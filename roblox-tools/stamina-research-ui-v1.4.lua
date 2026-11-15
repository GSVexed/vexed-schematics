-- FERAL Stamina Research v1.4 -- read-only diagnostic
-- Velocity-friendly standard Luau. No metamethod hooks, remote calls, or game-state edits.
-- Automatic movement classification is observational and not guaranteed to match game-defined gaits.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("StaminaResearchPanel")
if old then old:Destroy() end

local DURATION = 120
local INTERVAL = 0.5
local MAX_SAMPLES = 300
local MAX_EVENTS = 350

local C = {
    bg = Color3.fromRGB(13, 18, 28),
    surface = Color3.fromRGB(25, 34, 49),
    surface2 = Color3.fromRGB(32, 44, 62),
    outline = Color3.fromRGB(64, 82, 106),
    text = Color3.fromRGB(237, 245, 255),
    muted = Color3.fromRGB(158, 179, 202),
    accent = Color3.fromRGB(49, 199, 175),
    blue = Color3.fromRGB(63, 129, 213),
    red = Color3.fromRGB(198, 77, 92),
    track = Color3.fromRGB(51, 63, 79)
}
local function create(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function round(obj, pixels)
    create("UICorner", {CornerRadius = UDim.new(0, pixels or 10)}, obj)
end
local function line(parent)
    create("UIStroke", {Color = C.outline, Thickness = 1, Transparency = 0.25}, parent)
end
local function label(parent, name, text, x, y, w, h, size, color, bold)
    return create("TextLabel", {
        Name = name, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize = size, TextColor3 = color or C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Text = text
    }, parent)
end
local function button(parent, name, text, x, y, w, h, background)
    local b = create("TextButton", {
        Name = name, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = background,
        TextColor3 = C.text, Font = Enum.Font.GothamBold,
        TextSize = 12, Text = text,
        BorderSizePixel = 0, AutoButtonColor = true
    }, parent)
    round(b, 8)
    return b
end

local gui = create("ScreenGui", {
    Name = "StaminaResearchPanel", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 300
}, playerGui)
local panel = create("Frame", {
    Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.fromOffset(520, 670),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0, Active = true
}, gui)
round(panel, 14)
line(panel)

local camera = workspace.CurrentCamera
if camera then
    local v = camera.ViewportSize
    create("UIScale", {Scale = math.clamp(math.min(v.X / 560, v.Y / 730), 0.65, 1)}, panel)
end

local header = create("Frame", {
    Name = "DragHeader", Size = UDim2.fromOffset(520, 62),
    BackgroundTransparency = 1, Active = true
}, panel)
label(header, "Title", "FERAL  /  STAMINA LAB  v1.4", 17, 8, 375, 27, 16, C.text, true)
label(header, "Subtitle", "Tiger gait identities • Burst investigation • read only", 17, 35, 400, 19, 11, C.muted, false)
local minimize = button(header, "Minimize", "–", 452, 16, 25, 27, C.surface2)
local close = button(header, "Close", "X", 482, 16, 25, 27, C.red)

local top = create("Frame", {
    Name = "StaminaCard",
    Position = UDim2.fromOffset(16, 66),
    Size = UDim2.fromOffset(488, 103),
    BackgroundColor3 = C.surface, BorderSizePixel = 0
}, panel)
round(top, 10)
label(top, "StaminaTitle", "STAMINA   /   MAXIMUM", 13, 8, 220, 18, 10, C.muted, true)
local staminaText = label(top, "StaminaValue", "— / —", 13, 28, 263, 34, 25, C.text, true)
local rateText = label(top, "Rate", "Rate: collecting...", 280, 34, 190, 22, 11, C.muted, false)
rateText.TextXAlignment = Enum.TextXAlignment.Right
local track = create("Frame", {
    Name = "StaminaTrack", Position = UDim2.fromOffset(13, 76),
    Size = UDim2.fromOffset(462, 11),
    BackgroundColor3 = C.track, BorderSizePixel = 0
}, top)
round(track, 5)
local fill = create("Frame", {
    Name = "StaminaFill", Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = C.accent, BorderSizePixel = 0
}, track)
round(fill, 5)

local mid = create("Frame", {
    Name = "MovementCard",
    Position = UDim2.fromOffset(16, 179),
    Size = UDim2.fromOffset(488, 115),
    BackgroundColor3 = C.surface, BorderSizePixel = 0
}, panel)
round(mid, 10)
label(mid, "MovementTitle", "AUTO-DETECTED MOVEMENT", 13, 7, 350, 19, 10, C.muted, true)
local modeText = label(mid, "Mode", "Waiting for observations", 13, 26, 456, 30, 21, C.accent, true)
local sourceText = label(mid, "Evidence", "Source: no state detected", 13, 57, 456, 19, 11, C.muted, false)
local detailText = label(mid, "Details", "Speed: —     Sprint: —     Exhausted: —", 13, 80, 458, 20, 11, C.text, false)

local burstCard = create("Frame", {
    Name = "BurstCard", Position = UDim2.fromOffset(16, 299),
    Size = UDim2.fromOffset(488, 70), BackgroundColor3 = C.surface2,
    BorderSizePixel = 0
}, panel)
round(burstCard, 10)
label(burstCard, "BurstTitle", "BURST / FASTER-SPRINT INVESTIGATION", 13, 6, 455, 18, 10, C.muted, true)
local burstText = label(burstCard, "BurstState", "Waiting for evidence...", 13, 25, 455, 24, 15, C.accent, true)
local burstDetail = label(burstCard, "BurstDetail", "No explicit burst signal detected yet", 13, 49, 457, 17, 10, C.muted, false)
local hint = label(panel, "Hint", "Actual names are preserved when exposed; speed-only burst is marked unconfirmed.", 17, 376, 487, 24, 10, C.muted, false)
hint.TextWrapped = true

local start = button(panel, "Start", "Start 120s scan", 16, 407, 182, 38, C.accent)
local stop = button(panel, "Stop", "Stop", 207, 407, 104, 38, C.red)
local copy = button(panel, "Copy", "Copy report", 320, 407, 184, 38, C.blue)

local progressTrack = create("Frame", {
    Name = "ProgressTrack", Position = UDim2.fromOffset(16, 459),
    Size = UDim2.fromOffset(488, 6),
    BackgroundColor3 = C.track, BorderSizePixel = 0
}, panel)
round(progressTrack, 3)
local progressFill = create("Frame", {
    Name = "ProgressFill", Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = C.blue, BorderSizePixel = 0
}, progressTrack)
round(progressFill, 3)
local status = label(panel, "Status", "Ready. Try normal sprint, faster burst, crawl, trot and walking.", 16, 471, 488, 27, 11, C.muted, false)
status.TextWrapped = true
label(panel, "ReportTitle", "REPORT   /   SELECT TEXT IF CLIPBOARD UNAVAILABLE", 16, 503, 487, 17, 10, C.muted, true)

local reportBox = create("TextBox", {
    Name = "Report",
    Position = UDim2.fromOffset(16, 527),
    Size = UDim2.fromOffset(488, 124),
    BackgroundColor3 = C.surface,
    TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, BorderSizePixel = 0,
    Text = "Press Start to begin. No movement-mode buttons needed.",
    MultiLine = true, TextWrapped = false, ClearTextOnFocus = false,
    TextEditable = true, Font = Enum.Font.Code, TextSize = 11
}, panel)
round(reportBox, 8)
create("UIPadding", {
    PaddingTop = UDim.new(0, 7), PaddingLeft = UDim.new(0, 9),
    PaddingBottom = UDim.new(0, 7), PaddingRight = UDim.new(0, 9)
}, reportBox)

local dragging = false
local dragOrigin
local panelOrigin
local connections = {}
local function bind(connection)
    table.insert(connections, connection)
    return connection
end
bind(header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragOrigin = input.Position
        panelOrigin = panel.Position
    end
end))
bind(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
       or input.UserInputType == Enum.UserInputType.Touch) then
        local diff = input.Position - dragOrigin
        panel.Position = UDim2.new(panelOrigin.X.Scale, panelOrigin.X.Offset + diff.X,
                                  panelOrigin.Y.Scale, panelOrigin.Y.Offset + diff.Y)
    end
