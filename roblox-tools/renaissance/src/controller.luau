local Controller = {}
function Controller.new(M,bridge,options)
    local Core = M.core
    local h = { version = "15.0.0", token = tostring(math.floor(bridge.clock()*1000000)),
        active = false, closed = false, ready = false, scope = Core.scope(),
        registry = Core.registry(), policy = M.policy.new(), ledger = Core.ledger(160),
        nextScan = 0, nextSlow = 0, nextBind = 0, nextSample = 0, nextEscape = 0,
        nextWalk = bridge.clock()+90, nextIdle = bridge.clock()+75,
        transactions = {}, earlyInputs = setmetatable({},{__mode = "k"}),
        notice = "Ready · Right Shift opens menu", bridge = bridge, options = options or {} }
    h.policy.lastPhysical = bridge.clock()
    h.settings,h.settingsOrigin = M.settings.load(bridge:io(),Core.specs)
    if h.options.settings then h.settings = M.settings.sanitize(h.options.settings,Core.specs) end
    for _,feature in ipairs(h.registry.order) do
        if not feature.permanent and not feature.linked then h.registry:request(feature.id,h.settings.states[feature.id]) end
    end
    h.features = M.features.new(Core,bridge,h.registry)
    h.grab = M.grab.new()
    h.recovery = M.recovery.new(bridge,h.policy,h.ledger)
    h.settingsAvailable = bridge:io().available ~= false
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
        self.features.leases:release("surface")
        self.surfaceUntil = nil
        if self.drop then
            bridge:restoreAttribute(self.drop.char,"FeralFlyDrop",true,self.drop.before)
            self.drop = nil
        end
    end
    function h:set(id,on)
        if self.closed or not self.active then return false end
        local feature = assert(self.registry.byId[id],"unknown feature")
        if feature.permanent or feature.linked then return false end
        self.registry:request(id,on)
        local now = bridge.clock()
        if id == "recovery" and not on then self.recovery.enabled = false; self.recovery:release("OFF",now) end
        if id == "minigame" then
            self.grab.enabled = on == true
            if not on then self.grab:reset("OFF") end
        end
        if id == "survivalAFK" and not on then self:stopWalk("disabled") end
        if id == "flight" and not on then self:clearFlight() end
        if id == "robloxAFK" then self.idleUnavailable = nil end
        if id == "climb" and not on then self.climbQueue = nil end
        self.features.nextReconcile = 0
        local s = bridge:snapshot(now,false)
        self.features:reconcile(s,now,true) -- both true AND false are reconciled
        self:ackLocal(s)
        self:save()
        return self.registry.byId[id].applied == (on == true)
    end
    function h:characterChanged(generation)
        local now = bridge.clock()
        self.recovery:release("animal changed",now)
        self.policy.manualRest,self.policy.manualIntentUntil = false,0
        self.grab:reset("animal changed")
        self:stopWalk("animal changed")
        self:clearFlight()
        self.features:releaseFlag()
        self.features.nextReconcile = 0
        self.climbQueue,self.guide,self.transactions,self.lastIntent = nil,nil,{},nil
        self.ledger.previous = nil
        self.anchor,self.anchorChar = nil,nil
        self.ledger:event("character_generation",now,{generation = generation})
        self.nextWalk = now+90
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
                    if node:IsA("TextButton") or node:IsA("TextLabel") then body ..= " " .. node.Text end
                    if string.find(string.lower(body),"rest",1,true) then return true end
                    node = node.Parent
                end
            end
        end
        return false
    end
    function h:preInput(input)
        if self.closed or not self.active or bridge.UserInputService:GetFocusedTextBox() then return end
        local now,key,kind = bridge.clock(),input.KeyCode,input.UserInputType
        local previous = self.earlyInputs[input]
        if previous and now-previous < .1 then return end
        self.earlyInputs[input] = now
        local click = kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2
        local point = bridge.UserInputService:GetMouseLocation()
        if click and self.ui:contains(point) then return end
        local s = bridge:snapshot(now,false)
        if s.gameMenu then return end
        if key == Enum.KeyCode.R or key == Enum.KeyCode.Z or key == Enum.KeyCode.X
            or (click and self:isRestControl(input)) then
            self.policy:input("rest",now)
            if self.recovery.owned then self.recovery:manual(now) end
            return
        end
        if self.grab.active and (click or key == Enum.KeyCode.Space or kind == Enum.UserInputType.Touch) then
            self.grab:manual()
            return
        end
        if click then
            local feedCan = bridge:attribute(s.char,"FeedCan")
            if feedCan == "eat" or feedCan == "drink" or feedCan == true then
                self.policy:input("action",now)
                self.recovery:release("manual feeding input",now)
                return
            end
            self.policy:input("attack",now)
            self.recovery:release("attack input",now)
            if kind == Enum.UserInputType.MouseButton1 then
                local tx = { intent = now, lock = self.policy:restLocked(now), generation = s.generation }
                self.lastIntent = tx
                table.insert(self.transactions,tx)
                if #self.transactions > 32 then table.remove(self.transactions,1) end
                self.ledger:event("attack_intent",now,{restLock = tx.lock})
            end
        elseif key == Enum.KeyCode.E or key == Enum.KeyCode.F or key == Enum.KeyCode.G
            or key == Enum.KeyCode.Q or key == Enum.KeyCode.Space then
            self.policy:input("action",now)
            self.recovery:release("manual native action",now)
        end
    end
    function h:input(input,processed)
        local kind,key = input.UserInputType,input.KeyCode
        if kind == Enum.UserInputType.MouseButton2 and bridge.clock() < (self.syntheticUntil or 0) then return end
        self:physicalInput("other")
        if bridge.UserInputService:GetFocusedTextBox() then return end
        self:preInput(input)
        if processed then return end
        if key == Enum.KeyCode.Q and self.registry.byId.climb.requested then
            local s = bridge:snapshot(bridge.clock(),false)
            local allowed = self.policy:allowed("climb",s,s.now)
            if allowed and not s.climbing and type(s.climber) == "number" and s.climber >= 1 then
                self.climbQueue = { generation = s.generation, expires = s.now+2.25,
                    earliest = s.now+.1, attempts = 0 }
            end
        end
    end
    function h:nativeAttribute(key)
        if self.closed or not self.active then return end
        local now = bridge.clock()
        local s = bridge:snapshot(now,false)
        if key == "WolfRest" then self.recovery:echo(s,now)
        elseif key == "WolfBiteAt" and Core.finite(bridge:attribute(s.char,key)) then
            self.policy.attackUntil = math.max(self.policy.attackUntil,now+1.1)
            self.recovery:release("native bite marker",now)
            local tx = self.lastIntent
            if not tx or tx.nativeAt or now-tx.intent > 1.3 then
                tx = { intent = now,generation = s.generation }
                table.insert(self.transactions,tx)
                if #self.transactions > 32 then table.remove(self.transactions,1) end
            end
            tx.nativeAt,tx.claimDue = now,now+.27
            self.ledger:event("native_bite_marker",now,{requestObserved = false,claimObserved = false})
        end
    end
    function h:nativeEvent(kind,event,data)
        if self.closed or not self.active then return end
        if kind == "feedback" then
            self.ledger:event("native_hit_feedback",bridge.clock(),{damageAcceptance = "unverified"})
            return
        end
        local now = bridge:serverNow()
        if not now then return end
        local c = bridge:config("GrabV2Config")
        local handled = self.grab:event(event,data,now,bridge.generation,c and c.PERFECT or .32,c and c.PASSES or 2.5)
        if handled then
            self.recovery:release("native minigame",bridge.clock())
            self:stopWalk("native minigame")
            self.ledger:event("native_grab_" .. tostring(event),bridge.clock(),
                {tier = event == "res" and data.mine == true and data.tier or nil})
        end
    end
    function h:requestFlight()
        local now = bridge.clock()
        if not self.active or self.closed or not self.registry.byId.flight.requested or now < (self.nextFlight or 0) then return false end
        local s = bridge:snapshot(now,true)
        s.grab = self.grab.active
        local c = bridge:config("FlightConfig")
        local ok,canFly = pcall(function() return c.canFly(s.char) end)
        if not ok or canFly ~= true or s.flying or not s.surface or s.underwater
            or not self.policy:allowed("flight",s,now) then return false end
        if type(c.WATER) ~= "table" or type(c.WATER.NO_TAKEOFF) ~= "boolean" then return false end
        self.recovery:release("surface takeoff input",now)
        local applied = self.features.leases:apply("surface",{
            {target = c.WATER,key = "NO_TAKEOFF",value = false,kind = "boolean"} })
        if not applied then return false end
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
        for _,id in ipairs({"combat","colours","finder","menu"}) do
            r:ack(id,true,id == "combat" and "ARMED" or "CLIENT",r.byId[id].detail)
        end
        for _,id in ipairs({"esp","tags","biteHelper"}) do
            local f = r.byId[id]
            r:ack(id,f.requested,f.requested and "CLIENT" or "OFF",f.detail)
        end
        for _,id in ipairs({"robloxAFK","survivalAFK","minigame","escape","flight"}) do
            local f = r.byId[id]
            if not f.requested then r:ack(id,false,"OFF",f.detail)
            elseif id == "minigame" then
                r:ack(id,bridge:hasRemote("FeralGrabV2"),"ARMED",self.grab.status)
            elseif id == "escape" then
                r:ack(id,bridge:hasRemote("FeralLunge"),"ARMED",self.escapeStatus or "watching native capture")
            elseif id == "flight" then
                local c = bridge:config("FlightConfig")
                local ok,eligible = pcall(function() return s.alive and c.canFly(s.char) end)
                r:ack(id,ok and eligible == true,ok and eligible and "ARMED" or "WAITING",
                    ok and eligible and (s.underwater and "underwater; takeoff blocked" or "surface assistance armed")
                        or "waiting for flight-eligible animal")
            elseif id == "survivalAFK" then
                r:ack(id,true,"ARMED",self.walk and "safe walk active; credit unverified" or self.walkStatus or "waiting for safe idle window")
            else r:ack(id,not self.idleUnavailable,self.idleUnavailable and "UNAVAILABLE" or "ARMED",
                self.idleUnavailable and "virtual input unavailable" or "best-effort idle input; retention unverified") end
        end
        if self.settingsAvailable then r:ack("settings",true,"CLIENT","saved intent reconciled; " .. self.settingsOrigin) end
        local recovery = r.byId.recovery
        if recovery.requested then
            recovery.reason = self.recovery.state .. " · gameplay unverified"
            recovery.observed = self.recovery.nativeEchoObserved and "owned native pose echo observed locally" or "unknown"
        end
        r.byId.minigame.observed = {
            perfect = self.grab.grades.perfect,good = self.grab.grades.good,miss = self.grab.grades.miss,
            source = "matching native res replies only",
        }
        r.byId.flight.observed = s.flying and "native local flight flag" or "unknown"
        r.byId.climb.observed = s.climbing and "native local climb flag" or "unknown"
        r.byId.survivalAFK.observed = (self.ledger.counts.survival_value_advanced or 0) > 0
            and "survival value advanced; cause unverified" or "unknown"
    end
    function h:stepCombat(s,now)
        for _,tx in ipairs(self.transactions) do
            if not tx.classified and tx.generation == s.generation then
                if not tx.nativeAt and now-tx.intent > .45 then
                    tx.classified = true
                    self.combatStatus = tx.lock and "No native bite marker · recent Rest lock possible" or "No native bite marker observed"
                    self.ledger:event("no_native_bite_marker",now,{recentRest = tx.lock == true})
                elseif tx.nativeAt and not tx.sampled and now >= tx.claimDue then
                    tx.sampled = true
                    local target = self.guide and self.guide.target
                    if target then
                        tx.target,tx.hp,tx.maxHP = target,target.hum.Health,target.hum.MaxHealth
                        tx.extendedOnly = self.guide.extended and self.guide.extended.valid
                            and not (self.guide.baseline and self.guide.baseline.valid)
                    end
                    self.ledger:event("client_candidate_sample",now,{found = target ~= nil,claimObserved = false})
                elseif tx.nativeAt and tx.sampled and now >= tx.claimDue+.8 then
                    tx.classified = true
                    local target = tx.target
                    local drop = target and target.hum.Parent and target.hum.MaxHealth == tx.maxHP and target.hum.Health < tx.hp-.05
                    self.combatStatus = drop and "Target HP fell after native marker · attribution unverified"
                        or "Native marker observed · no matching HP decline observed"
                    self.ledger:event(drop and "target_hp_decline_correlated" or "no_correlated_hp_decline",now,
                        {extendedOnly = tx.extendedOnly == true,damageAcceptance = "unverified"})
                end
            end
        end
    end
    function h:stepClimb(s,now)
        local q = self.climbQueue
        if not q then return end
        if not self.registry.byId.climb.requested or q.generation ~= s.generation or now > q.expires then self.climbQueue = nil; return end
        if s.climbing then
            self.ledger:event("native_climb_mounted",now,{afterRequest = q.attempts > 0})
            self.climbQueue = nil; return
        end
        if not self.policy:allowed("climb",s,now) then self.climbQueue = nil; return end
        if now < q.earliest or not s.climbCan then return end
        if q.attempts >= 2 then self.climbQueue = nil; return end
        self.recovery:release("buffered climb",now)
        if bridge:setAttribute(bridge.player,"FeralClimbTap",now) then
            q.attempts += 1; q.earliest = now+.7
            self.ledger:event("native_climb_tap",now,{attempt = q.attempts})
        else self.climbQueue = nil end
    end
    function h:stepAFK(s,now)
        if self.registry.byId.robloxAFK.requested and now >= self.nextIdle and now-self.policy.lastPhysical >= 65 then self:idle() end
        if not self.registry.byId.survivalAFK.requested then self:stopWalk("disabled"); return end
        if self.walk then
            s.nearbyDanger = bridge:nearbyDanger(s)
            local allowed,why = self.policy:allowed("afk",s,now)
            if not allowed or now >= self.walk.untilAt or self.walk.snapshot.char ~= s.char then self:stopWalk(why or "walk timeout"); return end
            if (s.root.Position-self.walk.goal).Magnitude < 1.3 then
                self.ledger:event("afk_displacement_observed",now)
                self:stopWalk("goal reached")
            end
            return
        end
        if now < self.nextWalk then return end
        self.nextWalk = now+90
        s.nearbyDanger = bridge:nearbyDanger(s)
        local allowed,why = self.policy:allowed("afk",s,now)
        self.walkStatus = why
        if not allowed then return end
        local goal = bridge:safeStep(s,self.anchorChar == s.char and self.anchor or nil)
        if not goal then self.walkStatus = "no safe ground step"; return end
        self.recovery:release("safe idle walk",now)
        if bridge:walk(s,goal) then
            if self.anchorChar ~= s.char then self.anchor,self.anchorChar = s.root.Position,s.char end
            self.walk = { snapshot = s,goal = goal,untilAt = now+8 }
            self.ledger:event("afk_walk_requested",now)
        end
    end
    function h:stepFlight(s,now)
        if self.surfaceUntil and (now >= self.surfaceUntil or s.underwater or s.flying
            or s.captured or s.grab or s.chat or s.gameMenu or s.attackHeld) then
            self.features.leases:release("surface")
            self.surfaceUntil = nil
        end
        if self.drop then
            if not s.flying then self.ledger:event("underwater_flight_exit_observed",now) end
            if not s.flying or self.drop.char ~= s.char or now >= self.drop.untilAt then self:clearFlight() end
        elseif self.registry.byId.flight.requested and s.flying and s.underwater and not s.grab then
            local before = bridge:attribute(s.char,"FeralFlyDrop")
            if bridge:setAttribute(s.char,"FeralFlyDrop",true) then
                self.drop = {char = s.char,before = before,untilAt = now+2}
                self.ledger:event("native_underwater_flight_exit_requested",now)
            end
        end
    end
    function h:stepEscape(s,now)
        if not self.registry.byId.escape.requested or now < self.nextEscape then return end
        self.nextEscape = now+.12
        local allowed = self.policy:allowed("escape",s,now)
        if not allowed then return end
        local action,why,interval = bridge:escapeAction(s)
        self.escapeStatus = why
        if action then
            self.nextEscape = now+interval
            local sent = bridge:fire("FeralLunge",action)
            self.ledger:event("native_escape_requested",now,{action = action,sent = sent})
        end
    end
    function h:tick()
        if not self.active or self.closed then return end
        local now = bridge.clock()
        local slow = now >= self.nextSlow
        local s = bridge:snapshot(now,slow and self.registry.byId.flight.requested)
        self.snapshot = s
        s.grab,s.afkWalking = self.grab.active,self.walk ~= nil
        self.grab.enabled = self.registry.byId.minigame.requested
        local clock = s.serverNow
        if clock then
            self.grab:tick(clock,s.generation,s.alive and self.policy:allowed("grab",s,now),
                function(session,strike,at) return bridge:fire("FeralGrabV2","press",session,strike,at) end)
        else self.grab.pending = nil end
        if now >= self.nextBind then self.nextBind = now+1; bridge:bindNative(self) end
        self.features:reconcile(s,now)
        self.recovery.enabled = self.registry.byId.recovery.requested
        self.recovery:tick(s,now)
        self:stepClimb(s,now)
        self:stepEscape(s,now)
        self:stepCombat(s,now)
        if now >= self.nextScan then
            self.nextScan = now+.12
            local candidates = bridge:candidates(s,self.settings.range)
            if self.features.originalCombat and self.features.leases:valid("reach") then
                self.guide = bridge:select(s,self.features.originalCombat,self.features.combat,candidates)
            else self.guide = nil end
            self.ui:syncTracked(bridge.tracked)
        end
        if slow then
            self.nextSlow = now+.25
            self:stepFlight(s,now)
            self:stepAFK(s,now)
            self:ackLocal(s)
        end
        if now >= self.nextSample and s.alive then
            self.nextSample = now+.25
            local mode = self.policy.manualRest and "MANUAL" or self.recovery.owned and "NATIVE_SIGNAL" or "NO_SIGNAL"
            self.ledger:sample(s,mode)
            if Core.finite(s.survival) and Core.finite(self.lastSurvival) and s.survival > self.lastSurvival then
                self.ledger:event("survival_value_advanced",now,{cause = "unverified"})
            end
            self.lastSurvival = s.survival
        end
    end
    function h:maskPose()
        if self.recovery.owned then
            local char = bridge.player.Character
            self.recovery:echo({char = char,rest = bridge:attribute(char,"WolfRest") == true},bridge.clock())
        end
    end
    function h:render(dt)
        self:maskPose()
        self.ui:render(dt,bridge.clock())
    end
    function h:fault(errorValue)
        self.notice = "Controller paused · reload or use CLEAN v14"
        self.lastError = tostring(errorValue):sub(1,180)
        self.ledger:event("runtime_fault",bridge.clock())
        self:close()
        warn("[FERAL Renaissance] " .. self.lastError)
    end
    function h:stage()
        self.ui = M.ui.mount(self,bridge,self.scope)
        bridge:attach(self,self.scope)
        bridge:bindNative(self)
        bridge.bindCharacter(bridge.player.Character)
        self.ready = true
        return self
    end
    function h:activate()
        assert(self.ready and not self.closed,"candidate not staged")
        self.ui:activate()
        self.active = true
        self.registry:ack("settings",true,"CLIENT","loaded settings; full reconciliation pending")
        return self
    end
    function h:close()
        if self.closed then return end
        self.active = false
        self.closed = true
        self.cleanupErrors = {}
        for _,cleanup in ipairs({
            function() self.recovery:close(bridge.clock()) end,
            function() self:stopWalk("shutdown") end,
            function() self:clearFlight() end,
            function() self.features:close() end,
        }) do
            local ok,why = pcall(cleanup)
            if not ok then table.insert(self.cleanupErrors,tostring(why)) end
        end
        self.scope:close()
        if bridge.env.FERAL_RENAISSANCE_ACTIVE == self then bridge.env.FERAL_RENAISSANCE_ACTIVE = nil end
        if bridge.env.FERAL_NOVA_PRIME_ACTIVE == self.marker then bridge.env.FERAL_NOVA_PRIME_ACTIVE = nil end
    end
    return h
end
return Controller
