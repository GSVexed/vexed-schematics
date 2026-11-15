-- FERAL Recovery Trial v1.9
-- v1.8 read-only diagnostic plus a reversible HudRest-only local experiment.
-- This does not alter WolfRest, animations, movement or fire game remotes.
-- Local HudRest may be only a UI indicator; no server regeneration is guaranteed.
-- Stops if natural resting begins, rest animation is visible by track name,
-- character changes, movement locks, or the game rejects the local flag.

local Players=game:GetService("Players")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")

local BASE_URL="https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-rest-mechanism-lab-v1.8.lua"
local okBase,baseErr=pcall(function()
    local source=game:HttpGet(BASE_URL)
    local chunk=loadstring(source)
    if not chunk then error("The v1.8 diagnostic could not be compiled") end
    chunk()
end)
if not okBase then warn("[FERAL v1.9] Base panel error: "..tostring(baseErr)); return end

local ui=playerGui:WaitForChild("StaminaResearchPanel",8)
local panel=ui and ui:WaitForChild("RestLab",8)
if not panel then warn("[FERAL v1.9] Diagnostic panel not found"); return end

local running=true
local enabled=false
local savedHudRest=nil
local savedCharacter=nil
local writes=0
local lastStatus="Not tested"
local failedChecks=0
local blockedSince=nil
local startedAt=0
local activeSeconds=0
local restPoseSeen=false
local trialSamples=0
local baselineSamples=0
local lastStam=nil
local lastStamMax=nil
local lastHp=nil
local lastHpMax=nil
local lastT=nil
local lastGroup=nil
local lastMode=nil

-- Adjust the inherited v1.8 layout to add a separate test section.
panel.Size=UDim2.fromOffset(540,880)
local uiScale=panel:FindFirstChildOfClass("UIScale")
if uiScale then
    local cam=workspace.CurrentCamera
    if cam then
        local vp=cam.ViewportSize
        uiScale.Scale=math.clamp(math.min(vp.X/570,vp.Y/930),0.51,1)
    end
end
local draggingHeader=panel:FindFirstChild("DragHeader")
if draggingHeader then
    local title=draggingHeader:FindFirstChild("Title")
    local subtitle=draggingHeader:FindFirstChild("Subtitle")
    if title then title.Text="FERAL / RECOVERY TRIAL v1.9" end
    if subtitle then subtitle.Text="Rest request versus pose • opt-in • local-only" end
end
local function shift(name,offset)
    local child=panel:FindFirstChild(name)
    if child and child:IsA("GuiObject") then
        child.Position=UDim2.new(child.Position.X.Scale,child.Position.X.Offset,
            child.Position.Y.Scale,child.Position.Y.Offset+offset)
    end
    return child
end
for _,name in ipairs({"Start","Stop","CopySummary","CopyFull",
                       "Progress","Status","ReportHeading","Report"}) do
    shift(name,104)
end
local inheritedReport=panel:FindFirstChild("Report")
if inheritedReport then inheritedReport.Size=UDim2.fromOffset(512,124) end

local sizeGuard=false
panel:GetPropertyChangedSignal("Size"):Connect(function()
    if not running or sizeGuard then return end
    -- v1.8's Minimize handler uses the old expanded size (778).
    if panel.Size.Y.Offset==778 then
        sizeGuard=true
        panel.Size=UDim2.fromOffset(540,880)
        sizeGuard=false
    end
end)

local function make(className,props,parent)
    local instance=Instance.new(className)
    for k,v in pairs(props) do instance[k]=v end
    instance.Parent=parent
    return instance
end
local surface=Color3.fromRGB(26,37,51)
local accent=Color3.fromRGB(54,194,170)
local blue=Color3.fromRGB(64,127,215)
local red=Color3.fromRGB(193,77,91)
local light=Color3.fromRGB(240,247,255)
local muted=Color3.fromRGB(162,181,204)
local trialCard=make("Frame",{
    Name="HudRestOnlyTrial",Position=UDim2.fromOffset(14,493),
    Size=UDim2.fromOffset(512,103),BackgroundColor3=surface,
    BorderSizePixel=0
},panel)
make("UICorner",{CornerRadius=UDim.new(0,9)},trialCard)

local function label(name,textValue,x,y,w,h,size,color,bold)
    return make("TextLabel",{
        Name=name,Text=textValue,BackgroundTransparency=1,
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextColor3=color or light,TextSize=size,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,
        TextWrapped=true
    },trialCard)
end
label("Heading","HUDREST-ONLY TRIAL  •  WOLFREST UNCHANGED",12,5,480,17,11,accent,true)
label("Explanation",
    "Tests the rest-request flag without intentionally starting the resting pose.",
    12,23,490,19,10,muted,false)
