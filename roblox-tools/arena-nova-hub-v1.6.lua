-- ARENA NOVA | Core + predictive bow aim | v1.6.0
-- Player outlines, clean player/loot labels, weapon reach, alerts, right-click aim and loot filters.
-- Client-side visual tools plus optional hold-right-click camera tracking; no server-state modification.
-- No gameplay remotes, diagnostics, perk actions, decompilation or file writes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

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
local VERSION = "1.6.0"
local settings = {
    outlines = true,
    names = true,
    reach = true,
    disasters = true,
    aim = true,
    loot = true,
}
for _, option in ipairs({ "outlines", "names", "reach", "disasters", "aim", "loot" }) do
    local fromTeleport = type(incomingOptions) == "table" and incomingOptions[option]
    local fromPrior = type(lastOptions) == "table" and lastOptions[option]
    if type(fromTeleport) == "boolean" then
        settings[option] = fromTeleport
    elseif type(fromPrior) == "boolean" then
        settings[option] = fromPrior
    end
end
local loadedHidden = if type(incomingOptions) == "table" then incomingOptions.lootHidden else nil
local previousHidden = if type(lastOptions) == "table" then lastOptions.lootHidden else nil
settings.lootHidden = if type(loadedHidden) == "string" then loadedHidden
    else if type(previousHidden) == "string" then previousHidden else ""
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

-- Hold LEFT ALT to lock the opponent nearest the centre of the viewport.
-- For Bow/Wooden Bow, lead the moving target using live charge, projectile
-- launch speed and gravity from the game's actual Ballistics and Weapons code.
-- The native Ballistics.aimVelocity solver handles gravity once; we supply
-- a FUTURE target position, NOT an already-compensated pitch.
-- CameraRig.aimPoint is the shot-origin aim source used by ShotIntent, so an
-- optional reversible wrapper aligns real shot intent with predictive camera.
local AIM_BIND = "ArenaNovaAim_" .. tostring(player.UserId)
local AIM_PRIORITY = Enum.RenderPriority.Camera.Value + 4
local AIM_RESPONSE = 29
local AIM_TRACKED_SPEED_MAX = 88
local AIM_LATENCY_SECONDS = 0.045
local AIM_MAX_FLIGHT_SECONDS = 2.8
local aimBound = false
local aimTarget = nil
local aimHeldLastFrame = false
local aimPredictedPoint = nil
local aimMotion = {target=nil,part=nil,lastPosition=nil,lastAt=nil,velocity=Vector3.zero}
local aimRig = nil
local aimRigOriginal = nil
local aimRigWrapper = nil
local aimBindEpoch = 0
local aimRigConnected = false

local function clearAimTarget()
    aimTarget = nil
    aimPredictedPoint = nil
    aimHeldLastFrame = false
    aimMotion.target = nil
    aimMotion.part = nil
    aimMotion.lastPosition = nil
    aimMotion.lastAt = nil
    aimMotion.velocity = Vector3.zero
end

local function aimBodyPart(target)
    if not target or target == player or target.Parent ~= Players then
        return nil, nil
    end
    local character = target.Character
    if not character or not character:IsDescendantOf(Workspace) then
        return nil, nil
    end
    local stats = character:FindFirstChild("CombatStats")
    if stats then
        local health = stats:GetAttribute("Health")
        if type(health) == "number" and health <= 0 then
            return nil, nil
        end
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then
        return nil, nil
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        -- More forgiving bow target: centre-mass rather than the head.
        return root, root.Position + Vector3.new(0, 0.65, 0)
    end
    local head = character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        return head, head.Position
    end
    return nil, nil
end

local function onScreenAimPoint(camera, target)
    local _, point = aimBodyPart(target)
    if not point then return nil, nil end
    local projection, visible = camera:WorldToViewportPoint(point)
    if not visible or projection.Z <= 0 then return nil, nil end
    return point, projection
end

local function closestToCrosshair(camera)
    local size = camera.ViewportSize
    local cx, cy = size.X * 0.5, size.Y * 0.5
    local winner, bestPixels2 = nil, math.huge
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then
            local point, screen = onScreenAimPoint(camera, other)
            if point then
                local dx, dy = screen.X - cx, screen.Y - cy
                local pixels2 = dx*dx + dy*dy
                if pixels2 < bestPixels2 then
                    winner, bestPixels2 = other, pixels2
                end
            end
        end
    end
    return winner
end

