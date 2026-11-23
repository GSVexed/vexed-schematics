-- PROJECT EMPIRE CLASH NOVA / read-only client research collector v1.0.0
-- Runs once for the current place. No require, game remote calls, hooks,
-- decompile, getgc, player traffic recording, or HTTP uploads.
-- Raw bytecode cannot be privacy scrubbed; keep it in the private research repo.
local CFG={
    version="1.0.0",universe=3569141441,
    -- Separate creator-listed private server experiences. Exact universe is
    -- recorded in the manifest; no other place or universe is allowed.
    privatePlaces={[11883226417]=true,[15645012269]=true},
    home="EMPIRE_CLASH_NOVA_CAPTURE_V1",
    budget=110,discoveryBudget=30,maxInstances=57000,
    maxQueue=8000,maxAttempts=1500,apiTimeout=1.0,
    maxBytecodeBytes=3*1024*1024,maxSessionBinaryBytes=130*1024*1024,
    streamBytes=128*1024,checkpointInterval=8,retryFailureAfter=1200,
}
if game.GameId~=CFG.universe and not CFG.privatePlaces[game.PlaceId] then
    warn("[EMPIRE CLASH NOVA] Not a verified Empire Clash place. Observed universe "
        ..tostring(game.GameId).." and place "..tostring(game.PlaceId))
    return
end
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
if not player then warn("[EMPIRE CLASH NOVA] LocalPlayer unavailable");return end
local playerGui=player:FindFirstChildOfClass("PlayerGui")
if not playerGui then warn("[EMPIRE CLASH NOVA] PlayerGui unavailable");return end

local function fn(name)
    local ok,v=pcall(function()
        if type(getgenv)=="function" then
            local env=getgenv()
            if type(env)=="table" and type(env[name])=="function" then
                return env[name]
            end
        end
        if type(getfenv)=="function" then
            local env=getfenv()
            if type(env)=="table" and type(env[name])=="function" then
                return env[name]
            end
        end
        return nil
    end)
    return ok and type(v)=="function" and v or nil
end
local API={
    get=fn("getscriptbytecode"),write=fn("writefile"),
    read=fn("readfile"),mkdir=fn("makefolder"),
    isfolder=fn("isfolder"),clipboard=fn("setclipboard")
}
local D={
    mode="PLACE",running=false,stopped=false,phase="READY",root=nil,
    t0=0,deadline=0,lastYield=0,lastCheckpoint=0,
    current="Current place capture starts automatically. No in-game decompilation.",
    stopReason=nil,inventoryComplete=false,extractionComplete=false,
    queue={},privateRoots={},privateNames={},dirs={},streams={},
    savedFiles={},cache={schema=4,entries={}},bytecodeSaved=0,
    visits=0,scanLimitHit=false,captureId="",
    scopeTruncated=0,slowBytecodeCalls=0,lastRecordTime=0,
    fps=60,lowFPSTime=0,fpsConnection=nil,
    c={objects=0,sceneNodes=0,attrs=0,positions=0,scripts=0,eligible=0,queued=0,remotes=0,values=0,
       attrs=0,privacySkipped=0,platformSkipped=0,
       bytecodeNew=0,bytecodeCache=0,bytecodeFailed=0,
       bytecodeUnavailable=0,bytecodeSkipped=0,bytecodeTooLarge=0,
       bytecodeUnknownFormat=0,bytecodeAttempts=0,
       bytecodeTimeout=0,bytecodeBytes=0,readErrors=0,
       slowBytecodeCalls=0,scopesTruncated=0,
       cachedFailuresSkipped=0,fpsGuardTriggers=0,
       writeErrors=0,files=0,rootScopes=0},
    report=nil,gui=nil,refs=nil
}
local PRIVATE={
    userdata=true,profiles=true,authdata=true,
    privatemessages=true,directmessages=true,chatlogs=true,
    credentials=true,sessiontokens=true,authentication=true
}
local PLATFORM={
    coregui=true,corepackages=true,robloxreplicatedstorage=true,
    robloxreplicatedscriptstorage=true,playermodule=true,
    chatscript=true,experiencechat=true,bubblechat=true,
    textchatservice=true,chat=true,chatlogs=true
}
local FOCUS={
    "king","monarch","royal","heir","rank","class","faction","team",
    "territor","capture","flag","control","core","capital","monument",
    "victory","domination","score","regiment","general","diplom","war",
    "edict","crown","authority","revolution","vote","election",
    "combat","weapon","damage","hit","swing","projectile","gun","block",
    "cooldown","attack","stamina","health","hunger","plague","armor",
    "shop","stock","sell","craft","blacksmith","profession","income",
    "merchant","trade","coin","currency","resource","mine","farm",
    "harvest","wood","inventory","bank","upgrade","foreman","tycoon",
    "horse","mount","move","speed","jump","controller","ability",
    "interact","prompt","gui","menu","hud","replicate","remote",
    "map","northwall","stonetonas","runespire","dunehaven","round"
}
local SENSITIVE={
    password=true,passwd=true,secret=true,cookie=true,
    authentication=true,credential=true,apikey=true,authtoken=true,
    accesstoken=true,refreshtoken=true,privatekey=true,
    webhook=true,sessionid=true,roblosecurity=true,
    userid=true,owneruserid=true,ownerid=true,playerid=true,
    username=true,displayname=true,accountage=true,
    discordid=true,privatechat=true
}
local SAFE_STRING_FIELDS={
    faction=true,kingdom=true,team=true,classname=true,classtype=true,
    territory=true,territoryname=true,region=true,biome=true,map=true,
    mapname=true,weapon=true,weaponname=true,material=true,resource=true,
    state=true,phase=true,profession=true,shoptype=true,objectivetype=true
}
local function clean(s)
    s=tostring(s or "?")
    if #s>120 then s=s:sub(1,120) end
    if D.privateNames[s] then
        s="[private-name]"
    else
        -- A token lookup avoids quadratic work on populated 700-player maps.
        s=s:gsub("[%w_]+",function(token)
            return D.privateNames[token] and "[private-name]" or token
        end)
    end
    if SENSITIVE[s:lower():gsub("[^%w]","")] then return "[sensitive]" end
    if s:find("[%c]") then s=s:gsub("[%c]","_") end
    return s
