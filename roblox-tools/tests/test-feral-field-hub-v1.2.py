"""Behaviour, privacy and upgrade faults; engine substitute, not Roblox verification."""
from pathlib import Path
import importlib.util
import os
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("hub11tests", ROOT / "tests/test-feral-field-hub-v1.1.py")
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
base = prior.base

CORE_MORE = r'''
case("own-state copies only known booleans without aliases",function()
    local payload={owned={Bear=true,Phantosuchus=false,PRIVATE=true},coats={Tiger={White=true,PRIVATE=true}},
        slots={{name="SECRET",userId=123}},token="NEVER-COPY"}
    local clean=assert(Core.cleanOwnership(payload))
    assert(clean.owned.Bear==true and clean.owned.Phantosuchus==false and clean.owned.PRIVATE==nil)
    assert(clean.coats.Tiger.White==true and clean.coats.Tiger.PRIVATE==nil)
    assert(clean.slots==nil and clean.token==nil)
    payload.owned.Bear=false; assert(clean.owned.Bear==true)
    assert(Core.cleanOwnership("bad")==nil)
end)
case("rolling history reports every discarded event",function()
    local ring=Core.ring(3)
    for i=1,10 do Core.push(ring,{i=i}) end
    assert(#ring.items==3 and ring.total==10 and ring.dropped==7)
    assert(ring.items[1].i==8 and ring.items[3].i==10)
end)
case("waypoints reject nonfinite malformed and excessive coordinates",function()
    assert(Core.place("1","-2").z==-2)
    assert(Core.place(8193,0)==nil and Core.place(0,math.huge)==nil)
    assert(Core.place(0/0,0)==nil and Core.place({},0)==nil and Core.place(false,0)==nil)
end)
case("saved places reject sparse and oversized arrays",function()
    assert(#assert(Core.cleanPlaces({schema="feral-places/1",places={{x=1,z=2}},stamina=true}))==1)
    assert(Core.cleanPlaces({schema="wrong",places={}})==nil)
    assert(Core.cleanPlaces({schema="feral-places/1",places={private="SECRET"}})==nil)
    assert(Core.cleanPlaces({schema="feral-places/1",places={[2]={x=1,z=2}}})==nil)
    local a={}; for i=1,25 do a[i]={x=0,z=0} end
    assert(Core.cleanPlaces({schema="feral-places/1",places=a})==nil)
end)
case("drift includes fields that initially needed no write",function()
    local target={a=0,b=1}
    local lease=assert(Core.patch(target,{a=0,b=0}))
    assert(Core.leaseMatches(lease))
    target.a=3
    assert(not Core.leaseMatches(lease))
    Core.restore(lease)
    assert(target.a==3 and target.b==1)
end)
print("CORE_EXTRA_CASES=5")
case("owner gate predicates expose no identity and respect known styles",function()
    assert(Core.clientGate({77},77,"array")=="matched")
    assert(Core.clientGate({[77]=true},77,"map")=="matched")
    assert(Core.clientGate({88},77,"array")=="not_matched")
    assert(Core.clientGate(nil,77,"array")=="unavailable")
    local big={}; for i=1,129 do big[i]=i end
    assert(Core.clientGate(big,77,"array")=="unavailable")
end)
case("owner lookup summaries reject mismatched targets and discard raw data",function()
    local data=Core.ownLookupSummary({id=77,name="SECRET",save={amber=50,password="SECRET"}},77,"gift")
    assert(data.state=="own_lookup_returned" and data.saved_amber_snapshot==50)
    assert(data.id==nil and data.name==nil and data.save==nil)
    assert(Core.ownLookupSummary({id=88,save={amber=9}},77,"gift").state=="reply_target_not_verified")
    assert(Core.ownLookupSummary({err="Owner only SECRET"},77,"gift").state=="permission_error_reported")
    assert(Core.ownLookupSummary({id="77",list={{private="SECRET"}},undoAt=1},77,"saves").saved_version_count==1)
end)
'''

