-- Surface-only FERAL animal navigation. Separate steering and native gait.
-- No position writes, teleports, CFrame turns, server remotes or velocity edits.
local Nav={}
local function flat(a,b)
    local x,z=a.X-b.X,a.Z-b.Z
    return math.sqrt(x*x+z*z)
end
local function xyz(v) return {x=v.X,z=v.Z} end
local function groundAt(workspace,pos,char)
    local ray=RaycastParams.new()
    ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={char}
    ray.IgnoreWater=false
    local result=workspace:Raycast(
        Vector3.new(pos.X,math.max(90,pos.Y+95),pos.Z),
        Vector3.new(0,-420,0),ray)
    if result and result.Material~=Enum.Material.Water and result.Normal.Y>=.46 then
        return result.Position+Vector3.new(0,2.5,0)
    end
    return nil
end
function Nav.new(pathService,workspace,Gait)
    local n={service=pathService,workspace=workspace,math=Gait,
        destination=nil,body=nil,points={},index=1,
        desiredPoint=nil,desiredRoot=nil,desiredHum=nil,
        held={},nativeInput="UNTESTED",lastReason="IDLE",gait="STOP",
        routeAt=0,lastAt=0,issued=0,failures=0,replans=0,
        progressAt=0,progressDistance=nil,previousPosition=nil,
        lastHeading=nil,lastGaitAt=0,lastBurstAt=-100,lastTrotAt=-100,
        fallbackUntil=0,lastMode="WORLD",burstObserved=false}
    local bindings={W=Enum.KeyCode.W,A=Enum.KeyCode.A,
        S=Enum.KeyCode.S,D=Enum.KeyCode.D,
        SHIFT=Enum.KeyCode.LeftShift,X=Enum.KeyCode.X,Z=Enum.KeyCode.Z}
    local vkeys={W=0x57,A=0x41,S=0x53,D=0x44,SHIFT=0xA0,X=0x58,Z=0x5A}
    local function key(name,on)
        local code=bindings[name]
        if not code then return false end
        local ok,input=pcall(function()return game:GetService("VirtualInputManager")end)
        if ok and input then
            local fired=pcall(input.SendKeyEvent,input,on,code,false,game)
            if fired then return true,"VirtualInputManager" end
        end
        local action=on and keypress or keyrelease
        if type(action)=="function" then
            local fired=pcall(action,vkeys[name])
            if fired then return true,"ExecutorKey" end
        end
        return false,"Unavailable"
    end
    function n:hold(name,on)
        local previous=self.held[name]==true
        if previous==on then return previous end
        if on then
            local ok,via=key(name,true)
            if ok then self.held[name]=true;self.nativeInput=via end
            return ok
        end
        if previous then
            key(name,false)
            self.held[name]=nil
        end
        return true
    end
    function n:tap(name)
        if not self:hold(name,true) then return false end
        local owner=self
        task.delay(.09,function()
            -- A tap's release must not be held across stop/unload; release is
            -- idempotent even if the controller was closed during the delay.
            owner:hold(name,false)
        end)
        return true
    end
    function n:releaseSteering()
        for _,name in ipairs({"W","A","S","D"}) do self:hold(name,false) end
    end
    function n:releaseKeys()
        for name in pairs(self.held) do self:hold(name,false) end
        self.gait="STOP"
    end
    function n:stop(hum,root,reason)
        local wasNavigating=self.destination~=nil or self.desiredPoint~=nil
        self.desiredPoint,self.desiredRoot,self.desiredHum=nil,nil,nil
        self:releaseKeys()
        if wasNavigating and hum and root then
            pcall(function() hum:Move(Vector3.zero,false) end)
            pcall(function() hum:MoveTo(root.Position) end)
        end
        self.destination,self.body=nil,nil
        self.points,self.index={},1
        self.progressDistance=nil
        self.lastReason=reason or "IDLE"
    end
    function n:reset(destination,char,now)
        self.destination,self.body=destination,char
        self.points,self.index={},1
        self:releaseSteering()
        self:hold("SHIFT",false)
        self.desiredPoint,self.desiredRoot,self.desiredHum=nil,nil,nil
        self.routeAt=0;self.issued=0
        self.progressAt=now;self.progressDistance=nil
        self.lastReason="NEW_ROUTE"
        self.previousPosition=nil;self.lastHeading=nil
        self.fallbackUntil=0;self.lastMode="WORLD"
    end
    function n:route(root,hum,char,now)
        local from=root.Position
        local delta=self.destination-from
        local distance=flat(from,self.destination)
        if distance<9 then self.points={};return true end
        -- Limit pathfinding to the streamed neighborhood; avoid directing an
        -- animal into an unstreamed faraway waterfall or cliff.
        local span=math.min(distance,75)
        local direction=Vector3.new(delta.X/distance,0,delta.Z/distance)
        local probes={Vector3.new(from.X+direction.X*span,from.Y,from.Z+direction.Z*span)}
        for _,ang in ipairs({-math.pi/7,math.pi/7,-math.pi/3,math.pi/3}) do
            local x=direction.X*math.cos(ang)-direction.Z*math.sin(ang)
            local z=direction.X*math.sin(ang)+direction.Z*math.cos(ang)
            table.insert(probes,Vector3.new(from.X+x*math.min(span,45),from.Y,
                from.Z+z*math.min(span,45)))
        end
        local surface=nil
        for _,probe in ipairs(probes) do
            surface=groundAt(self.workspace,probe,char)
            if surface then break end
        end
        if not surface then
            self.lastReason="NO_STREAMED_GROUND"
            return false
        end
        local route,success=false,false
        local ok=pcall(function()
            local radius=math.clamp(math.max(root.Size.X,root.Size.Z)*.5+1.25,2,12)
            local height=math.clamp(hum.HipHeight+root.Size.Y+1.5,4,30)
            route=self.service:CreatePath({AgentRadius=radius,AgentHeight=height,
                AgentCanJump=false,AgentCanClimb=false,WaypointSpacing=12})
            route:ComputeAsync(from,surface)
            success=route.Status==Enum.PathStatus.Success
        end)
        local points={}
        if ok and success then
            for _,p in ipairs(route:GetWaypoints()) do
                if typeof(p.Position)=="Vector3" then table.insert(points,p.Position) end
            end
        end
        if #points<2 then
            -- Only make a short direct ground step when the ray has no physical
            -- obstacles. Missing/unloaded obstacles must not become a blind TP.
            local params=RaycastParams.new()
            params.FilterType=Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances={char}
            local hit=self.workspace:Raycast(from+Vector3.new(0,3,0),
                surface-from,params)
            if hit and hit.Instance and hit.Instance~=self.workspace.Terrain
                and not hit.Instance:IsDescendantOf(char) then
                self.lastReason="BLOCKED_SURFACE"
                return false
            end
            points={surface}
        end
        self.points,self.index=points,1
        self.routeOrigin=from
        self.routeAt=now
        self.progressAt=now
        self.progressDistance=distance
        self.lastReason=success and "PATH_SURFACE" or "SHORT_SURFACE"
        return true
    end
    function n:setGait(wanted,state,now)
        local current=self.gait
        if wanted~=current then
            self.gait=wanted
            self.lastGaitAt=now
        end
        -- Sprint uses the actual FERAL LeftShift input. Never use RightShift,
        -- because it owns both hub menus.
        local faster=wanted=="SPRINT" or wanted=="BURST"
        self:hold("SHIFT",faster)
        if wanted=="TROT" and not (state and state.hudTrot==true)
            and now-self.lastTrotAt>9 then
            if self:tap("Z") then self.lastTrotAt=now end
        end
        if wanted=="BURST" then
            local observed=state and state.hudBurst==true
            if not observed and now-self.lastBurstAt>8 then
                if self:tap("X") then self.lastBurstAt=now end
            end
        end
    end
    function n:drive()
        local root,hum,p=self.desiredRoot,self.desiredHum,self.desiredPoint
        if not root or not hum or not p or not root.Parent or hum.Health<=0 then
            self:releaseKeys()
            return
        end
        local delta=Vector3.new(p.X-root.Position.X,0,p.Z-root.Position.Z)
        if delta.Magnitude<6 then
            self:releaseSteering()
            pcall(function()hum:Move(Vector3.zero,false)end)
            return
        end
        -- One authoritative steering stream. Never combine continuous WASD
        -- with camera-relative world-space humanoid steering (orbit bug).
        if os.clock()>=self.fallbackUntil then
            self:releaseSteering()
            local direction=delta.Unit
            pcall(function()hum:Move(direction,false)end)
            self.lastMode="WORLD"
            return
        end
        -- An optional short-lived fallback when world-space movement was
        -- demonstrably stationary. One camera-relative key at a time.
        local cam=self.workspace.CurrentCamera
        if not cam then return end
        local look=cam.CFrame.LookVector
        local right=cam.CFrame.RightVector
        local f=Vector3.new(look.X,0,look.Z)
        local r=Vector3.new(right.X,0,right.Z)
        if f.Magnitude<.1 or r.Magnitude<.1 then return end
        local fd=delta.Unit:Dot(f.Unit)
        local rd=delta.Unit:Dot(r.Unit)
        local which=math.abs(fd)>=math.abs(rd)
            and (fd>=0 and "W" or "S")
            or (rd>=0 and "D" or "A")
        for _,name in ipairs({"W","A","S","D"}) do
            self:hold(name,name==which)
        end
        self.lastMode="KEY_FALLBACK"
    end
    function n:tick(destination,char,hum,root,now,otherPlayers,state)
        if not destination or not char or not hum or not root or hum.Health<=0 then
            self:stop(hum,root,"NO_LIVING_ANIMAL");return "WAIT"
        end
        if not self.destination or flat(destination,self.destination)>9 or self.body~=char then
            self:reset(destination,char,now)
        end
        local total=flat(root.Position,destination)
        if total<9 then self:stop(hum,root,"ARRIVED");return "REACHED" end
        for _,pos in ipairs(otherPlayers or {}) do
            if typeof(pos)=="Vector3" and flat(pos,root.Position)<115 then
                self:stop(hum,root,"PLAYER_NEARBY");return "BLOCKED"
            end
        end
        if #self.points==0 or self.index>#self.points then
            if not self:route(root,hum,char,now) then
                self.failures+=1
                if self.failures>3 then return "STUCK" end
                return "WAIT"
            end
        end
        local currentPosition=xyz(root.Position)
        local waypointRange=math.clamp(math.max(root.Size.X,root.Size.Z)*.6+5,8,14)
        local check={}
        for _,p in ipairs(self.points) do table.insert(check,xyz(p)) end
        local newIndex=self.math.waypointIndex(check,self.index,currentPosition,waypointRange)
        -- High-speed animals can overshoot a short path waypoint between
        -- samples. Never turn them around to chase a point behind them:
        -- advance when the animal has passed the waypoint along the segment.
        while newIndex<=#self.points do
            local p=self.points[newIndex]
            local prev=self.points[newIndex-1] or self.routeOrigin
            if not prev then break end
            local sx,sz=p.X-prev.X,p.Z-prev.Z
            local length=math.sqrt(sx*sx+sz*sz)
            if length<=2 then newIndex+=1 else
                local beyond=((root.Position.X-p.X)*sx
                    +(root.Position.Z-p.Z)*sz)/length
                if beyond>waypointRange*.5 then newIndex+=1 else break end
            end
        end
        self.index=newIndex
        if self.index>#self.points then
            -- Do not leave a stale waypoint steering the animal backwards.
            self.points={}
            self.desiredPoint=nil
            self:releaseSteering()
            pcall(function()hum:Move(Vector3.zero,false)end)
            self.lastReason="SEGMENT_COMPLETE"
            return "MOVING"
        end
        local waypoint=self.points[self.index]
        if self.progressDistance and now-self.progressAt>=5.5 then
            local progress=self.math.progress(now,self.progressAt,self.progressDistance,total,5.5,3.5)
            if progress=="STALLED" then
                self.replans+=1
                self.lastReason="STALL_REPLAN"
                self:releaseSteering()
                self.fallbackUntil=now+math.min(2.5,1+self.replans*.3)
                self.progressAt=now
                self.progressDistance=total
                self.points={}
                if self.replans>=4 then return "STUCK" end
                return "WAIT"
            end
            self.progressAt=now
            self.progressDistance=total
            self.fallbackUntil=0
        end
        -- Acceleration choice is based on full distance to the claimed hex
        -- and the latest heading, not each small intermediate waypoint.
        local turn=self.math.turn(self.previousPosition,currentPosition,xyz(destination))
        if not self.lastHeading or self.math.distance(self.lastHeading,currentPosition)>7 then
            self.previousPosition=self.lastHeading
            self.lastHeading=currentPosition
        end
        local reserve=state and state.staminaFraction or nil
        -- Burst only on a nearly straight, sufficiently long LOCAL segment,
        -- not simply because the distant territory is far away.
        if flat(root.Position,waypoint)<34 then turn=math.max(turn,42) end
        local wanted=self.math.select(total,turn,reserve,{
            allowBurst=state and state.allowBurst~=false,
            burstReady=not (state and state.hudBurstNo),
            combat=state and state.combat,
            ability=state and state.ability,
        })
        self:setGait(wanted,state,now)
        self.desiredPoint,self.desiredRoot,self.desiredHum=waypoint,root,hum
        if now-self.issued>=1.5 then
            self.issued=now
            pcall(function()hum:MoveTo(waypoint)end)
        end
        self.lastReason="FOLLOWING_"..wanted.."_"..self.lastMode
        return "MOVING"
    end
    return n
end
return Nav
