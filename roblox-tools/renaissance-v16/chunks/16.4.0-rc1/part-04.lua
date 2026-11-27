ers=self.biteCount,activeIntervals=n,
            meanSeconds=seconds,minSeconds=minimum,maxSeconds=maximum,
            measuredBitesPerSecond=seconds and 1/seconds or nil}
    end
    function t:report(recent)
        local counts,rates=self:ledgerSummary()
        local events=self.events
        if recent then
            events={}
            for i=math.max(1,#self.events-39),#self.events do table.insert(events,self.events[i]) end
        end
        return {schema=SCHEMA,version=hub.version,sourceFingerprint=hub.sourceFingerprint,
            placeId=game.PlaceId,placeVersion=game.PlaceVersion,
            savedAt=os.time(),source="own client observations; server damage reduction unverified",
            events=events,samples=self.samples,species=self.species,snapshot=self:snapshot(),
            features=self:featureStates(),ledgerCounts=counts,ledgerRates=rates,
            biteCadence=self:biteCadence(),middleRepeat=hub.combatInput:middleReport(),leftHold=hub:desktopHoldReport(),
            recording=self.enabled,oneShotAttempts=self.attempts,reportPath=PATH}
    end
    function t:bridgeReport() return self:report(true) end
    function t:save()
        if not io.available then
            self.notice="Local file writing unavailable";return false
        end
        local ok,result=pcall(io.write,PATH,self:report())
        self.saved=ok and result~=false
        if self.saved then
            self.dirty=false
            self.nextSave=bridge.clock()+8
            self.notice="Saved "..PATH
        else self.notice="Could not save report" end
        return self.saved
    end
    function t:copy()
        local ok,raw=pcall(bridge.HttpService.JSONEncode,bridge.HttpService,self:report())
        if not ok then self.notice="Report encoding failed";return false end
        if type(setclipboard)=="function" then
            local copied=pcall(setclipboard,raw)
            if copied then self.notice="Report copied to clipboard";return true end
        end
        self:save()
        self.notice="Clipboard unavailable; report saved locally"
        return false
    end
    function t:setEnabled(on)
        if self.enabled==(on==true) then return end
        self.enabled=on==true
        self.dirty=true
        if self.enabled then self:record("recording_enabled") end
        self:save()
    end
    function t:tick(now,critical)
        if not self.active or self.closed or not self.enabled or critical then return end
        if now>=self.nextSample then
            self.nextSample=now+15
            local sample=self:snapshot()
            sample.at=now
            table.insert(self.samples,sample)
            if #self.samples>60 then table.remove(self.samples,1) end
            self.dirty=true
        end
        if self.dirty and now>=self.nextSave then self:save() end
    end
    function t:summary()
        local s=self:snapshot()
        local totals=self.species[s.species]
        return string.format("%s · HP %s/%s · Rest %s\n%s · %d events · %d damage samples\n%s",
            s.species,tostring(s.hp or "?"),tostring(s.maxHP or "?"),
            s.rest and "ON" or "OFF",self.enabled and "Recording" or "Paused",
            #self.events,totals and totals.hits or 0,
            self.saved and "Local report saved · PC sync pending" or "Waiting for local report")
    end
    function t:start()
        self.active=true
        self:record("session_started",self:snapshot())
        self:save()
    end
    function t:close()
        if self.closed then return end
        if self.pending then self:release("hub unload") end
        self:record("session_stopped",self:snapshot())
        self:save()
        self.active=false;self.closed=true
        self.characterScope:close()
    end
    return t
end
return Tests
]============]
sources["ui"] = [============[
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
        u.rows,u.combatReadout,u.finderReadout,u.hippoReadout,u.testsReadout,u.testsToggle = {},nil,nil,nil,nil,nil
        title.Text = string.upper(u.tab)
        subtitle.Text="Simple controls. Native gameplay remains in charge."
        if u.pages[u.tab] then
            u.pageView=u.pages[u.tab]:mount(cards,{
                text=text,button=button,palette=palette,make=make,card=card})
            subtitle.Text="Automatic territory, survival and native movement in one hub."
        elseif u.tab=="Territory" then
            info(0,"TERRITORY FARMING","Territory controls initialise with this hub. If unavailable, reload the current Renaissance launcher.",100)
        elseif u.tab == "Combat" then
            row("reach",0);row("biteHelper",57);row("attackSpeed",114);row("holdBite",171);row("autoBite",228)
            info(285,"NATIVE HOLD BITE","Tap and manual spam normally. Hold the same left mouse button for 0.28s to repeat using original WolfController callbacks. No synthetic mouse clicks. Faster Bites scheduling stays ON; WAITING means game handler inaccessible.",85)
            u.combatReadout = info(365,"NATIVE COMBAT","Waiting for an animal.",100)
        elseif u.tab == "Hippo" then
            info(0,"CRUSHER BITE","Hold your normal ability control. Charge movement and release assistance apply only to Hippo.",65)
            row("hippoMove",74);row("hippoRelease",131)
            u.hippoReadout=info(193,"CHARGE","Waiting for Hippo.",106)
            info(309,"POWER LIMIT","Damage beyond full charge and shorter ability cooldowns remain unverified.",55)
        elseif u.tab == "Test Features" then
            subtitle.Text="Own-character observations for every animal."
            info(0,"DAMAGE & ABILITY EVIDENCE","Records HP loss, Rest, effects, Hippo replies and hub feature states. The client shell formula is not proof of protection.",60)
            u.testsReadout=info(68,"LIVE RECORDER","Waiting for your animal.",96)
            local save=button(cards,"SAVE REPORT",0,174,238,34)
            save.Activated:Connect(function()
                if hub.active then hub.tests:save();u.nextText=0 end
            end)
            local copy=button(cards,"COPY REPORT",252,174,238,34)
            copy.Activated:Connect(function()
                if hub.active then hub.tests:copy();u.nextText=0 end
            end)
            u.testsToggle=button(cards,"RECORDING: ON",0,216,490,34)
            u.testsToggle.Activated:Connect(function()
                if hub.active then hub.tests:setEnabled(not hub.tests.enabled);u.nextText=0 end
            end)
            local cross=button(cards,"ONE-SHOT TURTLE / CRUSHER REQUEST",0,258,490,34)
            cross.Activated:Connect(function()
                if hub.active then hub.tests:crossSpecies();u.nextText=0 end
            end)
            info(300,"CONTROLLED TRIAL","Only while naturally resting as Turtle in FERAL v2412. No shell or reduced damage is claimed.",64)
        elseif u.tab == "Vision" then
            row("esp",0); row("tags",57); row("voice",114)
            local c = card(171,52)
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
            local walls = button(cards,"Through-wall outlines: " .. (hub.settings.walls and "ON" or "OFF"),0,231,490,30)
            walls.Activated:Connect(function()
                if not hub.active then return end
                hub.settings.walls = not hub.settings.walls
                walls.Text = "Through-wall outlines: " .. (hub.settings.walls and "ON" or "OFF")
                hub:save()
            end)
            info(269,"HEALTH / PACK","Health-coloured outlines; pack-coloured names.",47)
            u.finderReadout = info(317,"PLAYER FINDER","Waiting for replicated players.",48)
        else
            local order = u.tab == "Survival"
                and {"stamina","recovery","escape","robloxAFK","survivalAFK","minigame"}
                or {"climb","flight","mobility","speed","leap","zoom"}
            for i,id in ipairs(order) do row(id,(i-1)*57) end
        end
        for name,btn in pairs(tabs) do btn.BackgroundColor3 = name == u.tab and Color3.fromRGB(27,111,98) or palette.panel end
        u.nextText = 0
    end
    for i,name in ipairs({"Survival","Combat","Movement","Vision","Territory","Hippo","Test Features"}) do
        local btn = button(side,string.upper(name),12,106+(i-1)*39,141,32)
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
                .."\n"..(hub.combatStatus or "Watching native attacks") .. "\n" .. hub.combatInput.status)
        end
        if self.finderReadout then
            assign(self.finderReadout,"Text",string.format("%d shown · %d in range · %.0f studs",#bridge.tracked,bridge.replicatedCount or 0,hub.settings.range))
        end
        if self.hippoReadout then assign(self.hippoReadout,"Text",hub.hippo:summary()) end
        if self.testsReadout then assign(self.testsReadout,"Text",hub.tests:summary().."\n"..hub.tests.notice) end
        if self.testsToggle then assign(self.testsToggle,"Text",hub.tests.enabled and "RECORDING: ON" or "RECORDING: PAUSED") end
    end
    function u:activate()
        gui.Enabled = true
        hub.policy.menuOpen = self.visible
    end
    draw()
    return u
end
return UI
]============]
sources["controller"] = [============[
local Controller = {}
local LEFT_READY="FERAL_LEFT_HOLD_READY_V1"
local LEFT_INTENT="FERAL_LEFT_HOLD_INTENT_V1"
-- Replies have no recovered transaction identifier. Prefer a matching native
-- target and timing, and retain ambiguity instead of assigning the newest bite.
function Controller.matchFeedback(Core,transactions,data,now)
    if type(data)~="table" or data.v==nil then return nil,false end
    local best,bestRank,matches,abilityOverlap=nil,math.huge,0,false
    for _,tx in ipairs(transactions) do
        local corrected=tx.feedback and not tx.feedback.safe and tx.feedback.v==data.v
            and Core.finite(tx.feedback.dmg) and tx.feedback.dmg==0 and Core.finite(data.dmg) and data.dmg>0
        if tx.nativeAt and not tx.closed and (not tx.feedback or corrected) and now>=tx.nativeAt and now-tx.nativeAt<2.6 then
            local target=tx.focusTarget and tx.focusTarget.char or tx.target and tx.target.char
            local seenVictim=tx.hpBefore and tx.hpBefore[data.v]~=nil
            -- Real FeralHit replies may involve a different nearby victim
            -- than the client's projected target. Prefer exact matches but
            -- allow a unique weaker nearby-victim match.
            local rank=tx.nativeTarget==data.v and 0
                or tx.localTarget==data.v and 1
                or target==data.v and 2
                or seenVictim and 3 or nil
            if rank then
                if tx.abilityAmbiguous then
                    abilityOverlap=true
                elseif rank<bestRank then
                    best,bestRank,matches=tx,rank,1
                elseif rank==bestRank then
                    matches+=1
                end
            end
        end
    end
    -- Neither timing proximity nor a shared target is a transaction ID.
    -- Do not train cadence or label damage when multiple equal candidates fit.
    local ambiguous=abilityOverlap or best~=nil and matches>1
    return not ambiguous and best or nil,ambiguous
end
local function nativeState(native)
    if not native or type(native.state)~="function" then return nil,false end
    local ok,state,known=pcall(native.state)
    if ok then return state,known end
    return nil,false
end
function Controller.new(M,bridge,options)
    local Core = M.core
    local tokenIdentity = {}
    local h = { version = M.release and M.release.version or "unbundled",
        sourceFingerprint = M.release and M.release.sourceFingerprint, tokenIdentity = tokenIdentity,
        token = (tostring(tokenIdentity):gsub("[^%w]","")) .. "_" .. tostring(math.floor(bridge.clock()*1000000)),
        active = false, closed = false, ready = false, inputSuspended=false, scope = Core.scope(),
        registry = Core.registry(), policy = M.policy.new(), ledger = Core.ledger(160),
        nextScan = 0, nextSlow = 0, nextBind = 0, nextSample = 0, nextEscape = 0,
        nextWalk = bridge.clock()+90, nextIdle = bridge.clock()+75,
        transactions = {}, earlyInputs = setmetatable({},{__mode = "k"}),
        notice = "Ready · Right Shift opens menu", bridge = bridge, options = options or {} }
    h.policy.lastPhysical = bridge.clock()
    h.settings,h.settingsOrigin = M.settings.load(bridge:io(),Core.specs)
    if h.options.settings then h.settings = M.settings.sanitize(h.options.settings,Core.specs) end
    if h.options.leftHoldBridge==true then h.settings.states.holdBite=true end
    for _,feature in ipairs(h.registry.order) do
        if not feature.permanent and not feature.linked then h.registry:request(feature.id,h.settings.states[feature.id]) end
    end
    h.features = M.features.new(Core,bridge,h.registry)
    h.grab = M.grab.new()
    h.grabInput = M.grab_input.new(bridge,h.token)
    h.recovery = M.recovery.new(bridge,h.policy,h.ledger)
    h.feeding = M.feeding.new(bridge,h.policy,h.ledger)
    bridge.holdBinding=h.options.holdBinding=="M1" and h.options.leftHoldBridge~=true and "M1" or "M3"
    h.leftHoldBridge=h.options.leftHoldBridge==true
    h.leftHoldIo=bridge:io()
    h.leftHoldAwaitFresh=true
    h.leftHoldEpoch=0
    h.leftHoldToken=h.token.."_0"
    bridge.desktopLeftHold=h.leftHoldBridge
    -- Default M3 to standard input: live 16.2.6 reported six native attempts and zero attributable markers.
    bridge.middleRoutePreference=h.options.middleRoutePreference=="NATIVE" and "NATIVE" or "INPUT"
    h.combatInput = M.combat_input.new(bridge,h.policy,h.ledger)
    bridge.combatGovernor = h.combatInput
    -- Weak keyed: a disappeared animal is never retained by combat trust.
    -- Only Auto Bite pauses unconfirmed extended contacts; manual reach stays.
    h.extendedConfidence=setmetatable({},{__mode="k"})
    bridge.extendedConfidence=h.extendedConfidence
    -- A pending synthetic reset can outlive the current Heartbeat. Never
    -- press during an asynchronously arriving native grab begin.
    -- Only an independently held middle button can own an ordinary-input pulse.
    -- Never compete with a physically held M1 or a native minigame.
    bridge.combatPointBlocked = function(point) return h.ui and h.ui:contains(point) or false end
    -- Desktop ownership is separate from the engine's primary-button poll.
    -- Only a fresh, accepted session can classify the same physical LMB
    -- as the held intent instead of a competing manual click.
    bridge.desktopOwnsPrimary = function(s,now)
        local held=h.combatInput.held
        return h.leftHoldBridge and h.active and not h.closed
            and h.windowFocused~=false and not h.inputSuspended
            and h.registry.byId.holdBite.requested and h.leftHoldArmed==true
            and h.leftHoldIntent==true and not h.leftHoldAwaitFresh
            and h.leftHoldLastAt~=nil and now-h.leftHoldLastAt<=.55
            and held~=nil and held.source=="desktop" and held.key=="M3"
            and held.char==s.char and held.generation==s.generation
            and s.alive and not s.chat and not s.gameMenu
    end
    bridge.combatPulseBlocked = function()
        if bridge.holdBinding~="M3" then return true end
        local held=h.combatInput.held
        local desktop=held and held.source=="desktop"
        local fresh=desktop and bridge.desktopOwnsPrimary({char=bridge.player.Character,
            generation=bridge.generation,alive=true},bridge.clock())
        return h.closed or not h.active or h.inputSuspended or h.windowFocused==false
            or not h.registry.byId.holdBite.requested
            or not held or held.key~="M3" or held.upSince~=nil
            or desktop and not fresh
            or h.physicalM1Input~=nil and not fresh or h:hasNativeGrab(bridge.clock())
            or h.grabInput.lease~=nil
            or bridge:protectedInteraction(bridge.player.Character)~=nil
            or bridge.UserInputService:GetFocusedTextBox()~=nil
            or h.ui:contains(bridge.UserInputService:GetMouseLocation())
    end
    h.rescue = M.rescue.new(bridge,h.ledger)
    h.hippo = M.hippo.new(Core,bridge,h.ledger)
    h.tests = M.test_features.new(Core,bridge,h)
    h.zoom = M.zoom.new(bridge.player)
    h.voice = M.voice.new(bridge.Players,bridge.player)
    h.settingsAvailable = bridge:io().available ~= false
    function h:hasNativeGrab(now)
        if self.grab.active then return true end
        local observed=self.nativeGrabSession
        return observed~=nil and observed.char==bridge.player.Character
            and observed.generation==bridge.generation and now-observed.at<=8
    end
    function h:focusChanged(focused)
        if self.closed then return end
        self.windowFocused=focused==true
        self.middlePollArmed=false;self.middlePollDown=nil
        -- Focus return does not resurrect a hold whose release was missed.
        -- A fresh gameplay input must establish ownership again.
        self.inputSuspended=true
        self.physicalM1Input=nil
        self.combatInput:cancel()
        self:disarmDesktopHold(bridge.clock())
        self:stopWalk("window focus changed")
    end
    function h:observeCombatAbility(s,now)
        if not s.alive then return end
        -- FeralHit does not identify which ordinary bite or ability caused
        -- damage. Keep the real reply, but suspend ordinary-bite attribution
        -- across this bounded overlap rather than training cadence on it.
        self.abilityEvidenceUntil=now+2.6
        for _,tx in ipairs(self.transactions) do
            if tx.generation==s.generation and tx.nativeAt and not tx.closed
                and not tx.feedback and not tx.abilityAmbiguous
                and now>=tx.nativeAt and now-tx.nativeAt<2.6 then
                tx.abilityAmbiguous,tx.rateEligible,tx.dirty=true,false,true
            end
        end
    end
    function h:save()
        if self.closed then return false end
        for id in pairs(self.settings.states) do self.settings.states[id] = self.registry.byId[id].requested end
        local ok,why = M.settings.save(bridge:io(),self.settings,Core.specs)
        self.settingsAvailable = ok
        self.registry:ack("settings",ok,ok and "CLIENT" or "UNAVAILABLE",why)
        if not ok then self.notice = "Settings stay in memory · saving unavailable" end
        return ok
    end
    function h:stopWalk(reason)
        local walk = self.walk
        self.walk = nil
        if walk then
            pcall(bridge.walk,bridge,walk.snapshot,nil)
            self.ledger:event("afk_walk_stopped",bridge.clock(),{reason = reason})
        end
    end
    function h:clearFlight()
        self:releaseFlightRepair()
        self.flightEpisode,self.flightStatus=nil,nil
        self:releaseSurface()
        if self.drop then
            bridge:restoreAttribute(self.drop.char,"FeralFlyDrop",true,self.drop.before)
            self.drop = nil
        end
    end
    function h:releaseSurface()
        self.features.leases:release("surface")
        self.surfaceUntil = nil
        local request=self.surfaceRequest;self.surfaceRequest=nil
        if request then
            bridge:restoreAttribute(request.char,"FeralFlyRequest",request.value,request.before)
        end
    end
    function h:releaseFlightRepair()
        local r=self.flightRepair;self.flightRepair=nil
        if r then
            bridge:restoreAttribute(r.char,"FeralFlyDrop",true,nil)
            bridge:restoreAttribute(r.char,"FeralFlyRelaunch",r.at,nil)
        end
    end
    function h:noteFlightCancel(input,s,now)
        if not self.registry.byId.flight.requested or self:hasNativeGrab(now)
            or s.talonLock==nil then return false end
        local config=bridge:config("FlightConfig")
        local compatible,eligible=pcall(function() return config.canFly(s.char) end)
        if not compatible or eligible~=true then return false end
        -- The captured Talon controller owns Space/ButtonB for any eligible
        -- animal using this binding. Dive has a different native cancel path.
        local info=bridge.ContextActionService:GetAllBoundActionInfo().FeralTalonLetGo
        for _,key in ipairs(info and info.inputTypes or {}) do
            if key==input.KeyCode then
                local q=self.flightEpisode
                if not q or q.char~=s.char or q.lock~=s.talonLock then
                    q={char=s.char,generation=s.generation,lock=s.talonLock,at=now}
                    self.flightEpisode=q
                end
                q.cancelAt=now
                q.airborne=q.airborne or s.flying or s.hum.FloorMaterial==Enum.Material.Air
                return true
            end
        end
        return false
    end
    function h:stepFlightHandoff(s,now)
        if self.flightRepair then
            local r=self.flightRepair
            if not s.alive or r.char~=s.char or r.generation~=s.generation or s.grab or s.captured or s.ability or s.chat or s.gameMenu
                or now-r.at>1.5 then self:releaseFlightRepair()
            elseif (s.root.Position-r.position).Magnitude>1.5 and s.root.AssemblyLinearVelocity.Magnitude>2 then
                self.flightStatus="Movement observed after native restart; cause unverified"
                self.ledger:event("post_attack_flight_motion_observed",now)
                self:releaseFlightRepair()
            end
        end
        if not self.registry.byId.flight.requested or not s.alive then self.flightEpisode=nil;return end
        local config=bridge:config("FlightConfig")
        if not config or type(config.canFly)~="function" then self.flightEpisode=nil;return end
        local compatible,eligible=pcall(config.canFly,s.char)
        if not compatible or eligible~=true then
            self.flightEpisode=nil;return
        end
        local q=self.flightEpisode
        local lock,kind=s.talonLock,"talon"
        if lock==nil then lock,kind=s.diveLock,"dive" end
        if lock~=nil then
            if not q or q.char~=s.char or q.lock~=lock or q.kind~=nil and q.kind~=kind then
                q={char=s.char,generation=s.generation,lock=lock,kind=kind,at=now};self.flightEpisode=q
            end
            q.airborne=q.airborne or s.flying or s.hum.FloorMaterial==Enum.Material.Air
            -- Replay only an actual native let-go intent, once for this session.
            -- Server/native cleanup owns anchoring and capture restrictions.
            if kind=="talon" and q.cancelAt and not q.releaseRetried and now-q.cancelAt>=1 and now-q.cancelAt<3
                and not s.grab and not s.captured and not s.chat and not s.gameMenu then
                q.releaseRetried=true
                local sent=bridge:fire("FeralLunge","release")
                self.flightStatus="Native attack release retried; response unconfirmed"
                self.ledger:event("native_talon_release_retried",now,{sent=sent})
            end
            return
        end
        if not q or q.char~=s.char or q.generation~=s.generation then self.flightEpisode=nil;return end
        if not q.airborne then self.flightEpisode=nil;return end
        q.ended=q.ended or now
        if now-q.ended>4 then self.flightEpisode=nil;return end
        if s.grab or s.captured or s.ability or s.chat or s.gameMenu or s.underwater or s.swimming
            or s.climbing or s.attackHeld or s.root.Anchored or s.hum.FloorMaterial~=Enum.Material.Air
            or s.hum.MoveDirection.Magnitude<=.13 or s.root.AssemblyLinearVelocity.Magnitude>=.6 then q.stillAt=nil;return end
        local vel=s.root:FindFirstChild("FeralFlyVel")
        local rot=s.root:FindFirstChild("FeralFlyRot")
        if not s.flying or not vel or not vel:IsA("LinearVelocity") or not rot or not rot:IsA("AlignOrientation") then return end
        q.stillAt=q.stillAt or now
        if now-q.stillAt<.75 or q.restarted or self.timingCritical then return end
        if bridge:attribute(s.char,"FeralFlyDrop")~=nil or bridge:attribute(s.char,"FeralFlyRelaunch")~=nil then return end
        -- v2412 FeralFlight consumes these normal drop/relaunch intents. Never
        -- edit native movers, anchors, velocities, capture flags or positions.
        q.restarted=true
        self.flightRepair={char=s.char,generation=s.generation,at=now,position=s.root.Position}
        local a=bridge:setAttribute(s.char,"FeralFlyRelaunch",now)
        local b=a and bridge:setAttribute(s.char,"FeralFlyDrop",true)
        if not b then self:releaseFlightRepair() end
        self.flightStatus=b and "Native flight restart requested; movement unconfirmed" or "Native restart unavailable"
        self.ledger:event("post_attack_native_flight_restart",now,{sent=b==true})
    end
    function h:set(id,on)
        if self.closed or not self.active then return false end
        local feature = assert(self.registry.byId[id],"unknown feature")
        if feature.permanent or feature.linked then return false end
        self.registry:request(id,on)
        self.tests:record("feature_changed",{feature=id,requested=on==true})
        local now = bridge.clock()
        if id == "recovery" and not on then self.recovery.enabled = false; self.recovery:release("OFF",now) end
        if id == "minigame" then
            self.grab.enabled = on == true
            if not on then self.grab:reset("OFF"); self.grabInput:release();self:cancelGrabWake() end
        end
        if id == "survivalAFK" and not on then self:stopWalk("disabled") end
        if id == "flight" and not on then self:clearFlight() end
        if id == "robloxAFK" then self.idleUnavailable = nil end
        if id == "climb" and not on then self.climbQueue = nil end
        if id=="autoBite" and not on then self.combatInput:pause("auto bite disabled",now) end
        if id=="holdBite" and not on then
            self.middlePollArmed=false
            self.physicalM1Input=nil
            self.combatInput:cancel()
            self:disarmDesktopHold(now)
        end
        if id=="attackSpeed" then bridge.biteTiming=nil;self.combatInput.nextAttempt=0;self.combatInput:resetRate() end
        if id=="voice" then self.voice:setEnabled(on) end
        self.features.nextReconcile = 0
        local s = bridge:snapshot(now,false)
        self.features:reconcile(s,now,true) -- both true AND false are reconciled
        if id=="reach" then
            self.guide,self.guideAt=nil,nil
            self.nextScan=0
            self.policy.combatApproachUntil=0
        end
        self:ackLocal(s)
        self:save()
        return self.registry.byId[id].applied == (on == true)
    end
    function h:characterChanged(generation)
        local now = bridge.clock()
        bridge:paintHippoGait(nil)
        self.recovery:release("animal changed",now)
        self.recovery:clearPose()
        self.recovery.lastAutomaticCharacter,self.recovery.previous = nil,nil
        self.recovery.observations,self.recovery.nativeEchoObserved = {},false
        self.recovery.conditionChar,self.recovery.conditionSeenUntil,self.recovery.conditionSeen=nil,0,{}
        self.recovery.backoffUntil,self.recovery.nextObserve=0,0
        self.recovery.releaseFailedChar,self.recovery.releasingChar=nil,nil
        bridge:clearCombatTargets()
        bridge.biteTiming,bridge.deferNativeDiscovery=nil,false
        self.policy.manualRest,self.policy.manualIntentUntil = false,0
        self.nativeGrabBusy,self.nativeGrabSession,self.nativeGrabUntil=false,nil,nil
        self.abilityEvidenceUntil=nil
        self.policy.attackUntil,self.policy.actionUntil,self.policy.lastRestRelease=0,0,-math.huge
        self.policy.combatApproachUntil=0
        self.grab:reset("animal changed")
        self.nativeGrabSession=nil
        self:cancelGrabWake()
        self.grabInput:release()
        bridge:releaseSyntheticBite()
        self.feeding:close(now)
        self.combatInput:cancel()
        self:disarmDesktopHold(now)
        self.middlePollArmed=false;self.middlePollDown=nil
        self.physicalM1Input=nil;self.physicalM1MissingSince=nil
        self.combatInput:resetRate()
        self.extendedConfidence=setmetatable({},{__mode="k"})
        bridge.extendedConfidence=self.extendedConfidence
        self.hippo:reset()
        self.rescue:cancel("animal changed")
        self:stopWalk("animal changed")
        self:clearFlight()
        self.features:releaseFlag()
        self.features.nextReconcile = 0
        self.climbQueue,self.guide,self.transactions,self.lastIntent = nil,nil,{},nil
        self.snapshot=nil
        self.ledger.previous = nil
        self.ledger.staminaObservation=nil
        self.lastSurvival,self.lastGrabClock,self.lastGrabPending,self.combatStatusAt=nil,nil,nil,nil
        self.combatStatus,self.biteReadiness=nil,nil
        self.nextScan,self.nextSlow,self.nextSample,self.nextGrabPoll=0,0,0,0
        self.anchor,self.anchorChar = nil,nil
        self.ledger:event("character_generation",now,{generation = generation})
        self.tests:characterChanged(bridge.character)
        self.nextWalk = now+90
        self.nextFlight,self.nextEscape,self.rescue.nextAt=0,0,0
    end
    function h:physicalInput(kind)
        local now = bridge.clock()
        if kind == "mouse" and now < (self.syntheticUntil or 0) then return end
        self.policy.lastPhysical = now
        self:stopWalk("manual input")
        self.nextWalk = now+90
        self.anchor,self.anchorChar = nil,nil
    end
    function h:isRestControl(input)
        local point = input.Position
        if not point then return false end
        local pg = bridge.player:FindFirstChildOfClass("PlayerGui")
        local ok,objects = pcall(function() return pg:GetGuiObjectsAtPosition(point.X,point.Y) end)
        if not ok then return false end
        for _,object in ipairs(objects) do
            if not object:IsDescendantOf(self.ui.gui) then
                local node = object
                for _ = 1,4 do
                    if not node then break end
                    local body = node.Name
                    if node:IsA("TextButton") or node:IsA("TextLabel") then body = node.Text end
                    body=string.upper(body):match("^%s*(.-)%s*$")
                    if node.Name=="FeralRestTap" or node.Name=="WolfRest" or node.Name=="RestButton"
                        or body=="REST" or body=="REST [R]" or body=="REST (R)" or body=="STAND UP" then return true end
                    node = node.Parent
                end
            end
        end
        return false
    end
    function h:isFeedControl(input)
        local point=input.Position
        local pg=bridge.player:FindFirstChildOfClass("PlayerGui")
        if not point or not pg then return false end
        local ok,objects=pcall(pg.GetGuiObjectsAtPosition,pg,point.X,point.Y)
        if not ok then return false end
        for _,object in ipairs(objects) do
            if not object:IsDescendantOf(self.ui.gui) then
                local node=object
                for _=1,4 do
                    if not node then break end
                    local text=(node:IsA("TextLabel") or node:IsA("TextButton")) and node.Text or ""
                    text=string.upper(text):match("^%s*(.-)%s*$")
                    if text=="EAT" or text=="DRINK" or node.Name=="FeralFeedTap" then return true end
                    node=node.Parent
                end
            end
        end
        return false
    end
    function h:carryInput(input)
        if not self.active or self.closed or bridge:grabTextFocused() then return false end
        local now=bridge.clock()
        local s=bridge:snapshot(now,true);s.grab=self:hasNativeGrab(now)
        local handled=self.rescue:input(s,now)
        if handled then
            self.earlyInputs[input]=now
            self:physicalInput("other")
            self.policy:input("action",now)
            self.recovery:release("cub rescue input",now)
            self.combatInput:cancel()
            self:stopWalk("cub rescue input")
        end
        return handled
    end
    function h:preInput(input)
        if self.closed or not self.active or bridge.UserInputService:GetFocusedTextBox() then return end
        local now,key,kind = bridge.clock(),input.KeyCode,input.UserInputType
        -- Once this real physical M1 has been held long enough for the
        -- hub to own repeat, no *second* InputBegan can originate from that
        -- same uninterrupted hardware press. Ignore any later replay echo
        -- even when the executor delivers it after the short grace window.
        -- It still reaches FERAL's original InputBegan listener normally.
        if bridge.holdBinding=="M1" and kind==Enum.UserInputType.MouseButton1
            and self.physicalM1Input~=nil and input~=self.physicalM1Input
            and self.combatInput.held and self.combatInput.held.handoff
            and not self.ui:contains(bridge.UserInputService:GetMouseLocation()) then
            return
        end
        -- Virtual/executor mouse events may be delivered after the sending API
        -- returns. The short owned replay window is authoritative here; a
        -- synthetic Up can make IsMouseButtonPressed false before its echo.
        if kind==Enum.UserInputType.MouseButton1 and (bridge.syntheticPressing
            or bridge.syntheticM1~=nil or now<(bridge.syntheticM1Until or 0)) then return end
        local previous = self.earlyInputs[input]
        if previous and now-previous < .1 then return end
        self.earlyInputs[input] = now
        local click = kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2
        local primary = kind == Enum.UserInputType.MouseButton1
        local point = bridge.UserInputService:GetMouseLocation()
        if (click or key==Enum.KeyCode.ButtonR2) and self.ui:contains(point) then
            if primary or key==Enum.KeyCode.ButtonR2 then
                self.inputSuspended=true
                self.physicalM1Input=nil
                self.combatInput:cancel()
            end
            return
        end
        local s = bridge:snapshot(now,false)
        if s.gameMenu or self.windowFocused==false then return end
        if primary or key==Enum.KeyCode.ButtonR2 then
            self.inputSuspended=false
            if primary then self.physicalM1Input=input;self.physicalM1MissingSince=nil end
        end
        self.features:hippoInput(s,key)
        if key == Enum.KeyCode.R or key == Enum.KeyCode.ButtonY
            or ((primary or kind == Enum.UserInputType.Touch) and self:isRestControl(input)) then
            self.policy:input("rest",now)
            self.recovery:manual(now)
            self.combatInput:cancel();self.feeding:cancel("manual rest control",now);self.rescue:cancel()
            return
        end
        if self.grab.active and (key == Enum.KeyCode.Space or key == Enum.KeyCode.ButtonA or key == Enum.KeyCode.ButtonR2) then
            self.grab:manual()
            self:cancelGrabWake()
            return
        end
        local flightCancel=(key==Enum.KeyCode.Space or key==Enum.KeyCode.ButtonB) and self:noteFlightCancel(input,s,now)
        if flightCancel then
            self.policy:input("action",now);self.recovery:release("manual native flight release",now)
            self.combatInput:pause("native flight release",now);return
        end
        -- WolfController binds E/ButtonB to native feeding. Preserve flight's
        -- active ButtonB cancellation, which has priority over feeding.
        if key == Enum.KeyCode.E or key==Enum.KeyCode.ButtonB and not (s.ability or s.flying)
            or (primary or kind == Enum.UserInputType.Touch) and self:isFeedControl(input) then
            self.feeding:input(s,now)
            self.policy:input("action",now)
            self.recovery:release("manual feeding input",now)
            self.combatInput:pause("manual feeding input",now);self.rescue:cancel()
            return
        end
        if primary or key == Enum.KeyCode.ButtonR2 then
            self.combatInput:manualAttack(now)
            self.policy:input("attack",now)
            local restReleased=self.recovery:release("attack input",now)
            if primary or key == Enum.KeyCode.ButtonR2 then
                self.feeding:attack(s,now);self.rescue:cancel()
                local tx = { intent = now, input=input,lock = self.policy:restLocked(now),
                    generation = s.generation,restExitFailed=not restReleased }
                self.lastIntent = tx
                table.insert(self.transactions,tx)
                if #self.transactions > 32 then table.remove(self.transactions,1) end
                self.ledger:event("attack_intent",now,{restLock = tx.lock})
                if restReleased then self.combatInput:input(s,now,primary and "M1" or "R2",input)
                else self.combatInput:pause("native Rest exit pending",now) end
            end
        elseif key == Enum.KeyCode.E or key == Enum.KeyCode.F or key == Enum.KeyCode.G
            or key==Enum.KeyCode.Z or key==Enum.KeyCode.X
            or key == Enum.KeyCode.Q or key == Enum.KeyCode.Space then
            self.policy:input("action",now)
            self.recovery:release("manual native action",now)
            -- Preserve a physically held primary attack across temporary
            -- ability/movement actions. Native readiness still gates a bite.
            self.combatInput.pending=nil
            if key ~= Enum.KeyCode.Space then self.rescue:cancel() end
        end
    end
    -- The helper is a local, scoped physical-input remap. These files carry
    -- only the current session token, sequence, readiness and held boolean.
    -- Never execute file contents or accept a signal from an older hub.
    function h:desktopReady(armed,now,force)
        if not self.leftHoldBridge or not self.leftHoldIo.available then return false end
        if not force and self.leftHoldArmed==armed and now<(self.nextLeftReady or 0) then return self.leftHoldReadyWritten==true end
        self.nextLeftReady=now+.12
        self.leftHoldArmed=armed
        local ok,written=pcall(self.leftHoldIo.write,LEFT_READY..".json",{schema=LEFT_READY,
            token=self.leftHoldToken,armed=armed==true})
        self.leftHoldReadyWritten=ok and written~=false
        return self.leftHoldReadyWritten
    end
    function h:disarmDesktopHold(now)
        if not self.leftHoldBridge then return end
        -- A hard boundary changes the input-session identity. Both legacy and
        -- current helpers must then discard the captured press until real Up/Down.
        self.leftHoldEpoch+=1
        self.leftHoldToken=self.token.."_"..tostring(self.leftHoldEpoch)
        self.leftHoldRevoked=true
        self.leftHoldAwaitFresh=true
        self.leftHoldLastAt=nil
        self.leftHoldLastSequence=nil
        self.leftHoldIntent=false
        self.leftHoldPaused,self.leftHoldResumeAt=false,nil
        self:desktopReady(false,now,true)
        local held=self.combatInput.held
        if held and held.source=="desktop" then self.combatInput:release("M3",now) end
    end
    function h:desktopHoldReport()
        local now=bridge.clock()
        return {enabled=self.leftHoldBridge==true,armed=self.leftHoldArmed==true,
            helperConnected=self.leftHoldLastAt~=nil and now-self.leftHoldLastAt<=.55,
            held=self.combatInput.held~=nil and self.combatInput.held.source=="desktop",
            intent=self.leftHoldIntent==true,waitingFresh=self.leftHoldAwaitFresh==true,
            primaryReportedDown=self.leftHoldRawPrimary==true,
            rawPrimaryDuringHold=self.leftHoldRawSamples or 0,
            epoch=self.leftHoldEpoch,helperInstance=self.leftHoldHelperInstance,
            logicalResets=bridge.desktopLogicalResets or 0,
            dispatched=bridge.desktopDispatches or 0,
            reason=self.leftHoldReason}
    end
    function h:desktopHoldTick(s,now,critical)
        if not self.leftHoldBridge then return end
        self.leftHoldRawPrimary=s.mouseHeld==true and not bridge.syntheticM1
        -- In desktop mode, the physical middle button is not the trigger.
        s.middleHeldKnown=true;s.middleHeld=false
        local hard=not self.active or self.closed or self.windowFocused==false
            or not s.alive or s.chat or s.gameMenu or s.captured or self.policy.manualRest
            or not self.registry.byId.holdBite.requested
        if hard then
            if not self.leftHoldRevoked then self:disarmDesktopHold(now) end
        else self.leftHoldRevoked=false end
        if not hard and (critical or self:hasNativeGrab(now) or self.grabInput.lease or s.protectedInteraction) then
            -- Minigames are a temporary pause, not proof that the physical
            -- desktop M1 was released. Disarm the helper's ready heartbeat
            -- and stop owned pulses, but permit a fresh *positive* same-window
            -- helper confirmation after the minigame ends.
            self:desktopReady(false,now,false)
            self.leftHoldPaused=true
            self.leftHoldIntent=false
            self.leftHoldResumeAt=nil
            local current=self.combatInput.held
            if current and current.source=="desktop" then
                self.combatInput:release("M3",now)
            end
            self.leftHoldReason="minigame priority (paused, no attack dispatch)"
            return
        end
        local eligible=not hard
        if eligible then
            local ok,allowed=pcall(bridge.mouseGameplayPoint,bridge,nil,true)
            eligible=ok and allowed==true
        end
        if not eligible and not hard then
            self.leftHoldPaused=true;self.leftHoldResumeAt=nil
        elseif eligible and self.leftHoldPaused then
            self.leftHoldPaused=false;self.leftHoldResumeAt=now+.20
        end
        local ready=self:desktopReady(eligible==true,now,false)
        if not ready then
            eligible=false
            self.leftHoldReason="local readiness file unavailable"
        end
        if now>=(self.nextLeftIntent or 0) and self.leftHoldIo.available then
            self.nextLeftIntent=now+.04
            local ok,v=pcall(self.leftHoldIo.read,LEFT_INTENT..".json")
            if ok and type(v)=="table" and v.schema==LEFT_INTENT and v.token==self.leftHoldToken
                and Core.finite(v.sequence) and v.sequence>=1 and v.sequence<=1e12
                and v.sequence%1==0 and type(v.held)=="boolean" then
                local instance=type(v.instance)=="string" and v.instance:match("^[a-f0-9]+$") and #v.instance==32 and v.instance or nil
                if instance and self.leftHoldHelperInstance and instance~=self.leftHoldHelperInstance then
                    self.leftHoldHelperInstance=instance
                    self:disarmDesktopHold(now)
                    self.leftHoldReason="helper restarted; waiting for a fresh physical press"
                    return
                end
                if instance then self.leftHoldHelperInstance=instance end
                if self.leftHoldLastSequence~=nil and v.sequence<self.leftHoldLastSequence and not v.held then
                    self:disarmDesktopHold(now)
                    self.leftHoldReason="helper sequence restarted; input session renewed"
                    return
                end
                if self.leftHoldLastSequence==nil or v.sequence>self.leftHoldLastSequence then
                    self.leftHoldLastSequence=v.sequence
                    self.leftHoldLastAt=now
                    self.leftHoldIntent=v.held
                    if not v.held then self.leftHoldAwaitFresh=false end
                end
            end
        end
        local connected=self.leftHoldLastAt~=nil and now-self.leftHoldLastAt<=.55
        local resumeFresh=not self.leftHoldResumeAt or now>=self.leftHoldResumeAt
            and self.leftHoldLastAt~=nil and self.leftHoldLastAt>=self.leftHoldResumeAt
        -- Processed input echoes can leave the hub suspended after a temporary
        -- GUI action. Only a new, positively held signal from the installed
        -- foreground-scoped helper may restore desktop attack ownership.
        -- The gameplay hit-test and minigame/offer gates above still apply.
        if eligible and connected and resumeFresh and self.leftHoldIntent and not self.leftHoldAwaitFresh
            and self.inputSuspended and self.windowFocused~=false then
            self.inputSuspended=false
            self.ledger:event("desktop_left_hold_resumed_after_gui_pause",now)
        end
        local held=self.combatInput.held
        if not eligible or not connected or not resumeFresh or not self.leftHoldIntent or self.leftHoldAwaitFresh then
            if held and held.source=="desktop" then self.combatInput:release("M3",now) end
            -- Short helper/GUI readiness gaps should pause, not permanently
            -- revoke a captured physical press. Focus and actual game menus
            -- remain strict boundaries: the helper requires another Down edge.
            if self.windowFocused==false or s.chat or s.gameMenu then
                self.leftHoldAwaitFresh=true
            end
            if ready then
                self.leftHoldReason=not eligible and "gameplay input unavailable"
                    or not connected and "waiting for desktop helper"
                    or not resumeFresh and "waiting for fresh held confirmation after pause"
                    or self.leftHoldAwaitFresh and "waiting for fresh physical press" or "ready"
            end
            return
        end
        if not held then
            if self:startMiddle(s,now,nil) and self.combatInput.held then
                self.combatInput.held.source="desktop"
                self.ledger:event("desktop_left_hold_started",now)
            end
            held=self.combatInput.held
        end
        if held and held.source=="desktop" and bridge.desktopOwnsPrimary(s,now) then
            s.middleHeld=true
            -- This is an internal ownership classification only. Preserve
            -- the raw read for diagnostics; never alter engine properties.
            if self.leftHoldRawPrimary then self.leftHoldRawSamples=(self.leftHoldRawSamples or 0)+1 end
            s.desktopPrimaryRaw=s.mouseHeld
            s.mouseHeld=false
            s.physicalM1Held=false
            self.leftHoldReason=self.leftHoldRawPrimary and "desktop owns reported primary" or "desktop hold active"
        end
    end
    function h:startMiddle(s,now,input)
        -- A real middle press does not activate a primary-click GUI control.
        -- Only actual menu/text/focus/lifecycle ownership gates the hold.
        -- Querying every native HUD button here used to discard the entire
        -- physical press before the route could even be selected.
        local reason
        if self.closed or not self.active then reason="hub inactive"
        elseif self.windowFocused==false then reason="window unfocused"
        elseif not s.alive then reason="no active animal"
        elseif s.chat or s.gameMenu or bridge.UserInputService:GetFocusedTextBox() then reason="menu or text entry"
        elseif not self.registry.byId.holdBite.requested then reason="hold feature disabled"
        elseif self.ui:contains(bridge.UserInputService:GetMouseLocation()) then reason="hub UI" end
        if reason then
            self.combatInput.middleAdmission=reason
            self.ledger:event("m3_press_rejected",now,{reason=reason})
            return false
        end
        self.combatInput.middleAdmission="physical hold accepted"
        if self.combatInput.held and self.combatInput.held.key=="M3"
            and self.combatInput.held.generation==s.generation then return true end
        self:physicalInput("other")
        self.inputSuspended=false
        self.policy:input("attack",now)
        self.feeding:attack(s,now);self.rescue:cancel()
        self:stopWalk("middle mouse attack input")
        self.recovery:release("middle mouse attack input",now)
        self.combatInput:input(s,now,"M3",input)
        return true
    end
    function h:input(input,processed)
        local kind,key = input.UserInputType,input.KeyCode
        if bridge.holdBinding=="M3" and kind==Enum.UserInputType.MouseButton3 then
            if self.leftHoldBridge then return end
            -- Camera processing alone is not a gameplay veto. UI/menu/text checks
            -- in startMiddle still reject consumed control clicks.
            self.middlePollDown=true;self.middlePollArmed=false
            local now=bridge.clock()
            self:startMiddle(bridge:snapshot(now,false),now,input)
            return
        end
        -- Once this real physical M1 has been held long enough for the
        -- hub to own repeat, no *second* InputBegan can originate from that
        -- same uninterrupted hardware press. Ignore any later replay echo
        -- even when the executor delivers it after the short grace window.
        -- It still reaches FERAL's original InputBegan listener normally.
        if bridge.holdBinding=="M1" and kind==Enum.UserInputType.MouseButton1
            and self.physicalM1Input~=nil and input~=self.physicalM1Input
            and self.combatInput.held and self.combatInput.held.handoff
            and not self.ui:contains(bridge.UserInputService:GetMouseLocation()) then
            return
        end
        -- A replayed InputBegan may arrive asynchronously, including with
        -- processed=true. Never let that echo permanently suspend the real M1.
        if kind==Enum.UserInputType.MouseButton1 and (bridge.syntheticPressing
            or bridge.syntheticM1~=nil or bridge.clock()<(bridge.syntheticM1Until or 0)) then return end
        if kind == Enum.UserInputType.MouseButton2 and bridge.clock() < (self.syntheticUntil or 0) then return end
        self:physicalInput("other")
        if processed then
            -- Once a world-originated real M1 has entered handoff, later
            -- processed mouse echoes must not cancel that real InputObject.
            -- The original processed physical click is still cancelled,
            -- and a focused UI/text field always takes priority.
            if bridge.holdBinding=="M1" and kind==Enum.UserInputType.MouseButton1
                and self.physicalM1Input~=nil and input~=self.physicalM1Input
                and self.combatInput.held and self.combatInput.held.handoff
                and not bridge.UserInputService:GetFocusedTextBox()
                and not self.ui:contains(bridge.UserInputService:GetMouseLocation()) then return end
            -- Native movement/ability bindings consume their own keyboard
            -- events too. Preserve those observations (e.g. X/Z gait intent),
            -- while consumed attack inputs never establish held ownership.
            if kind~=Enum.UserInputType.MouseButton1 and key~=Enum.KeyCode.ButtonR2
                and not bridge.UserInputService:GetFocusedTextBox() then
                self:preInput(input)
            end
            -- A later native/UI binding can consume the original event after
            -- our priority observer. Never turn its consumed click into a
            -- delayed attack through the optional Rest-exit buffer.
            local pending,held=self.combatInput.pending,self.combatInput.held
            if kind==Enum.UserInputType.MouseButton1 or key==Enum.KeyCode.ButtonR2
                or pending and pending.input==input or held and held.input==input then
                if bridge.holdBinding=="M3" and held and held.key=="M3"
                    and not bridge.UserInputService:GetFocusedTextBox()
                    and not self.ui:contains(bridge.UserInputService:GetMouseLocation()) then
                    if pending and pending.input==input then self.combatInput.pending=nil end
                    self.physicalM1Input=nil
                else
                    self.combatInput:cancel()
                    self.physicalM1Input=nil
                    self.inputSuspended=true
                end
            end
            if self.lastIntent and self.lastIntent.input==input and not self.lastIntent.nativeAt then
                self.lastIntent.consumed=true
            end
            return
        end
        if bridge.UserInputService:GetFocusedTextBox() then return end
        self:preInput(input)
        if key == Enum.KeyCode.Q and self.registry.byId.climb.requested then
            local s = bridge:snapshot(bridge.clock(),false)
            local allowed = self.policy:allowed("climb",s,s.now)
            if allowed and not s.climbing and type(s.climber) == "number" and s.climber >= 1 then
                self.climbQueue = { generation = s.generation, expires = s.now+2.25,
                    earliest = s.now+.1, attempts = 0 }
            end
        end
    end
    function h:inputEnded(input)
        if self.closed or not self.active then return end
        local kind,key=input.UserInputType,input.KeyCode
        if kind==Enum.UserInputType.MouseButton3 and bridge.holdBinding=="M3" then
            if self.leftHoldBridge then return end
            self.middlePollArmed=false
            self.combatInput:release("M3",bridge.clock())
            return
        elseif kind==Enum.UserInputType.MouseButton1 then
            -- Owned synchronous releases may reuse the engine's mouse object.
            -- Suppress those before consulting optional InputObject identity.
            if bridge.syntheticReleasing then return end
            -- A matching real InputObject can end during a synthetic Down
            -- callback. Do not discard that genuine release solely because
            -- syntheticPressing is set; generated Up has syntheticReleasing.
            if input==self.physicalM1Input then
                self.physicalM1Input=nil
                self.combatInput:release("M1",bridge.clock())
                return
            end
            if bridge.syntheticPressing then return end
            if bridge.syntheticM1~=nil
                or bridge.clock()<(bridge.syntheticM1Until or 0) then
                return
            end
            -- Fallback for late physical releases and hub sessions that
            -- started after M1 was already held: the existing poll source
            -- also clears on the next native IsMouseButtonPressed=false.
            self.physicalM1Input=nil
            self.combatInput:release("M1",bridge.clock())
        elseif key==Enum.KeyCode.ButtonR2 then
            self.combatInput:release("R2",bridge.clock())
        end
    end
    function h:nativeAttribute(key)
        if self.closed or not self.active then return end
        local now = bridge.clock()
        local s = bridge:snapshot(now,false)
        if s.ability or key=="FeralCrushBiteAt" and Core.finite(bridge:attribute(s.char,key)) then
            self:observeCombatAbility(s,now)
        end
        if key=="FeralCrushAt" then self.features:hippoAttribute(s) end
        if key=="FeralCrushAt" or key=="FeralCrushBiteAt" then self.hippo:observe(s,now) end
        if key=="FeralCrushBiteAt" and s.species=="Hippo" and Core.finite(bridge:attribute(s.char,key)) then
            self.policy:input("attack",now)
            self.recovery:release("native Crusher release",now)
            self:stopWalk("native Crusher release")
            self.ledger:event("hippo_native_bite_marker",now,{damageAcceptance="unverified"})
        end
        if key == "WolfRest" then self.recovery:echo(s,now)
        elseif key == "WolfBiteAt" and Core.finite(bridge:attribute(s.char,key)) then
            bridge.biteTiming=nil
            if not s.alive then return end
            self.combatInput:marker(s,now)
            self.tests:observeBite(s,now)
            self.policy.attackUntil = math.max(self.policy.attackUntil,now+1.1)
            self.recovery:release("native bite marker",now)
            local tx = self.lastIntent
            if not tx or tx.nativeAt or now-tx.intent > 1.3 then
                tx = { intent = now,generation = s.generation }
                table.insert(self.transactions,tx)
                if #self.transactions > 32 then table.remove(self.transactions,1) end
            end
            tx.nativeAt,tx.claimDue,tx.classified = now,now+bridge:biteDelay(s.char),false
            tx.abilityAmbiguous=s.ability==true or now<(self.abilityEvidenceUntil or 0)
            -- Only confirmed *stock*-range contacts can train attack cadence.
            -- Extended-only reach, predictive FX, and a bare bite sound are
            -- never treated as server proof.
            local guide=self.guide
            local focus=guide and guide.target
            local fresh=focus and focus.root and focus.root.Parent
                and now-(self.guideAt or -math.huge)<.28
            -- Pin the target selected at the actual native bite marker.
            -- The guide can switch to another animal before delayed contact.
            tx.focusTarget=fresh and focus or nil
            tx.focusExtendedOnly=fresh and guide.extended and guide.extended.valid
                and not (guide.baseline and guide.baseline.valid) or false
            local valid=fresh and guide and guide.baseline and guide.baseline.valid
            -- Reuse the already checked guide, avoiding extra expensive or
            -- throwable world queries within a native attribute callback.
            local clear=valid and focus and focus.root and focus.root.Parent
                and guide.blocked~=true and guide.obstruction~=true
            tx.rateTarget=clear and focus or nil
            tx.rateEligible=tx.rateTarget~=nil and self.registry.byId.attackSpeed.requested
                and (self.combatInput.held~=nil or self.registry.byId.autoBite.requested) and not tx.abilityAmbiguous
            tx.observeUntil=tx.claimDue+2.0
            tx.hpBefore={}
            for _,target in ipairs(bridge.allCandidates or {}) do
                if bridge:currentTargetBody(target) and (target.root.Position-s.root.Position).Magnitude<=45 then
                    tx.hpBefore[target.char]={hp=target.hum.Health,maxHP=target.hum.MaxHealth,hum=target.hum}
                end
            end
            self.ledger:event("native_bite_marker",now,{requestObserved = false,claimObserved = false})
        else
            -- Native actions can begin between heartbeats. Release competing
            -- automation on the actual state change, preserving manual input.
            s.grab,s.rescuing = self:hasNativeGrab(now),self.rescue.pending~=nil
            s.feeding = s.feeding or self.feeding.busy
            local allowed,why=self.policy:allowed("recovery",s,now,self.recovery.purpose)
            if self.recovery.owned and not allowed then self.recovery:release(why,now) end
            if s.captured or s.grab or s.ability or s.flying or s.climbing or s.feeding then
                self:stopWalk("native action began")
                if s.captured or s.ability or s.flying then self.climbQueue=nil end
            end
            if key=="FeralTalonLock" or key=="FeralDiveLocal" then self:stepFlightHandoff(s,now) end
        end
    end
    function h:nativeEvent(kind,event,data,...)
        if self.closed or not self.active then return end
        if kind == "hippo" then self.tests:hippoReply(event,data,...);return end
        if kind == "feedback" then
            self.tests:feedback(event,data)
            self.ledger:event("native_hit_feedback",bridge.clock(),{damageAcceptance = "unverified"})
            if event=="hit" and type(data)=="table" and data.a==bridge.player.Character then
                local now=bridge.clock()
                self.hippo:feedback(data,now)
                local tx,ambiguous=Controller.matchFeedback(Core,self.transactions,data,now)
                if tx then
                    tx.feedback=data;tx.nativeTarget=data.v;tx.dirty=true
                    tx.targetMismatch=tx.localTarget~=nil and tx.localTarget~=data.v
                    if Core.finite(data.dmg) and data.dmg>0 and data.safe~=true then
                        tx.positiveReply=true
                        local confidence=self.extendedConfidence[data.v]
                        if confidence then
                            confidence.misses=0
                            confidence.waitUntil=0
                        end
                    end
                    if tx.rateEligible and tx.rateTarget and tx.rateTarget.char==data.v
                        and data.safe~=true and Core.finite(data.dmg) and data.dmg>0
                        and not tx.fastConfirmed then
                        tx.fastConfirmed=true
                        self.combatInput:confirmed(now)
                    end
                end
                self.ledger:event("native_outgoing_hit_reply",now,{safe=data.safe==true,damage=data.dmg,
                    matched=tx~=nil,ambiguous=ambiguous==true})
                if not tx and Core.finite(data.dmg) and data.dmg>0 and data.safe~=true then
                    -- A genuine reply must not be displayed as a ghost
                    -- merely because its client bite ID was ambiguous.
                    self.lastUnmatchedGameHit=now
                    self.combatStatus="Game reports a hit · local bite association uncertain"
                end
                if not tx then
                    self.ledger:event("native_outgoing_hit_reply_unmatched",now,
                        {reason=ambiguous and "ambiguous overlapping attacks" or "no matching native bite"})
                end
            end
            return
        end
        if kind=="actions" then
            if event=="FeedStop" then self.feeding:stopped(data,bridge.clock()) end
            return
        end
        if kind=="biteLocal" then
            local at=bridge.clock()
            self.ledger:event("client_bite_fx_only",at,{claimObserved=false})
            local candidates,due={},{}
            for index=#self.transactions,1,-1 do
                local tx=self.transactions[index]
                if tx.generation==bridge.generation and tx.nativeAt and not tx.classified
                    and not tx.localTarget and at>=tx.nativeAt and at-tx.nativeAt<1.5 then
                    table.insert(candidates,tx)
                    if at>=(tx.claimDue or tx.nativeAt)-.03 then table.insert(due,tx) end
                end
            end
            -- Never attach an old delayed impact to a new bite whose claim
            -- has not occurred. Ambiguous overlaps remain local observations.
            local tx=#candidates==1 and candidates[1] or #due==1 and due[1] or nil
            if tx then
                tx.localTarget,tx.localImpactAt,tx.dirty=event,at,true
                self.ledger:event("native_client_bite_candidate",at,{claimObserved=false})
            else self.ledger:event("native_client_bite_candidate_unmatched",at,{claimObserved=false}) end
            return
        end
        -- Observe the game's action ownership even with automation OFF.
        -- This never schedules presses or leases its controls while disabled.
        if kind=="grab" and type(data)=="table" then
            local session=data.f or (event=="begin" and data.id)
            local observed=self.nativeGrabSession
            local at=bridge.clock()
            if M.grab.validId(session) then
                if event=="begin" then
                    self.nativeGrabSession={id=session,char=bridge.player.Character,generation=bridge.generation,at=at}
                    self.recovery:release("native minigame",at);self:stopWalk("native minigame")
                elseif observed and tostring(observed.id)==tostring(session)
                    and observed.generation==bridge.generation then
                    if event=="end" then self.nativeGrabSession=nil
                    elseif event=="strike" or event=="res" or event=="bite" or event=="n" then observed.at=at end
                end
            end
        end
        local now = bridge:serverNow()
        if kind=="grab" and event=="begin" then
            bridge:releaseSyntheticBite()
            self.combatInput.awaiting=nil
        end
        self.nativeGrabBusy=self:hasNativeGrab(bridge.clock())
        if not now then return end
        local c = bridge:config("GrabV2Config")
        local handled = self.grab:event(event,data,now,bridge.generation,c and c.PERFECT or .32,c and c.PASSES or 2.5,
            {character=bridge.player.Character,bitePause=c and c.BITE_PAUSE or .6})
        if handled then
            self.recovery:release("native minigame",bridge.clock())
            self:stopWalk("native minigame")
            self.ledger:event("native_grab_" .. tostring(event),bridge.clock(),
                {tier = event == "res" and data.mine == true and data.tier or nil})
            if event == "begin" then
                bridge.nextGrabDiscovery = 0
                if not bridge.grabController then bridge.nativeScan=nil end
            end
            bridge.deferNativeDiscovery=self.grab.enabled and self.grab.pending~=nil
            if event=="begin" or event=="strike" then self.grabInput.nextBindingCheck=0 end
            self.grabInput:update(self.grab,bridge.clock())
            if event=="strike" then self:pumpGrab(bridge:grabSnapshot(bridge.clock()),false) end
            self:updateGrabWake()
        end
    end
    function h:cancelGrabWake()
        local wake=self.grabWake;self.grabWake=nil
        if wake then bridge:cancelDelay(wake.handle) end
    end
    function h:updateGrabWake()
        local p=self.grab.pending
        local wake=self.grabWake
        if wake and wake.pending==p and wake.at==p.at then return end
        self:cancelGrabWake()
        if not self.active or self.closed or not self.grab.enabled or not p or (p.wakes or 0)>=4 then return end
        local now=bridge:serverNow()
        if not now then return end
        p.localEnds=p.localEnds or bridge.clock()+math.max(0,p.ends-now)
        if p.at<=now then return end
        wake={pending=p,at=p.at};self.grabWake=wake
        wake.handle=bridge:delay(math.max(.001,p.at-now),function()
            if self.grabWake~=wake then return end
            self.grabWake=nil
            if self.active and not self.closed and self.grab.enabled and self.grab.pending==p then
                self:pumpGrab(bridge:grabSnapshot(bridge.clock()),true)
                self:updateGrabWake()
            end
        end)
        if wake.handle then p.wakes=(p.wakes or 0)+1 else self.grabWake=nil end
    end
    function h:pumpGrab(s,sync)
        if self.closed or not self.active or not self.grab.enabled or not self.grab.active then return end
        local now,clock=s.now,s.serverNow
        if not clock or not s.alive then return end
        local native=bridge.grabController
        if sync and native then
            local state,known=nativeState(native)
            local cfg=bridge:config("GrabV2Config")
            if state or known==true then
                self.grab:syncNative(state,clock,s.generation,cfg and cfg.PERFECT or .32,cfg and cfg.PASSES or 2.5,now)
            end
        end
        local p=self.grab.pending
        if not p then
            -- Session timeout must also run between strikes; otherwise a lost
            -- end packet with no private UI handle can block recovery forever.
            self.grab:tick(clock,s.generation,false,function()return false end)
            return
        end
        if self.lastGrabClock==clock and self.lastGrabPending==p then return end
        self.lastGrabClock,self.lastGrabPending=clock,p
        s.grab=true
        self.grab:tick(clock,s.generation,self.policy:allowed("grab",s,now),function(session,strike)
            -- Native-issued IDs and the actual current server clock only.
            -- Recheck after inspection; never backdate or anticipate a press.
            local at=bridge:serverNow()
            if not at then return false end
            if at<p.t0 or at>=p.ends-.002
                or math.abs(M.grab.triangle(at,p.t0,p.speed,p.from)-p.target)>p.half*.98 then
                return false,"clock_moved",at
            end
            local sent=bridge:fire("FeralGrabV2","press",session,strike,at)
            -- An optional native-UI annotation cannot turn an already issued
            -- press into a failed dispatch and allow a duplicate submission.
            if sent then pcall(bridge.markGrabPress,bridge,session,strike,now) end
            return sent
        end)
    end
    function h:requestFlight()
        local now = bridge.clock()
        if not self.active or self.closed or not self.registry.byId.flight.requested or now < (self.nextFlight or 0) then return false end
        local s = bridge:snapshot(now,true)
        s.grab,s.rescuing = self:hasNativeGrab(now),self.rescue.pending~=nil
        local c = bridge:config("FlightConfig")
        local ok,canFly = pcall(function() return c.canFly(s.char) end)
        if not ok or canFly ~= true or s.flying or not s.surface or s.underwater
            or not self.policy:allowed("flight",s,now) then return false end
        if type(c.WATER) ~= "table" or type(c.WATER.NO_TAKEOFF) ~= "boolean" then return false end
        self.recovery:release("surface takeoff input",now)
        local applied = self.features.leases:apply("surface",{
            {target = c.WATER,key = "NO_TAKEOFF",value = false,kind = "boolean"} })
        if not applied then return false end
        self.surfaceRequest={char=s.char,value=now,before=bridge:attribute(s.char,"FeralFlyRequest")}
        if not bridge:setAttribute(s.char,"FeralFlyRequest",now) then self:clearFlight(); return false end
        self.surfaceUntil,self.nextFlight = now+1.15,now+.75
        self.ledger:event("surface_takeoff_requested",now)
        return true
    end
    function h:idle()
        local now = bridge.clock()
        if self.closed or not self.active or not self.registry.byId.robloxAFK.requested
            or bridge.UserInputService:GetFocusedTextBox() then return end
        self.syntheticUntil,self.nextIdle = now+.25,now+75
        local ok = bridge:pulseIdle()
        self.idleUnavailable = not ok
        self.registry:ack("robloxAFK",ok,ok and "ARMED" or "UNAVAILABLE",
            ok and "idle input sent; retention unverified" or "virtual input unavailable")
        self.ledger:event("idle_input_attempt",now,{callSucceeded = ok})
    end
    function h:ackLocal(s)
        local r = self.registry
        local zoom=r.byId.zoom
        local zoomApplied=self.zoom:set(self.active and zoom.requested)
        r:ack("zoom",zoomApplied,not zoom.requested and "OFF" or zoomApplied and "CLIENT" or "UNAVAILABLE",self.zoom.reason)
        for _,id in ipairs({"combat","colours","finder","menu"}) do
            r:ack(id,true,id == "combat" and "ARMED" or "CLIENT",r.byId[id].detail)
        end
        local hearing=r.byId.voice
        local hearingActive=self.voice.enabled and hearing.requested
        r:ack("voice",hearingActive,not hearing.requested and "OFF" or hearingActive and "ARMED" or "WAITING",
            self.voice:summary())
        for _,id in ipairs({"esp","tags","biteHelper"}) do
            local f = r.byId[id]
            r:ack(id,f.requested,f.requested and "CLIENT" or "OFF",f.detail)
        end
        local auto=r.byId.autoBite
        local native=bridge.wolfActions and bridge.wolfActions.tryBite~=nil
        local hold=r.byId.holdBite
        local m1Native=bridge.holdBinding=="M1" and not native and bridge:nativeWolfInputAction(s.now or bridge.clock()) or nil
        local middle=bridge.holdBinding=="M3"
        local locked=self.combatInput.middleRoute
        local route=locked or self.combatInput.middleCandidate
        local ordinaryReady=middle and bridge:combatInputCompatible() and bridge:hasHeldInputBackend()
        local nativeGC=native and bridge.wolfActions.discovery=="validated own heap closure"
        local sourceLabel=nativeGC and "Original native callback recovered · "
            or native and "Original native callback · "
            or m1Native and "Original WolfController M1 input callback · "
            or "Original attack handler inaccessible · "
        local routeReady=native or m1Native~=nil
        if middle then
            sourceLabel=locked and ("M3 locked: "..(locked=="NATIVE" and "native callback" or "ordinary input").." · ")
                or route and ("M3 verifying: "..route.." · ") or "M3 awaiting first verified bite · "
            routeReady=route=="NATIVE" and native or route=="INPUT" and ordinaryReady
                or route==nil and (native or ordinaryReady)
        end
        r:ack("holdBite",hold.requested and routeReady,
            not hold.requested and "OFF" or middle and locked and routeReady and "ARMED"
                or not middle and native and "ARMED" or routeReady and "PARTIAL" or "WAITING",
            hold.requested and sourceLabel..self.combatInput.status or hold.detail)
        r:ack("autoBite",auto.requested and native,not auto.requested and "OFF" or native and "ARMED" or "WAITING",
            auto.requested and self.combatInput.status or auto.detail)
        local movement=r.byId.hippoMove
        local hippo=s.alive and s.species=="Hippo"
        local moved=hippo and self.features.leases:valid("hippoGait")
        r:ack("hippoMove",movement.requested and moved,not movement.requested and "OFF" or moved and "CLIENT" or "WAITING",
            not hippo and "waiting for Hippo" or moved and "charge movement inputs applied; displacement unverified" or self.features.hippoStatus)
        local release=r.byId.hippoRelease
        local releaseReady=hippo and self.hippo.native~=nil
        r:ack("hippoRelease",release.requested and releaseReady,not release.requested and "OFF" or releaseReady and "ARMED" or "WAITING",
            self.hippo.releaseStatus)
        for _,id in ipairs({"robloxAFK","survivalAFK","minigame","escape","flight"}) do
            local f = r.byId[id]
            if not f.requested then r:ack(id,false,"OFF",f.detail)
            elseif id == "minigame" then
                local remote = bridge:hasRemote("FeralGrabV2")
                local state = remote and (self.grab.active and not self.grabInput.lease and "PARTIAL" or "ARMED") or "WAITING"
                r:ack(id,remote,state,
                    self.grab.active and (self.grab.status .. " · " .. self.grabInput.status) or self.grab.status)
            elseif id == "escape" then
                r:ack(id,bridge:hasRemote("FeralLunge"),"ARMED",self.escapeStatus or "watching native capture")
            elseif id == "flight" then
                local c =