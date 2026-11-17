"""Self-only native hit feedback and lifecycle tests; no Roblox execution."""
from pathlib import Path
import importlib.util
import os
import re
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("health11tests", ROOT / "tests/test-feral-health-recovery-v1.1.py")
previous = importlib.util.module_from_spec(spec)
spec.loader.exec_module(previous)

PRELUDE = r'''
M.hitRemote=child("RemoteEvent","FeralHit",M.services.ReplicatedStorage)
M.hitRemote.OnClientEvent=signal()
M.playersForCharacters={}
function methods:GetPlayerFromCharacter(char) return M.playersForCharacters[char] end
function M.other(playerActor)
    local other=child("Model","PRIVATE-ACTOR-NAME",workspace)
    if playerActor then M.playersForCharacters[other]=Instance.new("Player") end
    return other
end
function M.feedback(victim,damage,blocked)
    M.hitRemote.OnClientEvent:Fire("hit",{a=M.character,v=victim,dmg=damage,safe=blocked,
        name="PRIVATE-PAYLOAD-NAME",token="SECRET-TOKEN",health=987654321,pos=vec(4444,5555,6666)})
end
'''

MORE = r'''
case("own outgoing hit feedback keeps damage/classification but drops identities and raw packet",function()
    M.fresh(); launchHealth(); M.step(.1); local other=M.other(true)
    M.feedback(other,12,false); local d=M.healthReport()
    assert(d.combat_trace.counts.outgoing==1 and d.combat_trace.counts.positive_outgoing==1)
    local found
    for _,e in ipairs(d.timeline.events) do if e.kind=="own_native_hit_feedback" then found=e end end
    assert(found.reported_damage==12 and found.other_actor_kind=="player" and found.direction=="outgoing")
    local encoded=encode(d)
    for _,value in ipairs({"PRIVATE-ACTOR-NAME","PRIVATE-PAYLOAD-NAME","SECRET-TOKEN","987654321"}) do
        assert(not encoded:find(value,1,true))
    end
    assert(found.a==nil and found.v==nil and found.pos==nil and found.token==nil)
end)
case("unrelated native traffic and malformed packets are ignored",function()
    M.fresh(); launchHealth(); M.step(.1); local other=M.other(false); local third=M.other(false)
    local before=M.healthReport().timeline.total
    for _,payload in ipairs({false,12,"SECRET",{a=other,v=third,dmg=9},{a=M.character,v="bad",dmg=9}}) do
        M.hitRemote.OnClientEvent:Fire("hit",payload)
    end
    M.hitRemote.OnClientEvent:Fire("other",{a=M.character,v=other,dmg=9})
    local d=M.healthReport(); assert(d.timeline.total==before and d.combat_trace.counts.outgoing==0)
end)
case("unsupported damage fields stay unknown without leaking their value",function()
    M.fresh(); launchHealth(); M.step(.1); M.feedback(M.other(true),"PRIVATE-DAMAGE",false)
    local d=M.healthReport(); local found
    for _,e in ipairs(d.timeline.events) do if e.kind=="own_native_hit_feedback" then found=e end end
    assert(found.damage_state=="amount_unavailable" and found.damage_value_type=="string" and found.reported_damage==nil)
    assert(d.combat_trace.counts.positive_outgoing==0 and d.combat_trace.counts.safety_blocked_outgoing==0)
    assert(not encode(d):find("PRIVATE-DAMAGE",1,true))
end)
case("delayed tag followup handles hit feedback arriving before combat replication",function()
    M.fresh(); launchHealth(); M.step(.1); M.feedback(M.other(true),12,false)
    M.player:SetAttribute("FeralCombatUntil",workspace:GetServerTimeNow()+10)
    M.step(1.1); local d=M.healthReport()
    assert(d.combat_trace.counts.tag_followups_present==1 and d.combat_trace.pending_followups==0)
    local found
    for _,e in ipairs(d.timeline.events) do if e.kind=="own_hit_tag_followup" then found=e end end
    assert(found.outcome=="tag_observed" and found.combat_seconds_remaining>8)
end)
case("an untagged NPC hit report is not labelled a combat bypass",function()
    M.fresh(); launchHealth(); M.step(.1); M.feedback(M.other(false),12,false); M.step(1.1)
    local d=M.healthReport()
    assert(d.combat_trace.counts.tag_followups_absent==1 and d.limits.combat_disable=="not_established")
    local found
    for _,e in ipairs(d.timeline.events) do if e.kind=="own_hit_tag_followup" then found=e end end
    assert(found.other_actor_kind=="npc_or_other" and found.outcome=="tag_not_observed")
end)
case("safety-block feedback never becomes a positive-damage report",function()
    M.fresh(); launchHealth(); M.step(.1); M.feedback(M.other(true),12,true)
    local d=M.healthReport()
    assert(d.combat_trace.counts.safety_blocked_outgoing==1 and d.combat_trace.counts.positive_outgoing==0)
    assert(d.combat_trace.pending_followups==0)
end)
case("character replacement cancels old hit followups",function()
    M.fresh(); launchHealth(); M.step(.1); M.feedback(M.other(true),12,false)
    M.spawn(); M.step(1.1); local d=M.healthReport()
    assert(d.combat_trace.counts.followups_cancelled==1 and d.combat_trace.pending_followups==0)
    assert(d.combat_trace.counts.tag_followups_absent==0)
end)
case("closing cancels queued followups and disconnects native traffic",function()
    M.fresh(); launchHealth(); M.step(.1); M.feedback(M.other(true),12,false); M.close()
    assert(M.lastEncoded.combat_trace.counts.followups_cancelled==1 and M.lastEncoded.combat_trace.pending_followups==0)
    local total=M.lastEncoded.timeline.total; M.feedback(M.other(true),12,false); M.step(2)
    assert(M.lastEncoded.timeline.total==total)
end)
case("hit followup budget bounds pending work and reports omissions",function()
    M.fresh(); launchHealth(); M.step(.1); local other=M.other(false)
    for _=1,40 do M.feedback(other,12,false) end
    local d=M.healthReport()
    assert(d.combat_trace.pending_followups==32 and d.combat_trace.counts.followups_omitted==8)
    M.step(1.1); assert(M.healthReport().combat_trace.counts.tag_followups_absent==32)
end)
case("missing and replaced hit remotes do not create duplicate listeners",function()
    M.fresh(); M.hitRemote.Parent=nil; launchHealth(); M.step(.1)
    assert(M.healthReport().combat_trace.listener=="unavailable")
    M.hitRemote.Parent=M.services.ReplicatedStorage; M.step(5.1)
    M.feedback(M.other(false),12,false); assert(M.healthReport().combat_trace.counts.outgoing==1)
    local old=M.hitRemote; old.Parent=nil
    M.hitRemote=child("RemoteEvent","FeralHit",M.services.ReplicatedStorage); M.hitRemote.OnClientEvent=signal()
    M.step(5.1); old.OnClientEvent:Fire("hit",{a=M.character,v=M.other(false),dmg=12})
    M.feedback(M.other(false),12,false); assert(M.healthReport().combat_trace.counts.outgoing==2)
    M.close(); M.hitRemote:Destroy(); M.hitRemote=old; old.Parent=M.services.ReplicatedStorage
end)
case("combat and protection are observed without changing them",function()
    M.fresh(100)
    local combatUntil=workspace:GetServerTimeNow()+10; local safeUntil=workspace:GetServerTimeNow()+20
    M.player:SetAttribute("FeralCombatUntil",combatUntil); M.character:SetAttribute("FeralSafeUntil",safeUntil)
    M.player:SetAttribute("FeralTut",2); child("ForceField","Shield",M.character)
    local writes=#M.writes; launchHealth(); M.step(.1); local d=M.healthReport()
    assert(d.current.combat_seconds_remaining>9 and d.current.safe_seconds_remaining>19)
    assert(d.current.own_forcefield_present and d.current.tutorial_flag_present)
    assert(M.player:GetAttribute("FeralCombatUntil")==combatUntil and M.character:GetAttribute("FeralSafeUntil")==safeUntil)
    for i=writes+1,#M.writes do
        assert(M.writes[i].key~="FeralCombatUntil" and M.writes[i].key~="FeralSafeUntil" and M.writes[i].key~="FeralTut")
    end
    M.player:SetAttribute("FeralTut",nil)
end)
case("invalid combat timer is unknown and never exported as a raw value",function()
    M.fresh(); M.player:SetAttribute("FeralCombatUntil","SECRET-DEADLINE")
    M.character:SetAttribute("FeralSafeUntil","PRIVATE-DEADLINE"); launchHealth(); M.step(.1)
    M.feedback(M.other(false),12,false); M.step(1.1); local d=M.healthReport()
    assert(not d.current.combat_known and d.current.combat_seconds_remaining==nil)
    assert(d.combat_trace.counts.tag_followups_present==0 and d.combat_trace.counts.tag_followups_absent==0)
    local raw=encode(d); assert(not raw:find("SECRET-DEADLINE",1,true) and not raw:find("PRIVATE-DEADLINE",1,true))
    M.player:SetAttribute("FeralCombatUntil",0)
end)
case("actual health v1.1 is replaced with clean recovery and trace state",function()
    M.fresh(); launchHealth11(); M.click("RECOVERY ASSIST: OFF"); M.step(.1)
    local old=M.playerGui:FindFirstChild("FeralHealthRecoveryV11"); assert(old)
    launchHealth(); M.step(.1); local d=M.healthReport()
    assert(old._destroyed and not d.current.recovery_enabled and d.combat_trace.listener=="listening")
    assert(next(M.renderBindings)==nil and d.combat_trace.counts.outgoing==0)
end)
'''


