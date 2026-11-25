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
    local r=Planner.plan({h("BAD",170,0,5,nil,nil),h("SAFE",0,200,5,nil,nil)},state,{avoidRadius=55})
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
    eq(Planner.need(state),"TERRITORY")
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

print(string.format("AMBER_PLANNER_RESULT total=%d passed=%d failed=%d",total,passed,total-passed))
assert(total==passed,"Amber planner tests failed")
