-- THE PHONE NOVA HUB v1.0.0 | client-side live companion
-- Grounded in Nov 23, 2026 LOBBY and MATCH offline reconstructions.
-- Read-only telemetry, optional local phone locator, guidance and snapshots.
-- No FireServer/InvokeServer calls, automation of gameplay or secret scanning.
local VERSION="1.0.0"
local EXPECTED_UNIVERSE=10775041696
local LOBBY_PLACE=138199295184592
local MATCH_PLACE=120688878033226
if game.GameId~=EXPECTED_UNIVERSE and game.PlaceId~=LOBBY_PLACE and game.PlaceId~=MATCH_PLACE then
    warn("[THE PHONE NOVA] This script only supports THE PHONE experience.")
    return
end
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local player=Players.LocalPlayer
if not player then warn("[THE PHONE NOVA] LocalPlayer unavailable");return end
local playerGui=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",10)
if not playerGui then warn("[THE PHONE NOVA] PlayerGui unavailable");return end
local env=nil
pcall(function()if type(getgenv)=="function" then env=getgenv() end end)
if type(env)=="table" and type(env.THE_PHONE_NOVA_HUB_V1)=="table" then
    pcall(function()env.THE_PHONE_NOVA_HUB_V1.stop()end)
end
local previous=playerGui:FindFirstChild("ThePhoneNovaHubV1")
if previous then pcall(function()previous:Destroy()end)end

local C={
    bg=Color3.fromRGB(13,21,33),panel=Color3.fromRGB(21,32,48),
    dim=Color3.fromRGB(34,49,69),edge=Color3.fromRGB(56,78,102),
    text=Color3.fromRGB(231,241,251),muted=Color3.fromRGB(156,178,202),
    mint=Color3.fromRGB(68,218,175),sky=Color3.fromRGB(77,176,249),
    gold=Color3.fromRGB(249,196,94),red=Color3.fromRGB(236,99,115)
}
local state={
    alive=true,enabled=true,minimized=false,tab="OVERVIEW",
    notify=true,beacon=false,compact=false,
    place=(game.PlaceId==LOBBY_PLACE and "LOBBY") or
        (game.PlaceId==MATCH_PLACE and "MATCH") or "OTHER",
    lines={},logDirty=true,lastEvent="",lastPhase="",lastMap="",lastStatus="READY",
    lastSnapshot=nil,localEventAt=0,noticeUntil=0,noticeText="",
    beaconGui=nil,beaconPart=nil,connections={}
}
local function connect(signal,fn)
    local c=signal:Connect(fn)
    state.connections[#state.connections+1]=c
    return c
end
local function attr(obj,key,default)
    if not obj then return default end
    local ok,v=pcall(function()return obj:GetAttribute(key)end)
    if not ok or v==nil then return default end
    return v
end
local function textVal(v)
    if v==nil then return "--" end
    if type(v)=="boolean" then return v and "YES" or "NO" end
    return tostring(v)
end
local function addLog(message)
    local stamp=os.date("!%H:%M:%S")
    table.insert(state.lines,1,stamp.."  "..tostring(message))
    while #state.lines>22 do table.remove(state.lines)end
    state.logDirty=true
end
local function toast(message)
    state.noticeText=message
    state.noticeUntil=os.clock()+5
    addLog(message)
end
local function create(class,props,parent)
    local obj=Instance.new(class)
    for key,value in pairs(props) do
        pcall(function()obj[key]=value end)
    end
    obj.Parent=parent
    return obj
end
local function round(parent,rad)
    create("UICorner",{CornerRadius=UDim.new(0,rad or 8)},parent)
end
local function stroke(parent,color,transparency)
    create("UIStroke",{Color=color or C.edge,Thickness=1,Transparency=transparency or 0},parent)
end
local function label(parent,txt,x,y,w,h,sz,color,bold)
    return create("TextLabel",{
        Text=txt,BackgroundTransparency=1,TextColor3=color or C.text,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=sz or 12,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,
        TextWrapped=true,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h)
    },parent)
end
local function button(parent,txt,x,y,w,h,color)
    local b=create("TextButton",{
        Text=txt,AutoButtonColor=true,BorderSizePixel=0,
        BackgroundColor3=color or C.dim,TextColor3=C.text,
        Font=Enum.Font.GothamBold,TextSize=11,
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h)
    },parent)
    round(b,7)
    return b
