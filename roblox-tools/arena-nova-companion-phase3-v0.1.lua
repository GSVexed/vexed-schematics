-- ARENA NOVA Companion | Phase 3 preview 0.1.0
-- Client-side read-only survival, round and recipe display.
-- Does not fire remotes, alter game state, hook functions or save/upload data.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

if game.GameId ~= 7209131331 then
    warn("[ARENA NOVA] This companion is for Arena of Survival only.")
    return
end

local globalEnvironment = _G
if type(getgenv) == "function" then
    local ok, result = pcall(getgenv)
    if ok and type(result) == "table" then
        globalEnvironment = result
    end
end
if type(globalEnvironment.__ARENA_NOVA_COMPANION) == "table"
    and type(globalEnvironment.__ARENA_NOVA_COMPANION.unload) == "function" then
    pcall(globalEnvironment.__ARENA_NOVA_COMPANION.unload)
end

local running = true
local connections = {}
local function track(signalConnection)
    table.insert(connections, signalConnection)
    return signalConnection
end
local function new(className, parent, properties)
    local obj = Instance.new(className)
    for key, value in pairs(properties) do
        obj[key] = value
    end
    obj.Parent = parent
    return obj
end

local guiParent
if type(gethui) == "function" then
    local ok, parent = pcall(gethui)
    if ok and typeof(parent) == "Instance" then
        guiParent = parent
    end
end
if not guiParent then
    guiParent = player:FindFirstChildOfClass("PlayerGui")
        or player:WaitForChild("PlayerGui", 8)
end
if not guiParent then
    warn("[ARENA NOVA] No GUI parent is available.")
    return
