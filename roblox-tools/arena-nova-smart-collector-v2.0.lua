-- ARENA NOVA SMART COLLECTOR v2.0
-- Complete accessible hierarchy inventory; priority-driven, time-budgeted source
-- extraction with persistent local cache. Read-only except for this tool's UI
-- and files. No require, remote invocation, hooks, hidden identity, or upload.
local CFG={
    version="2.0.0", universe=7209131331, rootPlace=72238253016204,
    home="ARENA_NOVA_SMART_V2",
    maxObjects=200000, maxDepth=100, maxCandidates=25000,
    recordChunkBytes=192*1024, maxSourceBytes=3*1024*1024,
    lobbyBudgetSeconds=110, matchBudgetSeconds=38,
    decompileTimeout=4.0, fallbackTimeout=2.5, bytecodeTimeout=0.8,
    metadataSlice=300, rapidLimit=1200, sourceCheckpoint=5,
    maxFileBytes=3*1024*1024,
}
if game.PlaceId~=CFG.rootPlace and game.GameId~=CFG.universe then
    warn("[ARENA NOVA SMART] Wrong Roblox experience.");return
end
local Http=game:GetService("HttpService")
local Players=game:GetService("Players")
local P=Players.LocalPlayer
if not P then warn("[ARENA NOVA SMART] LocalPlayer unavailable.");return end
local PG=P:FindFirstChildOfClass("PlayerGui")
if not PG then warn("[ARENA NOVA SMART] PlayerGui unavailable; rejoin.");return end
local gEnv=nil
if type(getgenv)=="function" then
    local ok,r=pcall(getgenv)
    if ok and type(r)=="table" then gEnv=r end
end
local function api(name)
    local fn=nil
    local ok,r=pcall(function()return (getfenv and getfenv()[name]) or nil end)
    if ok and type(r)=="function" then fn=r end
    if not fn and gEnv and type(gEnv[name])=="function" then fn=gEnv[name] end
    return fn
end
local API={
    write=api("writefile"),read=api("readfile"),mkdir=api("makefolder"),
    isfolder=api("isfolder"),decompile=api("decompile"),
    bytecode=api("getscriptbytecode"),clipboard=api("setclipboard"),
}
local placeVersion=0
pcall(function()placeVersion=game.PlaceVersion end)
local D={
    running=false,stopped=false,mode="LOBBY",phase="READY",root=nil,session=nil,
    started=0,deadline=0,latest="Ready. Nothing has been scanned.",
    c={objects=0,scripts=0,eligible=0,remotes=0,values=0,focus=0,
       attrs=0,details=0,readWarnings=0,sourceExported=0,
       directSourceSuccess=0,nativeSuccess=0,fallbackSuccess=0,
       cacheHit=0,cacheUnverified=0,
       cacheInvalid=0,cachedFailuresSkipped=0,sourceFailures=0,
       sourceDeferred=0,sourceSkippedTime=0,sourceQueued=0,
       rapid=0,privacySkipped=0,redactions=0,unsafeSource=0,
       nativeTimeouts=0,fallbackTimeouts=0,files=0,writeErrors=0},
    errors={},sources={},visited={},privateRoots={},names={},
    streams={},scriptQueue={},cache={version=2,next=0,entries={}},
    scannedComplete=false,sourceComplete=false,stopReason=nil,
    showReport=false,gui=nil,connections={},outputFiles={},
}
function D.sensitiveKey(key)
    local k = tostring(key):lower():gsub("[^%w]", "")
    for _, word in ipairs({"password", "passwd", "secret", "cookie", "authorization", "credential",
        "accesstoken", "refreshtoken", "authtoken", "apikey", "privatekey", "sessionkey",
        "sessionid", "bearer", "csrf", "roblosecurity", "webhook"}) do
        if k:find(word, 1, true) then return true end
    end
    return k == "token" or k == "auth" or k == "email" or k == "phone"
end
function D.secretString(text)
    local low = text:lower()
    if low:find("roblosecurity", 1, true) or low:find("bearer ", 1, true)
        or low:find("begin private key", 1, true) or low:find("github_pat_", 1, true)
        or low:find("ghp_", 1, true) or low:find("discord.com/api/webhooks", 1, true)
        or low:find("sk%-[%w_%-][%w_%-][%w_%-][%w_%-][%w_%-]")
        or text:find("AKIA[A-Z0-9]+") or text:find("eyJ[%w_%-]+%.[%w_%-]+%.[%w_%-]+")
        or text:find("[%w_.+%-]+@[%w.%-]+%.[%a]+") then return true end
    for key in low:gmatch("([%w_%-]+)%s*[:=]") do
        if D.sensitiveKey(key) then return true end
    end
    -- Quoted JSON keys, credential URLs, and unknown long opaque strings.
    for key in low:gmatch('["\']([%w_%-]+)["\']%s*:') do
        if D.sensitiveKey(key) then return true end
    end
    if low:find("https?://") and (low:find("?", 1, true) or low:find("@", 1, true)) then return true end
    if #text >= 32 and text:match("^[%w+/=_%-]+$") and not text:match("^%d+$") then return true end
    return false