end
local function escapePath(name)
    return clean(name):gsub("~","~0"):gsub("/","~1")
end
local function priority(path,root)
    local leaf=path:match("[^/]+$") or path
    local low=leaf:lower()
    local score=root=="ReplicatedStorage" and 350 or
        root=="ReplicatedFirst" and 400 or
        root=="PlayerScripts" and 310 or
        root=="StarterPlayer" and 280 or
        root=="Backpack" and 270 or
        root=="StarterPack" and 260 or
        root=="StarterGui" and 220 or
        root=="PlayerGui" and 170 or 90
    for _,word in ipairs(FOCUS) do
        if low:find(word,1,true) then score+=100;break end
    end
    return score
end
local function encode(v)
    local ok,s=pcall(function()return Http:JSONEncode(v) end)
    if ok then return s end
    return "{}"
end
local function adler32(s)
    local a,b=1,0
    for i=1,#s do
        a=(a+s:byte(i))%65521
        b=(b+a)%65521
    end
    return string.format("%08x",b*65536+a)
end
local function mkdir(path)
    if D.dirs[path] then return true end
    if API.isfolder then
        local ok,v=pcall(API.isfolder,path)
        if ok and v then D.dirs[path]=true;return true end
    end
    if not API.mkdir then return false end
    local ok,v=pcall(API.mkdir,path)
    if ok and v~=false then D.dirs[path]=true;return true end
    return false
end
local function ensureParents(path)
    local p=path:match("^(.*)/[^/]+$") or ""
    local acc=""
    for x in p:gmatch("[^/]+") do
        acc=acc=="" and x or acc.."/"..x
        if not mkdir(acc) then return false end
    end
    return true
end
local function write(path,bytes)
    if not API.write or not ensureParents(path) then
        D.c.writeErrors+=1;return false
    end
    local ok,res=pcall(API.write,path,bytes)
    if not ok or res==false then D.c.writeErrors+=1;return false end
    D.c.files+=1
    return true
end
local function read(path)
    if not API.read then return nil end
    local ok,s=pcall(API.read,path)
    if ok and type(s)=="string" then return s end
    return nil
