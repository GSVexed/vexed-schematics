"""Own-account native-protocol trials: static checks and engine-substitute faults."""
from pathlib import Path
import importlib.util
import os
import re
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('hub13tests', ROOT / 'tests/test-feral-field-hub-v1.3.py')
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
base = prior.base

CORE_MORE = r'''
case("goal gift packets are positive bounded and restricted to supported kinds",function()
    assert(Core.goalGift("amber","100").value==100)
    for _,n in ipairs({"0","-1","1.5","1e309","1000001"}) do assert(Core.goalGift("amber",n)==nil) end
    assert(Core.goalGift("animal","Phantosuchus").value=="Phantosuchus")
    assert(Core.goalGift("animal","*").value=="*")
    assert(Core.goalGift("role","owner")==nil and Core.goalGift("animal","PRIVATE")==nil)
end)
case("goal slots preserve numeric emptiness and never expose names or growth",function()
    local data=assert(Core.goalSlots({slots={[1]={sp="Tiger",name="SECRET",g=2},[2]=false},active=1,owned={Tiger=true}},5))
    assert(data.empty[1]==2 and data.slots[1].occupied and data.slots[1].species=="Tiger")
    assert(data.slots[1].name==nil and data.slots[1].g==nil)
    assert(Core.goalSlots({slots={["1"]={sp="Tiger"}}},5)==nil)
    assert(Core.goalSlots({slots={}},100)==nil)
end)
case("gift acknowledgement never copies raw reply or implies credited balance",function()
    local data=Core.goalGiftReply(table.pack(true,{here=true,name="SECRET",save={amber=99}}))
    assert(data.acknowledged and data.here and data.name==nil and data.save==nil)
    assert(Core.goalGiftReply(table.pack(true,{})).state=="table_reply_unclassified")
    assert(Core.goalGiftReply(table.pack(true,nil)).state=="nil_reply_unconfirmed")
    assert(Core.goalGiftReply(table.pack(true,{err="Owner only SECRET"})).state=="permission_error_reported")
end)
local function phase(rate,move)
    local a={}
    for i=1,5 do a[i]={t=i,health=20+rate*i,health_max=100,hunger=80,thirst=80,horizontal_speed=move and 5 or 0,combat=false} end
    return a
end
case("recovery metrics require comparable moving baseline signal and after",function()
    local data=Core.goalRecoveryResult({baseline=phase(1,true),signal=phase(2,true),after=phase(1,true)})
    assert(data.state=="higher_recovery_during_signal_observed_while_moving")
    assert(Core.goalRecoveryResult({baseline=phase(1,false),signal=phase(2,false),after=phase(1,false)}).state=="movement_comparison_incomplete")
    assert(Core.goalRecoveryResult({baseline=phase(1,true),signal=phase(1,true),after=phase(1,true)}).state=="no_clear_recovery_uplift_observed")
end)
case("growth needs and saturation do not manufacture measured recovery",function()
    local a=phase(2,true)
    for i,v in ipairs(a) do v.health_max=100+i end
    assert(Core.goalRates(a).valid_pairs==0)
    a=phase(2,true); for _,v in ipairs(a) do v.hunger=5 end
    assert(Core.goalRates(a).valid_pairs==0)
    a=phase(2,true); for _,v in ipairs(a) do v.health=100 end
    assert(Core.goalRates(a).valid_pairs==0)
end)
case("goal export removes aliases and fails visibly on cycles",function()
    local record={state="done",amount=1}; local copy=Core.goalCopy({latest=record,trials={record}})
    assert(copy.latest.amount==1 and copy.latest~=copy.trials[1] and copy.latest~=record)
    local bad={}; bad.self=bad
    assert(not pcall(Core.goalCopy,bad))
end)
'''

