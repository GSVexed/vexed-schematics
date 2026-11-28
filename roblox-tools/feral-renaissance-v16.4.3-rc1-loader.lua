-- FERAL Renaissance 16.4.3-rc1: immutable source, protected desktop input.
-- Immutable candidate source; server movement and stamina outcomes unverified.
-- Offline checks do not establish live server movement or stamina outcomes.
local version="16.4.3-rc1"
local expected=632803
local digest="90dc59c0f0720a2ddec91bc9336e34c5d11e63e1d5f91f76814c5f3666c67277"
local fingerprint="e6074ab5dee84d4cb359bd157eaaceff205b2681393e48fb843bf643d52e6861"
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/757700f484350b02565e49efa7677a2837b15c37/"
local function fetch(path,size)
    local ok,source=pcall(function()return game:HttpGet(raw..path)end)
    return ok and type(source)=="string" and #source==size and source or nil
end
local source=fetch("roblox-tools/feral-renaissance-v16.4.3-rc1.lua",expected)
if not source then
    local sizes={93000,93000,93000,93000,93000,93000,74803}
    local parts={}
    for i,n in ipairs(sizes) do
        parts[i]=fetch("roblox-tools/renaissance-v16/chunks/16.4.3-rc1/part-"..string.format("%02d",i)..".lua",n)
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
