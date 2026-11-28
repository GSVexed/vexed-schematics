-- EMPIRE CLASH NOVA | Combat Guide v0.8.0
-- Read-only weapon intelligence, client-visible targeting, and faction visuals.
-- No shot interception, remote firing, camera snapping or anti-cheat bypass.
-- Source basis: saved 2026-11-23 Runespire client research, not live verification.

local VERSION = "0.8.0"
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
local SOURCE_URL = "https://raw.githubusercontent.com/GSVexed/vexed-schematics/project-empire-clash-nova/roblox-tools/empire-clash-nova-combat-guide-v0.8.lua"
local config = {
    AimRegion = "Adaptive",
    FOV = 160, MaxRange = 550,
    TeamFilter = true, RequireVisible = true,
    Prediction = false, PredictionMs = 70,
    Outline = true, Nametag = true, ThroughWalls = false,
    FactionLabels = true, DisguiseAlerts = true,
    TargetCard = true, AimMarker = true,
    FOVRing = true, FirePoint = true,
    AutoQueue = true,
    WeaponGuide = true, ShotFeedback = true, ShowWeaponHint = true
}
local function safeBoundedInt(value, fallback, minValue, maxValue)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge then
        return fallback
    end
    return math.clamp(math.floor(value), minValue, maxValue)
end
local function clampConfig()
    if config.AimRegion ~= "Head" and config.AimRegion ~= "Torso" and config.AimRegion ~= "Adaptive" then
        config.AimRegion = "Adaptive"
    end
    config.FOV = safeBoundedInt(config.FOV, 160, 60, 460)
    config.MaxRange = safeBoundedInt(config.MaxRange, 550, 120, 1500)
    config.PredictionMs = safeBoundedInt(config.PredictionMs, 70, 0, 180)
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
    weaponClass = "UNARMED", weaponHint = "Equip a weapon",
    guideStatus = "NO TARGET", genericHitFeedback = 0,
    genericDamageFeedback = 0, lastHitAt = 0, lastDamageAt = 0,
    feedbackAttached = false, feedbackLastTry = -100, feedbackStatus = "NOT CONNECTED",
    profiles = 0
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
-- Conservative weapon-family identification; no shot calculation is altered.
local function weaponProfile(tool)
    if localPlayer:GetAttribute("CannonSittingClient") == true then
        return "CANNON", "Use native spotter and elevation; impact is unverified."
    end
    if not tool then return "UNARMED", "Equip a combat weapon." end
    local name = string.lower(tool.Name)
    if name:find("grenade", 1, true) or name:find("bomb", 1, true) then
        return "THROWN", "Use native throw arc and cover preview."
    end
    if name:find("cannon", 1, true) or name:find("mortar", 1, true) then
        return "CANNON", "Use native artillery prediction and obstruction."
    end
    if name:find("blunderbuss", 1, true) or name:find("shotgun", 1, true) then
        return "SPREAD", "Centre-mass guidance; pellet spread unverified."
    end
    if name:find("flintlock", 1, true) or name:find("pistol", 1, true) then
        return "PISTOL", "Check native reticle and mounted-angle limits."
    end
    if name:find("rifle", 1, true) or name:find("musket", 1, true)
        or name:find("carbine", 1, true) then
        return "PRECISION", "Reticle alignment only; spread remains possible."
    end
    if name:find("bow", 1, true) then
        return "BOW", "Visual alignment only; ballistics unverified."
    end
    if tool:GetAttribute("Melee") == true then
        return "MELEE", "Proximity, obstruction and native swing timing."
    end
    if tool:GetAttribute("Melee") == false then
        return "FIREARM", "Use native reticle; spread and damage unverified."
    end
    return "UTILITY", "Weapon-specific mechanics not established."
end

local function currentWeapon()
    local char = localPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    local family, hint = weaponProfile(tool)
    local label = tool and tool.Name or (family == "CANNON" and "Mounted cannon" or "Unarmed")
    if not tool then return label, nil, family, hint end
    local body = tool:FindFirstChild("BodyAttach")
    local stats = body and body:FindFirstChild("Stats")
    local accuracy = stats and stats:FindFirstChild("Accuracy")
    local value = accuracy and accuracy:IsA("ValueBase") and accuracy.Value
    if type(value) ~= "number" or value ~= value or value < 0
        or value == math.huge or value == -math.huge then
        return label, nil, family, hint
    end
    return label, value, family, hint
