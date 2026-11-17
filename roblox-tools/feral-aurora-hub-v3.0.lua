-- FERAL AURORA v3.0 / one-line Velocity entry
-- All game changes are local or native client-action requests. No server grants.
local ROOT="https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/"
if game.PlaceId~=108901361810209 then
    warn("[Aurora v3] Enter FERAL Animal Survival first.")
    return
end
local player=game:GetService("Players").LocalPlayer
if not player then return end
local pg=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",10)
if not pg then
    warn("[Aurora v3] PlayerGui not available.")
    return
end
for _,name in ipairs({
    "FeralAuroraHubV30","FeralAuroraHubV21","FeralAuroraHubV20",
    "FeralRecoveryHubV10","FeralRecoveryHubV11","FeralRecoveryHubV12",
    "FeralRecoveryHubV13","FeralFieldHubV10","FeralFieldHubV11",
    "FeralFieldHubV12","FeralFieldHubV13","FeralFieldHubV14",
    "FeralRestOnlyLabV10","FeralRestOnlyLabV11","FeralRestOnlyLabV12",
    "FeralHealthRecoveryV10","FeralHealthRecoveryV11",
    "FeralHealthRecoveryV12","FeralHealthRecoveryV13"
}) do
    local old=pg:FindFirstChild(name)
    if old then
        local ev=old:FindFirstChild("AuroraShutdown")
            or old:FindFirstChild("HubShutdown")
        if ev and ev:IsA("BindableEvent") then
            pcall(function()ev:Fire()end)
        end
        if old.Parent then pcall(function()old:Destroy()end)end
    end
end
local function fetchModule(name)
    local ok,body=pcall(function()return game:HttpGet(ROOT..name)end)
    if not ok or type(body)~="string" or #body<40 then
        warn("[Aurora v3] Failed to download "..name)
        return nil
    end
    local fn,err=loadstring(body)
    if not fn then
        warn("[Aurora v3] Could not compile "..name)
        return nil
    end
    local loaded,value=pcall(fn)
    if not loaded then
        warn("[Aurora v3] Module failed at startup: "..name)
        return nil
    end
    return value
end
local atlas=fetchModule("feral-aurora-atlas-v2.0.lua")
local engine=fetchModule("feral-aurora-engine-v2.1.lua")
local ops=fetchModule("feral-aurora-ops-v3.0.lua")
local ui=fetchModule("feral-aurora-ui-v3.0.lua")
if type(engine)~="table" or type(engine.new)~="function"
    or type(ops)~="table" or type(ops.attach)~="function"
    or type(ui)~="table" or type(ui.mount)~="function" then
    warn("[Aurora v3] An essential module is missing; hub not started.")
    return
end
local ok,ctx=pcall(function()
    return engine.new(type(atlas)=="table" and atlas or {})
end)
if not ok or type(ctx)~="table" then
    warn("[Aurora v3] Could not initialize core.")
    return
end
local attached=pcall(function()ops.attach(ctx)end)
if not attached or type(ctx.ops)~="table" then
    pcall(ctx.close)
    warn("[Aurora v3] Operations startup failed; core shut down.")
    return
end
local mounted,screen=pcall(function()return ui.mount(ctx)end)
if not mounted or not screen then
    ctx.close()
    warn("[Aurora v3] Interface startup failed; all owned changes cleaned.")
    return
end
ctx.notice("AURORA v3 READY • "..#(type(atlas)=="table" and atlas or {})..
    " systems • Radar, waypoints, search and connected tools ready.")
