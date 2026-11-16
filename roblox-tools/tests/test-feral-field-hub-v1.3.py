"""Engine-substitute fault/behaviour checks; never executes exported game sources."""
from pathlib import Path
import importlib.util
import os
import re
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("hub12tests", ROOT / "tests/test-feral-field-hub-v1.2.py")
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
base = prior.base

CORE_MORE = r'''
case("journal preserves the beginning and reports every omission", function()
    local log=Core.journal(3)
    for i=1,8 do Core.push(log,{i=i}) end
    assert(#log.items==3 and log.items[1].i==1 and log.items[3].i==3 and log.dropped==5)
end)
case("reward sanitizer and planner use only reported eligibility", function()
    local data=assert(Core.cleanRewards({pt=65,pc={},dailyOn=true,claimed=false,day=1,token="SECRET"}))
    local config={ON=true,DAILY_ON=true,PLAYTIME={{min=1},{min=5}},DAILY={108}}
    local plan=Core.rewardPlan(data,config,{})
    assert(#plan==2 and plan[1].kind=="play" and plan[1].index==1 and plan[2].kind=="daily")
    assert(data.token==nil and #Core.rewardPlan(data,config,{["play/1"]=true,["daily/1"]=true})==0)
    assert(Core.cleanRewards({pt=math.huge,pc={}})==nil)
    local malformed=assert(Core.cleanRewards({pt=65,pc={{private=true}},claimed=false}))
    assert(#Core.rewardPlan(malformed,config,{})==0)
end)
case("only exact active-slot protocol metadata survives filtering", function()
    local d=assert(Core.cleanOwnership({owned={},coats={Tiger={White=true}},active="2",slots={["2"]={sp="Tiger",coat="White",name="SECRET",growth=1}}}))
    assert(d.active.key=="2" and d.active.species=="Tiger" and d.active.coat=="White" and d.active.name==nil)
    assert(Core.equipAllowed(d,1,"Tiger","White"))
    assert(not Core.equipAllowed(d,11,"Tiger","White"))
    assert(not Core.equipAllowed(d,1,"Bear","White"))
    assert(not Core.equipAllowed(d,1,"Tiger","Spirit"))
end)
case("speed plans are bounded and leap leaves zero-length species unchanged", function()
    assert(Core.speedPlan({RUN_SPEED=.9,SWIM_SPEED=.7},1.5).RUN_SPEED==1.35)
    assert(Core.speedPlan({RUN_SPEED=.9,SWIM_SPEED=.7},100)==nil)
    local bodies,config=Core.leapPlan({ON=true,of=function() end,BODY_LENGTHS={Tiger=.95,Python=0},DEFAULT=.85,MAX_RUN_SHARE=1},2)
    assert(bodies.Tiger==1.9 and bodies.Python==0 and config.MAX_RUN_SHARE==2)
end)
case("rest gate rejects combat water movement and input focus", function()
    local sample={health=20,mode="idle",horizontal_speed=0}
    assert(Core.restAllowed(sample))
    for _,key in ipairs({"combat","blocked","focused","menu","resting"}) do
        sample[key]=true; assert(not Core.restAllowed(sample)); sample[key]=nil
    end
    sample.mode="swim"; assert(not Core.restAllowed(sample))
end)
case("owner replies distinguish absence without retaining raw values", function()
    assert(Core.lookupReply(table.pack(true),77,"gift").state=="no_values_returned")
    assert(Core.lookupReply(table.pack(true,nil),77,"gift").state=="nil_returned_no_access_established")
    local data=Core.lookupReply(table.pack(true,false,"SECRET"),77,"gift")
    assert(data.return_count==2 and data.return_types[1]=="boolean" and data.return_types[2]=="string")
    assert(data.state=="false_returned_no_access_established" and data.raw==nil)
    assert(Core.lookupReply(table.pack(false,"SECRET"),77,"gift").return_count==0)
end)
'''

