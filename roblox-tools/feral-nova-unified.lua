-- FERAL NOVA | SINGLE-HUB STABLE LAUNCHER
-- Main Renaissance and Territory Rush are bundled in one Luau payload.
local url="https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v13.5.9-unified-territory-potassium.lua"
local source=game:HttpGet(url)
local execute,err=loadstring(source)
if not execute then error("FERAL Unified source failed to compile: "..tostring(err),0) end
return execute()
