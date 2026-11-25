-- FERAL Renaissance 15.4.1: fix equal aliased fields rejecting the stamina plan.
-- Compile/regression validated; sustained gameplay stamina remains unverified.
-- CLEAN v14 and all earlier complete Renaissance bundles remain unchanged.
local source = game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/64c3487b111a7f3075004d645c9b18e23daa744e/roblox-tools/feral-renaissance-v15.4.1.lua")
local execute, why = loadstring(source, "=FERAL_Renaissance_15_4_1")
if not execute then error("FERAL Renaissance failed to compile: " .. tostring(why), 0) end
return execute()
