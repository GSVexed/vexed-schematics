-- FERAL AURORA FORCE v3.1 | high-impact gameplay control centre
-- Clear separation: client-applied tuning versus server-held resources/effects.
local UI={}
local Players=game:GetService("Players")
local Tween=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")
local localPlayer=Players.LocalPlayer
local function mk(class,props,parent)
    local x=Instance.new(class)
    for k,v in pairs(props or {}) do x[k]=v end
    if parent then x.Parent=parent end
    return x
end
local function corner(x,n)
    mk("UICorner",{CornerRadius=UDim.new(0,n or 9)},x)
    return x
end
local function line(x,color,opacity)
    mk("UIStroke",{Color=color,Transparency=opacity or .5,Thickness=1},x)
end
local function txt(parent,text,size,color,bold)
    return mk("TextLabel",{
        Text=text or "",Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=size or 12,TextColor3=color or Color3.fromRGB(224,241,255),
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,
        TextWrapped=true,BackgroundTransparency=1
    },parent)
end
local function btn(parent,text,color,action)
    local x=corner(mk("TextButton",{
        Text=text,TextColor3=Color3.fromRGB(242,248,255),
        Font=Enum.Font.GothamBold,TextSize=11,BorderSizePixel=0,
        BackgroundColor3=color,AutoButtonColor=true
    },parent),8)
    local border=mk("UIStroke",{
        Color=Color3.fromRGB(245,255,255),
        Thickness=1,Transparency=1
    },x)
    x.MouseEnter:Connect(function()
        Tween:Create(border,TweenInfo.new(.12),{Transparency=.46}):Play()
    end)
    x.MouseLeave:Connect(function()
        Tween:Create(border,TweenInfo.new(.15),{Transparency=1}):Play()
    end)
    if action then x.Activated:Connect(action) end
    return x
end
local function layout(parent,gap)
    mk("UIListLayout",{
        FillDirection=Enum.FillDirection.Vertical,
        Padding=UDim.new(0,gap or 11),
        SortOrder=Enum.SortOrder.LayoutOrder
    },parent)
end
local function num(n,d)
    return type(n)=="number" and n==n
        and string.format("%."..tostring(d or 1).."f",n) or "--"
