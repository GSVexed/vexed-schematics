-- ARENA NOVA | Phase 5 refinement build | v1.2.1
-- Client-side UI, outline-only player ESP, names-only tags, weapon reach, passive disaster cues.
-- Experimental server-authoritative mechanics are intentionally not represented as working.
-- No diagnostic collection, remote firing, decompilation, bytecode export or file writes.

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
local VERSION = "1.2.1"
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
    Size = UDim2.fromOffset(354, 356),
    Position = UDim2.new(0.5, -177, 0.5, -178),
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
    Text = "PHASE 4   /   v" .. VERSION,
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
local tabs = create("Frame", main, {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(14, 62),
    Size = UDim2.new(1, -28, 0, 31),
})
local tabButtons = {}
for index, entry in ipairs({{"LIVE", "live"}, {"RESEARCH", "research"}}) do
    local button = create("TextButton", tabs, {
        Name = entry[2],
        Text = entry[1],
        Size = UDim2.fromOffset(index == 1 and 93 or 113, 30),
        Position = UDim2.fromOffset(index == 1 and 0 or 100, 0),
        BackgroundColor3 = palette.surface,
        BorderSizePixel = 0,
        TextSize = 11,
        TextColor3 = palette.muted,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        Active = true,
    })
    makeCorner(button, 6)
    tabButtons[entry[2]] = button
