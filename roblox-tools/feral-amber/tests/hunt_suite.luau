local Hunt=assert(loadstring(HUNT_SRC))()
local total,passed=0,0
local function test(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then passed+=1;print("PASS "..name)else print("FAIL "..name.." "..tostring(why))end
end
local function eq(a,b)assert(a==b,tostring(a).." != "..tostring(b))end
local function world()
    local a={moves={},stops=0,bites=0,preyBlocked={}}
    local p={model={},position={x=30,z=0},health=80,hum={Health=80},velocity={x=9,z=0}}
    function a:prey()return p end
    function a:checkPrey(t)return t end
    function a:attackGeometry()return {valid=self.valid==true,inRange=self.inRange==true}end
    function a:bite()self.bites+=1;return true,"Requested"end
    function a:move(to,s,options)table.insert(self.moves,{to=to,options=options});return self.moveResult or "MOVING"end
    function a:stop()self.stops+=1 end
    local s={now=10,position={x=0,z=0},healthFraction=1}
    return a,Hunt.new(a),p,s
end
test("moving prey uses short interception and a stable moving-target identity",function()
    local a,h,p,s=world();h:tick(s)
    assert(a.moves[1].to.x>p.position.x);eq(a.moves[1].options.navKey,p.model)
    assert(a.moves[1].options.hunting and a.moves[1].options.movingTarget)
end)
test("being nearby but facing away keeps positioning rather than stopping",function()
    local a,h,p,s=world();p.position={x=5,z=0};a.inRange=true
    h:tick(s);eq(a.bites,0);assert(#a.moves>0);eq(a.stops,0)
end)
test("native attack input alone never counts as confirmed damage",function()
    local a,h,p,s=world();a.valid=true;p.position={x=6,z=0}
    local phase=h:tick(s);eq(phase,"HUNT_VERIFY");eq(h.attacks,1);eq(h.hits,0);eq(h.kills,0)
end)
test("missed attacks are observed and cause repositioning",function()
    local a,h,p,s=world();a.valid=true;p.position={x=6,z=0};h:tick(s)
    s.now=12;h:tick(s);eq(h.misses,1);eq(h.hits,0);assert(#a.moves>0)
end)
test("prey HP drop is recorded independently from an input return value",function()
    local a,h,p,s=world();a.valid=true;p.position={x=6,z=0};h:tick(s)
    s.now=10.8;p.health=62;p.hum.Health=62;h:tick(s)
    eq(h.hits,1);eq(h.kills,0);assert(h.lastResult:find("attribution unverified",1,true))
end)
test("HP zero transitions to corpse search without claiming a completed meal",function()
    local a,h,p,s=world();h:tick(s);p.hum.Health=0;s.now=11
    eq(h:tick(s),"PREY_DOWN");eq(h.kills,1);eq(h.target,nil);assert(h.corpse)
end)
test("pursuit continues while a moving prey attack is being verified",function()
    local a,h,p,s=world();a.valid=true;p.position={x=8,z=0}
    h:tick(s);local before=#a.moves
    p.position.x=13;s.now=10.4;h:tick(s)
    assert(#a.moves>before);eq(a.bites,1)
end)
test("faster escaping prey is abandoned and cooled down",function()
    local a,h,p,s=world();h:tick(s)
    p.position.x=150;s.now=23;eq(h:tick(s),"HUNT_REPLAN")
    eq(h.target,nil);assert(a.preyBlocked[p.model]>23)
end)
test("a blocked chase abandons the prey without an endless route loop",function()
    local a,h,p,s=world();a.moveResult="STUCK"
    eq(h:tick(s),"HUNT_REPLAN");eq(h.target,nil)
end)
test("native geometry being unavailable never creates a guessed attack",function()
    local a,h,p,s=world();a.attackGeometry=function()return nil end
    p.position={x=3,z=0};h:tick(s);eq(a.bites,0);assert(#a.moves>0)
end)
print(string.format("AMBER_HUNT_RESULT total=%d passed=%d failed=%d",total,passed,total-passed))
assert(total==passed,"Hunting regressions failed")
