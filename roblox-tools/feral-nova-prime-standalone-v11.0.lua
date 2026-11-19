-- FERAL NOVA PRIME v11.0 / SINGLE DOWNLOAD BUNDLED RELEASE
-- Private game/server state is not impersonated; all changes local/reversible.
local ROOT="https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/"
if game.PlaceId~=108901361810209 then
    warn("[NOVA PRIME] Open FERAL Animal Survival before running.")
    return
end
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local pg=player and (player:FindFirstChildOfClass("PlayerGui")
    or player:WaitForChild("PlayerGui",10))
if not pg then warn("[NOVA PRIME] PlayerGui unavailable");return end

for _,name in ipairs({
    "FeralNovaPrimeV110","FeralNovaPrimeV100","FeralNovaPrimeV90","FeralNovaPrimeV80","FeralNovaPrimeV70","FeralNovaPrimeV60","FeralNovaPrimeV50","FeralAuroraNovaV40","FeralAuroraForceV31",
    "FeralAuroraHubV30","FeralAuroraHubV21","FeralAuroraHubV20",
    "FeralRecoveryHubV10","FeralRecoveryHubV11","FeralRecoveryHubV12",
    "FeralRecoveryHubV13","FeralFieldHubV10","FeralFieldHubV11",
    "FeralFieldHubV12","FeralFieldHubV13","FeralFieldHubV14"
}) do
    local old=pg:FindFirstChild(name)
    if old then
        local stop=old:FindFirstChild("AuroraShutdown")
            or old:FindFirstChild("HubShutdown")
        if stop and stop:IsA("BindableEvent") then
            pcall(function()stop:Fire()end)
        end
        if old.Parent then pcall(function()old:Destroy()end)end
    end
end

