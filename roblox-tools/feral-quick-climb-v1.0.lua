-- FERAL Quick Climb v1.0: independent v14-compatible prototype.
-- One buffered Q input, native player FeralClimbTap, reversible client
-- PassiveConfig.CLIMBER leases. Never changes tree/target physics.
-- Source: S0003916 FeralClimb, S0000492 PassiveConfig.CLIMBER.
if game.PlaceId~=108901361810209 then
    warn("[QUICK CLIMB] Open FERAL Animal Survival first.");return
end
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local pg=player:FindFirstChildOfClass("PlayerGui")
    or player:WaitForChild("PlayerGui",8)
if not pg then return end
local host
if type(getgenv)=="function" then
    local ok,value=pcall(getgenv)
    if ok and type(value)=="table" then host=value end
end
if host and type(host.FERALQuickClimbV1)=="table"
    and type(host.FERALQuickClimbV1.close)=="function" then
    pcall(host.FERALQuickClimbV1.close)
end
local old=pg:FindFirstChild("FERALQuickClimbV1")
if old then
    local stop=old:FindFirstChild("Shutdown")
    if stop and stop:IsA("BindableEvent") then pcall(function()stop:Fire()end)end
    pcall(function()old:Destroy()end)
end
local Q={
    alive=true,enabled=true,ready=false,queued=false,
    status="WAITING FOR CLIMBABLE ANIMAL",lastError="",
    configReady=false,sprintGrabPatch=false,
    queuedPresses=0,expiredPresses=0,gameTaps=0,
    observedMounts=0,suppressedDives=0,suppressedConflicts=0,
    next=0,lastTap=-math.huge,pendingUntil=0,
    lastChar=nil,awaitingMount=false,awaitUntil=0,
    firstReadyAt=0,configLease=nil
}
local connections={}
local function finite(v)
    return type(v)=="number" and v==v and v<1e8 and v>-1e8
