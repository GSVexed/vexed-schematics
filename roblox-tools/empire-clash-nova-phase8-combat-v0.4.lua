-- EMPIRE CLASH NOVA | Phase 8 Combat Foundation v0.2.0
-- Original, locally rendered targeting / aim-intent / ESP implementation.
-- IMPORTANT: Optional shot-direction correction is experimental and UNVERIFIED.
-- Native firearm requests may be rejected by server or detected by moderators.
-- No extra shots, fabricated damage, integrity-check bypass or ban guarantee.
-- Research basis: private 2026-11-23 Runespire client shooting audit.

local VERSION = "0.4.0"
local UNIVERSE = 3569141441
if game.GameId ~= UNIVERSE then
    warn("[EC NOVA] This launcher only runs inside Empire Clash.")
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local localPlayer = Players.LocalPlayer
if not localPlayer then return end
local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
if not playerGui then
    warn("[EC NOVA] PlayerGui was not available.")
    return
end
local global = _G
if type(getgenv) == "function" then
    local ok, result = pcall(getgenv)
    if ok and type(result) == "table" then global = result end
end
if type(global.ECNovaCombat) == "table" and type(global.ECNovaCombat.Shutdown) == "function" then
    pcall(global.ECNovaCombat.Shutdown)
end

local SAVE_PATH = "EC_NOVA_COMBAT_SETTINGS.json"
local SOURCE_URL = "https://raw.githubusercontent.com/GSVexed/vexed-schematics/project-empire-clash-nova/roblox-tools/empire-clash-nova-phase8-combat-v0.4.lua"
local config = {
    AimRegion = "Adaptive",
    FOV = 160, MaxRange = 550,
    TeamFilter = true, RequireVisible = true,
    Prediction = false, PredictionMs = 70,
    Outline = true, Nametag = true, ThroughWalls = false,
    TargetCard = true, AimMarker = true,
    FOVRing = true, FirePoint = true,
    AutoQueue = true,
    ExperimentalSilentAim = false,
    MaxAngularCorrection = 12
}
local function clampConfig()
    if config.AimRegion ~= "Head" and config.AimRegion ~= "Torso" and config.AimRegion ~= "Adaptive" then
        config.AimRegion = "Adaptive"
    end
    config.FOV = math.clamp(math.floor(config.FOV), 60, 460)
    config.MaxRange = math.clamp(math.floor(config.MaxRange), 120, 1500)
    config.PredictionMs = math.clamp(math.floor(config.PredictionMs), 0, 180)
    config.MaxAngularCorrection = math.clamp(math.floor(config.MaxAngularCorrection), 2, 25)
end
local function loadConfig()
    if type(readfile) ~= "function" then return end
    local ok, saved = pcall(function() return HttpService:JSONDecode(readfile(SAVE_PATH)) end)
    if not ok or type(saved) ~= "table" then return end
    for name, original in pairs(config) do
        if type(saved[name]) == type(original) then config[name] = saved[name] end
    end
    clampConfig()
end
local function saveConfig()
    if type(writefile) ~= "function" then return end
    pcall(function() writefile(SAVE_PATH, HttpService:JSONEncode(config)) end)
end
loadConfig()
-- Do not silently re-enable an unverified shot experiment on reload.
config.ExperimentalSilentAim = false

local COLORS = {
    panel = Color3.fromRGB(18, 26, 38),
    dark = Color3.fromRGB(31, 42, 60),
    border = Color3.fromRGB(86, 107, 143),
    white = Color3.fromRGB(233, 242, 255),
    secondary = Color3.fromRGB(160, 178, 197),
    enemy = Color3.fromRGB(239, 107, 108),
    friendly = Color3.fromRGB(103, 175, 227),
    selected = Color3.fromRGB(248, 204, 113),
    clear = Color3.fromRGB(121, 227, 168),
    uncertain = Color3.fromRGB(152, 172, 198)
}

local active = true
local conns = {}
local registry = {}
local state = {
    selected = nil, selection = nil, reticle = Vector2.new(0, 0),
    nativeReticle = false, weaponName = "None", weaponAccuracy = nil,
    searches = 0, changes = 0, rejectedFriendlies = 0,
    rejectedOccluded = 0, lastSelectedAt = 0,
    frames = 0, fps = 0, lastFPSAt = os.clock(),
    lastSample = 0, nextVisuals = 0,
    diagnostics = {}, failure = nil,
    hookState = "OFF", hookError = nil, shotRequestsSeen = 0,
    correctedShots = 0, skippedNoTarget = 0,
    skippedObstructed = 0, skippedOutOfAngle = 0,
    failedCorrections = 0, lastCorrectionRegion = nil,
    genericHitFeedback = 0,
    errorStreak = 0, skipsNoReticle = 0, skipsBadCharacter = 0,
    skipsInvalidTool = 0
}

local function ownConnection(signal, callback, list)
    local conn = signal:Connect(callback)
    table.insert(list or conns, conn)
    return conn
end
local function create(className, properties, parent)
    local instance = Instance.new(className)
    for property, value in pairs(properties) do instance[property] = value end
    instance.Parent = parent
    return instance
