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
            path=self.service:CreatePath({AgentRadius=5,AgentHeight=10,AgentCanJump=false,
                AgentCanClimb=false,WaypointSpacing=14})
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
