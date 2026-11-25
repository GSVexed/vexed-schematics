-- FERAL Amber Autopilot 0.1.0 | 2026-11-25 | all species | client-only outcomes
local sources = {}
sources["planner"] = [============[
-- Grizzly Amber v1: pure objective planner. Never writes territory/game state.
-- Hex geometry, pay, owner, hold and progress are replicated native observations.
local Planner = {}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e10 end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function dist(a,b)
    if not a or not b or not finite(a.x) or not finite(a.z) or not finite(b.x) or not finite(b.z) then
        return math.huge
    end
    local dx,dz=a.x-b.x,a.z-b.z
    return math.sqrt(dx*dx+dz*dz)
end
local function pathRisk(a,b,players,avoidRadius)
    for _,p in ipairs(players or {}) do
        if finite(p.x) and finite(p.z) then
            local vx,vz=b.x-a.x,b.z-a.z
            local denom=vx*vx+vz*vz
            local t=denom>.01 and clamp(((p.x-a.x)*vx+(p.z-a.z)*vz)/denom,0,1) or 0
            local qx,qz=a.x+vx*t,a.z+vz*t
            local offset=math.sqrt((qx-p.x)^2+(qz-p.z)^2)
            if offset<avoidRadius then return true,offset end
        end
    end
    return false,math.huge
end
Planner.distance=dist
Planner.pathRisk=pathRisk

-- kind is CLAIM or SCENT. Existing claims have a minimum guard against churn.
function Planner.objective(hex,state,from,options)
    options=options or {}
    if not hex or type(hex.key)~="string" or hex.neutral or state.pack==nil
        or not hex.center or not finite(hex.center.x) or not finite(hex.center.z) then return nil end
    if (options.exclude and options.exclude[hex.key])
        or (options.blockedUntil and (options.blockedUntil[hex.key] or 0)>(state.now or 0)) then return nil end
    local owned=hex.owner==state.pack
    local hold=finite(hex.hold) and clamp(hex.hold,0,1) or nil
    local pay=finite(hex.pay) and clamp(hex.pay,1,20) or 2.5
    local kind,priority
    if owned then
        if hold==nil or hold>= (options.scentThreshold or .84) then return nil end
        kind="SCENT"
        priority=45+pay*8+(1-hold)*180
        if hold<.35 then priority+=125 end
        if finite(hex.fade) and finite(state.unixNow) then
            local seconds=hex.fade-state.unixNow
            if seconds<150 then priority+=math.max(0,150-seconds)*.32 end
        end
    else
        kind="CLAIM"
        priority=80+pay*23
        if hex.owner==nil then priority+=30 else priority-=15 end
        if hex.by==state.pack and finite(hex.prog) and hex.prog>0 then
            priority+=140+clamp(hex.prog,0,1)*100
        end
    end
    local d=dist(from,hex.center)
    if d==math.huge then return nil end
    local deny,nearest=pathRisk(from,hex.center,state.players,options.avoidRadius or 120)
    if deny and options.avoidPlayers~=false then return nil end
    local recent=options.recent and options.recent[hex.key]
    if finite(recent) and (state.now or 0)-recent<120 then priority*=.65 end
    local routeCost=1+d/320
    local score=priority/(routeCost^.74)
    if not finite(score) then return nil end
    return {key=hex.key,kind=kind,score=score,base=priority,distance=d,
        pay=pay,hold=hold,center=hex.center,nearestPlayer=nearest,
        urgency=owned and (1-(hold or 0)) or 0}
end

function Planner.plan(hexes,state,options)
    options=options or {}
    if type(hexes)~="table" or not state or not state.position then return {} end
    local route,from={},state.position
    local exclude={}
    for key,blocked in pairs(options.exclude or {}) do if blocked then exclude[key]=true end end
    local n=math.min(options.maxStops or 6,16)
    for step=1,n do
        local ranked={}
        local opt={}
        for k,v in pairs(options) do opt[k]=v end
        opt.exclude=exclude
        for _,hex in ipairs(hexes) do
            local item=Planner.objective(hex,state,from,opt)
            if item then table.insert(ranked,item) end
        end
        if #ranked==0 then break end
        table.sort(ranked,function(a,b) if a.score~=b.score then return a.score>b.score end return a.key<b.key end)
        -- One-stop lookahead rewards efficient clusters rather than global backtracking.
        local best=nil
        for j=1,math.min(7,#ranked) do
            local candidate=ranked[j]
            local forward=0
            if step<n then
                local lookOpt={}
                for k,v in pairs(opt) do lookOpt[k]=v end
                local skip={}
                for k,v in pairs(exclude) do skip[k]=v end
                skip[candidate.key]=true
                lookOpt.exclude=skip
                for _,hex in ipairs(hexes) do
                    local other=Planner.objective(hex,state,candidate.center,lookOpt)
                    if other and other.score>forward then forward=other.score end
                end
            end
            candidate.trajectory=candidate.score+forward*.16
            if not best or candidate.trajectory>best.trajectory
                or candidate.trajectory==best.trajectory and candidate.key<best.key then best=candidate end
        end
        table.insert(route,best)
        exclude[best.key]=true
        from=best.center
    end
    if options.currentKey and options.currentKey~="" and #route>0 and route[1].key~=options.currentKey then
        -- Preserve an active objective unless it is done, dangerous or strongly outclassed.
        local current
        for _,hex in ipairs(hexes) do
            if hex.key==options.currentKey then
                current=Planner.objective(hex,state,state.position,options);break
            end
        end
        if current and current.score>=route[1].score*.73 and
            (state.now or 0)-(options.currentStarted or 0)<(options.maxCommitSeconds or 75) then
            for i=#route,1,-1 do if route[i].key==current.key then table.remove(route,i) end end
            table.insert(route,1,current)
            while #route>n do table.remove(route) end
        end
    end
    return route
end

function Planner.need(state,options)
    options=options or {}
    if not state or not finite(state.healthFraction) then return "WAIT" end
    if state.healthFraction<(options.minimumHP or .46) then return "RECOVER" end
    local h,t=state.hunger,state.thirst
    if finite(t) and t<(options.emergencyThirst or 19) then return "DRINK" end
    if finite(h) and h<(options.emergencyHunger or 19) then return "EAT" end
    if finite(t) and t<(options.thirstTrigger or 44) then return "DRINK" end
    if finite(h) and h<(options.hungerTrigger or 42) then return "EAT" end
    return "TERRITORY"
end
return Planner
]============]
sources["nav"] = [============[
-- Natural-surface navigation for Grizzly Amber. Never teleports or changes velocity.
local Nav={}
local function flat(a,b) local x,z=a.X-b.X,a.Z-b.Z;return math.sqrt(x*x+z*z) end
local function groundAt(workspace,pos,char)
    local ray=RaycastParams.new()
    ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={char}
    ray.IgnoreWater=false
    local result=workspace:Raycast(Vector3.new(pos.X,math.max(120,pos.Y+90),pos.Z),
        Vector3.new(0,-390,0),ray)
    if not result or result.Material==Enum.Material.Water or result.Normal.Y<.48 then return nil end
    return result.Position+Vector3.new(0,3,0)
end
function Nav.new(pathService,workspace)
    local n={service=pathService,workspace=workspace,destination=nil,body=nil,
        points={},index=1,issued=0,lastAt=0,lastPosition=nil,failures=0,replans=0,
        lastReason="IDLE",routeAt=0}
    function n:stop(hum,root,reason)
        if hum and root then pcall(function() hum:MoveTo(root.Position) end) end
        self.destination,self.body=nil,nil
        self.points,self.index={},1
        self.lastReason=reason or "IDLE"
    end
    function n:reset(destination,char)
        self.destination,self.body=destination,char
        self.points,self.index={},1
        self.lastAt,self.issued=0,0
        self.lastPosition=nil
        self.failures,self.replans=0,0
    end
    function n:route(root,hum,char,now)
        local from=root.Position
        local delta=self.destination-from
        local distance=flat(from,self.destination)
        local waypoint=self.destination
        if distance>145 then waypoint=from+Vector3.new(delta.X/distance*140,0,delta.Z/distance*140) end
        local surface=groundAt(self.workspace,waypoint,char)
        if not surface then
            self.lastReason="Terrain/water unavailable on surface route"
            return false
        end
        local path
        local ok=pcall(function()
            local half=math.max(root.Size.X,root.Size.Z)*.5
            local radius=math.clamp(half+1.5,2,12)
            local height=math.clamp(hum.HipHeight+root.Size.Y+2,5,30)
            path=self.service:CreatePath({AgentRadius=radius,AgentHeight=height,
                AgentCanJump=false,AgentCanClimb=false,WaypointSpacing=14})
            path:ComputeAsync(from,surface)
        end)
        local points={}
        if ok and path and path.Status==Enum.PathStatus.Success then
            for _,p in ipairs(path:GetWaypoints()) do
                if typeof(p.Position)=="Vector3" then table.insert(points,p.Position) end
            end
        end
        if #points<2 then
            -- Short straight ground steps only; never fly through streamed-out areas.
            local ray=RaycastParams.new()
            ray.FilterType=Enum.RaycastFilterType.Exclude
            ray.FilterDescendantsInstances={char}
            local hit=self.workspace:Raycast(from+Vector3.new(0,2,0),
                surface-from,ray)
            if hit and hit.Instance and not hit.Instance:IsDescendantOf(char) then
                self.lastReason="Pathfinding failed: obstacle on direct route"
                return false
            end
            points={surface}
        end
        self.points,self.index=points,1
        self.lastAt,self.lastPosition=now,from
        self.routeAt=now
        self.lastReason="SURFACE_ROUTE"
        return true
    end
    function n:tick(destination,char,hum,root,now,otherPlayers)
        if not destination or not char or not hum or not root or hum.Health<=0 then
            self:stop(hum,root,"No living animal");return "WAIT"
        end
        if not self.destination or flat(destination,self.destination)>9 or self.body~=char then
            self:reset(destination,char)
        end
        local total=flat(root.Position,destination)
        if total<16 then self:stop(hum,root,"ARRIVED");return "REACHED" end
        if type(otherPlayers)=="table" then
            for _,pos in ipairs(otherPlayers) do
                if typeof(pos)=="Vector3" and flat(pos,root.Position)<115 then
                    self:stop(hum,root,"Other player nearby");return "BLOCKED"
                end
            end
        end
        if #self.points==0 or self.index>#self.points then
            if not self:route(root,hum,char,now) then
                self.failures+=1
                if self.failures>2 then return "STUCK" end
                return "WAIT"
            end
        end
        while self.index<=#self.points and flat(root.Position,self.points[self.index])<12 do
            self.index+=1
        end
        if self.index>#self.points then
            self.points={}
            return "MOVING"
        end
        local p=self.points[self.index]
        if self.lastPosition and now-self.lastAt>6 then
            if flat(root.Position,self.lastPosition)<4.5 then
                self.replans+=1
                if self.replans>2 then self.lastReason="Stationary despite MoveTo";return "STUCK" end
                self.points={}
                self.lastAt=now
                return "WAIT"
            end
            self.lastAt=now
            self.lastPosition=root.Position
        end
        if now-self.issued>=1.75 then
            self.issued=now
            local good=pcall(function() hum:MoveTo(p) end)
            if not good then self.lastReason="Native MoveTo failed";return "STUCK" end
        end
        return "MOVING"
    end
    return n
end
return Nav
]============]
sources["agent"] = [============[
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
        if state.menuOpen or state.manualInput or (state.combat and (not self.goal or self.goal.kind~="EAT"))
            or state.ability or state.pinned or state.resting or state.flying or state.swimming or state.underwater then
            self.phase="PAUSED";self.reason="Yielding to native movement/combat/menu"
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
]============]
sources["bridge"] = [============[
-- Native FERAL data boundary; all species supported by shared territory/need logic.
-- No PivotTo, CFrame teleport, direct resource writes, or fabricated rewards.
local Bridge={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e10 end
local function point(p) return {x=p.X,z=p.Z} end
local function dist(a,b)
    local dx,dz=a.x-b.x,a.z-b.z
    return math.sqrt(dx*dx+dz*dz)
end
function Bridge.new(nav)
    local Players=game:GetService("Players")
    local Rep=game:GetService("ReplicatedStorage")
    local Workspace=game:GetService("Workspace")
    local UserInput=game:GetService("UserInputService")
    local player=assert(Players.LocalPlayer,"No local player")
    local b={player=player,Players=Players,Rep=Rep,Workspace=Workspace,
        UserInput=UserInput,nav=nav,hexes={},hexByKey={},
        cfg=nil,spots=nil,territory=nil,refreshAt=0,lastString=nil,
        lastBiome=nil,motionReason="Idle",manualUncertain=false,spotCache={},spotTry={}}
    local world=Rep:FindFirstChild("FeralWorld")
    local function config(name)
        local module=world and world:FindFirstChild(name)
        if not module or not module:IsA("ModuleScript") then return nil end
        local ok,value=pcall(require,module)
        return ok and type(value)=="table" and value or nil
    end
    b.cfg=config("TerritoryConfig")
    b.spots=config("MapSpots")
    b.territory=Rep:FindFirstChild("FeralTerritory")
    local function attr(object,key)
        if not object then return nil end
        local ok,value=pcall(function() return object:GetAttribute(key) end)
        return ok and value or nil
    end
    local function validAnimal()
        local c=player.Character
        local h=c and c:FindFirstChildOfClass("Humanoid")
        local r=c and c:FindFirstChild("HumanoidRootPart")
        return c,h,r
    end
    local function fullStats(c)
        local sp=attr(c,"Species")
        local coat=attr(c,"Coat") or attr(c,"CoatId") or attr(c,"Skin")
            or attr(player,"Coat")
        return sp,coat
    end
    function b:otherPlayerPositions()
        local all={}
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player then
                local c=p.Character
                local root=c and c:FindFirstChild("HumanoidRootPart")
                if root then table.insert(all,point(root.Position)) end
            end
        end
        return all
    end
    function b:refresh(now)
        if not self.cfg or not self.territory then
            world=Rep:FindFirstChild("FeralWorld")
            self.cfg=config("TerritoryConfig")
            self.spots=config("MapSpots")
            self.territory=Rep:FindFirstChild("FeralTerritory")
            if not self.cfg or not self.territory then return end
        end
        local text=attr(self.territory,"Hexes")
        local biome=attr(Workspace,"FeralBiome") or "WolfValley"
        if type(text)~="string" or #text==0 or type(self.cfg.parseHexes)~="function"
            or type(self.cfg.hexCenter)~="function" then return end
        if text==self.lastString and biome==self.lastBiome then return end
        self.lastString,self.lastBiome=text,biome
        self.spotCache,self.spotTry={},{}
        local ok,parsed=pcall(self.cfg.parseHexes,text)
        if not ok or type(parsed)~="table" then return end
        local hexes,byKey={},{}
        for _,t in ipairs(parsed) do
            if type(t.key)=="string" and type(t.i)=="number" and type(t.j)=="number" then
                local good,p=pcall(self.cfg.hexCenter,t.i,t.j)
                if good and typeof(p)=="Vector2" then
                    local h={key=t.key,center={x=p.X,z=p.Y}}
                    table.insert(hexes,h);byKey[t.key]=h
                end
            end
        end
        local landmarks=self.spots and (self.spots[biome] or self.spots.WolfValley)
        if type(landmarks)=="table" and type(self.cfg.hexAt)=="function" then
            for _,spot in ipairs(landmarks) do
                if typeof(spot.pos)=="Vector2" then
                    local good,i,j=pcall(self.cfg.hexAt,spot.pos.X,spot.pos.Y)
                    if good then
                        local key=type(self.cfg.hexKey)=="function"
                            and self.cfg.hexKey(i,j) or ("H"..tostring(i).."_"..tostring(j))
                        local h=byKey[key]
                        if h and not h.spot then h.spot={x=spot.pos.X,z=spot.pos.Y} end
                    end
                end
            end
        end
        self.hexes,self.hexByKey=hexes,byKey
    end
    local function terrAttr(key,suffix)
        local t=b.territory
        return attr(t,key.."_"..suffix)
    end
    function b:territory(key)
        if not self.territory then return nil end
        local h=self.hexByKey[key]
        if not h then return nil end
        return {key=key,neutral=terrAttr(key,"neutral")==true,
            owner=terrAttr(key,"owner"),by=terrAttr(key,"by"),
            prog=terrAttr(key,"prog"),hold=terrAttr(key,"hold"),
            pay=terrAttr(key,"pay") or terrAttr(key,"income") or terrAttr(key,"amber"),
            fade=terrAttr(key,"fade"),center=h.center,spot=h.spot}
    end
    function b:territories(state)
        self:refresh(state.now)
        local list={}
        for _,h in ipairs(self.hexes) do
            local t=self:territory(h.key)
            if t then table.insert(list,t) end
        end
        return list
    end
    function b:counts(state)
        local pack=state and state.pack or attr(player,"FeralPack")
        local result={total=0,eligible=0,neutral=0,owned=0,other=0,fading=0}
        for _,hex in ipairs(self:territories(state or {now=os.clock()})) do
            result.total+=1
            if hex.neutral then
                result.neutral+=1
            else
                result.eligible+=1
                if pack~=nil and hex.owner==pack then
                    result.owned+=1
                    if finite(hex.hold) and hex.hold<.84 then result.fading+=1 end
                else result.other+=1 end
            end
        end
        return result
    end
    local function groundAt(x,z,c)
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={c}
        params.IgnoreWater=false
        local hit=Workspace:Raycast(Vector3.new(x,2200,z),Vector3.new(0,-4400,0),params)
        if hit and hit.Material~=Enum.Material.Water and hit.Normal.Y>.5 then
            return hit.Position+Vector3.new(0,2.5,0)
        end
        return nil
    end
    -- Native hex geometry contains the entire territory pool; MapSpots is
    -- supplemental, not a whitelist. Sample walkable ground inside each hex,
    -- favouring genuine named claim zones where one exists.
    function b:territorySpot(key,state)
        local h=self.hexByKey[key]
        if not h then return nil end
        local cached=self.spotCache[key]
        if cached and (self.spotTry[key] or 0)==cached.index then return cached.pos end
        local c=player.Character
        local focus=h.spot or h.center
        local candidate={focus}
        if not h.spot then
            -- Hex-only territories have no landmark; use their hex centre.
            candidate={h.center}
        end
        local ring={12,25,40,57,75}
        for _,radius in ipairs(ring) do
            for direction=0,11 do
                local angle=direction*math.pi/6
                table.insert(candidate,{x=focus.x+math.cos(angle)*radius,
                    z=focus.z+math.sin(angle)*radius})
            end
        end
        if h.spot then table.insert(candidate,h.center) end
        local viable={}
        local native=self.cfg
        for _,p in ipairs(candidate) do
            local matching=true
            if type(native.hexAt)=="function" then
                local ok,i,j=pcall(native.hexAt,p.x,p.z)
                if not ok then matching=false else
                    local hexKey
                    if type(native.hexKey)=="function" then
                        local good,keyResult=pcall(native.hexKey,i,j)
                        if good then hexKey=keyResult end
                    else
                        hexKey="H"..tostring(i).."_"..tostring(j)
                    end
                    matching=hexKey==key
                end
            end
            if matching and (not h.spot or dist(p,h.spot)<108) then
                local ground=groundAt(p.x,p.z,c)
                if ground then
                    local q=point(ground)
                    local clear=true
                    for _,other in ipairs(state and state.players or {}) do
                        if dist(q,other)<(state.avoidRadius or 110) then clear=false;break end
                    end
                    if clear then table.insert(viable,q) end
                end
            end
        end
        if #viable==0 then return nil end
        -- Walkable alternative landing slots are used only after a genuine
        -- no-progress timeout, never to teleport or change hex ownership.
        local index=math.min(1+(self.spotTry[key] or 0),#viable)
        local position=viable[index]
        self.spotCache[key]={index=self.spotTry[key] or 0,pos=position}
        return position
    end
    function b:advanceSpot(key)
        if not self.hexByKey[key] then return end
        self.spotTry[key]=math.min(3,(self.spotTry[key] or 0)+1)
        self.spotCache[key]=nil
    end
    function b:water(state)
        local char=player.Character
        local biome=attr(Workspace,"FeralBiome") or "WolfValley"
        local landmarks=self.spots and (self.spots[biome] or self.spots.WolfValley)
        if type(landmarks)~="table" then return nil end
        local best,bestScore=nil,math.huge
        for _,spot in ipairs(landmarks) do
            local name=string.lower(tostring(spot.name or spot.key or ""))
            if typeof(spot.pos)=="Vector2" and
                (name:find("water",1,true) or name:find("lake",1,true)
                or name:find("pond",1,true) or name:find("river",1,true)
                or name:find("falls",1,true) or name:find("spring",1,true)) then
                for k=0,11 do
                    local angle=k*math.pi/6
                    local x=spot.pos.X+math.cos(angle)*22
                    local z=spot.pos.Y+math.sin(angle)*22
                    local land=groundAt(x,z,char)
                    if land then
                        local candidate=point(land)
                        local d=dist(candidate,state.position)
                        local blocked=false
                        for _,p in ipairs(state.players or {}) do
                            if dist(p,candidate)<120 then blocked=true;break end
                        end
                        if not blocked and d<bestScore then best,bestScore=candidate,d end
                    end
                end
            end
        end
        return best
    end
    function b:snapshot(now)
        local c,h,r=validAnimal()
        local species,coat=fullStats(c)
        local alive=c~=nil and c.Parent~=nil and h~=nil and r~=nil and h.Health>0
        if not alive then return {alive=false,species=species,coat=coat} end
        self:refresh(now)
        local nowServer
        pcall(function() nowServer=Workspace:GetServerTimeNow() end)
        local untilCombat=attr(player,"FeralCombatUntil")
        local typing=UserInput:GetFocusedTextBox()~=nil
        local movingKeys={Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,
            Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.Left,Enum.KeyCode.Right}
        local manual=typing
        for _,key in ipairs(movingKeys) do
            local ok,down=pcall(UserInput.IsKeyDown,UserInput,key)
            if ok and down then manual=true;break end
        end
        local combat=finite(nowServer) and finite(untilCombat) and untilCombat>nowServer or false
        local power=attr(c,"FeralRolling")==true or attr(c,"FeralDowned")==true
            or attr(c,"FeralVenomDown")==true or attr(c,"FeralTalonLock")~=nil
            or attr(c,"FeralTumbleAt")~=nil or attr(c,"FeralDeathRollLocal")==true
        local amber=attr(player,"Amber")
        if not finite(amber) then
            local stats=player:FindFirstChild("leaderstats")
            local v=stats and stats:FindFirstChild("Amber")
            if v and typeof(v.Value)=="number" then amber=v.Value end
        end
        local hub=(type(getgenv)=="function" and getgenv() or _G).FERAL_RENAISSANCE_ACTIVE
        local menu=attr(player,"FeralMenuOpen")==true
            or hub and hub.policy and hub.policy.menuOpen==true
        return {alive=true,char=c,hum=h,root=r,position=point(r.Position),
            species=species,coat=coat,pack=attr(player,"FeralPack"),
            healthFraction=h.MaxHealth>0 and h.Health/h.MaxHealth or 0,
            hunger=attr(c,"Hunger"),thirst=attr(c,"Thirst"),feedCan=attr(c,"FeedCan"),
            feedMode=attr(c,"WolfFeed"),
            amber=amber,now=now,unixNow=os.time(),players=self:otherPlayerPositions(),
            avoidRadius=110,claimRadius=17,careTarget=65,menuOpen=menu or typing,
            manualInput=manual,combat=combat,pinned=attr(c,"FeralPinned")==true
                or attr(c,"FeralDragged")==true or attr(c,"FeralCarried")==true,
            ability=power,resting=attr(c,"WolfRest")==true,
            flying=attr(c,"FeralFlyLocal")==true,
            swimming=attr(c,"FeralSwimLocal")==true,
            underwater=attr(c,"FeralUnderwater")==true}
    end
    function b:move(destination,state)
        if not destination then return "WAIT" end
        -- Pathfinding and Humanoid:MoveTo are the only movement writers.
        local target=Vector3.new(destination.x,state.root.Position.Y,destination.z)
        local players={}
        for _,p in ipairs(state.players or {}) do
            table.insert(players,Vector3.new(p.x,state.root.Position.Y,p.z))
        end
        local result=self.nav:tick(target,state.char,state.hum,state.root,state.now,players)
        self.motionReason=self.nav.lastReason
        return result
    end
    function b:stop(reason)
        self.motionReason=reason
        local c,h,r=validAnimal()
        self.nav:stop(h,r,reason)
    end
    function b:feed(state,kind)
        if state.feedCan~=kind then return false end
        if state.menuOpen or state.manualInput then return false end
        local ok,virtual=pcall(function() return game:GetService("VirtualInputManager") end)
        if ok and virtual then
            local sent=pcall(function()
                virtual:SendKeyEvent(true,Enum.KeyCode.E,false,game)
                task.wait(.07)
                virtual:SendKeyEvent(false,Enum.KeyCode.E,false,game)
            end)
            if sent then return true end
        end
        if type(keypress)=="function" and type(keyrelease)=="function" then
            return pcall(function() keypress(0x45);task.wait(.07);keyrelease(0x45) end)
        end
        return false
    end
    local function alliedNPC(model)
        local mine=attr(player,"FeralPack")
        local pack=attr(model,"FeralPack")
        return mine~=nil and pack~=nil and mine==pack
    end
    local hunters={Bear=true,Wolf=true,Tiger=true,Lion=true,Jaguar=true,Cobra=true,
        KingCobra=true,Crocodile=true,SaltwaterCrocodile=true,Alligator=true,
        BaldEagle=true,Eagle=true,Vulture=true,Leopard=true,Hyena=true,
        Fox=true,Python=true,Otter=true}
    function b:checkPrey(prey,state)
        if not prey or not prey.model or not prey.model.Parent
            or not hunters[state.species] then return nil end
        if Players:GetPlayerFromCharacter(prey.model) then return nil end
        local root=prey.model:FindFirstChild("HumanoidRootPart")
        local hum=prey.model:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health<=0 or attr(prey.model,"FeralDead")==true
            or alliedNPC(prey.model) then return nil end
        if hum.MaxHealth>state.hum.MaxHealth*1.2 then return nil end
        local position=point(root.Position)
        for _,p in ipairs(state.players or {}) do
            if dist(position,p)<100 then return nil end
        end
        prey.position=position;prey.root=root;prey.hum=hum
        return prey
    end
    function b:prey(state)
        if not hunters[state.species] then return nil end
        local folder=Workspace:FindFirstChild("FeralNPCs")
        if not folder then return nil end
        local best,bestDist=nil,math.huge
        for i,npc in ipairs(folder:GetChildren()) do
            if i>96 then break end
            if npc:IsA("Model") then
                local p=self:checkPrey({model=npc},state)
                if p then
                    local d=dist(p.position,state.position)
                    if d<270 and d<bestDist then best,bestDist=p,d end
                end
            end
        end
        return best
    end
    function b:bite(state,prey)
        local p=self:checkPrey(prey,state)
        if not p then return false end
        local direction=p.root.Position-state.root.Position
        local planar=Vector3.new(direction.X,0,direction.Z)
        if planar.Magnitude<.1 or planar.Magnitude>22 then return false end
        local forward=state.root.CFrame.LookVector
        local flat=Vector3.new(forward.X,0,forward.Z)
        if flat.Magnitude<.1 or flat.Unit:Dot(planar.Unit)<.35 then
            -- Natural rotation occurs during a MoveTo approach, never PivotTo.
            self:move(p.position,state)
            return false
        end
        local ok,virtual=pcall(function() return game:GetService("VirtualInputManager") end)
        if ok and virtual then
            local m=UserInput:GetMouseLocation()
            local sent=pcall(function()
                virtual:SendMouseButtonEvent(m.X,m.Y,0,true,game,0)
                task.wait(.04)
                virtual:SendMouseButtonEvent(m.X,m.Y,0,false,game,0)
            end)
            if sent then return true end
        end
        if type(mouse1click)=="function" then return pcall(mouse1click) end
        return false
    end
    return b
end
return Bridge
]============]
sources["ui"] = [============[
-- Compact independent Amber control. Right Shift remains owned by Renaissance.
local UI={}
local function text(parent,size,x,y,w,h,colour)
    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1
    t.Font=Enum.Font.Gotham
    t.TextSize=size
    t.TextColor3=colour or Color3.fromRGB(220,240,233)
    t.TextXAlignment=Enum.TextXAlignment.Left
    t.TextYAlignment=Enum.TextYAlignment.Center
    t.Position=UDim2.fromOffset(x,y)
    t.Size=UDim2.fromOffset(w,h)
    t.Text=""
    t.Parent=parent
    return t
end
local function button(parent,label,x,y,width,callback)
    local b=Instance.new("TextButton")
    b.Name=label:gsub("[^%w]","")
    b.Position=UDim2.fromOffset(x,y)
    b.Size=UDim2.fromOffset(width,28)
    b.BackgroundColor3=Color3.fromRGB(45,79,79)
    b.BorderSizePixel=0
    b.Font=Enum.Font.GothamMedium
    b.TextSize=11
    b.TextColor3=Color3.fromRGB(240,252,247)
    b.Text=label
    b.Parent=parent
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    b.Activated:Connect(callback)
    return b
end
function UI.new(agent,bridge)
    local pg=bridge.player:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil,"PlayerGui not ready" end
    local prior=pg:FindFirstChild("FeralAmberAutopilot")
    if prior then prior:Destroy() end
    local gui=Instance.new("ScreenGui")
    gui.Name="FeralAmberAutopilot"
    gui.ResetOnSpawn=false
    gui.DisplayOrder=180
    gui.Parent=pg
    local frame=Instance.new("Frame")
    frame.Name="AmberPanel"
    frame.Position=UDim2.new(1,-358,0,84)
    frame.Size=UDim2.fromOffset(340,141)
    frame.BackgroundColor3=Color3.fromRGB(20,29,31)
    frame.BorderSizePixel=0
    frame.Parent=gui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,8)
    local border=Instance.new("UIStroke")
    border.Thickness=1;border.Color=Color3.fromRGB(61,91,88);border.Parent=frame
    local header=text(frame,13,12,8,270,22,Color3.fromRGB(230,204,130))
    header.Font=Enum.Font.GothamBold
    header.Text="FERAL AMBER  ·  AUTOPILOT"
    local mode=text(frame,11,12,34,320,21)
    local info=text(frame,11,12,56,320,21)
    local reason=text(frame,10,12,77,320,22,Color3.fromRGB(184,207,201))
    reason.TextTruncate=Enum.TextTruncate.AtEnd
    local running=false
    local ui={gui=gui,frame=frame,agent=agent,bridge=bridge,lastUpdate=0,collapsed=false}
    local start
    start=button(frame,"START",12,106,87,function()
        agent:setEnabled(not agent.enabled)
        start.Text=agent.enabled and "STOP" or "START"
    end)
    local copyStatus=button(frame,"COPY STATUS",108,106,125,function()
        local status=agent:status()
        status.coat=type(status.coat)=="string" and status.coat or nil
        status.events=agent.events
        status.gameVersion=game.PlaceVersion
        status.territoryCount=#(bridge.hexes or {})
        local ok,payload=pcall(function()
            return game:GetService("HttpService"):JSONEncode(status)
        end)
        if ok then
            if type(setclipboard)=="function" then pcall(setclipboard,payload) end
            print("[FERAL AMBER STATUS] "..payload)
        end
    end)
    local collapse
    collapse=button(frame,"HIDE",244,106,84,function()
        ui.collapsed=not ui.collapsed
        if ui.collapsed then
            frame.Size=UDim2.fromOffset(340,34)
            start.Visible=false;copyStatus.Visible=false;mode.Visible=false;info.Visible=false;reason.Visible=false
            collapse.Text="OPEN";collapse.Position=UDim2.fromOffset(258,3)
        else
            frame.Size=UDim2.fromOffset(340,141)
            start.Visible=true;copyStatus.Visible=true;mode.Visible=true;info.Visible=true;reason.Visible=true
            collapse.Text="HIDE";collapse.Position=UDim2.fromOffset(244,106)
        end
    end)
    function ui:tick(now)
        if now-self.lastUpdate<.75 then return end
        self.lastUpdate=now
        local st=agent:status()
        local snap=bridge:snapshot(now)
        start.Text=st.enabled and "STOP" or "START"
        mode.Text=(st.enabled and "RUNNING · " or "OFF · ")..st.phase
            ..(st.key and " · "..st.key or "")
        local counts=bridge:counts(snap)
        info.Text=string.format("Hexes %d/%d owned · %d fading · Amber +%.0f",
            counts.owned,counts.eligible,counts.fading,st.earned)
        local species=tostring(st.species or snap.species or "No animal")
        reason.Text=species.." · "..st.reason
    end
    function ui:close()
        agent:setEnabled(false)
        if gui.Parent then gui:Destroy() end
    end
    return ui
end
return UI
]============]
-- FERAL AMBER AUTOPILOT v0.1 — all-animal surface-route, territory and care engine.
-- Native client observations only. No teleportation or fake resource changes.
local EXPECTED_PLACE=108901361810209
if game.PlaceId~=EXPECTED_PLACE then
    warn("[FERAL AMBER] This addon is only for FERAL Animal Survival.")
    return nil
end
local environment=(type(getgenv)=="function" and getgenv()) or _G
local prior=environment.FERAL_AMBER_ACTIVE
if type(prior)=="table" and type(prior.close)=="function" then pcall(prior.close) end
-- Do not permit the old snap/hover controller to compete for movement ownership.
local legacy=environment.FERAL_TERRITORY_RUSH_V4
if type(legacy)=="table" and type(legacy.stop)=="function" then pcall(legacy.stop) end
local function module(name)
    local src=assert(sources[name],"Missing owned Amber module: "..tostring(name))
    local fn,why=loadstring(src,"=FERAL_AMBER_"..name)
    if not fn then error("Amber module compile failure: "..tostring(why)) end
    return fn()
end
local Planner=module("planner")
local Nav=module("nav")
local Agent=module("agent")
local Bridge=module("bridge")
local UI=module("ui")
local Players=game:GetService("Players")
local player=assert(Players.LocalPlayer,"No player in current client")
local gui=player:WaitForChild("PlayerGui",18)
if not gui then warn("[FERAL AMBER] PlayerGui unavailable. Spawn first.");return nil end
local path=game:GetService("PathfindingService")
local workspace=game:GetService("Workspace")
local nav=Nav.new(path,workspace)
local bridge=Bridge.new(nav)
local agent=Agent.new(Planner,bridge)
local panel,why=UI.new(agent,bridge)
if not panel then warn("[FERAL AMBER] "..tostring(why));return nil end
local active=true
local connection
local handle={version="0.1.0",agent=agent,bridge=bridge,nav=nav,panel=panel}
function handle.close()
    if not active then return end
    active=false
    if connection then connection:Disconnect();connection=nil end
    panel:close()
    if environment.FERAL_AMBER_ACTIVE==handle then environment.FERAL_AMBER_ACTIVE=nil end
end
function handle.setEnabled(on) agent:setEnabled(on==true) end
function handle.status() return agent:status() end
local lastError=0
connection=game:GetService("RunService").Heartbeat:Connect(function()
    if not active or handle.working then return end
    handle.working=true
    local now=os.clock()
    if agent.enabled then
        local hub=environment.FERAL_RENAISSANCE_ACTIVE
        if type(hub)=="table" and hub.walk and type(hub.stopWalk)=="function" then
            pcall(hub.stopWalk,hub,"Amber surface-navigation owner")
        end
    end
    local ok,err=pcall(agent.tick,agent,now)
    if not ok then
        agent:setEnabled(false)
        agent.phase="ERROR"
        agent.reason="Native bridge error; autopilot stopped"
        if now-lastError>4 then
            lastError=now
            warn("[FERAL AMBER] Safe stop: "..tostring(err))
        end
    end
    local good,uierr=pcall(panel.tick,panel,now)
    if not good and now-lastError>4 then lastError=now;warn("[FERAL AMBER] UI: "..tostring(uierr)) end
    handle.working=false
end)
environment.FERAL_AMBER_ACTIVE=handle
print("[FERAL AMBER 0.1] Ready. Select START in the small Amber panel; native walking, claim and care outcomes are observed, not presumed.")
return handle
