-- FERAL Renaissance 16.2.3 candidate loader. Exact pinned source with split fallback.
local version="16.2.3"
local total=586906
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/"
local function fetch(url,n)
    local ok,body=pcall(function()return game:HttpGet(url)end)
    if not ok or type(body)~="string" or #body~=n then return nil end
    return body
end
local source=fetch(raw.."f23197deb6fa52be8cf42d2776d40851313b1faf/roblox-tools/feral-renaissance-v16.2.3.lua",total)
if not source then
    local sizes={92980,92951,92944,92963,92969,92974,29125}
    local pieces={}
    for i,n in ipairs(sizes) do
        local p=fetch(raw.."2b2a5fba32a7dd6e846bb09578caf4fcce23b04a/roblox-tools/renaissance/chunks/v16.2.3/part-"..string.format("%02d",i)..".txt",n)
        if not p then error("FERAL "..version..": failed to download part "..i,0) end
        pieces[i]=p
    end
    source=table.concat(pieces)
end
if #source~=total or not source:find("-- FERAL Project Renaissance 16.2.3 |",1,true) then error("FERAL "..version..": source verification failed",0) end
local run,why=loadstring(source)
if not run then error("FERAL "..version..": compile failed: "..tostring(why),0) end
return run()
