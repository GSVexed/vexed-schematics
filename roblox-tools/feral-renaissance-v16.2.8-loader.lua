-- FERAL Renaissance 16.2.8 candidate loader. Pinned source with split-download recovery.
local version="16.2.8"
local total=599269
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/"
local function fetch(url,n)
    local ok,body=pcall(function()return game:HttpGet(url)end)
    if not ok or type(body)~="string" or #body~=n then return nil end
    return body
end
local source=fetch(raw.."e9df6e55a11207acfd2af815faac8ecec01ded86/roblox-tools/feral-renaissance-v16.2.8.lua",total)
if not source then
    local sizes={92920,92929,92971,92982,92958,92994,41515}
    local pieces={}
    for i,n in ipairs(sizes) do
        local p=fetch(raw.."ccc7f549f29e6d8668481edc2f8044aee4a7b741/roblox-tools/renaissance/chunks/v16.2.8/part-"..string.format("%02d",i)..".txt",n)
        if not p then error("FERAL "..version..": failed to download part "..i,0) end
        pieces[i]=p
    end
    source=table.concat(pieces)
end
if #source~=total or not source:find("-- FERAL Project Renaissance 16.2.8 |",1,true) then error("FERAL "..version..": source verification failed",0) end
local run,why=loadstring(source)
if not run then error("FERAL "..version..": compile failed: "..tostring(why),0) end
return run()
