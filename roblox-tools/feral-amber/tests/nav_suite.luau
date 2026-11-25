-- Scripted physical simulations, not recorded live travel or a FERAL server.
local Gait=assert(loadstring(GAIT_SRC))()
local Nav
local total,passed=0,0
local function eq(a,b,msg) assert(a==b,(msg or "equality")..": "..tostring(a).." != "..tostring(b)) end
local function test(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then passed+=1;print("PASS "..name) else print("FAIL "..name.." "..tostring(why)) end
end
local vm={};local methods={}
local function v(x,y,z) return setmetatable({X=x,Y=y,Z=z,vector=true},vm) end
vm.__index=function(a,k)
    if k=="Magnitude" then return math.sqrt(a.X^2+a.Y^2+a.Z^2) end
    if k=="Unit" then local m=a.Magnitude;return m>.001 and v(a.X/m,a.Y/m,a.Z/m) or v(0,0,0) end
    return methods[k]
end
vm.__add=function(a,b)return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vm.__sub=function(a,b)return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vm.__mul=function(a,b)if type(a)=="number"then a,b=b,a end;return v(a.X*b,a.Y*b,a.Z*b)end
vm.__div=function(a,b)return v(a.X/b,a.Y/b,a.Z/b)end
function methods:Dot(b)return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
Vector3={new=v,zero=v(0,0,0)}
Enum={KeyCode={},RaycastFilterType={Exclude=1},Material={Water="Water"},PathStatus={Success="Success"}}
for _,key in ipairs({"W","A","S","D","LeftShift","X","Z"}) do Enum.KeyCode[key]=key end
RaycastParams={new=function()return {}end}
typeof=function(a)return type(a)=="table" and a.vector and "Vector3" or type(a)end
local loader=assert(loadstring(NAV_SRC))
setfenv(loader,getfenv()) -- Disable built-in import caching for fake Vector3 typeof.
Nav=loader()
local scene,keys,events,timers,jobs
local input={}
function input:SendKeyEvent(on,key) keys[key]=on;table.insert(events,{key=key,on=on}) end
game={GetService=function(_,name)if name=="VirtualInputManager"then return input end end}
task={delay=function(_,fn)table.insert(timers,fn)end,spawn=function(fn)
    if scene.deferred then table.insert(jobs,fn) else fn() end
end}
local function world()
    scene={};keys={};events={};timers={};jobs={}
    local workspace={Terrain={CanCollide=true},CurrentCamera={CFrame={LookVector=v(0,0,-1),RightVector=v(1,0,0)}}}
    function workspace:Raycast(origin,delta)
        if delta.Y<-100 then
            if scene.missing then return nil end
            local wet=scene.water and origin.X>30 and origin.X<150
            local height=scene.height and scene.height(origin.X) or 0
            return {Position=v(origin.X,height,origin.Z),Material=wet and "Water" or "Grass",Normal={Y=1},Instance=self.Terrain}
        end
        if scene.wall then return {Instance=self.Terrain,Material="Rock",Position=origin,Normal={Y=0}} end
    end
    local paths={calls=0}
    function paths:CreatePath(options)
        self.calls+=1;self.options=options
        local path={Status=scene.noPath and "NoPath" or "Success"}
        function path:ComputeAsync(from,to)
            if scene.computeHook then scene.computeHook() end
            self.points=scene.path or {{Position=from},{Position=to}}
        end
        function path:GetWaypoints()return self.points end
        return path
    end
    local root={Position=v(0,3,0),Parent={},Size=v(6,4,10),CFrame={LookVector=v(1,0,0)}}
    local hum={Health=200,HipHeight=3,MoveDirection=v(0,0,0),writes=0}
    function hum:Move(dir)self.MoveDirection=dir;self.writes+=1 end
    local nav=Nav.new(paths,workspace,Gait)
    local state={staminaFraction=.98,allowBurst=true,hudBurst=false,hudTrot=false,hudSprint=false,allowWater=true}
    return nav,{},hum,root,state,workspace,paths
end
local function run(nav,char,hum,root,state,goal,first,steps,speed)
    for frame=1,steps do
        local now=first+frame*.2
        state.now=now
        nav:tick(goal,char,hum,root,now,{},state)
        nav:drive()
        local direction=hum.MoveDirection
        if nav.steeringStrategy=="KEY" then direction=v((keys.D and 1 or 0)-(keys.A and 1 or 0),0,(keys.S and 1 or 0)-(keys.W and 1 or 0));if direction.Magnitude>1 then direction=direction.Unit end end
        root.Position+=direction*(speed or 24)*.2
        for _,fn in ipairs(timers)do fn()end;timers={}
    end
end
test("START issues a direction and requests sprint before long ground travel",function()
    local n,c,h,r,s=world();eq(n:tick(v(350,3,0),c,h,r,10,{},s),"MOVING");n:drive()
    assert(h.MoveDirection.X>.9);eq(n.gait,"SPRINT");assert(keys.LeftShift)
    eq(n.inputVerified,false);eq(keys.X,nil)
end)
test("long route sustains over 300 studs without resetting at each segment",function()
    local n,c,h,r,s=world();run(n,c,h,r,s,v(380,3,0),10,72,25)
    assert(r.Position.X>330);assert(n.travelled>320);assert(n.segmentCount>=3);eq(n.replans,0)
end)
test("segment prefetch preserves a valid steering direction",function()
    local n,c,h,r,s=world();n:tick(v(350,3,0),c,h,r,10,{},s)
    r.Position=v(82,3,0);n:tick(v(350,3,0),c,h,r,11,{},s)
    assert(n.desiredPoint and n.desiredPoint.X>100)
end)
test("overshot waypoint continues forwards immediately",function()
    local n,c,h,r,s=world();n:tick(v(350,3,0),c,h,r,10,{},s)
    r.Position=v(110,3,0);eq(n:tick(v(350,3,0),c,h,r,11,{},s),"MOVING")
    assert(n.desiredPoint.X>110);n:drive();assert(h.MoveDirection.X>0)
end)
test("final close arrival does not oscillate between waypoint and destination",function()
    local n,c,h,r,s=world();s.moveRadius=2
    run(n,c,h,r,s,v(20,3,0),10,20,10)
    assert(math.abs(r.Position.X-20)<=2.1)
end)
test("moving prey target updates do not reset the stall watchdog",function()
    local n,c,h,r,s=world();s.navKey="NPC";s.movingTarget=true
    for i=0,12 do n:tick(v(50+i*15,3,0),c,h,r,10+i,{},s) end
    assert(n.replans>=2);assert(n.stallsInRow>=2)
end)
test("physical non-progress uses bounded fallback and ultimately releases inputs",function()
    local n,c,h,r,s=world();local result
    for i=0,26 do result=n:tick(v(300,3,0),c,h,r,10+i,{},s);if result=="STUCK"then break end end
    eq(result,"STUCK");eq(n.desiredPoint,nil);eq(next(n.held),nil)
end)
test("terrain wall is rejected rather than exempting Terrain",function()
    local n,c,h,r,s=world();scene.wall=true;scene.noPath=true
    n:tick(v(300,3,0),c,h,r,10,{},s)
    eq(n.desiredPoint,nil);assert(n.lastFailure)
end)
test("large body path clearance uses width rather than entire animal length",function()
    local n,c,h,r,s,w,p=world();scene.wall=true;r.Size=v(4,4,28)
    n:tick(v(300,3,0),c,h,r,10,{},s)
    eq(p.options.AgentRadius,2.65)
end)
test("entering water follows a checked swim route",function()
    local n,c,h,r,s=world();scene.water=true
    n:tick(v(280,3,0),c,h,r,10,{},s)
    assert(n.waterRoutes>0);assert(n.desiredPoint)
end)
test("crossing water and leaving the bank keeps the route alive",function()
    local n,c,h,r,s=world();scene.water=true
    for i=1,65 do
        s.swimming=r.Position.X>30 and r.Position.X<150
        run(n,c,h,r,s,v(300,3,0),10+(i-1)*.2,1,24)
    end
    assert(r.Position.X>270);assert(n.waterRoutes>0)
end)
test("unknown or disabled water capability cannot choose a wet direct route",function()
    local n,c,h,r,s=world();scene.water=true;s.allowWater=false;scene.noPath=true
    n:tick(v(280,3,0),c,h,r,10,{},s);eq(n.waterRoutes,0)
end)
test("steep shoreline is not treated as flat water",function()
    local n,c,h,r,s=world();scene.water=true;scene.noPath=true;scene.height=function(x)return x>55 and 80 or 0 end
    local clear=n:clearSegment(r.Position,v(100,80,0),c,true);eq(clear,false)
end)
test("STOP while a path job is pending prevents late movement",function()
    local n,c,h,r,s=world();scene.deferred=true
    eq(n:tick(v(300,3,0),c,h,r,10,{},s),"WAIT");assert(#jobs==1)
    n:stop(h,r,"STOP");for _,fn in ipairs(jobs)do fn()end
    eq(n.desiredPoint,nil);eq(#n.points,0);eq(n.pending,nil)
end)
test("unload during ComputeAsync discards its result",function()
    local n,c,h,r,s=world();scene.wall=true
    scene.computeHook=function()n:stop(h,r,"UNLOAD");n.closed=true end
    n:tick(v(300,3,0),c,h,r,10,{},s)
    eq(n.desiredPoint,nil);eq(n.pending,nil)
end)
test("stale tap release cannot release a newly owned key",function()
    local n=world();n:tap("X");local old=timers[1]
    n:releaseKeys();n:hold("X",true);old();eq(n.held.X,true)
end)
test("native-key steering holds a diagonal without world Move writes",function()
    local n,c,h,r,s=world();n.preferredStrategy="KEY"
    n:tick(v(120,3,-120),c,h,r,10,{},s);n:drive()
    eq(h.writes,0);assert(keys.W and keys.D);eq(n.lastMode,"NATIVE_KEYS")
end)
test("nearby player does not stop an otherwise valid travel route",function()
    local n,c,h,r,s=world();n:tick(v(350,3,0),c,h,r,10,{},s)
    eq(n:tick(v(350,3,0),c,h,r,11,{v(4,3,0)},s),"MOVING")
    assert(n.desiredPoint)
end)
test("unstreamed ground retries are bounded and do not produce movement",function()
    local n,c,h,r,s=world();scene.missing=true;local result
    for i=0,20,2 do result=n:tick(v(300,3,0),c,h,r,10+i,{},s);if result=="STUCK"then break end end
    eq(result,"STUCK");eq(n.desiredPoint,nil)
end)
test("body sweep catches an off-centre tree that centre-line steering could miss",function()
    local n,c,h,r,s,w=world()
    CFrame={lookAt=function(from,to)return {Position=from,LookVector=(to-from).Unit}end}
    function w:Blockcast(cf,size,dir)return {Instance={CanCollide=true},Position=v(12,3,2)}end
    n.bodyHeight=3;n.bodyLength=6;n.clearance=3.6
    eq(n:bodyClear(r.Position,v(30,3,0),c),false)
end)
test("initial tree overlap selects an outward local detour in about a second",function()
    local n,c,h,r,s,w=world()
    OverlapParams={new=function()return {}end}
    CFrame={lookAt=function(from,to)return {Position=from,LookVector=(to-from).Unit}end}
    local trunk={CanCollide=true,Position=v(5,3,0)}
    function w:GetPartsInPart()return {trunk}end
    function w:Blockcast()return nil end -- native sweeps omit initial overlap
    n:tick(v(300,3,0),c,h,r,10,{},s)
    n:tick(v(300,3,0),c,h,r,11.1,{},s)
    assert((n.obstacleRecoveries or 0)>0,"No detour: "..tostring(n.lastReason).." / "..tostring(n.lastFailure).." / "..tostring(n.overlapParts and #n.overlapParts));assert(math.abs(n.desiredPoint.Z)>3)
    assert(n.desiredPoint.X<0,"Recovery must move outward, not push into the tree")
end)
test("tall canopy is not selected as a ground waypoint",function()
    local n,c,h,r,s,w=world()
    Enum.RaycastFilterType.Include=2
    function w:Raycast(origin,dir,params)
        if params.FilterType==Enum.RaycastFilterType.Include then return {Position=v(origin.X,0,origin.Z),Normal={Y=1},Material="Grass",Instance=self.Terrain}end
        return {Position=v(origin.X,42,origin.Z),Normal={Y=1},Material="Wood",Instance={CanCollide=true}}
    end
    local p=n:surface(v(50,3,0),c,true);eq(p.Y,2.5)
end)
test("standing against an ineffective route does not wait thirty seconds",function()
    local n,c,h,r,s=world();local result
    for i=0,50 do result=n:tick(v(300,3,0),c,h,r,10+i*.2,{},s);if result=="STUCK"then break end end
    eq(result,"STUCK");assert(n.lastAt<20)
end)
test("prey following uses ordinary analog movement to match approach speed",function()
    local n,c,h,r,s=world();s.moveScale=.4
    n:tick(v(100,3,0),c,h,r,10,{},s);n:drive()
    assert(math.abs(h.MoveDirection.Magnitude-.4)<.001)
end)
test("straight path mesh waypoints share a longer steering horizon",function()
    local n,c,h,r,s,w=world();scene.wall=true
    scene.path={}
    for x=16,112,16 do table.insert(scene.path,{Position=v(x,3,0)})end
    scene.computeHook=function()scene.wall=false end
    n:tick(v(350,3,0),c,h,r,10,{},s)
    assert(n.desiredPoint.X>=80,"Horizon "..tostring(n.desiredPoint.X).." index "..tostring(n.index).." stage "..tostring(n.lastReason))
    s.hudSprint=true;r.Position=v(8,3,0);n:tick(v(350,3,0),c,h,r,10.3,{},s)
    eq(n.gait,"BURST")
end)
test("a low analog following scale still issues a digital steering direction",function()
    local n,c,h,r,s=world();n.preferredStrategy="KEY";s.moveScale=.15
    n:tick(v(80,3,-80),c,h,r,10,{},s);n:drive()
    assert(keys.W and keys.D);eq(h.writes,0)
end)
test("a new goal clears the previous obstacle detour hold",function()
    local n,c,h,r,s=world();n.detourUntil=100;n.lastObstacleProbe=100
    n:tick(v(350,3,0),c,h,r,10,{},s)
    assert(n.desiredPoint);eq(n.detourUntil,nil);eq(n.lastObstacleProbe,nil)
end)
print(string.format("AMBER_NAV_RESULT total=%d passed=%d failed=%d",total,passed,total-passed))
assert(total==passed,"Navigation regression failure")