local function getBowRanged()
    local character = player.Character
    local stats = character and character:FindFirstChild("CombatStats")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not stats or not root or not root:IsA("BasePart") then
        return nil, nil
    end
    local itemId = stats:GetAttribute("Equipped")
    if itemId ~= "Bow" and itemId ~= "Wooden Bow" then
        return nil, nil
    end
    local ranged = nil
    if weaponsModule and type(weaponsModule.get) == "function" then
        local ok, weapon = pcall(weaponsModule.get, itemId)
        if ok and type(weapon) == "table" and type(weapon.ranged) == "table" then
            ranged = weapon.ranged
        end
    end
    -- Source-backed fallbacks when the live Weapons module isn't available.
    if not ranged then
        ranged = {
            range = if itemId == "Bow" then 500 else 450,
            gravity = 1/3,
            chargeTime = 1.2,
        }
    end
    return ranged, root
end

local function bowLaunchSpeed(ranged, root)
    -- Shared.combat.Ballistics.charge uses smoothstep(drawTime / chargeTime).
    local charge = 1
    local drawing = root:GetAttribute("Drawing") == true
    local drawAt = root:GetAttribute("DrawAt")
    if drawing and type(drawAt) == "number"
        and type(ranged.chargeTime) == "number" and ranged.chargeTime > 0 then
        local elapsed = Workspace:GetServerTimeNow() - drawAt
        local fraction = math.clamp(elapsed / ranged.chargeTime, 0, 1)
        charge = fraction * fraction * (3 - 2*fraction)
    else
        local previousCharge = root:GetAttribute("ReleaseCharge")
        if type(previousCharge) == "number" then
            charge = math.clamp(previousCharge, 0, 1)
        end
    end
    local baseSpeed = if type(ranged.range) == "number" then ranged.range else 500
    return baseSpeed * (0.5 + 0.5*charge)
end

local function smoothedAimVelocity(target, part, dt)
    local now = os.clock()
    if aimMotion.target ~= target or aimMotion.part ~= part then
        aimMotion.target = target
        aimMotion.part = part
        aimMotion.lastPosition = part.Position
        aimMotion.lastAt = now
        aimMotion.velocity = part.AssemblyLinearVelocity
        return aimMotion.velocity
    end
    local observed = part.AssemblyLinearVelocity
    local elapsed = now - (aimMotion.lastAt or now)
    if aimMotion.lastPosition and elapsed > 0.009 and elapsed < 0.22 then
        local fromPosition = (part.Position - aimMotion.lastPosition) / elapsed
        if fromPosition.Magnitude < AIM_TRACKED_SPEED_MAX then
            -- Coordinate movement tends to be more stable than packet velocity
            -- for remote characters but can be noisy at low frame rates.
            observed = observed * 0.38 + fromPosition * 0.62
        end
    end
    aimMotion.lastPosition = part.Position
    aimMotion.lastAt = now
    if observed.Magnitude > AIM_TRACKED_SPEED_MAX then
        observed = observed.Unit * AIM_TRACKED_SPEED_MAX
    end
    local alpha = 1 - math.exp(-13 * math.clamp(dt, 0, 0.1))
    aimMotion.velocity = aimMotion.velocity:Lerp(observed, alpha)
    return aimMotion.velocity
end

-- Low-arc ballistic solution for a stationary predicted point. This obtains
-- the travel time; the game's own Ballistics module generates final pitch.
local function bowFlightTime(origin, destination, speed, gravity)
    local displacement = destination - origin
    local flat = Vector3.new(displacement.X, 0, displacement.Z).Magnitude
    if speed < 1 then return nil end
    if flat < 0.01 then return math.abs(displacement.Y) / speed end
    if gravity <= 0.01 then
        return displacement.Magnitude / speed
    end
    local speed2 = speed*speed
    local discriminant = speed2*speed2
        - gravity*(gravity*flat*flat + 2*displacement.Y*speed2)
    if discriminant < 0 then return nil end
    local theta = math.atan((speed2-math.sqrt(discriminant))/(gravity*flat))
    local horizontalSpeed = speed*math.cos(theta)
    if horizontalSpeed <= 0.01 then return nil end
    return flat/horizontalSpeed
end

local function bowLeadPoint(part, location, ranged, root, dt)
    local speed = bowLaunchSpeed(ranged, root)
    local gravityMultiplier = if type(ranged.gravity) == "number"
        then ranged.gravity else 1/3
    local gravity = Workspace.Gravity * gravityMultiplier
    local velocity = smoothedAimVelocity(aimTarget, part, dt)
    local origin = root.Position
    local travelTime = bowFlightTime(origin, location, speed, gravity)
    if not travelTime then return location end
    -- Solve the future position, re-evaluating time at each iteration.
    local predicted = location
    for _ = 1, 3 do
        travelTime = math.clamp(travelTime, 0, AIM_MAX_FLIGHT_SECONDS)
        predicted = location + velocity * (travelTime + AIM_LATENCY_SECONDS)
        local nextTime = bowFlightTime(origin, predicted, speed, gravity)
        if not nextTime then break end
        travelTime = nextTime
    end
    return predicted
