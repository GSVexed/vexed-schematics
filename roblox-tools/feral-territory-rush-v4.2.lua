-- FERAL TERRITORY RUSH v4.2: SUBSURFACE + SESSION RECORDER
-- Claims verified by replicated game state; client cannot conceal teleports from other players.
-- Reads FeralTerritory.Hexes and per-hex attributes. Does not modify territory attrs.
-- Moves the actual animal. Automatic retries are bounded; success requires replicated territory state.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local me=Players.LocalPlayer
if not me or game.PlaceId~=108901361810209 then
    warn("[FERAL Territory Probe v2] Expected FERAL Animal Survival.")
    return
end
local env=(type(getgenv)=="function" and getgenv()) or _G
for _,name in ipairs({"FERAL_POSITION_CLAIM_PROBE","FERAL_TERRITORY_MAINTENANCE_V2","FERAL_TERRITORY_MAINTENANCE_V3","FERAL_TERRITORY_RUSH_V4","FERAL_RADIUS_EXPERIMENT"}) do
    local old=env[name]
    if type(old)=="table" and type(old.stop)=="function" then
        pcall(old.stop)
    end
end

local world=RS:WaitForChild("FeralWorld",12)
local module=world and world:FindFirstChild("TerritoryConfig")
local namesModule=world and world:FindFirstChild("MapSpots")
local terr=RS:WaitForChild("FeralTerritory",12)
local pg=me:FindFirstChildOfClass("PlayerGui")
if not (module and terr and pg) then
    warn("[FERAL Territory Probe v2] Territory data or PlayerGui unavailable. Spawn first.")
    return
end
local ok,cfg=pcall(require,module)
if not ok or type(cfg)~="table" or type(cfg.parseHexes)~="function"
    or type(cfg.hexCenter)~="function" or type(cfg.hexAt)~="function" then
    warn("[FERAL Territory Probe v2] Native territory geometry is unavailable.")
    return
end
local spotsData=nil
if namesModule then
    local good,result=pcall(require,namesModule)
    if good and type(result)=="table" then spotsData=result end
end
local hexString=terr:GetAttribute("Hexes")
if type(hexString)~="string" or hexString=="" then
    local untilTime=os.clock()+10
    repeat
        task.wait(0.3)
        hexString=terr:GetAttribute("Hexes")
    until (type(hexString)=="string" and hexString~="") or os.clock()>=untilTime
end
if type(hexString)~="string" or hexString=="" then
    warn("[FERAL Territory Probe v2] No server-replicated Hexes list received.")
    return
end
local raw=cfg.parseHexes(hexString)
local all={}
local byKey={}
for _,entry in ipairs(raw) do
    if type(entry.i)=="number" and type(entry.j)=="number"
        and type(entry.key)=="string" then
        local center=cfg.hexCenter(entry.i,entry.j)
        if typeof(center)=="Vector2" then
            local t={key=entry.key,center=center,landing=center,name=entry.key}
            table.insert(all,t)
            byKey[t.key]=t
        end
    end
end
if #all==0 then
    warn("[FERAL Territory Probe v2] Hex list is empty.")
    return
end

local biome=WS:GetAttribute("FeralBiome") or "WolfValley"
local landmarks=spotsData and (spotsData[biome] or spotsData.WolfValley)
if type(landmarks)=="table" then
    for _,spot in ipairs(landmarks) do
        if typeof(spot.pos)=="Vector2" then
            local i,j=cfg.hexAt(spot.pos.X,spot.pos.Y)
            local key=type(cfg.hexKey)=="function" and cfg.hexKey(i,j)
                or ("H"..tostring(i).."_"..tostring(j))
            local t=byKey[key]
            if t and not t.hasLandmark then
                t.hasLandmark=true
                t.landing=spot.pos
                t.name=spot.name or spot.key or key
            end
        end
    end
end

local function root()
    local c=me.Character
    local r=c and c:FindFirstChild("HumanoidRootPart")
    local h=c and c:FindFirstChildOfClass("Humanoid")
    if c and r and h and h.Health>0 and not r.Anchored then
        return c,r,h
    end
end
local function dist2D(p,pos)
    return math.sqrt((p.X-pos.X)^2+(p.Z-pos.Y)^2)
end
local function value(key,suffix)
    return terr:GetAttribute(key.."_"..suffix)
end
local function isNeutral(key)
    return value(key,"neutral")==true
end
local function hold(key)
    local v=value(key,"hold")
    if type(v)=="number" and v==v then return math.clamp(v,0,1) end
    return nil
end
local function isOwned(key)
    local pack=me:GetAttribute("FeralPack")
    return pack~=nil and value(key,"owner")==pack
