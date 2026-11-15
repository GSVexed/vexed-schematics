-- FERAL Replication & Stamina Lab v1.5
-- Passive client-side research only.
-- Reads visible replication, observes incoming RemoteEvent occurrence counts (no payloads),
-- tracks stamina/movement/health; does not send remotes, alter game state or hook functions.
-- Cannot read private server-side state or establish server authority by itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local previousGui = playerGui:FindFirstChild("StaminaResearchPanel")
if previousGui then previousGui:Destroy() end

local DURATION = 120
local SAMPLE_INTERVAL = 0.25
local MAX_SAMPLES = 520
local MAX_EVENTS = 220
local MAX_REMOTES = 70
local MAX_REPLICATED_OBJECTS = 75

local theme = {
    background = Color3.fromRGB(14, 19, 29),
    surface = Color3.fromRGB(26, 35, 50),
    highlight = Color3.fromRGB(37, 53, 72),
    outline = Color3.fromRGB(62, 79, 104),
    text = Color3.fromRGB(239, 246, 253),
    muted = Color3.fromRGB(161, 183, 203),
    turquoise = Color3.fromRGB(40, 194, 168),
    blue = Color3.fromRGB(67, 129, 209),
    red = Color3.fromRGB(198, 78, 88)
}
local function make(class, props, parent)
    local obj = Instance.new(class)
    for key, value in pairs(props) do obj[key] = value end
    obj.Parent = parent
    return obj
end
local function corner(obj, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 9)}, obj)
end
local function text(parent, name, value, x, y, w, h, size, color, bold)
    return make("TextLabel", {
        Name = name, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h), Text = value,
        BackgroundTransparency = 1, TextColor3 = color or theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
        TextSize = size, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    }, parent)
end
local function button(parent, name, caption, x, y, width, color)
    local b = make("TextButton", {
        Name = name, Text = caption,
        Position = UDim2.fromOffset(x,y), Size = UDim2.fromOffset(width,38),
        BorderSizePixel = 0, BackgroundColor3 = color,
        TextColor3 = theme.text, TextSize = 12,
        Font = Enum.Font.GothamBold, AutoButtonColor = true
    }, parent)
    corner(b,7)
    return b
end

local gui = make("ScreenGui", {
    Name = "StaminaResearchPanel", DisplayOrder = 350,
    ResetOnSpawn = false, IgnoreGuiInset = true
}, playerGui)
local panel = make("Frame", {
    Name = "ResearchPanel", AnchorPoint = Vector2.new(0.5,0.5),
    Position = UDim2.fromScale(0.5,0.5),
    Size = UDim2.fromOffset(540,630),
    BackgroundColor3 = theme.background, BorderSizePixel = 0, Active = true
}, gui)
corner(panel,13)
make("UIStroke",{Color=theme.outline,Thickness=1},panel)
local camera = workspace.CurrentCamera
if camera then
    local v = camera.ViewportSize
    make("UIScale", {
        Scale=math.clamp(math.min(v.X/580,v.Y/700),0.6,1)
    },panel)
end
local header=make("Frame", {
    Name="DragHeader",Size=UDim2.fromOffset(540,58),
    BackgroundTransparency=1,Active=true
},panel)
text(header,"Title","FERAL  /  REPLICATION LAB",16,6,396,28,17,theme.text,true)
text(header,"Subtitle","v1.5 • client-visible server signals • read-only",16,33,395,16,10,theme.muted,false)
local minimize=button(header,"Minimize","–",468,13,27,theme.highlight)
local close=button(header,"Close","X",503,13,24,theme.red)
local box=make("Frame",{
    Name="Overview",Position=UDim2.fromOffset(14,65),
    Size=UDim2.fromOffset(512,149),BackgroundColor3=theme.surface,
    BorderSizePixel=0
},panel)
corner(box,11)
text(box,"StamCaption","STAMINA / MAXIMUM",12,7,240,18,10,theme.muted,true)
local stamText=text(box,"Stamina","— / —",12,26,300,32,24,theme.text,true)
local rateText=text(box,"Rate","— / sec",326,31,172,26,12,theme.turquoise,true)
rateText.TextXAlignment=Enum.TextXAlignment.Right
local track=make("Frame",{Name="Track",Position=UDim2.fromOffset(12,64),
    Size=UDim2.fromOffset(488,10),BackgroundColor3=theme.highlight,BorderSizePixel=0},box)
