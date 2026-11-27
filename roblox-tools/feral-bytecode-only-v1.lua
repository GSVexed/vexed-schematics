-- FERAL client bytecode capture v1.0 | build 2415+
-- Fast, client-only, raw Luau bytecode: no in-game source reconstruction.
-- Never calls game remotes, requires game modules, or changes combat inputs.
-- Only FERAL game-owned script instances. No other-player character data.
local PLACE = 108901361810209
if game.PlaceId ~= PLACE then
    warn("[FERAL BYTECODE] Wrong game; no capture started")
    return
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local user = Players.LocalPlayer
if not user then warn("[FERAL BYTECODE] Local player unavailable") return end
-- End the superseded slow UI collector cooperatively. Its Destroying
-- connection requests a safe stop and checkpoint, not deletion of exports.
local ownGui=user:FindFirstChildOfClass("PlayerGui")
local oldGui=ownGui and ownGui:FindFirstChild("FeralClientRefreshV304")
if oldGui and oldGui:IsA("ScreenGui") then
    pcall(function()oldGui:Destroy()end)
    task.wait(0.25)
end

local env = type(getgenv)=="function" and getgenv() or _G
local byteApi = type(getscriptbytecode)=="function" and getscriptbytecode
    or (type(env)=="table" and type(env.getscriptbytecode)=="function" and env.getscriptbytecode)
local write = type(writefile)=="function" and writefile
    or (type(env)=="table" and type(env.writefile)=="function" and env.writefile)
local folder = type(makefolder)=="function" and makefolder
    or (type(env)=="table" and type(env.makefolder)=="function" and env.makefolder)
local getScripts = type(getscripts)=="function" and getscripts
    or (type(env)=="table" and type(env.getscripts)=="function" and env.getscripts)
local loaded = type(getloadedmodules)=="function" and getloadedmodules
    or (type(env)=="table" and type(env.getloadedmodules)=="function" and env.getloadedmodules)

if not byteApi or not write or not folder then
    warn("[FERAL BYTECODE] Needs getscriptbytecode/writefile/makefolder. No fallback to slow reconstruction.")
    return
end

local previous = type(env)=="table" and rawget(env,"FERAL_BYTECODE_CAPTURE")
if type(previous)=="table" and previous.running then
    warn("[FERAL BYTECODE] An earlier bytecode scan is still running")
    return
end

