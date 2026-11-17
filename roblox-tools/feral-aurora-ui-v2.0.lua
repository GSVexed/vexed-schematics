-- FERAL AURORA v2.0 / polished page-based Roblox interface
-- Constructed from native Roblox UI instances. No external UI framework.
local UI={}
local UIS=game:GetService("UserInputService")
local Tween=game:GetService("TweenService")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local function ui(class,props,parent)
    local o=Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    if parent then o.Parent=parent end
    return o
end
local function round(o,r)
    ui("UICorner",{CornerRadius=UDim.new(0,r or 10)},o);return o
end
local function border(o,color,alpha)
    ui("UIStroke",{Thickness=1,Color=color,Transparency=alpha or .4},o)
end
local function label(parent,str,size,height,color,bold,wrap)
    return ui("TextLabel",{
        BackgroundTransparency=1,Text=str or "",TextColor3=color,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=size or 12,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=wrap~=false,
        Size=UDim2.new(1,0,0,height or 24),RichText=false
    },parent)
end
local function button(parent,title,w,h,color,callback)
    local b=round(ui("TextButton",{
        BackgroundColor3=color,BorderSizePixel=0,
        TextColor3=Color3.fromRGB(242,247,255),Text=title,
        Font=Enum.Font.GothamBold,TextSize=12,
        Size=UDim2.fromOffset(w or 120,h or 32),AutoButtonColor=true
    },parent),9)
    -- Subtle interaction shimmer; changes only UI styling, never game state.
    local glow=ui("UIStroke",{Color=Color3.fromRGB(240,249,255),
        Transparency=1,Thickness=1},b)
    b.MouseEnter:Connect(function()
        Tween:Create(glow,TweenInfo.new(.14),{Transparency=.42}):Play()
    end)
    b.MouseLeave:Connect(function()
        Tween:Create(glow,TweenInfo.new(.18),{Transparency=1}):Play()
    end)
    if callback then b.Activated:Connect(callback) end
    return b
end
local function column(parent,gap)
    return ui("UIListLayout",{
        FillDirection=Enum.FillDirection.Vertical,
        SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,gap or 10)
    },parent)
end
local function pad(parent,left,right,top,bottom)
    return ui("UIPadding",{
        PaddingLeft=UDim.new(0,left or 0),PaddingRight=UDim.new(0,right or left or 0),
        PaddingTop=UDim.new(0,top or 0),PaddingBottom=UDim.new(0,bottom or 0)
    },parent)
