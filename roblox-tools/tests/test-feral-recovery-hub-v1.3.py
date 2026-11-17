"""Deferred-callback timing, bounded revalidation and clipboard regressions."""
from pathlib import Path
import importlib.util
import os
import re
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("recovery_hub_12", ROOT / "tests/test-feral-recovery-hub-v1.2.py")
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)

TIMING = r'''
local timingFresh=M.fresh
function M.fresh(hp)
    timingFresh(hp)
    M.deferStamina=false; M.deferredSignals={}; M.injectHud=nil
    M.nextPublish=0; M.publishInterval=0; M.report=nil
    M.renderBindings.InjectHUD=nil
    setclipboard=function(value) M.report=value end; toclipboard=nil
end
local immediateAttribute=methods.SetAttribute
function methods:SetAttribute(key,value)
    if M.deferStamina and self==M.character and key=="Stamina" then
        local event=self._signals["@attribute/"..key]
        local changed=self:GetAttribute(key)~=value
        self._signals["@attribute/"..key]=nil
        immediateAttribute(self,key,value)
        self._signals["@attribute/"..key]=event
        if changed and event then M.deferredSignals[#M.deferredSignals+1]=event end
    else immediateAttribute(self,key,value) end
end
local ordinaryStep=M.step
function M.step(seconds)
    ordinaryStep(seconds)
    local queued=M.deferredSignals; M.deferredSignals={}
    for _,event in ipairs(queued) do event:Fire() end
end
function M.copy()
    M.click("COPY STATUS"); assert(type(M.report)=="string"); return M.report
end
function M.forceHud(value)
    M.injectHud=value
    M.renderBindings.InjectHUD={priority=101.5,fn=function()
        if M.injectHud~=nil then M.character:SetAttribute("Stamina",M.injectHud) end
    end}
end
'''