end
local gui = new("ScreenGui", guiParent, {
    Name = "ArenaNOVA_Phase3",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 110,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local bg = Color3.fromRGB(16, 21, 30)
local surface = Color3.fromRGB(25, 33, 45)
local muted = Color3.fromRGB(146, 161, 181)
local textColor = Color3.fromRGB(238, 243, 250)
local accent = Color3.fromRGB(62, 190, 210)
local alert = Color3.fromRGB(244, 177, 81)
local panel = new("Frame", gui, {
    Name = "Main",
    Size = UDim2.fromOffset(362, 348),
    Position = UDim2.new(1, -376, 0.48, -162),
    BackgroundColor3 = bg,
    BorderSizePixel = 0,
    Active = true,
})
new("UICorner", panel, {CornerRadius = UDim.new(0, 12)})
new("UIStroke", panel, {Color = Color3.fromRGB(66, 85, 108), Thickness = 1})
local titleBar = new("Frame", panel, {
    Name = "Header",
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundTransparency = 1,
    Active = true,
})
local title = new("TextLabel", titleBar, {
    Position = UDim2.fromOffset(15, 8),
    Size = UDim2.new(1, -100, 0, 19),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "ARENA NOVA",
    TextColor3 = textColor,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
})
new("TextLabel", titleBar, {
    Position = UDim2.fromOffset(15, 28),
    Size = UDim2.new(1, -100, 0, 15),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "PHASE 3  /  READ-ONLY COMPANION",
    TextColor3 = muted,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
})
local function button(parent, label, x, width)
    local b = new("TextButton", parent, {
        Position = UDim2.new(1, x, 0, 9),
        Size = UDim2.fromOffset(width, 28),
        Text = label,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = textColor,
        BackgroundColor3 = surface,
        BorderSizePixel = 0,
        AutoButtonColor = true,
    })
    new("UICorner", b, {CornerRadius = UDim.new(0, 6)})
    return b
end
local collapseButton = button(titleBar, "-", -78, 28)
local exitButton = button(titleBar, "X", -44, 28)
new("Frame", panel, {
    Position = UDim2.fromOffset(13, 49),
    Size = UDim2.new(1, -26, 0, 1),
    BorderSizePixel = 0,
    BackgroundColor3 = Color3.fromRGB(52, 68, 87),
})
local tabHolder = new("Frame", panel, {
    Position = UDim2.fromOffset(12, 58),
    Size = UDim2.new(1, -24, 0, 32),
    BackgroundTransparency = 1,
})
local pages = new("Frame", panel, {
    Position = UDim2.fromOffset(12, 99),
    Size = UDim2.new(1, -24, 1, -140),
    BackgroundTransparency = 1,
})
local footer = new("TextLabel", panel, {
    Position = UDim2.new(0, 15, 1, -35),
    Size = UDim2.new(1, -30, 0, 22),
    BackgroundTransparency = 1,
    Text = "F7: show / hide     |     No remotes or game modifications",
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = muted,
    TextXAlignment = Enum.TextXAlignment.Left,
})
local pageByName = {}
local tabByName = {}
local selectedPage = "Overview"
local function makePage(name, number)
    local tab = new("TextButton", tabHolder, {
        Position = UDim2.new((number - 1) / 4, 0, 0, 0),
        Size = UDim2.new(0.25, -4, 1, 0),
        Text = name,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = muted,
        BackgroundColor3 = surface,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    new("UICorner", tab, {CornerRadius = UDim.new(0, 6)})
    local page = new("Frame", pages, {
        Name = name,
        Visible = name == selectedPage,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    })
    pageByName[name] = page
    tabByName[name] = tab
    track(tab.MouseButton1Click:Connect(function()
        selectedPage = name
        for pageName, frame in pairs(pageByName) do
            frame.Visible = pageName == name
            tabByName[pageName].TextColor3 = pageName == name and textColor or muted
            tabByName[pageName].BackgroundColor3 = pageName == name
                and Color3.fromRGB(38, 94, 111) or surface
        end
    end))
    return page
end
local overview = makePage("Overview", 1)
local statusPage = makePage("Effects", 2)
local craftPage = makePage("Recipes", 3)
local infoPage = makePage("Info", 4)
tabByName.Overview.TextColor3 = textColor
tabByName.Overview.BackgroundColor3 = Color3.fromRGB(38, 94, 111)

local function label(parent, y, content, size, color)
    return new("TextLabel", parent, {
        Position = UDim2.fromOffset(7, y),
        Size = UDim2.new(1, -14, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = size or 12,
        TextColor3 = color or textColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = content,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
end
local phaseLabel = label(overview, 0, "Round: ...", 12, accent)
local healthLabel = label(overview, 28, "Health: ...", 12, textColor)
local function bar(parent, y, color)
    local rail = new("Frame", parent, {
        Position = UDim2.fromOffset(7, y),
        Size = UDim2.new(1, -14, 0, 5),
        BackgroundColor3 = surface,
        BorderSizePixel = 0,
    })
    new("UICorner", rail, {CornerRadius = UDim.new(0, 3)})
    local fill = new("Frame", rail, {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
    })
    new("UICorner", fill, {CornerRadius = UDim.new(0, 3)})
    return fill
end
local healthBar = bar(overview, 50, Color3.fromRGB(103, 215, 150))
local staminaLabel = label(overview, 61, "Stamina: ...", 12)
local staminaBar = bar(overview, 83, accent)
local hungerLabel = label(overview, 95, "Hunger: --")
local thirstLabel = label(overview, 116, "Thirst: --")
local oxygenLabel = label(overview, 137, "Oxygen: --")
local weaponLabel = label(overview, 158, "Equipped: --")
local barrierLabel = label(overview, 179, "Barrier: --", 11, alert)

local effectsHeading = label(statusPage, 3, "REPLICATED STATUS EFFECTS", 12, accent)
local effectsLabel = new("TextLabel", statusPage, {
    Position = UDim2.fromOffset(7, 32),
    Size = UDim2.new(1, -14, 0, 140),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium,
    TextSize = 12,
    TextWrapped = true,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = textColor,
    Text = "No status data yet.",
})
local environmentLabel = label(statusPage, 169, "Environment: --", 11, alert)

local recipeRows = {
    {"Stone-Headed Axe", "2 Stone + 1 Firewood"},
    {"Stone-Tipped Spear", "1 Stone + 2 Firewood"},
    {"Wooden Bow", "2 Firewood + 2 Herb"},
    {"Wooden Blow Gun", "1 Firewood"},
    {"Wooden Arrows (x5)", "1 Firewood + 1 Stone"},
    {"Bone Darts (x10)", "1 Bone"},
    {"Bandage", "3 Herb"},
    {"Wooden Torch", "1 Firewood"},
    {"Poison Bottle", "1 Bottle + 4 Darkberry"},
}
local recipeList = new("ScrollingFrame", craftPage, {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.fromOffset(0, #recipeRows * 43),
})
for i, pair in ipairs(recipeRows) do
    local line = new("Frame", recipeList, {
        Position = UDim2.fromOffset(4, (i - 1) * 43),
        Size = UDim2.new(1, -15, 0, 38),
        BackgroundColor3 = surface,
        BorderSizePixel = 0,
    })
    new("UICorner", line, {CornerRadius = UDim.new(0, 5)})
    local nameLabel = label(line, 1, pair[1], 12, textColor)
    nameLabel.Size = UDim2.new(1, -10, 0, 18)
    local materialsLabel = label(line, 19, pair[2], 10, muted)
    materialsLabel.Size = UDim2.new(1, -10, 0, 16)
end

local info = new("TextLabel", infoPage, {
    Position = UDim2.fromOffset(7, 4),
    Size = UDim2.new(1, -14, 1, -8),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextWrapped = true,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = muted,
    Text = "Arena NOVA Companion v0.1\n\n"
        .. "This is a lightweight preview based on inspected client modules. "
        .. "Stamina is an estimate from replicated attributes, not a server-confirmed total. "
        .. "Hunger, thirst and oxygen are the latest replicated values.\n\n"
        .. "Recipes are reference information; this tool never crafts items.\n\n"
        .. "No server requests, input automation, hooks, character changes, ESP or uploads.",
})

local effectNames = {"Wet", "Burning", "Poisoned", "Crippled", "Bleeding",
    "Starving", "Thirsty", "Cold", "Infected"}
local effectWidths = {1, 1, 1, 1, 2, 2, 2, 2, 2}
local function statusStages(encoded)
    local values = {}
    if typeof(encoded) ~= "number" then
        return values
    end
    local shift = 0
    for i, key in ipairs(effectNames) do
        local stage = bit32.extract(math.floor(encoded), shift, effectWidths[i])
        values[key] = stage
        shift += effectWidths[i]
    end
    return values
end
local function hasPerk(perks, name)
    if typeof(perks) ~= "string" then
        return false
    end
    for token in string.gmatch(perks, "[^,]+") do
        if string.gsub(token, "^%s*(.-)%s*$", "%1") == name then
            return true
        end
    end
    return false
end
local function predictedStamina(root, stats, effects, serverNow)
    if not root then
        return nil, nil
    end
    local anchor = root:GetAttribute("StaminaAnchor")
    if typeof(anchor) ~= "number" then
        return nil, nil
    end
    local perks = stats and stats:GetAttribute("Perks")
    local maximum = hasPerk(perks, "Conserver") and 225 or 250
    local regen = hasPerk(perks, "Iron Lungs") and 30 or 20
    if (effects.Infected or 0) > 0 then
        maximum *= 0.85
    end
    if (effects.Thirsty or 0) == 1 then
        regen *= 0.75
    elseif (effects.Thirsty or 0) >= 2 then
        regen *= 0.5
    end
    local anchorAt = root:GetAttribute("StaminaAnchorAt")
    local from = typeof(anchorAt) == "number" and anchorAt or serverNow
    local consume
    if root:GetAttribute("Sprinting") == true then
        consume = 15 * (hasPerk(perks, "Conserver") and 0.7 or 1)
    elseif root:GetAttribute("Blocking") == true then
        consume = 10
    else
        consume = 0
    end
    if consume > 0 then
        return math.clamp(anchor - consume * math.max(0, serverNow - from), 0, maximum), maximum
    end
    local regenAt = root:GetAttribute("StaminaRegenAt")
    local start = typeof(regenAt) == "number" and math.max(from, regenAt) or from
    return math.clamp(anchor + regen * math.max(0, serverNow - start), 0, maximum), maximum
end
local function attrNumber(instance, name)
    if not instance then
        return nil
    end
    local v = instance:GetAttribute(name)
    return typeof(v) == "number" and v or nil
end
local function meterText(name, stats)
    local v = attrNumber(stats, name)
    return name .. ": " .. (v and string.format("%.0f / 100 (snapshot)", v) or "--")
end
local function fill(barFrame, numerator, denominator)
    local proportion = 0
    if typeof(numerator) == "number" and typeof(denominator) == "number"
        and denominator > 0 then
        proportion = math.clamp(numerator / denominator, 0, 1)
    end
    barFrame.Size = UDim2.fromScale(proportion, 1)
end
local function refresh()
    local char = player.Character
    local stats = char and char:FindFirstChild("CombatStats")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local now = workspace:GetServerTimeNow()
    local effects = statusStages(attrNumber(stats, "Status"))
    local phase = workspace:GetAttribute("Phase")
    if typeof(phase) == "string" then
        local entered = workspace:GetAttribute("PhaseAt")
        local elapsed = typeof(entered) == "number" and math.max(0, now - entered) or nil
        phaseLabel.Text = "Round: " .. phase .. (elapsed
            and string.format("  |  %02d:%02d in phase", math.floor(elapsed / 60),
                math.floor(elapsed % 60)) or "")
    else
        phaseLabel.Text = "Round: waiting for match state"
    end
    local health = attrNumber(stats, "Health")
    local maxHealth = attrNumber(stats, "MaxHealth")
    if health == nil and humanoid then
        health = humanoid.Health
        maxHealth = humanoid.MaxHealth
    end
    healthLabel.Text = health and string.format("Health: %.0f / %.0f", health, maxHealth or 100)
        or "Health: unavailable"
    fill(healthBar, health, maxHealth or 100)
    local stamina, maxStamina = predictedStamina(root, stats, effects, now)
    staminaLabel.Text = stamina and string.format("Stamina: ~%.0f / %.0f (estimate)", stamina, maxStamina)
        or "Stamina: no anchor data"
    fill(staminaBar, stamina, maxStamina)
    hungerLabel.Text = meterText("Hunger", stats)
    thirstLabel.Text = meterText("Thirst", stats)
    oxygenLabel.Text = meterText("Oxygen", stats)
    local equipped = stats and stats:GetAttribute("Equipped")
    weaponLabel.Text = "Equipped: " .. ((typeof(equipped) == "string" and equipped ~= "")
        and equipped or "Fists / unavailable")
    local stage = workspace:GetAttribute("BarrierStage")
    local untilAt = workspace:GetAttribute("BarrierUntil")
    if typeof(stage) == "number" then
        barrierLabel.Text = "Barrier stage: " .. tostring(stage)
        if typeof(untilAt) == "number" and untilAt > now then
            barrierLabel.Text ..= string.format("  |  %ds left in transition",
                math.ceil(untilAt - now))
        end
    else
        barrierLabel.Text = "Barrier: no replicated stage"
    end
    if stats then
        local active = {}
        for _, name in ipairs(effectNames) do
            local level = effects[name] or 0
            if level > 0 then
                table.insert(active, name .. (level > 1 and (" (" .. level .. ")") or ""))
            end
        end
        effectsLabel.Text = #active > 0 and table.concat(active, "\n")
            or "None reported by the replicated status field."
    else
        effectsLabel.Text = "No character status data is currently available."
    end
    local hazards = {}
    for _, key in ipairs({"Raining", "Famine", "Drought"}) do
        if workspace:GetAttribute(key) == true then
            table.insert(hazards, key)
        end
    end
    environmentLabel.Text = "Environment flags: "
        .. (#hazards > 0 and table.concat(hazards, ", ") or "none reported")
end

local function unload()
    if not running then
        return
    end
    running = false
    for _, connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    gui:Destroy()
    globalEnvironment.__ARENA_NOVA_COMPANION = nil
end
globalEnvironment.__ARENA_NOVA_COMPANION = {unload = unload, version = "0.1.0"}
track(exitButton.MouseButton1Click:Connect(unload))
local collapsed = false
track(collapseButton.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    tabHolder.Visible = not collapsed
    pages.Visible = not collapsed
    footer.Visible = not collapsed
    panel.Size = collapsed and UDim2.fromOffset(362, 49) or UDim2.fromOffset(362, 348)
    collapseButton.Text = collapsed and "+" or "-"
end))
track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() ~= nil then
        return
    end
    if input.KeyCode == Enum.KeyCode.F7 then
        gui.Enabled = not gui.Enabled
    end
end))
local dragging = false
local dragInput
local dragFrom
local panelFrom
track(titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragFrom = input.Position
        panelFrom = panel.Position
        track(input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end))
    end
end))
track(titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end))
track(UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragFrom
        panel.Position = UDim2.new(panelFrom.X.Scale, panelFrom.X.Offset + delta.X,
            panelFrom.Y.Scale, panelFrom.Y.Offset + delta.Y)
    end
end))
task.spawn(function()
    while running do
        if gui.Enabled then
            local ok, err = pcall(refresh)
            if not ok then
                footer.Text = "Local display error: " .. tostring(err):sub(1, 64)
            end
        end
        task.wait(0.25)
    end
end)
print("[ARENA NOVA] Read-only companion 0.1.0 loaded. F7 toggles UI.")
