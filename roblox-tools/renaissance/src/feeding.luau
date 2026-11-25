-- Protect the user's native feeding session; never changes hunger/thirst values.
local Feeding = {}
function Feeding.new(bridge,policy,ledger)
    local f = { intent=nil,session=nil,restart=nil,status="",busy=false }
    function f:cancel(reason,now)
        local active=self.intent or self.session or self.restart or self.busy
        self.intent,self.session,self.restart,self.carryRetry,self.busy = nil,nil,nil,nil,false
        self.status = reason or ""
        if active then policy.actionUntil = math.max(policy.actionUntil,now+.45) end
    end
    function f:input(s,now)
        self.nextProbe=0
        if s.feeding or self.intent or self.restart then self:cancel("manual feeding toggle",now);return end
        local kind = bridge:attribute(s.char,"FeedCan")
        if kind == "eat" or kind == "drink" then
            self.intent = {char=s.char,kind=kind,untilAt=now+6}
            self.busy,self.status = true,"Approaching " .. (kind == "eat" and "food" or "water")
        end
    end
    function f:stopped(reason,now)
        if reason == "eaten" or reason == "nofood" then self:cancel("native feeding ended: " .. reason,now) end
    end
    function f:attack(s,now)
        local mode=bridge:nativeFeedState(now)
        local active=s.feeding or mode~=nil or self.busy
        self:cancel("attack input",now)
        if active then
            local called=bridge:stopNativeFeed(now)
            ledger:event("native_feed_cancel_for_attack",now,{called=called==true})
        end
    end
    function f:tick(s,now)
        local invalid = not s.alive or s.chat or s.gameMenu or s.captured or s.grab or s.holding or s.ability
            or s.flying or s.climbing
            or s.attackHeld or now < policy.attackUntil
        if invalid then
            if self.intent or self.session or self.restart or self.busy then self:cancel("feeding yielded to native action",now) end
            return
        end
        if now >= (self.nextProbe or 0) or s.feeding or self.intent or self.restart or self.busy then
            self.mode,self.started,self.known=bridge:nativeFeedState(now)
            self.nextProbe=now+.25
        end
        local mode,started,known = self.mode,self.started,self.known
        if self.intent and (self.intent.char ~= s.char or now > self.intent.untilAt
            or known and mode == nil and not self.restart and now > self.intent.untilAt-5.65) then self.intent=nil end
        if self.session and (self.session.char ~= s.char or s.feedMode ~= self.session.kind) and not self.restart then self.session=nil end
        local active = s.feedMode
        local pending = known and mode ~= nil or self.intent ~= nil or self.restart ~= nil
        self.busy = s.feeding or pending
        s.feeding = self.busy
        if self.restart then
            local r = self.restart
            if r.char ~= s.char or s.moving or now > r.untilAt then self:cancel("feeding restart cancelled",now);return end
            if now >= r.at and known and mode == nil and bridge:attribute(s.char,"FeedCan") == r.kind then
                self.restart=nil
                -- Original toggleFeed owns approach, selection, eligibility and Feed.
                local sent = bridge:toggleNativeFeed(now)
                self.intent = sent and {char=s.char,kind=r.kind,untilAt=now+6} or nil
                self.carryRetry = sent and {char=s.char,kind=r.kind} or nil
                self.status = sent and "Feeding restarted once; watching resource" or "Native feeding restart unavailable"
                ledger:event("native_feed_restart",now,{called=sent==true})
            end
            return
        end
        if not active then
            if not self.busy then self.status="" end
            return
        end
        self.intent=nil
        local value = active == "eat" and s.hunger or s.thirst
        if type(value) ~= "number" or value ~= value then self.status="Feeding; resource unavailable";return end
        local session = self.session
        if not session or session.kind ~= active or session.char ~= s.char then
            session = {char=s.char,kind=active,last=value,progressAt=now,
                retried=self.carryRetry and self.carryRetry.char==s.char and self.carryRetry.kind==active or false}
            self.session,self.carryRetry = session,nil
        end
        if value > session.last+.02 then
            ledger:event("feeding_resource_advanced",now,{kind=active,increase=value-session.last})
            session.progressAt=now
        end
        session.last=value
        self.status = active == "eat" and "Eating; watching hunger" or "Drinking; watching thirst"
        local cfg=bridge:config("NeedsConfig")
        local maximum=cfg and cfg[active=="eat" and "HUNGER_MAX" or "THIRST_MAX"] or 100
        if type(maximum) ~= "number" then maximum=100 end
        if value >= maximum-.5 or now-session.progressAt < 4.5 then return end
        self.status="Feeding stalled; no resource increase observed"
        if bridge:attribute(s.char,"FeedCan")~=active then
            self.status="Feeding stalled; native food/water offer lost"
            return
        end
        if session.retried or s.moving or not known or mode ~= active or not started then return end
        session.retried=true
        self.restart={char=s.char,kind=active,at=now+.18,untilAt=now+1.3}
        local stopped = bridge:toggleNativeFeed(now)
        ledger:event("native_feed_stall_repair",now,{called=stopped==true})
        if not stopped then self.restart=nil;self.status="Feeding stalled; native restart unavailable" end
    end
    function f:close(now) self:cancel("",now) end
    return f
end
return Feeding
