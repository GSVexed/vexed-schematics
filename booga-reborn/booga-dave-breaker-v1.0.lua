-- BOOGA REBORN / DAVE BREAKER v1.0
-- Real native swing automation. No forged packets, no local HP writes.
-- PlaceId 11729688377. F6 stops, re-running cleans up previous copy.
local PLACE=11729688377
if game.PlaceId~=PLACE then warn("[DAVE] Open Booga Booga Reborn first.");return end
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
if not player then return end
local guiParent=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",8)
if not guiParent then return end
local previous=guiParent:FindFirstChild("BoogaDaveBreakerV1")
if previous then
    local stop=previous:FindFirstChild("DaveShutdown")
    if stop and stop:IsA("BindableEvent") then pcall(function()stop:Fire()end) end
    if previous.Parent then previous:Destroy() end
end

local alive=true
local running=false
local target=nil
local baseline=nil
local initialHP=nil
local lastHP=nil
local attackBackend=nil
local inputHeld=false
local startedAt=0
local nextActionAt=0
local damageLog={}
local totalDamage=0
local lastDamageAt=0
local status="READY • Stand close, face Dave and equip a suitable axe."
local mode="HOLD"
local lastError=nil
local conn={}
local savedSetting=nil
local savedSettingTable=nil
local MAX_DISTANCE=10
local CYAN=Color3.fromRGB(85,231,216)
local BG=Color3.fromRGB(13,22,34)
local PANEL=Color3.fromRGB(24,37,53)
local MUTE=Color3.fromRGB(160,186,204)
local AMBER=Color3.fromRGB(255,206,116)
local RED=Color3.fromRGB(245,113,119)
local function inst(class,properties,parent)
    local obj=Instance.new(class)
    for k,v in pairs(properties or {}) do obj[k]=v end
    if parent then obj.Parent=parent end
    return obj
end
local function rounded(obj,n)
    inst("UICorner",{CornerRadius=UDim.new(0,n or 9)},obj)
    return obj
end
local function text(parent,value,size,color,bold)
    return inst("TextLabel",{
        BackgroundTransparency=1,Text=value or "",
        TextColor3=color or Color3.fromRGB(231,244,251),
        TextSize=size or 12,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Center
    },parent)
end
local function button(parent,value,x,y,w,h,fn)
    local b=rounded(inst("TextButton",{
        BackgroundColor3=PANEL,BorderSizePixel=0,
        TextColor3=Color3.fromRGB(240,249,255),
        Font=Enum.Font.GothamBold,TextSize=12,Text=value,
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h)
    },parent),9)
    b.Activated:Connect(fn)
    return b
