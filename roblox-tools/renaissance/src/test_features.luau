-- Own-character diagnostics for every animal. Potassium's local file is
-- picked up by the separate private PC runner; this module has no network API.
local Tests = {}
local PATH = "FERAL_RENAISSANCE_TESTS_LATEST.json"
local LIMIT = 240
local SCHEMA = "FERAL_RENAISSANCE_TESTS_V1"

function Tests.new(Core,bridge,hub)
    local t = { active = false, closed = false, enabled = true, path = PATH,
        events = {}, samples = {}, species = {}, biteTimes = {}, biteCount = 0,
        dirty = true, saved = false, attempts = 0,
        nextSave = 0, nextSample = 0, notice = "Recording starts with the hub",
        characterScope = Core.scope() }
    local io = bridge:io()
    local function attr(char,key)
        if not char then return nil end
        local read,value=pcall(char.GetAttribute,char,key)
        return read and value or nil
    end
    local function finite(value)
        return Core.finite(value)
    end
    function t:snapshot()
        local char=bridge.player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local species=attr(char,"Species")
        local shell
        local config=bridge:config("CombatConfig")
        if char and config and type(config.shellMult)=="function" then
            local computed,value=pcall(config.shellMult,char)
            if computed and finite(value) then shell=value end
        end
        local current=hub.snapshot
        local combat
        if current and current.char==char and type(current.combat)=="boolean" then combat=current.combat end
        return {species=type(species)=="string" and #species<=31 and species:match("^[A-Za-z][A-Za-z0-9]*$") and species or "unknown",
            rest=attr(char,"WolfRest")==true,
            restAt=finite(attr(char,"WolfRestAt")) and attr(char,"WolfRestAt") or nil,
            hp=hum and finite(hum.Health) and hum.Health or nil,
            maxHP=hum and finite(hum.MaxHealth) and hum.MaxHealth or nil,
            safeUntil=finite(attr(char,"FeralSafeUntil")) and attr(char,"FeralSafeUntil") or nil,
            crushAt=finite(attr(char,"FeralCrushAt")) and attr(char,"FeralCrushAt") or nil,
            injury=current and current.char==char and finite(current.injury) and current.injury or nil,
            bleed=current and current.char==char and finite(current.bleed) and current.bleed or nil,
            venom=current and current.char==char and finite(current.venom) and current.venom or nil,
            stamina=current and current.char==char and finite(current.stamina) and current.stamina or nil,
            maxStamina=current and current.char==char and finite(current.maxStamina) and current.maxStamina or nil,
            hunger=current and current.char==char and finite(current.hunger) and current.hunger or nil,
            thirst=current and current.char==char and finite(current.thirst) and current.thirst or nil,
            survival=current and current.char==char and finite(current.survival) and current.survival or nil,
            locomotion=current and current.char==char and current.locomotion or "NONE",
            moving=current and current.char==char and current.moving==true or false,
            combat=combat,combatKnown=combat~=nil,
            shellFormulaClientOnly=shell}
    end
    function t:record(kind,fields)
        if not self.active or not self.enabled then return end
        local event={kind=kind,at=bridge.clock(),serverAt=bridge:serverNow(),data=fields or {}}
        table.insert(self.events,event)
        if #self.events>LIMIT then table.remove(self.events,1) end
        self.dirty=true
    end
    function t:characterChanged(char)
        self.characterScope:close()
        self.characterScope=Core.scope()
        self.char=char
        self.biteTimes,self.biteCount={},0
        self.hum=nil
        if not char then
            self:record("character_removed")
            return
        end
        local function watch(hum)
            if not hum or self.closed or bridge.player.Character~=char then return end
            self.hum=hum
            local last,lastMax=hum.Health,hum.MaxHealth
            local connection=hum.HealthChanged:Connect(function(hp)
                if not self.active or not self.enabled or bridge.player.Character~=char then
                    last,lastMax=hp,hum.MaxHealth;return
                end
                local maxHP=hum.MaxHealth
                local before,previousMax=last,lastMax
                last,lastMax=hp,maxHP
                if not finite(before) or not finite(hp) or hp==before then return end
                local snapshot=self:snapshot()
                local delta=hp-before
                local stable=finite(maxHP) and maxHP==previousMax and maxHP>0
                self:record(delta<0 and "incoming_hp_loss" or "hp_recovery",
                    {species=snapshot.species,rest=snapshot.rest,restAt=snapshot.restAt,
                    before=before,after=hp,delta=delta,maxHP=maxHP,
                    maxHPStable=stable,safeUntil=snapshot.safeUntil,
                    shellFormulaClientOnly=snapshot.shellFormulaClientOnly,
                    crushAt=snapshot.crushAt})
                if delta<0 and stable then
                    local key=snapshot.species
                    local totals=self.species[key]
                    if type(totals)~="table" then
                        totals={hits=0,damage=0,restHits=0,restDamage=0}
                        self.species[key]=totals
                    end
                    totals.hits+=1;totals.damage-=delta
                    if snapshot.rest then totals.restHits+=1;totals.restDamage-=delta end
                end
            end)
            self.characterScope:add(function() connection:Disconnect() end)
            self:record("character_ready",self:snapshot())
        end
        for _,key in ipairs({"Species","WolfRest","WolfRestAt","FeralSafeUntil","FeralCrushAt","FeralCrushBiteAt"}) do
            local connection=char:GetAttributeChangedSignal(key):Connect(function()
                if bridge.player.Character==char then self:record("attribute_"..key,self:snapshot()) end
            end)
            self.characterScope:add(function() connection:Disconnect() end)
        end
        self:record("character_attached",self:snapshot())
        local hum=char:FindFirstChildOfClass("Humanoid")
        if hum and hum.HealthChanged then watch(hum)
        else
            task.spawn(function()
                local later=char:WaitForChild("Humanoid",5)
                if later and later.HealthChanged then watch(later) end
            end)
        end
    end
    function t:feedback(kind,data)
        if kind~="hit" or type(data)~="table" then return end
        local char=bridge.player.Character
        if not char or data.v~=char and data.a~=char then return end
        self:record("server_hit_reply",{direction=data.v==char and "incoming" or "outgoing",
            damage=finite(data.dmg) and data.dmg or nil,safe=data.safe==true,
            species=self:snapshot().species,rest=attr(char,"WolfRest")==true})
    end
    function t:hippoReply(kind,actor,_,_,strength,hit)
        local mine=actor==bridge.player.Character
        if mine then
            self:record("hippo_server_reply",{kind=kind=="cancel" and "cancel" or kind=="release" and "release"
                or kind=="start" and "start" or "other",actorIsSelf=mine,
                strength=finite(strength) and strength or nil,
                hit=type(hit)=="boolean" and hit or nil,snapshot=self:snapshot()})
        end
        if mine and kind=="cancel" and self.pending then
            self.pending=nil
            self:record("crusher_cancel_observed",{acceptance="unverified"})
        end
    end
    function t:release(reason)
        local pending=self.pending
        if not pending then return false end
        self.pending=nil
        if bridge.player.Character~=pending.char or not pending.char.Parent then
            self:record("crusher_release_skipped",{reason="character changed"})
            return false
        end
        local now=bridge:serverNow()
        local sent=now and bridge:fire("FeralHippo","release",now)==true or false
        self:record("crusher_release_requested",
            {sent=sent,reason=reason,heldFor=now and now-pending.at or nil,
                serverAcceptance="unverified",snapshot=self:snapshot()})
        return sent
    end
    function t:crossSpecies()
        if not self.active or not self.enabled or self.attempts>0 then
            self.notice="One attempt per hub run";return false
        end
        if game.PlaceId~=108901361810209 or game.PlaceVersion~=2412 then
            self.notice="Game version changed; test request disabled"
            self:record("trial_version_blocked",{placeVersion=game.PlaceVersion})
            return false
        end
        local snapshot=self:snapshot()
        local char=bridge.player.Character
        local now=bridge:serverNow()
        local readyAt=bridge:attribute(bridge.player,"FeralLungeReadyAt")
        if snapshot.species~="SnappingTurtle" or not snapshot.rest
            or not finite(snapshot.restAt) or not now or now-snapshot.restAt<1.25
            or not self.hum or self.hum.Health<=0 then
            self.notice="Rest as Turtle for 1.25 seconds first"
            return false
        end
        if finite(readyAt) and now<readyAt-.05 then
            self.notice="Ability cooldown active";return false
        end
        self.attempts=1
        local pending={char=char,at=now}
        self.pending=pending
        local sent=bridge:fire("FeralHippo","start",now)==true
        self:record("crusher_start_requested",
            {sent=sent,serverAcceptance="unverified",snapshot=snapshot})
        if not sent then self.pending=nil;self.notice="Crusher request unavailable";return false end
        self.notice="Crusher request sent; observing server"
        task.delay(6.1,function()
            if self.active and self.pending==pending then self:release("timed one-shot") end
        end)
        return true
    end
    function t:featureStates()
        local states={}
        for _,feature in ipairs(hub.registry.order) do
            states[feature.id]={requested=feature.requested==true,applied=feature.applied==true,
                state=feature.state=="CLIENT" and "CLIENT" or feature.state=="ARMED" and "ARMED"
                    or feature.state=="PARTIAL" and "PARTIAL" or feature.state=="WAITING" and "WAITING"
                    or feature.state=="OFF" and "OFF" or "OTHER"}
        end
        return states
    end
    function t:ledgerSummary()
        local counts={}
        for name,count in pairs(hub.ledger.counts) do
            if type(name)=="string" and #name<=64 and name:match("^[A-Za-z_][A-Za-z0-9_]*$")
                and finite(count) and count>=0 and count<10000000 then counts[name]=count end
        end
        local rates={}
        for name,bucket in pairs(hub.ledger.rates) do
            if type(name)=="string" and #name<=55 and name:match("^[A-Z_:a-z]+$")
                and type(bucket)=="table" then
                local effects={}
                for _,effect in ipairs({"injury","bleed","venom"}) do
                    local v=bucket.effects and bucket.effects[effect]
                    if v and finite(v.seconds) and finite(v.decrease) then
                        effects[effect]={seconds=v.seconds,decrease=v.decrease}
                    end
                end
                rates[name]={seconds=finite(bucket.seconds) and bucket.seconds or nil,
                    hp=finite(bucket.hp) and bucket.hp or nil,
                    damage=finite(bucket.damage) and bucket.damage or nil,effects=effects}
            end
        end
        return counts,rates
    end
    function t:observeBite(s,now)
        if not self.active or not self.enabled or s.char~=self.char then return end
        self.biteCount+=1
        table.insert(self.biteTimes,now)
        if #self.biteTimes>32 then table.remove(self.biteTimes,1) end
        self.dirty=true
    end
    function t:biteCadence()
        local sum,minimum,maximum,n=0,nil,nil,0
        for i=2,#self.biteTimes do
            local dt=self.biteTimes[i]-self.biteTimes[i-1]
            -- Exclude breaks between encounters from the active bite rate.
            if finite(dt) and dt>.03 and dt<=3 then
                sum+=dt;n+=1
                minimum=math.min(minimum or dt,dt);maximum=math.max(maximum or dt,dt)
            end
        end
        local seconds=n>0 and sum/n or nil
        local species=self:snapshot().species
        return {species=species,markers=self.biteCount,activeIntervals=n,
            meanSeconds=seconds,minSeconds=minimum,maxSeconds=maximum,
            measuredBitesPerSecond=seconds and 1/seconds or nil}
    end
    function t:report(recent)
        local counts,rates=self:ledgerSummary()
        local events=self.events
        if recent then
            events={}
            for i=math.max(1,#self.events-39),#self.events do table.insert(events,self.events[i]) end
        end
        return {schema=SCHEMA,version=hub.version,sourceFingerprint=hub.sourceFingerprint,
            placeId=game.PlaceId,placeVersion=game.PlaceVersion,
            savedAt=os.time(),source="own client observations; server damage reduction unverified",
            events=events,samples=self.samples,species=self.species,snapshot=self:snapshot(),
            features=self:featureStates(),ledgerCounts=counts,ledgerRates=rates,
            biteCadence=self:biteCadence(),middleRepeat=hub.combatInput:middleReport(),
            recording=self.enabled,oneShotAttempts=self.attempts,reportPath=PATH}
    end
    function t:bridgeReport() return self:report(true) end
    function t:save()
        if not io.available then
            self.notice="Local file writing unavailable";return false
        end
        local ok,result=pcall(io.write,PATH,self:report())
        self.saved=ok and result~=false
        if self.saved then
            self.dirty=false
            self.nextSave=bridge.clock()+8
            self.notice="Saved "..PATH
        else self.notice="Could not save report" end
        return self.saved
    end
    function t:copy()
        local ok,raw=pcall(bridge.HttpService.JSONEncode,bridge.HttpService,self:report())
        if not ok then self.notice="Report encoding failed";return false end
        if type(setclipboard)=="function" then
            local copied=pcall(setclipboard,raw)
            if copied then self.notice="Report copied to clipboard";return true end
        end
        self:save()
        self.notice="Clipboard unavailable; report saved locally"
        return false
    end
    function t:setEnabled(on)
        if self.enabled==(on==true) then return end
        self.enabled=on==true
        self.dirty=true
        if self.enabled then self:record("recording_enabled") end
        self:save()
    end
    function t:tick(now,critical)
        if not self.active or self.closed or not self.enabled or critical then return end
        if now>=self.nextSample then
            self.nextSample=now+15
            local sample=self:snapshot()
            sample.at=now
            table.insert(self.samples,sample)
            if #self.samples>60 then table.remove(self.samples,1) end
            self.dirty=true
        end
        if self.dirty and now>=self.nextSave then self:save() end
    end
    function t:summary()
        local s=self:snapshot()
        local totals=self.species[s.species]
        return string.format("%s · HP %s/%s · Rest %s\n%s · %d events · %d damage samples\n%s",
            s.species,tostring(s.hp or "?"),tostring(s.maxHP or "?"),
            s.rest and "ON" or "OFF",self.enabled and "Recording" or "Paused",
            #self.events,totals and totals.hits or 0,
            self.saved and "Local report saved · PC sync pending" or "Waiting for local report")
    end
    function t:start()
        self.active=true
        self:record("session_started",self:snapshot())
        self:save()
    end
    function t:close()
        if self.closed then return end
        if self.pending then self:release("hub unload") end
        self:record("session_stopped",self:snapshot())
        self:save()
        self.active=false;self.closed=true
        self.characterScope:close()
    end
    return t
end
return Tests