end
local gui=create("ScreenGui",{
    Name="ThePhoneNovaHubV1",ResetOnSpawn=false,
    IgnoreGuiInset=true,DisplayOrder=810,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling
},playerGui)
local panel=create("Frame",{
    Name="Main",Size=UDim2.fromOffset(476,502),
    Position=UDim2.new(0,18,0.16,0),BackgroundColor3=C.bg,
    BorderSizePixel=0,Active=true
},gui)
round(panel,12)
stroke(panel,C.edge,0.25)
local scale=create("UIScale",{Scale=1},panel)
local function fitScale()
    local cam=workspace.CurrentCamera
    if not cam then return end
    scale.Scale=math.clamp(math.min(
        (cam.ViewportSize.X-22)/500,(cam.ViewportSize.Y-50)/550
    ),0.63,1)
end
fitScale()
local top=create("Frame",{
    Name="DragBar",Size=UDim2.new(1,0,0,58),BorderSizePixel=0,
    BackgroundColor3=C.panel,Active=true
},panel)
round(top,12)
create("Frame",{
    BackgroundColor3=C.panel,BorderSizePixel=0,
    Position=UDim2.fromOffset(0,38),Size=UDim2.new(1,0,0,20)
},top)
label(top,"T H E   P H O N E    N O V A",16,8,280,21,15,C.text,true)
label(top,"CLIENT COMPANION  •  v"..VERSION,16,30,270,13,10,C.muted)
local minBtn=button(top,"—",380,12,34,32,C.dim)
local hideBtn=button(top,"×",422,12,36,32,Color3.fromRGB(103,48,68))
local body=create("Frame",{
    Name="Body",BackgroundTransparency=1,Position=UDim2.fromOffset(0,58),
    Size=UDim2.new(1,0,1,-58)
},panel)
local modePill=create("Frame",{
    Position=UDim2.fromOffset(14,10),Size=UDim2.fromOffset(448,37),
    BackgroundColor3=C.panel,BorderSizePixel=0
},body)
round(modePill,7)
local modeText=label(modePill,"SCANNING LIVE STATE...",13,2,423,32,11,C.mint,true)

local tabs={"OVERVIEW","EVENTS","TOOLS","LOG"}
local pages={}
for i,name in ipairs(tabs) do
    local b=button(body,name,14+(i-1)*113,56,109,32,C.dim)
    b.Name="Tab"..name
    local page=create("Frame",{
        Name=name,BackgroundTransparency=1,Visible=name=="OVERVIEW",
        Position=UDim2.fromOffset(14,95),Size=UDim2.fromOffset(448,282)
    },body)
    pages[name]={tab=b,page=page}
end
local bottom=create("Frame",{
    BackgroundColor3=C.panel,BorderSizePixel=0,
    Position=UDim2.fromOffset(14,388),Size=UDim2.fromOffset(448,38)
},body)
round(bottom,7)
local foot=label(bottom,"RIGHT SHIFT • hide/show   |   local client companion",10,3,427,30,10,C.muted)

-- Overview page: only replicated attributes documented by captured scripts.
local p=pages.OVERVIEW.page
local function boxLine(y,header)
    local c=create("Frame",{
        Position=UDim2.fromOffset(0,y),Size=UDim2.fromOffset(448,58),
        BackgroundColor3=C.panel,BorderSizePixel=0
    },p)
    round(c,8)
    label(c,header,12,6,420,17,10,C.muted,true)
    local v=label(c,"--",12,25,420,27,14,C.text,true)
    return v
end
local currentEvent=boxLine(0,"ACTIVE CHALLENGE")
local currentPhase=boxLine(65,"ROUND / MAP")
local currentTimer=boxLine(130,"CLOCK / PHONE")
local currentPlayer=boxLine(195,"PLAYER STATUS")
local note=label(p,"Replicated attributes are observed, not server authority.",5,260,437,19,10,C.muted)

