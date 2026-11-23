-- EMPIRE CLASH NOVA | Combat Foundation v0.1.0
-- Client-side target/visual assistant. Does NOT modify firing rays, hitboxes,
-- network calls, weapon timing, damage, server state, or anti-cheat.
-- Research base: 2026-11-23 Runespire WeaponController + FirearmAccuracy audit.
local UNIVERSE_ID = 3569141441
local VERSION = "0.1.0"
if game.GameId ~= UNIVERSE_ID then
    warn("[EC NOVA] Not Empire Clash. No changes made.")
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local env = (type(getgenv) == "function" and getgenv()) or _G

if env.ECNovaCombat and type(env.ECNovaCombat.Shutdown) == "function" then
    pcall(env.ECNovaCombat.Shutdown)
end

local SAVE_PATH = "EC_NOVA_COMBAT_SETTINGS.json"
local config = {
    Outlines = true,
    Nametags = true,
    TargetMarker = true,
    FirePoint = true,
    FOVRing = true,
    ThroughWalls = false,
    IgnoreFriendlies = true,
    FOV = 180,
    MaxRange = 550
}
local function loadConfig()
    if type(readfile) ~= "function" then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SAVE_PATH)) end)
    if ok and type(data) == "table" then
        for k, original in pairs(config) do
            if type(data[k]) == type(original) then config[k] = data[k] end
        end
    end
    config.FOV = math.clamp(config.FOV, 60, 500)
    config.MaxRange = math.clamp(config.MaxRange, 100, 1500)
end
local function saveConfig()
    if type(writefile) ~= "function" then return end
    pcall(function() writefile(SAVE_PATH, HttpService:JSONEncode(config)) end)
end
loadConfig()

local alive = true
local connections = {}
local tracked = {}
local selected = nil
local selectedInfo = nil
local accumulated = 0
local header, gui, targetCard, targetText, statusText, cannonText
local targetDot, fireDot, fovCircle, panel
local toggleButtons = {}
local COLOR_ENEMY = Color3.fromRGB(246, 98, 95)
local COLOR_FRIENDLY = Color3.fromRGB(93, 181, 239)
local COLOR_SELECTED = Color3.fromRGB(255, 215, 102)
local COLOR_DIM = Color3.fromRGB(150, 162, 177)

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end
local function make(className, properties, parent)
    local item = Instance.new(className)
    for k, v in pairs(properties) do item[k] = v end
    item.Parent = parent
    return item
end
local function corner(obj, px)
    make("UICorner", {CornerRadius = UDim.new(0, px)}, obj)
end
local function stroke(obj, color, thickness)
    make("UIStroke", {Color = color, Transparency = 0.28, Thickness = thickness or 1}, obj)
end
local function label(parent, text, pos, size, fontSize, color, bold)
    return make("TextLabel", {
        Name = "Text", BackgroundTransparency = 1,
        Position = pos, Size = size, Text = text,
        TextColor3 = color or Color3.fromRGB(233, 241, 252),
        TextSize = fontSize or 13, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd
    }, parent)
end
local function button(parent, caption, pos, size)
    local b = make("TextButton", {
        Text = caption, Position = pos, Size = size, AutoButtonColor = true,
        BackgroundColor3 = Color3.fromRGB(35, 44, 60),
        TextColor3 = Color3.fromRGB(227, 235, 250),
        BorderSizePixel = 0, Font = Enum.Font.GothamMedium, TextSize = 12
    }, parent)
    corner(b, 7)
    return b
end
local function isFriendly(p)
    return LocalPlayer.Team ~= nil and p.Team ~= nil and LocalPlayer.Team == p.Team
end
local function getCharacter(p)
    local char = p.Character
    if not char or not char.Parent then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    local head = char:FindFirstChild("Head") or root
    if not root or not humanoid or humanoid.Health <= 0 then return nil end
    return char, humanoid, root, head
end
local function localOrigin()
    local c = LocalPlayer.Character
    local root = c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
    return root and root.Position or Camera.CFrame.Position
end

-- The native WeaponController explicitly reads Reticle.Main.Position SCALE,
-- adds 0.01 to Y SCALE, then uses ViewportPointToRay on release-to-fire.
local function nativeFirePoint()
    local viewport = Camera.ViewportSize
    local reticle = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    reticle = reticle and reticle:FindFirstChild("Reticle")
    local main = reticle and reticle:FindFirstChild("Main")
    if main and main:IsA("GuiObject") then
        local pos = main.Position
        return Vector2.new(pos.X.Scale * viewport.X, (pos.Y.Scale + 0.01) * viewport.Y), true
    end
    return Vector2.new(viewport.X * 0.5, viewport.Y * 0.51), false
end
local function getPoint(char, root, head)
    if not char or not root then return nil end
    if head and head:IsA("BasePart") then
        return root.Position:Lerp(head.Position, 0.45)
    end
    return root.Position