end))
bind(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

local minimized = false
minimize.Activated:Connect(function()
    minimized = not minimized
    panel.Size = UDim2.fromOffset(520, minimized and 62 or 670)
    for _, obj in ipairs({top, mid, burstCard, hint, start, stop, copy, progressTrack,
                           status, reportBox}) do
        obj.Visible = not minimized
    end
    for _, obj in ipairs(panel:GetChildren()) do
        if obj.Name == "ReportTitle" then obj.Visible = not minimized end
    end
    minimize.Text = minimized and "+" or "–"
end)

local running = false
local stopRequested = false
local began = 0
local samples = {}
local transitions = {}
local detectedObjects = {}
local knownSignals = {}
local lastAnimationSignature = ""
local lastBurstUI = ""
local burstUIState = "Not yet observed"
local lastReport = ""
local mode = "Unknown"
local modeEvidence = "unavailable"
local candidate, candidateTime = nil, 0
local peakSpeed = 0
local previousStamina = nil
local previousTime = nil
local characterSignals = {}
local observedCharacter = nil

local function disconnectCharacter()
    for _, con in ipairs(characterSignals) do pcall(function() con:Disconnect() end) end
    characterSignals = {}
    observedCharacter = nil
end
local function now()
    return running and math.max(0, os.clock() - began) or 0
end
local function event(message)
    if running and #transitions < MAX_EVENTS then
        table.insert(transitions, string.format("[%.2fs] %s", now(), message))
    end
end
local function readNumber(object, key)
    if not object then return nil end
    local v = object:GetAttribute(key)
    return typeof(v) == "number" and v or nil
end
local function fmt(v)
    if typeof(v) == "number" then return string.format("%.2f", v) end
    if v == nil then return "-" end
    return tostring(v)
end

-- Collect exact attribute values and HUD changes, without modifying any game state.
local function isRelevantKey(key)
    if typeof(key) ~= "string" then return false end
    local k = string.lower(key)
    for _, word in ipairs({"burst", "boost", "dash", "sprint", "trot", "crawl",
        "crouch", "walk", "gait", "stamina", "exhaust", "locomot", "stance",
        "speedmode", "movespeed", "movemode", "running", "rush"}) do
        if string.find(k, word, 1, true) then return true end
    end
    return false
end

local function observeAttributes(character, humanoid, root)
    for _, info in ipairs({{character,"Character"}, {player,"Player"}, {humanoid,"Humanoid"}, {root,"Root"}}) do
        local object, prefix = info[1], info[2]
        if object then
            local ok, attributes = pcall(function() return object:GetAttributes() end)
            if ok then
                for name, value in pairs(attributes) do
                    if isRelevantKey(name) then
                        local key = prefix .. "@" .. name
                        local content = string.sub(tostring(value), 1, 90)
                        if knownSignals[key] ~= content then
                            knownSignals[key] = content
                            event("RAW ATTR " .. key .. "=" .. content)
                        end
                    end
                end
            end
        end
    end
end

local function observeBurstHud()
    local hud = playerGui:FindFirstChild("FeralHUD")
    if not hud then burstUIState = "FeralHUD not found"; return end
    local burst = hud:FindFirstChild("burst", true)
    if not burst then burstUIState = "No burst-named HUD object"; return end
    burstUIState = "Burst-named HUD control exists; its presence alone does not mean active"
    local targets = {burst}
    for _, obj in ipairs(burst:GetDescendants()) do
        if #targets >= 6 then break end
        if obj:IsA("GuiObject") then table.insert(targets, obj) end
    end
    local parts = {}
    for _, obj in ipairs(targets) do
        local fragment = obj.Name .. ":" .. obj.ClassName
        if obj:IsA("GuiObject") then
            fragment = fragment .. ":visible=" .. tostring(obj.Visible)
                .. ":bgAlpha=" .. string.format("%.2f", obj.BackgroundTransparency)
        end
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            fragment = fragment .. ":imageAlpha=" .. string.format("%.2f", obj.ImageTransparency)
                .. ":imageRGB=" .. tostring(obj.ImageColor3)
        end
        if obj:IsA("GuiObject") then
            fragment = fragment .. ":size=" .. tostring(obj.Size)
        end
        table.insert(parts, fragment)
    end
    local signature = table.concat(parts, ";")
    if signature ~= lastBurstUI then
        lastBurstUI = signature
        event("BURST HUD: " .. string.sub(signature, 1, 360))
    end
end

local function stateName(text)
    if typeof(text) ~= "string" then return nil end
    local n = string.lower(text)
    if string.find(n, "crawl", 1, true) or string.find(n, "crouch", 1, true) then return "Crawl" end
    if string.find(n, "trot", 1, true) then return "Trot" end
    if string.find(n, "burst", 1, true) then return "Burst" end
    if string.find(n, "dash", 1, true) then return "Dash" end
    if string.find(n, "boost", 1, true) then return "Boost" end
    if string.find(n, "rush", 1, true) then return "Rush" end
    if string.find(n, "sprint", 1, true) then return "Sprint" end
    if string.find(n, "walk", 1, true) then return "Walk" end
    if string.find(n, "run", 1, true) or string.find(n, "gallop", 1, true) then return "Run" end
    if string.find(n, "idle", 1, true) or string.find(n, "rest", 1, true) then return "Idle / Rest" end
    return nil
end

local stateAttributes = {"MovementMode", "MoveMode", "Gait", "Stance", "Locomotion", "LocomotionState", "MovementState", "SpeedMode", "MoveState", "CurrentGait", "MoveType", "Motion", "Movement", "Pace", "SpeedState"}
local positiveFlags = {
    {"IsBursting", "Burst"}, {"Bursting", "Burst"}, {"HudBurst", "Burst"},
    {"IsDashing", "Dash"}, {"Dashing", "Dash"}, {"IsBoosting", "Boost"},
    {"IsCrawling", "Crawl"}, {"Crawling", "Crawl"}, {"IsCrouching", "Crawl"},
    {"Crouching", "Crawl"}, {"IsTrotting", "Trot"}, {"Trotting", "Trot"},
    {"IsSprinting", "Sprint"}, {"Sprinting", "Sprint"}, {"IsRunning", "Run"}
}

local function inspectModeAttributes(character, humanoid, root)
    for _, obj in ipairs({character, player, humanoid, root}) do
        if obj then
            for _, key in ipairs(stateAttributes) do
                local value = obj:GetAttribute(key)
                local n = stateName(value)
                if n then return n, "explicit attribute: " .. key .. "=" .. string.sub(tostring(value), 1, 35) end
            end
            for _, pair in ipairs(positiveFlags) do
                if obj:GetAttribute(pair[1]) == true then
                    return pair[2], "explicit flag: " .. pair[1]
                end
            end
        end
    end
    return nil, nil
end

-- Track names and underlying Animation.Name/AnimationId are read-only evidence.
local function animationMode(humanoid)
    if not humanoid then return nil, nil, "" end
    local animator = humanoid:FindFirstChildOfClass("Animator")
        or (player.Character and player.Character:FindFirstChildWhichIsA("Animator", true))
    if not animator then return nil, nil, "" end
    local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
    if not ok then return nil, nil, "" end
    local playing = {}
    local best, bestSource, bestScore = nil, nil, -1
    for _, track in ipairs(tracks) do
        if #playing >= 14 then break end
        local weight = 0
        pcall(function() weight = track.WeightCurrent end)
        if weight > 0.04 then
            local name = tostring(track.Name)
            local underlying, animationId
            local succeeded, animation = pcall(function() return track.Animation end)
            if succeeded and animation then
                pcall(function() underlying = tostring(animation.Name) end)
                pcall(function() animationId = tostring(animation.AnimationId) end)
            end
            local displayName = name .. (underlying and "/" .. underlying or "")
            local identity = displayName .. (animationId and "#" .. string.sub(animationId, 1, 65) or "")
            table.insert(playing, identity)
            local candidate = stateName(name) or stateName(underlying)
            if candidate then
                local score = (candidate == "Burst" or candidate == "Dash"
                    or candidate == "Boost" or candidate == "Rush") and 10
                    or (candidate == "Crawl" and 8) or (candidate == "Trot" and 7)
                    or (candidate == "Sprint" and 6) or (candidate == "Run" and 5)
                    or (candidate == "Walk" and 4) or 2
                if score > bestScore then
                    best, bestSource, bestScore = candidate,
                        "named animation: " .. string.sub(displayName, 1, 70), score
                end
            end
        end
    end
    table.sort(playing)
    local signature = table.concat(playing, "; ")
    if running and signature ~= lastAnimationSignature then
        lastAnimationSignature = signature
        event("ACTIVE ANIMATIONS: " .. string.sub(signature, 1, 460))
    end
    return best, bestSource, signature
end

local function explicitBurst(character, humanoid, root)
    for _, info in ipairs({{character,"Character"}, {player,"Player"}, {humanoid,"Humanoid"}, {root,"Root"}}) do
        local obj, prefix = info[1], info[2]
        if obj then
            local ok, attrs = pcall(function() return obj:GetAttributes() end)
            if ok then
                for key, value in pairs(attrs) do
                    local low = string.lower(key)
                    local related = string.find(low, "burst", 1, true)
                        or string.find(low, "dash", 1, true)
                        or string.find(low, "boost", 1, true)
                        or string.find(low, "rush", 1, true)
                    if related then
                        if value == true then return true, prefix .. "@" .. key .. "=true" end
                        if typeof(value) == "string" then
                            local name = stateName(value)
                            if name == "Burst" or name == "Dash" or name == "Boost" or name == "Rush" then
                                return true, prefix .. "@" .. key .. "=" .. string.sub(value, 1, 40)
                            end
                        end
                    end
                end
            end
        end
    end
    return false, nil
end

local function observe()
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local speed = nil
    if root and root:IsA("BasePart") then
        local v = root.AssemblyLinearVelocity
        speed = Vector3.new(v.X, 0, v.Z).Magnitude
    end
    local input = humanoid and humanoid.MoveDirection.Magnitude or nil
    local walk = humanoid and humanoid.WalkSpeed or nil
    local sprint = player:GetAttribute("HudSprint")
    local exhausted = char and char:GetAttribute("StaminaOut")
    local stamina = readNumber(char, "Stamina")
    local maximum = readNumber(char, "StaminaMax")
    if running then
        observeAttributes(char, humanoid, root)
        observeBurstHud()
    end
    if speed and speed < 80 and speed > peakSpeed then peakSpeed = speed end

    local explicitName, explicitSource = inspectModeAttributes(char, humanoid, root)
    local animationName, animationSource, animationSignature = animationMode(humanoid)
    local isBurst, burstSource = explicitBurst(char, humanoid, root)
    local namedBurstAnimation = animationName == "Burst" or animationName == "Dash"
        or animationName == "Boost" or animationName == "Rush"
    local speedTier = "unknown"
    if speed then
        if speed >= 28 then speedTier = "high 28+"
        elseif speed >= 15 then speedTier = "moderate 15-28"
        elseif speed < 1 then speedTier = "near-still"
        else speedTier = "low under-15" end
    end

    local chosen, evidence, confidence = nil, nil, "estimate"
    if isBurst then
        chosen, evidence, confidence = "Burst/boost active", "explicit attribute: "..burstSource, "explicit attribute"
    elseif namedBurstAnimation then
        chosen, evidence, confidence = animationName, animationSource, "named animation"
    elseif explicitName then
        chosen, evidence, confidence = explicitName, explicitSource, "explicit attribute"
    elseif sprint == true then
        if speed and speed >= 28 and (input or 0) > 0.2 then
            chosen, evidence, confidence = "High-speed sprint (burst candidate)",
                "HudSprint=true; speed>=28; not a confirmed burst", "speed correlation"
        else
            chosen, evidence, confidence = "Sprint", "HudSprint=true", "HUD sprint flag"
        end
    elseif animationName then
        chosen, evidence, confidence = animationName, animationSource, "named animation"
    elseif (not speed or speed < 0.7) and (not input or input < 0.1) then
        chosen, evidence = "Idle / Rest", "low speed and input"
    elseif speed then
        local threshold = math.max(peakSpeed, 16)
        local ratio = speed / threshold
        if ratio < 0.22 then chosen = "Slow movement"
        elseif ratio < 0.60 then chosen = "Medium movement"
        else chosen = "Fast movement" end
        evidence = "speed estimate; true gait unknown"
    else
        chosen, evidence = "Unknown", "no movement data"
    end
    local burstStatus
    if isBurst then burstStatus = "Burst-like attribute is ACTIVE"
    elseif namedBurstAnimation then burstStatus = "Named " .. animationName .. " animation playing"
    elseif sprint == true and speed and speed >= 28 then
        burstStatus = "Faster sprint observed; burst NOT confirmed"
    else
        burstStatus = "No explicit burst-active evidence"
    end
    return {
        stamina = stamina, maximum = maximum, sprint = sprint, exhausted = exhausted,
        walk = walk, speed = speed, input = input, rawMode = chosen,
        evidence = evidence, confidence = confidence, speedTier = speedTier,
        burstActive = isBurst, burstSource = burstSource,
        burstStatus = burstStatus, animationSignature = animationSignature
    }
end

local function observeCharacter()
    local char = player.Character
    if observedCharacter == char then return end
    disconnectCharacter()
    observedCharacter = char
    if not char then return end
    local function listen(key)
        local con = char:GetAttributeChangedSignal(key):Connect(function()
            if running and (key == "StaminaOut" or key == "StaminaMax") then
                event("Character@" .. key .. " = " .. fmt(char:GetAttribute(key)) .. " at stamina=" .. fmt(char:GetAttribute("Stamina")) .. "/" .. fmt(char:GetAttribute("StaminaMax")))
            end
        end)
        table.insert(characterSignals, con)
    end
    listen("StaminaOut")
    listen("StaminaMax")
    event("Character observed / respawn")
end

local function updateMode(observed, elapsed)
    local nextMode = observed.rawMode
    if nextMode == mode then
        candidate = nil
        modeEvidence = observed.evidence
    elseif nextMode ~= candidate then
        candidate = nextMode
        candidateTime = elapsed
    elseif elapsed - candidateTime >= 0.45 then
        mode = candidate
        modeEvidence = observed.evidence
        candidate = nil
        event("AUTO MODE -> " .. mode .. " (" .. modeEvidence .. ")")
    end
end

local function record(observed, elapsed)
    if #samples >= MAX_SAMPLES then return end
    table.insert(samples, {
        t = elapsed, mode = mode, evidence = modeEvidence,
        confidence = observed.confidence, speedTier = observed.speedTier,
        burstActive = observed.burstActive, animationSignature = observed.animationSignature,
        stamina = observed.stamina, maximum = observed.maximum,
        sprint = observed.sprint, exhausted = observed.exhausted,
        speed = observed.speed, walk = observed.walk, input = observed.input
    })
end

local function buildReport(complete)
    local out = {
        "=== FERAL STAMINA DIAGNOSTIC v1.4 ===",
        "Read-only observation; no client/game attributes modified",
        "Place ID: " .. tostring(game.PlaceId),
        "Test animal: Tiger (user supplied; not independently verified)",
        "Focus: identity of walk/trot/crawl/sprint and faster burst",
        "Elapsed: " .. string.format("%.1f", running and now() or (#samples > 0 and samples[#samples].t or 0)) .. "s",
        "Status: " .. (complete and "finished / stopped" or "scanning"),
        "Samples: " .. #samples .. " ; interval: " .. INTERVAL .. "s",
        "Confirmed names are read from attributes/animations; speed-only burst candidates are unconfirmed.",
        "Burst HUD evidence: " .. burstUIState,
        "Nothing here establishes whether server or client is authoritative.",
        "",
        "=== AUTOMATIC STATE TRANSITIONS ==="
    }
    for _, text in ipairs(transitions) do table.insert(out, text) end
    table.insert(out, "")
    table.insert(out, "=== RAW MOVEMENT-RELATED ATTRIBUTES (LATEST) ===")
    local keys = {}
    for key in pairs(knownSignals) do table.insert(keys, key) end
    table.sort(keys)
    for _, key in ipairs(keys) do
        table.insert(out, key .. " = " .. knownSignals[key])
    end
    table.insert(out, "")
    table.insert(out, "=== SPRINT SPEED-TIER STAMINA COMPARISON ===")
    local tiers = {
        {name="Sprint below 15 studs/s", seconds=0, spent=0, n=0},
        {name="Sprint 15 to under 28 studs/s", seconds=0, spent=0, n=0},
        {name="Sprint 28+ studs/s (burst candidate only)", seconds=0, spent=0, n=0}
    }
    for i = 2, #samples do
        local a, b = samples[i-1], samples[i]
        local dt = b.t - a.t
        if a.sprint == true and b.sprint == true and a.stamina and b.stamina
            and b.speed and dt > 0 and dt < 2 then
            local band = b.speed >= 28 and tiers[3] or (b.speed >= 15 and tiers[2] or tiers[1])
            local delta = b.stamina - a.stamina
            if math.abs(delta / dt) < 80 then
                band.seconds = band.seconds + dt
                band.n = band.n + 1
                if delta < 0 then band.spent = band.spent - delta end
            end
        end
    end
    for _, band in ipairs(tiers) do
        table.insert(out, string.format(
            "%s | %.1fs / %d intervals | spent %.2f | spent/s %.2f",
            band.name, band.seconds, band.n, band.spent,
            band.seconds > 0 and band.spent / band.seconds or 0
        ))
    end
    table.insert(out, "")
    table.insert(out, "=== STAMINA DELTAS BY AUTO-LABEL ===")
    local stats = {}
    local ordered = {}
    for i = 2, #samples do
        local a, b = samples[i - 1], samples[i]
        if a.mode == b.mode and a.stamina ~= nil and b.stamina ~= nil then
            local key = b.mode
            if not stats[key] then
                stats[key] = {seconds = 0, drain = 0, regen = 0, count = 0}
                table.insert(ordered, key)
            end
            local s = stats[key]
            local dt = b.t - a.t
            local change = b.stamina - a.stamina
            if dt > 0 and dt < 2 and math.abs(change / dt) < 80 then
                s.seconds = s.seconds + dt
                s.count = s.count + 1
                if change < 0 then s.drain = s.drain - change else s.regen = s.regen + change end
            end
        end
    end
    for _, key in ipairs(ordered) do
        local s = stats[key]
        table.insert(out, string.format(
            "%s: %.1fs (%d intervals) | spent %.2f | gained %.2f | avg spent/s %.2f | avg gained/s %.2f",
            key, s.seconds, s.count, s.drain, s.regen,
            s.seconds > 0 and s.drain / s.seconds or 0,
            s.seconds > 0 and s.regen / s.seconds or 0
        ))
    end
    table.insert(out, "")
    table.insert(out, "=== TIME SERIES ===")
    table.insert(out, "t | mode | evidence | confidence | speedTier | explicitBurst | stamina | max | exhausted | sprintHUD | WalkSpeed | horizontalSpeed | input | activeAnimations")
    for _, r in ipairs(samples) do
        table.insert(out, string.format(
            "%.1f | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s",
            r.t, r.mode, r.evidence, r.confidence, r.speedTier, fmt(r.burstActive),
            fmt(r.stamina), fmt(r.maximum), fmt(r.exhausted), fmt(r.sprint),
            fmt(r.walk), fmt(r.speed), fmt(r.input), string.sub(r.animationSignature or "", 1, 110)
        ))
    end
    table.insert(out, "")
    table.insert(out, "=== END OF DIAGNOSTIC ===")
    return table.concat(out, "\n")
end

local function statusText(s)
    if gui.Parent then status.Text = s end
end

local function render(observed, elapsed)
    staminaText.Text = fmt(observed.stamina) .. "  /  " .. fmt(observed.maximum)
    local fraction = 0
    if observed.stamina and observed.maximum and observed.maximum > 0 then
        fraction = math.clamp(observed.stamina / observed.maximum, 0, 1)
    end
    fill.Size = UDim2.fromScale(fraction, 1)
    fill.BackgroundColor3 = observed.exhausted == true and C.red or C.accent
    modeText.Text = mode
    sourceText.Text = "Evidence: " .. string.sub(modeEvidence, 1, 80)
    burstText.Text = observed.burstStatus
    burstDetail.Text = "Speed " .. fmt(observed.speed) .. " studs/s • tier " .. observed.speedTier
    detailText.Text = "Speed " .. fmt(observed.speed) ..
        "   |   Sprint " .. fmt(observed.sprint) ..
        "   |   Exhausted " .. fmt(observed.exhausted)

    if observed.stamina and previousStamina and previousTime and elapsed > previousTime then
        local rate = (observed.stamina - previousStamina) / (elapsed - previousTime)
        rateText.Text = string.format("%+.2f stamina/s", rate)
        rateText.TextColor3 = rate < -0.05 and C.red or (rate > 0.05 and C.accent or C.muted)
    else
        rateText.Text = "Rate: collecting..."
    end
    previousStamina = observed.stamina
    previousTime = elapsed
    progressFill.Size = UDim2.fromScale(math.clamp(elapsed / DURATION, 0, 1), 1)
end

local function finish()
    if not running then return end
    running = false
    stopRequested = false
    lastReport = buildReport(true)
    reportBox.Text = lastReport
    start.Text = "Start new scan"
    statusText("Report ready: " .. #samples .. " samples. Press Copy report.")
end

start.Activated:Connect(function()
    if running then statusText("Already scanning. Move naturally; modes update automatically."); return end
    running = true
    stopRequested = false
    began = os.clock()
    samples = {}
    transitions = {}
    detectedObjects = {}
    knownSignals = {}
    lastAnimationSignature = ""
    lastBurstUI = ""
    burstUIState = "Not yet observed"
    lastReport = ""
    mode, modeEvidence = "Unknown", "initializing"
    candidate = nil
    candidateTime = 0
    peakSpeed = 0
    previousStamina, previousTime = nil, nil
    reportBox.Text = "Scanning... movement modes are classified automatically.\n" ..
        "No buttons needed. Sprint, trot, walk, crawl and rest as normal."
    start.Text = "Scanning..."
    statusText("Recording 120s: test normal sprint and the faster burst.")
    event("Scan started")
end)
stop.Activated:Connect(function()
    if running then stopRequested = true
    else statusText("No active scan. Press Start to begin.") end
end)
copy.Activated:Connect(function()
    local report = lastReport
    if report == "" and running then report = buildReport(false) end
    if report == "" then statusText("No report yet. Press Start first."); return end
    local clipboard = nil
    if type(setclipboard) == "function" then clipboard = setclipboard end
    if not clipboard and type(toclipboard) == "function" then clipboard = toclipboard end
    if clipboard then
        local ok = pcall(clipboard, report)
        if ok then
            statusText("Report sent to clipboard. Paste it into ChatGPT.")
            return
        end
    end
    reportBox.Text = report
    reportBox:CaptureFocus()
    statusText("Clipboard unavailable. Select report text and press Ctrl+A / Ctrl+C.")
end)
close.Activated:Connect(function()
    stopRequested = true
    gui:Destroy()
end)

bind(player:GetAttributeChangedSignal("HudSprint"):Connect(function()
    if running then event("Player@HudSprint = " .. fmt(player:GetAttribute("HudSprint"))) end
end))
gui.Destroying:Connect(function()
    stopRequested = true
    running = false
    disconnectCharacter()
    for _, con in ipairs(connections) do pcall(function() con:Disconnect() end) end
end)

task.spawn(function()
    local nextSample = 0
    while gui.Parent do
        local ok, err = pcall(function()
            observeCharacter()
            local seen = observe()
            local t = running and now() or 0
            if running then
                updateMode(seen, t)
                if t >= nextSample then
                    record(seen, t)
                    render(seen, t)
                    nextSample = t + INTERVAL
                    statusText(string.format("Scanning %.1f / %ds  •  %d samples  •  %s",
                        t, DURATION, #samples, mode))
                end
                if t >= DURATION or stopRequested or #samples >= MAX_SAMPLES then
                    finish()
                end
            else
                if lastReport == "" then
                    local previous = mode
                    mode = seen.rawMode
                    modeEvidence = seen.evidence
                    if previous ~= mode then
                        modeText.Text = mode
                        sourceText.Text = "Evidence: " .. modeEvidence
                    end
                    staminaText.Text = fmt(seen.stamina) .. "  /  " .. fmt(seen.maximum)
                    burstText.Text = seen.burstStatus
                    burstDetail.Text = "Speed " .. fmt(seen.speed) .. " • tier " .. seen.speedTier
                    if seen.stamina and seen.maximum and seen.maximum > 0 then
                        fill.Size = UDim2.fromScale(math.clamp(seen.stamina / seen.maximum, 0, 1), 1)
                    end
                end
                nextSample = 0
            end
        end)
        if not ok then
            statusText("Diagnostic error: " .. string.sub(tostring(err), 1, 125))
        end
        task.wait(0.18)
    end
end)
