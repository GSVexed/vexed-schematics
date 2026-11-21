-- FERAL HUB v7.3 / restored v1.1 Rest signaling with bounded pose safety
-- Previously observed mobile Rest signal sometimes doubled real HP recovery.
-- Keep one native Rest signal active outside combat even during movement.
-- Never force physical Rest; mask local WolfRest with recurrence safeguards.
-- Server heal and status benefits are still authoritative and not guaranteed.
local Native={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local EFFECTS={"FeralInjury","FeralBleed","FeralVenomAmt"}
local function finite(n)
    return type(n)=="number" and n==n and n>=0 and n<1e9
end
local function blockedByActivity(char,ctx)
    if not char or not char.Parent then return "NO ANIMAL" end
    if char:GetAttribute("FeralPinned")==true
        or char:GetAttribute("FeralCarried")==true
        or char:GetAttribute("FeralDragged")==true then
        return "ESCAPE HAS PRIORITY"
    end
    -- Flight, climb, feeding and held prey are not reasons to
    -- suppress recovery. The pose mask and short input grace protect
    -- interactions, while combat itself is a strict exclusion.
    if ctx.carry and ctx.carry.classify then
        local _,_,victim=ctx.carry.classify(char)
        if victim then return "ESCAPE HAS PRIORITY" end
    end
    local untilAt=player:GetAttribute("FeralCombatUntil")
    local ownDeadline=char:GetAttribute("FeralCombatUntil")
    if finite(ownDeadline) and (not finite(untilAt) or ownDeadline>untilAt) then
        untilAt=ownDeadline
    end
    if finite(untilAt) then
        local ok,serverNow=pcall(function()return workspace:GetServerTimeNow()end)
        if not ok or not finite(serverNow) then
            return "COMBAT CLOCK UNAVAILABLE / REST OFF"
        end
        if untilAt>serverNow then
            return "COMBAT TAG ACTIVE / REST OFF"
        end
    end
    local species=char:GetAttribute("Species")
    if type(species)=="string"
        and string.find(species,"SnappingTurtle",1,true) then
        return "TURTLE SHELL PROTECTED / NO MASK"
    end
    return nil
end
Native.blockedByActivity=blockedByActivity
function Native.attach(ctx)
    local N={
        enabled=false,alive=true,active=false,
        status="OFF",reason="OFF",lastError="",
        owned=nil,mask=nil,nextTick=0,pausedUntil=0,
        nextRequest=0,nextRefresh=0,
        nativeOn=0,nativeOff=0,maskWrites=0,maskEchoes=0,
        maskErrors=0,pauses=0,activations=0,
        forcedOffBeforeActions=0,combatPauses=0,
        lastHP=nil,lastStatus=nil,lastHPMax=nil,lastAt=0,
        observedHPGain=0,eligibleHPSeconds=0,HPGainTicks=0,
        effectClears={FeralInjury=0,FeralBleed=0,FeralVenomAmt=0},
        effectSeconds={FeralInjury=0,FeralBleed=0,FeralVenomAmt=0},
        lastBlock=nil,inputAt=-math.huge,
        poseRecurrences=0,poseSafetyPauses=0,poseBlockedChar=nil,
        poseRetryAt=0,poseBackoffSeconds=0,lastAnimal=nil,signalStartedAt=0,
        poseSafetyFailures=0,nativeRefreshRequestsSuppressed=0,
        combatTagBlocks=0,restRefreshAttempts=0,restRefreshSuccess=0,
        legacyRestCadenceSeconds=5,preMaskStarts=0,renderMaskPasses=0,
        lastProgressAt=0,lastGainValue=0,refreshAfterSeconds=18,
        lastRefreshAt=-math.huge,maxRefreshesPerLife=2,
        mobileSignalSeconds=0,fullHealthSignalSeconds=0,
        noNeedSignalSeconds=0,
    }
    local conns={}
    local masking=false
    -- v1.1 Bear prototype used mask priority 199, before native WolfAnim.
    local renderName="FERAL_HUB_V73_REST_MASK"
    local function fire(on,char)
        local remote=RS:FindFirstChild("WolfActions")
        if not remote or not remote:IsA("RemoteEvent") then
            N.lastError="WolfActions missing";return false
        end
        if player.Character~=char then return false end
        local ok,err=pcall(function()remote:FireServer("Rest",on)end)
        if not ok then N.lastError=tostring(err);return false end
        if on then N.nativeOn+=1 else N.nativeOff+=1 end
        return true
    end
    local function unmask()
        local m=N.mask
        N.mask=nil
        if not m then return end
        if m.conn then pcall(function()m.conn:Disconnect()end)end
        pcall(function()RunService:UnbindFromRenderStep(renderName)end)
        -- Never "repair" WolfRest by writing true: that would itself
        -- activate a local Rest pose even when the server is not resting.
    end
    local function cancel(reason,preempt)
        unmask()
        local char=N.owned
        N.owned=nil;N.active=false
        if char then
            if preempt then N.forcedOffBeforeActions+=1 end
            if char.Parent and player.Character==char then
                fire(false,char)
            end
        end
        if reason then N.reason=reason;N.status=reason end
    end
    local function writeMask(m)
        if not N.enabled or not N.alive or N.mask~=m
            or player.Character~=m.char or masking then return end
        if m.char:GetAttribute("WolfRest")==true then
            local now=os.clock()
            if now-(m.echoWindowAt or 0)>2 then
                m.echoWindowAt=now
                m.trueEchoes=0
            end
            m.trueEchoes+=1
            N.poseRecurrences+=1
            -- A single WolfRest=true echo when the native action starts is
            -- expected. Repeated true echoes mean the game keeps forcing the
            -- visible resting pose: release Rest instead of fighting animation.
            if m.trueEchoes>=3 then
                N.poseSafetyPauses+=1
                N.poseSafetyFailures+=1
                -- v7.2 permanently excluded this animal after two bursts.
                -- Use bounded retries without fighting a visible pose.
                local delay=math.min(120,15*2^math.min(3,N.poseSafetyFailures-1))
                N.poseBackoffSeconds=delay
                N.poseRetryAt=now+delay
                N.pausedUntil=math.max(N.pausedUntil,N.poseRetryAt)
                cancel("POSE SAFETY / TEMPORARY RETRY BACKOFF",true)
                return
            end
            masking=true
            local ok=pcall(function()
                m.char:SetAttribute("WolfRest",false)
            end)
            masking=false
            if ok then N.maskWrites+=1
            else
                N.maskErrors+=1
                N.pausedUntil=math.max(N.pausedUntil,now+10)
                cancel("POSE MASK ERROR / SIGNAL RELEASED",true)
            end
        end
    end
    local function beginMask(char)
        local m={char=char,echoWindowAt=os.clock(),trueEchoes=0}
        N.mask=m
        local ok,conn=pcall(function()
            return char:GetAttributeChangedSignal("WolfRest"):Connect(function()
                N.maskEchoes+=1
                writeMask(m)
            end)
        end)
        if not ok then
            N.mask=nil
            N.maskErrors+=1
            return false
        end
        m.conn=conn
        local bound=pcall(function()
            RunService:BindToRenderStep(renderName,199,function()
                if N.mask==m then
                    N.renderMaskPasses+=1
                    writeMask(m)
                end
            end)
        end)
        if not bound then
            N.maskErrors+=1
            unmask()
            return false
        end
        N.preMaskStarts+=1
        writeMask(m)
        return N.mask==m
    end
    local function delayInput(reason,cooldown)
        N.inputAt=os.clock()
        N.pausedUntil=math.max(N.pausedUntil,N.inputAt+(cooldown or .9))
        if N.active then
            N.pauses+=1
            cancel(reason,true)
        end
    end
    function N.beforeCarry()
        local was=N.active
        delayInput("NATIVE CARRY / REST RELEASED",1.2)
        return was
    end
    function N.beforeClimb()
        -- Do not drop the signal merely because the character climbs.
        return false
    end
    function N.beforeFlight()
        -- Do not drop the signal merely because the character takes off.
        return false
    end
    function N.setEnabled(v)
        N.enabled=v==true
        if not N.enabled then
            N.poseBlockedChar=nil
            N.poseSafetyFailures=0
            N.poseRetryAt=0
            N.poseBackoffSeconds=0
            N.lastAnimal=nil
        end
        if not N.enabled then
            cancel("OFF / OWNED REST RELEASED")
        else
            if ctx.recovery and ctx.recovery.enabled then
                ctx.recovery.setEnabled(false)
            end
            if ctx.mobile and ctx.mobile.enabled then
                ctx.mobile.setEnabled(false)
            end
            N.status="ARMED / RECOVER WHILE NOT IN COMBAT"
            N.nextTick=0
        end
        return N.enabled
    end
    conns[#conns+1]=UIS.InputBegan:Connect(function(input,processed)
        if processed or UIS:GetFocusedTextBox() then return end
        local key=input.KeyCode
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.MouseButton2 then
            N.combatPauses+=1
            delayInput("ATTACK PRIORITY / REST RELEASED",1.2)
        elseif key==Enum.KeyCode.G then
            N.beforeCarry()
        end
    end)
    local function sample(char,hum,now)
        local state={hp=hum.Health,max=hum.MaxHealth,effects={}}
        for _,key in ipairs(EFFECTS) do
            state.effects[key]=char:GetAttribute(key)
        end
        local old=N.lastStatus
        if N.owned==char and old and N.lastAt>0
            and now-N.lastAt>.10 and now-N.lastAt<1.5 then
            local delta=state.hp-old.hp
            if finite(old.hp) and finite(old.max) and
                state.max==old.max and old.hp<old.max-.20 and delta>=-.01 then
                N.eligibleHPSeconds+=now-N.lastAt
                if delta>.01 then
                    N.observedHPGain+=delta
                    N.HPGainTicks+=1
                end
            end
            for _,key in ipairs(EFFECTS) do
                local a,b=old.effects[key],state.effects[key]
                if finite(a) and finite(b) and a>.2 and b<=a then
                    N.effectSeconds[key]+=now-N.lastAt
                    N.effectClears[key]+=a-b
                end
            end
        end
        N.lastStatus=state;N.lastAt=now
    end
    local function tick()
        if not N.alive or not ctx.state.alive then return end
        local now=os.clock()
        if now<N.nextTick then return end
        N.nextTick=now+.2
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not N.enabled or not char or not char.Parent or not hum
            or hum.Health<=0 or player:GetAttribute("FeralMenuOpen")==true then
            if N.active then cancel("ANIMAL UNAVAILABLE") end
            N.lastStatus=nil
            return
        end
        if N.lastAnimal~=char then
            N.lastAnimal=char
            N.poseSafetyFailures=0
            N.poseRetryAt=0
            N.poseBackoffSeconds=0
        end
        if now<N.poseRetryAt then
            N.status="POSE SAFETY / BACKOFF (NO VISIBLE REST)"
            if N.active then cancel(N.status,true)end
            N.lastStatus=nil
            return
        end
        local blocked=blockedByActivity(char,ctx)
        N.lastBlock=blocked
        if blocked or now<N.pausedUntil then
            if blocked=="COMBAT TAG ACTIVE / REST OFF" then
                N.combatTagBlocks+=1
            end
            if N.active then cancel(blocked or "INPUT COOLDOWN",true)end
            N.status=blocked or "ATTACK / CARRY COOLDOWN"
            N.lastStatus=nil
            return
        end
        if UIS:GetFocusedTextBox() then
            if N.active then cancel("CHAT PRIORITY",true)end
            return
        end
        -- InputBegan fires only once when Mouse1 is held. Never restart
        -- Rest during a held attack merely because 1.2 s has elapsed.
        local heldOK,heldAttack=pcall(function()
            return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        end)
        if heldOK and heldAttack then
            if N.active then cancel("HELD ATTACK / NO REST",true)end
            N.status="HELD ATTACK / RECOVERY PAUSED"
            N.lastStatus=nil
            return
        end
        local hpDeficit=hum.Health<hum.MaxHealth-.35
        local statusDeficit=false
        for _,key in ipairs(EFFECTS) do
            local value=char:GetAttribute(key)
            if finite(value) and value>.2 then statusDeficit=true end
        end
        -- Keep the signal primed even at full HP: no visible Rest,
        -- and new damage/status can benefit without a new activation.
        -- Do not claim a higher server-side healing rate without observations.
        if N.owned and N.owned~=char then
            cancel("ANIMAL CHANGED")
        end
        if not N.active then
            -- v1.1 order: mask before the first native Rest request.
            N.owned=char;N.active=true
            N.signalStartedAt=now
            if not beginMask(char) then
                N.owned=nil;N.active=false
                N.status="POSE MASK UNAVAILABLE / REST NOT REQUESTED"
                return
            end
            if not fire(true,char) then
                cancel("NATIVE REST REQUEST FAILED",true)
                return
            end
            -- A synchronous server pose echo can trip the guard during
            -- FireServer; never revive a cancelled signal after the call.
            if not N.active or N.owned~=char or not N.mask then return end
            N.activations+=1
            N.nextRefresh=now+N.legacyRestCadenceSeconds
            N.lastProgressAt=now
            N.lastGainValue=N.observedHPGain
            N.restRefreshAttempts=0
            N.lastStatus=nil
        end
        if N.mask then writeMask(N.mask)end
        sample(char,hum,now)
        if N.poseSafetyFailures>0 and now-N.signalStartedAt>=90 then
            N.poseSafetyFailures=0
            N.poseBackoffSeconds=0
        end
        if N.observedHPGain>N.lastGainValue+.01 then
            N.lastGainValue=N.observedHPGain
            N.lastProgressAt=now
        end
        -- Recover v1.1's five-second cadence while missing HP or affected.
        -- Never refresh while combat-blocked, unsafe, or in pose backoff.
        if now>=N.nextRefresh then
            N.nextRefresh=now+N.legacyRestCadenceSeconds
            if (hpDeficit or statusDeficit) and N.owned==char
                and N.mask and N.active then
                N.restRefreshAttempts+=1
                N.lastRefreshAt=now
                if fire(true,char) then N.restRefreshSuccess+=1 end
            else
                N.nativeRefreshRequestsSuppressed+=1
            end
        end
        if not hpDeficit and not statusDeficit then
            N.fullHealthSignalSeconds+=.2
        end
        N.mobileSignalSeconds+=.2
        N.status="MOBILE REST SIGNAL / NO VISIBLE REST / OUTSIDE COMBAT"
    end
    function N.report()
        local rate=N.eligibleHPSeconds>.1
            and N.observedHPGain/N.eligibleHPSeconds or nil
        local t={
            "FERAL NOVA PRIME v15 | Rest-Signal Recovery",
            "enabled="..tostring(N.enabled)..
                " active_native_signal="..tostring(N.active),
            "status="..N.status,
            "native_rest_true_requests="..N.nativeOn,
            "native_rest_false_requests="..N.nativeOff,
            "strict_combat_tag_blocks="..N.combatTagBlocks,
            "mobile_rest_signal_seconds_estimate="..string.format("%.1f",N.mobileSignalSeconds),
            "full_health_rest_signal_seconds_estimate="..string.format("%.1f",N.fullHealthSignalSeconds),
            "native_rest_compatibility_refresh_attempts="..N.restRefreshAttempts,
            "native_rest_compatibility_refresh_successes="..N.restRefreshSuccess,
            "native_rest_compatibility_refresh_interval_s="..N.legacyRestCadenceSeconds,
            "pre_request_pose_mask_starts="..N.preMaskStarts,
            "pre_animation_mask_checks="..N.renderMaskPasses,
            "bounded_no_heal_refresh_attempts="..N.restRefreshAttempts,
            "bounded_no_heal_refresh_successes="..N.restRefreshSuccess,
            "local_WolfRest_false_mask_writes="..N.maskWrites,
            "rest_attr_echoes="..N.maskEchoes,
            "observed_health_gain_per_second_while_masked="..
                tostring(rate),
            "valid_hp_observation_seconds="..string.format("%.2f",N.eligibleHPSeconds),
            "positive_healing_samples="..N.HPGainTicks,
            "activations="..N.activations,
            "activity_pauses="..N.pauses,
            "attack_priority_pauses="..N.combatPauses,
            "pose_mask_errors="..N.maskErrors,
            "pose_rest_true_recurrences="..N.poseRecurrences,
            "pose_safety_pauses="..N.poseSafetyPauses,
            "pose_native_signals_avoided="..N.nativeRefreshRequestsSuppressed,
            "pose_guard_config_only_until_respawn=false",
            "pose_retry_backoff_seconds="..N.poseBackoffSeconds,
            "pose_retry_remaining_seconds="..string.format("%.1f",math.max(0,N.poseRetryAt-os.clock())),
            "pose_retry_failure_streak="..N.poseSafetyFailures,
            "last_activity_block="..tostring(N.lastBlock),
            "last_error="..N.lastError,
            "NOTE=Native Rest signal stays active outside combat while moving, flying and climbing.",
            "NOTE=Provenance: v1.1 Bear observed mobile healing under five-second Rest signaling.",
            "NOTE=Pose mask attaches before the native request and ahead of WolfAnim.",
            "NOTE=While wounded/affected, refresh Rest no more often than every five seconds.",
            "NOTE=Repeated native pose echoes trigger 15/30/60/120s backoff, not permanent exclusion.",
            "NOTE=FeralCombatUntil and attack input suspend Rest; repeated pose signals also suspend it.",
            "NOTE=Local WolfRest masking can affect game animations and interactions.",
            "NOTE=Rest traffic or local attributes do not prove server-side healing."
        }
        for _,key in ipairs(EFFECTS) do
            local sec=N.effectSeconds[key]
            t[#t+1]=key.."_observed_decay_per_sec="..
                tostring(sec>.1 and N.effectClears[key]/sec or nil)
        end
        return table.concat(t,"\n")
    end
    function N.close()
        if not N.alive then return end
        N.alive=false
        N.setEnabled(false)
        for _,c in ipairs(conns) do
            pcall(function()c:Disconnect()end)
        end
        if N.conn then N.conn:Disconnect()end
    end
    N.conn=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            N.lastError=tostring(err)
            cancel("NATIVE RECOVERY ERROR",true)
        end
    end)
    return N
end
return Native
