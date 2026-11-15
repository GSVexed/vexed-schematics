-- FERAL Recovery Mechanism Lab v1.8
-- Passive, read-only, Velocity-friendly Luau diagnostic.
-- Compares natural Rest, idle without rest, and visible-only rest signals. Tracks health and stamina
-- along with changed player/character attributes and relevant Value objects.
-- Does not modify game attributes, fire remotes, hook methods or override movement.
-- Client-visible observations cannot establish or bypass server-side authority.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local guiParent = player:WaitForChild("PlayerGui")

local old = guiParent:FindFirstChild("StaminaResearchPanel")
if old then old:Destroy() end

local DURATION = 150
local INTERVAL = 0.25
local MAX_SAMPLES = 645
local MAX_EVENTS = 320
local MAX_WATCHES = 125
local SCAN_LIMIT_PER_ROOT = 2800

local colors = {
    bg=Color3.fromRGB(15,20,30),
    surface=Color3.fromRGB(26,37,51),
    raised=Color3.fromRGB(36,51,70),
    border=Color3.fromRGB(65,83,104),
    text=Color3.fromRGB(240,247,255),
    muted=Color3.fromRGB(162,181,204),
    accent=Color3.fromRGB(54,194,170),
    blue=Color3.fromRGB(64,127,215),
    red=Color3.fromRGB(193,77,91),
}
local function make(kind,props,parent)
    local obj=Instance.new(kind)
    for key,value in pairs(props) do obj[key]=value end
    obj.Parent=parent
    return obj
end
local function round(obj,n)
    make("UICorner",{CornerRadius=UDim.new(0,n or 9)},obj)
end
local function text(parent,name,value,x,y,w,h,size,color,bold)
    return make("TextLabel",{
        Name=name,Text=value,
        Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h),
        BackgroundTransparency=1,
        TextColor3=color or colors.text,
        TextSize=size,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,
        TextYAlignment=Enum.TextYAlignment.Center
    },parent)
end
local function button(parent,name,value,x,y,w,background)
    local b=make("TextButton",{
        Name=name,Text=value,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,38),
        BackgroundColor3=background,BorderSizePixel=0,
        TextColor3=colors.text,TextSize=12,
        Font=Enum.Font.GothamBold,AutoButtonColor=true
    },parent)
    round(b,8)
    return b
end

local gui=make("ScreenGui",{
    Name="StaminaResearchPanel",DisplayOrder=360,
    ResetOnSpawn=false,IgnoreGuiInset=true
},guiParent)
local panel=make("Frame",{
    Name="RestLab",AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.5),
    Size=UDim2.fromOffset(540,778),
    BackgroundColor3=colors.bg,BorderSizePixel=0,Active=true
},gui)
round(panel,13)
make("UIStroke",{Color=colors.border,Thickness=1},panel)
local camera=workspace.CurrentCamera
if camera then
    local viewport=camera.ViewportSize
    make("UIScale",{
        Scale=math.clamp(math.min(viewport.X/570,viewport.Y/840),0.56,1)
    },panel)
end
local header=make("Frame",{
    Name="DragHeader",Size=UDim2.fromOffset(540,59),
    BackgroundTransparency=1,Active=true
},panel)
text(header,"Title","FERAL  /  RECOVERY MECHANISM LAB",15,6,420,27,16,colors.text,true)
text(header,"Subtitle","v1.8 • natural rest vs idle • health + stamina • read-only",15,32,424,18,10,colors.muted,false)
local minimize=button(header,"Minimize","–",470,12,27,colors.raised)
local close=button(header,"Close","X",503,12,23,colors.red)

local vitality=make("Frame",{
    Name="Vitality",Position=UDim2.fromOffset(14,67),
    Size=UDim2.fromOffset(512,124),
    BackgroundColor3=colors.surface,BorderSizePixel=0
},panel)
round(vitality,10)
text(vitality,"Caption","CURRENT STAMINA / MAXIMUM",12,8,280,18,10,colors.muted,true)
local staminaLabel=text(vitality,"Stamina","— / —",12,27,289,32,24,colors.text,true)
local rateLabel=text(vitality,"Rate","— / sec",307,31,190,24,12,colors.accent,true)
rateLabel.TextXAlignment=Enum.TextXAlignment.Right
local bar=make("Frame",{
    Name="Bar",Position=UDim2.fromOffset(12,65),
    Size=UDim2.fromOffset(488,11),
    BackgroundColor3=colors.raised,BorderSizePixel=0
},vitality)
round(bar,5)
local fill=make("Frame",{
    Name="Fill",Size=UDim2.fromScale(0,1),
    BackgroundColor3=colors.accent,BorderSizePixel=0
},bar)
round(fill,5)
local movementLabel=text(vitality,"Movement","Movement: waiting...",12,85,484,25,12,colors.text,true)