end
local screen=inst("ScreenGui",{
    Name="BoogaDaveBreakerV1",DisplayOrder=160,ResetOnSpawn=false
},guiParent)
local shutdown=inst("BindableEvent",{Name="DaveShutdown"},screen)
local panel=rounded(inst("Frame",{
    BackgroundColor3=BG,BorderSizePixel=0,Active=true,
    Position=UDim2.fromOffset(22,120),Size=UDim2.fromOffset(392,330)
},screen),14)
inst("UIStroke",{Color=CYAN,Thickness=1,Transparency=.36},panel)
local title=text(panel,"DAVE  /  BREAKER",19,CYAN,true)
title.Position=UDim2.fromOffset(17,10)
title.Size=UDim2.fromOffset(340,35)
local subtitle=text(panel,"Real swings • replicated HP • safe auto-stop",11,MUTE)
subtitle.Position=UDim2.fromOffset(18,44)
subtitle.Size=UDim2.fromOffset(356,24)
local targetText=text(panel,"DAVE: searching...",13,AMBER,true)
targetText.Position=UDim2.fromOffset(18,80)
targetText.Size=UDim2.fromOffset(354,28)
local hpText=text(panel,"HP: --",15)
hpText.Position=UDim2.fromOffset(18,111)
hpText.Size=UDim2.fromOffset(354,30)
local progressBackground=rounded(inst("Frame",{
    BackgroundColor3=PANEL,BorderSizePixel=0,
    Position=UDim2.fromOffset(18,146),
    Size=UDim2.fromOffset(355,9)
},panel),5)
local progressFill=rounded(inst("Frame",{
    BackgroundColor3=CYAN,BorderSizePixel=0,
    Size=UDim2.fromScale(1,1)
},progressBackground),5)
local rateText=text(panel,"Accepted HP loss: -- / sec",12,MUTE)
rateText.Position=UDim2.fromOffset(18,166)
rateText.Size=UDim2.fromOffset(358,27)
local statusText=text(panel,status,11,AMBER)
statusText.Position=UDim2.fromOffset(18,199)
statusText.Size=UDim2.fromOffset(358,50)
local modeButton
local function stateMessage(message)status=message end
local function closestDave()
    local folder=workspace:FindFirstChild("Resources")
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local nearest=nil
    local best=math.huge
    local count=0
    if not folder then return nil,0,math.huge end
    for _,model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") and model.Name=="Dave" then
            local hp=model:FindFirstChild("Health")
            local part=model.PrimaryPart or model:FindFirstChild("Stump")
                or model:FindFirstChildWhichIsA("BasePart")
            if hp and hp:IsA("ValueBase") and type(hp.Value)=="number"
                and part then
                count+=1
                local distance=root and (root.Position-part.Position).Magnitude
                    or math.huge
                if distance<best then best=distance;nearest=model end
            end
        end
    end
    return nearest,count,best
end
local function healthOf(model)
    local h=model and model:FindFirstChild("Health")
    return h and h:IsA("ValueBase") and type(h.Value)=="number" and h.Value
        or nil
end
local function rootPart()
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not root or not hum or hum.Health<=0 then return nil end
    return root
end
local function distanceTo(model)
    local root=rootPart()
    local part=model and (model.PrimaryPart or model:FindFirstChild("Stump")
        or model:FindFirstChildWhichIsA("BasePart"))
    return root and part and (root.Position-part.Position).Magnitude
        or math.huge
end
local function resolveInputs()
    local env=nil
    if type(getgenv)=="function" then
        local ok,result=pcall(getgenv)
        if ok and type(result)=="table" then env=result end
    end
    local press=type(mouse1press)=="function" and mouse1press
        or env and type(env.mouse1press)=="function" and env.mouse1press
    local release=type(mouse1release)=="function" and mouse1release
        or env and type(env.mouse1release)=="function" and env.mouse1release
    local options={}
    if press and release then
        options[#options+1]={
            name="Velocity mouse input",
            down=function()press()end,
            up=function()release()end
        }
    end
    local ok,vim=pcall(function()return game:GetService("VirtualInputManager")end)
    if ok and vim then
        local function mouse(down)
            local cam=workspace.CurrentCamera
            local v=cam and cam.ViewportSize or Vector2.new(1280,720)
            vim:SendMouseButtonEvent(math.floor(v.X/2),math.floor(v.Y/2),
                0,down,game,0)
        end
        options[#options+1]={
            name="VirtualInputManager",
            down=function()mouse(true)end,
            up=function()mouse(false)end
        }
    end
    return options
end
local inputOptions=resolveInputs()
local function releaseInput()
    if inputHeld and attackBackend then
        pcall(attackBackend.up)
    end
    inputHeld=false
end
local function restoreHoldSetting()
    if savedSettingTable and savedSetting~=nil then
        pcall(function()
            if savedSettingTable.holdToSwing==true then
                savedSettingTable.holdToSwing=savedSetting
            end
        end)
    end
    savedSettingTable=nil
    savedSetting=nil
