-- FERAL AURORA NOVA v4.0 | Velocity one-line loader
-- Loads only the existing verified client engine/power and the redesigned UI.
local ROOT = "https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/"
if game.PlaceId ~= 108901361810209 then
    warn("[Aurora NOVA] Open FERAL Animal Survival first.")
    return
end
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local pg = player and (player:FindFirstChildOfClass("PlayerGui")
    or player:WaitForChild("PlayerGui", 10))
if not pg then
    warn("[Aurora NOVA] PlayerGui not ready.")
    return
end

for _, name in ipairs({
    "FeralAuroraNovaV40", "FeralAuroraForceV31",
    "FeralAuroraHubV30", "FeralAuroraHubV21", "FeralAuroraHubV20",
    "FeralRecoveryHubV10", "FeralRecoveryHubV11", "FeralRecoveryHubV12",
    "FeralRecoveryHubV13", "FeralFieldHubV10", "FeralFieldHubV11",
    "FeralFieldHubV12", "FeralFieldHubV13", "FeralFieldHubV14"
}) do
    local old = pg:FindFirstChild(name)
    if old then
        local shutdown = old:FindFirstChild("AuroraShutdown")
            or old:FindFirstChild("HubShutdown")
        if shutdown and shutdown:IsA("BindableEvent") then
            pcall(function() shutdown:Fire() end)
        end
        if old.Parent then pcall(function() old:Destroy() end) end
    end
end

local function loadFile(file)
    local ok, data = pcall(function()
        return game:HttpGet(ROOT..file)
    end)
    if not ok or type(data) ~= "string" or #data < 100 then
        warn("[Aurora NOVA] Download failed: "..file)
        return nil
    end
    local fn, compileError = loadstring(data)
    if not fn then
        warn("[Aurora NOVA] Syntax error: "..file.." "..tostring(compileError))
        return nil
    end
    local done, value = pcall(fn)
    if not done then
        warn("[Aurora NOVA] Module error: "..file.." "..tostring(value))
        return nil
    end
    return value
end

local core = loadFile("feral-aurora-engine-v2.1.lua")
local power = loadFile("feral-aurora-power-v3.1.lua")
local ui = loadFile("feral-aurora-nova-ui-v4.0.lua")
if not core or type(core.new) ~= "function"
    or not power or type(power.attach) ~= "function"
    or not ui or type(ui.mount) ~= "function" then
    warn("[Aurora NOVA] Modules unavailable. Hub not started.")
    return
end
local ok, ctx = pcall(function() return core.new({}) end)
if not ok or type(ctx) ~= "table" then
    warn("[Aurora NOVA] Client engine could not start.")
    return
end
local attached, attachError = pcall(function()
    power.attach(ctx)
end)
if not attached or type(ctx.power) ~= "table" then
    pcall(ctx.close)
    warn("[Aurora NOVA] Power init failed: "..tostring(attachError))
    return
end
local mounted, window = pcall(function() return ui.mount(ctx) end)
if not mounted or not window then
    pcall(ctx.close)
    warn("[Aurora NOVA] UI init failed: "..tostring(window))
    return
end
ctx.notice("AURORA NOVA v4.0: outlines ON, auto escape watching. No ALT required.")