local restCard=make("Frame",{
    Name="RestStateCard",Position=UDim2.fromOffset(14,201),
    Size=UDim2.fromOffset(512,135),
    BackgroundColor3=colors.surface,BorderSizePixel=0
},panel)
round(restCard,10)
text(restCard,"RestHeading","EXPLICIT REST STATE VS. OBSERVED REGENERATION",12,7,489,20,10,colors.muted,true)
local restLabel=text(restCard,"ExplicitRest","Explicit resting signal: not identified",12,30,488,24,14,colors.accent,true)
local evidenceLabel=text(restCard,"RestSource","Evidence: no rest-specific flag found yet",12,60,488,19,11,colors.muted,false)
local recoveryLabel=text(restCard,"Recovery","Observed stamina: waiting for sample",12,81,488,21,12,colors.text,false)
local discoveryLabel=text(restCard,"Discovery","Related object candidates: 0  •  distinct keys: 0",12,107,488,18,10,colors.muted,false)

text(panel,"Message",
    "For clean evidence: start with partial stamina, then test idle, normal Rest, and sprint. No game state is changed.",
    15,345,507,33,10,colors.muted,false)

local mechanismCard=make("Frame",{
    Name="MechanismCard",Position=UDim2.fromOffset(14,386),
    Size=UDim2.fromOffset(512,102),BackgroundColor3=colors.surface,BorderSizePixel=0
},panel)
round(mechanismCard,9)
text(mechanismCard,"Heading","NATURAL REST vs VISUAL REST vs IDLE",12,6,482,18,10,colors.muted,true)
local classifierLabel=text(mechanismCard,"Classifier","Rest classification: waiting...",12,27,486,24,13,colors.accent,true)
local healthLabel=text(mechanismCard,"Health","Health: waiting...",12,53,480,19,11,colors.text,false)
local stateHint=text(mechanismCard,"Hint","Natural Rest requires HudRest + WolfRest; visual-only has WolfRest without HudRest.",12,75,490,19,10,colors.muted,false)

local start=button(panel,"Start","Start 150s scan",14,505,173,colors.accent)
local stop=button(panel,"Stop","Stop",196,505,74,colors.red)
local copySummary=button(panel,"CopySummary","Copy summary",279,505,118,colors.blue)
local copyFull=button(panel,"CopyFull","Copy full",406,505,120,colors.blue)
local progressBar=make("Frame",{
    Name="Progress",Position=UDim2.fromOffset(14,554),
    Size=UDim2.fromOffset(512,7),
    BackgroundColor3=colors.raised,BorderSizePixel=0
},panel)
round(progressBar,4)
local progressFill=make("Frame",{
    Name="ProgressFill",Size=UDim2.fromScale(0,1),
    BackgroundColor3=colors.blue,BorderSizePixel=0
},progressBar)
round(progressFill,4)
local status=text(panel,"Status","Ready. Observe resting, walking, crouching, trotting, sprint and burst.",
    14,567,512,34,11,colors.muted,false)
text(panel,"ReportHeading","REPORT PREVIEW  •  COPY SUMMARY OR FULL DETAILS",14,605,510,21,10,colors.muted,true)
local report=make("TextBox",{
    Name="Report",Position=UDim2.fromOffset(14,631),
    Size=UDim2.fromOffset(512,132),
    BackgroundColor3=colors.surface,BorderSizePixel=0,
    TextColor3=colors.text,
    Text="Press Start. Detection runs automatically; no movement buttons required.",
    Font=Enum.Font.Code,TextSize=11,
    MultiLine=true,TextWrapped=false,TextEditable=true,
    ClearTextOnFocus=false,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top
},panel)
round(report,9)
make("UIPadding",{
    PaddingLeft=UDim.new(0,9),PaddingRight=UDim.new(0,9),
    PaddingTop=UDim.new(0,7),PaddingBottom=UDim.new(0,7)
},report)

local connections={}
local function own(con)
    table.insert(connections,con)
    return con
end
local dragging=false
local dragAt=nil
local panelAt=nil
own(header.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1
       or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true
        dragAt=input.Position
        panelAt=panel.Position
    end
end))
own(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement
       or input.UserInputType==Enum.UserInputType.Touch) then
        local d=input.Position-dragAt
        panel.Position=UDim2.new(panelAt.X.Scale,panelAt.X.Offset+d.X,
            panelAt.Y.Scale,panelAt.Y.Offset+d.Y)
    end
end))
own(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1
       or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end))
local minimized=false
minimize.Activated:Connect(function()
    minimized=not minimized
    panel.Size=UDim2.fromOffset(540,minimized and 59 or 778)
    for _,child in ipairs(panel:GetChildren()) do
        if child:IsA("GuiObject") and child~=header then
            child.Visible=not minimized
        end
    end
    minimize.Text=minimized and "+" or "–"
end)

local running=false
local stopped=false
local began=0
local samples={}
local events={}
local objectCandidates={}
local watched={}
local snapshots={}
local keys={}
local animations={}
local lastRestSource="none"
local previousStamina=nil
local previousTime=nil
local lastMode="Unknown"
local lastExplicitRest=false
local lastAnimSignature=""
local finalSummary=""
local finalFull=""
local capped=false
local watchCapped=false
local scanCapped=false
local overlapping=0
local regenMoving=0
local sampleErrors=0
local signalSnapshots={}
local signalInfo={}
local signalLimited=false
local restClassBefore="Unknown"
local lastHealth=nil
local lastHealthAt=nil
local healthChangeEvents=0
local knownSourceCount=0

