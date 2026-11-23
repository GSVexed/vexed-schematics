--[[
 THE PHONE NOVA V2.0 | PRIVATE-RESEARCH-BASED PLAYER HUB
 Source basis: THE PHONE lobby+match captured 2026-11-23, offline-recovered Luau.
 Features target client-visible inputs and mechanics; server acceptance not guaranteed.
 No admin/coin/revive bypass, remote fuzzing, teleportation, or data exfiltration.
 Toggle: RightShift. The red X hides the hub without removing automation.
]]
local VERSION="2.0.0"
local UNIVERSE=10775041696
local LOBBY=138199295184592
local MATCH=120688878033226
if game.GameId~=UNIVERSE and game.PlaceId~=LOBBY and game.PlaceId~=MATCH then
    warn("[PHONE NOVA] Wrong Roblox experience; refusing to load")
    return
end

local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local Http=game:GetService("HttpService")
local plr=Players.LocalPlayer
if not plr then return end
local pg=plr:FindFirstChildOfClass("PlayerGui") or plr:WaitForChild("PlayerGui",15)
if not pg then return end
local environment=nil
pcall(function() if type(getgenv)=="function" then environment=getgenv() end end)
if type(environment)=="table" then
    for _,key in ipairs({"THE_PHONE_NOVA_HUB_V2","THE_PHONE_NOVA_HUB_V1"}) do
        if type(environment[key])=="table" and type(environment[key].stop)=="function" then
            pcall(environment[key].stop)
        end
    end
end
for _,name in ipairs({"ThePhoneNovaHubV1","ThePhoneNovaHubV2"}) do
    local old=pg:FindFirstChild(name)
    if old then pcall(function()old:Destroy()end)end
end

local SWITCH={
    duel=true,thin=true,escape=true,bomb=true,aim=true,
    moonBoost=true,moonPath=false,takenPath=false,speed=false,miniHud=false
}
local INFO={
    duel={"AUTO QUICK DRAW","Shoot as soon as the game permits it; honours scheduled red light.","COMBAT"},
    bomb={"HOLD-TO-PASS BOMB","Only the eligible person under your held left mouse button.","COMBAT"},
    aim={"SUBTLE AIM ASSIST","Aim near a visible gun target while holding right mouse.","COMBAT"},
    thin={"THIN ICE / NO LOCAL FAIL","Experimental: pauses the local balance-failure simulation.","SURVIVAL"},
    escape={"AUTO ESCAPE / BREAKOUT","Rapid taps only during your own live escape or breakout.","SURVIVAL"},
    takenPath={"TAKEN ROUTE AUTOPILOT","Use map markers; gates/chasm still need live validation.","SURVIVAL"},
    moonBoost={"MOON BOOST SUSTAIN","Experimental: reapply game-provided boost walking speed.","MOVEMENT"},
    moonPath={"MOON RACE AUTORUN","Run to the supplied finish flag; jump past simple obstacles.","MOVEMENT"},
    speed={"PRECISE +3% SPEED","Normal movement only; never override special modes.","MOVEMENT"},
    miniHud={"COMPACT STATUS STRIP","Show current event and automation status while panel is hidden.","TOOLS"}
}
local ORDER={
    COMBAT={"duel","bomb","aim"},
    SURVIVAL={"thin","escape","takenPath"},
    MOVEMENT={"moonBoost","moonPath","speed"},
    TOOLS={"miniHud"}
}
local S={
    alive=true,visible=true,mini=false,tab="COMBAT",enabled=SWITCH,
    mode=(game.PlaceId==LOBBY and "LOBBY" or "MATCH"),
    phase="",event="",eventLive=false,
    connections={},logs={},dirty=true,snapshot=nil,
    counters={duel=0,bomb=0,escape=0,taken=0,thin=0,moon=0,speed=0,aim=0},
    features={},remote={},lastError="",lastStatus="READY",
    duel={allowed=false,redAt=nil,sent=false,armedAt=0,round=0},
    bomb={holding=false,eligible={},sentTo=nil,lastSent=0,startAt=0},
    escape={active=false,variant="",startedAt=0,progress=0,lastTap=0},
    taken={breakout=false,breakStarted=0,breakProgress=0,lastTap=0,pathIndex=1,lastPathAt=0,routeLastDist=math.huge,routeStuckAt=0},
    thin={active=false,lastFreeze=0,starts=0},
    moon={active=false,started=false,cfg=nil,flag=nil,lastMove=0,lastJump=0,lastSpeed=0,routeStuckAt=0},
    tickAt=0,renderAt=0,lastUi=0
}
local function track(signal,cb)
    local c=signal:Connect(cb)
    table.insert(S.connections,c)
    return c
end
local function log(message)
    table.insert(S.logs,1,os.date("!%H:%M:%S").." "..tostring(message))
    while #S.logs>60 do table.remove(S.logs) end
    S.dirty=true
    S.lastStatus=tostring(message)
