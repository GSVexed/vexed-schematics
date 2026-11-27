-- FERAL Renaissance 16.3.1 - desktop left-hold candidate.
-- Requires the already-installed local FERAL input helper.
local version="16.3.1"
local total=611361
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/"
local function fetch(url,n)
    local ok,body=pcall(function()return game:HttpGet(url)end)
    if not ok or type(body)~="string" or #body~=n then return nil end
    return body
end
local source=fetch(raw.."d6d0318a5addeb3a401d0be3f36daf1faa46b4d7/roblox-tools/feral-renaissance-v16.3.1.lua",total)
if not source then
    local sizes={92999,92966,92966,92998,92994,92924,53514}
    local pieces={}
    for i,n in ipairs(sizes) do
        local p=fetch(raw.."9c9738b85a754e720242800a9364e1ea1f65822e/roblox-tools/renaissance/chunks/v16.3.1/part-"..string.format("%02d",i)..".txt",n)
        if not p then error("FERAL "..version..": failed to download part "..i,0) end
        pieces[i]=p
    end
    source=table.concat(pieces)
end
if #source~=total or not source:find("-- FERAL Project Renaissance 16.3.1 |",1,true) then error("FERAL "..version..": source verification failed",0) end
local run,why=loadstring(source)
if not run then error("FERAL "..version..": compile failed: "..tostring(why),0) end
return run({leftHoldBridge=true})
