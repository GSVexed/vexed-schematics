-- FERAL Renaissance 16.4.1-exp1: immutable source, protected desktop input.
-- Immutable experiment source; server movement and stamina outcomes unverified.
-- Offline checks do not establish live server movement or stamina outcomes.
local version="16.4.1-exp1"
local expected=628555
local digest="b5ca78b29a8cfc37bfada425561398cda72fa679e83397433c6fdb049d5fba67"
local fingerprint="b05e56fb2c64abffa8c21c1fb780b75adfac9fcaf676dfefe3eb2c22810700f1"
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/d39828746fff0fdfc709ece15b4c0097b3f35c8c/"
local function fetch(path,size)
    local ok,source=pcall(function()return game:HttpGet(raw..path)end)
    return ok and type(source)=="string" and #source==size and source or nil
end
local source=fetch("roblox-tools/feral-renaissance-v16.4.1-exp1.lua",expected)
if not source then
    local sizes={93000,93000,93000,93000,93000,93000,70555}
    local parts={}
    for i,n in ipairs(sizes) do
        parts[i]=fetch("roblox-tools/renaissance-v16/chunks/16.4.1-exp1/part-"..string.format("%02d",i)..".lua",n)
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
