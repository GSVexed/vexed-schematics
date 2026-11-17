-- FERAL Rest-Only Lab v1.0 | PlaceId 108901361810209
-- Focused follow-up to Recovery Hub v1.3. Does not alter stamina pools,
-- stamina/health configuration, Humanoid.Health, combat flags or needs.
-- Sends only the game's normal own-character WolfActions("Rest", boolean).
-- Local WolfRest pose masking changes appearance only; it is NOT server proof.
-- Both the request switch and the pose mask start OFF.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

if game.PlaceId ~= 108901361810209 then
    warn("[FERAL Rest Lab] Join FERAL first.")
    return
end
local parent = player:WaitForChild("PlayerGui", 10)
if not parent then return end

-- Older panels clean up their owned settings on Destroying. Keep the old
-- script files intact; avoid simultaneous Recovery/Field Hub modifications.
for _, name in ipairs({
    "FeralRestOnlyLabV10", "FeralRecoveryHubV10", "FeralRecoveryHubV11",
    "FeralRecoveryHubV12", "FeralRecoveryHubV13", "FeralFieldHubV10",
    "FeralFieldHubV11", "FeralFieldHubV12", "FeralFieldHubV13",
    "FeralFieldHubV14", "FeralHealthRecoveryV13"
}) do
    local previous = parent:FindFirstChild(name)
    if previous then pcall(function() previous:Destroy() end) end
end

local function finite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end
local function number(value)
    return finite(value) and string.format("%.2f", value) or "-"
end
local knownAnimals = {
    Wolf=true, Fox=true, Deer=true, Elk=true, Bear=true, Cougar=true,
    SnowLeopard=true, Eagle=true, Vulture=true, Falcon=true, Tiger=true,
    Otter=true, Porcupine=true, Bison=true, Hippo=true, Rhino=true,
    Elephant=true, Alligator=true, Python=true, Komodo=true,
    RedPanda=true, Gorilla=true, KingCobra=true, Phantosuchus=true
}
local function own()
    local char = player.Character
    if not char or not char.Parent then return nil end
    return char, char:FindFirstChildOfClass("Humanoid"),
        char:FindFirstChild("HumanoidRootPart")
end
local function ready(char, hum, root)
    if not char or not hum or not root or hum.Health <= 0 then
        return false, "Waiting for a living animal."
    end
    if not knownAnimals[char:GetAttribute("Species")] then
        return false, "Waiting for an active species."
    end
    if char:GetAttribute("FeralDowned") == true then
        return false, "Paused while downed."
    end
    if player:GetAttribute("FeralMenuOpen") == true
        or player:GetAttribute("FeralTitleOpen") == true then
        return false, "Paused in the game menu."
    end
    return true, ""
end
local function sendRest(char, value)
    if not char or player.Character ~= char then return false end
    local remote = ReplicatedStorage:FindFirstChild("WolfActions")
    if not remote or not remote:IsA("RemoteEvent") then return false end
    return pcall(function() remote:FireServer("Rest", value == true) end)
end

local C = {
    bg=Color3.fromRGB(17,23,34), surface=Color3.fromRGB(29,39,54),
    text=Color3.fromRGB(239,245,251), muted=Color3.fromRGB(173,190,210),
    blue=Color3.fromRGB(62,117,208), green=Color3.fromRGB(39,153,119),
    red=Color3.fromRGB(186,71,83)
}
local function ui(className, properties, target)
    local object = Instance.new(className)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = target
    return object
end
local screen = ui("ScreenGui", {
    Name="FeralRestOnlyLabV10", ResetOnSpawn=false, DisplayOrder=98
}, parent)
local panel = ui("Frame", {
    Name="RestLab", AnchorPoint=Vector2.new(.5,.5),
    Position=UDim2.fromScale(.5,.5), Size=UDim2.fromOffset(470,378),
    BackgroundColor3=C.bg, BorderSizePixel=0, Active=true
}, screen)
ui("UICorner", {CornerRadius=UDim.new(0,12)}, panel)
local header = ui("TextLabel", {
    Text="FERAL  /  REST-ONLY LAB v1.0", Position=UDim2.fromOffset(14,7),
    Size=UDim2.fromOffset(350,27), BackgroundTransparency=1,
    TextColor3=C.text, Font=Enum.Font.GothamBold, TextSize=16,
    TextXAlignment=Enum.TextXAlignment.Left, Active=true
}, panel)
local subtitle = ui("TextLabel", {
    Text="Native Rest request • no stamina or HP writes",
    Position=UDim2.fromOffset(14,34), Size=UDim2.fromOffset(440,23),
    BackgroundTransparency=1, TextColor3=C.muted,
    Font=Enum.Font.Gotham, TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left
}, panel)
local function button(title,x,y,w,colour)
    local b = ui("TextButton", {
        Text=title, Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,35), BackgroundColor3=colour or C.blue,
        BorderSizePixel=0, TextColor3=C.text, Font=Enum.Font.GothamBold,
        TextSize=12
    }, panel)
    ui("UICorner", {CornerRadius=UDim.new(0,7)}, b)
    return b