end
local function round(object, radius)
    create("UICorner", {CornerRadius = UDim.new(0, radius)}, object)
end
local function border(object, color, transparency, thickness)
    return create("UIStroke", {
        Color = color or COLORS.border,
        Transparency = transparency or 0.35,
        Thickness = thickness or 1
    }, object)
end
local function text(parent, content, position, size, fontSize, color, bold)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        Text = content, Position = position, Size = size,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize = fontSize or 12, TextColor3 = color or COLORS.white,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, parent)
end
local function press(parent, content, position, size)
    local b = create("TextButton", {
        Position = position, Size = size,
        Text = content, TextSize = 12,
        Font = Enum.Font.GothamMedium,
        BackgroundColor3 = COLORS.dark,
        TextColor3 = COLORS.white,
        AutoButtonColor = true, BorderSizePixel = 0
    }, parent)
    round(b, 7)
    return b
end

local function getCamera()
    return workspace.CurrentCamera
end
local function getOwnOrigin()
    local char = localPlayer.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
    local cam = getCamera()
    if root and root:IsA("BasePart") then return root.Position end
    return cam and cam.CFrame.Position or Vector3.new()
end
local function getReticlePoint()
    local cam = getCamera()
    if not cam then return Vector2.new(), false end
    local size = cam.ViewportSize
    local reticleRoot = playerGui:FindFirstChild("Reticle")
    local reticle = reticleRoot and reticleRoot:FindFirstChild("Main")
    if reticle and reticle:IsA("GuiObject") then
        -- Decompiled branch: +.01 Y viewport scale; could vary by input path.
        -- The dot is therefore approximate, not a verified universal shot ray.
        local pos = reticle.Position
        return Vector2.new(pos.X.Scale * size.X, (pos.Y.Scale + 0.01) * size.Y), true
    end
    return Vector2.new(size.X * 0.5, size.Y * 0.51), false
end
local function currentWeapon()
    local char = localPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then return "Unarmed", nil end
    local body = tool:FindFirstChild("BodyAttach")
    local stats = body and body:FindFirstChild("Stats")
    local accuracy = stats and stats:FindFirstChild("Accuracy")
    local value = accuracy and accuracy:IsA("ValueBase") and accuracy.Value
    return tool.Name, type(value) == "number" and value or nil
end
local function friendly(player)
    return localPlayer.Team ~= nil and player.Team ~= nil and localPlayer.Team == player.Team
end

-- Lifecycle-aware registry: each entry owns only its own player connections
-- and current character visuals. Stale character generations cannot be selected.
local function removeVisuals(rec)
    if rec.highlight then pcall(function() rec.highlight:Destroy() end) end
    if rec.billboard then pcall(function() rec.billboard:Destroy() end) end
    rec.highlight, rec.billboard, rec.tagText = nil, nil, nil
end
local function setCharacter(rec, character)
    removeVisuals(rec)
    rec.generation += 1
    rec.character = character
    rec.humanoid = nil
    rec.root = nil
    rec.head = nil
    rec.torso = nil
    rec.lastPosition = nil
    rec.lastTime = nil
    rec.smoothedVelocity = Vector3.new()
    if state.selected == rec.player then
        state.selected, state.selection = nil, nil
    end
end
local function register(player)
    if player == localPlayer or registry[player] then return end
    local rec = {
        player = player, generation = 0, connections = {},
        character = nil, smoothedVelocity = Vector3.new()
    }
    registry[player] = rec
    setCharacter(rec, player.Character)
    ownConnection(player.CharacterAdded, function(char)
        if active and registry[player] == rec then setCharacter(rec, char) end
    end, rec.connections)
    ownConnection(player.CharacterRemoving, function(char)
        if active and rec.character == char then setCharacter(rec, nil) end
    end, rec.connections)
end
local function unregister(player)
    local rec = registry[player]
    if not rec then return end
    for _, conn in ipairs(rec.connections) do pcall(function() conn:Disconnect() end) end
    removeVisuals(rec)
    registry[player] = nil
    if state.selected == player then state.selected, state.selection = nil, nil end
end
for _, player in ipairs(Players:GetPlayers()) do register(player) end
ownConnection(Players.PlayerAdded, register)
ownConnection(Players.PlayerRemoving, unregister)

local function characterParts(rec)
    local char = rec.character
    if not char or char ~= rec.player.Character or not char.Parent then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or root
    local head = char:FindFirstChild("Head")
    if not hum or hum.Health <= 0 or not root or not root:IsA("BasePart") then return nil end
    rec.humanoid, rec.root, rec.torso, rec.head = hum, root, torso, head
    return rec
end
local function sampleVelocity(rec, now)
    local root = rec.root
    if not root then return end
    local pos = root.Position
    local dt = rec.lastTime and (now - rec.lastTime) or 0
    if rec.lastPosition and dt > 0.025 and dt < 0.7 then
        local delta = pos - rec.lastPosition
        if delta.Magnitude < 70 then
            local measured = delta / dt
            if measured.Magnitude < 170 then
                rec.smoothedVelocity = rec.smoothedVelocity:Lerp(measured, 0.4)
            end
        end
    end
    rec.lastPosition, rec.lastTime = pos, now