end
local function lease(tbl,key,value,list)
    if type(tbl)~="table" then return false end
    local original=tbl[key]
    if original==nil then return false end
    if original==value then return true end
    local ok=pcall(function()tbl[key]=value end)
    if not ok or tbl[key]~=value then return false end
    list[#list+1]={tbl=tbl,key=key,original=original,wanted=value}
    return true
end
local function release()
    for i=#(Q.configLease or {}),1,-1 do
        local e=Q.configLease[i]
        pcall(function()
            if e.tbl[e.key]==e.wanted then e.tbl[e.key]=e.original end
        end)
    end
    Q.configLease=nil
    Q.configReady=false
    Q.sprintGrabPatch=false
end
local function install()
    if Q.configReady then return true end
    local world=RS:FindFirstChild("FeralWorld")
    local mod=world and world:FindFirstChild("PassiveConfig")
    if not mod or not mod:IsA("ModuleScript") then
        Q.status="PASSIVE CONFIG UNAVAILABLE"
        return false
    end
    local ok,v=pcall(require,mod)
    local c=ok and type(v)=="table" and v.CLIMBER
    if type(c)~="table" or type(c.levels)~="table"
        or not finite(c.GRAB_REACH) or not finite(c.E_REACH)
        or not finite(c.GRAB_FACING) or not finite(c.MOUNT_TIME) then
        Q.status="CLIMB CONFIG NOT COMPATIBLE"
        return false
    end
    local changes={}
    local work={
        {"GRAB_REACH",math.min(1.25,c.GRAB_REACH*1.30)},
        {"E_REACH",math.min(2.1,c.E_REACH*1.25)},
        {"GRAB_FACING",math.max(.25,c.GRAB_FACING*.58)},
        {"MOUNT_TIME",math.max(.22,c.MOUNT_TIME*.75)},
        {"HINT_RANGE",math.min(20,(c.HINT_RANGE or 14)*1.25)}
    }
    for _,entry in ipairs(work) do
        lease(c,entry[1],entry[2],changes)
    end
    local sprintGranted=false
    for _,level in ipairs({1,2}) do
        local l=c.levels[level]
        if type(l)=="table" and l.sprintGrab~=true then
            -- Source blocks basic climbers from catching a tree at
            -- sprint velocity; this is the main chase nuisance.
            if l.sprintGrab==nil then
                -- Nil fields require special restoration.
                local setOk=pcall(function()l.sprintGrab=true end)
                if setOk and l.sprintGrab==true then
                    changes[#changes+1]={
                        tbl=l,key="sprintGrab",original=nil,wanted=true}
                    sprintGranted=true
                end
            else
                if lease(l,"sprintGrab",true,changes) then
                    sprintGranted=true
                end
            end
        end
    end
    Q.configLease=changes
    Q.sprintGrabPatch=sprintGranted
    Q.configReady=true
    Q.status="FAST MOUNT SETTINGS READY • Q BUFFER ON"
    return true
end
local function validChar(char)
    if not char or not char.Parent then return false end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health<=0 or char:GetAttribute("FeralDead")==true then
        return false
    end
    local lv=char:GetAttribute("PassiveClimber")
    return finite(lv) and lv>=1
end
local function unsafe(char)
    return char:GetAttribute("FeralClimbLocal")==true
        or char:GetAttribute("FeralPinned")==true
        or char:GetAttribute("FeralCarried")==true
        or char:GetAttribute("WolfRest")==true
        or char:GetAttribute("WolfFeed")==true
        or char:GetAttribute("FeralDiving")==true
        or char:FindFirstChild("FeralClamp")~=nil
        or char:FindFirstChild("FeralClampLocal")~=nil
end
local function onQ(now)
    if not Q.enabled or not Q.alive then return end
    if UIS:GetFocusedTextBox() then return end
    local char=player.Character
    if not validChar(char) then
        Q.status="THIS ANIMAL CANNOT CLIMB YET"
        return
    end
    if char:GetAttribute("FeralClimbLocal")==true then
        Q.queued=false
        Q.status="ALREADY CLIMBING • NATIVE Q HANDLES LET-GO"
        return
    end
    -- The same Q may be used to dive. Never invoke the climb
    -- tap listener when the local game is offering DiveCan.
    if char:GetAttribute("DiveCan")==true then
        Q.queued=false
        Q.suppressedDives+=1
        Q.status="DIVE HAS PRIORITY"
        return
    end
    if unsafe(char) then
        Q.queued=false
        Q.suppressedConflicts+=1
        Q.status="BUSY / CARRY, REST OR GRAB PRIORITY"
        return
    end
    -- A Q pressed before the first heartbeat must survive the
    -- initial character sample; only an actual respawn clears it.
    Q.lastChar=char
    Q.pendingUntil=now+1.3
    Q.queued=true
    Q.queuedPresses+=1
    Q.status="Q BUFFERED • RUN TOWARD TREE"
end
local function tick()
    if not Q.alive then return end
    local now=os.clock()
    if now<Q.next then return end
    Q.next=now+.055
    if Q.enabled and not Q.configReady then install()end
    local char=player.Character
    if char~=Q.lastChar then
        Q.lastChar=char;Q.queued=false
        Q.awaitingMount=false;Q.ready=false
    end
    if not Q.enabled then return end
    if not validChar(char) then
        Q.queued=false;Q.ready=false
        return
    end
    if char:GetAttribute("FeralClimbLocal")==true then
        if Q.awaitingMount then Q.observedMounts+=1 end
        Q.queued=false;Q.awaitingMount=false
        Q.status="CLIMBING • NATIVE Q TO LET GO"
        Q.ready=false
        return
    end
    if Q.awaitingMount and now>=Q.awaitUntil then
        Q.awaitingMount=false
        Q.status="CLIMB TAP SENT • NO MOUNT CONFIRMED"
    end
    Q.ready=char:GetAttribute("ClimbCan")==true
    if not Q.queued then return end
    if now>Q.pendingUntil then
        Q.queued=false
        Q.expiredPresses+=1
        Q.status="BUFFER EXPIRED • TREE NOT READY"
        return
    end
    if UIS:GetFocusedTextBox() or unsafe(char) then
        Q.queued=false
        Q.suppressedConflicts+=1
        return
    end
    if char:GetAttribute("DiveCan")==true then
        Q.queued=false;Q.suppressedDives+=1
        return
    end
    if not Q.ready then return end
    if now-Q.lastTap<.35 then return end
    Q.lastTap=now
    Q.queued=false
    -- Native FERAL ClimbController listens to the player's
    -- FeralClimbTap attribute (same as the game's own touch HUD).
    -- Never send FeralClimb remote directly or teleport into trees.
    player:SetAttribute("FeralClimbTap",now)
    Q.gameTaps+=1
    Q.awaitingMount=true
    Q.awaitUntil=now+.7
    Q.status="NATIVE CLIMB TAP SENT"
end
function Q.setEnabled(on)
    Q.enabled=on==true
    Q.queued=false
    if not Q.enabled then
        release()
        Q.status="OFF / CLIMB SETTINGS RESTORED"
    else
        Q.status="READY TO BUFFER Q"
        install()
    end
end
function Q.report()
    return table.concat({
        "FERAL Quick Climb v1.0 | Native Tree Mount",
        "enabled="..tostring(Q.enabled)..
            " config_applied="..tostring(Q.configReady),
        "climb_ready_now="..tostring(Q.ready),
        "buffer_pending="..tostring(Q.queued),
        "sprint_grab_enabled_client="..tostring(Q.sprintGrabPatch),
        "Q_press_buffers="..Q.queuedPresses,
        "buffer_expired="..Q.expiredPresses,
        "native_climb_taps="..Q.gameTaps,
        "observed_climb_mounts="..Q.observedMounts,
        "dive_priority_holds="..Q.suppressedDives,
        "carry_and_capture_priority_holds="..Q.suppressedConflicts,
        "status="..Q.status,
        "last_error="..Q.lastError,
        "NOTE=Game controls actual mount and server acceptance."
    },"\n")
end
local g=Instance.new("ScreenGui")
g.Name="FERALQuickClimbV1";g.ResetOnSpawn=false;g.DisplayOrder=250
g.Parent=pg
local stop=Instance.new("BindableEvent")
stop.Name="Shutdown";stop.Parent=g
local panel=Instance.new("Frame")
panel.Size=UDim2.fromOffset(234,60)
panel.Position=UDim2.new(1,-244,0,55)
panel.BackgroundColor3=Color3.fromRGB(20,29,41)
panel.BackgroundTransparency=.12;panel.BorderSizePixel=0
panel.Parent=g
local round=Instance.new("UICorner");round.CornerRadius=UDim.new(0,9)
round.Parent=panel
local status=Instance.new("TextLabel")
status.Size=UDim2.new(1,-16,0,24)
status.Position=UDim2.fromOffset(8,3)
status.BackgroundTransparency=1
status.Font=Enum.Font.GothamBold;status.TextSize=12
status.TextColor3=Color3.fromRGB(210,234,241)
status.TextXAlignment=Enum.TextXAlignment.Left
status.Text="QUICK CLIMB • Q"
status.Parent=panel
local toggle=Instance.new("TextButton")
toggle.Size=UDim2.fromOffset(103,25)
toggle.Position=UDim2.fromOffset(7,30)
toggle.BackgroundColor3=Color3.fromRGB(37,109,98)
toggle.TextColor3=Color3.new(1,1,1)
toggle.Font=Enum.Font.GothamBold;toggle.TextSize=11
toggle.Text="ON • Q BUFFER";toggle.Parent=panel
local copy=Instance.new("TextButton")
copy.Size=UDim2.fromOffset(108,25)
copy.Position=UDim2.fromOffset(118,30)
copy.BackgroundColor3=Color3.fromRGB(47,75,91)
copy.TextColor3=Color3.new(1,1,1)
copy.Font=Enum.Font.GothamBold;copy.TextSize=11
copy.Text="COPY STATUS";copy.Parent=panel
local function close()
    if not Q.alive then return end
    Q.alive=false;Q.setEnabled(false)
    for _,cn in ipairs(connections) do
        pcall(function()cn:Disconnect()end)
    end
    if host and host.FERALQuickClimbV1==Q then
        host.FERALQuickClimbV1=nil
    end
    if g.Parent then g:Destroy()end
end
Q.close=close
if host then host.FERALQuickClimbV1=Q end
connections[#connections+1]=stop.Event:Connect(close)
connections[#connections+1]=UIS.InputBegan:Connect(function(input,processed)
    if input.KeyCode==Enum.KeyCode.Q then
        pcall(onQ,os.clock())
    end
end)
connections[#connections+1]=toggle.MouseButton1Click:Connect(function()
    Q.setEnabled(not Q.enabled)
end)
connections[#connections+1]=copy.MouseButton1Click:Connect(function()
    local f=type(setclipboard)=="function" and setclipboard
        or type(toclipboard)=="function" and toclipboard
    if f then pcall(f,Q.report()) else print(Q.report()) end
end)
connections[#connections+1]=RunService.Heartbeat:Connect(function()
    local ok,err=pcall(tick)
    if not ok then
        Q.lastError=tostring(err)
        Q.queued=false
    end
    local label=Q.enabled and (
        Q.queued and "Q QUEUED • APPROACH TREE"
        or Q.ready and "READY • Q TO CLIMB"
        or Q.status) or "QUICK CLIMB DISABLED"
    status.Text=label
    status.TextColor3=Q.ready and Color3.fromRGB(100,239,181)
        or Color3.fromRGB(210,234,241)
    toggle.Text=Q.enabled and "ON • Q BUFFER" or "OFF • ORIGINAL"
end)
install()
print("[FERAL QUICK CLIMB] Loaded. Q is buffered up to 1.3 seconds, no repeated auto-tapping.")