-- Event guide: decisions are reminders from client code, not win guarantees.
local guides={
    {pattern="pass the bomb",name="PASS THE BOMB",tip="Watch for the holder and fuse. BombTap is a server request: visible taps are not proof of a successful pass."},
    {pattern="bomb",name="BOMB EVENT",tip="Keep the bomb-holder changes in view. The game controls the timer and accepted transfers."},
    {pattern="thin ice",name="THIN ICE",tip="Client code restricts left/right controls during this challenge. Watch the balancing prompt rather than forcing movement."},
    {pattern="escape",name="ESCAPE",tip="When the escape prompt is active, SPACE/Button A/R2 sends escape taps. Timing and outcome remain server-controlled."},
    {pattern="undertow",name="UNDERTOW",tip="The EscapeClient handles this as an escape variant. Focus on the game's on-screen mash prompt."},
    {pattern="underice",name="UNDER ICE",tip="This is an EscapeClient variant. Use the live escape prompt and watch oxygen or survival feedback."},
    {pattern="centipede",name="CENTIPEDE",tip="EscapeClient contains a distinct Centipede effect. Use the escape input prompt when grabbed."},
    {pattern="quick draw",name="QUICK DRAW",tip="Listen for the bell and act on the game's actual signal, not an assumed countdown."},
    {pattern="wrong number",name="WRONG NUMBER",tip="This event has separate reveal, launch and revenge sequences. Observe the phase before choosing an action."},
    {pattern="hell",name="HELLFIRE",tip="Hellfire includes voting and choices. The displayed choice is submitted to the server; the UI alone does not determine results."},
    {pattern="last call",name="LAST CALL",tip="Last Call includes split/steal decisions and round-end feedback. Don't infer other players' choices from local UI."},
    {pattern="roulette",name="ROULETTE",tip="Watch the official selection UI; the underlying outcome is not predicted by this hub."},
    {pattern="shark",name="SHARK",tip="Track event timing and visible hazards; this hub does not predict hidden attacks."},
    {pattern="flash freeze",name="FLASH FREEZE",tip="Use the event's visible freeze cues; the client effect alone cannot tell us server acceptance."},
    {pattern="moon",name="MOON EVENT",tip="Movement or gravity may change here. Observe the current event before committing to a jump."},
    {pattern="number",name="NUMBER CHALLENGE",tip="NumberPick submits a choice. Confirm which options the game actually presents."},
    {pattern="dread",name="DREAD",tip="Watch the event HUD and environmental cues. No validated prediction is available."},
    {pattern="ghost",name="GHOST EVENT",tip="GhostVote and other event remotes are present; a displayed vote is not a guaranteed outcome."}
}
local eventPage=pages.EVENTS.page
local eventTitle=label(eventPage,"WAITING FOR EVENT",8,7,432,34,18,C.mint,true)
local tipFrame=create("Frame",{
    Position=UDim2.fromOffset(0,46),Size=UDim2.fromOffset(448,124),
    BackgroundColor3=C.panel,BorderSizePixel=0
},eventPage)
round(tipFrame,8)
local tipLabel=label(tipFrame,"Monitoring workspace.EventName and EventActive.",13,12,424,101,13,C.text)
local eventData=label(eventPage,"",7,182,434,65,12,C.muted)
local eventNotice=label(eventPage,"Detection uses replicated state, not remote interception.",7,253,435,22,10,C.muted)
local function getGuide(event)
    local search=tostring(event or ""):lower()
    for _,guide in ipairs(guides) do
        if search:find(guide.pattern,1,true) then return guide end
    end
    return nil
end

-- Tools page: explicit toggles; no gameplay or network manipulation.
local toolsPage=pages.TOOLS.page
local function toolRow(y,title,desc,key)
    local row=create("Frame",{
        Position=UDim2.fromOffset(0,y),Size=UDim2.fromOffset(448,62),
        BackgroundColor3=C.panel,BorderSizePixel=0
    },toolsPage)
    round(row,8)
    label(row,title,11,5,304,24,12,C.text,true)
    label(row,desc,11,29,310,25,10,C.muted)
    local b=button(row,"ON",354,15,78,31,C.dim)
    local function update()
        b.Text=state[key] and "ON" or "OFF"
        b.BackgroundColor3=state[key] and Color3.fromRGB(26,105,89) or C.dim
    end
    connect(b.Activated,function()
        state[key]=not state[key]
        update()
        addLog(title..(state[key] and " enabled" or " disabled"))
    end)
    update()
    return b
end
toolRow(0,"Event notifications","Short notice when the active event changes.","notify")
toolRow(68,"Phone locator","Show distance to the replicated in-game phone.","beacon")
toolRow(136,"Compact event HUD","Keep event and countdown visible above panel.","compact")
local snapshotBtn=button(toolsPage,"COPY LIVE SNAPSHOT",0,212,212,37,Color3.fromRGB(32,97,137))
local refreshBtn=button(toolsPage,"REFRESH NOW",223,212,225,37,C.dim)
local toolsInfo=label(toolsPage,
    "No remote firing. No automatic inputs. No changes to player stats.",5,256,440,24,10,C.muted)