end

-- The recovered DisguiseController / ChatController use Player.Team for
-- actual faction, separately from Player:GetAttribute("DisguisedTeam").
-- Clothing, shown colours, class appearance and forged name are not trusted.
local function factionIdentity(player)
    local trueTeam = player.Team
    local actual = trueTeam and trueTeam.Name or "UNKNOWN"
    local color = trueTeam and trueTeam.TeamColor.Color or COLORS.uncertain
    local same = trueTeam ~= nil and localPlayer.Team ~= nil
        and trueTeam == localPlayer.Team
    local disguise = player:GetAttribute("DisguisedTeam")
    if type(disguise) ~= "string" or disguise == "" or disguise == actual then
        disguise = nil
    end
    local stats = player:FindFirstChild("leaderstats")
    local classValue = stats and stats:FindFirstChild("Class")
    local className = classValue and classValue:IsA("StringValue") and classValue.Value or nil
    local forged = player:GetAttribute("ForgedName")
    local forgedIdentity = type(forged) == "string" and forged ~= ""
        and forged ~= player.Name
    local pretendingOurTeam = not same and disguise ~= nil
        and localPlayer.Team ~= nil and disguise == localPlayer.Team.Name
    return {
        actual = actual, color = color, sameTeam = same,
        known = trueTeam ~= nil, disguise = disguise,
        className = className, isThief = className == "Thief",
        forgedName = forgedIdentity, pretendingOurTeam = pretendingOurTeam
    }
end
local function factionCaption(id)
    if not id.known then return "FACTION UNKNOWN" end
    if config.DisguiseAlerts then
        if id.pretendingOurTeam then
            return "DISGUISED AS YOUR TEAM | REAL: " .. id.actual
        end
        if id.disguise then
            return "REAL: " .. id.actual .. " | MASK: " .. id.disguise
        end
        if id.isThief then return "REAL: " .. id.actual .. " | THIEF" end
        if id.forgedName then return "REAL: " .. id.actual .. " | FORGED NAME" end
    end
    return id.actual .. (id.sameTeam and " | ALLY" or " | OTHER FACTION")
end
local function friendly(player)
    -- Relationship always uses actual replicated Player.Team.
    return localPlayer.Team ~= nil and player.Team ~= nil and localPlayer.Team == player.Team
end

