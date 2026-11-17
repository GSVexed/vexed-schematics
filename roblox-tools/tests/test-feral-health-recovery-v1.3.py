"""Native death reason, bounded trace and privacy faults in a simulator only."""
from pathlib import Path
import importlib.util
import os
import re
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("health12tests", ROOT / "tests/test-feral-health-recovery-v1.2.py")
previous = importlib.util.module_from_spec(spec)
spec.loader.exec_module(previous)

PRELUDE = r'''
M.deathRemote=child("RemoteEvent","FeralDeath",M.services.ReplicatedStorage)
M.deathRemote.OnClientEvent=signal()
local originalFind=methods.FindFirstChild
function methods:FindFirstChild(name,recursive)
    local direct=originalFind(self,name)
    if direct or not recursive then return direct end
    for _,c in ipairs(self:GetChildren()) do local found=c:FindFirstChild(name,true); if found then return found end end
end
function M.deathPacket(cause,corpse,extra)
    local p={cause=cause,corpse=corpse or M.character,alive=123.5,
        killerUser="PRIVATE-KILLER-USER",killerName="PRIVATE-KILLER-NAME",token="SECRET-TOKEN",saveId="SECRET-SAVE"}
    for k,v in pairs(extra or {}) do p[k]=v end
    M.deathRemote.OnClientEvent:Fire("dead",p)
end
function M.clearDeathGui()
    local old=M.playerGui:FindFirstChild("FeralDeath")
    if old then old:Destroy() end
    M.player:SetAttribute("FeralDeathScreen",nil)
end
function M.deathGui(text)
    M.clearDeathGui()
    local gui=child("ScreenGui","FeralDeath",M.playerGui); gui.Enabled=true
    local frame=child("Frame","NativeCanvas",gui)
    local title=child("TextLabel","Title",frame); title.Text=text
    M.player:SetAttribute("FeralDeathScreen",true)
    return gui,title
end
'''