end
local onButton = button("CONTINUOUS REST: OFF",14,65,273,C.blue)
local copyButton = button("COPY REPORT",294,65,162,C.blue)
local status = ui("TextLabel", {
    Text="Ready. Collect a normal baseline before enabling.",
    Position=UDim2.fromOffset(14,107), Size=UDim2.fromOffset(442,45),
    BackgroundTransparency=1, TextColor3=C.text, TextWrapped=true,
    Font=Enum.Font.Gotham, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left
}, panel)
local metrics = ui("TextLabel", {
    Text="Waiting for character...",
    Position=UDim2.fromOffset(14,155), Size=UDim2.fromOffset(442,70),
    BackgroundTransparency=1, TextColor3=C.muted, TextWrapped=true,
    Font=Enum.Font.Code, TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top
}, panel)
local hint = ui("TextLabel", {
    Text="OFF: move with partial stamina for 10s. ON: repeat the same movement. Rest packets are NOT confirmation of server acceptance.",
    Position=UDim2.fromOffset(14,225), Size=UDim2.fromOffset(442,47),
    BackgroundTransparency=1, TextColor3=C.muted, TextWrapped=true,
    Font=Enum.Font.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left
}, panel)
local output = ui("TextBox", {
    Name="ReportFallback", Visible=false, Position=UDim2.fromOffset(14,275),
    Size=UDim2.fromOffset(442,82), BackgroundColor3=C.surface,
    TextColor3=C.text, Font=Enum.Font.Code, TextSize=10,
    MultiLine=true, TextEditable=true, TextWrapped=false,
    ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top
}, panel)
local mini = button("-",389,8,32,C.surface)
local close = button("X",426,8,30,C.red)
mini.Size, close.Size = UDim2.fromOffset(32,25), UDim2.fromOffset(30,25)

local state = {
    alive=true, on=false, char=nil, mask=nil, requestAt=-math.huge,
    lastSample=0, lastUi=0, last=nil, packets=0, failures=0,
    echoes=0, maskWrites=0, cleanup="none", status="No Rest request sent.",
    begun=os.clock(), samples=0, recent={}, groups={}
}
for _, mode in ipairs({"off_still","off_moving","on_still","on_moving"}) do
    state.groups[mode] = {intervals=0, hpN=0, hpSum=0, hpTime=0, hpPositive=0,
        hpDamage=0, stN=0, stSum=0, stTime=0, stPositive=0}
end
local renderName = "FeralRestOnlyMask_" .. tostring(os.time()) ..
    "_" .. tostring(math.random(100000,999999))

local function releaseMask()
    local mask = state.mask
    state.mask = nil
    if not mask then return end
    if mask.changed then pcall(function() mask.changed:Disconnect() end) end
    pcall(function() RunService:UnbindFromRenderStep(renderName) end)
    -- No local attribute reset here: the game owns WolfRest when the mask ends.
end
local function clearSignal()
    local target = state.char
    state.char = nil
    releaseMask()
    if target and player.Character == target then
        state.cleanup = sendRest(target, false) and "Rest=false sent" or "Rest=false failed"
    else
        state.cleanup = target and "Old character gone; no packet sent to replacement"
            or "No owned signal"
    end
end
local function stop(reason)
    state.on = false
    clearSignal()
    state.status = reason or "Switched off."
end
local function beginMask(char)
    if state.mask then return state.mask.char == char end
    local mask = {char=char, writing=false}
    state.mask = mask
    local function enforce()
        if not state.alive or state.mask ~= mask or mask.writing
            or player.Character ~= char or not char.Parent then return end
        if char:GetAttribute("WolfRest") == true then
            state.echoes = state.echoes + 1
            mask.writing = true
            local ok = pcall(function() char:SetAttribute("WolfRest", false) end)
            mask.writing = false
            if ok then
                state.maskWrites = state.maskWrites + 1
            else
                stop("Local pose mask failed; Rest stopped.")
            end
        end
    end
    local ok = pcall(function()
        mask.changed = char:GetAttributeChangedSignal("WolfRest"):Connect(enforce)
        -- The game's WolfAnim rest animation is observed around Camera+2.
        RunService:BindToRenderStep(renderName, 199, enforce)
        enforce()
    end)
    if not ok then releaseMask(); return false end
    return state.mask == mask