local toggle=make("TextButton",{
    Name="Toggle",Text="Enable trial",Position=UDim2.fromOffset(12,54),
    Size=UDim2.fromOffset(146,38),BackgroundColor3=blue,
    TextColor3=light,Font=Enum.Font.GothamBold,TextSize=12,
    BorderSizePixel=0
},trialCard)
make("UICorner",{CornerRadius=UDim.new(0,8)},toggle)
local copy=make("TextButton",{
    Name="CopyTrial",Text="Copy trial",Position=UDim2.fromOffset(169,54),
    Size=UDim2.fromOffset(115,38),BackgroundColor3=blue,
    TextColor3=light,Font=Enum.Font.GothamBold,TextSize=12,
    BorderSizePixel=0
},trialCard)
make("UICorner",{CornerRadius=UDim.new(0,8)},copy)
local trialStatus=label("Status","OFF\nNo local changes",297,48,201,47,11,muted,true)

local function newBucket()
    return {n=0,seconds=0,stamDelta=0,stamGain=0,stamLoss=0,
            hpAdjusted=0,hpGain=0,hpLoss=0,stamEligible=0,hpEligible=0}
end
local data={
    baseline={Sprint=newBucket(),Burst=newBucket(),Other=newBucket()},
    trial={Sprint=newBucket(),Burst=newBucket(),Other=newBucket()}
}
local function fmt(n)
    if typeof(n)=="number" then return string.format("%.2f",n) end
    return tostring(n)
end
local function refresh()
    if not running then return end
    toggle.Text=enabled and "Disable trial" or "Enable trial"
    toggle.BackgroundColor3=enabled and red or blue
    trialStatus.Text=(enabled and "ON • local only\n" or "OFF\n")..
        (enabled and "No pose requested" or string.sub(lastStatus,1,36))
    trialStatus.TextColor3=enabled and accent or muted
end
local function stop(reason)
    if enabled then
        enabled=false
        lastStatus=reason or "Manually disabled"
        if player.Parent and player:GetAttribute("HudRest")==true then
            -- Restore the value captured when we enabled this test.
            -- We never touch WolfRest or any movement/animation properties.
            pcall(function() player:SetAttribute("HudRest",savedHudRest) end)
        end
    end
    savedCharacter=nil
    savedHudRest=nil
    blockedSince=nil
    refresh()
end
local function restAnimation(char)
    for _,obj in ipairs(char:GetDescendants()) do
        if obj:IsA("Animator") then
            local ok,tracks=pcall(function() return obj:GetPlayingAnimationTracks() end)
            if ok then
                for _,track in ipairs(tracks) do
                    local name=string.lower(tostring(track.Name))
                    pcall(function()
                        if track.Animation then
                            name=name.." "..string.lower(tostring(track.Animation.Name))
                        end
                    end)
                    if name:find("rest",1,true) or
                       name:find("sleep",1,true) or name:find("lying",1,true) then
                        local weight=0
                        pcall(function() weight=track.WeightCurrent end)
                        if weight>0.05 then return true end
                    end
                end
            end
        end
    end
    return false
end
local function getMode(char,speed)
    if (char:GetAttribute("WolfBurst")==true or player:GetAttribute("HudBurst")==true)
        and speed>=25 then return "Burst" end
    if player:GetAttribute("HudSprint")==true and speed>=18 then
        return "Sprint"
    end
    return "Other"
end
local function collect()
    local char=player.Character
    if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    local root=char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    local vel=root.AssemblyLinearVelocity
    local speed=Vector3.new(vel.X,0,vel.Z).Magnitude
    if enabled then
        if char~=savedCharacter or hum.Health<=0 then
            stop("Stopped: character changed")
        elseif char:GetAttribute("WolfRest")==true or restAnimation(char) then
            restPoseSeen=true
            stop("Stopped: rest pose activated")
        elseif player:GetAttribute("HudRest")~=true then
            failedChecks=failedChecks+1
            stop("Stopped: HudRest was reset")
        else
            if hum.MoveDirection.Magnitude>0.4 and speed<0.7 then
                blockedSince=blockedSince or os.clock()
                if os.clock()-blockedSince>1.5 then
                    stop("Stopped: movement blocked")
                end
            else
                blockedSince=nil
            end
            if enabled then activeSeconds=os.clock()-startedAt end
        end
    end

    local stam=char:GetAttribute("Stamina")
    local stamMax=char:GetAttribute("StaminaMax")
    local hp=hum.Health
    local hpMax=hum.MaxHealth
    local now=os.clock()
    local group=enabled and "trial" or
        ((player:GetAttribute("HudRest")==false or
          player:GetAttribute("HudRest")==nil) and
         char:GetAttribute("WolfRest")~=true and "baseline" or "ignore")
    local mode=getMode(char,speed)

    if lastT and now-lastT>0 and now-lastT<1 and group==lastGroup and
       mode==lastMode and group~="ignore" then
        local dt=now-lastT
        local bucket=data[group][mode]
        local staminaDelta=(typeof(stam)=="number" and typeof(lastStam)=="number")
            and (stam-lastStam) or nil
        local healthDelta=(typeof(hp)=="number" and typeof(lastHp)=="number")
            and (hp-lastHp) or nil
        local healthMaxDelta=(typeof(hpMax)=="number" and typeof(lastHpMax)=="number")
            and (hpMax-lastHpMax) or 0
        bucket.n=bucket.n+1
        bucket.seconds=bucket.seconds+dt
        if staminaDelta and typeof(stamMax)=="number"
           and typeof(lastStamMax)=="number" and
           lastStam<lastStamMax-0.4 and stam<stamMax-0.4 then
            bucket.stamDelta=bucket.stamDelta+staminaDelta
            bucket.stamEligible=bucket.stamEligible+dt
            if staminaDelta>0 then bucket.stamGain=bucket.stamGain+staminaDelta
            else bucket.stamLoss=bucket.stamLoss-staminaDelta end
        end
        if healthDelta and hp< hpMax-0.4 and lastHp<lastHpMax-0.4 then
            -- If health and MaxHealth both grow, subtract maximum growth
            -- as an approximation, not proof of actual HP restoration.
            local adjusted=healthDelta-healthMaxDelta
            bucket.hpAdjusted=bucket.hpAdjusted+adjusted
            bucket.hpEligible=bucket.hpEligible+dt
            if adjusted>0 then bucket.hpGain=bucket.hpGain+adjusted
            else bucket.hpLoss=bucket.hpLoss-adjusted end
        end
        if group=="trial" then trialSamples=trialSamples+1
        else baselineSamples=baselineSamples+1 end
    end
    lastStam=stam
    lastStamMax=stamMax
    lastHp=hp
    lastHpMax=hpMax
    lastT=now
    lastGroup=group
    lastMode=mode
