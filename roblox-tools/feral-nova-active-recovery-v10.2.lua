-- FERAL NOVA v10.2 / ONE ACTIVE RECOVERY CONTROLLER + manual Rest passthrough
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
        nextTick=0,lastAt=os.clock(),lastError=""
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
        if native and native.manualRest then
            A.mode="MANUAL_REST"
            A.status="MANUAL REST / GAME CONTROLS POSE / AUTO SIGNAL YIELDED"
        elseif native and native.active then
            A.mode="NATIVE_RECOVERY"
            A.status="ACTIVE / GUARDED NATIVE REST + CLIENT STATUS INPUTS"
        elseif native and native.poseBlockedChar then
            A.mode="POSE_SAFE_CONFIG_ONLY"
            A.status="POSE SAFETY / CONFIG-ONLY UNTIL RESPAWN"
        elseif native and native.enabled then
            A.mode="WAITING_FOR_SAFE_WINDOW"
            A.status=native.status or "WAITING FOR SAFE REST WINDOW"
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
            "native_signal_active="..tostring(native and native.active),
            "manual_rest_preserved="..tostring(native and native.manualRest),
            "health_client_config_applied="..tostring(A.healthInputsApplied),
            "status_client_config_applied="..tostring(A.statusInputsApplied),
            "native_rest_status_multiplier_ready="..tostring(A.restMultiplierReady),
            "pose_safety_events="..A.poseSafetyEvents,
            "native_seconds="..string.format("%.2f",A.nativeActiveSeconds),
            "config_only_seconds="..string.format("%.2f",A.configOnlySeconds),
            "safe_rest_legacy_enabled="..tostring(safeRest and safeRest.enabled),
            "mobile_trial_legacy_enabled="..tostring(mobile and mobile.enabled),
            "NOTE=Client statuses alone do not establish 4x server clearance.",
            "NOTE=Automatic recovery yields to manual Rest; manual pose is not overwritten.",
            "NOTE=Nearby players never pause active recovery by proximity alone."
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