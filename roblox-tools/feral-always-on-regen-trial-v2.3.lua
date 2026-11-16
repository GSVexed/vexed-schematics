-- FERAL Always-on Regeneration Trial v2.3
-- Experimental LOCAL-only stamina/health writes for comparison.
-- This does NOT activate hidden server regeneration or bypass server validation.
-- No RemoteEvent calls, hooks, anti-cheat modifications, or movement changes.
-- Based on observations in FERAL v2.1: Character Stamina/StaminaMax
-- attributes and Humanoid Health/MaxHealth are the locally visible resources.

local Players=game:GetService("Players")
local player=Players.LocalPlayer
local expectedPlaceId=108901361810209

if game.PlaceId~=expectedPlaceId then
    warn("[FERAL v2.3] Wrong PlaceId: "..tostring(game.PlaceId))
    return
end

local guiParent=player:WaitForChild("PlayerGui")
local guiName="FeralAlwaysRegenTrialV23"
-- Replace the previous test panel/loop so only this version applies regeneration.
local previous=guiParent:FindFirstChild("FeralAlwaysRegenTrialV22")
if previous then previous:Destroy() end
local existing=guiParent:FindFirstChild(guiName)
if existing then existing:Destroy() end

local enabled=true
local staminaOn=true
local healthOn=true
local loopActive=true
local STAMINA_PER_SECOND=5
local HEALTH_PER_SECOND=4
local INTERVAL=0.12
local totalSeconds=0
local onSeconds=0
local totalLocalStamRequested=0
local totalLocalHealthRequested=0
local staminaWrites=0
local healthWrites=0
local staminaReadbacks=0
local healthReadbacks=0
local staminaDrops=0
local healthDrops=0
local errors=0
local lastChar=nil
local lastPreStam=nil
local lastPreHealth=nil
local lastState=nil
local lastMode=nil
local aggregates={}
local firstStam=nil
local firstHealth=nil
local lastSeenStam=nil
local lastSeenHealth=nil
local recentMessage="Starting"

local function formatNum(n)
    return type(n)=="number" and string.format("%.2f",n) or "-"
end
local function getMode(char)
    if char:GetAttribute("WolfBurst")==true or player:GetAttribute("HudBurst")==true then
        return "Burst"
    end
    if player:GetAttribute("HudSprint")==true then return "Sprint" end
    return "Non-sprint"
end
local function bucket(kind,mode)
    local key=kind.." / "..mode
    if not aggregates[key] then
        aggregates[key]={time=0,sChange=0,hChange=0,sPositive=0,sNegative=0,
            hPositive=0,hNegative=0,samples=0}
    end
    return aggregates[key]
end
local function aggregate(prev,current,dt,kind,mode)
    if prev==nil or current==nil or dt<=0 or dt>0.5 then return end
    local delta=current-prev
    if kind=="stamina" then
        mode.sChange=mode.sChange+delta
        if delta>=0 then mode.sPositive=mode.sPositive+delta
        else mode.sNegative=mode.sNegative-delta end
    else
        mode.hChange=mode.hChange+delta
        if delta>=0 then mode.hPositive=mode.hPositive+delta
        else mode.hNegative=mode.hNegative-delta end
    end
end

local colors={
    bg=Color3.fromRGB(20,28,39),
    surface=Color3.fromRGB(31,44,60),
    text=Color3.fromRGB(243,247,253),
    muted=Color3.fromRGB(175,194,211),
    green=Color3.fromRGB(46,186,132),
    blue=Color3.fromRGB(62,126,212),
    red=Color3.fromRGB(192,81,96)
}
local function make(kind,props,parent)
    local inst=Instance.new(kind)
    for k,v in pairs(props) do inst[k]=v end
    inst.Parent=parent
    return inst
end
local function round(obj,r)
    make("UICorner",{CornerRadius=UDim.new(0,r)},obj)
