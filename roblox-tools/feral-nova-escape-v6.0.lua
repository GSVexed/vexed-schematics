-- FERAL NOVA PRIME v6.0 / Auto Escape
-- Native carry/shake actions are attempted ONLY after own-character cues.
-- Any simulated Space presses are fallback; server acceptance is not assumed.
local Escape = {}
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CAS = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local CUE_NAMES = {
    "grabbed", "beingheld", "heldby", "pinned", "latched",
    "struggling", "constricted", "takedownvictim", "grappledvictim"
}
local CUE_EXCLUDE = {"cooldown", "progress", "available", "chance", "climb", "canescape"}

local function finitePositive(v)
    return type(v) == "number" and v == v and v > 0 and v < 100000
end

local function active(v)
    if v == true then return true end
    if finitePositive(v) then return true end
    if type(v) == "string" then
        local s = string.lower(v)
        return #s > 0 and s ~= "false" and s ~= "none"
            and s ~= "nil" and s ~= "0"
    end
    return typeof(v) == "Instance" and v.Parent ~= nil
end

local function grabbedAttribute(inst)
    if not inst then return false end
    local ok, attrs = pcall(function() return inst:GetAttributes() end)
    if not ok or type(attrs) ~= "table" then return false end
    for key, value in pairs(attrs) do
        if type(key) == "string" and active(value) then
            local lower = string.lower(key)
            local hit = false
            for _, needle in ipairs(CUE_NAMES) do
                if string.find(lower, needle, 1, true) then hit = true; break end
            end
            if hit then
                for _, needle in ipairs(CUE_EXCLUDE) do
                    if string.find(lower, needle, 1, true) then
                        hit = false; break
                    end
                end
            end
            if hit then return true, "grab flag: " .. key end
        end
    end
    return false
end

local function visible(node)
    local steps = 0
    while node and steps < 16 do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") then return node.Enabled end
        node = node.Parent
        steps += 1
    end
    return false
end

local function promptCue(playerGui, ownGui)
    if not playerGui then return false end
    -- Bounded scan; escape UI is checked only after cheaper own-state cues.
    local n = 0
    for _, label in ipairs(playerGui:GetDescendants()) do
        n += 1
        if n > 650 then break end
        if (label:IsA("TextLabel") or label:IsA("TextButton"))
            and (not ownGui or not label:IsDescendantOf(ownGui))
            and visible(label) then
            local msg = string.upper(label.Text or "")
            if #msg >= 6 and #msg <= 150 then
                local hasSpace = string.find(msg, "SPACE", 1, true)
                local context = string.find(msg, "ESCAPE", 1, true)
                    or string.find(msg, "BREAK FREE", 1, true)
                    or string.find(msg, "STRUGGLE", 1, true)
                    or string.find(msg, "GET FREE", 1, true)
                local mash = string.find(msg, "MASH SPACE", 1, true)
                    or string.find(msg, "SPAM SPACE", 1, true)
                    or string.find(msg, "TAP SPACE", 1, true)
                if (hasSpace and context) or mash then
                    return true, "escape prompt"
                end
            end
        end
    end
    return false
end