PRELUDE_MORE = r'''
local originalSetAttribute=methods.SetAttribute
function methods:GetAttributeChangedSignal(key)
    local name="@attribute/"..key
    if not self._signals[name] then self._signals[name]=signal() end
    return self._signals[name]
end
function methods:SetAttribute(key,value)
    local before=self:GetAttribute(key); originalSetAttribute(self,key,value)
    local changed=self._signals["@attribute/"..key]
    if before~=value and changed then changed:Fire() end
end
M.needs.RUN_SPEED=.9; M.needs.SWIM_SPEED=.7
M.leap={ON=true,DEFAULT=.85,MAX_RUN_SHARE=1,BODY_LENGTHS={Tiger=.95,Python=0}}
M.leap.of=function(sp) return M.leap.BODY_LENGTHS[sp] or M.leap.DEFAULT end
M.leapModule=child("ModuleScript","JumpLeapConfig",M.world); M.modules[M.leapModule]=M.leap
M.rewards={ON=true,DAILY_ON=true,PLAYTIME={{min=1},{min=5}},DAILY={108,405}}
M.rewardModule=child("ModuleScript","RewardConfig",M.world); M.modules[M.rewardModule]=M.rewards
M.gameRequests={}
function methods:FireServer(...)
    M.remoteCalls=M.remoteCalls+1
    local args=table.pack(...); args.remote=self.Name
    M.gameRequests[#M.gameRequests+1]=args
    if M.onGameRequest then M.onGameRequest(self,args) end
end
function M.selectWhite()
    M.click("Tiger"); M.click("LOAD COATS FOR SELECTED PORTRAIT"); M.flush(); M.click("White Tiger",true)
end
function M.syncCoat(coat,owned)
    M.nativeSlots.OnClientEvent:Fire("sync",{owned={Tiger=true},coats={Tiger={White=owned~=false}},active=2,slots={[2]={sp="Tiger",coat=coat,private="SECRET-SLOT"}}})
end
function M.clearRest()
    M.player:SetAttribute("FeralCombatUntil",0); M.player:SetAttribute("FeralMenuOpen",nil)
    M.player:SetAttribute("FeralTitleOpen",nil); M.character:SetAttribute("WolfRest",nil)
    M.character:SetAttribute("FeralUnderwater",nil); M.character:SetAttribute("FeralPinned",nil)
    M.root.AssemblyLinearVelocity=vec(); M.humanoid.MoveDirection=vec()
end
'''

