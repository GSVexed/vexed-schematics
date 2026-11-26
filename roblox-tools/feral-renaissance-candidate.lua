-- FERAL Renaissance 16.0.1 candidate / Territory 0.8.0
-- Immutable source pin. Stable 15.7.0 launchers remain unchanged.
-- Candidate validation and live gameplay acceptance are separate.
local source = game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/45c6a24e2d396ac3a5956c225c70c59451838b90/roblox-tools/feral-renaissance-v16.0.1.lua")
local run, why = loadstring(source, "=FERAL Renaissance 16.0.1 candidate")
if not run then error("FERAL candidate compile failed: " .. tostring(why), 0) end
return run()
