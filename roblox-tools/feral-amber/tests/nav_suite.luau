local Gait=assert(loadstring(GAIT_SRC,"=FERAL_AMBER_GAIT"))()
local Nav=assert(loadstring(NAV_SRC,"=FERAL_AMBER_NAV"))()
local total,passed=0,0
local function test(name,fn)
    total+=1
    local ok,errorMessage=pcall(fn)
    if ok then passed+=1;print("PASS "..name)
    else print("FAIL "..name.." : "..tostring(errorMessage)) end
end
local function eq(a,b,msg)
    assert(a==b,(msg or "equality")..": got "..tostring(a).." expected "..tostring(b))
end
local vmeta={}
vmeta.__index=function(self,k)
    if k=="Magnitude" then return math.sqrt(self.X^2+self.Y^2+self.Z^2) end
    if k=="Unit" then
        local size=math.sqrt(self.X^2+self.Y^2+self.Z^2)
        return setmetatable({X=self.X/size,Y=self.Y/size,Z=self.Z/size,vector=true},vmeta)
    end
end
local function v(x,y,z)return setmetatable({X=x,Y=y,Z=z,vector=true},vmeta) end
vmeta.__sub=function(a,b)return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vmeta.__add=function(a,b)return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vmeta.__mul=function(a,b)
    if type(a)=="number" then return v(a*b.X,a*b.Y,a*b.Z) end
    return v(a.X*b,a.Y*b,a.Z*b)
end
vmeta.__div=function(a,b)return v(a.X/b,a.Y/b,a.Z/b)end
Vector3={new=v,zero=v(0,0,0)}
Enum={KeyCode={},RaycastFilterType={Exclude=1},Material={Water="Water"},PathStatus={Success="Success"}}
for _,key in ipairs({"W","A","S","D","LeftShift","X","Z"}) do Enum.KeyCode[key]=key end
RaycastParams={new=function()return {}end}
typeof=function(x)return type(x)=="table" and x.vector and "Vector3" or type(x)end
local input={events={}}
function input:SendKeyEvent(on,key)
    table.insert(self.events,{name=key,on=on})
end
game={GetService=function(_,name)
    if name=="VirtualInputManager" then return input end
end}
local tasks={}
task={delay=function(_,fn)table.insert(tasks,fn)end}
local workspace={Terrain={},CurrentCamera={
    CFrame={LookVector=v(0,0,-1),RightVector=v(1,0,0)}}}
function workspace:Raycast(origin,delta)
    return {Position=v(origin.X,0,origin.Z),Material="Grass",
        Normal={Y=1},Instance=self.Terrain}
end
local paths={created=0}
function paths:CreatePath()
    self.created+=1
    local path={Status=Enum.PathStatus.Success}
    function path:ComputeAsync(from,to)
        self.waypoints={{Position=from},{Position=to}}
    end
    function path:GetWaypoints() return self.waypoints end
    return path
end
local function world()
    input.events={};tasks={}
    local root={Position=v(0,0,0),Size=v(6,4,6),Parent={}}
    local char={}
    local hum={Health=200,HipHeight=3,moves={},requested={}}
    function hum:Move(dir)
        table.insert(self.moves,dir)
    end
    function hum:MoveTo(dest)
        table.insert(self.requested,dest)
    end
    local nav=Nav.new(paths,workspace,Gait)
    local state={staminaFraction=.97,allowBurst=true,hudBurst=false,
        hudBurstNo=false,hudTrot=false}
    return nav,char,hum,root,state
end
local function seen(name,on)
    local count=0
    for _,e in ipairs(input.events) do
        if e.name==name and e.on==on then count+=1 end
    end
    return count
end
test("a Spirit Bear long-range route requests native sprint and Burst",function()
    local nav,char,hum,root,state=world()
    eq(nav:tick(v(350,0,0),char,hum,root,10,{},state),"MOVING")
    eq(nav.gait,"BURST")
    assert(seen("LeftShift",true)>=1)
    assert(seen("X",true)>=1)
end)
test("world-space steering never holds camera-relative WASD concurrently",function()
    local nav,char,hum,root,state=world()
    nav:tick(v(350,0,0),char,hum,root,10,{},state)
    nav:drive()
    assert(#hum.moves>0)
    for _,name in ipairs({"W","A","S","D"}) do
        eq(seen(name,true),0,"Unexpected competing key "..name)
    end
end)
test("burst is not repeatedly requested when native HUD says it is active",function()
    local nav,char,hum,root,state=world()
    state.hudBurst=true
    nav:tick(v(350,0,0),char,hum,root,10,{},state)
    eq(seen("X",true),0)
end)
test("sharp approach ends in a trot without an unsafe Burst input",function()
    local nav,char,hum,root,state=world()
    nav:tick(v(34,0,0),char,hum,root,10,{},state)
    eq(nav.gait,"TROT")
    eq(seen("X",true),0)
    eq(seen("LeftShift",true),0)
end)
test("high-speed waypoint overshoot never drives animal backwards",function()
    local nav,char,hum,root,state=world()
    nav:tick(v(350,0,0),char,hum,root,10,{},state)
    assert(nav.desiredPoint~=nil)
    root.Position=v(96,0,0)
    eq(nav:tick(v(350,0,0),char,hum,root,11,{},state),"MOVING")
    eq(nav.desiredPoint,nil)
    eq(nav.lastReason,"SEGMENT_COMPLETE")
    nav:drive()
    eq(nav.desiredPoint,nil)
end)
test("controller continues with next surface segment after passing waypoint",function()
    local nav,char,hum,root,state=world()
    nav:tick(v(350,0,0),char,hum,root,10,{},state)
    root.Position=v(98,0,0)
    nav:tick(v(350,0,0),char,hum,root,11,{},state)
    nav:tick(v(350,0,0),char,hum,root,11.5,{},state)
    assert(nav.desiredPoint and nav.desiredPoint.X>98)
end)
test("release on shutdown clears Shift and any pending Burst key",function()
    local nav,char,hum,root,state=world()
    nav:tick(v(350,0,0),char,hum,root,10,{},state)
    nav:stop(hum,root,"hub unload")
    eq(nav.gait,"STOP")
    eq(nav.desiredPoint,nil)
    assert(seen("LeftShift",false)>=1)
    assert(seen("X",false)>=1)
end)
test("nearby other player blocks route and releases movement immediately",function()
    local nav,char,hum,root,state=world()
    nav:tick(v(350,0,0),char,hum,root,10,{},state)
    eq(nav:tick(v(350,0,0),char,hum,root,11,{v(3,0,0)},state),"BLOCKED")
    eq(nav.desiredPoint,nil)
    eq(nav.gait,"STOP")
end)
print(string.format("AMBER_NAV_RESULT total=%d passed=%d failed=%d",total,passed,total-passed))
assert(total==passed,"Native navigation tests failed")