-- Event log: scroll with compact entries; no names, chat or personal data.
local logPage=pages.LOG.page
local scroll=create("ScrollingFrame",{
    Name="RecentEvents",Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(448,238),
    ScrollBarThickness=4,ScrollBarImageColor3=C.sky,
    BackgroundColor3=C.panel,BorderSizePixel=0,
    CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.None
},logPage)
round(scroll,8)
local logBody=create("Frame",{
    BackgroundTransparency=1,Size=UDim2.fromOffset(431,0)
},scroll)
local copyLog=button(logPage,"COPY SESSION EVENTS",0,248,217,32,C.dim)
local clearLog=button(logPage,"CLEAR LOG",226,248,222,32,C.dim)
local function updateLog()
    if not state.logDirty then return end
    state.logDirty=false
    for _,child in ipairs(logBody:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    local lineHeight=25
    for i,str in ipairs(state.lines) do
        label(logBody,str,9,(i-1)*lineHeight,418,lineHeight,11,C.text)
    end
    local h=#state.lines*lineHeight
    logBody.Size=UDim2.fromOffset(431,h)
    scroll.CanvasSize=UDim2.fromOffset(0,h)
end
connect(copyLog.Activated,function()
    local cb=nil
    pcall(function()if type(setclipboard)=="function" then cb=setclipboard end end)
    if cb then
        local ok=pcall(cb,table.concat(state.lines,"\n"))
        toast(ok and "Session event log copied" or "Clipboard unavailable")
    else toast("Clipboard API unavailable")end
end)
connect(clearLog.Activated,function()state.lines={};addLog("Session history cleared");updateLog()end)

local eventHUD=create("Frame",{
    Name="CompactEvent",Visible=false,
    Position=UDim2.new(0.5,-210,0,17),Size=UDim2.fromOffset(420,45),
    BorderSizePixel=0,BackgroundColor3=C.bg
},gui)
round(eventHUD,9)
stroke(eventHUD,C.edge,0.3)
local eventHUDLabel=label(eventHUD,"THE PHONE • monitoring event",12,4,400,37,13,C.text,true)
local noticeBar=create("Frame",{
    Name="Notice",Visible=false,
    Position=UDim2.new(0.5,-195,0,71),Size=UDim2.fromOffset(390,38),
    BackgroundColor3=C.panel,BorderSizePixel=0
},gui)
round(noticeBar,8)
local noticeLabel=label(noticeBar,"",10,3,370,31,12,C.mint,true)
local function changeTab(name)
    state.tab=name
    for key,rec in pairs(pages) do
        rec.page.Visible=key==name
        rec.tab.BackgroundColor3=key==name and Color3.fromRGB(31,96,120) or C.dim
    end
    if name=="LOG" then state.logDirty=true;updateLog()end
end
for name,rec in pairs(pages) do connect(rec.tab.Activated,function()changeTab(name)end)end
changeTab("OVERVIEW")
local function visible(on)
    state.enabled=on
    gui.Enabled=on
    if not on and state.beaconGui then state.beaconGui.Enabled=false end
end
connect(hideBtn.Activated,function()visible(false)end)
connect(minBtn.Activated,function()
    state.minimized=not state.minimized
    body.Visible=not state.minimized
    panel.Size=UDim2.fromOffset(476,state.minimized and 58 or 502)
    minBtn.Text=state.minimized and "+" or "—"
end)
connect(UIS.InputBegan,function(input,processed)
    if input.KeyCode==Enum.KeyCode.RightShift and not UIS:GetFocusedTextBox() then
        visible(not state.enabled)
    end
end)
local dragging=false
local dragStart=nil
local startPos=nil
connect(top.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or
       input.UserInputType==Enum.UserInputType.Touch then
        dragging=true;dragStart=input.Position;startPos=panel.Position
    end
end)
connect(UIS.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or
       input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
connect(UIS.InputChanged,function(input)
    if not dragging or not dragStart or not startPos then return end
    if input.UserInputType~=Enum.UserInputType.MouseMovement and
       input.UserInputType~=Enum.UserInputType.Touch then return end
    local delta=input.Position-dragStart
    panel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,
        startPos.Y.Scale,startPos.Y.Offset+delta.Y)
end)
local function snapshot()
    local matchState=RS:FindFirstChild("MatchState")
    local char=player.Character
    local eventName=attr(workspace,"EventName","")
    local endTime=attr(matchState,"EndsAt",nil)
    local secs=nil
    if type(endTime)=="number" then
        local ok,now=pcall(function()return workspace:GetServerTimeNow()end)
        if ok then secs=math.max(0,math.floor(endTime-now)) end
    end
    return {
        tool="the-phone-nova-hub",version=VERSION,
        universe_id=game.GameId,place_id=game.PlaceId,
        place_version=game.PlaceVersion,mode=state.place,
        phase=attr(matchState,"Phase",""),
        map=attr(workspace,"CurrentMap",""),
        event=eventName,event_active=attr(workspace,"EventActive",false),
        countdown_seconds=secs,
        phone_locked=attr(player,"PhoneLocked",false),
        afk=attr(player,"AFK",false),
        in_booth=attr(player,"InBooth",""),
        server_walkspeed=attr(char,"ServerWalkSpeed",nil),
        released=attr(char,"Released",nil),
        dying=attr(char,"Dying",nil),
        client_inventory_only=true,server_authority_unverified=true,
        no_gameplay_remotes_called=true
    }
end
connect(snapshotBtn.Activated,function()
    local data=snapshot()
    local ok,s=pcall(function()return Http:JSONEncode(data)end)
    if not ok then toast("Snapshot encoding failed");return end
    state.lastSnapshot=s
    local cb=nil
    pcall(function()if type(setclipboard)=="function" then cb=setclipboard end end)
    if cb then
        local pasted=pcall(cb,s)
        toast(pasted and "Live snapshot copied to clipboard" or "Clipboard failed; snapshot in registry")
    else toast("Snapshot stored in registry; clipboard unavailable")end
end)
connect(refreshBtn.Activated,function()
    toast("Refresh requested; reading live client state")
end)
local function clearBeacon()
    if state.beaconGui then pcall(function()state.beaconGui:Destroy()end)end
    state.beaconGui=nil
    state.beaconPart=nil
end
local function locatePhone()
    local root=workspace:FindFirstChild("Game")
    local phone=root and root:FindFirstChild("ThePhone")
    if not phone then return nil end
    return phone:FindFirstChild("Base") or phone:FindFirstChild("Handset")
end
local function updateBeacon()
    if not state.beacon or not state.enabled or state.place~="MATCH" then
        if state.beaconGui then state.beaconGui.Enabled=false end
        return
    end
    local obj=locatePhone()
    if not obj or not obj:IsA("BasePart") then clearBeacon();return end
    if state.beaconPart~=obj then
        clearBeacon()
        state.beaconPart=obj
        state.beaconGui=create("BillboardGui",{
            Name="ThePhoneNovaPhoneMarker",
            Adornee=obj,AlwaysOnTop=true,Size=UDim2.fromOffset(160,43),
            StudsOffsetWorldSpace=Vector3.new(0,3,0),
            Enabled=true,MaxDistance=500
        },playerGui)
        local text=label(state.beaconGui,"PHONE",0,0,160,43,13,C.mint,true)
        text.Name="MarkerText"
        text.TextXAlignment=Enum.TextXAlignment.Center
        text.BackgroundColor3=C.bg
        text.BackgroundTransparency=0.23
        round(text,8)
    end
    if state.beaconGui then
        state.beaconGui.Enabled=true
        local hrp=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local distance=hrp and math.floor((hrp.Position-obj.Position).Magnitude) or nil
        local marker=state.beaconGui:FindFirstChild("MarkerText")
        if marker then marker.Text="PHONE  •  "..(distance and tostring(distance).." studs" or "--") end
    end
end
local function tick()
    local matchState=RS:FindFirstChild("MatchState")
    local phase=tostring(attr(matchState,"Phase",state.place=="LOBBY" and "Lobby" or "Unknown"))
    local map=tostring(attr(workspace,"CurrentMap","--"))
    local event=tostring(attr(workspace,"EventName",""))
    local active=attr(workspace,"EventActive",false)==true
    local displayEvent=active and event or ""
    local eventLabel=displayEvent~="" and displayEvent or "No active challenge detected"
    if displayEvent~=state.lastEvent then
        local before=state.lastEvent
        state.lastEvent=displayEvent
        if displayEvent~="" then
            state.localEventAt=os.clock()
            if state.notify then toast("EVENT: "..displayEvent) else addLog("Event: "..displayEvent)end
        elseif before~="" then addLog("Challenge cleared: "..before) end
    end
    if phase~=state.lastPhase then
        state.lastPhase=phase
        addLog("Round phase: "..phase)
    end
    if map~=state.lastMap then
        state.lastMap=map
        if map~="--" then addLog("Map: "..map) end
    end
    local seconds=nil
    local endTime=attr(matchState,"EndsAt",nil)
    if type(endTime)=="number" then
        local ok,now=pcall(function()return workspace:GetServerTimeNow()end)
        if ok then seconds=math.max(0,math.floor(endTime-now+0.5))end
    end
    local char=player.Character
    local speed=attr(char,"ServerWalkSpeed",nil)
    local locked=attr(player,"PhoneLocked",false)==true
    local afk=attr(player,"AFK",false)==true
    local holder=attr(player,"InBooth","")
    modeText.Text=state.place.."  •  "..phase.."  •  "..(active and "EVENT LIVE" or "MONITORING")
    modeText.TextColor3=active and C.mint or C.sky
    currentEvent.Text=eventLabel..(active and "  • LIVE" or "")
    currentEvent.TextColor3=active and C.mint or C.text
    currentPhase.Text=phase.."  |  "..map
    currentTimer.Text=(seconds and tostring(seconds).."s remaining" or "No phase timer")..
        "  |  Phone "..(locked and "LOCKED" or "FREE")
    currentPlayer.Text=(afk and "AFK" or "ACTIVE")..
        "  |  Speed: "..textVal(speed)..
        (holder~="" and "  |  Booth" or "")
    local guide=getGuide(displayEvent)
    eventTitle.Text=guide and guide.name or (active and eventLabel:upper() or "NO EVENT")
    tipLabel.Text=guide and guide.tip or
        (active and "This challenge is detected, but no verified event-specific helper is configured yet."
            or "Waiting for the next challenge. The hub observes live event attributes without intercepting game remotes.")
    eventData.Text="Match phase: "..phase..
        "\nMap: "..map..
        "\nEventActive: "..textVal(active)..
        (seconds and ("   |   Vote timer: "..tostring(seconds).."s") or "")
    eventHUD.Visible=state.compact and state.enabled
    eventHUDLabel.Text=(active and eventLabel or phase)..
        (seconds and "  •  "..tostring(seconds).."s" or "")..
        (locked and "  •  PHONE LOCKED" or "")
    noticeBar.Visible=state.enabled and state.noticeUntil>os.clock()
    noticeLabel.Text=state.noticeText
    foot.Text=state.place.." • "..(state.enabled and "RIGHT SHIFT hide/show" or "")..
        " • read-only client telemetry"
    if state.tab=="LOG" then updateLog() end
end
local function stop()
    if not state.alive then return end
    state.alive=false
    for _,connection in ipairs(state.connections) do
        pcall(function()connection:Disconnect()end)
    end
    state.connections={}
    clearBeacon()
    if gui then pcall(function()gui:Destroy()end)end
    if type(env)=="table" and env.THE_PHONE_NOVA_HUB_V1==state.api then
        env.THE_PHONE_NOVA_HUB_V1=nil
    end
end
state.api={stop=stop,version=VERSION,snapshot=snapshot}
if type(env)=="table" then env.THE_PHONE_NOVA_HUB_V1=state.api end
connect(gui.Destroying,function()
    if state.alive then stop()end
end)
addLog("Hub loaded in "..state.place.." place")
if state.place=="LOBBY" then addLog("Lobby features: booths, daily rewards, voting prep")
else addLog("Match features: event/round state, challenge hints")end
local frame=workspace.CurrentCamera
if frame then
    connect(frame:GetPropertyChangedSignal("ViewportSize"),fitScale)
end
task.spawn(function()
    while state.alive do
        local ok,err=pcall(tick)
        if not ok then state.lastStatus=tostring(err);warn("[THE PHONE NOVA] HUD refresh: "..tostring(err))end
        pcall(updateBeacon)
        task.wait(0.35)
    end
end)
warn("[THE PHONE NOVA] v"..VERSION.." ready | "..state.place..
    " | RightShift toggles all UI | No gameplay remotes called")
