-- Minimal service contract regression for the real Amber Roblox bridge.
local results={pass=0,fail=0}
local function eq(a,b,why)
    assert(a==b,(why or "equality")..": got "..tostring(a).." expected "..tostring(b))
end
local function test(label,callback)
    local ok,err=pcall(callback)
    if not ok then
        results.fail+=1;print("FAIL "..label.." "..tostring(err))
    else
        results.pass+=1;print("PASS "..label)
    end
end
local originalTypeof=typeof
typeof=function(v)
    if type(v)=="table" and v.fakeType then return v.fakeType end
    if originalTypeof then return originalTypeof(v) end
    return type(v)
end
local terrain={attributes={
    Hexes="H0_0,H0_1,H0_2",
    H0_0_owner=7,H0_0_neutral=false,H0_0_hold=.4,H0_0_pay=5,
    H0_1_owner=nil,H0_1_neutral=true,H0_1_hold=nil,
    H0_2_owner=nil,H0_2_neutral=false,H0_2_pay=2.5}}
function terrain:GetAttribute(name) return self.attributes[name] end
local services={}
services.Players={LocalPlayer={}}
function services.Players:GetPlayers() return {} end
services.ReplicatedStorage={}
function services.ReplicatedStorage:FindFirstChild(name)
    if name=="FeralTerritory" then return terrain end
    return nil
end
services.UserInputService={}
services.Workspace={}
function services.Workspace:GetAttribute(key)
    return key=="FeralBiome" and "WolfValley" or nil
end
game={GetService=function(_,name) return services[name] end}
local Bridge=assert(loadstring(BRIDGE_SRC,"=RealAmberBridge"))()
local nav={held={},lastReason="IDLE"}
function nav:stop() end
local bridge=Bridge.new(nav)
bridge.cfg={
    parseHexes=function()
        return {{key="H0_0",i=0,j=0},{key="H0_1",i=0,j=1},{key="H0_2",i=0,j=2}}
    end,
    hexCenter=function(i,j) return {X=150*i,Y=190*j,fakeType="Vector2"} end,
}
test("bridge keeps the replicated territory instance separate from per-hex method",function()
    eq(type(bridge.territory),"function")
    eq(bridge.territoryInstance,terrain)
end)
test("bridge reads all hexes from actual replicated Hexes attribute",function()
    bridge:refresh(1)
    eq(#bridge.hexes,3)
    eq(bridge:territory("H0_0").owner,7)
    eq(bridge:territory("H0_0").hold,.4)
    eq(bridge:territory("H0_2").pay,2.5)
end)
test("bridge excludes neutral territory and counts two eligible hexes",function()
    local stats=bridge:counts({pack=7,now=2})
    eq(stats.total,3)
    eq(stats.neutral,1)
    eq(stats.eligible,2)
    eq(stats.owned,1)
    eq(stats.fading,1)
end)
test("distant unstreamed hex offers coarse destination without raycasting unavailable terrain",function()
    local p=bridge:territorySpot("H0_2",{position={x=999,z=999}})
    eq(p.x,0)
    eq(p.z,380)
end)
print(string.format("AMBER_BRIDGE_RESULT total=%d passed=%d failed=%d",
    results.pass+results.fail,results.pass,results.fail))
assert(results.fail==0,"Bridge regression failure")
