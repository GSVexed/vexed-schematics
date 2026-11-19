-- FERAL NOVA PRIME v15 / Safe native Rest mutually exclusive with legacy signal mask.
-- Old v8 automatically entered Rest near enemies, preventing Bite.
-- v9 never enters Rest at startup and cancels its OWN Rest on combat input.
-- Actual healing and damage protection are decided by game server.
local Recovery={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function finite(n)
    return type(n)=="number" and n==n and n>=0 and n<1e9
end
function Recovery.shellState(species,rest,restAt,serverNow)
    if type(species)~="string" or not string.find(species,"SnappingTurtle",1,true)
        then return "NOT TURTLE",1 end
    if rest~=true then return "SHELL INACTIVE",1 end
    if not finite(restAt) or not finite(serverNow) then
        return "REST OBSERVED / TIMER UNAVAILABLE",1
    end
    if serverNow-restAt<1 then return "SHELL ARMING",1 end
    return "SHELL CONDITION MET / UNVERIFIED DAMAGE",.30
end

function Recovery.attach(ctx)
    local M={
        alive=true,enabled=false,status="PASSIVE MONITOR",
        shell="NOT TURTLE",multiplier=1,
        requests=0,cancels=0,replicatedRestTransitions=0,
        restingHeals=0,normalHeals=0,lastRate=0,
        movingShellSeen=false,attackInterrupts=0,
        healthRestGain=0,healthRestSeconds=0,
        healthNormalGain=0,healthNormalSeconds=0,
        healthRestTicks=0,healthNormalTicks=0,
        cachedHealthRegen=nil,cachedHealthRestMult=nil,
        cachedStatusRestMults="UNAVAILABLE",
        damageInterrupts=0,unsafeBlocks=0,carryInterrupts=0,carryBlocks=0,
        restOwned=nil,restActive=false,
        lastChar=nil,lastHP=nil,lastMax=nil,
        lastMeasure=0,lastMeasureRest=nil,lastRest=false,lastInput=-math.huge,
        lastDamage=-math.huge,stillSince=0,
        nextRequest=0,nextTick=0,lastError="",
        pendingUntil=0,restAttempts=0,
        statusActive=false,
        statusValues={},
        statusSamples={},
        prevStatusAt=0,prevStatusRest=nil,
        restObservedSeconds=0,
        noRestObservedSeconds=0,
        reason="Enable Rest to request 2x HP / 4x status recovery when eligible"
    }
    local connections={}
    local world=RS:FindFirstChild("FeralWorld")
    local function readConfig(name)
        local mod=world and world:FindFirstChild(name)
        if not mod or not mod:IsA("ModuleScript") then return nil end
        local ok,v=pcall(require,mod)
        return ok and type(v)=="table" and v or nil
    end
    local needs=readConfig("NeedsConfig")
    local statusConfig=readConfig("StatusConfig")
    if needs then
        if finite(needs.HEALTH_REGEN) then M.cachedHealthRegen=needs.HEALTH_REGEN end
        if finite(needs.HEALTH_REST_MULT) then
            M.cachedHealthRestMult=needs.HEALTH_REST_MULT
        end
    end
    if statusConfig then
        local mult={}
        for _,key in ipairs({"INJURY","BLEED","VENOM"}) do
            local entry=statusConfig[key]
            mult[#mult+1]=key..":"..tostring(
                type(entry)=="table" and entry.REST_MULT or "unknown")
        end
        M.cachedStatusRestMults=table.concat(mult,",")
    end
    local statusKeys={
        {key="FeralInjury",name="injury",limit=.5},
        {key="FeralBleed",name="bleed",limit=.25},
        {key="FeralVenomAmt",name="venom",limit=.25}
    }
    for _,entry in ipairs(statusKeys) do
        M.statusSamples[entry.name]={
            restDelta=0,normalDelta=0,restSeconds=0,
            normalSeconds=0,restTicks=0,normalTicks=0,
            gainedTicks=0
        }
    end
    local function remote()
        local r=RS:FindFirstChild("WolfActions")
        return r and r:IsA("RemoteEvent") and r or nil
    end
    local function requestRest(char,flag)
        if not char or char~=player.Character then return false end
        local r=remote()
        if not r then M.lastError="WolfActions unavailable";return false end
        local ok,err=pcall(function()r:FireServer("Rest",flag)end)
        if not ok then M.lastError=tostring(err);return false end
        if flag then
            M.requests+=1
            M.restOwned=char
            M.pendingUntil=os.clock()+1.7
        else
            M.cancels+=1
        end
        return true
    end
    local function cancelOwned(reason)
        if M.restOwned then
            local char=M.restOwned
            M.restOwned=nil
            if char.Parent and char==player.Character then
                requestRest(char,false)
            end
        end
        M.pendingUntil=0
        if reason then M.reason=reason end
    end
    function M.beforeCarry()
        M.lastInput=os.clock()
        local owned=M.restOwned~=nil
        if owned then
            M.carryInterrupts+=1
            cancelOwned("Carry/drop has priority; releasing own Rest")
            M.status="REST RELEASED FOR CARRY"
        end
        return owned
    end
    local function resetCharacter(char)
        cancelOwned("Animal changed")
        M.lastChar=char
        M.lastHP=nil
        M.lastMax=nil
        M.lastMeasure=0
        M.lastMeasureRest=nil
        M.lastRest=false
        M.stillSince=0
        M.nextRequest=0
        M.lastDamage=os.clock()
        M.prevStatusAt=0
        M.prevStatusRest=nil
        M.statusValues={}
        M.statusActive=false
    end
    -- Under a deliberate user-enabled Rest mode, use a more realistic
    -- nearby-threat threshold than v9's 62-stud hard block. Never Rest
    -- while combat, damaged very recently, moving or any player is inside
    -- 32 studs; enemy velocities and the server can still surprise us.
    local function dangerNearby(root)
        -- Only nearby replicated animals; streaming may omit others.
        local count=0
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player and other.Character then
                local e=other.Character:FindFirstChild("HumanoidRootPart")
                local h=other.Character:FindFirstChildOfClass("Humanoid")
                if e and h and h.Health>0 then
                    count+=1
                    if (root.Position-e.Position).Magnitude<32 then
                        return true,count
                    end
                end
            end
        end
        return false,count
    end
    local function combatInput()
        local now=os.clock()
        M.lastInput=now
        if M.restOwned then
            M.attackInterrupts+=1
            cancelOwned("Combat/movement input; released owned Rest")
            M.status="REST CANCELLED / ATTACK OR MOVE"
        end
    end
    connections[#connections+1]=UIS.InputBegan:Connect(function(input,processed)
        if processed or UIS:GetFocusedTextBox() then return end
        local t=input.UserInputType
        local k=input.KeyCode
        if k==Enum.KeyCode.G then
            M.beforeCarry()
        elseif t==Enum.UserInputType.MouseButton1
            or t==Enum.UserInputType.MouseButton2
            or k==Enum.KeyCode.W or k==Enum.KeyCode.A
            or k==Enum.KeyCode.S or k==Enum.KeyCode.D
            or k==Enum.KeyCode.Space then
            combatInput()
        end
    end)
    function M.setEnabled(v)
        M.enabled=v==true
        if M.enabled and ctx.native and ctx.native.enabled then
            ctx.native.setEnabled(false)
        end
        if not M.enabled then
            cancelOwned("Automatic rest OFF")
            M.status="PASSIVE MONITOR"
        else
            M.status="SAFE REST ARMED"
            M.nextTick=0
        end
    end
    function M.close()
        M.setEnabled(false)
        M.alive=false
        if M.connection then M.connection:Disconnect()end
        for _,c in ipairs(connections) do c:Disconnect()end
    end
    function M.report()
        return table.concat({
            "FERAL NOVA PRIME v15 | Safe Rest / Turtle Shell",
            "auto_rest_enabled="..tostring(M.enabled),
            "status="..M.status,
            "shell="..M.shell,
            "client_rule_multiplier="..tostring(M.multiplier),
            "native_rest_on_requests="..tostring(M.requests),
            "owned_rest_off_requests="..tostring(M.cancels),
            "rest_attribute_transitions="..tostring(M.replicatedRestTransitions),
            "healing_intervals_while_resting="..tostring(M.restingHeals),
            "healing_intervals_when_not_resting="..tostring(M.normalHeals),
            "status_condition_present="..tostring(M.statusActive),
            "injury_rest_rate="..string.format("%.3f",M.statusSamples.injury.restDelta/math.max(.01,M.statusSamples.injury.restSeconds)),
            "injury_normal_rate="..string.format("%.3f",M.statusSamples.injury.normalDelta/math.max(.01,M.statusSamples.injury.normalSeconds)),
            "bleed_rest_rate="..string.format("%.3f",M.statusSamples.bleed.restDelta/math.max(.01,M.statusSamples.bleed.restSeconds)),
            "bleed_normal_rate="..string.format("%.3f",M.statusSamples.bleed.normalDelta/math.max(.01,M.statusSamples.bleed.normalSeconds)),
            "venom_rest_rate="..string.format("%.3f",M.statusSamples.venom.restDelta/math.max(.01,M.statusSamples.venom.restSeconds)),
            "venom_normal_rate="..string.format("%.3f",M.statusSamples.venom.normalDelta/math.max(.01,M.statusSamples.venom.normalSeconds)),
            "cached_health_regen="..tostring(M.cachedHealthRegen),
            "cached_health_rest_multiplier="..tostring(M.cachedHealthRestMult),
            "cached_status_rest_multipliers="..M.cachedStatusRestMults,
            "observed_rest_hp_gain_per_sec="..string.format("%.4f",M.healthRestGain/math.max(.01,M.healthRestSeconds)),
            "observed_normal_hp_gain_per_sec="..string.format("%.4f",M.healthNormalGain/math.max(.01,M.healthNormalSeconds)),
            "rest_hp_increase_samples="..tostring(M.healthRestTicks),
            "normal_hp_increase_samples="..tostring(M.healthNormalTicks),
            "archived_health_rest_multiplier=2",
            "archived_status_rest_multiplier=4",
            "last_hp_gain_per_second="..string.format("%.3f",M.lastRate),
            "movement_or_attack_cancellations="..tostring(M.attackInterrupts),
            "damage_cancellations="..tostring(M.damageInterrupts),
            "danger_blocks="..tostring(M.unsafeBlocks),
            "carry_safety_blocks="..tostring(M.carryBlocks),
            "carry_rest_interruptions="..tostring(M.carryInterrupts),
            "shell_observed_while_moving="..tostring(M.movingShellSeen),
            "last_reason="..M.reason,
            "last_error="..M.lastError,
            "NOTE=WolfController can set WolfRest locally; Rest attribute alone does not prove the server granted 2x/4x."
        },"\n")
    end

    local function tick()
        if not M.alive or not ctx.state.alive then return end
        local now=os.clock()
        if now<M.nextTick then return end
        M.nextTick=now+.22
        local char=player.Character
        if char~=M.lastChar then resetCharacter(char)end
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if not char or not char.Parent or not hum or not root
            or hum.Health<=0 or player:GetAttribute("FeralMenuOpen")==true then
            cancelOwned("Menu, dead or missing character")
            M.shell="NOT ACTIVE";M.multiplier=1
            M.status="WAITING FOR ANIMAL"
            return
        end
        local serverNow=workspace:GetServerTimeNow()
        local rest=char:GetAttribute("WolfRest")==true
        M.shell,M.multiplier=Recovery.shellState(
            char:GetAttribute("Species"),rest,
            char:GetAttribute("WolfRestAt"),serverNow
        )
        if rest and not M.lastRest then
            M.replicatedRestTransitions+=1
        end
        M.lastRest=rest
        -- Real replicated status attributes, NOT local StatusConfig writes.
        -- A status may be re-applied in combat. Increases are excluded from
        -- recovery-rate estimates, and samples across a rest toggle are not
        -- compared because they cross two different modes.
        M.statusActive=false
        local statusInterval=M.prevStatusAt>0 and now-M.prevStatusAt or 0
        for _,entry in ipairs(statusKeys) do
            local current=char:GetAttribute(entry.key)
            if finite(current) then
                if current>entry.limit then M.statusActive=true end
                local last=M.statusValues[entry.key]
                if finite(last) and statusInterval>.15 and statusInterval<3.5
                    and M.prevStatusRest==rest then
                    local v=M.statusSamples[entry.name]
                    local delta=last-current
                    if delta>0 then
                        if rest then
                            v.restDelta+=delta;v.restTicks+=1
                        else
                            v.normalDelta+=delta;v.normalTicks+=1
                        end
                    elseif delta<-.01 then
                        v.gainedTicks+=1
                    end
                    -- Rate denominator includes time without gains, only
                    -- while the negative effect is still above its cutoff.
                    -- Exclude fresh application and samples crossing a rest toggle.
                    if last>entry.limit and delta>=-.01 then
                        if rest then
                            v.restSeconds+=statusInterval
                        else
                            v.normalSeconds+=statusInterval
                        end
                    end
                end
                M.statusValues[entry.key]=current
            else
                M.statusValues[entry.key]=nil
            end
        end
        M.prevStatusAt=now
        M.prevStatusRest=rest
        if now-M.lastMeasure>.85 then
            if finite(hum.Health) and finite(hum.MaxHealth) then
                if finite(M.lastHP) and M.lastMax==hum.MaxHealth then
                    local delta=hum.Health-M.lastHP
                    local interval=now-M.lastMeasure
                    local compatible=M.lastMeasureRest==rest
                    -- Use all eligible damaged-but-not-damaged-again
                    -- observation time, including zero-gain intervals.
                    if compatible and M.lastHP<hum.MaxHealth-.2
                        and delta>=-.01 then
                        if rest then
                            M.healthRestSeconds+=interval
                        else
                            M.healthNormalSeconds+=interval
                        end
                    end
                    if delta>.01 then
                        M.lastRate=delta/math.max(now-M.lastMeasure,.1)
                        if rest then
                            M.restingHeals+=1
                            if compatible then
                                M.healthRestGain+=delta
                                M.healthRestTicks+=1
                            end
                        else
                            M.normalHeals+=1
                            if compatible then
                                M.healthNormalGain+=delta
                                M.healthNormalTicks+=1
                            end
                        end
                    elseif delta<-.01 then
                        M.lastDamage=now
                        M.lastRate=0
                        if M.restOwned and M.multiplier~=.30 then
                            M.damageInterrupts+=1
                            cancelOwned("Damage observed; combat has priority")
                        end
                    else
                        M.lastRate=0
                    end
                end
                M.lastHP=hum.Health
                M.lastMax=hum.MaxHealth
                M.lastMeasure=now
                M.lastMeasureRest=rest
            end
        end
        -- Owner's prey/carcass carry must take precedence over *any*
        -- resting status, including Turtle shell and WolfRest. In v12
        -- this check came AFTER returning from the rest-state branch.
        local carryState,holding,victim="UNKNOWN",false,false
        if ctx.carry and ctx.carry.classify then
            carryState,holding,victim=ctx.carry.classify(char)
        else
            holding=char:GetAttribute("FeralCarcassCarry")==true
            victim=char:GetAttribute("FeralCarried")==true
                or char:GetAttribute("FeralPinned")==true
                or char:GetAttribute("FeralDragged")==true
        end
        if holding or victim then
            if M.restOwned then
                M.beforeCarry()
            end
            if holding then
                M.carryBlocks+=1
                M.status="CARRYING / REST HELD OFF"
            else
                M.status="CAPTURED / ESCAPE PRIORITY"
            end
            return
        end
        local moving=root.AssemblyLinearVelocity.Magnitude>1.5
        if moving and M.multiplier==.30 then M.movingShellSeen=true end
        if M.restOwned and moving then
            cancelOwned("Movement interrupted Rest")
        end
        if M.multiplier==.30 then
            M.status="TURTLE SHELL CONDITION SEEN"
            return
        end
        if rest then
            M.status=M.statusActive
                and "REST ACTIVE / 4x STATUS RULE (UNVERIFIED)"
                or "REST ACTIVE / 2x HP RULE (UNVERIFIED)"
            return
        end
        if not M.enabled then
            M.status="PASSIVE MONITOR"
            return
        end
        if moving then
            M.stillSince=0
            M.status="MOVING / REST NOT REQUESTED"
            return
        end
        if M.stillSince==0 then M.stillSince=now end
        if now-M.stillSince<1.7 or now-M.lastInput<2.5
            or now-M.lastDamage<5.5 then
            M.status="WAITING FOR SAFE IDLE"
            return
        end
        -- A Turtle may deliberately rest for shell protection at full HP.
        -- This is opt-in only and still subject to safety/idle checks.
        local species=char:GetAttribute("Species")
        local turtle=type(species)=="string" and
            string.find(species,"SnappingTurtle",1,true)~=nil
        if hum.Health>=hum.MaxHealth-.2 and not M.statusActive and not turtle then
            M.status="HP FULL / NO STATUS TO CLEAR"
            return
        end
        local combatUntil=player:GetAttribute("FeralCombatUntil")
        if finite(combatUntil) and combatUntil>serverNow then
            M.status="IN COMBAT / REST BLOCKED"
            return
        end
        local danger,scanned=dangerNearby(root)
        if danger then
            M.unsafeBlocks+=1
            M.status="ANIMAL NEARBY / REST BLOCKED"
            return
        end
        local hunger,thirst=char:GetAttribute("Hunger"),char:GetAttribute("Thirst")
        if (finite(hunger) and hunger<20)
            or (finite(thirst) and thirst<20) then
            M.status="LOW NEEDS / REST NOT REQUESTED"
            return
        end
        if now<M.pendingUntil then
            M.status="REST REQUESTED / UNCONFIRMED"
            return
        end
        if now<M.nextRequest then
            M.status="REST COOLDOWN / WAITING"
            return
        end
        M.nextRequest=now+8
        local ok=requestRest(char,true)
        M.status=ok and "REQUESTING REST: EXPECT 2x HP / 4x STATUS"
            or "REST UNAVAILABLE"
    end
    M.connection=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            M.lastError=tostring(err)
            cancelOwned("Recovery exception")
            M.status="RECOVERY DISABLED ON ERROR"
            M.enabled=false
        end
    end)
    return M
end
return Recovery
