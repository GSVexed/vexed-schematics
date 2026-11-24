-- FERAL Project Renaissance 15.0.0: immutable, validated source.
-- CLEAN v14 remains available through the separate feral-nova-clean.lua loader.
local source = game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/59e0a6d0db6d1a9e8c9f57f7a8368e858f8ec600/roblox-tools/feral-renaissance-v15.0.0.lua")
local execute, why = loadstring(source, "=FERAL_Renaissance_15")
if not execute then error("FERAL Renaissance failed to compile: " .. tostring(why), 0) end
return execute()
