-- FERAL Health Recovery v1.1 | PlaceId 108901361810209
-- One recovery switch: native Rest signal for missing HP or active own conditions.
-- Bear captures support 2x out-of-combat HP recovery and faster clotting in combat.
-- Combat HP regeneration remains unestablished. Injury/venom benefit is unverified.
-- No HP, condition or combat-flag writes; optional earlier stamina tuning.
-- Only the local rest-pose flag is masked. Native downed/death state is untouched.
-- No full scan, purchases, gifts, spawn requests, account data or other-player data.

-- BEGIN TESTABLE CORE
local Core = {}
function Core.finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end
function Core.errorMeta(value)
    local text = type(value) == "string" and value or ""
    local lower = string.lower(text)
    local kind = "runtime_error"
    if lower:find("permission", 1, true) or lower:find("security", 1, true) then kind = "permission_error"
    elseif lower:find("readonly", 1, true) or lower:find("read-only", 1, true) then kind = "readonly_error"
    elseif lower:find("not a valid member", 1, true) then kind = "missing_member" end
    return {kind = kind, line = tonumber(text:match(":(%d+):"))}
end
function Core.restore(lease)
    local errors = 0
    for i = #(lease and lease.entries or {}), 1, -1 do
        local entry = lease.entries[i]
        local ok = pcall(function()
            if lease.target[entry.key] == entry.wanted then lease.target[entry.key] = entry.old end
        end)
        if not ok then errors = errors + 1 end
    end
    return errors
