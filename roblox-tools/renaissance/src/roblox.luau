-- Roblox boundary. Staging creates only inactive, owner-scoped listeners.
local Roblox = {}
function Roblox.new(Core, environment)
    local b = { Core = Core, env = environment, generation = 0, modules = {},
        remoteConnections = {}, characterScope = nil, treeTarget = nil, tracked = {} }
    for _, name in ipairs({ "Players","ReplicatedStorage","RunService","UserInputService",
        "ContextActionService","HttpService","Workspace" }) do b[name] = game:GetService(name) end
    b.player = assert(b.Players.LocalPlayer,"LocalPlayer unavailable")
    b.clock = os.clock
    function b:delay(seconds,fn)
        if type(task)~="table" or type(task.delay)~="function" then return nil end
        local ok,handle=pcall(task.delay,seconds,fn)
        return ok and handle or nil
    end
    function b:cancelDelay(handle)
        if handle and type(task)=="table" and type(task.cancel)=="function" then pcall(task.cancel,handle) end
    end
    function b:serverNow()
        local ok, now = pcall(function() return self.Workspace:GetServerTimeNow() end)
        return ok and Core.finite(now) and now or nil
    end
    function b:attribute(object,key)
        if not object then return nil end
        local ok,value = pcall(function() return object:GetAttribute(key) end)
        if ok then return value end
        return nil
    end
    function b:setAttribute(object,key,value)
        if not object or not object.Parent then return false end
        local ok = pcall(function() object:SetAttribute(key,value) end)
        return ok and self:attribute(object,key) == value
    end
    function b:restoreAttribute(object,key,owned,original)
        if object and object.Parent and self:attribute(object,key) == owned then
            return self:setAttribute(object,key,original)
        end
        return false
    end
    -- FeralHUD v2412 builds a Cluster with three named gait outlines. Paint
    -- those native keycaps only; HudTrot/HudSprint/HudBurst also feed other
    -- scripts and cannot be used as presentation-only flags.
    function b:paintHippoGait(tier)
        local painted=self.hippoGaitPaint
        local function restore()
            self.hippoGaitPaint=nil
            if not painted then return end
            for _,record in pairs(painted.keys) do
                if record.rim.Parent and record.rim.Color==record.paintedColor then
                    pcall(function()record.rim.Color=record.beforeColor end)
                end
                if record.cap.Parent and record.cap.BackgroundTransparency==record.paintedAlpha then
                    pcall(function()record.cap.BackgroundTransparency=record.beforeAlpha end)
                end
            end
        end
        if tier~="sprint" and tier~="burst" or game.PlaceVersion~=2412 then
            restore();return false
        end
        local gui=self.player:FindFirstChild("PlayerGui")
        gui=gui and gui:FindFirstChild("FeralHUD")
        local cluster=painted and painted.gui==gui and painted.cluster.Parent and painted.cluster
            or gui and gui:FindFirstChild("Cluster",true)
        if not cluster then restore();return false end
        if painted and painted.cluster~=cluster then restore();painted=nil end
        if not painted then
            local keys={}
            for _,name in ipairs({"trot","sprint","burst"}) do
                local outline=cluster:FindFirstChild(name,true)
                local cap=outline and outline:IsA("Frame") and outline:FindFirstChild("Cap")
                local rim=cap and cap:IsA("Frame") and cap:FindFirstChildOfClass("UIStroke")
                if not rim then return false end
                keys[name]={outline=outline,cap=cap,rim=rim,
                    beforeColor=rim.Color,beforeAlpha=cap.BackgroundTransparency}
            end
            painted={gui=gui,cluster=cluster,keys=keys};self.hippoGaitPaint=painted
        end
        local activeColor=painted.keys.trot.beforeColor
        local quietColor=painted.keys.sprint.beforeColor
        for name,record in pairs(painted.keys) do
            if not record.outline:IsDescendantOf(cluster) or record.cap.Parent~=record.outline
                or record.rim.Parent~=record.cap then restore();return false end
            local selected=name==tier
            local desiredColor=selected and activeColor or quietColor
            local desiredAlpha=selected and painted.keys.trot.beforeAlpha or painted.keys.sprint.beforeAlpha
            if record.rim.Color~=desiredColor then record.rim.Color=desiredColor end
            if record.cap.BackgroundTransparency~=desiredAlpha then record.cap.BackgroundTransparency=desiredAlpha end
            record.paintedColor,record.paintedAlpha=desiredColor,desiredAlpha
        end
        return true
    end
    function b:config(name)
        local world = self.ReplicatedStorage:FindFirstChild("FeralWorld")
        local object = world and world:FindFirstChild(name)
        if not object or not object:IsA("ModuleScript") then self.modules[name] = nil; return nil end
        local cached = self.modules[name]
        if cached and cached.object == object then return cached.value end
        local ok,value = pcall(require,object)
        if not ok or type(value) ~= "table" then return nil end
        self.modules[name] = { object = object, value = value }
        return value
    end
    function b:rest(char,on)
        if char ~= self.player.Character or not char or not char.Parent then return false end
        return self:fire("WolfActions","Rest",on)
    end
    function b:maskRest(char)
        if char ~= self.player.Character then return false end
        if self:attribute(char,"WolfRest") ~= true then return true end
        return self:setAttribute(char,"WolfRest",false)
    end
    function b:fire(name,...)
        local remote = self.ReplicatedStorage:FindFirstChild(name)
        if not remote or not remote:IsA("RemoteEvent") then return false end
        local args = table.pack(...)
        return pcall(function() remote:FireServer(table.unpack(args,1,args.n)) end)
    end
    function b:hasRemote(name)
        local remote = self.ReplicatedStorage:FindFirstChild(name)
        return remote and remote:IsA("RemoteEvent") or false
    end
    function b:nativeGrabBound()
        return self.ContextActionService:GetAllBoundActionInfo().FeralGrabV2Press ~= nil
    end
    function b:markGrabPress(session,strike,now)
        local native = self:nativeGrabController(now)
        local state = native and native.state()
        if state and not state.ended and tostring(state.id) == tostring(session)
            and type(state.strike) == "table" and state.strike.k == strike then
            state.strike.pressed = true -- an actual submitted input, never a fabricated grade
        end
    end
    function b:grabTextFocused()
        return self.UserInputService:GetFocusedTextBox() ~= nil
            or self:attribute(self.player,"FeralMenuOpen") == true
    end
    function b:grabSnapshot(now)
        local char=self.player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        return {now=now,serverNow=self:serverNow(),char=char,generation=self.generation,
            alive=char~=nil and char.Parent~=nil and hum~=nil and hum.Health>0,
            chat=self.UserInputService:GetFocusedTextBox()~=nil,
            gameMenu=self:attribute(self.player,"FeralMenuOpen")==true}
    end
    function b:unbindGrabManual(name)
        self.ContextActionService:UnbindAction(name)
    end
    function b:bindGrabManual(name,press)
        self.ContextActionService:BindActionAtPriority(name,function(_,state)
            if state == Enum.UserInputState.Begin then press() end
            return Enum.ContextActionResult.Sink
        end,false,3000,Enum.KeyCode.Space,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonR2)
    end
    function b:nativeGrabController(now)
        local scripts = self.player:FindFirstChild("PlayerScripts")
        local scriptObject = scripts and scripts:FindFirstChild("FeralGrabV2UI")
        local currentRemote=self.ReplicatedStorage:FindFirstChild("FeralGrabV2")
        if self.grabController and self.grabController.remote~=currentRemote then
            self.grabController,self.grabDiscovery,self.nextGrabDiscovery=nil,nil,0
        end
        if self.grabController and self.grabController.script == scriptObject and scriptObject.Parent then
            return self.grabController
        end
        self.grabController = nil
        if not scriptObject then self.grabDiscovery = nil; return nil end
        if self.grabDiscovery and self.grabDiscovery.script ~= scriptObject then self.grabDiscovery = nil end
        if not self.grabDiscovery and now < (self.nextGrabDiscovery or 0) then return nil end
        if self.deferNativeDiscovery or type(getconnections) ~= "function" or type(debug) ~= "table" or type(debug.info) ~= "function" then return nil end
        local many = type(debug.getupvalues) == "function" and debug.getupvalues
            or type(getupvalues) == "function" and getupvalues
        local one = type(debug.getupvalue) == "function" and debug.getupvalue
            or type(getupvalue) == "function" and getupvalue
        if not many and not one then return nil end
        local function upvalues(fn)
            if many then
                local ok,values = pcall(many,fn)
                return ok and type(values) == "table" and values or {}
            end
            local values = {}
            for index = 1,12 do
                local ok,a,c = pcall(one,fn,index)
                if not ok then break end
                values[index] = c ~= nil and type(a) == "string" and c or a
            end
            return values
        end
        local function nativeName(fn)
            local ok,source,name = pcall(debug.info,fn,"sn")
            if not ok then return nil end
            local owned=type(source)=="string" and source:find("FeralGrabV2UI",1,true)~=nil
            if type(getfenv) == "function" then
                local valid,env = pcall(getfenv,fn)
                if valid and type(env) == "table" and env.script ~= nil then
                    if env.script ~= scriptObject then return nil end
                    owned=true
                end
            end
            return owned and name or nil
        end
        local previous=self.env.FERAL_RENAISSANCE_ACTIVE
        local inherited=previous and previous.bridge and previous.bridge.grabController
        if inherited and inherited.script==scriptObject and type(inherited.press)=="function"
            and type(inherited.state)=="function" and type(inherited.bind)=="function"
            and nativeName(inherited.press)=="serverPress" then
            local remote=self.ReplicatedStorage:FindFirstChild("FeralGrabV2")
            for _,value in pairs(upvalues(inherited.press)) do
                if remote and value==remote then
                    inherited.remote=remote
                    self.grabController=inherited;return inherited
                end
            end
        end
        local pool,source=self:nativeFunctions(now)
        if not pool then return nil end
        if not self.grabDiscovery or self.grabDiscovery.source~=source then
            self.nextGrabDiscovery = now+30
            self.grabDiscovery = {script=scriptObject,pool=pool,index=1,source=source}
        end
        -- Resume the shared own-callback pool without revisiting its prefix.
        local discovery,started,checked = self.grabDiscovery,self.clock(),0
        while discovery.index <= #discovery.pool do
            if checked >= 32 or self.clock()-started > .001 then return nil end
            local fn = discovery.pool[discovery.index]
            discovery.index += 1; checked += 1
            if type(fn) == "function" and nativeName(fn) == "serverPress" then
                local remote = self.ReplicatedStorage:FindFirstChild("FeralGrabV2")
                local matched = false
                for _,value in pairs(upvalues(fn)) do
                    if remote ~= nil and value == remote then matched = true end
                end
                if matched then
                    local native = { press = fn,script = scriptObject,remote=remote }
                    native.state = function()
                        local values=upvalues(fn)
                        local readable=false
                        for _,value in pairs(values) do if value==remote then readable=true end end
                        for _,value in pairs(values) do
                            if type(value) == "table" and value.id ~= nil
                                and (value.role == "prey" or value.role == "hunter") then
                                if native.lastState ~= value then native.lastState,native.ownerCharacter = value,self.player.Character end
                                if native.ownerCharacter ~= self.player.Character then return nil,true end
                                return value,true
                            end
                        end
                        return nil,readable
                    end
                    native.bind = function(on)
                        local cas = self.ContextActionService
                        if not on then
                            local info = cas:GetAllBoundActionInfo().FeralGrabV2Press
                            if info then
                                native.inputs = info.inputTypes and table.clone(info.inputTypes)
                                    or {Enum.KeyCode.Space,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonR2,Enum.UserInputType.MouseButton1}
                                native.priority = info.priorityLevel or 3000
                            end
                            cas:UnbindAction("FeralGrabV2Press")
                        else
                            -- v2412 callback prototype 73: Begin calls the
                            -- original serverPress; every state returns Sink.
                            cas:BindActionAtPriority("FeralGrabV2Press",function(_,state)
                                if state == Enum.UserInputState.Begin then fn() end
                                return Enum.ContextActionResult.Sink
                            end,false,native.priority or 3000,table.unpack(native.inputs or {
                                Enum.KeyCode.Space,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonR2,Enum.UserInputType.MouseButton1}))
                        end
                    end
                    self.grabController = native
                    self.grabDiscovery = nil
                    self:releaseNativeScan()
                    return native
                end
            end
        end
        if source.complete then self.grabDiscovery = nil end
        return nil
    end
    function b:isClimbing(char) return self:attribute(char,"FeralClimbLocal") == true end
    -- Inspect only three existing own-script callback chains. Never enumerate
    -- the Lua heap. Both consumers share a resumable, bounded queue.
    function b:nativeFunctions(now)
        if self.deferNativeDiscovery then return nil end
        if type(getconnections)~="function" or type(debug)~="table" or type(debug.info)~="function" then return nil end
        local scripts=self.player:FindFirstChild("PlayerScripts")
        local wolf=scripts and scripts:FindFirstChild("WolfController")
        local grab=scripts and scripts:FindFirstChild("FeralGrabV2UI")
        local scan=self.nativeScan
        if scan and (scan.wolf~=wolf or scan.grab~=grab or scan.complete and now>=scan.refreshAt) then scan=nil end
        if not scan then
            local signals={self.UserInputService.InputBegan,self.player:GetAttributeChangedSignal("FeralFeedTap")}
            local remote=self.ReplicatedStorage:FindFirstChild("FeralGrabV2")
            if remote and remote:IsA("RemoteEvent") then table.insert(signals,remote.OnClientEvent) end
            scan={wolf=wolf,grab=grab,functions={},seen={},queue={},cursor=1,signalIndex=1,
                signals=signals,complete=false,refreshAt=now+30}
            self.nativeScan=scan
        end
        if scan.complete or scan.lastStep==now then return scan.functions,scan end
        scan.lastStep=now
        local started,checked=self.clock(),0
        while checked<32 and self.clock()-started<.002 do
            if #scan.functions>=256 then scan.complete=true;break end
            local item=scan.queue[scan.cursor]
            if item then
                scan.cursor+=1;checked+=1
                local fn,depth=item.fn,item.depth
                if type(fn)~="function" or scan.seen[fn] or depth>4 then continue end
                scan.seen[fn]=true
                local ok,source=pcall(debug.info,fn,"s")
                local owned=ok and type(source)=="string" and (source:find("WolfController",1,true) or source:find("FeralGrabV2UI",1,true))
                if type(getfenv)=="function" then
                    local valid,env=pcall(getfenv,fn)
                    if valid and type(env)=="table" and env.script~=nil then owned=env.script==wolf or env.script==grab end
                end
                -- Executors may expose a vendor wrapper as the signal root.
                -- Inspect one root hop, but accept only validated own-script
                -- functions; never descend through an unrelated child chain.
                if not owned and depth~=0 then continue end
                if owned then table.insert(scan.functions,fn) end
                local count=0
                for _,value in pairs(self:upvalues(fn)) do
                    count+=1;if count>64 then break end
                    if type(value)=="function" and not scan.seen[value] and #scan.queue<512 then
                        table.insert(scan.queue,{fn=value,depth=depth+1})
                    end
                end
            elseif scan.connections then
                local connection=scan.connections[scan.connectionIndex]
                if not connection or scan.connectionIndex>96 then scan.connections=nil;continue end
                scan.connectionIndex+=1;checked+=1
                local ok,fn=pcall(function()return connection.Function end)
                if ok and type(fn)=="function" and #scan.queue<512 then table.insert(scan.queue,{fn=fn,depth=0}) end
            else
                local signal=scan.signals[scan.signalIndex]
                if not signal then scan.complete=true;break end
                scan.signalIndex+=1;checked+=1
                local ok,connections=pcall(getconnections,signal)
                if ok and type(connections)=="table" then scan.connections,scan.connectionIndex=connections,1 end
            end
        end
        if scan.complete then scan.queue,scan.seen,scan.connections,scan.signals=nil,nil,nil,nil end
        return scan.functions,scan
    end
    function b:releaseNativeScan()
        local native=self.wolfActions
        if native and native.tryBite and native.toggleFeed and self.grabController
            and not self.wolfDiscovery and not self.grabDiscovery then self.nativeScan=nil end
    end
    function b:closeNativeScan()
        self.nativeScan,self.wolfDiscovery,self.grabDiscovery=nil,nil,nil
        self.hippoActions,self.hippoDiscovery=nil,nil
        self.biteTiming=nil
    end
    function b:upvalues(fn)
        local many = type(debug.getupvalues) == "function" and debug.getupvalues
            or type(getupvalues) == "function" and getupvalues
        if many then
            local ok,values = pcall(many,fn)
            return ok and type(values) == "table" and values or {}
        end
        local one = type(debug.getupvalue) == "function" and debug.getupvalue
            or type(getupvalue) == "function" and getupvalue
        local values = {}
        if one then
            for index = 1,24 do
                local ok,a,value = pcall(one,fn,index)
                if not ok then break end
                if type(a) == "string" and value ~= nil then values[index] = value else values[index] = a end
            end
        end
        return values
    end
    function b:nativeWolfActions(now)
        local scripts = self.player:FindFirstChild("PlayerScripts")
        local ownScript = scripts and scripts:FindFirstChild("WolfController")
        if not ownScript then self.wolfActions,self.wolfDiscovery = nil,nil;return nil end
        if self.wolfActions and self.wolfActions.script ~= ownScript then self.wolfActions,self.wolfDiscovery = nil,nil end
        local native = self.wolfActions
        if not native then
            -- Preserve validated handles already held by our previous release.
            -- This reads the existing owner; it never enumerates another VM.
            local previous=self.env.FERAL_RENAISSANCE_ACTIVE
            local cached=previous and previous.bridge and previous.bridge.wolfActions
            local remote=self.ReplicatedStorage:FindFirstChild("WolfActions")
            if cached and cached.script==ownScript and type(cached.tryBite)=="function" then
                local t=self:upvalues(cached.tryBite)
                local d=type(t[5])=="function" and self:upvalues(t[5]) or {}
                local named,name=pcall(debug.info,t[4],"n")
                if t[1]==self.player and d[1]==self.player and remote and d[8]==remote
                    and type(t[4])=="function" and named and name=="biteCooldown" then
                    native={script=ownScript,tryBite=cached.tryBite,doBite=t[5],biteCooldown=t[4]}
                    local f=type(cached.toggleFeed)=="function" and self:upvalues(cached.toggleFeed) or {}
                    if f[5]==self.player and f[6]==remote then native.toggleFeed=cached.toggleFeed end
                    self.wolfActions=native
                end
            end
        end
        if native and native.tryBite and native.toggleFeed then return native end
        if not self.wolfDiscovery and now < (self.nextWolfDiscovery or 0) then return native end
        if self.deferNativeDiscovery or type(getconnections) ~= "function" or type(debug) ~= "table" or type(debug.info) ~= "function" then return native end
        if type(debug.getupvalues) ~= "function" and type(getupvalues) ~= "function"
            and type(debug.getupvalue) ~= "function" and type(getupvalue) ~= "function" then return native end
        local function nameOf(fn)
            if type(fn) ~= "function" then return nil end
            local ok,source,name = pcall(debug.info,fn,"sn")
            if not ok then return nil end
            local owned=type(source)=="string" and source:find("WolfController",1,true)~=nil
            if type(getfenv) == "function" then
                local valid,env = pcall(getfenv,fn)
                if valid and type(env)=="table" and env.script~=nil then
                    if env.script~=ownScript then return nil end
                    owned=true
                end
            end
            return owned and name or nil
        end
        local pool,source=self:nativeFunctions(now)
        if not pool then return native end
        if not self.wolfDiscovery or self.wolfDiscovery.source~=source then
            self.nextWolfDiscovery = now+30
            native = native or {script=ownScript}
            self.wolfActions,self.wolfDiscovery = native,{pool=pool,index=1,source=source}
        end
        local scan,started,count = self.wolfDiscovery,self.clock(),0
        local remote = self.ReplicatedStorage:FindFirstChild("WolfActions")
        while scan.index <= #scan.pool do
            if count >= 32 or self.clock()-started > .001 then return native end
            local fn = scan.pool[scan.index];scan.index += 1;count += 1
            local name = nameOf(fn)
            if name == "tryBite" or name == "toggleFeed" or name == "cancelFeed" then
                local playerMatched,remoteMatched = false,false
                for _,value in pairs(self:upvalues(fn)) do
                    if value == self.player then playerMatched = true end
                    if remote and value == remote then remoteMatched = true end
                    if name == "tryBite" and nameOf(value) == "doBite" then
                        for _,upvalue in pairs(self:upvalues(value)) do
                            if remote and upvalue == remote then remoteMatched = true;native.doBite=value end
                        end
                    end
                    if name == "tryBite" and nameOf(value) == "biteCooldown" then native.biteCooldown=value end
                end
                if playerMatched and remoteMatched then native[name] = fn end
            end
            if native.tryBite and native.toggleFeed then break end
        end
        if source.complete or native.tryBite and native.toggleFeed then self.wolfDiscovery = nil end
        self:releaseNativeScan()
        return native
    end
    function b:nativeFeedState(now)
        local native = self:nativeWolfActions(now)
        if not native or not native.toggleFeed then return nil,nil,false end
        local values = self:upvalues(native.toggleFeed)
        if values[5] ~= self.player or values[6] ~= self.ReplicatedStorage:FindFirstChild("WolfActions") then return nil,nil,false end
        local mode = values[1]
        if mode ~= nil and mode ~= "eat" and mode ~= "drink" then return nil,nil,false end
        return mode,values[2] == true,true
    end
    function b:toggleNativeFeed(now)
        local native = self:nativeWolfActions(now)
        return native and native.toggleFeed and pcall(native.toggleFeed) or false
    end
    function b:stopNativeFeed(now)
        local native = self:nativeWolfActions(now)
        if native and native.cancelFeed then return pcall(native.cancelFeed) end
        local mode,_,known=self:nativeFeedState(now)
        -- The named cancelFeed prototype may be unretained after script startup.
        -- The original toggle's first branch performs the same native cancellation.
        return known and mode~=nil and native and native.toggleFeed and pcall(native.toggleFeed) or false
    end
    function b:tryNativeBite(now)
        local native = self:nativeWolfActions(now)
        self.biteTiming=nil
        return native and native.tryBite and pcall(native.tryBite) or false
    end
    -- FeralHippoClient.finish uses the native clock and release path. Validate
    -- its captured own-player/remote layout before retaining or calling it.
    function b:hippoHandleValid(native)
        if game.PlaceVersion~=2412 or not native or type(native.finish)~="function" then return false end
        local scripts=self.player:FindFirstChild("PlayerScripts")
        local own=scripts and scripts:FindFirstChild("FeralHippoClient")
        local remote=self.ReplicatedStorage:FindFirstChild("FeralHippo")
        if not own or own~=native.script or not remote or remote~=native.remote then return false end
        local ok,source,name=pcall(debug.info,native.finish,"sn")
        if not ok or name~="finish" or type(source)~="string" or not source:find("FeralHippoClient",1,true) then return false end
        if type(getfenv)=="function" then
            local valid,env=pcall(getfenv,native.finish)
            if valid and type(env)=="table" and env.script~=nil and env.script~=own then return false end
        end
        local v=self:upvalues(native.finish)
        return v[2]==self.player and type(v[3])=="function" and type(v[4])=="table" and v[5]==remote
    end
    function b:nativeHippoActions(now)
        if self.hippoActions and self:hippoHandleValid(self.hippoActions) then return self.hippoActions end
        self.hippoActions=nil
        if self.deferNativeDiscovery or game.PlaceVersion~=2412 or type(getconnections)~="function"
            or type(debug)~="table" or type(debug.info)~="function" then return nil end
        local scripts=self.player:FindFirstChild("PlayerScripts")
        local own=scripts and scripts:FindFirstChild("FeralHippoClient")
        local remote=self.ReplicatedStorage:FindFirstChild("FeralHippo")
        if not own or not remote or not remote:IsA("RemoteEvent") then return nil end
        local scan=self.hippoDiscovery
        if scan and (scan.script~=own or scan.remote~=remote) then scan=nil;self.hippoDiscovery=nil end
        if not scan then
            if now<(self.nextHippoDiscovery or 0) then return nil end
            local signals={}
            if self.UserInputService.InputEnded then table.insert(signals,self.UserInputService.InputEnded) end
            if self.RunService.RenderStepped then table.insert(signals,self.RunService.RenderStepped) end
            table.insert(signals,self.player:GetAttributeChangedSignal("FeralCrushTouchUp"))
            scan={script=own,remote=remote,signals=signals,signalIndex=1,queue={},cursor=1,seen={}}
            self.hippoDiscovery=scan
        end
        local started,checked=self.clock(),0
        while checked<24 and self.clock()-started<.001 do
            local item=scan.queue[scan.cursor]
            if item then
                scan.cursor+=1;checked+=1
                local fn=item.fn
                if type(fn)~="function" or scan.seen[fn] or item.depth>3 then continue end
                scan.seen[fn]=true
                local ok,source,name=pcall(debug.info,fn,"sn")
                local owned=ok and type(source)=="string" and source:find("FeralHippoClient",1,true)
                if type(getfenv)=="function" then
                    local valid,env=pcall(getfenv,fn)
                    if valid and type(env)=="table" and env.script~=nil then owned=env.script==own end
                end
                if not owned and item.depth~=0 then continue end
                if owned and name=="finish" then
                    local native={finish=fn,script=own,remote=remote}
                    if self:hippoHandleValid(native) then
                        self.hippoActions=native;self.hippoDiscovery=nil;return native
                    end
                end
                local count=0
                for _,value in pairs(self:upvalues(fn)) do
                    count+=1;if count>32 then break end
                    if type(value)=="function" and #scan.queue<192 then table.insert(scan.queue,{fn=value,depth=item.depth+1}) end
                end
            elseif scan.connections then
                local record=scan.connections[scan.connectionIndex]
                if not record or scan.connectionIndex>96 then scan.connections=nil;continue end
                scan.connectionIndex+=1;checked+=1
                local ok,fn=pcall(function()return record.Function end)
                if ok and type(fn)=="function" and #scan.queue<192 then table.insert(scan.queue,{fn=fn,depth=0}) end
            else
                local signal=scan.signals[scan.signalIndex]
                if not signal then self.hippoDiscovery=nil;self.nextHippoDiscovery=now+10;return nil end
                scan.signalIndex+=1;checked+=1
                local ok,connections=pcall(getconnections,signal)
                if ok and type(connections)=="table" then scan.connections,scan.connectionIndex=connections,1 end
            end
        end
        return nil
    end
    function b:finishNativeHippo(s,startedAt,now)
        if not s.alive or s.species~="Hippo" or s.char~=self.player.Character then return false end
        local native=self:nativeHippoActions(now)
        if not native or not self:hippoHandleValid(native) then return false end
        local state=self:upvalues(native.finish)[1]
        if type(state)~="table" or state.at~=startedAt or self:attribute(s.char,"FeralCrushAt")~=startedAt then return false end
        return pcall(native.finish) -- no supplied timestamp, multiplier or damage
    end
    function b:biteDelay(char)
        local c = self:config("CombatConfig")
        if c and type(c.hitDelay) == "function" then
            local ok,delay = pcall(c.hitDelay,char)
            if ok and Core.finite(delay) and delay >= .03 and delay <= 1 then return delay end
        end
        return c and Core.finite(c.HIT_DELAY) and math.clamp(c.HIT_DELAY,.03,1) or .27
    end
    function b:restLock(char)
        local profiles=self:config("AnimProfiles")
        local profile=profiles and profiles[self:attribute(char,"AnimProfile") or ""]
        local value=profile and profile.REST_UP_LOCK
        return Core.finite(value) and math.clamp(value,.05,1.5) or .7
    end
    function b:biteReadiness(s,now,policy)
        local function result(ready,reason,known)return {ready=ready,reason=reason,known=known~=false}end
        if not s.alive then return result(false,"waiting for animal") end
        if s.chat or s.gameMenu then return result(false,"menu or text input") end
        if s.captured or s.char:FindFirstChild("FeralClamp") then return result(false,"capture or carry lock") end
        if s.feeding then return result(false,"feeding") end
        if s.rest or policy.manualRest or policy:restLocked(now,self:restLock(s.char)) then return result(false,"Rest or stand-up lock") end
        if s.ability or self:attribute(s.char,"FeralKingsAt") or self:attribute(s.char,"FeralCrushAt") then
            return result(false,"native ability lock")
        end
        for _,key in ipairs({"FeralNoBiteUntil","FeralVenomRecoilUntil"}) do
            local at=self:attribute(s.char,key)
            if at~=nil and (not Core.finite(at) or not s.serverNow) then return result(false,"native timing unknown",false) end
            if at and at>s.serverNow then return result(false,"native bite lock") end
        end
        local native=self.wolfActions
        if not native or not native.tryBite or not native.doBite or not native.biteCooldown then
            -- Primary-input connections may be VM-isolated. The captured
            -- cooldown calculation and own SafeTime bite marker remain useful,
            -- but do not establish the inaccessible private Rest/input state.
            local species=self:config("Species")
            local passive=self:config("PassiveConfig")
            local at=self:attribute(s.char,"WolfBiteAt")
            if not species or type(species.biteCooldown)~="function" or not s.serverNow or not Core.finite(at)
                or at>s.serverNow+1 then return result(false,"native timing unavailable",false) end
            local ok,cd=pcall(species.biteCooldown,self:attribute(s.char,"Species") or species.DEFAULT,self:attribute(s.char,"Growth") or 1)
            local mult=1
            if passive and passive.biteCdMult~=nil then
                local valid,value=pcall(passive.biteCdMult,s.char)
                if not valid or not Core.finite(value) or value<=0 then return result(false,"native cooldown unknown",false) end
                mult=value
            end
            if not ok or not Core.finite(cd) or cd*mult<.03 or cd*mult>30 then return result(false,"native cooldown unknown",false) end
            local r=result(s.serverNow-at>=cd*mult,s.serverNow-at>=cd*mult
                and "visible client checks clear; private state unverified" or "native cooldown")
            r.timingSource="native config and own bite marker";r.privateStateKnown=false
            if not r.ready then r.nextAt=now+math.max(.015,cd*mult-(s.serverNow-at)) end
            return r
        end
        local timing=self.biteTiming
        if not timing or timing.native~=native or now>=timing.nextAt then
            if self.deferNativeDiscovery then return result(false,"native timing deferred",false) end
            local try,doBite=self:upvalues(native.tryBite),self:upvalues(native.doBite)
            local remote=self.ReplicatedStorage:FindFirstChild("WolfActions")
            if try[1]~=self.player or try[4]~=native.biteCooldown or try[5]~=native.doBite
                or doBite[1]~=self.player or doBite[8]~=remote or not remote
                or not Core.finite(try[3]) or not Core.finite(doBite[4])
                or type(doBite[2])~="boolean" or type(doBite[3])~="boolean" then
                return result(false,"native timing layout unknown",false)
            end
            -- The captured biteCooldown prototype is a pure native calculation.
            -- No attack/cooldown state is changed or bypassed.
            local ok,cd=pcall(native.biteCooldown)
            if not ok or not Core.finite(cd) or cd<.03 or cd>30 then return result(false,"native cooldown unknown",false) end
            timing={native=native,lastBite=try[3],lastRest=doBite[4],resting=doBite[2] or doBite[3],cd=cd,nextAt=now+.05}
            self.biteTiming=timing
        end
        if timing.resting or now-timing.lastRest<self:restLock(s.char) then return result(false,"native Rest lock") end
        if now-timing.lastBite<timing.cd then
            local r=result(false,"native cooldown");r.nextAt=timing.lastBite+timing.cd;return r
        end
        local r=result(true,"client checks clear; gameplay unverified")
        r.privateStateKnown=true;r.timingSource="validated own native closures"
        return r
    end
    function b:io()
        return {
            available = type(readfile) == "function" and type(writefile) == "function",
            read = function(path)
                assert(type(readfile) == "function","readfile unavailable")
                return self.HttpService:JSONDecode(readfile(path))
            end,
            write = function(path,value)
                assert(type(writefile) == "function","writefile unavailable")
                writefile(path,self.HttpService:JSONEncode(value))
                return true
            end,
        }
    end
    function b:water(char,hum,root)
        if not hum or not root then return false,false end
        local swim = self:attribute(char,"FeralSwimLocal") == true
            or hum:GetState() == Enum.HumanoidStateType.Swimming or hum.FloorMaterial == Enum.Material.Water
        local under = self:attribute(char,"FeralUnderwater") == true
            or (swim and self:attribute(char,"FeralDiving") == true)
        local params = RaycastParams.new()
        params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Include,{self.Workspace.Terrain}
        params.IgnoreWater = false
        local body = math.max(hum.HipHeight+root.Size.Y/2,.2)
        local y,top = root.Position.Y+40,nil
        for _ = 1,2 do
            local hit = self.Workspace:Raycast(Vector3.new(root.Position.X,y,root.Position.Z),
                Vector3.new(0,-(y-root.Position.Y+body*2),0),params)
            if not hit then break end
            if hit.Material == Enum.Material.Water then top = hit.Position.Y; break end
            if hit.Position.Y <= root.Position.Y then break end
            y = hit.Position.Y-.3
        end
        local depth = top and top-root.Position.Y
        if depth and depth > math.max(1.6,body*1.2) then under = true end
        local surface = swim and depth ~= nil and not under
            and depth >= -math.max(1.6,body*1.25) and depth <= math.max(1.6,body*1.2)
        return swim,under,surface == true,depth
    end
    function b:snapshot(now, waterNeeded)
        local char = self.player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local at = self:serverNow()
        local deadline = self:attribute(self.player,"FeralCombatUntil")
        local combat = nil
        if at and (deadline == nil or Core.finite(deadline)) then combat = (deadline or 0) > at end
        local s = { now = now, serverNow = at, char = char, hum = hum, root = root,
            generation = self.generation, species=self:attribute(char,"Species"),
            alive = char ~= nil and char.Parent ~= nil and hum ~= nil and root ~= nil and hum.Health > 0,
            hp = hum and hum.Health or 0, maxHP = hum and hum.MaxHealth or 0,
            chat = self.UserInputService:GetFocusedTextBox() ~= nil,
            gameMenu = self:attribute(self.player,"FeralMenuOpen") == true,
            combat = combat, rest = self:attribute(char,"WolfRest") == true,
            feeding = false, captured = false, moving = false, locomotion = "NONE",
            injury = self:attribute(char,"FeralInjury"), bleed = self:attribute(char,"FeralBleed"),
            venom = self:attribute(char,"FeralVenomAmt"), stamina = self:attribute(char,"Stamina"),
            maxStamina=self:attribute(char,"StaminaMax"),
            hunger = self:attribute(char,"Hunger"), thirst = self:attribute(char,"Thirst"),
            survival = self:attribute(self.player,"FeralSurvival") }
        if not s.alive then return s end
        local feed = self:attribute(char,"WolfFeed")
        s.feedMode = (feed == "eat" or feed == "drink") and feed or nil
        s.feeding = feed == true or s.feedMode ~= nil
        s.captured = self:attribute(char,"FeralPinned") == true
            or self:attribute(char,"FeralCarried") == true or self:attribute(char,"FeralDragged") == true
        s.pinned = self:attribute(char,"FeralPinned") == true or self:attribute(char,"FeralDragged") == true
        s.carried = self:attribute(char,"FeralCarried") == true
        s.climbing = self:isClimbing(char)
        s.climbCan = self:attribute(char,"ClimbCan") == true
        s.climber = self:attribute(char,"PassiveClimber")
        s.flying = self:attribute(char,"FeralFlyLocal") == true
        s.diveCan = self:attribute(char,"DiveCan") == true
        s.burst = self:attribute(self.player,"HudBurst") == true or self:attribute(char,"FeralFlyBurst") == true
        -- v2412 WolfController input callback accepts MouseButton1/R2.
        -- MouseButton2 is a camera control, not a continuously held bite.
        s.attackHeld = self.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        local padOK,padHeld=pcall(self.UserInputService.IsGamepadButtonDown,self.UserInputService,
            Enum.UserInputType.Gamepad1,Enum.KeyCode.ButtonR2)
        s.attackHeld=s.attackHeld or padOK and padHeld==true
        local velocity = root.AssemblyLinearVelocity
        s.moving = hum.MoveDirection.Magnitude > .13 or Vector3.new(velocity.X,0,velocity.Z).Magnitude >= 2
        local clamp = char:FindFirstChild("FeralClamp")
        s.holding = clamp ~= nil and clamp:IsA("ObjectValue") and clamp.Value ~= nil
            or self:attribute(char,"FeralCarcassCarry") == true
        s.talonLock=self:attribute(char,"FeralTalonLock")
        s.diveLock=self:attribute(char,"FeralDiveLocal")
        s.ability = self:attribute(char,"FeralCrushAt")~=nil and self:attribute(char,"FeralCrushAt")~=false
            or self:attribute(char,"FeralDeathRollLocal") == true
            or self:attribute(char,"FeralDowned") == true
            or self:attribute(char,"FeralRolling") == true
            or s.talonLock~=nil or s.diveLock~=nil
            or self:attribute(char,"FeralDiveBomb") == true
            or self:attribute(char,"FeralVenomDown") == true
            or self:attribute(char,"FeralTumbleAt") ~= nil
        if waterNeeded then
            s.swimming,s.underwater,s.surface,s.depth = self:water(char,hum,root)
        else
            s.swimming = self:attribute(char,"FeralSwimLocal") == true
            s.underwater = self:attribute(char,"FeralUnderwater") == true
        end
        s.locomotion = s.underwater and "UNDERWATER" or s.flying and "FLIGHT"
            or s.climbing and "CLIMB" or s.swimming and "SWIM" or s.burst and "BURST" or "LAND"
        return s
    end
    local function knownPack(v)
        if type(v) == "number" then return v > 0 and tostring(v) or nil end
        if type(v) == "string" and v ~= "" and v ~= "0" and v ~= "None" and v ~= "nil" then return v end
        return nil
    end
    function b:litterRecord(char)
        local record = self.litterByBody and self.litterByBody[char]
        local body = record and record.Parent and record:FindFirstChild("Body")
        if body and body:IsA("ObjectValue") and body.Value == char and self:attribute(record,"Alive") == true then return record end
        return nil
    end
    function b:refreshLitter()
        local map = {}
        local folder = self.ReplicatedStorage:FindFirstChild("FeralLitter")
        if folder then
            for index,record in ipairs(folder:GetChildren()) do
                if index > 256 then break end
                local body = record:FindFirstChild("Body")
                local char = body and body:IsA("ObjectValue") and body.Value
                if char and char:IsA("Model") and char.Parent and self:attribute(record,"Alive") == true then map[char] = record end
            end
        end
        self.litterByBody = map
        return map
    end
    function b:packFor(char,owner)
        local record = self:litterRecord(char)
        return knownPack(self:attribute(owner,"FeralPack")) or knownPack(self:attribute(char,"FeralPack"))
            or knownPack(self:attribute(record,"Pack"))
    end
    function b:affiliation(other, char)
        local own = self:packFor(self.player.Character,self.player)
        local theirs = self:packFor(char,other or (char and self.Players:GetPlayerFromCharacter(char)))
        return own and theirs and (own == theirs and "same" or "other") or "unknown"
    end
    function b:targetBlocker(char,owner)
        if not char or not char.Parent or self:attribute(char,"FeralDead") == true then return "target unavailable" end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return "target unavailable" end
        if char:FindFirstChildOfClass("ForceField") then return "protected target" end
        local safe,now = self:attribute(char,"FeralSafeUntil"),self:serverNow()
        if Core.finite(safe) and (not now or safe > now) then return "spawn protection" end
        owner = owner or self.Players:GetPlayerFromCharacter(char)
        if self:attribute(owner,"FeralTut") == true or self:attribute(owner,"FeralTutorial") == true then return "tutorial protection" end
        local tutorial = self:attribute(char,"TutorialOwner")
        if tutorial ~= nil and tutorial ~= self.player.UserId then return "another tutorial target" end
        if self:attribute(char,"FeralBurrowed") == true then return "burrowed target" end
        return nil
    end
    function b:combatEligible(char)
        return char ~= self.player.Character and not self:targetBlocker(char)
            and self:affiliation(nil,char) ~= "same"
    end
    function b:sameTree(a,c)
        if not self:isClimbing(a) or not self:isClimbing(c) then return false end
        local axisA,axisB = self:attribute(a,"FeralClimbAxis"),self:attribute(c,"FeralClimbAxis")
        return typeof(axisA) == "Vector3" and typeof(axisB) == "Vector3" and (axisA-axisB).Magnitude < 5
    end
    function b:candidates(s, range,visual)
        local all,seen = {},{}
        if not s.alive then self.tracked = all; return all end
        local litter = self:refreshLitter()
        local function add(char,other,npc)
            if not char or char == s.char or not char.Parent or seen[char] then return end
            local owner = self.Players:GetPlayerFromCharacter(char)
            if owner == self.player then return end
            local root,hum = char:FindFirstChild("HumanoidRootPart"),char:FindFirstChildOfClass("Humanoid")
            if not root or not hum or hum.Health <= 0 then return end
            local delta = root.Position-s.root.Position
            local distance = delta.Magnitude
            if distance > range then return end
            local record = litter[char]
            seen[char] = true
            table.insert(all,{ char = char, root = root, hum = hum, player = owner, npc = owner == nil,
                litter = owner == nil and record or nil,
                name = owner and owner.DisplayName or self:attribute(record,"Name") or self:attribute(char,"FeralName") or char.Name,
                distance = distance,affiliation = self:affiliation(owner,char), flat = Vector3.new(delta.X,0,delta.Z),
                sameTree = self:sameTree(s.char,char),
                protected = self:targetBlocker(char,owner) ~= nil })
        end
        for _, other in ipairs(self.Players:GetPlayers()) do
            if other ~= self.player then add(other.Character,other,false) end
        end
        local folder = self.Workspace:FindFirstChild("FeralNPCs")
        if folder then
            for i, char in ipairs(folder:GetChildren()) do
                if i > 256 then break end
                if char:IsA("Model") then add(char,nil,true) end
            end
        end
        for char in pairs(litter) do add(char,nil,true) end
        table.sort(all,function(a,c) return a.distance < c.distance end)
        local tracked,players,playerCount,npcCount = {},0,0,0
        for _,target in ipairs(all) do
            if target.player then
                playerCount += 1
                if players < 24 then table.insert(tracked,target);players += 1 end
            elseif target.litter or self:packFor(target.char) then
                npcCount += 1
            end
        end
        if visual ~= false then
            self.tracked,self.replicatedCount,self.packNPCCount = tracked,playerCount,npcCount
            self.allCandidates=all
        end
        return all
    end
    function b:carrying(s,target)
        local clamp=s.char and s.char:FindFirstChild("FeralClamp")
        local value=clamp and clamp:IsA("ObjectValue") and clamp.Value
        return value ~= nil and (value==target or value:IsDescendantOf(target)) and self:attribute(clamp,"Carry")==true
    end
    function b:carryEligible(s,target)
        if not s.alive or not target or not target.char.Parent or not target.root.Parent or target.hum.Health<=0
            or self:attribute(target.char,"FeralCarried")==true or self:attribute(target.char,"FeralDragged")==true
            or self:affiliation(target.player,target.char)=="other" then return false end
        local cfg,species,abilities=self:config("CarryConfig"),self:config("Species"),self:config("AbilityConfig")
        if not cfg or cfg.ENABLED~=true or not Core.finite(cfg.REACH) or type(cfg.canCarry)~="function" or not species or not abilities then return false end
        local diff=target.root.Position-s.root.Position
        local reach=1.5+cfg.REACH*(s.root.Size.Z+target.root.Size.Z)
        local flat=Vector3.new(diff.X,0,diff.Z)
        local look=s.root.CFrame.LookVector;look=Vector3.new(look.X,0,look.Z)
        if diff.Magnitude>reach or flat.Magnitude>.1 and look.Magnitude>.1 and look.Unit:Dot(flat.Unit)<.2 then return false end
        local ok,can=pcall(cfg.canCarry,species,abilities,s.char,target.char)
        return ok and can==true
    end
    function b:waterCub(s)
        local best
        for _,target in ipairs(self:candidates(s,35,false)) do
            if self:carryEligible(s,target) then
                local swim,_,_,depth=self:water(target.char,target.hum,target.root)
                if (swim or depth and depth>=-.25) and (not best or target.distance<best.distance) then best=target end
            end
        end
        return best
    end
    function b:carryWaterAllowed(s)
        local swim,under,_,depth=self:water(s.char,s.hum,s.root)
        if not swim and not under and (not depth or depth<-.25) then return true end
        local cfg=self:config("CarryConfig")
        return cfg and type(cfg.WATER_OK)=="table" and cfg.WATER_OK[self:attribute(s.char,"Species")]==true or false
    end
    function b:geometry(values,s,target)
        if not values or not s.alive then return nil end
        if not target.root.Parent or not target.hum.Parent or target.hum.Health <= 0 then return nil end
        local diff = target.root.Position-s.root.Position
        local flat = Vector3.new(diff.X,0,diff.Z)
        local fwd = s.root.CFrame.LookVector
        fwd = Vector3.new(fwd.X,0,fwd.Z)
        if fwd.Magnitude < .01 then return nil end
        if type(values.biteLook) == "function" then
            local ok,v = pcall(values.biteLook,s.char,fwd.Unit)
            if ok and typeof(v) == "Vector3" then fwd = Vector3.new(v.X,0,v.Z) end
        end
        if fwd.Magnitude < .01 then return nil end
        local ok,gap = pcall(values.bodyGap,target.root,flat)
        if not ok or not Core.finite(gap) then return nil end
        local function modifier(key, default)
            if type(values[key]) ~= "function" then return default end
            local good,v = pcall(values[key],s.char)
            return good and Core.finite(v) and v or default
        end
        local box = self:attribute(s.root,"FeralBoxFull")
        if not Core.finite(box) or box <= 0 then box = s.root.Size.Z end
        local reach = (box*.5+s.hum.HipHeight*values.REACH+values.SLACK)*values.HIT_SCALE*modifier("reachMult",1)
        local angle = flat.Magnitude > .01 and fwd.Unit:Dot(flat.Unit) or 1
        local cone = modifier("coneFor",values.CONE)
        local height = math.abs(target.root.Position.Y-s.root.Position.Y)
        local vertical = (s.hum.HipHeight+target.hum.HipHeight)*values.MAX_DY*modifier("dyMult",1)
        return { valid = gap < reach and angle > math.cos(math.rad(cone)) and height < vertical,
            withinBodyRange = gap < reach and height < vertical,
            gap = gap, reach = reach, angle = angle, distance = diff.Magnitude,score = gap-angle*2 }
    end
    function b:occluded(s,target)
        local params = RaycastParams.new()
        params.FilterType,params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude,{s.char}
        params.IgnoreWater = true
        local hit = self.Workspace:Raycast(s.root.Position,target.root.Position-s.root.Position,params)
        return hit ~= nil and not hit.Instance:IsDescendantOf(target.char)
    end
    function b:leadPoint(s,target)
        local point=target.root.Position
        local a,bv=target.root.AssemblyLinearVelocity,s.root.AssemblyLinearVelocity
        if typeof(a)~="Vector3" or typeof(bv)~="Vector3" then return point end
        local lead=(a-bv)*math.min(.35,self:biteDelay(s.char))
        lead=Vector3.new(lead.X,0,lead.Z)
        if not Core.finite(lead.Magnitude) then return point end
        if lead.Magnitude>4 then lead=lead.Unit*4 end
        return point+lead
    end
    function b:autoAttackTarget(s,guide,values)
        if not guide or guide.invalid or not guide.target or not s.alive then return false end
        local target=guide.target
        if not target.root.Parent or (target.root.Position-s.root.Position).Magnitude>45
            or not self:combatEligible(target.char) then return false end
        local geometry=self:geometry(values,s,target)
        return geometry~=nil and geometry.valid and not self:occluded(s,target)
    end
    function b:select(s, baseline, changed, all)
        local previousAssist=self.reachTarget
        self.treeTarget = nil
        self.reachTarget = nil
        local best,score = nil,math.huge
        local eligible={}
        for _, target in ipairs(all) do
            if target.distance <= 45 and self:combatEligible(target.char) then
                table.insert(eligible,target)
                if target.sameTree and (not self.treeTarget or target.distance < self.treeTarget.distance) then self.treeTarget = target end
            end
        end
        local assisted,assistScore = nil,math.huge
        local selectionModel = table.clone(changed)
        selectionModel.biteLook = baseline.biteLook
        for _,target in ipairs(eligible) do
                local geometry = self:geometry(selectionModel,s,target)
                if geometry and geometry.withinBodyRange then
                    local stock = self:geometry(baseline,s,target)
                    local rank = target.distance+(target.affiliation == "unknown" and .5 or 0)
                        -(stock and stock.valid and .75 or 0)
                    if previousAssist and previousAssist.char==target.char then rank-=.65 end
                    if rank < assistScore and not self:occluded(s,target) then
                        assisted,assistScore = target,rank
                    end
                end
        end
        self.reachTarget = assisted
        for _, target in ipairs(eligible) do
                local base = self:geometry(baseline,s,target)
                local extended = self:geometry(changed,s,target)
                if base or extended then
                    local rank = (extended and extended.score or math.huge) + (extended and extended.valid and 0 or 1000)
                    if rank < score then best,score = { target = target, baseline = base, extended = extended },rank end
                end
        end
        if best then
            best.obstruction=best.target.protected or self:occluded(s,best.target)
            best.blocked=best.obstruction
        end
        return best
    end
    function b:refreshGuide(s,baseline,changed,guide)
        local target=guide.target
        if not s.alive or not target or not self:combatEligible(target.char) then
            guide.blocked,guide.invalid=true,true;return
        end
        guide.invalid=false
        guide.baseline=self:geometry(baseline,s,target)
        guide.extended=self:geometry(changed,s,target)
        -- A guide tracks the current selected body every frame. Target search
        -- and obstacle queries remain bounded background work.
        guide.blocked=guide.obstruction or not guide.extended or not guide.extended.valid
    end
    function b:friendlyCarry(s)
        if not s.carried or s.pinned then return false end
        local growth = self:attribute(s.char,"Growth")
        local species = self:attribute(s.char,"Species")
        if not Core.finite(growth) or growth > .34 or type(species) ~= "string" then return false end
        for _, other in ipairs(self.Players:GetPlayers()) do
            local adult = other.Character
            local ag = self:attribute(adult,"Growth")
            if adult ~= s.char and Core.finite(ag) and ag >= .67 and self:attribute(adult,"Species") == species then
                for _, name in ipairs({"FeralClamp","FeralClampLocal"}) do
                    local clamp = adult and adult:FindFirstChild(name)
                    if clamp and clamp:IsA("ObjectValue") then
                        local target = clamp.Value
                        if target and (target == s.char or target:IsDescendantOf(s.char)) then return true end
                    end
                end
            end
        end
        return false
    end
    function b:escapeAction(s)
        if not s.alive or self:friendlyCarry(s) then return nil,"friendly carry or no animal" end
        if s.holding and not s.captured then return nil,"carrying prey" end
        local clamp = self:attribute(s.char,"FeralClampN") or self:attribute(s.char,"FeralClampGame")
        local need = self:attribute(s.char,"FeralShakeNeed")
        local cue = s.captured or (Core.finite(clamp) and clamp > 0) or (Core.finite(need) and need > 0)
        if not cue then return nil,"watching native capture cues" end
        if s.carried then return "getoff","carried",.435 end
        local bindings = self.ContextActionService:GetAllBoundActionInfo()
        if bindings.FeralTugTap then return "shake","native tug",.12 end
        if bindings.FeralShakeTaps or bindings.FeralShakeMash then return "shake","native shake",.17 end
        return nil,"captured; no native escape binding"
    end
    function b:nearbyDanger(s)
        if not s.root then return true end
        local params = OverlapParams.new()
        params.FilterType,params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude,{s.char}
        params.MaxParts = 200
        local parts = self.Workspace:GetPartBoundsInRadius(s.root.Position,28,params)
        if #parts >= 200 then return true end
        for _, part in ipairs(parts) do
            local model = part:FindFirstAncestorOfClass("Model")
            local hum = model and model:FindFirstChildOfClass("Humanoid")
            if model ~= s.char and hum and hum.Health > 0 then return true end
        end
        return false
    end
    function b:safeStep(s, anchor)
        local config = self:config("SurvivalConfig")
        local threshold = config and config.AFK_MOVE
        if not Core.finite(threshold) or threshold < 0 or threshold+2 > 8 then return nil end
        local step = threshold+2
        local root = s.root
        local params = RaycastParams.new()
        params.FilterType,params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude,{s.char}
        params.IgnoreWater = false
        local function ground(at)
            local hit = self.Workspace:Raycast(at+Vector3.new(0,8,0),Vector3.new(0,-35,0),params)
            return hit and hit.Material ~= Enum.Material.Water and hit.Normal.Y > .86 and hit.Position or nil
        end
        local start = ground(root.Position)
        if not start then return nil end
        local forward = root.CFrame.LookVector
        forward = Vector3.new(forward.X,0,forward.Z)
        if forward.Magnitude < .01 then return nil end
        forward = forward.Unit
        local side = Vector3.new(-forward.Z,0,forward.X)
        local goals = { root.Position+side*step,root.Position-side*step,root.Position+forward*step,root.Position-forward*step }
        if anchor and (root.Position-anchor).Magnitude > threshold+.2 then goals = {anchor} end
        for _, goal in ipairs(goals) do
            local vector = goal-root.Position
            vector = Vector3.new(vector.X,0,vector.Z)
            if vector.Magnitude > threshold+.5 and vector.Magnitude <= 8 then
                local safe = true
                for distance = 0,vector.Magnitude+1.25,1 do
                    local point = ground(root.Position+vector.Unit*distance)
                    if not point or math.abs(point.Y-start.Y) > 1.1 then safe = false; break end
                end
                if safe and not self.Workspace:Raycast(root.Position+Vector3.new(0,1,0),vector,params) then
                    local ending = ground(goal)
                    if ending then return Vector3.new(goal.X,root.Position.Y+ending.Y-start.Y,goal.Z) end
                end
            end
        end
        return nil
    end
    function b:routeSafe(s,goal)
        if not s.alive or not goal or s.hum.FloorMaterial==Enum.Material.Air
            or s.hum.FloorMaterial==Enum.Material.Water then return false end
        local vector=goal-s.root.Position
        vector=Vector3.new(vector.X,0,vector.Z)
        if vector.Magnitude>8.1 then return false end
        if vector.Magnitude<.05 then return true end
        local params=RaycastParams.new()
        params.FilterType,params.FilterDescendantsInstances=Enum.RaycastFilterType.Exclude,{s.char}
        params.IgnoreWater=false
        local groundY
        for distance=0,vector.Magnitude+1.25,1 do
            local point=s.root.Position+vector.Unit*distance
            local hit=self.Workspace:Raycast(point+Vector3.new(0,8,0),Vector3.new(0,-35,0),params)
            if not hit or hit.Material==Enum.Material.Water or hit.Normal.Y<=.86 then return false end
            groundY=groundY or hit.Position.Y
            if math.abs(hit.Position.Y-groundY)>1.1 then return false end
        end
        return self.Workspace:Raycast(s.root.Position+Vector3.new(0,1,0),vector,params)==nil
    end
    function b:walk(s,goal)
        if s.char ~= self.player.Character or not s.hum or not s.root then return false end
        s.hum:MoveTo(goal or s.root.Position)
        return true
    end
    function b:pulseIdle()
        local ok = pcall(function()
            local v = game:GetService("VirtualUser")
            v:CaptureController()
            v:ClickButton2(Vector2.new(0,0))
        end)
        return ok
    end
    function b:attach(hub,scope)
        local function connect(signal,fn)
            local c = signal:Connect(function(...)
                if hub.active and not hub.closed then fn(...) end
            end)
            scope:add(function() c:Disconnect() end)
            return c
        end
        local function character(char)
            if self.characterScope then self.characterScope:close() end
            self.characterScope = Core.scope()
            self.generation += 1
            self.character = char
            hub:characterChanged(self.generation)
            if not char then return end
            for _, key in ipairs({"WolfRest","WolfBiteAt","WolfFeed","FeralPinned","FeralCarried",
                "FeralDragged","FeralTalonLock","FeralDiveLocal","FeralDeathRollLocal","FeralRolling",
                "FeralDowned","FeralVenomDown","FeralTumbleAt","FeralCrushAt","FeralCrushBiteAt","FeralClimbLocal","FeralFlyLocal","FeralUnderwater"}) do
                local c = char:GetAttributeChangedSignal(key):Connect(function()
                    if hub.active and not hub.closed and char == self.player.Character then hub:nativeAttribute(key) end
                end)
                self.characterScope:add(function() c:Disconnect() end)
            end
        end
        self.bindCharacter = character
        scope:add(function() if self.characterScope then self.characterScope:close() end end)
        connect(self.player.CharacterAdded,character)
        connect(self.player.CharacterRemoving,function() character(nil) end)
        connect(self.player.Idled,function() hub:idle() end)
        connect(self.player:GetAttributeChangedSignal("FeralRestTap"),function()
            if self.UserInputService:GetFocusedTextBox() then return end
            local now=self.clock()
            hub.policy:input("rest",now)
            hub.recovery:manual(now)
            hub.combatInput:cancel();hub.feeding:cancel("manual rest control",now);hub.rescue:cancel()
        end)
        connect(self.UserInputService.InputBegan,function(input,processed) hub:input(input,processed) end)
        connect(self.UserInputService.InputChanged,function(input)
            local kind = input.UserInputType
            if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.MouseWheel
                or kind == Enum.UserInputType.Touch then hub:physicalInput(kind == Enum.UserInputType.MouseMovement and "mouse" or "other") end
        end)
        local actionName = "FERAL_RENAISSANCE_" .. tostring(hub.token)
        -- CAS can consume event-driven sprint bindings. Native IsKeyDown
        -- polling can still see Right Shift; this limitation is recorded.
        self.ContextActionService:BindActionAtPriority(actionName,function(_,state,input)
            if not hub.active or hub.closed or self.UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
            if input.KeyCode == Enum.KeyCode.RightShift then
                if state == Enum.UserInputState.Begin then hub.ui:toggle() end
                return Enum.ContextActionResult.Sink
            end
            if state == Enum.UserInputState.Begin and input.KeyCode == Enum.KeyCode.G and hub:carryInput(input) then
                return Enum.ContextActionResult.Sink
            end
            if state == Enum.UserInputState.Begin then hub:preInput(input) end
            return Enum.ContextActionResult.Pass
        end,false,4000,Enum.KeyCode.RightShift,Enum.KeyCode.R,Enum.KeyCode.ButtonY,Enum.KeyCode.Z,Enum.KeyCode.X,
            Enum.KeyCode.E,Enum.KeyCode.F,Enum.KeyCode.G,
            Enum.KeyCode.Q,Enum.KeyCode.Space,Enum.KeyCode.ButtonR2,Enum.KeyCode.ButtonB,
            Enum.UserInputType.MouseButton1,Enum.UserInputType.MouseButton2)
        scope:add(function() self.ContextActionService:UnbindAction(actionName) end)
        connect(self.UserInputService.JumpRequest,function() hub:requestFlight() end)
        connect(self.RunService.Heartbeat,function(dt)
            local ok,err = pcall(hub.tick,hub,dt)
            if not ok then hub:fault(err) end
        end)
        local renderName = actionName .. "_RENDER"
        self.RunService:BindToRenderStep(renderName,Enum.RenderPriority.Camera.Value+3,function(dt)
            if hub.active and not hub.closed then
                local ok,err = pcall(hub.render,hub,dt)
                if not ok then hub:fault(err) end
            end
        end)
        scope:add(function() self.RunService:UnbindFromRenderStep(renderName) end)
        if self.RunService.PreAnimation then
            connect(self.RunService.PreAnimation,function() hub:maskPose() end)
        end
        scope:add(function()
            for _, item in pairs(self.remoteConnections) do item.connection:Disconnect() end
            table.clear(self.remoteConnections)
        end)
    end
    function b:bindNative(hub)
        for _, item in ipairs({{"FeralGrabV2","grab"},{"FeralHit","feedback"},{"FeralHippo","hippo"},{"WolfActions","actions"},
            {"FeralBiteLocal","biteLocal","BindableEvent"}}) do
            local remote = self.ReplicatedStorage:FindFirstChild(item[1])
            local old = self.remoteConnections[item[1]]
            if old and old.remote ~= remote then old.connection:Disconnect(); self.remoteConnections[item[1]] = nil; old = nil end
            if remote and remote:IsA(item[3] or "RemoteEvent") and not old then
                local kind = item[2]
                local signal = item[3] == "BindableEvent" and remote.Event or remote.OnClientEvent
                local c = signal:Connect(function(...)
                    if hub.active and not hub.closed then hub:nativeEvent(kind,...) end
                end)
                self.remoteConnections[item[1]] = { remote = remote,connection = c }
            end
        end
    end
    return b
end
return Roblox
