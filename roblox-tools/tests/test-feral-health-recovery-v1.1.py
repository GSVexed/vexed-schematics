"""Recovery condition/lifecycle checks in a substitute, not a Roblox execution."""
from pathlib import Path
import importlib.util
import os
import re
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("health10tests", ROOT / "tests/test-feral-health-recovery-v1.0.py")
previous = importlib.util.module_from_spec(spec)
spec.loader.exec_module(previous)

MORE = r'''
case("each active condition can request recovery at full HP without condition writes",function()
    for _,attribute in ipairs({"FeralBleed","FeralInjury","FeralVenomAmt"}) do
        M.fresh(100); M.character:SetAttribute(attribute,6); launchHealth()
        local writes=#M.writes; local hpWrites=M.healthWrites; local n=M.restCount(true)
        M.arm(); assert(M.restCount(true)==n+1 and M.character:GetAttribute(attribute)==6)
        assert(M.healthWrites==hpWrites)
        for i=writes+1,#M.writes do assert(M.writes[i].key~=attribute) end
        assert(#M.healthReport().current.recovery_reasons==1)
    end
end)
case("clearing the last condition at full HP releases recovery and stays armed",function()
    M.fresh(100); M.character:SetAttribute("FeralBleed",6); launchHealth(); M.arm()
    local n=M.restCount(false); M.character:SetAttribute("FeralBleed",nil); M.step(.2)
    local d=M.healthReport()
    assert(M.restCount(false)==n+1 and d.current.recovery_enabled and not d.current.request_active)
    assert(next(M.renderBindings)==nil and #d.current.recovery_reasons==0)
end)
case("remaining HP deficit keeps recovery active after conditions disappear",function()
    M.fresh(); M.character:SetAttribute("FeralBleed",6); launchHealth(); M.arm()
    local n=M.restCount(false); M.character:SetAttribute("FeralBleed",nil); M.step(.2)
    local d=M.healthReport()
    assert(M.restCount(false)==n and d.current.request_active and d.current.recovery_reasons[1]=="health")
end)
case("condition events distinguish numeric drops and attribute removal",function()
    M.fresh(100); M.character:SetAttribute("FeralBleed",6); launchHealth(); M.arm()
    M.character:SetAttribute("FeralBleed",2); M.character:SetAttribute("FeralBleed",nil); M.step(.2)
    local d=M.healthReport(); local events={}
    for _,e in ipairs(d.timeline.events) do if e.kind=="condition_changed" then events[#events+1]=e end end
    assert(#events==2 and events[1].condition=="bleed" and events[1].condition_change==-4)
    assert(events[2].positive_attribute_removed and events[2].condition_value==nil and not events[2].attribute_present)
    assert(d.condition_counts.bleed.decreases==1 and d.condition_counts.bleed.removals==1)
end)
case("invalid condition values cannot activate a full-health recovery request",function()
    M.fresh(100); launchHealth(); local n=M.restCount(true); M.arm()
    for _,value in ipairs({-1,0,math.huge,0/0,"SECRET",true}) do
        M.character:SetAttribute("FeralBleed",value); M.step(.2)
        assert(M.restCount(true)==n and #M.healthReport().current.recovery_reasons==0)
    end
    assert(not encode(M.healthReport()):find("SECRET",1,true))
end)
case("condition observers disconnect from old characters on respawn",function()
    M.fresh(100); launchHealth(); M.arm(); local old=M.character
    M.spawn(); M.humanoid.Health=100; M.character:SetAttribute("FeralBleed",5); M.step(5.2)
    local before=M.healthReport().timeline.total
    old:SetAttribute("FeralBleed",6)
    assert(M.healthReport().timeline.total==before and M.healthReport().current.request_active)
end)
case("recovery works without reading a config even when stamina cache is frozen",function()
    M.fresh(100); M.character:SetAttribute("FeralInjury",5)
    local target=M.world:FindFirstChild("NeedsConfig"); local original=M.modules[target]
    M.modules[target]=table.freeze(table.clone(original)); local requires=M.requireCalls
    launchHealth(); M.arm(); assert(M.requireCalls==requires and M.healthReport().current.request_active)
    M.click("STAMINA TUNING: OFF"); M.flush(); M.step(.2)
    assert(M.healthReport().current.request_active and M.modules[target].HEALTH_NO_REGEN_IN_COMBAT)
    M.close(); M.modules[target]=original
end)
case("both current condition and HP reasons are preserved",function()
    M.fresh(); M.character:SetAttribute("FeralBleed",3); M.character:SetAttribute("FeralInjury",4)
    M.character:SetAttribute("FeralVenomAmt",5); launchHealth(); M.arm()
    local r=M.healthReport().current.recovery_reasons
    assert(#r==4 and r[1]=="health" and r[2]=="bleed" and r[3]=="injury" and r[4]=="venom")
end)
case("actual health v1.0 upgrade restores its flag and stops old requests first",function()
    M.fresh(); launchHealth10()
    M.click("LOCAL COMBAT REGEN FLAG: OFF"); M.click("STAMINA TUNING: OFF"); M.flush()
    M.click("CONTINUOUS RECOVERY REQUEST: OFF"); M.step(.1)
    local old=M.playerGui:FindFirstChild("FeralHealthRecoveryV10"); assert(old)
    assert(M.needs.HEALTH_NO_REGEN_IN_COMBAT==false and M.needs.STAMINA_REGEN==250)
    local n=M.restCount(false); launchHealth(); M.flush()
    assert(old._destroyed and M.needs.HEALTH_NO_REGEN_IN_COMBAT==true and M.needs.STAMINA_REGEN==1.31)
    assert(M.restCount(false)==n+1 and next(M.renderBindings)==nil)
    n=M.restCount(true); M.step(8); assert(M.restCount(true)==n)
end)
'''


