"""Focused lifecycle/evidence faults in an engine substitute, not Roblox testing."""
from pathlib import Path
import importlib.util
import os
import re
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("hub14helpers", ROOT / "tests/test-feral-field-hub-v1.4.py")
hub14 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hub14)

PRELUDE = r'''
M.needs.HEALTH_NO_REGEN_IN_COMBAT=true
M.needs.HEALTH_REGEN=.01; M.needs.HEALTH_REST_MULT=2
M.serverNeeds={HEALTH_NO_REGEN_IN_COMBAT=true}
M.renderBindings={}
function methods:BindToRenderStep(name,priority,fn)
    if M.renderFail then error("permission: SECRET-API-TEXT") end
    M.renderBindings[name]={priority=priority,fn=fn}
end
function methods:UnbindFromRenderStep(name) M.renderBindings[name]=nil end
local originalStep=M.step
function M.step(seconds)
    originalStep(seconds)
    local list={}; for _,binding in pairs(M.renderBindings) do list[#list+1]=binding end
    table.sort(list,function(a,b) return a.priority<b.priority end)
    for _,binding in ipairs(list) do binding.fn() end
    M.nativeRestPose=M.character and M.character:GetAttribute("WolfRest")==true
end
local baseAttribute=methods.SetAttribute
function methods:SetAttribute(key,value)
    if M.attrFail and self==M.character and key=="WolfRest" and value==false then error("security: SECRET-API-TEXT") end
    baseAttribute(self,key,value)
end
function M.close()
    local gui=M.playerGui:FindFirstChild("FeralHealthRecoveryV10")
    if gui then M.click("X"); M.flush() end
end
function M.fresh(hp)
    M.close(); M.renderFail=false; M.attrFail=false
    M.spawn(); M.clearRest(); M.humanoid.Health=hp or 80
    M.needs.HEALTH_NO_REGEN_IN_COMBAT=true
    M.player:SetAttribute("HudSprint",nil); M.player:SetAttribute("HudBurst",nil)
    M.rpcReply=nil; M.onGameRequest=nil; M.io()
    M.echoRest=true
    M.onGameRequest=function(remote,args)
        if remote==M.wolfActions and M.echoRest then M.character:SetAttribute("WolfRest",args[2]) end
    end
end
function M.healthReport()
    M.click("SAVE HEALTH REPORT .JSON"); M.flush()
    assert(M.lastEncoded and M.lastEncoded.schema=="feral-health-report/1.0")
    return M.lastEncoded
end
function M.restCount(value)
    local count=0
    for _,r in ipairs(M.gameRequests) do
        if r.remote=="WolfActions" and r[1]=="Rest" and (value==nil or r[2]==value) then count=count+1 end
    end
    return count
end
function M.arm() M.click("CONTINUOUS RECOVERY REQUEST: OFF"); M.step(.1) end
'''

