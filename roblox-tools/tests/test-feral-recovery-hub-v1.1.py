"""Synthetic native-pool integration and lifecycle faults, not Roblox validation."""
from pathlib import Path
import importlib.util
import os
import re
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("recovery_hub_10", ROOT / "tests/test-feral-recovery-hub-v1.0.py")
previous = importlib.util.module_from_spec(spec)
spec.loader.exec_module(previous)

NATIVE = r'''
M.scripts=child("PlayerScripts","PlayerScripts",M.player)
M.controller=child("LocalScript","WolfController",M.scripts)
M.foreignController=child("LocalScript","UnrelatedObserver",M.scripts)
M.meta={}; M.internalWrites={}; M.invalidWrites=0; M.connectionReads=0; M.foreignReads=0
local vanillaFenv=getfenv
function getfenv(fn)
    if M.meta[fn] then return {script=M.meta[fn].script} end
    return vanillaFenv(fn)
end
function getconnections(event)
    assert(event==M.humanoid.StateChanged,"only own native state signal may be inspected")
    M.connectionReads=M.connectionReads+1
    if M.connectionError then error("API failed") end
    return M.nativeConnections
end
function getconstants(fn)
    local meta=assert(M.meta[fn])
    if meta.script~=M.controller then M.foreignReads=M.foreignReads+1 end
    return meta.constants
end
function getupvalues(fn)
    if M.upvalueError then error("API failed") end
    local meta=assert(M.meta[fn])
    if meta.script~=M.controller then M.foreignReads=M.foreignReads+1 end
    if meta.foreign then return {[1]=M.pool,[2]=M.needs,[3]=M.humanoid} end
    return {[1]=M.pool,[2]=M.lastDrain,[3]=M.configChanged or meta.config,[4]=meta.hum,
        [5]=M.mirrorPool and M.pool or 12345,[6]=meta.char,[7]=meta.root}
end
function setupvalue(fn,index,value)
    if M.setterError then error("API denied") end
    if M.setterNoop then return end
    assert(M.meta[fn] and M.meta[fn].script==M.controller)
    assert(M.meta[fn].hum==M.humanoid,"old-character upvalue write")
    if index~=1 then M.invalidWrites=M.invalidWrites+1; error("wrong cell") end
    M.internalWrites[#M.internalWrites+1]={fn=fn,index=index,before=M.pool,after=value,t=M.now}
    M.pool=value
end
local priorFresh=M.fresh
function M.fresh(hp)
    priorFresh(hp)
    M.renderBindings.NativeGame=nil; M.nativeEnabled=false
    M.nativeConnections={}; M.internalWrites={}; M.invalidWrites=0
    M.connectionError=false; M.upvalueError=false; M.setterError=false; M.setterNoop=false
    M.configChanged=nil; M.mirrorPool=false; M.lastDrain=0; M.pool=40; M.nativeSteps=0
    M.needs.LOW_NEED_AT=20; M.needs.RUN_DRAIN=.9
    M.character:SetAttribute("IsWolf",true); M.character:SetAttribute("Hunger",100); M.character:SetAttribute("Thirst",100)
    M.humanoid.StateChanged=signal(); M.humanoid.MoveDirection=vec(0,0,-1)
    M.attachNative()
end
function M.attachNative()
    local capturedHum=M.humanoid
    local fn=function() return capturedHum end
    M.nativeFunction=fn
    M.meta[fn]={script=M.controller,constants={"Jumping","STAMINA_JUMP_COST","clock","max"},
        char=M.character,hum=M.humanoid,root=M.root,config=M.needs}
    M.nativeConnections={{Function=fn}}
end
function M.native()
    M.nativeEnabled=true
    M.renderBindings.NativeGame={priority=101,fn=function(dt)
        if not M.nativeEnabled or M.humanoid.Health<=0 then return end
        M.nativeSteps=M.nativeSteps+1
        local char=M.character
        local fast=M.player:GetAttribute("HudSprint")==true or M.player:GetAttribute("HudBurst")==true or char:GetAttribute("WolfBurst")==true
        local poolMax=char:GetAttribute("StaminaMax") or 50
        if fast then
            local burst=M.player:GetAttribute("HudBurst")==true or char:GetAttribute("WolfBurst")==true
            local cost=M.needs.STAMINA_SPRINT_DRAIN*M.needs.RUN_DRAIN*(burst and M.needs.BURST.DRAIN or 1)
            M.pool=math.max(0,M.pool-cost*dt); M.lastDrain=M.now
        else
            local low=char:GetAttribute("Hunger")<20 or char:GetAttribute("Thirst")<20
            M.pool=math.min(poolMax,M.pool+M.needs.STAMINA_REGEN*(low and M.needs.STAMINA_LOW_NEEDS or 1)*dt)
        end
        char:SetAttribute("Stamina",math.floor(M.pool*10+.5)/10)
        char:SetAttribute("StaminaMax",poolMax)
    end}
end
function M.step(seconds)
    M.now=M.now+seconds; M.flush(); M.services.RunService.Heartbeat:Fire(seconds)
    local list={}; for _,binding in pairs(M.renderBindings) do list[#list+1]=binding end
    table.sort(list,function(a,b) return a.priority<b.priority end)
    for _,binding in ipairs(list) do binding.fn(seconds) end
    M.restPose=M.character and M.character:GetAttribute("WolfRest")==true
end
function M.frames(n,dt) for _=1,n do M.step(dt or .1) end end
function M.moveOn()
    M.click("MOVING STAMINA REGEN: OFF"); M.flush()
end
function M.bind()
    M.player:SetAttribute("HudSprint",true); M.native(); M.moveOn(); M.frames(15)
    assert(M.button("MOVING STAMINA REGEN: ON"),"binding should finish")
end
'''