local alnum="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64(src)
    local out={}
    for at=1,#src,3 do
        local a,b,c=string.byte(src,at,at+2)
        local n=a*65536+(b or 0)*256+(c or 0)
        local a1=math.floor(n/262144)%64+1
        local b1=math.floor(n/4096)%64+1
        local c1=math.floor(n/64)%64+1
        local d1=n%64+1
        out[#out+1]=alnum:sub(a1,a1)..alnum:sub(b1,b1)
            ..(b and alnum:sub(c1,c1) or "=")
            ..(c and alnum:sub(d1,d1) or "=")
    end
    return table.concat(out)
end

local function safeName(name)
    name=tostring(name or "Unknown")
    if #name>90 then return "[long-name]" end
    return (name:gsub("[^%w_ %-]","_"))
end

local roots={}
local function include(root,prefix)
    if root and root.Parent then roots[#roots+1]={root=root,prefix=prefix} end
end
include(RS,"game/ReplicatedStorage")
include(game:GetService("ReplicatedFirst"),"game/ReplicatedFirst")
include(game:GetService("StarterPlayer"),"game/StarterPlayer")
include(game:GetService("StarterGui"),"game/StarterGui")
include(user:FindFirstChildOfClass("PlayerScripts"),"game/Players/LocalPlayer/PlayerScripts")
include(user:FindFirstChildOfClass("PlayerGui"),"game/Players/LocalPlayer/PlayerGui")

local function pathOf(script)
    for _,item in ipairs(roots) do
        if script==item.root or script:IsDescendantOf(item.root) then
            local names={}
            local current=script
            while current and current~=item.root and #names<32 do
                table.insert(names,1,safeName(current.Name))
                current=current.Parent
            end
            if current~=item.root then return nil end
            return item.prefix.."/"..table.concat(names,"/")
        end
    end
    return nil
end

local function eligible(v)
    if typeof(v)~="Instance" then return false end
    if v:IsA("LocalScript") or v:IsA("ModuleScript") then return true end
    if v:IsA("Script") then
        local ok,mode=pcall(function() return v.RunContext end)
        return ok and mode==Enum.RunContext.Client
    end
    return false
end
local scripts,seen={},{}
local function accept(v)
    if eligible(v) and not seen[v] then
        local ok,path=pcall(pathOf,v)
        if ok and type(path)=="string" and #path<420 then
            seen[v]=true
            scripts[#scripts+1]={v=v,path=path,class=v.ClassName}
        end
    end
end

local start=os.clock()
for _,item in ipairs(roots) do
    local ok,desc=pcall(function()return item.root:GetDescendants()end)
    if ok and type(desc)=="table" then
        for i,v in ipairs(desc) do
            accept(v)
            if i%5000==0 then task.wait() end
        end
    end
end
for _,fn in ipairs({getScripts,loaded}) do
    if type(fn)=="function" then
        local ok,arr=pcall(fn)
        if ok and type(arr)=="table" then
            for i,v in ipairs(arr) do
                accept(v)
                if i%1000==0 then task.wait() end
            end
        end
    end
end
table.sort(scripts,function(a,b)return a.path<b.path end)
local maxScripts=3000
if #scripts>maxScripts then
    warn("[FERAL BYTECODE] Too many candidate scripts; bounded to 3000")
end

local id=(os.date("!%Y%m%d_%H%M%S") or "current").."_"..tostring(math.random(100000,999999))
local root="FERAL_BYTECODE_v"..tostring(game.PlaceVersion).."_"..id
local okFolders=pcall(function()
    folder(root)
    folder(root.."/bytecode")
end)
if not okFolders then warn("[FERAL BYTECODE] Cannot create local export folders") return end

local D={
    schema="FERAL_CLIENT_BYTECODE_V1",
    run_id=id,
    place_id=game.PlaceId,
    place_version=game.PlaceVersion,
    started_utc=os.date("!%Y-%m-%dT%H:%M:%SZ"),
    mode="RAW_LUAU_BYTECODE_ONLY_NO_IN_GAME_DECOMPILATION",
    client_only=true,
    no_server_scripts=true,
    running=true,
    stop=false,
    finished=false,
    root=root,
    phase="exporting_bytecode",
    script_count=#scripts,
    processed=0,
    exported=0,
    unique_programs=0,
    failures=0,
    export_bytes=0,
    errors={},
}
if type(env)=="table" then env.FERAL_BYTECODE_CAPTURE=D end

local function writeJson(path,value)
    local json=Http:JSONEncode(value)
    return pcall(write,path,json)
end
local function checkpoint()
    D.updated_utc=os.date("!%Y-%m-%dT%H:%M:%SZ")
    writeJson(root.."/status.json",{
        schema=D.schema,place_version=D.place_version,run_id=id,root=root,
        phase=D.phase,processed=D.processed,script_count=D.script_count,
        exported=D.exported,unique_programs=D.unique_programs,
        failures=D.failures,export_bytes=D.export_bytes,
        elapsed_seconds=math.floor((os.clock()-start)*10)/10,
        no_in_game_decompilation=true,
    })
    writeJson("FERAL_BYTECODE_CURRENT_STATUS.json",{
        schema=D.schema,place_version=D.place_version,root=root,
        phase=D.phase,processed=D.processed,script_count=D.script_count,
        exported=D.exported,unique_programs=D.unique_programs,
        failures=D.failures,elapsed_seconds=math.floor((os.clock()-start)*10)/10,
        no_in_game_decompilation=true,
    })
end
checkpoint()
local meta={}
local programs={}
local index={}
local budget=64*1024*1024
local maxTime=105
for i,entry in ipairs(scripts) do
    if D.stop or i>maxScripts or os.clock()-start>maxTime then
        D.phase=D.stop and "stopped_partial" or "bounded_partial"
        break
    end
    local ok,result=pcall(byteApi,entry.v)
    local rec={path=entry.path,class=entry.class,status="unavailable",program=nil}
    if ok and type(result)=="string" and #result>=12 and #result<1024*1024 then
        local head=string.byte(result,1)
        if (head>=3 and head<=14) or head==100 then
            local len=#result
            local checksum=0
            for p=1,len do checksum=(checksum+string.byte(result,p))%4294967296 end
            local key=tostring(len)..":"..tostring(checksum)
            local candidate=index[key]
            local existing=nil
            if candidate then
                for _,known in ipairs(candidate) do
                    if known.bytes==result then existing=known.id break end
                end
            end
            if existing then
                rec.program=existing
                rec.status="deduplicated"
                D.exported+=1
            elseif D.export_bytes+len<=budget then
                local programId=#programs+1
                local filename=string.format("bytecode/program_%05d.b64.txt",programId)
                local encoded=b64(result)
                local saved=pcall(write,root.."/"..filename,encoded)
                if saved then
                    programs[#programs+1]={id=programId,path=filename,bytes=len,
                        adler_hint=checksum,luau_version=head}
                    if not candidate then candidate={} index[key]=candidate end
                    candidate[#candidate+1]={id=programId,bytes=result}
                    rec.program=programId
                    rec.status="exported"
                    D.unique_programs+=1
                    D.exported+=1
                    D.export_bytes+=len
                else
                    rec.status="write_failed"
                    D.failures+=1
                end
            else
                rec.status="budget_exhausted"
                D.failures+=1
            end
        else
            rec.status="unsupported_luau_header"
            D.failures+=1
        end
    else
        rec.status=ok and "empty_or_oversize_bytecode" or "bytecode_api_unavailable_for_script"
        D.failures+=1
    end
    meta[#meta+1]=rec
    D.processed=i
    if i%20==0 then
        checkpoint()
        task.wait()
    end
end

D.running=false
D.finished=true
if D.phase=="exporting_bytecode" then D.phase="finished" end
D.completed_utc=os.date("!%Y-%m-%dT%H:%M:%SZ")
D.elapsed_seconds=math.floor((os.clock()-start)*10)/10
local manifest={
    schema=D.schema,
    place_id=D.place_id,place_version=D.place_version,
    run_id=id,root=root,phase=D.phase,started_utc=D.started_utc,
    completed_utc=D.completed_utc,elapsed_seconds=D.elapsed_seconds,
    counters={scripts_total=D.script_count,processed=D.processed,
        exported=D.exported,unique_programs=D.unique_programs,
        failures=D.failures,bytecode_bytes=D.export_bytes},
    scripts=meta,
    programs=programs,
    constraints={mode="RAW_LUAU_BYTECODE_ONLY",
        in_game_decompile_calls=0,source_reconstruction=false,
        remote_calls=0,gameplay_input_changes=0,
        server_source_available=false,
        excludes_other_players=true,
        collected_roots={"ReplicatedStorage","ReplicatedFirst","StarterPlayer",
            "StarterGui","LocalPlayer.PlayerScripts","LocalPlayer.PlayerGui"}},
}
local wrote=writeJson(root.."/manifest.json",manifest)
checkpoint()
if wrote then
    print("[FERAL BYTECODE] "..D.phase.." v"..tostring(D.place_version)..
        " | programs "..D.unique_programs.." | scripts "..D.processed..
        " | failures "..D.failures.." | "..D.elapsed_seconds.."s | "..root)
else
    warn("[FERAL BYTECODE] Export finished but manifest write failed; partial files retained")
end
return D