end
local function emit(stream,row)
    local v=D.streams[stream]
    if not v then v={lines={},bytes=0,file=0,count=0,files={}};D.streams[stream]=v end
    local line=encode(row).."\n"
    v.lines[#v.lines+1]=line;v.bytes+=#line;v.count+=1
    if v.bytes>=CFG.streamBytes then
        D.flush(stream)
    end
end
function D.flush(stream)
    local v=D.streams[stream]
    if not v or v.bytes==0 then return end
    v.file+=1
    local file=D.root.."/"..stream.."_"..string.format("%03d",v.file)..".ndjson.txt"
    local body=table.concat(v.lines)
    if write(file,body) then
        v.files[#v.files+1]={path=file,bytes=#body,adler32=adler32(body)}
    end
    v.lines={};v.bytes=0
end
local function flushAll()
    for name in pairs(D.streams) do D.flush(name) end
end
local function summary()
    return {
        tool="empire-clash-nova-client-collector",version=CFG.version,
        mode=D.mode,phase=D.phase,reason=D.stopReason,
        universe_id=game.GameId,place_id=game.PlaceId,
        place_version=game.PlaceVersion,elapsed_seconds=
            math.floor((os.clock()-D.t0)*10)/10,
        server_type=game.PrivateServerId~="" and "private_or_reserved" or "public",
        inventory_complete=D.inventoryComplete,
        scope_truncated=D.scopeTruncated>0,
        bytecode_export_complete=D.extractionComplete,
        scope="accessible_gameplay_roots_client_scripts_and_scene_platform_excluded",
        no_in_game_decompile=true,server_only_source_unavailable=true,
        binary_bytecode_not_privacy_scrubbed=true,
        fps_estimate=math.floor(D.fps),
        fps_guard_triggered=D.stopReason=="fps_guard",
        output_root=D.root,counts=D.c,
        capture_strategy="once_per_distinct_place_and_gameplay_context",
        game_title="Empire Clash",game_creator="Empire Clash Community",
        exported_content="client_visible_inventory_and_raw_bytecode_only",
        server_authority_unverified=true,traffic_interception=false,
        no_outbound_network_requests=true,
        caution="Raw bytecode is not privacy-redacted; client-only data; server trust is unverified",
        privacy_scrub_is_heuristic=true,
        cache_reuse_by_place_version_path_not_exact_byte_identity=true
    }
end
function D.checkpoint()
    if not D.root then return end
    flushAll()
    local streams={}
    for k,v in pairs(D.streams) do
        streams[k]={records=v.count,files=v.files}
    end
    local data={summary=summary(),streams=streams,binaries=D.savedFiles}
    write(D.root.."/manifest.json.txt",encode(data))
    D.lastCheckpoint=os.clock()
end
local function cacheFile()
    return CFG.home.."/cache-index.json.txt"
end
local function loadCache()
    local s=read(cacheFile())
    if not s then return end
    local ok,v=pcall(function()return Http:JSONDecode(s)end)
    if ok and type(v)=="table" and v.schema==4
       and type(v.entries)=="table" then D.cache=v end
end
local function saveCache()
    if D.root then write(cacheFile(),encode(D.cache)) end
end
local function logFailure(entry,reason,elapsed,method)
    D.c.bytecodeFailed+=1
    D.cache.entries[tostring(game.PlaceId).."|"..entry.class.."|"..entry.path]={
        failed=reason,place_version=game.PlaceVersion,
        retry_after=os.time()+CFG.retryFailureAfter
    }
    emit("bytecode_results",{script_path=entry.path,
       class=entry.class,status="unavailable",reason=reason,
       elapsed_ms=math.floor((elapsed or 0)*1000),method=method})
    if reason=="api_missing" or reason=="empty" then
        D.c.bytecodeUnavailable+=1
    end
end
local function yieldBrief(force)
    if force or os.clock()-D.lastYield>0.006 then
        task.wait()
        D.lastYield=os.clock()
    end
end
local function privateBranches()
    for _,other in ipairs(Players:GetPlayers()) do
        D.privateNames[other.Name]=true
        D.privateNames[other.DisplayName]=true
        if other~=player then
            D.privateRoots[other]=true
            if other.Character then D.privateRoots[other.Character]=true end
        end
    end
    Players.PlayerAdded:Connect(function(other)
        D.privateNames[other.Name]=true
        D.privateNames[other.DisplayName]=true
        if other~=player then
            D.privateRoots[other]=true
            other.CharacterAdded:Connect(function(character)
                D.privateRoots[character]=true
            end)
        end
    end)
    for _,other in ipairs(Players:GetPlayers()) do
        if other~=player then
            other.CharacterAdded:Connect(function(character)
                D.privateRoots[character]=true
            end)
        end
    end
end
local function roots()
    return {
        {name="ReplicatedFirst",obj=game:GetService("ReplicatedFirst"),limit=3500},
        {name="ReplicatedStorage",obj=game:GetService("ReplicatedStorage"),limit=17500},
        {name="PlayerScripts",obj=player:FindFirstChildOfClass("PlayerScripts"),limit=4000},
        {name="Character",obj=player.Character,limit=3200},
        {name="StarterPlayer",obj=game:GetService("StarterPlayer"),limit=3500},
        {name="StarterPack",obj=game:GetService("StarterPack"),limit=2800},
        {name="Backpack",obj=player:FindFirstChildOfClass("Backpack"),limit=2000},
        {name="StarterGui",obj=game:GetService("StarterGui"),limit=3500},
        {name="PlayerGui",obj=playerGui,limit=3500},
        {name="Workspace",obj=game:GetService("Workspace"),limit=15500},
        {name="Lighting",obj=game:GetService("Lighting"),limit=400},
        {name="Teams",obj=game:GetService("Teams"),limit=450},
    }
end
local function scriptEligible(obj,class)
    if class=="LocalScript" or class=="ModuleScript" then return true end
    if class=="Script" then
        local ok,ctx=pcall(function()return obj.RunContext end)
        return ok and tostring(ctx)=="Enum.RunContext.Client"
    end
    return false
end
function D.discover()
    D.phase="DISCOVERING"
    D.current="Indexing client scripts and remotes without decompiling..."
    local t0=os.clock()
    local budget=CFG.discoveryBudget
    local maxObjects=CFG.maxInstances
    local allRoots=roots()
    for _,scope in ipairs(allRoots) do
        if D.stopped or D.c.objects>=maxObjects
           or os.clock()-t0>budget or os.clock()>D.deadline-1 then break end
        local obj=scope.obj
        if obj then
            D.c.rootScopes+=1
            local stack={{obj=obj,path="game/"..scope.name,depth=0}}
            local visited=0
            while #stack>0 and visited<scope.limit
                  and D.c.objects<maxObjects and not D.stopped
                  and os.clock()-t0<budget do
                local item=stack[#stack]
                stack[#stack]=nil
                local node=item.obj
                if not D.privateRoots[node] and node~=D.gui then
                    local ok,cls=pcall(function()return node.ClassName end)
                    if ok then
                        visited+=1;D.c.objects+=1
                        local name=clean(node.Name)
                        local key=name:lower():gsub("[^%w]","")
                        if PLATFORM[key] then
                            D.c.platformSkipped+=1
                        elseif PRIVATE[key] or SENSITIVE[key] then
                            D.c.privacySkipped+=1
                        else
                            -- Inventory every accessible node, not only scripts:
                            -- path/class/parent/root, with bounded gameplay metadata.
                            local info={path=item.path,class=cls,root=scope.name,depth=item.depth}
                            local lowPath=item.path:lower()
                            local focus=false
                            for _,word in ipairs(FOCUS) do
                                if lowPath:find(word,1,true) then focus=true;break end
                            end
                            if focus and (cls=="BasePart" or cls=="Part"
                                or cls=="MeshPart" or cls=="SpawnLocation") then
                                local posOK,pos=pcall(function()return node.Position end)
                                if posOK and typeof(pos)=="Vector3" then
                                    info.position={math.floor(pos.X*10)/10,
                                        math.floor(pos.Y*10)/10,math.floor(pos.Z*10)/10}
                                    D.c.positions+=1
                                end
                            end
                            if focus and item.depth<14 then
                                local attrOK,attr=pcall(function()return node:GetAttributes()end)
                                if attrOK and type(attr)=="table" then
                                    local pairsSeen=0
                                    local safe={}
                                    for key,val in pairs(attr) do
                                        if pairsSeen>=12 then break end
                                        local k=clean(key)
                                        if not SENSITIVE[k:lower():gsub("[^%w]","")]
                                            and not PRIVATE[k:lower():gsub("[^%w]","")] then
                                            if type(val)=="number" and val==val and math.abs(val)<1e10 then
                                                safe[k]=math.floor(val*1000+.5)/1000
                                            elseif type(val)=="boolean" then safe[k]=val
                                            elseif type(val)=="string" and #val<=64
                                                and SAFE_STRING_FIELDS[k:lower():gsub("[^%w]","")] then
                                                safe[k]=clean(val)
                                            end
                                            pairsSeen+=1
                                        end
                                    end
                                    if next(safe) then info.attributes=safe;D.c.attrs+=1 end
                                end
                            end
                            emit("objects",info)
                            D.c.sceneNodes+=1
                            if cls=="LocalScript" or cls=="ModuleScript" or cls=="Script" then
                                D.c.scripts+=1
                                local allowed=scriptEligible(node,cls)
                                if allowed then
                                    D.c.eligible+=1
                                    if #D.queue<CFG.maxQueue then
                                        D.queue[#D.queue+1]={
                                            obj=node,path=item.path,class=cls,
                                            score=priority(item.path,scope.name)
                                        }
                                    else D.c.bytecodeSkipped+=1 end
                                end
                                emit("scripts",{path=item.path,class=cls,
                                    eligible=allowed,root=scope.name})
                            elseif cls=="RemoteEvent" or cls=="RemoteFunction"
                                  or cls=="UnreliableRemoteEvent"
                                  or cls=="BindableEvent" or cls=="BindableFunction" then
                                D.c.remotes+=1
                                emit("remotes",{path=item.path,class=cls,
                                    invoked=false,traffic_captured=false})
                            elseif focus and (cls=="NumberValue" or cls=="IntValue"
                                  or cls=="BoolValue" or cls=="StringValue"
                                  or cls=="ObjectValue") then
                                local rok,v=pcall(function()return node.Value end)
                                local valueKey=node.Name:lower():gsub("[^%w]","")
                                if rok and type(v)~="userdata" then
                                    local safeValue=nil
                                    if type(v)=="number" and v==v and math.abs(v)<1e10 then
                                        safeValue=v
                                    elseif type(v)=="boolean" then safeValue=v
                                    elseif type(v)=="string" and #v<=64
                                        and SAFE_STRING_FIELDS[valueKey] then
                                        safeValue=clean(v)
                                    end
                                    if safeValue~=nil then
                                        D.c.values+=1
                                        emit("values",{path=item.path,class=cls,value=safeValue})
                                    end
                                end
                            end
                            if item.depth<55 then
                                local childrenOK,children=pcall(function()return node:GetChildren()end)
                                if childrenOK and type(children)=="table" then
                                    -- The scene can exceed its bounded scan cap. Visit
                                    -- likely objective folders before generic terrain.
                                    if scope.name=="Workspace" then
                                        table.sort(children,function(a,b)
                                            local pa=priority(a.Name,scope.name)
                                            local pb=priority(b.Name,scope.name)
                                            if pa==pb then return a.Name>b.Name end
                                            return pa<pb
                                        end)
                                    end
                                    local counts={}
                                    for i=#children,1,-1 do
                                        local child=children[i]
                                        if not D.privateRoots[child] then
                                            local cname=clean(child.Name)
                                            local ckey=cname.."|"..child.ClassName
                                            counts[ckey]=(counts[ckey] or 0)+1
                                            local suffix=counts[ckey]>1 and
                                                "~"..counts[ckey] or ""
                                            stack[#stack+1]={obj=child,
                                                path=item.path.."/"..escapePath(cname)..suffix,
                                                depth=item.depth+1}
                                        end
                                    end
                                else D.c.readErrors+=1 end
                            end
                        end
                    end
                else
                    D.c.privacySkipped+=1
                end
                if D.c.objects%30==0 then
                    D.current="Indexed "..D.c.objects.." objects, "..D.c.eligible.." client scripts"
                    D.refresh()
                    yieldBrief(true)
                end
            end
            if #stack>0 then
                D.scopeTruncated+=1
                D.c.scopesTruncated+=1
                emit("limits",{root=scope.name,objects_pending_approx=#stack,
                    reason="discovery_scope_limit_or_time_budget"})
            end
            D.checkpoint()
        end
    end
    table.sort(D.queue,function(a,b)
        if a.score==b.score then return a.path<b.path end
        return a.score>b.score
    end)
    D.c.queued=#D.queue
    local availableRoots=0
    for _,scope in ipairs(allRoots) do
        if scope.obj then availableRoots+=1 end
    end
    D.inventoryComplete=D.c.objects<maxObjects and
        os.clock()-t0<budget and not D.stopped
        and D.scopeTruncated==0 and D.c.rootScopes==availableRoots
    emit("coverage",{roots_traversed=D.c.rootScopes,
         indexed_objects=D.c.objects,
         eligible=D.c.eligible,queued=D.c.queued,
         complete=D.inventoryComplete,
         note="Platform subtrees and other-player branches omitted; capped root scans."})
    D.checkpoint()
end
local function callBounded(callback,arg,timeout)
    if not callback then return false,"api_missing",0 end
    local t0=os.clock()
    local state={alive=true,done=false,ok=false,value=nil}
    local worker=task.defer(function()
        if not state.alive then return end
        local ok,val=pcall(callback,arg)
        if state.alive then state.ok,state.value,state.done=ok,val,true end
    end)
    while not state.done and not D.stopped and os.clock()-t0<timeout do
        task.wait()
    end
    local elapsed=os.clock()-t0
    if state.done then return state.ok,state.value,elapsed end
    state.alive=false
    if task.cancel then pcall(task.cancel,worker) end
    return false,D.stopped and "stopped" or "timeout",elapsed
end
local function cacheKey(entry)
    return tostring(game.PlaceId).."|"..entry.class.."|"..entry.path
end
local function plausibleBytes(bytes)
    if type(bytes)~="string" or #bytes==0 then return false,"empty" end
    if #bytes>CFG.maxBytecodeBytes then return false,"too_large" end
    local prefix=bytes:sub(1,100):lower()
    if prefix:find("failed to",1,true) or prefix:find("error:",1,true) then
        return false,"executor_error_string"
    end
    return true,nil
end
local function storeBytecode(entry,bytes,method,oldRecord)
    local enough,err=plausibleBytes(bytes)
    if not enough then return false,err end
    if D.bytecodeSaved+#bytes>CFG.maxSessionBinaryBytes then return false,"byte_budget" end
    local idx=D.c.bytecodeNew+D.c.bytecodeCache+1
    local relative="bytecode/B"..string.format("%05d",idx)..".luauc"
    local path=D.root.."/"..relative
    if not write(path,bytes) then return false,"write_failed" end
    -- Binary read-back for the first file only: verifies that Potassium can
    -- round-trip NUL-containing binary strings without re-reading every file.
    if idx==1 and API.read then
        local check=read(path)
        if check~=bytes then
            D.c.writeErrors+=1
            return false,"binary_readback_mismatch"
        end
    end
    local checksum=adler32(bytes)
    D.bytecodeSaved+=#bytes
    D.c.bytecodeBytes+=#bytes
    local first=bytes:byte(1)
    -- The live Arena/Potassium MCP probe returned bytecode with leading
    -- version byte 14. Preserve unchanged bytes and treat supported Luau
    -- version numbers 3..14 as plausible, not independently validated.
    local format=(first and (first>=3 and first<=14)) and "likely_luau"
        or "format_unverified"
    if format=="format_unverified" then D.c.bytecodeUnknownFormat+=1 end
    local meta={
        script_path=entry.path,class=entry.class,method=method,
        file=relative,bytes=#bytes,adler32=checksum,
        format_guess=format,first_byte=first,
        original_source_included=false,source_decompiled_in_game=false,
        cached_using_unverified_path_and_version=(method=="cache_copy")
    }
    emit("bytecode_results",meta)
    D.savedFiles[#D.savedFiles+1]=meta
    D.cache.entries[cacheKey(entry)]={
        file=path,bytes=#bytes,adler32=checksum,
        place_version=game.PlaceVersion,class=entry.class,
        copied_from=oldRecord and oldRecord.file or nil
    }
    if method=="cache_copy" then D.c.bytecodeCache+=1
    else D.c.bytecodeNew+=1 end
    return true,nil
end
function D.collectBytecode()
    D.phase="BYTECODE CAPTURE"
    D.current="Copying saved bytecode and retrieving new client bytecode..."
    local attemptsLimit=CFG.maxAttempts
    local completed=0
    local healthFailures=0
    for idx,entry in ipairs(D.queue) do
        if D.stopped then D.stopReason="user_stopped";break end
        if os.clock()>=D.deadline then D.stopReason="time_budget";break end
        if D.lowFPSTime>1.1 then
            D.stopReason="fps_guard"
            D.c.fpsGuardTriggers+=1
            break
        end
        if D.c.bytecodeAttempts>=attemptsLimit then
            D.stopReason="bytecode_attempt_budget";break
        end
        if D.bytecodeSaved>=CFG.maxSessionBinaryBytes then
            D.stopReason="binary_export_budget";break
        end
        local ck=D.cache.entries[cacheKey(entry)]
        local hit=false
        if ck and ck.failed and ck.place_version==game.PlaceVersion
            and type(ck.retry_after)=="number"
            and os.time()<ck.retry_after then
            D.c.cachedFailuresSkipped+=1
            emit("bytecode_results",{script_path=entry.path,class=entry.class,
                status="prior_failure_not_retried",reason=ck.failed})
            hit=true
        end
        if not hit and ck and ck.place_version==game.PlaceVersion and
            type(ck.file)=="string" then
            local cached=read(ck.file)
            if cached and #cached==ck.bytes and adler32(cached)==ck.adler32 then
                hit=storeBytecode(entry,cached,"cache_copy",ck)
            end
        end
        if not hit then
            D.c.bytecodeAttempts+=1
            local ok,bytes,elapsed=callBounded(API.get,entry.obj,
                math.min(CFG.apiTimeout,math.max(0.05,D.deadline-os.clock())))
            if elapsed>=0.55 then
                D.c.slowBytecodeCalls+=1
            end
            if not ok then
                local reason=bytes=="timeout" and "timeout"
                    or bytes=="api_missing" and "api_missing"
                    or "getter_failed"
                if reason=="timeout" then D.c.bytecodeTimeout+=1 end
                logFailure(entry,reason,elapsed,"getscriptbytecode")
                healthFailures+=1
            else
                local stored,reason=storeBytecode(entry,bytes,
                    "getscriptbytecode",nil)
                if stored then healthFailures=0
                else
                    if reason=="too_large" then D.c.bytecodeTooLarge+=1 end
                    logFailure(entry,reason,elapsed,"getscriptbytecode")
                    healthFailures+=1
                end
            end
        end
        completed+=1
        entry.obj=nil
        if healthFailures>=5 and D.c.bytecodeNew==0 then
            D.stopReason="bytecode_api_not_working";break
        end
        if D.c.bytecodeAttempts>=6 and D.c.slowBytecodeCalls>=5 then
            D.stopReason="bytecode_getter_too_slow"
            D.current="Bytecode retrieval itself is too slow; sample and diagnostics saved."
            break
        end
        if completed%5==0 then
            D.current="Processed "..completed.."/"..#D.queue..
                ", dumped "..D.c.bytecodeNew..
                ", cache "..D.c.bytecodeCache..
                ", failures "..D.c.bytecodeFailed
            D.refresh()
            yieldBrief(true)
        end
        if os.clock()-D.lastCheckpoint>=CFG.checkpointInterval then
            D.checkpoint();saveCache()
        end
    end
    D.c.bytecodeSkipped+=math.max(0,#D.queue-completed)
    D.extractionComplete=(completed==#D.queue) and D.stopReason==nil
    D.checkpoint();saveCache()
end
function D.refresh()
    if not D.gui or not D.gui.Parent or not D.refs then return end
    D.refs.status.Text=D.phase.." | "..D.mode
    D.refs.count.Text="Scripts "..D.c.eligible.." | bytecode "..D.c.bytecodeNew..
        " new / "..D.c.bytecodeCache.." cached | failures "..D.c.bytecodeFailed
    D.refs.current.Text=D.current
    D.refs.path.Text=D.root or "No capture yet"
end
function D.run()
    if D.running then return end
    D.running=true;D.stopped=false
    D.t0=os.clock()
    D.deadline=D.t0+CFG.budget
    D.phase="STARTING"
    D.refresh()
    if not API.write or not API.mkdir then
        D.phase="FILES UNAVAILABLE"
        D.current="Executor must provide writefile and makefolder."
        D.running=false;D.refresh();return
    end
    mkdir(CFG.home)
    privateBranches()
    loadCache()
    local timestamp=os.date("!%Y%m%d_%H%M%S")
    local guidOk,guid=pcall(function()return Http:GenerateGUID(false)end)
    local suffix=guidOk and guid:gsub("%W",""):sub(1,8)
        or tostring(math.random(10000000,99999999))
    D.root=CFG.home.."/captures/PLACE_"..tostring(game.PlaceId).."_"..
        timestamp.."_"..suffix
    mkdir(CFG.home.."/captures")
    if not mkdir(D.root) then
        D.phase="WRITE FAILURE"
        D.current="Could not create capture folder."
        D.running=false;D.refresh();return
    end
    D.fpsConnection=RunService.Heartbeat:Connect(function(dt)
        if not D.running or dt<=0 or dt>0.5 then return end
        local inst=math.min(150,1/dt)
        D.fps=D.fps*0.85+inst*0.15
        if D.fps<24 then D.lowFPSTime+=dt
        else D.lowFPSTime=math.max(0,D.lowFPSTime-dt) end
    end)
    write(D.root.."/README.txt",
        "EMPIRE CLASH NOVA READ-ONLY CLIENT COLLECTION v1.0.0\n"..
        "Keep this capture private. The private GitHub runner can collect it.\n"..
        "Raw bytecode is NOT redacted. Do not publish it.\n"..
        "No source decompilation was run in Roblox.\n"..
        "Bytecode files are .luauc; manifest records paths and checksums.\n"..
        "The cache-index lives above captures and does not need uploading.\n")
    D.checkpoint()
    local ok=pcall(function()
        D.discover()
        if not D.stopped and not D.stopReason and os.clock()<D.deadline
            and D.lowFPSTime<=1.1 then D.collectBytecode()
        elseif not D.stopped then
            D.stopReason=D.lowFPSTime>1.1 and "fps_guard" or "time_budget_discovery"
        end
    end)
    if not ok then
        D.phase="FAILED - PARTIAL SAVED"
        D.stopReason="collector_runtime_error"
        D.current="Runtime error; capture files saved."
    elseif D.stopped then
        D.phase="STOPPED - SAVED"
        D.stopReason="user_stopped"
    elseif D.stopReason~=nil then
        D.phase="PARTIAL - SAVED"
        D.current="Bounded collection saved. Later runs reuse cached bytecode."
    elseif not D.inventoryComplete or not D.extractionComplete then
        D.phase="PARTIAL - SAVED"
        D.stopReason=not D.inventoryComplete and "discovery_scope_limit" or "bytecode_not_complete"
        D.current="Coverage is partial; the saved files remain usable."
    else
        D.phase="COMPLETE"
        D.current="Capture saved. Tell ChatGPT this place is finished."
    end
    D.checkpoint();saveCache()
    D.running=false
    if D.fpsConnection then D.fpsConnection:Disconnect();D.fpsConnection=nil end
    D.refresh()
    warn("[EMPIRE CLASH NOVA] "..D.phase.." | "..(D.root or "")..
        " | binary files="..(D.c.bytecodeNew+D.c.bytecodeCache))
end

local old=playerGui:FindFirstChild("EmpireClashNovaCaptureV1")
if old then pcall(function()old:Destroy()end)end
local function elem(klass,props,parent)
    local inst=Instance.new(klass)
    for k,v in pairs(props) do pcall(function()inst[k]=v end) end
    inst.Parent=parent
    return inst
end
local ui=elem("ScreenGui",{Name="EmpireClashNovaCaptureV1",
    DisplayOrder=800,ResetOnSpawn=false,IgnoreGuiInset=true},playerGui)
D.gui=ui
ui.Destroying:Connect(function() D.stopped=true end)
local panel=elem("Frame",{Size=UDim2.fromOffset(590,330),
    Position=UDim2.fromScale(0.5,0.12),
    AnchorPoint=Vector2.new(0.5,0),
    BackgroundColor3=Color3.fromRGB(18,28,44),BorderSizePixel=0},ui)
elem("UICorner",{CornerRadius=UDim.new(0,10)},panel)
local camera=workspace.CurrentCamera
if camera then
    elem("UIScale",{Scale=math.max(0.50,math.min(1,
        camera.ViewportSize.X/630,camera.ViewportSize.Y/375))},panel)
end
local function label(t,y,h,sz)
    return elem("TextLabel",{Text=t,Font=Enum.Font.Gotham,
        TextColor3=Color3.fromRGB(233,241,248),
        BackgroundTransparency=1,TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(14,y),
        Size=UDim2.fromOffset(560,h),TextSize=sz or 12},panel)
end
label("EMPIRE CLASH NOVA / RESEARCH CAPTURE",12,28,16)
D.refs={
    status=label("READY / CURRENT PLACE",50,24,14),
    count=label("No files collected.",83,40,12),
    current=label("Game structure + client Luau bytecode. Auto starting.",130,44,12),
    path=label("No capture yet",259,60,10),
}
local function button(name,title,x,w,fill)
    local b=elem("TextButton",{Name=name,Text=title,
        Size=UDim2.fromOffset(w,35),
        Position=UDim2.fromOffset(x,204),
        BorderSizePixel=0,Font=Enum.Font.GothamBold,TextSize=12,
        TextColor3=Color3.fromRGB(242,248,253),
        BackgroundColor3=fill or Color3.fromRGB(49,92,144)},panel)
    elem("UICorner",{CornerRadius=UDim.new(0,5)},b)
    return b
end
local start=button("Start","AUTO CAPTURE",153,172,Color3.fromRGB(28,119,101))
local stop=button("Stop","STOP & SAVE",336,110,Color3.fromRGB(164,65,77))
local copy=button("Copy","COPY REPORT",456,120)
-- Visible close control: safe after a capture has finished and the final
-- manifest/cache checkpoints have been written to the executor workspace.
-- Closing this GUI never deletes the saved output directory.
local closePanel=elem("TextButton",{
    Name="ClosePanel",Text="CLOSE PANEL",
    Size=UDim2.fromOffset(131,30),
    Position=UDim2.fromOffset(445,11),
    BorderSizePixel=0,
    Font=Enum.Font.GothamBold,TextSize=11,
    TextColor3=Color3.fromRGB(255,241,246),
    BackgroundColor3=Color3.fromRGB(116,62,81)
},panel)
elem("UICorner",{CornerRadius=UDim.new(0,6)},closePanel)
closePanel.Activated:Connect(function()
    if D.running or D.startQueued then
        D.current="Capture still running: wait for COMPLETE or use STOP & SAVE."
        D.refresh()
        return
    end
    -- Completed capture data is already on disk. This only removes the panel.
    if D.fpsConnection then D.fpsConnection:Disconnect();D.fpsConnection=nil end
    if D.gui and D.gui.Parent then D.gui:Destroy() end
    warn("[EMPIRE CLASH NOVA] Panel closed. Saved capture files were not removed.")
end)
start.Activated:Connect(function()
    if not D.running and not D.startQueued and not D.root then
        D.startQueued=true
        task.defer(function()
            D.startQueued=false
            D.run()
        end)
    end
end)
stop.Activated:Connect(function()
    if D.running then D.stopped=true
        D.current="Stop requested; saving completed binary files."
        D.refresh()
    end
end)
copy.Activated:Connect(function()
    if API.clipboard then
        pcall(API.clipboard,encode(summary()))
        D.current="Report copied. Paste into ChatGPT."
    else D.current="Clipboard unavailable; see manifest.json.txt." end
    D.refresh()
end)
D.refresh()
warn("[EMPIRE CLASH NOVA] Read-only collector starting for place "..tostring(game.PlaceId))
task.defer(function()
    if not D.running and not D.startQueued and not D.root then D.run() end
end)

