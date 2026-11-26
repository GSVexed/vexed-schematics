-- One bounded retry of the user's bite after an owned Rest exit. Native guards stay intact.
local CombatInput = {}
function CombatInput.new(bridge,policy,ledger)
    local c = { pending=nil }
    function c:cancel() self.pending=nil end
    function c:input(s,now,input)
        if not s.alive or policy.manualRest or not policy:restLocked(now,bridge:restLock(s.char)) then return end
        local at=math.max(now+.025,policy.lastRestRelease+bridge:restLock(s.char)+.035)
        self.pending={char=s.char,generation=s.generation,input=input,
            marker=bridge:attribute(s.char,"WolfBiteAt"),at=at,untilAt=math.max(now+1.6,at+.3)}
        -- Some native profiles have a stand-up lock longer than the ordinary
        -- attack pause. Recovery must not re-arm in front of this user's bite.
        policy.attackUntil=math.max(policy.attackUntil,at+.3)
        ledger:event("bite_waiting_for_rest_exit",now)
    end
    function c:tick(s,now)
        local p=self.pending
        if not p then return end
        if not s.alive or p.char~=s.char or p.generation~=s.generation or now>p.untilAt
            or policy.manualRest or s.rest or s.chat or s.gameMenu or s.feeding or s.captured or s.holding or s.ability then self:cancel();return end
        -- Attribute listeners can be replaced or arrive after native input.
        -- The actual marker also cancels the buffer, preventing a second bite.
        if bridge:attribute(s.char,"WolfBiteAt")~=p.marker then self:cancel();return end
        if now<p.at then return end
        local ready=bridge:biteReadiness(s,now,policy)
        if ready.known and not ready.ready then
            if ready.reason=="native Rest lock" and now+.04<=p.untilAt then
                -- Wait for the *native* private stand-up state; do not invoke
                -- tryBite repeatedly or bypass its authoritative guards.
                p.at=now+.04;policy.attackUntil=math.max(policy.attackUntil,p.at+.3)
            else self:cancel() end
            return
        end
        self.pending=nil -- clear before the native function can emit a marker
        policy.attackUntil=math.max(policy.attackUntil,now+1.1)
        local called=bridge:tryNativeBite(now)
        ledger:event("native_bite_buffer_released",now,{called=called==true,
            markerObserved=bridge:attribute(s.char,"WolfBiteAt")~=p.marker,damageAcceptance="unverified"})
    end
    return c
end
return CombatInput