end
local function estimatedPoint(part, rec, visualPreview)
    if not part or not part:IsA("BasePart") then return nil end
    local position = part.Position
    -- Experimental uncalibrated movement lead is ONLY for screen previews.
    if visualPreview and config.Prediction and rec.lastTime
        and os.clock() - rec.lastTime < 0.45 then
        position += rec.smoothedVelocity * (config.PredictionMs / 1000)
    end
    return position
end
local function clearPath(character, position)
    local cam = getCamera()
    if not cam or not character then return nil end
    local origin = cam.CFrame.Position
    local direction = position - origin
    if direction.Magnitude < 0.02 then return nil end
    local filters = {}
    if localPlayer.Character then table.insert(filters, localPlayer.Character) end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = filters
    params.IgnoreWater = true
    local hit = workspace:Raycast(origin, direction, params)
    if not hit then return true end
    return hit.Instance:IsDescendantOf(character)
end
local function regionPoint(rec, visualPreview)
    local head = estimatedPoint(rec.head, rec, visualPreview)
    local torso = estimatedPoint(rec.torso, rec, visualPreview)
        or estimatedPoint(rec.root, rec, visualPreview)
    -- Assess obstruction at CURRENT replicated part positions, not future points
    -- that may be outside the target's character collision geometry.
    local headClear = rec.head and clearPath(rec.character, rec.head.Position)
    local center = rec.torso or rec.root
    local torsoClear = center and clearPath(rec.character, center.Position)
    if config.AimRegion == "Head" then
        if head then return head, "HEAD", headClear end
        return torso, "TORSO (NO HEAD)", torsoClear
    end
    if config.AimRegion == "Torso" then
        if torso then return torso, "TORSO", torsoClear end
        return head, "HEAD (NO TORSO)", headClear
    end
    if head and headClear == true then return head, "HEAD", true end
    if torso then return torso, "TORSO (FALLBACK)", torsoClear end
    return head, "HEAD", headClear
end
local function evaluate(rec, reticle, visualPreview)
    if rec.player == localPlayer or not characterParts(rec) then return nil end
    if config.TeamFilter and friendly(rec.player) then
        state.rejectedFriendlies += 1
        return nil
    end
    local cam = getCamera()
    if not cam then return nil end
    local point, region, canSee = regionPoint(rec, visualPreview)
    if not point then return nil end
    local distance = (getOwnOrigin() - point).Magnitude
    if distance > config.MaxRange then return nil end
    local projected, visibleOnScreen = cam:WorldToViewportPoint(point)
    if not visibleOnScreen or projected.Z <= 0 then return nil end
    local pixel = Vector2.new(projected.X, projected.Y)
    local errorPixels = (pixel - reticle).Magnitude
    if errorPixels > config.FOV * 1.14 then return nil end
    if config.RequireVisible and canSee ~= true then
        state.rejectedOccluded += 1
        return nil
    end
    return {
        record = rec, player = rec.player, character = rec.character,
        generation = rec.generation, point = point, pixel = pixel,
        region = region, distance = distance, errorPixels = errorPixels,
        clear = canSee, health = rec.humanoid.Health,
        velocity = rec.smoothedVelocity
    }
end
local function findTarget(reticle, visualPreview)
    if visualPreview == nil then visualPreview = true end
    local best
    state.searches += 1
    local now = os.clock()
    for _, rec in pairs(registry) do
        if characterParts(rec) then sampleVelocity(rec, now) end
        local candidate = evaluate(rec, reticle, visualPreview)
        if candidate and candidate.errorPixels <= config.FOV then
            if not best or candidate.errorPixels < best.errorPixels then best = candidate end
        end
    end
    local retained = state.selected and registry[state.selected]
    local old = retained and evaluate(retained, reticle, visualPreview) or nil
    if old and old.errorPixels <= config.FOV * 1.14 then
        if not best or best.player == old.player or old.errorPixels <= best.errorPixels * 1.25 then
            best = old
        end
    end
    if (best and best.player or nil) ~= state.selected then
        state.changes += 1
        state.lastSelectedAt = os.clock()
    end
    state.selection, state.selected = best, best and best.player or nil
end

local function ensureVisual(rec)
    if not characterParts(rec) then
        removeVisuals(rec)
        return nil
    end
    if rec.highlight and rec.highlight.Parent ~= rec.character then removeVisuals(rec) end
    if not rec.highlight then
        rec.highlight = create("Highlight", {
            Name = "NOVAOutline_v02", Adornee = rec.character,
            FillTransparency = 1, OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.Occluded
        }, rec.character)
    end
    if not rec.billboard then
        rec.billboard = create("BillboardGui", {
            Name = "NOVATag_v02", Adornee = rec.head or rec.root,
            Size = UDim2.fromOffset(188, 38),
            StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0),
            AlwaysOnTop = config.ThroughWalls,
            ResetOnSpawn = false
        }, playerGui)
        rec.tagText = text(rec.billboard, rec.player.DisplayName,
            UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 12, COLORS.enemy, true)
        rec.tagText.TextXAlignment = Enum.TextXAlignment.Center
        rec.tagText.TextStrokeTransparency = 0.48
    end
    rec.billboard.Adornee = rec.head or rec.root
    return rec
