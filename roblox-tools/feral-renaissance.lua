-- FERAL Project Renaissance 15.4.2: pinned deterministic source, 185/185 official regressions.
-- Hippo-only Crusher Bite client speed-cap adjustment and alias-safe stamina profiles.
-- Gameplay/server acceptance is unverified. CLEAN v14 and all older Renaissance versions are preserved.
local source = game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/cbd9e84740538895f0f4c766b39604e10c014214/roblox-tools/feral-renaissance-v15.4.2.lua")
local execute, why = loadstring(source, "=FERAL_Renaissance_15_4_2")
if not execute then error("FERAL Renaissance failed to compile: " .. tostring(why), 0) end
return execute()