PRELUDE_MORE = r'''
M.needs.HURT_SLOW=.4
M.status={INJURY={SLOW_PER_POINT=.01}}
M.statusModule=child("ModuleScript","StatusConfig",M.world)
M.modules[M.statusModule]=M.status
M.files={}; M.encoded={}; M.lastEncoded=nil
local function cloneData(value)
    if type(value)~="table" then return value end
    local r={}; for k,v in pairs(value) do r[k]=cloneData(v) end; return r
end
local function encode(value)
    if value==nil then return "null" end
    if type(value)=="boolean" then return tostring(value) end
    if type(value)=="number" then assert(value==value and math.abs(value)<math.huge); return string.format("%.17g",value) end
    if type(value)=="string" then
        local result=value:gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t")
        return '"'..result..'"'
    end
    assert(type(value)=="table","unsupported JSON value")
    local out={}
    if #value>0 then
        for _,v in ipairs(value) do out[#out+1]=encode(v) end
        return "["..table.concat(out,",").."]"
    end
    for k,v in pairs(value) do out[#out+1]=encode(tostring(k))..":"..encode(v) end
    return "{"..table.concat(out,",").."}"
end
M.services.HttpService=Instance.new("HttpService")
function methods:JSONEncode(value)
    local text=encode(value); M.lastEncoded=cloneData(value); M.encoded[text]=cloneData(value); return text
end
function methods:JSONDecode(text)
    if M.decodeOverride then return cloneData(M.decodeOverride) end
    return cloneData(assert(M.encoded[text],"invalid JSON fixture"))
end
function M.io()
    writefile=function(name,text) M.files[name]=text end
    readfile=function(name) return assert(M.files[name],"missing fixture file") end
end
function M.input(name)
    for i=#M.nodes,1,-1 do local n=M.nodes[i]; if not n._destroyed and n.Parent and n.Name==name then return n end end
    error("input missing: "..name)
end
function M.field()
    M.io(); M.click("SAVE FOCUSED FIELD REPORT",true)
    assert(M.lastEncoded and M.lastEncoded.schema=="feral-field-report/1.2")
    return M.lastEncoded
end
M.player.UserId=77
M.ownerConfigs={GiftConfig={ADMINS={77}},OnboardingConfig={OWNERS={[77]=true}},DevConfig={OWNERS={77}}}
for name,value in pairs(M.ownerConfigs) do
    local module=child("ModuleScript",name,M.world); M.modules[module]=value
end
M.rpcCalls={}
M.giftRemote=child("RemoteFunction","FeralGive",M.services.ReplicatedStorage)
M.saveRemote=child("RemoteFunction","FeralSaveAdmin",M.services.ReplicatedStorage)
function methods:InvokeServer(verb,target)
    M.rpcCalls[#M.rpcCalls+1]={remote=self.Name,verb=verb,target=target}
    if M.rpcReply then return M.rpcReply(self.Name,verb,target) end
    if self.Name=="FeralGive" then return {id=77,name="PRIVATE-OWNER-NAME",save={amber=321,private="SECRET-SAVE"}} end
    return {id=77,list={{private="PRIVATE-VERSION"}},undoAt=1}
end
'''

