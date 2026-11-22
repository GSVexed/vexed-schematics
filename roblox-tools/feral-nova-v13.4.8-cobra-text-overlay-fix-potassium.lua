-- FERAL NOVA v13.4.8 PROJECT RENAISSANCE / COBRA AIM AND BITE GEOMETRY PATCH
-- 23 modules: action coordination, native features, read-only evidence and four-tab DATA dashboard.
-- Uses no game:HttpGet. Loaded gameplay state is client-side; server acceptance unverified.
local H={}
local bootAt=os.clock()
local log={schema="FERAL_HUB_STARTUP_V7",name="FERAL HUB",version="13.4.8",
    baseline="NOVA PRIME v32",phase="preflight",result="STARTING",
    moduleCount=0,modules={},capabilities={},steps={}}
local overlay,view,copyButton
local function clean(s)
    s=tostring(s or "")
    if #s>600 then s=s:sub(1,600)end
    return s
end
local function json()
    log.elapsedSeconds=math.floor((os.clock()-bootAt)*1000)/1000
    local ok,t=pcall(function()return game:GetService("HttpService"):JSONEncode(log)end)
    return ok and t or "{\"error\":\"json unavailable\"}"
end
local function save()
    if type(writefile)=="function" then
        pcall(function()writefile("FERAL_HUB_STARTUP_v7.json",json())end)
    end
end
local function show(label,detail,isError)
    pcall(function()
        if view and view.Parent then
            view.Text="FERAL NOVA v13.4.8  /  PROJECT RENAISSANCE\n"..
                tostring(label).."\n"..clean(detail)
            view.TextColor3=isError and Color3.fromRGB(255,146,151)
                or Color3.fromRGB(120,235,217)
        end
        warn("[FERAL HUB] "..tostring(label).." | "..clean(detail))
    end)
end
function H.phase(s)
    log.phase=tostring(s)
    log.steps[#log.steps+1]={name=tostring(s),at=os.clock()-bootAt}
    show("STARTING",s,false)
    save()
end
function H.loaded(path)
    log.moduleCount+=1
    log.modules[#log.modules+1]=path
end
function H.attach(name,fn)
    H.phase("ATTACH: "..name)
    local ok,value=pcall(fn)
    if not ok then error(name.." attach failed: "..tostring(value),0)end
    return value
end
function H.brand(gui)
    local changes=0
    for _,x in ipairs(gui:GetDescendants()) do
        if x:IsA("TextLabel") or x:IsA("TextButton") then
            local t=x.Text
            local nextText=t
            if t=="N O V A   P R I M E" then
                nextText="F E R A L   H U B"
            elseif t=="✦  NOVA" then
                nextText="✦  FERAL HUB"
            elseif t:find("FERAL  •  v32.0",1,true) then
                nextText="FERAL NOVA  •  v13.4.8  •  23 OFFLINE MODULES"
            end
            if t~=nextText then x.Text=nextText;changes+=1 end
        end
    end
    log.rebrandedElements=changes
end
-- Passive own-animal reports only. Does not issue game-server remotes.
local session={
    schema="FERAL_HUB_SESSION_V7",version="13.4.8",
    state="NOT_STARTED",sampleSeconds=10,samples={},
    note="Locally observed values; not proof of server-authoritative changes"
}
local monitoring=false
local monitorConnection
local prevSample=0
local prevSave=0
function H.sessionJson()
    local ok,data=pcall(function()
        return game:GetService("HttpService"):JSONEncode(session)
    end)
    return ok and data or "{\"error\":\"session unavailable\"}"
end
local function saveSession()
    if type(writefile)=="function" then
        pcall(function()writefile("FERAL_HUB_SESSION_v7.json",H.sessionJson())end)
    end
end
function H.startSession(ctx)
    if monitoring then return end
    monitoring=true
    session.state="RUNNING"
    local me=game:GetService("Players").LocalPlayer
    local run=game:GetService("RunService")
    local function finite(n)
        return type(n)=="number" and n==n and math.abs(n)<1e10 and math.floor(n*1000+.5)/1000 or nil
    end
    local function sample()
        local now=os.clock()
        local ok,err=pcall(function()
            local char=me and me.Character
            local own=type(ctx.stats)=="function" and ctx.stats() or {}
            local eagle=ctx.eagleActions
            local ev=ctx.evidence and ctx.evidence.summary and ctx.evidence.summary() or {}
            local row={
                elapsed=finite(now-bootAt),
                species=char and tostring(char:GetAttribute("Species") or "unknown"):sub(1,40) or "none",
                growth=finite(char and char:GetAttribute("Growth")),
                hp=finite(own.hp),maxHp=finite(own.maxHp),
                stamina=finite(own.stamina),maxStamina=finite(own.maxStamina),
                hunger=finite(char and char:GetAttribute("Hunger")),
                thirst=finite(char and char:GetAttribute("Thirst")),
                wolfRest=char and char:GetAttribute("WolfRest")==true or false,
                poseRetryRemaining=finite(ctx.native and math.max(0,(ctx.native.poseRetryAt or 0)-now)),
                combatDeadline=finite((me and me:GetAttribute("FeralCombatUntil")) or
                    (char and char:GetAttribute("FeralCombatUntil"))),
                recovery=ctx.activeRecovery and tostring(ctx.activeRecovery.mode):sub(1,60) or "unknown",
                recoveryReason=ctx.activeRecovery and
                    tostring(ctx.activeRecovery.lastReason):sub(1,70) or "unknown",
                realRestFallback=false,
                mobileRestSignal=ctx.native and ctx.native.active or false,
                combatRestBlocks=finite(ctx.native and ctx.native.combatTagBlocks),
                mobileRestSignalSeconds=finite(ctx.native and ctx.native.mobileSignalSeconds),
                realRestFallbackCount=finite(ctx.activeRecovery and ctx.activeRecovery.fallbackCount),
                nativeMaskedHealSeconds=finite(ctx.native and ctx.native.eligibleHPSeconds),
                nativeMaskedHealGain=finite(ctx.native and ctx.native.observedHPGain),
                woundedRecoveryWait=finite(ctx.activeRecovery and ctx.activeRecovery.woundedBlockedSeconds),
                growthQuality=ctx.mechanics and tostring(ctx.mechanics.growthQuality):sub(1,60) or "unknown",
                growthYoungOnSeconds=finite(ctx.mechanics and ctx.mechanics.growthByStage.young.on.seconds),
                growthYoungOffSeconds=finite(ctx.mechanics and ctx.mechanics.growthByStage.young.off.seconds),
                climb=ctx.climb and tostring(ctx.climb.status):sub(1,60) or "unknown",
                escape=ctx.escape and tostring(ctx.escape.status):sub(1,60) or "unknown",
                flight=ctx.flight and tostring(ctx.flight.status):sub(1,60) or "unknown",
                lungeReady=finite((me and me:GetAttribute("FeralLungeReadyAt")) or
                    (char and char:GetAttribute("FeralLungeReadyAt"))),
                lungeReadySource=finite(me and me:GetAttribute("FeralLungeReadyAt"))
                    and "PLAYER" or finite(char and char:GetAttribute("FeralLungeReadyAt"))
                    and "CHARACTER" or "NONE",
                cooldownTotal=finite((me and me:GetAttribute("FeralLungeCdTotal")) or
                    (char and char:GetAttribute("FeralLungeCdTotal"))),
                observedHolds=finite(eagle and eagle.actualClampObservations),
                physicalHolds=finite(eagle and eagle.anyClampObservations),
                eagleRemoteBinds=finite(eagle and eagle.remoteBinds),
                eagleRemoteLateBinds=finite(eagle and eagle.remoteLateBinds),
                eagleTargetClockMismatches=finite(eagle and eagle.incomparableTargetPressClocks),
                physicalHoldsNearReply=finite(eagle and eagle.nearServerClampObservations),
                oversizedByLocalRatio=finite(eagle and eagle.clientOversizeClampObservations),
                clampReplies=finite(eagle and eagle.serverClampReplies),
                scratchReplies=finite(eagle and eagle.serverBitReplies),
                afkRobloxEnabled=ctx.afk and ctx.afk.robloxEnabled or false,
                afkSurvivalEnabled=ctx.afk and ctx.afk.survivalEnabled or false,
                afkPulses=finite(ctx.afk and ctx.afk.pulseSuccess),
                afkSafeMoves=finite(ctx.afk and ctx.afk.survivalMoves),
                afkSafeArrivals=finite(ctx.afk and ctx.afk.survivalArrivals),
                afkBonusProgress=finite(ctx.afk and ctx.afk.survivalProgress),
                mobileMovingHealGain=finite(ctx.native and ctx.native.movingObservedHPGain),
                mobileMovingHealSeconds=finite(ctx.native and ctx.native.movingEligibleHPSeconds),
                mobileStillHealGain=finite(ctx.native and ctx.native.stationaryObservedHPGain),
                mobileStillHealSeconds=finite(ctx.native and ctx.native.stationaryEligibleHPSeconds),
                mobileRestMotionRefreshes=finite(ctx.native and ctx.native.movingRefreshRequests),
                evidenceMovingHPPerS=finite(ev.movingHealingRate),
                evidenceStillHPPerS=finite(ev.stationaryHealingRate),
                evidenceMovingToStill=finite(ev.movingToStillRatio),
                evidenceInjuryMovingRate=finite(ev.injuryMovingRate),
                evidenceInjuryStillRate=finite(ev.injuryStillRate),
                evidenceBleedMovingRate=finite(ev.bleedMovingRate),
                evidenceVenomMovingRate=finite(ev.venomMovingRate),
                evidenceSurvivalGain=finite(ev.survivalIncrease),
                evidenceStaminaConsumed=finite(ev.staminaConsumed),
                evidenceHungerLost=finite(ev.hungerLost),
                evidenceThirstLost=finite(ev.thirstLost),
                evidenceCleanMovingSeconds=finite(ev.movingSeconds),
                evidenceCleanStillSeconds=finite(ev.stationarySeconds),
                corePriority=ctx.action and tostring(ctx.action.lastPriority):sub(1,45) or "NO CORE",
                coreDenials=finite(ctx.action and ctx.action.denied),
                coreLeases=finite(ctx.action and ctx.action.leaseCount),
                coreTransitions=finite(ctx.action and ctx.action.transitions),
                miniEnabled=ctx.grabMini and ctx.grabMini.enabled or false,
                miniStrikesSeen=finite(ctx.grabMini and ctx.grabMini.strikesSeen),
                miniPerfectCenterPresses=finite(ctx.grabMini and ctx.grabMini.pressesSent),
                miniServerPerfectReplies=finite(ctx.grabMini and ctx.grabMini.serverPerfectReplies),
                miniStatus=ctx.grabMini and tostring(ctx.grabMini.status):sub(1,70) or "OFF",
                afkStatus=ctx.afk and tostring(ctx.afk.robloxStatus):sub(1,70) or "OFF",
                survivalAfkStatus=ctx.afk and tostring(ctx.afk.survivalStatus):sub(1,70) or "OFF"
            }
            session.samples[#session.samples+1]=row
            if #session.samples>360 then table.remove(session.samples,1)end
            session.sampleCount=(session.sampleCount or 0)+1
        end)
        if not ok then
            session.errorCount=(session.errorCount or 0)+1
            session.lastError=tostring(err):sub(1,250)
        end
        prevSample=now
        if now-prevSave>=20 then prevSave=now;saveSession()end
    end
    sample()
    monitorConnection=run.Heartbeat:Connect(function()
        if monitoring and os.clock()-prevSample>=session.sampleSeconds then sample()end
    end)
end
-- Safe runtime self-check; no privileged inspection APIs are invoked.
function H.selfCheck(ctx)
    local checks={}
    local function add(key,pass) checks[#checks+1]={name=key,passed=pass==true}end
    add("all_precompiled",H.precompiledCount==23)
    add("all_loaded",log.moduleCount==23)
    add("luau_smoke",log.preflight and log.preflight.loadstringSmoke==true)
    add("gui",ctx and ctx.ui and ctx.ui.Parent~=nil)
    add("session_monitor",monitoring==true and monitorConnection~=nil)
    add("shutdown",ctx and type(ctx.close)=="function")
    add("ui_refresh",ctx and type(ctx.onUI)=="function")
    add("v1132_eagle_replicated_holds",ctx and ctx.eagleActions and
        type(ctx.eagleActions.actualClampObservations)=="number" and
        type(ctx.eagleActions.actualClampHoldSeconds)=="number")
    add("v5_growth_quality",ctx and ctx.mechanics and
        type(ctx.mechanics.growthQuality)=="string")
    add("v5_recovery_reason",ctx and ctx.activeRecovery and
        type(ctx.activeRecovery.lastReason)=="string")
    add("v5_extended_diagnostics",ctx and ctx.diag and
        type(ctx.diag.payload)=="function")
    add("v6_natural_rest_fallback",ctx and ctx.activeRecovery and
        type(ctx.activeRecovery.autoRealRestFallback)=="boolean")
    add("v1132_eagle_native_remote_lifecycle",ctx and ctx.eagleActions and
        type(ctx.eagleActions.nativeLungeBinds)=="number" and
        type(ctx.eagleActions.nativeLungeRebinds)=="number")
    add("v7_strict_combat_gate",ctx and ctx.native and
        type(ctx.native.combatTagBlocks)=="number")
    add("v7_no_visible_rest_fallback",ctx and ctx.activeRecovery and
        ctx.activeRecovery.autoRealRestFallback==false)
    add("v1132_eagle_target_timing",ctx and ctx.eagleActions and
        type(ctx.eagleActions.lastTargetAt)=="number" and
        type(ctx.eagleActions.selectedTargetUpdates)=="number" and
        type(ctx.eagleActions.serverDeadlineOverwrites)=="number")
    add("v73_bounded_pose_retry",ctx and ctx.native and
        type(ctx.native.poseRetryAt)=="number" and
        type(ctx.native.poseBackoffSeconds)=="number")
    add("v73_recovery_retry_status",ctx and ctx.activeRecovery and
        type(ctx.activeRecovery.refresh)=="function")
    add("v8_shared_action_reader",ctx and ctx.action
        and type(ctx.action.snapshot)=="function")
    add("v8_idle_heartbeat",ctx and ctx.afk
        and type(ctx.afk.setRobloxEnabled)=="function")
    add("v8_survival_safe_walk",ctx and ctx.afk
        and type(ctx.afk.setSurvivalEnabled)=="function")
    add("v81_mobile_heal_disambiguation",ctx and ctx.native
        and type(ctx.native.movingObservedHPGain)=="number")
    add("v81_game_grab_minigame",ctx and ctx.grabMini
        and type(ctx.grabMini.setEnabled)=="function")
    add("v81_minigame_remote_evidence",ctx and ctx.grabMini
        and type(ctx.grabMini.strikesSeen)=="number")
    add("v81_motion_refresh_evidence",ctx and ctx.native
        and type(ctx.native.movingRefreshRequests)=="number")
    add("v9_shared_priority_policy",ctx and ctx.action
        and type(ctx.action.allowed)=="function")
    add("v9_timed_leases",ctx and ctx.action
        and type(ctx.action.reserve)=="function"
        and type(ctx.action.release)=="function")
    add("v9_priority_evidence",ctx and ctx.action
        and type(ctx.action.denials)=="table"
        and type(ctx.action.transitions)=="number")
    add("v9_grab_owned_lease_cleanup",ctx and ctx.grabMini
        and type(ctx.grabMini.close)=="function")
    add("v10_independent_evidence",ctx and ctx.evidence and type(ctx.evidence.summary)=="function")
    add("v10_evidence_reports",ctx and ctx.evidence and type(ctx.evidence.report)=="function")
    add("v10_evidence_buckets",ctx and ctx.evidence and type(ctx.evidence.moving)=="table"
        and type(ctx.evidence.stationary)=="table")
    add("v112_readonly_evidence_version",ctx and ctx.evidence and ctx.evidence.version=="11.2")
    add("v112_legacy_engine_rest_retired",ctx and ctx.state and
        ctx.state.flags and ctx.state.flags.recovery==false)
    add("v131_combat_rest_allowed",ctx and ctx.native and
        type(ctx.native.combatRestActiveSeconds)=="number" and
        type(ctx.native.combatStatusSamples)=="number" and
        type(ctx.native.conditionRates.auto_combat)=="table")
    add("v131_combat_status_independent_of_hp",ctx and ctx.action
        and type(ctx.action.allowed)=="function"
        and ctx.native and type(ctx.native.blockedByActivity)=="function")
    add("v132_death_roll_priority_and_echo_guard",ctx and ctx.native
        and type(ctx.native.beforeDeathRoll)=="function"
        and type(ctx.native.nativeDeathRollPresent)=="function"
        and type(ctx.native.deathRollInputs)=="number"
        and type(ctx.native.deathRollEchoesSuppressed)=="number")
    add("v13_native_eat_drink_semantics",ctx and ctx.native
        and type(ctx.native.isNativeFeed)=="function"
        and ctx.native.isNativeFeed("eat") and ctx.native.isNativeFeed("drink")
        and ctx.native.isNativeFeed(true)
        and not ctx.native.isNativeFeed(false)
        and not ctx.native.isNativeFeed(nil))
    add("v13_action_eat_drink_semantics",ctx and ctx.action
        and type(ctx.action.isNativeFeed)=="function"
        and ctx.action.isNativeFeed("eat") and ctx.action.isNativeFeed("drink")
        and not ctx.action.isNativeFeed(false))
    add("v13_climb_eat_drink_semantics",ctx and ctx.climb
        and type(ctx.climb.isNativeFeed)=="function"
        and ctx.climb.isNativeFeed("eat") and ctx.climb.isNativeFeed("drink")
        and not ctx.climb.isNativeFeed(false))
    add("v122_clickable_ui_feedback",ctx and ctx.uiInputHealth
        and type(ctx.uiInputHealth.clicks)=="number"
        and type(ctx.uiInputHealth.errors)=="number"
        and type(ctx.uiInputHealth.refreshErrors)=="number")
    add("v121_native_E_feed_priority",ctx and ctx.native
        and type(ctx.native.feedHotkeyPreemptions)=="number")
    add("v133_feed_input_priority_preempt",ctx and ctx.native
        and type(ctx.native.feedPriorityPreemptions)=="number"
        and type(ctx.native.feedPriorityBound)=="boolean")
    add("v133_feed_approach_window",ctx and ctx.native
        and type(ctx.native.feedApproachUntil)=="number"
        and type(ctx.native.feedApproachSeconds)=="number"
        and ctx.native.feedApproachSeconds>=4)
    add("v133_feed_gui_preempt",ctx and ctx.native
        and type(ctx.native.feedGuiPreemptions)=="number")
    add("v12_eagle_talon_clock_domains",ctx and ctx.eagleActions and
        type(ctx.eagleActions.incomparableTargetPressClocks)=="number" and
        type(ctx.eagleActions.convertedServerPressStamps)=="number")
    add("v12_grab_cross_session_strikes",ctx and ctx.grabMini
        and type(ctx.grabMini.staleStrikePackets)=="number")
    add("v12_respawn_safe_snapshot_cache",ctx and ctx.action
        and ctx.action.cacheCharacterGuard==true)
    add("v1131_deferred_carry_cancel",ctx and ctx.carry and
        type(ctx.carry.deferredCharacterDrops)=="number")
    add("v1131_eagle_carry_action_policy",ctx and ctx.eagleActions and
        type(ctx.eagleActions.nativeCarryPriorityBlocks)=="number")
    add("v113_rank_safe_action_leases",ctx and ctx.action and
        type(ctx.action.priorityConflicts)=="number" and
        type(ctx.action.characterLeaseReleases)=="number")
    add("v113_flight_priority_guard",ctx and ctx.flight and
        type(ctx.flight.actionPriorityBlocks)=="number")
    add("v113_eagle_native_reconnect",ctx and ctx.eagleActions and
        type(ctx.eagleActions.nativeLungeBinds)=="number")
    add("v113_grab_session_coherence",ctx and ctx.grabMini and
        type(ctx.grabMini.staleSessionEvents)=="number")
    add("v112_single_auto_rest_writer",ctx and ctx.recovery and
        ctx.recovery.legacyRetired==true and ctx.mobile and
        ctx.mobile.legacyRetired==true and ctx.native and
        type(ctx.native.beforeFeed)=="function")
    add("v112_feed_priority",ctx and ctx.action and
        type(ctx.action.allowed)=="function" and ctx.native
        and type(ctx.native.feedStarts)=="number")
    add("v112_effect_clearance_buckets",ctx and ctx.native and
        type(ctx.native.conditionRates)=="table" and
        type(ctx.native.conditionRates.auto)=="table")
    add("v112_auto_recovery_owns_native",ctx and ctx.activeRecovery
        and ctx.activeRecovery.nativeEligible~=nil)
    for _,key in ipairs({"power","escape","carry","reach","regen","flight","native",
            "baby","climb","mechanics","eagleActions","lab","recovery",
            "mobile","activeRecovery","tags","diag","action","afk","grabMini","evidence"}) do
        add("controller_"..key,ctx and type(ctx[key])=="table")
    end
    local n=0
    for _,x in ipairs(checks) do if x.passed then n+=1 end end
    local failures=#checks-n
    local label="SELF-CHECK "..(failures==0 and "PASS" or "INCOMPLETE")..
        " "..tostring(n).."/"..tostring(#checks)
    log.selfCheck={summary=label,passed=n,total=#checks,failed=failures,checks=checks}
    save()
    return label
end
function H.closeSession()
    monitoring=false
    if monitorConnection then pcall(function()monitorConnection:Disconnect()end);monitorConnection=nil end
    if session.state=="RUNNING" then
        session.state="CLOSED"
        session.endedElapsedSeconds=os.clock()-bootAt
        saveSession()
    end
end

pcall(function()
    local p=game:GetService("Players").LocalPlayer
    local pg=p and (p:FindFirstChildOfClass("PlayerGui") or p:WaitForChild("PlayerGui",10))
    if not pg then return end
    local old=pg:FindFirstChild("FERAL_HUB_BOOT_V7")
    if old then old:Destroy()end
    overlay=Instance.new("ScreenGui")
    overlay.Name="FERAL_HUB_BOOT_V7"
    overlay.DisplayOrder=100000
    overlay.ResetOnSpawn=false
    local pane=Instance.new("Frame")
    pane.Size=UDim2.fromOffset(570,135)
    pane.Position=UDim2.new(0,12,1,-150)
    pane.BackgroundColor3=Color3.fromRGB(11,23,36)
    pane.Parent=overlay
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,10)
    corner.Parent=pane
    view=Instance.new("TextLabel")
    view.Size=UDim2.new(1,-18,0,85)
    view.Position=UDim2.fromOffset(9,5)
    view.TextXAlignment=Enum.TextXAlignment.Left
    view.TextYAlignment=Enum.TextYAlignment.Center
    view.BackgroundTransparency=1
    view.TextWrapped=true
    view.Font=Enum.Font.GothamBold
    view.TextSize=12
    view.Parent=pane
    copyButton=Instance.new("TextButton")
    copyButton.Size=UDim2.fromOffset(175,30)
    copyButton.Position=UDim2.fromOffset(10,99)
    copyButton.BackgroundColor3=Color3.fromRGB(28,72,80)
    copyButton.TextColor3=Color3.fromRGB(232,249,253)
    copyButton.Text="COPY STARTUP REPORT"
    copyButton.TextSize=12
    copyButton.Parent=pane
    copyButton.Activated:Connect(function()
        if type(setclipboard)=="function" then
            local ok=pcall(function()setclipboard(json())end)
            copyButton.Text=ok and "REPORT COPIED" or "COPY FAILED"
        else
            copyButton.Text="CLIPBOARD UNAVAILABLE"
        end
    end)
    local hide=Instance.new("TextButton")
    hide.Size=UDim2.fromOffset(118,30)
    hide.Position=UDim2.fromOffset(195,99)
    hide.BackgroundColor3=Color3.fromRGB(36,51,67)
    hide.TextColor3=Color3.fromRGB(232,249,253)
    hide.Text="HIDE STATUS"
    hide.TextSize=12
    hide.Parent=pane
    hide.Activated:Connect(function() if overlay then overlay:Destroy()end end)
    overlay.Parent=pg
end)
local c={
    loadstring=type(loadstring)=="function",
    getgenv=type(getgenv)=="function",
    readfile=type(readfile)=="function",
    writefile=type(writefile)=="function",
    setclipboard=type(setclipboard)=="function",
    drawing=type(Drawing)=="table",
    decompile=type(decompile)=="function",
    getgc=type(getgc)=="function",
    hookfunction=type(hookfunction)=="function",
    getconnections=type(getconnections)=="function",
    getscriptbytecode=type(getscriptbytecode)=="function"
}
log.capabilities=c
log.preflight={loadstringSmoke=false,fileRoundTrip=false}
pcall(function()
    local fn=type(identifyexecutor)=="function" and identifyexecutor
        or (type(getexecutorname)=="function" and getexecutorname or nil)
    if fn then log.executor=clean(fn()) end
end)
save()
show("PREFLIGHT","Offline 23-module hub; no extra module downloads.",false)
local worked,problem=xpcall(function()
    if game.PlaceId~=108901361810209 then
        error("Wrong place: "..tostring(game.PlaceId).."; open FERAL Animal Survival.",0)
    end
    if not c.loadstring then error("loadstring is unavailable in this executor.",0)end
    local fn,issue=loadstring("return 6*7")
    if type(fn)~="function" then error("Compile smoke test failed: "..tostring(issue),0)end
    local success,value=pcall(fn)
    if not success or value~=42 then error("Runtime smoke test failed.",0)end
    log.preflight.loadstringSmoke=true
    H.phase("Luau compile/runtime smoke test passed")
    if c.writefile and c.readfile then
        local ok=pcall(function()
            local original=json()
            writefile("FERAL_HUB_STARTUP_v7.json",original)
            local echoed=readfile("FERAL_HUB_STARTUP_v7.json")
            if type(echoed)~="string" or #echoed~=#original then error("File roundtrip mismatch")end
            log.preflight.fileRoundTrip=true
        end)
        if not ok then log.preflight.fileRoundTrip=false end
    end
-- FERAL NOVA PRIME v32.0 / Eagle selected-prey carry confirmation, client cooldown gate, preserved core
-- Private game/server state is not impersonated; all changes local/reversible.
local ROOT="https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/"
if game.PlaceId~=108901361810209 then
    warn("[NOVA PRIME] Open FERAL Animal Survival before running.")
    return
end
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local pg=player and (player:FindFirstChildOfClass("PlayerGui")
    or player:WaitForChild("PlayerGui",10))
if not pg then warn("[NOVA PRIME] PlayerGui unavailable");return end

-- Preserve the fifteen v15 modules. The v25 UI is a reviewed extension; mechanics is module 16.
local BUNDLED={
["feral-aurora-engine-v11.2.lua"]=[==========[
-- FERAL NOVA v11.2 / shared engine with all legacy Rest remotes retired
-- Client presentation, own-character controls and reversible leases. Legacy Rest mask disabled.
-- No server code, grants, HP writes, Amber writes, death bypass or fake ownership.
local Engine={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local HttpService=game:GetService("HttpService")
local player=Players.LocalPlayer
local function finite(n)
    return type(n)=="number" and n==n and n>-math.huge and n<math.huge
end
local function fmt(n,d)
    return finite(n) and string.format("%."..tostring(d or 1).."f",n) or "--"
end
local function make(class,props,parent)
    local o=Instance.new(class)
    for key,v in pairs(props or {}) do o[key]=v end
    if parent then o.Parent=parent end
    return o
end
local function own()
    local char=player and player.Character
    if not char or not char.Parent then return nil,nil,nil end
    return char,char:FindFirstChildOfClass("Humanoid"),char:FindFirstChild("HumanoidRootPart")
end
local function restoreEntries(entries)
    for i=#(entries or {}),1,-1 do
        local e=entries[i]
        pcall(function()
            if e.target[e.key]==e.wanted then e.target[e.key]=e.previous end
        end)
    end
end
local function patchTable(t,plan)
    if type(t)~="table" then return nil end
    local entries={}
    for key,value in pairs(plan) do
        local ok,old=pcall(function()return t[key]end)
        if not ok or (not finite(old) and type(old)~="boolean") then
            restoreEntries(entries);return nil
        end
        if old~=value then
            local okWrite=pcall(function()t[key]=value end)
            if not okWrite then restoreEntries(entries);return nil end
            entries[#entries+1]={target=t,key=key,wanted=value,previous=old}
        end
    end
    return entries
end
local function module(name)
    local f=RS:FindFirstChild("FeralWorld")
    local m=f and f:FindFirstChild(name)
    if not m or not m:IsA("ModuleScript") then return nil end
    local ok,r=pcall(require,m)
    return ok and type(r)=="table" and r or nil
end
function Engine.new(atlas)
    local ctx={}
    ctx.atlas=type(atlas)=="table" and atlas or {}
    ctx.atlasReady=#ctx.atlas>0
    ctx.palette={
        bg=Color3.fromRGB(9,15,24),shell=Color3.fromRGB(12,20,31),
        panel=Color3.fromRGB(22,32,47),panel2=Color3.fromRGB(29,42,58),
        line=Color3.fromRGB(55,76,93),text=Color3.fromRGB(240,247,255),
        muted=Color3.fromRGB(162,180,197),dim=Color3.fromRGB(118,145,166),
        teal=Color3.fromRGB(75,226,194),violet=Color3.fromRGB(179,146,255),
        coral=Color3.fromRGB(255,154,130),amber=Color3.fromRGB(243,191,106),
        red=Color3.fromRGB(236,105,126),green=Color3.fromRGB(99,225,166)
    }
    local S={
        alive=true,theme="teal",scale=1,closed=false,hidden=false,
        flags={recovery=false,vision=false,calm=false,performance=false,
            mobility=false,speed=false,leap=false,lowNeedsAssist=false,
            playerFinder=false,
            tags=true,outlines=true,throughWalls=false,alerts=true,
            localAutosave=false,miniHUD=false},
        range=300,limit=24,tagScale=1,outlineStyle="subtle",
        restChar=nil,mask=nil,lastRest=-math.huge,
        restSent=0,restFailed=0,restEchoed=0,lastTracker=-math.huge,
        finderOrigin="NONE",finderReason="OFF",finderCounts={players=0,live=0,inRange=0,shown=0},
        leases={},attrLeases={},byPlayer={},highlightFolder=nil,light=nil,log={},
        notice="Aurora ready. All gameplay changes are OFF.",
        stat={},statusText={},nearby={},survivalMinutes=0,
        favourites={},query="",atlasCategory="All",atlasPage=1,
        lastNeedsWarning=-math.huge,mutedWarnings=false,
        chosenLocation=1,sessionStart=os.clock(),lastUI=-math.huge,
        lastPoll=-math.huge,lastHealth=nil,lastStamina=nil,
        lastHPTime=nil,lastChar=nil,lastSpeed=0,
        resource={kind="none",origin="none",candidates={},at=0,summary="Not searched yet"},
        lastLocalSave=0,localSaveCount=0,localHistory={},
        localSaveResult="Not saved. GitHub sync is not connected.",
        statusPath="FERAL_Aurora_Status_v2_1.json.txt"
    }
    ctx.state=S
    ctx.onUI=function() end
    ctx.onNotice=function() end
    ctx.ui=nil
    ctx.locations={
        {"Oasis / The spring",1070,1505},{"Canyon arch",818,1432},
        {"Golden Waterhole",-240,220},{"Eagle Rock",711,-105},
        {"Great Falls",15,-504},{"Frost Lake",30,-990},
        {"Beaver Ponds",-546,60},{"Pine Woods",-1140,180},
        {"Lunar Crest",-600,-1050},{"Goat Cliffs",1215,-855},
        {"Black Ravine",165,1620},{"Elder Giants",-1182,583},
        {"Golden Plains",717,882},{"Elk Crossing",-6,606},
        {"Rattlebone Mesa",1158,621},{"Tall Marsh",-826,1996},
        {"Mudlands",860,2110},{"Dead Lagoon",180,2142}
    }
    local prefPath="FERAL_Aurora_Preferences_v2.json"
    function ctx.accent()return ctx.palette[S.theme] or ctx.palette.teal end
    function ctx.notice(txt)
        S.notice=tostring(txt)
        S.log[#S.log+1]=string.format("%0.0fs %s",os.clock()-S.sessionStart,txt)
        if #S.log>30 then table.remove(S.log,1) end
        pcall(ctx.onNotice)
    end
    function ctx.loadPrefs()
        if type(readfile)~="function" then return end
        local ok,prefs=pcall(function()return HttpService:JSONDecode(readfile(prefPath)) end)
        if not ok or type(prefs)~="table" then return end
        if prefs.theme=="teal" or prefs.theme=="violet" or prefs.theme=="coral" then
            S.theme=prefs.theme
        end
        if finite(prefs.scale) and prefs.scale>=.70 and prefs.scale<=1.16 then
            S.scale=prefs.scale
        end
        if type(prefs.favourites)=="table" then
            for _,title in ipairs(prefs.favourites) do
                if type(title)=="string" and #title<=92 then S.favourites[title]=true end
            end
        end
        if finite(prefs.range) and prefs.range>=100 and prefs.range<=900 then
            S.range=prefs.range
        end
    end
    function ctx.savePrefs()
        if type(writefile)~="function" then return end
        local names={}
        for title,enabled in pairs(S.favourites) do
            if enabled and #names<128 then names[#names+1]=title end
        end
        pcall(function()
            writefile(prefPath,HttpService:JSONEncode({
                theme=S.theme,scale=S.scale,favourites=names,range=S.range
            }))
        end)
    end
    ctx.loadPrefs()
    function ctx.setTheme(name)
        if name~="teal" and name~="violet" and name~="coral" then return end
        S.theme=name;ctx.savePrefs();ctx.notice("Accent switched to "..name)
        ctx.onUI()
    end
    function ctx.setScale(value)
        if finite(value) then
            S.scale=math.clamp(value,.70,1.16)
            ctx.savePrefs();ctx.onUI()
        end
    end
    function ctx.toggleFavourite(title)
        if type(title)~="string" or #title>92 then return end
        S.favourites[title]=not S.favourites[title]
        ctx.savePrefs();ctx.onUI()
    end
    function ctx.setOutlineStyle(name)
        if name~="subtle" and name~="bold" then return end
        S.outlineStyle=name
        ctx.refreshTracker(true)
        ctx.notice("Outline style: "..name)
    end
    function ctx.setRange(nextRange)
        if finite(nextRange) then
            S.range=math.clamp(nextRange,100,900)
            ctx.savePrefs();ctx.notice("Player finder range: "..S.range.." studs")
            ctx.refreshTracker(true);ctx.onUI()
        end
    end
    local function setAttrLease(key,changes,enable)
        if not enable then
            for _,e in ipairs(S.attrLeases[key] or {}) do
                pcall(function()
                    if player:GetAttribute(e.key)==e.wanted then
                        player:SetAttribute(e.key,e.previous)
                    end
                end)
            end
            S.attrLeases[key]=nil
            return true
        end
        local entries={}
        for attr,wanted in pairs(changes) do
            local before=player:GetAttribute(attr)
            local ok=pcall(function()player:SetAttribute(attr,wanted) end)
            if not ok then
                for _,e in ipairs(entries) do
                    pcall(function()player:SetAttribute(e.key,e.previous)end)
                end
                return false
            end
            entries[#entries+1]={key=attr,wanted=wanted,previous=before}
        end
        S.attrLeases[key]=entries
        return true
    end
    local function stopRest()
        -- The engine no longer owns a native Rest session.
        -- Releasing its *legacy* bookkeeping must NOT cancel a real
        -- player Rest or the new Native supervisor's recovery signal.
        local m=S.mask;S.mask=nil
        if m and m.connection then
            pcall(function()m.connection:Disconnect()end)
        end
        S.restChar=nil
    end
    -- The previous legacy recovery mask forcibly wrote WolfRest=false,
    -- breaking Turtle shell and invalidating recovery observations.
    -- Keep old callers benign: only the dedicated v13 recovery module
    -- may own Rest requests. No local WolfRest writes remain in core.
    local function startRestMask(char)
        return nil
    end
    local function needsRecovery(char,hum)
        if not char or not hum or hum.Health<=0
            or char:GetAttribute("FeralDowned")==true then return false end
        if hum.Health < hum.MaxHealth-.01 then return true end
        for _,key in ipairs({"FeralBleed","FeralInjury","FeralVenomAmt"}) do
            local v=char:GetAttribute(key)
            if finite(v) and v>0 then return true end
        end
        return false
    end
    local function recoveryTick(now)
        -- Retired engine branch. The separate native recovery supervisor
        -- owns every automatic Rest request and all feed/combat exclusions.
        if S.restChar or S.mask then stopRest()end
    end
    local function turnFeature(key,on)
        if key=="recovery" then
            -- Deprecated core recovery is explicitly unavailable.
            -- Only the Native Recovery supervisor owns Rest requests.
            if on then return false end
            stopRest()
            S.lastRest=-math.huge
            return true
        elseif key=="vision" then
            if S.light then S.light:Destroy();S.light=nil end
            if on then
                S.light=make("ColorCorrectionEffect",{Name="FeralAuroraLocalVision",
                    Brightness=.12,Contrast=-.06,Saturation=.03},Lighting)
            end
            return true
        elseif key=="calm" then
            return setAttrLease(key,{FeralSet_shake=0,FeralSet_sway=false},on)
        elseif key=="performance" then
            return setAttrLease(key,{FeralSet_perf=true},on)
        elseif key=="mobility" then
            if not on then
                restoreEntries(S.leases.mobilityA)
                restoreEntries(S.leases.mobilityB)
                S.leases.mobilityA=nil;S.leases.mobilityB=nil
                return true
            end
            local needs=module("NeedsConfig")
            local status=module("StatusConfig")
            local injury=status and status.INJURY
            if type(needs)~="table" or not finite(needs.HURT_SLOW)
                or type(injury)~="table" or not finite(injury.SLOW_PER_POINT) then return false end
            local a=patchTable(needs,{HURT_SLOW=0})
            local b=patchTable(injury,{SLOW_PER_POINT=0})
            if not a or not b then restoreEntries(a);restoreEntries(b);return false end
            S.leases.mobilityA=a;S.leases.mobilityB=b;return true
        elseif key=="lowNeedsAssist" then
            if not on then
                restoreEntries(S.leases.lowNeedsAssist)
                S.leases.lowNeedsAssist=nil
                return true
            end
            local c=module("NeedsConfig")
            if not c or not finite(c.STAMINA_LOW_NEEDS)
                or c.STAMINA_LOW_NEEDS<0 or c.STAMINA_LOW_NEEDS>1 then return false end
            S.leases.lowNeedsAssist=patchTable(c,{STAMINA_LOW_NEEDS=1})
            return S.leases.lowNeedsAssist~=nil
        elseif key=="speed" then
            if not on then
                restoreEntries(S.leases.speed);S.leases.speed=nil;return true
            end
            local c=module("NeedsConfig")
            if not c or not finite(c.RUN_SPEED) or not finite(c.SWIM_SPEED)
                or c.RUN_SPEED<=0 or c.SWIM_SPEED<=0 or c.RUN_SPEED>4
                or c.SWIM_SPEED>4 then return false end
            S.leases.speed=patchTable(c,{RUN_SPEED=c.RUN_SPEED*1.10,
                SWIM_SPEED=c.SWIM_SPEED*1.10})
            return S.leases.speed~=nil
        elseif key=="leap" then
            if not on then
                restoreEntries(S.leases.leapA)
                restoreEntries(S.leases.leapB)
                S.leases.leapA=nil;S.leases.leapB=nil
                return true
            end
            local c=module("JumpLeapConfig")
            if not c or c.ON~=true or type(c.of)~="function"
                or type(c.BODY_LENGTHS)~="table" or not finite(c.DEFAULT)
                or not finite(c.MAX_RUN_SHARE) then return false end
            local plan={}
            for species,value in pairs(c.BODY_LENGTHS) do
                if type(species)=="string" and finite(value) and value>=0 and value<=10 then
                    plan[species]=value*1.10
                end
            end
            if not next(plan) then return false end
            local a=patchTable(c,{DEFAULT=c.DEFAULT*1.10,
                MAX_RUN_SHARE=c.MAX_RUN_SHARE*1.10})
            local b=patchTable(c.BODY_LENGTHS,plan)
            if not a or not b then restoreEntries(a);restoreEntries(b);return false end
            S.leases.leapA=a;S.leases.leapB=b;return true
        elseif key=="playerFinder" or key=="tags" or key=="outlines"
            or key=="throughWalls" or key=="alerts" or key=="localAutosave"
            or key=="miniHUD" then
            return true
        end
        return false
    end
    local labels={
        recovery="Recovery Assist",vision="Brighter View",calm="Calm Camera",
        performance="Native Performance",mobility="Injury Slowdown Inputs",
        lowNeedsAssist="Client Low-Needs Stamina Penalty",speed="1.10x Speed Inputs",leap="1.10x Leap Inputs",
        playerFinder="Player Finder",tags="Name Tags",outlines="Character Outlines",
        throughWalls="Through-Wall Outlines",alerts="Survival Alerts",
        localAutosave="Local Report Auto-Save",miniHUD="Compact Status HUD"
    }
    function ctx.toggle(key,value)
        if not S.alive or S.flags[key]==nil then return end
        local nextValue=value
        if nextValue==nil then nextValue=not S.flags[key] end
        nextValue=nextValue==true
        if nextValue==S.flags[key] then return end
        local ok,result=pcall(turnFeature,key,nextValue)
        if not ok or not result then
            ctx.notice("Unavailable: "..(labels[key] or key).." (live client fields did not match)")
            return
        end
        S.flags[key]=nextValue
        if key=="playerFinder" or key=="tags" or key=="outlines" or key=="throughWalls" then
            ctx.refreshTracker(true)
        end
        ctx.notice((nextValue and "ON  " or "OFF  ")..(labels[key] or key))
        ctx.onUI()
    end
    function ctx.reset()
        for _,key in ipairs({"recovery","mobility","lowNeedsAssist","speed",
            "leap","vision",
            "calm","performance","playerFinder","throughWalls","localAutosave",
            "miniHUD"}) do
            if S.flags[key] then ctx.toggle(key,false) end
        end
        ctx.notice("RESTORED: all modified settings and player overlays off.")
        ctx.onUI()
    end
    local function clearRecord(plr)
        local r=S.byPlayer[plr]
        S.byPlayer[plr]=nil
        if r then
            pcall(function()if r.h then r.h:Destroy() end end)
            pcall(function()if r.b then r.b:Destroy() end end)
        end
    end
    local function getHighlightFolder()
        if S.highlightFolder and S.highlightFolder.Parent then return S.highlightFolder end
        -- Client-created workspace descendants render as 3D highlights,
        -- unlike PlayerGui-parented Highlight instances on some Roblox builds.
        S.highlightFolder=make("Folder",{Name="FeralAuroraLocalHighlightsV2"},workspace)
        return S.highlightFolder
    end
    local function newRecord(plr,character)
        local c=ctx.palette
        local h=make("Highlight",{
            Name="Aurora_PlayerOutline",Adornee=character,
            DepthMode=Enum.HighlightDepthMode.Occluded,
            FillTransparency=.82,OutlineTransparency=.06,
            FillColor=c.teal,OutlineColor=c.teal,Enabled=true},getHighlightFolder())
        local b=make("BillboardGui",{
            Name="Aurora_PlayerTag",Adornee=character:FindFirstChild("Head")
                or character:FindFirstChild("HumanoidRootPart"),
            AlwaysOnTop=false,MaxDistance=S.range,Size=UDim2.fromOffset(182,56),
            StudsOffsetWorldSpace=Vector3.new(0,3.3,0),LightInfluence=0,
            Enabled=true},player.PlayerGui)
        local plate=make("Frame",{
            Size=UDim2.fromScale(1,1),BorderSizePixel=0,
            BackgroundColor3=Color3.fromRGB(12,21,33),
            BackgroundTransparency=.12},b)
        make("UICorner",{CornerRadius=UDim.new(0,9)},plate)
        make("UIStroke",{Color=c.teal,Transparency=.2,Thickness=1},plate)
        local name=make("TextLabel",{
            BackgroundTransparency=1,Text="ANIMAL",Font=Enum.Font.GothamBold,
            TextSize=12,TextColor3=c.text,TextXAlignment=Enum.TextXAlignment.Left,
            TextTruncate=Enum.TextTruncate.AtEnd,
            Position=UDim2.fromOffset(9,3),Size=UDim2.fromOffset(166,18)},plate)
        local info=make("TextLabel",{
            BackgroundTransparency=1,Text="",Font=Enum.Font.Gotham,
            TextSize=10,TextColor3=c.muted,TextXAlignment=Enum.TextXAlignment.Left,
            TextTruncate=Enum.TextTruncate.AtEnd,
            Position=UDim2.fromOffset(9,21),Size=UDim2.fromOffset(166,15)},plate)
        local bar=make("Frame",{
            BackgroundColor3=Color3.fromRGB(54,65,76),BorderSizePixel=0,
            Position=UDim2.fromOffset(9,42),Size=UDim2.fromOffset(164,6)},plate)
        make("UICorner",{CornerRadius=UDim.new(1,0)},bar)
        local fill=make("Frame",{
            BackgroundColor3=c.green,BorderSizePixel=0,Size=UDim2.fromScale(1,1)},bar)
        make("UICorner",{CornerRadius=UDim.new(1,0)},fill)
        local r={char=character,h=h,b=b,name=name,info=info,fill=fill}
        S.byPlayer[plr]=r
        return r
    end
    function ctx.refreshTracker(force)
        if not S.alive then return end
        local now=os.clock()
        if not force and now-S.lastTracker<.35 then return end
        S.lastTracker=now
        if not S.flags.playerFinder then
            S.finderOrigin="NONE";S.finderReason="OFF"
            S.finderCounts={players=0,live=0,inRange=0,shown=0}
            for p in pairs(S.byPlayer) do clearRecord(p) end
            if S.highlightFolder then
                pcall(function()S.highlightFolder:Destroy()end)
                S.highlightFolder=nil
            end
            S.nearby={};return
        end
        local char,hum,root=own()
        local camera=workspace.CurrentCamera
        local origin=root and root.Position
            or camera and camera.CFrame.Position or nil
        S.finderOrigin=root and "ANIMAL" or origin and "MENU CAMERA" or "NO CAMERA"
        if not origin then
            S.finderReason="Waiting for a valid character or camera."
            for p in pairs(S.byPlayer) do clearRecord(p) end
            S.nearby={};return
        end
        local near={}
        local seen={}
        local counts={players=0,live=0,inRange=0,shown=0}
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player then counts.players=counts.players+1 end
            if p~=player and p.Character then
                local other=p.Character
                local op=other:FindFirstChild("HumanoidRootPart")
                local oh=other:FindFirstChildOfClass("Humanoid")
                if op and oh and oh.Health>0 then
                    counts.live=counts.live+1
                    local d=(origin-op.Position).Magnitude
                    if d<=S.range then
                        counts.inRange=counts.inRange+1
                        near[#near+1]={player=p,char=other,hum=oh,
                            root=op,distance=d}
                    end
                end
            end
        end
        table.sort(near,function(a,b)return a.distance<b.distance end)
        S.nearby={}
        counts.shown=math.min(S.limit,#near)
        S.finderCounts=counts
        S.finderReason=counts.players==0 and "No other players in this server."
            or counts.live==0 and "Other players exist, but no living characters are replicated."
            or counts.inRange==0 and "No replicated characters within the selected range."
            or "Tracking "..counts.shown.." replicated characters from "..S.finderOrigin.."."
        for i=1,math.min(S.limit,#near) do
            local x=near[i]
            seen[x.player]=true
            local v=x.char:GetAttribute("Species")
            local species=type(v)=="string" and v or "Unknown"
            local ratio=(x.hum.MaxHealth>0 and x.hum.Health/x.hum.MaxHealth or 0)
            ratio=math.clamp(ratio,0,1)
            local color=x.distance<145 and ctx.palette.teal
                or x.distance<320 and ctx.palette.amber or ctx.palette.coral
            local r=S.byPlayer[x.player]
            if r and r.char~=x.char then clearRecord(x.player);r=nil end
            if not r then r=newRecord(x.player,x.char) end
            r.h.Adornee=x.char;r.h.Enabled=S.flags.outlines
            r.h.DepthMode=S.flags.throughWalls and
                Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            r.h.FillColor=color;r.h.OutlineColor=color
            r.h.FillTransparency=S.outlineStyle=="bold" and .60 or .86
            r.h.OutlineTransparency=S.outlineStyle=="bold" and 0 or .12
            r.b.Adornee=x.char:FindFirstChild("Head") or x.root
            r.b.Enabled=S.flags.tags
            r.b.AlwaysOnTop=S.flags.throughWalls
            r.b.MaxDistance=S.range
            local display=x.player.DisplayName or x.player.Name
            if #display>22 then display=string.sub(display,1,21).."…" end
            r.name.Text=display
            r.info.Text=species.."  •  "..math.floor(x.distance+.5).." studs"
            r.fill.Size=UDim2.fromScale(ratio,1)
            r.fill.BackgroundColor3=ratio>.5 and ctx.palette.green
                or ratio>.25 and ctx.palette.amber or ctx.palette.red
            S.nearby[#S.nearby+1]={name=display,species=species,
                distance=x.distance,health=x.hum.Health,maxHealth=x.hum.MaxHealth}
        end
        for p in pairs(S.byPlayer) do
            if not seen[p] then clearRecord(p) end
        end
    end
    function ctx.effects()
        local char,hum=own()
        if not char then return {"Animal menu — no active animal effects to read."} end
        local lines={}
        for _,entry in ipairs({
            {"FeralInjury","Injury"},{"FeralBleed","Bleeding"},
            {"FeralVenomAmt","Venom"},{"StaminaOut","Exhausted"},
            {"FeralPinned","Pinned"},{"FeralDragged","Dragged"},
            {"FeralLatching","Latched"},{"FeralVenomDown","Venom down"},
            {"FeralHomeTurf","Home Turf"},{"FeralGrazing","Grazing"},
            {"FeralBurrowed","Burrowed"}
        }) do
            local value=char:GetAttribute(entry[1])
            if value==true or finite(value) and value>0
                or type(value)=="string" and value~="" then
                lines[#lines+1]=entry[2]..(finite(value) and (" "..fmt(value,1)) or "")
            end
        end
        local now=workspace:GetServerTimeNow()
        for _,entry in ipairs({
            {"FeralThriveUntil","Thriving"},{"FeralHobbledUntil","Hobbled"}
        }) do
            local value=char:GetAttribute(entry[1])
            if finite(value) and value>now then
                lines[#lines+1]=entry[2].." ("..math.ceil(value-now).."s)"
            end
        end
        local regrow=player:GetAttribute("FeralRegrowLeft")
        if finite(regrow) and regrow>0 then lines[#lines+1]="Regrowth "..fmt(regrow) end
        if char:GetAttribute("WolfRest")==true then lines[#lines+1]="Resting" end
        return #lines>0 and lines or {"No tracked active effects."}
    end
    function ctx.stats()
        local char,hum,root=own()
        local result={
            sessionPhase=not char and "ANIMAL MENU" or (not hum or not root)
                and "SPAWNING" or hum.Health<=0 and "DOWNED / DEAD" or "IN GAME",
            species=char and char:GetAttribute("Species") or "Animal menu",
            stage=char and char:GetAttribute("AgeStage") or "No active animal",
            hp=hum and hum.Health, maxHp=hum and hum.MaxHealth,
            stamina=char and char:GetAttribute("Stamina"),
            maxStamina=char and char:GetAttribute("StaminaMax"),
            hunger=char and char:GetAttribute("Hunger"),
            thirst=char and char:GetAttribute("Thirst"),
            growth=char and char:GetAttribute("Growth"),
            amber=player:GetAttribute("Amber"),
            speed=root and Vector3.new(root.AssemblyLinearVelocity.X,0,
                root.AssemblyLinearVelocity.Z).Magnitude,
            pos=root and root.Position,
            exhausted=char and char:GetAttribute("StaminaOut")==true or false,
            mode=not char and "Menu" or char:GetAttribute("WolfBurst")==true and "Burst"
                or player:GetAttribute("HudSprint")==true and "Sprint"
                or "Ordinary",
            serverRest=char and char:GetAttribute("WolfRest")==true,
            hudRest=player:GetAttribute("HudRest")==true,
            combat=finite(player:GetAttribute("FeralCombatUntil")) and
                player:GetAttribute("FeralCombatUntil")>workspace:GetServerTimeNow(),
            activeCount=0
        }
        result.activeCount=char and #ctx.effects() or 0
        return result
    end

    -- Server-held needs and buffs cannot be minted by client attributes.
    -- Resource Finder only pinpoints replicated named props and map POIs.
    function ctx.resourceHelp()
        local a=ctx.stats()
        if a.sessionPhase~="IN GAME" then
            return "Spawn an animal first. Hunger/thirst are not readable in the menu."
        end
        local h,t=a.hunger,a.thirst
        local advice={}
        if not finite(h) then
            advice[#advice+1]="HUNGER UNKNOWN: this animal has no readable needs value."
        elseif h<20 then
            advice[#advice+1]="HUNGER CRITICAL: native feeding needed; client edits won't refill it."
        elseif h<45 then
            advice[#advice+1]="HUNGER LOW: look for edible prey, carcasses or forage for your species."
        else advice[#advice+1]="Hunger: "..fmt(h,1).." (currently adequate)." end
        if not finite(t) then
            advice[#advice+1]="THIRST UNKNOWN: this animal has no readable needs value."
        elseif t<20 then
            advice[#advice+1]="THIRST CRITICAL: reach drinking water; no remote refill available."
        elseif t<45 then
            advice[#advice+1]="THIRST LOW: navigate toward a water source."
        else advice[#advice+1]="Thirst: "..fmt(t,1).." (currently adequate)." end
        return table.concat(advice,"\n")
    end
    local waterNames={"water","pond","lake","river","creek","spring","pool","waterhole","drink"}
    local foodNames={"food","grass","feed","carcass","corpse","berry","berries","fish","plant","meat","bush","prey"}
    local function isCandidate(part,terms)
        local names={part.Name}
        local ancestor=part.Parent
        for i=1,2 do
            if not ancestor or ancestor==workspace then break end
            names[#names+1]=ancestor.Name
            ancestor=ancestor.Parent
        end
        local name=string.lower(table.concat(names," "))
        for _,term in ipairs(terms) do
            if string.find(name,term,1,true) then
                return true
            end
        end
        return false
    end
    function ctx.findResources(kind)
        if kind~="food" and kind~="water" then return end
        local char,hum,root=own()
        if not root or not hum or hum.Health<=0 then
            S.resource={kind=kind,origin="NONE",candidates={},at=os.clock(),
                summary="Spawn your animal before searching for "..kind.."."}
            ctx.notice(S.resource.summary);ctx.onUI()
            return
        end
        local candidates={}
        local terms=kind=="water" and waterNames or foodNames
        local params=OverlapParams.new()
        params.MaxParts=1100
        local ok,parts=pcall(function()
            return workspace:GetPartBoundsInRadius(root.Position,500,params)
        end)
        if not ok or type(parts)~="table" then parts={} end
        local checked=math.min(#parts,1100)
        for i=1,checked do
            local part=parts[i]
            if part:IsA("BasePart") and not part:IsDescendantOf(char)
                and isCandidate(part,terms) then
                local d=(part.Position-root.Position).Magnitude
                candidates[#candidates+1]={name=part.Parent and part.Parent.Name or part.Name,
                    distance=d,kind="replicated name match",position=part.Position}
            end
        end
        table.sort(candidates,function(a,b)return a.distance<b.distance end)
        while #candidates>5 do table.remove(candidates)end
        if kind=="water" then
            for _,point in ipairs(ctx.locations) do
                if isCandidate({Name=point[1],Parent=workspace},waterNames) then
                    local d=math.sqrt((root.Position.X-point[2])^2+
                        (root.Position.Z-point[3])^2)
                    candidates[#candidates+1]={name=point[1],distance=d,
                        kind="recorded map POI",x=point[2],z=point[3]}
                end
            end
            table.sort(candidates,function(a,b)return a.distance<b.distance end)
            while #candidates>7 do table.remove(candidates)end
        end
        local summary=#candidates==0
            and "No nearby named "..kind.." sources found in streamed geometry."
            or (#candidates.." "..kind.." leads from replicated map data (not verified edible/drinkable).")
        S.resource={kind=kind,origin="ANIMAL",candidates=candidates,
            at=os.clock(),summary=summary}
        ctx.notice(summary);ctx.onUI()
    end
    function ctx.pinResource(index)
        local resource=S.resource
        local entry=resource and resource.candidates[index]
        if not entry then return end
        local x,z=entry.x,entry.z
        if not x and entry.position then x=entry.position.X;z=entry.position.Z end
        if finite(x) and finite(z) then
            ctx.customDestination={"Resource: "..entry.name,x,z}
            ctx.notice("Compass now points to "..entry.name.." (name match only).")
            ctx.onUI()
        end
    end
    function ctx.featureStatus(key)
        if S.flags[key]==nil then return "UNAVAILABLE" end
        if not S.flags[key] then return "OFF" end
        if key=="recovery" then
            local char,hum=own()
            return not char and "ARMED • WAITING FOR SPAWN"
                or needsRecovery(char,hum) and "ARMED • NATIVE REST REQUESTS" or
                "ARMED • WAITING FOR NEED"
        elseif key=="playerFinder" then
            return S.finderReason
        elseif key=="mobility" or key=="speed" or key=="leap"
            or key=="lowNeedsAssist" then
            local lease=S.leases[key] or S.leases[key.."A"]
            if not lease then return "CLIENT PATCH NOT AVAILABLE" end
            local matches=true
            for _,item in ipairs(lease) do
                if item.target[item.key]~=item.wanted then matches=false end
            end
            return matches and "LOCAL CLIENT VALUES APPLIED" or "CLIENT VALUES CHANGED"
        elseif key=="localAutosave" then return "LOCAL FILE ONLY • NO GITHUB SYNC"
        elseif key=="throughWalls" then return "LOCAL OVERLAY • NOT SERVER VISION"
        else return "LOCAL SWITCH ON" end
    end
    function ctx.saveStatusFile()
        if type(writefile)~="function" then
            S.localSaveResult="Executor writefile unavailable; copy status instead."
            ctx.notice(S.localSaveResult);return false
        end
        local a=ctx.stats()
        local data={
            schema="feral_aurora_v2_1_local_own_state",reported_at_unix=os.time(),
            session=a.sessionPhase,species=a.species,stage=a.stage,
            hp=a.hp,max_hp=a.maxHp,stamina=a.stamina,max_stamina=a.maxStamina,
            hunger=a.hunger,thirst=a.thirst,growth=a.growth,
            amber_visible=a.amber,exhausted=a.exhausted,
            rest_requested=S.restSent,rest_failed=S.restFailed,
            effects=ctx.effects(),finder_enabled=S.flags.playerFinder,
            finder_origin=S.finderOrigin,finder_count=#S.nearby,
            finder_reason=S.finderReason,
            note="LOCAL ONLY. No other-player identifiers, coordinates, source code or credentials. GitHub upload not configured."
        }
        -- Retain up to sixty own-state snapshots in this current session.
        -- This is local-only; no other players or positions are exported.
        S.localHistory[#S.localHistory+1]=data
        while #S.localHistory>60 do table.remove(S.localHistory,1) end
        local ok,encoded=pcall(function()
            return HttpService:JSONEncode({
                schema="feral_aurora_v2_1_local_session_history",
                record_count=#S.localHistory,
                records=S.localHistory,
                note="Own-character snapshots only; GitHub auto-sync is not configured."
            })
        end)
        if not ok then
            S.localSaveResult="Could not encode own status.";return false
        end
        local written=pcall(function()writefile(S.statusPath,encoded)end)
        if written then
            S.lastLocalSave=os.clock();S.localSaveCount=S.localSaveCount+1
            S.localSaveResult="Saved "..#S.localHistory.." own-state records to "..
                S.statusPath.." in executor workspace. GitHub: not synced."
            ctx.notice("Local own-status file saved; GitHub sync is not configured.")
            return true
        end
        S.localSaveResult="Local file write failed; use COPY STATUS."
        ctx.notice(S.localSaveResult);return false
    end
    function ctx.survivalMultiplier(minutes)
        local m=math.max(0,finite(minutes) and minutes or 0)
        return math.min(3,1+.1*math.min(10,math.floor(m/10))
            +.1*math.min(10,math.floor(math.max(0,m-100)/15)))
    end
    function ctx.openNative(which)
        local attr=which=="rewards" and "FeralRewardsRequest"
            or which=="guide" and "FeralGuideRequest" or nil
        if not attr then return end
        local n=os.clock()
        if player:GetAttribute(attr)==n then n=n+.001 end
        local ok=pcall(function()player:SetAttribute(attr,n)end)
        ctx.notice(ok and ("Opened normal "..which.." interface")
            or ("Native "..which.." interface unavailable"))
    end
    function ctx.compass(point)
        local _,_,root=own()
        if not root then return "Spawn an animal for directions." end
        local dx=point[2]-root.Position.X
        local dz=point[3]-root.Position.Z
        local distance=math.sqrt(dx*dx+dz*dz)
        local camera=workspace.CurrentCamera
        local look=camera and camera.CFrame.LookVector or root.CFrame.LookVector
        local f=dx*look.X+dz*look.Z
        local right=dx*-look.Z+dz*look.X
        local angle=math.deg(math.atan2(right,f))
        local direction=math.abs(angle)>155 and "BEHIND" or angle>30 and "RIGHT"
            or angle< -30 and "LEFT" or "AHEAD"
        return string.format("%s  /  %.0f studs  /  %+.0f°",
            direction,distance,angle)
    end
    function ctx.copyStatus()
        local a=ctx.stats()
        local lines={
            "FERAL AURORA v2.1 | own-client status",
            "Session: "..a.sessionPhase,
            "Species: "..tostring(a.species).." stage: "..tostring(a.stage),
            "HP: "..fmt(a.hp).."/"..fmt(a.maxHp).." stamina: "..
                fmt(a.stamina).."/"..fmt(a.maxStamina),
            "Hunger: "..fmt(a.hunger).." thirst: "..fmt(a.thirst)
                .." growth: "..fmt(a.growth,3).." Amber (visible): "..fmt(a.amber,0),
            "Mode: "..a.mode.." exhaustion: "..tostring(a.exhausted),
            "Local HudRest: "..tostring(a.hudRest),
            "Rest requests: "..S.restSent.." failed: "..S.restFailed..
                " local echoes: "..S.restEchoed,
            "Player finder: "..tostring(S.flags.playerFinder)
                .." origin: "..S.finderOrigin
                .." name tags: "..tostring(S.flags.tags)
                .." outlines: "..tostring(S.flags.outlines)
                .." walls: "..tostring(S.flags.throughWalls)
                .." range: "..S.range.." count: "..#S.nearby,
            "Player finder state: "..S.finderReason,
            "Player counts: server others="..S.finderCounts.players
                ..", replicated living="..S.finderCounts.live
                ..", within range="..S.finderCounts.inRange,
            "Own active effects: "..table.concat(ctx.effects(),", "),
            "Food/water finder: "..S.resource.summary,
            "Local report autosave: "..tostring(S.flags.localAutosave)
                .." ("..S.localSaveCount.." files) | "..S.localSaveResult,
            "GitHub live status sync: NOT CONFIGURED (no automatic upload)",
            "Feature states requested (client-only unless noted):"
        }
        for key,enabled in pairs(S.flags) do
            if enabled then lines[#lines+1]="- "..key end
        end
        lines[#lines+1]="Enabled means requested locally, NOT a verified server-side bonus."
        lines[#lines+1]="Client display and Rest requests do not prove server acceptance."
        local result=table.concat(lines,"\n")
        local copy=type(setclipboard)=="function" and setclipboard
            or type(toclipboard)=="function" and toclipboard or nil
        if copy then
            local ok=pcall(copy,result)
            if ok then ctx.notice("Status copied to clipboard.");return true,result end
        end
        ctx.notice("Clipboard unavailable; use the selectable text field.")
        return false,result
    end
    function ctx.tick()
        if not S.alive then return end
        local now=os.clock()
        if now-S.lastPoll>=.3 then
            S.lastPoll=now
            recoveryTick(now)
            if S.flags.localAutosave and now-S.lastLocalSave>=120 then
                S.lastLocalSave=now
                ctx.saveStatusFile()
            end
            local okTracker=pcall(ctx.refreshTracker,false)
            if not okTracker and S.flags.playerFinder then
                S.flags.playerFinder=false
                for p in pairs(S.byPlayer) do clearRecord(p) end
                if S.highlightFolder then
                    pcall(function()S.highlightFolder:Destroy()end)
                    S.highlightFolder=nil
                end
                ctx.notice("Player Finder stopped after an unexpected local rendering error.")
            end
            local current=ctx.stats()
            if S.flags.alerts and now-S.lastNeedsWarning>=25 then
                local h,t=current.hunger,current.thirst
                if finite(h) and h<20 or finite(t) and t<20 then
                    ctx.notice("Low needs: hunger/thirst under 20 may reduce stamina recovery.")
                    S.lastNeedsWarning=now
                elseif current.exhausted then
                    ctx.notice("Exhaustion detected. The visible stamina bar may not tell the full story.")
                    S.lastNeedsWarning=now
                end
            end
        end
        if now-S.lastUI>=.5 then
            S.lastUI=now;pcall(ctx.onUI)
        end
    end
    ctx.connection=RunService.Heartbeat:Connect(ctx.tick)
    function ctx.close()
        if not S.alive then return end
        ctx.reset()
        S.alive=false
        if ctx.connection then ctx.connection:Disconnect() end
        if ctx.cleanupUI then pcall(ctx.cleanupUI) end
        for p in pairs(S.byPlayer) do clearRecord(p) end
        if S.highlightFolder then
            pcall(function()S.highlightFolder:Destroy()end)
            S.highlightFolder=nil
        end
        if ctx.ui then pcall(function()ctx.ui:Destroy()end)end
    end
    return ctx
end
return Engine
]==========],
["feral-aurora-power-v14.0.lua"]=[==========[
-- FERAL AURORA FORCE v14 - land vs bird stamina paths and real rate observations
-- Concrete own-client power profiles based on recovered controller fields.
-- All experimental features OFF by default. Server authority is NOT bypassed.
local Power={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function number(v)
    return type(v)=="number" and v==v and v>-math.huge and v<math.huge
end
local function loaded(name)
    local world=RS:FindFirstChild("FeralWorld")
    local mod=world and world:FindFirstChild(name)
    if not mod or not mod:IsA("ModuleScript") then
        return nil,"Module "..name.." not available"
    end
    local ok,result=pcall(require,mod)
    if not ok or type(result)~="table" then
        return nil,"Client module "..name.." not readable"
    end
    return result,nil
end
local function revert(lease)
    local reverted=0;local failed=0
    if not lease then return 0,0 end
    for i=#lease.entries,1,-1 do
        local entry=lease.entries[i]
        local ok=pcall(function()
            if lease.target[entry.key]==entry.wanted then
                lease.target[entry.key]=entry.previous
                reverted=reverted+1
            end
        end)
        if not ok then failed=failed+1 end
    end
    return reverted,failed
end
local function apply(tableValue,changes)
    if type(tableValue)~="table" then return nil,"No usable client config" end
    local lease={target=tableValue,entries={}}
    for key,wanted in pairs(changes) do
        if not number(wanted) then return nil,"Invalid number for "..key end
        local ok,previous=pcall(function()return tableValue[key]end)
        if not ok or not number(previous) then
            revert(lease);return nil,"Missing numeric field "..key
        end
        if previous~=wanted then
            local success=pcall(function()
                tableValue[key]=wanted
                assert(tableValue[key]==wanted)
            end)
            if not success then
                revert(lease);return nil,"Client config rejected "..key
            end
            lease.entries[#lease.entries+1]={
                key=key,previous=previous,wanted=wanted
            }
        end
    end
    return lease
end
function Power.attach(ctx)
    local S=ctx.state
    local P={
        alive=true,stamina="OFF",speed=1,leap=1,
        staminaLease=nil,speedLease=nil,
        leapConfig=nil,leapSpecies=nil,
        noDrain=false,turbo=false,
        lastAction="No power changes enabled.",lastError=nil,
        charFlags={},lastFlagChar=nil,heartbeat=nil,
        turboSupported=false,turboSignal="Executor keypress/keyrelease unavailable.",
        turboHeld=false,turboLast=0,
        lastRecheck=0,createdAt=os.clock(),
        lastChar=nil,appliedProfiles=0,restored=0,
        lastStaminaRate=nil,rateSamples=0,
        fallbackInfo="No status data sampled yet.",
        animalMode="WAITING",species="--",
        flightTickSeconds=0,landTickSeconds=0,
        flightStaminaGains=0,landStaminaGains=0,
        flightStaminaLoss=0,landStaminaLoss=0,
        burstSeconds=0,burstDamageEvents=0,
        suddenHpEvents=0,outEvents=0,
        observationSeconds=0,modeChanges=0,
        lastObs=nil,nextObs=0,
        lastObservedBurst=false,priorHp=nil,
        flightBaseDrain=nil,flightEasyDrain=nil,
        latestStamina=0,latestMax=0,
        birdEvidence="NO LIVE BIRD TRACE YET",
        noDrainReapplyAttempts=0,noDrainReapplyFailures=0
    }
    ctx.power=P
    local environment=nil
    if type(getgenv)=="function" then
        local ok,result=pcall(getgenv)
        if ok and type(result)=="table" then environment=result end
    end
    local press=type(keypress)=="function" and keypress
        or environment and type(environment.keypress)=="function"
        and environment.keypress or nil
    local release=type(keyrelease)=="function" and keyrelease
        or environment and type(environment.keyrelease)=="function"
        and environment.keyrelease or nil
    if press and release then
        P.turboSupported=true
        P.turboSignal="Executor key events available; native game handling still unverified."
    else
        -- Some executor environments permit VirtualInputManager instead.
        -- Its protected SendKeyEvent method may still be rejected at runtime.
        local ok,vim=pcall(function()
            return game:GetService("VirtualInputManager")
        end)
        if ok and vim then
            press=function()
                vim:SendKeyEvent(true,Enum.KeyCode.Space,false,game)
            end
            release=function()
                vim:SendKeyEvent(false,Enum.KeyCode.Space,false,game)
            end
            P.turboSupported=true
            P.turboSignal="VirtualInputManager fallback armed; input permissions unverified."
        end
    end
    local function log(info)
        P.lastAction=tostring(info)
        ctx.notice(info)
    end
    local function ownCharacter()
        local char=player.Character
        if not char or not char.Parent then return nil end
        return char
    end
    local function revertFlag(char)
        local old=P.charFlags[char]
        P.charFlags[char]=nil
        if not old or not char then return end
        pcall(function()
            if old.changed and char:GetAttribute("WolfDbgNoStamina")==true then
                char:SetAttribute("WolfDbgNoStamina",old.value)
            end
        end)
    end
    local function flagCharacter(char)
        if not char or not char.Parent then return end
        if P.charFlags[char] then
            -- The archived WolfController may refresh this attribute.
            -- Retry at most once per existing maintenance cycle, without
            -- losing the originally observed attribute for later restore.
            if char:GetAttribute("WolfDbgNoStamina")~=true then
                P.noDrainReapplyAttempts+=1
                local ok=pcall(function()
                    char:SetAttribute("WolfDbgNoStamina",true)
                end)
                if not ok then P.noDrainReapplyFailures+=1 end
            end
            return
        end
        local value=char:GetAttribute("WolfDbgNoStamina")
        local ok=pcall(function()
            if value~=true then char:SetAttribute("WolfDbgNoStamina",true)end
        end)
        if ok then
            P.charFlags[char]={value=value,changed=value~=true}
        else
            P.lastError="Own-character debug stamina flag could not be set."
        end
    end
    local function maintainFlag()
        local on=P.noDrain or P.stamina=="APEX" or P.stamina=="RECOVER"
        local char=ownCharacter()
        for c in pairs(P.charFlags) do
            if not on or c~=char then revertFlag(c)end
        end
        if on and char then flagCharacter(char)end
        P.lastFlagChar=char
    end
    function P.disableStamina(silent)
        revert(P.staminaLease);P.staminaLease=nil
        P.stamina="OFF";maintainFlag()
        if not silent then log("Stamina profile OFF • cached settings restored where still owned.")end
    end
    local function staminaPlan(mode,c)
        if not number(c.STAMINA_REGEN) or c.STAMINA_REGEN<=0
            or not number(c.STAMINA_REST_MULT)
            or not number(c.STAMINA_REGEN_DELAY)
            or not number(c.STAMINA_LOW_NEEDS) then
            return nil,"Client stamina config is missing expected values."
        end
        if mode=="RECOVER" then
            return {
                STAMINA_REGEN=c.STAMINA_REGEN*3,
                STAMINA_REST_MULT=1,
                STAMINA_REGEN_DELAY=0,
                STAMINA_LOW_NEEDS=1,
                STAMINA_SPRINT_DRAIN=0,
                STAMINA_JUMP_COST=0
            }
        elseif mode=="APEX" then
            if not number(c.STAMINA_SPRINT_DRAIN)
                or not number(c.STAMINA_JUMP_COST) then
                return nil,"Apex sprint/jump controller fields not found."
            end
            return {
                STAMINA_SPRINT_DRAIN=0,STAMINA_JUMP_COST=0,
                STAMINA_REGEN=250,STAMINA_REGEN_DELAY=0,
                STAMINA_LOW_NEEDS=1
            }
        end
        return nil,"Unknown power profile"
    end
    function P.setStamina(mode)
        if mode~="RECOVER" and mode~="APEX" and mode~="OFF" then return end
        if mode==P.stamina then return end
        P.disableStamina(true)
        if mode=="OFF" then log("Stamina config restored.");return end
        -- The standalone low-needs switch patches the SAME cached field.
        -- Release its lease first so both controls can be switched off cleanly.
        if S.flags.lowNeedsAssist then
            ctx.toggle("lowNeedsAssist",false)
        end
        local config,err=loaded("NeedsConfig")
        if not config then
            P.lastError=err;log("Unavailable: "..err);return
        end
        local plan,reason=staminaPlan(mode,config)
        if not plan then
            P.lastError=reason;log("Unavailable: "..reason);return
        end
        local lease,why=apply(config,plan)
        if not lease then
            P.lastError=why;log("Not applied: "..why);return
        end
        P.staminaLease=lease;P.stamina=mode;P.appliedProfiles+=1
        maintainFlag()
        if mode=="RECOVER" then
            log("ENDURANCE: 3x client regen + sprint/jump cost zeroed + debug flag; flight and land acceptance unverified.")
        else
            log("APEX CLIENT MODE applied: high-risk local stamina tuning. Prior prolonged Burst deaths remain unexplained.")
        end
    end
    function P.toggleNoDrain()
        P.noDrain=not P.noDrain
        maintainFlag()
        local state=P.noDrain and
            "Standalone client no-stamina-cost flag ON (not a server guarantee)." or
            P.stamina=="APEX" and
            "Standalone flag OFF; Apex profile still owns WolfDbgNoStamina." or
            "Standalone client no-drain flag OFF; original attribute restored."
        log(state)
    end
    function P.setSpeed(multiplier)
        if multiplier~=1 and multiplier~=1.15
            and multiplier~=1.30 and multiplier~=1.50 then return end
        if multiplier==P.speed then return end
        revert(P.speedLease);P.speedLease=nil;P.speed=1
        if multiplier==1 then log("Speed profile restored.");return end
        local c,why=loaded("NeedsConfig")
        if not c then log("Speed unavailable: "..why);return end
        if not number(c.RUN_SPEED) or not number(c.SWIM_SPEED)
            or c.RUN_SPEED<=0 or c.RUN_SPEED>4
            or c.SWIM_SPEED<=0 or c.SWIM_SPEED>4 then
            log("Speed profile unavailable: expected cached inputs not present.")
            return
        end
        local lease,err=apply(c,{
            RUN_SPEED=c.RUN_SPEED*multiplier,SWIM_SPEED=c.SWIM_SPEED*multiplier
        })
        if not lease then log("Speed not applied: "..err);return end
        P.speedLease=lease;P.speed=multiplier;P.appliedProfiles+=1
        log(string.format("%.2f× land/swim inputs applied locally; server checks remain independent.",multiplier))
    end
    function P.setLeap(multiplier)
        if multiplier~=1 and multiplier~=1.15 and multiplier~=1.35 then return end
        if multiplier==P.leap then return end
        revert(P.leapSpecies);revert(P.leapConfig)
        P.leapSpecies=nil;P.leapConfig=nil;P.leap=1
        if multiplier==1 then log("Leap profile restored.");return end
        local c,why=loaded("JumpLeapConfig")
        if not c or c.ON~=true or type(c.BODY_LENGTHS)~="table"
            or not number(c.DEFAULT) or not number(c.MAX_RUN_SHARE) then
            log("Leap unavailable: original cached module not usable.");return
        end
        local species={}
        for name,value in pairs(c.BODY_LENGTHS) do
            if type(name)=="string" and number(value) and value>=0 and value<=10 then
                species[name]=value*multiplier
            end
        end
        if not next(species) then log("Leap source has no usable species entries.");return end
        local one,firstErr=apply(c,{
            DEFAULT=c.DEFAULT*multiplier,
            MAX_RUN_SHARE=c.MAX_RUN_SHARE*multiplier
        })
        if not one then log("Leap unavailable: "..firstErr);return end
        local two,secondErr=apply(c.BODY_LENGTHS,species)
        if not two then
            revert(one);log("Leap species table unavailable: "..secondErr);return
        end
        P.leapConfig=one;P.leapSpecies=two;P.leap=multiplier
        P.appliedProfiles+=1
        log(string.format("%.2f× leap inputs locally applied (not flight or a server grant).",multiplier))
    end
    local function releaseSpace()
        if P.turboHeld and release then pcall(release,0x20)end
        P.turboHeld=false
    end
    function P.toggleTurbo()
        if not P.turboSupported then
            log("Rapid Escape unavailable: this executor does not expose keypress/keyrelease.")
            return
        end
        P.turbo=not P.turbo
        if not P.turbo then releaseSpace()end
        log(P.turbo and "Rapid Escape ARMED: hold ALT to pulse Space, chat input excluded."
            or "Rapid Escape OFF: key events stopped.")
    end
    local function turboTick(now)
        if not P.turbo or not P.turboSupported then return end
        if UIS:GetFocusedTextBox() then
            releaseSpace();return
        end
        if not (UIS:IsKeyDown(Enum.KeyCode.LeftAlt)
            or UIS:IsKeyDown(Enum.KeyCode.RightAlt)) then
            releaseSpace();return
        end
        if now-P.turboLast<.17 then return end
        P.turboLast=now
        if not P.turboHeld then
            local ok=pcall(press,0x20)
            if ok then
                P.turboHeld=true
                task.delay(.06,function()
                    if not P.alive then releaseSpace();return end
                    releaseSpace()
                end)
            else
                P.turbo=false;P.lastError="Executor keypress failed"
                log("Rapid Escape stopped: key input was rejected by executor.")
            end
        end
    end
    function P.reset()
        P.disableStamina(true)
        P.noDrain=false;maintainFlag()
        P.setSpeed(1);P.setLeap(1)
        P.turbo=false;releaseSpace()
        P.lastAction="All power profiles OFF; original client inputs restored where still owned."
        ctx.notice(P.lastAction)
    end
    function P.status()
        local a=ctx.stats()
        local valid=function(lease)
            if not lease then return false end
            local ok,match=pcall(function()
                for _,entry in ipairs(lease.entries) do
                    if lease.target[entry.key]~=entry.wanted then return false end
                end
                return true
            end)
            return ok and match
        end
        local char=ownCharacter()
        local flag=char and char:GetAttribute("WolfDbgNoStamina")==true or false
        local danger=P.stamina=="APEX" and "AGGRESSIVE / HIGH RISK" or
            P.stamina=="RECOVER" and "RECOVERY / EXPERIMENTAL" or "STOCK"
        return {
            stamina=P.stamina,
            staminaMatches=valid(P.staminaLease),
            speed=P.speed,speedMatches=valid(P.speedLease),
            leap=P.leap,leapMatches=valid(P.leapConfig) and valid(P.leapSpecies),
            noDrain=P.noDrain,turbo=P.turbo,turboSupported=P.turboSupported,
            flag=flag,mode=danger,phase=a.sessionPhase,
            hp=a.hp,staminaValue=a.stamina,maxStamina=a.maxStamina,
            healthMax=a.maxHp,hunger=a.hunger,thirst=a.thirst,
            last=P.lastAction,error=P.lastError,
            appliedProfiles=P.appliedProfiles
        }
    end
    local function watchStamina(now)
        if now<P.nextObs then return end
        P.nextObs=now+.28
        local char=ownCharacter()
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health<=0 then
            P.lastObs=nil
            P.animalMode="WAITING"
            return
        end
        local species=tostring(char:GetAttribute("Species") or "UNKNOWN")
        local flight=char:GetAttribute("FeralFlyLocal")==true
            or char:GetAttribute("FeralFlyDrain")==true
        local mode=flight and "FLIGHT" or "LAND / SWIM / OTHER"
        local stamina=char:GetAttribute("Stamina")
        local maximum=char:GetAttribute("StaminaMax")
        local burst=char:GetAttribute("FeralFlyBurst")==true
            or player:GetAttribute("HudBurst")==true
        local nowHp=hum.Health
        local out=char:GetAttribute("StaminaOut")==true
        if mode~=P.animalMode then P.modeChanges+=1 end
        P.animalMode=mode
        P.species=species
        if number(stamina) then P.latestStamina=stamina end
        if number(maximum) then P.latestMax=maximum end
        local last=P.lastObs
        if last and last.char==char and last.mode==mode then
            local dt=now-last.time
            if dt>.05 and dt<1.3 then
                local isFlight=mode=="FLIGHT"
                if isFlight then P.flightTickSeconds+=dt
                else P.landTickSeconds+=dt end
                if number(stamina) and number(last.stamina) then
                    local d=stamina-last.stamina
                    if d>.02 then
                        if isFlight then P.flightStaminaGains+=d
                        else P.landStaminaGains+=d end
                    elseif d<-.02 then
                        if isFlight then P.flightStaminaLoss-=d
                        else P.landStaminaLoss-=d end
                    end
                end
                if burst then P.burstSeconds+=dt end
                if number(nowHp) and number(last.hp) then
                    local loss=last.hp-nowHp
                    if loss>math.max(10,(hum.MaxHealth or 100)*.10) then
                        P.suddenHpEvents+=1
                        if burst then P.burstDamageEvents+=1 end
                    end
                end
                if out and not last.out then P.outEvents+=1 end
                P.observationSeconds+=dt
            end
        end
        P.lastObs={char=char,mode=mode,time=now,
            stamina=stamina,hp=nowHp,out=out}
        if flight and P.flightTickSeconds>=3 then
            P.birdEvidence="FLIGHT CONTROLLER ACTIVE; OBSERVE SERVER EFFECTS"
        end
    end
    function P.enduranceReport()
        return table.concat({
            "FERAL NOVA PRIME v14 | Land and Flight Endurance",
            "species="..P.species.." movement_path="..P.animalMode,
            "endurance_mode="..P.stamina,
            "client_debug_no_drain="..tostring(
                ownCharacter() and ownCharacter():GetAttribute("WolfDbgNoStamina")==true),
            "debug_flag_reapply_attempts="..P.noDrainReapplyAttempts,
            "debug_flag_reapply_failures="..P.noDrainReapplyFailures,
            "flight_trace_seconds="..string.format("%.2f",P.flightTickSeconds),
            "land_trace_seconds="..string.format("%.2f",P.landTickSeconds),
            "flight_stamina_gained="..string.format("%.2f",P.flightStaminaGains),
            "flight_stamina_lost="..string.format("%.2f",P.flightStaminaLoss),
            "land_stamina_gained="..string.format("%.2f",P.landStaminaGains),
            "land_stamina_lost="..string.format("%.2f",P.landStaminaLoss),
            "burst_seconds="..string.format("%.2f",P.burstSeconds),
            "burst_hp_loss_events="..P.burstDamageEvents,
            "large_hp_loss_events="..P.suddenHpEvents,
            "stamina_out_transitions="..P.outEvents,
            "current_stamina="..string.format("%.1f",P.latestStamina),
            "current_stamina_max="..string.format("%.1f",P.latestMax),
            "mode_changes="..P.modeChanges,
            "bird_evidence="..P.birdEvidence,
            "NOTE=Flight and land share stamina resources, but different drain paths.",
            "NOTE=Observed bird survival does not prove bypass of server validation."
        },"\n")
    end
    P.connection=RunService.Heartbeat:Connect(function()
        if not P.alive or not S.alive then return end
        local now=os.clock()
        turboTick(now)
        watchStamina(now)
        if now-P.lastRecheck>=.75 then
            P.lastRecheck=now
            local char=ownCharacter()
            if char~=P.lastChar then P.lastChar=char end
            -- Also check the current animal: a later controller update may
            -- have undone the flag even while this species stays the same.
            maintainFlag()
        end
    end)
    local priorReset=ctx.reset
    function ctx.reset()
        P.reset()
        priorReset()
    end
    local priorClose=ctx.close
    function ctx.close()
        if P.alive then
            P.reset()
            P.alive=false
            if P.connection then P.connection:Disconnect()end
            releaseSpace()
        end
        priorClose()
    end
    return P
end
return Power

]==========],
["feral-nova-escape-core-v9.0.lua"]=[==========[
-- FERAL NOVA CORE v9.0 / native escape with Grab V2 priority and friendly baby protection.
-- Captured FeralLungeUI: TUG_MIN_GAP=.10, SHAKE_MIN_GAP=.15,
-- SHAKE_MASH=false (directional FeralShakeTaps), getoff gap=.40.
-- Only sends native actions while its OWN character reports a grab
-- or the native grab control is actually bound. Server acceptance unknown.
local Escape={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local CAS=game:GetService("ContextActionService")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer

local function num(v)
    return type(v)=="number" and v==v and v>=0 and v<1e8
end
local function on(obj,key)
    return obj and obj:GetAttribute(key)==true
end
local function positive(obj,key)
    local a=obj and obj:GetAttribute(key)
    return num(a) and a>0
end

function Escape.choose(carry,pinned,clamp,need,bindings)
    bindings=bindings or {}
    if carry then return "getoff","CARRIED",.435 end
    -- The captured game has SHAKE_MASH=false. In that mode
    -- FeralShakeTaps is the actual A/D escape binding.
    local shakeBinding=bindings.FeralShakeTaps or bindings.FeralShakeMash
    local tugBinding=bindings.FeralTugTap
    if (clamp or need or pinned) and tugBinding then
        return "shake","TUG PREY",.12
    end
    if (clamp or need or pinned) and shakeBinding then
        return "shake","DIRECTIONAL SHAKE",.17
    end
    if pinned and (clamp or need) then
        return "shake","PINNED CLAMP STATE",.17
    end
    if clamp and need then
        return "shake","CLAMP PROGRESS",.17
    end
    -- The pinned cue alone is not proof that a shake request is allowed;
    -- don't send arbitrary game traffic without a native escape binding.
    return nil,"UNCLASSIFIED PIN",nil
end

function Escape.attach(ctx)
    local E={
        alive=true,enabled=true,status="WATCHING",
        trigger="",mode="NONE",input="NO INJECTION",
        nativeCount=0,pulses=0,detections=0,
        attempts={getoff=0,shake=0},
        progress=0,releaseEvents=0,
        cases=0,activeSince=0,longest=0,
        lastShakeHave=nil,lastClamp=nil,
        noProgressWarnings=0,lastError="",
        holdingPauses=0,carryIntentPauses=0,lastCarryState="FREE",
        friendlyCarryHolds=0,friendlyCarryReason="NONE",
        bindingPolls=0,
        lastCharacter=nil,bindings={},
        nextBindings=0,nextScan=0,nextAction=0,
        nextKey=0,down=false,token=0,active=false,
        fallbackUntil=0,fallbackReason="",
        lastAction="",nextReport=0,
        pendingFeedback=false
    }
    local env
    if type(getgenv)=="function" then
        local ok,result=pcall(getgenv)
        if ok and type(result)=="table" then env=result end
    end
    local kp=(type(keypress)=="function" and keypress)
        or (env and type(env.keypress)=="function" and env.keypress)
    local kr=(type(keyrelease)=="function" and keyrelease)
        or (env and type(env.keyrelease)=="function" and env.keyrelease)
    local press,release
    if type(kp)=="function" and type(kr)=="function" then
        press=function()kp(0x20)end
        release=function()kr(0x20)end
        E.input="EXECUTOR"
    else
        local ok,vim=pcall(function()return game:GetService("VirtualInputManager")end)
        if ok and vim then
            press=function()vim:SendKeyEvent(true,Enum.KeyCode.Space,false,game)end
            release=function()vim:SendKeyEvent(false,Enum.KeyCode.Space,false,game)end
            E.input="VIRTUAL INPUT"
        end
    end
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local charConnections={}
    local forceRead=false
    local function drop()
        if E.down then
            E.down=false;E.token+=1
            if release then pcall(release)end
        end
    end
    local function resetEpisode()
        if E.active then
            E.longest=math.max(E.longest,os.clock()-E.activeSince)
        end
        E.active=false
        E.mode="NONE"
        E.pendingFeedback=false
        E.lastShakeHave=nil
        E.lastClamp=nil
        drop()
    end
    local function connectChar(char)
        for _,c in ipairs(charConnections) do pcall(function()c:Disconnect()end)end
        table.clear(charConnections)
        resetEpisode()
        E.lastCharacter=char
        E.nextAction=0
        E.nextBindings=0
        forceRead=true
        if char then
            for _,key in ipairs({"FeralCarried","FeralPinned","FeralClampN",
                "FeralClampGame","FeralShakeHave","FeralShakeNeed",
                "FeralDowned"}) do
                local ok,c=pcall(function()
                    return char:GetAttributeChangedSignal(key):Connect(function()
                        forceRead=true
                        E.nextBindings=0
                    end)
                end)
                if ok then charConnections[#charConnections+1]=c end
            end
        end
    end
    connectChar(player.Character)
    E.charConnection=player.CharacterAdded:Connect(connectChar)

    local function updateBindings(now)
        if now<E.nextBindings and not forceRead then return end
        E.nextBindings=now+.12
        forceRead=false
        local ok,value=pcall(function()return CAS:GetAllBoundActionInfo()end)
        E.bindingPolls+=1
        if ok and type(value)=="table" then
            E.bindings={
                FeralCarryEscape=value.FeralCarryEscape~=nil,
                FeralShakeTaps=value.FeralShakeTaps~=nil,
                FeralShakeMash=value.FeralShakeMash~=nil,
                FeralTugTap=value.FeralTugTap~=nil
            }
        end
    end

    local function fallback(char,now)
        if now<E.nextScan then return end
        E.nextScan=now+.40
        if on(char,"FeralPinned") then
            E.fallbackUntil=now+.46
            E.fallbackReason="PINNED"
            return
        end
        if not pg then return end
        local checked=0
        for _,node in ipairs(pg:GetDescendants()) do
            checked+=1
            if checked>420 then break end
            if node:IsA("TextLabel") and node.Visible
                and (not ctx.ui or not node:IsDescendantOf(ctx.ui)) then
                local s=string.upper(node.Text or "")
                if (string.find(s,"ESCAPE",1,true)
                    or string.find(s,"SHAKE",1,true))
                    and string.find(s,"SPACE",1,true) then
                    E.fallbackUntil=now+.45
                    E.fallbackReason="ESCAPE PROMPT"
                    return
                end
            end
        end
    end

    local function pulse(now)
        if not press then E.status="KEYBOARD UNAVAILABLE";return end
        if E.down or now<E.nextKey then return end
        E.nextKey=now+.16
        local ok,err=pcall(press)
        if not ok then E.lastError=tostring(err);E.status="SPACE BLOCKED";return end
        E.down=true;E.pulses+=1
        E.status="SPACE FALLBACK (UNVERIFIED)"
        E.token+=1
        local token=E.token
        task.delay(.045,function()
            if E.alive and E.token==token then drop()end
        end)
    end

    local function observeProgress(char)
        local have=char:GetAttribute("FeralShakeHave")
        if num(have) then
            if E.lastShakeHave and have>E.lastShakeHave+.01 then
                E.progress+=1
                E.pendingFeedback=false
            end
            E.lastShakeHave=have
        end
        local clamp=char:GetAttribute("FeralClampN")
        if not num(clamp) then clamp=char:GetAttribute("FeralClampGame")end
        if num(clamp) then
            if E.lastClamp and clamp<E.lastClamp-.01 then
                E.progress+=1
                E.pendingFeedback=false
            end
            E.lastClamp=clamp
        end
    end

    local function tick()
        if not E.alive or not ctx.state.alive or not E.enabled then return end
        local now=os.clock()
        if UIS:GetFocusedTextBox() then
            drop()
            E.status="PAUSED FOR CHAT"
            return
        end
        if ctx.action and type(ctx.action.allowed)=="function" then
            local ok,allowed,reason=pcall(ctx.action.allowed,"escape")
            if not ok or not allowed then
                drop()
                E.status="ACTION PRIORITY / "..tostring(reason)
                return
            end
        end
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if char~=E.lastCharacter then connectChar(char)end
        if not char or not char.Parent or not hum or hum.Health<=0
            or on(player,"FeralMenuOpen") then
            resetEpisode()
            E.status="WAITING FOR ANIMAL"
            return
        end
        -- Eligible same-species adult carrying a baby must not be
        -- treated as an enemy grab. Still escape immediately when pinned.
        if ctx.baby and ctx.baby.shouldProtect then
            local protect,why=ctx.baby.shouldProtect(char,now)
            if protect then
                if E.active then resetEpisode() end
                drop()
                E.friendlyCarryHolds+=1
                E.friendlyCarryReason=why or "BABY CARRY"
                E.status="FRIENDLY BABY CARRY / ESCAPE PAUSED"
                return
            end
        end
        local carryState,holding,victim="UNKNOWN",false,false
        if ctx.carry and ctx.carry.classify then
            carryState,holding,victim=ctx.carry.classify(char)
        else
            -- Safe fallback when the native carry tracker is missing.
            local obj=char:FindFirstChild("FeralClamp")
            holding=obj and obj:IsA("ObjectValue")
                and (obj:GetAttribute("Carry")==true
                    or obj.Value and obj.Value.Parent~=nil)
                or char:GetAttribute("FeralCarcassCarry")==true
            victim=on(char,"FeralCarried") or on(char,"FeralPinned")
                or on(char,"FeralDragged")
        end
        E.lastCarryState=carryState
        -- Owner's outgoing FeralClamp can exist during a real grab.
        -- This is NOT evidence the owner is a victim; never spam
        -- "shake/getoff" while they carry prey or a carcass.
        if holding and not victim then
            if E.active then resetEpisode() end
            if E.status~="CARRYING / ESCAPE NOT NEEDED" then
                E.holdingPauses+=1
            end
            E.status="CARRYING / ESCAPE NOT NEEDED"
            return
        end
        -- Native G input has an unavoidable replication transition.
        -- Never mistake one's outgoing pickup/drop animation for an
        -- incoming enemy grab merely because the clamp attributes lag.
        if not victim and ctx.carry then
            local lastG=math.max(ctx.carry.lastInputAt or -math.huge,
                ctx.carry.lastAt or -math.huge)
            if now-lastG<.58 then
                if E.active then resetEpisode() end
                E.status="CARRY ACTION / ESCAPE SUSPENDED"
                E.carryIntentPauses+=1
                return
            end
        end
        local carried=on(char,"FeralCarried")
        local pinned=on(char,"FeralPinned")
        local clamp=positive(char,"FeralClampN") or positive(char,"FeralClampGame")
        local need=positive(char,"FeralShakeNeed")
        local hasCue=carried or pinned or clamp or need
        -- No need to ask ContextActionService about every bound action
        -- 8+ times a second when not grabbed. Keep fast polling only
        -- during an actual own-character escape cue.
        if hasCue then updateBindings(now) end
        local mode,reason,interval=Escape.choose(carried,pinned,clamp,need,E.bindings)
        if not hasCue then
            if E.active then
                E.releaseEvents+=1
                resetEpisode()
            end
            E.status="WATCHING"
            return
        end
        if not E.active then
            E.active=true
            E.activeSince=now
            E.cases+=1
            E.detections+=1
            E.nextAction=0
            E.lastShakeHave=nil
            E.lastClamp=nil
        end
        E.trigger=reason or "grab cue"
        observeProgress(char)
        local spent=now-E.activeSince
        E.longest=math.max(E.longest,spent)
        if mode then
            E.mode=mode
            E.status="ESCAPING / "..reason
            drop()
            if now<E.nextAction then return end
            E.nextAction=now+interval
            local remote=RS:FindFirstChild("FeralLunge")
            if not remote or not remote:IsA("RemoteEvent") then
                E.status="ESCAPE REMOTE MISSING"
                E.lastError="FeralLunge RemoteEvent unavailable"
                return
            end
            local ok,err=pcall(function()remote:FireServer(mode)end)
            if ok then
                E.nativeCount+=1
                E.attempts[mode]+=1
                E.lastAction=mode
                if spent>2.5 and E.progress==0 and E.noProgressWarnings<1 then
                    E.noProgressWarnings+=1
                    E.status="NO OBSERVED ESCAPE PROGRESS"
                end
            else
                E.lastError=tostring(err)
                E.status="NATIVE INPUT ERROR"
            end
        else
            E.mode="FALLBACK"
            fallback(char,now)
            if now<E.fallbackUntil then
                pulse(now)
            else
                E.status="GRABBED / NO CONFIRMED ACTION"
            end
        end
    end

    function E.setEnabled(v)
        E.enabled=v==true
        if E.enabled then
            E.status="WATCHING"
            E.nextBindings=0
            E.nextAction=0
        else
            resetEpisode()
            E.status="OFF"
        end
    end
    function E.report()
        return table.concat({
            "FERAL NOVA PRIME v15 | Escape",
            "status="..E.status.." enabled="..tostring(E.enabled),
            "last_cue="..E.trigger,
            "last_action="..E.lastAction.." mode="..E.mode,
            "getoff_requests="..tostring(E.attempts.getoff),
            "shake_requests="..tostring(E.attempts.shake),
            "space_fallback_pulses="..tostring(E.pulses),
            "grab_episodes="..tostring(E.cases),
            "observed_releases="..tostring(E.releaseEvents),
            "shake_progress_changes="..tostring(E.progress),
            "longest_grab_seconds="..string.format("%.2f",E.longest),
            "binding_taps="..tostring(E.bindings.FeralShakeTaps),
            "binding_tug="..tostring(E.bindings.FeralTugTap),
            "binding_mash="..tostring(E.bindings.FeralShakeMash),
            "native_binding_polls="..tostring(E.bindingPolls),
            "escape_cadence=carry_0.435s,tug_0.12s,shake_0.17s",
            "carrying_pauses="..tostring(E.holdingPauses),
            "friendly_baby_carry_suppressed_frames="..E.friendlyCarryHolds,
            "friendly_baby_evidence="..E.friendlyCarryReason,
            "carry_action_grace_frames="..tostring(E.carryIntentPauses),
            "carry_or_capture_state="..E.lastCarryState,
            "input="..E.input,
            "last_error="..E.lastError,
            "NOTE=Native requests and observed release do not prove which action caused release.",
            "NOTE=v9 prioritizes real Grab V2 timing over legacy shake/tug actions."
        },"\n")
    end
    function E.close()
        E.alive=false
        E.setEnabled(false)
        if E.connection then E.connection:Disconnect()end
        if E.charConnection then E.charConnection:Disconnect()end
        for _,c in ipairs(charConnections) do pcall(function()c:Disconnect()end)end
        table.clear(charConnections)
    end
    E.connection=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            E.lastError=tostring(err)
            E.status="ESCAPE ERROR"
            drop()
        end
    end)
    return E
end
return Escape
]==========],
["feral-nova-combat-v15.0.lua"]=[==========[
-- FERAL NOVA PRIME v15.7 / Cobra text unmounted, stale bite GUIs purged; smooth helper preserved.
-- Mirrors recovered WolfController biteClaimTarget geometry for a
-- target-in-cone hint. It never edits enemy parts or emits BiteHit.
local Combat={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer

local function finite(n)
    return type(n)=="number" and n==n and math.abs(n)<1e8
end
local function config()
    local folder=RS:FindFirstChild("FeralWorld")
    local mod=folder and folder:FindFirstChild("CombatConfig")
    if not mod or not mod:IsA("ModuleScript") then return nil end
    local ok,t=pcall(require,mod)
    if not ok or type(t)~="table" or type(t.bodyGap)~="function"
        or not finite(t.REACH) or not finite(t.CONE)
        or not finite(t.HIT_SCALE) or not finite(t.SLACK)
        or not finite(t.MAX_DY) then return nil end
    return t
end
function Combat.attach(ctx)
    local C={
        alive=true,enabled=true,status="WAITING FOR ANIMAL",
        target=nil,targetDistance=nil,margin=0,ready=false,
        bites=0,blockedRestInputs=0,monitored=0,observedHPDrops=0,
        sample=0,nextScan=0,lastBite=-math.huge,lastError="",
        window=nil,configStatus="NOT READ",mode="DISPLAY ONLY",
        playerCandidates=0,npcCandidates=0,
        closeRootDistance=nil,closeRootSize="NONE",
        closeRootCanCollide="--",closeRootGroup="--",
        ownRootSize="--",physicalEdits=0,
        oldHitboxGuiVisible=false,
        lastBlockerCheck=0,nextCollisionAudit=0,collisionAudits=0,
        rayBlockCategory="NOT CHECKED",
        configValues="NOT READ",carryBiteAttempts=0,
        nativeReady=false,boostedOnlyReady=false,
        boostedOnlyWindowCount=0,boostedOnlyBites=0,
        boostedOnlyHPDrops=0,extendedBiteEvidence="NONE",
        mouseAttempts=0,extendedMouseAttempts=0,lastExtendedInputAt=-math.huge,
        extendedWithoutNativeBite=0,nativeBitesAfterExtendedInput=0,
        rayBlockCollidable="--",
        aimAngle=0,aimHeight=0,aimMaxHeight=0,
        aimReach=0,aimCone=0,aimLOS="UNKNOWN",
        cobraShotState="NOT COBRA",cobraClientRange=nil,
        shownOffscreen=0,clientOnlyWarnings=0,
        cobraThrowRange=nil,cobraPickCone=nil,cobraShotGap=nil,
        cobraGrowthFactor=nil,cobraRangeInfo=nil,
        espDiveCount=0,espSpitCount=0,espOutOfLockCount=0,
        espActive=false,espRefreshes=0,espErrors=0,
        noHpDeclineAfterBite=0,biteClaimWindowsSampled=0,attackReadinessWaits=0,
        smoothFrames=0,smoothErrors=0,targetSwitches=0,
        renderMethod="NOT_STARTED",reticleOffscreen=false,
        stableTargetPenalty=8,scanInterval=.12,
        guideSnapCount=0,guideLastError="",guideTargetAge=0,
        staleGuideWindowsRemoved=0,cobraTextUnmounted=false,
        cobraDetection="UNKNOWN",textParentFixes=0
    }
    local playerGui=player:FindFirstChildOfClass("PlayerGui")
        or player:WaitForChild("PlayerGui",8)
    -- Every FERAL NOVA bite helper is owned by this module, not the HUD.
    -- The previous module can leave an old ScreenGui in the PlayerGui
    -- when a rerun begins after an interrupted shutdown; destroy only
    -- the dedicated bite-guide GUI names, never the game's native GUI.
    if playerGui then
        for _,old in ipairs(playerGui:GetChildren()) do
            if old:IsA("ScreenGui")
                and string.match(old.Name,"^FeralNovaBiteGuideV%d+$") then
                pcall(function() old:Destroy() end)
                C.staleGuideWindowsRemoved+=1
            end
        end
    end
    local gui=Instance.new("ScreenGui")
    gui.Name="FeralNovaBiteGuideV157"
    gui.IgnoreGuiInset=true
    gui.DisplayOrder=203
    gui.ResetOnSpawn=false
    gui.Parent=playerGui
    local circle=Instance.new("Frame")
    circle.Name="TargetPoint"
    circle.AnchorPoint=Vector2.new(.5,.5)
    circle.Size=UDim2.fromOffset(19,19)
    circle.BackgroundColor3=Color3.fromRGB(110,244,219)
    circle.BackgroundTransparency=.83
    circle.BorderSizePixel=0
    circle.Visible=false
    circle.Parent=gui
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(1,0);c.Parent=circle
    local stroke=Instance.new("UIStroke")
    stroke.Color=Color3.fromRGB(110,244,219)
    stroke.Thickness=2;stroke.Parent=circle
    local centerDot=Instance.new("Frame")
    centerDot.Name="BiteAimCenter"
    centerDot.AnchorPoint=Vector2.new(.5,.5)
    centerDot.Position=UDim2.fromScale(.5,.5)
    centerDot.Size=UDim2.fromOffset(4,4)
    centerDot.BackgroundColor3=Color3.fromRGB(110,244,219)
    centerDot.BorderSizePixel=0
    centerDot.ZIndex=7
    centerDot.Parent=circle
    local centerCorner=Instance.new("UICorner")
    centerCorner.CornerRadius=UDim.new(1,0)
    centerCorner.Parent=centerDot
    -- Always show a compact cue, including when the target is OUTSIDE
    -- the bite window; a green indicator is never shown from the old
    -- generic geometry that ignored Cobra's adult profile multiplier.
    local hint=Instance.new("TextLabel")
    hint.Name="CombatAimHintV15_1"
    hint.AnchorPoint=Vector2.new(.5,0)
    hint.Size=UDim2.fromOffset(280,42)
    hint.BackgroundColor3=Color3.fromRGB(12,23,30)
    hint.BackgroundTransparency=.18
    hint.BorderSizePixel=0
    hint.TextColor3=Color3.fromRGB(225,236,241)
    hint.Font=Enum.Font.GothamMedium
    hint.TextSize=12
    hint.TextWrapped=true
    hint.TextXAlignment=Enum.TextXAlignment.Center
    hint.TextYAlignment=Enum.TextYAlignment.Center
    hint.Visible=false
    hint.ZIndex=5
    hint.Parent=gui
    local hc=Instance.new("UICorner")
    hc.CornerRadius=UDim.new(0,7)
    hc.Parent=hint
    circle.ZIndex=6

    -- Cobra can have a different profile/model name from its Species
    -- attribute on a respawn. Prefer actual KingsStrike ability mapping,
    -- then accept the species and Cobra model/profile naming variants.
    local abilityConfig=nil
    local world=RS:FindFirstChild("FeralWorld")
    local abilityModule=world and world:FindFirstChild("AbilityConfig")
    if abilityModule then
        local ok,result=pcall(require,abilityModule)
        if ok and type(result)=="table" then abilityConfig=result end
    end
    local function isCobra(char)
        if not char then
            C.cobraDetection="NO_CHARACTER"
            return false
        end
        for _,value in ipairs({
            char:GetAttribute("Species"),char:GetAttribute("AnimProfile"),
            char.Name
        }) do
            if type(value)=="string"
                and string.find(string.lower(value),"kingcobra",1,true) then
                C.cobraDetection="COBRA_SPECIES_OR_PROFILE"
                return true
            end
        end
        local species=char:GetAttribute("Species")
        if abilityConfig and type(abilityConfig.of)=="function"
            and type(species)=="string" then
            local ok,result=pcall(abilityConfig.of,species)
            if ok and result=="KingsStrike" then
                C.cobraDetection="KINGS_STRIKE_ABILITY"
                return true
            end
        end
        C.cobraDetection=type(species)=="string" and species
            or "SPECIES_PENDING"
        return false
    end
    local conns={}
    local biteConnection
    local function own()
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if not char or not hum or not root or hum.Health<=0 then
            return nil,nil,nil
        end
        return char,hum,root
    end
    -- Match the real CombatConfig, including AnimProfile-specific reach,
    -- the snake's body gap, current cone, vertical multiplier, and the
    -- active reach controller's exact saved baseline when available.
    local function candidate(char,hum,root,preferModel)
        local cfg=config()
        if not cfg then
            C.configStatus="NATIVE COMBAT CONFIG MISSING"
            return nil
        end
        C.configStatus="READABLE; CLIENT MODEL ONLY"
        C.configValues=string.format("reach=%.3f scale=%.3f cone=%.2f slack=%.3f max_dy=%.3f",
            cfg.REACH,cfg.HIT_SCALE,cfg.CONE,cfg.SLACK,cfg.MAX_DY)
        local flatForward=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
        if flatForward.Magnitude<.01 then return nil end
        flatForward=flatForward.Unit
        local ownPack=player:GetAttribute("FeralPack")
        local ownPos=root.Position
        local reachMult=1
        if type(cfg.reachMult)=="function" then
            local ok,v=pcall(cfg.reachMult,char)
            if ok and finite(v) then reachMult=v end
        end
        local cone=cfg.CONE
        if type(cfg.coneFor)=="function" then
            local ok,v=pcall(cfg.coneFor,char)
            if ok and finite(v) then cone=v end
        end
        local dyMult=1
        if type(cfg.dyMult)=="function" then
            local ok,v=pcall(cfg.dyMult,char)
            if ok and finite(v) then dyMult=v end
        end
        local box=root:GetAttribute("FeralBoxFull")
        if not finite(box) or box<=0 then box=root.Size.Z end
        local reach=(box*.5+hum.HipHeight*cfg.REACH+cfg.SLACK)*cfg.HIT_SCALE*reachMult
        local best,bestScore
        local function consider(model)
            if model==char or not model or not model.Parent
                or model:GetAttribute("FeralDead")==true then return end
            local eRoot=model:FindFirstChild("HumanoidRootPart")
            local eHum=model:FindFirstChildOfClass("Humanoid")
            if not eRoot or not eHum or eHum.Health<=0 then return end
            local pack=model:GetAttribute("FeralPack")
            if ownPack~=nil and pack~=nil and ownPack==pack then return end
            local difference=eRoot.Position-ownPos
            local flat=Vector3.new(difference.X,0,difference.Z)
            local dist=flat.Magnitude
            if dist>(char:GetAttribute("Species")=="KingCobra" and 135 or 75) then return end
            local direction=dist>.01 and flat.Unit or flatForward
            local dot=math.clamp(flatForward:Dot(direction),-1,1)
            local angle=math.deg(math.acos(dot))
            local ok,gap=pcall(cfg.bodyGap,eRoot,flat)
            if not ok or not finite(gap) then return end
            local vertical=math.abs(difference.Y)
            local maxVertical=(hum.HipHeight+eHum.HipHeight)*cfg.MAX_DY*dyMult
            local valid=gap<reach and angle<cone and vertical<maxVertical
            local nativeValid=valid
            local boostedOnly=false
            local margin=reach-gap
            if ctx.reach and ctx.reach.applied and ctx.reach.compare then
                local compareOK,base,enhanced=pcall(
                    ctx.reach.compare,char,root,hum,eRoot,eHum)
                if compareOK and base and enhanced then
                    nativeValid=base.valid
                    valid=enhanced.valid
                    boostedOnly=enhanced.valid and not base.valid
                    margin=enhanced.margin
                    gap=enhanced.gap
                    reach=reach -- local summary remains the current client reach
                end
            end
            local score=(valid and -125 or 0)
                +(nativeValid and -10 or 0)
                +math.max(0,-margin)*.6
                +dist*.23+angle*.09
                +math.max(0,vertical-maxVertical)*.7
            -- Small hysteresis avoids swapping between similarly good
            -- targets every scan. Native vs extended validation still wins.
            if preferModel==model then score-=C.stableTargetPenalty end
            if not best or score<bestScore then
                bestScore=score
                best={model=model,root=eRoot,hum=eHum,dist=dist,
                    gap=gap,reach=reach,margin=margin,valid=valid,
                    nativeValid=nativeValid,boostedOnly=boostedOnly,
                    angle=angle,cone=cone,vertical=vertical,
                    maxVertical=maxVertical,
                    heightDelta=difference.Y,
                    turnSide=flatForward:Cross(direction).Y<0 and "R" or "L"}
            end
        end
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player and other.Character then
                C.playerCandidates+=1
                consider(other.Character)
            end
        end
        local npc=workspace:FindFirstChild("FeralNPCs")
        if npc then
            local n=0
            for _,model in ipairs(npc:GetChildren()) do
                n+=1
                if n>75 then break end
                if model:IsA("Model") then
                    C.npcCandidates+=1
                    consider(model)
                end
            end
        end
        return best
    end
    local function collisionAudit(root)
        -- Never writes part.Size, CanCollide or collision groups.
        -- This is only for identifying possible leftover v7/v8 changes.
        C.closeRootDistance=nil
        C.closeRootSize="NONE"
        C.closeRootCanCollide="--"
        C.closeRootGroup="--"
        C.ownRootSize=string.format("%.2f/%.2f/%.2f",
            root.Size.X,root.Size.Y,root.Size.Z)
        local pg=player:FindFirstChildOfClass("PlayerGui")
        C.oldHitboxGuiVisible=pg and
            (pg:FindFirstChild("FeralNovaPrimeV70")~=nil
              or pg:FindFirstChild("FeralNovaPrimeV80")~=nil)
            or false
        local nearestRoot,nearestModel
        local function inspect(char)
            if not char or char==player.Character then return end
            local other=char:FindFirstChild("HumanoidRootPart")
            if other and other:IsA("BasePart") and other.Parent then
                local d=(root.Position-other.Position).Magnitude
                if d<30 and (not C.closeRootDistance or d<C.closeRootDistance) then
                    C.closeRootDistance=d
                    C.closeRootSize=string.format("%.2f/%.2f/%.2f",
                        other.Size.X,other.Size.Y,other.Size.Z)
                    C.closeRootCanCollide=tostring(other.CanCollide)
                    C.closeRootGroup=tostring(other.CollisionGroup)
                    nearestRoot=other
                    nearestModel=char
                end
            end
        end
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player then inspect(other.Character)end
        end
        local npcs=workspace:FindFirstChild("FeralNPCs")
        if npcs then
            local i=0
            for _,obj in ipairs(npcs:GetChildren()) do
                i+=1
                if i>65 then break end
                if obj:IsA("Model") then inspect(obj)end
            end
        end
        local now=os.clock()
        if now-C.lastBlockerCheck>=.9 then
            C.lastBlockerCheck=now
            C.rayBlockCategory="NO NEARBY ANIMAL"
            C.rayBlockCollidable="--"
            if nearestRoot then
                -- Pure read: one ray per 0.9 seconds. Categorise the
                -- collidable obstruction but never export player/part names.
                local ok,category,collidable=pcall(function()
                    local params=RaycastParams.new()
                    params.FilterType=Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances={player.Character}
                    local dir=nearestRoot.Position-root.Position
                    local result=workspace:Raycast(root.Position,dir,params)
                    if not result or not result.Instance then
                        return "NO RAY CONTACT","--"
                    end
                    local part=result.Instance
                    local kind=nearestModel and part:IsDescendantOf(nearestModel)
                        and "TARGET" or "WORLD / OTHER"
                    return kind,tostring(part.CanCollide)
                end)
                C.rayBlockCategory=ok and category or "RAYCAST UNAVAILABLE"
                C.rayBlockCollidable=ok and collidable or "--"
            end
        end
    end

    local function bite()
        local now=os.clock()
        if now-C.lastBite<.075 then return end
        C.lastBite=now
        C.bites+=1
        if now-C.lastExtendedInputAt<.45 then
            C.nativeBitesAfterExtendedInput+=1
        end
        if C.target and C.target.hum then
            C.window={
                hum=C.target.hum,
                before=C.target.hum.Health,
                untilAt=now+1.0,
                boostedOnly=C.boostedOnlyReady
            }
            if C.boostedOnlyReady then C.boostedOnlyBites+=1 end
            C.monitored+=1
            C.biteClaimWindowsSampled+=1
        end
    end
    local function charChanged(char)
        if biteConnection then biteConnection:Disconnect();biteConnection=nil end
        C.window=nil
        if char then
            biteConnection=char:GetAttributeChangedSignal("WolfBiteAt"):Connect(bite)
        end
    end
    conns[#conns+1]=player.CharacterAdded:Connect(charChanged)
    charChanged(player.Character)
    conns[#conns+1]=UIS.InputBegan:Connect(function(input,processed)
        if processed then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            C.mouseAttempts+=1
            if C.boostedOnlyReady then
                C.extendedMouseAttempts+=1
                C.lastExtendedInputAt=os.clock()
            end
            local char=player.Character
            if char and char:GetAttribute("WolfRest")==true then
                C.blockedRestInputs+=1
            end
            if ctx.carry and ctx.carry.classify then
                local _,holding=ctx.carry.classify(char)
                if holding then C.carryBiteAttempts+=1 end
            end
        end
    end)

    -- Native King Cobra selector: body-edge gap, growth-scaled SPIT_RANGE,
    -- and PICK_CONE; all observed from the live replicated config.
    local cobraRangeCacheAt=0
    local cobraBase
    local function cobraRange(char)
        local now=os.clock()
        if now>=cobraRangeCacheAt then
            cobraRangeCacheAt=now+2
            cobraBase=nil
            local world=RS:FindFirstChild("FeralWorld")
            local mod=world and world:FindFirstChild("AbilityConfig")
            local ok,configData=false,nil
            if mod then ok,configData=pcall(require,mod) end
            local strike=ok and type(configData)=="table" and configData.KingsStrike or nil
            if type(strike)=="table" and finite(strike.SPIT_RANGE)
                and strike.SPIT_RANGE>0 and finite(strike.PICK_CONE)
                and strike.PICK_CONE>0 then
                cobraBase={spit=strike.SPIT_RANGE,
                    throw=finite(strike.THROW_RANGE) and strike.THROW_RANGE or nil,
                    cone=strike.PICK_CONE}
            end
        end
        if not cobraBase or not char then return nil end
        local mult=1
        local world=RS:FindFirstChild("FeralWorld")
        local mod=world and world:FindFirstChild("Species")
        if mod then
            local ok,species=pcall(require,mod)
            if ok and type(species)=="table" and type(species.size)=="function" then
                local name=char:GetAttribute("Species") or "KingCobra"
                local growth=char:GetAttribute("Growth") or 1
                local a,val=pcall(species.size,name,growth)
                local b,adult=pcall(species.size,name,1)
                if a and b and finite(val) and finite(adult) and adult>.001 then
                    mult=math.clamp(val/adult,.1,2)
                end
            end
        end
        return {spit=cobraBase.spit*mult,
            throw=cobraBase.throw and cobraBase.throw*mult or nil,
            cone=cobraBase.cone,scale=mult}
    end
    local function unobstructed(char,targetRoot,targetModel)
        if not char or not targetRoot then return false end
        local root=char:FindFirstChild("HumanoidRootPart")
        if not root then return false end
        local direction=targetRoot.Position-root.Position
        if direction.Magnitude<.01 then return true end
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={char}
        local hit=workspace:Raycast(root.Position,direction,params)
        if not hit or not hit.Instance then return true end
        if hit.Instance:IsDescendantOf(targetModel) then return true end
        return hit.Instance.CanCollide~=true
    end
    local function updateGuideAppearance(char,best)
        local status
        if C.aimLOS=="BLOCKED" then
            status="OBSTRUCTED / FIND CLEAR LINE"
        elseif best.valid and best.nativeValid then
            status="BITE READY (NATIVE CLIENT WINDOW)"
        elseif best.valid then
            status="EXTENDED BITE RANGE (SERVER UNVERIFIED)"
        elseif best.angle>=best.cone then
            status=string.format("TURN %.0f° TO REACH TARGET",
                math.max(0,best.angle-best.cone))
        elseif best.vertical>=best.maxVertical then
            status="TARGET TOO HIGH / LOW"
        else
            status="MOVE CLOSER TO BITE"
        end
        local shade=best.valid and C.aimLOS~="BLOCKED"
            and (best.nativeValid and Color3.fromRGB(110,244,219)
                or Color3.fromRGB(255,195,110))
            or Color3.fromRGB(255,121,125)
        -- Colour is authoritative only for LOCAL game claim geometry,
        -- never proof that the actual server awarded HP damage.
        stroke.Color=shade
        centerDot.BackgroundColor3=shade
        circle.BackgroundColor3=shade
        hint.TextColor3=shade
        hint.Text=string.format("%s\n%.1f studs • %s %.0f° • height %+.1f",
            status,best.dist,best.turnSide or "?",best.angle,
            best.heightDelta or 0)
    end

    -- The previous 0.14-second scan painted the GUI only ~7 times/s,
    -- then hid and re-showed it on every scan. Render every camera frame
    -- using the latest chosen target; only selection stays rate-limited.
    local smoothPosition=nil
    local lastGuideModel=nil
    local function drawGuide(dt)
        local char=player.Character
        local cobra=isCobra(char)
        -- Detach the actual text panel from the GUI tree for Cobra.
        -- This is stronger than setting Visible=false once: no text
        -- rectangle can render from this module while Cobra is active.
        -- Non-Cobra animals get the exact same text helper as before.
        if cobra then
            hint.Visible=false
            if hint.Parent then
                hint.Parent=nil
                C.textParentFixes+=1
            end
        elseif hint.Parent~=gui then
            hint.Parent=gui
            C.textParentFixes+=1
        end
        C.cobraTextUnmounted=cobra and hint.Parent==nil
        if not C.alive or not ctx.state.alive or not C.enabled then
            circle.Visible=false;hint.Visible=false
            smoothPosition=nil;lastGuideModel=nil
            return
        end
        local best=C.target
        local camera=workspace.CurrentCamera
        if not best or not best.model or not best.model.Parent
            or not best.root or not best.root.Parent
            or not best.hum or best.hum.Health<=0
            or not camera or not char or not char.Parent then
            circle.Visible=false;hint.Visible=false
            smoothPosition=nil;lastGuideModel=nil
            return
        end
        local viewport=camera.ViewportSize
        if viewport.X<100 or viewport.Y<100 then
            circle.Visible=false;hint.Visible=false
            return
        end
        local worldPoint=best.root.Position
            +Vector3.new(0,math.max(.25,best.root.Size.Y*.52),0)
        local projected,onScreen=camera:WorldToViewportPoint(worldPoint)
        local x,y=projected.X,projected.Y
        local pad=24
        local outside=projected.Z<=0 or not onScreen
        if projected.Z<=0 then
            -- A camera-facing projection of something behind you flips
            -- on the screen. Place a stable edge marker instead.
            local offset=worldPoint-camera.CFrame.Position
            local side=offset:Dot(camera.CFrame.RightVector)
            local up=offset:Dot(camera.CFrame.UpVector)
            x=side>=0 and viewport.X-pad or pad
            y=viewport.Y*.5-math.clamp(up,-25,25)*3
        end
        x=math.clamp(x,pad,viewport.X-pad)
        y=math.clamp(y,pad,viewport.Y-pad)
        C.reticleOffscreen=outside
        if outside then C.shownOffscreen+=1 end
        local desired=Vector2.new(x,y)
        local newModel=best.model~=lastGuideModel
        if newModel or not smoothPosition
            or (desired-smoothPosition).Magnitude>220 then
            smoothPosition=desired
            C.guideSnapCount+=1
        else
            local delta=type(dt)=="number" and math.clamp(dt,0,.1) or .016
            local alpha=1-math.exp(-28*delta)
            smoothPosition=smoothPosition:Lerp(desired,alpha)
        end
        lastGuideModel=best.model
        circle.Position=UDim2.fromOffset(smoothPosition.X,smoothPosition.Y)
        circle.BackgroundTransparency=outside and .94 or .83
        stroke.Transparency=outside and .2 or 0
        local width=math.min(280,math.max(95,viewport.X-26))
        hint.Size=UDim2.fromOffset(width,42)
        local half=width*.5+3
        local hintX=math.clamp(smoothPosition.X,half,
            math.max(half,viewport.X-half))
        local hintY=smoothPosition.Y+16
        if hintY+42>viewport.Y-8 then
            hintY=smoothPosition.Y-58
        end
        hint.Position=UDim2.fromOffset(hintX,math.clamp(hintY,8,
            math.max(8,viewport.Y-50)))
        circle.Visible=true
        -- The user wants ONLY ESP colours for Cobra ability range.
        -- Keep the small bite dot on Cobra, not the rectangular text box.
        hint.Visible=not cobra
            and type(char:GetAttribute("Species"))=="string"
        C.smoothFrames+=1
    end

    local DIVE_COLOR=Color3.fromRGB(97,239,151)
    local SPIT_COLOR=Color3.fromRGB(198,141,255)
    -- Called AFTER the existing ESP tracker assigns its normal colours.
    -- Never spawns new ESP or changes other players' character parts.
    local function recolorCobraESP()
        C.espDiveCount=0
        C.espSpitCount=0
        C.espOutOfLockCount=0
        C.espActive=false
        local state=ctx.state
        if not (C.alive and C.enabled and state and state.alive
            and state.flags and state.flags.playerFinder
            and state.flags.outlines) then return end
        local char,hum,root=own()
        if not char or char:GetAttribute("Species")~="KingCobra" then return end
        local info=cobraRange(char)
        if not info then return end
        local fwd=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
        if fwd.Magnitude<.01 then return end
        fwd=fwd.Unit
        local minDot=math.cos(math.rad(math.max(1,info.cone-4)))
        local ownPack=player:GetAttribute("FeralPack")
        C.espActive=true
        for other,record in pairs(state.byPlayer or {}) do
            if other~=player and record and record.char and record.char.Parent
                and record.h and record.h.Parent and record.h.Enabled then
                local model=record.char
                local root2=model:FindFirstChild("HumanoidRootPart")
                local hum2=model:FindFirstChildOfClass("Humanoid")
                local targetPack=model:GetAttribute("FeralPack")
                local friendly=ownPack~=nil and targetPack~=nil and ownPack==targetPack
                if root2 and hum2 and hum2.Health>0 and not friendly
                    and not model:GetAttribute("FeralDead")
                    and not model:GetAttribute("FeralBurrowed") then
                    local displacement=root2.Position-root.Position
                    local flat=Vector3.new(displacement.X,0,displacement.Z)
                    local distance=flat.Magnitude
                    if distance>.05 then
                        -- The native Cobra selector measures horizontal gap
                        -- to the edge of a target's root box, not 3D center distance.
                        local gap=math.max(0,distance-
                            math.max(root2.Size.X,root2.Size.Z)*.5)
                        local inCone=fwd:Dot(flat.Unit)>=minDot
                        local lineClear=unobstructed(char,root2,model)
                        if not inCone or not lineClear then
                            C.espOutOfLockCount+=1
                        elseif info.throw and gap<=info.throw*.90 then
                            record.h.OutlineColor=DIVE_COLOR
                            C.espDiveCount+=1
                        elseif gap<=info.spit*.88 then
                            record.h.OutlineColor=SPIT_COLOR
                            C.espSpitCount+=1
                        else
                            C.espOutOfLockCount+=1
                        end
                    end
                end
            end
        end
        C.espRefreshes+=1
    end

    local function tick()
        if not C.alive or not ctx.state.alive then return end
        local now=os.clock()
        if C.window then
            local w=C.window
            if w.hum and w.hum.Parent and finite(w.hum.Health)
                and w.hum.Health<w.before-.05 then
                C.observedHPDrops+=1
                if w.boostedOnly then
                    C.boostedOnlyHPDrops+=1
                    C.extendedBiteEvidence="TARGET HP DECLINE CORRELATED / CAUSE UNVERIFIED"
                end
                C.window=nil
            elseif now>w.untilAt then
                if w.hum and w.hum.Parent and finite(w.hum.Health) then
                    C.noHpDeclineAfterBite+=1
                end
                C.window=nil
            end
        end
        if now<C.nextScan then return end
        C.nextScan=now+C.scanInterval
        local char,hum,root=own()
        C.cobraShotState="NOT COBRA"
        C.aimLOS="UNKNOWN"
        C.cobraRangeInfo=nil
        C.cobraShotGap=nil
        local preferred=C.target and C.target.model or nil
        C.target=nil
        C.ready=false
        C.nativeReady=false
        C.boostedOnlyReady=false
        C.targetDistance=nil
        C.playerCandidates=0
        C.npcCandidates=0
        if not char then C.status="NO ACTIVE ANIMAL";return end
        if now>=C.nextCollisionAudit then
            C.nextCollisionAudit=now+.45
            collisionAudit(root)
            C.collisionAudits+=1
        end
        if char:GetAttribute("WolfRest")==true then
            C.status="REST ACTIVE / GAME DISALLOWS BITE"
            return
        end
        if ctx.carry and ctx.carry.classify then
            local _,holding=ctx.carry.classify(char)
            if holding then
                -- Game's own WolfController declines ordinary bites when
                -- the hunter's outgoing FeralClamp exists. The guide
                -- does not restrict player input or prematurely drop prey.
                C.status="HOLDING PREY / GAME BITE LIMIT"
                return
            end
        end
        if not C.enabled then
            C.status="GUIDE OFF"
            return
        end
        local best=candidate(char,hum,root,preferred)
        if best and preferred and best.model~=preferred then
            C.targetSwitches+=1
        end
        C.target=best
        if not best then
            C.status="NO TARGET IN REPLICATED RANGE"
            return
        end
        C.targetDistance=best.dist
        C.margin=best.margin
        C.ready=best.valid
        C.nativeReady=best.nativeValid
        C.boostedOnlyReady=best.boostedOnly
        if C.boostedOnlyReady then C.boostedOnlyWindowCount+=1 end
        C.aimAngle=best.angle
        C.aimHeight=best.vertical
        C.aimMaxHeight=best.maxVertical
        C.aimReach=best.reach
        C.aimCone=best.cone
        C.aimLOS=unobstructed(char,best.root,best.model) and "CLEAR" or "BLOCKED"
        if char:GetAttribute("Species")=="KingCobra" then
            C.cobraRangeInfo=cobraRange(char)
            local info=C.cobraRangeInfo
            C.cobraClientRange=info and info.spit or nil
            C.cobraThrowRange=info and info.throw or nil
            C.cobraPickCone=info and info.cone or nil
            C.cobraGrowthFactor=info and info.scale or nil
        else
            C.cobraClientRange=nil
            C.cobraThrowRange=nil
            C.cobraPickCone=nil
            C.cobraGrowthFactor=nil
        end
        C.status=C.aimLOS=="BLOCKED" and "OBSTRUCTED / MOVE FOR CLEAR SHOT"
            or C.boostedOnlyReady and "EXTENDED CLIENT WINDOW / SERVER UNKNOWN"
            or C.ready and "BITE WINDOW OPEN (CLIENT)"
            or "MOVE CLOSER / TURN / ADJUST HEIGHT"
        if C.boostedOnlyReady then C.clientOnlyWarnings+=1 end
        updateGuideAppearance(char,best)
    end
    local baseRefresh
    local recolorRefresh
    function C.setEnabled(v)
        C.enabled=v==true
        if not C.enabled then circle.Visible=false;hint.Visible=false end
        -- Refresh baseline outlines immediately on disable; the game tracker
        -- retains full ownership of standard colour, distance and visibility.
        if ctx.refreshTracker then pcall(ctx.refreshTracker,true) end
    end
    function C.report()
        return table.concat({
            "FERAL NOVA PRIME v15.7 | Cobra Text Detachment + Smooth Bite Helper",
            "enabled="..tostring(C.enabled).." status="..C.status,
            "model="..C.configStatus,
            "candidate_players="..tostring(C.playerCandidates),
            "candidate_npcs="..tostring(C.npcCandidates),
            "client_bite_ready="..tostring(C.ready),
            "baseline_bite_ready="..tostring(C.nativeReady),
            "extended_only_bite_ready="..tostring(C.boostedOnlyReady),
            "boosted_only_window_samples="..tostring(C.boostedOnlyWindowCount),
            "all_mouse1_attack_inputs="..tostring(C.mouseAttempts),
            "mouse1_during_extended_only_window="..tostring(C.extendedMouseAttempts),
            "native_bite_starts_after_extended_mouse1="..tostring(C.nativeBitesAfterExtendedInput),
            "boosted_only_bites_started="..tostring(C.boostedOnlyBites),
            "boosted_only_hp_drops_near_bite="..tostring(C.boostedOnlyHPDrops),
            "extended_bite_evidence="..C.extendedBiteEvidence,
            "bites_started="..tostring(C.bites),
            "bite_observations="..tostring(C.monitored),
            "nearby_hp_drops_after_bites="..tostring(C.observedHPDrops),
            "bite_claim_windows_sampled="..tostring(C.biteClaimWindowsSampled),
            "bite_claim_windows_with_no_observed_hp_drop="..tostring(C.noHpDeclineAfterBite),
            "cobra_large_square_overlay_visible=false",
            "cobra_text_panel_unmounted="..tostring(C.cobraTextUnmounted),
            "cobra_identification="..C.cobraDetection,
            "stale_bite_guide_windows_purged="..C.staleGuideWindowsRemoved,
            "text_panel_parent_transitions="..C.textParentFixes,
            "cobra_compact_bite_dot_preserved=true",
            "visual_render_method="..C.renderMethod,
            "visual_frames_rendered="..tostring(C.smoothFrames),
            "visual_render_errors="..tostring(C.smoothErrors),
            "visual_last_error="..C.guideLastError,
            "target_stabilization_switches="..tostring(C.targetSwitches),
            "visual_marker_snaps="..tostring(C.guideSnapCount),
            "visual_target_offscreen="..tostring(C.reticleOffscreen),
            "target_rescan_interval_seconds="..C.scanInterval,
            "attempted_attacks_while_resting="..tostring(C.blockedRestInputs),
            "attempted_attacks_while_holding="..tostring(C.carryBiteAttempts),
            "client_config_inputs="..C.configValues,
            "aim_angle_degrees="..tostring(C.aimAngle),
            "aim_elevation_studs="..tostring(C.aimHeight),
            "aim_vertical_cap="..tostring(C.aimMaxHeight),
            "aim_effective_reach="..tostring(C.aimReach),
            "aim_half_cone_degrees="..tostring(C.aimCone),
            "aim_line_of_sight="..C.aimLOS,
            "cobra_spit_range_scaled_from_config="..tostring(C.cobraClientRange),
            "cobra_throw_range_scaled="..tostring(C.cobraThrowRange),
            "cobra_pick_cone_degrees="..tostring(C.cobraPickCone),
            "cobra_growth_scale="..tostring(C.cobraGrowthFactor),
            "cobra_target_edge_gap_studs="..tostring(C.cobraShotGap),
            "cobra_safe_spit_gap_factor=.88",
            "cobra_shot_warning="..C.cobraShotState,
            "cobra_esp_active="..tostring(C.espActive),
            "cobra_green_dive_targets="..tostring(C.espDiveCount),
            "cobra_purple_spit_targets="..tostring(C.espSpitCount),
            "cobra_outside_lock_targets="..tostring(C.espOutOfLockCount),
            "cobra_esp_refreshes="..tostring(C.espRefreshes),
            "cobra_esp_errors="..tostring(C.espErrors),
            "offscreen_guide_updates="..tostring(C.shownOffscreen),
            "nearest_root_distance="..tostring(C.closeRootDistance),
            "nearest_root_size_xyz="..C.closeRootSize,
            "nearest_root_can_collide="..C.closeRootCanCollide,
            "nearest_root_collision_group="..C.closeRootGroup,
            "own_root_size_xyz="..C.ownRootSize,
            "read_only_collision_audits="..tostring(C.collisionAudits),
            "old_v7_v8_gui_present="..tostring(C.oldHitboxGuiVisible),
            "ray_obstruction_category="..C.rayBlockCategory,
            "ray_obstruction_collidable="..C.rayBlockCollidable,
            "physical_part_edits_by_v10="..tostring(C.physicalEdits),
            "NOTE=v10 never changes root part size/collision; lingering v7/v8 changes require a fresh join.",
            "NOTE=Bite guidance and HP correlations do not prove server damage."
        },"\n")
    end
    function C.close()
        C.alive=false
        hint:Destroy()
        pcall(function()
            RunService:UnbindFromRenderStep("FERAL_NOVA_BITE_SMOOTH_V156")
        end)
        if C.renderConnection then C.renderConnection:Disconnect()end
        if C.connection then C.connection:Disconnect()end
        if biteConnection then biteConnection:Disconnect()end
        for _,cn in ipairs(conns) do cn:Disconnect()end
        if gui then gui:Destroy()end
    end
    C.connection=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            C.lastError=tostring(err)
            C.status="GUIDE ERROR"
            C.target=nil
        end
    end)
    local function protectedDraw(dt)
        local ok,err=pcall(drawGuide,dt)
        if not ok then
            C.smoothErrors+=1
            C.guideLastError=tostring(err):sub(1,160)
            circle.Visible=false;hint.Visible=false
        end
    end
    -- In case a previous interrupted hub left the named callback behind,
    -- clear only the previous bite-helper render binding before attaching.
    pcall(function()
        RunService:UnbindFromRenderStep("FERAL_NOVA_BITE_SMOOTH_V156")
    end)
    local okRender=pcall(function()
        RunService:BindToRenderStep("FERAL_NOVA_BITE_SMOOTH_V156",
            Enum.RenderPriority.Camera.Value+1,protectedDraw)
    end)
    if okRender then
        C.renderMethod="RENDER_STEP_AFTER_CAMERA"
    else
        C.renderMethod="RENDER_STEPPED_FALLBACK"
        C.renderConnection=RunService.RenderStepped:Connect(protectedDraw)
    end
    -- Core refreshTracker repaints every record with default range colours;
    -- this wrapper is called after it, and remains compatible with the UI's
    -- later name-tag wrapper (which calls our wrapper as its base).
    baseRefresh=ctx.refreshTracker
    recolorRefresh=function(force)
        local result=baseRefresh(force)
        if C.alive then
            local ok,err=pcall(recolorCobraESP)
            if not ok then
                C.espErrors+=1
                C.lastError=tostring(err)
            end
        end
        return result
    end
    ctx.refreshTracker=recolorRefresh
    return C
end
return Combat
]==========],
["feral-nova-recovery-compat-v11.2.lua"]=[==========[
-- FERAL NOVA v11.2 / retired legacy Safe Rest implementation.
-- Compatibility API only. No events, Heartbeat, attributes or Rest remotes.
-- Automatic Rest has exactly one owner: feral-nova-native-recovery-v11.0.
local Recovery={}
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local function finite(n)
    return type(n)=="number" and n==n and n>=0 and n<1e9
end
function Recovery.shellState(species,rest,restAt,serverNow)
    if type(species)~="string" or not string.find(species,"SnappingTurtle",1,true) then
        return "NOT TURTLE",1
    end
    if rest~=true then return "SHELL INACTIVE",1 end
    if not finite(restAt) or not finite(serverNow) then
        return "REST OBSERVED / TIMER UNAVAILABLE",1
    end
    if serverNow-restAt<1 then return "SHELL ARMING",1 end
    return "SHELL RULE CONDITION / SERVER UNVERIFIED",.30
end
function Recovery.attach(ctx)
    local M={
        alive=true,enabled=false,legacyRetired=true,
        status="RETIRED / UNIFIED NATIVE RECOVERY OWNS REST",
        shell="UNKNOWN",multiplier=1,restOwned=nil,restActive=false,
        attempts=0,requests=0,cancels=0
    }
    function M.snapshot()
        local char=player.Character
        if not char or not char.Parent then
            M.shell="NO ANIMAL";M.multiplier=1
            return M.shell,M.multiplier
        end
        local species=char:GetAttribute("Species")
        local active=char:GetAttribute("WolfRest")==true
        local start=char:GetAttribute("WolfRestAt")
        local ok,serverNow=pcall(function()return workspace:GetServerTimeNow()end)
        M.shell,M.multiplier=Recovery.shellState(species,active,start,ok and serverNow or nil)
        return M.shell,M.multiplier
    end
    function M.beforeCarry() return false end
    function M.setEnabled(v)
        -- A stale UI or older module cannot re-enable a second Rest writer.
        M.enabled=false
        M.status="RETIRED / USE ACTIVE RECOVERY"
        return false
    end
    function M.report()
        M.snapshot()
        return table.concat({
            "FERAL NOVA v11.2 | Safe Rest compatibility only",
            "legacy_retired=true","automatic_rest_requests=0",
            "event_connections=0","heartbeat_connections=0",
            "enabled=false","status="..M.status,
            "turtle_shell_observation="..M.shell,
            "client_shell_multiplier="..tostring(M.multiplier),
            "NOTE=Actual Turtle damage reduction is game-server controlled.",
            "NOTE=Native recovery is the only hub Rest request owner."
        },"\n")
    end
    function M.close()
        M.enabled=false
        M.alive=false
    end
    return M
end
return Recovery
]==========],
["feral-nova-mobile-compat-v11.2.lua"]=[==========[
-- FERAL NOVA v11.2 / retired mobile A/B Rest experiment.
-- Compatibility API only; the active native controller owns moving recovery.
local Mobile={}
function Mobile.attach(ctx)
    local M={
        alive=true,enabled=false,active=false,legacyRetired=true,
        status="RETIRED / MOVING RECOVERY CONSOLIDATED",
        result="UNAVAILABLE / EXTERNAL SERVER VERIFICATION REQUIRED",
        restOwned=false,attempts=0,signals=0
    }
    function M.beforeCarry() return false end
    function M.setEnabled(v)
        M.enabled=false
        M.active=false
        return false
    end
    function M.report()
        return table.concat({
            "FERAL NOVA v11.2 | Mobile Rest experiment retired",
            "legacy_retired=true","enabled=false","active=false",
            "heartbeat_connections=0","input_connections=0",
            "native_rest_requests=0","result="..M.result,
            "NOTE=No second mobile Rest controller can interfere with user actions."
        },"\n")
    end
    function M.close()
        M.enabled=false
        M.active=false
        M.alive=false
    end
    return M
end
return Mobile
]==========],
["feral-nova-carry-core-v11.3.lua"]=[==========[
-- FERAL NOVA v11.3.1 / carry requests scoped to original animal and final action state
-- FeralCarryClient uses G and sets _G.FeralCarryCan / _G.FeralCarryPress.
-- Predator holding prey: own FeralClamp ObjectValue with Carry or Value.
-- Carcass holding: own FeralCarcassCarry attribute.
-- Victim: own FeralCarried/FeralPinned/FeralDragged attributes.
-- Never sends fabricated pickup/drop remotes or changes physics.
local Carry={}
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer

function Carry.classify(char)
    if not char or not char.Parent then
        return "NO ANIMAL",false,false
    end
    if char:GetAttribute("FeralCarried")==true then
        return "BEING CARRIED",false,true
    end
    if char:GetAttribute("FeralPinned")==true then
        return "PINNED BY ENEMY",false,true
    end
    if char:GetAttribute("FeralDragged")==true then
        return "BEING DRAGGED",false,true
    end
    local clamp=char:FindFirstChild("FeralClamp")
    if clamp and clamp:IsA("ObjectValue") then
        local carried=clamp:GetAttribute("Carry")==true
        local hasTarget=clamp.Value and clamp.Value.Parent~=nil
        if carried then return "HOLDING PREY",true,false end
        if hasTarget then return "GRAPPLING PREY",true,false end
    end
    if char:GetAttribute("FeralCarcassCarry")==true then
        return "HOLDING CARCASS",true,false
    end
    local localClamp=char:FindFirstChild("FeralClampLocal")
    if localClamp and localClamp:IsA("ObjectValue")
        and localClamp.Value and localClamp.Value.Parent then
        return "LOCAL GRAPPLE",true,false
    end
    return "FREE",false,false
end

function Carry.attach(ctx)
    local C={
        classify=Carry.classify,
        alive=true,enabled=true,status="WAITING FOR ANIMAL",
        state="NO ANIMAL",holding=false,victim=false,
        canInteract=false,action="G",helper="UNAVAILABLE",
        method="NONE",attempts=0,helperCalls=0,keyboardTaps=0,
        blocked=0,preemptedRest=0,lastError="",lastAt=-math.huge,
        nextRefresh=0,refreshes=0,
        lastInputAt=-math.huge,lastState="NO ANIMAL",
        changes=0,holdingEpisodes=0,victimEpisodes=0,
        deferredCharacterDrops=0,deferredCaptureBlocks=0
    }
    local env
    if type(getgenv)=="function" then
        local ok,result=pcall(getgenv)
        if ok and type(result)=="table" then env=result end
    end
    local kp=(type(keypress)=="function" and keypress)
        or env and type(env.keypress)=="function" and env.keypress
    local kr=(type(keyrelease)=="function" and keyrelease)
        or env and type(env.keyrelease)=="function" and env.keyrelease
    local press,release
    if type(kp)=="function" and type(kr)=="function" then
        press=function()kp(0x47)end
        release=function()kr(0x47)end
        C.method="EXECUTOR G"
    else
        local ok,vim=pcall(function()return game:GetService("VirtualInputManager")end)
        if ok and vim then
            press=function()vim:SendKeyEvent(true,Enum.KeyCode.G,false,game)end
            release=function()vim:SendKeyEvent(false,Enum.KeyCode.G,false,game)end
            C.method="VIRTUAL G"
        end
    end
    local connections={}
    local currentToken=0
    local function native()
        local fn=type(_G)=="table" and _G.FeralCarryPress or nil
        local can=type(_G)=="table" and _G.FeralCarryCan or nil
        if type(fn)=="function" then
            local ok,allowed=pcall(function()
                return type(can)~="function" or can()==true
            end)
            C.helper="GAME CARRY HELPER"
            return fn,ok and allowed
        end
        C.helper="G KEY FALLBACK"
        return nil,false
    end
    local function releaseForCarry()
        local preempt=false
        if ctx.mobile and ctx.mobile.beforeCarry then
            local ok,done=pcall(ctx.mobile.beforeCarry)
            if ok and done then preempt=true end
        end
        if ctx.native and ctx.native.beforeCarry then
            local ok,done=pcall(ctx.native.beforeCarry)
            if ok and done then preempt=true end
        end
        if ctx.recovery and ctx.recovery.beforeCarry then
            local ok,done=pcall(ctx.recovery.beforeCarry)
            if ok and done then preempt=true end
        end
        if ctx.flight and ctx.flight.beforeCarry then
            -- Native G must always undo a temporary local drag mode first.
            pcall(ctx.flight.beforeCarry)
        end
        if preempt then C.preemptedRest+=1 end
        return preempt
    end

    local function refresh()
        local char=player.Character
        local state,holding,victim=Carry.classify(char)
        if state~=C.lastState then
            C.changes+=1
            if holding then C.holdingEpisodes+=1 end
            if victim then C.victimEpisodes+=1 end
            C.lastState=state
        end
        C.state=state
        C.holding=holding
        C.victim=victim
        local fn,can=native()
        local nativeAvailable=type(fn)=="function" and (can or holding)
        C.canInteract=(nativeAvailable or type(press)=="function") and
            not victim and state~="NO ANIMAL"
        C.action=holding and "DROP / RELEASE"
            or victim and "ESCAPE FIRST"
            or can and "PICK UP / CARRY"
            or type(press)=="function" and "TRY G"
            or "USE G"
        C.status=victim and "ESCAPE PRIORITY"
            or holding and ("CARRY PRESERVED: "..state)
            or state=="NO ANIMAL" and "WAITING FOR ANIMAL"
            or can and "NATIVE CARRY READY"
            or "CARRY VIA G WHEN AVAILABLE"
    end
    function C.beforeCarry()
        return releaseForCarry()
    end
    local function mayCarry()
        if ctx.action and type(ctx.action.allowed)=="function" then
            local ok,allowed,reason=pcall(ctx.action.allowed,"carry")
            if not ok then return false,"ACTION CORE ERROR" end
            return allowed,reason
        end
        return true,"NO ACTION CORE"
    end
    function C.press()
        if not C.alive then return false end
        local safe,why=mayCarry()
        if not safe then
            C.blocked+=1
            C.lastError="Carry action priority: "..tostring(why)
            C.status="CARRY INPUT BLOCKED / "..tostring(why)
            return false
        end
        refresh()
        local now=os.clock()
        if now-C.lastAt<.39 then
            C.blocked+=1
            C.lastError="Carry action cooldown (.39 sec)"
            return false
        end
        if UIS:GetFocusedTextBox() or player:GetAttribute("FeralMenuOpen")==true
            or C.victim or not player.Character then
            C.blocked+=1
            C.lastError="Carry unavailable while chatting, in menu or captured"
            return false
        end
        C.lastAt=now
        C.lastInputAt=now  -- Suppress speculative victim shake during G transition.
        C.attempts+=1
        local preempted=releaseForCarry()
        local token=currentToken+1
        currentToken=token
        local intendedCharacter=player.Character
        -- Give the game's own Rest=false time before native carry G.
        -- Never duplicate a native G action. Manual G is left untouched.
        local function invoke()
            if not C.alive or currentToken~=token then return end
            if not intendedCharacter or player.Character~=intendedCharacter
                or not intendedCharacter.Parent then
                C.deferredCharacterDrops+=1
                C.status="DEFERRED CARRY CANCELLED / ANIMAL CHANGED"
                return
            end
            if UIS:GetFocusedTextBox()
                or player:GetAttribute("FeralMenuOpen")==true then return end
            local state,_,victim=Carry.classify(intendedCharacter)
            if victim then
                C.deferredCaptureBlocks+=1
                C.status="DEFERRED CARRY CANCELLED / CAPTURED"
                return
            end
            local safe,why=mayCarry()
            if not safe then
                C.blocked+=1
                C.status="DEFERRED CARRY CANCELLED / "..tostring(why)
                return
            end
            local fn,can=native()
            -- A native helper may report pickup as ineligible while
            -- *already holding prey*. Let the game-owned helper handle
            -- its drop/release branch rather than forcing key injection.
            if fn and (can or C.holding) then
                local ok,err=pcall(fn)
                if ok then
                    C.helperCalls+=1
                    C.lastError=""
                    C.status="NATIVE CARRY ACTION REQUESTED"
                else
                    C.lastError=tostring(err)
                end
                return
            end
            if not press or not release then
                C.lastError="Game helper not accessible; use native G key"
                C.status="PRESS G IN GAME"
                return
            end
            local ok,err=pcall(press)
            if not ok then
                C.lastError=tostring(err)
                return
            end
            C.keyboardTaps+=1
            task.delay(.045,function()
                pcall(release)
            end)
            C.status="NATIVE G INPUT ATTEMPTED"
        end
        if preempted then task.delay(.17,invoke) else invoke() end
        return true
    end
    function C.report()
        return table.concat({
            "FERAL NOVA PRIME v15 | Native Carry",
            "state="..C.state,
            "holding_prey_or_carcass="..tostring(C.holding),
            "captured_by_enemy="..tostring(C.victim),
            "native_action="..C.action,
            "helper="..C.helper,
            "input_method="..C.method,
            "native_helper_calls="..tostring(C.helperCalls),
            "G_taps="..tostring(C.keyboardTaps),
            "native_g_fallback_available="..tostring(type(press)=="function"),
            "carry_action_confirmed_by_server=UNVERIFIED",
            "button_requests="..tostring(C.attempts),
            "carry_capability_polls="..tostring(C.refreshes),
            "rest_interference_preemptions="..tostring(C.preemptedRest),
            "carry_transitions="..tostring(C.changes),
            "holding_episodes="..tostring(C.holdingEpisodes),
            "captured_episodes="..tostring(C.victimEpisodes),
            "blocked_interactions="..tostring(C.blocked),
            "deferred_actions_cancelled_on_respawn="..tostring(C.deferredCharacterDrops),
            "deferred_actions_cancelled_on_capture="..tostring(C.deferredCaptureBlocks),
            "last_error="..C.lastError,
            "NOTE=Native G/carry helper is game-controlled. Requests are not proof of pickup.",
            "NOTE=v9 Grab V2 timing has priority over hub-initiated G carry.",
            "NOTE=Manual G remains native; coordinator checks only our hub button."
        },"\n")
    end
    function C.close()
        if not C.alive then return end
        C.alive=false
        currentToken+=1
        if C.connection then C.connection:Disconnect()end
        for _,cn in ipairs(connections) do
            pcall(function()cn:Disconnect()end)
        end
    end
    connections[#connections+1]=UIS.InputBegan:Connect(function(input,processed)
        if processed or UIS:GetFocusedTextBox() then return end
        if input.KeyCode==Enum.KeyCode.G then
            C.lastInputAt=os.clock()
            C.nextRefresh=0
            -- Only withdraw an OWNED experimental Rest signal; never
            -- intercept, sink, or fire additional native carry actions.
            releaseForCarry()
        end
    end)
    C.connection=RunService.Heartbeat:Connect(function()
        if not C.alive then return end
        local now=os.clock()
        if now<C.nextRefresh then return end
        C.nextRefresh=now+.13 -- Native FeralCarryCan may perform expensive work.
        local ok,err=pcall(refresh)
        if ok then C.refreshes+=1
        else C.lastError=tostring(err) end
    end)
    return C
end
return Carry
]==========],
["feral-nova-reach-v14.0.lua"]=[==========[
-- FERAL NOVA PRIME v14.1 / Conservative enhanced bite reach, rear arc and elevation.
-- Changes only the shared client CombatConfig bite selection math.
-- Enemy Part.Size / CanCollide / CollisionGroup are NEVER touched.
-- Native WolfController handles Bite and BiteHit on its original schedule.
local Reach={}
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local function good(n)return type(n)=="number" and n==n and math.abs(n)<1e7 end
local function cfgNow()
    local folder=RS:FindFirstChild("FeralWorld")
    local inst=folder and folder:FindFirstChild("CombatConfig")
    if not inst or not inst:IsA("ModuleScript") then return nil,"CombatConfig module absent" end
    local ok,t=pcall(require,inst)
    if not ok or type(t)~="table" then return nil,"CombatConfig require failed" end
    for _,k in ipairs({"REACH","HIT_SCALE","CONE","SLACK","MAX_DY"}) do
        if not good(t[k]) then return nil,"CombatConfig missing "..k end
    end
    if type(t.bodyGap)~="function" then
        return nil,"CombatConfig bodyGap missing"
    end
    return t,nil
end
local function snapshot(t)
    return {REACH=t.REACH,HIT_SCALE=t.HIT_SCALE,
        CONE=t.CONE,SLACK=t.SLACK,MAX_DY=t.MAX_DY,
        bodyGap=t.bodyGap,reachMult=t.reachMult,
        coneFor=t.coneFor,dyMult=t.dyMult}
end
local function vecFlat(v)
    return Vector3.new(v.X,0,v.Z)
end
local function ownedCompare(patch)
    for _,e in ipairs(patch or {}) do
        if e.table[e.key]~=e.wanted then return false end
    end
    return patch and #patch>0
end
function Reach.geometry(values, ownRoot,ownHum,enemyRoot,enemyHum,character)
    if not values or not ownRoot or not enemyRoot
        or not ownHum or not enemyHum then return nil end
    local diff=enemyRoot.Position-ownRoot.Position
    local flat=vecFlat(diff)
    local fwd=vecFlat(ownRoot.CFrame.LookVector)
    if fwd.Magnitude<.01 then return nil end
    fwd=fwd.Unit
    local angle=flat.Magnitude>.01 and fwd:Dot(flat.Unit) or 1
    local ok,gap=pcall(values.bodyGap,enemyRoot,flat)
    if not ok or not good(gap) then return nil end
    local reachMult=1
    if type(values.reachMult)=="function" then
        local b,v=pcall(values.reachMult,character)
        if b and good(v) then reachMult=v end
    end
    local cone=values.CONE
    if type(values.coneFor)=="function" then
        local b,v=pcall(values.coneFor,character)
        if b and good(v) then cone=v end
    end
    local dyMult=1
    if type(values.dyMult)=="function" then
        local b,v=pcall(values.dyMult,character)
        if b and good(v) then dyMult=v end
    end
    local box=ownRoot:GetAttribute("FeralBoxFull")
    if not good(box) or box<=0 then box=ownRoot.Size.Z end
    local reach=(box*.5+ownHum.HipHeight*values.REACH+values.SLACK)
        *values.HIT_SCALE*reachMult
    local vertical=math.abs(diff.Y)
    local maxVertical=(ownHum.HipHeight+enemyHum.HipHeight)*values.MAX_DY*dyMult
    local maxAngle=math.cos(math.rad(cone))
    local distanceOK=gap<reach
    local facingOK=angle>maxAngle
    local heightOK=vertical<maxVertical
    local valid=distanceOK and facingOK and heightOK
    return {valid=valid,gap=gap,reach=reach,angle=angle,
        angleDegrees=math.deg(math.acos(math.clamp(angle,-1,1))),
        coneDegrees=cone,vertical=vertical,maxVertical=maxVertical,
        distanceOK=distanceOK,facingOK=facingOK,heightOK=heightOK,
        distance=flat.Magnitude,margin=reach-gap}
end
function Reach.attach(ctx)
    local C={
        enabled=false,applied=false,alive=true,mode="OFF",
        status="OFF",lastError="",installCount=0,
        externalChanges=0,reverts=0,
        lease=nil,original=nil,table=nil,claimedWindows=0,
        baselineDistance=0,boostDistance=0,benefit="SERVER UNVERIFIED",
        nextTick=0
    }
    local function restore()
        if not C.lease then return end
        for i=#C.lease,1,-1 do
            local e=C.lease[i]
            pcall(function()
                if e.table[e.key]==e.wanted then
                    e.table[e.key]=e.original
                    C.reverts+=1
                else
                    C.externalChanges+=1
                end
            end)
        end
        C.lease=nil;C.applied=false
        C.table=nil
    end
    function C.setEnabled(v)
        if v==false then
            C.enabled=false;restore()
            C.status="OFF / ORIGINAL CLAIM GEOMETRY RESTORED"
            C.mode="OFF"
            return false
        end
        C.enabled=true
        if C.applied and ownedCompare(C.lease) then
            return true
        end
        if C.applied then
            restore()
            C.enabled=false
            C.status="EXTERNAL COMBAT CONFIG CHANGED / BOOST DISABLED"
            C.lastError="Another script changed the configured claim geometry"
            return false
        end
        local t,err=cfgNow()
        if not t then
            C.status="WAITING / "..tostring(err)
            C.lastError=tostring(err)
            return false
        end
        local original=snapshot(t)
        -- Modest additional distance over v14, but a deliberate rear-side
        -- angle and elevation window. Client-only: server validation applies.
        local desired={
            REACH=math.min(original.REACH*1.27,2.82),
            HIT_SCALE=math.min(original.HIT_SCALE*1.24,2.0),
            CONE=math.min(original.CONE+48,124),
            SLACK=original.SLACK+.45,
            MAX_DY=math.min(original.MAX_DY*1.35,4.0),
        }
        -- Only client claim geometry; real character/enemy parts unchanged.
        desired.bodyGap=function(part,flat)
            local gap=original.bodyGap(part,flat)
            if not good(gap) then return gap end
            return gap-.84
        end
        local lease={}
        for _,key in ipairs({"REACH","HIT_SCALE","CONE","SLACK","MAX_DY","bodyGap"}) do
            local before=t[key]
            local wanted=desired[key]
            if before~=wanted then
                local ok=pcall(function()t[key]=wanted end)
                if not ok or t[key]~=wanted then
                    for i=#lease,1,-1 do
                        local e=lease[i]
                        if e.table[e.key]==e.wanted then
                            pcall(function()e.table[e.key]=e.original end)
                        end
                    end
                    C.status="CLAIM CONFIG WRITE FAILED / ORIGINAL RESTORED"
                    C.lastError="CombatConfig rejected "..key
                    C.enabled=false
                    return false
                end
                lease[#lease+1]={table=t,key=key,
                    original=before,wanted=wanted}
            end
        end
        C.lease=lease
        C.original=original
        C.table=t
        C.applied=true
        C.mode="VIRTUAL REACH + REAR ARC + ELEVATION (NO PHYSICS)"
        C.status="INCREASED CLIENT BITE CLAIM WINDOW"
        C.installCount+=1
        C.lastError=""
        return true
    end
    function C.compare(char,ownRoot,ownHum,enemyRoot,enemyHum)
        local native=C.original or C.table and snapshot(C.table)
        if not native then
            local t=cfgNow()
            if not t then return nil,nil end
            native=snapshot(t)
        end
        local base=Reach.geometry(native,ownRoot,ownHum,enemyRoot,enemyHum,char)
        local applied=C.applied and C.table or nil
        local boosted=applied and Reach.geometry(snapshot(applied),
            ownRoot,ownHum,enemyRoot,enemyHum,char) or base
        return base,boosted
    end
    function C.report()
        local native=C.original
        local t=C.table
        return table.concat({
            "FERAL NOVA PRIME v14.1 | Bite Reach / Rear Arc / Elevated Targets",
            "enabled="..tostring(C.enabled).." applied="..tostring(C.applied),
            "mode="..C.mode,
            "status="..C.status,
            "original_reach="..tostring(native and native.REACH),
            "client_reach="..tostring(t and t.REACH),
            "original_hit_scale="..tostring(native and native.HIT_SCALE),
            "client_hit_scale="..tostring(t and t.HIT_SCALE),
            "original_cone="..tostring(native and native.CONE),
            "client_cone="..tostring(t and t.CONE),
            "virtual_body_gap_bonus_studs="..(C.applied and "0.84" or "0"),
            "client_max_dy="..tostring(t and t.MAX_DY),
            "rear_half_arc_degrees="..tostring(t and t.CONE),
            "physical_enemy_parts_resized=0",
            "install_count="..C.installCount,
            "restored_fields="..C.reverts,
            "external_config_conflicts="..C.externalChanges,
            "server_damage_acceptance="..C.benefit,
            "last_error="..C.lastError,
            "NOTE=Claim geometry and virtual hitbox are local to the game's client.",
            "NOTE=Server may reject extended range; use the bite observations report."
        },"\n")
    end
    function C.close()
        if not C.alive then return end
        C.alive=false
        C.setEnabled(false)
        if C.connection then C.connection:Disconnect()end
    end
    C.connection=RunService.Heartbeat:Connect(function()
        if not C.alive or not ctx.state.alive then return end
        local now=os.clock()
        if now<C.nextTick then return end
        C.nextTick=now+1.25
        if C.enabled then
            -- Auto-install if loaded in the menu before FeralWorld exists.
            local ok,err=pcall(C.setEnabled,true)
            if not ok then
                C.lastError=tostring(err)
                C.status="CLAIM CONFIG ERROR"
                C.enabled=false
            end
        end
    end)
    return C
end
return Reach
]==========],
["feral-nova-regen-v11.0.lua"]=[==========[
-- FERAL NOVA v11.0 / non-rest configuration without unverified 4x claims
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
        restMultipliersReady=false,statusFieldsApplied=0,
        attempts=0,applies=0,reverts=0,conflicts=0,
        nextTick=0,lastCharacter=nil,lastSample=nil,lastTime=0,
        lastRest=false,restExclusionSeconds=0,nativeSignalExcludedSeconds=0,
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
        R.restMultipliersReady=false
        R.statusFieldsApplied=0
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
        -- Preserve the game's combat exclusion. The prior version changed
        -- HEALTH_NO_REGEN_IN_COMBAT to false, contrary to user intent.
        -- This module must never permit recovery during combat by editing it.
        local combatOK=type(needs.HEALTH_NO_REGEN_IN_COMBAT)=="boolean"
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
        local readyRest=0
        local missing={}
        for _,e in ipairs(statusKeys) do
            local block=cfg and cfg[e.name]
            if type(block)=="table" and finite(block[e.field])
                and block[e.field]>0 then
                local source=block[e.field]
                local target=math.min(source*4,10000)
                if set(block,e.field,target,lease) then
                    applied+=1
                    -- Native Rest already uses REST_MULT=4 in the exported
                    -- FERAL client StatusConfig. Keep that rule at least 4
                    -- locally; do not inflate it to 16 or fabricate effect changes.
                    if finite(block.REST_MULT) and block.REST_MULT>=4 then
                        readyRest+=1
                    elseif finite(block.REST_MULT)
                        and set(block,"REST_MULT",4,lease) then
                        readyRest+=1
                    end
                else missing[#missing+1]=e.name end
            else
                missing[#missing+1]=e.name
            end
        end
        R.statusApplied=applied==#statusKeys
        R.statusFieldsApplied=applied
        R.restMultipliersReady=readyRest==#statusKeys
        R.status=R.statusApplied and R.restMultipliersReady
            and "CLIENT CONFIG PRESENT / REAL 4x STATUS UNVERIFIED"
            or "CLIENT HEALTH CONFIG ACTIVE / STATUS PARTIAL"
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
            if finite(x) and x>.20 and (finite(y) or y==nil) then
                local after=finite(y) and y or 0
                if after<=x+.01 then
                    selected.statusSeconds[e.attr]=(selected.statusSeconds[e.attr] or 0)+elapsed
                    if after<x-.005 then
                        selected.status[e.attr]=(selected.status[e.attr] or 0)+(x-after)
                        selected.statusSamples[e.attr]=(selected.statusSamples[e.attr] or 0)+1
                    end
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
            if ctx.native and ctx.native.active then
                -- Old v1.3 pose mask reports WolfRest=false even while
                -- sending native Rest(true); never falsely label the
                -- healing as pure non-Rest regeneration.
                R.nativeSignalExcludedSeconds+=now-R.lastTime
            elseif current.rest or R.lastSample.rest then
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
            "FERAL NOVA PRIME v15 | Non-Rest Config / Clean Live Rates",
            "enabled="..tostring(R.enabled),
            "client_config_applied="..tostring(R.applied),
            "client_health_inputs_applied="..tostring(R.needsApplied),
            "client_status_inputs_applied="..tostring(R.statusApplied),
            "status_fields_applied="..tostring(R.statusFieldsApplied).."/3",
            "native_rest_status_multiplier_config_ready="..tostring(R.restMultipliersReady),
            "real_server_4x_status_recovery_verified=false",
            "status="..R.status,
            "health_regen_config_baseline="..tostring(R.baselineExpected),
            "health_combat_exclusion_client_flag=GAME_ORIGINAL_UNMODIFIED",
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
            "native_masked_rest_signal_excluded_seconds="..fmt(R.nativeSignalExcludedSeconds),
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
        parts[#parts+1]="NOTE=Game-exported status REST_MULT was 4 already; local 4x inputs may be ignored by server."
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
]==========],
["feral-nova-flight-v11.3.lua"]=[==========[
-- FERAL NOVA v11.3 / action-safe native surface flight and underwater exit
-- Uses the game's own FlightController waterTop method (terrain-water raycast).
-- Temporarily permits takeoff only while FLOATING at the surface, not submerged.
-- When native flight is detected underwater, requests native FeralFlyDrop.
-- Does NOT teleport or modify other characters or fabricate server remotes.
local Flight={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer

local function canFly(char,cfg)
    if not char or type(cfg)~="table" or type(cfg.canFly)~="function" then
        return false
    end
    local ok,allowed=pcall(cfg.canFly,char)
    return ok and allowed==true
end
local function flightConfig()
    local folder=RS:FindFirstChild("FeralWorld")
    local mod=folder and folder:FindFirstChild("FlightConfig")
    if not mod or not mod:IsA("ModuleScript") then
        return nil,"FlightConfig not replicated"
    end
    local ok,cfg=pcall(require,mod)
    if not ok or type(cfg)~="table" or type(cfg.WATER)~="table" then
        return nil,"FlightConfig.WATER unavailable"
    end
    if type(cfg.WATER.NO_TAKEOFF)~="boolean"
        or type(cfg.WATER.GRACE)~="number" then
        return nil,"Unexpected WATER config"
    end
    return cfg,nil
end
local waterRay=RaycastParams.new()
waterRay.FilterType=Enum.RaycastFilterType.Include
waterRay.FilterDescendantsInstances={workspace.Terrain}
waterRay.IgnoreWater=false

-- Equivalent approach to FERAL WolfController's waterTop, not a fixed ocean height.
-- Supports water surfaces at different elevations. Returns nil if unconfirmed.
local function waterTop(position,body)
    local y=position.Y+40
    for attempt=1,2 do
        local origin=Vector3.new(position.X,y,position.Z)
        local cast=Vector3.new(0,-(y-position.Y+body*2),0)
        local ok,hit=pcall(function()return workspace:Raycast(origin,cast,waterRay)end)
        if not ok or not hit then return nil end
        if hit.Material==Enum.Material.Water then return hit.Position.Y end
        if hit.Position.Y<=position.Y then return nil end
        y=hit.Position.Y-.3
    end
    return nil
end

local function isWater(char,hum)
    if not char or not hum then return false end
    if char:GetAttribute("FeralSwimLocal")==true then return true end
    local ok,state=pcall(function()return hum:GetState()end)
    if ok and state==Enum.HumanoidStateType.Swimming then return true end
    local okMat,mat=pcall(function()return hum.FloorMaterial end)
    return okMat and mat==Enum.Material.Water or false
end

function Flight.attach(ctx)
    local F={
        alive=true,enabled=false,applied=false,
        status="OFF",lastError="",config=nil,lease=nil,
        clampLease=nil,eligible=false,water=false,airborne=false,
        holding=false,attempts=0,observedTakeoffs=0,
        waterCarryTakeoffs=0,flyWithPreySeconds=0,
        airCarrySessions=0,restores=0,conflicts=0,
        takeoffPendingUntil=0,nextAttempt=0,nextTick=0,
        blocked=0,waterTime=0,flightTime=0,
        surfaceEligible=false,underwater=false,depth=nil,
        surfaceRequests=0,submergedTakeoffBlocks=0,underwaterFlightExits=0,
        waterFlightOverlapSamples=0,lastSurfaceY=nil,nextDrop=0,
        underwaterExitConfirmed=0,underwaterExitUnconfirmed=0,
        lastNativeDropAt=-math.huge,awaitingDropUntil=0,dropUnconfirmed=false,
        ownedDropChar=nil,waterFlightSeconds=0,
        lastRequestAt=0,lastAirborne=false,lastOwner=nil,
        lastTakeoffCarry=false,serverCarryRetained="NOT VERIFIED",
        midairPreyProtects=0,characterConnections={},
        actionPriorityBlocks=0,actionPolicyErrors=0,
    }
    local listeners={}
    local function restoreClamp()
        local l=F.clampLease
        F.clampLease=nil
        if not l then return end
        pcall(function()
            if l.clamp.Parent and l.clamp:GetAttribute("Mode")=="drag" then
                l.clamp:SetAttribute("Mode",l.original)
                F.restores+=1
            else
                F.conflicts+=1
            end
        end)
    end
    local function restoreWater()
        local lease=F.lease
        F.lease=nil
        if not lease then return end
        for i=#lease,1,-1 do
            local e=lease[i]
            pcall(function()
                if e.parent[e.key]==e.wanted then
                    e.parent[e.key]=e.original
                    F.restores+=1
                else
                    F.conflicts+=1
                end
            end)
        end
    end
    local function setLocal(tbl,key,value,lease)
        if type(tbl)~="table" then return false end
        local old=tbl[key]
        if old==nil then return false end
        if old~=value then
            local ok=pcall(function()tbl[key]=value end)
            if not ok or tbl[key]~=value then return false end
            lease[#lease+1]={parent=tbl,key=key,
                original=old,wanted=value}
        end
        return true
    end
    local function apply()
        if F.applied then return true end
        local cfg,why=flightConfig()
        if not cfg then
            F.status="WATER CONFIG WAITING"
            F.lastError=why
            return false
        end
        -- Critical: WATER.NO_TAKEOFF and WATER.GRACE are NOT altered globally.
        -- An unlock lease is acquired only for a verified surface takeoff.
        F.config=cfg
        F.applied=true
        F.lastError=""
        F.status="NATIVE SURFACE TAKEOFF GUARD READY"
        return true
    end
    local function own()
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not char.Parent or not hum or hum.Health<=0 then
            return nil,nil
        end
        return char,hum
    end
    local function waterState(char,hum)
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local swimming=isWater(char,hum)
        -- "FeralDiving" can also mean an aerial dive, not water submersion.
        -- Only treat it as underwater when the game also reports swimming.
        local underwater=char and (char:GetAttribute("FeralUnderwater")==true
            or (swimming and char:GetAttribute("FeralDiving")==true)) or false
        if not root or not hum then return false,underwater,nil,nil end
        local body=math.max(hum.HipHeight+root.Size.Y/2,.2)
        local top=waterTop(root.Position,body)
        local depth=top and top-root.Position.Y or nil
        -- Swimming birds normally have the root slightly below the surface.
        -- A deeply submerged root is not a valid floating takeoff position.
        if depth and depth>math.max(1.6,body*1.20) then underwater=true end
        local surface=swimming and top~=nil and not underwater
            and depth>=-math.max(1.6,body*1.25)
            and depth<=math.max(1.6,body*1.20)
        return surface==true,underwater,depth,top
    end

    local function outgoingClamp(char)
        local clamp=char and char:FindFirstChild("FeralClamp")
        if not clamp or not clamp:IsA("ObjectValue") then
            return nil
        end
        if clamp:GetAttribute("Carry")==true or
            (clamp.Value and clamp.Value.Parent) then
            return clamp
        end
        return nil
    end
    local function prepAirCarry(char,now)
        local clamp=outgoingClamp(char)
        if not clamp then return false end
        if F.clampLease and F.clampLease.clamp==clamp then
            return true
        end
        restoreClamp()
        local original=clamp:GetAttribute("Mode")
        if original=="drag" then return true end
        local ok=pcall(function()clamp:SetAttribute("Mode","drag")end)
        if not ok or clamp:GetAttribute("Mode")~="drag" then
            F.lastError="Outgoing clamp mode is not locally writable"
            return false
        end
        F.clampLease={
            clamp=clamp,original=original,owner=char,start=now
        }
        F.airCarrySessions+=1
        return true
    end
    local function request()
        local now=os.clock()
        if not F.enabled or not F.applied then return false end
        if UIS:GetFocusedTextBox() then return false end
        if now<F.nextAttempt then return false end
        if ctx.action and type(ctx.action.allowed)=="function" then
            local ok,allowed,reason=pcall(ctx.action.allowed,"flight")
            if not ok then
                F.actionPolicyErrors+=1
                F.status="FLIGHT PRIORITY ERROR / TAKEOFF CANCELLED"
                return false
            elseif not allowed then
                F.actionPriorityBlocks+=1
                F.status="FLIGHT PRIORITY / "..tostring(reason)
                return false
            end
        end
        local char,hum=own()
        if not char or not canFly(char,F.config) then
            F.status="NOT A FLIGHT-ELIGIBLE ANIMAL"
            return false
        end
        if char:GetAttribute("FeralFlyLocal")==true then return false end
        if not isWater(char,hum) then
            F.status="DRY LAND / NORMAL GAME TAKEOFF"
            return false
        end
        local atSurface,underwater,depth,top=waterState(char,hum)
        F.surfaceEligible=atSurface
        F.underwater=underwater
        F.depth=depth
        F.lastSurfaceY=top
        if not atSurface then
            F.submergedTakeoffBlocks+=1
            F.status=underwater and "UNDERWATER / TAKEOFF BLOCKED"
                or "WAITING FOR WATER SURFACE / TAKEOFF BLOCKED"
            return false
        end
        if char:GetAttribute("FeralPinned")==true
            or char:GetAttribute("FeralCarried")==true
            or char:GetAttribute("FeralDragged")==true then
            F.status="CAPTURED / ESCAPE FIRST"
            F.blocked+=1
            return false
        end
        F.nextAttempt=now+.75
        restoreWater()
        local cfg=F.config
        local lease={}
        if not setLocal(cfg.WATER,"NO_TAKEOFF",false,lease) then
            F.status="SURFACE TAKEOFF CONFIG REJECTED"
            return false
        end
        F.lease=lease
        if ctx.native and ctx.native.beforeFlight then pcall(ctx.native.beforeFlight) end
        if ctx.recovery and ctx.recovery.beforeCarry then pcall(ctx.recovery.beforeCarry) end
        if ctx.mobile and ctx.mobile.beforeCarry then pcall(ctx.mobile.beforeCarry) end
        local clamp=outgoingClamp(char)
        F.lastTakeoffCarry=clamp~=nil
        if clamp then prepAirCarry(char,now) end
        local ok,err=pcall(function()
            char:SetAttribute("FeralFlyRequest",now)
        end)
        if not ok then
            restoreWater()
            restoreClamp()
            F.lastError=tostring(err)
            F.status="SURFACE TAKEOFF REQUEST FAILED"
            return false
        end
        F.attempts+=1
        F.surfaceRequests+=1
        F.lastRequestAt=now
        F.takeoffPendingUntil=now+1.15
        F.status="FLOATING SURFACE / NATIVE TAKEOFF REQUESTED"
        return true
    end
    function F.beforeCarry()
        -- Drop/pickup always takes priority; never preserve a local
        -- airborne clamp override across a deliberate G action.
        restoreClamp()
        restoreWater()
        F.takeoffPendingUntil=0
        return false
    end
    function F.setEnabled(v)
        if v==false then
            F.enabled=false
            F.takeoffPendingUntil=0
            restoreClamp()
            restoreWater()
            F.config=nil
            F.applied=false
            F.status="OFF / WATER CONFIG RESTORED"
            return false
        end
        F.enabled=true
        return apply()
    end
    function F.requestTakeoff()
        return request()
    end
    local function tick()
        if not F.alive or not ctx.state.alive then return end
        local now=os.clock()
        if now<F.nextTick then return end
        F.nextTick=now+.14
        if not F.enabled then return end
        if not F.applied then apply() end
        local char,hum=own()
        if not char then
            restoreClamp()
            restoreWater()
            F.awaitingDropUntil=0
            F.ownedDropChar=nil
            F.status="WAITING FOR BIRD"
            F.lastOwner=nil
            F.lastAirborne=false
            return
        end
        if F.lastOwner and char~=F.lastOwner then
            restoreClamp()
            restoreWater()
            F.awaitingDropUntil=0
            F.ownedDropChar=nil
            F.takeoffPendingUntil=0
        end
        F.lastOwner=char
        F.eligible=canFly(char,F.config)
        if not F.eligible then
            restoreClamp()
            F.status="NOT A FLIGHT SPECIES / GROWTH LOCKED"
            return
        end
        local beforeWater=F.water
        F.water=isWater(char,hum)
        F.surfaceEligible,F.underwater,F.depth,F.lastSurfaceY=waterState(char,hum)
        F.airborne=char:GetAttribute("FeralFlyLocal")==true
        F.holding=outgoingClamp(char)~=nil
        if F.water and not beforeWater then F.waterContacts=(F.waterContacts or 0)+1 end
        if F.underwater then
            -- Restore native NO_TAKEOFF immediately if we enter deep water.
            restoreWater()
            F.takeoffPendingUntil=0
            restoreClamp()
            if F.airborne and now>=F.nextDrop and F.awaitingDropUntil==0
                and now-F.lastNativeDropAt>=3.5 then
                F.nextDrop=now+.8
                local ok=pcall(function()char:SetAttribute("FeralFlyDrop",true)end)
                if ok then
                    F.underwaterFlightExits+=1
                    F.lastNativeDropAt=now
                    F.awaitingDropUntil=now+2.0
                    F.dropUnconfirmed=false
                    F.ownedDropChar=char
                end
            end
        elseif F.airborne then
            -- Flight began at the surface: stop overriding WATER config.
            restoreWater()
        elseif F.lease and now>=F.takeoffPendingUntil then
            restoreWater()
        end
        if F.water and F.airborne then
            F.waterFlightOverlapSamples+=1
            F.waterFlightSeconds+=.14
        end
        -- Track whether the game's own flight controller actually released flight
        -- after our native FeralFlyDrop request; do not confuse a write with success.
        if F.awaitingDropUntil>0 then
            if not F.airborne then
                F.underwaterExitConfirmed+=1
                F.awaitingDropUntil=0
                F.dropUnconfirmed=false
                local owned=F.ownedDropChar
                if owned and owned==char then
                    pcall(function()
                        if owned:GetAttribute("FeralFlyDrop")==true then
                            owned:SetAttribute("FeralFlyDrop",false)
                        end
                    end)
                end
                F.ownedDropChar=nil
            elseif now>=F.awaitingDropUntil and not F.dropUnconfirmed then
                F.underwaterExitUnconfirmed+=1
                F.dropUnconfirmed=true
                F.awaitingDropUntil=0
            end
        end
        if F.airborne and not F.lastAirborne then
            if now-F.lastRequestAt<3.2 then
                F.observedTakeoffs+=1
                if F.lastTakeoffCarry then F.waterCarryTakeoffs+=1 end
            end
        end
        F.lastAirborne=F.airborne
        if F.airborne and F.holding and not F.underwater then
            -- The original flight controller drops flight when an
            -- outgoing clamp is not Mode="drag". Preserve its native
            -- talon-drag path even for prey acquired mid-flight.
            if not F.clampLease then
                if prepAirCarry(char,now) then
                    F.midairPreyProtects+=1
                end
            end
            F.flyWithPreySeconds+=.14
        end
        if F.water then F.waterTime+=.14 end
        if F.airborne then F.flightTime+=.14 end

        if F.clampLease then
            local owned=F.clampLease
            local keep=F.holding and F.enabled and not F.underwater
                and char==owned.owner
                and (F.airborne or now<F.takeoffPendingUntil)
            if not keep then restoreClamp() end
        end
        if F.underwater and F.airborne then
            F.status="UNDERWATER FLIGHT DETECTED / NATIVE DROP REQUESTED"
        elseif F.underwater then
            F.status="UNDERWATER / FLOAT RECOVERY"
        elseif F.water and F.surfaceEligible and F.airborne then
            F.status="WATER SURFACE TAKEOFF IN PROGRESS"
        elseif F.water and F.surfaceEligible then
            F.status="FLOATING / JUMP TO TAKE OFF"
        elseif F.water then
            F.status="WATER SURFACE NOT CONFIRMED / TAKEOFF BLOCKED"
        elseif F.airborne then
            F.status=F.holding and "FLYING WITH PREY (LOCAL)"
                or "FLIGHT ACTIVE"
        elseif F.takeoffPendingUntil>now then
            F.status="TAKEOFF ATTEMPT IN PROGRESS"
        else
            F.status="DRY / NORMAL FLIGHT CONTROL"
        end
        if F.takeoffPendingUntil>0 and now>=F.takeoffPendingUntil
            and not F.airborne then
            restoreClamp()
            F.takeoffPendingUntil=0
            F.status="NO FLIGHT OBSERVED / SERVER OR LOCAL RESTRICTION"
        end
    end
    function F.report()
        return table.concat({
            "FERAL NOVA PRIME v15 | Water Flight / Air Carry",
            "enabled="..tostring(F.enabled),
            "client_water_config_applied="..tostring(F.applied),
            "status="..F.status,
            "flight_species_eligible="..tostring(F.eligible),
            "in_water="..tostring(F.water),
            "flight_active="..tostring(F.airborne),
            "holding_prey="..tostring(F.holding),
            "water_takeoff_requests="..F.attempts,
            "surface_takeoff_requests="..F.surfaceRequests,
            "submerged_takeoff_blocks="..F.submergedTakeoffBlocks,
            "underwater_flight_native_drop_requests="..F.underwaterFlightExits,
            "water_flight_overlap_samples="..F.waterFlightOverlapSamples,
            "water_flight_seconds_local="..string.format("%.2f",F.waterFlightSeconds),
            "underwater_exit_confirmed_local="..F.underwaterExitConfirmed,
            "underwater_exit_unconfirmed_after_2s="..F.underwaterExitUnconfirmed,
            "water_surface_eligible="..tostring(F.surfaceEligible),
            "underwater="..tostring(F.underwater),
            "relative_water_depth="..tostring(F.depth),
            "water_grace_modified=false",
            "observed_flight_after_request="..F.observedTakeoffs,
            "water_prey_takeoffs="..F.waterCarryTakeoffs,
            "flight_with_prey_seconds_local="..string.format("%.2f",F.flyWithPreySeconds),
            "temporary_local_drag_modes="..F.airCarrySessions,
            "midair_carry_guard_attempts="..F.midairPreyProtects,
            "local_config_restorations="..F.restores,
            "config_or_clamp_conflicts="..F.conflicts,
            "last_error="..F.lastError,
            "takeoffs_blocked_by_action_priority="..F.actionPriorityBlocks,
            "takeoff_action_policy_errors="..F.actionPolicyErrors,
            "NOTE=No prey/animal physics modifications or fabricated server remotes.",
            "NOTE=Surface water takeoff only; native FeralFlyDrop requested when submerged.",
            "NOTE=Server acceptance of takeoff/flight exit remains unverified."
        },"\n")
    end
    local function watchChar(char)
        for _,c in ipairs(F.characterConnections) do
            pcall(function()c:Disconnect()end)
        end
        table.clear(F.characterConnections)
        if not char then return end
        local ok,conn=pcall(function()
            return char.ChildAdded:Connect(function(child)
                if child.Name~="FeralClamp" then return end
                -- Incoming clamp may be populated just after parenting.
                task.defer(function()
                    if not F.alive or not F.enabled or
                        char~=player.Character then return end
                    local hum=char:FindFirstChildOfClass("Humanoid")
                    local _,submerged=waterState(char,hum)
                    if hum and canFly(char,F.config) and not submerged
                        and char:GetAttribute("FeralFlyLocal")==true then
                        if prepAirCarry(char,os.clock()) then
                            F.midairPreyProtects+=1
                        end
                    end
                end)
            end)
        end)
        if ok and conn then
            F.characterConnections[#F.characterConnections+1]=conn
        end
    end
    function F.close()
        if not F.alive then return end
        F.alive=false
        F.setEnabled(false)
        F.awaitingDropUntil=0
        F.ownedDropChar=nil
        if F.conn then F.conn:Disconnect()end
        for _,c in ipairs(F.characterConnections) do
            pcall(function()c:Disconnect()end)
        end
        for _,c in ipairs(listeners) do pcall(function()c:Disconnect()end)end
    end
    watchChar(player.Character)
    listeners[#listeners+1]=player.CharacterAdded:Connect(function(char)
        restoreWater()
        restoreClamp()
        F.awaitingDropUntil=0
        F.ownedDropChar=nil
        F.lastOwner=nil
        F.lastAirborne=false
        F.nextTick=0
        watchChar(char)
    end)
    listeners[#listeners+1]=UIS.JumpRequest:Connect(function()
        if F.enabled then pcall(request)end
    end)
    listeners[#listeners+1]=UIS.InputBegan:Connect(function(input,processed)
        if processed or UIS:GetFocusedTextBox() then return end
        if input.KeyCode==Enum.KeyCode.G then F.beforeCarry()end
    end)
    F.conn=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            F.lastError=tostring(err)
            F.status="WATER FLIGHT ERROR"
        end
    end)
    return F
end
return Flight
]==========],
["feral-nova-native-recovery-v13.3.lua"]=[==========[
-- FERAL NOVA v13.4.6 / Cobra combat Rest-lock preflight and native Rest arbitration
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
local function blockedByActivity(char,ctx)
    if not char or not char.Parent then return "NO ANIMAL" end
    if nativeFeed(char:GetAttribute("WolfFeed")) then
        return "FEEDING / DRINKING / REST OFF"
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
    -- Cobra: the native WolfController refuses bite during Rest and for
    -- ~0.7 seconds after getting up. Yield owned Rest before the animal
    -- reaches bite range, not on the first damaging swing.
    -- This affects recovery timing, NOT CombatConfig or the server's hit rules.
    if char:GetAttribute("Species")=="KingCobra" and ctx.lab then
        local lab=ctx.lab
        local target=lab.target
        if lab.enabled and target and target.model and target.model.Parent
            and type(target.gap)=="number"
            and type(target.reach)=="number"
            and type(target.angle)=="number"
            and type(target.cone)=="number"
            and target.gap<target.reach+28
            and target.angle<math.min(130,target.cone+10) then
            return "COBRA PRE-BITE RANGE / REST YIELDED"
        end
    end
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
    }
    N.blockedByActivity=blockedByActivity
    N.nativeDeathRollPresent=nativeDeathRollPresent
    local conns={}
    local feedConn=nil
    local feedPoseConn=nil
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
            N.attackInputsObserved+=1
            if N.active then N.attackRestReleases+=1 end
            -- The game's own bite path can refuse attacks while server Rest
            -- is active, even when WolfRest is masked false on this client.
            -- Send Rest(false) immediately on the actual attack input.
            local char=player.Character
            local cobra=char and char:GetAttribute("Species")=="KingCobra"
            if cobra then
                N.cobraLastBiteInputAt=os.clock()
            end
            delayInput("ATTACK INPUT / NATIVE REST RELEASED",
                cobra and 2.4 or 1.3)
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
        local current={char=char,at=now,mode=mode,values={}}
        for _,key in ipairs(EFFECTS) do
            current.values[key]=char:GetAttribute(key)
        end
        if old and old.char==char and old.mode==mode
            and N.conditionRates[mode] and now-old.at>=.1
            and now-old.at<=1.5 then
            local dt=now-old.at
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
        local preAim=blocked=="COBRA PRE-BITE RANGE / REST YIELDED"
        if preAim and not N.cobraPreAimActive then
            N.cobraEarlyBitePauses+=1
        end
        N.cobraPreAimActive=preAim
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
            "cobra_base_post_rest_bite_lock_seconds="..N.cobraRestLockSeconds,
            "cobra_early_pre_bite_rest_pauses="..N.cobraEarlyBitePauses,
            "cobra_pre_bite_guard_active="..tostring(N.cobraPreAimActive),
            "cobra_special_ability_inputs="..N.cobraAbilityInputs,
            "cobra_special_ability_rest_preemptions="..N.cobraAbilityPreempts,
            "cobra_cas_prioritized="..tostring(N.cobraCASBound),
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
            "NOTE=3s wounded-motion refresh is experimental and may still be rejected by the server.",
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
        if feedConn then pcall(function()feedConn:Disconnect()end)end
        if feedPoseConn then pcall(function()feedPoseConn:Disconnect()end)end
    end
    local function watchFeed(char)
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
]==========],
["feral-nova-baby-v15.0.lua"]=[==========[
-- FERAL NOVA PRIME v15 / Same-species baby pickup protection.
-- This protects the user's infant from Auto Escape's getoff requests.
-- It never grants a pickup or sends any carry action itself.
local Baby={}
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function number(x)
    return type(x)=="number" and x==x and x>=0 and x<10
end
local function targetOf(clamp,baby)
    if not clamp or not clamp:IsA("ObjectValue") then return false end
    local target=clamp.Value
    if not target then return false end
    if target==baby then return true end
    local ok,value=pcall(function()return target:IsDescendantOf(baby)end)
    return ok and value==true
end
function Baby.eligible(baby,adult)
    if not baby or not adult or not baby.Parent or not adult.Parent
        or baby==adult then return false end
    if baby:GetAttribute("FeralPinned")==true
        or baby:GetAttribute("FeralDragged")==true then return false end
    local bs= baby:GetAttribute("Species")
    local adultSpecies=adult:GetAttribute("Species")
    local bg=baby:GetAttribute("Growth")
    local ag=adult:GetAttribute("Growth")
    return type(bs)=="string" and bs~="" and bs==adultSpecies
        and number(bg) and bg<=.34 and number(ag) and ag>=.67
end
function Baby.carrierEvidence(baby,adult)
    if not Baby.eligible(baby,adult) then
        return false,"NOT ELIGIBLE"
    end
    local clamp=adult:FindFirstChild("FeralClamp")
    if targetOf(clamp,baby) then
        return true,"CONFIRMED OUTGOING CLAMP"
    end
    local localClamp=adult:FindFirstChild("FeralClampLocal")
    if targetOf(localClamp,baby) then
        return true,"CONFIRMED LOCAL OUTGOING CLAMP"
    end
    local b= baby:FindFirstChild("HumanoidRootPart")
    local a=adult:FindFirstChild("HumanoidRootPart")
    if b and a then
        local ok,d=pcall(function()
            return (b.Position-a.Position).Magnitude
        end)
        if ok and type(d)=="number" and d<=12 then
            return true,"SAME-SPECIES ADULT NEARBY"
        end
    end
    return false,"NO MATCHING CARRIER"
end
function Baby.attach(ctx)
    local B={
        alive=true,enabled=true,active=false,
        status="ARMED / BABY PICKUP PROTECTION",
        lastEvidence="NONE",lastCarrierSpecies="",
        friendlyFrames=0,confirmedFrames=0,
        proximityFrames=0,hostileFrames=0,
        sameSpeciesAdultCandidates=0,
        episodes=0,protectedSeconds=0,
        maxProximityTrustSeconds=12,
        firstProximityAt=0,
        lastUpdate=0,lastFriendlyAt=0,
        nextCheck=0,lastCharacter=nil
    }
    function B.setEnabled(value)
        B.enabled=value==true
        if not B.enabled then
            B.active=false;B.status="OFF / ALL CAPTURES ESCAPED NORMALLY"
        else
            B.status="ARMED / ELIGIBLE BABY ONLY"
        end
    end
    function B.shouldProtect(baby,now)
        now=now or os.clock()
        if not B.enabled or not baby or not baby.Parent then
            B.active=false
            return false,"DISABLED / NO BABY"
        end
        if baby~=B.lastCharacter then
            B.lastCharacter=baby
            B.active=false
            B.firstProximityAt=0
        end
        if baby:GetAttribute("FeralPinned")==true
            or baby:GetAttribute("FeralDragged")==true then
            B.active=false
            B.hostileFrames+=1
            B.status="PINNED/DRAGGED / ESCAPE ALWAYS WINS"
            return false,"HOSTILE CONTROL"
        end
        if baby:GetAttribute("FeralCarried")~=true then
            B.active=false
            B.firstProximityAt=0
            B.status="WAITING FOR INFANT PICKUP"
            return false,"NOT BEING CARRIED"
        end
        local growth=baby:GetAttribute("Growth")
        if not number(growth) or growth>.34 then
            B.active=false
            B.status="NOT IN BABY GROWTH RANGE"
            return false,"ADULT / UNKNOWN GROWTH"
        end
        local chosen,kind
        local count=0
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player then
                local adult=other.Character
                if Baby.eligible(baby,adult) then
                    count+=1
                    local ok,why=Baby.carrierEvidence(baby,adult)
                    if ok then
                        chosen=adult
                        kind=why
                        if why~="SAME-SPECIES ADULT NEARBY" then
                            break
                        end
                    end
                end
            end
        end
        B.sameSpeciesAdultCandidates=count
        if not chosen then
            B.active=false
            B.firstProximityAt=0
            B.status="NO VERIFIED FRIENDLY CARRIER / ESCAPE NORMAL"
            return false,"NO CARRIER"
        end
        local confirmed=kind~="SAME-SPECIES ADULT NEARBY"
        if confirmed then
            B.firstProximityAt=0
            B.confirmedFrames+=1
        else
            if B.firstProximityAt==0 then
                B.firstProximityAt=now
            end
            if now-B.firstProximityAt>B.maxProximityTrustSeconds then
                B.active=false
                B.status="NO CARRIER CLAMP CONFIRMED / ESCAPE RESUMES"
                return false,"PROXIMITY EXPIRED"
            end
            B.proximityFrames+=1
        end
        if not B.active then B.episodes+=1 end
        B.active=true
        B.lastFriendlyAt=now
        B.lastEvidence=kind
        B.lastCarrierSpecies=tostring(chosen:GetAttribute("Species") or "")
        B.friendlyFrames+=1
        B.status=confirmed
            and "FRIENDLY BABY CARRY CONFIRMED / GETOFF BLOCKED"
            or "SAME-SPECIES ADULT NEARBY / SHORT GETOFF GRACE"
        return true,kind
    end
    function B.report()
        return table.concat({
            "FERAL NOVA PRIME v15 | Friendly Baby Carry",
            "enabled="..tostring(B.enabled)..
                " friendly_carry_protected_now="..tostring(B.active),
            "status="..B.status,
            "last_carrier_evidence="..B.lastEvidence,
            "same_species_adults_eligible="..B.sameSpeciesAdultCandidates,
            "friendly_carry_episodes="..B.episodes,
            "confirmed_clamp_observations="..B.confirmedFrames,
            "proximity_fallback_observations="..B.proximityFrames,
            "proximity_grace_max_seconds="..B.maxProximityTrustSeconds,
            "hostile_pin_or_drag_overrides="..B.hostileFrames,
            "NOTE=Only Growth<=.34 with same-species adult Growth>=.67.",
            "NOTE=Pinned/dragged overrides friendly protection immediately.",
            "NOTE=Proximity alone cannot prove consent; disable protection if needed."
        },"\n")
    end
    function B.close()
        B.enabled=false;B.alive=false;B.active=false
    end
    return B
end
return Baby

]==========],
["feral-nova-climb-v13.0.lua"]=[==========[
-- FERAL NOVA v13.0 / feed-aware climb and processed-Q input protection.
-- Adapted from the separately validated Quick Climb v1.0.
-- No injected tree geometry, no fabricated climbing server remotes.
local Climb={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function nativeFeed(value)
    -- WolfController uses string "eat"/"drink"; retain boolean true for legacy.
    return value==true or value=="eat" or value=="drink"
end
Climb.isNativeFeed=nativeFeed
function Climb.attach(ctx)
    local env
    if type(getgenv)=="function" then
        local ok,g=pcall(getgenv)
        if ok and type(g)=="table" then env=g end
    end
    if env and type(env.FERALQuickClimbV1)=="table"
        and type(env.FERALQuickClimbV1.close)=="function" then
        pcall(env.FERALQuickClimbV1.close)
    end
    local Q={
        alive=true,enabled=true,ready=false,queued=false,
        status="WAITING FOR CLIMBABLE ANIMAL",lastError="",
        configReady=false,sprintGrabPatch=false,
        queuedPresses=0,expiredPresses=0,gameTaps=0,
        observedMounts=0,suppressedDives=0,suppressedConflicts=0,
        retries=0,retrySuppressed=0,retapsForPress=0,
        next=0,lastTap=-math.huge,pendingUntil=0,
        lastChar=nil,awaitingMount=false,awaitUntil=0,
        firstReadyAt=0,configLease=nil
    }
    local connections={}
    local function finite(v)
        return type(v)=="number" and v==v and v<1e8 and v>-1e8
    end
    local function lease(tbl,key,value,list)
        if type(tbl)~="table" then return false end
        local original=tbl[key]
        if original==nil then return false end
        if original==value then return true end
        local ok=pcall(function()tbl[key]=value end)
        if not ok or tbl[key]~=value then return false end
        list[#list+1]={tbl=tbl,key=key,original=original,wanted=value}
        return true
    end
    local function release()
        for i=#(Q.configLease or {}),1,-1 do
            local e=Q.configLease[i]
            pcall(function()
                if e.tbl[e.key]==e.wanted then e.tbl[e.key]=e.original end
            end)
        end
        Q.configLease=nil
        Q.configReady=false
        Q.sprintGrabPatch=false
    end
    local function install()
        if Q.configReady then return true end
        local world=RS:FindFirstChild("FeralWorld")
        local mod=world and world:FindFirstChild("PassiveConfig")
        if not mod or not mod:IsA("ModuleScript") then
            Q.status="PASSIVE CONFIG UNAVAILABLE"
            return false
        end
        local ok,v=pcall(require,mod)
        local c=ok and type(v)=="table" and v.CLIMBER
        if type(c)~="table" or type(c.levels)~="table"
            or not finite(c.GRAB_REACH) or not finite(c.E_REACH)
            or not finite(c.GRAB_FACING) or not finite(c.MOUNT_TIME) then
            Q.status="CLIMB CONFIG NOT COMPATIBLE"
            return false
        end
        local changes={}
        local work={
            {"GRAB_REACH",math.min(1.25,c.GRAB_REACH*1.30)},
            {"E_REACH",math.min(2.1,c.E_REACH*1.25)},
            {"GRAB_FACING",math.max(.25,c.GRAB_FACING*.58)},
            {"MOUNT_TIME",math.max(.22,c.MOUNT_TIME*.75)},
            {"HINT_RANGE",math.min(20,(c.HINT_RANGE or 14)*1.25)}
        }
        for _,entry in ipairs(work) do
            lease(c,entry[1],entry[2],changes)
        end
        local sprintGranted=false
        for _,level in ipairs({1,2}) do
            local l=c.levels[level]
            if type(l)=="table" and l.sprintGrab~=true then
                -- Source blocks basic climbers from catching a tree at
                -- sprint velocity; this is the main chase nuisance.
                if l.sprintGrab==nil then
                    -- Nil fields require special restoration.
                    local setOk=pcall(function()l.sprintGrab=true end)
                    if setOk and l.sprintGrab==true then
                        changes[#changes+1]={
                            tbl=l,key="sprintGrab",original=nil,wanted=true}
                        sprintGranted=true
                    end
                else
                    if lease(l,"sprintGrab",true,changes) then
                        sprintGranted=true
                    end
                end
            end
        end
        Q.configLease=changes
        Q.sprintGrabPatch=sprintGranted
        Q.configReady=true
        Q.status="FAST MOUNT SETTINGS READY • Q BUFFER ON"
        return true
    end
    local function validChar(char)
        if not char or not char.Parent then return false end
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health<=0 or char:GetAttribute("FeralDead")==true then
            return false
        end
        local lv=char:GetAttribute("PassiveClimber")
        return finite(lv) and lv>=1
    end
    local function unsafe(char)
        return char:GetAttribute("FeralClimbLocal")==true
            or char:GetAttribute("FeralPinned")==true
            or char:GetAttribute("FeralCarried")==true
            or char:GetAttribute("WolfRest")==true
            or nativeFeed(char:GetAttribute("WolfFeed"))
            or char:GetAttribute("FeralDiving")==true
            or char:FindFirstChild("FeralClamp")~=nil
            or char:FindFirstChild("FeralClampLocal")~=nil
    end
    local function climbAllowed()
        if not ctx.action or type(ctx.action.allowed)~="function" then
            return true
        end
        local ok,allowed,reason=pcall(ctx.action.allowed,"climb")
        if not ok then return false,"ACTION CORE ERROR" end
        return allowed,reason
    end
    local function onQ(now)
        if not Q.enabled or not Q.alive then return end
        if UIS:GetFocusedTextBox() then return end
        local char=player.Character
        if not validChar(char) then
            Q.status="THIS ANIMAL CANNOT CLIMB YET"
            return
        end
        if char:GetAttribute("FeralClimbLocal")==true then
            Q.queued=false
            Q.status="ALREADY CLIMBING • NATIVE Q HANDLES LET-GO"
            return
        end
        -- The same Q may be used to dive. Never invoke the climb
        -- tap listener when the local game is offering DiveCan.
        if char:GetAttribute("DiveCan")==true then
            Q.queued=false
            Q.suppressedDives+=1
            Q.status="DIVE HAS PRIORITY"
            return
        end
        if unsafe(char) then
            Q.queued=false
            Q.suppressedConflicts+=1
            Q.status="BUSY / CARRY, REST OR GRAB PRIORITY"
            return
        end
        local allowed,why=climbAllowed()
        if not allowed then
            Q.queued=false
            Q.suppressedConflicts+=1
            Q.status="ACTION PRIORITY / "..tostring(why)
            return
        end
        -- A Q pressed before the first heartbeat must survive the
        -- initial character sample; only an actual respawn clears it.
        Q.lastChar=char
        if ctx.native and ctx.native.beforeClimb then
            pcall(ctx.native.beforeClimb)
        end
        Q.pendingUntil=now+2.25
        Q.retapsForPress=0
        Q.queued=true
        Q.queuedPresses+=1
        Q.status="Q BUFFERED • RUN TOWARD TREE"
    end
    local function tick()
        if not Q.alive then return end
        local now=os.clock()
        if now<Q.next then return end
        Q.next=now+.055
        if Q.enabled and not Q.configReady then install()end
        local char=player.Character
        if char~=Q.lastChar then
            Q.lastChar=char;Q.queued=false
            Q.awaitingMount=false;Q.ready=false;Q.retapsForPress=0
        end
        if not Q.enabled then return end
        if not validChar(char) then
            Q.queued=false;Q.ready=false
            return
        end
        if char:GetAttribute("FeralClimbLocal")==true then
            if Q.awaitingMount then Q.observedMounts+=1 end
            Q.queued=false;Q.awaitingMount=false;Q.retapsForPress=0
            Q.status="CLIMBING • NATIVE Q TO LET GO"
            Q.ready=false
            return
        end
        Q.ready=char:GetAttribute("ClimbCan")==true
        if Q.awaitingMount and now>=Q.awaitUntil then
            Q.awaitingMount=false
            -- One guarded retry after a dropped native tap, only when the
            -- same own climber is still on a valid tree and not diving.
            if Q.retapsForPress<1 and Q.ready
                and not UIS:GetFocusedTextBox()
                and not unsafe(char)
                and char:GetAttribute("DiveCan")~=true
                and climbAllowed() then
                Q.retapsForPress+=1
                Q.retries+=1
                Q.queued=true
                Q.pendingUntil=now+.65
                Q.status="NATIVE CLIMB TAP RETRY QUEUED"
            else
                Q.retrySuppressed+=1
                Q.status="CLIMB TAP SENT • NO MOUNT CONFIRMED"
            end
        end
        if not Q.queued then return end
        if now>Q.pendingUntil then
            Q.queued=false
            Q.expiredPresses+=1
            Q.status="BUFFER EXPIRED • TREE NOT READY"
            return
        end
        local allowed,why=climbAllowed()
        if UIS:GetFocusedTextBox() or unsafe(char) or not allowed then
            Q.queued=false
            Q.suppressedConflicts+=1
            Q.status="ACTION PRIORITY / "..tostring(why)
            return
        end
        if char:GetAttribute("DiveCan")==true then
            Q.queued=false;Q.suppressedDives+=1
            return
        end
        if not Q.ready then return end
        if now-Q.lastTap<.35 then return end
        Q.lastTap=now
        Q.queued=false
        if ctx.native and ctx.native.beforeClimb then
            pcall(ctx.native.beforeClimb)
        end
        -- Native FERAL ClimbController listens to the player's
        -- FeralClimbTap attribute (same as the game's own touch HUD).
        -- Never send FeralClimb remote directly or teleport into trees.
        player:SetAttribute("FeralClimbTap",now)
        Q.gameTaps+=1
        Q.awaitingMount=true
        Q.awaitUntil=now+.7
        Q.status="NATIVE CLIMB TAP SENT"
    end
    function Q.setEnabled(on)
        Q.enabled=on==true
        Q.queued=false
        Q.awaitingMount=false
        Q.retapsForPress=0
        if not Q.enabled then
            release()
            Q.status="OFF / CLIMB SETTINGS RESTORED"
        else
            Q.status="READY TO BUFFER Q"
            install()
        end
    end
    function Q.report()
        return table.concat({
            "FERAL NOVA PRIME v15 | Quick Climb",
            "enabled="..tostring(Q.enabled)..
                " config_applied="..tostring(Q.configReady),
            "climb_ready_now="..tostring(Q.ready),
            "buffer_pending="..tostring(Q.queued),
            "sprint_grab_enabled_client="..tostring(Q.sprintGrabPatch),
            "Q_press_buffers="..Q.queuedPresses,
            "buffer_expired="..Q.expiredPresses,
            "native_climb_taps="..Q.gameTaps,
            "retry_taps_queued="..Q.retries,
            "retry_taps_suppressed="..Q.retrySuppressed,
            "buffer_window_seconds=2.25",
            "observed_climb_mounts="..Q.observedMounts,
            "dive_priority_holds="..Q.suppressedDives,
            "carry_and_capture_priority_holds="..Q.suppressedConflicts,
            "status="..Q.status,
            "last_error="..Q.lastError,
            "NOTE=Climb input buffers for 2.25s and may retry one missed native tap.",
            "NOTE=Game controls actual mount and server acceptance.",
            "NOTE=v9 shared minigame priority prevents buffered climb taps conflicting with grabs."
        },"\n")
    end
    
    function Q.close()
        if not Q.alive then return end
        Q.alive=false
        Q.setEnabled(false)
        for _,connection in ipairs(connections) do
            pcall(function()connection:Disconnect()end)
        end
    end
    connections[#connections+1]=UIS.InputBegan:Connect(function(input,processed)
        -- Ignore Q already handled by Roblox UI, even with no focused chat.
        if processed then return end
        if input.KeyCode==Enum.KeyCode.Q then
            local ok,err=pcall(onQ,os.clock())
            if not ok then Q.lastError=tostring(err)end
        end
    end)
    connections[#connections+1]=RunService.Heartbeat:Connect(function()
        if not ctx.state.alive then Q.close();return end
        local ok,err=pcall(tick)
        if not ok then Q.lastError=tostring(err)end
    end)
    install()
    Q.isNativeFeed=nativeFeed
    return Q
end
return Climb
]==========],
["feral-nova-tags-v8.0.lua"]=[==========[
-- FERAL NOVA PRIME v8: camera-projected tag overlay.
-- Replaces distance-clipped BillboardGui labels with small ScreenGui labels.
-- Viewport projection is visual only, never changes game character state.
local Tags={}
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function create(kind,props,parent)
    local v=Instance.new(kind)
    for k,x in pairs(props) do v[k]=x end
    v.Parent=parent
    return v
end
function Tags.attach(ctx)
    local S=ctx.state
    local pg=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",8)
    if not pg then error("PlayerGui unavailable for tags") end
    local gui=create("ScreenGui",{
        Name="FeralNovaPrimeTagsV8",
        DisplayOrder=205,ResetOnSpawn=false,
        IgnoreGuiInset=true,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    },pg)
    local T={
        alive=true,gui=gui,active=0,visible=0,closeCount=0,
        lastError="",frameInterval=.065,lastFrame=-math.huge
    }
    local labels={}
    local function clear(plr)
        local label=labels[plr]
        labels[plr]=nil
        if label then pcall(function()label:Destroy()end)end
    end
    local function labelFor(plr)
        local label=labels[plr]
        if label and label.Parent then return label end
        label=create("TextLabel",{
            Name="FloatingAnimalName",
            AnchorPoint=Vector2.new(.5,.5),
            Size=UDim2.fromOffset(172,22),
            BackgroundTransparency=1,
            Font=Enum.Font.GothamBold,
            TextSize=12,
            TextColor3=Color3.fromRGB(231,247,252),
            TextStrokeColor3=Color3.fromRGB(3,8,15),
            TextStrokeTransparency=.12,
            TextXAlignment=Enum.TextXAlignment.Center,
            TextYAlignment=Enum.TextYAlignment.Center,
            TextTruncate=Enum.TextTruncate.AtEnd,
            Visible=false,ZIndex=8
        },gui)
        labels[plr]=label
        return label
    end
    local function worldHead(record)
        local char=record.char
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        local head=char:FindFirstChild("Head")
        local p=(head and head:IsA("BasePart")) and head.Position or root.Position
        if not record.lastTopSample or os.clock()-record.lastTopSample>1.1 then
            record.lastTopSample=os.clock()
            local ok,cf,size=pcall(function()return char:GetBoundingBox()end)
            if ok and cf and size then
                record.cachedTop=cf.Position.Y+size.Y*.5
            end
        end
        local top=record.cachedTop
        if type(top)=="number" then
            -- Keep labels above head without floating above an entire huge
            -- model when giant decorative attachments distort its bounds.
            local lift=math.clamp(top-p.Y+.52,.6,5.5)
            return p+Vector3.new(0,lift,0),root
        end
        return p+Vector3.new(0,2.35,0),root
    end
    local function paint()
        if not T.alive or not S.alive then return end
        local now=os.clock()
        if now-T.lastFrame<T.frameInterval then return end
        T.lastFrame=now
        local camera=workspace.CurrentCamera
        if not camera then
            for _,lab in pairs(labels) do lab.Visible=false end
            T.visible=0
            return
        end
        local vp=camera.ViewportSize
        if vp.X<=0 or vp.Y<=0 then return end
        local enabled=S.flags.playerFinder and S.flags.tags
        local alive={}
        local shown=0
        local closeTags=0
        local total=0
        for plr,record in pairs(S.byPlayer) do
            if plr~=player and record and record.char and record.char.Parent then
                local world,root=worldHead(record)
                if world and root and root.Parent then
                    total+=1
                    local lab=labelFor(plr)
                    alive[plr]=true
                    -- Core tracker originally creates BillboardGui plates.
                    -- Disable their render; this overlay remains visible
                    -- even at extremely short camera/target distances.
                    if record.b then record.b.Enabled=false end
                    if enabled then
                        local pos,front=camera:WorldToViewportPoint(world)
                        local rootDist=(root.Position-camera.CFrame.Position).Magnitude
                        if rootDist<=S.range then
                            local closeCamera=rootDist<9
                            local x,y
                            if pos.Z>0 and (front or closeCamera) then
                                x=pos.X
                                y=pos.Y
                            elseif closeCamera then
                                -- Player may literally surround the camera.
                                -- Keep a small name chip at the top, instead
                                -- of silently dropping their name.
                                x=vp.X*.5
                                y=76+closeTags*24
                            end
                            if x and y then
                                x=math.clamp(x,93,vp.X-93)
                                y=math.clamp(y,35,vp.Y-35)
                                if closeCamera then
                                    y=math.min(y,104+closeTags*24)
                                    closeTags+=1
                                end
                                lab.Position=UDim2.fromOffset(x,y)
                                lab.Text=record.name and record.name.Text or plr.DisplayName
                                lab.TextColor3=record.h and record.h.OutlineColor
                                    or Color3.fromRGB(231,247,252)
                                lab.Visible=true
                                shown+=1
                            else
                                lab.Visible=false
                            end
                        else
                            lab.Visible=false
                        end
                    else
                        lab.Visible=false
                    end
                end
            end
        end
        for plr in pairs(labels) do
            if not alive[plr] then clear(plr) end
        end
        T.active=total
        T.visible=shown
        T.closeCount=closeTags
    end
    function T.report()
        return "FERAL v8 Screen Tags | tracked="..tostring(T.active)..
            " visible="..tostring(T.visible)..
            " close="..tostring(T.closeCount)..
            " enabled="..tostring(S.flags.tags)..
            " error="..tostring(T.lastError)
    end
    function T.close()
        if not T.alive then return end
        T.alive=false
        if T.connection then T.connection:Disconnect()end
        for plr in pairs(labels) do clear(plr) end
        if gui then pcall(function()gui:Destroy()end)end
    end
    T.connection=RunService.RenderStepped:Connect(function()
        local ok,err=pcall(paint)
        if not ok then T.lastError=tostring(err) end
    end)
    return T
end
return Tags

]==========],
["feral-nova-ui-v13.1.lua"]=[==========[
-- FERAL NOVA UI v13.4.3 | display release from ctx.hubBuild.release (legacy internal GUI name preserved)
-- Preserves v7.5 gameplay while adding independent AFK controls and safety evidence.
local UI={}
-- Standalone callback wrapper used by all click paths.
function UI.runButtonAction(state,label,callback)
    if type(state)=="table" then
        state.clicks=(state.clicks or 0)+1
        state.lastButton=tostring(label)
    end
    local ok,err=pcall(callback)
    if type(state)=="table" then
        if not ok then
            state.errors=(state.errors or 0)+1
            state.lastError=tostring(err):sub(1,240)
        else
            state.lastSuccessfulButton=tostring(label)
        end
    end
    return ok,err
end
-- Current Eagle module's actual fields, with safe fallbacks.
function UI.eagleSummary(eagle,recoveryStatus)
    local function safeNumber(v)
        return type(v)=="number" and v==v and tostring(v) or "0"
    end
    return "HEALTH "..tostring(recoveryStatus or "UNKNOWN"):sub(1,28)..
        "  •  HOLDS "..safeNumber(eagle and eagle.actualClampObservations)..
        "  / SERVER CLAMPS "..safeNumber(eagle and eagle.serverClampReplies)..
        "  / UNCONFIRMED "..safeNumber(eagle and eagle.serverClampWithoutObservedCarry)
end
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Lighting=game:GetService("Lighting")
local HttpService=game:GetService("HttpService")
local player=Players.LocalPlayer
local C={
    bg=Color3.fromRGB(8,14,25),tile=Color3.fromRGB(17,29,45),
    edge=Color3.fromRGB(46,70,91),alt=Color3.fromRGB(29,46,66),
    cyan=Color3.fromRGB(75,237,212),violet=Color3.fromRGB(168,146,255),
    ink=Color3.fromRGB(235,244,252),muted=Color3.fromRGB(147,169,190),
    danger=Color3.fromRGB(246,116,132),amber=Color3.fromRGB(255,194,113)
}
local function make(typ,props,parent)
    local x=Instance.new(typ)
    for key,value in pairs(props or {}) do x[key]=value end
    if parent then x.Parent=parent end
    return x
end
local function corner(x,r)
    make("UICorner",{CornerRadius=UDim.new(0,r or 11)},x)
    return x
end
local function border(x,transparency)
    make("UIStroke",{Color=C.edge,Transparency=transparency or .4,Thickness=1},x)
end
local function txt(parent,s,size,color,bold)
    return make("TextLabel",{
        Text=s or "",Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=size or 12,TextColor3=color or C.ink,
        BackgroundTransparency=1,BorderSizePixel=0,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,
        TextTruncate=Enum.TextTruncate.AtEnd
    },parent)
end
local function btn(parent,s,callback,w,h)
    local b=corner(make("TextButton",{
        Text=s,Font=Enum.Font.GothamBold,TextSize=11,
        BackgroundColor3=C.alt,TextColor3=C.ink,
        BorderSizePixel=0,AutoButtonColor=false
    },parent),9)
    b.Size=UDim2.fromOffset(w or 64,h or 30)
    local outline=make("UIStroke",{
        Color=C.cyan,Transparency=.86,Thickness=1
    },b)
    b.MouseEnter:Connect(function()
        if b.Parent then
            TweenService:Create(outline,TweenInfo.new(.12),{Transparency=.34}):Play()
        end
    end)
    b.MouseLeave:Connect(function()
        if b.Parent then
            TweenService:Create(outline,TweenInfo.new(.12),{Transparency=.86}):Play()
        end
    end)
    local lastInvoke=-math.huge
    local function activate()
        -- Desktop MouseButton1Click fallback is de-duplicated against Activated.
        local now=os.clock()
        if now-lastInvoke<.12 then return end
        lastInvoke=now
        local label=(b.Name~="TextButton" and b.Name) or s
        local ok,err=UI.runButtonAction(UI._buttonEvents,label,callback)
        if not ok then
            warn("[FERAL HUB UI] BUTTON ACTION FAILED: "..tostring(err))
        end
        if type(UI._showActionFeedback)=="function" then
            UI._showActionFeedback(label,ok,err)
        end
        if type(UI._requestRefresh)=="function" then
            pcall(UI._requestRefresh)
        end
    end
    b.Activated:Connect(activate)
    b.MouseButton1Click:Connect(activate)
    return b
end
local function nfmt(n,decimals)
    if type(n)~="number" or n~=n then return "--" end
    return string.format("%."..tostring(decimals or 0).."f",n)
end

function UI.mount(ctx)
    local S,P=ctx.state,ctx.power
    local Escape=ctx.escape
    local Lab=ctx.lab
    local Recovery=ctx.recovery
    local Regen=ctx.regen
    local Mobile=ctx.mobile
    local Native=ctx.native
    local Active=ctx.activeRecovery
    local Climb=ctx.climb
    local Baby=ctx.baby
    local Reach=ctx.reach
    local Flight=ctx.flight
    local Carry=ctx.carry
    local Tags=ctx.tags
    local Mechanics=ctx.mechanics
    local Eagle=ctx.eagleActions
    local Diag=ctx.diag
    local AFK=ctx.afk
    local Action=ctx.action
    local Grab=ctx.grabMini
    local Evidence=ctx.evidence
    if not AFK or not Action or not Grab or not Evidence then return nil end
    if not Escape or not P or not Lab or not Recovery or not Regen or not Mobile or not Native or not Climb or not Baby or not Reach or not Flight or not Carry or not Tags or not Mechanics or not Diag or not Active or not Eagle then return nil end
    local buttonEvents={
        clicks=0,errors=0,refreshErrors=0,
        lastButton="NONE",lastSuccessfulButton="NONE",
        lastError="",lastRefreshError=""
    }
    UI._buttonEvents=buttonEvents
    ctx.uiInputHealth=buttonEvents
    local pg=player:FindFirstChildOfClass("PlayerGui")
        or player:WaitForChild("PlayerGui",10)
    if not pg then return nil end
    -- The release is supplied by the integrated launcher: no stale UI version.
    local release=tostring(ctx.hubBuild and ctx.hubBuild.release or "UNKNOWN")
    local gui=make("ScreenGui",{
        Name="FeralNovaV131",ResetOnSpawn=false,
        DisplayOrder=210,ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    },pg)
    ctx.ui=gui
    local shutdown=make("BindableEvent",{Name="AuroraShutdown"},gui)
    shutdown.Event:Connect(function()ctx.close()end)

    -- Existing player tracker handles lifecycle, stream-out, selection and
    -- cleanup. V6 only changes rendering; it never recolours model interiors.
    -- Tags are positioned above the species' actual bounding box.
    local baseTracker=ctx.refreshTracker
    function ctx.refreshTracker(force)
        baseTracker(force)
        for _,r in pairs(S.byPlayer) do
            if r.h and r.h.Parent then
                r.h.FillTransparency=1
                r.h.OutlineTransparency=0
            end
            if r.b and r.b.Parent then
                r.b.Size=UDim2.fromOffset(148,20)
                r.b.AlwaysOnTop=S.flags.throughWalls
                r.b.MaxDistance=S.range
                r.b.Enabled=false -- v8 screen-projected names replace this billboard
                if S.flags.tags and r.char and r.b.Adornee
                    and r.b.Adornee:IsA("BasePart") then
                    local now=os.clock()
                    if now-(r.lastTagHeight or -math.huge)>=1.5 then
                        r.lastTagHeight=now
                        local ok,cf,size=pcall(function()
                            return r.char:GetBoundingBox()
                        end)
                        if ok and cf and size then
                            local top=cf.Position.Y+size.Y*.5
                            local head=r.b.Adornee.Position.Y
                            r.tagOffset=math.clamp(top-head+.7,.6,8)
                        end
                    end
                end
                r.b.StudsOffsetWorldSpace=Vector3.new(0,r.tagOffset or 2.4,0)
                if r.name then
                    local plate=r.name.Parent
                    if plate then
                        plate.BackgroundTransparency=1
                        for _,item in ipairs(plate:GetChildren()) do
                            if item:IsA("UIStroke") then item.Enabled=false end
                        end
                    end
                    r.name.Position=UDim2.new(0,0,0,0)
                    r.name.Size=UDim2.fromScale(1,1)
                    r.name.TextSize=11
                    r.name.TextXAlignment=Enum.TextXAlignment.Center
                    r.name.TextStrokeColor3=C.bg
                    r.name.TextStrokeTransparency=.14
                end
                if r.info then r.info.Visible=false end
                if r.fill and r.fill.Parent then
                    r.fill.Parent.Visible=false
                end
            end
        end
    end

    -- One endurance switch combines tested-in-prior-users client 3x local
    -- controller recovery and the own-character debug no-drain flag.
    -- It is not a claimed server-side resource grant.
    local function endurance(on)
        if on then
            P.setStamina("RECOVER")
            if P.stamina=="RECOVER" and not P.noDrain then
                P.toggleNoDrain()
            end
        else
            if P.noDrain then P.toggleNoDrain() end
            P.disableStamina(true)
            ctx.notice("Endurance OFF. Client settings restored where owned.")
        end
    end
    local function enduranceOn()
        return P.stamina=="RECOVER" and P.noDrain
    end
    -- One agility toggle instead of choosing three speed and leap tiers.
    local function agility(on)
        if on then
            P.setSpeed(1.30)
            P.setLeap(1.35)
            ctx.toggle("mobility",true)
            if P.speed~=1.30 or P.leap~=1.35 then
                P.setSpeed(1)
                P.setLeap(1)
                ctx.toggle("mobility",false)
                ctx.notice("Agility unavailable on this animal/client. Restored.")
            end
        else
            P.setSpeed(1)
            P.setLeap(1)
            ctx.toggle("mobility",false)
        end
    end
    local function agilityOn()
        return P.speed==1.30 and P.leap==1.35
    end

    -- CLEAR VIEW uses the established local vision switch and reversible
    -- local atmosphere/fog edits. No environment object deletion.
    -- Only optional visual preferences persist between launches.
    -- Power/escape choices do not silently auto-enable from an old session.
    local displayFile="FERAL_NovaPrime_Display_v32.json"
    local function readDisplay()
        local default={tags=true,walls=true,range=450}
        if type(readfile)~="function" then return default end
        local ok,value=pcall(function()
            return HttpService:JSONDecode(readfile(displayFile))
        end)
        if not ok or type(value)~="table" then return default end
        if type(value.tags)=="boolean" then default.tags=value.tags end
        if type(value.walls)=="boolean" then default.walls=value.walls end
        if value.range==450 or value.range==900 then default.range=value.range end
        return default
    end
    local function saveDisplay()
        if type(writefile)~="function" then return end
        pcall(function()
            writefile(displayFile,HttpService:JSONEncode({
                tags=S.flags.tags,
                walls=S.flags.throughWalls,
                range=S.range
            }))
        end)
    end
    local displayPrefs=readDisplay()
    local fogLease={}
    local function clearFog()
        for i=#fogLease,1,-1 do
            local e=fogLease[i]
            pcall(function()
                if e.obj.Parent and e.obj[e.key]==e.wanted then
                    e.obj[e.key]=e.old
                end
            end)
        end
        table.clear(fogLease)
    end
    local function fogSet(obj,key,wanted)
        if not obj then return end
        pcall(function()
            local old=obj[key]
            if type(old)=="number" and old~=wanted then
                obj[key]=wanted
                fogLease[#fogLease+1]={obj=obj,key=key,old=old,wanted=wanted}
            end
        end)
    end
    local function view(on)
        if on then
            ctx.toggle("vision",true)
            if S.flags.vision then
                clearFog()
                fogSet(Lighting,"FogEnd",100000)
                local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere")
                if atmosphere then
                    fogSet(atmosphere,"Density",.015)
                    fogSet(atmosphere,"Haze",0)
                end
            end
        else
            ctx.toggle("vision",false)
            clearFog()
        end
    end

    local shell=corner(make("Frame",{
        Size=UDim2.fromOffset(830,828),
        AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        BackgroundColor3=C.bg,BorderSizePixel=0,Active=true
    },gui),18)
    border(shell,.24)
    make("UIGradient",{
        Rotation=20,Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(17,34,54)),
            ColorSequenceKeypoint.new(.59,C.bg),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(22,17,42))
        })
    },shell)
    local scale=make("UIScale",{Scale=1},shell)
    local function fit()
        local cam=workspace.CurrentCamera
        local size=cam and cam.ViewportSize or Vector2.new(1280,800)
        scale.Scale=math.clamp(math.min(
            (size.X-22)/830,(size.Y-36)/828,1
        ),.32,1)
    end
    fit()

    local header=make("Frame",{
        Size=UDim2.new(1,0,0,68),
        BackgroundTransparency=1,Active=true
    },shell)
    corner(make("Frame",{
        Position=UDim2.fromOffset(18,17),
        Size=UDim2.fromOffset(5,37),
        BackgroundColor3=C.cyan,BorderSizePixel=0
    },header),3)
    local title=txt(header,"F E R A L   H U B",21,C.ink,true)
    title.Position=UDim2.fromOffset(37,11)
    title.Size=UDim2.fromOffset(360,27)
    local subtitle=txt(header,"v"..release.." RENAISSANCE  •  COBRA COMBAT",10,C.muted)
    subtitle.Position=UDim2.fromOffset(38,37)
    subtitle.Size=UDim2.fromOffset(385,20)
    local live=corner(make("Frame",{
        Position=UDim2.fromOffset(466,19),
        Size=UDim2.fromOffset(100,29),
        BackgroundColor3=C.tile,BorderSizePixel=0
    },header),8)
    border(live,.77)
    local liveText=txt(live,"●  GAME READY",10,C.cyan,true)
    liveText.Size=UDim2.fromScale(1,1)
    liveText.TextXAlignment=Enum.TextXAlignment.Center

    local hidden=false
    local show
    local function toggleMenu()
        hidden=not hidden
        shell.Visible=not hidden
        if show then show.Visible=hidden end
        if not hidden and type(ctx.onUI)=="function" then pcall(ctx.onUI)end
    end
    show=btn(gui,"✦  FERAL HUB",toggleMenu,130,37)
    show.Position=UDim2.fromOffset(16,220)
    show.Visible=false
    local minimize=btn(header,"—",toggleMenu,34,30)
    minimize.Position=UDim2.fromOffset(699,18)
    local exit=btn(header,"CLOSE",function()ctx.close()end,73,30)
    exit.Position=UDim2.fromOffset(742,18)
    exit.BackgroundColor3=Color3.fromRGB(85,43,60)

    local strip=corner(make("Frame",{
        Size=UDim2.fromOffset(794,60),
        Position=UDim2.fromOffset(18,73),
        BackgroundColor3=C.tile,BorderSizePixel=0
    },shell),12)
    border(strip,.80)
    local meters={}
    for i,caption in ipairs({"HEALTH","STAMINA","HUNGER","THIRST"}) do
        local x=14+(i-1)*197
        local label=txt(strip,caption,10,C.muted,true)
        label.Position=UDim2.fromOffset(x,7)
        label.Size=UDim2.fromOffset(105,18)
        local value=txt(strip,"--",12,C.ink,true)
        value.Position=UDim2.fromOffset(x+90,7)
        value.Size=UDim2.fromOffset(95,18)
        value.TextXAlignment=Enum.TextXAlignment.Right
        local track=corner(make("Frame",{
            Position=UDim2.fromOffset(x,37),
            Size=UDim2.fromOffset(181,7),
            BackgroundColor3=C.alt,BorderSizePixel=0
        },strip),4)
        local fill=corner(make("Frame",{
            Size=UDim2.fromScale(0,1),
            BackgroundColor3=(i==1 and C.danger
                or i==2 and C.cyan or C.violet),
            BorderSizePixel=0
        },track),4)
        meters[i]={value=value,fill=fill}
    end

    local buttons={}
    local function card(x,y,titleText,desc,glyph,getter,action,id)
        local cardFrame=corner(make("Frame",{
            Position=UDim2.fromOffset(x,y),
            Size=UDim2.fromOffset(386,78),
            BackgroundColor3=C.tile,BorderSizePixel=0
        },shell),11)
        border(cardFrame,.76)
        local iconBox=corner(make("Frame",{
            Size=UDim2.fromOffset(37,37),
            Position=UDim2.fromOffset(12,20),
            BackgroundColor3=C.alt,BorderSizePixel=0
        },cardFrame),10)
        local icon=txt(iconBox,glyph,19,C.cyan,true)
        icon.Size=UDim2.fromScale(1,1)
        icon.TextXAlignment=Enum.TextXAlignment.Center
        local cap=txt(cardFrame,titleText,13,C.ink,true)
        cap.Position=UDim2.fromOffset(60,12)
        cap.Size=UDim2.fromOffset(240,25)
        local descText=txt(cardFrame,desc,10,C.muted)
        descText.Position=UDim2.fromOffset(60,37)
        descText.Size=UDim2.fromOffset(246,22)
        -- Larger whole-card click area with the ON/OFF switch above it.
        local hit=btn(cardFrame,titleText,action,386,78)
        hit.Position=UDim2.fromOffset(0,0)
        hit.Name="CARD_"..id
        hit.BackgroundTransparency=1
        hit.TextTransparency=1
        hit.ZIndex=2
        local stroke=hit:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Enabled=false end
        local b=btn(cardFrame,"OFF",action,59,33)
        b.Position=UDim2.fromOffset(315,23)
        b.Name="TOGGLE_"..id
        b.ZIndex=3
        buttons[#buttons+1]={button=b,getter=getter,id=id}
        return b,descText
    end
    card(18,144,"ENDURANCE","Local stamina settings; server unverified","⚡",
        enduranceOn,function()endurance(not enduranceOn())end,"endurance")
    card(414,144,"AUTO ESCAPE","Only if captured • never drops your prey","↗",
        function()return Escape.enabled end,
        function()Escape.setEnabled(not Escape.enabled)end,"escape")
    card(18,231,"OUTLINE ESP","Clean outlines • never fills animals","◎",
        function()return S.flags.playerFinder end,
        function()ctx.toggle("playerFinder")end,"esp")
    card(414,231,"AGILITY","Local speed/leap and slow-assist inputs","➤",
        agilityOn,function()agility(not agilityOn())end,"agility")
    local regenButton,regenDesc=card(18,318,
        "ACTIVE RECOVERY","Native feeding protected • manual Rest preserved","✚",
        function()return Active.enabled end,
        function()
            Active.setEnabled(not Active.enabled)
            if Diag and Diag.mark then Diag.mark("recovery_toggle")end
        end,"active")
    card(414,318,"CLEAR VIEW","Local visual changes; reversible","◈",
        function()return S.flags.vision end,
        function()view(not S.flags.vision)end,"vision")

    local afkRobloxButton,afkRobloxDesc=card(18,410,
        "ANTI IDLE KICK","Best-effort virtual input to stay connected","◷",
        function()return AFK.robloxEnabled end,
        function()AFK.setRobloxEnabled(not AFK.robloxEnabled)end,"afkRoblox")
    local afkBonusButton,afkBonusDesc=card(414,410,
        "SURVIVAL AFK","Opt-in safe 6.5-stud movement for bonus","◇",
        function()return AFK.survivalEnabled end,
        function()AFK.setSurvivalEnabled(not AFK.survivalEnabled)end,"afkSurvival")

    local esp=corner(make("Frame",{
        Position=UDim2.fromOffset(18,503),
        Size=UDim2.fromOffset(794,52),
        BackgroundColor3=C.tile,BorderSizePixel=0
    },shell),11)
    border(esp,.79)
    local espTitle=txt(esp,"ESP DETAILS",11,C.muted,true)
    espTitle.Position=UDim2.fromOffset(14,14)
    espTitle.Size=UDim2.fromOffset(75,22)
    local tags=btn(esp,"TAGS",function()
        ctx.toggle("tags")
        saveDisplay()
    end,65,30)
    tags.Position=UDim2.fromOffset(91,11)
    local walls=btn(esp,"WALLS",function()
        ctx.toggle("throughWalls")
        saveDisplay()
    end,65,30)
    walls.Position=UDim2.fromOffset(163,11)
    local distance=btn(esp,"RANGE",function()
        ctx.setRange(S.range<650 and 900 or 450)
        saveDisplay()
    end,86,30)
    distance.Position=UDim2.fromOffset(234,11)
    local reachButton=btn(esp,"REACH",function()
        Reach.setEnabled(not Reach.enabled)
        ctx.onUI()
    end,82,30)
    reachButton.Position=UDim2.fromOffset(326,11)
    local waterButton=btn(esp,"SURFACE FLY",function()
        Flight.setEnabled(not Flight.enabled)
        ctx.onUI()
    end,96,30)
    waterButton.Position=UDim2.fromOffset(413,11)
    local carryButton=btn(esp,"CARRY  G",function()
        Carry.press()
        ctx.onUI()
    end,268,30)
    carryButton.Position=UDim2.fromOffset(514,11)

    local actions=corner(make("Frame",{
        Position=UDim2.fromOffset(18,565),
        Size=UDim2.fromOffset(794,44),
        BackgroundColor3=C.tile,BorderSizePixel=0
    },shell),10)
    border(actions,.79)
    local quickButton=btn(actions,"QUICK CLIMB",function()
        Climb.setEnabled(not Climb.enabled)
        ctx.onUI()
    end,153,29)
    quickButton.Position=UDim2.fromOffset(10,7)
    local babyButton=btn(actions,"BABY CARRY",function()
        Baby.setEnabled(not Baby.enabled)
        ctx.onUI()
    end,153,29)
    babyButton.Position=UDim2.fromOffset(170,7)
    local assistText=txt(actions,"Q buffered at tree • friendly pickups protected",11,C.muted)
    assistText.Position=UDim2.fromOffset(334,6)
    assistText.Size=UDim2.fromOffset(450,32)
    local experiments=corner(make("Frame",{
        Position=UDim2.fromOffset(18,618),
        Size=UDim2.fromOffset(794,64),
        BackgroundColor3=C.tile,BorderSizePixel=0
    },shell),10)
    border(experiments,.79)
    local expTitle=txt(experiments,"EAGLE LAB • EXPERIMENTAL • SERVER ACCEPTANCE UNVERIFIED",10,C.amber,true)
    expTitle.Position=UDim2.fromOffset(11,3)
    expTitle.Size=UDim2.fromOffset(760,20)
    local function expBtn(index,label,callback)
        local b=btn(experiments,label,callback,122,30)
        b.Position=UDim2.fromOffset(10+(index-1)*130,27)
        return b
    end
    local recoveryReportButton=expBtn(1,"RECOVERY STATUS",function()
        local copy=type(setclipboard)=="function" and setclipboard
            or type(toclipboard)=="function" and toclipboard
        if copy then pcall(function()
            copy(Active.report().."\n\n"..Native.report().."\n\n"..Regen.report().."\n\n"..Diag.report())
        end)end
        ctx.onUI()
    end)
    local growthTest=expBtn(2,"GROWTH (LOCAL)",function()
        Mechanics.setEnabled("growth",not Mechanics.enabled.growth)
        ctx.onUI()
    end)
    local carryTest=expBtn(3,"NATIVE CARRY ASSIST",function()
        Mechanics.setEnabled("carry",not Mechanics.enabled.carry)
        ctx.onUI()
    end)
    local cdTest=expBtn(4,"TALON READY ASSIST",function()
        Mechanics.setEnabled("cooldown",not Mechanics.enabled.cooldown)
        ctx.onUI()
    end)
    local profileTest=expBtn(5,"PRESET",function()
        Mechanics.cyclePreset()
        ctx.onUI()
    end)
    local grabAuto=expBtn(6,"AUTO PERFECT",function()
        Grab.setEnabled(not Grab.enabled)
        ctx.onUI()
    end)

    local footer=corner(make("Frame",{
        Position=UDim2.fromOffset(18,696),
        Size=UDim2.fromOffset(794,42),
        BackgroundColor3=Color3.fromRGB(13,22,36),BorderSizePixel=0
    },shell),10)
    local status=txt(footer,"ESCAPE: WATCHING • RIGHT SHIFT TO HIDE",11,C.muted)
    status.Position=UDim2.fromOffset(13,5)
    status.Size=UDim2.fromOffset(542,32)
    local feedbackUntil=0
    local feedback=""
    UI._showActionFeedback=function(label,ok,err)
        if not gui.Parent then return end
        feedback=(ok and "CLICK RECEIVED • " or "ACTION ERROR • ")..
            tostring(label):sub(1,24)
        if not ok then feedback=feedback.." • "..tostring(err):sub(1,65) end
        feedbackUntil=os.clock()+3.5
        status.Text=feedback
    end
    local reportButton=btn(footer,"COPY STATUS",function()
        local a=ctx.stats()
        local power=P.status()
        local report=Evidence.report().."\n\n"..Grab.report().."\n\n"..AFK.report().."\n\n"..Action.report().."\n\n"..Escape.report().."\n\n"..Carry.report().."\n\n"..Lab.report().."\n\n"..Reach.report().."\n\n"..Regen.report().."\n\n"..Diag.report().."\n\n"..Mechanics.report().."\n\n"..Eagle.report().."\n\n"..Native.report().."\n\n"..Climb.report().."\n\n"..Baby.report().."\n\n"..Mobile.report().."\n\n"..Flight.report().."\n\n"..Recovery.report().."\n\n"..P.enduranceReport().."\n"..Tags.report()..
            "\n\nFERAL v28 | Lease verification"..
            "\nendurance_cached_lease="..tostring(power.staminaMatches)..
            " stamina_profile="..tostring(power.stamina)..
            " own_no_drain_flag="..tostring(power.flag)..
            "\nspeed_cached_lease="..tostring(power.speedMatches)..
            " leap_cached_lease="..tostring(power.leapMatches)..
            " anti_slow_cached_flag="..tostring(S.flags.mobility)..
            "\nserver_stamina_and_movement_acceptance=UNVERIFIED"..
            "\ncurrent_growth="..tostring(player.Character and player.Character:GetAttribute("Growth"))..
            "\nendurance="..tostring(enduranceOn())..
            " agility="..tostring(agilityOn())..
            " antislow="..tostring(S.flags.mobility)..
            " visible_hp="..nfmt(a.hp).."/"..nfmt(a.maxHp)..
            " visible_stamina="..nfmt(a.stamina,1).."/"..nfmt(a.maxStamina,1)..
            "\nesp="..tostring(S.flags.playerFinder)..
            " tags="..tostring(S.flags.tags)..
            " walls="..tostring(S.flags.throughWalls)..
            " range="..tostring(S.range)..
            " tracked="..tostring(S.finderCounts.shown or 0)..
            "\nui_clicks="..tostring(buttonEvents.clicks)..
            " ui_button_errors="..tostring(buttonEvents.errors)..
            " ui_refresh_errors="..tostring(buttonEvents.refreshErrors)..
            " last_ui_button="..tostring(buttonEvents.lastButton)..
            " last_button_error="..tostring(buttonEvents.lastError)..
            " last_refresh_error="..tostring(buttonEvents.lastRefreshError)
        local copy=(type(setclipboard)=="function" and setclipboard)
            or (type(toclipboard)=="function" and toclipboard)
        local ok=copy and pcall(copy,report)
        feedback=ok and "STATUS COPIED • CARRY / ESCAPE / RECOVERY"
            or "CLIPBOARD NOT SUPPORTED BY EXECUTOR"
        feedbackUntil=os.clock()+3.5
        if not ok then warn("[NOVA PRIME] "..report) end
        ctx.onUI()
    end,103,31)
    reportButton.Position=UDim2.fromOffset(566,5)
    local reset=btn(footer,"RESET",function()
        endurance(false)
        agility(false)
        view(false)
        Lab.setEnabled(false)
        Flight.setEnabled(false)
        Active.setEnabled(false)
        Mobile.setEnabled(false)
        Climb.setEnabled(false)
        Baby.setEnabled(false)
        Reach.setEnabled(false)
        Mechanics.setEnabled("growth",false)
        Mechanics.setEnabled("carry",false)
        Mechanics.setEnabled("cooldown",false)
        Recovery.setEnabled(false)
        Escape.setEnabled(false)
        Grab.setEnabled(false)
        AFK.setRobloxEnabled(false)
        AFK.setSurvivalEnabled(false)
        clearFog()
        Diag.mark("hub_reset")
        ctx.reset()
        feedback="RESET APPLIED • ALL LOCAL FEATURE SWITCHES REQUESTED OFF"
        feedbackUntil=os.clock()+6
        ctx.notice("Local configurations reset; close/rejoin if old game state persists.")
    end,107,31)
    reset.Position=UDim2.fromOffset(673,5)
    reset.BackgroundColor3=Color3.fromRGB(84,42,57)

    -- All diagnostics are collected automatically from our own character only.
    -- The report is kept locally; there is no network upload or secret collection.
    local diagBar=corner(make("Frame",{
        Position=UDim2.fromOffset(18,746),
        Size=UDim2.fromOffset(794,63),
        BackgroundColor3=C.tile,BorderSizePixel=0
    },shell),10)
    border(diagBar,.79)
    local diagStatus=txt(diagBar,"DIAGNOSTICS STARTING  •  PRIVATE RUNNER COLLECTION",10,C.muted)
    diagStatus.Position=UDim2.fromOffset(12,6)
    diagStatus.Size=UDim2.fromOffset(768,20)
    local autoDiag=btn(diagBar,"AUTO FILE",function()
        Diag.setAutoSave(not Diag.autoSave)
        ctx.onUI()
    end,174,29)
    autoDiag.Position=UDim2.fromOffset(12,30)
    local saveDiag=btn(diagBar,"SAVE DIAG",function()
        Diag.mark("manual_save")
        local ok,msg=Diag.save()
        feedback=msg or (ok and "DIAGNOSTICS SAVED" or "SAVE FAILED")
        feedbackUntil=os.clock()+4
        ctx.onUI()
    end,140,29)
    saveDiag.Position=UDim2.fromOffset(196,30)
    local copyDiag=btn(diagBar,"COPY DIAG",function()
        Diag.mark("copy_report")
        local ok,msg=Diag.copy()
        feedback=msg or (ok and "DIAGNOSTICS COPIED" or "COPY FAILED")
        feedbackUntil=os.clock()+4
        ctx.onUI()
    end,140,29)
    copyDiag.Position=UDim2.fromOffset(346,30)
    local diagHint=txt(diagBar,"Private Windows runner · no public upload",10,C.muted)
    diagHint.Position=UDim2.fromOffset(502,30)
    diagHint.Size=UDim2.fromOffset(280,29)

    -- Persistent V2 guide / executor compatibility panel. Startup diagnostics remain
    -- accessible even after the guarded boot overlay disappears.
    local helpLayer=make("Frame",{
        Position=UDim2.fromOffset(18,73),
        Size=UDim2.fromOffset(794,738),
        BackgroundColor3=Color3.fromRGB(8,17,30),
        BorderSizePixel=0,Visible=false,ZIndex=30
    },shell)
    corner(helpLayer,14)
    border(helpLayer,.15)
    local helpHeading=txt(helpLayer,"FERAL HUB  /  GUIDE & COMPATIBILITY",19,C.cyan,true)
    helpHeading.Position=UDim2.fromOffset(22,18)
    helpHeading.Size=UDim2.fromOffset(660,36)
    helpHeading.ZIndex=31
    local helpBody=txt(helpLayer,
        "CLIENT CONTROLS vs GAME-SERVER RULES\n"..
        "Endurance, Agility, Reach, Growth and Talon Gate edit local inputs/settings.\n"..
        "Only observed replicated game outcomes count as evidence of real results.\n\n"..
        "EAGLE: An on-screen CATCH label does not guarantee a carry.\n"..
        "The hub separates physical holds from holds matching assisted targets.\n"..
        "A locally permitted CATCH indicator cannot override game-server carry limits.\n"..
        "Growth configuration does not establish faster server-recognised Elder growth.\n"..
        "Health: mobile Rest signal outside combat; never forces visible Rest.\n"..
        "Feeding/drinking pauses automatic Rest; it resumes after native feeding.\n"..
        "Native E feeding is prioritized even when Roblox marks input processed.\n"..
        "WolfFeed/FeedCan use eat/drink strings; feeding always outranks auto Rest.\n"..
        "Retired Safe Rest and Mobile A/B loops cannot compete with recovery.\n"..
        "Flight respects feed, grab and AFK action priorities.\n"..
        "Eagle native lunge reply monitor reconnects after remote replacement.\n"..
        "Talon target/press timestamps use explicit local/server clock comparison.\n"..
        "Grab V2 rejects late strikes from another active session.\n"..
        "Rest requests use 5s idle/3s wounded-motion cadence, subject to server.\n"..
        "Real mouse attacks pause auto Rest; nearby animals alone never do.\n"..
        "Roblox idle: virtual input heartbeat; retention not confirmed.\n"..
        "Survival AFK: opt-in short real walks on safe ground.\n"..
        "Grab V2: auto Perfect uses actual native strikes and timestamps.\n"..
        "Local Perfect timing does not guarantee server Perfect results.\n"..
        "No fake server survival credit is submitted.\n"..
        "Recovery resumes after attacks; real combat blocks it completely.\n"..
        "Repeated pose echoes trigger timed retry, not a lifetime shutdown.\n"..
        "Hunger/Thirst: normal game consumption takes action priority.\n"..
        "A local REST_MULT=4 is not proof of server 4x effect recovery.\n\n"..
        "CORE: real attacks, grabs and combat outrank automatic Rest.\n"..
        "Extended local bite hints cannot masquerade as actual native reach.\n"..
        "COORDINATION: Auto Escape protects against hostile grabs. Friendly baby\n"..
        "carrying is handled separately. Active Recovery pauses for unsafe actions.\n"..
        "Quick Climb buffers Q for 2.25s and retries one missed native mount tap.\n\n"..
        "KEYS: RIGHT SHIFT hide/show  |  END shutdown  |  Q climb  |  G carry\n"..
        "DIAGNOSTICS: The original v32 session report saves locally when supported.\n"..
        "A v7 session report records own HP, Hunger, Thirst and recovery status.\n"..
        "No new network telemetry is transmitted by this release.\n"..
        "New DATA dashboard shows measured movement, status and survival changes.\n"..
        "Evidence labels distinguish API calls from server-accepted results.",
        13,C.ink,false)
    helpBody.Position=UDim2.fromOffset(22,68)
    helpBody.Size=UDim2.fromOffset(742,425)
    helpBody.TextWrapped=true
    helpBody.TextTruncate=Enum.TextTruncate.None
    helpBody.TextYAlignment=Enum.TextYAlignment.Top
    helpBody.ZIndex=31
    local coreEvidence=txt(helpLayer,
        "CORE POLICY STARTING • HP and Grab server outcomes are not guaranteed",
        11,C.cyan,true)
    coreEvidence.Position=UDim2.fromOffset(22,489)
    coreEvidence.Size=UDim2.fromOffset(750,21)
    coreEvidence.ZIndex=31
    local helpFeedback=txt(helpLayer,"Potassium APIs are optional: unsupported features are reported, not forced.",11,C.muted)
    helpFeedback.Position=UDim2.fromOffset(22,509)
    helpFeedback.Size=UDim2.fromOffset(733,29)
    helpFeedback.ZIndex=31
    local function helpCopy(text)
        local copy=type(setclipboard)=="function" and setclipboard
            or type(toclipboard)=="function" and toclipboard
        if type(copy)~="function" then
            helpFeedback.Text="Clipboard API not available; use saved report files."
            return
        end
        local ok=pcall(copy,text)
        helpFeedback.Text=ok and "Copied to clipboard." or "Clipboard request failed."
    end
    local copyBoot=btn(helpLayer,"COPY BOOT REPORT",function()
        local boot=ctx.hubBuild
        if boot and type(boot.bootReport)=="function" then
            local ok,result=pcall(boot.bootReport)
            if ok then helpCopy(tostring(result)) else helpFeedback.Text="Boot report unavailable." end
        else
            helpFeedback.Text="Boot report not available in this environment."
        end
    end,199,36)
    copyBoot.Position=UDim2.fromOffset(22,560)
    copyBoot.ZIndex=31
    local copySession=btn(helpLayer,"COPY SESSION",function()
        local boot=ctx.hubBuild
        if boot and type(boot.sessionReport)=="function" then
            local ok,result=pcall(boot.sessionReport)
            if ok then helpCopy(tostring(result)) else helpFeedback.Text="Session report unavailable." end
        else
            helpCopy(Diag.report())
        end
    end,185,36)
    copySession.Position=UDim2.fromOffset(236,560)
    copySession.ZIndex=31
    local selfCheck=btn(helpLayer,"RUN SELF-CHECK",function()
        local build=ctx.hubBuild
        if build and type(build.selfTest)=="function" then
            local ok,summary=pcall(build.selfTest)
            helpFeedback.Text=ok and tostring(summary):sub(1,95)
                or "Self-check failed: "..tostring(summary):sub(1,75)
        else
            helpFeedback.Text="This release does not expose the self-check."
        end
    end,150,36)
    selfCheck.Position=UDim2.fromOffset(432,560)
    selfCheck.ZIndex=31
    local copyGoals=btn(helpLayer,"COPY HEALTH + CARRY",function()
        helpCopy("FERAL NOVA v"..release.." / HEALTH AND EAGLE CARRY\n"..
            Active.report().."\n\n"..Native.report()..
            "\n\n"..Recovery.report().."\n\n"..Regen.report()..
            "\n\n"..Carry.report().."\n\n"..Eagle.report()..
            "\n\nNOTE=Real server healing and prohibited-size pickup remain subject to server rules.")
    end,199,29)
    copyGoals.Position=UDim2.fromOffset(22,602)
    copyGoals.ZIndex=31
    local copyCore=btn(helpLayer,"COPY CORE AUDIT",function()
        helpCopy(Action.report().."\n\n"..Native.report()..
            "\n\n"..Grab.report().."\n\n"..AFK.report()..
            "\nNOTE=Successful local input calls do not prove server credit.")
    end,174,29)
    copyCore.Position=UDim2.fromOffset(236,602)
    copyCore.ZIndex=31
    local closeHelp=btn(helpLayer,"BACK TO HUB",function()
        helpLayer.Visible=false
    end,169,36)
    closeHelp.Position=UDim2.fromOffset(598,560)
    closeHelp.ZIndex=31
    local dashboardLayer
    local helpButton=btn(header,"HELP",function()
        helpLayer.Visible=not helpLayer.Visible
        if dashboardLayer then dashboardLayer.Visible=false end
    end,55,30)
    helpButton.Position=UDim2.fromOffset(637,18)
    -- The panel cannot claim detection avoidance or live-game validation.
    helpButton.ZIndex=4
    dashboardLayer=make("Frame",{
        Position=UDim2.fromOffset(18,73),
        Size=UDim2.fromOffset(794,738),
        BackgroundColor3=Color3.fromRGB(8,17,30),
        BorderSizePixel=0,Visible=false,ZIndex=35
    },shell)
    corner(dashboardLayer,13)
    border(dashboardLayer,.15)
    local dashTitle=txt(dashboardLayer,
        "FERAL NOVA / LIVE GAMEPLAY EVIDENCE",19,C.cyan,true)
    dashTitle.Position=UDim2.fromOffset(22,19)
    dashTitle.Size=UDim2.fromOffset(650,35)
    dashTitle.ZIndex=36
    local dashSubtitle=txt(dashboardLayer,
        "Read-only own-animal measurements. Client action requests are NOT server proof.",
        11,C.muted,false)
    dashSubtitle.Position=UDim2.fromOffset(22,55)
    dashSubtitle.Size=UDim2.fromOffset(740,25)
    dashSubtitle.ZIndex=36
    local dashTab="SURVIVAL"
    local dashTabs={}
    local function chooseTab(tab)
        dashTab=tab
        for _,item in ipairs(dashTabs) do
            item.button.BackgroundColor3=item.label==tab and
                Color3.fromRGB(28,78,79) or C.alt
            item.button.TextColor3=item.label==tab and C.cyan or C.muted
        end
        if type(ctx.onUI)=="function" then pcall(ctx.onUI) end
    end
    for i,tab in ipairs({"SURVIVAL","COMBAT","ABILITIES","SYSTEM"}) do
        local t=tab
        local b=btn(dashboardLayer,t,function()chooseTab(t)end,172,38)
        b.Position=UDim2.fromOffset(22+(i-1)*187,98)
        b.ZIndex=36
        dashTabs[#dashTabs+1]={button=b,label=t}
    end
    local dashBody=txt(dashboardLayer,"Awaiting own animal data...",15,C.ink,false)
    dashBody.Position=UDim2.fromOffset(25,160)
    dashBody.Size=UDim2.fromOffset(742,405)
    dashBody.TextWrapped=true
    dashBody.TextYAlignment=Enum.TextYAlignment.Top
    dashBody.TextTruncate=Enum.TextTruncate.None
    dashBody.ZIndex=36
    local dashFoot=txt(dashboardLayer,
        "OBSERVED does not mean CAUSALLY PROVEN. No fabricated server events.",
        12,C.amber,false)
    dashFoot.Position=UDim2.fromOffset(25,583)
    dashFoot.Size=UDim2.fromOffset(742,37)
    dashFoot.TextWrapped=true
    dashFoot.ZIndex=36
    local copyEvidence=btn(dashboardLayer,"COPY EVIDENCE",function()
        helpCopy(Evidence.report().."\n\n"..Action.report())
    end,182,36)
    copyEvidence.Position=UDim2.fromOffset(22,662)
    copyEvidence.ZIndex=36
    local dashClose=btn(dashboardLayer,"BACK TO HUB",function()
        dashboardLayer.Visible=false
    end,165,36)
    dashClose.Position=UDim2.fromOffset(607,662)
    dashClose.ZIndex=36
    local dashButton=btn(header,"DATA",function()
        dashboardLayer.Visible=not dashboardLayer.Visible
        if dashboardLayer.Visible then
            helpLayer.Visible=false
            chooseTab(dashTab)
        end
    end,62,30)
    dashButton.Position=UDim2.fromOffset(569,18)
    dashButton.ZIndex=4
    chooseTab(dashTab)

    local connections={}
    local drag=false
    local dragOrigin,dragStart
    connections[#connections+1]=header.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch then
            -- The right side holds DATA, HELP, minimize and CLOSE controls.
            -- Do not begin dragging when those buttons receive a press.
            local x=input.Position.X-header.AbsolutePosition.X
            if x<0 or x>header.AbsoluteSize.X*.66 then return end
            drag=true;dragOrigin=input.Position;dragStart=shell.Position
        end
    end)
    connections[#connections+1]=UIS.InputChanged:Connect(function(input)
        if drag and (input.UserInputType==Enum.UserInputType.MouseMovement
            or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position-dragOrigin
            shell.Position=UDim2.new(
                dragStart.X.Scale,dragStart.X.Offset+delta.X,
                dragStart.Y.Scale,dragStart.Y.Offset+delta.Y
            )
        end
    end)
    connections[#connections+1]=UIS.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch then
            drag=false
        end
    end)
    connections[#connections+1]=UIS.InputBegan:Connect(function(input,processed)
        if UIS:GetFocusedTextBox() then return end
        -- Menu and emergency shutdown shortcuts work even if the game processed input.
        if input.KeyCode==Enum.KeyCode.RightShift then toggleMenu()
        elseif input.KeyCode==Enum.KeyCode.End then ctx.close()
        end
    end)

    local function styleButton(b,on,label)
        b.Text=label or (on and "ON" or "OFF")
        b.BackgroundColor3=on and Color3.fromRGB(28,78,79) or C.alt
        b.TextColor3=on and C.cyan or C.muted
    end
    local warned=false
    ctx.onUI=function()
        local ok,err=pcall(function()
            if not gui.Parent or not S.alive or not shell.Visible then return end
            local a=ctx.stats()
            local ev=Evidence.summary()
            local function numOrUnknown(n,decimals)
                if type(n)~="number" or n~=n then return "NOT YET MEASURED" end
                return string.format("%."..tostring(decimals or 2).."f",n)
            end
            if dashboardLayer.Visible then
                if dashTab=="SURVIVAL" then
                    dashBody.Text=table.concat({
                        "OWN ANIMAL HEALTH & INJURY (clean observation windows)",
                        "",
                        "Moving HP increase / second: "..numOrUnknown(ev.movingHealingRate),
                        "Stationary HP increase / second: "..numOrUnknown(ev.stationaryHealingRate),
                        "Moving vs stationary ratio: "..numOrUnknown(ev.movingToStillRatio).."x",
                        "Clean moving seconds: "..numOrUnknown(ev.movingSeconds,1),
                        "Clean stationary seconds: "..numOrUnknown(ev.stationarySeconds,1),
                        "",
                        "Broken-bone clearance moving / second: "..numOrUnknown(ev.injuryMovingRate),
                        "Broken-bone clearance stationary / second: "..numOrUnknown(ev.injuryStillRate),
                        "Bleeding clearance moving / second: "..numOrUnknown(ev.bleedMovingRate),
                        "Venom clearance moving / second: "..numOrUnknown(ev.venomMovingRate),
                        "",
                        "COMBAT NEGATIVE-EFFECT RECOVERY (native attribute samples)",
                        "Combat Rest tag alone permitted: YES",
                        "Combat Rest signal seconds: "..
                            numOrUnknown(Native.combatRestActiveSeconds,1),
                        "Combat status samples: "..tostring(Native.combatStatusSamples),
                        "Rate estimates: HELP > native report (auto_combat/baseline_combat)",
                        "NOTE: Rest requests alone do not establish server 4x.",
                        "",
                        "Observed stamina consumed: "..numOrUnknown(ev.staminaConsumed,1),
                        "Observed hunger lost: "..numOrUnknown(ev.hungerLost,1),
                        "Observed thirst lost: "..numOrUnknown(ev.thirstLost,1),
                        "Survival progress observed: "..numOrUnknown(ev.survivalIncrease,1)
                    },"\n")
                elseif dashTab=="COMBAT" then
                    dashBody.Text=table.concat({
                        "GAME COMBAT & NATIVE GRAB V2",
                        "",
                        "Current action priority: "..tostring(Action.lastPriority),
                        "Action policy denials: "..tostring(Action.denied),
                        "Action leases granted: "..tostring(Action.leaseCount),
                        "Current recovery status: "..tostring(Native.status),
                        "Manual Rest protected: "..tostring(Native.manualRest),
                        "",
                        "Native Grab V2 strike events: "..tostring(ev.minigameStrikes),
                        "Timed native presses sent: "..tostring(ev.minigamePresses),
                        "Recognised server Perfect replies: "..tostring(ev.confirmedServerPerfects),
                        "Last Grab status: "..tostring(Grab.status),
                        "",
                        "Auto Escape status: "..tostring(Escape.status),
                        "Native bite indicator: "..tostring(Lab.nativeReady),
                        "Extended target hint: "..tostring(Lab.ready),
                        "",
                        "NOTE: A locally-timed Perfect is not a guaranteed server Perfect."
                    },"\n")
                elseif dashTab=="ABILITIES" then
                    dashBody.Text=table.concat({
                        "EAGLE, TALON, FLIGHT AND CARRY EVIDENCE",
                        "",
                        "Server Eagle clamp replies: "..
                            tostring(Eagle.serverClampReplies),
                        "Physically held matching assisted target: "..
                            tostring(Eagle.actualClampObservations),
                        "Clamp reply without observed hold: "..
                            tostring(Eagle.serverClampWithoutObservedCarry),
                        "Native Eagle status: "..tostring(Eagle.status),
                        "",
                        "Local Talon gate enabled: "..
                            tostring(Mechanics.enabled.cooldown),
                        "Client Talon clock edits: "..
                            tostring(Eagle.cooldownAttrEdits),
                        "Native carry status: "..tostring(Carry.status),
                        "Native climbing: "..tostring(Climb.status),
                        "Flight assist: "..tostring(Flight.status),
                        "",
                        "NOTE: Oversized server-accepted carry and reduced Talon cooldown",
                        "are not established by client flags or a CATCH indicator."
                    },"\n")
                else
                    dashBody.Text=table.concat({
                        "HUB SYSTEMS, ACTION OWNERSHIP AND SHUTDOWN",
                        "",
                        "Build: FERAL NOVA v"..release,
                        "Modules loaded: 23",
                        "Action policy state: "..tostring(Action.lastPriority),
                        "Action policy snapshot reads: "..tostring(Action.reads),
                        "Cached state reads: "..tostring(Action.cacheHits),
                        "Denied unsafe actions: "..tostring(Action.denied),
                        "Action lease expirations: "..tostring(Action.expiredLeases),
                        "",
                        "Active Recovery: "..tostring(Active.status),
                        "Roblox anti-idle: "..tostring(AFK.robloxStatus),
                        "Survival AFK movement: "..tostring(AFK.survivalStatus),
                        "Evidence samples: "..tostring(Evidence.totalObservations),
                        "Evidence errors: "..tostring(Evidence.errorCount),
                        "",
                        "Right Shift: hide | End: safe shutdown | HELP: diagnostics",
                        "Only the owner can change actual game-server rules."
                    },"\n")
                end
            end
            local list={
                {a.hp,a.maxHp},{a.stamina,a.maxStamina},
                {a.hunger,100},{a.thirst,100}
            }
            for i,entry in ipairs(list) do
                local v,max=entry[1],entry[2]
                local ratio=type(v)=="number" and type(max)=="number" and max>0
                    and math.clamp(v/max,0,1) or 0
                meters[i].fill.Size=UDim2.fromScale(ratio,1)
                meters[i].value.Text=nfmt(v,i==2 and 1 or 0)..
                    (i<=2 and ("/"..nfmt(max)) or "%")
            end
            for _,item in ipairs(buttons) do
                if item.id=="active" then
                    styleButton(item.button,Active.enabled,
                        Active.mode=="NATIVE_RECOVERY" and "REST SIGNAL"
                            or Active.mode=="POSE_SAFE_CONFIG_ONLY" and "SAFE"
                            or Active.enabled and "ARMED" or "OFF")
                elseif item.id=="afkRoblox" then
                    styleButton(item.button,AFK.robloxEnabled,
                        AFK.robloxEnabled and "ARMED" or "OFF")
                elseif item.id=="afkSurvival" then
                    styleButton(item.button,AFK.survivalEnabled,
                        AFK.survivalEnabled and "SAFE" or "OFF")
                elseif item.id=="endurance" then
                    styleButton(item.button,item.getter(),
                        item.getter() and "CLIENT" or "OFF")
                elseif item.id=="agility" then
                    styleButton(item.button,item.getter(),
                        item.getter() and "CLIENT" or "OFF")
                else
                    styleButton(item.button,item.getter())
                end
            end
            coreEvidence.Text="PRIORITY "..tostring(Action.lastPriority)..
                "  •  MOVING HP + "..nfmt(Native.movingObservedHPGain,1)..
                "  •  GRAB PRESSES "..tostring(Grab.pressesSent)..
                "  •  SERVER OUTCOME: VERIFY"
            afkRobloxDesc.Text=AFK.robloxStatus
            afkBonusDesc.Text=AFK.survivalStatus
            diagStatus.Text=Diag.shortStatus().."  •  PRIVATE RUNNER SYNC"
            local observed=Diag.lastSnapshot or {}
            local inspect=Mechanics.inspect()
            local recoveryStatus=Active.mode=="MANUAL_REST"
                and "MANUAL REST / PRESERVED" or Active.mode=="COMBAT_BLOCKED"
                and "REST OFF / COMBAT" or Active.mode=="NATIVE_RECOVERY"
                and "MOBILE REST SIGNAL" or Active.mode
            expTitle.Text=UI.eagleSummary(Eagle,recoveryStatus)
            local waterStatus=Flight.underwater and "UNDERWATER" or
                Flight.surfaceEligible and "FLOATING" or Flight.airborne and "FLYING" or "NORMAL"
            diagHint.Text="WATER "..waterStatus..
                "  EXIT OK "..Flight.underwaterExitConfirmed..
                " / UNCONFIRMED "..Flight.underwaterExitUnconfirmed
            styleButton(autoDiag,Diag.autoSave,Diag.autoSave and "AUTO SAVE EVERY 25s" or "FILE SAVE OFF")
            recoveryReportButton.Text=Active.mode=="MANUAL_REST" and "MANUAL REST"
                or Active.mode=="COMBAT_BLOCKED" and "COMBAT PAUSE"
                or Active.mode=="NATIVE_RECOVERY" and "REST REQUEST"
                or Active.mode=="POSE_SAFE_CONFIG_ONLY" and "POSE GUARDED"
                or Active.mode=="PAUSED_FOR_ACTION" and "ACTION BLOCKED"
                or Active.mode=="NO_RECOVERY_NEEDED" and "HP FULL"
                or "RECOVERY STATUS"
            styleButton(growthTest,Mechanics.enabled.growth,"GROWTH "..(Mechanics.enabled.growth and "ON" or "OFF"))
            styleButton(carryTest,Mechanics.enabled.carry,"CARRY ASSIST "..(Mechanics.enabled.carry and "ON" or "OFF"))
            styleButton(cdTest,Mechanics.enabled.cooldown,"TALON GATE "..(Mechanics.enabled.cooldown and "ON" or "OFF"))
            profileTest.Text="PRESET "..Mechanics.preset().name
            styleButton(grabAuto,Grab.enabled,
                Grab.enabled and (Grab.activeSession and "AUTO TIMING" or "AUTO ARMED")
                    or "AUTO OFF")
            styleButton(tags,S.flags.tags,"TAGS "..(S.flags.tags and "ON" or "OFF"))
            styleButton(walls,S.flags.throughWalls,"WALLS "..(S.flags.throughWalls and "ON" or "OFF"))
            distance.Text="RANGE "..tostring(S.range)
            styleButton(quickButton,Climb.enabled,
                Climb.enabled and "Q CLIMB ON" or "Q CLIMB OFF")
            styleButton(babyButton,Baby.enabled,
                Baby.enabled and "BABY CARRY ON" or "BABY CARRY OFF")
            assistText.Text=Climb.queued and "Q QUEUED • APPROACH A TREE"
                or Baby.active and ("FRIENDLY PICKUP • "..Baby.lastEvidence)
                or Native.active and "RECOVERY SIGNAL ACTIVE • ACTIONS TAKE PRIORITY"
                or Climb.status
            styleButton(reachButton,Reach.enabled,
                Reach.applied and "REACH ON" or Reach.enabled and "REACH ?" or "REACH OFF")
            styleButton(waterButton,Flight.enabled,
                Flight.applied and "SURFACE ON" or Flight.enabled and "SURFACE ?" or "SURFACE OFF")
            regenDesc.Text=Active.enabled and Active.status or "RECOVERY OFF"
            regenDesc.TextColor3=Active.mode=="NATIVE_RECOVERY" and C.cyan or C.muted
            local carryLabel=Carry.victim and "ESCAPE FIRST"
                or Carry.holding and "DROP / RELEASE"
                or Carry.canInteract and "CARRY / PICK"
                or "USE G"
            styleButton(carryButton,Carry.holding or Carry.canInteract,carryLabel)
            if os.clock()<feedbackUntil then
                status.Text=feedback
            else
                local primary=Grab.activeSession
                    and ("GRAB V2 • "..Grab.status)
                    or Baby.active and ("FRIENDLY PICKUP • NO AUTO GETOFF")
                    or Carry.victim and ("CAPTURED • "..Escape.status)
                    or Carry.holding and ("CARRYING • "..Carry.state.." • G TO DROP")
                    or Escape.active and ("ESCAPING • "..Escape.status)
                    or Lab.ready and "BITE WINDOW (CLIENT)" or Lab.status
                if Recovery.snapshot then Recovery.snapshot()end
                local secondary=Active.enabled and ("RECOVERY: "..Active.status)
                    or Climb.queued and "QUICK CLIMB QUEUED"
                    or Flight.water and Flight.enabled
                    and ("WATER: "..Flight.status)
                    or (Regen.enabled and Regen.applied
                        and "CLIENT RECOVERY INPUTS ACTIVE • SERVER UNVERIFIED")
                    or (Reach.enabled and Reach.applied
                        and "CLIENT BITE REACH ACTIVE")
                    or Recovery.multiplier==.30 and "TURTLE SHELL RULE (UNVERIFIED)"
                    or ""
                status.Text=primary..
                    (secondary~="" and ("  •  "..secondary) or "")
            end
            if a.sessionPhase=="IN GAME" then
                if Recovery.multiplier==.30 then
                    liveText.Text="●  SHELL RULE (CLIENT)"
                    liveText.TextColor3=C.cyan
                elseif type(a.hp)=="number" and type(a.maxHp)=="number"
                    and a.maxHp>0 and a.hp/a.maxHp<.25 then
                    liveText.Text="●  LOW HEALTH"
                    liveText.TextColor3=C.danger
                elseif type(a.hunger)=="number" and a.hunger<20
                    or type(a.thirst)=="number" and a.thirst<20 then
                    liveText.Text="●  LOW NEEDS"
                    liveText.TextColor3=C.amber
                else
                    liveText.Text="●  IN GAME"
                    liveText.TextColor3=C.cyan
                end
            else
                liveText.Text="●  MENU"
                liveText.TextColor3=C.muted
            end
            if shell.Visible then fit()end
        end)
        if not ok then
            buttonEvents.refreshErrors+=1
            buttonEvents.lastRefreshError=tostring(err):sub(1,240)
            feedback="UI REFRESH ERROR • "..tostring(err):sub(1,65)
            feedbackUntil=os.clock()+5
            status.Text=feedback
            if not warned then
                warned=true;warn("[NOVA PRIME] UI: "..tostring(err))
            end
        end
    end
    UI._requestRefresh=function()
        if ctx.onUI then ctx.onUI() end
    end
    ctx.onNotice=function()end
    ctx.cleanupUI=function()
        UI._buttonEvents=nil
        UI._requestRefresh=nil
        UI._showActionFeedback=nil
        -- Flush and terminate the recorder before restoring game-side modules.
        pcall(function()Diag.close()end)
        pcall(function()Evidence.close()end)
        pcall(function()Active.close()end)
        pcall(function()Grab.close()end)
        pcall(function()AFK.close()end)
        pcall(function()Action.close()end)
        pcall(function()Eagle.close()end)
        pcall(function()Native.close()end)
        pcall(function()Climb.close()end)
        pcall(function()Baby.close()end)
        pcall(function()Flight.close()end)
        pcall(function()Mobile.close()end)
        pcall(function()Regen.close()end)
        pcall(function()Mechanics.close()end)
        pcall(function()Reach.close()end)
        pcall(function()Carry.close()end)
        pcall(function()Lab.close()end)
        pcall(function()Recovery.close()end)
        pcall(function()Tags.close()end)
        pcall(function()Escape.close()end)
        pcall(clearFog)
        for _,cn in ipairs(connections) do
            pcall(function()cn:Disconnect()end)
        end
    end

    -- Practical defaults: no setup needed to see other animals or escape.
    S.flags.tags=displayPrefs.tags
    ctx.toggle("playerFinder",true)
    ctx.toggle("throughWalls",displayPrefs.walls)
    ctx.toggle("alerts",false)
    ctx.setRange(displayPrefs.range)
    -- Proven-compatible defaults preserved. Guarded native Rest only
    -- runs outside combat and now consults the v9 action policy.
    endurance(true)
    Reach.setEnabled(true)
    Flight.setEnabled(true)
    Climb.setEnabled(true)
    Baby.setEnabled(true)
    Active.setEnabled(true)
    AFK.setRobloxEnabled(true)
    -- No unrequested character movement from opening the hub.
    -- Explicitly opt in with the SURVIVAL AFK toggle.
    AFK.setSurvivalEnabled(false)
    Grab.setEnabled(true)
    ctx.refreshTracker(true)
    ctx.onUI()
    return gui
end
return UI
]==========]
,["feral-nova-mechanics-v28.0.lua"]=[==========[
-- FERAL HUB v5 / stage-aware and balanced Eagle growth measurements; client-only mechanics
-- Disabled by default. Changes are reversible and server effects are NOT asserted.
-- Existing Endurance, HP/status recovery, escape, baby carry, ESP and climb modules own their states.
local Mechanics={}
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
function Mechanics.attach(ctx)
    local M={
        alive=true,enabled={growth=false,carry=false,cooldown=false},
        profile=2,applied=0,status="Experimental mechanics OFF",
        featureApplied={growth=0,carry=0,cooldown=0},localLeaseOverwrites=0,
        lastFields={},
        localOnly=true,errors={},observed={},
        growthEvidence={on={seconds=0,delta=0,samples=0},off={seconds=0,delta=0,samples=0}},
        growthResets=0,measuredGrowth=nil,
        growthByStage={young={on={seconds=0,delta=0,samples=0},off={seconds=0,delta=0,samples=0}},elder={on={seconds=0,delta=0,samples=0},off={seconds=0,delta=0,samples=0}}},
        growthQuality="INSUFFICIENT_BALANCED_DATA",growthOnOffComparable=false,
        growthTrialMinimumSeconds=120,growthStageTransitions=0,
    }
    local presets={
        {name="CONSERVATIVE",growth=2,carry=2,seconds=5},
        {name="BALANCED",growth=3,carry=3,seconds=1.5},
        {name="AGGRESSIVE",growth=6,carry=5,seconds=.5}
    }
    -- Compare observed own Eagle Growth while the local switch is on/off.
    -- This never edits the Growth attribute and does not imply causation.
    local own=Players.LocalPlayer
    local lastChar=nil
    local lastValue=nil
    local lastAt=nil
    local lastMode=nil
    local lastStage=nil
    local growthConnection
    local function resetGrowthSample()
        lastValue=nil
        lastAt=nil
        lastMode=nil
        lastStage=nil
    end
    local function sampleGrowth()
        if not M.alive then return end
        local char=own and own.Character
        if char~=lastChar then
            lastChar=char
            resetGrowthSample()
            M.growthResets+=1
        end
        if not char or char:GetAttribute("Species")~="Eagle" then
            resetGrowthSample()
            return
        end
        local value=char:GetAttribute("Growth")
        if type(value)~="number" or value~=value or value<0 or value>1e6 then
            resetGrowthSample()
            return
        end
        local now=os.clock()
        local enabled=M.enabled.growth==true
        local stage=value>=1 and "elder" or "young"
        local mode=enabled and "on" or "off"
        if lastAt and lastMode==enabled and now>lastAt then
            local dt=now-lastAt
            local delta=value-lastValue
            if dt<=5 and delta>=0 and delta<=.15 then
                local b=M.growthEvidence[mode]
                b.seconds+=dt
                b.delta+=delta
                b.samples+=1
                -- Only compare within the same stage; stage changes alter
                -- natural rate and would otherwise bias ON/OFF estimates.
                if lastStage==stage then
                    local g=M.growthByStage[stage][mode]
                    g.seconds+=dt
                    g.delta+=delta
                    g.samples+=1
                else
                    M.growthStageTransitions+=1
                end
            else
                M.growthResets+=1
            end
        end
        local young=M.growthByStage.young
        M.growthOnOffComparable=
            young.on.seconds>=M.growthTrialMinimumSeconds and
            young.off.seconds>=M.growthTrialMinimumSeconds and
            young.on.samples>=60 and young.off.samples>=60
        M.growthQuality=M.growthOnOffComparable
            and "BALANCED_YOUNG_EAGLE_OBSERVATIONS_ONLY"
            or "INSUFFICIENT_MATCHED_STAGE_CONTROL"
        M.measuredGrowth=value
        lastValue=value
        lastAt=now
        lastMode=enabled
        lastStage=stage
    end
    local lastPoll=0
    growthConnection=RunService.Heartbeat:Connect(function()
        local now=os.clock()
        if now-lastPoll>=1 then
            lastPoll=now
            pcall(sampleGrowth)
        end
    end)
    local original={}
    local cached={}
    local valid={growth=true,carry=true,cooldown=true}
    local function get(name)
        if cached[name] then return cached[name] end
        local world=RS:FindFirstChild("FeralWorld")
        local scriptNode=world and world:FindFirstChild(name)
        if not scriptNode or not scriptNode:IsA("ModuleScript") then
            M.errors[name]="module not found"
            return nil
        end
        local ok,value=pcall(require,scriptNode)
        if ok and type(value)=="table" then
            cached[name]=value
            M.errors[name]=nil
            return value
        end
        M.errors[name]=ok and "not a table" or tostring(value)
        return nil
    end
    local function lease(t,k,v)
        if type(t)~="table" or rawget(t,k)==nil or type(rawget(t,k))~=type(v) then return false end
        local previous=rawget(t,k)
        if previous==v then return false end
        local ok=pcall(function()t[k]=v end)
        if not ok or rawget(t,k)~=v then return false end
        original[#original+1]={t=t,k=k,previous=previous,wanted=v}
        return true
    end
    local function restore()
        for i=#original,1,-1 do
            local row=original[i]
            pcall(function()
                -- Do not overwrite a value subsequently changed by another controller.
                if rawget(row.t,row.k)==row.wanted then
                    row.t[row.k]=row.previous
                end
            end)
            original[i]=nil
        end
        M.applied=0
        M.featureApplied={growth=0,carry=0,cooldown=0}
        M.lastFields={}
    end
    local function recalc()
        if not M.alive then return false end
        restore()
        local p=presets[M.profile]
        local count=0
        local feature={growth=0,carry=0,cooldown=0}
        local changed={}
        local function change(t,k,v,which)
            if lease(t,k,v) then
                count+=1
                feature[which]+=1
                changed[#changed+1]=which.."."..k
            end
        end
        if M.enabled.growth then
            local species=get("Species")
            local growth=get("GrowthConfig")
            -- The public server can maintain Growth independently of these client inputs.
            local mins=species and species.ADULT_MINUTES
            if mins and type(mins.Eagle)=="number" then
                change(mins,"Eagle",math.max(.5,mins.Eagle/p.growth),"growth")
            elseif species and type(species.List)=="table" and type(species.List.Eagle)=="table" then
                local eagle=species.List.Eagle
                if type(eagle.growthMinutes)=="number" then
                    change(eagle,"growthMinutes",math.max(.5,eagle.growthMinutes/p.growth),"growth")
                end
            end
            if growth then
                if type(rawget(growth,"ELDER_RATE"))=="number" then change(growth,"ELDER_RATE",growth.ELDER_RATE*p.growth,"growth") end
                if type(rawget(growth,"CUB_BOOST"))=="number" then change(growth,"CUB_BOOST",math.max(growth.CUB_BOOST,p.growth),"growth") end
            end
        end
        if M.enabled.carry then
            local abilities=get("AbilityConfig")
            local talon=abilities and abilities.Talon
            if talon then
                change(talon,"CARRY_RATIO",p.carry,"carry")
                change(talon,"NO_ELDER_LIFT",false,"carry")
            end
        end
        if M.enabled.cooldown then
            local abilities=get("AbilityConfig")
            local talon=abilities and abilities.Talon
            if talon then
                for _,key in ipairs({"FLAT_COOLDOWN","COOLDOWN","MISS_COOLDOWN"}) do
                    if type(rawget(talon,key))=="number" then change(talon,key,p.seconds,"cooldown") end
                end
            end
            local flight=get("FlightConfig")
            local stoop=flight and flight.STOOP
            if stoop then
                for _,key in ipairs({"CD_PICK","CD_CANCEL","CD_EMPTY"}) do
                    if type(rawget(stoop,key))=="number" then change(stoop,key,p.seconds,"cooldown") end
                end
            end
        end
        M.applied=count
        M.featureApplied=feature
        M.lastFields=changed
        local enabledCount=(M.enabled.growth and 1 or 0)+(M.enabled.carry and 1 or 0)+(M.enabled.cooldown and 1 or 0)
        M.status=enabledCount==0 and "Experimental mechanics OFF"
            or (tostring(count).." local config fields changed; server effects unverified")
        return true
    end
    function M.setEnabled(feature,on)
        if not M.alive or not valid[feature] then return false end
        if feature=="growth" then resetGrowthSample()end
        M.enabled[feature]=on==true
        return recalc()
    end
    function M.cyclePreset()
        if not M.alive then return nil end
        M.profile=M.profile%#presets+1
        recalc()
        return presets[M.profile]
    end
    function M.preset()
        return presets[M.profile]
    end
    function M.inspect()
        local intact=0
        local overwritten=0
        for _,row in ipairs(original) do
            if rawget(row.t,row.k)==row.wanted then intact+=1 else overwritten+=1 end
        end
        M.localLeaseOverwrites=overwritten
        return {intact=intact,overwritten=overwritten,
            features=M.featureApplied,fields=M.lastFields}
    end
    function M.report()
        local p=presets[M.profile]
        local inspection=M.inspect()
        local parts={
            "FERAL v25 EXPERIMENTAL MECHANICS / LOCAL CONFIG ONLY",
            "growth="..tostring(M.enabled.growth).." carry="..tostring(M.enabled.carry).." cooldown="..tostring(M.enabled.cooldown),
            "preset="..p.name.." growth_factor="..p.growth.." carry_ratio="..p.carry.." cooldown_seconds="..p.seconds,
            "locally_changed_fields="..M.applied,
            "local_fields_still_applied="..inspection.intact,
            "local_fields_overwritten="..inspection.overwritten,
            "growth_fields_changed="..M.featureApplied.growth,
            "carry_fields_changed="..M.featureApplied.carry,
            "cooldown_fields_changed="..M.featureApplied.cooldown,
            "changed_local_fields="..table.concat(M.lastFields,","),
            "observed_eagle_growth="..tostring(M.measuredGrowth),
            "growth_observation_resets="..tostring(M.growthResets),
            "growth_stage_transitions="..tostring(M.growthStageTransitions),
            "growth_trial_quality="..M.growthQuality,
            "growth_balanced_young_eagle="..tostring(M.growthOnOffComparable),
            "young_growth_on_seconds="..string.format("%.1f",M.growthByStage.young.on.seconds),
            "young_growth_off_seconds="..string.format("%.1f",M.growthByStage.young.off.seconds),
            "young_growth_on_per_minute="..string.format("%.5f",
                M.growthByStage.young.on.seconds>0 and
                60*M.growthByStage.young.on.delta/M.growthByStage.young.on.seconds or 0),
            "young_growth_off_per_minute="..string.format("%.5f",
                M.growthByStage.young.off.seconds>0 and
                60*M.growthByStage.young.off.delta/M.growthByStage.young.off.seconds or 0),
            "growth_on_seconds="..string.format("%.1f",M.growthEvidence.on.seconds),
            "growth_on_delta="..string.format("%.4f",M.growthEvidence.on.delta),
            "growth_on_per_minute="..string.format("%.5f",
                M.growthEvidence.on.seconds>0 and
                60*M.growthEvidence.on.delta/M.growthEvidence.on.seconds or 0),
            "growth_off_seconds="..string.format("%.1f",M.growthEvidence.off.seconds),
            "growth_off_delta="..string.format("%.4f",M.growthEvidence.off.delta),
            "growth_off_per_minute="..string.format("%.5f",
                M.growthEvidence.off.seconds>0 and
                60*M.growthEvidence.off.delta/M.growthEvidence.off.seconds or 0),
            "NOTE=Only same-stage Eagle measurements qualify for a comparison; each mode requires 120 seconds and 60 samples.",
            "NOTE=Observed growth with a local switch does not prove causation or server acceptance.",
            "NOTE=Any field marked applied is LOCAL ONLY, not a server-accepted mechanic.",
            "SERVER_GROWTH_ACCEPTANCE=UNVERIFIED",
            "SERVER_CARRY_ACCEPTANCE=UNVERIFIED",
            "SERVER_TALON_COOLDOWN_ACCEPTANCE=UNVERIFIED"
        }
        for name,err in pairs(M.errors) do parts[#parts+1]=name.."_error="..err end
        return table.concat(parts,"\n")
    end
    function M.close()
        if not M.alive then return end
        M.alive=false
        if growthConnection then pcall(function()growthConnection:Disconnect()end)end
        growthConnection=nil
        restore()
        M.enabled.growth=false
        M.enabled.carry=false
        M.enabled.cooldown=false
    end
    if type(ctx)=="table" then ctx.mechanics=M end
    return M
end
return Mechanics
]==========]
,["feral-nova-diagnostics-v32.0.lua"]=[==========[
-- FERAL HUB v7 / verified own HP observations during mobile Rest signal versus combat state
-- Privacy: never includes names, IDs, chats, coordinates, player lists or external URLs.
-- Captures own character and controller state. No background network transmission.
-- Auto-saves to the executor workspace when writefile is available.
local Diagnostics={}
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local HttpService=game:GetService("HttpService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local function finite(v)
    return type(v)=="number" and v==v and v<1e9 and v>-1e9
end
local function rounded(v)
    if not finite(v) then return nil end
    return math.floor(v*1000+.5)/1000
end
local function attribute(obj,name)
    if not obj then return nil end
    local ok,value=pcall(function()return obj:GetAttribute(name)end)
    if ok then return value end
end
local function numericAttr(obj,name)
    return rounded(attribute(obj,name))
end
local function yes(value)
    return value==true
end
local function swimmingState(hum)
    if not hum then return false end
    local ok,value=pcall(function()
        return hum:GetState()==Enum.HumanoidStateType.Swimming
    end)
    return ok and value==true
end
local function cleanText(v)
    -- Only record the game's species label, never arbitrary object names.
    if type(v)~="string" then return "unknown" end
    local allow={Bear=true,Eagle=true,Falcon=true,Vulture=true,Wolf=true,Tiger=true,
        Lion=true,Fox=true,Rabbit=true,Deer=true,Elk=true,Boar=true,Rhino=true,
        Elephant=true,Hippo=true,Crocodile=true,SnappingTurtle=true}
    return allow[v] and v or "other"
end
local function bounded(list,entry,limit)
    list[#list+1]=entry
    if #list>limit then table.remove(list,1) end
end
local function safeClock()
    local ok,n=pcall(function()return Workspace:GetServerTimeNow()end)
    return ok and finite(n) and n or nil
end
function Diagnostics.attach(ctx)
    if not player then return nil end
    local D={
        alive=true,enabled=true,autoSave=(type(writefile)=="function"),
        autoSavePeriod=25,saveFile="FERAL_NOVA_v32_session.json",
        status="Starting own-client diagnostics",saveStatus="No file yet",
        samples={},events={},maxSamples=720,maxEvents=180,
        transitions=0,samplesTotal=0,deathCount=0,respawns=0,climbTapStarts=0,
        attackInputs=0,climbInputs=0,carryInputs=0,spaceInputs=0,
        lungeStarts=0,clampStarts=0,escapeStarts=0,
        talonPresses=0,talonPendingStarts=0,
        talonLocalClampsAfterPress=0,talonSustainedLocalClamps=0,
        talonHoldSeconds=0,longestLocalHoldSeconds=0,
        talonObservedShortCooldownEvents=0,talonObservedLongCooldownEvents=0,
        talonPressIntervalSeconds=0,talonPressIntervals=0,
        lastTalonPressT=nil,holdStartedAt=nil,sustainedHoldMarked=false,
        healthGained=0,healthLost=0,staminaGained=0,staminaLost=0,
        growthGained=0,statusCleared={bleed=0,venom=0,injury=0},
        growthTrials={},staminaModes={},cdTrials={},cooldownTotalJumps=0,
        noDrainMissingSeconds=0,
        modes={},lastSnapshot=nil,lastSaveAt=-math.huge,lastAutoAt=-math.huge,
        lastEvent="",session=0,lastReportBytes=0
    }
    local start=os.clock()
    local currentChar=nil
    local prev=nil
    local connectionList={}
    local lastSample=-math.huge
    local changedState={}
    local function bind(signal,fn)
        local ok,c=pcall(function()return signal:Connect(fn)end)
        if ok and c then connectionList[#connectionList+1]=c end
    end
    local function mark(kind,detail)
        if not D.alive then return end
        bounded(D.events,{t=rounded(os.clock()-start),kind=kind,info=detail},D.maxEvents)
        D.lastEvent=kind
    end
    function D.mark(kind)
        local valid={hub_reset=true,manual_save=true,copy_report=true,
            experimental_toggle=true,recovery_toggle=true}
        if valid[kind] then mark(kind) end
    end
    local function mode()
        local native=ctx.native and ctx.native.active==true or false
        local regen=ctx.regen and ctx.regen.applied==true or false
        if native and regen then return "native_plus_config" end
        if native then return "native_only" end
        if regen then return "config_only" end
        return "neither"
    end
    local function ownSnapshot()
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local clamp=char and char:FindFirstChild("FeralClamp")
        local holding=clamp and clamp:IsA("ObjectValue") and clamp.Value~=nil or false
        local nowServer=safeClock()
        -- Some game builds publish talon deadlines on the character rather than Player.
        -- Track source + raw values. Comparing to GetServerTimeNow is an estimate,
        -- never a substitute for an accepted follow-up catch.
        local playerReady=numericAttr(player,"FeralLungeReadyAt")
        local charReady=numericAttr(char,"FeralLungeReadyAt")
        local ready=playerReady or charReady
        local readySource=playerReady and "player" or charReady and "character" or "absent"
        local cdPlayer=numericAttr(player,"FeralLungeCdTotal")
        local cdChar=numericAttr(char,"FeralLungeCdTotal")
        local cdTotal=cdPlayer or cdChar
        local cooldown=nowServer and ready and rounded(math.max(0,ready-nowServer)) or nil
        local mods=ctx.mechanics
        local p=ctx.power
        local staminaMatches=nil
        if p and type(p.status)=="function" then
            local ok,ps=pcall(p.status)
            if ok and type(ps)=="table" then staminaMatches=ps.staminaMatches end
        end
        return {
            t=rounded(os.clock()-start),session=D.session,
            species=cleanText(attribute(char,"Species") or attribute(player,"Species")),
            hp=hum and rounded(hum.Health) or nil,
            hpMax=hum and rounded(hum.MaxHealth) or nil,
            stamina=numericAttr(char,"Stamina"),
            staminaMax=numericAttr(char,"StaminaMax"),
            staminaOut=yes(attribute(char,"StaminaOut")),
            growth=numericAttr(char,"Growth"),
            bleed=numericAttr(char,"FeralBleed"),
            venom=numericAttr(char,"FeralVenomAmt"),
            injury=numericAttr(char,"FeralInjury"),
            grabbed=yes(attribute(char,"FeralCarried")) or yes(attribute(char,"FeralPinned")) or yes(attribute(char,"FeralDragged")),
            pinned=yes(attribute(char,"FeralPinned")),
            dragged=yes(attribute(char,"FeralDragged")),
            holding=holding,climbCan=yes(attribute(player,"ClimbCan")),
            climbTapAt=numericAttr(player,"FeralClimbTap"),
            resting=yes(attribute(char,"WolfRest")),
            native=ctx.native and ctx.native.active==true or false,
            regen=ctx.regen and ctx.regen.applied==true or false,
            activeRecoveryEnabled=ctx.activeRecovery and ctx.activeRecovery.enabled==true or false,
            recoveryMode=ctx.activeRecovery and ctx.activeRecovery.mode or "OFF",
            recoveryPosePauses=ctx.native and ctx.native.poseSafetyPauses or 0,
            recoveryPoseBlocked=ctx.native and ctx.native.poseBlockedChar==char or false,
            statusInputsReady=ctx.regen and ctx.regen.statusApplied==true or false,
            nativeStatusRestMultReady=ctx.regen and ctx.regen.restMultipliersReady==true or false,
            regenEnabled=ctx.regen and ctx.regen.enabled==true or false,
            endurance=p and p.stamina or "unknown",
            enduranceLeaseMatches=staminaMatches,
            noDrain=yes(attribute(char,"WolfDbgNoStamina")),
            autoEscape=ctx.escape and ctx.escape.enabled==true or false,
            babyCarry=ctx.baby and ctx.baby.enabled==true or false,
            quickClimb=ctx.climb and ctx.climb.enabled==true or false,
            esp=ctx.state and ctx.state.flags and ctx.state.flags.playerFinder==true or false,
            expGrowth=mods and mods.enabled.growth or false,
            expCarry=mods and mods.enabled.carry or false,
            expCooldown=mods and mods.enabled.cooldown or false,
            eagleNativeDragAttempts=ctx.eagleActions and ctx.eagleActions.directDragAttempts or 0,
            eagleCooldownGateEdits=ctx.eagleActions and ctx.eagleActions.cooldownAttrEdits or 0,
            eagleServerScratchReplies=ctx.eagleActions and ctx.eagleActions.serverBitReplies or 0,
            eagleServerClampReplies=ctx.eagleActions and ctx.eagleActions.serverClampReplies or 0,
            eagleServerClampAfterAssist=ctx.eagleActions and ctx.eagleActions.serverClampAfterAssist or 0,
            eagleReplicatedClamps=ctx.eagleActions and ctx.eagleActions.actualClampObservations or 0,
            eagleClampsWithoutHold=ctx.eagleActions and ctx.eagleActions.serverClampWithoutObservedCarry or 0,
            eagleDeadlineOverwrites=ctx.eagleActions and ctx.eagleActions.serverDeadlineOverwrites or 0,
            eagleLongestReplicatedHold=ctx.eagleActions and rounded(ctx.eagleActions.longestActualClampSeconds) or 0,
            eagleLastServerResult=ctx.eagleActions and ctx.eagleActions.lastServerResult or "NONE",
            flying=yes(attribute(char,"FeralFlyLocal")),
            swimming=yes(attribute(char,"FeralSwimLocal"))
                or swimmingState(hum),
            underwater=yes(attribute(char,"FeralUnderwater"))
                or (ctx.flight and ctx.flight.underwater==true) or false,
            waterSurfaceEligible=ctx.flight and ctx.flight.surfaceEligible==true or false,
            relativeWaterDepth=ctx.flight and rounded(ctx.flight.depth) or nil,
            flightRequests=ctx.flight and ctx.flight.surfaceRequests or 0,
            underwaterTakeoffBlocked=ctx.flight and ctx.flight.submergedTakeoffBlocks or 0,
            nativeFlightDropRequests=ctx.flight and ctx.flight.underwaterFlightExits or 0,
            waterFlightOverlapSamples=ctx.flight and ctx.flight.waterFlightOverlapSamples or 0,
            underwaterExitConfirmed=ctx.flight and ctx.flight.underwaterExitConfirmed or 0,
            underwaterExitUnconfirmed=ctx.flight and ctx.flight.underwaterExitUnconfirmed or 0,
            -- WolfController writes both on LocalPlayer, not Character.
            talonPressAt=numericAttr(player,"FeralTalonPress"),
            talonPendingAt=numericAttr(player,"FeralTalonPending"),
            talonReadyAt=ready,talonRemaining=cooldown,talonReadySource=readySource,
            cdTotal=cdTotal,cdTotalSource=cdPlayer and "player" or cdChar and "character" or "absent",
            mode=mode()
        }
    end
    local watch={"grabbed","pinned","dragged","holding","staminaOut",
        "noDrain","native","regenEnabled","expGrowth","expCarry","expCooldown",
        "talonReadyAt","climbTapAt","endurance","quickClimb","babyCarry",
        "flying","swimming","underwater","waterSurfaceEligible",
        "recoveryMode","recoveryPosePauses","recoveryPoseBlocked",
        "statusInputsReady","activeRecoveryEnabled",
        "talonPressAt","talonPendingAt"}
    local function transition(s,previous)
        if not previous then return end
        -- WolfController can write FeralTalonPress and create the local clamp
        -- between recorder samples. Correlate simultaneous changes regardless
        -- of which watch-key is visited first.
        local pressChanged=finite(s.talonPressAt)
            and previous.talonPressAt~=s.talonPressAt
        for _,key in ipairs(watch) do
            local a,b=previous[key],s[key]
            if a~=b then
                D.transitions+=1
                if key=="talonReadyAt" and finite(b) and (not finite(a) or b>a+.4) then D.lungeStarts+=1 end
                if key=="holding" and b==true then
                    D.clampStarts+=1
                    D.holdStartedAt=s.t
                    D.sustainedHoldMarked=false
                    if pressChanged or (D.lastTalonPressT
                        and s.t-D.lastTalonPressT<=3
                        and s.t>=D.lastTalonPressT) then
                        D.talonLocalClampsAfterPress+=1
                        mark("talon_followed_by_local_clamp","local observation, not server confirmation")
                    end
                elseif key=="holding" and b==false and D.holdStartedAt then
                    local held=math.max(0,s.t-D.holdStartedAt)
                    D.talonHoldSeconds+=held
                    D.longestLocalHoldSeconds=math.max(D.longestLocalHoldSeconds,held)
                    D.holdStartedAt=nil
                    D.sustainedHoldMarked=false
                end
                if key=="talonPressAt" and finite(b) then
                    D.talonPresses+=1
                    if D.lastTalonPressT then
                        local gap=s.t-D.lastTalonPressT
                        if gap>0 and gap<300 then
                            D.talonPressIntervals+=1
                            D.talonPressIntervalSeconds+=gap
                        end
                    end
                    D.lastTalonPressT=s.t
                end
                if key=="talonPendingAt" and finite(b) then D.talonPendingStarts+=1 end
                if key=="climbTapAt" and finite(b) then D.climbTapStarts=(D.climbTapStarts or 0)+1 end
                if key=="grabbed" and b==true then D.escapeStarts+=1 end
                mark(key.."_changed",key=="talonReadyAt" and rounded(b) or tostring(b))
            end
        end
        -- Growth increments can occur several times per second and used to
        -- overwrite the entire event history; retain only 10% milestones.
        if finite(s.growth) and finite(previous.growth)
            and math.floor(s.growth*10)>math.floor(previous.growth*10) then
            mark("growth_milestone",rounded(s.growth))
        end
        if finite(s.cdTotal) and finite(previous.cdTotal)
            and math.abs(s.cdTotal-previous.cdTotal)>=.5 then
            D.cooldownTotalJumps+=1
            if D.lastTalonPressT and s.t-D.lastTalonPressT<=3
                and s.t>=D.lastTalonPressT then
                if s.cdTotal>=50 then D.talonObservedLongCooldownEvents+=1
                elseif s.cdTotal>=.3 and s.cdTotal<=3 then
                    D.talonObservedShortCooldownEvents+=1 end
            end
            mark("talon_cd_total_changed",tostring(previous.cdTotal).." to "..tostring(s.cdTotal))
        end
    end
    local function addDelta(s,previous)
        if not previous then return end
        local dt=s.t-previous.t
        if not finite(dt) or dt<=0 or dt>5 then return end
        local k=s.mode
        local bucket=D.modes[k]
        if not bucket then
            bucket={seconds=0,woundedSeconds=0,
                hpUp=0,hpDown=0,staminaUp=0,staminaDown=0,growthUp=0,
                bleedClear=0,venomClear=0,injuryClear=0,
                bleedActiveSeconds=0,venomActiveSeconds=0,injuryActiveSeconds=0}
            D.modes[k]=bucket
        end
        bucket.seconds+=dt
        if finite(previous.hp) and finite(previous.hpMax)
            and previous.hpMax>0 and previous.hp<previous.hpMax-.01 then
            bucket.woundedSeconds+=dt
        end
        for _,effect in ipairs({"bleed","venom","injury"}) do
            if finite(previous[effect]) and previous[effect]>0 then
                bucket[effect.."ActiveSeconds"]+=dt
            end
        end
        if not s.noDrain and previous.noDrain and
            s.endurance~="OFF" then
            D.noDrainMissingSeconds+=dt
        end
        local function delta(key,up,down)
            if not finite(s[key]) or not finite(previous[key]) then return end
            local diff=s[key]-previous[key]
            if diff>0 then
                bucket[up]+=diff
                return diff,0
            elseif diff<0 and down then
                bucket[down]+=-diff
                return 0,-diff
            end
            return 0,0
        end
        local hpUp,hpDown=delta("hp","hpUp","hpDown")
        local sUp,sDown=delta("stamina","staminaUp","staminaDown")
        D.healthGained+=hpUp or 0
        D.healthLost+=hpDown or 0
        D.staminaGained+=sUp or 0
        D.staminaLost+=sDown or 0
        if s.flying==previous.flying and s.swimming==previous.swimming then
            local travel=s.flying and "flight" or s.swimming and "swimming" or "land_other"
            local flag=s.noDrain and previous.noDrain and "flag_on" or "flag_off"
            local mk=travel.."_"..flag
            local b=D.staminaModes[mk]
            if not b then b={seconds=0,staminaUp=0,staminaDown=0,samples=0};D.staminaModes[mk]=b end
            b.seconds+=dt
            b.samples+=1
            b.staminaUp+=sUp or 0
            b.staminaDown+=sDown or 0
        end
        if finite(s.growth) and finite(previous.growth) then
            local g=math.max(0,s.growth-previous.growth)
            D.growthGained+=g
            bucket.growthUp+=g
            if s.expGrowth==previous.expGrowth and s.species==previous.species then
                local trial=s.expGrowth and "on" or "off"
                local animal=s.species=="Eagle" and "eagle" or "other"
                local stage=previous.growth>=1 and s.growth>=1 and "elder"
                    or previous.growth<1 and s.growth<1 and "young" or "transition"
                local name="growth_"..trial.."_"..animal.."_"..stage
                local b=D.growthTrials[name]
                if not b then b={seconds=0,delta=0,samples=0};D.growthTrials[name]=b end
                b.seconds+=dt;b.delta+=g;b.samples+=1
            end
        end
        if finite(s.cdTotal) and s.expCooldown==previous.expCooldown then
            local k=(s.expCooldown and "cooldown_on_" or "cooldown_off_")..
                (s.species=="Eagle" and "eagle" or "other")
            local b=D.cdTrials[k]
            if not b then b={samples=0,nearOnePointFive=0,nearSixty=0,other=0};D.cdTrials[k]=b end
            b.samples+=1
            if s.cdTotal>=1 and s.cdTotal<=2.5 then b.nearOnePointFive+=1
            elseif s.cdTotal>=50 and s.cdTotal<=70 then b.nearSixty+=1
            else b.other+=1 end
        end
        for _,effect in ipairs({"bleed","venom","injury"}) do
            if finite(s[effect]) and finite(previous[effect]) then
                local loss=math.max(0,previous[effect]-s[effect])
                D.statusCleared[effect]+=loss
                bucket[effect.."Clear"]+=loss
            end
        end
    end
    function D.sample()
        if not D.alive or not D.enabled then return end
        local c=player.Character
        if c~=currentChar then
            currentChar=c
            D.session+=1
            D.respawns+=1
            prev=nil
            mark("character_changed",c and "character_present" or "character_absent")
        end
        local s=ownSnapshot()
        transition(s,prev)
        if s.holding and D.holdStartedAt and not D.sustainedHoldMarked
            and s.t-D.holdStartedAt>=2 then
            D.sustainedHoldMarked=true
            D.talonSustainedLocalClamps+=1
            mark("local_clamp_sustained_2s","not server-confirmed")
        end
        addDelta(s,prev)
        if prev and finite(prev.hp) and prev.hp>0 and s.hp==0 then
            D.deathCount+=1
            mark("death")
        end
        prev=s
        D.lastSnapshot=s
        D.samplesTotal+=1
        bounded(D.samples,s,D.maxSamples)
        D.status="Sampling "..tostring(D.samplesTotal).." snapshots / "..tostring(#D.events).." events"
    end
    local function totals()
        local summary={
            schema="FERAL_NOVA_DIAG_V32",scope="OWN_CHARACTER_ONLY",
            transfer="LOCAL_FILE_ONLY_NO_NETWORK_UPLOAD",
            duration=rounded(os.clock()-start),sessions=D.session,
            samples=D.samplesTotal,events=#D.events,respawns=D.respawns,
            deaths=D.deathCount,attacks=D.attackInputs,
            climbKeys=D.climbInputs,carryKeys=D.carryInputs,spaceKeys=D.spaceInputs,
            lungeDeadlines=D.lungeStarts,climbTaps=D.climbTapStarts or 0,clampStarts=D.clampStarts,
            captureStarts=D.escapeStarts,
            talonPresses=D.talonPresses,talonPendingStarts=D.talonPendingStarts,
            eagleGoalEvidence={
                observedTalonPresses=D.talonPresses,
                observedTalonPending=D.talonPendingStarts,
                clampsWithin3sOfTalonPress=D.talonLocalClampsAfterPress,
                locallyHeldAtLeast2Seconds=D.talonSustainedLocalClamps,
                accumulatedLocalHoldSeconds=rounded(D.talonHoldSeconds),
                longestLocalHoldSeconds=rounded(D.longestLocalHoldSeconds),
                averageObservedPressGapSeconds=D.talonPressIntervals>0
                    and rounded(D.talonPressIntervalSeconds/D.talonPressIntervals) or nil,
                cooldownChangesNearPressToLong=D.talonObservedLongCooldownEvents,
                cooldownChangesNearPressToShort=D.talonObservedShortCooldownEvents,
                note="No confirmed server-side carry or accepted second catch is inferred."
            },
            outcomeNote="LocalPlayer Talon signals and local clamps only; server outcomes not proven.",
            healthUp=rounded(D.healthGained),healthDown=rounded(D.healthLost),
            staminaUp=rounded(D.staminaGained),staminaDown=rounded(D.staminaLost),
            growthUp=rounded(D.growthGained),
            cooldownTotalJumps=D.cooldownTotalJumps,
            recovery={
                enabled=D.lastSnapshot and D.lastSnapshot.activeRecoveryEnabled or false,
                unifiedMode=ctx.activeRecovery and ctx.activeRecovery.mode or "UNKNOWN",
                realRestFallback=false,
                forcedVisibleRest=false,
                mobileRestSignal=ctx.native and ctx.native.active or false,
                strictCombatTagBlocks=ctx.native and ctx.native.combatTagBlocks or 0,
                mobileRestSignalSeconds=ctx.native and rounded(ctx.native.mobileSignalSeconds) or 0,
                boundedNoHealRefreshAttempts=ctx.native and ctx.native.restRefreshAttempts or 0,
                boundedNoHealRefreshSuccess=ctx.native and ctx.native.restRefreshSuccess or 0,
                fallbackCount=ctx.activeRecovery and ctx.activeRecovery.fallbackCount or 0,
                fallbackReason=ctx.activeRecovery and ctx.activeRecovery.fallbackReason or "UNKNOWN",
                nativeEligibleHPSeconds=ctx.native and rounded(ctx.native.eligibleHPSeconds) or 0,
                nativeObservedHPGain=ctx.native and rounded(ctx.native.observedHPGain) or 0,
                safeRestOwned=ctx.recovery and ctx.recovery.restOwned~=nil or false,
                nativeWaitReason=ctx.activeRecovery and ctx.activeRecovery.lastReason or "UNKNOWN",
                woundedBlockedSeconds=ctx.activeRecovery and rounded(ctx.activeRecovery.woundedBlockedSeconds) or 0,
                poseSafetyFailures=ctx.native and ctx.native.poseSafetyFailures or 0,
                mode=D.lastSnapshot and D.lastSnapshot.recoveryMode or "OFF",
                poseSafetyPauses=D.lastSnapshot and D.lastSnapshot.recoveryPosePauses or 0,
                poseGuardActive=D.lastSnapshot and D.lastSnapshot.recoveryPoseBlocked or false,
                statusConfigApplied=D.lastSnapshot and D.lastSnapshot.statusInputsReady or false,
                nativeRestMultiplierReady=D.lastSnapshot and D.lastSnapshot.nativeStatusRestMultReady or false
            },
            staminaNoDrainMissingSeconds=rounded(D.noDrainMissingSeconds),
            recoveryComparison={},growthComparison={},staminaByMovement={},cooldownComparison={},
            growthExperiment={
                quality=ctx.mechanics and ctx.mechanics.growthQuality or "UNKNOWN",
                balanced=ctx.mechanics and ctx.mechanics.growthOnOffComparable or false,
                resets=ctx.mechanics and ctx.mechanics.growthResets or 0,
                youngOnSeconds=ctx.mechanics and
                    rounded(ctx.mechanics.growthByStage.young.on.seconds) or 0,
                youngOffSeconds=ctx.mechanics and
                    rounded(ctx.mechanics.growthByStage.young.off.seconds) or 0,
                controlMinimumSeconds=ctx.mechanics and ctx.mechanics.growthTrialMinimumSeconds or 120
            },
            eagleNativeAction={
                nativeDragRetryRequests=ctx.eagleActions and ctx.eagleActions.directDragAttempts or 0,
                nativeRemoteBinds=ctx.eagleActions and ctx.eagleActions.remoteBinds or 0,
                nativeRemoteLateBinds=ctx.eagleActions and ctx.eagleActions.remoteLateBinds or 0,
                nativeRemoteMissing=ctx.eagleActions and ctx.eagleActions.remoteUnavailable or 0,
                targetClockMismatchIgnored=ctx.eagleActions and
                    ctx.eagleActions.incomparableTargetPressClocks or 0,
                staleTargetRejections=ctx.eagleActions and
                    ctx.eagleActions.staleTargetPressRejects or 0,
                allPhysicalHolds=ctx.eagleActions and ctx.eagleActions.anyClampObservations or 0,
                unassistedOrUnmatchedHolds=ctx.eagleActions and ctx.eagleActions.unmatchedClampObservations or 0,
                localRatioOversizeHolds=ctx.eagleActions and ctx.eagleActions.clientOversizeClampObservations or 0,
                holdsNearServerClampReply=ctx.eagleActions and ctx.eagleActions.nearServerClampObservations or 0,
                longestAnyPhysicalHoldSeconds=ctx.eagleActions and
                    rounded(ctx.eagleActions.longestAnyClampSeconds) or 0,
                serverScratchReplies=ctx.eagleActions and ctx.eagleActions.serverBitReplies or 0,
                serverClampReplies=ctx.eagleActions and ctx.eagleActions.serverClampReplies or 0,
                serverClampRepliesAfterAssist=ctx.eagleActions and ctx.eagleActions.serverClampAfterAssist or 0,
                replicatedClampsMatchingSelectedPrey=ctx.eagleActions and ctx.eagleActions.actualClampObservations or 0,
                replicatedHoldLongestSeconds=ctx.eagleActions and rounded(ctx.eagleActions.longestActualClampSeconds) or 0,
                clampResponsesWithoutObservedHold=ctx.eagleActions and ctx.eagleActions.serverClampWithoutObservedCarry or 0,
                clientDeadlineResets=ctx.eagleActions and ctx.eagleActions.serverDeadlineOverwrites or 0,
                clientDeadlineShortenings=ctx.eagleActions and ctx.eagleActions.cooldownAttrEdits or 0,
                lastServerResult=ctx.eagleActions and ctx.eagleActions.lastServerResult or "NONE",
                note="Clamp response is reported by native server event, but may not prove lasting larger-prey carry."
            },
            water={
                surfaceTakeoffs=D.lastSnapshot and D.lastSnapshot.flightRequests or 0,
                blockedSubmergedTakeoffs=D.lastSnapshot and D.lastSnapshot.underwaterTakeoffBlocked or 0,
                nativeFlightDropRequests=D.lastSnapshot and D.lastSnapshot.nativeFlightDropRequests or 0,
                nativeFlightDropConfirmed=D.lastSnapshot and D.lastSnapshot.underwaterExitConfirmed or 0,
                nativeFlightDropNotConfirmed=D.lastSnapshot and D.lastSnapshot.underwaterExitUnconfirmed or 0,
                waterFlightOverlapSamples=D.lastSnapshot and D.lastSnapshot.waterFlightOverlapSamples or 0,
                finalUnderwater=D.lastSnapshot and D.lastSnapshot.underwater or false
            },
            cleared={
                bleed=rounded(D.statusCleared.bleed),
                venom=rounded(D.statusCleared.venom),
                injury=rounded(D.statusCleared.injury)
            },modes={},enabled=D.enabled,autoSave=D.autoSave,
            saveStatus=D.saveStatus
        }
        for k,b in pairs(D.modes) do
            local entry={}
            for name,value in pairs(b) do entry[name]=rounded(value) end
            entry.hpGainPerSecond=b.seconds>0 and rounded(b.hpUp/b.seconds) or nil
            entry.hpGainPerWoundedSecond=b.woundedSeconds>0 and rounded(b.hpUp/b.woundedSeconds) or nil
            entry.statusBleedPerSecond=b.seconds>0 and rounded(b.bleedClear/b.seconds) or nil
            entry.statusBleedPerActiveSecond=b.bleedActiveSeconds>0 and rounded(b.bleedClear/b.bleedActiveSeconds) or nil
            entry.statusVenomPerSecond=b.seconds>0 and rounded(b.venomClear/b.seconds) or nil
            entry.statusVenomPerActiveSecond=b.venomActiveSeconds>0 and rounded(b.venomClear/b.venomActiveSeconds) or nil
            summary.modes[k]=entry
        end
        for name,b in pairs(D.growthTrials) do
            summary.growthComparison[name]={
                seconds=rounded(b.seconds),samples=b.samples,delta=rounded(b.delta),
                observedPerMinute=b.seconds>0 and rounded(b.delta*60/b.seconds) or nil
            }
        end
        for name,b in pairs(D.staminaModes) do
            summary.staminaByMovement[name]={
                seconds=rounded(b.seconds),samples=b.samples,
                gained=rounded(b.staminaUp),lost=rounded(b.staminaDown)
            }
        end
        for name,b in pairs(D.cdTrials) do summary.cooldownComparison[name]=b end
        return summary
    end
    function D.payload()
        return {
            summary=totals(),
            current=D.lastSnapshot,
            recentSamples=D.samples,
            recentEvents=D.events,
            notice="Client observations are not proof of server acceptance. No identifying data is recorded."
        }
    end
    function D.report()
        local a=totals()
        local s=D.lastSnapshot or {}
        local lines={
            "=== FERAL NOVA PRIME v32 AUTOMATIC DIAGNOSTICS ===",
            "privacy=own_character_aggregates_only; upload=NONE",
            "duration_s="..tostring(a.duration).." samples="..a.samples.." events="..a.events,
            "species="..tostring(s.species).." sessions="..a.sessions,
            "HP="..tostring(s.hp).."/"..tostring(s.hpMax)..
                " stamina="..tostring(s.stamina).."/"..tostring(s.staminaMax)..
                " growth="..tostring(s.growth),
            "HP gained="..tostring(a.healthUp).." lost="..tostring(a.healthDown)..
                " stamina gained="..tostring(a.staminaUp).." lost="..tostring(a.staminaDown),
            "bleed cleared="..tostring(a.cleared.bleed)..
                " venom cleared="..tostring(a.cleared.venom)..
                " injury cleared="..tostring(a.cleared.injury),
            "attacks="..a.attacks.." climb_keys="..a.climbKeys..
                " carry_keys="..a.carryKeys.." captures="..a.captureStarts..
                " outgoing_clamps="..a.clampStarts,
            "water_surface_takeoffs="..tostring(a.water.surfaceTakeoffs)..
                " underwater_takeoff_blocks="..tostring(a.water.blockedSubmergedTakeoffs)..
                " underwater_flight_drop_requests="..tostring(a.water.nativeFlightDropRequests)..
                " water_flight_overlap_samples="..tostring(a.water.waterFlightOverlapSamples),
            "swimming="..tostring(s.swimming).." underwater="..tostring(s.underwater)..
                " surface_eligible="..tostring(s.waterSurfaceEligible)..
                " flying="..tostring(s.flying)..
                " relative_depth="..tostring(s.relativeWaterDepth),
            "all_physical_holds="..tostring(a.eagleNativeAction.allPhysicalHolds)..
                " matching_assisted_holds="..tostring(a.eagleNativeAction.replicatedClampsMatchingSelectedPrey)..
                " unmatched_holds="..tostring(a.eagleNativeAction.unassistedOrUnmatchedHolds)..
                " holds_with_client_ratio_over_1_45="..tostring(a.eagleNativeAction.localRatioOversizeHolds)..
                " near_server_reply="..tostring(a.eagleNativeAction.holdsNearServerClampReply),
            "growth_quality="..tostring(a.growthExperiment.quality)..
                " balanced="..tostring(a.growthExperiment.balanced)..
                " young_on_seconds="..tostring(a.growthExperiment.youngOnSeconds)..
                " young_off_seconds="..tostring(a.growthExperiment.youngOffSeconds),
            "mobile_rest_signal="..tostring(a.recovery.mobileRestSignal)..
                " combat_blocks="..tostring(a.recovery.strictCombatTagBlocks)..
                " bounded_refreshes="..tostring(a.recovery.boundedNoHealRefreshAttempts),
            "forced_visible_rest="..tostring(a.recovery.forcedVisibleRest),
            "real_rest_fallback="..tostring(a.recovery.realRestFallback)..
                " fallback_count="..tostring(a.recovery.fallbackCount)..
                " fallback_reason="..tostring(a.recovery.fallbackReason),
            "eagle_remote_binds="..tostring(a.eagleNativeAction.nativeRemoteBinds)..
                " late_binds="..tostring(a.eagleNativeAction.nativeRemoteLateBinds),
            "recovery_reason="..tostring(a.recovery.nativeWaitReason)..
                " wounded_wait_seconds="..tostring(a.recovery.woundedBlockedSeconds),
            "native_drag_retries="..tostring(a.eagleNativeAction.nativeDragRetryRequests)..
                " server_scratch_replies="..tostring(a.eagleNativeAction.serverScratchReplies)..
                " server_clamp_replies="..tostring(a.eagleNativeAction.serverClampReplies)..
                " clamp_replies_after_assist="..tostring(a.eagleNativeAction.serverClampRepliesAfterAssist)..
                " matched_replicated_clamps="..tostring(a.eagleNativeAction.replicatedClampsMatchingSelectedPrey)..
                " longest_real_hold_s="..tostring(a.eagleNativeAction.replicatedHoldLongestSeconds)..
                " client_deadline_shortened="..tostring(a.eagleNativeAction.clientDeadlineShortenings)..
                " local_deadline_reverts="..tostring(a.eagleNativeAction.clientDeadlineResets),
            "talon_press_signals="..tostring(a.talonPresses)..
                " talon_pending="..tostring(a.talonPendingStarts)..
                " local_clamp_starts="..tostring(a.clampStarts),
            "EAGLE GOALS: local_clamps_after_press="..a.eagleGoalEvidence.clampsWithin3sOfTalonPress..
                " locally_held_2s="..a.eagleGoalEvidence.locallyHeldAtLeast2Seconds..
                " avg_press_gap_s="..tostring(a.eagleGoalEvidence.averageObservedPressGapSeconds),
            "TALON_AFTER_PRESS: cooldown_long="..a.eagleGoalEvidence.cooldownChangesNearPressToLong..
                " cooldown_short="..a.eagleGoalEvidence.cooldownChangesNearPressToShort,
            "lunge_deadlines="..a.lungeDeadlines..
                " talon_remaining_s="..tostring(s.talonRemaining)..
                " cd_total="..tostring(s.cdTotal)..
                " cd_source="..tostring(s.cdTotalSource)..
                " cooldown_total_jumps="..tostring(a.cooldownTotalJumps),
            "active_recovery_enabled="..tostring(s.activeRecoveryEnabled)..
                " recovery_mode="..tostring(s.recoveryMode)..
                " pose_guard_pauses="..tostring(a.recovery.poseSafetyPauses)..
                " status_inputs_applied="..tostring(a.recovery.statusConfigApplied),
            "endurance="..tostring(s.endurance).." no_drain="..tostring(s.noDrain)..
                " cached_stamina_applied="..tostring(s.enduranceLeaseMatches)..
                " native_recovery="..tostring(s.native).." regen="..tostring(s.regen),
            "experimental_growth="..tostring(s.expGrowth)..
                " carry="..tostring(s.expCarry).." cooldown="..tostring(s.expCooldown),
            "ESP="..tostring(s.esp).." quick_climb="..tostring(s.quickClimb)..
                " friendly_baby_carry="..tostring(s.babyCarry),
            "auto_save="..tostring(D.autoSave).." status="..D.saveStatus,
            "water_exit_confirmed="..tostring(a.water.nativeFlightDropConfirmed)..
                " water_exit_unconfirmed="..tostring(a.water.nativeFlightDropNotConfirmed),
            "SERVER_ACCEPTANCE=UNVERIFIED"
        }
        for _,name in ipairs({"neither","config_only","native_only","native_plus_config"}) do
            local b=a.modes[name]
            if b then
                lines[#lines+1]="MODE "..name..
                    " seconds="..tostring(b.seconds)..
                    " hp_gain_per_sec="..tostring(b.hpGainPerSecond)..
                    " hp_gain_per_wounded_sec="..tostring(b.hpGainPerWoundedSecond)..
                    " bleed_clear_per_sec="..tostring(b.statusBleedPerSecond)..
                    " venom_clear_per_sec="..tostring(b.statusVenomPerSecond)
            end
        end
        for name,b in pairs(a.growthComparison) do
            lines[#lines+1]="GROWTH "..name.." seconds="..tostring(b.seconds)..
                " progress_per_min="..tostring(b.observedPerMinute)
        end
        for name,b in pairs(a.cooldownComparison) do
            lines[#lines+1]="TALON "..name.." samples="..b.samples..
                " near_1.5s="..b.nearOnePointFive.." near_60s="..b.nearSixty
        end
        for name,b in pairs(a.staminaByMovement) do
            lines[#lines+1]="STAMINA "..name.." seconds="..tostring(b.seconds)..
                " gained="..tostring(b.gained).." lost="..tostring(b.lost)
        end
        lines[#lines+1]="GROWTH COMPARISON: actual Growth attribute, grouped by species and stage"
        lines[#lines+1]="RECENT EVENTS (UP TO 30)"
        for i=math.max(1,#D.events-29),#D.events do
            local e=D.events[i]
            lines[#lines+1]=tostring(e.t).."s "..tostring(e.kind)..
                (e.info~=nil and " "..tostring(e.info) or "")
        end
        return table.concat(lines,"\n")
    end
    function D.save()
        if type(writefile)~="function" then
            D.saveStatus="Executor writefile unavailable; use COPY DIAG"
            return false,D.saveStatus
        end
        local ok,encoded=pcall(function()return HttpService:JSONEncode(D.payload())end)
        if not ok then
            D.saveStatus="JSON encode failed"
            return false,D.saveStatus
        end
        local saved,err=pcall(function()writefile(D.saveFile,encoded)end)
        if saved then
            D.lastSaveAt=os.clock()
            D.lastReportBytes=#encoded
            D.saveStatus="Saved "..D.saveFile.." ("..#encoded.." bytes)"
            return true,D.saveStatus
        end
        D.saveStatus="File write failed; use COPY DIAG"
        return false,tostring(err)
    end
    function D.copy()
        local copy=(type(setclipboard)=="function" and setclipboard)
            or (type(toclipboard)=="function" and toclipboard)
        if not copy then return false,"Clipboard unsupported" end
        local ok=pcall(function()copy(D.report())end)
        if ok then return true,"Diagnostic summary copied" end
        return false,"Clipboard operation failed"
    end
    function D.setAutoSave(v)
        D.autoSave=v==true and type(writefile)=="function"
        if D.autoSave then D.save() end
        return D.autoSave
    end
    function D.shortStatus()
        local s=D.lastSnapshot or {}
        return "DIAG: "..D.samplesTotal.." samples  HP "..tostring(s.hp or "--")..
            "  ST "..tostring(s.stamina or "--")..
            "  CD "..tostring(s.talonRemaining or "--")..
            "  "..(D.autoSave and "AUTO FILE ON" or "COPY-ONLY")
    end
    bind(UIS.InputBegan,function(input,processed)
        if not D.alive or not D.enabled or processed or UIS:GetFocusedTextBox() then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            D.attackInputs+=1
        elseif input.KeyCode==Enum.KeyCode.Q then
            D.climbInputs+=1
        elseif input.KeyCode==Enum.KeyCode.G then
            D.carryInputs+=1
        elseif input.KeyCode==Enum.KeyCode.Space then
            D.spaceInputs+=1
        end
    end)
    local lastAutosave=0
    bind(RunService.Heartbeat,function()
        if not D.alive then return end
        local now=os.clock()
        if D.enabled and now-lastSample>=.5 then
            lastSample=now
            local ok,err=pcall(D.sample)
            if not ok then
                D.status="Sample error, skipped"
                if now-D.lastAutoAt>10 then
                    mark("sample_error")
                    D.lastAutoAt=now
                end
            end
        end
        if D.autoSave and now-lastAutosave>=D.autoSavePeriod then
            lastAutosave=now
            D.save()
        end
    end)
    function D.close()
        if not D.alive then return end
        if D.autoSave then pcall(D.save) end
        D.alive=false
        for _,cn in ipairs(connectionList) do pcall(function()cn:Disconnect()end) end
        for i=#connectionList,1,-1 do connectionList[i]=nil end
    end
    ctx.diag=D
    return D
end
return Diagnostics
]==========]
,["feral-nova-active-recovery-v13.1.lua"]=[==========[
-- FERAL NOVA v13.1 / combat-compatible native status Rest supervisor
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
        if native and native.feedChar==game:GetService("Players").LocalPlayer.Character
            and (native.feedActive or os.clock()<(native.feedUntil or 0)) then
            A.mode="FEEDING_PAUSE"
            A.lastReason="NATIVE FEED / DRINK PRIORITY"
            A.status="FEEDING OR DRINKING / AUTO REST PAUSED / AUTO RESUME"
        elseif native and native.manualRest then
            A.mode="MANUAL_REST"
            A.lastReason="PLAYER-OWNED REST"
            A.status="MANUAL REST ACTIVE / GAME CONTROLS POSE / AUTO PAUSED"
        elseif native and native.active then
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
            local inCombat=false -- no tag-only exclusion in v13.1
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
            "manual_rest_preserved="..tostring(native and native.manualRest),
            "native_feeding_priority="..tostring(native and (native.feedActive or os.clock()<(native.feedUntil or 0))),
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
            "safe_rest_legacy_retired="..tostring(safeRest and safeRest.legacyRetired),
            "safe_rest_legacy_enabled="..tostring(safeRest and safeRest.enabled),
            "mobile_trial_legacy_retired="..tostring(mobile and mobile.legacyRetired),
            "mobile_trial_legacy_enabled="..tostring(mobile and mobile.enabled),
            "NOTE=Client statuses alone do not establish 4x server clearance.",
            "NOTE=No automatic visible Rest, no posture-forcing, no Humanoid.Health writes.",
            "NOTE=Manual Rest bypasses all automatic Rest masking and cancellation.",
            "NOTE=Native feeding/drinking always pauses hub-owned auto Rest, then resumes.",
            "NOTE=Old Safe Rest and Mobile A/B are compatibility-only: no competing Rest traffic.",
            "NOTE=Combat tags alone do not block native status Rest; real attacks still preempt.",
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
                    and A.mode~="NATIVE_RECOVERY" and A.mode~="MANUAL_REST" then
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
]==========]
,["feral-nova-eagle-actions-v12.0.lua"]=[==========[
-- FERAL NOVA v12.0 / explicit Talon clock domains, safe native Eagle lifecycle
-- Activated by existing Eagle Carry and Talon CD toggles.
-- Uses the original game request protocol; never sends blind lunge packets.
-- Native "bit" and "clamp" replies determine the observed result.
-- Server validation may still reject an oversized carry or a short cooldown.
local Eagle={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local localPlayer=Players.LocalPlayer
local function numeric(x)
    return type(x)=="number" and x==x and x>-1e10 and x<1e10
end
-- The game's attributes can use Workspace:GetServerTimeNow while the
-- assistant's scheduling uses os.clock. Never subtract incomparable clocks.
-- Returns a local clock timestamp only for recent values in a known domain.
local function normalizeStamp(stamp,localNow,serverNow,ageLimit)
    if not (numeric(stamp) and numeric(localNow)) then
        return nil,"INVALID"
    end
    ageLimit=type(ageLimit)=="number" and ageLimit or 30
    if math.abs(stamp-localNow)<=ageLimit then
        return math.min(localNow,stamp),"LOCAL"
    end
    if numeric(serverNow) and math.abs(stamp-serverNow)<=ageLimit then
        return localNow-math.max(0,serverNow-stamp),"SERVER"
    end
    return nil,"INCOMPARABLE"
end
Eagle.normalizeStamp=normalizeStamp
local function getChar()
    local char=localPlayer and localPlayer.Character
    if not char or char:GetAttribute("Species")~="Eagle" or char:GetAttribute("FeralDead") then return nil end
    local h=char:FindFirstChildOfClass("Humanoid")
    local root=char:FindFirstChild("HumanoidRootPart")
    if not h or h.Health<=0 or not root then return nil end
    return char,root
end
local function getConfig()
    local world=RS:FindFirstChild("FeralWorld")
    local scriptNode=world and world:FindFirstChild("AbilityConfig")
    if not scriptNode or not scriptNode:IsA("ModuleScript") then return nil end
    local ok,cfg=pcall(require,scriptNode)
    if ok and type(cfg)=="table" then return cfg end
end
function Eagle.attach(ctx)
    local E={
        alive=true,carryOn=false,cooldownOn=false,status="NATIVE EAGLE ASSIST IDLE",
        cooldownAttrEdits=0,cooldownAttrRejected=0,rawCooldownEvents=0,
        directDragAttempts=0,dragRequestErrors=0,
        serverBitReplies=0,serverClampReplies=0,serverMissReplies=0,
        serverClampAfterAssist=0,serverBitAfterAssist=0,
        lastServerResult="NONE",localDeadlineBefore=nil,
        lastTarget=nil,lastTargetAt=-math.huge,
        lastDragAt=-math.huge,lastDragTarget=nil,
        lastDirectAt=-math.huge,
        lastLocalReadyWrite=nil,lastOriginalDeadline=nil,
        lastMode="NONE",lastWhy="",
        targetSelections=0,guardedRejects=0,serverDeadlineOverwrites=0,
        pendingClampUntil=0,pendingClampTarget=nil,
        pendingClampResponse=false,pendingClampEverHeld=false,
        actualClampObservations=0,actualClampHoldSeconds=0,
        longestActualClampSeconds=0,holdingSince=0,observedHoldingTarget=nil,
        serverClampWithoutObservedCarry=0,
        nativeLungeBinds=0,nativeLungeRebinds=0,remoteBindErrors=0,
        selectedTargetUpdates=0,targetNodeRemovals=0,
        nativeCarryPriorityBlocks=0,
        incomparableTargetPressClocks=0,
        convertedServerSelectionStamps=0,
        convertedServerPressStamps=0,
        fallbackSelectionStamps=0,
        lastTargetClockDomain="NONE",
    }
    local connections={}
    local charConnections={}
    local writingReady=false
    local observedChar=nil
    local remote=nil
    local remoteConn=nil
    local cachedAbility=nil
    local lastPoll=0
    local function connect(bucket,signal,fn)
        local ok,cn=pcall(function()return signal:Connect(fn)end)
        if ok and cn then bucket[#bucket+1]=cn end
    end
    local function disconnect(bucket)
        for i=#bucket,1,-1 do
            pcall(function()bucket[i]:Disconnect()end)
            bucket[i]=nil
        end
    end
    local function addSelected(v)
        if not E.alive or not v or v.Name~="FeralTalonTarget" or not v:IsA("ObjectValue") then return end
        local target=v.Value
        if target and target:IsA("Model") then
            E.lastTarget=target
            local at=v:GetAttribute("At")
            local localNow=os.clock()
            local ok,serverNow=pcall(function()
                return Workspace:GetServerTimeNow()
            end)
            local converted,domain=normalizeStamp(
                at,localNow,ok and serverNow or nil,30)
            E.lastTargetAt=converted or localNow
            E.lastTargetClockDomain=domain
            if domain=="SERVER" then E.convertedServerSelectionStamps+=1 end
            if not converted then E.fallbackSelectionStamps+=1 end
            E.targetSelections+=1
        else
            -- An ObjectValue may be cleared/reused without removal. Never
            -- keep treating an earlier animal as the currently selected prey.
            E.lastTarget=nil
            E.lastTargetAt=-math.huge
            E.lastTargetClockDomain="NONE"
        end
    end
    local function watchSelected(v)
        if not E.alive or not v or v.Name~="FeralTalonTarget"
            or not v:IsA("ObjectValue") then return end
        addSelected(v)
        local ok,signal=pcall(function()return v:GetPropertyChangedSignal("Value")end)
        if ok and signal then
            connect(charConnections,signal,function()
                if not E.alive or not observedChar
                    or v.Parent~=observedChar then return end
                E.selectedTargetUpdates+=1
                addSelected(v)
            end)
        end
    end
    local function onChar(char)
        disconnect(charConnections)
        observedChar=char
        E.lastTarget=nil
        E.lastTargetAt=-math.huge
        E.lastTargetClockDomain="NONE"
        E.lastDragTarget=nil
        E.pendingClampTarget=nil
        E.pendingClampUntil=0
        E.pendingClampResponse=false
        E.pendingClampEverHeld=false
        E.observedHoldingTarget=nil
        E.holdingSince=0
        if not char then return end
        local child=char:FindFirstChild("FeralTalonTarget")
        if child then watchSelected(child)end
        connect(charConnections,char.ChildAdded,watchSelected)
        connect(charConnections,char.ChildRemoved,function(removed)
            if removed.Name=="FeralTalonTarget" then
                E.lastTarget=nil
                E.lastTargetAt=-math.huge
                E.lastTargetClockDomain="NONE"
                E.targetNodeRemovals+=1
            end
        end)
    end
    if localPlayer then
        onChar(localPlayer.Character)
        connect(connections,localPlayer.CharacterAdded,onChar)
    end
    local function sameKindFlag(key)
        return E.alive and ctx.mechanics and ctx.mechanics.enabled and ctx.mechanics.enabled[key]==true
    end
    local function restoreReady()
        local stamped=E.lastLocalReadyWrite
        local previous=E.lastOriginalDeadline
        E.lastLocalReadyWrite=nil
        E.lastOriginalDeadline=nil
        if numeric(stamped) and numeric(previous)
            and localPlayer:GetAttribute("FeralLungeReadyAt")==stamped then
            writingReady=true
            pcall(function()localPlayer:SetAttribute("FeralLungeReadyAt",previous)end)
            writingReady=false
        end
    end
    local function patchReady()
        if writingReady or not sameKindFlag("cooldown") then return end
        if not getChar() then return end
        local ready=localPlayer:GetAttribute("FeralLungeReadyAt")
        if not numeric(ready) then return end
        local now=Workspace:GetServerTimeNow()
        if not numeric(now) then return end
        local preset=ctx.mechanics and ctx.mechanics.preset and ctx.mechanics.preset()
        local wanted=math.clamp(preset and preset.seconds or 1.5,.35,8)
        if ready-now<=wanted+.25 then return end
        if E.lastLocalReadyWrite and ready~=E.lastLocalReadyWrite then
            E.serverDeadlineOverwrites+=1
        end
        local prev=ready
        local nextTime=now+wanted
        E.lastOriginalDeadline=prev
        writingReady=true
        local ok=pcall(function()localPlayer:SetAttribute("FeralLungeReadyAt",nextTime)end)
        writingReady=false
        if ok and localPlayer:GetAttribute("FeralLungeReadyAt")==nextTime then
            E.lastLocalReadyWrite=nextTime
            E.cooldownAttrEdits+=1
            E.status="CLIENT LUNGE GATE SHORTENED / SERVER ACCEPTANCE UNKNOWN"
        else
            E.cooldownAttrRejected+=1
        end
    end
    local function safeTarget()
        local char,root=getChar()
        local target=E.lastTarget
        if not char or not target or not target.Parent or os.clock()-E.lastTargetAt>4 then
            return nil,"NO RECENT SELECTED PREY"
        end
        -- Only use the own character's native TalonView selection, not a
        -- nearest-player guess or a cached model from an earlier character.
        if observedChar~=char then return nil,"CHARACTER SELECTION EXPIRED"end
        local nativePress=localPlayer:GetAttribute("FeralTalonPress")
        if numeric(nativePress) then
            local localNow=os.clock()
            local ok,serverNow=pcall(function()
                return Workspace:GetServerTimeNow()
            end)
            local pressAt,domain=normalizeStamp(
                nativePress,localNow,ok and serverNow or nil,30)
            if not pressAt then
                -- An unknown clock domain must NOT discard a genuine
                -- recent selected target as though it had gone stale.
                E.incomparableTargetPressClocks+=1
            else
                if domain=="SERVER" then E.convertedServerPressStamps+=1 end
                if E.lastTargetAt+.5<pressAt then
                    return nil,"TALON SELECTION PREDATES CURRENT PRESS"
                end
            end
        end
        if target==char then return nil,"SELF TARGET"end
        local theirRoot=target:FindFirstChild("HumanoidRootPart")
        local theirHum=target:FindFirstChildOfClass("Humanoid")
        if not theirRoot or not theirHum or theirHum.Health<=0 or target:GetAttribute("FeralDead") then
            return nil,"TARGET NOT ALIVE"
        end
        local owner=Players:GetPlayerFromCharacter(target)
        if owner and owner:GetAttribute("FeralNewPlayer")==true then
            return nil,"NEW PLAYER PROTECTION"
        end
        local dist=(theirRoot.Position-root.Position).Magnitude
        local sizeA=math.max(root.Size.X,root.Size.Z)
        local sizeB=math.max(theirRoot.Size.X,theirRoot.Size.Z)
        if dist>math.max(9,2.5+sizeA/2+sizeB/2) then return nil,"TOO FAR FOR LATCH" end
        return {char=char,root=root,prey=target,preyRoot=theirRoot,distance=dist},nil
    end
    local function nativeDragAfterScratch()
        -- Only act once after an actual server "bit" response for a recently
        -- user-selected target. If server-side size validation rejects it,
        -- we report the failure instead of spamming extra remotes.
        if not sameKindFlag("carry") then return end
        if ctx.action and type(ctx.action.allowed)=="function" then
            local ok,allowed,reason=pcall(ctx.action.allowed,"carry")
            if not ok or not allowed then
                E.nativeCarryPriorityBlocks+=1
                E.lastWhy="CARRY ACTION PRIORITY / "..tostring(reason)
                return
            end
        end
        if os.clock()-E.lastDragAt<5 then
            E.guardedRejects+=1
            return
        end
        local row,why=safeTarget()
        if not row then E.lastWhy=why return end
        local cfg=cachedAbility or getConfig()
        cachedAbility=cfg
        if not cfg or type(cfg.attach)~="function"
            or type(cfg.grabMode)~="function"
            or type(cfg.size)~="function"
            or not (cfg.Talon and numeric(cfg.Talon.CARRY_RATIO)) then
            E.lastWhy="NATIVE ABILITY CONFIG UNAVAILABLE"
            return
        end
        local okRatio,ratio=pcall(function()
            return cfg.size(row.prey)/cfg.size(row.char)
        end)
        if not okRatio or not numeric(ratio) or ratio<=1.45 then
            E.lastWhy="NOT AN OVERSIZE TALON TARGET"
            return
        end
        local permitted,mode=pcall(function()
            return cfg.grabMode("Talon",row.char,row.prey)
        end)
        if not permitted or mode~="drag" then
            E.lastWhy="LOCAL TALON MODE IS NOT DRAG"
            return
        end
        local okRel,rel=pcall(function()
            return cfg.attach("drag",row.char,row.prey,row.root.Position)
        end)
        if not okRel or typeof(rel)~="CFrame" then
            E.lastWhy="NATIVE DRAG ATTACHMENT FAILED"
            return
        end
        if not remote or not remote:IsA("RemoteEvent") then
            E.lastWhy="NATIVE FERAL LUNGE REMOTE UNAVAILABLE"
            return
        end
        E.lastDragAt=os.clock()
        E.lastDragTarget=row.prey
        E.lastMode="drag"
        local ok,err=pcall(function()
            remote:FireServer("latch",row.prey,rel,"drag")
        end)
        if ok then
            E.directDragAttempts+=1
            E.pendingClampTarget=row.prey
            E.pendingClampResponse=false
            E.pendingClampEverHeld=false
            E.pendingClampUntil=os.clock()+4
            E.status="ONE NATIVE DRAG REQUEST SENT / WAITING FOR SERVER"
        else
            E.dragRequestErrors+=1
            E.lastWhy="NATIVE DRAG REQUEST FAILED"
        end
    end
    local function onNativeLunge(kind)
            if not E.alive then return end
            if kind=="bit" then
                E.serverBitReplies+=1
                E.lastServerResult="SCRATCH"
                if E.lastDragAt>0 and os.clock()-E.lastDragAt<2 then
                    E.serverBitAfterAssist+=1
                else
                    nativeDragAfterScratch()
                end
            elseif kind=="clamp" then
                E.serverClampReplies+=1
                E.lastServerResult="CLAMP"
                if E.lastDragAt>0 and os.clock()-E.lastDragAt<3 then
                    E.serverClampAfterAssist+=1
                    E.pendingClampResponse=true
                    E.status="SERVER CLAMP REPLY / CHECKING REAL HOLD"
                end
            elseif kind=="miss" then
                E.serverMissReplies+=1
                E.lastServerResult="MISS"
            end
    end
    local function bindNativeLunge()
        -- FeralLunge may be created late or replaced during a session.
        -- Rebind native replies without leaving old remote listeners alive.
        local current=RS:FindFirstChild("FeralLunge")
        if remote==current and remoteConn and current and current.Parent then
            return true
        end
        local wasBound=remoteConn~=nil
        if remoteConn then pcall(function()remoteConn:Disconnect()end)end
        remoteConn=nil
        remote=nil
        if not current or not current:IsA("RemoteEvent") then
            return false
        end
        local ok,cn=pcall(function()
            return current.OnClientEvent:Connect(onNativeLunge)
        end)
        if not ok or not cn then
            E.remoteBindErrors+=1
            return false
        end
        remote=current
        remoteConn=cn
        E.nativeLungeBinds+=1
        if wasBound then E.nativeLungeRebinds+=1 end
        return true
    end
    bindNativeLunge()
    if localPlayer then
        connect(connections,localPlayer:GetAttributeChangedSignal("FeralLungeReadyAt"),function()
            if writingReady then return end
            E.rawCooldownEvents+=1
            pcall(patchReady)
        end)
    end
    connect(connections,RunService.Heartbeat,function()
        if not E.alive then return end
        local now=os.clock()
        if now-lastPoll<.25 then return end
        lastPoll=now
        if not remote or not remote.Parent
            or RS:FindFirstChild("FeralLunge")~=remote then
            bindNativeLunge()
        end
        local carry=sameKindFlag("carry")
        local cooldown=sameKindFlag("cooldown")
        if E.cooldownOn and not cooldown then restoreReady()end
        E.carryOn=carry
        E.cooldownOn=cooldown
        if cooldown then pcall(patchReady)end
        local char=localPlayer and localPlayer.Character
        local val=char and char:FindFirstChild("FeralClamp")
        local held=val and val:IsA("ObjectValue") and val.Value and val.Value.Parent and val.Value or nil
        if held and held==E.pendingClampTarget and now<=E.pendingClampUntil then
            if E.observedHoldingTarget~=held then
                E.actualClampObservations+=1
                E.pendingClampEverHeld=true
                E.observedHoldingTarget=held
                E.holdingSince=now
                E.status="REPLICATED FERALCLAMP OBSERVED / REAL HOLD"
            end
        end
        if E.observedHoldingTarget then
            if held~=E.observedHoldingTarget or not E.observedHoldingTarget.Parent then
                local duration=math.max(0,now-E.holdingSince)
                E.actualClampHoldSeconds+=duration
                E.longestActualClampSeconds=math.max(E.longestActualClampSeconds,duration)
                E.observedHoldingTarget=nil
                E.holdingSince=0
            end
        end
        if E.pendingClampUntil>0 and now>E.pendingClampUntil then
            if E.pendingClampResponse and not E.pendingClampEverHeld then
                E.serverClampWithoutObservedCarry+=1
            end
            E.pendingClampUntil=0
            E.pendingClampTarget=nil
            E.pendingClampResponse=false
            E.pendingClampEverHeld=false
        end
    end)
    function E.report()
        return table.concat({
            "FERAL v32 / NATIVE EAGLE ASSIST",
            "carry_assist_enabled="..tostring(E.carryOn),
            "cooldown_gate_enabled="..tostring(E.cooldownOn),
            "client_lunge_deadline_shortened="..E.cooldownAttrEdits,
            "native_drag_retry_requests="..E.directDragAttempts,
            "server_scratch_replies="..E.serverBitReplies,
            "server_clamp_replies="..E.serverClampReplies,
            "replicated_clamps_matching_retry="..E.actualClampObservations,
            "replicated_clamp_hold_seconds="..string.format("%.2f",E.actualClampHoldSeconds),
            "longest_replicated_clamp_seconds="..string.format("%.2f",E.longestActualClampSeconds),
            "clamp_reply_without_matching_hold="..E.serverClampWithoutObservedCarry,
            "native_target_selections="..E.targetSelections,
            "target_stamp_server_clock_conversions="..E.convertedServerSelectionStamps,
            "target_stamp_unrecognized_fallbacks="..E.fallbackSelectionStamps,
            "press_stamp_server_clock_conversions="..E.convertedServerPressStamps,
            "incomparable_talon_press_clocks="..E.incomparableTargetPressClocks,
            "last_target_clock_domain="..E.lastTargetClockDomain,
            "target_value_updates_observed="..E.selectedTargetUpdates,
            "target_nodes_removed="..E.targetNodeRemovals,
            "native_remote_bind_success="..E.nativeLungeBinds,
            "native_remote_rebinds="..E.nativeLungeRebinds,
            "native_remote_bind_errors="..E.remoteBindErrors,
            "native_carry_priority_blocks="..E.nativeCarryPriorityBlocks,
            "client_deadline_reverts_observed="..E.serverDeadlineOverwrites,
            "clamp_replies_after_assist="..E.serverClampAfterAssist,
            "server_miss_replies="..E.serverMissReplies,
            "last_server_result="..E.lastServerResult,
            "last_issue="..E.lastWhy,
            "NOTE=Client gate edits and drag requests cannot force game-server pickup.",
            "NOTE=Only a replicated FeralClamp matched to the selected prey counts as a held target.",
            "NOTE=One extra drag request maximum per five seconds, only after an observed scratch.",
            "NOTE=Server and os.clock Talon timestamps are normalized before recency comparisons."
        },"\n")
    end
    function E.close()
        if not E.alive then return end
        E.alive=false
        restoreReady()
        if remoteConn then pcall(function()remoteConn:Disconnect()end)end
        remoteConn=nil
        remote=nil
        E.pendingClampTarget=nil
        E.observedHoldingTarget=nil
        disconnect(connections)
        disconnect(charConnections)
    end
    ctx.eagleActions=E
    return E
end
return Eagle
]==========]
,
["feral-nova-action-core-v13.1.lua"]=[==========[
-- FERAL NOVA v13.1 / combat-tag-compatible negative-effect Rest action arbitration
-- All gameplay-effecting modules retain ownership of their original game
-- interactions. This module only grants/rejects safe windows.
-- No remote traffic, movement, attribute writes, player identifiers or HTTP.
local Coordinator={}
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local function finite(n)
    return type(n)=="number" and n==n and math.abs(n)<1e12
end
local function nativeFeed(value)
    -- WolfController uses string "eat"/"drink"; retain boolean true for legacy.
    return value==true or value=="eat" or value=="drink"
end
Coordinator.isNativeFeed=nativeFeed
local function stateName(hum)
    local ok,value=pcall(function()return hum:GetState()end)
    return ok and value and value.Name or "UNKNOWN"
end
local priority={
    GRAB_MINIGAME=100, CAPTURED=95, COMBAT=90,
    FEEDING=88, ATTACK=85, BITE_WINDOW=80, CARRY=70, CLIMB=60,
    FLIGHT=55, REAL_REST=50, AFK_WALK=35, IDLE=0
}
function Coordinator.attach(ctx)
    local A={
        alive=true,reads=0,cacheHits=0,lastRead=-math.huge,
        lastSnapshot=nil,lastPriority="STARTING",lastReason="STARTING",
        decisions=0,denied=0,denials={},allowedCounts={},
        transitions=0,lastState="",reserveCalls=0,
        lease=nil,leaseCount=0,expiredLeases=0,
        priorityConflicts=0,characterLeaseReleases=0,
        cacheCharacterGuard=true,
    }
    local function now()return os.clock()end
    function A.reserve(owner,seconds)
        -- Higher priority actual actions can displace a lower-priority lease.
        if not A.alive or (owner~="minigame" and owner~="afk_walk"
            and owner~="feed") then
            return false,"UNKNOWN OWNER"
        end
        if not finite(seconds) or seconds<=0 or seconds>12 then
            return false,"UNBOUNDED LEASE"
        end
        local t=now()
        local char=player and player.Character
        if A.lease and A.lease.character~=char then
            A.lease=nil
            A.characterLeaseReleases+=1
        end
        if A.lease and A.lease.expires<=t then
            A.lease=nil
            A.expiredLeases+=1
        end
        local rank={minigame=100,feed=88,afk_walk=35}
        if A.lease and A.lease.owner~=owner
            and rank[A.lease.owner]>rank[owner] then
            A.priorityConflicts+=1
            return false,string.upper(A.lease.owner).." PRIORITY"
        end
        local expires=t+seconds
        if A.lease and A.lease.owner==owner then
            expires=math.max(expires,A.lease.expires)
        end
        A.lease={owner=owner,expires=expires,character=char}
        A.reserveCalls+=1
        A.leaseCount+=1
        A.lastRead=-math.huge
        return true,"GRANTED"
    end
    function A.release(owner)
        if A.lease and A.lease.owner==owner then
            A.lease=nil
            A.lastRead=-math.huge
            return true
        end
        return false
    end
    local function leaseOwner()
        if not A.lease then return nil end
        if A.lease.character~=(player and player.Character) then
            A.lease=nil
            A.characterLeaseReleases+=1
            return nil
        end
        if now()>=A.lease.expires then
            A.lease=nil
            A.expiredLeases+=1
            return nil
        end
        return A.lease.owner
    end
    function A.snapshot(force)
        local t=now()
        -- Even inside the 60-ms cache TTL, changing animals invalidates
        -- the snapshot. A former animal's combat/feed state or AFK state
        -- must not grant access to actions on a newly spawned character.
        if not force and A.lastSnapshot and t-A.lastRead<.06
            and A.lastSnapshot.char==(player and player.Character) then
            A.cacheHits+=1
            return A.lastSnapshot
        end
        local char=player and player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local S={
            char=char,hum=hum,root=root,alive=false,
            combat=false,combatTimeUnknown=false,
            attackHeld=false,nativeBite=false,extendedHint=false,
            feeding=false,feedAvailable=false,
            victim=false,holding=false,grab=false,afkMoving=false,
            menu=false,chat=false,visibleRest=false,locomotion="UNKNOWN",
            lease=leaseOwner(),priority="IDLE",reason="NO ANIMAL",
            danger=false,blocked=true,
        }
        A.reads+=1
        if char and char.Parent and hum and hum.Health>0 and root then
            S.alive=true
            local ok,held=pcall(function()
                return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                    or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
            end)
            S.attackHeld=ok and held==true
            local guide=ctx.lab
            S.nativeBite=guide and guide.alive and guide.enabled
                and guide.nativeReady==true or false
            S.extendedHint=guide and guide.alive and guide.enabled
                and guide.ready==true or false
            local untilAt=player:GetAttribute("FeralCombatUntil")
            local animalAt=char:GetAttribute("FeralCombatUntil")
            if finite(animalAt) and
                (not finite(untilAt) or animalAt>untilAt) then
                untilAt=animalAt
            end
            if finite(untilAt) then
                local timeOK,serverNow=pcall(function()
                    return workspace:GetServerTimeNow()
                end)
                if not timeOK or not finite(serverNow) then
                    S.combatTimeUnknown=true
                else
                    S.combat=untilAt>serverNow
                end
            end
            if ctx.carry and type(ctx.carry.classify)=="function" then
                local yes,_,holding,victim=pcall(ctx.carry.classify,char)
                if yes then
                    S.holding=holding==true
                    S.victim=victim==true
                end
            end
            S.victim=S.victim or char:GetAttribute("FeralPinned")==true
                or char:GetAttribute("FeralDragged")==true
                or char:GetAttribute("FeralCarried")==true
            S.grab=ctx.grabMini and ctx.grabMini.activeSession==true or false
            S.afkMoving=ctx.afk and ctx.afk.travelActive==true or false
            S.menu=player:GetAttribute("FeralMenuOpen")==true
            local chatOK,focused=pcall(function()
                return UIS:GetFocusedTextBox()
            end)
            S.chat=chatOK and focused~=nil and focused~=false
            S.feeding=nativeFeed(char:GetAttribute("WolfFeed"))
            S.feedAvailable=nativeFeed(char:GetAttribute("FeedCan"))
            S.visibleRest=char:GetAttribute("WolfRest")==true
            S.locomotion=stateName(hum)
            local priorityName="IDLE"
            if S.grab or S.lease=="minigame" then
                priorityName="GRAB_MINIGAME"
            elseif S.victim then priorityName="CAPTURED"
            elseif S.combat or S.combatTimeUnknown then
                priorityName="COMBAT"
            elseif S.feeding or S.lease=="feed" then priorityName="FEEDING"
            elseif S.attackHeld then priorityName="ATTACK"
            elseif S.nativeBite then priorityName="BITE_WINDOW"
            elseif S.holding then priorityName="CARRY"
            elseif S.locomotion=="Climbing" then priorityName="CLIMB"
            elseif S.locomotion=="Swimming" or S.locomotion=="Flying"
                or S.locomotion=="Freefall" then
                priorityName="FLIGHT"
            elseif S.visibleRest then priorityName="REAL_REST"
            elseif S.afkMoving or S.lease=="afk_walk" then
                priorityName="AFK_WALK"
            end
            S.priority=priorityName
            S.priorityRank=priority[priorityName] or -1
            S.reason=priorityName
            S.danger=S.combat or S.victim or S.grab
                or S.attackHeld or S.nativeBite
            S.blocked=S.danger or S.feeding or S.lease=="feed"
                or S.visibleRest or S.holding
                or priorityName=="CLIMB" or priorityName=="FLIGHT"
        end
        if not S.alive then S.priority="NO ANIMAL" end
        if A.lastState~=S.priority then
            A.transitions+=1
            A.lastState=S.priority
        end
        A.lastPriority=S.priority
        A.lastReason=S.reason
        A.lastRead=t
        A.lastSnapshot=S
        return S
    end
    function A.allowed(mode,previous)
        local S=previous or A.snapshot(true)
        local reason=nil
        if not A.alive then reason="CLOSED"
        elseif not S or not S.alive then reason="NO ANIMAL"
        elseif mode=="recovery" then
            -- Do not drop recovery because an enlarged *client-only*
            -- target hint is true: only original native bite readiness
            -- has the authority to preempt actual attacks.
            if S.grab or S.lease=="minigame" then reason="GRAB MINIGAME"
            elseif S.victim then reason="CAPTURED"
            elseif S.feeding or S.lease=="feed" then reason="FEEDING / DRINKING"
            -- A combat tag by itself never invalidates real status Rest:
            -- 4x Rest status configuration and blocked combat HP regen
            -- are distinct game rules. Keep actual attack input priority.
            elseif S.attackHeld then reason="ATTACK HELD"
            -- Mere native bite readiness (including a teammate in front
            -- of the camera) is not an attack and cannot stop recovery.
            -- Merely holding already-captured prey is NOT a new carry
            -- action. Preserve v8.1 mobile recovery uptime outside combat;
            -- the G input still invokes Native.beforeCarry() immediately.
            elseif S.afkMoving or S.lease=="afk_walk" then
                reason="SAFE AFK WALK"
            elseif S.menu then reason="MENU" end
        elseif mode=="afk_walk" then
            if S.menu or S.chat then reason="MENU OR CHAT"
            elseif S.grab or S.lease=="minigame" then reason="GRAB MINIGAME"
            elseif S.victim or S.holding then reason="CARRY"
            elseif S.feeding or S.lease=="feed" then reason="FEEDING / DRINKING"
            elseif S.combat or S.combatTimeUnknown then reason="COMBAT"
            elseif S.attackHeld or S.nativeBite or S.extendedHint then
                reason="BITE TARGET OR INPUT"
            elseif S.visibleRest then reason="VISIBLE REST"
            elseif S.afkMoving then reason="ALREADY WALKING"
            elseif S.locomotion=="Swimming" or S.locomotion=="Climbing"
                or S.locomotion=="Freefall" or S.locomotion=="FallingDown"
                or S.locomotion=="Flying" or S.locomotion=="Dead" then
                reason="UNSAFE LOCOMOTION"
            end
        elseif mode=="flight" then
            -- Allows combat escapes and flying with prey, but not during
            -- feeding, grabs, modal input or autonomous AFK travel.
            if S.menu or S.chat then reason="MENU OR CHAT"
            elseif S.grab or S.lease=="minigame" then reason="GRAB PRIORITY"
            elseif S.feeding or S.lease=="feed" then reason="FEEDING / DRINKING"
            elseif S.victim then reason="CAPTURED"
            elseif S.afkMoving or S.lease=="afk_walk" then reason="AFK WALK"
            end
        elseif mode=="grab_press" then
            if not S.grab then reason="NO NATIVE GRAB SESSION"
            elseif S.menu or S.chat then reason="MENU OR CHAT"
            end
        elseif mode=="climb" then
            if S.feeding or S.lease=="feed" then reason="FEEDING / DRINKING"
            elseif S.grab or S.lease=="minigame" then reason="GRAB PRIORITY"
            elseif S.menu or S.chat then reason="MENU OR CHAT" end
        elseif mode=="carry" then
            if S.feeding or S.lease=="feed" then reason="FEEDING / DRINKING"
            elseif S.grab or S.lease=="minigame" then reason="GRAB PRIORITY"
            elseif S.menu or S.chat then reason="MENU OR CHAT" end
        elseif mode=="escape" then
            -- Old shake/tug automation must not compete with the native
            -- Grab V2 timed-input minigame. Real captured non-V2 escapes
            -- remain available, including during combat.
            if S.grab or S.lease=="minigame" then
                reason="GRAB V2 TIMING HAS PRIORITY"
            elseif S.menu or S.chat then reason="MENU OR CHAT" end
        else reason="UNKNOWN POLICY"
        end
        A.decisions+=1
        if reason then
            A.denied+=1
            A.denials[mode..":"..reason]=(A.denials[mode..":"..reason] or 0)+1
            return false,reason
        end
        A.allowedCounts[mode]=(A.allowedCounts[mode] or 0)+1
        return true,"SAFE"
    end
    function A.report()
        local denials={}
        for key,n in pairs(A.denials) do
            denials[#denials+1]={key=key,count=n}
        end
        table.sort(denials,function(a,b)return a.count>b.count end)
        local lines={
            "FERAL NOVA CORE v9.0 | Unified Action Policy",
            "alive="..tostring(A.alive),
            "side_effects=NONE",
            "snapshot_reads="..A.reads,
            "snapshot_cache_hits="..A.cacheHits,
            "priority_transitions="..A.transitions,
            "current_priority="..A.lastPriority,
            "decisions="..A.decisions,
            "denied="..A.denied,
            "leases_granted="..A.reserveCalls,
            "leases_expired="..A.expiredLeases,
            "lower_priority_lease_overwrites_rejected="..A.priorityConflicts,
            "character_switch_lease_resets="..A.characterLeaseReleases,
            "character_change_invalidates_cached_snapshot="..tostring(A.cacheCharacterGuard),
            "active_lease="..tostring(leaseOwner()),
            "native_bite_proximity_does_not_preempt_rest=true",
            "native_feeding_blocks_recovery_and_afk=true",
            "rank_safe_feed_minigame_afk_leases=true",
            "flight_respects_native_feed_and_minigame=true",
            "feed_lease_owner_supported=true",
            "extended_local_hint_does_not_preempt_rest=true",
        }
        for i=1,math.min(8,#denials) do
            lines[#lines+1]="denial_"..i.."="..
                denials[i].key..":"..denials[i].count
        end
        return table.concat(lines,"\n")
    end
    function A.close()
        A.alive=false
        A.lease=nil
        A.lastSnapshot=nil
    end
    A.isNativeFeed=nativeFeed
    return A
end
return Coordinator
]==========],
["feral-nova-afk-v10.1.lua"]=[==========[
-- FERAL NOVA v10.1 / two independent AFK systems under central action policy.
-- Platform idle heartbeat: virtual input, best-effort, not guaranteed.
-- Survival activity: optional conservative WALK, never spoof FeralSurvival.
local AFK={}
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local function readFeralConfig(name)
    local folder=RS:FindFirstChild("FeralWorld")
    local module=folder and folder:FindFirstChild(name)
    if not module or not module:IsA("ModuleScript") then return nil end
    local ok,config=pcall(require,module)
    return ok and type(config)=="table" and config or nil
end
local function finite(v)
    return type(v)=="number" and v==v and math.abs(v)<1e9
end
local function horizontal(v)
    return Vector3.new(v.X,0,v.Z)
end
function AFK.attach(ctx)
    local now=os.clock()
    local A={
        alive=true,robloxEnabled=false,survivalEnabled=false,
        robloxStatus="OFF",survivalStatus="OFF",
        pulseAttempts=0,pulseSuccess=0,pulseErrors=0,idledEvents=0,
        survivalMoves=0,survivalArrivals=0,unsafeStops=0,moveFailures=0,
        survivalProgress=0,progressObserved=0,lastSurvival=nil,
        lastPhysicalInputAt=now,lastPulseAt=now,lastStepAt=now,
        recentPhysicalTravel=now,ignoreInputUntil=0,
        travelActive=false,travelDeadline=0,travelGoal=nil,
        travelChar=nil,travelHum=nil,anchor=nil,anchorChar=nil,
        nextTick=0,desiredTravelPeriod=70,desiredPulsePeriod=85,
        lastError="",lastBlock="NONE",userStopCount=0,
        idleTimeoutSeconds=1200,gameHopWarningSeconds=1080,
        survivalAfkSeconds=120,survivalAfkMoveStuds=4,
        safeStepStuds=6.5,serverValueIncreasesUnverified=true,
    }
    -- Feral's own replicated config is preferred to archived defaults.
    -- We NEVER edit these config objects or local Survival attributes.
    local liveSurvival=readFeralConfig("SurvivalConfig")
    if liveSurvival then
        if finite(liveSurvival.AFK_AFTER)
            and liveSurvival.AFK_AFTER>=30 and liveSurvival.AFK_AFTER<=600 then
            A.survivalAfkSeconds=liveSurvival.AFK_AFTER
        end
        if finite(liveSurvival.AFK_MOVE)
            and liveSurvival.AFK_MOVE>=1 and liveSurvival.AFK_MOVE<=20 then
            A.survivalAfkMoveStuds=liveSurvival.AFK_MOVE
        end
    end
    A.safeStepStuds=math.max(6.5,A.survivalAfkMoveStuds+2)
    A.desiredTravelPeriod=math.min(70,A.survivalAfkSeconds*.6)
    local liveAfk=readFeralConfig("AfkConfig")
    if liveAfk and finite(liveAfk.HOP_AT) and liveAfk.HOP_AT>=150 then
        A.gameHopWarningSeconds=liveAfk.HOP_AT
        A.desiredPulsePeriod=math.min(85,liveAfk.HOP_AT*.25)
    end
    local conns={}
    local virtualUser=nil
    pcall(function()virtualUser=game:GetService("VirtualUser")end)
    local virtualInput=nil
    pcall(function()virtualInput=game:GetService("VirtualInputManager")end)
    local function setBaseline()
        local t=os.clock()
        A.lastPhysicalInputAt=t
        A.lastStepAt=t
        A.anchor=nil
        A.anchorChar=nil
        A.recentPhysicalTravel=t
    end
    local function stopTravel(reason)
        if ctx.action and type(ctx.action.release)=="function" then
            ctx.action.release("afk_walk")
        end
        if not A.travelActive then return end
        local hum=A.travelHum
        local char=A.travelChar
        A.travelActive=false
        A.travelChar=nil
        A.travelHum=nil
        A.travelGoal=nil
        A.travelDeadline=0
        if hum and char and player.Character==char then
            local root=char:FindFirstChild("HumanoidRootPart")
            if root and root.Parent and hum.Parent==char then
                pcall(function()hum:MoveTo(root.Position)end)
            end
        end
        A.survivalStatus=reason or "TRAVEL STOPPED"
    end
    local function recordInput(input)
        local t=os.clock()
        -- VirtualUser emits mouse-button/movement events; suppress those only.
        -- Never suppress real keyboard/touch/primary-click input, because it
        -- must immediately cancel an autonomous walk even after an idle pulse.
        if t<A.ignoreInputUntil and input and (
            input.UserInputType==Enum.UserInputType.MouseMovement
            or input.UserInputType==Enum.UserInputType.MouseWheel
            or input.UserInputType==Enum.UserInputType.MouseButton2
        ) then return end
        -- Mouse/camera movement counts as manual control too. The older
        -- early return recorded activity but left auto-walk running.
        A.lastPhysicalInputAt=t
        if A.travelActive then
            A.userStopCount+=1
            stopTravel("REAL INPUT / AUTO WALK STOPPED")
            setBaseline()
        end
    end
    conns[#conns+1]=UIS.InputBegan:Connect(recordInput)
    conns[#conns+1]=UIS.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement
            or input.UserInputType==Enum.UserInputType.MouseWheel
            or input.UserInputType==Enum.UserInputType.Touch
            or (input.KeyCode==Enum.KeyCode.Thumbstick1
                or input.KeyCode==Enum.KeyCode.Thumbstick2)
                and input.Position.Magnitude>.25 then
            recordInput(input)
        end
    end)
    local function pulse(reason)
        if not A.robloxEnabled or not A.alive then return false end
        local t=os.clock()
        A.lastPulseAt=t
        A.ignoreInputUntil=t+.25
        A.pulseAttempts+=1
        -- First preference: Roblox's VirtualUser. Avoid real-world OS input.
        if virtualUser then
            local ok,err=pcall(function()
                virtualUser:CaptureController()
                virtualUser:ClickButton2(Vector2.new(0,0))
            end)
            if ok then
                A.pulseSuccess+=1
                A.robloxStatus="VIRTUAL INPUT SENT / RESET UNVERIFIED"
                return true
            end
            A.lastError=tostring(err):sub(1,160)
        end
        -- Some executors expose VirtualInputManager instead. A tiny mouse
        -- movement is attempted only when no real user input is occurring.
        if virtualInput and type(virtualInput.SendMouseMoveEvent)=="function" then
            local ok,err=pcall(function()
                virtualInput:SendMouseMoveEvent(1,1,game)
                virtualInput:SendMouseMoveEvent(2,1,game)
            end)
            if ok then
                A.pulseSuccess+=1
                A.robloxStatus="VIRTUAL MOUSE MOVE / RESET UNVERIFIED"
                return true
            end
            A.lastError=tostring(err):sub(1,160)
        end
        A.pulseErrors+=1
        A.robloxStatus="INPUT API UNAVAILABLE / NOT PROTECTED"
        return false
    end
    conns[#conns+1]=player.Idled:Connect(function(seconds)
        A.idledEvents+=1
        if A.robloxEnabled then pulse("PLAYER_IDLED") end
    end)
    local function nearAnotherHumanoid(char,root)
        local params=OverlapParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={char}
        params.MaxParts=200
        local ok,parts=pcall(function()
            return workspace:GetPartBoundsInRadius(root.Position,28,params)
        end)
        if not ok or #parts>=200 then return true end
        local visited={}
        for _,part in ipairs(parts) do
            local model=part:FindFirstAncestorOfClass("Model")
            if model and model~=char and not visited[model] then
                visited[model]=true
                local other=model:FindFirstChildOfClass("Humanoid")
                if other and other.Health>0 then return true end
            end
        end
        return false
    end
    local function safeSurface(char,root,hum,target)
        local rayParams=RaycastParams.new()
        rayParams.FilterType=Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances={char}
        rayParams.IgnoreWater=false
        local groundLength=math.max(35,root.Size.Y+hum.HipHeight+25)
        local function ground(at)
            local ok,hit=pcall(function()
                return workspace:Raycast(
                    at+Vector3.new(0,8,0),
                    Vector3.new(0,-groundLength,0),rayParams)
            end)
            if not ok or not hit or hit.Material==Enum.Material.Water
                or hit.Normal.Y<.86 then return nil end
            return hit.Position
        end
        local from=ground(root.Position)
        local to=ground(target)
        if not from or not to or math.abs(from.Y-to.Y)>1.5 then return nil end
        local vector=horizontal(target-root.Position)
        if vector.Magnitude<=A.survivalAfkMoveStuds+.5
            or vector.Magnitude>8 then return nil end
        local ok,hit=pcall(function()
            return workspace:Raycast(
                root.Position+Vector3.new(0,1,0),
                vector,rayParams)
        end)
        if not ok or hit then return nil end
        local waist=ground(target+vector.Unit*1.25)
        if not waist or math.abs(waist.Y-to.Y)>1.1 then return nil end
        return Vector3.new(target.X,root.Position.Y+to.Y-from.Y,target.Z)
    end
    local function safeForTravel(snap)
        if ctx.action and type(ctx.action.allowed)=="function" then
            local ok,allowed,reason=pcall(ctx.action.allowed,"afk_walk",snap)
            if not ok then return false,"ACTION POLICY ERROR / NO WALK" end
            if not allowed then return false,"ACTION POLICY / "..tostring(reason) end
        elseif not snap or snap.blocked then
            return false,snap and snap.reason or "NO ANIMAL"
        end
        local char,hum,root=snap.char,snap.hum,snap.root
        if not char or not hum or not root then return false,"NO ANIMAL" end
        if hum.Health<hum.MaxHealth*.80 then return false,"LOW HP / AVOID MOVEMENT" end
        if horizontal(root.AssemblyLinearVelocity).Magnitude>2.5 then
            return false,"CHARACTER ALREADY MOVING"
        end
        local hunger=char:GetAttribute("Hunger")
        local thirst=char:GetAttribute("Thirst")
        if finite(hunger) and hunger<25 or finite(thirst) and thirst<25 then
            return false,"LOW HUNGER OR THIRST"
        end
        for _,key in ipairs({"FeralInjury","FeralBleed","FeralVenomAmt"}) do
            local value=char:GetAttribute(key)
            if finite(value) and value>0.1 then
                return false,"STATUS EFFECT / AVOID MOVEMENT"
            end
        end
        if UIS:GetFocusedTextBox() then return false,"CHAT OPEN" end
        if nearAnotherHumanoid(char,root) then return false,"ANIMAL NEARBY / STAY PUT" end
        return true,"SAFE"
    end
    local function beginTravel(snap)
        local char,root,hum=snap.char,snap.root,snap.hum
        if A.anchorChar~=char or not A.anchor then
            A.anchorChar=char
            A.anchor=root.Position
        end
        local current=root.Position
        local anchor=A.anchor
        local wantsReturn=horizontal(current-anchor).Magnitude>A.survivalAfkMoveStuds+.2
        local candidates={}
        if A.safeStepStuds>8 then
            A.survivalStatus="GAME THRESHOLD TOO LARGE / NO SAFE WALK"
            A.moveFailures+=1
            A.lastStepAt=os.clock()
            return false
        end
        if wantsReturn then
            candidates[1]=Vector3.new(anchor.X,current.Y,anchor.Z)
        else
            local f=horizontal(root.CFrame.LookVector)
            if f.Magnitude<.5 then f=Vector3.new(1,0,0)end
            f=f.Unit
            local side=Vector3.new(-f.Z,0,f.X)
            candidates={
                current+side*A.safeStepStuds,current-side*A.safeStepStuds,
                current+f*A.safeStepStuds,current-f*A.safeStepStuds
            }
        end
        for _,dest in ipairs(candidates) do
            local tested=safeSurface(char,root,hum,dest)
            if tested then
                if ctx.action and type(ctx.action.reserve)=="function" then
                    local reserved,reason=ctx.action.reserve("afk_walk",8)
                    if not reserved then
                        A.survivalStatus="ACTION PRIORITY / "..tostring(reason)
                        return false
                    end
                end
                if ctx.native and ctx.native.beforeAfkMove then
                    ctx.native.beforeAfkMove()
                end
                A.travelActive=true
                A.travelChar=char
                A.travelHum=hum
                A.travelGoal=tested
                A.travelDeadline=os.clock()+8
                A.lastStepAt=os.clock()
                A.survivalMoves+=1
                A.survivalStatus="WALK TO SAFE POINT / SERVER CREDIT UNVERIFIED"
                local ok,err=pcall(function()hum:MoveTo(tested)end)
                if not ok then
                    A.lastError=tostring(err):sub(1,120)
                    A.moveFailures+=1
                    stopTravel("MOVE COMMAND FAILED")
                end
                return ok
            end
        end
        A.moveFailures+=1
        A.survivalStatus="NO SAFE STEP / SURVIVAL BONUS MAY PAUSE"
        A.lastStepAt=os.clock()
        return false
    end
    function A.setRobloxEnabled(v)
        A.robloxEnabled=v==true
        A.robloxStatus=A.robloxEnabled and "ARMED / BEST-EFFORT VIRTUAL INPUT"
            or "OFF"
        A.lastPulseAt=os.clock()
        return A.robloxEnabled
    end
    function A.setSurvivalEnabled(v)
        A.survivalEnabled=v==true
        if not A.survivalEnabled then
            stopTravel("OFF")
            A.survivalStatus="OFF"
        else
            setBaseline()
            A.survivalStatus="ARMED / SAFE GROUND MOVEMENT"
        end
        return A.survivalEnabled
    end
    local lastRoot=nil
    local lastChar=nil
    local function tick()
        if not A.alive or not ctx.state.alive then return end
        local now=os.clock()
        if now<A.nextTick then return end
        A.nextTick=now+.45
        local snap=ctx.action and ctx.action.snapshot and ctx.action.snapshot()
        if A.robloxEnabled and now-A.lastPulseAt>=A.desiredPulsePeriod
            and now-A.lastPhysicalInputAt>65 then
            pulse("PERIODIC")
        end
        if not A.survivalEnabled then return end
        local char,root=snap and snap.char,snap and snap.root
        if char~=lastChar then
            lastChar=char
            lastRoot=root and root.Position or nil
            setBaseline()
        end
        if not char or not root or not snap.hum then
            stopTravel("NO ANIMAL")
            A.survivalStatus="WAITING FOR ANIMAL"
            return
        end
        local survival=player:GetAttribute("FeralSurvival")
        if finite(survival) then
            if finite(A.lastSurvival) and survival>A.lastSurvival+.01 then
                A.survivalProgress+=survival-A.lastSurvival
                A.progressObserved+=1
            end
            A.lastSurvival=survival
        end
        if lastRoot and horizontal(root.Position-lastRoot).Magnitude>=A.survivalAfkMoveStuds+.2 then
            A.recentPhysicalTravel=now
            lastRoot=root.Position
        end
        if A.travelActive then
            if snap.blocked or not A.travelGoal
                or A.travelChar~=char then
                A.unsafeStops+=1
                stopTravel("NATIVE ACTION / WALK CANCELLED")
            elseif horizontal(root.Position-A.travelGoal).Magnitude<=2.0 then
                A.travelActive=false
                A.travelChar=nil
                A.travelHum=nil
                A.travelGoal=nil
                if ctx.action and type(ctx.action.release)=="function" then
                    ctx.action.release("afk_walk")
                end
                A.survivalArrivals+=1
                A.recentPhysicalTravel=now
                A.lastStepAt=now
                A.survivalStatus="SAFE STEP REACHED / BONUS UNVERIFIED"
            elseif now>A.travelDeadline then
                A.moveFailures+=1
                stopTravel("WALK STALLED / NO BONUS CLAIM")
                A.lastStepAt=now
            end
            return
        end
        if now-A.lastPhysicalInputAt<55 then
            A.survivalStatus="USER ACTIVE / NO AUTO MOVE"
            return
        end
        if now-A.recentPhysicalTravel<math.max(20,A.desiredTravelPeriod-8)
            or now-A.lastStepAt<A.desiredTravelPeriod then
            A.survivalStatus="WAITING / SURVIVAL MOVEMENT TIMER"
            return
        end
        local safe,why=safeForTravel(snap)
        if not safe then
            A.lastBlock=why
            A.survivalStatus=why
            return
        end
        beginTravel(snap)
    end
    conns[#conns+1]=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            A.lastError=tostring(err):sub(1,160)
            A.survivalStatus="CONTROLLER ERROR / AUTO WALK STOPPED"
            A.survivalEnabled=false
            stopTravel("ERROR / WALK STOPPED")
        end
    end)
    function A.report()
        return table.concat({
            "FERAL NOVA v10.1 | Roblox Idle + Survival Activity",
            "platform_enabled="..tostring(A.robloxEnabled),
            "platform_status="..A.robloxStatus,
            "virtual_pulse_attempts="..A.pulseAttempts,
            "virtual_pulse_successful_calls="..A.pulseSuccess,
            "platform_idle_events="..A.idledEvents,
            "survival_assist_enabled="..tostring(A.survivalEnabled),
            "survival_status="..A.survivalStatus,
            "safe_steps_attempted="..A.survivalMoves,
            "safe_steps_reached="..A.survivalArrivals,
            "movement_stops="..A.unsafeStops,
            "move_failures="..A.moveFailures,
            "observed_survival_afk_after_s="..A.survivalAfkSeconds,
            "observed_survival_move_threshold_studs="..A.survivalAfkMoveStuds,
            "checked_safe_step_studs="..A.safeStepStuds,
            "observed_feral_hop_warning_s="..A.gameHopWarningSeconds,
            "observed_server_survival_seconds_gain="..string.format("%.2f",A.survivalProgress),
            "survival_progress_updates="..A.progressObserved,
            "last_block="..A.lastBlock,
            "last_error="..A.lastError,
            "NOTE=Roblox timeout protection is best effort; an API call is not evidence of long-term server retention.",
            "NOTE=FERAL's AFK detector is separate from Roblox's idle timeout.",
            "NOTE=Survival assist walks real short SAFE paths; no server reward or multiplier spoofing.",
            "NOTE=When safety conditions fail, survival bonus is allowed to pause instead of risking the animal.",
            "NOTE=v9 coordinator gives native combat and grab priority over AFK movement."
        },"\n")
    end
    function A.close()
        if not A.alive then return end
        A.alive=false
        stopTravel("CLOSED")
        A.robloxEnabled=false
        A.survivalEnabled=false
        for _,c in ipairs(conns) do
            pcall(function()c:Disconnect()end)
        end
    end
    return A
end
return AFK
]==========]
,
["feral-nova-grab-v12.0.lua"]=[==========[
-- FERAL NOVA v12.0 / reject stale Grab V2 strike packets across sessions.
-- Uses ONLY actual own-game OnClientEvent("strike") and matching
-- FeralGrabV2:FireServer("press",sessionId,strikeId,Workspace:GetServerTimeNow()).
-- No forged strike/start events, no fake results and no timestamp spoofing.
-- Actual server "perfect" grading is NOT guaranteed by a client forecast.
local Grab={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local function finite(x)
    return type(x)=="number" and x==x and math.abs(x)<1e10
end
local function positive(x)
    return finite(x) and x>0
end
local function validSession(v)
    if type(v)=="number" then return finite(v) and v>0 and v%1==0 end
    if type(v)=="string" then
        if #v<1 or #v>90 or not v:match("^[%w_%-]+$") then
            return false
        end
        -- Old logic rejected "-1" only; "-2" and "0" strings
        -- could be mistaken for real sessions and send a remote.
        local asNumber=tonumber(v)
        if asNumber~=nil then
            return finite(asNumber) and asNumber>0
                and asNumber%1==0
        end
        return true
    end
    return false
end
local function config()
    local folder=RS:FindFirstChild("FeralWorld")
    local m=folder and folder:FindFirstChild("GrabV2Config")
    if not m or not m:IsA("ModuleScript") then return nil end
    local ok,v=pcall(require,m)
    if ok and type(v)=="table" then return v end
    return nil
end
local function triangle(at,t0,speed,from)
    local phase=math.max(0,(at-t0)*speed)%2
    local wave=phase<=1 and phase or 2-phase
    return from==0 and wave or (1-wave)
end
-- A triangle wave reaches target on the rising and falling edges of
-- each 2/speed period. Find earliest valid crossing with time for network
-- clock/readout jitter; never claim perfect from a local prediction alone.
local function crossing(now,t0,dur,speed,from,target,halfWidth,margin)
    if not (finite(now) and finite(t0) and positive(dur)
        and positive(speed) and finite(target) and finite(halfWidth))
        or target<0 or target>1 or halfWidth<=0 then return nil end
    local current=triangle(now,t0,speed,from)
    if now>=t0 and now<=t0+dur-.018
        and math.abs(current-target)<=halfWidth*.5 then
        return now
    end
    local waveTarget=from==0 and target or 1-target
    local threshold=math.max(now+margin,t0+.008)
    local best=nil
    for cycle=0,math.min(32,math.ceil(dur*speed/2)+1) do
        for _,phase in ipairs({waveTarget,2-waveTarget}) do
            local at=t0+(2*cycle+phase)/speed
            if at>=threshold and at<=t0+dur-.018
                and (best==nil or at<best) then
                best=at
            end
        end
    end
    return best
end
Grab.crossing=crossing
function Grab.attach(ctx)
    local G={
        enabled=false,alive=true,activeSession=false,
        status="OFF",session=nil,sessionCharacter=nil,pending=nil,serial=0,
        strikesSeen=0,pressesAttempted=0,pressesSent=0,pressErrors=0,
        perfectWindowAtPress=0,missedWindow=0,
        skippedMissingId=0,invalidStrikePackets=0,manualOverrides=0,
        remoteBinds=0,lateBinds=0,lastBind=0,lastStatus="",
        serverPerfectReplies=0,serverGoodReplies=0,
        serverMissReplies=0,serverUnknownReplies=0,
        lastSessionAt=0,blockedRestWindows=0,lastError="",
        minLeadSeconds=.042,lastReadDelay=0,rawWindowSeconds=0,
        staleSessionEvents=0,sessionResets=0,
        staleStrikePackets=0,
    }
    local conns={}
    local remote=nil
    local remoteConn=nil
    local watchedRemote=nil
    local function revoke(reason)
        G.pending=nil
        G.activeSession=false
        G.session=nil
        G.sessionCharacter=nil
        if ctx.action and type(ctx.action.release)=="function" then
            ctx.action.release("minigame")
        end
        if reason then G.status=reason end
    end
    local function reserve(t)
        if ctx.action and type(ctx.action.reserve)=="function" then
            return ctx.action.reserve("minigame",math.clamp(t,1,8))
        end
        return true,"COORDINATOR NOT ATTACHED"
    end
    local function notifyResult(data)
        local tier=type(data)=="table" and (data.tier or data.grade or data.result) or data
        if type(tier)~="string" then return end
        tier=tier:lower()
        if tier=="perfect" then G.serverPerfectReplies+=1
        elseif tier=="good" then G.serverGoodReplies+=1
        elseif tier=="miss" then G.serverMissReplies+=1
        else G.serverUnknownReplies+=1 end
    end
    local function onEvent(event,data)
        if not G.alive or not G.enabled or type(event)~="string" then return end
        if event=="end" or event=="done" or event=="free"
            or event=="quit" or event=="cancel" then
            local packetId=type(data)=="table" and (data.f or data.id) or nil
            if validSession(packetId) and validSession(G.session)
                and tostring(packetId)~=tostring(G.session) then
                -- A delayed end for an older session is not a new cancel.
                G.staleSessionEvents+=1
                return
            end
            revoke("MINIGAME ENDED / WAITING")
            return
        end
        if event=="result" or event=="grade" or event=="scored" then
            notifyResult(data)
            return
        end
        if event=="bite" then
            G.pending=nil
            G.status="BITE PAUSE / WAITING NEXT STRIKE"
            return
        end
        if event=="start" or event=="begin" then
            local id=type(data)=="table" and (data.f or data.id) or nil
            if validSession(id) then
                local permitted,why=reserve(8)
                if not permitted then
                    G.status="PRIORITY CONFLICT / "..tostring(why)
                    return
                end
                if G.session~=id or G.sessionCharacter~=player.Character then
                    G.pending=nil
                    G.sessionResets+=1
                end
                G.session=id
                G.sessionCharacter=player.Character
                G.activeSession=true
                G.lastSessionAt=os.clock()
                G.status="SESSION FOUND / WATCHING STRIKES"
                if ctx.native and ctx.native.beforeMinigame then
                    ctx.native.beforeMinigame()
                    G.blockedRestWindows+=1
                end
            end
            return
        end
        if event~="strike" then return end
        G.strikesSeen+=1
        if type(data)~="table" then
            G.invalidStrikePackets+=1
            G.status="INVALID STRIKE / NO INPUT SENT"
            return
        end
        if G.activeSession and validSession(G.session)
            and validSession(data.f)
            and tostring(data.f)~=tostring(G.session) then
            -- A late strike from an older session cannot hijack the
            -- current session or send a press using that previous ID.
            -- Fresh sessions remain accepted via native "start" events.
            G.staleStrikePackets+=1
            G.status="STALE STRIKE FROM DIFFERENT GRAB SESSION"
            return
        end
        local id=validSession(data.f) and data.f or G.session
        local strike=data.k
        local t0=data.t0
        local spd=data.spd
        local from=data.from
        local zc=data.zc
        local zw=data.zw
        local cfg=config()
        local cfgPerfect=cfg and cfg.PERFECT or .32
        local passes=cfg and cfg.PASSES or 2.5
        local duration=data.dur
        if not positive(duration) then duration=positive(spd) and passes/spd or 0 end
        if not validSession(id) or not finite(strike) or strike<1
            or strike%1~=0 then
            G.skippedMissingId+=1
            G.status="NO VERIFIED SESSION/STRIKE ID / SKIPPING"
            return
        end
        if not(finite(t0) and positive(spd) and (from==0 or from==1)
            and finite(zc) and zc>=0 and zc<=1 and positive(zw)
            and zw<1 and positive(duration) and duration<=10
            and positive(cfgPerfect) and cfgPerfect<=1) then
            G.invalidStrikePackets+=1
            G.status="UNEXPECTED STRIKE SCHEMA / SKIPPING"
            return
        end
        local ok,serverNow=pcall(function()return Workspace:GetServerTimeNow()end)
        if not ok or not finite(serverNow) or t0+duration<serverNow+.02
            or t0-serverNow>3 then
            G.invalidStrikePackets+=1
            G.status="STRIKE EXPIRED OR CLOCK UNSAFE"
            return
        end
        local permitted,why=reserve(math.min(8,duration+1))
        if not permitted then
            G.pending=nil
            G.status="PRIORITY CONFLICT / "..tostring(why)
            return
        end
        G.session=id
        G.sessionCharacter=player.Character
        G.activeSession=true
        G.lastSessionAt=os.clock()
        if ctx.native and ctx.native.beforeMinigame then
            ctx.native.beforeMinigame()
            G.blockedRestWindows+=1
        end
        local halfPerfect=(zw/2)*cfgPerfect
        local targetTime=crossing(serverNow,t0,duration,spd,from,zc,halfPerfect,G.minLeadSeconds)
        if not targetTime then
            G.missedWindow+=1
            G.status="NO SAFE PERFECT WINDOW LEFT / NOT GUESSING"
            G.pending=nil
            return
        end
        G.serial+=1
        G.pending={
            serial=G.serial,session=id,strike=strike,
            t0=t0,duration=duration,speed=spd,
            from=from,target=zc,halfPerfect=halfPerfect,
            targetTime=targetTime,arrivedAt=os.clock(),
        }
        G.rawWindowSeconds=2*halfPerfect/spd
        G.status="PERFECT CROSSING SCHEDULED / SERVER UNVERIFIED"
    end
    local function bindRemote()
        local nextRemote=RS:FindFirstChild("FeralGrabV2")
        if not nextRemote or not nextRemote:IsA("RemoteEvent") then
            G.status="WAITING FOR NATIVE FERALGRABV2 REMOTE"
            return
        end
        if remote==nextRemote and remoteConn then return end
        if remoteConn then pcall(function()remoteConn:Disconnect()end)end
        remote=nextRemote
        local ok,cn=pcall(function()
            return nextRemote.OnClientEvent:Connect(onEvent)
        end)
        if not ok then
            remote=nil
            G.lastError=tostring(cn):sub(1,140)
            return
        end
        remoteConn=cn
        G.remoteBinds+=1
        G.status="MONITORING NATIVE GRAB V2 EVENTS"
    end
    function G.setEnabled(v)
        G.enabled=v==true
        if G.enabled then
            G.status="WAITING FOR GRAB V2 STRIKE / AUTO PERFECT ARMED"
            bindRemote()
        else
            revoke("OFF / NO MINIGAME INPUTS")
        end
        return G.enabled
    end
    conns[#conns+1]=UIS.InputBegan:Connect(function(input,processed)
        if not G.enabled or not G.pending or processed then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch
            or input.KeyCode==Enum.KeyCode.Space then
            G.manualOverrides+=1
            G.pending=nil
            G.status="MANUAL INPUT HAS PRIORITY"
        end
    end)
    local lastCheck=0
    local function tick()
        if not G.enabled or not G.alive or not ctx.state.alive then return end
        local nowClock=os.clock()
        if nowClock-lastCheck>2 then
            lastCheck=nowClock
            if not remote or not remote.Parent then
                if G.remoteBinds>0 then G.lateBinds+=1 end
                bindRemote()
            end
        end
        if G.activeSession then
            local current=player.Character
            local hum=current and current:FindFirstChildOfClass("Humanoid")
            if not current or not hum or hum.Health<=0
                or (G.sessionCharacter and current~=G.sessionCharacter) then
                revoke("ANIMAL CHANGED OR DEAD / GRAB SESSION RESET")
            elseif not G.pending and nowClock-G.lastSessionAt>8 then
                revoke("SESSION TIMEOUT / NO STRIKE")
            end
        end
        local p=G.pending
        if not p then return end
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health<=0
            or player:GetAttribute("FeralMenuOpen")==true
            or UIS:GetFocusedTextBox() then
            G.pending=nil
            G.status="NO ANIMAL / MENU / CHAT / NO INPUT"
            return
        end
        if ctx.action and type(ctx.action.allowed)=="function" then
            local okAllow,mayPress,reason=pcall(
                ctx.action.allowed,"grab_press")
            if not okAllow or not mayPress then
                G.pending=nil
                G.status="COORDINATOR BLOCKED PRESS / "..tostring(reason)
                return
            end
        end
        local ok,now=pcall(function()return Workspace:GetServerTimeNow()end)
        if not ok or not finite(now) then
            G.pending=nil
            G.status="SERVER CLOCK UNAVAILABLE"
            return
        end
        if now<p.targetTime-.007 then return end
        if now>p.t0+p.duration-.01 then
            G.pending=nil
            G.missedWindow+=1
            G.status="STRIKE EXPIRED / NOT SENDING MISS"
            return
        end
        local pos=triangle(now,p.t0,p.speed,p.from)
        if math.abs(pos-p.target)>p.halfPerfect*.88 then
            -- If a very narrow window was missed, do not lie about the
            -- expected grade or send a stale/future timestamp.
            if now>p.targetTime+.08 then
                G.pending=nil
                G.missedWindow+=1
                G.status="MISSED CENTER / SKIPPED UNSAFE PRESS"
            end
            return
        end
        G.pending=nil
        G.pressesAttempted+=1
        if not remote or not remote.Parent then
            G.pressErrors+=1
            G.status="NATIVE REMOTE LOST / PRESS NOT SENT"
            return
        end
        local sent,err=pcall(function()
            remote:FireServer("press",p.session,p.strike,now)
        end)
        if sent then
            G.pressesSent+=1
            G.perfectWindowAtPress+=1
            G.lastReadDelay=now-p.targetTime
            G.lastSessionAt=nowClock
            G.status="PRESS SENT IN LOCAL PERFECT WINDOW / SERVER RESULT UNKNOWN"
        else
            G.pressErrors+=1
            G.lastError=tostring(err):sub(1,140)
            G.status="NATIVE PRESS ERROR"
        end
    end
    conns[#conns+1]=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            G.lastError=tostring(err):sub(1,140)
            G.status="MINIGAME CONTROLLER ERROR"
            G.pending=nil
        end
    end)
    function G.report()
        return table.concat({
            "FERAL NOVA v10.1 | Grab V2 Auto Perfect",
            "enabled="..tostring(G.enabled),
            "active_native_session="..tostring(G.activeSession),
            "status="..G.status,
            "native_remote_binds="..G.remoteBinds,
            "native_strikes_observed="..G.strikesSeen,
            "perfect_center_press_attempts="..G.pressesAttempted,
            "native_press_calls_success="..G.pressesSent,
            "local_perfect_window_samples="..G.perfectWindowAtPress,
            "late_or_unavailable_windows="..G.missedWindow,
            "manual_press_overrides="..G.manualOverrides,
            "invalid_strike_packets="..G.invalidStrikePackets,
            "stale_session_events_ignored="..G.staleSessionEvents,
            "cross_session_strikes_rejected="..G.staleStrikePackets,
            "session_changes_cancel_old_pending_strikes="..G.sessionResets,
            "unverified_session_ids="..G.skippedMissingId,
            "server_perfect_replies="..G.serverPerfectReplies,
            "server_good_replies="..G.serverGoodReplies,
            "server_miss_replies="..G.serverMissReplies,
            "rest_releases_for_grab="..G.blockedRestWindows,
            "v9_minigame_action_priority=true",
            "last_read_timing_error_seconds="..string.format("%.4f",G.lastReadDelay),
            "last_window_width_seconds="..string.format("%.4f",G.rawWindowSeconds),
            "last_error="..G.lastError,
            "NOTE=Only native server-issued strike packets allow a press.",
            "NOTE=The submitted timestamp is the actual Workspace:GetServerTimeNow().",
            "NOTE=A local Perfect prediction is not a confirmed server Perfect grade.",
            "NOTE=The server may reject presses because of state, latency or validation.",
            "NOTE=Practice mode uses local-only events and is not sent to the server."
        },"\n")
    end
    function G.close()
        if not G.alive then return end
        G.alive=false
        revoke("CLOSED")
        if remoteConn then pcall(function()remoteConn:Disconnect()end)end
        for _,cn in ipairs(conns) do
            pcall(function()cn:Disconnect()end)
        end
    end
    return G
end
return Grab
]==========]
,
["feral-nova-evidence-v11.2.lua"]=[==========[
-- FERAL NOVA v11.2 / activity-isolated, read-only game-outcome evidence
-- Only reads own animal/game state; never sends any remote, alters attributes
-- or claims server-authoritative changes. Clean samples are observational.
local Evidence={}
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local STATES={"moving","stationary"}
local EFFECTS={
    {"injury","FeralInjury"},{"bleed","FeralBleed"},
    {"venom","FeralVenomAmt"},
}
local function finite(v)
    return type(v)=="number" and v==v and v>-1e9 and v<1e9
end
local function read(obj,key)
    if not obj then return nil end
    local ok,v=pcall(function()return obj:GetAttribute(key)end)
    return ok and v or nil
end
local function bucket()
    return {seconds=0,samples=0,positiveHP=0,damage=0,
        healingTicks=0,damageTicks=0,
        status={},statusSeconds={},statusTicks={}}
end
local function safeRate(num,den)
    if not finite(num) or not finite(den) or den<.35 then return nil end
    return num/den
end
local function fmt(n)
    return finite(n) and string.format("%.3f",n) or "INSUFFICIENT DATA"
end
function Evidence.attach(ctx)
    local E={
        alive=true,version="11.2",enabled=true,
        status="WAITING FOR A LIVING ANIMAL",
        moving=bucket(),stationary=bucket(),
        combatSeconds=0,unsafeSeconds=0,transitionSamples=0,
        maxHpChanged=0,characterChanges=0,invalidSamples=0,
        totalObservations=0,last=nil,lastChar=nil,lastClock=0,
        lastTick=-math.huge,interval=.25,history={},
        samplesMax=180,sessionStart=os.clock(),latest=nil,
        lastSurvival=nil,survivalIncrease=0,survivalIncreaseTicks=0,
        survivalResetCount=0,staminaDelta=0,staminaUp=0,staminaDown=0,
        needs={hunger={lost=0,gained=0},thirst={lost=0,gained=0}},
        serverOutcome="NOT CONFIRMED",lastReport="NO EVIDENCE",
        errorCount=0,lastError="",
    }
    local function observe()
        local char=player and player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if char~=E.lastChar then
            E.lastChar=char
            E.last=nil
            E.characterChanges+=1
        end
        if not char or not hum or hum.Health<=0 or not root then
            E.last=nil
            E.status="WAITING FOR LIVING ANIMAL"
            return
        end
        local now=os.clock()
        local velocity=root.AssemblyLinearVelocity
        local horizontal=typeof(velocity)=="Vector3"
            and Vector3.new(velocity.X,0,velocity.Z).Magnitude or 0
        local direction=hum.MoveDirection
        local moving=horizontal>=2 or (
            typeof(direction)=="Vector3" and direction.Magnitude>.13)
        local stateOK,state=pcall(function()return hum:GetState()end)
        local locomotion=stateOK and state and state.Name or "UNKNOWN"
        local snap=ctx.action and type(ctx.action.snapshot)=="function"
            and ctx.action.snapshot() or nil
        local combat=snap and (snap.combat==true or snap.attackHeld==true
            or snap.combatTimeUnknown==true) or false
        local unsafe=not snap or not snap.alive or
            snap.grab or snap.victim or snap.afkMoving or snap.feeding or
            locomotion=="Dead" or locomotion=="FallingDown"
        local effects={}
        for _,entry in ipairs(EFFECTS) do
            local value=read(char,entry[2])
            effects[entry[1]]=finite(value) and math.max(0,value) or nil
        end
        local new={
            now=now,char=char,health=hum.Health,max=hum.MaxHealth,
            moving=moving,combat=combat,unsafe=unsafe,
            rest=ctx.native and ctx.native.active==true or false,
            effects=effects,
            stamina=read(char,"Stamina"),
            hunger=read(char,"Hunger"),
            thirst=read(char,"Thirst"),
            survival=read(player,"FeralSurvival"),
        }
        E.latest={
            health=new.health,maxHealth=new.max,moving=moving,
            locomotion=locomotion,combat=combat,
            restSignal=new.rest,priority=snap and snap.priority or "NO STATE",
            survival=finite(new.survival) and new.survival or nil,
            injury=effects.injury,bleed=effects.bleed,venom=effects.venom,
            stamina=new.stamina,hunger=new.hunger,thirst=new.thirst,
        }
        E.totalObservations+=1
        local old=E.last
        if old then
            local dt=new.now-old.now
            if dt<.12 or dt>1.5 then
                E.invalidSamples+=1
            else
                local stable=new.max==old.max and finite(new.health)
                    and finite(old.health) and new.health>=0
                    and new.health<=new.max+.1
                if not stable then E.maxHpChanged+=1 end
                local clean=stable and not new.combat and not old.combat
                    and not new.unsafe and not old.unsafe
                    and new.moving==old.moving
                    and new.rest==old.rest
                if new.combat or old.combat then E.combatSeconds+=dt end
                if new.unsafe or old.unsafe then E.unsafeSeconds+=dt end
                if new.moving~=old.moving or new.rest~=old.rest then
                    E.transitionSamples+=1
                end
                if clean then
                    local B=new.moving and E.moving or E.stationary
                    B.seconds+=dt
                    B.samples+=1
                    local difference=new.health-old.health
                    if difference>.01 then
                        B.positiveHP+=difference
                        B.healingTicks+=1
                    elseif difference<-.01 then
                        B.damage+=-difference
                        B.damageTicks+=1
                    end
                    for _,entry in ipairs(EFFECTS) do
                        local name=entry[1]
                        local v1=new.effects[name]
                        local v0=old.effects[name]
                        if finite(v0) and v0>.01
                            and (finite(v1) or v1==nil) then
                            local after=finite(v1) and v1 or 0
                            if after<=v0 then
                                B.statusSeconds[name]=(B.statusSeconds[name] or 0)+dt
                                local clearance=v0-after
                                if clearance>.001 then
                                    B.status[name]=(B.status[name] or 0)+clearance
                                    B.statusTicks[name]=(B.statusTicks[name] or 0)+1
                                end
                            end
                        end
                    end
                end
                if finite(new.stamina) and finite(old.stamina) then
                    local diff=new.stamina-old.stamina
                    E.staminaDelta+=diff
                    if diff>0 then E.staminaUp+=diff
                    else E.staminaDown-=diff end
                end
                for _,k in ipairs({"hunger","thirst"}) do
                    local v1,v0=new[k],old[k]
                    if finite(v1) and finite(v0) then
                        local diff=v1-v0
                        if diff>=0 then E.needs[k].gained+=diff
                        else E.needs[k].lost-=diff end
                    end
                end
                if finite(new.survival) and finite(old.survival) then
                    local diff=new.survival-old.survival
                    if diff>0 and diff<=dt*5+2 then
                        E.survivalIncrease+=diff
                        E.survivalIncreaseTicks+=1
                    elseif diff<-.5 then E.survivalResetCount+=1 end
                end
            end
        end
        E.last=new
        if moving then E.status="MOVING / OBSERVING OWN HP"
        else E.status="STATIONARY / OBSERVING OWN HP" end
        if combat then E.status="COMBAT / HEALING SAMPLES EXCLUDED" end
    end
    local connection=RunService.Heartbeat:Connect(function()
        if not E.alive or not E.enabled then return end
        local now=os.clock()
        if now-E.lastTick<E.interval then return end
        E.lastTick=now
        local ok,err=pcall(observe)
        if not ok then
            E.errorCount+=1
            E.lastError=tostring(err):sub(1,160)
            E.last=nil
            E.status="EVIDENCE SAMPLE ERROR"
        end
    end)
    function E.summary()
        local movingHeal=safeRate(E.moving.positiveHP,E.moving.seconds)
        local stillHeal=safeRate(E.stationary.positiveHP,E.stationary.seconds)
        local enoughMoving=E.moving.samples>=12 and E.moving.seconds>=4
        local enoughStill=E.stationary.samples>=12 and E.stationary.seconds>=4
        local compare=enoughMoving and enoughStill and stillHeal
            and stillHeal>.01 and movingHeal and movingHeal/stillHeal or nil
        local localMinigame=ctx.grabMini
        local eagle=ctx.eagleActions
        return {
            version=E.version,
            movingHealingRate=enoughMoving and movingHeal or nil,
            stationaryHealingRate=enoughStill and stillHeal or nil,
            movingToStillRatio=compare,
            movingSeconds=E.moving.seconds,
            stationarySeconds=E.stationary.seconds,
            injuryMovingRate=safeRate(E.moving.status.injury,
                E.moving.statusSeconds.injury),
            injuryStillRate=safeRate(E.stationary.status.injury,
                E.stationary.statusSeconds.injury),
            bleedMovingRate=safeRate(E.moving.status.bleed,
                E.moving.statusSeconds.bleed),
            venomMovingRate=safeRate(E.moving.status.venom,
                E.moving.statusSeconds.venom),
            survivalIncrease=E.survivalIncrease,
            survivalSamples=E.survivalIncreaseTicks,
            staminaConsumed=E.staminaDown,
            staminaReplenished=E.staminaUp,
            hungerLost=E.needs.hunger.lost,
            thirstLost=E.needs.thirst.lost,
            minigameStrikes=localMinigame and localMinigame.strikesSeen or 0,
            minigamePresses=localMinigame and localMinigame.pressesSent or 0,
            confirmedServerPerfects=localMinigame and
                localMinigame.serverPerfectReplies or 0,
            nativeEagleClampObservations=eagle and
                eagle.actualClampObservations or 0,
            location="OWN_ANIMAL_ONLY",
            evidenceScope="OBSERVED_REPLICATED_OR_LOCAL_VALUES_NOT_CAUSAL_PROOF",
            readyForComparison=compare~=nil,
        }
    end
    function E.report()
        local S=E.summary()
        local lines={
            "FERAL NOVA v10 | Independent Gameplay Evidence",
            "status="..E.status,
            "observations="..E.totalObservations,
            "character_resets="..E.characterChanges,
            "max_HP_exclusions="..E.maxHpChanged,
            "transition_exclusions="..E.transitionSamples,
            "moving_clean_seconds="..fmt(E.moving.seconds),
            "stationary_clean_seconds="..fmt(E.stationary.seconds),
            "moving_HP_per_s="..fmt(S.movingHealingRate),
            "stationary_HP_per_s="..fmt(S.stationaryHealingRate),
            "moving_to_still_ratio="..fmt(S.movingToStillRatio),
            "injury_clearance_moving_per_s="..fmt(S.injuryMovingRate),
            "injury_clearance_still_per_s="..fmt(S.injuryStillRate),
            "bleed_clearance_moving_per_s="..fmt(S.bleedMovingRate),
            "venom_clearance_moving_per_s="..fmt(S.venomMovingRate),
            "observed_survival_gain="..fmt(S.survivalIncrease),
            "survival_credit_increments="..S.survivalSamples,
            "observed_stamina_consumed="..fmt(S.staminaConsumed),
            "observed_stamina_replenished="..fmt(S.staminaReplenished),
            "observed_hunger_lost="..fmt(S.hungerLost),
            "observed_thirst_lost="..fmt(S.thirstLost),
            "grab_native_strikes_seen="..S.minigameStrikes,
            "grab_native_presses_sent="..S.minigamePresses,
            "grab_server_perfect_replies="..S.confirmedServerPerfects,
            "eagle_native_clamp_observations="..S.nativeEagleClampObservations,
            "validation="..S.evidenceScope,
            "sample_error_count="..E.errorCount,
            "last_error="..E.lastError,
            "NOTE=Only own animal values are sampled. No remote sends, no writes.",
            "NOTE=Local Humanoid Health and replicated attributes can be updated without identifying exact cause.",
            "NOTE=Comparisons require comparable states, multiple samples, unchanged MaxHP, no combat or interruption.",
            "NOTE=Rest signal visibility, local mechanics and timing do not prove server acceptance.",
        }
        return table.concat(lines,"\n")
    end
    function E.close()
        if not E.alive then return end
        E.alive=false
        E.enabled=false
        E.last=nil
        if connection then pcall(function()connection:Disconnect()end)end
    end
    return E
end
return Evidence
]==========]
}

-- Precompile before retiring old hub. No game-server remote requests.
local MODULE_ORDER={"feral-aurora-engine-v11.2.lua","feral-aurora-power-v14.0.lua","feral-nova-escape-core-v9.0.lua","feral-nova-combat-v15.0.lua","feral-nova-recovery-compat-v11.2.lua","feral-nova-mobile-compat-v11.2.lua","feral-nova-carry-core-v11.3.lua","feral-nova-reach-v14.0.lua","feral-nova-regen-v11.0.lua","feral-nova-flight-v11.3.lua","feral-nova-native-recovery-v13.3.lua","feral-nova-baby-v15.0.lua","feral-nova-climb-v13.0.lua","feral-nova-tags-v8.0.lua","feral-nova-ui-v13.1.lua","feral-nova-mechanics-v28.0.lua","feral-nova-diagnostics-v32.0.lua","feral-nova-active-recovery-v13.1.lua","feral-nova-eagle-actions-v12.0.lua","feral-nova-action-core-v13.1.lua","feral-nova-afk-v10.1.lua","feral-nova-grab-v12.0.lua","feral-nova-evidence-v11.2.lua"}
local compiled={}
H.precompiledCount=0
H.phase("Compile-checking every embedded module")
for _,key in ipairs(MODULE_ORDER) do
    local source=BUNDLED[key]
    if type(source)~="string" or #source<100 then error("Missing module source: "..key,0)end
    local ok,fn,err=pcall(loadstring,source)
    if not ok or type(fn)~="function" then
        error("Module compile failure: "..key.." | "..tostring(err or fn),0)
    end
    compiled[key]=fn
    H.precompiledCount+=1
end
log.precompiledModules=H.precompiledCount
H.phase("All 23 modules compile; initializing Renaissance core")
-- Retire broken v21-v24 rebuilds before launching preserved v15 modules.
local env=(type(getgenv)=="function" and getgenv()) or _G
for _,key in ipairs({"FERAL_NOVA_PRIME_V21","FERAL_NOVA_PRIME_V22","FERAL_NOVA_PRIME_V23","FERAL_NOVA_PRIME_V24"}) do
    local old=env[key]
    if type(old)=="table" and type(old.Destroy)=="function" then
        pcall(function()old:Destroy()end)
    end
end

for _,name in ipairs({
    "FeralNovaV131","FeralNovaV130","FeralNovaV122","FeralNovaV121","FeralNovaV120","FeralNovaV1132","FeralNovaV1131","FeralNovaV113","FeralNovaV112","FeralNovaV100","FeralNovaPrimeV320","FeralNovaPrimeV310","FeralNovaPrimeV300","FeralNovaPrimeV290","FeralNovaPrimeV280","FeralNovaPrimeV270","FeralNovaPrimeV260","FeralNovaPrimeV250","FeralNovaPrimeV150","FeralNovaPrimeV140","FeralNovaPrimeV130","FeralNovaPrimeV120","FeralNovaPrimeV110","FeralNovaPrimeV100","FeralNovaPrimeV90","FeralNovaPrimeV80","FeralNovaPrimeV70","FeralNovaPrimeV60","FeralNovaPrimeV50","FeralAuroraNovaV40","FeralAuroraForceV31",
    "FeralAuroraHubV30","FeralAuroraHubV21","FeralAuroraHubV20",
    "FeralRecoveryHubV10","FeralRecoveryHubV11","FeralRecoveryHubV12",
    "FeralRecoveryHubV13","FeralFieldHubV10","FeralFieldHubV11",
    "FeralFieldHubV12","FeralFieldHubV13","FeralFieldHubV14"
}) do
    local old=pg:FindFirstChild(name)
    if old then
        local stop=old:FindFirstChild("AuroraShutdown")
            or old:FindFirstChild("HubShutdown")
        if stop and stop:IsA("BindableEvent") then
            pcall(function()stop:Fire()end)
        end
        if old.Parent then pcall(function()old:Destroy()end)end
    end
end


local function get(path)
    H.phase("MODULE: "..tostring(path))
    local loader=compiled[path]
    if type(loader)~="function" then error("Not precompiled: "..tostring(path),0)end
    local ok,result=pcall(loader)
    if not ok then error("Module runtime failed "..path..": "..tostring(result),0)end
    H.loaded(path)
    return result
end

-- Full hub lifecycle registry for safe same-session reloads.
-- Earlier v27 and older did not register all their controllers; rejoin first
-- when migrating from those versions.
local activeEnv=(type(getgenv)=="function" and getgenv()) or _G
if type(activeEnv.FERAL_NOVA_PRIME_ACTIVE)=="table" then
    local prior=activeEnv.FERAL_NOVA_PRIME_ACTIVE
    if type(prior.close)=="function" then
        pcall(function()prior.close()end)
    end
end
activeEnv.FERAL_NOVA_PRIME_ACTIVE=nil

H.phase("Initializing preserved core")
local core=get("feral-aurora-engine-v11.2.lua")
local power=get("feral-aurora-power-v14.0.lua")
local escape=get("feral-nova-escape-core-v9.0.lua")
local lab=get("feral-nova-combat-v15.0.lua")
local recovery=get("feral-nova-recovery-compat-v11.2.lua")
local mobile=get("feral-nova-mobile-compat-v11.2.lua")
local carry=get("feral-nova-carry-core-v11.3.lua")
local tags=get("feral-nova-tags-v8.0.lua")
local reach=get("feral-nova-reach-v14.0.lua")
local regen=get("feral-nova-regen-v11.0.lua")
local flight=get("feral-nova-flight-v11.3.lua")
local native=get("feral-nova-native-recovery-v13.3.lua")
local baby=get("feral-nova-baby-v15.0.lua")
local climb=get("feral-nova-climb-v13.0.lua")
local mechanics=get("feral-nova-mechanics-v28.0.lua")
local diagnostics=get("feral-nova-diagnostics-v32.0.lua")
local activeRecovery=get("feral-nova-active-recovery-v13.1.lua")
local eagleActions=get("feral-nova-eagle-actions-v12.0.lua")
local action=get("feral-nova-action-core-v13.1.lua")
local afk=get("feral-nova-afk-v10.1.lua")
local grab=get("feral-nova-grab-v12.0.lua")
local evidence=get("feral-nova-evidence-v11.2.lua")
local ui=get("feral-nova-ui-v13.1.lua")
if not core or type(core.new)~="function"
    or not power or type(power.attach)~="function"
    or not escape or type(escape.attach)~="function"
    or not lab or type(lab.attach)~="function"
    or not recovery or type(recovery.attach)~="function"
    or not mobile or type(mobile.attach)~="function"
    or not carry or type(carry.attach)~="function"
    or not reach or type(reach.attach)~="function"
    or not regen or type(regen.attach)~="function"
    or not flight or type(flight.attach)~="function"
    or not native or type(native.attach)~="function"
    or not baby or type(baby.attach)~="function"
    or not climb or type(climb.attach)~="function"
    or not tags or type(tags.attach)~="function"
    or not mechanics or type(mechanics.attach)~="function"
    or not eagleActions or type(eagleActions.attach)~="function"
    or not diagnostics or type(diagnostics.attach)~="function"
    or not activeRecovery or type(activeRecovery.attach)~="function"
    or not action or type(action.attach)~="function"
    or not afk or type(afk.attach)~="function"
    or not grab or type(grab.attach)~="function"
    or not evidence or type(evidence.attach)~="function"
    or not ui or type(ui.mount)~="function" then
    error("[FERAL HUB] Required module interface unavailable.",0)
end
H.phase("Creating core controller")
local ok,ctx=pcall(function()return core.new({})end)
if not ok or type(ctx)~="table" then
    error("[FERAL HUB] Could not start core: "..tostring(ctx),0)
end
ctx.hubBuild={
    release="13.4.8",
    bootReport=function()return json()end,
    sessionReport=function()return H.sessionJson()end,
    capabilities=c,
    selfTest=function()return H.selfCheck(ctx)end
}
local attached,reason=pcall(function()
    H.attach("power",function() return power.attach(ctx) end)
    ctx.carry=H.attach("carry",function() return carry.attach(ctx) end)
    ctx.reach=H.attach("reach",function() return reach.attach(ctx) end)
    ctx.regen=H.attach("regen",function() return regen.attach(ctx) end)
    ctx.mechanics=H.attach("mechanics",function() return mechanics.attach(ctx) end)
    ctx.eagleActions=H.attach("eagleActions",function() return eagleActions.attach(ctx) end)
    ctx.flight=H.attach("flight",function() return flight.attach(ctx) end)
    ctx.baby=H.attach("baby",function() return baby.attach(ctx) end)
    ctx.native=H.attach("native",function() return native.attach(ctx) end)
    ctx.climb=H.attach("climb",function() return climb.attach(ctx) end)
    ctx.escape=H.attach("escape",function() return escape.attach(ctx) end)
    ctx.lab=H.attach("lab",function() return lab.attach(ctx) end)
    ctx.recovery=H.attach("recovery",function() return recovery.attach(ctx) end)
    ctx.mobile=H.attach("mobile",function() return mobile.attach(ctx) end)
    ctx.activeRecovery=H.attach("activeRecovery",function() return activeRecovery.attach(ctx) end)
    ctx.tags=H.attach("tags",function() return tags.attach(ctx) end)
    ctx.diag=H.attach("diagnostics",function() return diagnostics.attach(ctx) end)
    ctx.action=H.attach("action",function()return action.attach(ctx)end)
    ctx.afk=H.attach("afk",function()return afk.attach(ctx)end)
    ctx.grabMini=H.attach("grabMini",function()return grab.attach(ctx)end)
    ctx.evidence=H.attach("evidence",function()return evidence.attach(ctx)end)
end)
if not attached or not ctx.escape or not ctx.lab or not ctx.recovery or not ctx.mobile or not ctx.carry or not ctx.flight or not ctx.reach or not ctx.regen or not ctx.mechanics or not ctx.eagleActions or not ctx.diag or not ctx.activeRecovery or not ctx.native or not ctx.climb or not ctx.baby or not ctx.tags or not ctx.action or not ctx.afk or not ctx.grabMini or not ctx.evidence then
    pcall(function()if ctx.evidence then ctx.evidence.close()end end)
    pcall(function()if ctx.grabMini then ctx.grabMini.close()end end)
    pcall(function()if ctx.afk then ctx.afk.close()end end)
    pcall(function()if ctx.action then ctx.action.close()end end)
    pcall(function()if ctx.activeRecovery then ctx.activeRecovery.close()end end)
    pcall(function()if ctx.native then ctx.native.close()end end)
    pcall(function()if ctx.climb then ctx.climb.close()end end)
    pcall(function()if ctx.baby then ctx.baby.close()end end)
    pcall(function()if ctx.tags then ctx.tags.close()end end)
    pcall(function()if ctx.flight then ctx.flight.close()end end)
    pcall(function()if ctx.reach then ctx.reach.close()end end)
    pcall(function()if ctx.regen then ctx.regen.close()end end)
    pcall(function()if ctx.mechanics then ctx.mechanics.close()end end)
    pcall(function()if ctx.eagleActions then ctx.eagleActions.close()end end)
    pcall(function()if ctx.diag then ctx.diag.close()end end)
    pcall(function()if ctx.mobile then ctx.mobile.close()end end)
    pcall(function()if ctx.carry then ctx.carry.close()end end)
    pcall(function()if ctx.recovery then ctx.recovery.close()end end)
    pcall(function()if ctx.lab then ctx.lab.close()end end)
    pcall(function()if ctx.escape then ctx.escape.close()end end)
    pcall(ctx.close)
    error("[FERAL HUB] Module attachment failure: "..tostring(reason),0)
end
H.phase("Mounting FERAL HUB interface")
local ready,window=pcall(function()return ui.mount(ctx)end)
if not ready or not window then
    pcall(function()ctx.evidence.close()end)
    pcall(function()ctx.grabMini.close()end)
    pcall(function()ctx.afk.close()end)
    pcall(function()ctx.action.close()end)
    pcall(function()ctx.activeRecovery.close()end)
    pcall(function()ctx.native.close()end)
    pcall(function()ctx.climb.close()end)
    pcall(function()ctx.baby.close()end)
    pcall(function()ctx.tags.close()end)
    pcall(function()ctx.flight.close()end)
    pcall(function()ctx.reach.close()end)
    pcall(function()ctx.regen.close()end)
    pcall(function()ctx.mechanics.close()end)
    pcall(function()ctx.eagleActions.close()end)
    pcall(function()ctx.diag.close()end)
    pcall(function()ctx.mobile.close()end)
    pcall(function()ctx.carry.close()end)
    pcall(function()ctx.recovery.close()end)
    pcall(function()ctx.lab.close()end)
    pcall(ctx.escape.close)
    pcall(ctx.close)
    error("[FERAL HUB] UI failure: "..tostring(window),0)
end
H.activeUI=window
-- Close a previous v28 instance before starting any new hooks. The v15
-- engine and all module shutdowns run before new recurring connections exist.
ctx.notice("FERAL NOVA Renaissance: native Rest is allowed during combat tags; real attacks, feeding and grabs still preempt it. Combat injury/bleed/venom recovery now has separate evidence buckets; server 4x remains unverified.")
-- The UI invokes ctx.close() dynamically. This wrapper is the sole active-hub
-- registry; shutting down from Close, End, RESET+Close or rerunning v28 clears it.
local activeRecord={}
local previousClose=ctx.close
local closed=false
-- Close every module's own event listeners/Heartbeat before closing the engine.
-- The old v7 wrapper called only the engine closure and could leave handlers alive.
local controllerShutdownOrder={
    "evidence","grabMini","afk","action","activeRecovery","native","eagleActions","diag","tags",
    "climb","baby","flight","reach","regen","mechanics",
    "mobile","recovery","lab","escape","carry"
}
local function closeHubControllers()
    for _,key in ipairs(controllerShutdownOrder) do
        local mod=ctx[key]
        if type(mod)=="table" and type(mod.close)=="function" then
            pcall(function() mod.close() end)
        end
    end
end
function ctx.close()
    if closed then return end
    closed=true
    pcall(H.closeSession)
    closeHubControllers()
    if activeEnv.FERAL_NOVA_PRIME_ACTIVE==activeRecord then
        activeEnv.FERAL_NOVA_PRIME_ACTIVE=nil
    end
    -- Power's wrapper closes its own Heartbeat and then the original engine.
    return previousClose()
end
activeRecord.close=function()ctx.close()end
activeRecord.version="feral-nova-v13.4.8"
activeRecord.shutdownMode="FULL_CONTROLLER_SHUTDOWN"
activeEnv.FERAL_NOVA_PRIME_ACTIVE=activeRecord

    local okMonitor,monitorError=pcall(function()H.startSession(ctx)end)
    if not okMonitor then log.monitorError=tostring(monitorError):sub(1,320)end
    local checkOK,checkError=pcall(function()H.selfCheck(ctx)end)
    if not checkOK then log.selfCheckError=tostring(checkError):sub(1,320)end
    H.phase("PRESERVED CORE FINISHED")
end,function(err)
    local msg=tostring(err)
    if type(debug)=="table" and type(debug.traceback)=="function" then
        local ok,trace=pcall(debug.traceback,msg,2)
        if ok then msg=tostring(trace)end
    end
    return clean(msg)
end)
if not worked then
    log.result="RUNTIME_ERROR"
    log.error=clean(problem)
    save()
    show("FAILED",problem,true)
else
    local hub=H.activeUI
    if hub and hub.Parent then
        pcall(function()H.brand(hub)end)
        local verified=log.selfCheck
        log.result=(verified and verified.failed==0) and "READY" or "DEGRADED"
        log.phase=log.result=="READY" and "ready" or "needs_review"
        log.previousRelease="13.4.7"
        log.preservedGameplayModules=22
        log.unchangedModuleBodiesFromPrevious=22
        log.revisedModuleBodiesFromPrevious=1
        log.updatedGameplayModules={"feral-nova-combat-v15.0.lua (v15.7 detach Cobra text panel)"}
        log.updatedUIModule="feral-nova-ui-v13.1.lua (v13.4.3 display body)"
        save()
        if log.result=="READY" then
            show("READY","v13.4.8 Cobra Text Fix / "..tostring(verified.total).." startup checks.",false)
        else
            show("INCOMPLETE","Open HELP and copy the startup report.",true)
        end
        if log.result=="READY" and type(task)=="table" and type(task.delay)=="function" then
            task.delay(7,function()
                if overlay and overlay.Parent then overlay:Destroy()end
            end)
        end
    else
        log.result="NO_HUB_CREATED"
        log.error="Core ended without the mounted FERAL v13.4.3 UI; inspect report."
        save()
        show("NO HUB CREATED",log.error,true)
    end
end
