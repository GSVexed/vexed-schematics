-- FERAL CLEAN stable launcher; latest reviewed clean single-window release.
local url="https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v14.0-clean-reach-core.lua"
local source=game:HttpGet(url)
local execute,err=loadstring(source)
if not execute then error("FERAL CLEAN failed to compile: "..tostring(err),0) end
return execute()