MORE = r'''
case("native cause and lifetime are captured without killer identities or other fields",function()
    M.fresh(); M.clearDeathGui(); launchHealth(); M.step(.1)
    M.humanoid.Health=0; M.deathPacket("other"); local d=M.healthReport()
    assert(d.death_trace.native_messages==1 and d.death_trace.latest_native.info.cause=="other")
    assert(d.death_trace.latest_native.info.alive_seconds_reported==123.5)
    assert(#d.fatal_records==1 and d.fatal_records[1].native_feedback.cause=="other")
    local raw=encode(d)
    for _,v in ipairs({"PRIVATE-KILLER-USER","PRIVATE-KILLER-NAME","SECRET-TOKEN","SECRET-SAVE"}) do assert(not raw:find(v,1,true)) end
end)
case("unknown cause strings and optional fields are redacted",function()
    M.fresh(); launchHealth(); M.step(.1)
    M.deathPacket("PRIVATE-CAUSE",nil,{reason="SECRET-REASON",code="SECRET-CODE",alive=math.huge})
    local d=M.healthReport(); local info=d.death_trace.latest_native.info
    assert(info.cause==nil and info.cause_status=="unrecognized_redacted" and info.alive_seconds_reported==nil)
    local raw=encode(d)
    for _,v in ipairs({"PRIVATE-CAUSE","SECRET-REASON","SECRET-CODE"}) do assert(not raw:find(v,1,true)) end
end)
case("an actually received investigation token is distinguished from a known source code",function()
    M.fresh(); launchHealth(); M.step(.1); M.deathPacket("ANTI_CHEAT",nil,{code="stamina_violation"})
    local info=M.healthReport().death_trace.latest_native.info
    assert(info.cause=="anti_cheat" and info.cause_status=="fixed_investigation_code")
    assert(info.code=="stamina_violation" and info.code_status=="fixed_investigation_code")
end)
case("generic other and missing messages never become an anti-cheat conclusion",function()
    M.fresh(); launchHealth(); M.step(.1); M.humanoid.Health=0
    local d=M.healthReport()
    assert(d.fatal_records[1].native_reason_status=="not_received_at_transition")
    M.deathPacket("other"); d=M.healthReport()
    assert(d.fatal_records[1].native_feedback.cause=="other")
    assert(not encode(d.fatal_records):find('"anti_cheat"',1,true))
end)
case("native feedback arriving before Health zero associates by timing without fabricating a death",function()
    M.fresh(); launchHealth(); M.step(.1); M.deathPacket("other")
    assert(#M.healthReport().fatal_records==0)
    M.humanoid.Health=0; local d=M.healthReport()
    assert(#d.fatal_records==1 and d.fatal_records[1].native_feedback.cause=="other")
    assert(d.fatal_records[1].native_reason_status=="native_feedback_same_generation_close_timing")
end)
case("a delayed old-corpse message stays with the previous model after respawn",function()
    M.fresh(); launchHealth(); M.step(.1); local old=M.character; M.humanoid.Health=0
    M.spawn(); M.step(.2); M.deathPacket("killed",old)
    local d=M.healthReport()
    assert(d.death_trace.latest_native.association=="matches_previous_own_model")
    assert(d.death_trace.latest_native.associated_generation==d.fatal_records[1].generation)
    assert(d.fatal_records[1].native_feedback.cause=="killed")
end)
case("revival in the same model can record a later separate fatal transition",function()
    M.fresh(); launchHealth(); M.step(.1); M.humanoid.Health=0; M.deathPacket("killed")
    M.humanoid.Health=50; M.step(.2); M.deathPacket("other"); M.humanoid.Health=0
    local d=M.healthReport()
    assert(#d.fatal_records==2 and d.fatal_records[1].native_feedback.cause=="killed")
    assert(d.fatal_records[2].native_feedback.cause=="other")
end)
case("client stamina oxygen and independent burst flags are read without writes",function()
    M.fresh(); M.character:SetAttribute("Stamina",40); M.character:SetAttribute("StaminaMax",50)
    M.character:SetAttribute("StaminaOut",false); M.character:SetAttribute("Oxygen",.6)
    M.player:SetAttribute("HudBurst",true); M.character:SetAttribute("WolfBurst",true)
    launchHealth(); local writes=#M.writes; M.step(.1); M.step(2)
    local d=M.healthReport()
    assert(d.current.client_stamina==40 and d.current.client_stamina_max==50 and d.current.oxygen==.6)
    assert(d.current.hud_burst and d.current.character_burst and d.current.continuous_burst_observed_seconds>=2)
    for i=writes+1,#M.writes do
        for _,key in ipairs({"Stamina","StaminaMax","StaminaOut","Oxygen","WolfBurst","HudBurst"}) do assert(M.writes[i].key~=key) end
    end
    M.player:SetAttribute("HudBurst",nil)
end)
case("pre-death trace is frozen, bounded and excludes absolute position",function()
    M.fresh(); launchHealth(); M.step(.1)
    for _=1,90 do M.root.Position=M.root.Position+vec(1,0,0); M.step(.25) end
    M.humanoid.Health=0; local d=M.healthReport(); local fatal=d.fatal_records[1]
    assert(#fatal.trace<=61 and fatal.trace_omitted_before_window>0)
    for _,frame in ipairs(fatal.trace) do
        assert(fatal.observed_at-frame.t<=15.001 and frame.x==nil and frame.z==nil and frame.Position==nil)
    end
    local before=encode(fatal.trace); M.spawn(); M.step(2)
    assert(encode(M.healthReport().fatal_records[1].trace)==before)
end)
case("long sampling gaps are explicit and stale samples are excluded at death",function()
    M.fresh(); launchHealth(); M.step(.1); M.step(2)
    M.now=M.now+20; M.humanoid.Health=0
    local fatal=M.healthReport().fatal_records[1]
    assert(#fatal.trace==1 and fatal.trace_gap_to_transition_seconds>=20 and fatal.trace_omitted_before_window>0)
end)
case("fatal history cap counts omitted records rather than growing without limit",function()
    M.fresh(); launchHealth(); M.step(.1)
    for _=1,20 do M.humanoid.Health=50; M.humanoid.Health=0 end
    local d=M.healthReport()
    assert(#d.fatal_records==16 and d.fatal_records_omitted==4 and d.latest_fatal_id==20)
end)
case("the current native death heading can be classified without another death",function()
    M.fresh(); M.deathGui("Y O U  D I E D  T O  A  PRIVATE-ENEMY")
    launchHealth(); M.click("READ CURRENT DEATH SCREEN"); M.flush()
    local d=M.healthReport()
    assert(d.death_trace.latest_ui_hint.category=="killed" and #d.fatal_records==0)
    assert(d.death_trace.latest_ui_hint.provenance=="local_ui_not_native_server_message")
    assert(not encode(d):find("PRIVATE-ENEMY",1,true)); M.clearDeathGui()
end)
case("an absent or unknown current death heading is explicit and redacted",function()
    M.fresh(); M.clearDeathGui(); launchHealth(); M.click("READ CURRENT DEATH SCREEN"); M.flush()
    assert(M.healthReport().death_trace.latest_ui_hint.status=="current_death_heading_unavailable")
    M.deathGui("SECRET-HEADING"); M.click("READ CURRENT DEATH SCREEN"); M.flush()
    local d=M.healthReport()
    assert(d.death_trace.latest_ui_hint.category=="unrecognized_redacted" and not encode(d):find("SECRET-HEADING",1,true))
    M.clearDeathGui()
end)
case("death evidence autosaves after waiting for native feedback",function()
    M.fresh(); launchHealth(); M.step(.1); M.humanoid.Health=0; M.deathPacket("other")
    M.step(1.4); M.flush()
    assert(M.lastEncoded.schema=="feral-health-report/1.3")
    assert(M.lastEncoded.fatal_records[1].native_feedback.cause=="other")
end)
case("missing and replaced death remotes do not duplicate listeners",function()
    M.fresh(); M.deathRemote.Parent=nil; launchHealth(); M.step(.1)
    assert(M.healthReport().death_trace.listener=="unavailable")
    M.deathRemote.Parent=M.services.ReplicatedStorage; M.step(5.1); M.deathPacket("other")
    local old=M.deathRemote; old.Parent=nil
    M.deathRemote=child("RemoteEvent","FeralDeath",M.services.ReplicatedStorage); M.deathRemote.OnClientEvent=signal()
    M.step(5.1); old.OnClientEvent:Fire("dead",{cause="killed"}); M.deathPacket("other")
    assert(M.healthReport().death_trace.native_messages==2)
    M.close(); M.deathRemote:Destroy(); M.deathRemote=old; old.Parent=M.services.ReplicatedStorage
end)
case("close disconnects death feedback and cancels future evidence saves",function()
    M.fresh(); launchHealth(); M.step(.1); M.humanoid.Health=0; M.close()
    local saved=M.lastEncoded; M.deathPacket("killed"); M.step(3); M.flush()
    assert(M.lastEncoded==saved and saved.death_trace.listener=="stopped")
end)
case("actual health v1.2 upgrade restores its effects before capture starts",function()
    M.fresh(); launchHealth12(); M.click("STAMINA TUNING: OFF"); M.flush(); M.click("RECOVERY ASSIST: OFF"); M.step(.1)
    local old=M.playerGui:FindFirstChild("FeralHealthRecoveryV12"); assert(old)
    launchHealth(); M.step(.1); local d=M.healthReport()
    assert(old._destroyed and M.needs.STAMINA_REGEN==1.31 and d.death_trace.listener=="listening")
    assert(not d.current.stamina_tuning_enabled and not d.current.recovery_enabled)
end)
'''


