-- FERAL Renaissance 16.3.0 - desktop left-hold candidate.
-- Requires the already-installed local FERAL input helper.
local version="16.3.0"
local total=607727
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/"
local function fetch(url,n)
    local ok,body=pcall(function()return game:HttpGet(url)end)
    if not ok or type(body)~="string" or #body~=n then return nil end
    return body
end
local source=fetch(raw.."56d8666625073274105e0d52ce5d2df00e63b0f9/roblox-tools/feral-renaissance-v16.3.0.lua",total)
if not source then
    local sizes={92999,92910,92975,92949,92952,92987,49955}
    local pieces={}
    for i,n in ipairs(sizes) do
        local p=fetch(raw.."a089c3372f3db50625949c8bbdbd64ec0118d482/roblox-tools/renaissance/chunks/v16.3.0/part-"..string.format("%02d",i)..".txt",n)
        if not p then error("FERAL "..version..": failed to download part "..i,0) end
        pieces[i]=p
    end
    source=table.concat(pieces)
end
if #source~=total or not source:find("-- FERAL Project Renaissance 16.3.0 |",1,true) then error("FERAL "..version..": source verification failed",0) end
local run,why=loadstring(source)
if not run then error("FERAL "..version..": compile failed: "..tostring(why),0) end
return run({leftHoldBridge=true})