end
function UI.mount(ctx)
    local s,c=ctx.state,ctx.palette
    local pg=player:FindFirstChildOfClass("PlayerGui")
        or player:WaitForChild("PlayerGui",8)
    if not pg then return nil end
    local gui=ui("ScreenGui",{
        Name="FeralAuroraHubV20",ResetOnSpawn=false,
        DisplayOrder=130,IgnoreGuiInset=false,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    },pg)
    ctx.ui=gui
    local shutdown=ui("BindableEvent",{Name="AuroraShutdown"},gui)
    shutdown.Event:Connect(function()ctx.close()end)
    local shell=round(ui("Frame",{
        Name="AuroraShell",AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(968,636),
        BackgroundColor3=c.bg,BorderSizePixel=0,Active=true
    },gui),17)
    border(shell,c.line,.1)
    ui("UIGradient",{Rotation=28,
        Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(14,27,39)),
            ColorSequenceKeypoint.new(.5,c.bg),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(15,17,31))
        })
    },shell)
    local scale=ui("UIScale",{Scale=1},shell)
    local function fitScale()
        local camera=workspace.CurrentCamera
        local size=camera and camera.ViewportSize or Vector2.new(1200,800)
        return math.clamp(math.min((size.X-24)/968,(size.Y-40)/636,1),.58,1)
    end
    local function useScale()
        scale.Scale=fitScale()*s.scale
    end
    useScale()
    local top=ui("Frame",{
        Name="TitleBar",Size=UDim2.new(1,0,0,73),
        BackgroundTransparency=1,Active=true
    },shell)
    local line=ui("Frame",{BackgroundColor3=c.line,BorderSizePixel=0,
        Position=UDim2.fromOffset(0,71),Size=UDim2.new(1,0,0,1)},shell)
    local brand=ui("Frame",{
        BackgroundColor3=ctx.accent(),BorderSizePixel=0,
        Position=UDim2.fromOffset(21,17),Size=UDim2.fromOffset(4,36)
    },top)
    round(brand,3)
    local name=ui("TextLabel",{
        BackgroundTransparency=1,Text="FERAL  /  AURORA",
        Font=Enum.Font.GothamBold,TextSize=23,TextColor3=c.text,
        TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(38,13),Size=UDim2.fromOffset(395,31)
    },top)
    local subt=ui("TextLabel",{
        BackgroundTransparency=1,Text="COMMAND CENTER    •    v2.0    •    74 SYSTEMS",
        Font=Enum.Font.Gotham,TextSize=10,TextColor3=c.dim,
        TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(40,43),Size=UDim2.fromOffset(435,22)
    },top)
    local statusPill=round(ui("Frame",{
        BackgroundColor3=c.panel,BorderSizePixel=0,
        Position=UDim2.fromOffset(544,17),Size=UDim2.fromOffset(198,33)
    },top),8)
    local statusPillText=ui("TextLabel",{
        Text="●   CLIENT ONLINE",TextColor3=c.teal,TextSize=11,
        Font=Enum.Font.GothamBold,BackgroundTransparency=1,
        Size=UDim2.fromScale(1,1)
    },statusPill)
    local openMini
    local hidden=false
    local function hidePanel()
        hidden=not hidden;s.hidden=hidden
        shell.Visible=not hidden
        openMini.Visible=hidden
    end
    local mini=button(top,"—",39,32,c.panel2,function()hidePanel()end)
    mini.Position=UDim2.fromOffset(764,17)
    local theme=button(top,"◐",39,32,c.panel2,function()
        local all={"teal","violet","coral"}
        local index=table.find(all,s.theme) or 1
        ctx.setTheme(all[index%#all+1])
    end)
    theme.Position=UDim2.fromOffset(811,17)
    local zoom=button(top,"⤢",39,32,c.panel2,function()
        if s.scale>=1.08 then ctx.setScale(.78)
        else ctx.setScale(s.scale+.10) end
        useScale()
    end)
    zoom.Position=UDim2.fromOffset(858,17)
    local exit=button(top,"×",39,32,c.red,function()ctx.close()end)
    exit.Position=UDim2.fromOffset(905,17)
    openMini=button(gui,"✦  AURORA",131,38,c.panel,function()hidePanel()end)
    openMini.Visible=false
    openMini.Position=UDim2.new(0,18,.42,0)
    border(openMini,ctx.accent(),.15)
    local sidebar=round(ui("Frame",{
        Name="Sidebar",BackgroundColor3=c.shell,BorderSizePixel=0,
        Position=UDim2.fromOffset(12,85),
        Size=UDim2.fromOffset(185,494)
    },shell),12)
    border(sidebar,c.line,.65)
    local navLabel=ui("TextLabel",{
        Text="NAVIGATION",Font=Enum.Font.GothamBold,TextSize=10,
        BackgroundTransparency=1,TextColor3=c.dim,
        Position=UDim2.fromOffset(15,12),Size=UDim2.fromOffset(148,22),
        TextXAlignment=Enum.TextXAlignment.Left
    },sidebar)
    local main=ui("Frame",{
        Name="Main",BackgroundTransparency=1,
        Position=UDim2.fromOffset(207,84),Size=UDim2.fromOffset(748,496)
    },shell)
    local sectionTitle=ui("TextLabel",{
        BackgroundTransparency=1,Text="Your wild, at a glance.",
        Font=Enum.Font.GothamBold,TextSize=19,TextColor3=c.text,
        Position=UDim2.fromOffset(5,0),Size=UDim2.fromOffset(724,30),
        TextXAlignment=Enum.TextXAlignment.Left
    },main)
    local sectionSub=ui("TextLabel",{
        BackgroundTransparency=1,Text="Live statistics and your most useful tools.",
        Font=Enum.Font.Gotham,TextSize=11,TextColor3=c.muted,
        Position=UDim2.fromOffset(7,31),Size=UDim2.fromOffset(724,24),
        TextXAlignment=Enum.TextXAlignment.Left
    },main)
    local dock=ui("Frame",{
        BackgroundTransparency=1,Position=UDim2.fromOffset(12,587),
        Size=UDim2.fromOffset(944,34)
    },shell)
    ui("Frame",{BackgroundColor3=c.line,BorderSizePixel=0,
        Size=UDim2.new(1,0,0,1)},dock)
    local notice=ui("TextLabel",{
        Text=s.notice,TextSize=10,TextColor3=c.muted,
        Font=Enum.Font.Gotham,TextTruncate=Enum.TextTruncate.AtEnd,
        BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(8,6),Size=UDim2.fromOffset(710,25)
    },dock)
    local reset=button(dock,"RESTORE ALL",166,29,c.red,function()ctx.reset()end)
    reset.Position=UDim2.fromOffset(775,3)
    local pages={}
    local navButtons={}
    local navData={
        {"HOME","⌂"},{"RECOVERY","✚"},{"MOVEMENT","➤"},
        {"PLAYER FINDER","◉"},{"AMBER","◈"},{"PROGRESSION","△"},
        {"WORLD","◎"},{"ATLAS","▤"},{"SETTINGS","⚙"}
    }
    local pageTitles={
        ["HOME"]={"Your animal, at a glance.","Live status and instant access to the essentials."},
        ["RECOVERY"]={"Recovery & conditions","Native Rest requests, survival status and recovery research."},
        ["MOVEMENT"]={"Movement & comfort","Native camera settings and reversible client experiments."},
        ["PLAYER FINDER"]={"Player finder / visual ESP","Beautiful nametags, character outlines and a live proximity list."},
        ["AMBER"]={"Amber & multiplier intelligence","Reward information, an earnings calculator and native earned rewards."},
        ["PROGRESSION"]={"Growth, thriving & elder","Understand temporary boosts and growth progression."},
        ["WORLD"]={"Territory & world","Replicated buffs, destination bearings and world systems."},
        ["ATLAS"]={"The mechanics atlas","Search 74 catalogued mechanics, hidden flags and server-gated features."},
        ["SETTINGS"]={"Style, safety & session","Themes, preferences, presets, reset and export."}
    }
    local function createPage(key)
        local frame=ui("ScrollingFrame",{
            Name=key,BackgroundTransparency=1,BorderSizePixel=0,
            Position=UDim2.fromOffset(0,64),Size=UDim2.fromOffset(741,420),
            ScrollBarThickness=4,ScrollBarImageColor3=c.line,
            AutomaticCanvasSize=Enum.AutomaticSize.Y,
            CanvasSize=UDim2.fromOffset(0,0),
            ScrollingDirection=Enum.ScrollingDirection.Y,
            Visible=false
        },main)
        pad(frame,3,9,2,12)
        column(frame,11)
        pages[key]=frame
        return frame
    end
    for _,entry in ipairs(navData) do createPage(entry[1]) end
    local current="HOME"
    local rerenderAtlas=function() end
    local function showPage(key)
        current=key
        for name,p in pairs(pages) do p.Visible=name==key end
        for name,b in pairs(navButtons) do
            b.BackgroundColor3=name==key and c.panel2 or c.shell
            b.TextColor3=name==key and ctx.accent() or c.muted
        end
        local v=pageTitles[key]
        sectionTitle.Text=v[1];sectionSub.Text=v[2]
        if key=="ATLAS" then
            if ctx.atlasReady then
                sectionSub.Text=tostring(#ctx.atlas).." entries • filter, search and favourite."
            end
            rerenderAtlas()
        end
    end
    for i,entry in ipairs(navData) do
        local key,icon=entry[1],entry[2]
        local b=button(sidebar,icon.."   "..key,163,37,c.shell,function()
            showPage(key)
        end)
        b.Position=UDim2.fromOffset(11,36+(i-1)*46)
        b.TextXAlignment=Enum.TextXAlignment.Left
        b.TextSize=11
        navButtons[key]=b
    end
    local hotkey=ui("TextLabel",{
        Text="RIGHT SHIFT  ·  SHOW / HIDE",Font=Enum.Font.Gotham,
        TextSize=9,TextColor3=c.dim,BackgroundTransparency=1,
        Position=UDim2.fromOffset(11,457),Size=UDim2.fromOffset(166,22)
    },sidebar)
    -- Reusable card primitives
    local function card(parent,title,desc,height,tag)
        local frame=round(ui("Frame",{
            BackgroundColor3=c.panel,BorderSizePixel=0,
            Size=UDim2.new(1,-16,0,height or 104)
        },parent),11)
        border(frame,c.line,.6)
        local t=ui("TextLabel",{
            Text=title,Font=Enum.Font.GothamBold,TextSize=14,TextColor3=c.text,
            Position=UDim2.fromOffset(15,9),Size=UDim2.new(1,-35,0,23),
            BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left
        },frame)
        local d=ui("TextLabel",{
            Text=desc or "",Font=Enum.Font.Gotham,TextSize=11,
            TextColor3=c.muted,TextWrapped=true,
            TextYAlignment=Enum.TextYAlignment.Top,
            TextXAlignment=Enum.TextXAlignment.Left,
            BackgroundTransparency=1,Position=UDim2.fromOffset(15,36),
            Size=UDim2.new(1,-30,0,math.max(24,(height or 104)-46))
        },frame)
        if tag then
            local pill=round(ui("Frame",{
                BackgroundColor3=c.panel2,BorderSizePixel=0,
                Position=UDim2.new(1,-125,0,12),Size=UDim2.fromOffset(110,19)
            },frame),5)
            local tt=ui("TextLabel",{
                BackgroundTransparency=1,Text=tag,TextSize=9,
                Font=Enum.Font.GothamBold,TextColor3=c.dim,
                Size=UDim2.fromScale(1,1)
            },pill)
            t.Size=UDim2.new(1,-165,0,23)
        end
        return frame,d
    end
    local toggles={}
    local function switch(parent,key,title,desc,tag)
        local f,d=card(parent,title,desc,93,tag)
        d.Size=UDim2.new(1,-112,0,51)
        local b=button(f,"OFF",76,34,c.panel2,function()
            ctx.toggle(key)
        end)
        b.Position=UDim2.new(1,-92,0,43)
        toggles[key]=toggles[key] or {}
        toggles[key][#toggles[key]+1]=b
        return f,b
    end
    local function action(parent,title,desc,name,callback,tag)
        local f,d=card(parent,title,desc,109,tag)
        d.Size=UDim2.new(1,-195,0,58)
        local b=button(f,name,170,31,c.panel2,callback)
        b.Position=UDim2.new(1,-186,1,-40)
        return f,b
    end
    local function metric(parent,title,color)
        local f=round(ui("Frame",{
            BackgroundColor3=c.panel,BorderSizePixel=0,
            Size=UDim2.fromOffset(218,90)
        },parent),10)
        border(f,c.line,.6)
        local small=ui("TextLabel",{
            Text=title,BackgroundTransparency=1,Font=Enum.Font.GothamBold,
            TextSize=10,TextColor3=c.dim,TextXAlignment=Enum.TextXAlignment.Left,
            Position=UDim2.fromOffset(12,10),Size=UDim2.fromOffset(190,18)
        },f)
        local value=ui("TextLabel",{
            Text="--",BackgroundTransparency=1,Font=Enum.Font.GothamBold,
            TextSize=24,TextColor3=color,TextXAlignment=Enum.TextXAlignment.Left,
            Position=UDim2.fromOffset(12,32),Size=UDim2.fromOffset(193,40)
        },f)
        return value
    end
    local function setDynamicText(frame,desc)
        desc.TextWrapped=true
        desc.TextYAlignment=Enum.TextYAlignment.Top
    end
    local function pretty(n,d)
        return type(n)=="number" and n==n and string.format("%."..tostring(d or 1).."f",n) or "--"
    end
    -- HOME / HERO
    local home=pages.HOME
    local hero=round(ui("Frame",{BackgroundColor3=Color3.fromRGB(25,46,62),
        Size=UDim2.new(1,-16,0,112),BorderSizePixel=0},home),12)
    ui("UIGradient",{Rotation=10,Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(29,75,80)),
        ColorSequenceKeypoint.new(.58,Color3.fromRGB(37,48,76)),
        ColorSequenceKeypoint.new(1,c.panel2)
    })},hero)
    ui("TextLabel",{
        Text="YOUR WILD. YOUR CONTROL.",Font=Enum.Font.GothamBold,TextSize=17,
        BackgroundTransparency=1,TextColor3=c.text,
        TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(17,10),Size=UDim2.fromOffset(560,30)
    },hero)
    local heroSpecies=ui("TextLabel",{
        Text="Waiting for a living animal",Font=Enum.Font.Gotham,
        TextSize=12,BackgroundTransparency=1,TextColor3=c.muted,
        TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(18,38),Size=UDim2.fromOffset(620,25)
    },hero)
    local h1=button(hero,"RECOVERY",134,29,c.panel,function()showPage("RECOVERY")end)
    h1.Position=UDim2.fromOffset(15,74)
    local h2=button(hero,"PLAYER FINDER",154,29,c.panel,function()showPage("PLAYER FINDER")end)
    h2.Position=UDim2.fromOffset(157,74)
    local h3=button(hero,"ATLAS",114,29,c.panel,function()showPage("ATLAS")end)
    h3.Position=UDim2.fromOffset(319,74)
    local h4=button(hero,"SAFE RESET",125,29,c.red,function()ctx.reset()end)
    h4.Position=UDim2.fromOffset(440,74)
    local statsHolder=ui("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,-16,0,193)},home)
    ui("UIGridLayout",{
        CellSize=UDim2.fromOffset(218,90),CellPadding=UDim2.fromOffset(13,11),
        SortOrder=Enum.SortOrder.LayoutOrder
    },statsHolder)
    local statValues={
        hp=metric(statsHolder,"HEALTH",c.green),
        stamina=metric(statsHolder,"STAMINA",c.teal),
        amber=metric(statsHolder,"AMBER",c.amber),
        hunger=metric(statsHolder,"HUNGER",c.text),
        thirst=metric(statsHolder,"THIRST",c.text),
        growth=metric(statsHolder,"GROWTH",c.violet)
    }
    local effCard,effText=card(home,"ACTIVE CONDITIONS","Waiting for a character...",122,"LIVE")
    local activeCard,activeText=card(home,"ENABLED TOOLS","No tools active.",96,"LIVE")
    local nearCard,nearText=card(home,"PLAYER RADAR","Player Finder is off.",97,"LOCAL")
    -- RECOVERY
    local recovery=pages.RECOVERY
    card(recovery,"BEFORE YOU BEGIN",
        "No tool can promise invulnerability. FERAL controls real health, combat and death on the server; Recovery Assist only sends native requests.",96,"HONEST STATUS")
    switch(recovery,"recovery","RECOVERY ASSIST",
        "When injured, bleeding, poisoned or below full HP, request the game's native Rest effect while masking only your own local rest pose.","NATIVE")
    switch(recovery,"alerts","SMART SURVIVAL ALERTS",
        "Warn when hunger/thirst are under 20 or when a visible exhaustion state is detected. No resource changes.","LOCAL")
    local restCard,restDetail=card(recovery,"RECOVERY SIGNAL STATUS","No packets sent.",92,"LIVE")
    local conditionCard,conditionDetail=card(recovery,"CONDITION MONITOR","No current status data.",113,"LIVE")
    card(recovery,"REST EFFECT BREAKDOWN",
        "Configured rest bonuses: Health x2, stamina x3, and ailment-clearing multipliers around x4. The actual server may deny moving Rest, especially during Burst.",110,"CONFIG")
    card(recovery,"ABOUT THE 3× STAMINA LEGACY",
        "The old Recovery Hub v1.3 remains on GitHub, unchanged. Experimental stamina-pool tuning was involved in sessions with unexplained Burst deaths, so Aurora does not auto-load it.",113,"PARKED")
    -- MOVEMENT
    local move=pages.MOVEMENT
    card(move,"CLIENT CONTROL LIMITATIONS",
        "Local cached movement controls do not make server movement legal or prevent unexpected death. Everything here starts OFF.",90,"NOTICE")
    switch(move,"calm","CALM CAMERA",
        "Set native camera-shake to zero and turn off sway; restores the previous client settings when disabled.","COMFORT")
    switch(move,"vision","BRIGHTER WORLD",
        "Apply a subtle local brightness and colour-correction effect to improve readability.","VISUAL")
    switch(move,"performance","NATIVE PERFORMANCE MODE",
        "Ask FERAL to use its built-in performance option via local player settings.","COMFORT")
    switch(move,"mobility","INJURY SLOWDOWN INPUTS",
        "Experimental client cache: reduce HURT_SLOW and INJURY.SLOW_PER_POINT. Does not cure the server-held injury.","ADVANCED")
    switch(move,"speed","1.10× LAND / SWIM SPEED INPUTS",
        "Experimental reversible RUN_SPEED and SWIM_SPEED cache profile. No movement authority is promised.","ADVANCED")
    switch(move,"leap","1.10× FORWARD LEAP INPUTS",
        "Experimental reversible leap length and speed cap profile; no double-jump or flight grant.","ADVANCED")
    -- PLAYER FINDER
    local esp=pages["PLAYER FINDER"]
    card(esp,"VISUAL PLAYER TRACKER",
        "Outlines and name tags are drawn locally for characters already replicated to your client. This does not locate unstreamed or hidden server entities.",100,"LOCAL ONLY")
    switch(esp,"playerFinder","PLAYER FINDER / ESP",
        "Main switch. Adds the customised overlay to the nearest replicated players within range. Off clears every tag and outline.","MASTER")
    switch(esp,"tags","AESTHETIC NAME TAGS",
        "Floating dark-glass nameplates show display name, animal species, distance and a health bar.","DISPLAY")
    switch(esp,"outlines","CHARACTER OUTLINES",
        "Colour-coded character highlights. Teal nearby, amber mid-distance, coral at the edge of range.","DISPLAY")
    switch(esp,"throughWalls","THROUGH-WALL VISIBILITY",
        "Optional always-on-top outlines and name tags for replicated players behind terrain. OFF is visible-only.","OPT-IN")
    local distanceCard,distanceText=card(esp,"TRACKER RANGE",
        "Limit drawing distance to avoid visual clutter and excessive instances.",122,"PERFORMANCE")
    distanceText.Size=UDim2.new(1,-32,0,24)
    local rangeLine=ui("TextLabel",{
        Text="300 STUDS  /  24 PLAYER CAP",BackgroundTransparency=1,
        Font=Enum.Font.GothamBold,TextSize=12,TextColor3=c.teal,
        Position=UDim2.fromOffset(16,55),Size=UDim2.fromOffset(510,25),
        TextXAlignment=Enum.TextXAlignment.Left
    },distanceCard)
    for i,d in ipairs({150,300,600,900}) do
        local b=button(distanceCard,tostring(d),79,29,c.panel2,function()
            ctx.setRange(d)
        end)
        b.Position=UDim2.fromOffset(16+(i-1)*90,88)
    end
    local stylingCard,stylingInfo=card(esp,"OUTLINE LOOK & FEEL",
        "Choose a subtle or bold outline. Changes the local visual only.",115,"STYLE")
    local subtle=button(stylingCard,"SUBTLE",133,30,c.panel2,function()
        ctx.setOutlineStyle("subtle")
    end)
    subtle.Position=UDim2.fromOffset(15,76)
    local bold=button(stylingCard,"BOLD",133,30,c.panel2,function()
        ctx.setOutlineStyle("bold")
    end)
    bold.Position=UDim2.fromOffset(160,76)
    local nearbyCard,nearbyText=card(esp,"NEARBY PLAYER LIST",
        "Enable Player Finder to see replicated characters here.",138,"LIVE")
    nearbyText.Size=UDim2.new(1,-30,0,91)
    card(esp,"PRIVACY & PERFORMANCE",
        "Tracks at most 24 nearby living players. Disabling the master switch destroys all locally created Highlight and BillboardGui instances. No coordinates are uploaded.",103,"LOCAL")
    -- AMBER
    local amber=pages.AMBER
    local walletCard,walletText=card(amber,"YOUR AMBER WALLET","Waiting for a replicated balance.",94,"LIVE")
    local simulator,simDesc=card(amber,"SURVIVAL MULTIPLIER EXPLORER",
        "Estimated +0.1 per eligible 10 min to 2×, then per 15 min to 3×. Set hypothetical eligible time below.",166,"CONFIG")
    simDesc.Size=UDim2.new(1,-30,0,40)
    local simValue=ui("TextLabel",{
        Text="1.0×  /  0 eligible min",BackgroundTransparency=1,
        Font=Enum.Font.GothamBold,TextSize=20,TextColor3=c.amber,
        TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(17,75),Size=UDim2.fromOffset(585,32)
    },simulator)
    local function updateSim()
        simValue.Text=string.format("%.1f×  /  %d eligible min",
            ctx.survivalMultiplier(s.survivalMinutes),s.survivalMinutes)
    end
    for i,entry in ipairs({
        {"− 10",function() s.survivalMinutes=math.max(0,s.survivalMinutes-10) end},
        {"+ 10",function() s.survivalMinutes=math.min(250,s.survivalMinutes+10) end},
        {"+ 50",function() s.survivalMinutes=math.min(250,s.survivalMinutes+50) end},
        {"MAX 3×",function() s.survivalMinutes=250 end}
    }) do
        local b=button(simulator,entry[1],115,29,c.panel2,function()
            entry[2]();updateSim()
        end)
        b.Position=UDim2.fromOffset(16+(i-1)*123,125)
    end
    action(amber,"OPEN EARNED REWARDS",
        "Open FERAL's normal playtime/daily reward interface. No repeated claims or currency forgery.",
        "OPEN REWARDS",function()ctx.openNative("rewards")end,"NATIVE")
    action(amber,"OPEN ANIMAL GUIDE",
        "Use the native guide for progression and unlock information.",
        "OPEN GUIDE",function()ctx.openNative("guide")end,"NATIVE")
    card(amber,"GRAZING & HOME-TURF AMBER",
        "Config leads: 10 Amber per grazing minute; 5 Amber per owned hex per five minutes. Actual server earning and stacking have not been verified.",112,"RESEARCH")
    card(amber,"OTHER MULTIPLIERS",
        "Survival x1–x3 is distinct from the paid 2× Amber option, completion bonuses, Amber chunks and quest payouts. Which rewards stack remains unknown.",111,"RESEARCH")
    -- PROGRESSION
    local prog=pages.PROGRESSION
    local growCard,growText=card(prog,"GROWTH & LIFE STAGE","Waiting for animal.",106,"LIVE")
    local thriveCard,thriveText=card(prog,"THRIVING / TEMPORARY GROWTH","Waiting for state.",102,"LIVE")
    local regrowCard,regrowText=card(prog,"REGROWTH ALLOWANCE","Waiting for state.",97,"LIVE")
    card(prog,"THRIVING: +50% GROWTH",
        "Configured acceleration with a 600-second cap. Hunting, eating, drinking and quests are named ways to accumulate boost time.",106,"CONFIG")
    card(prog,"ELDER: STATS, BODY & SCARS",
        "The elder system defines health/damage/stamina scaling up to roughly +10%, stage growth up to 2.0, and separate elder scars/paint.",112,"CONFIG")
    card(prog,"REGROWTH: DIFFERENT FROM THRIVING",
        "RegrowConfig has a separate x2 growth mechanic capped to five minutes. HUD allowance and eligibility are server controlled.",110,"CONFIG")
    card(prog,"UNRELEASED LITTERMATES",
        "LitterConfig.ENABLED=false with sibling grouping, catch-up and graduation mechanics. Source presence does not imply that the feature is live.",110,"DISABLED")
    -- WORLD
    local world=pages.WORLD
    local turfCard,turfText=card(world,"TERRITORY & GRAZING",
        "Waiting for your replicated turf flags.",109,"LIVE")
    card(world,"DAMAGE BONUSES FROM TERRITORY",
        "Home Turf +10% and Grazing +20% damage are separately configured. Their stacking and actual server application have not been established.",112,"CONFIG")
    local navCard,navDesc=card(world,"LOCATION COMPASS",
        "Select a known point of interest. Aurora calculates distance and bearing from your character without teleporting.",130,"NAVIGATION")
    local compassText=ui("TextLabel",{
        Text="Spawn an animal to get a bearing.",BackgroundTransparency=1,
        Font=Enum.Font.GothamBold,TextSize=12,TextColor3=c.teal,
        Position=UDim2.fromOffset(16,74),Size=UDim2.new(1,-30,0,40),
        TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true
    },navCard)
    local poiCard,poiDetail=card(world,"DESTINATION QUICK SELECT",
        "18 recorded points of interest. Select one to update the compass above.",321,"18 POI")
    poiDetail.Size=UDim2.new(1,-35,0,22)
    for i,loc in ipairs(ctx.locations) do
        local selected=loc
        local b=button(poiCard,loc[1],212,32,c.panel2,function()
            s.chosenLocation=i
            ctx.notice("Compass destination: "..selected[1])
            ctx.onUI()
        end)
        b.TextSize=10
        b.TextTruncate=Enum.TextTruncate.AtEnd
        b.Position=UDim2.fromOffset(15+((i-1)%3)*224,
            73+math.floor((i-1)/3)*39)
    end
    card(world,"DROUGHTS, FLOODS & FISH",
        "The client contains drought pond ellipses, flooding zones, water-stage controls, fish paths and carcass/scavenger systems.",106,"WORLD")
    -- ATLAS
    local atlas=pages.ATLAS
    local findBox=round(ui("Frame",{
        BackgroundColor3=c.panel,BorderSizePixel=0,
        Size=UDim2.new(1,-16,0,103)
    },atlas),10)
    border(findBox,c.line,.5)
    local search=round(ui("TextBox",{
        Text="",PlaceholderText="Search mechanics, effects, multipliers, disabled flags...",
        ClearTextOnFocus=false,Font=Enum.Font.Gotham,TextSize=12,
        TextColor3=c.text,PlaceholderColor3=c.dim,BackgroundColor3=c.panel2,
        BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(11,10),Size=UDim2.new(1,-22,0,34)
    },findBox),8)
    pad(search,12,12,0,0)
    local filters={"All","Recovery","Economy","Progression","Territory",
        "Abilities","Hidden","Favourites"}
    local filterButtons={}
    for i,filter in ipairs(filters) do
        local b=button(findBox,filter,83,29,c.panel2,function()
            s.atlasCategory=filter;s.atlasPage=1
            rerenderAtlas()
            ctx.onUI()
        end)
        b.TextSize=9;b.Position=UDim2.fromOffset(10+(i-1)*87,58)
        filterButtons[filter]=b
    end
    local catalogHost=ui("Frame",{
        BackgroundTransparency=1,Size=UDim2.new(1,-16,0,0),
        AutomaticSize=Enum.AutomaticSize.Y
    },atlas)
    column(catalogHost,9)
    local pagination=round(ui("Frame",{
        BackgroundColor3=c.panel2,BorderSizePixel=0,
        Size=UDim2.new(1,-16,0,43)
    },atlas),9)
    local pageCount=ui("TextLabel",{
        Text="Page 1",Font=Enum.Font.GothamBold,TextSize=11,
        BackgroundTransparency=1,TextColor3=c.muted,
        Position=UDim2.fromOffset(163,4),Size=UDim2.fromOffset(382,32)
    },pagination)
    button(pagination,"PREV",131,29,c.panel,function()
        s.atlasPage=math.max(1,s.atlasPage-1);rerenderAtlas();ctx.onUI()
    end).Position=UDim2.fromOffset(10,7)
    button(pagination,"NEXT",131,29,c.panel,function()
        s.atlasPage=s.atlasPage+1;rerenderAtlas();ctx.onUI()
    end).Position=UDim2.new(1,-140,0,7)
    local filtered={}
    local lastCatalogSignature=""
    local function rebuildCatalog()
        local term=string.lower(search.Text or "")
        local tab=s.atlasCategory
        local matching={}
        for _,entry in ipairs(ctx.atlas) do
            local valid=tab=="All" or tab=="Favourites" and s.favourites[entry.title]
                or entry.category==tab
            local hay=string.lower((entry.title or "").." "..(entry.detail or "")..
                " "..(entry.source or "").." "..(entry.tag or ""))
            if valid and (term=="" or string.find(hay,term,1,true)) then
                matching[#matching+1]=entry
            end
        end
        table.sort(matching,function(a,b)
            local fa=s.favourites[a.title] and 1 or 0
            local fb=s.favourites[b.title] and 1 or 0
            if fa~=fb then return fa>fb end
            return a.title<b.title
        end)
        local maxPage=math.max(1,math.ceil(#matching/7))
        s.atlasPage=math.clamp(s.atlasPage,1,maxPage)
        for _,child in ipairs(catalogHost:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end
        for i=(s.atlasPage-1)*7+1,math.min(s.atlasPage*7,#matching) do
            local entry=matching[i]
            local row,detail=card(catalogHost,entry.title,entry.detail,116,entry.tag)
            detail.Position=UDim2.fromOffset(14,37)
            detail.Size=UDim2.new(1,-29,0,61)
            local source=ui("TextLabel",{
                BackgroundTransparency=1,
                Text="SOURCE  "..tostring(entry.source or "Recovered client code"),
                Font=Enum.Font.Gotham,TextSize=9,TextColor3=c.dim,
                TextXAlignment=Enum.TextXAlignment.Left,
                Position=UDim2.fromOffset(15,99),
                Size=UDim2.new(1,-75,0,14),
                TextTruncate=Enum.TextTruncate.AtEnd
            },row)
            local favourite=button(row,s.favourites[entry.title] and "★" or "☆",
                32,27,c.panel2,function()
                    ctx.toggleFavourite(entry.title)
                    rerenderAtlas()
                end)
            favourite.Position=UDim2.new(1,-49,1,-34)
            favourite.TextColor3=s.favourites[entry.title] and c.amber or c.dim
        end
        if #matching==0 then
            card(catalogHost,"NO MATCHES",
                ctx.atlasReady and "Try another search or category."
                    or "Atlas unavailable: the extra source module did not load.",104,"INFO")
        end
        pageCount.Text=string.format("PAGE %d / %d   •   %d MATCHES",
            s.atlasPage,maxPage,#matching)
        for key,b in pairs(filterButtons) do
            b.BackgroundColor3=(key==tab) and ctx.accent() or c.panel2
            b.TextColor3=(key==tab) and c.bg or c.text
        end
    end
    rerenderAtlas=rebuildCatalog
    search:GetPropertyChangedSignal("Text"):Connect(function()
        s.atlasPage=1;rebuildCatalog()
    end)
    -- SETTINGS
    local settings=pages.SETTINGS
    local presetCard,presetDesc=card(settings,"ONE-CLICK COMFORT PRESET",
        "Enable Calm Camera, Brighter View and Native Performance. Does NOT start mobility experiments or Rest.",108,"PRESET")
    local comfortable=button(presetCard,"APPLY COMFORT",154,30,c.panel2,function()
        for _,key in ipairs({"calm","vision","performance"}) do
            if not s.flags[key] then ctx.toggle(key,true) end
        end
        ctx.notice("Comfort preset enabled. All risky movement controls left OFF.")
    end)
    comfortable.Position=UDim2.new(1,-170,1,-42)
    local themeCard,themeDetail=card(settings,"COLOUR THEMES",
        "Choose an accent. Your preference is saved locally if writefile is available.",118,"STYLE")
    for i,x in ipairs({{"TEAL","teal"},{"VIOLET","violet"},{"CORAL","coral"}}) do
        local b=button(themeCard,x[1],126,31,c[x[2]],function()ctx.setTheme(x[2])end)
        b.Position=UDim2.fromOffset(16+(i-1)*135,76)
    end
    local sizeCard,sizeDetail=card(settings,"INTERFACE SCALE",
        "Auto-fits your display, with an extra personal size setting.",107,"STYLE")
    local small=button(sizeCard,"− SMALLER",136,30,c.panel2,function()
        ctx.setScale(math.max(.70,s.scale-.1));useScale()
    end)
    small.Position=UDim2.fromOffset(15,68)
    local larger=button(sizeCard,"+ BIGGER",136,30,c.panel2,function()
        ctx.setScale(math.min(1.16,s.scale+.1));useScale()
    end)
    larger.Position=UDim2.fromOffset(160,68)
    local infoCard,infoDesc=card(settings,"COPY OWN STATUS",
        "Copy a short own-character status including enabled features and conditions. No other-player names or coordinates are included.",197,"EXPORT")
    local copyField=nil
    local copied=button(infoCard,"COPY STATUS",151,30,c.panel2,function()
        local success,report=ctx.copyStatus()
        if not success then
            if copyField then copyField:Destroy() end
            copyField=round(ui("TextBox",{
                Text=report,MultiLine=true,TextEditable=true,
                TextColor3=c.text,Font=Enum.Font.Code,TextSize=10,
                ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,
                TextYAlignment=Enum.TextYAlignment.Top,
                Position=UDim2.fromOffset(16,105),Size=UDim2.fromOffset(661,75),
                BackgroundColor3=c.panel2
            },infoCard),8)
        end
    end)
    copied.Position=UDim2.new(1,-169,1,-41)
    action(settings,"RESTORE / TURN EVERYTHING OFF",
        "Restore Aurora-owned local settings and remove all player tags and outlines. This does not revert changes made by unrelated scripts.",
        "RESTORE ALL",function()ctx.reset()end,"SAFETY")
    card(settings,"WORKING FEATURES VS RESEARCH",
        "Active controls are explicitly marked. Atlas entries are informational and cannot be activated as server permissions. No invisible unlocks, currencies or damage buffs are promised.",115,"IMPORTANT")
    card(settings,"SHORTCUTS & CLEANUP",
        "Right Shift hides the entire hub. Use the floating Aurora chip to reopen. X closes and cleans up. Rest, through-wall overlay and movement experiments start OFF.",111,"HELP")
    local sessionCard,sessionLabel=card(settings,"SESSION ACTIVITY",
        "Session history loading...",116,"LIVE")
    -- Main update, without dynamic widget creation on frequent ticks
    local function refresh()
        if not s.alive or not gui.Parent then return end
        notice.Text=s.notice
        brand.BackgroundColor3=ctx.accent()
        if shell.Visible then useScale() end
        local a=ctx.stats()
        heroSpecies.Text=tostring(a.species or "Waiting").."   /   "..tostring(a.stage or "")..
            "   •   "..tostring(a.mode).."   •   "..pretty(a.speed,1).." studs/s"
        statValues.hp.Text=pretty(a.hp,0).." / "..pretty(a.maxHp,0)
        statValues.stamina.Text=pretty(a.stamina,1).." / "..pretty(a.maxStamina,1)
        statValues.amber.Text=pretty(a.amber,0)
        statValues.hunger.Text=pretty(a.hunger,1)
        statValues.thirst.Text=pretty(a.thirst,1)
        statValues.growth.Text=type(a.growth)=="number" and
            string.format("%.1f%%",a.growth*100) or "--"
        local effects=ctx.effects()
        effText.Text=table.concat(effects,"   ·   ")
        local running={}
        for key,enabled in pairs(s.flags) do
            if enabled and key~="tags" and key~="outlines" and key~="alerts" then
                running[#running+1]=key
            end
        end
        table.sort(running)
        activeText.Text=#running>0 and table.concat(running,"   ·   ")
            or "All gameplay and visual experiments OFF."
        nearText.Text=s.flags.playerFinder and (#s.nearby.." nearby players within "..
            s.range.." studs") or "Player Finder OFF. Open its page to enable."
        restDetail.Text=string.format("Native Rest=true requests %d  •  send failures %d  •  local echoes %d\nServer Rest acceptance: NOT VERIFIED",s.restSent,s.restFailed,s.restEchoed)
        conditionDetail.Text=table.concat(effects,"   ·   ")
        rangeLine.Text=s.range.." STUDS   /   "..s.limit.." MAX PLAYER TAGS"
        local nearLines={}
        for i=1,math.min(#s.nearby,6) do
            local x=s.nearby[i]
            nearLines[#nearLines+1]=string.format("%d. %s  /  %s   •   %d studs",
                i,x.name,x.species,math.floor(x.distance+.5))
        end
        nearbyText.Text=#nearLines>0 and table.concat(nearLines,"\n")
            or (s.flags.playerFinder and "No replicated players in range." or
                "Player Finder is currently OFF.")
        walletText.Text="Visible Amber: "..pretty(a.amber,0)..
            "\nSpendable awards remain controlled by FERAL's server."
        growText.Text="Species: "..tostring(a.species).."  •  Stage: "..tostring(a.stage)..
            "\nGrowth: "..(type(a.growth)=="number" and string.format("%.2f",a.growth) or "--")
        local char=player.Character
        local now=workspace:GetServerTimeNow()
        local untilThrive=char and char:GetAttribute("FeralThriveUntil")
        thriveText.Text=type(untilThrive)=="number" and untilThrive>now
            and ("THRIVING ACTIVE   /   "..math.ceil(untilThrive-now).." seconds remaining")
            or "No active Thriving timer currently replicated."
        local rLeft=player:GetAttribute("FeralRegrowLeft")
        regrowText.Text=type(rLeft)=="number" and rLeft>0
            and ("Regrowth allowance: "..pretty(rLeft))
            or "No active Regrowth allowance currently replicated."
        local homeTurf=char and char:GetAttribute("FeralHomeTurf")
        local grazing=char and char:GetAttribute("FeralGrazing")
        local function activeFlag(x)
            return x==true or type(x)=="number" and x>0
                or type(x)=="string" and x~=""
        end
        turfText.Text="Home Turf: "..tostring(activeFlag(homeTurf))
            .."  •  Grazing: "..tostring(activeFlag(grazing))
            .."\nBonus amounts are config leads, not verified server damage grants."
        local destination=ctx.locations[s.chosenLocation] or ctx.locations[1]
        compassText.Text=destination[1].."\n"..ctx.compass(destination)
        for key,list in pairs(toggles) do
            for _,b in ipairs(list) do
                b.Text=s.flags[key] and "ON" or "OFF"
                b.BackgroundColor3=s.flags[key] and ctx.accent() or c.panel2
                b.TextColor3=s.flags[key] and c.bg or c.muted
            end
        end
        sessionLabel.Text="Session elapsed: "..math.floor(os.clock()-s.sessionStart).." seconds."
            .."\n"..(s.log[#s.log] or "No actions yet.")
        -- Atlas cards are rebuilt only on search, filter, page or favourite
        -- changes. A heartbeat must not destroy controls mid-click.
    end
    -- Avoid rebuilding cards every 0.5s unless the user changes the atlas UI.
    ctx.onUI=function()
        refresh()
    end
    ctx.onNotice=function()
        if notice and notice.Parent then notice.Text=s.notice end
    end
    -- Restyle the relevant accent on theme changes, retaining current page.
    local globalConnections={}
    local function globalConnect(signal,handler)
        local connection=signal:Connect(handler)
        globalConnections[#globalConnections+1]=connection
        return connection
    end
    ctx.cleanupUI=function()
        for _,connection in ipairs(globalConnections) do
            pcall(function()connection:Disconnect()end)
        end
        table.clear(globalConnections)
    end
    local dragged=false
    local dragStart,frameStart
    top.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch then
            dragged=true;dragStart=input.Position;frameStart=shell.Position
        end
    end)
    globalConnect(UIS.InputChanged,function(input)
        if dragged and (input.UserInputType==Enum.UserInputType.MouseMovement
            or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position-dragStart
            shell.Position=UDim2.new(frameStart.X.Scale,frameStart.X.Offset+delta.X,
                frameStart.Y.Scale,frameStart.Y.Offset+delta.Y)
        end
    end)
    globalConnect(UIS.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch then dragged=false end
    end)
    globalConnect(UIS.InputBegan,function(input,gameProcessed)
        if gameProcessed then return end
        if input.KeyCode==Enum.KeyCode.RightShift then hidePanel() end
    end)
    showPage("HOME")
    rebuildCatalog()
    refresh()
    return gui
end
return UI
