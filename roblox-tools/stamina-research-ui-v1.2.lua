-- Stamina Research Panel v1.2 (Velocity-compatible, read-only)
-- READ-ONLY: inspects replicated client objects and movement observations.
-- No remote calls, hooks, anti-cheat bypasses, or game-state modifications.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DURATION = 75
local SAMPLE_INTERVAL = 0.5
local REINDEX_INTERVAL = 5
local MAX_WATCHES = 350
local MAX_EVENTS = 350
local KEYWORDS = {"stam", "energy", "sprint", "endur", "fatigue", "exhaust", "drain", "regen"}

local old = playerGui:FindFirstChild("StaminaResearchPanel")
if old then old:Destroy() end

local function rounded(n)
    return math.floor(n * 10 + 0.5) / 10
end

local function isRelevant(name)
    name = string.lower(name)
    for _, word in ipairs(KEYWORDS) do
        if string.find(name, word, 1, true) then return true end
    end
    return false
end

local function new(className, properties, parent)
    local obj = Instance.new(className)
    for key, value in pairs(properties) do obj[key] = value end
    obj.Parent = parent
    return obj
end

local palette = {
    background = Color3.fromRGB(18, 23, 34),
    surface = Color3.fromRGB(29, 36, 50),
    input = Color3.fromRGB(13, 18, 27),
    outline = Color3.fromRGB(64, 76, 96),
    text = Color3.fromRGB(237, 242, 248),
    muted = Color3.fromRGB(167, 182, 203),
    accent = Color3.fromRGB(38, 166, 153),
    blue = Color3.fromRGB(61, 112, 188),
    danger = Color3.fromRGB(166, 77, 86),
}

local gui = new("ScreenGui", {
    Name = "StaminaResearchPanel",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 250,
}, playerGui)

local panel = new("Frame", {
    Name = "Panel",
    Size = UDim2.fromOffset(480, 540),
    Position = UDim2.new(0.5, -240, 0.5, -270),
    BackgroundColor3 = palette.background,
    BorderSizePixel = 0,
    Active = true,
}, gui)
new("UICorner", {CornerRadius = UDim.new(0, 12)}, panel)
new("UIStroke", {Color = palette.outline, Thickness = 1}, panel)

local header = new("Frame", {
    Name = "DragHeader",
    Size = UDim2.new(1, 0, 0, 47),
    BackgroundTransparency = 1,
    Active = true,
}, panel)

