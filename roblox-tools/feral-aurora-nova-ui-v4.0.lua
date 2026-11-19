-- FERAL AURORA NOVA v4.0
-- Compact client controls; automatic escape watches explicit grabbed-state cues.
-- Does not assert server-side health, stamina or entitlement changes.
local Module = {}
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local function make(class, props, parent)
    local inst = Instance.new(class)
    for key, value in pairs(props or {}) do inst[key] = value end
    if parent then inst.Parent = parent end
    return inst
end

local function rounded(inst, r)
    make("UICorner", {CornerRadius = UDim.new(0, r or 10)}, inst)
    return inst
end

local function stroke(inst, color, transparency, thickness)
    return make("UIStroke", {
        Color = color, Transparency = transparency or .65,
        Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    }, inst)
end

local function text(parent, value, size, color, weight)
    return make("TextLabel", {
        Text = value, TextSize = size or 12, TextColor3 = color,
        Font = weight and Enum.Font.GothamBold or Enum.Font.Gotham,
        BackgroundTransparency = 1, BorderSizePixel = 0,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, parent)
end

local function button(parent, title, color, callback)
    local b = rounded(make("TextButton", {
        Text = title, TextSize = 12, Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(225, 238, 249),
        BackgroundColor3 = color, BorderSizePixel = 0,
        AutoButtonColor = false, Active = true
    }, parent), 9)
    local line = stroke(b, Color3.fromRGB(170, 205, 222), .82)
    b.MouseEnter:Connect(function()
        if b.Parent then TweenService:Create(line, TweenInfo.new(.12), {Transparency=.3}):Play() end
    end)
    b.MouseLeave:Connect(function()
        if b.Parent then TweenService:Create(line, TweenInfo.new(.12), {Transparency=.82}):Play() end
    end)
    b.Activated:Connect(callback)
    return b
end

local function formatNum(n, decimals)
    if type(n) ~= "number" or n ~= n then return "--" end
    return string.format("%."..tostring(decimals or 0).."f",n)
end

local function truthy(value)
    if value == true then return true end
    if type(value) == "number" then return value > 0 end
    if type(value) == "string" then
        local v = string.lower(value)
        return #v > 0 and v ~= "false" and v ~= "none" and v ~= "0" and v ~= "nil"
    end
    return typeof(value) == "Instance"
end

local function capturedByState(target)
    if not target then return false, nil end
    local ok, attrs = pcall(function() return target:GetAttributes() end)
    if not ok or type(attrs) ~= "table" then return false, nil end
    for key, value in pairs(attrs) do
        local k = string.lower(key)
        local victim = k:find("grabbed",1,true)
            or k:find("beingheld",1,true)
            or k:find("heldby",1,true)
            or k:find("pinned",1,true)
            or k:find("latched",1,true)
            or k:find("struggle",1,true)
            or k:find("constricted",1,true)
            or k:find("takedownvictim",1,true)
            or k:find("escapeactive",1,true)
        -- Explicit victim-state cues only. Climbing, carrying and attack
        -- button holds are NOT evidence that this player is being grabbed.
        if victim and not (k:find("climb",1,true)
            or k:find("cooldown",1,true)
            or k:find("progress",1,true)
            or k:find("available",1,true)) and truthy(value) then
            return true, key
        end
    end
    return false, nil
end


-- A physical latch may use a replicated joint instead of a status flag.
-- Only a real joint connecting OUR body to another player's body counts.
local function capturedByJoint(char)
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false, nil end
    local function connected(obj)
        if not (obj:IsA("WeldConstraint") or obj:IsA("Weld")
            or obj:IsA("Motor6D")) then return false end
        local a, b = obj.Part0, obj.Part1
        if not a or not b then return false end
        if a:IsDescendantOf(char) and not b:IsDescendantOf(char) then return true end
        if b:IsDescendantOf(char) and not a:IsDescendantOf(char) then return true end
        return false
    end
    local function scan(container)
        for _, item in ipairs(container:GetDescendants()) do
            if connected(item) then return true end
        end
        return false
    end
    if scan(char) then return true, "replicated cross-character joint" end
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and other.Character then
            local theirRoot = other.Character:FindFirstChild("HumanoidRootPart")
            if theirRoot and (root.Position - theirRoot.Position).Magnitude < 18 then
                if scan(other.Character) then
                    return true, "nearby player latch joint"
                end
            end
        end
    end
    return false, nil
end

local function visibleLabel(label)
    local node = label
    for _ = 1, 14 do
        if not node then return false end
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") then return node.Enabled end
        node = node.Parent
    end
    return false
end

local function capturedByPrompt(playerGui, ownGui)
    local nodes = playerGui:GetDescendants()
    local checked = 0
    for _, node in ipairs(nodes) do
        if checked >= 900 then break end
        checked += 1
        if (node:IsA("TextLabel") or node:IsA("TextButton"))
            and not node:IsDescendantOf(ownGui) and visibleLabel(node) then
            local msg = string.upper(node.Text or "")
            if #msg > 0 and #msg < 170 then
                local space = msg:find("SPACE", 1, true) ~= nil
                local escape = msg:find("ESCAPE", 1, true)
                    or msg:find("BREAK FREE", 1, true)
                    or msg:find("STRUGGLE", 1, true)
                    or msg:find("GET FREE", 1, true)
                    or msg:find("RELEASE YOURSELF", 1, true)
                local context = string.upper(tostring(node.Name).." "..
                    (node.Parent and tostring(node.Parent.Name) or ""))
                local marked = space and (context:find("ESCAPE",1,true)
                    or context:find("STRUGGLE",1,true)
                    or context:find("GRAPPLE",1,true))
                local mash = msg:find("MASH SPACE", 1, true)
                    or msg:find("SPAM SPACE", 1, true)
                    or msg:find("TAP SPACE REPEATEDLY", 1, true)
                if (space and escape) or mash or marked then
                    return true, "on-screen escape prompt"
                end
            end
        end
    end
    return false, nil
end

function Module.mount(ctx)
    local S, P, c = ctx.state, ctx.power, ctx.palette
    local pg = player:FindFirstChildOfClass("PlayerGui")
        or player:WaitForChild("PlayerGui", 10)
    if not pg then return nil end

    local A = {
        live = true, enabled = true, pressed = false, nextPulse = 0,
        nextCheck = 0, signalUntil = 0, pulses = 0,
        source = "WAITING FOR GRAB", reason = "WATCHING",
        detected = false, inputName = "NOT FOUND", press = nil,
        release = nil, failures = 0, lastError = nil
    }

    local env
    if type(getgenv) == "function" then
        local ok, e = pcall(getgenv)
        if ok and type(e) == "table" then env = e end
    end
    local keyDown = type(keypress) == "function" and keypress
        or env and type(env.keypress) == "function" and env.keypress
        or nil
    local keyUp = type(keyrelease) == "function" and keyrelease
        or env and type(env.keyrelease) == "function" and env.keyrelease
        or nil
    if keyDown and keyUp then
        A.press = function() keyDown(0x20) end
        A.release = function() keyUp(0x20) end
        A.inputName = "EXECUTOR KEYS"
    else
        local ok, vim = pcall(function()
            return game:GetService("VirtualInputManager")
        end)
        if ok and vim then
            A.press = function()
                vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            end
            A.release = function()
                vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end
            A.inputName = "VIRTUAL INPUT (UNVERIFIED)"
        end
    end
    local function releaseSpace()
        if A.pressed then
            A.pressed = false
            if A.release then pcall(A.release) end
        end
    end
    local function stopAuto()
        A.enabled = false
        A.signalUntil = 0
        A.detected = false
        A.reason = "OFF"
        releaseSpace()
    end
    local function automaticTick()
        if not A.live or not A.enabled then return end
        local now = os.clock()
        if UIS:GetFocusedTextBox() then
            A.reason = "CHAT PAUSE"
            A.signalUntil = 0
            releaseSpace()
            return
        end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health <= 0
            or player:GetAttribute("FeralMenuOpen") == true then
            A.reason = "WAITING FOR ANIMAL"
            A.signalUntil = 0
            releaseSpace()
            return
        end
        if now >= A.nextCheck then
            A.nextCheck = now + .20
            local yes, which = capturedByState(char)
            if not yes then yes, which = capturedByState(hum) end
            if not yes then yes, which = capturedByState(player) end
            if not yes then
                local ok, joint, name = pcall(capturedByJoint, char)
                if ok then yes, which = joint, name end
            end
            if not yes then
                local ok, found, name = pcall(capturedByPrompt, pg, ctx.ui)
                if ok then yes, which = found, name end
            end
            A.detected = yes
            if yes then
                A.signalUntil = now + .38
                A.source = which or "grabbed-state cue"
            end
        end
        if now > A.signalUntil then
            A.reason = A.press and "WATCHING" or "INPUT UNAVAILABLE"
            releaseSpace()
            return
        end
        if not A.press then
            A.reason = "INPUT UNAVAILABLE"
            return
        end
        if now < A.nextPulse or A.pressed then return end
        A.nextPulse = now + .125
        local ok, err = pcall(A.press)
        if not ok then
            A.failures += 1
            A.lastError = tostring(err)
            A.reason = "INPUT BLOCKED"
            stopAuto()
            A.reason = "INPUT BLOCKED"
            return
        end
        A.pressed = true
        A.pulses += 1
        A.reason = "ESCAPING"
        task.delay(.047, function()
            releaseSpace()
        end)
    end

    -- Use the previously tested finder/respawn lifecycle. Override only
    -- its presentation, so all Highlight fills are transparent (no glow).
    local originalRefresh = ctx.refreshTracker
    function ctx.refreshTracker(force)
        originalRefresh(force)
        for _, record in pairs(S.byPlayer) do
            if record.h and record.h.Parent then
                record.h.FillTransparency = 1
                record.h.OutlineTransparency = 0
            end
            if record.b and record.b.Parent then
                record.b.Size = UDim2.fromOffset(168, 23)
                record.b.StudsOffsetWorldSpace = Vector3.new(0, 2.65, 0)
                record.b.AlwaysOnTop = S.flags.throughWalls
                local plate = record.name and record.name.Parent
                if plate then
                    plate.BackgroundTransparency = 1
                    for _, child in ipairs(plate:GetChildren()) do
                        if child:IsA("UIStroke") then child.Enabled = false end
                    end
                end
                if record.name then
                    record.name.Position = UDim2.fromOffset(0, 0)
                    record.name.Size = UDim2.fromScale(1, 1)
                    record.name.TextSize = 12
                    record.name.TextXAlignment = Enum.TextXAlignment.Center
                    record.name.TextStrokeColor3 = Color3.fromRGB(2, 8, 15)
                    record.name.TextStrokeTransparency = .15
                end
                if record.info then record.info.Visible = false end
                if record.fill and record.fill.Parent then
                    record.fill.Parent.Visible = false
                end
            end
        end
    end

    local bg = Color3.fromRGB(9, 14, 25)
    local panel = Color3.fromRGB(18, 28, 43)
    local alt = Color3.fromRGB(26, 41, 60)
    local ink = Color3.fromRGB(232, 245, 255)
    local muted = Color3.fromRGB(141, 166, 187)
    local cyan = Color3.fromRGB(68, 228, 217)
    local violet = Color3.fromRGB(158, 133, 255)
    local coral = Color3.fromRGB(255, 126, 133)

    local gui = make("ScreenGui", {
        Name = "FeralAuroraNovaV40", ResetOnSpawn = false,
        DisplayOrder = 191, ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, pg)
    ctx.ui = gui
    make("BindableEvent", {Name = "AuroraShutdown"}, gui).Event:Connect(function()
        ctx.close()
    end)

    local shell = rounded(make("Frame", {
        Size = UDim2.fromOffset(820, 520),
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
        BackgroundColor3 = bg, BorderSizePixel = 0, Active = true
    }, gui), 17)
    stroke(shell, Color3.fromRGB(67, 107, 138), .45, 1)
    make("UIGradient", {
        Rotation = 24, Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 30, 47)),
            ColorSequenceKeypoint.new(.60, bg),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 17, 42))
        })
    }, shell)
    local scaler = make("UIScale", {Scale = 1}, shell)
    local function fit()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 800)
        scaler.Scale = math.clamp(math.min(
            (viewport.X - 18) / 820, (viewport.Y - 38) / 520, 1
        ), .45, 1)
    end
    fit()
    local header = make("Frame", {
        Size = UDim2.new(1, 0, 0, 63),
        BackgroundTransparency = 1, Active = true
    }, shell)
    rounded(make("Frame", {
        Position = UDim2.fromOffset(17, 17),
        Size = UDim2.fromOffset(5, 33),
        BackgroundColor3 = cyan, BorderSizePixel = 0
    }, header), 3)
    local title = text(header, "A U R O R A   N O V A", 21, ink, true)
    title.Position = UDim2.fromOffset(33, 9)
    title.Size = UDim2.fromOffset(335, 30)
    local subtitle = text(header, "FERAL  /  v4.0  /  CONTROL CENTRE", 10, muted)
    subtitle.Position = UDim2.fromOffset(35, 36)
    subtitle.Size = UDim2.fromOffset(340, 18)
    local onBadge = rounded(make("Frame", {
        Position = UDim2.fromOffset(406, 16), Size = UDim2.fromOffset(87, 29),
        BackgroundColor3 = panel, BorderSizePixel = 0
    }, header), 9)
    local onText = text(onBadge, "●  ONLINE", 11, cyan, true)
    onText.Size = UDim2.fromScale(1, 1)
    onText.TextXAlignment = Enum.TextXAlignment.Center

    local connections = {}
    local hidden = false
    local function setHidden(value)
        hidden = value
        shell.Visible = not value
    end
    local showChip = button(gui, "✦  NOVA", panel, function()
        setHidden(false)
    end)
    showChip.Size = UDim2.fromOffset(112, 36)
    showChip.Position = UDim2.fromOffset(15, 210)
    showChip.Visible = false
    local function hide()
        setHidden(not hidden)
        showChip.Visible = hidden
    end
    local hideBtn = button(header, "—", alt, hide)
    hideBtn.Size = UDim2.fromOffset(34, 30)
    hideBtn.Position = UDim2.fromOffset(735, 16)
    local closeBtn = button(header, "×", Color3.fromRGB(91, 41, 62), function()
        ctx.close()
    end)
    closeBtn.Size = UDim2.fromOffset(34, 30)
    closeBtn.Position = UDim2.fromOffset(774, 16)

    local page = "CONTROL"
    local controls = {}
    local root = make("Frame", {
        Position = UDim2.fromOffset(13, 70),
        Size = UDim2.fromOffset(794, 393),
        BackgroundTransparency = 1
    }, shell)
    local controlTab = button(root, "⚡  CONTROL", alt, function()
        page = "CONTROL"
        controls.panel.Visible = true
        controls.espPage.Visible = false
    end)
    controlTab.Position = UDim2.fromOffset(3, 0)
    controlTab.Size = UDim2.fromOffset(147, 36)
    local espTab = button(root, "◎  ESP", panel, function()
        page = "ESP"
        controls.panel.Visible = false
        controls.espPage.Visible = true
    end)
    espTab.Position = UDim2.fromOffset(159, 0)
    espTab.Size = UDim2.fromOffset(125, 36)
    local setup = button(root, "✦  ONE-TAP SETUP", Color3.fromRGB(28, 84, 82), function()
        P.setStamina("RECOVER")
        ctx.toggle("playerFinder", true)
        ctx.toggle("recovery", true)
        A.enabled = true
        ctx.notice("One-tap: 3× client recovery + outlines + auto escape + recovery assist.")
    end)
    setup.Position = UDim2.fromOffset(602, 0)
    setup.Size = UDim2.fromOffset(189, 36)

    -- Resources always visible without opening another tab.
    local statFrame = rounded(make("Frame", {
        Position = UDim2.fromOffset(3, 47),
        Size = UDim2.fromOffset(788, 46),
        BackgroundColor3 = panel, BorderSizePixel = 0
    }, root), 10)
    local statText = {}
    for i, label in ipairs({"HEALTH", "STAMINA", "HUNGER", "THIRST"}) do
        local x = 16 + (i - 1) * 196
        local cap = text(statFrame, label, 10, muted, true)
        cap.Position = UDim2.fromOffset(x, 4)
        cap.Size = UDim2.fromOffset(173, 16)
        local val = text(statFrame, "--", 15, ink, true)
        val.Position = UDim2.fromOffset(x, 21)
        val.Size = UDim2.fromOffset(173, 22)
        statText[i] = val
    end
    local content = make("Frame", {
        Position = UDim2.fromOffset(3, 104),
        Size = UDim2.fromOffset(788, 286),
        BackgroundTransparency = 1
    }, root)
    local controlPage = make("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1
    }, content)
    local espPage = make("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Visible = false
    }, content)
    controls.panel = controlPage
    controls.espPage = espPage

    local function tile(parent, x, y, w, h, caption, detail)
        local frame = rounded(make("Frame", {
            Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
            BackgroundColor3 = panel, BorderSizePixel = 0
        }, parent), 11)
        stroke(frame, Color3.fromRGB(72, 105, 130), .82)
        local name = text(frame, caption, 13, ink, true)
        name.Position = UDim2.fromOffset(13, 7)
        name.Size = UDim2.fromOffset(w - 27, 20)
        local desc = text(frame, detail, 10, muted)
        desc.Position = UDim2.fromOffset(13, 27)
        desc.Size = UDim2.fromOffset(w - 27, 16)
        return frame
    end

    local selections = {}
    local toggles = {}
    local function segment(parent, options, values, y, callback, id)
        local cell = math.floor((parent.AbsoluteSize.X - 26 - (#options - 1) * 7) / #options)
        -- AbsoluteSize can initially be zero before Roblox lays out the GUI.
        cell = cell > 35 and cell or math.floor((parent.Size.X.Offset - 26 - (#options - 1) * 7) / #options)
        for i, label in ipairs(options) do
            local b = button(parent, label, alt, function() callback(values[i]) end)
            b.Position = UDim2.fromOffset(13 + (i-1)*(cell+7), y)
            b.Size = UDim2.fromOffset(cell, 30)
            selections[#selections+1] = {button=b, group=id, value=values[i]}
        end
    end
    local staminaTile = tile(controlPage, 0, 0, 477, 89, "STAMINA CONTROL",
        "Recovery improves local tuning. Apex is aggressive / risky.")
    segment(staminaTile, {"STOCK", "3× RECOVER", "APEX ⚠"},
        {"OFF", "RECOVER", "APEX"}, 51, function(v) P.setStamina(v) end, "stamina")
    local speedTile = tile(controlPage, 0, 99, 477, 89, "MOVEMENT SPEED",
        "Choose once; editable client land and swim speeds.")
    segment(speedTile, {"NORMAL", "SWIFT", "FAST"},
        {1, 1.15, 1.30}, 51, function(v) P.setSpeed(v) end, "speed")
    local leapTile = tile(controlPage, 0, 198, 477, 88, "LEAP DISTANCE",
        "Controls cached animal jump and leap inputs.")
    segment(leapTile, {"NORMAL", "LONG", "MAX"},
        {1, 1.15, 1.35}, 51, function(v) P.setLeap(v) end, "leap")

    local function switch(parent, y, caption, detail, getter, callback, id)
        local frame = tile(parent, 489, y, 299, 64, caption, detail)
        local b = button(frame, "OFF", alt, callback)
        b.Position = UDim2.fromOffset(226, 16)
        b.Size = UDim2.fromOffset(60, 32)
        toggles[id] = {button=b, getter=getter}
        -- Keep the text away from the toggle on the right.
        for _, child in ipairs(frame:GetChildren()) do
            if child:IsA("TextLabel") then
                child.Size = UDim2.fromOffset(207, child.Size.Y.Offset)
            end
        end
        return frame
    end
    switch(controlPage, 0, "AUTO ESCAPE", "No ALT / detects grabs",
        function() return A.enabled end,
        function()
            if A.enabled then stopAuto() else A.enabled=true;A.reason="WATCHING" end
        end, "auto")
    switch(controlPage, 74, "RECOVERY ASSIST", "Native Rest requests",
        function() return S.flags.recovery end,
        function() ctx.toggle("recovery") end, "recovery")
    switch(controlPage, 148, "NIGHT VISIBILITY", "Brighter game lighting",
        function() return S.flags.vision end,
        function() ctx.toggle("vision") end, "vision")
    switch(controlPage, 222, "CALM CAMERA", "Reduce camera shake",
        function() return S.flags.calm end,
        function() ctx.toggle("calm") end, "calm")

    -- ESP keeps the animals looking normal: invisible highlight fill,
    -- narrow stroke, and an unboxed small label above the model.
    local espMaster = tile(espPage, 0, 0, 477, 66, "PLAYER OUTLINES",
        "Real 3D outline • no translucent glow or fill")
    local espMasterButton = button(espMaster, "OFF", alt, function()
        ctx.toggle("playerFinder")
    end)
    espMasterButton.Size = UDim2.fromOffset(85, 34)
    espMasterButton.Position = UDim2.fromOffset(377, 16)
    toggles.esp = {button=espMasterButton, getter=function()
        return S.flags.playerFinder end}
    local espTags = tile(espPage, 0, 76, 477, 66, "NAME TAGS",
        "Small labels above animals • no blocking plates")
    local tagButton = button(espTags, "OFF", alt, function()
        ctx.toggle("tags")
    end)
    tagButton.Size = UDim2.fromOffset(85, 34)
    tagButton.Position = UDim2.fromOffset(377, 16)
    toggles.tags = {button=tagButton, getter=function()return S.flags.tags end}
    local espWalls = tile(espPage, 0, 152, 477, 66, "THROUGH WALLS",
        "Show replicated players through obstacles")
    local wallsButton = button(espWalls, "OFF", alt, function()
        ctx.toggle("throughWalls")
    end)
    wallsButton.Size = UDim2.fromOffset(85, 34)
    wallsButton.Position = UDim2.fromOffset(377, 16)
    toggles.walls = {button=wallsButton, getter=function()
        return S.flags.throughWalls end}
    local rangeTile = tile(espPage, 0, 228, 477, 58, "TRACKING RANGE",
        "")
    segment(rangeTile, {"200", "400", "800"},
        {200, 400, 800}, 24, function(v) ctx.setRange(v) end, "range")
    local nearby = tile(espPage, 489, 0, 299, 286, "NEARBY PLAYERS",
        "Replicated animals only • closest first")
    local nearbyContent = text(nearby, "Enable outlines to see nearby animals.", 12, ink)
    nearbyContent.Position = UDim2.fromOffset(12, 53)
    nearbyContent.Size = UDim2.fromOffset(275, 198)
    nearbyContent.TextXAlignment = Enum.TextXAlignment.Left
    nearbyContent.TextYAlignment = Enum.TextYAlignment.Top
    nearbyContent.TextWrapped = true
    nearbyContent.TextTruncate = Enum.TextTruncate.None
    local nearbyCount = text(nearby, "0 found", 11, cyan, true)
    nearbyCount.Position = UDim2.fromOffset(13, 256)
    nearbyCount.Size = UDim2.fromOffset(269, 21)

    local footer = rounded(make("Frame", {
        Position = UDim2.fromOffset(16, 470),
        Size = UDim2.fromOffset(788, 38),
        BackgroundColor3 = panel, BorderSizePixel = 0
    }, shell), 9)
    local info = text(footer, "AUTO ESCAPE: WATCHING   •   RSHIFT: HIDE", 11, muted)
    info.Position = UDim2.fromOffset(12, 1)
    info.Size = UDim2.fromOffset(584, 36)
    local reset = button(footer, "RESET ALL", Color3.fromRGB(79, 42, 56), function()
        stopAuto()
        ctx.reset()
        ctx.notice("Everything restored. Auto escape OFF.")
    end)
    reset.Position = UDim2.fromOffset(652, 4)
    reset.Size = UDim2.fromOffset(122, 30)

    local dragging, origin, start = false, nil, nil
    connections[#connections+1] = header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            origin = input.Position
            start = shell.Position
        end
    end)
    connections[#connections+1] = UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - origin
            shell.Position = UDim2.new(start.X.Scale, start.X.Offset + delta.X,
                start.Y.Scale, start.Y.Offset + delta.Y)
        end
    end)
    connections[#connections+1] = UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    connections[#connections+1] = UIS.InputBegan:Connect(function(input, processed)
        if processed or UIS:GetFocusedTextBox() then return end
        if input.KeyCode == Enum.KeyCode.RightShift then hide() end
    end)
    connections[#connections+1] = RunService.Heartbeat:Connect(function()
        local ok, err = pcall(automaticTick)
        if not ok and A.live then
            A.failures += 1
            A.lastError = tostring(err)
            if A.failures > 4 then stopAuto(); A.reason = "DETECTION ERROR" end
        end
    end)

    local function active(b, yes)
        b.BackgroundColor3 = yes and Color3.fromRGB(33, 94, 98) or alt
        b.TextColor3 = yes and cyan or ink
    end
    local updateError = false
    ctx.onUI = function()
        local ok, err = pcall(function()
            if not gui.Parent then return end
            local values = ctx.stats()
            statText[1].Text = formatNum(values.hp).." / "..formatNum(values.maxHp)
            statText[2].Text = formatNum(values.stamina, 1).." / "..formatNum(values.maxStamina, 1)
            statText[3].Text = formatNum(values.hunger).."%"
            statText[4].Text = formatNum(values.thirst).."%"
            local state = P.status()
            for _, entry in ipairs(selections) do
                local v = entry.group == "stamina" and state.stamina
                    or entry.group == "speed" and state.speed
                    or entry.group == "leap" and state.leap
                    or S.range
                active(entry.button, v == entry.value)
            end
            for _, entry in pairs(toggles) do
                local yes = entry.getter()
                entry.button.Text = yes and "ON" or "OFF"
                active(entry.button, yes)
            end
            controlTab.BackgroundColor3 = page == "CONTROL" and alt or panel
            espTab.BackgroundColor3 = page == "ESP" and alt or panel
            local mode = values.sessionPhase == "IN GAME"
                and tostring(values.species or "ANIMAL") or "ANIMAL MENU"
            onText.Text = "●  "..(values.sessionPhase == "IN GAME" and "LIVE" or "MENU")
            onText.TextColor3 = cyan
            info.Text = "AUTO ESCAPE  "..A.reason..
                (A.reason == "ESCAPING" and "  •  "..A.source or "")..
                "    •    "..mode.."    •    RSHIFT hide"
            local list = {}
            for i=1, math.min(8, #S.nearby) do
                local x = S.nearby[i]
                list[#list+1] = string.format("%d   %s   [%s]   %d studs",
                    i, tostring(x.name):sub(1,14), tostring(x.species):sub(1,12),
                    math.floor(x.distance+.5))
            end
            nearbyContent.Text = #list > 0 and table.concat(list, "\n")
                or (S.flags.playerFinder and
                    "No replicated animals within range.\n\nOthers may be outside streaming distance."
                    or "Outlines are currently OFF.")
            nearbyCount.Text = tostring(S.finderCounts.shown or 0)..
                " tracked   •   "..tostring(S.range).." studs"
            if shell.Visible then fit() end
        end)
        if not ok and not updateError then
            updateError = true
            warn("[Aurora NOVA] UI refresh failed: "..tostring(err))
        end
    end
    ctx.onNotice = function() end
    ctx.cleanupUI = function()
        A.live = false
        stopAuto()
        for _, connection in ipairs(connections) do
            pcall(function() connection:Disconnect() end)
        end
    end

    -- Arrive usable: ESP on, compact labels off, auto-escape watching.
    -- Other experimental gameplay changes remain deliberately OFF.
    S.flags.tags = false
    ctx.toggle("playerFinder", true)
    ctx.setRange(400)
    ctx.toggle("alerts", false)
    ctx.refreshTracker(true)
    ctx.onUI()
    return gui
end
return Module