end
local function updateVisuals()
    local ownPos = getOwnOrigin()
    local sorted = {}
    for _, rec in pairs(registry) do
        if characterParts(rec) then
            local d = (rec.root.Position - ownPos).Magnitude
            table.insert(sorted, {rec = rec, dist = d})
        else
            removeVisuals(rec)
        end
    end
    table.sort(sorted, function(a, b)
        if a.rec.player == state.selected then return true end
        if b.rec.player == state.selected then return false end
        return a.dist < b.dist
    end)
    -- Allocate visuals only for near players in the display budget.
    for index, item in ipairs(sorted) do
        local inRange = item.dist <= config.MaxRange
        local desired = inRange and ((config.Outline and index <= 28)
            or (config.Nametag and index <= 48))
        local rec
        if desired then rec = ensureVisual(item.rec)
        else removeVisuals(item.rec) end
        if rec then
            local selected = state.selected == rec.player
            local teamMate = friendly(rec.player)
            local color = selected and COLORS.selected or (teamMate and COLORS.friendly or COLORS.enemy)
            local near = item.dist <= config.MaxRange
            rec.highlight.FillTransparency = 1
            rec.highlight.OutlineColor = color
            rec.highlight.DepthMode = config.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            rec.highlight.Enabled = config.Outline and near and index <= 28
            rec.billboard.Enabled = config.Nametag and near and index <= 48
            rec.billboard.AlwaysOnTop = config.ThroughWalls
            rec.billboard.MaxDistance = config.MaxRange
            rec.tagText.TextColor3 = color
            rec.tagText.Text = (selected and "◆ " or "") .. rec.player.DisplayName ..
                "  " .. tostring(math.floor(item.dist + 0.5)) .. " st"
        end
    end
end

local gui = create("ScreenGui", {
    Name = "EmpireClash_NOVA_Phase8_v02", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 125,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, playerGui)
local panel = create("Frame", {
    Name = "ControlCenter", Size = UDim2.fromOffset(344, 510),
    Position = UDim2.new(0, 26, 0.5, -255),
    BackgroundColor3 = COLORS.panel, BorderSizePixel = 0
}, gui)
round(panel, 12)
border(panel, COLORS.border, 0.15)

local titleBar = create("Frame", {
    Name = "DragHeader", BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 61)
}, panel)
text(titleBar, "EMPIRE CLASH  /  NOVA", UDim2.fromOffset(16, 9),
    UDim2.fromOffset(282, 22), 17, COLORS.white, true)
text(titleBar, "PHASE 8   •   COMBAT ENGINE FOUNDATION",
    UDim2.fromOffset(17, 34), UDim2.fromOffset(296, 16), 10, COLORS.secondary, true)
local close = press(titleBar, "×", UDim2.fromOffset(305, 11), UDim2.fromOffset(26, 27))
close.TextSize = 19
ownConnection(close.MouseButton1Click, function() panel.Visible = false end)

