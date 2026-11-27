-- FERAL Renaissance 16.2.4 candidate loader. Exact pinned source with split-download recovery.
local version="16.2.4"
local total=591333
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/"
local function fetch(url,n)
    local ok,body=pcall(function()return game:HttpGet(url)end)
    if not ok or type(body)~="string" or #body~=n then return nil end
    return body
end
local source=fetch(raw.."d15fd56515ce13db6ff3d263ae281471c99f552e/roblox-tools/feral-renaissance-v16.2.4.lua",total)
if not source then
    local sizes={92930,92965,92995,92995,92979,92946,33523}
    local pieces={}
    for i,n in ipairs(sizes) do
        local p=fetch(raw.."8e426424a0af5eaf2271c7fffcc129fb33c20f68/roblox-tools/renaissance/chunks/v16.2.4/part-"..string.format("%02d",i)..".txt",n)
        if not p then error("FERAL "..version..": failed to download part "..i,0) end
        pieces[i]=p
    end
    source=table.concat(pieces)
end
if #source~=total or not source:find("-- FERAL Project Renaissance 16.2.4 |",1,true) then error("FERAL "..version..": source verification failed",0) end
local run,why=loadstring(source)
if not run then error("FERAL "..version..": compile failed: "..tostring(why),0) end
return run()
