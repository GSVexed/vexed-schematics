-- FERAL Renaissance 16.2.9 candidate loader. Pinned source with split-download recovery.
local version="16.2.9"
local total=602162
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/"
local function fetch(url,n)
    local ok,body=pcall(function()return game:HttpGet(url)end)
    if not ok or type(body)~="string" or #body~=n then return nil end
    return body
end
local source=fetch(raw.."11c726cdd55d0290f98b245add9a9489cbc98083/roblox-tools/feral-renaissance-v16.2.9.lua",total)
if not source then
    local sizes={92947,92910,92942,92998,92999,92969,44397}
    local pieces={}
    for i,n in ipairs(sizes) do
        local p=fetch(raw.."1a14196e253e13997130afb88b06102fb0ebef91/roblox-tools/renaissance/chunks/v16.2.9/part-"..string.format("%02d",i)..".txt",n)
        if not p then error("FERAL "..version..": failed to download part "..i,0) end
        pieces[i]=p
    end
    source=table.concat(pieces)
end
if #source~=total or not source:find("-- FERAL Project Renaissance 16.2.9 |",1,true) then error("FERAL "..version..": source verification failed",0) end
local run,why=loadstring(source)
if not run then error("FERAL "..version..": compile failed: "..tostring(why),0) end
return run()