end
local function countTypes()
    local pack=me:GetAttribute("FeralPack")
    local n={total=#all,eligible=0,owned=0,fading=0,remaining=0,neutral=0}
    for _,t in ipairs(all) do
        if isNeutral(t.key) then
            n.neutral+=1
        else
            n.eligible+=1
            if pack~=nil and value(t.key,"owner")==pack then
                n.owned+=1
                local h=hold(t.key)
                if h~=nil and h<0.985 then n.fading+=1 end
            else
                n.remaining+=1
            end
        end
    end
    return n
end

local mode="PRIORITY" -- Restore urgent pack scent, then capture other territory.
local SCENT_TRIGGER=0.85
local SCENT_SUCCESS=0.97
local retryCooldown={}
local landingCache={}
local claimCompletions=0
local claimDuration=0
local totalRetries,totalSkipped,totalCompleted=0,0,0
local lastFailure=nil
local autoBusy=false
local busySnap=false
local movementToken=0
local targets={}
local index=1
local selectedKey=nil
local active=true
local auto=false
local autoToken=0
local lastStatus="PRIORITY: restore scent under 85%, then claim"
local changedCount=0
local claimedCount=0
local reScentCount=0
local sampleLog={}
local attempt=nil
local lastLandingError=nil
local attemptedLandingHex=nil
local returnCFrame=nil
local returnCharacter=nil
local heartbeat=nil
local nextUpdate=0
local gui=nil
local L={}
local careConnection=nil
local careEnabled=false
local careBusy=false
local careMode=nil
local careResumeAuto=false
local careHuntEnabled=true
local careNextAction=0
local careLastSnapAt=-math.huge
local careAnchorChar=nil
local careLastNeedValue=nil
local careStartedAt=0
local carePendingAttempts=0
local careCooldownUntil=0
local careProfiles={{hunger=35,thirst=35,hp=0.40},{hunger=55,thirst=55,hp=0.55},{hunger=20,thirst=20,hp=0.30}}
local careProfileIndex=1
local careMessage="CARE OFF"
local inputUnavailable=false
-- Avoid all other replicated players, including members of your own pack.
-- A client may be unaware of unstreamed players: concealment is NOT guaranteed.
local avoidPlayers=true
local avoidRadii={120,200,300,450}
local avoidRadiusIndex=3
local travelStyle="ADAPTIVE" -- "WALK" never teleports
local visibilityHoldUntil=0
local lastSnapAttemptAt=-math.huge
local snapLockUntil=0
local snapCorrectionStreak=0
local snapCorrectionCount=0
local lastThreatDistance=math.huge
local lastThreatName=nil
local safeWalkRadius=155
-- User-requested subsurface territory hold. Experimental: neither true
-- replication invisibility nor server territory eligibility is guaranteed.
local undergroundRequested=false
local undergroundDepths={5,8,12}
local undergroundDepthIndex=2
local undergroundRefused=false
local undergroundConfirmed=nil
local undergroundState=nil
local hoverWatchConnection=nil
local undergroundFailures=0
local undergroundAttempts=0
local undergroundSuccesses=0
local undergroundStatus="OFF • server visibility cannot be guaranteed"
local careSnapPending=nil
local function undergroundDepth()
    return undergroundDepths[undergroundDepthIndex]
end
local function territoryNeedsAvoidance()
    -- Ignore nearby players only while the user deliberately enables the
    -- subsurface experiment. If the trial fails, revert to normal avoidance.
    return not (undergroundRequested and not undergroundRefused
        and travelStyle=="ADAPTIVE")
end
local function avoidRadius()
    return avoidRadii[avoidRadiusIndex]
end
local function nearestPlayerAt(position)
    local nearest=math.huge
    local seen=nil
    for _,other in ipairs(Players:GetPlayers()) do
        if other~=me then
            local character=other.Character
            local body=character and character:FindFirstChild("HumanoidRootPart")
            local hum=character and character:FindFirstChildOfClass("Humanoid")
            if body and body:IsA("BasePart") and (not hum or hum.Health>0) then
                local dx=body.Position.X-position.X
                local dz=body.Position.Z-position.Z
                local distance=math.sqrt(dx*dx+dz*dz)
                if distance<nearest then
                    nearest=distance
                    seen=other
                end
            end
        end
    end
    return nearest,seen
end
local function otherPlayerNearby(position,extra)
    if not avoidPlayers then return false,math.huge,nil end
    local distance,other=nearestPlayerAt(position)
    return distance<avoidRadius()+(extra or 0),distance,other
end
local function currentPlayerThreat()
    local _,body=root()
    if not body then return false end
    local threatened,distance,other=otherPlayerNearby(body.Position,0)
    lastThreatDistance=distance
    lastThreatName=other and other.DisplayName or nil
    if threatened then
        visibilityHoldUntil=math.max(visibilityHoldUntil,os.clock()+6)
    end
    return threatened,distance,other
end
local function restrictSnaps(reason)
    snapCorrectionCount+=1
    snapCorrectionStreak=math.min(5,snapCorrectionStreak+1)
    local cool=math.min(360,45*2^(snapCorrectionStreak-1))
    snapLockUntil=math.max(snapLockUntil,os.clock()+cool)
    lastFailure=(reason or "Server corrected teleport").." — no repeat snap for "..cool.."s"
    return cool
end


-- SESSION FLIGHT RECORDER: retained ring buffers, zero external uploads.
-- Captures actual replicated game state, not invented server action outcomes.
-- Does not collect usernames, chat, job IDs, account secrets or network tokens.
local SESSION_SCHEMA=1
local SESSION_STARTED=os.clock()
local SESSION_UNIX=os.time()
local SESSION_FILENAME="FERAL_TERRITORY_RUSH_V42_SESSION_"..tostring(SESSION_UNIX)..".json.txt"
local SESSION_EVENT_CAP=360
local SESSION_SAMPLE_CAP=600
local SESSION_HEX_CAP=700
local SESSION_SAMPLE_INTERVAL=2.0
local SESSION_HEX_INTERVAL=3.5
local SESSION_AUTOSAVE_INTERVAL=45.0
local sessionLog={events={},samples={},hexChanges={}}
local sessionHexPrevious={}
local sessionEventCounts={}
local sessionLastSample=0
local sessionLastHexScan=0
local sessionLastAutoSave=0
local sessionPreviousStatus=nil
local sessionStatus="SESSION RECORDING • private local buffer"
local sessionSaved=false
local sessionTotalEvents=0
local sessionTotalSamples=0
local sessionTotalHexChanges=0
local sessionAutoSaved=0
local sessionLastFileError=nil
local sessionFps=nil
local sessionLastSampleHeartbeat=0
local sessionExporting=false
local function roundSession(n,dp)
    if type(n)~="number" or n~=n or math.abs(n)>1e9 then return nil end
    local pow=10^(dp or 1)
    return math.floor(n*pow+0.5)/pow
end
local function sessionAppend(list,row,maxSize)
    table.insert(list,row)
    if #list>maxSize then
        table.remove(list,1)
    end
end
local function sessionSanitize(message)
    return tostring(message or ""):gsub("[%c]"," "):sub(1,180)
end
local function sessionLogEvent(kind,message)
    kind=type(kind)=="string" and kind or "event"
    local safe=sessionSanitize(message)
    sessionTotalEvents+=1
    sessionEventCounts[kind]=(sessionEventCounts[kind] or 0)+1
    sessionAppend(sessionLog.events,{
        elapsed=roundSession(os.clock()-SESSION_STARTED,2),
        type=kind,message=safe,
    },SESSION_EVENT_CAP)
end
local function recordStatus(message)
    local safe=sessionSanitize(message)
    if safe~=sessionPreviousStatus then
        sessionPreviousStatus=safe
        sessionLogEvent("status",safe)
    end
end
local function sessionHexPoll()
    local now=os.clock()
    if now-sessionLastHexScan<SESSION_HEX_INTERVAL then return end
    sessionLastHexScan=now
    for _,hex in ipairs(all) do
        local key=hex.key
        local owner=value(key,"owner")
        local by=value(key,"by")
        local state=value(key,"state")
        local prog=roundSession(value(key,"prog"),3)
        local scent=roundSession(hold(key),3)
        -- Only store pack relationships: never persist ownership strings.
        local row={
            key=key,
            packOwns=owner~=nil and owner==me:GetAttribute("FeralPack"),
            otherOwns=owner~=nil and owner~=me:GetAttribute("FeralPack"),
            claimByPack=by~=nil and by==me:GetAttribute("FeralPack"),
            state=type(state)=="string" and state:sub(1,26) or nil,
            claimProgress=prog,scent=scent,
        }
        local old=sessionHexPrevious[key]
        local changed=not old
            or old.packOwns~=row.packOwns
            or old.otherOwns~=row.otherOwns
            or old.claimByPack~=row.claimByPack
            or old.state~=row.state
            or old.claimProgress~=row.claimProgress
            or old.scent~=row.scent
        if changed then
            sessionHexPrevious[key]=row
            sessionTotalHexChanges+=1
            sessionAppend(sessionLog.hexChanges,{
                elapsed=roundSession(now-SESSION_STARTED,2),
                key=key,packOwns=row.packOwns,
                otherOwns=row.otherOwns,claimByPack=row.claimByPack,
                state=row.state,claimProgress=row.claimProgress,
                scent=row.scent,
            },SESSION_HEX_CAP)
        end
    end
end
local function sessionCapture(dt)
    if not active then return end
    local now=os.clock()
    if type(dt)=="number" and dt>0.001 and dt<0.5 then
        local immediate=1/dt
        sessionFps=if sessionFps then sessionFps*0.90+immediate*0.10
            else immediate
    end
    if now-sessionLastSample<SESSION_SAMPLE_INTERVAL then
        return
    end
    sessionLastSample=now
    local c,r,h=root()
    local a=attempt
    local k=a and a.key or selectedKey
    local otherDist=nil
    local nearbyCount=0
    if r then
        local distance=nearestPlayerAt(r.Position)
        if distance<1e8 then otherDist=roundSession(distance,1) end
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=me then
                local char=other.Character
                local part=char and char:FindFirstChild("HumanoidRootPart")
                if part and part:IsA("BasePart") then
                    local horizontal=Vector2.new(part.Position.X-r.Position.X,
                        part.Position.Z-r.Position.Z).Magnitude
                    if horizontal<avoidRadius() then nearbyCount+=1 end
                end
            end
        end
    end
    local pos=if r then {
        x=roundSession(r.Position.X,1),
        y=roundSession(r.Position.Y,1),
        z=roundSession(r.Position.Z,1),
    } else nil
    local surfaceOffset=nil
    local hoverError=nil
    if undergroundState and r then
        surfaceOffset=roundSession(r.Position.Y-undergroundState.surfacePoint.Y,2)
        hoverError=roundSession((r.Position-undergroundState.position).Magnitude,2)
    end
    local charHunger=c and c:GetAttribute("Hunger")
    local charThirst=c and c:GetAttribute("Thirst")
    local rawFeed=c and c:GetAttribute("FeedCan")
    local state=k and value(k,"state") or nil
    local row={
        elapsed=roundSession(now-SESSION_STARTED,2),
        mode=mode,auto=auto,careEnabled=careEnabled,
        careMode=careMode,careStatus=sessionSanitize(careMessage),
        selectedHex=selectedKey,attemptHex=a and a.key,
        attemptKind=a and a.kind,attemptTravel=a and a.travelType,
        attemptAge=a and roundSession(now-a.began,1),
        attemptRetries=a and a.snapCount,
        attemptFailed=a and a.failed,
        serverOwnerIsPack=k and isOwned(k),
        serverClaimProgress=k and roundSession(value(k,"prog"),3),
        serverScent=k and roundSession(hold(k),3),
        serverClaimState=type(state)=="string" and state:sub(1,26) or nil,
        position=pos,
        speed=r and roundSession(r.AssemblyLinearVelocity.Magnitude,1),
        fps=roundSession(sessionFps,1),
        hpPercent=h and h.MaxHealth>0 and
            roundSession(h.Health/h.MaxHealth*100,1) or nil,
        hunger=roundSession(charHunger,1),
        thirst=roundSession(charThirst,1),
        feedCan=rawFeed=="eat" and "eat" or (rawFeed=="drink" and "drink" or nil),
        nearestPlayerStuds=otherDist,nearbyPlayerCount=nearbyCount,
        avoidRadius=avoidRadius(),avoidEnabled=avoidPlayers,
        undergroundRequested=undergroundRequested,
        undergroundActive=undergroundState~=nil,
        undergroundVerified=undergroundConfirmed,
        hoverDepth=undergroundDepth(),surfaceOffset=surfaceOffset,
        hoverPositionError=hoverError,
        snapCooldown=roundSession(math.max(0,snapLockUntil-now),1),
        totalServerCorrections=snapCorrectionCount,
        careInputUnavailable=inputUnavailable,
    }
    sessionTotalSamples+=1
    sessionAppend(sessionLog.samples,row,SESSION_SAMPLE_CAP)
    sessionHexPoll()
end

local function makeSessionPayload()
    local stats=countTypes()
    return {
        schema="feral-territory-rush-session-v"..tostring(SESSION_SCHEMA),
        version="4.2.0",
        sessionStartUnix=SESSION_UNIX,
        elapsedSeconds=roundSession(os.clock()-SESSION_STARTED,2),
        source="client-observed and replicated FERAL game attributes",
        validation="NOT proof of server invisibility or hover claim success",
        privacy="No other player names, identifiers, chat, credentials or uploads",
        caps={events=SESSION_EVENT_CAP,samples=SESSION_SAMPLE_CAP,
            hexChanges=SESSION_HEX_CAP},
        totals={events=sessionTotalEvents,samples=sessionTotalSamples,
            hexChanges=sessionTotalHexChanges,autoSaved=sessionAutoSaved,
            categories=sessionEventCounts,
            owned=stats.owned,claimable=stats.eligible,
            attemptedSnaps=totalRetries,completed=totalCompleted,
            claims=claimCompletions,scents=reScentCount,
            undergroundAttempts=undergroundAttempts,
            undergroundFailures=undergroundFailures,
            undergroundProgressSignals=undergroundSuccesses,
            serverCorrectionCount=snapCorrectionCount},
        finalState={mode=mode,auto=auto,careEnabled=careEnabled,
            careMode=careMode,careStatus=sessionSanitize(careMessage),
            lastStatus=sessionSanitize(lastStatus),
            lastFailure=sessionSanitize(lastFailure),
            undergroundRequested=undergroundRequested,
            undergroundConfirmed=undergroundConfirmed,
            undergroundRefused=undergroundRefused,
            undergroundStatus=sessionSanitize(undergroundStatus),
            avoidanceRadius=avoidRadius(),travelStyle=travelStyle},
        events=sessionLog.events,
        samples=sessionLog.samples,
        hexChanges=sessionLog.hexChanges,
        note="Send this JSON text file to ChatGPT to investigate FERAL territory behaviour."
    }
end
local function getSessionJSON()
    local ok,json=pcall(function()
        return HttpService:JSONEncode(makeSessionPayload())
    end)
    return ok and json or nil,if ok then nil else tostring(json)
end
local function saveSession(includeClipboard)
    if sessionExporting then return false,"Report export already running" end
    sessionExporting=true
    local json,err=getSessionJSON()
    if not json then
        sessionExporting=false
        sessionLastFileError=tostring(err)
        return false,"JSON export failed: "..tostring(err)
    end
    local saved=false
    if type(writefile)=="function" then
        local ok,reason=pcall(writefile,SESSION_FILENAME,json)
        saved=ok
        if not ok then sessionLastFileError=tostring(reason) end
    else
        sessionLastFileError="Executor writefile unavailable"
    end
    local copied=false
    if includeClipboard and type(setclipboard)=="function" then
        copied=pcall(setclipboard,json)
    end
    sessionExporting=false
    if saved then
        sessionSaved=true
        sessionStatus="SAVED "..SESSION_FILENAME..
            (copied and " • JSON ALSO COPIED" or "")
        return true,sessionStatus
    end
    if copied then
        sessionStatus="JSON COPIED • paste into a text file and upload here"
        return true,sessionStatus
    end
    if includeClipboard then
        -- Console fallback, never automatically prints the full dataset.
        print("[FERAL Territory Rush] JSON REPORT: "..json)
        sessionStatus="REPORT PRINTED TO CONSOLE (save its JSON as text)"
        return true,sessionStatus
    end
    sessionStatus="Local autosave unavailable (use SAVE REPORT button)"
    return false,sessionStatus
end
local function sessionAutosave()
    local now=os.clock()
    if now-sessionLastAutoSave<SESSION_AUTOSAVE_INTERVAL then return end
    sessionLastAutoSave=now
    if type(writefile)=="function" then
        local ok=saveSession(false)
        if ok then sessionAutoSaved+=1 end
    end
end
sessionLogEvent("session","Started v4.2 local-only session recorder")

local function score(t)
    local h=hold(t.key)
    if isOwned(t.key) then
        if h==nil then return -1 end
        if h<0.35 then return 300+(1-h)*100 end
        if h<SCENT_TRIGGER then return 200+(1-h)*100 end
        return -100
    end
    local progress=value(t.key,"prog")
    if value(t.key,"by")==me:GetAttribute("FeralPack")
        and type(progress)=="number" and progress>0 then
        return 420+math.clamp(progress,0,1)*60
    end
    local owner=value(t.key,"owner")
    return if owner==nil then 100 else 80
end
local function rebuild()
    local prior=selectedKey
    local result={}
    for _,t in ipairs(all) do
        if not isNeutral(t.key)
            and (mode=="ALL" or (mode=="SCENT" and isOwned(t.key))
            or (mode=="CLAIM" and not isOwned(t.key))
            or (mode=="PRIORITY" and score(t)>0)) then
            table.insert(result,t)
        end
    end
    if mode=="SCENT" or mode=="PRIORITY" then
        table.sort(result,function(a,b)
            local ha,hb=score(a),score(b)
            if ha==hb then return a.key<b.key end
            return ha>hb
        end)
    elseif mode=="CLAIM" then
        table.sort(result,function(a,b)
            local sa,sb=score(a),score(b)
            if sa~=sb then return sa>sb end
            return a.key<b.key
        end)
    else
        table.sort(result,function(a,b) return a.key<b.key end)
    end
    targets=result
    index=1
    if prior then
        for i,t in ipairs(targets) do
            if t.key==prior then index=i break end
        end
    end
    selectedKey=targets[index] and targets[index].key or nil
end
rebuild()
local function target()
    return targets[index]
end
local function say(s)
    lastStatus=s
    if L.Status then L.Status.Text=s end
    -- "PLAYER AVOID" UI messages may contain another player's DisplayName.
    -- Keep the useful reason but NEVER save their name in our session file.
    if string.find(tostring(s),"PLAYER AVOID",1,true) then
        recordStatus("PLAYER AVOID: an opponent is inside the configured radius")
    else
        recordStatus(s)
    end
end
local function event(s)
    table.insert(sampleLog,1,string.format("%.1f: %s",os.clock(),s))
    if #sampleLog>18 then table.remove(sampleLog) end
    sessionLogEvent("territory",s)
end

gui=Instance.new("ScreenGui")
gui.Name="FERAL_TerritoryRushV4"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=360
gui.Parent=pg
local frame=Instance.new("Frame")
frame.Name="Panel"
frame.Position=UDim2.new(1,-426,0,20)
frame.Size=UDim2.fromOffset(410,656)
frame.BackgroundColor3=Color3.fromRGB(18,26,35)
frame.BorderSizePixel=0
frame.Parent=gui
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,10)
local border=Instance.new("UIStroke",frame)
border.Color=Color3.fromRGB(67,87,108)
border.Thickness=1
local function label(name,y,sz)
    local l=Instance.new("TextLabel")
    l.Name=name
    l.Size=UDim2.fromOffset(384,sz or 21)
    l.Position=UDim2.fromOffset(12,y)
    l.BackgroundTransparency=1
    l.Text=""
    l.TextColor3=Color3.fromRGB(224,235,245)
    l.Font=Enum.Font.Gotham
    l.TextSize=12
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextTruncate=Enum.TextTruncate.AtEnd
    l.Parent=frame
    L[name]=l
    return l