end

-- ShotIntent and the client ghost-projectile path call CameraRig.aimPoint().
-- Modify that shared aim-point accessor only while LeftAlt is held on a bow.
local function restoreAimRig()
    if aimRig and aimRigWrapper and aimRigOriginal then
        pcall(function()
            if aimRig.aimPoint == aimRigWrapper then
                aimRig.aimPoint = aimRigOriginal
            end
        end)
    end
    aimRig, aimRigOriginal, aimRigWrapper = nil, nil, nil
    aimRigConnected = false
end

local function bindAimRig(epoch)
    if aimRigConnected then return true end
    local scripts = player:FindFirstChild("PlayerScripts")
    local common = scripts and scripts:FindFirstChild("common")
    local cameraFolder = common and common:FindFirstChild("camera")
    local source = cameraFolder and cameraFolder:FindFirstChild("CameraRig")
    if not source or not source:IsA("ModuleScript") then
        return false
    end
    local success, rig = pcall(require, source)
    if not success or type(rig) ~= "table" or type(rig.aimPoint) ~= "function" then
        return false
    end
    if not running or not settings.aim or epoch ~= aimBindEpoch then
        return false
    end
    local original = rig.aimPoint
    local wrapped = function(...)
        if running and settings.aim and aimHeldLastFrame and aimTarget
            and typeof(aimPredictedPoint) == "Vector3"
            and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
            and not UserInputService:GetFocusedTextBox() then
            return aimPredictedPoint
        end
        return original(...)
    end
    local installed = pcall(function()
        rig.aimPoint = wrapped
    end)
    if not installed or rig.aimPoint ~= wrapped then
        return false
    end
    aimRig, aimRigOriginal, aimRigWrapper = rig, original, wrapped
    aimRigConnected = true
    return true
end

local function stopAim()
    aimBindEpoch += 1
    if aimBound then
        pcall(function()
            RunService:UnbindFromRenderStep(AIM_BIND)
        end)
        aimBound = false
    end
    clearAimTarget()
    restoreAimRig()
end

local function startAim()
    if aimBound then return end
    clearAimTarget()
    aimBindEpoch += 1
    local epoch = aimBindEpoch
    -- Binding CameraRig may need its module to finish starting. Do it away
    -- from the render thread, and cancel cleanly on toggle off/unload.
    task.spawn(function()
        for _ = 1, 12 do
            if not running or not settings.aim or epoch ~= aimBindEpoch then return end
            if bindAimRig(epoch) then return end
            task.wait(1)
        end
    end)
    local ok = pcall(function()
        RunService:BindToRenderStep(AIM_BIND, AIM_PRIORITY, function(dt)
            if not running or not settings.aim then return end
            -- No longer uses RMB, which remains entirely game-controlled.
            local alt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
            if not alt or UserInputService:GetFocusedTextBox() then
                clearAimTarget()
                return
            end
            local camera = Workspace.CurrentCamera
            if not camera then
                clearAimTarget()
                return
            end
            local point = nil
            if aimHeldLastFrame and aimTarget then
                point = onScreenAimPoint(camera, aimTarget)
            end
            if not point then
                aimTarget = closestToCrosshair(camera)
                if aimTarget then point = onScreenAimPoint(camera, aimTarget) end
                -- A newly acquired target must not reuse previous target velocity.
                aimMotion.target = nil
            end
            aimHeldLastFrame = true
            if not point or not aimTarget then
                aimPredictedPoint = nil
                return
            end
            local part, base = aimBodyPart(aimTarget)
            if not part or not base then
                aimPredictedPoint = nil
                return
            end
            local ranged, root = getBowRanged()
            local aimPoint = base
            if ranged and root then
                aimPoint = bowLeadPoint(part, base, ranged, root, dt)
                aimPredictedPoint = aimPoint
            else
                aimPredictedPoint = nil
            end
            local current = camera.CFrame
            if (aimPoint - current.Position).Magnitude < 0.05 then return end
            local desired = CFrame.lookAt(current.Position, aimPoint)
            local alpha = 1 - math.exp(-AIM_RESPONSE * math.clamp(dt, 0, 0.1))
            camera.CFrame = current:Lerp(desired, alpha)
        end)
    end)
    aimBound = ok
end

