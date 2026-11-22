-- ARENA NOVA | Core-only hub | v1.3.0
-- Client-side UI, outline-only player ESP, names-only tags, weapon reach, passive disaster cues.
-- Focused on lightweight, opt-in client visuals; no gameplay-state modifications.
-- No gameplay remotes, diagnostics, perk actions, decompilation or file writes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

if not game:IsLoaded() then
    game.Loaded:Wait()
end
if game.GameId ~= 7209131331 then
    warn("[ARENA NOVA] Hub requires Arena of Survival (universe 7209131331).")
    return
end

local player = Players.LocalPlayer
if not player then
    warn("[ARENA NOVA] LocalPlayer unavailable.")
    return
end
local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then
    warn("[ARENA NOVA] PlayerGui unavailable.")
    return
end

local environment = _G
if type(getgenv) == "function" then
    local success, value = pcall(getgenv)
    if success and type(value) == "table" then
        environment = value
    end
end
local lastOptions = nil
for _, oldKey in {"__ARENA_NOVA_PHASE4", "__ARENA_NOVA_COMPANION"} do
    local oldInstance = environment[oldKey]
    if type(oldInstance) == "table" then
        if type(oldInstance.options) == "table" then
            lastOptions = oldInstance.options
        end
        if type(oldInstance.unload) == "function" then
            pcall(oldInstance.unload)
        end
    end
end
local incomingOptions = environment.__ARENA_NOVA_BOOT_CONFIG
environment.__ARENA_NOVA_BOOT_CONFIG = nil

local running = true
local VERSION = "1.3.0"
local settings = {
    outlines = true,
    names = true,
    reach = true,
    disasters = true,
}
for _, option in ipairs({ "outlines", "names", "reach", "disasters" }) do
    local fromTeleport = type(incomingOptions) == "table" and incomingOptions[option]
    local fromPrior = type(lastOptions) == "table" and lastOptions[option]
    if type(fromTeleport) == "boolean" then
        settings[option] = fromTeleport
    elseif type(fromPrior) == "boolean" then
        settings[option] = fromPrior
    end
end
local globals = {}
local function connect(signal, callback, owner)
    local connection = signal:Connect(callback)
    table.insert(owner or globals, connection)
    return connection
end
local function disconnectAll(collection)
    for _, item in ipairs(collection) do
        pcall(function()
            item:Disconnect()
        end)
    end
    table.clear(collection)
end
local function create(className, parent, attributes)
    local object = Instance.new(className)
    for property, value in pairs(attributes or {}) do
        object[property] = value
    end
    object.Parent = parent
    return object
end
local function makeCorner(gui, pixels)
    create("UICorner", gui, {CornerRadius = UDim.new(0, pixels)})
end
local function makeStroke(gui, color, transparency)
    create("UIStroke", gui, {
        Color = color,
        Transparency = transparency or 0,
        Thickness = 1,
    })
end

-- Replicated character tracking: never create a fake proxy for an unstreamed player.
local targets = {}
local nativeBillboards = {}
local outlineFolder = create("Folder", Workspace, {Name = "ArenaNovaOutlines"})
local suppressNativeNames = nil
local neutralOutline = Color3.fromRGB(170, 184, 201)
local function healthOutlineColor(record)
    if not record.stats then
        return neutralOutline
    end
    local hp = record.stats:GetAttribute("Health")
    local maxHp = record.stats:GetAttribute("MaxHealth")
    if type(hp) ~= "number" or type(maxHp) ~= "number" or maxHp <= 0 then
        return neutralOutline
    end
    local fraction = math.clamp(hp / maxHp, 0, 1)
    return Color3.fromHSV(fraction / 3, 0.89, 0.98)
end
local function removeHighlight(record)
    if record.highlight then
        record.highlight:Destroy()
        record.highlight = nil
    end
end
local function removeName(record)
    if record.tag then
        record.tag:Destroy()
        record.tag = nil
    end
    record.text = nil
end
local function paintOutline(record)
    if record.highlight then
        record.highlight.OutlineColor = healthOutlineColor(record)
    end
end
local function clearStats(record)
    disconnectAll(record.statConnections)
    record.stats = nil
end
local function resetCharacter(record)
    disconnectAll(record.characterConnections)
    clearStats(record)
    removeHighlight(record)
    removeName(record)
    record.character = nil
    record.head = nil
