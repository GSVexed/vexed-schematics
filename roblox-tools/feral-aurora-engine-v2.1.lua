-- FERAL AURORA v2.1 / Engine: menu-aware finder, local reports and survival tools
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
            mobility=false,speed=false,leap=false,lowNeedsAssist=false,
            playerFinder=false,
            tags=true,outlines=true,throughWalls=false,alerts=true,
            localAutosave=false,miniHUD=false},
        range=300,limit=24,tagScale=1,outlineStyle="subtle",
        restChar=nil,mask=nil,lastRest=-math.huge,
        restSent=0,restFailed=0,restEchoed=0,lastTracker=-math.huge,
        finderOrigin="NONE",finderReason="OFF",finderCounts={players=0,live=0,inRange=0,shown=0},
        leases={},attrLeases={},byPlayer={},highlightFolder=nil,light=nil,log={},
        notice="Aurora ready. All gameplay changes are OFF.",
        stat={},statusText={},nearby={},survivalMinutes=0,
        favourites={},query="",atlasCategory="All",atlasPage=1,
        lastNeedsWarning=-math.huge,mutedWarnings=false,
        chosenLocation=1,sessionStart=os.clock(),lastUI=-math.huge,
        lastPoll=-math.huge,lastHealth=nil,lastStamina=nil,
        lastHPTime=nil,lastChar=nil,lastSpeed=0,
        resource={kind="none",origin="none",candidates={},at=0,summary="Not searched yet"},
        lastLocalSave=0,localSaveCount=0,localHistory={},
        localSaveResult="Not saved. GitHub sync is not connected.",
        statusPath="FERAL_Aurora_Status_v2_1.json.txt"
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
    function ctx.setOutlineStyle(name)
        if name~="subtle" and name~="bold" then return end
        S.outlineStyle=name
        ctx.refreshTracker(true)
        ctx.notice("Outline style: "..name)
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
        elseif key=="lowNeedsAssist" then
            if not on then
                restoreEntries(S.leases.lowNeedsAssist)
                S.leases.lowNeedsAssist=nil
                return true
            end
            local c=module("NeedsConfig")
            if not c or not finite(c.STAMINA_LOW_NEEDS)
                or c.STAMINA_LOW_NEEDS<0 or c.STAMINA_LOW_NEEDS>1 then return false end
            S.leases.lowNeedsAssist=patchTable(c,{STAMINA_LOW_NEEDS=1})
            return S.leases.lowNeedsAssist~=nil
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
            or key=="throughWalls" or key=="alerts" or key=="localAutosave"
            or key=="miniHUD" then
            return true
        end
        return false
    end
    local labels={
        recovery="Recovery Assist",vision="Brighter View",calm="Calm Camera",
        performance="Native Performance",mobility="Injury Slowdown Inputs",
        lowNeedsAssist="Client Low-Needs Stamina Penalty",speed="1.10x Speed Inputs",leap="1.10x Leap Inputs",
        playerFinder="Player Finder",tags="Name Tags",outlines="Character Outlines",
        throughWalls="Through-Wall Outlines",alerts="Survival Alerts",
        localAutosave="Local Report Auto-Save",miniHUD="Compact Status HUD"
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
        for _,key in ipairs({"recovery","mobility","lowNeedsAssist","speed",
            "leap","vision",
            "calm","performance","playerFinder","throughWalls","localAutosave",
            "miniHUD"}) do
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
    local function getHighlightFolder()
        if S.highlightFolder and S.highlightFolder.Parent then return S.highlightFolder end
        -- Client-created workspace descendants render as 3D highlights,
        -- unlike PlayerGui-parented Highlight instances on some Roblox builds.
        S.highlightFolder=make("Folder",{Name="FeralAuroraLocalHighlightsV2"},workspace)
        return S.highlightFolder
    end
    local function newRecord(plr,character)
        local c=ctx.palette
        local h=make("Highlight",{
            Name="Aurora_PlayerOutline",Adornee=character,
            DepthMode=Enum.HighlightDepthMode.Occluded,
            FillTransparency=.82,OutlineTransparency=.06,
            FillColor=c.teal,OutlineColor=c.teal,Enabled=true},getHighlightFolder())
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
            S.finderOrigin="NONE";S.finderReason="OFF"
            S.finderCounts={players=0,live=0,inRange=0,shown=0}
            for p in pairs(S.byPlayer) do clearRecord(p) end
            if S.highlightFolder then
                pcall(function()S.highlightFolder:Destroy()end)
                S.highlightFolder=nil
            end
            S.nearby={};return
        end
        local char,hum,root=own()
        local camera=workspace.CurrentCamera
        local origin=root and root.Position
            or camera and camera.CFrame.Position or nil
        S.finderOrigin=root and "ANIMAL" or origin and "MENU CAMERA" or "NO CAMERA"
        if not origin then
            S.finderReason="Waiting for a valid character or camera."
            for p in pairs(S.byPlayer) do clearRecord(p) end
            S.nearby={};return
        end
        local near={}
        local seen={}
        local counts={players=0,live=0,inRange=0,shown=0}
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player then counts.players=counts.players+1 end
            if p~=player and p.Character then
                local other=p.Character
                local op=other:FindFirstChild("HumanoidRootPart")
                local oh=other:FindFirstChildOfClass("Humanoid")
                if op and oh and oh.Health>0 then
                    counts.live=counts.live+1
                    local d=(origin-op.Position).Magnitude
                    if d<=S.range then
                        counts.inRange=counts.inRange+1
                        near[#near+1]={player=p,char=other,hum=oh,
                            root=op,distance=d}
                    end
                end
            end
        end
        table.sort(near,function(a,b)return a.distance<b.distance end)
        S.nearby={}
        counts.shown=math.min(S.limit,#near)
        S.finderCounts=counts
        S.finderReason=counts.players==0 and "No other players in this server."
            or counts.live==0 and "Other players exist, but no living characters are replicated."
            or counts.inRange==0 and "No replicated characters within the selected range."
            or "Tracking "..counts.shown.." replicated characters from "..S.finderOrigin.."."
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
            r.h.FillTransparency=S.outlineStyle=="bold" and .60 or .86
            r.h.OutlineTransparency=S.outlineStyle=="bold" and 0 or .12
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
        if not char then return {"Animal menu — no active animal effects to read."} end
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
            sessionPhase=not char and "ANIMAL MENU" or (not hum or not root)
                and "SPAWNING" or hum.Health<=0 and "DOWNED / DEAD" or "IN GAME",
            species=char and char:GetAttribute("Species") or "Animal menu",
            stage=char and char:GetAttribute("AgeStage") or "No active animal",
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
            exhausted=char and char:GetAttribute("StaminaOut")==true or false,
            mode=not char and "Menu" or char:GetAttribute("WolfBurst")==true and "Burst"
                or player:GetAttribute("HudSprint")==true and "Sprint"
                or "Ordinary",
            serverRest=char and char:GetAttribute("WolfRest")==true,
            hudRest=player:GetAttribute("HudRest")==true,
            combat=finite(player:GetAttribute("FeralCombatUntil")) and
                player:GetAttribute("FeralCombatUntil")>workspace:GetServerTimeNow(),
            activeCount=0
        }
        result.activeCount=char and #ctx.effects() or 0
        return result
    end

    -- Server-held needs and buffs cannot be minted by client attributes.
    -- Resource Finder only pinpoints replicated named props and map POIs.
    function ctx.resourceHelp()
        local a=ctx.stats()
        if a.sessionPhase~="IN GAME" then
            return "Spawn an animal first. Hunger/thirst are not readable in the menu."
        end
        local h,t=a.hunger,a.thirst
        local advice={}
        if not finite(h) then
            advice[#advice+1]="HUNGER UNKNOWN: this animal has no readable needs value."
        elseif h<20 then
            advice[#advice+1]="HUNGER CRITICAL: native feeding needed; client edits won't refill it."
        elseif h<45 then
            advice[#advice+1]="HUNGER LOW: look for edible prey, carcasses or forage for your species."
        else advice[#advice+1]="Hunger: "..fmt(h,1).." (currently adequate)." end
        if not finite(t) then
            advice[#advice+1]="THIRST UNKNOWN: this animal has no readable needs value."
        elseif t<20 then
            advice[#advice+1]="THIRST CRITICAL: reach drinking water; no remote refill available."
        elseif t<45 then
            advice[#advice+1]="THIRST LOW: navigate toward a water source."
        else advice[#advice+1]="Thirst: "..fmt(t,1).." (currently adequate)." end
        return table.concat(advice,"\n")
    end
    local waterNames={"water","pond","lake","river","creek","spring","pool","waterhole","drink"}
    local foodNames={"food","grass","feed","carcass","corpse","berry","berries","fish","plant","meat","bush","prey"}
    local function isCandidate(part,terms)
        local names={part.Name}
        local ancestor=part.Parent
        for i=1,2 do
            if not ancestor or ancestor==workspace then break end
            names[#names+1]=ancestor.Name
            ancestor=ancestor.Parent
        end
        local name=string.lower(table.concat(names," "))
        for _,term in ipairs(terms) do
            if string.find(name,term,1,true) then
                return true
            end
        end
        return false
    end
    function ctx.findResources(kind)
        if kind~="food" and kind~="water" then return end
        local char,hum,root=own()
        if not root or not hum or hum.Health<=0 then
            S.resource={kind=kind,origin="NONE",candidates={},at=os.clock(),
                summary="Spawn your animal before searching for "..kind.."."}
            ctx.notice(S.resource.summary);ctx.onUI()
            return
        end
        local candidates={}
        local terms=kind=="water" and waterNames or foodNames
        local params=OverlapParams.new()
        params.MaxParts=1100
        local ok,parts=pcall(function()
            return workspace:GetPartBoundsInRadius(root.Position,500,params)
        end)
        if not ok or type(parts)~="table" then parts={} end
        local checked=math.min(#parts,1100)
        for i=1,checked do
            local part=parts[i]
            if part:IsA("BasePart") and not part:IsDescendantOf(char)
                and isCandidate(part,terms) then
                local d=(part.Position-root.Position).Magnitude
                candidates[#candidates+1]={name=part.Parent and part.Parent.Name or part.Name,
                    distance=d,kind="replicated name match",position=part.Position}
            end
        end
        table.sort(candidates,function(a,b)return a.distance<b.distance end)
        while #candidates>5 do table.remove(candidates)end
        if kind=="water" then
            for _,point in ipairs(ctx.locations) do
                if isCandidate({Name=point[1],Parent=workspace},waterNames) then
                    local d=math.sqrt((root.Position.X-point[2])^2+
                        (root.Position.Z-point[3])^2)
                    candidates[#candidates+1]={name=point[1],distance=d,
                        kind="recorded map POI",x=point[2],z=point[3]}
                end
            end
            table.sort(candidates,function(a,b)return a.distance<b.distance end)
            while #candidates>7 do table.remove(candidates)end
        end
        local summary=#candidates==0
            and "No nearby named "..kind.." sources found in streamed geometry."
            or (#candidates.." "..kind.." leads from replicated map data (not verified edible/drinkable).")
        S.resource={kind=kind,origin="ANIMAL",candidates=candidates,
            at=os.clock(),summary=summary}
        ctx.notice(summary);ctx.onUI()
    end
    function ctx.pinResource(index)
        local resource=S.resource
        local entry=resource and resource.candidates[index]
        if not entry then return end
        local x,z=entry.x,entry.z
        if not x and entry.position then x=entry.position.X;z=entry.position.Z end
        if finite(x) and finite(z) then
            ctx.customDestination={"Resource: "..entry.name,x,z}
            ctx.notice("Compass now points to "..entry.name.." (name match only).")
            ctx.onUI()
        end
    end
    function ctx.featureStatus(key)
        if S.flags[key]==nil then return "UNAVAILABLE" end
        if not S.flags[key] then return "OFF" end
        if key=="recovery" then
            local char,hum=own()
            return not char and "ARMED • WAITING FOR SPAWN"
                or needsRecovery(char,hum) and "ARMED • NATIVE REST REQUESTS" or
                "ARMED • WAITING FOR NEED"
        elseif key=="playerFinder" then
            return S.finderReason
        elseif key=="mobility" or key=="speed" or key=="leap"
            or key=="lowNeedsAssist" then
            local lease=S.leases[key] or S.leases[key.."A"]
            if not lease then return "CLIENT PATCH NOT AVAILABLE" end
            local matches=true
            for _,item in ipairs(lease) do
                if item.target[item.key]~=item.wanted then matches=false end
            end
            return matches and "LOCAL CLIENT VALUES APPLIED" or "CLIENT VALUES CHANGED"
        elseif key=="localAutosave" then return "LOCAL FILE ONLY • NO GITHUB SYNC"
        elseif key=="throughWalls" then return "LOCAL OVERLAY • NOT SERVER VISION"
        else return "LOCAL SWITCH ON" end
    end
    function ctx.saveStatusFile()
        if type(writefile)~="function" then
            S.localSaveResult="Executor writefile unavailable; copy status instead."
            ctx.notice(S.localSaveResult);return false
        end
        local a=ctx.stats()
        local data={
            schema="feral_aurora_v2_1_local_own_state",reported_at_unix=os.time(),
            session=a.sessionPhase,species=a.species,stage=a.stage,
            hp=a.hp,max_hp=a.maxHp,stamina=a.stamina,max_stamina=a.maxStamina,
            hunger=a.hunger,thirst=a.thirst,growth=a.growth,
            amber_visible=a.amber,exhausted=a.exhausted,
            rest_requested=S.restSent,rest_failed=S.restFailed,
            effects=ctx.effects(),finder_enabled=S.flags.playerFinder,
            finder_origin=S.finderOrigin,finder_count=#S.nearby,
            finder_reason=S.finderReason,
            note="LOCAL ONLY. No other-player identifiers, coordinates, source code or credentials. GitHub upload not configured."
        }
        -- Retain up to sixty own-state snapshots in this current session.
        -- This is local-only; no other players or positions are exported.
        S.localHistory[#S.localHistory+1]=data
        while #S.localHistory>60 do table.remove(S.localHistory,1) end
        local ok,encoded=pcall(function()
            return HttpService:JSONEncode({
                schema="feral_aurora_v2_1_local_session_history",
                record_count=#S.localHistory,
                records=S.localHistory,
                note="Own-character snapshots only; GitHub auto-sync is not configured."
            })
        end)
        if not ok then
            S.localSaveResult="Could not encode own status.";return false
        end
        local written=pcall(function()writefile(S.statusPath,encoded)end)
        if written then
            S.lastLocalSave=os.clock();S.localSaveCount=S.localSaveCount+1
            S.localSaveResult="Saved "..#S.localHistory.." own-state records to "..
                S.statusPath.." in executor workspace. GitHub: not synced."
            ctx.notice("Local own-status file saved; GitHub sync is not configured.")
            return true
        end
        S.localSaveResult="Local file write failed; use COPY STATUS."
        ctx.notice(S.localSaveResult);return false
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
            "FERAL AURORA v2.1 | own-client status",
            "Session: "..a.sessionPhase,
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
                .." origin: "..S.finderOrigin
                .." name tags: "..tostring(S.flags.tags)
                .." outlines: "..tostring(S.flags.outlines)
                .." walls: "..tostring(S.flags.throughWalls)
                .." range: "..S.range.." count: "..#S.nearby,
            "Player finder state: "..S.finderReason,
            "Player counts: server others="..S.finderCounts.players
                ..", replicated living="..S.finderCounts.live
                ..", within range="..S.finderCounts.inRange,
            "Own active effects: "..table.concat(ctx.effects(),", "),
            "Food/water finder: "..S.resource.summary,
            "Local report autosave: "..tostring(S.flags.localAutosave)
                .." ("..S.localSaveCount.." files) | "..S.localSaveResult,
            "GitHub live status sync: NOT CONFIGURED (no automatic upload)",
            "Feature states requested (client-only unless noted):"
        }
        for key,enabled in pairs(S.flags) do
            if enabled then lines[#lines+1]="- "..key end
        end
        lines[#lines+1]="Enabled means requested locally, NOT a verified server-side bonus."
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
            if S.flags.localAutosave and now-S.lastLocalSave>=120 then
                S.lastLocalSave=now
                ctx.saveStatusFile()
            end
            local okTracker=pcall(ctx.refreshTracker,false)
            if not okTracker and S.flags.playerFinder then
                S.flags.playerFinder=false
                for p in pairs(S.byPlayer) do clearRecord(p) end
                if S.highlightFolder then
                    pcall(function()S.highlightFolder:Destroy()end)
                    S.highlightFolder=nil
                end
                ctx.notice("Player Finder stopped after an unexpected local rendering error.")
            end
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
        if ctx.cleanupUI then pcall(ctx.cleanupUI) end
        for p in pairs(S.byPlayer) do clearRecord(p) end
        if S.highlightFolder then
            pcall(function()S.highlightFolder:Destroy()end)
            S.highlightFolder=nil
        end
        if ctx.ui then pcall(function()ctx.ui:Destroy()end)end
    end
    return ctx
end
return Engine
