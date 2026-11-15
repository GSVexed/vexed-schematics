-- FERAL Stamina Research v1.3 -- read-only diagnostic
-- Velocity-friendly standard Luau. No metamethod hooks, remote calls, or game-state edits.
-- Automatic movement classification is observational and not guaranteed to match game-defined gaits.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("StaminaResearchPanel")
if old then old:Destroy() end

local DURATION = 90
local INTERVAL = 0.5
local MAX_SAMPLES = 220
local MAX_EVENTS = 180

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
    Size = UDim2.fromOffset(520, 560),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0, Active = true
}, gui)
round(panel, 14)
line(panel)

local camera = workspace.CurrentCamera
if camera then
    local v = camera.ViewportSize
    create("UIScale", {Scale = math.clamp(math.min(v.X / 560, v.Y / 620), 0.65, 1)}, panel)
end

local header = create("Frame", {
    Name = "DragHeader", Size = UDim2.fromOffset(520, 62),
    BackgroundTransparency = 1, Active = true
}, panel)
label(header, "Title", "FERAL  /  STAMINA LAB", 17, 8, 375, 27, 16, C.text, true)
label(header, "Subtitle", "v1.3   •   automatic observation   •   read only", 17, 35, 400, 19, 11, C.muted, false)
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

local hint = label(panel, "Hint", "Auto-labels use gait attributes, animations, sprint flag, then speed estimates.", 17, 301, 487, 25, 10, C.muted, false)
hint.TextWrapped = true

local start = button(panel, "Start", "Start 90s scan", 16, 335, 182, 38, C.accent)
local stop = button(panel, "Stop", "Stop", 207, 335, 104, 38, C.red)
local copy = button(panel, "Copy", "Copy report", 320, 335, 184, 38, C.blue)

local progressTrack = create("Frame", {
    Name = "ProgressTrack", Position = UDim2.fromOffset(16, 387),
    Size = UDim2.fromOffset(488, 6),
    BackgroundColor3 = C.track, BorderSizePixel = 0
}, panel)
round(progressTrack, 3)
local progressFill = create("Frame", {
    Name = "ProgressFill", Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = C.blue, BorderSizePixel = 0
}, progressTrack)
round(progressFill, 3)
local status = label(panel, "Status", "Ready. Sprint, trot, walk and crawl naturally during the scan.", 16, 401, 488, 27, 11, C.muted, false)
status.TextWrapped = true
label(panel, "ReportTitle", "REPORT   /   SELECT TEXT IF CLIPBOARD UNAVAILABLE", 16, 432, 487, 17, 10, C.muted, true)