end
function D.safeString(v,key)
    if D.sensitiveKey(key) or D.secretString(v) or D.names[v] then
        D.c.redactions+=1;return "[REDACTED]"
    end
    if #v>280 then return "[long-text-omitted:"..#v.."]" end
    return v
end
function D.safeValue(v,key)
    local t=typeof(v)
    if D.sensitiveKey(key) then return "[sensitive]" end
    if t=="string" then return D.safeString(v,key) end
    if t=="number" and v==v and v~=math.huge and v~=-math.huge then return v end
    if t=="boolean" then return v end
    if t=="Vector3" or t=="Vector2" or t=="Color3" or t=="EnumItem"
        or t=="UDim" or t=="UDim2" then return tostring(v) end
    if t=="Instance" then return {type="Instance",class=v.ClassName} end
    if t=="nil" then return nil end
    return {type=t}
end
function D.adler32(data)
    local a,b=1,0
    for pos=1,#data,2048 do
        local en=math.min(#data,pos+2047)
        for k=pos,en do
            a=(a+string.byte(data,k))%65521
            b=(b+a)%65521
        end
    end
    return string.format("%08x",b*65536+a)
end
function D.encode(v)
    local ok,r=pcall(function()return Http:JSONEncode(v)end)
    if ok then return r end
    return "{}"
end
function D.mk(path)
    if API.isfolder then
        local ok,v=pcall(API.isfolder,path)
        if ok and v then return true end
    end
    if not API.mkdir then return false end
    local ok,v=pcall(API.mkdir,path)
    if ok and v~=false then return true end
    if API.isfolder then
        local pass,exists=pcall(API.isfolder,path)
        return pass and exists
    end
    return false
end
function D.makeParents(path)
    local root=""
    local parent=path:match("^(.*)/[^/]+$") or ""
    for part in parent:gmatch("[^/]+") do
        root=(root=="" and part or root.."/"..part)
        if not D.mk(root) then return false end
    end
    return true
end
function D.write(path,body)
    if not API.write then return false end
    if not D.makeParents(path) then
        D.c.writeErrors+=1;return false
    end
    local ok,res=pcall(API.write,path,body)
    if not ok or res==false then
        D.c.writeErrors+=1;return false
    end
    D.c.files+=1
    return true
end
function D.readFile(path)
    if not API.read then return nil end
    local ok,content=pcall(API.read,path)
    if ok and type(content)=="string" then return content end
    return nil
end
function D.record(name,value)
    local st=D.streams[name]
    if not st then
        st={buffer={},bytes=0,num=0,records=0,files={}}
        D.streams[name]=st
    end
    local line=D.encode(value).."\n"
    st.buffer[#st.buffer+1]=line
    st.bytes+=#line
    st.records+=1
    if st.bytes>=CFG.recordChunkBytes then D.flush(name) end
end
function D.flush(name)
    local st=D.streams[name]
    if not st or st.bytes==0 then return end
    st.num+=1
    local path=D.session.."/"..name.."_"..string.format("%04d",st.num)..".ndjson.txt"
    local body=table.concat(st.buffer)
    if D.write(path,body) then
        st.files[#st.files+1]={path=path,bytes=#body,adler32=D.adler32(body)}
    end
    st.buffer={};st.bytes=0
end
function D.flushAll()
    for k in pairs(D.streams) do D.flush(k) end
end
function D.summary()
    return {
        tool="arena-nova-smart-collector",version=CFG.version,
        mode=D.mode,place_id=game.PlaceId,universe_id=game.GameId,
        place_version=placeVersion,phase=D.phase,
        elapsed_s=math.floor((os.clock()-D.started)*10)/10,
        complete_inventory=D.scannedComplete,
        complete_source_pass=D.sourceComplete,
        source_budget_expired=D.stopReason=="time_budget",
        stopped_early=D.stopped,
        reason=D.stopReason,
        counts=D.c,
        cache_path=CFG.home.."/cache_index.json.txt",
        output_root=D.session,
        raw_bytecode_exported=false,
        privacy_scrub_is_heuristic=true,
        cache_reuse_unverified_without_matching_bytecode=true,
        server_only_content_not_available=true,
        source_statuses_are_not_proof_of_server_authority=true,
    }
end
function D.checkpoint()
    D.flushAll()
    if D.session then
        local all={}
        for k,v in pairs(D.streams) do
            all[k]={records=v.records,files=v.files}
        end
        D.write(D.session.."/manifest.json.txt",D.encode({summary=D.summary(),
            streams=all,updated_unix=os.time()}))
    end
end
function D.saveCache()
    if API.write then
        D.write(CFG.home.."/cache_index.json.txt",D.encode(D.cache))
    end
end
function D.loadCache()
    local blob=D.readFile(CFG.home.."/cache_index.json.txt")
    if not blob then return end
    local ok,t=pcall(function()return Http:JSONDecode(blob)end)
    if ok and type(t)=="table" and t.version==2
        and type(t.entries)=="table" then
        D.cache=t
        if type(D.cache.next)~="number" then D.cache.next=0 end
    end
end
function D.logErr(kind,key)
    D.errors[kind]=(D.errors[kind] or 0)+1
    D.record("errors",{kind=kind,script=key,elapsed_s=math.floor(os.clock()-D.started)})
end
function D.private(obj)
    local node=obj
    for _=1,CFG.maxDepth+4 do
        if node==D.gui then return true end
        if D.privateRoots[node] then return true end
        if node==game then return false end
        local ok,parent=pcall(function()return node.Parent end)
        if not ok or not parent then return true end
        node=parent
    end
    return true
end
function D.buildPrivacy()
    for _,other in ipairs(Players:GetPlayers()) do
        if other~=P then
            D.privateRoots[other]=true
            local c=other.Character
            if c then D.privateRoots[c]=true end
            D.names[other.Name]=true
            D.names[other.DisplayName]=true
            D.names[tostring(other.UserId)]=true
        end
    end
    D.names[P.Name]=true
    D.names[P.DisplayName]=true
    D.names[tostring(P.UserId)]=true
    -- New players can join while a long inventory is underway.
    Players.PlayerAdded:Connect(function(other)
        if other~=P then
            D.privateRoots[other]=true
            D.names[other.Name]=true
            D.names[other.DisplayName]=true
            D.names[tostring(other.UserId)]=true
            other.CharacterAdded:Connect(function(character)
                D.privateRoots[character]=true
            end)
        end
    end)
    for _,other in ipairs(Players:GetPlayers()) do
        if other~=P then
            other.CharacterAdded:Connect(function(character)
                D.privateRoots[character]=true
            end)
        end
    end
end
local FOCUS={"arena","round","map","combat","damage","weapon","inventory",
"loot","pickup","drop","health","stamina","sprint","movement","surviv",
"disaster","storm","zone","barrier","crate","chest","shop","item",
"ability","power","perk","event","remote","tool","projectile","attack",
"shield","block","parry","heal","match","lobby","config"}
function D.focus(path)
    local low=path:lower()
    for _,word in ipairs(FOCUS) do
        if low:find(word,1,true) then return true end
    end
    return false
end
local function isPlatform(path)
    return path:find("^game/CoreGui")
        or path:find("^game/CorePackages")
        or path:find("^game/RobloxReplicatedStorage")
        or path:find("^game/RobloxReplicatedScriptStorage")
        or path:find("/PlayerModule",1,true)
        or path:find("/ChatScript",1,true)
end
function D.rapidScene()
    D.phase="RAPID SNAPSHOT"
    local roots={
        {"Workspace",game:GetService("Workspace")},
        {"ReplicatedStorage",game:GetService("ReplicatedStorage")},
        {"Backpack",P:FindFirstChildOfClass("Backpack")},
        {"PlayerGui",PG},
    }
    for _,spec in ipairs(roots) do
        local root=spec[2]
        if root then
            local q={{root,"game/"..spec[1],0}}
            local head=1
            local taken=0
            while head<=#q and taken<CFG.rapidLimit and not D.stopped do
                local item=q[head]
                q[head]=false;head+=1
                local obj,path,depth=item[1],item[2],item[3]
                if not D.private(obj) then
                    local ok,class=pcall(function()return obj.ClassName end)
                    if ok then
                        taken+=1;D.c.rapid+=1
                        D.record("rapid",{path=path,class=class,
                            t=math.floor((os.clock()-D.started)*100)/100})
                        if depth<9 then
                            local good,kids=pcall(function()return obj:GetChildren()end)
                            if good then
                                for _,kid in ipairs(kids) do
                                    if not D.privateRoots[kid] then
                                        q[#q+1]={kid,path.."/"..D.safeString(kid.Name,"name"),depth+1}
                                    end
                                end
                            end
                        end
                    end
                end
                if taken%120==0 then task.wait() end
            end
            D.flush("rapid")
        end
    end
    D.checkpoint()
end
function D.enumerate()
    D.phase="FULL INVENTORY"
    D.latest="Inventorying all accessible game objects and client scripts."
    -- Parent-frame traversal proves ancestry; avoid walking parent chain
    -- per object (a major performance cost in the inherited collector).
    local queue={{game,"game",0,0,"game"}}
    local head=1
    local id=0
    local categoryCount={game=0,platform=0}
    local burst=0
    while head<=#queue and not D.stopped and D.c.objects<CFG.maxObjects do
        local frame=queue[head]
        queue[head]=false;head+=1
        local obj,path,parent,depth,root=frame[1],frame[2],frame[3],frame[4],frame[5]
        if not D.visited[obj] and obj~=D.gui and not D.privateRoots[obj] then
            D.visited[obj]=true
            local ok,class=pcall(function()return obj.ClassName end)
            if ok then
                id+=1;D.c.objects+=1
                local name=D.safeString(obj.Name,"name")
                local platform=isPlatform(path) and "platform" or "game"
                categoryCount[platform]+=1
                D.record("objects",{id=id,parent=parent,path=path,name=name,
                    class=class,category=platform})
                local remote=(class=="RemoteEvent" or class=="RemoteFunction"
                    or class=="UnreliableRemoteEvent" or class=="BindableEvent"
                    or class=="BindableFunction")
                if remote then
                    D.c.remotes+=1
                    D.record("remotes",{id=id,path=path,class=class,
                        invoked=false,traffic_captured=false})
                end
                local focus=D.focus(path)
                if focus then D.c.focus+=1 end
                local script=(class=="ModuleScript" or class=="LocalScript" or class=="Script")
                if script then
                    D.c.scripts+=1
                    local eligible=class~="Script"
                    if class=="Script" then
                        local rok,ctx=pcall(function()return obj.RunContext end)
                        eligible=rok and tostring(ctx)=="Enum.RunContext.Client"
                    end
                    D.record("scripts",{id=id,path=path,class=class,category=platform,
                        eligible=eligible,focus=focus})
                    if eligible then
                        D.c.eligible+=1
                        if #D.scriptQueue<CFG.maxCandidates then
                            D.scriptQueue[#D.scriptQueue+1]={
                                obj=obj,path=path,class=class,category=platform,
                                score=(platform=="platform" and 0 or 200)
                                    +(focus and 100 or 0)
                                    +((root=="ReplicatedStorage" or root=="ReplicatedFirst") and 60 or 0)
                            }
                        else D.logErr("source_candidate_limit",path) end
                    end
                end
                local isValue=class:sub(-5)=="Value"
                if isValue and not D.sensitiveKey(name) then
                    local vok,val=pcall(function()return obj.Value end)
                    if vok then
                        D.c.values+=1
                        D.record("values",{id=id,path=path,value=D.safeValue(val,name)})
                    end
                end
                if focus or remote or script or class=="Tool" then
                    D.c.details+=1
                    local extra={}
                    if class=="Tool" then
                        pcall(function()extra.toolTip=D.safeString(obj.ToolTip,"tooltip")end)
                        pcall(function()extra.requiresHandle=obj.RequiresHandle end)
                    end
                    if obj:IsA("BasePart") then
                        pcall(function()extra.size=tostring(obj.Size)end)
                        pcall(function()extra.canCollide=obj.CanCollide end)
                    end
                    if obj:IsA("Animation") then
                        pcall(function()extra.animation=D.safeString(obj.AnimationId,"asset")end)
                    end
                    if obj:IsA("Sound") then
                        pcall(function()extra.sound=D.safeString(obj.SoundId,"asset")end)
                    end
                    if obj:IsA("MeshPart") then
                        pcall(function()extra.mesh=D.safeString(obj.MeshId,"asset")end)
                    end
                    local attrs={}
                    local aok,av=pcall(function()return obj:GetAttributes()end)
                    if aok and type(av)=="table" then
                        local count=0
                        for k,v in pairs(av) do
                            if count>=48 then break end
                            if not D.sensitiveKey(k) then
                                attrs[D.safeString(k,"attribute-key")]=D.safeValue(v,k)
                                D.c.attrs+=1
                                count+=1
                            end
                        end
                    else D.c.readWarnings+=1 end
                    D.record("details",{id=id,path=path,props=extra,attrs=attrs})
                end
                if depth<CFG.maxDepth then
                    local cok,kids=pcall(function()return obj:GetChildren()end)
                    if cok and type(kids)=="table" then
                        local siblingCounts={}
                        for _,kid in ipairs(kids) do
                            local n=kid.Name
                            local low=n:lower():gsub("[^%w]","")
                            local privateBranch=(low=="playerdata" or low=="userdata"
                                or low=="profiles" or low=="authdata"
                                or low=="privatemessages" or low=="directmessages")
                            if not D.privateRoots[kid] and kid~=D.gui and not privateBranch then
                                local safe=D.safeString(n,"name")
                                local key=safe.."|"..kid.ClassName
                                local ordinal=(siblingCounts[key] or 0)+1
                                siblingCounts[key]=ordinal
                                local segment=safe
                                if ordinal>1 then segment=safe.."~"..ordinal end
                                queue[#queue+1]={kid,path.."/"..segment,id,depth+1,
                                    depth==0 and safe or root}
                            else D.c.privacySkipped+=1 end
                        end
                    else D.c.readWarnings+=1 end
                end
            end
        else D.c.privacySkipped+=1 end
        burst+=1
        if burst>=CFG.metadataSlice then
            burst=0
            D.latest="Inventory: "..D.c.objects.." objects, "..D.c.eligible.." eligible client scripts"
            D.updateUI()
            task.wait()
            if os.clock()>=D.deadline-8 then
                D.stopReason="inventory_time_budget";break
            end
        end
    end
    D.scannedComplete=head>#queue and not D.stopped
        and D.c.objects<CFG.maxObjects
    if D.c.objects>=CFG.maxObjects then D.stopReason="object_safety_cap" end
    table.sort(D.scriptQueue,function(a,b)
        if a.score==b.score then return a.path<b.path end
        return a.score>b.score
    end)
    D.c.sourceQueued=#D.scriptQueue
    D.record("coverage",{complete=D.scannedComplete,counts=categoryCount,
        eligible=D.c.eligible,queued=#D.scriptQueue,
        limit=CFG.maxObjects,pending=math.max(0,#queue-head+1)})
    D.checkpoint()
end
function D.runLimited(fn,target,timeout)
    if not fn then return false,"api_missing",0 end
    if D.stopped then return false,"stopped",0 end
    local t0=os.clock()
    local state={done=false,alive=true,ok=false,result=nil}
    local worker
    local sent=pcall(function()
        worker=task.defer(function()
            if not state.alive then return end
            local ok,result=pcall(fn,target)
            if state.alive then
                state.ok,state.result,state.done=ok,result,true
            end
        end)
    end)
    if not sent then return false,"dispatch_failed",0 end
    while not state.done and not D.stopped and os.clock()-t0<timeout do
        task.wait()
    end
    local elapsed=os.clock()-t0
    if state.done then
        return state.ok,state.result,elapsed
    end
    state.alive=false
    if worker and task.cancel then pcall(task.cancel,worker) end
    return false,D.stopped and "stopped" or "timeout",elapsed
end
function D.plausibleSource(body)
    if type(body)~="string" or #body==0 then return false,"empty_source" end
    if #body>CFG.maxSourceBytes then return false,"oversize_source" end
    local low=body:sub(1,400):lower()
    if low:find("failed to decompile",1,true)
        or low:find("decompilation failed",1,true)
        or low:find("failed to get script bytecode",1,true)
        or low:find("script has no bytecode",1,true) then
        return false,"decompiler_placeholder"
    end
    return true,nil
end
function D.filterSource(source)
    local out, at, n, redactions, hasCode = {}, 1, #source, 0, false
    local function longEnd(position)
        if source:sub(position,position) ~= "[" then return nil end
        local last = position + 1
        while source:sub(last,last) == "=" do last = last + 1 end
        if source:sub(last,last) ~= "[" then return nil end
        local equals = source:sub(position + 1,last - 1)
        local opening = last - position + 1
        local close = "]" .. equals .. "]"
        local finish = source:find(close, position + opening, true)
        return finish and finish + #close - 1 or n, opening, finish
    end
    while at <= n do
        local char, nextTwo = source:sub(at, at), source:sub(at, at + 1)
        if nextTwo == "--" then
            local finish = longEnd(at + 2)
            if not finish then finish = (source:find("\n", at + 2, true) or n + 1) - 1 end
            local removed = source:sub(at, finish)
            local _, newlines = removed:gsub("\n", "")
            out[#out + 1] = "--[[comment omitted]]" .. string.rep("\n", newlines)
            at, redactions = finish + 1, redactions + 1
        elseif char == '"' or char == "'" then
            hasCode = true
            local finish, escaped = at + 1, false
            while finish <= n do
                local c = source:sub(finish, finish)
                if not escaped and c == char then break end
                if not escaped and c == "\\" then escaped = true else escaped = false end
                finish = finish + 1
            end
            finish = math.min(finish, n)
            local literal = source:sub(at + 1, finish - 1)
            local context = source:sub(math.max(1, at - 100), at - 1):match("([^\n]*)$") or ""
            local risky = D.secretString(literal) or D.sensitiveKey(context)
            -- Escaped string bytes cannot be reliably inspected without evaluating code.
            if literal:find("\\%d") or literal:find("\\[xu]") then risky = true end
            out[#out + 1] = risky and (char .. "[REDACTED]" .. char) or source:sub(at, finish)
            if risky then redactions = redactions + 1 end
            at = finish + 1
        elseif char == "[" then
            hasCode = true
            local finish, opening, closing = longEnd(at)
            if finish then
                local context = source:sub(math.max(1, at - 100), at - 1):match("([^\n]*)$") or ""
                local literal = source:sub(at + opening, (closing or n + 1) - 1)
                if D.secretString(literal) or D.sensitiveKey(context) then
                    out[#out + 1] = '"[REDACTED]"'; redactions = redactions + 1
                else out[#out + 1] = source:sub(at, finish) end
                at = finish + 1
            else out[#out + 1] = char; at = at + 1 end
        else
            -- Copy code in runs, avoiding one table entry per source byte.
            local finish = source:find("[%[\"'%-]", at + 1) or n + 1
            local run = source:sub(at,finish - 1)
            if run:find("%S") then hasCode = true end
            out[#out + 1] = run
            at = finish
        end
    end
    return table.concat(out), redactions, hasCode
end


function D.cacheKey(entry)
    return tostring(game.PlaceId).."|"..entry.class.."|"..entry.path
end
function D.exportSource(entry,body,method,cacheConfidence)
    local usable,reason=D.plausibleSource(body)
    if not usable then return false,reason end
    local filtered,edits,hasCode=D.filterSource(body)
    if not hasCode or #filtered==0 then return false,"no_usable_code" end
    D.c.redactions+=edits
    local index=D.c.sourceExported+1
    local path=D.session.."/sources/S"..string.format("%05d",index)..".source.txt"
    if not D.write(path,filtered) then return false,"file_write_failed" end
    D.c.sourceExported+=1
    D.record("source_results",{path=entry.path,class=entry.class,
        method=method,status="exported",file=path,bytes=#filtered,
        adler32=D.adler32(filtered),cache_confidence=cacheConfidence,
        privacy_filtered=true,original_source_guaranteed=false})
    if method~="persistent_cache" and API.read and API.write then
        D.cache.next+=1
        local cachePath=CFG.home.."/sources/S"..string.format("%06d",D.cache.next)..".source.txt"
        if D.write(cachePath,filtered) then
            D.cache.entries[D.cacheKey(entry)]={
                path=cachePath,placeVersion=placeVersion,
                bytes=#filtered,adler32=D.adler32(filtered),
                category=entry.category,created_unix=os.time()
            }
        end
    end
    return true,nil
end
function D.tryCache(entry)
    if not API.read then return false end
    local cached=D.cache.entries[D.cacheKey(entry)]
    if not cached or cached.placeVersion~=placeVersion
        or type(cached.path)~="string" then return false end
    local body=D.readFile(cached.path)
    if not body or #body~=cached.bytes or D.adler32(body)~=cached.adler32 then
        D.c.cacheInvalid+=1
        D.cache.entries[D.cacheKey(entry)]=nil
        return false
    end
    -- Cache reuse is same-game-version/path, not bytecode identity proof.
    local ok=D.exportSource(entry,body,"persistent_cache",
        "same_place_version_and_script_path_unverified")
    if ok then D.c.cacheHit+=1;D.c.cacheUnverified+=1 end
    return ok
end
function D.failureKind(raw)
    local text=tostring(raw or ""):lower()
    if text:find("timeout",1,true) then return "decompiler_timeout" end
    if text:find("permission",1,true) or text:find("security",1,true)
        then return "permission_denied" end
    if text:find("bytecode",1,true) and text:find("unsupported",1,true)
        then return "unsupported_bytecode" end
    if text:find("no bytecode",1,true) or text:find("empty bytecode",1,true)
        then return "no_accessible_bytecode" end
    if text:find("not supported",1,true) or text:find("unavailable",1,true)
        then return "decompiler_unavailable" end
    if text=="api_missing" then return "executor_api_missing" end
    return "executor_failure_details_withheld"
end
function D.failSource(entry,reason,attempted)
    D.c.sourceFailures+=1
    D.record("source_results",{path=entry.path,class=entry.class,
        status="failed",reason=reason,attempted=attempted~=false})
    D.logErr(reason,entry.path)
    -- Failed source is retried after a cooldown, never permanently written
    -- off. A new game place-version immediately invalidates the skip.
    D.cache.entries[D.cacheKey(entry)]={
        failed=reason,placeVersion=placeVersion,
        category=entry.category,created_unix=os.time(),
        retry_after_unix=os.time()+900}
end
function D.collectSources()
    D.phase="SOURCE EXTRACTION"
    D.latest="Reusing prior code and prioritising game scripts."
    local completed=0
    local lastCacheSave=os.clock()
    for idx,entry in ipairs(D.scriptQueue) do
        if D.stopped then D.stopReason="user_stopped";break end
        if os.clock()>=D.deadline then
            D.stopReason="time_budget";break
        end
        local cached=D.cache.entries[D.cacheKey(entry)]
        if D.tryCache(entry) then
            completed+=1
        elseif cached and cached.failed and cached.placeVersion==placeVersion
            and type(cached.retry_after_unix)=="number"
            and os.time()<cached.retry_after_unix then
            D.c.cachedFailuresSkipped+=1
            D.record("source_results",{path=entry.path,class=entry.class,
                status="prior_failure_not_retried",
                reason=cached.failed,place_version=placeVersion})
            completed+=1
        else
            local ok,body=pcall(function()return entry.obj.Source end)
            local method="Source_property"
            if not ok or type(body)~="string" or #body==0 then
                method="decompile_instance"
                ok,body=D.runLimited(API.decompile,entry.obj,
                    math.min(CFG.decompileTimeout,math.max(0.1,D.deadline-os.clock())))
                if not ok and body=="timeout" then D.c.nativeTimeouts+=1 end
            end
            local accepted,why=false,nil
            if ok then
                accepted,why=D.exportSource(entry,body,method,nil)
            else
                why=D.failureKind(body)
            end
            if accepted then
                if method=="Source_property" then D.c.directSourceSuccess+=1
                else D.c.nativeSuccess+=1 end
            elseif API.bytecode and API.decompile and os.clock()+1<D.deadline then
                -- Recovery is capped and only used for a failing game script;
                -- inaccessible platform bytecode is not worth delaying game data.
                if entry.category=="game" then
                    local bok,bytes=D.runLimited(API.bytecode,entry.obj,
                        math.min(CFG.bytecodeTimeout,math.max(0.1,D.deadline-os.clock())))
                    local fallbackGood=false
                    if bok and type(bytes)=="string" and #bytes>0
                        and #bytes<CFG.maxSourceBytes and os.clock()+1<D.deadline then
                        local decOk,source=D.runLimited(API.decompile,bytes,
                            math.min(CFG.fallbackTimeout,math.max(0.1,D.deadline-os.clock())))
                        if not decOk and source=="timeout" then D.c.fallbackTimeouts+=1 end
                        if decOk then
                            fallbackGood=D.exportSource(entry,source,"decompile_bytecode",nil)
                        end
                    end
                    if fallbackGood then
                        D.c.fallbackSuccess+=1
                    else
                        D.failSource(entry,why or "decompiler_or_bytecode_failed",true)
                    end
                else D.failSource(entry,why or "native_decompile_failed",true) end
            else
                D.failSource(entry,why or "native_decompile_unavailable",true)
            end
            completed+=1
        end
        entry.obj=nil
        D.latest="Sources "..completed.."/"..#D.scriptQueue..
            " | exported "..D.c.sourceExported..
            " | cached "..D.c.cacheHit..
            " | failures "..D.c.sourceFailures
        if completed%4==0 then
            D.updateUI();task.wait()
        end
        if completed%CFG.sourceCheckpoint==0 or os.clock()-lastCacheSave>=8 then
            D.checkpoint();D.saveCache();lastCacheSave=os.clock()
        end
    end
    D.c.sourceDeferred=math.max(0,#D.scriptQueue-completed)
    D.c.sourceSkippedTime=(D.stopReason=="time_budget") and D.c.sourceDeferred or 0
    D.sourceComplete=completed==#D.scriptQueue and not D.stopped
        and D.stopReason~="time_budget"
    D.checkpoint();D.saveCache()
end
function D.updateUI()
    if not D.gui or not D.gui.Parent then return end
    if not D.labels then return end
    D.labels.status.Text=D.phase.." / "..D.mode
    D.labels.count.Text="Objects "..D.c.objects.."  Scripts "..D.c.eligible..
        "  Remotes "..D.c.remotes.."  Sources "..D.c.sourceExported..
        "  Failures "..D.c.sourceFailures.."  Cache "..D.c.cacheHit
    D.labels.current.Text=D.latest
    D.labels.footer.Text="Saved: "..(D.session or "not started")..
        " | elapsed "..math.floor(os.clock()-D.started).."s"
    D.labels.mode.Text="MODE: "..D.mode
end
function D.run()
    if D.running then return end
    D.running=true;D.stopped=false;D.started=os.clock()
    D.deadline=D.started+(D.mode=="MATCH" and CFG.matchBudgetSeconds
        or CFG.lobbyBudgetSeconds)
    D.phase="STARTING";D.latest="Checking executor filesystem..."
    D.updateUI()
    if not API.write or not API.mkdir then
        D.phase="FILE APIS UNAVAILABLE"
        D.latest="Potassium must support writefile and makefolder."
        D.running=false;D.updateUI()
        return
    end
    D.mk(CFG.home)
    D.buildPrivacy()
    D.loadCache()
    local stamp=os.date("!%Y%m%d_%H%M%S")
    local suffix=Http:GenerateGUID(false):gsub("%W",""):sub(1,8)
    D.session=CFG.home.."/captures/"..D.mode.."_"..stamp.."_"..suffix
    if not D.mk(CFG.home.."/captures") or not D.mk(D.session) then
        D.phase="WRITE FAILED";D.latest="Could not create capture directory."
        D.running=false;D.updateUI();return
    end
    D.write(D.session.."/README.txt",
        "ARENA NOVA SMART v2.0 - self-contained capture folder.\n"..
        "Source cache in "..CFG.home.."/cache_index.json.txt supports later scans.\n"..
        "ZIP this capture folder only, including all objects/sources/manifest files.\n"..
        "All results are a client-side snapshot, not server code.\n")
    D.checkpoint()
    local ok,err=pcall(function()
        D.rapidScene()
        if not D.stopped then D.enumerate() end
        if not D.stopped and os.clock()<D.deadline then D.collectSources()
        else
            D.c.sourceDeferred=#D.scriptQueue
            D.checkpoint()
        end
    end)
    if not ok then
        D.stopReason="collector_exception"
        D.phase="FAILED - PARTIAL SAVED"
        D.logErr("collector_exception",nil)
        D.latest="Scan error. Existing completed capture files were kept."
    elseif D.stopped then
        D.phase="STOPPED - PARTIAL SAVED"
        D.latest="Stopped safely. Capture files have been saved."
    elseif D.stopReason=="time_budget" or D.stopReason=="inventory_time_budget" then
        D.phase="BUDGET REACHED - SAVED"
        D.latest="Time budget reached. Run again to continue, reusing cached source."
    else
        D.phase="COMPLETE";D.latest="Saved. ZIP the capture folder to share it."
    end
    D.checkpoint();D.saveCache()
    D.running=false
    D.updateUI()
    warn("[ARENA NOVA SMART] "..D.phase.." | "..(D.session or "")..
        " | exported="..D.c.sourceExported.." | errors="..D.c.sourceFailures)
end
local old=PG:FindFirstChild("ArenaNovaSmartV20")
if old then pcall(function()old:Destroy()end)end
local function element(class,props,parent)
    local obj=Instance.new(class)
    for k,v in pairs(props) do pcall(function()obj[k]=v end)end
    obj.Parent=parent;return obj
end
local ui=element("ScreenGui",{Name="ArenaNovaSmartV20",ResetOnSpawn=false,
    IgnoreGuiInset=true,DisplayOrder=750},PG)
D.gui=ui
ui.Destroying:Connect(function() D.stopped=true end)
local panel=element("Frame",{
    BackgroundColor3=Color3.fromRGB(18,24,37),BorderSizePixel=0,
    Size=UDim2.fromOffset(600,318),Position=UDim2.fromScale(0.5,0.17),
    AnchorPoint=Vector2.new(0.5,0)},ui)
element("UICorner",{CornerRadius=UDim.new(0,12)},panel)
local cam=workspace.CurrentCamera
if cam then element("UIScale",{Scale=math.max(0.55,math.min(1,
    cam.ViewportSize.X/630,cam.ViewportSize.Y/370))},panel)end
local function label(t,y,height,fontSize)
    return element("TextLabel",{Text=t,BackgroundTransparency=1,
        TextColor3=Color3.fromRGB(223,236,249),TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,
        Font=Enum.Font.Gotham,TextSize=fontSize or 12,
        Position=UDim2.fromOffset(18,y),Size=UDim2.fromOffset(564,height)},panel)
end
label("ARENA NOVA  /  SMART HEAVY COLLECTOR  v2.0",12,30,16)
D.labels={
    status=label("READY / LOBBY",53,25,14),
    count=label("No scan yet.",83,36,12),
    current=label("Choose mode, then start.",129,50,12),
    footer=label("Only local files. No automatic upload.",255,52,11),
}
local function button(name,title,x,y,w,fill)
    local b=element("TextButton",{Name=name,Text=title,
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,35),
        BorderSizePixel=0,BackgroundColor3=fill or Color3.fromRGB(43,89,141),
        TextColor3=Color3.fromRGB(244,249,255),Font=Enum.Font.GothamBold,
        TextSize=12},panel)
    element("UICorner",{CornerRadius=UDim.new(0,6)},b)
    return b
end
D.labels.mode=button("Mode","MODE: LOBBY",18,195,139)
local start=button("Start","START SMART SCAN",170,195,190,Color3.fromRGB(21,117,93))
local stop=button("Stop","STOP & SAVE",373,195,101,Color3.fromRGB(155,57,68))
local copy=button("Copy","COPY SUMMARY",487,195,95)
D.labels.mode.Activated:Connect(function()
    if not D.running and not D.session then
        D.mode=D.mode=="LOBBY" and "MATCH" or "LOBBY"
        D.updateUI()
    end
end)
start.Activated:Connect(function()
    if not D.running and not D.session then task.defer(function()D.run()end)end
end)
stop.Activated:Connect(function()
    if D.running then D.stopped=true
        D.latest="Stop requested: sealing completed data..."
        D.updateUI()
    end
end)
copy.Activated:Connect(function()
    local report=D.encode(D.summary())
    if API.clipboard then
        pcall(API.clipboard,report)
        D.latest="Summary copied. Paste into chat."
    else D.latest="Clipboard unavailable. Find manifest.json.txt in the capture folder."end
    D.updateUI()
end)
D.started=os.clock()
D.updateUI()
warn("[ARENA NOVA SMART] v2.0 ready: 110s lobby / 38s match budget. All source caching is local.");
