-- FERAL Renaissance 16.2.2 candidate loader. Exact pinned source with split fallback.
local version="16.2.2"
local total=583292
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/"
local function fetch(url,n)
    local ok,body=pcall(function()return game:HttpGet(url)end)
    if not ok or type(body)~="string" or #body~=n then return nil end
    return body
end
local source=fetch(raw.."74641c9d3eca66e51d39c740d4c52eb560635c63/roblox-tools/feral-renaissance-v16.2.2.lua",total)
if not source then
    local sizes={92982,92979,92886,92969,92993,92990,25493}
    local pieces={}
    for i,n in ipairs(sizes) do
        local p=fetch(raw.."a162d0563436f5474af33a6bb56db47d52c1cd1c/roblox-tools/renaissance/chunks/v16.2.2/part-"..string.format("%02d",i)..".txt",n)
        if not p then error("FERAL "..version..": failed to download part "..i,0) end
        pieces[i]=p
    end
    source=table.concat(pieces)
end
if #source~=total or not source:find("-- FERAL Project Renaissance 16.2.2 |",1,true) then error("FERAL "..version..": source verification failed",0) end
local run,why=loadstring(source)
if not run then error("FERAL "..version..": compile failed: "..tostring(why),0) end
return run()
