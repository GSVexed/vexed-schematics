-- FERAL NOVA PRIME v10.0 | streamlined survival dashboard
-- One-screen high-impact UI. Six meaningful switches; no multi-profile setup.
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
    b.Activated:Connect(callback)
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
    local Tags=ctx.tags
    if not Escape or not P or not Lab or not Recovery or not Tags then return nil end
    local pg=player:FindFirstChildOfClass("PlayerGui")
        or player:WaitForChild("PlayerGui",10)
    if not pg then return nil end
    local gui=make("ScreenGui",{
        Name="FeralNovaPrimeV100",ResetOnSpawn=false,
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
    local displayFile="FERAL_NovaPrime_Display_v6.json"
    local function readDisplay()
        local default={tags=false,walls=true,range=450}
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
        Size=UDim2.fromOffset(830,528),
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
            (size.X-22)/830,(size.Y-36)/528,1
        ),.47,1)
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
    local title=txt(header,"N O V A   P R I M E",21,C.ink,true)
    title.Position=UDim2.fromOffset(37,11)
    title.Size=UDim2.fromOffset(360,27)
    local subtitle=txt(header,"FERAL  •  v10.0  •  CLEAN PHYSICS / REST TRACKER",10,C.muted)
    subtitle.Position=UDim2.fromOffset(38,37)
    subtitle.Size=UDim2.fromOffset(385,20)
    local live=corner(make("Frame",{
        Position=UDim2.fromOffset(498,19),
        Size=UDim2.fromOffset(132,29),
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
    end
    show=btn(gui,"✦  NOVA",toggleMenu,116,37)
    show.Position=UDim2.fromOffset(16,220)
    show.Visible=false
    local minimize=btn(header,"—",toggleMenu,34,30)
    minimize.Position=UDim2.fromOffset(734,18)
    local exit=btn(header,"×",function()ctx.close()end,34,30)
    exit.Position=UDim2.fromOffset(775,18)
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
    card(18,144,"ENDURANCE","3× recovery + client no-drain input","⚡",
        enduranceOn,function()endurance(not enduranceOn())end,"endurance")
    card(414,144,"AUTO ESCAPE","Directional shake / tug / carry","↗",
        function()return Escape.enabled end,
        function()Escape.setEnabled(not Escape.enabled)end,"escape")
    card(18,231,"OUTLINE ESP","Clean outlines • never fills animals","◎",
        function()return S.flags.playerFinder end,
        function()ctx.toggle("playerFinder")end,"esp")
    card(414,231,"AGILITY","Speed, leap and injury-slow assist","➤",
        agilityOn,function()agility(not agilityOn())end,"agility")
    local recoveryButton,recoveryDesc=card(18,318,
        "REST RECOVERY","2× HP / 4× effects only when resting","✚",
        function()return Recovery.enabled end,
        function()Recovery.setEnabled(not Recovery.enabled)end,"recovery")
    card(414,318,"CLEAR VIEW","Brighter visibility and less local fog","◈",
        function()return S.flags.vision end,
        function()view(not S.flags.vision)end,"vision")

    local esp=corner(make("Frame",{
        Position=UDim2.fromOffset(18,410),
        Size=UDim2.fromOffset(794,52),
        BackgroundColor3=C.tile,BorderSizePixel=0
    },shell),11)
    border(esp,.79)
    local espTitle=txt(esp,"ESP DETAILS",11,C.muted,true)
    espTitle.Position=UDim2.fromOffset(14,14)
    espTitle.Size=UDim2.fromOffset(109,22)
    local tags=btn(esp,"TAGS",function()
        ctx.toggle("tags")
        saveDisplay()
    end,112,30)
    tags.Position=UDim2.fromOffset(130,11)
    local walls=btn(esp,"WALLS",function()
        ctx.toggle("throughWalls")
        saveDisplay()
    end,112,30)
    walls.Position=UDim2.fromOffset(251,11)
    local distance=btn(esp,"RANGE",function()
        ctx.setRange(S.range<650 and 900 or 450)
        saveDisplay()
    end,128,30)
    distance.Position=UDim2.fromOffset(372,11)
    local hitbox=btn(esp,"BITE GUIDE",function()
        Lab.setEnabled(not Lab.enabled)
        ctx.onUI()
    end,120,30)
    hitbox.Position=UDim2.fromOffset(507,11)
    local near=txt(esp,"0 TRACKED",10,C.cyan,true)
    near.Position=UDim2.fromOffset(639,13)
    near.Size=UDim2.fromOffset(136,25)
    near.TextXAlignment=Enum.TextXAlignment.Right

    local footer=corner(make("Frame",{
        Position=UDim2.fromOffset(18,472),
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
        local report=Escape.report().."\n\n"..Lab.report().."\n\n"..Recovery.report().."\n"..Tags.report()..
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
        feedback=ok and "STATUS COPIED • REST / COLLISION / COMBAT"
            or "CLIPBOARD NOT SUPPORTED BY EXECUTOR"
        feedbackUntil=os.clock()+3.5
        if not ok then warn("[NOVA PRIME] "..report) end
        ctx.onUI()
    end,103,31)
    reportButton.Position=UDim2.fromOffset(566,5)
    local reset=btn(footer,"RESET",function()
        Lab.setEnabled(false)
        Recovery.setEnabled(false)
        Escape.setEnabled(false)
        clearFog()
        ctx.reset()
        feedback="RESET APPLIED • REJOIN TO CLEAR LEGACY HITBOX CHANGES"
        feedbackUntil=os.clock()+6
        ctx.notice("Local settings reset. If collisions persist, rejoin FERAL for untouched root geometry.")
    end,107,31)
    reset.Position=UDim2.fromOffset(673,5)
    reset.BackgroundColor3=Color3.fromRGB(84,42,57)

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
        if processed or UIS:GetFocusedTextBox() then return end
        if input.KeyCode==Enum.KeyCode.RightShift then toggleMenu()end
    end)

    local function styleButton(b,on,label)
        b.Text=label or (on and "ON" or "OFF")
        b.BackgroundColor3=on and Color3.fromRGB(28,78,79) or C.alt
        b.TextColor3=on and C.cyan or C.muted
    end
    local warned=false
    ctx.onUI=function()
        local ok,err=pcall(function()
            if not gui.Parent or not S.alive then return end
            local a=ctx.stats()
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
                styleButton(item.button,item.getter())
            end
            styleButton(tags,S.flags.tags,"TAGS "..(S.flags.tags and "ON" or "OFF"))
            styleButton(walls,S.flags.throughWalls,"WALLS "..(S.flags.throughWalls and "ON" or "OFF"))
            distance.Text="RANGE "..tostring(S.range)
            styleButton(hitbox,Lab.enabled,"GUIDE "..(Lab.enabled and "ON" or "OFF"))
            recoveryDesc.Text=Recovery.status
            if type(Recovery.statusActive)=="boolean" and Recovery.statusActive
                and not Recovery.enabled then
                recoveryDesc.Text="Effects detected • rest assistance OFF"
            end
            recoveryDesc.TextColor3=(Recovery.multiplier==.30)
                and C.cyan or C.muted
            local counts=S.finderCounts
            if Lab.enabled and a.sessionPhase=="IN GAME" then
                near.Text=Lab.ready and "BITE READY" or "AIM / CLOSE"
                near.TextColor3=Lab.ready and C.cyan or C.muted
            else
                near.Text=tostring(counts.shown or 0).." TRACKED"
                near.TextColor3=C.cyan
            end
            if os.clock()<feedbackUntil then
                status.Text=feedback
            else
                status.Text=(Recovery.multiplier==.30 and "SHELL RULE MET  •  " or "")..
                    "ESCAPE  "..Escape.status..
                    (Lab.status=="REST ACTIVE / BITE BLOCKED" and "  •  REST BLOCKS BITE" or "")..
                    "  •  "..tostring(a.species or "ANIMAL")
            end
            if a.sessionPhase=="IN GAME" then
                if Recovery.multiplier==.30 then
                    liveText.Text="●  SHELL CONDITION"
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
        Lab.close()
        Recovery.close()
        Tags.close()
        Escape.close()
        clearFog()
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
    ctx.refreshTracker(true)
    ctx.onUI()
    return gui
end
return UI