-- BUNDLED MODULE SNAPSHOT: a single, consistent source set.
-- This file does not fetch dependencies after the initial launcher URL.
local BUNDLED={
["feral-aurora-engine-v2.1.lua"]=[==========[
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

]==========],
["feral-aurora-power-v3.1.lua"]=[==========[
-- FERAL AURORA FORCE v3.1
-- Concrete own-client power profiles based on recovered controller fields.
-- All experimental features OFF by default. Server authority is NOT bypassed.
local Power={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function number(v)
    return type(v)=="number" and v==v and v>-math.huge and v<math.huge
end
local function loaded(name)
    local world=RS:FindFirstChild("FeralWorld")
    local mod=world and world:FindFirstChild(name)
    if not mod or not mod:IsA("ModuleScript") then
        return nil,"Module "..name.." not available"
    end
    local ok,result=pcall(require,mod)
    if not ok or type(result)~="table" then
        return nil,"Client module "..name.." not readable"
    end
    return result,nil
end
local function revert(lease)
    local reverted=0;local failed=0
    if not lease then return 0,0 end
    for i=#lease.entries,1,-1 do
        local entry=lease.entries[i]
        local ok=pcall(function()
            if lease.target[entry.key]==entry.wanted then
                lease.target[entry.key]=entry.previous
                reverted=reverted+1
            end
        end)
        if not ok then failed=failed+1 end
    end
    return reverted,failed
end
local function apply(tableValue,changes)
    if type(tableValue)~="table" then return nil,"No usable client config" end
    local lease={target=tableValue,entries={}}
    for key,wanted in pairs(changes) do
        if not number(wanted) then return nil,"Invalid number for "..key end
        local ok,previous=pcall(function()return tableValue[key]end)
        if not ok or not number(previous) then
            revert(lease);return nil,"Missing numeric field "..key
        end
        if previous~=wanted then
            local success=pcall(function()
                tableValue[key]=wanted
                assert(tableValue[key]==wanted)
            end)
            if not success then
                revert(lease);return nil,"Client config rejected "..key
            end
            lease.entries[#lease.entries+1]={
                key=key,previous=previous,wanted=wanted
            }
        end
    end
    return lease
end
function Power.attach(ctx)
    local S=ctx.state
    local P={
        alive=true,stamina="OFF",speed=1,leap=1,
        staminaLease=nil,speedLease=nil,
        leapConfig=nil,leapSpecies=nil,
        noDrain=false,turbo=false,
        lastAction="No power changes enabled.",lastError=nil,
        charFlags={},lastFlagChar=nil,heartbeat=nil,
        turboSupported=false,turboSignal="Executor keypress/keyrelease unavailable.",
        turboHeld=false,turboLast=0,
        lastRecheck=0,createdAt=os.clock(),
        lastChar=nil,appliedProfiles=0,restored=0,
        lastStaminaRate=nil,rateSamples=0,
        fallbackInfo="No status data sampled yet."
    }
    ctx.power=P
    local environment=nil
    if type(getgenv)=="function" then
        local ok,result=pcall(getgenv)
        if ok and type(result)=="table" then environment=result end
    end
    local press=type(keypress)=="function" and keypress
        or environment and type(environment.keypress)=="function"
        and environment.keypress or nil
    local release=type(keyrelease)=="function" and keyrelease
        or environment and type(environment.keyrelease)=="function"
        and environment.keyrelease or nil
    if press and release then
        P.turboSupported=true
        P.turboSignal="Executor key events available; native game handling still unverified."
    else
        -- Some executor environments permit VirtualInputManager instead.
        -- Its protected SendKeyEvent method may still be rejected at runtime.
        local ok,vim=pcall(function()
            return game:GetService("VirtualInputManager")
        end)
        if ok and vim then
            press=function()
                vim:SendKeyEvent(true,Enum.KeyCode.Space,false,game)
            end
            release=function()
                vim:SendKeyEvent(false,Enum.KeyCode.Space,false,game)
            end
            P.turboSupported=true
            P.turboSignal="VirtualInputManager fallback armed; input permissions unverified."
        end
    end
    local function log(info)
        P.lastAction=tostring(info)
        ctx.notice(info)
    end
    local function ownCharacter()
        local char=player.Character
        if not char or not char.Parent then return nil end
        return char
    end
    local function revertFlag(char)
        local old=P.charFlags[char]
        P.charFlags[char]=nil
        if not old or not char then return end
        pcall(function()
            if old.changed and char:GetAttribute("WolfDbgNoStamina")==true then
                char:SetAttribute("WolfDbgNoStamina",old.value)
            end
        end)
    end
    local function flagCharacter(char)
        if not char or not char.Parent or P.charFlags[char] then return end
        local value=char:GetAttribute("WolfDbgNoStamina")
        local ok=pcall(function()
            if value~=true then char:SetAttribute("WolfDbgNoStamina",true)end
        end)
        if ok then
            P.charFlags[char]={value=value,changed=value~=true}
        else
            P.lastError="Own-character debug stamina flag could not be set."
        end
    end
    local function maintainFlag()
        local on=P.noDrain or P.stamina=="APEX"
        local char=ownCharacter()
        for c in pairs(P.charFlags) do
            if not on or c~=char then revertFlag(c)end
        end
        if on and char then flagCharacter(char)end
        P.lastFlagChar=char
    end
    function P.disableStamina(silent)
        revert(P.staminaLease);P.staminaLease=nil
        P.stamina="OFF";maintainFlag()
        if not silent then log("Stamina profile OFF • cached settings restored where still owned.")end
    end
    local function staminaPlan(mode,c)
        if not number(c.STAMINA_REGEN) or c.STAMINA_REGEN<=0
            or not number(c.STAMINA_REST_MULT)
            or not number(c.STAMINA_REGEN_DELAY)
            or not number(c.STAMINA_LOW_NEEDS) then
            return nil,"Client stamina config is missing expected values."
        end
        if mode=="RECOVER" then
            return {
                STAMINA_REGEN=c.STAMINA_REGEN*3,
                STAMINA_REST_MULT=1,
                STAMINA_REGEN_DELAY=0,
                STAMINA_LOW_NEEDS=1
            }
        elseif mode=="APEX" then
            if not number(c.STAMINA_SPRINT_DRAIN)
                or not number(c.STAMINA_JUMP_COST) then
                return nil,"Apex sprint/jump controller fields not found."
            end
            return {
                STAMINA_SPRINT_DRAIN=0,STAMINA_JUMP_COST=0,
                STAMINA_REGEN=250,STAMINA_REGEN_DELAY=0,
                STAMINA_LOW_NEEDS=1
            }
        end
        return nil,"Unknown power profile"
    end
    function P.setStamina(mode)
        if mode~="RECOVER" and mode~="APEX" and mode~="OFF" then return end
        if mode==P.stamina then return end
        P.disableStamina(true)
        if mode=="OFF" then log("Stamina config restored.");return end
        -- The standalone low-needs switch patches the SAME cached field.
        -- Release its lease first so both controls can be switched off cleanly.
        if S.flags.lowNeedsAssist then
            ctx.toggle("lowNeedsAssist",false)
        end
        local config,err=loaded("NeedsConfig")
        if not config then
            P.lastError=err;log("Unavailable: "..err);return
        end
        local plan,reason=staminaPlan(mode,config)
        if not plan then
            P.lastError=reason;log("Unavailable: "..reason);return
        end
        local lease,why=apply(config,plan)
        if not lease then
            P.lastError=why;log("Not applied: "..why);return
        end
        P.staminaLease=lease;P.stamina=mode;P.appliedProfiles+=1
        maintainFlag()
        if mode=="RECOVER" then
            log("RECOVER applied to client controller: 3× recovery, zero delay; server outcome unknown.")
        else
            log("APEX CLIENT MODE applied: high-risk local stamina tuning. Prior prolonged Burst deaths remain unexplained.")
        end
    end
    function P.toggleNoDrain()
        P.noDrain=not P.noDrain
        maintainFlag()
        local state=P.noDrain and
            "Standalone client no-stamina-cost flag ON (not a server guarantee)." or
            P.stamina=="APEX" and
            "Standalone flag OFF; Apex profile still owns WolfDbgNoStamina." or
            "Standalone client no-drain flag OFF; original attribute restored."
        log(state)
    end
    function P.setSpeed(multiplier)
        if multiplier~=1 and multiplier~=1.15
            and multiplier~=1.30 and multiplier~=1.50 then return end
        if multiplier==P.speed then return end
        revert(P.speedLease);P.speedLease=nil;P.speed=1
        if multiplier==1 then log("Speed profile restored.");return end
        local c,why=loaded("NeedsConfig")
        if not c then log("Speed unavailable: "..why);return end
        if not number(c.RUN_SPEED) or not number(c.SWIM_SPEED)
            or c.RUN_SPEED<=0 or c.RUN_SPEED>4
            or c.SWIM_SPEED<=0 or c.SWIM_SPEED>4 then
            log("Speed profile unavailable: expected cached inputs not present.")
            return
        end
        local lease,err=apply(c,{
            RUN_SPEED=c.RUN_SPEED*multiplier,SWIM_SPEED=c.SWIM_SPEED*multiplier
        })
        if not lease then log("Speed not applied: "..err);return end
        P.speedLease=lease;P.speed=multiplier;P.appliedProfiles+=1
        log(string.format("%.2f× land/swim inputs applied locally; server checks remain independent.",multiplier))
    end
    function P.setLeap(multiplier)
        if multiplier~=1 and multiplier~=1.15 and multiplier~=1.35 then return end
        if multiplier==P.leap then return end
        revert(P.leapSpecies);revert(P.leapConfig)
        P.leapSpecies=nil;P.leapConfig=nil;P.leap=1
        if multiplier==1 then log("Leap profile restored.");return end
        local c,why=loaded("JumpLeapConfig")
        if not c or c.ON~=true or type(c.BODY_LENGTHS)~="table"
            or not number(c.DEFAULT) or not number(c.MAX_RUN_SHARE) then
            log("Leap unavailable: original cached module not usable.");return
        end
        local species={}
        for name,value in pairs(c.BODY_LENGTHS) do
            if type(name)=="string" and number(value) and value>=0 and value<=10 then
                species[name]=value*multiplier
            end
        end
        if not next(species) then log("Leap source has no usable species entries.");return end
        local one,firstErr=apply(c,{
            DEFAULT=c.DEFAULT*multiplier,
            MAX_RUN_SHARE=c.MAX_RUN_SHARE*multiplier
        })
        if not one then log("Leap unavailable: "..firstErr);return end
        local two,secondErr=apply(c.BODY_LENGTHS,species)
        if not two then
            revert(one);log("Leap species table unavailable: "..secondErr);return
        end
        P.leapConfig=one;P.leapSpecies=two;P.leap=multiplier
        P.appliedProfiles+=1
        log(string.format("%.2f× leap inputs locally applied (not flight or a server grant).",multiplier))
    end
    local function releaseSpace()
        if P.turboHeld and release then pcall(release,0x20)end
        P.turboHeld=false
    end
    function P.toggleTurbo()
        if not P.turboSupported then
            log("Rapid Escape unavailable: this executor does not expose keypress/keyrelease.")
            return
        end
        P.turbo=not P.turbo
        if not P.turbo then releaseSpace()end
        log(P.turbo and "Rapid Escape ARMED: hold ALT to pulse Space, chat input excluded."
            or "Rapid Escape OFF: key events stopped.")
    end
    local function turboTick(now)
        if not P.turbo or not P.turboSupported then return end
        if UIS:GetFocusedTextBox() then
            releaseSpace();return
        end
        if not (UIS:IsKeyDown(Enum.KeyCode.LeftAlt)
            or UIS:IsKeyDown(Enum.KeyCode.RightAlt)) then
            releaseSpace();return
        end
        if now-P.turboLast<.17 then return end
        P.turboLast=now
        if not P.turboHeld then
            local ok=pcall(press,0x20)
            if ok then
                P.turboHeld=true
                task.delay(.06,function()
                    if not P.alive then releaseSpace();return end
                    releaseSpace()
                end)
            else
                P.turbo=false;P.lastError="Executor keypress failed"
                log("Rapid Escape stopped: key input was rejected by executor.")
            end
        end
    end
    function P.reset()
        P.disableStamina(true)
        P.noDrain=false;maintainFlag()
        P.setSpeed(1);P.setLeap(1)
        P.turbo=false;releaseSpace()
        P.lastAction="All power profiles OFF; original client inputs restored where still owned."
        ctx.notice(P.lastAction)
    end
    function P.status()
        local a=ctx.stats()
        local valid=function(lease)
            if not lease then return false end
            local ok,match=pcall(function()
                for _,entry in ipairs(lease.entries) do
                    if lease.target[entry.key]~=entry.wanted then return false end
                end
                return true
            end)
            return ok and match
        end
        local char=ownCharacter()
        local flag=char and char:GetAttribute("WolfDbgNoStamina")==true or false
        local danger=P.stamina=="APEX" and "AGGRESSIVE / HIGH RISK" or
            P.stamina=="RECOVER" and "RECOVERY / EXPERIMENTAL" or "STOCK"
        return {
            stamina=P.stamina,
            staminaMatches=valid(P.staminaLease),
            speed=P.speed,speedMatches=valid(P.speedLease),
            leap=P.leap,leapMatches=valid(P.leapConfig) and valid(P.leapSpecies),
            noDrain=P.noDrain,turbo=P.turbo,turboSupported=P.turboSupported,
            flag=flag,mode=danger,phase=a.sessionPhase,
            hp=a.hp,staminaValue=a.stamina,maxStamina=a.maxStamina,
            healthMax=a.maxHp,hunger=a.hunger,thirst=a.thirst,
            last=P.lastAction,error=P.lastError,
            appliedProfiles=P.appliedProfiles
        }
    end
    P.connection=RunService.Heartbeat:Connect(function()
        if not P.alive or not S.alive then return end
        local now=os.clock()
        turboTick(now)
        if now-P.lastRecheck>=.75 then
            P.lastRecheck=now
            local char=ownCharacter()
            if char~=P.lastChar then
                P.lastChar=char
                maintainFlag()
            end
        end
    end)
    local priorReset=ctx.reset
    function ctx.reset()
        P.reset()
        priorReset()
    end
    local priorClose=ctx.close
    function ctx.close()
        if P.alive then
            P.reset()
            P.alive=false
            if P.connection then P.connection:Disconnect()end
            releaseSpace()
        end
        priorClose()
    end
    return P
end
return Power

]==========],
["feral-nova-escape-v9.0.lua"]=[==========[
-- FERAL NOVA PRIME v9 / context-aware escape controller.
-- Captured FeralLungeUI: TUG_MIN_GAP=.10, SHAKE_MIN_GAP=.15,
-- SHAKE_MASH=false (directional FeralShakeTaps), getoff gap=.40.
-- Only sends native actions while its OWN character reports a grab
-- or the native grab control is actually bound. Server acceptance unknown.
local Escape={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local CAS=game:GetService("ContextActionService")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer

local function num(v)
    return type(v)=="number" and v==v and v>=0 and v<1e8
end
local function on(obj,key)
    return obj and obj:GetAttribute(key)==true
end
local function positive(obj,key)
    local a=obj and obj:GetAttribute(key)
    return num(a) and a>0
end

function Escape.choose(carry,pinned,clamp,need,bindings)
    bindings=bindings or {}
    if carry then return "getoff","CARRIED",.415 end
    -- The captured game has SHAKE_MASH=false. In that mode
    -- FeralShakeTaps is the actual A/D escape binding.
    local shakeBinding=bindings.FeralShakeTaps or bindings.FeralShakeMash
    local tugBinding=bindings.FeralTugTap
    if (clamp or need or pinned) and tugBinding then
        return "shake","TUG PREY",.112
    end
    if (clamp or need or pinned) and shakeBinding then
        return "shake","DIRECTIONAL SHAKE",.163
    end
    if pinned and (clamp or need) then
        return "shake","PINNED CLAMP STATE",.165
    end
    if clamp and need then
        return "shake","CLAMP PROGRESS",.165
    end
    -- The pinned cue alone is not proof that a shake request is allowed;
    -- don't send arbitrary game traffic without a native escape binding.
    return nil,"UNCLASSIFIED PIN",nil
end

function Escape.attach(ctx)
    local E={
        alive=true,enabled=true,status="WATCHING",
        trigger="",mode="NONE",input="NO INJECTION",
        nativeCount=0,pulses=0,detections=0,
        attempts={getoff=0,shake=0},
        progress=0,releaseEvents=0,
        cases=0,activeSince=0,longest=0,
        lastShakeHave=nil,lastClamp=nil,
        noProgressWarnings=0,lastError="",
        lastCharacter=nil,bindings={},
        nextBindings=0,nextScan=0,nextAction=0,
        nextKey=0,down=false,token=0,active=false,
        fallbackUntil=0,fallbackReason="",
        lastAction="",nextReport=0,
        pendingFeedback=false
    }
    local env
    if type(getgenv)=="function" then
        local ok,result=pcall(getgenv)
        if ok and type(result)=="table" then env=result end
    end
    local kp=(type(keypress)=="function" and keypress)
        or (env and type(env.keypress)=="function" and env.keypress)
    local kr=(type(keyrelease)=="function" and keyrelease)
        or (env and type(env.keyrelease)=="function" and env.keyrelease)
    local press,release
    if type(kp)=="function" and type(kr)=="function" then
        press=function()kp(0x20)end
        release=function()kr(0x20)end
        E.input="EXECUTOR"
    else
        local ok,vim=pcall(function()return game:GetService("VirtualInputManager")end)
        if ok and vim then
            press=function()vim:SendKeyEvent(true,Enum.KeyCode.Space,false,game)end
            release=function()vim:SendKeyEvent(false,Enum.KeyCode.Space,false,game)end
            E.input="VIRTUAL INPUT"
        end
    end
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local charConnections={}
    local forceRead=false
    local function drop()
        if E.down then
            E.down=false;E.token+=1
            if release then pcall(release)end
        end
    end
    local function resetEpisode()
        if E.active then
            E.longest=math.max(E.longest,os.clock()-E.activeSince)
        end
        E.active=false
        E.mode="NONE"
        E.pendingFeedback=false
        E.lastShakeHave=nil
        E.lastClamp=nil
        drop()
    end
    local function connectChar(char)
        for _,c in ipairs(charConnections) do pcall(function()c:Disconnect()end)end
        table.clear(charConnections)
        resetEpisode()
        E.lastCharacter=char
        E.nextAction=0
        E.nextBindings=0
        forceRead=true
        if char then
            for _,key in ipairs({"FeralCarried","FeralPinned","FeralClampN",
                "FeralClampGame","FeralShakeHave","FeralShakeNeed",
                "FeralDowned"}) do
                local ok,c=pcall(function()
                    return char:GetAttributeChangedSignal(key):Connect(function()
                        forceRead=true
                        E.nextBindings=0
                    end)
                end)
                if ok then charConnections[#charConnections+1]=c end
            end
        end
    end
    connectChar(player.Character)
    E.charConnection=player.CharacterAdded:Connect(connectChar)

    local function updateBindings(now)
        if now<E.nextBindings and not forceRead then return end
        E.nextBindings=now+.12
        forceRead=false
        local ok,value=pcall(function()return CAS:GetAllBoundActionInfo()end)
        if ok and type(value)=="table" then
            E.bindings={
                FeralCarryEscape=value.FeralCarryEscape~=nil,
                FeralShakeTaps=value.FeralShakeTaps~=nil,
                FeralShakeMash=value.FeralShakeMash~=nil,
                FeralTugTap=value.FeralTugTap~=nil
            }
        end
    end

    local function fallback(char,now)
        if now<E.nextScan then return end
        E.nextScan=now+.40
        if on(char,"FeralPinned") then
            E.fallbackUntil=now+.46
            E.fallbackReason="PINNED"
            return
        end
        if not pg then return end
        local checked=0
        for _,node in ipairs(pg:GetDescendants()) do
            checked+=1
            if checked>420 then break end
            if node:IsA("TextLabel") and node.Visible
                and (not ctx.ui or not node:IsDescendantOf(ctx.ui)) then
                local s=string.upper(node.Text or "")
                if (string.find(s,"ESCAPE",1,true)
                    or string.find(s,"SHAKE",1,true))
                    and string.find(s,"SPACE",1,true) then
                    E.fallbackUntil=now+.45
                    E.fallbackReason="ESCAPE PROMPT"
                    return
                end
            end
        end
    end

    local function pulse(now)
        if not press then E.status="KEYBOARD UNAVAILABLE";return end
        if E.down or now<E.nextKey then return end
        E.nextKey=now+.16
        local ok,err=pcall(press)
        if not ok then E.lastError=tostring(err);E.status="SPACE BLOCKED";return end
        E.down=true;E.pulses+=1
        E.status="SPACE FALLBACK (UNVERIFIED)"
        E.token+=1
        local token=E.token
        task.delay(.045,function()
            if E.alive and E.token==token then drop()end
        end)
    end

    local function observeProgress(char)
        local have=char:GetAttribute("FeralShakeHave")
        if num(have) then
            if E.lastShakeHave and have>E.lastShakeHave+.01 then
                E.progress+=1
                E.pendingFeedback=false
            end
            E.lastShakeHave=have
        end
        local clamp=char:GetAttribute("FeralClampN")
        if not num(clamp) then clamp=char:GetAttribute("FeralClampGame")end
        if num(clamp) then
            if E.lastClamp and clamp<E.lastClamp-.01 then
                E.progress+=1
                E.pendingFeedback=false
            end
            E.lastClamp=clamp
        end
    end

    local function tick()
        if not E.alive or not ctx.state.alive or not E.enabled then return end
        local now=os.clock()
        if UIS:GetFocusedTextBox() then
            drop()
            E.status="PAUSED FOR CHAT"
            return
        end
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if char~=E.lastCharacter then connectChar(char)end
        if not char or not char.Parent or not hum or hum.Health<=0
            or on(player,"FeralMenuOpen") then
            resetEpisode()
            E.status="WAITING FOR ANIMAL"
            return
        end
        updateBindings(now)
        local carried=on(char,"FeralCarried")
        local pinned=on(char,"FeralPinned")
        local clamp=positive(char,"FeralClampN") or positive(char,"FeralClampGame")
        local need=positive(char,"FeralShakeNeed")
        local hasCue=carried or pinned or clamp or need
        local mode,reason,interval=Escape.choose(carried,pinned,clamp,need,E.bindings)
        if not hasCue then
            if E.active then
                E.releaseEvents+=1
                resetEpisode()
            end
            E.status="WATCHING"
            return
        end
        if not E.active then
            E.active=true
            E.activeSince=now
            E.cases+=1
            E.detections+=1
            E.nextAction=0
            E.lastShakeHave=nil
            E.lastClamp=nil
        end
        E.trigger=reason or "grab cue"
        observeProgress(char)
        local spent=now-E.activeSince
        E.longest=math.max(E.longest,spent)
        if mode then
            E.mode=mode
            E.status="ESCAPING / "..reason
            drop()
            if now<E.nextAction then return end
            E.nextAction=now+interval
            local remote=RS:FindFirstChild("FeralLunge")
            if not remote or not remote:IsA("RemoteEvent") then
                E.status="ESCAPE REMOTE MISSING"
                E.lastError="FeralLunge RemoteEvent unavailable"
                return
            end
            local ok,err=pcall(function()remote:FireServer(mode)end)
            if ok then
                E.nativeCount+=1
                E.attempts[mode]+=1
                E.lastAction=mode
                if spent>2.5 and E.progress==0 and E.noProgressWarnings<1 then
                    E.noProgressWarnings+=1
                    E.status="NO OBSERVED ESCAPE PROGRESS"
                end
            else
                E.lastError=tostring(err)
                E.status="NATIVE INPUT ERROR"
            end
        else
            E.mode="FALLBACK"
            fallback(char,now)
            if now<E.fallbackUntil then
                pulse(now)
            else
                E.status="GRABBED / NO CONFIRMED ACTION"
            end
        end
    end

    function E.setEnabled(v)
        E.enabled=v==true
        if E.enabled then
            E.status="WATCHING"
            E.nextBindings=0
            E.nextAction=0
        else
            resetEpisode()
            E.status="OFF"
        end
    end
    function E.report()
        return table.concat({
            "FERAL NOVA PRIME v9 | Escape",
            "status="..E.status.." enabled="..tostring(E.enabled),
            "last_cue="..E.trigger,
            "last_action="..E.lastAction.." mode="..E.mode,
            "getoff_requests="..tostring(E.attempts.getoff),
            "shake_requests="..tostring(E.attempts.shake),
            "space_fallback_pulses="..tostring(E.pulses),
            "grab_episodes="..tostring(E.cases),
            "observed_releases="..tostring(E.releaseEvents),
            "shake_progress_changes="..tostring(E.progress),
            "longest_grab_seconds="..string.format("%.2f",E.longest),
            "binding_taps="..tostring(E.bindings.FeralShakeTaps),
            "binding_tug="..tostring(E.bindings.FeralTugTap),
            "binding_mash="..tostring(E.bindings.FeralShakeMash),
            "input="..E.input,
            "last_error="..E.lastError,
            "NOTE=Native requests and observed release do not prove which action caused release."
        },"\n")
    end
    function E.close()
        E.alive=false
        E.setEnabled(false)
        if E.connection then E.connection:Disconnect()end
        if E.charConnection then E.charConnection:Disconnect()end
        for _,c in ipairs(charConnections) do pcall(function()c:Disconnect()end)end
        table.clear(charConnections)
    end
    E.connection=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            E.lastError=tostring(err)
            E.status="ESCAPE ERROR"
            drop()
        end
    end)
    return E
end
return Escape

]==========],
["feral-nova-combat-v10.0.lua"]=[==========[
-- FERAL NOVA PRIME v10 / nonphysical Bite Guide + collision diagnostics.
-- Mirrors recovered WolfController biteClaimTarget geometry for a
-- target-in-cone hint. It never edits enemy parts or emits BiteHit.
local Combat={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer

local function finite(n)
    return type(n)=="number" and n==n and math.abs(n)<1e8
end
local function config()
    local folder=RS:FindFirstChild("FeralWorld")
    local mod=folder and folder:FindFirstChild("CombatConfig")
    if not mod or not mod:IsA("ModuleScript") then return nil end
    local ok,t=pcall(require,mod)
    if not ok or type(t)~="table" or type(t.bodyGap)~="function"
        or not finite(t.REACH) or not finite(t.CONE)
        or not finite(t.HIT_SCALE) or not finite(t.SLACK)
        or not finite(t.MAX_DY) then return nil end
    return t
end
function Combat.attach(ctx)
    local C={
        alive=true,enabled=true,status="WAITING FOR ANIMAL",
        target=nil,targetDistance=nil,margin=0,ready=false,
        bites=0,blockedRestInputs=0,monitored=0,observedHPDrops=0,
        sample=0,nextScan=0,lastBite=-math.huge,lastError="",
        window=nil,configStatus="NOT READ",mode="DISPLAY ONLY",
        playerCandidates=0,npcCandidates=0,
        closeRootDistance=nil,closeRootSize="NONE",
        closeRootCanCollide="--",closeRootGroup="--",
        ownRootSize="--",physicalEdits=0,
        oldHitboxGuiVisible=false,
        lastBlockerCheck=0,rayBlockCategory="NOT CHECKED",
        rayBlockCollidable="--"
    }
    local gui=Instance.new("ScreenGui")
    gui.Name="FeralNovaBiteGuideV10"
    gui.IgnoreGuiInset=true
    gui.DisplayOrder=203
    gui.ResetOnSpawn=false
    gui.Parent=player:FindFirstChildOfClass("PlayerGui")
        or player:WaitForChild("PlayerGui",8)
    local circle=Instance.new("Frame")
    circle.Name="TargetPoint"
    circle.AnchorPoint=Vector2.new(.5,.5)
    circle.Size=UDim2.fromOffset(12,12)
    circle.BackgroundColor3=Color3.fromRGB(110,244,219)
    circle.BackgroundTransparency=.38
    circle.BorderSizePixel=0
    circle.Visible=false
    circle.Parent=gui
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(1,0);c.Parent=circle
    local stroke=Instance.new("UIStroke")
    stroke.Color=Color3.fromRGB(10,34,40)
    stroke.Thickness=2;stroke.Parent=circle

    local conns={}
    local biteConnection
    local function own()
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if not char or not hum or not root or hum.Health<=0 then
            return nil,nil,nil
        end
        return char,hum,root
    end
    local function candidate(char,hum,root)
        local cfg=config()
        if not cfg then
            C.configStatus="NATIVE COMBAT CONFIG MISSING"
            return nil
        end
        C.configStatus="READABLE; CLIENT MODEL ONLY"
        local forward=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
        if forward.Magnitude<.01 then return nil end
        forward=forward.Unit
        local reach=(root.Size.Z*.5+hum.HipHeight*cfg.REACH+cfg.SLACK)
            *cfg.HIT_SCALE
        local maxAngle=math.cos(math.rad(cfg.CONE))
        local ownPos=root.Position
        local best,score
        local ownPack=player:GetAttribute("FeralPack")
        local function consider(model)
            if model==char or not model or not model.Parent
                or model:GetAttribute("FeralDead")==true then return end
            local eRoot=model:FindFirstChild("HumanoidRootPart")
            local eHum=model:FindFirstChildOfClass("Humanoid")
            if not eRoot or not eHum or eHum.Health<=0 then return end
            local enemyPack=model:GetAttribute("FeralPack")
            if ownPack~=nil and enemyPack~=nil and ownPack==enemyPack then return end
            local difference=eRoot.Position-ownPos
            local flat=Vector3.new(difference.X,0,difference.Z)
            local dist=flat.Magnitude
            if dist>45 then return end
            local angle=dist>.05 and forward:Dot(flat.Unit) or 1
            local ok,gap=pcall(cfg.bodyGap,eRoot,flat)
            if not ok or not finite(gap) then return end
            local vertical=math.abs(difference.Y)
            local maxVertical=(hum.HipHeight+eHum.HipHeight)*cfg.MAX_DY
            local valid=gap<reach and angle>maxAngle and vertical<maxVertical
            local s=gap-angle*2
            if valid and (not best or not best.valid or s<score) then
                score=s
                best={model=model,root=eRoot,hum=eHum,
                    dist=dist,margin=reach-gap,gap=gap,valid=true}
            elseif not best and (not score or s<score) then
                score=s
                best={model=model,root=eRoot,hum=eHum,
                    dist=dist,margin=reach-gap,gap=gap,valid=false}
            end
        end
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player and other.Character then
                C.playerCandidates+=1
                consider(other.Character)
            end
        end
        local npc=workspace:FindFirstChild("FeralNPCs")
        if npc then
            local n=0
            for _,model in ipairs(npc:GetChildren()) do
                n+=1
                if n>75 then break end
                if model:IsA("Model") then
                    C.npcCandidates+=1
                    consider(model)
                end
            end
        end
        return best
    end
    local function collisionAudit(root)
        -- Never writes part.Size, CanCollide or collision groups.
        -- This is only for identifying possible leftover v7/v8 changes.
        C.closeRootDistance=nil
        C.closeRootSize="NONE"
        C.closeRootCanCollide="--"
        C.closeRootGroup="--"
        C.ownRootSize=string.format("%.2f/%.2f/%.2f",
            root.Size.X,root.Size.Y,root.Size.Z)
        local pg=player:FindFirstChildOfClass("PlayerGui")
        C.oldHitboxGuiVisible=pg and
            (pg:FindFirstChild("FeralNovaPrimeV70")~=nil
              or pg:FindFirstChild("FeralNovaPrimeV80")~=nil)
            or false
        local nearestRoot,nearestModel
        local function inspect(char)
            if not char or char==player.Character then return end
            local other=char:FindFirstChild("HumanoidRootPart")
            if other and other:IsA("BasePart") and other.Parent then
                local d=(root.Position-other.Position).Magnitude
                if d<30 and (not C.closeRootDistance or d<C.closeRootDistance) then
                    C.closeRootDistance=d
                    C.closeRootSize=string.format("%.2f/%.2f/%.2f",
                        other.Size.X,other.Size.Y,other.Size.Z)
                    C.closeRootCanCollide=tostring(other.CanCollide)
                    C.closeRootGroup=tostring(other.CollisionGroup)
                    nearestRoot=other
                    nearestModel=char
                end
            end
        end
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player then inspect(other.Character)end
        end
        local npcs=workspace:FindFirstChild("FeralNPCs")
        if npcs then
            local i=0
            for _,obj in ipairs(npcs:GetChildren()) do
                i+=1
                if i>65 then break end
                if obj:IsA("Model") then inspect(obj)end
            end
        end
        local now=os.clock()
        if now-C.lastBlockerCheck>=.9 then
            C.lastBlockerCheck=now
            C.rayBlockCategory="NO NEARBY ANIMAL"
            C.rayBlockCollidable="--"
            if nearestRoot then
                -- Pure read: one ray per 0.9 seconds. Categorise the
                -- collidable obstruction but never export player/part names.
                local ok,category,collidable=pcall(function()
                    local params=RaycastParams.new()
                    params.FilterType=Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances={player.Character}
                    local dir=nearestRoot.Position-root.Position
                    local result=workspace:Raycast(root.Position,dir,params)
                    if not result or not result.Instance then
                        return "NO RAY CONTACT","--"
                    end
                    local part=result.Instance
                    local kind=nearestModel and part:IsDescendantOf(nearestModel)
                        and "TARGET" or "WORLD / OTHER"
                    return kind,tostring(part.CanCollide)
                end)
                C.rayBlockCategory=ok and category or "RAYCAST UNAVAILABLE"
                C.rayBlockCollidable=ok and collidable or "--"
            end
        end
    end

    local function bite()
        local now=os.clock()
        if now-C.lastBite<.075 then return end
        C.lastBite=now
        C.bites+=1
        if C.target and C.target.hum then
            C.window={
                hum=C.target.hum,
                before=C.target.hum.Health,
                untilAt=now+1.0
            }
            C.monitored+=1
        end
    end
    local function charChanged(char)
        if biteConnection then biteConnection:Disconnect();biteConnection=nil end
        C.window=nil
        if char then
            biteConnection=char:GetAttributeChangedSignal("WolfBiteAt"):Connect(bite)
        end
    end
    conns[#conns+1]=player.CharacterAdded:Connect(charChanged)
    charChanged(player.Character)
    conns[#conns+1]=UIS.InputBegan:Connect(function(input,processed)
        if processed then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            local char=player.Character
            if char and char:GetAttribute("WolfRest")==true then
                C.blockedRestInputs+=1
            end
        end
    end)

    local function tick()
        if not C.alive or not ctx.state.alive then return end
        local now=os.clock()
        if C.window then
            local w=C.window
            if w.hum and w.hum.Parent and finite(w.hum.Health)
                and w.hum.Health<w.before-.05 then
                C.observedHPDrops+=1
                C.window=nil
            elseif now>w.untilAt then C.window=nil end
        end
        if now<C.nextScan then return end
        C.nextScan=now+.14
        local char,hum,root=own()
        circle.Visible=false
        C.target=nil
        C.ready=false
        C.targetDistance=nil
        C.playerCandidates=0
        C.npcCandidates=0
        if not char then C.status="NO ACTIVE ANIMAL";return end
        collisionAudit(root)
        if char:GetAttribute("WolfRest")==true then
            C.status="REST ACTIVE / BITE BLOCKED"
            return
        end
        if not C.enabled then
            C.status="GUIDE OFF"
            return
        end
        local best=candidate(char,hum,root)
        C.target=best
        if not best then
            C.status="NO TARGET IN REPLICATED RANGE"
            return
        end
        C.targetDistance=best.dist
        C.margin=best.margin
        C.ready=best.valid
        C.status=best.valid and "BITE WINDOW OPEN (CLIENT)"
            or "MOVE CLOSER / FACE TARGET"
        if not best.valid then return end
        local camera=workspace.CurrentCamera
        if not camera then return end
        local point,shown=camera:WorldToViewportPoint(best.root.Position+
            Vector3.new(0,math.max(0,best.root.Size.Y*.55),0))
        if shown and point.Z>0 then
            circle.Position=UDim2.fromOffset(point.X,point.Y)
            circle.Visible=true
        end
    end
    function C.setEnabled(v)
        C.enabled=v==true
        if not C.enabled then circle.Visible=false end
    end
    function C.report()
        return table.concat({
            "FERAL NOVA PRIME v9 | Combat Guide",
            "enabled="..tostring(C.enabled).." status="..C.status,
            "model="..C.configStatus,
            "candidate_players="..tostring(C.playerCandidates),
            "candidate_npcs="..tostring(C.npcCandidates),
            "client_bite_ready="..tostring(C.ready),
            "bites_started="..tostring(C.bites),
            "bite_observations="..tostring(C.monitored),
            "nearby_hp_drops_after_bites="..tostring(C.observedHPDrops),
            "attempted_attacks_while_resting="..tostring(C.blockedRestInputs),
            "nearest_root_distance="..tostring(C.closeRootDistance),
            "nearest_root_size_xyz="..C.closeRootSize,
            "nearest_root_can_collide="..C.closeRootCanCollide,
            "nearest_root_collision_group="..C.closeRootGroup,
            "own_root_size_xyz="..C.ownRootSize,
            "old_v7_v8_gui_present="..tostring(C.oldHitboxGuiVisible),
            "ray_obstruction_category="..C.rayBlockCategory,
            "ray_obstruction_collidable="..C.rayBlockCollidable,
            "physical_part_edits_by_v10="..tostring(C.physicalEdits),
            "NOTE=v10 never changes root part size/collision; lingering v7/v8 changes require a fresh join.",
            "NOTE=Bite guidance and HP correlations do not prove server damage."
        },"\n")
    end
    function C.close()
        C.alive=false
        if C.connection then C.connection:Disconnect()end
        if biteConnection then biteConnection:Disconnect()end
        for _,cn in ipairs(conns) do cn:Disconnect()end
        if gui then gui:Destroy()end
    end
    C.connection=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            C.lastError=tostring(err)
            C.status="GUIDE ERROR"
            circle.Visible=false
        end
    end)
    return C
end
return Combat

]==========],
["feral-nova-recovery-v10.0.lua"]=[==========[
-- FERAL NOVA PRIME v10 / real Rest eligibility and 2x HP, 4x status evidence.
-- Old v8 automatically entered Rest near enemies, preventing Bite.
-- v9 never enters Rest at startup and cancels its OWN Rest on combat input.
-- Actual healing and damage protection are decided by game server.
local Recovery={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function finite(n)
    return type(n)=="number" and n==n and n>=0 and n<1e9
end
function Recovery.shellState(species,rest,restAt,serverNow)
    if type(species)~="string" or not string.find(species,"SnappingTurtle",1,true)
        then return "NOT TURTLE",1 end
    if rest~=true then return "SHELL INACTIVE",1 end
    if not finite(restAt) or not finite(serverNow) then
        return "REST OBSERVED / TIMER UNAVAILABLE",1
    end
    if serverNow-restAt<1 then return "SHELL ARMING",1 end
    return "SHELL CONDITION MET / UNVERIFIED DAMAGE",.30
end

function Recovery.attach(ctx)
    local M={
        alive=true,enabled=false,status="PASSIVE MONITOR",
        shell="NOT TURTLE",multiplier=1,
        requests=0,cancels=0,replicatedRestTransitions=0,
        restingHeals=0,normalHeals=0,lastRate=0,
        movingShellSeen=false,attackInterrupts=0,
        healthRestGain=0,healthRestSeconds=0,
        healthNormalGain=0,healthNormalSeconds=0,
        healthRestTicks=0,healthNormalTicks=0,
        cachedHealthRegen=nil,cachedHealthRestMult=nil,
        cachedStatusRestMults="UNAVAILABLE",
        damageInterrupts=0,unsafeBlocks=0,
        restOwned=nil,restActive=false,
        lastChar=nil,lastHP=nil,lastMax=nil,
        lastMeasure=0,lastMeasureRest=nil,lastRest=false,lastInput=-math.huge,
        lastDamage=-math.huge,stillSince=0,
        nextRequest=0,nextTick=0,lastError="",
        pendingUntil=0,restAttempts=0,
        statusActive=false,
        statusValues={},
        statusSamples={},
        prevStatusAt=0,prevStatusRest=nil,
        restObservedSeconds=0,
        noRestObservedSeconds=0,
        reason="Enable Rest to request 2x HP / 4x status recovery when eligible"
    }
    local connections={}
    local world=RS:FindFirstChild("FeralWorld")
    local function readConfig(name)
        local mod=world and world:FindFirstChild(name)
        if not mod or not mod:IsA("ModuleScript") then return nil end
        local ok,v=pcall(require,mod)
        return ok and type(v)=="table" and v or nil
    end
    local needs=readConfig("NeedsConfig")
    local statusConfig=readConfig("StatusConfig")
    if needs then
        if finite(needs.HEALTH_REGEN) then M.cachedHealthRegen=needs.HEALTH_REGEN end
        if finite(needs.HEALTH_REST_MULT) then
            M.cachedHealthRestMult=needs.HEALTH_REST_MULT
        end
    end
    if statusConfig then
        local mult={}
        for _,key in ipairs({"INJURY","BLEED","VENOM"}) do
            local entry=statusConfig[key]
            mult[#mult+1]=key..":"..tostring(
                type(entry)=="table" and entry.REST_MULT or "unknown")
        end
        M.cachedStatusRestMults=table.concat(mult,",")
    end
    local statusKeys={
        {key="FeralInjury",name="injury",limit=.5},
        {key="FeralBleed",name="bleed",limit=.25},
        {key="FeralVenomAmt",name="venom",limit=.25}
    }
    for _,entry in ipairs(statusKeys) do
        M.statusSamples[entry.name]={
            restDelta=0,normalDelta=0,restSeconds=0,
            normalSeconds=0,restTicks=0,normalTicks=0,
            gainedTicks=0
        }
    end
    local function remote()
        local r=RS:FindFirstChild("WolfActions")
        return r and r:IsA("RemoteEvent") and r or nil
    end
    local function requestRest(char,flag)
        if not char or char~=player.Character then return false end
        local r=remote()
        if not r then M.lastError="WolfActions unavailable";return false end
        local ok,err=pcall(function()r:FireServer("Rest",flag)end)
        if not ok then M.lastError=tostring(err);return false end
        if flag then
            M.requests+=1
            M.restOwned=char
            M.pendingUntil=os.clock()+1.7
        else
            M.cancels+=1
        end
        return true
    end
    local function cancelOwned(reason)
        if M.restOwned then
            local char=M.restOwned
            M.restOwned=nil
            if char.Parent and char==player.Character then
                requestRest(char,false)
            end
        end
        M.pendingUntil=0
        if reason then M.reason=reason end
    end
    local function resetCharacter(char)
        cancelOwned("Animal changed")
        M.lastChar=char
        M.lastHP=nil
        M.lastMax=nil
        M.lastMeasure=0
        M.lastMeasureRest=nil
        M.lastRest=false
        M.stillSince=0
        M.nextRequest=0
        M.lastDamage=os.clock()
        M.prevStatusAt=0
        M.prevStatusRest=nil
        M.statusValues={}
        M.statusActive=false
    end
    -- Under a deliberate user-enabled Rest mode, use a more realistic
    -- nearby-threat threshold than v9's 62-stud hard block. Never Rest
    -- while combat, damaged very recently, moving or any player is inside
    -- 32 studs; enemy velocities and the server can still surprise us.
    local function dangerNearby(root)
        -- Only nearby replicated animals; streaming may omit others.
        local count=0
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player and other.Character then
                local e=other.Character:FindFirstChild("HumanoidRootPart")
                local h=other.Character:FindFirstChildOfClass("Humanoid")
                if e and h and h.Health>0 then
                    count+=1
                    if (root.Position-e.Position).Magnitude<32 then
                        return true,count
                    end
                end
            end
        end
        return false,count
    end
    local function combatInput()
        local now=os.clock()
        M.lastInput=now
        if M.restOwned then
            M.attackInterrupts+=1
            cancelOwned("Combat/movement input; released owned Rest")
            M.status="REST CANCELLED / ATTACK OR MOVE"
        end
    end
    connections[#connections+1]=UIS.InputBegan:Connect(function(input,processed)
        if processed or UIS:GetFocusedTextBox() then return end
        local t=input.UserInputType
        local k=input.KeyCode
        if t==Enum.UserInputType.MouseButton1
            or t==Enum.UserInputType.MouseButton2
            or k==Enum.KeyCode.W or k==Enum.KeyCode.A
            or k==Enum.KeyCode.S or k==Enum.KeyCode.D
            or k==Enum.KeyCode.Space then
            combatInput()
        end
    end)
    function M.setEnabled(v)
        M.enabled=v==true
        if not M.enabled then
            cancelOwned("Automatic rest OFF")
            M.status="PASSIVE MONITOR"
        else
            M.status="SAFE REST ARMED"
            M.nextTick=0
        end
    end
    function M.close()
        M.setEnabled(false)
        M.alive=false
        if M.connection then M.connection:Disconnect()end
        for _,c in ipairs(connections) do c:Disconnect()end
    end
    function M.report()
        return table.concat({
            "FERAL NOVA PRIME v9 | Safe Rest / Turtle Shell",
            "auto_rest_enabled="..tostring(M.enabled),
            "status="..M.status,
            "shell="..M.shell,
            "client_rule_multiplier="..tostring(M.multiplier),
            "native_rest_on_requests="..tostring(M.requests),
            "owned_rest_off_requests="..tostring(M.cancels),
            "rest_attribute_transitions="..tostring(M.replicatedRestTransitions),
            "healing_intervals_while_resting="..tostring(M.restingHeals),
            "healing_intervals_when_not_resting="..tostring(M.normalHeals),
            "status_condition_present="..tostring(M.statusActive),
            "injury_rest_rate="..string.format("%.3f",M.statusSamples.injury.restDelta/math.max(.01,M.statusSamples.injury.restSeconds)),
            "injury_normal_rate="..string.format("%.3f",M.statusSamples.injury.normalDelta/math.max(.01,M.statusSamples.injury.normalSeconds)),
            "bleed_rest_rate="..string.format("%.3f",M.statusSamples.bleed.restDelta/math.max(.01,M.statusSamples.bleed.restSeconds)),
            "bleed_normal_rate="..string.format("%.3f",M.statusSamples.bleed.normalDelta/math.max(.01,M.statusSamples.bleed.normalSeconds)),
            "venom_rest_rate="..string.format("%.3f",M.statusSamples.venom.restDelta/math.max(.01,M.statusSamples.venom.restSeconds)),
            "venom_normal_rate="..string.format("%.3f",M.statusSamples.venom.normalDelta/math.max(.01,M.statusSamples.venom.normalSeconds)),
            "cached_health_regen="..tostring(M.cachedHealthRegen),
            "cached_health_rest_multiplier="..tostring(M.cachedHealthRestMult),
            "cached_status_rest_multipliers="..M.cachedStatusRestMults,
            "observed_rest_hp_gain_per_sec="..string.format("%.4f",M.healthRestGain/math.max(.01,M.healthRestSeconds)),
            "observed_normal_hp_gain_per_sec="..string.format("%.4f",M.healthNormalGain/math.max(.01,M.healthNormalSeconds)),
            "rest_hp_increase_samples="..tostring(M.healthRestTicks),
            "normal_hp_increase_samples="..tostring(M.healthNormalTicks),
            "archived_health_rest_multiplier=2",
            "archived_status_rest_multiplier=4",
            "last_hp_gain_per_second="..string.format("%.3f",M.lastRate),
            "movement_or_attack_cancellations="..tostring(M.attackInterrupts),
            "damage_cancellations="..tostring(M.damageInterrupts),
            "danger_blocks="..tostring(M.unsafeBlocks),
            "shell_observed_while_moving="..tostring(M.movingShellSeen),
            "last_reason="..M.reason,
            "last_error="..M.lastError,
            "NOTE=WolfController can set WolfRest locally; Rest attribute alone does not prove the server granted 2x/4x."
        },"\n")
    end

    local function tick()
        if not M.alive or not ctx.state.alive then return end
        local now=os.clock()
        if now<M.nextTick then return end
        M.nextTick=now+.22
        local char=player.Character
        if char~=M.lastChar then resetCharacter(char)end
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if not char or not char.Parent or not hum or not root
            or hum.Health<=0 or player:GetAttribute("FeralMenuOpen")==true then
            cancelOwned("Menu, dead or missing character")
            M.shell="NOT ACTIVE";M.multiplier=1
            M.status="WAITING FOR ANIMAL"
            return
        end
        local serverNow=workspace:GetServerTimeNow()
        local rest=char:GetAttribute("WolfRest")==true
        M.shell,M.multiplier=Recovery.shellState(
            char:GetAttribute("Species"),rest,
            char:GetAttribute("WolfRestAt"),serverNow
        )
        if rest and not M.lastRest then
            M.replicatedRestTransitions+=1
        end
        M.lastRest=rest
        -- Real replicated status attributes, NOT local StatusConfig writes.
        -- A status may be re-applied in combat. Increases are excluded from
        -- recovery-rate estimates, and samples across a rest toggle are not
        -- compared because they cross two different modes.
        M.statusActive=false
        local statusInterval=M.prevStatusAt>0 and now-M.prevStatusAt or 0
        for _,entry in ipairs(statusKeys) do
            local current=char:GetAttribute(entry.key)
            if finite(current) then
                if current>entry.limit then M.statusActive=true end
                local last=M.statusValues[entry.key]
                if finite(last) and statusInterval>.15 and statusInterval<3.5
                    and M.prevStatusRest==rest then
                    local v=M.statusSamples[entry.name]
                    local delta=last-current
                    if delta>0 then
                        if rest then
                            v.restDelta+=delta;v.restTicks+=1
                        else
                            v.normalDelta+=delta;v.normalTicks+=1
                        end
                    elseif delta<-.01 then
                        v.gainedTicks+=1
                    end
                    -- Rate denominator includes time without gains, only
                    -- while the negative effect is still above its cutoff.
                    -- Exclude fresh application and samples crossing a rest toggle.
                    if last>entry.limit and delta>=-.01 then
                        if rest then
                            v.restSeconds+=statusInterval
                        else
                            v.normalSeconds+=statusInterval
                        end
                    end
                end
                M.statusValues[entry.key]=current
            else
                M.statusValues[entry.key]=nil
            end
        end
        M.prevStatusAt=now
        M.prevStatusRest=rest
        if now-M.lastMeasure>.85 then
            if finite(hum.Health) and finite(hum.MaxHealth) then
                if finite(M.lastHP) and M.lastMax==hum.MaxHealth then
                    local delta=hum.Health-M.lastHP
                    local interval=now-M.lastMeasure
                    local compatible=M.lastMeasureRest==rest
                    -- Use all eligible damaged-but-not-damaged-again
                    -- observation time, including zero-gain intervals.
                    if compatible and M.lastHP<hum.MaxHealth-.2
                        and delta>=-.01 then
                        if rest then
                            M.healthRestSeconds+=interval
                        else
                            M.healthNormalSeconds+=interval
                        end
                    end
                    if delta>.01 then
                        M.lastRate=delta/math.max(now-M.lastMeasure,.1)
                        if rest then
                            M.restingHeals+=1
                            if compatible then
                                M.healthRestGain+=delta
                                M.healthRestTicks+=1
                            end
                        else
                            M.normalHeals+=1
                            if compatible then
                                M.healthNormalGain+=delta
                                M.healthNormalTicks+=1
                            end
                        end
                    elseif delta<-.01 then
                        M.lastDamage=now
                        M.lastRate=0
                        if M.restOwned and M.multiplier~=.30 then
                            M.damageInterrupts+=1
                            cancelOwned("Damage observed; combat has priority")
                        end
                    else
                        M.lastRate=0
                    end
                end
                M.lastHP=hum.Health
                M.lastMax=hum.MaxHealth
                M.lastMeasure=now
                M.lastMeasureRest=rest
            end
        end
        local moving=root.AssemblyLinearVelocity.Magnitude>1.5
        if moving and M.multiplier==.30 then M.movingShellSeen=true end
        if M.restOwned and moving then
            cancelOwned("Movement interrupted Rest")
        end
        if M.multiplier==.30 then
            M.status="TURTLE SHELL CONDITION SEEN"
            return
        end
        if rest then
            M.status=M.statusActive
                and "REST ACTIVE / 4x STATUS RULE (UNVERIFIED)"
                or "REST ACTIVE / 2x HP RULE (UNVERIFIED)"
            return
        end
        if not M.enabled then
            M.status="PASSIVE MONITOR"
            return
        end
        if moving then
            M.stillSince=0
            M.status="MOVING / REST NOT REQUESTED"
            return
        end
        if M.stillSince==0 then M.stillSince=now end
        if now-M.stillSince<1.7 or now-M.lastInput<2.5
            or now-M.lastDamage<5.5 then
            M.status="WAITING FOR SAFE IDLE"
            return
        end
        -- A Turtle may deliberately rest for shell protection at full HP.
        -- This is opt-in only and still subject to safety/idle checks.
        local species=char:GetAttribute("Species")
        local turtle=type(species)=="string" and
            string.find(species,"SnappingTurtle",1,true)~=nil
        if hum.Health>=hum.MaxHealth-.2 and not M.statusActive and not turtle then
            M.status="HP FULL / NO STATUS TO CLEAR"
            return
        end
        local combatUntil=player:GetAttribute("FeralCombatUntil")
        if finite(combatUntil) and combatUntil>serverNow then
            M.status="IN COMBAT / REST BLOCKED"
            return
        end
        local danger,scanned=dangerNearby(root)
        if danger then
            M.unsafeBlocks+=1
            M.status="ANIMAL NEARBY / REST BLOCKED"
            return
        end
        local hunger,thirst=char:GetAttribute("Hunger"),char:GetAttribute("Thirst")
        if (finite(hunger) and hunger<20)
            or (finite(thirst) and thirst<20) then
            M.status="LOW NEEDS / REST NOT REQUESTED"
            return
        end
        if now<M.pendingUntil then
            M.status="REST REQUESTED / UNCONFIRMED"
            return
        end
        if now<M.nextRequest then
            M.status="REST COOLDOWN / WAITING"
            return
        end
        M.nextRequest=now+8
        local ok=requestRest(char,true)
        M.status=ok and "REQUESTING REST: EXPECT 2x HP / 4x STATUS"
            or "REST UNAVAILABLE"
    end
    M.connection=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            M.lastError=tostring(err)
            cancelOwned("Recovery exception")
            M.status="RECOVERY DISABLED ON ERROR"
            M.enabled=false
        end
    end)
    return M
end
return Recovery

]==========],
["feral-nova-mobile-v11.0.lua"]=[==========[
-- FERAL NOVA PRIME v11 / Controlled mobile-Rest compatibility test.
-- No "always-on regen" claim: only a server can award the built-in Rest
-- multipliers. Tests *one* native Rest(true) window while MOVING, followed
-- by Rest(false). Stops if it enters actual Rest (which blocks bites).
-- Can sustain only after a measured moving uplift, and remains opt-in.
local Mobile={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function finite(v)
    return type(v)=="number" and v==v and v>=0 and v<1e9
end
local keyNames={"FeralInjury","FeralBleed","FeralVenomAmt"}
local function sample(char,hum)
    local sample={hp=hum.Health,max=hum.MaxHealth}
    for _,k in ipairs(keyNames) do
        local v=char:GetAttribute(k)
        sample[k]=finite(v) and v or nil
    end
    return sample
end
local function newWindow()
    return {time=0,hp=0,hpEvents=0,negative=0,
        status={FeralInjury=0,FeralBleed=0,FeralVenomAmt=0},
        statusTime={FeralInjury=0,FeralBleed=0,FeralVenomAmt=0}}
end
local function rate(sum,den)
    if den<=.01 then return nil end
    return sum/den
end
function Mobile.decide(base,signal)
    local hpBase=rate(base.hp,base.time)
    local hpSignal=rate(signal.hp,signal.time)
    local hasHp=hpBase and hpSignal
        and base.time>=2.4 and signal.time>=4
        and hpBase>.025 and hpSignal>hpBase*1.55
    local effects={}
    local hasStatus=false
    for _,key in ipairs(keyNames) do
        local b=rate(base.status[key],base.statusTime[key])
        local s=rate(signal.status[key],signal.statusTime[key])
        if b and s and base.statusTime[key]>=1.5
            and signal.statusTime[key]>=2.5
            and b>.025 and s>b*2.5 then
            hasStatus=true
            effects[#effects+1]=key
        end
    end
    return hasHp==true or hasStatus,hasHp==true,hasStatus,
        hpBase,hpSignal,table.concat(effects,",")
end
function Mobile.attach(ctx)
    local M={
        alive=true,enabled=false,phase="OFF",status="OFF",
        outcome="NOT TESTED",reason="",
        starts=0,requestsOn=0,requestsOff=0,
        injuryEvents=0,attackStops=0,
        restConflicts=0,movementStops=0,deathStops=0,
        baseline=newWindow(),signal=newWindow(),
        after=newWindow(),samples=0,lastError="",
        lastInput=-math.huge,lastAttack=-math.huge,
        nextTick=0,phaseStart=0,nextSignal=0,ownSignal=false,
        lastSample=nil,lastSampleAt=0,lastCharacter=nil,
        measuredHp=false,measuredStatus=false,
        observedUplift=false,upliftStatusTypes="",
        sustainable=false,baselineStarted=false
    }
    local conns={}
    local function fire(on)
        local remote=RS:FindFirstChild("WolfActions")
        if not remote or not remote:IsA("RemoteEvent") then
            M.lastError="WolfActions remote unavailable"
            return false
        end
        local ok,err=pcall(function()
            remote:FireServer("Rest",on)
        end)
        if not ok then
            M.lastError=tostring(err)
            return false
        end
        if on then M.requestsOn+=1;M.ownSignal=true
        else M.requestsOff+=1;M.ownSignal=false end
        return true
    end
    local function cancel()
        if M.ownSignal then
            M.ownSignal=false
            if player.Character==M.lastCharacter
                and M.lastCharacter and M.lastCharacter.Parent then
                fire(false)
            end
        end
    end
    local function finish(message,outcome)
        cancel()
        M.phase="OFF"
        M.enabled=false
        M.status=message
        M.outcome=outcome or M.outcome
        M.lastSample=nil
        M.lastSampleAt=0
    end
    local function clearSamples()
        M.baseline=newWindow()
        M.signal=newWindow()
        M.after=newWindow()
        M.phaseStart=os.clock()
        M.lastSample=nil
        M.lastSampleAt=0
        M.observedUplift=false
        M.measuredHp=false
        M.measuredStatus=false
        M.upliftStatusTypes=""
        M.sustainable=false
        M.baselineStarted=false
    end
    local function input(action)
        M.lastInput=os.clock()
        if action then M.lastAttack=M.lastInput end
        -- Important: never keep an owned server Rest request active on
        -- attack; this has been shown to block WolfController bites.
        if action and M.ownSignal then
            M.attackStops+=1
            finish("STOPPED: ATTACK HAS PRIORITY","INTERRUPTED")
        end
    end
    conns[#conns+1]=UIS.InputBegan:Connect(function(a,processed)
        if processed or UIS:GetFocusedTextBox() then return end
        local key=a.KeyCode
        if a.UserInputType==Enum.UserInputType.MouseButton1
            or a.UserInputType==Enum.UserInputType.MouseButton2 then
            input(true)
        elseif key==Enum.KeyCode.W or key==Enum.KeyCode.A
            or key==Enum.KeyCode.S or key==Enum.KeyCode.D
            or key==Enum.KeyCode.Space then
            M.lastInput=os.clock()
        end
    end)
    function M.setEnabled(v)
        if not v then
            finish("OFF","STOPPED")
            return false
        end
        if M.enabled then return true end
        if ctx.recovery and ctx.recovery.enabled then
            ctx.recovery.setEnabled(false)
        end
        M.enabled=true
        M.starts+=1
        M.phase="BASELINE"
        M.status="MOVING BASELINE: 4 SECONDS"
        M.outcome="MEASURING"
        M.lastCharacter=player.Character
        clearSamples()
        return true
    end
    local function accumulate(window,old,current,elapsed)
        if elapsed<=0 or elapsed>1.2 then return end
        if finite(old.hp) and finite(current.hp)
            and old.max==current.max
            and old.hp<old.max-.5 and current.hp>=old.hp-.001 then
            window.time+=elapsed
            local delta=current.hp-old.hp
            if delta>.001 then
                window.hp+=delta
                window.hpEvents+=1
            end
        end
        for _,key in ipairs(keyNames) do
            local x,y=old[key],current[key]
            if finite(x) and finite(y) and x>.25 and y<=x+.001 then
                window.statusTime[key]+=elapsed
                window.status[key]+=math.max(0,x-y)
            end
        end
    end
    local function tick()
        if not M.alive or not ctx.state.alive then return end
        local now=os.clock()
        if now<M.nextTick then return end
        M.nextTick=now+.19
        if not M.enabled then return end
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if not char or not char.Parent or not hum or not root
            or hum.Health<=0 or player:GetAttribute("FeralMenuOpen")==true then
            M.deathStops+=1
            finish("STOPPED: ANIMAL UNAVAILABLE","INTERRUPTED")
            return
        end
        if char~=M.lastCharacter then
            M.deathStops+=1
            finish("STOPPED: ANIMAL CHANGED","INTERRUPTED")
            return
        end
        -- The entire experiment requires natural movement.
        if root.AssemblyLinearVelocity.Magnitude<1.6 then
            if M.phase=="BASELINE" and not M.baselineStarted then
                M.status="START MOVING TO BEGIN"
                return
            end
            M.movementStops+=1
            finish("STOPPED: MOVEMENT INTERRUPTED","INCONCLUSIVE")
            return
        end
        if M.phase=="BASELINE" and not M.baselineStarted then
            M.baselineStarted=true
            M.phaseStart=now
            M.lastSample=nil
            M.lastSampleAt=0
        end
        if char:GetAttribute("WolfRest")==true then
            M.restConflicts+=1
            finish("STOPPED: REST BLOCKS BITES","UNSAFE")
            return
        end
        if now-M.lastAttack<2.0 then
            finish("STOPPED: RECENT ATTACK","INTERRUPTED")
            return
        end
        local nowSample=sample(char,hum)
        local hasDeficit=nowSample.hp<nowSample.max-.5
        for _,key in ipairs(keyNames) do
            if finite(nowSample[key]) and nowSample[key]>.5 then
                hasDeficit=true
            end
        end
        if not hasDeficit and M.phase=="BASELINE" then
            M.status="NEED HP DEFICIT OR BLEED / VENOM / INJURY"
            M.phaseStart=now
            M.lastSample=nil
            M.lastSampleAt=0
            return
        end
        local window=M.phase=="BASELINE" and M.baseline
            or M.phase=="SIGNAL" and M.signal or M.after
        if M.lastSample and M.lastSampleAt>0 and M.lastSamplePhase==M.phase then
            accumulate(window,M.lastSample,nowSample,now-M.lastSampleAt)
            M.samples+=1
        end
        M.lastSample=nowSample
        M.lastSampleAt=now
        M.lastSamplePhase=M.phase
        local since=now-M.phaseStart
        if M.phase=="BASELINE" then
            M.status="BASELINE: KEEP MOVING"
            if since>=4 then
                if window.time<1 and not (
                    window.statusTime.FeralInjury>=.9
                    or window.statusTime.FeralBleed>=.9
                    or window.statusTime.FeralVenomAmt>=.9) then
                    finish("NO MEASURABLE BASELINE","INCONCLUSIVE")
                    return
                end
                if not fire(true) then
                    finish("NO NATIVE REST REMOTE","UNAVAILABLE")
                    return
                end
                M.phase="SIGNAL"
                M.phaseStart=now
                M.lastSample=nil
                M.status="MOBILE REST SIGNAL SENT / WATCHING"
            end
        elseif M.phase=="SIGNAL" then
            M.status="MOBILE SIGNAL: MEASURING"
            if since>=7 then
                cancel()
                M.phase="AFTER"
                M.phaseStart=now
                M.lastSample=nil
                M.status="COMPARING AFTER SIGNAL"
            end
        elseif M.phase=="AFTER" then
            M.status="AFTER SIGNAL: KEEP MOVING"
            if since>=3.5 then
                local uplift,hp,status,b,s,keys=Mobile.decide(M.baseline,M.signal)
                M.measuredHp=hp
                M.measuredStatus=status
                M.upliftStatusTypes=keys
                M.observedUplift=uplift
                -- Even a measured rate change could be confounded; the
                -- server's actual reason is not exposed to the client.
                if uplift then
                    M.sustainable=true
                    M.enabled=true
                    M.phase="SUSTAIN"
                    M.phaseStart=now
                    M.lastSample=nil
                    M.nextSignal=now
                    M.status="UPLIFT OBSERVED; MOBILE SIGNAL TRIAL"
                    M.outcome="OBSERVED UPLIFT / UNVERIFIED CAUSE"
                else
                    finish("NO VERIFIED MOBILE UPLIFT","NOT SUPPORTED BY MEASUREMENT")
                end
            end
        elseif M.phase=="SUSTAIN" then
            if now>=M.nextSignal then
                if not fire(true) then
                    finish("SUSTAIN SIGNAL UNAVAILABLE","STOPPED")
                    return
                end
                M.nextSignal=now+5
            end
            M.status="MOBILE SIGNAL • OBSERVED UPLIFT"
        end
    end
    function M.report()
        local b,s=M.baseline,M.signal
        local base=rate(b.hp,b.time)
        local signal=rate(s.hp,s.time)
        local parts={
            "FERAL NOVA PRIME v11 | Mobile Recovery Trial",
            "enabled="..tostring(M.enabled).." phase="..M.phase,
            "status="..M.status.." outcome="..M.outcome,
            "native_rest_on="..tostring(M.requestsOn)..
                " native_rest_off="..tostring(M.requestsOff),
            "moving_normal_hp_rate="..tostring(base),
            "moving_signal_hp_rate="..tostring(signal),
            "normal_valid_hp_seconds="..string.format("%.2f",b.time),
            "signal_valid_hp_seconds="..string.format("%.2f",s.time),
            "observed_hp_uplift="..tostring(M.measuredHp),
            "observed_status_uplift="..tostring(M.measuredStatus),
            "status_uplift_types="..M.upliftStatusTypes,
            "rest_conflict_stops="..tostring(M.restConflicts),
            "attack_priority_stops="..tostring(M.attackStops),
            "movement_stops="..tostring(M.movementStops),
            "death_or_respawn_stops="..tostring(M.deathStops),
            "last_error="..M.lastError,
            "NOTE=Remote calls are not proof of server Rest. Rate changes may be confounded.",
            "NOTE=This automatically stops without observed mobile benefit."
        }
        for _,key in ipairs(keyNames) do
            parts[#parts+1]=key.."_normal_rate="..tostring(
                rate(b.status[key],b.statusTime[key]))
            parts[#parts+1]=key.."_signal_rate="..tostring(
                rate(s.status[key],s.statusTime[key]))
        end
        return table.concat(parts,"\n")
    end
    function M.close()
        finish("CLOSED","STOPPED")
        M.alive=false
        if M.connection then M.connection:Disconnect()end
        for _,cn in ipairs(conns) do pcall(function()cn:Disconnect()end)end
    end
    M.connection=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            M.lastError=tostring(err)
            finish("TRIAL ERROR","ERROR")
        end
    end)
    return M
end
return Mobile

]==========],
["feral-nova-tags-v8.0.lua"]=[==========[
-- FERAL NOVA PRIME v8: camera-projected tag overlay.
-- Replaces distance-clipped BillboardGui labels with small ScreenGui labels.
-- Viewport projection is visual only, never changes game character state.
local Tags={}
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function create(kind,props,parent)
    local v=Instance.new(kind)
    for k,x in pairs(props) do v[k]=x end
    v.Parent=parent
    return v
end
function Tags.attach(ctx)
    local S=ctx.state
    local pg=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",8)
    if not pg then error("PlayerGui unavailable for tags") end
    local gui=create("ScreenGui",{
        Name="FeralNovaPrimeTagsV8",
        DisplayOrder=205,ResetOnSpawn=false,
        IgnoreGuiInset=true,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    },pg)
    local T={
        alive=true,gui=gui,active=0,visible=0,closeCount=0,
        lastError="",frameInterval=.065,lastFrame=-math.huge
    }
    local labels={}
    local function clear(plr)
        local label=labels[plr]
        labels[plr]=nil
        if label then pcall(function()label:Destroy()end)end
    end
    local function labelFor(plr)
        local label=labels[plr]
        if label and label.Parent then return label end
        label=create("TextLabel",{
            Name="FloatingAnimalName",
            AnchorPoint=Vector2.new(.5,.5),
            Size=UDim2.fromOffset(172,22),
            BackgroundTransparency=1,
            Font=Enum.Font.GothamBold,
            TextSize=12,
            TextColor3=Color3.fromRGB(231,247,252),
            TextStrokeColor3=Color3.fromRGB(3,8,15),
            TextStrokeTransparency=.12,
            TextXAlignment=Enum.TextXAlignment.Center,
            TextYAlignment=Enum.TextYAlignment.Center,
            TextTruncate=Enum.TextTruncate.AtEnd,
            Visible=false,ZIndex=8
        },gui)
        labels[plr]=label
        return label
    end
    local function worldHead(record)
        local char=record.char
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        local head=char:FindFirstChild("Head")
        local p=(head and head:IsA("BasePart")) and head.Position or root.Position
        if not record.lastTopSample or os.clock()-record.lastTopSample>1.1 then
            record.lastTopSample=os.clock()
            local ok,cf,size=pcall(function()return char:GetBoundingBox()end)
            if ok and cf and size then
                record.cachedTop=cf.Position.Y+size.Y*.5
            end
        end
        local top=record.cachedTop
        if type(top)=="number" then
            -- Keep labels above head without floating above an entire huge
            -- model when giant decorative attachments distort its bounds.
            local lift=math.clamp(top-p.Y+.52,.6,5.5)
            return p+Vector3.new(0,lift,0),root
        end
        return p+Vector3.new(0,2.35,0),root
    end
    local function paint()
        if not T.alive or not S.alive then return end
        local now=os.clock()
        if now-T.lastFrame<T.frameInterval then return end
        T.lastFrame=now
        local camera=workspace.CurrentCamera
        if not camera then
            for _,lab in pairs(labels) do lab.Visible=false end
            T.visible=0
            return
        end
        local vp=camera.ViewportSize
        if vp.X<=0 or vp.Y<=0 then return end
        local enabled=S.flags.playerFinder and S.flags.tags
        local alive={}
        local shown=0
        local closeTags=0
        local total=0
        for plr,record in pairs(S.byPlayer) do
            if plr~=player and record and record.char and record.char.Parent then
                local world,root=worldHead(record)
                if world and root and root.Parent then
                    total+=1
                    local lab=labelFor(plr)
                    alive[plr]=true
                    -- Core tracker originally creates BillboardGui plates.
                    -- Disable their render; this overlay remains visible
                    -- even at extremely short camera/target distances.
                    if record.b then record.b.Enabled=false end
                    if enabled then
                        local pos,front=camera:WorldToViewportPoint(world)
                        local rootDist=(root.Position-camera.CFrame.Position).Magnitude
                        if rootDist<=S.range then
                            local closeCamera=rootDist<9
                            local x,y
                            if pos.Z>0 and (front or closeCamera) then
                                x=pos.X
                                y=pos.Y
                            elseif closeCamera then
                                -- Player may literally surround the camera.
                                -- Keep a small name chip at the top, instead
                                -- of silently dropping their name.
                                x=vp.X*.5
                                y=76+closeTags*24
                            end
                            if x and y then
                                x=math.clamp(x,93,vp.X-93)
                                y=math.clamp(y,35,vp.Y-35)
                                if closeCamera then
                                    y=math.min(y,104+closeTags*24)
                                    closeTags+=1
                                end
                                lab.Position=UDim2.fromOffset(x,y)
                                lab.Text=record.name and record.name.Text or plr.DisplayName
                                lab.TextColor3=record.h and record.h.OutlineColor
                                    or Color3.fromRGB(231,247,252)
                                lab.Visible=true
                                shown+=1
                            else
                                lab.Visible=false
                            end
                        else
                            lab.Visible=false
                        end
                    else
                        lab.Visible=false
                    end
                end
            end
        end
        for plr in pairs(labels) do
            if not alive[plr] then clear(plr) end
        end
        T.active=total
        T.visible=shown
        T.closeCount=closeTags
    end
    function T.report()
        return "FERAL v8 Screen Tags | tracked="..tostring(T.active)..
            " visible="..tostring(T.visible)..
            " close="..tostring(T.closeCount)..
            " enabled="..tostring(S.flags.tags)..
            " error="..tostring(T.lastError)
    end
    function T.close()
        if not T.alive then return end
        T.alive=false
        if T.connection then T.connection:Disconnect()end
        for plr in pairs(labels) do clear(plr) end
        if gui then pcall(function()gui:Destroy()end)end
    end
    T.connection=RunService.RenderStepped:Connect(function()
        local ok,err=pcall(paint)
        if not ok then T.lastError=tostring(err) end
    end)
    return T
end
return Tags

]==========],
["feral-nova-prime-ui-v11.0.lua"]=[==========[
-- FERAL NOVA PRIME v11.0 | streamlined survival dashboard
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
    local Mobile=ctx.mobile
    local Tags=ctx.tags
    if not Escape or not P or not Lab or not Recovery or not Mobile or not Tags then return nil end
    local pg=player:FindFirstChildOfClass("PlayerGui")
        or player:WaitForChild("PlayerGui",10)
    if not pg then return nil end
    local gui=make("ScreenGui",{
        Name="FeralNovaPrimeV110",ResetOnSpawn=false,
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
    local subtitle=txt(header,"FERAL  •  v11.0  •  COMBAT SAFE / MOBILE RECOVERY",10,C.muted)
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
    local mobileButton,mobileDesc=card(18,318,
        "MOBILE RECOVERY","Tests 2× HP / 4× effects while moving","✚",
        function()return Mobile.enabled end,
        function()
            if Mobile.enabled then
                Mobile.setEnabled(false)
            else
                Recovery.setEnabled(false)
                Mobile.setEnabled(true)
            end
        end,"mobile")
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
    local safeRest=btn(esp,"SAFE REST",function()
        if Recovery.enabled then
            Recovery.setEnabled(false)
        else
            Mobile.setEnabled(false)
            Recovery.setEnabled(true)
        end
        ctx.onUI()
    end,120,30)
    safeRest.Position=UDim2.fromOffset(507,11)
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
        local report=Escape.report().."\n\n"..Lab.report().."\n\n"..Recovery.report().."\n\n"..Mobile.report().."\n"..Tags.report()..
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
        feedback=ok and "STATUS COPIED • MOBILE / ESCAPE / COMBAT"
            or "CLIPBOARD NOT SUPPORTED BY EXECUTOR"
        feedbackUntil=os.clock()+3.5
        if not ok then warn("[NOVA PRIME] "..report) end
        ctx.onUI()
    end,103,31)
    reportButton.Position=UDim2.fromOffset(566,5)
    local reset=btn(footer,"RESET",function()
        Lab.setEnabled(false)
        Mobile.setEnabled(false)
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
            styleButton(safeRest,Recovery.enabled,"REST "..(Recovery.enabled and "ON" or "OFF"))
            mobileDesc.Text=Mobile.status
            mobileDesc.TextColor3=(Mobile.enabled or Mobile.observedUplift)
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
                    (Mobile.enabled and ("MOBILE  "..Mobile.phase.."  •  ") or "")..
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
        Mobile.close()
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

]==========]
}

local function get(path)
    local ok,body=true,BUNDLED[path]
    if not ok or type(body)~="string" or #body<100 then
        warn("[NOVA PRIME] Module download failed: "..path)
        return nil
    end
    local compiled,err=loadstring(body)
    if not compiled then
        warn("[NOVA PRIME] Compilation failed: "..path.." - "..tostring(err))
        return nil
    end
    local done,value=pcall(compiled)
    if not done then
        warn("[NOVA PRIME] Module failed: "..path.." - "..tostring(value))
        return nil
    end
    return value
end

local core=get("feral-aurora-engine-v2.1.lua")
local power=get("feral-aurora-power-v3.1.lua")
local escape=get("feral-nova-escape-v9.0.lua")
local lab=get("feral-nova-combat-v10.0.lua")
local recovery=get("feral-nova-recovery-v10.0.lua")
local mobile=get("feral-nova-mobile-v11.0.lua")
local tags=get("feral-nova-tags-v8.0.lua")
local ui=get("feral-nova-prime-ui-v11.0.lua")
if not core or type(core.new)~="function"
    or not power or type(power.attach)~="function"
    or not escape or type(escape.attach)~="function"
    or not lab or type(lab.attach)~="function"
    or not recovery or type(recovery.attach)~="function"
    or not mobile or type(mobile.attach)~="function"
    or not tags or type(tags.attach)~="function"
    or not ui or type(ui.mount)~="function" then
    warn("[NOVA PRIME] Required modules unavailable. Nothing changed.")
    return
end
local ok,ctx=pcall(function()return core.new({})end)
if not ok or type(ctx)~="table" then
    warn("[NOVA PRIME] Could not start core.")
    return
end
local attached,reason=pcall(function()
    power.attach(ctx)
    ctx.escape=escape.attach(ctx)
    ctx.lab=lab.attach(ctx)
    ctx.recovery=recovery.attach(ctx)
    ctx.mobile=mobile.attach(ctx)
    ctx.tags=tags.attach(ctx)
end)
if not attached or not ctx.escape or not ctx.lab or not ctx.recovery or not ctx.mobile or not ctx.tags then
    pcall(function()if ctx.tags then ctx.tags.close()end end)
    pcall(function()if ctx.mobile then ctx.mobile.close()end end)
    pcall(function()if ctx.recovery then ctx.recovery.close()end end)
    pcall(function()if ctx.lab then ctx.lab.close()end end)
    pcall(function()if ctx.escape then ctx.escape.close()end end)
    pcall(ctx.close)
    warn("[NOVA PRIME] Core extension error: "..tostring(reason))
    return
end
local ready,window=pcall(function()return ui.mount(ctx)end)
if not ready or not window then
    pcall(function()ctx.tags.close()end)
    pcall(function()ctx.mobile.close()end)
    pcall(function()ctx.recovery.close()end)
    pcall(function()ctx.lab.close()end)
    pcall(ctx.escape.close)
    pcall(ctx.close)
    warn("[NOVA PRIME] UI failed: "..tostring(window))
    return
end
ctx.notice("NOVA PRIME v11: combat-first recovery trial. No server-side permanent bonus is yet verified.")