corner(track,5)
local fill=make("Frame",{Name="Fill",Size=UDim2.fromScale(0,1),
    BackgroundColor3=theme.turquoise,BorderSizePixel=0},track)
corner(fill,5)
local modeText=text(box,"Mode","Movement: unknown",12,84,486,23,14,theme.turquoise,true)
local statsText=text(box,"Vitals","Health —  •  Speed —  •  Ping —",12,112,486,22,11,theme.muted,false)

local serverBox=make("Frame",{
    Name="Replication",Position=UDim2.fromOffset(14,224),
    Size=UDim2.fromOffset(512,105),BackgroundColor3=theme.surface,
    BorderSizePixel=0
},panel)
corner(serverBox,11)
text(serverBox,"RTitle","REPLICATION AND ENFORCEMENT OBSERVATION",12,9,486,18,10,theme.muted,true)
local remoteText=text(serverBox,"RemoteCount","RemoteEvents visible: 0   •   inbound signals: 0",12,33,486,23,13,theme.text,true)
local changeText=text(serverBox,"ChangeCount","State transitions: 0   •   health events: 0",12,60,486,22,11,theme.muted,false)

local notice=text(panel,"Notice",
    "The client can observe replicated state; it cannot inspect private server code.",15,337,506,31,
    10,theme.muted,false)

local start=button(panel,"Start","Start 120s scan",14,378,174,theme.turquoise)
local stop=button(panel,"Stop","Stop",197,378,74,theme.red)
local copySummary=button(panel,"CopySummary","Copy summary",280,378,118,theme.blue)
local copyFull=button(panel,"CopyFull","Copy full",407,378,119,theme.blue)
local progressBase=make("Frame", {
    Name="Progress",Position=UDim2.fromOffset(14,427),Size=UDim2.fromOffset(512,6),
    BackgroundColor3=theme.highlight,BorderSizePixel=0
},panel)
corner(progressBase,3)
local progress=make("Frame",{
    Name="ProgressFill",Size=UDim2.fromScale(0,1),
    BackgroundColor3=theme.blue,BorderSizePixel=0
},progressBase)
corner(progress,3)
local status=text(panel,"Status","Ready. Start the scan and move normally, including burst and recovery.",
    14,443,512,36,11,theme.muted,false)
text(panel,"ReportLabel","REPORT PREVIEW  •  SELECT ALL / COPY IF CLIPBOARD FAILS",14,486,512,19,
    10,theme.muted,true)
local reportBox=make("TextBox",{
    Name="Report",Position=UDim2.fromOffset(14,509),
    Size=UDim2.fromOffset(512,105),BackgroundColor3=theme.surface,
    Text="Press Start to capture visible replication and stamina/health events.",
    TextColor3=theme.text,BorderSizePixel=0,Font=Enum.Font.Code,
    TextSize=11,TextWrapped=false,TextEditable=true,
    MultiLine=true,ClearTextOnFocus=false,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top
},panel)
corner(reportBox,9)
make("UIPadding",{PaddingLeft=UDim.new(0,9),PaddingRight=UDim.new(0,9),
    PaddingTop=UDim.new(0,7),PaddingBottom=UDim.new(0,7)},reportBox)

local connections={}
local characterConnections={}
local remoteConnections={}
local function own(c)
    table.insert(connections,c)
    return c
end
local function clear(list)
    for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
    table.clear(list)
end

local isDragging=false
local dragInput=nil
local startPosition=nil
own(header.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or
       input.UserInputType==Enum.UserInputType.Touch then
        isDragging=true
        dragInput=input.Position
        startPosition=panel.Position
    end
end))
own(UserInputService.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType==Enum.UserInputType.MouseMovement or
       input.UserInputType==Enum.UserInputType.Touch) then
        local d=input.Position-dragInput
        panel.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+d.X,
            startPosition.Y.Scale,startPosition.Y.Offset+d.Y)
    end