-- This reads the game's existing loot CollectionService tags, with no remote
-- requests and no broad Workspace.Descendants scanning. Rendering is capped.
local LOOT_GROUPS = {
    {name="WEAPONS",kind="Weapon",ids={"Falchions","Knife","Katana","Sword","Hammer","Mace","Stone-Headed Axe","Flail","Battle Axe","Hatchet","Trident","Spear","Stone-Tipped Spear","Bow","Wooden Bow","Blow Gun","Wooden Blow Gun","Kunai","Pickaxe"}},
    {name="FOOD & HEALING",kind="Consumable",ids={"Apple","Blackberry","Blueberry","Darkberry","Grape","Bread","Coconut","Cooked Meat","Corn","Crab","Raw Meat","Mushroom","Bandage","Medicine","Bottle","Poison Bottle"}},
    {name="RESOURCES",kind="Resource",ids={"Firewood","Stone","Herb","Bone"}},
    {name="AMMO",kind="Ammo",ids={"Arrows","Wooden Arrows","Darts","Bone Darts"}},
    {name="UTILITIES",kind="Utility",ids={"Disguise","Torch","Wooden Torch"}},
    {name="UPGRADES",kind="Upgrade",ids={"Backpack"}},
    {name="CRATES",kind="Crate",ids={"__Crate"}},
    {name="OTHER",kind="Other",ids={"__Other"}},
}
local LOOT_COLORS = {
    Weapon=Color3.fromRGB(240,191,105),
    Consumable=Color3.fromRGB(118,212,161),
    Resource=Color3.fromRGB(118,181,224),
    Ammo=Color3.fromRGB(168,182,202),
    Utility=Color3.fromRGB(151,196,225),
    Upgrade=Color3.fromRGB(188,159,233),
    Crate=Color3.fromRGB(225,173,124),
    Other=Color3.fromRGB(186,199,213),
}
local lootKinds = {}
for _, group in ipairs(LOOT_GROUPS) do
    for _, id in ipairs(group.ids) do
        lootKinds[id] = group.kind
    end
end
local lootExcluded = {}
for id in string.gmatch(settings.lootHidden, "[^|]+") do
    if lootKinds[id] then lootExcluded[id] = true end
end
local function saveLootFilter()
    local names = {}
    for id, disabled in pairs(lootExcluded) do
        if disabled and lootKinds[id] then table.insert(names,id) end
    end
    table.sort(names)
    settings.lootHidden = table.concat(names,"|")
end
local lootEntries = {}
local taggedLoot = {Highlightable={}, Crate={}}
local lootSignals = {}
local lootFolder = nil
local lootUpdate = nil
local lootItemRows = nil
local LOOT_CAP = 64
local LOOT_LABEL_CAP = 22
local LOOT_LABEL_DISTANCE = 150

local function readLootItems()
    if lootItemRows then return end
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local constants = shared and shared:FindFirstChild("constants")
    local mod = constants and constants:FindFirstChild("Items")
    if mod and mod:IsA("ModuleScript") then
        local ok, value = pcall(require, mod)
        if ok and type(value) == "table" and type(value.rows) == "table" then
            lootItemRows = value.rows
        end
    end
end
local function getLootPart(entry)
    if entry.part and entry.part.Parent and entry.part:IsDescendantOf(entry.model) then
        return entry.part
    end
    local model = entry.model
    local part = model.PrimaryPart
    if not part or not part:IsA("BasePart") then
        part = model:FindFirstChildWhichIsA("BasePart",true)
    end
    entry.part = part
    return part
end
local function identifyLoot(entry)
    local model = entry.model
    if entry.crates > 0 then
        local size = model:GetAttribute("Size")
        return "__Crate", (if type(size) == "string" and size ~= ""
            then size.." Crate" else "Crate"), "Crate"
    end
    local raw = model:GetAttribute("ItemId") or model:GetAttribute("LootId")
        or model:GetAttribute("Id")
    if type(raw) ~= "string" or raw == "" then raw = model.Name end
    local id = if lootKinds[raw] then raw else "__Other"
    local prompt = model:FindFirstChildWhichIsA("ProximityPrompt",true)
    if id == "__Other" and prompt and lootKinds[prompt.ObjectText] then
        id = prompt.ObjectText
    end
    local kind = lootKinds[id] or "Other"
    local row = lootItemRows and lootItemRows[raw]
    local display = if type(row) == "table" and type(row.displayName) == "string"
        then row.displayName
        else if id ~= "__Other" then id
        else if prompt and prompt.ObjectText ~= "" then prompt.ObjectText
        else if raw == "Model" or raw == "Loot" then "Loot" else raw
    return id, tostring(display):gsub("_"," "), kind