end

local function sample(now)
    local char, hum, root = own()
    local speed = 0
    if root then
        local velocity = root.AssemblyLinearVelocity
        speed = Vector3.new(velocity.X,0,velocity.Z).Magnitude
    end
    local burst = char and char:GetAttribute("WolfBurst") == true
    local sprint = player:GetAttribute("HudSprint") == true
    local moving = speed > 1.2 or sprint or burst
    local mode = burst and "Burst" or sprint and "Sprint"
        or moving and "Moving" or "Still"
    local hp = hum and hum.Health or nil
    local maxHp = hum and hum.MaxHealth or nil
    local st = char and char:GetAttribute("Stamina") or nil
    local maxSt = char and char:GetAttribute("StaminaMax") or nil
    local requested = state.on and state.char == char and char ~= nil
    local current = {
        t=now, char=char, hp=hp, maxHp=maxHp, st=st, maxSt=maxSt,
        mode=mode, moving=moving, requested=requested,
        hunger=char and char:GetAttribute("Hunger") or nil,
        thirst=char and char:GetAttribute("Thirst") or nil,
        hudRest=player:GetAttribute("HudRest") == true,
        wolfRest=char and char:GetAttribute("WolfRest") == true
    }
    local previous = state.last
    if previous and previous.char == current.char and current.char
        and previous.requested == requested and previous.moving == moving then
        local dt = now - previous.t
        if dt >= .4 and dt <= 1.6 then
            local group = state.groups[(requested and "on" or "off")
                .. (moving and "_moving" or "_still")]
            group.intervals = group.intervals + 1
            if finite(hp) and finite(previous.hp) and finite(maxHp)
                and maxHp > 0 and maxHp == previous.maxHp
                and previous.hp < maxHp - .05 and hp < maxHp - .05 then
                local dh = hp - previous.hp
                if dh >= -.01 and dh < maxHp * .08 then
                    group.hpN = group.hpN + 1
                    group.hpTime = group.hpTime + dt
                    if dh > 0 then
                        group.hpPositive = group.hpPositive + 1
                        group.hpSum = group.hpSum + dh / maxHp * 100
                    end
                elseif dh < -.01 then
                    group.hpDamage = group.hpDamage + 1
                end
            end
            if finite(st) and finite(previous.st) and finite(maxSt)
                and maxSt > 0 and maxSt == previous.maxSt
                and previous.st < maxSt - .02 and st < maxSt - .02 then
                group.stN = group.stN + 1
                group.stSum = group.stSum + (st - previous.st)
                group.stTime = group.stTime + dt
                if st > previous.st then group.stPositive = group.stPositive + 1 end
            end
        end
    end
    state.last = current
    state.samples = state.samples + 1
    local recent = state.recent
    recent[#recent + 1] = string.format("%0.0fs %s %s HP=%s ST=%s HudRest=%s",
        now - state.begun, requested and "ON" or "OFF", mode,
        number(hp), number(st), tostring(current.hudRest))
    if #recent > 10 then table.remove(recent,1) end
end

