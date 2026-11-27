-- FERAL Renaissance 16.2.6 candidate loader. Pinned source with split-download recovery.
local version="16.2.6"
local total=597322
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/"
local function fetch(url,n)
    local ok,body=pcall(function()return game:HttpGet(url)end)
    if not ok or type(body)~="string" or #body~=n then return nil end
    return body
end
local source=fetch(raw.."53f55d7e1bfab655b8fc6ddaa7149f53cf2d96de/roblox-tools/feral-renaissance-v16.2.6.lua",total)
if not source then
    local sizes={92945,92946,92998,92946,92923,92995,39569}
    local pieces={}
    for i,n in ipairs(sizes) do
        local p=fetch(raw.."aaf47de8bd645994edeb77f0524c9c9bb3816f1f/roblox-tools/renaissance/chunks/v16.2.6/part-"..string.format("%02d",i)..".txt",n)
        if not p then error("FERAL "..version..": failed to download part "..i,0) end
        pieces[i]=p
    end
    source=table.concat(pieces)
end
if #source~=total or not source:find("-- FERAL Project Renaissance 16.2.6 |",1,true) then error("FERAL "..version..": source verification failed",0) end
local run,why=loadstring(source)
if not run then error("FERAL "..version..": compile failed: "..tostring(why),0) end
return run()
