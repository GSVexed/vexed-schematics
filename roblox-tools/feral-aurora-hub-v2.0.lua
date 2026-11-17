-- FERAL AURORA v2.0 / one-line entry point
-- Local client hub. Roblox place 108901361810209 only.
local HERE="https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/"
if game.PlaceId~=108901361810209 then
    warn("[AURORA] Enter FERAL Animal Survival first.");return
end
local player=game:GetService("Players").LocalPlayer
if not player then return end
local pg=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",10)
if not pg then warn("[AURORA] PlayerGui unavailable.");return end
local oldAurora=pg:FindFirstChild("FeralAuroraHubV20")
if oldAurora then
    local ev=oldAurora:FindFirstChild("AuroraShutdown")
    if ev and ev:IsA("BindableEvent") then pcall(function()ev:Fire()end) end
    if oldAurora.Parent then oldAurora:Destroy() end
end
-- Older owned panels have their own shutdown hooks. Keep historical builds
-- intact in GitHub; do not allow multiple concurrent FERAL experiments.
for _,name in ipairs({
    "FeralRecoveryHubV10","FeralRecoveryHubV11","FeralRecoveryHubV12",
    "FeralRecoveryHubV13","FeralFieldHubV10","FeralFieldHubV11",
    "FeralFieldHubV12","FeralFieldHubV13","FeralFieldHubV14",
    "FeralRestOnlyLabV10","FeralRestOnlyLabV11","FeralRestOnlyLabV12",
    "FeralHealthRecoveryV10","FeralHealthRecoveryV11",
    "FeralHealthRecoveryV12","FeralHealthRecoveryV13"
}) do
    local old=pg:FindFirstChild(name)
    if old then
        local ev=old:FindFirstChild("HubShutdown")
        if ev and ev:IsA("BindableEvent") then pcall(function()ev:Fire()end)end
        pcall(function()old:Destroy()end)
    end
end
local function download(name)
    local ok,source=pcall(function()return game:HttpGet(HERE..name)end)
    if not ok or type(source)~="string" then
        return nil,"Unable to retrieve "..name
    end
    local fn,err=loadstring(source)
    if not fn then return nil,"Luau loader rejected "..name end
    local run,result=pcall(fn)
    if not run then return nil,"Module initialization failed for "..name end
    return result
end
local Atlas=download("feral-aurora-atlas-v2.0.lua")
if type(Atlas)~="table" then Atlas={} end
local Engine,msg=download("feral-aurora-engine-v2.0.lua")
if type(Engine)~="table" or type(Engine.new)~="function" then
    warn("[AURORA] "..(msg or "Engine module missing"));return
end
local UI,uiMessage=download("feral-aurora-ui-v2.0.lua")
if type(UI)~="table" or type(UI.mount)~="function" then
    warn("[AURORA] "..(uiMessage or "UI module missing"));return
end
local ok,ctx=pcall(function()return Engine.new(Atlas)end)
if not ok or type(ctx)~="table" then
    warn("[AURORA] Engine could not start.");return
end
local mounted,screen=pcall(function()return UI.mount(ctx)end)
if not mounted or not screen then
    ctx.close()
    warn("[AURORA] UI could not start. All owned changes restored.")
    return
end
ctx.notice("AURORA READY • "..#Atlas.." mechanics loaded. Player Finder is OFF until enabled.")
