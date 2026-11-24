-- FERAL Project Renaissance 15.2.1: immutable validated source.
-- Native recovery/pose ownership corrected; actual 2x/4x gameplay rates unverified.
-- CLEAN v14 and complete Renaissance 15.0/15.1/15.2 bundles remain unchanged.
local source = game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/bdfd2fc913fcf70f2a71dee5a94d5cfbfdda8b17/roblox-tools/feral-renaissance-v15.2.1.lua")
local execute, why = loadstring(source, "=FERAL_Renaissance_15_2_1")
if not execute then error("FERAL Renaissance failed to compile: " .. tostring(why), 0) end
return execute()
