"""Combined 3x recovery, shared-pool modes and lifecycle checks in a substitute engine."""
from pathlib import Path
import importlib.util
import os
import re
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("recovery_hub_11", ROOT / "tests/test-feral-recovery-hub-v1.1.py")
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)

MORE = r'''
local combinedFresh=M.fresh
function M.fresh(hp)
    combinedFresh(hp)
    M.player:SetAttribute("HudTrot",nil)
    M.trotNativeRegen=false; M.skipNativePublish=false; M.holdNativeRecovery=false
    M.nativeDrain=nil; M.nativeMax=50
    M.controller.Enabled=true; M.controller.Disabled=false
end
function M.native()
    M.nativeEnabled=true
    M.renderBindings.NativeGame={priority=101,fn=function(dt)
        if not M.nativeEnabled or M.humanoid.Health<=0 or not M.controller.Enabled then return end
        M.nativeSteps=M.nativeSteps+1
        local char=M.character
        local burst=M.player:GetAttribute("HudBurst")==true or char:GetAttribute("WolfBurst")==true
        local fast=M.player:GetAttribute("HudSprint")==true or burst
        local trot=M.player:GetAttribute("HudTrot")==true or char:GetAttribute("WolfTrot")==true
        if M.nativeDrain~=nil then
            M.pool=math.max(0,M.pool-M.nativeDrain*dt); M.lastDrain=M.now
        elseif fast then
            local cost=M.needs.STAMINA_SPRINT_DRAIN*M.needs.RUN_DRAIN*(burst and M.needs.BURST.DRAIN or 1)
            M.pool=math.max(0,M.pool-cost*dt); M.lastDrain=M.now
        elseif not M.holdNativeRecovery and (not trot or M.trotNativeRegen) then
            local low=char:GetAttribute("Hunger")<20 or char:GetAttribute("Thirst")<20
            local actualRest=char:GetAttribute("WolfRest")==true
            M.pool=math.min(M.nativeMax,M.pool+M.needs.STAMINA_REGEN*(low and M.needs.STAMINA_LOW_NEEDS or 1)
                *(actualRest and M.needs.STAMINA_REST_MULT or 1)*dt)
        end
        if not M.skipNativePublish then
            char:SetAttribute("Stamina",math.floor(M.pool*10+.5)/10)
            char:SetAttribute("StaminaMax",M.nativeMax)
        end
    end}
end
function M.enable() M.click("3X STAMINA REGEN: OFF"); M.flush() end
function M.disable() M.click("3X STAMINA REGEN: ",true) end
function M.bind()
    M.player:SetAttribute("HudSprint",true); M.native(); M.enable(); M.frames(15)
    assert(M.button("3X STAMINA REGEN: ON"),"combined mode should bind")
end
function M.trot(characterFlag)
    M.player:SetAttribute("HudSprint",nil); M.player:SetAttribute("HudBurst",nil)
    M.character:SetAttribute("WolfBurst",nil)
    M.player:SetAttribute("HudTrot",not characterFlag and true or nil)
    M.character:SetAttribute("WolfTrot",characterFlag and true or nil)
end
function M.restored()
    assert(M.needs.STAMINA_REGEN==1.31 and M.needs.STAMINA_REST_MULT==3)
end
'''

