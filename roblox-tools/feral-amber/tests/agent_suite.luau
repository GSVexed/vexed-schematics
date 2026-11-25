local Planner=assert(loadstring(PLANNER_SRC,"=amber_planner"))()
local Agent=assert(loadstring(AGENT_SRC,"=amber_agent"))()
local total,passed=0,0
local function eq(a,b,msg) assert(a==b,(msg or "compare")..": got "..tostring(a).." expected "..tostring(b)) end
local function test(name,fn)
    total+=1
    local ok,why=pcall(fn)
    if ok then passed+=1;print("PASS "..name) else print("FAIL "..name.." : "..tostring(why)) end
end
local function world()
    local w={moves={},stops={},feeds={},bites=0,hex={},preyMode=false}
    w.state={alive=true,position={x=0,z=0},pack=9,species="Bear",
        coat="Spirit Bear",healthFraction=1,hunger=85,thirst=90,
        players={},amber=100,claimRadius=17}
    w.hex={{key="A",center={x=60,z=0},owner=nil,pay=5,hold=nil},
        {key="B",center={x=230,z=0},owner=9,pay=5,hold=.4}}
    function w:snapshot(now)
        local s=table.clone(self.state)
        s.now=now
        return s
    end
    function w:territories() return self.hex end
    function w:territory(key)
        for _,hex in ipairs(self.hex) do if hex.key==key then return hex end end
    end
    function w:territorySpot(key) local h=self:territory(key);return h and h.center end
    function w:move(to,s)
        table.insert(self.moves,{to=to,from=s.position})
        return "MOVING"
    end
    function w:stop(why) table.insert(self.stops,why) end
    function w:water() return {x=20,z=20} end
    function w:feed(s,kind) table.insert(self.feeds,kind);return true end
    function w:checkPrey(prey) return prey end
    function w:prey()
        if self.preyMode then return {position={x=6,z=0},attackRange=9} end
    end
    function w:bite() self.bites+=1;return true end
    return w,Agent.new(Planner,w)
end
test("Spirit Bear is Bear species with coat shown only as metadata",function()
    local w,a=world()
    a:setEnabled(true);a:tick(10)
    local status=a:status()
    eq(status.species,"Bear");eq(status.coat,"Spirit Bear")
    eq(status.phase,"TRAVEL");assert(#w.moves>0)
end)
test("all species use same core planner not a Bear-only gate",function()
    for _,species in ipairs({"Bear","Wolf","Tiger","Cobra","SaltwaterCrocodile","BaldEagle","Turtle"}) do
        local w,a=world();w.state.species=species;w.state.coat=nil
        a:setEnabled(true);a:tick(15)
        eq(a:status().phase,"TRAVEL")
    end
end)
test("disabled autopilot makes no movement or hunts",function()
    local w,a=world();a:tick(10);eq(#w.moves,0)
    a:setEnabled(false);a:tick(11);eq(a:status().phase,"OFF")
end)
test("replicated owner verifies claim before reporting success",function()
    local w,a=world();a:setEnabled(true);a:tick(10)
    local key=a.goal.key
    eq(a.claimed,0);w:territory(key).owner=9
    a:tick(11);eq(a.claimed,1);eq(a.goal,nil)
end)
test("replicated hold verifies rescent before counting it",function()
    local w,a=world();w.hex={w.hex[2]}
    a:setEnabled(true);a:tick(10)
    eq(a.goal.detail.kind,"SCENT");eq(a.scented,0)
    w.hex[1].hold=.98;a:tick(11)
    eq(a.scented,1);eq(a.goal,nil)
end)
test("thirst interrupt cancels current claim and moves toward natural water",function()
    local w,a=world();a:setEnabled(true);a:tick(10)
    w.state.thirst=13;a:tick(11)
    eq(a.goal.kind,"DRINK");eq(a:status().phase,"TRAVEL_WATER")
end)
test("native E requested only when game reports drinking eligibility",function()
    local w,a=world();w.state.thirst=10
    a:setEnabled(true);a:tick(10);eq(#w.feeds,0)
    w.state.feedCan="drink";a:tick(11)
    eq(#w.feeds,1);eq(w.feeds[1],"drink")
end)
test("successful drinking requires actual thirst increase",function()
    local w,a=world();w.state.thirst=10;w.state.feedCan="drink"
    a:setEnabled(true);a:tick(10)
    eq(a.feeds,0)
    w.state.thirst=20;a:tick(11)
    eq(a.feeds,1)
end)
test("low health pauses movement without claiming fabricated healing",function()
    local w,a=world();w.state.healthFraction=.19
    a:setEnabled(true);a:tick(10);eq(a:status().phase,"RECOVER")
    eq(#w.moves,0)
end)
test("manual input pauses movement and cancels no owned server attribute",function()
    local w,a=world();w.state.manualInput=true
    a:setEnabled(true);a:tick(10)
    eq(a:status().phase,"PAUSED");eq(#w.moves,0)
end)
test("nearby real player stops route",function()
    local w,a=world();w.state.players={{x=10,z=0}}
    a:setEnabled(true);a:tick(10)
    eq(a:status().phase,"PAUSED");eq(#w.moves,0)
end)
test("NPC hunting is native-click only and never a player attack",function()
    local w,a=world();w.state.hunger=12;w.preyMode=true
    a:setEnabled(true);a:tick(10)
    eq(a:status().phase,"HUNT_ATTACK")
    eq(w.bites,1)
    eq(a.hunts,0)
end)
test("old client cannot claim amber without observed resource increase",function()
    local w,a=world();a:setEnabled(true);a:tick(10)
    eq(a.earned,0);w.state.amber=115;a:tick(11)
    eq(a.earned,15)
    w.state.amber=107;a:tick(12)
    eq(a.earned,15)
end)
test("missing pack pauses all farming and releases movement",function()
    local w,a=world();w.state.pack=nil;a:setEnabled(true);a:tick(10)
    eq(a:status().phase,"WAIT");eq(#w.moves,0)
end)
test("missing terrain triggers bounded retry and cooldown",function()
    local w,a=world();w.territorySpot=function()return nil end
    a:setEnabled(true);a:tick(10)
    eq(a:status().kind,"NONE");assert(a.cooldown[a.lastTerritoryKey]>10)
end)
print(string.format("AMBER_AGENT_RESULT total=%d passed=%d failed=%d",total,passed,total-passed))
assert(total==passed,"Amber agent tests failed")
