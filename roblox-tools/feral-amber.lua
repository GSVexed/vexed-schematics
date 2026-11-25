-- Optional combined launcher: latest Renaissance hub + Amber Autopilot 0.1.
-- Amber remains opt-in and disabled until the player presses START.
if game.PlaceId ~= 108901361810209 then
    warn("[FERAL AMBER] Join FERAL Animal Survival first.")
    return
end
local env=(type(getgenv)=="function" and getgenv()) or _G
if type(env.FERAL_RENAISSANCE_ACTIVE)~="table" then
    local source=game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua")
    local fn,why=loadstring(source,"=FERAL_Renaissance")
    if not fn then error(tostring(why),0) end
    fn()
end
local source=game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-amber-autopilot-v0.1.lua")
local fn,why=loadstring(source,"=FERAL_Amber_0_1")
if not fn then error(tostring(why),0) end
return fn()
