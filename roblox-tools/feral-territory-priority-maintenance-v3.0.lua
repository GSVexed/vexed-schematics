-- FERAL Territory Position Maintenance v3.0: SMART SNAP + PRIORITY
-- Experimental position-based maintenance. No server-side capture authority is implied.
-- Reads FeralTerritory.Hexes and per-hex attributes. Does not modify territory attrs.
-- Moves the actual animal. Automatic retries are bounded; success requires replicated territory state.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local me=Players.LocalPlayer
if not me or game.PlaceId~=108901361810209 then
    warn("[FERAL Territory Probe v2] Expected FERAL Animal Survival.")
    return
end
local env=(type(getgenv)=="function" and getgenv()) or _G
for _,name in ipairs({"FERAL_POSITION_CLAIM_PROBE","FERAL_TERRITORY_MAINTENANCE_V2","FERAL_TERRITORY_MAINTENANCE_V3","FERAL_RADIUS_EXPERIMENT"}) do
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
local totalRetries,totalSkipped,totalCompleted=0,0,0
local lastFailure=nil
local autoBusy=false
local busySnap=false
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

local function score(t)
    local h=hold(t.key)
    if isOwned(t.key) then
        if h==nil then return -1 end
        if h<0.35 then return 300+(1-h)*100 end
        if h<SCENT_TRIGGER then return 200+(1-h)*100 end
        return -100
    end
    local owner=value(t.key,"owner")
    return owner==nil and 100 or 80
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
            local aOwner,bOwner=value(a.key,"owner"),value(b.key,"owner")
            if (aOwner==nil)~=(bOwner==nil) then return aOwner==nil end
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
end
local function event(s)
    table.insert(sampleLog,1,string.format("%.1f: %s",os.clock(),s))
    if #sampleLog>18 then table.remove(sampleLog) end
end

gui=Instance.new("ScreenGui")
gui.Name="FERAL_TerritoryMaintainV2"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=360
gui.Parent=pg
local frame=Instance.new("Frame")
frame.Name="Panel"
frame.Position=UDim2.new(1,-426,0,105)
frame.Size=UDim2.fromOffset(410,316)
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
label("Title",10,24).Text="FERAL  |  SMART CLAIM + SCENT v3"
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

local function release()
    auto=false
    autoToken+=1
    autoB.Text="AUTO: OFF"
end
local function stop()
    if not active then return end
    active=false
    release()
    if heartbeat then heartbeat:Disconnect() heartbeat=nil end
    if gui then gui:Destroy() gui=nil end
    if env.FERAL_TERRITORY_MAINTENANCE_V2
        and env.FERAL_TERRITORY_MAINTENANCE_V2.stop==stop then
        env.FERAL_TERRITORY_MAINTENANCE_V2=nil
    end
end
closeB.Activated:Connect(stop)

local function choose(i)
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
    selectedKey=nil
    rebuild()
    say(target() and "Selected lowest-scent owned hex" or "No owned hexes found")
end)
reloadB.Activated:Connect(function()
    release()
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
    local moved=pcall(function()
        c:PivotTo(c:GetPivot()+(returnCFrame.Position-r.Position))
        r.AssemblyLinearVelocity=Vector3.zero
        r.AssemblyAngularVelocity=Vector3.zero
    end)
    say(moved and "RETURN attempted (not guaranteed server-accepted)" or "Return failed")
end)

local function safePoint(t,c)
    -- Search the entire target hex, not just 10 points near its centre.
    -- Remote map chunks often are not streamed when this probe first runs.
    local candidate={t.landing,t.center}
    local radii={25,50,75,100,130,160,185,205}
    for _,radius in ipairs(radii) do
        for direction=0,15 do
            local angle=direction*math.pi/8
            table.insert(candidate,t.center+Vector2.new(
                math.cos(angle)*radius,math.sin(angle)*radius))
        end
    end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={c}
    params.IgnoreWater=false
    local stats={sampled=0,hits=0,water=0,steep=0}
    for _,p in ipairs(candidate) do
        if typeof(p)=="Vector2" then
            local i,j=cfg.hexAt(p.X,p.Y)
            local check=type(cfg.hexKey)=="function" and cfg.hexKey(i,j)
                or ("H"..tostring(i).."_"..tostring(j))
            if check==t.key then
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
    for pass=1,10 do
        ground,stats=safePoint(t,c)
        if ground then
            return ground,string.format("streamed after pass %d",pass)
        end
        if pass<10 then task.wait(0.6) end
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
    local c,r,h=root()
    if not c then return false,"Spawn a living animal first" end
    local pack=me:GetAttribute("FeralPack")
    if pack==nil then return false,"Join a pack before territory maintenance" end
    if c:GetAttribute("FeralDenRoot") or c:GetAttribute("FeralPinned")
        or c:GetAttribute("FeralFlyLocal")
        or (c:GetAttribute("FeralFly") and c:GetAttribute("FeralFly")~="flutter") then
        return false,"Land and exit pinned/den modes before SNAP"
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
    if not active then return false,"Panel was closed" end
    if not ground then
        lastLandingError="No safe landing: "..t.key.." — "..groundInfo
        event(lastLandingError)
        return false,lastLandingError
    end
    local clearance=math.max(3,h.HipHeight+r.Size.Y*0.5+1.0)
    local point=ground+Vector3.new(0,clearance,0)
    local a={
        key=t.key,pack=pack,originalOwner=owner,originalHold=oldHold,
        originalProgress=type(oldProgress)=="number" and oldProgress or 0,
        lastHold=oldHold,lastProgress=type(oldProgress)=="number" and oldProgress or 0,
        began=os.clock(),startDist=startingDistance,
        evidenceProgress=false,evidenceScent=false,evidenceOwner=false,
        destination=point,character=c,lastSnap=0,snapCount=0,
        snapBacks=0,inTarget=false,lastEvidenceAt=os.clock(),
        failed=false,kind=owner==pack and "SCENT" or "CLAIM"
    }
    attempt=a
    local okMove,err=applyPosition(a)
    if not okMove then
        a.failed=true
        return false,"SNAP failed: "..tostring(err)
    end
    event(string.format("SNAP %s from %.0f studs (%s)",
        t.key,startingDistance,groundInfo))
    return true,string.format("SNAP %s — %s; checking real territory state",
        t.key,a.kind)
