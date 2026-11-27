-- Original WolfController.tryBite is the preferred dispatch. Never inject BiteHit,
-- synthesize hit replies, or infer accepted damage from a local bite sound.
-- A guarded physical-input fallback is used only for *held* human input when
-- the private callback is unavailable; never for passive/automatic attacks.
local CombatInput = {}
function CombatInput.new(bridge,policy,ledger)
    local middleMode=bridge.holdBinding=="M3"
    local c = {
        pending=nil, held=nil, awaiting=nil, nextAttempt=0, markerCount=0,
        status="native input", fallbackMisses=0, unavailableUntil=0,
        speedFactor=.62, goodStreak=0, suspectStreak=0,
        lastRateChange=-math.huge, lastMarker=nil, lastDispatch=0,
        nativeMisses=0,middleCandidate=middleMode and bridge.middleRoutePreference~="NATIVE" and "INPUT" or nil,middleRoute=nil,
        middleRouteMarkers=0,middleNativeAttempts=0,middleInputAttempts=0,
    }
    local function stopDiscovery()
        bridge.wantHeldNativeDiscovery=false
        -- A cancelled, unfinished lookup has not established unavailability.
        -- A fresh press may restart it; completed negative searches retain
        -- the bridge's normal retry backoff.
        if bridge.wolfHeapScan then bridge.nextWolfHeapScan=0 end
        bridge.wolfHeapScan=nil
    end
    function c:factor()
        return self.speedFactor
    end
    function c:resetRate()
        self.speedFactor,self.goodStreak,self.suspectStreak=.62,0,0
        self.lastRateChange=-math.huge
    end
    -- Feedback changes only the requested local timing, never server outcomes.
    -- A confirmed, uniquely matched positive damage response is the only
    -- evidence that permits accelerating below the initial 62% cadence.
    function c:confirmed(now)
        self.suspectStreak=0
        self.goodStreak+=1
        if self.goodStreak>=3 and now-self.lastRateChange>=1.8 then
            self.speedFactor=math.max(.55,math.floor((self.speedFactor-.025)*1000+.5)/1000)
            self.lastRateChange=now
            self.goodStreak=0
            ledger:event("cadence_confidence_increased",now,{factor=self.speedFactor})
        end
    end
    -- Three *clean* stock-range contact windows without verified damage
    -- may indicate server cadence rejection, so slow down rather than spam.
    function c:suspect(now)
        self.goodStreak=0
        self.suspectStreak+=1
        if self.suspectStreak>=3 and now-self.lastRateChange>=1 then
            self.speedFactor=math.min(1,math.floor((self.speedFactor+.08)*1000+.5)/1000)
            self.lastRateChange=now
            self.suspectStreak=0
            ledger:event("cadence_backoff",now,{factor=self.speedFactor})
        end
    end
    function c:cancel()
        self.pending,self.held,self.awaiting=nil,nil,nil
        stopDiscovery()
        if type(bridge.releaseSyntheticBite)=="function" then bridge:releaseSyntheticBite() end
        self.nextAttempt=0
    end
    -- Temporary native action transitions must not discard an accepted M3
    -- press. Hard cancellation is reserved for release, focus, UI, OFF,
    -- manual Rest, or loss of the current animal.
    function c:pause(reason,now)
        if not middleMode or not self.held or self.held.key~="M3" then
            self:cancel()
            return
        end
        self.pending,self.awaiting=nil,nil
        stopDiscovery()
        if type(bridge.releaseSyntheticBite)=="function" then bridge:releaseSyntheticBite() end
        self.nextAttempt=math.max(self.nextAttempt,now+.20)
        self.status=reason.." · middle hold retained"
    end
    -- Standard input is the production M3 route. Explicit native compatibility
    -- mode may probe only until its first attributable marker.
    function c:noteNativeMiss(now)
        if not middleMode or not self.held or self.held.key~="M3" then return end
        self.nativeMisses=math.min(3,self.nativeMisses+1)
        if self.nativeMisses>=3 then
            if not self.middleRoute and self.middleCandidate=="NATIVE"
                and type(bridge.hasHeldInputBackend)=="function" and bridge:hasHeldInputBackend() then
                self.middleCandidate="INPUT"
                stopDiscovery()
                ledger:event("m3_initial_route_probe_changed",now,{route="INPUT"})
            else
                -- A verified route may pause but never hands off to another method.
                self.nextAttempt=math.max(self.nextAttempt,now+.4)
            end
        end
    end
    function c:manualAttack(now)
        if middleMode and self.awaiting and self.awaiting.middle then
            self.awaiting=nil
            self.nextAttempt=math.max(self.nextAttempt,now+.12)
        end
    end
    function c:confirmMiddleRoute(waiting,s,now)
        if not middleMode or not waiting or not waiting.middle or not self.held
            or self.held.key~="M3" or self.held.char~=s.char
            or self.held.generation~=s.generation or waiting.char~=s.char
            or waiting.generation~=s.generation then return end
        local route=waiting.backend
        if route~="NATIVE" and route~="INPUT" then return end
        if route=="NATIVE" and (s.mouseHeld or s.r2Held) then return end
        if route=="INPUT" and not bridge.heldInputBackend then return end
        if self.middleRoute and self.middleRoute~=route then return end
        if not self.middleRoute then
            self.middleRoute,self.middleCandidate=route,route
            self.middleVerifiedAt=now
            if route=="INPUT" then bridge.heldInputLockedBackend=bridge.heldInputBackend end
            ledger:event("m3_route_verified_and_locked",now,{route=route,adapter=bridge.heldInputLockedBackend})
        end
        self.middleRouteMarkers+=1
    end
    function c:middleReport()
        return {binding=bridge.desktopLeftHold and "LMB_DESKTOP" or middleMode and "M3" or "M1",route=self.middleRoute,
            candidate=self.middleCandidate,verifiedAt=self.middleVerifiedAt,
            attributableMarkers=self.middleRouteMarkers,nativeAttempts=self.middleNativeAttempts,
            inputAttempts=self.middleInputAttempts,adapter=bridge.heldInputLockedBackend,
            held=self.held~=nil,status=self.status,admission=self.middleAdmission,
            inputBlockReason=bridge.heldInputBlockReason,feedGuardPulses=bridge.feedGuardPulses or 0,
            serverDamageVerified=false}
    end
    function c:release(kind,now)
        if self.held and (kind==nil or self.held.key==kind or self.held.key=="poll") then
            -- A single tap made during an owned Rest-exit window must still
            -- deliver its one buffered native bite after M1/R2 is released.
            -- Only the continuous repeat intent stops on InputEnded.
            self.held,self.awaiting=nil,nil
            stopDiscovery()
            if type(bridge.releaseSyntheticBite)=="function" then bridge:releaseSyntheticBite() end
            self.nextAttempt=now or 0
            self.status=self.pending and "one Rest-exit bite queued" or "released"
        end
    end
    function c:marker(s,now)
        local waiting=self.awaiting
        self:confirmMiddleRoute(waiting,s,now)
        if waiting and waiting.backend=="NATIVE" and (not middleMode or self.middleRoute=="NATIVE") then self.nativeMisses=0 end
        if waiting and waiting.backend=="INPUT"
            and (not middleMode or self.middleRoute=="INPUT")
            and type(bridge.noteHeldInputMarker)=="function" then
            bridge:noteHeldInputMarker()
        end
        self.pending,self.awaiting=nil,nil
        self.lastMarker=now
        self.markerCount+=1
        self.fallbackMisses=0
        self.unavailableUntil=0
        self.status="native bite marker observed; impact unverified"
    end
    function c:input(s,now,kind,inputObject)
        if not s.alive then return end
        if middleMode then
            if kind=="M3" then
                if self.held and self.held.key=="M3" and self.held.char==s.char
                    and self.held.generation==s.generation then return end
                self.held={char=s.char,generation=s.generation,key="M3",
                    source="event",input=inputObject,startedAt=now,handoff=true}
                self.fallbackMisses,self.unavailableUntil=0,0
                self.nextAttempt=math.max(self.nextAttempt,now+.025)
                self.status="middle mouse held"
                ledger:event("physical_m3_hold_started",now)
                return
            end
        else
            -- The first genuine M1 click belongs entirely to the game. Only
            -- after one uninterrupted hold crosses the tap/hold threshold does
            -- the hub take over repeating. New taps always start a fresh timer.
            self.held={char=s.char,generation=s.generation,key=kind or "mouse",
                source="event",input=inputObject,startedAt=now,handoff=kind=="R2"}
            self.nextAttempt=math.max(self.nextAttempt,now+.025)
        end
        if not policy:restLocked(now,bridge:restLock(s.char)) then return end
        local at=math.max(now+.025,policy.lastRestRelease+bridge:restLock(s.char)+.035)
        self.pending={char=s.char,generation=s.generation,at=at,untilAt=math.max(now+1.6,at+.35),
            marker=bridge:attribute(s.char,"WolfBiteAt"),input=inputObject}
        policy.attackUntil=math.max(policy.attackUntil,at+.3)
        ledger:event("bite_waiting_for_rest_exit",now)
    end
    function c:tick(s,now,options)
        options=options or {}
        if options.inputSuspended then
            self:cancel()
            self.status="input suspended; waiting for a fresh press"
            return
        end
        if middleMode then
            -- Fresh world InputBegan owns M3. Polling only revokes stale ownership.
            if self.held then
                if s.middleHeldKnown and s.middleHeld then
                    self.held.seenDown=true;self.held.upSince=nil
                elseif s.middleHeldKnown and self.held.seenDown then
                    self.held.upSince=self.held.upSince or now
                end
                if not options.repeatHeld or self.held.char~=s.char
                    or self.held.generation~=s.generation
                    or self.held.upSince and now-self.held.upSince>.35 then
                    self:release("M3",now)
                elseif self.held.upSince then
                    -- Stop dispatch immediately on an uncertain physical release,
                    -- but keep the press through a short polling dropout.
                    if type(bridge.releaseSyntheticBite)=="function" then bridge:releaseSyntheticBite() end
                    self.awaiting=nil
                    self.status="middle button temporarily unconfirmed"
                    return
                end
            end
        else
            local physical=s.attackHeld==true
            if not options.repeatHeld then
                if self.held then self:release(nil,now) end
            elseif physical and not bridge.syntheticM1
                and now>=(bridge.syntheticM1Until or 0)
                and (not self.held or self.held.char~=s.char or self.held.generation~=s.generation) then
                -- Hub enabled after M1 was already pressed: wait a fresh hold
                -- threshold before dispatching repeats.
                self.held={char=s.char,generation=s.generation,key="poll",source="poll",
                    startedAt=now,handoff=false}
                self.nextAttempt=math.max(self.nextAttempt,now+.025)
            elseif self.held and (self.held.char~=s.char or self.held.generation~=s.generation
                or self.held.source=="poll" and not physical) then
                self:release(nil,now)
            end
            -- The real InputBegan object, not a potentially unreliable native
            -- mouse-down poll, owns this hold until its actual InputEnded.
            -- Focus loss, UI, ability/Rest and hub unload still revoke it.
            if self.held and not self.held.handoff and
                (self.held.key=="M1" or self.held.key=="poll") then
                local age=now-(self.held.startedAt or now)
                if age>=.28 then
                    self.held.handoff=true
                    self.nextAttempt=math.max(self.nextAttempt,now+.015)
                    ledger:event("physical_m1_hold_handoff",now,{age=age})
                end
            end
        end
        local inGrab=s.grab==true or options.minigameBusy==true
        local nativeGrabLane=inGrab and options.nativeMinigame==true
            and self.held~=nil and (self.held.key=="M3" or self.held.key=="M1" or self.held.key=="poll")
            and (not middleMode or (self.middleRoute or self.middleCandidate)~="INPUT")
            and options.minigamePressNear~=true
            and bridge.wolfActions and type(bridge.wolfActions.tryBite)=="function"
        if not s.alive or s.chat or s.gameMenu or inGrab and not nativeGrabLane
            or policy.manualRest or options.uiBlocked then
            self.pending,self.awaiting=nil,nil
            stopDiscovery()
            if type(bridge.releaseSyntheticBite)=="function" then bridge:releaseSyntheticBite() end
            -- Preserve the event-held state across a *known* minigame, so
            -- continuing to hold resumes after its native end. OFF and
            -- InputEnded always clear it; menus/text clear it immediately.
            -- Hovering over an existing hub window pauses attacks, but does
            -- not revoke an M1 that began in the world. An actual UI press
            -- cancels ownership in Controller.preInput, and InputEnded clears
            -- it even while hovering. This prevents one hover from ending a
            -- continuous real hold until the user clicks again.
            if not s.alive or s.chat or s.gameMenu then self.held=nil end
            self.nextAttempt=now+.12
            self.status=(options.minigameBusy or s.grab) and "minigame has priority" or "native action has priority"
            return
        end
        if middleMode and bridge.syntheticM1 then return end
        local p=self.pending
        if p and (p.char~=s.char or p.generation~=s.generation or now>p.untilAt
            or bridge:attribute(s.char,"WolfBiteAt")~=p.marker) then
            self.pending=nil;p=nil
        end
        local held=options.repeatHeld and self.held~=nil and self.held.handoff==true
            and (not middleMode or inGrab or not (s.mouseHeld or s.r2Held))
        -- Holding M1 explicitly takes priority over Auto Bite target
        -- selection. Ordinary clicks before the handoff remain game-owned.
        local automatic=not inGrab and options.automatic and options.targetValid==true
            and self.held==nil and (not middleMode or not (s.mouseHeld or s.r2Held))
        if inGrab and not nativeGrabLane then automatic=false end
        if not p and not held and not automatic then
            -- A quick manual tap is never repeated by this controller.
            -- No callback/simulated mouse edge is dispatched until handoff.
            self.awaiting=nil
            self.status=self.held and (middleMode and "manual attack has priority" or "manual M1 tap; waiting for sustained hold") or "idle"
            return
        end
        if s.feeding or s.captured or s.holding or s.ability or s.rest then
            self.pending=nil
            if middleMode then self.awaiting=nil end
            if type(bridge.releaseSyntheticBite)=="function" then bridge:releaseSyntheticBite() end
            self.status="native action lock; hold retained"
            return
        end
        local waiting=self.awaiting
        if waiting and (waiting.char~=s.char or waiting.generation~=s.generation) then
            self.awaiting=nil;waiting=nil
        end
        if waiting then
            if middleMode and waiting.backend=="INPUT" and bridge.heldInputBlockReason then
                self.awaiting=nil
                self.nextAttempt=math.max(self.nextAttempt,now+.12)
                self.status="M3 held; "..bridge.heldInputBlockReason
                return
            end
            if now-waiting.at<math.max(.18,bridge:biteDelay(s.char)+.10) then return end
            self.awaiting=nil
            self.nextAttempt=math.max(self.nextAttempt,now+.18)
            if waiting.backend=="INPUT" and type(bridge.noteHeldInputTimeout)=="function" then
                bridge:noteHeldInputTimeout()
            end
            if waiting.backend=="NATIVE" and not inGrab then self:noteNativeMiss(now) end
            self.fallbackMisses+=(waiting.backend=="NATIVE_INPUT" or waiting.backend=="INPUT") and 1 or 0
            if self.fallbackMisses>=3 then
                self.unavailableUntil=now+2.5
                self.fallbackMisses=0
            end
            self.status="no native marker; checking original game cooldown"
            ledger:event("native_bite_marker_timeout",now,{backend=waiting.backend})
            return
        end
        if now<self.nextAttempt or p and now<p.at or now<self.unavailableUntil then return end
        local middleHeld=middleMode and held and self.held.key=="M3"
        if held and (not middleHeld or (self.middleRoute or self.middleCandidate)~="INPUT")
            and not (bridge.wolfActions and type(bridge.wolfActions.tryBite)=="function")
            and type(bridge.nativeWolfActions)=="function" then
            -- The input-event connection path may be unavailable in the
            -- executor's VM even when the original WolfController closure is
            -- discoverable via getgc. Request validation only while held.
            bridge.wantHeldNativeDiscovery=true
            bridge:nativeWolfActions(now)
        end
        local route
        if middleHeld then
            route=self.middleRoute or self.middleCandidate
            if not route then
                if bridge.wolfActions and type(bridge.wolfActions.tryBite)=="function" then
                    route="NATIVE"
                elseif not inGrab and type(bridge.hasHeldInputBackend)=="function"
                    and bridge:hasHeldInputBackend() then
                    route="INPUT"
                end
                if route then
                    self.middleCandidate=route
                    ledger:event("m3_initial_route_selected",now,{route=route})
                end
            end
            if not route then
                self.status="middle held; waiting for a supported attack route"
                self.nextAttempt=now+.15
                return
            end
        end
        local desktopOrdinary=middleHeld and route=="INPUT" and not inGrab
            and self.held.source=="desktop"
            and type(bridge.desktopInputReadiness)=="function"
        local readiness=desktopOrdinary and bridge:desktopInputReadiness(s,now,policy)
            or bridge:biteReadiness(s,now,policy)
        local allowed=readiness.ready
        -- If a game's original callback is private, visible cooldown + own
        -- BiteAt marker still offer a bounded path for held user input.
        -- This path never enables Auto Bite or ignores a known Rest/minigame lock.
        local privateUnknown=not readiness.known
            and (readiness.reason=="native timing unavailable"
                or readiness.reason=="native timing layout unknown")
        if not allowed and privateUnknown and held and not automatic then
            -- The native tryBite owns its cooldown. Its private timing
            -- upvalue offsets cannot be inferred after an update. The
            -- original onInput fallback remains gated by the visible stock
            -- bite cooldown and a genuine original M1 InputObject.
            local original=bridge.wolfActions and bridge.wolfActions.tryBite
            if type(original)=="function" and route~="INPUT" and (not inGrab or nativeGrabLane) then
                allowed=true
            elseif not inGrab and self.held and ((self.held.key=="M1" and self.held.input)
                or middleMode and self.held.key=="M3") then
                allowed=type(bridge.visibleBiteWindow)=="function"
                    and bridge:visibleBiteWindow(s,now) or false
            end
        end
        if not allowed then
            self.status=readiness.reason
            self.nextAttempt=readiness.nextAt and math.max(now+.015,readiness.nextAt) or now+.08
            return
        end
        if options.beforeAttempt then
            local ok,released=pcall(options.beforeAttempt,s,now)
            if not ok or released==false then
                self.pending,self.awaiting=nil,nil
                self.nextAttempt=now+.2
                self.status="native action release not confirmed"
                ledger:event("native_bite_preparation_failed",now,{callbackSucceeded=ok})
                return
            end
        end
        -- A chosen M3 route remains exclusive. Native/manual compatibility
        -- and the separate Auto Bite feature keep their original dispatch.
        local native=bridge.wolfActions and bridge.wolfActions.tryBite
        if middleHeld and route=="INPUT" then native=nil end
        local nativeInput=not native and held and not automatic and not inGrab
            and self.held and self.held.key=="M1" and self.held.source=="event"
            and self.held.input and type(bridge.nativeWolfInputAction)=="function"
            and bridge:nativeWolfInputAction(now) or nil
        local ordinary=middleHeld and route=="INPUT" and not inGrab
            and not automatic and self.held.key=="M3"
            and not (s.mouseHeld or s.r2Held or s.physicalM1Held)
            and type(bridge.tryHeldInputBite)=="function"
            and type(bridge.visibleBiteWindow)=="function" and bridge:visibleBiteWindow(s,now)
        if type(native)~="function" and not nativeInput and not ordinary then
            self.nextAttempt=now+.12
            self.status=middleHeld and (route=="INPUT" and "ordinary route waiting for native cooldown or manual input"
                or "native route waiting for original callback")
                or "waiting for native attack handler"
            return
        end
        -- The only dispatch sources are validated original game functions.
        -- Preserve Rest-exit intent until an actual native dispatcher exists.
        self.pending=nil
        self.lastDispatch=now
        local markers=self.markerCount
        -- Keep the existing working Adaptive Faster Bites factor unchanged.
        -- It controls native-request timing, not game/server cooldown.
        local cooldown=type(bridge.nativeBiteCooldown)=="function"
            and bridge:nativeBiteCooldown(s) or nil
        local factor=options.speedEnabled and self:factor() or 1
        if type(cooldown)=="number" and cooldown==cooldown
            and cooldown>=.03 and cooldown<=30 then
            self.nextAttempt=now+math.max(.04,cooldown*factor)
        else
            self.nextAttempt=now+.065
        end
        local called,backend
        if type(native)=="function" then backend="NATIVE"
        elseif nativeInput then backend="NATIVE_INPUT"
        else backend="INPUT" end
        local attempt={char=s.char,generation=s.generation,at=now,backend=backend,middle=middleHeld==true}
        if middleHeld then
            if backend=="NATIVE" then self.middleNativeAttempts+=1
            else self.middleInputAttempts+=1 end
            -- Record before invocation: the original game can emit its marker
            -- synchronously, before the callback returns.
            self.awaiting=attempt
        end
        if backend=="NATIVE" then
            called=bridge:tryNativeBite(now)
        elseif backend=="NATIVE_INPUT" then
            called=bridge:tryNativeInputBite(now,self.held.input)
        else
            called=bridge:tryHeldInputBite(s,now)
        end
        local marked=self.markerCount>markers
        if backend=="NATIVE" and marked then self.nativeMisses=0 end
        if backend=="NATIVE" and not called and not inGrab then self:noteNativeMiss(now) end
        if called and not marked then
            self.awaiting=attempt
        elseif self.awaiting==attempt then
            self.awaiting=nil
        end
        if not called then
            self.lastDispatch=0
            self.nextAttempt=math.max(self.nextAttempt,now+.3)
        end
        self.status=marked and "native marker; awaiting server-confirmed impact"
            or called and (backend=="INPUT" and "M3 ordinary-input route; awaiting native marker"
                or backend=="NATIVE_INPUT" and "own original input handler called; awaiting native marker"
                or "original native bite callback called; awaiting marker")
            or (backend=="INPUT" and bridge.heldInputBlockReason and ("M3 held; "..bridge.heldInputBlockReason))
            or "validated native attack handler unavailable"
        ledger:event(p and "native_bite_buffer_released" or "native_cadence_attempt",now,{
            called=called==true,marker=marked,backend=backend,automatic=automatic==true,
            minigameNative=nativeGrabLane==true,
            damageAcceptance="unverified"})
    end
    return c
end
return CombatInput