end
local gui=make("ScreenGui",{
    Name=guiName,ResetOnSpawn=false,DisplayOrder=390,IgnoreGuiInset=true
},guiParent)
local panel=make("Frame",{
    Name="Panel",AnchorPoint=Vector2.new(0.5,0),
    Position=UDim2.fromScale(0.5,0.12),Size=UDim2.fromOffset(450,324),
    BackgroundColor3=colors.bg,BorderSizePixel=0,Active=true
},gui)
round(panel,12)
make("UIStroke",{Color=Color3.fromRGB(64,83,108),Thickness=1},panel)

local cam=workspace.CurrentCamera
if cam then
    local vp=cam.ViewportSize
    make("UIScale",{Scale=math.clamp(math.min(vp.X/485,vp.Y/385),0.65,1)},panel)
end

local function label(name,content,x,y,w,h,fontSize,color,bold)
    return make("TextLabel",{
        Name=name,Text=content,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextColor3=color or colors.text,TextSize=fontSize,
        TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center
    },panel)
end
local function button(name,content,x,y,w,h,color)
    local obj=make("TextButton",{
        Name=name,Text=content,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h),BackgroundColor3=color,
        BorderSizePixel=0,Font=Enum.Font.GothamBold,
        TextColor3=colors.text,TextSize=12
    },panel)
    round(obj,8)
    return obj
end

local title=label("Title","FERAL  /  ALWAYS-ON REGEN TRIAL",13,8,365,27,15,colors.text,true)
local subtitle=label("Subtitle","v2.3 • +5 stamina/s +4 HP/s • server effects unverified",13,33,415,18,10,colors.muted,false)
local close=button("Close","X",419,10,22,25,colors.red)
local status=label("Status","Enabled. Testing stamina + health together.",14,60,422,22,12,colors.green,true)
local staminaLabel=label("Stamina","Stamina: waiting for character...",14,91,420,22,13,colors.text,true)
local healthLabel=label("Health","Health: waiting for character...",14,118,420,22,13,colors.text,true)
local rates=label("Rates","+5 stamina/sec  •  +4 health/sec when below max",
    14,147,420,22,11,colors.muted,false)
local enableButton=button("Enable","STOP TRIAL",14,183,132,38,colors.red)
local staminaButton=button("Stamina","Stamina: ON",156,183,129,38,colors.green)
local healthButton=button("Health","Health: ON",295,183,141,38,colors.green)
local copyButton=button("Copy","COPY TEST REPORT",14,233,422,32,colors.blue)
local message=label("Message","Compare sprint and burst with the trial ON, then OFF. Watch real stamina usage.",
    14,271,420,28,10,colors.muted,false)
local caution=label("Caution","Local changes do not prove the server accepts either effect.",
    14,299,420,17,10,colors.muted,false)

-- The panel is draggable by its header; no game input is intercepted.
local UIS=game:GetService("UserInputService")
local dragging=false
local dragStart=nil
local panelStart=nil
title.Active=true
title.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1
        or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true
        dragStart=input.Position
        panelStart=panel.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and dragStart and panelStart and
        (input.UserInputType==Enum.UserInputType.MouseMovement or
         input.UserInputType==Enum.UserInputType.Touch) then
        local d=input.Position-dragStart
        panel.Position=UDim2.new(panelStart.X.Scale,panelStart.X.Offset+d.X,
            panelStart.Y.Scale,panelStart.Y.Offset+d.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or
        input.UserInputType==Enum.UserInputType.Touch then
        dragging=false
    end
end)

local function updateControls()
    enableButton.Text=enabled and "STOP TRIAL" or "START TRIAL"
    enableButton.BackgroundColor3=enabled and colors.red or colors.green
    staminaButton.Text=staminaOn and "Stamina: ON" or "Stamina: OFF"
    staminaButton.BackgroundColor3=staminaOn and colors.green or colors.red
    healthButton.Text=healthOn and "Health: ON" or "Health: OFF"
    healthButton.BackgroundColor3=healthOn and colors.green or colors.red
