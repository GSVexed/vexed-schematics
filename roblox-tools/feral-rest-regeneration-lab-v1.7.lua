-- FERAL Rest & Regeneration Lab v1.7
-- Adds an opt-in, reversible, client-local WolfRest experiment to v1.6.
-- No remotes fired; no animation playback or movement controls modified.
-- Local flags cannot establish server-recognised regeneration.
local base = "https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-rest-regeneration-lab-v1.6.lua"
local okBase,errBase=pcall(function()
    local func=loadstring(game:HttpGet(base))
    if not func then error("Could not load base rest lab") end
    func()
end)
if not okBase then warn("FERAL Rest Lab v1.7: "..tostring(errBase));return end

local Players=game:GetService("Players")
local player=Players.LocalPlayer
local ui=player:WaitForChild("PlayerGui"):WaitForChild("StaminaResearchPanel",6)
if not ui then warn("FERAL Rest Lab: panel missing");return end
local panel=ui:WaitForChild("RestLab",6)
if not panel then warn("FERAL Rest Lab: parent panel missing");return end
local running=true

local function move(name,y)
    local obj=panel:FindFirstChild(name)
    if obj and obj:IsA("GuiObject") then
        obj.Position=UDim2.new(obj.Position.X.Scale,obj.Position.X.Offset,0,y)
    end
    return obj
end

panel.Size=UDim2.fromOffset(540,724)
local scale=panel:FindFirstChildOfClass("UIScale")
local function resizeScale()
    local camera=workspace.CurrentCamera
    if scale and camera then
        local sz=camera.ViewportSize
        scale.Scale=math.clamp(math.min(sz.X/570,sz.Y/772),0.58,1)
    end
end
resizeScale()
local message=panel:FindFirstChild("Message")
if message then message.Visible=false end
move("Start",462)
move("Stop",462)
move("CopySummary",462)
move("CopyFull",462)
move("Progress",511)
move("Status",525)
move("ReportHeading",563)
local originalReport=move("Report",588)
if originalReport then originalReport.Size=UDim2.fromOffset(512,121) end
local header=panel:FindFirstChild("DragHeader")
if header and header:FindFirstChild("Title") then
    header.Title.Text="FERAL / REST & REGEN LAB v1.7"
end
if header and header:FindFirstChild("Subtitle") then
    header.Subtitle.Text="rest diagnostics + experimental local rest toggle"
end
-- The inherited minimize handler restores height 644; correct expanded state.
panel:GetPropertyChangedSignal("Size"):Connect(function()
    if running and panel.Size.Y.Offset==644 then
        panel.Size=UDim2.fromOffset(540,724)
    end
end)

local bg=Color3.fromRGB(26,37,51)
local accent=Color3.fromRGB(54,194,170)
local blue=Color3.fromRGB(64,127,215)
local red=Color3.fromRGB(193,77,91)
local white=Color3.fromRGB(240,247,255)
local muted=Color3.fromRGB(162,181,204)
local function make(cls,props,parent)
    local obj=Instance.new(cls)
    for k,v in pairs(props) do obj[k]=v end
    obj.Parent=parent
    return obj
end
local card=make("Frame",{
    Name="AlwaysRestExperiment",
    Position=UDim2.fromOffset(14,344),
    Size=UDim2.fromOffset(512,106),
    BackgroundColor3=bg,BorderSizePixel=0
},panel)
make("UICorner",{CornerRadius=UDim.new(0,10)},card)
local function label(name,content,x,y,w,h,fontSize,color,bold)
    return make("TextLabel",{
        Name=name,Text=content,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextColor3=color or white,TextSize=fontSize,
        TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center
    },card)
end
label("SectionTitle","ALWAYS REST • CLIENT-LOCAL TEST",12,3,480,20,11,accent,true)
label("SectionCaption",
    "Sets WolfRest only; no normal Rest action or HudRest changes.",
    12,24,482,19,10,muted,false)
local toggle=make("TextButton",{
    Name="ToggleAlwaysRest",
    Position=UDim2.fromOffset(12,57),Size=UDim2.fromOffset(166,38),
    BackgroundColor3=blue,TextColor3=white,
    Text="Enable local rest",TextSize=12,
    Font=Enum.Font.GothamBold,BorderSizePixel=0
},card)
make("UICorner",{CornerRadius=UDim.new(0,8)},toggle)
local copy=make("TextButton",{
    Name="CopyProbe",Position=UDim2.fromOffset(188,57),
    Size=UDim2.fromOffset(116,38),BackgroundColor3=blue,
    TextColor3=white,Text="Copy probe",
    Font=Enum.Font.GothamBold,TextSize=11,BorderSizePixel=0
},card)
make("UICorner",{CornerRadius=UDim.new(0,8)},copy)
local stateLabel=label("ProbeState",
    "OFF\nNo local changes",316,51,180,47,10,muted,true)

local enabled=false
local target=nil
local original=nil
local changed=0
local overwritten=0
local overlap=0
local positive=0
local negative=0
local totalDelta=0
local firstStam=nil
local prevStam=nil
local previousMode="none"
local lastStatus="Not tested"
local attempts=0
local animationFound=false
local blockedAt=nil
local minHealth=nil
local lastHealth=nil
local elapsedSince=0
local started=0
local samples=0
local recentRate=0

local function updateUI()
    if not running then return end
    if enabled then
        toggle.Text="Disable local rest"
        toggle.BackgroundColor3=red
        stateLabel.Text="ON • Client-only\nΔ "..string.format("%+.2f",totalDelta).." stamina"
        stateLabel.TextColor3=accent
    else
        toggle.Text="Enable local rest"
        toggle.BackgroundColor3=blue
        stateLabel.Text="OFF\n"..string.sub(lastStatus,1,65)
        stateLabel.TextColor3=muted
    end