-- Lifecycle-aware registry: each entry owns only its own player connections
-- and current character visuals. Stale character generations cannot be selected.
local function removeVisuals(rec)
    if rec.highlight then pcall(function() rec.highlight:Destroy() end) end
    if rec.billboard then pcall(function() rec.billboard:Destroy() end) end
    rec.highlight, rec.billboard, rec.tagText, rec.tagSub = nil, nil, nil, nil
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
                rec.smoothedVelocity = rec.smoothedVelocity:Lerp(measured, 0.33)
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
    local mode = config.AimRegion
    -- This only selects an indicative point, not a server headshot.
    if mode == "Adaptive" and (state.weaponClass == "SPREAD"
        or state.weaponClass == "MELEE" or state.weaponClass == "THROWN") then
        mode = "Torso"
    end
    local head = estimatedPoint(rec.head, rec, visualPreview)
    local torso = estimatedPoint(rec.torso, rec, visualPreview)
        or estimatedPoint(rec.root, rec, visualPreview)
    -- Assess obstruction at CURRENT replicated part positions, not future points
    -- that may be outside the target's character collision geometry.
    local headClear = rec.head and clearPath(rec.character, rec.head.Position)
    local center = rec.torso or rec.root
    local torsoClear = center and clearPath(rec.character, center.Position)
    if mode == "Head" then
        if head then return head, "HEAD", headClear end
        return torso, "TORSO (NO HEAD)", torsoClear
    end
    if mode == "Torso" then
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
    -- Cull off-screen/out-of-range entities BEFORE costly obstruction raycasts.
    local ownOrigin = getOwnOrigin()
    if (ownOrigin - rec.root.Position).Magnitude > config.MaxRange + 15 then return nil end
    local rough = rec.head or rec.torso or rec.root
    local roughPx, roughVisible = cam:WorldToViewportPoint(rough.Position)
    if not roughVisible or roughPx.Z <= 0 then return nil end
    if (Vector2.new(roughPx.X, roughPx.Y) - reticle).Magnitude
        > config.FOV * 1.6 then return nil end
    local point, region, canSee = regionPoint(rec, visualPreview)
    if not point then return nil end
    local distance = (ownOrigin - point).Magnitude
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
        velocity = rec.smoothedVelocity, sampledAt = os.clock()
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
            Name = "NOVAOutline_v07", Adornee = rec.character,
            FillTransparency = 1, OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.Occluded
        }, rec.character)
    end
    if not rec.billboard then
        rec.billboard = create("BillboardGui", {
            Name = "NOVATag_v07", Adornee = rec.head or rec.root,
            Size = UDim2.fromOffset(264, 56),
            StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0),
            AlwaysOnTop = config.ThroughWalls,
            ResetOnSpawn = false
        }, playerGui)
        rec.tagText = text(rec.billboard, rec.player.DisplayName,
            UDim2.new(0, 5, 0, 2), UDim2.new(1, -10, 0, 25),
            15, COLORS.white, true)
        rec.tagText.TextXAlignment = Enum.TextXAlignment.Center
        rec.tagText.TextStrokeColor3 = Color3.new(0, 0, 0)
        rec.tagText.TextStrokeTransparency = 0.12
        rec.tagSub = text(rec.billboard, "FACTION UNKNOWN",
            UDim2.new(0, 5, 0, 28), UDim2.new(1, -10, 0, 22),
            10, COLORS.secondary, true)
        rec.tagSub.TextXAlignment = Enum.TextXAlignment.Center
        rec.tagSub.TextStrokeColor3 = Color3.new(0, 0, 0)
        rec.tagSub.TextStrokeTransparency = 0.08
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
        local selectedA = a.rec.player == state.selected
        local selectedB = b.rec.player == state.selected
        if selectedA ~= selectedB then return selectedA end
        if a.dist ~= b.dist then return a.dist < b.dist end
        return a.rec.player.UserId < b.rec.player.UserId
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
            local identity = factionIdentity(rec.player)
            -- The player's actual faction's exact TeamColor drives BOTH
            -- outline ESP and the name, even when that player is selected.
            -- A target selection glyph is used instead of overriding its hue.
            local factionColor = identity.color
            local near = item.dist <= config.MaxRange
            rec.highlight.FillTransparency = 1
            rec.highlight.OutlineColor = factionColor
            rec.highlight.DepthMode = config.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            rec.highlight.Enabled = config.Outline and near and index <= 28
            rec.billboard.Enabled = config.Nametag and near and index <= 48
            rec.billboard.AlwaysOnTop = config.ThroughWalls
            rec.billboard.MaxDistance = config.MaxRange
            rec.tagText.TextColor3 = factionColor
            rec.tagText.Text = (selected and "◆ " or "")
                .. rec.player.DisplayName .. "  "
                .. tostring(math.floor(item.dist + 0.5)) .. " st"
            rec.tagSub.TextColor3 = identity.pretendingOurTeam
                and COLORS.selected or COLORS.white
            rec.tagSub.Visible = config.FactionLabels
            rec.tagSub.Text = factionCaption(identity)
        end
    end
end

local gui = create("ScreenGui", {
    Name = "EmpireClash_NOVA_Guide_v08", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 125,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, playerGui)
local panel = create("Frame", {
    Name = "ControlCenter", Size = UDim2.fromOffset(354, 486),
    Position = UDim2.new(0, 26, 0.5, -243),
    BackgroundColor3 = COLORS.panel, BorderSizePixel = 0
}, gui)
round(panel, 12)
border(panel, COLORS.border, 0.15)

local titleBar = create("Frame", {
    Name = "DragHeader", BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 61)
}, panel)
text(titleBar, "NOVA  /  EMPIRE CLASH", UDim2.fromOffset(16, 9),
    UDim2.fromOffset(284, 22), 17, COLORS.white, true)
text(titleBar, "COMBAT INTELLIGENCE  •  NATIVE SHOTS UNCHANGED",
    UDim2.fromOffset(17, 34), UDim2.fromOffset(314, 16), 10, COLORS.secondary, true)
local close = press(titleBar, "×", UDim2.fromOffset(315, 11), UDim2.fromOffset(26, 27))
close.TextSize = 19
ownConnection(close.MouseButton1Click, function() panel.Visible = false end)

