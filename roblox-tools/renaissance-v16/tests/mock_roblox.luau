-- Deterministic service boundary. It simulates events/streaming, not a server.
local Mock = {}
local function signal()
    local s = { listeners = {} }
    function s:Connect(fn)
        local c = { Connected = true, fn = fn }
        function c:Disconnect() self.Connected = false end
        table.insert(self.listeners,c)
        return c
    end
    function s:Fire(...)
        local current = table.clone(self.listeners)
        for _,c in ipairs(current) do if c.Connected then c.fn(...) end end
    end
    function s:Count()
        local count = 0
        for _,c in ipairs(self.listeners) do if c.Connected then count += 1 end end
        return count
    end
    return s
end
local function vectors(dim)
    local methods,meta = {},{}
    local function new(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,_type=dim==3 and "Vector3" or "Vector2"},meta) end
    function meta.__index(v,k)
        if k == "Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+(dim==3 and v.Z*v.Z or 0)) end
        if k == "Unit" then local m=v.Magnitude; return m>0 and new(v.X/m,v.Y/m,v.Z/m) or new() end
        return methods[k]
    end
    function meta.__add(a,b) return new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
    function meta.__sub(a,b) return new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
    function meta.__mul(a,b) if type(a)=="number" then a,b=b,a end; return new(a.X*b,a.Y*b,a.Z*b) end
    function meta.__div(a,b) return new(a.X/b,a.Y/b,a.Z/b) end
    function methods:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
    function methods:Lerp(b,a) return self+(b-self)*a end
    return { new=new }
