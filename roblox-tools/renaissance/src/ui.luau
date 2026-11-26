-- One compact window and one owner for all hub outlines, tags and the bite dot.
local UI = {}
function UI.fit(viewport,centre)
    local x,y=viewport and viewport.X,viewport and viewport.Y
    if type(x)~="number" or type(y)~="number" or x~=x or y~=y or x<80 or y<80 or x>=1e8 or y>=1e8 then return nil end
    local scale=math.min((x-24)/704,(y-24)/505,1)
    local halfX,halfY=352*scale,252.5*scale
    return scale,Vector2.new(math.clamp(centre and centre.X or x/2,halfX+12,x-halfX-12),
        math.clamp(centre and centre.Y or y/2,halfY+12,y-halfY-12))
end

function UI.markerTone(species,ready,stock)
    if not ready then return "sub" end
    if species=="KingCobra" then return stock and "same" or "unknown" end
    return "text"
end

function UI.healthColour(hp,maxHP)
    if type(hp) ~= "number" or type(maxHP) ~= "number" or hp ~= hp or maxHP ~= maxHP
        or math.abs(hp) >= 1e12 or math.abs(maxHP) >= 1e12 or maxHP <= 0 then
        return Color3.fromRGB(151,173,194)
    end
    local ratio = math.clamp(hp/maxHP,0,1)
    return Color3.fromRGB(255*math.min(1,2*(1-ratio)),255*math.min(1,2*ratio),0)