def main():
    source = (ROOT / "feral-health-recovery-v1.3.lua").read_text()
    luau = Path(os.environ.get("FERAL_LUAU", str(previous.previous.previous.hub14.base.DEFAULT_LUAU)))
    subprocess.run([str(luau.with_name("luau-compile")), "--null", str(ROOT / "feral-health-recovery-v1.3.lua")], check=True)
    for text in [":GetPlayers(", "decompile(", "getgc(", "hookfunction(", "setreadonly(", ":InvokeServer(",
                 "FeralSelect", "FeralGive", "FeralRewards", "FeralRestTap", "TakeDamage(", "HEALTH_NO_REGEN_IN_COMBAT",
                 "payload.killer", "payload.token", "payload.saveId"]:
        assert text not in source, text
    assert not re.search(r"\b(?:hum|humanoid)\.Health\s*=", source)
    assert source.count(":FireServer(") == 1 and 'remote:FireServer("Rest", enabled)' in source
    assert set(re.findall(r':SetAttribute\("([^"]+)"', source)) == {"WolfRest", "WolfDbgNoStamina"}
    hub14 = previous.previous.previous.hub14
    mock = (ROOT / "tests/mock-feral-field-hub-v1.0.luau").read_text().split("-- HUB SCENARIOS", 1)[0]
    mock += r'''
M.remoteCalls=0
M.nativeRewards=child("RemoteEvent","FeralRewards",M.services.ReplicatedStorage)
M.nativeSlots=child("RemoteEvent","FeralSlots",M.services.ReplicatedStorage)
M.nativeRewards.OnClientEvent=signal(); M.nativeSlots.OnClientEvent=signal()
'''
    mock += hub14.prior.prior.PRELUDE_MORE + hub14.prior.PRELUDE_MORE + hub14.PRELUDE_MORE
    mock += previous.previous.previous.PRELUDE.replace("FeralHealthRecoveryV10", "FeralHealthRecoveryV13").replace("feral-health-report/1.0", "feral-health-report/1.3").replace("CONTINUOUS RECOVERY REQUEST", "RECOVERY ASSIST")
    mock += previous.PRELUDE + PRELUDE
    cases = previous.previous.scenarios().split('\nM.close()\nprint("HEALTH_RUNTIME_CASES=', 1)[0]
    cases = cases.replace("FeralHealthRecoveryV11", "FeralHealthRecoveryV13").replace("feral-health-report/1.1", "feral-health-report/1.3")
    cases += previous.MORE.replace("FeralHealthRecoveryV12", "FeralHealthRecoveryV13").replace("feral-health-report/1.2", "feral-health-report/1.3")
    with tempfile.TemporaryDirectory(prefix="feral-health13-tests-") as tmp:
        runtime = Path(tmp) / "runtime.luau"
        blocks = [mock]
        for name, filename in [("launchHealth", "feral-health-recovery-v1.3.lua"),
                               ("launchOld14", "feral-field-hub-v1.4.lua"),
                               ("launchHealth10", "feral-health-recovery-v1.0.lua"),
                               ("launchHealth11", "feral-health-recovery-v1.1.lua"),
                               ("launchHealth12", "feral-health-recovery-v1.2.lua")]:
            blocks += ["\nlocal function " + name + "()\n", (ROOT / filename).read_text(), "\nend\n"]
        runtime.write_text("".join(blocks) + cases + MORE + '\nM.close()\nprint("HEALTH_RUNTIME_CASES="..passed)\n')
        subprocess.run([str(luau), str(runtime)], check=True)
    print("v1.3 source/static/simulated checks passed. Live death classification and enforcement cause remain unverified.")


if __name__ == "__main__":
    main()