end
local function clearLootEntry(entry)
    if entry.fade then entry.fade:Cancel(); entry.fade = nil end
    if entry.highlight then entry.highlight:Destroy(); entry.highlight = nil end
    if entry.billboard then entry.billboard:Destroy(); entry.billboard = nil end
    entry.label = nil
    entry.showingLabel = false
    entry.drawnId = nil
    entry.drawnPart = nil
    entry.drawnText = nil
end
local function removeLootEntry(model)
    local entry = lootEntries[model]
    if entry then
        clearLootEntry(entry)
        lootEntries[model] = nil
    end
end
local function attachLootVisual(entry, part, id, display, kind)
    if entry.highlight and entry.billboard and entry.drawnPart == part
        and entry.drawnId == id and entry.drawnText == display then return end
    clearLootEntry(entry)
    local color = LOOT_COLORS[kind] or LOOT_COLORS.Other
    entry.highlight = create("Highlight",lootFolder,{
        Name="ArenaNovaLoot",Adornee=entry.model,
        DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
        OutlineColor=color,OutlineTransparency=0.18,
        FillColor=color,FillTransparency=1,Enabled=true,
    })
    entry.billboard = create("BillboardGui",playerGui,{
        Name="ArenaNovaLootLabel",Adornee=part,
        Size=UDim2.fromOffset(150,20),StudsOffsetWorldSpace=Vector3.new(0,1.05,0),
        AlwaysOnTop=true,LightInfluence=0,MaxDistance=0,ResetOnSpawn=false,
    })
    entry.label = create("TextLabel",entry.billboard,{
        BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),
        Text=string.upper(display),Font=Enum.Font.GothamMedium,
        TextSize=11,TextScaled=false,TextTruncate=Enum.TextTruncate.AtEnd,
        TextXAlignment=Enum.TextXAlignment.Center,
        TextColor3=color,TextStrokeColor3=Color3.fromRGB(8,11,20),
        TextTransparency=1,TextStrokeTransparency=1,
    })
    entry.showingLabel = false
    entry.drawnId = id
    entry.drawnPart = part
    entry.drawnText = display
end
local function labelLoot(entry, show)
    if not entry.label or entry.showingLabel == show then return end
    entry.showingLabel = show
    if entry.fade then entry.fade:Cancel() end
    entry.fade = TweenService:Create(entry.label,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{
        TextTransparency=if show then 0 else 1,
        TextStrokeTransparency=if show then 0.66 else 1,
    })
    entry.fade:Play()
end
local function onLootTagged(instance, tag)
    if taggedLoot[tag][instance] then return end
    local model = if instance:IsA("Model") then instance else instance:FindFirstAncestorOfClass("Model")
    if not model then return end
    taggedLoot[tag][instance] = model
    local entry = lootEntries[model]
    if not entry then
        entry = {model=model, sources=0, crates=0}
        lootEntries[model] = entry
    end
    entry.sources += 1
    if tag == "Crate" then entry.crates += 1 end
end
local function onLootUntagged(instance, tag)
    local model = taggedLoot[tag][instance]
    if not model then return end
    taggedLoot[tag][instance] = nil
    local entry = lootEntries[model]
    if not entry then return end
    entry.sources -= 1
    if tag == "Crate" then entry.crates = math.max(0,entry.crates - 1) end
    if entry.sources <= 0 then removeLootEntry(model) else clearLootEntry(entry) end
end
local function refreshLootESP()
    if not running or not settings.loot or not lootFolder then return end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local camera = Workspace.CurrentCamera
    local origin = if root and root:IsA("BasePart") then root.Position
        else if camera then camera.CFrame.Position else nil
    if not origin or game.PlaceId == 72238253016204 then
        for _, entry in pairs(lootEntries) do clearLootEntry(entry) end
        return
    end
    local candidates = {}
    for _, entry in pairs(lootEntries) do
        if entry.sources > 0 and entry.model:IsDescendantOf(Workspace) then
            local id, label, kind = identifyLoot(entry)
            local part = getLootPart(entry)
            if part and part:IsDescendantOf(Workspace) and not lootExcluded[id] then
                local distance = (part.Position - origin).Magnitude
                table.insert(candidates,{
                    entry=entry,part=part,id=id,label=label,kind=kind,distance=distance,
                })
            else
                clearLootEntry(entry)
            end
        else
            clearLootEntry(entry)
        end
    end
    table.sort(candidates,function(a,b)
        local ad = a.distance * (if a.entry.highlight then 0.96 else 1)
        local bd = b.distance * (if b.entry.highlight then 0.96 else 1)
        return ad < bd
    end)
    local labels = 0
    for index, item in ipairs(candidates) do
        if index <= LOOT_CAP then
            attachLootVisual(item.entry,item.part,item.id,item.label,item.kind)
            local show = labels < LOOT_LABEL_CAP and item.distance < LOOT_LABEL_DISTANCE
            if show then labels += 1 end
            labelLoot(item.entry,show)
        else
            clearLootEntry(item.entry)
        end
    end
