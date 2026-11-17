-- BOOGA REBORN / DAVE FAST BREAK LAB v2.0
-- Uses the game's REAL typed SwingTool API, not mouse autoclicking.
-- Auto-selects the best observed SERVER-REPLICATED HP loss per second.
-- No claims of instant damage, no HP spoofing, no automatic pickups.
-- Stop anytime: F6 or STOP. Rerunning replaces previous instance.
if game.PlaceId ~= 11729688377 then
    warn("[Dave v2] Only for Booga Booga Reborn, PlaceId 11729688377.")
    return
end
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local me=Players.LocalPlayer
if not me then return end
local pg=me:FindFirstChildOfClass("PlayerGui") or me:WaitForChild("PlayerGui",9)
if not pg then return end
local old=pg:FindFirstChild("BoogaDaveFastBreakV20")
if old then
    local shutdown=old:FindFirstChild("Shutdown")
    if shutdown and shutdown:IsA("BindableEvent") then pcall(function()shutdown:Fire()end) end
    if old.Parent then old:Destroy() end
end
local canRun=true
local active=false
local clientPackets=nil
local clock=nil
local gameUtil=nil
local target=nil
local entityId=nil
local currentStage=0
local stageBegin=0
local stageHP=0
local lastObservedHP=0
local stageResults={}
local stages={
    {name="NORMAL-ISH",rate=3,copies=1,seconds=6},
    {name="RAPID",rate=10,copies=1,seconds=6},
    {name="MULTI-HIT CHECK",rate=10,copies=4,seconds=6}
}
local winner=nil
local lastPacketAt=0
local lastHPChangeAt=0
local attackCount=0
local failures=0
local notes="Stand facing Dave with a real equipped axe or pick. START tests server-accepted hit rates."
local lastUI=0
local lastValid=0
local maxDistance=8
local maxPacketRate=10
local startTotal=0
local function create(class,props,parent)
    local object=Instance.new(class)
    for k,v in pairs(props or {}) do object[k]=v end
    if parent then object.Parent=parent end
    return object
end
local function rounded(o,n)
    create("UICorner",{CornerRadius=UDim.new(0,n or 9)},o)
    return o
end
local function text(parent,s,size,col,bold)
    return create("TextLabel",{
        Text=s,TextSize=size,TextColor3=col or Color3.fromRGB(237,247,250),
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
        TextWrapped=true
    },parent)
end
local gui=create("ScreenGui",{
    Name="BoogaDaveFastBreakV20",ResetOnSpawn=false,DisplayOrder=169
},pg)
local shutdown=create("BindableEvent",{Name="Shutdown"},gui)
local bg=rounded(create("Frame",{
    Name="Main",BackgroundColor3=Color3.fromRGB(13,21,32),
    BorderSizePixel=0,Active=true,Size=UDim2.fromOffset(413,327),
    Position=UDim2.fromOffset(28,119)
},gui),14)
create("UIStroke",{Color=Color3.fromRGB(84,223,213),Thickness=1,Transparency=.28},bg)
local heading=text(bg,"DAVE   /   FAST BREAK",19,Color3.fromRGB(92,238,222),true)
heading.Position=UDim2.fromOffset(15,12);heading.Size=UDim2.fromOffset(340,30)
local sub=text(bg,"Direct game packet • verified HP loss • adaptive speed",11,Color3.fromRGB(164,184,198))
sub.Position=UDim2.fromOffset(16,42);sub.Size=UDim2.fromOffset(369,25)
local modeLabel=text(bg,"MODE: IDLE",12,Color3.fromRGB(249,212,130),true)
modeLabel.Position=UDim2.fromOffset(16,82);modeLabel.Size=UDim2.fromOffset(376,28)
local hpLabel=text(bg,"DAVE HP: --",16,nil,true)
hpLabel.Position=UDim2.fromOffset(16,111);hpLabel.Size=UDim2.fromOffset(380,29)
local rateLabel=text(bg,"HP loss: -- per second",12)
rateLabel.Position=UDim2.fromOffset(16,144);rateLabel.Size=UDim2.fromOffset(380,29)
local verdict=text(bg,"Tests have not run yet.",11,Color3.fromRGB(176,193,208))
verdict.Position=UDim2.fromOffset(16,179);verdict.Size=UDim2.fromOffset(380,55)
local detail=text(bg,notes,11,Color3.fromRGB(165,186,198))
detail.Position=UDim2.fromOffset(16,239);detail.Size=UDim2.fromOffset(380,38)
local function button(s,x,y,w,callback,colour)
    local b=rounded(create("TextButton",{
        BackgroundColor3=colour or Color3.fromRGB(30,50,66),
        BorderSizePixel=0,Text=s,TextSize=12,Font=Enum.Font.GothamBold,
        TextColor3=Color3.fromRGB(237,249,253),
        Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,31)
    },bg),7)
    b.Activated:Connect(callback)
    return b
