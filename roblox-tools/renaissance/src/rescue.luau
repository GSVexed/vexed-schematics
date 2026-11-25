-- Manual G assistance for native-sized friendly cubs in water. No remote success is inferred.
local Rescue = {}
function Rescue.new(bridge,ledger)
    local r = { pending=nil,status="G: normal carry/drop; water cub rescue",nextAt=0 }
    function r:cancel(reason)
        self.pending=nil
        if reason then self.status=reason end
    end
    function r:input(s,now)
        if self.pending then self:cancel("Cub rescue cancelled");return true end
        if now<self.nextAt or not s.alive or s.chat or s.gameMenu or s.holding or s.captured or s.feeding or s.grab
            or s.ability or s.flying or s.climbing then return false end
        local target=bridge:waterCub(s)
        if not target then return false end -- leave ordinary native G untouched
        self.nextAt=now+.6
        self.pending={char=s.char,generation=s.generation,target=target,untilAt=now+2.6}
        self.status="Water cub selected; waiting for native pickup conditions"
        return true
    end
    function r:tick(s,now)
        local p=self.pending
        if not p then return end
        if not s.alive or p.char~=s.char or p.generation~=s.generation then self:cancel("Cub rescue animal changed");return end
        if bridge:carrying(s,p.target.char) then
            ledger:event("native_cub_carry_observed",now)
            self:cancel("Native cub carry observed")
            return
        end
        if not s.alive or p.char~=s.char or p.generation~=s.generation or s.chat or s.gameMenu
            or s.captured or s.grab or s.feeding or s.attackHeld or s.ability or now>p.untilAt then
            self:cancel(p.sent and "No native carry observed; game water rules may block pickup" or "Cub rescue ended; move to the bank and use G")
            return
        end
        s.rescuing=true
        if p.sent then return end
        if not bridge:carryEligible(s,p.target) then self:cancel("Cub is no longer eligible or in native reach");return end
        if not bridge:carryWaterAllowed(s) then
            if not p.jump then
                p.jump=true
                s.hum.Jump=true -- one ordinary jump request; no swim-flag or position spoof
                ledger:event("cub_rescue_jump_requested",now)
            end
            self.status="Native water lock; jump or move to the bank"
            return
        end
        p.sent=bridge:fire("FeralLunge","carry",p.target.char)
        p.untilAt=now+1.3
        self.status=p.sent and "Pickup requested; waiting for native carry" or "Native pickup unavailable"
        ledger:event("native_cub_pickup_requested",now,{sent=p.sent==true,carryAcceptance="unverified"})
        if not p.sent then self.pending=nil end
    end
    return r
end
return Rescue
