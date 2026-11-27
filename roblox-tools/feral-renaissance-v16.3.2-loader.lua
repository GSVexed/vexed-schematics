-- FERAL Renaissance 16.3.2 - desktop left-hold candidate.
-- Requires the already-installed local FERAL input helper.
local version="16.3.2"
local total=615380
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/"
local function fetch(url,n)
    local ok,body=pcall(function()return game:HttpGet(url)end)
    if not ok or type(body)~="string" or #body~=n then return nil end
    return body
end
local source=fetch(raw.."42eb58256cd40cae4da1d6b16a39e13b220d372e/roblox-tools/feral-renaissance-v16.3.2.lua",total)
if not source then
    local sizes={92971,92985,92923,92933,92936,92952,57680}
    local pieces={}
    for i,n in ipairs(sizes) do
        local p=fetch(raw.."ee8b5a66db7e078dc092dc402cca616cc1426964/roblox-tools/renaissance/chunks/v16.3.2/part-"..string.format("%02d",i)..".txt",n)
        if not p then error("FERAL "..version..": failed to download part "..i,0) end
        pieces[i]=p
    end
    source=table.concat(pieces)
end
if #source~=total or not source:find("-- FERAL Project Renaissance 16.3.2 |",1,true) then error("FERAL "..version..": source verification failed",0) end
local run,why=loadstring(source)
if not run then error("FERAL "..version..": compile failed: "..tostring(why),0) end
return run({leftHoldBridge=true})
