r 2)*2.5,8,18)
        local sides=self.detourSide or 1
        for _,angle in ipairs({sides*1.1,-sides*1.1,sides*1.8,-sides*1.8,math.pi}) do
            local x=base.X*math.cos(angle)-base.Z*math.sin(angle)
            local z=base.X*math.sin(angle)+base.Z*math.cos(angle)
            local point=self:surface(root.Position+Vector3.new(x*span,0,z*span),char,state.allowWater==true)
            local cell=point and (math.floor(point.X/10)..":"..math.floor(point.Z/10))
            if point and (not self.recoveryCells[cell] or now-self.recoveryCells[cell]>20)
                and self:clearSegment(root.Position,point,char,state.allowWater==true,true) then
                self.recoveryCells[cell]=now
                local count=0;for key,at in pairs(self.recoveryCells) do count+=1;if now-at>30 then self.recoveryCells[key]=nil end end
                if count>96 then self.recoveryCells={[cell]=now} end
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
    function n:mesh(from,target,root,hum,char,state)
        self.operations.paths+=1
        local ok,path=pcall(function()
            local p=self.service:CreatePath({AgentRadius=self.clearance or 3,
                AgentHeight=math.clamp(hum.HipHeight+root.Size.Y+1,4,30),
                AgentCanJump=false,AgentCanClimb=false,WaypointSpacing=12})
            p:ComputeAsync(from,target);return p
        end)
        if not ok or path.Status~=Enum.PathStatus.Success then return nil end
        local points={};local previous=from
        for _,waypoint in ipairs(path:GetWaypoints()) do
            local p=waypoint.Position
            if typeof(p)=="Vector3" and flat(p,from)>2 then
                local ground=self:surface(p,char,false)
                if not ground or not self:clearSegment(previous,ground,char,false) then return nil end
                table.insert(points,ground);previous=ground
            end
            if #points>160 then return nil end
        end
        return #points>0 and points or nil
    end
    function n:compute(from,root,hum,char,state,goal,attempt)
        local distance=flat(from,goal)
        if distance<.01 then return {},"EMPTY_ROUTE" end
        local delta=goal-from;local dir=Vector3.new(delta.X/distance,0,delta.Z/distance)
        local span=math.min(distance,100)
        local allowWater=state.allowWater==true
        local direct=self:surface(from+dir*span,char,allowWater)
        if direct then
            local clear,wet=self:clearSegment(from,direct,char,allowWater)
            if clear then return {direct},(wet or state.swimming) and "SWIM_ROUTE" or "CLEAR_SURFACE" end
        end
        if not state.movingTarget and not state.swimming then
            local full=self:surface(goal,char,false)
            if full and distance<=900 then
                if self.model then
                    local cached=self.model:path(p2(from),p2(full),state.now or self.lastAt or 0)
                    if cached then
                        local result={};local previous=from;local valid=true
                        for _,p in ipairs(cached) do
                            local v=Vector3.new(p.x,p.y or full.Y,p.z)
                            if not self:clearSegment(previous,v,char,false) then valid=false;break end
                            table.insert(result,v);previous=v
                        end
                        if valid then return result,"CHECKED_PASSAGE" end
                    end
                end
                local fullPath=self:mesh(from,full,root,hum,char,state)
                if fullPath then return fullPath,"PATH_SURFACE_FULL" end
            end
        end
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
                    local points=self:mesh(from,surface,root,hum,char,state)
                    if points then return points,"PATH_SURFACE" end
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
        -- ComputeAsync may yield through an animal/goal replacement. Isolate
        -- every cache and collision side effect before the adoption lease is
        -- checked, rather than merely rejecting the eventual waypoint list.
        local worker=table.clone(self)
        worker.operations={rays=0,surfaces=0,paths=0};worker.surfaceCache={}
        worker.overlapAt=nil;worker.overlapParts=nil
        task.spawn(function()
            local started=os.clock()
            local ok,points,reason=pcall(worker.compute,worker,request.origin,root,hum,char,
                table.clone(state or {}),request.goal,self.replans)
            self.pathWall=(self.pathWall or 0)+math.max(0,os.clock()-started)
            self.activeJobs-=1
            for name,count in pairs(worker.operations) do self.operations[name]=(self.operations[name] or 0)+count end
            if self.closed or self.epoch~=epoch or self.pending~=request then return end
            self.pending=nil
            self.lastSafety=worker.lastSafety;self.lastObstacle=worker.lastObstacle
            if not ok or not points then
                self.routeFailures+=1;self.failures+=1
                self.lastFailure=ok and reason or "PATH_COMPUTATION_ERROR"
                self.lastReason=self.lastFailure;self.nextRouteAt=now+1.5
                return
            end
            -- An old path cannot pull a moving animal back toward its old start.
            if not root.Parent or self.body~=char then return end
            -- Rebase a late same-goal path at the closest checked forward join.
            local bestIndex,best=1,math.huge
            for index,p in ipairs(points) do
                local previous=points[index-1] or request.origin
                local delta=p-previous;local len=delta:Dot(delta)
                local t=len>.01 and math.clamp((root.Position-previous):Dot(delta)/len,0,1) or 0
                local projection=previous+delta*t;local d=flat(root.Position,projection)
                if d<best and self:clearSegment(root.Position,p,char,state.allowWater==true,true) then bestIndex,best=index,d end
            end
            if flat(root.Position,request.origin)>30 and best>math.max(15,self.clearance*3) then
                self.lastFailure="OBSOLETE_PATH_ORIGIN";self.nextRouteAt=self.lastAt or now;return
            end
            self.points,self.index=points,bestIndex;self.routeOrigin=request.origin
            self:advance(root,math.clamp(root.Size.X*.5+4,6,12))
            if self.model then
                local observed={{x=request.origin.X,y=request.origin.Y,z=request.origin.Z}}
                for _,p in ipairs(points) do table.insert(observed,{x=p.X,y=p.Y,z=p.Z}) end
                self.model:addRoute(observed,self.lastAt or now)
            end
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
        state=state or {};self.lastState=state;self.lastAt=now;self.surfaceCache={}
        if self.closed or not destination or not char or not hum or not root or hum.Health<=0 then
            self:stop(hum,root,"NO_LIVING_ANIMAL");return "WAIT"
        end
        if state.flying or state.climbing or state.underwater then
            self:stop(hum,root,"UNSUPPORTED_NATIVE_ROUTE_MODE");return "BLOCKED"
        end
        local identity=state.navKey or "STATIC"
        local replacedRoot=self.bodyRoot and self.bodyRoot~=root
        local replacedGeneration=self.characterGeneration~=nil and self.characterGeneration~=state.generation
        self.bodyRoot=root
        self.clearance=math.clamp(root.Size.X*.5+.65,2,12)
        self.bodyHeight=math.clamp(root.Size.Y*.8,1,10)
        self.bodyLength=math.clamp(root.Size.Z*.65,2,18)
        self.supportHeight=math.max(2,hum.HipHeight+root.Size.Y*.5)
        self.maxDrop=math.clamp(hum.HipHeight*.75,2,4)
        self.maxStepUp=math.clamp(hum.HipHeight,2,4)
        self.minGroundNormal=math.cos(math.rad(math.clamp(hum.MaxSlopeAngle or 55,20,55)))
        if not self.destination or self.body~=char or self.identity~=identity or replacedRoot or replacedGeneration then
            if replacedRoot or replacedGeneration then
                self.gaits:stop(nil,now);self:releaseKeys()
            end
            self:reset(destination,char,now,identity)
        end
        self.characterGeneration=state.generation
        local targetShift=flat(destination,self.destination)
        self.destination=destination
        self.arrivalRadius=state.moveRadius or 8
        self.inputScale=state.moveScale and math.clamp(state.moveScale,.15,1) or 1
        local total=flat(root.Position,destination);self.distance=total
        self.costPoint=state.costPoint;self.costPurpose=state.costPurpose
        self.goalOrigin=self.goalOrigin or root.Position
        self.bestGoalDistance=math.min(self.bestGoalDistance or total,total)
        if total<=self.arrivalRadius then
            if self.model and not self.costRecorded then
                self.model:record(p2(self.goalOrigin),self.costPoint or p2(destination),math.max(.1,now-self.goalStarted),now,false,self.costPurpose,self.costPurpose~=nil)
                self.costRecorded=true
            end
            self:stop(hum,root,"ARRIVED");return "REACHED"
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
        if now>=(self.nextTrajectoryAt or 0) then
            self.nextTrajectoryAt=now+1
            for _,sample in ipairs(self.trajectory) do
                if now-sample.at>8 and flat(root.Position,sample.position)<8
                    and self.routeTravel-sample.travel>70 and total>=sample.distance-5 then
                    oscillating=true;self.lastFailure="RECURRENT_ROUTE";self.lastProgressAt=now-6;break
                end
            end
            table.insert(self.trajectory,{at=now,position=root.Position,travel=self.routeTravel,distance=total})
            while #self.trajectory>40 do table.remove(self.trajectory,1) end
        end
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
            self.lastFailure=(self.lastFailure=="OSCILLATION" or self.lastFailure=="RECURRENT_ROUTE") and self.lastFailure or "NO_PHYSICAL_PROGRESS"
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
        local reach=math.min(aheadFlat,math.max(8,self.speed*.75+self.bodyLength*.5))
        if aheadFlat>.1 then
            local probe=root.Position+Vector3.new(ahead.X/aheadFlat*reach,0,ahead.Z/aheadFlat*reach)
            local safe=self:clearSegment(root.Position,probe,char,state.allowWater==true,true)
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
        self.lastTurn=turn;self.localRange=localRange
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
            corrections=self.corrections,segments=self.segmentCount,obstacleRecoveries=self.obstacleRecoveries or 0,
            operations=self.operations,pathJobWallSeconds=self.pathWall,activeJobs=self.activeJobs or 0,knowledge=self.model and self.model:summary()}
    end
    return n
