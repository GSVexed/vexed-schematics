"""v1.1 regression/upgrade tests using the existing engine substitute."""
from pathlib import Path
import importlib.util
import os
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("hub10tests", ROOT / "tests/test-feral-field-hub-v1.0.py")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

ADDITIONAL = r'''
case("health monitor never writes HP and reports decreases separately",function()
    launchHub(); M.step(.25)
    local before=M.healthWrites
    M.humanoid.Health=M.humanoid.Health-1
    local afterDamage=M.healthWrites
    M.step(.25); M.step(5)
    assert(M.healthWrites==afterDamage and afterDamage==before+1)
    local text=nil; setclipboard=function(value) text=value end
    M.click("COPY HUB STATUS")
    assert(text:find("Local HP writer: retired",1,true))
    assert(text:find("Health decreases observed: 1",1,true))
    assert(text:find("Stamina decreases observed: 0",1,true))
    M.click("X")
end)
case("reward shortcut delegates to existing UI without direct claims",function()
    launchHub()
    assert(M.nativeRewards:GetAttribute("unused")==nil)
    M.click("OPEN GAME REWARDS",true)
    assert(type(M.player:GetAttribute("FeralRewardsRequest"))=="number")
    local previous=M.player:GetAttribute("FeralRewardsRequest")
    M.click("OPEN GAME REWARDS",true)
    assert(previous~=M.player:GetAttribute("FeralRewardsRequest"))
    assert(M.remoteCalls==0)
end)
case("reply observer only retains allowlisted labels and no payloads",function()
    M.nativeRewards.OnClientEvent:Fire("state",{private="DO-NOT-COPY"})
    M.nativeRewards.OnClientEvent:Fire("paid","private-user",987)
    M.nativeSlots.OnClientEvent:Fire("coatPoor","PRIVATE-REASON")
    M.nativeSlots.OnClientEvent:Fire("PRIVATE-UNKNOWN-EVENT",{credential="NEVER-EXPORT"})
    local text=nil; setclipboard=function(value) text=value end
    M.click("COPY HUB STATUS")
    assert(text:find("Native reward state seen: true",1,true))
    assert(text:find("Native reward paid notices: 1",1,true))
    assert(text:find("FeralSlots:coatPoor",1,true))
    for _,private in ipairs({"DO-NOT-COPY","private-user","987","PRIVATE-REASON","PRIVATE-UNKNOWN-EVENT","NEVER-EXPORT"}) do
        assert(not text:find(private,1,true),private)
    end
end)
case("observer connections and label history remain bounded",function()
    M.click("OBSERVE NORMAL REWARD",true); M.click("OBSERVE NORMAL REWARD",true)
    local connected=0
    for _,c in ipairs(M.nativeRewards.OnClientEvent.listeners) do if c.Connected then connected=connected+1 end end
    assert(connected==1)
    for i=1,30 do M.nativeSlots.OnClientEvent:Fire("sync",{private=i}) end
    local text=nil; setclipboard=function(value) text=value end
    M.click("COPY HUB STATUS")
    local _,count=text:gsub("FeralSlots:sync","")
    assert(count==12)
    M.click("X")
    for _,c in ipairs(M.nativeRewards.OnClientEvent.listeners) do assert(not c.Connected) end
end)
case("v1.1 closes an actual v1.0 resource loop before upgrading",function()
    launchOldHub()
    M.click("STAMINA EXPERIMENT: OFF"); M.flush()
    M.click("LOCAL HP TRIAL: OFF")
    M.humanoid.Health=80; M.step(.2)
    assert(M.needs.STAMINA_REGEN==250)
    local old=M.playerGui:FindFirstChild("FeralFieldHubV10")
    assert(old)
    launchHub()
    assert(old._destroyed and not M.playerGui:FindFirstChild("FeralFieldHubV10"))
    assert(M.playerGui:FindFirstChild("FeralFieldHubV11"))
    assert(M.needs.STAMINA_REGEN==1.31)
    local healthWrites=M.healthWrites
    M.step(.25); assert(M.healthWrites==healthWrites)
    M.click("X")
end)
'''


def main():
    source = (ROOT / "feral-field-hub-v1.1.lua").read_text()
    luau = Path(os.environ.get("FERAL_LUAU", str(base.DEFAULT_LUAU)))
    subprocess.run([str(luau.with_name("luau-compile")), "--null", str(ROOT / "feral-field-hub-v1.1.lua")], check=True)
    for forbidden in [":FireServer(", ":InvokeServer(", ":GetPlayers(", "decompile(",
                      "getgc(", "hookfunction(", "setreadonly(", 'SetAttribute("Amber"',
                      'SetAttribute("FeralTester"', "hum.Health =", "state.hp", "hpToggle"]:
        assert forbidden not in source, forbidden
    assert 'player:SetAttribute("FeralRewardsRequest", request)' in source
    mock = (ROOT / "tests/mock-feral-field-hub-v1.0.luau").read_text()
    prelude, scenarios = mock.split("-- HUB SCENARIOS", 1)
    prelude += r'''
M.remoteCalls=0
function methods:FireServer() M.remoteCalls=M.remoteCalls+1 end
M.nativeRewards=child("RemoteEvent","FeralRewards",M.services.ReplicatedStorage)
M.nativeSlots=child("RemoteEvent","FeralSlots",M.services.ReplicatedStorage)
M.nativeRewards.OnClientEvent=signal(); M.nativeSlots.OnClientEvent=signal()
'''
    scenarios = scenarios.replace("FeralFieldHubV10", "FeralFieldHubV11")
    scenarios = scenarios.replace("STAMINA EXPERIMENT:", "STAMINA TUNING:")
    scenarios = scenarios.replace("SHOW HIDDEN CARDS IN NATIVE MENU:", "NATIVE MENU CARD VISIBILITY:")
    first = scenarios.index('case("health trial stops at max and does not revive"')
    last = scenarios.index('case("preview removes cloned scripts', first)
    scenarios = scenarios[:first] + scenarios[last:]
    split = scenarios.index('case("startup error reports phase and cleans partial UI"')
    scenarios = scenarios[:split] + ADDITIONAL + scenarios[split:]
    core = source.split("-- BEGIN TESTABLE CORE\n", 1)[1].split("-- END TESTABLE CORE", 1)[0]
    with tempfile.TemporaryDirectory(prefix="feral-hub11-tests-") as tmp:
        path = Path(tmp)
        core_file = path / "core.luau"
        core_file.write_text(core + "\n" + base.CORE_CASES)
        subprocess.run([str(luau), str(core_file)], check=True)
        runtime = path / "runtime.luau"
        old_source = (ROOT / "feral-field-hub-v1.0.lua").read_text()
        runtime.write_text(prelude + "\nlocal function launchHub()\n" + source
                           + "\nend\nlocal function launchOldHub()\n" + old_source
                           + "\nend\n" + scenarios)
        subprocess.run([str(luau), str(runtime)], check=True)
    print("v1.1 source and simulated tests passed. User runtime evidence covers the v1.0 stamina path, not this release's complete UI.")


if __name__ == "__main__":
    main()
