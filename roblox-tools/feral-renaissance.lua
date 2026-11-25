-- FERAL Project Renaissance 15.4.0: immutable compile/regression-validated source.
-- Exact Potassium staging passed; gameplay outcomes remain separately unverified.
-- CLEAN v14 and complete Renaissance 15.0 through 15.3 bundles remain unchanged.
local source = game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/ef1544f25d37f071df90dd1da84b9fd5df60bdaf/roblox-tools/feral-renaissance-v15.4.0.lua")
local execute, why = loadstring(source, "=FERAL_Renaissance_15_4")
if not execute then error("FERAL Renaissance failed to compile: " .. tostring(why), 0) end
return execute()