end
local function refreshPlayerVisuals(record)
    local character = record.character
    if not character or not character.Parent then
        removeHighlight(record)
        removeName(record)
        return
    end
    if settings.outlines then
        if not record.highlight then
            record.highlight = create("Highlight", outlineFolder, {
                Name = "ArenaNovaOutline",
                Adornee = character,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                FillTransparency = 1,
                OutlineTransparency = 0,
                FillColor = Color3.fromRGB(0, 0, 0),
                OutlineColor = neutralOutline,
                Enabled = true,
            })
        end
        paintOutline(record)
    else
        removeHighlight(record)
    end

    if settings.names and record.head and record.head.Parent == character then
        if not record.tag then
            local billboard = create("BillboardGui", playerGui, {
                Name = "ArenaNovaName",
                Adornee = record.head,
                Size = UDim2.fromOffset(148, 22),
                StudsOffsetWorldSpace = Vector3.new(0, 1.85, 0),
                AlwaysOnTop = true,
                MaxDistance = 0,
                LightInfluence = 0,
                ResetOnSpawn = false,
                Enabled = true,
            })
            local label = create("TextLabel", billboard, {
                Name = "Name",
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1),
                Text = record.player.DisplayName,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextScaled = false,
                TextColor3 = Color3.fromRGB(245, 248, 255),
                TextStrokeColor3 = Color3.fromRGB(6, 9, 18),
                TextStrokeTransparency = 0.5,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            record.tag = billboard
            record.text = label
        else
            record.tag.Adornee = record.head
        end
        if record.text then
            record.text.Text = record.player.DisplayName
        end
    else
        removeName(record)
    end
end
local function assignStats(record, stats)
    if record.stats == stats then
        return
    end
    clearStats(record)
    record.stats = stats
    if stats then
        connect(stats:GetAttributeChangedSignal("Health"), function()
            if running then
                paintOutline(record)
            end
        end, record.statConnections)
        connect(stats:GetAttributeChangedSignal("MaxHealth"), function()
            if running then
                paintOutline(record)
            end
        end, record.statConnections)
    end
    paintOutline(record)
end
local function updateCharacterParts(record)
    local character = record.character
    if not character then
        return
    end
    local head = character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        record.head = head
    else
        record.head = nil
    end
    local stats = character:FindFirstChild("CombatStats")
    assignStats(record, stats)
    refreshPlayerVisuals(record)
    if settings.names and suppressNativeNames then
        suppressNativeNames()
    end
end
local function bindCharacter(record, character)
    resetCharacter(record)
    if not running or not character then
        return
    end
    record.character = character
    connect(character.ChildAdded, function(child)
        if child.Name == "Head" or child.Name == "CombatStats" then
            updateCharacterParts(record)
        end
    end, record.characterConnections)
    connect(character.ChildRemoved, function(child)
        if child == record.head or child == record.stats then
            updateCharacterParts(record)
        end
    end, record.characterConnections)
    connect(character.AncestryChanged, function(_, parent)
        if record.character ~= character then
            return
        end
        if parent then
            updateCharacterParts(record)
        else
            -- A streamed model can temporarily leave Workspace and later return.
            removeHighlight(record)
            removeName(record)
        end
    end, record.characterConnections)
    updateCharacterParts(record)
end
local function removePlayer(target)
    local record = targets[target]
    if not record then
        return
    end
    resetCharacter(record)
    disconnectAll(record.connections)
    targets[target] = nil
end
local function trackPlayer(target)
    if target == player or targets[target] then
        return
    end
    local record = {
        player = target,
        character = nil,
        head = nil,
        stats = nil,
        tag = nil,
        text = nil,
        highlight = nil,
        connections = {},
        characterConnections = {},
        statConnections = {},
    }
    targets[target] = record
    connect(target.CharacterAdded, function(character)
        bindCharacter(record, character)
    end, record.connections)
    connect(target.CharacterRemoving, function(character)
        if record.character == character then
            resetCharacter(record)
        end
    end, record.connections)
    connect(target:GetPropertyChangedSignal("DisplayName"), function()
        if record.text then
            record.text.Text = target.DisplayName
        end
    end, record.connections)
    if target.Character then
        bindCharacter(record, target.Character)
    end
end
local function allPlayerVisuals()
    for _, record in pairs(targets) do
        refreshPlayerVisuals(record)
    end
end

-- The native match has its own PlayerBillboard with name and health.
-- Suppress only positively identified native billboards while names-only mode is on.
local function nativeForTrackedHead(gui)
    if not gui:IsA("BillboardGui") or gui.Name ~= "PlayerBillboard" then
        return false
    end
    if not gui:FindFirstChild("PlayerName", true)
        or not gui:FindFirstChild("HealthBar", true) then
        return false
    end
    for _, record in pairs(targets) do
        if record.head and gui.Adornee == record.head then
            return true
        end
    end
    return false
end
local function maybeSuppressNative(gui)
    if not running or not settings.names or nativeBillboards[gui] or not nativeForTrackedHead(gui) then
        return
    end
    local state = {original = gui.Enabled, signal = nil, removed = nil}
    nativeBillboards[gui] = state
    state.removed = gui.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if state.signal then
                state.signal:Disconnect()
            end
            if state.removed then
                state.removed:Disconnect()
            end
            nativeBillboards[gui] = nil
        end
    end)
    state.signal = gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if running and settings.names and gui.Parent and gui.Enabled then
            gui.Enabled = false
        end
    end)
    gui.Enabled = false
