-- FERAL Position-to-Territory Probe v1.0 (separate experimental tool)
-- Changes ONE character position only when SNAP is clicked.
-- Reads replicated server territory owner/progress, never modifies them.
-- No den-dive remote spoofing, rapid repeated remotes, or automatic multi-claim.
-- This tests whether client-initiated movement gets server-recognised capture.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local WS=game:GetService("Workspace")
local plr=Players.LocalPlayer
if not plr or game.PlaceId~=108901361810209 then
    warn("[FERAL Position Probe] Run inside FERAL Animal Survival.")
    return
end
local G=(type(getgenv)=="function" and getgenv()) or _G
if type(G.FERAL_POSITION_CLAIM_PROBE)=="table"
    and type(G.FERAL_POSITION_CLAIM_PROBE.stop)=="function" then
    pcall(G.FERAL_POSITION_CLAIM_PROBE.stop)
end

local world=RS:FindFirstChild("FeralWorld")
local configModule=world and world:FindFirstChild("TerritoryConfig")
local spotsModule=world and world:FindFirstChild("MapSpots")
local terr=RS:FindFirstChild("FeralTerritory")
local guiParent=plr:FindFirstChildOfClass("PlayerGui")
if not (configModule and spotsModule and terr and guiParent) then
    warn("[FERAL Position Probe] Territory, map data or PlayerGui not ready. Spawn an animal first.")
    return
end
local ok1,cfg=pcall(require,configModule)
local ok2,spotSets=pcall(require,spotsModule)
if not ok1 or not ok2 or type(cfg)~="table" or type(spotSets)~="table"
    or type(cfg.hexAt)~="function" or type(cfg.hexKey)~="function" then
    warn("[FERAL Position Probe] Native map/territory helpers unavailable.")
    return
end

local function getRoot()
    local c=plr.Character
    local r=c and c:FindFirstChild("HumanoidRootPart")
    local h=c and c:FindFirstChildOfClass("Humanoid")
    if c and r and h and h.Health>0 and not r.Anchored then
        return c,r,h
    end
end
local function dist2D(p,v)
    return math.sqrt((p.X-v.X)^2+(p.Z-v.Y)^2)
end
local biome=WS:GetAttribute("FeralBiome") or "WolfValley"
local spotList=spotSets[biome] or spotSets.WolfValley
if type(spotList)~="table" then
    warn("[FERAL Position Probe] No claim spots for biome "..tostring(biome))
    return
end
local hexes={}
for i,j in tostring(terr:GetAttribute("Hexes") or ""):gmatch("(%-?%d+),(%-?%d+)") do
    hexes["H"..i.."_"..j]=true
end
local targets={}
local _,startRoot=getRoot()
for _,spot in ipairs(spotList) do
    if typeof(spot.pos)=="Vector2" and type(spot.key)=="string"
        and (type(cfg.claimable)~="function" or cfg.claimable(spot.key)) then
        local i,j=cfg.hexAt(spot.pos.X,spot.pos.Y)
        local hex=cfg.hexKey(i,j)
        if hexes[hex] and not terr:GetAttribute(hex.."_neutral") then
            table.insert(targets,{
                key=spot.key,
                name=spot.name or spot.key,
                pos=spot.pos,
                hex=hex,
                distance=startRoot and dist2D(startRoot.Position,spot.pos) or 0
            })
        end
    end
end
table.sort(targets,function(a,b) return a.distance<b.distance end)
if #targets==0 then
    warn("[FERAL Position Probe] No matching server hexes. Try after loading into the map.")
    return
end
local index=1
local ownPack=plr:GetAttribute("FeralPack")
for i,t in ipairs(targets) do
    if (not startRoot or dist2D(startRoot.Position,t.pos)>180)
        and (not ownPack or terr:GetAttribute(t.hex.."_owner")~=ownPack) then
        index=i
        break
    end
end
local alive=true
local conn=nil
local moveSource=nil
local moveCharacter=nil
local moveTime=nil
local attempt=nil
local observedProgress=false
local observedOwnership=false
local maxObservedProgress=0
local lastStatus="READY — click SNAP to try one destination"
local nextRefresh=0
local labels={}

local gui=Instance.new("ScreenGui")
gui.Name="FERAL_PositionClaimProbeV1"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=349
gui.Parent=guiParent
local panel=Instance.new("Frame")
panel.Name="Panel"
panel.Size=UDim2.fromOffset(370,254)
panel.Position=UDim2.new(1,-386,0,116)
panel.BackgroundColor3=Color3.fromRGB(19,25,36)
panel.BorderSizePixel=0
panel.Parent=gui
local corner=Instance.new("UICorner",panel)
corner.CornerRadius=UDim.new(0,10)
local stroke=Instance.new("UIStroke",panel)
stroke.Color=Color3.fromRGB(64,84,107)
stroke.Thickness=1
local function label(name,y,height,bold)
    local l=Instance.new("TextLabel")
    l.Name=name
    l.BackgroundTransparency=1
    l.Position=UDim2.fromOffset(12,y)
    l.Size=UDim2.fromOffset(345,height)
    l.TextColor3=Color3.fromRGB(222,235,243)
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextYAlignment=Enum.TextYAlignment.Center
    l.TextSize=bold and 14 or 12
    l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextTruncate=Enum.TextTruncate.AtEnd
    l.Text="..."
    l.Parent=panel
    labels[name]=l
    return l
