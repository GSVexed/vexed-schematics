-- FERAL Field Hub v1.1 | GSVexed/vexed-schematics
-- For PlaceId 108901361810209. Original UI and client experiments.
-- No gameplay remote calls, purchases, currency spoofing, decompilation, or full scan.
-- Optional client changes are OFF until clicked. They do not grant server ownership.
-- API/compiler checks and offline tests cannot establish Roblox/Velocity compatibility.

-- BEGIN TESTABLE CORE
local Core = {}
function Core.finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end
function Core.number(n, fallback)
    return Core.finite(n) and n or fallback
end
function Core.errorMeta(value)
    local message = type(value) == "string" and value or ""
    local lowered, line = string.lower(message), message:match(":(%d+):")
    local kind = "runtime_error"
    if lowered:find("permission", 1, true) or lowered:find("security", 1, true) then kind = "permission_error"
    elseif lowered:find("readonly", 1, true) or lowered:find("read-only", 1, true) then kind = "readonly_error"
    elseif lowered:find("not a valid member", 1, true) then kind = "missing_member"
    elseif lowered:find("timeout", 1, true) or lowered:find("timed out", 1, true) then kind = "timeout" end
    -- Preserve only fixed categories and a numeric source line, never raw API messages.
    return kind, line and tonumber(line) or nil
end
function Core.patch(target, changes)
    local lease = {target = target, entries = {}}
    for key, wanted in pairs(changes) do
        local readOK, old = pcall(function() return target[key] end)
        if not readOK then
            local failures = Core.restore(lease)
            return nil, "Table read failed; rollback failures: " .. failures .. "."
        end
        if old ~= wanted then
            local ok = pcall(function() target[key] = wanted end)
            if not ok then
                local failures = Core.restore(lease)
                return nil, "Table write failed; rollback failures: " .. failures .. "."
            end
            table.insert(lease.entries, {key = key, old = old, wanted = wanted})
        end
    end
    return lease
end
function Core.restore(lease)
    local failed = 0
    if not lease then return failed end
    for i = #lease.entries, 1, -1 do
        local entry = lease.entries[i]
        local ok = pcall(function()
            -- Preserve changes made by the game or another script after ours.
            if lease.target[entry.key] == entry.wanted then
                lease.target[entry.key] = entry.old
            end
        end)
        if not ok then failed = failed + 1 end
    end
    return failed
end
function Core.hpTarget(health, maximum, dt, perSecond)
    if not (Core.finite(health) and Core.finite(maximum) and Core.finite(dt)
        and Core.finite(perSecond)) then return nil end
    if health <= 0 or maximum <= 0 or health >= maximum or perSecond <= 0 then return nil end
    return math.min(maximum, health + perSecond * math.clamp(dt, 0, 0.25))
end
function Core.bearing(dx, dz, lookX, lookZ)
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance < 0.01 then return 0, "HERE", distance end
    local length = math.sqrt(lookX * lookX + lookZ * lookZ)
    if length < 0.01 then lookX, lookZ, length = 0, -1, 1 end
    lookX, lookZ = lookX / length, lookZ / length
    local forward = dx * lookX + dz * lookZ
    local right = dx * -lookZ + dz * lookX
    local angle = math.deg(math.atan2(right, forward))
    local word = "AHEAD"
    if math.abs(angle) > 150 then word = "BEHIND"
    elseif angle > 30 then word = "RIGHT"
    elseif angle < -30 then word = "LEFT" end
    return angle, word, distance
end
function Core.travelAllowed(plan, character, now, healthy, blocked)
    if not plan then return false, "Scout a landing first." end
    if plan.character ~= character then return false, "Character changed; scout again." end
    if not Core.finite(now) or not Core.finite(plan.at) or now - plan.at < 0 or now - plan.at > 12 then
        return false, "Landing expired; scout again."
    end
    if not healthy then return false, "A living, spawned animal is required." end
    if blocked then return false, "Travel unavailable during combat, carrying, a grab or a fall." end
    return true
end
function Core.supported(sample)
    return sample and sample.measured == true and sample.water == false
        and Core.finite(sample.normalY) and sample.normalY >= math.cos(math.rad(25))
        and Core.finite(sample.supportDelta) and sample.supportDelta <= 1.25
        and sample.clear == true