end))
own(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or
       input.UserInputType==Enum.UserInputType.Touch then isDragging=false end
end))

local minimized=false
minimize.Activated:Connect(function()
    minimized=not minimized
    panel.Size=UDim2.fromOffset(540,minimized and 58 or 630)
    for _,obj in ipairs(panel:GetChildren()) do
        if obj~=header and obj:IsA("GuiObject") then obj.Visible=not minimized end
    end
    minimize.Text=minimized and "+" or "–"
end)

local running=false
local stopNow=false
local begun=0
local samples={}
local events={}
local remoteList={}
local remoteByObject={}
local seenAttributes={}
local seenReplicatedValues={}
local boundCharacter=nil
local boundHumanoid=nil
local lastSummary=""
local lastFull=""
local lastStam=nil
local lastTime=nil
local lastObservedMode="Unknown"
local healthEvents=0
local anomalousDrops=0
local replicationCount=0
local scanCount=0
local reportTruncated=false
local replicationTruncated=false
local remoteTruncated=false

local function tnow()
    return running and math.max(0,os.clock()-begun) or 0
end
local function fmt(n)
    if typeof(n)=="number" then return string.format("%.2f",n) end
    if n==nil then return "-" end
    return tostring(n)
end
local function relevant(name)
    local n=string.lower(tostring(name))
    for _,key in ipairs({"stam","energ","burst","sprint","trot","crawl","crouch",
        "speed","movement","gait","health","fatigue","exhaust","jump","dash",
        "boost","rush","endurance"}) do
        if string.find(n,key,1,true) then return true end
    end
    return false
end
local function attr(obj,key)
    if not obj then return nil end
    return obj:GetAttribute(key)
end
local function number(obj,key)
    local value=attr(obj,key)
    if typeof(value)=="number" then return value end
    return nil
end
local function snapshot()
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    return "stam="..fmt(number(char,"Stamina"))..
        " / "..fmt(number(char,"StaminaMax"))..
        " health="..fmt(hum and hum.Health)..
        " exhausted="..fmt(attr(char,"StaminaOut"))..
        " sprint="..fmt(attr(player,"HudSprint"))..
        " burst="..fmt(attr(char,"WolfBurst"))..
        " trot="..fmt(attr(char,"WolfTrot"))
end
local function log(message)
    if not running then return end
    if #events>=MAX_EVENTS then reportTruncated=true;return end
    table.insert(events,string.format("[%.2fs] %s",tnow(),message))
end
local function stateMode(char, speed, input)
    local burst=attr(char,"WolfBurst")==true or attr(player,"HudBurst")==true
    local sprint=attr(player,"HudSprint")==true
    local trot=attr(char,"WolfTrot")==true or attr(player,"HudTrot")==true
    local crouch=attr(char,"FeralCrouch")==true
    local exhausted=attr(char,"StaminaOut")==true
    if burst then return "Burst (explicit flag)" end
    if sprint then return "Sprint (HUD flag)" end
    if trot then return "Trot (explicit flag)" end
    if crouch then return "Crouch (explicit flag)" end
    if speed and speed<0.8 and (not input or input<0.1) then return "Idle / Rest" end
    if exhausted then return "Exhausted movement" end
    if speed and speed>0.8 then return "Walking / unlabelled" end
    return "Unknown"
end