local function report()
    local last = state.last or {}
    local lines = {
        "FERAL REST-ONLY LAB v1.0 STATUS",
        "PlaceId: 108901361810209",
        "Elapsed: " .. number(os.clock() - state.begun) .. "s",
        "Rest request switch: " .. (state.on and "ON" or "OFF"),
        "Status: " .. state.status,
        "Rest=true sent: " .. state.packets .. " | failed: " .. state.failures,
        "WolfRest true seen before local masking: " .. state.echoes,
        "Local pose-only WolfRest=false writes: " .. state.maskWrites,
        "Cleanup: " .. state.cleanup,
        "Samples: " .. state.samples,
        "Last: mode=" .. (last.mode or "-") .. " HP=" .. number(last.hp)
            .. "/" .. number(last.maxHp) .. " stamina=" .. number(last.st)
            .. "/" .. number(last.maxSt) .. " hunger=" .. number(last.hunger)
            .. " thirst=" .. number(last.thirst) .. " HudRest="
            .. tostring(last.hudRest),
        "Observed intervals (no write to HP/stamina):"
    }
    for _, key in ipairs({"off_still","off_moving","on_still","on_moving"}) do
        local group = state.groups[key]
        local hpRate = group.hpTime > 0 and number(group.hpSum / group.hpTime) or "-"
        local stRate = group.stTime > 0 and number(group.stSum / group.stTime) or "-"
        lines[#lines+1] = key .. ": intervals=" .. group.intervals
            .. ", HP gain %max/s=" .. hpRate .. " (" .. group.hpPositive .. "/" .. group.hpN .. " positive/valid pairs)"
            .. ", damage pairs=" .. group.hpDamage
            .. ", stamina net/s=" .. stRate .. " (" .. group.stN .. " pairs)"
    end
    lines[#lines+1] = "Recent own-character samples:"
    for _, line in ipairs(state.recent) do lines[#lines+1] = line end
    lines[#lines+1] = "IMPORTANT: Client-visible rates and Rest requests do NOT prove server-accepted Rest, unlimited stamina, or combat healing."
    lines[#lines+1] = "No HP, stamina-pool, needs, combat, or config writes by this lab."
    return table.concat(lines, "\n")
end

local function refresh()
    onButton.Text = state.on and "CONTINUOUS REST: ON" or "CONTINUOUS REST: OFF"
    onButton.BackgroundColor3 = state.on and C.green or C.blue
    status.Text = state.status
    local last = state.last or {}
    metrics.Text = "HP " .. number(last.hp) .. "/" .. number(last.maxHp)
        .. "   Stamina " .. number(last.st) .. "/" .. number(last.maxSt)
        .. "\nMode " .. (last.mode or "-") .. "   HudRest " .. tostring(last.hudRest)
        .. "   WolfRest (local) " .. tostring(last.wolfRest)
        .. "\nRest packets " .. state.packets .. "   Echoes " .. state.echoes
end

onButton.Activated:Connect(function()
    if state.on then stop("Stopped by user. Baseline sampling continues."); refresh(); return end
    local char, hum, root = own()
    local ok, reason = ready(char, hum, root)
    if not ok then state.status=reason; refresh(); return end
    if player:GetAttribute("HudRest") == true or char:GetAttribute("WolfRest") == true then
        state.status="Exit the game's normal Rest first, then enable this lab."
        refresh()
        return
    end
    state.on = true
    state.status = "Armed. Requesting normal Rest, including at full HP/stamina."
    state.requestAt = -math.huge
    refresh()
end)
copyButton.Activated:Connect(function()
    local data = report()
    local fn = type(setclipboard) == "function" and setclipboard
        or type(toclipboard) == "function" and toclipboard or nil
    if fn then
        local ok = pcall(fn, data)
        if ok then state.status="Report copied. Paste into chat."; refresh(); return end
    end
    output.Visible = true
    output.Text = data
    pcall(function() output:CaptureFocus() end)
    state.status="Select report text with Ctrl+A, then Ctrl+C."
    refresh()
end)
local minimized = false
mini.Activated:Connect(function()
    minimized = not minimized
    panel.Size = UDim2.fromOffset(470, minimized and 42 or 378)
    for _, obj in ipairs({subtitle,onButton,copyButton,status,metrics,hint,output}) do
        obj.Visible = not minimized and (obj ~= output or output.Text ~= "")
    end
    mini.Text = minimized and "+" or "-"
end)
local dragging, dragAt, panelAt = false, nil, nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragAt = input.Position; panelAt = panel.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragAt
        panel.Position = UDim2.new(panelAt.X.Scale, panelAt.X.Offset + delta.X,
            panelAt.Y.Scale, panelAt.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
local heartbeat
local function shutdown()
    if not state.alive then return end
    state.alive=false
    stop("Panel closed.")
    if heartbeat then heartbeat:Disconnect() end
end
close.Activated:Connect(function() shutdown(); screen:Destroy() end)
screen.Destroying:Connect(shutdown)
heartbeat = RunService.Heartbeat:Connect(function()
    if not state.alive then return end
    local now = os.clock()
    if now - state.lastSample >= .5 then
        state.lastSample = now
        local ok = pcall(sample, now)
        if not ok then state.status="Sample failed; observations may be incomplete." end
    end
    if state.on and now - state.requestAt >= 5 then
        state.requestAt = now
        local char, hum, root = own()
        local readyNow, reason = ready(char, hum, root)
        if not readyNow then
            if state.char then clearSignal() end
            state.status=reason
        else
            if state.char ~= char then
                clearSignal()
                if not beginMask(char) then
                    stop("Pose mask unavailable; Rest request NOT started.")
                else
                    state.char=char
                end
            end
            if state.on and state.char == char then
                if sendRest(char,true) then
                    state.packets=state.packets+1
                    state.status="Rest=true requested. Moving and full-health requests remain enabled; server response unverified."
                else
                    state.failures=state.failures+1
                    stop("Rest remote unavailable; experiment stopped.")
                end
            end
        end
    end
    if now - state.lastUi >= .25 then
        state.lastUi = now
        pcall(refresh)
    end
end)
refresh()