CASES = r'''
case("new mode starts off without inspecting native callbacks",function()
    M.fresh(); local reads=M.connectionReads; launchHub(); M.step(.3)
    assert(M.button("MOVING STAMINA REGEN: OFF") and M.connectionReads==reads and #M.internalWrites==0)
end)
case("no upvalue writes occur before four changing native HUD samples",function()
    M.fresh(); launchHub(); M.player:SetAttribute("HudSprint",true); M.native(); M.moveOn()
    M.frames(3); assert(#M.internalWrites==0 and M.button("MOVING STAMINA REGEN: BINDING"))
    M.frames(15); assert(#M.internalWrites>0 and M.invalidWrites==0)
end)
case("normal regen is added after native sprint cost",function()
    M.fresh(); launchHub(); M.bind(); local before=M.pool
    M.frames(10)
    local expected=before+10*(1.31-.94*.9)*.1
    assert(math.abs(M.pool-expected)<.000001 and M.invalidWrites==0)
    assert(M.needs.STAMINA_SPRINT_DRAIN==.94 and M.needs.STAMINA_JUMP_COST==6 and M.needs.BURST.ENABLED)
end)
case("one-times recovery extends Burst while Burst still has a net cost",function()
    M.fresh(); launchHub(); M.bind(); M.player:SetAttribute("HudSprint",nil); M.player:SetAttribute("HudBurst",true)
    local before=M.pool; M.frames(10)
    local expected=before+10*(1.31-.94*.9*3.9)*.1
    assert(math.abs(M.pool-expected)<.000001 and M.pool<before)
end)
case("walking native recovery is not counted a second time",function()
    M.fresh(); launchHub(); M.bind(); M.player:SetAttribute("HudSprint",nil)
    local before=M.pool; local writes=#M.internalWrites; M.frames(10)
    assert(math.abs(M.pool-before-1.31)<.000001 and #M.internalWrites==writes)
end)
case("both stamina controls can share one pending cache job",function()
    M.fresh(); launchHub(); M.native(); M.player:SetAttribute("HudSprint",true); local reads=M.requireCalls
    M.click("REST-RATE STAMINA: OFF"); M.click("MOVING STAMINA REGEN: OFF"); M.flush(); M.frames(15)
    assert(M.requireCalls==reads+1 and M.button("REST-RATE STAMINA: ON") and M.button("MOVING STAMINA REGEN: ON"))
    local last=M.internalWrites[#M.internalWrites]; assert(math.abs(last.after-last.before-.393)<.000001)
end)
case("switching the rest-rate control off keeps moving regen at its original rate",function()
    M.fresh(); launchHub(); M.stamina(); M.bind(); M.click("REST-RATE STAMINA: ON"); M.frames(1)
    local last=M.internalWrites[#M.internalWrites]; assert(math.abs(last.after-last.before-.131)<.000001)
    assert(M.needs.STAMINA_REST_MULT==3 and M.needs.STAMINA_REGEN==1.31)
end)
case("low-needs penalty still reduces the added recovery",function()
    M.fresh(); launchHub(); M.bind(); M.character:SetAttribute("Hunger",5); M.frames(1)
    local last=M.internalWrites[#M.internalWrites]; assert(math.abs(last.after-last.before-.0655)<.000001)
end)
case("menu downed venom and special movement pause added recovery",function()
    for _,key in ipairs({"FeralDowned","FeralSwimLocal","FeralFlyLocal","FeralClimbLocal","FeralUnderwater","FeralPinned","FeralVenomAmt"}) do
        M.fresh(); launchHub(); M.bind(); M.character:SetAttribute(key,key=="FeralVenomAmt" and 4 or true)
        local writes=#M.internalWrites; M.frames(3); assert(#M.internalWrites==writes,key)
    end
    M.fresh(); launchHub(); M.bind(); M.player:SetAttribute("FeralMenuOpen",true)
    local writes=#M.internalWrites; M.frames(3); assert(#M.internalWrites==writes)
end)
case("sudden death cannot trigger another pool write",function()
    M.fresh(); launchHub(); M.bind(); M.humanoid.Health=0; local writes=#M.internalWrites
    M.frames(20); assert(#M.internalWrites==writes)
end)
case("missing APIs produce a concrete unavailable status without writes",function()
    M.fresh(); launchHub(); local getter=getconnections; getconnections=nil
    M.moveOn(); assert(#M.internalWrites==0 and M.button("MOVING STAMINA REGEN: OFF"))
    assert(M.text("Unavailable: getconnections")); getconnections=getter
end)
case("unrelated script callbacks are rejected before reading their constants or upvalues",function()
    M.fresh(); launchHub(); local foreign=function() end
    M.meta[foreign]={script=M.foreignController,constants={"Jumping","STAMINA_JUMP_COST"},foreign=true}
    M.nativeConnections={{Function=foreign}}; local reads=M.foreignReads
    M.moveOn(); M.frames(110)
    assert(M.foreignReads==reads and #M.internalWrites==0 and M.button("MOVING STAMINA REGEN: OFF"))
end)
case("the controller callback must also capture the exact loaded config",function()
    M.fresh(); launchHub(); M.configChanged={}; M.moveOn(); M.frames(110)
    assert(#M.internalWrites==0 and M.button("MOVING STAMINA REGEN: OFF"))
end)
case("duplicate matching functions are rejected rather than guessed",function()
    M.fresh(); launchHub(); local second=function() end
    M.meta[second]={script=M.controller,constants={"Jumping","STAMINA_JUMP_COST"},char=M.character,hum=M.humanoid,root=M.root,config=M.needs}
    M.nativeConnections[#M.nativeConnections+1]={Function=second}; M.moveOn()
    assert(#M.internalWrites==0 and M.button("MOVING STAMINA REGEN: OFF"))
end)
case("ambiguous numeric cells are rejected before the first write",function()
    M.fresh(); launchHub(); M.mirrorPool=true; M.player:SetAttribute("HudSprint",true); M.native(); M.moveOn(); M.frames(15)
    assert(#M.internalWrites==0 and M.text("Stamina match is ambiguous"))
end)
case("no-op setter and API errors stop the option",function()
    for _,key in ipairs({"setterNoop","setterError","upvalueError"}) do
        M.fresh(); launchHub(); M.bind(); M[key]=true; local writes=#M.internalWrites; M.frames(2)
        assert(M.button("MOVING STAMINA REGEN: OFF") and #M.internalWrites==writes,key)
    end
end)
case("a changed native stamina echo stops writes instead of pinning the HUD",function()
    M.fresh(); launchHub(); M.bind(); local writes=#M.internalWrites
    M.character:SetAttribute("Stamina",1); M.frames(2)
    assert(#M.internalWrites==writes and M.button("MOVING STAMINA REGEN: OFF"))
end)
case("a replaced native controller stops access to the old callback",function()
    M.fresh(); launchHub(); M.bind(); M.controller.Parent=nil; local writes=#M.internalWrites; M.frames(2)
    assert(#M.internalWrites==writes and M.button("MOVING STAMINA REGEN: OFF"))
    M.controller.Parent=M.scripts
end)
case("large frame gaps cannot produce catch-up refill",function()
    M.fresh(); launchHub(); M.bind(); M.step(3)
    local last=M.internalWrites[#M.internalWrites]; assert(last.after-last.before<=1.31*.1+.000001)
end)
case("pool gain is clamped below the rounded maximum",function()
    M.fresh(); launchHub(); M.stamina(); M.bind()
    M.pool=49.96; M.frames(10)
    assert(M.pool<=49.95+.000001)
    for _,write in ipairs(M.internalWrites) do assert(write.after<=49.95+.000001) end
end)
case("stopping moving regen preserves the current pool and separate rest-rate option",function()
    M.fresh(); launchHub(); M.stamina(); M.bind(); local before=M.pool; local writes=#M.internalWrites
    M.click("MOVING STAMINA REGEN: ON"); assert(M.pool==before)
    M.frames(3); assert(#M.internalWrites==writes and M.needs.STAMINA_REST_MULT==1)
end)
case("cancelled cache results and closed menus cannot start moving regen",function()
    M.fresh(); launchHub(); M.click("MOVING STAMINA REGEN: OFF"); M.click("MOVING STAMINA REGEN: BINDING"); M.flush()
    assert(#M.internalWrites==0 and M.button("MOVING STAMINA REGEN: OFF"))
    M.click("MOVING STAMINA REGEN: OFF"); M.close(); M.flush(); M.frames(3)
    assert(#M.internalWrites==0)
end)
case("all-off unbinds internal access and stops owned recovery",function()
    M.fresh(); launchHub(); M.arm(); M.stamina(); M.bind(); local writes=#M.internalWrites
    M.click("TURN EVERYTHING OFF"); M.frames(3)
    assert(#M.internalWrites==writes and M.needs.STAMINA_REGEN==1.31 and M.needs.STAMINA_REST_MULT==3)
    for _,binding in pairs(M.renderBindings) do assert(binding.priority==101) end
end)
case("respawn waits for the new native callback and requires a fresh pool match",function()
    M.fresh(); launchHub(); M.bind(); local oldFn=M.nativeFunction; local writes=#M.internalWrites
    M.spawn(); M.character:SetAttribute("IsWolf",true); M.character:SetAttribute("Hunger",100); M.character:SetAttribute("Thirst",100)
    M.humanoid.StateChanged=signal(); M.humanoid.MoveDirection=vec(0,0,-1); M.pool=40
    M.frames(5); assert(#M.internalWrites==writes and M.button("MOVING STAMINA REGEN: BINDING"))
    M.attachNative(); M.frames(35); assert(#M.internalWrites>writes)
    for i=writes+1,#M.internalWrites do assert(M.internalWrites[i].fn~=oldFn) end
end)
case("turning off a separate rate request cannot cancel the moving cache request",function()
    M.fresh(); launchHub(); M.native(); M.player:SetAttribute("HudSprint",true)
    M.click("REST-RATE STAMINA: OFF"); M.click("MOVING STAMINA REGEN: OFF"); M.click("REST-RATE STAMINA: CHECKING")
    M.flush(); M.frames(15)
    assert(M.needs.STAMINA_REGEN==1.31 and M.button("MOVING STAMINA REGEN: ON"))
end)
case("rerun closes a bound mode before the new menu opens off",function()
    M.fresh(); launchHub(); M.bind(); local writes=#M.internalWrites
    launchHub(); M.frames(5)
    assert(#M.internalWrites==writes and M.button("MOVING STAMINA REGEN: OFF"))
end)
case("v1.0 upgrade restores its walking-rate changes before v1.1 opens",function()
    M.fresh(); launchPreviousHub(); M.click("REST-RATE STAMINA: OFF"); M.flush()
    assert(M.needs.STAMINA_REST_MULT==1)
    launchHub(); assert(not M.playerGui:FindFirstChild("FeralRecoveryHubV10"))
    assert(M.needs.STAMINA_REST_MULT==3 and M.button("MOVING STAMINA REGEN: OFF"))
end)
M.close()
print("RECOVERY_HUB_V11_CASES="..passed)
'''