end
local V3,V2 = vectors(3),vectors(2)
local enum = setmetatable({}, {__index=function(t,k)
    local group = setmetatable({}, {__index=function(g,v) local value=k.."."..v;rawset(g,v,value);return value end})
    rawset(t,k,group);return group
end})
enum.RenderPriority.Camera={Value=200}
local function kind(v) return type(v)=="table" and v._type or type(v) end
function Mock.new()
    local w = { time=10,objects={},calls={},configs={},renders={},bindings={},bindingInfo={},parts={},timers={},timerSerial=0,
        nativeRestEcho=false,localEnvironment={},failure=nil,waterY=nil,blocked=false,
        metrics={writes={},projections=0,connections=0,info=0,upvalues=0,heap=0,boundInfo=0} }
    function w:resetMetrics()
        self.metrics={writes={},projections=0,connections=0,info=0,upvalues=0,heap=0,boundInfo=0}
    end
    local methods = {}
    local function new(class)
        if w.failure == "instance:"..class then error("injected Instance creation failure") end
        local o = {_props={ClassName=class,Name=class,Visible=true,Enabled=true,Active=true,Interactable=true,Text="",
            AbsolutePosition=V2.new(0,0),AbsoluteSize=V2.new(704,505),
            Size=V3.new(2,2,4),Position=V3.new(0,3,0),Health=100,MaxHealth=100,
            HipHeight=1,WalkSpeed=16,MoveDirection=V3.new(),AssemblyLinearVelocity=V3.new(),
            FloorMaterial=enum.Material.Grass,CFrame={LookVector=V3.new(0,0,-1),UpVector=V3.new(0,1,0)}},
            _children={},_attrs={},_signals={},_destroyed=false}
        setmetatable(o,{
            __index=function(self,k)
                if methods[k] then return methods[k] end
                if k=="Activated" or k=="OnClientEvent" or k=="Event" then
                    self._signals[k]=self._signals[k] or signal();return self._signals[k]
                end
                return self._props[k]
            end,
            __newindex=function(self,k,v)
                local key=self.ClassName..":"..k
                w.metrics.writes[key]=(w.metrics.writes[key] or 0)+1
                if (k:match("Color3$") or k=="Color" or k=="OutlineColor" or k=="FillColor") and v~=nil then
                    assert(kind(v)=="Color3","colour property received non-colour: "..k)
                end
                if k=="Parent" then
                    local old=self._props.Parent
                    if old then
                        for i,c in ipairs(old._children) do if c==self then table.remove(old._children,i);break end end
                    end
                    if v then assert(not v._destroyed,"parent was destroyed");table.insert(v._children,self) end
                end
                self._props[k]=v
                local changed=self._signals["property:"..k]
                if changed then changed:Fire() end
            end,
        })
        table.insert(w.objects,o)
        return o
    end
    function methods:IsA(class)
        return self.ClassName==class or class=="Instance"
            or class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="MeshPart")
            or class=="GuiButton" and (self.ClassName=="TextButton" or self.ClassName=="ImageButton")
    end
    function methods:GetPropertyChangedSignal(key)
        local name="property:"..key
        self._signals[name]=self._signals[name] or signal()
        return self._signals[name]
    end
    function methods:GetChildren() return table.clone(self._children) end
    function methods:GetGuiObjectsAtPosition() return w.guiUnder or {} end
    function methods:GetDescendants()
        local all={}
        local function visit(o) for _,c in ipairs(o._children) do table.insert(all,c);visit(c) end end
        visit(self);return all
    end
    function methods:FindFirstChild(name,recursive)
        for _,c in ipairs(self._children) do if c.Name==name then return c end end
        if recursive then for _,c in ipairs(self:GetDescendants()) do if c.Name==name then return c end end end
        return nil
    end
    function methods:FindFirstChildOfClass(class)
        for _,c in ipairs(self._children) do if c:IsA(class) then return c end end
        return nil
    end
    function methods:FindFirstAncestorOfClass(class)
        local p=self.Parent
        while p do if p:IsA(class) then return p end;p=p.Parent end
        return nil
    end
    function methods:IsDescendantOf(parent)
        local p=self.Parent
        while p do if p==parent then return true end;p=p.Parent end
        return false
    end
    function methods:WaitForChild(name) return self:FindFirstChild(name) end
    function methods:GetAttribute(key) return self._attrs[key] end
    function methods:SetAttribute(key,value)
        local old=self._attrs[key];self._attrs[key]=value
        if old~=value and self._signals[key] then self._signals[key]:Fire() end
    end
    function methods:GetAttributeChangedSignal(key)
        self._signals[key]=self._signals[key] or signal();return self._signals[key]
    end
    function methods:Destroy()
        if self._destroyed then return end
        for _,c in ipairs(self:GetChildren()) do c:Destroy() end
        for _,s in pairs(self._signals) do for _,c in ipairs(s.listeners) do c:Disconnect() end end
        self.Parent=nil;self._destroyed=true
    end
    function methods:FireServer(...)
        local args=table.pack(...)
        table.insert(w.calls,{name=self.Name,args=args,at=w.time})
        if self.Name=="WolfActions" and args[1]=="Rest" and w.nativeRestEcho then
            w.player.Character:SetAttribute("WolfRest",args[2])
        end
        if self.Name=="WolfActions" and args[1]=="Rest" and args[2]==false then w.nativeRestReleasedAt=w.time end
        if self.Name=="FeralLunge" and args[1]=="carry" and w.acceptCarry then
            local clamp=new("ObjectValue");clamp.Name="FeralClamp";clamp.Value=args[2]
            clamp:SetAttribute("Carry",true);clamp.Parent=w.player.Character
        end
    end
    function methods:GetState() return self.NativeState or enum.HumanoidStateType.Running end
    function methods:MoveTo(goal) self.goal=goal end
    function methods:GetGuiObjectsAtPosition() return w.guiHits or {} end
    local root = new("DataModel")
    local workspace = new("Workspace");workspace.Parent=root
    workspace.Terrain=new("Terrain");workspace.Terrain.Parent=workspace
    workspace.CurrentCamera={
        ViewportSize=V2.new(1400,900),
        WorldToViewportPoint=function(_,p) w.metrics.projections+=1;return V3.new(700+p.X*2,450-p.Y*2,20-p.Z),true end
    }
    function workspace:GetServerTimeNow() return w.time+1000 end
    function workspace:Raycast(origin,direction,params)
        if params.FilterType==enum.RaycastFilterType.Include then
            return w.waterY and {Material=enum.Material.Water,Position=V3.new(origin.X,w.waterY,origin.Z),Normal=V3.new(0,1,0),Instance=self.Terrain} or nil
        end
        if direction.Y==0 then return w.blocked and {Instance=self.Terrain,Position=origin,Material=enum.Material.Grass} or nil end
        if w.hole and math.abs(origin.X)>2 and math.abs(origin.X)<4 then return nil end
        return {Position=V3.new(origin.X,0,origin.Z),Normal=V3.new(0,1,0),Material=enum.Material.Grass,Instance=self.Terrain}
    end
    function workspace:GetPartBoundsInRadius() return w.parts end
    local player=new("Player");player.Parent=root;player.Name="LocalPlayer";player.DisplayName="Local";player.UserId=1
    player.CameraMinZoomDistance=.5;player.CameraMaxZoomDistance=128;player.CameraMode=enum.CameraMode.Classic
    local pg=new("PlayerGui");pg.Parent=player
    player.CharacterAdded,player.CharacterRemoving,player.Idled=signal(),signal(),signal()
    player:SetAttribute("FeralCombatUntil",0);player:SetAttribute("FeralPack",1);player:SetAttribute("FeralSurvival",0)
    local players={LocalPlayer=player,list={player}}
    function players:GetPlayers() return table.clone(self.list) end
    function players:GetPlayerFromCharacter(char)
        for _,p in ipairs(self.list) do if p.Character==char then return p end end
    end
    local rs=new("ReplicatedStorage");rs.Parent=root
    local world=new("Folder");world.Name="FeralWorld";world.Parent=rs
    local needs={STAMINA_REGEN=1.31,STAMINA_REGEN_DELAY=.8,STAMINA_SPRINT_DRAIN=.94,
        STAMINA_JUMP_COST=6,STAMINA_LOW_NEEDS=.5,STAMINA_REST_MULT=3,
        HEALTH_REGEN=.01,HEALTH_REST_MULT=2,HEALTH_NO_REGEN_IN_COMBAT=true,
        HURT_SLOW=.3,RUN_SPEED=1,SWIM_SPEED=1}
    local combat={REACH=1.45,HIT_SCALE=1.15,CONE=71,SLACK=1.2,MAX_DY=2.5,
        bodyGap=function(_,flat) return math.max(0,flat.Magnitude-1) end}
    function w:addConfig(name,value)
        local m=new("ModuleScript");m.Name=name;m.ModuleValue=value;m.Parent=world;self.configs[name]=value
        return m
    end
    w:addConfig("NeedsConfig",needs);w:addConfig("CombatConfig",combat)
    w:addConfig("StatusConfig",{INJURY={HEAL=.45,REST_MULT=4,SLOW_PER_POINT=.1},
        BLEED={CLOT=.2,REST_MULT=4},VENOM={FADE=.3,REST_MULT=4}})
    w:addConfig("JumpLeapConfig",{ON=true,DEFAULT=1,MAX_RUN_SHARE=1,BODY_LENGTHS={Wolf=1,Cobra=0}})
    w:addConfig("FlightConfig",{FLAP_DRAIN=.85,WATER={NO_TAKEOFF=true,GRACE=.3},
        canFly=function(char) return char and char:GetAttribute("Species")=="BaldEagle" end})
    w:addConfig("PassiveConfig",{CLIMBER={GRAB_REACH=.8,E_REACH=1.6,GRAB_FACING=.7,MOUNT_TIME=.32,levels={{},{}}}})
    w:addConfig("SurvivalConfig",{AFK_MOVE=4,AFK_AFTER=120})
    w:addConfig("GrabV2Config",{PERFECT=.32,PASSES=2.5})
    for _,name in ipairs({"WolfActions","FeralGrabV2","FeralHit","FeralLunge"}) do
        local remote=new("RemoteEvent");remote.Name=name;remote.Parent=rs
    end
    local run={Heartbeat=signal(),PreAnimation=signal()}
    function run:BindToRenderStep(name,priority,fn)
        if w.failure=="render" then error("injected render attach failure") end
        w.renders[name]={priority=priority,fn=fn}
    end
    function run:UnbindFromRenderStep(name) w.renders[name]=nil end
    local uis={InputBegan=signal(),InputChanged=signal(),JumpRequest=signal()}
    function uis:GetFocusedTextBox() return w.chat end
    function uis:IsMouseButtonPressed(button) return w.held==button end
    function uis:GetMouseLocation() return V2.new(1200,850) end
    local cas={}
    function cas:BindActionAtPriority(name,fn,_,priority,...)
        w.bindings[name]=fn;w.bindingInfo[name]={inputTypes={...},priorityLevel=priority or 0}
    end
    function cas:UnbindAction(name) w.bindings[name]=nil;w.bindingInfo[name]=nil end
    function cas:GetAllBoundActionInfo()
        w.metrics.boundInfo+=1
        local result={}
        for name in pairs(w.bindings) do result[name]=w.bindingInfo[name] or {} end
        if w.nativeShake then result.FeralShakeTaps={} end
        return result
    end
    local virtual={}
    function virtual:CaptureController() if w.idleBlocked then error("input unavailable") end end
    function virtual:ClickButton2() w.idlePulses=(w.idlePulses or 0)+1 end
    local files={}
    local http={}
    function http:JSONDecode(key) assert(files[key],"invalid JSON");return files[key] end
    function http:JSONEncode(value) local key="json:"..tostring(#w.calls)..":"..tostring(w.time)..":"..tostring(value);files[key]=value;return key end
    local paths={}
    function paths:CreatePath()
        local p={Status=enum.PathStatus.Success}
        function p:ComputeAsync(from,target)self.from,self.target=from,target end
        function p:GetWaypoints()return {{Position=self.from},{Position=self.target}}end
        return p
    end
    function uis:IsKeyDown(key)return w.keys and w.keys[key]==true or false end
    uis.InputEnded=signal()
    function methods:Move(dir)self.MoveDirection=dir end
    V3.zero=V3.new()
    local services={Players=players,ReplicatedStorage=rs,RunService=run,UserInputService=uis,
        ContextActionService=cas,HttpService=http,Workspace=workspace,VirtualUser=virtual,PathfindingService=paths}
    local gameObject={PlaceId=108901361810209,PlaceVersion=2412}
    function gameObject:GetService(name) return assert(services[name],"unknown service "..name) end
    local stored={}
    local mockOS=table.clone(os);mockOS.clock=function()return w.time end
    local env=setmetatable({
        game=gameObject,workspace=workspace,Enum=enum,Vector3=V3,Vector2=V2,
        Color3={fromRGB=function(r,g,b)return {_type="Color3",R=r/255,G=g/255,B=b/255}end},
        UDim={new=function(a,b)return {Scale=a,Offset=b}end},
        UDim2={new=function(xs,xo,ys,yo)return {X=xo,Y=yo,XScale=xs,YScale=ys}end,
            fromOffset=function(x,y)return {X=x,Y=y}end,fromScale=function(x,y)return {X=x,Y=y}end},
        Instance={new=new},RaycastParams={new=function()return {}end},OverlapParams={new=function()return {}end},
        typeof=kind,os=mockOS,
        task={spawn=function(fn)fn()end,defer=function(fn)fn()end,delay=function(seconds,fn)
            w.timerSerial+=1
            local timer={id=w.timerSerial,at=w.time+seconds,fn=fn}
            w.timers[timer.id]=timer;return timer
        end,cancel=function(timer)w.timers[timer.id]=nil end},
        getgenv=function()return w.localEnvironment end,
        readfile=function(path)assert(stored[path],"file absent");return stored[path]end,
        writefile=function(path,value) if w.writeBlocked then error("disk unavailable") end;stored[path]=value end,
        require=function(object)return assert(object.ModuleValue,"module unavailable")end,
        warn=function(message)w.warning=message end,
    },{__index=getfenv()})
    env.loadstring=function(source,name)
        local fn,err=loadstring(source,name)
        if fn then setfenv(fn,env) end
        return fn,err
    end
    function w:registerNative(fn,scriptName,name,values)
        local scripts=player:FindFirstChild("PlayerScripts")
        if not scripts then scripts=new("PlayerScripts");scripts.Name="PlayerScripts";scripts.Parent=player end
        local scriptObject=scripts:FindFirstChild(scriptName)
        if not scriptObject then scriptObject=new("LocalScript");scriptObject.Name=scriptName;scriptObject.Parent=scripts end
        if not self.nativeRecords then
            self.nativeRecords,self.nativePool={},{}
            local originalInfo=debug.info
            local mockDebug=table.clone(debug)
            mockDebug.info=function(target,options)
                self.metrics.info+=1
                local record=self.nativeRecords[target]
                if not record then return originalInfo(target,options) end
                local source="Players.LocalPlayer.PlayerScripts."..record.script
                if options=="sn" then return source,record.name end
                if options=="n" then return record.name end
                if options=="s" then return source end
            end
            mockDebug.getupvalues=function(target)
                self.metrics.upvalues+=1
                local record=self.nativeRecords[target]
                return record and record.values() or {}
            end
            env.debug=mockDebug
            env.getgc=function()self.metrics.heap+=1;return table.clone(self.nativePool)end
            self:enableNativeConnections()
        end
        self.nativeRecords[fn]={script=scriptName,name=name,values=values}
        table.insert(self.nativePool,fn)
        return scriptObject
    end
    function w:enableNativeGrab()
        local state=nil
        local remote=rs:FindFirstChild("FeralGrabV2")
        local nativePress
        nativePress=function()
            local strike=state and state.strike
            if not state or state.ended or not strike or strike.pressed or w.time+1000<strike.t0 then return end
            strike.pressed=true
            w.nativeManualPresses=(w.nativeManualPresses or 0)+1
            remote:FireServer("press",state.id,strike.k,w.time+1000)
        end
        local function bind()
            cas:BindActionAtPriority("FeralGrabV2Press",function(_,inputState)
                if inputState==enum.UserInputState.Begin then nativePress() end
                return enum.ContextActionResult.Sink
            end,false,3000,enum.KeyCode.Space,enum.KeyCode.ButtonA,enum.KeyCode.ButtonR2,enum.UserInputType.MouseButton1)
        end
        local function onGrab(event,data)
            if event=="begin" then
                state={id=data.f or data.id,role=data.role or "prey",n=data.n or 1}
                bind()
            elseif state and data.f==state.id then
                if event=="strike" then state.strike=table.clone(data);state.strike.dur=w.configs.GrabV2Config.PASSES/data.spd
                elseif event=="n" then state.n=data.n
                elseif event=="bite" then state.strike=nil;state.biteUntil=w.time+.6
                elseif event=="end" then state.ended=true;cas:UnbindAction("FeralGrabV2Press")
                elseif event=="res" and state.strike and state.strike.k==data.k then state.strike.myTier=data.tier end
            end
        end
        remote.OnClientEvent:Connect(onGrab)
        uis.InputBegan:Connect(function(input,processed)
            if not self.nativeActionsEnabled and not processed and input.UserInputType==enum.UserInputType.MouseButton1
                and player.Character:GetAttribute("FeralPinned")~=true then
                w.nativeBites=(w.nativeBites or 0)+1
                player.Character:SetAttribute("WolfBiteAt",w.time+1000)
            end
        end)
        self:registerNative(nativePress,"FeralGrabV2UI","serverPress",function()
            return {[1]=state,[2]=w.configs.GrabV2Config,[3]=remote}
        end)
        self:registerNative(onGrab,"FeralGrabV2UI","onGrab",function()return {nativePress}end)
        self.nativeGrabState=function()return state end
    end
    function w:enableNativeActions()
        self.nativeActionsEnabled=true
        local remote=rs:FindFirstChild("WolfActions")
        local localBite=new("BindableEvent");localBite.Name="FeralBiteLocal";localBite.Parent=rs
        local mode,started=nil,false
        local function cancelFeed()
            mode,started=nil,false
            player.Character:SetAttribute("WolfFeed",false)
            remote:FireServer("Feed",false)
        end
        local function start()
            if mode then
                started=true;player.Character:SetAttribute("WolfFeed",mode)
                remote:FireServer("Feed",mode)
            end
        end
        local function toggleFeed()
            self.nativeFeedToggles=(self.nativeFeedToggles or 0)+1
            if mode then cancelFeed();return end
            local offer=player.Character:GetAttribute("FeedCan")
            if offer=="eat" or offer=="drink" then mode=offer;started=false;if not self.feedApproach then start() end end
        end
        local function doBite()
            local char=player.Character
            if char:GetAttribute("WolfRest")==true or self.time-(self.nativeRestReleasedAt or -100)<.7 then return end
            self.nativeBites=(self.nativeBites or 0)+1
            self.lastBiteAt=self.time;char:SetAttribute("WolfBiteAt",self.time+1000)
            remote:FireServer("Bite",self.time+1000)
            if self.nativeBiteTarget then
                local target=self.nativeBiteTarget
                self.nativeClaims=self.nativeClaims or {}
                table.insert(self.nativeClaims,{at=self.time+.27,char=char,target=target})
            end
        end
        local function tryBite()
            self.nativeBiteAttempts=(self.nativeBiteAttempts or 0)+1
            local char=player.Character
            if char:GetAttribute("FeralPinned")==true or char:FindFirstChild("FeralClamp")
                or (char:GetAttribute("FeralNoBiteUntil") or 0)>self.time+1000
                or self.time-(self.lastBiteAt or -100)<.5 or mode then return end
            doBite()
        end
        local function biteCooldown()return .5 end
        self:registerNative(biteCooldown,"WolfController","biteCooldown",function()return {}end)
        self:registerNative(doBite,"WolfController","doBite",function()
            return {[1]=player,[2]=self.nativeRestWanted==true,[3]=self.nativeRestActive==true,
                [4]=self.nativeRestReleasedAt or -100,[6]=self.lastBiteAt or -100,[8]=remote}
        end)
        self:registerNative(tryBite,"WolfController","tryBite",function()
            return {[1]=player,[3]=self.lastBiteAt or -100,[4]=biteCooldown,[5]=doBite}
        end)
        self:registerNative(toggleFeed,"WolfController","toggleFeed",function()
            return {[1]=mode,[2]=started,[5]=player,[6]=remote}
        end)
        -- Native cancelFeed is not retained by the captured script; cancellation uses toggleFeed.
        cas:BindActionAtPriority("NativeFeed",function(_,inputState)
            if inputState==enum.UserInputState.Begin then toggleFeed() end
            return enum.ContextActionResult.Sink
        end,false,2000,enum.KeyCode.E)
        local function onInput(input,processed)
            if not processed and (input.UserInputType==enum.UserInputType.MouseButton1 or input.KeyCode==enum.KeyCode.ButtonR2) then tryBite() end
        end
        self:registerNative(onInput,"WolfController","onInput",function()return {tryBite}end)
        uis.InputBegan:Connect(onInput)
        local function feedTap()toggleFeed()end
        self:registerNative(feedTap,"WolfController","feedTap",function()return {toggleFeed}end)
        player:GetAttributeChangedSignal("FeralFeedTap"):Connect(feedTap)
        self.finishFeedApproach=start
        self.nativeFeedMode=function()return mode,started end
        remote.OnClientEvent:Connect(function(event,reason)
            if event=="FeedStop" and (reason=="eaten" or reason=="nofood") then
                mode,started=nil,false;player.Character:SetAttribute("WolfFeed",false)
            end
        end)
    end
    function w:enableNativeConnections()
        env.getconnections=function(event)
            self.metrics.connections+=1
            local result={}
            for _,connection in ipairs(event.listeners or {})do
                if connection.Connected then table.insert(result,{Function=connection.fn}) end
            end
            return result
        end
    end
    function w:enableCarry()
        self:addConfig("Species",{})
        self:addConfig("AbilityConfig",{})
        self:addConfig("CarryConfig",{ENABLED=true,MIN_CARRIER_GROWTH=.67,MAX_BABY_GROWTH=.34,REACH=.75,
            WATER_OK={Otter=true,Alligator=true,Komodo=true},
            canCarry=function(_,_,carrier,baby)
                self.carryChecks=(self.carryChecks or 0)+1
                return carrier:GetAttribute("Growth")>=.67 and baby:GetAttribute("Growth")<.34
                    and carrier:GetAttribute("Species")==baby:GetAttribute("Species")
            end})
        cas:BindActionAtPriority("NativeCarry",function(_,inputState)
            if inputState==enum.UserInputState.Begin then self.nativeG=(self.nativeG or 0)+1 end
            return enum.ContextActionResult.Sink
        end,false,2000,enum.KeyCode.G)
    end
    function w:enableNativePose()
        -- Model the captured persistent blend and its supported override.
        -- A false WolfRest alone takes time to stand up from a cached pose.
        self.nativePose={sit=1,lie=1,hold=8}
        self.renders.WolfAnim={priority=202,fn=function(dt)
            local pose=self.nativePose
            local char=player.Character
            if char:GetAttribute("WolfRest")==true or char:GetAttribute("FeralDowned")==true then
                pose.sit=math.min(1,pose.sit+dt)
                pose.lie=math.min(1,pose.lie+dt)
            else
                pose.lie=math.max(0,pose.lie-dt/1.2)
                if pose.lie<=.4 then pose.sit=math.max(0,pose.sit-dt/.8) end
            end
            local override=char:GetAttribute("WolfDbgRestP")
            if kind(override)=="Vector3" then pose.sit,pose.lie,pose.hold=override.X,override.Y,override.Z end
            self.movingRestVisible=self.hum.MoveDirection.Magnitude>.13 and (pose.sit>.01 or pose.lie>.01)
        end}
    end
    function w:enableVultureFlight()
        self:spawn("Vulture")
        self.configs.FlightConfig.canFly=function(char)return char and (char:GetAttribute("Species")=="Vulture" or char:GetAttribute("Species")=="BaldEagle")end
        self.hum.FloorMaterial=enum.Material.Air;self.hum.MoveDirection=V3.new(1,0,0)
        self.player.Character:SetAttribute("FeralFlyLocal",true)
        local vel=new("LinearVelocity");vel.Name="FeralFlyVel";vel.Enabled=false;vel.VectorVelocity=V3.new();vel.Parent=self.root
        local rot=new("AlignOrientation");rot.Name="FeralFlyRot";rot.Enabled=false;rot.Parent=self.root
        self.vultureMovers={vel=vel,rot=rot}
        cas:BindActionAtPriority("FeralTalonLetGo",function(_,state)
            if state==enum.UserInputState.Begin then rs:FindFirstChild("FeralLunge"):FireServer("release") end
            return enum.ContextActionResult.Sink
        end,false,3000,enum.KeyCode.Space,enum.KeyCode.ButtonB)
    end
    function w:animal(species,position)
        local char=new("Model");char.Name=species or "Wolf";char.Parent=workspace
        local hum=new("Humanoid");hum.Parent=char
        local rootPart=new("Part");rootPart.Name="HumanoidRootPart";rootPart.Position=position or V3.new(0,3,0);rootPart.Parent=char
        char:SetAttribute("Species",species or "Wolf");char:SetAttribute("IsWolf",true)
        char:SetAttribute("Growth",.8);char:SetAttribute("Hunger",100);char:SetAttribute("Thirst",100)
        char:SetAttribute("FeralInjury",0);char:SetAttribute("FeralBleed",0);char:SetAttribute("FeralVenomAmt",0)
        char:SetAttribute("Stamina",80);char:SetAttribute("StaminaMax",100);char:SetAttribute("PassiveClimber",1)
        return char,hum,rootPart
    end
    function w:spawn(species)
        local old=player.Character
        if old then player.CharacterRemoving:Fire(old) end
        local char,hum,rootPart=self:animal(species)
        player.Character=char;self.hum,self.root=hum,rootPart
        player.CharacterAdded:Fire(char)
        return char
    end
    function w:enemy(pack,position)
        local p=new("Player");p.Parent=root;p.DisplayName="Other";p:SetAttribute("FeralPack",pack or 2)
        local char,hum,rootPart=self:animal("Wolf",position or V3.new(0,3,-4))
        p.Character=char;table.insert(players.list,p)
        return p,char,hum,rootPart
    end
    function w:npc(pack,position,withLitter)
        local char,hum,rootPart=self:animal("Wolf",position or V3.new(0,3,-3))
        local folder=workspace:FindFirstChild("FeralNPCs")
        if not folder then folder=new("Folder");folder.Name="FeralNPCs";folder.Parent=workspace end
        char.Parent=folder;char:SetAttribute("FeralNPC",true);char:SetAttribute("FeralPack",pack)
        char:SetAttribute("Growth",.2);char:SetAttribute("FeralName","Cub")
        rootPart.Size=V3.new(1,1,1);hum.HipHeight=.2
        local record
        if withLitter then
            local registry=rs:FindFirstChild("FeralLitter")
            if not registry then registry=new("Folder");registry.Name="FeralLitter";registry.Parent=rs end
            record=new("Configuration");record.Parent=registry
            record:SetAttribute("Pack",pack);record:SetAttribute("Alive",true);record:SetAttribute("Name","Cub")
            local body=new("ObjectValue");body.Name="Body";body.Value=char;body.Parent=record
        end
        return char,hum,rootPart,record
    end
    function w:step(dt)
        self.time+=dt or .05
        if self.acceptNativeFlightRepair and self.vultureMovers then
            local char=self.player.Character
            if char:GetAttribute("FeralFlyDrop")==true then
                char:SetAttribute("FeralFlyDrop",nil);char:SetAttribute("FeralFlyLocal",nil)
                self.nativeFlightDropped=true
            elseif self.nativeFlightDropped and char:GetAttribute("FeralFlyRelaunch")~=nil then
                char:SetAttribute("FeralFlyRelaunch",nil);char:SetAttribute("FeralFlyLocal",true)
                self.vultureMovers.vel.Enabled=true;self.vultureMovers.rot.Enabled=true
                self.vultureMovers.vel.VectorVelocity=V3.new(20,0,0);self.root.AssemblyLinearVelocity=V3.new(20,0,0)
                self.nativeFlightDropped=false;self.nativeFlightRestarts=(self.nativeFlightRestarts or 0)+1
            end
            if self.root.AssemblyLinearVelocity.Magnitude>2 then self.root.Position+=self.root.AssemblyLinearVelocity*(dt or .05) end
        end
        for index=#(self.nativeClaims or {}),1,-1 do
            local claim=self.nativeClaims[index]
            if self.time>=claim.at then
                table.remove(self.nativeClaims,index)
                self:remote("WolfActions"):FireServer("BiteHit",{t=claim.at+1000,m=claim.target})
                local hit2=self.configs.CombatConfig.HIT2
                if hit2 and hit2.PREDICT then self.predictedImpacts=(self.predictedImpacts or 0)+1 end
                local damage=self.nativeDamage or 0
                local hum=claim.target:FindFirstChildOfClass("Humanoid");hum.Health-=damage
                self:remote("FeralHit").OnClientEvent:Fire("hit",{a=claim.char,v=claim.target,dmg=damage,safe=self.nativeSafe==true})
                self:remote("FeralBiteLocal").Event:Fire(claim.target)
                self.nativeHitResponses=(self.nativeHitResponses or 0)+1
            end
        end
        self:runTimers()
        run.PreAnimation:Fire()
        run.Heartbeat:Fire(dt or .05)
        local renders={}
        for _,record in pairs(self.renders) do table.insert(renders,record) end
        table.sort(renders,function(a,b)return a.priority<b.priority end)
        for _,record in ipairs(renders) do record.fn(dt or .05) end
    end
    function w:runTimers()
        local ready={}
        for _,timer in pairs(self.timers)do if timer.at<=self.time then table.insert(ready,timer) end end
        table.sort(ready,function(a,b)return a.at<b.at end)
        for _,timer in ipairs(ready)do
            if self.timers[timer.id]==timer then self.timers[timer.id]=nil;timer.fn() end
        end
    end
    function w:advance(seconds)
        for _=1,math.ceil(seconds/.02) do self:step(.02) end
    end
    function w:input(key,kind,processed)
        local input={KeyCode=key or enum.KeyCode.Unknown,UserInputType=kind or enum.UserInputType.Keyboard,Position=V3.new(1200,850,0)}
        local order={}
        for name,fn in pairs(table.clone(self.bindings))do
            local info=self.bindingInfo[name] or {inputTypes={},priorityLevel=0}
            for _,value in ipairs(info.inputTypes)do
                if value==input.KeyCode or value==input.UserInputType then table.insert(order,{name=name,fn=fn,priority=info.priorityLevel});break end
            end
        end
        table.sort(order,function(a,b)return a.priority>b.priority end)
        for _,item in ipairs(order)do
            if item.fn(item.name,enum.UserInputState.Begin,input)==enum.ContextActionResult.Sink then processed=true;break end
        end
        uis.InputBegan:Fire(input,processed==true)
        return input
    end
    function w:connections()
        local n=0
        for _,s in ipairs({run.Heartbeat,run.PreAnimation,uis.InputBegan,uis.InputChanged,uis.JumpRequest,player.CharacterAdded,player.CharacterRemoving,player.Idled}) do n+=s:Count() end
        for _ in pairs(self.renders) do n+=1 end
        for _ in pairs(self.bindings) do n+=1 end
        for _,o in ipairs(self.objects) do for _,s in pairs(o._signals) do n+=s:Count() end end
        return n
    end
    function w:count(class)
        local n=0
        for _,o in ipairs(self.objects) do if not o._destroyed and o:IsA(class) then n+=1 end end
        return n
    end
    function w:remote(name) return rs:FindFirstChild(name) end
    w.env,w.player,w.workspace,w.rs,w.run,w.uis,w.cas,w.new,w.stored=env,player,workspace,rs,run,uis,cas,new,stored
    w:spawn("Wolf")
    return w
end
Mock.Enum,Mock.V3,Mock.V2 = enum,V3,V2
return Mock