end
return Nav
]============]
sources["amber_hunt"] = [============[
-- Moving NPC pursuit. Inputs and observed HP changes are separate outcomes.
local Hunt={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e8 end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
function Hunt.new(adapter)
    local h={adapter=adapter,target=nil,pending=nil,hits=0,misses=0,attacks=0,
        lastResult="No attack",nextAttack=0,blocked=setmetatable({},{__mode="k"}),kills=0}
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
        if self.actorSeen and (self.actor~=s.char or self.generation~=s.generation) then
            self.target,self.pending,self.sample=nil,nil,nil
            self.nextAttack=0;self.nextSelect=nil;self.lastTargetHealth=nil;self.lastTargetMax=nil
            self.blocked=setmetatable({},{__mode="k"})
            self.adapter:stop("Hunt animal generation changed")
        end
        self.actorSeen=true;self.actor=s.char;self.generation=s.generation
        for model,untilAt in pairs(self.blocked) do if now>=untilAt then self.blocked[model]=nil end end
        if self.adapter.attackEvidence then self.inputEvidence=self.adapter:attackEvidence(s) end
        local prey=self.target
        -- A recycled model/Humanoid cannot contribute a death or HP result to
        -- the old prey transaction, even if its last Health happened to be zero.
        if prey and prey.hum and prey.model and type(prey.model.FindFirstChildOfClass)=="function"
            and prey.model:FindFirstChildOfClass("Humanoid")~=prey.hum then
            self.target,self.pending=nil,nil;prey=nil
            self.lastResult="Prey identity changed; resampling native target"
        end
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
            self.lastTargetMax=prey.maxHealth or prey.hum and prey.hum.MaxHealth
            self.lastTargetHum=prey.hum
            self.lastUsefulAt=now;self.blockedSince=nil;self.nextAttack=now
            self.repositionUntil=nil;self.previousThrottle=nil;self.fullSpeed=nil;self.routeRetries=0;self.smoothVelocity=nil
        end
        self.target=prey
        local health=prey.health or prey.hum and prey.hum.Health
        local maximum=prey.maxHealth or prey.hum and prey.hum.MaxHealth
        local continuous=self.lastTargetHum==prey.hum
            and not (finite(maximum) and finite(self.lastTargetMax) and math.abs(maximum-self.lastTargetMax)>.001)
        if not continuous then
            self.pending=nil;self.lastTargetHealth=health;self.missesOnTarget=0
            self.noDamageAt=now;self.lastUsefulAt=now
            self.lastResult="Prey health identity/maximum changed; outcome window reset"
        end
        self.lastTargetHum=prey.hum;self.lastTargetMax=maximum
        if continuous and finite(health) and finite(self.lastTargetHealth) and health<self.lastTargetHealth-.01 then
            if self.adapter.huntOutcome then self.adapter:huntOutcome(self.lastTargetHealth-health) end
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
            elseif now-p.at>(s.attackCooldown and math.clamp(s.attackCooldown*.75+(s.progressLatency or .5)+.5,1.1,3) or 1.1) then
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
        if self.smoothVelocity then
            velocity={x=self.smoothVelocity.x*.55+velocity.x*.45,z=self.smoothVelocity.z*.55+velocity.z*.45}
            speed=math.sqrt(velocity.x^2+velocity.z^2)
        end
        self.smoothVelocity=velocity
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
                self.attacks+=1;self.pending={at=now,health=health,maxHealth=maximum,hum=prey.hum,model=prey.model}
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
        self.pending=nil;self.sample=nil;self.nextAttack=0;self.lastTargetHealth=nil
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
sources["amber_care"] = [============[
-- Feeding handshake and recovery. Native approach, active feeding and an input
-- request have distinct lifetimes; manual cancellation never leaves a stale latch.
local Care={}
local function finite(n)return type(n)=="number" and n==n and math.abs(n)<1e10 end
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
    if not finite(value) or not finite(g.baseline) then return "FAILED","Native needs unavailable" end
    local maximum=kind=="drink" and (s.thirstMax or 100) or (s.hungerMax or 100)
    if not finite(maximum) or maximum<=0 then return "FAILED","Native need maximum unavailable" end
    if value<0 or value>maximum*1.05 then return "FAILED","Native need value outside its maximum" end
    if g.needMaximum and g.needMaximum~=maximum then
        -- A schema/species maximum change is not nutrition gained. Establish a
        -- new same-maximum window and keep watching the actual native session.
        g.baseline=value;m.value=value;m.progressAt=now
    end
    g.needMaximum=maximum
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
    local target=kind=="drink" and math.min(s.drinkTarget or maximum,maximum)-maximum*.002 or math.min(s.careTarget or maximum*.72,maximum)
    if not finite(target) or target<=0 then return "FAILED","Native care target unavailable" end
    if value>=target and g.gain>math.min(.25,maximum*.002) then
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
sources["amber_agent"] = [============[
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
]============]
sources["amber_bridge"] = [============[
-- Native FERAL data boundary; shared logic does not imply every mode is supported.
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
        configs={},configInstances={},configRevision=0,manualButtons={},waterBlocked={},preyBlocked=setmetatable({},{__mode="k"}),foodBlocked=setmetatable({},{__mode="k"}),
        connections={},inputEpoch=0,territorySamples={},operations={surface=0,food=0,prey=0},synthetic={},generation=0,
        coverage={},coverageOrder={},nativeCosts={}}
    local world=Rep:FindFirstChild("FeralWorld")
    local function config(name)
        local module=world and world:FindFirstChild(name)
        local previous=b.configInstances[name]
        if b.configs[name] and previous==module then return b.configs[name] end
        if previous~=module then b.configRevision+=1 end
        b.configs[name]=nil;b.configInstances[name]=module
        if not module or not module:IsA("ModuleScript") then return nil end
        local ok,value=pcall(require,module)
        if ok and type(value)=="table" then b.configs[name]=value;return value end
        return nil
    end
    b.config=config
    local function measured(name,fn,...)
        local started=os.clock();local result=table.pack(pcall(fn,...))
        local elapsed=math.max(0,os.clock()-started)
        local cost=b.nativeCosts[name] or {calls=0,total=0,max=0};b.nativeCosts[name]=cost
        cost.calls+=1;cost.total+=elapsed;cost.max=math.max(cost.max,elapsed)
        return table.unpack(result,1,result.n)
    end
    function b:hub()
        local h=self.ownerHub or (type(getgenv)=="function" and getgenv() or _G).FERAL_RENAISSANCE_ACTIVE
        return type(h)=="table" and not h.closed and h.bridge and h.bridge.player==player and h or nil
    end
    function b:recover(state,on)
        local h=self:hub()
        if not h then return false end
        if on then h.territoryRecoveryOwner=self
        elseif h.territoryRecoveryOwner==self then
            h.territoryRecoveryOwner=nil
            if h.recovery and not h.registry.byId.recovery.requested then h.recovery:release("Territory recovery ended",state and state.now or os.clock()) end
        end
        return on and h.recovery~=nil
    end
    function b:resetDiscovery(identity)
        local same=self.identity~=nil
        for _,key in ipairs({"char","root","profile","pack","biome","territory","world","configRevision"}) do if not self.identity or self.identity[key]~=identity[key] then same=false;break end end
        if same then return end
        self.identity=identity;self.generation+=1
        local char=player.Character
        self.nav:stop(char and char:FindFirstChildOfClass("Humanoid"),char and char:FindFirstChild("HumanoidRootPart"),"GENERATION_CHANGED")
        self.spotCache,self.spotTry,self.territorySamples={},{},{}
        self.waterBlocked={};self.preyBlocked=setmetatable({},{__mode="k"});self.foodBlocked=setmetatable({},{__mode="k"})
        for _,name in ipairs({"waterCache","waterScan","waterMissUntil","waterAt","searchPoint","searchVisits","searchUntil",
            "patrolTarget","patrolVisits","patrolUntil","foodIndex","preyIndex","foodBest","preyBest","lastAttackInput","attackCharacter","foodETA","drinkETA","foodObserved","drinkObserved","observedDamage","nextBite"}) do self[name]=nil end
        self.nav.recoveryCells={};self.nav.trajectory={};self.nav.surfaceCache={}
        self:releaseInputs();self:recover(nil,false)
        if self.nav.model then self.nav.model:reset(identity) end
    end
    function b:prepare(now,enabled,goal)
        local h=self:hub()
        if not enabled or not h then return end
        if h.walk and type(h.stopWalk)=="function" then h:stopWalk("Amber movement owner") end
        h.nextWalk=now+90
        -- Coordinate with existing recovery instead of letting it start Rest
        -- during travel, feeding approach or hunt preparation.
        local recovering=goal and goal.kind=="RECOVER"
        self:recover({now=now},recovering==true)
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
        local currentWorld=Rep:FindFirstChild("FeralWorld")
        if currentWorld~=world then world=currentWorld;self.configs={};self.configInstances={};self.configRevision+=1;self.cfg=nil;self.spots=nil;self.lastString=nil;self.hexes={};self.hexByKey={} end
        if self.configInstances.TerritoryConfig or world and world:FindFirstChild("TerritoryConfig") then
            local latest=config("TerritoryConfig")
            if latest~=self.cfg then self.cfg=latest;self.lastString=nil;self.hexes={};self.hexByKey={} end
        end
        if self.configInstances.MapSpots or world and world:FindFirstChild("MapSpots") then self.spots=config("MapSpots") end
        local currentTerritory=Rep:FindFirstChild("FeralTerritory")
        if currentTerritory~=self.territoryInstance then self.territoryInstance=currentTerritory;self.lastString=nil;self.hexes={};self.hexByKey={} end
        if not self.cfg or not self.territoryInstance then
            world=Rep:FindFirstChild("FeralWorld")
            self.cfg=config("TerritoryConfig")
            self.spots=config("MapSpots")
            self.territoryInstance=Rep:FindFirstChild("FeralTerritory")
            if not self.cfg or not self.territoryInstance then return end
        end
        self.spots=self.spots or config("MapSpots")
        local previous=self.territoryContract
        local changed=not previous
        for _,key in ipairs({"parseHexes","hexCenter","hexAt","hexKey","CLAIM_RADIUS","CLAIM_TIME","REFILL_TIME"}) do
            if not previous or previous[key]~=self.cfg[key] then changed=true;break end
        end
        if changed then
            self.territoryContract={}
            for _,key in ipairs({"parseHexes","hexCenter","hexAt","hexKey","CLAIM_RADIUS","CLAIM_TIME","REFILL_TIME"}) do self.territoryContract[key]=self.cfg[key] end
            self.lastString=nil;self.hexes={};self.hexByKey={};self.spotCache={};self.territorySamples={}
            self.configRevision+=1
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
        local landmarks=self.spots and self.spots[biome]
        if type(landmar