PRELUDE_MORE = r'''
M.saveConfig={SLOT_COUNT=5}
M.shopConfig={PRICES={SnowLeopard=3000,Phantosuchus=100000000}}
for name,value in pairs({SaveConfig=M.saveConfig,ShopConfig=M.shopConfig}) do local m=child("ModuleScript",name,M.world); M.modules[m]=value end
M.nativeSelect=child("RemoteEvent","FeralSelect",M.services.ReplicatedStorage)
M.wolfActions=child("RemoteEvent","WolfActions",M.services.ReplicatedStorage)
M.nativeAmber=child("RemoteEvent","FeralAmber",M.services.ReplicatedStorage); M.nativeAmber.OnClientEvent=signal()
function methods:InvokeServer(verb,target,kind,value)
    M.rpcCalls[#M.rpcCalls+1]={remote=self.Name,verb=verb,target=target,kind=kind,value=value}
    if M.rpcReply then return M.rpcReply(self.Name,verb,target,kind,value) end
    if self.Name=="FeralGive" then
        if verb=="give" then return nil end
        return {id=77,name="PRIVATE-OWNER-NAME",save={amber=321,private="SECRET-SAVE"}}
    end
    return {id=77,list={{private="PRIVATE-VERSION"}},undoAt=1}
end
function M.goal() return M.field().goal_experiments end
function M.goalReady()
    M.rpcReply=nil; M.onGameRequest=nil; M.spawn(); M.clearRest()
    M.character:SetAttribute("Hunger",80); M.character:SetAttribute("Thirst",80)
    M.player:SetAttribute("HudBurst",nil); M.player:SetAttribute("HudSprint",nil)
    M.player:SetAttribute("Amber",5000)
end
function M.menu() M.player.Character=nil end
function M.replySlots(payload)
    M.onGameRequest=function(remote,args)
        if remote==M.nativeSlots and args[1]=="get" then M.nativeSlots.OnClientEvent:Fire("sync",payload) end
    end
end
function M.countMessage(remote,verb)
    local n=0
    for _,r in ipairs(M.gameRequests) do if r.remote==remote and r[1]==verb then n=n+1 end end
    return n
end
'''

