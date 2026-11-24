-- A single native Rest owner. Manual Rest is never cancelled or masked.
local Recovery = {}
function Recovery.new(bridge, policy, ledger)
    local r = { state = "OFF", owned = nil, enabled = false, echoes = 0,
        backoffUntil = 0, releaseAt = -math.huge, signalAt = -math.huge,
        nativeEchoObserved = false, writes = 0, nextRefresh = 0 }
    function r:release(reason, now)
        local char = self.owned
        self.owned = nil
        if char then
            self.releaseAt, policy.lastRestRelease = now, now
            bridge:rest(char, false)
            -- Only an echo attributed to this owner's Rest request is cleared.
            if not policy.manualRest then bridge:maskRest(char) end
            ledger:event("owned_rest_released", now, { reason = reason })
        end
        self.state = reason or "OFF"
    end
    function r:manual(now)
        -- Yield ownership without emitting false; native/manual Rest takes over.
        self.owned = nil
        policy.manualRest = true
        self.state = "MANUAL"
        ledger:event("manual_rest_preserved", now)
    end
    function r:echo(s, now)
        if not s or not s.char then return end
        if self.owned == s.char and s.rest then
            if now <= policy.manualIntentUntil then self:manual(now); return end
            self.nativeEchoObserved = true
            if now-(self.echoWindow or 0) > 2 then self.echoes,self.echoWindow = 0,now end
            self.echoes += 1
            local ok = bridge:maskRest(s.char)
            if ok then self.writes += 1 end
            ledger:event("owned_rest_pose_echo", now, { locallyMasked = ok })
            if not ok or self.echoes >= 3 then
                self:release("pose recurrence; recovery paused", now)
                self.backoffUntil = now+15
            else self.state = "ECHO_OBSERVED" end
        elseif not self.owned and s.rest and now-self.releaseAt > 2.6 then
            self:manual(now)
        elseif not self.owned and s.rest and now-self.releaseAt <= 2.6
            and not policy.manualRest and now > policy.manualIntentUntil then
            bridge:maskRest(s.char)
        end
    end
    function r:tick(s, now)
        if policy.manualRest then
            if not s or not s.alive or not s.rest then
                policy.manualRest = false
                policy.manualIntentUntil = 0
                policy.lastRestRelease = now
                self.backoffUntil = math.max(self.backoffUntil, now+.75)
            else self.state = "MANUAL"; return end
        end
        if self.owned and (not s or self.owned ~= s.char) then self:release("animal changed", now) end
        if not self.enabled then self:release("OFF", now); return end
        local effects = s and (
            (type(s.injury) == "number" and s.injury > .1)
            or (type(s.bleed) == "number" and s.bleed > .1)
            or (type(s.venom) == "number" and s.venom > .1))
        self.purpose = effects and "effects" or "health"
        local allowed, reason = policy:allowed("recovery", s, now,self.purpose)
        if not allowed then self:release(reason, now); return end
        if now < self.backoffUntil then self.state = "waiting after action"; return end
        self:echo(s, now)
        if policy.manualRest or now < self.backoffUntil then return end
        -- Request only for an actual deficit. Keeping Rest primed at full
        -- health needlessly exposes the next bite to native Rest timing.
        local deficit = effects or s.hp < s.maxHP-.35
        if not deficit then self:release("armed; no recovery deficit", now); return end
        if not self.owned then
            -- Stage masking ownership BEFORE requesting native Rest.
            self.owned = s.char
            self.echoes, self.nativeEchoObserved = 0, false
            self.echoWindow = now
            self.signalAt, self.nextRefresh = now, now+5
            self.state = "REQUESTED"
            if not bridge:rest(s.char, true) then
                self.owned = nil
                self.state = "native Rest unavailable"
                self.backoffUntil = now+3
                return
            end
            ledger:event("native_rest_requested", now, { moving = s.moving,purpose = self.purpose,combatHPExcluded = s.combat ~= false })
        elseif now >= self.nextRefresh then
            -- Bounded renewal while deficit persists. A request is not an acknowledgement.
            self.nextRefresh = now+5
            if bridge:rest(s.char, true) then ledger:event("native_rest_renewed", now) end
        end
    end
    function r:close(now)
        self.enabled = false
        self:release("CLOSED", now)
    end
    return r
end
return Recovery
