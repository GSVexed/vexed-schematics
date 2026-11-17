"""Lifecycle/fault checks in an engine substitute; not Roblox or server validation."""
from pathlib import Path
import os
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

EXTRA = r'''
local originalAttribute=methods.SetAttribute
function methods:GetAttributeChangedSignal(key)
    local name="@attribute/"..key
    if not self._signals[name] then self._signals[name]=signal() end
    return self._signals[name]
end
function methods:SetAttribute(key,value)
    if M.attrFail and self==M.character and key=="WolfRest" and value==false then error("denied") end
    local old=self:GetAttribute(key); originalAttribute(self,key,value)
    local changed=self._signals["@attribute/"..key]
    if old~=value and changed then changed:Fire() end
end
M.renderBindings={}; M.gameRequests={}
M.services.HttpService=Instance.new("HttpService")
function methods:JSONEncode() return "{}" end
function methods:BindToRenderStep(name,priority,fn)
    if M.renderFail then error("unavailable") end
    M.renderBindings[name]={priority=priority,fn=fn}
end
function methods:UnbindFromRenderStep(name) M.renderBindings[name]=nil end
M.wolfActions=child("RemoteEvent","WolfActions",M.services.ReplicatedStorage)
function methods:FireServer(...)
    if M.rpcFail then error("unavailable") end
    local args=table.pack(...); args.remote=self.Name; args.char=M.player.Character
    M.gameRequests[#M.gameRequests+1]=args
    if self==M.wolfActions and M.echoRest then M.character:SetAttribute("WolfRest",args[2]) end
end
local originalStep=M.step
function M.step(seconds)
    originalStep(seconds)
    local list={}; for _,v in pairs(M.renderBindings) do list[#list+1]=v end
    table.sort(list,function(a,b) return a.priority<b.priority end)
    for _,v in ipairs(list) do v.fn() end
    M.restPose=M.character and M.character:GetAttribute("WolfRest")==true
end
function M.close()
    local gui=M.playerGui:FindFirstChild("FeralRecoveryHubV10")
    if gui then gui:Destroy() end
end
function M.fresh(hp)
    M.close(); M.renderFail=false; M.attrFail=false; M.rpcFail=false; M.echoRest=true
    M.spawn(); M.humanoid.Health=hp or 80
    for _,key in ipairs({"FeralMenuOpen","FeralTitleOpen","HudBurst","HudSprint","FeralCombatUntil"}) do M.player:SetAttribute(key,nil) end
    M.needs.STAMINA_REGEN=1.31; M.needs.STAMINA_REST_MULT=3
    M.needs.STAMINA_SPRINT_DRAIN=.94; M.needs.STAMINA_JUMP_COST=6
    M.needs.STAMINA_REGEN_DELAY=.8; M.needs.STAMINA_LOW_NEEDS=.5
    M.needs.BURST={ENABLED=true,DRAIN=3.9}
    M.gameRequests={}
end
function M.restCount(value)
    local n=0
    for _,r in ipairs(M.gameRequests) do
        assert(r.remote=="WolfActions" and r[1]=="Rest" and type(r[2])=="boolean")
        if value==nil or r[2]==value then n=n+1 end
    end
    return n
end
function M.text(fragment)
    for i=#M.nodes,1,-1 do
        local n=M.nodes[i]
        if not n._destroyed and n.Parent and type(n.Text)=="string" and n.Text:find(fragment,1,true) then return true end
    end
    return false
end
function M.arm() M.click("RECOVERY ASSIST: OFF"); M.step(.11) end
function M.stamina() M.click("REST-RATE STAMINA: OFF"); M.flush() end
'''

