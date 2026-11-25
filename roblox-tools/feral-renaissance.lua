-- Renaissance 15.5.0 with the built-in Territory farming engine.
local source=game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/ecd087cabbafcea08a73b3dd56401faca1cdb6ca/roblox-tools/feral-renaissance-v15.5.0.lua")
local fn,why=loadstring(source,"=FERAL_Renaissance_15_5_0")
assert(fn,why)
return fn()
