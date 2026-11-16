-- Small engine substitute for lifecycle/fault tests, not engine compatibility evidence.
local M = {now = 0, nodes = {}, warnings = {}, pending = {}, writes = {},
    requireCalls = 0, moves = 0, streams = 0, water = false, obstruction = false,
    floor = true, modules = {}, healthWrites = 0, attributeWrites = 0}
os = {clock = function() return M.now end, time = function() return 1800000000 + M.now end}
function warn(message) M.warnings[#M.warnings + 1] = message end
local function signal()
    local s = {listeners = {}}
    function s:Connect(fn)
        local c = {Connected = true, fn = fn}
        function c:Disconnect() self.Connected = false end
        self.listeners[#self.listeners + 1] = c
        return c
    end
    function s:Fire(...)
        local copy = table.clone(self.listeners)
        for _, c in ipairs(copy) do if c.Connected then c.fn(...) end end
    end
    return s
end
task = {
    spawn = function(fn) M.pending[#M.pending + 1] = {fn = fn, at = M.now} end,
    delay = function(seconds, fn) M.pending[#M.pending + 1] = {fn = fn, at = M.now + seconds} end,
    wait = function() end,
}
function M.flush()
    local again = true
    while again do
        again = false
        for i = #M.pending, 1, -1 do
            if M.pending[i].at <= M.now then
                local job = table.remove(M.pending, i)
                job.fn(); again = true
            end
        end
    end
end
local vectorMethods, vectorMeta = {}, {}
function vectorMeta.__index(v, key)
    if key == "Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    if key == "Unit" then local n = v.Magnitude; return n > 0 and v/n or v end
    return vectorMethods[key]
end
local function vec(x, y, z) return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, vectorMeta) end
function vectorMeta.__add(a, b) return vec(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
function vectorMeta.__sub(a, b) return vec(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
function vectorMeta.__mul(a, b)
    if type(a) == "number" then return vec(a*b.X, a*b.Y, a*b.Z) end
    return vec(a.X*b, a.Y*b, a.Z*b)
end
function vectorMeta.__div(a, b) return vec(a.X/b, a.Y/b, a.Z/b) end
Vector3 = {new = vec, zero = vec()}
Vector2 = {new = function(x,y) return vec(x,y,0) end}
Color3 = {new = vec, fromRGB = vec}
local cfMeta, cfMethods = {}, {}
local function cf(x,y,z)
    if type(x) == "table" then return setmetatable({Position=x, LookVector=vec(0,0,-1)}, cfMeta) end
    return setmetatable({Position=vec(x,y,z), LookVector=vec(0,0,-1)}, cfMeta)
end
function cfMeta.__index(v,k) if k == "Rotation" then return cf() end; return cfMethods[k] end
function cfMeta.__mul(a,b) return cf(a.Position+b.Position) end
function cfMethods:ToObjectSpace(other) return cf(other.Position-self.Position) end
function cfMethods:PointToWorldSpace(point) return self.Position+point end
CFrame = {new=cf, lookAt=function(position, target)
    local result=cf(position); result.LookVector=(target-position).Unit; return result
end}
UDim = {new=function(scale, offset) return {Scale=scale, Offset=offset} end}
UDim2 = {new=function(xs,xo,ys,yo) return {X=UDim.new(xs or 0,xo or 0),Y=UDim.new(ys or 0,yo or 0)} end}
UDim2.fromOffset=function(x,y) return UDim2.new(0,x,0,y) end
UDim2.fromScale=function(x,y) return UDim2.new(x,0,y,0) end
Enum = setmetatable({}, {__index=function(t,k)
    local result=setmetatable({}, {__index=function(s,n) rawset(s,n,k.."."..n); return rawget(s,n) end})
    rawset(t,k,result); return result
end})
RaycastParams={new=function() return {} end}
OverlapParams={new=function() return {} end}
local methods, nodeMeta = {}, {}
local function isA(node, class)
    local own=node._props.ClassName
    if class == own or class == "Instance" then return true end
    if class == "BasePart" then return own=="Part" or own=="MeshPart" end
    if class == "LuaSourceContainer" then return own=="Script" or own=="LocalScript" or own=="ModuleScript" end
    return false
end
function nodeMeta.__index(node,key)
    if methods[key] then return methods[key] end
    local value=node._props[key]
    if value~=nil then return value end
    for _,child in ipairs(node._children) do if child.Name==key then return child end end
    return nil
end
function nodeMeta.__newindex(node,key,value)
    if key == "Parent" then
        local old=node._props.Parent
        if old then
            for i,child in ipairs(old._children) do if child==node then table.remove(old._children,i); break end end
        end
        if value then value._children[#value._children+1]=node end
    elseif key == "Character" and node._props.Character ~= value then
        if node._props.Character then node.CharacterRemoving:Fire(node._props.Character) end
    elseif key == "Health" and node._props.ClassName=="Humanoid" then
        M.healthWrites=M.healthWrites+1
    end
    node._props[key]=value
    if node._signals[key] then node._signals[key]:Fire() end
end
Instance = {}
function Instance.new(class)
    local node=setmetatable({_props={ClassName=class,Name=class,Size=vec(4,5,8),CFrame=cf(),
        Position=vec(),AssemblyLinearVelocity=vec(),AssemblyAngularVelocity=vec(),
        AbsoluteSize=vec(450,270),Visible=true,Scale=1,Text="",TextureID="",CanCollide=true},
        _children={},_attrs={},_signals={}},nodeMeta)
    for _,name in ipairs({"Destroying","Activated","InputBegan","InputChanged","InputEnded",
        "CharacterRemoving","CharacterAdded","Event"}) do node._props[name]=signal() end
    M.nodes[#M.nodes+1]=node
    return node
end
function methods:IsA(class) return isA(self,class) end
function methods:GetChildren() return table.clone(self._children) end
function methods:FindFirstChild(name)
    for _,child in ipairs(self._children) do if child.Name==name then return child end end
    return nil
end
function methods:FindFirstChildOfClass(class)
    for _,child in ipairs(self._children) do if child:IsA(class) then return child end end
    return nil
end
function methods:FindFirstAncestorOfClass(class)
    local p=self.Parent
    while p do if p:IsA(class) then return p end; p=p.Parent end
end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:GetAttribute(key) return self._attrs[key] end
function methods:SetAttribute(key,value)
    self._attrs[key]=value; M.attributeWrites=M.attributeWrites+1
    M.writes[#M.writes+1]={key=key,value=value,node=self}
end
function methods:GetPropertyChangedSignal(key)
    if not self._signals[key] then self._signals[key]=signal() end
    return self._signals[key]
end
function methods:Destroy()
    if self._destroyed or self._destroying then return end
    self._destroying=true; self.Destroying:Fire()
    for _,child in ipairs(self:GetChildren()) do child:Destroy() end
    self.Parent=nil; self._destroyed=true
end
function methods:Clone()
    local copy=Instance.new(self.ClassName)
    for k,v in pairs(self._props) do
        if k~="Parent" and type(v)~="function" and not (type(v)=="table" and v.listeners) then copy._props[k]=v end
    end
    copy._attrs=table.clone(self._attrs)
    for _,child in ipairs(self._children) do child:Clone().Parent=copy end
    return copy
end
function methods:GetPivot()
    local root=self:FindFirstChild("HumanoidRootPart")
    return root and cf(root.Position) or self.CFrame
end
function methods:GetBoundingBox() return self:GetPivot(),vec(4,5,8) end
function methods:PivotTo(destination)
    local root=self:FindFirstChild("HumanoidRootPart")
    if self==M.character then M.moves=M.moves+1 end
    if root then root.Position=destination.Position; root.CFrame=destination
    else self.CFrame=destination end
end
function methods:Fire(...) self.Event:Fire(...) end
function methods:GetFocusedTextBox() return nil end
function methods:GetServerTimeNow() return 10000+M.now end
function methods:RequestStreamAroundAsync() M.streams=M.streams+1 end
function methods:Raycast(origin,direction)
    if not M.floor or direction.Y>=0 then return nil end
    if origin.Y+direction.Y>0 then return nil end
    return {Position=vec(origin.X,0,origin.Z),Normal=vec(0,1,0),
        Material=M.water and Enum.Material.Water or Enum.Material.Ground,Instance=M.ground}
end
function methods:GetPartBoundsInBox() return M.obstruction and {M.ground} or {} end
local function child(class,name,parent)
    local n=Instance.new(class); n.Name=name; n.Parent=parent; return n
end
M.player=Instance.new("Player")
M.playerGui=child("PlayerGui","PlayerGui",M.player)
M.services={Players=Instance.new("Players"),ReplicatedStorage=Instance.new("ReplicatedStorage"),
    RunService=Instance.new("RunService"),UserInputService=Instance.new("UserInputService"),Lighting=Instance.new("Lighting")}
M.services.Players.LocalPlayer=M.player
M.services.RunService.Heartbeat=signal()
workspace=Instance.new("Workspace")
workspace.CurrentCamera=Instance.new("Camera")
workspace.CurrentCamera.ViewportSize=vec(1100,800)
M.ground=child("Part","Ground",workspace)
game={PlaceId=108901361810209,GetService=function(_,key) return assert(M.services[key],key) end}
M.world=child("Folder","FeralWorld",M.services.ReplicatedStorage)
local portraits=child("Folder","Portraits",M.world)
M.portrait=child("MeshPart","Tiger",portraits)
child("Script","NeverRun",M.portrait)
child("SurfaceAppearance","DefaultLook",M.portrait)
child("MeshPart","SnowLeopard",portraits)
child("MeshPart","Phantosuchus",portraits)
local coats=child("Folder","Coats",M.world)
local tigerCoats=child("Folder","Tiger",coats)
local white=child("Folder","White",tigerCoats)
child("SurfaceAppearance","Tiger",white)
local originalRequire=require
require=function(module)
    M.requireCalls=M.requireCalls+1
    return assert(M.modules[module],"module not in fixture cache")
end
M.needs={STAMINA_SPRINT_DRAIN=.94,STAMINA_JUMP_COST=6,STAMINA_REGEN=1.31,
    STAMINA_REGEN_DELAY=.8,STAMINA_LOW_NEEDS=.5}
M.access={HIDE_LOCKED=true}
M.coats={LIST={Tiger={{id="Default",name="DEFAULT"},{id="White",name="White Tiger"}}}}
for key,value in pairs({NeedsConfig=M.needs,AccessConfig=M.access,CoatConfig=M.coats}) do
    local module=child("ModuleScript",key,M.world); M.modules[module]=value
end
function getloadedmodules()
    local result={}
    for module in pairs(M.modules) do result[#result+1]=module end
    return result
end
function M.spawn()
    local character=Instance.new("Model"); character.Name="TestAnimal"; character.Parent=workspace
    character:SetAttribute("Species","Tiger"); character:SetAttribute("Growth",.5)
    character:SetAttribute("Stamina",40); character:SetAttribute("StaminaMax",50)
    local hum=child("Humanoid","Humanoid",character); hum.Health=80; hum.MaxHealth=100
    local root=child("Part","HumanoidRootPart",character)
    local mesh=child("MeshPart","Tiger",character)
    local surface=child("SurfaceAppearance","GameOriginal",mesh)
    M.character,M.humanoid,M.root,M.mesh,M.originalSurface=character,hum,root,mesh,surface
    M.player.Character=character
    return character
end
function M.button(text,prefix)
    for i=#M.nodes,1,-1 do
        local n=M.nodes[i]
        if not n._destroyed and n:IsA("TextButton") and n.Parent
            and (n.Text==text or (prefix and n.Text:sub(1,#text)==text)) then return n end
    end
    error("button missing: "..text)
end
function M.click(text,prefix) M.button(text,prefix).Activated:Fire() end
function M.step(seconds)
    M.now=M.now+seconds; M.flush(); M.services.RunService.Heartbeat:Fire(seconds)
end
local passed=0
local function case(name,fn) fn(); passed=passed+1; print("PASS runtime "..name) end

-- HUB SCENARIOS
launchHub()
case("opens without a Start button or filesystem",function()
    assert(M.playerGui:FindFirstChild("FeralFieldHubV10"))
    assert(#M.warnings==0 and M.requireCalls==0 and M.moves==0 and M.streams==0)
    M.step(.25)
end)
M.spawn()
M.step(.25)
case("no resource writes by default",function()
    local writes=M.healthWrites
    M.step(.25)
    assert(M.healthWrites==writes)
    assert(M.character:GetAttribute("WolfDbgNoStamina")==nil)
end)
case("stamina tunes real cached fields without writing Stamina",function()
    local before=#M.writes
    M.click("STAMINA EXPERIMENT: OFF"); M.flush()
    assert(M.needs.STAMINA_SPRINT_DRAIN==0 and M.needs.STAMINA_REGEN==250)
    assert(M.character:GetAttribute("WolfDbgNoStamina")==true)
    for i=before+1,#M.writes do assert(M.writes[i].key~="Stamina") end
end)
case("stamina off restores owned fields and preserves external edits",function()
    M.needs.STAMINA_JUMP_COST=7
    M.click("STAMINA EXPERIMENT: ON",true)
    assert(M.needs.STAMINA_SPRINT_DRAIN==.94 and M.needs.STAMINA_REGEN==1.31)
    assert(M.needs.STAMINA_JUMP_COST==7)
    assert(M.character:GetAttribute("WolfDbgNoStamina")==nil)
end)
case("late module result cannot enable a stopped menu patch",function()
    M.click("SHOW HIDDEN CARDS IN NATIVE MENU: OFF")
    M.click("CHECKING LOADED ACCESS CONFIG...")
    M.flush(); assert(M.access.HIDE_LOCKED==true)
end)
case("hidden card toggle never modifies permissions",function()
    M.click("SHOW HIDDEN CARDS IN NATIVE MENU: OFF"); M.flush()
    assert(M.access.HIDE_LOCKED==false)
    assert(M.player:GetAttribute("FeralTester")==nil)
    M.click("HIDDEN CARDS VISIBLE",true)
    assert(M.access.HIDE_LOCKED==true)
end)
case("health trial stops at max and does not revive",function()
    M.click("LOCAL HP TRIAL: OFF")
    M.humanoid.Health=99.8; M.step(.25); assert(M.humanoid.Health==100)
    M.humanoid.Health=0; M.step(.25); assert(M.humanoid.Health==0)
    M.click("LOCAL HP TRIAL: ON",true); M.humanoid.Health=80
end)
case("preview removes cloned scripts without touching asset scripts",function()
    M.click("Tiger")
    local gui=M.playerGui:FindFirstChild("FeralFieldHubV10")
    local preview=nil
    for _,n in ipairs(M.nodes) do
        if n.Name=="HubPreviewWorld" and n.Parent and not n._destroyed then preview=n end
    end
    assert(preview and #preview:GetChildren()==1)
    assert(not preview:GetChildren()[1]:FindFirstChild("NeverRun"))
    assert(M.portrait:FindFirstChild("NeverRun"))
end)
case("local coat swap restores original identity",function()
    M.click("LOAD COATS FOR SELECTED PORTRAIT"); M.flush()
    M.click("White Tiger",true)
    M.click("TRY SELECTED COAT",true)
    assert(M.originalSurface.Parent~=M.mesh)
    assert(M.mesh:FindFirstChildOfClass("SurfaceAppearance")~=M.originalSurface)
    M.click("RESTORE MY LOCAL COAT")
    assert(M.originalSurface.Parent==M.mesh)
end)
case("travel without a landing cannot move",function()
    M.click("2  /  MOVE ONCE",true); assert(M.moves==0)
end)
case("water and absent geometry cannot enable travel",function()
    M.water=true; M.click("1  /  SCOUT",true); M.flush()
    M.click("2  /  MOVE ONCE",true); assert(M.moves==0)
    M.water=false; M.floor=false; M.click("1  /  SCOUT",true); M.flush()
    M.click("2  /  MOVE ONCE",true); assert(M.moves==0)
    M.floor=true
end)
case("stale landing cannot move",function()
    M.click("1  /  SCOUT",true); M.flush(); M.now=M.now+13
    M.click("2  /  MOVE ONCE",true); assert(M.moves==0)
end)
case("landing revalidation catches a new obstruction",function()
    M.click("1  /  SCOUT",true); M.flush(); M.obstruction=true
    M.click("2  /  MOVE ONCE",true); assert(M.moves==0)
    M.obstruction=false
end)
case("combat prevents travel",function()
    M.click("1  /  SCOUT",true); M.flush()
    M.player:SetAttribute("FeralCombatUntil",workspace:GetServerTimeNow()+30)
    M.click("2  /  MOVE ONCE",true); assert(M.moves==0)
    M.player:SetAttribute("FeralCombatUntil",nil)
end)
case("valid landing allows exactly one movement",function()
    M.click("1  /  SCOUT",true); M.flush()
    M.click("2  /  MOVE ONCE",true); assert(M.moves==1)
    M.click("2  /  MOVE ONCE",true); assert(M.moves==1)
end)
case("saved report is text and excludes account identity",function()
    local saved=nil
    writefile=function(name,content) saved={name,content} end
    M.click("SAVE HUB STATUS .TXT")
    assert(saved and saved[1]:match("%.txt$") and saved[2]:find("client status only",1,true))
    assert(not saved[2]:find("UserId",1,true) and not saved[2]:find("TestAnimal",1,true))
end)
case("respawn restores old flag and applies new flag",function()
    M.click("STAMINA EXPERIMENT: OFF"); M.flush()
    local old=M.character
    M.spawn(); M.step(.25)
    assert(old:GetAttribute("WolfDbgNoStamina")==nil)
    assert(M.character:GetAttribute("WolfDbgNoStamina")==true)
end)
case("rerunning replaces hub and restores its settings",function()
    local old=M.playerGui:FindFirstChild("FeralFieldHubV10")
    launchHub()
    assert(old._destroyed and M.playerGui:FindFirstChild("FeralFieldHubV10")~=old)
    assert(M.needs.STAMINA_REGEN==1.31)
    assert(M.character:GetAttribute("WolfDbgNoStamina")==nil)
end)
case("close cleans settings and camera subscription",function()
    M.click("STAMINA EXPERIMENT: OFF"); M.flush()
    M.click("BRIGHTER VIEW: OFF")
    M.click("X")
    assert(not M.playerGui:FindFirstChild("FeralFieldHubV10"))
    assert(M.character:GetAttribute("WolfDbgNoStamina")==nil and M.needs.STAMINA_REGEN==1.31)
    for _,c in ipairs(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize").listeners) do assert(not c.Connected) end
end)
case("rapid off-on during a module check uses the latest request",function()
    launchHub()
    M.click("SHOW HIDDEN CARDS IN NATIVE MENU: OFF")
    M.click("CHECKING LOADED ACCESS CONFIG...")
    M.click("SHOW HIDDEN CARDS IN NATIVE MENU: OFF")
    M.flush(); assert(M.access.HIDE_LOCKED==false)
    M.click("X"); assert(M.access.HIDE_LOCKED==true)
end)
case("missing optional API degrades without startup failure",function()
    local old=getloadedmodules; getloadedmodules=nil
    launchHub(); M.click("STAMINA EXPERIMENT: OFF")
    assert(M.needs.STAMINA_REGEN==1.31)
    assert(M.character:GetAttribute("WolfDbgNoStamina")==true)
    M.click("X"); assert(M.character:GetAttribute("WolfDbgNoStamina")==nil)
    getloadedmodules=old
end)
case("frozen cached configuration is not force-unlocked",function()
    local module=M.world:FindFirstChild("NeedsConfig")
    M.modules[module]=table.freeze(table.clone(M.needs))
    launchHub(); M.click("STAMINA EXPERIMENT: OFF"); M.flush()
    assert(M.modules[module].STAMINA_REGEN==1.31)
    M.click("X"); M.modules[module]=M.needs
end)
case("closing while a cache request waits prevents a late mutation",function()
    launchHub(); M.click("STAMINA EXPERIMENT: OFF"); M.click("X"); M.flush()
    assert(M.needs.STAMINA_REGEN==1.31)
    assert(M.character:GetAttribute("WolfDbgNoStamina")==nil)
end)
case("external GUI destruction restores settings",function()
    launchHub(); M.click("STAMINA EXPERIMENT: OFF"); M.flush()
    M.playerGui:FindFirstChild("FeralFieldHubV10"):Destroy()
    assert(M.needs.STAMINA_REGEN==1.31)
    assert(M.character:GetAttribute("WolfDbgNoStamina")==nil)
end)
case("startup error reports phase and cleans partial UI",function()
    local oldNew=Instance.new
    Instance.new=function(class)
        if class=="ViewportFrame" then error("injected permission failure PRIVATE-API-TEXT") end
        return oldNew(class)
    end
    launchHub(); Instance.new=oldNew
    assert(not M.playerGui:FindFirstChild("FeralFieldHubV10"))
    assert(#M.warnings==1 and M.warnings[1]:find("creating_animal_studio",1,true))
    assert(not M.warnings[1]:find("PRIVATE-API-TEXT",1,true))
end)
case("wrong place does not start",function()
    game.PlaceId=1; launchHub()
    assert(not M.playerGui:FindFirstChild("FeralFieldHubV10"))
    assert(#M.warnings==2)
end)
print("RUNTIME_CASES="..passed)
