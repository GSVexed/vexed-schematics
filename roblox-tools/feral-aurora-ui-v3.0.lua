-- FERAL AURORA v3.0 | premium all-in-one operations UI
-- No third-party UI libraries. Uses native Roblox GUI and client data.
local UI={}
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Tween=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local localPlayer=Players.LocalPlayer
local function make(class,props,parent)
    local o=Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    if parent then o.Parent=parent end
    return o
end
local function round(item,n)
    make("UICorner",{CornerRadius=UDim.new(0,n or 10)},item)
    return item
end
local function stroke(item,color,alpha)
    make("UIStroke",{Color=color,Transparency=alpha or .5,Thickness=1},item)
end
local function gradient(item,a,b,rotation)
    make("UIGradient",{
        Color=ColorSequence.new(a,b),Rotation=rotation or 0
    },item)
end
local function label(parent,text,size,height,color,bold)
    return make("TextLabel",{
        Text=text or "",BackgroundTransparency=1,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=size or 12,TextColor3=color or Color3.fromRGB(225,240,249),
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,
        TextWrapped=true,Size=UDim2.new(1,0,0,height or 25)
    },parent)
end
local function textButton(parent,text,color,callback)
    local b=round(make("TextButton",{
        Text=text,Font=Enum.Font.GothamBold,TextSize=11,
        TextColor3=Color3.fromRGB(236,247,253),
        BorderSizePixel=0,BackgroundColor3=color,
        AutoButtonColor=true,Size=UDim2.fromOffset(115,33)
    },parent),8)
    local edge=make("UIStroke",{
        Color=Color3.fromRGB(234,249,255),Transparency=1,Thickness=1
    },b)
    b.MouseEnter:Connect(function()
        Tween:Create(edge,TweenInfo.new(.13),{Transparency=.47}):Play()
    end)
    b.MouseLeave:Connect(function()
        Tween:Create(edge,TweenInfo.new(.16),{Transparency=1}):Play()
    end)
    if callback then b.Activated:Connect(callback) end
    return b
end
local function list(parent,spacing)
    make("UIListLayout",{
        Padding=UDim.new(0,spacing or 9),
        SortOrder=Enum.SortOrder.LayoutOrder
    },parent)
end
local function padded(parent,px,py)
    make("UIPadding",{
        PaddingLeft=UDim.new(0,px or 0),PaddingRight=UDim.new(0,px or 0),
        PaddingTop=UDim.new(0,py or 0),PaddingBottom=UDim.new(0,py or 0)
    },parent)
end
local function fmt(v,d)
    return type(v)=="number" and v==v
        and string.format("%."..tostring(d or 1).."f",v) or "—"
