-- Amber is a built-in Renaissance Territory page, with one scheduler and window.
if game.PlaceId~=108901361810209 then warn("Join FERAL Animal Survival first.");return end
local env=(type(getgenv)=="function" and getgenv()) or _G
local hub=env.FERAL_RENAISSANCE_ACTIVE
if not hub or hub.closed or not hub.territory or hub.territory.version~="0.5.0" then
    local source=game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua")
    local fn,why=loadstring(source,"=FERAL_Renaissance");assert(fn,why)
    hub=fn()
end
assert(hub and hub.territory,"Territory engine did not initialise")
hub.ui:selectTab("Territory")
if not hub.ui.visible then hub.ui:toggle() end
return hub.territory
