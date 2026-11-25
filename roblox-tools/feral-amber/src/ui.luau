-- Draggable Amber control; Right Shift follows the Renaissance menu.
local UI={}
local function text(parent,size,x,y,w,h,colour)
    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1
    t.Font=Enum.Font.Gotham
    t.TextSize=size
    t.TextColor3=colour or Color3.fromRGB(220,240,233)
    t.TextXAlignment=Enum.TextXAlignment.Left
    t.TextYAlignment=Enum.TextYAlignment.Center
    t.Position=UDim2.fromOffset(x,y)
    t.Size=UDim2.fromOffset(w,h)
    t.Text=""
    t.Parent=parent
    return t
end
local function button(parent,label,x,y,width,callback)
    local b=Instance.new("TextButton")
    b.Name=label:gsub("[^%w]","")
    b.Position=UDim2.fromOffset(x,y)
    b.Size=UDim2.fromOffset(width,28)
    b.BackgroundColor3=Color3.fromRGB(45,79,79)
    b.BorderSizePixel=0
    b.Font=Enum.Font.GothamMedium
    b.TextSize=11
    b.TextColor3=Color3.fromRGB(240,252,247)
    b.Text=label
    b.Parent=parent
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    b.Activated:Connect(callback)
    return b
end
function UI.new(agent,bridge)
    local pg=bridge.player:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil,"PlayerGui not ready" end
    local prior=pg:FindFirstChild("FeralAmberAutopilot")
    if prior then prior:Destroy() end
    local gui=Instance.new("ScreenGui")
    gui.Name="FeralAmberAutopilot"
    gui.ResetOnSpawn=false
    gui.DisplayOrder=180
    gui.Parent=pg
    local UIS=game:GetService("UserInputService")
    local Workspace=game:GetService("Workspace")
    local env=(type(getgenv)=="function" and getgenv()) or _G
    local frame=Instance.new("Frame")
    frame.Name="AmberPanel"
    frame.Position=env.FERAL_AMBER_PANEL_POSITION or UDim2.new(1,-358,0,84)
    frame.Size=UDim2.fromOffset(340,141)
    frame.BackgroundColor3=Color3.fromRGB(20,29,31)
    frame.BorderSizePixel=0
    frame.Active=true
    frame.Parent=gui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,8)
    local border=Instance.new("UIStroke")
    border.Thickness=1;border.Color=Color3.fromRGB(61,91,88);border.Parent=frame
    local header=text(frame,13,12,8,270,22,Color3.fromRGB(230,204,130))
    header.Font=Enum.Font.GothamBold
    header.Text="FERAL AMBER  ·  AUTOPILOT"
    header.Active=true
    local mode=text(frame,11,12,34,320,21)
    local info=text(frame,11,12,56,320,21)
    local reason=text(frame,10,12,77,320,22,Color3.fromRGB(184,207,201))
    reason.TextTruncate=Enum.TextTruncate.AtEnd
    local ui={gui=gui,frame=frame,agent=agent,bridge=bridge,lastUpdate=0,
        collapsed=false,visible=true,connections={}}
    local start
    start=button(frame,"START",12,106,87,function()
        agent:setEnabled(not agent.enabled)
        start.Text=agent.enabled and "STOP" or "START"
    end)
    local copyStatus=button(frame,"COPY STATUS",108,106,125,function()
        local status=agent:status()
        status.coat=type(status.coat)=="string" and status.coat or nil
        status.events=agent.events
        status.gameVersion=game.PlaceVersion
        status.territoryCount=#(bridge.hexes or {})
        status.hexSummary=bridge:counts(bridge:snapshot(os.clock()))
        status.navigation={
            stage=bridge.nav.lastReason,input=bridge.nav.nativeInput,
            gait=bridge.nav.gait,steering=bridge.nav.lastMode,
            activeBurstAt=bridge.nav.lastBurstAt,
            pathIndex=bridge.nav.index,pathCount=#(bridge.nav.points or {}),
            lastGoal=bridge.nav.destination and {
                x=math.floor(bridge.nav.destination.X),
                z=math.floor(bridge.nav.destination.Z)} or nil,
            failures=bridge.nav.failures,replans=bridge.nav.replans,
        }
        status.savedPanelPosition=tostring(frame.Position)
        local ok,payload=pcall(function()
            return game:GetService("HttpService"):JSONEncode(status)
        end)
        if ok then
            if type(setclipboard)=="function" then pcall(setclipboard,payload) end
            print("[FERAL AMBER STATUS] "..payload)
        end
    end)
    local collapse
    collapse=button(frame,"MIN",244,106,84,function()
        ui.collapsed=not ui.collapsed
        if ui.collapsed then
            frame.Size=UDim2.fromOffset(340,34)
            start.Visible=false;copyStatus.Visible=false;mode.Visible=false;info.Visible=false;reason.Visible=false
            collapse.Text="OPEN";collapse.Position=UDim2.fromOffset(258,3)
        else
            frame.Size=UDim2.fromOffset(340,141)
            start.Visible=true;copyStatus.Visible=true;mode.Visible=true;info.Visible=true;reason.Visible=true
            collapse.Text="MIN";collapse.Position=UDim2.fromOffset(244,106)
        end
    end)
    -- Right Shift is the same hub hotkey, not a separate keybinding to
    -- interfere with FERAL's normal sprint controls. Read Renaissance's final
    -- visibility after its own handler has processed the key.
    function ui:setVisible(on)
        self.visible=on==true
        gui.Enabled=self.visible
    end
    function ui:toggle()
        self:setVisible(not self.visible)
    end
    table.insert(ui.connections,UIS.InputBegan:Connect(function(input)
        if input.KeyCode~=Enum.KeyCode.RightShift or UIS:GetFocusedTextBox() then return end
        task.defer(function()
            if not gui.Parent then return end
            local hub=env.FERAL_RENAISSANCE_ACTIVE
            if type(hub)=="table" and hub.ui and type(hub.ui.visible)=="boolean" then
                ui:setVisible(hub.ui.visible)
            else
                ui:toggle()
            end
        end)
    end))
    -- Drag only the header; START, STOP, COPY and MIN remain independently
    -- clickable. Works with desktop mouse and touch; stores position locally.
    local drag=false
    local dragInput=nil
    local dragOrigin=nil
    local frameOrigin=nil
    table.insert(ui.connections,header.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch then
            drag=true
            dragInput=input
            dragOrigin=input.Position
            frameOrigin=frame.AbsolutePosition
        end
    end))
    table.insert(ui.connections,UIS.InputChanged:Connect(function(input)
        if not drag or not dragOrigin or not frameOrigin then return end
        if input.UserInputType~=Enum.UserInputType.MouseMovement
            and input~=dragInput then return end
        local delta=input.Position-dragOrigin
        local cam=Workspace.CurrentCamera
        local size=cam and cam.ViewportSize or Vector2.new(1366,768)
        local width,height=frame.AbsoluteSize.X,frame.AbsoluteSize.Y
        local x=math.clamp(frameOrigin.X+delta.X,0,math.max(0,size.X-width))
        local y=math.clamp(frameOrigin.Y+delta.Y,0,math.max(0,size.Y-height))
        frame.Position=UDim2.fromOffset(x,y)
        env.FERAL_AMBER_PANEL_POSITION=frame.Position
    end))
    table.insert(ui.connections,UIS.InputEnded:Connect(function(input)
        if drag and (input==dragInput
            or input.UserInputType==Enum.UserInputType.MouseButton1) then
            drag,dragInput,dragOrigin,frameOrigin=false,nil,nil,nil
        end
    end))
    function ui:tick(now)
        if now-self.lastUpdate<.75 then return end
        self.lastUpdate=now
        local st=agent:status()
        local snap=bridge:snapshot(now)
        start.Text=st.enabled and "STOP" or "START"
        mode.Text=(st.enabled and "RUNNING · " or "OFF · ")..st.phase
            ..(st.key and " · "..st.key or "")
        local counts=bridge:counts(snap)
        info.Text=string.format("Hexes %d/%d owned · %d fading · Amber +%.0f",
            counts.owned,counts.eligible,counts.fading,st.earned)
        local species=tostring(st.species or snap.species or "No animal")
        local nav=bridge.nav
        local diagnostic=st.phase=="TRAVEL" or st.phase=="TRAVEL_WATER"
            or st.phase=="HUNT_APPROACH"
        reason.Text=species.." · "..st.reason
            ..(diagnostic and (" / "..tostring(nav.gait or "STOP").." · "..tostring(nav.lastReason or "routing")
                .." · "..tostring(nav.nativeInput or "input pending")) or "")
    end
    function ui:close()
        agent:setEnabled(false)
        for _,connection in ipairs(self.connections) do pcall(function() connection:Disconnect() end) end
        table.clear(self.connections)
        if gui.Parent then gui:Destroy() end
    end
    return ui
end
return UI
