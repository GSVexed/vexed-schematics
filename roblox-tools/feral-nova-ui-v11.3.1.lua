-- FERAL NOVA v11.3.1 | Project Renaissance action and deferred-carry safeguards
-- Preserves v7.5 gameplay while adding independent AFK controls and safety evidence.
local UI={}
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Lighting=game:GetService("Lighting")
local HttpService=game:GetService("HttpService")
local player=Players.LocalPlayer
local C={
    bg=Color3.fromRGB(8,14,25),tile=Color3.fromRGB(17,29,45),
    edge=Color3.fromRGB(46,70,91),alt=Color3.fromRGB(29,46,66),
    cyan=Color3.fromRGB(75,237,212),violet=Color3.fromRGB(168,146,255),
    ink=Color3.fromRGB(235,244,252),muted=Color3.fromRGB(147,169,190),
    danger=Color3.fromRGB(246,116,132),amber=Color3.fromRGB(255,194,113)
}
local function make(typ,props,parent)
    local x=Instance.new(typ)
    for key,value in pairs(props or {}) do x[key]=value end
    if parent then x.Parent=parent end
    return x
end
local function corner(x,r)
    make("UICorner",{CornerRadius=UDim.new(0,r or 11)},x)
    return x
end
local function border(x,transparency)
    make("UIStroke",{Color=C.edge,Transparency=transparency or .4,Thickness=1},x)
end
local function txt(parent,s,size,color,bold)
    return make("TextLabel",{
        Text=s or "",Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=size or 12,TextColor3=color or C.ink,
        BackgroundTransparency=1,BorderSizePixel=0,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,
        TextTruncate=Enum.TextTruncate.AtEnd
    },parent)
end
local function btn(parent,s,callback,w,h)
    local b=corner(make("TextButton",{
        Text=s,Font=Enum.Font.GothamBold,TextSize=11,
        BackgroundColor3=C.alt,TextColor3=C.ink,
        BorderSizePixel=0,AutoButtonColor=false
    },parent),9)
    b.Size=UDim2.fromOffset(w or 64,h or 30)
    local outline=make("UIStroke",{
        Color=C.cyan,Transparency=.86,Thickness=1
    },b)
    b.MouseEnter:Connect(function()
        if b.Parent then
            TweenService:Create(outline,TweenInfo.new(.12),{Transparency=.34}):Play()
        end
    end)
    b.MouseLeave:Connect(function()
        if b.Parent then
            TweenService:Create(outline,TweenInfo.new(.12),{Transparency=.86}):Play()
        end
    end)
    b.Activated:Connect(function()
        local ok,err=pcall(callback)
        if not ok then warn("[FERAL HUB UI] BUTTON ACTION FAILED: "..tostring(err))end
    end)
    return b
end
local function nfmt(n,decimals)
    if type(n)~="number" or n~=n then return "--" end
    return string.format("%."..tostring(decimals or 0).."f",n)
end

