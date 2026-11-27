-- One objective and one movement owner, with suspended territory and care latches.
local Agent={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e10 end
local function flat(a,b)
    if not a or not b then return math.huge end
    return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)
end
local function feeding(s,kind)
    return s.feedMode==kind or s.feedMode==true or s.nativeFeedMode==kind
end
function Agent.new(planner,adapter,Hunt,Care,Ledger)
    local a={planner=planner,adapter=adapter,Hunt=Hunt,Care=Care,enabled=false,phase="OFF",goal=nil,
        cooldown={},careCooldown={},recent={},waitingSince={},events={},ticks=0,earned=0,claimed=0,scented=0,
        feeds=0,hunts=0,failures=0,nextTick=0,reason="Disabled",generation=0,returns={},version="0.8.0"}
    a.metrics=Ledger and Ledger.new() or nil
    function a:planningOptions(extra)
        local options={blockedUntil=self.cooldown,waitingSince=self.waitingSince,
            maintenanceOnly=self.capacity and self.capacity.maintenanceOnly,retainOwned=self.capacity and self.capacity.retainOwned}
        for key,value in pairs(extra or {}) do options[key]=value end
        return options
    end
    function a:updateCapacity(hexes,state)
        if not self.planner.capacity then return end
        local care,active=0,self.metrics and self.metrics.active or 0
        for phase,seconds in pairs(self.metrics and self.metrics.phases or {}) do
            if phase:find("FOOD",1,true) or phase:find("WATER",1,true) or phase:find("HUNT",1,true)
                or phase=="DRINKING" or phase=="EATING" or phase=="RECOVER" or phase=="FEED_APPROACH" then care+=seconds end
        end
        self.capacity=self.planner.capacity(hexes,state,{blockedUntil=self.cooldown,
            careFraction=active>30 and math.clamp(care/active,0,.75) or 0})
    end
    function a:selectTerritory(state,force)
        local hexes=self.adapter:territories(state)
        local byKey={}
        for _,hex in ipairs(hexes) do
            byKey[hex.key]=hex
            if self.planner.objective(hex,state,state.position,{blockedUntil=self.cooldown}) then self.waitingSince[hex.key]=self.waitingSince[hex.key] or state.now
            else self.waitingSince[hex.key]=nil end
        end
        self:updateCapacity(hexes,state)
        local options=self:planningOptions({recent=self.recent,maxStops=6,
            regionCursor=self.regionCursor,regionDirection=self.regionDirection})
        if not force and self.itinerary then
            while #self.itinerary>0 do
                local item=self.itinerary[1]
                local fresh=self.planner.objective(byKey[item.key],state,state.position,options)
                if fresh then self.itinerary[1]=fresh;return self.itinerary,self.strategy end
                table.remove(self.itinerary,1)
            end
        end
        local route,strategy=self.planner.strategy(hexes,state,options)
        self.itinerary=route;self.strategy=strategy;self.regionCursor=strategy.cursor;self.regionDirection=strategy.direction or self.regionDirection
        return route,strategy
    end
    function a:log(at,kind,msg)
        table.insert(self.events,{at=math.floor(at*10)/10,kind=kind,msg=msg})
        if kind=="confirmed" or kind=="deferred" or kind=="failed" then self.lastNotice=msg end
        while #self.events>35 do table.remove(self.events,1) end
    end
    function a:setEnabled(on,now)
        local desired=on==true
        if self.enabled==desired then return end
        now=now or self.lastState and self.lastState.now or os.clock()
        local ownedFeed=self.enabled and self.goal and self.goal.meal and self.goal.meal.owned
        self.generation+=1;self.enabled=desired
        if not self.enabled then
            if self.metrics and self.metrics.run then self.metrics:sample(now or self.lastState and self.lastState.now or self.metrics.at,self.phase,self.phase=="PAUSED",false,self.goal,self.lastState,self.adapter.nav) end
            if self.adapter.recover then self.adapter:recover(self.lastState,false) end
            self.goal,self.suspended=nil,nil;self.returns={};self.itinerary=nil;self.phase="OFF";self.reason="Disabled"
            self.adapter:stop("disabled")
            if self.adapter.releaseInputs then self.adapter:releaseInputs() end
            if ownedFeed and self.lastState then
                if self.adapter.cancelFeed then self.adapter:cancelFeed(self.lastState) end
            end
        else
            self.nextTick=0;self.prevAmber=nil;self.needWindow={};self.needRates={};self.depletionProfiles={}
            self.capacity=nil;self.nextCapacityAt=0;self.nextPlanAt=0;self.nextUrgentCheck=0;self.pausedAt=nil
            self.itinerary=nil;self.regionCursor=nil;self.regionDirection=nil;self.earned=0;self.claimed=0;self.scented=0
            self.feeds,self.hunts,self.failures=0,0,0
            if self.metrics then self.metrics:start(now) end
            self.reason="Assessing animal and territory"
        end
    end
    function a:suspend(goal)
        if not goal or self.suspended==goal then return end
        if self.suspended then
            table.insert(self.returns,self.suspended)
            if #self.returns>3 then table.remove(self.returns,1) end
        end
        self.suspended=goal
    end
    function a:fail(state,reason)
        self.failures+=1;self.reason=reason
        if self.metrics then self.metrics:count("failure",reason) end
        if self.adapter.recover then self.adapter:recover(state,false) end
        local g=self.goal
        if g and g.meal and g.meal.owned and not g.meal.cancelAt and not g.emergencyStopAt and self.adapter.cancelFeed then
            if self.adapter:cancelFeed(state) then g.meal.cancelAt=state.now end
        end
        if self.adapter.releaseInputs then self.adapter:releaseInputs() end
        if g and g.kind=="TERRITORY" then self.cooldown[g.key]=state.now+90
        elseif g then self.careCooldown[g.kind]=state.now+2 end
        if g and g.kind=="DRINK" and self.adapter.avoidWater then self.adapter:avoidWater(g.location,state.now) end
        if g and g.food and g.food.model and self.adapter.foodBlocked then self.adapter.foodBlocked[g.food.model]=state.now+80 end
        self:log(state.now,"failed",reason);self.goal=nil
        self.adapter:stop(reason);self.phase="REPLAN"
    end
    function a:takeGoal(state,kind,target)
        self.adapter:stop("new goal")
        if kind~="RECOVER" and self.adapter.recover then self.adapter:recover(state,false) end
        self.objectiveSerial=(self.objectiveSerial or 0)+1
        self.goal={id=self.objectiveSerial,generation=self.generation,wallStart=state.now,
            kind=kind,key=target and target.key,detail=target,start=state.now,
            nextAction=0,tries=0,progressAt=state.now,
            baseline=kind=="DRINK" and state.thirst or kind=="EAT" and state.hunger or nil,
            needMaximum=kind=="DRINK" and state.thirstMax or kind=="EAT" and state.hungerMax or nil}
        self.phase="PREPARE_"..kind;self.reason="Starting "..kind
        self:log(state.now,"goal",kind..":"..tostring(target and target.key or "-"))
    end
    function a:resume(state)
        self.adapter:stop("care confirmed")
        if self.adapter.recover then self.adapter:recover(state,false) end
        local g=self.suspended;self.suspended=table.remove(self.returns)
        if g and g.kind=="TERRITORY" then
            local current=self.adapter:territory(g.key,state)
            local detail=current and self.planner.objective(current,state,state.position,self:planningOptions())
            if detail then
                if state.travelCost then
                    local route,strategy=self.planner.strategy(self.adapter:territories(state),state,self:planningOptions({regionCursor=self.regionCursor,maxStops=1}))
                    local alternate=route[1]
                    if alternate and alternate.key~=g.key and (strategy.phase=="URGENT_SCENT"
                        or alternate.score>detail.score*1.8 and alternate.travelSeconds<detail.travelSeconds*.55) then
                        self.itinerary=nil;self.goal=nil;self.reason="Replanning after care changed the useful route"
                        return
                    end
                end
                g.start=state.now;g.progressAt=state.now;g.interactAt=nil
                g.detail=detail;g.finishUntil=nil;g.completeAt=nil;g.inHexProgressAt=nil
                self.goal=g;self.phase="RESUME";self.reason="Resuming "..g.key
                return
            end
        end
        self.goal=nil
        if self.suspended then self:resume(state) end
    end
    function a:status()
        local s=self.lastState or {}
        local g=self.goal
        return {metrics=self.metrics and self.metrics:summary(),capacity=self.capacity,decision=self.decision,version=self.version,enabled=self.enabled,phase=self.phase,reason=self.reason,
            kind=g and g.kind or "NONE",key=g and g.key,claimed=self.claimed,scented=self.scented,
            feeds=self.feeds,hunts=self.hunts,failures=self.failures,earned=self.earned,
            species=self.species,coat=self.coat,hunger=s.hunger,thirst=s.thirst,
            suspended=self.suspended and self.suspended.key,lastSuccess=self.lastSuccess,
            targetProgress=g and {action=g.detail and g.detail.kind,progress=g.lastProg,hold=g.lastHold,alternates=g.alternates,
                needBaseline=g.baseline,needGain=g.gain},hunt=g and g.hunt and g.hunt:status() or nil,
            lastHunt=self.lastHunt,returnDepth=#self.returns+(self.suspended and 1 or 0),
            survivalReserve={hunger=s.hungerReserve,thirst=s.thirstReserve},lastCare=self.lastCare,lastRouteFailure=self.lastRouteFailure,
            input=self.adapter.lastInput,error=self.lastError,strategy=self.strategy,deferred=self.deferred or 0,
            lastSkip=self.lastSkip,lastNotice=self.lastNotice,travelled=self.adapter.nav and self.adapter.nav.travelled,
            waitSeconds=self.goal and self.goal.interactAt and s.now-self.goal.interactAt or 0}
    end
    function a:pause(state,reason)
        self.pausedAt=self.pausedAt or state.now
        self.pauseManual=state.manualInput==true or state.gameMenu==true
        if self.Care then self.Care.interrupt(self.goal,state.now) end
        self.phase="PAUSED";self.reason=reason;self.adapter:stop(reason)
    end
    function a:tick(now)
        if not self.enabled or now<self.nextTick then return end
        self.nextTick=now+.15;self.ticks+=1
        if self.metrics then
            if not self.metrics.run then self.metrics:start(now) elseif not self.metrics.at then self.metrics.at=now;self.metrics.started=now end
            self.metrics:sample(now,self.phase,self.phase=="PAUSED" or self.phase=="WAIT",self.phase=="PAUSED" and self.pauseManual,self.goal,self.lastState,self.adapter.nav)
        end
        if not self.metrics and self.goal and self.phaseAt and self.phaseGoal==self.goal then
            self.goal.durations=self.goal.durations or {}
            self.goal.durations[self.phase]=(self.goal.durations[self.phase] or 0)+math.clamp(now-self.phaseAt,0,2)
        end
        self.phaseAt=now;self.phaseGoal=self.goal
        if self.adapter.prepare then self.adapter:prepare(now,true,self.goal) end
        local state=self.adapter:snapshot(now)
        if not state or not state.alive or not state.position then
            self.phase="WAIT";self.reason="Living animal unavailable"
            self.goal,self.suspended=nil,nil;self.returns={};self.itinerary=nil
            if self.adapter.recover then self.adapter:recover(state,false) end
            self.adapter:stop("despawn");if self.adapter.releaseInputs then self.adapter:releaseInputs() end;return
        end
        state.now=now;self.lastState=state;self.species,self.coat=state.species,state.coat
        local changed=self.initialized and (self.lastCharacter~=state.char or self.lastPack~=state.pack
            or self.lastBiome~=state.biome or self.lastSpecies~=state.species or self.lastProfile~=state.profileKey
            or self.lastGeneration~=state.generation)
        if changed then
            self.goal,self.suspended=nil,nil;self.returns={};self.cooldown,self.recent,self.careCooldown={},{},{}
            self.waitingSince={};self.regionCursor=nil;self.regionDirection=nil;self.itinerary=nil
            self.needWindow={};self.needRates={};self.depletionProfiles={}
            self.prevAmber=nil;self.capacity=nil;self.nextCapacityAt=0;self.nextPlanAt=0;self.nextUrgentCheck=0
            if self.adapter.releaseInputs then self.adapter:releaseInputs() end
            if self.adapter.recover then self.adapter:recover(state,false) end
            self.adapter:stop("animal / pack / map changed")
            self.lastTerritoryKey=nil;self.pausedAt=nil
            self:log(now,"reset","Changed animal, pack or map")
        end
        self.initialized=true
        self.lastCharacter,self.lastPack,self.lastBiome,self.lastSpecies,self.lastProfile=state.char,state.pack,state.biome,state.species,state.profileKey
        self.lastGeneration=state.generation
        self.needRates=self.needRates or {}
        self.needWindow=self.needWindow or {}
        for _,key in ipairs({"hunger","thirst"}) do
            local sample,value=self.needWindow[key],state[key]
            if not finite(value) then self.needWindow[key]=nil
            elseif not sample or sample.char~=state.char or value>sample.value+.02 or now-sample.at>15 then
                self.needWindow[key]={char=state.char,at=now,value=value,mode=state.swimming and "swim" or state.hudBurst and "burst" or state.hudSprint and "sprint" or "ordinary"}
            elseif now-sample.at>=4 then
                -- Include idle samples between replicated resource updates;
                -- averaging only falling ticks exaggerates consumption.
                local rate=(sample.value-value)/(now-sample.at)
                if rate>=0 and rate<((state[key.."Max"] or 100)*.05) then
                    self.needRates[key]=(self.needRates[key] or rate)*.6+rate*.4
                    self.depletionProfiles=self.depletionProfiles or {}
                    self.depletionProfiles[key]=self.depletionProfiles[key] or {}
                    local modes=self.depletionProfiles[key];local mode=sample.mode or "ordinary"
                    modes[mode]={rate=rate,at=now}
                end
                self.needWindow[key]={char=state.char,at=now,value=value,mode=state.swimming and "swim" or state.hudBurst and "burst" or state.hudSprint and "sprint" or "ordinary"}
            end
        end
        for _,key in ipairs({"hunger","thirst"}) do
            local rate=self.needRates[key]
            for _,v in pairs(self.depletionProfiles and self.depletionProfiles[key] or {}) do
                if now-v.at<90 then rate=math.max(rate or 0,v.rate*.7) end
            end
            if finite(state[key]) and rate and rate>.001 then state[key.."Reserve"]=math.max(0,state[key]-(state[key.."Max"] or 100)*.12)/rate end
        end
        if self.metrics then self.metrics:currency(state.amber,state.char) end
        if self.planner.capacity and now>=(self.nextCapacityAt or 0) then
            self.nextCapacityAt=now+10
            self:updateCapacity(self.adapter:territories(state),state)
        end
        if finite(state.amber) then
            if finite(self.prevAmber) and state.amber>self.prevAmber then self.earned+=state.amber-self.prevAmber end
            self.prevAmber=state.amber
        end
        if state.manualInput or state.gameMenu then
            if self.goal then self.goal.manualInterventionObserved=true end
            self:pause(state,"Manual movement, typing or native menu");return
        end
        local ownRecovery=self.goal and self.goal.kind=="RECOVER" and state.automaticRest==true
        if state.ability or state.pinned or state.resting and not ownRecovery or state.flying or state.climbing or state.rescuing then
            self:pause(state,"Native ability, capture, Rest, flight or climbing");return
        end
        if (feeding(state,"eat") or feeding(state,"drink")) and (not self.goal or self.goal.kind=="TERRITORY") then
            self:pause(state,"Native feeding owns movement");return
        end
        if state.underwater then self:pause(state,"Underwater route requires manual surface recovery");return end
        if state.combatKnown==false then self:pause(state,"Native combat timing unavailable");return end
        if state.combat and (not self.goal or self.goal.kind~="EAT") then self:pause(state,"Combat interruption");return end
        if self.pausedAt then
            if self.goal then
                local delay=now-self.pausedAt
                self.goal.start+=delay;self.goal.progressAt+=delay
                if self.goal.interactAt then self.goal.interactAt+=delay end
                if self.goal.hunt and self.goal.hunt.resume then self.goal.hunt:resume(delay) end
            end
            self.pausedAt=nil
        end
        state.recoveryStalled=self.goal and self.goal.kind=="RECOVER" and now-(self.goal.recoverProgressAt or self.goal.start)>20
        local decision=self.planner.decide and self.planner.decide(state) or {kind=self.planner.need(state)}
        self.decision=decision
        local need=decision.kind
        if need=="WAIT" then self:pause(state,decision.reason or "Native needs unavailable");return end
        if not self.goal and self.suspended and need=="TERRITORY" then self:resume(state) end
        local goal=self.goal
        if goal and goal.kind=="TERRITORY" and not goal.nativeStarted and self.capacity and self.capacity.maintenanceOnly
            and (goal.detail.kind=="CLAIM" or self.capacity.retainOwned and not self.capacity.retainOwned[goal.key]) then
            self.goal=nil;self.itinerary=nil;goal=nil
            self.adapter:stop("Maintenance workload displaced optional acquisition")
        end
        if goal and goal.kind=="TERRITORY" and state.contested and state.contested[goal.key] then
            self.cooldown[goal.key]=now+15
            self.lastSkip="Non-pack player occupies "..goal.key
            self.deferred=(self.deferred or 0)+1
            self:log(now,"deferred",self.lastSkip)
            self.goal=nil;goal=nil
        end
        if self.suspended and state.contested and state.contested[self.suspended.key] then
            self.suspended=table.remove(self.returns)
        end
        local opportunistic=(not goal or goal.kind=="TERRITORY") and state.feedCan=="drink"
            and finite(state.thirst) and state.thirst<(state.thirstMax or 100)*.82
            and now-(self.lastFullDrinkAt or -100)>90
        if opportunistic and state.healthFraction>=.45 then need="DRINK" end
        -- Finish a progressing near-complete claim before routine care. A
        -- critical need, genuine contest or native interruption still wins.
        local protected=false
        if goal and goal.kind=="TERRITORY" and need~="TERRITORY" and not decision.critical then
            local t=self.adapter:territory(goal.key,state)
            local p=t and (goal.detail.kind=="SCENT" and t.hold or t.prog)
            if type(p)=="number" and p>=.72 and p<=1 and state.healthFraction>=.45
                and (state.hunger or 100)>(state.hungerMax or 100)*.19 and (state.thirst or 100)>(state.thirstMax or 100)*.19 then
                goal.finishUntil=goal.finishUntil or now+math.clamp((goal.detail.kind=="SCENT" and (state.refillTime or 60) or (state.claimTime or 20))*(1-p)+2,2,18)
                protected=now<goal.finishUntil and now-goal.progressAt<3
            end
        end
        if protected then need="TERRITORY" end
        -- Re-evaluate urgent scent during travel, without abandoning active or
        -- nearly finished work. Preserve the region cursor and return target.
        if goal and goal.kind=="TERRITORY" and need=="TERRITORY" and not self.suspended
            and not goal.nativeStarted and now>=(self.nextUrgentCheck or 0) then
            self.nextUrgentCheck=now+1
            local current=self.adapter:territory(goal.key,state)
            local almostDone=current and current.by==state.pack and finite(current.prog) and current.prog>=.72
            local urgentGoal=goal.detail.kind=="SCENT" and current and (finite(current.hold) and current.hold<.28 or goal.detail.slack and goal.detail.slack<45)
            local completed=current and (goal.detail.kind=="CLAIM" and current.owner==state.pack
                or goal.detail.kind=="SCENT" and current.hold and current.hold>=.985)
            if not completed and not almostDone and not urgentGoal and flat(state.position,goal.detail.center)>(state.claimRadius or 15) then
                local route,strategy=self.planner.strategy(self.adapter:territories(state),state,
                    self:planningOptions({regionCursor=self.regionCursor,maxStops=1}))
                if strategy.phase=="URGENT_SCENT" and route[1] and route[1].key~=goal.key then
                    self:suspend(goal);self.strategy=strategy
                    self:takeGoal(state,"TERRITORY",route[1]);goal=self.goal
                    self.reason="Maintaining critical scent before resuming the area sweep"
                end
            end
        end
        -- Care is latched to its completion target. Crossing its trigger does
        -- not cancel a native feeding session or lose the suspended territory.
        if goal and goal.kind=="RECOVER" and state.healthFraction>=.72 then
            self:resume(state);goal=self.goal
        end
        local urgent=decision.critical and decision.kind or nil
        -- A latched meal cannot ignore a different need becoming lethal.
        -- Cancel only our own native feeding session and wait for its release.
        local emergency=goal and (goal.kind=="EAT" or goal.kind=="DRINK") and urgent and urgent~=goal.kind
            and (urgent=="RECOVER" or urgent=="DRINK" and state.thirst<(state.thirstMax or 100)*.10
                or urgent=="EAT" and state.hunger<(state.hungerMax or 100)*.10) and urgent
        if emergency and goal.meal and goal.meal.owned then
            goal.emergencySince=goal.emergencySince or now
            if not feeding(state,"eat") and not feeding(state,"drink")
                and (state.nativeFeedKnown==true and not state.nativeFeedMode
                    or goal.emergencyStopAt and now-goal.emergencyStopAt>.75) then
                self:takeGoal(state,emergency);goal=self.goal;urgent=emergency;need=emergency
            else
                if not goal.emergencyStopAt and self.adapter.cancelFeed and self.adapter:cancelFeed(state) then
                    goal.emergencyStopAt=now
                end
                self.adapter:stop("Critical survival handoff")
                self.phase="VERIFY_FEED_RELEASE";self.reason="Releasing owned feeding for critical "..emergency
                if now-goal.emergencySince>3 then self:fail(state,"Critical feeding release unconfirmed") end
                return
            end
        end
        local switch=not goal or goal.kind=="TERRITORY" and need~="TERRITORY"
            or urgent and goal.kind~=urgent and not goal.feedPending and not feeding(state,"eat") and not feeding(state,"drink")
        if switch and need~="TERRITORY" and need~="WAIT" then
            local kind=urgent or need
            if (self.careCooldown[kind] or 0)>now then
                self.phase="WAIT_CARE";self.reason="Retrying another survival location shortly"
                self.adapter:stop("care retry cooldown");return
            end
            if goal and goal.kind=="TERRITORY" then self:suspend(goal) end
            self:takeGoal(state,kind);goal=self.goal
        end
        if not goal then
            if state.pack==nil then
                self.phase="WAIT";self.reason="Join a pack to claim or scent territory";self.adapter:stop("no pack");return
            end
            if now<(self.nextPlanAt or 0) then
                self.phase="WATCH";self.reason="Watching native scent and survival";self.adapter:stop("maintenance watch");return
            end
            local route,strategy=self:selectTerritory(state)
            if #route==0 then
                self.nextPlanAt=now+.8
                local exposed=state.currentHex and state.contested and state.contested[state.currentHex]
                local patrol=exposed and self.adapter.patrol and self.adapter:patrol(state)
                if patrol then
                    self.phase="PATROL";self.reason="Territories maintained; checking the next area"
                    self.adapter:move(patrol,state,{navKey="PATROL:"..tostring(patrol.key),moveRadius=12})
                else
                    self.phase="WATCH";self.reason=self.capacity and self.capacity.maintenanceOnly and self.capacity.policy or "Territories maintained or deferred; watching native scent and survival"
                    self.adapter:stop("no available target")
                end
                return
            end
            self:takeGoal(state,"TERRITORY",route[1]);goal=self.goal
            self.lastTerritoryKey=goal.key
        end
        if goal.kind=="RECOVER" then
            local available=self.adapter.recover and self.adapter:recover(state,true)
            if not goal.recoverHP or state.healthFraction>goal.recoverHP+.001 then
                goal.recoverHP=state.healthFraction;goal.recoverProgressAt=now
            end
            self.phase="RECOVER";self.reason="Watching native out-of-combat HP recovery"
            if now-(goal.recoverProgressAt or goal.start)>20 then
                self.phase="WAIT_RECOVERY"
                self.reason=state.combat and "Recovery waits for native combat eligibility"
                    or "Recovery has no observed HP gain; rechecking native eligibility"
                goal.recoverChecks=(goal.recoverChecks or 0)+1
            end
            self.adapter:stop("low health");return
        end
        if goal.kind=="TERRITORY" then
            if state.pack==nil then self:fail(state,"Pack unavailable");return end
            local native=self.adapter:territory(goal.key,state)
            if not native or native.neutral then self:fail(state,"Territory missing or neutral");return end
            local owned=native.owner==state.pack
            local pendingClaim=owned and native.by==state.pack and finite(native.prog) and native.prog>.01 and native.prog<.995
            local done=goal.detail.kind=="CLAIM" and owned and not pendingClaim
                or goal.detail.kind=="SCENT" and owned and finite(native.hold) and native.hold>=.985
            if done then
                goal.completeAt=goal.completeAt or now
                -- Require the replicated completion to survive another native
                -- sample before departure. Ownership is not fabricated locally.
                if now-goal.completeAt<.45 then
                    self.adapter:stop("verifying territory completion")
                    self.phase="VERIFY_TERRITORY";self.reason="Checking stable native territory completion";return
                end
                if goal.detail.kind=="SCENT" then self.scented+=1 else self.claimed+=1 end
                if self.metrics then self.metrics:count("outcome",goal.nativeStarted and "local territory progress completed" or "pack territory completion observed") end
                self.recent[goal.key]=now;self.lastSuccess="Observed "..goal.detail.kind.." "..goal.key
                self.waitingSince[goal.key]=nil
                self:log(now,"confirmed",self.lastSuccess);self.adapter:stop("replicated complete")
                self.goal=nil;self.phase="CONFIRMED";self.reason=self.lastSuccess
                if self.suspended then self:resume(state) end
                return
            end
            goal.completeAt=nil
            local waypoint=self.adapter:territorySpot(goal.key,state)
            if not waypoint then self:fail(state,"No streamed native territory position");return end
            local progressing=finite(native.prog) and native.by==state.pack and finite(goal.lastProg) and native.prog>goal.lastProg+.002
                or owned and finite(native.hold) and finite(goal.lastHold) and native.hold>goal.lastHold+.002
            if progressing then goal.progressAt=now;goal.nativeStarted=true end
            goal.lastProg,goal.lastHold=native.prog,native.hold
            local inHex=state.currentHex==goal.key or not state.currentHex and flat(state.position,waypoint)<=(state.claimRadius or 15)
            if progressing and inHex then goal.inHexProgressAt=now end
            -- Replication arrives less often than this coordinator ticks. Stay
            -- put between progressing samples rather than restarting travel.
            local localProgress=inHex and (owned or native.by==state.pack)
                and goal.inHexProgressAt and now-goal.inHexProgressAt<2.5
            local outsideHex=state.currentHex~=nil and state.currentHex~=goal.key
            if outsideHex or flat(state.position,waypoint)>(waypoint.moveRadius or state.claimRadius or 15) and not localProgress then
                self.phase="TRAVEL";self.reason=goal.detail.kind.." "..goal.key
                local result=self.adapter:move(waypoint,state,{navKey="HEX:"..goal.key,costPurpose="HEX:"..goal.key,costPoint=goal.detail.center,moveRadius=waypoint.moveRadius or 10})
                if result=="STUCK" or result=="BLOCKED" then
                    goal.routeRetries=(goal.routeRetries or 0)+1
                    self.lastRouteFailure={key=goal.key,at=now,reason=self.adapter.motionReason,
                        navigation=self.adapter.nav and self.adapter.nav:status()}
                    self:log(now,"route_retry","Retrying approach "..goal.key.." ("..goal.routeRetries.."): "..tostring(self.adapter.motionReason or result))
                    self.adapter:advanceSpot(goal.key);self.adapter:stop("Alternative territory approach")
                    if goal.routeRetries>=3 then self:fail(state,"Territory route failed after three approach attempts") end
                elseif now-goal.start>240 then self:fail(state,"Territory travel budget exhausted") end
                return
            end
            self.adapter:stop("at territory")
            self.phase="CLAIMING";self.reason=goal.nativeStarted and "Native territory progress observed" or "Waiting for native claim/scent progress"
            if not goal.interactAt then goal.interactAt=now;goal.progressAt=now end
            local stall=now-goal.progressAt
            local stallLimit=goal.nativeStarted and math.max(4.5,(state.progressLatency or 1)*3) or 3.2
            if stall>stallLimit and (goal.alternates or 0)<3 then
                goal.alternates=(goal.alternates or 0)+1;goal.progressAt=now;goal.interactAt=now
                self.adapter:advanceSpot(goal.key);self.phase="REPOSITION"
                self.reason="Trying another surface position in "..goal.key
            elseif stall>6 or now-goal.interactAt>75 then self:fail(state,"No confirmed territory progress") end
            return
        end
        local kind=goal.kind=="DRINK" and "drink" or "eat"
        if (feeding(state,"eat") or feeding(state,"drink")) and not (goal.meal and goal.meal.owned) then
            goal.manualInterventionObserved=true
        end
        local careStatus,careReason=self.Care.step(goal,state,self.adapter)
        if careStatus=="COMPLETE" then
            if self.adapter.careObserved then self.adapter:careObserved(goal,state) end
            self.lastCare={kind=goal.kind,seconds=now-goal.start,wallSeconds=now-(goal.wallStart or goal.start),activeSeconds=goal.timing and goal.timing.active,
                pausedSeconds=goal.timing and goal.timing.paused,unobservedSeconds=goal.timing and goal.timing.unknown,
                phases=goal.timing and goal.timing.phases or goal.durations,gain=goal.gain,
                manualInterventionObserved=goal.manualInterventionObserved==true}
            if kind=="drink" then self.lastFullDrinkAt=now end
            if self.metrics then self.metrics:count("outcome",goal.manualInterventionObserved and "assisted care completed" or "unassisted care observed") end
            self.feeds+=1;self.lastSuccess=careReason.." (+"..string.format("%.1f",goal.gain)..")"
            self:log(now,"confirmed",self.lastSuccess);self.goal=nil;self:resume(state)
            if not self.goal then self.phase="CONFIRMED";self.reason=self.lastSuccess end
            return
        elseif careStatus=="BUSY" then
            self.adapter:stop("native feeding owns approach")
            self.phase=feeding(state,kind) and (kind=="drink" and "DRINKING" or "EATING") or "FEED_APPROACH"
            self.reason=careReason;return
        elseif careStatus=="FAILED" then self:fail(state,careReason);return
        elseif careStatus=="RELOCATE" then
            if kind=="drink" and self.adapter.avoidWater then self.adapter:avoidWater(goal.location or state.feedPosition or state.position,now) end
            if goal.food and goal.food.model and self.adapter.foodBlocked then self.adapter.foodBlocked[goal.food.model]=now+30 end
            goal.location,goal.arrivedAt,goal.food,goal.foodArrived=nil,nil,nil,nil
            self.Care.resetSite(goal,now)
            goal.siteFailures=(goal.siteFailures or 0)+1
            goal.feedBlockedUntil=now+1.5
            if goal.siteFailures>=3 then self:fail(state,careReason);return end
        end
        if state.feedCan==kind and now>=(goal.feedBlockedUntil or 0) then
            self.adapter:stop("native feed offer")
            if now<goal.nextAction then return end
            local sent=self.adapter:feed(state,kind)
            goal.tries+=1;goal.nextAction=now+1
            if sent then self.Care.requested(goal,now) end
            self.phase=kind=="drink" and "DRINKING" or "EATING"
            self.reason=sent and "Feed input requested; watching native approach and need" or "Feed input unavailable"
            if not sent and goal.tries>=3 then self:fail(state,"Native feed input unavailable") end
            return
        end
        local usefulHunt=goal.hunt and goal.hunt.lastUsefulAt and now-goal.hunt.lastUsefulAt<12
        if now-goal.start>150 and not usefulHunt then self:fail(state,"Survival objective timed out without useful progress");return end
        if kind=="drink" then
            if not goal.location then goal.location=self.adapter:water(state);goal.locationAt=now end
            if not goal.location then
                local search=self.adapter.resourceSearch and self.adapter:resourceSearch(state,"WATER")
                if search then
                    self.phase="SEARCH_WATER";self.reason="Checking another area for native water access"
                    self.adapter:move(search,state,{navKey="WATER_SCOUT",moveRadius=10})
                else
                    self.phase="WAIT_WATER";self.reason="No streamed water access found";self.adapter:stop("no water")
                end
                return
            end
            if now-(goal.waterRefreshAt or 0)>1.5 and self.adapter.waterEvidence=="LANDMARK_APPROACH" then
                goal.waterRefreshAt=now
                local refined=self.adapter:water(state)
                if refined and flat(refined,goal.location)>5 then goal.location=refined;goal.arrivedAt=nil end
            end
            local d=flat(state.position,goal.location)
            if d<110 and self.adapter.waterEvidence=="LANDMARK_APPROACH" and now-(goal.refinedAt or 0)>3 then
                goal.refinedAt=now
                self.adapter.waterCache=nil
                local refined=self.adapter:water(state)
                if refined and flat(refined,goal.location)>5 then goal.location=refined;goal.arrivedAt=nil end
                d=flat(state.position,goal.location)
            end
            if d<6 and not goal.arrivedAt then goal.arrivedAt=now end
            if goal.arrivedAt and now-goal.arrivedAt>1.8 then
                if self.adapter.avoidWater then self.adapter:avoidWater(goal.location,now) end
                goal.location=nil;goal.arrivedAt=nil;goal.waterRetries=(goal.waterRetries or 0)+1
                if goal.waterRetries>=4 then self:fail(state,"No native drinking offer at sampled water access") end
                return
            end
            self.phase="TRAVEL_WATER";self.reason="Approaching observed water access"
            local result=self.adapter:move(goal.location,state,{navKey="WATER:"..tostring(goal.locationAt),moveRadius=4})
            if result=="STUCK" or result=="BLOCKED" then
                if self.adapter.avoidWater then self.adapter:avoidWater(goal.location,now) end
                goal.location=nil;goal.arrivedAt=nil
            end
            return
        end
        local food=self.adapter.food and self.adapter:food(state,goal.food)
        if food and self.adapter.mealChoice then food=self.adapter:mealChoice(state,food,goal.hunt) end
        if food then
            if not goal.food or goal.food.model~=food.model then goal.foodArrived=nil end
            goal.food=food;self.phase="TRAVEL_FOOD";self.reason="Approaching native edible food"
            local result=self.adapter:move(food.position,state,{navKey=food.model or "FOOD",moveRadius=2})
            if result=="REACHED" then goal.foodArrived=goal.foodArrived or now end
            if result=="STUCK" or result=="BLOCKED" or goal.foodArrived and now-goal.foodArrived>2.5 then
                if food.model and self.adapter.foodBlocked then self.adapter.foodBlocked[food.model]=now+80 end
                goal.food=nil;goal.foodArrived=nil
            end
            return
        end
        if state.healthFraction<.42 then
            local search=self.adapter.resourceSearch and self.adapter:resourceSearch(state,"FOOD")
            if search then
                self.phase="SEARCH_FOOD";self.reason="Seeking edible food without risking a hunt"
                self.adapter:move(search,state,{navKey="LOW_HP_FOOD",moveRadius=10})
            else
                self.phase="WAIT_FOOD";self.reason="Health too low to hunt; watching edible food offers"
                self.adapter:stop("low health excludes hunt")
            end
            return
        end
        if not goal.hunt and self.Hunt then goal.hunt=self.Hunt.new(self.adapter) end
        if not goal.hunt then self.phase="WAIT_FOOD";self.reason="Hunting controller unavailable";self.adapter:stop("no hunter");return end
        if goal.hunt.corpse then
            local corpse=goal.hunt.corpse
            if now-corpse.at<10 then
                self.phase="WAIT_FOOD";self.reason="Prey HP reached zero; locating native edible food"
                self.adapter:move(corpse.position,state,{navKey="CORPSE",moveRadius=2});return
            else goal.hunt.corpse=nil end
        end
        self.phase,self.reason=goal.hunt:tick(state)
        if (self.phase=="WAIT_FOOD" or self.phase=="HUNT_REPLAN" or self.phase=="HUNT_SEARCH") and self.adapter.resourceSearch then
            local search=self.adapter:resourceSearch(state,"FOOD")
            if search then
                self.adapter:move(search,state,{navKey="FOOD_SCOUT",moveRadius=10,hunting=true})
                self.phase="SEARCH_FOOD";self.reason="Searching another area for edible food or suitable NPC prey"
            end
        end
        self.lastHunt=goal.hunt:status();self.lastHunt.at=now;self.lastHunt.active=false;self.lastHunt.retained=true
        if goal.hunt.kills>(goal.observedKills or 0) then
            self.hunts+=goal.hunt.kills-(goal.observedKills or 0);goal.observedKills=goal.hunt.kills
        end
    end
    return a
end
return Agent