CASES = r'''
case("opens with both controls off, no gameplay requests, resource writes or config reads",function()
    M.fresh(); local writes=M.healthWrites; local reads=M.requireCalls; local attrs=M.attributeWrites
    launchHub(); M.step(2)
    assert(M.playerGui:FindFirstChild("FeralRecoveryHubV10"))
    assert(#M.gameRequests==0 and M.healthWrites==writes and M.requireCalls==reads and M.attributeWrites==attrs)
    assert(M.needs.STAMINA_REGEN==1.31 and M.needs.BURST.ENABLED)
end)
case("rest-rate option changes only two cached recovery fields",function()
    M.fresh(); launchHub(); local writes=M.attributeWrites; local hp=M.healthWrites
    M.stamina()
    assert(math.abs(M.needs.STAMINA_REGEN-3.93)<.000001 and M.needs.STAMINA_REST_MULT==1)
    assert(M.needs.STAMINA_SPRINT_DRAIN==.94 and M.needs.STAMINA_JUMP_COST==6)
    assert(M.needs.STAMINA_REGEN_DELAY==.8 and M.needs.STAMINA_LOW_NEEDS==.5)
    assert(M.needs.BURST.ENABLED and M.needs.BURST.DRAIN==3.9)
    assert(M.attributeWrites==writes and M.healthWrites==hp and #M.gameRequests==0)
    assert(M.text("3.00x base stamina recovery applied locally"))
end)
case("ordinary rest does not stack the rate to nine times baseline",function()
    M.fresh(); launchHub(); M.stamina()
    assert(math.abs(M.needs.STAMINA_REGEN*M.needs.STAMINA_REST_MULT-1.31*3)<.000001)
end)
case("off restores original values without compounding subsequent toggles",function()
    M.fresh(); launchHub(); M.stamina(); M.click("REST-RATE STAMINA: ON")
    assert(M.needs.STAMINA_REGEN==1.31 and M.needs.STAMINA_REST_MULT==3)
    M.stamina(); assert(math.abs(M.needs.STAMINA_REGEN-3.93)<.000001)
end)
case("external config changes stop assistance and preserve the external edit",function()
    M.fresh(); launchHub(); M.stamina(); M.needs.STAMINA_REGEN=2.5; M.step(.3)
    assert(M.needs.STAMINA_REGEN==2.5 and M.needs.STAMINA_REST_MULT==3)
    assert(M.text("Config changed externally"))
end)
case("late cache result cannot reactivate a stopped option",function()
    M.fresh(); launchHub(); M.click("REST-RATE STAMINA: OFF")
    M.click("REST-RATE STAMINA: CHECKING"); M.flush()
    assert(M.needs.STAMINA_REGEN==1.31 and M.needs.STAMINA_REST_MULT==3)
end)
case("latest toggle wins while only one cache job is queued",function()
    M.fresh(); launchHub(); local reads=M.requireCalls
    M.click("REST-RATE STAMINA: OFF"); M.click("REST-RATE STAMINA: CHECKING"); M.click("REST-RATE STAMINA: OFF")
    M.flush(); assert(M.requireCalls==reads+1 and math.abs(M.needs.STAMINA_REGEN-3.93)<.000001)
end)
case("absent executor cache API cannot start a new module or leave enabled status",function()
    M.fresh(); launchHub(); local getter=getloadedmodules; getloadedmodules=nil; local reads=M.requireCalls
    M.stamina(); assert(M.requireCalls==reads and M.needs.STAMINA_REGEN==1.31)
    assert(M.button("REST-RATE STAMINA: OFF")); getloadedmodules=getter
end)
case("frozen config leaves all original fields intact",function()
    M.fresh(); local module=M.world:FindFirstChild("NeedsConfig"); local old=M.modules[module]
    M.modules[module]=table.freeze(table.clone(M.needs)); launchHub(); M.stamina()
    assert(M.modules[module].STAMINA_REGEN==1.31 and M.modules[module].STAMINA_REST_MULT==3)
    assert(M.button("REST-RATE STAMINA: OFF")); M.close(); M.modules[module]=old
end)
case("failure on the second field rolls the first field back",function()
    M.fresh(); local module=M.world:FindFirstChild("NeedsConfig"); local old=M.modules[module]
    local backing=table.clone(M.needs)
    local proxy=setmetatable({},{__index=backing,__newindex=function(_,key,value)
        if key=="STAMINA_REGEN" then error("readonly") end; backing[key]=value
    end})
    M.modules[module]=proxy; launchHub(); M.stamina()
    assert(backing.STAMINA_REST_MULT==3 and backing.STAMINA_REGEN==1.31)
    assert(M.button("REST-RATE STAMINA: OFF")); M.close(); M.modules[module]=old
end)
case("existing no-drain flag is not taken over or advertised as this option",function()
    M.fresh(); M.character:SetAttribute("WolfDbgNoStamina",true); launchHub(); local reads=M.requireCalls
    M.stamina(); assert(M.requireCalls==reads and M.needs.STAMINA_REGEN==1.31)
    assert(M.character:GetAttribute("WolfDbgNoStamina")==true and M.text("An existing no-drain flag"))
end)
case("native Rest works independently in combat and Burst without HP writes",function()
    M.fresh(); M.player:SetAttribute("FeralCombatUntil",workspace:GetServerTimeNow()+100)
    M.player:SetAttribute("HudBurst",true); launchHub(); local hp=M.healthWrites
    M.arm(); assert(M.restCount(true)==1 and not M.restPose and M.healthWrites==hp)
    assert(M.needs.STAMINA_REGEN==1.31 and M.needs.BURST.ENABLED)
end)
case("true recovery packets are throttled to at most one each five seconds",function()
    M.fresh(); launchHub(); M.arm()
    for _=1,45 do M.step(.1) end
    assert(M.restCount(true)==1); M.step(.6); assert(M.restCount(true)==2)
end)
case("server rest echoes are masked before native animation render priority",function()
    M.fresh(); launchHub(); M.arm()
    local found=false; for _,binding in pairs(M.renderBindings) do assert(binding.priority==199); found=true end
    assert(found and M.character:GetAttribute("WolfRest")==false)
    M.character:SetAttribute("WolfRest",true); M.step(.01); assert(not M.restPose)
end)
case("full HP standby wakes for a deficit and releases at full HP",function()
    M.fresh(100); launchHub(); M.arm(); assert(M.restCount()==0)
    M.humanoid.Health=60; M.step(.2); assert(M.restCount(true)==1)
    M.humanoid.Health=100; M.step(.2); assert(M.restCount(false)==1 and next(M.renderBindings)==nil)
    assert(M.button("RECOVERY ASSIST: ON"))
end)
case("full HP conditions can request recovery without writing the condition",function()
    for _,key in ipairs({"FeralBleed","FeralInjury","FeralVenomAmt"}) do
        M.fresh(100); M.character:SetAttribute(key,8); launchHub(); M.arm()
        assert(M.restCount(true)==1 and M.character:GetAttribute(key)==8)
    end
end)
case("initial native rest belongs to the player and is not seized",function()
    M.fresh(); M.character:SetAttribute("WolfRest",true); launchHub(); M.arm()
    assert(M.restCount()==0 and M.character:GetAttribute("WolfRest")==true)
end)
case("menu downed and dead standby do not revive or erase downed state",function()
    M.fresh(); launchHub(); M.arm(); M.character:SetAttribute("FeralDowned",true); M.step(.2)
    assert(M.restCount(false)==1 and M.character:GetAttribute("FeralDowned")==true)
    M.character:SetAttribute("FeralDowned",nil); M.player:SetAttribute("FeralMenuOpen",true); M.step(6)
    assert(M.restCount(true)==1)
    M.humanoid.Health=0; local hp=M.healthWrites; M.player:SetAttribute("FeralMenuOpen",nil); M.step(6)
    assert(M.restCount(true)==1 and M.healthWrites==hp)
end)
case("respawn restores old rest ownership and keeps both options armed",function()
    M.fresh(); launchHub(); M.arm(); M.stamina(); local old=M.character
    M.spawn(); assert(M.restCount(false)==1 and old:GetAttribute("WolfRest")==false)
    M.step(5.2); assert(M.restCount(true)==2 and not M.restPose)
    assert(math.abs(M.needs.STAMINA_REGEN-3.93)<.000001)
end)
case("unannounced character replacement never receives old false cleanup",function()
    M.fresh(); launchHub(); M.arm(); local replacement=Instance.new("Model"); replacement.Parent=workspace
    M.player._props.Character=replacement; M.step(.2)
    assert(M.restCount(false)==0 and next(M.renderBindings)==nil)
end)
case("missing mask API fails before any true request",function()
    M.fresh(); launchHub(); M.renderFail=true; M.arm()
    assert(M.restCount(true)==0 and next(M.renderBindings)==nil)
    assert(M.button("RECOVERY ASSIST: OFF")); M.renderFail=false
end)
case("mask failure after activation stops requests and releases the lease",function()
    M.fresh(); launchHub(); M.arm(); M.attrFail=true; M.character:SetAttribute("WolfRest",true)
    M.attrFail=false; M.step(.2); local before=M.restCount(true); M.step(8)
    assert(M.restCount(true)==before and next(M.renderBindings)==nil)
    assert(M.button("RECOVERY ASSIST: OFF"))
end)
case("unavailable remote stops recovery without a retry loop",function()
    M.fresh(); launchHub(); local owner=M.wolfActions.Parent; M.wolfActions.Parent=nil
    M.arm(); M.step(8); assert(M.restCount(true)==0 and M.button("RECOVERY ASSIST: OFF"))
    M.close(); M.wolfActions.Parent=owner
end)
case("off button restores both options while leaving the menu available",function()
    M.fresh(); launchHub(); M.arm(); M.stamina(); M.click("TURN EVERYTHING OFF")
    assert(M.needs.STAMINA_REGEN==1.31 and M.needs.STAMINA_REST_MULT==3 and M.restCount(false)==1)
    assert(next(M.renderBindings)==nil and M.playerGui:FindFirstChild("FeralRecoveryHubV10"))
end)
case("close restores original config and current native Rest request",function()
    M.fresh(); launchHub(); M.arm(); M.stamina(); M.click("X")
    assert(M.needs.STAMINA_REGEN==1.31 and M.needs.STAMINA_REST_MULT==3)
    assert(M.restCount(false)==1 and next(M.renderBindings)==nil)
    assert(not M.playerGui:FindFirstChild("FeralRecoveryHubV10"))
end)
case("rerun shuts the previous instance down before opening default-off controls",function()
    M.fresh(); launchHub(); M.arm(); M.stamina(); launchHub(); M.step(.2)
    assert(M.needs.STAMINA_REGEN==1.31 and M.needs.STAMINA_REST_MULT==3)
    assert(M.restCount(false)==1 and M.button("RECOVERY ASSIST: OFF") and M.button("REST-RATE STAMINA: OFF"))
end)
case("external GUI destruction and late callbacks cannot leave stamina tuning behind",function()
    M.fresh(); launchHub(); M.click("REST-RATE STAMINA: OFF"); M.close(); M.flush()
    assert(M.needs.STAMINA_REGEN==1.31 and M.needs.STAMINA_REST_MULT==3)
end)
case("minimize keeps features active and the plus button reopens the panel",function()
    M.fresh(); launchHub(); M.stamina(); M.click("-"); M.step(.3)
    assert(math.abs(M.needs.STAMINA_REGEN-3.93)<.000001 and M.button("+"))
    M.click("+"); assert(M.button("-"))
end)
case("upgrading the actual v1.3 tool releases its no-drain tuning before the new controls",function()
    M.fresh(); launchPreviousHealth()
    assert(M.playerGui:FindFirstChild("FeralHealthRecoveryV13"))
    M.click("STAMINA TUNING: OFF"); M.flush()
    assert(M.needs.STAMINA_REGEN==250 and M.needs.STAMINA_SPRINT_DRAIN==0)
    assert(M.character:GetAttribute("WolfDbgNoStamina")==true)
    M.click("RECOVERY ASSIST: OFF"); M.step(.2)
    launchHub(); M.step(.2)
    assert(not M.playerGui:FindFirstChild("FeralHealthRecoveryV13"))
    assert(M.character:GetAttribute("WolfDbgNoStamina")==nil)
    assert(M.needs.STAMINA_REGEN==1.31 and M.needs.STAMINA_SPRINT_DRAIN==.94)
    assert(M.restCount(false)>=1 and next(M.renderBindings)==nil)
    M.stamina(); assert(math.abs(M.needs.STAMINA_REGEN-3.93)<.000001)
end)
M.close()
print("RECOVERY_HUB_RUNTIME_CASES="..passed)
'''


