-- FERAL Renaissance 16.2.7 candidate loader. Pinned source with split-download recovery.
local version="16.2.7"
local total=597631
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/00a60c2414bebafc52a318f2c6a777c48b2fd217/roblox-tools/"
local function fetch(url,n)
    local ok,body=pcall(function()return game:HttpGet(url)end)
    if not ok or type(body)~="string" or #body~=n then return nil end
    return body
end
local source=fetch(raw.."feral-renaissance-v16.2.7.lua",total)
if not source then
    local sizes={92980,92943,92956,92942,92955,92966,39889}
    local pieces={}
    for i,n in ipairs(sizes) do
        local p=fetch(raw.."renaissance/chunks/v16.2.7/part-"..string.format("%02d",i)..".txt",n)
        if not p then error("FERAL "..version..": failed to download part "..i,0) end
        pieces[i]=p
    end
    source=table.concat(pieces)
end
if #source~=total or not source:find("-- FERAL Project Renaissance 16.2.7 |",1,true) then error("FERAL "..version..": source verification failed",0) end
local run,why=loadstring(source)
if not run then error("FERAL "..version..": compile failed: "..tostring(why),0) end
return run()