local function bindCharacter()
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if boundCharacter==char and boundHumanoid==hum then return end
    clear(characterConnections)
    boundCharacter,boundHumanoid=char,hum
    if not char then return end
    local function listen(key)
        table.insert(characterConnections,char:GetAttributeChangedSignal(key):Connect(function()
            if not running then return end
            local val=char:GetAttribute(key)
            log("CHAR ATTRIBUTE "..key.."="..fmt(val).." | "..snapshot())
        end))
    end
    for _,key in ipairs({"StaminaOut","WolfBurst","WolfTrot","FeralCrouch","StaminaMax"}) do
        listen(key)
    end
    if hum then
        table.insert(characterConnections,hum.HealthChanged:Connect(function(h)
            if running then
                healthEvents=healthEvents+1
                log("HEALTH CHANGED "..fmt(h).." | "..snapshot())
            end
        end))
        table.insert(characterConnections,hum.Died:Connect(function()
            if running then log("HUMANOID DIED | "..snapshot()) end
        end))
        table.insert(characterConnections,hum.StateChanged:Connect(function(old,new)
            if running and (new==Enum.HumanoidStateType.Jumping or
                new==Enum.HumanoidStateType.Freefall or
                new==Enum.HumanoidStateType.Dead) then
                log("HUMANOID STATE "..old.Name.." -> "..new.Name.." | "..snapshot())
            end
        end))
    end
    log("CHARACTER/HUMANOID BOUND | "..snapshot())
end

local function scanVisibleAttributes()
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    for _,pair in ipairs({{player,"Player"},{char,"Character"},
                          {hum,"Humanoid"},{root,"Root"}}) do
        local obj,prefix=pair[1],pair[2]
        if obj then
            local ok,attributes=pcall(function() return obj:GetAttributes() end)
            if ok then
                for key,val in pairs(attributes) do
                    if relevant(key) then
                        local id=prefix.."@"..key
                        local content=string.sub(tostring(val),1,95)
                        if seenAttributes[id]~=content then
                            seenAttributes[id]=content
                            if key~="Stamina" then
                                log("VISIBLE ATTRIBUTE "..id.."="..content)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ReplicatedStorage is a client-visible container, not access to ServerStorage.
local function scanReplicatedStorage()
    local found=0
    for _,obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if found>=MAX_REPLICATED_OBJECTS then
            replicationTruncated=true
            break
        end
        if relevant(obj.Name) and (obj:IsA("ValueBase") or obj:IsA("Folder")) then
            found=found+1
            local id=string.sub(obj:GetFullName(),1,140)
            if obj:IsA("ValueBase") then
                local ok,value=pcall(function() return obj.Value end)
                local valueText=ok and string.sub(tostring(value),1,95) or "unavailable"
                if seenReplicatedValues[id]~=valueText then
                    seenReplicatedValues[id]=valueText
                    log("REPLICATED VALUE "..id.."="..valueText)
                end
            else
                if seenReplicatedValues[id]==nil then
                    seenReplicatedValues[id]="<Folder>"
                    log("REPLICATED FOLDER "..id)
                end
            end
        end
    end
    replicationCount=found
end

-- Only observe incoming notification counts, never remote argument payloads.
local function scanRemotes()
    local roots={ReplicatedStorage}
    if player.Character then table.insert(roots,player.Character) end
    for _,root in ipairs(roots) do
        for _,obj in ipairs(root:GetDescendants()) do
            if #remoteList>=MAX_REMOTES then remoteTruncated=true;return end
            if (obj:IsA("RemoteEvent") or obj:IsA("UnreliableRemoteEvent"))
                and not remoteByObject[obj] then
                local entry={
                    name=string.sub(obj:GetFullName(),1,150),
                    first=-1,last=-1,count=0,instance=obj
                }
                remoteByObject[obj]=entry
                table.insert(remoteList,entry)
                local ok,con=pcall(function()
                    return obj.OnClientEvent:Connect(function()
                        if not running then return end
                        entry.count=entry.count+1
                        entry.last=tnow()
                        if entry.first<0 then entry.first=entry.last end
                        if entry.count<=2 then
                            log("INBOUND REMOTE SIGNAL "..entry.name.." occurrence #"..entry.count..
                                " | "..snapshot())
                        end
                    end)
                end)
                if ok and con then table.insert(remoteConnections,con) end
            end
        end
    end
end