def main():
    luau = os.environ.get("LUAU", "luau")
    source = (ROOT / "feral-recovery-hub-v1.0.lua").read_text()
    for forbidden in ("writefile", "readfile", "decompile", "setreadonly", "hookfunction", "getupvalue", "GetPlayers", "InvokeServer", "STAMINA_REGEN = 250"):
        assert forbidden not in source, forbidden
    assert not re.search(r"(?:hum|humanoid)\.Health\s*=", source)
    assert not re.search(r'SetAttribute\("(?:Stamina|StaminaMax|WolfDbgNoStamina|FeralCombatUntil|FeralDowned)"', source)
    assert source.count(":FireServer(") == 1
    assert 'remote:FireServer("Rest", enabled)' in source
    assert "BURST.ENABLED =" not in source and "STAMINA_SPRINT_DRAIN = 0" not in source
    mock = (ROOT / "tests/mock-feral-field-hub-v1.0.luau").read_text().split("-- HUB SCENARIOS", 1)[0]
    with tempfile.TemporaryDirectory(prefix="feral-recovery-hub-") as tmp:
        runtime = Path(tmp) / "runtime.luau"
        previous = (ROOT / "feral-health-recovery-v1.3.lua").read_text()
        runtime.write_text(mock + EXTRA + "\nlocal function launchHub()\n" + source + "\nend\n"
                           + "\nlocal function launchPreviousHealth()\n" + previous + "\nend\n" + CASES)
        result = subprocess.run([luau, str(runtime)], text=True, capture_output=True)
        print(result.stdout, end="")
        if result.returncode:
            print(result.stderr, end="")
            raise SystemExit(result.returncode)
    print("Static boundary checks passed. Runtime checks are simulated; Roblox/Velocity behavior is unverified.")


if __name__ == "__main__":
    main()
