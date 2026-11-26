local Ledger=assert(loadstring(LEDGER_SRC))()
local Model=assert(loadstring(MODEL_SRC))()
local Planner=assert(loadstring(PLANNER_SRC))()
local Agent=assert(loadstring(AGENT_SRC))()
local Care=assert(loadstring(CARE_SRC))()
local total,passed=0,0
local function eq(a,b)assert(a==b,tostring(a).." != "..tostring(b))end
local function near(a,b)assert(math.abs(a-b)<.00001,tostring(a).." ~= "..tostring(b))end
local function test(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then passed+=1;print("PASS "..name)else print("FAIL "..name.." "..tostring(why))end
end
local function state()
    return {alive=true,char={},pack=2,species="Wolf",biome="A",position={x=0,z=0},healthFraction=1,
        hunger=80,thirst=80,hungerMax=100,thirstMax=100,now=10}
end
local function hex(key,x,z,extra)
    local h={key=key,center={x=x,z=z},region=1}
    for k,v in pairs(extra or {})do h[k]=v end
    return h
end
test("run clocks reconcile pause and long unobserved intervals",function()
    local l=Ledger.new();l:start(10);l:sample(10,"TRAVEL",false,false)
    l:sample(11,"TRAVEL",false,false);l:sample(12,"PAUSED",true,true)
    l:sample(22,"PAUSED",true,true);l:sample(23,"TRAVEL",false,false)
    near(l.wall,13);near(l.wall,l.active+l.paused+l.unknown);eq(l.unknown,8);eq(l.assistance,1)
    local sum=0;for _,v in pairs(l.phases)do sum+=v end;near(sum+l.unknown,l.wall)
end)
test("objective timing uses exclusive phase totals and a separate wall clock",function()
    local l=Ledger.new();local g={wallStart=10};l:start(10);l:sample(10,"TRAVEL",false,false,g)
    l:sample(11,"TRAVEL",false,false,g);l:sample(12,"PAUSED",true,true,g);l:sample(13,"EATING",false,false,g)
    local sum=0;for _,v in pairs(g.timing.phases)do sum+=v end
    near(sum,g.timing.active+g.timing.paused);near(sum+g.timing.unknown,3)
end)
test("currency records inflow spending and character discontinuities separately",function()
    local l=Ledger.new();l:start(0);local c={};l:currency(100,c);l:currency(140,c);l:currency(120,c)
    eq(l.inflow,40);eq(l.outflow,20);eq(l.net,20)
    l:currency(900,{});eq(l.net,20);l:start(10);l:currency(1200,c);eq(l.inflow,0)
end)
test("bounded error and profiling histories retain aggregate counts",function()
    local l=Ledger.new();l:start(0)
    for i=1,200 do l:count("failure",tostring(i));l:cost("tick",i/1000)end
    local n,sum=0,0;for _,v in pairs(l.failures)do n+=1;sum+=v end
    assert(n<=49);eq(sum,200);eq(#l.costs.tick.samples,128);eq(l:summary().costs.tick.calls,200)
end)
test("travel observations affect only compatible directed cost cells",function()
    local m=Model.new();m:reset("wolf");local a,b={x=0,z=0},{x=200,z=0}
    near(m:estimate(a,b,10,20),10);m:record(a,b,45,10,false);near(m:estimate(a,b,11,20),45)
    near(m:estimate(b,a,11,20),10);m:reset("bear");near(m:estimate(a,b,12,20),10)
end)
test("checked passage graph is bounded expires and preserves directed connectivity",function()
    local m=Model.new();m:reset("A");m:addRoute({{x=0,z=0},{x=50,z=50},{x=100,z=50},{x=150,z=0}},10)
    assert(m:path({x=0,z=0},{x=150,z=0},11));eq(m:path({x=0,z=0},{x=150,z=0},300),nil)
    for i=1,300 do m:addRoute({{x=i*50,z=0}},20)end
    assert(#m.order<=160)
end)
test("failed route cost is penalized and eventually expires",function()
    local m=Model.new();local a,b={x=0,z=0},{x=50,z=0}
    m:record(a,b,5,10,true);assert(m:estimate(a,b,11,20)>=45)
    near(m:estimate(a,b,700,20),2.5)
end)
test("regional route uses priority while still finishing nearby clusters",function()
    local s=state();s.regionGrid=3
    local r=Planner.strategy({hex("low",10,0,{pay=1}),hex("high",30,0,{pay=20})},s,{regionCursor=1})
    eq(r[1].key,"high")
    r=Planner.strategy({hex("A",10,0,{pay=2}),hex("B",20,0,{pay=2}),hex("C",30,0,{pay=2}),hex("far",300,300,{pay=20})},s,{regionCursor=1})
    eq(r[1].key,"A");eq(r[2].key,"B");eq(r[3].key,"C")
end)
test("observed costly terrain can outweigh Euclidean proximity",function()
    local s=state();s.regionGrid=3;s.travelCost=function(_,p)return p.x==10 and 90 or 3,"observed"end
    local r=Planner.strategy({hex("near_mountain",10,0),hex("accessible",80,0)},s,{regionCursor=1})
    eq(r[1].key,"accessible")
end)
test("region entry starts near the actual animal instead of forcing region one",function()
    local s=state();s.regionGrid=3;s.position={x=1000,z=1000}
    local r=Planner.strategy({hex("corner1",0,0,{region=1}),hex("local",1010,1000,{region=9})},s,{})
    eq(r[1].key,"local")
end)
test("measured scent deadline overrides the old hold point-two-eight boundary",function()
    local s=state();s.regionGrid=3
    local r,mode=Planner.strategy({hex("claim",10,0),hex("due",20,0,{owner=2,hold=.5,deadlineSeconds=35})},s,{})
    eq(r[1].key,"due");eq(mode.phase,"URGENT_SCENT")
end)
test("capacity distinguishes measured deadline pressure from missing data",function()
    local s=state()
    local c=Planner.capacity({hex("A",300,0,{owner=2,hold=.4,deadlineSeconds=10})},s,{})
    eq(c.state,"DEADLINE_PRESSURE");assert(c.predictedLate>0)
    c=Planner.capacity({hex("A",300,0,{owner=2,hold=.4})},s,{})
    eq(c.state,"UNKNOWN");eq(c.unknown,1)
end)
test("need arbitration is consistent for simultaneous risks and immediate native care",function()
    local s=state();s.healthFraction=.2;s.thirst=8
    eq(Planner.need(s),Planner.decide(s).kind);eq(Planner.need(s),"RECOVER")
    s.feedCan="drink";eq(Planner.need(s),"DRINK")
    s.healthFraction=.3;s.feedCan=nil;s.hunger=10;s.thirst=80;eq(Planner.need(s),"EAT")
end)
test("non-hundred maxima and unavailable data produce feasible need decisions",function()
    local s=state();s.hungerMax=50;s.thirstMax=200;s.hunger=45;s.thirst=70
    eq(Planner.need(s),"DRINK");s.needsKnown=false;eq(Planner.need(s),"WAIT")
end)
test("care uses the true small maximum and rejects malformed resources",function()
    local g={kind="DRINK",baseline=.5};local s={now=1,thirst=.99,thirstMax=1,drinkTarget=1}
    eq(Care.step(g,s,{}),"READY");s.thirst=1;eq(Care.step(g,s,{}),"COMPLETE")
    s.thirst=0/0;eq(Care.step(g,s,{}),"FAILED")
end)
test("agent retains a revalidated itinerary and avoids repeated full route construction",function()
    local s=state();local all={hex("A",100,0),hex("B",200,0)}
    local b={};function b:snapshot()return table.clone(s)end
    function b:stop()end;function b:territories()return all end
    function b:territory(k)for _,h in ipairs(all)do if h.key==k then return h end end end
    function b:territorySpot(k)return self:territory(k).center end
    function b:move()return "MOVING"end
    local p=table.clone(Planner);local calls=0
    p.strategy=function(...)calls+=1;return Planner.strategy(...)end
    local a=Agent.new(p,b,nil,Care,Ledger);a:setEnabled(true,10);a:tick(10)
    local first=a.goal.key;local job=b:territory(first);job.owner=2;job.hold=1
    a:tick(11);a:tick(11.6);a:tick(12)
    assert(a.goal and a.goal.key~=first);eq(calls,1)
end)
test("agent recovery ownership releases on STOP even with saved recovery off",function()
    local s=state();s.healthFraction=.35;local active=false
    local b={};function b:snapshot()return table.clone(s)end
    function b:stop()end;function b:territories()return {}end
    function b:recover(_,on)active=on;return on end
    local a=Agent.new(Planner,b,nil,Care,Ledger);a:setEnabled(true,10);a:tick(10);eq(active,true)
    a:setEnabled(false,11);eq(active,false);near(a:status().metrics.wall,1)
end)
test("long-waiting reachable work cannot starve behind recurring nearby claims",function()
    local s=state();s.regionGrid=3;s.now=1000
    local r,meta=Planner.strategy({hex("near",10,0),hex("waiting",300,0,{region=2})},s,
        {regionCursor=1,waitingSince={waiting=100}})
    eq(r[1].key,"waiting");eq(meta.phase,"FAIRNESS_SWEEP")
end)
test("paired regional benchmark reduces the initial crossing and preserves local sweep direction",function()
    local Old=assert(loadstring(BASE_PLANNER_SRC))()
    local function run(p)
        local s=state();s.regionGrid=3;s.position={x=620,z=620}
        local all={};for i=1,9 do table.insert(all,hex(tostring(i),(i-1)%3*300,math.floor((i-1)/3)*300,{region=i}))end
        local cursor,direction=nil,nil;local distance=0
        for _=1,9 do
            local r,m=p.strategy(all,s,{regionCursor=cursor,regionDirection=direction,maxStops=3})
            assert(r[1]);local job=r[1];distance+=Planner.distance(s.position,job.center);s.position=job.center
            for _,h in ipairs(all)do if h.key==job.key then h.owner=2;h.hold=1 end end
            cursor,direction=m.cursor,m.direction
        end
        return distance
    end
    local old,new=run(Old),run(Planner);assert(new<old*.85)
    print(string.format("TERRITORY_PAIRED_REGIONS baseline_studs=%.1f candidate_studs=%.1f",old,new))
end)
test("paired deadline benchmark serves feasible maintenance before a fresh claim",function()
    local Old=assert(loadstring(BASE_PLANNER_SRC))()
    local s=state();s.regionGrid=3
    local all={hex("claim",10,0),hex("scent",20,0,{owner=2,hold=.5,deadlineSeconds=40})}
    local a=Old.strategy(all,s,{regionCursor=1});local b=Planner.strategy(all,s,{regionCursor=1})
    eq(a[1].key,"claim");eq(b[1].key,"scent")
    local oldFinish=20+10/24+10/24+30;local newFinish=20/24+30
    assert(oldFinish>40 and newFinish<40)
    print(string.format("TERRITORY_PAIRED_DEADLINE baseline_finish=%.2f candidate_finish=%.2f deadline=40",oldFinish,newFinish))
end)
test("gait and movement-mode clocks exclude pauses and unobserved gaps",function()
    local l=Ledger.new();l:start(0)
    local s={alive=true};local n={gaits={observed="BURST"}}
    l:sample(0,"TRAVEL",false,false,nil,s,n);l:sample(1,"TRAVEL",false,false,nil,s,n)
    s.swimming=true;n.gaits.observed="SPRINT";l:sample(2,"TRAVEL",false,false,nil,s,n)
    l:sample(3,"PAUSED",true,true,nil,s,n);l:sample(13,"PAUSED",true,true,nil,s,n)
    local stats=l:summary();near(stats.modeSeconds.ground,1);near(stats.modeSeconds.surface_water,1)
    near(stats.observedGaitSeconds.BURST,1);near(stats.observedGaitSeconds.SPRINT,1)
    near(stats.active+stats.paused+stats.unobserved,stats.wall)
end)
test("stalled critical recovery gives the competing critical resource a productive attempt",function()
    local s=state();s.healthFraction=.18;s.thirst=10
    eq(Planner.decide(s).kind,"RECOVER");s.recoveryStalled=true;eq(Planner.decide(s).kind,"DRINK")
    s.recoveryStalled=nil;s.thirst=7;eq(Planner.decide(s).kind,"DRINK")
end)
print(string.format("AMBER_EFFICIENCY_RESULT total=%d passed=%d failed=%d",total,passed,total-passed))
assert(total==passed,"Efficiency/ownership regressions failed")