end
local livePage = create("Frame", main, {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(14, 104),
    Size = UDim2.new(1, -28, 0, 215),
    Visible = true,
})
local researchPage = create("ScrollingFrame", main, {
    Name = "Research",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(14, 104),
    Size = UDim2.new(1, -28, 0, 215),
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = palette.border,
    CanvasSize = UDim2.fromOffset(0, 616),
    Visible = false,
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


-- Experimental client mechanics. Each control is OPT-IN and deliberately labelled as a
-- trial; a local effect cannot prove server-side acceptance or anti-cheat compatibility.
-- Never send an extra attack: the reach trial modifies the game's existing SwingFired request.
local trialEnabled = {melee = false, stamina = false, knockback = false}
local trialConnections = {}
local swingBinding, originalSwingFire, wrappedSwingFire = nil, nil, nil
local TRIAL_REACH_OFFSET = 2.5
local TRIAL_KNOCK_MULT = 0.40

local function getClientNetwork()
    local scripts = player:FindFirstChild("PlayerScripts")
    local common = scripts and scripts:FindFirstChild("common")
    local source = common and common:FindFirstChild("Network")
    if not source or not source:IsA("ModuleScript") then
        return nil
    end
    local okay, module = pcall(require, source)
    if okay and type(module) == "table" then
        return module
    end
    return nil
end

local function disableMeleeTrial()
    trialEnabled.melee = false
    if swingBinding and swingBinding.Fire == wrappedSwingFire then
        pcall(function()
            swingBinding.Fire = originalSwingFire
        end)
    end
    swingBinding, originalSwingFire, wrappedSwingFire = nil, nil, nil
end

local function enableMeleeTrial()
    if trialEnabled.melee then
        return true
    end
    local network = getClientNetwork()
    local entry = network and network.SwingFired
    if type(entry) ~= "table" or type(entry.Fire) ~= "function" then
        return false
    end
    swingBinding = entry
    originalSwingFire = entry.Fire
    wrappedSwingFire = function(packet)
        if trialEnabled.melee and type(packet) == "table"
            and typeof(packet.origin) == "Vector3"
            and game.PlaceId ~= 72238253016204 then
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then
                local revised = table.clone(packet)
                revised.origin = packet.origin + root.CFrame.LookVector * TRIAL_REACH_OFFSET
                return originalSwingFire(revised)
            end
        end
        return originalSwingFire(packet)
    end
    local installed = pcall(function()
        entry.Fire = wrappedSwingFire
    end)
    if not installed then
        swingBinding, originalSwingFire, wrappedSwingFire = nil, nil, nil
        return false
    end
    trialEnabled.melee = true
    return true
end

local function stopStaminaTrial()
    trialEnabled.stamina = false
    if trialConnections.stamina then
        trialConnections.stamina:Disconnect()
        trialConnections.stamina = nil
    end
end

local function startStaminaTrial()
    if trialEnabled.stamina then
        return true
    end
    local elapsed = 0
    trialEnabled.stamina = true
    trialConnections.stamina = RunService.PostSimulation:Connect(function(dt)
        if not running or game.PlaceId == 72238253016204 then
            return
        end
        elapsed += dt
        if elapsed < 0.09 then
            return
        end
        elapsed = 0
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local stats = character and character:FindFirstChild("CombatStats")
        if not root or not root:IsA("BasePart") or not stats then
            return
        end
        local health = stats:GetAttribute("Health")
        if type(health) == "number" and health <= 0 then
            return
        end
        -- Entity.simOf() returns the local HumanoidRootPart, not a
        -- separate SimState child. This is local simulation state only.
        local now = time()
        root:SetAttribute("StaminaAnchor", 250)
        root:SetAttribute("StaminaAnchorAt", now)
        root:SetAttribute("StaminaRegenAt", now)
        root:SetAttribute("SprintExhausted", false)
        root:SetAttribute("BlockExhausted", false)
    end)
    return true
end

local function stopKnockbackTrial()
    trialEnabled.knockback = false
    if trialConnections.knockback then
        trialConnections.knockback:Disconnect()
        trialConnections.knockback = nil
    end
end

local function startKnockbackTrial()
    if trialEnabled.knockback then
        return true
    end
    trialEnabled.knockback = true
    trialConnections.knockback = RunService.PostSimulation:Connect(function(_)
        if not running or game.PlaceId == 72238253016204 then
            return
        end
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local stats = character and character:FindFirstChild("CombatStats")
        if not root or not root:IsA("BasePart") or not stats then
            return
        end
        local knockedAt = root:GetAttribute("KnockAt")
        local knockVelocity = stats:GetAttribute("KnockVelocity")
        if type(knockedAt) ~= "number" or typeof(knockVelocity) ~= "Vector3" then
            return
        end
        local age = time() - knockedAt
        if age < 0 or age > 0.55 or knockVelocity.Magnitude < 2 then
            return
        end
        -- Damp replicated knock movement only while a recent knock impulse exists.
        -- This cannot cancel a server-enforced stun/damage and may be corrected.
        local velocity = root.AssemblyLinearVelocity
        if velocity.Magnitude > 1 and velocity:Dot(knockVelocity) > 0 then
            root.AssemblyLinearVelocity = Vector3.new(
                velocity.X * TRIAL_KNOCK_MULT,
                velocity.Y,
                velocity.Z * TRIAL_KNOCK_MULT
            )
        end
    end)
    return true
end

local trialStart = {
    melee = enableMeleeTrial,
    stamina = startStaminaTrial,
    knockback = startKnockbackTrial,
}
local trialStop = {
    melee = disableMeleeTrial,
    stamina = stopStaminaTrial,
    knockback = stopKnockbackTrial,
}
local function setTrial(id, enabled)
    if not running or trialStart[id] == nil then
        return false
    end
    if not enabled then
        trialStop[id]()
        return true
    end
    local ok, success = pcall(trialStart[id])
    if not ok or success ~= true then
        trialStop[id]()
        return false
    end
    return true
end
local function stopAllTrials()
    for id, stop in pairs(trialStop) do
        stop()
    end
end

local researchRows = {
    {"EXTENDED MELEE", "UNVERIFIED"},
    {"INFINITE STAMINA", "UNVERIFIED"},
    {"GRADUAL HEALING", "ITEM / PERK"},
    {"INFINITE HUNGER", "UNVERIFIED"},
    {"INFINITE THIRST", "UNVERIFIED"},
    {"INFINITE OXYGEN", "UNVERIFIED"},
    {"STATUS IMMUNITY", "UNVERIFIED"},
    {"FALL IMMUNITY", "CATLIKE PERK"},
    {"DISASTER IMMUNITY", "UNVERIFIED"},
    {"KNOCKBACK / STUN", "UNVERIFIED"},
}
local trialRows = {
    ["EXTENDED MELEE"] = "melee",
    ["INFINITE STAMINA"] = "stamina",
    ["KNOCKBACK / STUN"] = "knockback",
}
local trialUi = {}
local researchIndicators = {}
for index, entry in ipairs(researchRows) do
    local trialId = trialRows[entry[1]]
    local rowProps = {
        Name = "Research_" .. index,
        BackgroundColor3 = palette.surface,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, (index - 1) * 36),
        Size = UDim2.new(1, -6, 0, 32),
    }
    if trialId then
        rowProps.Text = ""
        rowProps.AutoButtonColor = false
        rowProps.Active = true
    end
    local row = create(if trialId then "TextButton" else "Frame", researchPage, rowProps)
    makeCorner(row, 6)
    create("TextLabel", row, {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(11, 0),
        Size = UDim2.new(1, -136, 1, 0),
        Text = entry[1],
        Font = Enum.Font.GothamMedium,
        TextColor3 = palette.white,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local stateLabel = create("TextLabel", row, {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -129, 0, 0),
        Size = UDim2.fromOffset(119, 32),
        Text = if trialId then "TRY (LOCAL)" else entry[2],
        Font = Enum.Font.Gotham,
        TextColor3 = palette.muted,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    researchIndicators[entry[1]] = stateLabel
    if trialId then
        trialUi[trialId] = stateLabel
        connect(row.Activated, function()
            local request = not trialEnabled[trialId]
            local accepted = setTrial(trialId, request)
            if request and not accepted then
                stateLabel.Text = "UNAVAILABLE"
                stateLabel.TextColor3 = palette.muted
            else
                stateLabel.Text = if trialEnabled[trialId] then "LOCAL TRIAL" else "TRY (LOCAL)"
                stateLabel.TextColor3 = if trialEnabled[trialId]
                    then Color3.fromRGB(244, 180, 102) else palette.muted
            end
        end)
    end
end

local perkControls = {}
create("TextLabel", researchPage, {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(10, 365),
    Size = UDim2.new(1, -15, 0, 23),
    Text = "BUILT-IN PERKS  ·  SERVER VALIDATED",
    Font = Enum.Font.GothamBold,
    TextSize = 9,
    TextColor3 = palette.muted,
    TextXAlignment = Enum.TextXAlignment.Left,
})
local perkNames = {"Catlike", "Quick Recovery", "Iron Lungs", "Conserver", "Storm Rider"}
for index, perkName in ipairs(perkNames) do
    local button = create("TextButton", researchPage, {
        Name = "Perk_" .. index,
        BackgroundColor3 = palette.surface,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 393 + (index - 1) * 37),
        Size = UDim2.new(1, -6, 0, 32),
        Text = "",
        Active = true,
        AutoButtonColor = false,
    })
    makeCorner(button, 6)
    create("TextLabel", button, {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(11, 0),
        Size = UDim2.new(1, -132, 1, 0),
        Text = string.upper(perkName),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = palette.white,
    })
    local state = create("TextLabel", button, {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -129, 0, 0),
        Size = UDim2.fromOffset(119, 32),
        Text = "EQUIP",
        Font = Enum.Font.Gotham,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = palette.muted,
    })
    perkControls[perkName] = {button = button, label = state}
end
local lastPerkRequest = -math.huge
local function requestOwnedPerk(name)
    if os.clock() - lastPerkRequest < 0.8 then
        return false, "COOLDOWN"
    end
    local network = getClientNetwork()
    local action = network and network.PerkAction
    if type(action) ~= "table" or type(action.Fire) ~= "function" then
        return false, "UNAVAILABLE"
    end
    local first = player:GetAttribute("Perk1")
    local second = player:GetAttribute("Perk2")
    if first == name or second == name then
        return false, "EQUIPPED"
    end
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local constants = shared and shared:FindFirstChild("constants")
    local moduleScript = constants and constants:FindFirstChild("Perks")
    if moduleScript then
        local loaded, module = pcall(require, moduleScript)
        if loaded and type(module) == "table" then
            local row = module.rows and module.rows[name]
            if row and row.kind == "Progression" and type(module.unlockedIn) == "function" then
                local mask = player:GetAttribute("UnlockedMask")
                if type(mask) ~= "number" or not module.unlockedIn(mask, name) then
                    return false, "LOCKED"
                end
            end
        end
    end
    -- When both slots are filled, an explicit click replaces Slot 2.
    -- Pass ownership and final acceptance are verified by the actual game server.
    local slot = if type(first) ~= "string" or first == "" then 1
        else if type(second) ~= "string" or second == "" then 2 else 2
    local sent = pcall(function()
        action.Fire({action = "Equip", slot = slot, perk = name})
    end)
    if sent then
        lastPerkRequest = os.clock()
        return true, "REQUESTED"
    end
    return false, "UNAVAILABLE"
end

local function refreshEquippedPerks()
    local first = player:GetAttribute("Perk1")
    local second = player:GetAttribute("Perk2")
    local function ownsEquipped(name)
        return first == name or second == name
    end
    local fall = researchIndicators["FALL IMMUNITY"]
    local healing = researchIndicators["GRADUAL HEALING"]
    local oxygen = researchIndicators["INFINITE OXYGEN"]
    if fall then
        fall.Text = if ownsEquipped("Catlike") then "CATLIKE EQUIPPED" else "CATLIKE PERK"
        fall.TextColor3 = if ownsEquipped("Catlike") then palette.accent else palette.muted
    end
    if healing then
        healing.Text = if ownsEquipped("Quick Recovery") then "RECOVERY EQUIPPED" else "ITEM / PERK"
        healing.TextColor3 = if ownsEquipped("Quick Recovery") then palette.accent else palette.muted
    end
    if oxygen then
        oxygen.Text = if ownsEquipped("Iron Lungs") then "LUNGS EQUIPPED" else "UNVERIFIED"
        oxygen.TextColor3 = if ownsEquipped("Iron Lungs") then palette.accent else palette.muted
    end
    local disaster = researchIndicators["DISASTER IMMUNITY"]
    if disaster then
        disaster.Text = if ownsEquipped("Storm Rider") then "LIGHTNING AVOIDED" else "UNVERIFIED"
        disaster.TextColor3 = if ownsEquipped("Storm Rider") then palette.accent else palette.muted
    end
    for name, control in pairs(perkControls) do
        if ownsEquipped(name) then
            control.label.Text = "EQUIPPED"
            control.label.TextColor3 = palette.accent
        elseif type(first) == "string" and first ~= ""
            and type(second) == "string" and second ~= "" then
            control.label.Text = "REPLACE 2"
            control.label.TextColor3 = palette.muted
        else
            control.label.Text = "EQUIP"
            control.label.TextColor3 = palette.muted
        end
    end
end
for name, control in pairs(perkControls) do
    connect(control.button.Activated, function()
        local accepted, message = requestOwnedPerk(name)
        control.label.Text = message
        control.label.TextColor3 = if accepted then Color3.fromRGB(244, 180, 102)
            else palette.muted
        task.delay(1.4, function()
            if running then
                refreshEquippedPerks()
            end
        end)
    end)
end
connect(player:GetAttributeChangedSignal("Perk1"), refreshEquippedPerks)
connect(player:GetAttributeChangedSignal("Perk2"), refreshEquippedPerks)
refreshEquippedPerks()
local footer = create("Frame", main, {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(15, 326),
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
        stopAllTrials()
        for id, label in pairs(trialUi) do
            label.Text = "TRY (LOCAL)"
            label.TextColor3 = palette.muted
        end
        quietButton.Text = "RESTORE"
    end
end)
local selectedTab = "live"
local function openTab(tab)
    selectedTab = tab
    livePage.Visible = tab == "live"
    researchPage.Visible = tab == "research"
    for id, button in pairs(tabButtons) do
        local selected = id == tab
        button.BackgroundColor3 = selected and palette.surfaceHover or palette.surface
        button.TextColor3 = selected and palette.white or palette.muted
    end
end
for key, button in pairs(tabButtons) do
    connect(button.Activated, function()
        openTab(key)
    end)
end
openTab("live")
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
    stopAllTrials()
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
    trials = trialEnabled,
    setTrial = setTrial,
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
print("[ARENA NOVA] Phase 4 integrated v" .. VERSION .. " loaded. Right Shift opens/closes the hub.")
