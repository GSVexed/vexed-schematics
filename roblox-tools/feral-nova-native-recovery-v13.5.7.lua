-- FERAL NOVA v13.5.7 / Eagle Talon Rest preemption and hover-lock coexistence.
-- Previously observed mobile Rest signal sometimes doubled real HP recovery.
-- Keep native Rest requests active outside combat, including movement.
-- Never treat delayed self-owned Rest echoes as real manual Rest actions.
-- The animation mask is client-local; visibility to other players is unverified.
-- Server heal and status benefits are still authoritative and not guaranteed.
local Native={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local CAS=game:GetService("ContextActionService")
local player=Players.LocalPlayer
local EFFECTS={"FeralInjury","FeralBleed","FeralVenomAmt"}
local function finite(n)
    return type(n)=="number" and n==n and n>=0 and n<1e9
end
local function nativeFeed(value)
    -- WolfController uses string "eat"/"drink"; retain boolean true for legacy.
    return value==true or value=="eat" or value=="drink"
end
Native.isNativeFeed=nativeFeed
-- A nearby animal from a different pack is not proof of combat.
-- Do not preempt Rest based on nearby actors, target markers, or pack IDs.
-- Real attack inputs, abilities, feeding and capture still get priority.
local function blockedByActivity(char,ctx)
    if not char or not char.Parent then return "NO ANIMAL" end
    if nativeFeed(char:GetAttribute("WolfFeed")) then
        return "FEEDING / DRINKING / REST OFF"
    end
    -- Let native Eagle Talon control contact and lock physics. Never rearm
    -- hub-owned Rest during actual Talon targeting or the locked response.
    if char:GetAttribute("Species")=="Eagle"
        and (char:GetAttribute("FeralTalonLock")~=nil
            or char:GetAttribute("FeralTalonView")==true
            or char:GetAttribute("FeralDiveLocal")==true) then
        return "EAGLE TALON / DIVE LOCK / REST OFF"
    end
    -- A combat *tag* is not an attack input. The recovered StatusConfig
    -- grants 4x Rest decay to negative effects independently of the game's
    -- HEALTH_NO_REGEN_IN_COMBAT rule, so combat tags are not Rest exclusions.
    -- Preserve the action policy for actual attacks, feeding and capture.
    -- Fail closed on policy errors without inventing an effect award.
    if ctx.action and type(ctx.action.allowed)=="function" then
        local ok,allowed,why=pcall(ctx.action.allowed,"recovery")
        if not ok then return "ACTION POLICY ERROR / REST OFF" end
        if allowed==false then
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
    -- Combat tags, flight, climb and held prey do not independently
    -- disable status Rest. The real bite input still yields native Rest.
    if ctx.carry and ctx.carry.classify then
        local _,_,victim=ctx.carry.classify(char)
        if victim then return "ESCAPE HAS PRIORITY" end
    end
    -- Mixpacking-safe policy: do not evaluate proximity, pack IDs,
    -- tree-climber presence or the Cobra guide to interrupt recovery.
    -- An actual mouse bite, native ability input or other active game
    -- interaction still cancels this hub's Rest and starts a cooldown.
    -- Deliberately no combat-tag gate here. A player can manually Rest
    -- while tagged, and status decay's REST_MULT is distinct from
    -- health regeneration's HEALTH_NO_REGEN_IN_COMBAT setting.
    local species=char:GetAttribute("Species")
    if type(species)=="string"
        and string.find(species,"SnappingTurtle",1,true) then
        return "TURTLE SHELL PROTECTED / NO MASK"
    end
    return nil
end
-- Death Roll owns its movement/pose until the native ability resolves.
-- This reads ONLY our current animal's replicated state.
local function saltwaterCroc(char)
    local species=char and char:GetAttribute("Species")
    return type(species)=="string"
        and species:find("SaltwaterCrocodile",1,true)~=nil
end
local function nativeDeathRollPresent(char)
    if not saltwaterCroc(char) then return false end
    local value=char:GetAttribute("FeralDeathRollPhys")
    return value~=nil and value~=false and value~=""
end
Native.saltwaterCroc=saltwaterCroc
Native.nativeDeathRollPresent=nativeDeathRollPresent
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
        legacyRestCadenceSeconds=5,movingRestCadenceSeconds=5,
        restoredMobileCadenceFromV11=true,
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
        mixpackSafeRecovery=true,passiveTargetRestBlocks=0,
        lastAttackIntentAt=-math.huge,
        firstBitePriorityBound=false,firstBitePriorityInputs=0,
        firstBiteNativeEvents=0,firstBiteDeduplicated=0,
        firstBiteRecoveryReleases=0,
        lastOwnedRestReleaseAt=-math.huge,lastOwnedRestReleaseChar=nil,
        staleRestAfterAttackIgnored=0,
        delayedAutoRestEchoesMasked=0,preAnimationMaskPasses=0,
        manualRestIntentHits=0,manualRestMotionHandoffs=0,
        inheritedRestPoseHandoffMasks=0,
        feedChar=nil,feedActive=false,feedUntil=0,
        feedStarts=0,feedFinishes=0,feedRestReleases=0,
        feedIntentPreemptions=0,feedGraceSeconds=1.25,
        -- Native game approaches food/water for up to FEED_WALK_MAX (~4 s)
        -- before WolfFeed appears. Do not re-arm Rest during that approach.
        feedApproachSeconds=4.8,feedApproachUntil=0,
        feedPriorityPreemptions=0,feedPriorityBound=false,
        feedGuiPreemptions=0,
        feedHotkeyPreemptions=0,
        feedAutoReleaseAt=-math.huge,feedEchoesSuppressed=0,
        feedEchoWindowCount=0,
        conditionPrev=nil,conditionRates={auto={},manual={},baseline={},
            auto_combat={},manual_combat={},baseline_combat={}},
        conditionMotionRates={},conditionMotionTransitionIntervalsExcluded=0,
        combatRestActiveSeconds=0,combatStatusSamples=0,
        deathRollInputs=0,deathRollRestReleases=0,
        deathRollStateObservations=0,deathRollSuppressedTicks=0,
        deathRollEchoesSuppressed=0,deathRollEchoFailures=0,
        deathRollInputUntil=0,deathRollStateHoldUntil=0,
        deathRollEchoUntil=0,deathRollEchoCount=0,
        deathRollChar=nil,deathRollStateSince=0,
        cobraAbilityInputs=0,cobraAbilityPreempts=0,cobraEarlyBitePauses=0,
        cobraPreAimActive=false,cobraRestLockSeconds=.7,
        cobraLastAbilityInputAt=-math.huge,cobraLastBiteInputAt=-math.huge,
        cobraCASBound=false,
        treeFightRestPauses=0,treeFightRestActive=false,
        treeFightRestPreempts=0,
        generalBiteRestHandoffs=0,generalBiteRestActive=false,
        generalBiteRestPreempts=0,generalNearContactChecks=0,
        generalAttackHoldSeconds=2.2,
        eagleTalonPriorityBound=false,eagleTalonInputs=0,
        eagleTalonNativePressSignals=0,eagleTalonRestReleases=0,
        eagleTalonLastInputAt=-math.huge,
    }
    N.blockedByActivity=blockedByActivity
    N.nativeDeathRollPresent=nativeDeathRollPresent
    local conns={}
    local feedConn=nil
    local feedPoseConn=nil
    local biteAtConn=nil
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
        if m.preAnimConn then pcall(function()m.preAnimConn:Disconnect()end)end
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
                N.lastOwnedRestReleaseAt=os.clock()
                N.lastOwnedRestReleaseChar=char
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
    local function movingNow(char,hum)
        -- Input intent is sufficient even when streamed root is temporarily
        -- missing. Physical sliding/translation also counts as motion.
        local dir=hum and hum.MoveDirection
        if typeof(dir)=="Vector3" and dir.Magnitude>.13 then return true end
        local root=char and type(char.FindFirstChild)=="function"
            and char:FindFirstChild("HumanoidRootPart") or nil
        if not root then return false end
        local ok,v=pcall(function()return root.AssemblyLinearVelocity end)
        if ok and typeof(v)=="Vector3" then
            return Vector3.new(v.X,0,v.Z).Magnitude>=2
        end
        return false
    end
    local function syncManualRest(char,now)
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local moving=char and hum and movingNow(char,hum) or false
        if N.manualRest then
            if N.manualRestChar~=char
                or not char or not char.Parent
                or char:GetAttribute("WolfRest")~=true
                or moving then
                if moving and N.manualRestChar==char then
                    N.manualRestMotionHandoffs+=1
                end
                -- On real movement, the user's stationary Rest is yielded
                -- to the SAME automatic recovery controller; no Rest(false)
                -- remote is sent and no movement recovery gate is introduced.
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
            -- A moving visible Rest pose is never a manual Rest to preserve.
            -- Keep auto recovery owned and let its mask remove the pose.
            if moving then return false end
            -- If we currently own automatic Rest, a true attribute can be
            -- a delayed native response, NOT proof of player Rest.
            -- Only a real Rest key / game Rest button may transfer ownership
            -- while our automatic session is running.
            if N.active and N.owned==char then
                if now<=N.manualIntentUntil then
                    N.manualRestIntentHits+=1
                    enterManualRest(char,"PLAYER REST INPUT / AUTO YIELDED")
                    return true
                end
                return false
            end
            -- An earlier hub-owned Rest(true) can still echo briefly
            -- after we issue Rest(false) on the first bite. That is
            -- not manual Rest unless the player actually pressed Rest.
            if N.lastOwnedRestReleaseChar==char
                and now-N.lastOwnedRestReleaseAt<=2.6
                and now>N.manualIntentUntil then
                N.staleRestAfterAttackIgnored+=1
                return false
            end
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
            -- Delayed own Rest(true) echoes may arrive long after the last
            -- request. Time elapsed is NOT evidence of physical user Rest:
            -- that old rule yielded ownership and exposed a moving Rest pose.
            -- A manual Rest key/visible game Rest button is stronger evidence.
            local hum=m.char:FindFirstChildOfClass("Humanoid")
            if now<=N.manualIntentUntil
                and not (hum and movingNow(m.char,hum)) then
                N.manualRestIntentHits+=1
                enterManualRest(m.char,
                    "PLAYER REST INPUT DETECTED / POSE LEFT UNTOUCHED")
                return
            end
            if now-N.lastOnRequestAt>N.ownEchoGraceSeconds then
                N.delayedAutoRestEchoesMasked+=1
            end
            if now-(m.echoWindowAt or 0)>2 then
                m.echoWindowAt=now
                m.trueEchoes=0
            end
            -- The first mask operation may clear the visible pose
            -- inherited from an already-resting character during manual
            -- to automatic handoff. It is NOT an additional self-owned
            -- server Rest echo and must not trip recurrence backoff.
            if m.initialInheritedRest then
                m.initialInheritedRest=false
                N.inheritedRestPoseHandoffMasks+=1
            else
                m.trueEchoes+=1
                N.poseRecurrences+=1
            end
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
        local m={char=char,echoWindowAt=os.clock(),trueEchoes=0,
            initialInheritedRest=char:GetAttribute("WolfRest")==true}
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
        -- Run this attribute guard before both render animation and the
        -- regular pre-animation evaluation, where supported. This never
        -- overwrites a confirmed manual Rest session.
        pcall(function()
            if RunService.PreAnimation then
                m.preAnimConn=RunService.PreAnimation:Connect(function()
                    if N.mask==m then
                        N.preAnimationMaskPasses+=1
                        writeMask(m)
                    end
                end)
            end
        end)
        local bound=pcall(function()
            RunService:BindToRenderStep(renderName,90,function()
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
    -- This path is called by high-priority ContextActionService BEFORE
    -- native bite controls when possible. It never sinks the input,
    -- changes damage, or requests another attack. It only releases
    -- a hub-owned Rest and holds recovery briefly during attack chains.
    function N.beforeBiteInput(reason,fromNativeBite)
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not (N.alive and N.enabled and char and char.Parent
            and hum and hum.Health>0 and not N.manualRest
            and player:GetAttribute("FeralMenuOpen")~=true) then return false end
        local now=os.clock()
        if now-N.lastAttackIntentAt<.075 then
            N.firstBiteDeduplicated+=1
            return false
        end
        N.attackInputsObserved+=1
        N.generalBiteRestHandoffs+=1
        N.lastAttackIntentAt=now
        if fromNativeBite then N.firstBiteNativeEvents+=1 end
        if N.active then
            N.attackRestReleases+=1
            N.generalBiteRestPreempts+=1
            N.firstBiteRecoveryReleases+=1
        end
        local cobra=char:GetAttribute("Species")=="KingCobra"
        if cobra then N.cobraLastBiteInputAt=now end
        delayInput(reason or "FIRST BITE / OWNED REST RELEASED",
            cobra and 2.4 or N.generalAttackHoldSeconds)
        return true
    end
    -- King Cobra needs a pre-ability Rest release. The game's normal
    -- ability uses FeralKingsPress and is not one of the mouse inputs handled
    -- by the older recovery supervisor. We do not fire the ability ourselves.
    function N.beforeKingsStrike(reason)
        local char=player.Character
        if not (N.alive and N.enabled and char
            and char:GetAttribute("Species")=="KingCobra"
            and not N.manualRest) then return false end
        local now=os.clock()
        if now-N.cobraLastAbilityInputAt>.15 then
            N.cobraAbilityInputs+=1
            N.cobraLastAbilityInputAt=now
        end
        if N.active then N.cobraAbilityPreempts+=1 end
        -- Cover native stance (2.763s), rise (2.07s) and animation settle.
        delayInput(reason or "KING COBRA KINGS STRIKE / REST OFF",6.0)
        return true
    end
    -- Eagle Talon was previously left armed with moving auto-Rest.
    -- Unlike ordinary flight, Talon requires exclusive attack/lock physics.
    -- Never cancel a genuine manually initiated Rest.
    function N.beforeEagleTalon(reason,fromNative)
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not (N.alive and N.enabled and char and char.Parent
            and char:GetAttribute("Species")=="Eagle"
            and hum and hum.Health>0 and not N.manualRest
            and player:GetAttribute("FeralMenuOpen")~=true) then
            return false
        end
        local now=os.clock()
        if now-N.eagleTalonLastInputAt<.12 then return false end
        N.eagleTalonLastInputAt=now
        N.eagleTalonInputs+=1
        if fromNative then N.eagleTalonNativePressSignals+=1 end
        if N.active then N.eagleTalonRestReleases+=1 end
        delayInput(reason or "EAGLE TALON / AUTO REST RELEASED",5.0)
        return true
    end
    -- Native game feeding owns its interaction until the WolfFeed state
    -- ends. Rest(false) is sent only for a Rest session owned by this hub;
    -- deliberate manual Rest is never cancelled on the user's behalf.
    function N.beforeFeed(reason)
        if not N.alive or not N.enabled then return false end
        local char=player.Character
        if not char then return false end
        local now=os.clock()
        N.feedChar=char
        N.feedUntil=math.max(N.feedUntil,now+N.feedGraceSeconds)
        N.feedApproachUntil=math.max(N.feedApproachUntil,now+N.feedApproachSeconds)
        N.feedIntentPreemptions+=1
        if ctx.action and type(ctx.action.reserve)=="function" then
            pcall(ctx.action.reserve,"feed",N.feedGraceSeconds)
        end
        if N.active then
            N.feedRestReleases+=1
            N.feedAutoReleaseAt=os.clock()
            N.feedEchoWindowCount=0
        end
        delayInput(reason or "NATIVE FEED / AUTO REST RELEASED",N.feedGraceSeconds)
        return true
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
    -- F is the native crocodile ability key. Yield the hub-owned Rest
    -- signal before the game starts Death Roll; never stop game animations
    -- or write server-owned ability/cooldown/physics attributes.
    function N.beforeDeathRoll()
        if not N.alive or not N.enabled then return false end
        local char=player.Character
        if not saltwaterCroc(char) then return false end
        local now=os.clock()
        N.deathRollInputs+=1
        N.deathRollChar=char
        N.deathRollInputUntil=math.max(N.deathRollInputUntil,now+2.8)
        N.deathRollEchoUntil=math.max(N.deathRollEchoUntil,now+3.5)
        N.deathRollEchoCount=0
        if N.active then N.deathRollRestReleases+=1 end
        -- The ordinary Rest owner emits its matching Rest(false).
        -- Input grace handles FX/replication delays before a physics
        -- attribute is visible; later observations extend the hold.
        delayInput("CROCODILE DEATH ROLL / REST RELEASED",2.8)
        return true
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
            N.feedChar=nil
            N.feedActive=false
            N.feedUntil=0
            N.feedApproachUntil=0
            N.feedAutoReleaseAt=-math.huge
            N.feedEchoWindowCount=0
            N.conditionPrev=nil
            N.deathRollChar=nil
            N.deathRollInputUntil=0
            N.deathRollStateHoldUntil=0
            N.deathRollEchoUntil=0
            N.deathRollEchoCount=0
            N.deathRollStateSince=0
            N.cobraPreAimActive=false
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
            N.status="ARMED / REST STATUS SIGNAL WORKS WITH COMBAT TAGS"
            N.nextTick=0
        end
        return N.enabled
    end
    local function gameRestGuiPressed(input)
        -- Avoid confusing a click on this hub (or an unrelated Roblox
        -- interface) with a manual Rest command. Only a visible in-game
        -- Rest-labelled control may mark processed mouse/touch input.
        local pg=nil
        pcall(function()pg=player:FindFirstChildOfClass("PlayerGui")end)
        if not pg then return false end
        local point=nil
        local okPoint=pcall(function()
            point=input.Position
            if input.UserInputType~=Enum.UserInputType.Touch then
                point=UIS:GetMouseLocation()
            end
        end)
        if not okPoint or not point then return false end
        local ok,objects=pcall(function()
            return pg:GetGuiObjectsAtPosition(point.X,point.Y)
        end)
        if not ok or type(objects)~="table" then return false end
        for _,object in ipairs(objects) do
            if ctx.ui and object:IsDescendantOf(ctx.ui) then
                return false
            end
        end
        for _,object in ipairs(objects) do
            local name=string.lower(tostring(object.Name or ""))
            local label=""
            pcall(function()label=string.lower(tostring(object.Text or ""))end)
            if name:find("rest",1,true) or label:find("rest",1,true) then
                return true
            end
        end
        return false
    end
    -- ContextActionService normally invokes WolfFeed(E / ButtonB) before
    -- UserInputService.InputBegan. Yield our Rest *first*, then PASS the same
    -- input through to the original WolfController (never consume or duplicate).
    local feedPriorityName="FERAL_HUB_NATIVE_FEED_YIELD_V133"
    local function preemptNativeFeed(actionName,state,input)
        if state==Enum.UserInputState.Begin and N.enabled and N.alive
            and not N.manualRest and not UIS:GetFocusedTextBox()
            and player:GetAttribute("FeralMenuOpen")~=true then
            local char=player.Character
            if char and (nativeFeed(char:GetAttribute("FeedCan"))
                or nativeFeed(char:GetAttribute("WolfFeed"))) then
                N.feedPriorityPreemptions+=1
                N.beforeFeed("NATIVE FEED PRE-INPUT / REST YIELDED")
            end
        end
        return Enum.ContextActionResult.Pass
    end
    pcall(function()
        CAS:BindActionAtPriority(feedPriorityName,preemptNativeFeed,
            false,3000,Enum.KeyCode.E,Enum.KeyCode.ButtonB)
        N.feedPriorityBound=true
    end)
    local cobraPriorityName="FERAL_HUB_COBRA_KINGS_YIELD_V1346"
    pcall(function()
        CAS:BindActionAtPriority(cobraPriorityName,function(_,state)
            if state==Enum.UserInputState.Begin and N.alive and N.enabled
                and not UIS:GetFocusedTextBox()
                and player:GetAttribute("FeralMenuOpen")~=true then
                N.beforeKingsStrike("COBRA F ABILITY PRE-INPUT / REST RELEASED")
            end
            return Enum.ContextActionResult.Pass
        end,false,3000,Enum.KeyCode.F)
        N.cobraCASBound=true
    end)
    -- Eagle Talon is F / FeralTalonPress. Preserve the user's native
    -- input while releasing our own Rest before native aim and contact.
    local eaglePriorityName="FERAL_HUB_EAGLE_TALON_YIELD_V1357"
    pcall(function()
        CAS:BindActionAtPriority(eaglePriorityName,function(_,state)
            if state==Enum.UserInputState.Begin and N.alive and N.enabled
                and not UIS:GetFocusedTextBox()
                and player:GetAttribute("FeralMenuOpen")~=true then
                N.beforeEagleTalon("EAGLE F TALON PRE-INPUT / REST RELEASED",false)
            end
            return Enum.ContextActionResult.Pass
        end,false,3600,Enum.KeyCode.F)
        N.eagleTalonPriorityBound=true
    end)
    -- Prioritize actual bite inputs above the game's regular controls.
    -- Pass lets the native game still perform its own attack normally.
    -- Guard real Rest GUI clicks and text boxes so mixpacking recovery
    -- is not interrupted by ordinary menu interactions.
    local bitePriorityName="FERAL_HUB_FIRST_BITE_YIELD_V1353"
    pcall(function()
        CAS:UnbindAction(bitePriorityName)
        CAS:BindActionAtPriority(bitePriorityName,function(_,state,input)
            if state==Enum.UserInputState.Begin and N.alive and N.enabled
                and not UIS:GetFocusedTextBox()
                and player:GetAttribute("FeralMenuOpen")~=true
                and not N.manualRest and not gameRestGuiPressed(input) then
                local char=player.Character
                if char and char:GetAttribute("IsWolf")==true
                    and not nativeFeed(char:GetAttribute("FeedCan")) then
                    N.firstBitePriorityInputs+=1
                    N.beforeBiteInput("EARLIEST BITE INPUT / AUTO REST OFF")
                end
            end
            return Enum.ContextActionResult.Pass
        end,false,3500,Enum.UserInputType.MouseButton1,
            Enum.UserInputType.MouseButton2)
        N.firstBitePriorityBound=true
    end)
    conns[#conns+1]=UIS.InputBegan:Connect(function(input,processed)
        if not N.enabled or not N.alive then return end
        local key=input.KeyCode
        local typ=input.UserInputType
        -- Only Rest-associated keyboard or real game Rest GUI controls
        -- create a manual-intent hint. WolfRest=true is still required.
        if key==Enum.KeyCode.R or key==Enum.KeyCode.Z
            or key==Enum.KeyCode.X
            or ((typ==Enum.UserInputType.Touch
                or (processed and typ==Enum.UserInputType.MouseButton1))
                and gameRestGuiPressed(input)) then
            N.manualIntentUntil=os.clock()+1.4
        end
        -- The recovered FERAL WolfController binds "WolfFeed" to E via
        -- ContextActionService, which may mark the input as processed.
        -- Give a real E feed request priority BEFORE the processed flag
        -- is evaluated. This does not create food, water or server credit.
        -- Manual Rest remains player-owned and is never cancelled here.
        if key==Enum.KeyCode.E
            and not N.manualRest and not UIS:GetFocusedTextBox()
            and player:GetAttribute("FeralMenuOpen")~=true then
            local feedChar=player.Character
            -- A stray E press with no food or water prompt should not
            -- interrupt auto recovery or create misleading feed evidence.
            if feedChar and (nativeFeed(feedChar:GetAttribute("FeedCan"))
                or nativeFeed(feedChar:GetAttribute("WolfFeed"))) then
                N.feedHotkeyPreemptions+=1
                N.beforeFeed("NATIVE E FEED INPUT / AUTO REST RELEASED")
                return
            end
        end
        -- Ability input may already be marked processed by the native
        -- ContextActionService binding. Handle it before the processed gate.
        if key==Enum.KeyCode.F
            and saltwaterCroc(player.Character)
            and not UIS:GetFocusedTextBox()
            and player:GetAttribute("FeralMenuOpen")~=true then
            N.beforeDeathRoll()
            return
        end
        if key==Enum.KeyCode.F
            and player.Character
            and player.Character:GetAttribute("Species")=="KingCobra"
            and not UIS:GetFocusedTextBox()
            and player:GetAttribute("FeralMenuOpen")~=true then
            N.beforeKingsStrike("COBRA F INPUT / REST RELEASED")
        end
        -- The FeralHUD touch/mouse feed button can be processed by GuiService.
        -- Its Activated event sets FeralFeedTap; preempt on InputBegan so
        -- the server sees Rest(false) before that native Feed request.
        if not N.manualRest and not UIS:GetFocusedTextBox()
            and (typ==Enum.UserInputType.Touch
                or typ==Enum.UserInputType.MouseButton1) then
            local char=player.Character
            if char and nativeFeed(char:GetAttribute("FeedCan")) then
                local point=input.Position
                local ok,objects=pcall(function()
                    return player:FindFirstChildOfClass("PlayerGui")
                        :GetGuiObjectsAtPosition(point.X,point.Y)
                end)
                if ok and type(objects)=="table" then
                    for _,obj in ipairs(objects) do
                        local gui=obj:FindFirstAncestorOfClass("ScreenGui")
                        if gui and gui.Name=="FeralHUD"
                            and obj:IsA("GuiButton") then
                            N.feedGuiPreemptions+=1
                            N.beforeFeed("HUD FEED INPUT / REST YIELDED")
                            break
                        end
                    end
                end
            end
        end
        if N.manualRest or processed or UIS:GetFocusedTextBox() then return end
        -- FeedCan is the game's native interaction-eligibility hint. On
        -- a real primary click, yield hub-owned Rest *before* a feed action
        -- is confirmed; this protects the first food/water interaction.
        -- This is not a claim that FeedCan proves a server resource grant.
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            local char=player.Character
            if char and nativeFeed(char:GetAttribute("FeedCan")) then
                N.beforeFeed("ELIGIBLE FEED CLICK / AUTO REST RELEASED")
                return
            end
        end
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.MouseButton2 then
            -- Fallback if the high-priority CAS binding is unavailable;
            -- the .075s dedupe prevents double Rest(false) requests.
            N.beforeBiteInput("MOUSE BITE INPUT / AUTO REST OFF",false)
        elseif key==Enum.KeyCode.G then
            N.beforeCarry()
        end
    end)
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
                -- Fully cleared effects are commonly represented by
                -- removal of the attribute, not a final numeric zero.
                if finite(a) and a>.2 and (finite(b) or b==nil) then
                    local after=finite(b) and b or 0
                    if after<=a then
                        N.effectSeconds[key]+=now-N.lastAt
                        N.effectClears[key]+=a-after
                    end
                end
            end
        end
        N.lastStatus=state;N.lastAt=now
    end
    local function sampleConditions(char,now)
        local old=N.conditionPrev
        local mode=N.manualRest and "manual"
            or N.active and "auto" or "baseline"
        local attr=player:GetAttribute("FeralCombatUntil")
        local own=char:GetAttribute("FeralCombatUntil")
        if finite(own) and (not finite(attr) or own>attr) then attr=own end
        local combat=false
        if finite(attr) then
            local ok,serverNow=pcall(function()return workspace:GetServerTimeNow()end)
            combat=not ok or not finite(serverNow) or serverNow<attr
        end
        if combat then
            mode=mode.."_combat"
        end
        if N.feedChar==char
            and (nativeFeed(char:GetAttribute("WolfFeed")) or now<N.feedUntil) then
            -- Feeding must not contaminate recovery-rate comparisons.
            mode="feeding"
        elseif mode=="baseline" and char:GetAttribute("WolfRest")==true then
            mode="unknown_rest"
        end
        local hum=char:FindFirstChildOfClass("Humanoid")
        local moving=hum and movingNow(char,hum) or false
        local current={char=char,at=now,mode=mode,moving=moving,values={}}
        for _,key in ipairs(EFFECTS) do
            current.values[key]=char:GetAttribute(key)
        end
        if old and old.char==char and old.mode==mode
            and N.conditionRates[mode] and now-old.at>=.1
            and now-old.at<=1.5 then
            local dt=now-old.at
            local comparableMotion=old.moving==moving
            if not comparableMotion then
                N.conditionMotionTransitionIntervalsExcluded+=1
            end
            local motionKey=mode.."_"..(moving and "moving" or "stationary")
            local motionBucket=N.conditionMotionRates[motionKey]
            if not motionBucket then
                motionBucket={}
                N.conditionMotionRates[motionKey]=motionBucket
            end
            for _,key in ipairs(EFFECTS) do
                local before=old.values[key]
                local after=current.values[key]
                -- A disappearing effect attribute is treated as cleared,
                -- never as a new value or as client-side healing.
                if finite(before) and before>.2
                    and (finite(after) or after==nil) then
                    local endValue=finite(after) and after or 0
                    local row=N.conditionRates[mode][key]
                    if not row then
                        row={seconds=0,cleared=0,intervals=0}
                        N.conditionRates[mode][key]=row
                    end
                    row.seconds+=dt
                    row.intervals+=1
                    if combat then N.combatStatusSamples+=1 end
                    if endValue<before then
                        row.cleared+=before-endValue
                    end
                    -- Real replicated status values only. Do not silently
                    -- count stationary-to-moving boundary intervals as
                    -- proof that the moving 4x Rest effect persisted.
                    if comparableMotion then
                        local motionRow=motionBucket[key]
                        if not motionRow then
                            motionRow={seconds=0,cleared=0,intervals=0}
                            motionBucket[key]=motionRow
                        end
                        motionRow.seconds+=dt
                        motionRow.intervals+=1
                        if endValue<before then
                            motionRow.cleared+=before-endValue
                        end
                    end
                end
            end
        end
        N.conditionPrev=current
    end
    local function clearOwnedFeedEcho(char,now)
        if N.feedChar~=char or N.manualRest
            or now<=N.manualIntentUntil
            or now-N.feedAutoReleaseAt>4
            or N.feedEchoWindowCount>=3
            or char:GetAttribute("WolfRest")~=true then return end
        local ok=pcall(function()char:SetAttribute("WolfRest",false)end)
        if ok then
            N.feedEchoesSuppressed+=1
            N.feedEchoWindowCount+=1
        end
    end
    -- Only suppress delayed echoes attributable to this hub's own
    -- just-released Rest request, never a real player-initiated Rest.
    -- Limited to three local pose echoes in the short ability window.
    local function clearOwnedDeathRollEcho(char,now)
        if N.deathRollChar~=char or N.manualRest
            or now>N.deathRollEchoUntil or now<=N.manualIntentUntil
            or N.deathRollEchoCount>=3
            or char:GetAttribute("WolfRest")~=true then return end
        local ok=pcall(function()char:SetAttribute("WolfRest",false)end)
        if ok then
            N.deathRollEchoCount+=1
            N.deathRollEchoesSuppressed+=1
        else
            N.deathRollEchoFailures+=1
        end
    end
    local function feedGuard(char,now)
        local nativeFeeding=nativeFeed(char:GetAttribute("WolfFeed"))
        if nativeFeeding then
            -- Once the native animation begins, the long approach hold is
            -- unnecessary; keep only the normal short post-feed settle.
            N.feedApproachUntil=0
            if N.feedChar~=char or not N.feedActive then
                N.feedStarts+=1
            end
            N.feedChar=char
            N.feedActive=true
            N.feedUntil=math.max(N.feedUntil,now+N.feedGraceSeconds)
        elseif N.feedActive then
            N.feedActive=false
            N.feedApproachUntil=0
            N.feedFinishes+=1
        end
        -- A delayed acknowledgment of our OWN released Rest(true) can
        -- arrive after feeding starts. It is not a player-owned Rest action.
        -- Clear its local pose only in this bounded own-release window.
        clearOwnedFeedEcho(char,now)
        if N.feedChar==char and (nativeFeeding or now<N.feedUntil
            or now<N.feedApproachUntil) then
            if N.active then
                N.feedRestReleases+=1
                N.feedAutoReleaseAt=now
                N.feedEchoWindowCount=0
                cancel("FEEDING / DRINKING / REST RELEASED",true)
            end
            N.status=nativeFeeding and "FEEDING / DRINKING / REST PAUSED"
                or "FEED SETTLE / RECOVERY RESUMES AUTOMATICALLY"
            N.lastStatus=nil
            return true
        end
        return false
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
            N.conditionPrev=nil
            N.feedChar=nil
            N.feedUntil=0
            N.feedApproachUntil=0
            N.feedActive=false
            N.feedAutoReleaseAt=-math.huge
            N.feedEchoWindowCount=0
            N.deathRollChar=nil
            N.deathRollInputUntil=0
            N.deathRollStateHoldUntil=0
            N.deathRollEchoUntil=0
            N.deathRollEchoCount=0
            N.deathRollStateSince=0
        end
        sampleConditions(char,now)
        -- Feeding takes precedence even over an inherited/manual Rest flag.
        -- Never re-arm a native Rest signal during a feed animation/settle.
        if feedGuard(char,now) then return end
        -- Never overwrite the game's deliberate Rest pose; physical Rest
        -- is entirely user/game-controlled until the game clears WolfRest.
        -- A late automatic Rest echo can reassert WolfRest while the game
        -- is leaving Death Roll. Clear just our owned echo before the normal
        -- manual-Rest ownership test; never cancel genuine manual Rest.
        clearOwnedDeathRollEcho(char,now)
        if syncManualRest(char,now) then return end
        if saltwaterCroc(char) then
            local rolling=nativeDeathRollPresent(char)
            if rolling then
                N.deathRollStateObservations+=1
                if N.deathRollStateSince==0 then
                    N.deathRollStateSince=now
                end
                N.deathRollStateHoldUntil=math.max(
                    N.deathRollStateHoldUntil,now+1.0)
            else
                N.deathRollStateSince=0
            end
            if rolling or now<N.deathRollInputUntil
                or now<N.deathRollStateHoldUntil then
                N.deathRollSuppressedTicks+=1
                if N.active then
                    N.deathRollRestReleases+=1
                    N.deathRollChar=char
                    N.deathRollEchoUntil=math.max(N.deathRollEchoUntil,now+2)
                    N.deathRollEchoCount=0
                    cancel("CROCODILE DEATH ROLL / REST RELEASED",true)
                end
                N.status=rolling
                    and "CROCODILE ROLL PHYSICS ACTIVE / REST OFF"
                    or "CROCODILE ROLL SETTLING / REST OFF"
                N.lastStatus=nil
                return
            end
        end
        if now<N.poseRetryAt then
            N.status="POSE SAFETY / BACKOFF (NO VISIBLE REST)"
            if N.active then cancel(N.status,true)end
            N.lastStatus=nil
            return
        end
        local blocked=blockedByActivity(char,ctx)
        -- No proximity scan here; only actual input can set the
        -- ordinary bite pause. Preserve fields for DATA compatibility.
        N.cobraPreAimActive=false
        N.treeFightRestActive=false
        N.generalBiteRestActive=now<N.pausedUntil
            and now-N.lastAttackIntentAt<=N.generalAttackHoldSeconds+.25
        N.lastBlock=blocked
        if blocked or now<N.pausedUntil then
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
        -- Actual mouse attacks and Grab V2 still preempt Rest, but a
        -- combat tag by itself is now allowed to retain the Rest signal.
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
        local combatAt=player:GetAttribute("FeralCombatUntil")
        local animalCombatAt=char:GetAttribute("FeralCombatUntil")
        if finite(animalCombatAt)
            and (not finite(combatAt) or animalCombatAt>combatAt) then
            combatAt=animalCombatAt
        end
        local inCombat=false
        if finite(combatAt) then
            local clockOK,serverNow=pcall(function()
                return workspace:GetServerTimeNow()
            end)
            inCombat=not clockOK or not finite(serverNow) or combatAt>serverNow
        end
        if inCombat then N.combatRestActiveSeconds+=.2 end
        N.status="NATIVE REST SIGNAL / "..
            (moving and "MOVING" or "STATIONARY")..
            (inCombat and " / COMBAT TAG ALLOWED" or " / PEACE")
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
            "legacy_strict_combat_tag_blocks="..N.combatTagBlocks,
            "native_rest_allowed_during_combat_tag=true",
            "rest_signal_seconds_during_combat="..
                string.format("%.2f",N.combatRestActiveSeconds),
            "combat_condition_samples="..N.combatStatusSamples,
            "mobile_rest_signal_seconds_estimate="..string.format("%.1f",N.mobileSignalSeconds),
            "full_health_rest_signal_seconds_estimate="..string.format("%.1f",N.fullHealthSignalSeconds),
            "native_rest_compatibility_refresh_attempts="..N.restRefreshAttempts,
            "native_rest_compatibility_refresh_successes="..N.restRefreshSuccess,
            "native_rest_compatibility_refresh_interval_s="..N.legacyRestCadenceSeconds,
            "wounded_moving_refresh_interval_s="..N.movingRestCadenceSeconds,
            "restored_earlier_mobile_refresh_cadence="..tostring(N.restoredMobileCadenceFromV11),
            "status_motion_boundary_intervals_excluded="..N.conditionMotionTransitionIntervalsExcluded,
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
            "pre_animation_event_mask_checks="..N.preAnimationMaskPasses,
            "late_auto_rest_echoes_masked="..N.delayedAutoRestEchoesMasked,
            "verified_manual_rest_input_handoffs="..N.manualRestIntentHits,
            "manual_to_auto_handoffs_on_movement="..N.manualRestMotionHandoffs,
            "inherited_rest_poses_masked_on_handoff="..N.inheritedRestPoseHandoffMasks,
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
            "first_bite_priority_bound="..tostring(N.firstBitePriorityBound),
            "first_bite_priority_inputs="..N.firstBitePriorityInputs,
            "first_bite_native_event_fallbacks="..N.firstBiteNativeEvents,
            "first_bite_input_deduplications="..N.firstBiteDeduplicated,
            "first_bite_auto_rest_releases="..N.firstBiteRecoveryReleases,
            "eagle_talon_priority_bound="..tostring(N.eagleTalonPriorityBound),
            "eagle_talon_input_preemptions="..N.eagleTalonInputs,
            "eagle_talon_native_press_fallbacks="..N.eagleTalonNativePressSignals,
            "eagle_talon_rest_releases="..N.eagleTalonRestReleases,
            "stale_rest_echoes_not_mistaken_for_manual="..N.staleRestAfterAttackIgnored,
            "cobra_base_post_rest_bite_lock_seconds="..N.cobraRestLockSeconds,
            "cobra_early_pre_bite_rest_pauses="..N.cobraEarlyBitePauses,
            "cobra_pre_bite_guard_active="..tostring(N.cobraPreAimActive),
            "cobra_special_ability_inputs="..N.cobraAbilityInputs,
            "cobra_special_ability_rest_preemptions="..N.cobraAbilityPreempts,
            "cobra_cas_prioritized="..tostring(N.cobraCASBound),
            "tree_combat_auto_rest_pauses="..N.treeFightRestPauses,
            "tree_combat_rest_preemptions="..N.treeFightRestPreempts,
            "tree_combat_rest_guard_active="..tostring(N.treeFightRestActive),
            "all_species_pre_bite_handoffs="..N.generalBiteRestHandoffs,
            "all_species_pre_bite_rest_preemptions="..N.generalBiteRestPreempts,
            "all_species_pre_bite_guard_active="..tostring(N.generalBiteRestActive),
            "all_species_pre_bite_scan_cycles="..N.generalNearContactChecks,
            "mixpack_safe_rest=true",
            "proximity_based_rest_pauses=0",
            "passive_target_rest_preemption_disabled=true",
            "last_genuine_attack_intent_age_seconds="..
                tostring(N.lastAttackIntentAt>0
                    and os.clock()-N.lastAttackIntentAt or "NONE"),
            "post_attack_rest_pause_seconds="..N.generalAttackHoldSeconds,
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
            "feed_interactions_seen="..N.feedStarts,
            "feed_interactions_completed="..N.feedFinishes,
            "rest_releases_for_feed="..N.feedRestReleases,
            "feed_intent_preemptions="..N.feedIntentPreemptions,
            "native_E_hotkey_feed_preemptions="..N.feedHotkeyPreemptions,
            "native_E_priority_guard_bound="..tostring(N.feedPriorityBound),
            "native_E_priority_preemptions="..N.feedPriorityPreemptions,
            "native_HUD_feed_preemptions="..N.feedGuiPreemptions,
            "native_feed_approach_hold_seconds="..N.feedApproachSeconds,
            "native_feed_approach_remaining="..string.format("%.2f",
                math.max(0,N.feedApproachUntil-os.clock())),
            "feed_guard_active="..tostring(N.feedActive
                or os.clock()<N.feedUntil or os.clock()<N.feedApproachUntil),
            "late_owned_rest_poses_suppressed_during_feed="..N.feedEchoesSuppressed,
            "death_roll_input_events="..N.deathRollInputs,
            "death_roll_owned_rest_releases="..N.deathRollRestReleases,
            "death_roll_native_state_samples="..N.deathRollStateObservations,
            "death_roll_rest_suppressed_ticks="..N.deathRollSuppressedTicks,
            "death_roll_owned_pose_echoes_suppressed="..N.deathRollEchoesSuppressed,
            "death_roll_owned_pose_echo_failures="..N.deathRollEchoFailures,
            "death_roll_active_state_seconds="..string.format("%.2f",
                N.deathRollStateSince>0 and os.clock()-N.deathRollStateSince or 0),
            "death_roll_possible_stale_state="..tostring(
                N.deathRollStateSince>0 and os.clock()-N.deathRollStateSince>15),
            "last_error="..N.lastError,
            "NOTE=Native Rest requests are allowed with combat tags, including while moving.",
            "NOTE=Provenance: v1.1 Bear observed mobile healing under five-second Rest signaling.",
            "NOTE=Pose mask attaches before the native request and ahead of WolfAnim.",
            "NOTE=While wounded/affected, refresh Rest no more often than every five seconds.",
            "NOTE=Repeated native pose echoes trigger 15/30/60/120s backoff, not permanent exclusion.",
            "NOTE=Nearby animals never preempt Rest by proximity alone; real attack input still does.",
            "NOTE=Stationary manual Rest is preserved; actual movement hands off to masked automatic Rest.",
            "NOTE=Manual Rest input yields ownership; delayed auto Rest echoes stay masked.",
            "NOTE=PreAnimation and early render mask are local visuals, not guaranteed other-player appearance.",
            "NOTE=Combat alone no longer blocks status Rest; real attacks briefly release it.",
            "NOTE=Optional survival activity pauses native Rest before actual safe walking.",
            "NOTE=Grab V2 timing minigame has combat priority over native Rest.",
            "NOTE=Action arbitration still yields Rest for active grab/feed/attack/AFK movement.",
            "NOTE=A policy failure fails closed rather than allowing risky Rest.",
            "NOTE=Rest refresh uses the previously observed 5s mobile cadence; server acceptance unverified.",
            "NOTE=Actual moving and standing condition rates are measured separately with transition samples excluded.",
            "NOTE=Only same-max-HP consecutive observations measure mobile/stationary healing.",
            "NOTE=Repeated local pose signals trigger bounded safety backoff.",
            "NOTE=Local WolfRest masking can affect game animations and interactions.",
            "NOTE=WolfFeed and native feed taps suspend automatic Rest and preserve game feed ownership.",
            "NOTE=4x recovery requires actual observed condition rates, not client REST_MULT settings.",
            "NOTE=Only this native supervisor can send hub-owned Rest requests.",
            "NOTE=Feeding intervals are excluded from 4x status-rate comparisons.",
            "NOTE=Real primary clicks on native FeedCan release Rest before consumption.",
            "NOTE=Real E-key native WolfFeed actions preempt automatic Rest even with processed input.",
            "NOTE=WolfFeed and FeedCan are eat/drink strings in the recovered game controller.",
            "NOTE=Rest traffic or local attributes do not prove server-side healing."
        }
        for _,key in ipairs(EFFECTS) do
            for _,mode in ipairs({"baseline","auto","manual",
                "baseline_combat","auto_combat","manual_combat"}) do
                local row=N.conditionRates[mode][key]
                if row then
                    t[#t+1]=key.."_"..mode.."_observed_decay_per_sec="..
                        tostring(row.seconds>.1 and row.cleared/row.seconds or nil)
                    t[#t+1]=key.."_"..mode.."_eligible_seconds="..
                        string.format("%.2f",row.seconds)
                end
            end
            local base=N.conditionRates.baseline_combat[key]
            local assisted=N.conditionRates.auto_combat[key]
            local baseRate=base and base.seconds>=4 and
                base.cleared/base.seconds or nil
            local assistedRate=assisted and assisted.seconds>=4 and
                assisted.cleared/assisted.seconds or nil
            t[#t+1]=key.."_observed_combat_status_rest_ratio="..
                tostring(baseRate and baseRate>.001 and assistedRate and
                    assistedRate/baseRate or "INSUFFICIENT_COMPARABLE_SAMPLES")
            local sec=N.effectSeconds[key]
            t[#t+1]=key.."_observed_decay_per_sec="..
                tostring(sec>.1 and N.effectClears[key]/sec or nil)
            for _,mode in ipairs({"baseline_moving","auto_moving",
                "manual_moving","baseline_stationary","auto_stationary",
                "manual_stationary","baseline_combat_moving",
                "auto_combat_moving","manual_combat_moving",
                "baseline_combat_stationary","auto_combat_stationary",
                "manual_combat_stationary"}) do
                local bucket=N.conditionMotionRates[mode]
                local row=bucket and bucket[key]
                if row then
                    t[#t+1]=key.."_"..mode.."_observed_decay_per_sec="..
                        tostring(row.seconds>.1 and row.cleared/row.seconds or nil)
                    t[#t+1]=key.."_"..mode.."_eligible_seconds="..
                        string.format("%.2f",row.seconds)
                end
            end
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
        if N.feedPriorityBound then
            pcall(function()CAS:UnbindAction("FERAL_HUB_NATIVE_FEED_YIELD_V133")end)
            N.feedPriorityBound=false
        end
        if N.cobraCASBound then
            pcall(function()CAS:UnbindAction("FERAL_HUB_COBRA_KINGS_YIELD_V1346")end)
            N.cobraCASBound=false
        end
        if N.firstBitePriorityBound then
            pcall(function()CAS:UnbindAction("FERAL_HUB_FIRST_BITE_YIELD_V1353")end)
            N.firstBitePriorityBound=false
        end
        if N.eagleTalonPriorityBound then
            pcall(function()CAS:UnbindAction("FERAL_HUB_EAGLE_TALON_YIELD_V1357")end)
            N.eagleTalonPriorityBound=false
        end
        if biteAtConn then
            pcall(function()biteAtConn:Disconnect()end)
            biteAtConn=nil
        end
        if feedConn then pcall(function()feedConn:Disconnect()end)end
        if feedPoseConn then pcall(function()feedPoseConn:Disconnect()end)end
    end
    local function watchFeed(char)
        if biteAtConn then
            pcall(function()biteAtConn:Disconnect()end)
            biteAtConn=nil
        end
        if char then
            local okBite,connection=pcall(function()
                return char:GetAttributeChangedSignal("WolfBiteAt"):Connect(function()
                    if N.alive and N.enabled and player.Character==char then
                        local nativeAt=char:GetAttribute("WolfBiteAt")
                        if type(nativeAt)=="number" then
                            -- Native start is a fallback, not a verified hit.
                            N.beforeBiteInput("NATIVE WOLFBITE START / REST OFF",true)
                        end
                    end
                end)
            end)
            if okBite then biteAtConn=connection end
        end
        if feedConn then pcall(function()feedConn:Disconnect()end)end
        if feedPoseConn then pcall(function()feedPoseConn:Disconnect()end)end
        feedConn=nil
        feedPoseConn=nil
        N.feedChar=nil
        N.feedActive=false
        N.feedUntil=0
        N.feedApproachUntil=0
        if not char then return end
        local ok,conn=pcall(function()
            return char:GetAttributeChangedSignal("WolfFeed"):Connect(function()
                if not N.alive or player.Character~=char then return end
                if nativeFeed(char:GetAttribute("WolfFeed")) then
                    N.beforeFeed("NATIVE WOLFFEED / AUTO REST RELEASED")
                end
            end)
        end)
        if ok then feedConn=conn end
        local poseOk,poseConn=pcall(function()
            return char:GetAttributeChangedSignal("WolfRest"):Connect(function()
                if N.alive and player.Character==char then
                    clearOwnedFeedEcho(char,os.clock())
                    clearOwnedDeathRollEcho(char,os.clock())
                end
            end)
        end)
        if poseOk then feedPoseConn=poseConn end
        if nativeFeed(char:GetAttribute("WolfFeed")) then
            N.beforeFeed("SPAWNED FEEDING / AUTO REST OFF")
        end
    end
    watchFeed(player.Character)
    pcall(function()
        conns[#conns+1]=player.CharacterAdded:Connect(watchFeed)
    end)
    -- Read-only monitoring of game Death Roll state. Attribute absence
    -- is allowed: the F-key input guard still covers the start delay.
    pcall(function()
        conns[#conns+1]=player.CharacterAdded:Connect(function()
            N.deathRollChar=nil
            N.deathRollInputUntil=0
            N.deathRollStateHoldUntil=0
            N.deathRollEchoUntil=0
            N.deathRollEchoCount=0
            N.deathRollStateSince=0
        end)
    end)
    -- A genuine game Feed tap can precede WolfFeed and must release Rest
    -- before the first server-owned food/water action is attempted.
    pcall(function()
        conns[#conns+1]=player:GetAttributeChangedSignal("FeralFeedTap"):Connect(
            function()
                -- WolfController runs toggleFeed on *every attribute change*,
                -- regardless of the new value. Match the native trigger.
                N.beforeFeed("NATIVE FEED TAP / AUTO REST RELEASED")
            end)
    end)
    -- Covers HUD/mobile ability activation as well as keyboard F.
    -- The game, not this hub, still owns target selection and firing.
    conns[#conns+1]=player:GetAttributeChangedSignal("FeralTalonPress"):Connect(function()
        N.beforeEagleTalon("EAGLE NATIVE TALON PRESS / REST RELEASED",true)
    end)
    conns[#conns+1]=player:GetAttributeChangedSignal("FeralKingsPress"):Connect(function()
        if player:GetAttribute("FeralMenuOpen")~=true then
            N.beforeKingsStrike("COBRA NATIVE KINGS PRESS / REST RELEASED")
        end
    end)
    N.conn=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            N.lastError=tostring(err)
            cancel("NATIVE RECOVERY ERROR",true)
        end
    end)
    N.isNativeFeed=nativeFeed
    return N
end
return Native
