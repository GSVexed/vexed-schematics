-- FERAL Renaissance 16.0.0 candidate / Territory 0.8.0
-- Immutable source pin. Stable 15.7.0 launchers remain unchanged.
-- Automated regressions pass; current live gameplay acceptance is unverified.
local source = game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/6c2e10c268d681d45d312ec5cb8a0de5100243fa/roblox-tools/feral-renaissance-v16.0.0.lua")
local run, why = loadstring(source, "=FERAL Renaissance 16.0.0 candidate")
if not run then error("FERAL candidate compile failed: " .. tostring(why), 0) end
return run()