end
local function setNativeHold()
    local modules=ReplicatedStorage:FindFirstChild("Modules")
    local util=modules and modules:FindFirstChild("util")
    local gameUtil=util and util:FindFirstChild("gameUtil")
    if not gameUtil or not gameUtil:IsA("ModuleScript") then return false end
    local ok,ref=pcall(require,gameUtil)
    if not ok or type(ref)~="table" then return false end
    local settings=ref.Data and ref.Data.userSettings
    if type(settings)~="table" then return false end
    savedSettingTable=settings
    savedSetting=settings.holdToSwing
    settings.holdToSwing=true
    return settings.holdToSwing==true
end
local function stop(reason)
    running=false
    releaseInput()
    restoreHoldSetting()
    panel.Visible=true
    if reason then stateMessage(reason) end
end
local mini=rounded(inst("Frame",{
    BackgroundColor3=BG,BorderSizePixel=0,
    Size=UDim2.fromOffset(302,103),
    Position=UDim2.fromOffset(20,120),Visible=false
},screen),11)
inst("UIStroke",{Color=CYAN,Thickness=1,Transparency=.3},mini)
local miniHP=text(mini,"Dave HP: --",13,CYAN,true)
miniHP.Position=UDim2.fromOffset(12,8)
miniHP.Size=UDim2.fromOffset(276,27)
local miniMsg=text(mini,"ATTACKING • F6 TO STOP",11,AMBER)
miniMsg.Position=UDim2.fromOffset(12,37)
miniMsg.Size=UDim2.fromOffset(278,25)
local miniStop=button(mini,"STOP  [F6]",10,66,280,29,function()
    stop("Stopped manually; input released.")
end)
miniStop.BackgroundColor3=Color3.fromRGB(120,40,52)
local function draw()
    mini.Visible=running
    local model,count,distance=closestDave()
    if running then model=target;distance=distanceTo(target) end
    local hp=healthOf(model)
    targetText.Text=model and ("DAVE DETECTED • "..count.." streamed • "..math.floor(distance).." studs")
        or "NO DAVE STREAMED • Move towards Dave"
    hpText.Text=hp and ("HEALTH  "..string.format("%.0f",hp)) or "HEALTH  --"
    local progress=(hp and initialHP and initialHP>0)
        and math.clamp(hp/initialHP,0,1) or 1
    progressFill.Size=UDim2.fromScale(progress,1)
    local now=os.clock()
    while #damageLog>0 and now-damageLog[1].time>25 do
        table.remove(damageLog,1)
    end
    local loss=0
    for _,hit in ipairs(damageLog) do loss+=hit.amount end
    local duration=#damageLog>0 and math.min(25,now-startedAt) or 0
    local dps=duration>1 and loss/duration or 0
    rateText.Text=string.format("Observed HP loss: %.1f/s   •   ETA: %s",
        dps,dps>0 and string.format("%.1f hrs",hp/dps/3600) or "--")
    statusText.Text=status
    miniHP.Text=hp and string.format("DAVE HP: %.0f",hp) or "DAVE: UNAVAILABLE"
    miniMsg.Text=running and (dps>0 and
        string.format("LIVE: %.1f HP/s  •  F6 STOP",dps) or
        "ATTACKING • F6 TO STOP") or "STOPPED"
end
local function beginAttack()
    if running then return end
    local candidate,count,distance=closestDave()
    if not candidate then
        stateMessage("Cannot start: no replicated Dave nearby. Move to Dave.");draw();return
    end
    if distance>MAX_DISTANCE then
        stateMessage("Move within 10 studs and face the stump; currently "..
            math.floor(distance).." studs away.")
        draw();return
    end
    local hp=healthOf(candidate)
    if not hp or hp<=0 then
        stateMessage("Dave is already broken or its Health isn't readable.")
        draw();return
    end
    local actual=nil
    for _,backend in ipairs(inputOptions) do
        -- Validate release first; don't synthesize an attack until UI is hidden.
        if pcall(backend.up) then actual=backend;break end
    end
    if not actual then
        stateMessage("No working mouse input API. Enable Booga's Hold to Swing and hold left-click manually.")
        draw();return
    end
    target=candidate
    baseline=hp;initialHP=hp;lastHP=hp
    damageLog={};totalDamage=0
    startedAt=os.clock()
    lastDamageAt=startedAt
    attackBackend=actual
    running=true
    nextActionAt=startedAt+1.4
    if mode=="HOLD" then setNativeHold() end
    stateMessage("STARTING: move your cursor off the menu. Stay facing Dave.")
    panel.Visible=false
    mini.Visible=true
    draw()