end
suppressNativeNames = function()
    if not settings.names then
        return
    end
    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("BillboardGui") then
            maybeSuppressNative(object)
        end
    end
end
local function restoreNativeNames()
    for gui, state in pairs(nativeBillboards) do
        if state.signal then
            pcall(function()
                state.signal:Disconnect()
            end)
        end
        if state.removed then
            pcall(function()
                state.removed:Disconnect()
            end)
        end
        if gui.Parent then
            pcall(function()
                gui.Enabled = state.original
            end)
        end
        nativeBillboards[gui] = nil
    end
end

-- Reach module: actual weapon definitions, visual assistance only.
local weaponsModule = nil
do
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local constants = shared and shared:FindFirstChild("constants")
    local moduleScript = constants and constants:FindFirstChild("Weapons")
    if moduleScript then
        local ok, loaded = pcall(require, moduleScript)
        if ok and type(loaded) == "table" then
            weaponsModule = loaded
        end
    end
end
local fallbackReach = {
    Knife = 6,
    Sword = 7, Katana = 7, Falchions = 7, Hammer = 7,
    Mace = 7, ["Stone-Headed Axe"] = 7, Flail = 7,
    Pickaxe = 7, Hatchet = 7, ["Battle Axe"] = 8.5,
    Trident = 8.5, Spear = 10, ["Stone-Tipped Spear"] = 10,
}
local function selectedReach()
    local character = player.Character
    if not character then
        return nil
    end
    local stats = character:FindFirstChild("CombatStats")
    if not stats then
        return nil
    end
    local health = stats:GetAttribute("Health")
    if type(health) == "number" and health <= 0 then
        return nil
    end
    local equipped = stats:GetAttribute("Equipped")
    if type(equipped) ~= "string" or equipped == "" then
        return 4.5
    end
    if weaponsModule and type(weaponsModule.get) == "function" then
        local ok, row = pcall(weaponsModule.get, equipped)
        if ok and type(row) == "table" then
            if type(row.reach) == "number" and row.reach > 0 then
                return row.reach
            end
            return nil
        end
    end
    return fallbackReach[equipped]
end
local reachModel = nil
local reachParts = {}
local reachConnection = nil
local RING_SEGMENTS = 32
local reachRayParams = RaycastParams.new()
reachRayParams.FilterType = Enum.RaycastFilterType.Exclude
reachRayParams.IgnoreWater = true

local function stopReach()
    if reachConnection then
        reachConnection:Disconnect()
        reachConnection = nil
    end
    if reachModel then
        reachModel:Destroy()
        reachModel = nil
    end
    table.clear(reachParts)
end

local function setReachVisible(visible)
    local transparency = visible and 0.40 or 1
    for _, part in ipairs(reachParts) do
        if part.Transparency ~= transparency then
            part.Transparency = transparency
        end
    end
end

