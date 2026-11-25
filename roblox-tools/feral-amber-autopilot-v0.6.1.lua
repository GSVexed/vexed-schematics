-- FERAL Amber Autopilot 0.6.1 | 2026-11-25 | native profiles | gameplay outcomes observed separately
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
    if state.contested and state.contested[hex.key] then return nil end
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
    if deny and options.avoidPlayers==true then return nil end
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

-- Native regionCell is a one-based row-major ID. Sweep alternating rows to
-- finish complete areas without crossing repeatedly between opposite corners.
function Planner.regionOrder(grid)
    local order={}
    for row=0,grid-1 do
        for step=0,grid-1 do
            local col=row%2==0 and step or grid-1-step
            table.insert(order,row*grid+col+1)
        end
    end
    return order
end
local function localTour(hexes,state,options)
    local remaining={}
    for _,hex in ipairs(hexes) do
        local item=Planner.objective(hex,state,state.position,options)
        if item then item.region=hex.region;table.insert(remaining,item) end
    end
    local route,from={},state.position
    while #remaining>0 and #route<16 do
        local nearest=math.huge
        for _,item in ipairs(remaining) do nearest=math.min(nearest,dist(from,item.center)) end
        local best,index,cost=nil,nil,math.huge
        for i,item in ipairs(remaining) do
            local d=dist(from,item.center)
            if d<=nearest*1.3+20 then
                local nextDistance=0
                if #remaining>1 then
                    nextDistance=math.huge
                    for j,other in ipairs(remaining) do if i~=j then nextDistance=math.min(nextDistance,dist(item.center,other.center)) end end
                end
                local value=d+nextDistance*.22
                if value<cost or value==cost and item.key<(best and best.key or "~") then best,index,cost=item,i,value end
            end
        end
        table.insert(route,best);table.remove(remaining,index);from=best.center
    end
    -- Shorten crossings while keeping the entry fixed. At most 16 stops.
    for _=1,3 do
        local changed=false
        for i=2,#route-1 do
            for j=i+1,#route-1 do
                local before=dist(route[i-1].center,route[i].center)+dist(route[j].center,route[j+1].center)
                local after=dist(route[i-1].center,route[j].center)+dist(route[i].center,route[j+1].center)
                if after+3<before then
                    local l,r=i,j
                    while l<r do route[l],route[r]=route[r],route[l];l+=1;r-=1 end
                    changed=true
                end
            end
        end
        if not changed then break end
    end
    return route