end
function UI.mount(ctx)
    local s,c,p=ctx.state,ctx.palette,ctx.power
    local parent=localPlayer:FindFirstChildOfClass("PlayerGui")
        or localPlayer:WaitForChild("PlayerGui",9)
    if not parent then return nil end
    local gui=mk("ScreenGui",{
        Name="FeralAuroraForceV31",ResetOnSpawn=false,
        DisplayOrder=157,ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    },parent)
    ctx.ui=gui
    local shutdown=mk("BindableEvent",{Name="AuroraShutdown"},gui)
    shutdown.Event:Connect(function()ctx.close()end)
    local shell=corner(mk("Frame",{
        BackgroundColor3=Color3.fromRGB(9,16,27),BorderSizePixel=0,
        AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        Size=UDim2.fromOffset(1000,662),Active=true
    },gui),17)
    line(shell,c.line,.12)
    mk("UIGradient",{
        Rotation=21,Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(15,31,46)),
            ColorSequenceKeypoint.new(.65,Color3.fromRGB(9,16,27)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(21,17,37))
        })
    },shell)
    local scaler=mk("UIScale",{Scale=1},shell)
    local function fit()
        local cam=workspace.CurrentCamera
        local size=cam and cam.ViewportSize or Vector2.new(1200,800)
        scaler.Scale=math.clamp(math.min((size.X-20)/1000,
            (size.Y-44)/662,1),.57,1)*s.scale
    end
    fit()
    local header=mk("Frame",{
        BackgroundTransparency=1,Size=UDim2.new(1,0,0,69),Active=true
    },shell)
    mk("Frame",{BackgroundColor3=c.line,BorderSizePixel=0,
        Position=UDim2.fromOffset(0,68),Size=UDim2.new(1,0,0,1)},shell)
    local leftAccent=corner(mk("Frame",{
        BackgroundColor3=c.teal,BorderSizePixel=0,
        Size=UDim2.fromOffset(4,39),Position=UDim2.fromOffset(17,15)
    },header),3)
    local name=txt(header,"A U R O R A  /  F O R C E",20,c.text,true)
    name.Position=UDim2.fromOffset(32,11)
    name.Size=UDim2.fromOffset(500,29)
    local tagline=txt(header,"v3.1  •  POWER PROFILES  /  REAL CLIENT CONTROL",
        10,c.dim)
    tagline.Position=UDim2.fromOffset(34,40)
    tagline.Size=UDim2.fromOffset(540,22)
    local modePill=corner(mk("Frame",{
        BackgroundColor3=c.panel,BorderSizePixel=0,
        Position=UDim2.fromOffset(575,18),Size=UDim2.fromOffset(204,30)
    },header),9)
    local modeText=txt(modePill,"●  STOCK CONFIG",10,c.teal,true)
    modeText.Size=UDim2.fromScale(1,1)
    modeText.TextXAlignment=Enum.TextXAlignment.Center
    local hidden=false
    local reopen=nil
    local function toggleMenu()
        hidden=not hidden;shell.Visible=not hidden
        if reopen then reopen.Visible=hidden end
    end
    local minBtn=btn(header,"—",c.panel2,toggleMenu)
    minBtn.Size=UDim2.fromOffset(39,32)
    minBtn.Position=UDim2.fromOffset(812,16)
    local scaleBtn=btn(header,"⤢",c.panel2,function()
        ctx.setScale(s.scale>=1.05 and .77 or s.scale+.09)
        fit()
    end)
    scaleBtn.Size=UDim2.fromOffset(39,32)
    scaleBtn.Position=UDim2.fromOffset(858,16)
    local exit=btn(header,"×",c.red,function()ctx.close()end)
    exit.Size=UDim2.fromOffset(39,32)
    exit.Position=UDim2.fromOffset(904,16)
    reopen=btn(gui,"✦  AURORA FORCE",c.panel2,toggleMenu)
    reopen.Size=UDim2.fromOffset(159,39)
    reopen.Position=UDim2.new(0,16,.43,0)
    reopen.Visible=false
    line(reopen,c.teal,.16)
    -- Navigation + right rail stays visible on every page.
    local nav=corner(mk("Frame",{
        BackgroundColor3=c.shell,BorderSizePixel=0,
        Position=UDim2.fromOffset(12,80),
        Size=UDim2.fromOffset(168,523)
    },shell),11)
    line(nav,c.line,.64)
    local navHeader=txt(nav,"FEATURE GROUPS",10,c.dim,true)
    navHeader.Position=UDim2.fromOffset(15,13)
    navHeader.Size=UDim2.fromOffset(135,25)
    local main=mk("Frame",{
        BackgroundTransparency=1,Position=UDim2.fromOffset(192,78),
        Size=UDim2.fromOffset(567,528)
    },shell)
    local rail=corner(mk("Frame",{
        BackgroundColor3=c.shell,BorderSizePixel=0,
        Position=UDim2.fromOffset(772,80),
        Size=UDim2.fromOffset(215,523)
    },shell),11)
    line(rail,c.line,.64)
    local pages={}
    for _,id in ipairs({"POWER","ESP","SURVIVAL","SETTINGS"}) do
        local page=mk("ScrollingFrame",{
            Name=id,BackgroundTransparency=1,BorderSizePixel=0,
            Size=UDim2.fromScale(1,1),Visible=false,
            AutomaticCanvasSize=Enum.AutomaticSize.Y,
            CanvasSize=UDim2.new(),ScrollBarThickness=3,
            ScrollBarImageColor3=c.line,
            ScrollingDirection=Enum.ScrollingDirection.Y
        },main)
        mk("UIPadding",{
            PaddingLeft=UDim.new(0,3),PaddingRight=UDim.new(0,9),
            PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,16)
        },page)
        layout(page,10)
        pages[id]=page
    end
    local navItems={
        {"POWER","⚡"},{"ESP","◉"},{"SURVIVAL","✚"},{"SETTINGS","⚙"}
    }
    local navButtons={}
    local current="POWER"
    local function showPage(page)
        current=page
        for id,frame in pairs(pages) do frame.Visible=(id==page)end
        for id,b in pairs(navButtons) do
            b.BackgroundColor3=id==page and c.panel2 or c.shell
            b.TextColor3=id==page and ctx.accent() or c.muted
        end
    end
    for i,item in ipairs(navItems) do
        local id,icon=item[1],item[2]
        local b=btn(nav,icon.."   "..id,c.shell,function()showPage(id)end)
        b.Size=UDim2.fromOffset(150,43)
        b.Position=UDim2.fromOffset(9,47+(i-1)*53)
        b.TextSize=12;b.TextXAlignment=Enum.TextXAlignment.Left
        navButtons[id]=b
    end
    local shortcuts=txt(nav,"RSHIFT  /  HIDE\nALT  /  ESCAPE ASSIST\nX  /  CLEAN CLOSE",
        10,c.dim)
    shortcuts.Position=UDim2.fromOffset(13,299)
    shortcuts.Size=UDim2.fromOffset(148,75)
    local restoreNav=btn(nav,"RESET EVERYTHING",c.red,function()
        ctx.reset()
    end)
    restoreNav.Size=UDim2.fromOffset(148,34)
    restoreNav.Position=UDim2.fromOffset(10,457)
    local function card(page,title,desc,height,category)
        local box=corner(mk("Frame",{
            BackgroundColor3=c.panel,BorderSizePixel=0,
            Size=UDim2.new(1,-13,0,height or 107)
        },page),12)
        line(box,c.line,.55)
        local titleView=txt(box,title,14,c.text,true)
        titleView.Position=UDim2.fromOffset(14,11)
        titleView.Size=UDim2.new(1,category and -135 or -28,0,25)
        if category then
            local pill=corner(mk("Frame",{
                BackgroundColor3=c.panel2,BorderSizePixel=0,
                Position=UDim2.new(1,-113,0,13),
                Size=UDim2.fromOffset(100,18)
            },box),6)
            local t=txt(pill,category,9,c.dim,true)
            t.TextXAlignment=Enum.TextXAlignment.Center
            t.Size=UDim2.fromScale(1,1)
        end
        local description=txt(box,desc or "",11,c.muted)
        description.TextYAlignment=Enum.TextYAlignment.Top
        description.Position=UDim2.fromOffset(14,42)
        description.Size=UDim2.new(1,-28,0,math.max(22,(height or 107)-47))
        return box,description
    end
    local function section(page,text)
        local section=txt(page,text,15,c.text,true)
        section.Size=UDim2.new(1,-13,0,28)
        return section
    end
    local buttons={}
    local function group(page,title,desc,options,callback,category,height)
        local box,details=card(page,title,desc,height or 126,category)
        details.Size=UDim2.new(1,-26,0,50)
        local row={}
        local width=math.floor((526-12-7*(#options-1))/#options)
        for i,item in ipairs(options) do
            local key,labelValue=item[1],item[2]
            local b=btn(box,labelValue,c.panel2,function()callback(key)end)
            b.Position=UDim2.fromOffset(14+(i-1)*(width+7),84)
            b.Size=UDim2.fromOffset(width,30)
            row[key]=b
        end
        buttons[#buttons+1]={kind="group",controls=row,title=title}
        return row,details,box
    end
    local switches={}
    local function feature(page,title,desc,callback,state,category)
        local box,d=card(page,title,desc,95,category)
        d.Size=UDim2.new(1,-122,0,48)
        local b=btn(box,"OFF",c.panel2,callback)
        b.Position=UDim2.new(1,-92,0,50)
        b.Size=UDim2.fromOffset(77,31)
        switches[#switches+1]={button=b,check=state}
        return box,d
    end
    local function control(page,title,desc,action,text,category)
        local box,d=card(page,title,desc,100,category)
        d.Size=UDim2.new(1,-168,0,52)
        local b=btn(box,text,c.panel2,action)
        b.Position=UDim2.new(1,-155,0,54)
        b.Size=UDim2.fromOffset(141,31)
        return b
    end
    -- Always-on own live status rail, including in-game depletion states.
    local railHead=txt(rail,"OWN ANIMAL  /  LIVE",11,c.teal,true)
    railHead.Position=UDim2.fromOffset(12,11)
    railHead.Size=UDim2.fromOffset(191,24)
    local animalName=txt(rail,"ANIMAL MENU",14,c.text,true)
    animalName.Position=UDim2.fromOffset(12,40)
    animalName.Size=UDim2.fromOffset(190,34)
    local modeName=txt(rail,"No active animal",11,c.dim)
    modeName.Position=UDim2.fromOffset(12,72)
    modeName.Size=UDim2.fromOffset(190,21)
    local railBars={}
    local function statbar(key,text,color,index)
        local f=corner(mk("Frame",{
            BackgroundColor3=c.panel2,BorderSizePixel=0,
            Position=UDim2.fromOffset(10,105+(index-1)*66),
            Size=UDim2.fromOffset(193,57)
        },rail),9)
        local title=txt(f,text,10,c.muted,true)
        title.Position=UDim2.fromOffset(10,4)
        title.Size=UDim2.fromOffset(90,20)
        local value=txt(f,"—",10,c.text,true)
        value.Position=UDim2.fromOffset(95,4)
        value.Size=UDim2.fromOffset(88,20)
        value.TextXAlignment=Enum.TextXAlignment.Right
        local bg=corner(mk("Frame",{
            BackgroundColor3=c.line,BorderSizePixel=0,
            Position=UDim2.fromOffset(10,33),
            Size=UDim2.fromOffset(173,9)
        },f),5)
        local fill=corner(mk("Frame",{
            BackgroundColor3=color,BorderSizePixel=0,
            Size=UDim2.fromScale(0,1)
        },bg),5)
        railBars[key]={value=value,fill=fill}
    end
    statbar("hp","HEALTH",c.green,1)
    statbar("stamina","STAMINA",c.teal,2)
    statbar("hunger","HUNGER",c.amber,3)
    statbar("thirst","THIRST",c.violet,4)
    local powerState=txt(rail,"STAMINA PROFILE\nSTOCK",11,c.amber,true)
    powerState.Position=UDim2.fromOffset(13,383)
    powerState.Size=UDim2.fromOffset(189,44)
    local activeState=txt(rail,"No client power profile enabled.",
        10,c.muted)
    activeState.TextYAlignment=Enum.TextYAlignment.Top
    activeState.Position=UDim2.fromOffset(13,427)
    activeState.Size=UDim2.fromOffset(188,79)
    -- The actual power centre
    local power=pages.POWER
    local hero=corner(mk("Frame",{
        BackgroundColor3=Color3.fromRGB(28,57,68),
        BorderSizePixel=0,Size=UDim2.new(1,-13,0,112)
    },power),12)
    mk("UIGradient",{Rotation=8,Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(30,92,95)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(48,30,73))
    })},hero)
    local heroText=txt(hero,"ACTUAL CONTROL. NO PLACEBO BUTTONS.",16,c.text,true)
    heroText.Position=UDim2.fromOffset(15,11)
    heroText.Size=UDim2.fromOffset(504,28)
    local heroDesc=txt(hero,
        "Stamina profiles and controller inputs from the recovered FERAL client. Select exactly what you want to change.",
        11,c.muted)
    heroDesc.Position=UDim2.fromOffset(15,41)
    heroDesc.Size=UDim2.fromOffset(500,31)
    local quickApex=btn(hero,"APEX STAMINA",c.panel2,function()
        p.setStamina(p.stamina=="APEX" and "OFF" or "APEX")
    end)
    quickApex.Position=UDim2.fromOffset(15,78)
    quickApex.Size=UDim2.fromOffset(166,27)
    local quickESp=btn(hero,"PLAYER ESP",c.panel2,function()showPage("ESP")end)
    quickESp.Position=UDim2.fromOffset(191,78)
    quickESp.Size=UDim2.fromOffset(143,27)
    local quickReset=btn(hero,"RESET",c.red,function()ctx.reset()end)
    quickReset.Position=UDim2.fromOffset(344,78)
    quickReset.Size=UDim2.fromOffset(117,27)
    section(power,"STAMINA ENGINE")
    local staminaButtons,staminaDesc=group(power,"STAMINA POWER PROFILE",
        "RECOVER boosts the local recharge calculation. APEX turns on the recovered zero-drain/high-regeneration client tuning; prior unexplained deaths make prolonged Burst risky.",
        {{"OFF","STOCK"},{"RECOVER","3× RECOVER"},{"APEX","APEX"}},
        function(mode)p.setStamina(mode)end,"TOP FEATURE",147)
    feature(power,"LOCAL NO-DRAIN / EXHAUSTION FLAG",
        "Use WolfDbgNoStamina on your character. This is a separate own-client gate; server effects aren't confirmed.",
        function()p.toggleNoDrain()end,function()return p.noDrain end,"CONTROLLER")
    local stateCard,stateInfo=card(power,"POWER APPLICATION STATUS",
        "Choose a stamina profile to see if the cached fields match.",114,"LIVE")
    stateInfo.Size=UDim2.new(1,-30,0,65)
    section(power,"MOBILITY & STRUGGLES")
    local speedButtons=group(power,"SPEED PROFILE",
        "Land and swim speed coefficients, reversible on OFF. Higher values may be corrected or penalised by FERAL.",
        {{1,"STOCK"},{1.15,"1.15×"},{1.30,"1.30×"},{1.50,"1.50×"}},
        function(value)p.setSpeed(value)end,"ADVANCED",139)
    local leapButtons=group(power,"LEAP PROFILE",
        "Scales forward leap distances and caps from loaded JumpLeapConfig; does not create flying/double jump.",
        {{1,"STOCK"},{1.15,"1.15×"},{1.35,"1.35×"}},
        function(value)p.setLeap(value)end,"ADVANCED",137)
    feature(power,"ALT-HELD RAPID ESCAPE",
        "Hold ALT to pulse Space at approximately 0.17s while enabled. Chat text entry is excluded. Needs executor keypress and keyrelease APIs.",
        function()p.toggleTurbo()end,function()return p.turbo end,"INPUT")
    feature(power,"INJURY SLOWDOWN INPUTS",
        "Reversible HURT_SLOW and INJURY.SLOW_PER_POINT client cache changes. It does not remove real injuries.",
        function()ctx.toggle("mobility")end,function()return s.flags.mobility end,"CLIENT")
    section(power,"RECOVERY")
    feature(power,"NATIVE RECOVERY ASSIST",
        "Native Rest requests for missing HP, bleeding, injury or venom. May be visible to other players; server acceptance is unproven.",
        function()ctx.toggle("recovery")end,function()return s.flags.recovery end,"NATIVE ACTION")
    local function toggleStandaloneNeeds()
        if p.stamina~="OFF" then
            ctx.notice("Low-needs penalty reduction is already included in this stamina profile. Select STOCK before using it separately.")
            return
        end
        ctx.toggle("lowNeedsAssist")
    end
    feature(power,"LOW-NEEDS STAMINA ASSIST",
        "Client stamina recovery when hunger/thirst is under 20. Included in 3× RECOVER and APEX; standalone only in STOCK.",
        toggleStandaloneNeeds,
        function()return s.flags.lowNeedsAssist end,"CLIENT")
    -- Player ESP, retained with local visual only.
    local esp=pages.ESP
    section(esp,"PLAYER ESP / VISUAL")
    local espCard,espState=card(esp,"LIVE PLAYER FINDER",
        "Only currently replicated characters can appear.",124,"24 MAX")
    feature(esp,"PLAYER FINDER MASTER",
        "Enable local 3D character highlights and floating nameplates with species, health and distance.",
        function()ctx.toggle("playerFinder")end,
        function()return s.flags.playerFinder end,"ESP")
    feature(esp,"FLOATING NAMETAGS",
        "Display name, species, stud distance and horizontal health bar above detected animals.",
        function()ctx.toggle("tags")end,function()return s.flags.tags end,"ESP")
    feature(esp,"COLOUR-CODED OUTLINES",
        "Teal nearest, amber middle and coral at the edge of range.",
        function()ctx.toggle("outlines")end,function()return s.flags.outlines end,"ESP")
    feature(esp,"THROUGH-WALL ESP",
        "Opt-in outlines and tags remain visible behind local obstacles. This won't reveal unreplicated players.",
        function()ctx.toggle("throughWalls")end,
        function()return s.flags.throughWalls end,"OPTIONAL")
    local rangeButtons=group(esp,"FINDER RANGE",
        "Choose a search radius. Defaults to 300 studs and 24 tracked characters.",
        {{150,"150"},{300,"300"},{600,"600"},{900,"900"}},
        function(value)ctx.setRange(value)end,"DISTANCE",131)
    local styleButtons=group(esp,"OUTLINE STYLE",
        "Choose subtle soft edges or a more obvious outlined silhouette.",
        {{"subtle","SUBTLE"},{"bold","BOLD"}},
        function(value)ctx.setOutlineStyle(value)end,"VISUAL",128)
    local playersCard,playersState=card(esp,"NEARBY PLAYERS",
        "Enable Player Finder to see a compact name/species/distance list.",173,"LIVE")
    playersState.Size=UDim2.new(1,-29,0,120)
    -- Survival and active effects instead of arbitrary fake status grants.
    local survival=pages.SURVIVAL
    section(survival,"REAL SURVIVAL / OWN STATUS")
    local needsCard,needsInfo=card(survival,"NEEDS / RECOVERY CONDITIONS",
        "Spawn an animal to read real hunger, thirst and conditions.",133,"LIVE")
    local effectsCard,effectsInfo=card(survival,"ACTIVE DAMAGE & BUFFS",
        "No animal spawned yet.",136,"LIVE")
    feature(survival,"NATIVE REST REQUESTS",
        "Rest Assist triggers on genuine healing needs; never writes HP or pretends to be server-approved.",
        function()ctx.toggle("recovery")end,function()return s.flags.recovery end,"NATIVE")
    feature(survival,"INJURY MOBILITY INPUTS",
        "Local slowdown factor tuning, not a server cure.",
        function()ctx.toggle("mobility")end,function()return s.flags.mobility end,"CLIENT")
    feature(survival,"REDUCE LOCAL LOW-NEEDS STAMINA PENALTY",
        "Included in active stamina power profiles. Available as a standalone client toggle only in STOCK.",
        toggleStandaloneNeeds,
        function()return s.flags.lowNeedsAssist end,"CLIENT")
    feature(survival,"SURVIVAL WARNINGS",
        "Alerts when needs are below the known stamina penalty threshold or exhaustion appears.",
        function()ctx.toggle("alerts")end,function()return s.flags.alerts end,"ALERT")
    card(survival,"WHY NO 'INFINITE HP / FOOD / AMBER' SWITCH?",
        "We have extensive CLIENT code but not private server grant/health/needs handlers. Changing client attributes is overwritten and does not give real resources. This hub prioritises real client-controller inputs rather than fake full-bar buttons.",
        156,"SERVER-LIMITED")
    -- UI and convenience
    local settings=pages.SETTINGS
    section(settings,"CUSTOMISE YOUR EXPERIENCE")
    feature(settings,"STEADY CAMERA",
        "Turn off local camera shake and sway for easier tracking.",
        function()ctx.toggle("calm")end,function()return s.flags.calm end,"COMFORT")
    feature(settings,"BRIGHTER WORLD",
        "Subtle local colour correction to lift dark scenes.",
        function()ctx.toggle("vision")end,function()return s.flags.vision end,"VISUAL")
    feature(settings,"NATIVE PERFORMANCE MODE",
        "Use the game's built-in local performance preference.",
        function()ctx.toggle("performance")end,
        function()return s.flags.performance end,"CLIENT")
    feature(settings,"COMPACT STATS HUD",
        "Keep a small independent health/stamina/hunger/thirst readout when this menu is hidden.",
        function()ctx.toggle("miniHUD")end,
        function()return s.flags.miniHUD end,"HUD")
    feature(settings,"LOCAL OWN-STATUS AUTOSAVE",
        "Opt-in private file written by executor; GitHub sync is not connected.",
        function()ctx.toggle("localAutosave")end,
        function()return s.flags.localAutosave end,"LOCAL FILE")
    local themes=group(settings,"ACCENT THEME","Switch Aurora's main highlight colour.",
        {{"teal","TEAL"},{"violet","VIOLET"},{"coral","CORAL"}},
        function(value)ctx.setTheme(value)end,"STYLE",130)
    control(settings,"COPY STATUS",
        "Copy your current own-character statistics; nothing is uploaded to GitHub automatically.",
        function()ctx.copyStatus()end,"COPY","EXPORT")
    control(settings,"SAVE STATUS FILE",
        "Write a local privacy-limited snapshot history if your executor supports writefile.",
        function()ctx.saveStatusFile()end,"SAVE LOCAL","EXPORT")
    control(settings,"RESTORE ORIGINALS",
        "Stop client stamina/movement profiles, input pulses, ESP, Rest requests and local settings.",
        function()ctx.reset()end,"RESET ALL","SAFE")
    -- Footer and small independent HUD.
    local foot=mk("Frame",{
        BackgroundTransparency=1,Position=UDim2.fromOffset(13,614),
        Size=UDim2.fromOffset(974,37)
    },shell)
    mk("Frame",{BackgroundColor3=c.line,BorderSizePixel=0,
        Size=UDim2.new(1,0,0,1)},foot)
    local notice=txt(foot,s.notice,10,c.muted)
    notice.TextTruncate=Enum.TextTruncate.AtEnd
    notice.Position=UDim2.fromOffset(7,7)
    notice.Size=UDim2.fromOffset(748,25)
    local offBtn=btn(foot,"RESTORE ALL",c.red,function()ctx.reset()end)
    offBtn.Size=UDim2.fromOffset(156,28)
    offBtn.Position=UDim2.fromOffset(806,5)
    local mini=corner(mk("Frame",{
        Name="AuroraForceCompact",BackgroundColor3=c.bg,
        BackgroundTransparency=.09,BorderSizePixel=0,
        Position=UDim2.new(1,-293,0,90),
        Size=UDim2.fromOffset(276,90),Visible=false
    },gui),12)
    line(mini,c.teal,.3)
    local miniTitle=txt(mini,"✦  AURORA  /  LIVE ANIMAL",10,c.teal,true)
    miniTitle.Position=UDim2.fromOffset(12,7)
    miniTitle.Size=UDim2.fromOffset(248,22)
    local miniBody=txt(mini,"No active animal",11,c.text,true)
    miniBody.Position=UDim2.fromOffset(12,31)
    miniBody.Size=UDim2.fromOffset(253,49)
    local events={}
    local function global(signal,handler)
        local e=signal:Connect(handler);events[#events+1]=e;return e
    end
    ctx.cleanupUI=function()
        for _,e in ipairs(events) do pcall(function()e:Disconnect()end)end
    end
    local dragging=false
    local start,old
    header.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true;start=input.Position;old=shell.Position
        end
    end)
    global(UIS.InputChanged,function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement
            or input.UserInputType==Enum.UserInputType.Touch) then
            local d=input.Position-start
            shell.Position=UDim2.new(old.X.Scale,old.X.Offset+d.X,
                old.Y.Scale,old.Y.Offset+d.Y)
        end
    end)
    global(UIS.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end)
    global(UIS.InputBegan,function(input,processed)
        if processed or UIS:GetFocusedTextBox() then return end
        if input.KeyCode==Enum.KeyCode.RightShift then toggleMenu()end
    end)
    local function colourButton(b,active)
        b.BackgroundColor3=active and ctx.accent() or c.panel2
        b.TextColor3=active and c.bg or c.muted
    end
    local failures=0
    local function refresh()
        if not gui.Parent or not s.alive then return end
        local status=p.status()
        local a=ctx.stats()
        leftAccent.BackgroundColor3=ctx.accent()
        modeText.Text="●  "..status.mode
        modeText.TextColor3=status.stamina=="APEX" and c.coral or
            status.stamina=="RECOVER" and c.amber or c.teal
        animalName.Text=tostring(a.species or "MENU")
        modeName.Text=tostring(a.sessionPhase).."  /  "..tostring(a.mode)
        local function set(key,v,max,precision)
            local slot=railBars[key]
            slot.value.Text=num(v,precision).." / "..num(max,0)
            slot.fill.Size=UDim2.fromScale(
                type(v)=="number" and type(max)=="number" and max>0
                    and math.clamp(v/max,0,1) or 0,1)
        end
        set("hp",a.hp,a.maxHp,0)
        set("stamina",a.stamina,a.maxStamina,1)
        set("hunger",a.hunger,100,0)
        set("thirst",a.thirst,100,0)
        powerState.Text="STAMINA / "..status.stamina..
            "\nSPEED / "..num(status.speed,2).."×"
        powerState.TextColor3=status.stamina=="APEX" and c.coral or c.amber
        activeState.Text=status.last..
            "\nController flag: "..tostring(status.flag)..
            "\nESCAPE: "..(status.turbo and "ARMED" or "OFF")
        stateInfo.Text="Stamina profile: "..status.stamina..
            " • cached inputs match: "..tostring(status.staminaMatches)..
            "\nNo-drain client flag: "..tostring(status.flag)..
            " • ALT Escape: "..(status.turbo and "ARMED" or "OFF")..
            "\n"..status.last
        for key,b in pairs(staminaButtons) do
            colourButton(b,status.stamina==key)
        end
        for key,b in pairs(speedButtons) do
            colourButton(b,status.speed==key)
        end
        for key,b in pairs(leapButtons) do
            colourButton(b,status.leap==key)
        end
        for key,b in pairs(rangeButtons) do
            colourButton(b,s.range==key)
        end
        for key,b in pairs(styleButtons) do
            colourButton(b,s.outlineStyle==key)
        end
        for key,b in pairs(themes) do
            colourButton(b,s.theme==key)
        end
        for _,switch in ipairs(switches) do
            local on=switch.check()
            switch.button.Text=on and "ON" or "OFF"
            colourButton(switch.button,on)
        end
        quickApex.BackgroundColor3=status.stamina=="APEX" and c.coral or c.panel2
        espState.Text="Origin "..s.finderOrigin..
            " • replicated living "..s.finderCounts.live..
            " • within range "..s.finderCounts.inRange..
            "\n"..s.finderReason
        local lines={}
        for i=1,math.min(7,#s.nearby) do
            local item=s.nearby[i]
            lines[#lines+1]=string.format("%d. %s / %s  •  %.0f studs",
                i,item.name,item.species,item.distance)
        end
        playersState.Text=#lines>0 and table.concat(lines,"\n")
            or (s.flags.playerFinder and s.finderReason or "Finder OFF.")
        needsInfo.Text=ctx.resourceHelp()
        effectsInfo.Text=table.concat(ctx.effects(),"\n")
        mini.Visible=s.flags.miniHUD
        miniTitle.TextColor3=ctx.accent()
        miniBody.Text=a.sessionPhase=="IN GAME" and
            ("HP "..num(a.hp,0).."/"..num(a.maxHp,0)..
            "   ST "..num(a.stamina,1).."/"..num(a.maxStamina,1)..
            "\nHUNGER "..num(a.hunger,0).."   THIRST "..num(a.thirst,0)) or
            "ANIMAL MENU  /  SPAWN TO SEE STATS"
        notice.Text=s.notice
        if shell.Visible then fit() end
    end
    ctx.onUI=function()
        local ok,err=pcall(refresh)
        if not ok and failures<1 then
            failures+=1
            ctx.notice("Aurora FORCE UI refresh error: "..tostring(err):sub(1,115))
        end
    end
    ctx.onNotice=function()notice.Text=s.notice end
    showPage("POWER")
    refresh()
    return gui
end
return UI
