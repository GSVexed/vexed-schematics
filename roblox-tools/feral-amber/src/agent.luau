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
function Agent.new(planner,adapter,Hunt)
    local a={planner=planner,adapter=adapter,Hunt=Hunt,enabled=false,phase="OFF",goal=nil,
        cooldown={},careCooldown={},recent={},waitingSince={},events={},ticks=0,earned=0,claimed=0,scented=0,
        feeds=0,hunts=0,failures=0,nextTick=0,reason="Disabled",generation=0,version="0.4.0"}
    function a:log(at,kind,msg)
        table.insert(self.events,{at=math.floor(at*10)/10,kind=kind,msg=msg})
        while #self.events>35 do table.remove(self.events,1) end
    end
    function a:setEnabled(on)
        local ownedFeed=self.enabled and self.goal and self.goal.feedPending
        self.generation+=1;self.enabled=on==true
        if not self.enabled then
            self.goal,self.suspended=nil,nil;self.phase="OFF";self.reason="Disabled"
            self.adapter:stop("disabled")
            if self.adapter.releaseInputs then self.adapter:releaseInputs() end
            if ownedFeed and self.lastState then
                if self.adapter.cancelFeed then self.adapter:cancelFeed(self.lastState) end
            end
        else self.nextTick=0;self.reason="Assessing animal and territory" end
    end
    function a:fail(state,reason)
        self.failures+=1;self.reason=reason
        local g=self.goal
        if g and g.kind=="TERRITORY" then self.cooldown[g.key]=state.now+90
        elseif g then self.careCooldown[g.kind]=state.now+8 end
        if g and g.kind=="DRINK" and self.adapter.avoidWater then self.adapter:avoidWater(g.location,state.now) end
        if g and g.food and g.food.model and self.adapter.foodBlocked then self.adapter.foodBlocked[g.food.model]=state.now+80 end
        self:log(state.now,"failed",reason);self.goal=nil
        self.adapter:stop(reason);self.phase="REPLAN"
    end
    function a:takeGoal(state,kind,target)
        self.adapter:stop("new goal")
        self.goal={kind=kind,key=target and target.key,detail=target,start=state.now,
            nextAction=0,tries=0,progressAt=state.now,
            baseline=kind=="DRINK" and state.thirst or kind=="EAT" and state.hunger or nil}
        self.phase="PREPARE_"..kind;self.reason="Starting "..kind
        self:log(state.now,"goal",kind..":"..tostring(target and target.key or "-"))
    end
    function a:resume(state)
        self.adapter:stop("care confirmed")
        local g=self.suspended;self.suspended=nil
        if g and g.kind=="TERRITORY" then
            local current=self.adapter:territory(g.key,state)
            if current and not current.neutral then
                g.start=state.now;g.progressAt=state.now;g.interactAt=nil
                self.goal=g;self.phase="RESUME";self.reason="Resuming "..g.key
                return
            end
        end
        self.goal=nil
    end
    function a:status()
        local s=self.lastState or {}
        local g=self.goal
        return {version=self.version,enabled=self.enabled,phase=self.phase,reason=self.reason,
            kind=g and g.kind or "NONE",key=g and g.key,claimed=self.claimed,scented=self.scented,
            feeds=self.feeds,hunts=self.hunts,failures=self.failures,earned=self.earned,
            species=self.species,coat=self.coat,hunger=s.hunger,thirst=s.thirst,
            suspended=self.suspended and self.suspended.key,lastSuccess=self.lastSuccess,
            targetProgress=g and {progress=g.lastProg,hold=g.lastHold,alternates=g.alternates,
                needBaseline=g.baseline,needGain=g.gain},hunt=g and g.hunt and g.hunt:status() or self.lastHunt,
            input=self.adapter.lastInput,error=self.lastError}
    end
    function a:pause(state,reason)
        self.pausedAt=self.pausedAt or state.now
        self.phase="PAUSED";self.reason=reason;self.adapter:stop(reason)
    end
    function a:tick(now)
        if not self.enabled or now<self.nextTick then return end
        self.nextTick=now+.2;self.ticks+=1
        if self.adapter.prepare then self.adapter:prepare(now,true,self.goal) end
        local state=self.adapter:snapshot(now)
        if not state or not state.alive or not state.position then
            self.phase="WAIT";self.reason="Living animal unavailable"
            self.goal,self.suspended=nil,nil;self.adapter:stop("despawn");return
        end
        state.now=now;self.lastState=state;self.species,self.coat=state.species,state.coat
        local changed=self.initialized and (self.lastCharacter~=state.char or self.lastPack~=state.pack
            or self.lastBiome~=state.biome or self.lastSpecies~=state.species)
        if changed then
            self.goal,self.suspended=nil,nil;self.cooldown,self.recent,self.careCooldown={},{},{}
            self.waitingSince={}
            self.adapter:stop("animal / pack / map changed")
            self.lastTerritoryKey=nil;self.pausedAt=nil
            self:log(now,"reset","Changed animal, pack or map")
        end
        self.initialized=true
        self.lastCharacter,self.lastPack,self.lastBiome,self.lastSpecies=state.char,state.pack,state.biome,state.species
        if finite(state.amber) then
            if finite(self.prevAmber) and state.amber>self.prevAmber then self.earned+=state.amber-self.prevAmber end
            self.prevAmber=state.amber
        end
        if state.manualInput or state.gameMenu then self:pause(state,"Manual movement, typing or native menu");return end
        if state.ability or state.pinned or state.resting or state.flying or state.climbing or state.rescuing then
            self:pause(state,"Native ability, capture, Rest, flight or climbing");return
        end
        if (feeding(state,"eat") or feeding(state,"drink")) and (not self.goal or self.goal.kind=="TERRITORY") then
            self:pause(state,"Native feeding owns movement");return
        end
        if state.underwater then self:pause(state,"Underwater route requires manual surface recovery");return end
        if state.combat and (not self.goal or self.goal.kind~="EAT") then self:pause(state,"Combat interruption");return end
        for _,p in ipairs(state.players or {}) do
            if flat(state.position,p)<(state.avoidRadius or 110) then self:pause(state,"Player nearby");return end
        end
        if self.pausedAt then
            if self.goal then
                local delay=now-self.pausedAt
                self.goal.start+=delay;self.goal.progressAt+=delay
                if self.goal.interactAt then self.goal.interactAt+=delay end
                if self.goal.hunt then self.goal.hunt:abandon(now,"Pursuit interrupted") end
            end
            self.pausedAt=nil
        end
        local need=self.planner.need(state)
        local goal=self.goal
        -- Care is latched to its completion target. Crossing its trigger does
        -- not cancel a native feeding session or lose the suspended territory.
        if goal and goal.kind=="RECOVER" and state.healthFraction>=.72 then
            self:resume(state);goal=self.goal
        end
        local urgent=state.thirst and state.thirst<19 and "DRINK"
            or state.hunger and state.hunger<19 and "EAT"
            or state.healthFraction<.3 and "RECOVER" or nil
        local switch=not goal or goal.kind=="TERRITORY" and need~="TERRITORY"
            or urgent and goal.kind~=urgent and not goal.feedPending and not feeding(state,"eat") and not feeding(state,"drink")
        if switch and need~="TERRITORY" and need~="WAIT" then
            local kind=urgent or need
            if (self.careCooldown[kind] or 0)>now then
                self.phase="WAIT_CARE";self.reason="Retrying another survival location shortly"
                self.adapter:stop("care retry cooldown");return
            end
            if goal and goal.kind=="TERRITORY" then self.suspended=goal end
            self:takeGoal(state,kind);goal=self.goal
        end
        if not goal then
            if state.pack==nil then
                self.phase="WAIT";self.reason="Join a pack to claim or scent territory";self.adapter:stop("no pack");return
            end
            local hexes=self.adapter:territories(state)
            for _,hex in ipairs(hexes) do
                if not hex.neutral then self.waitingSince[hex.key]=self.waitingSince[hex.key] or now end
            end
            local route=self.planner.plan(hexes,state,{
                blockedUntil=self.cooldown,recent=self.recent,waitingSince=self.waitingSince,
                avoidRadius=state.avoidRadius or 110,maxStops=5})
            if #route==0 then self.phase="WATCH";self.reason="No eligible safe territory objective";self.adapter:stop("no target");return end
            self:takeGoal(state,"TERRITORY",route[1]);goal=self.goal
            self.lastTerritoryKey=goal.key
        end
        if goal.kind=="RECOVER" then
            self.phase="RECOVER";self.reason="Waiting for observed out-of-combat HP recovery"
            self.adapter:stop("low health");return
        end
        if goal.kind=="TERRITORY" then
            if state.pack==nil then self:fail(state,"Pack unavailable");return end
            local native=self.adapter:territory(goal.key,state)
            if not native or native.neutral then self:fail(state,"Territory missing or neutral");return end
            local owned=native.owner==state.pack
            local done=goal.detail.kind=="CLAIM" and owned
                or goal.detail.kind=="SCENT" and owned and finite(native.hold) and native.hold>=.96
            if done then
                if goal.detail.kind=="SCENT" then self.scented+=1 else self.claimed+=1 end
                self.recent[goal.key]=now;self.lastSuccess="Observed "..goal.detail.kind.." "..goal.key
                self.waitingSince[goal.key]=nil
                self:log(now,"confirmed",self.lastSuccess);self.adapter:stop("replicated complete")
                self.goal=nil;self.phase="CONFIRMED";self.reason=self.lastSuccess;return
            end
            local waypoint=self.adapter:territorySpot(goal.key,state)
            if not waypoint then self:fail(state,"No streamed native territory position");return end
            local progressing=finite(native.prog) and native.by==state.pack and finite(goal.lastProg) and native.prog>goal.lastProg+.002
                or owned and finite(native.hold) and finite(goal.lastHold) and native.hold>goal.lastHold+.002
            if progressing then goal.progressAt=now;goal.nativeStarted=true end
            goal.lastProg,goal.lastHold=native.prog,native.hold
            if flat(state.position,waypoint)>(state.claimRadius or 15) and not progressing then
                self.phase="TRAVEL";self.reason=goal.detail.kind.." "..goal.key
                local result=self.adapter:move(waypoint,state,{navKey="HEX:"..goal.key,moveRadius=10})
                if result=="STUCK" or now-goal.start>450 then self:fail(state,"Territory route made no sustained progress") end
                return
            end
            self.adapter:stop("at territory")
            self.phase="CLAIMING";self.reason=goal.nativeStarted and "Native territory progress observed" or "Waiting for native claim/scent progress"
            if not goal.interactAt then goal.interactAt=now;goal.progressAt=now end
            local stall=now-goal.progressAt
            if stall>22 and (goal.alternates or 0)<3 then
                goal.alternates=(goal.alternates or 0)+1;goal.progressAt=now;goal.interactAt=now
                self.adapter:advanceSpot(goal.key);self.phase="REPOSITION"
                self.reason="Trying another surface position in "..goal.key
            elseif stall>35 or now-goal.interactAt>180 then self:fail(state,"No confirmed territory progress") end
            return
        end
        local kind=goal.kind=="DRINK" and "drink" or "eat"
        local value=kind=="drink" and state.thirst or state.hunger
        if not finite(value) or not finite(goal.baseline) then self:fail(state,"Native needs unavailable");return end
        goal.gain=value-goal.baseline
        if finite(goal.lastValue) and value>goal.lastValue+.02 then goal.progressAt=now end
        goal.lastValue=value
        local active=feeding(state,kind)
        if value>=(state.careTarget or 72) and goal.gain>.25 then
            if active then
                self.adapter:stop("feeding target reached")
                if goal.feedPending and not goal.stopFeedRequested and self.adapter.cancelFeed then
                    goal.stopFeedRequested=self.adapter:cancelFeed(state)
                end
                self.phase="VERIFY_FEED_END";self.reason="Needs increased; waiting for native feeding to end";return
            end
            self.feeds+=1;self.lastSuccess=(kind=="drink" and "Thirst" or "Hunger").." increased by "..string.format("%.1f",goal.gain)
            self:log(now,"confirmed",self.lastSuccess)
            self.goal=nil;self:resume(state)
            if not self.goal then self.phase="CONFIRMED";self.reason=self.lastSuccess end
            return
        end
        if active or goal.feedPending then
            self.adapter:stop("native feeding owns approach")
            self.phase=active and (kind=="drink" and "DRINKING" or "EATING") or "FEED_APPROACH"
            self.reason=active and "Watching actual needs during native feeding" or "Native feeding approach requested"
            if now-goal.progressAt>14 and now-(goal.feedAt or now)>14 then
                if self.adapter.cancelFeed then self.adapter:cancelFeed(state) end
                self:fail(state,"Native feeding stalled without sufficient resource increase")
            end
            return
        end
        if state.feedCan==kind then
            self.adapter:stop("native feed offer")
            if now<goal.nextAction then return end
            local sent=self.adapter:feed(state,kind)
            goal.tries+=1;goal.nextAction=now+4
            if sent then goal.feedPending=true;goal.feedAt=now;goal.progressAt=now end
            self.phase=kind=="drink" and "DRINKING" or "EATING"
            self.reason=sent and "Feed input requested; watching native approach and need" or "Feed input unavailable"
            if goal.tries>=3 then self:fail(state,"Native feed input unavailable") end
            return
        end
        if now-goal.start>240 then self:fail(state,"Survival objective timed out");return end
        if kind=="drink" then
            if not goal.location then goal.location=self.adapter:water(state);goal.locationAt=now end
            if not goal.location then self.phase="WAIT_WATER";self.reason="No streamed water access found";self.adapter:stop("no water");return end
            local d=flat(state.position,goal.location)
            if d<110 and self.adapter.waterEvidence=="LANDMARK_APPROACH" and now-(goal.refinedAt or 0)>3 then
                goal.refinedAt=now
                self.adapter.waterCache=nil
                local refined=self.adapter:water(state)
                if refined and flat(refined,goal.location)>5 then goal.location=refined;goal.arrivedAt=nil end
                d=flat(state.position,goal.location)
            end
            if d<6 and not goal.arrivedAt then goal.arrivedAt=now end
            if goal.arrivedAt and now-goal.arrivedAt>5 then
                if self.adapter.avoidWater then self.adapter:avoidWater(goal.location,now) end
                goal.location=nil;goal.arrivedAt=nil;goal.waterRetries=(goal.waterRetries or 0)+1
                if goal.waterRetries>=5 then self:fail(state,"No native drinking offer at sampled water access") end
                return
            end
            self.phase="TRAVEL_WATER";self.reason="Approaching observed water access"
            local result=self.adapter:move(goal.location,state,{navKey="WATER:"..tostring(goal.locationAt),moveRadius=4})
            if result=="STUCK" then
                if self.adapter.avoidWater then self.adapter:avoidWater(goal.location,now) end
                goal.location=nil;goal.arrivedAt=nil
            end
            return
        end
        local food=self.adapter.food and self.adapter:food(state)
        if food then
            goal.food=food;self.phase="TRAVEL_FOOD";self.reason="Approaching native edible food"
            local result=self.adapter:move(food.position,state,{navKey=food.model or "FOOD",moveRadius=2})
            if result=="REACHED" then goal.foodArrived=goal.foodArrived or now end
            if result=="STUCK" or goal.foodArrived and now-goal.foodArrived>7 then
                if food.model and self.adapter.foodBlocked then self.adapter.foodBlocked[food.model]=now+80 end
                goal.food=nil;goal.foodArrived=nil
            end
            return
        end
        if state.healthFraction<.42 then
            self.phase="WAIT_FOOD";self.reason="Health too low to hunt; watching edible food offers"
            self.adapter:stop("low health excludes hunt");return
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
        self.lastHunt=goal.hunt:status()
        if goal.hunt.kills>(goal.observedKills or 0) then
            self.hunts+=goal.hunt.kills-(goal.observedKills or 0);goal.observedKills=goal.hunt.kills
        end
    end
    return a
end
return Agent