def main():
    source = (ROOT / "feral-health-recovery-v1.2.lua").read_text()
    luau = Path(os.environ.get("FERAL_LUAU", str(previous.previous.hub14.base.DEFAULT_LUAU)))
    subprocess.run([str(luau.with_name("luau-compile")), "--null", str(ROOT / "feral-health-recovery-v1.2.lua")], check=True)
    for text in [":GetPlayers(", "decompile(", "getgc(", "hookfunction(", "setreadonly(", ":InvokeServer(",
                 "FeralSelect", "FeralGive", "FeralRewards", "FeralRestTap", "TakeDamage(", "HEALTH_NO_REGEN_IN_COMBAT"]:
        assert text not in source, text
    assert not re.search(r"\b(?:hum|humanoid)\.Health\s*=", source)
    assert source.count(":FireServer(") == 1 and 'remote:FireServer("Rest", enabled)' in source
    assert set(re.findall(r':SetAttribute\("([^"]+)"', source)) == {"WolfRest", "WolfDbgNoStamina"}
    hub14 = previous.previous.hub14
    mock = (ROOT / "tests/mock-feral-field-hub-v1.0.luau").read_text().split("-- HUB SCENARIOS", 1)[0]
    mock += r'''
M.remoteCalls=0
M.nativeRewards=child("RemoteEvent","FeralRewards",M.services.ReplicatedStorage)
M.nativeSlots=child("RemoteEvent","FeralSlots",M.services.ReplicatedStorage)
M.nativeRewards.OnClientEvent=signal(); M.nativeSlots.OnClientEvent=signal()
'''
    mock += hub14.prior.prior.PRELUDE_MORE + hub14.prior.PRELUDE_MORE + hub14.PRELUDE_MORE
    mock += previous.previous.PRELUDE.replace("FeralHealthRecoveryV10", "FeralHealthRecoveryV12").replace("feral-health-report/1.0", "feral-health-report/1.2").replace("CONTINUOUS RECOVERY REQUEST", "RECOVERY ASSIST")
    mock += PRELUDE
    cases = previous.scenarios().split('\nM.close()\nprint("HEALTH_RUNTIME_CASES=', 1)[0]
    cases = cases.replace("FeralHealthRecoveryV11", "FeralHealthRecoveryV12").replace("feral-health-report/1.1", "feral-health-report/1.2")
    with tempfile.TemporaryDirectory(prefix="feral-health12-tests-") as tmp:
        runtime = Path(tmp) / "runtime.luau"
        blocks = [mock]
        for name, filename in [("launchHealth", "feral-health-recovery-v1.2.lua"),
                               ("launchOld14", "feral-field-hub-v1.4.lua"),
                               ("launchHealth10", "feral-health-recovery-v1.0.lua"),
                               ("launchHealth11", "feral-health-recovery-v1.1.lua")]:
            blocks += ["\nlocal function " + name + "()\n", (ROOT / filename).read_text(), "\nend\n"]
        runtime.write_text("".join(blocks) + cases + MORE + '\nM.close()\nprint("HEALTH_RUNTIME_CASES="..passed)\n')
        subprocess.run([str(luau), str(runtime)], check=True)
    print("v1.2 static and simulated checks passed. Combat bypass and live hit-correlation behaviour are unverified.")


if __name__ == "__main__":
    main()
