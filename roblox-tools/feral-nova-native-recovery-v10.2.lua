-- FERAL NOVA v10.2 / manual Rest sovereignty + proximity-independent recovery
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
    -- Central action policy is authoritative for *additional* exclusions.
    -- Preserve native combat/attack fallback below even if the coordinator
    -- fails to attach. Never let a policy error turn into unsafe Rest.
    if ctx.action and type(ctx.action.allowed)=="function" then
        local ok,allowed,why=pcall(ctx.action.allowed,"recovery")
        if not ok then return "ACTION POLICY ERROR / REST OFF" end
        if allowed==false then
            if why=="COMBAT TAG" then
                return "COMBAT TAG ACTIVE / REST OFF"
            elseif why=="COMBAT CLOCK UNKNOWN" then
                return "COMBAT CLOCK UNAVAILABLE / REST OFF"
            end
            return "ACTION POLICY / "..tostring(why)
        end
    end
    if ctx.afk and ctx.afk.travelActive==true then
        return "SURVIVAL SAFE WALK / REST OFF"
    end
    if ctx.grabMini and ctx.grabMini.activeSession==true then
        return "GRAB V2 MINIGAME / REST OFF"
    end
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
        forcedOffBeforeActions=0,combatPauses=0,attackInputsObserved=0,
        attackRestReleases=0,aimedTargetRestReleases=0,heldAttackBlocks=0,
        lastHP=nil,lastStatus=nil,lastHPMax=nil,lastAt=0,
        observedHPGain=0,eligibleHPSeconds=0,HPGainTicks=0,
        effectClears={FeralInjury=0,FeralBleed=0,FeralVenomAmt=0},
        effectSeconds={FeralInjury=0,FeralBleed=0,FeralVenomAmt=0},
        lastBlock=nil,inputAt=-math.huge,
        poseRecurrences=0,poseSafetyPauses=0,poseBlockedChar=nil,
        poseRetryAt=0,poseBackoffSeconds=0,lastAnimal=nil,signalStartedAt=0,
        poseSafetyFailures=0,nativeRefreshRequestsSuppressed=0,
        combatTagBlocks=0,restRefreshAttempts=0,restRefreshSuccess=0,
        legacyRestCadenceSeconds=5,movingRestCadenceSeconds=3,
        restMinimumSpacingSeconds=2,preMaskStarts=0,renderMaskPasses=0,
        movingEligibleHPSeconds=0,movingObservedHPGain=0,movingHPGainTicks=0,
        stationaryEligibleHPSeconds=0,stationaryObservedHPGain=0,
        stationaryHPGainTicks=0,
        movingSignalSeconds=0,stationarySignalSeconds=0,
        movementTransitions=0,movingRefreshRequests=0,
        movementTriggeredRefreshRequests=0,lastMoving=nil,lastMotionSample=nil,
        lastProgressAt=0,lastGainValue=0,refreshAfterSeconds=18,
        lastRefreshAt=-math.huge,maxRefreshesPerLife=2,
        mobileSignalSeconds=0,fullHealthSignalSeconds=0,
        noNeedSignalSeconds=0,
        -- Manual Rest is game-owned: never mask its pose or send Rest(false)
        -- on behalf of a controller that no longer owns the Rest session.
        manualRest=false,manualRestChar=nil,manualRestEntries=0,
        manualRestExits=0,manualRestSeconds=0,
        manualIntentUntil=0,lastOnRequestAt=-math.huge,
        ownEchoGraceSeconds=1.0,
        nearbyTargetBlocksRemoved=true,
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
        if on then N.lastOnRequestAt=os.clock() end
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
            if char.Parent and player.Character==char
                and not (N.manualRest and N.manualRestChar==char) then
                fire(false,char)
            end
        end
        if reason then N.reason=reason;N.status=reason end
    end
    local function enterManualRest(char,reason)
        if N.manualRest and N.manualRestChar==char then return end
        N.manualRest=true
        N.manualRestChar=char
        N.manualRestEntries+=1
        -- Yield ownership BEFORE stopping the mask. A Rest(false) from us
        -- would immediately cancel the player's real Rest action.
        N.owned=nil
        N.active=false
        unmask()
        N.lastStatus=nil
        N.status=reason or "MANUAL REST / PLAYER CONTROL HAS PRIORITY"
    end
    local function syncManualRest(char,now)
        if N.manualRest then
            if N.manualRestChar~=char
                or not char or not char.Parent
                or char:GetAttribute("WolfRest")~=true then
                N.manualRest=false
                N.manualRestChar=nil
                -- Never reuse a prior manual-activation hint after the
                -- game has already exited physical Rest: a new own Rest
                -- echo could otherwise be mistaken for a second manual rest.
                N.manualIntentUntil=0
                N.manualRestExits+=1
                N.nextTick=0
                N.lastStatus=nil
            else
                N.manualRestSeconds+=.2
                N.status="MANUAL REST / AUTO SIGNAL YIELDED"
                return true
            end
        end
        if char and char.Parent
            and char:GetAttribute("WolfRest")==true then
            enterManualRest(char,"EXISTING MANUAL REST / AUTO SIGNAL YIELDED")
            return true
        end
        return false
    end
    local function writeMask(m)
        if not N.enabled or not N.alive or N.mask~=m
            or player.Character~=m.char or masking then return end
        if m.char:GetAttribute("WolfRest")==true then
            local now=os.clock()
            -- The native WolfController writes WolfRest for real player
            -- Rest actions. A later true transition, or one following a
            -- recent real Rest/UI input, must be left alone.
            if now<=N.manualIntentUntil
                or now-N.lastOnRequestAt>N.ownEchoGraceSeconds then
                enterManualRest(m.char,
                    "PLAYER REST DETECTED / POSE LEFT UNTOUCHED")
                return
            end
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
                -- Before entering backoff, clear only the echo already
                -- attributed to our OWN just-issued Rest request. Leaving
                -- this final true behind would misclassify it as manual Rest
                -- after the cooldown and stall automatic recovery forever.
                masking=true
                local cleaned=pcall(function()
                    m.char:SetAttribute("WolfRest",false)
                end)
                masking=false
                if cleaned then N.maskWrites+=1 else N.maskErrors+=1 end
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
    function N.beforeMinigame()
        local was=N.active
        delayInput("GRAB V2 MINIGAME / NATIVE REST RELEASED",1.5)
        return was
    end
    function N.beforeAfkMove()
        -- Safety: never let native Rest block an actual safe locomotion
        -- pulse needed for the survival AFK timer.
        local was=N.active
        delayInput("SURVIVAL SAFE WALK / NATIVE REST RELEASED",6)
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
            N.manualRest=false
            N.manualRestChar=nil
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
        if not N.enabled or not N.alive then return end
        local key=input.KeyCode
        local typ=input.UserInputType
        -- Capture possible Rest controls even for game-processed GUI
        -- clicks. A key alone never proves Rest; WolfRest=true must follow.
        if key==Enum.KeyCode.R or key==Enum.KeyCode.Z
            or key==Enum.KeyCode.X or typ==Enum.UserInputType.Touch
            or (processed and typ==Enum.UserInputType.MouseButton1) then
            N.manualIntentUntil=os.clock()+1.4
        end
        if N.manualRest or processed or UIS:GetFocusedTextBox() then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.MouseButton2 then
            N.attackInputsObserved+=1
            if N.active then N.attackRestReleases+=1 end
            -- The game's own bite path can refuse attacks while server Rest
            -- is active, even when WolfRest is masked false on this client.
            -- Send Rest(false) immediately on the actual attack input.
            delayInput("ATTACK INPUT / NATIVE REST RELEASED",1.3)
        elseif key==Enum.KeyCode.G then
            N.beforeCarry()
        end
    end)
    local function movingNow(char,hum)
        local root=type(char.FindFirstChild)=="function"
            and char:FindFirstChild("HumanoidRootPart") or nil
        if not root then return false end
        local speed=0
        local ok,v=pcall(function()return root.AssemblyLinearVelocity end)
        if ok and typeof(v)=="Vector3" then
            speed=Vector3.new(v.X,0,v.Z).Magnitude
        end
        local dir=hum.MoveDirection
        return speed>=2 or (typeof(dir)=="Vector3" and dir.Magnitude>.13)
    end
    local function sample(char,hum,now,moving)
        local state={hp=hum.Health,max=hum.MaxHealth,moving=moving,effects={}}
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
                -- Movement-specific measurements require the same observed
                -- state at both ends of the sample. Do not attribute growth,
                -- combat or transition intervals to mobile healing.
                if old.moving==moving then
                    if moving then
                        N.movingEligibleHPSeconds+=now-N.lastAt
                        if delta>.01 then
                            N.movingObservedHPGain+=delta
                            N.movingHPGainTicks+=1
                        end
                    else
                        N.stationaryEligibleHPSeconds+=now-N.lastAt
                        if delta>.01 then
                            N.stationaryObservedHPGain+=delta
                            N.stationaryHPGainTicks+=1
                        end
                    end
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
            N.manualRest=false
            N.manualRestChar=nil
            N.manualIntentUntil=0
            N.poseSafetyFailures=0
            N.poseRetryAt=0
            N.poseBackoffSeconds=0
        end
        -- Never overwrite the game's deliberate Rest pose; physical Rest
        -- is entirely user/game-controlled until the game clears WolfRest.
        if syncManualRest(char,now) then return end
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
        -- v7.4's combat-tag-only gate caused a bite deadlock: a native
        -- Rest(true) may suppress the first bite, so no combat tag appears.
        -- A held mouse button cannot re-arm Rest until release.
        local heldOK,held=pcall(function()
            return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        end)
        if heldOK and held then
            N.heldAttackBlocks+=1
            N.pausedUntil=math.max(N.pausedUntil,now+.8)
            if N.active then
                N.attackRestReleases+=1
                cancel("ATTACK HELD / NATIVE REST RELEASED",true)
            end
            N.status="ATTACK HELD / RECOVERY SUSPENDED FOR BITES"
            N.lastStatus=nil
            return
        end
        -- Merely standing next to a biteable animal is NOT combat:
        -- teammates and peaceful animals must not interrupt recovery.
        -- Actual mouse attacks, active combat tags and Grab V2 still
        -- preempt Rest via input handling and the shared action policy.
        local moving=movingNow(char,hum)
        if N.lastMoving~=nil and moving~=N.lastMoving then
            N.movementTransitions+=1
        end
        local enteredMotion=N.lastMoving==false and moving==true
        N.lastMoving=moving
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
            N.nextRefresh=now+
                (moving and N.movingRestCadenceSeconds
                    or N.legacyRestCadenceSeconds)
            N.lastRefreshAt=now
            N.lastProgressAt=now
            N.lastGainValue=N.observedHPGain
            N.restRefreshAttempts=0
            N.lastStatus=nil
        end
        if N.mask then writeMask(N.mask)end
        sample(char,hum,now,moving)
        if N.poseSafetyFailures>0 and now-N.signalStartedAt>=90 then
            N.poseSafetyFailures=0
            N.poseBackoffSeconds=0
        end
        if N.observedHPGain>N.lastGainValue+.01 then
            N.lastGainValue=N.observedHPGain
            N.lastProgressAt=now
        end
        -- The game can drop a resting bonus when the animal starts moving
        -- even though our client-owned Rest flag stays active. Use at most
        -- one motion-entry retry, then 3-second bounded native renewals while
        -- actually moving and wounded/affected (5 seconds when stationary).
        -- The server may still refuse moving Rest; measurements decide.
        local cadence=moving and N.movingRestCadenceSeconds
            or N.legacyRestCadenceSeconds
        if enteredMotion and (hpDeficit or statusDeficit) then
            local earliest=N.lastRefreshAt+N.restMinimumSpacingSeconds
            N.nextRefresh=math.min(N.nextRefresh,math.max(now+.2,earliest))
        end
        if now>=N.nextRefresh then
            N.nextRefresh=now+cadence
            if now-N.lastRefreshAt>=N.restMinimumSpacingSeconds
                and (hpDeficit or statusDeficit) and N.owned==char
                and N.mask and N.active then
                N.restRefreshAttempts+=1
                N.lastRefreshAt=now
                if moving then N.movingRefreshRequests+=1 end
                if enteredMotion then N.movementTriggeredRefreshRequests+=1 end
                if fire(true,char) then N.restRefreshSuccess+=1 end
            else
                N.nativeRefreshRequestsSuppressed+=1
                if now-N.lastRefreshAt<N.restMinimumSpacingSeconds then
                    N.nextRefresh=math.min(
                        N.nextRefresh,
                        N.lastRefreshAt+N.restMinimumSpacingSeconds)
                end
            end
        end
        if not hpDeficit and not statusDeficit then
            N.fullHealthSignalSeconds+=.2
        end
        N.mobileSignalSeconds+=.2
        if moving then N.movingSignalSeconds+=.2
        else N.stationarySignalSeconds+=.2 end
        N.status=moving
            and "MOBILE REST ACTIVE / MOVING / OUTSIDE COMBAT"
            or "MOBILE REST ACTIVE / STATIONARY / OUTSIDE COMBAT"
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
            "wounded_moving_refresh_interval_s="..N.movingRestCadenceSeconds,
            "minimum_rest_refresh_spacing_s="..N.restMinimumSpacingSeconds,
            "moving_rest_active_seconds="..string.format("%.2f",N.movingSignalSeconds),
            "stationary_rest_active_seconds="..string.format("%.2f",N.stationarySignalSeconds),
            "moving_hp_gain="..string.format("%.3f",N.movingObservedHPGain),
            "moving_eligible_hp_seconds="..string.format("%.3f",N.movingEligibleHPSeconds),
            "stationary_hp_gain="..string.format("%.3f",N.stationaryObservedHPGain),
            "stationary_eligible_hp_seconds="..string.format("%.3f",N.stationaryEligibleHPSeconds),
            "moving_hp_gain_ticks="..N.movingHPGainTicks,
            "stationary_hp_gain_ticks="..N.stationaryHPGainTicks,
            "motion_transitions="..N.movementTransitions,
            "rest_refreshes_while_moving="..N.movingRefreshRequests,
            "rest_refreshes_on_motion_entry="..N.movementTriggeredRefreshRequests,
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
            "afk_travel_exclusion_available=true",
            "attack_inputs_observed="..N.attackInputsObserved,
            "native_rest_releases_for_attack="..N.attackRestReleases,
            "native_rest_releases_for_aimed_bite_legacy="..N.aimedTargetRestReleases,
            "nearby_target_pauses_disabled="..tostring(N.nearbyTargetBlocksRemoved),
            "manual_rest_active="..tostring(N.manualRest),
            "manual_rest_entries="..N.manualRestEntries,
            "manual_rest_exits="..N.manualRestExits,
            "manual_rest_seconds_estimate="..string.format("%.1f",N.manualRestSeconds),
            "held_attack_guard_samples="..N.heldAttackBlocks,
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
            "NOTE=Nearby animals never preempt Rest by proximity alone; real attack input still does.",
            "NOTE=Game-owned manual Rest is never masked or cancelled by native auto recovery.",
            "NOTE=Combat tag continues to block native Rest until expiry.",
            "NOTE=Optional survival activity pauses native Rest before actual safe walking.",
            "NOTE=Grab V2 timing minigame has combat priority over native Rest.",
            "NOTE=v9 arbiter suppresses Rest for native grab/combat/carry/AFK priorities.",
            "NOTE=A policy failure fails closed rather than allowing risky Rest.",
            "NOTE=3s wounded-motion refresh is experimental and may still be rejected by the server.",
            "NOTE=Only same-max-HP consecutive observations measure mobile/stationary healing.",
            "NOTE=Repeated local pose signals trigger bounded safety backoff.",
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