end

toggle.Activated:Connect(function()
    if enabled then stop("Manually disabled");return end
    local char=player.Character
    if not char or not char.Parent then
        lastStatus="No character"
        refresh()
        return
    end
    if player:GetAttribute("HudRest")==true or char:GetAttribute("WolfRest")==true then
        lastStatus="Exit normal Rest first"
        refresh()
        return
    end
    savedCharacter=char
    savedHudRest=player:GetAttribute("HudRest")
    enabled=true
    startedAt=os.clock()
    activeSeconds=0
    lastStatus="Active"
    local ok=pcall(function() player:SetAttribute("HudRest",true) end)
    writes=writes+(ok and 1 or 0)
    if not ok then
        stop("Unable to set local flag")
    else
        refresh()
    end
end)

local function report()
    local lines={
        "=== FERAL HUDREST-ONLY RECOVERY TRIAL v1.9 ===",
        "Status: "..(enabled and "ON" or "OFF").." | "..lastStatus,
        "Place ID: "..tostring(game.PlaceId),
        "HudRest set locally: "..writes.." time(s)",
        "WolfRest modified: NEVER",
        "Other movement/animation properties modified: NEVER",
        "Rest-pose signal detected: "..tostring(restPoseSeen),
        "Local HudRest reset: "..failedChecks,
        "Last active window: "..fmt(activeSeconds).."s",
        "Baseline intervals: "..baselineSamples,
        "Trial intervals: "..trialSamples,
        "Only speed >=18 while Sprint and >=25 while Burst count.",
        "Stamina and health samples at maximum are excluded.",
        "Health change adjusted for MaxHealth growth (approximation).",
        ""
    }
    for _,name in ipairs({"Sprint","Burst","Other"}) do
        for _,kind in ipairs({"baseline","trial"}) do
            local b=data[kind][name]
            table.insert(lines,string.format(
                "%s/%s | %.1fs | stam eligibility %.1fs net %+.2f (gained %.2f lost %.2f) | health eligibility %.1fs max-adjusted net %+.2f",
                kind,name,b.seconds,b.stamEligible,b.stamDelta,
                b.stamGain,b.stamLoss,b.hpEligible,b.hpAdjusted))
        end
    end
    table.insert(lines,"")
    table.insert(lines,"IMPORTANT: HudRest is a client-local flag in this experiment.")
    table.insert(lines,"Any stamina gain does not prove a server-recognised resting effect.")
    table.insert(lines,"This does not disable server movement restrictions or validation.")
    table.insert(lines,"=== END ===")
    return table.concat(lines,"\n")
end

copy.Activated:Connect(function()
    local value=report()
    local fn=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard or nil)
    if fn then
        local ok=pcall(fn,value)
        if ok then
            trialStatus.Text="Trial report copied"
            return
        end
    end
    if inheritedReport then
        inheritedReport.Text=value
        inheritedReport:CaptureFocus()
    end
    trialStatus.Text="Select report & Ctrl+C"
end)

ui.Destroying:Connect(function()
    stop("Panel closed")
    running=false
end)
task.spawn(function()
    while ui.Parent and running do
        local ok=pcall(collect)
        if not ok and enabled then stop("Stopped: sampling error") end
        task.wait(0.25)
    end
end)

refresh()
