-- A single native Rest owner. Manual Rest is never cancelled or masked.
local Recovery = {}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e12 end
function Recovery.new(bridge, policy, ledger)
    local r = { state = "OFF", owned = nil, enabled = false, echoes = 0,
        backoffUntil = 0, releaseAt = -math.huge, signalAt = -math.huge,
        nativeEchoObserved = false, writes = 0, nextRefresh = 0, observations = {},
        conditionChar = nil, conditionSeenUntil = 0, conditionSeen = {}, renewals = 0 }
    function r:clearPose()
        local pose = self.pose
        self.pose = nil
        if pose then bridge:restoreAttribute(pose.char,"WolfDbgRestP",pose.value,pose.before) end
    end
    function r:holdPose(char, now)
        if not char or char ~= bridge.player.Character or not char.Parent
            or bridge:attribute(char,"FeralDowned") == true then self:clearPose();return false end
        if self.pose and self.pose.char ~= char then self:clearPose() end
        if self.pose then return bridge:attribute(char,"WolfDbgRestP") == self.pose.value end
        -- v2412 WolfAnimClient.stepRig, words 3736-3760: this Vector3
        -- replaces the persistent sit/lie/hold blend, not combat/downed state.
        local pose = {char=char,before=bridge:attribute(char,"WolfDbgRestP"),value=Vector3.new(0,0,0)}
        self.pose = pose -- record before a setter can fail after mutating
        if not bridge:setAttribute(char,"WolfDbgRestP",pose.value) then self:clearPose();return false end
        self.poseUntil = now+.35
        return true
    end
    function r:guardPose(now)
        if self.pose and (policy.manualRest or self.pose.char ~= bridge.player.Character
            or bridge:attribute(self.pose.char,"FeralDowned") == true) then self:clearPose() end
        if self.owned and not self:holdPose(self.owned,now) then
            self:release("native pose control unavailable",now)
            self.backoffUntil = now+3
        end
    end
    function r:afterAnimationFrame(now)
        -- Expiry is processed after native WolfAnim (Camera+2), never before
        -- its first frame after a hitch. Time alone is not a rendered frame.
        if self.pose and not self.owned and now >= (self.poseUntil or 0) then self:clearPose() end
    end
    function r:failedExit(char,now)
        -- Do not hide a native Rest that we failed to end, claim a
        -- successful exit, or retry the user's attack against unknown state.
        self.releaseFailedChar=char
        self.lastAutomaticCharacter=nil
        self.nativeEchoObserved=false
        self.previous,self.observations=nil,{}
        self:clearPose()
        self.state="native Rest exit failed; use manual Rest"
        ledger:event("native_rest_exit_failed",now)
        return false
    end
    function r:release(reason, now)
        local char = self.owned
        self.owned = nil
        if char then
            if char~=bridge.player.Character or not char.Parent then
                self:clearPose()
                self.lastAutomaticCharacter=nil
            else
                self.releasingChar=char
                local dispatched=bridge:rest(char,false)
                self.releasingChar=nil
                if not dispatched then return self:failedExit(char,now) end
                self.releaseAt, policy.lastRestRelease = now, now
                -- Only an echo attributed to this owner's dispatched exit is cleared.
                if not policy.manualRest then bridge:maskRest(char) end
                self.poseUntil = now+.35
                ledger:event("owned_rest_released", now, { reason = reason })
            end
        end
        if self.releaseFailedChar and self.releaseFailedChar==bridge.player.Character then
            self.state="native Rest exit failed; use manual Rest"
            return false
        end
        self.state = reason or "OFF"
        return true
    end
    function r:manual(now)
        -- Yield ownership without emitting false; native/manual Rest takes over.
        self.owned = nil
        self.lastAutomaticCharacter = nil
        self.releaseFailedChar=nil
        self:clearPose()
        policy.manualRest = true
        self.state = "MANUAL"
        ledger:event("manual_rest_preserved", now)
    end
    function r:echo(s, now)
        if not s or not s.char then return end
        if policy.manualRest or self.releasingChar==s.char or self.releaseFailedChar==s.char then return end
        if self.owned == s.char and s.rest then
            if now <= policy.manualIntentUntil then self:manual(now); return end
            self.nativeEchoObserved = true
            if now-(self.echoWindow or 0) > 2 then self.echoes,self.echoWindow = 0,now end
            self.echoes += 1
            local ok = bridge:maskRest(s.char)
            if ok then self.writes += 1 end
            ledger:event("owned_rest_pose_echo", now, { locallyMasked = ok })
            if not ok then
                self:release("native pose mask unavailable", now)
                self.backoffUntil = now+3
            else self.state = "ECHO_OBSERVED" end
        elseif not self.owned and s.rest then
            if now <= policy.manualIntentUntil or self.lastAutomaticCharacter ~= s.char then
                self:manual(now)
            else
                -- An elapsed timeout is not evidence of manual input. Keep
                -- the provenance of our own session until a real Rest action
                -- or character change, including while recovery is disabled.
                if self:holdPose(s.char,now) then self.poseUntil = now+.35 end
                bridge:maskRest(s.char)
                ledger:event("late_owned_rest_echo",now)
            end
        end
    end
    function r:observe(s,now)
        if now < (self.nextObserve or 0) then return end
        self.nextObserve = now+.25
        local mode = self.owned and (s.combat == false and "hp" or "effects") or "idle"
        local previous = self.previous
        self.previous = {char=s.char,now=now,maxHP=s.maxHP,moving=s.moving,combat=s.combat,mode=mode,
            hp=s.hp,injury=s.injury,bleed=s.bleed,venom=s.venom}
        if not previous or previous.char ~= s.char or previous.mode ~= mode or previous.combat ~= s.combat
            or previous.moving ~= s.moving or previous.maxHP ~= s.maxHP
            or now<=previous.now or now-previous.now > 1.5 then
            self.observations = {};return
        end
        if mode == "idle" then self.observations = {};return end
        for _,key in ipairs({"hp","injury","bleed","venom"}) do
            local a,b = previous[key],s[key]
            if key == "hp" and s.combat ~= false or type(a) ~= "number" or type(b) ~= "number"
                or a ~= a or b ~= b or math.abs(a)>=1e12 or math.abs(b)>=1e12
                or a<0 or b<0 or key ~= "hp" and a <= 0 then self.observations[key]=nil;continue end
            local delta = key == "hp" and b-a or a-b
            if delta < 0 then self.observations[key]=nil;continue end
            local item=self.observations[key] or {samples={}}
            self.observations[key]=item
            table.insert(item.samples,{from=previous.now,to=now,change=delta})
            local cutoff=now-6
            while #item.samples>0 and (item.samples[1].to<=cutoff or #item.samples>32) do
                table.remove(item.samples,1)
            end
            local first=item.samples[1]
            if first and first.from<cutoff then
                first.change *= (first.to-cutoff)/(first.to-first.from)
                first.from=cutoff
            end
            item.seconds,item.change=0,0
            for _,sample in ipairs(item.samples) do
                item.seconds += sample.to-sample.from;item.change += sample.change
            end
            item.rate = item.change/item.seconds
        end
    end
    function r:summary()
        local hp = self.observations.hp
        local message = self.owned and "Recovery requested" or self.state
        if self.owned and self.previous and self.previous.combat==false then
            message ..= hp and hp.change > .02 and string.format(" · HP rising %.2f/s; 2× unverified",hp.rate)
                or hp and hp.seconds >= 5.9 and " · no HP rise observed; 2× unverified"
                or " · watching HP; 2× unverified"
        else message ..= " · gameplay unverified" end
        return message
    end
    function r:effectsSummary()
        local pieces={}
        for _,key in ipairs({"injury","bleed","venom"}) do
            local item=self.observations[key]
            table.insert(pieces,key..": "..(not item and "unmeasured" or item.change>0 and string.format("easing %.2f/s",item.rate)
                or item.seconds>=5.9 and "no recent decrease" or "watching"))
        end
        return table.concat(pieces," · ").." · 4× unverified"
    end
    function r:tick(s, now)
        self:guardPose(now)
        if self.releaseFailedChar then
            if s and s.char==self.releaseFailedChar then
                self.state="native Rest exit failed; use manual Rest"
                return
            end
            self.releaseFailedChar=nil
        end
        if s and s.alive then
            if self.conditionChar~=s.char then
                self.conditionChar=s.char
                self.conditionSeenUntil,self.conditionSeen=0,{}
            end
            self:observe(s,now)
        end
        if policy.manualRest then
            if self.enabled and s and s.alive and s.rest and s.hum.MoveDirection.Magnitude>.13
                and not s.captured and not s.grab and not s.ability and now>policy.manualIntentUntil then
                -- Walking is an explicit exit from stationary manual Rest.
                -- End that action once, then let ordinary recovery policy run.
                policy.manualRest,policy.manualIntentUntil=false,0
                self.lastAutomaticCharacter=s.char
                self:holdPose(s.char,now);self.poseUntil=now+.35
                self.releasingChar=s.char
                local dispatched=bridge:rest(s.char,false)
                self.releasingChar=nil
                if not dispatched then self:failedExit(s.char,now);return end
                bridge:maskRest(s.char)
                self.releaseAt,policy.lastRestRelease=now,now
                self.backoffUntil=math.max(self.backoffUntil,now+.75)
                self.state="manual Rest ended by movement"
                ledger:event("manual_rest_exit_by_movement",now)
                return
            end
            if not s or not s.alive or not s.rest then
                if s and s.alive and now <= policy.manualIntentUntil then self.state="MANUAL";return end
                policy.manualRest = false
                policy.manualIntentUntil = 0
                policy.lastRestRelease = now
                self.backoffUntil = math.max(self.backoffUntil, now+.75)
            else self.state = "MANUAL"; return end
        end
        if self.owned and (not s or self.owned ~= s.char) then self:release("animal changed", now) end
        if not self.enabled then self:release("OFF", now); return end
        local effects=false
        self.conditionSeenUntil=0
        if s and s.alive then
            for _,key in ipairs({"injury","bleed","venom"}) do
                local value=s[key]
                if finite(value) and value>=0 then
                    -- Explicit zero ends this condition immediately; only an
                    -- unknown amount gets the bounded replication-gap grace.
                    self.conditionSeen[key]=value>.1 and now+.9 or nil
                end
                local untilAt=self.conditionSeen[key] or 0
                if now<untilAt then effects=true end
                self.conditionSeenUntil=math.max(self.conditionSeenUntil,untilAt)
            end
        end
        self.purpose = effects and "effects" or "health"
        local allowed, reason = policy:allowed("recovery", s, now,self.purpose)
        if not allowed then self:release(reason, now); return end
        if now < self.backoffUntil then
            if self.state~="native Rest renewal unavailable" then self.state = "waiting after action" end
            return
        end
        self:echo(s, now)
        if policy.manualRest or now < self.backoffUntil then return end
        -- Request only for an actual deficit. Keeping Rest primed at full
        -- health needlessly exposes the next bite to native Rest timing.
        if not effects and (not finite(s.hp) or not finite(s.maxHP) or s.maxHP<=0) then
            self:release("health data unavailable",now);return
        end
        local deficit = effects or s.hp < s.maxHP-.35
        if not deficit then self:release("armed; no recovery deficit", now); return end
        if not self.owned then
            -- Stage masking ownership BEFORE requesting native Rest.
            if not self:holdPose(s.char,now) then
                self.state="native pose control unavailable";self.backoffUntil=now+3;return
            end
            local previousAutomatic=self.lastAutomaticCharacter
            self.owned = s.char
            self.lastAutomaticCharacter = s.char
            self.echoes, self.nativeEchoObserved = 0, false
            self.echoWindow = now
            self.signalAt, self.nextRefresh = now, now+2
            self.state = "REQUESTED"
            if not bridge:rest(s.char, true) then
                self.owned = nil
                self.lastAutomaticCharacter=previousAutomatic
                self:clearPose()
                self.state = "native Rest unavailable"
                self.backoffUntil = now+3
                return
            end
            ledger:event("native_rest_requested", now, { moving = s.moving,purpose = self.purpose,combatHPExcluded = s.combat ~= false })
        elseif now >= self.nextRefresh then
            -- v1.1 live Bear measurements supported the native Rest request
            -- while moving. Renew ONLY Rest(true) at a bounded interval so
            -- native locomotion transitions cannot leave long unsignalled
            -- gaps. Do not flip it to false just because HP/status changes are
            -- not yet observed: the prior no-progress retries interrupted it.
            self.nextRefresh = now+2
            if bridge:rest(s.char, true) then
                self.renewals += 1
                ledger:event("native_rest_renewed", now, { moving=s.moving, purpose=self.purpose })
            else
                -- A failed request is not a continuing active recovery session.
                -- Relinquish its local ownership and restore the owned pose;
                -- do not keep an invisible Rest override indefinitely.
                ledger:event("native_rest_renew_failed",now)
                self:release("native Rest renewal unavailable",now)
                self:clearPose()
                self.backoffUntil=now+3
                self.observations={}
                self.previous=nil
            end
        end
    end
    function r:close(now)
        self.enabled = false
        self:release("CLOSED", now)
        self:clearPose()
        self.previous,self.observations,self.lastAutomaticCharacter = nil,{},nil
        self.conditionChar,self.conditionSeenUntil,self.conditionSeen = nil,0,{}
        self.releaseFailedChar,self.releasingChar=nil,nil
    end
    return r
end
return Recovery
