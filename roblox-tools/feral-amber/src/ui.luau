-- Compact independent Amber control. Right Shift remains owned by Renaissance.
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
    local frame=Instance.new("Frame")
    frame.Name="AmberPanel"
    frame.Position=UDim2.new(1,-358,0,84)
    frame.Size=UDim2.fromOffset(340,141)
    frame.BackgroundColor3=Color3.fromRGB(20,29,31)
    frame.BorderSizePixel=0
    frame.Parent=gui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,8)
    local border=Instance.new("UIStroke")
    border.Thickness=1;border.Color=Color3.fromRGB(61,91,88);border.Parent=frame
    local header=text(frame,13,12,8,270,22,Color3.fromRGB(230,204,130))
    header.Font=Enum.Font.GothamBold
    header.Text="FERAL AMBER  ·  AUTOPILOT"
    local mode=text(frame,11,12,34,320,21)
    local info=text(frame,11,12,56,320,21)
    local reason=text(frame,10,12,77,320,22,Color3.fromRGB(184,207,201))
    reason.TextTruncate=Enum.TextTruncate.AtEnd
    local running=false
    local ui={gui=gui,frame=frame,agent=agent,bridge=bridge,lastUpdate=0,collapsed=false}
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
        local ok,payload=pcall(function()
            return game:GetService("HttpService"):JSONEncode(status)
        end)
        if ok then
            if type(setclipboard)=="function" then pcall(setclipboard,payload) end
            print("[FERAL AMBER STATUS] "..payload)
        end
    end)
    local collapse
    collapse=button(frame,"HIDE",244,106,84,function()
        ui.collapsed=not ui.collapsed
        if ui.collapsed then
            frame.Size=UDim2.fromOffset(340,34)
            start.Visible=false;copyStatus.Visible=false;mode.Visible=false;info.Visible=false;reason.Visible=false
            collapse.Text="OPEN";collapse.Position=UDim2.fromOffset(258,3)
        else
            frame.Size=UDim2.fromOffset(340,141)
            start.Visible=true;copyStatus.Visible=true;mode.Visible=true;info.Visible=true;reason.Visible=true
            collapse.Text="HIDE";collapse.Position=UDim2.fromOffset(244,106)
        end
    end)
    function ui:tick(now)
        if now-self.lastUpdate<.75 then return end
        self.lastUpdate=now
        local st=agent:status()
        local snap=bridge:snapshot(now)
        start.Text=st.enabled and "STOP" or "START"
        mode.Text=(st.enabled and "RUNNING · " or "OFF · ")..st.phase
            ..(st.key and " · "..st.key or "")
        info.Text=string.format("Claims %d  |  Scent %d  |  Feeds %d  |  Amber +%.0f",
            st.claimed,st.scented,st.feeds,st.earned)
        local species=tostring(st.species or snap.species or "No animal")
        reason.Text=species.." · "..st.reason
    end
    function ui:close()
        agent:setEnabled(false)
        if gui.Parent then gui:Destroy() end
    end
    return ui
end
return UI
