-- FERAL Renaissance 16.3.2: pinned, chunk-verified desktop Hold-to-Bite recovery candidate.
-- The older v16.3.1 loader remains untouched for rollback.
local version="16.3.2"
local expected=612976
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/aa16edcd457ab3f9db4547b9c8647234cba78fc7/"
local function fetch(path,size)
    local ok,source=pcall(function()return game:HttpGet(raw..path)end)
    return ok and type(source)=="string" and #source==size and source or nil
end
local source=fetch("roblox-tools/feral-renaissance-v16.3.2.lua",expected)
if not source then
    local sizes={93000,93000,93000,93000,93000,93000,54976}
    local parts={}
    for i,n in ipairs(sizes) do
        local path="roblox-tools/renaissance/chunks/v16.3.2/part-"..string.format("%02d",i)..".lua"
        local chunk=fetch(path,n)
        if not chunk then error("FERAL "..version..": missing pinned source chunk "..i,0) end
        parts[i]=chunk
    end
    source=table.concat(parts)
end
if #source~=expected
    or not source:find("-- FERAL Project Renaissance 16.3.2",1,true)
    or not source:find('M.release = {version="16.3.2"',1,true) then
    error("FERAL "..version..": source integrity check failed",0)
end
-- Any earlier Elder local-config experiment is reversible and should not
-- interfere with native stamina/hold behaviour. Leave unrelated scripts alone.
local env=type(getgenv)=="function" and getgenv() or _G
local experiment=type(env)=="table" and env.FERAL_ELDER_EXPERIMENT_V1
if type(experiment)=="table" and type(experiment.stop)=="function" then
    pcall(function()experiment:stop()end)
end
local run,why=loadstring(source)
if not run then error("FERAL "..version..": compile failed: "..tostring(why),0) end
return run({leftHoldBridge=true})