end
function Planner.strategy(hexes,state,options)
    options=options or {}
    local grid=state.regionGrid
    if not finite(grid) or grid<1 or grid>8 or grid%1~=0 then
        return Planner.plan(hexes,state,options),{phase="GENERAL",cursor=options.regionCursor or 1}
    end
    local groups={};local urgent={};local anyRegion=false
    for _,hex in ipairs(hexes) do
        if hex.region and not hex.neutral then
            anyRegion=true
            groups[hex.region]=groups[hex.region] or {total=0,owned=0,hexes={}}
            local group=groups[hex.region];group.total+=1
            if hex.owner==state.pack then group.owned+=1 end
            table.insert(group.hexes,hex)
        end
        local item=Planner.objective(hex,state,state.position,options)
        if item and item.kind=="SCENT" and item.hold and item.hold<.28 then table.insert(urgent,hex) end
    end
    if not anyRegion then return Planner.plan(hexes,state,options),{phase="GENERAL",cursor=1} end
    local order=Planner.regionOrder(grid)
    if #urgent>0 then return localTour(urgent,state,options),{phase="URGENT_SCENT",cursor=options.regionCursor or 1} end
    local cursor=math.clamp(options.regionCursor or 1,1,#order)
    -- Claims first, then maintenance; blocked areas stay eligible for the next
    -- pass instead of being incorrectly counted as completed.
    for _,claimsOnly in ipairs({true,false}) do
        for step=0,#order-1 do
            local index=(cursor+step-1)%#order+1
            local region=order[index];local group=groups[region]
            if group and (not claimsOnly or group.owned<group.total) then
                local pool={}
                for _,hex in ipairs(group.hexes) do
                    if not claimsOnly or hex.owner~=state.pack then table.insert(pool,hex) end
                end
                local route=localTour(pool,state,options)
                if #route>0 then
                    local row,col=math.floor((region-1)/grid),(region-1)%grid
                    local vertical=grid==3 and ({"Top","Middle","Bottom"})[row+1] or ("Row "..(row+1))
                    local horizontal=grid==3 and ({"left","centre","right"})[col+1] or ("column "..(col+1))
                    return route,{phase=claimsOnly and "AREA_SWEEP" or "AREA_MAINTENANCE",cursor=index,
                        region=region,area=vertical.." "..horizontal,owned=group.owned,total=group.total,
                        bonus=state.regionBonus,order=order}
                end
            end
        end
    end
    return {},{phase="MAINTAINED",cursor=cursor,order=order}
end

function Planner.need(state,options)
    options=options or {}
    if not state or not finite(state.healthFraction) then return "WAIT" end
    if state.healthFraction<(options.minimumHP or .46) then return "RECOVER" end
    local h,t=state.hunger,state.thirst
    if finite(t) and t<(options.emergencyThirst or 19) then return "DRINK" end
    if finite(h) and h<(options.emergencyHunger or 19) then return "EAT" end
    -- Measured depletion can bring care forward before a long search/hunt.
    -- Absent telemetry does not invent a rate or a full resource value.
    if finite(t) and t<80 and finite(state.thirstReserve) and state.thirstReserve<180 then return "DRINK" end
    if finite(h) and h<80 and finite(state.hungerReserve) and state.hungerReserve<240 then return "EAT" end
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
    if options.following and type(options.gaitSpeeds)=="table" then
        for _,mode in ipairs({"WALK","TROT","SPRINT"}) do
            local speed=options.gaitSpeeds[mode]
            if finite(speed) and speed>=(options.preySpeed or 0)*1.08 then return mode end
        end
    end
    local reserve=finite(stamina) and stamina or nil
    local angle=finite(turn) and turn or 0
    if options.allowBurst~=false and (reserve and reserve>=.56 or not reserve and options.nativeBurstAvailable==true)
        and distance>=80 and angle<=22 and not options.crowded
        and options.burstReady~=false then return "BURST" end
    if options.hunting and (options.preySpeed or 0)>6 and distance>6
        and (not reserve or reserve>=.22) and angle<65 then return "SPRINT" end
    if distance<10 then return "WALK" end
    if distance<24 then return "TROT" end
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
            elseif now-p.at>=1.25 then
                local count=self.attempts[p.mode] or 1
                if count>=2 then self.blocked[p.mode]=now+8 end
                self.pending=nil;self.reason="Gait request unconfirmed"
                if p.mode=="SPRINT" then io:hold("SHIFT",false) end
                if count==1 and type(io.retryInput)=="function" then
                    io:retryInput(p.mode=="SPRINT" and "SHIFT" or p.mode=="TROT" and "Z" or "X")
                end
            end
        end
        local emergency=wanted=="STOP" or wanted=="WALK" or s.ability or s.swimming or s.brake
        local boost=wanted=="BURST" and self.requested=="SPRINT" and observed=="SPRINT"
        if wanted~=self.requested and not emergency and not boost and now-self.changedAt<1.1 then
            wanted=self.requested
        end
        if wanted=="BURST" and (type(s.hudBurst)~="boolean" or s.hudBurstNo or (self.blocked.BURST or 0)>now) then wanted="SPRINT" end
        if (wanted=="SPRINT" or wanted=="BURST") and (self.blocked.SPRINT or 0)>now then wanted="TROT" end
        if wanted~=self.requested then self.changedAt=now;self.requested=wanted end
        if observed==wanted and not self.pending then self.reason="Native gait already active" end
        local fast=wanted=="SPRINT" or wanted=="BURST"
        io:hold("SHIFT",fast)
        local function request(mode,key)
            if self.pending and self.pending.mode~=mode and mode=="BURST_OFF" then self.pending=nil end
            if self.pending or (self.blocked[mode] or 0)>now then return end
            local sent=key=="SHIFT" and io:hold(key,true) or io:tap(key)
            if sent then
                self.attempts[mode]=(self.attempts[mode] or 0)+1
                self.requests+=1;self.pending={mode=mode,at=now}
                self.reason="Input requested; awaiting native gait"
                if mode=="BURST" then self.burstOwned=true end
                if mode=="TROT" then self.trotOwned=true end
            else self.blocked[mode]=now+8;self.reason="Gait input unavailable" end
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
    p.FilterDescendantsInstances={char};p.IgnoreWater=false;p.RespectCanCollide=true
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
        self.recoveryProgress=0;self.overlapAt=nil;self.overlapParts=nil
        self.detourUntil=nil;self.lastObstacleProbe=nil
        self.lastReason="NEW_ROUTE";self.goalStarted=now
        self.routeTravel=0;self.safetyBlockedUntil=nil;self.lastSafety=nil
    end
    function n:surface(pos,char,allowWater)
        local params=rayParams(char)
        local root=char and type(char.FindFirstChild)=="function" and char:FindFirstChild("HumanoidRootPart")
        local originY=root and root.Position.Y or pos.Y
        -- Prefer the real terrain under tall foliage. A low supporting solid
        -- surface may override it for rocks, bridges and constructed ground.
        local terrainParams=rayParams(char)
        terrainParams.FilterType=Enum.RaycastFilterType.Include
        terrainParams.FilterDescendantsInstances={self.workspace.Terrain}
        local terrain=self.workspace:Raycast(Vector3.new(pos.X,math.max(pos.Y,originY)+100,pos.Z),Vector3.new(0,-420,0),terrainParams)
        local solid=self.workspace:Raycast(Vector3.new(pos.X,originY+12,pos.Z),Vector3.new(0,-420,0),params)
        local hit=terrain or solid
        if solid and solid.Normal.Y>=.46 and solid.Position.Y<=originY+5
            and (not terrain or solid.Position.Y>terrain.Position.Y+.4) then hit=solid end
        if not hit then return nil end
        local wet=hit.Material==Enum.Material.Water
        if wet and not allowWater or not wet and hit.Normal.Y<(self.minGroundNormal or .46) then return nil end
        return hit.Position+Vector3.new(0,2.5,0),wet
    end
    function n:bodyClear(from,to,char)
        local direction=Vector3.new(to.X-from.X,0,to.Z-from.Z)
        if direction.Magnitude<.1 then return true end
        -- Sweeps omit shapes already touching their start volume. Check the
        -- actual animal root separately and allow movement out of an overlap.
        if self.bodyRoot and type(self.workspace.GetPartsInPart)=="function" and OverlapParams then
            local at=self.lastAt or 0
            if not self.overlapAt or at-self.overlapAt>.4 then
                self.overlapAt=at
                local params=OverlapParams.new()
                params.FilterType=Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances={char};params.RespectCanCollide=true;params.MaxParts=12
                local ok,parts=pcall(self.workspace.GetPartsInPart,self.workspace,self.bodyRoot,params)
                self.overlapParts=ok and parts or {}
            end
            for _,part in ipairs(self.overlapParts or {}) do
                if part.CanCollide~=false and part.Position then
                    local away=Vector3.new(from.X-part.Position.X,0,from.Z-part.Position.Z)
                    if away.Magnitude>.05 and direction:Dot(away)<0 then
                        self.lastObstacle={Instance=part};return false
                    end
                end
            end
        end
        if type(self.workspace.Blockcast)=="function" and CFrame and type(CFrame.lookAt)=="function" then
            local params=rayParams(char);params.IgnoreWater=true
            local size=Vector3.new((self.clearance or 2)*1.9,self.bodyHeight or 2,self.bodyLength or 4)
            local ok,hit=pcall(self.workspace.Blockcast,self.workspace,CFrame.lookAt(from,from+direction),size,direction,params)
            if ok and hit and (not hit.Instance or hit.Instance.CanCollide~=false) then
                self.lastObstacle=hit;return false
            end
        end
        return true
    end
    function n:clearSegment(from,to,char,allowWater)
        self.lastSafety=nil
        local distance=flat(from,to)
        if distance<.1 then return true,false end
        local params=rayParams(char);params.IgnoreWater=true
        if not self:bodyClear(from,to,char) then return false,false end
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
        local steps=math.max(1,math.ceil(distance/4))
        for step=0,steps do
            local p=from+(to-from)*(step/steps)
            local ground,water=self:surface(p,char,allowWater)
            if not ground then return false,wet end
            if not previous and from.Y-ground.Y>(self.supportHeight or 5)+(self.maxDrop or 3) then
                self.lastSafety="UNSUPPORTED_DROP";return false,wet
            end
            if previous then
                local rise=ground.Y-previous.Y
                if rise>(self.maxStepUp or 3) or -rise>(self.maxDrop or 3) then
                    self.lastSafety=rise>0 and "STEEP_ASCENT" or "UNSAFE_DESCENT"
                    return false,wet
                end
            end
            previous=ground;wet=wet or water
        end
        return true,wet
    end
    function n:detour(root,char,state,now)
        local delta=self.destination-root.Position
        local d=flat(self.destination,root.Position)
        if d<.1 then return false end
        local base=Vector3.new(delta.X/d,0,delta.Z/d)
        local span=math.clamp((self.clearance or 2)*2.5,8,18)
        local sides=self.detourSide or 1
        for _,angle in ipairs({sides*1.1,-sides*1.1,sides*1.8,-sides*1.8,math.pi}) do
            local x=base.X*math.cos(angle)-base.Z*math.sin(angle)
            local z=base.X*math.sin(angle)+base.Z*math.cos(angle)
            local point=self:surface(root.Position+Vector3.new(x*span,0,z*span),char,state.allowWater==true)
            if point and self:clearSegment(root.Position,point,char,state.allowWater==true) then
                self.epoch+=1;self.pending=nil
                self.points,self.index={point},1;self.routeOrigin=root.Position
                self.detourUntil=now+3;self.detourSide=-sides
                self.obstacleRecoveries=(self.obstacleRecoveries or 0)+1
                self.lastFailure="LOCAL_OBSTACLE_DETOUR"
                return true
            end
        end
        return false
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
                        -- A successful mesh path can include steep drops and
                        -- unchecked ledges. Validate its actual walking edges.
                        local safe=#points>0;local previous=from
                        for _,p in ipairs(points) do
                            if not self:clearSegment(previous,p,char,false) then safe=false;break end
                            previous=p
                        end
                        if safe then return points,"PATH_SURFACE" end
                    end
                end
            end
        end
        return nil,"NO_STREAMED_SAFE_ROUTE"
    end
    function n:route(root,hum,char,now,state)
        if self.pending or (self.activeJobs or 0)>=2 or now<self.nextRouteAt then return end
        local epoch=self.epoch
        local request={at=now,epoch=epoch,origin=root.Position,goal=self.destination}
        self.pending=request;self.activeJobs=(self.activeJobs or 0)+1
        task.spawn(function()
            local ok,points,reason=pcall(self.compute,self,request.origin,root,hum,char,
                table.clone(state or {}),request.goal,self.replans)
            self.activeJobs-=1
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
        return delta.Unit*(self.inputScale or 1)
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
        if direction.Magnitude<.01 then self:releaseSteering();return end
        -- Keys are digital: an analog following scale must not fall below
        -- every direction threshold and silently stop a moving pursuit.
        direction=direction.Unit
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
        self.bodyRoot=root
        self.clearance=math.clamp(root.Size.X*.5+.65,2,12)
        self.bodyHeight=math.clamp(root.Size.Y*.8,1,10)
        self.bodyLength=math.clamp(root.Size.Z*.65,2,18)
        self.supportHeight=math.max(2,hum.HipHeight+root.Size.Y*.5)
        self.maxDrop=math.clamp(hum.HipHeight*.75,2,4)
        self.maxStepUp=math.clamp(hum.HipHeight,2,4)
        self.minGroundNormal=math.cos(math.rad(math.clamp(hum.MaxSlopeAngle or 55,20,55)))
        if not self.destination or self.body~=char or self.identity~=identity then self:reset(destination,char,now,identity) end
        local targetShift=flat(destination,self.destination)
        self.destination=destination
        self.arrivalRadius=state.moveRadius or 8
        self.inputScale=state.moveScale and math.clamp(state.moveScale,.15,1) or 1
        local total=flat(root.Position,destination);self.distance=total
        if total<=self.arrivalRadius then self:stop(hum,root,"ARRIVED");return "REACHED" end

        local dt=now-(self.lastSampleAt or now)
        if self.lastPosition and dt>0 then
            local moved=flat(root.Position,self.lastPosition)
            if moved>math.max(90,(self.speed or 0)*dt*3+35) then
                self.corrections+=1;self.points={};self.epoch+=1;self.pending=nil
                self.desiredPoint=nil;self:releaseSteering()
                self.lastFailure="POSITION_CORRECTION";self.lastProgressAt=now
                if self.corrections>=3 then self:stop(hum,root,"REPEATED_CORRECTIONS");return "STUCK" end
            else
                self.travelled+=moved;self.routeTravel+=moved;self.windowTravel+=moved
                self.speed=self.speed*.6+math.min(180,moved/dt)*.4
                local wp=self.points[self.index]
                if wp and flat(self.lastPosition,wp)-flat(root.Position,wp)>math.max(.05,dt*.4) then
                    self.lastProgressAt=now;self.inputVerified=true
                    self.recoveryProgress+=moved
                    if self.recoveryProgress>15 then self.stallsInRow=0 end
                end
            end
        end
        self.lastPosition=root.Position;self.lastSampleAt=now
        self.windowOrigin=self.windowOrigin or root.Position
        local oscillating=false
        if now-self.windowAt>=6 then
            if self.windowTravel>35 and flat(root.Position,self.windowOrigin)<6 then
                self.lastProgressAt=math.min(self.lastProgressAt,now-6)
                self.lastFailure="OSCILLATION"
                oscillating=true
            end
            self.windowOrigin=root.Position;self.windowTravel=0;self.windowAt=now
        end
        local waypointRadius=self.detourUntil and now<self.detourUntil and 2 or math.clamp(root.Size.X*.5+4,6,12)
        local advanced=self:advance(root,waypointRadius)
        if advanced and not oscillating then self.lastProgressAt=now;self.inputVerified=true end
        if self.pending and now-self.pending.at>4 then
            self.epoch+=1;self.pending=nil;self.routeFailures+=1
            self.lastFailure="PATH_TIMEOUT"
        end
        if self.routeFailures>=4 then self:stop(hum,root,self.lastFailure);return "STUCK" end
        if now-self.lastProgressAt>.9 and now-(self.lastObstacleProbe or 0)>1
            and not (self.detourUntil and now<self.detourUntil and self.index<=#self.points) then
            self.lastObstacleProbe=now
            local probePoint=self.desiredPoint or destination
            local towards=probePoint-root.Position
            local dist=flat(probePoint,root.Position)
            if dist>1 then
                local probe=root.Position+Vector3.new(towards.X/dist,0,towards.Z/dist)*math.min(12,dist)
                if not self:bodyClear(root.Position,probe,char) then
                    self.lastCollisionAt=now
                    self:detour(root,char,state,now)
                end
            end
        end
        if now-self.lastProgressAt>(self.inputVerified and 2.5 or 1.6) then
            self.stallsInRow+=1;self.replans+=1;self.lastProgressAt=now
            self.recoveryProgress=0
            self.points={};self.epoch+=1;self.pending=nil;self.desiredPoint=nil
            self:releaseSteering();self:hold("SHIFT",false)
            self.lastFailure=self.lastFailure=="OSCILLATION" and self.lastFailure or "NO_PHYSICAL_PROGRESS"
            if self.stallsInRow==1 and self.steeringStrategy=="WORLD" and now-(self.lastCollisionAt or -100)>3 then
                self.steeringStrategy="KEY";self.strategyChanges+=1
            elseif self.stallsInRow==2 and type(keypress)=="function" then self.keyBackend="EXECUTOR" end
            if self.stallsInRow>=3 then self:stop(hum,root,"BOUNDED_STUCK");return "STUCK" end
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
        if (not self.detourUntil or now>=self.detourUntil or exhausted) and (exhausted or prefetch or targetShift>14 and now-(self.routeAt or 0)>1.1) then
            self:route(root,hum,char,now,state)
        end
        self:advance(root,waypointRadius)
        local waypoint=self.points[self.index]
        if not waypoint then
            self.desiredPoint=nil;self:releaseSteering();self:hold("SHIFT",false)
            self.lastReason=self.pending and "PLANNING" or self.lastFailure or "WAIT_ROUTE"
            return "WAIT"
        end
        if not state.movingTarget and not (self.detourUntil and now<self.detourUntil)
            and now>=(self.shortcutAt or 0) then
            self.shortcutAt=now+.75
            local d=destination-root.Position
            local direct=self:surface(root.Position+Vector3.new(d.X/total,0,d.Z/total)*math.min(total,100),char,state.allowWater==true)
            -- Prefer the checked straight corridor when an old obstacle path
            -- is no longer necessary. Do not cut a mountain bend blindly.
            if direct and flat(direct,waypoint)>8 and self:clearSegment(root.Position,direct,char,state.allowWater==true) then
                self.epoch+=1;self.pending=nil;self.points={direct};self.index=1
                self.routeOrigin=root.Position;self.segmentCount+=1;waypoint=direct
            end
        end
        -- Collapse straight, visible path sections into a body-checked horizon.
        -- Gaits can remain fast across tiny mesh waypoints without cutting bends.
        for j=math.min(#self.points,self.index+7),self.index+1,-1 do
            local candidate=self.points[j]
            if flat(root.Position,candidate)<=120 and self.math.turn(p2(root.Position),p2(waypoint),p2(candidate))<22
                and self:clearSegment(root.Position,candidate,char,state.allowWater==true) then
                self.index=j;waypoint=candidate;break
            end
        end
        -- Directly track a nearby moving target only over checked terrain.
        if state.movingTarget and total<28 then
            local clear=self:clearSegment(root.Position,destination,char,state.allowWater==true)
            if clear then waypoint=destination end
        end
        -- Recheck the immediate corridor after every meaningful navigation
        -- update. Terrain may stream/change after the path was computed.
        local ahead=waypoint-root.Position;local aheadFlat=flat(root.Position,waypoint)
        local reach=math.min(aheadFlat,math.max(8,self.speed*.5+self.bodyLength*.5))
        if aheadFlat>.1 then
            local probe=root.Position+Vector3.new(ahead.X/aheadFlat*reach,0,ahead.Z/aheadFlat*reach)
            local safe=self:clearSegment(root.Position,probe,char,state.allowWater==true)
            if not safe then
                self.desiredPoint=nil;self:releaseSteering();self:hold("SHIFT",false)
                if hum then pcall(hum.Move,hum,Vector3.zero,false) end
                self.lastFailure=self.lastSafety or "BLOCKED_CORRIDOR";self.lastReason="CHECKING_SAFE_APPROACH"
                self.points={};self.epoch+=1;self.pending=nil;self.nextRouteAt=now+.15
                return "WAIT"
            end
        end
        local look=root.CFrame and root.CFrame.LookVector
        local previous=look and {x=root.Position.X-look.X*5,z=root.Position.Z-look.Z*5} or nil
        local turn=self.math.turn(previous,p2(root.Position),p2(waypoint))
        local localRange=flat(root.Position,waypoint)
        local nextPoint=self.points[self.index+1]
        if nextPoint and self.math.turn(p2(root.Position),p2(waypoint),p2(nextPoint))>55 and localRange<35 then turn=math.max(turn,85) end
        local braking=turn>72 or total<18 or (nextPoint and localRange<math.max(20,self.speed*.55))
        state.brake=braking or self.detourUntil and now<self.detourUntil
        local wanted=self.math.select(state.hunting and total*2 or total,turn,state.staminaFraction,{
            allowBurst=state.allowBurst~=false and self.inputVerified and localRange>=38,
            nativeBurstAvailable=type(state.hudBurst)=="boolean",
            burstReady=not state.hudBurstNo,swimming=state.swimming,
            swimSprint=state.swimSprint,combat=state.combat,hunting=state.hunting,
            preySpeed=state.preySpeed,following=state.following,gaitSpeeds=state.gaitSpeeds,ability=state.ability})
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
            staminaFraction=self.lastState and self.lastState.staminaFraction,
            inputVerified=self.inputVerified,distance=self.distance,
            travelled=math.floor(self.travelled*10)/10,speed=math.floor(self.speed*10)/10,
            routeTravel=math.floor((self.routeTravel or 0)*10)/10,routeAge=self.goalStarted and (self.lastAt-self.goalStarted),
            stalledFor=self.lastProgressAt and (self.lastAt-self.lastProgressAt),safety=self.lastSafety,
            replans=self.replans,failures=self.failures,waterRoutes=self.waterRoutes,
            corrections=self.corrections,segments=self.segmentCount,obstacleRecoveries=self.obstacleRecoveries or 0}
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
        self.lastBlockedReason=self.lastBlockedReason or self.lastResult
        self.blockedAt=now;self.abandonReason=why
        self.lastResult=why;self.nextSelect=now+.25
        self.adapter:stop(why)
    end
    function h:tick(s)
        local now=s.now
        if self.adapter.attackEvidence then self.inputEvidence=self.adapter:attackEvidence(s) end
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
            self.closingAt=now;self.sample=nil;self.noDamageAt=nil;self.missesOnTarget=0
            self.lastTargetHealth=prey.health or prey.hum and prey.hum.Health
            self.lastUsefulAt=now;self.blockedSince=nil;self.nextAttack=now
            self.repositionUntil=nil;self.previousThrottle=nil;self.fullSpeed=nil;self.routeRetries=0
        end
        local health=prey.health or prey.hum and prey.hum.Health
        if finite(health) and finite(self.lastTargetHealth) and health<self.lastTargetHealth-.01 then
            self.lastUsefulAt=now;self.noDamageAt=now;self.closingAt=now
            self.missesOnTarget=0;self.routeRetries=0
        end
        self.lastTargetHealth=health
        if self.pending then
            local p=self.pending
            if finite(health) and health<p.health-.01 then
                self.hits+=1;self.noDamageAt=now;self.missesOnTarget=0
                self.lastResult="Observed prey HP decline after input; attribution unverified"
                self.pending=nil
            elseif now-p.at>1.1 then
                self.misses+=1;self.missesOnTarget+=1
                self.lastResult="No prey HP decline observed"
                self.lastBlockedReason=self.lastResult;self.lastBlockedAt=now
                self.pending=nil;self.repositionUntil=now+.55
            end
        end
        local d=distance(s.position,prey.position)
        if d<self.bestDistance-2 then self.bestDistance=d;self.closingAt=now;self.lastUsefulAt=now;self.routeRetries=0 end
        if d>390 or now-self.lastUsefulAt>60 or self.missesOnTarget>=5
            or now-self.closingAt>12 and d>28 or self.noDamageAt and now-self.noDamageAt>16 and d<28 then
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
        local geometry=type(self.adapter.attackGeometry)=="function" and self.adapter:attackGeometry(s,prey) or nil
        local valid=geometry and geometry.valid
        self.geometry=geometry
        if not valid then
            self.lastBlockedReason=geometry and geometry.reason or "Native bite geometry unavailable"
            self.lastBlockedAt=now
            self.lastResult=self.lastBlockedReason
        end
        if not valid then self.blockedSince=nil end
        local heading=speed>1 and {x=velocity.x/speed,z=velocity.z/speed} or prey.forward
        local standoff=math.clamp((prey.attackRange or 7)*.65,2.4,8)
        local target={x=prey.position.x+velocity.x*lead,z=prey.position.z+velocity.z*lead}
        if heading then
            target.x-=heading.x*standoff;target.z-=heading.z*standoff
        end
        local following=speed>1 and d<standoff+10 and geometry and geometry.inRange
        local scale=1
        if following then
            local nav=self.adapter.nav
            local observed=nav and nav.speed
            local previous=self.previousThrottle or 1
            if observed and observed>2 then self.fullSpeed=(self.fullSpeed or observed)*.7+(observed/math.max(previous,.2))*.3 end
            if self.fullSpeed and self.fullSpeed>2 then
                scale=math.clamp((speed+(d-standoff)*1.8)/self.fullSpeed,.15,1)
            end
        end
        self.previousThrottle=scale
        -- Keep pursuing while verifying a previous bite; a coarse range check
        -- must never freeze a hunter while its prey runs out of range.
        if valid and now>=self.nextAttack and not self.pending and now>=(self.repositionUntil or 0) then
            local sent,why=self.adapter:bite(s,prey)
            if self.adapter.attackEvidence then self.inputEvidence=self.adapter:attackEvidence(s) end
            self.lastResult=why or (sent and "Attack requested; awaiting prey HP" or "Native attack not ready")
            self.nextAttack=now+(sent and (s.attackCooldown or .9) or .25)
            if sent then self.blockedSince=nil;self.noDamageAt=self.noDamageAt or now
            else self.blockedSince=self.blockedSince or now;self.lastBlockedReason=self.lastResult;self.lastBlockedAt=now end
            if sent and finite(health) then
                self.attacks+=1;self.pending={at=now,health=health}
            end
        end
        if self.blockedSince and now-self.blockedSince>12 then
            self:abandon(now,"Native attack unavailable: "..tostring(self.lastResult))
            return "HUNT_REPLAN",self.lastResult
        end
        if valid and speed<2 and not self.repositionUntil then
            self.adapter:stop("valid stationary attack position")
        else
            if geometry and geometry.inRange and geometry.facing==false and geometry.clear~=false then
                -- Walking toward a parking point behind prey can end with our
                -- animal facing away and no remaining movement. Approach the
                -- prey itself until native movement turns us toward it.
                target={x=prey.position.x,z=prey.position.z}
            elseif geometry and geometry.inRange and not valid or now<(self.repositionUntil or 0) then
                local dx,dz=prey.position.x-s.position.x,prey.position.z-s.position.z
                local len=math.max(1,math.sqrt(dx*dx+dz*dz))
                local side=(self.missesOnTarget%2==0) and 1 or -1
                if heading then
                    target={x=prey.position.x-heading.x*standoff-heading.z*side*2,
                        z=prey.position.z-heading.z*standoff+heading.x*side*2}
                else
                    target={x=prey.position.x+dx/len*2-dz/len*side*2,
                        z=prey.position.z+dz/len*2+dx/len*side*2}
                end
            end
            local result=self.adapter:move(target,s,{navKey=prey.model or "NPC_HUNT",
                movingTarget=true,hunting=true,following=following,moveScale=scale,preySpeed=speed,moveRadius=.9})
            if result=="STUCK" or result=="BLOCKED" then
                self.routeRetries=(self.routeRetries or 0)+1
                self.adapter:stop("Retrying approach to committed prey")
                if self.routeRetries>=3 then
                    self:abandon(now,"NPC pursuit route failed repeatedly")
                    return "HUNT_REPLAN",self.lastResult
                end
            end
        end
        if self.repositionUntil and now>=self.repositionUntil then self.repositionUntil=nil end
        self.distance=d;self.preySpeed=speed
        return self.pending and "HUNT_VERIFY" or valid and "HUNT_ATTACK" or "HUNT_APPROACH",self.lastResult
    end
    function h:resume(delay)
        -- Manual intervention pauses a hunt; it does not blacklist its prey.
        for _,key in ipairs({"started","closingAt","noDamageAt","lastUsefulAt","blockedSince"}) do
            if self[key] then self[key]+=delay end
        end
        self.pending=nil;self.sample=nil;self.nextAttack=0
    end
    function h:status()
        return {attacks=self.attacks,hpDeclines=self.hits,misses=self.misses,
            result=self.lastResult,distance=self.distance,preySpeed=self.preySpeed,
            active=self.target~=nil,killsObserved=self.kills,blockedSince=self.blockedSince,
            committedSince=self.started,lastUsefulAt=self.lastUsefulAt,abandonReason=self.abandonReason,
            geometry=self.geometry,lastBlockedReason=self.lastBlockedReason,lastBlockedAt=self.lastBlockedAt,inputEvidence=self.inputEvidence}
    end
    return h
end
return Hunt
]============]
sources["care"] = [============[
-- Feeding handshake and recovery. Native approach, active feeding and an input
-- request have distinct lifetimes; manual cancellation never leaves a stale latch.
local Care={}
local function active(s,kind)
    return s.nativeFeedMode==kind or s.feedMode==kind or s.feedMode==true
end
local function meal(g,now)
    if not g.meal then g.meal={requests=0,at=now,progressAt=now} end
    return g.meal
end
function Care.interrupt(g,now)
    if not g or g.kind~="EAT" and g.kind~="DRINK" then return end
    local m=meal(g,now)
    m.interrupted=true;m.interruptedAt=now
end
function Care.requested(g,now)
    local m=meal(g,now)
    m.requests+=1;m.at=now;m.pending=true;m.owned=true
    m.interrupted=false;m.seenActive=false;m.progressAt=now
    g.feedPending=true;g.feedAt=now
end
function Care.resetSite(g,now)
    g.meal={requests=0,at=now,progressAt=now};g.feedPending=nil
    g.feedAt=nil;g.nextAction=now+.2;g.stopFeedRequested=nil
end
function Care.step(g,s,adapter)
    local now=s.now;local m=meal(g,now)
    local kind=g.kind=="DRINK" and "drink" or "eat"
    local value=kind=="drink" and s.thirst or s.hunger
    if type(value)~="number" or type(g.baseline)~="number" then return "FAILED","Native needs unavailable" end
    g.gain=value-g.baseline
    if m.value and value>m.value+.02 then m.progressAt=now;m.requests=0 end
    m.value=value
    local running=active(s,kind)
    local other=s.nativeFeedMode and s.nativeFeedMode~=kind
        or s.feedMode and s.feedMode~=false and s.feedMode~=kind and s.feedMode~=true
    if other then return "BUSY","Another native feeding session owns movement" end
    local idleKnown=s.nativeFeedKnown==true and s.nativeFeedMode==nil and not running
    if running then m.seenActive=true;m.interrupted=false end
    if m.interrupted and not running and now-(m.interruptedAt or now)>=.35
        and (idleKnown or now-(m.interruptedAt or now)>=1.1) then
        m.pending=false;m.interrupted=false;m.cancelAt=nil;m.requests=0
        g.feedPending=nil;g.feedAt=nil;g.arrivedAt=nil;g.stopFeedRequested=nil
        g.nextAction=now
    elseif m.pending and m.seenActive and not running then
        -- The native session ended below the care target: continue the same
        -- objective immediately, instead of waiting for a 14-second timeout.
        m.pending=false;m.seenActive=false;m.cancelAt=nil;g.feedPending=nil;g.nextAction=now+.2
    elseif m.pending and not running and now-m.at>=(idleKnown and .75 or 2.2) then
        m.pending=false;g.feedPending=nil;g.nextAction=now+.2
        if m.requests>=3 then return "RELOCATE","Native feed request was not acknowledged" end
    end
    local target=kind=="drink" and (s.drinkTarget or s.thirstMax or 100)-.2 or (s.careTarget or 72)
    if value>=target and g.gain>.25 then
        if running then
            m.fullAt=m.fullAt or now
            if m.owned and not m.cancelAt and adapter.cancelFeed then
                if adapter:cancelFeed(s) then m.cancelAt=now end
            end
            if m.owned and now-(m.cancelAt or m.fullAt)>2 then
                return "FAILED","Thirst or hunger recovered; native feeding release unconfirmed"
            end
            return "BUSY","Needs recovered; finishing native feeding"
        end
        return "COMPLETE",(kind=="drink" and "Thirst" or "Hunger").." actually increased"
    end
    if m.cancelAt then
        if not running and (idleKnown or now-m.cancelAt>.5) then
            m.pending=false;g.feedPending=nil;return "RELOCATE","Trying a fresh feed access"
        end
        if now-m.cancelAt>2 then return "FAILED","Native feeding cancellation unconfirmed" end
        return "BUSY","Releasing a stalled native feeding session"
    end
    if running and now-m.progressAt>5.5 then
        if m.owned and adapter.cancelFeed and adapter:cancelFeed(s) then
            m.cancelAt=now;return "BUSY","Restarting feeding after no resource progress"
        end
        if now-m.progressAt>8 then return "FAILED","Native feeding has no resource progress" end
    end
    if running then return "BUSY","Native feeding active; watching needs" end
    if m.pending then return "BUSY","Native feeding approach requested" end
    return "READY","Finding native "..kind.." access"
end
return Care
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
function Agent.new(planner,adapter,Hunt,Care)
    local a={planner=planner,adapter=adapter,Hunt=Hunt,Care=Care,enabled=false,phase="OFF",goal=nil,
        cooldown={},careCooldown={},recent={},waitingSince={},events={},ticks=0,earned=0,claimed=0,scented=0,
        feeds=0,hunts=0,failures=0,nextTick=0,reason="Disabled",generation=0,returns={},version="0.6.1"}
    function a:log(at,kind,msg)
        table.insert(self.events,{at=math.floor(at*10)/10,kind=kind,msg=msg})
        if kind=="confirmed" or kind=="deferred" or kind=="failed" then self.lastNotice=msg end
        while #self.events>35 do table.remove(self.events,1) end
    end
    function a:setEnabled(on)
        local ownedFeed=self.enabled and self.goal and self.goal.feedPending
        self.generation+=1;self.enabled=on==true
        if not self.enabled then
            self.goal,self.suspended=nil,nil;self.returns={};self.phase="OFF";self.reason="Disabled"
            self.adapter:stop("disabled")
            if self.adapter.releaseInputs then self.adapter:releaseInputs() end
            if ownedFeed and self.lastState then
                if self.adapter.cancelFeed then self.adapter:cancelFeed(self.lastState) end
            end
        else self.nextTick=0;self.prevAmber=nil;self.needWindow={};self.needRates={};self.reason="Assessing animal and territory" end
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
        local g=self.goal
        if g and g.kind=="TERRITORY" then self.cooldown[g.key]=state.now+90
        elseif g then self.careCooldown[g.kind]=state.now+2 end
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
        local g=self.suspended;self.suspended=table.remove(self.returns)
        if g and g.kind=="TERRITORY" then
            local current=self.adapter:territory(g.key,state)
            local detail=current and self.planner.objective(current,state,state.position,{blockedUntil=self.cooldown})
            if detail then
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
        return {version=self.version,enabled=self.enabled,phase=self.phase,reason=self.reason,
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
        if self.Care then self.Care.interrupt(self.goal,state.now) end
        self.phase="PAUSED";self.reason=reason;self.adapter:stop(reason)
    end
    function a:tick(now)
        if not self.enabled or now<self.nextTick then return end
        self.nextTick=now+.15;self.ticks+=1
        if self.goal and self.phaseAt and self.phaseGoal==self.goal then
            self.goal.durations=self.goal.durations or {}
            self.goal.durations[self.phase]=(self.goal.durations[self.phase] or 0)+math.clamp(now-self.phaseAt,0,2)
        end
        self.phaseAt=now;self.phaseGoal=self.goal
        if self.adapter.prepare then self.adapter:prepare(now,true,self.goal) end
        local state=self.adapter:snapshot(now)
        if not state or not state.alive or not state.position then
            self.phase="WAIT";self.reason="Living animal unavailable"
            self.goal,self.suspended=nil,nil;self.returns={};self.adapter:stop("despawn");return
        end
        state.now=now;self.lastState=state;self.species,self.coat=state.species,state.coat
        local changed=self.initialized and (self.lastCharacter~=state.char or self.lastPack~=state.pack
            or self.lastBiome~=state.biome or self.lastSpecies~=state.species)
        if changed then
            self.goal,self.suspended=nil,nil;self.returns={};self.cooldown,self.recent,self.careCooldown={},{},{}
            self.waitingSince={};self.regionCursor=1
            self.needWindow={};self.needRates={}
            self.adapter:stop("animal / pack / map changed")
            self.lastTerritoryKey=nil;self.pausedAt=nil
            self:log(now,"reset","Changed animal, pack or map")
        end
        self.initialized=true
        self.lastCharacter,self.lastPack,self.lastBiome,self.lastSpecies=state.char,state.pack,state.biome,state.species
        self.needRates=self.needRates or {}
        self.needWindow=self.needWindow or {}
        for _,key in ipairs({"hunger","thirst"}) do
            local sample,value=self.needWindow[key],state[key]
            if not finite(value) then self.needWindow[key]=nil
            elseif not sample or sample.char~=state.char or value>sample.value+.02 or now-sample.at>15 then
                self.needWindow[key]={char=state.char,at=now,value=value}
            elseif now-sample.at>=4 then
                -- Include idle samples between replicated resource updates;
                -- averaging only falling ticks exaggerates consumption.
                local rate=(sample.value-value)/(now-sample.at)
                if rate>=0 and rate<2 then
                    self.needRates[key]=(self.needRates[key] or rate)*.6+rate*.4
                end
                self.needWindow[key]={char=state.char,at=now,value=value}
            end
        end
        for _,key in ipairs({"hunger","thirst"}) do
            local rate=self.needRates[key]
            if finite(state[key]) and rate and rate>.001 then state[key.."Reserve"]=math.max(0,state[key]-12)/rate end
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
        local need=self.planner.need(state)
        if not self.goal and self.suspended and need=="TERRITORY" then self:resume(state) end
        local goal=self.goal
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
            and finite(state.thirst) and state.thirst<(state.thirstMax or 100)-.8
            and now-(self.lastFullDrinkAt or -100)>20
        if opportunistic and state.healthFraction>=.45 then need="DRINK" end
        -- Finish a progressing near-complete claim before routine care. A
        -- critical need, genuine contest or native interruption still wins.
        local protected=false
        if goal and goal.kind=="TERRITORY" and need~="TERRITORY" then
            local t=self.adapter:territory(goal.key,state)
            local p=t and (goal.detail.kind=="SCENT" and t.hold or t.prog)
            if type(p)=="number" and p>=.72 and p<=1 and state.healthFraction>=.45
                and (state.hunger or 100)>17 and (state.thirst or 100)>17 then
                goal.finishUntil=goal.finishUntil or now+math.clamp((goal.detail.kind=="SCENT" and (state.refillTime or 60) or 20)*(1-p)+2,2,18)
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
            local urgentGoal=goal.detail.kind=="SCENT" and current and finite(current.hold) and current.hold<.28
            if not almostDone and not urgentGoal and flat(state.position,goal.detail.center)>(state.claimRadius or 15) then
                local route,strategy=self.planner.strategy(self.adapter:territories(state),state,{
                    blockedUntil=self.cooldown,regionCursor=self.regionCursor,maxStops=1})
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
        local urgent=state.thirst and state.thirst<19 and "DRINK"
            or state.hunger and state.hunger<19 and "EAT"
            or state.healthFraction<.3 and "RECOVER" or nil
        -- A latched meal cannot ignore a different need becoming lethal.
        -- Cancel only our own native feeding session and wait for its release.
        local emergency=goal and goal.kind=="EAT" and finite(state.thirst) and state.thirst<10 and "DRINK"
            or goal and goal.kind=="DRINK" and finite(state.hunger) and state.hunger<10 and "EAT"
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
            local hexes=self.adapter:territories(state)
            for _,hex in ipairs(hexes) do
                if not hex.neutral then self.waitingSince[hex.key]=self.waitingSince[hex.key] or now end
            end
            local route,strategy=self.planner.strategy(hexes,state,{
                blockedUntil=self.cooldown,recent=self.recent,waitingSince=self.waitingSince,
                avoidRadius=state.avoidRadius or 35,maxStops=3,regionCursor=self.regionCursor})
            self.strategy=strategy;self.regionCursor=strategy.cursor
            if #route==0 then
                local patrol=self.adapter.patrol and self.adapter:patrol(state)
                if patrol then
                    self.phase="PATROL";self.reason="Territories maintained; checking the next area"
                    self.adapter:move(patrol,state,{navKey="PATROL:"..tostring(patrol.key),moveRadius=12})
                else
                    self.phase="WATCH";self.reason="No available territory; checking occupied areas"
                    self.adapter:stop("no available target")
                end
                return
            end
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
            if outsideHex or flat(state.position,waypoint)>(state.claimRadius or 15) and not localProgress then
                self.phase="TRAVEL";self.reason=goal.detail.kind.." "..goal.key
                local result=self.adapter:move(waypoint,state,{navKey="HEX:"..goal.key,moveRadius=10})
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
            local stallLimit=goal.nativeStarted and 4.5 or 3.2
            if stall>stallLimit and (goal.alternates or 0)<3 then
                goal.alternates=(goal.alternates or 0)+1;goal.progressAt=now;goal.interactAt=now
                self.adapter:advanceSpot(goal.key);self.phase="REPOSITION"
                self.reason="Trying another surface position in "..goal.key
            elseif stall>6 or now-goal.interactAt>75 then self:fail(state,"No confirmed territory progress") end
            return
        end
        local kind=goal.kind=="DRINK" and "drink" or "eat"
        local careStatus,careReason=self.Care.step(goal,state,self.adapter)
        if careStatus=="COMPLETE" then
            self.lastCare={kind=goal.kind,seconds=now-goal.start,phases=goal.durations,gain=goal.gain,
                manualInterventionObserved=goal.manualInterventionObserved==true}
            if kind=="drink" then self.lastFullDrinkAt=now end
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
            if result=="STUCK" then
                if self.adapter.avoidWater then self.adapter:avoidWater(goal.location,now) end
                goal.location=nil;goal.arrivedAt=nil
            end
            return
        end
        local food=self.adapter.food and self.adapter:food(state,goal.food)
        if food then
            if not goal.food or goal.food.model~=food.model then goal.foodArrived=nil end
            goal.food=food;self.phase="TRAVEL_FOOD";self.reason="Approaching native edible food"
            local result=self.adapter:move(food.position,state,{navKey=food.model or "FOOD",moveRadius=2})
            if result=="REACHED" then goal.foodArrived=goal.foodArrived or now end
            if result=="STUCK" or goal.foodArrived and now-goal.foodArrived>2.5 then
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
        local h=self.ownerHub or (type(getgenv)=="function" and getgenv() or _G).FERAL_RENAISSANCE_ACTIVE
        return type(h)=="table" and not h.closed and h.bridge and h.bridge.player==player and h or nil
    end
    function b:prepare(now,enabled,goal)
        local h=self:hub()
        if not enabled or not h then return end
        if h.walk and type(h.stopWalk)=="function" then h:stopWalk("Amber movement owner") end
        h.nextWalk=now+90
        -- Coordinate with existing recovery instead of letting it start Rest
        -- during travel, feeding approach or hunt preparation.
        local recovering=goal and goal.kind=="RECOVER"
        if recovering and h.recovery and h.recovery.owned==player.Character
            and not (h.policy and h.policy.manualRest) then
            local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            recovering=not (hum and hum.MaxHealth>0 and hum.Health/hum.MaxHealth>=.72)
        end
        if not recovering then
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
        if ok then return value end
        return nil
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
    local function packKey(value)
        if value==nil or value==false or value==0 or value=="0" or value=="" or value=="None" then return nil end
        return tostring(value)
    end
    function b:hexAt(position)
        if not self.cfg or type(self.cfg.hexAt)~="function" or not position then return nil end
        local ok,i,j=pcall(self.cfg.hexAt,position.x,position.z)
        if not ok then return nil end
        if type(self.cfg.hexKey)=="function" then
            local good,key=pcall(self.cfg.hexKey,i,j)
            if good then return key end
        end
        return "H"..tostring(i).."_"..tostring(j)
    end
    function b:otherPlayerPositions()
        local all,occupied={},{}
        local mine=packKey(attr(player,"FeralPack"))
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player then
                local c=p.Character
                local root=c and c:FindFirstChild("HumanoidRootPart")
                local theirs=packKey(attr(p,"FeralPack") or attr(c,"FeralPack"))
                local same=mine~=nil and theirs==mine
                if root and not same then
                    local pos=point(root.Position);pos.hex=self:hexAt(pos)
                    table.insert(all,pos)
                    if pos.hex then occupied[pos.hex]=(occupied[pos.hex] or 0)+1 end
                end
            end
        end
        return all,occupied
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
                    if type(self.cfg.regionCell)=="function" then
                        local valid,region=pcall(self.cfg.regionCell,p.X,p.Y)
                        if valid and finite(region) then h.region=region end
                    end
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
            fade=terrAttr(key,"fade"),center=h.center,spot=h.spot,region=h.region}
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
        local root=c and c:FindFirstChild("HumanoidRootPart")
        if root and type(b.nav.surface)=="function" then
            return b.nav:surface(Vector3.new(x,root.Position.Y,z),c,false)
        end
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
        if type(UserInput.IsMouseButtonPressed)=="function" and Enum.UserInputType then
            local ok,down=pcall(UserInput.IsMouseButtonPressed,UserInput,Enum.UserInputType.MouseButton1)
            if ok and down and not (self.pendingInputs and self.pendingInputs.M1) then return true end
        end
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
        params.FilterDescendantsInstances={state.char};params.IgnoreWater=false;params.RespectCanCollide=true
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
        self.waterCache=nil;self.waterAt=0;self.waterScan=nil;self.waterMissUntil=nil
    end
    function b:water(state)
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
        if best then
            self.waterEvidence="NATIVE_OFFER";self.waterCache,self.waterAt=best,state.now;return best
        end
        if self.waterCache and state.now<(self.waterAt or 0)+3 then return self.waterCache end
        if self.waterMissUntil and state.now<self.waterMissUntil then return nil end
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
        table.sort(origins,function(a,b)return dist(a,state.position)<dist(b,state.position)end)
        local scan=self.waterScan
        if not scan or scan.char~=state.char or scan.biome~=state.biome
            or state.now-scan.at>6 or dist(scan.position,state.position)>100 then
            scan={at=state.now,char=state.char,biome=state.biome,position={x=state.position.x,z=state.position.z},points={},index=1}
            for _,origin in ipairs(origins) do
                for _,radius in ipairs(origin.rings) do
                    for k=0,(radius==0 and 0 or 7) do
                        local a=k*math.pi/4
                        table.insert(scan.points,{x=origin.x+math.cos(a)*radius,z=origin.z+math.sin(a)*radius,
                            dx=math.cos(a),dz=math.sin(a)})
                    end
                end
            end
            self.waterScan=scan
        end
        -- Bound terrain work per coordinator tick. Resume unfinished searches
        -- instead of repeating the whole map scan after an empty result.
        local stop=math.min(#scan.points,scan.index+23)
        for index=scan.index,stop do
            local probe=scan.points[index]
            local x,z=probe.x,probe.z
            local pos,wet=surfaceAt(x,z,state,true)
            if pos and wet then
                consider(pos)
                for _,reach in ipairs({7,15}) do
                    local bank=surfaceAt(x-probe.dx*reach,z-probe.dz*reach,state,false)
                    if bank and dist(bank,pos)<=reach+1 then consider(bank) end
                end
            end
        end
        scan.index=stop+1
        if scan.index>#scan.points then
            self.waterScan=nil;self.waterMissUntil=state.now+1.2
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
        local needs=config("NeedsConfig") or {}
        local attackCooldown
        local speciesConfig=config("Species")
        if speciesConfig and type(speciesConfig.biteCooldown)=="function" then
            local good,value=pcall(speciesConfig.biteCooldown,species,attr(c,"Growth") or 1)
            if good and finite(value) and value>=.1 and value<=10 then attackCooldown=value end
        end
        local offer=attr(c,"FeedCanPos")
        local others,contested=self:otherPlayerPositions()
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
            runIntent=attr(c,"WolfRunIntent"),allowBurst=reserve==nil or reserve>=.56,
            allowWater=profile.swim==true,swimSprint=profile.swimSprint==true,
            amber=amber,now=now,serverNow=at,unixNow=os.time(),players=others,contested=contested,currentHex=self:hexAt(point(r.Position)),
            avoidRadius=35,claimRadius=self.cfg and finite(self.cfg.CLAIM_RADIUS) and math.clamp(self.cfg.CLAIM_RADIUS,8,180) or 15,careTarget=85,
            thirstMax=finite(needs.THIRST_MAX) and needs.THIRST_MAX or 100,
            drinkTarget=finite(needs.THIRST_MAX) and needs.THIRST_MAX or 100,
            refillTime=self.cfg and self.cfg.REFILL_TIME,
            attackCooldown=attackCooldown,gaitSpeeds=profile.native and profile.native.gait,
            regionGrid=self.cfg and self.cfg.REGIONS and self.cfg.REGIONS.GRID,
            regionBonus=self.cfg and self.cfg.REGIONS and self.cfg.REGIONS.PAY_MULT,
            gameMenu=attr(player,"FeralMenuOpen")==true,menuOpen=UserInput:GetFocusedTextBox()~=nil,
            manualInput=self:manualInput(),combat=finite(at) and finite(untilCombat) and untilCombat>at or false,
            pinned=attr(c,"FeralPinned")==true or attr(c,"FeralDragged")==true or attr(c,"FeralCarried")==true,
            ability=attr(c,"FeralRolling")==true or attr(c,"FeralDowned")==true or attr(c,"FeralVenomDown")==true
                or attr(c,"FeralTalonLock")~=nil and attr(c,"FeralTalonLock")~=false
                or attr(c,"FeralDeathRollLocal")==true or attr(c,"FeralDiveBomb")==true
                or hub and hub.grab and hub.grab.active==true,
            rescuing=hub and hub.rescue and hub.rescue.pending~=nil,
            resting=attr(c,"WolfRest")==true,
            automaticRest=hub and hub.recovery and hub.recovery.owned==c and not (hub.policy and hub.policy.manualRest),
            flying=fly,swimming=swimming,
            climbing=attr(c,"FeralClimbLocal")==true,underwater=attr(c,"FeralUnderwater")==true}
    end
    function b:move(destination,state,options)
        if not destination then return "WAIT" end
        options=options or {}
        local s=table.clone(state)
        for key,value in pairs(options) do s[key]=value end
        local target=Vector3.new(destination.x,state.root.Position.Y,destination.z)
        local result=self.nav:tick(target,state.char,state.hum,state.root,state.now,{},s)
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
    function b:food(state,preferred)
        -- Keep a real edible food target instead of chasing a new nearest item
        -- on every tick. Revalidate consumption, diet, ownership and position.
        local item=preferred and preferred.model
        local profile=state.profile or self:profile(state.char,state.species)
        local forage=config("Forage")
        if item and item.Parent and item:IsDescendantOf(Workspace) and forage and type(forage.canEat)=="function" then
            local ok,edible=pcall(forage.canEat,profile.diet,attr(item,"Diet"))
            local left,owner=attr(item,"FoodLeft"),attr(item,"TutorialOwner")
            if ok and edible and attr(item,"Consumed")~=true and (not finite(left) or left>.01)
                and (owner==nil or owner==player.UserId) and (self.foodBlocked[item] or 0)<=state.now then
                local pos=attr(item,"FoodPos")
                if typeof(pos)~="Vector3" and item:IsA("BasePart") then pos=item.Position end
                if typeof(pos)~="Vector3" and item:IsA("Model") then
                    local good,cf=pcall(item.GetBoundingBox,item);if good then pos=cf.Position end
                end
                if typeof(pos)=="Vector3" and safePosition(point(pos),state) then
                    return {model=item,position=point(pos)}
                end
            end
        end
        local finder=config("FeedFinder")
        if finder and type(finder.food)=="function" then
            local ok,item,pos=pcall(finder.food,state.char,state.root)
            if ok and item and typeof(pos)=="Vector3" and safePosition(point(pos),state)
                and (self.foodBlocked[item] or 0)<=state.now then
                return {position=point(pos),model=item}
            end
        end
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
    function b:resourceSearch(state,kind)
        self.searchVisits=self.searchVisits or {}
        local active=self.searchPoint
        if active and self.searchKind==kind then
            local remaining=dist(active,state.position)
            if not self.searchBest or remaining<self.searchBest-1 then
                self.searchBest=remaining;self.searchProgressAt=state.now
            end
            if state.now<(self.searchUntil or 0) and state.now-(self.searchProgressAt or state.now)<15
                and remaining>12 then return active end
        end
        if active then self.searchVisits[active.key or "last"]=state.now end
        local best,score=nil,math.huge
        for _,hex in ipairs(self.hexes) do
            local p=hex.spot or hex.center
            local d=dist(p,state.position)
            local visited=self.searchVisits[hex.key] or -100
            if d>45 and d<650 and not (state.contested and state.contested[hex.key]) and state.now-visited>25 then
                local rank=d+(hex.key==state.currentHex and 120 or 0)
                if rank<score then best,score={x=p.x,z=p.z,key=hex.key},rank end
            end
        end
        self.searchPoint,self.searchUntil=best,state.now+120
        self.searchKind=kind;self.searchBest=best and dist(best,state.position);self.searchProgressAt=state.now
        return best
    end
    function b:patrol(state)
        self.patrolVisits=self.patrolVisits or {}
        local target=self.patrolTarget
        if target and dist(target,state.position)>14 and state.now<(self.patrolUntil or 0) then return target end
        if target then self.patrolVisits[target.key]=state.now end
        local best,score=nil,math.huge
        for _,h in ipairs(self.hexes) do
            local t=self:territory(h.key)
            local d=dist(state.position,h.spot or h.center)
            if t and not t.neutral and t.owner==state.pack and d>40 and not (state.contested and state.contested[h.key]) then
                local recent=self.patrolVisits[h.key]
                local rank=d+(recent and math.max(0,60-state.now+recent)*12 or 0)
                if rank<score then best,score={x=(h.spot or h.center).x,z=(h.spot or h.center).z,key=h.key},rank end
            end
        end
        self.patrolTarget,self.patrolUntil=best,state.now+12
        return best
    end
    function b:checkPrey(prey,state)
        local profile=state.profile or self:profile(state.char,state.species)
        if not prey or not prey.model or not prey.model.Parent or not profile.hunts then return nil end
        if Players:GetPlayerFromCharacter(prey.model) then return nil end
        local hub=self:hub()
        if hub and type(hub.bridge.combatEligible)=="function" then
            local ok,eligible=pcall(hub.bridge.combatEligible,hub.bridge,prey.model)
            if not ok or not eligible then return nil end
        end
        local pack=attr(prey.model,"FeralPack")
        if packKey(state.pack)~=nil and packKey(state.pack)==packKey(pack) then return nil end
        local root=prey.model:FindFirstChild("HumanoidRootPart")
        local hum=prey.model:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health<=0 or attr(prey.model,"FeralDead")==true
            or hum.MaxHealth>state.hum.MaxHealth*1.25 or (self.preyBlocked[prey.model] or 0)>state.now then return nil end
        local position=point(root.Position)
        if not safePosition(position,state,32) then return nil end
        local velocity=root.AssemblyLinearVelocity
        prey.position=position;prey.root=root;prey.hum=hum
        prey.velocity=velocity and point(velocity) or {x=0,z=0}
        local look=root.CFrame and root.CFrame.LookVector
        prey.forward=look and {x=look.X,z=look.Z} or nil
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
        local box=attr(state.root,"FeralBoxFull")
        if not finite(box) or box<=0 then box=state.root.Size.Z end
        local reach=(box*.5+state.hum.HipHeight*cfg.REACH+cfg.SLACK)*cfg.HIT_SCALE*mult("reachMult",1)
        local angle=planar.Magnitude>.01 and look.Unit:Dot(planar.Unit) or 1
        local height=(state.hum.HipHeight+prey.hum.HipHeight)*cfg.MAX_DY*mult("dyMult",1)
        local cone=mult("coneFor",cfg.CONE)
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={state.char};params.IgnoreWater=true
        params.RespectCanCollide=true
        local obstruction=Workspace:Raycast(state.root.Position,diff,params)
        local clear=not obstruction or obstruction.Instance and obstruction.Instance:IsDescendantOf(prey.model)
        local inRange=gap<reach*.92 and math.abs(diff.Y)<height*.95
        local facing=angle>math.cos(math.rad(cone))
        return {valid=inRange and facing and clear,inRange=inRange,facing=facing,
            angle=angle,gap=gap,reach=reach,clear=clear,height=math.abs(diff.Y),heightLimit=height*.95,
            reason=not inRange and "Outside native bite geometry" or not facing and "Facing away from prey"
                or not clear and "Bite corridor obstructed" or "Native attack geometry ready"}
    end
    function b:attackEvidence(state)
        if not self.lastAttackInput then return nil end
        local record=table.clone(self.lastAttackInput)
        record.age=state.now-record.at
        record.sameCharacter=self.attackCharacter==state.char
        local marker=record.sameCharacter and attr(state.char,"WolfBiteAt") or nil
        record.markerNow=finite(marker) and marker or nil
        record.markerAdvanced=record.sameCharacter and finite(marker)
            and (not finite(record.markerBefore) or marker>record.markerBefore+.000001) or false
        return record
    end
    function b:bite(state,prey)
        local p=self:checkPrey(prey,state)
        if not p then return false,"Prey unavailable" end
        local geometry=self:attackGeometry(state,p)
        if not geometry or not geometry.valid then return false,"Native range, facing or line of sight not ready" end
        self.attackCharacter=state.char
        self.lastAttackInput={at=state.now,markerBefore=attr(state.char,"WolfBiteAt"),sent=false,backend="NONE"}
        local hub=self:hub()
        if hub and type(hub.bridge.tryNativeBite)=="function" then
            if hub.recovery then hub.recovery:release("Amber hunt",state.now) end
            -- Readiness guidance is advisory. Cached/private timing must not
            -- suppress the original handler: that handler already owns the
            -- native cooldown, Rest and capture guards. Dispatch is still only
            -- an attempt; the hunter observes actual HP separately.
            if hub.policy then hub.policy:input("attack",state.now) end
            local ok,sent=pcall(hub.bridge.tryNativeBite,hub.bridge,state.now)
            if ok and sent then
                self.lastAttackInput.sent=true;self.lastAttackInput.backend="NATIVE_CALLBACK"
                self.lastInput="Native tryBite requested";return true,self.lastInput
            end
        end
        local species=config("Species")
        local delay=1.35
        if species and type(species.biteCooldown)=="function" then
            local ok,value=pcall(species.biteCooldown,state.species,attr(state.char,"Growth") or 1)
            if ok and finite(value) then delay=math.clamp(value,.15,10) end
        end
        if state.now<(self.nextBite or 0) then return false,"Native bite cooldown" end
        self.nextBite=state.now+delay
        local original=UserInput:GetMouseLocation()
        local m=original
        local camera=Workspace.CurrentCamera
        local gui=player:FindFirstChildOfClass("PlayerGui")
        local function clearAt(x,y)
            if not gui or type(gui.GetGuiObjectsAtPosition)~="function" then return true end
            local checked,objects=pcall(gui.GetGuiObjectsAtPosition,gui,x,y)
            if not checked then return false end
            for _,object in ipairs(objects) do
                if object.Active or object:IsA("GuiButton") or object:IsA("TextBox") then return false end
            end
            return true
        end
        if not clearAt(m.X,m.Y) then
            local found=false
            if camera and camera.ViewportSize then
                for _,uv in ipairs({{.08,.45},{.92,.45},{.5,.5},{.5,.82}}) do
                    local x,y=camera.ViewportSize.X*uv[1],camera.ViewportSize.Y*uv[2]
                    if clearAt(x,y) then m={X=x,Y=y};found=true;break end
                end
            end
            if not found then self.lastInput="Attack input blocked by interface";return false,self.lastInput end
        end
        local ok,v=pcall(function()return game:GetService("VirtualInputManager")end)
        if ok and v then
            -- The owned WolfController callback above avoids UI hit testing.
            -- Fallback mouse input is reported as a request, never as damage.
            local sent=pulse("M1",function()v:SendMouseButtonEvent(m.X,m.Y,0,true,game,0)end,
                function()v:SendMouseButtonEvent(m.X,m.Y,0,false,game,0)end)
            if sent then
                self.lastAttackInput.sent=true;self.lastAttackInput.backend="VIRTUAL_MOUSE"
                self.lastInput="Virtual mouse attack requested";return true,self.lastInput
            end
            self.lastAttackInput.virtualError="VIRTUAL_MOUSE_REJECTED"
        end
        local moved=false
        local function positionCursor()
            if math.abs(m.X-original.X)+math.abs(m.Y-original.Y)>.5 then
                assert(type(mousemoveabs)=="function","Executor cursor positioning unavailable")
                mousemoveabs(m.X,m.Y);moved=true
            end
        end
        local function restoreCursor()
            if moved and type(mousemoveabs)=="function" then mousemoveabs(original.X,original.Y);moved=false end
        end
        local sent=false
        if type(mouse1press)=="function" and type(mouse1release)=="function" then
            sent=pulse("M1",function()positionCursor();mouse1press()end,function()
                pcall(mouse1release);restoreCursor()
            end)
        elseif type(mouse1click)=="function" then
            sent=pulse("M1",function()positionCursor();mouse1click()end,restoreCursor)
        end
        self.lastAttackInput.sent=sent;self.lastAttackInput.backend=sent and "EXECUTOR_MOUSE" or "UNAVAILABLE"
        self.lastInput=sent and "Executor mouse attack requested" or "Attack input unavailable or rejected"
        return sent,self.lastInput
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
-- Native Renaissance page. No companion ScreenGui, scheduler or visibility key.
local UI={}
function UI.new(engine,hub)
    local p={closed=false,engine=engine,hub=hub}
    local function amount(value)
        return type(value)=="number" and string.format("%.0f",value) or "?"
    end
    function p:mount(parent,H)
        local text,button,card=H.text,H.button,H.card
        local v={}
        local controls=card(0,48)
        local start=button(controls,"START FARMING",10,9,150,30)
        local skip=button(controls,"SKIP TARGET",169,9,150,30)
        local copy=button(controls,"COPY STATUS",328,9,150,30)
        start.Name="TerritoryStart";skip.Name="TerritorySkip";copy.Name="TerritoryCopy"
        start.Activated:Connect(function()if not p.closed then engine.setEnabled(not engine.agent.enabled)end end)
        skip.Activated:Connect(function()if not p.closed then engine.skip()end end)
        copy.Activated:Connect(function()if not p.closed then engine.copyStatus()end end)
        local stats=card(56,71)
        local totals=text(stats,"",12,8,465,22,12,H.palette.same)
        local needs=text(stats,"",12,34,465,23,12)
        local goal=card(135,103)
        local phase=text(goal,"",12,7,465,23,13,H.palette.same)
        local reason=text(goal,"",12,33,465,37,11,H.palette.sub);reason.TextWrapped=true
        local progress=text(goal,"",12,73,465,20,11)
        local movement=card(246,53)
        local gait=text(movement,"",12,5,465,22,12)
        local travel=text(movement,"",12,28,465,19,10,H.palette.sub)
        local recent=card(307,54)
        local last=text(recent,"",12,5,465,44,11,H.palette.sub);last.TextWrapped=true
        function v:tick(now)
            local s=engine.status();local n=s.navigation or {};local c=s.hexSummary or {}
            start.Text=s.enabled and "STOP FARMING" or "START FARMING"
            start.BackgroundColor3=s.enabled and H.palette.on or H.palette.off
            totals.Text=string.format("%d / %d owned · %d need scent · Amber +%.0f",c.owned or 0,c.eligible or 0,c.fading or 0,s.earned or 0)
            needs.Text="Hunger "..amount(s.hunger).." · Thirst "..amount(s.thirst).." · "..tostring(s.species or "Waiting for animal")
            phase.Text=(s.enabled and "RUNNING · " or "OFF · ")..tostring(s.phase)..(s.key and " · "..s.key or "")
            reason.Text=tostring(s.reason or "Ready")
            local target=s.targetProgress or {}
            local value=target.action=="SCENT" and target.hold or target.progress
            progress.Text=type(value)=="number" and ("Native territory progress "..amount(value*100).."%")
                or s.suspended and ("Will resume "..s.suspended) or "Watching native progress and resource changes"
            gait.Text=tostring(n.requested or "STOP").." requested · "..tostring(n.observed or "UNKNOWN").." observed"
            travel.Text="Travelled "..amount(n.travelled).." studs · Target "..amount(n.distance).." studs"
                ..(n.failure and (n.stalledFor or 0)>1 and " · "..n.failure or "")
            if s.strategy and s.strategy.area then
                progress.Text=s.strategy.area.." · "..tostring(s.strategy.owned or 0).."/"..tostring(s.strategy.total or 0).." owned"
                    ..(type(value)=="number" and (" · Native progress "..amount(value*100).."%") or "")
            end
            last.Text=s.lastNotice or s.lastSuccess or s.lastSkip or "Select START FARMING. Hiding the hub keeps farming active."
        end
        function v:close()end
        v:tick(os.clock());return v
    end
    p.registration=hub.ui:registerPage("Territory",p)
    function p:close()
        if self.closed then return end
        self.closed=true
        if self.registration then self.registration:close() end
    end
    return p
end
return UI
]============]
sources["runtime"] = [============[
-- Built-in Territory engine. Renaissance owns scheduling, UI and shutdown.
local Runtime={version="0.6.1"}
function Runtime.start(M,hub)
    assert(hub and hub.ui and type(hub.ui.registerPage)=="function","Update Renaissance for its built-in Territory page")
    local env=(type(getgenv)=="function" and getgenv()) or _G
    local prior=env.FERAL_AMBER_ACTIVE
    if prior and prior.version==Runtime.version and prior.ownerHub==hub and not prior.closed then return prior end
    if prior and type(prior.close)=="function" then pcall(prior.close) end
    local function module(name)return assert(M["amber_"..name] or M[name],"Missing territory module "..name)end
    local Nav,Bridge,Agent=module("nav"),module("bridge"),module("agent")
    local nav=Nav.new(game:GetService("PathfindingService"),game:GetService("Workspace"),module("gait"))
    local bridge=Bridge.new(nav);bridge.ownerHub=hub
    local agent=Agent.new(module("planner"),bridge,module("hunt"),module("care"))
    local driver=module("driver").new(bridge.player,nav,function()return bridge:manualInput()end)
    local h={version=Runtime.version,ownerHub=hub,agent=agent,bridge=bridge,nav=nav,driver=driver,closed=false,nextCounts=0}
    function h.setEnabled(on) if not h.closed then agent:setEnabled(on==true) end end
    function h.status()
        local now=os.clock();local st=agent:status()
        if now>=h.nextCounts then
            h.counts=bridge:counts(agent.lastState or {now=now});h.nextCounts=now+.8
        end
        st.hexSummary=h.counts;st.navigation=nav:status();st.gameVersion=game.PlaceVersion
        st.events={}
        for i=math.max(1,#agent.events-11),#agent.events do table.insert(st.events,agent.events[i]) end
        return st
    end
    function h.copyStatus()
        local ok,payload=pcall(function()return game:GetService("HttpService"):JSONEncode(h.status())end)
        if not ok then return false end
        if type(setclipboard)=="function" then pcall(setclipboard,payload) end
        print("[FERAL TERRITORY STATUS] "..payload);return true
    end
    function h.skip()
        if not agent.enabled then return end
        local s=agent.lastState
        if not s or not agent.goal or agent.goal.kind~="TERRITORY" then return end
        agent:fail(s,"Target skipped from Territory controls");agent.nextTick=0
    end
    h.panel=module("ui").new(h,hub)
    function h:tick(now)
        if self.closed then return end
        if hub.closed then self.close();return end
        local ok,why=pcall(function()
            if agent.enabled then driver:tick() end
            for _=1,3 do
                agent:tick(now)
                if not agent.enabled or agent.goal or agent.phase~="CONFIRMED" and agent.phase~="REPLAN" then break end
                agent.nextTick=now
            end
        end)
        if not ok then
            -- A failure in the normal stop path must not escape this boundary
            -- and interrupt the shared hub's remaining work for the frame.
            pcall(agent.setEnabled,agent,false)
            pcall(nav.stop,nav,nav.desiredHum,nav.desiredRoot,"TERRITORY_ERROR")
            pcall(nav.releaseKeys,nav);pcall(bridge.releaseInputs,bridge)
            agent.enabled=false;agent.goal=nil;agent.suspended=nil;agent.returns={};agent.phase="ERROR"
            agent.lastError=tostring(why):sub(1,180);agent.reason="Territory stopped after an input or data error"
        end
    end
    function h.close()
        if h.closed then return end
        h.closed=true
        pcall(agent.setEnabled,agent,false);pcall(driver.close,driver);pcall(bridge.close,bridge)
        nav.closed=true
        if h.panel then pcall(h.panel.close,h.panel) end
        if env.FERAL_AMBER_ACTIVE==h then env.FERAL_AMBER_ACTIVE=nil end
        if hub.territory==h then hub.territory=nil end
    end
    env.FERAL_AMBER_ACTIVE=h;hub.territory=h
    return h
end
return Runtime
]============]
-- The Territory engine is part of Renaissance; this versioned entry reuses it.
if game.PlaceId~=108901361810209 then return nil end
local env=(type(getgenv)=="function" and getgenv()) or _G
local hub=env.FERAL_RENAISSANCE_ACTIVE
if not hub or hub.closed or not hub.ui or type(hub.ui.registerPage)~="function" then
    warn("[FERAL TERRITORY] Run the current combined Amber/Renaissance launcher first.")
    return nil
end
if hub.territory and hub.territory.version=="0.6.1" and not hub.territory.closed then return hub.territory end
local M={}
for name,source in pairs(sources) do
    local fn,why=loadstring(source,"=FERAL_TERRITORY_"..name)
    assert(fn,why);M[name]=fn()
end
return M.runtime.start(M,hub)
