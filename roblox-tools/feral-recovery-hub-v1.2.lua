-- FERAL Recovery Hub v1.2 | PlaceId 108901361810209
-- Native recovery signal and one combined 3x client stamina recovery switch.
-- Normal costs, low-needs penalties and Burst settings remain intact.
-- No source collection, file exports, HP writes or no-drain debug flag.
-- Observed recovery: about 2x HP outside combat, faster bleed/venom clearance.
-- Combat HP regen and reliable unlimited Burst remain unresolved.
-- Optional moving regen targets only the own Humanoid's native jump callback.
-- Four changing HUD samples must identify one stamina upvalue before writes.
-- Adds bounded 3x recovery during flat/draining activity in the shared client pool.
-- Native positive recovery is never counted twice. No HUD pinning.

-- BEGIN TESTABLE CORE
local Core = {}
function Core.finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
function Core.restore(lease)
    local errors = 0
    for i = #(lease and lease.entries or {}), 1, -1 do
        local entry = lease.entries[i]
        local ok = pcall(function()
            if lease.target[entry.key] == entry.wanted then
                lease.target[entry.key] = entry.old
                assert(lease.target[entry.key] == entry.old)
            end
        end)
        if not ok then errors = errors + 1 end
    end
    return errors
end
function Core.matches(lease)
    if not lease then return false end
    local ok, matches = pcall(function()
        for _, entry in ipairs(lease.entries) do
            if lease.target[entry.key] ~= entry.wanted then return false end
        end
        return true
    end)
    return ok and matches
