-- FERAL NOVA PRIME v14 / Non-Rest recovery configuration and evidence tracker.
-- Tries the archived HEALTH_REGEN and status decay inputs while mobile.
-- Does not write Humanoid.Health, combat tags or condition attributes.
-- If the server owns health/status, this may not change any actual rate.
local Regen={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local statusKeys={
    {name="INJURY",attr="FeralInjury",field="HEAL"},
    {name="BLEED",attr="FeralBleed",field="CLOT"},
    {name="VENOM",attr="FeralVenomAmt",field="FADE"}
}
local function finite(v)
    return type(v)=="number" and v==v and math.abs(v)<1e9
end
local function config(name)
    local folder=RS:FindFirstChild("FeralWorld")
    local m=folder and folder:FindFirstChild(name)
    if not m or not m:IsA("ModuleScript") then
        return nil,name.." not replicated yet"
    end
    local ok,result=pcall(require,m)
    if ok and type(result)=="table" then return result end
    return nil,name.." unavailable after require"
end
local function window()
    return {valid=0,hp=0,gainTicks=0,damageTicks=0,
        observed=0,status={},statusSeconds={},statusSamples={}}
end
local function score(a,b)
    if b<=.5 then return nil end
    return a/b
end
local function fmt(n)
    return type(n)=="number" and string.format("%.4f",n) or "UNKNOWN"
end
function Regen.attach(ctx)
    local R={
        alive=true,enabled=false,applied=false,
        status="OFF",lastError="",needsApplied=false,
        statusApplied=false,lease=nil,requestedAt=0,
        attempts=0,applies=0,reverts=0,conflicts=0,
        nextTick=0,lastCharacter=nil,lastSample=nil,lastTime=0,
        lastRest=false,restExclusionSeconds=0,
        baselineExpected="UNKNOWN",
        combat=window(),peace=window(),unknown=window(),
        lastHp=0,lastMax=0,combatSamples=0,peaceSamples=0,
        unclassifiedSamples=0,belowMaxSeconds=0,
        efficacy="UNVERIFIED / SERVER MAY IGNORE CLIENT CONFIG"
    }
    local function restore()
        for i=#(R.lease or {}),1,-1 do
            local e=R.lease[i]
            local ok=pcall(function()
                if e.parent[e.key]==e.wanted then
                    e.parent[e.key]=e.old
                    R.reverts+=1
                else
                    R.conflicts+=1
                end
            end)
            if not ok then R.conflicts+=1 end
        end
        R.lease=nil
        R.applied=false
        R.needsApplied=false
        R.statusApplied=false
    end
    local function set(tableValue,key,wanted,lease)
        if type(tableValue)~="table" then return false end
        local old=tableValue[key]
        if old==nil or old==wanted then
            return old~=nil
        end
        local ok=pcall(function()tableValue[key]=wanted end)
        if not ok or tableValue[key]~=wanted then return false end
        lease[#lease+1]={parent=tableValue,key=key,old=old,wanted=wanted}
        return true
    end
    local function install()
        local needs,err=config("NeedsConfig")
        if not needs then
            R.status="WAITING: "..tostring(err)
            R.lastError=tostring(err)
            return false
        end
        if not finite(needs.HEALTH_REGEN)
            or type(needs.HEALTH_NO_REGEN_IN_COMBAT)~="boolean" then
            R.status="UNRECOGNISED HEALTH CONFIG / NO CHANGE"
            R.lastError="NeedsConfig schema mismatch"
            return false
        end
        local cfg,why=config("StatusConfig")
        local lease={}
        local ok=set(needs,"HEALTH_REGEN",math.min(needs.HEALTH_REGEN*2.0,.09),lease)
        local combatOK=set(needs,"HEALTH_NO_REGEN_IN_COMBAT",false,lease)
        if not ok or not combatOK then
            for i=#lease,1,-1 do
                local e=lease[i];e.parent[e.key]=e.old
            end
            R.status="HEALTH CONFIG NOT PATCHABLE"
            R.lastError="Could not update both local health config inputs"
            return false
        end
        R.baselineExpected=string.format("%.4f",needs.HEALTH_REGEN/2)
        R.needsApplied=true
        local applied=0
        local missing={}
        for _,e in ipairs(statusKeys) do
            local block=cfg and cfg[e.name]
            if type(block)=="table" and finite(block[e.field])
                and block[e.field]>0 then
                local source=block[e.field]
                local target=math.min(source*4,10000)
                if set(block,e.field,target,lease) then
                    applied+=1
                else missing[#missing+1]=e.name end
            else
                missing[#missing+1]=e.name
            end
        end
        R.statusApplied=applied==#statusKeys
        R.status=R.statusApplied
            and "CLIENT 2x HEALTH + 4x STATUS INPUTS"
            or "CLIENT HEALTH INPUTS ON / STATUS PARTIAL"
        if #missing>0 then
            R.lastError="StatusConfig fields missing: "..
                table.concat(missing,",").."; "..tostring(why or "")
        else
            R.lastError=""
        end
        R.lease=lease
        R.applied=true
        R.applies+=1
        return true
    end
    function R.setEnabled(v)
        if v==false then
            R.enabled=false
            restore()
            R.status="OFF / ORIGINAL CLIENT CONFIG RESTORED"
            return false
        end
        R.enabled=true
        if R.applied then return true end
        R.attempts+=1
        return install()
    end
    local function sample(char,hum)
        local d={hp=hum.Health,max=hum.MaxHealth,
            rest=char:GetAttribute("WolfRest")==true}
        for _,e in ipairs(statusKeys) do
            local n=char:GetAttribute(e.attr)
            d[e.attr]=finite(n) and n or nil
        end
        return d
    end
    local function bucket()
        local untilAt=player:GetAttribute("FeralCombatUntil")
        if finite(untilAt) then
            local ok,now=pcall(function()
                return workspace:GetServerTimeNow()
            end)
            if ok and finite(now) then
                return untilAt>now and R.combat or R.peace
            end
        end
        return R.unknown
    end
    local function measure(old,new,elapsed,selected)
        if elapsed<.08 or elapsed>1.5 or new.rest or old.rest
            or old.max~=new.max or not finite(old.hp)
            or not finite(new.hp) then return end
        if old.hp<old.max-.20 then
            local diff=new.hp-old.hp
            if diff>=-.01 then
                selected.valid+=elapsed
                R.belowMaxSeconds+=elapsed
                if diff>.01 then
                    selected.hp+=diff
                    selected.gainTicks+=1
                end
            else
                selected.damageTicks+=1
            end
        end
        selected.observed+=elapsed
        for _,e in ipairs(statusKeys) do
            local x=old[e.attr]
            local y=new[e.attr]
            if finite(x) and finite(y) and x>.20 and y<=x+.01 then
                selected.statusSeconds[e.attr]=(selected.statusSeconds[e.attr] or 0)+elapsed
                if y<x-.005 then
                    selected.status[e.attr]=(selected.status[e.attr] or 0)+(x-y)
                    selected.statusSamples[e.attr]=(selected.statusSamples[e.attr] or 0)+1
                end
            end
        end
    end
    local function tick()
        if not R.alive or not ctx.state.alive then return end
        local now=os.clock()
        if now<R.nextTick then return end
        R.nextTick=now+.25
        if R.enabled and not R.applied then R.setEnabled(true) end
        if not R.enabled then return end
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not char.Parent or not hum or hum.Health<=0 then
            R.lastCharacter=nil;R.lastSample=nil;R.lastTime=0
            return
        end
        if char~=R.lastCharacter then
            R.lastCharacter=char
            R.lastSample=nil
            R.lastTime=0
        end
        local current=sample(char,hum)
        if R.lastSample and R.lastTime>0 then
            if current.rest or R.lastSample.rest then
                R.restExclusionSeconds+=now-R.lastTime
            else
                local group=bucket()
                measure(R.lastSample,current,now-R.lastTime,group)
                if group==R.combat then R.combatSamples+=1
                elseif group==R.peace then R.peaceSamples+=1
                else R.unclassifiedSamples+=1 end
            end
        end
        R.lastSample=current
        R.lastTime=now
        R.lastHp=hum.Health
        R.lastMax=hum.MaxHealth
        local r=score(R.peace.hp,R.peace.valid)
        local default=R.lastMax*.01
        if R.peace.valid>=5 and R.peace.gainTicks>=3 and r then
            R.efficacy=r>default*1.5
                and "ELEVATED NONREST HP RATE OBSERVED (CAUSE UNPROVEN)"
                or "NONREST HEALTH UPLIFT NOT ESTABLISHED"
        end
    end
    function R.report()
        local parts={
            "FERAL NOVA PRIME v14 | Always-Regen Config + Live Rates",
            "enabled="..tostring(R.enabled),
            "client_config_applied="..tostring(R.applied),
            "client_health_inputs_applied="..tostring(R.needsApplied),
            "client_status_inputs_applied="..tostring(R.statusApplied),
            "status="..R.status,
            "health_regen_config_baseline="..tostring(R.baselineExpected),
            "health_combat_exclusion_client_flag="..
                (R.applied and "false" or "UNMODIFIED"),
            "observed_nonrest_hp_per_second="..fmt(score(R.peace.hp,R.peace.valid)),
            "observed_combat_hp_per_second="..fmt(score(R.combat.hp,R.combat.valid)),
            "observed_unknown_combat_hp_per_second="..fmt(score(R.unknown.hp,R.unknown.valid)),
            "valid_nonrest_peace_seconds="..fmt(R.peace.valid),
            "valid_nonrest_combat_seconds="..fmt(R.combat.valid),
            "valid_unknown_combat_seconds="..fmt(R.unknown.valid),
            "positive_hp_intervals_peace="..R.peace.gainTicks,
            "positive_hp_intervals_combat="..R.combat.gainTicks,
            "nonrest_hp_benefit="..R.efficacy,
            "rest_excluded_seconds="..fmt(R.restExclusionSeconds),
            "config_install_count="..R.applies,
            "restored_fields="..R.reverts,
            "external_config_conflicts="..R.conflicts,
            "last_error="..R.lastError,
        }
        for _,s in ipairs(statusKeys) do
            for _,pair in ipairs({{"combat",R.combat},{"peace",R.peace}}) do
                local x=pair[2]
                local time=x.statusSeconds[s.attr] or 0
                local amount=x.status[s.attr] or 0
                parts[#parts+1]=s.name:lower().."_"..pair[1]..
                    "_per_second="..fmt(score(amount,time))
            end
        end
        parts[#parts+1]="NOTE=Health and condition values are observed; NEVER written by this module."
        parts[#parts+1]="NOTE=Client config edits and combat UI flags may be ignored by game server."
        parts[#parts+1]="NOTE=Server-side doubled regen and 4x clearing are not assumed."
        return table.concat(parts,"\n")
    end
    function R.close()
        R.alive=false
        R.setEnabled(false)
        if R.connection then R.connection:Disconnect()end
    end
    R.connection=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            R.lastError=tostring(err)
            R.status="OBSERVATION ERROR"
        end
    end)
    return R
end
return Regen
