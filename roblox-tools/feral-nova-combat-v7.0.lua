-- FERAL NOVA PRIME v7.0 - focused, reversible bite target lab
-- Recovered client WolfController selects BiteHit targets using
-- CombatConfig.bodyGap(root,size) and CombatConfig reach/cone.
-- Local targeting changes are NOT proof of server-confirmed damage.
local Lab = {}
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local function finite(v)
    return type(v) == "number" and v == v and math.abs(v) < 1e8
end
local function close(a,b)
    return finite(a) and finite(b) and math.abs(a-b) < .0001
end
local function bodyAlive(character)
    if not character or not character.Parent then return false end
    local hum=character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health>0 and character:GetAttribute("FeralDead")~=true
end
local function safeConfig()
    local world=RS:FindFirstChild("FeralWorld")
    local mod=world and world:FindFirstChild("CombatConfig")
    if not mod or not mod:IsA("ModuleScript") then return nil end
    local ok,t=pcall(require,mod)
    if not ok or type(t)~="table"
        or type(t.bodyGap)~="function"
        or not finite(t.HIT_SCALE)
        or not finite(t.REACH)
        or not finite(t.CONE) then return nil end
    return t
end

function Lab.attach(ctx)
    local L={
        alive=true,enabled=false,status="OFF",lastError="",
        roots=0,bites=0,confirmed=0,boostedBites=0,
        normalBites=0,boostedObservations=0,normalObservations=0,
        patchedConfig=false,configStatus="NOT CHECKED",
        interval=.40,nextTick=0,maxTargets=28,range=100,
        sizeScale=1.65,lastBite=0,watch=nil,selected=nil,
        lastOutcome="NO BITE RECORDED",ratio=0,
        lastMode="OFF", lastTargetHP=nil,
        nextEconomyCheck=0, amberLast=nil, amberPositive=0,
        amberNegative=0, amberGainEvents=0, hpLast=nil,
        hpMaxLast=nil, hpGainTicks=0, hpDamageTicks=0,
        growthLast=nil, growthGain=0
    }
    local leased=setmetatable({}, {__mode="k"})
    local cfg
    local originals={}
    local applied={}
    local connections={}
    local biteConnection

    local function returnConfig()
        if cfg then
            for key,base in pairs(originals) do
                local desired=applied[key]
                pcall(function()
                    if cfg[key]==desired then cfg[key]=base end
                end)
            end
        end
        cfg=nil
        table.clear(originals)
        table.clear(applied)
        L.patchedConfig=false
    end
    local function restoreRoot(part)
        local lease=leased[part]
        if not lease then return end
        pcall(function()
            if part.Parent and part.Size==lease.wanted then
                part.Size=lease.original
            end
        end)
        leased[part]=nil
    end
    local function restoreAll()
        for part in pairs(leased) do restoreRoot(part) end
        L.roots=0
        returnConfig()
    end
    local function applyConfig()
        if cfg then return end
        cfg=safeConfig()
        if not cfg then
            L.configStatus="COMBAT CONFIG UNAVAILABLE"
            return
        end
        -- Boundaries are conservative. No cooldown, damage or hit-delay
        -- edits; those remain authoritative on the server.
        local changes={
            HIT_SCALE=math.min(cfg.HIT_SCALE*1.20,1.55),
            REACH=math.min(cfg.REACH*1.16,2.1),
            CONE=math.min(cfg.CONE+9,85)
        }
        local done=0
        for key,wanted in pairs(changes) do
            local current=cfg[key]
            if finite(current) and wanted>current then
                local ok=pcall(function() cfg[key]=wanted end)
                if ok and close(cfg[key],wanted) then
                    originals[key]=current
                    applied[key]=wanted
                    done+=1
                end
            end
        end
        L.patchedConfig=done==3
        L.configStatus=L.patchedConfig and "CLIENT CLAIM WINDOW EXPANDED"
            or "PARTIAL CONFIG SUPPORT"
    end
    local function targetPackExcluded(character)
        local ownPack=player:GetAttribute("FeralPack")
        local theirPack=character:GetAttribute("FeralPack")
        return ownPack~=nil and theirPack~=nil and ownPack==theirPack
    end
    local function candidates()
        local own=player.Character
        local ownRoot=own and own:FindFirstChild("HumanoidRootPart")
        if not ownRoot or not bodyAlive(own) then return {},nil end
        local out={}
        local origin=ownRoot.Position
        local function add(model)
            if model==own or not bodyAlive(model) or targetPackExcluded(model) then return end
            local r=model:FindFirstChild("HumanoidRootPart")
            if not r or not r:IsA("BasePart") then return end
            local d=(origin-r.Position).Magnitude
            if d<=L.range then
                out[#out+1]={part=r,model=model,hum=model:FindFirstChildOfClass("Humanoid"),dist=d}
            end
        end
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player and other.Character then add(other.Character) end
        end
        local npcFolder=workspace:FindFirstChild("FeralNPCs")
        if npcFolder then
            local i=0
            for _,npc in ipairs(npcFolder:GetChildren()) do
                i+=1
                if i>70 then break end
                if npc:IsA("Model") then add(npc) end
            end
        end
        table.sort(out,function(a,b) return a.dist<b.dist end)
        while #out>L.maxTargets do table.remove(out) end
        return out,ownRoot
    end
    local function resizeRoot(part)
        local existing=leased[part]
        if existing then
            if part.Size~=existing.wanted and part.Size~=existing.original then
                -- An external state change/animal morph owns the new size.
                -- Never fight another writer or overwrite a changed part.
                restoreRoot(part)
                return false
            end
            return true
        end
        if part.Anchored or not finite(part.Size.X) or not finite(part.Size.Z) then
            return false
        end
        local original=part.Size
        local wanted=Vector3.new(
            math.min(original.X*L.sizeScale,16),
            original.Y,
            math.min(original.Z*L.sizeScale,16)
        )
        if wanted.X<=original.X or wanted.Z<=original.Z then return false end
        local ok=pcall(function()part.Size=wanted end)
        if not ok or part.Size~=wanted then return false end
        leased[part]={original=original,wanted=wanted}
        return true
    end

    -- Observes replicated Humanoid.Health after own bite input. A decrease
    -- is a correlated observation, NOT verified damage attribution.
    local function onBite()
        local now=os.clock()
        if now-L.lastBite<.08 then return end
        L.bites+=1
        L.lastBite=now
        local targets,root=candidates()
        local preferred
        if root then
            local forward=root.CFrame.LookVector
            for _,candidate in ipairs(targets) do
                if candidate.dist<22 then
                    local delta=candidate.part.Position-root.Position
                    if delta.Magnitude>.02 and forward:Dot(delta.Unit)>.45 then
                        preferred=candidate
                        break
                    end
                end
            end
        end
        L.watch=nil
        L.lastMode=L.enabled and "BOOSTED" or "NORMAL"
        if L.enabled then L.boostedBites+=1 else L.normalBites+=1 end
        if preferred and preferred.hum then
            L.watch={
                hum=preferred.hum,
                original=preferred.hum.Health,
                untilAt=now+1.15,done=false,boost=L.enabled
            }
            L.lastTargetHP=preferred.hum.Health
            L.lastOutcome="WATCHING TARGET HP"
        else
            L.lastOutcome="NO ELIGIBLE TARGET IN CONE"
        end
    end
    local function characterChanged(character)
        if biteConnection then biteConnection:Disconnect();biteConnection=nil end
        L.watch=nil
        if character then
            biteConnection=character:GetAttributeChangedSignal("WolfBiteAt"):Connect(onBite)
        end
    end
    connections[#connections+1]=player.CharacterAdded:Connect(characterChanged)
    characterChanged(player.Character)

    function L.setEnabled(wanted)
        L.enabled=wanted==true
        if L.enabled then
            applyConfig()
            L.status="LOCAL HIT WINDOW BOOST"
            L.nextTick=0
        else
            restoreAll()
            L.status="OFF"
        end
        return L.enabled
    end
    function L.report()
        return table.concat({
            "FERAL NOVA PRIME v7 | Hitbox Test",
            "mode="..(L.enabled and "LOCAL BOOST ON" or "OFF"),
            "root_parts_expanded="..tostring(L.roots),
            "local_claim_config="..L.configStatus,
            "total_bites_seen="..tostring(L.bites),
            "normal_bites="..tostring(L.normalBites),
            "boosted_bites="..tostring(L.boostedBites),
            "hp_decreases_near_normal_bite="..tostring(L.normalObservations),
            "hp_decreases_near_boosted_bite="..tostring(L.boostedObservations),
            "last_observation="..L.lastOutcome,
            "last_error="..L.lastError,
            "visible_amber="..tostring(L.amberLast),
            "observed_amber_net_positive="..tostring(L.amberPositive),
            "observed_amber_net_spend="..tostring(L.amberNegative),
            "observed_amber_gain_events="..tostring(L.amberGainEvents),
            "observed_hp_increase_ticks_unchanged_max="..tostring(L.hpGainTicks),
            "observed_hp_decrease_ticks="..tostring(L.hpDamageTicks),
            "observed_growth_increase="..string.format("%.4f",L.growthGain),
            "IMPORTANT=Replicated HP changes are not guaranteed to be caused by your bite.",
            "IMPORTANT=Local enlargement alone does not prove the server accepts longer hits."
        },"\n")
    end
    function L.close()
        L.alive=false
        L.setEnabled(false)
        if L.connection then L.connection:Disconnect();L.connection=nil end
        if biteConnection then biteConnection:Disconnect();biteConnection=nil end
        for _,c in ipairs(connections) do c:Disconnect() end
    end

    local function tick()
        if not L.alive then return end
        local now=os.clock()
        if L.watch then
            local w=L.watch
            if w.hum and w.hum.Parent and finite(w.hum.Health)
                and w.hum.Health<w.original-.05 and not w.done then
                w.done=true
                L.lastOutcome="REPLICATED HP DECREASE SEEN"
                if w.boost then
                    L.boostedObservations+=1
                else
                    L.normalObservations+=1
                end
            end
            if now>w.untilAt or w.done then L.watch=nil end
        end
        if now>=L.nextEconomyCheck then
            L.nextEconomyCheck=now+1.0
            local ok,a=pcall(ctx.stats)
            if ok and type(a)=="table" then
                if finite(a.amber) then
                    if L.amberLast~=nil then
                        local d=a.amber-L.amberLast
                        if d>0 then
                            L.amberPositive+=d
                            L.amberGainEvents+=1
                        elseif d<0 then
                            L.amberNegative-=d
                        end
                    end
                    L.amberLast=a.amber
                end
                if finite(a.hp) and finite(a.maxHp) then
                    if L.hpLast~=nil and L.hpMaxLast==a.maxHp then
                        if a.hp>L.hpLast+.01 then
                            L.hpGainTicks+=1
                        elseif a.hp<L.hpLast-.01 then
                            L.hpDamageTicks+=1
                        end
                    end
                    L.hpLast=a.hp
                    L.hpMaxLast=a.maxHp
                end
                if finite(a.growth) then
                    if L.growthLast~=nil and a.growth>L.growthLast then
                        L.growthGain+=a.growth-L.growthLast
                    end
                    L.growthLast=a.growth
                end
            end
        end
        if not L.enabled or now<L.nextTick then return end
        L.nextTick=now+L.interval
        if not player.Character or not bodyAlive(player.Character) then
            restoreAll();L.status="WAITING FOR ANIMAL";return
        end
        applyConfig()
        local seen={}
        local targets=candidates()
        local count=0
        for _,item in ipairs(targets) do
            seen[item.part]=true
            if resizeRoot(item.part) then count+=1 end
        end
        for part in pairs(leased) do
            if not seen[part] then restoreRoot(part) end
        end
        L.roots=count
        L.status=(count>0) and "LOCAL HIT WINDOW BOOST"
            or "SEARCHING FOR REPLICATED TARGETS"
    end
    L.connection=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            L.lastError=tostring(err)
            L.setEnabled(false)
            L.status="BOOST ERROR; RESTORED"
        end
    end)
    return L
end
return Lab