end

-- The live game sometimes corrects a snap-back to the old location.
-- Only retry while an explicit SNAP or AUTO target is current;
-- at most 4 placements, spaced >=3 seconds apart, then stop.
local function keepTarget()
    local a=attempt
    if not (a and a.destination and not a.failed and active) then return end
    local c,r=root()
    if c~=a.character or not r then
        a.failed=true
        lastFailure="Animal changed/died during maintenance"
        return
    end
    local distance=(r.Position-a.destination).Magnitude
    if distance<125 then
        a.inTarget=true
        return
    end
    local elapsed=os.clock()-a.lastSnap
    if elapsed<3 or os.clock()-a.began>45 then return end
    if a.snapCount>=4 then
        a.failed=true
        lastFailure="Server kept correcting position: "..a.key
        event(lastFailure)
        return
    end
    a.snapBacks+=1
    totalRetries+=1
    local okMove,err=applyPosition(a)
    if not okMove then
        a.failed=true
        lastFailure="Snap retry failed: "..tostring(err)
    else
        event(string.format("Retry after snap-back %s (%d/4)",
            a.key,a.snapCount))
    end
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
        claimedCount+=1
        changedCount+=1
        event(a.key.." claimed by pack after SNAP")
    end
    if owner==a.pack and nowHold~=nil
        and a.lastHold~=nil and nowHold>a.lastHold+0.001 then
        a.lastEvidenceAt=os.clock()
        if not a.evidenceScent then
            a.evidenceScent=true
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
        version="3.0.0",mode=mode,biome=biome,
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
        "currentSnaps","snapFailed","lastFailure","lastStatus"
    }) do
        table.insert(v,key.."="..tostring(p[key]))
    end
    local result="[FERAL TERRITORY MAINTENANCE V3.0] "..table.concat(v," | ")
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
heartbeat=RunService.Heartbeat:Connect(function()
    if not active or os.clock()<nextUpdate then return end
    nextUpdate=os.clock()+0.4
    local success,err=pcall(update)
    if not success then say("Monitor error: "..tostring(err)) end
end)

local AUTO_TRIGGER_HOLD=0.80 -- Watch until meaningful fading, avoiding constant repeated snaps.
local function nextFading()
    local arr={}
    for _,t in ipairs(all) do
        local h=hold(t.key)
        if not isNeutral(t.key) and isOwned(t.key)
            and h~=nil and h<AUTO_TRIGGER_HOLD then
            table.insert(arr,t)
        end
    end
    table.sort(arr,function(a,b)
        local ha,hb=hold(a.key),hold(b.key)
        if ha==hb then return a.key<b.key end
        return ha<hb
    end)
    return arr[1]
end
autoB.Activated:Connect(function()
    if auto then
        release()
        say("AUTO SCENT stopped")
        return
    end
    if mode~="SCENT" then
        say("AUTO only operates in SCENT mode")
        return
    end
    if not me:GetAttribute("FeralPack") then
        say("Join a pack before AUTO SCENT")
        return
    end
    auto=true
    autoToken+=1
    local token=autoToken
    autoB.Text="AUTO: ON"
    say("AUTO SCENT WATCH on — triggers below 80% scent")
    task.spawn(function()
        while active and auto and token==autoToken do
            local t=nextFading()
            if not t then
                say("AUTO WATCH: all owned scent >=80% (or unavailable)")
                task.wait(5)
            else
            if not isOwned(t.key) then
                release()
                say("An owned hex changed owner; automation stopped")
                break
            end
            rebuild()
            for i,p in ipairs(targets) do
                if p.key==t.key then index=i selectedKey=t.key break end
            end
            local okMove,msg=moveTo(t)
            say(msg)
            if not okMove then
                release()
                break
            end
            local a=attempt
            local firstRise=false
            local stalledAt=os.clock()+16
            local hardStop=os.clock()+100
            local done=false
            while active and auto and token==autoToken and os.clock()<hardStop do
                task.wait(0.5)
                if not active or not auto or token~=autoToken then break end
                if not isOwned(a.key) then
                    release()
                    say("Lost territory during AUTO; stopped")
                    break
                end
                local h=hold(a.key)
                if not h then
                    release()
                    say("No scent data — AUTO stopped")
                    break
                end
                if h>=0.985 then
                    event(a.key.." scent restored to "..math.floor(h*100).."%")
                    done=true
                    break
                end
                if a.evidenceScent then firstRise=true end
                if not firstRise and os.clock()>stalledAt then
                    release()
                    say("No replicated scent increase — AUTO stopped")
                    break
                end
            end
            if not auto or not active or token~=autoToken then break end
            if not done then
                release()
                say("Scent did not finish restoring — AUTO stopped")
                break
            end
            task.wait(0.8)
            end -- owned target available
        end
    end)
end)

env.FERAL_TERRITORY_MAINTENANCE_V3={
    stop=stop,report=report,
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
print(string.format("[FERAL Territory v3.0] Hexes: %d, eligible: %d. Default SCENT mode; Auto requires real _hold increase.",#all,countTypes().eligible))
print("[FERAL Territory v3.0] Live character movement, bounded retries, server territory observation.")
