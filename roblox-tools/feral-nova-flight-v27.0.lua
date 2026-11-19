-- FERAL NOVA PRIME v27 / WATER-SAFE FLIGHT AND AIR CARRY
-- Preserves normal water floating and native swimming; never unlocks WATER.NO_TAKEOFF.
-- Never requests flight while floating/swimming. Existing native land/air flight
-- is unchanged; outgoing clamp's local mode is only guarded while fully airborne.
-- Does NOT change target parts or send invented flight/carry remotes.
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
        waterTakeoffBlocked=0,waterAirborneSamples=0,waterContacts=0,
        lastRequestAt=0,lastAirborne=false,lastOwner=nil,
        lastTakeoffCarry=false,serverCarryRetained="NOT VERIFIED",
        midairPreyProtects=0,characterConnections={}
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
        F.applied=false
        F.config=nil
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
            F.status="FLIGHT CONFIG WAITING"
            F.lastError=why
            return false
        end
        -- Important regression fix: never write WATER.NO_TAKEOFF or WATER.GRACE.
        -- Both are left exactly as the game supplied them.
        F.lease=nil
        F.config=cfg
        F.applied=true
        F.lastError=""
        F.status="NATIVE WATER FLOAT / AIR CARRY READY"
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
        -- Water takeoff is deliberately disabled. The game controls its own
        -- Swimming/float state. An executor request here caused occasional
        -- underwater flight and conspicuous movement.
        if not F.alive or not F.enabled then return false end
        local char,hum=own()
        if char and isWater(char,hum) then
            F.waterTakeoffBlocked+=1
            F.status="WATER FLOAT PRIORITY / TAKEOFF BLOCKED"
        else
            F.status="NORMAL TAKEOFF IS GAME CONTROLLED"
        end
        return false
    end
    function F.beforeCarry()
        -- Drop/pickup always takes priority; never preserve a local
        -- airborne clamp override across a deliberate G action.
        restoreClamp()
        F.takeoffPendingUntil=0
        return false
    end
    function F.setEnabled(v)
        if v==false then
            F.enabled=false
            F.takeoffPendingUntil=0
            restoreClamp()
            restoreWater()
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
            F.status="WAITING FOR BIRD"
            F.lastOwner=nil
            F.lastAirborne=false
            return
        end
        if F.lastOwner and char~=F.lastOwner then
            restoreClamp()
            F.takeoffPendingUntil=0
        end
        F.lastOwner=char
        F.eligible=canFly(char,F.config)
        if not F.eligible then
            restoreClamp()
            F.status="NOT A FLIGHT SPECIES / GROWTH LOCKED"
            return
        end
        local previousWater=F.water
        F.water=isWater(char,hum)
        F.airborne=char:GetAttribute("FeralFlyLocal")==true
        if F.water and not previousWater then
            F.waterContacts+=1
            F.takeoffPendingUntil=0
            restoreClamp()
        end
        if F.water and F.airborne then
            F.waterAirborneSamples+=1
        end
        F.holding=outgoingClamp(char)~=nil
        if F.airborne and not F.lastAirborne then
            if now-F.lastRequestAt<3.2 then
                F.observedTakeoffs+=1
                if F.lastTakeoffCarry then F.waterCarryTakeoffs+=1 end
            end
        end
        F.lastAirborne=F.airborne
        if F.airborne and F.holding and not F.water then
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
            local keep=F.holding and F.enabled and not F.water
                and char==owned.owner
                and (F.airborne or now<F.takeoffPendingUntil)
            if not keep then restoreClamp() end
        end
        if F.water and F.airborne then
            F.status="WATER + FLIGHT OVERLAP DETECTED / NO HUB TAKEOFF"
        elseif F.water then
            F.status="WATER FLOAT PRIORITY / NATIVE SWIMMING"
        elseif F.airborne then
            F.status=F.holding and "AIR CARRY ACTIVE (LOCAL)"
                or "NORMAL AIR FLIGHT ACTIVE"
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
            "water_takeoff_requests_blocked="..F.waterTakeoffBlocked,
            "water_contacts="..F.waterContacts,
            "water_flight_overlap_samples="..F.waterAirborneSamples,
            "water_NO_TAKEOFF_modified=false",
            "water_GRACE_modified=false",
            "observed_flight_after_request="..F.observedTakeoffs,
            "water_prey_takeoffs="..F.waterCarryTakeoffs,
            "flight_with_prey_seconds_local="..string.format("%.2f",F.flyWithPreySeconds),
            "temporary_local_drag_modes="..F.airCarrySessions,
            "midair_carry_guard_attempts="..F.midairPreyProtects,
            "local_config_restorations="..F.restores,
            "config_or_clamp_conflicts="..F.conflicts,
            "last_error="..F.lastError,
            "NOTE=No prey/animal physics modifications or fabricated server remotes.",
            "NOTE=Native water float is preserved. Server owns flight/swim outcomes."
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
                    if hum and canFly(char,F.config) and not isWater(char,hum)
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
        if F.conn then F.conn:Disconnect()end
        for _,c in ipairs(F.characterConnections) do
            pcall(function()c:Disconnect()end)
        end
        for _,c in ipairs(listeners) do pcall(function()c:Disconnect()end)end
    end
    watchChar(player.Character)
    listeners[#listeners+1]=player.CharacterAdded:Connect(function(char)
        restoreClamp()
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
