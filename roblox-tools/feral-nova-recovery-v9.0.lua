-- FERAL NOVA PRIME v9 / safe rest + passive Turtle shell observer.
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
        damageInterrupts=0,unsafeBlocks=0,
        restOwned=nil,restActive=false,
        lastChar=nil,lastHP=nil,lastMax=nil,
        lastMeasure=0,lastRest=false,lastInput=-math.huge,
        lastDamage=-math.huge,stillSince=0,
        nextRequest=0,nextTick=0,lastError="",
        pendingUntil=0,restAttempts=0,
        reason="Not auto-resting until you enable SAFE REST"
    }
    local connections={}
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
    local function resetCharacter(char)
        cancelOwned("Animal changed")
        M.lastChar=char
        M.lastHP=nil
        M.lastMax=nil
        M.lastMeasure=0
        M.lastRest=false
        M.stillSince=0
        M.nextRequest=0
        M.lastDamage=os.clock()
    end
    local function dangerNearby(root)
        -- Only nearby replicated animals; streaming may omit others.
        local count=0
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player and other.Character then
                local e=other.Character:FindFirstChild("HumanoidRootPart")
                local h=other.Character:FindFirstChildOfClass("Humanoid")
                if e and h and h.Health>0 then
                    count+=1
                    if (root.Position-e.Position).Magnitude<62 then
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
        if t==Enum.UserInputType.MouseButton1
            or t==Enum.UserInputType.MouseButton2
            or k==Enum.KeyCode.W or k==Enum.KeyCode.A
            or k==Enum.KeyCode.S or k==Enum.KeyCode.D
            or k==Enum.KeyCode.Space then
            combatInput()
        end
    end)
    function M.setEnabled(v)
        M.enabled=v==true
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
            "FERAL NOVA PRIME v9 | Safe Rest / Turtle Shell",
            "auto_rest_enabled="..tostring(M.enabled),
            "status="..M.status,
            "shell="..M.shell,
            "client_rule_multiplier="..tostring(M.multiplier),
            "native_rest_on_requests="..tostring(M.requests),
            "owned_rest_off_requests="..tostring(M.cancels),
            "rest_state_transitions="..tostring(M.replicatedRestTransitions),
            "healing_intervals_while_resting="..tostring(M.restingHeals),
            "healing_intervals_when_not_resting="..tostring(M.normalHeals),
            "last_hp_gain_per_second="..string.format("%.3f",M.lastRate),
            "movement_or_attack_cancellations="..tostring(M.attackInterrupts),
            "damage_cancellations="..tostring(M.damageInterrupts),
            "danger_blocks="..tostring(M.unsafeBlocks),
            "shell_observed_while_moving="..tostring(M.movingShellSeen),
            "last_reason="..M.reason,
            "last_error="..M.lastError,
            "NOTE=Observed rest and healing do not prove faster server regeneration."
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
        if now-M.lastMeasure>.85 then
            if finite(hum.Health) and finite(hum.MaxHealth) then
                if finite(M.lastHP) and M.lastMax==hum.MaxHealth then
                    local delta=hum.Health-M.lastHP
                    if delta>.01 then
                        M.lastRate=delta/math.max(now-M.lastMeasure,.1)
                        if rest then M.restingHeals+=1 else M.normalHeals+=1 end
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
            end
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
            M.status="REST ACTIVE / BITES DISABLED"
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
        if now-M.stillSince<3.0 or now-M.lastInput<5.0
            or now-M.lastDamage<7 then
            M.status="WAITING FOR SAFE IDLE"
            return
        end
        if hum.Health>=hum.MaxHealth-.2 then
            M.status="HP FULL / NO REST NEEDED"
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
        M.status=ok and "REST SENT / STATE UNCONFIRMED"
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