-- Ring segment sizes change only when the equipped weapon's reach changes.
-- Moving the model pivot every frame is smoother than reconstructing geometry at 18 Hz.
local function layoutReach(radius)
    local angleStep = math.pi * 2 / RING_SEGMENTS
    local currentPivot = reachModel:GetPivot()
    local previous = Vector3.new(radius, 0, 0)
    for i = 1, RING_SEGMENTS do
        local angle = i * angleStep
        local nextPoint = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        local direction = nextPoint - previous
        local part = reachParts[i]
        part.Size = Vector3.new(direction.Magnitude + 0.012, 0.065, 0.065)
        part.CFrame = currentPivot
            * CFrame.lookAt((previous + nextPoint) * 0.5, nextPoint)
            * CFrame.Angles(0, math.pi / 2, 0)
        previous = nextPoint
    end
end

local function startReach()
    if reachConnection then
        return
    end
    reachModel = create("Model", Workspace, {Name = "ArenaNovaReach"})
    reachModel.WorldPivot = CFrame.new()
    for i = 1, RING_SEGMENTS do
        local part = create("Part", reachModel, {
            Name = "Arc" .. i,
            Anchored = true,
            CanCollide = false,
            CanTouch = false,
            CanQuery = false,
            CastShadow = false,
            Material = Enum.Material.Neon,
            Color = Color3.fromRGB(112, 212, 255),
            Transparency = 1,
            Size = Vector3.new(0.2, 0.065, 0.065),
        })
        table.insert(reachParts, part)
    end
    local rayElapsed = math.huge
    local reachReadElapsed = math.huge
    local cachedReach = nil
    local currentRadius = nil
    local groundY = nil
    local lastCharacter = nil
    local shown = false
    reachConnection = RunService.RenderStepped:Connect(function(dt)
        if not running or not settings.reach then
            return
        end
        if game.PlaceId == 72238253016204 then
            if shown then
                setReachVisible(false)
                shown = false
            end
            return
        end
        local character = player.Character
        if character ~= lastCharacter then
            lastCharacter = character
            rayElapsed = math.huge
            reachReadElapsed = math.huge
            groundY = nil
            currentRadius = nil
            cachedReach = nil
        end
        local root = character and character:FindFirstChild("HumanoidRootPart")
        reachReadElapsed += dt
        if reachReadElapsed >= 0.11 then
            reachReadElapsed = 0
            cachedReach = selectedReach()
        end
        local radius = cachedReach
        if not root or not root:IsA("BasePart") or not radius then
            if shown then
                setReachVisible(false)
                shown = false
            end
            return
        end
        if radius ~= currentRadius then
            layoutReach(radius)
            currentRadius = radius
        end
        if not shown then
            setReachVisible(true)
            shown = true
        end
        rayElapsed += dt
        if rayElapsed >= 0.11 or not groundY then
            rayElapsed = 0
            reachRayParams.FilterDescendantsInstances = {character, reachModel}
            local hit = Workspace:Raycast(root.Position, Vector3.new(0, -13, 0), reachRayParams)
            groundY = if hit then hit.Position.Y + 0.09 else root.Position.Y - 2.8
        end
        reachModel:PivotTo(CFrame.new(root.Position.X, groundY, root.Position.Z))
    end)
end