def scenarios():
    retired = {
        "local flag changes only client cache and never sends recovery",
        "late config callback cannot reactivate a stopped health trial",
        "frozen config fails without readonly bypass",
        "missing loaded module API cannot require a new module",
        "stamina and health cache patches coexist and stop independently",
        "closing restores local flags releases request and disconnects mask",
    }
    blocks = re.split(r'(?=^case\(")', previous.CASES, flags=re.M)
    kept = []
    for block in blocks:
        match = re.match(r'case\("([^"]+)"', block)
        if not match or match[1] in retired:
            continue
        block = block.split('\nM.close()\nprint("HEALTH_RUNTIME_CASES=', 1)[0]
        kept.append(block)
    assert len(kept) == 28
    text = "\n".join(kept)
    text = text.replace("CONTINUOUS RECOVERY REQUEST", "RECOVERY ASSIST")
    text = text.replace("FeralHealthRecoveryV10", "FeralHealthRecoveryV11")
    text = text.replace("STOP HEALTH EXPERIMENTS", "STOP & SAVE")
    text = text.replace("feral-health-report/1.0", "feral-health-report/1.1")
    return text + MORE + '\nM.close()\nprint("HEALTH_RUNTIME_CASES="..passed)\n'


def main():
    source = (ROOT / "feral-health-recovery-v1.1.lua").read_text()
    luau = Path(os.environ.get("FERAL_LUAU", str(previous.hub14.base.DEFAULT_LUAU)))
    subprocess.run([str(luau.with_name("luau-compile")), "--null", str(ROOT / "feral-health-recovery-v1.1.lua")], check=True)
    for text in [":GetPlayers(", "decompile(", "getgc(", "hookfunction(", "setreadonly(", ":InvokeServer(",
                 "FeralSelect", "FeralGive", "FeralRewards", "FeralRestTap", "TakeDamage(", "HEALTH_NO_REGEN_IN_COMBAT"]:
        assert text not in source, text
    assert not re.search(r"\b(?:hum|humanoid)\.Health\s*=", source)
    assert source.count(":FireServer(") == 1 and 'remote:FireServer("Rest", enabled)' in source
    assert set(re.findall(r':SetAttribute\("([^"]+)"', source)) == {"WolfRest", "WolfDbgNoStamina"}
    hub14 = previous.hub14
    mock = (ROOT / "tests/mock-feral-field-hub-v1.0.luau").read_text().split("-- HUB SCENARIOS", 1)[0]
    mock += r'''
M.remoteCalls=0
M.nativeRewards=child("RemoteEvent","FeralRewards",M.services.ReplicatedStorage)
M.nativeSlots=child("RemoteEvent","FeralSlots",M.services.ReplicatedStorage)
M.nativeRewards.OnClientEvent=signal(); M.nativeSlots.OnClientEvent=signal()
'''
    mock += hub14.prior.prior.PRELUDE_MORE + hub14.prior.PRELUDE_MORE + hub14.PRELUDE_MORE
    extra = previous.PRELUDE.replace("FeralHealthRecoveryV10", "FeralHealthRecoveryV11")
    extra = extra.replace("feral-health-report/1.0", "feral-health-report/1.1")
    extra = extra.replace("CONTINUOUS RECOVERY REQUEST", "RECOVERY ASSIST")
    mock += extra
    with tempfile.TemporaryDirectory(prefix="feral-health11-tests-") as tmp:
        runtime = Path(tmp) / "runtime.luau"
        blocks = [mock]
        for name, filename in [("launchHealth", "feral-health-recovery-v1.1.lua"),
                               ("launchOld14", "feral-field-hub-v1.4.lua"),
                               ("launchHealth10", "feral-health-recovery-v1.0.lua")]:
            blocks += ["\nlocal function " + name + "()\n", (ROOT / filename).read_text(), "\nend\n"]
        runtime.write_text("".join(blocks) + scenarios())
        subprocess.run([str(luau), str(runtime)], check=True)
    print("Health v1.1 static and simulated checks passed; v1.1 live execution and injury/venom effects remain unverified.")


if __name__ == "__main__":
    main()