end
local function guarded(label,fn)
    local ok,err=pcall(fn)
    if not ok then
        local es=tostring(err):sub(1,165)
        if S.lastError~=label..es then
            S.lastError=label..es
            log("ERROR "..label..": "..es)
        end
    end
end
local function getAttr(o,k,default)
    if not o then return default end
    local ok,res=pcall(function()return o:GetAttribute(k)end)
    if ok and res~=nil then return res end
    return default
end
local function timeNow()
    local ok,v=pcall(function()return workspace:GetServerTimeNow()end)
    return ok and v or os.clock()
end
local function character()
    return plr.Character
end
local function humanoid()
    local c=character()
    return c and c:FindFirstChildOfClass("Humanoid"),c
end
local function alive()
    local h=humanoid()
    return h and h.Health>0 and getAttr(plr,"Eliminated",false)~=true
end
local function remote(name)
    return S.remote[name]
end
local function send(name,...)
    local r=remote(name)
    if not (r and r:IsA("RemoteEvent")) then return false end
    local ok=pcall(r.FireServer,r,...)
    if not ok then log(name.." could not submit request")end
    return ok
end
local function actionStatus(name)
    if name=="duel" then
        if S.duel.sent then return "SHOT SENT • server outcome pending" end
        if S.duel.allowed then return "ARMED • waiting for valid red" end
        return "Monitoring duel permission"
    elseif name=="bomb" then
        return S.bomb.holding and "BOMB HELD • hover + hold left click" or "Waiting for bomb holder signal"
    elseif name=="aim" then
        return type(mousemoverel)=="function" and "Hold RIGHT MOUSE near target" or "Target marker only (no cursor API)"
    elseif name=="thin" then
        return S.thin.active and "CLIENT BALANCE SIMULATION PAUSED" or "Waiting for Thin Ice"
    elseif name=="escape" then
        if S.taken.breakout then return "TAKEN BREAKOUT • server progress "..math.floor(S.taken.breakProgress*100).."%"
        end
        return S.escape.active and ("ESCAPE TAPS • "..S.escape.variant) or "Waiting for escape prompt"
    elseif name=="takenPath" then
        return S.taken.routeStuckAt>0 and "Taking route • monitor obstacles" or "Ready for TakenShip markers"
    elseif name=="moonBoost" then
        return S.moon.started and "ACTIVE • game boost speed reassertion" or "Waiting for Moon Race"
    elseif name=="moonPath" then
        return S.moon.started and "Navigating towards supplied finish flag" or "Waiting for Moon Race flag"
    elseif name=="speed" then
        return "Target: 103% of server walking speed • local only"
    elseif name=="miniHud" then return "Optional one-line status strip"
    end
    return ""
end
local P={bg=Color3.fromRGB(12,17,27),panel=Color3.fromRGB(21,29,45),
        field=Color3.fromRGB(27,39,57),line=Color3.fromRGB(54,71,95),
        white=Color3.fromRGB(237,244,255),muted=Color3.fromRGB(156,174,197),
        green=Color3.fromRGB(90,225,177),blue=Color3.fromRGB(110,177,255),
        red=Color3.fromRGB(245,108,132),gold=Color3.fromRGB(246,196,94)}
local function make(class,props,parent)
    local o=Instance.new(class)
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent
    return o
end
local function corners(parent,r)
    make("UICorner",{CornerRadius=UDim.new(0,r or 7)},parent)
end
local function border(parent,c,a)
    make("UIStroke",{Color=c or P.line,Thickness=1,Transparency=a or 0},parent)
end
local function txt(parent,s,x,y,w,h,size,c,bold)
    return make("TextLabel",{Text=tostring(s),BackgroundTransparency=1,
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
        TextColor3=c or P.white,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextWrapped=true,TextSize=size or 12},parent)
end
local function btn(parent,s,x,y,w,h,color)
    local b=make("TextButton",{Text=s,AutoButtonColor=true,BorderSizePixel=0,
        TextColor3=P.white,BackgroundColor3=color or P.field,
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        Font=Enum.Font.GothamBold,TextSize=12},parent)
    corners(b,7)
    return b
end

local ui=make("ScreenGui",{Name="ThePhoneNovaHubV2",ResetOnSpawn=false,
    IgnoreGuiInset=true,DisplayOrder=808,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},pg)
local main=make("Frame",{Name="Panel",Size=UDim2.fromOffset(514,562),
    Position=UDim2.new(0,24,0.13,0),BackgroundColor3=P.bg,
    Active=true,BorderSizePixel=0},ui)
corners(main,13);border(main,P.line,0.05)
local scaler=make("UIScale",{Scale=1},main)
local function rescale()
    local camera=workspace.CurrentCamera
    if camera then
        scaler.Scale=math.clamp(math.min(
            (camera.ViewportSize.X-20)/534,
            (camera.ViewportSize.Y-32)/585),0.65,1)
    end