-- UI shell: all working modules have a single-click toggle.
local ui = create("ScreenGui", playerGui, {
    Name = "ArenaNovaPhase4",
    Enabled = true,
    DisplayOrder = 10000,
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local palette = {
    panel = Color3.fromRGB(18, 21, 30),
    surface = Color3.fromRGB(28, 33, 46),
    surfaceHover = Color3.fromRGB(35, 42, 56),
    border = Color3.fromRGB(60, 69, 88),
    white = Color3.fromRGB(237, 243, 251),
    muted = Color3.fromRGB(149, 163, 186),
    accent = Color3.fromRGB(88, 207, 177),
}
local main = create("Frame", ui, {
    Name = "Panel",
    Size = UDim2.fromOffset(354, 314),
    Position = UDim2.new(0.5, -177, 0.5, -157),
    BackgroundColor3 = palette.panel,
    BorderSizePixel = 0,
    Visible = true,
    Active = true,
})
makeCorner(main, 12)
makeStroke(main, palette.border, 0.45)
local header = create("Frame", main, {
    Name = "Header",
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 51),
    Active = true,
})
create("TextLabel", header, {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(16, 9),
    Size = UDim2.fromOffset(245, 23),
    Font = Enum.Font.GothamBold,
    Text = "ARENA NOVA",
    TextColor3 = palette.white,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
})
create("TextLabel", header, {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(17, 31),
    Size = UDim2.fromOffset(230, 14),
    Font = Enum.Font.Gotham,
    Text = "CORE EDITION   /   v" .. VERSION,
    TextColor3 = palette.muted,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
})
local hideButton = create("TextButton", header, {
    Name = "Hide",
    Text = "—",
    Position = UDim2.new(1, -44, 0, 12),
    Size = UDim2.fromOffset(30, 28),
    BackgroundColor3 = palette.surface,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    TextColor3 = palette.white,
    Font = Enum.Font.GothamBold,
    TextSize = 17,
    Active = true,
})
makeCorner(hideButton, 7)
-- Only one page: no tabs, no research menus, no experimental abilities.
local livePage = create("Frame", main, {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(14, 62),
    Size = UDim2.new(1, -28, 0, 215),
    Visible = true,
})
local toggleUI = {}
local definitions = {
    {key = "outlines", label = "PLAYER OUTLINES"},
    {key = "names", label = "PLAYER NAMETAGS"},
    {key = "reach", label = "WEAPON REACH"},
    {key = "disasters", label = "DISASTER ALERTS"},
}
for index, definition in ipairs(definitions) do
    local row = create("TextButton", livePage, {
        Name = definition.key,
        Position = UDim2.fromOffset(0, (index - 1) * 54),
        Size = UDim2.new(1, 0, 0, 47),
        BackgroundColor3 = palette.surface,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        Active = true,
    })
    makeCorner(row, 7)
    local name = create("TextLabel", row, {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(13, 0),
        Size = UDim2.new(1, -102, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = definition.label,
        TextColor3 = palette.white,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local status = create("TextLabel", row, {
        Name = "Status",
        Position = UDim2.new(1, -71, 0.5, -13),
        Size = UDim2.fromOffset(58, 26),
        BackgroundColor3 = palette.accent,
        BorderSizePixel = 0,
        TextColor3 = palette.panel,
        Text = "ON",
        TextSize = 11,
        Font = Enum.Font.GothamBold,
    })
    makeCorner(status, 6)
    toggleUI[definition.key] = {button = row, text = name, status = status}
end


-- Core-only build: no experimental combat/stamina/knockback hooks,
-- no perk manipulation, and no speculative resource or immunity controls.
local footer = create("Frame", main, {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(15, 285),
    Size = UDim2.new(1, -30, 0, 23),
})
create("TextLabel", footer, {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -187, 1, 0),
    Text = "RIGHT SHIFT",
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = palette.muted,
    TextXAlignment = Enum.TextXAlignment.Left,
})
local quietButton = create("TextButton", footer, {
    Name = "AllOff",
    Text = "ALL OFF",
    Position = UDim2.new(1, -157, 0, 0),
    Size = UDim2.fromOffset(74, 23),
    BackgroundColor3 = palette.surface,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = palette.white,
    AutoButtonColor = false,
})
makeCorner(quietButton, 6)
local unloadButton = create("TextButton", footer, {
    Text = "UNLOAD",
    Position = UDim2.new(1, -75, 0, 0),
    Size = UDim2.fromOffset(75, 23),
    BackgroundColor3 = palette.surface,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(238, 174, 163),
    AutoButtonColor = false,
})
makeCorner(unloadButton, 6)

-- A transient, silent cue; not a persistent on-screen disaster status panel.
local alertPill = create("Frame", ui, {
    Name = "HazardCue",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -16, 0.14, 0),
    Size = UDim2.fromOffset(206, 31),
    BackgroundColor3 = palette.panel,
    BorderSizePixel = 0,
    Visible = false,
})
makeCorner(alertPill, 8)
makeStroke(alertPill, Color3.fromRGB(233, 140, 91), 0.25)
local alertText = create("TextLabel", alertPill, {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(1, -20, 1, 0),
    Font = Enum.Font.GothamMedium,
    Text = "",
    TextColor3 = Color3.fromRGB(249, 202, 164),
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Center,
})
local alertSequence = 0
local lastCue = {}
local function showDisasterCue(id, title)
    if not running or not settings.disasters then
        return
    end
    local timeNow = os.clock()
    if lastCue[id] and timeNow - lastCue[id] < 40 then
        return
    end
    lastCue[id] = timeNow
    alertText.Text = title
    alertPill.Visible = true
    alertSequence = alertSequence + 1
    local sequence = alertSequence
    task.delay(3.4, function()
        if running and sequence == alertSequence and alertPill.Parent then
            alertPill.Visible = false
        end
    end)
end

local disasterConnections = {}
local disasterSubscriptions = {}
local disasterToken = 0
local observableDisasters = {
    "AcidRain", "Blizzard", "Drought", "Famine", "ForestFire",
    "Meteor", "Nuclear", "Tornado", "ToxicGas", "Thunderstorm",
    "Volcano", "TidalWave", "Sandstorm",
}
local function stopDisasters()
    disasterToken = disasterToken + 1
    disconnectAll(disasterConnections)
    for _, unsubscribe in ipairs(disasterSubscriptions) do
        if type(unsubscribe) == "function" then
            pcall(unsubscribe)
        end
    end
    table.clear(disasterSubscriptions)
    alertSequence = alertSequence + 1
    alertPill.Visible = false
end
local function startDisasters()
    if #disasterConnections > 0 then
        return
    end
    disasterToken = disasterToken + 1
    local token = disasterToken
    for _, disaster in ipairs(observableDisasters) do
        local attribute = disaster .. "Until"
        local function readDisasterFlag()
            local untilAt = Workspace:GetAttribute(attribute)
            if type(untilAt) ~= "number" then
                return
            end
            local ok, serverTime = pcall(function()
                return Workspace:GetServerTimeNow()
            end)
            if ok and untilAt > serverTime then
                local label = disaster:gsub("(%l)(%u)", "%1 %2")
                showDisasterCue(disaster, string.upper(label) .. " ACTIVE")
            end
        end
        connect(Workspace:GetAttributeChangedSignal(attribute), readDisasterFlag, disasterConnections)
        if Workspace:GetAttribute(attribute) ~= nil then
            readDisasterFlag()
        end
    end
    task.spawn(function()
        local scripts = player:FindFirstChild("PlayerScripts")
            or player:WaitForChild("PlayerScripts", 7)
        local common = scripts and (scripts:FindFirstChild("common") or scripts:WaitForChild("common", 5))
        local networkSource = common and (common:FindFirstChild("Network") or common:WaitForChild("Network", 5))
        if not running or not settings.disasters or disasterToken ~= token or not networkSource then
            return
        end
        local ok, network = pcall(require, networkSource)
        if not ok or type(network) ~= "table" then
            return
        end
        local eventRows = {
            {name = "MeteorSpawned", label = "METEOR ACTIVITY", id = "Meteor"},
            {name = "LightningStruck", label = "LIGHTNING ACTIVITY", id = "Lightning"},
        }
        for _, event in ipairs(eventRows) do
            local signal = network[event.name]
            if type(signal) == "table" and type(signal.On) == "function" then
                local valid, unsubscribe = pcall(signal.On, function(_)
                    showDisasterCue(event.id, event.label)
                end)
                if valid and type(unsubscribe) == "function" then
                    table.insert(disasterSubscriptions, unsubscribe)
                end
            end
        end
    end)
end

local function repaintToggle(key)
    local details = toggleUI[key]
    if not details then
        return
    end
    local active = settings[key]
    details.status.Text = active and "ON" or "OFF"
    details.status.BackgroundColor3 = active and palette.accent or palette.border
    details.status.TextColor3 = active and palette.panel or palette.white
    details.button.BackgroundColor3 = active and palette.surfaceHover or palette.surface
end
local function setOption(key, value)
    if not running or settings[key] == value then
        return
    end
    settings[key] = value
    if key == "outlines" then
        allPlayerVisuals()
    elseif key == "names" then
        if not value then
            restoreNativeNames()
        end
        allPlayerVisuals()
        if value then
            suppressNativeNames()
        end
    elseif key == "reach" then
        if value then
            startReach()
        else
            stopReach()
        end
    elseif key == "disasters" then
        if value then
            startDisasters()
        else
            stopDisasters()
        end
    end
    repaintToggle(key)
end
local storedToggles = nil
for _, definition in ipairs(definitions) do
    local key = definition.key
    connect(toggleUI[key].button.Activated, function()
        if storedToggles then
            storedToggles = nil
            quietButton.Text = "ALL OFF"
        end
        setOption(key, not settings[key])
    end)
    repaintToggle(key)
end
connect(quietButton.Activated, function()
    if storedToggles then
        for _, definition in ipairs(definitions) do
            setOption(definition.key, storedToggles[definition.key] == true)
        end
        storedToggles = nil
        quietButton.Text = "ALL OFF"
    else
        storedToggles = {}
        for _, definition in ipairs(definitions) do
            storedToggles[definition.key] = settings[definition.key]
            setOption(definition.key, false)
        end
        quietButton.Text = "RESTORE"
    end
end)
local function setMenuVisible(visible)
    if running then
        main.Visible = visible
    end
end
connect(hideButton.Activated, function()
    setMenuVisible(false)
end)
connect(UserInputService.InputBegan, function(input, processed)
    if not running or UserInputService:GetFocusedTextBox() then
        return
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        setMenuVisible(not main.Visible)
    end
end)

-- Header-only dragging, with a fixed number of connections.
local dragging = false
local dragFrom = nil
local dragPosition = nil
connect(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragFrom = input.Position
        dragPosition = main.Position
    end
end)
connect(UserInputService.InputChanged, function(input)
    if dragging and dragFrom and dragPosition
        and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragFrom
        main.Position = UDim2.new(
            dragPosition.X.Scale, dragPosition.X.Offset + delta.X,
            dragPosition.Y.Scale, dragPosition.Y.Offset + delta.Y
        )
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local function unload()
    if not running then
        return
    end
    running = false
    stopDisasters()
    stopReach()
    restoreNativeNames()
    if outlineFolder then
        outlineFolder:Destroy()
    end
    for target in pairs(targets) do
        removePlayer(target)
    end
    disconnectAll(globals)
    if ui then
        ui:Destroy()
    end
    if environment.__ARENA_NOVA_PHASE4
        and environment.__ARENA_NOVA_PHASE4.version == VERSION then
        environment.__ARENA_NOVA_PHASE4 = nil
    end
end
environment.__ARENA_NOVA_PHASE4 = {
    unload = unload,
    version = VERSION,
    set = setOption,
    options = settings,
}
connect(unloadButton.Activated, unload)

-- Potassium supports queue_on_teleport; retain the hub across lobby -> match
-- only when the executor exposes the queue function. Unload cancels future queuing.
local teleportQueue = nil
if type(queue_on_teleport) == "function" then
    teleportQueue = queue_on_teleport
elseif type(queueonteleport) == "function" then
    teleportQueue = queueonteleport
end
local didQueue = false
if type(teleportQueue) == "function" then
    connect(player.OnTeleport, function(state)
        if running and not didQueue and state == Enum.TeleportState.Started then
            local config = string.format(
                "{outlines=%s,names=%s,reach=%s,disasters=%s}",
                tostring(settings.outlines),
                tostring(settings.names),
                tostring(settings.reach),
                tostring(settings.disasters)
            )
            local loader = [[local env=_G;if type(getgenv)=="function" then local ok,x=pcall(getgenv);if ok and type(x)=="table" then env=x end end;env.__ARENA_NOVA_BOOT_CONFIG=]]
                .. config
                .. [[;loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/arena-nova.lua"))()]]
            local queued = pcall(teleportQueue, loader)
            didQueue = queued
        elseif state == Enum.TeleportState.Failed then
            didQueue = false
        end
    end)
end

connect(Players.PlayerAdded, trackPlayer)
connect(Players.PlayerRemoving, removePlayer)
connect(playerGui.DescendantAdded, function(object)
    if object:IsA("BillboardGui") and object.Name == "PlayerBillboard" then
        maybeSuppressNative(object)
        task.defer(function()
            if running and object.Parent then
                maybeSuppressNative(object)
            end
        end)
    end
end)
for _, target in ipairs(Players:GetPlayers()) do
    trackPlayer(target)
end
suppressNativeNames()
if settings.reach then
    startReach()
end
if settings.disasters then
    startDisasters()
end
print("[ARENA NOVA] Core-only v" .. VERSION .. " loaded. Right Shift opens/closes the hub.")