end
local function isClear(char, point)
    local own = LocalPlayer.Character
    local filter = {}
    if own then table.insert(filter, own) end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = filter
    params.IgnoreWater = true
    local origin = Camera.CFrame.Position
    local delta = point - origin
    if delta.Magnitude < 0.01 then return true end
    local hit = workspace:Raycast(origin, delta, params)
    return not hit or hit.Instance:IsDescendantOf(char)
end
local function candidate(p, fire)
    if p == LocalPlayer or (config.IgnoreFriendlies and isFriendly(p)) then return nil end
    local char, hum, root, head = getCharacter(p)
    if not char then return nil end
    local point = getPoint(char, root, head)
    local position, onscreen = Camera:WorldToViewportPoint(point)
    if not onscreen or position.Z <= 0 then return nil end
    local distance = (localOrigin() - point).Magnitude
    if distance > config.MaxRange then return nil end
    local pixel = Vector2.new(position.X, position.Y)
    local errorPixels = (pixel - fire).Magnitude
    return {
        player = p, character = char, humanoid = hum,
        point = point, pixel = pixel, distance = distance,
        errorPixels = errorPixels
    }
end
local function chooseTarget(fire)
    local best
    for _, player in ipairs(Players:GetPlayers()) do
        local info = candidate(player, fire)
        if info and info.errorPixels <= config.FOV then
            if not best or info.errorPixels < best.errorPixels then best = info end
        end
    end
    local retained = selected and candidate(selected, fire)
    if retained and retained.errorPixels <= config.FOV * 1.13 then
        if not best or best.player == selected or retained.errorPixels < best.errorPixels * 1.35 then
            return retained
        end
    end
    return best
end
local function dispose(p)
    local info = tracked[p]
    if info then
        if info.outline then info.outline:Destroy() end
        if info.tag then info.tag:Destroy() end
    end
    tracked[p] = nil
end
local function ensureTrack(p)
    local char, hum, root, head = getCharacter(p)
    if not char then
        dispose(p)
        return
    end
    local info = tracked[p]
    if info and info.char ~= char then dispose(p); info = nil end
    if not info then
        info = {char = char}
        tracked[p] = info
        local h = make("Highlight", {
            Name = "ECNovaOutline",
            Adornee = char,
            FillTransparency = 1,
            OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.Occluded,
            Enabled = config.Outlines
        }, char)
        info.outline = h
        local b = make("BillboardGui", {
            Name = "ECNovaTag", Adornee = head, AlwaysOnTop = config.ThroughWalls,
            Size = UDim2.fromOffset(175, 40),
            StudsOffsetWorldSpace = Vector3.new(0, 2.3, 0),
            Enabled = config.Nametags, MaxDistance = config.MaxRange,
            ResetOnSpawn = false
        }, LocalPlayer.PlayerGui)
        local t = label(b, p.DisplayName, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 12, COLOR_ENEMY, true)
        t.TextXAlignment = Enum.TextXAlignment.Center
        t.TextStrokeTransparency = 0.45
        info.tag = b
        info.text = t
    end
    info.head = head
    info.humanoid = hum
    if info.tag.Adornee ~= head then info.tag.Adornee = head end
    return info
end
local function refreshVisuals()
    local origin = localOrigin()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local info = ensureTrack(p)
            if info then
                local head = info.head
                local d = head and (head.Position - origin).Magnitude or math.huge
                local show = d <= config.MaxRange
                local friendly = isFriendly(p)
                local chosen = selected == p
                local color = chosen and COLOR_SELECTED or (friendly and COLOR_FRIENDLY or COLOR_ENEMY)
                info.outline.FillTransparency = 1
                info.outline.OutlineColor = color
                info.outline.DepthMode = config.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
                info.outline.Enabled = config.Outlines and show
                info.tag.Enabled = config.Nametags and show
                info.tag.AlwaysOnTop = config.ThroughWalls
                info.tag.MaxDistance = config.MaxRange
                info.text.TextColor3 = color
                info.text.Text = (chosen and "◆ " or "") .. p.DisplayName .. "  " .. tostring(math.floor(d + 0.5)) .. " st"
            end
        end
    end
end
local function cannonInfo()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local seat = hum and hum.SeatPart
    if not seat or not seat:GetAttribute("CannonSeat") then return nil end
    local parent = seat.Parent
    local model = parent and parent.Parent and parent.Parent.Parent
    if not model or not model:IsA("Model") then return nil end
    if not model:FindFirstChild("Bore") or not model:FindFirstChild("Cannon") then return nil end
    return model
end

