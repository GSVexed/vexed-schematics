local Controller = {}
-- Replies have no recovered transaction identifier. Prefer a matching native
-- target and timing, and retain ambiguity instead of assigning the newest bite.
function Controller.matchFeedback(Core,transactions,data,now)
    if type(data)~="table" or data.v==nil then return nil,false end
    local best,bestRank,bestTime,secondTime=nil,math.huge,math.huge,math.huge
    for _,tx in ipairs(transactions) do
        local corrected=tx.feedback and not tx.feedback.safe and tx.feedback.v==data.v
            and Core.finite(tx.feedback.dmg) and tx.feedback.dmg==0 and Core.finite(data.dmg) and data.dmg>0
        if tx.nativeAt and not tx.classified and (not tx.feedback or corrected) and now>=tx.nativeAt and now-tx.nativeAt<1.8 then
            local target=tx.nativeTarget or tx.target and tx.target.char
            local rank=target==data.v and 0 or target==nil and tx.hpBefore and tx.hpBefore[data.v] and 1 or nil
            if rank then
                local delta=math.abs(now-(tx.claimDue or tx.nativeAt))
                if rank<bestRank then
                    best,bestRank,bestTime,secondTime=tx,rank,delta,math.huge
                elseif rank==bestRank then
                    if delta<bestTime then best,secondTime,bestTime=tx,bestTime,delta
                    elseif delta<secondTime then secondTime=delta end
                end
            end
        end
    end
    local ambiguous=best~=nil and secondTime-bestTime<=.040001
    return not ambiguous and best or nil,ambiguous
