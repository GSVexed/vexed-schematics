-- Booga Chest Trial v1.0 | PlaceId 11729688377
-- One normal ChestDrop request per panel. No PurchaseChest or inventory edits.
-- Requires a fresh own-inventory response showing zero of the selected chest.
-- A visible chest is a candidate result; usable loot and persistence are unverified.

-- BEGIN TESTABLE CORE
local Core = {}
function Core.finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
function Core.snapshot(data, chest)
    if type(data) ~= "table" or type(data.inventory) ~= "table" or not Core.finite(data.coins) or data.coins < 0 then return nil end
    local count, entries = 0, 0
    for _, item in pairs(data.inventory) do
        entries = entries + 1
        if entries > 10000 then return nil end
        if type(item) == "table" and item.name == chest then
            local quantity = item.quantity
            if not Core.finite(quantity) or quantity < 0 or quantity % 1 ~= 0 then return nil end
            count = count + quantity
            if count > 1000000000 then return nil end
        end
    end
    return {owned = count, coins = data.coins}
end
function Core.verdict(before, after, matches)
    if not after then return "AFTER_UNAVAILABLE" end
    if before.coins ~= after.coins or after.owned ~= 0 then return "BALANCE_CHANGED" end
    return matches > 0 and "CHEST_OBSERVED_UNVERIFIED" or "NO_CHEST_OBSERVED"
end
function Core.trial(api, result)
    api.state("Checking your inventory with the server...")
    local before = Core.snapshot(api.snapshot(), result.chest)
    if not before then result.verdict = "BEFORE_UNAVAILABLE"; return end
    result.before_owned, result.before_coins = before.owned, before.coins
    if before.owned ~= 0 then result.verdict = "ALREADY_OWNED"; return end
    if not api.guard() then result.verdict = "CANCELLED"; return end
    if not api.watch() then result.verdict = "WORLD_UNAVAILABLE"; return end
    if not api.reserve() then result.verdict = "SESSION_LIMIT"; return end
    if not api.guard() then result.verdict = "CANCELLED"; return end
    api.state("Sending one normal chest-open request...")
    result.request_attempted = true
    if not api.send(result.chest) then result.verdict = "SEND_FAILED"; return end
    result.request_sent = true
    api.state("Request sent. Watching for a matching world chest...")
    result.world_chests_observed = api.observe()
    if not api.guard() then result.verdict = "CANCELLED"; return end
    api.state("Checking the final inventory and coin balance...")
    local after = Core.snapshot(api.snapshot(), result.chest)
    if after then result.after_owned, result.after_coins = after.owned, after.coins end
    result.verdict = Core.verdict(before, after, result.world_chests_observed)
end
-- END TESTABLE CORE

if game.PlaceId ~= 11729688377 then warn("[BOOGA CHEST] Join Booga Booga Reborn first."); return end
local Players, RS = game:GetService("Players"), game:GetService("ReplicatedStorage")
local UIS, Http = game:GetService("UserInputService"), game:GetService("HttpService")
local player = Players.LocalPlayer
local pg = player and (player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 8))
if not pg then warn("[BOOGA CHEST] PlayerGui unavailable."); return end
local old = pg:FindFirstChild("BoogaChestTrialV10")
if old then
    local shutdown = old:FindFirstChild("Shutdown")
    if shutdown and shutdown:IsA("BindableEvent") then shutdown:Fire() end
    if old.Parent then old:Destroy() end
end
local alive, busy, used = true, false, false
local connections, result = {}, nil
local choices = {"Resource Chest", "Crystal Chest", "Emerald Chest", "Magnetite Chest", "Pleb Chest"}
local choice = 1
local environment = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then environment = value end
end
local guardKey = "__BOOGA_CHEST_TRIAL_V10"
local session = environment[guardKey]
if type(session) ~= "table" then
    session = {total = 0, last = -math.huge, types = {}}
    environment[guardKey] = session
end
local function optional(name)
    local globals = {setclipboard = setclipboard, toclipboard = toclipboard, writefile = writefile}
    if type(globals[name]) == "function" then return globals[name] end
    return type(environment[name]) == "function" and environment[name] or nil
end
local C = {bg = Color3.fromRGB(16, 24, 34), text = Color3.fromRGB(232, 240, 247),
    muted = Color3.fromRGB(166, 186, 202), blue = Color3.fromRGB(39, 95, 147), red = Color3.fromRGB(149, 49, 66)}
local function new(class, props, parent)
    local node = Instance.new(class)
    for key, value in pairs(props) do node[key] = value end
    node.Parent = parent
    return node
end
local gui = new("ScreenGui", {Name = "BoogaChestTrialV10", ResetOnSpawn = false, DisplayOrder = 90}, pg)
local shutdown = new("BindableEvent", {Name = "Shutdown"}, gui)
local frame = new("Frame", {BackgroundColor3 = C.bg, BorderSizePixel = 0,
    Position = UDim2.new(.5, -225, .5, -190), Size = UDim2.fromOffset(450, 380)}, gui)
