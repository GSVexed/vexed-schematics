-- THE PHONE NOVA V2.1 | STABLE POTASSIUM LAUNCHER
-- Targets lobby and match place IDs in the same experience.
local sourceUrl="https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/the-phone-nova-hub-v2.1.lua"
local scriptSource=game:HttpGet(sourceUrl)
local chunk,compileError=loadstring(scriptSource)
if not chunk then
    error("[THE PHONE NOVA] Hub compile error: "..tostring(compileError),0)
end
return chunk()
