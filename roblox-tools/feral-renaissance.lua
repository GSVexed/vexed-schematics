-- FERAL Project Renaissance 15.3.0: immutable compile/regression-validated source.
-- Final rendered pose, Vulture recovery and sustained 2x/4x gameplay rates unconfirmed.
-- CLEAN v14 and complete Renaissance 15.0/15.1/15.2/15.2.1 remain unchanged.
local source = game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/1905fbe0eda6e3dd48b2ef32a16de8d02b5f6a3b/roblox-tools/feral-renaissance-v15.3.0.lua")
local execute, why = loadstring(source, "=FERAL_Renaissance_15_3")
if not execute then error("FERAL Renaissance failed to compile: " .. tostring(why), 0) end
return execute()