MORE = r'''
case("new goal requests are all opt in",function()
    M.goalReady(); local calls=#M.gameRequests; local rpc=#M.rpcCalls; local writes=M.healthWrites
    launchHub(); M.step(2); M.flush()
    assert(#M.gameRequests==calls and #M.rpcCalls==rpc and M.healthWrites==writes and #M.goal().trials==0)
    M.click("X")
end)
case("own gift sends numeric self and exact amount and verifies own saved delta",function()
    M.goalReady(); local balance=5000
    M.rpcReply=function(remote,verb,target,kind,value)
        assert(target==77)
        if verb=="look" then return {id=77,save={amber=balance,private="SECRET"},name="PRIVATE"} end
        assert(verb=="give" and kind=="amber" and value==100)
        balance=balance+value; M.player:SetAttribute("Amber",balance); return {here=true,private="SECRET"}
    end
    launchHub(); M.input("GoalAmberAmount").Text="100"; M.click("TRY OWN AMBER GIFT",true); M.flush()
    local data=M.goal(); assert(data.gift.state=="own_saved_balance_increase_observed_after_gift")
    assert(data.gift.saved_amber_before==5000 and data.gift.saved_amber_after==5100)
    local raw=encode(data); assert(not raw:find("SECRET",1,true) and not raw:find("PRIVATE",1,true))
    M.click("X"); M.rpcReply=nil
end)
case("failed read is not treated as proof the independent write is denied",function()
    M.goalReady(); M.rpcReply=function() return nil end
    launchHub(); local before=#M.rpcCalls
    M.click("TRY OWN AMBER GIFT",true); M.flush()
    assert(#M.rpcCalls==before+2 and M.rpcCalls[#M.rpcCalls].verb=="give")
    assert(M.goal().gift.state=="nil_reply_unconfirmed"); M.click("X"); M.rpcReply=nil
end)
case("invalid amber cannot reach either gift RPC",function()
    M.goalReady(); launchHub(); local calls=#M.rpcCalls
    for _,v in ipairs({"-1","0","1.5","1e309","1000001"}) do M.input("GoalAmberAmount").Text=v; M.click("TRY OWN AMBER GIFT",true); M.flush() end
    assert(#M.rpcCalls==calls); M.click("X")
end)
case("own lookup compares numeric and text formats without identity export",function()
    M.goalReady(); M.rpcReply=function(_,verb,target)
        assert(verb=="look"); if type(target)=="string" then return {id=77,save={amber=100},private="SECRET"} end
        return nil
    end
    launchHub(); local n=#M.rpcCalls; M.click("CHECK MY GIFT LOOKUP",true); M.flush()
    assert(#M.rpcCalls==n+2 and M.rpcCalls[n+1].target==77 and M.rpcCalls[n+2].target=="77")
    local data=M.goal(); assert(data.own_lookup.state=="own_lookup_returned" and data.own_lookup.target_format=="text_self_id")
    assert(data.own_lookup.id==nil and data.own_lookup.save==nil)
    M.click("X"); M.rpcReply=nil
end)
case("stopping during baseline RPC prevents the chained gift",function()
    M.goalReady(); launchHub()
    M.rpcReply=function() M.click("STOP GOAL EXPERIMENTS"); return {id=77,save={amber=100}} end
    local n=#M.rpcCalls; M.click("TRY OWN AMBER GIFT",true); M.flush()
    assert(#M.rpcCalls==n+1 and M.goal().gift.state=="stopped_before_gift_send")
    M.click("X"); M.rpcReply=nil
end)
case("all-animal gift has an own target and native supported wildcard",function()
    M.goalReady(); launchHub(); M.click("TRY OWN ALL-ANIMAL GIFT"); M.flush()
    local r=M.rpcCalls[#M.rpcCalls]
    assert(r.target==77 and r.verb=="give" and r.kind=="animal" and r.value=="*")
    M.click("X")
end)
case("spawn cannot replace a living active animal",function()
    M.goalReady(); launchHub(); local n=#M.gameRequests
    M.click("TRY SNOW LEOPARD NEW-SLOT SPAWN"); M.flush()
    assert(#M.gameRequests==n); M.click("X")
end)
case("direct spawn uses exactly one empty numeric slot and six native args",function()
    M.goalReady(); M.menu(); launchHub()
    local payload={slots={[1]={sp="Tiger",g=2,name="SECRET"}},active=1,owned={SnowLeopard=false},coats={}}
    M.replySlots(payload); M.click("TRY SNOW LEOPARD NEW-SLOT SPAWN"); M.flush()
    local r=M.gameRequests[#M.gameRequests]
    assert(r.remote=="FeralSelect" and r.n==6 and r[1]=="SnowLeopard" and r[2]=="Male" and r[3]==2 and r[4]==false and r[5]==nil and r[6]==nil)
    M.spawn(); M.character:SetAttribute("Species","SnowLeopard")
    M.nativeSlots.OnClientEvent:Fire("sync",{slots={[1]={sp="Tiger"},[2]={sp="SnowLeopard"}},active=2,owned={SnowLeopard=true},coats={}})
    M.step(.3); assert(M.goal().spawn.state=="live_species_and_new_active_slot_match")
    M.click("X"); M.onGameRequest=nil
end)
case("full or malformed slot maps never submit a spawn",function()
    M.goalReady(); M.menu(); launchHub()
    local slots={}; for i=1,5 do slots[i]={sp="Tiger",name="SECRET",g=2} end
    M.replySlots({slots=slots,owned={},coats={}})
    local n=M.countMessage("FeralSelect","Phantosuchus")
    M.click("TRY PHANTOSUCHUS NEW-SLOT SPAWN"); M.flush()
    assert(M.countMessage("FeralSelect","Phantosuchus")==n and M.goal().spawn.state=="no_empty_slot_or_active_animal")
    M.click("X"); M.onGameRequest=nil; M.spawn()
end)
case("late SaveConfig callbacks cannot send after goal stop",function()
    M.goalReady(); M.menu(); launchHub(); local n=#M.gameRequests
    M.click("TRY PHANTOSUCHUS NEW-SLOT SPAWN"); M.click("STOP GOAL EXPERIMENTS"); M.flush()
    assert(#M.gameRequests==n); M.click("X"); M.spawn()
end)
case("a live species without a fresh matching slot sync remains partial",function()
    M.goalReady(); M.menu(); launchHub(); M.replySlots({slots={},owned={},coats={}})
    M.click("TRY PHANTOSUCHUS NEW-SLOT SPAWN"); M.flush()
    M.spawn(); M.character:SetAttribute("Species","Phantosuchus"); M.step(.3)
    assert(M.goal().spawn.state~="live_species_and_new_active_slot_match")
    M.step(12.1); assert(M.goal().spawn.state=="no_confirmed_spawn_in_window")
    M.click("X"); M.onGameRequest=nil
end)
case("normal Snow Leopard buy is opt in bounded and requires ownership change",function()
    M.goalReady(); launchHub()
    local payload={slots={},active=1,owned={SnowLeopard=false},coats={}}
    M.onGameRequest=function(remote,args)
        if remote==M.nativeSlots and args[1]=="get" then M.nativeSlots.OnClientEvent:Fire("sync",payload)
        elseif remote==M.nativeSlots and args[1]=="buy" then
            assert(args.n==2 and args[2]=="SnowLeopard")
            M.player:SetAttribute("Amber",2000); payload.owned.SnowLeopard=true; M.nativeSlots.OnClientEvent:Fire("sync",payload)
        end
    end
    M.click("TRY SNOW LEOPARD BUY",true); M.flush()
    assert(M.goal().buy.state=="own_sync_lists_snow_leopard_owned_after_buy" and M.goal().buy.amber_after==2000)
    M.click("X"); M.onGameRequest=nil
end)
case("insufficient amber and already owned species do not buy",function()
    M.goalReady(); M.player:SetAttribute("Amber",100); launchHub(); local n=M.countMessage("FeralSlots","buy")
    M.click("TRY SNOW LEOPARD BUY",true); M.flush(); assert(M.countMessage("FeralSlots","buy")==n)
    M.player:SetAttribute("Amber",5000); M.replySlots({slots={},owned={SnowLeopard=true},coats={}})
    M.click("TRY SNOW LEOPARD BUY",true); M.flush()
    assert(M.countMessage("FeralSlots","buy")==n and M.goal().buy.state=="already_listed_owned_no_purchase")
    M.click("X"); M.onGameRequest=nil
end)
case("claimed reward replay requires fresh claimed state and sends one request",function()
    M.goalReady(); launchHub(); local before=M.countMessage("FeralRewards","claim")
    M.click("TEST ONE ALREADY-CLAIMED",true); M.flush()
    assert(M.countMessage("FeralRewards","claim")==before)
    M.nativeRewards.OnClientEvent:Fire("state",{pt=1000,pc={true},dailyOn=false})
    assert(M.countMessage("FeralRewards","claim")==before+1)
    M.step(9); M.step(60); assert(M.countMessage("FeralRewards","claim")==before+1)
    assert(M.goal().replay.state=="no_confirmed_duplicate_award_in_window"); M.click("X")
end)
case("replay candidate requires matching paid balance and fresh state observations",function()
    M.goalReady(); launchHub(); M.click("TEST ONE ALREADY-CLAIMED",true); M.flush()
    M.nativeRewards.OnClientEvent:Fire("state",{pt=1000,pc={true},dailyOn=false})
    M.nativeRewards.OnClientEvent:Fire("paid","play",1)
    M.player:SetAttribute("Amber",5020)
    M.step(1); assert(M.goal().replay.state=="one_replay_sent")
    M.nativeRewards.OnClientEvent:Fire("state",{pt=1000,pc={true},dailyOn=false})
    M.step(1); assert(M.goal().replay.state=="duplicate_award_candidate_observed")
    M.click("X")
end)
case("unclaimed tier and conflicting earned batch do not become replays",function()
    M.goalReady(); launchHub(); local n=M.countMessage("FeralRewards","claim")
    M.click("TEST ONE ALREADY-CLAIMED",true); M.flush()
    M.click("CLAIM ALL SERVER",true); M.flush()
    M.nativeRewards.OnClientEvent:Fire("state",{pt=1000,pc={},dailyOn=false})
    assert(M.countMessage("FeralRewards","claim")==n and M.goal().replay.state=="no_claimed_play_tier_reported")
    M.click("X")
end)
case("server Rest loop is throttled and combat restores false",function()
    M.goalReady(); launchHub(); local n=M.countMessage("WolfActions","Rest")
    M.click("UNPROVEN SERVER REST LOOP: OFF")
    assert(M.countMessage("WolfActions","Rest")==n+1 and M.gameRequests[#M.gameRequests][2]==true)
    M.step(4.9); assert(M.countMessage("WolfActions","Rest")==n+1)
    M.step(.3); assert(M.countMessage("WolfActions","Rest")==n+2)
    M.player:SetAttribute("FeralCombatUntil",workspace:GetServerTimeNow()+30); M.step(.3)
    assert(M.gameRequests[#M.gameRequests][2]==false); M.button("UNPROVEN SERVER REST LOOP: OFF")
    n=M.countMessage("WolfActions","Rest"); M.step(10); assert(M.countMessage("WolfActions","Rest")==n)
    M.click("X"); M.clearRest()
end)
case("closing an active Rest loop restores once and disconnects",function()
    M.goalReady(); launchHub(); M.click("UNPROVEN SERVER REST LOOP: OFF")
    M.click("X"); local n=#M.gameRequests; assert(M.gameRequests[n][2]==false)
    M.step(20); assert(#M.gameRequests==n)
end)
case("update failure restores Rest and blocks unmanaged goal restarts",function()
    M.goalReady(); launchHub(); M.click("UNPROVEN SERVER REST LOOP: OFF")
    M.root.AssemblyLinearVelocity=nil; M.step(1); M.root.AssemblyLinearVelocity=vec()
    assert(M.gameRequests[#M.gameRequests][2]==false)
    local n,rpc=#M.gameRequests,#M.rpcCalls
    M.click("UNPROVEN SERVER REST LOOP: OFF"); M.click("TRY OWN AMBER GIFT",true); M.click("CHECK MY GIFT LOOKUP",true); M.flush()
    assert(#M.gameRequests==n and #M.rpcCalls==rpc)
    M.click("X")
end)
case("26s recovery comparison sends true then false without HP writes",function()
    M.goalReady(); M.humanoid.Health=20; M.root.AssemblyLinearVelocity=vec(5,0,0); M.humanoid.MoveDirection=vec(1,0,0)
    launchHub(); local n=M.countMessage("WolfActions","Rest"); local writes=M.healthWrites
    M.click("RUN 26s SERVER-REST",true)
    for i=1,26 do M.humanoid.Health=M.humanoid.Health+((i>8 and i<=18) and 2 or 1); M.step(1) end
    local data=M.goal()
    assert(data.health.state=="completed" and data.health.result.state=="higher_recovery_during_signal_observed_while_moving")
    assert(M.countMessage("WolfActions","Rest")==n+2 and M.healthWrites==writes+26)
    assert(data.health.restore_request_sent and #data.health.phases.after>=7)
    M.click("X"); M.clearRest()
end)
case("damage during a signal stops the comparison and restores Rest=false",function()
    M.goalReady(); M.humanoid.Health=20; launchHub(); M.click("RUN 26s SERVER-REST",true)
    for i=1,8 do M.humanoid.Health=M.humanoid.Health+1; M.step(1) end
    assert(M.gameRequests[#M.gameRequests][2]==true)
    M.humanoid.Health=M.humanoid.Health-1; M.step(1)
    assert(M.gameRequests[#M.gameRequests][2]==false)
    assert(M.goal().health.state=="combat_damage_or_native_assist_confounded")
    M.click("X"); M.clearRest()
end)
case("healthy animal does not receive a comparison Rest signal",function()
    M.goalReady(); launchHub(); local n=#M.gameRequests
    M.click("RUN 26s SERVER-REST",true); M.step(1)
    assert(#M.gameRequests==n and M.goal().health==nil); M.click("X")
end)
case("entering water invalidates comparison and restores a sent signal",function()
    M.goalReady(); M.humanoid.Health=20; launchHub(); M.click("RUN 26s SERVER-REST",true)
    for i=1,8 do M.humanoid.Health=M.humanoid.Health+1; M.step(1) end
    M.character:SetAttribute("FeralUnderwater",true); M.step(1)
    assert(M.gameRequests[#M.gameRequests][2]==false)
    assert(M.goal().health.state=="combat_damage_or_native_assist_confounded")
    M.click("X"); M.clearRest()
end)
case("goal record budget never silently evicts completed trials",function()
    M.goalReady(); M.player:SetAttribute("Amber",0); launchHub()
    for i=1,33 do M.click("TRY SNOW LEOPARD BUY",true); M.flush() end
    assert(#M.goal().trials==32); M.click("X")
end)
case("native gain reasons and raw own-save fields are never retained",function()
    M.goalReady(); launchHub()
    M.nativeAmber.OnClientEvent:Fire("gain",20,"Gift from PRIVATE-PLAYER-NAME")
    local data=M.goal(); assert(data.last_gain_notice.amount==20)
    assert(not encode(data):find("PRIVATE-PLAYER-NAME",1,true)); M.click("X")
end)
case("v1.4 replaces an actual v1.3 loop and cleans old observers",function()
    M.goalReady(); launchHub13(); M.click("STAMINA TUNING: OFF"); M.flush()
    launchHub(); assert(not M.playerGui:FindFirstChild("FeralFieldHubV13"))
    assert(M.playerGui:FindFirstChild("FeralFieldHubV14") and M.needs.STAMINA_REGEN==1.31)
    local n=0; for _,c in ipairs(M.nativeRewards.OnClientEvent.listeners) do if c.Connected then n=n+1 end end
    assert(n==1); M.click("X")
end)
'''

