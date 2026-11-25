-- FERAL Amber Autopilot 0.4.0 | 2026-11-25 | all species | client-only outcomes
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
    local payKnown=finite(hex.pay)
    local pay=payKnown and clamp(hex.pay,1,20) or 1
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
    local waiting=options.waitingSince and options.waitingSince[hex.key]
    if finite(waiting) then priority+=math.min(180,math.max(0,(state.now or 0)-waiting)/5) end
    if finite(recent) and (state.now or 0)-recent<120 then priority*=.65 end
    local routeCost=1+d/320
    local score=priority/(routeCost^.74)
    if not finite(score) then return nil end
    return {key=hex.key,kind=kind,score=score,base=priority,distance=d,
        pay=payKnown and pay or nil,hold=hold,center=hex.center,nearestPlayer=nearest,
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
sources["gait"] = [============[
-- FERAL Amber: pure navigation/locomotion decisions, no side effects.
-- Distances in horizontal studs; angles in degrees; reserves protect stamina.
local Gait={}
local function finite(x)
    return type(x)=="number" and x==x and math.abs(x)<1e9
end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
function Gait.distance(a,b)
    if not a or not b or not finite(a.x) or not finite(a.z)
        or not finite(b.x) or not finite(b.z) then return math.huge end
    local dx,dz=a.x-b.x,a.z-b.z
    return math.sqrt(dx*dx+dz*dz)
end
function Gait.turn(previous,position,target)
    if not previous or not position or not target then return 0 end
    local ax,az=position.x-previous.x,position.z-previous.z
    local bx,bz=target.x-position.x,target.z-position.z
    local la=math.sqrt(ax*ax+az*az)
    local lb=math.sqrt(bx*bx+bz*bz)
    if la<1 or lb<1 then return 0 end
    local dot=clamp((ax*bx+az*bz)/(la*lb),-1,1)
    return math.deg(math.acos(dot))
end
-- Trot and sprint are valid across land animals; burst only when an actual
-- game input is available and enough stamina remains. Never force WalkSpeed.
function Gait.select(distance,turn,stamina,options)
    options=options or {}
    if not finite(distance) or distance<=0 then return "STOP" end
    if options.ability or options.injured then return "TROT" end
    if options.combat and not options.hunting then return "TROT" end
    if options.swimming then
        if options.swimSprint and distance>45 and (not finite(stamina) or stamina>.25) then return "SPRINT" end
        return "TROT"
    end
    if options.hunting and (options.preySpeed or 0)>6 and distance>6
        and (not finite(stamina) or stamina>=.22) and (turn or 0)<65 then return "SPRINT" end
    if distance<10 then return "WALK" end
    if distance<24 then return "TROT" end
    local reserve=finite(stamina) and stamina or nil
    local angle=finite(turn) and turn or 0
    if options.allowBurst~=false and reserve and reserve>=.56
        and distance>=170 and angle<=22 and not options.crowded
        and options.burstReady~=false then return "BURST" end
    if distance>=48 and angle<=72 and not options.crowded
        and (not reserve or reserve>=.22) then return "SPRINT" end
    return "TROT"
end

-- Stateful requests with observed HUD acknowledgements. A successful key API
-- call is only an input request. Burst and trot are native Begin toggles.
function Gait.controller(io)
    local g={requested="STOP",observed="UNKNOWN",changedAt=-100,
        attempts={},blocked={},pending=nil,lastSuccess=nil,reason="Idle",
        burstOwned=false,trotOwned=false,requests=0,confirmations=0}
    function g:step(wanted,s,now)
        s=s or {}
        local observed=s.hudBurst==true and "BURST"
            or s.hudSprint==true and "SPRINT"
            or s.hudTrot==true and "TROT"
            or s.hudSprint==false and s.hudTrot==false and s.hudBurst==false and "WALK"
            or "UNKNOWN"
        self.observed=observed
        if self.pending then
            local p=self.pending
            local confirmed=(p.mode==observed)
                or p.mode=="BURST_OFF" and s.hudBurst==false
                or p.mode=="WALK" and s.hudTrot==false and s.hudSprint==false
            if confirmed then
                self.lastSuccess=now;self.confirmations+=1
                self.attempts[p.mode]=0;self.pending=nil
                self.reason="Native gait observed"
            elseif now-p.at>=2.4 then
                local count=self.attempts[p.mode] or 1
                if count>=2 then self.blocked[p.mode]=now+18 end
                self.pending=nil;self.reason="Gait request unconfirmed"
                if p.mode=="SPRINT" then io:hold("SHIFT",false) end
                if count==1 and type(io.retryInput)=="function" then
                    io:retryInput(p.mode=="SPRINT" and "SHIFT" or p.mode=="TROT" and "Z" or "X")
                end
            end
        end
        local emergency=wanted=="STOP" or wanted=="WALK" or s.ability or s.swimming
        if wanted~=self.requested and not emergency and now-self.changedAt<2.25 then
            wanted=self.requested
        end
        if wanted=="BURST" and (type(s.hudBurst)~="boolean" or s.hudBurstNo or (self.blocked.BURST or 0)>now) then wanted="SPRINT" end
        if (wanted=="SPRINT" or wanted=="BURST") and (self.blocked.SPRINT or 0)>now then wanted="TROT" end
        if wanted~=self.requested then self.changedAt=now;self.requested=wanted end
        local fast=wanted=="SPRINT" or wanted=="BURST"
        io:hold("SHIFT",fast)
        local function request(mode,key)
            if self.pending or (self.blocked[mode] or 0)>now then return end
            local sent=key=="SHIFT" and io:hold(key,true) or io:tap(key)
            if sent then
                self.attempts[mode]=(self.attempts[mode] or 0)+1
                self.requests+=1;self.pending={mode=mode,at=now}
                self.reason="Input requested; awaiting native gait"
                if mode=="BURST" then self.burstOwned=true end
                if mode=="TROT" then self.trotOwned=true end
            else self.blocked[mode]=now+18;self.reason="Gait input unavailable" end
        end
        if wanted~="BURST" and s.hudBurst==true and self.burstOwned then
            request("BURST_OFF","X")
        elseif wanted=="BURST" and s.hudBurst==false then request("BURST","X")
        elseif fast and s.hudSprint==false and s.hudBurst~=true then request("SPRINT","SHIFT")
        elseif wanted=="TROT" and s.hudTrot==false and s.hudBurst~=true then request("TROT","Z")
        elseif wanted=="WALK" and s.hudTrot==true and self.trotOwned then request("WALK","Z") end
        return self.requested
    end
    function g:stop(s,now)
        io:hold("SHIFT",false)
        -- Undo toggles only when this controller requested them and their
        -- current native state is known. Never blindly toggle an unknown mode.
        if s and s.hudBurst==true and self.burstOwned then io:tap("X") end
        if s and s.hudTrot==true and self.trotOwned then io:tap("Z") end
        self.burstOwned,self.trotOwned=false,false
        self.pending=nil;self.requested="STOP";self.changedAt=now or 0
    end
    return g
end
function Gait.arrived(destinationDistance,claimRadius)
    if not finite(destinationDistance) then return false end
    return destinationDistance<=math.max(8,(claimRadius or 17)-2)
end
-- Keep a goal unless its progress stalls. Do not change directions on each
-- intermediate waypoint when the destination is already within claim radius.
function Gait.waypointIndex(points,index,pos,reach)
    local i=math.max(1,index or 1)
    local radius=math.max(6,reach or 11)
    while i<=#points do
        local point=points[i]
        if Gait.distance(pos,point)<=radius then i+=1
        else break end
    end
    return i
end
function Gait.progress(now,previousTime,previousDistance,currentDistance,delay,minGain)
    if not finite(previousTime) or not finite(previousDistance) then
        return "RESET" end
    if now-previousTime < (delay or 4) then return "MONITOR" end
    if previousDistance-currentDistance >= (minGain or 3) then return "ADVANCING" end
    return "STALLED"
end
return Gait
]============]
sources["nav"] = [============[
-- Continuous native steering, cancellable streamed routes and measured progress.
local Nav={}
local function flat(a,b)
    local x,z=a.X-b.X,a.Z-b.Z
    return math.sqrt(x*x+z*z)
end
local function p2(v) return {x=v.X,z=v.Z} end
local function rayParams(char)
    local p=RaycastParams.new()
    p.FilterType=Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances={char};p.IgnoreWater=false
    return p
end
function Nav.new(pathService,workspace,Gait)
    local n={service=pathService,workspace=workspace,math=Gait,held={},backends={},gaitBackends={},
        destination=nil,body=nil,points={},index=1,epoch=0,keyEpoch=0,
        lastReason="IDLE",lastFailure=nil,gait="STOP",nativeInput="UNTESTED",
        preferredStrategy="WORLD",steeringStrategy="WORLD",lastMode="WORLD",
        failures=0,replans=0,routeFailures=0,stallsInRow=0,waterRoutes=0,
        strategyChanges=0,inputVerified=false,inputAttempts=0,driveCalls=0,
        travelled=0,distance=nil,speed=0,corrections=0,segmentCount=0,arrivalRadius=8,
        lastBurstAt=-100,lastTrotAt=-100,nextRouteAt=0,closed=false}
    local bindings={W=Enum.KeyCode.W,A=Enum.KeyCode.A,S=Enum.KeyCode.S,
        D=Enum.KeyCode.D,SHIFT=Enum.KeyCode.LeftShift,X=Enum.KeyCode.X,Z=Enum.KeyCode.Z}
    local codes={W=0x57,A=0x41,S=0x53,D=0x44,SHIFT=0xA0,X=0x58,Z=0x5A}
    local function send(name,on,backend)
        if backend~="EXECUTOR" then
            local ok,v=pcall(function()return game:GetService("VirtualInputManager")end)
            if ok and v and pcall(v.SendKeyEvent,v,on,bindings[name],false,game) then return true,"VIRTUAL" end
        end
        local fn=on and keypress or keyrelease
        if type(fn)=="function" and pcall(fn,codes[name]) then return true,"EXECUTOR" end
        return false,"UNAVAILABLE"
    end
    function n:hold(name,on)
        if not bindings[name] then return false end
        if (self.held[name]==true)==on then return true end
        local ok,method=send(name,on,self.backends[name] or self.gaitBackends[name] or self.keyBackend)
        if on and ok then
            self.held[name]=true;self.backends[name]=method
            self.nativeInput=method;self.inputAttempts+=1
        elseif not on then self.held[name]=nil;self.backends[name]=nil end
        return ok
    end
    function n:tap(name)
        if self.held[name] or not self:hold(name,true) then return false end
        local epoch=self.keyEpoch
        task.delay(.09,function() if self.keyEpoch==epoch then self:hold(name,false) end end)
        return true
    end
    function n:retryInput(name)
        if type(keypress)~="function" or type(keyrelease)~="function" then return false end
        self:hold(name,false);self.gaitBackends[name]="EXECUTOR"
        return true
    end
    function n:releaseSteering()
        for _,key in ipairs({"W","A","S","D"}) do self:hold(key,false) end
    end
    function n:releaseKeys()
        self.keyEpoch+=1
        local keys={}
        for k in pairs(self.held) do table.insert(keys,k) end
        for _,k in ipairs(keys) do self:hold(k,false) end
    end
    n.gaits=Gait.controller(n)
    function n:stop(hum,root,reason)
        local active=self.desiredPoint~=nil or self.destination~=nil
        self.epoch+=1;self.pending=nil
        self.desiredPoint,self.desiredRoot,self.desiredHum=nil,nil,nil
        if active then self.gaits:stop(self.lastState,self.lastAt or 0) end
        self:releaseKeys();self.gait="STOP"
        if active and hum then pcall(hum.Move,hum,Vector3.zero,false) end
        self.destination,self.body,self.identity=nil,nil,nil
        self.points,self.index={},1;self.lastPosition=nil
        self.lastReason=reason or "IDLE"
    end
    function n:reset(destination,char,now,identity)
        self.epoch+=1;self.pending=nil
        self.destination,self.body,self.identity=destination,char,identity
        self.points,self.index={},1;self.nextRouteAt=now
        self.desiredPoint=nil;self:releaseSteering()
        self.lastProgressAt=now;self.lastPosition=nil;self.lastSampleAt=now
        self.windowAt=now;self.windowOrigin=nil;self.windowTravel=0
        self.stallsInRow,self.routeFailures,self.corrections=0,0,0
        self.inputVerified=false;self.steeringStrategy=self.preferredStrategy
        self.recoveryProgress=0
        self.lastReason="NEW_ROUTE";self.goalStarted=now
    end
    function n:surface(pos,char,allowWater)
        local hit=self.workspace:Raycast(pos+Vector3.new(0,100,0),Vector3.new(0,-420,0),rayParams(char))
        if not hit then return nil end
        local wet=hit.Material==Enum.Material.Water
        if wet and not allowWater or not wet and hit.Normal.Y<.46 then return nil end
        return hit.Position+Vector3.new(0,2.5,0),wet
    end
    function n:clearSegment(from,to,char,allowWater)
        local distance=flat(from,to)
        if distance<.1 then return true,false end
        local params=rayParams(char);params.IgnoreWater=true
        -- Terrain walls are obstacles too; never exempt Terrain from this ray.
        local hit=self.workspace:Raycast(from+Vector3.new(0,1.5,0),to-from,params)
        if hit and (not hit.Instance or hit.Instance.CanCollide~=false) then return false,false end
        local perpendicular=Vector3.new(-(to.Z-from.Z)/distance,0,(to.X-from.X)/distance)
        for _,side in ipairs({-1,1}) do
            local offset=perpendicular*(self.clearance or 2)*side
            local flank=self.workspace:Raycast(from+Vector3.new(0,1.5,0)+offset,to-from,params)
            if flank and (not flank.Instance or flank.Instance.CanCollide~=false) then return false,false end
        end
        local wet=false;local previous=nil
        local steps=math.max(1,math.ceil(distance/10))
        for step=0,steps do
            local p=from+(to-from)*(step/steps)
            local ground,water=self:surface(p,char,allowWater)
            if not ground then return false,wet end
            if previous and math.abs(ground.Y-previous.Y)>math.max(7,distance/steps*1.05) then return false,wet end
            previous=ground;wet=wet or water
        end
        return true,wet
    end
    function n:compute(from,root,hum,char,state,goal,attempt)
        local distance=flat(from,goal)
        if distance<.01 then return {},"EMPTY_ROUTE" end
        local delta=goal-from;local dir=Vector3.new(delta.X/distance,0,delta.Z/distance)
        local span=math.min(distance,100)
        local allowWater=state.allowWater==true
        local angles={0,-.45,.45,-.9,.9}
        if attempt%2==1 then angles={0,.45,-.45,.9,-.9} end
        for _,angle in ipairs(angles) do
            local length=angle==0 and span or math.min(span,55)
            local x=dir.X*math.cos(angle)-dir.Z*math.sin(angle)
            local z=dir.X*math.sin(angle)+dir.Z*math.cos(angle)
            local surface,water=self:surface(from+Vector3.new(x*length,0,z*length),char,allowWater)
            if surface then
                local clear,crossesWater=self:clearSegment(from,surface,char,allowWater)
                if clear then return {surface},(water or crossesWater or state.swimming) and "SWIM_ROUTE" or "CLEAR_SURFACE" end
                if not water and not state.swimming then
                    local ok,path=pcall(function()
                        local result=self.service:CreatePath({
                            AgentRadius=math.clamp(root.Size.X*.5+.65,2,12),
                            AgentHeight=math.clamp(hum.HipHeight+root.Size.Y+1,4,30),
                            AgentCanJump=false,AgentCanClimb=false,WaypointSpacing=16})
                        result:ComputeAsync(from,surface)
                        return result
                    end)
                    if ok and path.Status==Enum.PathStatus.Success then
                        local points={}
                        for _,p in ipairs(path:GetWaypoints()) do
                            if typeof(p.Position)=="Vector3" and flat(p.Position,from)>2 then table.insert(points,p.Position) end
                        end
                        if #points>0 then return points,"PATH_SURFACE" end
                    end
                end
            end
        end
        return nil,"NO_STREAMED_SAFE_ROUTE"
    end
    function n:route(root,hum,char,now,state)
        if self.pending or now<self.nextRouteAt then return end
        local epoch=self.epoch
        local request={at=now,epoch=epoch,origin=root.Position,goal=self.destination}
        self.pending=request
        task.spawn(function()
            local ok,points,reason=pcall(self.compute,self,request.origin,root,hum,char,
                table.clone(state or {}),request.goal,self.replans)
            if self.closed or self.epoch~=epoch or self.pending~=request then return end
            self.pending=nil
            if not ok or not points then
                self.routeFailures+=1;self.failures+=1
                self.lastFailure=ok and reason or "PATH_COMPUTATION_ERROR"
                self.lastReason=self.lastFailure;self.nextRouteAt=now+1.5
                return
            end
            -- An old path cannot pull a moving animal back toward its old start.
            if not root.Parent or self.body~=char then return end
            self.points,self.index=points,1;self.routeOrigin=request.origin
            self.segmentCount+=1;self.routeFailures=0
            self.routeAt=now;self.lastReason=reason
            self.routeWater=reason=="SWIM_ROUTE"
            if self.routeWater then self.waterRoutes+=1 end
        end)
    end
    function n:direction()
        local root,hum,p=self.desiredRoot,self.desiredHum,self.desiredPoint
        if not root or not hum or not p or not root.Parent or hum.Health<=0 then return nil end
        local delta=Vector3.new(p.X-root.Position.X,0,p.Z-root.Position.Z)
        if delta.Magnitude<=self.arrivalRadius and flat(root.Position,self.destination or p)<=self.arrivalRadius then return Vector3.zero end
        if delta.Magnitude<.1 then return Vector3.zero end
        return delta.Unit
    end
    function n:drive()
        self.driveCalls+=1
        local direction=self:direction()
        if not direction then self:releaseSteering();return end
        if self.steeringStrategy=="WORLD" then
            self:releaseSteering();self.desiredHum:Move(direction,false)
            self.lastMode="WORLD";return
        end
        local camera=self.workspace.CurrentCamera
        if not camera then self:releaseSteering();self.lastFailure="NO_CAMERA";return end
        local f,r=camera.CFrame.LookVector,camera.CFrame.RightVector
        f=Vector3.new(f.X,0,f.Z);r=Vector3.new(r.X,0,r.Z)
        if f.Magnitude<.1 or r.Magnitude<.1 then self:releaseSteering();return end
        local forward,side=direction:Dot(f.Unit),direction:Dot(r.Unit)
        -- Eight directions avoid the four-direction fallback's square orbit.
        local keys={W=forward>.38,S=forward<-.38,D=side>.38,A=side<-.38}
        for key,on in pairs(keys) do self:hold(key,on) end
        self.lastMode="NATIVE_KEYS"
    end
    function n:advance(root,radius)
        local advanced=false
        while self.index<=#self.points do
            local p=self.points[self.index]
            local last=self.index==#self.points
            local goalNear=last and self.destination and flat(p,self.destination)<3
            local reach=goalNear and self.arrivalRadius or radius
            local near=flat(root.Position,p)<=reach
            local prev=self.points[self.index-1] or self.routeOrigin
            local passed=false
            if prev and not goalNear then
                local dx,dz=p.X-prev.X,p.Z-prev.Z;local len=math.sqrt(dx*dx+dz*dz)
                if len>.1 then
                    local beyond=((root.Position.X-p.X)*dx+(root.Position.Z-p.Z)*dz)/len
                    local cross=math.abs((root.Position.X-p.X)*dz-(root.Position.Z-p.Z)*dx)/len
                    passed=beyond>0 and cross<radius*1.4
                end
            end
            if near or passed then self.index+=1;advanced=true else break end
        end
        return advanced
    end
    function n:tick(destination,char,hum,root,now,otherPlayers,state)
        state=state or {};self.lastState=state;self.lastAt=now
        if self.closed or not destination or not char or not hum or not root or hum.Health<=0 then
            self:stop(hum,root,"NO_LIVING_ANIMAL");return "WAIT"
        end
        local identity=state.navKey or "STATIC"
        self.clearance=math.clamp(root.Size.X*.5+.65,2,12)
        if not self.destination or self.body~=char or self.identity~=identity then self:reset(destination,char,now,identity) end
        local targetShift=flat(destination,self.destination)
        self.destination=destination
        self.arrivalRadius=state.moveRadius or 8
        local total=flat(root.Position,destination);self.distance=total
        if total<=self.arrivalRadius then self:stop(hum,root,"ARRIVED");return "REACHED" end
        for _,p in ipairs(otherPlayers or {}) do
            if flat(root.Position,p)<(state.avoidRadius or 110) then
                self:stop(hum,root,"PLAYER_NEARBY");return "BLOCKED"
            end
        end
        local dt=now-(self.lastSampleAt or now)
        if self.lastPosition and dt>0 then
            local moved=flat(root.Position,self.lastPosition)
            if moved>math.max(90,(self.speed or 0)*dt*3+35) then
                self.corrections+=1;self.points={};self.epoch+=1;self.pending=nil
                self.desiredPoint=nil;self:releaseSteering()
                self.lastFailure="POSITION_CORRECTION";self.lastProgressAt=now
                if self.corrections>=3 then self:stop(hum,root,"REPEATED_CORRECTIONS");return "STUCK" end
            else
                self.travelled+=moved;self.windowTravel+=moved
                self.speed=self.speed*.6+math.min(180,moved/dt)*.4
                local wp=self.points[self.index]
                if wp and flat(self.lastPosition,wp)-flat(root.Position,wp)>.45 then
                    self.lastProgressAt=now;self.inputVerified=true
                    self.recoveryProgress+=moved
                    if self.recoveryProgress>15 then self.stallsInRow=0 end
                end
            end
        end
        self.lastPosition=root.Position;self.lastSampleAt=now
        self.windowOrigin=self.windowOrigin or root.Position
        if now-self.windowAt>=6 then
            if self.windowTravel>35 and flat(root.Position,self.windowOrigin)<6 then
                self.lastProgressAt=math.min(self.lastProgressAt,now-6)
                self.lastFailure="OSCILLATION"
            end
            self.windowOrigin=root.Position;self.windowTravel=0;self.windowAt=now
        end
        local advanced=self:advance(root,math.clamp(root.Size.X*.5+4,6,12))
        if advanced then self.lastProgressAt=now;self.inputVerified=true end
        if self.pending and now-self.pending.at>12 then
            self.epoch+=1;self.pending=nil;self.routeFailures+=1
            self.lastFailure="PATH_TIMEOUT"
        end
        if self.routeFailures>=4 then self:stop(hum,root,self.lastFailure);return "STUCK" end
        if now-self.lastProgressAt>5 then
            self.stallsInRow+=1;self.replans+=1;self.lastProgressAt=now
            self.recoveryProgress=0
            self.points={};self.epoch+=1;self.pending=nil;self.desiredPoint=nil
            self:releaseSteering();self:hold("SHIFT",false)
            self.lastFailure=self.lastFailure=="OSCILLATION" and self.lastFailure or "NO_PHYSICAL_PROGRESS"
            if self.stallsInRow==1 and self.steeringStrategy=="WORLD" then
                self.steeringStrategy="KEY";self.strategyChanges+=1
            elseif self.stallsInRow==2 and type(keypress)=="function" then self.keyBackend="EXECUTOR" end
            if self.stallsInRow>=4 then self:stop(hum,root,"BOUNDED_STUCK");return "STUCK" end
        end
        local exhausted=self.index>#self.points
        if exhausted then
            self.points={};self.index=1;self.desiredPoint=nil
            self:releaseSteering()
        end
        -- Prepare the next segment while following the current valid segment.
        local tail=self.points[#self.points]
        local prefetch=tail and flat(root.Position,tail)<math.max(24,self.speed*.85)
            and flat(tail,destination)>15
        if exhausted or prefetch or targetShift>14 and now-(self.routeAt or 0)>1.1 then
            self:route(root,hum,char,now,state)
        end
        self:advance(root,math.clamp(root.Size.X*.5+4,6,12))
        local waypoint=self.points[self.index]
        if not waypoint then
            self.desiredPoint=nil;self:releaseSteering();self:hold("SHIFT",false)
            self.lastReason=self.pending and "PLANNING" or self.lastFailure or "WAIT_ROUTE"
            return "WAIT"
        end
        -- Directly track a nearby moving target only over checked terrain.
        if state.movingTarget and total<28 then
            local clear=self:clearSegment(root.Position,destination,char,state.allowWater==true)
            if clear then waypoint=destination end
        end
        local look=root.CFrame and root.CFrame.LookVector
        local previous=look and {x=root.Position.X-look.X*5,z=root.Position.Z-look.Z*5} or nil
        local turn=self.math.turn(previous,p2(root.Position),p2(waypoint))
        local localRange=flat(root.Position,waypoint)
        local nextPoint=self.points[self.index+1]
        if nextPoint and self.math.turn(p2(root.Position),p2(waypoint),p2(nextPoint))>55 and localRange<35 then turn=math.max(turn,85) end
        local wanted=self.math.select(state.hunting and total*2 or total,turn,state.staminaFraction,{
            allowBurst=state.allowBurst~=false and self.inputVerified and localRange>=38,
            burstReady=not state.hudBurstNo,swimming=state.swimming,
            swimSprint=state.swimSprint,combat=state.combat,hunting=state.hunting,
            preySpeed=state.preySpeed,ability=state.ability})
        self.gait=self.gaits:step(wanted,state,now)
        self.desiredPoint,self.desiredRoot,self.desiredHum=waypoint,root,hum
        self.lastReason=(state.swimming and "SWIM_" or "FOLLOWING_")..self.gait
        return "MOVING"
    end
    function n:status()
        return {stage=self.lastReason,failure=self.lastFailure,method=self.lastMode,
            driverPath=self.driverPath,driverReason=self.driverReason,
            requested=self.gaits.requested,observed=self.gaits.observed,
            gaitReason=self.gaits.reason,gaitRequests=self.gaits.requests,
            gaitConfirmations=self.gaits.confirmations,input=self.nativeInput,
            inputVerified=self.inputVerified,distance=self.distance,
            travelled=math.floor(self.travelled*10)/10,speed=math.floor(self.speed*10)/10,
            replans=self.replans,failures=self.failures,waterRoutes=self.waterRoutes,
            corrections=self.corrections,segments=self.segmentCount}
    end
    return n
end
return Nav
]============]
sources["hunt"] = [============[
-- Moving NPC pursuit. Inputs and observed HP changes are separate outcomes.
local Hunt={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e8 end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
function Hunt.new(adapter)
    local h={adapter=adapter,target=nil,pending=nil,hits=0,misses=0,attacks=0,
        lastResult="No attack",nextAttack=0,blocked={},kills=0}
    function h:abandon(now,why)
        if self.target and self.target.model then
            self.blocked[self.target.model]=now+80
            if self.adapter.preyBlocked then self.adapter.preyBlocked[self.target.model]=now+80 end
        end
        self.target,self.pending=nil,nil
        self.lastResult=why;self.nextSelect=now+2
        self.adapter:stop(why)
    end
    function h:tick(s)
        local now=s.now
        local prey=self.target
        if prey and prey.hum and prey.hum.Health<=0 then
            self.kills+=1;self.lastResult="Observed NPC HP reached zero; attribution unverified"
            self.corpse={position=prey.position,at=now,model=prey.model}
            self.target,self.pending=nil,nil
            self.adapter:stop("prey down")
            return "PREY_DOWN",self.lastResult
        end
        if prey then prey=self.adapter:checkPrey(prey,s) end
        if not prey then
            self.target,self.pending=nil,nil
            if now<(self.nextSelect or 0) then return "HUNT_SEARCH",self.lastResult end
            prey=self.adapter:prey(s)
            if prey and prey.model and (self.blocked[prey.model] or 0)>now then prey=nil end
            if not prey then self.adapter:stop("no suitable NPC prey");return "WAIT_FOOD","No suitable safe NPC prey or edible food" end
            self.target=prey;self.started=now;self.bestDistance=distance(s.position,prey.position)
            self.closingAt=now;self.sample=nil;self.noDamageAt=now;self.missesOnTarget=0
        end
        local health=prey.health or prey.hum and prey.hum.Health
        if self.pending then
            local p=self.pending
            if finite(health) and health<p.health-.01 then
                self.hits+=1;self.noDamageAt=now;self.missesOnTarget=0
                self.lastResult="Observed prey HP decline after input; attribution unverified"
                self.pending=nil
            elseif now-p.at>1.6 then
                self.misses+=1;self.missesOnTarget+=1
                self.lastResult="No prey HP decline observed"
                self.pending=nil;self.repositionUntil=now+1.1
            end
        end
        local d=distance(s.position,prey.position)
        if d<self.bestDistance-3 then self.bestDistance=d;self.closingAt=now end
        if d>390 or now-self.started>65 or self.missesOnTarget>=6
            or now-self.closingAt>12 and d>28 or now-self.noDamageAt>25 and d<28 then
            self:abandon(now,"Prey escaping, unreachable or attacks ineffective")
            return "HUNT_REPLAN",self.lastResult
        end
        local velocity=prey.velocity or {x=0,z=0}
        if self.sample and now>self.sample.at and now-self.sample.at<2 and not prey.velocity then
            velocity={x=(prey.position.x-self.sample.position.x)/(now-self.sample.at),
                z=(prey.position.z-self.sample.position.z)/(now-self.sample.at)}
        end
        local speed=math.sqrt(velocity.x^2+velocity.z^2)
        if speed>100 then velocity={x=0,z=0};speed=0 end
        self.sample={position={x=prey.position.x,z=prey.position.z},at=now}
        local lead=math.clamp(d/math.max(20,(s.travelSpeed or 35)+speed),.08,.85)
        local target={x=prey.position.x+velocity.x*lead,z=prey.position.z+velocity.z*lead}
        local geometry=type(self.adapter.attackGeometry)=="function" and self.adapter:attackGeometry(s,prey) or nil
        local valid=geometry and geometry.valid
        -- Keep pursuing while verifying a previous bite; a coarse range check
        -- must never freeze a hunter while its prey runs out of range.
        if valid and now>=self.nextAttack and not self.pending and now>=(self.repositionUntil or 0) then
            local sent,why=self.adapter:bite(s,prey)
            self.lastResult=why or (sent and "Attack requested; awaiting prey HP" or "Native attack not ready")
            self.nextAttack=now+(s.attackCooldown or 1.35)
            if sent and finite(health) then
                self.attacks+=1;self.pending={at=now,health=health}
            end
        end
        if valid and speed<2 and not self.repositionUntil then
            self.adapter:stop("valid stationary attack position")
        else
            if geometry and geometry.inRange and not valid or now<(self.repositionUntil or 0) then
                local dx,dz=prey.position.x-s.position.x,prey.position.z-s.position.z
                local len=math.max(1,math.sqrt(dx*dx+dz*dz))
                local side=(self.missesOnTarget%2==0) and 1 or -1
                target={x=prey.position.x+dx/len*2-dz/len*side*2,
                    z=prey.position.z+dz/len*2+dx/len*side*2}
            end
            local result=self.adapter:move(target,s,{navKey=prey.model or "NPC_HUNT",
                movingTarget=true,hunting=true,preySpeed=speed,moveRadius=.9})
            if result=="STUCK" or result=="BLOCKED" then
                self:abandon(now,"NPC pursuit route failed")
                return "HUNT_REPLAN",self.lastResult
            end
        end
        if self.repositionUntil and now>=self.repositionUntil then self.repositionUntil=nil end
        self.distance=d;self.preySpeed=speed
        return self.pending and "HUNT_VERIFY" or valid and "HUNT_ATTACK" or "HUNT_APPROACH",self.lastResult
    end
    function h:status()
        return {attacks=self.attacks,hpDeclines=self.hits,misses=self.misses,
            result=self.lastResult,distance=self.distance,preySpeed=self.preySpeed,
            active=self.target~=nil,killsObserved=self.kills}
    end
    return h
end
return Hunt
]============]
sources["agent"] = [============[
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
        cfg=nil,spots=nil,territoryInstance=nil,refreshAt=0,lastString=nil,
        lastBiome=nil,motionReason="Idle",manualUncertain=false,spotCache={},spotTry={},
        configs={},waterBlocked={},preyBlocked={},foodBlocked={},connections={},inputEpoch=0}
    local world=Rep:FindFirstChild("FeralWorld")
    local function config(name)
        if b.configs[name] then return b.configs[name] end
        local module=world and world:FindFirstChild(name)
        if not module or not module:IsA("ModuleScript") then return nil end
        local ok,value=pcall(require,module)
        if ok and type(value)=="table" then b.configs[name]=value;return value end
        return nil
    end
    b.config=config
    function b:hub()
        local h=(type(getgenv)=="function" and getgenv() or _G).FERAL_RENAISSANCE_ACTIVE
        return type(h)=="table" and not h.closed and h.bridge and h.bridge.player==player and h or nil
    end
    function b:prepare(now,enabled,goal)
        local h=self:hub()
        if not enabled or not h then return end
        if h.walk and type(h.stopWalk)=="function" then h:stopWalk("Amber movement owner") end
        h.nextWalk=now+90
        -- Coordinate with existing recovery instead of letting it start Rest
        -- during travel, feeding approach or hunt preparation.
        if not goal or goal.kind~="RECOVER" then
            if h.policy then h.policy.actionUntil=math.max(h.policy.actionUntil or 0,now+.6) end
            if h.recovery and type(h.recovery.release)=="function" then h.recovery:release("Amber objective",now) end
        end
    end
    b.cfg=config("TerritoryConfig")
    b.spots=config("MapSpots")
    b.territoryInstance=Rep:FindFirstChild("FeralTerritory")
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
        if not self.cfg or not self.territoryInstance then
            world=Rep:FindFirstChild("FeralWorld")
            self.cfg=config("TerritoryConfig")
            self.spots=config("MapSpots")
            self.territoryInstance=Rep:FindFirstChild("FeralTerritory")
            if not self.cfg or not self.territoryInstance then return end
        end
        local text=attr(self.territoryInstance,"Hexes")
        local biome=attr(Workspace,"FeralBiome") or "WolfValley"
        if type(text)~="string" or #text==0 or type(self.cfg.parseHexes)~="function"
            or type(self.cfg.hexCenter)~="function" then return end
        if text==self.lastString and biome==self.lastBiome then return end
        local ok,parsed=pcall(self.cfg.parseHexes,text)
        if not ok or type(parsed)~="table" then return end
        self.lastString,self.lastBiome=text,biome
        self.spotCache,self.spotTry={},{}
        local hexes,byKey={},{}
        for _,t in ipairs(parsed) do
            if type(t.key)=="string" and type(t.i)=="number" and type(t.j)=="number" then
                local good,p=pcall(self.cfg.hexCenter,t.i,t.j)
                if good and p and ((typeof(p)=="Vector2")
                    or (type(p)=="table" and finite(p.X) and finite(p.Y))) then
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
        local t=b.territoryInstance
        return attr(t,key.."_"..suffix)
    end
    function b:territory(key)
        if not self.territoryInstance then return nil end
        local h=self.hexByKey[key]
        if not h then return nil end
        local pay=terrAttr(key,"pay") or terrAttr(key,"income") or terrAttr(key,"amber")
        return {key=key,neutral=terrAttr(key,"neutral")==true or self.cfg and self.cfg.ON==false,
            owner=terrAttr(key,"owner"),by=terrAttr(key,"by"),
            prog=terrAttr(key,"prog"),hold=terrAttr(key,"hold"),
            pay=finite(pay) and pay or nil,
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
        -- Distant hex terrain is commonly unstreamed in Roblox. Travel toward
        -- the replicated geometry first; only demand a physical claim spot
        -- after the animal is near enough for the terrain to stream in.
        local origin=state and state.position
        if origin and dist(origin,h.spot or h.center)>210 then
            return h.spot or h.center
        end
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
            if matching and (not h.spot or dist(p,h.spot)<math.max(10,(self.cfg.CLAIM_RADIUS or 120)-12)) then
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
    function b:manualInput()
        if UserInput:GetFocusedTextBox() then return true end
        for _,name in ipairs({"W","A","S","D","Up","Down","Left","Right","Space"}) do
            local key=Enum.KeyCode[name]
            if key then
                local ok,down=pcall(UserInput.IsKeyDown,UserInput,key)
                if ok and down and not self.nav.held[name] then return true end
            end
        end
        return false
    end
    local function safePosition(p,state,radius)
        for _,other in ipairs(state.players or {}) do
            if dist(p,other)<(radius or state.avoidRadius or 110) then return false end
        end
        return true
    end
    local function surfaceAt(x,z,state,waterAllowed)
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={state.char};params.IgnoreWater=false
        local hit=Workspace:Raycast(Vector3.new(x,state.root.Position.Y+120,z),Vector3.new(0,-460,0),params)
        if not hit then return nil end
        local water=hit.Material==Enum.Material.Water
        if water and not waterAllowed or not water and hit.Normal.Y<.5 then return nil end
        return point(hit.Position),water
    end
    function b:avoidWater(position,now)
        if position then
            local key=string.format("%d:%d",math.floor(position.x/12),math.floor(position.z/12))
            self.waterBlocked[key]=now+90
        end
        self.waterCache=nil;self.waterAt=0
    end
    function b:water(state)
        if self.waterCache and state.now<(self.waterAt or 0)+3 then return self.waterCache end
        local best,score=nil,math.huge
        local coarse,coarseDistance=nil,math.huge
        local function consider(candidate)
            local key=string.format("%d:%d",math.floor(candidate.x/12),math.floor(candidate.z/12))
            if (self.waterBlocked[key] or 0)>state.now or not safePosition(candidate,state,120) then return end
            local d=dist(candidate,state.position)
            if d<score then best,score=candidate,d end
        end
        -- FeedCanPos is the real current native offer, not a guessed landmark.
        if state.feedCan=="drink" and state.feedPosition then consider(state.feedPosition) end
        local finder=config("FeedFinder")
        local needs=config("NeedsConfig")
        if finder and type(finder.waterAround)=="function" then
            local ok,p=pcall(finder.waterAround,state.char,state.root,needs and needs.WATER_PROMPT_PROBES)
            if ok and typeof(p)=="Vector3" then consider(point(p)) end
        end
        -- Find actual nearby terrain water. Also sample progressively larger
        -- landmark rings: a lake's centre is not necessarily its shoreline.
        local origins={{x=state.position.x,z=state.position.z,rings={10,24,48,90,150}}}
        local biome=state.biome
        local spots=self.spots and (self.spots[biome] or self.spots.WolfValley)
        for _,spot in ipairs(type(spots)=="table" and spots or {}) do
            local name=string.lower(tostring(spot.key or spot.name or ""))
            if typeof(spot.pos)=="Vector2" and (spot.drinkR or name:find("water",1,true)
                or name:find("lake",1,true) or name:find("pond",1,true) or name:find("river",1,true)
                or name:find("creek",1,true) or name:find("marsh",1,true) or name:find("fall",1,true)) then
                table.insert(origins,{x=spot.pos.X,z=spot.pos.Y,rings={0,30,80,160,spot.drinkR or 240}})
                local p={x=spot.pos.X,z=spot.pos.Y}
                local d=dist(p,state.position)
                local key=string.format("%d:%d",math.floor(p.x/12),math.floor(p.z/12))
                if d<coarseDistance and safePosition(p,state,120) and (self.waterBlocked[key] or 0)<=state.now then
                    coarse,coarseDistance=p,d
                end
            end
        end
        for _,origin in ipairs(origins) do
            for _,radius in ipairs(origin.rings) do
                for k=0,7 do
                    local a=k*math.pi/4
                    local x,z=origin.x+math.cos(a)*radius,origin.z+math.sin(a)*radius
                    local pos,wet=surfaceAt(x,z,state,true)
                    if pos and wet then
                        -- A shallow native swim route may approach the water;
                        -- native E retains the final mouth/shore positioning.
                        consider(pos)
                        for _,reach in ipairs({7,15}) do
                            local bank=surfaceAt(x-math.cos(a)*reach,z-math.sin(a)*reach,state,false)
                            if bank and dist(bank,pos)<=reach+1 then consider(bank) end
                        end
                    end
                end
            end
        end
        self.waterEvidence=best and "TERRAIN_OR_NATIVE_OFFER" or coarse and "LANDMARK_APPROACH" or "NONE"
        self.waterCache,self.waterAt=best or coarse,state.now
        return self.waterCache
    end
    function b:profile(char,species)
        local cfg=config("Species")
        local known=cfg and cfg.List and cfg.List[species]
        if not known then return {known=false,hunts=false,swim=true} end
        local forage=config("Forage")
        local hunts=known.diet=="carnivore" or known.diet=="omnivore"
        if forage and type(forage.canEat)=="function" then
            local ok,value=pcall(forage.canEat,known.diet,"meat")
            if ok then hunts=value==true end
        end
        return {known=true,diet=known.diet,swim=true,swimSprint=finite(known.swimSprint) and known.swimSprint>0,
            hunts=hunts,
            native=known}
    end
    function b:snapshot(now)
        local c,h,r=validAnimal()
        local species,coat=fullStats(c)
        local alive=c~=nil and c.Parent~=nil and h~=nil and r~=nil and h.Health>0
        if not alive then return {alive=false,species=species,coat=coat,now=now} end
        self:refresh(now)
        local at;pcall(function()at=Workspace:GetServerTimeNow()end)
        local untilCombat=attr(player,"FeralCombatUntil")
        local stamina,maximum=attr(c,"Stamina"),attr(c,"StaminaMax")
        local reserve=finite(stamina) and finite(maximum) and maximum>0 and math.clamp(stamina/maximum,0,1) or nil
        local burstNo=attr(player,"HudBurstNo")
        local profile=self:profile(c,species)
        local hub=self:hub()
        local feed,feedStarted,feedKnown
        if hub and type(hub.bridge.nativeFeedState)=="function" then
            local ok,mode,started,known=pcall(hub.bridge.nativeFeedState,hub.bridge,now)
            if ok then feed,feedStarted,feedKnown=mode,started,known end
        end
        local offer=attr(c,"FeedCanPos")
        local amber=attr(player,"Amber")
        if not finite(amber) then
            local stats=player:FindFirstChild("leaderstats")
            local v=stats and stats:FindFirstChild("Amber")
            if v and finite(v.Value) then amber=v.Value end
        end
        local pack=attr(player,"FeralPack")
        if pack==0 or pack=="" or pack=="0" or pack==false then pack=nil end
        local swimming=attr(c,"FeralSwimLocal")==true
        local ok,humState=pcall(h.GetState,h)
        if ok and Enum.HumanoidStateType and humState==Enum.HumanoidStateType.Swimming then swimming=true end
        local fly=attr(c,"FeralFlyLocal")==true
        local hudBurst=attr(player,"HudBurst")
        if type(hudBurst)~="boolean" then hudBurst=attr(c,"WolfBurst") end
        local hudTrot=attr(player,"HudTrot")
        if type(hudTrot)~="boolean" then hudTrot=attr(c,"WolfTrot") end
        return {alive=true,char=c,hum=h,root=r,position=point(r.Position),
            species=species,coat=coat,profile=profile,pack=pack,
            biome=attr(Workspace,"FeralBiome") or "WolfValley",healthFraction=h.MaxHealth>0 and h.Health/h.MaxHealth or 0,
            hunger=attr(c,"Hunger"),thirst=attr(c,"Thirst"),feedCan=attr(c,"FeedCan"),
            feedMode=attr(c,"WolfFeed"),nativeFeedMode=feed,nativeFeedKnown=feedKnown,feedStarted=feedStarted,
            feedPosition=typeof(offer)=="Vector3" and point(offer) or nil,
            staminaFraction=reserve,hudBurst=hudBurst,hudTrot=hudTrot,hudSprint=attr(player,"HudSprint"),
            hudBurstNo=burstNo==true or finite(burstNo) and now>=burstNo and now-burstNo<1.7,
            runIntent=attr(c,"WolfRunIntent"),allowBurst=reserve~=nil and reserve>=.56,
            allowWater=profile.swim==true,swimSprint=profile.swimSprint==true,
            amber=amber,now=now,serverNow=at,unixNow=os.time(),players=self:otherPlayerPositions(),
            avoidRadius=110,claimRadius=15,careTarget=72,
            gameMenu=attr(player,"FeralMenuOpen")==true,menuOpen=UserInput:GetFocusedTextBox()~=nil,
            manualInput=self:manualInput(),combat=finite(at) and finite(untilCombat) and untilCombat>at or false,
            pinned=attr(c,"FeralPinned")==true or attr(c,"FeralDragged")==true or attr(c,"FeralCarried")==true,
            ability=attr(c,"FeralRolling")==true or attr(c,"FeralDowned")==true or attr(c,"FeralVenomDown")==true
                or attr(c,"FeralTalonLock")~=nil and attr(c,"FeralTalonLock")~=false
                or attr(c,"FeralDeathRollLocal")==true or attr(c,"FeralDiveBomb")==true
                or hub and hub.grab and hub.grab.active==true,
            rescuing=hub and hub.rescue and hub.rescue.pending~=nil,
            resting=attr(c,"WolfRest")==true,flying=fly,swimming=swimming,
            climbing=attr(c,"FeralClimbLocal")==true,underwater=attr(c,"FeralUnderwater")==true}
    end
    function b:move(destination,state,options)
        if not destination then return "WAIT" end
        options=options or {}
        local s=table.clone(state)
        for key,value in pairs(options) do s[key]=value end
        local target=Vector3.new(destination.x,state.root.Position.Y,destination.z)
        local players={}
        for _,p in ipairs(state.players or {}) do table.insert(players,Vector3.new(p.x,state.root.Position.Y,p.z)) end
        local result=self.nav:tick(target,state.char,state.hum,state.root,state.now,players,s)
        self.motionReason=self.nav.lastReason
        return result
    end
    function b:stop(reason)
        self.motionReason=reason
        local _,h,r=validAnimal()
        self.nav:stop(h,r,reason)
    end
    function b:releaseInputs()
        self.inputEpoch+=1
        for name,release in pairs(self.pendingInputs or {}) do pcall(release);self.pendingInputs[name]=nil end
    end
    local function pulse(name,begin,finish)
        b.pendingInputs=b.pendingInputs or {}
        if b.pendingInputs[name] then return false end
        local ok=pcall(begin)
        if not ok then pcall(finish);return false end
        b.pendingInputs[name]=finish
        local epoch=b.inputEpoch
        task.delay(.07,function()
            if b.inputEpoch==epoch and b.pendingInputs[name]==finish then
                pcall(finish);b.pendingInputs[name]=nil
            end
        end)
        return true
    end
    function b:feed(state,kind)
        if state.feedCan~=kind or state.nativeFeedMode or state.feedMode==kind or state.feedMode==true
            or state.menuOpen or state.manualInput then return false end
        local hub=self:hub()
        if hub and type(hub.bridge.toggleNativeFeed)=="function" and state.nativeFeedKnown then
            local ok,sent=pcall(hub.bridge.toggleNativeFeed,hub.bridge,state.now)
            self.lastInput=ok and sent and "Native toggleFeed requested" or "Native toggleFeed unavailable"
            return ok and sent==true
        end
        local ok,v=pcall(function()return game:GetService("VirtualInputManager")end)
        if ok and v then
            self.lastInput="E input requested"
            return pulse("E",function()v:SendKeyEvent(true,Enum.KeyCode.E,false,game)end,
                function()v:SendKeyEvent(false,Enum.KeyCode.E,false,game)end)
        end
        if type(keypress)=="function" and type(keyrelease)=="function" then
            return pulse("E",function()keypress(0x45)end,function()keyrelease(0x45)end)
        end
        return false
    end
    function b:cancelFeed(state)
        local hub=self:hub()
        if hub and type(hub.bridge.stopNativeFeed)=="function" then
            local ok,sent=pcall(hub.bridge.stopNativeFeed,hub.bridge,state.now)
            return ok and sent==true
        end
        return false
    end
    function b:food(state)
        local finder=config("FeedFinder")
        if finder and type(finder.food)=="function" then
            local ok,item,pos=pcall(finder.food,state.char,state.root)
            if ok and item and typeof(pos)=="Vector3" and safePosition(point(pos),state) then
                return {position=point(pos),model=item}
            end
        end
        local profile=state.profile or self:profile(state.char,state.species)
        local forage=config("Forage")
        if not profile.diet or not forage or type(forage.canEat)~="function" then return nil end
        if forage.PLANT_DIETS and forage.PLANT_DIETS[profile.diet] and type(forage.nearest)=="function" then
            local ok,entry,pos=pcall(forage.nearest,state.root.Position,300)
            if ok and entry and typeof(pos)=="Vector3" and safePosition(point(pos),state) then
                local item
                if type(forage.handle)=="function" then
                    local valid,result=pcall(forage.handle,entry)
                    if valid then item=result end
                end
                if item and (self.foodBlocked[item] or 0)<=state.now then return {model=item,position=point(pos)} end
            end
        end
        local ok,collection=pcall(function()return game:GetService("CollectionService")end)
        if not ok or not collection then return nil end
        local best,score=nil,math.huge
        for _,item in ipairs(collection:GetTagged("FeralFood")) do
            local left=attr(item,"FoodLeft")
            local owner=attr(item,"TutorialOwner")
            local valid,edible=pcall(forage.canEat,profile.diet,attr(item,"Diet"))
            if item.Parent and item:IsDescendantOf(Workspace) and attr(item,"Consumed")~=true and valid and edible
                and (not finite(left) or left>.01) and (owner==nil or owner==player.UserId)
                and (self.foodBlocked[item] or 0)<=state.now then
                local pos=attr(item,"FoodPos")
                if typeof(pos)~="Vector3" then
                    if item:IsA("Model") then
                        local good,cf=pcall(item.GetBoundingBox,item)
                        if good then pos=cf.Position end
                    elseif item:IsA("BasePart") then pos=item.Position end
                end
                if typeof(pos)=="Vector3" then
                    local p=point(pos);local d=dist(p,state.position)
                    if d<400 and d<score and safePosition(p,state) then best,score={position=p,model=item},d end
                end
            end
        end
        return best
    end
    function b:checkPrey(prey,state)
        local profile=state.profile or self:profile(state.char,state.species)
        if not prey or not prey.model or not prey.model.Parent or not profile.hunts then return nil end
        if Players:GetPlayerFromCharacter(prey.model) then return nil end
        local pack=attr(prey.model,"FeralPack")
        if state.pack~=nil and state.pack==pack then return nil end
        local root=prey.model:FindFirstChild("HumanoidRootPart")
        local hum=prey.model:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health<=0 or attr(prey.model,"FeralDead")==true
            or hum.MaxHealth>state.hum.MaxHealth*.8 or (self.preyBlocked[prey.model] or 0)>state.now then return nil end
        local position=point(root.Position)
        if not safePosition(position,state,120) then return nil end
        local velocity=root.AssemblyLinearVelocity
        prey.position=position;prey.root=root;prey.hum=hum
        prey.velocity=velocity and point(velocity) or {x=0,z=0}
        prey.health=hum.Health
        prey.attackRange=math.clamp((state.root.Size.Z+root.Size.Z)*.35,4,12)
        return prey
    end
    function b:prey(state)
        local folder=Workspace:FindFirstChild("FeralNPCs")
        if not folder then return nil end
        local best,score=nil,math.huge
        for _,npc in ipairs(folder:GetChildren()) do
            if npc:IsA("Model") then
                local p=self:checkPrey({model=npc},state)
                if p then
                    local d=dist(p.position,state.position)
                    local speed=math.sqrt(p.velocity.x^2+p.velocity.z^2)
                    local rank=d+speed*3+p.health*.05
                    if d<330 and rank<score then best,score=p,rank end
                end
            end
        end
        return best
    end
    function b:attackGeometry(state,prey)
        local hub=self:hub()
        local cfg=hub and hub.features and hub.features.originalCombat or config("CombatConfig")
        if not cfg then return nil end
        local diff=prey.root.Position-state.root.Position
        local planar=Vector3.new(diff.X,0,diff.Z)
        local look=state.root.CFrame.LookVector
        look=Vector3.new(look.X,0,look.Z)
        if type(cfg.bodyGap)~="function" or not finite(cfg.REACH) or not finite(cfg.SLACK)
            or not finite(cfg.HIT_SCALE) or not finite(cfg.MAX_DY) or not finite(cfg.CONE) then return nil end
        if type(cfg.biteLook)=="function" then
            local ok,v=pcall(cfg.biteLook,state.char,look.Unit)
            if ok and typeof(v)=="Vector3" then look=Vector3.new(v.X,0,v.Z) end
        end
        local function mult(name,default)
            if type(cfg[name])~="function" then return default end
            local ok,value=pcall(cfg[name],state.char)
            return ok and finite(value) and value or default
        end
        local ok,gap=pcall(cfg.bodyGap,prey.root,planar)
        if not ok or not finite(gap) or look.Magnitude<.01 then return nil end
        local box=attr(state.root,"FeralBoxFull") or state.root.Size.Z
        local reach=(box*.5+state.hum.HipHeight*cfg.REACH+cfg.SLACK)*cfg.HIT_SCALE*mult("reachMult",1)
        local angle=planar.Magnitude>.01 and look.Unit:Dot(planar.Unit) or 1
        local height=(state.hum.HipHeight+prey.hum.HipHeight)*cfg.MAX_DY*mult("dyMult",1)
        local cone=mult("coneFor",cfg.CONE)
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={state.char};params.IgnoreWater=true
        local obstruction=Workspace:Raycast(state.root.Position,diff,params)
        local clear=not obstruction or obstruction.Instance and obstruction.Instance:IsDescendantOf(prey.model)
        return {valid=gap<reach*.92 and angle>math.cos(math.rad(cone)) and math.abs(diff.Y)<height*.95 and clear,
            inRange=gap<reach*.92 and math.abs(diff.Y)<height*.95,angle=angle,gap=gap,reach=reach,clear=clear}
    end
    function b:bite(state,prey)
        local p=self:checkPrey(prey,state)
        if not p then return false,"Prey unavailable" end
        local geometry=self:attackGeometry(state,p)
        if not geometry or not geometry.valid then return false,"Native range, facing or line of sight not ready" end
        local hub=self:hub()
        if hub and type(hub.bridge.tryNativeBite)=="function" then
            if hub.recovery then hub.recovery:release("Amber hunt",state.now) end
            local s=hub.snapshot
            if s and s.char==state.char and type(hub.bridge.biteReadiness)=="function" then
                local ready=hub.bridge:biteReadiness(s,state.now,hub.policy)
                if ready.known and not ready.ready then return false,ready.reason end
            end
            if hub.policy then hub.policy:input("attack",state.now) end
            local ok,sent=pcall(hub.bridge.tryNativeBite,hub.bridge,state.now)
            if ok and sent then self.lastInput="Native tryBite requested";return true,self.lastInput end
        end
        local species=config("Species")
        local delay=1.35
        if species and type(species.biteCooldown)=="function" then
            local ok,value=pcall(species.biteCooldown,state.species,attr(state.char,"Growth") or 1)
            if ok and finite(value) then delay=math.clamp(value,.15,10) end
        end
        if state.now<(self.nextBite or 0) then return false,"Native bite cooldown" end
        self.nextBite=state.now+delay
        local ok,v=pcall(function()return game:GetService("VirtualInputManager")end)
        if ok and v then
            -- The owned WolfController callback above avoids UI hit testing.
            -- Fallback mouse input is reported as a request, never as damage.
            local m=UserInput:GetMouseLocation()
            self.lastInput="Mouse attack requested"
            return pulse("M1",function()v:SendMouseButtonEvent(m.X,m.Y,0,true,game,0)end,
                function()v:SendMouseButtonEvent(m.X,m.Y,0,false,game,0)end),self.lastInput
        end
        if type(mouse1click)=="function" then return pcall(mouse1click) end
        return false,"Attack input unavailable"
    end
    function b:close()
        self:releaseInputs();self:stop("unloaded")
        for _,c in ipairs(self.connections) do c:Disconnect() end
        self.connections={}
    end
    return b
end
return Bridge
]============]
sources["driver"] = [============[
-- Ordinary world-space input before WolfMove reads Humanoid.MoveDirection.
-- v2412 WolfController 187:1546-1666 binds WolfMove at Input.Value+1.
local Driver={}
function Driver.new(player,nav,manual)
    local d={nav=nav,closed=false,method="NATIVE_KEYS",controls=nil,original=nil,nextProbe=0}
    function d:attach()
        if self.closed or self.controls then return end
        local modules={}
        local scripts=player:FindFirstChild("PlayerScripts")
        local legacy=scripts and scripts:FindFirstChild("PlayerModule")
        if legacy then table.insert(modules,{module=legacy,path="PLAYER_SCRIPTS"}) end
        -- The supplied capture indexes StarterPlayer/PlayerModule/ControlModule.
        -- IAS PlayerModule need not expose the legacy GetControls endpoint.
        local ok,starter=pcall(function()return game:GetService("StarterPlayer")end)
        local modern=ok and starter and starter:FindFirstChild("PlayerModule")
        if modern and modern~=legacy then table.insert(modules,{module=modern,path="STARTER_PLAYER"}) end
        local controls,path=nil,nil
        for _,candidate in ipairs(modules) do
            local mod=candidate.module
            local good,value=pcall(require,mod)
            if good and type(value)=="table" then
                if type(value.GetControls)=="function" then
                    local found,result=pcall(value.GetControls,value)
                    if found and type(result)=="table" then controls=result end
                elseif type(value.moveFunction)=="function" then controls=value end
            end
            if not controls and type(mod.FindFirstChild)=="function" then
                local child=mod:FindFirstChild("ControlModule")
                if child then
                    local found,result=pcall(require,child)
                    if found and type(result)=="table" then controls=result end
                end
            end
            if controls and type(controls.moveFunction)=="function" then path=candidate.path;break end
            controls=nil
        end
        if not controls then self.reason="No supported native moveFunction; using keys";return end
        local previous=controls.moveFunction
        local wrapper=function(p,direction,relative)
            if p==player and not self.closed and nav.desiredPoint and nav.steeringStrategy=="WORLD" then
                if manual and manual() then
                    nav:stop(nav.desiredHum,nav.desiredRoot,"MANUAL_INPUT")
                else
                    local wanted=nav:direction()
                    if wanted then
                        nav.driveCalls+=1;nav.lastMode="PLAYER_MODULE"
                        return previous(p,wanted,false)
                    end
                end
            end
            return previous(p,direction,relative)
        end
        local attached,why=pcall(function()controls.moveFunction=wrapper end)
        if not attached then self.reason=tostring(why);return end
        self.controls,self.original,self.wrapper=controls,previous,wrapper
        self.method,self.path,self.reason="PLAYER_MODULE",path,"Native callback attached; motion unverified"
        nav.preferredStrategy="WORLD";nav.steeringStrategy="WORLD"
        nav.driverPath=path
    end
    d:attach()
    if not d.controls then nav.preferredStrategy="KEY";nav.steeringStrategy="KEY" end
    function d:tick()
        if self.closed then return end
        if self.controls and self.controls.moveFunction~=self.wrapper then
            self.method="NATIVE_KEYS";nav.preferredStrategy="KEY";nav.steeringStrategy="KEY"
            self.reason="Native callback ownership changed"
        elseif not self.controls and os.clock()>=self.nextProbe then
            self.nextProbe=os.clock()+5;self:attach()
        end
        nav.driverReason=self.reason
        if nav.steeringStrategy=="KEY" then nav:drive() end
    end
    function d:close()
        if self.closed then return end
        self.closed=true
        nav:stop(nav.desiredHum,nav.desiredRoot,"DRIVER_CLOSED")
        if self.controls and self.controls.moveFunction==self.wrapper then
            self.controls.moveFunction=self.original
        end
    end
    return d
end
return Driver
]============]
sources["ui"] = [============[
-- Draggable Amber control; Right Shift follows the Renaissance menu.
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
    local UIS=game:GetService("UserInputService")
    local Workspace=game:GetService("Workspace")
    local env=(type(getgenv)=="function" and getgenv()) or _G
    local frame=Instance.new("Frame")
    frame.Name="AmberPanel"
    frame.Position=env.FERAL_AMBER_PANEL_POSITION or UDim2.new(1,-358,0,84)
    frame.Size=UDim2.fromOffset(340,185)
    frame.BackgroundColor3=Color3.fromRGB(20,29,31)
    frame.BorderSizePixel=0
    frame.Active=true
    frame.Parent=gui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,8)
    local border=Instance.new("UIStroke")
    border.Thickness=1;border.Color=Color3.fromRGB(61,91,88);border.Parent=frame
    local header=text(frame,13,12,8,270,22,Color3.fromRGB(230,204,130))
    header.Font=Enum.Font.GothamBold
    header.Text="FERAL AMBER  ·  AUTOPILOT"
    header.Active=true
    local mode=text(frame,11,12,34,320,21)
    local info=text(frame,11,12,56,320,21)
    local care=text(frame,11,12,78,320,20)
    local movement=text(frame,10,12,99,320,20)
    local reason=text(frame,10,12,120,320,22,Color3.fromRGB(184,207,201))
    reason.TextTruncate=Enum.TextTruncate.AtEnd
    local ui={gui=gui,frame=frame,agent=agent,bridge=bridge,lastUpdate=0,
        collapsed=false,visible=true,connections={}}
    local start
    start=button(frame,"START",12,150,87,function()
        agent:setEnabled(not agent.enabled)
        start.Text=agent.enabled and "STOP" or "START"
    end)
    local copyStatus=button(frame,"COPY STATUS",108,150,125,function()
        local status=agent:status()
        status.coat=type(status.coat)=="string" and status.coat or nil
        status.events={}
        for i=math.max(1,#agent.events-11),#agent.events do table.insert(status.events,agent.events[i]) end
        status.gameVersion=game.PlaceVersion
        status.hexSummary=bridge:counts(agent.lastState or {now=os.clock()})
        status.navigation=bridge.nav:status()
        status.savedPanelPosition=tostring(frame.Position)
        local ok,payload=pcall(function()
            return game:GetService("HttpService"):JSONEncode(status)
        end)
        if ok then
            if type(setclipboard)=="function" then pcall(setclipboard,payload) end
            print("[FERAL AMBER STATUS] "..payload)
        end
    end)
    local collapse
    collapse=button(frame,"MIN",244,150,84,function()
        ui.collapsed=not ui.collapsed
        if ui.collapsed then
            frame.Size=UDim2.fromOffset(340,34)
            start.Visible=false;copyStatus.Visible=false;mode.Visible=false;info.Visible=false;care.Visible=false;movement.Visible=false;reason.Visible=false
            collapse.Text="OPEN";collapse.Position=UDim2.fromOffset(258,3)
        else
            frame.Size=UDim2.fromOffset(340,185)
            start.Visible=true;copyStatus.Visible=true;mode.Visible=true;info.Visible=true;care.Visible=true;movement.Visible=true;reason.Visible=true
            collapse.Text="MIN";collapse.Position=UDim2.fromOffset(244,150)
        end
    end)
    -- Right Shift is the same hub hotkey, not a separate keybinding to
    -- interfere with FERAL's normal sprint controls. Read Renaissance's final
    -- visibility after its own handler has processed the key.
    function ui:setVisible(on)
        self.visible=on==true
        gui.Enabled=self.visible
    end
    function ui:toggle()
        self:setVisible(not self.visible)
    end
    table.insert(ui.connections,UIS.InputBegan:Connect(function(input)
        if input.KeyCode~=Enum.KeyCode.RightShift or UIS:GetFocusedTextBox() then return end
        task.defer(function()
            if not gui.Parent then return end
            local hub=env.FERAL_RENAISSANCE_ACTIVE
            if type(hub)=="table" and hub.ui and type(hub.ui.visible)=="boolean" then
                ui:setVisible(hub.ui.visible)
            else
                ui:toggle()
            end
        end)
    end))
    -- Drag only the header; START, STOP, COPY and MIN remain independently
    -- clickable. Works with desktop mouse and touch; stores position locally.
    local drag=false
    local dragInput=nil
    local dragOrigin=nil
    local frameOrigin=nil
    table.insert(ui.connections,header.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch then
            drag=true
            dragInput=input
            dragOrigin=input.Position
            frameOrigin=frame.AbsolutePosition
        end
    end))
    table.insert(ui.connections,UIS.InputChanged:Connect(function(input)
        if not drag or not dragOrigin or not frameOrigin then return end
        if input.UserInputType~=Enum.UserInputType.MouseMovement
            and input~=dragInput then return end
        local delta=input.Position-dragOrigin
        local cam=Workspace.CurrentCamera
        local size=cam and cam.ViewportSize or Vector2.new(1366,768)
        local width,height=frame.AbsoluteSize.X,frame.AbsoluteSize.Y
        local x=math.clamp(frameOrigin.X+delta.X,0,math.max(0,size.X-width))
        local y=math.clamp(frameOrigin.Y+delta.Y,0,math.max(0,size.Y-height))
        frame.Position=UDim2.fromOffset(x,y)
        env.FERAL_AMBER_PANEL_POSITION=frame.Position
    end))
    table.insert(ui.connections,UIS.InputEnded:Connect(function(input)
        if drag and (input==dragInput
            or input.UserInputType==Enum.UserInputType.MouseButton1) then
            drag,dragInput,dragOrigin,frameOrigin=false,nil,nil,nil
        end
    end))
    function ui:tick(now)
        if now-self.lastUpdate<.75 then return end
        self.lastUpdate=now
        local st=agent:status()
        local snap=agent.lastState or bridge:snapshot(now)
        start.Text=st.enabled and "STOP" or "START"
        mode.Text=(st.enabled and "RUNNING · " or "OFF · ")..st.phase
            ..(st.key and " · "..st.key or "")
        local counts=bridge:counts(snap)
        info.Text=string.format("Hexes %d/%d owned · %d fading · Amber +%.0f",
            counts.owned,counts.eligible,counts.fading,st.earned)
        local function amount(v) return type(v)=="number" and string.format("%.0f",v) or "?" end
        care.Text="Hunger "..amount(snap.hunger).." · Thirst "..amount(snap.thirst)
            .." · "..tostring(st.species or snap.species or "No animal")
        local nav=bridge.nav
        movement.Text=tostring(nav.gaits.requested).." requested / "..tostring(nav.gaits.observed)
            .." observed · "..tostring(nav.lastMode)
        reason.Text=st.reason

    end
    function ui:close()
        agent:setEnabled(false)
        for _,connection in ipairs(self.connections) do pcall(function() connection:Disconnect() end) end
        table.clear(self.connections)
        if gui.Parent then gui:Destroy() end
    end
    return ui
end
return UI
]============]
-- FERAL AMBER AUTOPILOT v0.4 — all-animal surface-route, territory and care engine.
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
local Gait=module("gait")
local Nav=module("nav")
local Hunt=module("hunt")
local Agent=module("agent")
local Bridge=module("bridge")
local Driver=module("driver")
local UI=module("ui")
local Players=game:GetService("Players")
local player=assert(Players.LocalPlayer,"No player in current client")
local gui=player:WaitForChild("PlayerGui",18)
if not gui then warn("[FERAL AMBER] PlayerGui unavailable. Spawn first.");return nil end
local path=game:GetService("PathfindingService")
local workspace=game:GetService("Workspace")
local nav=Nav.new(path,workspace,Gait)
local bridge=Bridge.new(nav)
local agent=Agent.new(Planner,bridge,Hunt)
local panel,why=UI.new(agent,bridge)
if not panel then warn("[FERAL AMBER] "..tostring(why));return nil end
local driver=Driver.new(player,nav,function()return bridge:manualInput()end)
local active=true
local connection
-- Closing Renaissance also closes all companion territory automation.
-- This watches the specific hub instance so replacing/unloading it never
-- leaves an orphan Amber controller, panel or synthetic held keys.
local ownerHub=environment.FERAL_RENAISSANCE_ACTIVE
local handle={version="0.4.0",agent=agent,bridge=bridge,nav=nav,panel=panel,
    ownerHub=ownerHub,driver=driver}
function handle.close()
    if not active then return end
    active=false
    if connection then connection:Disconnect();connection=nil end
    pcall(agent.setEnabled,agent,false)
    pcall(driver.close,driver)
    pcall(bridge.close,bridge)
    nav.closed=true
    panel:close()
    if environment.FERAL_AMBER_ACTIVE==handle then environment.FERAL_AMBER_ACTIVE=nil end
end
function handle.setEnabled(on) agent:setEnabled(on==true) end
function handle.status() return agent:status() end
function handle.setPanelVisible(on) panel:setVisible(on) end
function handle.togglePanel() panel:toggle() end
local lastError=0
connection=game:GetService("RunService").Heartbeat:Connect(function()
    if not active then return end
    if ownerHub and (ownerHub.closed==true
        or environment.FERAL_RENAISSANCE_ACTIVE~=ownerHub) then
        handle.close()
        return
    end
    -- PlayerModule supplies steering at Input priority, before WolfMove.
    -- Heartbeat only pumps a mutually exclusive native-key fallback.
    if agent.enabled then
        local ok,err=pcall(driver.tick,driver)
        if not ok then
            agent.lastError=tostring(err)
            agent:setEnabled(false)
            agent.phase="ERROR";agent.reason="Movement input failed; stopped"
        end
    end
    if handle.working then return end
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
        agent.lastError=tostring(err)
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
print("[FERAL AMBER 0.4] Ready. Select START in the small Amber panel; native walking, claim and care outcomes are observed, not presumed.")
return handle
