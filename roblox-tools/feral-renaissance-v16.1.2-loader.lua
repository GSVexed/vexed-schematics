-- FERAL Renaissance 16.1.2 launch helper (no gameplay changes).
-- Pulls the identical verified candidate from two GitHub references.
-- On failure, displays the exact startup stage instead of silently failing.
local expected = "16.1.2"
local prefix = "-- FERAL Project Renaissance " .. expected
local file = "roblox-tools/feral-renaissance-v" .. expected .. ".lua"
local urls = {
    "https://raw.githubusercontent.com/GSVexed/vexed-schematics/63b189fc871dbc48315e24cdbfe16d1df8246589/" .. file,
    "https://raw.githubusercontent.com/GSVexed/vexed-schematics/renaissance/reliability-audit-hold-sustain-16.1.2/" .. file,
}

local function reportError(stage, reason)
    local body = stage .. ": " .. tostring(reason)
    warn("[FERAL " .. expected .. "] " .. body)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "FERAL " .. expected .. " could not start",
            Text = body:sub(1, 195),
            Duration = 18,
        })
    end)
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local guiParent = player and player:FindFirstChildOfClass("PlayerGui")
        if not guiParent then return end
        local previous = guiParent:FindFirstChild("FERAL_Renaissance_Load_Error")
        if previous then previous:Destroy() end
        local gui = Instance.new("ScreenGui")
        gui.Name = "FERAL_Renaissance_Load_Error"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 10000
        gui.Parent = guiParent
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(.8, 0, 0, 124)
        label.Position = UDim2.new(.1, 0, .09, 0)
        label.BackgroundColor3 = Color3.fromRGB(42, 26, 34)
        label.TextColor3 = Color3.fromRGB(255, 235, 233)
        label.TextWrapped = true
        label.Font = Enum.Font.Gotham
        label.TextSize = 15
        label.Text = "FERAL " .. expected .. " could not start\n" .. body:sub(1, 275)
        label.Parent = gui
    end)
end

if game.PlaceId ~= 108901361810209 then
    reportError("Wrong game", "This build is for FERAL Animal Survival (PlaceId 108901361810209), not " .. tostring(game.PlaceId))
    return
end

local source, issue
for _, url in ipairs(urls) do
    local ok, result = pcall(function() return game:HttpGet(url) end)
    if ok and type(result) == "string" and result:sub(1, #prefix) == prefix then
        source = result
        break
    end
    issue = ok and "Download returned unexpected content" or tostring(result)
end
-- Recover from executors that cap/truncate a large single HttpGet.
-- These are exact newline-preserving slices of the tested candidate, pinned
-- to an immutable commit; no other executable content is substituted.
if not source then
    local chunkRoot = "https://raw.githubusercontent.com/GSVexed/vexed-schematics/0605986d3934f101f040cf4d52f1f7c56a92a1f6/roblox-tools/renaissance/chunks/v16.1.2/"
    local byteCounts = {96005,95996,95963,95987,95983,80574}
    local parts = {}
    local complete = true
    for index, expectedBytes in ipairs(byteCounts) do
        local uri = chunkRoot .. string.format("part-%02d.txt", index)
        local ok, value = pcall(function() return game:HttpGet(uri) end)
        if not ok or type(value) ~= "string" or #value ~= expectedBytes then
            issue = "Full bundle unavailable; chunk " .. tostring(index) .. " failed or was truncated: " .. tostring(value):sub(1, 120)
            complete = false
            break
        end
        parts[index] = value
    end
    if complete then
        local rebuilt = table.concat(parts)
        if #rebuilt == 560508 and rebuilt:sub(1, #prefix) == prefix then
            source = rebuilt
        else
            issue = "Chunk reconstruction did not match the expected bundle structure"
        end
    end
end
if not source then
    reportError("Download", issue or "No trusted source could be downloaded")
    return
end

if type(loadstring) ~= "function" then
    reportError("Executor", "loadstring is unavailable in this client")
    return
end
local runner, why = loadstring(source, "=FERAL_Renaissance_" .. expected)
if type(runner) ~= "function" then
    reportError("Compile", why or "loadstring returned no function")
    return
end
local ok, hub = pcall(runner)
if not ok then
    reportError("Startup", hub)
    return
end
if type(hub) ~= "table" or hub.version ~= expected or hub.closed == true then
    reportError("Activation", "The hub did not return an active " .. expected .. " session")
    return
end
print("[FERAL " .. expected .. "] Loaded successfully. Right Shift opens the hub.")