local function fmt(value)
    if typeof(value)=="number" then return string.format("%.2f",value) end
    if value==nil then return "-" end
    return tostring(value)
end
local function elapsed()
    return running and math.max(0,os.clock()-began) or 0
end
local function note(message,critical)
    if not running then return end
    if #events>=MAX_EVENTS then capped=true;return end
    table.insert(events,string.format("[%.2fs]%s %s",elapsed(),
        critical and " IMPORTANT" or "",message))
end
local function containsAny(name,words)
    local low=string.lower(tostring(name))
    for _,word in ipairs(words) do
        if string.find(low,word,1,true) then return true end
    end
    return false
end
local REST_KEYS={"rest","sleep","asleep","recover","regen","nap","lie","lying","idle","relax","breathe","breath"}
local RELATED_KEYS={"rest","sleep","asleep","recover","regen","nap","lie","lying",
                    "idle","relax","breathe","breath","stam","energ","fatigue","exhaust",
                    "trot","burst","sprint","crouch","walk","gait","stance","movement"}
local function attr(obj,key)
    if not obj then return nil end
    return obj:GetAttribute(key)
end
local function num(obj,key)
    local value=attr(obj,key)
    return typeof(value)=="number" and value or nil
end
local function readable(value)
    local kind=typeof(value)
    if kind=="string" or kind=="number" or kind=="boolean" or kind=="EnumItem" then
        return string.sub(tostring(value),1,110)
    end
    return kind
