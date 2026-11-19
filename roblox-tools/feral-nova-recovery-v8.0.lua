-- FERAL NOVA PRIME v8 / Rest & Turtle Shell
-- Native Rest boolean requests with confirmed own-character cues.
-- Never overwrites WolfRest or WolfRestAt: those must be replicated.
-- For SnappingTurtle the captured CombatConfig.shellMult is 0.30
-- only while WolfRest=true after at least 1 second.
local Recovery={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function number(n)
    return type(n)=="number" and n==n and n>=0 and n<1e9
end
local function isTurtle(char)
    if not char then return false end
    local sp=char:GetAttribute("Species")
    return type(sp)=="string" and string.find(sp,"SnappingTurtle",1,true)~=nil
end
function Recovery.shellState(species,rest,restAt,serverNow)
    if type(species)~="string"
        or not string.find(species,"SnappingTurtle",1,true) then
        return "NOT TURTLE",1
    end
    if rest~=true then return "SHELL INACTIVE",1 end
    if number(restAt) and number(serverNow) then
        if serverNow-restAt<1 then return "SHELL ARMING",1 end
    else
        return "REST REPLICATED / TIMER UNKNOWN",1
    end
    return "SHELL CONDITION MET",.30
end

function Recovery.attach(ctx)
    local M={
        alive=true,enabled=true,status="WATCHING",
        shell="NOT TURTLE",multiplier=1,attempts=0,
        accepted=0,wasRest=false,lastError="",
        lastChar=nil,restOwned=nil,nextTick=0,lastSent=0,
        nextRequest=0,started=0,pendingUntil=0,
        stationaryFor=0,idleAt=0,healedTicks=0,
        lastHP=nil,lastMax=nil,nextMeasure=0,
        lastReason="",
        movingProbeUsed=false,movingProbeAt=0,movingAccepted=false,
        movingRejected=false,probes=0
    }
    local function remote()
        local r=RS:FindFirstChild("WolfActions")
        return r and r:IsA("RemoteEvent") and r or nil
    end
    local function fireRest(on,char)
        local r=remote()
        if not r then M.lastError="WolfActions remote unavailable";return false end
        if not char or player.Character~=char then return false end
        local ok,err=pcall(function()r:FireServer("Rest",on)end)
        if not ok then M.lastError=tostring(err);return false end
        if on then
            M.attempts+=1
            M.lastSent=os.clock()
            M.pendingUntil=os.clock()+2.2
            M.restOwned=char
        end
        return true
    end
    local function endOwned()
        if M.restOwned then
            local old=M.restOwned
            M.restOwned=nil
            if old.Parent and player.Character==old then fireRest(false,old)end
        end
    end
    local function resetState()
        M.stationaryFor=0;M.idleAt=0
        M.lastHP=nil;M.lastMax=nil
        M.started=0;M.pendingUntil=0;M.nextRequest=0
        M.wasRest=false;M.movingProbeUsed=false
        M.movingProbeAt=0;M.movingAccepted=false
        M.movingRejected=false
    end
    function M.setEnabled(on)
        M.enabled=on==true
        if not M.enabled then
            endOwned()
            resetState()
            M.status="OFF"
        else
            M.nextTick=0
            M.status="WATCHING"
        end
    end
    function M.close()
        if not M.alive then return end
        M.setEnabled(false)
        M.alive=false
        if M.connection then M.connection:Disconnect()end
    end
    function M.report()
        return table.concat({
            "FERAL NOVA PRIME v8 | Recovery and Shell",
            "enabled="..tostring(M.enabled),
            "status="..M.status,
            "shell="..M.shell,
            "client_shell_multiplier="..tostring(M.multiplier),
            "native_rest_requests="..tostring(M.attempts),
            "replicated_rest_transitions="..tostring(M.accepted),
            "observed_healing_ticks="..tostring(M.healedTicks),
            "moving_shell_probe="..(M.movingAccepted and "REST OBSERVED DURING MOTION"
                or M.movingRejected and "REST NOT SUSTAINED IN MOTION"
                or M.movingProbeUsed and "PENDING"
                or "NOT ATTEMPTED"),
            "reason="..M.lastReason,
            "last_error="..M.lastError,
            "NOTE=Rest requests and matching attributes do not establish accepted healing or damage reduction."
        },"\n")
    end
    local function tick()
        if not M.alive or not ctx.state.alive then return end
        local now=os.clock()
        if now<M.nextTick then return end
        M.nextTick=now+.25
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local menu=player:GetAttribute("FeralMenuOpen")==true
        if char~=M.lastChar then
            endOwned()
            M.lastChar=char
            resetState()
        end
        if not char or not char.Parent or menu or not hum
            or not root or hum.Health<=0 then
            endOwned()
            M.status="WAITING FOR ANIMAL"
            M.shell="NOT ACTIVE";M.multiplier=1
            M.lastReason="menu, spawn or downed"
            return
        end
        local turtle=isTurtle(char)
        local serverNow=workspace:GetServerTimeNow()
        local rest=char:GetAttribute("WolfRest")==true
        local restAt=char:GetAttribute("WolfRestAt")
        local species=char:GetAttribute("Species")
        M.shell,M.multiplier=Recovery.shellState(species,rest,restAt,serverNow)
        if rest and not M.wasRest then
            M.accepted+=1
        end
        M.wasRest=rest
        -- Count increases only if MaxHealth did not change.
        if now>=M.nextMeasure then
            M.nextMeasure=now+1
            if number(hum.Health) and number(hum.MaxHealth) then
                if M.lastHP and M.lastMax==hum.MaxHealth
                    and hum.Health>M.lastHP+.01 then
                    M.healedTicks+=1
                end
                M.lastHP=hum.Health
                M.lastMax=hum.MaxHealth
            end
        end
        if not M.enabled then M.status="OFF";return end
        local speed=root.AssemblyLinearVelocity.Magnitude
        local moving=speed>1.35
        local combatUntil=player:GetAttribute("FeralCombatUntil")
        local inCombat=number(combatUntil) and combatUntil>serverNow
        local safeNeeds=true
        for _,key in ipairs({"Hunger","Thirst"}) do
            local v=char:GetAttribute(key)
            if number(v) and v<12 then safeNeeds=false end
        end

        if moving then
            M.stationaryFor=0
            M.idleAt=0
            -- Turtle shell is not automatically claimed while running.
            -- A one-off, time-limited probe can check if native Rest
            -- remains replicated in motion, without repeatedly spamming.
            if turtle and not M.movingProbeUsed and not rest and not inCombat
                and safeNeeds and now>=M.nextRequest then
                M.movingProbeUsed=true
                M.movingProbeAt=now
                M.probes+=1
                fireRest(true,char)
                M.nextRequest=now+5
                M.lastReason="single moving Turtle-rest compatibility probe"
            end
            if M.movingProbeUsed and not M.movingRejected
                and not M.movingAccepted and now-M.movingProbeAt>1.45 then
                if rest and M.multiplier==.30 then
                    M.movingAccepted=true
                else
                    M.movingRejected=true
                end
                -- End test if there is no server-confirmed rest.
                if M.movingRejected then endOwned() end
            end
            if M.movingAccepted and rest then
                M.status="SHELL OBSERVED WHILE MOVING"
            elseif turtle then
                M.status="MOVING / SHELL NOT CONFIRMED"
            else
                M.status="MOVING / REST INACTIVE"
            end
            -- Don't send repeated native Rest requests while moving.
            return
        end
        if M.idleAt==0 then M.idleAt=now end
        M.stationaryFor=now-M.idleAt
        local deficit=hum.Health<hum.MaxHealth-.25
        if not turtle and not deficit then
            if M.restOwned then endOwned() end
            M.status="HEALTH FULL"
            return
        end
        if inCombat then
            M.status="COMBAT / REST BLOCKED"
            M.lastReason="combat timer active"
            return
        end
        if not safeNeeds then
            M.status="LOW NEEDS"
            M.lastReason="food/water too low to rely on recovery"
            return
        end
        if rest then
            M.status=turtle and (M.multiplier==.30
                and "TURTLE SHELL READY" or "TURTLE SHELL ARMING")
                or "REST REPLICATED"
            return
        end
        if M.stationaryFor<1.15 then
            M.status="SETTLING / HOLD STILL"
            return
        end
        if M.pendingUntil>now then
            M.status="REST REQUESTED / NOT CONFIRMED"
            return
        end
        if M.attempts>0 and not rest then
            M.lastReason="native request may be rejected by server"
        end
        if now>=M.nextRequest then
            M.nextRequest=now+5.5
            local ok=fireRest(true,char)
            M.status=ok and "REST REQUESTED / WAITING"
                or "REST UNAVAILABLE"
        else
            M.status="WAITING FOR REST ELIGIBILITY"
        end
    end
    M.connection=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            M.lastError=tostring(err)
            endOwned()
            M.status="RECOVERY ERROR"
            M.enabled=false
        end
    end)
    return M
end
return Recovery
