-- Offline fault-injection harness. This simulates APIs; it is not Roblox/Velocity.
local case = TEST_CASE or "normal"
local clock, queue, disk, folders, nodes, warnings = 0, {}, {}, {}, {}, {}
local decompileCalls, writes, forbiddenWrites, eventCalls, cancelled = 0,0,0,0,0
local stopTriggered, pauseTriggered, pausedCalls = false,false,nil
local nativeClock = os.clock
os.clock = function() return clock end
local function schedule(fn, delay, args)
    local thread = type(fn) == "thread" and fn or coroutine.create(fn)
    queue[#queue + 1] = {thread = thread, at = clock + (delay or 0), args = args}
    return thread
end
task = {}
function task.spawn(fn, ...) return schedule(fn,0,{...}) end
function task.defer(fn, ...) return schedule(fn,0,{...}) end
function task.delay(delay,fn,...) return schedule(fn,delay,{...}) end
function task.wait(delay) return coroutine.yield(delay or 0.016) end
local dead = {}
function task.cancel(thread)
    if case == "uncancellable" then error("cannot cancel native thread") end
    dead[thread] = true; cancelled = cancelled + 1
end
local function signal()
    local self = {handlers = {}}
    function self:Connect(fn)
        local connection = {connected = true}
        function connection:Disconnect() self.connected = false end
        self.handlers[#self.handlers + 1] = {fn = fn,connection = connection}
        return connection
    end
    function self:Fire(...)
        for _,handler in ipairs(self.handlers) do if handler.connection.connected then handler.fn(...) end end
    end
    return self
end
local enumMeta = {__index = function(self,key)
    local value = setmetatable({__type = "EnumItem",label = self.label .. "." .. key}, {__tostring = function(v) return v.label end})
    rawset(self,key,value); return value
end}
Enum = setmetatable({}, {__index = function(self,key)
    local value = setmetatable({label = "Enum." .. key},enumMeta); rawset(self,key,value); return value
end})
Color3 = {fromRGB = function(r,g,b) return {__type = "Color3",R = r/255,G = g/255,B = b/255} end}
Vector2 = {new = function(x,y) return {__type = "Vector2",X=x,Y=y} end}
local function udim(s,o) return {__type="UDim",Scale=s,Offset=o} end
UDim = {new = udim}
UDim2 = {new = function(xs,xo,ys,yo) return {__type="UDim2",X=udim(xs,xo),Y=udim(ys,yo)} end}
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
local parents = {
    PlayerGui="BasePlayerGui", ScreenGui="LayerCollector", LayerCollector="GuiBase2d",
    Frame="GuiObject", TextLabel="GuiObject", TextBox="GuiObject", TextButton="GuiButton", GuiButton="GuiObject",
    GuiObject="GuiBase2d", UICorner="UIComponent", UIScale="UIComponent",
    LocalScript="BaseScript", ModuleScript="LuaSourceContainer", Script="BaseScript", BaseScript="LuaSourceContainer",
    NumberValue="ValueBase", StringValue="ValueBase", ObjectValue="ValueBase", Part="BasePart",
}
local methods = {}
function methods:IsA(class)
    local cursor = self._class
    while cursor do if cursor == class then return true end; cursor = parents[cursor] end
    return class == "Instance"
end
function methods:IsDescendantOf(root)
    local cursor = self._props.Parent
    while cursor do if cursor == root then return true end; cursor = cursor._props.Parent end
    return false
end
function methods:GetChildren()
    if self._props.childrenFail then error("security permission") end
    local out = {}; for _,child in ipairs(self._children) do out[#out+1] = child end; return out
end
function methods:GetAttributes()
    if self._props.attributesFail then error("permission denied") end
    return self._attrs
end
function methods:FindFirstChild(name)
    for _,child in ipairs(self._children) do if child.Name == name then return child end end
end
function methods:FindFirstChildOfClass(class)
    for _,child in ipairs(self._children) do if child.ClassName == class then return child end end
end
function methods:GetService(name) return services[name] or error("unknown service " .. name) end
function methods:GetPlayers() return self._props.playerList end
function methods:GetState() return Enum.HumanoidStateType.Running end
function methods:GetPlayingAnimationTracks() return self._props.mockTracks or {} end
function methods:Destroy() self.Destroying:Fire(); self.Parent = nil end
local mt = {
    __index = function(self,key)
        if key == "ClassName" then return self._class end
        if methods[key] then return methods[key] end
        local value = self._props[key]
        if value ~= nil or key == "Parent" then return value end
        if key == "Source" then error("security permission denied") end
        error(key .. " is not a valid member")
    end,
    __newindex = function(self,key,value)
        if not self._own then forbiddenWrites = forbiddenWrites + 1; error("gameplay write: " .. key) end
        if key == "Parent" then
            self._props.Parent = value
            if value then value._children[#value._children+1] = self end
        else self._props[key] = value end
    end,
    __tostring = function(self) return self._props.Name end,
}
local function newNode(class,name,parent,props,attrs,own)
    local p = props or {}; p.Name,p.Parent,p.Archivable = name,parent,true
    if class=="Script" or class=="LocalScript" then p.Enabled,p.Disabled=true,false end
    for _,key in ipairs({"Activated","Destroying","InputBegan","CharacterAdded","PlayerAdded"}) do p[key] = signal() end
    local self = setmetatable({_class=class,_props=p,_attrs=attrs or {},_children={},_own=own or false,__type="Instance"},mt)
    if parent then parent._children[#parent._children+1] = self end
    nodes[#nodes+1] = self
    return self
end
function typeof(value) return type(value) == "table" and rawget(value,"__type") or type(value) end
Instance = {new = function(class) return newNode(class,class,nil,{},nil,true) end}
warn = function(text) warnings[#warnings+1] = text end
gcinfo = function() return 1024 end
local dumping = false
local function quote(text)
    local pattern = dumping and '[%z\1-\31\128-\255\\"]' or '[%z\1-\31\\"]'
    return '"' .. text:gsub(pattern,function(char)
        local known = {['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
        return known[char] or string.format('\\u%04x',string.byte(char))
    end) .. '"'
end
local function json(value,seen)
    local kind=type(value)
    if kind == "string" then return quote(value) end
    if kind == "number" or kind == "boolean" then return tostring(value) end
    if kind == "nil" then return "null" end
    assert(kind == "table","unserializable mock JSON")
    seen=seen or {}; assert(not seen[value],"cycle"); seen[value]=true
    local out, isArray, count = {},true,0
    for key in pairs(value) do count=count+1; if type(key)~="number" then isArray=false end end
    if isArray then
        assert(count == #value,"sparse array")
        for _,item in ipairs(value) do out[#out+1]=json(item,seen) end
        seen[value]=nil; return '['..table.concat(out,',')..']'
    end
    local keys={}; for key in pairs(value) do keys[#keys+1]=key end; table.sort(keys)
    for _,key in ipairs(keys) do out[#out+1]=quote(key)..':'..json(value[key],seen) end
    seen[value]=nil; return '{'..table.concat(out,',')..'}'
end
services = {}
game = newNode("DataModel","Game",nil,{PlaceId=108901361810209})
workspace = newNode("Workspace","Workspace",game,{Gravity=196.2,StreamingEnabled=true})
workspace._props.CurrentCamera = newNode("Camera","Camera",workspace,{ViewportSize=Vector2.new(1920,1080)})
services.Workspace = workspace
services.Players = newNode("Players","Players",game)
local localPlayer = newNode("Player","Joel",services.Players,{DisplayName="LocalDisplay",UserId=1234})
local playerGui = newNode("PlayerGui","PlayerGui",localPlayer)
local localCharacter = newNode("Model","Joel",workspace)
localPlayer._props.Character = localCharacter
newNode("Humanoid","Humanoid",localCharacter,{Health=80,MaxHealth=100,WalkSpeed=20})
local other = newNode("Player","PRIVATE_OTHER_NAME",services.Players,{DisplayName="PRIVATE_DISPLAY_NAME",UserId=98765})
local otherChar = newNode("Model","PRIVATE_OTHER_NAME",workspace,{}, {private="PRIVATE_OTHER_ATTRIBUTE"})
other._props.Character = otherChar
newNode("StringValue","AccountData",otherChar,{Value="PRIVATE_OTHER_SECRET"})
services.Players._props.LocalPlayer,services.Players._props.playerList = localPlayer,{localPlayer,other}
services.ReplicatedStorage = newNode("ReplicatedStorage","ReplicatedStorage",game)
services.CorePackages = newNode("CorePackages","CorePackages",game)
services.CoreGui = newNode("CoreGui","CoreGui",game)
services.HttpService = newNode("HttpService","HttpService",game)
services.HttpService._props.JSONEncode = function(_,value) return json(value) end
services.HttpService._props.GenerateGUID = function() return "01234567-89ab-cdef-0123-456789abcdef" end
services.HttpService._props.JSONDecode = function(_,text)
    if text:find('"stamina"',1,true) then
        return {stamina={regen=5,max=100},password="PRIVATE_JSON_PASSWORD",array={1,2,3},
            PRIVATE_OTHER_NAME={data="PRIVATE_JSON_OTHER_DATA"}}
    end
    error("mock decoder only supports the configuration fixture")
end
services.CollectionService = newNode("CollectionService","CollectionService",game)
services.CollectionService._props.GetTags = function(_,obj) return obj._props.tags or {} end
services.UserInputService = newNode("UserInputService","UserInputService",game,{InputChanged=signal(),InputEnded=signal()})
local config = newNode("Folder","AnimalConfig",services.ReplicatedStorage,{},
    {StaminaMax=100,Regen=5,Species="Wolf",AuthToken="PRIVATE_ATTRIBUTE_TOKEN",Badge="VALID_CONFIG",Binary="a\255b"})
newNode("NumberValue","BleedRate",config,{Value=2})
newNode("StringValue","AnimalType",config,{Value="Wolf"})
newNode("StringValue","BalanceConfig",config,{Value='{"stamina":{"regen":5,"max":100},"password":"PRIVATE_JSON_PASSWORD"}'})
newNode("StringValue","Password",config,{Value="PRIVATE_PASSWORD_VALUE"})
newNode("StringValue","Webhook",config,{Value="PRIVATE_WEBHOOK_VALUE"})
newNode("RemoteEvent","FeedRequest",services.ReplicatedStorage,{FireServer=function() eventCalls=eventCalls+1;error("remote invoked") end})
newNode("BindableEvent","LocalSignal",services.ReplicatedStorage)
local runAnimation = newNode("Animation","WolfRun",config,{AnimationId="rbxassetid://123456"})
local animator = newNode("Animator","Animator",localCharacter)
local playingTrack = newNode("AnimationTrack","RunTrack",nil,{Animation=runAnimation,IsPlaying=true,Length=2,
    Looped=true,Priority=Enum.AnimationPriority.Movement,Speed=1,TimePosition=0,WeightCurrent=1,WeightTarget=1})
animator._props.mockTracks = {playingTrack}
newNode("Folder","BinaryNode\255",config)
newNode("Folder","PlayerData",services.ReplicatedStorage,{}, {private="PRIVATE_PROFILE_ATTRIBUTE"})
newNode("TextLabel","HudHealth",playerGui,{Text="PRIVATE_UI_CHAT_TEXT",TextSize=12,Visible=true})
newNode("TextBox","Input",playerGui,{Text="PRIVATE_TEXTBOX_INPUT",TextEditable=true})
local chat = newNode("Folder","ExperienceChat",services.CoreGui)
newNode("TextLabel","PRIVATE_MESSAGE_NODE",chat,{Text="PRIVATE_MESSAGE_TEXT"},{message="PRIVATE_MESSAGE_ATTRIBUTE"})
newNode("Folder","Unreadable",config,{childrenFail=true,attributesFail=true})
local allScripts = {}
local function addScript(class,name,parent,source,props)
    local obj=newNode(class,name,parent,props or {})
    obj._props.mockSource=source
    allScripts[#allScripts+1]=obj
    return obj
end
addScript("LocalScript","StaminaController",config,[==[-- PRIVATE_COMMENT_TOKEN
local Config = { StaminaMax = 100, BleedRate = 2, Species = "Wolf" }
local AccessToken = "PRIVATE_SOURCE_TOKEN"
local email = 'private@example.test'
local password = [=[PRIVATE_LONG_LITERAL]=]
local escaped = "\080\082\073\086\065\084\069"
local asset = "rbxassetid://123456"
local a=1 --[[PRIVATE_INLINE_COMMENT]] local b=2
return Config
]==])
addScript("ModuleScript","ReadableModule",config,"unused",{Source="return {growth=2}"})
addScript("Script","ClientCombat",config,"return {damage=4}",{RunContext=Enum.RunContext.Client})
addScript("Script","ServerStub",config,"PRIVATE_SERVER_SOURCE",{RunContext=Enum.RunContext.Server})
addScript("ModuleScript","RobloxModule",services.CorePackages,"return { platform = true }")
addScript("LocalScript","RobloxGuiScript",services.CoreGui,"return { ui = true }")
addScript("ModuleScript","Throws",config,"throws")
addScript("ModuleScript","CommentOnly",config,"-- decompile failed")
if case == "chunked" then addScript("ModuleScript","Big",config,'return [=['..string.rep('αβText\n',130000)..']=]') end
if case == "oversize" then addScript("ModuleScript","Oversize",config,string.rep('local a=1\n',850000)) end
if case == "scale" then
    for i=1,37983 do addScript("ModuleScript","PlatformModule"..i,services.CorePackages,"return {index="..i.."}") end
end
if case == "deep" then
    local parent=config
    for i=1,520 do parent=newNode("Folder","D"..i,parent) end
end
local function click(name)
    for _,node in ipairs(nodes) do
        if node._own and node._props.Name==name then node._props.Activated:Fire(); return end
    end
    error("missing button "..name)
end
function decompile(obj)
    decompileCalls=decompileCalls+1
    if case == "cancel" and decompileCalls==3 then click("Stop"); stopTriggered=true end
    if case == "pause" and decompileCalls==2 then
        click("Pause"); pauseTriggered=true; pausedCalls=decompileCalls
        task.delay(1,function() assert(decompileCalls==pausedCalls,"started source while paused"); click("Pause") end)
    end
    if (case == "timeouts" or case == "uncancellable") and obj.Name~="StaminaController" then task.wait(1000) end
    if case == "yielding" then task.wait(0.1) end
    if obj.Name=="Throws" then error("executor failure PRIVATE_EXCEPTION_TEXT") end
    return obj._props.mockSource
end
local initiallyMissing = case=="missing_files"
function makefolder(path) folders[path]=true end
function isfolder(path) return folders[path] or false end
function writefile(path,body)
    writes=writes+1
    if case == "write_failure" and path:find("objects/",1,true) then error("disk full") end
    disk[path]=body
    if case == "stop_inventory" and not stopTriggered and path:find("objects/",1,true) then
        click("Stop"); stopTriggered=true
    end
end
function readfile(path)
    assert(disk[path],"no file")
    if case=="read_corruption" then return disk[path].."CORRUPTION" end
    return disk[path]
end
function setclipboard(_) end
function getloadedmodules() return allScripts end
function getscripts() return allScripts end
if case=="no_decompiler" then decompile=nil end
if case=="no_readfile" then readfile=nil end
if initiallyMissing then writefile,makefolder=nil,nil end
local text=assert(io.open(SOURCE_PATH,"rb")):read("*a")
if case=="object_limit" then text=text:gsub("maxObjects = 600000","maxObjects = 20",1) end
if case=="source_budget" then text=text:gsub("maxExportBytes = 2147483648","maxExportBytes = 16780000",1) end
if case=="config_limit" then text=text:gsub("maxDecodedConfigNodes = 100000","maxDecodedConfigNodes = 2",1) end
if case=="memory_limit" then gcinfo=function() return clock>0.05 and 400000 or 1024 end end
assert(load(text,"@feral-complete-diagnostic-v3.0.lua"))()
local steps=0
while #queue>0 do
    table.sort(queue,function(a,b) return a.at<b.at end)
    local item=table.remove(queue,1)
    if not dead[item.thread] and coroutine.status(item.thread)~="dead" then
        clock=math.max(clock,item.at)
        local ok,delay=coroutine.resume(item.thread,table.unpack(item.args or {}))
        assert(ok,tostring(delay))
        if coroutine.status(item.thread)~="dead" then schedule(item.thread,delay or 0.016) end
    end
    steps=steps+1
    assert(steps<1500000,"scheduler did not finish")
    if case=="uncancellable" and clock>100 then break end
end
os.clock=nativeClock
local status,notice
for _,node in ipairs(nodes) do
    if node._own and node._props.Name=="Status" then status=node._props.Text end
    if node._own and node._props.Name=="Notice" then notice=node._props.Text end
end
assert(forbiddenWrites==0,"gameplay mutations occurred")
assert(eventCalls==0,"gameplay remote was invoked")
local result={case=case,disk=disk,decompile_calls=decompileCalls,writes=writes,cancelled=cancelled,
    status=status,notice=notice,steps=steps,clock=clock,stop_triggered=stopTriggered,pause_triggered=pauseTriggered,warnings=warnings}
dumping = true -- encode arbitrary file bytes as reversible U+00xx JSON escapes
local output=assert(io.open(OUTPUT_PATH,"wb")); output:write(json(result)); output:close()
