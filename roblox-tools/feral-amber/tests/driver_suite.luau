require=function(m)return m.ModuleValue end
local Driver=assert(loadstring(DRIVER_SRC))()
local total,passed=0,0
local function test(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then passed+=1;print("PASS "..name)else print("FAIL "..name.." "..tostring(why))end
end
local function eq(a,b)assert(a==b,tostring(a).." != "..tostring(b))end
local function world()
    local desired={x=1,z=0};local zero={x=0,z=0}
    local controls={calls=0}
    controls.moveFunction=function(p,dir,relative)controls.calls+=1;controls.direction=dir;controls.relative=relative;return "native"end
    local mod={ModuleValue={GetControls=function()return controls end}}
    local scripts={FindFirstChild=function(_,name)return name=="PlayerModule" and mod or nil end}
    local player={FindFirstChild=function()return scripts end}
    require=function(m)return m.ModuleValue end
    local n={desiredPoint={},steeringStrategy="WORLD",driveCalls=0}
    function n:direction()return desired end
    function n:stop()self.desiredPoint=nil;self.stopped=true end
    function n:drive()self.keyCalls=(self.keyCalls or 0)+1 end
    return player,n,controls,desired,zero
end
test("normal controls overwrite Heartbeat-only motion before native sampling",function()
    local p,n,c,d,z=world();c.direction=d
    c.moveFunction(p,z,true)
    eq(c.direction,z)
end)
test("PlayerModule supplies continuous direction before native WolfMove sampling",function()
    local p,n,c,d,z=world();local driver=Driver.new(p,n,function()return false end)
    assert(driver.method=="PLAYER_MODULE",driver.reason or driver.method)
    for _=1,90 do c.moveFunction(p,z,true);eq(c.direction,d);eq(c.relative,false)end
    eq(n.driveCalls,90);eq(driver.method,"PLAYER_MODULE")
end)
test("STOP immediately returns ordinary manual input to its original callback",function()
    local p,n,c,d,z=world();Driver.new(p,n,function()return false end)
    n.desiredPoint=nil;c.moveFunction(p,z,true);eq(c.direction,z);eq(c.relative,true)
end)
test("physical movement yields on that same PlayerModule frame",function()
    local p,n,c,d,z=world();Driver.new(p,n,function()return true end)
    c.moveFunction(p,z,true);eq(c.direction,z);assert(n.stopped)
end)
test("unload restores the exact previous moveFunction and is idempotent",function()
    local p,n,c=world();local original=c.moveFunction
    local driver=Driver.new(p,n);driver:close();driver:close()
    eq(c.moveFunction,original);assert(n.stopped)
end)
test("another callback owner is preserved during close",function()
    local p,n,c=world();local driver=Driver.new(p,n)
    local another=function()end;c.moveFunction=another;driver:close();eq(c.moveFunction,another)
end)
test("missing PlayerModule selects native keys instead of competing Heartbeat Move",function()
    local p,n=world();p.FindFirstChild=function()return nil end
    local d=Driver.new(p,n);eq(d.method,"NATIVE_KEYS");eq(n.preferredStrategy,"KEY")
    d:tick();eq(n.keyCalls,1)
end)
test("losing callback ownership selects fallback without replacing its new owner",function()
    local p,n,c=world();local d=Driver.new(p,n);local replacement=function()end;c.moveFunction=replacement
    d:tick();eq(n.steeringStrategy,"KEY");eq(c.moveFunction,replacement)
end)
test("the captured StarterPlayer layout works without legacy GetControls",function()
    local p,n,c=world()
    local child={ModuleValue=c}
    local module={ModuleValue=true,FindFirstChild=function(_,name)return name=="ControlModule" and child or nil end}
    local starter={FindFirstChild=function(_,name)return name=="PlayerModule" and module or nil end}
    game={GetService=function(_,name)return name=="StarterPlayer" and starter or nil end}
    p.FindFirstChild=function()return nil end
    local d=Driver.new(p,n);eq(d.method,"PLAYER_MODULE");eq(d.path,"STARTER_PLAYER")
    d:close()
end)
test("a frozen controls table selects keys without leaving a partial callback",function()
    local p,n,c=world();table.freeze(c)
    local d=Driver.new(p,n);eq(d.method,"NATIVE_KEYS");eq(d.controls,nil);assert(d.reason)
end)
print(string.format("AMBER_DRIVER_RESULT total=%d passed=%d failed=%d",total,passed,total-passed))
assert(total==passed,"Driver regression failed")