end
function Core.patch(target, changes)
    local lease = {target = target, entries = {}, expected = table.clone(changes)}
    for key, wanted in pairs(changes) do
        local ok, old = pcall(function() return target[key] end)
        if not ok then Core.restore(lease); return nil end
        if old ~= wanted then
            if not pcall(function() target[key] = wanted end) then Core.restore(lease); return nil end
            lease.entries[#lease.entries + 1] = {key = key, old = old, wanted = wanted}
        end
    end
    return lease
end
function Core.matches(lease)
    if not lease then return false end
    for key, value in pairs(lease.expected) do if lease.target[key] ~= value then return false end end
    return true
end
Core.species = {"Wolf", "Fox", "Deer", "Elk", "Bear", "Cougar", "SnowLeopard", "Eagle", "Vulture", "Falcon", "Tiger", "Otter", "Porcupine", "Bison", "Hippo", "Rhino", "Elephant", "Alligator", "Python", "Komodo", "RedPanda", "Gorilla", "KingCobra", "Phantosuchus"}
function Core.speciesName(value)
    for _, item in ipairs(Core.species) do if value == item then return item end end
    return "other"
end
function Core.push(log, item)
    log.total = log.total + 1
    if #log.events < log.limit then log.events[#log.events + 1] = item
    else log.omitted = log.omitted + 1 end
end
Core.conditions = {
    {key = "bleed", attribute = "FeralBleed"},
    {key = "injury", attribute = "FeralInjury"},
    {key = "venom", attribute = "FeralVenomAmt"},
}
function Core.recoveryReasons(sample)
    local reasons = {}
    if Core.finite(sample.health) and Core.finite(sample.health_max) and sample.health > 0
        and sample.health < sample.health_max - .001 then reasons[#reasons + 1] = "health" end
    for _, condition in ipairs(Core.conditions) do
        if Core.finite(sample[condition.key]) and sample[condition.key] > 0 then
            reasons[#reasons + 1] = condition.key
        end
    end
    return reasons
end
-- END TESTABLE CORE

local abort, phase = nil, "place_check"
local function run()
    if game.PlaceId ~= 108901361810209 then warn("[FERAL Health] Open FERAL first."); return end
    phase = "services"
    local Players, RS = game:GetService("Players"), game:GetService("ReplicatedStorage")
    local RunService, UIS = game:GetService("RunService"), game:GetService("UserInputService")
    local Http = game:GetService("HttpService")
    local player = Players.LocalPlayer
    local parent = player and (player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 8))
    if not parent then warn("[FERAL Health] PlayerGui unavailable; rerun after joining."); return end
    for _, name in ipairs({"FeralFieldHubV10", "FeralFieldHubV11", "FeralFieldHubV12", "FeralFieldHubV13", "FeralFieldHubV14", "FeralHealthRecoveryV10", "FeralHealthRecoveryV11"}) do
        local old = parent:FindFirstChild(name)
        if old then
            local shutdown = old:FindFirstChild("HubShutdown")
            if shutdown and shutdown:IsA("BindableEvent") then shutdown:Fire() end
            if old.Parent then old:Destroy() end
        end
    end
    local s = {
        alive = true, born = os.clock(), connections = {}, charConnections = {},
        recovery = false, stamina = false,
        log = {events = {}, total = 0, omitted = 0, limit = 6000}, errors = 0,
        counts = {true_requests = 0, false_requests = 0, hp_up = 0, hp_down = 0,
            max_changes = 0, retained_gains = 0, retained_combat_gains = 0,
            gains_invalidated = 0, rest_echoes_masked = 0, bite_inputs_observed = 0},
        generation = 0, candidates = {}, status = "Off. Enable Recovery Assist when ready.",
        conditionCounts = {bleed = {decreases = 0, removals = 0}, injury = {decreases = 0, removals = 0}, venom = {decreases = 0, removals = 0}},
        moduleStatus = "No module checked.", lastSample = -math.huge, lastAutoSave = os.clock(),
        lastRequest = -math.huge, revision = 0, fileStatus = "No file saved yet.",
        leases = {}, cacheBusy = false, cacheWaiters = {}, saveBusy = false,
    }
    local token = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
    s.base = "FERAL_Health_Report_v1_1_" .. token
    local renderName = "FeralHealthPose_" .. token
    local C = {bg = Color3.fromRGB(14, 23, 30), surface = Color3.fromRGB(28, 44, 55),
        text = Color3.fromRGB(236, 245, 241), muted = Color3.fromRGB(170, 192, 195),
        blue = Color3.fromRGB(38, 100, 143), green = Color3.fromRGB(30, 130, 101), red = Color3.fromRGB(153, 59, 77)}
    local function emit(kind, data)
        data = table.clone(data or {}); data.kind, data.t = kind, math.max(0, os.clock() - s.born)
        data.generation = s.generation
        Core.push(s.log, data)
    end
    local function failure(where, detail)
        s.errors = s.errors + 1
        local meta = Core.errorMeta(detail); meta.where = where
        s.lastError = meta; emit("error", {where = where, error_kind = meta.kind, line = meta.line})
    end
    local function optional(name)
        local found = ({writefile = writefile, readfile = readfile, setclipboard = setclipboard,
            toclipboard = toclipboard, getloadedmodules = getloadedmodules})[name]
        if type(found) == "function" then return found end
        if type(getgenv) == "function" then
            local ok, env = pcall(getgenv)
            if ok and type(env) == "table" and type(env[name]) == "function" then return env[name] end
        end
    end
    local function new(class, props, owner)
        local item = Instance.new(class)
        for key, value in pairs(props or {}) do item[key] = value end
        item.Parent = owner
        return item
    end
    local function connect(signal, fn, bucket)
        local c = signal:Connect(fn); table.insert(bucket or s.connections, c); return c
    end
    local function disconnect(bucket)
        for _, c in ipairs(bucket) do pcall(function() c:Disconnect() end) end
        table.clear(bucket)
    end
    local stopHealth, cleanup, save, refresh
    phase = "gui"
    local gui = new("ScreenGui", {Name = "FeralHealthRecoveryV11", ResetOnSpawn = false, DisplayOrder = 85}, parent)
    abort = function() if cleanup then cleanup("startup_error") elseif gui.Parent then gui:Destroy() end end
    local shutdown = new("BindableEvent", {Name = "HubShutdown"}, gui)
    local frame = new("Frame", {Name = "HealthPanel", BackgroundColor3 = C.bg, BorderSizePixel = 0,
        Size = UDim2.fromOffset(500, 548), Position = UDim2.new(0, 22, 0.5, -274)}, gui)
    new("UICorner", {CornerRadius = UDim.new(0, 10)}, frame)
    local scale = new("UIScale", {Scale = 1}, frame)
    local title = new("TextLabel", {Text = "FERAL / HEALTH RECOVERY v1.1", Font = Enum.Font.Gotham, Active = true,
        TextSize = 14, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -100, 0, 40)}, frame)
    local close = new("TextButton", {Text = "X", TextSize = 15, TextColor3 = C.text, BackgroundColor3 = C.red,
        Size = UDim2.fromOffset(32, 28), Position = UDim2.new(1, -40, 0, 7), BorderSizePixel = 0}, frame)
    local hide = new("TextButton", {Text = "-", TextSize = 17, TextColor3 = C.text, BackgroundColor3 = C.blue,
        Size = UDim2.fromOffset(32, 28), Position = UDim2.new(1, -78, 0, 7), BorderSizePixel = 0}, frame)
    local body = new("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(14, 44), Size = UDim2.new(1, -28, 1, -56), ScrollBarThickness = 4,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, frame)
    new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, body)
    local order = 0
    local function label(text, height)
        order = order + 1
        return new("TextLabel", {Text = text, TextSize = 12, Font = Enum.Font.Gotham,
            TextColor3 = C.muted, RichText = false, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, height), LayoutOrder = order}, body)
    end
    local function button(text, color)
        order = order + 1
        return new("TextButton", {Text = text, TextSize = 12, Font = Enum.Font.GothamBold,
            TextColor3 = C.text, BackgroundColor3 = color or C.blue, BorderSizePixel = 0,
            Size = UDim2.new(1, -8, 0, 34), LayoutOrder = order}, body)
    end
    label("Recovery Assist starts OFF. Bear captures support faster healing outside combat and faster clotting during combat. Combat HP regeneration remains unresolved.", 48)
    local live = label("Waiting for your animal...", 52)
    local conditionsText = label("Conditions: waiting...", 24)
    local recoveryButton = button("RECOVERY ASSIST: OFF")
    local recoveryText = label("Uses the native recovery signal when HP is missing or bleeding, injury or venom is active. The local rest pose is masked. Injury/venom benefit remains unverified.", 48)
    local evidence = label("HP recovery and condition changes are recorded separately.", 52)
    local staminaButton = button("STAMINA TUNING: OFF", C.surface)
    local stopButton = button("STOP & SAVE", C.red)
    local saveButton = button("SAVE HEALTH REPORT .JSON", C.surface)
    local copyButton = button("COPY REPORT FILENAME", C.surface)
    local fileText = label("Small report only; no full diagnostic needed. Reports go in Velocity's workspace.", 44)
    local function action(control, fn)
        connect(control.Activated, function()
            if not s.alive then return end
            local ok, detail = pcall(fn)
            if not ok then failure("control", detail); if stopHealth then stopHealth("control_error") end end
        end)
    end
    local function context()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local result = {generation = s.generation, species = Core.speciesName(char and char:GetAttribute("Species")),
            recovery_enabled = s.recovery, request_active = s.signal ~= nil, pose_mask_active = s.mask ~= nil,
            stamina_applied = Core.matches(s.leases.stamina),
            combat = false, mode = "idle"}
        local untilTime = player:GetAttribute("FeralCombatUntil")
        local clockOK, serverTime = pcall(function() return workspace:GetServerTimeNow() end)
        result.combat_known = clockOK and Core.finite(serverTime)
        if result.combat_known and Core.finite(untilTime) then result.combat = untilTime > serverTime end
        local values = {health = hum and hum.Health, health_max = hum and hum.MaxHealth,
            growth = char and char:GetAttribute("Growth"), hunger = char and char:GetAttribute("Hunger"),
            thirst = char and char:GetAttribute("Thirst"), injury = char and char:GetAttribute("FeralInjury"),
            bleed = char and char:GetAttribute("FeralBleed"), venom = char and char:GetAttribute("FeralVenomAmt")}
        for key, value in pairs(values) do if Core.finite(value) then result[key] = value end end
        if char then
            result.local_rest = char:GetAttribute("WolfRest") == true
            result.downed = char:GetAttribute("FeralDowned") == true
            if char:GetAttribute("FeralPinned") or char:GetAttribute("CarriedBy") then result.mode = "grab"
            elseif char:GetAttribute("FeralFlyLocal") then result.mode = "flight"
            elseif char:GetAttribute("FeralClimbLocal") then result.mode = "climb"
            elseif char:GetAttribute("FeralSwimLocal") or char:GetAttribute("FeralUnderwater") then result.mode = "swim"
            elseif char:GetAttribute("FeralBurrowed") then result.mode = "burrow"
            elseif player:GetAttribute("HudBurst") then result.mode = "burst"
            elseif player:GetAttribute("HudSprint") then result.mode = "sprint"
            elseif hum and hum.MoveDirection and hum.MoveDirection.Magnitude > .1 then result.mode = "move" end
        end
        if root then
            local velocity = root.AssemblyLinearVelocity
            local speed = math.sqrt(velocity.X * velocity.X + velocity.Z * velocity.Z)
            if Core.finite(speed) then result.horizontal_speed = speed end
        end
        result.recovery_reasons = Core.recoveryReasons(result)
        return result, char, hum, root
    end
    local function restPacket(char, enabled)
        -- Remote has no character argument. Never send an old-character cleanup to a replacement.
        if player.Character ~= char then return false end
        local remote = RS:FindFirstChild("WolfActions")
        if not remote or not remote:IsA("RemoteEvent") then return false end
        local ok, detail = pcall(function() remote:FireServer("Rest", enabled) end)
        if not ok then failure("rest_request", detail) end
        if ok then
            local key = enabled and "true_requests" or "false_requests"
            s.counts[key] = s.counts[key] + 1
        end
        emit("rest_request", {enabled = enabled, api_call_succeeded = ok, server_acceptance = "unknown"})
        return ok
    end
    local function releaseMask()
        local mask = s.mask; s.mask = nil
        if not mask then return end
        if mask.connection then mask.connection:Disconnect() end
        pcall(function() RunService:UnbindFromRenderStep(renderName) end)
        -- Keep false after our request ends; do not restore the server's earlier true echo.
        pcall(function() if mask.char.Parent then mask.char:SetAttribute("WolfRest", false) end end)
    end
    local function stopSignal(reason)
        local signal = s.signal; s.signal = nil
        if signal then
            local restored = restPacket(signal.char, false)
            emit("recovery_signal_stopped", {reason = reason, false_request_sent = restored,
                character_still_current = player.Character == signal.char})
        end
        releaseMask()
    end
    local function beginMask(char)
        local mask = {char = char, writing = false}
        s.mask = mask
        local function enforce()
            if s.mask ~= mask or mask.writing or not s.alive then return end
            if player.Character ~= char then stopSignal("character_changed"); return end
            local ok, detail = pcall(function()
                if char:GetAttribute("WolfRest") == true then
                    s.counts.rest_echoes_masked = s.counts.rest_echoes_masked + 1
                    mask.writing = true; char:SetAttribute("WolfRest", false); mask.writing = false
                end
            end)
            mask.writing = false
            if not ok then
                failure("pose_mask", detail); s.recovery = false
                s.status = "Pose mask failed. Recovery stopped; no further true requests."
                stopSignal("pose_mask_failed")
            end
        end
        local ok, detail = pcall(function()
            mask.connection = char:GetAttributeChangedSignal("WolfRest"):Connect(enforce)
            -- Native WolfAnim renders at Camera+2 (202). Run before it, without hooking it.
            RunService:BindToRenderStep(renderName, 199, enforce)
            char:SetAttribute("WolfRest", false)
        end)
        if not ok then failure("pose_mask_start", detail); releaseMask(); return false end
        return true
    end
    local function needsModule(key, callback)
        s.cacheWaiters[key] = callback
        if s.cacheBusy then return end
        s.cacheBusy = true; s.moduleStatus = "Checking the already-loaded NeedsConfig cache..."
        task.delay(6, function()
            if s.alive and s.cacheBusy then s.moduleStatus = "Cache check still waiting; UI remains usable. No duplicate job started." end
        end)
        task.spawn(function()
            if not s.alive then s.cacheBusy = false; s.cacheWaiters = {}; return end
            local fw = RS:FindFirstChild("FeralWorld")
            local target = fw and fw:FindFirstChild("NeedsConfig")
            local loaded = optional("getloadedmodules")
            local ok, config = pcall(function()
                if not target or not target:IsA("ModuleScript") or not loaded then return nil end
                local list = loaded()
                if type(list) ~= "table" then return nil end
                local count = 0
                for _, module in pairs(list) do
                    count = count + 1
                    if module == target then return require(target) end
                    if count >= 100000 or not s.alive then break end
                    if count % 512 == 0 then task.wait() end
                end
            end)
            s.cacheBusy = false
            local waiters = s.cacheWaiters; s.cacheWaiters = {}
            if not s.alive then return end
            local current = RS:FindFirstChild("FeralWorld")
            if not ok then failure("cached_module", config) end
            if not ok or type(config) ~= "table" or not current or current:FindFirstChild("NeedsConfig") ~= target then config = nil end
            s.moduleStatus = config and "NeedsConfig read from the loaded cache." or "Loaded cache unavailable. No new game module was started."
            for _, callback1 in pairs(waiters) do callback1(config) end
        end)
    end
    local function releaseFlag()
        local flag = s.staminaFlag; s.staminaFlag = nil
        if not flag then return end
        local ok, detail = pcall(function()
            if flag.char:GetAttribute("WolfDbgNoStamina") == true then flag.char:SetAttribute("WolfDbgNoStamina", flag.old) end
        end)
        if not ok then failure("stamina_flag_restore", detail) end
    end
    local function applyFlag(char)
        if not char or s.staminaFlag then return end
        local old = char:GetAttribute("WolfDbgNoStamina")
        char:SetAttribute("WolfDbgNoStamina", true)
        s.staminaFlag = {char = char, old = old}
    end
    local function restoreLease(key)
        local errors = Core.restore(s.leases[key]); s.leases[key] = nil
        for _ = 1, errors do failure("config_restore", "") end
    end
    local function stopStamina()
        s.stamina = false; s.staminaEpoch = (s.staminaEpoch or 0) + 1
        restoreLease("stamina"); releaseFlag()
    end
    stopHealth = function(reason)
        s.recovery = false
        stopSignal(reason)
        s.status = "Recovery off. No HP or condition values were written."
        emit("health_experiments_stopped", {reason = reason})
    end
    action(recoveryButton, function()
        if s.updateFailed then s.status = "Update stopped. Save report and rerun before starting a trial."; return end
        s.recovery = not s.recovery
        if not s.recovery then stopSignal("toggle_off") end
        s.status = s.recovery and "Armed across respawns. Waiting for missing HP or active conditions."
            or "Recovery requests off."
        emit("recovery_toggled", {enabled = s.recovery, includes_combat = true})
    end)
    action(staminaButton, function()
        if s.updateFailed then s.status = "Update stopped. Save report and rerun before starting a trial."; return end
        if s.stamina then stopStamina(); return end
        s.stamina = true; s.staminaEpoch = (s.staminaEpoch or 0) + 1
        local epoch = s.staminaEpoch
        applyFlag(player.Character)
        needsModule("stamina", function(config)
            if not s.alive or not s.stamina or s.staminaEpoch ~= epoch then return end
            local changes = {STAMINA_SPRINT_DRAIN = 0, STAMINA_JUMP_COST = 0,
                STAMINA_REGEN = 250, STAMINA_REGEN_DELAY = 0, STAMINA_LOW_NEEDS = 1}
            if not config then s.moduleStatus = "Stamina flag only; cached tuning unavailable."; return end
            for key in pairs(changes) do
                if not Core.finite(config[key]) then s.moduleStatus = "Stamina flag only; config fields do not match."; return end
            end
            s.leases.stamina = Core.patch(config, changes)
            if not s.leases.stamina then
                failure("stamina_config_write", ""); s.moduleStatus = "Stamina flag only; cached table write failed."
            end
        end)
    end)
    local function observe(kind)
        if not s.alive or not s.hum or player.Character ~= s.char then return end
        local snapshot = context()
        local hp, maximum = snapshot.health, snapshot.health_max
        if not hp or not maximum then return end
        if s.lastMax and maximum ~= s.lastMax then
            s.maxEpoch = (s.maxEpoch or 0) + 1; s.maxAt = os.clock()
            s.counts.max_changes = s.counts.max_changes + 1
        end
        local difference = s.lastHP and hp - s.lastHP or 0
        for _, candidate in ipairs(s.candidates) do candidate.minimum = math.min(candidate.minimum, hp) end
        if difference > .001 then
            s.counts.hp_up = s.counts.hp_up + 1
            if #s.candidates < 64 then
                s.candidates[#s.candidates + 1] = {at = os.clock(), health = hp, gain = difference,
                    minimum = hp, epoch = s.maxEpoch, stableBefore = os.clock() - (s.maxAt or s.born) >= 1.5,
                    combat = snapshot.combat and snapshot.combat_known, generation = s.generation,
                    requested = snapshot.request_active,
                    continuousCombat = snapshot.combat and snapshot.combat_known}
            else
                s.counts.gains_invalidated = s.counts.gains_invalidated + 1
                emit("gain_not_classified", {reason = "64_pending_candidate_limit"})
            end
        elseif difference < -.001 then s.counts.hp_down = s.counts.hp_down + 1 end
        s.lastHP, s.lastMax = hp, maximum
        snapshot.change = difference
        emit(kind, snapshot)
    end
    local function bindCharacter(char, hum)
        if char == s.char and hum == s.hum then return end
        stopSignal("character_or_humanoid_changed"); releaseFlag(); disconnect(s.charConnections)
        s.counts.gains_invalidated = s.counts.gains_invalidated + #s.candidates
        s.candidates = {}; s.char, s.hum = char, hum
        s.generation = s.generation + 1; s.maxEpoch = 0; s.maxAt = os.clock()
        s.lastHP, s.lastMax = nil, nil
        emit("own_character_changed", {humanoid_present = hum ~= nil})
        if char then
            for _, condition in ipairs(Core.conditions) do
                local previous = char:GetAttribute(condition.attribute)
                connect(char:GetAttributeChangedSignal(condition.attribute), function()
                    if not s.alive or s.char ~= char or player.Character ~= char then return end
                    local current = char:GetAttribute(condition.attribute)
                    local snapshot = context()
                    snapshot.condition = condition.key
                    snapshot.attribute_present = current ~= nil
                    snapshot.numeric_value = Core.finite(current)
                    if Core.finite(previous) then snapshot.previous_condition_value = previous end
                    if Core.finite(current) then snapshot.condition_value = current end
                    if Core.finite(current) and Core.finite(previous) then
                        snapshot.condition_change = current - previous
                        if current < previous then
                            s.conditionCounts[condition.key].decreases = s.conditionCounts[condition.key].decreases + 1
                        end
                    elseif current == nil and Core.finite(previous) and previous > 0 then
                        s.conditionCounts[condition.key].removals = s.conditionCounts[condition.key].removals + 1
                        snapshot.positive_attribute_removed = true
                    end
                    emit("condition_changed", snapshot)
                    previous = current
                end, s.charConnections)
            end
            connect(char:GetAttributeChangedSignal("WolfBiteAt"), function()
                s.counts.bite_inputs_observed = s.counts.bite_inputs_observed + 1
                emit("native_bite_marker", {attack_accepted_by_server = "unknown"})
            end, s.charConnections)
        end
        if hum then
            connect(hum:GetPropertyChangedSignal("Health"), function() observe("health_changed") end, s.charConnections)
            connect(hum:GetPropertyChangedSignal("MaxHealth"), function() observe("health_max_changed") end, s.charConnections)
            observe("initial_health")
        end
        if s.stamina then applyFlag(char) end
    end
    local function report()
        return {schema = "feral-health-report/1.1", version = "1.1", place_id = game.PlaceId,
            seconds = math.max(0, os.clock() - s.born), current = context(), counts = table.clone(s.counts),
            status = s.status, errors = s.errors, last_error = s.lastError, module_status = s.moduleStatus,
            condition_counts = s.conditionCounts,
            timeline = {events = s.log.events, total = s.log.total, stored = #s.log.events, omitted = s.log.omitted,
                limit = s.log.limit, policy = "first_events_preserved_later_events_counted_as_omitted"},
            pending_gain_classifications = #s.candidates, previous_export = s.lastExport,
            limits = {health_writes = 0, condition_writes = 0, combat_flag_tuning = "not_attempted",
                server_health_code_available = false, server_flag_changed = false,
                server_rest_acknowledgement_available = false, causal_healing_effect = "not_established",
                gains = "Observed HP increases retained 3s with stable MaxHealth, not proof of extra healing or server acceptance.",
                conditions = "Own attribute changes only; removal is marked explicitly. Faster clotting has prior observational support; injury/venom effects remain unverified.",
                local_pose_mask = "Only own local WolfRest attribute; server/other-client pose and attack acceptance unknown.",
                scope = "Own HP, needs, condition, movement mode and experiment events only; no raw errors or identity."}}
    end
    save = function(auto)
        if s.saveBusy then
            if not auto then s.pendingManualSave = true end
            return
        end
        local writer = optional("writefile")
        if not writer then
            s.fileStatus = "writefile unavailable. Save cannot create a file in this executor."
            return
        end
        s.saveBusy = true
        s.revision = s.revision + 1
        local name = s.base .. (auto and ("_CHECKPOINT_" .. (s.revision % 2 == 0 and "A" or "B"))
            or ("_SAVE_" .. string.format("%03d", s.revision))) .. ".json.txt"
        -- Snapshot/encode before dispatch: a later UI close cannot mutate this export.
        local ok, encoded = pcall(function() return Http:JSONEncode(report()) end)
        if not ok then s.saveBusy = false; failure("json_encode", encoded); s.fileStatus = "JSON encoding failed; no file marked saved."; return end
        s.fileStatus = "Saving " .. name .. "..."
        task.spawn(function()
            local written, detail = pcall(writer, name, encoded)
            local verified, reader = false, optional("readfile")
            if written and reader then
                local readOK, data = pcall(reader, name)
                verified = readOK and data == encoded
            end
            if not written then failure("file_write", detail) end
            s.lastExport = {file = name, bytes = #encoded, written = written, readback_verified = verified}
            s.lastFilename = written and name or s.lastFilename
            s.fileStatus = written and (name .. (verified and "\nSaved and exact readback verified."
                or "\nWritten; readback verification unavailable or failed.")) or "File write failed. No export marked saved."
            s.saveBusy = false
            if s.pendingManualSave then s.pendingManualSave = false; save(false) end
        end)
    end
    refresh = function()
        local sample = context()
        local hp = sample.health and string.format("%.2f / %.2f", sample.health, sample.health_max or 0) or "waiting"
        live.Text = "HP: " .. hp .. " | combat: " .. (sample.combat_known and tostring(sample.combat) or "unknown")
            .. " | " .. sample.mode .. "\n" .. s.status
        local function conditionValue(value)
            return Core.finite(value) and string.format("%.1f", value) or "--"
        end
        conditionsText.Text = "Bleed " .. conditionValue(sample.bleed) .. " | Injury " .. conditionValue(sample.injury)
            .. " | Venom " .. conditionValue(sample.venom) .. "  (-- = absent/unavailable)"
        recoveryButton.Text = "RECOVERY ASSIST: " .. (s.recovery and "ON" or "OFF")
        recoveryButton.BackgroundColor3 = s.recovery and C.green or C.blue
        recoveryText.Text = "Request: " .. (s.signal and "active (acceptance unknown)" or "standby/off")
            .. " | local pose mask: " .. tostring(s.mask ~= nil)
            .. "\nNeeds: " .. (#sample.recovery_reasons > 0 and table.concat(sample.recovery_reasons, ", ") or "none")
        evidence.Text = "HP gains retained 3s: " .. s.counts.retained_gains .. " | throughout combat: " .. s.counts.retained_combat_gains
            .. "\nPrior Bear captures: ~2x HP recovery outside combat; faster clotting in combat. Injury/venom benefit unverified."
            .. (s.log.omitted > 0 and (" LOG FULL: " .. s.log.omitted .. " later events omitted; save and restart.") or "")
        staminaButton.Text = "STAMINA TUNING: " .. (s.stamina and "ON" or "OFF")
        fileText.Text = s.fileStatus
    end
    action(stopButton, function() stopHealth("manual_stop"); save(false); refresh() end)
    action(saveButton, function() save(false); refresh() end)
    action(copyButton, function()
        local copy = optional("setclipboard") or optional("toclipboard")
        if not s.lastFilename then s.fileStatus = "Save a report first."; return end
        if not copy or not pcall(copy, s.lastFilename) then s.fileStatus = "Clipboard unavailable. Filename is shown below." end
    end)
    local minimized = false
    action(hide, function()
        minimized = not minimized; body.Visible = not minimized
        frame.Size = UDim2.fromOffset(500, minimized and 40 or 548); hide.Text = minimized and "+" or "-"
    end)
    local drag
    connect(title.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = {start = input.Position, position = frame.Position}
        end
    end)
    connect(UIS.InputChanged, function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - drag.start
            frame.Position = UDim2.new(drag.position.X.Scale, drag.position.X.Offset + delta.X,
                drag.position.Y.Scale, drag.position.Y.Offset + delta.Y)
        end
    end)
    connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drag = nil end
    end)
    cleanup = function(reason)
        if not s.alive then return end
        stopHealth(reason); stopStamina(); s.alive = false
        disconnect(s.charConnections); disconnect(s.connections)
        save(false)
        if gui.Parent then gui:Destroy() end
    end
    action(close, function() cleanup("closed") end)
    connect(shutdown.Event, function() cleanup("replaced") end)
    connect(gui.Destroying, function() cleanup("external_destroy") end)
    connect(player.CharacterRemoving, function(char)
        if char == s.char then stopSignal("character_removing"); releaseFlag(); disconnect(s.charConnections) end
    end)
    local function tick()
        local now = os.clock()
        local sample, char, hum, root = context()
        bindCharacter(char, hum)
        if s.recovery then
            local reason
            if not char or not hum or not root or sample.species == "other" then reason = "waiting_for_spawned_animal"
            elseif not sample.health or sample.health <= 0 or sample.downed then reason = "dead_or_downed_standby"
            elseif player:GetAttribute("FeralMenuOpen") or player:GetAttribute("FeralTitleOpen") then reason = "menu_standby"
            elseif not sample.health_max then reason = "health_max_unavailable"
            elseif #sample.recovery_reasons == 0 then reason = "no_recovery_needed"
            elseif not s.signal and char:GetAttribute("WolfRest") == true then reason = "stand_up_normally_first" end
            if reason then
                stopSignal(reason)
                s.status = reason == "no_recovery_needed" and "Armed. Full HP / no active condition; waiting."
                    or ("Armed / " .. reason)
            elseif now - s.lastRequest >= 5 then
                s.lastRequest = now
                if not s.mask and not beginMask(char) then
                    s.recovery = false; s.status = "Local pose mask unavailable. No true request sent."
                else
                    -- Establish ownership before FireServer, including synchronous mock/server echoes.
                    s.signal = s.signal or {char = char}
                    if not restPacket(char, true) then
                        s.recovery = false; stopSignal("true_request_failed")
                        s.status = "Recovery request unavailable/failed. Toggle off; no retry loop."
                    elseif s.recovery then s.status = sample.combat and "Recovery active. Combat HP healing remains unestablished."
                        or "Recovery active for missing HP or conditions." end
                end
            end
        end
        sample = context()
        if s.signal and s.recovery then
            s.status = sample.combat and "Recovery active. Combat HP healing remains unestablished."
                or "Recovery active for missing HP or conditions."
        end
        for i = #s.candidates, 1, -1 do
            local candidate = s.candidates[i]
            candidate.continuousCombat = candidate.continuousCombat and sample.combat and sample.combat_known
            if now - candidate.at >= 3 then
                local retained = candidate.generation == s.generation and candidate.stableBefore
                    and candidate.epoch == s.maxEpoch and candidate.minimum >= candidate.health - .001
                if retained then
                    s.counts.retained_gains = s.counts.retained_gains + 1
                    if candidate.continuousCombat then s.counts.retained_combat_gains = s.counts.retained_combat_gains + 1 end
                else s.counts.gains_invalidated = s.counts.gains_invalidated + 1 end
                emit("gain_classified", {gain = candidate.gain, retained_3s_stable_max = retained,
                    combat_at_gain = candidate.combat, observed_combat_throughout = candidate.continuousCombat,
                    request_at_gain = candidate.requested,
                    causal_effect = "unknown"})
                table.remove(s.candidates, i)
            end
        end
        if now - s.lastSample >= 1 then
            s.lastSample = now; observe("sample")
            local camera = workspace.CurrentCamera
            if camera then scale.Scale = math.clamp(math.min(camera.ViewportSize.X / 540, camera.ViewportSize.Y / 590), .4, 1) end
            refresh()
        end
        if now - s.lastAutoSave >= 30 then s.lastAutoSave = now; save(true) end
    end
    phase = "heartbeat"
    connect(RunService.Heartbeat, function()
        if not s.alive then return end
        local ok, detail = pcall(tick)
        if not ok then
            s.updateFailed = true
            failure("update", detail); stopHealth("update_error"); stopStamina()
            s.status = "Update failed. Health/stamina stopped; save report and rerun."
            disconnect(s.charConnections)
            -- Disconnect this update and retain the GUI/export controls.
            if s.heartbeat then s.heartbeat:Disconnect() end
        end
    end)
    s.heartbeat = s.connections[#s.connections]
    bindCharacter(player.Character, player.Character and player.Character:FindFirstChildOfClass("Humanoid"))
    emit("started", {health_experiments_default = "off", combat_request_allowed = true})
    refresh(); phase = "ready"
end
local ok, detail = pcall(run)
if not ok then
    if abort then pcall(abort) end
    local meta = Core.errorMeta(detail)
    warn("[FERAL Health] Startup failed at " .. phase .. " / " .. meta.kind .. " / line " .. tostring(meta.line or "unknown"))
end