end
rescale()
local header=make("Frame",{Name="Move",BackgroundColor3=P.panel,
    Size=UDim2.fromOffset(514,68),BorderSizePixel=0,Active=true},main)
corners(header,13)
make("Frame",{Position=UDim2.fromOffset(0,50),
    Size=UDim2.fromOffset(514,18),BorderSizePixel=0,BackgroundColor3=P.panel},header)
txt(header,"THE PHONE  /  NOVA",17,8,285,27,18,P.white,true)
txt(header,"PRECISION HUB    •    "..VERSION.."    •    "..S.mode,18,37,358,17,10,P.muted)
local minButton=btn(header,"—",423,16,36,31)
local hideButton=btn(header,"×",466,16,34,31,Color3.fromRGB(108,48,66))
local content=make("Frame",{Name="Content",BackgroundTransparency=1,
    Position=UDim2.fromOffset(0,68),Size=UDim2.fromOffset(514,494)},main)
local banner=make("Frame",{BackgroundColor3=P.field,
    Position=UDim2.fromOffset(13,11),Size=UDim2.fromOffset(488,43),BorderSizePixel=0},content)
corners(banner,7)
local stateTitle=txt(banner,"NO EVENT DETECTED",12,3,466,21,12,P.green,true)
local stateSub=txt(banner,"Monitoring game state ...",12,23,465,16,10,P.muted)
local tabNames={"COMBAT","SURVIVAL","MOVEMENT","TOOLS"}
local views={}
for idx,name in ipairs(tabNames) do
    local tab=btn(content,name,13+(idx-1)*123,64,119,33,P.field)
    local page=make("Frame",{Name=name,Visible=(idx==1),
        BackgroundTransparency=1,Position=UDim2.fromOffset(13,107),
        Size=UDim2.fromOffset(488,329)},content)
    views[name]={button=tab,page=page}
end
local featureCards={}
local function featureRow(parent,key,y)
    local f=make("Frame",{Size=UDim2.fromOffset(488,82),
        Position=UDim2.fromOffset(0,y),BackgroundColor3=P.panel,BorderSizePixel=0},parent)
    corners(f,8);border(f,P.line,0.5)
    local detail=INFO[key]
    txt(f,detail[1],12,6,362,20,12,P.white,true)
    txt(f,detail[2],12,27,371,29,10,P.muted)
    local status=txt(f,actionStatus(key),12,58,386,17,10,P.blue)
    local toggle=btn(f,"",407,24,66,33,P.field)
    local function refresh()
        local enabled=S.enabled[key]
        toggle.Text=enabled and "ON" or "OFF"
        toggle.BackgroundColor3=enabled and Color3.fromRGB(24,105,90) or P.field
        toggle.TextColor3=enabled and P.green or P.muted
    end
    featureCards[key]={button=toggle,status=status,refresh=refresh}
    track(toggle.Activated,function()
        S.enabled[key]=not S.enabled[key]
        refresh()
        log(detail[1].." "..(S.enabled[key] and "ON" or "OFF"))
        if key=="thin" and S.thin.active and not S.enabled.thin then
            log("Thin Ice: next event restarts game's normal balance controller")
        end
        if key=="takenPath" and not S.enabled[key] then
            S.taken.routeStuckAt=0;S.taken.pathIndex=1
        end
    end)
    refresh()
end
for tab,keys in pairs(ORDER) do
    local page=views[tab].page
    for i,key in ipairs(keys) do featureRow(page,key,(i-1)*89)end
end

local toolsPage=views.TOOLS.page
local extras=make("Frame",{BackgroundColor3=P.panel,BorderSizePixel=0,
    Position=UDim2.fromOffset(0,90),Size=UDim2.fromOffset(488,230)},toolsPage)
corners(extras,8)
local diagBtn=btn(extras,"COPY DIAGNOSTICS",10,12,230,36,Color3.fromRGB(32,89,130))
local stopBtn=btn(extras,"STOP ALL HELPERS",248,12,230,36,Color3.fromRGB(103,47,64))
local logTitle=txt(extras,"SESSION ACTIVITY",12,57,460,20,11,P.muted,true)
local sessionText=txt(extras,"No activity recorded yet.",12,79,462,111,11,P.white)
sessionText.TextYAlignment=Enum.TextYAlignment.Top
local helpText=txt(extras,"Right Shift: hide/reopen  •  X: hide  •  —: minimise",12,195,460,26,11,P.blue)
local footer=make("Frame",{BackgroundColor3=P.panel,BorderSizePixel=0,
    Position=UDim2.fromOffset(13,446),Size=UDim2.fromOffset(488,36)},content)
corners(footer,7)
local footerLabel=txt(footer,"LOCAL ACTIONS • server outcomes not guaranteed",11,5,472,25,10,P.muted)
local strip=make("Frame",{Name="CompactHUD",BackgroundColor3=P.bg,
    Size=UDim2.fromOffset(390,34),Position=UDim2.new(0.5,-195,0,15),
    BorderSizePixel=0,Visible=false},ui)