end
enableButton.Activated:Connect(function()
    enabled=not enabled
    recentMessage=enabled and "Trial resumed" or "Trial paused; prior local additions not undone"
    updateControls()
end)
staminaButton.Activated:Connect(function()
    staminaOn=not staminaOn
    updateControls()
end)
healthButton.Activated:Connect(function()
    healthOn=not healthOn
    updateControls()
end)

local function report()
    local out={
        "=== FERAL ALWAYS-ON REGEN TRIAL v2.3 ===",
        "PlaceId: "..tostring(game.PlaceId),
        "Local trial currently: "..(enabled and "ON" or "OFF"),
        "Stamina switch: "..tostring(staminaOn).." | Health switch: "..tostring(healthOn),
        "Intended local rates: +5 stamina/sec and +4 health/sec",
        "Elapsed: "..formatNum(totalSeconds).."s; trial enabled: "..formatNum(onSeconds).."s",
        "Local stamina added (attempted): "..formatNum(totalLocalStamRequested),
        "Local health added (attempted): "..formatNum(totalLocalHealthRequested),
        "Stamina writes/readbacks: "..staminaWrites.."/"..staminaReadbacks,
        "Health writes/readbacks: "..healthWrites.."/"..healthReadbacks,
        "Observed stamina decreases before next write: "..staminaDrops,
        "Observed health decreases before next write: "..healthDrops,
        "Write or sample errors: "..errors,
        "First observed stamina/health: "..formatNum(firstStam).." / "..formatNum(firstHealth),
        "Latest observed stamina/health: "..formatNum(lastSeenStam).." / "..formatNum(lastSeenHealth),
        "Last status: "..recentMessage,
        "",
        "=== OBSERVED PRE-WRITE VALUE CHANGES BY MOVEMENT ===",
        "Positive and negative deltas combine gameplay changes and prior LOCAL writes.",
        "They DO NOT confirm server-recognised stamina or healing.",
    }
    for _,kind in ipairs({"Trial ON","Trial OFF"}) do
        for _,mode in ipairs({"Non-sprint","Sprint","Burst"}) do
            local key=kind.." / "..mode
            local b=aggregates[key]
            if b and b.time>0 then
                table.insert(out,string.format(
                    "%s | %.1fs / %d intervals | stamina net %+.2f (up %.2f/down %.2f) | health net %+.2f (up %.2f/down %.2f)",
                    key,b.time,b.samples,b.sChange,b.sPositive,b.sNegative,
                    b.hChange,b.hPositive,b.hNegative))
            else
                table.insert(out,key.." | no comparable intervals")
            end
        end
    end
    table.insert(out,"")
    table.insert(out,"=== LIMITS ===")
    table.insert(out,"This script writes Character Stamina attribute and Humanoid.Health locally only.")
    table.insert(out,"No FireServer/InvokeServer, remote hooks or anti-cheat bypasses are used.")
    table.insert(out,"Local readback may display increased values even if the server refuses them.")
    table.insert(out,"Compare whether sprint/burst actually lasts longer, not just what the GUI displays.")
    table.insert(out,"For server-authoritative effects, changes must be supported by the game server.")
    table.insert(out,"=== END ===")
    return table.concat(out,"\n")
end
copyButton.Activated:Connect(function()
    local content=report()
    local setter=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard or nil)
    if setter then
        local ok=pcall(setter,content)
        if ok then
            recentMessage="Copied report. Paste into ChatGPT."
            message.Text=recentMessage
            return
        end
    end
    recentMessage="Clipboard unavailable. Print report to executor console."
    warn(content)
    message.Text=recentMessage
end)

close.Activated:Connect(function()
    loopActive=false
    gui:Destroy()
end)
gui.Destroying:Connect(function() loopActive=false end)
updateControls()

