-- Renaissance 15.6.2 with built-in Territory 0.6.1 and Zoom Unlock.
local source=game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/c4cbd5a5c088c85c273f5735afc68ceb46cfc90e/roblox-tools/feral-renaissance-v15.6.2.lua")
local fn,why=loadstring(source,"=FERAL_Renaissance_15_6_2")
assert(fn,why)
return fn()
