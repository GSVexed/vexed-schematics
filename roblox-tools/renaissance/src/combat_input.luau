-- One bounded retry of the user's bite after an owned Rest exit. Native guards stay intact.
local CombatInput = {}
function CombatInput.new(bridge,policy,ledger)
    local c = { pending=nil }
    function c:cancel() self.pending=nil end
    function c:input(s,now)
        if not s.alive or not policy:restLocked(now,bridge:restLock(s.char)) then return end
        self.pending={char=s.char,generation=s.generation,
            at=math.max(now+.025,policy.lastRestRelease+bridge:restLock(s.char)+.035),untilAt=now+1.6}
        ledger:event("bite_waiting_for_rest_exit",now)
    end
    function c:tick(s,now)
        local p=self.pending
        if not p then return end
        if not s.alive or p.char~=s.char or p.generation~=s.generation or now>p.untilAt
            or s.chat or s.gameMenu or s.feeding or s.captured or s.holding or s.ability then self:cancel();return end
        if now<p.at then return end
        self.pending=nil -- clear before the native function can emit a marker
        local called=bridge:tryNativeBite(now)
        ledger:event("native_bite_buffer_released",now,{called=called==true,damageAcceptance="unverified"})
    end
    return c
end
return CombatInput
