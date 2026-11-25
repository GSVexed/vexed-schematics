-- FERAL Project Renaissance 15.4.3: highest observed Hippo Crusher Bite burst-tier client cap.
-- Old 15.4.2 source and CLEAN v14 remain independently recoverable.
-- Client-side change only; server-authoritative ability speed is not proven.
local source = game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/60b8218912f8ff4b9bebec4e0a91bdc104f78b46/roblox-tools/feral-renaissance-v15.4.3.lua")
local execute, why = loadstring(source, "=FERAL_Renaissance_15_4_3")
if not execute then error("FERAL Renaissance failed to compile: " .. tostring(why), 0) end
return execute()
