-- FERAL AURORA FORCE v3.1 / Velocity one-line entry
-- Power-first own-client controls. No fabricated server-side benefits.
local ROOT="https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/"
if game.PlaceId~=108901361810209 then
    warn("[Aurora FORCE] Enter FERAL Animal Survival first.")
    return
end
local player=game:GetService("Players").LocalPlayer
local gui=player and (player:FindFirstChildOfClass("PlayerGui")
    or player:WaitForChild("PlayerGui",9))
if not gui then
    warn("[Aurora FORCE] PlayerGui not available.")
    return
end
for _,name in ipairs({
    "FeralAuroraForceV31","FeralAuroraHubV30",
    "FeralAuroraHubV21","FeralAuroraHubV20",
    "FeralRecoveryHubV10","FeralRecoveryHubV11",
    "FeralRecoveryHubV12","FeralRecoveryHubV13",
    "FeralFieldHubV10","FeralFieldHubV11",
    "FeralFieldHubV12","FeralFieldHubV13","FeralFieldHubV14",
    "FeralRestOnlyLabV10","FeralRestOnlyLabV11","FeralRestOnlyLabV12",
    "FeralHealthRecoveryV10","FeralHealthRecoveryV11",
    "FeralHealthRecoveryV12","FeralHealthRecoveryV13"
}) do
    local old=gui:FindFirstChild(name)
    if old then
        local ev=old:FindFirstChild("AuroraShutdown")
            or old:FindFirstChild("HubShutdown")
        if ev and ev:IsA("BindableEvent") then
            pcall(function()ev:Fire()end)
        end
        if old.Parent then pcall(function()old:Destroy()end)end
    end
end
local function loadModule(file)
    local ok,body=pcall(function()return game:HttpGet(ROOT..file)end)
    if not ok or type(body)~="string" or #body<40 then
        warn("[Aurora FORCE] Download failed: "..file)
        return nil
    end
    local compiled,err=loadstring(body)
    if not compiled then
        warn("[Aurora FORCE] Compilation failed: "..file)
        return nil
    end
    local success,instance=pcall(compiled)
    if not success then
        warn("[Aurora FORCE] Module initialisation failed: "..file)
        return nil
    end
    return instance
end
local core=loadModule("feral-aurora-engine-v2.1.lua")
local power=loadModule("feral-aurora-power-v3.1.lua")
local interface=loadModule("feral-aurora-force-ui-v3.1.lua")
if not core or type(core.new)~="function"
    or not power or type(power.attach)~="function"
    or not interface or type(interface.mount)~="function" then
    warn("[Aurora FORCE] Hub startup failed, no new UI created.")
    return
end
local ok,ctx=pcall(function()return core.new({})end)
if not ok or type(ctx)~="table" then
    warn("[Aurora FORCE] Core startup failed.")
    return
end
local attached=pcall(function()power.attach(ctx)end)
if not attached or type(ctx.power)~="table" then
    pcall(ctx.close)
    warn("[Aurora FORCE] Power module failed; core cleaned.")
    return
end
local mounted,screen=pcall(function()return interface.mount(ctx)end)
if not mounted or not screen then
    ctx.close()
    warn("[Aurora FORCE] UI failed; owned changes cleaned.")
    return
end
ctx.notice("AURORA FORCE v3.1 READY • Power, ESCAPE, ESP and Survival • all power profiles OFF.")