corners(strip,9);border(strip,P.line,0.2)
local stripLabel=txt(strip,"NOVA  •  ready",12,3,369,28,12,P.green,true)

local function showTab(name)
    S.tab=name
    for k,view in pairs(views) do
        view.page.Visible=(name==k)
        view.button.BackgroundColor3=name==k and Color3.fromRGB(33,99,118) or P.field
    end
end
for name,view in pairs(views) do
    track(view.button.Activated,function()showTab(name)end)
end
showTab("COMBAT")
local function updateVisible()
    main.Visible=S.visible
    strip.Visible=(S.enabled.miniHud and not S.visible)
end
track(hideButton.Activated,function()
    S.visible=false;updateVisible()
end)
track(minButton.Activated,function()
    S.mini=not S.mini
    content.Visible=not S.mini
    main.Size=UDim2.fromOffset(514,S.mini and 68 or 562)
    minButton.Text=S.mini and "+" or "—"
end)
track(UIS.InputBegan,function(input,processed)
    if input.KeyCode==Enum.KeyCode.RightShift and not UIS:GetFocusedTextBox() then
        S.visible=not S.visible
        updateVisible()
    end
end)
local dragging=false
local dragPos,dragStart
track(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or
       input.UserInputType==Enum.UserInputType.Touch then
        dragging=true;dragPos=input.Position;dragStart=main.Position
    end
end)
track(UIS.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or
       input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
track(UIS.InputChanged,function(input)
    if dragging and dragPos and dragStart and
       (input.UserInputType==Enum.UserInputType.MouseMovement or
        input.UserInputType==Enum.UserInputType.Touch) then
        local d=input.Position-dragPos
        main.Position=UDim2.new(dragStart.X.Scale,dragStart.X.Offset+d.X,
                               dragStart.Y.Scale,dragStart.Y.Offset+d.Y)
    end
end)
local aimDot=make("Frame",{Name="AimHint",Size=UDim2.fromOffset(7,7),
    BorderSizePixel=0,BackgroundColor3=P.green,
    Visible=false,AnchorPoint=Vector2.new(0.5,0.5)},ui)
make("UICorner",{CornerRadius=UDim.new(1,0)},aimDot)

local function snapshot()
    local h,c=humanoid()
    local m=RS:FindFirstChild("MatchState")
    return {tool="THE_PHONE_NOVA",version=VERSION,
        universe_id=game.GameId,place_id=game.PlaceId,
        place_version=game.PlaceVersion,phase=getAttr(m,"Phase",""),
        event_name=getAttr(workspace,"EventName",""),
        event_active=getAttr(workspace,"EventActive",false),
        current_map=getAttr(workspace,"CurrentMap",""),
        player={eliminated=getAttr(plr,"Eliminated",false),
                phone_locked=getAttr(plr,"PhoneLocked",false),
                hp=h and h.Health or nil,
                server_walkspeed=getAttr(c,"ServerWalkSpeed",nil)},
        feature_switches=S.enabled,counters=S.counters,
        duel={allowed=S.duel.allowed,red_at=S.duel.redAt,
              sent=S.duel.sent,shot_count=S.counters.duel},
        thin_ice={active=S.thin.active,local_suspensions=S.counters.thin},
        escape={active=S.escape.active,taps=S.counters.escape,variant=S.escape.variant},
        taken={breakout=S.taken.breakout,progress=S.taken.breakProgress,
               taps=S.counters.taken,route_step=S.taken.pathIndex},
        moon_race={active=S.moon.active,racing=S.moon.started,
                   boost_updates=S.counters.moon},
        bomb={holding=S.bomb.holding,passes_requested=S.counters.bomb},
        logs=S.logs,server_outcomes_unverified=true}
end
track(diagBtn.Activated,function()
    local ok,data=pcall(function()return Http:JSONEncode(snapshot())end)
    if not ok then log("Diagnostic encoding failed");return end
    S.snapshot=data
    if type(setclipboard)=="function" then
        local success=pcall(setclipboard,data)
        log(success and "Diagnostics copied" or "Clipboard unavailable; diagnostics in registry")
    else log("Diagnostics stored; clipboard unsupported")end
end)
local function disableAll()
    for k in pairs(S.enabled) do
        if k~="miniHud" then S.enabled[k]=false end
    end
    S.taken.routeStuckAt=0
    for _,card in pairs(featureCards) do card.refresh()end
    log("All gameplay helpers OFF")
end
track(stopBtn.Activated,disableAll)

-- Routes and remote handlers use only client-visible game information.
local function attemptDuel()
    local d=S.duel
    if not (S.enabled.duel and d.allowed and not d.sent and alive()) then return end
    local now=timeNow()
    if d.redAt and now<d.redAt then return end
    if not d.redAt and os.clock()-d.armedAt<0.02 then return end
    d.sent=true -- once per server permission window; never spam
    if send("DuelShoot",now) then
        S.counters.duel+=1
        log("QUICK DRAW: shot request #"..S.counters.duel.." sent at permitted signal")
    else
        d.sent=false
    end
end
local function remotesFind(name)
    local folder=RS:FindFirstChild("Remotes")
    return (folder and folder:FindFirstChild(name)) or RS:FindFirstChild(name)
end
local function attach(name,handler)
    task.spawn(function()
        local t0=os.clock()
        while S.alive and os.clock()-t0<25 do
            local r=remotesFind(name)
            if r and r:IsA("RemoteEvent") then
                S.remote[name]=r
                track(r.OnClientEvent,function(...)
                    guarded(name,function()handler(...)end)
                end)
                return
            end
            task.wait(0.35)
        end
        if S.alive then log("Remote not found: "..name) end
    end)
end
attach("DuelButton",function(allowed)
    local d=S.duel
    if allowed==true then
        d.allowed=true;d.sent=false;d.armedAt=os.clock()
        attemptDuel()
    else
        d.allowed=false;d.sent=false;d.redAt=nil
    end
end)
attach("QuickDrawBell",function(kind,value)
    local d=S.duel
    if kind=="start" then
        d.round+=1;d.redAt=nil;d.sent=false
        log("QUICK DRAW: bell sequence began")
    elseif kind=="redAt" and type(value)=="number" then
        d.redAt=value
        log("QUICK DRAW: server red timestamp acquired")
    elseif kind=="red" then
        d.redAt=timeNow()
        log("QUICK DRAW: red signal observed")
    elseif kind=="end" then
        d.allowed=false;d.redAt=nil
    end
end)

-- Bomb target selection mirrors the game's whitelist and on-screen raycast.
local function eligibleHover()
    local b=S.bomb
    if not b.holding or #b.eligible==0 then return nil end
    local cam=workspace.CurrentCamera
    if not cam then return nil end
    local mp=UIS:GetMouseLocation()
    local inset=GuiService:GetGuiInset()
    local rx=mp.X
    local ry=mp.Y-inset.Y
    if S.visible then
        local a=main.AbsolutePosition
        local sz=main.AbsoluteSize
        if mp.X>=a.X and mp.X<=a.X+sz.X and mp.Y>=a.Y and mp.Y<=a.Y+sz.Y then return nil end
    end
    local ray=cam:ScreenPointToRay(rx,ry)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances=b.eligible
    local hit=workspace:Raycast(ray.Origin,ray.Direction*500,params)
    if hit then
        for _,model in ipairs(b.eligible) do
            if model.Parent and hit.Instance:IsDescendantOf(model) then return model end
        end
    end
    local best,bestD=nil,40
    for _,model in ipairs(b.eligible) do
        if model.Parent then
            for _,nm in ipairs({"Head","UpperTorso","Torso","HumanoidRootPart","Core","Body"}) do
                local part=model:FindFirstChild(nm)
                if part and part:IsA("BasePart") then
                    local pt,shown=cam:WorldToViewportPoint(part.Position)
                    if shown and pt.Z>0 then
                        local dist=(Vector2.new(pt.X,pt.Y)-Vector2.new(rx,ry)).Magnitude
                        if dist<bestD then bestD=dist;best=model end
                    end
                end
            end
        end
    end
    return best
end
local function attemptBomb()
    local b=S.bomb
    if not (S.enabled.bomb and b.holding and alive()) then return end
    if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        b.sentTo=nil
        return
    end
    local target=eligibleHover()
    if target~=b.sentTo then
        b.sentTo=target
        b.lastSent=0
    end
    if target and os.clock()-b.lastSent>=0.20 then
        b.lastSent=os.clock()
        if send("BombTap",target) then
            S.counters.bomb+=1
            if S.counters.bomb<=3 or S.counters.bomb%8==0 then
                log("BOMB: requested held target "..tostring(target.Name))
            end
        end
    end
end
attach("BombHold",function(holding,_,eligible)
    local b=S.bomb
    b.holding=holding==true
    b.eligible={}
    b.sentTo=nil
    b.lastSent=0
    if b.holding and type(eligible)=="table" then
        for _,t in ipairs(eligible) do
            if typeof(t)=="Instance" and t:IsA("Model") and t.Parent and t~=plr.Character then
                table.insert(b.eligible,t)
            end
        end
        b.startAt=os.clock()
        log("BOMB: holding • "..#b.eligible.." eligible recipients")
        task.defer(attemptBomb)
    end
end)
attach("BombFX",function(kind,...)
    if kind=="pass" or kind=="boom" or kind=="end" then
        -- The BombHold signal is the definitive indication of local possession.
        if kind~="pass" then
            S.bomb.holding=false;S.bomb.eligible={};S.bomb.sentTo=nil
        end
    end
end)

-- Escape prompts: only send while server reports *your own* escape.
attach("EscapeFX",function(kind,...)
    local values={...}
    if kind=="start" then
        local char=values[1]
        local ownerId=values[7]
        S.escape.active=(char==plr.Character or ownerId==plr.UserId)
        S.escape.variant=tostring(values[2] or "Escape")
        S.escape.startedAt=os.clock();S.escape.progress=0
        if S.escape.active then log("ESCAPE: "..S.escape.variant.." live")end
    elseif kind=="p" then
        if S.escape.active and values[1]==plr.Character and type(values[2])=="number" then
            S.escape.progress=values[2]
        end
    elseif kind=="escaped" or kind=="fail" then
        if values[1]==plr.Character or S.escape.active then
            log("ESCAPE: server event "..kind)
        end
        S.escape.active=false
    end
end)
attach("TakenFX",function(kind,...)
    local a={...}
    if kind=="breakout" then
        -- This packet identifies the local breakout player as its first argument.
        S.taken.breakout=a[1]==plr.Character
        S.taken.breakStarted=os.clock()
        S.taken.breakProgress=0
        if S.taken.breakout then log("TAKEN: breakout prompt detected")end
    elseif kind=="breakprog" then
        if S.taken.breakout and type(a[1])=="number" then
            S.taken.breakProgress=a[1]
            if a[1]>=1 then S.taken.breakout=false;log("TAKEN: escape meter confirmed complete")end
        end
    elseif kind=="podaway" or kind=="timeup" or kind=="done" or kind=="end" then
        S.taken.breakout=false
        if kind=="end" or kind=="done" then
            S.taken.pathIndex=1;S.taken.routeStuckAt=0
        end
    end
end)
local function attemptEscape()
    if not (S.enabled.escape and alive()) then return end
    local t=os.clock()
    if S.escape.active and t-S.escape.startedAt<18 and t-S.escape.lastTap>=0.085 then
        S.escape.lastTap=t
        if send("EscapeTap") then S.counters.escape+=1 end
    end
    if S.taken.breakout and t-S.taken.breakStarted<17 and t-S.taken.lastTap>=0.085 then
        S.taken.lastTap=t
        if send("TakenTap") then S.counters.taken+=1 end
    end
end

-- Thin Ice failure originates in the local controller; this prevents the
-- locally-bound balancing loop from reporting failure. Unverified server outcome.
attach("ThinIceStart",function(started)
    S.thin.active=started and true or false
    S.thin.lastFreeze=0
    if S.thin.active then
        S.thin.starts+=1
        log("THIN ICE: balance controller detected")
        if S.enabled.thin then
            task.defer(function()
                if not S.alive or not S.thin.active or not S.enabled.thin then return end
                pcall(function()Run:UnbindFromRenderStep("ThinIceBalance")end)
                S.counters.thin+=1
                log("THIN ICE: paused local balance/failure loop (experimental)")
            end)
        end
    end
end)
local function attemptThin()
    if not (S.thin.active and S.enabled.thin) then return end
    if os.clock()-S.thin.lastFreeze>=0.3 then
        S.thin.lastFreeze=os.clock()
        pcall(function()Run:UnbindFromRenderStep("ThinIceBalance")end)
    end
end

-- Moon Race code contains a local boost meter and local WalkSpeed assignment.
-- We reapply the game's own BOOST value; we do NOT modify remote cfg values.
attach("MoonRaceFX",function(kind,a,b,c)
    local m=S.moon
    if kind=="intro" then
        m.active=true;m.started=false;m.cfg=nil;m.flag=nil
        log("MOON RACE: intro")
    elseif kind=="ready" then
        m.active=true;m.started=false;m.flag=b
        m.cfg=type(c)=="table" and c or nil
        m.lastSpeed=0
        log("MOON RACE: config and finish location received")
    elseif kind=="go" then
        m.active=true;m.started=true
        m.routeStuckAt=0
        log("MOON RACE: started")
    elseif kind=="left" or kind=="end" or kind=="done" then
        m.started=false
        if kind=="end" then m.active=false end
    end
end)
local function moonMovement()
    local m=S.moon
    if not (m.started and m.active and alive()) then return end
    local h,c=humanoid()
    local root=c and c:FindFirstChild("HumanoidRootPart")
    if not (h and root) then return end
    if S.enabled.moonBoost and m.cfg and type(m.cfg.BOOST)=="number" and
       h.MoveDirection.Magnitude>0.10 and h.SeatPart==nil and not root.Anchored then
        if h.WalkSpeed<m.cfg.BOOST then
            h.WalkSpeed=m.cfg.BOOST
            S.counters.moon+=1
        end
    end
    if S.enabled.moonPath and typeof(m.flag)=="Vector3" and h.SeatPart==nil then
        if os.clock()-m.lastMove>=0.12 then
            m.lastMove=os.clock()
            local dest=m.flag
            local distance=(Vector3.new(root.Position.X,0,root.Position.Z)-
                Vector3.new(dest.X,0,dest.Z)).Magnitude
            if distance>3 then
                h:MoveTo(dest)
                if distance<16 and h.FloorMaterial~=Enum.Material.Air and
                    os.clock()-m.lastJump>0.6 then
                    local direction=(dest-root.Position)
                    if direction.Magnitude>1 then
                        local params=RaycastParams.new()
                        params.FilterType=Enum.RaycastFilterType.Exclude
                        params.FilterDescendantsInstances={c}
                        local hit=workspace:Raycast(root.Position, direction.Unit*5,params)
                        if hit and hit.Instance.CanCollide then
                            m.lastJump=os.clock();h.Jump=true
                        end
                    end
                end
            else
                m.lastMove=os.clock()
            end
        end
    end
end
local function takenMovement()
    if not (S.enabled.takenPath and alive()) then
        S.taken.routeStuckAt=0
        return
    end
    local name=tostring(getAttr(workspace,"EventName","")):lower()
    if not name:find("taken",1,true) then return end
    local ship=workspace:FindFirstChild("TakenShip")
    local marks=ship and ship:FindFirstChild("Markers")
    if not marks then return end
    local h,c=humanoid()
    local root=c and c:FindFirstChild("HumanoidRootPart")
    if not (h and root) or root.Anchored or h.SeatPart then return end
    local t=S.taken
    local waypoint=marks:FindFirstChild("Route"..t.pathIndex)
    if not waypoint or not waypoint:IsA("BasePart") then
        if t.pathIndex>1 then
            S.enabled.takenPath=false
            if featureCards.takenPath then featureCards.takenPath.refresh()end
            log("TAKEN: final route marker reached")
        end
        return
    end
    local destination=waypoint.Position
    local dist=(Vector3.new(root.Position.X,0,root.Position.Z)-
        Vector3.new(destination.X,0,destination.Z)).Magnitude
    if dist<2.3 then
        t.pathIndex+=1;t.routeLastDist=math.huge;t.routeStuckAt=0
        log("TAKEN: reached route marker "..tostring(t.pathIndex-1))
        return
    end
    if os.clock()-t.lastPathAt<0.13 then return end
    t.lastPathAt=os.clock()
    h:MoveTo(destination)
    if dist<t.routeLastDist-0.25 then
        t.routeStuckAt=0;t.routeLastDist=dist
    elseif t.routeStuckAt==0 then
        t.routeStuckAt=os.clock()
    elseif os.clock()-t.routeStuckAt>3.2 then
        log("TAKEN: route obstructed; stopped for manual intervention")
        S.enabled.takenPath=false
        featureCards.takenPath.refresh()
        t.routeStuckAt=0
        return
    end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={c}
    local vec=destination-root.Position
    if vec.Magnitude>2 and h.FloorMaterial~=Enum.Material.Air then
        local hit=workspace:Raycast(root.Position,vec.Unit*3.7,params)
        if hit and hit.Instance.CanCollide and os.clock()-S.moon.lastJump>0.5 then
            h.Jump=true;S.moon.lastJump=os.clock()
        end
    end
end

-- Aim assist only nudges an existing mouse pointer towards a *visible* opponent.
local lastAim=0
local function aimUpdate()
    aimDot.Visible=false
    if not (S.enabled.aim and alive() and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)) then return end
    local cam=workspace.CurrentCamera
    local h,me=humanoid()
    if not (cam and me and h) then return end
    local gun=nil
    for _,tool in ipairs(me:GetChildren()) do
        if tool:IsA("Tool") and tool.Name=="Handgun" then gun=tool;break end
    end
    if not gun then return end
    local mouse=UIS:GetMouseLocation()
    local inset=GuiService:GetGuiInset()
    local cursor=Vector2.new(mouse.X,mouse.Y-inset.Y)
    local best,bestPoint,bestDistance=nil,nil,68
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=plr and (not plr.Team or p.Team~=plr.Team) then
            local char=p.Character
            local hh=char and char:FindFirstChildOfClass("Humanoid")
            local target=char and (char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso"))
            if hh and hh.Health>0 and target and target:IsA("BasePart") then
                local screen,seen=cam:WorldToViewportPoint(target.Position)
                if seen and screen.Z>0 then
                    local pos=Vector2.new(screen.X,screen.Y)
                    local d=(pos-cursor).Magnitude
                    if d<bestDistance then
                        local exclude=RaycastParams.new()
                        exclude.FilterType=Enum.RaycastFilterType.Exclude
                        exclude.FilterDescendantsInstances={me}
                        local from=cam.CFrame.Position
                        local ray=workspace:Raycast(from,target.Position-from,exclude)
                        if ray and ray.Instance:IsDescendantOf(char) then
                            best=p;bestPoint=pos;bestDistance=d
                        end
                    end
                end
            end
        end
    end
    if bestPoint then
        aimDot.Visible=S.visible
        aimDot.Position=UDim2.fromOffset(bestPoint.X,bestPoint.Y)
        if type(mousemoverel)=="function" and os.clock()-lastAim>=0.015 then
            lastAim=os.clock()
            local diff=bestPoint-cursor
            guarded("aim",function()
                mousemoverel(math.clamp(diff.X*0.20,-5,5),math.clamp(diff.Y*0.20,-5,5))
                S.counters.aim+=1
            end)
        end
    end
end
local lastWalk=0
local function speedUpdate()
    if not (S.enabled.speed and alive()) then return end
    if S.moon.active or S.taken.routeStuckAt>0 then return end
    if getAttr(plr,"PhoneLocked",false) or getAttr(workspace,"EventActive",false) then
        return
    end
    local h,c=humanoid()
    local base=getAttr(c,"ServerWalkSpeed",nil)
    if not (h and type(base)=="number" and base>0 and h.SeatPart==nil) then return end
    if getAttr(c,"LocalWalk",false) then return end
    local desired=base*1.03
    if math.abs(h.WalkSpeed-desired)>0.02 then
        h.WalkSpeed=desired
        S.counters.speed+=1
    end
end

local function uiRefresh()
    local ms=RS:FindFirstChild("MatchState")
    S.phase=tostring(getAttr(ms,"Phase",S.mode))
    S.event=tostring(getAttr(workspace,"EventName",""))
    S.eventLive=getAttr(workspace,"EventActive",false)==true
    local headline=(S.eventLive and S.event~="" and S.event or "NO ACTIVE CHALLENGE")
    local c=0
    for k,v in pairs(S.enabled) do
        if v and k~="miniHud" then c+=1 end
    end
    stateTitle.Text=headline:upper()
    stateSub.Text=S.mode.." • "..S.phase.." • "..c.." helpers selected"
    stateTitle.TextColor3=S.eventLive and P.green or P.blue
    local d=S.duel
    if S.mode=="LOBBY" then
        footerLabel.Text="LOBBY • gameplay automations activate in a match"
    else
        footerLabel.Text="DUEL "..S.counters.duel.."  •  ESCAPE "..S.counters.escape..
            "  •  BOMB "..S.counters.bomb.."  •  SERVER OUTCOME UNVERIFIED"
    end
    stripLabel.Text="NOVA  •  "..(S.eventLive and S.event or S.phase)..
        "  •  "..c.." helpers"
    if S.tab=="TOOLS" and S.dirty then
        local values={}
        for i=1,math.min(5,#S.logs) do table.insert(values,S.logs[i]) end
        sessionText.Text=table.concat(values,"\n")
        S.dirty=false
    end
    for key,card in pairs(featureCards) do
        if card.status then card.status.Text=actionStatus(key) end
    end
end
local function cleanup()
    if not S.alive then return end
    S.alive=false
    S.escape.active=false;S.taken.breakout=false;S.bomb.holding=false
    for _,conn in ipairs(S.connections) do pcall(function()conn:Disconnect()end)end
    S.connections={}
    pcall(function()Run:UnbindFromRenderStep("PhoneNovaV2Aim")end)
    if ui and ui.Parent then pcall(function()ui:Destroy()end)end
    if type(environment)=="table" and environment.THE_PHONE_NOVA_HUB_V2==S.api then
        environment.THE_PHONE_NOVA_HUB_V2=nil
    end
end
S.api={stop=cleanup,version=VERSION,snapshot=snapshot,config=S.enabled,diagnostics=function()return S.snapshot end}
if type(environment)=="table" then environment.THE_PHONE_NOVA_HUB_V2=S.api end
track(ui.Destroying,function()
    if S.alive then cleanup()end
end)
if workspace.CurrentCamera then
    track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),rescale)
end
track(plr.CharacterAdded,function()
    S.escape.active=false;S.taken.breakout=false
    S.taken.pathIndex=1;S.taken.routeStuckAt=0
    S.moon.started=false
    log("Respawn: temporary action state cleared")
end)
Run:BindToRenderStep("PhoneNovaV2Aim",Enum.RenderPriority.Camera.Value+9,function()
    if not S.alive then return end
    guarded("render",function()
        aimUpdate()
        speedUpdate()
        moonMovement()
    end)
end)
track(Run.Heartbeat,function()
    if not S.alive then return end
    local now=os.clock()
    if now-S.tickAt>=0.06 then
        S.tickAt=now
        guarded("actions",function()
            attemptDuel();attemptBomb();attemptEscape()
            attemptThin();takenMovement()
        end)
    end
    if now-S.lastUi>=0.28 then
        S.lastUi=now
        guarded("display",uiRefresh)
    end
end)
updateVisible()
log("THE PHONE NOVA "..VERSION.." loaded; RightShift toggles panel")
if S.mode=="LOBBY" then
    log("Lobby detected; gameplay controls arm after match teleport")
end
warn("[PHONE NOVA] "..VERSION.." ready | RightShift toggle | one-action server requests | diagnostics via TOOLS")