task.spawn(function()
    local lastTick=os.clock()
    while loopActive and gui.Parent do
        local now=os.clock()
        local dt=math.clamp(now-lastTick,0,0.35)
        lastTick=now
        local ok,err=pcall(function()
            totalSeconds=totalSeconds+dt
            local char=player.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            if not char or not char.Parent or not hum or hum.Health<=0 then
                lastChar=nil
                lastPreStam=nil
                lastPreHealth=nil
                lastState=nil
                lastMode=nil
                status.Text="Waiting for a living character..."
                status.TextColor3=colors.muted
                return
            end
            if lastChar~=char then
                lastChar=char
                lastPreStam=nil
                lastPreHealth=nil
                lastState=nil
                lastMode=nil
                firstStam=char:GetAttribute("Stamina")
                firstHealth=hum.Health
            end
            local stam=char:GetAttribute("Stamina")
            local stmax=char:GetAttribute("StaminaMax")
            local hp=hum.Health
            local hpmax=hum.MaxHealth
            local mode=getMode(char)
            local state=enabled and "Trial ON" or "Trial OFF"

            -- Compare pre-write observations only within stable movement/state intervals.
            if lastState==state and lastMode==mode then
                local b=bucket(state,mode)
                b.time=b.time+dt
                b.samples=b.samples+1
                if type(stam)=="number" and type(lastPreStam)=="number" then
                    aggregate(lastPreStam,stam,dt,"stamina",b)
                end
                if type(hp)=="number" and type(lastPreHealth)=="number" then
                    aggregate(lastPreHealth,hp,dt,"health",b)
                end
            end

            if enabled then
                onSeconds=onSeconds+dt
                if staminaOn and type(stam)=="number" and type(stmax)=="number"
                    and stmax>0 and stam<stmax then
                    local target=math.min(stmax,stam+STAMINA_PER_SECOND*dt)
                    local added=target-stam
                    if added>0 then
                        char:SetAttribute("Stamina",target)
                        staminaWrites=staminaWrites+1
                        totalLocalStamRequested=totalLocalStamRequested+added
                        local read=char:GetAttribute("Stamina")
                        if type(read)=="number" and read>=target-0.01 then
                            staminaReadbacks=staminaReadbacks+1
                        end
                    end
                end
                if healthOn and type(hp)=="number" and type(hpmax)=="number"
                    and hpmax>0 and hp<hpmax then
                    local target=math.min(hpmax,hp+HEALTH_PER_SECOND*dt)
                    local added=target-hp
                    if added>0 then
                        hum.Health=target
                        healthWrites=healthWrites+1
                        totalLocalHealthRequested=totalLocalHealthRequested+added
                        if hum.Health>=target-0.01 then
                            healthReadbacks=healthReadbacks+1
                        end
                    end
                end
            end
            if type(stam)=="number" and type(lastPreStam)=="number"
               and stam<lastPreStam-0.02 then staminaDrops=staminaDrops+1 end
            if type(hp)=="number" and type(lastPreHealth)=="number"
               and hp<lastPreHealth-0.02 then healthDrops=healthDrops+1 end

            -- Display current attributes following any attempted local writes.
            local shownStam=char:GetAttribute("Stamina")
            local shownHp=hum.Health
            staminaLabel.Text="Stamina: "..formatNum(shownStam).." / "..formatNum(stmax)
            healthLabel.Text="Health: "..formatNum(shownHp).." / "..formatNum(hpmax)
            status.Text=(enabled and "TRIAL ON" or "TRIAL OFF").."  •  "..mode..
                "  •  SERVER EFFECT NOT VERIFIED"
            status.TextColor3=enabled and colors.green or colors.muted
            rates.Text="Local targets: +"..formatNum(STAMINA_PER_SECOND)..
                " stamina/s and +"..formatNum(HEALTH_PER_SECOND).." HP/s"
            lastPreStam=stam
            lastPreHealth=hp
            lastSeenStam=stam
            lastSeenHealth=hp
            lastState=state
            lastMode=mode
        end)
        if not ok then
            errors=errors+1
            recentMessage=string.sub(tostring(err),1,95)
            status.Text="Warning: "..recentMessage
            status.TextColor3=colors.red
        end
        task.wait(INTERVAL)
    end
end)