end
label("Title",10,24).Text="FERAL  |  TERRITORY + RECORDER v4.2"
L.Title.Font=Enum.Font.GothamBold
L.Title.TextSize=14
label("Counts",42)
label("Selected",69)
label("Owner",96)
label("Distance",123)
label("Telemetry",150)
label("Evidence",177)
label("Status",207,23).TextColor3=Color3.fromRGB(250,198,120)
local function button(n,s,x,y,w,color)
    local b=Instance.new("TextButton")
    b.Name=n
    b.Text=s
    b.Font=Enum.Font.GothamBold
    b.TextSize=11
    b.TextColor3=Color3.fromRGB(253,253,253)
    b.BackgroundColor3=color
    b.Size=UDim2.fromOffset(w,29)
    b.Position=UDim2.fromOffset(x,y)
    b.Parent=frame
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    return b
end
local modeB=button("Mode","MODE: PRIORITY",12,242,103,Color3.fromRGB(56,81,111))
local prevB=button("Prev","<",121,242,29,Color3.fromRGB(57,79,101))
local nextB=button("Next",">",155,242,29,Color3.fromRGB(57,79,101))
local snapB=button("Snap","SNAP",190,242,60,Color3.fromRGB(42,109,128))
local autoB=button("Auto","AUTO: OFF",256,242,98,Color3.fromRGB(44,104,89))
local closeB=button("Close","X",360,242,38,Color3.fromRGB(119,61,72))
local returnB=button("Return","RETURN",12,274,66,Color3.fromRGB(90,70,108))
local worstB=button("Worst","WORST SCENT",84,274,105,Color3.fromRGB(85,68,110))
local copyB=button("Copy","COPY RESULT",195,274,114,Color3.fromRGB(54,90,95))
local reloadB=button("Rescan","RESCAN",315,274,83,Color3.fromRGB(75,76,90))


local function exitUnderground(rescue,why)
    local state=undergroundState
    if not state then return end
    undergroundState=nil
    if state.align then
        pcall(function()
            state.align.Enabled=false
            state.align:Destroy()
        end)
    end
    if state.attachment then
        pcall(function() state.attachment:Destroy() end)
    end
    local c,r=root()
    if rescue and c==state.character and r and state.surfacePoint then
        local here=r.Position
        local spot=state.surfacePoint
        local dx=here.X-spot.X
        local dz=here.Z-spot.Z
        -- Never fight a server correction that returned the player far away.
        -- One surface rescue when still near this spot, no repeated teleports.
        if dx*dx+dz*dz<6400 and
            here.Y<spot.Y+3 and here.Y>spot.Y-35 then
            pcall(function()
                c:PivotTo(c:GetPivot()+(spot-here))
                r.AssemblyLinearVelocity=Vector3.zero
            end)
        end
    end
    for part,prior in pairs(state.collisions or {}) do
        if part.Parent then
            pcall(function() part.CanCollide=prior end)
        end
    end
    undergroundStatus=why or "Surface restored"
end

local function beginUnderground(a,ground,surfacePoint)
    local c,r,h=root()
    if not c or c~=a.character or not r then
        return false,"The current animal is not available"
    end
    local y=ground.Y-undergroundDepth()
    local destination=Vector3.new(ground.X,y,ground.Z)
    local existing=undergroundState
    if existing and existing.character==c and existing.align and existing.align.Parent then
        -- Reuse the already-held collision-free character and physics
        -- constraint; only one transition to the next underground spot.
        local changed,why=pcall(function()
            existing.position=destination
            existing.surfacePoint=surfacePoint
            existing.started=os.clock()
            existing.align.Position=destination
            c:PivotTo(c:GetPivot()+(destination-r.Position))
            r.AssemblyLinearVelocity=Vector3.zero
            r.AssemblyAngularVelocity=Vector3.zero
        end)
        if changed then
            a.destination=destination
            a.surfacePoint=surfacePoint
            a.travelType="UNDERGROUND"
            a.lastSnap=os.clock()
            a.snapCount+=1
            undergroundAttempts+=1
            undergroundStatus="UNDERGROUND TRANSFER • awaiting new claim evidence"
            return true,nil
        end
        exitUnderground(true,"Subsurface transfer failed: "..tostring(why))
        return false,tostring(why)
    end
    if undergroundState then exitUnderground(true,"Different animal / stale hover") end
    local state={character=c,root=r,surfacePoint=surfacePoint,
        position=destination,collisions={},started=os.clock()}
    local success,err=pcall(function()
        for _,instance in ipairs(c:GetDescendants()) do
            if instance:IsA("BasePart") then
                state.collisions[instance]=instance.CanCollide
                instance.CanCollide=false
            end
        end
        local attachment=Instance.new("Attachment")
        attachment.Name="FeralRushSubsurfaceHold"
        attachment.Parent=r
        state.attachment=attachment
        local align=Instance.new("AlignPosition")
        align.Name="FeralRushSubsurfaceHold"
        align.Mode=Enum.PositionAlignmentMode.OneAttachment
        align.Attachment0=attachment
        align.Position=destination
        align.MaxForce=math.clamp(r.AssemblyMass*WS.Gravity*35,300000,20000000)
        align.MaxVelocity=65
        align.Responsiveness=65
        align.RigidityEnabled=false
        align.ReactionForceEnabled=false
        align.ApplyAtCenterOfMass=true
        align.Parent=r
        state.align=align
        -- Only one initial relocation. The constraint maintains altitude
        -- rather than repeatedly PivotTo-ing against server corrections.
        c:PivotTo(c:GetPivot()+(destination-r.Position))
        r.AssemblyLinearVelocity=Vector3.zero
        r.AssemblyAngularVelocity=Vector3.zero
    end)
    if not success then
        undergroundState=state
        exitUnderground(true,"Underground setup rejected: "..tostring(err):sub(1,80))
        return false,tostring(err)
    end
    undergroundState=state
    a.destination=destination
    a.surfacePoint=surfacePoint
    a.travelType="UNDERGROUND"
    a.lastSnap=os.clock()
    a.snapCount+=1
    undergroundAttempts+=1
    undergroundStatus="UNDERGROUND TRIAL • waiting for real claim progress"
    return true,nil
end

local function failUnderground(a,reason)
    a.failed=true
    undergroundFailures+=1
    undergroundRefused=true
    undergroundConfirmed=false
    undergroundRequested=false
    local seconds=restrictSnaps(reason)
    retryCooldown[a.key]=os.clock()+math.max(105,seconds)
    exitUnderground(true,"DISABLED: "..reason)
    event("SUBSURFACE DISABLED: "..reason)
end

local function release()
    if undergroundState then
        exitUnderground(true,"AUTO off; surface rescue attempted")
        if attempt and attempt.travelType=="UNDERGROUND" then
            attempt=nil
        end
    end
    auto=false
    autoToken+=1
    autoB.Text="AUTO: OFF"
end
local function stop()
    if not active then return end
    sessionLogEvent("session","Controller unloading; final snapshot export")
    sessionLastSample=-math.huge
    pcall(sessionCapture,0.016)
    pcall(saveSession,false)
    active=false
    release()
    if heartbeat then heartbeat:Disconnect() heartbeat=nil end
    if careConnection then careConnection:Disconnect() careConnection=nil end
    if hoverWatchConnection then hoverWatchConnection:Disconnect() hoverWatchConnection=nil end
    careSnapPending=nil
    careEnabled=false
    visibilityHoldUntil=0
    if gui then gui:Destroy() gui=nil end
    movementToken+=1
    attempt=nil
    if env.FERAL_TERRITORY_RUSH_V4
        and env.FERAL_TERRITORY_RUSH_V4.stop==stop then
        env.FERAL_TERRITORY_RUSH_V4=nil
    end
end
closeB.Activated:Connect(stop)

