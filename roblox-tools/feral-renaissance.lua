-- Renaissance 15.6.1 with the built-in Territory farming engine.
local source=game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/19c07c3311836be8d5f2bb2aedd8099c2dbc55a1/roblox-tools/feral-renaissance-v15.6.1.lua")
local fn,why=loadstring(source,"=FERAL_Renaissance_15_6_1")
assert(fn,why)
return fn()