function UI.mount(ctx)
    local S,P=ctx.state,ctx.power
    local Escape=ctx.escape
    local Lab=ctx.lab
    local Recovery=ctx.recovery
    local Regen=ctx.regen
    local Mobile=ctx.mobile
    local Native=ctx.native
    local Active=ctx.activeRecovery
    local Climb=ctx.climb
    local Baby=ctx.baby
    local Reach=ctx.reach
    local Flight=ctx.flight
    local Carry=ctx.carry
    local Tags=ctx.tags
    local Mechanics=ctx.mechanics
    local Eagle=ctx.eagleActions
    local Diag=ctx.diag
    local AFK=ctx.afk
    local Action=ctx.action
    local Grab=ctx.grabMini
    local Evidence=ctx.evidence
    if not AFK or not Action or not Grab or not Evidence then return nil end
    if not Escape or not P or not Lab or not Recovery or not Regen or not Mobile or not Native or not Climb or not Baby or not Reach or not Flight or not Carry or not Tags or not Mechanics or not Diag or not Active or not Eagle then return nil end
    local pg=player:FindFirstChildOfClass("PlayerGui")
        or player:WaitForChild("PlayerGui",10)
    if not pg then return nil end
    local gui=make("ScreenGui",{
        Name="FeralNovaV1131",ResetOnSpawn=false,
        DisplayOrder=210,ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    },pg)
    ctx.ui=gui
    local shutdown=make("BindableEvent",{Name="AuroraShutdown"},gui)
    shutdown.Event:Connect(function()ctx.close()end)

    -- Existing player tracker handles lifecycle, stream-out, selection and
    -- cleanup. V6 only changes rendering; it never recolours model interiors.
    -- Tags are positioned above the species' actual bounding box.
    local baseTracker=ctx.refreshTracker
    function ctx.refreshTracker(force)
        baseTracker(force)
        for _,r in pairs(S.byPlayer) do
            if r.h and r.h.Parent then
                r.h.FillTransparency=1
                r.h.OutlineTransparency=0
            end
            if r.b and r.b.Parent then
                r.b.Size=UDim2.fromOffset(148,20)
                r.b.AlwaysOnTop=S.flags.throughWalls
                r.b.MaxDistance=S.range
                r.b.Enabled=false -- v8 screen-projected names replace this billboard
                if S.flags.tags and r.char and r.b.Adornee
                    and r.b.Adornee:IsA("BasePart") then
                    local now=os.clock()
                    if now-(r.lastTagHeight or -math.huge)>=1.5 then
                        r.lastTagHeight=now
                        local ok,cf,size=pcall(function()
                            return r.char:GetBoundingBox()
                        end)
                        if ok and cf and size then
                            local top=cf.Position.Y+size.Y*.5
                            local head=r.b.Adornee.Position.Y
                            r.tagOffset=math.clamp(top-head+.7,.6,8)
                        end
                    end
                end
                r.b.StudsOffsetWorldSpace=Vector3.new(0,r.tagOffset or 2.4,0)
                if r.name then
                    local plate=r.name.Parent
                    if plate then
                        plate.BackgroundTransparency=1
                        for _,item in ipairs(plate:GetChildren()) do
                            if item:IsA("UIStroke") then item.Enabled=false end
                        end
                    end
                    r.name.Position=UDim2.new(0,0,0,0)
                    r.name.Size=UDim2.fromScale(1,1)
                    r.name.TextSize=11
                    r.name.TextXAlignment=Enum.TextXAlignment.Center
                    r.name.TextStrokeColor3=C.bg
                    r.name.TextStrokeTransparency=.14
                end
                if r.info then r.info.Visible=false end
                if r.fill and r.fill.Parent then
                    r.fill.Parent.Visible=false
                end
            end
        end
    end

    -- One endurance switch combines tested-in-prior-users client 3x local
    -- controller recovery and the own-character debug no-drain flag.
    -- It is not a claimed server-side resource grant.
    local function endurance(on)
        if on then
            P.setStamina("RECOVER")
            if P.stamina=="RECOVER" and not P.noDrain then
                P.toggleNoDrain()
            end
        else
            if P.noDrain then P.toggleNoDrain() end
            P.disableStamina(true)
            ctx.notice("Endurance OFF. Client settings restored where owned.")
        end
    end
    local function enduranceOn()
        return P.stamina=="RECOVER" and P.noDrain
    end
    -- One agility toggle instead of choosing three speed and leap tiers.
    local function agility(on)
        if on then
            P.setSpeed(1.30)
            P.setLeap(1.35)
            ctx.toggle("mobility",true)
            if P.speed~=1.30 or P.leap~=1.35 then
                P.setSpeed(1)
                P.setLeap(1)
                ctx.toggle("mobility",false)
                ctx.notice("Agility unavailable on this animal/client. Restored.")
            end
        else
            P.setSpeed(1)
            P.setLeap(1)
            ctx.toggle("mobility",false)
        end
    end
    local function agilityOn()
        return P.speed==1.30 and P.leap==1.35
    end

    -- CLEAR VIEW uses the established local vision switch and reversible
    -- local atmosphere/fog edits. No environment object deletion.
    -- Only optional visual preferences persist between launches.
    -- Power/escape choices do not silently auto-enable from an old session.
    local displayFile="FERAL_NovaPrime_Display_v32.json"
    local function readDisplay()
        local default={tags=true,walls=true,range=450}
        if type(readfile)~="function" then return default end
        local ok,value=pcall(function()
            return HttpService:JSONDecode(readfile(displayFile))
        end)
        if not ok or type(value)~="table" then return default end
        if type(value.tags)=="boolean" then default.tags=value.tags end
        if type(value.walls)=="boolean" then default.walls=value.walls end
        if value.range==450 or value.range==900 then default.range=value.range end
        return default
    end
    local function saveDisplay()
        if type(writefile)~="function" then return end
        pcall(function()
            writefile(displayFile,HttpService:JSONEncode({
                tags=S.flags.tags,
                walls=S.flags.throughWalls,
                range=S.range
            }))
        end)
    end
    local displayPrefs=readDisplay()
    local fogLease={}
    local function clearFog()
        for i=#fogLease,1,-1 do
            local e=fogLease[i]
            pcall(function()
                if e.obj.Parent and e.obj[e.key]==e.wanted then
                    e.obj[e.key]=e.old
                end
            end)
        end
        table.clear(fogLease)
    end
    local function fogSet(obj,key,wanted)
        if not obj then return end
        pcall(function()
            local old=obj[key]
            if type(old)=="number" and old~=wanted then
                obj[key]=wanted
                fogLease[#fogLease+1]={obj=obj,key=key,old=old,wanted=wanted}
            end
        end)
    end
    local function view(on)
        if on then
            ctx.toggle("vision",true)
            if S.flags.vision then
                clearFog()
                fogSet(Lighting,"FogEnd",100000)
                local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere")
                if atmosphere then
                    fogSet(atmosphere,"Density",.015)
                    fogSet(atmosphere,"Haze",0)
                end
            end
        else
            ctx.toggle("vision",false)
            clearFog()
        end
    end

    local shell=corner(make("Frame",{
        Size=UDim2.fromOffset(830,828),
        AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        BackgroundColor3=C.bg,BorderSizePixel=0,Active=true
    },gui),18)
    border(shell,.24)
    make("UIGradient",{
        Rotation=20,Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(17,34,54)),
            ColorSequenceKeypoint.new(.59,C.bg),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(22,17,42))
        })
    },shell)
    local scale=make("UIScale",{Scale=1},shell)
    local function fit()
        local cam=workspace.CurrentCamera
        local size=cam and cam.ViewportSize or Vector2.new(1280,800)
        scale.Scale=math.clamp(math.min(
            (size.X-22)/830,(size.Y-36)/828,1
        ),.32,1)
    end
    fit()

    local header=make("Frame",{
        Size=UDim2.new(1,0,0,68),
        BackgroundTransparency=1,Active=true
    },shell)
    corner(make("Frame",{
        Position=UDim2.fromOffset(18,17),
        Size=UDim2.fromOffset(5,37),
        BackgroundColor3=C.cyan,BorderSizePixel=0
    },header),3)
    local title=txt(header,"F E R A L   H U B",21,C.ink,true)
    title.Position=UDim2.fromOffset(37,11)
    title.Size=UDim2.fromOffset(360,27)
    local subtitle=txt(header,"v11.3.1 RENAISSANCE  •  GAMEPLAY RELIABILITY",10,C.muted)
    subtitle.Position=UDim2.fromOffset(38,37)
    subtitle.Size=UDim2.fromOffset(385,20)
    local live=corner(make("Frame",{
        Position=UDim2.fromOffset(466,19),
        Size=UDim2.fromOffset(100,29),
        BackgroundColor3=C.tile,BorderSizePixel=0
    },header),8)
    border(live,.77)
    local liveText=txt(live,"●  GAME READY",10,C.cyan,true)
    liveText.Size=UDim2.fromScale(1,1)
    liveText.TextXAlignment=Enum.TextXAlignment.Center

    local hidden=false
    local show
    local function toggleMenu()
        hidden=not hidden
        shell.Visible=not hidden
        if show then show.Visible=hidden end
        if not hidden and type(ctx.onUI)=="function" then pcall(ctx.onUI)end
    end
    show=btn(gui,"✦  FERAL HUB",toggleMenu,130,37)
    show.Position=UDim2.fromOffset(16,220)
    show.Visible=false
    local minimize=btn(header,"—",toggleMenu,34,30)
    minimize.Position=UDim2.fromOffset(699,18)
    local exit=btn(header,"CLOSE",function()ctx.close()end,73,30)
    exit.Position=UDim2.fromOffset(742,18)
    exit.BackgroundColor3=Color3.fromRGB(85,43,60)

    local strip=corner(make("Frame",{
        Size=UDim2.fromOffset(794,60),
        Position=UDim2.fromOffset(18,73),
        BackgroundColor3=C.tile,BorderSizePixel=0
    },shell),12)
    border(strip,.80)
    local meters={}
    for i,caption in ipairs({"HEALTH","STAMINA","HUNGER","THIRST"}) do
        local x=14+(i-1)*197
        local label=txt(strip,caption,10,C.muted,true)
        label.Position=UDim2.fromOffset(x,7)
        label.Size=UDim2.fromOffset(105,18)
        local value=txt(strip,"--",12,C.ink,true)
        value.Position=UDim2.fromOffset(x+90,7)
        value.Size=UDim2.fromOffset(95,18)
        value.TextXAlignment=Enum.TextXAlignment.Right
        local track=corner(make("Frame",{
            Position=UDim2.fromOffset(x,37),
            Size=UDim2.fromOffset(181,7),
            BackgroundColor3=C.alt,BorderSizePixel=0
        },strip),4)
        local fill=corner(make("Frame",{
            Size=UDim2.fromScale(0,1),
            BackgroundColor3=(i==1 and C.danger
                or i==2 and C.cyan or C.violet),
            BorderSizePixel=0
        },track),4)
        meters[i]={value=value,fill=fill}
    end

    local buttons={}
    local function card(x,y,titleText,desc,glyph,getter,action,id)
        local cardFrame=corner(make("Frame",{
            Position=UDim2.fromOffset(x,y),
            Size=UDim2.fromOffset(386,78),
            BackgroundColor3=C.tile,BorderSizePixel=0
        },shell),11)
        border(cardFrame,.76)
        local iconBox=corner(make("Frame",{
            Size=UDim2.fromOffset(37,37),
            Position=UDim2.fromOffset(12,20),
            BackgroundColor3=C.alt,BorderSizePixel=0
        },cardFrame),10)
        local icon=txt(iconBox,glyph,19,C.cyan,true)
        icon.Size=UDim2.fromScale(1,1)
        icon.TextXAlignment=Enum.TextXAlignment.Center
        local cap=txt(cardFrame,titleText,13,C.ink,true)
        cap.Position=UDim2.fromOffset(60,12)
        cap.Size=UDim2.fromOffset(240,25)
        local descText=txt(cardFrame,desc,10,C.muted)
        descText.Position=UDim2.fromOffset(60,37)
        descText.Size=UDim2.fromOffset(246,22)
        local b=btn(cardFrame,"OFF",action,59,33)
        b.Position=UDim2.fromOffset(315,23)
        buttons[#buttons+1]={button=b,getter=getter,id=id}
        return b,descText
    end
    card(18,144,"ENDURANCE","Local stamina settings; server unverified","⚡",
        enduranceOn,function()endurance(not enduranceOn())end,"endurance")
    card(414,144,"AUTO ESCAPE","Only if captured • never drops your prey","↗",
        function()return Escape.enabled end,
        function()Escape.setEnabled(not Escape.enabled)end,"escape")
    card(18,231,"OUTLINE ESP","Clean outlines • never fills animals","◎",
        function()return S.flags.playerFinder end,
        function()ctx.toggle("playerFinder")end,"esp")
    card(414,231,"AGILITY","Local speed/leap and slow-assist inputs","➤",
        agilityOn,function()agility(not agilityOn())end,"agility")
    local regenButton,regenDesc=card(18,318,
        "ACTIVE RECOVERY","Native feeding protected • manual Rest preserved","✚",
        function()return Active.enabled end,
        function()
            Active.setEnabled(not Active.enabled)
            if Diag and Diag.mark then Diag.mark("recovery_toggle")end
        end,"active")
    card(414,318,"CLEAR VIEW","Local visual changes; reversible","◈",
        function()return S.flags.vision end,
        function()view(not S.flags.vision)end,"vision")

    local afkRobloxButton,afkRobloxDesc=card(18,410,
        "ANTI IDLE KICK","Best-effort virtual input to stay connected","◷",
        function()return AFK.robloxEnabled end,
        function()AFK.setRobloxEnabled(not AFK.robloxEnabled)end,"afkRoblox")
    local afkBonusButton,afkBonusDesc=card(414,410,
        "SURVIVAL AFK","Opt-in safe 6.5-stud movement for bonus","◇",
        function()return AFK.survivalEnabled end,
        function()AFK.setSurvivalEnabled(not AFK.survivalEnabled)end,"afkSurvival")

    local esp=corner(make("Frame",{
        Position=UDim2.fromOffset(18,503),
        Size=UDim2.fromOffset(794,52),
        BackgroundColor3=C.tile,BorderSizePixel=0
    },shell),11)
    border(esp,.79)
    local espTitle=txt(esp,"ESP DETAILS",11,C.muted,true)
    espTitle.Position=UDim2.fromOffset(14,14)
    espTitle.Size=UDim2.fromOffset(75,22)
    local tags=btn(esp,"TAGS",function()
        ctx.toggle("tags")
        saveDisplay()
    end,65,30)
    tags.Position=UDim2.fromOffset(91,11)
    local walls=btn(esp,"WALLS",function()
        ctx.toggle("throughWalls")
        saveDisplay()
    end,65,30)
    walls.Position=UDim2.fromOffset(163,11)
    local distance=btn(esp,"RANGE",function()
        ctx.setRange(S.range<650 and 900 or 450)
        saveDisplay()
    end,86,30)
    distance.Position=UDim2.fromOffset(234,11)
    local reachButton=btn(esp,"REACH",function()
        Reach.setEnabled(not Reach.enabled)
        ctx.onUI()
    end,82,30)
    reachButton.Position=UDim2.fromOffset(326,11)
    local waterButton=btn(esp,"SURFACE FLY",function()
        Flight.setEnabled(not Flight.enabled)
        ctx.onUI()
    end,96,30)
    waterButton.Position=UDim2.fromOffset(413,11)
    local carryButton=btn(esp,"CARRY  G",function()
        Carry.press()
        ctx.onUI()
    end,268,30)
    carryButton.Position=UDim2.fromOffset(514,11)

    local actions=corner(make("Frame",{
        Position=UDim2.fromOffset(18,565),
        Size=UDim2.fromOffset(794,44),
        BackgroundColor3=C.tile,BorderSizePixel=0
    },shell),10)
    border(actions,.79)
    local quickButton=btn(actions,"QUICK CLIMB",function()
        Climb.setEnabled(not Climb.enabled)
        ctx.onUI()
    end,153,29)
    quickButton.Position=UDim2.fromOffset(10,7)
    local babyButton=btn(actions,"BABY CARRY",function()
        Baby.setEnabled(not Baby.enabled)
        ctx.onUI()
    end,153,29)
    babyButton.Position=UDim2.fromOffset(170,7)
    local assistText=txt(actions,"Q buffered at tree • friendly pickups protected",11,C.muted)
    assistText.Position=UDim2.fromOffset(334,6)
    assistText.Size=UDim2.fromOffset(450,32)
    local experiments=corner(make("Frame",{
        Position=UDim2.fromOffset(18,618),
        Size=UDim2.fromOffset(794,64),
        BackgroundColor3=C.tile,BorderSizePixel=0
    },shell),10)
    border(experiments,.79)
    local expTitle=txt(experiments,"EAGLE LAB • EXPERIMENTAL • SERVER ACCEPTANCE UNVERIFIED",10,C.amber,true)
    expTitle.Position=UDim2.fromOffset(11,3)
    expTitle.Size=UDim2.fromOffset(760,20)
    local function expBtn(index,label,callback)
        local b=btn(experiments,label,callback,122,30)
        b.Position=UDim2.fromOffset(10+(index-1)*130,27)
        return b
    end
    local recoveryReportButton=expBtn(1,"RECOVERY STATUS",function()
        local copy=type(setclipboard)=="function" and setclipboard
            or type(toclipboard)=="function" and toclipboard
        if copy then pcall(function()
            copy(Active.report().."\n\n"..Native.report().."\n\n"..Regen.report().."\n\n"..Diag.report())
        end)end
        ctx.onUI()
    end)
    local growthTest=expBtn(2,"GROWTH (LOCAL)",function()
        Mechanics.setEnabled("growth",not Mechanics.enabled.growth)
        ctx.onUI()
    end)
    local carryTest=expBtn(3,"NATIVE CARRY ASSIST",function()
        Mechanics.setEnabled("carry",not Mechanics.enabled.carry)
        ctx.onUI()
    end)
    local cdTest=expBtn(4,"TALON READY ASSIST",function()
        Mechanics.setEnabled("cooldown",not Mechanics.enabled.cooldown)
        ctx.onUI()
    end)
    local profileTest=expBtn(5,"PRESET",function()
        Mechanics.cyclePreset()
        ctx.onUI()
    end)
    local grabAuto=expBtn(6,"AUTO PERFECT",function()
        Grab.setEnabled(not Grab.enabled)
        ctx.onUI()
    end)

    local footer=corner(make("Frame",{
        Position=UDim2.fromOffset(18,696),
        Size=UDim2.fromOffset(794,42),
        BackgroundColor3=Color3.fromRGB(13,22,36),BorderSizePixel=0
    },shell),10)
    local status=txt(footer,"ESCAPE: WATCHING • RIGHT SHIFT TO HIDE",11,C.muted)
    status.Position=UDim2.fromOffset(13,5)
    status.Size=UDim2.fromOffset(542,32)
    local feedbackUntil=0
    local feedback=""
    local reportButton=btn(footer,"COPY STATUS",function()
        local a=ctx.stats()
        local power=P.status()
        local report=Evidence.report().."\n\n"..Grab.report().."\n\n"..AFK.report().."\n\n"..Action.report().."\n\n"..Escape.report().."\n\n"..Carry.report().."\n\n"..Lab.report().."\n\n"..Reach.report().."\n\n"..Regen.report().."\n\n"..Diag.report().."\n\n"..Mechanics.report().."\n\n"..Eagle.report().."\n\n"..Native.report().."\n\n"..Climb.report().."\n\n"..Baby.report().."\n\n"..Mobile.report().."\n\n"..Flight.report().."\n\n"..Recovery.report().."\n\n"..P.enduranceReport().."\n"..Tags.report()..
            "\n\nFERAL v28 | Lease verification"..
            "\nendurance_cached_lease="..tostring(power.staminaMatches)..
            " stamina_profile="..tostring(power.stamina)..
            " own_no_drain_flag="..tostring(power.flag)..
            "\nspeed_cached_lease="..tostring(power.speedMatches)..
            " leap_cached_lease="..tostring(power.leapMatches)..
            " anti_slow_cached_flag="..tostring(S.flags.mobility)..
            "\nserver_stamina_and_movement_acceptance=UNVERIFIED"..
            "\ncurrent_growth="..tostring(player.Character and player.Character:GetAttribute("Growth"))..
            "\nendurance="..tostring(enduranceOn())..
            " agility="..tostring(agilityOn())..
            " antislow="..tostring(S.flags.mobility)..
            " visible_hp="..nfmt(a.hp).."/"..nfmt(a.maxHp)..
            " visible_stamina="..nfmt(a.stamina,1).."/"..nfmt(a.maxStamina,1)..
            "\nesp="..tostring(S.flags.playerFinder)..
            " tags="..tostring(S.flags.tags)..
            " walls="..tostring(S.flags.throughWalls)..
            " range="..tostring(S.range)..
            " tracked="..tostring(S.finderCounts.shown or 0)
        local copy=(type(setclipboard)=="function" and setclipboard)
            or (type(toclipboard)=="function" and toclipboard)
        local ok=copy and pcall(copy,report)
        feedback=ok and "STATUS COPIED • CARRY / ESCAPE / RECOVERY"
            or "CLIPBOARD NOT SUPPORTED BY EXECUTOR"
        feedbackUntil=os.clock()+3.5
        if not ok then warn("[NOVA PRIME] "..report) end
        ctx.onUI()
    end,103,31)
    reportButton.Position=UDim2.fromOffset(566,5)
    local reset=btn(footer,"RESET",function()
        endurance(false)
        agility(false)
        view(false)
        Lab.setEnabled(false)
        Flight.setEnabled(false)
        Active.setEnabled(false)
        Mobile.setEnabled(false)
        Climb.setEnabled(false)
        Baby.setEnabled(false)
        Reach.setEnabled(false)
        Mechanics.setEnabled("growth",false)
        Mechanics.setEnabled("carry",false)
        Mechanics.setEnabled("cooldown",false)
        Recovery.setEnabled(false)
        Escape.setEnabled(false)
        Grab.setEnabled(false)
        AFK.setRobloxEnabled(false)
        AFK.setSurvivalEnabled(false)
        clearFog()
        Diag.mark("hub_reset")
        ctx.reset()
        feedback="RESET APPLIED • ALL LOCAL FEATURE SWITCHES REQUESTED OFF"
        feedbackUntil=os.clock()+6
        ctx.notice("Local configurations reset; close/rejoin if old game state persists.")
    end,107,31)
    reset.Position=UDim2.fromOffset(673,5)
    reset.BackgroundColor3=Color3.fromRGB(84,42,57)

    -- All diagnostics are collected automatically from our own character only.
    -- The report is kept locally; there is no network upload or secret collection.
    local diagBar=corner(make("Frame",{
        Position=UDim2.fromOffset(18,746),
        Size=UDim2.fromOffset(794,63),
        BackgroundColor3=C.tile,BorderSizePixel=0
    },shell),10)
    border(diagBar,.79)
    local diagStatus=txt(diagBar,"DIAGNOSTICS STARTING  •  PRIVATE RUNNER COLLECTION",10,C.muted)
    diagStatus.Position=UDim2.fromOffset(12,6)
    diagStatus.Size=UDim2.fromOffset(768,20)
    local autoDiag=btn(diagBar,"AUTO FILE",function()
        Diag.setAutoSave(not Diag.autoSave)
        ctx.onUI()
    end,174,29)
    autoDiag.Position=UDim2.fromOffset(12,30)
    local saveDiag=btn(diagBar,"SAVE DIAG",function()
        Diag.mark("manual_save")
        local ok,msg=Diag.save()
        feedback=msg or (ok and "DIAGNOSTICS SAVED" or "SAVE FAILED")
        feedbackUntil=os.clock()+4
        ctx.onUI()
    end,140,29)
    saveDiag.Position=UDim2.fromOffset(196,30)
    local copyDiag=btn(diagBar,"COPY DIAG",function()
        Diag.mark("copy_report")
        local ok,msg=Diag.copy()
        feedback=msg or (ok and "DIAGNOSTICS COPIED" or "COPY FAILED")
        feedbackUntil=os.clock()+4
        ctx.onUI()
    end,140,29)
    copyDiag.Position=UDim2.fromOffset(346,30)
    local diagHint=txt(diagBar,"Private Windows runner · no public upload",10,C.muted)
    diagHint.Position=UDim2.fromOffset(502,30)
    diagHint.Size=UDim2.fromOffset(280,29)

    -- Persistent V2 guide / executor compatibility panel. Startup diagnostics remain
    -- accessible even after the guarded boot overlay disappears.
    local helpLayer=make("Frame",{
        Position=UDim2.fromOffset(18,73),
        Size=UDim2.fromOffset(794,738),
        BackgroundColor3=Color3.fromRGB(8,17,30),
        BorderSizePixel=0,Visible=false,ZIndex=30
    },shell)
    corner(helpLayer,14)
    border(helpLayer,.15)
    local helpHeading=txt(helpLayer,"FERAL HUB  /  GUIDE & COMPATIBILITY",19,C.cyan,true)
    helpHeading.Position=UDim2.fromOffset(22,18)
    helpHeading.Size=UDim2.fromOffset(660,36)
    helpHeading.ZIndex=31
    local helpBody=txt(helpLayer,
        "CLIENT CONTROLS vs GAME-SERVER RULES\n"..
        "Endurance, Agility, Reach, Growth and Talon Gate edit local inputs/settings.\n"..
        "Only observed replicated game outcomes count as evidence of real results.\n\n"..
        "EAGLE: An on-screen CATCH label does not guarantee a carry.\n"..
        "The hub separates physical holds from holds matching assisted targets.\n"..
        "A locally permitted CATCH indicator cannot override game-server carry limits.\n"..
        "Growth configuration does not establish faster server-recognised Elder growth.\n"..
        "Health: mobile Rest signal outside combat; never forces visible Rest.\n"..
        "Feeding/drinking pauses automatic Rest; it resumes after native feeding.\n"..
        "Retired Safe Rest and Mobile A/B loops cannot compete with recovery.\n"..
        "Flight respects feed, grab and AFK action priorities.\n"..
        "Eagle native lunge reply monitor reconnects after remote replacement.\n"..
        "Rest requests use 5s idle/3s wounded-motion cadence, subject to server.\n"..
        "Real mouse attacks pause auto Rest; nearby animals alone never do.\n"..
        "Roblox idle: virtual input heartbeat; retention not confirmed.\n"..
        "Survival AFK: opt-in short real walks on safe ground.\n"..
        "Grab V2: auto Perfect uses actual native strikes and timestamps.\n"..
        "Local Perfect timing does not guarantee server Perfect results.\n"..
        "No fake server survival credit is submitted.\n"..
        "Recovery resumes after attacks; real combat blocks it completely.\n"..
        "Repeated pose echoes trigger timed retry, not a lifetime shutdown.\n"..
        "Hunger/Thirst: normal game consumption takes action priority.\n"..
        "A local REST_MULT=4 is not proof of server 4x effect recovery.\n\n"..
        "CORE: real attacks, grabs and combat outrank automatic Rest.\n"..
        "Extended local bite hints cannot masquerade as actual native reach.\n"..
        "COORDINATION: Auto Escape protects against hostile grabs. Friendly baby\n"..
        "carrying is handled separately. Active Recovery pauses for unsafe actions.\n"..
        "Quick Climb buffers Q for 2.25s and retries one missed native mount tap.\n\n"..
        "KEYS: RIGHT SHIFT hide/show  |  END shutdown  |  Q climb  |  G carry\n"..
        "DIAGNOSTICS: The original v32 session report saves locally when supported.\n"..
        "A v7 session report records own HP, Hunger, Thirst and recovery status.\n"..
        "No new network telemetry is transmitted by this release.\n"..
        "New DATA dashboard shows measured movement, status and survival changes.\n"..
        "Evidence labels distinguish API calls from server-accepted results.",
        13,C.ink,false)
    helpBody.Position=UDim2.fromOffset(22,68)
    helpBody.Size=UDim2.fromOffset(742,425)
    helpBody.TextWrapped=true
    helpBody.TextTruncate=Enum.TextTruncate.None
    helpBody.TextYAlignment=Enum.TextYAlignment.Top
    helpBody.ZIndex=31
    local coreEvidence=txt(helpLayer,
        "CORE POLICY STARTING • HP and Grab server outcomes are not guaranteed",
        11,C.cyan,true)
    coreEvidence.Position=UDim2.fromOffset(22,489)
    coreEvidence.Size=UDim2.fromOffset(750,21)
    coreEvidence.ZIndex=31
    local helpFeedback=txt(helpLayer,"Potassium APIs are optional: unsupported features are reported, not forced.",11,C.muted)
    helpFeedback.Position=UDim2.fromOffset(22,509)
    helpFeedback.Size=UDim2.fromOffset(733,29)
    helpFeedback.ZIndex=31
    local function helpCopy(text)
        local copy=type(setclipboard)=="function" and setclipboard
            or type(toclipboard)=="function" and toclipboard
        if type(copy)~="function" then
            helpFeedback.Text="Clipboard API not available; use saved report files."
            return
        end
        local ok=pcall(copy,text)
        helpFeedback.Text=ok and "Copied to clipboard." or "Clipboard request failed."
    end
    local copyBoot=btn(helpLayer,"COPY BOOT REPORT",function()
        local boot=ctx.hubBuild
        if boot and type(boot.bootReport)=="function" then
            local ok,result=pcall(boot.bootReport)
            if ok then helpCopy(tostring(result)) else helpFeedback.Text="Boot report unavailable." end
        else
            helpFeedback.Text="Boot report not available in this environment."
        end
    end,199,36)
    copyBoot.Position=UDim2.fromOffset(22,560)
    copyBoot.ZIndex=31
    local copySession=btn(helpLayer,"COPY SESSION",function()
        local boot=ctx.hubBuild
        if boot and type(boot.sessionReport)=="function" then
            local ok,result=pcall(boot.sessionReport)
            if ok then helpCopy(tostring(result)) else helpFeedback.Text="Session report unavailable." end
        else
            helpCopy(Diag.report())
        end
    end,185,36)
    copySession.Position=UDim2.fromOffset(236,560)
    copySession.ZIndex=31
    local selfCheck=btn(helpLayer,"RUN SELF-CHECK",function()
        local build=ctx.hubBuild
        if build and type(build.selfTest)=="function" then
            local ok,summary=pcall(build.selfTest)
            helpFeedback.Text=ok and tostring(summary):sub(1,95)
                or "Self-check failed: "..tostring(summary):sub(1,75)
        else
            helpFeedback.Text="This release does not expose the self-check."
        end
    end,150,36)
    selfCheck.Position=UDim2.fromOffset(432,560)
    selfCheck.ZIndex=31
    local copyGoals=btn(helpLayer,"COPY HEALTH + CARRY",function()
        helpCopy("FERAL NOVA v11.3.1 / HEALTH AND EAGLE CARRY\n"..
            Active.report().."\n\n"..Native.report()..
            "\n\n"..Recovery.report().."\n\n"..Regen.report()..
            "\n\n"..Carry.report().."\n\n"..Eagle.report()..
            "\n\nNOTE=Real server healing and prohibited-size pickup remain subject to server rules.")
    end,199,29)
    copyGoals.Position=UDim2.fromOffset(22,602)
    copyGoals.ZIndex=31
    local copyCore=btn(helpLayer,"COPY CORE AUDIT",function()
        helpCopy(Action.report().."\n\n"..Native.report()..
            "\n\n"..Grab.report().."\n\n"..AFK.report()..
            "\nNOTE=Successful local input calls do not prove server credit.")
    end,174,29)
    copyCore.Position=UDim2.fromOffset(236,602)
    copyCore.ZIndex=31
    local closeHelp=btn(helpLayer,"BACK TO HUB",function()
        helpLayer.Visible=false
    end,169,36)
    closeHelp.Position=UDim2.fromOffset(598,560)
    closeHelp.ZIndex=31
    local dashboardLayer
    local helpButton=btn(header,"HELP",function()
        helpLayer.Visible=not helpLayer.Visible
        if dashboardLayer then dashboardLayer.Visible=false end
    end,55,30)
    helpButton.Position=UDim2.fromOffset(637,18)
    -- The panel cannot claim detection avoidance or live-game validation.
    helpButton.ZIndex=4
    dashboardLayer=make("Frame",{
        Position=UDim2.fromOffset(18,73),
        Size=UDim2.fromOffset(794,738),
        BackgroundColor3=Color3.fromRGB(8,17,30),
        BorderSizePixel=0,Visible=false,ZIndex=35
    },shell)
    corner(dashboardLayer,13)
    border(dashboardLayer,.15)
    local dashTitle=txt(dashboardLayer,
        "FERAL NOVA / LIVE GAMEPLAY EVIDENCE",19,C.cyan,true)
    dashTitle.Position=UDim2.fromOffset(22,19)
    dashTitle.Size=UDim2.fromOffset(650,35)
    dashTitle.ZIndex=36
    local dashSubtitle=txt(dashboardLayer,
        "Read-only own-animal measurements. Client action requests are NOT server proof.",
        11,C.muted,false)
    dashSubtitle.Position=UDim2.fromOffset(22,55)
    dashSubtitle.Size=UDim2.fromOffset(740,25)
    dashSubtitle.ZIndex=36
    local dashTab="SURVIVAL"
    local dashTabs={}
    local function chooseTab(tab)
        dashTab=tab
        for _,item in ipairs(dashTabs) do
            item.button.BackgroundColor3=item.label==tab and
                Color3.fromRGB(28,78,79) or C.alt
            item.button.TextColor3=item.label==tab and C.cyan or C.muted
        end
        if type(ctx.onUI)=="function" then pcall(ctx.onUI) end
    end
    for i,tab in ipairs({"SURVIVAL","COMBAT","ABILITIES","SYSTEM"}) do
        local t=tab
        local b=btn(dashboardLayer,t,function()chooseTab(t)end,172,38)
        b.Position=UDim2.fromOffset(22+(i-1)*187,98)
        b.ZIndex=36
        dashTabs[#dashTabs+1]={button=b,label=t}
    end
    local dashBody=txt(dashboardLayer,"Awaiting own animal data...",15,C.ink,false)
    dashBody.Position=UDim2.fromOffset(25,160)
    dashBody.Size=UDim2.fromOffset(742,405)
    dashBody.TextWrapped=true
    dashBody.TextYAlignment=Enum.TextYAlignment.Top
    dashBody.TextTruncate=Enum.TextTruncate.None
    dashBody.ZIndex=36
    local dashFoot=txt(dashboardLayer,
        "OBSERVED does not mean CAUSALLY PROVEN. No fabricated server events.",
        12,C.amber,false)
    dashFoot.Position=UDim2.fromOffset(25,583)
    dashFoot.Size=UDim2.fromOffset(742,37)
    dashFoot.TextWrapped=true
    dashFoot.ZIndex=36
    local copyEvidence=btn(dashboardLayer,"COPY EVIDENCE",function()
        helpCopy(Evidence.report().."\n\n"..Action.report())
    end,182,36)
    copyEvidence.Position=UDim2.fromOffset(22,662)
    copyEvidence.ZIndex=36
    local dashClose=btn(dashboardLayer,"BACK TO HUB",function()
        dashboardLayer.Visible=false
    end,165,36)
    dashClose.Position=UDim2.fromOffset(607,662)
    dashClose.ZIndex=36
    local dashButton=btn(header,"DATA",function()
        dashboardLayer.Visible=not dashboardLayer.Visible
        if dashboardLayer.Visible then
            helpLayer.Visible=false
            chooseTab(dashTab)
        end
    end,62,30)
    dashButton.Position=UDim2.fromOffset(569,18)
    dashButton.ZIndex=4
    chooseTab(dashTab)

    local connections={}
    local drag=false
    local dragOrigin,dragStart
    connections[#connections+1]=header.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch then
            drag=true;dragOrigin=input.Position;dragStart=shell.Position
        end
    end)
    connections[#connections+1]=UIS.InputChanged:Connect(function(input)
        if drag and (input.UserInputType==Enum.UserInputType.MouseMovement
            or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position-dragOrigin
            shell.Position=UDim2.new(
                dragStart.X.Scale,dragStart.X.Offset+delta.X,
                dragStart.Y.Scale,dragStart.Y.Offset+delta.Y
            )
        end
    end)
    connections[#connections+1]=UIS.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch then
            drag=false
        end
    end)
    connections[#connections+1]=UIS.InputBegan:Connect(function(input,processed)
        if UIS:GetFocusedTextBox() then return end
        -- Menu and emergency shutdown shortcuts work even if the game processed input.
        if input.KeyCode==Enum.KeyCode.RightShift then toggleMenu()
        elseif input.KeyCode==Enum.KeyCode.End then ctx.close()
        end
    end)

    local function styleButton(b,on,label)
        b.Text=label or (on and "ON" or "OFF")
        b.BackgroundColor3=on and Color3.fromRGB(28,78,79) or C.alt
        b.TextColor3=on and C.cyan or C.muted
    end
    local warned=false
    ctx.onUI=function()
        local ok,err=pcall(function()
            if not gui.Parent or not S.alive or not shell.Visible then return end
            local a=ctx.stats()
            local ev=Evidence.summary()
            local function numOrUnknown(n,decimals)
                if type(n)~="number" or n~=n then return "NOT YET MEASURED" end
                return string.format("%."..tostring(decimals or 2).."f",n)
            end
            if dashboardLayer.Visible then
                if dashTab=="SURVIVAL" then
                    dashBody.Text=table.concat({
                        "OWN ANIMAL HEALTH & INJURY (clean observation windows)",
                        "",
                        "Moving HP increase / second: "..numOrUnknown(ev.movingHealingRate),
                        "Stationary HP increase / second: "..numOrUnknown(ev.stationaryHealingRate),
                        "Moving vs stationary ratio: "..numOrUnknown(ev.movingToStillRatio).."x",
                        "Clean moving seconds: "..numOrUnknown(ev.movingSeconds,1),
                        "Clean stationary seconds: "..numOrUnknown(ev.stationarySeconds,1),
                        "",
                        "Broken-bone clearance moving / second: "..numOrUnknown(ev.injuryMovingRate),
                        "Broken-bone clearance stationary / second: "..numOrUnknown(ev.injuryStillRate),
                        "Bleeding clearance moving / second: "..numOrUnknown(ev.bleedMovingRate),
                        "Venom clearance moving / second: "..numOrUnknown(ev.venomMovingRate),
                        "",
                        "Observed stamina consumed: "..numOrUnknown(ev.staminaConsumed,1),
                        "Observed hunger lost: "..numOrUnknown(ev.hungerLost,1),
                        "Observed thirst lost: "..numOrUnknown(ev.thirstLost,1),
                        "Survival progress observed: "..numOrUnknown(ev.survivalIncrease,1)
                    },"\n")
                elseif dashTab=="COMBAT" then
                    dashBody.Text=table.concat({
                        "GAME COMBAT & NATIVE GRAB V2",
                        "",
                        "Current action priority: "..tostring(Action.lastPriority),
                        "Action policy denials: "..tostring(Action.denied),
                        "Action leases granted: "..tostring(Action.leaseCount),
                        "Current recovery status: "..tostring(Native.status),
                        "Manual Rest protected: "..tostring(Native.manualRest),
                        "",
                        "Native Grab V2 strike events: "..tostring(ev.minigameStrikes),
                        "Timed native presses sent: "..tostring(ev.minigamePresses),
                        "Recognised server Perfect replies: "..tostring(ev.confirmedServerPerfects),
                        "Last Grab status: "..tostring(Grab.status),
                        "",
                        "Auto Escape status: "..tostring(Escape.status),
                        "Native bite indicator: "..tostring(Lab.nativeReady),
                        "Extended target hint: "..tostring(Lab.ready),
                        "",
                        "NOTE: A locally-timed Perfect is not a guaranteed server Perfect."
                    },"\n")
                elseif dashTab=="ABILITIES" then
                    dashBody.Text=table.concat({
                        "EAGLE, TALON, FLIGHT AND CARRY EVIDENCE",
                        "",
                        "Native Eagle physical clamp observations: "..
                            tostring(Eagle.anyClampObservations),
                        "Physically held matching assisted target: "..
                            tostring(Eagle.actualClampObservations),
                        "Client oversize-labeled holds (not server proof): "..
                            tostring(Eagle.clientOversizeClampObservations),
                        "Native Eagle status: "..tostring(Eagle.status),
                        "",
                        "Local Talon gate enabled: "..
                            tostring(Mechanics.enabled.cooldown),
                        "Client Talon clock edits: "..
                            tostring(Eagle.cooldownAttrEdits),
                        "Native carry status: "..tostring(Carry.status),
                        "Native climbing: "..tostring(Climb.status),
                        "Flight assist: "..tostring(Flight.status),
                        "",
                        "NOTE: Oversized server-accepted carry and reduced Talon cooldown",
                        "are not established by client flags or a CATCH indicator."
                    },"\n")
                else
                    dashBody.Text=table.concat({
                        "HUB SYSTEMS, ACTION OWNERSHIP AND SHUTDOWN",
                        "",
                        "Build: FERAL NOVA v11.3.1",
                        "Modules loaded: 23",
                        "Action policy state: "..tostring(Action.lastPriority),
                        "Action policy snapshot reads: "..tostring(Action.reads),
                        "Cached state reads: "..tostring(Action.cacheHits),
                        "Denied unsafe actions: "..tostring(Action.denied),
                        "Action lease expirations: "..tostring(Action.expiredLeases),
                        "",
                        "Active Recovery: "..tostring(Active.status),
                        "Roblox anti-idle: "..tostring(AFK.robloxStatus),
                        "Survival AFK movement: "..tostring(AFK.survivalStatus),
                        "Evidence samples: "..tostring(Evidence.totalObservations),
                        "Evidence errors: "..tostring(Evidence.errorCount),
                        "",
                        "Right Shift: hide | End: safe shutdown | HELP: diagnostics",
                        "Only the owner can change actual game-server rules."
                    },"\n")
                end
            end
            local list={
                {a.hp,a.maxHp},{a.stamina,a.maxStamina},
                {a.hunger,100},{a.thirst,100}
            }
            for i,entry in ipairs(list) do
                local v,max=entry[1],entry[2]
                local ratio=type(v)=="number" and type(max)=="number" and max>0
                    and math.clamp(v/max,0,1) or 0
                meters[i].fill.Size=UDim2.fromScale(ratio,1)
                meters[i].value.Text=nfmt(v,i==2 and 1 or 0)..
                    (i<=2 and ("/"..nfmt(max)) or "%")
            end
            for _,item in ipairs(buttons) do
                if item.id=="active" then
                    styleButton(item.button,Active.enabled,
                        Active.mode=="NATIVE_RECOVERY" and "REST SIGNAL"
                            or Active.mode=="POSE_SAFE_CONFIG_ONLY" and "SAFE"
                            or Active.enabled and "ARMED" or "OFF")
                elseif item.id=="afkRoblox" then
                    styleButton(item.button,AFK.robloxEnabled,
                        AFK.robloxEnabled and "ARMED" or "OFF")
                elseif item.id=="afkSurvival" then
                    styleButton(item.button,AFK.survivalEnabled,
                        AFK.survivalEnabled and "SAFE" or "OFF")
                elseif item.id=="endurance" then
                    styleButton(item.button,item.getter(),
                        item.getter() and "CLIENT" or "OFF")
                elseif item.id=="agility" then
                    styleButton(item.button,item.getter(),
                        item.getter() and "CLIENT" or "OFF")
                else
                    styleButton(item.button,item.getter())
                end
            end
            coreEvidence.Text="PRIORITY "..tostring(Action.lastPriority)..
                "  •  MOVING HP + "..nfmt(Native.movingObservedHPGain,1)..
                "  •  GRAB PRESSES "..tostring(Grab.pressesSent)..
                "  •  SERVER OUTCOME: VERIFY"
            afkRobloxDesc.Text=AFK.robloxStatus
            afkBonusDesc.Text=AFK.survivalStatus
            diagStatus.Text=Diag.shortStatus().."  •  PRIVATE RUNNER SYNC"
            local observed=Diag.lastSnapshot or {}
            local inspect=Mechanics.inspect()
            local recoveryStatus=Active.mode=="MANUAL_REST"
                and "MANUAL REST / PRESERVED" or Active.mode=="COMBAT_BLOCKED"
                and "REST OFF / COMBAT" or Active.mode=="NATIVE_RECOVERY"
                and "MOBILE REST SIGNAL" or Active.mode
            expTitle.Text="HEALTH "..tostring(recoveryStatus):sub(1,28)..
                "  •  EAGLE HOLDS "..Eagle.anyClampObservations..
                "  / ASSISTED "..Eagle.actualClampObservations..
                "  / LOCAL OVERSIZE "..Eagle.clientOversizeClampObservations
            local waterStatus=Flight.underwater and "UNDERWATER" or
                Flight.surfaceEligible and "FLOATING" or Flight.airborne and "FLYING" or "NORMAL"
            diagHint.Text="WATER "..waterStatus..
                "  EXIT OK "..Flight.underwaterExitConfirmed..
                " / UNCONFIRMED "..Flight.underwaterExitUnconfirmed
            styleButton(autoDiag,Diag.autoSave,Diag.autoSave and "AUTO SAVE EVERY 25s" or "FILE SAVE OFF")
            recoveryReportButton.Text=Active.mode=="MANUAL_REST" and "MANUAL REST"
                or Active.mode=="COMBAT_BLOCKED" and "COMBAT PAUSE"
                or Active.mode=="NATIVE_RECOVERY" and "REST REQUEST"
                or Active.mode=="POSE_SAFE_CONFIG_ONLY" and "POSE GUARDED"
                or Active.mode=="PAUSED_FOR_ACTION" and "ACTION BLOCKED"
                or Active.mode=="NO_RECOVERY_NEEDED" and "HP FULL"
                or "RECOVERY STATUS"
            styleButton(growthTest,Mechanics.enabled.growth,"GROWTH "..(Mechanics.enabled.growth and "ON" or "OFF"))
            styleButton(carryTest,Mechanics.enabled.carry,"CARRY ASSIST "..(Mechanics.enabled.carry and "ON" or "OFF"))
            styleButton(cdTest,Mechanics.enabled.cooldown,"TALON GATE "..(Mechanics.enabled.cooldown and "ON" or "OFF"))
            profileTest.Text="PRESET "..Mechanics.preset().name
            styleButton(grabAuto,Grab.enabled,
                Grab.enabled and (Grab.activeSession and "AUTO TIMING" or "AUTO ARMED")
                    or "AUTO OFF")
            styleButton(tags,S.flags.tags,"TAGS "..(S.flags.tags and "ON" or "OFF"))
            styleButton(walls,S.flags.throughWalls,"WALLS "..(S.flags.throughWalls and "ON" or "OFF"))
            distance.Text="RANGE "..tostring(S.range)
            styleButton(quickButton,Climb.enabled,
                Climb.enabled and "Q CLIMB ON" or "Q CLIMB OFF")
            styleButton(babyButton,Baby.enabled,
                Baby.enabled and "BABY CARRY ON" or "BABY CARRY OFF")
            assistText.Text=Climb.queued and "Q QUEUED • APPROACH A TREE"
                or Baby.active and ("FRIENDLY PICKUP • "..Baby.lastEvidence)
                or Native.active and "RECOVERY SIGNAL ACTIVE • ACTIONS TAKE PRIORITY"
                or Climb.status
            styleButton(reachButton,Reach.enabled,
                Reach.applied and "REACH ON" or Reach.enabled and "REACH ?" or "REACH OFF")
            styleButton(waterButton,Flight.enabled,
                Flight.applied and "SURFACE ON" or Flight.enabled and "SURFACE ?" or "SURFACE OFF")
            regenDesc.Text=Active.enabled and Active.status or "RECOVERY OFF"
            regenDesc.TextColor3=Active.mode=="NATIVE_RECOVERY" and C.cyan or C.muted
            local carryLabel=Carry.victim and "ESCAPE FIRST"
                or Carry.holding and "DROP / RELEASE"
                or Carry.canInteract and "CARRY / PICK"
                or "USE G"
            styleButton(carryButton,Carry.holding or Carry.canInteract,carryLabel)
            if os.clock()<feedbackUntil then
                status.Text=feedback
            else
                local primary=Grab.activeSession
                    and ("GRAB V2 • "..Grab.status)
                    or Baby.active and ("FRIENDLY PICKUP • NO AUTO GETOFF")
                    or Carry.victim and ("CAPTURED • "..Escape.status)
                    or Carry.holding and ("CARRYING • "..Carry.state.." • G TO DROP")
                    or Escape.active and ("ESCAPING • "..Escape.status)
                    or Lab.ready and "BITE WINDOW (CLIENT)" or Lab.status
                if Recovery.snapshot then Recovery.snapshot()end
                local secondary=Active.enabled and ("RECOVERY: "..Active.status)
                    or Climb.queued and "QUICK CLIMB QUEUED"
                    or Flight.water and Flight.enabled
                    and ("WATER: "..Flight.status)
                    or (Regen.enabled and Regen.applied
                        and "CLIENT RECOVERY INPUTS ACTIVE • SERVER UNVERIFIED")
                    or (Reach.enabled and Reach.applied
                        and "CLIENT BITE REACH ACTIVE")
                    or Recovery.multiplier==.30 and "TURTLE SHELL RULE (UNVERIFIED)"
                    or ""
                status.Text=primary..
                    (secondary~="" and ("  •  "..secondary) or "")
            end
            if a.sessionPhase=="IN GAME" then
                if Recovery.multiplier==.30 then
                    liveText.Text="●  SHELL RULE (CLIENT)"
                    liveText.TextColor3=C.cyan
                elseif type(a.hp)=="number" and type(a.maxHp)=="number"
                    and a.maxHp>0 and a.hp/a.maxHp<.25 then
                    liveText.Text="●  LOW HEALTH"
                    liveText.TextColor3=C.danger
                elseif type(a.hunger)=="number" and a.hunger<20
                    or type(a.thirst)=="number" and a.thirst<20 then
                    liveText.Text="●  LOW NEEDS"
                    liveText.TextColor3=C.amber
                else
                    liveText.Text="●  IN GAME"
                    liveText.TextColor3=C.cyan
                end
            else
                liveText.Text="●  MENU"
                liveText.TextColor3=C.muted
            end
            if shell.Visible then fit()end
        end)
        if not ok and not warned then
            warned=true;warn("[NOVA PRIME] UI: "..tostring(err))
        end
    end
    ctx.onNotice=function()end
    ctx.cleanupUI=function()
        -- Flush and terminate the recorder before restoring game-side modules.
        pcall(function()Diag.close()end)
        pcall(function()Evidence.close()end)
        pcall(function()Active.close()end)
        pcall(function()Grab.close()end)
        pcall(function()AFK.close()end)
        pcall(function()Action.close()end)
        pcall(function()Eagle.close()end)
        pcall(function()Native.close()end)
        pcall(function()Climb.close()end)
        pcall(function()Baby.close()end)
        pcall(function()Flight.close()end)
        pcall(function()Mobile.close()end)
        pcall(function()Regen.close()end)
        pcall(function()Mechanics.close()end)
        pcall(function()Reach.close()end)
        pcall(function()Carry.close()end)
        pcall(function()Lab.close()end)
        pcall(function()Recovery.close()end)
        pcall(function()Tags.close()end)
        pcall(function()Escape.close()end)
        pcall(clearFog)
        for _,cn in ipairs(connections) do
            pcall(function()cn:Disconnect()end)
        end
    end

    -- Practical defaults: no setup needed to see other animals or escape.
    S.flags.tags=displayPrefs.tags
    ctx.toggle("playerFinder",true)
    ctx.toggle("throughWalls",displayPrefs.walls)
    ctx.toggle("alerts",false)
    ctx.setRange(displayPrefs.range)
    -- Proven-compatible defaults preserved. Guarded native Rest only
    -- runs outside combat and now consults the v9 action policy.
    endurance(true)
    Reach.setEnabled(true)
    Flight.setEnabled(true)
    Climb.setEnabled(true)
    Baby.setEnabled(true)
    Active.setEnabled(true)
    AFK.setRobloxEnabled(true)
    -- No unrequested character movement from opening the hub.
    -- Explicitly opt in with the SURVIVAL AFK toggle.
    AFK.setSurvivalEnabled(false)
    Grab.setEnabled(true)
    ctx.refreshTracker(true)
    ctx.onUI()
    return gui
end
return UI