def main():
    luau = os.environ.get("LUAU", "luau")
    source = (ROOT / "feral-recovery-hub-v1.1.lua").read_text()
    for forbidden in ("writefile", "readfile", "decompile", "setreadonly", "hookfunction", "getgc", "getregistry", "GetPlayers", "InvokeServer"):
        assert forbidden not in source, forbidden
    assert not re.search(r"(?:hum|humanoid)\.Health\s*=", source)
    assert not re.search(r'SetAttribute\("(?:Stamina|StaminaMax|WolfDbgNoStamina|FeralCombatUntil|FeralDowned)"', source)
    assert source.count(":FireServer(") == 1 and 'remote:FireServer("Rest", enabled)' in source
    assert source.count("api.set(") == 1 and "api.connections(hum.StateChanged)" in source
    mock = (ROOT / "tests/mock-feral-field-hub-v1.0.luau").read_text().split("-- HUB SCENARIOS", 1)[0]
    extra = previous.EXTRA.replace("FeralRecoveryHubV10", "FeralRecoveryHubV11")
    regression = previous.CASES.replace("FeralRecoveryHubV10", "FeralRecoveryHubV11")
    regression = regression.replace("3.00x base stamina recovery applied locally", "3.00x base recovery applied locally")
    # The original final print/close are harmless between the regression and new cases.
    with tempfile.TemporaryDirectory(prefix="feral-moving-regen-") as tmp:
        runtime = Path(tmp) / "runtime.luau"
        runtime.write_text(mock + extra + NATIVE + "\nlocal function launchHub()\n" + source + "\nend\n"
                           + "\nlocal function launchPreviousHealth()\n" + (ROOT / "feral-health-recovery-v1.3.lua").read_text() + "\nend\n"
                           + "\nlocal function launchPreviousHub()\n" + (ROOT / "feral-recovery-hub-v1.0.lua").read_text() + "\nend\n"
                           + regression + CASES)
        result = subprocess.run([luau, str(runtime)], text=True, capture_output=True)
        print(result.stdout, end="")
        if result.returncode:
            print(result.stderr, end="")
            raise SystemExit(result.returncode)
    print("Static boundaries and synthetic native-pool checks passed. Roblox/Velocity behavior remains unverified.")


if __name__ == "__main__":
    main()
