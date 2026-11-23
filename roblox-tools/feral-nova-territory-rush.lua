-- FERAL NOVA | Territory Rush + Subsurface + Auto Survival stable one-line launcher
-- The original Renaissance hub and territory controller remain separate,
-- so an addon failure does not silently replace the working main hub.
local GAME=108901361810209
if game.PlaceId~=GAME then
    warn("[FERAL Territory Rush] Join FERAL Animal Survival before loading.")
    return
end
local BASE="https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/"
local env=(type(getgenv)=="function" and getgenv()) or _G
local function launch(name)
    local ok,err=pcall(function()
        local source=game:HttpGet(BASE..name)
        local compiled,syntaxError=loadstring(source)
        if type(compiled)~="function" then
            error("Luau compilation failed: "..tostring(syntaxError))
        end
        compiled()
    end)
    if not ok then
        warn("[FERAL Territory Rush] "..name..": "..tostring(err))
    end
    return ok
end
if type(env.FERAL_NOVA_PRIME_ACTIVE)~="table" then
    launch("feral-nova-v13.5.7-eagle-talon-hover-fix-experimental-potassium.lua")
end
launch("feral-territory-rush-v4.1.lua")