end
local startButton=button(panel,"START BREAKING",18,268,174,38,beginAttack)
startButton.BackgroundColor3=Color3.fromRGB(27,115,108)
modeButton=button(panel,"MODE: NATIVE HOLD",203,268,170,38,function()
    if running then return end
    mode=mode=="HOLD" and "TAP" or "HOLD"
    modeButton.Text=mode=="HOLD" and "MODE: NATIVE HOLD" or "MODE: AUTO TAP"
    stateMessage(mode=="HOLD" and "Uses native Hold to Swing (preferred)."
        or "Taps at normal 0.36-second intervals; no remote flooding.")
    draw()
end)
local close=button(panel,"×",347,12,28,27,function()
    stop("Closed; input released.")
    alive=false
    for _,c in ipairs(conn) do pcall(function()c:Disconnect()end) end
    screen:Destroy()
end)
local function attackStep(now)
    if not running then return end
    if UserInputService:GetFocusedTextBox() then
        stop("Paused: text box/chat opened. Click START to resume.")
        return
    end
    local currentHP=healthOf(target)
    if not target or not target.Parent or not currentHP or currentHP<=0 then
        stop("Dave disappeared or reached zero HP. Check for Pie drops.")
        return
    end
    local distance=distanceTo(target)
    if distance>MAX_DISTANCE then
        stop("Stopped: moved outside Dave's 10-stud attack zone.")
        return
    end
    if currentHP<lastHP then
        local damage=lastHP-currentHP
        totalDamage+=damage
        lastDamageAt=now
        damageLog[#damageLog+1]={time=now,amount=damage}
    end
    lastHP=currentHP
    if now-startedAt>22 and lastDamageAt==startedAt then
        stop("No server-observed HP loss after 22 seconds. Face Dave, stand closer or change your tool/mode.")
        return
    end
    if now<nextActionAt then return end
    if mode=="HOLD" then
        if not inputHeld then
            local ok=pcall(attackBackend.down)
            if not ok then
                stop("Mouse HOLD rejected by executor. Try AUTO TAP mode.")
                return
            end
            inputHeld=true
        end
        nextActionAt=now+.5
    else
        if inputHeld then
            releaseInput()
            nextActionAt=now+.31
        else
            local ok=pcall(attackBackend.down)
            if not ok then
                stop("Mouse TAP rejected by executor. Try NATIVE HOLD.")
                return
            end
            inputHeld=true
            nextActionAt=now+.055
        end
    end
end
conn[#conn+1]=RunService.Heartbeat:Connect(function()
    if not alive then return end
    local ok,result=pcall(attackStep,os.clock())
    if not ok and running then stop("Stopped after a local input error.") end
end)
local lastUI=0
conn[#conn+1]=RunService.Heartbeat:Connect(function()
    local now=os.clock()
    if not alive or now-lastUI<.25 then return end
    lastUI=now
    pcall(draw)
end)
conn[#conn+1]=UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.F6 then
        stop("F6 stop • native input released.")
    end
end)
shutdown.Event:Connect(function()
    stop("Replaced by new Dave Breaker instance.")
    alive=false
    for _,c in ipairs(conn) do pcall(function()c:Disconnect()end) end
    if screen.Parent then screen:Destroy() end
end)
draw()
warn("[DAVE] Ready. Equip your best axe, stand ~3-5 studs facing Dave, press START.")