gui = make("ScreenGui", {
    Name = "EmpireClashNOVA_Combat_v01", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 120, ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, LocalPlayer.PlayerGui)

panel = make("Frame", {
    Name = "Settings", BackgroundColor3 = Color3.fromRGB(20, 27, 39),
    BorderSizePixel = 0, Position = UDim2.new(0, 24, 0.5, -224),
    Size = UDim2.fromOffset(308, 448)
}, gui)
corner(panel, 12)
stroke(panel, Color3.fromRGB(90, 116, 151))
label(panel, "EMPIRE CLASH  /  NOVA", UDim2.fromOffset(17, 12), UDim2.fromOffset(248, 22), 16, Color3.fromRGB(238, 245, 255), true)
label(panel, "COMBAT FOUNDATION  v" .. VERSION, UDim2.fromOffset(18, 36), UDim2.fromOffset(250, 18), 10, COLOR_DIM, true)
local close = button(panel, "×", UDim2.fromOffset(267, 12), UDim2.fromOffset(27, 26))
close.TextSize = 19
connect(close.MouseButton1Click, function() panel.Visible = false end)
label(panel, "VISUALS AND TARGETING", UDim2.fromOffset(18, 67), UDim2.fromOffset(250, 17), 11, COLOR_DIM, true)

local toggles = {
    {"Outlines", "Outline chams (no fill)"},
    {"Nametags", "Player nametags"},
    {"TargetMarker", "Selected target marker"},
    {"FirePoint", "Native firing-point dot"},
    {"FOVRing", "Targeting radius"},
    {"ThroughWalls", "Visible through walls"},
    {"IgnoreFriendlies", "Filter friendly targets"}
}
for i, entry in ipairs(toggles) do
    local key, title = entry[1], entry[2]
    local y = 91 + (i - 1) * 33
    local b = button(panel, "", UDim2.fromOffset(18, y), UDim2.fromOffset(272, 29))
    b.TextXAlignment = Enum.TextXAlignment.Left
    toggleButtons[key] = {button = b, text = title}
    connect(b.MouseButton1Click, function()
        config[key] = not config[key]
        saveConfig()
        local t = toggleButtons[key]
        t.button.Text = (config[key] and "   ●  " or "   ○  ") .. t.text
        t.button.TextColor3 = config[key] and Color3.fromRGB(196, 238, 231) or COLOR_DIM
    end)
end
local function refreshButtons()
    for k, t in pairs(toggleButtons) do
        t.button.Text = (config[k] and "   ●  " or "   ○  ") .. t.text
        t.button.TextColor3 = config[k] and Color3.fromRGB(196, 238, 231) or COLOR_DIM
    end
end
refreshButtons()
local radiusButton = button(panel, "", UDim2.fromOffset(18, 328), UDim2.fromOffset(132, 30))
local rangeButton = button(panel, "", UDim2.fromOffset(158, 328), UDim2.fromOffset(132, 30))
local fovOptions = {120, 180, 260, 360, 480}
local rangeOptions = {250, 550, 850, 1200}
local function nextOption(options, n)
    for i, value in ipairs(options) do
        if n <= value then return options[i % #options + 1] end
    end
    return options[1]
end
local function showSettings()
    radiusButton.Text = "FOV: " .. tostring(config.FOV) .. " px"
    rangeButton.Text = "Range: " .. tostring(config.MaxRange) .. " st"
end
showSettings()
connect(radiusButton.MouseButton1Click, function()
    config.FOV = nextOption(fovOptions, config.FOV)
    showSettings(); saveConfig()
end)
connect(rangeButton.MouseButton1Click, function()
    config.MaxRange = nextOption(rangeOptions, config.MaxRange)
    showSettings(); saveConfig()
end)
statusText = label(panel, "Targeting is visual-only.", UDim2.fromOffset(19, 366), UDim2.fromOffset(272, 33), 11, COLOR_DIM)
cannonText = label(panel, "Cannon: not seated", UDim2.fromOffset(19, 396), UDim2.fromOffset(272, 19), 11, COLOR_DIM)
local unload = button(panel, "UNLOAD", UDim2.fromOffset(218, 414), UDim2.fromOffset(72, 26))

targetCard = make("Frame", {
    Name = "TargetCard", BackgroundColor3 = Color3.fromRGB(21, 30, 43),
    BackgroundTransparency = 0.12, BorderSizePixel = 0,
    Position = UDim2.new(1, -286, 0, 32), Size = UDim2.fromOffset(261, 69),
    Visible = false
}, gui)
corner(targetCard, 9)
stroke(targetCard, Color3.fromRGB(130, 159, 201))
targetText = label(targetCard, "NO TARGET", UDim2.fromOffset(12, 9), UDim2.fromOffset(238, 55), 12, Color3.fromRGB(241, 246, 251), true)
targetText.TextYAlignment = Enum.TextYAlignment.Center
targetText.TextWrapped = true

fovCircle = make("Frame", {
    Name = "AimRadius", BackgroundTransparency = 1, BorderSizePixel = 0,
    Size = UDim2.fromOffset(360, 360), AnchorPoint = Vector2.new(0.5, 0.5)
}, gui)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, fovCircle)
local fovStroke = stroke(fovCircle, Color3.fromRGB(111, 189, 228))
fovStroke.Transparency = 0.72
fireDot = make("Frame", {
    Name = "NativeShotOrigin2D", Size = UDim2.fromOffset(6, 6),
    AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(99, 235, 190),
    BorderSizePixel = 0
}, gui)
corner(fireDot, 6)
targetDot = make("Frame", {
    Name = "TargetAimPoint", Size = UDim2.fromOffset(14, 14),
    AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
    BorderSizePixel = 0, Visible = false
}, gui)
corner(targetDot, 14)
stroke(targetDot, COLOR_SELECTED, 2)

local function shutdown()
    if not alive then return end
    alive = false
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for p in pairs(tracked) do dispose(p) end
    if gui then gui:Destroy() end
    if env.ECNovaCombat and env.ECNovaCombat.Shutdown == shutdown then
        env.ECNovaCombat = nil
    end
end
env.ECNovaCombat = {Shutdown = shutdown, Version = VERSION, Config = config}
connect(unload.MouseButton1Click, shutdown)
connect(UserInputService.InputBegan, function(input, processed)
    if input.KeyCode == Enum.KeyCode.RightShift and not UserInputService:GetFocusedTextBox() then
        panel.Visible = not panel.Visible
    end
end)
connect(Players.PlayerRemoving, function(p)
    dispose(p)
    if selected == p then selected = nil; selectedInfo = nil end
end)

connect(RunService.RenderStepped, function(dt)
    if not alive then return end
    Camera = workspace.CurrentCamera or Camera
    local fire, exact = nativeFirePoint()
    fovCircle.Size = UDim2.fromOffset(config.FOV * 2, config.FOV * 2)
    fovCircle.Position = UDim2.fromOffset(fire.X, fire.Y)
    fovCircle.Visible = config.FOVRing
    fireDot.Position = UDim2.fromOffset(fire.X, fire.Y)
    fireDot.Visible = config.FirePoint
    fireDot.BackgroundColor3 = exact and Color3.fromRGB(99, 235, 190) or COLOR_DIM
    if selected then
        local info = candidate(selected, fire)
        targetDot.Visible = config.TargetMarker and info ~= nil
        if info then
            targetDot.Position = UDim2.fromOffset(info.pixel.X, info.pixel.Y)
        end
    else
        targetDot.Visible = false
    end
    accumulated += dt
    if accumulated < 0.12 then return end
    accumulated = 0
    selectedInfo = chooseTarget(fire)
    selected = selectedInfo and selectedInfo.player or nil
    refreshVisuals()

    if selectedInfo then
        local blocked = not isClear(selectedInfo.character, selectedInfo.point)
        local name = selectedInfo.player.DisplayName
        local hp = math.floor(selectedInfo.humanoid.Health + 0.5)
        local err = math.floor(selectedInfo.errorPixels + 0.5)
        local aligned = err <= 13 and not blocked
        targetText.Text = name .. "  •  " .. hp .. " HP  •  " .. math.floor(selectedInfo.distance + 0.5) ..
            " st\n" .. (blocked and "BLOCKED" or (aligned and "ALIGNED" or "OFFSET " .. err .. " px"))
        targetText.TextColor3 = aligned and Color3.fromRGB(132, 242, 182) or COLOR_SELECTED
        targetCard.Visible = true
        statusText.Text = (exact and "Native reticle calibrated" or "Native reticle not found") .. "  •  VISUAL ONLY"
    else
        targetCard.Visible = false
        statusText.Text = (exact and "Native reticle calibrated" or "Reticle fallback") .. "  •  No valid target"
    end
    local cannon = cannonInfo()
    if cannon then
        cannonText.Text = "Cannon: " .. tostring(cannon:GetAttribute("Status") or "?") ..
            "  |  Range ×" .. tostring(cannon:GetAttribute("Range") or "?") .. " (native)"
    else
        cannonText.Text = "Cannon: not seated"
    end
end)

-- Optional continuity. Some executors do not support queue_on_teleport; if
-- missing, simply re-execute after travelling. Saved settings load when available.
local queue = type(queue_on_teleport) == "function" and queue_on_teleport
if not queue and type(syn) == "table" and type(syn.queue_on_teleport) == "function" then
    queue = syn.queue_on_teleport
end
if queue then
    pcall(queue, 'loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/project-empire-clash-nova/roblox-tools/empire-clash-nova-combat-foundation-v0.1.lua"))()')
end
print("[EC NOVA] Combat Foundation v" .. VERSION .. " loaded. RightShift = panel. No shot modification.")
