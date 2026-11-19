-- FERAL NOVA PRIME v12.0 / Velocity one-line entry
-- Private game/server state is not impersonated; all changes local/reversible.
local ROOT="https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/"
if game.PlaceId~=108901361810209 then
    warn("[NOVA PRIME] Open FERAL Animal Survival before running.")
    return
end
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local pg=player and (player:FindFirstChildOfClass("PlayerGui")
    or player:WaitForChild("PlayerGui",10))
if not pg then warn("[NOVA PRIME] PlayerGui unavailable");return end

for _,name in ipairs({
    "FeralNovaPrimeV120","FeralNovaPrimeV110","FeralNovaPrimeV100","FeralNovaPrimeV90","FeralNovaPrimeV80","FeralNovaPrimeV70","FeralNovaPrimeV60","FeralNovaPrimeV50","FeralAuroraNovaV40","FeralAuroraForceV31",
    "FeralAuroraHubV30","FeralAuroraHubV21","FeralAuroraHubV20",
    "FeralRecoveryHubV10","FeralRecoveryHubV11","FeralRecoveryHubV12",
    "FeralRecoveryHubV13","FeralFieldHubV10","FeralFieldHubV11",
    "FeralFieldHubV12","FeralFieldHubV13","FeralFieldHubV14"
}) do
    local old=pg:FindFirstChild(name)
    if old then
        local stop=old:FindFirstChild("AuroraShutdown")
            or old:FindFirstChild("HubShutdown")
        if stop and stop:IsA("BindableEvent") then
            pcall(function()stop:Fire()end)
        end
        if old.Parent then pcall(function()old:Destroy()end)end
    end
end

local function get(path)
    local ok,body=pcall(function()return game:HttpGet(ROOT..path)end)
    if not ok or type(body)~="string" or #body<100 then
        warn("[NOVA PRIME] Module download failed: "..path)
        return nil
    end
    local compiled,err=loadstring(body)
    if not compiled then
        warn("[NOVA PRIME] Compilation failed: "..path.." - "..tostring(err))
        return nil
    end
    local done,value=pcall(compiled)
    if not done then
        warn("[NOVA PRIME] Module failed: "..path.." - "..tostring(value))
        return nil
    end
    return value
end

local core=get("feral-aurora-engine-v2.1.lua")
local power=get("feral-aurora-power-v3.1.lua")
local escape=get("feral-nova-escape-v12.0.lua")
local lab=get("feral-nova-combat-v10.0.lua")
local recovery=get("feral-nova-recovery-v12.0.lua")
local mobile=get("feral-nova-mobile-v12.0.lua")
local carry=get("feral-nova-carry-v12.0.lua")
local tags=get("feral-nova-tags-v8.0.lua")
local ui=get("feral-nova-prime-ui-v12.0.lua")
if not core or type(core.new)~="function"
    or not power or type(power.attach)~="function"
    or not escape or type(escape.attach)~="function"
    or not lab or type(lab.attach)~="function"
    or not recovery or type(recovery.attach)~="function"
    or not mobile or type(mobile.attach)~="function"
    or not carry or type(carry.attach)~="function"
    or not tags or type(tags.attach)~="function"
    or not ui or type(ui.mount)~="function" then
    warn("[NOVA PRIME] Required modules unavailable. Nothing changed.")
    return
end
local ok,ctx=pcall(function()return core.new({})end)
if not ok or type(ctx)~="table" then
    warn("[NOVA PRIME] Could not start core.")
    return
end
local attached,reason=pcall(function()
    power.attach(ctx)
    ctx.carry=carry.attach(ctx)
    ctx.escape=escape.attach(ctx)
    ctx.lab=lab.attach(ctx)
    ctx.recovery=recovery.attach(ctx)
    ctx.mobile=mobile.attach(ctx)
    ctx.tags=tags.attach(ctx)
end)
if not attached or not ctx.escape or not ctx.lab or not ctx.recovery or not ctx.mobile or not ctx.carry or not ctx.tags then
    pcall(function()if ctx.tags then ctx.tags.close()end end)
    pcall(function()if ctx.mobile then ctx.mobile.close()end end)
    pcall(function()if ctx.carry then ctx.carry.close()end end)
    pcall(function()if ctx.recovery then ctx.recovery.close()end end)
    pcall(function()if ctx.lab then ctx.lab.close()end end)
    pcall(function()if ctx.escape then ctx.escape.close()end end)
    pcall(ctx.close)
    warn("[NOVA PRIME] Core extension error: "..tostring(reason))
    return
end
local ready,window=pcall(function()return ui.mount(ctx)end)
if not ready or not window then
    pcall(function()ctx.tags.close()end)
    pcall(function()ctx.mobile.close()end)
    pcall(function()ctx.carry.close()end)
    pcall(function()ctx.recovery.close()end)
    pcall(function()ctx.lab.close()end)
    pcall(ctx.escape.close)
    pcall(ctx.close)
    warn("[NOVA PRIME] UI failed: "..tostring(window))
    return
end
ctx.notice("NOVA PRIME v12: native carry/drop preserved. Recovery yields to carrying; escape acts only for captured prey.")
