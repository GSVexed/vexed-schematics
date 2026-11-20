-- FERAL HUB v7.2 / Eagle native event-aware carry fallback and cooldown acceptance guard
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
        lastTarget=nil,lastTargetAt=-math.huge,lastTargetGameStamp=nil,
        incomparableTargetPressClocks=0,staleTargetPressRejects=0,
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
        targetValueUpdates=0,targetTimeUpdates=0,replicatedClampEvents=0,
        localCooldownOriginalUpdates=0,skippedAlreadyHolding=0,
        anyClampObservations=0,anyClampHoldSeconds=0,longestAnyClampSeconds=0,
        anyHoldingSince=0,anyHoldingTarget=nil,unmatchedClampObservations=0,
        clientOversizeClampObservations=0,ratioUnavailable=0,
        nearServerClampObservations=0,lastServerClampAt=-math.huge,
        activeHoldRatio=nil,deadlineSource="NONE",
        remoteBinds=0,remoteLateBinds=0,remoteUnavailable=0,
        nearServerCorrelatedHold=nil,
        -- A native Talon press can occur without a server 'bit' event.
        -- One bounded fallback is allowed after a real press, never on idle.
        observedTalonPress=nil,pendingPressAt=0,pendingReplyBaseline=0,
        pressFallbackScheduled=0,pressFallbackTriggered=0,
        pressFallbackRequests=0,pressFallbackSuppressed=0,
        -- External server deadline reassertions distinguish a cosmetic
        -- client gate edit from an actually usable shorter cooldown.
        localReadyWrittenAt=-math.huge,
        deadlineServerReassertions=0,cooldownGateServerLimited=false,
    }
    local connections={}
    local charConnections={}
    local writingReady=false
    local observedChar=nil
    local remote=RS:FindFirstChild("FeralLunge")
    local remoteConnection=nil
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
    local function finishHold()
        if E.observedHoldingTarget and E.holdingSince>0 then
            local dt=math.max(0,os.clock()-E.holdingSince)
            E.actualClampHoldSeconds+=dt
            E.longestActualClampSeconds=math.max(E.longestActualClampSeconds,dt)
        end
        E.observedHoldingTarget=nil
        E.holdingSince=0
    end
    local function finishAnyHold()
        if E.anyHoldingTarget and E.anyHoldingSince>0 then
            local dt=math.max(0,os.clock()-E.anyHoldingSince)
            E.anyClampHoldSeconds+=dt
            E.longestAnyClampSeconds=math.max(E.longestAnyClampSeconds,dt)
        end
        E.anyHoldingTarget=nil
        E.anyHoldingSince=0
        E.activeHoldRatio=nil
        E.nearServerCorrelatedHold=nil
    end
    local function addSelected(v)
        if not E.alive or not v or v.Name~="FeralTalonTarget"
            or not v:IsA("ObjectValue") then return end
        local target=v.Value
        if target and target:IsA("Model") then
            local at=v:GetAttribute("At")
            local changed=E.lastTarget~=target
                or (numeric(at) and E.lastTargetGameStamp~=at)
            if changed then
                E.lastTarget=target
                -- Always use a local monotonic arrival clock for freshness.
                -- The optional game At value might use a different epoch.
                E.lastTargetAt=os.clock()
                E.lastTargetGameStamp=numeric(at) and at or nil
                E.targetSelections+=1
            end
        elseif E.lastTarget~=nil then
            E.lastTarget=nil
            E.lastTargetAt=-math.huge
            E.lastTargetGameStamp=nil
        end
    end
    local function clientRatio(prey)
        local own=localPlayer and localPlayer.Character
        local cfg=cachedAbility or getConfig()
        if not cfg or type(cfg.size)~="function" or not own then return nil end
        local ok,ratio=pcall(function()
            local ownSize=cfg.size(own)
            local preySize=cfg.size(prey)
            return numeric(ownSize) and ownSize>0 and
                numeric(preySize) and preySize/ownSize or nil
        end)
        if ok and numeric(ratio) then return ratio end
        return nil
    end
    local function observeClamp()
        local char=localPlayer and localPlayer.Character
        if not char then finishHold();finishAnyHold();return end
        local v=char:FindFirstChild("FeralClamp")
        local held=v and v:IsA("ObjectValue") and v.Value and v.Value.Parent
            and v.Value or nil
        local now=os.clock()
        if held~=E.anyHoldingTarget then
            finishAnyHold()
            if held then
                E.anyHoldingTarget=held
                E.anyHoldingSince=now
                E.anyClampObservations+=1
                local ratio=clientRatio(held)
                E.activeHoldRatio=ratio
                if not ratio then
                    E.ratioUnavailable+=1
                elseif ratio>1.45 then
                    E.clientOversizeClampObservations+=1
                end
                if now-E.lastServerClampAt<=3 then
                    E.nearServerClampObservations+=1
                    E.nearServerCorrelatedHold=held
                end
                if E.pendingClampTarget~=held then
                    E.unmatchedClampObservations+=1
                end
                E.status="OBSERVED PHYSICAL HOLD / ASSIST UNKNOWN"
            end
        end
        local allowedUntil=E.pendingClampUntil+
            (E.pendingClampResponse and 3 or 0)
        if held and held==E.pendingClampTarget and
            E.pendingClampUntil>0 and now<=allowedUntil then
            if E.observedHoldingTarget~=held then
                finishHold()
                E.observedHoldingTarget=held
                E.holdingSince=now
                E.actualClampObservations+=1
                E.pendingClampEverHeld=true
                E.status="MATCHING PREY HOLD OBSERVED"
            end
        elseif E.observedHoldingTarget and held~=E.observedHoldingTarget then
            finishHold()
        end
    end
    local function watchSelection(v)
        if not v or not v:IsA("ObjectValue") then return end
        addSelected(v)
        connect(charConnections,v:GetPropertyChangedSignal("Value"),function()
            E.targetValueUpdates+=1
            addSelected(v)
        end)
        connect(charConnections,v:GetAttributeChangedSignal("At"),function()
            E.targetTimeUpdates+=1
            addSelected(v)
        end)
    end
    local function watchClamp(v)
        if not v or not v:IsA("ObjectValue") then return end
        connect(charConnections,v:GetPropertyChangedSignal("Value"),function()
            E.replicatedClampEvents+=1
            observeClamp()
        end)
        observeClamp()
    end
    local function onChar(char)
        disconnect(charConnections)
        finishHold()
        finishAnyHold()
        observedChar=char
        E.lastTarget=nil
        E.lastTargetAt=-math.huge
        E.lastTargetGameStamp=nil
        E.lastDragTarget=nil
        E.pendingClampTarget=nil
        E.pendingClampUntil=0
        E.pendingClampResponse=false
        E.pendingClampEverHeld=false
        E.pendingPressAt=0
        E.observedTalonPress=localPlayer:GetAttribute("FeralTalonPress")
        E.deadlineServerReassertions=0
        E.cooldownGateServerLimited=false
        if not char then return end
        local v=char:FindFirstChild("FeralTalonTarget")
        if v then watchSelection(v)end
        local cl=char:FindFirstChild("FeralClamp")
        if cl then watchClamp(cl)end
        connect(charConnections,char.ChildAdded,function(obj)
            if obj.Name=="FeralTalonTarget" then watchSelection(obj)
            elseif obj.Name=="FeralClamp" then watchClamp(obj)end
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
        if E.cooldownGateServerLimited then
            E.status="SERVER COOLDOWN REASSERTED / CLIENT SHORTCUT DISABLED"
            return
        end
        local ready=localPlayer:GetAttribute("FeralLungeReadyAt")
        local char=localPlayer.Character
        local characterReady=char and char:GetAttribute("FeralLungeReadyAt")
        if numeric(ready) then
            E.deadlineSource="PLAYER"
        elseif numeric(characterReady) then
            E.deadlineSource="CHARACTER_ONLY / NO PLAYER WRITE"
        else
            E.deadlineSource="NO_REPLICATED_DEADLINE"
        end
        if not numeric(ready) then return end
        local now=Workspace:GetServerTimeNow()
        if not numeric(now) then return end
        local preset=ctx.mechanics and ctx.mechanics.preset and ctx.mechanics.preset()
        local wanted=math.clamp(preset and preset.seconds or 1.5,.35,8)
        if ready-now<=wanted+.25 then return end
        if E.lastLocalReadyWrite and ready~=E.lastLocalReadyWrite then
            E.serverDeadlineOverwrites+=1
            if os.clock()-E.localReadyWrittenAt<=3 and ready-now>10 then
                E.deadlineServerReassertions+=1
                if E.deadlineServerReassertions>=2 then
                    E.cooldownGateServerLimited=true
                    E.status="SERVER COOLDOWN REASSERTED / TRUE COOLDOWN UNCHANGED"
                    return
                end
            end
        end
        local prev=ready
        local nextTime=now+wanted
        -- Retain the latest externally supplied deadline rather than replacing
        -- our restoration anchor with our own previous locally shortened value.
        if E.lastLocalReadyWrite==nil or ready~=E.lastLocalReadyWrite then
            E.lastOriginalDeadline=prev
            E.localCooldownOriginalUpdates+=1
        end
        writingReady=true
        local ok=pcall(function()localPlayer:SetAttribute("FeralLungeReadyAt",nextTime)end)
        writingReady=false
        if ok and localPlayer:GetAttribute("FeralLungeReadyAt")==nextTime then
            E.lastLocalReadyWrite=nextTime
            E.localReadyWrittenAt=os.clock()
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
        local targetGameStamp=E.lastTargetGameStamp
        if numeric(nativePress) and numeric(targetGameStamp) then
            if math.abs(nativePress-targetGameStamp)<=120 then
                if targetGameStamp+.5<nativePress then
                    E.staleTargetPressRejects+=1
                    return nil,"TALON SELECTION PREDATES CURRENT PRESS"
                end
            else
                -- Different timestamp epochs: retain the independent
                -- recent selected-prey and character guards.
                E.incomparableTargetPressClocks+=1
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
    local bindLungeRemote
    local function nativeDragAfterScratch()
        -- Only act once after an actual server "bit" response for a recently
        -- user-selected target. If server-side size validation rejects it,
        -- we report the failure instead of spamming extra remotes.
        if not sameKindFlag("carry") then return end
        if os.clock()-E.lastDragAt<5 then
            E.guardedRejects+=1
            return
        end
        local row,why=safeTarget()
        if not row then E.lastWhy=why return end
        local held= row.char:FindFirstChild("FeralClamp")
        if held and held:IsA("ObjectValue") and held.Value then
            E.skippedAlreadyHolding+=1
            E.lastWhy="ALREADY HOLDING PREY"
            return
        end
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
        -- Same-size Eagle prey can also be locally forbidden because
        -- of elder-lift rules. Leave server acceptance to the native remote.
        if not okRatio or not numeric(ratio) or ratio<1 then
            E.lastWhy="TARGET SMALLER THAN EAGLE / NO LARGE-PREY ASSIST"
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
            local candidate=RS:FindFirstChild("FeralLunge")
            if candidate then bindLungeRemote(candidate)end
        end
        if not remote or not remote:IsA("RemoteEvent") then
            E.remoteUnavailable+=1
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
    bindLungeRemote=function(candidate)
        if not candidate or candidate.Name~="FeralLunge"
            or not candidate:IsA("RemoteEvent") then return end
        if remote==candidate and remoteConnection then return end
        if remoteConnection then
            pcall(function()remoteConnection:Disconnect()end)
            remoteConnection=nil
        end
        remote=candidate
        local ok,cn=pcall(function()
            return candidate.OnClientEvent:Connect(function(kind)
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
                E.lastServerClampAt=os.clock()
                if E.anyHoldingTarget and E.anyHoldingTarget~=E.nearServerCorrelatedHold
                    and os.clock()-E.anyHoldingSince<=3 then
                    E.nearServerClampObservations+=1
                    E.nearServerCorrelatedHold=E.anyHoldingTarget
                end
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
            end)
        end)
        if ok and cn then
            remoteConnection=cn
            E.remoteBinds+=1
            if E.remoteBinds>1 then E.remoteLateBinds+=1 end
        else
            E.remoteUnavailable+=1
        end
    end
    bindLungeRemote(remote)
    connect(connections,RS.ChildAdded,function(obj)
        if obj.Name=="FeralLunge" then bindLungeRemote(obj)end
    end)
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
        local carry=sameKindFlag("carry")
        local cooldown=sameKindFlag("cooldown")
        -- A real user Talon press is a native own-player attribute change.
        -- If the normal server reply arrives, it already determines outcome.
        -- Otherwise allow at most one extra native drag attempt after a
        -- short grace period, subject to all usual target/distance/size guards.
        local stamp=localPlayer:GetAttribute("FeralTalonPress")
        if numeric(stamp) and stamp~=E.observedTalonPress then
            E.observedTalonPress=stamp
            if carry then
                E.pendingPressAt=now
                E.pendingReplyBaseline=
                    E.serverBitReplies+E.serverClampReplies+E.serverMissReplies
                E.pressFallbackScheduled+=1
            end
        end
        if E.pendingPressAt>0 and now-E.pendingPressAt>=.75 then
            E.pendingPressAt=0
            local currentReplies=E.serverBitReplies+
                E.serverClampReplies+E.serverMissReplies
            if carry and currentReplies==E.pendingReplyBaseline then
                E.pressFallbackTriggered+=1
                local before=E.directDragAttempts
                nativeDragAfterScratch()
                if E.directDragAttempts>before then
                    E.pressFallbackRequests+=1
                end
            else
                E.pressFallbackSuppressed+=1
            end
        end
        if E.cooldownOn and not cooldown then restoreReady()end
        E.carryOn=carry
        E.cooldownOn=cooldown
        if cooldown then pcall(patchReady)end
        observeClamp()
        if E.pendingClampUntil>0 and
            now>E.pendingClampUntil+(E.pendingClampResponse and 3 or 0) then
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
            "FERAL HUB v5 / OBSERVED EAGLE OUTCOMES",
            "carry_assist_enabled="..tostring(E.carryOn),
            "cooldown_gate_enabled="..tostring(E.cooldownOn),
            "client_lunge_deadline_shortened="..E.cooldownAttrEdits,
            "native_drag_retry_requests="..E.directDragAttempts,
            "native_press_fallback_scheduled="..E.pressFallbackScheduled,
            "native_press_fallback_triggered="..E.pressFallbackTriggered,
            "native_press_fallback_requests="..E.pressFallbackRequests,
            "native_press_fallback_suppressed_reply="..E.pressFallbackSuppressed,
            "deadline_server_reassertions="..E.deadlineServerReassertions,
            "cooldown_gate_server_limited="..tostring(E.cooldownGateServerLimited),
            "lunge_remote_bind_count="..E.remoteBinds,
            "lunge_remote_late_bind_count="..E.remoteLateBinds,
            "lunge_remote_missing_count="..E.remoteUnavailable,
            "server_scratch_replies="..E.serverBitReplies,
            "server_clamp_replies="..E.serverClampReplies,
            "replicated_clamps_matching_retry="..E.actualClampObservations,
            "all_observed_physical_clamps="..E.anyClampObservations,
            "holds_not_matching_assist_target="..E.unmatchedClampObservations,
            "holds_near_server_clamp_response="..E.nearServerClampObservations,
            "held_preys_client_ratio_above_1_45="..E.clientOversizeClampObservations,
            "held_preys_size_unknown="..E.ratioUnavailable,
            "currently_holding_any_prey="..tostring(E.anyHoldingTarget~=nil),
            "current_hold_local_size_ratio="..tostring(E.activeHoldRatio),
            "all_observed_hold_seconds_finished="..string.format("%.2f",E.anyClampHoldSeconds),
            "longest_observed_hold_seconds_finished="..string.format("%.2f",E.longestAnyClampSeconds),
            "replicated_clamp_hold_seconds="..string.format("%.2f",E.actualClampHoldSeconds),
            "longest_replicated_clamp_seconds="..string.format("%.2f",E.longestActualClampSeconds),
            "clamp_reply_without_matching_hold="..E.serverClampWithoutObservedCarry,
            "native_target_selections="..E.targetSelections,
            "incomparable_target_press_clocks_ignored="..E.incomparableTargetPressClocks,
            "genuinely_stale_target_press_rejections="..E.staleTargetPressRejects,
            "target_value_changes="..E.targetValueUpdates,
            "target_timestamp_updates="..E.targetTimeUpdates,
            "replicated_clamp_value_changes="..E.replicatedClampEvents,
            "already_holding_guard_skips="..E.skippedAlreadyHolding,
            "local_cooldown_original_updates="..E.localCooldownOriginalUpdates,
            "client_deadline_reverts_observed="..E.serverDeadlineOverwrites,
            "current_deadline_attribute_source="..E.deadlineSource,
            "clamp_replies_after_assist="..E.serverClampAfterAssist,
            "server_miss_replies="..E.serverMissReplies,
            "last_server_result="..E.lastServerResult,
            "last_issue="..E.lastWhy,
            "NOTE=Client gate edits and drag requests cannot force game-server pickup.",
            "NOTE=Observed physical holds are distinguished from matching assisted-target holds.",
            "NOTE=Client size ratio is not server validated and may reflect locally patched config.",
            "NOTE=One native drag attempt per observed user press or scratch, limited to once per five seconds.",
            "NOTE=After two rapid external deadline reassertions, stop misleading local cooldown rewrites."
        },"\n")
    end
    function E.close()
        if not E.alive then return end
        E.alive=false
        restoreReady()
        E.pendingClampTarget=nil
        finishHold()
        finishAnyHold()
        if remoteConnection then
            pcall(function()remoteConnection:Disconnect()end)
            remoteConnection=nil
        end
        disconnect(connections)
        disconnect(charConnections)
    end
    ctx.eagleActions=E
    return E
end
return Eagle