MORE = r'''
case("field report has bounded self-only schema and no HP writes",function()
    launchHub(); M.step(1)
    local writes=M.healthWrites
    M.step(1)
    local data=M.field()
    assert(M.healthWrites==writes and data.health_writer=="unidentified")
    assert(data.timeline.stored<=600 and data.timeline.total_seen>=data.timeline.stored)
    assert(data.grants.arbitrary_amber=="unestablished")
    M.click("X")
end)
case("stamina and mobility share a pending config job without losing callbacks",function()
    launchHub()
    M.click("STAMINA TUNING: OFF")
    M.click("LOW-HP / INJURY MOVEMENT: OFF")
    M.flush()
    assert(M.needs.STAMINA_REGEN==250 and M.needs.HURT_SLOW==0 and M.status.INJURY.SLOW_PER_POINT==0)
    local writes=M.healthWrites; M.step(1); assert(M.healthWrites==writes)
    M.click("STAMINA TUNING: ON",true)
    assert(M.needs.STAMINA_REGEN==1.31 and M.needs.HURT_SLOW==0)
    M.click("X")
    assert(M.needs.HURT_SLOW==.4 and M.status.INJURY.SLOW_PER_POINT==.01)
end)
case("mobility second-table failure rolls back the first",function()
    M.modules[M.statusModule]={INJURY=table.freeze({SLOW_PER_POINT=.01})}
    launchHub(); M.click("LOW-HP / INJURY MOVEMENT: OFF"); M.flush()
    assert(M.needs.HURT_SLOW==.4)
    M.click("X"); M.modules[M.statusModule]=M.status
end)
case("mobility late response cannot reactivate after off",function()
    launchHub(); M.click("LOW-HP / INJURY MOVEMENT: OFF")
    M.click("CHECKING MOVEMENT INPUTS..."); M.flush()
    assert(M.needs.HURT_SLOW==.4 and M.status.INJURY.SLOW_PER_POINT==.01)
    M.click("X")
end)
case("explicit stamina repair recovers drift and preserves the external baseline",function()
    launchHub(); M.click("STAMINA TUNING: OFF"); M.flush()
    M.needs.STAMINA_SPRINT_DRAIN=.33; M.character:SetAttribute("WolfDbgNoStamina",false); M.step(1)
    M.click("REAPPLY STAMINA TUNING"); M.flush()
    assert(M.needs.STAMINA_SPRINT_DRAIN==0 and M.character:GetAttribute("WolfDbgNoStamina")==true)
    M.click("X"); assert(M.needs.STAMINA_SPRINT_DRAIN==.33)
    M.needs.STAMINA_SPRINT_DRAIN=.94
end)
case("module replacement invalidates cached target",function()
    launchHub(); M.click("STAMINA TUNING: OFF"); M.flush()
    local old=M.world:FindFirstChild("NeedsConfig"); old.Name="NeedsOld"
    local replacement=child("ModuleScript","NeedsConfig",M.world)
    local config={STAMINA_SPRINT_DRAIN=.7,STAMINA_JUMP_COST=8,STAMINA_REGEN=2,STAMINA_REGEN_DELAY=1,STAMINA_LOW_NEEDS=.5,HURT_SLOW=.2}
    M.modules[replacement]=config
    M.click("REAPPLY STAMINA TUNING"); M.flush()
    assert(M.needs.STAMINA_REGEN==1.31 and config.STAMINA_REGEN==250)
    M.click("X"); assert(config.STAMINA_REGEN==2)
    replacement:Destroy(); M.modules[replacement]=nil; old.Name="NeedsConfig"
end)
case("health events distinguish maxima and timing without writer attribution",function()
    launchHub(); M.step(1)
    M.humanoid.Health=90; M.now=M.now+.2; M.humanoid.Health=89
    M.humanoid.MaxHealth=110
    local data=M.field()
    assert(data.health_gain_followed_by_drop_pairs>=1 and data.health_writer=="unidentified")
    local seenMaximum=false
    for _,event in ipairs(data.timeline.events) do
        if event.kind=="health_property_update" and event.values.maximum_delta~=0 then seenMaximum=true end
    end
    assert(seenMaximum); M.click("X"); M.humanoid.MaxHealth=100; M.humanoid.Health=80
end)
case("rolling field budget is explicit and observations separate tuning states",function()
    launchHub()
    for i=1,620 do M.step(1.01) end
    M.click("STAMINA TUNING: OFF"); M.flush(); M.step(1.01)
    local data=M.field()
    assert(data.timeline.stored==600 and data.timeline.dropped>0 and data.timeline.truncated==true)
    local normal,tuned=false,false
    for key in pairs(data.observations_by_species_mode_and_tuning) do
        if key:find("/stamina_off",1,true) then normal=true end
        if key:find("/stamina_on",1,true) then tuned=true end
    end
    assert(normal and tuned); M.click("X")
end)
case("ownership snapshot excludes names IDs unknown species and coat keys",function()
    launchHub()
    M.nativeSlots.OnClientEvent:Fire("sync",{owned={Bear=true,SnowLeopard=false,PRIVATE=true},
        coats={Tiger={White=true,PRIVATE=true}},slots={{name="PRIVATE-NAME",UserId=888}},token="PRIVATE-TOKEN"})
    local data=M.field()
    assert(data.own_inventory.values.owned.Bear==true and data.own_inventory.values.owned.PRIVATE==nil)
    assert(data.own_inventory.values.coats.Tiger.White==true and data.own_inventory.values.coats.Tiger.PRIVATE==nil)
    local raw=encode(data)
    assert(not raw:find("PRIVATE-NAME",1,true) and not raw:find("PRIVATE-TOKEN",1,true))
    assert(not raw:find("UserId",1,true)); M.click("X")
end)
case("native guide opens through its UI request without selection calls",function()
    launchHub(); local calls=M.remoteCalls
    M.click("OPEN NORMAL ANIMAL GUIDE")
    assert(type(M.player:GetAttribute("FeralGuideRequest"))=="number" and M.remoteCalls==calls)
    M.click("X")
end)
case("custom waypoint selection never moves and invalid input is refused",function()
    launchHub(); local moves=M.moves
    M.input("WaypointX").Text="800"; M.input("WaypointZ").Text="900"; M.click("SELECT CUSTOM X/Z")
    assert(M.moves==moves)
    M.input("WaypointX").Text="1e100"; M.click("SELECT CUSTOM X/Z"); assert(M.moves==moves)
    M.click("X")
end)
case("bookmarks round trip and loading never enables experiments",function()
    launchHub(); M.io(); M.root.Position=vec(100,4,200)
    M.click("BOOKMARK MY CURRENT POSITION"); M.click("SAVE BOOKMARKS .TXT")
    assert(M.lastEncoded.places[1].x==100 and M.lastEncoded.places[1].z==200)
    M.click("REMOVE LAST BOOKMARK"); M.click("LOAD SAVED BOOKMARKS")
    M.button("Bookmark 01 / X 100 Z 200")
    assert(M.needs.STAMINA_REGEN==1.31 and M.needs.HURT_SLOW==.4)
    M.decodeOverride={schema="feral-places/1",places={{x=math.huge,z=0}}}
    M.click("LOAD SAVED BOOKMARKS"); M.button("Bookmark 01 / X 100 Z 200")
    M.decodeOverride=nil; M.click("X")
end)
case("bookmark budget does not silently discard places",function()
    launchHub()
    for i=1,25 do M.root.Position=vec(i,4,i); M.click("BOOKMARK MY CURRENT POSITION") end
    M.io(); M.click("SAVE BOOKMARKS .TXT")
    assert(#M.lastEncoded.places==24 and M.lastEncoded.places[24].x==24)
    M.click("X")
end)
case("failed and corrupt file saves are not marked verified",function()
    launchHub()
    writefile=function() return false end
    M.click("SAVE FOCUSED FIELD REPORT",true)
    local copied=false; setclipboard=function() copied=true end
    M.click("COPY LAST FIELD REPORT FILENAME"); assert(not copied)
    writefile=function() end; readfile=function() return "CORRUPTED" end
    M.click("SAVE FOCUSED FIELD REPORT",true)
    M.click("COPY LAST FIELD REPORT FILENAME"); assert(not copied)
    M.click("X")
end)
case("health observer disconnects across respawns and final shutdown",function()
    launchHub(); M.step(1); local old=M.humanoid
    M.spawn(); M.step(1)
    for _,name in ipairs({"Health","MaxHealth"}) do
        for _,c in ipairs(old:GetPropertyChangedSignal(name).listeners) do assert(not c.Connected) end
    end
    local current=M.humanoid; M.click("X")
    for _,name in ipairs({"Health","MaxHealth"}) do
        for _,c in ipairs(current:GetPropertyChangedSignal(name).listeners) do assert(not c.Connected) end
    end
end)
case("owner gate checks do not query the server or export owner lists",function()
    launchHub(); local before=#M.rpcCalls
    M.click("CHECK MY CACHED OWNER TOOL GATES"); M.flush()
    local data=M.field()
    assert(data.own_cached_owner_gates.gift=="matched" and data.own_cached_owner_gates.saves=="matched")
    assert(data.own_cached_owner_gates.developer=="matched" and #M.rpcCalls==before)
    assert(not encode(data):find("ADMINS",1,true)); M.click("X")
end)
case("owner lookups use only verified read verbs and self target",function()
    launchHub(); local before=#M.rpcCalls
    M.click("CHECK SERVER GIFT LOOKUP",true); M.click("CHECK SERVER GIFT LOOKUP",true)
    M.flush(); assert(#M.rpcCalls==before+1)
    M.click("CHECK SERVER SAVE-VERSION LIST",true); M.flush()
    local data=M.field()
    assert(data.own_server_lookup_results.gift.saved_amber_snapshot==321)
    assert(data.own_server_lookup_results.saves.saved_version_count==1)
    assert(data.own_server_lookup_results.gift.write_permission=="unverified")
    for i=before+1,#M.rpcCalls do
        local call=M.rpcCalls[i]
        assert(call.target=="77")
        assert((call.remote=="FeralGive" and call.verb=="look") or (call.remote=="FeralSaveAdmin" and call.verb=="list"))
    end
    local raw=encode(data)
    for _,secret in ipairs({"PRIVATE-OWNER-NAME","SECRET-SAVE","PRIVATE-VERSION"}) do assert(not raw:find(secret,1,true)) end
    M.click("X")
end)
case("owner lookup errors and stopped late replies cannot establish access",function()
    launchHub(); M.rpcReply=function() return {err="Owner only PRIVATE-ERROR"} end
    M.click("CHECK SERVER GIFT LOOKUP",true); M.flush()
    local data=M.field()
    assert(data.own_server_lookup_results.gift.state=="permission_error_reported")
    assert(not encode(data):find("PRIVATE-ERROR",1,true))
    M.rpcReply=nil
    M.click("CHECK SERVER SAVE-VERSION LIST",true); M.click("X"); M.flush()
end)
case("existing owner launchers require a matched gate and restore on close",function()
    local gift=child("ScreenGui","FeralGive",M.playerGui); gift.Enabled=false
    local giftKey=child("TextButton","GiveKey",gift); giftKey.Visible=false
    local saves=child("ScreenGui","FeralSaveAdmin",M.playerGui); saves.Enabled=false
    local saveKey=child("TextButton","SavesKey",saves); saveKey.Visible=false
    launchHub(); local before=#M.rpcCalls
    M.click("SHOW EXISTING GIFT",true); assert(not gift.Enabled and not saves.Enabled)
    M.click("CHECK MY CACHED OWNER TOOL GATES"); M.flush()
    M.click("SHOW EXISTING GIFT",true)
    assert(gift.Enabled and saves.Enabled and giftKey.Visible and saveKey.Visible)
    assert(#M.rpcCalls==before)
    M.click("X")
    assert(not gift.Enabled and not saves.Enabled and not giftKey.Visible and not saveKey.Visible)
    gift:Destroy(); saves:Destroy()
end)
case("mismatched client gate does not reveal an existing gift launcher",function()
    local previous=M.ownerConfigs.GiftConfig.ADMINS
    M.ownerConfigs.GiftConfig.ADMINS={88}
    local gift=child("ScreenGui","FeralGive",M.playerGui); gift.Enabled=false
    launchHub(); M.click("CHECK MY CACHED OWNER TOOL GATES"); M.flush()
    M.click("SHOW EXISTING GIFT",true)
    assert(not gift.Enabled)
    assert(M.field().own_cached_owner_gates.gift=="not_matched")
    M.click("X"); gift:Destroy(); M.ownerConfigs.GiftConfig.ADMINS=previous
end)
case("travel observation compares body centre rather than root offset",function()
    local previous=methods.GetBoundingBox
    function methods:GetBoundingBox()
        if self==M.character then return cf(M.root.Position+vec(0,3,0)),vec(4,5,8) end
        return previous(self)
    end
    launchHub()
    M.click("1  /  SCOUT",true); M.flush(); M.click("2  /  MOVE ONCE",true); M.step(4.1)
    local matched=false
    for _,node in ipairs(M.nodes) do
        if not node._destroyed and node.Parent and type(node.Text)=="string"
            and node.Text:find("After 4s: 0.0 studs",1,true) then matched=true end
    end
    assert(matched)
    M.click("X"); methods.GetBoundingBox=previous
end)
case("current hub upgrades actual v1.1 and replaces its native observers",function()
    launchHub11(); M.click("STAMINA TUNING: OFF"); M.flush()
    M.click("OBSERVE NORMAL REWARD",true)
    assert(M.playerGui:FindFirstChild("FeralFieldHubV11") and M.needs.STAMINA_REGEN==250)
    launchHub()
    assert(not M.playerGui:FindFirstChild("FeralFieldHubV11") and M.playerGui:FindFirstChild("FeralFieldHubV12"))
    assert(M.needs.STAMINA_REGEN==1.31)
    local count=0
    for _,c in ipairs(M.nativeRewards.OnClientEvent.listeners) do if c.Connected then count=count+1 end end
    assert(count==1); M.click("X")
end)
'''