end
function UI.mount(ctx)
    local s,c,ops=ctx.state,ctx.palette,ctx.ops
    local guiParent=localPlayer:FindFirstChildOfClass("PlayerGui")
        or localPlayer:WaitForChild("PlayerGui",9)
    if not guiParent then return nil end
    local gui=make("ScreenGui",{
        Name="FeralAuroraHubV30",ResetOnSpawn=false,DisplayOrder=155,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    },guiParent)
    ctx.ui=gui
    local shutdown=make("BindableEvent",{Name="AuroraShutdown"},gui)
    shutdown.Event:Connect(function()ctx.close()end)
    local accent=function()return ctx.accent() end
    local main=round(make("Frame",{
        AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        Size=UDim2.fromOffset(1064,682),BackgroundColor3=c.bg,
        BorderSizePixel=0,Active=true
    },gui),16)
    stroke(main,c.line,.14)
    gradient(main,Color3.fromRGB(12,26,39),Color3.fromRGB(11,14,27),28)
    local scale=make("UIScale",{Scale=1},main)
    local function scaleToScreen()
        local cam=workspace.CurrentCamera
        local size=cam and cam.ViewportSize or Vector2.new(1250,800)
        scale.Scale=math.clamp(math.min((size.X-24)/1064,(size.Y-40)/682,1),.54,1)*s.scale
    end
    scaleToScreen()
    local top=make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,65),Active=true},main)
    make("Frame",{BorderSizePixel=0,BackgroundColor3=c.line,
        Position=UDim2.fromOffset(0,64),Size=UDim2.new(1,0,0,1)},main)
    local heroLine=round(make("Frame",{
        BackgroundColor3=accent(),Position=UDim2.fromOffset(18,13),
        Size=UDim2.fromOffset(4,39),BorderSizePixel=0},top),3)
    make("TextLabel",{
        Text="A U R O R A",BackgroundTransparency=1,TextColor3=c.text,
        Font=Enum.Font.GothamBold,TextSize=22,TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(35,12),Size=UDim2.fromOffset(275,30)
    },top)
    make("TextLabel",{
        Text="FERAL  /  THE WILD, UNDER CONTROL  /  v3.0",
        Font=Enum.Font.Gotham,TextSize=10,TextColor3=c.dim,
        BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(37,39),Size=UDim2.fromOffset(395,20)
    },top)
    local phasePill=round(make("Frame",{
        Position=UDim2.fromOffset(550,16),Size=UDim2.fromOffset(190,30),
        BackgroundColor3=c.panel,BorderSizePixel=0
    },top),8)
    local phaseText=make("TextLabel",{
        Text="●  CHECKING ANIMAL",TextColor3=c.amber,
        Font=Enum.Font.GothamBold,TextSize=10,
        BackgroundTransparency=1,Size=UDim2.fromScale(1,1)
    },phasePill)
    local miniOpen
    local hidden=false
    local function toggleHidden()
        hidden=not hidden;main.Visible=not hidden
        if miniOpen then miniOpen.Visible=hidden end
    end
    local launchPalette=function()end
    local searchButton=textButton(top,"⌕  SEARCH",c.panel2,function()launchPalette()end)
    searchButton.Position=UDim2.fromOffset(755,14)
    local hide=textButton(top,"—",c.panel2,toggleHidden)
    hide.Size=UDim2.fromOffset(38,31);hide.Position=UDim2.fromOffset(881,14)
    local sizeButton=textButton(top,"⤢",c.panel2,function()
        if s.scale>=1.04 then ctx.setScale(.78)
        else ctx.setScale(s.scale+.09) end
        scaleToScreen()
    end)
    sizeButton.Size=UDim2.fromOffset(38,31);sizeButton.Position=UDim2.fromOffset(924,14)
    local exit=textButton(top,"×",c.red,function()ctx.close()end)
    exit.Size=UDim2.fromOffset(38,31);exit.Position=UDim2.fromOffset(967,14)
    miniOpen=textButton(gui,"✦  AURORA",c.panel2,toggleHidden)
    miniOpen.Size=UDim2.fromOffset(142,38)
    miniOpen.Position=UDim2.new(0,16,.43,0)
    miniOpen.Visible=false
    stroke(miniOpen,c.teal,.2)
    local nav=round(make("Frame",{
        Position=UDim2.fromOffset(12,77),Size=UDim2.fromOffset(190,538),
        BackgroundColor3=c.shell,BorderSizePixel=0
    },main),11)
    stroke(nav,c.line,.6)
    local navHeader=label(nav,"WORKSPACES",10,23,c.dim,true)
    navHeader.Position=UDim2.fromOffset(14,12);navHeader.Size=UDim2.fromOffset(158,24)
    local views={
        {"DASHBOARD","⌂"},{"RADAR","◉"},{"SURVIVAL","◍"},
        {"EFFECTS","✦"},{"MOVEMENT","➤"},{"WAYPOINTS","⌾"},
        {"SYSTEMS","▤"},{"SETTINGS","⚙"}
    }
    local navButtons={}
    local content=make("Frame",{
        BackgroundTransparency=1,Position=UDim2.fromOffset(215,77),
        Size=UDim2.fromOffset(558,539)
    },main)
    local right=round(make("Frame",{
        BackgroundColor3=c.shell,BorderSizePixel=0,
        Position=UDim2.fromOffset(786,77),Size=UDim2.fromOffset(266,539)
    },main),11)
    stroke(right,c.line,.6)
    local pages={}
    for _,item in ipairs(views) do
        local key=item[1]
        local page=make("ScrollingFrame",{
            BackgroundTransparency=1,BorderSizePixel=0,
            ScrollBarThickness=3,ScrollBarImageColor3=c.line,
            AutomaticCanvasSize=Enum.AutomaticSize.Y,
            CanvasSize=UDim2.new(),ScrollingDirection=Enum.ScrollingDirection.Y,
            Size=UDim2.new(1,0,1,0),Visible=false
        },content)
        padded(page,5,5);list(page,10)
        pages[key]=page
    end
    local activePage="DASHBOARD"
    local renderSystems=function()end
    local renderPins=function()end
    local renderResources=function()end
    local function showPage(key)
        if not pages[key] then return end
        activePage=key
        for name,page in pairs(pages) do page.Visible=(name==key)end
        for name,b in pairs(navButtons) do
            b.BackgroundColor3=name==key and c.panel2 or c.shell
            b.TextColor3=name==key and accent() or c.muted
        end
        if key=="SYSTEMS" then renderSystems() end
        if key=="WAYPOINTS" then renderPins() end
        if key=="SURVIVAL" then renderResources() end
    end
    for i,item in ipairs(views) do
        local b=textButton(nav,item[2].."   "..item[1],c.shell,function()showPage(item[1])end)
        b.Size=UDim2.fromOffset(168,42)
        b.Position=UDim2.fromOffset(11,44+(i-1)*52)
        b.TextXAlignment=Enum.TextXAlignment.Left
        b.TextSize=12
        navButtons[item[1]]=b
    end
    local shortcut=label(nav,"CTRL+K  SEARCH     ·     RSHIFT  HIDE",9,27,c.dim)
    shortcut.Position=UDim2.fromOffset(10,485)
    shortcut.Size=UDim2.fromOffset(173,30)
    local bottom=make("Frame",{
        BackgroundTransparency=1,Position=UDim2.fromOffset(13,624),
        Size=UDim2.fromOffset(1037,46)
    },main)
    make("Frame",{
        BackgroundColor3=c.line,BorderSizePixel=0,
        Size=UDim2.new(1,0,0,1)},bottom)
    local toast=make("TextLabel",{
        Text=s.notice,BackgroundTransparency=1,TextColor3=c.muted,
        TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,
        Position=UDim2.fromOffset(8,7),Size=UDim2.fromOffset(806,31)
    },bottom)
    local restore=textButton(bottom,"RESET ALL",c.red,function()ctx.reset()end)
    restore.Size=UDim2.fromOffset(162,31);restore.Position=UDim2.fromOffset(865,7)
    local function card(parent,title,subtitle,height,tag)
        local f=round(make("Frame",{
            BackgroundColor3=c.panel,Size=UDim2.new(1,-17,0,height or 100),
            BorderSizePixel=0},parent),11)
        stroke(f,c.line,.6)
        local t=label(f,title,14,26,c.text,true)
        t.Position=UDim2.fromOffset(15,9);t.Size=UDim2.new(1,-32,0,26)
        if tag then
            local pill=round(make("Frame",{
                BackgroundColor3=c.panel2,BorderSizePixel=0,
                Size=UDim2.fromOffset(94,20),
                Position=UDim2.new(1,-110,0,12)
            },f),6)
            local status=label(pill,tag,9,19,c.dim,true)
            status.TextXAlignment=Enum.TextXAlignment.Center
            t.Size=UDim2.new(1,-125,0,26)
        end
        local desc=label(f,subtitle or "",11,math.max(28,(height or 100)-42),c.muted)
        desc.TextYAlignment=Enum.TextYAlignment.Top
        desc.Position=UDim2.fromOffset(15,41)
        desc.Size=UDim2.new(1,-32,0,math.max(27,(height or 100)-47))
        return f,desc
    end
    local toggles={}
    local function toggle(parent,key,title,description,tag)
        local f,d=card(parent,title,description,97,tag)
        d.Size=UDim2.new(1,-116,0,48)
        local b=textButton(f,"OFF",c.panel2,function()ctx.toggle(key)end)
        b.Size=UDim2.fromOffset(75,31)
        b.Position=UDim2.new(1,-92,0,50)
        toggles[key]=toggles[key] or {}
        toggles[key][#toggles[key]+1]=b
        return f,b
    end
    local function action(parent,title,description,buttonText,callback,tag)
        local f,d=card(parent,title,description,106,tag)
        d.Size=UDim2.new(1,-185,0,61)
        local b=textButton(f,buttonText,c.panel2,callback)
        b.Position=UDim2.new(1,-174,1,-39)
        b.Size=UDim2.fromOffset(155,31)
        return f,b
    end
    local function heading(parent,text)
        local f=make("Frame",{
            BackgroundTransparency=1,Size=UDim2.new(1,-15,0,32)
        },parent)
        local t=label(f,text,16,30,c.text,true)
        t.Position=UDim2.fromOffset(1,0)
        return f
    end
    local function actionRow(parent,entries)
        local f=make("Frame",{
            BackgroundTransparency=1,Size=UDim2.new(1,-16,0,35)
        },parent)
        for i,entry in ipairs(entries) do
            local b=textButton(f,entry[1],c.panel2,entry[2])
            b.Size=UDim2.fromOffset(entry[3] or 122,33)
            b.Position=UDim2.fromOffset((i-1)*132,0)
        end
        return f
    end
    local function metricBar(parent,name,clr)
        local f=round(make("Frame",{
            BackgroundColor3=c.panel2,BorderSizePixel=0,
            Size=UDim2.new(1,-20,0,52)
        },parent),8)
        local nameLabel=label(f,name,10,17,c.dim,true)
        nameLabel.Position=UDim2.fromOffset(10,5)
        nameLabel.Size=UDim2.new(1,-118,0,17)
        local valueLabel=label(f,"—",11,17,c.text,true)
        valueLabel.Position=UDim2.new(1,-103,0,5)
        valueLabel.Size=UDim2.fromOffset(90,17)
        valueLabel.TextXAlignment=Enum.TextXAlignment.Right
        local rail=round(make("Frame",{
            BackgroundColor3=c.line,BorderSizePixel=0,
            Position=UDim2.fromOffset(10,30),
            Size=UDim2.new(1,-20,0,8)},f),5)
        local fill=round(make("Frame",{
            BackgroundColor3=clr,Size=UDim2.fromScale(0,1),
            BorderSizePixel=0
        },rail),5)
        return function(value,max)
            valueLabel.Text=(type(value)=="number" and fmt(value,1) or "—")..
                (type(max)=="number" and ("/"..fmt(max,0)) or "")
            fill.Size=UDim2.fromScale(
                type(value)=="number" and type(max)=="number" and max>0
                and math.clamp(value/max,0,1) or 0,1)
        end
    end
    -- Right rail persists across every page.
    local rightTitle=label(right,"LIVE / FIELD STATUS",11,22,c.teal,true)
    rightTitle.Position=UDim2.fromOffset(14,12)
    rightTitle.Size=UDim2.fromOffset(235,23)
    local animalText=label(right,"Waiting for animal...",12,41,c.text,true)
    animalText.Position=UDim2.fromOffset(14,36)
    animalText.Size=UDim2.fromOffset(237,38)
    local bars=make("Frame",{
        BackgroundTransparency=1,Position=UDim2.fromOffset(9,86),
        Size=UDim2.fromOffset(248,208)
    },right)
    list(bars,1)
    local setHP=metricBar(bars,"HEALTH",c.green)
    local setStamina=metricBar(bars,"STAMINA",c.teal)
    local setHunger=metricBar(bars,"HUNGER",c.amber)
    local setThirst=metricBar(bars,"THIRST",c.violet)
    make("Frame",{BackgroundColor3=c.line,BorderSizePixel=0,
        Position=UDim2.fromOffset(13,303),
        Size=UDim2.fromOffset(239,1)},right)
    local focusTitle=label(right,"◈  CURRENT TARGET",11,24,c.amber,true)
    focusTitle.Position=UDim2.fromOffset(15,314)
    focusTitle.Size=UDim2.fromOffset(222,26)
    local focusName=label(right,"NO TARGET SELECTED",13,26,c.text,true)
    focusName.Position=UDim2.fromOffset(15,341)
    focusName.Size=UDim2.fromOffset(233,27)
    local focusDetails=label(right,"Use radar or location pins.",11,49,c.muted)
    focusDetails.Position=UDim2.fromOffset(15,369)
    focusDetails.Size=UDim2.fromOffset(230,44)
    local pinFocus=textButton(right,"SAVE PIN",c.panel2,function()
        ops.addPin();renderPins()
    end)
    pinFocus.Size=UDim2.fromOffset(110,31);pinFocus.Position=UDim2.fromOffset(13,426)
    local clearFocus=textButton(right,"CLEAR",c.panel2,function()
        ops.clearFocus()
    end)
    clearFocus.Size=UDim2.fromOffset(110,31);clearFocus.Position=UDim2.fromOffset(136,426)
    local statusLine=label(right,"Client controls are separate from server rewards.",
        10,52,c.dim)
    statusLine.Position=UDim2.fromOffset(15,468)
    statusLine.Size=UDim2.fromOffset(234,45)
    -- Dashboard, designed as a working landing surface.
    local home=pages.DASHBOARD
    local hero=round(make("Frame",{
        BackgroundColor3=Color3.fromRGB(24,55,66),BorderSizePixel=0,
        Size=UDim2.new(1,-17,0,118)
    },home),12)
    gradient(hero,Color3.fromRGB(30,87,87),Color3.fromRGB(37,34,62),12)
    local heroLabel=label(hero,"ANIMAL MENU / READY TO EXPLORE",18,30,c.text,true)
    heroLabel.Position=UDim2.fromOffset(16,11)
    heroLabel.Size=UDim2.new(1,-32,0,30)
    local heroSub=label(hero,"Your tools, waypoints and player tracker stay ready.",
        11,30,c.muted)
    heroSub.Position=UDim2.fromOffset(16,39)
    heroSub.Size=UDim2.new(1,-30,0,27)
    local enterRadar=textButton(hero,"◉  RADAR",c.panel,function()showPage("RADAR")end)
    enterRadar.Position=UDim2.fromOffset(14,77)
    local enterSurvival=textButton(hero,"◍  NEEDS",c.panel,function()showPage("SURVIVAL")end)
    enterSurvival.Position=UDim2.fromOffset(143,77)
    local enterEffects=textButton(hero,"✦  EFFECTS",c.panel,function()showPage("EFFECTS")end)
    enterEffects.Position=UDim2.fromOffset(272,77)
    local quicks={
        {"PLAYER FINDER","finder"},{"RECOVERY ASSIST","rest"},
        {"CALM CAMERA","camera"},{"BRIGHT VIEW","vision"},
        {"FIND FOOD","food"},{"FIND WATER","water"},
        {"FOCUS NEAREST","target"},{"RESTORE ALL","reset"}
    }
    heading(home,"QUICK OPERATIONS")
    local quickPanel=round(make("Frame",{
        Size=UDim2.new(1,-17,0,171),BackgroundColor3=c.panel,
        BorderSizePixel=0
    },home),11)
    stroke(quickPanel,c.line,.65)
    local quickButtons={}
    for i,entry in ipairs(quicks) do
        local b=textButton(quickPanel,entry[1],c.panel2,function()
            if entry[2]=="reset" then ctx.reset()
            else ops.quick(entry[2]) end
            ctx.onUI()
        end)
        b.Size=UDim2.fromOffset(243,33)
        b.Position=UDim2.fromOffset(13+((i-1)%2)*256,
            12+math.floor((i-1)/2)*38)
        quickButtons[entry[2]]=b
    end
    local conditionsCard,conditionsInfo=card(home,"WHAT IS HAPPENING?",
        "Waiting for your animal and nearby-world signals.",122,"LIVE")
    local logCard,logInfo=card(home,"LATEST ACTIVITY",
        "No operations yet.",89,"SESSION")
    -- Radar: actual 2D geometry derived from replicated player coordinates
    local radarPage=pages.RADAR
    heading(radarPage,"PLAYER RADAR")
    local radarCard=round(make("Frame",{
        Size=UDim2.new(1,-17,0,335),
        BackgroundColor3=c.panel,BorderSizePixel=0
    },radarPage),12)
    stroke(radarCard,c.line,.55)
    local radarCircle=round(make("Frame",{
        BackgroundColor3=Color3.fromRGB(12,30,44),
        BorderSizePixel=0,Size=UDim2.fromOffset(258,258),
        Position=UDim2.fromOffset(18,24)},radarCard),129)
    stroke(radarCircle,c.teal,.45)
    local radarInset=round(make("Frame",{
        BackgroundTransparency=1,BorderSizePixel=0,
        Size=UDim2.fromOffset(169,169),
        Position=UDim2.fromOffset(44,44)
    },radarCircle),85)
    stroke(radarInset,c.line,.45)
    local radarCenter=round(make("Frame",{
        BackgroundColor3=c.teal,Size=UDim2.fromOffset(9,9),BorderSizePixel=0,
        AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5)
    },radarCircle),6)
    local direction=label(radarCircle,"FRONT ↑",10,20,c.teal,true)
    direction.Position=UDim2.fromOffset(96,6)
    direction.Size=UDim2.fromOffset(87,19)
    local dots={}
    for i=1,24 do
        local item={entry=nil}
        local circle=round(make("TextButton",{
            Text="•",TextSize=15,Font=Enum.Font.GothamBold,
            TextColor3=c.bg,BackgroundColor3=c.amber,
            BorderSizePixel=0,Size=UDim2.fromOffset(17,17),
            AnchorPoint=Vector2.new(.5,.5),Visible=false
        },radarCircle),9)
        circle.Activated:Connect(function()
            if item.entry then ops.focusPlayer(item.entry.ref) end
        end)
        item.button=circle
        dots[#dots+1]=item
    end
    local radarSummary=label(radarCard,"Radar ready.",12,70,c.muted)
    radarSummary.Position=UDim2.fromOffset(297,30)
    radarSummary.Size=UDim2.fromOffset(227,82)
    local nearestFocus=textButton(radarCard,"FOCUS NEAREST",c.panel2,function()
        ops.focusClosest()
    end)
    nearestFocus.Size=UDim2.fromOffset(212,33)
    nearestFocus.Position=UDim2.fromOffset(297,133)
    local radarFinder=textButton(radarCard,"ENABLE FINDER",c.panel2,function()
        ctx.toggle("playerFinder")
    end)
    radarFinder.Size=UDim2.fromOffset(212,33)
    radarFinder.Position=UDim2.fromOffset(297,175)
    local alertButton=textButton(radarCard,"NEARBY ALERTS OFF",c.panel2,function()
        ops.toggleNearAlerts()
    end)
    alertButton.Size=UDim2.fromOffset(212,33)
    alertButton.Position=UDim2.fromOffset(297,217)
    local finderOrigin=label(radarCard,"Animal or camera origin",10,28,c.dim)
    finderOrigin.Position=UDim2.fromOffset(16,297)
    finderOrigin.Size=UDim2.fromOffset(504,27)
    heading(radarPage,"FINDER APPEARANCE")
    toggle(radarPage,"playerFinder","WORLD OVERLAY MASTER",
        "Dark nametags, species, distance, health bars and local character outlines.","LOCAL")
    toggle(radarPage,"tags","FLOATING NAMEPLATES",
        "Beautiful local name tags following replicated players.","VISUAL")
    toggle(radarPage,"outlines","COLOUR-CODED OUTLINES",
        "Teal close by, amber middle distance, coral farther away.","VISUAL")
    toggle(radarPage,"throughWalls","THROUGH-WALL DISPLAY",
        "Optional always-on-top outlines and nameplates for replicated targets.","OPT-IN")
    local rangeCard,rangeInfo=card(radarPage,"RANGE & QUALITY",
        "Select the search circle. Maximum 24 nearest replicated characters.",111,"LIVE")
    for i,v in ipairs({150,300,600,900}) do
        local b=textButton(rangeCard,tostring(v).." studs",c.panel2,function()
            ctx.setRange(v)
        end)
        b.Size=UDim2.fromOffset(115,29)
        b.Position=UDim2.fromOffset(12+(i-1)*128,75)
    end
    actionRow(radarPage,{
        {"SUBTLE",function()ctx.setOutlineStyle("subtle")end},
        {"BOLD",function()ctx.setOutlineStyle("bold")end},
        {"CLOSEST",function()ops.focusClosest()end},
        {"WAYPOINT",function()ops.toggleMarker()end}
    })
    local playerListCard,playerListDesc=card(radarPage,"PLAYERS IN RANGE",
        "Click any name below to make it your focused target.",361,"INTERACTIVE")
    playerListDesc.Size=UDim2.new(1,-30,0,31)
    local playerButtons={}
    for i=1,6 do
        local index=i
        local b=textButton(playerListCard,"No player",c.panel2,function()
            local a=ops.getRadar()[index]
            if a then ops.focusPlayer(a.ref)end
        end)
        b.Size=UDim2.new(1,-26,0,37)
        b.Position=UDim2.fromOffset(13,78+(i-1)*43)
        b.Visible=false
        playerButtons[#playerButtons+1]=b
    end
    -- Survival, with actual usable search/pin actions.
    local survival=pages.SURVIVAL
    heading(survival,"STAY FED. STAY HYDRATED.")
    local needsCard,needsInfo=card(survival,"YOUR SURVIVAL STATE",
        "Spawn an animal to see needs and species-aware guidance.",129,"LIVE")
    action(survival,"LOOK FOR FOOD",
        "Scan currently replicated, named resource candidates within 500 studs.",
        "SCAN FOOD",function()ctx.findResources("food");renderResources()end,"SEARCH")
    action(survival,"LOOK FOR WATER",
        "Find named water geometry and recorded lakes/springs; pin to compass.",
        "SCAN WATER",function()ctx.findResources("water");renderResources()end,"SEARCH")
    toggle(survival,"lowNeedsAssist","LOW-NEEDS LOCAL STAMINA ASSIST",
        "Opt-in cached recovery factor adjustment. Does NOT refill actual hunger or thirst.","CLIENT")
    toggle(survival,"alerts","LOW-NEEDS WARNINGS",
        "Alerts if your observed hunger or thirst is dangerously low.","ALERT")
    local resultsCard,resultsDesc=card(survival,"DISCOVERED RESOURCE LEADS",
        "Scan first, then select a result to set a world waypoint.",421,"LOCAL MAP")
    resultsDesc.Size=UDim2.new(1,-29,0,41)
    local resourceButtons={}
    for i=1,7 do
        local index=i
        local b=textButton(resultsCard,"Candidate",c.panel2,function()
            ops.focusResource(index)
        end)
        b.Size=UDim2.new(1,-29,0,39)
        b.Position=UDim2.fromOffset(14,102+(i-1)*43)
        b.Visible=false
        resourceButtons[i]=b
    end
    card(survival,"WHY NOT AN INSTANT 100% BUTTON?",
        "FERAL's health, hunger, thirst and true status effects are not all client-authoritative. Changing a HUD value does not establish a real refill. This page instead gives actionable navigation and a reversible client-side stamina option.",139,"EXPLAINED")
    -- Conditions dashboard and honest controls
    local effects=pages.EFFECTS
    heading(effects,"EFFECTS AT A GLANCE")
    local effectsInfo=card(effects,"ACTIVE CONDITION SUMMARY",
        "Waiting for your spawned animal.",112,"LIVE")
    local conditions={
        {"INJURY","FeralInjury","Move slowdown and damage recovery."},
        {"BLEEDING","FeralBleed","Bleeding/clotting status."},
        {"VENOM","FeralVenomAmt","Stacking venom and potential stamina effects."},
        {"EXHAUSTION","StaminaOut","Distinct from the displayed stamina amount."},
        {"HOBBLED","FeralHobbledUntil","Temporary severe movement impairment."},
        {"THRIVING","FeralThriveUntil","Potential temporary +50% growth boost."},
        {"REGROWTH","FeralRegrowLeft","Separate server-held regrowth allowance."},
        {"HOME TURF","FeralHomeTurf","Configured territorial damage bonus."},
        {"GRAZING","FeralGrazing","Configured grazing buff/Amber accrual."}
    }
    local effectRows={}
    for _,item in ipairs(conditions) do
        local f,d=card(effects,item[1],item[3],87,"TRACKED")
        d.Size=UDim2.new(1,-156,0,43)
        local value=label(f,"NOT OBSERVED",10,30,c.dim,true)
        value.Position=UDim2.new(1,-150,0,42)
        value.Size=UDim2.fromOffset(139,31)
        value.TextXAlignment=Enum.TextXAlignment.Center
        effectRows[#effectRows+1]={key=item[2],view=value}
    end
    heading(effects,"AVAILABLE CONTROLS")
    toggle(effects,"recovery","NATIVE RECOVERY ASSIST",
        "Requests ordinary Rest only when you have missing HP/conditions; server acceptance is unknown.","REST")
    toggle(effects,"mobility","INJURY-RELATED CLIENT SPEED INPUTS",
        "Reversible local slowdown configuration. Not a cure for server-held injury.","EXPERIMENT")
    toggle(effects,"lowNeedsAssist","LOW-NEEDS RECOVERY FACTOR",
        "Adjust the client-side 0.5 low-needs stamina factor to 1 without changing real food or water.","EXPERIMENT")
    action(effects,"SEEK FOOD & WATER",
        "If needs are low, open resource navigation and protect stamina recovery.",
        "OPEN SURVIVAL",function()showPage("SURVIVAL")end,"QUICK LINK")
    card(effects,"CONFIGURED VS ACTUAL EFFECTS",
        "Rest health x2, stamina x3 and ailment clearance near x4 are client-config leads. Thriving, Regrowth, Elder, grazing and territory multipliers depend on server eligibility. This panel will never label an unverified grant as active.",134,"EVIDENCE")
    -- Movement and visual customisation
    local move=pages.MOVEMENT
    heading(move,"MOTION & PRESENTATION")
    toggle(move,"calm","STEADY CAMERA","Remove local screen shake and sway.","COMFORT")
    toggle(move,"vision","BRIGHTER GAME WORLD",
        "A subtle client-only brightness adjustment.","VISUAL")
    toggle(move,"performance","NATIVE PERFORMANCE MODE",
        "Uses FERAL's own local performance flag.","CLIENT")
    action(move,"CLEAR VISUAL FILTERS",
        "Reset the additional colour profile to the original game visuals.",
        "NORMAL VISION",function()ops.setVisual("normal")end,"STYLE")
    local visualCard,visualInfo=card(move,"VISUAL PROFILES",
        "Choose a local screen treatment; does not change actual weather, darkness or lighting for others.",142,"LIVE")
    for i,item in ipairs({
        {"CLARITY","clarity"},{"WARM","warm"},{"MOONLIGHT","moonlight"},
        {"NORMAL","normal"}
    }) do
        local b=textButton(visualCard,item[1],c.panel2,function()ops.setVisual(item[2])end)
        b.Position=UDim2.fromOffset(11+((i-1)%2)*256,
            68+math.floor((i-1)/2)*39)
        b.Size=UDim2.fromOffset(237,33)
    end
    heading(move,"ADVANCED / REVERSIBLE")
    toggle(move,"speed","1.10× LAND / SWIM INPUTS",
        "Experimental cached controller inputs, not a server-authorised speed buff.","CLIENT")
    toggle(move,"leap","1.10× LEAP INPUTS",
        "Forward leap distance and speed-cap inputs; no flight or double jump.","CLIENT")
    card(move,"ABOUT EXHAUSTION AND BURST",
        "Exhaustion is a separate client-visible condition from the stamina number. The prolonged Burst death reports remain unexplained. These controls do not bypass server enforcement or guarantee survival.",130,"LIMITATION")
    -- Navigation hub: selected target, world POIs, saved pins
    local world=pages.WAYPOINTS
    heading(world,"NAVIGATION / WORLD")
    local waypointCard,waypointInfo=card(world,"FOCUSED DESTINATION",
        "Select a target from Radar, a food/water lead, or one of the landmarks.",115,"LIVE")
    actionRow(world,{
        {"MARKER",function()ops.toggleMarker()end},
        {"SAVE PIN",function()ops.addPin();renderPins()end},
        {"CLEAR",function()ops.clearFocus()end},
        {"OASIS",function()ops.focusLocationIndex(1)end}
    })
    local savedPinsCard,savedPinsDesc=card(world,"YOUR SAVED WAYPOINTS",
        "Eight persistent local pins, when readfile/writefile is supported.",379,"BOOKMARKS")
    savedPinsDesc.Size=UDim2.new(1,-24,0,28)
    local pinButtons={}
    for i=1,8 do
        local idx=i
        local focus=textButton(savedPinsCard,"No saved pin",c.panel2,function()
            ops.focusPin(idx)
        end)
        focus.Size=UDim2.fromOffset(400,34)
        focus.Position=UDim2.fromOffset(12,60+(i-1)*39)
        focus.Visible=false
        local remove=textButton(savedPinsCard,"×",c.red,function()
            ops.removePin(idx);renderPins()
        end)
        remove.Size=UDim2.fromOffset(38,34)
        remove.Position=UDim2.fromOffset(456,60+(i-1)*39)
        remove.Visible=false
        pinButtons[i]={focus=focus,remove=remove}
    end
    renderPins=function()
        for i,pair in ipairs(pinButtons) do
            local entry=ops.pins[i]
            pair.focus.Visible=entry~=nil
            pair.remove.Visible=entry~=nil
            if entry then
                pair.focus.Text=entry.name.."  •  "..fmt(entry.x,0)..", "..fmt(entry.z,0)
            end
        end
    end
    heading(world,"LANDMARKS / INSTANT FOCUS")
    local poiCard=round(make("Frame",{
        Size=UDim2.new(1,-17,0,285),
        BackgroundColor3=c.panel,BorderSizePixel=0
    },world),11)
    stroke(poiCard,c.line,.6)
    for i,p in ipairs(ctx.locations) do
        local index=i
        local b=textButton(poiCard,p[1],c.panel2,function()
            ops.focusLocationIndex(index)
        end)
        b.Size=UDim2.fromOffset(162,32)
        b.TextSize=10;b.TextTruncate=Enum.TextTruncate.AtEnd
        b.Position=UDim2.fromOffset(10+((i-1)%3)*173,
            11+math.floor((i-1)/3)*42)
    end
    -- Systems atlas, now search-and-action navigable
    local systems=pages.SYSTEMS
    heading(systems,"MECHANICS / 74 RECOVERED LEADS")
    local searchCard=round(make("Frame",{
        Size=UDim2.new(1,-17,0,92),BackgroundColor3=c.panel,
        BorderSizePixel=0
    },systems),11)
    stroke(searchCard,c.line,.6)
    local atlasSearch=round(make("TextBox",{
        PlaceholderText="Search Amber, Thriving, grazing, venom, disabled...",
        ClearTextOnFocus=false,Text="",Font=Enum.Font.Gotham,
        TextSize=12,TextColor3=c.text,PlaceholderColor3=c.dim,
        BackgroundColor3=c.panel2,BorderSizePixel=0,
        Size=UDim2.new(1,-24,0,34),
        Position=UDim2.fromOffset(12,9)
    },searchCard),8)
    make("UIPadding",{
        PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)},atlasSearch)
    local categories={"All","Recovery","Economy","Progression","Territory",
        "Abilities","Hidden","Favourites"}
    local category="All";local atlasPage=1
    local systemCards=make("Frame",{
        BackgroundTransparency=1,Size=UDim2.new(1,-17,0,0),
        AutomaticSize=Enum.AutomaticSize.Y
    },systems)
    list(systemCards,8)
    local systemNav=round(make("Frame",{
        BackgroundColor3=c.panel,BorderSizePixel=0,
        Size=UDim2.new(1,-17,0,42)
    },systems),8)
    local systemPage=label(systemNav,"PAGE 1",11,33,c.muted,true)
    systemPage.Position=UDim2.fromOffset(163,4)
    systemPage.Size=UDim2.fromOffset(215,35)
    systemPage.TextXAlignment=Enum.TextXAlignment.Center
    local function matches(entry)
        if category=="Favourites" and not s.favourites[entry.title] then return false end
        if category~="All" and category~="Favourites" and entry.category~=category then
            return false end
        local term=string.lower(atlasSearch.Text or "")
        if term=="" then return true end
        local hay=string.lower((entry.title or "").." "..(entry.detail or "")..
            " "..(entry.tag or "").." "..(entry.source or ""))
        return string.find(hay,term,1,true)~=nil
    end
    local function regenerateSystems()
        for _,item in ipairs(systemCards:GetChildren()) do
            if item:IsA("GuiObject") then item:Destroy()end
        end
        local found={}
        for _,entry in ipairs(ctx.atlas) do if matches(entry) then
            found[#found+1]=entry end
        end
        table.sort(found,function(a,b)
            local favA=s.favourites[a.title] and 1 or 0
            local favB=s.favourites[b.title] and 1 or 0
            if favA~=favB then return favA>favB end
            return a.title<b.title
        end)
        local lastPage=math.max(1,math.ceil(#found/6))
        atlasPage=math.clamp(atlasPage,1,lastPage)
        for i=(atlasPage-1)*6+1,math.min(atlasPage*6,#found) do
            local entry=found[i]
            local f,d=card(systemCards,entry.title,entry.detail,151,entry.tag)
            d.Size=UDim2.new(1,-32,0,91)
            local sourceLabel=label(f,"SOURCE: "..tostring(entry.source),9,20,c.dim)
            sourceLabel.Position=UDim2.fromOffset(15,127)
            sourceLabel.Size=UDim2.new(1,-70,0,20)
            local fav=textButton(f,s.favourites[entry.title] and "★" or "☆",
                c.panel2,function()
                    ctx.toggleFavourite(entry.title)
                    regenerateSystems()
                end)
            fav.Size=UDim2.fromOffset(31,25)
            fav.Position=UDim2.new(1,-47,1,-32)
            fav.TextColor3=s.favourites[entry.title] and c.amber or c.muted
        end
        if #found==0 then
            card(systemCards,"NOTHING MATCHED",
                "Try another search or category. Disabled features are documented, not automatically unlockable.",104)
        end
        systemPage.Text=string.format("PAGE %d/%d  •  %d SYSTEMS",
            atlasPage,lastPage,#found)
    end
    renderSystems=regenerateSystems
    for i,categoryName in ipairs(categories) do
        local b=textButton(searchCard,categoryName,c.panel2,function()
            category=categoryName;atlasPage=1;regenerateSystems()
        end)
        b.Size=UDim2.fromOffset(61,30);b.TextSize=9
        b.Position=UDim2.fromOffset(10+(i-1)*66,54)
    end
    local prev=textButton(systemNav,"PREV",c.panel2,function()
        atlasPage=math.max(1,atlasPage-1);regenerateSystems()
    end)
    prev.Size=UDim2.fromOffset(107,28);prev.Position=UDim2.fromOffset(8,7)
    local next=textButton(systemNav,"NEXT",c.panel2,function()
        atlasPage=atlasPage+1;regenerateSystems()
    end)
    next.Size=UDim2.fromOffset(107,28)
    next.Position=UDim2.new(1,-115,0,7)
    atlasSearch:GetPropertyChangedSignal("Text"):Connect(function()
        atlasPage=1;regenerateSystems()
    end)
    -- Settings, preferences, testable presets and status export
    local settings=pages.SETTINGS
    heading(settings,"CONTROL & CUSTOMISATION")
    local themeCard=card(settings,"ACCENT COLOURS",
        "Change Aurora's controls, radar accent and status markers.",107,"STYLE")
    for i,pair in ipairs({{"TEAL","teal"},{"VIOLET","violet"},{"CORAL","coral"}}) do
        local b=textButton(themeCard,pair[1],c[pair[2]],function()
            ctx.setTheme(pair[2])
        end)
        b.Size=UDim2.fromOffset(130,32)
        b.Position=UDim2.fromOffset(14+(i-1)*148,67)
    end
    action(settings,"COMFORT PRESET",
        "Steady camera, subtle brighter vision and native performance mode.",
        "APPLY",function()
            for _,key in ipairs({"calm","vision","performance"}) do
                if not s.flags[key] then ctx.toggle(key,true) end
            end
            ops.log("Comfort preset armed.")
        end,"PRESET")
    action(settings,"EXPLORER PRESET",
        "Enable local name tags, outlines and visual radar, but keep through-walls OFF.",
        "APPLY",function()
            if s.flags.throughWalls then ctx.toggle("throughWalls",false) end
            for _,key in ipairs({"playerFinder","tags","outlines","alerts"}) do
                if not s.flags[key] then ctx.toggle(key,true) end
            end
            ops.log("Explorer preset armed; through-wall overlays stay OFF.")
        end,"PRESET")
    action(settings,"SURVIVAL PRESET",
        "Turn on survival alerts and keep the overview ready; doesn't fabricate resource values.",
        "APPLY",function()
            if not s.flags.alerts then ctx.toggle("alerts",true) end
            ops.log("Survival alert preset armed.")
        end,"PRESET")
    toggle(settings,"localAutosave","OPTIONAL LOCAL SESSION HISTORY",
        "Save up to sixty own-status snapshots to the executor folder every two minutes. Not uploaded to GitHub.","LOCAL")
    action(settings,"SAVE REPORT NOW",
        "Write a privacy-limited own-state JSON history file to local executor storage.",
        "SAVE LOCAL",function()ctx.saveStatusFile()end,"REPORT")
    action(settings,"COPY LIVE STATUS",
        "Copy a concise own-character status to your clipboard. Clipboard is not GitHub sync.",
        "COPY STATUS",function()
            local success,result=ctx.copyStatus()
            if not success then ops.log("Clipboard unavailable; inspect report via executor.")
            end
        end,"EXPORT")
    toggle(settings,"miniHUD","LEGACY SMALL HUD OPTION",
        "A legacy engine setting. The operations rail already shows your needs without hiding the main hub.","UI FLAG")
    local historyCard,historyText=card(settings,"YOUR SESSION",
        "Activity and local history are not automatically sent to GitHub.",117,"LIVE")
    card(settings,"CODE VS REAL GAME STATE",
        "The GitHub repo stores the source and research. It doesn't automatically receive live Velocity reports. Native Rest requests, local speed inputs, status flags, client resource scanning and server rewards have different authority.",139,"TRANSPARENCY")
    -- A genuinely functional independent compact HUD (no inert setting).
    local miniHUD=round(make("Frame",{
        Name="AuroraV3CompactStatus",BackgroundColor3=c.bg,
        BackgroundTransparency=.10,BorderSizePixel=0,
        Position=UDim2.new(1,-286,0,93),
        Size=UDim2.fromOffset(270,93),
        Visible=false
    },gui),12)
    stroke(miniHUD,c.teal,.45)
    local miniTitle=label(miniHUD,"✦  AURORA  /  MINI HUD",10,24,c.teal,true)
    miniTitle.Position=UDim2.fromOffset(12,7)
    miniTitle.Size=UDim2.fromOffset(250,22)
    local miniBody=label(miniHUD,"Spawn an animal for live stats.",
        11,58,c.text,true)
    miniBody.Position=UDim2.fromOffset(12,30)
    miniBody.Size=UDim2.fromOffset(248,55)
    -- Global command palette (Ctrl+K), with eight curated actions and search.
    local modal=make("Frame",{
        Name="CommandPalette",BackgroundColor3=Color3.fromRGB(4,9,16),
        BackgroundTransparency=.20,BorderSizePixel=0,Size=UDim2.fromScale(1,1),
        Visible=false,ZIndex=100},gui)
    local palette=round(make("Frame",{
        AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,.17),
        Size=UDim2.fromOffset(492,410),BackgroundColor3=c.shell,
        BorderSizePixel=0,ZIndex=102
    },modal),14)
    stroke(palette,accent(),.3)
    local paletteTitle=label(palette,"⌕  QUICK COMMANDS",14,36,c.text,true)
    paletteTitle.Position=UDim2.fromOffset(18,10)
    paletteTitle.Size=UDim2.fromOffset(440,32)
    paletteTitle.ZIndex=103
    local paletteSearch=round(make("TextBox",{
        PlaceholderText="Type a feature, page or action...",
        Text="",ClearTextOnFocus=false,Font=Enum.Font.Gotham,
        TextColor3=c.text,PlaceholderColor3=c.dim,
        TextSize=13,BackgroundColor3=c.panel2,BorderSizePixel=0,
        Position=UDim2.fromOffset(15,55),Size=UDim2.fromOffset(462,40),
        ZIndex=103
    },palette),9)
    make("UIPadding",{PaddingLeft=UDim.new(0,12)},paletteSearch)
    local commands={
        {"Open player radar",function()showPage("RADAR")end},
        {"Find food",function()showPage("SURVIVAL");ctx.findResources("food")end},
        {"Find water",function()showPage("SURVIVAL");ctx.findResources("water")end},
        {"Focus closest player",function()showPage("RADAR");ops.focusClosest()end},
        {"Recovery assist",function()ctx.toggle("recovery")end},
        {"Toggle ESP",function()ctx.toggle("playerFinder")end},
        {"Open effects",function()showPage("EFFECTS")end},
        {"Open waypoints",function()showPage("WAYPOINTS")end},
        {"Mechanics atlas",function()showPage("SYSTEMS")end},
        {"Brightness switch",function()ctx.toggle("vision")end},
        {"Calm camera",function()ctx.toggle("calm")end},
        {"Save status locally",function()ctx.saveStatusFile()end},
        {"Emergency restore all",function()ctx.reset()end}
    }
    local commandRows={}
    local function closePalette()
        modal.Visible=false;paletteSearch:ReleaseFocus()
    end
    for i=1,8 do
        local entry
        local b=textButton(palette,"",c.panel2,function()
            if commandRows[i] and commandRows[i].action then
                closePalette();commandRows[i].action()
            end
        end)
        b.Position=UDim2.fromOffset(15,105+(i-1)*36)
        b.Size=UDim2.fromOffset(462,33)
        b.ZIndex=103;b.TextXAlignment=Enum.TextXAlignment.Left
        commandRows[i]={button=b,action=nil}
    end
    local function refreshCommands()
        local q=string.lower(paletteSearch.Text or "")
        local matched={}
        for _,entry in ipairs(commands) do
            if q=="" or string.find(string.lower(entry[1]),q,1,true) then
                matched[#matched+1]=entry
            end
        end
        for i,row in ipairs(commandRows) do
            local entry=matched[i]
            row.button.Visible=entry~=nil
            row.action=entry and entry[2] or nil
            if entry then row.button.Text="   ↳  "..entry[1]end
        end
    end
    launchPalette=function()
        modal.Visible=true;paletteSearch.Text="";refreshCommands()
        paletteSearch:CaptureFocus()
    end
    paletteSearch:GetPropertyChangedSignal("Text"):Connect(refreshCommands)
    -- Layout / UI lifecycle
    local globalConnections={}
    local function connect(signal,fn)
        local r=signal:Connect(fn);globalConnections[#globalConnections+1]=r
        return r
    end
    ctx.cleanupUI=function()
        for _,connection in ipairs(globalConnections) do
            pcall(function()connection:Disconnect()end)
        end
    end
    local dragging=false
    local dragPos,oldPos
    top.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true;dragPos=input.Position;oldPos=main.Position
        end
    end)
    connect(UIS.InputChanged,function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement
            or input.UserInputType==Enum.UserInputType.Touch) then
            local d=input.Position-dragPos
            main.Position=UDim2.new(oldPos.X.Scale,oldPos.X.Offset+d.X,
                oldPos.Y.Scale,oldPos.Y.Offset+d.Y)
        end
    end)
    connect(UIS.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end)
    connect(UIS.InputBegan,function(input,processed)
        if input.KeyCode==Enum.KeyCode.Escape and modal.Visible then
            closePalette();return
        end
        if processed or UIS:GetFocusedTextBox() then return end
        if input.KeyCode==Enum.KeyCode.RightShift then toggleHidden()
        elseif input.KeyCode==Enum.KeyCode.K and
            (UIS:IsKeyDown(Enum.KeyCode.LeftControl)
            or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then launchPalette()
        end
    end)
    -- Refresh: no widget reallocation on heartbeats.
    local function refresh()
        if not s.alive or not gui.Parent then return end
        local a=ctx.stats()
        local target=ops.targetInfo()
        phaseText.Text="●  "..tostring(a.sessionPhase)
        phaseText.TextColor3=a.sessionPhase=="IN GAME" and c.teal or c.amber
        miniHUD.Visible=s.flags.miniHUD
        miniTitle.TextColor3=accent()
        miniBody.Text=a.sessionPhase=="IN GAME"
            and ("HP "..fmt(a.hp,0).."/"..fmt(a.maxHp,0)
                .."    ST "..fmt(a.stamina,1).."/"..fmt(a.maxStamina,1)
                .."\nHUNGER "..fmt(a.hunger,0)
                .."    THIRST "..fmt(a.thirst,0)
                .."\n"..tostring(a.species).." / "..tostring(a.mode))
            or "ANIMAL MENU  /  no active animal stats"
        heroLabel.Text=a.sessionPhase=="IN GAME" and
            (tostring(a.species).."  /  "..tostring(a.stage)) or
            ("ANIMAL MENU  /  FIELD TOOLS READY")
        heroSub.Text=a.sessionPhase=="IN GAME"
            and ("Move: "..a.mode.."   •   "..fmt(a.speed,1)..
                " studs/s   •   Amber "..fmt(a.amber,0))
            or "Live animal stats appear after spawning. Radar can use the menu camera."
        animalText.Text=tostring(a.species).."  /  "..tostring(a.stage)
        setHP(a.hp,a.maxHp)
        setStamina(a.stamina,a.maxStamina)
        setHunger(a.hunger,100)
        setThirst(a.thirst,100)
        focusName.Text=string.sub(tostring(target.name),1,29)
        focusDetails.Text=target.summary
        local effectsNow=ctx.effects()
        conditionsInfo.Text=table.concat(effectsNow,"  ·  ")
        logInfo.Text=ops.sessionNotes[#ops.sessionNotes] or
            "No operations yet. Choose a player on radar or pin a landmark."
        local live=(a.sessionPhase=="IN GAME")
        needsInfo.Text=ctx.resourceHelp()
        local stateLine=ctx.featureStatus("playerFinder")
        radarSummary.Text=string.format(
            "ORIGIN  %s\nRANGE  %d studs\nNEARBY  %d living\nOVERLAY  %s",
            ops.origin or "CAMERA",s.range,#ops.getRadar(),
            s.flags.playerFinder and "ON" or "OFF")
        finderOrigin.Text=s.finderReason
        radarFinder.Text=s.flags.playerFinder and "DISABLE WORLD OVERLAY" or "ENABLE WORLD OVERLAY"
        alertButton.Text=ops.nearAlerts and "NEARBY ALERTS ON" or "NEARBY ALERTS OFF"
        local dotsData=ops.radar
        for i,item in ipairs(dots) do
            local p=dotsData[i]
            item.entry=p
            item.button.Visible=p~=nil
            if p then
                -- Dot positions are scale coordinates, not pixel offsets.
                -- Clamp diagonals to the circular radar boundary.
                local length=math.sqrt(p.x*p.x+p.y*p.y)
                local weight=length>1 and 1/length or 1
                item.button.Position=UDim2.fromScale(
                    .5+p.x*weight*.455,.5+p.y*weight*.455)
                item.button.BackgroundColor3=p.focused and c.violet
                    or p.distance<140 and c.teal or p.distance<340 and c.amber
                    or c.coral
                item.button.Text=p.focused and "★" or "•"
            end
        end
        for i,b in ipairs(playerButtons) do
            local p=dotsData[i]
            b.Visible=p~=nil
            if p then
                b.Text=string.format("%d.  %s  /  %s   •   %.0f studs  •  %.0f HP",
                    i,string.sub(p.name,1,20),tostring(p.species),
                    p.distance,p.hp)
                b.BackgroundColor3=p.focused and c.panel2 or c.panel2
                b.TextColor3=p.focused and c.violet or c.text
            end
        end
        local r=s.resource
        resultsDesc.Text=r.summary.."  /  results are name matches, not confirmed edible or drinkable."
        for i,b in ipairs(resourceButtons) do
            local item=r.candidates[i]
            b.Visible=item~=nil
            if item then
                b.Text=string.format("%d  •  %s    %.0f studs   ↗ FOCUS",
                    i,string.sub(item.name,1,24),item.distance)
            end
        end
        local char=localPlayer.Character
        local serverNow=workspace:GetServerTimeNow()
        for _,row in ipairs(effectRows) do
            local v=row.key=="FeralRegrowLeft" and
                localPlayer:GetAttribute(row.key) or char and char:GetAttribute(row.key)
            local active=(v==true) or type(v)=="number" and v>0 or
                type(v)=="string" and v~=""
            if row.key=="FeralThriveUntil" or row.key=="FeralHobbledUntil" then
                active=type(v)=="number" and v>serverNow
            end
            row.view.Text=not live and "MENU" or active and "●  PRESENT" or "NOT OBSERVED"
            row.view.TextColor3=active and live and c.green or c.dim
        end
        waypointInfo.Text=target.summary
        for key,buttons in pairs(toggles) do
            for _,b in ipairs(buttons) do
                b.Text=s.flags[key] and "ON" or "OFF"
                b.TextColor3=s.flags[key] and c.bg or c.muted
                b.BackgroundColor3=s.flags[key] and accent() or c.panel2
            end
        end
        local highlights={"finder","rest","camera","vision"}
        local keys={finder="playerFinder",rest="recovery",camera="calm",
            vision="vision"}
        for _,key in ipairs(highlights) do
            local b=quickButtons[key]
            if b then
                b.BackgroundColor3=s.flags[keys[key]] and accent() or c.panel2
                b.TextColor3=s.flags[keys[key]] and c.bg or c.text
            end
        end
        historyText.Text=ops.summary()..
            "\nLocal report: "..s.localSaveResult
        toast.Text=s.notice
        heroLine.BackgroundColor3=accent()
        rightTitle.TextColor3=accent()
        statusLine.Text=s.flags.recovery and ctx.featureStatus("recovery")
            or "Rest helper OFF • server bonus never assumed."
        if main.Visible then scaleToScreen() end
    end
    local reportedError=false
    ctx.onUI=function()
        local ok,err=pcall(refresh)
        if not ok and not reportedError then
            reportedError=true
            ctx.notice("Aurora view refresh error: "..string.sub(tostring(err),1,110))
        end
    end
    ctx.onNotice=function()if toast and toast.Parent then toast.Text=s.notice end end
    renderPins()
    renderResources=function() refresh() end
    regenerateSystems()
    showPage("DASHBOARD")
    refresh()
    return gui
end
return UI