new("TextLabel", {
    Name = "Title",
    Size = UDim2.new(1, -88, 0, 25),
    Position = UDim2.fromOffset(15, 7),
    BackgroundTransparency = 1,
    Text = "STAMINA RESEARCH v1.2",
    TextColor3 = palette.text,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)
new("TextLabel", {
    Name = "Subtitle",
    Size = UDim2.new(1, -88, 0, 14),
    Position = UDim2.fromOffset(15, 29),
    BackgroundTransparency = 1,
    Text = "Read-only • client-side observation",
    TextColor3 = palette.muted,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local function button(name, label, x, y, width, height, bg, parent)
    local obj = new("TextButton", {
        Name = name,
        Size = UDim2.fromOffset(width, height),
        Position = UDim2.fromOffset(x, y),
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
        Text = label,
        TextColor3 = palette.text,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = true,
    }, parent)
    new("UICorner", {CornerRadius = UDim.new(0, 6)}, obj)
    return obj
end

local closeButton = button("Close", "X", 446, 10, 24, 24, palette.danger, header)
local minimizeButton = button("Minimize", "–", 417, 10, 24, 24, palette.surface, header)

local status = new("TextLabel", {
    Name = "Status",
    Position = UDim2.fromOffset(16, 56),
    Size = UDim2.fromOffset(448, 36),
    BackgroundColor3 = palette.surface,
    BorderSizePixel = 0,
    TextColor3 = palette.muted,
    Text = "Ready. Mark each movement mode during the scan.",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
new("UICorner", {CornerRadius = UDim.new(0, 6)}, status)
new("UIPadding", {PaddingLeft = UDim.new(0, 10)}, status)

local startButton = button("Start", "Start 75s scan", 16, 103, 154, 36, palette.accent, panel)
local stopButton = button("Stop", "Stop", 179, 103, 82, 36, palette.danger, panel)
local copyButton = button("Copy", "Copy report", 271, 103, 193, 36, palette.blue, panel)

local reportLabel = new("TextLabel", {
    Name = "ReportLabel",
    Position = UDim2.fromOffset(16, 220),
    Size = UDim2.fromOffset(448, 20),
    BackgroundTransparency = 1,
    TextColor3 = palette.muted,
    Text = "DIAGNOSTIC REPORT  •  COPY OR SELECT TEXT BELOW",
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local reportBox = new("TextBox", {
    Name = "ReportText",
    Position = UDim2.fromOffset(16, 244),
    Size = UDim2.fromOffset(448, 246),
    BackgroundColor3 = palette.input,
    BorderSizePixel = 0,
    TextColor3 = palette.text,
    Text = "Press Start 75s scan.\n\n" ..
           "Use the mode buttons to label what your tiger is doing.\n\n" ..
           "The report will appear here when ready.",
    Font = Enum.Font.Code,
    TextSize = 12,
    MultiLine = true,
    TextWrapped = true,
    TextEditable = true, -- manual select-all/copy fallback
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, panel)
new("UICorner", {CornerRadius = UDim.new(0, 6)}, reportBox)
new("UIPadding", {
    PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
    PaddingTop = UDim.new(0, 8),
    PaddingBottom = UDim.new(0, 8),
}, reportBox)

local footer = new("TextLabel", {
    Name = "Footer",
    Position = UDim2.fromOffset(16, 501),
    Size = UDim2.fromOffset(448, 30),
    BackgroundTransparency = 1,
    Text = "If Copy fails: click report, press Ctrl+A then Ctrl+C. Review before sharing.",
    TextColor3 = palette.muted,
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextWrapped = true,
}, panel)

-- The mode buttons label observations ONLY; they do not control the character.
local phaseLabel = new("TextLabel", {
    Name = "PhaseLabel",
    Position = UDim2.fromOffset(16, 149),
    Size = UDim2.fromOffset(448, 21),
    BackgroundTransparency = 1,
    Text = "MOVEMENT LABEL: Unmarked  •  click as the mode changes",
    TextColor3 = palette.muted,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local modeNames = {"Rest", "Walk", "Trot", "Sprint", "Crawl", "Other"}
local modeButtons = {}
for i, mode in ipairs(modeNames) do
    modeButtons[i] = button("Mode" .. mode, mode, 16 + (i - 1) * 76, 176, 71, 34, palette.surface, panel)
end

-- Drag the panel by its header; no gameplay input is recorded.
local dragging, dragStart, panelStart = false, nil, nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        panelStart = panel.Position
    end
end)
local dragChangedConnection = UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(panelStart.X.Scale, panelStart.X.Offset + delta.X,
                                   panelStart.Y.Scale, panelStart.Y.Offset + delta.Y)
    end
end)
local dragEndedConnection = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

gui.Destroying:Connect(function()
    dragChangedConnection:Disconnect()
    dragEndedConnection:Disconnect()
end)

local minimized = false
minimizeButton.Activated:Connect(function()
    minimized = not minimized
    panel.Size = UDim2.fromOffset(480, minimized and 47 or 540)
    for _, obj in ipairs({status, startButton, stopButton, copyButton,
                          reportLabel, reportBox, footer, phaseLabel}) do
        obj.Visible = not minimized
    end
    for _, obj in ipairs(modeButtons) do obj.Visible = not minimized end
    minimizeButton.Text = minimized and "+" or "–"
end)

local running = false
local aborted = false
local events = {}
local previous = {}
local lastReport = ""
local watches = {}
local truncated = false
local watchLimitReached = false
local discovered = 0
local samples = {}
local markers = {}
local selectedMode = "Unmarked"
local scanStart = 0
local boundCharacter = nil
local exhaustionConnection = nil
local sprintConnection = nil

local function timeNow()
    return math.max(0, os.clock() - scanStart)
end

local function mark(message)
    if not running then return end
    if #markers >= 150 then return end
    table.insert(markers, string.format("[%.2fs] %s", timeNow(), message))
end

local function disconnectSignals()
    if exhaustionConnection then exhaustionConnection:Disconnect(); exhaustionConnection = nil end
    if sprintConnection then sprintConnection:Disconnect(); sprintConnection = nil end
    boundCharacter = nil
end

-- Release event subscriptions if a fresh loader replaces this panel.
gui.Destroying:Connect(disconnectSignals)

local function connectSignals()
    local character = player.Character
    if boundCharacter ~= character then
        if exhaustionConnection then exhaustionConnection:Disconnect(); exhaustionConnection = nil end
        boundCharacter = character
        if character then
            exhaustionConnection = character:GetAttributeChangedSignal("StaminaOut"):Connect(function()
                mark("EXHAUSTION CHANGED: " .. tostring(character:GetAttribute("StaminaOut")))
            end)
            mark("Character attached for exhaustion events")
        end
    end
    if not sprintConnection then
        sprintConnection = player:GetAttributeChangedSignal("HudSprint"):Connect(function()
            mark("HUD SPRINT CHANGED: " .. tostring(player:GetAttribute("HudSprint")))
        end)
    end
end

local function numeric(value)
    return typeof(value) == "number" and value or nil
end

local function display(value)
    if value == nil then return "-" end
    if typeof(value) == "number" then return string.format("%.2f", value) end
    return tostring(value)
end

local function captureRow(elapsed)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local horizontal = nil
    if root and root:IsA("BasePart") then
        local v = root.AssemblyLinearVelocity
        horizontal = Vector3.new(v.X, 0, v.Z).Magnitude
    end
    table.insert(samples, {
        t = elapsed,
        mode = selectedMode,
        stamina = character and numeric(character:GetAttribute("Stamina")) or nil,
        maximum = character and numeric(character:GetAttribute("StaminaMax")) or nil,
        exhausted = character and character:GetAttribute("StaminaOut"),
        sprint = player:GetAttribute("HudSprint"),
        walkSpeed = humanoid and humanoid.WalkSpeed or nil,
        physicalSpeed = horizontal,
        input = humanoid and humanoid.MoveDirection.Magnitude or nil,
    })
end


local function record(key, value, elapsed)
    if typeof(value) == "number" then value = rounded(value) end
    local str = tostring(value)
    if #str > 180 then str = string.sub(str, 1, 180) .. "..." end
    if previous[key] == str then return end
    previous[key] = str
    -- These change quickly and are shown in the timestamped sample table.
    if key == "Character@Stamina" or key == "Character@StaminaMax"
       or key == "Player@HudSprint"
       or key == "Movement.WalkSpeed"
       or key == "Movement.HorizontalSpeed"
       or key == "Movement.InputMagnitude" then
        return
    end
    if #events >= MAX_EVENTS then
        truncated = true
        return
    end
    table.insert(events, string.format("[%.2fs] %s = %s", elapsed, key, str))
end

local function relativePath(object, root)
    if object == root then return "" end
    local parts = {}
    local current = object
    while current and current ~= root do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end
    return "/" .. table.concat(parts, "/")
end

local function indexRoot(root, label)
    if not root then return end
    local objects = root:GetDescendants()
    table.insert(objects, 1, root)
    for _, obj in ipairs(objects) do
        if #watches >= MAX_WATCHES then return end
        if obj ~= gui and not obj:IsDescendantOf(gui) then
            local attrNames = {}
            for name in pairs(obj:GetAttributes()) do
                if isRelevant(name) then
                    table.insert(attrNames, name)
                end
            end
            local matchName = isRelevant(obj.Name)
            if matchName or #attrNames > 0 then
                table.insert(watches, {
                    instance = obj,
                    path = label .. relativePath(obj, root),
                    matchName = matchName,
                    attributes = attrNames,
                })
            end
        end
    end
end

local function rebuildIndex()
    watches = {}
    indexRoot(player, "Player")
    indexRoot(ReplicatedStorage, "ReplicatedStorage")
    indexRoot(player.Character, "Character")
    discovered = math.max(discovered, #watches)
    if #watches >= MAX_WATCHES then watchLimitReached = true end
end

local function takeSample(elapsed)
    for _, entry in ipairs(watches) do
        local obj = entry.instance
        if obj.Parent then
            local path = entry.path
            if entry.matchName then
                if obj:IsA("ValueBase") then
                    record(path .. ".Value", obj.Value, elapsed)
                end
                if obj:IsA("GuiObject") then
                    record(path .. ".Visible", obj.Visible, elapsed)
                    record(path .. ".Size", obj.Size, elapsed)
                end
                if obj:IsA("TextLabel") or obj:IsA("TextButton")
                    or obj:IsA("TextBox") then
                    record(path .. ".Text", obj.Text, elapsed)
                end
            end
            for _, name in ipairs(entry.attributes) do
                local value = obj:GetAttribute(name)
                if value ~= nil then
                    record(path .. "@" .. name, value, elapsed)
                end
            end
        end
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        record("Movement.WalkSpeed", humanoid.WalkSpeed, elapsed)
        record("Movement.InputMagnitude", humanoid.MoveDirection.Magnitude, elapsed)
        record("Movement.State", humanoid:GetState().Name, elapsed)
    end
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if rootPart and rootPart:IsA("BasePart") then
        local velocity = rootPart.AssemblyLinearVelocity
        record("Movement.HorizontalSpeed", Vector3.new(velocity.X, 0, velocity.Z).Magnitude, elapsed)
    end
end

local function buildReport(finished)
    local lines = {
        "=== STAMINA RESEARCH REPORT v1.2 ===",
        "Read-only client-side diagnostic",
        "Game place ID: " .. tostring(game.PlaceId),
        "Animal: Tiger (user-reported; not detected programmatically)",
        "Mode labels: manually selected; not automatically detected",
        "Duration: " .. DURATION .. "s max; sample interval: " .. SAMPLE_INTERVAL .. "s",
        "Status: " .. (finished and "finished/stopped" or "in progress"),
        "Samples: " .. #samples .. "; other changes: " .. #events,
        "Tracked matching objects (peak): " .. tostring(discovered),
        truncated and "WARNING: other-change log truncated" or "",
        watchLimitReached and "WARNING: object-watch limit reached" or "",
        "NOTE: Client-visible values do NOT prove server authority.",
        "",
        "=== MANUAL MODE MARKERS & EXACT STATE TRANSITIONS ==="
    }
    for _, m in ipairs(markers) do table.insert(lines, m) end
    table.insert(lines, "")
    table.insert(lines, "=== PER-MODE STAMINA SUMMARY (approximate; user-marked) ===")
    local summaries, order = {}, {}
    for i = 2, #samples do
        local a, b = samples[i-1], samples[i]
        if a.mode == b.mode and a.stamina and b.stamina then
            local row = summaries[b.mode]
            if not row then
                row = {seconds = 0, spent = 0, recovered = 0}
                summaries[b.mode] = row
                table.insert(order, b.mode)
            end
            local delta = b.stamina - a.stamina
            row.seconds = row.seconds + (b.t - a.t)
            if delta < 0 then row.spent = row.spent - delta
            else row.recovered = row.recovered + delta end
        end
    end
    for _, name in ipairs(order) do
        local q = summaries[name]
        table.insert(lines, string.format(
            "%s: observed %.1fs | stamina spent %.2f | recovered %.2f | avg spent/s %.2f | avg recovered/s %.2f",
            name, q.seconds, q.spent, q.recovered,
            q.seconds > 0 and q.spent / q.seconds or 0,
            q.seconds > 0 and q.recovered / q.seconds or 0
        ))
    end
    table.insert(lines, "")
    table.insert(lines, "=== TIMESTAMPED SAMPLES ===")
    table.insert(lines, "s | user_mode | stamina | max | exhausted | HUD_sprint | WalkSpeed | real_horizontal_speed | input")
    for _, q in ipairs(samples) do
        table.insert(lines, string.format("%.2f | %s | %s | %s | %s | %s | %s | %s | %s",
            q.t, q.mode, display(q.stamina), display(q.maximum),
            display(q.exhausted), display(q.sprint),
            display(q.walkSpeed), display(q.physicalSpeed), display(q.input)))
    end
    table.insert(lines, "")
    table.insert(lines, "=== OTHER CLIENT-VISIBLE CHANGES ===")
    for _, event in ipairs(events) do table.insert(lines, event) end
    table.insert(lines, "")
    table.insert(lines, "=== END OF REPORT ===")
    return table.concat(lines, "\n")
end

local function setStatus(message)
    if gui.Parent then status.Text = "  " .. message end
end

for i, mode in ipairs(modeNames) do
    modeButtons[i].Activated:Connect(function()
        selectedMode = mode
        phaseLabel.Text = "MOVEMENT LABEL: " .. mode .. "  •  manual observation"
        for j, b in ipairs(modeButtons) do
            b.BackgroundColor3 = (j == i) and palette.accent or palette.surface
        end
        mark("USER MODE: " .. mode)
    end)
end

startButton.Activated:Connect(function()
    if running then
        setStatus("Already scanning. Sprint and then rest.")
        return
    end
    running = true
    aborted = false
    truncated = false
    watchLimitReached = false
    events = {}
    previous = {}
    discovered = 0
    watches = {}
    samples = {}
    markers = {}
    disconnectSignals()
    scanStart = os.clock()
    lastReport = ""
    reportBox.Text = "Starting scan..."
    startButton.Text = "Scanning..."
    setStatus("Recording for up to 30 seconds. Sprint, then rest.")

    task.spawn(function()
        local begin = os.clock()
        for step = 0, math.floor(DURATION / SAMPLE_INTERVAL) do
            local elapsed = step * SAMPLE_INTERVAL
            if aborted or not gui.Parent then break end
            local ok, err = pcall(function()
                if elapsed == 0 or elapsed % REINDEX_INTERVAL == 0 then
                    rebuildIndex()
                end
                connectSignals()
                takeSample(elapsed)
                captureRow(elapsed)
            end)
            if not ok then record("DiagnosticError", err, elapsed) end
            lastReport = buildReport(false)
            reportBox.Text = lastReport
            setStatus(string.format("Scanning %.1f/%ds • %s • %d samples", elapsed, DURATION, selectedMode, #samples))
            if elapsed < DURATION then
                task.wait(math.max(0, begin + elapsed + SAMPLE_INTERVAL - os.clock()))
            end
        end
        if gui.Parent then
            running = false
            disconnectSignals()
            lastReport = buildReport(true)
            reportBox.Text = lastReport
            startButton.Text = "Start new scan"
            setStatus(string.format("Report ready: %d samples. Press Copy report.", #samples))
        end
    end)
end)

stopButton.Activated:Connect(function()
    if running then
        aborted = true
        setStatus("Stopping scan. The collected data will remain available.")
    else
        setStatus("No scan running. Start a scan whenever you're ready.")
    end
end)

copyButton.Activated:Connect(function()
    if lastReport == "" then
        setStatus("Start a scan first so there's a report to copy.")
        return
    end
    local clipboard = nil
    if type(setclipboard) == "function" then
        clipboard = setclipboard
    elseif type(toclipboard) == "function" then
        clipboard = toclipboard
    end
    if clipboard then
        local ok = pcall(clipboard, lastReport)
        if ok then
            setStatus("Copied! Paste the report into the chat.")
            return
        end
    end
    reportBox.Text = lastReport
    reportBox:CaptureFocus()
    setStatus("Clipboard unavailable. Click the report, Ctrl+A, Ctrl+C.")
end)

closeButton.Activated:Connect(function()
    aborted = true
    disconnectSignals()
    gui:Destroy()
end)