local scrolling = create("ScrollingFrame", {
    Name = "Options", Position = UDim2.fromOffset(12, 65),
    Size = UDim2.fromOffset(320, 320),
    CanvasSize = UDim2.fromOffset(0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, ScrollBarImageColor3 = COLORS.border
}, panel)
local stack = create("UIListLayout", {
    Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder
}, scrolling)
local order = 0
local rows = {}
local applyExperimentalMode = function(_)
    state.hookError = "Experiment module not loaded."
    return false
end
local function heading(value)
    order += 1
    local l = text(scrolling, value, UDim2.new(), UDim2.new(1, -5, 0, 25),
        11, COLORS.secondary, true)
    l.LayoutOrder = order
end
local function option(labelText, valueFn, action)
    order += 1
    local b = press(scrolling, "", UDim2.new(), UDim2.new(1, -8, 0, 33))
    b.LayoutOrder = order
    local a = text(b, labelText, UDim2.fromOffset(10, 0), UDim2.new(0.65, 0, 1, 0),
        12, COLORS.white, false)
    local v = text(b, "", UDim2.new(0.66, 0, 0, 0), UDim2.new(0.30, 0, 1, 0),
        11, COLORS.clear, true)
    v.TextXAlignment = Enum.TextXAlignment.Right
    local refresh = function() v.Text = valueFn() end
    ownConnection(b.MouseButton1Click, function()
        action()
        clampConfig()
        refresh()
        saveConfig()
    end)
    table.insert(rows, refresh)
    refresh()
    return b
end
local function switch(name)
    config[name] = not config[name]
end
local function optionsCycle(list, current)
    for i, v in ipairs(list) do
        if current <= v then return list[i % #list + 1] end
    end
    return list[1]
end
heading("SILENT AIM  •  EXPERIMENTAL / UNVERIFIED")
option("Experimental shot correction", function()
    return config.ExperimentalSilentAim and "ON (RISK)" or "OFF"
end, function()
    local enable = not config.ExperimentalSilentAim
    if applyExperimentalMode(enable) then
        config.ExperimentalSilentAim = enable
    else
        config.ExperimentalSilentAim = false
    end
end)
option("Maximum correction angle", function()
    return tostring(config.MaxAngularCorrection) .. " deg"
end, function()
    config.MaxAngularCorrection = optionsCycle({4, 8, 12, 18, 25}, config.MaxAngularCorrection)
end)
heading("TARGET SELECTION / AIM INTENT")
option("Preferred hit region", function() return string.upper(config.AimRegion) end, function()
    local modes = {Adaptive = "Head", Head = "Torso", Torso = "Adaptive"}
    config.AimRegion = modes[config.AimRegion]
end)
option("Target FOV", function() return tostring(config.FOV) .. " px" end, function()
    config.FOV = optionsCycle({100, 160, 220, 300, 400}, config.FOV)
end)
option("Maximum range", function() return tostring(config.MaxRange) .. " st" end, function()
    config.MaxRange = optionsCycle({250, 550, 850, 1200}, config.MaxRange)
end)
option("Ignore same-team players", function() return config.TeamFilter and "ON" or "OFF" end, function()
    switch("TeamFilter")
end)
option("Require clear sight", function() return config.RequireVisible and "ON" or "OFF" end, function()
    switch("RequireVisible")
end)
option("Preview movement lead", function() return config.Prediction and "ON" or "OFF" end, function()
    switch("Prediction")
end)
option("Prediction horizon", function() return tostring(config.PredictionMs) .. " ms" end, function()
    config.PredictionMs = optionsCycle({0, 40, 70, 110, 160}, config.PredictionMs)
end)
heading("TARGET VISUALS")
option("Outline-only chams", function() return config.Outline and "ON" or "OFF" end, function()
    switch("Outline")
end)
option("Nametags + distance", function() return config.Nametag and "ON" or "OFF" end, function()
    switch("Nametag")
end)
option("ESP through walls", function() return config.ThroughWalls and "ON" or "OFF" end, function()
    switch("ThroughWalls")
end)
option("Target card", function() return config.TargetCard and "ON" or "OFF" end, function()
    switch("TargetCard")
end)
option("Intended aim marker", function() return config.AimMarker and "ON" or "OFF" end, function()
    switch("AimMarker")
end)
option("Targeting radius ring", function() return config.FOVRing and "ON" or "OFF" end, function()
    switch("FOVRing")
end)
option("Native reticle marker", function() return config.FirePoint and "ON" or "OFF" end, function()
    switch("FirePoint")
end)
heading("LIFECYCLE")
option("Queue across map travel", function() return config.AutoQueue and "ON" or "OFF" end, function()
    switch("AutoQueue")
end)

local status = text(panel, "TARGET ENGINE: READY  |  EXPERIMENT OFF",
    UDim2.fromOffset(16, 392), UDim2.fromOffset(313, 50), 11, COLORS.secondary)
status.TextWrapped = true
status.TextYAlignment = Enum.TextYAlignment.Top
local copy = press(panel, "COPY DIAGNOSTICS", UDim2.fromOffset(15, 465), UDim2.fromOffset(192, 29))
local unload = press(panel, "UNLOAD", UDim2.fromOffset(216, 465), UDim2.fromOffset(112, 29))

local targetCard = create("Frame", {
    Name = "SelectedTarget", Size = UDim2.fromOffset(292, 90),
    Position = UDim2.new(1, -312, 0, 32),
    BackgroundColor3 = COLORS.panel,
    BackgroundTransparency = 0.08, BorderSizePixel = 0, Visible = false
}, gui)
round(targetCard, 9)
border(targetCard, COLORS.border, 0.15)
local cardTitle = text(targetCard, "SELECTED TARGET", UDim2.fromOffset(12, 8),
    UDim2.fromOffset(265, 16), 10, COLORS.secondary, true)
local cardName = text(targetCard, "None", UDim2.fromOffset(12, 26),
    UDim2.fromOffset(265, 21), 14, COLORS.white, true)
local cardData = text(targetCard, "", UDim2.fromOffset(12, 52),
    UDim2.fromOffset(265, 27), 11, COLORS.selected)
cardData.TextWrapped = true

local ring = create("Frame", {
    Name = "TargetFOV", Size = UDim2.fromOffset(320, 320),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1, BorderSizePixel = 0
}, gui)
create("UICorner", {CornerRadius = UDim.new(1, 0)}, ring)
border(ring, COLORS.friendly, 0.72, 1)
local reticleMarker = create("Frame", {
    Name = "EstimatedNativeFirePoint",
    Size = UDim2.fromOffset(6, 6), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = COLORS.clear, BorderSizePixel = 0
}, gui)
round(reticleMarker, 6)
local aimMarker = create("Frame", {
    Name = "PredictedPointPreview", Size = UDim2.fromOffset(16, 16),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false
}, gui)
round(aimMarker, 16)
local aimStroke = border(aimMarker, COLORS.selected, 0, 2)

local dragging, dragAt, dragPos = false, nil, nil
ownConnection(titleBar.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragAt, dragPos = true, input.Position, panel.Position
    end
end)
ownConnection(UserInputService.InputChanged, function(input)
    if dragging and dragAt and dragPos
        and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
        local diff = input.Position - dragAt
        panel.Position = UDim2.new(dragPos.X.Scale, dragPos.X.Offset + diff.X,
            dragPos.Y.Scale, dragPos.Y.Offset + diff.Y)
    end
end)
ownConnection(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
ownConnection(UserInputService.InputBegan, function(input)
    if input.KeyCode == Enum.KeyCode.RightShift and not UserInputService:GetFocusedTextBox() then
        panel.Visible = not panel.Visible
    end
end)

local function validSelection()
    local s = state.selection
    if not s then return nil end
    local rec = registry[s.player]
    if not rec or rec.generation ~= s.generation or rec.character ~= s.character then return nil end
    if not characterParts(rec) then return nil end
    return s
end
local function getDiagnostics()
    local chosen = validSelection()
    return {
        product = "Empire Clash NOVA", version = VERSION, phase = "8A/B FOUNDATION",
        game_id = game.GameId, place_id = game.PlaceId,
        native_reticle_approximate = state.nativeReticle,
        weapon = state.weaponName, client_accuracy_raw = state.weaponAccuracy,
        selected_target_present = chosen ~= nil,
        selected_region = chosen and chosen.region or nil,
        selected_distance = chosen and math.floor(chosen.distance + 0.5) or nil,
        selected_pixel_error = chosen and math.floor(chosen.errorPixels + 0.5) or nil,
        selected_clear_path = chosen and chosen.clear or nil,
        target_changes = state.changes, target_searches = state.searches,
        rejected_same_team = state.rejectedFriendlies,
        rejected_occluded = state.rejectedOccluded,
        measured_fps = state.fps,
        client_ray_modified = state.correctedShots > 0,
        silent_aim_enabled = config.ExperimentalSilentAim,
        shot_hook_state = state.hookState,
        shot_requests_seen = state.shotRequestsSeen,
        correction_proposals_submitted = state.correctedShots,
        generic_hit_feedback = state.genericHitFeedback,
        skipped_no_target = state.skippedNoTarget,
        skipped_obstructed = state.skippedObstructed,
        skipped_angle = state.skippedOutOfAngle,
        failed_corrections = state.failedCorrections,
        hook_error = state.hookError,
        last_correction_region = state.lastCorrectionRegion,
        local_error_streak = state.errorStreak,
        skipped_missing_native_reticle = state.skipsNoReticle,
        skipped_invalid_character = state.skipsBadCharacter,
        skipped_invalid_tool = state.skipsInvalidTool,
        uncalibrated_prediction_preview_only = true,
        silent_aim_server_verified = false,
        anti_cheat_safety_verified = false,
        latest_error = state.failure,
        config = config
    }
end
ownConnection(copy.MouseButton1Click, function()
    local output = HttpService:JSONEncode(getDiagnostics())
    if type(setclipboard) == "function" then
        local ok = pcall(setclipboard, output)
        status.Text = ok and "Diagnostics copied. No player names or IDs included."
            or "Clipboard unavailable. See executor output."
    else
        status.Text = "No clipboard API. Diagnostics printed in executor."
    end
    print("[EC NOVA DIAGNOSTICS] " .. output)
end)

local function shutdown()
    if not active then return end
    active = false
    -- Hooks are process-wide for many executors: disable the callback on unload.
    pcall(function() applyExperimentalMode(false) end)
    for _, conn in ipairs(conns) do pcall(function() conn:Disconnect() end) end
    for player in pairs(registry) do unregister(player) end
    pcall(function() gui:Destroy() end)
    if type(global.ECNovaCombat) == "table" and global.ECNovaCombat.Shutdown == shutdown then
        global.ECNovaCombat = nil
    end
end
global.ECNovaCombat = {
    Version = VERSION, Config = config, Shutdown = shutdown,
    GetDiagnostics = getDiagnostics, SaveSettings = saveConfig
}
ownConnection(unload.MouseButton1Click, shutdown)


-- ================================================================
-- PHASE 8C: OPTIONAL ACTIVE SHOT-CORRECTION EXPERIMENT
-- ================================================================
-- Based on the recovered client call FireGun:Fire(weapon, ray, nativeState).
-- No remotes are generated here: only a user-triggered, native shot is eligible.
-- Not server-validated. No anti-cheat or integrity protections are bypassed.
local HOOK_KEY = "ECNovaFireGunDispatcher_v1"

local function correctedRay(tool, ray)
    if not active or not config.ExperimentalSilentAim then return nil, "DISABLED" end
    if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then return nil, "BAD_TOOL" end
    if typeof(ray) ~= "Ray" then return nil, "BAD_RAY" end
    local magnitude = ray.Direction.Magnitude
    if magnitude ~= magnitude or magnitude < 0.01 or magnitude == math.huge then
        return nil, "BAD_RAY"
    end
    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil, "BAD_CHARACTER" end
    if tool.Parent ~= character or tool:GetAttribute("Melee") ~= false then
        return nil, "NOT_EQUIPPED_FIREARM"
    end
    -- Do not guess aim direction when the native reticle UI is unavailable.
    local reticle, native = getReticlePoint()
    local cam = getCamera()
    if not native or not cam then return nil, "NO_NATIVE_RETICLE" end
    local viewport = cam.ViewportSize
    if reticle.X < 0 or reticle.Y < 0 or reticle.X > viewport.X
        or reticle.Y > viewport.Y then
        return nil, "NO_NATIVE_RETICLE"
    end
    -- Recompute at shot time. Never apply unverified motion lead to fired rays.
    findTarget(reticle, false)
    local selection = validSelection()
    if not selection or selection.errorPixels > config.FOV then return nil, "NO_TARGET" end
    if config.TeamFilter and friendly(selection.player) then return nil, "FRIENDLY" end
    if clearPath(selection.character, selection.point) ~= true then return nil, "BLOCKED" end
    local delta = selection.point - ray.Origin
    if delta.Magnitude < 0.01 then return nil, "NO_DIRECTION" end
    local unit = delta.Unit
    local angle = math.deg(math.acos(math.clamp(ray.Direction.Unit:Dot(unit), -1, 1)))
    if angle > config.MaxAngularCorrection then return nil, "ANGLE_LIMIT" end
    state.lastCorrectionRegion = selection.region
    return Ray.new(ray.Origin, unit * magnitude), "PREPARED"
end
local function transformShot(tool, ray)
    state.shotRequestsSeen += 1
    local ok, replacement, reason = pcall(correctedRay, tool, ray)
    if not ok then
        state.failedCorrections += 1
        state.errorStreak += 1
        state.hookError = tostring(replacement)
        if state.errorStreak >= 3 then
            pcall(function() applyExperimentalMode(false) end)
            state.hookState = "AUTO_DISABLED_AFTER_ERRORS"
        end
        return nil
    end
    state.errorStreak = 0
    if replacement then
        state.correctedShots += 1
        return replacement
    end
    if reason == "NO_TARGET" then
        state.skippedNoTarget += 1
    elseif reason == "NO_NATIVE_RETICLE" then
        state.skipsNoReticle += 1
    elseif reason == "BAD_CHARACTER" then
        state.skipsBadCharacter += 1
    elseif reason == "NOT_EQUIPPED_FIREARM" or reason == "BAD_TOOL" then
        state.skipsInvalidTool += 1
    elseif reason == "BLOCKED" then
        state.skippedObstructed += 1
    elseif reason == "ANGLE_LIMIT" then
        state.skippedOutOfAngle += 1
    end
    return nil
end

local function getFireGun()
    local storage = game:GetService("ReplicatedStorage")
    local packages = storage:FindFirstChild("Packages")
    local module = packages and packages:FindFirstChild("Knit")
    if not module or not module:IsA("ModuleScript") then
        return nil, nil, "Knit client module unavailable."
    end
    local ok, Knit = pcall(require, module)
    if not ok or type(Knit) ~= "table" or type(Knit.GetService) ~= "function" then
        return nil, nil, "Knit service API unavailable."
    end
    local okService, service = pcall(function() return Knit.GetService("DamageService") end)
    if not okService or not service then return nil, nil, "DamageService unavailable." end
    local signal = service.FireGun
    if not signal or type(signal.Fire) ~= "function" then
        return nil, nil, "FireGun signal unavailable."
    end
    return signal, service, nil
end

local function getDispatcher(signal)
    local existing = global[HOOK_KEY]
    if type(existing) == "table" and existing.installed then
        if existing.signal ~= signal then
            return nil, "Existing FireGun dispatcher belongs to another session."
        end
        return existing
    end
    if type(hookfunction) ~= "function" then
        return nil, "Executor has no hookfunction support."
    end
    local entry = {signal = signal, callback = nil, installed = false}
    local original
    local function wrapped(self, ...)
        if self ~= entry.signal or not entry.callback then
            return original(self, ...)
        end
        local args = table.pack(...)
        if args.n >= 2 then
            local ok, result = pcall(entry.callback, args[1], args[2])
            if ok and typeof(result) == "Ray" then args[2] = result end
        end
        return original(self, table.unpack(args, 1, args.n))
    end
    local ok, result = pcall(hookfunction, signal.Fire, wrapped)
    if not ok or type(result) ~= "function" then
        return nil, "Runtime refused FireGun interception."
    end
    original = result
    entry.installed = true
    global[HOOK_KEY] = entry
    return entry
end

local hookEntry, hitmarkerConnection = nil, nil
applyExperimentalMode = function(enabled)
    if not enabled then
        if hookEntry and hookEntry.callback == transformShot then
            hookEntry.callback = nil
        end
        config.ExperimentalSilentAim = false
        state.hookState = "OFF"
        return true
    end
    local signal, service, err = getFireGun()
    if not signal then
        state.hookState, state.hookError = "UNAVAILABLE", err
        return false
    end
    local entry, reason = getDispatcher(signal)
    if not entry then
        state.hookState, state.hookError = "UNAVAILABLE", reason
        return false
    end
    hookEntry = entry
    entry.callback = transformShot
    state.hookState, state.hookError = "EXPERIMENTAL", nil
    state.errorStreak = 0
    -- Count only generic feedback: no target-specific confirmation is proven.
    if not hitmarkerConnection and service.SendHitmarker
        and type(service.SendHitmarker.Connect) == "function" then
        local ok, connection = pcall(function()
            return service.SendHitmarker:Connect(function()
                if active then state.genericHitFeedback += 1 end
            end)
        end)
        if ok and connection then
            hitmarkerConnection = connection
            table.insert(conns, connection)
        end
    end
    return true
end
-- Mandatory off state at bootstrap, regardless of saved settings.
config.ExperimentalSilentAim = false
state.hookState = "OFF"

-- Lightweight render work only; target search and player visuals are throttled.
ownConnection(RunService.RenderStepped, function(dt)
    if not active then return end
    local cam = getCamera()
    if not cam then return end
    state.frames += 1
    local now = os.clock()
    if now - state.lastFPSAt >= 1 then
        state.fps = math.floor(state.frames / (now - state.lastFPSAt) + 0.5)
        state.frames, state.lastFPSAt = 0, now
    end
    state.reticle, state.nativeReticle = getReticlePoint()
    ring.Size = UDim2.fromOffset(config.FOV * 2, config.FOV * 2)
    ring.Position = UDim2.fromOffset(state.reticle.X, state.reticle.Y)
    ring.Visible = config.FOVRing
    reticleMarker.Position = UDim2.fromOffset(state.reticle.X, state.reticle.Y)
    reticleMarker.Visible = config.FirePoint
    reticleMarker.BackgroundColor3 = state.nativeReticle and COLORS.clear or COLORS.uncertain

    if now - state.lastSample >= 0.10 then
        state.lastSample = now
        local ok, err = pcall(function()
            findTarget(state.reticle)
            state.weaponName, state.weaponAccuracy = currentWeapon()
        end)
        if not ok then state.failure = tostring(err) end
    end
    if now - state.nextVisuals >= 0.23 then
        state.nextVisuals = now
        local ok, err = pcall(updateVisuals)
        if not ok then state.failure = tostring(err) end
    end
    local selected = validSelection()
    if selected then
        local aimPixel, onScreen = cam:WorldToViewportPoint(selected.point)
        if aimPixel.Z > 0 and onScreen then
            aimMarker.Position = UDim2.fromOffset(aimPixel.X, aimPixel.Y)
            aimMarker.Visible = config.AimMarker
            aimStroke.Color = selected.clear and COLORS.selected or COLORS.enemy
        else
            aimMarker.Visible = false
        end
        targetCard.Visible = config.TargetCard
        cardName.Text = selected.player.DisplayName
        cardData.Text = string.format("%s  |  %d HP  |  %d st  |  %s",
            selected.region, math.floor(selected.health + 0.5),
            math.floor(selected.distance + 0.5),
            selected.clear == true and "CLEAR PATH" or "BLOCKED / UNKNOWN")
    else
        aimMarker.Visible = false
        targetCard.Visible = false
    end
    if panel.Visible then
        local accuracyStr = state.weaponAccuracy and (" | accuracy stat " .. tostring(state.weaponAccuracy)) or ""
        local modeStatus = config.ExperimentalSilentAim
            and "EXPERIMENTAL SHOT CORRECTION: ON"
            or "EXPERIMENTAL SHOT CORRECTION: OFF"
        if state.hookError and not config.ExperimentalSilentAim then
            modeStatus = "SHOT CORRECTION UNAVAILABLE: " .. tostring(state.hookError)
        end
        status.Text = modeStatus .. " | SERVER UNVERIFIED\n" ..
            (state.nativeReticle and "Reticle estimate" or "Reticle fallback") ..
            " • " .. state.weaponName .. accuracyStr ..
            " • " .. tostring(state.fps) .. " FPS | proposed " ..
            tostring(state.correctedShots)
    end
end)

-- Optional map continuity. Universe guard ensures this script does nothing if
-- the player leaves Empire Clash for a different Roblox universe.
if config.AutoQueue then
    local queue = type(queue_on_teleport) == "function" and queue_on_teleport or nil
    if not queue and type(syn) == "table" and type(syn.queue_on_teleport) == "function" then
        queue = syn.queue_on_teleport
    end
    if queue then
        pcall(queue, 'loadstring(game:HttpGet("' .. SOURCE_URL .. '"))()')
    end
end
print("[EC NOVA] Phase 8 foundation v" .. VERSION ..
    " running. RightShift = panel; optional shot correction unverified; no anti-cheat bypass.")