end
function Core.restRate(config)
    if type(config) ~= "table" then return nil, "Loaded config unavailable." end
    local base, nativeRest = config.STAMINA_REGEN, config.STAMINA_REST_MULT
    local multiplier = 3
    if not Core.finite(base) or base <= 0 or not Core.finite(nativeRest) or nativeRest <= 1
        or not Core.finite(base * multiplier) then return nil, "Stamina fields do not match the expected config." end
    local lease = {target = config, multiplier = multiplier, entries = {}}
    -- Clear the extra native rest multiplier first, so actual rest does not stack to 9x.
    for _, item in ipairs({{"STAMINA_REST_MULT", 1}, {"STAMINA_REGEN", base * multiplier}}) do
        local entry = {key = item[1], old = config[item[1]], wanted = item[2]}
        lease.entries[#lease.entries + 1] = entry
        local ok = pcall(function()
            config[entry.key] = entry.wanted
            assert(config[entry.key] == entry.wanted)
        end)
        if not ok then
            local errors = Core.restore(lease)
            return nil, errors > 0 and "Config rollback failed; rejoin to reset." or "Config is not writable."
        end
    end
    return lease
end
Core.species = {"Wolf", "Fox", "Deer", "Elk", "Bear", "Cougar", "SnowLeopard", "Eagle", "Vulture", "Falcon", "Tiger", "Otter", "Porcupine", "Bison", "Hippo", "Rhino", "Elephant", "Alligator", "Python", "Komodo", "RedPanda", "Gorilla", "KingCobra", "Phantosuchus"}
function Core.animal(value)
    for _, species in ipairs(Core.species) do if species == value then return species end end
    return nil
end
function Core.needsRecovery(char, hum)
    if Core.finite(hum.Health) and Core.finite(hum.MaxHealth) and hum.Health > 0
        and hum.Health < hum.MaxHealth - .001 then return true end
    for _, key in ipairs({"FeralBleed", "FeralInjury", "FeralVenomAmt"}) do
        local value = char:GetAttribute(key)
        if Core.finite(value) and value > 0 then return true end
    end
    return false
end
function Core.poolSample(binding, values, displayed)
    if type(values) ~= "table" or not Core.finite(displayed) then return nil end
    if not binding.candidates then
        binding.candidates = {}
        local count = 0
        for index, value in pairs(values) do
            if type(index) == "number" and index % 1 == 0 and index >= 1 and index <= 128
                and Core.finite(value) and math.abs(value - displayed) <= .051 then
                count = count + 1; binding.candidates[index] = true
            end
        end
        if count > 16 then return nil end
    end
    local count, candidate = 0, nil
    for index in pairs(binding.candidates) do
        local value = values[index]
        if not Core.finite(value) or math.abs(value - displayed) > .051 then binding.candidates[index] = nil
        else count = count + 1; candidate = index end
    end
    if count == 0 then return nil end
    if binding.lastDisplay ~= displayed then
        binding.samples = (binding.samples or 0) + 1
        binding.low = math.min(binding.low or displayed, displayed)
        binding.high = math.max(binding.high or displayed, displayed)
        binding.lastDisplay = displayed
    end
    if binding.samples >= 4 and binding.high - binding.low >= .25 then
        if count == 1 then return candidate end
        binding.ambiguous = true
    end
    return false
end
function Core.recoveryRate(config, char)
    local rate, lowAt, penalty = config.STAMINA_REGEN, config.LOW_NEED_AT, config.STAMINA_LOW_NEEDS
    if not Core.finite(rate) or rate <= 0 or not Core.finite(lowAt)
        or not Core.finite(penalty) or penalty < 0 or penalty > 1 then return nil end
    local hunger, thirst = char:GetAttribute("Hunger"), char:GetAttribute("Thirst")
    if not Core.finite(hunger) or not Core.finite(thirst) then return nil end
    if hunger < lowAt or thirst < lowAt then rate = rate * penalty end
    return rate
end
function Core.increment(current, previous, maximum, rate, dt, allowFlat)
    if not Core.finite(current) or not Core.finite(previous) or not Core.finite(maximum)
        or not Core.finite(rate) or not Core.finite(dt) or maximum <= .1 or rate < 0 or dt <= 0
        or current < 0 or current > maximum + .1 then return nil end
    -- Trot can hold the native pool flat. Native positive recovery stays untouched.
    if current > previous or (not allowFlat and current >= previous - .000001) then return current end
    return math.max(current, math.min(maximum - .05, current + rate * math.min(dt, .1)))
end
-- END TESTABLE CORE

local abort
local function run()
    if game.PlaceId ~= 108901361810209 then warn("[FERAL Recovery] Open FERAL first."); return end
    local Players, RS = game:GetService("Players"), game:GetService("ReplicatedStorage")
    local RunService, UIS = game:GetService("RunService"), game:GetService("UserInputService")
    local player = Players.LocalPlayer
    local parent = player and (player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 8))
    if not parent then warn("[FERAL Recovery] PlayerGui unavailable; rerun after joining."); return end
    for _, name in ipairs({"FeralFieldHubV10", "FeralFieldHubV11", "FeralFieldHubV12", "FeralFieldHubV13", "FeralFieldHubV14", "FeralHealthRecoveryV10", "FeralHealthRecoveryV11", "FeralHealthRecoveryV12", "FeralHealthRecoveryV13", "FeralRecoveryHubV10", "FeralRecoveryHubV11", "FeralRecoveryHubV12"}) do
        local old = parent:FindFirstChild(name)
        if old then
            local shutdown = old:FindFirstChild("HubShutdown")
            if shutdown and shutdown:IsA("BindableEvent") then shutdown:Fire() end
            if old.Parent then old:Destroy() end
        end
    end
    local s = {alive = true, recovery = false, stamina = false, moving = false, epoch = 0,
        connections = {}, cacheWaiters = {}, lastBind = -math.huge,
        lastRequest = -math.huge, lastTick = -math.huge, lastUi = -math.huge,
        recoveryStatus = "Recovery off.", staminaStatus = "3x stamina recovery off.", movingStatus = "Extra stamina recovery off."}
    local C = {bg = Color3.fromRGB(16, 24, 34), text = Color3.fromRGB(230, 238, 245),
        muted = Color3.fromRGB(165, 187, 204), blue = Color3.fromRGB(39, 95, 147),
        green = Color3.fromRGB(21, 121, 98), red = Color3.fromRGB(149, 49, 66)}
    local function new(class, props, owner)
        local item = Instance.new(class)
        for key, value in pairs(props or {}) do item[key] = value end
        item.Parent = owner
        return item
    end
    local function connect(signal, fn)
        local connection = signal:Connect(fn)
        s.connections[#s.connections + 1] = connection
        return connection
    end
    local gui = new("ScreenGui", {Name = "FeralRecoveryHubV12", ResetOnSpawn = false, DisplayOrder = 85}, parent)
    local cleanup, refresh, stopSignal, stopStamina, stopMoving, releaseMoving, prepareMoving, fail
    abort = function() if cleanup then cleanup() elseif gui.Parent then gui:Destroy() end end
    local shutdown = new("BindableEvent", {Name = "HubShutdown"}, gui)
    local frame = new("Frame", {Name = "RecoveryPanel", BackgroundColor3 = C.bg, BorderSizePixel = 0,
        Size = UDim2.fromOffset(460, 590), Position = UDim2.new(0, 22, .5, -295)}, gui)
    new("UICorner", {CornerRadius = UDim.new(0, 10)}, frame)
    local scale = new("UIScale", {Scale = 1}, frame)
    local title = new("TextLabel", {Text = "FERAL / RECOVERY HUB v1.2", Active = true, Font = Enum.Font.Gotham,
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
            TextColor3 = C.muted, TextWrapped = true, RichText = false,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, height), LayoutOrder = order}, body)
    end
    local function button(text, color)
        order = order + 1
        return new("TextButton", {Text = text, TextSize = 12, Font = Enum.Font.GothamBold,
            TextColor3 = C.text, BackgroundColor3 = color or C.blue, BorderSizePixel = 0,
            Size = UDim2.new(1, -8, 0, 34), LayoutOrder = order}, body)
    end
    local live = label("Waiting for your animal...", 42)
    local recoveryButton = button("RECOVERY ASSIST: OFF")
    label("Uses the working native Rest signal and masks your local rest pose. Captures support ~2x HP recovery outside combat and faster bleed/venom clearing. Combat HP regen remains unresolved.", 60)
    local recoveryStatus = label(s.recoveryStatus, 30)
    local staminaButton = button("3X STAMINA REGEN: OFF")
    label("One switch: 3x recovery across movement modes, including climbing. Native costs and needs penalties still apply. Move briefly to bind; stays armed across respawns.", 60)
    local staminaStatus = label(s.staminaStatus, 42)
    local movingStatus = label(s.movingStatus, 44)
    local stopButton = button("TURN EVERYTHING OFF", C.red)
    label("All controls start off and stay armed across respawns. Drag the title; - minimizes; X stops controls and restores owned settings. This menu collects no reports.", 44)
    local renderName = "FeralRecoveryPose_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
    local movingRenderName = renderName .. "_Stamina"
    local function restPacket(char, enabled)
        -- No character parameter exists in this protocol: never target a replacement with old cleanup.
        if player.Character ~= char then return false end
        local remote = RS:FindFirstChild("WolfActions")
        if not remote or not remote:IsA("RemoteEvent") then return false end
        return pcall(function() remote:FireServer("Rest", enabled) end)
    end
    local function releaseMask()
        local mask = s.mask; s.mask = nil
        if not mask then return end
        if mask.connection then mask.connection:Disconnect() end
        pcall(function() RunService:UnbindFromRenderStep(renderName) end)
        pcall(function() if mask.char.Parent then mask.char:SetAttribute("WolfRest", false) end end)
    end
    stopSignal = function()
        local signal = s.signal; s.signal = nil
        releaseMask()
        if signal and player.Character == signal.char and not restPacket(signal.char, false) then
            s.recoveryStatus = "Rest cleanup unavailable; stand/rest normally or rejoin to reset."
        end
    end
    local function beginMask(char)
        local mask = {char = char, writing = false}
        s.mask = mask
        local function enforce()
            if s.mask ~= mask or mask.writing or not s.alive then return end
            if player.Character ~= char then stopSignal(); return end
            local ok = pcall(function()
                if char:GetAttribute("WolfRest") == true then
                    mask.writing = true; char:SetAttribute("WolfRest", false)
                end
            end)
            mask.writing = false
            if not ok then
                s.recovery = false; stopSignal()
                s.recoveryStatus = "Local pose mask failed. Recovery stopped."
            end
        end
        local ok = pcall(function()
            mask.connection = char:GetAttributeChangedSignal("WolfRest"):Connect(enforce)
            -- Native WolfAnim runs at Camera+2 (202); mask only our local pose first.
            RunService:BindToRenderStep(renderName, 199, enforce)
            char:SetAttribute("WolfRest", false)
        end)
        if not ok then releaseMask(); return false end
        return s.mask == mask and s.recovery
    end
    stopStamina = function(message)
        s.stamina = false; s.moving = false; s.epoch = s.epoch + 1; s.cacheWaiters.stamina = nil
        if releaseMoving then releaseMoving() end
        s.movingConfig, s.movingApi = nil, nil
        s.bindChar, s.bindHum, s.bindStarted = nil, nil, nil
        local errors = Core.restore(s.lease); s.lease = nil
        s.staminaStatus = errors > 0 and "Config restoration failed; rejoin to reset."
            or message or "3x stamina recovery off; owned settings restored."
        s.movingStatus = message or "Extra recovery stopped. Native stamina continues from its current value."
    end
    local function loadedConfig(key, callback)
        s.cacheWaiters[key] = callback
        if s.cacheBusy then return end
        s.cacheBusy = true
        task.delay(6, function()
            if s.alive and s.cacheBusy then
                if s.stamina then s.staminaStatus = "Loaded-cache check is waiting. Toggle off to cancel." end
                if s.moving then s.movingStatus = "Loaded-cache check is waiting. Toggle off to cancel." end
            end
        end)
        task.spawn(function()
            if not s.alive then s.cacheBusy = false; table.clear(s.cacheWaiters); return end
            local fw = RS:FindFirstChild("FeralWorld")
            local target = fw and fw:FindFirstChild("NeedsConfig")
            local getter = type(getloadedmodules) == "function" and getloadedmodules or nil
            if not getter and type(getgenv) == "function" then
                local ok, env = pcall(getgenv)
                if ok and type(env) == "table" and type(env.getloadedmodules) == "function" then getter = env.getloadedmodules end
            end
            local ok, config = pcall(function()
                if not getter or not target or not target:IsA("ModuleScript") then return nil end
                local list = getter()
                if type(list) ~= "table" then return nil end
                local count = 0
                for _, module in pairs(list) do
                    if not s.alive then break end
                    if module == target then return require(target) end
                    count = count + 1
                    if count >= 100000 then break end
                    if count % 512 == 0 then task.wait() end
                end
                return nil
            end)
            s.cacheBusy = false
            local latest = s.cacheWaiters; s.cacheWaiters = {}
            if not s.alive then return end
            local current = RS:FindFirstChild("FeralWorld")
            if not ok or type(config) ~= "table" or not current or current:FindFirstChild("NeedsConfig") ~= target then config = nil end
            for _, waiter in pairs(latest) do
                if not pcall(waiter, config) then fail(); break end
            end
        end)
    end
    local function optional(name)
        local globals = {getconnections = getconnections, getconstants = getconstants,
            getupvalues = getupvalues, setupvalue = setupvalue, getfenv = getfenv}
        if type(globals[name]) == "function" then return globals[name] end
        if type(getgenv) == "function" then
            local ok, env = pcall(getgenv)
            if ok and type(env) == "table" and type(env[name]) == "function" then return env[name] end
        end
        if type(debug) == "table" and type(debug[name]) == "function" then return debug[name] end
        return nil
    end
    releaseMoving = function()
        local binding = s.binding; s.binding = nil
        if binding and binding.connection then binding.connection:Disconnect() end
        pcall(function() RunService:UnbindFromRenderStep(movingRenderName) end)
        s.lastBind = -math.huge
        if s.stamina then s.staminaStatus = "3x rate remains armed; waiting for a fresh stamina pool match." end
    end
    stopMoving = function(message)
        stopStamina(message)
    end
    local function movementMode(char, hum)
        if char:GetAttribute("FeralDowned") == true or player:GetAttribute("FeralMenuOpen")
            or player:GetAttribute("FeralTitleOpen") then return false end
        if char:GetAttribute("FeralClimbLocal") == true then return "climb" end
        if char:GetAttribute("FeralFlyLocal") == true then return "flight" end
        if char:GetAttribute("FeralSwimLocal") or char:GetAttribute("FeralUnderwater") or char:GetAttribute("FeralDiving") then return "swim" end
        if char:GetAttribute("FeralBurrowed") then return "burrow" end
        if char:GetAttribute("FeralPinned") or char:GetAttribute("CarriedBy") or char:GetAttribute("FeralDragged") then return "held" end
        if hum.MoveDirection.Magnitude <= .1 then return "idle" end
        if player:GetAttribute("HudBurst") == true or char:GetAttribute("WolfBurst") == true then return "burst" end
        if player:GetAttribute("HudSprint") == true then return "sprint" end
        if player:GetAttribute("HudTrot") == true or char:GetAttribute("WolfTrot") == true then return "trot" end
        return "walk"
    end
    local function movingFrame(binding, dt)
        if not s.alive or not s.moving or s.binding ~= binding then return end
        if not Core.matches(s.lease) then stopMoving("Config changed externally; 3x stamina recovery stopped."); return end
        local char, hum, api = binding.char, binding.hum, s.movingApi
        if player.Character ~= char or char:FindFirstChildOfClass("Humanoid") ~= hum then releaseMoving(); return end
        local scripts = player:FindFirstChildOfClass("PlayerScripts")
        if not scripts or scripts:FindFirstChild("WolfController") ~= binding.script
            or binding.script.Enabled == false or binding.script.Disabled == true then
            stopMoving("Native controller replaced/stopped; moving recovery stopped."); return
        end
        if not hum.Parent or not char.Parent or not Core.finite(hum.Health) or hum.Health <= 0 then
            binding.previous = nil; s.movingStatus = "Armed; waiting until alive."; return
        end
        if char:GetAttribute("WolfDbgNoStamina") == true then stopMoving("Existing no-drain flag detected; moving recovery stopped."); return end
        if not binding.index then return end
        local values = api.upvalues(binding.fn)
        if type(values) ~= "table" or values[binding.configIndex] ~= s.movingConfig then
            stopMoving("Controller config changed; moving recovery stopped."); return
        end
        local current = values[binding.index]
        local maximum = char:GetAttribute("StaminaMax")
        if not Core.finite(current) or not Core.finite(maximum) or current < 0 or current > maximum + .1 then
            stopMoving("Stamina binding changed; moving recovery stopped."); return
        end
        local previous = binding.previous; binding.previous = current
        if not previous then return end
        local mode = movementMode(char, hum)
        if not mode then
            s.movingStatus = "Armed; waiting for the menu to close or downed state to end."; return
        end
        -- A genuinely flat bar may not emit changes. A matching current HUD
        -- permits a bounded start; continued gains require native HUD publication.
        local displayed = char:GetAttribute("Stamina")
        local matchedFlat = current == previous and Core.finite(displayed)
            and math.abs(current - displayed) <= .051
        if os.clock() - (binding.lastHud or -math.huge) > 2 and not matchedFlat then
            s.movingStatus = "Bound; waiting for a fresh native stamina update."; return
        end
        local rate = Core.recoveryRate(s.movingConfig, char)
        if not rate then s.movingStatus = "Bound; waiting for valid needs/recovery settings."; return end
        local wanted = Core.increment(current, previous, maximum, rate, dt, true)
        if not wanted then stopMoving("Invalid stamina timing/value; moving recovery stopped."); return end
        if wanted > current then
            api.set(binding.fn, binding.index, wanted)
            local after = api.upvalues(binding.fn)
            if type(after) ~= "table" or after[binding.index] ~= wanted then
                stopMoving("Velocity did not confirm the stamina write; moving recovery stopped."); return
            end
            binding.previous = wanted
            s.movingStatus = string.format("%s: adding %.2f stamina/s. Native costs still apply.", mode, rate)
        else
            s.movingStatus = "Bound. Native recovery/full pool or no applicable drain; no extra recovery."
        end
    end
    prepareMoving = function(char, hum, root)
        s.lastBind = os.clock()
        if not char or not hum or not root or not char.Parent or hum.Health <= 0
            or not Core.animal(char:GetAttribute("Species")) or char:GetAttribute("IsWolf") ~= true then
            s.movingStatus = "Armed; waiting for your spawned animal."; return
        end
        if s.bindChar ~= char or s.bindHum ~= hum then
            s.bindChar, s.bindHum, s.bindStarted = char, hum, os.clock()
        end
        local function waiting(message)
            if os.clock() - s.bindStarted < 10 then s.movingStatus = message; return true end
            return false
        end
        local scripts = player:FindFirstChildOfClass("PlayerScripts")
        local target = scripts and scripts:FindFirstChild("WolfController")
        if not target or not target:IsA("LocalScript") then
            if not waiting("Waiting for your native controller to start...") then stopMoving("WolfController unavailable; moving recovery remains off.") end
            return
        end
        local api = s.movingApi
        local list = api.connections(hum.StateChanged)
        if type(list) ~= "table" then stopMoving("Velocity did not return native connections; moving recovery remains off."); return end
        local matches, seen = {}, {}
        local count = 0
        for _, connection in pairs(list) do
            count = count + 1
            if count > 128 then stopMoving("Native callback list exceeded the matching limit; no stamina writes."); return end
            local ok, fn = pcall(function() return connection.Function end)
            if ok and type(fn) == "function" and not seen[fn] then
                seen[fn] = true
                local good, configIndex = pcall(function()
                    if api.env(fn).script ~= target then return nil end
                    local constants, values = api.constants(fn), api.upvalues(fn)
                    if type(constants) ~= "table" or type(values) ~= "table" then return nil end
                    local keys, n = {}, 0
                    for _, value in pairs(constants) do
                        n = n + 1; if n > 2048 then return nil end
                        if value == "STAMINA_JUMP_COST" or value == "Jumping" then keys[value] = true end
                    end
                    if not keys.STAMINA_JUMP_COST or not keys.Jumping then return nil end
                    local own, found = false, nil
                    n = 0
                    for index, value in pairs(values) do
                        n = n + 1; if n > 128 then return nil end
                        if value == hum or value == char or value == root then own = true end
                        if value == s.movingConfig and type(index) == "number" and index % 1 == 0
                            and index >= 1 and index <= 128 then found = index end
                    end
                    return own and found or nil
                end)
                if good and configIndex then matches[#matches + 1] = {fn = fn, configIndex = configIndex} end
            end
        end
        if #matches == 0 then
            if not waiting("Waiting for the native stamina callback; no stamina writes yet.") then
                stopMoving("Native stamina callback could not be matched. No stamina writes.")
            end
            return
        elseif #matches ~= 1 then stopMoving("Could not uniquely match the native stamina callback. No stamina writes."); return end
        local binding = {char = char, hum = hum, script = target, fn = matches[1].fn, configIndex = matches[1].configIndex}
        s.binding = binding
        binding.connection = char:GetAttributeChangedSignal("Stamina"):Connect(function()
            if not s.alive or not s.moving or s.binding ~= binding or player.Character ~= char then return end
            local ok = pcall(function()
                local values, displayed = api.upvalues(binding.fn), char:GetAttribute("Stamina")
                binding.lastHud = os.clock()
                if binding.index then
                    if type(values) ~= "table" or not Core.finite(values[binding.index]) or not Core.finite(displayed)
                        or math.abs(values[binding.index] - displayed) > .051 then
                        stopMoving("Native stamina no longer matches; moving recovery stopped.")
                    end
                else
                    local index = Core.poolSample(binding, values, displayed)
                    if index == nil then stopMoving("Native stamina match failed. No stamina writes.")
                    elseif binding.ambiguous then stopMoving("Stamina match is ambiguous. No stamina writes.")
                    elseif index then
                        binding.index = index; binding.previous = values[index]
                        s.staminaStatus = "3x stamina recovery enabled across movement modes. Native costs remain active."
                        s.movingStatus = "Native stamina pool matched."
                    end
                end
            end)
            if not ok then stopMoving("Stamina matching API failed. Moving recovery stopped.") end
        end)
        local ok = pcall(function()
            -- Native WolfMove is Input+1 (101); add after its normal movement cost.
            RunService:BindToRenderStep(movingRenderName, 102, function(dt)
                if not pcall(movingFrame, binding, dt) then stopMoving("Stamina access/write failed. Moving recovery stopped.") end
            end)
        end)
        if not ok then stopMoving("Render-step access unavailable; moving recovery remains off."); return end
        s.movingStatus = "Run briefly: waiting for four changing stamina updates to match the pool."
    end
    fail = function()
        s.failed = true; s.recovery = false; stopSignal(); stopStamina()
        s.recoveryStatus = "Update failed. Controls stopped; rerun the loader."
        if s.heartbeat then s.heartbeat:Disconnect() end
        if refresh then pcall(refresh) end
    end
    local function action(control, fn)
        connect(control.Activated, function()
            if not s.alive then return end
            local ok = pcall(function() fn(); refresh() end)
            if not ok then fail() end
        end)
    end
    action(recoveryButton, function()
        if s.failed then return end
        s.recovery = not s.recovery
        if not s.recovery then stopSignal() end
        s.recoveryStatus = s.recovery and "Armed for missing HP or active conditions." or "Recovery off."
    end)
    action(staminaButton, function()
        if s.failed then return end
        if s.stamina then stopStamina(); return end
        if player.Character and player.Character:GetAttribute("WolfDbgNoStamina") == true then
            s.staminaStatus = "An existing no-drain flag is active. Rejoin first to reset it."; return
        end
        local api = {connections = optional("getconnections"), constants = optional("getconstants"),
            upvalues = optional("getupvalues"), set = optional("setupvalue"), env = optional("getfenv")}
        local missing = {}
        for _, item in ipairs({{"getconnections", api.connections}, {"getconstants", api.constants},
            {"getupvalues", api.upvalues}, {"setupvalue", api.set}, {"getfenv", api.env}}) do
            if type(item[2]) ~= "function" then missing[#missing + 1] = item[1] end
        end
        if #missing > 0 then s.staminaStatus = "Unavailable: " .. table.concat(missing, ", ") .. ". 3x stamina stays off."; return end
        s.stamina = true; s.moving = true; s.epoch = s.epoch + 1; s.movingApi = api
        local epoch = s.epoch
        s.staminaStatus = "Checking the already-loaded stamina config..."
        s.movingStatus = "Waiting for the combined 3x mode..."
        loadedConfig("stamina", function(config)
            if not s.alive or not s.stamina or s.epoch ~= epoch then return end
            local ok, lease, message = pcall(Core.restRate, config)
            if not ok then lease, message = nil, "Stamina config check failed." end
            if not lease then stopStamina(message); refresh(); return end
            s.lease = lease; s.movingConfig = config
            s.staminaStatus = "3x rate applied locally. Matching the native stamina pool..."
            local char = player.Character
            prepareMoving(char, char and char:FindFirstChildOfClass("Humanoid"), char and char:FindFirstChild("HumanoidRootPart"))
            refresh()
        end)
    end)
    action(stopButton, function()
        s.recovery = false; stopSignal(); stopStamina()
        s.recoveryStatus = "Recovery off."
    end)
    local minimized = false
    action(hide, function()
        minimized = not minimized; body.Visible = not minimized
        frame.Size = UDim2.fromOffset(460, minimized and 40 or 590); hide.Text = minimized and "+" or "-"
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
    cleanup = function()
        if not s.alive then return end
        s.recovery = false; stopSignal(); stopStamina(); s.alive = false
        for _, connection in ipairs(s.connections) do pcall(function() connection:Disconnect() end) end
        table.clear(s.connections)
        if gui.Parent then gui:Destroy() end
    end
    action(close, cleanup)
    connect(shutdown.Event, cleanup)
    connect(gui.Destroying, cleanup)
    connect(player.CharacterRemoving, function(char)
        if (s.signal and s.signal.char == char) or (s.mask and s.mask.char == char) then stopSignal() end
        if s.binding and s.binding.char == char then releaseMoving() end
    end)
    refresh = function()
        if not s.alive then return end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local function number(value) return Core.finite(value) and string.format("%.1f", value) or "?" end
        live.Text = (Core.animal(char and char:GetAttribute("Species")) or "Waiting for animal")
            .. " | HP " .. number(hum and hum.Health) .. " / " .. number(hum and hum.MaxHealth)
            .. "\nClient stamina " .. number(char and char:GetAttribute("Stamina")) .. " / " .. number(char and char:GetAttribute("StaminaMax"))
        recoveryButton.Text = "RECOVERY ASSIST: " .. (s.recovery and "ON" or "OFF")
        recoveryButton.BackgroundColor3 = s.recovery and C.green or C.blue
        local staminaReady = s.stamina and s.lease and s.binding and s.binding.index
        staminaButton.Text = "3X STAMINA REGEN: " .. (s.stamina and (staminaReady and "ON" or (s.lease and "BINDING" or "CHECKING")) or "OFF")
        staminaButton.BackgroundColor3 = staminaReady and C.green or C.blue
        recoveryStatus.Text, staminaStatus.Text = s.recoveryStatus, s.staminaStatus
        movingStatus.Text = s.movingStatus
        local camera = workspace.CurrentCamera
        if camera then scale.Scale = math.clamp(math.min(camera.ViewportSize.X / 500, camera.ViewportSize.Y / 630), .4, 1) end
    end
    local function tick()
        local now = os.clock()
        if now - s.lastTick < .1 then return end
        s.lastTick = now
        if s.lease and not Core.matches(s.lease) then stopStamina("Config changed externally; stamina assistance stopped.") end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if s.moving then
            if s.binding and (s.binding.char ~= char or s.binding.hum ~= hum) then releaseMoving() end
            if not s.binding and s.movingConfig and now - s.lastBind >= 2 then prepareMoving(char, hum, root) end
        end
        if s.signal and s.signal.char ~= char then stopSignal() end
        if s.recovery then
            local standby
            if not char or not char.Parent or not hum or not root or not Core.animal(char:GetAttribute("Species")) then standby = "Armed; waiting for your animal."
            elseif not Core.finite(hum.Health) or hum.Health <= 0 or char:GetAttribute("FeralDowned") == true then standby = "Armed; waiting until alive and standing."
            elseif player:GetAttribute("FeralMenuOpen") or player:GetAttribute("FeralTitleOpen") then standby = "Armed; waiting for the game menu to close."
            elseif not Core.needsRecovery(char, hum) then standby = "Armed; full HP and no active condition."
            elseif not s.signal and char:GetAttribute("WolfRest") == true then standby = "Stand up normally first; native rest remains yours." end
            if standby then
                stopSignal(); s.recoveryStatus = standby
            elseif now - s.lastRequest >= 5 then
                s.lastRequest = now
                if not s.mask and not beginMask(char) then
                    s.recovery = false; s.recoveryStatus = "Local pose mask unavailable. No recovery request sent."
                else
                    s.signal = s.signal or {char = char}
                    if not restPacket(char, true) then
                        s.recovery = false; stopSignal(); s.recoveryStatus = "Recovery request unavailable. Control stopped."
                    elseif s.recovery then
                        s.recoveryStatus = "Native Rest requested; local rest pose masked."
                    end
                end
            end
        end
        if now - s.lastUi >= .25 then s.lastUi = now; refresh() end
    end
    s.heartbeat = connect(RunService.Heartbeat, function()
        if s.alive then local ok = pcall(tick); if not ok then fail() end end
    end)
    refresh()
end
local ok = pcall(run)
if not ok then
    if abort then pcall(abort) end
    warn("[FERAL Recovery] Startup failed. Rerun after joining FERAL.")
end
