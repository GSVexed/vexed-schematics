-- FERAL Renaissance 16.4.0-rc1: immutable source, protected desktop input.
-- Candidate: offline checks do not establish live server damage/stamina outcomes.
local version="16.4.0-rc1"
local expected=620644
local digest="4a25b0a6970bf0f0bf0114a70aa186bd7d11f1f276e2e81b596f7832ddda5a15"
local fingerprint="f75dabeff583e4af999c67ad57cc10d8e3cf8745d046f7da35dccb7de2696f58"
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/d4e3697728b9b6a2727d610a3f440d5b5f2dd81b/"
local function fetch(path,size)
    local ok,source=pcall(function()return game:HttpGet(raw..path)end)
    return ok and type(source)=="string" and #source==size and source or nil
end
local source=fetch("roblox-tools/feral-renaissance-v16.4.0-rc1.lua",expected)
if not source then
    local sizes={93000,93000,93000,93000,93000,93000,62644}
    local parts={}
    for i,n in ipairs(sizes) do
        parts[i]=fetch("roblox-tools/renaissance-v16/chunks/16.4.0-rc1/part-"..string.format("%02d",i)..".lua",n)
        if not parts[i] then error("FERAL "..version..": missing pinned source part "..i,0) end
    end
    source=table.concat(parts)
end
if #source~=expected or not source:find("-- FERAL Project Renaissance "..version.." |",1,true)
    or not source:find('M.release = {version="'..version..'"',1,true)
    or not source:find('sourceFingerprint="'..fingerprint..'"',1,true) then
    error("FERAL "..version..": pinned source integrity failed",0)
end
local hash=type(crypt)=="table" and crypt.hash
if type(hash)=="function" then
    local ok,value=pcall(hash,source,"sha256")
    if ok and type(value)=="string" and #value==64 and value:lower()~=digest then
        error("FERAL "..version..": SHA-256 mismatch",0)
    end
end
local run,why=loadstring(source)
if not run then error("FERAL "..version..": compile failed: "..tostring(why),0) end
local env=type(getgenv)=="function" and getgenv() or _G
local experiment=type(env)=="table" and env.FERAL_ELDER_EXPERIMENT_V1
if type(experiment)=="table" and type(experiment.stop)=="function" then pcall(function()experiment:stop()end) end
return run({leftHoldBridge=true})