CASES = r'''
case("opens with every experiment off and no gameplay requests or health writes",function()
    M.fresh(); local n=#M.gameRequests; local writes=M.healthWrites
    launchHealth(); M.step(2)
    assert(#M.gameRequests==n and M.healthWrites==writes and M.needs.HEALTH_NO_REGEN_IN_COMBAT)
    assert(M.healthReport().current.pose_mask_active==false)
end)
case("local flag changes only client cache and never sends recovery",function()
    M.fresh(); launchHealth(); local n=#M.gameRequests; local writes=M.healthWrites
    M.click("LOCAL COMBAT REGEN FLAG: OFF"); M.flush(); M.step(2)
    assert(M.needs.HEALTH_NO_REGEN_IN_COMBAT==false and M.serverNeeds.HEALTH_NO_REGEN_IN_COMBAT==true)
    assert(#M.gameRequests==n and M.healthWrites==writes)
    assert(M.healthReport().current.local_combat_flag_applied)
    M.click("STOP HEALTH EXPERIMENTS"); M.flush()
    assert(M.needs.HEALTH_NO_REGEN_IN_COMBAT==true)
end)
case("late config callback cannot reactivate a stopped health trial",function()
    M.fresh(); launchHealth(); M.click("LOCAL COMBAT REGEN FLAG: OFF")
    M.click("STOP HEALTH EXPERIMENTS"); M.flush()
    assert(M.needs.HEALTH_NO_REGEN_IN_COMBAT==true)
end)
case("frozen config fails without readonly bypass",function()
    M.fresh(); local target=M.world:FindFirstChild("NeedsConfig"); local original=M.modules[target]
    M.modules[target]=table.freeze(table.clone(original))
    launchHealth(); M.click("LOCAL COMBAT REGEN FLAG: OFF"); M.flush()
    assert(M.modules[target].HEALTH_NO_REGEN_IN_COMBAT and not M.healthReport().current.local_combat_flag_applied)
    M.close(); M.modules[target]=original
end)
case("missing loaded module API cannot require a new module",function()
    M.fresh(); local getter=getloadedmodules; getloadedmodules=nil; local n=M.requireCalls
    launchHealth(); M.click("LOCAL COMBAT REGEN FLAG: OFF"); M.flush()
    assert(M.requireCalls==n and M.needs.HEALTH_NO_REGEN_IN_COMBAT)
    M.close(); getloadedmodules=getter
end)
case("rest signal stays active in combat and burst without writing HP",function()
    M.fresh(); M.player:SetAttribute("FeralCombatUntil",workspace:GetServerTimeNow()+100)
    M.player:SetAttribute("HudBurst",true); launchHealth(); local n=M.restCount(true); local writes=M.healthWrites
    M.arm(); assert(M.restCount(true)==n+1 and not M.nativeRestPose)
    M.step(4.8); assert(M.restCount(true)==n+1)
    M.step(.3); assert(M.restCount(true)==n+2 and M.healthWrites==writes)
    local d=M.healthReport(); assert(d.current.combat and d.current.request_active and d.current.mode=="burst")
end)
case("requests are throttled to one every five seconds",function()
    M.fresh(); launchHealth(); M.arm(); local n=M.restCount(true)
    for _=1,40 do M.step(.1) end
    assert(M.restCount(true)==n)
    M.step(1.1); assert(M.restCount(true)==n+1)
end)
case("local mask clears server echoes before the native render priority",function()
    M.fresh(); launchHealth(); M.arm()
    local found=false; for _,v in pairs(M.renderBindings) do assert(v.priority==199); found=true end
    assert(found and M.character:GetAttribute("WolfRest")==false)
    M.character:SetAttribute("WolfRest",true); M.step(.01)
    assert(not M.nativeRestPose and M.healthReport().counts.rest_echoes_masked>=2)
end)
case("full HP stays armed without sending packets or masking native rest",function()
    M.fresh(100); launchHealth(); local n=M.restCount(); M.arm()
    local d=M.healthReport(); assert(M.restCount()==n and d.current.recovery_enabled and not d.current.request_active)
    assert(d.status:find("Full HP",1,true))
    M.humanoid.Health=60; M.step(.2); assert(M.restCount(true)>0 and M.healthReport().current.request_active)
end)
case("reaching full health restores false while preserving the armed toggle",function()
    M.fresh(); launchHealth(); M.arm(); local n=M.restCount(false)
    M.humanoid.Health=100; M.step(.2)
    assert(M.restCount(false)==n+1 and next(M.renderBindings)==nil)
    assert(M.healthReport().current.recovery_enabled and not M.healthReport().current.request_active)
end)
case("native rest is not seized when first enabling recovery",function()
    M.fresh(); M.character:SetAttribute("WolfRest",true); launchHealth(); local n=M.restCount(true)
    M.arm(); assert(M.restCount(true)==n and M.character:GetAttribute("WolfRest")==true)
end)
case("downed and dead state is not masked or revived",function()
    M.fresh(); launchHealth(); M.arm()
    M.character:SetAttribute("FeralDowned",true); M.step(.2)
    assert(M.character:GetAttribute("FeralDowned")==true and not M.healthReport().current.request_active)
    M.humanoid.Health=0; local writes=M.healthWrites; M.step(8)
    assert(M.healthWrites==writes and M.humanoid.Health==0)
end)
case("recovery survives a respawn and old false request never targets the new animal",function()
    M.fresh(); launchHealth(); M.arm(); local old=M.character; local n=M.restCount(false)
    M.spawn(); assert(M.restCount(false)==n+1)
    M.step(5.2); assert(M.healthReport().current.request_active)
    assert(old:GetAttribute("WolfRest")==false and M.character:GetAttribute("WolfRest")==false)
end)
case("late character swap without removing event does not send cleanup to replacement",function()
    M.fresh(); launchHealth(); M.arm(); local n=M.restCount(false)
    local replacement=Instance.new("Model"); replacement.Parent=workspace
    M.player._props.Character=replacement; M.step(.2)
    assert(M.restCount(false)==n and next(M.renderBindings)==nil)
end)
case("mask API failure stops before a true packet",function()
    M.fresh(); launchHealth(); M.renderFail=true; local n=M.restCount(true)
    M.arm(); assert(M.restCount(true)==n and next(M.renderBindings)==nil)
    assert(not M.healthReport().current.recovery_enabled); M.renderFail=false
end)
case("attribute failure after a true echo releases signal and stops future retries",function()
    M.fresh(); launchHealth(); M.echoRest=false; M.arm(); M.attrFail=true
    M.character:SetAttribute("WolfRest",true)
    M.attrFail=false; M.step(.2); local n=M.restCount(true); M.step(8)
    assert(M.restCount(true)==n and not M.healthReport().current.recovery_enabled)
end)
case("missing remote stops rather than looping retries",function()
    M.fresh(); local owner=M.wolfActions.Parent; M.wolfActions.Parent=nil
    launchHealth(); local n=M.restCount(true); M.arm(); M.step(8)
    assert(M.restCount(true)==n and not M.healthReport().current.recovery_enabled)
    M.close(); M.wolfActions.Parent=owner
end)
case("native bite marker does not pause continuous combat requests",function()
    M.fresh(); launchHealth(); M.arm(); M.character:SetAttribute("WolfBiteAt",M.now)
    M.step(5.2); local d=M.healthReport()
    assert(d.current.request_active and d.counts.bite_inputs_observed==1)
end)
case("stable HP gain observed throughout combat is retained without causal success claim",function()
    M.fresh(); launchHealth(); M.arm(); M.step(2)
    M.player:SetAttribute("FeralCombatUntil",workspace:GetServerTimeNow()+60)
    M.humanoid.Health=81; M.step(3.1)
    local d=M.healthReport(); assert(d.counts.retained_gains==1 and d.counts.retained_combat_gains==1)
    assert(d.limits.causal_healing_effect=="not_established")
end)
case("full health without a deficit does not become healing evidence",function()
    M.fresh(100); launchHealth(); M.arm(); M.step(10)
    assert(M.healthReport().counts.retained_gains==0)
end)
case("growth in either health-max event order invalidates recovery classification",function()
    for _,order in ipairs({"health_first","max_first"}) do
        M.fresh(); launchHealth(); M.step(2)
        if order=="health_first" then M.humanoid.Health=81; M.humanoid.MaxHealth=101
        else M.humanoid.MaxHealth=101; M.humanoid.Health=81 end
        M.step(3.1); local d=M.healthReport()
        assert(d.counts.retained_gains==0 and d.counts.max_changes==1)
    end
end)
case("a gain taken away in three seconds is not retained evidence",function()
    M.fresh(); launchHealth(); M.step(2); M.humanoid.Health=85; M.step(1)
    M.humanoid.Health=80; M.step(2.2)
    assert(M.healthReport().counts.retained_gains==0)
end)
case("combat expiring during retention is not throughout-combat evidence",function()
    M.fresh(); launchHealth(); M.step(2)
    M.player:SetAttribute("FeralCombatUntil",workspace:GetServerTimeNow()+1)
    M.humanoid.Health=81; M.step(3.1)
    assert(M.healthReport().counts.retained_combat_gains==0)
end)
case("report is self only and errors do not contain raw API text",function()
    M.fresh(); launchHealth(); M.renderFail=true; M.arm(); M.renderFail=false
    M.character:SetAttribute("Password","SECRET"); M.player:SetAttribute("Amber",87654321)
    local d=M.healthReport(); local raw=encode(d)
    for _,text in ipairs({"SECRET","TestAnimal","PRIVATE-OWNER-NAME","87654321","UserId"}) do assert(not raw:find(text,1,true)) end
    assert(d.last_error.kind=="permission_error" and d.errors>0)
end)
case("readback corruption is shown and never marked verified",function()
    M.fresh(); launchHealth(); readfile=function() return "CORRUPT" end
    M.click("SAVE HEALTH REPORT .JSON"); M.flush()
    M.click("SAVE HEALTH REPORT .JSON"); M.flush()
    assert(M.lastEncoded.previous_export.written and not M.lastEncoded.previous_export.readback_verified)
    M.io()
end)
case("write failure is not a successful export and manual save can recover",function()
    M.fresh(); launchHealth(); writefile=function() error("secret file path") end
    M.click("SAVE HEALTH REPORT .JSON"); M.flush(); M.io()
    local d=M.healthReport(); assert(not d.previous_export.written and not d.previous_export.readback_verified)
end)
case("autosave works without a manual first save and closes with final export",function()
    M.fresh(); launchHealth(); M.step(31); M.flush()
    assert(M.lastEncoded.schema=="feral-health-report/1.0")
    M.close(); assert(M.lastEncoded.status:find("off",1,true))
end)
case("event limit preserves early data and reports exact omissions",function()
    M.fresh(); launchHealth()
    for _=1,6020 do M.step(1) end
    local d=M.healthReport()
    assert(d.timeline.stored==6000 and d.timeline.omitted==d.timeline.total-6000)
    assert(d.timeline.events[1].kind=="own_character_changed")
end)
case("closing during an in-progress file save queues a final stopped report",function()
    M.fresh(); launchHealth(); M.arm(); M.click("SAVE HEALTH REPORT .JSON")
    M.click("X"); M.flush()
    assert(M.lastEncoded.status:find("off",1,true) and not M.lastEncoded.current.recovery_enabled)
end)
case("stamina and health cache patches coexist and stop independently",function()
    M.fresh(); launchHealth(); M.click("LOCAL COMBAT REGEN FLAG: OFF"); M.click("STAMINA TUNING: OFF"); M.flush(); M.step(.2)
    assert(M.needs.STAMINA_REGEN==250 and M.needs.HEALTH_NO_REGEN_IN_COMBAT==false)
    M.click("STOP HEALTH EXPERIMENTS"); M.flush()
    assert(M.needs.HEALTH_NO_REGEN_IN_COMBAT==true and M.needs.STAMINA_REGEN==250)
    M.close(); assert(M.needs.STAMINA_REGEN==1.31 and M.character:GetAttribute("WolfDbgNoStamina")==nil)
end)
case("stopped stamina callback cannot write late",function()
    M.fresh(); launchHealth(); M.click("STAMINA TUNING: OFF"); M.step(.01)
    M.click("STAMINA TUNING: ON"); M.flush()
    assert(M.needs.STAMINA_REGEN==1.31 and M.character:GetAttribute("WolfDbgNoStamina")==nil)
end)
case("closing restores local flags releases request and disconnects mask",function()
    M.fresh(); launchHealth(); M.click("LOCAL COMBAT REGEN FLAG: OFF"); M.flush(); M.arm()
    local n=M.restCount(false); M.close()
    assert(M.needs.HEALTH_NO_REGEN_IN_COMBAT and M.restCount(false)==n+1 and next(M.renderBindings)==nil)
    n=M.restCount(true); M.step(10); assert(M.restCount(true)==n)
end)
case("external destroy and rerun clean all owned effects",function()
    M.fresh(); launchHealth(); M.arm(); local old=M.playerGui:FindFirstChild("FeralHealthRecoveryV10")
    old:Destroy(); M.flush(); assert(next(M.renderBindings)==nil)
    launchHealth(); M.arm(); old=M.playerGui:FindFirstChild("FeralHealthRecoveryV10")
    launchHealth(); M.flush(); assert(old._destroyed and not M.healthReport().current.recovery_enabled)
end)
case("actual v1.4 hub is shut down before the focused tool starts",function()
    M.fresh(); launchOld14(); M.click("STAMINA TUNING: OFF"); M.flush()
    local old=M.playerGui:FindFirstChild("FeralFieldHubV14"); assert(M.needs.STAMINA_REGEN==250)
    launchHealth(); M.flush()
    assert(old._destroyed and M.needs.STAMINA_REGEN==1.31 and M.character:GetAttribute("WolfDbgNoStamina")==nil)
end)
M.close()
print("HEALTH_RUNTIME_CASES="..passed)
'''


