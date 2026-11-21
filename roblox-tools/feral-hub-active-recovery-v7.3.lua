-- FERAL HUB v7.3 / coordinated guarded native recovery outside combat
-- Coordinates existing native Rest-signal HP recovery and local HP/status
-- config. Never starts Safe Rest or Mobile A/B, never writes HP/effect values.
local Active={}
local RunService=game:GetService("RunService")
function Active.attach(ctx)
    local native=ctx.native
    local regen=ctx.regen
    local safeRest=ctx.recovery
    local mobile=ctx.mobile
    local A={
        alive=true,enabled=false,mode="OFF",status="OFF",
        nativeEligible=false,healthInputsApplied=false,
        statusInputsApplied=false,restMultiplierReady=false,
        poseSafetyEvents=0,activationCount=0,configOnlySeconds=0,
        nativeActiveSeconds=0,blockedSeconds=0,interventions=0,
        nextTick=0,lastAt=os.clock(),lastError="",
        lastReason="OFF",reasonSeconds={},modeTransitions=0,
        lastMode="OFF",woundedBlockedSeconds=0,
        autoRealRestFallback=false,realRestFallback=false,
        fallbackCount=0,fallbackReason="DISABLED_BY_USER_PREFERENCE",
        combatBlockedSeconds=0,
    }
    local function disableLegacy()
        if safeRest and safeRest.enabled then
            safeRest.setEnabled(false)
            A.interventions+=1
        end
        if mobile and mobile.enabled then
            mobile.setEnabled(false)
            A.interventions+=1
        end
    end
    function A.setEnabled(flag)
        if not A.alive then return false end
        if flag~=true then
            A.enabled=false
            if native then native.setEnabled(false)end
            if regen then regen.setEnabled(false)end
            disableLegacy()
            A.mode="OFF"
            A.status="OFF / NATIVE REST RELEASED / LOCAL INPUTS RESTORED"
            return false
        end
        A.enabled=true
        A.activationCount+=1
        disableLegacy()
        if regen then regen.setEnabled(true)end
        if native then native.setEnabled(true)end
        A.refresh()
        return true
    end
    function A.refresh()
        if not A.alive or not A.enabled then return end
        A.healthInputsApplied=regen and regen.needsApplied==true or false
        A.statusInputsApplied=regen and regen.statusApplied==true or false
        A.restMultiplierReady=regen and regen.restMultipliersReady==true or false
        A.poseSafetyEvents=native and native.poseSafetyPauses or 0
        A.nativeEligible=native and native.enabled==true
            and native.poseBlockedChar~=game:GetService("Players").LocalPlayer.Character or false
        if native and native.active then
            A.mode="NATIVE_RECOVERY"
            A.status="MOBILE REST SIGNAL / MASKED POSE / SERVER EFFECT UNVERIFIED"
        elseif native and type(native.poseRetryAt)=="number"
            and os.clock()<native.poseRetryAt then
            A.mode="POSE_SAFETY_BACKOFF"
            A.lastReason="POSE RETRY BACKOFF"
            A.status="POSE ECHO GUARD / REST RELEASED / AUTOMATIC SAFE RETRY"
        elseif native and native.poseBlockedChar then
            A.mode="POSE_SAFE_CONFIG_ONLY"
            A.status="POSE SAFETY / CONFIG-ONLY UNTIL RESPAWN"
        elseif native and native.enabled then
            local cause=native.status or "UNKNOWN SAFE WINDOW"
            A.lastReason=cause
            local inCombat=cause=="COMBAT TAG ACTIVE / REST OFF"
                or cause=="COMBAT CLOCK UNAVAILABLE / REST OFF"
            local full=cause=="FULL HP / NO STATUS TO CLEAR"
            local action=cause=="HELD ATTACK / RECOVERY PAUSED"
                or cause=="ATTACK / CARRY COOLDOWN"
                or cause=="CHAT PRIORITY"
                or cause=="ESCAPE HAS PRIORITY"
                or cause=="CLIMB HAS PRIORITY"
                or cause=="FLIGHT / DIVE HAS PRIORITY"
                or cause=="FEED HAS PRIORITY"
                or cause=="CARRY HAS PRIORITY"
                or cause=="NATIVE CARRY / REST RELEASED"
            A.mode=inCombat and "COMBAT_BLOCKED"
                or full and "NO_RECOVERY_NEEDED"
                or action and "PAUSED_FOR_ACTION"
                or "WAITING_FOR_SAFE_WINDOW"
            A.status=cause
        elseif A.healthInputsApplied then
            A.mode="CONFIG_ONLY"
            A.status="CLIENT CONFIG ONLY / REST NOT ACTIVE"
        else
            A.mode="UNAVAILABLE"
            A.status="RECOVERY MODULES UNAVAILABLE / CHECK STATUS REPORT"
        end
    end
    function A.report()
        A.refresh()
        return table.concat({
            "FERAL NOVA PRIME v29 | Unified Active Recovery",
            "single_control_enabled="..tostring(A.enabled),
            "mode="..A.mode,
            "status="..A.status,
            "native_wait_reason="..A.lastReason,
            "auto_visible_rest_disabled="..tostring(not A.autoRealRestFallback),
            "visible_rest_fallback_count="..A.fallbackCount,
            "combat_blocked_seconds="..string.format("%.2f",A.combatBlockedSeconds),
            "mode_transition_count="..A.modeTransitions,
            "wounded_wait_seconds="..string.format("%.2f",A.woundedBlockedSeconds),
            "native_signal_active="..tostring(native and native.active),
            "health_client_config_applied="..tostring(A.healthInputsApplied),
            "status_client_config_applied="..tostring(A.statusInputsApplied),
            "native_rest_status_multiplier_ready="..tostring(A.restMultiplierReady),
            "pose_safety_events="..A.poseSafetyEvents,
            "pose_retry_remaining_seconds="..string.format("%.1f",math.max(0,(native and native.poseRetryAt or 0)-os.clock())),
            "native_seconds="..string.format("%.2f",A.nativeActiveSeconds),
            "config_only_seconds="..string.format("%.2f",A.configOnlySeconds),
            "paused_seconds="..string.format("%.2f",A.reasonSeconds.PAUSED_FOR_ACTION or 0),
            "full_health_seconds="..string.format("%.2f",A.reasonSeconds.NO_RECOVERY_NEEDED or 0),
            "blocked_other_seconds="..string.format("%.2f",A.reasonSeconds.WAITING_FOR_SAFE_WINDOW or 0),
            "safe_rest_legacy_enabled="..tostring(safeRest and safeRest.enabled),
            "mobile_trial_legacy_enabled="..tostring(mobile and mobile.enabled),
            "NOTE=Client statuses alone do not establish 4x server clearance.",
            "NOTE=No automatic visible Rest, no posture-forcing, no Humanoid.Health writes.",
            "NOTE=Masked mobile Rest signal suspends for server-observed combat state and attacks.",
            "NOTE=Actual game-server healing cannot be guaranteed by client-side configuration."
        },"\n")
    end
    local connection
    connection=RunService.Heartbeat:Connect(function()
        if not A.alive then return end
        local now=os.clock()
        if now<A.nextTick then return end
        A.nextTick=now+.5
        local dt=math.clamp(now-A.lastAt,0,1.5)
        A.lastAt=now
        if A.enabled then
            local ok,err=pcall(function()
                disableLegacy()
                A.refresh()
                if A.lastMode~=A.mode then
                    A.modeTransitions+=1
                    A.lastMode=A.mode
                end
                A.reasonSeconds[A.mode]=(A.reasonSeconds[A.mode] or 0)+dt
                if A.mode=="COMBAT_BLOCKED" then
                    A.combatBlockedSeconds+=dt
                end
                local p=game:GetService("Players").LocalPlayer
                local c=p and p.Character
                local h=c and c:FindFirstChildOfClass("Humanoid")
                if h and h.Health>0 and h.Health<h.MaxHealth-.35
                    and A.mode~="NATIVE_RECOVERY" then
                    A.woundedBlockedSeconds+=dt
                end
                if A.mode=="NATIVE_RECOVERY" then
                    A.nativeActiveSeconds+=dt
                elseif A.mode=="POSE_SAFE_CONFIG_ONLY"
                    or A.mode=="CONFIG_ONLY" then
                    A.configOnlySeconds+=dt
                else
                    A.blockedSeconds+=dt
                end
            end)
            if not ok then
                A.lastError=tostring(err)
                A.status="RECOVERY STATUS ERROR / CHECK REPORT"
            end
        end
    end)
    function A.close()
        if not A.alive then return end
        A.setEnabled(false)
        A.alive=false
        if connection then connection:Disconnect()end
    end
    ctx.activeRecovery=A
    return A
end
return Active