local function playerJointCue(char)
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local neighbours = {}
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and other.Character then
            local theirs = other.Character:FindFirstChild("HumanoidRootPart")
            if theirs and (root.Position - theirs.Position).Magnitude < 23 then
                neighbours[#neighbours+1] = other.Character
            end
        end
    end
    if #neighbours == 0 then return false end
    local function connected(obj)
        if not (obj:IsA("WeldConstraint") or obj:IsA("Weld") or obj:IsA("Motor6D")) then
            return false
        end
        local a, b = obj.Part0, obj.Part1
        if not a or not b then return false end
        for _, other in ipairs(neighbours) do
            if a:IsDescendantOf(char) and b:IsDescendantOf(other)
                or b:IsDescendantOf(char) and a:IsDescendantOf(other) then
                return true
            end
        end
        return false
    end
    local function scan(model)
        local count = 0
        for _, obj in ipairs(model:GetDescendants()) do
            count += 1
            if count > 380 then break end
            if connected(obj) then return true end
        end
        return false
    end
    if scan(char) then return true, "player latch joint" end
    for i = 1, math.min(#neighbours, 4) do
        if scan(neighbours[i]) then return true, "player latch joint" end
    end
    return false
end

-- Conservative policy: native getoff is tied to own FeralCarried or a
-- confirmed local carry-escape bind. Native shake needs local clamp/shake
-- progress AND an active matching bind. Raw FeralClampN alone is ambiguous.
function Escape.chooseNative(carried, clamp, shakeNeed, carryBind, shakeBind, tugBind)
    if carried == true then return "getoff", "FeralCarried" end
    if carryBind then return "getoff", "FeralCarryEscape" end
    if (finitePositive(clamp) or finitePositive(shakeNeed))
        and (shakeBind or tugBind) then
        return "shake", "active clamp escape"
    end
    return nil, nil
end

function Escape.attach(ctx)
    local E = {
        alive = true, enabled = true, status = "WATCHING", source = "",
        input = "UNAVAILABLE", lastError = "", pulses = 0, nativeCount = 0,
        detections = 0, confirmed = 0, lastScan = 0,
        nativeNext = 0, lastNativeAction = nil, nextPulse = 0,
        expiry = 0, pressed = false, token = 0, lastChar = nil,
        scanInterval = .24, nextReport = 0, lastNativeCue = nil,
        nextNativeScan = 0, nativeState = nil, nativeSource = nil,
        sourceStable = 0, lastSource = nil, fallbackError = 0
    }
    local env
    if type(getgenv) == "function" then
        local ok, e = pcall(getgenv)
        if ok and type(e) == "table" then env = e end
    end
    local kp = (type(keypress) == "function" and keypress)
        or (env and type(env.keypress) == "function" and env.keypress)
    local kr = (type(keyrelease) == "function" and keyrelease)
        or (env and type(env.keyrelease) == "function" and env.keyrelease)
    local press, release
    if type(kp) == "function" and type(kr) == "function" then
        press = function() kp(0x20) end
        release = function() kr(0x20) end
        E.input = "EXECUTOR"
    else
        local ok, virtual = pcall(function()
            return game:GetService("VirtualInputManager")
        end)
        if ok and virtual then
            press = function()
                virtual:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            end
            release = function()
                virtual:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end
            E.input = "VIRTUAL INPUT / UNVERIFIED"
        end
    end
    local pg = player:FindFirstChildOfClass("PlayerGui")

    local function releaseSpace()
        if not E.pressed then return end
        E.pressed = false
        E.token += 1
        if release then pcall(release) end
    end

    local function invalidate()
        E.expiry = 0
        E.nativeState = nil
        E.nativeSource = nil
        E.sourceStable = 0
        E.lastSource = nil
        releaseSpace()
    end

    function E.setEnabled(on)
        E.enabled = on == true
        if E.enabled then
            invalidate()
            E.nextNativeScan = 0
            E.status = "WATCHING"
        else
            invalidate()
            E.status = "OFF"
        end
    end

    function E.report()
        return table.concat({
            "FERAL NOVA PRIME v6 | Auto Escape",
            "enabled=" .. tostring(E.enabled) .. " status=" .. E.status,
            "last_trigger=" .. tostring(E.source),
            "native_requests=" .. tostring(E.nativeCount),
            "space_pulses=" .. tostring(E.pulses),
            "detections=" .. tostring(E.detections),
            "input=" .. E.input,
            "last_error=" .. tostring(E.lastError)
        }, "\n")
    end

    function E.close()
        E.alive = false
        E.setEnabled(false)
        if E.connection then E.connection:Disconnect() end
    end

    local function nativeCue(char)
        local carried = char:GetAttribute("FeralCarried")
        local clamp = char:GetAttribute("FeralClampGame")
        if not finitePositive(clamp) then clamp = char:GetAttribute("FeralClampN") end
        local need = char:GetAttribute("FeralShakeNeed")
        local bindings = {}
        local ok, result = pcall(function() return CAS:GetAllBoundActionInfo() end)
        if ok and type(result) == "table" then bindings = result end
        local action, source = Escape.chooseNative(carried, clamp, need,
            bindings.FeralCarryEscape ~= nil,
            bindings.FeralShakeMash ~= nil,
            bindings.FeralTugTap ~= nil
        )
        if action == E.lastSource then E.sourceStable += 1 else
            E.sourceStable = 1; E.lastSource = action
        end
        -- Attribute is a stronger signal than a bound action.
        -- Binding-only guesses require two consecutive observations.
        if action and (source == "FeralCarried" or E.sourceStable >= 2) then
            return action, source
        end
        return nil, nil
    end

    local function tick()
        if not E.alive or not E.enabled or not ctx.state.alive then return end
        local now = os.clock()
        if UIS:GetFocusedTextBox() then
            invalidate()
            E.status = "CHAT PAUSED"
            return
        end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not char.Parent or not hum or hum.Health <= 0
            or player:GetAttribute("FeralMenuOpen") == true then
            invalidate()
            E.status = "WAITING FOR ANIMAL"
            return
        end
        if E.lastChar ~= char then
            E.lastChar = char
            invalidate()
            E.nextNativeScan = 0
            E.lastScan = 0
        end

        if now >= E.nextNativeScan then
            E.nextNativeScan = now + .23
            E.nativeState, E.nativeSource = nativeCue(char)
        end

        if E.nativeState then
            E.expiry = now + .28
            E.source = E.nativeSource or "native grab state"
            releaseSpace()
            local remote = RS:FindFirstChild("FeralLunge")
            if remote and remote:IsA("RemoteEvent") then
                if E.nativeState ~= E.lastNativeAction then
                    E.nativeNext = 0
                    E.lastNativeAction = E.nativeState
                end
                if now >= E.nativeNext then
                    E.nativeNext = now
                        + (E.nativeState == "getoff" and .43 or .23)
                    local ok, err = pcall(function()
                        remote:FireServer(E.nativeState)
                    end)
                    if ok then
                        E.nativeCount += 1
                        E.status = "NATIVE ESCAPE"
                        return
                    end
                    E.lastError = tostring(err)
                else
                    E.status = "NATIVE ESCAPE"
                    return
                end
            else
                E.lastError = "FeralLunge remote missing"
            end
            -- If native remote is unavailable, try bounded Space fallback.
        else
            E.lastNativeAction = nil
        end

        if now - E.lastScan >= E.scanInterval then
            E.lastScan = now
            local detected, source = grabbedAttribute(char)
            if not detected then detected, source = grabbedAttribute(hum) end
            if not detected then detected, source = grabbedAttribute(player) end
            if not detected and pg then
                local ok, a, b = pcall(promptCue, pg, ctx.ui)
                if ok then detected, source = a, b end
            end
            if not detected then
                local ok, a, b = pcall(playerJointCue, char)
                if ok then detected, source = a, b end
            end
            if detected then
                E.detections += 1
                E.expiry = now + .31
                E.source = source or "grab cue"
            end
        end
        if now > E.expiry then
            releaseSpace()
            E.status = "WATCHING"
            return
        end
        if not press then
            E.status = "INPUT UNAVAILABLE"
            return
        end
        if now < E.nextPulse or E.pressed then return end
        E.nextPulse = now + .125
        local ok, err = pcall(press)
        if not ok then
            E.lastError = tostring(err)
            E.fallbackError += 1
            releaseSpace()
            E.status = "SPACE BLOCKED"
            if E.fallbackError >= 2 then E.setEnabled(false) end
            return
        end
        E.pressed = true
        E.pulses += 1
        E.status = "SPACE ESCAPE"
        E.token += 1
        local token = E.token
        task.delay(.046, function()
            if E.alive and E.token == token then releaseSpace() end
        end)
    end

    E.connection = RunService.Heartbeat:Connect(function()
        local ok, err = pcall(tick)
        if not ok then
            E.lastError = tostring(err)
            invalidate()
            E.status = "DETECTION ERROR"
            E.enabled = false
        end
    end)
    return E
end

return Escape