CASES = r'''
case("the actual old v1.2 can falsely stop with deferred attribute callbacks",function()
    M.fresh(); launchPreviousCombinedHub(); M.deferStamina=true; M.publishInterval=.1
    M.player:SetAttribute("HudSprint",true); M.native(); M.enable(); M.frames(240,1/60)
    assert(M.text("Native stamina no longer matches; moving recovery stopped."))
    assert(M.button("3X STAMINA REGEN: OFF")); M.restored()
    M.playerGui:FindFirstChild("FeralRecoveryHubV12"):Destroy()
end)
case("new pre-write sampling stays enabled with the same deferred timing",function()
    M.fresh(); launchHub(); M.deferStamina=true; M.publishInterval=.1
    M.player:SetAttribute("HudSprint",true); M.native(); M.enable(); M.frames(240,1/60)
    assert(M.button("3X STAMINA REGEN: ON"))
    local report=M.copy(); assert(report:find("failure stops: 0",1,true) and report:find("mismatches: 0",1,true))
end)
case("deferred callbacks and ten-Hz publication also work during climbing",function()
    M.fresh(); M.character:SetAttribute("Species","Bear"); launchHub()
    M.deferStamina=true; M.publishInterval=.1; M.nativeDrain=2
    M.character:SetAttribute("FeralClimbLocal",true); M.native(); M.enable(); M.frames(240,1/60)
    assert(M.button("3X STAMINA REGEN: ON") and M.text("climb: adding 3.93 stamina/s"))
end)
case("one post-native mismatch pauses writes and then reconfirms without disabling",function()
    M.fresh(); launchHub(); M.bind(); local writes=#M.internalWrites
    M.forceHud(1); M.frames(1)
    assert(#M.internalWrites==writes and M.copy():find("Stamina phase: VERIFYING",1,true))
    M.injectHud=nil; M.frames(8)
    assert(#M.internalWrites>writes and M.button("3X STAMINA REGEN: ON"))
    assert(M.copy():find("resumed: 1",1,true))
end)
case("persistent mismatch restores the whole feature and freezes a useful failure frame",function()
    M.fresh(); launchHub(); M.bind(); local writes=#M.internalWrites
    M.forceHud(1); M.frames(20); M.restored()
    assert(#M.internalWrites==writes and M.button("3X STAMINA REGEN: OFF"))
    local report=M.copy()
    assert(report:find("mismatch persisted for 1.5s",1,true) and report:find("Failure frame:",1,true))
    assert(report:find("HUD=1.000",1,true) and report:find("pool_before=",1,true))
end)
case("a transient bad attribute overwritten by the native writer causes no false stop",function()
    M.fresh(); launchHub(); M.bind(); M.character:SetAttribute("Stamina",1); M.frames(5)
    assert(M.button("3X STAMINA REGEN: ON") and M.copy():find("failure stops: 0",1,true))
end)
case("controller stoppage still restores both settings immediately",function()
    M.fresh(); launchHub(); M.bind(); M.controller.Enabled=false; local writes=#M.internalWrites
    M.frames(3); M.restored(); assert(#M.internalWrites==writes and M.button("3X STAMINA REGEN: OFF"))
end)
case("status copying never changes gameplay settings or requests",function()
    M.fresh(); launchHub(); M.bind(); local writes=#M.internalWrites; local requests=#M.gameRequests
    local health=M.healthWrites; local attributes=M.attributeWrites; local pool=M.pool
    local report=M.copy()
    assert(report:find("FERAL RECOVERY HUB v1.3 STATUS",1,true) and report:find("PlaceId: 108901361810209",1,true))
    assert(#M.internalWrites==writes and #M.gameRequests==requests and M.healthWrites==health and M.attributeWrites==attributes and M.pool==pool)
end)
case("copying works before any feature has been enabled",function()
    M.fresh(); launchHub(); local reads=M.connectionReads; local report=M.copy()
    assert(report:find("Stamina phase: OFF",1,true) and report:find("Last failure: none",1,true))
    assert(M.connectionReads==reads and #M.internalWrites==0)
end)
case("clipboard fallback uses toclipboard if the first setter errors",function()
    M.fresh(); launchHub(); setclipboard=function() error("SECRET API TEXT") end
    toclipboard=function(value) M.report=value end
    assert(M.copy():find("FERAL RECOVERY HUB v1.3 STATUS",1,true))
end)
case("explicit clipboard failure also falls back without stopping gameplay",function()
    M.fresh(); launchHub(); M.bind(); setclipboard=function() return false end
    toclipboard=function(value) M.report=value end
    local writes=#M.internalWrites; assert(M.copy():find("Stamina phase: ON",1,true))
    assert(#M.internalWrites==writes and M.button("3X STAMINA REGEN: ON"))
end)
case("absent clipboard helpers reveal a selectable text fallback",function()
    M.fresh(); launchHub(); setclipboard=nil; toclipboard=nil; M.click("COPY STATUS")
    local box=M.playerGui:FindFirstChild("FeralRecoveryHubV13"):FindFirstChild("RecoveryPanel")
    local found
    for _,node in ipairs(M.nodes) do if node.Name=="StatusText" and node.Parent and not node._destroyed then found=node end end
    assert(found and found.Visible and found.Text:find("FERAL RECOVERY HUB v1.3 STATUS",1,true))
    assert(M.text("Clipboard unavailable.") and M.needs.STAMINA_REGEN==1.31)
end)
case("short status contains no usernames arbitrary attributes raw API errors or source",function()
    M.fresh(); launchHub(); M.player.Name="SECRET USERNAME"; M.character.Name="SECRET CHARACTER"
    M.character:SetAttribute("Password","SECRET PASSWORD"); M.character:SetAttribute("Amber",87654321)
    M.character:SetAttribute("PrivateMessage","SECRET MESSAGE"); M.bind()
    local report=M.copy()
    for _,text in ipairs({"SECRET USERNAME","SECRET CHARACTER","SECRET PASSWORD","87654321","SECRET MESSAGE","function(","getupvalues("}) do
        assert(not report:find(text,1,true),text)
    end
end)
case("recent samples remain bounded and report omitted history",function()
    M.fresh(); launchHub(); M.bind(); M.player:SetAttribute("HudSprint",nil); M.player:SetAttribute("HudBurst",true)
    M.frames(100); local report=M.copy()
    assert(report:find("Recent HUD samples: 16 retained",1,true) and report:match("[1-9]%d* older samples omitted"))
    assert(#report<8000)
end)
case("the previous failure remains copyable after a manual off and new attempt",function()
    M.fresh(); launchHub(); M.bind(); M.forceHud(1); M.frames(20)
    local failure=M.copy():match("Last failure at [^\n]+")
    M.injectHud=nil; M.enable(); M.frames(15); M.disable()
    assert(failure and M.copy():find(failure,1,true))
end)
case("v1.2 upgrade stops the actual previous tool and opens the new report control",function()
    M.fresh(); launchPreviousCombinedHub(); M.bind(); local writes=#M.internalWrites
    launchHub(); M.frames(3); M.restored()
    assert(not M.playerGui:FindFirstChild("FeralRecoveryHubV12") and M.button("COPY STATUS"))
    assert(M.button("3X STAMINA REGEN: OFF") and #M.internalWrites==writes)
end)
M.close()
print("RECOVERY_HUB_V13_CASES="..passed)
'''