def main():
    source = (ROOT / 'feral-field-hub-v1.4.lua').read_text()
    luau = Path(os.environ.get('FERAL_LUAU', str(base.DEFAULT_LUAU)))
    subprocess.run([str(luau.with_name('luau-compile')), '--null', str(ROOT / 'feral-field-hub-v1.4.lua')], check=True)
    for forbidden in [':GetPlayers(', 'decompile(', 'getgc(', 'hookfunction(', 'setreadonly(', 'SetAttribute("Amber"', 'SetAttribute("FeralTester"', 'hum.Health =', 'hpToggle', ':PromptProductPurchase(', '"DevGrow"', '"restore"']:
        assert forbidden not in source, forbidden
    assert source.count(':InvokeServer(') == 3
    assert source.count(':FireServer(') == 4
    assert 'remote:InvokeServer("give", ownId, spec.kind, spec.value)' in source
    assert set(re.findall(r'g.send\("([^"]+)"', source)) == {'WolfActions', 'FeralSlots', 'FeralSelect', 'FeralRewards'}
    assert 'g.send("FeralSelect", trial.species, "Male", key, false, nil, nil)' in source
    mock = (ROOT / 'tests/mock-feral-field-hub-v1.0.luau').read_text()
    prelude, scenarios = mock.split('-- HUB SCENARIOS', 1)
    prelude += r'''
M.remoteCalls=0
M.nativeRewards=child("RemoteEvent","FeralRewards",M.services.ReplicatedStorage)
M.nativeSlots=child("RemoteEvent","FeralSlots",M.services.ReplicatedStorage)
M.nativeRewards.OnClientEvent=signal(); M.nativeSlots.OnClientEvent=signal()
'''
    prelude += prior.prior.PRELUDE_MORE.replace('feral-field-report/1.2', 'feral-field-report/1.4') + prior.PRELUDE_MORE + PRELUDE_MORE
    scenarios = scenarios.replace('FeralFieldHubV10', 'FeralFieldHubV14').replace('STAMINA EXPERIMENT:', 'STAMINA TUNING:').replace('SHOW HIDDEN CARDS IN NATIVE MENU:', 'NATIVE MENU CARD VISIBILITY:')
    first = scenarios.index('case("health trial stops at max and does not revive"')
    last = scenarios.index('case("preview removes cloned scripts', first)
    scenarios = scenarios[:first] + scenarios[last:]
    old12 = prior.prior.MORE.replace('FeralFieldHubV12', 'FeralFieldHubV14').replace('data.health_writer=="unidentified"', 'data.health_writer:find("unidentified",1,true)')
    old12 = old12.replace('for i=1,620', 'for i=1,6020').replace('data.timeline.stored==600 ', 'data.timeline.stored==6000 ')
    split = scenarios.index('case("startup error reports phase and cleans partial UI"')
    old13 = prior.MORE.replace('FeralFieldHubV13', 'FeralFieldHubV14').replace('feral-field-report/1.3', 'feral-field-report/1.4').replace('FERAL_Hub_Places_v1_3', 'FERAL_Hub_Places_v1_4')
    scenarios = scenarios[:split] + prior.prior.prior.ADDITIONAL.replace('FeralFieldHubV11', 'FeralFieldHubV14') + old12 + old13 + MORE + scenarios[split:]
    scenarios = scenarios.replace('OPEN GAME REWARDS', 'OPEN NORMAL REWARDS')
    core = source.split('-- BEGIN TESTABLE CORE\n', 1)[1].split('-- END TESTABLE CORE', 1)[0]
    with tempfile.TemporaryDirectory(prefix='feral-hub14-tests-') as tmp:
        path = Path(tmp)
        core_file = path / 'core.luau'
        core_file.write_text(core + '\n' + base.CORE_CASES + '\n' + prior.prior.CORE_MORE + '\n' + prior.CORE_MORE + '\n' + CORE_MORE)
        subprocess.run([str(luau), str(core_file)], check=True)
        runtime = path / 'runtime.luau'
        blocks = [prelude, '\nlocal function launchHub()\n', source, '\nend\n']
        for version, name in [('1.0', 'launchOldHub'), ('1.1', 'launchHub11'), ('1.2', 'launchHub12'), ('1.3', 'launchHub13')]:
            blocks += [f'local function {name}()\n', (ROOT / f'feral-field-hub-v{version}.lua').read_text(), '\nend\n']
        runtime.write_text(''.join(blocks) + scenarios)
        subprocess.run([str(luau), str(runtime)], check=True)
    print('v1.4 static and simulated checks passed. Goal acceptance and new gameplay effects remain untested in Roblox/Velocity.')

if __name__ == '__main__':
    main()
