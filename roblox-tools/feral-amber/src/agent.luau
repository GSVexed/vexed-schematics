-- All-animal FERAL Amber Autopilot: auditable cooperative state machine.
-- Every reward/claim/feed result is observed from replication, never fabricated.
local Agent={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e10 end
local function flat(a,b)
    if not a or not b then return math.huge end
    local x,z=(a.x or 0)-(b.x or 0),(a.z or 0)-(b.z or 0)
    return math.sqrt(x*x+z*z)
end
function Agent.new(planner,adapter)
    local a={planner=planner,adapter=adapter,enabled=false,phase="OFF",goal=nil,
        cooldown={},recent={},attempts=0,events={},ticks=0,prevAmber=nil,
        earned=0,claimed=0,scented=0,feeds=0,hunts=0,failures=0,
        nextTick=0,reason="Disabled",species=nil,coat=nil}
    function a:log(at,kind,msg)
        table.insert(self.events,{at=at,kind=kind,msg=msg})
        while #self.events>100 do table.remove(self.events,1) end
    end
    function a:setEnabled(on)
        self.enabled=on==true
        if not self.enabled then
            self.goal=nil;self.phase="OFF";self.reason="Disabled"
            self.adapter:stop("disabled")
        else self.reason="Waiting for a living animal";self.nextTick=0 end
    end
    function a:fail(state,reason)
        self.failures+=1
        self.reason=reason
        local goal=self.goal
        if goal and goal.kind=="TERRITORY" and goal.key then
            self.cooldown[goal.key]=state.now+math.min(180,35+self.failures*12)
        end
        self:log(state.now,"failed",reason)
        self.goal=nil
        self.adapter:stop(reason)
    end
    function a:takeGoal(state,kind,target)
        self.adapter:stop("new goal")
        self.goal={kind=kind,key=target and target.key,detail=target,
            start=state.now,previous=state.now,nextAction=0,tries=0,
            baseline=kind=="DRINK" and state.thirst or kind=="EAT" and state.hunger or nil,
            progressAt=state.now}
        self.phase="PREPARE_"..kind
        self.reason="Starting "..kind
        self:log(state.now,"goal",kind..":"..tostring(target and target.key or "-"))
    end
    function a:status()
        return {enabled=self.enabled,phase=self.phase,reason=self.reason,
            kind=self.goal and self.goal.kind or "NONE",
            key=self.goal and self.goal.key or nil,
            claimed=self.claimed,scented=self.scented,feeds=self.feeds,
            hunts=self.hunts,failures=self.failures,earned=self.earned,
            species=self.species,coat=self.coat}
    end
    function a:tick(now)
        if not self.enabled or now<self.nextTick then return end
        self.nextTick=now+.35;self.ticks+=1
        local state=self.adapter:snapshot(now)
        if not state or not state.alive or not state.position then
            self.phase="WAIT";self.reason="Living animal unavailable"
            self.goal=nil;self.adapter:stop("despawn");return
        end
        state.now=now;self.species,self.coat=state.species,state.coat
        local changed=(self.lastCharacter and state.char~=self.lastCharacter)
            or (self.lastPack~=nil and state.pack~=self.lastPack)
            or (self.lastBiome~=nil and state.biome~=self.lastBiome)
        if changed then
            self.goal=nil
            self.adapter:stop("animal / pack / map changed")
            self.cooldown,self.recent={},{}
            self.lastTerritoryKey=nil
            self:log(now,"reset","Changed animal, pack or territory map")
        end
        self.lastCharacter,self.lastPack,self.lastBiome=state.char,state.pack,state.biome
        if state.pack==nil then
            self.phase="WAIT";self.reason="Join a pack to claim or scent territory"
            self.goal=nil;self.adapter:stop("no pack");return
        end
        if finite(state.amber) then
            if finite(self.prevAmber) and state.amber>self.prevAmber then
                local delta=state.amber-self.prevAmber
                self.earned+=delta
                self:log(now,"amber","replicated Amber increased by "..tostring(delta))
            end
            self.prevAmber=state.amber
        end
        -- Panels being visible do not mean the player is steering; keep travel
        -- active while checking progress in Renaissance or Amber. Yield only
        -- to actual physical input, text focus and native game actions.
        if state.manualInput or (state.combat and (not self.goal or self.goal.kind~="EAT"))
            or state.ability or state.pinned or state.resting or state.flying or state.swimming or state.underwater then
            self.phase="PAUSED";self.reason="Yielding to manual movement/combat/ability"
            self.adapter:stop("native action / manual control")
            return
        end
        if type(state.players)=="table" then
            for _,p in ipairs(state.players) do
                if flat(state.position,p)< (state.avoidRadius or 110) then
                    self.phase="PAUSED";self.reason="Player nearby"
                    self.adapter:stop("player nearby")
                    return
                end
            end
        end
        local need=self.planner.need(state)
        local goal=self.goal
        if need~="TERRITORY" and (not goal or goal.kind~=need) then
            self:takeGoal(state,need)
            goal=self.goal
        elseif need=="TERRITORY" and goal and goal.kind~="TERRITORY" then
            self.goal=nil;goal=nil;self.adapter:stop("needs above threshold")
        end
        if not goal then
            if need=="TERRITORY" then
                local opts={currentKey=self.lastTerritoryKey,
                    currentStarted=self.currentTerritoryStarted,blockedUntil=self.cooldown,
                    recent=self.recent,avoidRadius=state.avoidRadius or 110,
                    maxStops=5}
                local route=self.planner.plan(self.adapter:territories(state),state,opts)
                if #route==0 then
                    self.phase="WATCH";self.reason="No eligible safe territory objective"
                    self.adapter:stop("no target")
                    return
                end
                self:takeGoal(state,"TERRITORY",route[1])
                self.lastTerritoryKey=route[1].key
                self.currentTerritoryStarted=now
            else
                self:takeGoal(state,need)
            end
            goal=self.goal
        end
        if goal.kind=="RECOVER" then
            self.phase="RECOVER";self.reason="Waiting for out-of-combat recovery"
            self.adapter:stop("low health")
            return
        end
        if goal.kind=="TERRITORY" then
            local native=self.adapter:territory(goal.key,state)
            if not native then self:fail(state,"Territory state missing");return end
            if native.neutral then self:fail(state,"Neutral area is not claimable");return end
            local owned=native.owner==state.pack
            local done=goal.detail.kind=="SCENT" and owned
                and finite(native.hold) and native.hold>=.96
                or goal.detail.kind=="CLAIM" and owned
            if done then
                if goal.detail.kind=="SCENT" then self.scented+=1 else self.claimed+=1 end
                self.recent[goal.key]=now
                self:log(now,"confirmed","Replicated "..goal.detail.kind.." completed: "..goal.key)
                self.adapter:stop("replicated complete")
                self.goal=nil;self.phase="CONFIRMED";self.reason="Confirmed "..goal.detail.kind
                return
            end
            local waypoint=self.adapter:territorySpot(goal.key,state)
            if not waypoint then self:fail(state,"No reachable native territory spot");return end
            local d=flat(state.position,waypoint)
            if d> (state.claimRadius or 14) then
                self.phase="TRAVEL";self.reason=goal.detail.kind.." "..goal.key
                local status=self.adapter:move(waypoint,state)
                if status=="STUCK" then self:fail(state,"Walking route stalled: "..goal.key) end
                return
            end
            self.adapter:stop("at territory")
            self.phase="CLAIMING";self.reason="Waiting for replicated "..goal.detail.kind
            if finite(native.prog) and native.by==state.pack and native.prog>(goal.lastProg or 0)+.002 then
                goal.progressAt=now
            end
            if finite(native.hold) and native.hold>(goal.lastHold or 0)+.002 then goal.progressAt=now end
            goal.lastProg,goal.lastHold=native.prog,native.hold
            if now-goal.progressAt>20 and (goal.alternates or 0)<3 then
                -- Do not abandon valid hexes just because the first ground
                -- position missed a native claim circle. Try nearby walkable
                -- surface points in the SAME hex after a real timeout.
                goal.alternates=(goal.alternates or 0)+1
                goal.progressAt=now
                self.adapter:advanceSpot(goal.key)
                self.adapter:stop("alternate claim position")
                self.phase="REPOSITION"
                self.reason="Trying alternate walkable claim spot in "..goal.key
                self:log(now,"alternate","Native claim zone recheck "..goal.key)
            elseif now-goal.progressAt>32 or now-goal.start>165 then
                self:fail(state,"No confirmed territory progress: "..goal.key)
            end
            return
        end
        if goal.kind=="DRINK" then
            local value=state.thirst
            if finite(value) and (value>= (state.careTarget or 68)
                or finite(goal.baseline) and value>=goal.baseline+12
                    and state.feedMode~="drink" and state.feedMode~=true) then
                self.feeds+=1;self.goal=nil;self.phase="CONFIRMED"
                self.reason="Thirst actually increased";self.adapter:stop("drink confirmed");return
            end
            local water=self.adapter:water(state)
            if not water then self.phase="WAIT_WATER";self.reason="No safe drinking shore detected";return end
            if state.feedCan=="drink" then
                self.phase="DRINKING";self.adapter:stop("native drink opportunity")
                if state.feedMode=="drink" or state.feedMode==true then
                    self.reason="Native drink session active; watching thirst"
                elseif now>=goal.nextAction then
                    local ok=self.adapter:feed(state,"drink")
                    goal.tries+=1;goal.nextAction=now+5
                    self.reason=ok and "Native drink input; checking thirst" or "Drink input unavailable"
                end
            else
                self.phase="TRAVEL_WATER";self.reason="Approaching water by surface route"
                if self.adapter:move(water,state)=="STUCK" then
                    self:fail(state,"Drinking shore path blocked")
                end
            end
            if now-goal.start>120 or goal.tries>7 then
                self:fail(state,"Drinking failed to increase thirst")
            end
            return
        end
        if goal.kind=="EAT" then
            if finite(state.hunger) and (state.hunger>= (state.careTarget or 68)
                or finite(goal.baseline) and state.hunger>=goal.baseline+12
                    and state.feedMode~="eat" and state.feedMode~=true) then
                self.feeds+=1;self.goal=nil;self.phase="CONFIRMED"
                self.reason="Hunger actually increased";self.adapter:stop("food confirmed");return
            end
            if state.feedCan=="eat" then
                self.phase="EATING";self.adapter:stop("native food opportunity")
                if state.feedMode=="eat" or state.feedMode==true then
                    self.reason="Native eating session active; watching hunger"
                elseif now>=goal.nextAction then
                    local ok=self.adapter:feed(state,"eat")
                    goal.tries+=1;goal.nextAction=now+5
                    self.reason=ok and "Native eat input; checking hunger" or "Eat input unavailable"
                end
            else
                if goal.prey and goal.prey.hum and goal.prey.hum.Health<=0
                    and not goal.preyKilled then
                    goal.preyKilled=true;goal.killAt=now
                    self.hunts+=1
                    self.adapter:stop("observed NPC health reached zero")
                    self:log(now,"hunt","NPC health reached zero; waiting for edible offer")
                end
                if goal.preyKilled and now-(goal.killAt or now)<8 then
                    self.phase="WAIT_FOOD"
                    self.reason="Prey down; waiting for native FeedCan eat offer"
                    return
                end
                if goal.preyKilled then goal.prey=nil;goal.preyKilled=false end
                local prey=goal.prey and self.adapter:checkPrey(goal.prey,state)
                if not prey then
                    prey=self.adapter:prey(state)
                    goal.prey=prey
                    if prey then self:log(now,"prey","NPC prey selected (no players)") end
                end
                if not prey then
                    self.phase="WAIT_FOOD";self.reason="No suitable NPC prey; waiting for edible food"
                    self.adapter:stop("no suitable prey")
                else
                    local d=flat(state.position,prey.position)
                    if d> (prey.attackRange or 9) then
                        self.phase="HUNT_APPROACH"
                        self.reason="Approaching eligible NPC prey via ground route"
                        if self.adapter:move(prey.position,state)=="STUCK" then
                            goal.prey=nil;goal.nextAction=now+5
                        end
                    else
                        self.phase="HUNT_ATTACK"
                        self.adapter:stop("attack range")
                        if now>=goal.nextAction then
                            local ok=self.adapter:bite(state,prey)
                            goal.tries+=1;goal.nextAction=now+1.35
                            self.reason=ok and "Native bite attempted; awaiting prey state" or "Attack input unavailable"
                        end
                    end
                end
            end
            if now-goal.start>145 or goal.tries>24 then
                self:fail(state,"Could not confirm eating or prey outcome")
            end
            return
        end
        self.phase="WAIT";self.reason="Unknown goal"
    end
    return a
end
return Agent
