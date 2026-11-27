-- Hippo-only supervision of native charge/release. Never supplies damage or time.
local Hippo = {}
function Hippo.new(Core,bridge,ledger)
    local h={status="waiting for Hippo",history={},releaseStatus="manual release",nextProbe=0}
    function h:profile()
        if not bridge:capability("hippoProfile") then return nil end
        local config=bridge:config("AbilityConfig") or bridge:config("AbilityConfigBase")
        local p=config and config.CrusherBite
        if type(p)~="table" then return nil end
        for _,key in ipairs({"CHARGE_TIME","MULT_START","MULT_MAX","CURVE","OVERHOLD"}) do
            if not Core.finite(p[key]) then return nil end
        end
        if p.CHARGE_TIME<=0 or p.CHARGE_TIME>30 or p.OVERHOLD<0 or p.OVERHOLD>60
            or p.CURVE<=0 or p.CURVE>8 or p.MULT_START<0 or p.MULT_MAX<p.MULT_START then return nil end
        return p
    end
    function h:reset()
        self.session,self.recent,self.profileValue,self.native=nil,nil,nil,nil
        self.nextProbe=0
        self.status,self.releaseStatus="waiting for Hippo","manual release"
    end
    function h:observe(s,now)
        if not s.alive or s.species~="Hippo" then self:reset();return end
        local p=self:profile();self.profileValue=p
        if not p then self.session=nil;self.status="charge profile unavailable";return end
        local at=bridge:attribute(s.char,"FeralCrushAt")
        if Core.finite(at) and s.serverNow and at<=s.serverNow+.25 and s.serverNow-at<=p.CHARGE_TIME+p.OVERHOLD+2 then
            local q=self.session
            if not q or q.char~=s.char or q.generation~=s.generation or q.start~=at then
                q={char=s.char,generation=s.generation,start=at,profile=p};self.session=q
                ledger:event("hippo_charge_observed",now)
            end
            q.elapsed=math.max(0,s.serverNow-at)
            q.fraction=math.clamp(q.elapsed/p.CHARGE_TIME,0,1)
            q.multiplier=p.MULT_START+(p.MULT_MAX-p.MULT_START)*q.fraction^p.CURVE
            self.status=q.fraction>=1 and "full charge; extra hold does not increase the captured multiplier"
                or string.format("charging %.0f%%",q.fraction*100)
            return
        end
        local q=self.session
        if q then
            q.endedAt=q.endedAt or now
            local bittenAt=bridge:attribute(s.char,"FeralCrushBiteAt")
            if Core.finite(bittenAt) and bittenAt>=q.start and s.serverNow and bittenAt<=s.serverNow+.25 then
                q.releasedAt,q.heldFor=now,bittenAt-q.start
                self.recent=q;self.session=nil
                local record={heldFor=q.heldFor,smart=q.attempted==true,acceptedDamage="unverified"}
                q.record=record;table.insert(self.history,record)
                if #self.history>12 then table.remove(self.history,1) end
                self.status=string.format("release observed after %.2fs",q.heldFor)
                ledger:event("hippo_release_observed",now,{heldFor=q.heldFor,smart=q.attempted==true,damageAcceptance="unverified"})
            elseif now-q.endedAt>.35 then
                self.session=nil;self.status="charge ended without a release marker"
                ledger:event("hippo_charge_ended",now)
            end
        elseif not self.recent then self.status="ready for a manual charge" end
    end
    function h:tick(s,now,enabled,guide,geometry)
        self:observe(s,now)
        if not s.alive or s.species~="Hippo" then return end
        if enabled and now>=self.nextProbe and not bridge.deferNativeDiscovery then
            self.nextProbe=now+.1
            self.native=bridge:nativeHippoActions(now)
        end
        local q=self.session
        if not enabled then self.releaseStatus="manual release";return end
        if not self.native then self.releaseStatus="waiting for the native release control";return end
        self.releaseStatus="waiting for full charge and clear contact"
        if not q or q.attempted or q.fraction<1 or q.profile~=self.profileValue
            or s.chat or s.gameMenu or s.captured or s.grab or s.feeding or s.rest or s.holding
            or s.underwater then return end
        if not bridge:autoAttackTarget(s,guide,geometry) then return end
        q.attempted=true
        q.target=guide.target.char
        local called=bridge:finishNativeHippo(s,q.start,now)
        self.releaseStatus=called and "native release attempted; damage unverified" or "native release declined"
        ledger:event("hippo_smart_release_attempt",now,{called=called==true,damageAcceptance="unverified"})
    end
    function h:feedback(data,now)
        local q=self.recent
        if not q or q.char~=bridge.player.Character or now-q.releasedAt>1.5 or q.feedback
            or type(data)~="table" or data.a~=q.char or q.target and data.v~=q.target then return end
        q.feedback=data
        if q.record and Core.finite(data.dmg) and data.dmg>=0 then
            q.record.gameReportedDamage=data.dmg;q.record.protected=data.safe==true
            -- A nearby reply is correlation; normal bites may share this window.
            q.record.attribution="unverified"
        end
    end
    function h:summary()
        local p=self.profileValue
        if not p then return self.status end
        return self.status.."\n"..string.format("Captured scale %.2f×–%.2f× · full at %.1fs · overhold %.1fs",
            p.MULT_START,p.MULT_MAX,p.CHARGE_TIME,p.OVERHOLD).."\n"..self.releaseStatus
    end
    function h:close()
        self:reset();self.native=nil;table.clear(self.history)
    end
    return h
end
return Hippo
