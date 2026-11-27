-- Original WolfController.tryBite is the preferred dispatch. Never inject BiteHit,
-- synthesize hit replies, or infer accepted damage from a local bite sound.
-- A guarded physical-input fallback is used only for *held* human input when
-- the private callback is unavailable; never for passive/automatic attacks.
local CombatInput = {}
function CombatInput.new(bridge,policy,ledger)
    local c = {
        pending=nil, held=nil, awaiting=nil, nextAttempt=0, markerCount=0,
        status="native input", fallbackMisses=0, unavailableUntil=0,
        speedFactor=.62, goodStreak=0, suspectStreak=0,
        lastRateChange=-math.huge, lastMarker=nil, lastDispatch=0,
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
        if self.awaiting and self.awaiting.backend=="INPUT"
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
        -- The generated M1 pulses and ordinary manual clicks never replace
        -- the independent Alt hold. The game's M1 handler still runs normally.
        if kind=="M1" and self.held and self.held.key=="ALT" then return end
        self.held={char=s.char,generation=s.generation,key=kind or "mouse",source="event",input=inputObject}
        self.nextAttempt=math.max(self.nextAttempt,now+.025)
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
        local physical=s.attackHeld==true
        local alt=s.altBiteHeld==true
        if not options.repeatHeld then
            if self.held then self:release(nil,now) end
        elseif alt and (not self.held or self.held.char~=s.char or self.held.generation~=s.generation
            or self.held.key~="ALT") then
            -- Recover missing ALT InputBegan without relying on generated M1.
            self.held={char=s.char,generation=s.generation,key="ALT",source="altPoll"}
            self.nextAttempt=math.max(self.nextAttempt,now+.025)
        elseif self.held and self.held.key=="ALT"
            and s.altBiteKnown~=false and not alt then
            -- ALT release stops repeat even if InputEnded was lost.
            self:release("ALT",now)
        elseif physical and (not self.held or self.held.char~=s.char or self.held.generation~=s.generation) then
            -- Restore a missed InputBegan (e.g. hub enabled after M1 went down).
            self.held={char=s.char,generation=s.generation,key="poll",source="poll"}
            self.nextAttempt=math.max(self.nextAttempt,now+.025)
        elseif self.held and (self.held.char~=s.char or self.held.generation~=s.generation
            or self.held.source=="poll" and not physical) then
            self:release(nil,now)
        end
        local inGrab=s.grab==true or options.minigameBusy==true
        local nativeGrabLane=inGrab and options.nativeMinigame==true
            and self.held~=nil and (self.held.key=="M1" or self.held.key=="poll" or self.held.key=="ALT")
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
        local p=self.pending
        if p and (p.char~=s.char or p.generation~=s.generation or now>p.untilAt
            or bridge:attribute(s.char,"WolfBiteAt")~=p.marker) then
            self.pending=nil;p=nil
        end
        local held=options.repeatHeld and self.held~=nil
        local automatic=not inGrab and options.automatic and options.targetValid==true
        if inGrab and not nativeGrabLane then automatic=false end
        if not p and not held and not automatic then
            self.awaiting=nil;return
        end
        if s.feeding or s.captured or s.holding or s.ability or s.rest then
            self.pending=nil
            if type(bridge.releaseSyntheticBite)=="function" then bridge:releaseSyntheticBite() end
            self.status="native action lock; hold retained"
            return
        end
        local waiting=self.awaiting
        if waiting and (waiting.char~=s.char or waiting.generation~=s.generation) then
            self.awaiting=nil;waiting=nil
        end
        if waiting then
            if now-waiting.at<math.max(.18,bridge:biteDelay(s.char)+.10) then return end
            self.awaiting=nil
            self.nextAttempt=math.max(self.nextAttempt,now+.18)
            if waiting.backend=="INPUT" and type(bridge.noteHeldInputTimeout)=="function" then
                bridge:noteHeldInputTimeout()
            end
            self.fallbackMisses+=waiting.backend=="INPUT" and 1 or 0
            if self.fallbackMisses>=3 then
                self.unavailableUntil=now+2.5
                self.fallbackMisses=0
            end
            self.status="no native marker; checking original game cooldown"
            ledger:event("native_bite_marker_timeout",now,{backend=waiting.backend})
            return
        end
        if now<self.nextAttempt or p and now<p.at or now<self.unavailableUntil then return end
        if held and not (bridge.wolfActions and type(bridge.wolfActions.tryBite)=="function")
            and type(bridge.nativeWolfActions)=="function" then
            -- The input-event connection path may be unavailable in the
            -- executor's VM even when the original WolfController closure is
            -- discoverable via getgc. Request validation only while held.
            bridge.wantHeldNativeDiscovery=true
            bridge:nativeWolfActions(now)
        end
        local readiness=bridge:biteReadiness(s,now,policy)
        local allowed=readiness.ready
        -- If a game's original callback is private, visible cooldown + own
        -- BiteAt marker still offer a bounded path for held user input.
        -- This path never enables Auto Bite or ignores a known Rest/minigame lock.
        local privateUnknown=not readiness.known
            and (readiness.reason=="native timing unavailable"
                or readiness.reason=="native timing layout unknown")
        if not allowed and privateUnknown and held and not automatic then
            -- Keep the verified original function in charge when available.
            -- When private, Alt can use ordinary game input only in a visible
            -- stock-cooldown window and never during minigames.
            local original=bridge.wolfActions and bridge.wolfActions.tryBite
            if type(original)=="function" and (not inGrab or nativeGrabLane) then
                allowed=true
            elseif self.held and self.held.key=="ALT" and not inGrab then
                allowed=type(bridge.visibleBiteWindow)=="function" and bridge:visibleBiteWindow(s,now) or false
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
        local native=bridge.wolfActions and bridge.wolfActions.tryBite
        local fallback=type(native)~="function" and held and not automatic and not inGrab
            and self.held and self.held.key=="ALT"
        -- Never reset a genuinely physically held M1. Native callback is
        -- safe with either trigger; only Alt owns synthetic input replay.
        if fallback and (s.mouseHeld or s.r2Held) then
            self.status="release left mouse while using Alt repeat fallback"
            self.nextAttempt=now+.12
            return
        end
        if type(native)~="function" and not fallback then
            self.nextAttempt=now+.12
            self.status="original native bite callback unavailable; hold Left Alt for input fallback"
            return
        end
        -- A validated original callback or a bounded Alt input request is
        -- required before recording an actual dispatch. Preserve pending
        -- Rest-exit intent until one of those paths can be attempted.
        self.pending=nil
        self.lastDispatch=now
        local markers=self.markerCount
        -- 16.1.4 adaptive factor applies to both native and Alt-input
        -- requests, without bypassing the unchanged game's cooldown.
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
        if type(native)=="function" then
            called,backend=bridge:tryNativeBite(now),"NATIVE"
        else
            called,backend=bridge:tryHeldInputBite(s,now),"INPUT"
        end
        local marked=self.markerCount>markers
        if called and not marked then
            self.awaiting={char=s.char,generation=s.generation,at=now,backend=backend}
        end
        if not called then self.nextAttempt=math.max(self.nextAttempt,now+.3) end
        self.status=marked and "native marker; awaiting server-confirmed impact"
            or called and (backend=="INPUT" and "Alt input requested; awaiting actual game bite marker"
                or "original native callback requested; awaiting marker")
            or "original native attack dispatcher unavailable"
        ledger:event(p and "native_bite_buffer_released" or "native_cadence_attempt",now,{
            called=called==true,marker=marked,backend=backend,automatic=automatic==true,
            minigameNative=nativeGrabLane==true,
            damageAcceptance="unverified"})
    end
    return c
end
return CombatInput