end
function Controller.new(M,bridge,options)
    local Core = M.core
    local tokenIdentity = {}
    local h = { version = "15.8.5", tokenIdentity = tokenIdentity,
        token = (tostring(tokenIdentity):gsub("[^%w]","")) .. "_" .. tostring(math.floor(bridge.clock()*1000000)),
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
    h.grabInput = M.grab_input.new(bridge,h.token)
    h.recovery = M.recovery.new(bridge,h.policy,h.ledger)
    h.feeding = M.feeding.new(bridge,h.policy,h.ledger)
    h.combatInput = M.combat_input.new(bridge,h.policy,h.ledger)
    bridge.combatGovernor = h.combatInput
    h.rescue = M.rescue.new(bridge,h.ledger)
    h.hippo = M.hippo.new(Core,bridge,h.ledger)
    h.tests = M.test_features.new(Core,bridge,h)
    h.zoom = M.zoom.new(bridge.player)
    h.voice = M.voice.new(bridge.Players,bridge.player)
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
        self:releaseFlightRepair()
        self.flightEpisode,self.flightStatus=nil,nil
        self.features.leases:release("surface")
        self.surfaceUntil = nil
        if self.drop then
            bridge:restoreAttribute(self.drop.char,"FeralFlyDrop",true,self.drop.before)
            self.drop = nil
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
        if not self.registry.byId.flight.requested or self.grab.active
            or bridge:attribute(s.char,"Species")~="Vulture" or s.talonLock==nil then return end
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
                return
            end
        end
    end
    function h:stepFlightHandoff(s,now)
        if self.flightRepair then
            local r=self.flightRepair
            if not s.alive or r.char~=s.char or s.grab or s.captured or s.ability or s.chat or s.gameMenu
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
        self.flightRepair={char=s.char,at=now,position=s.root.Position}
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
        if id=="autoBite" and not on then self.combatInput:cancel() end
        if id=="holdBite" and not on then self.combatInput.held=nil end
        if id=="attackSpeed" then bridge.biteTiming=nil;self.combatInput.nextAttempt=0;self.combatInput:resetRate() end
        if id=="voice" then self.voice:setEnabled(on) end
        self.features.nextReconcile = 0
        local s = bridge:snapshot(now,false)
        self.features:reconcile(s,now,true) -- both true AND false are reconciled
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
        bridge.biteTiming,bridge.deferNativeDiscovery=nil,false
        self.policy.manualRest,self.policy.manualIntentUntil = false,0
        self.nativeGrabBusy,self.nativeGrabSession,self.nativeGrabUntil=false,nil,nil
        self.grab:reset("animal changed")
        self:cancelGrabWake()
        self.grabInput:release()
        self.feeding:close(now)
        self.combatInput:cancel()
        self.combatInput:resetRate()
        self.hippo:reset()
        self.rescue:cancel("animal changed")
        self:stopWalk("animal changed")
        self:clearFlight()
        self.features:releaseFlag()
        self.features.nextReconcile = 0
        self.climbQueue,self.guide,self.transactions,self.lastIntent = nil,nil,{},nil
        self.ledger.previous = nil
        self.ledger.staminaObservation=nil
        self.anchor,self.anchorChar = nil,nil
        self.ledger:event("character_generation",now,{generation = generation})
        self.tests:characterChanged(bridge.character)
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
        local s=bridge:snapshot(now,true);s.grab=self.grab.active
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
        if kind==Enum.UserInputType.MouseButton1
            and (bridge.syntheticPressing or now<(bridge.syntheticM1Until or 0)
                and bridge.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then return end
        local previous = self.earlyInputs[input]
        if previous and now-previous < .1 then return end
        self.earlyInputs[input] = now
        local click = kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2
        local primary = kind == Enum.UserInputType.MouseButton1
        local point = bridge.UserInputService:GetMouseLocation()
        if click and self.ui:contains(point) then return end
        local s = bridge:snapshot(now,false)
        if s.gameMenu then return end
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
        if key==Enum.KeyCode.Space or key==Enum.KeyCode.ButtonB then self:noteFlightCancel(input,s,now) end
        if key == Enum.KeyCode.E or (primary or kind == Enum.UserInputType.Touch) and self:isFeedControl(input) then
            self.feeding:input(s,now)
            self.policy:input("action",now)
            self.recovery:release("manual feeding input",now)
            self.combatInput:cancel();self.rescue:cancel()
            return
        end
        if primary or key == Enum.KeyCode.ButtonR2 then
            self.policy:input("attack",now)
            self.recovery:release("attack input",now)
            if primary or key == Enum.KeyCode.ButtonR2 then
                self.feeding:attack(s,now);self.rescue:cancel()
                local tx = { intent = now, lock = self.policy:restLocked(now), generation = s.generation }
                self.lastIntent = tx
                table.insert(self.transactions,tx)
                if #self.transactions > 32 then table.remove(self.transactions,1) end
                self.ledger:event("attack_intent",now,{restLock = tx.lock})
                self.combatInput:input(s,now,primary and "M1" or "R2")
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
    function h:input(input,processed)
        local kind,key = input.UserInputType,input.KeyCode
        if kind==Enum.UserInputType.MouseButton1 and bridge.syntheticPressing then return end
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
    function h:inputEnded(input)
        if self.closed or not self.active then return end
        local kind,key=input.UserInputType,input.KeyCode
        if kind==Enum.UserInputType.MouseButton1 then
            if bridge.syntheticReleasing then return end
            -- The virtual release callback is owned by the hub; a real
            -- physical InputEnded must never be swallowed simply because
            -- it happened within the last synthetic-click time window.
            if bridge.clock()<(bridge.syntheticM1Until or 0) then
                local ok,stillDown=pcall(bridge.UserInputService.IsMouseButtonPressed,
                    bridge.UserInputService,Enum.UserInputType.MouseButton1)
                if ok and stillDown==true then return end
            end
            self.combatInput:release("M1",bridge.clock())
        elseif key==Enum.KeyCode.ButtonR2 then
            self.combatInput:release("R2",bridge.clock())
        end
    end
    function h:nativeAttribute(key)
        if self.closed or not self.active then return end
        local now = bridge.clock()
        local s = bridge:snapshot(now,false)
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
            -- Only confirmed *stock*-range contacts can train attack cadence.
            -- Extended-only reach, predictive FX, and a bare bite sound are
            -- never treated as server proof.
            local guide=self.guide
            local focus=guide and guide.target
            local valid=guide and guide.baseline and guide.baseline.valid
                and now-(self.guideAt or -math.huge)<.28
            local clear=valid and focus and focus.root and focus.root.Parent
                and bridge:combatEligible(focus.char) and not bridge:occluded(s,focus)
            tx.rateTarget=clear and focus or nil
            tx.rateEligible=tx.rateTarget~=nil and self.registry.byId.attackSpeed.requested
                and (self.combatInput.held~=nil or self.registry.byId.autoBite.requested)
            tx.hpBefore={}
            for _,target in ipairs(bridge.allCandidates or {}) do
                if target.root.Parent and (target.root.Position-s.root.Position).Magnitude<=45 then
                    tx.hpBefore[target.char]={hp=target.hum.Health,maxHP=target.hum.MaxHealth}
                end
            end
            self.ledger:event("native_bite_marker",now,{requestObserved = false,claimObserved = false})
        else
            -- Native actions can begin between heartbeats. Release competing
            -- automation on the actual state change, preserving manual input.
            s.grab,s.rescuing = self.grab.active,self.rescue.pending~=nil
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
                    tx.feedback=data;tx.nativeTarget=data.v
                    if tx.rateEligible and tx.rateTarget and tx.rateTarget.char==data.v
                        and data.safe~=true and Core.finite(data.dmg) and data.dmg>0
                        and not tx.fastConfirmed then
                        tx.fastConfirmed=true
                        self.combatInput:confirmed(now)
                    end
                end
                self.ledger:event("native_outgoing_hit_reply",now,{safe=data.safe==true,damage=data.dmg,
                    matched=tx~=nil,ambiguous=ambiguous==true})
            end
            return
        end
        if kind=="actions" then
            if event=="FeedStop" then self.feeding:stopped(data,bridge.clock()) end
            return
        end
        if kind=="biteLocal" then
            -- A client-side FX signal can arrive late or refer to a different
            -- attack when bites are rapid. It is not an authoritative target
            -- identity and must never remap a more recent hit transaction.
            self.ledger:event("client_bite_fx_only",bridge.clock(),{claimObserved=false})
            return
        end
        local now = bridge:serverNow()
        if kind=="grab" then
            local session=type(data)=="table" and data.f
            if event=="begin" then
                self.nativeGrabSession=session
                self.nativeGrabBusy=true
                self.nativeGrabUntil=bridge.clock()+35
                -- Release any partially held synthetic M1 before the grab
                -- minigame can interpret that input as an unwanted press.
                bridge:releaseSyntheticBite()
                self.combatInput.awaiting=nil
            elseif event=="end" and (self.nativeGrabSession==nil or session==self.nativeGrabSession) then
                self.nativeGrabBusy,self.nativeGrabSession=false,nil
            end
        end
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
        if not now or p.at<=now then return end
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
            local state,known=native.state()
            local cfg=bridge:config("GrabV2Config")
            if state or known==true then
                self.grab:syncNative(state,clock,s.generation,cfg and cfg.PERFECT or .32,cfg and cfg.PASSES or 2.5,now)
            end
        end
        local p=self.grab.pending
        if not p then return end
        if self.lastGrabClock==clock and self.lastGrabPending==p then return end
        self.lastGrabClock,self.lastGrabPending=clock,p
        s.grab=true
        self.grab:tick(clock,s.generation,self.policy:allowed("grab",s,now),function(session,strike)
            -- Native-issued IDs and the actual current server clock only.
            -- Recheck after inspection; never backdate or anticipate a press.
            local at=bridge:serverNow()
            if not at or at<p.t0 or at>=p.ends-.002
                or math.abs(M.grab.triangle(at,p.t0,p.speed,p.from)-p.target)>p.half*.98 then return false end
            local sent=bridge:fire("FeralGrabV2","press",session,strike,at)
            if sent then bridge:markGrabPress(session,strike,now) end
            return sent
        end)
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
        local heldFallback=not native and game.PlaceVersion==2412 and bridge:hasHeldInputBackend()
        local hold=r.byId.holdBite
        r:ack("holdBite",hold.requested and (native or heldFallback),
            not hold.requested and "OFF" or (native or heldFallback) and "ARMED" or "WAITING",
            hold.requested and (native and "Native callback · " or heldFallback and "Physical input replay · " or "No input backend · ")
                ..self.combatInput.status or hold.detail)
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
                local c = bridge:config("FlightConfig")
                local ok,eligible = pcall(function() return s.alive and c.canFly(s.char) end)
                r:ack(id,ok and eligible == true,ok and eligible and "ARMED" or "WAITING",
                    ok and eligible and (self.flightStatus or (s.underwater and "underwater; takeoff blocked" or "surface assistance armed"))
                        or "waiting for flight-eligible animal")
            elseif id == "survivalAFK" then
                r:ack(id,true,"ARMED",self.walk and "safe walk active; credit unverified" or self.walkStatus or "waiting for safe idle window")
            else r:ack(id,not self.idleUnavailable,self.idleUnavailable and "UNAVAILABLE" or "ARMED",
                self.idleUnavailable and "virtual input unavailable" or "best-effort idle input; retention unverified") end
        end
        local speed=r.byId.attackSpeed
        if speed.requested and speed.applied then
            speed.reason=string.format("Adaptive %.2fx client rate · server hit acceptance not guaranteed",
                1/self.combatInput:factor())
        end
        if self.settingsAvailable then r:ack("settings",true,"CLIENT","saved intent reconciled; " .. self.settingsOrigin) end
        local recovery = r.byId.recovery
        if recovery.requested then
            recovery.reason = self.recovery:summary()
            recovery.observed = self.recovery.nativeEchoObserved and "owned native pose echo observed locally" or "unknown"
            r.byId.effects.reason = self.recovery:effectsSummary()
            r.byId.effects.observed = self.recovery.observations
        end
        r.byId.minigame.observed = {
            perfect = self.grab.grades.perfect,good = self.grab.grades.good,miss = self.grab.grades.miss,
            source = "matching native res replies only",
        }
        if r.byId.minigame.requested and self.grab.active then
            r.byId.minigame.reason=string.format("P %d · G %d · M %d · %d presses · native grades only",
                self.grab.grades.perfect,self.grab.grades.good,self.grab.grades.miss,self.grab.presses)
        end
        if r.byId.stamina.requested and r.byId.stamina.applied then
            local item=self.ledger.staminaObservation
            r.byId.stamina.reason=(s.locomotion or "Animal").." client profile"
                ..(item and item.seconds>=1 and string.format(" · observed %+.2f/s",item.rate) or " · watching stamina")
            r.byId.stamina.observed=item or "unmeasured"
        end
        r.byId.flight.observed = s.flying and "native local flight flag" or "unknown"
        r.byId.climb.observed = s.climbing and "native local climb flag" or "unknown"
        r.byId.survivalAFK.observed = (self.ledger.counts.survival_value_advanced or 0) > 0
            and "survival value advanced; cause unverified" or "unknown"
    end
    function h:stepCombat(s,now)
        for _,tx in ipairs(self.transactions) do
            if not tx.classified and tx.generation == s.generation then
                if not tx.nativeAt and now-tx.intent > .45 and not self.combatInput.pending then
                    tx.classified = true
                    self.combatStatus = tx.lock and "No native bite marker · recent Rest lock possible" or "No native bite marker observed"
                    self.ledger:event("no_native_bite_marker",now,{recentRest = tx.lock == true})
                elseif tx.nativeAt and not tx.sampled and now >= tx.claimDue then
                    tx.sampled = true
                    if tx.rateEligible and tx.rateTarget and self.features.originalCombat
                        and tx.rateTarget.root and tx.rateTarget.root.Parent then
                        local geo=bridge:geometry(self.features.originalCombat,s,tx.rateTarget)
                        tx.rateAtClaim=geo and geo.valid and not bridge:occluded(s,tx.rateTarget) or false
                    end
                    local target = self.guide and self.guide.target
                    if target then
                        local before=tx.hpBefore and tx.hpBefore[target.char]
                        tx.target,tx.hp,tx.maxHP = target,before and before.hp,before and before.maxHP
                        tx.extendedOnly = self.guide.extended and self.guide.extended.valid
                            and not (self.guide.baseline and self.guide.baseline.valid)
                    end
                    self.ledger:event("client_candidate_sample",now,{found = target ~= nil,claimObserved = false})
                elseif tx.nativeAt and tx.sampled and now >= tx.claimDue+.8 then
                    tx.classified = true
                    local target = tx.target
                    local char=tx.nativeTarget or target and target.char
                    local ok,hum=pcall(function()return char and char:FindFirstChildOfClass("Humanoid")end)
                    local before=char and tx.hpBefore and tx.hpBefore[char]
                    local drop=ok and hum and hum.Parent and before and hum.MaxHealth==before.maxHP and hum.Health<before.hp-.05
                    local damage=tx.feedback and tx.feedback.dmg
                    if tx.rateEligible and tx.rateAtClaim and not tx.fastConfirmed
                        and not drop and not (tx.feedback and tx.feedback.safe==true)
                        and (not tx.feedback or tx.rateTarget and tx.feedback.v==tx.rateTarget.char) then
                        self.combatInput:suspect(now)
                    end
                    self.combatStatus = tx.feedback and tx.feedback.safe==true and "Game reply: target protected"
                        or Core.finite(damage) and damage>0 and (string.format("Game reply reports %.1f damage",damage)
                            ..(drop and " · HP decline correlated" or " · HP change unconfirmed"))
                        or drop and tx.feedback and "Native hit reply + target HP decline · attribution unverified"
                        or drop and "Target HP fell after native marker · attribution unverified"
                        or "Native marker observed · no matching HP decline observed"
                    self.ledger:event(drop and "target_hp_decline_correlated" or "no_correlated_hp_decline",now,
                        {extendedOnly = tx.extendedOnly == true,nativeReply=tx.feedback~=nil,damageAcceptance = "unverified"})
                    tx.hpBefore=nil
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
            elseif not bridge:routeSafe(s,self.walk.goal) then
                self:stopWalk("ground route changed")
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
        elseif self.registry.byId.flight.requested and s.flying and s.underwater and not s.grab and not s.ability and not s.captured then
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
    function h:tick(dt)
        if not self.active or self.closed then return end
        local now = bridge.clock()
        if self.territory then self.territory:tick(now) end
        if Core.finite(dt) and dt>0 then
            self.frameInterval=(self.frameInterval or dt)*.85+math.min(dt,.25)*.15
        end
        local slow = now >= self.nextSlow
        local critical=self.registry.byId.minigame.requested and self.grab.active and self.grab.pending~=nil
        self.timingCritical,bridge.deferNativeDiscovery=critical,critical
        local s = bridge:snapshot(now,not critical and slow and self.registry.byId.flight.requested)
        self.snapshot = s
        self.grab.enabled = self.registry.byId.minigame.requested
        local clock = s.serverNow
        if clock then
            local cfg = self.grab.enabled and bridge:config("GrabV2Config")
            local native = self.grab.enabled and self.grabInput:controller(now)
            local nativeState,nativeKnown
            if native and (self.grab.active or now >= (self.nextGrabPoll or 0)) then
                nativeState,nativeKnown=native.state();self.nextGrabPoll=now+.25
            end
            if native and s.alive and (nativeState or nativeKnown==true) then
                self.grab:syncNative(nativeState,clock,s.generation,cfg and cfg.PERFECT or .32,
                    cfg and cfg.PASSES or 2.5,now)
            end
            critical=critical or self.grab.enabled and self.grab.active and self.grab.pending~=nil
            self.timingCritical,bridge.deferNativeDiscovery=critical,critical
            if not s.alive and self.grab.active then self.grab:reset("animal unavailable") end
            s.grab,s.afkWalking = self.grab.active,self.walk ~= nil
            self.grabInput:update(self.grab,now,native,nativeState)
            self:pumpGrab(s,false)
            self:updateGrabWake()
        else self.grab.pending = nil; s.grab,s.afkWalking = self.grab.active,self.walk ~= nil end
        if self.nativeGrabBusy and now>=(self.nativeGrabUntil or 0) then
            self.nativeGrabBusy,self.nativeGrabSession=false,nil
        end
        s.grab=s.grab or self.nativeGrabBusy==true
        if not critical and now >= self.nextBind then self.nextBind = now+1; bridge:bindNative(self) end
        local care=self.territory and self.territory.agent.enabled and self.territory.agent.goal
        self.feeding:tick(s,now,care and (care.kind=="EAT" or care.kind=="DRINK"))
        self:stepFlightHandoff(s,now)
        self.rescue:tick(s,now)
        self.activity=self.policy:activity(s,now)
        bridge.predictionActive=s.attackHeld or self.registry.byId.autoBite.requested
        local auto=self.registry.byId.autoBite.requested and not (self.territory and self.territory.agent.enabled)
        local clear=auto and bridge:autoAttackTarget(s,self.guide,self.features.combat)
        self.combatInput:tick(s,now,{
            repeatHeld=self.registry.byId.holdBite.requested,automatic=auto,targetValid=clear,
            minigameBusy=self.nativeGrabBusy==true or self.grab.active or self.grabInput.lease~=nil,
            uiBlocked=self.ui:contains(bridge.UserInputService:GetMouseLocation()),
            beforeAttempt=function()
                self.policy:input("attack",now)
                self.recovery:release("native cadence input",now)
                self.rescue:cancel();self:stopWalk("native cadence input")
            end,
        })
        if not critical then self.features:reconcile(s,now) end
        self.recovery.enabled = self.registry.byId.recovery.requested or self.territoryRecoveryOwner~=nil
        self.recovery:tick(s,now)
        self:stepClimb(s,now)
        self:stepEscape(s,now)
        if not critical then self:stepCombat(s,now) end
        self.biteReadiness=bridge:biteReadiness(s,now,self.policy)
        if not critical and now >= self.nextScan then
            self.nextScan = now+((s.combat==true or s.attackHeld) and .12
                or math.clamp((self.frameInterval or .02)*6,.12,.3))
            local candidates = bridge:candidates(s,self.settings.range)
            if self.features.originalCombat and self.features.leases:valid("reach") then
                self.guide = bridge:select(s,self.features.originalCombat,self.features.combat,candidates)
            else self.guide = nil end
            self.guideAt=now
            self.ui:syncTracked(bridge.tracked)
        end
        self.hippo:tick(s,now,self.registry.byId.hippoRelease.requested,self.guide,self.features.originalCombat)
        if slow and not critical then
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
        self.tests:tick(now,critical)
    end
    function h:maskPose()
        local now = bridge.clock()
        self.recovery:guardPose(now)
        if self.recovery.owned then
            local char = bridge.player.Character
            self.recovery:echo({char = char,rest = bridge:attribute(char,"WolfRest") == true},now)
        end
    end
    function h:render(dt)
        if self.grab.enabled and self.grab.pending then
            self:pumpGrab(bridge:grabSnapshot(bridge.clock()),true)
            self:updateGrabWake()
        end
        self:maskPose()
        if self.guide and self.snapshot and self.features.leases:valid("reach") then
            bridge:refreshGuide(self.snapshot,self.features.originalCombat,self.features.combat,self.guide)
        end
        self.features:paintHippoGait()
        self.ui:render(dt,bridge.clock())
        self.recovery:afterAnimationFrame(bridge.clock())
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
        if self.registry.byId.minigame.requested then bridge:nativeGrabController(bridge.clock()) end
        bridge:nativeWolfActions(bridge.clock())
        self.ready = true
        return self
    end
    function h:activate()
        assert(self.ready and not self.closed,"candidate not staged")
        self.ui:activate()
        self.active = true
        self.zoom:set(self.registry.byId.zoom.requested)
        -- The earlier stand-alone trial must not apply a second attenuation scale.
        -- Automatically retire it before the integrated owner starts.
        local olderVoice=bridge.env.FERAL_VOICE_HEARING
        if type(olderVoice)=="table" and type(olderVoice.close)=="function" then
            pcall(olderVoice.close,olderVoice)
        end
        self.voice:setEnabled(self.registry.byId.voice.requested)
        if M.amber_runtime then self.territory=M.amber_runtime.start(M,self) end
        self.tests:start()
        self.registry:ack("settings",true,"CLIENT","loaded settings; full reconciliation pending")
        return self
    end
    function h:close()
        if self.closed then return end
        self.active = false
        self.closed = true
        self.cleanupErrors = {}
        for _,cleanup in ipairs({
            function() if self.territory then self.territory.close() end end,
            function() self.zoom:close() end,
            function() self.voice:close() end,
            function() self:cancelGrabWake() end,
            function() self.recovery:close(bridge.clock()) end,
            function() self.grabInput:close() end,
            function() self.feeding:close(bridge.clock()) end,
            function() self.combatInput:cancel();self.rescue:cancel() end,
            function() self.hippo:close();bridge.predictionActive=nil end,
            function() self.tests:close() end,
            function() bridge:closeNativeScan() end,
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
