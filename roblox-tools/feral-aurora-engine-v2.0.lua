-- FERAL AURORA v2.0 / Engine and replicated-player visual finder
-- Client presentation, own-character controls, native Rest requests, and reversible config leases.
-- No server code, grants, HP writes, Amber writes, death bypass or fake ownership.
local Engine={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local HttpService=game:GetService("HttpService")
local player=Players.LocalPlayer
local function finite(n)
    return type(n)=="number" and n==n and n>-math.huge and n<math.huge
end
local function fmt(n,d)
    return finite(n) and string.format("%."..tostring(d or 1).."f",n) or "--"
end
local function make(class,props,parent)
    local o=Instance.new(class)
    for key,v in pairs(props or {}) do o[key]=v end
    if parent then o.Parent=parent end
    return o
end
local function own()
    local char=player and player.Character
    if not char or not char.Parent then return nil,nil,nil end
    return char,char:FindFirstChildOfClass("Humanoid"),char:FindFirstChild("HumanoidRootPart")
end
local function restoreEntries(entries)
    for i=#(entries or {}),1,-1 do
        local e=entries[i]
        pcall(function()
            if e.target[e.key]==e.wanted then e.target[e.key]=e.previous end
        end)
    end
end
local function patchTable(t,plan)
    if type(t)~="table" then return nil end
    local entries={}
    for key,value in pairs(plan) do
        local ok,old=pcall(function()return t[key]end)
        if not ok or (not finite(old) and type(old)~="boolean") then
            restoreEntries(entries);return nil
        end
        if old~=value then
            local okWrite=pcall(function()t[key]=value end)
            if not okWrite then restoreEntries(entries);return nil end
            entries[#entries+1]={target=t,key=key,wanted=value,previous=old}
        end
    end
    return entries
end
local function module(name)
    local f=RS:FindFirstChild("FeralWorld")
    local m=f and f:FindFirstChild(name)
    if not m or not m:IsA("ModuleScript") then return nil end
    local ok,r=pcall(require,m)
    return ok and type(r)=="table" and r or nil
end
function Engine.new(atlas)
    local ctx={}
    ctx.atlas=type(atlas)=="table" and atlas or {}
    ctx.atlasReady=#ctx.atlas>0
    ctx.palette={
        bg=Color3.fromRGB(9,15,24),shell=Color3.fromRGB(12,20,31),
        panel=Color3.fromRGB(22,32,47),panel2=Color3.fromRGB(29,42,58),
        line=Color3.fromRGB(55,76,93),text=Color3.fromRGB(240,247,255),
        muted=Color3.fromRGB(162,180,197),dim=Color3.fromRGB(118,145,166),
        teal=Color3.fromRGB(75,226,194),violet=Color3.fromRGB(179,146,255),
        coral=Color3.fromRGB(255,154,130),amber=Color3.fromRGB(243,191,106),
        red=Color3.fromRGB(236,105,126),green=Color3.fromRGB(99,225,166)
    }
    local S={
        alive=true,theme="teal",scale=1,closed=false,hidden=false,
        flags={recovery=false,vision=false,calm=false,performance=false,
            mobility=false,speed=false,leap=false,playerFinder=false,
            tags=true,outlines=true,throughWalls=false,alerts=true},
        range=300,limit=24,tagScale=1,restChar=nil,mask=nil,lastRest=-math.huge,
        restSent=0,restFailed=0,restEchoed=0,lastTracker=-math.huge,
        leases={},attrLeases={},byPlayer={},light=nil,log={},
        notice="Aurora ready. All gameplay changes are OFF.",
        stat={},statusText={},nearby={},survivalMinutes=0,
        favourites={},query="",atlasCategory="All",atlasPage=1,
        lastNeedsWarning=-math.huge,mutedWarnings=false,
        chosenLocation=1,sessionStart=os.clock(),lastUI=-math.huge,
        lastPoll=-math.huge,lastHealth=nil,lastStamina=nil,
        lastHPTime=nil,lastChar=nil,lastSpeed=0
    }
    ctx.state=S
    ctx.onUI=function() end
    ctx.onNotice=function() end
    ctx.ui=nil
    ctx.locations={
        {"Oasis / The spring",1070,1505},{"Canyon arch",818,1432},
        {"Golden Waterhole",-240,220},{"Eagle Rock",711,-105},
        {"Great Falls",15,-504},{"Frost Lake",30,-990},
        {"Beaver Ponds",-546,60},{"Pine Woods",-1140,180},
        {"Lunar Crest",-600,-1050},{"Goat Cliffs",1215,-855},
        {"Black Ravine",165,1620},{"Elder Giants",-1182,583},
        {"Golden Plains",717,882},{"Elk Crossing",-6,606},
        {"Rattlebone Mesa",1158,621},{"Tall Marsh",-826,1996},
        {"Mudlands",860,2110},{"Dead Lagoon",180,2142}
    }
    local prefPath="FERAL_Aurora_Preferences_v2.json"
    function ctx.accent()return ctx.palette[S.theme] or ctx.palette.teal end
    function ctx.notice(txt)
        S.notice=tostring(txt)
        S.log[#S.log+1]=string.format("%0.0fs %s",os.clock()-S.sessionStart,txt)
        if #S.log>30 then table.remove(S.log,1) end
        pcall(ctx.onNotice)
    end
    function ctx.loadPrefs()
        if type(readfile)~="function" then return end
        local ok,prefs=pcall(function()return HttpService:JSONDecode(readfile(prefPath)) end)
        if not ok or type(prefs)~="table" then return end
        if prefs.theme=="teal" or prefs.theme=="violet" or prefs.theme=="coral" then
            S.theme=prefs.theme
        end
        if finite(prefs.scale) and prefs.scale>=.70 and prefs.scale<=1.16 then
            S.scale=prefs.scale
        end
        if type(prefs.favourites)=="table" then
            for _,title in ipairs(prefs.favourites) do
                if type(title)=="string" and #title<=92 then S.favourites[title]=true end
            end
        end
        if finite(prefs.range) and prefs.range>=100 and prefs.range<=900 then
            S.range=prefs.range
        end
    end
    function ctx.savePrefs()
        if type(writefile)~="function" then return end
        local names={}
        for title,enabled in pairs(S.favourites) do
            if enabled and #names<128 then names[#names+1]=title end
        end
        pcall(function()
            writefile(prefPath,HttpService:JSONEncode({
                theme=S.theme,scale=S.scale,favourites=names,range=S.range
            }))
        end)
    end
    ctx.loadPrefs()
    function ctx.setTheme(name)
        if name~="teal" and name~="violet" and name~="coral" then return end
        S.theme=name;ctx.savePrefs();ctx.notice("Accent switched to "..name)
        ctx.onUI()
    end
    function ctx.setScale(value)
        if finite(value) then
            S.scale=math.clamp(value,.70,1.16)
            ctx.savePrefs();ctx.onUI()
        end
    end
    function ctx.toggleFavourite(title)
        if type(title)~="string" or #title>92 then return end
        S.favourites[title]=not S.favourites[title]
        ctx.savePrefs();ctx.onUI()
    end
    function ctx.setRange(nextRange)
        if finite(nextRange) then
            S.range=math.clamp(nextRange,100,900)
            ctx.savePrefs();ctx.notice("Player finder range: "..S.range.." studs")
            ctx.refreshTracker(true);ctx.onUI()
        end
    end
    local function setAttrLease(key,changes,enable)
        if not enable then
            for _,e in ipairs(S.attrLeases[key] or {}) do
                pcall(function()
                    if player:GetAttribute(e.key)==e.wanted then
                        player:SetAttribute(e.key,e.previous)
                    end
                end)
            end
            S.attrLeases[key]=nil
            return true
        end
        local entries={}
        for attr,wanted in pairs(changes) do
            local before=player:GetAttribute(attr)
            local ok=pcall(function()player:SetAttribute(attr,wanted) end)
            if not ok then
                for _,e in ipairs(entries) do
                    pcall(function()player:SetAttribute(e.key,e.previous)end)
                end
                return false
            end
            entries[#entries+1]={key=attr,wanted=wanted,previous=before}
        end
        S.attrLeases[key]=entries
        return true
    end
    local function stopRest()
        local m=S.mask;S.mask=nil
        if m and m.connection then pcall(function()m.connection:Disconnect()end) end
        local char=S.restChar;S.restChar=nil
        if char and char.Parent and player.Character==char then
            local remote=RS:FindFirstChild("WolfActions")
            if remote and remote:IsA("RemoteEvent") then
                pcall(function()remote:FireServer("Rest",false)end)
            end
        end
    end
    local function startRestMask(char)
        local m={char=char,busy=false}
        S.mask=m
        local function enforce()
            if not S.alive or not S.flags.recovery or S.mask~=m or m.busy
                or player.Character~=char then return end
            if char:GetAttribute("WolfRest")==true then
                S.restEchoed=S.restEchoed+1
                m.busy=true
                pcall(function()char:SetAttribute("WolfRest",false)end)
                m.busy=false
            end
        end
        m.connection=char:GetAttributeChangedSignal("WolfRest"):Connect(enforce)
        enforce()
    end
    local function needsRecovery(char,hum)
        if not char or not hum or hum.Health<=0
            or char:GetAttribute("FeralDowned")==true then return false end
        if hum.Health < hum.MaxHealth-.01 then return true end
        for _,key in ipairs({"FeralBleed","FeralInjury","FeralVenomAmt"}) do
            local v=char:GetAttribute(key)
            if finite(v) and v>0 then return true end
        end
        return false
    end
    local function recoveryTick(now)
        if not S.flags.recovery or now-S.lastRest<5 then return end
        S.lastRest=now
        local char,hum,root=own()
        if not root or player:GetAttribute("FeralMenuOpen")==true
            or not needsRecovery(char,hum) then
            if S.restChar then stopRest() end
            return
        end
        if S.restChar~=char then
            if S.restChar then stopRest() end
            S.restChar=char
            startRestMask(char)
        end
        local remote=RS:FindFirstChild("WolfActions")
        if not remote or not remote:IsA("RemoteEvent") then
            S.restFailed=S.restFailed+1
            if S.restFailed==1 then
                ctx.notice("Recovery request unavailable. Native remote absent.")
            end
            return
        end
        local ok=pcall(function()remote:FireServer("Rest",true)end)
        if ok then S.restSent=S.restSent+1 else S.restFailed=S.restFailed+1 end
    end
    local function turnFeature(key,on)
        if key=="recovery" then
            if not on then stopRest() end
            S.lastRest=-math.huge;return true
        elseif key=="vision" then
            if S.light then S.light:Destroy();S.light=nil end
            if on then
                S.light=make("ColorCorrectionEffect",{Name="FeralAuroraLocalVision",
                    Brightness=.12,Contrast=-.06,Saturation=.03},Lighting)
            end
            return true
        elseif key=="calm" then
            return setAttrLease(key,{FeralSet_shake=0,FeralSet_sway=false},on)
        elseif key=="performance" then
            return setAttrLease(key,{FeralSet_perf=true},on)
        elseif key=="mobility" then
            if not on then
                restoreEntries(S.leases.mobilityA)
                restoreEntries(S.leases.mobilityB)
                S.leases.mobilityA=nil;S.leases.mobilityB=nil
                return true
            end
            local needs=module("NeedsConfig")
            local status=module("StatusConfig")
            local injury=status and status.INJURY
            if type(needs)~="table" or not finite(needs.HURT_SLOW)
                or type(injury)~="table" or not finite(injury.SLOW_PER_POINT) then return false end
            local a=patchTable(needs,{HURT_SLOW=0})
            local b=patchTable(injury,{SLOW_PER_POINT=0})
            if not a or not b then restoreEntries(a);restoreEntries(b);return false end
            S.leases.mobilityA=a;S.leases.mobilityB=b;return true
        elseif key=="speed" then
            if not on then
                restoreEntries(S.leases.speed);S.leases.speed=nil;return true
            end
            local c=module("NeedsConfig")
            if not c or not finite(c.RUN_SPEED) or not finite(c.SWIM_SPEED)
                or c.RUN_SPEED<=0 or c.SWIM_SPEED<=0 or c.RUN_SPEED>4
                or c.SWIM_SPEED>4 then return false end
            S.leases.speed=patchTable(c,{RUN_SPEED=c.RUN_SPEED*1.10,
                SWIM_SPEED=c.SWIM_SPEED*1.10})
            return S.leases.speed~=nil
        elseif key=="leap" then
            if not on then
                restoreEntries(S.leases.leapA)
                restoreEntries(S.leases.leapB)
                S.leases.leapA=nil;S.leases.leapB=nil
                return true
            end
            local c=module("JumpLeapConfig")
            if not c or c.ON~=true or type(c.of)~="function"
                or type(c.BODY_LENGTHS)~="table" or not finite(c.DEFAULT)
                or not finite(c.MAX_RUN_SHARE) then return false end
            local plan={}
            for species,value in pairs(c.BODY_LENGTHS) do
                if type(species)=="string" and finite(value) and value>=0 and value<=10 then
                    plan[species]=value*1.10
                end
            end
            if not next(plan) then return false end
            local a=patchTable(c,{DEFAULT=c.DEFAULT*1.10,
                MAX_RUN_SHARE=c.MAX_RUN_SHARE*1.10})
            local b=patchTable(c.BODY_LENGTHS,plan)
            if not a or not b then restoreEntries(a);restoreEntries(b);return false end
            S.leases.leapA=a;S.leases.leapB=b;return true
        elseif key=="playerFinder" or key=="tags" or key=="outlines"
            or key=="throughWalls" or key=="alerts" then
            return true
        end
        return false
    end
    local labels={
        recovery="Recovery Assist",vision="Brighter View",calm="Calm Camera",
        performance="Native Performance",mobility="Injury Slowdown Inputs",
        speed="1.10x Speed Inputs",leap="1.10x Leap Inputs",
        playerFinder="Player Finder",tags="Name Tags",outlines="Character Outlines",
        throughWalls="Through-Wall Outlines",alerts="Survival Alerts"
    }
    function ctx.toggle(key,value)
        if not S.alive or S.flags[key]==nil then return end
        local nextValue=value
        if nextValue==nil then nextValue=not S.flags[key] end
        nextValue=nextValue==true
        if nextValue==S.flags[key] then return end
        local ok,result=pcall(turnFeature,key,nextValue)
        if not ok or not result then
            ctx.notice("Unavailable: "..(labels[key] or key).." (live client fields did not match)")
            return
        end
        S.flags[key]=nextValue
        if key=="playerFinder" or key=="tags" or key=="outlines" or key=="throughWalls" then
            ctx.refreshTracker(true)
        end
        ctx.notice((nextValue and "ON  " or "OFF  ")..(labels[key] or key))
        ctx.onUI()
    end
    function ctx.reset()
        for _,key in ipairs({"recovery","mobility","speed","leap","vision",
            "calm","performance","playerFinder","throughWalls"}) do
            if S.flags[key] then ctx.toggle(key,false) end
        end
        ctx.notice("RESTORED: all modified settings and player overlays off.")
        ctx.onUI()
    end
    local function clearRecord(plr)
        local r=S.byPlayer[plr]
        S.byPlayer[plr]=nil
        if r then
            pcall(function()if r.h then r.h:Destroy() end end)
            pcall(function()if r.b then r.b:Destroy() end end)
        end
    end
    local function newRecord(plr,character)
        local c=ctx.palette
        local h=make("Highlight",{
            Name="Aurora_PlayerOutline",Adornee=character,
            DepthMode=Enum.HighlightDepthMode.Occluded,
            FillTransparency=.82,OutlineTransparency=.06,
            FillColor=c.teal,OutlineColor=c.teal,Enabled=true},player.PlayerGui)
        local b=make("BillboardGui",{
            Name="Aurora_PlayerTag",Adornee=character:FindFirstChild("Head")
                or character:FindFirstChild("HumanoidRootPart"),
            AlwaysOnTop=false,MaxDistance=S.range,Size=UDim2.fromOffset(182,56),
            StudsOffsetWorldSpace=Vector3.new(0,3.3,0),LightInfluence=0,
            Enabled=true},player.PlayerGui)
        local plate=make("Frame",{
            Size=UDim2.fromScale(1,1),BorderSizePixel=0,
            BackgroundColor3=Color3.fromRGB(12,21,33),
            BackgroundTransparency=.12},b)
        make("UICorner",{CornerRadius=UDim.new(0,9)},plate)
        make("UIStroke",{Color=c.teal,Transparency=.2,Thickness=1},plate)
        local name=make("TextLabel",{
            BackgroundTransparency=1,Text="ANIMAL",Font=Enum.Font.GothamBold,
            TextSize=12,TextColor3=c.text,TextXAlignment=Enum.TextXAlignment.Left,
            TextTruncate=Enum.TextTruncate.AtEnd,
            Position=UDim2.fromOffset(9,3),Size=UDim2.fromOffset(166,18)},plate)
        local info=make("TextLabel",{
            BackgroundTransparency=1,Text="",Font=Enum.Font.Gotham,
            TextSize=10,TextColor3=c.muted,TextXAlignment=Enum.TextXAlignment.Left,
            TextTruncate=Enum.TextTruncate.AtEnd,
            Position=UDim2.fromOffset(9,21),Size=UDim2.fromOffset(166,15)},plate)
        local bar=make("Frame",{
            BackgroundColor3=Color3.fromRGB(54,65,76),BorderSizePixel=0,
            Position=UDim2.fromOffset(9,42),Size=UDim2.fromOffset(164,6)},plate)
        make("UICorner",{CornerRadius=UDim.new(1,0)},bar)
        local fill=make("Frame",{
            BackgroundColor3=c.green,BorderSizePixel=0,Size=UDim2.fromScale(1,1)},bar)
        make("UICorner",{CornerRadius=UDim.new(1,0)},fill)
        local r={char=character,h=h,b=b,name=name,info=info,fill=fill}
        S.byPlayer[plr]=r
        return r
    end
    function ctx.refreshTracker(force)
        if not S.alive then return end
        local now=os.clock()
        if not force and now-S.lastTracker<.35 then return end
        S.lastTracker=now
        if not S.flags.playerFinder then
            for p in pairs(S.byPlayer) do clearRecord(p) end
            S.nearby={};return
        end
        local char,hum,root=own()
        if not root then
            for p in pairs(S.byPlayer) do clearRecord(p) end
            S.nearby={};return
        end
        local near={}
        local seen={}
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player and p.Character then
                local other=p.Character
                local op=other:FindFirstChild("HumanoidRootPart")
                local oh=other:FindFirstChildOfClass("Humanoid")
                if op and oh and oh.Health>0 then
                    local d=(root.Position-op.Position).Magnitude
                    if d<=S.range then
                        near[#near+1]={player=p,char=other,hum=oh,
                            root=op,distance=d}
                    end
                end
            end
        end
        table.sort(near,function(a,b)return a.distance<b.distance end)
        S.nearby={}
        for i=1,math.min(S.limit,#near) do
            local x=near[i]
            seen[x.player]=true
            local v=x.char:GetAttribute("Species")
            local species=type(v)=="string" and v or "Unknown"
            local ratio=(x.hum.MaxHealth>0 and x.hum.Health/x.hum.MaxHealth or 0)
            ratio=math.clamp(ratio,0,1)
            local color=x.distance<145 and ctx.palette.teal
                or x.distance<320 and ctx.palette.amber or ctx.palette.coral
            local r=S.byPlayer[x.player]
            if r and r.char~=x.char then clearRecord(x.player);r=nil end
            if not r then r=newRecord(x.player,x.char) end
            r.h.Adornee=x.char;r.h.Enabled=S.flags.outlines
            r.h.DepthMode=S.flags.throughWalls and
                Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            r.h.FillColor=color;r.h.OutlineColor=color
            r.b.Adornee=x.char:FindFirstChild("Head") or x.root
            r.b.Enabled=S.flags.tags
            r.b.AlwaysOnTop=S.flags.throughWalls
            r.b.MaxDistance=S.range
            local display=x.player.DisplayName or x.player.Name
            if #display>22 then display=string.sub(display,1,21).."…" end
            r.name.Text=display
            r.info.Text=species.."  •  "..math.floor(x.distance+.5).." studs"
            r.fill.Size=UDim2.fromScale(ratio,1)
            r.fill.BackgroundColor3=ratio>.5 and ctx.palette.green
                or ratio>.25 and ctx.palette.amber or ctx.palette.red
            S.nearby[#S.nearby+1]={name=display,species=species,
                distance=x.distance,health=x.hum.Health,maxHealth=x.hum.MaxHealth}
        end
        for p in pairs(S.byPlayer) do
            if not seen[p] then clearRecord(p) end
        end
    end
    function ctx.effects()
        local char,hum=own()
        if not char then return {"Spawn an animal to see effects."} end
        local lines={}
        for _,entry in ipairs({
            {"FeralInjury","Injury"},{"FeralBleed","Bleeding"},
            {"FeralVenomAmt","Venom"},{"StaminaOut","Exhausted"},
            {"FeralPinned","Pinned"},{"FeralDragged","Dragged"},
            {"FeralLatching","Latched"},{"FeralVenomDown","Venom down"},
            {"FeralHomeTurf","Home Turf"},{"FeralGrazing","Grazing"},
            {"FeralBurrowed","Burrowed"}
        }) do
            local value=char:GetAttribute(entry[1])
            if value==true or finite(value) and value>0
                or type(value)=="string" and value~="" then
                lines[#lines+1]=entry[2]..(finite(value) and (" "..fmt(value,1)) or "")
            end
        end
        local now=workspace:GetServerTimeNow()
        for _,entry in ipairs({
            {"FeralThriveUntil","Thriving"},{"FeralHobbledUntil","Hobbled"}
        }) do
            local value=char:GetAttribute(entry[1])
            if finite(value) and value>now then
                lines[#lines+1]=entry[2].." ("..math.ceil(value-now).."s)"
            end
        end
        local regrow=player:GetAttribute("FeralRegrowLeft")
        if finite(regrow) and regrow>0 then lines[#lines+1]="Regrowth "..fmt(regrow) end
        if char:GetAttribute("WolfRest")==true then lines[#lines+1]="Resting" end
        return #lines>0 and lines or {"No tracked active effects."}
    end
    function ctx.stats()
        local char,hum,root=own()
        local result={
            species=char and char:GetAttribute("Species") or "--",
            stage=char and char:GetAttribute("AgeStage") or "--",
            hp=hum and hum.Health, maxHp=hum and hum.MaxHealth,
            stamina=char and char:GetAttribute("Stamina"),
            maxStamina=char and char:GetAttribute("StaminaMax"),
            hunger=char and char:GetAttribute("Hunger"),
            thirst=char and char:GetAttribute("Thirst"),
            growth=char and char:GetAttribute("Growth"),
            amber=player:GetAttribute("Amber"),
            speed=root and Vector3.new(root.AssemblyLinearVelocity.X,0,
                root.AssemblyLinearVelocity.Z).Magnitude,
            pos=root and root.Position,
            exhausted=char and char:GetAttribute("StaminaOut")==true,
            mode=char and char:GetAttribute("WolfBurst")==true and "Burst"
                or player:GetAttribute("HudSprint")==true and "Sprint"
                or "Ordinary",
            serverRest=char and char:GetAttribute("WolfRest")==true,
            hudRest=player:GetAttribute("HudRest")==true,
            combat=finite(player:GetAttribute("FeralCombatUntil")) and
                player:GetAttribute("FeralCombatUntil")>workspace:GetServerTimeNow(),
            activeCount=0
        }
        result.activeCount=#ctx.effects()
        return result
    end
    function ctx.survivalMultiplier(minutes)
        local m=math.max(0,finite(minutes) and minutes or 0)
        return math.min(3,1+.1*math.min(10,math.floor(m/10))
            +.1*math.min(10,math.floor(math.max(0,m-100)/15)))
    end
    function ctx.openNative(which)
        local attr=which=="rewards" and "FeralRewardsRequest"
            or which=="guide" and "FeralGuideRequest" or nil
        if not attr then return end
        local n=os.clock()
        if player:GetAttribute(attr)==n then n=n+.001 end
        local ok=pcall(function()player:SetAttribute(attr,n)end)
        ctx.notice(ok and ("Opened normal "..which.." interface")
            or ("Native "..which.." interface unavailable"))
    end
    function ctx.compass(point)
        local _,_,root=own()
        if not root then return "Spawn an animal for directions." end
        local dx=point[2]-root.Position.X
        local dz=point[3]-root.Position.Z
        local distance=math.sqrt(dx*dx+dz*dz)
        local camera=workspace.CurrentCamera
        local look=camera and camera.CFrame.LookVector or root.CFrame.LookVector
        local f=dx*look.X+dz*look.Z
        local right=dx*-look.Z+dz*look.X
        local angle=math.deg(math.atan2(right,f))
        local direction=math.abs(angle)>155 and "BEHIND" or angle>30 and "RIGHT"
            or angle< -30 and "LEFT" or "AHEAD"
        return string.format("%s  /  %.0f studs  /  %+.0f°",
            direction,distance,angle)
    end
    function ctx.copyStatus()
        local a=ctx.stats()
        local lines={
            "FERAL AURORA v2.0 | own-client status",
            "Species: "..tostring(a.species).." stage: "..tostring(a.stage),
            "HP: "..fmt(a.hp).."/"..fmt(a.maxHp).." stamina: "..
                fmt(a.stamina).."/"..fmt(a.maxStamina),
            "Hunger: "..fmt(a.hunger).." thirst: "..fmt(a.thirst)
                .." growth: "..fmt(a.growth,3).." Amber (visible): "..fmt(a.amber,0),
            "Mode: "..a.mode.." exhaustion: "..tostring(a.exhausted),
            "Local HudRest: "..tostring(a.hudRest),
            "Rest requests: "..S.restSent.." failed: "..S.restFailed..
                " local echoes: "..S.restEchoed,
            "Player finder: "..tostring(S.flags.playerFinder)
                .." name tags: "..tostring(S.flags.tags)
                .." outlines: "..tostring(S.flags.outlines)
                .." walls: "..tostring(S.flags.throughWalls)
                .." range: "..S.range.." count: "..#S.nearby,
            "Own active effects: "..table.concat(ctx.effects(),", "),
            "Enabled features:"
        }
        for key,enabled in pairs(S.flags) do
            if enabled then lines[#lines+1]="- "..key end
        end
        lines[#lines+1]="Client display and Rest requests do not prove server acceptance."
        local result=table.concat(lines,"\n")
        local copy=type(setclipboard)=="function" and setclipboard
            or type(toclipboard)=="function" and toclipboard or nil
        if copy then
            local ok=pcall(copy,result)
            if ok then ctx.notice("Status copied to clipboard.");return true,result end
        end
        ctx.notice("Clipboard unavailable; use the selectable text field.")
        return false,result
    end
    function ctx.tick()
        if not S.alive then return end
        local now=os.clock()
        if now-S.lastPoll>=.3 then
            S.lastPoll=now
            recoveryTick(now)
            ctx.refreshTracker(false)
            local current=ctx.stats()
            if S.flags.alerts and now-S.lastNeedsWarning>=25 then
                local h,t=current.hunger,current.thirst
                if finite(h) and h<20 or finite(t) and t<20 then
                    ctx.notice("Low needs: hunger/thirst under 20 may reduce stamina recovery.")
                    S.lastNeedsWarning=now
                elseif current.exhausted then
                    ctx.notice("Exhaustion detected. The visible stamina bar may not tell the full story.")
                    S.lastNeedsWarning=now
                end
            end
        end
        if now-S.lastUI>=.5 then
            S.lastUI=now;pcall(ctx.onUI)
        end
    end
    ctx.connection=RunService.Heartbeat:Connect(ctx.tick)
    function ctx.close()
        if not S.alive then return end
        ctx.reset()
        S.alive=false
        if ctx.connection then ctx.connection:Disconnect() end
        for p in pairs(S.byPlayer) do clearRecord(p) end
        if ctx.ui then pcall(function()ctx.ui:Destroy()end)end
    end
    return ctx
end
return Engine