end

local function disable(reason)
    if enabled then
        enabled=false
        lastStatus=reason or "Manually disabled"
        if target and target.Parent then
            pcall(function() target:SetAttribute("WolfRest",original) end)
        end
    end
    target=nil
    original=nil
    blockedAt=nil
    updateUI()
end

local function isRestTrack(char)
    local keywords={"rest","sleep","lying","laydown","lie_down"}
    for _,item in ipairs(char:GetDescendants()) do
        if item:IsA("Animator") then
            local ok,tracks=pcall(function() return item:GetPlayingAnimationTracks() end)
            if ok then
                for _,track in ipairs(tracks) do
                    local name=string.lower(tostring(track.Name))
                    pcall(function()
                        if track.Animation then
                            name=name.." "..string.lower(tostring(track.Animation.Name))
                        end
                    end)
                    for _,word in ipairs(keywords) do
                        if name:find(word,1,true) then
                            local weight=0
                            pcall(function() weight=track.WeightCurrent end)
                            if weight>0.05 then return true end
                        end
                    end
                end
            end
        end
    end
    return false
end

local function tick()
    if not enabled then return end
    local char=player.Character
    if not char or target~=char or not char.Parent then
        disable("Stopped: character changed")
        return
    end
    if player:GetAttribute("HudRest")==true then
        disable("Stopped: normal Rest enabled")
        return
    end
    if isRestTrack(char) then
        animationFound=true
        disable("Stopped: rest animation")
        return
    end
    local hum=char:FindFirstChildOfClass("Humanoid")
    local root=char:FindFirstChild("HumanoidRootPart")
    if hum and hum.Health<=0 then
        disable("Stopped: character died")
        return
    end
    if hum and root and hum.MoveDirection.Magnitude>0.4 then
        local velocity=root.AssemblyLinearVelocity
        local speed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
        if speed<0.7 then
            if not blockedAt then blockedAt=os.clock() end
            if os.clock()-blockedAt>1.5 then
                disable("Stopped: movement blocked")
                return
            end
        else
            blockedAt=nil
        end
    else
        blockedAt=nil
    end
    if char:GetAttribute("WolfRest")~=true then
        if changed>0 then overwritten=overwritten+1 end
        local ok=pcall(function() char:SetAttribute("WolfRest",true) end)
        if not ok then
            disable("Stopped: setting failed")
            return
        end
        changed=changed+1
    end
    local stamina=char:GetAttribute("Stamina")
    local sprint=player:GetAttribute("HudSprint")==true
    local burst=char:GetAttribute("WolfBurst")==true
    local mode=burst and "Burst" or (sprint and "Sprint" or "Other")
    local isMoving=sprint or burst
    if isMoving then overlap=overlap+1 end
    if typeof(stamina)=="number" then
        if prevStam and isMoving then
            local diff=stamina-prevStam
            totalDelta=totalDelta+diff
            if diff>0.01 then positive=positive+1 end
            if diff< -0.01 then negative=negative+1 end
        end
        prevStam=stamina
        if not firstStam then firstStam=stamina end
    end
    previousMode=mode
    if hum then lastHealth=hum.Health end
    samples=samples+1
    elapsedSince=os.clock()-started
    if samples%4==0 then updateUI() end
end

toggle.Activated:Connect(function()
    if enabled then disable("Manually disabled");return end
    local char=player.Character
    if not char then lastStatus="No character";updateUI();return end
    if player:GetAttribute("HudRest")==true then
        lastStatus="Exit normal Rest first"
        updateUI()
        return
    end
    original=char:GetAttribute("WolfRest")
    target=char
    enabled=true
    started=os.clock()
    changed=0
    overwritten=0
    overlap=0
    positive=0
    negative=0
    totalDelta=0
    firstStam=nil
    prevStam=nil
    samples=0
    animationFound=false
    blockedAt=nil
    lastStatus="Enabled"
    tick()
    updateUI()
end)

local function probeReport()
    return table.concat({
        "=== FERAL LOCAL ALWAYS-REST EXPERIMENT v1.7 ===",
        "Status: "..(enabled and "ON" or "OFF").." | "..lastStatus,
        "Local flag: Character@WolfRest only (HudRest untouched)",
        "Samples: "..samples.." | elapsed "..string.format("%.1f",elapsedSince).."s",
        "WolfRest local writes: "..changed,
        "Times game reset WolfRest after a write: "..overwritten,
        "Sprint/Burst overlap samples: "..overlap,
        "Positive stamina deltas during Sprint/Burst: "..positive,
        "Negative stamina deltas during Sprint/Burst: "..negative,
        "Net stamina change during Sprint/Burst: "..string.format("%+.2f",totalDelta),
        "Rest-named animation observed: "..tostring(animationFound),
        "Important: this is CLIENT-LOCAL. Even apparent success does NOT prove",
        "the game server grants stamina regen or allows Rest with movement.",
        "=== END ==="
    },"\n")
end

copy.Activated:Connect(function()
    local content=probeReport()
    local fn=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard or nil)
    if fn then
        local ok=pcall(fn,content)
        if ok then
            stateLabel.Text="Probe report copied!"
            return
        end
    end
    if originalReport then
        originalReport.Text=content
        originalReport:CaptureFocus()
    end
    stateLabel.Text="Select text + Ctrl+C"
end)
ui.Destroying:Connect(function()
    disable("Panel closed")
    running=false
end)

task.spawn(function()
    while running and ui.Parent do
        if enabled then
            local ok=pcall(tick)
            if not ok then disable("Stopped: runtime error") end
        end
        task.wait(0.25)
    end
end)