end
local function relativePath(obj,root,prefix)
    local names={}
    local cur=obj
    while cur and cur~=root and #names<14 do
        table.insert(names,1,cur.Name)
        cur=cur.Parent
    end
    return prefix .. (#names>0 and "/"..table.concat(names,"/") or "")
end

-- Record relevant descendants (including rest/sleep indicators) but no personal/chat text.
local function reindex()
    watched={}
    objectCandidates={}
    local containers={
        {player.Character,"Character"},
        {guiParent:FindFirstChild("FeralHUD"),"FeralHUD"},
        {guiParent:FindFirstChild("FeralMenu"),"FeralMenu"},
        {ReplicatedStorage,"ReplicatedStorage"}
    }
    for _,entry in ipairs(containers) do
        local root,prefix=entry[1],entry[2]
        if root then
            local nodes=root:GetDescendants()
            local limit=math.min(#nodes,SCAN_LIMIT_PER_ROOT)
            if #nodes>limit then scanCapped=true end
            for i=1,limit do
                if #watched>=MAX_WATCHES then watchCapped=true;break end
                local obj=nodes[i]
                if containsAny(obj.Name,RELATED_KEYS) then
                    local path=relativePath(obj,root,prefix)
                    if containsAny(obj.Name,REST_KEYS) then
                        objectCandidates[path]=obj.ClassName
                    end
                    if obj:IsA("ValueBase") or obj:IsA("GuiObject") then
                        table.insert(watched,{obj=obj,path=path})
                    end
                end
            end
        end
    end
    discoveryLabel.Text="Rest-related objects: "..(function()
        local n=0
        for _ in pairs(objectCandidates) do n=n+1 end
        return n
    end)().."  •  relevant keys: "..(function()
        local n=0
        for _ in pairs(keys) do n=n+1 end
        return n
    end)()
end

local function inspectVisible()
    local char=player.Character
    local humanoid=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local exposedRest=false
    local restSource="none"
    local observedAttributes={}
    for _,entry in ipairs({
        {player,"Player"},{char,"Character"},
        {humanoid,"Humanoid"},{root,"Root"}
    }) do
        local obj,prefix=entry[1],entry[2]
        if obj then
            local ok,attrs=pcall(function() return obj:GetAttributes() end)
            if ok then
                for key,value in pairs(attrs) do
                    if containsAny(key,RELATED_KEYS) then
                        local full=prefix.."@"..key
                        local str=readable(value)
                        observedAttributes[full]=str
                        if keys[full]~=str then
                            keys[full]=str
                            if containsAny(key,REST_KEYS) then
                                note("REST/RECOVERY ATTRIBUTE "..full.." = "..str,true)
                            end
                        end
                        if containsAny(key,REST_KEYS) then
                            local low=string.lower(key)
                            local active=(value==true)
                                or (typeof(value)=="string" and
                                    containsAny(value,{"rest","sleep","idle","recover","regen"}))
                            -- Numeric regen rates do not prove that a resting mode is active.
                            if active and not (string.find(low,"regen",1,true) and typeof(value)=="number") then
                                exposedRest=true
                                restSource=full.."="..str
                            end
                        end
                    end
                end
            end
        end
    end
    for _,entry in ipairs(watched) do
        local obj=entry.obj
        if obj.Parent then
            local ok,value=pcall(function()
                if obj:IsA("ValueBase") then return obj.Value end
                if obj:IsA("GuiObject") then return obj.Visible end
                return nil
            end)
            if ok and value~=nil and containsAny(obj.Name,REST_KEYS) then
                local id=entry.path.."."..(obj:IsA("ValueBase") and "Value" or "Visible")
                local str=readable(value)
                if snapshots[id]~=str then
                    snapshots[id]=str
                    note("REST-RELATED OBJECT "..id.." = "..str,false)
                end
                -- Do not equate a visible UI button with active resting.
                if obj:IsA("ValueBase") and value==true then
                    exposedRest=true
                    restSource=id.."=true"
                end
            end
        end
    end
    if humanoid and humanoid.Sit then
        exposedRest=true
        restSource="Humanoid.Sit=true (sitting, not proven resting regen)"
    end
    return exposedRest,restSource,humanoid
end

local function inspectAnimations(char)
    if not char then return false,"none" end
    local restful=false
    local source="none"
    local current={}
    local animators={}
    for _,obj in ipairs(char:GetDescendants()) do
        if obj:IsA("Animator") then
            table.insert(animators,obj)
            if #animators>=4 then break end
        end
    end
    for _,animator in ipairs(animators) do
        local ok,tracks=pcall(function() return animator:GetPlayingAnimationTracks() end)
        if ok then
            for _,track in ipairs(tracks) do
                if #current>=16 then break end
                local weight=0
                pcall(function() weight=track.WeightCurrent end)
                if weight>0.04 then
                    local name=tostring(track.Name)
                    local animationId=""
                    pcall(function()
                        if track.Animation then
                            name=name.."/"..tostring(track.Animation.Name)
                            animationId=tostring(track.Animation.AnimationId)
                        end
                    end)
                    local signature=string.sub(name,1,75)..
                        (animationId~="" and "#" .. string.sub(animationId,1,45) or "")
                    table.insert(current,signature)
                    animations[signature]=true
                    if containsAny(name,REST_KEYS) then
                        restful=true
                        source="Playing animation: "..string.sub(name,1,70)
                    end
                end
            end
        end
    end
    table.sort(current)
    local signature=table.concat(current,"; ")
    if signature~=lastAnimSignature then
        lastAnimSignature=signature
        if signature~="" then
            note("PLAYING ANIMATIONS: "..string.sub(signature,1,280),false)
        end
    end
    return restful,source
end

local function modeOf(char,hum,speed,input)
    if attr(char,"WolfBurst")==true or attr(player,"HudBurst")==true then return "Burst" end
    if attr(player,"HudSprint")==true then return "Sprint" end
    if attr(char,"WolfTrot")==true or attr(player,"HudTrot")==true then return "Trot" end
    if attr(char,"FeralCrouch")==true then return "Crouch" end
    if hum and hum.Sit then return "Sit" end
    if speed and speed<0.8 and (not input or input<0.1) then return "Stationary" end
    if attr(char,"StaminaOut")==true then return "Exhausted movement" end
    if speed and speed>=0.8 then return "Walk/unlabelled" end
    return "Unknown"
end


-- Separate the player's Rest request from the character's animation-facing flag.
-- "Natural" means both visible flags are true, not that the server confirmed authority.
local function classifyRest(char)
    local hud=attr(player,"HudRest")==true
    local wolf=attr(char,"WolfRest")==true
    if hud and wolf then return "Natural Rest" end
    if wolf then return "Visual-only flag" end
    if hud then return "Rest requested" end
    return "No Rest"
end

-- A broad, bounded snapshot of primitive attributes and relevant value objects.
-- Never reads chat text, clipboard, user identification, or arbitrary TextBoxes.
local function collectSignals(char,hum,root)
    local result={}
    for _,pair in ipairs({
        {player,"Player"},{char,"Character"},
        {hum,"Humanoid"},{root,"Root"}
    }) do
        local obj,prefix=pair[1],pair[2]
        if obj then
            local ok,attributes=pcall(function() return obj:GetAttributes() end)
            if ok then
                for key,value in pairs(attributes) do
                    local kind=typeof(value)
                    if kind=="number" or kind=="boolean" or kind=="string" then
                        local safe=string.lower(tostring(key))
                        if not containsAny(safe,{"chat","message","token","secret","password","userid","session","auth"}) then
                            local id=prefix.."@"..key
                            if kind~="string" or #tostring(value)<=42 then
                                result[id]=readable(value)
                            end
                        end
                    end
                end
            end
        end
    end
    local added=0
    for _,entry in ipairs(watched) do
        if added>=80 then break end
        local obj=entry.obj
        if obj.Parent and obj:IsA("ValueBase") and containsAny(entry.path,RELATED_KEYS) then
            local ok,value=pcall(function() return obj.Value end)
            if ok and (typeof(value)=="boolean" or typeof(value)=="number" or
                (typeof(value)=="string" and #value<=40)) then
                result[entry.path..".Value"]=readable(value)
                added=added+1
            end
        end
    end
    return result
end

local function captureSignalChanges(row,sourceValues)
    local state=row.restClass
    for id,value in pairs(sourceValues) do
        local info=signalInfo[id]
        if not info then
            if knownSourceCount>=240 then
                signalLimited=true
            else
                info={changes=0,byState={},unique={},distinct=0}
                signalInfo[id]=info
                knownSourceCount=knownSourceCount+1
            end
        end
        if info then
            if not info.unique[value] then
                info.unique[value]=true
                info.distinct=info.distinct+1
            end
            local distribution=info.byState[state]
            if not distribution then
                distribution={};info.byState[state]=distribution
            end
            distribution[value]=(distribution[value] or 0)+1
            local old=signalSnapshots[id]
            if old~=nil and old~=value then
                info.changes=info.changes+1
                local meaningful=(info.distinct<=5) and
                   (containsAny(id,RELATED_KEYS) or
                    not tonumber(value) or not tonumber(old))
                if meaningful and info.changes<=5 then
                    note("EXPOSED SIGNAL "..id.." "..old.." -> "..value..
                        " | "..state.." | "..row.mode,false)
                end
            end
        end
        signalSnapshots[id]=value
    end
end

local function profileReport(out)
    table.insert(out,"")
    table.insert(out,"=== RECOVERY MECHANISM COMPARISON ===")
    table.insert(out,"Natural Rest = HudRest=true AND WolfRest=true.")
    table.insert(out,"Visual-only flag = WolfRest=true, HudRest=false.")
    table.insert(out,"Natural classification reflects client flags, not server approval.")
    table.insert(out,"Only stable intervals >=0.8s after a rest-state transition count.")
    table.insert(out,"Stamina at cap and health at cap are excluded from corresponding rates.")
    table.insert(out,"Positive/negative deltas recorded separately; positive movement deltas may be acceleration carryover.")
    local states={"No Rest","Rest requested","Natural Rest","Visual-only flag"}
    local types={"Stationary","Slow movement","Sprint","Burst","Other"}
    local data={}
    for _,state in ipairs(states) do
        data[state]={}
        for _,typeName in ipairs(types) do
            data[state][typeName]={secs=0,stPlus=0,stMinus=0,stSecs=0,
                hpPlus=0,hpMinus=0,hpSecs=0,n=0,stCap=0,hpCap=0}
        end
    end
    local lastTransition=0
    for i=2,#samples do
        local a,b=samples[i-1],samples[i]
        if a.restClass~=b.restClass then lastTransition=b.t end
        local dt=b.t-a.t
        if dt>0 and dt<1 and a.restClass==b.restClass
           and b.t-lastTransition>=0.8 then
            local typeName="Other"
            if a.mode=="Burst" and b.mode=="Burst" then typeName="Burst"
            elseif a.mode=="Sprint" and b.mode=="Sprint" then typeName="Sprint"
            elseif a.speed and b.speed and a.speed<0.8 and b.speed<0.8 then
                typeName="Stationary"
            elseif a.speed and b.speed and a.speed<=5 and b.speed<=5 then
                typeName="Slow movement"
            end
            local v=data[b.restClass] and data[b.restClass][typeName]
            if v then
                v.secs=v.secs+dt
                v.n=v.n+1
                if a.stam and b.stam and a.maximum and b.maximum then
                    if math.min(a.maximum-a.stam,b.maximum-b.stam)>0.35 then
                        local d=b.stam-a.stam
                        v.stSecs=v.stSecs+dt
                        if d>0 then v.stPlus=v.stPlus+d else v.stMinus=v.stMinus-d end
                    else
                        v.stCap=v.stCap+dt
                    end
                end
                if a.health and b.health and a.healthMax and b.healthMax then
                    if math.min(a.healthMax-a.health,b.healthMax-b.health)>0.3 then
                        local d=b.health-a.health
                        v.hpSecs=v.hpSecs+dt
                        if d>0 then v.hpPlus=v.hpPlus+d else v.hpMinus=v.hpMinus-d end
                    else
                        v.hpCap=v.hpCap+dt
                    end
                end
            end
        end
    end
    for _,state in ipairs(states) do
        for _,typeName in ipairs(types) do
            local v=data[state][typeName]
            if v.n>0 then
                table.insert(out,string.format(
                    "%s / %s | %.1fs | stam +%.2f -%.2f over %.1fs eligible | health +%.2f -%.2f over %.1fs eligible | capped(st/hp)=%.1f/%.1fs",
                    state,typeName,v.secs,v.stPlus,v.stMinus,v.stSecs,
                    v.hpPlus,v.hpMinus,v.hpSecs,v.stCap,v.hpCap))
            end
        end
    end
    table.insert(out,"")
    table.insert(out,"=== NON-STAMINA ATTRIBUTE CHANGES ASSOCIATED WITH REST ===")
    table.insert(out,"Values show client-visible correlation only, not cause.")
    local names={}
    for id,info in pairs(signalInfo) do
        if info.distinct>1 and info.distinct<=8 and info.changes>0 then
            if (info.byState["Natural Rest"] or info.byState["Visual-only flag"] or
                containsAny(id,RELATED_KEYS)) then table.insert(names,id) end
        end
    end
    table.sort(names,function(a,b)
        local x,y=signalInfo[a],signalInfo[b]
        local ax=(x.byState["Natural Rest"] and 100 or 0)+(x.byState["Visual-only flag"] and 40 or 0)+
            (containsAny(a,RELATED_KEYS) and 20 or 0)
        local by=(y.byState["Natural Rest"] and 100 or 0)+(y.byState["Visual-only flag"] and 40 or 0)+
            (containsAny(b,RELATED_KEYS) and 20 or 0)
        return ax==by and a<b or ax>by
    end)
    if #names==0 then table.insert(out,"No other bounded attribute transitions found.") end
    local shown=0
    for _,id in ipairs(names) do
        shown=shown+1
        if shown>65 then
            table.insert(out,"(More signals omitted; cap 65)")
            break
        end
        local info=signalInfo[id]
        local byStates={}
        for _,state in ipairs(states) do
            if info.byState[state] then
                local vals={}
                for val,count in pairs(info.byState[state]) do
                    table.insert(vals,{v=val,n=count})
                end
                table.sort(vals,function(a,b) return a.n>b.n end)
                local top={}
                for j=1,math.min(2,#vals) do
                    table.insert(top,vals[j].v.." ("..vals[j].n..")")
                end
                table.insert(byStates,state..": "..table.concat(top,", "))
            end
        end
        table.insert(out,id.." | changes="..info.changes.." | "..table.concat(byStates,"; "))
    end
    if signalLimited then table.insert(out,"WARNING: signal inventory capped at 240") end
    table.insert(out,"Health may decline from survival mechanics; this tool does not infer the cause.")
end

local function observe()
    local char=player.Character
    local exposedRest,restSource,hum=inspectVisible()
    local animatorRest,animSource=inspectAnimations(char)
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local horizontal=nil
    if root and root:IsA("BasePart") then
        local v=root.AssemblyLinearVelocity
        horizontal=Vector3.new(v.X,0,v.Z).Magnitude
    end
    local input=hum and hum.MoveDirection.Magnitude or nil
    local detectedMode=modeOf(char,hum,horizontal,input)
    local restExplicit=exposedRest or animatorRest
    local restEvidence=animatorRest and animSource or restSource
    local restClass=classifyRest(char)
    local row={
        t=elapsed(),stam=num(char,"Stamina"),maximum=num(char,"StaminaMax"),
        mode=detectedMode,rest=restExplicit,restEvidence=restEvidence,
        restClass=restClass,hudRest=attr(player,"HudRest"),
        wolfRest=attr(char,"WolfRest"),
        sprint=attr(player,"HudSprint"),burst=attr(char,"WolfBurst"),
        trot=attr(char,"WolfTrot"),crouch=attr(char,"FeralCrouch"),
        exhausted=attr(char,"StaminaOut"),health=hum and hum.Health or nil,
        healthMax=hum and hum.MaxHealth or nil,
        speed=horizontal,input=input,walk=hum and hum.WalkSpeed or nil,
        humanoidState=hum and hum:GetState().Name or "NoHumanoid"
    }
    row.observedSignals=collectSignals(char,hum,root)
    return row
end

local function render(row,rate)
    staminaLabel.Text=fmt(row.stam).." / "..fmt(row.maximum)
    local fraction=0
    if row.stam and row.maximum and row.maximum>0 then
        fraction=math.clamp(row.stam/row.maximum,0,1)
    end
    fill.Size=UDim2.fromScale(fraction,1)
    fill.BackgroundColor3=row.exhausted==true and colors.red or colors.accent
    rateLabel.Text=rate and string.format("%+.2f/sec",rate) or "collecting..."
    movementLabel.Text="Mode: "..row.mode.."  •  speed "..fmt(row.speed)
    restLabel.Text="Explicit resting signal: "..(row.rest and "ACTIVE" or "not found")
    evidenceLabel.Text="Evidence: "..string.sub(row.restEvidence,1,105)
    recoveryLabel.Text="Stamina: "..(rate==nil and "collecting..." or
        (rate>0.15 and "REGENERATING" or (rate< -0.15 and "DRAINING" or "stable")))..
        "  |  "..(rate and fmt(rate).." per second" or "no rate yet")
    classifierLabel.Text="Rest state: "..row.restClass
    healthLabel.Text="Health: "..fmt(row.health).." / "..fmt(row.healthMax)..
        "  |  rate: "..(row.healthRate and string.format("%+.2f/sec",row.healthRate) or "collecting")
    if row.restClass=="Natural Rest" then
        stateHint.Text="Normal Rest request active. Compare against No Rest / Stationary."
    elseif row.restClass=="Visual-only flag" then
        stateHint.Text="WolfRest without HudRest: likely visual pose, NOT verified regeneration."
    else
        stateHint.Text="Recover below maximum. Stay still without Rest, then use normal Rest."
    end
    progressFill.Size=UDim2.fromScale(math.clamp(row.t/DURATION,0,1),1)
end

local function collect()
    local row=observe()
    local rate=nil
    if previousStamina~=nil and row.stam~=nil and previousTime then
        local dt=row.t-previousTime
        if dt>0 and dt<1.2 then rate=(row.stam-previousStamina)/dt end
    end
    row.rate=rate
    local healthRate=nil
    if lastHealth~=nil and row.health~=nil and lastHealthAt then
        local dt=row.t-lastHealthAt
        if dt>0 and dt<1.2 then healthRate=(row.health-lastHealth)/dt end
    end
    row.healthRate=healthRate
    lastHealth=row.health
    lastHealthAt=row.t
    if row.restClass~=restClassBefore then
        note("REST CATEGORY "..restClassBefore.." -> "..row.restClass..
            " | stamina="..fmt(row.stam).." health="..fmt(row.health)..
            " speed="..fmt(row.speed),true)
        restClassBefore=row.restClass
    end
    if healthRate and math.abs(healthRate)>0.15 then
        healthChangeEvents=healthChangeEvents+1
        if healthChangeEvents<=24 then
            note("HEALTH DELTA "..fmt(healthRate).." per sec | "..row.restClass..
                " | "..row.mode,false)
        end
    end
    captureSignalChanges(row,row.observedSignals or {})
    row.observedSignals=nil
    if #samples<MAX_SAMPLES then table.insert(samples,row) end
    if row.mode~=lastMode then
        note("MODE "..lastMode.." -> "..row.mode.." | stamina="..fmt(row.stam),true)
        lastMode=row.mode
    end
    if row.rest~=lastExplicitRest or
       (row.rest and row.restEvidence~=lastRestSource) then
        note("EXPLICIT REST STATE "..tostring(row.rest)..
            " | "..row.restEvidence.." | movement="..row.mode,true)
        lastExplicitRest=row.rest
    end
    lastRestSource=row.restEvidence
    if row.rest and (row.mode=="Sprint" or row.mode=="Burst") then
        overlapping=overlapping+1
    end
    if rate and rate>0.15 and
        (row.mode=="Sprint" or row.mode=="Burst" or row.mode=="Trot") then
        regenMoving=regenMoving+1
        if regenMoving<=5 then
            note("REGEN WHILE ACTIVE MOVE "..row.mode..
                " | rate="..fmt(rate).." | restFlag="..tostring(row.rest),true)
        end
    end
    previousStamina=row.stam
    previousTime=row.t
    render(row,rate)
end

local function build(full)
    local out={
        "=== FERAL RECOVERY MECHANISM LAB v1.8 ===",
        "Read-only client observations; no attributes, remotes or movement modified",
        "Place ID: "..tostring(game.PlaceId),
        "Duration: "..fmt(#samples>0 and samples[#samples].t or 0).."s",
        "Samples: "..#samples.." / approx "..INTERVAL.."s interval",
        "Explicit rest state + Sprint/Burst overlap samples: "..overlapping,
        "Positive stamina delta during Sprint/Burst/Trot samples: "..regenMoving,
        "Important: regen while moving does not by itself prove a resting mode.",
        "Important: client data does not establish server-side regeneration authority.",
        capped and "WARNING: event log capped" or "",
        watchCapped and "WARNING: object watch cap reached" or "",
        scanCapped and "WARNING: per-root descendant scan cap reached" or "",
        sampleErrors>0 and ("Sampling warnings: "..sampleErrors) or "",
        "",
        "=== PER-MOVEMENT STAMINA AND REGENERATION ==="
    }
    local rates={}
    local order={"Stationary","Walk/unlabelled","Crouch","Trot","Sprint","Burst",
                 "Exhausted movement","Sit","Unknown"}
    for _,mode in ipairs(order) do rates[mode]={time=0,spent=0,gained=0,n=0,rest=0} end
    for i=2,#samples do
        local a,b=samples[i-1],samples[i]
        local dt=b.t-a.t
        if a.mode==b.mode and dt>0 and dt<1.5
           and a.stam~=nil and b.stam~=nil then
            local bucket=rates[b.mode] or {time=0,spent=0,gained=0,n=0,rest=0}
            rates[b.mode]=bucket
            local delta=b.stam-a.stam
            bucket.time=bucket.time+dt
            bucket.n=bucket.n+1
            if delta>0 then bucket.gained=bucket.gained+delta
            else bucket.spent=bucket.spent-delta end
            if a.rest and b.rest then bucket.rest=bucket.rest+dt end
        end
    end
    for _,mode in ipairs(order) do
        local r=rates[mode]
        if r.n>0 then
            table.insert(out,string.format(
                "%s | %.1fs (%d intervals) | gained %.2f / %.2f per sec | spent %.2f / %.2f per sec | explicit-rest %.1fs",
                mode,r.time,r.n,r.gained,
                r.time>0 and r.gained/r.time or 0,
                r.spent,r.time>0 and r.spent/r.time or 0,r.rest))
        end
    end
    profileReport(out)
    table.insert(out,"")
    table.insert(out,"=== REST / RECOVERY KEY INVENTORY (LATEST CLIENT-VISIBLE VALUES) ===")
    local attrNames={}
    for name in pairs(keys) do
        if containsAny(name,REST_KEYS) then table.insert(attrNames,name) end
    end
    table.sort(attrNames)
    if #attrNames==0 then table.insert(out,"No named rest, sleep, idle, recovery or regeneration attributes discovered.") end
    for _,name in ipairs(attrNames) do table.insert(out,name.." = "..keys[name]) end
    table.insert(out,"")
    table.insert(out,"=== REST-NAMED GUI/INSTANCE CANDIDATES (PRESENCE NOT PROOF) ===")
    local paths={}
    for path in pairs(objectCandidates) do table.insert(paths,path) end
    table.sort(paths)
    if #paths==0 then table.insert(out,"No rest-related object names discovered within scan limits.") end
    for _,path in ipairs(paths) do
        table.insert(out,path.." : "..objectCandidates[path])
    end
    table.insert(out,"")
    table.insert(out,"=== PLAYING ANIMATION NAMES SEEN ===")
    local an={}
    for name in pairs(animations) do table.insert(an,name) end
    table.sort(an)
    if #an==0 then table.insert(out,"No playing animation names visible (may be custom animation system).") end
    for _,name in ipairs(an) do table.insert(out,name) end
    table.insert(out,"")
    table.insert(out,"=== RELEVANT TRANSITIONS AND REST EVIDENCE ===")
    for _,entry in ipairs(events) do table.insert(out,entry) end
    if full then
        table.insert(out,"")
        table.insert(out,"=== FULL SAMPLE SERIES ===")
        table.insert(out,"t | restClass | hudRest | wolfRest | mode | stamina | max | regenPerSecond | health | healthMax | healthPerSecond | explicitRest | evidence | sprint | burst | trot | crouch | exhausted | speed | input | humanoidState")
        for _,r in ipairs(samples) do
            table.insert(out,string.format(
                "%.2f | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s",
                r.t,r.restClass,fmt(r.hudRest),fmt(r.wolfRest),
                r.mode,fmt(r.stam),fmt(r.maximum),fmt(r.rate),
                fmt(r.health),fmt(r.healthMax),fmt(r.healthRate),
                tostring(r.rest),string.sub(r.restEvidence,1,72),
                fmt(r.sprint),fmt(r.burst),fmt(r.trot),fmt(r.crouch),
                fmt(r.exhausted),fmt(r.speed),fmt(r.input),r.humanoidState))
        end
    end
    table.insert(out,"")
    table.insert(out,"=== END OF REST REPORT ===")
    return table.concat(out,"\n")
end

local function setStatus(message)
    if gui.Parent then status.Text=message end
end
local function copyContent(value)
    if value=="" then setStatus("Start the scan first.");return end
    local fn=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard or nil)
    if fn then
        local ok=pcall(fn,value)
        if ok then setStatus("Copied report. Paste it into ChatGPT.");return end
    end
    report.Text=value
    report:CaptureFocus()
    setStatus("Clipboard unavailable. Select report text and use Ctrl+A, Ctrl+C.")
end
local function finish()
    if not running then return end
    running=false
    stopped=false
    finalSummary=build(false)
    finalFull=build(true)
    report.Text=finalSummary
    start.Text="Start new scan"
    setStatus("Finished. "..#samples.." samples. Copy summary first; full details if needed.")
end

start.Activated:Connect(function()
    if running then setStatus("Already scanning.");return end
    samples={}
    events={}
    objectCandidates={}
    watched={}
    snapshots={}
    keys={}
    animations={}
    lastRestSource="none"
    previousStamina=nil
    previousTime=nil
    lastMode="Unknown"
    lastExplicitRest=false
    lastAnimSignature=""
    finalSummary=""
    finalFull=""
    capped=false
    watchCapped=false
    scanCapped=false
    overlapping=0
    regenMoving=0
    sampleErrors=0
    signalSnapshots={}
    signalInfo={}
    signalLimited=false
    restClassBefore="Unknown"
    lastHealth=nil
    lastHealthAt=nil
    healthChangeEvents=0
    knownSourceCount=0
    began=os.clock()
    running=true
    stopped=false
    start.Text="Scanning..."
    report.Text="Scanning rest flags, active animations, visible rest objects, and stamina recovery..."
    reindex()
    note("SCAN STARTED",true)
    setStatus("Compare 15s idle, 15s real Rest, then movement. Avoid full stamina for useful rates.")
end)
stop.Activated:Connect(function()
    if running then stopped=true else setStatus("No active scan.") end
end)
copySummary.Activated:Connect(function()
    copyContent(running and build(false) or finalSummary)
end)
copyFull.Activated:Connect(function()
    copyContent(running and build(true) or finalFull)
end)
close.Activated:Connect(function()
    stopped=true
    gui:Destroy()
end)
gui.Destroying:Connect(function()
    running=false
    for _,con in ipairs(connections) do pcall(function() con:Disconnect() end) end
end)

task.spawn(function()
    local count=0
    while gui.Parent do
        if running then
            local ok,errorMessage=pcall(function()
                collect()
                count=count+1
                if count%32==0 then reindex() end
                if count%8==0 then
                    setStatus(string.format("%.1f / %ds • %d samples • %s",
                        elapsed(),DURATION,#samples,lastMode))
                end
                if elapsed()>=DURATION or stopped or #samples>=MAX_SAMPLES then
                    finish()
                end
            end)
            if not ok then
                sampleErrors=sampleErrors+1
                setStatus("Sample warning: "..string.sub(tostring(errorMessage),1,128))
                if sampleErrors>=12 then finish() end
            end
        end
        task.wait(INTERVAL)
    end
end)
