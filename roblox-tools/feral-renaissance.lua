-- Renaissance 15.6.0 with the built-in Territory farming engine.
local source=game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/180eba2d914e3c089482ccf90947ac880439179d/roblox-tools/feral-renaissance-v15.6.0.lua")
local fn,why=loadstring(source,"=FERAL_Renaissance_15_6_0")
assert(fn,why)
return fn()
