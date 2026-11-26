-- Native tryBite owns every attack and its final guards. No hit-claim injection.
local CombatInput = {}
function CombatInput.new(bridge,policy,ledger)
    local c = {pending=nil,held=nil,awaiting=nil,nextAttempt=0,markerCount=0,status="native input"}
    function c:cancel()
        self.pending,self.held,self.awaiting=nil,nil,nil
        self.nextAttempt=0
    end
    function c:marker(s,now)
        self.pending,self.awaiting=nil,nil
        self.lastMarker=now
        self.markerCount+=1
        self.status="native bite marker observed"
    end
    function c:input(s,now)
        if not s.alive then return end
        self.held={char=s.char,generation=s.generation}
        if not policy:restLocked(now,bridge:restLock(s.char)) then return end
        self.pending={char=s.char,generation=s.generation,
            at=math.max(now+.025,policy.lastRestRelease+bridge:restLock(s.char)+.035),untilAt=now+1.6}
        ledger:event("bite_waiting_for_rest_exit",now)
    end
    function c:tick(s,now,options)
        options=options or {}
        if self.held and (self.held.char~=s.char or self.held.generation~=s.generation or not s.attackHeld) then
            self.held=nil
        end
        if not s.alive or s.chat or s.gameMenu or s.grab or policy.manualRest or options.uiBlocked then
            self:cancel();return
        end
        local p=self.pending
        if p and (p.char~=s.char or p.generation~=s.generation or now>p.untilAt) then self.pending=nil;p=nil end
        local held=options.repeatHeld and self.held~=nil and s.attackHeld
        local automatic=options.automatic and options.targetValid==true
        if not p and not held and not automatic then self.awaiting=nil;return end
        -- A native ability/capture can end while the physical button remains
        -- down. Retain that intent, but do not send a bite through the lock.
        if s.feeding or s.captured or s.holding or s.ability then
            self.pending=nil
            self.status="held input waiting for native action to end"
            return
        end
        local waiting=self.awaiting
        if waiting and (waiting.char~=s.char or waiting.generation~=s.generation) then
            self.awaiting=nil;waiting=nil
        end
        if waiting then
            if now-waiting.at<math.max(.15,bridge:biteDelay(s.char)+.08) then return end
            self.awaiting=nil
            self.nextAttempt=math.max(self.nextAttempt,now+.25)
            self.status="no native bite marker; backing off"
            ledger:event("native_bite_marker_timeout",now)
            return
        end
        if now<self.nextAttempt or p and now<p.at then return end
        local readiness=bridge:biteReadiness(s,now,policy)
        if not readiness.ready then
            self.status=readiness.reason
            self.nextAttempt=readiness.nextAt and math.max(now+.015,readiness.nextAt) or now+.1
            return
        end
        if options.beforeAttempt then options.beforeAttempt(s,now) end
        -- Reserve the attempt before a synchronous native marker can re-enter.
        self.pending=nil
        self.nextAttempt=now+.1
        local markers=self.markerCount
        local called=bridge:tryNativeBite(now)
        local marked=self.markerCount>markers
        if called and not marked then self.awaiting={char=s.char,generation=s.generation,at=now} end
        self.status=marked and "native bite marker observed; damage unverified"
            or called and "native bite attempted; awaiting marker" or "native attack handle unavailable"
        ledger:event(p and "native_bite_buffer_released" or "native_cadence_attempt",now,
            {called=called==true,marker=marked,automatic=automatic==true,damageAcceptance="unverified"})
    end
    return c
end
return CombatInput
