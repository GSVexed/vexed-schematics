-- FERAL NOVA PRIME v33.0 MODULAR / v32 FEATURES - LOAD EACH SOURCE INDIVIDUALLY
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

-- Retire broken v21-v24 rebuilds before launching preserved v15 modules.
local env=(type(getgenv)=="function" and getgenv()) or _G
for _,key in ipairs({"FERAL_NOVA_PRIME_V21","FERAL_NOVA_PRIME_V22","FERAL_NOVA_PRIME_V23","FERAL_NOVA_PRIME_V24"}) do
    local old=env[key]
    if type(old)=="table" and type(old.Destroy)=="function" then
        pcall(function()old:Destroy()end)
    end
end

for _,name in ipairs({
    "FeralNovaPrimeV330","FeralNovaPrimeV320","FeralNovaPrimeV310","FeralNovaPrimeV300","FeralNovaPrimeV290","FeralNovaPrimeV280","FeralNovaPrimeV270","FeralNovaPrimeV260","FeralNovaPrimeV250","FeralNovaPrimeV150","FeralNovaPrimeV140","FeralNovaPrimeV130","FeralNovaPrimeV120","FeralNovaPrimeV110","FeralNovaPrimeV100","FeralNovaPrimeV90","FeralNovaPrimeV80","FeralNovaPrimeV70","FeralNovaPrimeV60","FeralNovaPrimeV50","FeralAuroraNovaV40","FeralAuroraForceV31",
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

-- Preserve the fifteen v15 modules. The v25 UI is a reviewed extension; mechanics is module 16.

-- Each source module is downloaded independently; this avoids one >330KB
-- loadstring and pinpoints any module the executor cannot compile/execute.
local function get(path)
    local url=ROOT..path
    local ok,body=pcall(function() return game:HttpGet(url) end)
    if not ok then
        error("[NOVA MODULAR] HTTP "..path..": "..tostring(body),0)
    end
    if type(body)~="string" or #body<100 or #body>180000 then
        error("[NOVA MODULAR] Bad response "..path.." ("..tostring(type(body)=="string" and #body or type(body))..")",0)
    end
    local fn,why=loadstring(body)
    if type(fn)~="function" then
        error("[NOVA MODULAR] Compile "..path..": "..tostring(why),0)
    end
    local ran,result=pcall(fn)
    if not ran then
        error("[NOVA MODULAR] Execute "..path..": "..tostring(result),0)
    end
    return result
end

-- Full hub lifecycle registry for safe same-session reloads.
-- Earlier v27 and older did not register all their controllers; rejoin first
-- when migrating from those versions.
local activeEnv=(type(getgenv)=="function" and getgenv()) or _G
if type(activeEnv.FERAL_NOVA_PRIME_ACTIVE)=="table" then
    local prior=activeEnv.FERAL_NOVA_PRIME_ACTIVE
    if type(prior.close)=="function" then
        pcall(function()prior.close()end)
    end
end
activeEnv.FERAL_NOVA_PRIME_ACTIVE=nil

local core=get("feral-aurora-engine-v13.0.lua")
local power=get("feral-aurora-power-v14.0.lua")
local escape=get("feral-nova-escape-v15.0.lua")
local lab=get("feral-nova-combat-v15.0.lua")
local recovery=get("feral-nova-recovery-v15.0.lua")
local mobile=get("feral-nova-mobile-v15.0.lua")
local carry=get("feral-nova-carry-v15.0.lua")
local tags=get("feral-nova-tags-v8.0.lua")
local reach=get("feral-nova-reach-v14.0.lua")
local regen=get("feral-nova-regen-v29.0.lua")
local flight=get("feral-nova-flight-v28.0.lua")
local native=get("feral-nova-native-recovery-v29.0.lua")
local baby=get("feral-nova-baby-v15.0.lua")
local climb=get("feral-nova-climb-v15.0.lua")
local mechanics=get("feral-nova-mechanics-v28.0.lua")
local diagnostics=get("feral-nova-diagnostics-v32.0.lua")
local activeRecovery=get("feral-nova-active-recovery-v29.0.lua")
local eagleActions=get("feral-nova-eagle-actions-v32.0.lua")
local ui=get("feral-nova-prime-ui-v32.0.lua")
if not core or type(core.new)~="function"
    or not power or type(power.attach)~="function"
    or not escape or type(escape.attach)~="function"
    or not lab or type(lab.attach)~="function"
    or not recovery or type(recovery.attach)~="function"
    or not mobile or type(mobile.attach)~="function"
    or not carry or type(carry.attach)~="function"
    or not reach or type(reach.attach)~="function"
    or not regen or type(regen.attach)~="function"
    or not flight or type(flight.attach)~="function"
    or not native or type(native.attach)~="function"
    or not baby or type(baby.attach)~="function"
    or not climb or type(climb.attach)~="function"
    or not tags or type(tags.attach)~="function"
    or not mechanics or type(mechanics.attach)~="function"
    or not eagleActions or type(eagleActions.attach)~="function"
    or not diagnostics or type(diagnostics.attach)~="function"
    or not activeRecovery or type(activeRecovery.attach)~="function"
    or not ui or type(ui.mount)~="function" then
    error("[NOVA MODULAR] Required modules unavailable.",0)
end
local ok,ctx=pcall(function()return core.new({})end)
if not ok or type(ctx)~="table" then
    error("[NOVA MODULAR] Core engine.new failed.",0)
end
local attached,reason=pcall(function()
    power.attach(ctx)
    ctx.carry=carry.attach(ctx)
    ctx.reach=reach.attach(ctx)
    ctx.regen=regen.attach(ctx)
    ctx.mechanics=mechanics.attach(ctx)
    ctx.eagleActions=eagleActions.attach(ctx)
    ctx.flight=flight.attach(ctx)
    ctx.baby=baby.attach(ctx)
    ctx.native=native.attach(ctx)
    ctx.climb=climb.attach(ctx)
    ctx.escape=escape.attach(ctx)
    ctx.lab=lab.attach(ctx)
    ctx.recovery=recovery.attach(ctx)
    ctx.mobile=mobile.attach(ctx)
    ctx.activeRecovery=activeRecovery.attach(ctx)
    ctx.tags=tags.attach(ctx)
    ctx.diag=diagnostics.attach(ctx)
end)
if not attached or not ctx.escape or not ctx.lab or not ctx.recovery or not ctx.mobile or not ctx.carry or not ctx.flight or not ctx.reach or not ctx.regen or not ctx.mechanics or not ctx.eagleActions or not ctx.diag or not ctx.activeRecovery or not ctx.native or not ctx.climb or not ctx.baby or not ctx.tags then
    pcall(function()if ctx.activeRecovery then ctx.activeRecovery.close()end end)
    pcall(function()if ctx.native then ctx.native.close()end end)
    pcall(function()if ctx.climb then ctx.climb.close()end end)
    pcall(function()if ctx.baby then ctx.baby.close()end end)
    pcall(function()if ctx.tags then ctx.tags.close()end end)
    pcall(function()if ctx.flight then ctx.flight.close()end end)
    pcall(function()if ctx.reach then ctx.reach.close()end end)
    pcall(function()if ctx.regen then ctx.regen.close()end end)
    pcall(function()if ctx.mechanics then ctx.mechanics.close()end end)
    pcall(function()if ctx.eagleActions then ctx.eagleActions.close()end end)
    pcall(function()if ctx.diag then ctx.diag.close()end end)
    pcall(function()if ctx.mobile then ctx.mobile.close()end end)
    pcall(function()if ctx.carry then ctx.carry.close()end end)
    pcall(function()if ctx.recovery then ctx.recovery.close()end end)
    pcall(function()if ctx.lab then ctx.lab.close()end end)
    pcall(function()if ctx.escape then ctx.escape.close()end end)
    pcall(ctx.close)
    error("[NOVA MODULAR] Core extension error: "..tostring(reason),0)
end
local ready,window=pcall(function()return ui.mount(ctx)end)
if not ready or not window then
    pcall(function()ctx.activeRecovery.close()end)
    pcall(function()ctx.native.close()end)
    pcall(function()ctx.climb.close()end)
    pcall(function()ctx.baby.close()end)
    pcall(function()ctx.tags.close()end)
    pcall(function()ctx.flight.close()end)
    pcall(function()ctx.reach.close()end)
    pcall(function()ctx.regen.close()end)
    pcall(function()ctx.mechanics.close()end)
    pcall(function()ctx.eagleActions.close()end)
    pcall(function()ctx.diag.close()end)
    pcall(function()ctx.mobile.close()end)
    pcall(function()ctx.carry.close()end)
    pcall(function()ctx.recovery.close()end)
    pcall(function()ctx.lab.close()end)
    pcall(ctx.escape.close)
    pcall(ctx.close)
    error("[NOVA MODULAR] UI failed: "..tostring(window),0)
end
-- Close a previous v28 instance before starting any new hooks. The v15
-- engine and all module shutdowns run before new recurring connections exist.
ctx.notice("NOVA PRIME v33 modular: Eagle native drag attempts now measure actual matching FeralClamp holds; client Talon gate adjustable. Growth remains local only; recovery, stamina and surface flight preserved.")
-- The UI invokes ctx.close() dynamically. This wrapper is the sole active-hub
-- registry; shutting down from Close, End, RESET+Close or rerunning v28 clears it.
local activeRecord={}
local previousClose=ctx.close
function ctx.close()
    if activeEnv.FERAL_NOVA_PRIME_ACTIVE==activeRecord then
        activeEnv.FERAL_NOVA_PRIME_ACTIVE=nil
    end
    return previousClose()
end
activeRecord.close=function()ctx.close()end
activeRecord.version="v33"
activeEnv.FERAL_NOVA_PRIME_ACTIVE=activeRecord
