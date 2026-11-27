-- FERAL Renaissance 16.2.5 candidate loader. Pinned source with split-download recovery.
local version="16.2.5"
local total=594821
local raw="https://raw.githubusercontent.com/GSVexed/vexed-schematics/"
local function fetch(url,n)
    local ok,body=pcall(function()return game:HttpGet(url)end)
    if not ok or type(body)~="string" or #body~=n then return nil end
    return body
end
local source=fetch(raw.."60841019c778c0a7ef73374a108c39ba4d09c26a/roblox-tools/feral-renaissance-v16.2.5.lua",total)
if not source then
    local sizes={92930,92977,92942,93000,92966,92901,37105}
    local pieces={}
    for i,n in ipairs(sizes) do
        local p=fetch(raw.."2b9a70c221173a86ab79601ebed29130c68e8d33/roblox-tools/renaissance/chunks/v16.2.5/part-"..string.format("%02d",i)..".txt",n)
        if not p then error("FERAL "..version..": failed to download part "..i,0) end
        pieces[i]=p
    end
    source=table.concat(pieces)
end
if #source~=total or not source:find("-- FERAL Project Renaissance 16.2.5 |",1,true) then error("FERAL "..version..": source verification failed",0) end
local run,why=loadstring(source)
if not run then error("FERAL "..version..": compile failed: "..tostring(why),0) end
return run()