def main():
    luau = os.environ.get("LUAU", "luau")
    source = (ROOT / "feral-recovery-hub-v1.3.lua").read_text()
    for forbidden in ("writefile", "readfile", "decompile", "setreadonly", "hookfunction", "getgc", "getregistry", "GetPlayers", "InvokeServer", "getclipboard"):
        assert forbidden not in source, forbidden
    assert 'GetAttributeChangedSignal("Stamina")' not in source
    assert source.count(":FireServer(") == 1 and 'remote:FireServer("Rest", enabled)' in source
    assert source.count("api.set(") == 1
    assert not re.search(r'SetAttribute\("(?:Stamina|StaminaMax|WolfDbgNoStamina|FeralCombatUntil|FeralDowned)"', source)
    mock = (ROOT / "tests/mock-feral-field-hub-v1.0.luau").read_text().split("-- HUB SCENARIOS", 1)[0]
    extra = prior.prior.previous.EXTRA.replace("FeralRecoveryHubV10", "FeralRecoveryHubV13")
    selected = []
    for section in prior.prior.previous.CASES.split('\ncase("')[1:]:
        if section.split('"',1)[0] in prior.HEALTH_CASES: selected.append('\ncase("'+section)
    regress = []
    for section in prior.CASES.split('\ncase("')[1:]:
        if section.split('"',1)[0] != "a native HUD mismatch or stopped controller stops and restores the feature":
            regress.append('\ncase("'+section)
    regression = ''.join(regress).replace("FeralRecoveryHubV12","FeralRecoveryHubV13")
    native = prior.MORE.replace('        if not M.skipNativePublish then',
        '        if not M.skipNativePublish and M.now>=M.nextPublish then\n'
        '            M.nextPublish=M.now+M.publishInterval')
    assert 'M.nextPublish=M.now+M.publishInterval' in native
    with tempfile.TemporaryDirectory(prefix="feral-timing-status-") as tmp:
        runtime = Path(tmp) / "runtime.luau"
        runtime.write_text(mock + extra + prior.prior.NATIVE + native + TIMING
                           + "\nlocal function launchHub()\n" + source + "\nend\n"
                           + "\nlocal function launchPreviousMovingHub()\n" + (ROOT / "feral-recovery-hub-v1.1.lua").read_text() + "\nend\n"
                           + "\nlocal function launchPreviousCombinedHub()\n" + (ROOT / "feral-recovery-hub-v1.2.lua").read_text() + "\nend\n"
                           + ''.join(selected) + regression + CASES)
        result = subprocess.run([luau, str(runtime)], text=True, capture_output=True)
        print(result.stdout,end="")
        if result.returncode:
            print(result.stderr,end=""); raise SystemExit(result.returncode)
    print("Deferred timing reproduction, revalidation, clipboard and prior checks passed in simulation. Roblox behavior remains unverified.")


if __name__ == "__main__":
    main()