new("UICorner", {CornerRadius = UDim.new(0, 10)}, frame)
local scale = new("UIScale", {Scale = 1}, frame)
local function label(text, y, h)
    return new("TextLabel", {Text = text, Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, h),
        TextColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        BackgroundTransparency = 1, RichText = false}, frame)
end
local title = label("BOOGA / CHEST TRIAL v1.0", 14, 26)
title.TextColor3 = C.text; title.Active = true
local function button(text, x, y, w, color)
    return new("TextButton", {Text = text, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 34),
        TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12, BackgroundColor3 = color or C.blue,
        BorderSizePixel = 0}, frame)
end
local close = button("X", 402, 8, 32, C.red)
local selectButton = button("CHEST: " .. choices[choice] .. "  >", 16, 48, 418)
label("Try opening an unowned chest once. Uses the normal open request. Free spawning is unverified; no purchase request is sent.", 92, 52)
local startButton = button("TRY ONCE", 16, 148, 202)
local stopButton = button("STOP", 232, 148, 202, C.red)
local status = label("Ready. Choose a chest, then TRY ONCE.", 194, 65)
local copyButton = button("COPY RESULT", 16, 266, 418)
local copyStatus = label("One attempt per panel; zero owned chests required. Re-running does not reset the session request limit.", 310, 54)
local fallback = new("TextBox", {Name = "ResultText", Text = "", Position = UDim2.fromOffset(16, 190),
    Size = UDim2.fromOffset(418, 70), Visible = false, MultiLine = true, ClearTextOnFocus = false,
    TextSize = 10, Font = Enum.Font.Code, TextColor3 = C.text, BackgroundColor3 = C.bg,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, frame)
local messages = {
    BEFORE_UNAVAILABLE = "No usable server inventory response. No chest request sent.",
    ALREADY_OWNED = "You already own this chest. No request sent; choose another type.",
    CANCELLED = "Stopped. No further requests will be sent.",
    WORLD_UNAVAILABLE = "The live chest folder is unavailable. No request sent.",
    SESSION_LIMIT = "Session limit reached, type already tried, or 30s cooldown active. No request sent.",
    SEND_FAILED = "The chest request API failed. No automatic retry.",
    AFTER_UNAVAILABLE = "Request sent; final balance could not be checked. Outcome unverified.",
    BALANCE_CHANGED = "Your coins or chest inventory changed. A free spawn is not established.",
    CHEST_OBSERVED_UNVERIFIED = "A matching world chest appeared with unchanged coin/chest balances. Usable loot is still unverified.",
    NO_CHEST_OBSERVED = "No matching chest appeared during 10s of observation. This attempt did not establish free spawning.",
    API_ERROR = "The trial stopped after an API error. No automatic retry."
}
local function publish()
    if not result then return end
    local ok, text = pcall(Http.JSONEncode, Http, result)
    if not ok then return end
    local writer = optional("writefile")
    if writer then pcall(writer, "BOOGA_CHEST_TRIAL_v1_RESULT.json.txt", text) end
end
local function connect(signal, fn)
    local connection = signal:Connect(fn)
    connections[#connections + 1] = connection
end
local cancel = false
local function cleanup()
    if not alive then return end
    cancel = true; alive = false
    if result and busy then result.cancel_requested = true; publish() end
    for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
    if gui.Parent then gui:Destroy() end
end
connect(close.Activated, cleanup)
connect(shutdown.Event, cleanup)
connect(gui.Destroying, cleanup)
connect(stopButton.Activated, function()
    cancel = true
    if busy then status.Text = "Stopping. An already-sent request cannot be recalled."
    else status.Text = "Stopped. No attempt is running." end
end)
connect(selectButton.Activated, function()
    if busy or used then return end
    choice = choice % #choices + 1
    selectButton.Text = "CHEST: " .. choices[choice] .. "  >"
    fallback.Visible = false
end)
connect(copyButton.Activated, function()
    local value = result and Http:JSONEncode(result) or "No chest attempt has run."
    for _, name in ipairs({"setclipboard", "toclipboard"}) do
        local setter = optional(name)
        if setter then
            local ok, accepted = pcall(setter, value)
            if ok and accepted ~= false then copyStatus.Text = "Result copied. Paste it into the chat."; return end
        end
    end
    fallback.Text = value; fallback.Visible = true
    copyStatus.Text = "Click the text box, then Ctrl+A and Ctrl+C."
end)
connect(startButton.Activated, function()
    if busy or used or not alive then return end
    cancel = false; busy = true; fallback.Visible = false
    local chest = choices[choice]
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or not root or not Core.finite(hum.Health) or hum.Health <= 0 then
        busy = false; status.Text = "Spawn and stay alive before trying."; return
    end
    result = {schema = "booga-chest-trial/1.0", place_id = 11729688377, chest = chest,
        verdict = "RUNNING", request_attempted = false, request_sent = false,
        world_chests_observed = 0, purchases_sent = 0, loot_verified = false,
        persistence_verified = false, test_kind = "single_normal_unowned_chest_request"}
    task.spawn(function()
        local began = os.clock()
        local folder, existing, origin, packets, requestData
        local function guard()
            return alive and not cancel and player.Character == char and char.Parent ~= nil
                and hum.Health > 0 and os.clock() - began < 30
        end
        local function state(text)
            if alive then status.Text = text end
        end
        local function snapshot()
            if not guard() then return nil end
            local done, value = false, nil
            task.spawn(function()
                local ok, data = pcall(function() return requestData:InvokeServer() end)
                -- Retain only the selected chest count and own coin balance.
                if ok and guard() then
                    local filtered = Core.snapshot(data, chest)
                    if filtered then value = {inventory = {{name = chest, quantity = filtered.owned}}, coins = filtered.coins} end
                end
                done = true
            end)
            local deadline = os.clock() + 6
            while guard() and not done and os.clock() < deadline do task.wait(.05) end
            return done and value or nil
        end
        local function matches(model)
            if model.Name ~= chest or not model:IsA("Model") or not model:IsDescendantOf(folder) then return nil end
            local id = model:GetAttribute("EntityID")
            if not Core.finite(id) or id < 0 or id % 1 ~= 0 then return nil end
            local p = model:GetPivot().Position
            local dx, dz = p.X - origin.X, p.Z - origin.Z
            if dx * dx + dz * dz > 400 then return nil end
            local hp = model:FindFirstChild("Health")
            if not hp or not hp:IsA("ValueBase") or not Core.finite(hp.Value) or hp.Value <= 0 then return nil end
            return id
        end
        local api = {guard = guard, state = state, snapshot = snapshot}
        api.watch = function()
            folder = workspace:FindFirstChild("dropChests")
            if not folder then return false end
            origin, existing = root.Position, {}
            for _, model in ipairs(folder:GetChildren()) do
                local id = model:GetAttribute("EntityID")
                if Core.finite(id) then existing[id] = true end
            end
            return true
        end
        api.reserve = function()
            if type(session.types) ~= "table" or not Core.finite(session.total) or session.total >= 3
                or type(session.last) ~= "number" or os.clock() - session.last < 30 or session.types[chest] then return false end
            session.total = session.total + 1; session.last = os.clock(); session.types[chest] = true
            return true
        end
        api.send = function(name)
            if not guard() then return false end
            used = true
            return pcall(function() packets.ChestDrop.send(name) end)
        end
        api.observe = function()
            local seen, count = {}, 0
            local deadline = os.clock() + 10
            while guard() and os.clock() < deadline do
                if not folder.Parent then break end
                for _, model in ipairs(folder:GetChildren()) do
                    local ok, id = pcall(matches, model)
                    if ok and id and not existing[id] and not seen[id] then seen[id] = true; count = count + 1 end
                end
                task.wait(.1)
            end
            return count
        end
        local ok = pcall(function()
            local modules = RS:FindFirstChild("Modules")
            local util = modules and modules:FindFirstChild("util")
            local packetModule = util and util:FindFirstChild("packets")
            local events = RS:FindFirstChild("Events")
            requestData = events and events:FindFirstChild("RequestData")
            if not packetModule or not packetModule:IsA("ModuleScript") or not requestData or not requestData:IsA("RemoteFunction") then error("dependencies unavailable") end
            packets = require(packetModule)
            if type(packets) ~= "table" or type(packets.ChestDrop) ~= "table" or type(packets.ChestDrop.send) ~= "function" then error("typed packet unavailable") end
            Core.trial(api, result)
        end)
        if not ok then result.verdict = "API_ERROR" end
        result.elapsed_seconds = math.floor((os.clock() - began) * 10 + .5) / 10
        result.note = "Client observations and own server inventory replies. No loot, save persistence or definite spawn attribution established."
        busy = false
        if alive then
            status.Text = messages[result.verdict] or "Outcome unavailable."
            startButton.Text = used and "REQUEST USED" or "TRY ONCE"
        end
        publish()
    end)
end)
local drag
connect(title.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        drag = {start = input.Position, position = frame.Position}
    end
end)
connect(UIS.InputChanged, function(input)
    if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - drag.start
        frame.Position = UDim2.new(drag.position.X.Scale, drag.position.X.Offset + delta.X,
            drag.position.Y.Scale, drag.position.Y.Offset + delta.Y)
    end
end)
connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drag = nil end
end)
local camera = workspace.CurrentCamera
if camera then scale.Scale = math.clamp(math.min(camera.ViewportSize.X / 480, camera.ViewportSize.Y / 420), .5, 1) end
