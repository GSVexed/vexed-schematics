-- FERAL NOVA PRIME v15.3 / Cobra-only ESP outline range guide, no target overlay.
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
        espActive=false,espRefreshes=0,espErrors=0
    }
    -- ScreenGui, TargetPoint and CombatAimHint removed by user request.
    -- Uses the existing Aurora_PlayerOutline Highlights only.

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
    local function candidate(char,hum,root)
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
            if not best or score<bestScore then
                bestScore=score
                best={model=model,root=eRoot,hum=eHum,dist=dist,
                    gap=gap,reach=reach,margin=margin,valid=valid,
                    nativeValid=nativeValid,boostedOnly=boostedOnly,
                    angle=angle,cone=cone,vertical=vertical,
                    maxVertical=maxVertical}
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
                        if not inCone then
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
            elseif now>w.untilAt then C.window=nil end
        end
        if now<C.nextScan then return end
        C.nextScan=now+.14
        local char,hum,root=own()
        C.cobraShotState="NOT COBRA"
        C.aimLOS="UNKNOWN"
        C.cobraRangeInfo=nil
        C.cobraShotGap=nil
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
        local best=candidate(char,hum,root)
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
        -- Maintain diagnostic values without displaying an aiming overlay.
        if char:GetAttribute("Species")=="KingCobra" then
            local info=C.cobraRangeInfo
            local gap=math.max(0,best.dist-
                math.max(best.root.Size.X,best.root.Size.Z)*.5)
            C.cobraShotGap=gap
            if not info then
                C.cobraShotState="CONFIG UNAVAILABLE"
            elseif C.aimLOS=="BLOCKED" then
                C.cobraShotState="OBSTRUCTED"
            elseif best.angle>info.cone-4 then
                C.cobraShotState="OUT OF PICK CONE"
            elseif info.throw and gap<=info.throw*.90 then
                C.cobraShotState="DIVE/THROW (CLIENT)"
            elseif gap<=info.spit*.88 then
                C.cobraShotState="SPIT (CLIENT)"
            else
                C.cobraShotState="OUTSIDE SAFE RANGE"
            end
        end
    end
    local baseRefresh
    local recolorRefresh
    function C.setEnabled(v)
        C.enabled=v==true
        if ctx.refreshTracker then
            -- A full native refresh restores original ESP colours when disabled.
            pcall(ctx.refreshTracker,true)
        end
    end
    function C.report()
        return table.concat({
            "FERAL NOVA PRIME v15.3 | Cobra ESP Range Outline (No Overlay)",
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
            "esp_outline_active="..tostring(C.espActive),
            "esp_dive_green="..tostring(C.espDiveCount),
            "esp_spit_purple="..tostring(C.espSpitCount),
            "esp_default_other="..tostring(C.espOutOfLockCount),
            "esp_update_count="..tostring(C.espRefreshes),
            "esp_update_errors="..tostring(C.espErrors),
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
        if C.connection then C.connection:Disconnect()end
        if biteConnection then biteConnection:Disconnect()end
        for _,cn in ipairs(conns) do cn:Disconnect()end
        if ctx.refreshTracker==recolorRefresh then
            ctx.refreshTracker=baseRefresh
        end
    end
    C.connection=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            C.lastError=tostring(err)
            C.status="COMBAT GUIDE ERROR"
        end
    end)
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
