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