local function choose(i)
    movementToken+=1
    attempt=nil
    if #targets==0 then
        selectedKey=nil
        say("No targets in "..mode.." mode")
        return
    end
    index=((i-1)%#targets)+1
    selectedKey=targets[index].key
    say("Selected "..selectedKey)
end
prevB.Activated:Connect(function()
    release()
    choose(index-1)
end)
nextB.Activated:Connect(function()
    release()
    choose(index+1)
end)
modeB.Activated:Connect(function()
    release()
    if mode=="PRIORITY" then mode="SCENT"
    elseif mode=="SCENT" then mode="CLAIM"
    elseif mode=="CLAIM" then mode="ALL"
    else mode="PRIORITY" end
    movementToken+=1
    attempt=nil
    selectedKey=nil
    rebuild()
    modeB.Text="MODE: "..mode
    say("Mode changed to "..mode)
end)
worstB.Activated:Connect(function()
    release()
    mode="SCENT"
    modeB.Text="MODE: SCENT"
    movementToken+=1
    attempt=nil
    selectedKey=nil
    rebuild()
    say(target() and "Selected lowest-scent owned hex" or "No owned hexes found")
end)
reloadB.Activated:Connect(function()
    release()
    movementToken+=1
    attempt=nil
    rebuild()
    say("Targets updated from replicated territory state")
end)
returnB.Activated:Connect(function()
    local c,r=root()
    if not (c and r and c==returnCharacter and returnCFrame) then
        say("No saved return position for current animal")
        return
    end
    release()
    movementToken+=1
    attempt=nil
    exitUnderground(true,"Return to surface")
    local moved=pcall(function()
        c:PivotTo(c:GetPivot()+(returnCFrame.Position-r.Position))
        r.AssemblyLinearVelocity=Vector3.zero
        r.AssemblyAngularVelocity=Vector3.zero
    end)
    say(moved and "RETURN attempted (not guaranteed server-accepted)" or "Return failed")
end)

local function safePoint(t,c)
    -- Probe the named claim circle; other hex areas may not count.
    -- Remote terrain can be unstreamed when the probe first runs.
    local focus=t.landing or t.center
    local candidate={focus}
    if focus~=t.center then table.insert(candidate,t.center) end
    -- Named claim spots are the game's radius centres. A hex centre may be
    -- outside the named spot's valid claim circle.
    local radii={12,25,40,60,78}
    for _,radius in ipairs(radii) do
        for direction=0,15 do
            local angle=direction*math.pi/8
            table.insert(candidate,focus+Vector2.new(
                math.cos(angle)*radius,math.sin(angle)*radius))
        end
    end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={c}
    params.IgnoreWater=false
    local stats={sampled=0,hits=0,water=0,steep=0}
    local last=landingCache[t.key]
    if typeof(last)=="Vector3"
        and (not territoryNeedsAvoidance() or not otherPlayerNearby(last,0)) then
        local ray=WS:Raycast(Vector3.new(last.X,2300,last.Z),Vector3.new(0,-4500,0),params)
        if ray and ray.Material~=Enum.Material.Water and ray.Normal.Y>=0.35
            and (Vector2.new(last.X,last.Z)-focus).Magnitude<108 then
            return ray.Position,stats
        end
        landingCache[t.key]=nil
    end
    for _,p in ipairs(candidate) do
        if typeof(p)=="Vector2" then
            local i,j=cfg.hexAt(p.X,p.Y)
            local check=type(cfg.hexKey)=="function" and cfg.hexKey(i,j)
                or ("H"..tostring(i).."_"..tostring(j))
            if check==t.key and (p-focus).Magnitude<108
                and (not territoryNeedsAvoidance()
                    or not otherPlayerNearby(Vector3.new(p.X,0,p.Y),0)) then
                stats.sampled+=1
                local ray=WS:Raycast(Vector3.new(p.X,2300,p.Y),
                    Vector3.new(0,-4500,0),params)
                if ray then
                    stats.hits+=1
                    if ray.Material==Enum.Material.Water then
                        stats.water+=1
                    elseif ray.Normal.Y<0.35 then
                        stats.steep+=1
                    else
                        landingCache[t.key]=ray.Position
                        return ray.Position,stats
                    end
                end
            end
        end
    end
    return nil,stats
end

local function streamGround(t,c,r)
    local ground,stats=safePoint(t,c)
    if ground then return ground,"loaded" end
    say("Ground not loaded; requesting map streaming for "..t.key)
    local okRequest,requestErr=pcall(function()
        -- Do not gate on type(WS.RequestStreamAroundAsync): native methods can
        -- be exposed differently by executors. The call itself is protected.
        WS:RequestStreamAroundAsync(Vector3.new(
            t.center.X,math.max(30,r.Position.Y),t.center.Y))
    end)
    if not active then return nil,"Probe closed" end
    -- Allow a delayed chunk response before declaring the hex unreachable.
    for pass=1,8 do
        ground,stats=safePoint(t,c)
        if ground then
            return ground,string.format("streamed after pass %d",pass)
        end
        if pass<8 then task.wait(0.36) end
        if not active then return nil,"Probe closed" end
    end
    local why=stats.hits==0 and "no terrain/parts loaded"
        or stats.water==stats.hits and "only water detected"
        or "no walkable land detected"
    return nil,string.format("%s (%d rays; %d hits; stream request %s)",
        why,stats.sampled,stats.hits,
        okRequest and "accepted" or "failed")
end

local function applyPosition(a)
    local c,r=root()
    if not a or c~=a.character or not r then
        return false,"Animal changed or died"
    end
    local ok,err=pcall(function()
        c:PivotTo(c:GetPivot()+(a.destination-r.Position))
        r.AssemblyLinearVelocity=Vector3.zero
        r.AssemblyAngularVelocity=Vector3.zero
    end)
    if not ok then return false,tostring(err) end
    a.snapCount+=1
    a.lastSnap=os.clock()
    return true,nil
end

local function moveTo(t)
    if not t then return false,"No target selected" end
    movementToken+=1
    local thisMovement=movementToken
    -- Keep an accepted underground hold active while the next terrain chunk
    -- loads. It can be moved directly below the next territory without
    -- needlessly surfacing between successful claims.
    attempt=nil
    local c,r,h=root()
    if not c then return false,"Spawn a living animal first" end
    local pack=me:GetAttribute("FeralPack")
    if pack==nil then return false,"Join a pack before territory maintenance" end
    if c:GetAttribute("FeralDenRoot") or c:GetAttribute("FeralPinned")
        or c:GetAttribute("FeralFlyLocal")
        or (c:GetAttribute("FeralFly") and c:GetAttribute("FeralFly")~="flutter") then
        return false,"Land and exit pinned/den modes before SNAP"
    end
    if territoryNeedsAvoidance()
        and otherPlayerNearby(Vector3.new(t.landing.X,0,t.landing.Y),0) then
        return false,"PLAYER AVOID: other player at the requested claim spot"
    end
    local owner=value(t.key,"owner")
    local oldHold=hold(t.key)
    local oldProgress=value(t.key,"prog")
    if not returnCFrame or returnCharacter~=c then
        returnCFrame=r.CFrame
        returnCharacter=c
    end
    local startingDistance=dist2D(r.Position,t.center)
    lastLandingError=nil
    attemptedLandingHex=t.key
    local ground,groundInfo=streamGround(t,c,r)
    if not active or movementToken~=thisMovement then
        return false,"Movement canceled"
    end
    if not ground then
        lastLandingError="No safe landing: "..t.key.." — "..groundInfo
        event(lastLandingError)
        return false,lastLandingError
    end
    local clearance=math.max(3,h.HipHeight+r.Size.Y*0.5+1.0)
    local point=ground+Vector3.new(0,clearance,0)
    if territoryNeedsAvoidance() and otherPlayerNearby(point,0) then
        return false,"PLAYER AVOID: someone approached while the ground was loading"
    end
    local a={
        key=t.key,pack=pack,originalOwner=owner,originalHold=oldHold,
        originalProgress=type(oldProgress)=="number" and oldProgress or 0,
        lastHold=oldHold,lastProgress=type(oldProgress)=="number" and oldProgress or 0,
        began=os.clock(),startDist=startingDistance,
        evidenceProgress=false,evidenceScent=false,evidenceOwner=false,
        destination=point,character=c,lastSnap=0,snapCount=0,
        snapBacks=0,inTarget=false,lastEvidenceAt=os.clock(),
        origin=r.Position,travelType="PENDING",lastWalkAt=0,
        failed=false,kind=owner==pack and "SCENT" or "CLAIM"
    }
    attempt=a
    if undergroundRequested and not undergroundRefused
        and travelStyle=="ADAPTIVE" then
        local now=os.clock()
        if now<snapLockUntil or now-lastSnapAttemptAt<4.5 then
            attempt=nil
            return false,"SUBSURFACE COOLDOWN: wait for position acceptance"
        end
        lastSnapAttemptAt=now
        local accepted,reason=beginUnderground(a,ground,point)
        if not accepted then
            undergroundRequested=false
            undergroundRefused=true
            restrictSnaps("Subsurface positioning failed")
            a.failed=true
            return false,"SUBSURFACE FAILED: "..tostring(reason)
        end
        event("SUBSURFACE TRIAL "..t.key.." • verifying real server claim state")
        return true,"SUBSURFACE TRIAL "..t.key.." • verification pending"
    end
    if undergroundState then
        exitUnderground(true,"Switching from underground to surface travel")
    end
    local distance=(point-r.Position).Magnitude
    if distance<=safeWalkRadius then
        a.travelType="WALK"
        h:MoveTo(point)
        a.lastWalkAt=os.clock()
        event(string.format("WALK %s (%.0f studs)",t.key,distance))
        return true,"WALK "..t.key.." • waiting for genuine claim progress"
    end
    local now=os.clock()
    if travelStyle=="WALK" then
        attempt=nil
        return false,"WALK ONLY: the next territory needs long-distance travel"
    end
    if now<snapLockUntil then
        attempt=nil
        return false,string.format("SERVER SNAP COOLDOWN %.0fs",snapLockUntil-now)
    end
    if now-lastSnapAttemptAt<4.5 or now<visibilityHoldUntil then
        attempt=nil
        return false,"SNAP WAIT: anti-loop or nearby-player cooldown"
    end
    if currentPlayerThreat() then
        attempt=nil
        return false,"SNAP WAIT: another player can see your current location"
    end
    a.travelType="SNAP"
    lastSnapAttemptAt=now
    local okMove,err=applyPosition(a)
    if not okMove then
        a.failed=true
        return false,"ONE SNAP failed: "..tostring(err)
    end
    event(string.format("ONE SNAP %s from %.0f studs (%s)",
        t.key,startingDistance,groundInfo))
    return true,string.format("ONE SNAP %s • waiting for accepted server state",t.key)
end

-- The game can correct client positions: never resend the same snap.
-- A failed hold or underground probe is disabled with escalating cooldown.
local function keepTarget()
    local a=attempt
    if not (a and a.destination and not a.failed and active) then return end
    local c,r,h=root()
    if c~=a.character or not r then
        a.failed=true
        lastFailure="Animal changed/died during maintenance"
        return
    end
    local now=os.clock()
    local distance=(r.Position-a.destination).Magnitude
    if a.travelType=="UNDERGROUND" then
        if now-a.lastSnap<1.4 then return end
        local offset=r.Position-a.destination
        local flat=Vector2.new(offset.X,offset.Z).Magnitude
        if offset.Y < -15 then
            failUnderground(a,"HOVER ALTITUDE LOST: falling below safe depth")
        elseif flat>65 or offset.Y>8 then
            failUnderground(a,"SERVER CORRECTION: subsurface position rejected")
        elseif now-a.began>12 and not a.evidenceProgress
            and not a.evidenceScent and not a.evidenceOwner then
            failUnderground(a,"NO CLAIM PROGRESS: underground eligibility unverified")
        else
            a.inTarget=flat<15 and math.abs(offset.Y)<5
        end
        return
    end
    if a.travelType=="WALK" then
        if distance<23 then
            a.inTarget=true
            return
        end
        if now-a.began>26 then
            a.failed=true
            lastFailure="WALK path failed to reach safe claim position"
            return
        end
        if now-a.lastWalkAt>3.5 then
            a.lastWalkAt=now
            h:MoveTo(a.destination)
        end
        return
    end
    if a.travelType~="SNAP" or now-a.lastSnap<1.1 then return end
    if distance<50 then
        a.inTarget=true
        return
    end
    -- No snap retries at all. If the server moves the character back,
    -- temporarily ban all long-distance snaps, with escalating cooldown.
    a.failed=true
    a.snapBacks+=1
    totalRetries+=1
    local seconds=restrictSnaps("SERVER REJECTED TELEPORT "..a.key)
    retryCooldown[a.key]=now+math.max(90,seconds)
    event(lastFailure)
end

snapB.Activated:Connect(function()
    if autoBusy then
        say("AUTO running — stop it before manual SNAP")
        return
    end
    release()
    if busySnap then
        say("Already finding a safe landing")
        return
    end
    busySnap=true
    local okMove,msg
    local worked,err=pcall(function()
        okMove,msg=moveTo(target())
    end)
    busySnap=false
    if worked then
        say(msg or "No position result")
    else
        lastFailure=tostring(err)
        say("SNAP error: "..tostring(err))
    end
end)

local function observe()
    if not attempt then return end
    local a=attempt
    local nowHold=hold(a.key)
    local nowProg=value(a.key,"prog")
    local owner=value(a.key,"owner")
    local by=value(a.key,"by")
    local state=value(a.key,"state")
    if owner==a.pack and a.originalOwner~=a.pack and not a.evidenceOwner then
        a.evidenceOwner=true
        if a.travelType=="UNDERGROUND" then
            undergroundConfirmed=true
            undergroundSuccesses+=1
            undergroundStatus="SERVER OWNERSHIP CHANGE while below surface"
        end
        claimedCount+=1
        changedCount+=1
        event(a.key.." claimed by pack after SNAP")
    end
    if owner==a.pack and nowHold~=nil
        and a.lastHold~=nil and nowHold>a.lastHold+0.001 then
        a.lastEvidenceAt=os.clock()
        if not a.evidenceScent then
            a.evidenceScent=true
            if a.travelType=="UNDERGROUND" then
                undergroundConfirmed=true
                undergroundSuccesses+=1
                undergroundStatus="SERVER SCENT INCREASE while below surface"
            end
            reScentCount+=1
            changedCount+=1
            event(a.key.." scent rose after SNAP")
        end
    end
    if by==a.pack and state=="claim" and type(nowProg)=="number"
        and nowProg>a.lastProgress+0.001 then
        a.lastEvidenceAt=os.clock()
        if not a.evidenceProgress then
            a.evidenceProgress=true
            if a.travelType=="UNDERGROUND" then
                undergroundConfirmed=true
                undergroundSuccesses+=1
                undergroundStatus="SERVER CLAIM PROGRESS while below surface"
            end
            changedCount+=1
            event(a.key.." claim progressed after SNAP")
        end
    end
    a.lastHold=nowHold
    if type(nowProg)=="number" then a.lastProgress=nowProg end
    keepTarget()
end

local function report()
    local n=countTypes()
    local t=target()
    local _,r=root()
    local a=attempt
    return {
        version="4.2.0",mode=mode,biome=biome,
        hexCount=n.total,claimable=n.eligible,neutral=n.neutral,
        owned=n.owned,fading=n.fading,other=n.remaining,
        selected=t and t.key,
        selectedHold=t and hold(t.key),
        selectedOwnerIsPack=t and isOwned(t.key),
        selectedDistance=t and r and math.floor(dist2D(r.Position,t.center)),
        attemptedLandingHex=attemptedLandingHex,
        landingError=lastLandingError,
        testKey=a and a.key,testAge=a and math.floor(os.clock()-a.began),
        observedScentRise=a and a.evidenceScent or false,
        observedClaimProgress=a and a.evidenceProgress or false,
        observedOwnerChange=a and a.evidenceOwner or false,
        changesObserved=changedCount,
        claimChanges=claimedCount,scentChanges=reScentCount,
        autoEnabled=auto,totalSnapRetries=totalRetries,
        totalSkipped=totalSkipped,totalCompleted=totalCompleted,
        avoidanceEnabled=avoidPlayers,avoidRadius=avoidRadius(),
        subsurfaceRequested=undergroundRequested,
        subsurfaceVerified=undergroundConfirmed,
        subsurfaceRefused=undergroundRefused,
        subsurfaceAttempts=undergroundAttempts,
        subsurfaceFailures=undergroundFailures,
        subsurfaceProgressSignals=undergroundSuccesses,
        subsurfaceStatus=undergroundStatus,
        travelStyle=travelStyle,nearestOtherDistance=lastThreatDistance,
        snapCorrections=snapCorrectionCount,
        snapLockSeconds=math.max(0,math.ceil(snapLockUntil-os.clock())),
        claimed=claimCompletions,averageClaimSeconds=if claimCompletions>0 then claimDuration/claimCompletions else nil,
        currentSnaps=a and a.snapCount or 0,
        snapFailed=a and a.failed or false,
        lastFailure=lastFailure,lastStatus=lastStatus,
        events=sampleLog
    }
end
copyB.Activated:Connect(function()
    local p=report()
    local v={}
    for _,key in ipairs({
        "version","mode","biome","hexCount","claimable","neutral",
        "owned","fading","other","selected","selectedHold","selectedOwnerIsPack",
        "selectedDistance","testKey","testAge","observedScentRise",
        "observedClaimProgress","observedOwnerChange","changesObserved",
        "claimChanges","scentChanges","autoEnabled","attemptedLandingHex",
        "landingError","totalSnapRetries","totalSkipped","totalCompleted",
        "currentSnaps","snapFailed","lastFailure","lastStatus",
        "subsurfaceRequested","subsurfaceVerified","subsurfaceRefused",
        "subsurfaceAttempts","subsurfaceFailures","subsurfaceProgressSignals",
        "subsurfaceStatus","avoidanceEnabled","avoidRadius","travelStyle"
    }) do
        table.insert(v,key.."="..tostring(p[key]))
    end
    local result="[FERAL TERRITORY RUSH V4.2] "..table.concat(v," | ")
    if type(setclipboard)=="function" then
        local success=pcall(setclipboard,result)
        say(success and "Copied! Paste results into ChatGPT" or "Copy failed; printed in console")
    else
        say("Clipboard unavailable; printed in console")
    end
    print(result)
end)

local function update()
    observe()
    local counts=countTypes()
    local t=target()
    L.Counts.Text=string.format(
        "Server hexes: %d | Eligible: %d | Pack: %d | Fading: %d",
        counts.total,counts.eligible,counts.owned,counts.fading)
    if not t then
        L.Selected.Text="Mode "..mode..": no eligible targets"
        L.Owner.Text="Try MODE: ALL or join a pack"
        L.Distance.Text=""
        L.Telemetry.Text=""
        L.Evidence.Text=""
        return
    end
    local _,r=root()
    local h=hold(t.key)
    local progress=value(t.key,"prog")
    local state=value(t.key,"state")
    local isMine=isOwned(t.key)
    local own=value(t.key,"owner")
    local dist=r and dist2D(r.Position,t.center)
    L.Selected.Text=string.format("%s %d/%d: %s (%s)",
        mode,index,#targets,t.name,t.key)
    L.Owner.Text=string.format("%s | Scent: %s",
        isMine and "YOUR PACK - RE-SCENT ALLOWED"
            or (own and "OTHER PACK - CAPTURE POSSIBLE" or "UNCLAIMED - CAPTURE"),
        h and string.format("%.1f%%",h*100) or "unknown")
    L.Distance.Text="Hex-center distance: "..(dist and string.format("%.0f",dist) or "not spawned")
        .." | Old radius: 120"
    L.Telemetry.Text=string.format("State: %s | Claim: %s | Tries: %s",
        tostring(state or "idle"),
        type(progress)=="number" and string.format("%.1f%%",progress*100)
            or "unknown",
        attempt and tostring(attempt.snapCount) or "-")
    if attempt and attempt.key==t.key then
        if attempt.failed then
            L.Evidence.Text="SNAP FAILED: "..tostring(lastFailure)
            L.Evidence.TextColor3=Color3.fromRGB(251,149,132)
        elseif attempt.evidenceScent then
            L.Evidence.Text="REPLICATED SCENT INCREASE OBSERVED"
            L.Evidence.TextColor3=Color3.fromRGB(133,243,177)
        elseif attempt.evidenceOwner then
            L.Evidence.Text="OWNERSHIP CHANGED TO YOUR PACK"
            L.Evidence.TextColor3=Color3.fromRGB(133,243,177)
        elseif attempt.evidenceProgress then
            L.Evidence.Text="REPLICATED CLAIM PROGRESS OBSERVED"
            L.Evidence.TextColor3=Color3.fromRGB(133,243,177)
        else
            L.Evidence.Text="At target? Watch replicated scent/claim changes"
            L.Evidence.TextColor3=Color3.fromRGB(247,195,119)
        end
    else
        L.Evidence.Text=lastLandingError and attemptedLandingHex==t.key
            and lastLandingError
            or (isMine and "Owned hexes are valid RE-SCENT targets"
            or "SNAP tests server-recognised position")
        L.Evidence.TextColor3=Color3.fromRGB(213,222,239)
    end
end
heartbeat=RunService.Heartbeat:Connect(function(dt)
    if not active then return end
    local ok,err=pcall(sessionCapture,dt)
    if not ok then
        sessionLastFileError="Sampler error: "..sessionSanitize(err)
    end
    sessionAutosave()
    if os.clock()<nextUpdate then return end
    nextUpdate=os.clock()+0.22
    local success,updateErr=pcall(update)
    if not success then say("Monitor error: "..tostring(updateErr)) end
end)

-- Choose the highest-priority actionable hex, excluding recently failed ones.
-- SCENT mode watches for scent under 85%; PRIORITY does scent then claims.
local function bestAutoTarget()
    local now=os.clock()
    local best=nil
    local bestScore=-math.huge
    local _,ownRoot=root()
    local longTravelAllowed=travelStyle=="ADAPTIVE"
        and now>=snapLockUntil
    for _,t in ipairs(all) do
        local spot=t.landing
        local nearby=territoryNeedsAvoidance()
            and otherPlayerNearby(Vector3.new(spot.X,0,spot.Y),0)
        local closeEnough=ownRoot and dist2D(ownRoot.Position,spot)<safeWalkRadius-10
        if not isNeutral(t.key) and (retryCooldown[t.key] or 0)<=now
            and not nearby and (longTravelAllowed or closeEnough) then
            local p=score(t)
            local valid=(mode=="PRIORITY" and p>0)
                or (mode=="SCENT" and isOwned(t.key)
                    and type(hold(t.key))=="number"
                    and hold(t.key)<SCENT_TRIGGER)
                or (mode=="CLAIM" and not isOwned(t.key))
            if valid and p>bestScore then
                best=t
                bestScore=p
            end
        end
    end
    return best
end

local function toggleTerritoryAuto()
    if careMode then
        careResumeAuto=true
        say("AUTO queued until "..careMode.." care is finished")
        return
    end
    if auto then
        release()
        say("AUTO stopped by user")
        return
    end
    if mode=="ALL" then
        say("Switch to PRIORITY, SCENT or CLAIM before AUTO")
        return
    end
    if not me:GetAttribute("FeralPack") then
        say("Join a pack before running AUTO")
        return
    end
    if busySnap or autoBusy then
        say("Another territory attempt is still running")
        return
    end
    auto=true
    autoToken+=1
    local token=autoToken
    autoB.Text="AUTO: ON"
    say("AUTO: restores endangered scent, then captures")
    task.spawn(function()
        autoBusy=true
        local myPack=me:GetAttribute("FeralPack")
        while active and auto and token==autoToken do
            if me:GetAttribute("FeralPack")~=myPack then
                release()
                say("Pack changed — AUTO stopped")
                break
            end
            local c=root()
            if not c then
                release()
                say("Animal died or despawned — AUTO stopped")
                break
            end
            local threatened,nearDist,nearby=false,math.huge,nil
            if territoryNeedsAvoidance() then
                threatened,nearDist,nearby=currentPlayerThreat()
            end
            if threatened or (territoryNeedsAvoidance()
                and os.clock()<visibilityHoldUntil) then
                local who=nearby and nearby.DisplayName or (lastThreatName or "player")
                local range=nearDist<math.huge and string.format("%.0f",nearDist) or "?"
                say("PLAYER AVOID: "..who.." "..range.." studs • holding position")
                task.wait(1)
            else
            local t=bestAutoTarget()
            if not t then
                say("SAFE WATCH: no unoccupied nearby hex / snap cooling down")
                task.wait(1.3)
            else
                selectedKey=t.key
                rebuild()
                for i,p in ipairs(targets) do
                    if p.key==t.key then index=i break end
                end
                local okMove,msg
                local callOK,callErr=pcall(function()
                    okMove,msg=moveTo(t)
                end)
                say(callOK and msg or ("SNAP error: "..tostring(callErr)))
                if not callOK or not okMove then
                    retryCooldown[t.key]=os.clock()+35
                    totalSkipped+=1
                    lastFailure=callOK and msg or tostring(callErr)
                    event("Skipped "..t.key..": "..tostring(lastFailure))
                    task.wait(1)
                else
                    local a=attempt
                    local deadline=os.clock()+(a.kind=="SCENT" and 105 or 90)
                    local completed=false
                    local reason=nil
                    while active and auto and token==autoToken
                        and os.clock()<deadline do
                        task.wait(0.18)
                        if not active or not auto or token~=autoToken then break end
                        if a.failed then
                            reason=lastFailure or "Movement correction"
                            break
                        end
                        local _,ownPart=root()
                        if ownPart and territoryNeedsAvoidance()
                            and otherPlayerNearby(ownPart.Position,0) then
                            visibilityHoldUntil=os.clock()+7
                            reason="Other player entered your avoidance radius"
                            break
                        end
                        if me:GetAttribute("FeralPack")~=myPack then
                            reason="Pack changed"
                            break
                        end
                        if a.kind=="SCENT" then
                            if value(a.key,"owner")~=myPack then
                                reason="Owned territory was lost"
                                break
                            end
                            local currentHold=hold(a.key)
                            if currentHold and currentHold>=SCENT_SUCCESS then
                                completed=true
                                break
                            end
                            if os.clock()-a.lastEvidenceAt>40 then
                                reason="No server-replicated scent increase"
                                break
                            end
                        else
                            if value(a.key,"owner")==myPack then
                                completed=true
                                break
                            end
                            if os.clock()-a.lastEvidenceAt>28 then
                                reason="No server-replicated claim progress"
                                break
                            end
                        end
                    end
                    if not active or not auto or token~=autoToken then break end
                    if completed then
                        totalCompleted+=1
                        if a.kind=="CLAIM" then
                            claimCompletions+=1
                            claimDuration+=os.clock()-a.began
                        end
                        retryCooldown[t.key]=os.clock()+8
                        if a.travelType=="SNAP" then
                            -- A replicated ownership/scent success confirms a
                            -- meaningful territory action, not an immunity to
                            -- later server position corrections.
                            snapCorrectionStreak=0
                        end
                        event(a.key.." completed: "..a.kind)
                        say(a.key.." complete — selecting next")
                    else
                        retryCooldown[t.key]=os.clock()+
                            (a.failed and 125 or 45)
                        totalSkipped+=1
                        lastFailure=reason or ("Timed out: "..t.key)
                        event("Skipped "..t.key..": "..tostring(lastFailure))
                        say("Skipped "..t.key..": "..tostring(lastFailure))
                    end
                    task.wait(0.25)
                end
            end
            end -- player visibility gate
        end
        autoBusy=false
    end)
end
autoB.Activated:Connect(toggleTerritoryAuto)


-- Integrated survival lane. Gameplay events still use the game's own
-- controls: native E to feed/drink, real NPC pursuit/attack where eligible.
-- No client-side Hunger/Thirst/Health attribute edits or fake rewards.
-- No genuine global invisibility is available from the captured client code:
-- other players can still see server-replicated movement or teleportation.
local careButton=button("Care","AUTO CARE: OFF",12,307,127,Color3.fromRGB(43,105,101))
local huntButton=button("Hunt","HUNT: ON",145,307,104,Color3.fromRGB(64,92,116))
local thresholdButton=button("Threshold","LIMITS: 35/35",255,307,143,Color3.fromRGB(72,78,108))
L.Care=label("Care",347,23)
L.Care.Text="CARE OFF • native E feeding only when FeedCan permits"
L.Care.TextColor3=Color3.fromRGB(164,220,197)
L.Stealth=label("Stealth",373,22)
L.Stealth.Text="NO SERVER INVISIBILITY • safe landing + anti-snap-back"
L.Stealth.TextColor3=Color3.fromRGB(167,187,206)
local UIS=game:GetService("UserInputService")
local virtualInput=nil
pcall(function()virtualInput=game:GetService("VirtualInputManager")end)
inputUnavailable=false
local function sendKeyE()
    if UIS:GetFocusedTextBox() or me:GetAttribute("FeralMenuOpen")==true then
        return false
    end
    if virtualInput then
        local ok=pcall(function()
            virtualInput:SendKeyEvent(true,Enum.KeyCode.E,false,game)
            task.wait(.07)
            virtualInput:SendKeyEvent(false,Enum.KeyCode.E,false,game)
        end)
        if ok then
            sessionLogEvent("feed_input","Native E key attempted")
            return true
        end
    end
    if type(keypress)=="function" and type(keyrelease)=="function" then
        local ok=pcall(function()
            keypress(0x45)
            task.wait(.07)
            keyrelease(0x45)
        end)
        if ok then
            sessionLogEvent("feed_input","Native E fallback key attempted")
            return true
        end
    end
    inputUnavailable=true
    sessionLogEvent("feed_input","Native E input unavailable")
    return false
end
local function sendNativeBite()
    if UIS:GetFocusedTextBox() or me:GetAttribute("FeralMenuOpen")==true then
        return false
    end
    if virtualInput then
        local pos=UIS:GetMouseLocation()
        local x,y=pos.X,pos.Y
        local ok=pcall(function()
            virtualInput:SendMouseButtonEvent(x,y,0,true,game,0)
            task.wait(.06)
            virtualInput:SendMouseButtonEvent(x,y,0,false,game,0)
        end)
        if ok then
            sessionLogEvent("hunt_input","Native attack click attempted")
            return true
        end
    end
    if type(mouse1click)=="function" then
        local clicked=pcall(mouse1click)
        sessionLogEvent("hunt_input",
            if clicked then "Fallback attack click attempted" else "Attack fallback failed")
        return clicked
    end
    inputUnavailable=true
    sessionLogEvent("hunt_input","Native attack input unavailable")
    return false
end
local function packFriend(model)
    local owner=Players:GetPlayerFromCharacter(model)
    local pack=owner and owner:GetAttribute("FeralPack") or model:GetAttribute("FeralPack")
    local mine=me:GetAttribute("FeralPack")
    return pack~=nil and mine~=nil and pack==mine
end
local function bestNPCFood(position)
    local folder=WS:FindFirstChild("FeralNPCs")
    if not folder then return nil end
    local best,dist=nil,math.huge
    local checked=0
    for _,model in ipairs(folder:GetChildren()) do
        checked+=1
        if checked>80 then break end
        if model:IsA("Model") and not packFriend(model)
            and model:GetAttribute("FeralDead")~=true then
            local npcRoot=model:FindFirstChild("HumanoidRootPart")
            local npcHum=model:FindFirstChildOfClass("Humanoid")
            if npcRoot and npcHum and npcHum.Health>0
                and not otherPlayerNearby(npcRoot.Position,0) then
                local d=(npcRoot.Position-position).Magnitude
                if d<230 and d<dist then
                    dist=d
                    best={root=npcRoot,model=model,distance=d}
                end
            end
        end
    end
    return best
end
local function waterLandmark(position)
    local mapSpots=spotsData and (spotsData[WS:GetAttribute("FeralBiome") or biome]
        or spotsData.WolfValley)
    local best=nil
    local bestDistance=math.huge
    if type(mapSpots)=="table" then
        for _,spot in ipairs(mapSpots) do
            local name=string.lower(tostring(spot.name or spot.key or ""))
            if typeof(spot.pos)=="Vector2"
                and not otherPlayerNearby(Vector3.new(
                    spot.pos.X,position.Y,spot.pos.Y),0)
                and (name:find("water",1,true) or name:find("lake",1,true)
                    or name:find("pond",1,true) or name:find("falls",1,true)
                    or name:find("spring",1,true) or name:find("river",1,true)) then
                local d=(Vector2.new(position.X,position.Z)-spot.pos).Magnitude
                if d<bestDistance then
                    bestDistance=d
                    best={name=spot.name or spot.key or "Water",
                        center=spot.pos,distance=d}
                end
            end
        end
    end
    return best
end
local function safeWaterEdge(target,char)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={char}
    params.IgnoreWater=false
    local chosen=nil
    local bestScore=math.huge
    local radii={10,20,30,40}
    for _,r in ipairs(radii) do
        for i=0,11 do
            local angle=i*math.pi/6
            local x=target.center.X+math.cos(angle)*r
            local z=target.center.Y+math.sin(angle)*r
            local ray=WS:Raycast(Vector3.new(x,2300,z),
                Vector3.new(0,-4500,0),params)
            if ray and ray.Material~=Enum.Material.Water and ray.Normal.Y>0.40
                and not otherPlayerNearby(ray.Position,0) then
                local near=WS:Raycast(Vector3.new(x+6,2300,z),
                    Vector3.new(0,-4500,0),params)
                local score=r
                if near and near.Material==Enum.Material.Water then score-=15 end
                if score<bestScore then
                    bestScore=score
                    chosen=ray.Position
                end
            end
        end
    end
    return chosen
end

local function safeCareSnap(groundGoal,char,rootPart,hum,purpose)
    local now=os.clock()
    if now<snapLockUntil or now-lastSnapAttemptAt<5
        or now-careLastSnapAt<55 then
        return false,"Global correction / survival snap cooldown"
    end
    if otherPlayerNearby(groundGoal,0) then
        return false,"Other player in the destination avoidance radius"
    end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={char}
    params.IgnoreWater=false
    local ray=WS:Raycast(Vector3.new(groundGoal.X,groundGoal.Y+150,groundGoal.Z),
        Vector3.new(0,-450,0),params)
    if not ray or ray.Material==Enum.Material.Water or ray.Normal.Y<0.35
        or otherPlayerNearby(ray.Position,0) then
        return false,"Ground not safe at secluded destination"
    end
    local surface=ray.Position
        +Vector3.new(0,math.max(3,hum.HipHeight+rootPart.Size.Y/2+1),0)
    lastSnapAttemptAt=now
    careLastSnapAt=now
    if undergroundState then
        exitUnderground(true,"Surface exit for "..purpose)
    end
    local ok,err=pcall(function()
        char:PivotTo(char:GetPivot()+(surface-rootPart.Position))
        rootPart.AssemblyLinearVelocity=Vector3.zero
        rootPart.AssemblyAngularVelocity=Vector3.zero
    end)
    if not ok then
        restrictSnaps("Care movement could not be applied")
        return false,tostring(err)
    end
    careSnapPending={character=char,where=surface,began=os.clock(),
        purpose=purpose}
    sessionLogEvent("survival_move",purpose..": single ground-safe move attempted")
    return true,"Single secluded "..purpose.." travel attempted"
end

local function watchCareSnap()
    local pending=careSnapPending
    if not pending then return end
    if os.clock()-pending.began<1.7 then return end
    careSnapPending=nil
    local c,r=root()
    if c~=pending.character or not r then return end
    local dx=r.Position.X-pending.where.X
    local dz=r.Position.Z-pending.where.Z
    local horizontal=math.sqrt(dx*dx+dz*dz)
    if horizontal>65 then
        restrictSnaps("CARE POSITION CORRECTED: "..pending.purpose)
        sessionLogEvent("server_correction","Care move corrected: "..pending.purpose)
        careMessage="SERVER REJECTED "..pending.purpose.." MOVE • no looping"
    end
end

local function careStats()
    local char,r,hum=root()
    if not char then return nil end
    local hunger=char:GetAttribute("Hunger")
    local thirst=char:GetAttribute("Thirst")
    return char,r,hum,
        type(hunger)=="number" and hunger or nil,
        type(thirst)=="number" and thirst or nil,
        hum.MaxHealth>0 and hum.Health/hum.MaxHealth or 0
end
local function stopCareMode(message,resume)
    careMode=nil
    careLastNeedValue=nil
    carePendingAttempts=0
    careMessage=message or "CARE WAITING"
    careSnapPending=nil
    local shouldResume=resume and careResumeAuto and not auto and active
        and me:GetAttribute("FeralPack")~=nil
    careResumeAuto=false
    if shouldResume then
        if not autoBusy then
            toggleTerritoryAuto()
        else
            task.defer(function()
                for _=1,20 do
                    if not active or not careEnabled then return end
                    if not autoBusy and not careMode then
                        toggleTerritoryAuto()
                        return
                    end
                    task.wait(0.2)
                end
            end)
        end
    end
end
local function nextCareMode(hunger,thirst,hp)
    local lim=careProfiles[careProfileIndex]
    -- Emergency thirst/food comes before optional HP rest. Ordinary low HP
    -- pauses risky NPC hunting until recovery improves.
    if thirst and thirst<20 then return "DRINK" end
    if hunger and hunger<20 and hp>=0.20 then return "EAT" end
    if hp<lim.hp then return "RECOVER" end
    if thirst and thirst<lim.thirst then return "DRINK" end
    if hunger and hunger<lim.hunger then return "EAT" end
    return nil
end
local function tryCareAction(mode,char,rootPart,hum,hunger,thirst,hp)
    local now=os.clock()
    if now<careNextAction then return end
    careNextAction=now+1.5
    if careSnapPending then
        careMessage="WAITING FOR SERVER POSITION CHECK • "..careSnapPending.purpose
        return
    end
    local can=char:GetAttribute("FeedCan")
    local need=if mode=="DRINK" then thirst else hunger
    if mode=="RECOVER" then
        careMessage="LOW HP • TERRITORY PAUSED FOR RECOVERY"
        return
    end
    if can==string.lower(mode) or
        (mode=="EAT" and can=="eat") or
        (mode=="DRINK" and can=="drink") then
        local ok=sendKeyE()
        if ok then
            careMessage=mode.." • NATIVE E REQUESTED / VERIFYING NEEDS"
            carePendingAttempts+=1
        else
            careMessage=mode.." • INPUT UNAVAILABLE / NEEDS MANUAL E"
        end
        return
    end
    if mode=="EAT" then
        if not careHuntEnabled then
            careMessage="HUNT DISABLED • FIND FOOD MANUALLY"
            return
        end
        local npc=bestNPCFood(rootPart.Position)
        if not npc then
            careMessage="NO REPLICATED NPC PREY NEARBY"
            return
        end
        local target=npc.root
        if npc.distance>95 then
            local approach=target.Position-target.CFrame.LookVector*16
            local ok,reason=safeCareSnap(approach,char,rootPart,hum,"HUNT")
            careMessage=if ok then "HUNT • "..reason
                else "HUNT SAFE MOVE: "..tostring(reason)
        elseif npc.distance>8 then
            hum:MoveTo(target.Position)
            careMessage=string.format("HUNT • APPROACHING NPC %.0f STUDS",npc.distance)
        else
            local face=Vector3.new(target.Position.X,rootPart.Position.Y,target.Position.Z)
            if (face-rootPart.Position).Magnitude>1 then
                pcall(function()
                    char:PivotTo(CFrame.lookAt(rootPart.Position,face))
                end)
            end
            careMessage=if sendNativeBite() then "HUNT • NATIVE ATTACK INPUT"
                else "HUNT • ATTACK INPUT UNAVAILABLE"
            carePendingAttempts+=1
        end
    else
        local water=waterLandmark(rootPart.Position)
        if not water then
            careMessage="NO VALID WATER LANDMARK FOR THIS BIOME"
            return
        end
        local horizontal=(Vector2.new(rootPart.Position.X,rootPart.Position.Z)-water.center).Magnitude
        if horizontal<110 then
            careMessage="WATER NEARBY • APPROACH WATER EDGE / NATIVE E"
            local edge=safeWaterEdge(water,char)
            if edge then hum:MoveTo(edge+Vector3.new(0,2,0)) end
        elseif now-careLastSnapAt>55 then
            local destination=safeWaterEdge(water,char)
            if destination then
                local ok,reason=safeCareSnap(destination,char,rootPart,hum,"DRINK")
                careMessage=if ok then "WATER • "..reason
                    else "WATER SAFE MOVE: "..tostring(reason)
            else
                careMessage="WATER TERRAIN NOT LOADED / MOVEMENT PAUSED"
                task.spawn(function()
                    pcall(function()
                        WS:RequestStreamAroundAsync(Vector3.new(water.center.X,rootPart.Position.Y,water.center.Y))
                    end)
                end)
            end
        else
            careMessage="WATER • WAITING FOR SAFE ROUTE / SNAP COOLDOWN"
        end
    end
end
local lastCareTick=0
local function careTick()
    if not active or not careEnabled then return end
    local now=os.clock()
    if now-lastCareTick<0.7 then return end
    lastCareTick=now
    watchCareSnap()
    local char,rootPart,hum,hunger,thirst,hp=careStats()
    if not char then
        careMessage="SPAWN ANIMAL TO ENABLE CARE"
        return
    end
    local nextMode=nextCareMode(hunger,thirst,hp)
    if not careMode then
        if not nextMode or now<careCooldownUntil then
            careMessage=if not nextMode then "NEEDS ABOVE THRESHOLDS"
                else "CARE COOLDOWN / NO REPETITIVE INPUT"
            return
        end
        careMode=nextMode
        sessionLogEvent("care","Care started: "..nextMode)
        careStartedAt=now
        carePendingAttempts=0
        careLastNeedValue=if nextMode=="DRINK" then thirst
            else if nextMode=="EAT" then hunger else hp
        if undergroundState then
            exitUnderground(true,"Surfacing for survival care")
            if attempt then attempt.failed=true end
            movementToken+=1
            attempt=nil
        end
        if auto then
            careResumeAuto=true
            release()
            movementToken+=1
            attempt=nil
        end
        careMessage="CARE: "..nextMode.." • TERRITORY INTERRUPTED"
    end
    local critical=nextCareMode(hunger,thirst,hp)
    if critical=="DRINK" and careMode~="DRINK" and thirst and thirst<20 then
        careMode="DRINK"
        careStartedAt=now
        carePendingAttempts=0
        careLastNeedValue=thirst
    end
    local targetNeed=if careMode=="DRINK" then thirst
        else if careMode=="EAT" then hunger else hp
    local lim=careProfiles[careProfileIndex]
    local recovered=if careMode=="DRINK" then
        thirst and thirst>=lim.thirst+15
        else if careMode=="EAT" then hunger and hunger>=lim.hunger+15
        else hp>=math.min(0.95,lim.hp+0.20)
    if recovered then
        sessionLogEvent("care","Care goal verified: "..tostring(careMode))
        stopCareMode("CARE COMPLETE • RESUMING TERRITORIES",true)
        return
    end
    if targetNeed and careLastNeedValue and targetNeed>careLastNeedValue+0.5 then
        careLastNeedValue=targetNeed
        careStartedAt=now
        carePendingAttempts=0
    end
    if now-careStartedAt>45 then
        sessionLogEvent("care","Care timeout without accepted resource increase: "..tostring(careMode))
        careCooldownUntil=now+25
        stopCareMode("CARE UNCONFIRMED • PAUSED 25 SEC",true)
        return
    end
    if carePendingAttempts>=12 then
        sessionLogEvent("care","Care capped after 12 unconfirmed inputs")
        careCooldownUntil=now+25
        stopCareMode("INPUTS UNCONFIRMED • STOPPED RETRIES",true)
        return
    end
    if careBusy then return end
    careBusy=true
    task.spawn(function()
        local ok,err=pcall(tryCareAction,careMode,char,rootPart,hum,hunger,thirst,hp)
        if not ok then careMessage="CARE ERROR: "..tostring(err):sub(1,80) end
        careBusy=false
    end)
end
local careProfilesNames={"NORMAL","EARLY","CRITICAL"}
careButton.Activated:Connect(function()
    careEnabled=not careEnabled
    careButton.Text=if careEnabled then "AUTO CARE: ON" else "AUTO CARE: OFF"
    if not careEnabled then
        stopCareMode("AUTO CARE DISABLED",true)
    else
        careMessage="WATCHING HUNGER, THIRST AND HP"
    end
end)
huntButton.Activated:Connect(function()
    careHuntEnabled=not careHuntEnabled
    huntButton.Text=if careHuntEnabled then "HUNT: ON" else "HUNT: OFF"
end)
thresholdButton.Activated:Connect(function()
    careProfileIndex=careProfileIndex%#careProfiles+1
    local limits=careProfiles[careProfileIndex]
    thresholdButton.Text=string.format("%s: %d/%d",careProfilesNames[careProfileIndex],
        limits.hunger,limits.thirst)
end)

-- Player-avoidance controls are intentionally separate from auto survival.
-- These are choices about *where and when to move*, not server invisibility.
local avoidButton=button("Avoid","AVOID PLAYERS: ON",12,402,143,Color3.fromRGB(44,105,99))
local radiusButton=button("Radius","RADIUS: 300",162,402,111,Color3.fromRGB(56,81,111))
local travelButton=button("Travel","SNAP: ADAPTIVE",280,402,118,Color3.fromRGB(83,70,101))
L.Avoidance=label("Avoidance",470,22)
L.Avoidance.Text="All other players • 300 studs • streaming-limited"
L.Avoidance.TextColor3=Color3.fromRGB(173,223,201)
L.Travel=label("Travel",493,24)
L.Travel.Text="ONE SNAP MAX • cooldown on rejected position"
L.Travel.TextColor3=Color3.fromRGB(201,207,226)
avoidButton.Activated:Connect(function()
    avoidPlayers=not avoidPlayers
    avoidButton.Text=if avoidPlayers then "AVOID PLAYERS: ON" else "AVOID PLAYERS: OFF"
    if not avoidPlayers then visibilityHoldUntil=0 end
    say(if avoidPlayers then "Player avoidance enabled"
        else "WARNING: player avoidance disabled")
end)
radiusButton.Activated:Connect(function()
    avoidRadiusIndex=avoidRadiusIndex%#avoidRadii+1
    radiusButton.Text="RADIUS: "..tostring(avoidRadius())
    say("Avoidance now "..avoidRadius().." studs from replicated players")
end)
travelButton.Activated:Connect(function()
    travelStyle=if travelStyle=="ADAPTIVE" then "WALK" else "ADAPTIVE"
    travelButton.Text=if travelStyle=="ADAPTIVE" then "SNAP: ADAPTIVE" else "WALK ONLY"
    if travelStyle=="WALK" then
        snapLockUntil=math.max(snapLockUntil,os.clock()+5)
        if undergroundState then
            exitUnderground(true,"WALK ONLY: returning to normal grounded movement")
            if attempt and attempt.travelType=="UNDERGROUND" then
                attempt.failed=true
                lastFailure="WALK ONLY cancelled underground relocation"
            end
        end
        undergroundStatus="PAUSED • WALK ONLY selected"
    end
    say(if travelStyle=="WALK" then "WALK ONLY: no automatic long teleports"
        else "ADAPTIVE: single teleport only when safe")
end)

-- Explicit experimental opt-in. We never label local collision hiding as
-- server invisibility; this mode remains subject to server claim eligibility.
local hoverButton=button("Subsurface","SUBSURFACE: OFF",12,436,177,
    Color3.fromRGB(75,73,112))
local hoverDepthButton=button("Depth","DEPTH: 8",195,436,203,
    Color3.fromRGB(54,80,98))
L.Hover=label("SubsurfaceStatus",518,24)
L.Hover.Text="SUBSURFACE OFF • not verified invisible/server-eligible"
L.Hover.TextColor3=Color3.fromRGB(230,189,143)
-- Session file export is local only. The game does not upload anything to
-- ChatGPT. Users can send the file after playing for source-grounded refinement.
local saveReportButton=button("SaveReport","SAVE REPORT",12,548,159,
    Color3.fromRGB(39,104,107))
local copyReportButton=button("CopyReport","COPY JSON",181,548,217,
    Color3.fromRGB(66,78,111))
L.Session=label("SessionReport",587,22)
L.Session.Text="RECORDER ON • autosave every 45s when file writing works"
L.Session.TextColor3=Color3.fromRGB(145,225,202)
L.SessionHelp=label("SessionHelp",615,25)
L.SessionHelp.Text="No automatic uploads • send saved JSON text file here afterward"
L.SessionHelp.TextColor3=Color3.fromRGB(181,194,209)
saveReportButton.Activated:Connect(function()
    sessionLogEvent("user_action","SAVE REPORT clicked")
    local ok,message=saveSession(true)
    say(if ok then "SESSION EXPORTED • check your executor workspace / clipboard"
        else "REPORT EXPORT FAILED: "..tostring(message))
    L.Session.Text=sessionSanitize(message)
end)
copyReportButton.Activated:Connect(function()
    sessionLogEvent("user_action","COPY JSON clicked")
    local json,reason=getSessionJSON()
    if not json then
        L.Session.Text="JSON ERROR: "..sessionSanitize(reason)
        return
    end
    if type(setclipboard)=="function" then
        local copied=pcall(setclipboard,json)
        L.Session.Text=if copied then
            "FULL JSON COPIED • paste into a text file to upload"
            else "Clipboard rejected JSON • use SAVE REPORT"
    else
        print("[FERAL Territory Rush] JSON REPORT: "..json)
        L.Session.Text="NO CLIPBOARD • full JSON printed in executor console"
    end
end)
hoverButton.Activated:Connect(function()
    if undergroundRequested then
        undergroundRequested=false
        if undergroundState then
            exitUnderground(true,"SUBSURFACE OFF • surface rescue attempted")
            if attempt and attempt.travelType=="UNDERGROUND" then
                attempt.failed=true
                lastFailure="Underground trial disabled by user"
            end
        end
    else
        undergroundRequested=true
        -- The automatic refusal following a failed probe may be reset only
        -- by an explicit user click; global snap cooldown still applies.
        undergroundRefused=false
        undergroundConfirmed=nil
        undergroundStatus="ON • attempting bounded hold; claim unverified"
    end
    hoverButton.Text=if undergroundRequested then "SUBSURFACE: TRIAL"
        else "SUBSURFACE: OFF"
    say(if undergroundRequested then
        "UNDERGROUND TRIAL: may be server rejected or still visible to players"
        else "SUBSURFACE disabled; above-ground territory rules restored")
end)
hoverDepthButton.Activated:Connect(function()
    if undergroundState then
        say("Exit subsurface mode before changing hover depth")
        return
    end
    undergroundDepthIndex=undergroundDepthIndex%#undergroundDepths+1
    hoverDepthButton.Text="DEPTH: "..tostring(undergroundDepth())
end)
local hoverWatchLast=0
hoverWatchConnection=RunService.Heartbeat:Connect(function()
    local state=undergroundState
    if not state or not active or os.clock()-hoverWatchLast<0.15 then return end
    hoverWatchLast=os.clock()
    local c,r=root()
    if not c or c~=state.character or not r then
        undergroundRequested=false
        undergroundRefused=true
        exitUnderground(false,"HOVER ABORTED: animal changed")
        return
    end
    local delta=r.Position-state.position
    local horizontal=Vector2.new(delta.X,delta.Z).Magnitude
    if os.clock()-state.started>0.9
        and (horizontal>75 or delta.Y>10) then
        if attempt and attempt.travelType=="UNDERGROUND" then
            failUnderground(attempt,"SERVER REJECTED: position corrected; stopping hover")
        else
            undergroundRequested=false
            undergroundRefused=true
            restrictSnaps("Subsurface location corrected")
            exitUnderground(false,"SUBSURFACE REJECTED • no repeated pull")
        end
    elseif r.Position.Y<state.position.Y-14 then
        if attempt and attempt.travelType=="UNDERGROUND" then
            failUnderground(attempt,"EMERGENCY: losing underground hover altitude")
        else
            undergroundRequested=false
            undergroundRefused=true
            exitUnderground(true,"EMERGENCY SURFACE RESCUE")
        end
    end
end)
local lastCareUiUpdate=-math.huge
careConnection=RunService.Heartbeat:Connect(function()
    local ok,err=pcall(careTick)
    if not ok then careMessage="CARE LOOP ERROR: "..tostring(err):sub(1,75) end
    if os.clock()-lastCareUiUpdate>=0.25 then
        lastCareUiUpdate=os.clock()
        if L.Care and L.Care.Parent then
            L.Care.Text=string.format("%s  |  %s",careEnabled and "ON" or "OFF",careMessage)
        end
        if L.Avoidance and L.Avoidance.Parent then
            local nearest=lastThreatDistance<math.huge
                and string.format("%.0f",lastThreatDistance) or "not streamed"
            L.Avoidance.Text=(if avoidPlayers then "PLAYER AVOID ON  •  "
                else "PLAYER AVOID OFF  •  ")..nearest.." studs nearby"
        end
        if L.Travel and L.Travel.Parent then
            local pause=math.max(0,math.ceil(snapLockUntil-os.clock()))
            L.Travel.Text=(if travelStyle=="WALK" then "WALK ONLY" else "ONE SNAP MAX")
                .."  •  corrections "..snapCorrectionCount
                .."  •  global pause "..pause.."s"
        end
        if L.Hover and L.Hover.Parent then
            L.Hover.Text=undergroundStatus
            L.Hover.TextColor3=if undergroundConfirmed then
                Color3.fromRGB(142,221,165) else Color3.fromRGB(230,189,143)
        end
        if hoverButton and hoverButton.Parent and not undergroundRequested
            and hoverButton.Text~="SUBSURFACE: OFF" then
            hoverButton.Text="SUBSURFACE: OFF"
        end
        if L.Session and L.Session.Parent then
            if not sessionSaved and sessionLastFileError
                and sessionTotalSamples>2 then
                L.Session.Text="RECORDER ON • file autosave unavailable; COPY JSON works"
            elseif not sessionSaved then
                L.Session.Text="RECORDER ON • "..tostring(sessionTotalSamples)
                    .." snapshots / "..tostring(sessionTotalEvents).." events"
            end
        end
    end
end)

env.FERAL_TERRITORY_RUSH_V4={
    stop=stop,report=report,
    sessionReport=makeSessionPayload,
    sessionJSON=getSessionJSON,
    saveSession=function() return saveSession(true) end,
    sessionFilename=SESSION_FILENAME,
    startAuto=function()
        if not auto then toggleTerritoryAuto() end
    end,
    stopAuto=release,
    setAvoidance=function(on,radius)
        avoidPlayers=on==true
        if type(radius)=="number" then
            local best=1
            for i,r in ipairs(avoidRadii) do
                if math.abs(r-radius)<math.abs(avoidRadii[best]-radius) then best=i end
            end
            avoidRadiusIndex=best
        end
        avoidButton.Text=if avoidPlayers then "AVOID PLAYERS: ON" else "AVOID PLAYERS: OFF"
        radiusButton.Text="RADIUS: "..tostring(avoidRadius())
    end,
    setWalkOnly=function(on)
        travelStyle=if on then "WALK" else "ADAPTIVE"
        travelButton.Text=if on then "WALK ONLY" else "SNAP: ADAPTIVE"
        if on and undergroundState then
            exitUnderground(true,"WALK ONLY selected")
            if attempt and attempt.travelType=="UNDERGROUND" then
                attempt.failed=true
                lastFailure="WALK ONLY cancelled underground"
            end
        end
    end,
    setSubsurface=function(on)
        if not on then
            undergroundRequested=false
            if undergroundState then
                exitUnderground(true,"Subsurface stopped")
                if attempt and attempt.travelType=="UNDERGROUND" then
                    attempt.failed=true
                    lastFailure="Subsurface stopped by command"
                end
            end
        else
            undergroundRequested=true
            undergroundRefused=false
            undergroundConfirmed=nil
            undergroundStatus="ON • awaiting real claim proof"
        end
        hoverButton.Text=if undergroundRequested then "SUBSURFACE: TRIAL"
            else "SUBSURFACE: OFF"
    end,
    setCare=function(on)
        careEnabled=on==true
        careButton.Text=if careEnabled then "AUTO CARE: ON" else "AUTO CARE: OFF"
    end,
    careReport=function()
        return {active=careEnabled,mode=careMode,message=careMessage,
            hunt=careHuntEnabled,profile=careProfilesNames[careProfileIndex],
            inputUnavailable=inputUnavailable}
    end,
    selectMode=function(m)
        if m=="PRIORITY" or m=="SCENT" or m=="CLAIM" or m=="ALL" then
            release()
            mode=m
            modeB.Text="MODE: "..mode
            selectedKey=nil
            rebuild()
            return true
        end
        return false
    end
}
update()
print(string.format("[FERAL Territory RUSH v4.2] Hexes: %d, eligible: %d. Default PRIORITY mode; Auto checks actual _hold and ownership.",#all,countTypes().eligible))
print("[FERAL Territory RUSH v4.2] Live character movement, bounded retries, server territory observation.")