def main():
    script = ROOT / "feral-health-recovery-v1.0.lua"
    source = script.read_text()
    luau = Path(os.environ.get("FERAL_LUAU", str(hub14.base.DEFAULT_LUAU)))
    subprocess.run([str(luau.with_name("luau-compile")), "--null", str(script)], check=True)
    for text in [":GetPlayers(", "decompile(", "getgc(", "hookfunction(", "setreadonly(", ":InvokeServer(",
                 "FeralSelect", "FeralGive", "FeralRewards", "FeralRestTap", "TakeDamage("]:
        assert text not in source, text
    assert not re.search(r"\b(?:hum|humanoid)\.Health\s*=", source)
    assert source.count(":FireServer(") == 1 and 'remote:FireServer("Rest", enabled)' in source
    assert "HEALTH_NO_REGEN_IN_COMBAT = false" in source
    mock = (ROOT / "tests/mock-feral-field-hub-v1.0.luau").read_text().split("-- HUB SCENARIOS", 1)[0]
    mock += r'''
M.remoteCalls=0
M.nativeRewards=child("RemoteEvent","FeralRewards",M.services.ReplicatedStorage)
M.nativeSlots=child("RemoteEvent","FeralSlots",M.services.ReplicatedStorage)
M.nativeRewards.OnClientEvent=signal(); M.nativeSlots.OnClientEvent=signal()
'''
    mock += hub14.prior.prior.PRELUDE_MORE + hub14.prior.PRELUDE_MORE + hub14.PRELUDE_MORE + PRELUDE
    with tempfile.TemporaryDirectory(prefix="feral-health-tests-") as tmp:
        runtime = Path(tmp) / "health-runtime.luau"
        runtime.write_text(mock + "\nlocal function launchHealth()\n" + source + "\nend\n"
                           + "local function launchOld14()\n" + (ROOT / "feral-field-hub-v1.4.lua").read_text()
                           + "\nend\n" + CASES)
        subprocess.run([str(luau), str(runtime)], check=True)
    print("Focused health static and simulated checks passed. No Roblox/Velocity execution or server healing established.")


if __name__ == "__main__":
    main()