end
label("Title",9,25,true).Text="FERAL  |  POSITION CLAIM PROBE"
label("Spot",41,24)
label("Target",68,24)
label("Position",95,24)
label("State",122,24)
label("Evidence",149,24)
local status=label("Status",178,23)
status.TextColor3=Color3.fromRGB(250,202,115)
local function button(name,text,x,y,w,color)
    local b=Instance.new("TextButton")
    b.Name=name
    b.Text=text
    b.Font=Enum.Font.GothamBold
    b.TextSize=11
    b.TextColor3=Color3.fromRGB(255,255,255)
    b.BackgroundColor3=color
    b.Position=UDim2.fromOffset(x,y)
    b.Size=UDim2.fromOffset(w,29)
    b.AutoButtonColor=true
    b.Parent=panel
    local c=Instance.new("UICorner",b)
    c.CornerRadius=UDim.new(0,6)
    return b
end
local snap=button("Snap","SNAP",12,211,65,Color3.fromRGB(39,118,129))
local back=button("Return","RETURN",83,211,69,Color3.fromRGB(100,75,115))
local next=button("Next","NEXT",158,211,55,Color3.fromRGB(56,78,116))
local copy=button("Copy","COPY RESULT",219,211,88,Color3.fromRGB(57,93,89))
local close=button("Close","X",313,211,44,Color3.fromRGB(119,62,74))

local function targetNow()
    return targets[index]
end
local function say(msg)
    lastStatus=msg
    if labels.Status then labels.Status.Text=msg end
end
local function report()
    local t=targetNow()
    local c,r=getRoot()
    local state=t and terr:GetAttribute(t.hex.."_state")
    local prog=t and terr:GetAttribute(t.hex.."_prog")
    local by=t and terr:GetAttribute(t.hex.."_by")
    local owner=t and terr:GetAttribute(t.hex.."_owner")
    return {
        version="1.0.0",
        biome=biome,
        target=t and t.key,
        hex=t and t.hex,
        localDistance=t and r and math.floor(dist2D(r.Position,t.pos)+0.5),
        age=moveTime and math.floor(os.clock()-moveTime+0.5) or 0,
        state=state,
        progress=prog,
        byOwnPack=by~=nil and plr:GetAttribute("FeralPack")==by,
        ownerOwnPack=owner~=nil and plr:GetAttribute("FeralPack")==owner,
        sawOwnPackProgressIncrease=observedProgress,
        sawOwnPackOwnershipChange=observedOwnership,
        highestProgress=maxObservedProgress,
        status=lastStatus
    }
end
local function stop()
    if not alive then return end
    alive=false
    if conn then conn:Disconnect() conn=nil end
    if gui then gui:Destroy() end
    if G.FERAL_POSITION_CLAIM_PROBE
        and G.FERAL_POSITION_CLAIM_PROBE.stop==stop then
        G.FERAL_POSITION_CLAIM_PROBE=nil
    end