CASES = r'''
case("one stamina switch starts off without native inspection or resource writes",function()
    M.fresh(); local reads=M.connectionReads; local hp=M.healthWrites; local attrs=M.attributeWrites
    launchHub(); M.step(.3)
    assert(M.button("3X STAMINA REGEN: OFF") and M.connectionReads==reads and #M.internalWrites==0)
    assert(M.healthWrites==hp and M.attributeWrites==attrs); M.restored()
    assert(not M.text("REST-RATE STAMINA:") and not M.text("MOVING STAMINA REGEN:"))
end)
case("one switch enables the three-times rate and matched pool together",function()
    M.fresh(); launchHub(); M.bind()
    assert(math.abs(M.needs.STAMINA_REGEN-3.93)<.000001 and M.needs.STAMINA_REST_MULT==1)
    assert(#M.internalWrites>0 and M.needs.STAMINA_SPRINT_DRAIN==.94 and M.needs.STAMINA_JUMP_COST==6)
    assert(M.needs.STAMINA_REGEN_DELAY==.8 and M.needs.BURST.ENABLED and M.needs.BURST.DRAIN==3.9)
end)
case("four changing native readings are still required before internal writes",function()
    M.fresh(); launchHub(); M.player:SetAttribute("HudSprint",true); M.native(); M.enable()
    M.frames(3); assert(#M.internalWrites==0 and M.button("3X STAMINA REGEN: BINDING"))
    M.frames(12); assert(#M.internalWrites>0 and M.invalidWrites==0)
end)
case("sprint gains equal three-times recovery minus the native sprint cost",function()
    M.fresh(); launchHub(); M.bind(); local before=M.pool; M.frames(10)
    assert(math.abs(M.pool-before-(3.93-.94*.9))<.000001)
end)
case("Burst still pays its native cost while receiving three-times recovery",function()
    M.fresh(); launchHub(); M.bind(); M.player:SetAttribute("HudSprint",nil); M.player:SetAttribute("HudBurst",true)
    local before=M.pool; M.frames(10)
    assert(math.abs(M.pool-before-(3.93-.94*.9*3.9))<.000001)
end)
case("normal walking receives exactly three-times native recovery without duplicate gain",function()
    M.fresh(); launchHub(); M.bind(); M.player:SetAttribute("HudSprint",nil)
    local before=M.pool; local writes=#M.internalWrites; M.frames(10)
    assert(math.abs(M.pool-before-3.93)<.000001 and #M.internalWrites==writes)
end)
case("standing native recovery stays at three times",function()
    M.fresh(); launchHub(); M.bind(); M.player:SetAttribute("HudSprint",nil); M.humanoid.MoveDirection=vec()
    local before=M.pool; local writes=#M.internalWrites; M.frames(10)
    assert(math.abs(M.pool-before-3.93)<.000001 and #M.internalWrites==writes)
end)
case("a flat native Trot pool receives three-times recovery",function()
    M.fresh(); launchHub(); M.bind(); M.trot(); local before=M.pool; M.frames(10)
    assert(math.abs(M.pool-before-3.93)<.000001 and M.text("trot: adding 3.93 stamina/s"))
end)
case("character Trot flag also selects the flat-pool recovery path",function()
    M.fresh(); launchHub(); M.bind(); M.trot(true); local before=M.pool; M.frames(10)
    assert(math.abs(M.pool-before-3.93)<.000001)
end)
case("positive native Trot recovery is not counted twice",function()
    M.fresh(); launchHub(); M.bind(); M.trot(); M.trotNativeRegen=true
    local before=M.pool; local writes=#M.internalWrites; M.frames(10)
    assert(math.abs(M.pool-before-3.93)<.000001 and #M.internalWrites==writes)
end)
case("a flat delay interval while standing or walking still receives three-times recovery",function()
    for _,moving in ipairs({false,true}) do
        M.fresh(); launchHub(); M.bind(); M.player:SetAttribute("HudSprint",nil); M.holdNativeRecovery=true
        M.humanoid.MoveDirection=moving and vec(0,0,-1) or vec()
        local before=M.pool; M.frames(10); assert(math.abs(M.pool-before-3.93)<.000001)
        assert(M.needs.STAMINA_REGEN_DELAY==.8)
    end
end)
case("Bear climbing receives recovery alongside its simulated climbing cost",function()
    M.fresh(); M.character:SetAttribute("Species","Bear"); launchHub(); M.bind()
    M.player:SetAttribute("HudSprint",nil); M.character:SetAttribute("FeralClimbLocal",true)
    M.humanoid.MoveDirection=vec(); M.nativeDrain=2
    local before=M.pool; M.frames(10)
    assert(math.abs(M.pool-before-(3.93-2))<.000001 and M.text("climb: adding 3.93 stamina/s"))
end)
case("other shared-pool movement paths no longer pause added recovery",function()
    for _,key in ipairs({"FeralFlyLocal","FeralSwimLocal","FeralUnderwater","FeralDiving","FeralBurrowed","FeralPinned"}) do
        M.fresh(); launchHub(); M.bind(); M.player:SetAttribute("HudSprint",nil)
        M.character:SetAttribute(key,true); M.nativeDrain=2
        local before=M.pool; M.frames(10); assert(math.abs(M.pool-before-(3.93-2))<.000001,key)
    end
end)
case("venom no longer disables the requested continuous stamina recovery",function()
    M.fresh(); launchHub(); M.bind(); M.character:SetAttribute("FeralVenomAmt",8); M.nativeDrain=2
    local before=M.pool; M.frames(10); assert(math.abs(M.pool-before-(3.93-2))<.000001)
    assert(M.character:GetAttribute("FeralVenomAmt")==8)
end)
case("three-times recovery still includes the normal low-needs penalty",function()
    M.fresh(); launchHub(); M.bind(); M.character:SetAttribute("Hunger",5)
    local before=M.pool; M.frames(10)
    assert(math.abs(M.pool-before-(3.93*.5-.94*.9))<.000001)
end)
case("actual rest cannot stack the configured multiplier to nine times",function()
    M.fresh(); launchHub(); M.bind(); M.player:SetAttribute("HudSprint",nil); M.character:SetAttribute("WolfRest",true)
    local before=M.pool; M.frames(10); assert(math.abs(M.pool-before-3.93)<.000001)
end)
case("menus and downed state pause increments while keeping the feature armed",function()
    for _,kind in ipairs({"menu","downed"}) do
        M.fresh(); launchHub(); M.bind()
        if kind=="menu" then M.player:SetAttribute("FeralMenuOpen",true) else M.character:SetAttribute("FeralDowned",true) end
        local writes=#M.internalWrites; M.frames(3); assert(#M.internalWrites==writes)
        assert(M.button("3X STAMINA REGEN: ON"))
    end
end)
case("death cannot trigger another pool write",function()
    M.fresh(); launchHub(); M.bind(); M.humanoid.Health=0; local writes=#M.internalWrites
    M.frames(20); assert(#M.internalWrites==writes)
end)
case("one off action stops increments and restores both config fields",function()
    M.fresh(); launchHub(); M.bind(); local before=M.pool; local writes=#M.internalWrites
    M.disable(); assert(M.pool==before); M.frames(3)
    M.restored(); assert(#M.internalWrites==writes and M.button("3X STAMINA REGEN: OFF"))
end)
case("missing required API leaves the whole feature off without patching rates",function()
    M.fresh(); launchHub(); local getter=getconnections; getconnections=nil; local reads=M.requireCalls
    M.enable(); M.restored(); assert(M.requireCalls==reads and M.text("Unavailable: getconnections"))
    assert(M.button("3X STAMINA REGEN: OFF")); getconnections=getter
end)
case("missing loaded-cache API cannot start a new module or half-enable the feature",function()
    M.fresh(); launchHub(); local getter=getloadedmodules; getloadedmodules=nil; local reads=M.requireCalls
    M.enable(); M.restored(); assert(M.requireCalls==reads and M.button("3X STAMINA REGEN: OFF"))
    getloadedmodules=getter
end)
case("frozen config fails cleanly without making it writable",function()
    M.fresh(); local module=M.world:FindFirstChild("NeedsConfig"); local original=M.modules[module]
    M.modules[module]=table.freeze(table.clone(M.needs)); launchHub(); M.enable()
    assert(M.modules[module].STAMINA_REGEN==1.31 and M.modules[module].STAMINA_REST_MULT==3)
    assert(M.button("3X STAMINA REGEN: OFF")); M.close(); M.modules[module]=original
end)
case("failure writing the second config field rolls the first field back",function()
    M.fresh(); local module=M.world:FindFirstChild("NeedsConfig"); local original=M.modules[module]
    local backing=table.clone(M.needs)
    M.modules[module]=setmetatable({},{__index=backing,__newindex=function(_,key,value)
        if key=="STAMINA_REGEN" then error("readonly") end; backing[key]=value
    end})
    launchHub(); M.enable(); assert(backing.STAMINA_REST_MULT==3 and backing.STAMINA_REGEN==1.31)
    assert(M.button("3X STAMINA REGEN: OFF")); M.close(); M.modules[module]=original
end)
case("external config edits stop the whole feature and preserve the external value",function()
    M.fresh(); launchHub(); M.bind(); M.needs.STAMINA_REGEN=2.5; local writes=#M.internalWrites; M.frames(3)
    assert(M.needs.STAMINA_REGEN==2.5 and M.needs.STAMINA_REST_MULT==3 and #M.internalWrites==writes)
    assert(M.button("3X STAMINA REGEN: OFF"))
end)
case("unrelated callbacks and ambiguous callbacks cannot trigger internal writes",function()
    M.fresh(); launchHub(); local foreign=function() end
    M.meta[foreign]={script=M.foreignController,constants={"Jumping","STAMINA_JUMP_COST"},foreign=true}
    M.nativeConnections={{Function=foreign}}; local reads=M.foreignReads
    M.enable(); M.frames(110); M.restored(); assert(M.foreignReads==reads and #M.internalWrites==0)
    M.fresh(); launchHub(); local second=function() end
    M.meta[second]={script=M.controller,constants={"Jumping","STAMINA_JUMP_COST"},char=M.character,hum=M.humanoid,root=M.root,config=M.needs}
    M.nativeConnections[#M.nativeConnections+1]={Function=second}; M.enable()
    M.restored(); assert(#M.internalWrites==0 and M.button("3X STAMINA REGEN: OFF"))
end)
case("ambiguous numeric stamina cells stop and restore the full feature",function()
    M.fresh(); launchHub(); M.mirrorPool=true; M.player:SetAttribute("HudSprint",true); M.native(); M.enable(); M.frames(15)
    M.restored(); assert(#M.internalWrites==0 and M.button("3X STAMINA REGEN: OFF"))
end)
case("setter errors or no-op writes restore both parts instead of leaving walking-only tuning",function()
    for _,key in ipairs({"setterNoop","setterError","upvalueError"}) do
        M.fresh(); launchHub(); M.bind(); M[key]=true; local writes=#M.internalWrites; M.frames(2)
        M.restored(); assert(M.button("3X STAMINA REGEN: OFF") and #M.internalWrites==writes,key)
    end
end)
case("a native HUD mismatch or stopped controller stops and restores the feature",function()
    M.fresh(); launchHub(); M.bind(); local writes=#M.internalWrites
    M.character:SetAttribute("Stamina",1); M.frames(3); M.restored(); assert(#M.internalWrites==writes)
    M.fresh(); launchHub(); M.bind(); M.controller.Enabled=false; writes=#M.internalWrites; M.frames(3)
    M.restored(); assert(#M.internalWrites==writes and M.button("3X STAMINA REGEN: OFF"))
end)
case("long frames cannot produce a catch-up refill and gains remain capped",function()
    M.fresh(); launchHub(); M.bind(); M.step(3)
    local write=M.internalWrites[#M.internalWrites]; assert(write.after-write.before<=3.93*.1+.000001)
    M.pool=49.96; M.nativeDrain=2; M.frames(10); assert(M.pool<=49.95+.000001)
end)
case("flat recovery resumes after a long stationary HUD interval",function()
    M.fresh(); launchHub(); M.bind(); M.trot(); M.humanoid.MoveDirection=vec()
    M.player:SetAttribute("FeralMenuOpen",true); M.frames(30); M.player:SetAttribute("FeralMenuOpen",nil)
    local before=M.pool; M.frames(10); assert(math.abs(M.pool-before-3.93)<.000001)
end)
case("a stopped HUD publisher cannot drive repeated stale flat-pool refill",function()
    M.fresh(); launchHub(); M.bind(); M.trot(); M.player:SetAttribute("FeralMenuOpen",true); M.frames(30)
    M.skipNativePublish=true; M.player:SetAttribute("FeralMenuOpen",nil); local before=M.pool; M.frames(50)
    assert(M.pool-before<=.051+3.93*.1+.000001)
end)
case("cancelled and closed pending cache results cannot reactivate either part",function()
    M.fresh(); launchHub(); M.click("3X STAMINA REGEN: OFF"); M.disable(); M.flush(); M.restored()
    assert(M.button("3X STAMINA REGEN: OFF"))
    M.click("3X STAMINA REGEN: OFF"); M.close(); M.flush(); M.restored()
end)
case("rapid off-on toggles share one cache job and honor the latest request",function()
    M.fresh(); launchHub(); local reads=M.requireCalls
    M.click("3X STAMINA REGEN: OFF"); M.disable(); M.click("3X STAMINA REGEN: OFF"); M.flush()
    assert(M.requireCalls==reads+1 and math.abs(M.needs.STAMINA_REGEN-3.93)<.000001)
end)
case("respawn preserves the combined rate but requires a new callback match",function()
    M.fresh(); launchHub(); M.bind(); local oldFn=M.nativeFunction; local writes=#M.internalWrites
    M.spawn(); M.character:SetAttribute("IsWolf",true); M.character:SetAttribute("Hunger",100); M.character:SetAttribute("Thirst",100)
    M.humanoid.StateChanged=signal(); M.humanoid.MoveDirection=vec(0,0,-1); M.pool=40
    M.frames(5); assert(#M.internalWrites==writes and M.button("3X STAMINA REGEN: BINDING"))
    M.attachNative(); M.frames(35); assert(#M.internalWrites>writes)
    for i=writes+1,#M.internalWrites do assert(M.internalWrites[i].fn~=oldFn) end
    assert(math.abs(M.needs.STAMINA_REGEN-3.93)<.000001)
end)
case("all-off and close restore original config and stop all internal writes",function()
    M.fresh(); launchHub(); M.arm(); M.bind(); local writes=#M.internalWrites
    M.click("TURN EVERYTHING OFF"); M.frames(3); M.restored(); assert(#M.internalWrites==writes)
    assert(M.restCount(false)>=1 and M.button("3X STAMINA REGEN: OFF"))
    M.enable(); M.frames(15); writes=#M.internalWrites; M.click("X"); M.frames(3)
    M.restored(); assert(#M.internalWrites==writes and not M.playerGui:FindFirstChild("FeralRecoveryHubV12"))
end)
case("rerun shuts a bound instance down before opening the combined control off",function()
    M.fresh(); launchHub(); M.bind(); local writes=#M.internalWrites
    launchHub(); M.frames(3); M.restored(); assert(#M.internalWrites==writes and M.button("3X STAMINA REGEN: OFF"))
end)
case("upgrade from the actual v1.1 restores both old controls before the new default-off switch",function()
    M.fresh(); launchPreviousMovingHub(); M.native(); M.player:SetAttribute("HudSprint",true)
    M.click("REST-RATE STAMINA: OFF"); M.flush(); M.click("MOVING STAMINA REGEN: OFF"); M.flush(); M.frames(15)
    assert(M.button("MOVING STAMINA REGEN: ON")); local writes=#M.internalWrites
    launchHub(); M.frames(3); M.restored()
    assert(not M.playerGui:FindFirstChild("FeralRecoveryHubV11") and M.button("3X STAMINA REGEN: OFF"))
    assert(#M.internalWrites==writes)
end)
M.close()
print("RECOVERY_HUB_V12_CASES="..passed)
'''