end
local function ownRoot()
    local char=me.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    return root and hum and hum.Health>0 and root or nil
end
local function getDave()
    local folder=workspace:FindFirstChild("Resources")
    local root=ownRoot()
    if not folder or not root then return nil end
    local closest,best=nil,math.huge
    for _,d in ipairs(folder:GetChildren()) do
        if d:IsA("Model") and d.Name=="Dave" then
            local hp=d:FindFirstChild("Health")
            local part=d.PrimaryPart or d:FindFirstChild("Stump")
                or d:FindFirstChildWhichIsA("BasePart")
            if hp and hp:IsA("ValueBase") and type(hp.Value)=="number"
                and hp.Value>0 and part then
                local distance=(root.Position-part.Position).Magnitude
                if distance<best then closest,best=d,distance end
            end
        end
    end
    return closest
end
local function hpOf(d)
    local h=d and d:FindFirstChild("Health")
    return h and h:IsA("ValueBase") and type(h.Value)=="number"
        and h.Value or nil
end
local function verifyPosition()
    local root=ownRoot()
    local part=target and (target.PrimaryPart or target:FindFirstChild("Stump")
        or target:FindFirstChildWhichIsA("BasePart"))
    if not root or not part or not target.Parent then return false,"Character or Dave missing." end
    local delta=part.Position-root.Position
    local distance=delta.Magnitude
    if distance>maxDistance then return false,"Too far from Dave; approach within 8 studs." end
    local flat=Vector3.new(delta.X,0,delta.Z)
    local front=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
    if flat.Magnitude>1 and front.Magnitude>.01 and
        flat.Unit:Dot(front.Unit)<.25 then
        return false,"Turn your character to face Dave." end
    return true
end
local function nativeGameModules()
    local modules=RS:FindFirstChild("Modules")
    local util=modules and modules:FindFirstChild("util")
    local packetsModule=util and util:FindFirstChild("packets")
    local clockModule=util and util:FindFirstChild("clock")
    local utilModule=util and util:FindFirstChild("gameUtil")
    if not (packetsModule and clockModule and utilModule) then
        return nil,nil,nil,"Required Booga Modules/util modules are absent."
    end
    local okP,packets=pcall(require,packetsModule)
    local okC,clockValue=pcall(require,clockModule)
    local okG,gameUtils=pcall(require,utilModule)
    if not okP or type(packets)~="table" or
        not packets.SwingTool or type(packets.SwingTool.send)~="function" then
        return nil,nil,nil,"Typed SwingTool client packet is unavailable."
    end
    if not okC or type(clockValue)~="table"
        or type(clockValue.getServerTime)~="function" then
        return nil,nil,nil,"Game clock could not be read."
    end
    if not okG or type(gameUtils)~="table" then
        return nil,nil,nil,"Game equipment data unavailable."
    end
    return packets,clockValue,gameUtils
end
local function equippedName()
    if not gameUtil or type(gameUtil.Data)~="table" then return nil end
    local d=gameUtil.Data
    local slot=d.equipped
    local entry=type(d.toolbar)=="table" and d.toolbar[slot]
    return type(entry)=="table" and entry.name or nil
end
local function stop(reason)
    active=false
    if reason then notes=reason end
end
local function finishStage(now)
    local stage=stages[currentStage]
    local hp=hpOf(target)
    if not stage or not hp then
        stop("Dave lost; the current test ended.");return
    end
    local loss=math.max(0,stageHP-hp)
    local dps=loss/math.max(.1,now-stageBegin)
    stageResults[#stageResults+1]={
        name=stage.name,rate=stage.rate,copies=stage.copies,dps=dps,loss=loss
    }
    if currentStage<#stages then
        currentStage+=1
        stageBegin=now;stageHP=hp
        lastPacketAt=now
        notes=stage.name.." accepted HP loss "..math.floor(loss)
            ..". Next: "..stages[currentStage].name
        return
    end
    local baseline=stageResults[1].dps
    local best=stageResults[1]
    for _,result in ipairs(stageResults) do
        if result.dps>best.dps then best=result end
    end
    if best.loss<=0 then
        stop("STOPPED: Dave's replicated HP did not decrease. No accepted damage proven.")
        return
    end
    if best~=stageResults[1] and best.dps>=baseline*1.5 then
        winner=best
        notes=string.format("FAST MODE: %.0f HP/s (%.1fx baseline). Using measured best rate.",
            best.dps,baseline>0 and best.dps/baseline or 0)
    else
        winner=nil
        stop("NO FAST BREAK FOUND: extra packet rate/duplicates didn't beat normal damage. No fake exploit enabled.")
    end