local function readSample()
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local horizontal=nil
    if root and root:IsA("BasePart") then
        local v=root.AssemblyLinearVelocity
        horizontal=Vector3.new(v.X,0,v.Z).Magnitude
    end
    local input=hum and hum.MoveDirection.Magnitude or nil
    local latency=nil
    pcall(function() latency=player:GetNetworkPing() end)
    local row={
        t=tnow(),stam=number(char,"Stamina"),maximum=number(char,"StaminaMax"),
        exhausted=attr(char,"StaminaOut"),
        burst=attr(char,"WolfBurst"),sprint=attr(player,"HudSprint"),
        trot=attr(char,"WolfTrot"),crouch=attr(char,"FeralCrouch"),
        health=hum and hum.Health or nil,maxHealth=hum and hum.MaxHealth or nil,
        speed=horizontal,walkspeed=hum and hum.WalkSpeed or nil,
        input=input,ping=latency,state=hum and hum:GetState().Name or "NoHumanoid"
    }
    row.mode=stateMode(char,horizontal,input)
    if row.mode~=lastObservedMode then
        log("MODE "..lastObservedMode.." -> "..row.mode.." | "..snapshot())
        lastObservedMode=row.mode
    end
    if lastStam~=nil and row.stam~=nil and lastTime then
        local elapsed=row.t-lastTime
        local change=row.stam-lastStam
        if elapsed>0 and elapsed<1 and change< -2.6 then
            anomalousDrops=anomalousDrops+1
            log("LARGE STAMINA DROP "..fmt(change).." in "..fmt(elapsed).."s, mode="..
                row.mode.." state="..row.state.." | "..snapshot())
        end
        local rate=elapsed>0 and change/elapsed or 0
        rateText.Text=string.format("%+.2f / sec",rate)
        rateText.TextColor3=rate< -0.05 and theme.red
            or (rate>0.05 and theme.turquoise or theme.muted)
    end
    lastStam=row.stam
    lastTime=row.t
    if #samples<MAX_SAMPLES then table.insert(samples,row) end
    return row
end

local function remoteTotal()
    local total=0
    for _,r in ipairs(remoteList) do total=total+r.count end
    return total
end
local function render(row)
    if not gui.Parent then return end
    stamText.Text=fmt(row.stam).." / "..fmt(row.maximum)
    local fraction=0
    if row.stam and row.maximum and row.maximum>0 then
        fraction=math.clamp(row.stam/row.maximum,0,1)
    end
    fill.Size=UDim2.fromScale(fraction,1)
    fill.BackgroundColor3=row.exhausted==true and theme.red or theme.turquoise
    modeText.Text="Movement: "..row.mode
    statsText.Text="Health "..fmt(row.health).."  •  Speed "..fmt(row.speed)..
        "  •  Ping "..(row.ping and fmt(row.ping*1000).."ms" or "—")
    remoteText.Text="RemoteEvents visible: "..#remoteList.."   •   inbound signals: "..remoteTotal()
    changeText.Text="State events: "..#events.."   •   health events: "..healthEvents..
        "   •   notable drains: "..anomalousDrops
    progress.Size=UDim2.fromScale(math.clamp(row.t/DURATION,0,1),1)
end