def main():
    source = (ROOT / "feral-field-hub-v1.2.lua").read_text()
    luau = Path(os.environ.get("FERAL_LUAU", str(base.DEFAULT_LUAU)))
    subprocess.run([str(luau.with_name("luau-compile")), "--null", str(ROOT / "feral-field-hub-v1.2.lua")], check=True)
    for forbidden in [":FireServer(", ":GetPlayers(", "decompile(",
                      "getgc(", "hookfunction(", "setreadonly(", 'SetAttribute("Amber"',
                      'SetAttribute("FeralTester"', "hum.Health =", "state.hp", "hpToggle"]:
        assert forbidden not in source, forbidden
    assert source.count(":InvokeServer(")==1
    assert 'remote:InvokeServer(spec.verb, tostring(ownId))' in source
    assert '{key = "gift", remote = "FeralGive", verb = "look"}' in source
    assert '{key = "saves", remote = "FeralSaveAdmin", verb = "list"}' in source
    mock = (ROOT / "tests/mock-feral-field-hub-v1.0.luau").read_text()
    prelude, scenarios = mock.split("-- HUB SCENARIOS", 1)
    prelude += r'''
M.remoteCalls=0
function methods:FireServer() M.remoteCalls=M.remoteCalls+1 end
M.nativeRewards=child("RemoteEvent","FeralRewards",M.services.ReplicatedStorage)
M.nativeSlots=child("RemoteEvent","FeralSlots",M.services.ReplicatedStorage)
M.nativeRewards.OnClientEvent=signal(); M.nativeSlots.OnClientEvent=signal()
'''
    prelude += PRELUDE_MORE
    scenarios = scenarios.replace("FeralFieldHubV10", "FeralFieldHubV12")
    scenarios = scenarios.replace("STAMINA EXPERIMENT:", "STAMINA TUNING:")
    scenarios = scenarios.replace("SHOW HIDDEN CARDS IN NATIVE MENU:", "NATIVE MENU CARD VISIBILITY:")
    first = scenarios.index('case("health trial stops at max and does not revive"')
    last = scenarios.index('case("preview removes cloned scripts', first)
    scenarios = scenarios[:first] + scenarios[last:]
    split = scenarios.index('case("startup error reports phase and cleans partial UI"')
    scenarios = scenarios[:split] + prior.ADDITIONAL.replace("FeralFieldHubV11", "FeralFieldHubV12") + MORE + scenarios[split:]
    core = source.split("-- BEGIN TESTABLE CORE\n", 1)[1].split("-- END TESTABLE CORE", 1)[0]
    with tempfile.TemporaryDirectory(prefix="feral-hub12-tests-") as tmp:
        path = Path(tmp)
        core_file = path / "core.luau"
        core_file.write_text(core + "\n" + base.CORE_CASES + "\n" + CORE_MORE)
        subprocess.run([str(luau), str(core_file)], check=True)
        runtime = path / "runtime.luau"
        old_source = (ROOT / "feral-field-hub-v1.0.lua").read_text()
        source11 = (ROOT / "feral-field-hub-v1.1.lua").read_text()
        runtime.write_text(prelude + "\nlocal function launchHub()\n" + source
                           + "\nend\nlocal function launchOldHub()\n" + old_source
                           + "\nend\nlocal function launchHub11()\n" + source11 + "\nend\n" + scenarios)
        subprocess.run([str(luau), str(runtime)], check=True)
    print("v1.2 source and simulated fault/upgrade tests passed. Roblox/Velocity runtime effects remain unverified.")


if __name__ == "__main__":
    main()
