-- FERAL Renaissance 16.0.2 candidate / Territory 0.8.0
-- Immutable source pin. Stable 15.7.0 launchers remain unchanged.
-- Candidate validation and live gameplay acceptance are separate.
local source = game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/0bba0831449d8b7743bc9b36facada407168e68e/roblox-tools/feral-renaissance-v16.0.2.lua")
local run, why = loadstring(source, "=FERAL Renaissance 16.0.2 candidate")
if not run then error("FERAL candidate compile failed: " .. tostring(why), 0) end
return run()