end
close.Activated:Connect(stop)
next.Activated:Connect(function()
    index=index%#targets+1
    attempt=nil
    observedProgress=false
    observedOwnership=false
    maxObservedProgress=0
    moveTime=nil
    say("TARGET CHANGED — select SNAP to test it")
end)
back.Activated:Connect(function()
    local c,r=getRoot()
    if not (c and r and c==moveCharacter and moveSource) then
        say("No saved position for this animal")
        return
    end
    local delta=moveSource.Position-r.Position
    c:PivotTo(c:GetPivot()+delta)
    r.AssemblyLinearVelocity=Vector3.zero
    r.AssemblyAngularVelocity=Vector3.zero
    say("RETURN attempted — normal movement may correct it")
end)
copy.Activated:Connect(function()
    local results=report()
    local parts={}
    for _,key in ipairs({"version","biome","target","hex","localDistance","age",
        "state","progress","byOwnPack","ownerOwnPack","sawOwnPackProgressIncrease",
        "sawOwnPackOwnershipChange","highestProgress","status"}) do
        table.insert(parts,key.."="..tostring(results[key]))
    end
    local summary="[FERAL POSITION PROBE] "..table.concat(parts," | ")
    if type(setclipboard)=="function" then
        local ok=pcall(setclipboard,summary)
        say(ok and "RESULT COPIED — paste in chat" or "Copy failed; result printed to console")
    else
        say("Clipboard unavailable; result printed to console")
    end
    print(summary)
end)
snap.Activated:Connect(function()
    local t=targetNow()
    local c,r,h=getRoot()
    if not c then
        say("Spawn a living animal before testing")
        return
    end
    if not plr:GetAttribute("FeralPack") then
        say("Join/create a pack before testing")
        return
    end
    if c:GetAttribute("FeralFlyLocal")
        or (c:GetAttribute("FeralFly") and c:GetAttribute("FeralFly")~="flutter")
        or c:GetAttribute("FeralDenRoot")
        or c:GetAttribute("FeralPinned") then
        say("Exit flight, den dive or pinned state first")
        return
    end
    if dist2D(r.Position,t.pos)<=145 then
        say("Too close to this spot; use NEXT for a remote test")
        return
    end
    if terr:GetAttribute(t.hex.."_owner")==plr:GetAttribute("FeralPack") then
        say("Already owned by pack; press NEXT")
        return
    end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={c}
    rp.IgnoreWater=false
    local ray=WS:Raycast(Vector3.new(t.pos.X,1600,t.pos.Y),
        Vector3.new(0,-2800,0),rp)
    if not ray then
        say("Ground not streamed at target — cannot snap safely")
        return
    end
    if ray.Material==Enum.Material.Water then
        say("Water at target; try NEXT (grounded claim needed)")
        return
    end
    local clearance=math.max(3, h.HipHeight+r.Size.Y/2+1)
    local destination=Vector3.new(t.pos.X,ray.Position.Y+clearance,t.pos.Y)
    moveSource=r.CFrame
    moveCharacter=c
    moveTime=os.clock()
    attempt={
        targetKey=t.key,
        hex=t.hex,
        pack=plr:GetAttribute("FeralPack"),
        oldProgress=terr:GetAttribute(t.hex.."_prog") or 0,
        lastProgress=terr:GetAttribute(t.hex.."_prog") or 0,
        oldOwner=terr:GetAttribute(t.hex.."_owner"),
        startDistance=dist2D(r.Position,t.pos)
    }
    observedProgress=false
    observedOwnership=false
    maxObservedProgress=attempt.oldProgress
    local delta=destination-r.Position
    local good,err=pcall(function()
        c:PivotTo(c:GetPivot()+delta)
        r.AssemblyLinearVelocity=Vector3.zero
        r.AssemblyAngularVelocity=Vector3.zero
    end)
    if not good then
        say("Snap failed: "..tostring(err))
        return
    end
    say(string.format("SNAP sent locally (%.0f units); watch progress",attempt.startDistance))
end)

local function refresh()
    if not alive then return end
    local t=targetNow()
    if not t then return end
    local c,r=getRoot()
    local distance=r and dist2D(r.Position,t.pos)
    local pack=plr:GetAttribute("FeralPack")
    local owner=terr:GetAttribute(t.hex.."_owner")
    local by=terr:GetAttribute(t.hex.."_by")
    local state=terr:GetAttribute(t.hex.."_state")
    local progress=terr:GetAttribute(t.hex.."_prog")
    local numericProgress=type(progress)=="number" and progress or 0
    local owns=pack~=nil and owner==pack
    labels.Spot.Text=string.format("Target %d/%d: %s",index,#targets,t.name)
    labels.Target.Text="Hex: "..t.hex.."  |  Your pack: "..(pack and "yes" or "no")
    labels.Position.Text="Your horizontal distance: "..(distance and string.format("%.0f",distance) or "not spawned")
        .."  |  normal radius 120"
    labels.State.Text=string.format("Territory: %s  |  progress %.1f%%",
        tostring(state or "idle"),numericProgress*100)
    if attempt and attempt.targetKey==t.key then
        if by==attempt.pack and state=="claim"
            and numericProgress>attempt.lastProgress+0.002 then
            observedProgress=true
        end
        if owner==attempt.pack and attempt.oldOwner~=attempt.pack then
            observedOwnership=true
        end
        maxObservedProgress=math.max(maxObservedProgress,numericProgress)
        attempt.lastProgress=numericProgress
        local elapsed=os.clock()-moveTime
        if observedOwnership then
            labels.Evidence.Text="OWNER CHANGED TO YOUR PACK"
            labels.Evidence.TextColor3=Color3.fromRGB(122,241,162)
        elseif observedProgress then
            labels.Evidence.Text="OWN-PACK PROGRESS INCREASED AFTER SNAP"
            labels.Evidence.TextColor3=Color3.fromRGB(122,241,162)
        elseif elapsed>=6 and distance and distance>180 then
            labels.Evidence.Text="Not at target — movement was reversed/failed"
            labels.Evidence.TextColor3=Color3.fromRGB(254,157,130)
        else
            labels.Evidence.Text="No confirmed progress yet  |  "..math.floor(elapsed).."s"
            labels.Evidence.TextColor3=Color3.fromRGB(244,203,115)
        end
    else
        labels.Evidence.Text=owns and "Already owned by your pack"
            or "No attempt yet — press SNAP to test position"
        labels.Evidence.TextColor3=Color3.fromRGB(204,219,232)
    end
end
conn=RunService.Heartbeat:Connect(function()
    if not alive then return end
    if os.clock()<nextRefresh then return end
    nextRefresh=os.clock()+0.35
    local ok,err=pcall(refresh)
    if not ok then say("Observer issue: "..tostring(err)) end
end)
G.FERAL_POSITION_CLAIM_PROBE={stop=stop,report=report}
refresh()
print("[FERAL Position Probe] Ready; select SNAP for ONE client-side position attempt.")
print("[FERAL Position Probe] Client snap/progress alone does not prove map-wide claiming. Use COPY RESULT.")