end
local function stopLootESP()
    if lootUpdate then lootUpdate:Disconnect(); lootUpdate = nil end
    disconnectAll(lootSignals)
    for _, entry in pairs(lootEntries) do clearLootEntry(entry) end
    table.clear(lootEntries)
    for _, map in pairs(taggedLoot) do table.clear(map) end
    if lootFolder then lootFolder:Destroy(); lootFolder = nil end
end
local function startLootESP()
    if lootFolder then return end
    readLootItems()
    lootFolder = create("Folder",Workspace,{Name="ArenaNovaLootESP"})
    for _, tag in ipairs({"Highlightable","Crate"}) do
        connect(CollectionService:GetInstanceAddedSignal(tag),function(object)
            onLootTagged(object,tag)
        end,lootSignals)
        connect(CollectionService:GetInstanceRemovedSignal(tag),function(object)
            onLootUntagged(object,tag)
        end,lootSignals)
        for _, object in ipairs(CollectionService:GetTagged(tag)) do
            onLootTagged(object,tag)
        end
    end
    refreshLootESP()
    local elapsed = 0
    lootUpdate = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= 0.4 then
            elapsed = 0
            refreshLootESP()
        end
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
    Size = UDim2.fromOffset(354, 422),
    Position = UDim2.new(0.5, -177, 0.5, -211),
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
    Size = UDim2.new(1, -28, 0, 325),
    Visible = true,
})
local toggleUI = {}
local definitions = {
    {key = "outlines", label = "PLAYER OUTLINES"},
    {key = "names", label = "PLAYER NAMETAGS"},
    {key = "reach", label = "WEAPON REACH"},
    {key = "disasters", label = "DISASTER ALERTS"},
    {key = "aim", label = "LEFT ALT AIM · BOW"},
    {key = "loot", label = "LOOT ESP    ·    G"},
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



-- LOOT FILTER: an integrated dropdown with item-by-item multi-select,
-- grouped bulk toggles, search and small state indicators.
local filterButton = create("TextButton",toggleUI.loot.button,{
    Name="LootFilterButton",
    Position=UDim2.new(1,-165,0.5,-13),
    Size=UDim2.fromOffset(85,26),
    BackgroundColor3=palette.panel,
    BorderSizePixel=0,
    Text="ALL  ▾",
    TextColor3=palette.white,
    Font=Enum.Font.GothamBold,
    TextSize=10,
    AutoButtonColor=false,
    Active=true,
    ZIndex=6,
})
makeCorner(filterButton,6)
toggleUI.loot.text.Size = UDim2.new(1,-181,1,0)

local filterPopup = create("Frame",main,{
    Name="LootFilterDropdown",
    BackgroundColor3=palette.panel,
    Position=UDim2.fromOffset(14,84),
    Size=UDim2.new(1,-28,0,287),
    BorderSizePixel=0,
    Active=true,
    Visible=false,
    ZIndex=40,
})
makeCorner(filterPopup,9)
makeStroke(filterPopup,palette.border,0.12)
create("TextLabel",filterPopup,{
    BackgroundTransparency=1,
    Position=UDim2.fromOffset(13,8),
    Size=UDim2.new(1,-54,0,23),
    Text="LOOT FILTER",
    TextColor3=palette.white,
    Font=Enum.Font.GothamBold,
    TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=41,
})
local filterClose = create("TextButton",filterPopup,{
    BackgroundColor3=palette.surface,
    BorderSizePixel=0,
    Position=UDim2.new(1,-36,0,8),
    Size=UDim2.fromOffset(26,25),
    Text="×",
    TextColor3=palette.white,
    Font=Enum.Font.GothamMedium,
    TextSize=17,
    AutoButtonColor=false,
    ZIndex=42,
})
makeCorner(filterClose,5)
local filterSearch = create("TextBox",filterPopup,{
    Name="FindLoot",
    BackgroundColor3=palette.surface,
    BorderSizePixel=0,
    Position=UDim2.fromOffset(10,40),
    Size=UDim2.new(1,-20,0,29),
    PlaceholderText="Search for an item...",
    PlaceholderColor3=palette.muted,
    Text="",
    TextColor3=palette.white,
    Font=Enum.Font.Gotham,
    TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left,
    ClearTextOnFocus=false,
    ZIndex=42,
})
makeCorner(filterSearch,6)
create("UIPadding",filterSearch,{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
local filterAll = create("TextButton",filterPopup,{
    Name="SelectAll",
    BackgroundColor3=palette.surface,
    BorderSizePixel=0,
    Position=UDim2.fromOffset(10,76),
    Size=UDim2.fromOffset(147,26),
    Text="SELECT ALL",
    TextColor3=palette.muted,
    Font=Enum.Font.GothamBold,
    TextSize=10,
    AutoButtonColor=false,
    ZIndex=42,
})
makeCorner(filterAll,5)
local filterNone = create("TextButton",filterPopup,{
    Name="ClearAll",
    BackgroundColor3=palette.surface,
    BorderSizePixel=0,
    Position=UDim2.new(1,-157,0,76),
    Size=UDim2.fromOffset(147,26),
    Text="CLEAR ALL",
    TextColor3=palette.muted,
    Font=Enum.Font.GothamBold,
    TextSize=10,
    AutoButtonColor=false,
    ZIndex=42,
})
makeCorner(filterNone,5)
local filterScroll = create("ScrollingFrame",filterPopup,{
    Name="LootChoices",
    BackgroundTransparency=1,
    BorderSizePixel=0,
    Position=UDim2.fromOffset(9,109),
    Size=UDim2.new(1,-18,0,169),
    ScrollBarThickness=3,
    ScrollBarImageColor3=palette.border,
    CanvasSize=UDim2.fromOffset(0,0),
    ZIndex=42,
})
local filterLayout = create("UIListLayout",filterScroll,{
    SortOrder=Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,3),
})
local filterGroupRows = {}
local filterExpanded = {}
local updateLootFilterUI

for groupIndex,group in ipairs(LOOT_GROUPS) do
    local groupData = {group=group,items={}}
    filterExpanded[group.kind] = false
    local headerRow = create("TextButton",filterScroll,{
        Name=group.kind.."_All",
        BackgroundColor3=palette.surface,
        BorderSizePixel=0,
        Size=UDim2.new(1,-7,0,29),
        LayoutOrder=groupIndex*100,
        Text="",
        AutoButtonColor=false,
        ZIndex=43,
    })
    makeCorner(headerRow,5)
    create("Frame",headerRow,{
        BackgroundColor3=LOOT_COLORS[group.kind],
        BorderSizePixel=0,
        Position=UDim2.fromOffset(9,10),
        Size=UDim2.fromOffset(7,7),
        ZIndex=44,
    })
    create("TextLabel",headerRow,{
        BackgroundTransparency=1,
        Position=UDim2.fromOffset(23,0),
        Size=UDim2.new(1,-104,1,0),
        Text=group.name,
        TextColor3=palette.white,
        Font=Enum.Font.GothamMedium,
        TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
        ZIndex=44,
    })
    local counter = create("TextLabel",headerRow,{
        BackgroundTransparency=1,
        Position=UDim2.new(1,-77,0,0),
        Size=UDim2.fromOffset(47,29),
        Text="",
        TextColor3=palette.muted,
        Font=Enum.Font.Gotham,
        TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Right,
        ZIndex=44,
    })
    local expand = create("TextButton",headerRow,{
        BackgroundTransparency=1,
        Position=UDim2.new(1,-30,0,0),
        Size=UDim2.fromOffset(29,29),
        Text="▸",
        TextColor3=palette.muted,
        Font=Enum.Font.GothamBold,
        TextSize=14,
        AutoButtonColor=false,
        ZIndex=45,
    })
    groupData.header=headerRow
    groupData.counter=counter
    groupData.expand=expand
    connect(headerRow.Activated,function()
        local anyDisabled=false
        for _,id in ipairs(group.ids) do
            if lootExcluded[id] then anyDisabled=true;break end
        end
        for _,id in ipairs(group.ids) do
            lootExcluded[id]=if anyDisabled then nil else true
        end
        saveLootFilter()
        refreshLootESP()
        if updateLootFilterUI then updateLootFilterUI() end
    end)
    connect(expand.Activated,function()
        filterExpanded[group.kind]=not filterExpanded[group.kind]
        if updateLootFilterUI then updateLootFilterUI() end
    end)
    for itemIndex,id in ipairs(group.ids) do
        local display=if id=="__Crate" then "Crates"
            else if id=="__Other" then "Other loot"
            else id
        local row=create("TextButton",filterScroll,{
            Name="Choice_"..id,
            BackgroundColor3=Color3.fromRGB(26,30,41),
            BorderSizePixel=0,
            Size=UDim2.new(1,-7,0,25),
            LayoutOrder=groupIndex*100+itemIndex,
            Text="",
            Visible=false,
            AutoButtonColor=false,
            ZIndex=43,
        })
        makeCorner(row,5)
        create("TextLabel",row,{
            BackgroundTransparency=1,
            Position=UDim2.fromOffset(18,0),
            Size=UDim2.new(1,-61,1,0),
            Text=display,
            TextColor3=palette.white,
            Font=Enum.Font.Gotham,
            TextSize=11,
            TextXAlignment=Enum.TextXAlignment.Left,
            ZIndex=44,
        })
        local check=create("TextLabel",row,{
            BackgroundColor3=palette.accent,
            BorderSizePixel=0,
            Position=UDim2.new(1,-29,0.5,-9),
            Size=UDim2.fromOffset(19,18),
            Text="✓",
            TextColor3=palette.panel,
            Font=Enum.Font.GothamBold,
            TextSize=11,
            ZIndex=44,
        })
        makeCorner(check,5)
        table.insert(groupData.items,{id=id,name=display,row=row,check=check})
        connect(row.Activated,function()
            lootExcluded[id]=if lootExcluded[id] then nil else true
            saveLootFilter()
            refreshLootESP()
            if updateLootFilterUI then updateLootFilterUI() end
        end)
    end
    table.insert(filterGroupRows,groupData)
end
updateLootFilterUI=function()
    local term=string.lower(filterSearch.Text)
    term=term:match("^%s*(.-)%s*$") or ""
    local total,selected=0,0
    for _,group in ipairs(LOOT_GROUPS) do
        for _,id in ipairs(group.ids) do
            total+=1
            if not lootExcluded[id] then selected+=1 end
        end
    end
    filterButton.Text=if selected==total then "ALL  ▾"
        else tostring(selected).."/"..tostring(total).."  ▾"
    for _,widget in ipairs(filterGroupRows) do
        local enabled=0
        local matched=0
        local groupMatch=term=="" or string.find(string.lower(widget.group.name),term,1,true)~=nil
        for _,item in ipairs(widget.items) do
            if not lootExcluded[item.id] then enabled+=1 end
            local matches=groupMatch or string.find(string.lower(item.name),term,1,true)~=nil
            if matches then matched+=1 end
            item.row.Visible=matches and (filterExpanded[widget.group.kind] or term~="")
            item.check.Text=if lootExcluded[item.id] then "–" else "✓"
            item.check.BackgroundColor3=if lootExcluded[item.id] then palette.border else palette.accent
            item.check.TextColor3=if lootExcluded[item.id] then palette.white else palette.panel
        end
        widget.header.Visible=matched>0 or term==""
        widget.counter.Text=tostring(enabled).."/"..tostring(#widget.items)
        widget.expand.Text=if filterExpanded[widget.group.kind] or term~="" then "▾" else "▸"
    end
end
connect(filterLayout:GetPropertyChangedSignal("AbsoluteContentSize"),function()
    filterScroll.CanvasSize=UDim2.fromOffset(0,filterLayout.AbsoluteContentSize.Y+9)
end)
connect(filterSearch:GetPropertyChangedSignal("Text"),function()
    updateLootFilterUI()
end)
connect(filterButton.Activated,function()
    filterPopup.Visible=not filterPopup.Visible
    if filterPopup.Visible then updateLootFilterUI() end
end)
connect(filterClose.Activated,function()
    filterPopup.Visible=false
end)
connect(filterAll.Activated,function()
    table.clear(lootExcluded)
    saveLootFilter()
    refreshLootESP()
    updateLootFilterUI()
end)
connect(filterNone.Activated,function()
    for id in pairs(lootKinds) do lootExcluded[id]=true end
    saveLootFilter()
    refreshLootESP()
    updateLootFilterUI()
end)
updateLootFilterUI()

-- Core-only build: no experimental combat/stamina/knockback hooks,
-- no perk manipulation, and no speculative resource or immunity controls.
local footer = create("Frame", main, {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(15, 393),
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
    elseif key == "aim" then
        if value then
            startAim()
        else
            stopAim()
        end
    elseif key == "loot" then
        if value then
            startLootESP()
        else
            stopLootESP()
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
        if not visible then filterPopup.Visible = false end
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
    elseif input.KeyCode == Enum.KeyCode.G and not processed then
        setOption("loot",not settings.loot)
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
    stopLootESP()
    stopAim()
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
                "{outlines=%s,names=%s,reach=%s,disasters=%s,aim=%s,loot=%s,lootHidden=%q}",
                tostring(settings.outlines),
                tostring(settings.names),
                tostring(settings.reach),
                tostring(settings.disasters),
                tostring(settings.aim),
                tostring(settings.loot),
                settings.lootHidden
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
if settings.aim then
    startAim()
end
if settings.loot then
    startLootESP()
end
print("[ARENA NOVA] Core-only v" .. VERSION .. " loaded. Right Shift opens/closes the hub.")