local scrolling = create("ScrollingFrame", {
    Name = "Options", Position = UDim2.fromOffset(12, 62),
    Size = UDim2.fromOffset(330, 309),
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
local advancedRows = {}
local captureAdvanced = false
local advancedOpen = false
local function heading(value)
    order += 1
    local l = text(scrolling, value, UDim2.new(), UDim2.new(1, -5, 0, 25),
        11, COLORS.secondary, true)
    l.LayoutOrder = order
    if captureAdvanced then
        l.Visible = advancedOpen
        table.insert(advancedRows, l)
    end
end
local function option(labelText, valueFn, action)
    order += 1
    local b = press(scrolling, "", UDim2.new(), UDim2.new(1, -8, 0, 33))
    b.LayoutOrder = order
    if captureAdvanced then
        b.Visible = advancedOpen
        table.insert(advancedRows, b)
    end
    local a = text(b, labelText, UDim2.fromOffset(10, 0), UDim2.new(0.65, 0, 1, 0),
        12, COLORS.white, false)
    local v = text(b, "", UDim2.new(0.66, 0, 0, 0), UDim2.new(0.30, 0, 1, 0),
        11, COLORS.clear, true)
    v.TextXAlignment = Enum.TextXAlignment.Right
    local refresh = function() v.Text = valueFn() end
    ownConnection(b.MouseButton1Click, function()
        action()
        clampConfig()
        -- Synchronise duplicate quick / advanced controls for the same setting.
        for _, render in ipairs(rows) do render() end
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
heading("QUICK CONTROLS")
option("Faction-coloured outlines", function()
    return config.Outline and "ON" or "OFF"
end, function() switch("Outline") end)
option("Names + disguise warnings", function()
    return config.Nametag and "ON" or "OFF"
end, function() switch("Nametag") end)
option("Selected target card", function()
    return config.TargetCard and "ON" or "OFF"
end, function() switch("TargetCard") end)
option("Visual aim guide", function()
    return config.AimMarker and "ON" or "OFF"
end, function() switch("AimMarker") end)
option("Weapon-specific guidance", function()
    return config.WeaponGuide and "ON" or "OFF"
end, function() switch("WeaponGuide") end)
option("Show targets through walls", function()
    return config.ThroughWalls and "ON" or "OFF"
end, function() switch("ThroughWalls") end)

order += 1
local advancedToggle = press(scrolling, "ADVANCED OPTIONS  ▼", UDim2.new(),
    UDim2.new(1, -8, 0, 38))
advancedToggle.LayoutOrder = order
advancedToggle.BackgroundColor3 = COLORS.dark
advancedToggle.TextColor3 = COLORS.white
advancedToggle.TextSize = 12
ownConnection(advancedToggle.MouseButton1Click, function()
    advancedOpen = not advancedOpen
    for _, item in ipairs(advancedRows) do item.Visible = advancedOpen end
    advancedToggle.Text = advancedOpen
        and "HIDE ADVANCED OPTIONS  ▲" or "ADVANCED OPTIONS  ▼"
    if not advancedOpen then scrolling.CanvasPosition = Vector2.new(0, 0) end
end)

-- Every original setting below remains available; details are collapsed by
-- default to keep routine use simple. Nothing is silently auto-enabled.
captureAdvanced = true
heading("COMBAT INTELLIGENCE")
option("Adaptive weapon guide", function()
    return config.WeaponGuide and "ON" or "OFF"
end, function() switch("WeaponGuide") end)
option("Read-only hit feedback", function()
    return config.ShotFeedback and "ON" or "OFF"
end, function() switch("ShotFeedback") end)
option("Weapon context on HUD", function()
    return config.ShowWeaponHint and "ON" or "OFF"
end, function() switch("ShowWeaponHint") end)
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
heading("FACTION IDENTIFICATION")
option("Actual faction beneath names", function()
    return config.FactionLabels and "ON" or "OFF"
end, function() switch("FactionLabels") end)
option("Thief disguise warnings", function()
    return config.DisguiseAlerts and "ON" or "OFF"
end, function() switch("DisguiseAlerts") end)
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
captureAdvanced = false

local status = text(panel, "NOVA GUIDE READY   •   v0.8",
    UDim2.fromOffset(16, 379), UDim2.fromOffset(320, 46), 11, COLORS.secondary)
status.TextWrapped = true
status.TextYAlignment = Enum.TextYAlignment.Top
local copy = press(panel, "COPY DETAILS", UDim2.fromOffset(15, 443), UDim2.fromOffset(190, 29))
local unload = press(panel, "UNLOAD", UDim2.fromOffset(217, 443), UDim2.fromOffset(121, 29))
-- Technical output remains accessible in Advanced; main view stays uncluttered.
copy.Visible = false
table.insert(advancedRows, copy)
ownConnection(advancedToggle.MouseButton1Click, function()
    copy.Visible = advancedOpen
end)

local targetCard = create("Frame", {
    Name = "SelectedTarget", Size = UDim2.fromOffset(292, 146),
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
local cardFaction = text(targetCard, "", UDim2.fromOffset(12, 82),
    UDim2.fromOffset(265, 21), 10, COLORS.white, true)
local cardGuide = text(targetCard, "", UDim2.fromOffset(12, 111),
    UDim2.fromOffset(265, 24), 10, COLORS.clear, true)
cardGuide.TextWrapped = true

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
    if not s or not s.sampledAt or os.clock() - s.sampledAt > 0.26 then
        return nil
    end
    local rec = registry[s.player]
    if not rec or rec.generation ~= s.generation or rec.character ~= s.character then return nil end
    if not characterParts(rec) then return nil end
    if config.TeamFilter and friendly(s.player) then return nil end
    if (getOwnOrigin() - s.point).Magnitude > config.MaxRange then return nil end
    if config.RequireVisible and s.clear ~= true then return nil end
    return s
end
local function getDiagnostics()
    local chosen = validSelection()
    return {
        product = "Empire Clash NOVA", version = VERSION, phase = "8A-F RELIABILITY BUILD",
        game_id = game.GameId, place_id = game.PlaceId,
        native_reticle_approximate = state.nativeReticle,
        weapon = state.weaponName, client_accuracy_raw = state.weaponAccuracy,
        selected_target_present = chosen ~= nil,
        selected_region = chosen and chosen.region or nil,
        selected_distance = chosen and math.floor(chosen.distance + 0.5) or nil,
        selected_pixel_error = chosen and math.floor(chosen.errorPixels + 0.5) or nil,
        selected_clear_path = chosen and chosen.clear or nil,
        selected_sample_age_ms = chosen and math.floor((os.clock() - chosen.sampledAt) * 1000) or nil,
        faction_outline_matches_nametag = true,
        selected_actual_faction = chosen and factionIdentity(chosen.player).actual or nil,
        selected_disguise_team = chosen and factionIdentity(chosen.player).disguise or nil,
        target_changes = state.changes, target_searches = state.searches,
        rejected_same_team = state.rejectedFriendlies,
        rejected_occluded = state.rejectedOccluded,
        measured_fps = state.fps,
        weapon_class = state.weaponClass,
        weapon_hint = state.weaponHint,
        weapon_guide_enabled = config.WeaponGuide,
        guide_status = state.guideStatus,
        generic_hit_feedback = state.genericHitFeedback,
        generic_damage_feedback = state.genericDamageFeedback,
        last_hit_feedback_at = state.lastHitAt,
        last_damage_feedback_at = state.lastDamageAt,
        feedback_status = state.feedbackStatus,
        sends_no_gameplay_remotes = true,
        modifies_no_firing_requests = true,
        uncalibrated_prediction_preview_only = true,
        guaranteed_headshots = false,
        server_hit_attribution_verified = false,
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
-- READ-ONLY COMBAT INTELLIGENCE
-- No remote calls, shot interception, camera mutation or input automation.
-- Generic damage feedback does not identify which target was hit.
-- ================================================================
local function guideForSelection(selection)
    if not config.WeaponGuide then return "GUIDANCE OFF" end
    if not selection then return "NO TARGET" end
    if selection.clear == false then return "LINE OF SIGHT BLOCKED" end
    if selection.clear == nil then return "VISIBILITY UNKNOWN" end
    local family = state.weaponClass
    if family == "UNARMED" or family == "UTILITY" then return "EQUIP COMBAT WEAPON" end
    if family == "CANNON" or family == "THROWN" then
        return "USE NATIVE TRAJECTORY / OBSTRUCTION GUIDE"
    end
    local tolerance = (family == "SPREAD" or family == "MELEE") and 20 or 10
    local errorPixels = math.floor(selection.errorPixels + 0.5)
    if errorPixels <= tolerance then
        if selection.region == "HEAD" then return "HEAD ALIGNED - HIT NOT GUARANTEED" end
        return "RETICLE ALIGNED - HIT NOT GUARANTEED"
    end
    return string.format("ALIGN RETICLE (%d px OFFSET)", errorPixels)
end

-- Optional client-observed event handlers. No shot is generated or modified.
local function attachFeedback()
    if not active or not config.ShotFeedback or state.feedbackAttached then return end
    local now = os.clock()
    if now - state.feedbackLastTry < 12 then return end
    state.feedbackLastTry = now
    local storage = game:GetService("ReplicatedStorage")
    local packages = storage:FindFirstChild("Packages")
    local module = packages and packages:FindFirstChild("Knit")
    if not module or not module:IsA("ModuleScript") then
        state.feedbackStatus = "NO KNIT CLIENT"
        return
    end
    local ok, Knit = pcall(require, module)
    if not ok or type(Knit) ~= "table" or type(Knit.GetService) ~= "function" then
        state.feedbackStatus = "NO SERVICE API"
        return
    end
    local hasService, service = pcall(function() return Knit.GetService("DamageService") end)
    if not hasService or not service then
        state.feedbackStatus = "NO DAMAGE SERVICE"
        return
    end
    local attached = 0
    local function observe(signal, name)
        if not signal or type(signal.Connect) ~= "function" then return end
        local connected, conn = pcall(function()
            return signal:Connect(function()
                if not active or not config.ShotFeedback then return end
                if name == "HIT" then
                    state.genericHitFeedback += 1
                    state.lastHitAt = os.clock()
                else
                    state.genericDamageFeedback += 1
                    state.lastDamageAt = os.clock()
                end
            end)
        end)
        if connected and conn then
            table.insert(conns, conn)
            attached += 1
        end
    end
    observe(service.SendHitmarker, "HIT")
    observe(service.ReportDamage, "DAMAGE")
    state.feedbackAttached = attached > 0
    state.feedbackStatus = state.feedbackAttached and "GENERIC ONLY" or "NO FEEDBACK SIGNALS"
end

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

    if now - state.lastSample >= 0.075 then
        state.lastSample = now
        local ok, err = pcall(function()
            state.weaponName, state.weaponAccuracy,
                state.weaponClass, state.weaponHint = currentWeapon()
            state.profiles += 1
            findTarget(state.reticle)
            attachFeedback()
        end)
        if ok then
            state.failure = nil
        else
            state.failure = tostring(err)
            state.selected, state.selection = nil, nil
        end
    end
    if now - state.nextVisuals >= 0.23 then
        state.nextVisuals = now
        local ok, err = pcall(updateVisuals)
        if not ok then state.failure = tostring(err) end
    end
    local selected = validSelection()
    state.guideStatus = guideForSelection(selected)
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
        cardTitle.Text = config.ShowWeaponHint
            and ("TARGET / " .. state.weaponClass) or "SELECTED TARGET"
        cardGuide.Text = state.guideStatus
        cardGuide.TextColor3 = selected.clear == true and COLORS.clear or COLORS.enemy
        local identity = factionIdentity(selected.player)
        cardName.TextColor3 = identity.color
        cardName.Text = selected.player.DisplayName
        cardFaction.TextColor3 = identity.pretendingOurTeam
            and COLORS.selected or COLORS.white
        cardFaction.Text = factionCaption(identity)
        cardData.Text = string.format("%s  |  %d HP  |  %d st  |  %s",
            selected.region, math.floor(selected.health + 0.5),
            math.floor(selected.distance + 0.5),
            selected.clear == true and "LOCAL CLEAR" or "BLOCKED / UNKNOWN")
    else
        aimMarker.Visible = false
        targetCard.Visible = false
    end
    if panel.Visible then
        local acc = state.weaponAccuracy and (" | raw accuracy " .. tostring(state.weaponAccuracy)) or ""
        status.Text = "NOVA v" .. VERSION .. " | " .. state.weaponName .. "\n"
            .. (config.ShowWeaponHint and state.guideStatus or state.weaponClass)
        if advancedOpen then
            status.Text = state.weaponClass .. acc .. " | " .. tostring(state.fps) .. " FPS\n"
                .. "GENERIC HIT / DAMAGE " .. tostring(state.genericHitFeedback) .. " / "
                .. tostring(state.genericDamageFeedback) .. " | " .. state.feedbackStatus
        end
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
print("[EC NOVA] Combat guide v" .. VERSION ..
    " running. RightShift = panel; native firing unchanged; no remotes sent.")
