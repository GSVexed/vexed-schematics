-- FERAL Project Renaissance 15.1.0: pinned source; compile/regression validated.
-- New native input separation and gameplay efficacy remain live-unverified.
-- CLEAN v14 and Renaissance 15.0.0 remain available as immutable rollbacks.
local source = game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/552965031659c52e36bf8bda436d0d07d348abd6/roblox-tools/feral-renaissance-v15.1.0.lua")
local execute, why = loadstring(source, "=FERAL_Renaissance_15_1")
if not execute then error("FERAL Renaissance failed to compile: " .. tostring(why), 0) end
return execute()