MORE = r'''
case("all new native gameplay requests remain opt in at startup",function()
    local calls=#M.gameRequests; launchHub(); M.step(1); M.flush()
    assert(#M.gameRequests==calls and M.needs.RUN_SPEED==.9 and M.leap.BODY_LENGTHS.Tiger==.95)
    M.click("X")
end)
case("speed profiles do not compound and close restores settings",function()
    launchHub(); M.click("APPLY 1.50x LAND",true); M.flush()
    assert(math.abs(M.needs.RUN_SPEED-1.35)<1e-6)
    M.click("APPLY 2.00x LAND",true); M.flush(); assert(M.needs.RUN_SPEED==1.8)
    M.needs.SWIM_SPEED=1.7; M.click("X")
    assert(M.needs.RUN_SPEED==.9 and M.needs.SWIM_SPEED==1.7); M.needs.SWIM_SPEED=.7
end)
case("reset cancels pending speed callbacks without disabling stamina",function()
    launchHub(); M.click("STAMINA TUNING: OFF"); M.click("APPLY 2.00x LAND",true)
    M.click("RESET SPEED PROFILE"); M.flush()
    assert(M.needs.RUN_SPEED==.9 and M.needs.STAMINA_REGEN==250); M.click("X")
end)
case("leap applies and frozen second table rolls back first table",function()
    launchHub(); M.click("APPLY 1.50x FORWARD",true); M.flush()
    assert(math.abs(M.leap.BODY_LENGTHS.Tiger-1.425)<1e-6 and M.leap.BODY_LENGTHS.Python==0)
    M.click("X"); assert(M.leap.BODY_LENGTHS.Tiger==.95 and M.leap.MAX_RUN_SHARE==1)
    local config=table.freeze({ON=true,of=M.leap.of,DEFAULT=.85,MAX_RUN_SHARE=1,BODY_LENGTHS={Tiger=.95}})
    M.modules[M.leapModule]=config
    launchHub(); M.click("APPLY 2.00x FORWARD",true); M.flush()
    assert(config.BODY_LENGTHS.Tiger==.95); M.click("X"); M.modules[M.leapModule]=M.leap
end)
case("native rest has one request and acknowledgement without HP writes",function()
    M.clearRest(); launchHub(); local writes=M.healthWrites
    local c=M.player:GetAttributeChangedSignal("FeralRestTap"):Connect(function() M.character:SetAttribute("WolfRest",true) end)
    M.click("REQUEST NATIVE REST NOW"); M.step(.3)
    local stamp=M.player:GetAttribute("FeralRestTap"); M.click("REQUEST NATIVE REST NOW"); M.step(1)
    assert(M.player:GetAttribute("FeralRestTap")==stamp and M.healthWrites==writes)
    local data=M.field(); local seen=false
    for _,e in ipairs(data.timeline.events) do if e.kind=="native_rest_acknowledged" then seen=true end end
    assert(seen); M.click("X"); c:Disconnect(); M.clearRest()
end)
case("rest assist waits for idle and disables after missing acknowledgement",function()
    M.clearRest(); M.humanoid.Health=50; launchHub(); M.click("IDLE RECOVERY ASSIST: OFF")
    M.step(.3); M.step(2.1)
    local stamp=M.player:GetAttribute("FeralRestTap"); assert(type(stamp)=="number")
    M.step(5.1); M.button("IDLE RECOVERY ASSIST: OFF")
    M.step(10); assert(M.player:GetAttribute("FeralRestTap")==stamp)
    M.click("X"); M.humanoid.Health=80
end)
case("rest rejects combat and water rather than submitting toggles",function()
    M.clearRest(); launchHub(); local stamp=M.player:GetAttribute("FeralRestTap")
    M.player:SetAttribute("FeralCombatUntil",workspace:GetServerTimeNow()+100); M.click("REQUEST NATIVE REST NOW")
    assert(M.player:GetAttribute("FeralRestTap")==stamp)
    M.player:SetAttribute("FeralCombatUntil",0); M.character:SetAttribute("FeralUnderwater",true)
    M.click("REQUEST NATIVE REST NOW"); assert(M.player:GetAttribute("FeralRestTap")==stamp)
    M.click("X"); M.clearRest()
end)
case("comfort restores nil baselines and preserves later external edits",function()
    M.player:SetAttribute("FeralSet_shake",nil); M.player:SetAttribute("FeralSet_sway",nil)
    launchHub(); M.click("CALM CAMERA: OFF"); M.click("NATIVE PERFORMANCE MODE: OFF")
    assert(M.player:GetAttribute("FeralSet_shake")==0 and M.player:GetAttribute("FeralSet_sway")==false)
    M.player:SetAttribute("FeralSet_sway",true); M.click("X")
    assert(M.player:GetAttribute("FeralSet_shake")==nil and M.player:GetAttribute("FeralSet_sway")==true)
    assert(M.player:GetAttribute("FeralSet_perf")==nil)
end)
case("owned coat requires fresh sync then sends the exact native protocol",function()
    launchHub(); M.selectWhite(); local n=#M.gameRequests
    M.click("EQUIP SELECTED OWNED COAT",true); assert(#M.gameRequests==n)
    M.syncCoat("Default",false); M.click("EQUIP SELECTED OWNED COAT",true); assert(#M.gameRequests==n)
    M.syncCoat("Default",true); M.click("EQUIP SELECTED OWNED COAT",true)
    local request=M.gameRequests[#M.gameRequests]
    assert(#M.gameRequests==n+1 and request.remote=="FeralSlots" and request[1]=="wearCoat" and request[2]==2 and request[3]=="White")
    assert(M.field().features.last_owned_coat_equip==nil)
    M.syncCoat("White",true); assert(M.field().features.last_owned_coat_equip.sync_confirmed==true)
    M.click("X")
end)
case("coat pending deduplicates and timeout does not imply success",function()
    launchHub(); M.selectWhite(); M.syncCoat("Default",true)
    M.click("EQUIP SELECTED OWNED COAT",true); local n=#M.gameRequests
    M.click("EQUIP SELECTED OWNED COAT",true); assert(#M.gameRequests==n)
    M.step(8.1); assert(M.field().features.last_owned_coat_equip==nil)
    M.step(10); M.click("EQUIP SELECTED OWNED COAT",true); assert(#M.gameRequests==n)
    M.click("X")
end)
case("reward batch sends only eligible requests and waits between them",function()
    launchHub(); local start=#M.gameRequests
    M.click("CLAIM ALL SERVER",true); M.flush()
    assert(#M.gameRequests==start+1 and M.gameRequests[#M.gameRequests][1]=="hello")
    M.nativeRewards.OnClientEvent:Fire("state",{pt=61,pc={},dailyOn=true,claimed=false,day=1,private="SECRET"})
    local r=M.gameRequests[#M.gameRequests]; assert(r[1]=="claim" and r[2]=="play" and r[3]==1)
    M.nativeRewards.OnClientEvent:Fire("paid","play",2); assert(M.gameRequests[#M.gameRequests]==r)
    M.nativeRewards.OnClientEvent:Fire("paid","play",1); assert(M.gameRequests[#M.gameRequests][1]=="hello")
    M.nativeRewards.OnClientEvent:Fire("state",{pt=61,pc={true},dailyOn=true,claimed=false,day=1})
    r=M.gameRequests[#M.gameRequests]; assert(r[1]=="claim" and r[2]=="daily" and r[3]==nil)
    M.nativeRewards.OnClientEvent:Fire("state",{pt=61,pc={true},dailyOn=true,claimed=true,day=1})
    M.nativeRewards.OnClientEvent:Fire("state",{pt=61,pc={true},dailyOn=true,claimed=true,day=1})
    assert(M.field().features.reward_requests.sent==2)
    local data=M.field(); assert(data.features.reward_requests.paid_notices_matched==1 and data.features.reward_requests.sync_confirmed==1)
    M.click("X")
end)
case("reward silence and stop prevent retries or late claims",function()
    launchHub(); M.click("CLAIM ALL SERVER",true); M.flush(); local n=#M.gameRequests
    M.step(8.1); M.nativeRewards.OnClientEvent:Fire("state",{pt=1000,pc={},dailyOn=false})
    assert(#M.gameRequests==n)
    M.click("CLAIM ALL SERVER",true); M.flush(); M.click("STOP EXPERIMENTS",true); n=#M.gameRequests
    M.nativeRewards.OnClientEvent:Fire("state",{pt=1000,pc={},dailyOn=false}); assert(#M.gameRequests==n)
    M.click("X")
end)
case("report part rotation requires verified export and shares session identity",function()
    launchHub(); M.step(1); local data=M.field(); local session=data.session_id
    M.click("SAVE PART & CONTINUE",true); M.step(1); data=M.field()
    assert(data.part==2 and data.session_id==session and data.timeline.older_events_evicted==false)
    readfile=nil; M.click("SAVE PART & CONTINUE",true)
    M.io(); data=M.field(); assert(data.part==2)
    M.click("X")
end)
case("checkpoint is optional verified and saved again on close",function()
    M.io(); launchHub(); M.click("60s FILE CHECKPOINTS: OFF"); M.step(1); M.flush()
    local data=M.lastEncoded; assert(data and data.schema=="feral-field-report/1.3")
    assert(data.features.checkpoints_enabled==true)
    local before=data.uptime_seconds; M.step(2); M.click("X")
    assert(M.lastEncoded.uptime_seconds>before)
end)
case("actual v1.2 upgrade restores its changes and removes old observers",function()
    launchHub12(); M.click("STAMINA TUNING: OFF"); M.flush()
    launchHub(); assert(not M.playerGui:FindFirstChild("FeralFieldHubV12"))
    assert(M.playerGui:FindFirstChild("FeralFieldHubV13") and M.needs.STAMINA_REGEN==1.31)
    local n=0; for _,c in ipairs(M.nativeRewards.OnClientEvent.listeners) do if c.Connected then n=n+1 end end
    assert(n==1); M.click("X")
end)
case("module replacement invalidates applied speed evidence",function()
    launchHub(); M.click("APPLY 1.50x LAND",true); M.flush()
    local module=M.world:FindFirstChild("NeedsConfig"); module.Parent=nil
    local replacement=child("ModuleScript","NeedsConfig",M.world); M.modules[replacement]=table.clone(M.needs)
    M.step(1); assert(M.field().features.speed_inputs_match==false)
    M.click("X"); replacement:Destroy(); M.modules[replacement]=nil; module.Parent=M.world
end)
case("old inventory cannot equip on a different character",function()
    launchHub(); M.selectWhite(); M.syncCoat("Default",true)
    M.spawn(); local n=#M.gameRequests; M.click("EQUIP SELECTED OWNED COAT",true)
    assert(#M.gameRequests==n); M.click("X")
end)
case("remote exceptions stop native operations without retries",function()
    launchHub(); M.onGameRequest=function() error("PRIVATE-API-ERROR") end
    M.click("CLAIM ALL SERVER",true); M.flush(); local n=#M.gameRequests
    assert(M.field().errors==1)
    M.step(20); assert(#M.gameRequests==n)
    M.onGameRequest=nil; M.click("X")
end)
case("already collected rewards cause no claim or balance write",function()
    launchHub(); M.click("CLAIM ALL SERVER",true); M.flush(); local n=#M.gameRequests
    M.nativeRewards.OnClientEvent:Fire("state",{pt=1000,pc={true,true},dailyOn=true,claimed=true,day=1})
    assert(#M.gameRequests==n and M.field().features.reward_requests.sent==0)
    M.click("X")
end)
case("corrupt checkpoint stops autosaving and keeps collected history",function()
    launchHub(); M.io(); readfile=function() return "CORRUPTED" end
    M.click("60s FILE CHECKPOINTS: OFF"); M.step(1); M.flush()
    M.button("60s FILE CHECKPOINTS: OFF — SAVE FAILED")
    M.io(); local data=M.field(); assert(data.timeline.stored>0 and not data.features.checkpoints_enabled)
    M.click("X")
end)
case("v1.2 bookmarks migrate without enabling gameplay controls",function()
    M.io(); M.files["FERAL_Hub_Places_v1_3.json.txt"]=nil
    local text=encode({schema="feral-places/1",places={{x=123,z=456}}})
    M.encoded[text]={schema="feral-places/1",places={{x=123,z=456}}}
    M.files["FERAL_Hub_Places_v1_2.json.txt"]=text
    launchHub(); M.click("LOAD SAVED BOOKMARKS")
    M.button("Bookmark 01 / X 123 Z 456")
    assert(M.needs.RUN_SPEED==.9 and M.needs.STAMINA_REGEN==1.31); M.click("X")
end)
case("combat gain-drop context is evidence without a rollback claim",function()
    M.clearRest(); launchHub(); M.step(1)
    M.humanoid.Health=90; M.player:SetAttribute("FeralCombatUntil",workspace:GetServerTimeNow()+30)
    M.now=M.now+.1; M.humanoid.Health=80
    local data=M.field(); local found=false
    for _,e in ipairs(data.timeline.events) do if e.values.gain_followed_by_drop then assert(e.values.drop_context=="combat_active"); found=true end end
    assert(found); M.click("X"); M.clearRest()
end)
case("checkpoint generations preserve a prior verified file on corruption",function()
    M.io(); launchHub(); M.click("60s FILE CHECKPOINTS: OFF"); M.step(1); M.flush()
    local first=nil; local session=M.lastEncoded.session_id
    for name in pairs(M.files) do if name:find(session,1,true) and name:find("CHECKPOINT_A.json.txt",1,true) then first=name end end
    assert(first and M.files[first]); local before=M.files[first]
    readfile=function() return "CORRUPTED" end
    M.step(61); M.flush()
    assert(M.files[first]==before)
    M.io(); local data=M.field(); assert(not data.features.checkpoints_enabled)
    M.click("X")
end)
'''