local function buildReport(full)
    local rows={
        "=== FERAL REPLICATION & STAMINA LAB v1.5 ===",
        "Passive client-visible diagnostic; no game state or remote calls modified",
        "Place ID: "..game.PlaceId,
        "Animal: Tiger (user report)",
        "Elapsed: "..fmt(#samples>0 and samples[#samples].t or 0).."s",
        "Samples: "..#samples.." ; interval approximately "..SAMPLE_INTERVAL.."s",
        "Humanoid health events: "..healthEvents,
        "Large stamina drops (>2.6 points per sample): "..anomalousDrops,
        "Client ping estimate: uses Player:GetNetworkPing() when available.",
        "SERVER LIMIT: Private ServerScriptService, ServerStorage, server-only counters,",
        "anticheat rules and validation decisions are NOT accessible via passive client scanning.",
        "RemoteEvents listed below were discovered locally; incoming event counts do NOT",
        "establish that any particular stamina calculation is server-authoritative.",
        reportTruncated and "WARNING: event log capped" or "",
        remoteTruncated and "WARNING: remote watcher limit reached" or "",
        replicationTruncated and "WARNING: replicated-object inventory limit reached" or "",
        "",
        "=== MODE STAMINA RATES (BASED ON EXPLICIT FLAGS) ==="
    }
    local stats,order={},{}
    for i=2,#samples do
        local a,b=samples[i-1],samples[i]
        local dt=b.t-a.t
        if a.mode==b.mode and a.stam~=nil and b.stam~=nil and dt>0 and dt<1 then
            if not stats[b.mode] then
                stats[b.mode]={time=0,spent=0,gained=0,count=0}
                table.insert(order,b.mode)
            end
            local st=stats[b.mode]
            st.time=st.time+dt
            st.count=st.count+1
            local diff=b.stam-a.stam
            if diff>=0 then st.gained=st.gained+diff
            else st.spent=st.spent-diff end
        end
    end
    for _,mode in ipairs(order) do
        local st=stats[mode]
        table.insert(rows,string.format(
            "%s | %.1fs / %d intervals | spent %.2f (%.2f/s) | gained %.2f (%.2f/s)",
            mode,st.time,st.count,st.spent,st.time>0 and st.spent/st.time or 0,
            st.gained,st.time>0 and st.gained/st.time or 0))
    end
    table.insert(rows,"")
    table.insert(rows,"=== CLIENT-VISIBLE MOVEMENT/HEALTH STATE ATTRIBUTES ===")
    local keys={}
    for key in pairs(seenAttributes) do table.insert(keys,key) end
    table.sort(keys)
    for _,key in ipairs(keys) do
        table.insert(rows,key.." = "..seenAttributes[key])
    end
    table.insert(rows,"")
    table.insert(rows,"=== REPLICATED STORAGE RELEVANT VALUES / FOLDERS ===")
    local valueKeys={}
    for key in pairs(seenReplicatedValues) do table.insert(valueKeys,key) end
    table.sort(valueKeys)
    for _,key in ipairs(valueKeys) do
        table.insert(rows,key.." = "..seenReplicatedValues[key])
    end
    table.insert(rows,"")
    table.insert(rows,"=== OBSERVED INBOUND REMOTE EVENTS (NO PAYLOADS CAPTURED) ===")
    local withSignals={}
    for _,remote in ipairs(remoteList) do
        if remote.count>0 then table.insert(withSignals,remote) end
    end
    table.sort(withSignals,function(a,b) return a.count>b.count end)
    if #withSignals==0 then table.insert(rows,"No inbound RemoteEvent signals observed during scan") end
    for _,remote in ipairs(withSignals) do
        table.insert(rows,string.format("%s | %d signals | first %.2fs | last %.2fs",
            remote.name,remote.count,remote.first,remote.last))
    end
    table.insert(rows,"Discovered "..#remoteList.." RemoteEvents overall, including those with no inbound events.")
    if full then
        table.insert(rows,"=== ALL REMOTE NAMES DISCOVERED ===")
        for _,remote in ipairs(remoteList) do
            table.insert(rows,remote.name.." | inbound="..remote.count)
        end
    end
    table.insert(rows,"")
    table.insert(rows,"=== TIMESTAMPED ENFORCEMENT / MOVEMENT EVENTS ===")
    for _,entry in ipairs(events) do table.insert(rows,entry) end
    if full then
        table.insert(rows,"")
        table.insert(rows,"=== FULL 0.25s SAMPLE SERIES ===")
        table.insert(rows,"t | mode | stamina | max | exhausted | sprint | burst | trot | crouch | health | speed | walkSpeed | humanoidState | pingMs")
        for _,row in ipairs(samples) do
            table.insert(rows,string.format(
                "%.2f | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s",
                row.t,row.mode,fmt(row.stam),fmt(row.maximum),
                fmt(row.exhausted),fmt(row.sprint),fmt(row.burst),fmt(row.trot),
                fmt(row.crouch),fmt(row.health),fmt(row.speed),
                fmt(row.walkspeed),row.state,row.ping and fmt(row.ping*1000) or "-"))
        end
    end
    table.insert(rows,"")
    table.insert(rows,"=== END ===")
    return table.concat(rows,"\n")
end

local function setStatus(message)
    if gui.Parent then status.Text=message end
end
local function finish()
    if not running then return end
    running=false
    stopNow=false
    clear(remoteConnections)
    clear(characterConnections)
    lastSummary=buildReport(false)
    lastFull=buildReport(true)
    reportBox.Text=lastSummary
    start.Text="Start new scan"
    setStatus("Ready: "..#samples.." samples, "..remoteTotal().." incoming signals. Copy summary or full.")
end
local function clipboardCopy(report)
    if report=="" then
        setStatus("No report yet. Press Start.")
        return
    end
    local fn=type(setclipboard)=="function" and setclipboard
        or (type(toclipboard)=="function" and toclipboard or nil)
    if fn then
        local ok=pcall(fn,report)
        if ok then
            setStatus("Copied to clipboard. Paste in the chat.")
            return
        end
    end
    reportBox.Text=report
    reportBox:CaptureFocus()
    setStatus("Copy unavailable. Select report text, then Ctrl+A / Ctrl+C.")
end
start.Activated:Connect(function()
    if running then setStatus("Scan already active.");return end
    clear(remoteConnections)
    clear(characterConnections)
    remoteList,remoteByObject={},{ }
    seenAttributes,seenReplicatedValues={},{ }
    samples,events={},{ }
    reportTruncated,replicationTruncated,remoteTruncated=false,false,false
    lastSummary,lastFull="",""
    healthEvents,anomalousDrops=0,0
    replicationCount,scanCount=0,0
    lastTime,lastStam=nil,nil
    lastObservedMode="Unknown"
    boundCharacter,boundHumanoid=nil,nil
    begun=os.clock()
    running=true
    stopNow=false
    start.Text="Scanning..."
    reportBox.Text="Scanning client-visible state and inbound RemoteEvent counts..."
    log("Scan started | "..snapshot())
    scanVisibleAttributes()
    scanReplicatedStorage()
    scanRemotes()
    bindCharacter()
    setStatus("120s scan active. Use sprint, burst, trot, crawl, and normal movement.")
end)
stop.Activated:Connect(function()
    if running then stopNow=true
    else setStatus("No active scan.") end
end)
copySummary.Activated:Connect(function()
    clipboardCopy(running and buildReport(false) or lastSummary)
end)
copyFull.Activated:Connect(function()
    clipboardCopy(running and buildReport(true) or lastFull)
end)
close.Activated:Connect(function()
    stopNow=true
    gui:Destroy()
end)
for _,key in ipairs({"HudSprint","HudBurst","HudTrot"}) do
    own(player:GetAttributeChangedSignal(key):Connect(function()
        if running then
            log("PLAYER ATTRIBUTE "..key.."="..fmt(player:GetAttribute(key)).." | "..snapshot())
        end
    end))
end
gui.Destroying:Connect(function()
    running=false
    clear(remoteConnections)
    clear(characterConnections)
    clear(connections)
end)

task.spawn(function()
    while gui.Parent do
        local ok,err=pcall(function()
            if running then
                bindCharacter()
                local row=readSample()
                scanCount=scanCount+1
                render(row)
                if scanCount%8==0 then scanVisibleAttributes() end
                if scanCount%40==0 then
                    scanRemotes()
                    scanReplicatedStorage()
                end
                if scanCount%8==0 then
                    setStatus(string.format("%.1f/%ds  •  %d samples  •  %s",
                        row.t,DURATION,#samples,row.mode))
                end
                if row.t>=DURATION or stopNow or #samples>=MAX_SAMPLES then
                    finish()
                end
            end
        end)
        if not ok then setStatus("Diagnostic warning: "..string.sub(tostring(err),1,140)) end
        task.wait(SAMPLE_INTERVAL)
    end
end)