HEALTH_CASES = {
    "native Rest works independently in combat and Burst without HP writes",
    "true recovery packets are throttled to at most one each five seconds",
    "server rest echoes are masked before native animation render priority",
    "full HP standby wakes for a deficit and releases at full HP",
    "full HP conditions can request recovery without writing the condition",
    "initial native rest belongs to the player and is not seized",
    "menu downed and dead standby do not revive or erase downed state",
    "unannounced character replacement never receives old false cleanup",
    "missing mask API fails before any true request",
    "mask failure after activation stops requests and releases the lease",
    "unavailable remote stops recovery without a retry loop",
}


def main():
    luau = os.environ.get("LUAU", "luau")
    source = (ROOT / "feral-recovery-hub-v1.2.lua").read_text()
    for forbidden in ("writefile", "readfile", "decompile", "setreadonly", "hookfunction", "getgc", "getregistry", "GetPlayers", "InvokeServer"):
        assert forbidden not in source, forbidden
    assert not re.search(r"(?:hum|humanoid)\.Health\s*=", source)
    assert not re.search(r'SetAttribute\("(?:Stamina|StaminaMax|WolfDbgNoStamina|FeralCombatUntil|FeralDowned|HudTrot|WolfTrot)"', source)
    assert source.count(":FireServer(") == 1 and 'remote:FireServer("Rest", enabled)' in source
    assert source.count("api.set(") == 1 and 'button("REST-RATE' not in source and 'button("MOVING STAMINA' not in source
    mock = (ROOT / "tests/mock-feral-field-hub-v1.0.luau").read_text().split("-- HUB SCENARIOS", 1)[0]
    extra = prior.previous.EXTRA.replace("FeralRecoveryHubV10", "FeralRecoveryHubV12")
    selected = []
    for section in prior.previous.CASES.split('\ncase("')[1:]:
        name = section.split('"', 1)[0]
        if name in HEALTH_CASES:
            selected.append('\ncase("' + section)
    assert len(selected) == len(HEALTH_CASES)
    with tempfile.TemporaryDirectory(prefix="feral-combined-regen-") as tmp:
        runtime = Path(tmp) / "runtime.luau"
        runtime.write_text(mock + extra + prior.NATIVE + MORE + "\nlocal function launchHub()\n" + source + "\nend\n"
                           + "\nlocal function launchPreviousMovingHub()\n" + (ROOT / "feral-recovery-hub-v1.1.lua").read_text() + "\nend\n"
                           + ''.join(selected) + CASES)
        result = subprocess.run([luau, str(runtime)], text=True, capture_output=True)
        print(result.stdout, end="")
        if result.returncode:
            print(result.stderr, end="")
            raise SystemExit(result.returncode)
    print("Combined 3x, climbing/shared-pool and prior health checks passed in simulation. New v1.2 gameplay is unverified.")


if __name__ == "__main__":
    main()