end
function Core.nodes(root, limit)
    local result, stack = {}, {root}
    while #stack > 0 do
        local item = table.remove(stack)
        result[#result + 1] = item
        if #result > limit then return nil end
        for _, child in ipairs(item:GetChildren()) do
            if #stack + #result >= limit then return nil end
            stack[#stack + 1] = child
        end
    end
    return result
end
function Core.stripClone(root)
    local nodes = Core.nodes(root, 3000)
    if not nodes then return false end
    for _, item in ipairs(nodes) do
        if item:IsA("LuaSourceContainer") or item:IsA("RemoteEvent")
            or item:IsA("RemoteFunction") or item:IsA("BindableEvent")
            or item:IsA("BindableFunction") or item:IsA("ProximityPrompt")
            or item:IsA("ClickDetector") or item:IsA("Sound") then
            item:Destroy()
        elseif item:IsA("BasePart") then
            item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
        end
    end
    return true
end
-- END TESTABLE CORE

local startupCleanup = nil
local startupPhase = "place_check"
local function run()
    if game.PlaceId ~= 108901361810209 then
        warn("[FERAL Hub] Open FERAL PlaceId 108901361810209 first.")
        return
    end
    local Players = game:GetService("Players")
    startupPhase = "services_and_player_gui"
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local player = Players.LocalPlayer
    if not player then warn("[FERAL Hub] LocalPlayer is unavailable."); return end
    local parent = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 8)
    if not parent then warn("[FERAL Hub] PlayerGui is unavailable."); return end
    local name = "FeralFieldHubV11"
    for _, oldName in ipairs({"FeralFieldHubV10", name}) do
        local previous = parent:FindFirstChild(oldName)
        if previous then
            local shutdown = previous:FindFirstChild("HubShutdown")
            if shutdown and shutdown:IsA("BindableEvent") then shutdown:Fire() end
            if previous.Parent then previous:Destroy() end
        end
    end
    local state = {
        alive = true, born = os.clock(), connections = {}, leases = {}, flags = {},
        stamina = false, healthDrops = 0, staminaDrops = 0, rewardPaidNotices = 0,
        serverReplies = {}, rewardStateSeen = false, rewardObserver = false,
        hidden = false, menus = false, light = nil, errors = 0, samples = {},
        cache = {}, cacheBusy = {}, cacheWaiters = {}, selectedAsset = nil, selectedSpecies = nil,
        selectedCoat = nil, clone = nil, coatLease = nil, previewEpoch = 0,
        travelEpoch = 0, scoutBusy = false, plan = nil, returnSpot = nil,
        travelWatch = nil, currentPage = "LIVE", moduleJobs = 0,
        target = {name = "Oasis / The spring", x = 1070, z = 1505},
        moduleStatus = "No game modules loaded by the hub.", staminaEpoch = 0, menuEpoch = 0,
    }
    local C = {
        bg = Color3.fromRGB(15, 23, 29), surface = Color3.fromRGB(24, 36, 44),
        line = Color3.fromRGB(47, 67, 77), text = Color3.fromRGB(236, 244, 239),
        muted = Color3.fromRGB(157, 182, 182), green = Color3.fromRGB(38, 143, 112),
        blue = Color3.fromRGB(42, 101, 145), amber = Color3.fromRGB(204, 159, 69),
        red = Color3.fromRGB(162, 67, 79),
    }
    local function new(class, props, owner)
        local item = Instance.new(class)
        for k, v in pairs(props or {}) do item[k] = v end
        if owner then item.Parent = owner end
        return item
    end
    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        state.connections[#state.connections + 1] = connection
        return connection
    end
    local function round(item, radius)
        new("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, item)
        return item
    end
    local function label(owner, content, size, height, color)
        return new("TextLabel", {
            BackgroundTransparency = 1, Text = content, RichText = false,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center, Font = Enum.Font.Gotham,
            TextColor3 = color or C.text, TextSize = size or 13,
            Size = UDim2.new(1, 0, 0, height or 30),
        }, owner)
    end
    local function button(owner, content, color, height)
        return round(new("TextButton", {
            BackgroundColor3 = color or C.blue, BorderSizePixel = 0,
            Text = content, RichText = false, TextWrapped = true,
            Font = Enum.Font.GothamBold, TextColor3 = C.text, TextSize = 12,
            Size = UDim2.new(1, 0, 0, height or 34), AutoButtonColor = true,
        }, owner))
    end
    local function list(owner, padding)
        new("UIListLayout", {Padding = UDim.new(0, padding or 8), SortOrder = Enum.SortOrder.LayoutOrder}, owner)
    end
    local function card(owner, title, body)
        local f = round(new("Frame", {
            BackgroundColor3 = C.surface, BorderSizePixel = 0,
            Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        }, owner))
        new("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}, f)
        list(f, 7)
        local head = label(f, title, 14, 25)
        head.Font = Enum.Font.GothamBold
        if body then
            local text = label(f, body, 12, 0, C.muted)
            text.AutomaticSize = Enum.AutomaticSize.Y
        end
        return f
    end
    startupPhase = "creating_panel"
    local gui = new("ScreenGui", {
        Name = name, ResetOnSpawn = false, DisplayOrder = 850, IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, parent)
    local shutdownEvent = new("BindableEvent", {Name = "HubShutdown"}, gui)
    startupCleanup = function()
        state.alive = false
        for _, connection in ipairs(state.connections) do connection:Disconnect() end
        if gui.Parent then gui:Destroy() end
    end
    local panel = round(new("Frame", {
        Name = "Panel", Size = UDim2.fromOffset(780, 594), Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.bg, BorderSizePixel = 0,
        Active = true,
    }, gui), 12)
    new("UIStroke", {Color = C.line, Thickness = 1}, panel)
    local scale = new("UIScale", {}, panel)
    local title = label(panel, "FERAL  /  FIELD HUB", 18, 28)
    title.Font = Enum.Font.GothamBold
    title.Position, title.Size, title.Active = UDim2.fromOffset(18, 13), UDim2.fromOffset(520, 28), true
    local subtitle = label(panel, "v1.1   LIVE DATA  /  LOCAL EXPERIMENTS  /  ANIMAL STUDIO", 10, 22, C.muted)
    subtitle.Position, subtitle.Size = UDim2.fromOffset(18, 40), UDim2.fromOffset(640, 22)
    local hide = button(panel, "_", C.blue)
    hide.Position, hide.Size = UDim2.fromOffset(688, 16), UDim2.fromOffset(32, 30)
    local close = button(panel, "X", C.red)
    close.Position, close.Size = UDim2.fromOffset(731, 16), UDim2.fromOffset(32, 30)
    local reopen = button(gui, "FERAL HUB", C.green)
    reopen.AnchorPoint, reopen.Position, reopen.Size = Vector2.new(1, 1), UDim2.new(1, -18, 1, -22), UDim2.fromOffset(120, 38)
    reopen.Visible = false
    local status = label(panel, "Ready. Nothing is changed until you choose a control.", 11, 30, C.muted)
    status.Position, status.Size = UDim2.fromOffset(18, 554), UDim2.fromOffset(744, 30)
    local function say(message, errorFlag)
        if not state.alive then return end
        status.Text = tostring(message)
        status.TextColor3 = errorFlag and C.amber or C.muted
    end
    local function failure(context, details)
        state.errors = state.errors + 1
        local kind, line = Core.errorMeta(details)
        state.lastError = context .. " / " .. kind .. " / line " .. tostring(line or "unavailable")
        say(state.lastError .. ". The affected action stopped.", true)
    end
    local function action(control, callback)
        connect(control.Activated, function()
            if not state.alive then return end
            local ok, details = pcall(callback)
            if not ok then failure(control.Name ~= "TextButton" and control.Name or "Action", details) end
        end)
    end
    local tabs, pages = {}, {}
    local function page(key, index)
        local tab = button(panel, key, C.surface, 33)
        tab.Size, tab.Position = UDim2.fromOffset(117, 33), UDim2.fromOffset(18 + (index - 1) * 125, 74)
        local f = new("ScrollingFrame", {
            Name = key, BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.fromOffset(18, 120), Size = UDim2.fromOffset(748, 424),
            ScrollBarThickness = 5, ScrollBarImageColor3 = C.green,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y, Visible = index == 1,
        }, panel)
        new("UIPadding", {PaddingRight = UDim.new(0, 9), PaddingBottom = UDim.new(0, 12)}, f)
        list(f, 10)
        pages[key], tabs[key] = f, tab
        action(tab, function()
            state.currentPage = key
            for name1, frame in pairs(pages) do
                frame.Visible = name1 == key
                tabs[name1].BackgroundColor3 = name1 == key and C.green or C.surface
            end
        end)
        return f
    end
    local livePage = page("LIVE", 1)
    local resourcePage = page("RESOURCES", 2)
    local travelPage = page("TRAVEL", 3)
    local animalPage = page("ANIMALS", 4)
    local coatsPage = page("COATS", 5)
    local infoPage = page("FINDINGS", 6)
    tabs.LIVE.BackgroundColor3 = C.green
    local function own()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        return char, hum, root
    end
    local function world()
        return ReplicatedStorage:FindFirstChild("FeralWorld")
    end
    local function optional(name1)
        if name1 == "getloadedmodules" and type(getloadedmodules) == "function" then return getloadedmodules end
        if name1 == "setclipboard" and type(setclipboard) == "function" then return setclipboard end
        if name1 == "toclipboard" and type(toclipboard) == "function" then return toclipboard end
        if name1 == "writefile" and type(writefile) == "function" then return writefile end
        if type(getgenv) == "function" then
            local ok, env = pcall(getgenv)
            if ok and type(env) == "table" and type(env[name1]) == "function" then return env[name1] end
        end
        return nil
    end
    local function cachedModule(name1, callback)
        if state.cache[name1] then callback(state.cache[name1]); return end
        if state.cacheBusy[name1] then
            -- One consumer per named module; the latest request supersedes stale toggles/selections.
            state.cacheWaiters[name1] = callback
            say("Still checking " .. name1 .. "; the panel remains usable.")
            return
        end
        local fw = world()
        local target = fw and fw:FindFirstChild(name1)
        local getLoaded = optional("getloadedmodules")
        if not (target and target:IsA("ModuleScript") and getLoaded) then
            say(name1 .. " needs an already-loaded module and getloadedmodules support.", true)
            callback(nil)
            return
        end
        state.cacheBusy[name1] = true
        state.cacheWaiters[name1] = callback
        state.moduleJobs = state.moduleJobs + 1
        local started = os.clock()
        say("Checking the already-loaded " .. name1 .. " cache...")
        task.delay(6, function()
            if state.alive and state.cacheBusy[name1] then
                say(name1 .. " cache check is still waiting; no duplicate job will be started.", true)
            end
        end)
        task.spawn(function()
            local ok, value = pcall(function()
                local loaded = getLoaded()
                if type(loaded) ~= "table" then return nil end
                local found, count = false, 0
                for _, module in pairs(loaded) do
                    count = count + 1
                    if module == target then found = true; break end
                    if count > 100000 or not state.alive then return nil end
                    if count % 512 == 0 then task.wait() end
                end
                if not found or not state.alive then return nil end
                -- Never require an unconfirmed/new game module. This target is already loaded.
                return require(target)
            end)
            state.cacheBusy[name1] = nil
            local waiting = state.cacheWaiters[name1]
            state.cacheWaiters[name1] = nil
            if not state.alive then return end
            if ok and type(value) == "table" then
                state.cache[name1] = value
                state.moduleStatus = name1 .. " read from the loaded cache."
                local callOK, details = pcall(waiting, value)
                if not callOK then failure(name1 .. " consumer", details) end
            else
                say("Cannot read " .. name1 .. " from the loaded cache. No new module was started.", true)
                if not ok then
                    local kind, line = Core.errorMeta(value)
                    state.lastError = name1 .. " cache / " .. kind .. " / line " .. tostring(line or "unavailable")
                end
                local callOK, details = pcall(waiting, nil)
                if not callOK then failure(name1 .. " unavailable handler", details) end
            end
            if os.clock() - started > 6 then state.moduleStatus = name1 .. " cache response was delayed." end
        end)
    end

    startupPhase = "creating_live_and_resource_controls"
    local statsCard = card(livePage, "YOUR ANIMAL", "Reads only your current character. The panel remains available in the animal menu and after respawning.")
    local animalStats = label(statsCard, "Waiting for a spawned animal...", 14, 30)
    local hpStats = label(statsCard, "Health: —", 15, 27)
    local staminaStats = label(statsCard, "Stamina: —", 15, 27)
    local needsStats = label(statsCard, "Growth / hunger / thirst: —", 13, 30)
    local movementStats = label(statsCard, "Position / movement: —", 12, 28, C.muted)
    local rateStats = label(statsCard, "Observed changes: waiting for samples.", 11, 29, C.muted)
    local effectsCard = card(livePage, "WHY AM I SLOW OR LOSING RESOURCES?", "Observed attributes and configured effects; no buff, currency or growth is granted by this panel.")
    local effectsText = label(effectsCard, "No character loaded.", 12, 0)
    effectsText.AutomaticSize = Enum.AutomaticSize.Y
    local walletCard = card(livePage, "AMBER & OWNERSHIP", "Changing the displayed wallet does not establish spendable amber. Native reward claims can grant earned rewards when the server accepts them. Animal and coat ownership remain checked by the game.")
    local walletText = label(walletCard, "Visible amber: —", 13, 27)
    local openRewards = button(walletCard, "OPEN GAME REWARDS — CLAIM EARNED AMBER")
    local observeReplies = button(walletCard, "OBSERVE NORMAL REWARD / PURCHASE REPLIES", C.surface)
    state.nativeRewardsText = label(walletCard, "No automatic claims or purchases. Open the native rewards UI and use its CLAIM buttons.", 11, 48, C.muted)
    local allowedReplies = {
        FeralRewards = {state = true, paid = true},
        FeralSlots = {sync = true, bought = true, poor = true, coatBought = true, coatPoor = true},
    }
    local observedRemotes = {}
    local function observeNativeReplies()
        local count = 0
        for remoteName, allowed in pairs(allowedReplies) do
            local remote = ReplicatedStorage:FindFirstChild(remoteName)
            if remote and remote:IsA("RemoteEvent") then
                count = count + 1
                if observedRemotes[remoteName] ~= remote then
                    if observedRemotes[remoteName .. "Connection"] then
                        observedRemotes[remoteName .. "Connection"]:Disconnect()
                    end
                    observedRemotes[remoteName] = remote
                    observedRemotes[remoteName .. "Connection"] = connect(remote.OnClientEvent, function(kind)
                        -- Deliberately omit ALL payload arguments, including free-form error text.
                        if not state.alive or type(kind) ~= "string" or not allowed[kind] then return end
                        state.serverReplies[#state.serverReplies + 1] = remoteName .. ":" .. kind
                        while #state.serverReplies > 12 do table.remove(state.serverReplies, 1) end
                        if remoteName == "FeralRewards" and kind == "state" then state.rewardStateSeen = true end
                        if remoteName == "FeralRewards" and kind == "paid" then state.rewardPaidNotices = state.rewardPaidNotices + 1 end
                        if kind == "poor" or kind == "coatPoor" then
                            say("The native purchase returned " .. kind .. ". Its client handler treats this as insufficient amber.", true)
                        end
                    end)
                end
            end
        end
        state.rewardObserver = count > 0
        return count
    end
    action(observeReplies, function()
        local count = observeNativeReplies()
        say("Watching " .. count .. " named native reply channels. Only known event labels are recorded; payloads are omitted.")
    end)
    action(openRewards, function()
        observeNativeReplies()
        -- The recovered FeralRewardsUI listens to this UI request attribute.
        -- Its existing implementation handles eligibility, hello and claim requests.
        local previousRequest = player:GetAttribute("FeralRewardsRequest")
        local request = os.clock()
        if request == previousRequest then request = request + 0.001 end
        player:SetAttribute("FeralRewardsRequest", request)
        say("Native reward UI requested. Use its CLAIM buttons for earned rewards; no automatic claim or payment was sent by the hub.")
    end)
    local evidenceCard = card(livePage, "SMALL STATUS REPORT", "Optional report of this hub's state and your visible resources. No full diagnostic, usernames, account IDs, chat or other players' data.")
    local copyReport = button(evidenceCard, "COPY HUB STATUS")
    local saveReport = button(evidenceCard, "SAVE HUB STATUS .TXT", C.surface)

    local staminaCard = card(resourcePage, "CLIENT STAMINA TUNING", "Targets the cached NeedsConfig used by WolfController, plus its WolfDbgNoStamina character flag. It avoids the old approach of repeatedly changing the HUD Stamina attribute. Reported working by the user on Bear in v1.0. Coverage of other species, costs and server acceptance remains unverified.")
    local staminaToggle = button(staminaCard, "STAMINA TUNING: OFF", C.blue)
    local staminaDetail = label(staminaCard, "Off. No stamina fields or flags changed.", 12, 45, C.muted)
    local hpCard = card(resourcePage, "HEALTH — MONITOR ONLY", "The v1.0 local HP trial rose and was overwritten in the user's test. That failed writer is retired in v1.1. Health and status effects are observed; no working regeneration or invulnerability is claimed.")
    local hpDetail = label(hpCard, "No health-writing loop or regeneration toggle in this version.", 12, 34, C.muted)
    local visualCard = card(resourcePage, "LOCAL VISIBILITY", "A small colour-correction effect for your screen. It does not reveal unreplicated objects or change the server's weather.")
    local lightToggle = button(visualCard, "BRIGHTER VIEW: OFF", C.blue)
    local stopAll = button(resourcePage, "STOP EXPERIMENTS & RESTORE LOCAL SETTINGS", C.red, 39)

    local function releaseFlag(char)
        local lease = state.flags[char]
        if not lease then return end
        local ok = pcall(function()
            if lease.changed and char:GetAttribute("WolfDbgNoStamina") == true then
                char:SetAttribute("WolfDbgNoStamina", lease.old)
            end
        end)
        if not ok then state.errors = state.errors + 1 end
        state.flags[char] = nil
    end
    local function flagCharacter(char)
        if not char or state.flags[char] then return end
        local old = char:GetAttribute("WolfDbgNoStamina")
        state.flags[char] = {old = old, changed = old ~= true}
        if old ~= true then char:SetAttribute("WolfDbgNoStamina", true) end
    end
    local function stopStamina()
        state.stamina, state.staminaEpoch = false, state.staminaEpoch + 1
        local failed = Core.restore(state.leases.stamina)
        state.leases.stamina = nil
        for char in pairs(state.flags) do releaseFlag(char) end
        staminaToggle.Text, staminaToggle.BackgroundColor3 = "STAMINA TUNING: OFF", C.blue
        staminaDetail.Text = failed == 0 and "Off. Owned settings restored; later external changes preserved."
            or "Off. Some setting restorations failed; rejoin to reset the client module cache."
        state.errors = state.errors + failed
    end
    action(staminaToggle, function()
        if state.stamina then stopStamina(); return end
        state.stamina, state.staminaEpoch = true, state.staminaEpoch + 1
        local epoch = state.staminaEpoch
        flagCharacter(player.Character)
        staminaToggle.Text, staminaToggle.BackgroundColor3 = "STAMINA TUNING: ON — FIELD-REPORTED ON BEAR", C.green
        staminaDetail.Text = "Character flag active. Checking the loaded controller configuration..."
        cachedModule("NeedsConfig", function(config)
            if not state.alive or not state.stamina or state.staminaEpoch ~= epoch then return end
            if not config then staminaDetail.Text = "Flag only. Cached tuning unavailable; sprint coverage is unverified."; return end
            local changes = {
                STAMINA_SPRINT_DRAIN = 0, STAMINA_JUMP_COST = 0,
                STAMINA_REGEN = 250, STAMINA_REGEN_DELAY = 0, STAMINA_LOW_NEEDS = 1,
            }
            for key in pairs(changes) do
                if not Core.finite(config[key]) then
                    staminaDetail.Text = "Flag only. Cached configuration does not match the expected numeric fields."
                    return
                end
            end
            local lease, reason = Core.patch(config, changes)
            state.leases.stamina = lease
            staminaDetail.Text = lease and "Cached client drain/regen fields tuned; character flag active. Judge actual movement, not just the bar."
                or ("Flag only. " .. reason)
        end)
    end)
    local function stopLight()
        if state.light then pcall(function() state.light:Destroy() end); state.light = nil end
        lightToggle.Text, lightToggle.BackgroundColor3 = "BRIGHTER VIEW: OFF", C.blue
    end
    action(lightToggle, function()
        if state.light then stopLight(); return end
        state.light = new("ColorCorrectionEffect", {
            Name = "FeralHubLocalLight", Brightness = 0.12, Contrast = -0.07, Saturation = 0.02,
        }, game:GetService("Lighting"))
        lightToggle.Text, lightToggle.BackgroundColor3 = "BRIGHTER VIEW: ON", C.green
    end)

    startupPhase = "creating_travel_controls"
    local navCard = card(travelPage, "OASIS / THE SPRING — NORMAL POI", "A normal POI at X 1070, Z 1505. No special protection or healing is established. Compass guidance works without moving your character.")
    local destinationLabel = label(navCard, "Destination: Oasis / The spring", 14, 30)
    local navText = label(navCard, "Spawn an animal to see distance and direction.", 14, 39)
    local scoutButton = button(navCard, "1  /  SCOUT A LANDING — NO MOVEMENT")
    local travelButton = button(navCard, "2  /  MOVE ONCE TO CHECKED LANDING (EXPERIMENTAL)", C.red, 40)
    local travelText = label(navCard, "No landing checked. Travel never starts automatically.", 12, 58, C.muted)
    local returnButton = button(navCard, "SCOUT RETURN TO LAST DEPARTURE", C.surface)
    local mapCard = card(travelPage, "DESTINATIONS", "Landing checks use streamed geometry, slope, water, body clearance and ground support. They cannot establish absence of enemies, hazards, future map changes or server correction.")
    local spots = {
        {name = "Oasis / The spring", x = 1070, z = 1505},
        {name = "Canyon arch", x = 818, z = 1432},
        {name = "Canyon mouth", x = 835, z = 1225},
        {name = "Golden Waterhole", x = -240, z = 300},
        {name = "Eagle Rock", x = 711, z = -105},
        {name = "Great Falls", x = 15, z = -504},
        {name = "Frost Lake", x = 30, z = -990},
    }
    local function setTarget(spot)
        state.target, state.plan, state.travelEpoch = spot, nil, state.travelEpoch + 1
        destinationLabel.Text = "Destination: " .. spot.name
        travelText.Text = "Destination changed. Scout a new landing before moving."
    end
    for _, spot in ipairs(spots) do
        local b = button(mapCard, spot.name .. "  /  " .. spot.x .. ", " .. spot.z, C.surface, 31)
        action(b, function() setTarget(spot) end)
    end
    action(returnButton, function()
        if not state.returnSpot then say("No departure saved yet.", true); return end
        setTarget({name = "Last departure", x = state.returnSpot.X, z = state.returnSpot.Z})
        say("Return destination selected. Scout it before moving.")
    end)
    local function blocked(char, root)
        local combatUntil = Core.number(player:GetAttribute("FeralCombatUntil"), 0)
        if combatUntil > workspace:GetServerTimeNow() then return true end
        for _, key in ipairs({"FeralPinned", "FeralBurrowed", "FeralVenomDown", "CarriedBy", "FeralDragged", "FeralRider", "FeralLatching"}) do
            local value = char:GetAttribute(key)
            if value ~= nil and value ~= false and value ~= 0 and value ~= "" then return true end
        end
        return root.AssemblyLinearVelocity.Magnitude > 8
    end
    local function landingAt(char, x, z)
        local boxCF, size = char:GetBoundingBox()
        if size.X > 100 or size.Y > 100 or size.Z > 160 then return nil end
        local ray = RaycastParams.new()
        ray.FilterType, ray.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {char}
        ray.IgnoreWater = false
        -- Failure to support collision-respecting queries stops the landing check.
        ray.RespectCanCollide = true
        local hit = workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -4000, 0), ray)
        if not hit then return nil end
        if hit.Material == Enum.Material.Water or hit.Normal.Y < math.cos(math.rad(25)) then return nil end
        local ancestor = hit.Instance:FindFirstAncestorOfClass("Model")
        if ancestor and ancestor:FindFirstChildOfClass("Humanoid") then return nil end
        local center = Vector3.new(x, hit.Position.Y + size.Y / 2 + 0.85, z)
        local destinationBox = CFrame.new(center) * boxCF.Rotation
        if workspace:Raycast(Vector3.new(x, hit.Position.Y + 0.4, z), Vector3.new(0, size.Y + 1, 0), ray) then
            return nil
        end
        local maximumDelta = 0
        for _, sign in ipairs({Vector2.new(-1, -1), Vector2.new(-1, 1), Vector2.new(1, -1), Vector2.new(1, 1)}) do
            local localPoint = Vector3.new(sign.X * size.X * 0.45, -size.Y / 2, sign.Y * size.Z * 0.45)
            local supportPoint = destinationBox:PointToWorldSpace(localPoint)
            local support = workspace:Raycast(supportPoint + Vector3.new(0, 3, 0), Vector3.new(0, -7, 0), ray)
            if not support or support.Material == Enum.Material.Water
                or support.Normal.Y < math.cos(math.rad(25)) then return nil end
            maximumDelta = math.max(maximumDelta, math.abs(support.Position.Y - hit.Position.Y))
        end
        local overlap = OverlapParams.new()
        overlap.FilterType, overlap.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {char}
        overlap.RespectCanCollide, overlap.MaxParts = true, 32
        local colliders = workspace:GetPartBoundsInBox(destinationBox, size + Vector3.new(1, 0.3, 1), overlap)
        local sample = {measured = true, water = false, normalY = hit.Normal.Y,
            supportDelta = maximumDelta, clear = #colliders == 0}
        if not Core.supported(sample) then return nil end
        return {pivot = destinationBox * boxCF:ToObjectSpace(char:GetPivot()), x = x, z = z,
            floorY = hit.Position.Y, size = size, position = center}
    end
    action(scoutButton, function()
        if state.scoutBusy then say("A scout is already running; wait for its result."); return end
        local char, hum, root = own()
        if not (char and hum and root and hum.Health > 0 and type(char:GetAttribute("Species")) == "string") then
            say("Spawn an animal before scouting.", true); return
        end
        state.scoutBusy, state.plan, state.travelEpoch = true, nil, state.travelEpoch + 1
        local epoch, target = state.travelEpoch, state.target
        travelText.Text = "Requesting nearby scenery (up to 5 seconds), then checking loaded geometry..."
        task.spawn(function()
            local ok, result = pcall(function()
                pcall(function() player:RequestStreamAroundAsync(Vector3.new(target.x, root.Position.Y, target.z), 5) end)
                if not state.alive or epoch ~= state.travelEpoch or player.Character ~= char then return nil end
                local offsets = {Vector2.new(0, 0)}
                for _, radius in ipairs({8, 16, 28}) do
                    for i = 0, 7 do
                        local angle = math.pi * i / 4
                        offsets[#offsets + 1] = Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius)
                    end
                end
                for i, offset in ipairs(offsets) do
                    if not state.alive or epoch ~= state.travelEpoch or player.Character ~= char then return nil end
                    local candidate = landingAt(char, target.x + offset.X, target.z + offset.Y)
                    if candidate then return candidate end
                    if i % 4 == 0 then task.wait() end
                end
                return nil
            end)
            state.scoutBusy = false
            if not state.alive or epoch ~= state.travelEpoch then return end
            if ok and result then
                result.character, result.at, result.target = char, os.clock(), target
                state.plan = result
                travelText.Text = string.format("Landing checked at %.0f, %.1f, %.0f. Valid for 12 seconds. Movement remains experimental; this is not a protected area.", result.x, result.floorY, result.z)
                say("Landing ready. Moving is a separate button and rechecks the destination.")
            else
                state.plan = nil
                travelText.Text = "No suitable landing established in loaded geometry. No movement performed. Try again when closer."
                if not ok then failure("Landing check", result) end
            end
        end)
    end)
    action(travelButton, function()
        local char, hum, root = own()
        local plan = state.plan
        local healthy = char and hum and root and hum.Health > 0 and char:GetAttribute("FeralDead") ~= true
        local permitted, reason = Core.travelAllowed(plan, char, os.clock(), healthy, healthy and blocked(char, root))
        if not permitted then say(reason, true); return end
        local current = landingAt(char, plan.x, plan.z)
        state.plan = nil
        if not current or math.abs(current.floorY - plan.floorY) > 1 then
            travelText.Text = "Destination changed or could not be revalidated. No movement performed."; return
        end
        state.returnSpot = root.Position
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
        char:PivotTo(current.pivot)
        state.travelWatch = {character = char, at = os.clock(), position = current.position, health = hum.Health}
        travelText.Text = "One local movement attempted. Monitoring position and health for 4 seconds; server acceptance and safety are unverified."
        say("Departure saved. No automatic movement retries.")
    end)

    startupPhase = "creating_animal_studio"
    local animalsCard = card(animalPage, "ANIMAL STUDIO", "Browse all locally replicated portrait assets, including available restricted-animal assets. These are script-stripped local clones; a preview is not a playable spawn or ownership unlock.")
    local assetSearch = new("TextBox", {
        Text = "", PlaceholderText = "Search portraits — tiger, snow, phanto, baby...",
        ClearTextOnFocus = false, BackgroundColor3 = C.bg, TextColor3 = C.text,
        PlaceholderColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 13,
        Size = UDim2.new(1, 0, 0, 33), BorderSizePixel = 0,
    }, animalsCard)
    round(assetSearch)
    local refreshAssets = button(animalsCard, "REFRESH PORTRAITS", C.surface, 29)
    local assetCount = label(animalsCard, "No portrait scan run yet.", 11, 25, C.muted)
    local stage = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 270)}, animalsCard)
    local assetList = new("ScrollingFrame", {
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Size = UDim2.new(0.34, -7, 1, 0),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
    }, stage)
    list(assetList, 4)
    local viewport = new("ViewportFrame", {
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Position = UDim2.new(0.34, 3, 0, 0),
        Size = UDim2.new(0.66, -3, 1, 0), Ambient = Color3.fromRGB(180, 180, 180),
        LightColor = Color3.fromRGB(255, 240, 210), LightDirection = Vector3.new(-1, -1, -1),
    }, stage)
    round(viewport)
    local previewWorld = new("WorldModel", {Name = "HubPreviewWorld"}, viewport)
    local previewCamera = new("Camera", {FieldOfView = 32}, viewport)
    viewport.CurrentCamera = previewCamera
    local previewText = label(animalsCard, "Select a portrait. No gameplay spawn request will be sent.", 12, 43, C.muted)
    local rotateButton = button(animalsCard, "ROTATE PREVIEW", C.surface, 29)
    local menuToggle = button(animalsCard, "NATIVE MENU CARD VISIBILITY: OFF", C.blue, 36)
    local menuText = label(animalsCard, "Optional cached HIDE_LOCKED flag only. Owner/tester and server checks remain unchanged; reopen the native menu to refresh it.", 11, 45, C.muted)
    local orbit, assets = 0.75, {}
    local speciesNames = {"Phantosuchus", "SnowLeopard", "KingCobra", "Porcupine", "Elephant", "Alligator", "RedPanda", "Gorilla", "Vulture", "Falcon", "Cougar", "Python", "Komodo", "Tiger", "Hippo", "Rhino", "Bison", "Otter", "Bear", "Wolf", "Fox", "Elk", "Eagle"}
    local function speciesOf(assetName)
        local lowered = string.lower(assetName)
        if lowered:match("^doe") or lowered:match("^buck") then return "Deer" end
        if lowered:match("^eaglet") then return "Eagle" end
        for _, species in ipairs(speciesNames) do
            if lowered:sub(1, #species) == string.lower(species) then return species end
        end
        return nil
    end
    local function aimPreview()
        if not state.clone then return end
        local cf, size
        if state.clone:IsA("Model") then cf, size = state.clone:GetBoundingBox()
        elseif state.clone:IsA("BasePart") then cf, size = state.clone.CFrame, state.clone.Size
        else return end
        local aspect = math.max(viewport.AbsoluteSize.X, 1) / math.max(viewport.AbsoluteSize.Y, 1)
        local extent = math.max(size.Y, size.X / math.max(aspect, 0.3), size.Z)
        local distance = extent / (2 * math.tan(math.rad(previewCamera.FieldOfView / 2))) + size.Magnitude * 0.2
        previewCamera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(math.sin(orbit), 0.22, math.cos(orbit)).Unit * distance, cf.Position)
    end
    local function clonePortrait(asset)
        if not Core.nodes(asset, 3000) then say("Portrait exceeds the 3,000-node preview budget.", true); return end
        local clone = asset:Clone()
        if not clone then say("Portrait cannot be cloned.", true); return end
        if not Core.stripClone(clone) then clone:Destroy(); say("Portrait exceeded the clone budget.", true); return end
        if state.clone then state.clone:Destroy() end
        if clone:IsA("Model") then clone:PivotTo(CFrame.new())
        elseif clone:IsA("BasePart") then clone.CFrame = CFrame.new() end
        -- Scripts and interactive objects were removed BEFORE parenting.
        clone.Parent, state.clone = previewWorld, clone
        state.selectedAsset, state.selectedSpecies = asset, speciesOf(asset.Name)
        state.selectedCoat = nil
        local restriction = state.selectedSpecies == "Phantosuchus" and "OWNER ONLY"
            or state.selectedSpecies == "SnowLeopard" and "TESTERS ONLY" or "Gameplay access not checked"
        previewText.Text = asset.Name .. "  /  " .. restriction .. "  /  LOCAL PREVIEW"
        aimPreview()
        return true
    end
    local assetConnections = {}
    local function clearAssetButtons()
        for _, connection in ipairs(assetConnections) do connection:Disconnect() end
        table.clear(assetConnections)
        for _, child in ipairs(assetList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    end
    local function renderAssets()
        clearAssetButtons()
        local needle, count = string.lower(assetSearch.Text):sub(1, 80), 0
        for _, asset in ipairs(assets) do
            if string.find(string.lower(asset.Name), needle, 1, true) then
                count = count + 1
                if count <= 256 then
                    local b = button(assetList, asset.Name, C.surface, 28)
                    assetConnections[#assetConnections + 1] = b.Activated:Connect(function()
                        if state.alive then
                            local ok, details = pcall(clonePortrait, asset)
                            if not ok then failure("Portrait preview", details) end
                        end
                    end)
                end
            end
        end
        assetCount.Text = string.format("%d replicated portrait assets / %d matches%s", #assets, count,
            count > 256 and " / first 256 displayed; refine search" or "")
    end
    local function refreshPortraits()
        assets = {}
        local fw = world()
        local folder = fw and fw:FindFirstChild("Portraits")
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                if item:IsA("Model") or item:IsA("BasePart") then assets[#assets + 1] = item end
            end
        end
        table.sort(assets, function(a, b) return a.Name < b.Name end)
        renderAssets()
        if #assets == 0 then say("No replicated portrait assets found. Try refresh after the game menu loads.", true) end
    end
    action(refreshAssets, refreshPortraits)
    connect(assetSearch:GetPropertyChangedSignal("Text"), renderAssets)
    action(rotateButton, function() orbit = orbit + math.pi / 4; aimPreview() end)
    connect(viewport:GetPropertyChangedSignal("AbsoluteSize"), function() pcall(aimPreview) end)
    local function stopMenuPatch()
        state.menus, state.menuEpoch = false, state.menuEpoch + 1
        state.errors = state.errors + Core.restore(state.leases.menu)
        state.leases.menu = nil
        menuToggle.Text, menuToggle.BackgroundColor3 = "NATIVE MENU CARD VISIBILITY: OFF", C.blue
    end
    action(menuToggle, function()
        if state.menus then stopMenuPatch(); return end
        state.menus, state.menuEpoch = true, state.menuEpoch + 1
        local epoch = state.menuEpoch
        menuToggle.Text = "CHECKING LOADED ACCESS CONFIG..."
        cachedModule("AccessConfig", function(config)
            if not state.alive or not state.menus or state.menuEpoch ~= epoch then return end
            if not config or type(config.HIDE_LOCKED) ~= "boolean" then stopMenuPatch(); return end
            local lease = Core.patch(config, {HIDE_LOCKED = false})
            if not lease then stopMenuPatch(); return end
            state.leases.menu = lease
            menuToggle.Text, menuToggle.BackgroundColor3 = "HIDDEN CARDS VISIBLE — ACCESS UNCHANGED", C.green
            menuText.Text = "Reopen the native animal menu. Phantosuchus remains owner-only; Snow Leopard remains tester-only. No unlock or spawn has been established."
        end)
    end)

    startupPhase = "creating_coat_studio"
    local coatCard = card(coatsPage, "COAT STUDIO", "Read coat definitions from the already-loaded CoatConfig. Choose an animal portrait first, then load its coats. Local appearance trials do not grant ownership, paid passes or other players' visibility.")
    local loadCoats = button(coatCard, "LOAD COATS FOR SELECTED PORTRAIT")
    local coatInfo = label(coatCard, "Select a portrait in ANIMALS first.", 12, 43, C.muted)
    local coatList = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, coatCard)
    list(coatList, 5)
    local wearButton = button(coatCard, "TRY SELECTED COAT LOCALLY ON MY MATCHING ANIMAL", C.blue, 39)
    local resetCoat = button(coatCard, "RESTORE MY LOCAL COAT", C.surface)
    local coatConnections = {}
    local function clearCoats()
        for _, connection in ipairs(coatConnections) do connection:Disconnect() end
        table.clear(coatConnections)
        for _, child in ipairs(coatList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    end
    local function resetLocalCoat()
        local lease = state.coatLease
        state.coatLease = nil
        if not lease then return end
        local ok = pcall(function()
            if lease.applied and lease.applied.Parent == lease.part then lease.applied:Destroy() end
            if lease.original and lease.original.Parent == lease.stash and lease.part.Parent
                and not lease.part:FindFirstChildOfClass("SurfaceAppearance") then
                lease.original.Parent = lease.part
            end
            Core.restore(lease.textureLease)
            if lease.stash then lease.stash:Destroy() end
        end)
        if not ok then state.errors = state.errors + 1 end
    end
    local function meshOf(root)
        local nodes = Core.nodes(root, 3000)
        if not nodes then return nil end
        local fallback = nil
        for _, part in ipairs(nodes) do
            if part:IsA("MeshPart") then
                if part:FindFirstChildOfClass("SurfaceAppearance") then return part end
                fallback = fallback or part
            end
        end
        return fallback
    end
    local function appearanceFor(sp, coat, assetName)
        local fw = world()
        local coats = fw and fw:FindFirstChild("Coats")
        local family = coats and coats:FindFirstChild(sp)
        local folder = family and family:FindFirstChild(coat.id)
        local template = folder and folder:FindFirstChild(assetName)
        if not template then
            local config = state.cache.CoatConfig
            local alias = config and config.TEMPLATE_ALIAS and config.TEMPLATE_ALIAS[assetName]
            template = alias and folder and folder:FindFirstChild(alias)
        end
        if template and template:IsA("SurfaceAppearance") then return template end
        return nil
    end
    local function paintLocal(root, sp, coat, assetName, personal)
        local mesh = meshOf(root)
        if not mesh then return false, "No suitable mesh." end
        local original = mesh:FindFirstChildOfClass("SurfaceAppearance")
        local template = appearanceFor(sp, coat, assetName)
        local texture = type(coat.textures) == "table" and coat.textures[assetName]
        if original and (template or type(coat.recolor) == "string") then
            local replacement = (template or original):Clone()
            if not replacement or not Core.stripClone(replacement) then
                if replacement then replacement:Destroy() end
                return false, "Appearance clone failed."
            end
            replacement:SetAttribute("FeralRecolor", coat.recolor)
            replacement:SetAttribute("FeralCoat", coat.id)
            local stash = new("Folder", {Name = "HubCoatBackup"}, gui)
            local lease = {part = mesh, original = original, applied = replacement, stash = stash}
            -- Install the cleanup record before changing either parent.
            if personal then
                state.coatLease = lease
            end
            local committed = pcall(function()
                original.Parent = stash
                replacement.Parent = mesh
            end)
            if not committed then
                if replacement.Parent then replacement:Destroy() end
                if original.Parent == stash then original.Parent = mesh end
                stash:Destroy()
                if personal then state.coatLease = nil end
                return false, "Appearance swap failed and restoration was attempted."
            end
            if not personal then stash:Destroy() end
            return true, coat.recolor and "Local recolor metadata applied; renderer support is unverified." or "Local surface appearance applied."
        elseif type(texture) == "string" and #texture < 200 then
            local lease = Core.patch(mesh, {TextureID = texture})
            if not lease then return false, "Texture property is not writable." end
            if personal then state.coatLease = {part = mesh, textureLease = lease} end
            return true, "Local texture applied."
        end
        return false, "No compatible replicated texture or surface for this model; no tint substituted."
    end
    action(loadCoats, function()
        local sp, asset = state.selectedSpecies, state.selectedAsset
        if not sp or not asset then say("Select an animal portrait first.", true); return end
        clearCoats()
        state.selectedCoat = nil
        cachedModule("CoatConfig", function(config)
            if not state.alive or state.selectedAsset ~= asset then return end
            local definitions = config and type(config.LIST) == "table" and config.LIST[sp]
            if type(definitions) ~= "table" then coatInfo.Text = "No coat definitions available for " .. sp .. "."; return end
            local count = 0
            for _, coat in ipairs(definitions) do
                if type(coat) == "table" and type(coat.id) == "string" and count < 100 then
                    count = count + 1
                    local b = button(coatList, tostring(coat.name or coat.id) .. "  /  " .. coat.id .. "  /  preview", C.surface, 30)
                    coatConnections[#coatConnections + 1] = b.Activated:Connect(function()
                        if not state.alive then return end
                        local ok, details = pcall(function()
                            if not clonePortrait(asset) then return end
                            state.selectedCoat = {species = sp, definition = coat, asset = asset}
                            local applied, reason = paintLocal(state.clone, sp, coat, asset.Name, false)
                            coatInfo.Text = sp .. " / " .. tostring(coat.name or coat.id) .. ": " .. reason
                            if not applied then say(reason, true) end
                        end)
                        if not ok then failure("Coat preview", details) end
                    end)
                end
            end
            coatInfo.Text = sp .. ": showing " .. count .. " of " .. #definitions
                .. " coat entries" .. (#definitions > 100 and " (100-entry UI limit)" or "")
                .. ". Select one; view it in ANIMALS. Ownership is unchanged."
        end)
    end)
    action(wearButton, function()
        local selected = state.selectedCoat
        local char, hum = own()
        if not selected or not char or not hum or hum.Health <= 0 then say("Select a coat and spawn a matching animal first.", true); return end
        if char:GetAttribute("Species") ~= selected.species then say("The selected coat belongs to a different species.", true); return end
        resetLocalCoat()
        local assetName = char:GetAttribute("Model")
        if type(assetName) ~= "string" then
            local mesh = meshOf(char)
            assetName = mesh and mesh.Name or selected.asset.Name
        end
        local applied, reason = paintLocal(char, selected.species, selected.definition, assetName, true)
        coatInfo.Text = reason .. " Ownership and other players' views are unchanged or unverified."
        say(applied and "Local coat trial applied. RESTORE and closing the hub undo owned appearance changes." or reason, not applied)
    end)
    action(resetCoat, function() resetLocalCoat(); say("Owned local coat changes restored where still applicable.") end)

    startupPhase = "creating_findings_and_cleanup"
    local discoveries = {
        {"Stamina ownership", "CLIENT LOGIC", "WolfController maintains a private stamina accumulator and publishes attributes. Attribute-only refills can be overwritten by that same client, so snapback alone does not establish server rejection."},
        {"Health authority", "UNRESOLVED", "Client snapshots do not contain the server health writer. A visible local health increase is not proof of accepted healing."},
        {"Grab timing", "CLIENT LOGIC", "One Space-based tug handler ignores intervals below 0.1s. Another struggle uses direction prompts with a 0.15s minimum gap. Space spam is not a universal escape method."},
        {"Restricted animals", "CONFIG + MENU", "Phantosuchus is owner-only; Snow Leopard is tester-only. HIDE_LOCKED controls visibility. OFF was empty in the captured AccessConfig. Local cards do not establish spawn permission."},
        {"Oasis POI", "CONFIG LOCATION + USER OBSERVATION", "AdminConfig labels this POI Hidden oasis / The spring at X1070 Z1505. The user has already visited it normally. The label does not establish a secret, protected or healing area."},
        {"Rest and status recovery", "CONFIG + UI", "Injury, bleeding and venom have separate effects and configured 4x rest recovery. Ordinary health rest regeneration is configured separately."},
        {"Thriving", "CONFIG + UI", "A growth boost configured at +50%, with a 600-second cap. Hunting, eating, drinking and quests are named ways to build it. The server grant rules were not collected."},
        {"Regrowth", "CONFIG + UI", "A configured 2x regrowth bonus, capped at five minutes. The HUD tracks FeralRegrowLeft and FeralRegrowTotal. Eligibility and server grants were not verified."},
        {"Home turf and grazing", "CONFIG + UI", "Home turf specifies +10% damage and 5 amber per held hex per five minutes. Grazing specifies +20% damage and 10 amber per minute. Stacking is unverified."},
        {"Survival bonus", "CONFIG + UI", "Multiplier starts at x1, adds 0.1 per ten minutes until x2, then per fifteen minutes until x3. The client display accounts for an idle state; server payout was not tested."},
        {"Climbing levels", "CONFIG + CLIENT", "Climbing levels distinguish draining, cost-free and faster/regenerating movement. Cougar, Snow Leopard, Red Panda and Gorilla are in the grade-3 map; Tiger was absent from that particular map."},
        {"Vulture Death Sense", "CONFIG + CLIENT", "Configured for targets below 40% HP within 260 studs, including through-wall outlines. It is an existing Vulture mechanic, not enabled for all animals by this hub."},
        {"Baby carrying", "CONFIG", "Carrier growth >=0.67, target growth <0.34, same species and additional conditions. Same-pack status affects a spawn-safety check rather than being universally required."},
        {"Fox burrows", "CONFIG + CLIENT", "Multiple holes, digging materials, underground movement and a 15-second configured oxygen budget. Burrowing is not unlimited protection."},
        {"Diving", "CONFIG + CLIENT", "Air budget scales with growth. Separate no-drown fields do not establish unlimited underwater movement for every species."},
        {"Bird combat", "CONFIG + CLIENT", "Talon locking, spinning struggles and crashes have dedicated systems. Falcon dive-bomb text links impact speed with damage and a temporary knockout."},
        {"Cobra variants", "CONFIG + CLIENT", "Spit, throw and hiss event branches exist. KingsStrike also contains VARIANTS=false. Which variants the live server permits is unverified."},
        {"Anti-teaming", "CONFIG", "GANG is configured on with DMG=0.6 and a WEAKER BITES warning. Its notification is disabled. Actual server application was not observed."},
        {"Scavenger birds", "CONFIG + CLIENT", "Carcass state and food position drive client crow effects. Visual scavengers are separate from a proof of server food rules."},
        {"Weather and water", "CONFIG + CLIENT", "Drought lists drying ponds and a winter exclusion. Flood configuration includes areas and fish settings; reconstructed tables have fidelity limitations."},
        {"Littermates", "DISABLED CONFIG", "LitterConfig.ENABLED=false. Onboarding text refers to a version-specific littermate system. This is not proof of an upcoming release."},
        {"Disabled quest templates", "DISABLED CONFIG", "Some amber, fawn-hunt, timed-survival and daily-rest templates are disabled. Related mechanics and quick-rest quests are not all disabled."},
        {"Other hidden switches", "CONFIG", "NPC territory claiming is disabled in one branch. A Bison update banner is off. Recolor UI is hidden, although coats are enabled. These switches do not grant server features."},
        {"Coat variants", "CONFIG + ASSETS", "Black Panther, Florida Panther, Spirit Bear, Harpy Eagle and albino variants are coat entries. Local texture trials do not establish paid ownership."},
        {"Voices and cinematics", "CONFIG + CLIENT", "Calls use growth-dependent pitch. A staged growth film has newborn, teen, adult and elder scenes; some reconstructed film configuration is damaged."},
        {"Developer gifts", "CONFIG + CLIENT", "A developer-only gift interface handles amber/revives. Finding its client interface does not grant permission or prove gifts can be forged."},
    }
    local findingsSearch = new("TextBox", {
        Text = "", PlaceholderText = "Search findings — stamina, growth, hidden, cobra...",
        ClearTextOnFocus = false, BackgroundColor3 = C.surface, TextColor3 = C.text,
        PlaceholderColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 13,
        Size = UDim2.new(1, -4, 0, 34), BorderSizePixel = 0,
    }, infoPage)
    round(findingsSearch)
    local findingCards = {}
    for _, entry in ipairs(discoveries) do
        local f = card(infoPage, entry[1] .. "  /  " .. entry[2], entry[3])
        findingCards[#findingCards + 1] = {frame = f, text = string.lower(table.concat(entry, " "))}
    end
    connect(findingsSearch:GetPropertyChangedSignal("Text"), function()
        local needle = string.lower(findingsSearch.Text):sub(1, 100)
        for _, entry in ipairs(findingCards) do entry.frame.Visible = string.find(entry.text, needle, 1, true) ~= nil end
    end)

    local function stopExperiments()
        stopStamina()
        stopLight()
        stopMenuPatch()
        resetLocalCoat()
        state.plan, state.travelEpoch = nil, state.travelEpoch + 1
    end
    action(stopAll, function() stopExperiments(); say("Experiments stopped. Owned settings restored; completed movement is not reversed.") end)
    local function shutdown(skipDestroy)
        if not state.alive then return end
        pcall(stopExperiments)
        state.alive = false
        clearAssetButtons()
        clearCoats()
        if state.cameraConnection then state.cameraConnection:Disconnect(); state.cameraConnection = nil end
        for _, connection in ipairs(state.connections) do connection:Disconnect() end
        table.clear(state.connections)
        if not skipDestroy and gui.Parent then gui:Destroy() end
    end
    startupCleanup = shutdown
    connect(shutdownEvent.Event, shutdown)
    action(close, shutdown)
    connect(gui.Destroying, function() shutdown(true) end)
    action(hide, function() panel.Visible, reopen.Visible = false, true end)
    action(reopen, function()
        panel.Position = UDim2.fromScale(0.5, 0.5)
        panel.Visible, reopen.Visible = true, false
    end)
    connect(UIS.InputBegan, function(input, processed)
        if not processed and not UIS:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.RightShift then
            panel.Visible = not panel.Visible
            reopen.Visible = not panel.Visible
            if panel.Visible then panel.Position = UDim2.fromScale(0.5, 0.5) end
        end
    end)
    local drag = nil
    connect(title.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = {start = input.Position, position = panel.Position}
        end
    end)
    connect(UIS.InputChanged, function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - drag.start
            panel.Position = UDim2.new(drag.position.X.Scale, drag.position.X.Offset + delta.X,
                drag.position.Y.Scale, drag.position.Y.Offset + delta.Y)
        end
    end)
    connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drag = nil end
    end)
    local function fit()
        local camera = workspace.CurrentCamera
        if camera then
            local view = camera.ViewportSize
            scale.Scale = math.clamp(math.min((view.X - 24) / 780, (view.Y - 70) / 594), 0.35, 1.1)
        end
    end
    local function bindCamera()
        if state.cameraConnection then state.cameraConnection:Disconnect(); state.cameraConnection = nil end
        local camera = workspace.CurrentCamera
        if camera then state.cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
        fit()
    end
    connect(workspace:GetPropertyChangedSignal("CurrentCamera"), bindCamera)
    bindCamera()
    connect(player.CharacterRemoving, function(char)
        releaseFlag(char)
        resetLocalCoat()
        state.plan, state.travelWatch, state.travelEpoch = nil, nil, state.travelEpoch + 1
        table.clear(state.samples)
    end)

    local function formatNumber(value)
        return Core.finite(value) and string.format("%.1f", value) or "—"
    end
    local function report()
        local char, hum = own()
        return table.concat({
            "FERAL FIELD HUB v1.1 — client status only",
            "PlaceId: 108901361810209",
            "Uptime seconds: " .. math.floor(os.clock() - state.born),
            "Species: " .. tostring(char and char:GetAttribute("Species") or "not spawned"),
            "Health: " .. formatNumber(hum and hum.Health) .. " / " .. formatNumber(hum and hum.MaxHealth),
            "Stamina: " .. formatNumber(char and char:GetAttribute("Stamina")) .. " / " .. formatNumber(char and char:GetAttribute("StaminaMax")),
            "Stamina tuning: " .. tostring(state.stamina),
            "Field result: v1.0 stamina reported working on Bear; local HP refill overwritten.",
            "Cached stamina tuning applied: " .. tostring(state.leases.stamina ~= nil),
            "Local HP writer: retired; no health writes in v1.1",
            "Health decreases observed: " .. state.healthDrops,
            "Stamina decreases observed: " .. state.staminaDrops .. " (decreases alone do not identify the writer)",
            "Native reward state seen: " .. tostring(state.rewardStateSeen),
            "Native reward paid notices: " .. state.rewardPaidNotices,
            "Recent server reply types: " .. table.concat(state.serverReplies, ", "),
            "Hidden card visibility patch: " .. tostring(state.leases.menu ~= nil),
            "Local coat trial: " .. tostring(state.coatLease ~= nil),
            "Errors: " .. state.errors,
            "Last error: " .. tostring(state.lastError or "none"),
            "Module status: " .. state.moduleStatus,
            "Native reward UI shortcut only; arbitrary amber, permanent unlock, accepted healing and restricted spawn remain unestablished.",
            "The hub sends no gameplay remotes or purchases. Native UI actions retain the game's normal requests.",
            "No server-only code, reply payloads, other players' data or credentials collected.",
        }, "\n")
    end
    action(copyReport, function()
        local copy = optional("setclipboard") or optional("toclipboard")
        if not copy then say("Clipboard API unavailable. Use SAVE HUB STATUS instead.", true); return end
        local ok, details = pcall(copy, report())
        if ok then say("Hub status copied.") else failure("Clipboard", details) end
    end)
    action(saveReport, function()
        local write = optional("writefile")
        if not write then say("writefile unavailable. The hub itself does not need file access.", true); return end
        local filename = "FERAL_Field_Hub_Status_" .. tostring(os.time()) .. ".txt"
        local ok, details = pcall(write, filename, report())
        if ok then say("Saved " .. filename .. " in the executor workspace; disk read-back is not verified.")
        else failure("Status file write", details) end
    end)
    startupPhase = "binding_live_updates"
    local lastChar, sampleAccumulator = nil, 0
    local function tick(dt)
        local char, hum, root = own()
        if char ~= lastChar then
            if lastChar then releaseFlag(lastChar) end
            table.clear(state.samples)
            lastChar = char
        end
        if state.stamina and char then flagCharacter(char) end
        sampleAccumulator = sampleAccumulator + dt
        if sampleAccumulator < 0.25 then return end
        sampleAccumulator = 0
        local now = os.clock()
        local stamina = char and char:GetAttribute("Stamina")
        local maximum = char and char:GetAttribute("StaminaMax")
        animalStats.Text = tostring(char and char:GetAttribute("Species") or "Animal menu / no character")
            .. "  /  " .. tostring(char and char:GetAttribute("AgeStage") or "stage unavailable")
        hpStats.Text = "HEALTH   " .. formatNumber(hum and hum.Health) .. " / " .. formatNumber(hum and hum.MaxHealth)
        staminaStats.Text = "STAMINA   " .. formatNumber(stamina) .. " / " .. formatNumber(maximum)
        local growth = char and char:GetAttribute("Growth")
        needsStats.Text = "Growth " .. (Core.finite(growth) and string.format("%.1f%%", growth * 100) or "—")
            .. "   Hunger " .. formatNumber(char and char:GetAttribute("Hunger"))
            .. "   Thirst " .. formatNumber(char and char:GetAttribute("Thirst"))
        if root then
            local p = root.Position
            movementStats.Text = string.format("Position %.0f, %.0f, %.0f   /   speed %.1f studs/s", p.X, p.Y, p.Z, root.AssemblyLinearVelocity.Magnitude)
            local camera = workspace.CurrentCamera
            local look = camera and camera.CFrame.LookVector or root.CFrame.LookVector
            local angle, direction, distance = Core.bearing(state.target.x - p.X, state.target.z - p.Z, look.X, look.Z)
            navText.Text = string.format("%.0f studs horizontally   /   %s   /   camera bearing %+.0f°", distance, direction, angle)
        else
            movementStats.Text, navText.Text = "Spawn an animal to see position.", "Spawn an animal for navigation."
        end
        walletText.Text = "Visible amber: " .. formatNumber(player:GetAttribute("Amber")) .. "  /  server spending power not modified"
        local lines = {}
        if char then
            for _, item in ipairs({{"FeralInjury", "Injury"}, {"FeralBleed", "Bleeding"}, {"FeralVenomAmt", "Venom"}}) do
                local value = char:GetAttribute(item[1])
                if Core.finite(value) and value > 0 then lines[#lines + 1] = item[2] .. ": " .. formatNumber(value) end
            end
            for _, item in ipairs({{"FeralThriveUntil", "Growth boost"}, {"FeralHobbledUntil", "Hobbled"}}) do
                local value = char:GetAttribute(item[1])
                local left = Core.finite(value) and value - workspace:GetServerTimeNow() or 0
                if left > 0 then lines[#lines + 1] = item[2] .. ": " .. math.ceil(left) .. "s remaining" end
            end
            for _, item in ipairs({{"FeralHomeTurf", "Home turf"}, {"FeralGrazing", "Grazing ground"}}) do
                local value = char:GetAttribute(item[1])
                if value and value ~= 0 and value ~= "" then lines[#lines + 1] = item[2] .. ": active attribute" end
            end
            if char:GetAttribute("WolfRest") then lines[#lines + 1] = "Resting" end
            local regrow = player:GetAttribute("FeralRegrowLeft")
            if Core.finite(regrow) and regrow > 0 then lines[#lines + 1] = "Regrowth allowance: " .. formatNumber(regrow) .. " (game units)" end
        end
        effectsText.Text = #lines > 0 and table.concat(lines, "\n") or "No supported active effect attributes observed. Other effects may exist."
        local samples = state.samples
        local hp = hum and hum.Health
        local previousSample = samples[#samples]
        if previousSample then
            if Core.finite(hp) and hp < previousSample.hp then state.healthDrops = state.healthDrops + 1 end
            if Core.finite(stamina) and stamina < previousSample.stamina then state.staminaDrops = state.staminaDrops + 1 end
        end
        samples[#samples + 1] = {at = now, hp = Core.number(hp, 0), stamina = Core.number(stamina, 0)}
        while #samples > 33 do table.remove(samples, 1) end
        local elapsed = now - samples[1].at
        if elapsed > 1 and hum and Core.finite(stamina) then
            rateStats.Text = string.format("Observed over %.1fs: HP %+.2f/s   stamina %+.2f/s. Growth, spending and damage may affect these readings.",
                elapsed, (hum.Health - samples[1].hp) / elapsed, (stamina - samples[1].stamina) / elapsed)
        end
        hpDetail.Text = "Health is observed only. Decreases observed: " .. state.healthDrops
            .. "; their cause is not identified by this count."
        if state.nativeRewardsText then
            local ready = player:GetAttribute("FeralRewardsReady")
            state.nativeRewardsText.Text = "Game reward-ready indicator: " .. tostring(ready == true)
                .. " / server state observed: " .. tostring(state.rewardStateSeen)
                .. " / paid notices received: " .. state.rewardPaidNotices
                .. ". Use CLAIM in the normal reward UI; no reward amount is forged."
        end
        local watch = state.travelWatch
        if watch and now - watch.at >= 4 then
            state.travelWatch = nil
            if char == watch.character and root and hum then
                local distance = (root.Position - watch.position).Magnitude
                travelText.Text = string.format("After 4s: %.1f studs from checked body centre; HP change %+.1f. Movement/health observations do not establish lasting safety or server approval.", distance, hum.Health - watch.health)
            else travelText.Text = "Character changed during travel observation; result unresolved." end
        end
    end
    connect(RunService.Heartbeat, function(dt)
        if not state.alive or state.updateFailed then return end
        local ok, details = pcall(tick, dt)
        if not ok then
            -- Stop mutating experiments after an unexpected update error.
            state.updateFailed = true
            stopExperiments()
            failure("Hub update", details)
        end
    end)
    refreshPortraits()
    startupPhase = "ready"
    say("Ready. Right Shift or _ hides the panel. X stops the hub and restores owned local settings.")
end

local ok, startupError = pcall(run)
if not ok then
    if startupCleanup then pcall(startupCleanup) end
    local kind, line = Core.errorMeta(startupError)
    warn("[FERAL Hub] Startup failed / " .. startupPhase .. " / " .. kind .. " / source line " .. tostring(line or "unavailable"))
end