end
local function begin()
    if active then return end
    local d=getDave()
    if not d then
        notes="No alive Dave replicated near you. Move to Dave first."
        return
    end
    target=d
    local allowed,why=verifyPosition()
    if not allowed then notes=why;return end
    clientPackets,clock,gameUtil,why=nativeGameModules()
    if not clientPackets then notes=why;return end
    local tool=equippedName()
    if not tool then
        notes="Equip an actual attack tool first. Game toolbar has no equipped tool."
        return
    end
    local health=hpOf(d)
    local id=d:GetAttribute("EntityID")
    if type(id)~="number" or not health then
        notes="Dave lacks readable EntityID or Health; cannot send valid client attack."
        return
    end
    entityId=id
    lastObservedHP=health;lastHPChangeAt=os.clock()
    stageResults={};currentStage=1;winner=nil;failures=0
    attackCount=0;stageBegin=os.clock();stageHP=health;lastPacketAt=0
    active=true
    startTotal=stageBegin
    notes="Testing real server-observed HP loss: 3/s, then 10/s, then 4× batched."
end
local startButton=button("START FAST BREAK",15,284,174,begin,Color3.fromRGB(22,106,103))
local stopButton=button("STOP  /  F6",201,284,132,function()
    stop("Stopped by user.")
end,Color3.fromRGB(126,54,62))
local closeButton=button("×",366,13,29,function()
    stop("Closed.")
    canRun=false
    gui:Destroy()
end)
local events={}
events[#events+1]=UIS.InputBegan:Connect(function(key)
    if key.KeyCode==Enum.KeyCode.F6 then stop("F6 • stopped.")end
end)
shutdown.Event:Connect(function()
    stop("Replaced.")
    canRun=false
    for _,e in ipairs(events) do pcall(function()e:Disconnect()end)end
    if gui.Parent then gui:Destroy()end
end)
events[#events+1]=RunService.Heartbeat:Connect(function()
    if not canRun then return end
    local now=os.clock()
    if active then
        if UIS:GetFocusedTextBox() then
            stop("Text/chat focused; stopped. Re-select START to resume.")
        else
            local okPosition,why=verifyPosition()
            if not okPosition then stop(why) end
        end
        local hp=hpOf(target)
        if active and (not hp or hp<=0 or not target.Parent) then
            stop("Dave disappeared/reached zero. Check actual Pie drops.")
        elseif active then
            if hp<lastObservedHP then lastHPChangeAt=now end
            lastObservedHP=hp
            if now-lastHPChangeAt>22 then
                stop("No observed HP loss for 22 seconds. Server is rejecting/ignoring attacks.")
            elseif not winner and now-stageBegin>=stages[currentStage].seconds then
                finishStage(now)
            end
        end
        if active then
            local stage=winner or stages[currentStage]
            local interval=1/math.min(stage.rate,maxPacketRate)
            if now-lastPacketAt>=interval then
                lastPacketAt=now
                local ids=table.create(stage.copies)
                for i=1,stage.copies do ids[i]=entityId end
                local char=me.Character
                local sent,err=pcall(function()
                    clientPackets.SwingTool.send({
                        entityIDs=ids,cframe=char:GetPivot(),
                        timestamp=clock.getServerTime(true)
                    })
                end)
                if sent then attackCount+=1 else
                    failures+=1
                    if failures>=3 then
                        stop("Game rejected the typed attack request: "..tostring(err):sub(1,80))
                    end
                end
            end
        end
    end
    if now-lastUI>.24 then
        lastUI=now
        local health=hpOf(target or getDave())
        hpLabel.Text=health and ("DAVE HP: "..string.format("%.0f",health))
            or "DAVE HP: --"
        if active then
            local stage=winner or stages[currentStage]
            modeLabel.Text="MODE: "..(winner and "ACTIVE BOOST" or "LIVE COMPARISON")
                .."   /   "..stage.name
            local seen=stageHP and health and math.max(0,stageHP-health) or 0
            local seconds=now-stageBegin
            local dps=winner and winner.dps
                or seen/math.max(1,seconds)
            rateLabel.Text=string.format("Observed HP loss: %.1f/s  •  Requests: %d",
                dps,attackCount)
        else
            modeLabel.Text="MODE: STOPPED / READY"
            rateLabel.Text="Requests: "..attackCount
        end
        if #stageResults>0 then
            local names={}
            for _,result in ipairs(stageResults) do
                names[#names+1]=string.format("%s %.0f/s",result.name,result.dps)
            end
            verdict.Text=table.concat(names,"    ")
        else verdict.Text="Measures real replicated Dave Health; no fabricated hits."end
        detail.Text=notes
    end
end)
warn("[Dave Fast v2] Uses genuine typed game attack requests. Test results determine whether server permits acceleration.")
