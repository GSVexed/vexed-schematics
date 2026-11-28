ock())
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
    function h:ackEndurance(s)
        local r = self.registry
        local endurance=r.byId.enduranceMove
        local active=endurance.requested
            and (self.endurance.owned~=nil or self.endurance.directionRequested==true)
        local state=not endurance.requested and "OFF" or game.PlaceVersion~=2415 and "UNAVAILABLE"
            or (not s or not s.alive) and "WAITING"
            or bridge.clock()<self.endurance.suspendedUntil and "PAUSED"
            or active and "PARTIAL" or self.endurance.baseline and "ARMED" or "WAITING"
        r:ack("enduranceMove",active,state,
            endurance.requested and self.endurance.status or endurance.detail,
            {localSpeed=self.endurance.observedSpeed,peerVerified=false,corrections=self.endurance.corrections,
                nativeOverwrites=self.endurance.nativeOverwrites,
                directionRequested=self.endurance.directionRequested==true})
    end
    function h:ackLocal(s)
        local r = self.registry
        self:ackEndurance(s)
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
            speed.reason=string.format("Adaptive %.2fx repeat request pacing · native/server limits still apply",
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
                ..(s.serverTired and " · server fatigue reported" or not bridge:capability("debugStamina")
                    and " · server fatigue and ability costs remain native" or "")
            r.byId.stamina.observed=item or "unmeasured"
        end
        r.byId.flight.observed = s.flying and "native local flight flag" or "unknown"
        r.byId.climb.observed = s.climbing and "native local climb flag" or "unknown"
        r.byId.survivalAFK.observed = (self.ledger.counts.survival_value_advanced or 0) > 0
            and "survival value advanced; cause unverified" or "unknown"
    end
    function h:correlatedHPDrop(tx)
        local victim=tx.nativeTarget or tx.target and tx.target.char
        local before=victim and tx.hpBefore and tx.hpBefore[victim]
        if not before then return false end
        local ok,hum=pcall(function()return victim:FindFirstChildOfClass("Humanoid")end)
        return ok and hum and hum.Parent and hum.MaxHealth==before.maxHP
            and hum.Health<before.hp-.05 or false
    end
    function h:stepCombat(s,now)
        for _,tx in ipairs(self.transactions) do
            if tx.generation == s.generation and not tx.closed then
                if not tx.nativeAt and now-tx.intent > .45 and not self.combatInput.pending then
                    if not tx.classified then
                        tx.classified = true
                        local status = tx.consumed and "Input handled by native UI or another binding"
                            or tx.restExitFailed and "Native Rest exit failed; normal input preserved"
                            or tx.lock and "No native bite marker · recent Rest lock possible" or "No native bite marker observed"
                        if not self.combatStatusAt or tx.intent>=self.combatStatusAt then
                            self.combatStatus,self.combatStatusAt=status,tx.intent
                        end
                        self.ledger:event("no_native_bite_marker",now,{recentRest = tx.lock == true,consumed=tx.consumed==true})
                    end
                elseif tx.nativeAt and now>=tx.claimDue then
                    if not tx.sampled then
                        tx.sampled = true
                        local target = tx.focusTarget
                        if tx.rateEligible and tx.rateTarget and self.features.originalCombat
                            and bridge:currentTargetBody(tx.rateTarget) then
                            local geometryOK,geo=pcall(bridge.geometry,bridge,self.features.originalCombat,s,tx.rateTarget)
                            local rayOK,blocked=pcall(bridge.occluded,bridge,s,tx.rateTarget)
                            tx.rateAtClaim=geometryOK and geo and geo.valid and rayOK and blocked==false or false
                        end
                        if target and bridge:currentTargetBody(target) then
                            local before=tx.hpBefore and tx.hpBefore[target.char]
                            tx.target,tx.hp,tx.maxHP = target,before and before.hp,before and before.maxHP
                            tx.extendedOnly = tx.focusExtendedOnly==true
                            if tx.extendedOnly then
                                local ok,geo=pcall(bridge.geometry,bridge,self.features.combat,s,target)
                                local clear,blocked=pcall(bridge.occluded,bridge,s,target)
                                tx.extendedClaimValid=ok and geo and geo.valid and clear and blocked==false or false
                            end
                        end
                        self.ledger:event("client_candidate_sample",now,{found = target ~= nil,claimObserved = false})
                    end
                    if now>=(tx.nextHPRead or 0) or tx.dirty then
                        tx.nextHPRead=now+.1
                        local char=tx.nativeTarget or tx.localTarget or tx.target and tx.target.char
                        if tx.observedChar~=char then
                            tx.observedChar,tx.hpDrop,tx.hpInvalid=char,false,false
                        end
                        local ok,hum=pcall(function()return char and char:FindFirstChildOfClass("Humanoid")end)
                        local before=char and tx.hpBefore and tx.hpBefore[char]
                        if ok and hum and hum.Parent and before then
                            if (before.hum and hum~=before.hum or hum.MaxHealth~=before.maxHP) and not tx.hpInvalid then
                                tx.hpInvalid,tx.dirty=true,true
                            end
                            if not tx.hpInvalid and Core.finite(hum.Health) and Core.finite(before.hp)
                                and hum.Health<before.hp-.05 and not tx.hpDrop then
                                tx.hpDrop,tx.dirty=true,true
                            end
                        end
                    end
                    if now>=tx.claimDue+.8 and (not tx.classified or tx.dirty) then
                        local first=not tx.classified
                        tx.classified,tx.dirty = true,false
                        local drop=tx.hpDrop and not tx.hpInvalid
                        local damage=tx.feedback and tx.feedback.dmg
                        tx.status = tx.abilityAmbiguous and "Native ability overlaps · ordinary bite impact unassigned"
                            or tx.feedback and tx.feedback.safe==true and "Game reply: target protected"
                            or Core.finite(damage) and damage>0 and (string.format("Game reply reports %.1f damage",damage)
                                ..(drop and " · HP decline correlated" or " · HP change unconfirmed"))
                            or drop and tx.feedback and "Native hit reply + target HP decline · attribution unverified"
                            or drop and "Target HP fell after native marker · attribution unverified"
                            or tx.localTarget and "Local bite impact only · server hit/HP change unconfirmed"
                            or "Native marker observed · no matching HP decline observed"
                        if tx.targetMismatch then tx.status ..= " · local/server target differed" end
                        if not self.combatStatusAt or tx.nativeAt>=self.combatStatusAt then
                            self.combatStatus,self.combatStatusAt=tx.status,tx.nativeAt
                        end
                        if first or drop and not tx.dropReported then
                            self.ledger:event(drop and "target_hp_decline_correlated" or "no_correlated_hp_decline",now,
                                {extendedOnly = tx.extendedOnly == true,nativeReply=tx.feedback~=nil,late=not first,
                                 targetMismatch=tx.targetMismatch==true,damageAcceptance = "unverified"})
                            if drop then tx.dropReported=true end
                        end
                    end
                    if now>=(tx.observeUntil or tx.claimDue+2) then
                        local drop=tx.hpDrop and not tx.hpInvalid
                        local target=tx.target
                        -- Wait for the entire evidence window before adapting
                        -- optional auto-attempts. Silence is not server rejection.
                        if not tx.abilityAmbiguous and tx.extendedOnly and tx.extendedClaimValid and target and target.char
                            and not drop and not tx.positiveReply and not tx.feedback
                            and not (self.lastUnmatchedGameHit and now-self.lastUnmatchedGameHit<1.2) then
                            local entry=self.extendedConfidence[target.char]
                            if not entry then entry={misses=0,waitUntil=0};self.extendedConfidence[target.char]=entry end
                            entry.misses+=1
                            if entry.misses>=2 then entry.waitUntil=now+math.min(4,1.5+entry.misses*.5) end
                            self.ledger:event("extended_contact_unconfirmed",now,
                                {count=entry.misses,autoWait=entry.waitUntil>now})
                        end
                        if not tx.abilityAmbiguous and tx.rateEligible and tx.rateAtClaim and not tx.fastConfirmed and not drop
                            and not (tx.feedback and tx.feedback.safe==true)
                            and (not tx.feedback or tx.rateTarget and tx.feedback.v==tx.rateTarget.char) then
                            self.combatInput:suspect(now)
                        end
                        tx.closed=true;tx.hpBefore=nil
                    end
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
            self:releaseSurface()
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
        -- Recover an executor pulse whose scheduled Up callback never ran.
        if type(bridge.clearStaleSyntheticBite)=="function"
            and bridge:clearStaleSyntheticBite(now) then
            self.ledger:event("stale_mouse_repeat_pulse_released",now)
        end
        if Core.finite(dt) and dt>0 then
            self.frameInterval=(self.frameInterval or dt)*.85+math.min(dt,.25)*.15
        end
        local slow = now >= self.nextSlow
        local critical=self.registry.byId.minigame.requested and self.grab.active and self.grab.pending~=nil
        self.timingCritical,bridge.deferNativeDiscovery=critical,critical
        local s = bridge:snapshot(now,not critical and slow and self.registry.byId.flight.requested)
        if s.ability then self:observeCombatAbility(s,now) end
        if s.chat or s.gameMenu then
            self.inputSuspended=true
            self.physicalM1Input=nil
            self.combatInput:cancel()
        end
        if bridge.holdBinding=="M3" and not self.leftHoldBridge and s.middleHeldKnown then
            if not s.middleHeld then self.middlePollArmed=true
            elseif self.middlePollArmed and not self.middlePollDown then
                self.middlePollArmed=false
                self:startMiddle(s,now,nil)
            end
            self.middlePollDown=s.middleHeld
        end
        if bridge.holdBinding=="M3" then
            -- A late synthetic echo or a missed native M1 release can leave
            -- physicalM1Input latched forever. Only clear it after independent
            -- known-up readings outside every synthetic pulse/grace interval.
            if self.physicalM1Input and s.mouseHeldKnown and not s.mouseHeld
                and not bridge.syntheticM1 and now>=(bridge.syntheticM1Until or 0) then
                self.physicalM1MissingSince=self.physicalM1MissingSince or now
                local ok,state=pcall(function()return self.physicalM1Input.UserInputState end)
                if (ok and (state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel))
                    or now-self.physicalM1MissingSince>=.45 then
                    self.physicalM1Input=nil;self.physicalM1MissingSince=nil
                    self.ledger:event("stale_manual_mouse_owner_cleared",now)
                end
            else
                self.physicalM1MissingSince=nil
            end
            s.physicalM1Held=self.physicalM1Input~=nil or (s.mouseHeld and not bridge.syntheticM1)
        end
        self:desktopHoldTick(s,now,critical)
        if self.inputSuspended then s.attackHeld,s.mouseHeld,s.r2Held,s.middleHeld=false,false,false,false
        elseif bridge.holdBinding=="M3" and self.combatInput.held and self.combatInput.held.key=="M3" then s.attackHeld=true end
        self.snapshot = s
        self.grab.enabled = self.registry.byId.minigame.requested
        local clock = s.serverNow
        if clock then
            self.grabClockLostAt=nil
            local cfg = self.grab.enabled and bridge:config("GrabV2Config")
            local native = self.grab.enabled and self.grabInput:controller(now)
            local nativeState,nativeKnown
            if native and (self.grab.active or now >= (self.nextGrabPoll or 0)) then
                local ok,state,known=pcall(native.state)
                if ok then nativeState,nativeKnown=state,known end
                self.nextGrabPoll=now+.25
            end
            if native and s.alive and (nativeState or nativeKnown==true) then
                self.grab:syncNative(nativeState,clock,s.generation,cfg and cfg.PERFECT or .32,
                    cfg and cfg.PASSES or 2.5,now)
            end
            critical=critical or self.grab.enabled and self.grab.active and self.grab.pending~=nil
            self.timingCritical,bridge.deferNativeDiscovery=critical,critical
            if not s.alive and self.grab.active then self.grab:reset("animal unavailable") end
            s.grab,s.afkWalking = self:hasNativeGrab(now),self.walk ~= nil
            self.grabInput:update(self.grab,now,native,nativeState)
            self:pumpGrab(s,false)
            s.grab=self:hasNativeGrab(now)
            if not self.grab.active and self.grabInput.lease then self.grabInput:release() end
            self:updateGrabWake()
        else
            self.grabClockLostAt=self.grabClockLostAt or now
            local p=self.grab.pending
            if not s.alive or now-self.grabClockLostAt>8 then
                self.grab:reset(not s.alive and "animal unavailable" or "server clock unavailable; session paused")
                self.grabInput:release()
            elseif p and p.localEnds and now>p.localEnds+.1 then
                self.grab.pending=nil;self.grab.status="strike expired while server clock unavailable"
            end
            self:cancelGrabWake()
            s.grab,s.afkWalking = self:hasNativeGrab(now),self.walk ~= nil
        end
        -- Both observed and newly adopted native strikes get their first legal
        -- dispatch before any Territory discovery, routing or driver work.
        if self.territory then self.territory:tick(now) end
        if not critical and now >= self.nextBind then self.nextBind = now+1; bridge:bindNative(self) end
        local care=self.territory and self.territory.agent.enabled and self.territory.agent.goal
        self.feeding:tick(s,now,care and (care.kind=="EAT" or care.kind=="DRINK"))
        self:stepFlightHandoff(s,now)
        self.rescue:tick(s,now)
        self.activity=self.policy:activity(s,now)
        bridge.predictionActive=s.attackHeld or self.combatInput.held~=nil or self.registry.byId.autoBite.requested
        -- InputBegan can remain held even when an executor/virtual M1 reset
        -- momentarily reports IsMouseButtonPressed=false. Recovery must not
        -- re-enter owned Rest in the middle of that human-held attack.
        local repeatActive=self.registry.byId.holdBite.requested
            and (self.combatInput.held~=nil or bridge.holdBinding=="M1" and s.attackHeld==true)
            and s.alive and not s.chat and not s.gameMenu and not self.inputSuspended and not self.policy.manualRest
        if repeatActive then
            self.policy.attackUntil=math.max(self.policy.attackUntil,now+1.1)
            if self.recovery.owned and not self.recovery:release("held bite priority",now) then
                self.combatInput:pause("native Rest exit pending",now)
            end
        end
        local auto=self.registry.byId.autoBite.requested and not (self.territory and self.territory.agent.enabled)
        local clear=auto and bridge:autoAttackTarget(s,self.guide,self.features.combat)
        self.nativeGrabBusy=self:hasNativeGrab(now)
        local grabActive=self.nativeGrabBusy==true
            or self.grabInput.lease~=nil
        local lease=self.grabInput.lease
        -- WolfController.tryBite does not use CAS M1 binding. Its native
        -- handler may run alongside the perfect-press scheduler only for a
        -- known hunter minigame with the original M1 minigame action safely
        -- separated. A prey/captured player and all synthetic M1 fallbacks
        -- continue to have minigame priority.
        local nativeMini=grabActive and self.grab.active and self.grab.role=="hunter"
            and lease~=nil and lease.state and not lease.state.ended
            and not bridge:nativeGrabBound()
            and (bridge.holdBinding=="M1" and s.mouseHeld==true or self.combatInput.held~=nil
                and self.combatInput.held.handoff==true)
            and not s.captured
            and bridge.wolfActions and type(bridge.wolfActions.tryBite)=="function"
        local strike=self.grab.pending
        local nearPress=strike and s.serverNow and math.abs(strike.at-s.serverNow)<.095 or false
        self.combatInput:tick(s,now,{
            repeatHeld=self.registry.byId.holdBite.requested and not self.inputSuspended,
            speedEnabled=self.registry.byId.attackSpeed.requested,
            automatic=auto and not self.inputSuspended,targetValid=clear,
            inputSuspended=self.inputSuspended==true,
            minigameBusy=grabActive,nativeMinigame=nativeMini==true,
            minigamePressNear=nearPress==true,
            uiBlocked=self.ui:contains(bridge.UserInputService:GetMouseLocation()),
            beforeAttempt=function()
                self.policy:input("attack",now)
                local released=self.recovery:release("native cadence input",now)
                self.rescue:cancel();self:stopWalk("native cadence input")
                return released
            end,
        })
        if not critical then self.features:reconcile(s,now) end
        if not critical and now >= self.nextScan then
            self.nextScan = now+((s.combat==true or s.attackHeld or self.combatInput.held~=nil) and .12
                or math.clamp((self.frameInterval or .02)*6,.12,.3))
            local candidates = bridge:candidates(s,self.settings.range)
            if self.features:combatProfileReady() then
                self.guide = bridge:select(s,self.features.originalCombat,self.features.combat,candidates)

            else
                self.guide=nil
                self.policy.combatApproachUntil=0
            end
            self.guideAt=now
            self.ui:syncTracked(bridge.tracked)
        end
        self.hippo:tick(s,now,self.registry.byId.hippoRelease.requested,self.guide,self.features.originalCombat)
        -- Recovery follows observed action ownership, never nearby-player distance.
        self.recovery.enabled = self.registry.byId.recovery.requested or self.territoryRecoveryOwner~=nil
        self.recovery:tick(s,now)
        self:stepClimb(s,now)
        self:stepEscape(s,now)
        if not critical then self:stepCombat(s,now) end
        self.biteReadiness=bridge:biteReadiness(s,now,self.policy)
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
        if self.guide and self.snapshot and self.features:combatProfileReady() then
            bridge:refreshGuide(self.snapshot,self.features.originalCombat,self.features.combat,self.guide)
        end
        self.features:paintHippoGait()
        self.endurance:render(self.snapshot,bridge.clock(),self.windowFocused)
        self:ackEndurance(self.snapshot)
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
        self.endurance:setEnabled(self.registry.byId.enduranceMove.requested)
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
        self.physicalM1Input=nil
        self.nativeGrabSession=nil
        self.cleanupErrors = {}
        for _,cleanup in ipairs({
            function() if self.territory then self.territory.close() end end,
            function() self.zoom:close() end,
            function() self.voice:close() end,
            function() self.endurance:close() end,
            function() self:cancelGrabWake() end,
            function() self.recovery:close(bridge.clock()) end,
            function() self.grabInput:close() end,
            function() self.feeding:close(bridge.clock()) end,
            function() self:disarmDesktopHold(bridge.clock());self.combatInput:cancel();self.rescue:cancel() end,
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
        local closed,why=pcall(self.scope.close,self.scope)
        if not closed then table.insert(self.cleanupErrors,tostring(why)) end
        for _,scopeError in ipairs(self.scope.errors or {}) do
            table.insert(self.cleanupErrors,tostring(scopeError))
        end
        if bridge.env.FERAL_RENAISSANCE_ACTIVE == self then bridge.env.FERAL_RENAISSANCE_ACTIVE = nil end
        if bridge.env.FERAL_NOVA_PRIME_ACTIVE == self.marker then bridge.env.FERAL_NOVA_PRIME_ACTIVE = nil end
    end
    return h
end
return Controller
]============]
sources["amber_ledger"] = [============[
-- Bounded run accounting. Requests, world observations and attribution differ.
local Ledger={}
local function finite(n)return type(n)=="number" and n==n and math.abs(n)<1e12 end
function Ledger.new()
    local l={serial=0}
    function l:start(now)
        self.serial+=1;self.run=self.serial;self.started=now;self.at=now
        self.wall,self.active,self.paused,self.unknown=0,0,0,0
        self.phases,self.failures,self.outcomes,self.costs={},{},{},{}
        self.inflow,self.outflow,self.net=0,0,0;self.balance=nil;self.character=nil
        self.assistance=0;self.wasManual=false;self.previous=nil;self.gaits={};self.modes={}
    end
    function l:sample(now,phase,paused,manual,goal,state,nav)
        if not self.run then self:start(now) end
        local dt=math.max(0,now-(self.at or now));self.at=now;self.wall+=dt
        local known=math.min(dt,2);local gap=dt-known;self.unknown+=gap
        local p=self.previous and {phase=phase or "WAIT",paused=paused==true,goal=goal}
        if p then
            if p.paused then self.paused+=known else self.active+=known end
            self.phases[p.phase]=(self.phases[p.phase] or 0)+known
            if not p.paused then
                local mode=(not state or not state.alive) and "unavailable" or state.underwater and "depth"
                    or state.flying and "flight" or state.climbing and "climb" or state.swimming and "surface_water" or "ground"
                self.modes[mode]=(self.modes[mode] or 0)+known
                local observed=nav and nav.gaits and nav.gaits.observed
                if observed~="WALK" and observed~="TROT" and observed~="SPRINT" and observed~="BURST" then observed="UNKNOWN" end
                self.gaits[observed]=(self.gaits[observed] or 0)+known
            end
            local g=p.goal
            if g then
                g.timing=g.timing or {active=0,paused=0,unknown=0,phases={}}
                local t=g.timing;t.unknown+=gap
                if p.paused then t.paused+=known else t.active+=known end
                t.phases[p.phase]=(t.phases[p.phase] or 0)+known
            end
        else self.unknown+=known end
        if manual and not self.wasManual then self.assistance+=1 end
        self.wasManual=manual==true
        self.previous={phase=phase or "WAIT",paused=paused==true,goal=goal}
    end
    function l:currency(value,character)
        if not finite(value) then self.balance=nil;return end
        if self.character~=character then self.balance=nil;self.character=character end
        if self.balance then
            local delta=value-self.balance;self.net+=delta
            if delta>0 then self.inflow+=delta else self.outflow-=delta end
        end
        self.balance=value
    end
    function l:count(kind,reason)
        local t=kind=="failure" and self.failures or self.outcomes
        local key=tostring(reason or kind):sub(1,100)
        if not t[key] then
            local n=0;for _ in pairs(t) do n+=1 end
            if n>=48 then key="other" end
        end
        t[key]=(t[key] or 0)+1
    end
    function l:cost(name,seconds)
        local c=self.costs[name] or {calls=0,total=0,max=0,samples={}}
        self.costs[name]=c;c.calls+=1;c.total+=seconds;c.max=math.max(c.max,seconds)
        table.insert(c.samples,seconds);if #c.samples>128 then table.remove(c.samples,1) end
    end
    function l:summary()
        local costs={}
        for k,c in pairs(self.costs or {}) do
            local s=table.clone(c.samples);table.sort(s)
            costs[k]={calls=c.calls,total=c.total,max=c.max,p95=s[math.max(1,math.ceil(#s*.95))],p99=s[math.max(1,math.ceil(#s*.99))]}
        end
        return {run=self.run,wall=self.wall,active=self.active,paused=self.paused,unobserved=self.unknown,
            phases=self.phases,observedGaitSeconds=self.gaits,modeSeconds=self.modes,
            manualInterventions=self.assistance,failures=self.failures,outcomes=self.outcomes,costs=costs,
            amber={inflow=self.inflow,outflow=self.outflow,net=self.net,
                inflowPerWallHour=self.wall and self.wall>0 and self.inflow*3600/self.wall or nil,
                netPerWallHour=self.wall and self.wall>0 and self.net*3600/self.wall or nil,attribution="unattributed observed balance changes"}}
    end
    return l
end
return Ledger
]============]
sources["amber_model"] = [============[
-- Small, generation-scoped travel observations and checked passage graph.
local Model={}
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)end
local function key(p)return math.floor(p.x/48)..":"..math.floor(p.z/48)end
local function copy(p)return {x=p.x,y=p.y,z=p.z}end
function Model.new()
    local m={identity=nil,edges={},nodes={},order={},costs={},observations=0,failures=0}
    function m:reset(identity)
        if identity==self.identity then return end
        self.identity=identity;self.edges={};self.nodes={};self.order={};self.costs={}
    end
    function m:estimate(a,b,now,speed,purpose)
        local direct=distance(a,b)/math.max(6,speed or 24)
        local c=self.costs[key(a)..">"..key(b)..":"..tostring(purpose or "point")]
        if c and now-c.at<600 then
            return (c.access and c.seconds or math.max(direct,c.seconds)),c.samples>=2 and "observed" or "single observation"
        end
        return direct,"distance estimate"
    end
    function m:record(a,b,seconds,now,failed,purpose,access)
        if distance(a,b)<12 then return end
        local k=key(a)..">"..key(b)..":"..tostring(purpose or "point");local c=self.costs[k]
        local value=failed and math.max(seconds,45,distance(a,b)/10) or seconds
        if c then c.seconds=c.seconds*.4+value*.6;c.at=now;c.samples+=1;c.access=access==true
        else
            local count=0;local oldest,at=nil,math.huge
            for id,v in pairs(self.costs) do count+=1;if v.at<at then oldest,at=id,v.at end end
            if count>=192 then self.costs[oldest]=nil end
            self.costs[k]={seconds=value,at=now,samples=1,access=access==true}
        end
        if failed then self.failures+=1 else self.observations+=1 end
    end
    function m:addRoute(points,now)
        local previous
        for _,p in ipairs(points) do
            local k=key(p)
            if not self.nodes[k] then
                if #self.order>=160 then
                    local old=table.remove(self.order,1);self.nodes[old]=nil;self.edges[old]=nil
                    for _,e in pairs(self.edges) do e[old]=nil end
                end
                table.insert(self.order,k)
            end
            self.nodes[k]={point=copy(p),at=now};self.edges[k]=self.edges[k] or {}
            if previous and previous~=k and self.nodes[previous] and self.edges[previous] then
                self.edges[previous][k]={cost=distance(self.nodes[previous].point,p),at=now}
            end
            previous=k
        end
    end
    function m:path(a,b,now)
        local costs,parents,open={},{},{}
        for k,n in pairs(self.nodes) do
            local d=distance(a,n.point)
            if d<80 and now-n.at<180 then costs[k]=d;open[k]=true end
        end
        for _=1,160 do
            local current,best=nil,math.huge
            for k in pairs(open) do if costs[k]<best then current,best=k,costs[k] end end
            if not current then break end
            open[current]=nil
            local n=self.nodes[current]
            if n and distance(n.point,b)<90 then
                local result={copy(b)};local k=current;local seen={}
                while k and not seen[k] do
                    seen[k]=true;table.insert(result,1,copy(self.nodes[k].point));k=parents[k]
                end
                return result
            end
            for k,e in pairs(self.edges[current] or {}) do
                if self.nodes[k] and now-e.at<180 and (not costs[k] or best+e.cost<costs[k]) then
                    costs[k]=best+e.cost;parents[k]=current;open[k]=true
                end
            end
        end
        return nil
    end
    function m:summary()return {passages=#self.order,travelObservations=self.observations,routeFailures=self.failures}end
    return m
end
return Model
]============]
sources["amber_planner"] = [============[
-- Grizzly Amber v1: pure objective planner. Never writes territory/game state.
-- Hex geometry, pay, owner, hold and progress are replicated native observations.
local Planner = {}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e10 end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function dist(a,b)
    if not a or not b or not finite(a.x) or not finite(a.z) or not finite(b.x) or not finite(b.z) then
        return math.huge
    end
    local dx,dz=a.x-b.x,a.z-b.z
    return math.sqrt(dx*dx+dz*dz)
end
local function pathRisk(a,b,players,avoidRadius)
    for _,p in ipairs(players or {}) do
        if finite(p.x) and finite(p.z) then
            local vx,vz=b.x-a.x,b.z-a.z
            local denom=vx*vx+vz*vz
            local t=denom>.01 and clamp(((p.x-a.x)*vx+(p.z-a.z)*vz)/denom,0,1) or 0
            local qx,qz=a.x+vx*t,a.z+vz*t
            local offset=math.sqrt((qx-p.x)^2+(qz-p.z)^2)
            if offset<avoidRadius then return true,offset end
        end
    end
    return false,math.huge
end
Planner.distance=dist
Planner.pathRisk=pathRisk

-- kind is CLAIM or SCENT. Existing claims have a minimum guard against churn.
function Planner.objective(hex,state,from,options)
    options=options or {}
    if not hex or type(hex.key)~="string" or hex.neutral or state.pack==nil
        or not hex.center or not finite(hex.center.x) or not finite(hex.center.z) then return nil end
    if (options.exclude and options.exclude[hex.key])
        or (options.blockedUntil and (options.blockedUntil[hex.key] or 0)>(state.now or 0)) then return nil end
    if state.contested and state.contested[hex.key] then return nil end
    local owned=hex.owner==state.pack
    if options.maintenanceOnly and not owned then return nil end
    if owned and options.retainOwned and not options.retainOwned[hex.key] then return nil end
    local hold=finite(hex.hold) and clamp(hex.hold,0,1) or nil
    local payKnown=finite(hex.pay)
    local pay=payKnown and clamp(hex.pay,1,20) or 1
    local kind,priority
    if owned then
        if hold==nil or hold>= (options.scentThreshold or .84) then return nil end
        kind="SCENT"
        priority=45+pay*8+(1-hold)*180
        if hold<.35 then priority+=125 end
        if finite(hex.fade) and finite(state.unixNow) then
            local seconds=hex.fade-state.unixNow
            if seconds<150 then priority+=math.max(0,150-seconds)*.32 end
        end
    else
        kind="CLAIM"
        priority=80+pay*23
        if hex.owner==nil then priority+=30 else priority-=15 end
        if hex.by==state.pack and finite(hex.prog) and hex.prog>0 then
            priority+=140+clamp(hex.prog,0,1)*100
        end
    end
    local d=dist(from,hex.center)
    if d==math.huge then return nil end
    local deny,nearest=pathRisk(from,hex.center,state.players,options.avoidRadius or 120)
    if deny and options.avoidPlayers==true then return nil end
    local recent=options.recent and options.recent[hex.key]
    local waiting=options.waitingSince and options.waitingSince[hex.key]
    if finite(waiting) then priority+=math.min(180,math.max(0,(state.now or 0)-waiting)/5) end
    if finite(recent) and (state.now or 0)-recent<120 then priority*=.65 end
    local travel,confidence=d/24,"distance estimate"
    local estimate=options.travelCost or state.travelCost
    if type(estimate)=="function" then
        local ok,t,c=pcall(estimate,from,hex.center,"HEX:"..hex.key)
        if ok and finite(t) and t>=0 then travel,confidence=t,c or "estimate" end
    end
    local service=kind=="SCENT" and (state.refillTime or 60)*(1-hold)
        or (state.claimTime or 20)*(1-(hex.by==state.pack and finite(hex.prog) and clamp(hex.prog,0,1) or 0))
    local deadline=finite(hex.deadlineSeconds) and math.max(0,hex.deadlineSeconds) or nil
    -- Fade is used only when its units plausibly match the supplied Unix clock.
    if not deadline and finite(hex.fade) and finite(state.unixNow) and math.abs(hex.fade-state.unixNow)<86400 then
        deadline=math.max(0,hex.fade-state.unixNow)
    end
    local slack=deadline and deadline-travel-service or nil
    if kind=="SCENT" and slack and slack<60 then priority+=math.max(0,60-slack)*6 end
    local routeCost=1+d/320
    local score=type(estimate)=="function" and priority/math.max(2,travel+service+2) or priority/(routeCost^.74)
    if not finite(score) then return nil end
    return {key=hex.key,kind=kind,score=score,base=priority,distance=d,
        pay=payKnown and pay or nil,hold=hold,center=hex.center,nearestPlayer=nearest,
        urgency=owned and (1-(hold or 0)) or 0,travelSeconds=travel,serviceSeconds=service,
        deadlineSeconds=deadline,slack=slack,confidence=confidence}
end

function Planner.plan(hexes,state,options)
    options=options or {}
    if type(hexes)~="table" or not state or not state.position then return {} end
    local route,from={},state.position
    local exclude={}
    for key,blocked in pairs(options.exclude or {}) do if blocked then exclude[key]=true end end
    local n=math.min(options.maxStops or 6,16)
    for step=1,n do
        local ranked={}
        local opt={}
        for k,v in pairs(options) do opt[k]=v end
        opt.exclude=exclude
        for _,hex in ipairs(hexes) do
            local item=Planner.objective(hex,state,from,opt)
            if item then table.insert(ranked,item) end
        end
        if #ranked==0 then break end
        table.sort(ranked,function(a,b) if a.score~=b.score then return a.score>b.score end return a.key<b.key end)
        -- One-stop lookahead rewards efficient clusters rather than global backtracking.
        local best=nil
        for j=1,math.min(7,#ranked) do
            local candidate=ranked[j]
            local forward=0
            if step<n then
                local lookOpt={}
                for k,v in pairs(opt) do lookOpt[k]=v end
                local skip={}
                for k,v in pairs(exclude) do skip[k]=v end
                skip[candidate.key]=true
                lookOpt.exclude=skip
                for _,hex in ipairs(hexes) do
                    local other=Planner.objective(hex,state,candidate.center,lookOpt)
                    if other and other.score>forward then forward=other.score end
                end
            end
            candidate.trajectory=candidate.score+forward*.16
            if not best or candidate.trajectory>best.trajectory
                or candidate.trajectory==best.trajectory and candidate.key<best.key then best=candidate end
        end
        table.insert(route,best)
        exclude[best.key]=true
        from=best.center
    end
    if options.currentKey and options.currentKey~="" and #route>0 and route[1].key~=options.currentKey then
        -- Preserve an active objective unless it is done, dangerous or strongly outclassed.
        local current
        for _,hex in ipairs(hexes) do
            if hex.key==options.currentKey then
                current=Planner.objective(hex,state,state.position,options);break
            end
        end
        if current and current.score>=route[1].score*.73 and
            (state.now or 0)-(options.currentStarted or 0)<(options.maxCommitSeconds or 75) then
            for i=#route,1,-1 do if route[i].key==current.key then table.remove(route,i) end end
            table.insert(route,1,current)
            while #route>n do table.remove(route) end
        end
    end
    return route
end

-- Native regionCell is a one-based row-major ID. Sweep alternating rows to
-- finish complete areas without crossing repeatedly between opposite corners.
function Planner.regionOrder(grid)
    local order={}
    for row=0,grid-1 do
        for step=0,grid-1 do
            local col=row%2==0 and step or grid-1-step
            table.insert(order,row*grid+col+1)
        end
    end
    return order
end
local function localTour(hexes,state,options)
    local remaining={}
    for _,hex in ipairs(hexes) do
        local item=Planner.objective(hex,state,state.position,options)
        if item then item.region=hex.region;item.hex=hex;table.insert(remaining,item) end
    end
    local route,from={},state.position
    local elapsed=0
    while #remaining>0 and #route<math.min(options.maxStops or 6,16) do
        local best,index,value=nil,nil,-math.huge
        for i,item in ipairs(remaining) do
            local refreshed=Planner.objective(item.hex,state,from,options)
            local t=refreshed.travelSeconds+refreshed.serviceSeconds+2
            local rank=refreshed.base/math.max(2,t)/(1+(refreshed.travelSeconds/5)^2)
            if refreshed.slack and refreshed.slack-elapsed<45 then
                rank+=1000/math.max(1,refreshed.slack-elapsed+20)
            end
            if rank>value or rank==value and item.key<(best and best.key or "~") then
                best,index,value=refreshed,i,rank
                best.region=item.region
            end
        end
        elapsed+=best.travelSeconds+best.serviceSeconds
        table.insert(route,best);table.remove(remaining,index);from=best.center
    end
    return route
end
function Planner.strategy(hexes,state,options)
    options=options or {}
    local grid=state.regionGrid
    if not finite(grid) or grid<1 or grid>8 or grid%1~=0 then
        return Planner.plan(hexes,state,options),{phase="GENERAL",cursor=options.regionCursor or 1}
    end
    local groups={};local urgent={};local anyRegion=false
    for _,hex in ipairs(hexes) do
        if hex.region and not hex.neutral then
            anyRegion=true
            groups[hex.region]=groups[hex.region] or {total=0,owned=0,hexes={}}
            local group=groups[hex.region];group.total+=1
            if hex.owner==state.pack then group.owned+=1 end
            table.insert(group.hexes,hex)
        end
        local item=Planner.objective(hex,state,state.position,options)
        if item and item.kind=="SCENT" and item.hold and (item.hold<.28 or item.slack and item.slack<45) then table.insert(urgent,hex) end
    end
    if not anyRegion then return Planner.plan(hexes,state,options),{phase="GENERAL",cursor=1} end
    local order=Planner.regionOrder(grid)
    if #urgent>0 then return localTour(urgent,state,options),{phase="URGENT_SCENT",cursor=options.regionCursor or 1} end
    local oldest,agedRegion=300,nil
    for region,group in pairs(groups) do
        for _,hex in ipairs(group.hexes) do
            local since=options.waitingSince and options.waitingSince[hex.key]
            if finite(since) and (state.now or 0)-since>oldest and Planner.objective(hex,state,state.position,options) then
                oldest,agedRegion=(state.now or 0)-since,region
            end
        end
    end
    if agedRegion then
        local index=table.find(order,agedRegion) or 1
        return localTour(groups[agedRegion].hexes,state,options),{phase="FAIRNESS_SWEEP",cursor=index,region=agedRegion,
            area="Revisiting waiting area",order=order}
    end
    local cursor=math.clamp(options.regionCursor or 1,1,#order)
    if not options.regionCursor then
        local closest=math.huge
        for index,region in ipairs(order) do
            local group=groups[region]
            if group then
                for _,hex in ipairs(group.hexes) do
                    local item=Planner.objective(hex,state,state.position,options)
                    if item and item.travelSeconds<closest then cursor,closest=index,item.travelSeconds end
                end
            end
        end
    end
    local direction=options.regionDirection or 1
    if not options.regionCursor then
        local best=math.huge
        for _,candidateDirection in ipairs({1,-1}) do
            for step=1,#order-1 do
                local index=(cursor+step*candidateDirection-1)%#order+1
                local group=groups[order[index]];local cost=math.huge
                for _,hex in ipairs(group and group.hexes or {}) do
                    local item=Planner.objective(hex,state,state.position,options)
                    if item then cost=math.min(cost,item.travelSeconds) end
                end
                if cost<math.huge then
                    if cost<best then direction,best=candidateDirection,cost end
                    break
                end
            end
        end
    end
    -- Claims first, then maintenance; blocked areas stay eligible for the next
    -- pass instead of being incorrectly counted as completed.
    for _,claimsOnly in ipairs({true,false}) do
        for step=0,#order-1 do
            local index=(cursor+step*direction-1)%#order+1
            local region=order[index];local group=groups[region]
            if group and (not claimsOnly or group.owned<group.total) then
                local pool={}
                for _,hex in ipairs(group.hexes) do
                    if not claimsOnly or hex.owner~=state.pack then table.insert(pool,hex) end
                end
                local route=localTour(pool,state,options)
                if #route>0 then
                    local row,col=math.floor((region-1)/grid),(region-1)%grid
                    local vertical=grid==3 and ({"Top","Middle","Bottom"})[row+1] or ("Row "..(row+1))
                    local horizontal=grid==3 and ({"left","centre","right"})[col+1] or ("column "..(col+1))
                    return route,{phase=claimsOnly and "AREA_SWEEP" or "AREA_MAINTENANCE",cursor=index,
                        region=region,direction=direction,area=vertical.." "..horizontal,owned=group.owned,total=group.total,
                        bonus=state.regionBonus,order=order}
                end
            end
        end
    end
    return {},{phase="MAINTAINED",cursor=cursor,direction=direction,order=order}
end

function Planner.decide(state,options)
    options=options or {}
    if not state or not finite(state.healthFraction) or state.healthFraction<0 or state.healthFraction>1.05 or state.needsKnown==false then
        return {kind="WAIT",reason="Waiting for valid native health and needs"}
    end
    if state.hungerMax~=nil and (not finite(state.hungerMax) or state.hungerMax<=0)
        or state.thirstMax~=nil and (not finite(state.thirstMax) or state.thirstMax<=0) then
        return {kind="WAIT",reason="Native resource maxima unavailable"}
    end
    local hm=finite(state.hungerMax) and state.hungerMax>0 and state.hungerMax or 100
    local tm=finite(state.thirstMax) and state.thirstMax>0 and state.thirstMax or 100
    local h=finite(state.hunger) and state.hunger/hm or nil
    local t=finite(state.thirst) and state.thirst/tm or nil
    if not h or not t or h<0 or t<0 then return {kind="WAIT",reason="Waiting for both native needs"} end
    -- A merely thirsty animal must not repeatedly defer a starving one. Use
    -- observed depletion margins when both exist, otherwise normalized needs.
    local critical
    if h<.19 and t<.19 then
        local hr=finite(state.hungerReserve) and state.hungerReserve or h
        local tr=finite(state.thirstReserve) and state.thirstReserve or t
        if not (finite(state.hungerReserve) and finite(state.thirstReserve)) then hr,tr=h,t end
        critical=hr<tr and "EAT" or "DRINK"
    elseif t<.19 then critical="DRINK" elseif h<.19 then critical="EAT" end
    if state.healthFraction<.25 then
        if critical and (state.feedCan==(critical=="DRINK" and "drink" or "eat") or state.recoveryStalled
            or critical=="DRINK" and t<.08 or critical=="EAT" and h<.08) then
            return {kind=critical,critical=true,reason="Immediate native care before critical recovery"}
        end
        return {kind="RECOVER",critical=true,reason="Critical health"}
    end
    if critical then return {kind=critical,critical=true,reason="Critical survival need"} end
    if state.healthFraction<(options.minimumHP or .46) then return {kind="RECOVER",reason="Low health"} end
    local drinkBudget=math.max(180,(state.drinkETA or 0)+45)
    local foodBudget=math.max(240,(state.foodETA or 0)+60)
    if t and t<.8 and finite(state.thirstReserve) and state.thirstReserve<drinkBudget then
        return {kind="DRINK",reason="Water reserve shorter than care margin"}
    end
    if h and h<.8 and finite(state.hungerReserve) and state.hungerReserve<foodBudget then
        return {kind="EAT",reason="Food reserve shorter than acquisition margin"}
    end
    if t and t<(options.thirstTrigger or 44)/100 then return {kind="DRINK",reason="Thirst care"} end
    if h and h<(options.hungerTrigger or 42)/100 then return {kind="EAT",reason="Hunger care"} end
    return {kind="TERRITORY",reason="Survival reserve available"}
end
function Planner.need(state,options)return Planner.decide(state,options).kind end
-- Due-job deadlines and sustained maintenance are separate estimates. Include
-- healthy owned hexes in the latter: a full scent bar still creates future work.
-- Unknown decay is never silently replaced by an invented native lifetime.
function Planner.capacity(hexes,state,options)
    options=options or {}
    local jobs,recurring={},{}
    local unknown,owned=0,0
    local refill=finite(state.refillTime) and state.refillTime>0 and state.refillTime or 60
    local horizon=finite(options.horizon) and clamp(options.horizon,120,7200) or 900
    local floor=.35
    local function travel(from,to,purpose)
        local fallback=dist(from,to)/math.max(6,finite(state.travelSpeed) and state.travelSpeed or 24)
        if type(state.travelCost)=="function" then
            local ok,value=pcall(state.travelCost,from,to,purpose)
            if ok and finite(value) and value>=0 then return value end
        end
        return fallback
    end
    for _,hex in ipairs(hexes) do
        if state.pack~=nil and hex.owner==state.pack and not hex.neutral then
            owned+=1
            local item=Planner.objective(hex,state,state.position,options)
            if item and item.deadlineSeconds then table.insert(jobs,item) end
            local rate=hex.decayPerSecond
            if type(hex.key)=="string" and finite(rate) and rate>0 and rate<.1 and finite(hex.hold)
                and hex.center and finite(hex.center.x) and finite(hex.center.z) and #recurring<128 then
                local period=(1-floor)/rate
                local service=refill*(1-floor)
                table.insert(recurring,{key=hex.key,center=hex.center,pay=finite(hex.pay) and clamp(hex.pay,1,20) or 1,
                    period=period,service=service,load=service/period,
                    nextDue=math.max(0,(hex.hold-floor)/rate),
                    travel=travel(state.position,hex.center,"HEX:"..hex.key)})
            else unknown+=1 end
        end
    end
    table.sort(jobs,function(a,b)
        return a.deadlineSeconds==b.deadlineSeconds and a.key<b.key or a.deadlineSeconds<b.deadlineSeconds
    end)
    local elapsed,misses=0,0;local from=state.position
    for _,item in ipairs(jobs) do
        elapsed+=travel(from,item.center,"HEX:"..item.key)+item.serviceSeconds
        if elapsed>item.deadlineSeconds then misses+=1 end
        from=item.center
    end
    -- A bounded nearest-neighbour tour gives a travel allowance. It is an
    -- estimate, not a proof that every live terrain segment is traversable.
    local remaining=table.clone(recurring);from=state.position
    local tour,period,serviceLoad,events=0,math.huge,0,0
    for _,job in ipairs(recurring) do
        period=math.min(period,job.period);serviceLoad+=job.load
        events+=math.max(0,math.floor((horizon-job.nextDue)/job.period)+1)
    end
    while #remaining>0 do
        local index,best=1,math.huge
        for i,job in ipairs(remaining) do
            local cost=(from.x-job.center.x)^2+(from.z-job.center.z)^2
            if cost<best or cost==best and job.key<remaining[index].key then index,best=i,cost end
        end
        local job=table.remove(remaining,index);tour+=travel(from,job.center,"HEX:"..job.key);from=job.center
    end
    if #recurring>1 then tour+=travel(from,state.position,"MAINTENANCE_RETURN") end
    local care=finite(options.careFraction) and clamp(options.careFraction,0,.75) or 0
    local available=1-care
    local load=serviceLoad+(period<math.huge and tour/period or 0)
    local maintenanceState=#recurring==0 and "UNKNOWN" or unknown>0 and "PARTIAL"
        or load>available and "OVERLOADED" or "ESTIMATED_SUSTAINABLE"
    local retain,retained,retainedLoad={},0,0
    -- Act only on proven service overload (even zero travel cannot fit). The
    -- travel estimate alone may defer new acquisitions but does not abandon
    -- existing owned work. Higher-value cheap maintenance remains productive.
    local hardOverload=unknown==0 and serviceLoad>available
    if hardOverload then
        table.sort(recurring,function(a,b)
            local ar=a.pay/math.max(.0001,a.load+a.travel/a.period)
            local br=b.pay/math.max(.0001,b.load+b.travel/b.period)
            return ar==br and a.key<b.key or ar>br
        end)
        for _,job in ipairs(recurring) do
            local marginal=job.load+job.travel/job.period
            if retainedLoad+marginal<=available*.95 or retained==0 then
                retain[job.key]=true;retained+=1;retainedLoad+=marginal
            end
        end
    end
    return {knownDeadlines=#jobs,unknown=unknown,estimatedSeconds=elapsed,predictedLate=misses,
        state=#jobs==0 and "UNKNOWN" or misses>0 and "DEADLINE_PRESSURE" or "DUE_WORK_FEASIBLE",
        scope="due deadlines plus bounded recurring owned-map workload; estimates require live calibration",
        maintenance={state=maintenanceState,owned=owned,known=#recurring,unknown=unknown,horizonSeconds=horizon,
            visits=events,serviceUtilization=serviceLoad,travelUtilization=period<math.huge and tour/period or 0,
            estimatedUtilization=load,availableFraction=available,tourSeconds=tour,
            intervalSeconds=period<math.huge and period or nil,retained=hardOverload and retained or owned,
            retainedFeasible=hardOverload and retainedLoad<=available or not hardOverload},
        maintenanceOnly=unknown==0 and #recurring>0 and load>available,
        retainOwned=hardOverload and retain or nil,
        policy=hardOverload and (retainedLoad<=available and "Retain highest-value estimated maintenance subset; no new claims"
            or "Even best maintenance exceeds capacity; prioritize it without new claims")
            or maintenanceState=="OVERLOADED" and "Preserve owned maintenance before new claims"
            or unknown>0 and "Unknown lifetime remains eligible; no sustainability claim" or "Full observed workload estimated"}
end
return Planner
]============]
sources["amber_gait"] = [============[
-- FERAL Amber: pure navigation/locomotion decisions, no side effects.
-- Distances in horizontal studs; angles in degrees; reserves protect stamina.
local Gait={}
local function finite(x)
    return type(x)=="number" and x==x and math.abs(x)<1e9
end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
function Gait.distance(a,b)
    if not a or not b or not finite(a.x) or not finite(a.z)
        or not finite(b.x) or not finite(b.z) then return math.huge end
    local dx,dz=a.x-b.x,a.z-b.z
    return math.sqrt(dx*dx+dz*dz)
end
function Gait.turn(previous,position,target)
    if not previous or not position or not target then return 0 end
    local ax,az=position.x-previous.x,position.z-previous.z
    local bx,bz=target.x-position.x,target.z-position.z
    local la=math.sqrt(ax*ax+az*az)
    local lb=math.sqrt(bx*bx+bz*bz)
    if la<1 or lb<1 then return 0 end
    local dot=clamp((ax*bx+az*bz)/(la*lb),-1,1)
    return math.deg(math.acos(dot))
end
-- Trot and sprint are valid across land animals; burst only when an actual
-- game input is available and enough stamina remains. Never force WalkSpeed.
function Gait.select(distance,turn,stamina,options)
    options=options or {}
    if not finite(distance) or distance<=0 then return "STOP" end
    if options.ability or options.injured then return "TROT" end
    if options.combat and not options.hunting then return "TROT" end
    if options.swimming then
        if options.swimSprint and distance>45 and (not finite(stamina) or stamina>.25) then return "SPRINT" end
        return "TROT"
    end
    if options.following and type(options.gaitSpeeds)=="table" then
        for _,mode in ipairs({"WALK","TROT","SPRINT"}) do
            local speed=options.gaitSpeeds[mode] or options.gaitSpeeds[string.lower(mode)]
            if finite(speed) and speed>=(options.preySpeed or 0)*1.08 then return mode end
        end
    end
    local reserve=finite(stamina) and stamina or nil
    local angle=finite(turn) and turn or 0
    if options.allowBurst~=false and (reserve and reserve>=.56 or not reserve and options.nativeBurstAvailable==true)
        and distance>=80 and angle<=22 and not options.crowded
        and options.burstReady~=false then return "BURST" end
    if options.hunting and (options.preySpeed or 0)>6 and distance>6
        and (not reserve or reserve>=.22) and angle<65 then return "SPRINT" end
    if distance<10 then return "WALK" end
    if distance<24 then return "TROT" end
    if distance>=48 and angle<=72 and not options.crowded
        and (not reserve or reserve>=.22) then return "SPRINT" end
    return "TROT"
end

-- Stateful requests with observed HUD acknowledgements. A successful key API
-- call is only an input request. Burst and trot are native Begin toggles.
function Gait.controller(io)
    local g={requested="STOP",observed="UNKNOWN",changedAt=-100,
        attempts={},blocked={},pending=nil,lastSuccess=nil,reason="Idle",
        burstOwned=false,trotOwned=false,requests=0,confirmations=0}
    function g:step(wanted,s,now)
        s=s or {}
        local observed=s.hudBurst==true and "BURST"
            or s.hudSprint==true and "SPRINT"
            or s.hudTrot==true and "TROT"
            or s.hudSprint==false and s.hudTrot==false and s.hudBurst==false and "WALK"
            or "UNKNOWN"
        self.observed=observed
        if self.pending then
            local p=self.pending
            local confirmed=(p.mode==observed)
                or p.mode=="BURST_OFF" and s.hudBurst==false
                or p.mode=="WALK" and s.hudTrot==false and s.hudSprint==false
            if confirmed then
                self.lastSuccess=now;self.confirmations+=1
                self.attempts[p.mode]=0;self.pending=nil
                self.reason="Native gait observed"
            elseif now-p.at>=1.25 then
                local count=self.attempts[p.mode] or 1
                if count>=2 then self.blocked[p.mode]=now+8 end
                self.pending=nil;self.reason="Gait request unconfirmed"
                if p.mode=="SPRINT" then io:hold("SHIFT",false) end
                if count==1 and type(io.retryInput)=="function" then
                    io:retryInput(p.mode=="SPRINT" and "SHIFT" or p.mode=="TROT" and "Z" or "X")
                end
            end
        end
        local emergency=wanted=="STOP" or wanted=="WALK" or s.ability or s.swimming or s.brake
        local boost=wanted=="BURST" and self.requested=="SPRINT" and observed=="SPRINT"
        if wanted~=self.requested and not emergency and not boost and now-self.changedAt<1.1 then
            wanted=self.requested
        end
        if wanted=="BURST" and (type(s.hudBurst)~="boolean" or s.hudBurstNo or (self.blocked.BURST or 0)>now) then wanted="SPRINT" end
        if (wanted=="SPRINT" or wanted=="BURST") and (self.blocked.SPRINT or 0)>now then wanted="TROT" end
        if wanted~=self.requested then self.changedAt=now;self.requested=wanted end
        if observed==wanted and not self.pending then self.reason="Native gait already active" end
        local fast=wanted=="SPRINT" or wanted=="BURST"
        io:hold("SHIFT",fast)
        local function request(mode,key)
            if self.pending and self.pending.mode~=mode and mode=="BURST_OFF" then self.pending=nil end
            if self.pending or (self.blocked[mode] or 0)>now then return end
            local sent=key=="SHIFT" and io:hold(key,true) or io:tap(key)
            if sent then
                self.attempts[mode]=(self.attempts[mode] or 0)+1
                self.requests+=1;self.pending={mode=mode,at=now}
                self.reason="Input requested; awaiting native gait"
                if mode=="BURST" then self.burstOwned=true end
                if mode=="TROT" then self.trotOwned=true end
            else self.blocked[mode]=now+8;self.reason="Gait input unavailable" end
        end
        if wanted~="BURST" and s.hudBurst==true and self.burstOwned then
            request("BURST_OFF","X")
        elseif wanted=="BURST" and s.hudBurst==false then request("BURST","X")
        elseif fast and s.hudSprint==false and s.hudBurst~=true then request("SPRINT","SHIFT")
        elseif wanted=="TROT" and s.hudTrot==false and s.hudBurst~=true then request("TROT","Z")
        elseif wanted=="WALK" and s.hudTrot==true and self.trotOwned then request("WALK","Z") end
        return self.requested
    end
    function g:stop(s,now)
        io:hold("SHIFT",false)
        -- Undo toggles only when this controller requested them and their
        -- current native state is known. Never blindly toggle an unknown mode.
        if s and s.hudBurst==true and self.burstOwned then io:tap("X") end
        if s and s.hudTrot==true and self.trotOwned then io:tap("Z") end
        self.burstOwned,self.trotOwned=false,false
        self.pending=nil;self.requested="STOP";self.changedAt=now or 0
    end
    return g
end
function Gait.arrived(destinationDistance,claimRadius)
    if not finite(destinationDistance) then return false end
    return destinationDistance<=math.max(8,(claimRadius or 17)-2)
end
-- Keep a goal unless its progress stalls. Do not change directions on each
-- intermediate waypoint when the destination is already within claim radius.
function Gait.waypointIndex(points,index,pos,reach)
    local i=math.max(1,index or 1)
    local radius=math.max(6,reach or 11)
    while i<=#points do
        local point=points[i]
        if Gait.distance(pos,point)<=radius then i+=1
        else break end
    end
    return i
end
function Gait.progress(now,previousTime,previousDistance,currentDistance,delay,minGain)
    if not finite(previousTime) or not finite(previousDistance) then
        return "RESET" end
    if now-previousTime < (delay or 4) then return "MONITOR" end
    if previousDistance-currentDistance >= (minGain or 3) then return "ADVANCING" end
    return "STALLED"
end
return Gait
]============]
sources["amber_nav"] = [============[
-- Continuous native steering, cancellable streamed routes and measured progress.
local Nav={}
local function flat(a,b)
    local x,z=a.X-b.X,a.Z-b.Z
    return math.sqrt(x*x+z*z)
end
local function p2(v) return {x=v.X,z=v.Z} end
local function rayParams(char)
    local p=RaycastParams.new()
    p.FilterType=Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances={char};p.IgnoreWater=false;p.RespectCanCollide=true
    return p
end
function Nav.new(pathService,workspace,Gait,model)
    local n={service=pathService,workspace=workspace,math=Gait,model=model,synthetic={},held={},backends={},gaitBackends={},
        recoveryCells={},trajectory={},operations={rays=0,surfaces=0,paths=0},
        destination=nil,body=nil,points={},index=1,epoch=0,keyEpoch=0,
        lastReason="IDLE",lastFailure=nil,gait="STOP",nativeInput="UNTESTED",
        preferredStrategy="WORLD",steeringStrategy="WORLD",lastMode="WORLD",
        failures=0,replans=0,routeFailures=0,stallsInRow=0,waterRoutes=0,
        strategyChanges=0,inputVerified=false,inputAttempts=0,driveCalls=0,
        travelled=0,distance=nil,speed=0,corrections=0,segmentCount=0,arrivalRadius=8,
        lastBurstAt=-100,lastTrotAt=-100,nextRouteAt=0,closed=false}
    local bindings={W=Enum.KeyCode.W,A=Enum.KeyCode.A,S=Enum.KeyCode.S,
        D=Enum.KeyCode.D,SHIFT=Enum.KeyCode.LeftShift,X=Enum.KeyCode.X,Z=Enum.KeyCode.Z}
    local codes={W=0x57,A=0x41,S=0x53,D=0x44,SHIFT=0xA0,X=0x58,Z=0x5A}
    local function send(name,on,backend)
        n.synthetic[name]=os.clock()
        if backend~="EXECUTOR" then
            local ok,v=pcall(function()return game:GetService("VirtualInputManager")end)
            if ok and v and pcall(v.SendKeyEvent,v,on,bindings[name],false,game) then return true,"VIRTUAL" end
        end
        local fn=on and keypress or keyrelease
        if type(fn)=="function" and pcall(fn,codes[name]) then return true,"EXECUTOR" end
        return false,"UNAVAILABLE"
    end
    function n:hold(name,on)
        if not bindings[name] then return false end
        if (self.held[name]==true)==on then return true end
        local ok,method=send(name,on,self.backends[name] or self.gaitBackends[name] or self.keyBackend)
        if on and ok then
            self.held[name]=true;self.backends[name]=method
            self.nativeInput=method;self.inputAttempts+=1
        elseif not on then self.held[name]=nil;self.backends[name]=nil end
        return ok
    end
    function n:tap(name)
        if self.held[name] or not self:hold(name,true) then return false end
        local epoch=self.keyEpoch
        task.delay(.09,function() if self.keyEpoch==epoch then self:hold(name,false) end end)
        return true
    end
    function n:retryInput(name)
        if type(keypress)~="function" or type(keyrelease)~="function" then return false end
        self:hold(name,false);self.gaitBackends[name]="EXECUTOR"
        return true
    end
    function n:releaseSteering()
        for _,key in ipairs({"W","A","S","D"}) do self:hold(key,false) end
    end
    function n:releaseKeys()
        self.keyEpoch+=1
        local keys={}
        for k in pairs(self.held) do table.insert(keys,k) end
        for _,k in ipairs(keys) do self:hold(k,false) end
    end
    n.gaits=Gait.controller(n)
    function n:stop(hum,root,reason)
        local active=self.desiredPoint~=nil or self.destination~=nil
        if active and reason=="at territory" and self.model and self.costPoint and self.goalOrigin and not self.costRecorded then
            self.model:record(p2(self.goalOrigin),self.costPoint,math.max(.1,(self.lastAt or 0)-(self.goalStarted or 0)),self.lastAt or 0,false,self.costPurpose,true)
            self.costRecorded=true
        end
        if active and self.model and self.goalOrigin and self.destination and not self.costRecorded
            and ((self.routeFailures or 0)>=4 or (self.stallsInRow or 0)>=3) then
            self.model:record(p2(self.goalOrigin),self.costPoint or p2(self.destination),math.max(1,(self.lastAt or 0)-(self.goalStarted or 0)),self.lastAt or 0,true,self.costPurpose)
            self.costRecorded=true
        end
        self.epoch+=1;self.pending=nil
        self.desiredPoint,self.desiredRoot,self.desiredHum=nil,nil,nil
        local sameBody=not self.bodyRoot or self.bodyRoot==root
        if active then self.gaits:stop(sameBody and self.lastState or nil,self.lastAt or 0) end
        self:releaseKeys();self.gait="STOP"
        if active and sameBody and hum then pcall(hum.Move,hum,Vector3.zero,false) end
        self.destination,self.body,self.identity=nil,nil,nil
        self.points,self.index={},1;self.lastPosition=nil
        self.lastReason=reason or "IDLE"
    end
    function n:reset(destination,char,now,identity)
        self.epoch+=1;self.pending=nil
        self.destination,self.body,self.identity=destination,char,identity
        self.points,self.index={},1;self.nextRouteAt=now
        self.desiredPoint=nil;self:releaseSteering()
        self.lastProgressAt=now;self.lastPosition=nil;self.lastSampleAt=now
        self.windowAt=now;self.windowOrigin=nil;self.windowTravel=0
        self.stallsInRow,self.routeFailures,self.corrections=0,0,0
        self.inputVerified=false;self.steeringStrategy=self.preferredStrategy
        self.recoveryProgress=0;self.overlapAt=nil;self.overlapParts=nil
        self.detourUntil=nil;self.lastObstacleProbe=nil
        self.lastReason="NEW_ROUTE";self.goalStarted=now
        self.routeTravel=0;self.safetyBlockedUntil=nil;self.lastSafety=nil
        self.goalOrigin=nil;self.costRecorded=false;self.trajectory={};self.bestGoalDistance=nil
    end
    function n:surface(pos,char,allowWater)
        self.operations.surfaces+=1
        local cacheKey=string.format("%.1f:%.1f:%.1f:%s",pos.X,pos.Y,pos.Z,tostring(allowWater))
        local cache=self.surfaceCache and self.surfaceCache[cacheKey]
        if cache then return cache.point,cache.wet end
        local params=rayParams(char)
        local root=char and type(char.FindFirstChild)=="function" and char:FindFirstChild("HumanoidRootPart")
        local originY=root and root.Position.Y or pos.Y
        -- Prefer the real terrain under tall foliage. A low supporting solid
        -- surface may override it for rocks, bridges and constructed ground.
        local terrainParams=rayParams(char)
        terrainParams.FilterType=Enum.RaycastFilterType.Include
        terrainParams.FilterDescendantsInstances={self.workspace.Terrain}
        self.operations.rays+=2
        local terrain=self.workspace:Raycast(Vector3.new(pos.X,math.max(pos.Y,originY)+100,pos.Z),Vector3.new(0,-420,0),terrainParams)
        local solid=self.workspace:Raycast(Vector3.new(pos.X,originY+12,pos.Z),Vector3.new(0,-420,0),params)
        local hit=terrain or solid
        if solid and solid.Normal.Y>=.46 and solid.Position.Y<=originY+5
            and (not terrain or solid.Position.Y>terrain.Position.Y+.4) then hit=solid end
        if not hit then return nil end
        local wet=hit.Material==Enum.Material.Water
        if wet and not allowWater or not wet and hit.Normal.Y<(self.minGroundNormal or .46) then return nil end
        local position=hit.Position+Vector3.new(0,2.5,0)
        if self.surfaceCache then self.surfaceCache[cacheKey]={point=position,wet=wet} end
        return position,wet
    end
    function n:bodyClear(from,to,char)
        local direction=to-from
        if direction.Magnitude<.1 then return true end
        -- Sweeps omit shapes already touching their start volume. Check the
        -- actual animal root separately and allow movement out of an overlap.
        if self.bodyRoot and type(self.workspace.GetPartsInPart)=="function" and OverlapParams then
            local at=self.lastAt or 0
            if not self.overlapAt or at-self.overlapAt>.4 then
                self.overlapAt=at
                local params=OverlapParams.new()
                params.FilterType=Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances={char};params.RespectCanCollide=true;params.MaxParts=12
                self.operations.overlaps=(self.operations.overlaps or 0)+1
                local ok,parts=pcall(self.workspace.GetPartsInPart,self.workspace,self.bodyRoot,params)
                self.overlapParts=ok and parts or {}
            end
            for _,part in ipairs(self.overlapParts or {}) do
                if part.CanCollide~=false and part.Position then
                    local away=Vector3.new(from.X-part.Position.X,0,from.Z-part.Position.Z)
                    if away.Magnitude>.05 and direction:Dot(away)<0 then
                        self.lastObstacle={Instance=part};return false
                    end
                end
            end
        end
        if type(self.workspace.Blockcast)=="function" and CFrame and type(CFrame.lookAt)=="function" then
            local params=rayParams(char);params.IgnoreWater=true
            local size=Vector3.new((self.clearance or 2)*1.9,self.bodyHeight or 2,self.bodyLength or 4)
            self.operations.sweeps=(self.operations.sweeps or 0)+1
            local ok,hit=pcall(self.workspace.Blockcast,self.workspace,CFrame.lookAt(from,from+direction),size,direction,params)
            if ok and hit and (not hit.Instance or hit.Instance.CanCollide~=false) then
                self.lastObstacle=hit;return false
            end
        end
        return true
    end
    function n:clearSegment(from,to,char,allowWater,precise)
        self.lastSafety=nil
        local distance=flat(from,to)
        if distance<.1 then return true,false end
        local params=rayParams(char);params.IgnoreWater=true
        if not self:bodyClear(from,to,char) then return false,false end
        -- Terrain walls are obstacles too; never exempt Terrain from this ray.
        self.operations.rays+=3
        local hit=self.workspace:Raycast(from+Vector3.new(0,1.5,0),to-from,params)
        if hit and (not hit.Instance or hit.Instance.CanCollide~=false) then return false,false end
        local perpendicular=Vector3.new(-(to.Z-from.Z)/distance,0,(to.X-from.X)/distance)
        for _,side in ipairs({-1,1}) do
            local offset=perpendicular*(self.clearance or 2)*side
            local flank=self.workspace:Raycast(from+Vector3.new(0,1.5,0)+offset,to-from,params)
            if flank and (not flank.Instance or flank.Instance.CanCollide~=false) then return false,false end
        end
        local wet=false;local previous={}
        local steps=math.max(1,math.ceil(distance/(precise and 1 or 3)))
        for step=0,steps do
            local p=from+(to-from)*(step/steps)
            local center
            for _,side in ipairs({0,-1,1}) do
                local offset=perpendicular*(self.clearance or 2)*.8*side
                local ground,water=self:surface(p+offset,char,allowWater)
                if not ground then self.lastSafety="MISSING_SUPPORT";return false,wet end
                if side==0 then center=ground end
                if not previous[side] and from.Y-ground.Y>(self.supportHeight or 5)+(self.maxDrop or 3) then
                    self.lastSafety="UNSUPPORTED_DROP";return false,wet
                end
                if previous[side] then
                    local rise=ground.Y-previous[side].Y
                    if rise>(self.maxStepUp or 3) or -rise>(self.maxDrop or 3) then
                        self.lastSafety=rise>0 and "STEEP_ASCENT" or "UNSAFE_DESCENT"
                        return false,wet
                    end
                end
                if center and math.abs(ground.Y-center.Y)>math.max(self.maxDrop or 3,self.maxStepUp or 3) then
                    self.lastSafety="UNSUPPORTED_BODY_EDGE";return false,wet
                end
                previous[side]=ground;wet=wet or water
            end
        end
        return true,wet
    end
    function n:detour(root,char,state,now)
        local delta=self.destination-root.Position
        local d=flat(self.destination,root.Position)
        if d<.1 then return false end
        local base=Vector3.new(delta.X/d,0,delta.Z/d)
        local span=math.clamp((self.clearance o