end
function UI.mount(hub, bridge, scope)
    local player = bridge.player
    local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",10)
    assert(pg,"PlayerGui unavailable")
    local u = { visible = true, rows = {}, records = {}, nextText = 0, nextFit = 0,
        tab = hub.settings.tab, lastPoint = nil,pages={},pageView=nil }
    local palette = {
        bg = Color3.fromRGB(12,17,28), side = Color3.fromRGB(15,22,36),
        panel = Color3.fromRGB(22,31,48), line = Color3.fromRGB(48,65,85),
        text = Color3.fromRGB(239,246,252), sub = Color3.fromRGB(151,173,194),
        same = Color3.fromRGB(77,219,194), other = Color3.fromRGB(236,105,126),
        unknown = Color3.fromRGB(236,181,104), off = Color3.fromRGB(60,77,97),
        on = Color3.fromRGB(27,111,98),
    }
    local function make(class,properties,parent)
        local object = Instance.new(class)
        for key,value in pairs(properties or {}) do object[key] = value end
        object.Parent = parent
        return object
    end
    local function assign(object,key,value)
        if object[key]~=value then object[key]=value end
    end
    local function round(object,radius)
        make("UICorner",{CornerRadius = UDim.new(0,radius or 9)},object)
        return object
    end
    local function text(parent,body,x,y,w,h,size,colour)
        return make("TextLabel",{Text = body, BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.fromOffset(x,y), Size = UDim2.fromOffset(w,h),
            Font = Enum.Font.Gotham, TextSize = size or 12, TextColor3 = colour or palette.text,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd},parent)
    end
    local function button(parent,body,x,y,w,h)
        return round(make("TextButton",{Text = body, AutoButtonColor = true,
            Selectable = true,
            BackgroundColor3 = palette.off, BorderSizePixel = 0, TextColor3 = palette.text,
            Font = Enum.Font.GothamMedium, TextSize = 11, Position = UDim2.fromOffset(x,y),
            Size = UDim2.fromOffset(w,h)},parent),7)
    end
    -- Parent ownership is registered immediately, before any child creation.
    local gui = Instance.new("ScreenGui")
    scope:add(function() gui:Destroy() end)
    gui.Name = "FeralRenaissanceV15_" .. tostring(hub.token)
    gui.ResetOnSpawn, gui.Enabled, gui.IgnoreGuiInset = false,false,true
    gui.DisplayOrder = 350
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = pg
    u.gui = gui
    local folder = Instance.new("Folder")
    scope:add(function() folder:Destroy() end)
    folder.Name,folder.Parent = gui.Name .. "_Outlines",bridge.Workspace
    local frame = round(make("Frame",{Size = UDim2.fromOffset(704,505),
        Position = UDim2.fromScale(.5,.5), AnchorPoint = Vector2.new(.5,.5),
        BackgroundColor3 = palette.bg, BorderSizePixel = 0, Active = true},gui),15)
    u.frame = frame
    local scale = make("UIScale",{Scale=1},frame)
    u.scale=scale
    local side = round(make("Frame",{Size = UDim2.fromOffset(165,505),
        BackgroundColor3 = palette.side, BorderSizePixel = 0},frame),15)
    text(side,"F E R A L",18,22,130,28,20)
    u.versionLabel=text(side,"RENAISSANCE  /  "..tostring(hub.version),18,52,140,18,10,palette.same)
    local content = make("Frame",{BackgroundTransparency = 1,Position = UDim2.fromOffset(181,17),
        Size = UDim2.fromOffset(511,470)},frame)
    local title = text(content,u.tab,10,0,470,30,19)
    local subtitle = text(content,"Simple controls. Native gameplay remains in charge.",10,34,480,20,11,palette.sub)
    local cards = make("ScrollingFrame",{BackgroundTransparency = 1,BorderSizePixel=0,
        Position = UDim2.fromOffset(10,68),Size = UDim2.fromOffset(490,365),
        CanvasSize=UDim2.fromOffset(0,365),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollBarThickness=3,ScrollBarImageColor3=palette.line,ScrollingDirection=Enum.ScrollingDirection.Y,
        ClipsDescendants=true},content)
    text(content,"Client changes and predictions · gameplay results unverified",10,440,485,18,10,palette.sub)
    local footer = text(side,"Ready",14,452,140,39,10,palette.sub)
    footer.TextWrapped = true
    local hide = button(side,"HIDE  ·  RIGHT SHIFT",12,378,141,30)
    local unload = button(side,"UNLOAD",12,414,141,27)
    local launcher = button(gui,"FERAL",16,16,82,34)
    launcher.Position=UDim2.new(0,16,1,-50)
    launcher.Visible=false
    u.launcher=launcher
    local tabs = {}
    local function card(y,height)
        return round(make("Frame",{Position = UDim2.fromOffset(0,y),Size = UDim2.fromOffset(490,height),
            BorderSizePixel = 0,BackgroundColor3 = palette.panel},cards),9)
    end
    local function info(y,heading,body,height)
        local c = card(y,height or 75)
        text(c,heading,14,8,460,20,13,palette.same)
        local t = text(c,body,14,33,459,(height or 75)-37,11,palette.sub)
        t.TextWrapped = true
        return t
    end
    local function row(id,y)
        local f = hub.registry.byId[id]
        local c = card(y,50)
        text(c,f.title,13,4,365,21,13)
        local status = text(c,f.detail,13,27,365,18,10,palette.sub)
        local toggle = button(c,"OFF",394,9,82,32)
        u.rows[id] = { toggle = toggle, status = status }
        toggle.Activated:Connect(function()
            if not hub.active then return end
            hub:set(id,not hub.registry.byId[id].requested)
            u.nextText = 0
        end)
    end
    local function draw()
        if u.pageView and u.pageView.close then pcall(u.pageView.close,u.pageView) end
        u.pageView=nil
        for _, child in ipairs(cards:GetChildren()) do child:Destroy() end
        cards.CanvasPosition=Vector2.new(0,0)
        u.rows,u.combatReadout,u.finderReadout = {},nil,nil
        title.Text = string.upper(u.tab)
        subtitle.Text="Simple controls. Native gameplay remains in charge."
        if u.pages[u.tab] then
            u.pageView=u.pages[u.tab]:mount(cards,{
                text=text,button=button,palette=palette,make=make,card=card})
            subtitle.Text="Automatic territory, survival and native movement in one hub."
        elseif u.tab=="Territory" then
            info(0,"TERRITORY FARMING","Territory controls initialise with this hub. If unavailable, reload the current Renaissance launcher.",100)
        elseif u.tab == "Combat" then
            row("reach",0)
            row("biteHelper",57)
            info(124,"BITE GUIDE","OFF for experimental reach preserves normal game geometry. Cobra: teal in stock range; amber is unverified extended range. Grey means blocked or uncertain.",80)
            u.combatReadout = info(221,"NATIVE COMBAT","Waiting for an animal.",100)
        elseif u.tab == "Vision" then
            row("esp",0); row("tags",57)
            local c = card(123,52)
            text(c,"Tracking range",14,8,270,20,13)
            text(c,"Real players only · up to 24",14,29,320,17,10,palette.sub)
            local range = button(c,tostring(hub.settings.range) .. " STUDS",350,10,124,30)
            range.Activated:Connect(function()
                if not hub.active then return end
                local old = hub.settings.range
                hub.settings.range = old == 300 and 600 or old == 600 and 900 or 300
                range.Text = tostring(hub.settings.range) .. " STUDS"
                hub:save(); hub.nextScan = 0
            end)
            local walls = button(cards,"Through-wall outlines: " .. (hub.settings.walls and "ON" or "OFF"),0,187,490,32)
            walls.Activated:Connect(function()
                if not hub.active then return end
                hub.settings.walls = not hub.settings.walls
                walls.Text = "Through-wall outlines: " .. (hub.settings.walls and "ON" or "OFF")
                hub:save()
            end)
            info(232,"HEALTH / PACK","Outlines: green → yellow → red as HP falls. Real players only; name colour shows pack.",70)
            u.finderReadout = info(313,"PLAYER FINDER","Waiting for replicated players.",50)
        else
            local order = u.tab == "Survival"
                and {"stamina","recovery","escape","robloxAFK","survivalAFK","minigame"}
                or {"climb","flight","mobility","speed","leap","zoom"}
            for i,id in ipairs(order) do row(id,(i-1)*57) end
        end
        for name,btn in pairs(tabs) do btn.BackgroundColor3 = name == u.tab and Color3.fromRGB(27,111,98) or palette.panel end
        u.nextText = 0
    end
    for i,name in ipairs({"Survival","Combat","Movement","Vision","Territory"}) do
        local btn = button(side,string.upper(name),12,113+(i-1)*44,141,35)
        tabs[name] = btn
        btn.Activated:Connect(function()
            if not hub.active then return end
            u:selectTab(name)
        end)
    end
    function u:selectTab(name)
        if not tabs[name] then return false end
        self.tab,hub.settings.tab=name,name
        draw();if hub.active then hub:save() end
        return true
    end
    function u:registerPage(name,definition)
        assert(tabs[name] and type(definition.mount)=="function","Unsupported hub page")
        self.pages[name]=definition
        if self.tab==name then draw() end
        local registration={closed=false}
        function registration:close()
            if self.closed then return end
            self.closed=true
            if u.pages[name]==definition then
                u.pages[name]=nil
                if u.tab==name and not hub.closed then draw() end
            end
        end
        return registration
    end
    function u:toggle()
        self.visible = not self.visible
        self.drag=nil
        frame.Visible = self.visible
        launcher.Visible = not self.visible
        hub.policy.menuOpen = self.visible
        self.nextText=0
        if self.visible then hub:stopWalk("menu opened") end
    end
    function u:contains(point)
        if not gui.Enabled then return false end
        local surface=self.visible and frame or launcher
        if not surface.Visible then return false end
        local p,s = surface.AbsolutePosition,surface.AbsoluteSize
        return point.X >= p.X and point.X <= p.X+s.X and point.Y >= p.Y and point.Y <= p.Y+s.Y
    end
    function u:fit()
        local camera=bridge.Workspace.CurrentCamera
        local amount,centre=UI.fit(camera and camera.ViewportSize,self.windowCentre)
        if not amount then return end
        self.windowCentre=centre
        assign(scale,"Scale",amount)
        if self.windowX~=centre.X or self.windowY~=centre.Y then
            self.windowX,self.windowY=centre.X,centre.Y
            frame.Position=UDim2.fromOffset(centre.X,centre.Y)
        end
    end
    function u:beginDrag(point,input)
        if not hub.active or not self.visible or not self:contains(point) then return false end
        if point.Y>frame.AbsolutePosition.Y+76*scale.Scale then return false end
        self.drag={origin=point,centre=self.windowCentre or frame.AbsolutePosition+frame.AbsoluteSize*.5,input=input}
        return true
    end
    function u:moveDrag(point)
        if not self.drag or not self.visible then return end
        self.windowCentre=self.drag.centre+point-self.drag.origin
        self:fit()
    end
    local inputService=bridge.UserInputService
    local function pointOf(input)
        if input.UserInputType==Enum.UserInputType.Touch and input.Position then
            return Vector2.new(input.Position.X,input.Position.Y)
        end
        return inputService:GetMouseLocation()
    end
    local function listen(signal,callback)
        local connection=signal:Connect(callback)
        scope:add(function()connection:Disconnect()end)
    end
    listen(inputService.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            u:beginDrag(pointOf(input),input)
        end
    end)
    listen(inputService.InputChanged,function(input)
        if u.drag and (input==u.drag.input or input.UserInputType==Enum.UserInputType.MouseMovement) then
            u:moveDrag(pointOf(input))
        end
    end)
    listen(inputService.InputEnded,function(input)
        if u.drag and (input==u.drag.input or input.UserInputType==Enum.UserInputType.MouseButton1) then u.drag=nil end
    end)
    hide.Activated:Connect(function() if hub.active then u:toggle() end end)
    launcher.Activated:Connect(function() if hub.active then u:toggle() end end)
    unload.Activated:Connect(function() if hub.active then hub:close() end end)
    local dot = round(make("Frame",{Name = "BiteRangeMarker",BackgroundTransparency = 1,
        Size = UDim2.fromOffset(15,15),AnchorPoint = Vector2.new(.5,.5),Visible = false},gui),50)
    local dotStroke = make("UIStroke",{Thickness = 1.5,Transparency = .05,Color = palette.same},dot)
    u.dot,u.dotStroke=dot,dotStroke
    function u:syncTracked(tracked)
        local keep = {}
        for _, target in ipairs(tracked) do
            if not target.player or bridge.Players:GetPlayerFromCharacter(target.char) ~= target.player then continue end
            local char = target.char
            keep[char] = true
            local record = self.records[char]
            if not record then
                local highlight = Instance.new("Highlight")
                highlight.Name,highlight.Adornee = "Outline",char
                highlight.FillTransparency,highlight.OutlineTransparency = 1,0
                highlight.Enabled,highlight.Parent = false,folder
                local label = text(gui,"",0,0,180,18,11)
                label.TextXAlignment, label.AnchorPoint = Enum.TextXAlignment.Center,Vector2.new(.5,1)
                record = { highlight = highlight,label = label }
                self.records[char] = record
            end
            record.target = target
            record.head=char:FindFirstChild("Head")
        end
        for char,record in pairs(self.records) do
            if not keep[char] then
                record.highlight:Destroy(); record.label:Destroy()
                self.records[char] = nil
            end
        end
    end
    function u:render(dt,now)
        local camera = bridge.Workspace.CurrentCamera
        if not camera then
            for _,record in pairs(self.records) do
                assign(record.highlight,"Enabled",false);assign(record.label,"Visible",false)
            end
            assign(dot,"Visible",false)
            self.lastPoint,self.lastTarget=nil,nil
            return
        end
        if now >= self.nextFit then
            self.nextFit = now+.5
            self:fit()
        end
        local registry = hub.registry.byId
        for char,record in pairs(self.records) do
            local target = record.target
            local valid = target.player and target.player.Parent~=nil and target.player.Character==char
                and char.Parent ~= nil and target.root and target.root.Parent ~= nil
                and target.hum and target.hum.Parent ~= nil and target.hum.Health > 0
            valid=valid==true
            local colour = palette[target.affiliation] or palette.unknown
            assign(record.highlight,"FillTransparency",1)
            if valid and registry.esp.requested then
                local hp,maxHP=target.hum.Health,target.hum.MaxHealth
                if record.hp~=hp or record.maxHP~=maxHP then
                    record.hp,record.maxHP=hp,maxHP
                    record.healthColour=UI.healthColour(hp,maxHP)
                end
                assign(record.highlight,"OutlineColor",record.healthColour)
                assign(record.highlight,"DepthMode",hub.settings.walls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded)
            end
            assign(record.highlight,"Enabled",valid and registry.esp.requested)
            local projected,onScreen
            if valid and registry.tags.requested then
                local head=record.head
                local pos=head and head.Parent and head:IsA("BasePart") and head.Position+Vector3.new(0,head.Size.Y*.65,0)
                    or target.root.Position+Vector3.new(0,target.root.Size.Y*.6+1,0)
                projected,onScreen=camera:WorldToViewportPoint(pos)
            end
            local show=valid and registry.tags.requested and onScreen==true and projected.Z>0
            assign(record.label,"Visible",show)
            if show then
                local x,y = math.clamp(projected.X,90,math.max(90,camera.ViewportSize.X-90)),math.max(20,projected.Y-6)
                if not record.x or math.abs(x-record.x)>=.25 or math.abs(y-record.y)>=.25 then
                    record.x,record.y=x,y;record.label.Position=UDim2.fromOffset(x,y)
                end
                assign(record.label,"Text",target.name)
                assign(record.label,"TextColor3",colour)
            end
        end
        local guide = hub.guide
        local dotVisible=false
        if registry.biteHelper.requested and guide and not guide.invalid and guide.target.root.Parent then
            local point,onScreen = camera:WorldToViewportPoint(guide.target.root.Position)
            if onScreen and point.Z > 0 then
                local desired = Vector2.new(point.X,point.Y)
                if self.lastTarget~=guide.target.char then self.lastPoint=nil;self.lastTarget=guide.target.char end
                self.lastPoint = self.lastPoint and self.lastPoint:Lerp(desired,1-math.exp(-22*math.min(dt,.1))) or desired
                if self.dotX~=self.lastPoint.X or self.dotY~=self.lastPoint.Y then
                    self.dotX,self.dotY=self.lastPoint.X,self.lastPoint.Y
                    dot.Position=UDim2.fromOffset(self.dotX,self.dotY)
                end
                dotVisible = true
                local readiness=hub.biteReadiness
                local stale=now-(hub.guideAt or -math.huge)>.35
                local locked=not readiness or not readiness.ready
                local species=hub.snapshot and hub.snapshot.species
                assign(dotStroke,"Color",palette[UI.markerTone(species,not (guide.blocked or locked or stale),
                    guide.baseline and guide.baseline.valid)])
            else self.lastPoint,self.lastTarget=nil,nil end
        else self.lastPoint,self.lastTarget = nil,nil end
        assign(dot,"Visible",dotVisible)
        if not self.visible then return end
        if now < self.nextText then return end
        self.nextText = now+.25
        if self.pageView and self.pageView.tick then self.pageView:tick(now) end
        for id,rowValue in pairs(self.rows) do
            local feature = registry[id]
            assign(rowValue.toggle,"Text",not feature.requested and "OFF"
                or feature.applied and (feature.state == "PARTIAL" and "PARTIAL"
                    or feature.state == "ARMED" and "ARMED" or "ON") or "WAIT")
            assign(rowValue.toggle,"BackgroundColor3",feature.requested and feature.applied
                and (feature.state == "PARTIAL" and palette.unknown or palette.on) or palette.off)
            assign(rowValue.status,"Text",feature.requested and feature.reason ~= "" and feature.reason or feature.detail)
        end
        assign(footer,"Text",hub.rescue.pending and hub.rescue.status
            or hub.feeding.busy and hub.feeding.status or hub.notice or "Right Shift opens menu")
        if self.combatReadout then
            assign(self.combatReadout,"Text",(hub.biteReadiness and hub.biteReadiness.reason or "Native timing unmeasured")
                .."\n"..(hub.combatStatus or "Watching native attacks") .. "\n" .. hub.rescue.status)
        end
        if self.finderReadout then
            assign(self.finderReadout,"Text",string.format("%d shown · %d in range · %.0f studs",#bridge.tracked,bridge.replicatedCount or 0,hub.settings.range))
        end
    end
    function u:activate()
        gui.Enabled = true
        hub.policy.menuOpen = self.visible
    end
    draw()
    return u
end
return UI
