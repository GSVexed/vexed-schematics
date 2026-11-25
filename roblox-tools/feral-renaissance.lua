-- Renaissance 15.5.1 with the built-in Territory farming engine.
local source=game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/e6f2bccf72efb75d736b64996e05bed1a95cefd3/roblox-tools/feral-renaissance-v15.5.1.lua")
local fn,why=loadstring(source,"=FERAL_Renaissance_15_5_1")
assert(fn,why)
return fn()