local reportBox = create("TextBox", {
    Name = "Report",
    Position = UDim2.fromOffset(16, 452),
    Size = UDim2.fromOffset(488, 91),
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
    panel.Size = UDim2.fromOffset(520, minimized and 62 or 560)
    for _, obj in ipairs({top, mid, hint, start, stop, copy, progressTrack,
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
local function stateName(text)
    if typeof(text) ~= "string" then return nil end
    local n = string.lower(text)
    if string.find(n, "crawl", 1, true) or string.find(n, "crouch", 1, true) then return "Crawl" end
    if string.find(n, "trot", 1, true) then return "Trot" end
    if string.find(n, "sprint", 1, true) then return "Sprint" end
    if string.find(n, "walk", 1, true) then return "Walk" end
    if string.find(n, "run", 1, true) or string.find(n, "gallop", 1, true) then return "Run" end
    if string.find(n, "idle", 1, true) or string.find(n, "rest", 1, true) then return "Idle / Rest" end
    return nil
end

local stateAttributes = {"MovementMode", "MoveMode", "Gait", "Stance", "Locomotion", "LocomotionState", "MovementState", "SpeedMode", "MoveState"}
local positiveFlags = {
    {"IsCrawling", "Crawl"}, {"Crawling", "Crawl"}, {"IsCrouching", "Crawl"},
    {"Crouching", "Crawl"}, {"IsTrotting", "Trot"}, {"Trotting", "Trot"},
    {"IsSprinting", "Sprint"}, {"Sprinting", "Sprint"}, {"IsRunning", "Run"}
}

local function inspectModeAttributes(character)
    for _, obj in ipairs({character, player}) do
        if obj then
            for _, key in ipairs(stateAttributes) do
                local value = obj:GetAttribute(key)
                local n = stateName(value)
                if n then return n, "explicit attribute: " .. key end
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

local function animationMode(humanoid)
    if not humanoid then return nil, nil end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return nil, nil end
    local ok, tracks = pcall(function()
        return animator:GetPlayingAnimationTracks()
    end)
    if not ok then return nil, nil end
    local best, bestPriority, bestEvidence = nil, -1, nil
    for _, track in ipairs(tracks) do
        local named = stateName(track.Name)
        if named then
            local weight = (named == "Crawl" and 6) or (named == "Trot" and 5)
                or (named == "Sprint" and 4) or (named == "Run" and 3)
                or (named == "Walk" and 2) or 1
            if weight > bestPriority and track.WeightCurrent > 0.05 then
                best, bestPriority = named, weight
                bestEvidence = "animation name: " .. string.sub(track.Name, 1, 50)
            end
        end
    end
    return best, bestEvidence
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

    if speed and speed < 80 and speed > peakSpeed then peakSpeed = speed end

    local chosen, evidence = inspectModeAttributes(char)
    if not chosen and sprint == true then
        chosen, evidence = "Sprint", "HUD sprint flag"
    end
    if not chosen then chosen, evidence = animationMode(humanoid) end
    if not chosen then
        if (not speed or speed < 0.7) and (not input or input < 0.1) then
            chosen, evidence = "Idle / Rest", "low motion estimate"
        elseif speed then
            local threshold = math.max(peakSpeed, 16)
            local ratio = speed / threshold
            if ratio < 0.22 then chosen = "Slow movement"
            elseif ratio < 0.60 then chosen = "Medium movement"
            else chosen = "Fast movement" end
            evidence = "speed band estimate — gait unknown"
        else
            chosen, evidence = "Unknown", "no movement sensor"
        end
    end
    return {
        stamina = stamina, maximum = maximum, sprint = sprint,
        exhausted = exhausted, walk = walk, speed = speed,
        input = input, rawMode = chosen, evidence = evidence
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
                event("Character@" .. key .. " = " .. fmt(char:GetAttribute(key)))
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
        stamina = observed.stamina, maximum = observed.maximum,
        sprint = observed.sprint, exhausted = observed.exhausted,
        speed = observed.speed, walk = observed.walk, input = observed.input
    })
end

local function buildReport(complete)
    local out = {
        "=== FERAL STAMINA DIAGNOSTIC v1.3 ===",
        "Read-only observation; no client/game attributes modified",
        "Place ID: " .. tostring(game.PlaceId),
        "Test animal: Tiger (user supplied; not independently verified)",
        "Elapsed: " .. string.format("%.1f", running and now() or (#samples > 0 and samples[#samples].t or 0)) .. "s",
        "Status: " .. (complete and "finished / stopped" or "scanning"),
        "Samples: " .. #samples .. " ; interval: " .. INTERVAL .. "s",
        "Motion labels are automatic. Explicit attributes/animations/HUD are evidence; speed bands are estimates.",
        "Nothing here establishes whether server or client is authoritative.",
        "",
        "=== AUTOMATIC STATE TRANSITIONS ==="
    }
    for _, text in ipairs(transitions) do table.insert(out, text) end
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
    table.insert(out, "t | label | evidence | stamina | max | exhausted | sprintHUD | WalkSpeed | horizontalSpeed | input")
    for _, r in ipairs(samples) do
        table.insert(out, string.format(
            "%.1f | %s | %s | %s | %s | %s | %s | %s | %s | %s",
            r.t, r.mode, r.evidence, fmt(r.stamina), fmt(r.maximum),
            fmt(r.exhausted), fmt(r.sprint), fmt(r.walk), fmt(r.speed), fmt(r.input)
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
    sourceText.Text = "Evidence: " .. modeEvidence
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
    lastReport = ""
    mode, modeEvidence = "Unknown", "initializing"
    candidate = nil
    candidateTime = 0
    peakSpeed = 0
    previousStamina, previousTime = nil, nil
    reportBox.Text = "Scanning... movement modes are classified automatically.\n" ..
        "No buttons needed. Sprint, trot, walk, crawl and rest as normal."
    start.Text = "Scanning..."
    statusText("Recording up to 90 seconds. Mode switching is automatic.")
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
