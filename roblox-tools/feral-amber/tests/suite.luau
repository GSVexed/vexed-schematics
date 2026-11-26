local Planner=assert(loadstring(PLANNER_SRC,"=amber_planner"))()
local passed,total=0,0
local function eq(a,b,label) assert(a==b,(label or "equality").." got "..tostring(a).." expected "..tostring(b)) end
local function test(name,fn)
    total+=1
    local ok,reason=pcall(fn)
    if ok then passed+=1;print("PASS "..name) else print("FAIL "..name.." "..tostring(reason)) end
end
local function h(key,x,z,pay,owner,hold,extra)
    local xtra=extra or {}
    xtra.key=key;xtra.center={x=x,z=z};xtra.pay=pay;xtra.owner=owner;xtra.hold=hold
    return xtra
end
local function s()
    return {position={x=0,z=0},pack=5,now=200,unixNow=1795534100,players={},
        healthFraction=1,hunger=80,thirst=80}
end
test("not enough player or pack data never creates objectives",function()
    eq(#Planner.plan({h("H1",3,0,5,nil,nil)}, {position={x=0,z=0}},{}),0)
    eq(#Planner.plan({},s(),{}),0)
end)
test("fresh owned territory is omitted and faded owned one becomes SCENT",function()
    local state=s()
    eq(Planner.objective(h("A",5,0,5,5,.99),state,state.position),nil)
    local x=Planner.objective(h("B",10,0,5,5,.65),state,state.position)
    eq(x.kind,"SCENT")
end)
test("neutral hex is never a claim target",function()
    local state=s()
    eq(Planner.objective(h("A",5,0,5,nil,nil,{neutral=true}),state,state.position),nil)
end)
test("a progressing pack claim is preferred at the same distance",function()
    local state=s()
    local progressing=h("A",30,0,5,7,nil,{prog=.7,by=5})
    local fresh=h("B",30,0,5,nil,nil)
    local r=Planner.plan({fresh,progressing},state,{})
    eq(r[1].key,"A")
end)
test("higher Amber-value claim preferred at same distance",function()
    local state=s()
    local r=Planner.plan({h("LOW",-25,0,2.5,nil,nil),h("HIGH",25,0,5,nil,nil)},state,{})
    eq(r[1].key,"HIGH")
end)
test("nearby high yield beats distant duplicate yield",function()
    local state=s()
    local r=Planner.plan({h("D",900,0,5,nil,nil),h("N",25,0,5,nil,nil)},state,{})
    eq(r[1].key,"N")
end)
test("critical owned scent takes priority over nearby fresh claim",function()
    local state=s()
    local r=Planner.plan({h("A",30,0,5,5,.10),h("B",30,0,5,nil,nil)},state,{})
    eq(r[1].key,"A");eq(r[1].kind,"SCENT")
end)
test("player hazard on travel corridor filters target",function()
    local state=s();state.players={{x=80,z=0}}
    local r=Planner.plan({h("BAD",170,0,5,nil,nil),h("SAFE",0,200,5,nil,nil)},state,{avoidRadius=55,avoidPlayers=true})
    eq(r[1].key,"SAFE")
end)
test("temporary cooldown prevents repeatedly revisiting failed territory",function()
    local state=s()
    local r=Planner.plan({h("X",20,0,5,nil,nil),h("Y",50,0,2.5,nil,nil)},state,
        {blockedUntil={X=250}})
    eq(r[1].key,"Y")
end)
test("route visits unique objective keys with max stop bound",function()
    local state=s()
    local r=Planner.plan({h("A",20,0,5,nil,nil),h("B",40,0,5,nil,nil),h("C",60,0,5,nil,nil)},state,{maxStops=2})
    eq(#r,2);assert(r[1].key~=r[2].key)
end)
test("sticky active objective avoids changing destination every replan",function()
    local state=s();state.now=220
    local items={h("A",30,0,5,nil,nil),h("B",29,0,5,nil,nil)}
    local r=Planner.plan(items,state,{currentKey="A",currentStarted=200})
    eq(r[1].key,"A")
end)
test("unsafe malformed values are rejected and do not create invalid scores",function()
    local state=s()
    local x=Planner.objective(h("X",0/0,1,5,nil,nil),state,state.position,{})
    eq(x,nil)
end)
test("need arbitration prioritises health and thirst emergencies",function()
    local state=s()
    eq(Planner.need(state),"TERRITORY")
    state.hunger=10;eq(Planner.need(state),"EAT")
    state.thirst=9;eq(Planner.need(state),"DRINK")
    state.healthFraction=.2;eq(Planner.need(state),"RECOVER")
end)
test("missing need values do not trigger unsupportable food requests",function()
    local state=s();state.hunger=nil;state.thirst=nil
    -- Unknown needs must also stop optional territory acquisition. The old
    -- fallback avoided feeding but incorrectly treated unavailable data as safe.
    eq(Planner.need(state),"WAIT")
    state.hunger=80;eq(Planner.need(state),"WAIT")
    state.hunger=nil;state.thirst=80;eq(Planner.need(state),"WAIT")
end)
test("complete 71-hex map discovers every one of 69 eligible territories across route batches",function()
    local state=s()
    local hexes={}
    for i=1,71 do
        table.insert(hexes,h("H"..i,30*(i%9),38*math.floor(i/9),
            i%2==0 and 2.5 or 5,nil,nil,{neutral=i==12 or i==53}))
    end
    local first=Planner.plan(hexes,state,{maxStops=16})
    eq(#first,16)
    local seen={}
    for pass=1,6 do
        local route=Planner.plan(hexes,state,{maxStops=16,exclude=seen})
        if #route==0 then break end
        for _,spot in ipairs(route) do
            assert(not seen[spot.key],"No territory may be scheduled twice")
            assert(spot.key~="H12" and spot.key~="H53","Neutral hex cannot enter a route")
            seen[spot.key]=true
        end
    end
    local count=0
    for _ in pairs(seen) do count+=1 end
    eq(count,69)
end)
test("territory exclusion never leaks over to the next plan's distinct eligible hexes",function()
    local state=s()
    local hexes={h("A",20,0,5,nil,nil),h("B",50,0,5,nil,nil)}
    eq(Planner.plan(hexes,state,{maxStops=1,exclude={A=true}})[1].key,"B")
    eq(Planner.plan(hexes,state,{maxStops=1,exclude={B=true}})[1].key,"A")
end)

test("native 3 by 3 areas follow the requested serpentine sweep",function()
    local order=Planner.regionOrder(3)
    for i,v in ipairs({1,2,3,6,5,4,7,8,9})do eq(order[i],v)end
end)
test("area completion is preferred over closer hexes in the next area",function()
    local state=s();state.regionGrid=3;state.regionBonus=2
    local hexes={h("A",240,0,5,nil,nil,{region=1}),h("B",5,0,5,nil,nil,{region=2})}
    local route,meta=Planner.strategy(hexes,state,{regionCursor=1})
    eq(route[1].key,"A");eq(meta.region,1);eq(meta.bonus,2)
end)
test("completed top left area advances to top centre",function()
    local state=s();state.regionGrid=3
    local route,meta=Planner.strategy({h("A",20,0,5,5,1,{region=1}),h("B",60,0,5,nil,nil,{region=2})},state,{regionCursor=1})
    eq(route[1].key,"B");eq(meta.region,2)
end)
test("occupied hex is skipped even if it has the highest reward",function()
    local state=s();state.contested={A=1}
    local route=Planner.plan({h("A",2,0,20,nil,nil),h("B",40,0,2,nil,nil)},state,{})
    eq(route[1].key,"B")
end)
test("urgent scent loss can interrupt the area sweep",function()
    local state=s();state.regionGrid=3
    local route,meta=Planner.strategy({h("A",20,0,5,nil,nil,{region=1}),h("S",60,0,5,5,.1,{region=9})},state,{regionCursor=1})
    eq(route[1].key,"S");eq(meta.phase,"URGENT_SCENT");eq(meta.cursor,1)
end)
test("within an area the route avoids repeated opposite-corner jumps",function()
    local state=s();state.regionGrid=3;state.position={x=0,z=0}
    local hexes={h("A",10,0,2,nil,nil,{region=1}),h("B",20,0,2,nil,nil,{region=1}),
        h("FAR",300,300,20,nil,nil,{region=1}),h("C",30,0,2,nil,nil,{region=1})}
    local route=Planner.strategy(hexes,state,{regionCursor=1})
    eq(route[1].key,"A");eq(route[2].key,"B");eq(route[3].key,"C");eq(route[4].key,"FAR")
end)
print(string.format("AMBER_PLANNER_RESULT total=%d passed=%d failed=%d",total,passed,total-passed))
assert(total==passed,"Amber planner tests failed")
