local Care=assert(loadstring(CARE_SRC))()
local Planner=assert(loadstring(PLANNER_SRC))()
local Hunt=assert(loadstring(HUNT_SRC))()
local Agent=assert(loadstring(AGENT_SRC))()
local total,passed=0,0
local function eq(a,b)assert(a==b,tostring(a).." != "..tostring(b))end
local function test(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then passed+=1;print("PASS "..name)else print("FAIL "..name.." "..tostring(why))end
end
local function world()
    local b={state={alive=true,char={},species="Bear",coat="Spirit Bear",pack=2,
        biome="WolfValley",position={x=0,z=0},healthFraction=1,hunger=80,thirst=80,players={}},
        inputs=0,moves=0,cancels=0,waterFailed=0,hex={key="H",center={x=250,z=0},owner=nil}}
    function b:snapshot()return table.clone(self.state)end
    function b:territories()return {self.hex}end
    function b:territory()return self.hex end
    function b:territorySpot()return self.hex.center end
    function b:advanceSpot()end
    function b:move(p,s,o)self.moves+=1;self.options=o;return "MOVING"end
    function b:stop()end
    function b:water()return {x=12,z=0}end
    function b:avoidWater()self.waterFailed+=1 end
    function b:feed()self.inputs+=1;return self.feedUnavailable~=true end
    function b:cancelFeed()self.cancels+=1;return true end
    function b:prey()return nil end
    local a=Agent.new(Planner,b,Hunt,Care);a:setEnabled(true)
    return b,a
end
test("swimming interrupts neither territory travel nor survival planning",function()
    local b,a=world();b.state.swimming=true;a:tick(10)
    eq(a.phase,"TRAVEL");eq(b.moves,1)
end)
test("drinking remains latched after crossing its trigger threshold",function()
    local b,a=world();b.state.thirst=40;b.state.feedCan="drink";a:tick(10)
    b.state.thirst=50;a:tick(11);eq(a.goal.kind,"DRINK");eq(a.feeds,0);eq(b.inputs,1)
end)
test("eating remains latched after crossing its trigger threshold",function()
    local b,a=world();b.state.hunger=40;b.state.feedCan="eat";a:tick(10)
    b.state.hunger=52;a:tick(11);eq(a.goal.kind,"EAT");eq(a.feeds,0);eq(b.inputs,1)
end)
test("native approach state prevents repeated E from cancelling a session",function()
    local b,a=world();b.state.thirst=30;b.state.feedCan="drink";a:tick(10)
    b.state.nativeFeedMode="drink";b.state.feedMode=false
    for t=11,14 do b.state.thirst+=2;a:tick(t)end
    eq(b.inputs,1);eq(a.feeds,0);eq(a.phase,"DRINKING")
end)
test("a positive input return without needs progress cannot count a meal",function()
    local b,a=world();b.state.hunger=20;b.state.feedCan="eat";a:tick(10)
    for t=11,25 do a:tick(t)end;eq(a.feeds,0);assert(b.inputs<=9);assert(b.waterFailed>=0)
end)
test("unavailable E is bounded and waits between retries",function()
    local b,a=world();b.feedUnavailable=true;b.state.hunger=20;b.state.feedCan="eat";a:tick(10)
    a:tick(10.5);eq(b.inputs,1);a:tick(11);eq(b.inputs,2);a:tick(12);eq(a.failures,1)
end)
test("care preserves and resumes the same suspended territory objective",function()
    local b,a=world();a:tick(10);local territory=a.goal
    b.state.thirst=25;a:tick(11);eq(a.suspended,territory)
    b.state.feedCan="drink";a:tick(12);b.state.thirst=100;a:tick(13)
    eq(a.goal,territory);eq(a.suspended,nil);eq(a.feeds,1);eq(a.phase,"RESUME")
end)
test("care target waits for native feeding to end before resuming movement",function()
    local b,a=world();b.state.thirst=25;b.state.feedCan="drink";a:tick(10)
    b.state.thirst=100;b.state.nativeFeedMode="drink";a:tick(11)
    eq(a.phase,"DRINKING");eq(a.feeds,0);eq(b.cancels,1)
    a:tick(12);eq(b.cancels,1)
    b.state.nativeFeedMode=nil;a:tick(13);eq(a.feeds,1)
end)
test("animal replacement discards suspended objectives and native feed intent",function()
    local b,a=world();a:tick(10);b.state.thirst=20;a:tick(11);assert(a.suspended)
    b.state.char={};b.state.hunger=90;b.state.thirst=90;a:tick(12)
    eq(a.suspended,nil);eq(a.goal.kind,"TERRITORY")
end)
test("low health excludes NPC hunts even when hungry",function()
    local b,a=world();b.state.hunger=10;b.state.healthFraction=.3
    a:tick(10);eq(a.phase,"WAIT_FOOD");eq(b.moves,0)
end)
test("missing water cannot retain a previous movement command",function()
    local b,a=world();a:tick(10);b.state.thirst=12;b.water=function()return nil end
    a:tick(11);eq(a.phase,"WAIT_WATER");eq(a.goal.kind,"DRINK")
end)
test("no prompt at a water destination blacklists that access and searches again",function()
    local b,a=world();b.state.thirst=20;b.state.position={x=12,z=0}
    a:tick(10);a:tick(16);eq(b.waterFailed,1);eq(a.goal.location,nil)
end)
test("manual pause does not consume the territory interaction timeout",function()
    local b,a=world();b.state.position=b.hex.center;a:tick(10)
    b.state.manualInput=true;a:tick(11);b.state.manualInput=false;a:tick(200)
    eq(a.failures,0);eq(a.phase,"CLAIMING")
end)
test("native claim progress is observed without fabricating ownership",function()
    local b,a=world();b.state.position=b.hex.center;b.hex.by=2;b.hex.prog=.1;a:tick(10)
    b.hex.prog=.3;a:tick(12);eq(a.claimed,0);assert(a.goal.nativeStarted)
end)
test("STOP clears suspended care and cancels owned pending inputs",function()
    local b,a=world();a:tick(10);b.state.hunger=10;a:tick(11)
    a:setEnabled(false);eq(a.goal,nil);eq(a.suspended,nil);eq(a.phase,"OFF")
end)
test("STOP cancels an owned native approach before WolfFeed first appears",function()
    local b,a=world();b.state.hunger=20;b.state.feedCan="eat";a:tick(10)
    eq(b.state.feedMode,nil);a:setEnabled(false);eq(b.cancels,1)
end)
test("an unstarted private feed approach retains objective ownership",function()
    local b,a=world();b.state.hunger=20;b.state.feedCan="eat";a:tick(10)
    b.state.thirst=10;a:tick(11);eq(a.goal.kind,"EAT");eq(b.inputs,1)
end)
test("manual movement mid-drink restarts at the same water without the old 14-second latch",function()
    local b,a=world();b.state.thirst=25;b.state.feedCan="drink";b.state.nativeFeedKnown=true
    a:tick(10);eq(b.inputs,1)
    b.state.nativeFeedMode="drink";b.state.thirst=35;a:tick(10.3)
    b.state.manualInput=true;b.state.nativeFeedMode=nil;a:tick(10.6)
    b.state.manualInput=false;a:tick(11.1)
    eq(a.goal.kind,"DRINK");eq(b.inputs,2);eq(a.failures,0)
end)
test("a native drink session ending below full immediately becomes eligible to restart",function()
    local b,a=world();b.state.thirst=30;b.state.feedCan="drink";b.state.nativeFeedKnown=true
    a:tick(10);b.state.nativeFeedMode="drink";b.state.thirst=70;a:tick(10.3)
    b.state.nativeFeedMode=nil;a:tick(10.6);a:tick(10.9)
    eq(a.goal.kind,"DRINK");eq(b.inputs,2);eq(a.feeds,0)
end)
test("drinking goes to full rather than ending at the old care threshold",function()
    local b,a=world();b.state.thirst=30;b.state.feedCan="drink";a:tick(10)
    b.state.thirst=82;a:tick(11);eq(a.feeds,0);eq(a.goal.kind,"DRINK")
    b.state.thirst=100;a:tick(12);eq(a.feeds,1)
end)
test("an ordinary water opportunity interrupts travel and fills thirst",function()
    local b,a=world();b.state.thirst=81;b.state.feedCan="drink";a:tick(10)
    eq(a.goal.kind,"DRINK");eq(b.inputs,1)
    b.state.thirst=100;a:tick(11);eq(a.feeds,1)
end)
test("non-pack occupation defers a target and travels to another in the same tick",function()
    local b,a=world();b.hex={key="A",center={x=100,z=0},owner=nil}
    local second={key="B",center={x=0,z=200},owner=nil}
    function b:territories()return {self.hex,second}end
    function b:territory(key)return key=="A" and self.hex or second end
    function b:territorySpot(key)return self:territory(key).center end
    a:tick(10);eq(a.goal.key,"A")
    b.state.contested={A=1};a:tick(10.3)
    eq(a.goal.key,"B");eq(a.phase,"TRAVEL");assert(a.cooldown.A>10.3)
end)
test("near-complete native claim finishes before routine food care",function()
    local b,a=world();b.state.position=b.hex.center;b.hex.by=2;b.hex.prog=.8
    a:tick(10);b.state.hunger=35;b.hex.prog=.9;a:tick(10.5)
    eq(a.goal.kind,"TERRITORY");eq(a.phase,"CLAIMING")
    b.hex.owner=2;b.hex.prog=.97;a:tick(11);eq(a.claimed,0);eq(a.goal.kind,"TERRITORY")
    b.hex.prog=1;a:tick(11.5);eq(a.phase,"VERIFY_TERRITORY")
    a:tick(12.1);eq(a.claimed,1)
end)
test("freshly owned territory is observed across two samples before departure",function()
    local b,a=world();a:tick(10);b.hex.owner=2;a:tick(11)
    eq(a.claimed,0);eq(a.phase,"VERIFY_TERRITORY");a:tick(11.6);eq(a.claimed,1)
end)
test("a stalled claim tries another position within seconds",function()
    local b,a=world();b.state.position=b.hex.center;a:tick(10)
    a:tick(13.4);eq(a.phase,"REPOSITION");eq(a.failures,0)
end)
test("a full drink cannot retain an unconfirmed owned native release forever",function()
    local b,a=world();b.state.thirst=25;b.state.feedCan="drink";a:tick(10)
    b.state.thirst=100;b.state.nativeFeedMode="drink";a:tick(11);a:tick(13.3)
    eq(a.failures,1);eq(a.feeds,0);eq(a.goal,nil);eq(b.cancels,1)
end)
test("missing water with an available search route keeps moving and looking",function()
    local b,a=world();b.state.thirst=25;b.water=function()return nil end
    b.resourceSearch=function()return {x=100,z=100}end
    a:tick(10);eq(a.phase,"SEARCH_WATER");eq(b.moves,1);eq(b.options.navKey,"WATER_SCOUT")
end)
print(string.format("AMBER_CARE_RESULT total=%d passed=%d failed=%d",total,passed,total-passed))
assert(total==passed,"Care transition regressions failed")
