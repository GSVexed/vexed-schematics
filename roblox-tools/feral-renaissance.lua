-- FERAL Project Renaissance 15.2.0: immutable compile/regression-validated source.
-- Final native input compatibility and gameplay efficacy remain live-unconfirmed.
-- CLEAN v14 and complete Renaissance 15.0/15.1 bundles remain unchanged.
local source = game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/21da4732f05897c7225fde2ffd6ea81d02be6b1b/roblox-tools/feral-renaissance-v15.2.0.lua")
local execute, why = loadstring(source, "=FERAL_Renaissance_15_2")
if not execute then error("FERAL Renaissance failed to compile: " .. tostring(why), 0) end
return execute()