def main():
    source = (ROOT / 'feral-field-hub-v1.3.lua').read_text()
    luau = Path(os.environ.get('FERAL_LUAU', str(base.DEFAULT_LUAU)))
    subprocess.run([str(luau.with_name('luau-compile')), '--null', str(ROOT / 'feral-field-hub-v1.3.lua')], check=True)
    for forbidden in [':GetPlayers(', 'decompile(', 'getgc(', 'hookfunction(', 'setreadonly(',
                      'SetAttribute("Amber"', 'SetAttribute("FeralTester"', 'hum.Health =', 'hpToggle']:
        assert forbidden not in source, forbidden
    assert source.count(':InvokeServer(') == 1
    assert source.count(':FireServer(') == 3
    assert set(re.findall(r':FireServer\("([^"]+)"', source)) == {'wearCoat', 'hello', 'claim'}
    mock = (ROOT / 'tests/mock-feral-field-hub-v1.0.luau').read_text()
    prelude, scenarios = mock.split('-- HUB SCENARIOS', 1)
    prelude += r'''
M.remoteCalls=0
M.nativeRewards=child("RemoteEvent","FeralRewards",M.services.ReplicatedStorage)
M.nativeSlots=child("RemoteEvent","FeralSlots",M.services.ReplicatedStorage)
M.nativeRewards.OnClientEvent=signal(); M.nativeSlots.OnClientEvent=signal()
'''
    prelude += prior.PRELUDE_MORE.replace('feral-field-report/1.2', 'feral-field-report/1.3') + PRELUDE_MORE
    scenarios = scenarios.replace('FeralFieldHubV10', 'FeralFieldHubV13').replace('STAMINA EXPERIMENT:', 'STAMINA TUNING:').replace('SHOW HIDDEN CARDS IN NATIVE MENU:', 'NATIVE MENU CARD VISIBILITY:')
    first = scenarios.index('case("health trial stops at max and does not revive"')
    last = scenarios.index('case("preview removes cloned scripts', first)
    scenarios = scenarios[:first] + scenarios[last:]
    previous_more = prior.MORE.replace('FeralFieldHubV12', 'FeralFieldHubV13').replace('data.health_writer=="unidentified"', 'data.health_writer:find("unidentified",1,true)')
    previous_more = previous_more.replace('for i=1,620', 'for i=1,6020').replace('data.timeline.stored==600 ', 'data.timeline.stored==6000 ')
    split = scenarios.index('case("startup error reports phase and cleans partial UI"')
    scenarios = scenarios[:split] + prior.prior.ADDITIONAL.replace('FeralFieldHubV11', 'FeralFieldHubV13') + previous_more + MORE + scenarios[split:]
    scenarios = scenarios.replace('OPEN GAME REWARDS', 'OPEN NORMAL REWARDS')
    core = source.split('-- BEGIN TESTABLE CORE\n', 1)[1].split('-- END TESTABLE CORE', 1)[0]
    with tempfile.TemporaryDirectory(prefix='feral-hub13-tests-') as tmp:
        path = Path(tmp)
        core_file = path / 'core.luau'
        core_file.write_text(core + '\n' + base.CORE_CASES + '\n' + prior.CORE_MORE + '\n' + CORE_MORE)
        subprocess.run([str(luau), str(core_file)], check=True)
        runtime = path / 'runtime.luau'
        old_source = (ROOT / 'feral-field-hub-v1.0.lua').read_text()
        source11 = (ROOT / 'feral-field-hub-v1.1.lua').read_text()
        source12 = (ROOT / 'feral-field-hub-v1.2.lua').read_text()
        runtime.write_text(prelude + '\nlocal function launchHub()\n' + source
                           + '\nend\nlocal function launchOldHub()\n' + old_source
                           + '\nend\nlocal function launchHub11()\n' + source11
                           + '\nend\nlocal function launchHub12()\n' + source12 + '\nend\n' + scenarios)
        subprocess.run([str(luau), str(runtime)], check=True)
    print('v1.3 source and simulated behaviour/fault/upgrade checks passed. New Roblox/Velocity effects require an in-game test.')

if __name__ == '__main__':
    main()
