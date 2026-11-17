-- FERAL Recovery Hub v1.0 | PlaceId 108901361810209
-- Native recovery signal and optional rest-rate client stamina recovery.
-- Rest-rate tuning retains drain, costs, delays, low-needs penalties and Burst.
-- No source collection, file exports, HP writes or no-drain debug flag.
-- Observed recovery: about 2x HP outside combat, faster bleed/venom clearance.
-- Combat HP regen and reliable unlimited Burst remain unresolved.

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
    local base, multiplier = config.STAMINA_REGEN, config.STAMINA_REST_MULT
    if not Core.finite(base) or base <= 0 or not Core.finite(multiplier) or multiplier <= 1
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
-- END TESTABLE CORE

local abort
local function run()
    if game.PlaceId ~= 108901361810209 then warn("[FERAL Recovery] Open FERAL first."); return end
    local Players, RS = game:GetService("Players"), game:GetService("ReplicatedStorage")
    local RunService, UIS = game:GetService("RunService"), game:GetService("UserInputService")
    local player = Players.LocalPlayer
    local parent = player and (player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 8))
    if not parent then warn("[FERAL Recovery] PlayerGui unavailable; rerun after joining."); return end
    for _, name in ipairs({"FeralFieldHubV10", "FeralFieldHubV11", "FeralFieldHubV12", "FeralFieldHubV13", "FeralFieldHubV14", "FeralHealthRecoveryV10", "FeralHealthRecoveryV11", "FeralHealthRecoveryV12", "FeralHealthRecoveryV13", "FeralRecoveryHubV10"}) do
        local old = parent:FindFirstChild(name)
        if old then
            local shutdown = old:FindFirstChild("HubShutdown")
            if shutdown and shutdown:IsA("BindableEvent") then shutdown:Fire() end
            if old.Parent then old:Destroy() end
        end
    end
    local s = {alive = true, recovery = false, stamina = false, epoch = 0, connections = {},
        lastRequest = -math.huge, lastTick = -math.huge, lastUi = -math.huge,
        recoveryStatus = "Recovery off.", staminaStatus = "Rest-rate stamina off."}
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
    local gui = new("ScreenGui", {Name = "FeralRecoveryHubV10", ResetOnSpawn = false, DisplayOrder = 85}, parent)
    local cleanup, refresh, stopSignal, stopStamina
    abort = function() if cleanup then cleanup() elseif gui.Parent then gui:Destroy() end end
    local shutdown = new("BindableEvent", {Name = "HubShutdown"}, gui)
    local frame = new("Frame", {Name = "RecoveryPanel", BackgroundColor3 = C.bg, BorderSizePixel = 0,
        Size = UDim2.fromOffset(460, 470), Position = UDim2.new(0, 22, .5, -235)}, gui)
    new("UICorner", {CornerRadius = UDim.new(0, 10)}, frame)
    local scale = new("UIScale", {Scale = 1}, frame)
    local title = new("TextLabel", {Text = "FERAL / RECOVERY HUB v1.0", Active = true, Font = Enum.Font.Gotham,
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
    local staminaButton = button("REST-RATE STAMINA: OFF")
    label("Uses the configured rest recovery rate (currently 3x) where stamina already regenerates. Normal drain, costs, delay and Burst controls remain. Stamina still runs down during Burst.", 60)
    local staminaStatus = label(s.staminaStatus, 42)
    local stopButton = button("TURN EVERYTHING OFF", C.red)
    label("Both controls start off and stay armed across respawns. Drag the title; - minimizes; X restores owned changes and closes. This menu collects no reports.", 44)
    local renderName = "FeralRecoveryPose_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
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
        s.stamina = false; s.epoch = s.epoch + 1; s.cacheCallback = nil
        local errors = Core.restore(s.lease); s.lease = nil
        s.staminaStatus = errors > 0 and "Config restoration failed; rejoin to reset."
            or message or "Rest-rate stamina off; owned settings restored."
    end
    local function loadedConfig(callback)
        s.cacheCallback = callback
        if s.cacheBusy then return end
        s.cacheBusy = true
        task.delay(6, function()
            if s.alive and s.cacheBusy and s.stamina then
                s.staminaStatus = "Loaded-cache check is waiting. Toggle off to cancel; no duplicate job runs."
            end
        end)
        task.spawn(function()
            if not s.alive then s.cacheBusy = false; s.cacheCallback = nil; return end
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
            local latest = s.cacheCallback; s.cacheCallback = nil
            if not s.alive or not latest then return end
            local current = RS:FindFirstChild("FeralWorld")
            if not ok or type(config) ~= "table" or not current or current:FindFirstChild("NeedsConfig") ~= target then config = nil end
            latest(config)
        end)
    end
    local function fail()
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
        s.stamina = true; s.epoch = s.epoch + 1
        local epoch = s.epoch
        s.staminaStatus = "Checking the already-loaded stamina config..."
        loadedConfig(function(config)
            if not s.alive or not s.stamina or s.epoch ~= epoch then return end
            local ok, lease, message = pcall(Core.restRate, config)
            if not ok then lease, message = nil, "Stamina config check failed." end
            if not lease then stopStamina(message); refresh(); return end
            s.lease = lease
            s.staminaStatus = string.format("%.2fx base stamina recovery applied locally. Burst still consumes stamina.", lease.multiplier)
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
        frame.Size = UDim2.fromOffset(460, minimized and 40 or 470); hide.Text = minimized and "+" or "-"
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
        staminaButton.Text = "REST-RATE STAMINA: " .. (s.stamina and (s.lease and "ON" or "CHECKING") or "OFF")
        staminaButton.BackgroundColor3 = s.lease and C.green or C.blue
        recoveryStatus.Text, staminaStatus.Text = s.recoveryStatus, s.staminaStatus
        local camera = workspace.CurrentCamera
        if camera then scale.Scale = math.clamp(math.min(camera.ViewportSize.X / 500, camera.ViewportSize.Y / 500), .4, 1) end
    end
    local function tick()
        local now = os.clock()
        if now - s.lastTick < .1 then return end
        s.lastTick = now
        if s.lease and not Core.matches(s.lease) then stopStamina("Config changed externally; stamina assistance stopped.") end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
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
