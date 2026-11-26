-- FERAL Project Renaissance 15.7.1 | v2412 client baseline
-- Gameplay acceptance is unverified unless independently observed.
local options = ...
if type(options) ~= "table" then options = {} end
local sources = {}
sources["core"] = [============[
-- Renaissance: lifecycle, exclusive reversible leases and feature truth.
local Core = {}

function Core.finite(n)
    return type(n) == "number" and n == n and math.abs(n) < 1e12
end

function Core.scope()
    local s = { closed = false, tasks = {}, errors = {} }
    function s:add(fn)
        assert(type(fn) == "function", "cleanup must be callable")
        if self.closed then pcall(fn) else table.insert(self.tasks, fn) end
        return fn
    end
    function s:close()
        if self.closed then return end
        self.closed = true
        for i = #self.tasks, 1, -1 do
            local ok, err = pcall(self.tasks[i])
            if not ok then table.insert(self.errors, tostring(err)) end
        end
        table.clear(self.tasks)
    end
    return s
end

-- An entry is recorded BEFORE a write: setters that mutate and then throw also
-- unwind. Equal-value leases still reserve ownership. Nil originals are valid.
function Core.leases()
    local l = { owners = {}, slots = setmetatable({}, { __mode = "k" }), conflicts = 0 }
    function l:release(owner)
        local entries = self.owners[owner]
        if not entries then return end
        for i = #entries, 1, -1 do
            local e = entries[i]
            local ok = pcall(function()
                if e.target[e.key] == e.value then
                    e.target[e.key] = e.before
                else self.conflicts += 1 end
            end)
            if not ok then self.conflicts += 1 end
            local slots = self.slots[e.target]
            if slots and slots[e.key] == owner then slots[e.key] = nil end
        end
        self.owners[owner] = nil
    end
    function l:valid(owner)
        local entries = self.owners[owner]
        if not entries then return false end
        for _, e in ipairs(entries) do
            local ok, value = pcall(function() return e.target[e.key] end)
            if not ok or value ~= e.value then return false end
        end
        return true
    end
    function l:apply(owner, plan)
        assert(type(owner) == "string", "lease owner")
        if self.owners[owner] then
            return self:valid(owner), "existing lease changed"
        end
        if #plan == 0 then return false, "no compatible fields" end
        local seen = {}
        for _, e in ipairs(plan) do
            if type(e.target) ~= "table" or e.key == nil then return false, "invalid patch target" end
            local slots = self.slots[e.target]
            if slots and slots[e.key] then return false, "field already owned" end
            seen[e.target] = seen[e.target] or {}
            if seen[e.target][e.key] then return false, "duplicate field" end
            seen[e.target][e.key] = true
            local ok, value = pcall(function() return e.target[e.key] end)
            if not ok or (e.kind and type(value) ~= e.kind) then
                return false, "incompatible field: " .. tostring(e.key)
            end
        end
        self.owners[owner] = {}
        for _, p in ipairs(plan) do
            local e = { target = p.target, key = p.key, value = p.value, before = p.target[p.key] }
            table.insert(self.owners[owner], e)
            self.slots[e.target] = self.slots[e.target] or {}
            self.slots[e.target][e.key] = owner
            local ok = pcall(function()
                e.target[e.key] = e.value
                assert(e.target[e.key] == e.value, "write was not acknowledged")
            end)
            if not ok then self:release(owner); return false, "write rejected: " .. tostring(e.key) end
        end
        return true, "client config applied"
    end
    function l:close()
        local names = {}
        for name in pairs(self.owners) do table.insert(names, name) end
        for _, name in ipairs(names) do self:release(name) end
    end
    return l
end

Core.specs = {
    { "stamina", "Survival", "Infinite Stamina", "Client consumption profile; gameplay unverified" },
    { "recovery", "Survival", "Active Recovery + Fast Effects", "On by default; native effects unverified", default = true },
    { "effects", "Survival", "Fast Negative-Effect Recovery", "Injury, bleed and venom measured separately", linked = "recovery" },
    { "robloxAFK", "Survival", "Roblox Anti-AFK", "Best-effort platform idle input" },
    { "survivalAFK", "Survival", "Survival Bonus AFK", "Bounded safe walks; survival credit observed separately" },
    { "minigame", "Survival", "Automatic Minigames", "Native sessions; grades come from game replies" },
    { "escape", "Survival", "Auto Escape", "Native struggle actions; friendly baby carry preserved" },
    { "reach", "Combat", "Bite Reach", "Always enabled client geometry; server range unknown", permanent = true },
    { "biteHelper", "Combat", "Bite Range Helper", "Small smooth marker; native versus extended range" },
    { "combat", "Combat", "Combat Core", "Native attempts and feedback; no extra hit claims", permanent = true },
    { "climb", "Movement", "Climb Assist", "Native Q buffer and one guarded retry" },
    { "flight", "Movement", "Flight Assistance", "Surface takeoff assistance; no underwater flight" },
    { "mobility", "Movement", "Movement Assistance", "Reversible local injury slowdown inputs" },
    { "speed", "Movement", "Speed Assistance", "1.15x local land and swimming inputs" },
    { "leap", "Movement", "Jump / Leap Assistance", "1.15x local leap inputs; native exclusions retained" },
    { "zoom", "Movement", "Zoom Unlock", "Normal mouse-wheel zoom, from close-up to a distant view", default = true },
    { "esp", "Vision", "Outline ESP", "Hollow outlines for replicated characters" },
    { "colours", "Vision", "Faction / Health Colours", "Health-coloured hollow outlines; pack-coloured names", permanent = true },
    { "tags", "Vision", "Name Tags", "Small labels with independent visibility" },
    { "finder", "Vision", "Long-Range Player Finder", "Replicated players; up to 24 results", permanent = true },
    { "menu", "Vision", "Right Shift Menu Toggle", "Single menu; focused text keeps keyboard input", permanent = true },
    { "settings", "Vision", "Saved Settings", "Explicit ON and OFF reconciliation", permanent = true },
}

function Core.registry()
    local r = { order = {}, byId = {} }
    for _, spec in ipairs(Core.specs) do
        local f = { id = spec[1], group = spec[2], title = spec[3], detail = spec[4],
            permanent = spec.permanent == true, linked = spec.linked,
            requested = spec.permanent == true, applied = false, observed = "unknown",
            outcome = "unverified", state = "OFF", reason = "", revision = 0 }
        table.insert(r.order, f)
        r.byId[f.id] = f
    end
    function r:request(id, on)
        local f = assert(self.byId[id], "unknown feature")
        f.requested = f.permanent or on == true
        for _, x in ipairs(self.order) do
            if x.linked == id then x.requested = f.requested end
        end
    end
    function r:ack(id, applied, state, reason, observed)
        local f = assert(self.byId[id], "unknown feature")
        f.applied = applied == true
        f.state = state or (f.applied and "CLIENT" or "WAITING")
        f.reason = reason or ""
        if observed ~= nil then f.observed = observed end
        f.revision += 1
    end
    return r
end

function Core.ledger(limit)
    local l = { limit = limit or 160, events = {}, counts = {}, serial = 0, rates = {} }
    function l:event(kind, at, fields)
        self.serial += 1
        local e = { kind = kind, at = at, serial = self.serial, fields = fields or {} }
        table.insert(self.events, e)
        if #self.events > self.limit then table.remove(self.events, 1) end
        self.counts[kind] = (self.counts[kind] or 0) + 1
        return e
    end
    -- Unknown or disappeared status attributes never count as a cure.
    function l:sample(s, mode)
        local previous = self.previous
        self.previous = s
        if previous and previous.char==s.char and previous.species==s.species
            and previous.locomotion==s.locomotion and previous.maxStamina==s.maxStamina
            and previous.moving==s.moving and previous.combat==s.combat
            and Core.finite(previous.stamina) and Core.finite(s.stamina)
            and s.now-previous.now>=.1 and s.now-previous.now<=1.5 then
            local item=self.staminaObservation or {samples={}}
            self.staminaObservation=item
            table.insert(item.samples,{from=previous.now,to=s.now,change=s.stamina-previous.stamina})
            while #item.samples>0 and (item.samples[1].to<=s.now-6 or #item.samples>32) do table.remove(item.samples,1) end
            item.seconds,item.change=0,0
            for _,sample in ipairs(item.samples) do item.seconds+=sample.to-sample.from;item.change+=sample.change end
            item.rate,item.locomotion,item.species=item.change/item.seconds,s.locomotion,s.species
        else self.staminaObservation=nil end
        if not previous or previous.char ~= s.char or previous.mode ~= mode
            or previous.combat ~= s.combat or previous.moving ~= s.moving
            or previous.species ~= s.species or previous.maxHP ~= s.maxHP or s.now-previous.now < .1
            or s.now-previous.now > 1.5 then s.mode = mode; return end
        s.mode = mode
        local dt = s.now-previous.now
        local key = mode .. ":" .. tostring(s.combat) .. ":" .. (s.moving and "moving" or "still")
        local bucket = self.rates[key] or { seconds = 0, hp = 0, effects = {}, stamina = {} }
        self.rates[key] = bucket
        bucket.seconds += dt
        if Core.finite(s.hp) and Core.finite(previous.hp) and previous.hp < previous.maxHP-.2 then
            if s.hp >= previous.hp then bucket.hp += s.hp-previous.hp
            else bucket.damage = (bucket.damage or 0)+1 end
        end
        for _, name in ipairs({ "injury", "bleed", "venom" }) do
            local a, b = previous[name], s[name]
            if Core.finite(a) and Core.finite(b) and a > 0 and b <= a then
                local effect = bucket.effects[name] or { seconds = 0, decrease = 0 }
                bucket.effects[name] = effect
                effect.seconds += dt
                effect.decrease += a-b
            end
        end
        if Core.finite(s.stamina) and Core.finite(previous.stamina) and previous.locomotion == s.locomotion then
            local st = bucket.stamina[s.locomotion] or { seconds = 0, delta = 0 }
            bucket.stamina[s.locomotion] = st
            st.seconds += dt
            st.delta += s.stamina-previous.stamina
        end
    end
    return l
end

return Core
]============]
sources["settings"] = [============[
local Settings = { schema = 15, path = "FERAL_RENAISSANCE_V15.json",
    backup = "FERAL_RENAISSANCE_V15.backup.json", legacy = "FERAL_CLEAN_V14_PREFS.json" }

function Settings.sanitize(raw, specs)
    raw = type(raw) == "table" and raw or {}
    local src = type(raw.states) == "table" and raw.states or {}
    local result = { schema = 15, states = {}, range = 600, walls = false, tab = "Survival" }
    for _, spec in ipairs(specs) do
        if not spec.permanent and not spec.linked then
            local value = src[spec[1]]
            if spec[1] == "stamina" and value == nil then value = src.endurance end
            result.states[spec[1]] = value == true or value == nil and spec.default == true
        end
    end
    if raw.range == 300 or raw.range == 600 or raw.range == 900 then result.range = raw.range end
    result.walls = raw.walls == true or (raw.schema ~= 15 and src.walls == true)
    for _, tab in ipairs({ "Survival", "Combat", "Movement", "Vision", "Territory" }) do
        if raw.tab == tab then result.tab = tab end
    end
    return result
end

function Settings.load(io, specs)
    for _, path in ipairs({ Settings.path, Settings.backup, Settings.legacy }) do
        local ok, raw = pcall(io.read, path)
        if ok and type(raw) == "table" then
            return Settings.sanitize(raw, specs), path == Settings.path and "loaded" or "migrated"
        end
    end
    return Settings.sanitize(nil, specs), "defaults"
end

function Settings.save(io, value, specs)
    local clean = Settings.sanitize(value, specs)
    -- Backup protects the last readable settings if the executor stops mid-write.
    local readOK, old = pcall(io.read, Settings.path)
    if readOK and type(old) == "table" then
        local ok, why = pcall(io.write, Settings.backup, Settings.sanitize(old, specs))
        if not ok or why == false then return false, "backup write unavailable" end
    end
    local ok, result = pcall(io.write, Settings.path, clean)
    if not ok or result == false then return false, "settings write unavailable" end
    local verified, stored = pcall(io.read, Settings.path)
    if not verified or type(stored) ~= "table" or stored.schema ~= 15 then
        return false, "settings verification failed"
    end
    for key, value in pairs(clean.states) do
        if type(stored.states) ~= "table" or stored.states[key] ~= value then
            return false, "settings verification mismatch"
        end
    end
    if stored.range ~= clean.range or stored.walls ~= clean.walls or stored.tab ~= clean.tab then
        return false, "settings verification mismatch"
    end
    return true, "saved"
end

return Settings
]============]
sources["policy"] = [============[
-- Local scheduling policy. This never changes native eligibility or cooldowns.
local Policy = {}
function Policy.new()
    local p = { attackUntil = 0, actionUntil = 0, lastRestRelease = -math.huge,
        manualIntentUntil = 0, manualRest = false, lastPhysical = 0, menuOpen = false }
    function p:input(kind, now)
        self.lastPhysical = now
        if kind == "attack" then self.attackUntil = math.max(self.attackUntil, now+1.1) end
        if kind == "action" then self.actionUntil = math.max(self.actionUntil, now+1.3) end
        if kind == "rest" then self.manualIntentUntil = now+.9 end
    end
    function p:activity(s,now)
        if not s or not s.alive then return "unavailable" end
        if s.chat or s.gameMenu then return "menu" end
        if s.grab then return "minigame" end
        if s.captured then return "capture" end
        if s.attackHeld or now<self.attackUntil then return "attack" end
        if s.ability or s.holding then return "ability" end
        if s.feeding then return "feeding" end
        if s.rescuing then return "rescue" end
        if s.climbing or s.flying or s.underwater or s.swimming then return "movement" end
        if self.manualRest then return "manual Rest" end
        if now<self.actionUntil then return "action" end
        return "recovery window"
    end
    function p:allowed(mode, s, now, purpose)
        if not s or not s.alive then return false, "waiting for animal" end
        if s.chat or s.gameMenu then return false, "native menu or text input" end
        if mode == "grab" then return true, "native session" end
        if s.grab then return false, "minigame has priority" end
        if mode == "escape" then return true, "native capture" end
        if s.captured then return false, "captured" end
        if mode == "recovery" then
            if self.manualRest then return false, "manual Rest" end
            if s.feeding then return false, "feeding or approaching food/water" end
            if s.rescuing then return false,"cub rescue input" end
            if s.ability or s.holding then return false, "native action" end
            if s.attackHeld or now < self.attackUntil then return false, "attack has priority" end
            if now < self.actionUntil or s.afkWalking then return false, "action has priority" end
            if s.climbing or s.flying or s.underwater or s.swimming then return false, "movement transition" end
            -- Native status recovery is separate from the combat HP exclusion.
            if s.combat == true and purpose == "effects" then
                return true,"condition recovery; combat HP remains excluded"
            end
            if s.combat ~= false then return false, s.combat and "combat" or "combat state unknown" end
            return true, "recovery window"
        end
        if self.manualRest or s.rest then return false, "manual Rest" end
        if s.feeding or s.ability then return false, "native action" end
        if s.attackHeld or now < self.attackUntil then return false, "attack has priority" end
        if mode == "climb" or mode == "flight" then
            if s.diveCan and mode == "climb" then return false, "dive has priority" end
            return true, "manual movement request"
        end
        if mode == "afk" then
            if self.menuOpen then return false, "hub menu open" end
            if s.combat ~= false then return false, "combat or unknown combat state" end
            if now-self.lastPhysical < 65 then return false, "manual input" end
            if s.climbing or s.flying or s.swimming or s.holding then return false, "busy" end
            if s.moving and not s.afkWalking then return false, "already moving" end
            if s.hp < s.maxHP*.8 then return false, "health deficit" end
            for _, key in ipairs({ "injury", "bleed", "venom" }) do
                if type(s[key]) ~= "number" or s[key] > .1 then return false, "status or unknown status" end
            end
            if type(s.hunger) ~= "number" or type(s.thirst) ~= "number"
                or s.hunger < 25 or s.thirst < 25 then return false, "needs or unknown needs" end
            if s.nearbyDanger then return false, "animal nearby" end
            return true, "safe activity window"
        end
        return false, "unknown action"
    end
    function p:restLocked(now, duration)
        return now-self.lastRestRelease < (duration or .7)
    end
    return p
end
return Policy
]============]
sources["grab"] = [============[
-- Current v2412 FeralGrabV2UI protocol: begin / strike / res / bite / n / end.
-- Only native issued strikes permit a press; only own-character res grades count.
local Grab = {}
local function finite(n)
    return type(n) == "number" and n == n and math.abs(n) < 1e12
end
local function id(value)
    if type(value) == "number" then return finite(value) and value > 0 and value%1 == 0 end
    if type(value) ~= "string" or #value == 0 or #value > 90 or not value:match("^[%w_%-]+$") then return false end
    local n = tonumber(value)
    return n == nil or (finite(n) and n > 0 and n%1 == 0)
end
Grab.validId = id
function Grab.triangle(at, t0, speed, from)
    local phase = math.max(0, (at-t0)*speed)%2
    local wave = phase <= 1 and phase or 2-phase
    return from == 0 and wave or 1-wave
end
function Grab.crossing(now, p)
    -- First safe entry into the native Perfect interval, not its centre.
    -- The old 25 ms look-ahead could skip a crossing that was about to arrive.
    -- Inspect only the current and next triangle periods, even after a hitch.
    local target = p.from == 0 and p.target or 1-p.target
    local half = p.safeHalf or p.half*.88
    local low,high = math.max(0,target-half),math.min(1,target+half)
    local earliest = math.max(now,p.t0)
    local cycle = math.floor(math.max(0,(earliest-p.t0)*p.speed)/2)
    for period = cycle,cycle+1 do
        for _,range in ipairs({{low,high},{2-high,2-low}}) do
            local opens = p.t0+(2*period+range[1])/p.speed
            local closes = math.min(p.ends-.002,p.t0+(2*period+range[2])/p.speed)
            local at = math.max(earliest,opens)
            if at <= closes then return at,closes end
        end
    end
end
function Grab.new()
    local g = { enabled = false, active = false, pending = nil, session = nil,
        seen = {}, results = {}, grades = { perfect = 0, good = 0, miss = 0 },
        status = "OFF", rejected = 0, presses = 0, lastAt = 0, sequence = 0,
        highestStrike = 0, hunters = 1, pauseUntil = 0, retimed = 0, nativeResumes = 0,
        submitted = {}, history = {}, firstWindows = 0, dispatches = {} }
    function g:reset(reason)
        self.active, self.pending, self.session = false, nil, nil
        self.seen, self.results, self.submitted, self.history = {}, {}, {}, {}
        self.highestStrike,self.pauseUntil = 0,0
        self.status = reason or "waiting for native session"
        self.sequence += 1
    end
    function g:event(event, data, now, generation, perfect, passes, context)
        if not self.enabled or type(event) ~= "string" or type(data) ~= "table" then return false end
        local session = data.f or (event == "begin" and data.id)
        if not id(session) then self.rejected += 1; return false end
        local sessionKey = tostring(session)
        if event == "begin" then
            if tostring(self.session) ~= sessionKey or self.generation ~= generation then
                self:reset()
                self.session, self.generation = session, generation
            end
            self.active, self.lastAt = true, now
            if data.role == "prey" or data.role == "hunter" then self.role = data.role end
            if finite(data.n) and data.n >= 0 and data.n <= 128 then self.hunters = data.n end
            self.status = "native session observed"
            return true
        end
        if not self.active or tostring(self.session) ~= sessionKey or self.generation ~= generation then
            self.rejected += 1; return false
        end
        if event == "end" then self:reset("native session ended"); return true end
        if event == "n" then
            if finite(data.n) and data.n >= 0 and data.n <= 128 then self.hunters = data.n end
            self.lastAt = now -- joining/leaving hunters does not cancel the strike
            return true
        end
        if event == "bite" then
            self.pending, self.lastAt = nil, now
            self.pauseUntil = now+(context and context.bitePause or .6)
            self.status = "native bite pause"
            return true
        end
        if event == "res" then
            local key = tostring(data.k)
            local own = data.mine == true or (context and context.character ~= nil and data.c == context.character)
            if not own or not self.seen[key] or self.results[key] then
                self.rejected += 1; return false
            end
            if self.grades[data.tier] == nil then self.rejected += 1; return false end
            self.results[key] = true
            self.grades[data.tier] += 1
            if self.pending and tostring(self.pending.strike)==key then self.pending=nil end
            self.status = "game reply: " .. data.tier
            self.lastAt = now
            return true
        end
        if event ~= "strike" then return false end
        if not id(data.k) or type(data.k) ~= "number" or self.seen[tostring(data.k)]
            or data.k < self.highestStrike then
            self.rejected += 1; return false
        end
        local duration = data.dur
        if not finite(duration) and finite(data.spd) and data.spd > 0 then duration = (passes or 2.5)/data.spd end
        if not finite(data.t0) or not finite(data.spd) or data.spd <= 0 or data.spd > 100
            or not finite(data.zc) or data.zc < 0 or data.zc > 1
            or not finite(data.zw) or data.zw <= 0 or data.zw >= 1
            or (data.from ~= 0 and data.from ~= 1)
            or not finite(duration) or duration <= 0 or duration > 10
            or data.t0 > now+3 or data.t0+duration < now+.02
            or not finite(perfect) or perfect <= 0 or perfect > 1 then
            self.rejected += 1; return false
        end
        -- Remember every accepted native strike even after manual takeover.
        -- Replayed packets may never generate a second press.
        self.seen[tostring(data.k)] = true
        table.insert(self.history,tostring(data.k))
        if #self.history > 128 then
            local old = table.remove(self.history,1)
            self.seen[old],self.results[old],self.submitted[old] = nil,nil,nil
        end
        self.highestStrike = math.max(self.highestStrike,data.k)
        local p = { session = session, strike = data.k, generation = generation,
            t0 = data.t0, ends = data.t0+duration, speed = data.spd, from = data.from,
            target = data.zc, half = data.zw*.5*perfect }
        p.safeHalf = p.half*.88
        p.at,p.closes = Grab.crossing(math.max(now,self.pauseUntil), p)
        p.firstAt,p.received = p.at,now
        self.pending = p.at and p or nil
        self.lastAt = now
        self.status = p.at and "native strike scheduled; grade unknown" or "no safe crossing"
        return true
    end
    function g:manual()
        self.pending = nil
        self.status = "manual input has priority"
    end
    -- An already running native UI is the authority for joining mid-session.
    -- Only a real native strike is copied, with its original IDs and timestamps.
    function g:syncNative(state, now, generation, perfect, passes, localNow)
        if not self.enabled then return end
        if type(state) ~= "table" then
            if self.active then self:reset("native UI session ended") end
            return
        end
        if state.ended or state.practice or not id(state.id) then
            if self.active and tostring(self.session) == tostring(state.id) then self:reset("native session ended") end
            return
        end
        if not self.active or self.generation ~= generation or tostring(self.session) ~= tostring(state.id) then
            self:event("begin",{f=state.id,role=state.role,n=state.n},now,generation,perfect,passes)
            self.nativeResumes += 1
        end
        self.lastAt = now
        if finite(state.n) and state.n >= 0 and state.n <= 128 then self.hunters = state.n end
        if finite(state.biteUntil) and finite(localNow) and state.biteUntil > localNow then
            self.pauseUntil = math.max(self.pauseUntil,now+math.min(2,state.biteUntil-localNow))
        end
        local strike = state.strike
        if type(strike) ~= "table" or not id(strike.k) then
            self.pending = nil -- native bite/end cleanup wins over an old observer packet
            return
        end
        if self.submitted[tostring(strike.k)] then
            -- Native callbacks can run after our observer in the same event.
            -- Mark only an input that was actually submitted for this strike.
            strike.pressed = true
        end
        if strike.pressed then
            self.seen[tostring(strike.k)] = true
            if self.pending and self.pending.strike == strike.k then self:manual() end
            return
        end
        if not self.seen[tostring(strike.k)] then
            self:event("strike",{f=state.id,k=strike.k,t0=strike.t0,spd=strike.spd,
                from=strike.from,zc=strike.zc,zw=strike.zw,dur=strike.dur},now,generation,perfect,passes)
        end
    end
    function g:tick(now, generation, allowed, send)
        if not self.enabled then if self.active or self.pending then self:reset("OFF") end; return end
        if generation ~= self.generation then self:reset("animal changed"); return end
        if self.active and now-self.lastAt > 8 then self:reset("native session timeout"); return end
        local p = self.pending
        if not allowed then self.status = "input paused; native timing retained"; return end
        if now < self.pauseUntil then return end
        if not p or now+1e-7 < p.at then return end
        if now >= p.ends-.002 then self.pending = nil; self.status = "strike expired"; return end
        local error = math.abs(Grab.triangle(now,p.t0,p.speed,p.from)-p.target)
        if error > (p.safeHalf or p.half*.88)+1e-7 then
            if now > (p.closes or p.at) then
                local nextAt,closes = Grab.crossing(now,p)
                if nextAt then
                    p.at,p.closes,p.later = nextAt,closes,true
                    self.retimed += 1
                    self.status = "next native crossing scheduled"
                else self.pending = nil; self.status = "no valid crossing left" end
            end
            return
        end
        local sequence=self.sequence
        self.pending = nil -- clear before calling out, including re-entrant replies
        local ok, sent = pcall(send, p.session, p.strike, now)
        if ok and sent == true then
            self.presses += 1
            if self.sequence==sequence then self.submitted[tostring(p.strike)] = true end
            if not p.later then self.firstWindows += 1 end
            table.insert(self.dispatches,{delay=now-p.received,afterOpening=now-p.at,
                later=p.later==true,error=error,perfectHalf=p.half})
            if #self.dispatches>32 then table.remove(self.dispatches,1) end
            if self.sequence==sequence and not self.results[tostring(p.strike)] then self.status = "press sent; game grade unknown" end
        else self.status = "native press unavailable" end
        self.lastAt = now
    end
    return g
end
return Grab
]============]
sources["grab_input"] = [============[
-- Reversible native input separation. No global function hooks or fake bites.
-- Temporarily remove the native MouseButton1 minigame action.
-- Native Space/gamepad presses are retained under this owner's separate binding.
local GrabInput = {}
function GrabInput.new(bridge,token)
    local i = { lease = nil, status = "waiting for native session", name = "FERAL_GRAB_INPUT_" .. token }
    function i:release()
        bridge:unbindGrabManual(self.name)
        local lease = self.lease
        self.lease = nil
        if not lease then return end
        local current,known = lease.controller.state()
        local same=current==lease.state or current==nil and known~=true
        if same and lease.state.ended ~= true and not bridge:nativeGrabBound()
            and (not lease.controller.script or lease.controller.script.Parent ~= nil)
            and bridge.player.Character == lease.character then
            pcall(lease.controller.bind,true)
        end
        self.status = "native inputs restored"
    end
    function i:controller(now)
        return bridge:nativeGrabController(now)
    end
    function i:update(grab,now,native,state)
        if not grab.enabled or not grab.active then
            if self.lease then self:release() end
            return false
        end
        native = native or self:controller(now)
        state = state or native and native.state()
        if not state or state.ended or tostring(state.id) ~= tostring(grab.session) then
            local lease=self.lease
            if not state and lease and lease.controller==native and not lease.state.ended
                and tostring(lease.state.id)==tostring(grab.session) and bridge.player.Character==lease.character then
                self.status="native state temporarily unreadable; timing retained"
                return true
            end
            if self.lease then self:release() end
            self.status = "native input isolation unavailable"
            return false
        end
        if self.lease and (self.lease.controller ~= native or self.lease.state ~= state) then self:release() end
        local check=not self.lease or now >= (self.nextBindingCheck or 0)
        if check then self.nextBindingCheck=now+.1 end
        if check and bridge:nativeGrabBound() then
            local lease = { controller = native,state = state,character = bridge.player.Character }
            self.lease = lease -- record before calling out so partial failure unwinds
            local ok = pcall(native.bind,false)
            if not ok or bridge:nativeGrabBound() then
                self:release()
                self.status = "native minigame input could not be separated"
                return false
            end
            local bound = pcall(bridge.bindGrabManual,bridge,self.name,function()
                if not grab.enabled or not grab.active or self.lease ~= lease or bridge:grabTextFocused() then return end
                local current = native.state()
                if current ~= state or current.ended or tostring(current.id) ~= tostring(grab.session) then return end
                grab:manual()
                pcall(native.press)
            end)
            if not bound then self:release();self.status = "manual input binding unavailable";return false end
        end
        if not self.lease then self.status = "waiting for native input binding"; return false end
        self.status = "bite clicks separated from minigame presses"
        return true
    end
    function i:close() self:release() end
    return i
end
return GrabInput
]============]
sources["recovery"] = [============[
-- A single native Rest owner. Manual Rest is never cancelled or masked.
local Recovery = {}
local function finite(n)
    return type(n)=="number" and n==n and math.abs(n)<1e12
end
function Recovery.new(bridge, policy, ledger)
    local r = { state = "OFF", owned = nil, enabled = false, echoes = 0,
        backoffUntil = 0, releaseAt = -math.huge, signalAt = -math.huge,
        nativeEchoObserved = false, writes = 0, nextRefresh = 0, observations = {},
        progressWatch = nil, repairChar = nil, repairAttempts = 0,
        noProgressReported = false }
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
    function r:release(reason, now)
        local char = self.owned
        self.owned = nil
        self.progressWatch = nil
        if char then
            self.releaseAt, policy.lastRestRelease = now, now
            bridge:rest(char, false)
            -- Only an echo attributed to this owner's Rest request is cleared.
            if not policy.manualRest then bridge:maskRest(char) end
            self.poseUntil = now+.35 -- let the animator consume the reset after release
            ledger:event("owned_rest_released", now, { reason = reason })
        end
        self.state = reason or "OFF"
    end
    function r:manual(now)
        -- Yield ownership without emitting false; native/manual Rest takes over.
        self.owned = nil
        self.lastAutomaticCharacter = nil
        self:clearPose()
        policy.manualRest = true
        self.state = "MANUAL"
        ledger:event("manual_rest_preserved", now)
    end
    function r:echo(s, now)
        if not s or not s.char then return end
        if policy.manualRest then return end
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
            or previous.moving ~= s.moving or previous.maxHP ~= s.maxHP or now-previous.now > 1.5 then
            self.observations = {};return
        end
        if mode == "idle" then self.observations = {};return end
        for _,key in ipairs({"hp","injury","bleed","venom"}) do
            local a,b = previous[key],s[key]
            if key == "hp" and s.combat ~= false or type(a) ~= "number" or type(b) ~= "number"
                or a ~= a or b ~= b or math.abs(a)>=1e12 or math.abs(b)>=1e12
                or key ~= "hp" and a <= 0 then self.observations[key]=nil;continue end
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
    function r:watchProgress(s,now)
        -- These are measured replicated values, not native Rest acknowledgements.
        -- Keep a baseline until a meaningful cumulative improvement is observed.
        local p=self.progressWatch
        if not p or p.char~=s.char then
            self.progressWatch={char=s.char,progressAt=now,maxHP=s.maxHP,
                hp=s.hp,injury=s.injury,bleed=s.bleed,venom=s.venom}
            return
        end
        if p.maxHP~=s.maxHP then
            -- Growth may increase absolute HP without repairing a deficit.
            p.maxHP,p.hp,p.progressAt=s.maxHP,s.hp,now
        end
        local improved=false
        if s.combat==false and finite(s.hp) and finite(p.hp) then
            if s.hp>=p.hp+.02 then improved=true;p.hp=s.hp
            elseif s.hp<p.hp-.2 then p.hp=s.hp;p.progressAt=now end
        else p.hp=s.hp end
        for _,key in ipairs({"injury","bleed","venom"}) do
            local previous,current=p[key],s[key]
            if finite(previous) and finite(current) then
                if previous>.1 and current<=previous-.015 then
                    improved=true;p[key]=current
                elseif current>previous+.15 then
                    -- A new or worsening condition starts a fresh observation.
                    p[key]=current;p.progressAt=now
                end
            else p[key]=current end
        end
        if improved then
            p.progressAt=now
            self.repairAttempts,self.noProgressReported=0,false
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
        if (self.repairAttempts or 0)>0 then
            message ..= " · bounded no-progress repair "..tostring(self.repairAttempts).."/2"
        end
        if self.noProgressReported then message ..= " · no improvement confirmed" end
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
        if s and s.alive then
            if self.repairChar~=s.char then
                self.repairChar,self.repairAttempts,self.noProgressReported=s.char,0,false
                self.progressWatch=nil
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
                bridge:rest(s.char,false);bridge:maskRest(s.char)
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
        if self.owned then self:watchProgress(s,now) end
        if not self.owned then
            -- Stage masking ownership BEFORE requesting native Rest.
            if not self:holdPose(s.char,now) then
                self.state="native pose control unavailable";self.backoffUntil=now+3;return
            end
            self.owned = s.char
            self.lastAutomaticCharacter = s.char
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
            self:watchProgress(s,now)
            ledger:event("native_rest_requested", now, { moving = s.moving,purpose = self.purpose,combatHPExcluded = s.combat ~= false })
        elseif now >= self.nextRefresh then
            local stalled=self.progressWatch and now-self.progressWatch.progressAt>=12
            if stalled then
                if self.repairAttempts<2 then
                    -- Release once, respect the native stand-up interval,
                    -- and re-arm only in the next eligible recovery window.
                    self.repairAttempts+=1
                    local attempt=self.repairAttempts
                    self:release("no observed recovery; retrying native Rest",now)
                    self.backoffUntil=now+.85
                    ledger:event("native_rest_no_progress_repair",now,{attempt=attempt})
                    return
                elseif not self.noProgressReported then
                    self.noProgressReported=true
                    ledger:event("native_rest_no_progress",now,{restarts=self.repairAttempts})
                end
            end
            -- Keep ownership after exhausting bounded retries; no endless
            -- toggling or false claims of health/effect improvement.
            self.nextRefresh = now+5
            if bridge:rest(s.char, true) then ledger:event("native_rest_renewed", now) end
        end
    end
    function r:close(now)
        self.enabled = false
        self:release("CLOSED", now)
        self:clearPose()
        self.previous,self.observations,self.lastAutomaticCharacter = nil,{},nil
        self.progressWatch,self.repairChar,self.repairAttempts = nil,nil,0
    end
    return r
end
return Recovery
]============]
sources["feeding"] = [============[
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
    function f:tick(s,now,externalCare)
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
        -- Territory Care owns repair/cancellation for its own feeding session.
        -- Keep native approach protection and observations, without a second
        -- stop/start repair racing the farming controller.
        if externalCare or value >= maximum-.5 or now-session.progressAt < 4.5 then return end
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
]============]
sources["combat_input"] = [============[
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
]============]
sources["rescue"] = [============[
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
]============]
sources["features"] = [============[
-- Every shared client-config mutation goes through one lease manager.
local Features = {}
-- Native tables can alias the same consumption profile in several paths.
-- Coalesce equal intents before the strict lease manager reserves a field.
-- Conflicting values remain an error; never silently choose the last value.
function Features.uniquePlan(plan)
    local result,seen={},{}
    for _,item in ipairs(plan) do
        if type(item.target)~="table" or item.key==nil then return nil,"invalid stamina field" end
        local fields=seen[item.target]
        if not fields then fields={};seen[item.target]=fields end
        local previous=fields[item.key]
        if previous then
            if previous.value~=item.value or previous.kind~=item.kind then
                return nil,"conflicting aliased stamina field: "..tostring(item.key)
            end
        else
            fields[item.key]=item;table.insert(result,item)
        end
    end
    return result
end
function Features.new(Core, bridge, registry)
    local f = { leases = Core.leases(), originalCombat = nil, combat = nil, flag = nil,
        nextReconcile = 0, configIdentity = {}, failures = {} }
    local function entry(target, key, value, kind)
        return { target = target, key = key, value = value, kind = kind }
    end
    local function numeric(t, keys)
        if type(t) ~= "table" then return false end
        for _, key in ipairs(keys) do if not Core.finite(t[key]) then return false end end
        return true
    end
    function f:releaseFlag()
        local flag = self.flag
        self.flag = nil
        if flag then bridge:restoreAttribute(flag.char, "WolfDbgNoStamina", true, flag.before) end
    end
    function f:flagCharacter(s, on)
        if self.flag and (not on or self.flag.char ~= s.char) then self:releaseFlag() end
        if on and s.alive then
            if not self.flag then
                self.flag = { char = s.char, before = bridge:attribute(s.char, "WolfDbgNoStamina") }
            end
            return bridge:setAttribute(s.char, "WolfDbgNoStamina", true)
        end
        return not on
    end
    function f:plan(id)
        local n = bridge:config("NeedsConfig")
        if id == "reach" then
            local c = bridge:config("CombatConfig")
            if not numeric(c, { "REACH", "HIT_SCALE", "CONE", "SLACK", "MAX_DY" })
                or type(c.bodyGap) ~= "function" then return nil, "CombatConfig schema unavailable" end
            local original = {}
            for k, v in pairs(c) do original[k] = v end
            -- Keep stock-reference hints conservative even if a native helper
            -- closes over the shared config table that we are about to tune.
            if type(c.coneFor) == "function" then
                local stock = c.coneFor
                original.coneFor = function(char)
                    local ok,value = pcall(stock,char)
                    return ok and Core.finite(value) and math.min(value,original.CONE) or original.CONE
                end
            end
            self.originalCombat, self.combat = original, c
            local nativeCone = c.coneFor
            local desiredCone = math.max(c.CONE,170)
            local plan = {
                entry(c,"REACH",math.min(c.REACH*1.50,3.2),"number"),
                entry(c,"HIT_SCALE",math.min(c.HIT_SCALE*1.30,2.1),"number"),
                entry(c,"CONE",desiredCone,"number"),
                entry(c,"SLACK",c.SLACK+.75,"number"),
                entry(c,"MAX_DY",math.min(c.MAX_DY*1.50,4.5),"number"),
                entry(c,"bodyGap",function(part,flat)
                    local char = part and part.Parent
                    if char and not bridge:combatEligible(char) then return math.huge end
                    local gap = original.bodyGap(part,flat)
                    return Core.finite(gap) and gap-.90 or gap
                end,"function"),
            }
            -- FeralBiteLocal is predictive presentation, not a hit acknowledgement.
            -- Preserve the native FeralHit response effects; remove premature impacts.
            if type(c.HIT2) == "table" and type(c.HIT2.PREDICT) == "boolean" then
                table.insert(plan,entry(c.HIT2,"PREDICT",false,"boolean"))
            end
            table.insert(plan,entry(c,"coneFor",function(char)
                local value = desiredCone
                if type(nativeCone) == "function" then
                    local ok,native = pcall(nativeCone,char)
                    if ok and Core.finite(native) then value = math.max(value,native) end
                end
                return value
            end))
            -- A single candidate selected from the shared snapshot feeds both
            -- climb aim and the guide; no extra tree scan or hit request.
            table.insert(plan, entry(c,"biteLook",function(char, forward)
                local native = forward
                if type(original.biteLook) == "function" then
                    local ok,value = pcall(original.biteLook,char,forward)
                    if ok and typeof(value) == "Vector3" then native = value end
                end
                local target = bridge.reachTarget
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if target and target.char and target.char.Parent and target.root.Parent and root
                    and bridge:combatEligible(target.char) then
                    local diff = target.root.Position-root.Position
                    local flat = Vector3.new(diff.X,0,diff.Z)
                    local look = Vector3.new(native.X,0,native.Z)
                    if diff.Magnitude <= 45 and flat.Magnitude > .05
                        and (target.sameTree or look.Magnitude < .01 or look.Unit:Dot(flat.Unit) < .3) then
                        return flat.Unit
                    end
                end
                return native
            end))
            table.insert(plan, entry(c,"dyMult",function(char)
                local native = 1
                if type(original.dyMult) == "function" then
                    local ok,value = pcall(original.dyMult,char)
                    if ok and Core.finite(value) and value > 0 then native = value end
                end
                if bridge:isClimbing(char) and bridge.treeTarget and bridge.treeTarget.sameTree then
                    return math.min(native*2.50,3.5)
                end
                return native*1.35
            end))
            return plan
        elseif id == "stamina" then
            if not numeric(n, { "STAMINA_REGEN", "STAMINA_REGEN_DELAY", "STAMINA_SPRINT_DRAIN",
                "STAMINA_JUMP_COST", "STAMINA_LOW_NEEDS" }) then return nil, "NeedsConfig stamina schema unavailable" end
            local plan = {
                entry(n,"STAMINA_REGEN",n.STAMINA_REGEN*3,"number"),
                entry(n,"STAMINA_REGEN_DELAY",0,"number"),
                entry(n,"STAMINA_SPRINT_DRAIN",0,"number"),
                entry(n,"STAMINA_JUMP_COST",0,"number"),
                entry(n,"STAMINA_LOW_NEEDS",1,"number"),
            }
            local flight = bridge:config("FlightConfig")
            if numeric(flight, { "FLAP_DRAIN" }) then table.insert(plan,entry(flight,"FLAP_DRAIN",0,"number")) end
            -- v2412 WolfController has distinct swim, climb and venom paths.
            -- Change only recognised consumption inputs; preserve native
            -- species abilities, immunity, resource values and damage rules.
            local function zero(t,key)
                if type(t)=="table" and Core.finite(t[key]) and t[key]>=0 then
                    table.insert(plan,entry(t,key,0,"number"))
                end
            end
            zero(n,"SWIM_DRAIN_MULT");zero(n,"WATER_DRAIN_NONSWIM")
            local passive=bridge:config("PassiveConfig")
            local climber=passive and passive.CLIMBER
            if type(climber)=="table" then
                for level=1,3 do
                    local profile=type(climber.levels)=="table" and climber.levels[level]
                    if type(profile)=="table" then
                        zero(profile,"drain")
                        if profile.stamina=="drain" then table.insert(plan,entry(profile,"stamina","walk","string")) end
                    end
                end
                if type(climber.CLIMB_SPRINT)=="table" then
                    for species,profile in pairs(climber.CLIMB_SPRINT) do
                        if type(species)=="string" then zero(profile,"DRAIN") end
                    end
                end
            end
            local venom=bridge:config("VenomConfig")
            for _,key in ipairs({"SPRINT_DRAIN","OTHER_DRAIN","BITE_DRAIN"}) do zero(venom,key) end
            local status=bridge:config("StatusConfig")
            for _,key in ipairs({"STAMINA_BASE","STAMINA_PER_POINT"}) do zero(status and status.VENOM,key) end
            return Features.uniquePlan(plan)
        elseif id == "recovery" then
            if not numeric(n, { "HEALTH_REGEN", "HEALTH_REST_MULT" }) then return nil, "NeedsConfig recovery schema unavailable" end
            if n.HEALTH_REST_MULT < 1 then return nil,"native HP Rest multiplier unavailable" end
            -- Keep the game's real Rest factor. Flattening it to one removed
            -- the distinction between an actual Rest window and a local edit.
            -- Cap only the local Rest reference at 2x; never edit combat exclusion.
            return { entry(n,"HEALTH_REGEN",n.HEALTH_REGEN*math.min(1,2/n.HEALTH_REST_MULT),"number"),
                entry(n,"HEALTH_REST_MULT",n.HEALTH_REST_MULT,"number") }
        elseif id == "effects" then
            local status = bridge:config("StatusConfig")
            local plan = {}
            for _, pair in ipairs({ {"INJURY","HEAL"}, {"BLEED","CLOT"}, {"VENOM","FADE"} }) do
                local c = status and status[pair[1]]
                if not numeric(c,{pair[2],"REST_MULT"}) or c[pair[2]] <= 0 then
                    return nil, "StatusConfig " .. pair[1] .. " schema unavailable"
                end
                if c.REST_MULT < 1 then return nil,"native condition Rest multiplier unavailable" end
                -- Preserve native Rest=4 and ordinary base decay. Never
                -- advertise a faster HUD calculation as a gameplay cure.
                table.insert(plan,entry(c,pair[2],c[pair[2]]*math.min(1,4/c.REST_MULT),"number"))
                table.insert(plan,entry(c,"REST_MULT",c.REST_MULT,"number"))
            end
            return plan
        elseif id == "mobility" then
            local status = bridge:config("StatusConfig")
            if not numeric(n,{"HURT_SLOW"}) or not numeric(status and status.INJURY,{"SLOW_PER_POINT"}) then
                return nil, "movement slowdown schema unavailable"
            end
            return { entry(n,"HURT_SLOW",0,"number"), entry(status.INJURY,"SLOW_PER_POINT",0,"number") }
        elseif id == "speed" then
            if not numeric(n,{"RUN_SPEED","SWIM_SPEED"}) or n.RUN_SPEED <= 0 or n.RUN_SPEED > 4
                or n.SWIM_SPEED <= 0 or n.SWIM_SPEED > 4 then return nil, "speed schema unavailable" end
            return { entry(n,"RUN_SPEED",n.RUN_SPEED*1.15,"number"), entry(n,"SWIM_SPEED",n.SWIM_SPEED*1.15,"number") }
        elseif id == "leap" then
            local c = bridge:config("JumpLeapConfig")
            if not numeric(c,{"DEFAULT","MAX_RUN_SHARE"}) or c.ON ~= true or type(c.BODY_LENGTHS) ~= "table" then
                return nil, "leap schema unavailable"
            end
            local plan = { entry(c,"DEFAULT",c.DEFAULT*1.15,"number"),
                entry(c,"MAX_RUN_SHARE",c.MAX_RUN_SHARE*1.15,"number") }
            for name, value in pairs(c.BODY_LENGTHS) do
                if Core.finite(value) and value >= 0 and value <= 10 then
                    table.insert(plan,entry(c.BODY_LENGTHS,name,value*1.15,"number"))
                end
            end
            return plan
        elseif id == "climb" then
            local passive = bridge:config("PassiveConfig")
            local c = passive and passive.CLIMBER
            if not numeric(c,{"GRAB_REACH","E_REACH","GRAB_FACING","MOUNT_TIME"}) or type(c.levels) ~= "table" then
                return nil, "climb schema unavailable"
            end
            local plan = {
                entry(c,"GRAB_REACH",math.min(1.25,c.GRAB_REACH*1.3),"number"),
                entry(c,"E_REACH",math.min(2.1,c.E_REACH*1.25),"number"),
                entry(c,"GRAB_FACING",math.max(.25,c.GRAB_FACING*.58),"number"),
                entry(c,"MOUNT_TIME",math.max(.22,c.MOUNT_TIME*.75),"number"),
            }
            for _, level in ipairs({1,2}) do
                if type(c.levels[level]) == "table" then table.insert(plan,entry(c.levels[level],"sprintGrab",true)) end
            end
            return plan
        end
        return nil, "unknown config feature"
    end
    -- Captured v2412 WolfMove forces its run boolean off while CrushAt is
    -- active (186:2394-2402), then uses 16.8 / 42 * scaled(gait) * walkMul.
    -- SPEED_CAP is not consumed by that branch. Adapt its actual scalar input
    -- to the requested native tier, preserving the native ability/guard state.
    function f:hippoInput(s,key)
        if not s.alive or s.species~="Hippo" or s.chat or s.gameMenu or s.captured or s.rest then return end
        if key==Enum.KeyCode.X then
            if self.hippoIntentChar~=s.char then self.hippoBurstIntent=s.burst==true end
            self.hippoIntentChar=s.char;self.hippoBurstIntent=not self.hippoBurstIntent
        elseif key==Enum.KeyCode.Z then
            self.hippoIntentChar=s.char;self.hippoBurstIntent=false
        end
    end
    function f:hippoAttribute(s)
        if s.species~="Hippo" then self.hippoIntentChar,self.hippoBurstIntent=nil,nil;return end
        local at=bridge:attribute(s.char,"FeralCrushAt")
        if at~=nil and at~=false then
            if self.hippoIntentChar~=s.char or self.hippoBurstIntent==nil then
                self.hippoIntentChar=s.char;self.hippoBurstIntent=s.burst==true
            end
            self.hippoCharge=at
        else self.hippoCharge=nil;self.hippoBurstIntent=nil end
    end
    function f:reconcileHippoGait(s)
        local cfg=s.alive and s.species=="Hippo" and bridge:config("Species")
        local hippo=cfg and cfg.List and cfg.List.Hippo
        if self.hippoScaled and (not hippo or self.hippoScaled.cfg~=cfg or self.hippoScaled.char~=s.char
            or self.hippoScaled.profile~=hippo) then
            self.leases:release("hippoGait");self.hippoScaled=nil
        end
        if self.hippoGaitConflict and self.hippoGaitConflict.cfg==cfg and self.hippoGaitConflict.char==s.char then return end
        if not hippo or type(cfg.scaled)~="function" or not numeric(hippo,{"speed","gait"})
            or game.PlaceVersion~=2412 then return end
        if self.hippoScaled then
            if not self.leases:valid("hippoGait") then self.leases:release("hippoGait");self.hippoScaled=nil;self.hippoGaitConflict={cfg=cfg,char=s.char} end
            return
        end
        local original=cfg.scaled
        local char=s.char
        local wrapper=function(species,field,growth,...)
            local result=original(species,field,growth,...)
            if species~="Hippo" or (field~="gait" and field~="swimSpeed") or bridge.player.Character~=char
                or not char.Parent or game.PlaceVersion~=2412 or cfg.List.Hippo~=hippo then return result end
            local charge=bridge:attribute(char,"FeralCrushAt")
            if charge==nil or charge==false or bridge:attribute(char,"WolfRest")==true
                or bridge:attribute(char,"FeralCrouch")==true
                or bridge:attribute(char,"FeralPinned")==true or bridge:attribute(char,"FeralCarried")==true
                or bridge:attribute(char,"FeralDragged")==true or bridge.UserInputService:GetFocusedTextBox()
                or bridge:attribute(bridge.player,"FeralMenuOpen")==true then return result end
            local combat=bridge:config("CombatConfig")
            if combat and type(combat.hobbled)=="function" then
                local ok,hobbled=pcall(combat.hobbled,char)
                if not ok or hobbled then return result end
            end
            local shift=false
            pcall(function()shift=bridge.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)end)
            local burst=self.hippoIntentChar==char and self.hippoBurstIntent==true
            local denial=bridge:attribute(bridge.player,"HudBurstNo")
            if denial==true or Core.finite(denial) and bridge.clock()>=denial and bridge.clock()-denial<1.7
                or bridge:attribute(char,"StaminaOut")==true then burst=false;self.hippoBurstIntent=false end
            if not shift and not burst then return result end
            local needs=bridge:config("NeedsConfig")
            local boost=needs and needs.BURST
            local multiplier=1
            if burst then
                local key=field=="swimSpeed" and "SWIM_SPEED" or "SPEED"
                local n=boost and (boost[key] or boost.SPEED)
                if not boost or boost.ENABLED~=true or not Core.finite(n) or n<1 or n>3 then
                    if not shift then return result end
                    burst=false
                else multiplier=n end
            end
            if field=="swimSpeed" then
                if not Core.finite(hippo.swimSprint) or hippo.swimSprint<=0 then return result end
                local speed=original(species,"swimSprint",growth,...)
                return Core.finite(speed) and speed*multiplier or result
            end
            local walk=hippo.walkMul
            if type(hippo.walkMulStage)=="table" and type(cfg.stage)=="function" then
                local ok,stage=pcall(cfg.stage,growth,species);if ok then walk=hippo.walkMulStage[stage] or walk end
            end
            local scale=bridge:attribute(char,"WalkKMul")
            if scale~=nil and not Core.finite(scale) then return result end
            walk=(Core.finite(walk) and walk or 1)*(scale or 1)
            local run=needs and needs.RUN_SPEED
            local speed=original(species,"speed",growth,...)
            if not Core.finite(walk) or walk<=0 or not Core.finite(run) or run<=0 or not Core.finite(speed) then return result end
            self.hippoStatus=burst and "BURST_SPEED_REQUESTED" or "SPRINT_SPEED_REQUESTED"
            return speed*run*multiplier*(42/16.8)/walk
        end
        local ok=self.leases:apply("hippoGait",{entry(cfg,"scaled",wrapper,"function")})
        if ok then self.hippoScaled={cfg=cfg,char=char,profile=hippo,original=original} end
    end
    -- Hippo Crusher Bite has a v2412 native SPEED_CAP="trot" profile.
    -- A separate owner avoids touching other species or requiring a new toggle.
    -- Use the fastest native locomotion tier (burst) as the client-side cap.
    -- This does not activate a burst gait; the server may still impose a slow.
    function f:reconcileHippo(s)
        self:reconcileHippoGait(s)
        local hippo=s.alive and s.species=="Hippo"
        local ability=hippo and bridge:config("AbilityConfig")
        local base=hippo and bridge:config("AbilityConfigBase")
        local profile
        if hippo then
            for _,cfg in ipairs({ability or false,base or false}) do
                if type(cfg)=="table" then
                    local candidate=cfg.CrusherBite
                        or (type(cfg.Hippo)=="table" and cfg.Hippo.CrusherBite)
                        or cfg.CRUSHER
                    if type(candidate)=="table" and (candidate.SPEED_CAP=="trot"
                        or candidate==self.hippoProfile and candidate.SPEED_CAP=="burst") then
                        profile=candidate;break
                    end
                end
            end
        end
        if self.hippoProfile and (not hippo or not profile or self.hippoProfile~=profile
            or self.hippoCharacter~=s.char) then
            self.leases:release("hippoCrush")
            self.hippoProfile,self.hippoCharacter=nil,nil
        end
        if not hippo then self.hippoStatus="OFF";return end
        if self.leases.owners.hippoCrush then
            if self.leases:valid("hippoCrush") then
                self.hippoStatus="CLIENT";return
            end
            -- An external edit owns this value now; don't overwrite it.
            self.leases:release("hippoCrush")
            self.hippoProfile,self.hippoCharacter=nil,nil
            self.hippoStatus="CONFLICT";return
        end
        if not profile then self.hippoStatus="WAITING";return end
        -- The native speed tier is read from the same scoped Crusher Bite
        -- profile. Do not force Humanoid.WalkSpeed or manipulate ability remotes.
        local applied=self.leases:apply("hippoCrush",{
            entry(profile,"SPEED_CAP","burst","string")
        })
        self.hippoStatus=applied and "CLIENT" or "WAITING"
        if applied then self.hippoProfile,self.hippoCharacter=profile,s.char end
    end
    function f:reconcile(s, now, force)
        if not force and now < self.nextReconcile then return end
        self.nextReconcile = now+1.25
        for _, id in ipairs({ "reach","stamina","recovery","effects","mobility","speed","leap","climb" }) do
            local dependencies = {
                reach = {"CombatConfig"},stamina = {"NeedsConfig","FlightConfig","PassiveConfig","VenomConfig","StatusConfig"},
                recovery = {"NeedsConfig"},effects = {"StatusConfig"},
                mobility = {"NeedsConfig","StatusConfig"},speed = {"NeedsConfig"},
                leap = {"JumpLeapConfig"},climb = {"PassiveConfig"},
            }
            local identity,changed = {},false
            for _,name in ipairs(dependencies[id]) do
                identity[name] = bridge:config(name) or false
                if self.configIdentity[id] and self.configIdentity[id][name] ~= identity[name] then changed = true end
            end
            if id=="stamina" then
                local passive=identity.PassiveConfig
                local climb=type(passive)=="table" and type(passive.CLIMBER)=="table" and passive.CLIMBER
                identity.climb=climb or false
                identity.levels=climb and climb.levels or false
                identity.sprint=climb and climb.CLIMB_SPRINT or false
                identity.venom=type(identity.StatusConfig)=="table" and identity.StatusConfig.VENOM or false
                for _,name in ipairs({"climb","levels","sprint","venom"}) do
                    if self.configIdentity[id] and self.configIdentity[id][name]~=identity[name] then changed=true end
                end
                for level=1,3 do
                    local name="climbLevel"..level
                    identity[name]=climb and type(climb.levels)=="table" and climb.levels[level] or false
                    if self.configIdentity[id] and self.configIdentity[id][name]~=identity[name] then changed=true end
                end
            end
            if changed then self.leases:release(id);self.failures[id] = nil end
            self.configIdentity[id] = identity
            local record = registry.byId[id]
            if not record.requested then
                self.leases:release(id)
                registry:ack(id,false,"OFF","original client inputs restored")
                self.failures[id] = nil
            elseif self.failures[id] == "conflict" then
                registry:ack(id,false,"UNAVAILABLE","external config changed; toggle to retry")
            elseif self.leases.owners[id] then
                if self.leases:valid(id) then
                    registry:ack(id,true,"CLIENT","local config acknowledged; gameplay unverified")
                else
                    self.leases:release(id)
                    self.failures[id] = "conflict"
                    registry:ack(id,false,"UNAVAILABLE","external config changed")
                end
            else
                local ok, plan, why = pcall(self.plan,self,id)
                if not ok then why, plan = tostring(plan), nil end
                if plan then
                    local applied, reason = self.leases:apply(id,plan)
                    registry:ack(id,applied,applied and "CLIENT" or "UNAVAILABLE",reason)
                else registry:ack(id,false,"WAITING",why) end
            end
        end
        self:reconcileHippo(s)
        local stamina = registry.byId.stamina
        if not self:flagCharacter(s,stamina.requested and stamina.applied) and stamina.requested then
            registry:ack("stamina",false,"PARTIAL","local config applied; character flag unavailable")
        end
    end
    function f:close()
        self:releaseFlag()
        self.leases:close()
    end
    return f
end
return Features
]============]
sources["roblox"] = [============[
-- Roblox boundary. Staging creates only inactive, owner-scoped listeners.
local Roblox = {}
function Roblox.new(Core, environment)
    local b = { Core = Core, env = environment, generation = 0, modules = {},
        remoteConnections = {}, characterScope = nil, treeTarget = nil, tracked = {} }
    for _, name in ipairs({ "Players","ReplicatedStorage","RunService","UserInputService",
        "ContextActionService","HttpService","Workspace" }) do b[name] = game:GetService(name) end
    b.player = assert(b.Players.LocalPlayer,"LocalPlayer unavailable")
    b.clock = os.clock
    function b:delay(seconds,fn)
        if type(task)~="table" or type(task.delay)~="function" then return nil end
        local ok,handle=pcall(task.delay,seconds,fn)
        return ok and handle or nil
    end
    function b:cancelDelay(handle)
        if handle and type(task)=="table" and type(task.cancel)=="function" then pcall(task.cancel,handle) end
    end
    function b:serverNow()
        local ok, now = pcall(function() return self.Workspace:GetServerTimeNow() end)
        return ok and Core.finite(now) and now or nil
    end
    function b:attribute(object,key)
        if not object then return nil end
        local ok,value = pcall(function() return object:GetAttribute(key) end)
        if ok then return value end
        return nil
    end
    function b:setAttribute(object,key,value)
        if not object or not object.Parent then return false end
        local ok = pcall(function() object:SetAttribute(key,value) end)
        return ok and self:attribute(object,key) == value
    end
    function b:restoreAttribute(object,key,owned,original)
        if object and object.Parent and self:attribute(object,key) == owned then
            return self:setAttribute(object,key,original)
        end
        return false
    end
    function b:config(name)
        local world = self.ReplicatedStorage:FindFirstChild("FeralWorld")
        local object = world and world:FindFirstChild(name)
        if not object or not object:IsA("ModuleScript") then self.modules[name] = nil; return nil end
        local cached = self.modules[name]
        if cached and cached.object == object then return cached.value end
        local ok,value = pcall(require,object)
        if not ok or type(value) ~= "table" then return nil end
        self.modules[name] = { object = object, value = value }
        return value
    end
    function b:rest(char,on)
        if char ~= self.player.Character or not char or not char.Parent then return false end
        return self:fire("WolfActions","Rest",on)
    end
    function b:maskRest(char)
        if char ~= self.player.Character then return false end
        if self:attribute(char,"WolfRest") ~= true then return true end
        return self:setAttribute(char,"WolfRest",false)
    end
    function b:fire(name,...)
        local remote = self.ReplicatedStorage:FindFirstChild(name)
        if not remote or not remote:IsA("RemoteEvent") then return false end
        local args = table.pack(...)
        return pcall(function() remote:FireServer(table.unpack(args,1,args.n)) end)
    end
    function b:hasRemote(name)
        local remote = self.ReplicatedStorage:FindFirstChild(name)
        return remote and remote:IsA("RemoteEvent") or false
    end
    function b:nativeGrabBound()
        return self.ContextActionService:GetAllBoundActionInfo().FeralGrabV2Press ~= nil
    end
    function b:markGrabPress(session,strike,now)
        local native = self:nativeGrabController(now)
        local state = native and native.state()
        if state and not state.ended and tostring(state.id) == tostring(session)
            and type(state.strike) == "table" and state.strike.k == strike then
            state.strike.pressed = true -- an actual submitted input, never a fabricated grade
        end
    end
    function b:grabTextFocused()
        return self.UserInputService:GetFocusedTextBox() ~= nil
            or self:attribute(self.player,"FeralMenuOpen") == true
    end
    function b:grabSnapshot(now)
        local char=self.player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        return {now=now,serverNow=self:serverNow(),char=char,generation=self.generation,
            alive=char~=nil and char.Parent~=nil and hum~=nil and hum.Health>0,
            chat=self.UserInputService:GetFocusedTextBox()~=nil,
            gameMenu=self:attribute(self.player,"FeralMenuOpen")==true}
    end
    function b:unbindGrabManual(name)
        self.ContextActionService:UnbindAction(name)
    end
    function b:bindGrabManual(name,press)
        self.ContextActionService:BindActionAtPriority(name,function(_,state)
            if state == Enum.UserInputState.Begin then press() end
            return Enum.ContextActionResult.Sink
        end,false,3000,Enum.KeyCode.Space,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonR2)
    end
    function b:nativeGrabController(now)
        local scripts = self.player:FindFirstChild("PlayerScripts")
        local scriptObject = scripts and scripts:FindFirstChild("FeralGrabV2UI")
        local currentRemote=self.ReplicatedStorage:FindFirstChild("FeralGrabV2")
        if self.grabController and self.grabController.remote~=currentRemote then
            self.grabController,self.grabDiscovery,self.nextGrabDiscovery=nil,nil,0
        end
        if self.grabController and self.grabController.script == scriptObject and scriptObject.Parent then
            return self.grabController
        end
        self.grabController = nil
        if not scriptObject then self.grabDiscovery = nil; return nil end
        if self.grabDiscovery and self.grabDiscovery.script ~= scriptObject then self.grabDiscovery = nil end
        if not self.grabDiscovery and now < (self.nextGrabDiscovery or 0) then return nil end
        if self.deferNativeDiscovery or type(getconnections) ~= "function" or type(debug) ~= "table" or type(debug.info) ~= "function" then return nil end
        local many = type(debug.getupvalues) == "function" and debug.getupvalues
            or type(getupvalues) == "function" and getupvalues
        local one = type(debug.getupvalue) == "function" and debug.getupvalue
            or type(getupvalue) == "function" and getupvalue
        if not many and not one then return nil end
        local function upvalues(fn)
            if many then
                local ok,values = pcall(many,fn)
                return ok and type(values) == "table" and values or {}
            end
            local values = {}
            for index = 1,12 do
                local ok,a,c = pcall(one,fn,index)
                if not ok then break end
                values[index] = c ~= nil and type(a) == "string" and c or a
            end
            return values
        end
        local function nativeName(fn)
            local ok,source,name = pcall(debug.info,fn,"sn")
            if not ok then return nil end
            local owned=type(source)=="string" and source:find("FeralGrabV2UI",1,true)~=nil
            if type(getfenv) == "function" then
                local valid,env = pcall(getfenv,fn)
                if valid and type(env) == "table" and env.script ~= nil then
                    if env.script ~= scriptObject then return nil end
                    owned=true
                end
            end
            return owned and name or nil
        end
        local previous=self.env.FERAL_RENAISSANCE_ACTIVE
        local inherited=previous and previous.bridge and previous.bridge.grabController
        if inherited and inherited.script==scriptObject and type(inherited.press)=="function"
            and type(inherited.state)=="function" and type(inherited.bind)=="function"
            and nativeName(inherited.press)=="serverPress" then
            local remote=self.ReplicatedStorage:FindFirstChild("FeralGrabV2")
            for _,value in pairs(upvalues(inherited.press)) do
                if remote and value==remote then
                    inherited.remote=remote
                    self.grabController=inherited;return inherited
                end
            end
        end
        local pool,source=self:nativeFunctions(now)
        if not pool then return nil end
        if not self.grabDiscovery or self.grabDiscovery.source~=source then
            self.nextGrabDiscovery = now+30
            self.grabDiscovery = {script=scriptObject,pool=pool,index=1,source=source}
        end
        -- Resume the shared own-callback pool without revisiting its prefix.
        local discovery,started,checked = self.grabDiscovery,self.clock(),0
        while discovery.index <= #discovery.pool do
            if checked >= 32 or self.clock()-started > .001 then return nil end
            local fn = discovery.pool[discovery.index]
            discovery.index += 1; checked += 1
            if type(fn) == "function" and nativeName(fn) == "serverPress" then
                local remote = self.ReplicatedStorage:FindFirstChild("FeralGrabV2")
                local matched = false
                for _,value in pairs(upvalues(fn)) do
                    if remote ~= nil and value == remote then matched = true end
                end
                if matched then
                    local native = { press = fn,script = scriptObject,remote=remote }
                    native.state = function()
                        local values=upvalues(fn)
                        local readable=false
                        for _,value in pairs(values) do if value==remote then readable=true end end
                        for _,value in pairs(values) do
                            if type(value) == "table" and value.id ~= nil
                                and (value.role == "prey" or value.role == "hunter") then
                                if native.lastState ~= value then native.lastState,native.ownerCharacter = value,self.player.Character end
                                if native.ownerCharacter ~= self.player.Character then return nil,true end
                                return value,true
                            end
                        end
                        return nil,readable
                    end
                    native.bind = function(on)
                        local cas = self.ContextActionService
                        if not on then
                            local info = cas:GetAllBoundActionInfo().FeralGrabV2Press
                            if info then
                                native.inputs = info.inputTypes and table.clone(info.inputTypes)
                                    or {Enum.KeyCode.Space,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonR2,Enum.UserInputType.MouseButton1}
                                native.priority = info.priorityLevel or 3000
                            end
                            cas:UnbindAction("FeralGrabV2Press")
                        else
                            -- v2412 callback prototype 73: Begin calls the
                            -- original serverPress; every state returns Sink.
                            cas:BindActionAtPriority("FeralGrabV2Press",function(_,state)
                                if state == Enum.UserInputState.Begin then fn() end
                                return Enum.ContextActionResult.Sink
                            end,false,native.priority or 3000,table.unpack(native.inputs or {
                                Enum.KeyCode.Space,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonR2,Enum.UserInputType.MouseButton1}))
                        end
                    end
                    self.grabController = native
                    self.grabDiscovery = nil
                    self:releaseNativeScan()
                    return native
                end
            end
        end
        if source.complete then self.grabDiscovery = nil end
        return nil
    end
    function b:isClimbing(char) return self:attribute(char,"FeralClimbLocal") == true end
    -- Inspect only three existing own-script callback chains. Never enumerate
    -- the Lua heap. Both consumers share a resumable, bounded queue.
    function b:nativeFunctions(now)
        if self.deferNativeDiscovery then return nil end
        if type(getconnections)~="function" or type(debug)~="table" or type(debug.info)~="function" then return nil end
        local scripts=self.player:FindFirstChild("PlayerScripts")
        local wolf=scripts and scripts:FindFirstChild("WolfController")
        local grab=scripts and scripts:FindFirstChild("FeralGrabV2UI")
        local scan=self.nativeScan
        if scan and (scan.wolf~=wolf or scan.grab~=grab or scan.complete and now>=scan.refreshAt) then scan=nil end
        if not scan then
            local signals={self.UserInputService.InputBegan,self.player:GetAttributeChangedSignal("FeralFeedTap")}
            local remote=self.ReplicatedStorage:FindFirstChild("FeralGrabV2")
            if remote and remote:IsA("RemoteEvent") then table.insert(signals,remote.OnClientEvent) end
            scan={wolf=wolf,grab=grab,functions={},seen={},queue={},cursor=1,signalIndex=1,
                signals=signals,complete=false,refreshAt=now+30}
            self.nativeScan=scan
        end
        if scan.complete or scan.lastStep==now then return scan.functions,scan end
        scan.lastStep=now
        local started,checked=self.clock(),0
        while checked<32 and self.clock()-started<.002 do
            if #scan.functions>=256 then scan.complete=true;break end
            local item=scan.queue[scan.cursor]
            if item then
                scan.cursor+=1;checked+=1
                local fn,depth=item.fn,item.depth
                if type(fn)~="function" or scan.seen[fn] or depth>4 then continue end
                scan.seen[fn]=true
                local ok,source=pcall(debug.info,fn,"s")
                local owned=ok and type(source)=="string" and (source:find("WolfController",1,true) or source:find("FeralGrabV2UI",1,true))
                if type(getfenv)=="function" then
                    local valid,env=pcall(getfenv,fn)
                    if valid and type(env)=="table" and env.script~=nil then owned=env.script==wolf or env.script==grab end
                end
                -- Executors may expose a vendor wrapper as the signal root.
                -- Inspect one root hop, but accept only validated own-script
                -- functions; never descend through an unrelated child chain.
                if not owned and depth~=0 then continue end
                if owned then table.insert(scan.functions,fn) end
                local count=0
                for _,value in pairs(self:upvalues(fn)) do
                    count+=1;if count>64 then break end
                    if type(value)=="function" and not scan.seen[value] and #scan.queue<512 then
                        table.insert(scan.queue,{fn=value,depth=depth+1})
                    end
                end
            elseif scan.connections then
                local connection=scan.connections[scan.connectionIndex]
                if not connection or scan.connectionIndex>96 then scan.connections=nil;continue end
                scan.connectionIndex+=1;checked+=1
                local ok,fn=pcall(function()return connection.Function end)
                if ok and type(fn)=="function" and #scan.queue<512 then table.insert(scan.queue,{fn=fn,depth=0}) end
            else
                local signal=scan.signals[scan.signalIndex]
                if not signal then scan.complete=true;break end
                scan.signalIndex+=1;checked+=1
                local ok,connections=pcall(getconnections,signal)
                if ok and type(connections)=="table" then scan.connections,scan.connectionIndex=connections,1 end
            end
        end
        if scan.complete then scan.queue,scan.seen,scan.connections,scan.signals=nil,nil,nil,nil end
        return scan.functions,scan
    end
    function b:releaseNativeScan()
        local native=self.wolfActions
        if native and native.tryBite and native.toggleFeed and self.grabController
            and not self.wolfDiscovery and not self.grabDiscovery then self.nativeScan=nil end
    end
    function b:closeNativeScan()
        self.nativeScan,self.wolfDiscovery,self.grabDiscovery=nil,nil,nil
        self.biteTiming=nil
    end
    function b:upvalues(fn)
        local many = type(debug.getupvalues) == "function" and debug.getupvalues
            or type(getupvalues) == "function" and getupvalues
        if many then
            local ok,values = pcall(many,fn)
            return ok and type(values) == "table" and values or {}
        end
        local one = type(debug.getupvalue) == "function" and debug.getupvalue
            or type(getupvalue) == "function" and getupvalue
        local values = {}
        if one then
            for index = 1,24 do
                local ok,a,value = pcall(one,fn,index)
                if not ok then break end
                if type(a) == "string" and value ~= nil then values[index] = value else values[index] = a end
            end
        end
        return values
    end
    function b:nativeWolfActions(now)
        local scripts = self.player:FindFirstChild("PlayerScripts")
        local ownScript = scripts and scripts:FindFirstChild("WolfController")
        if not ownScript then self.wolfActions,self.wolfDiscovery = nil,nil;return nil end
        if self.wolfActions and self.wolfActions.script ~= ownScript then self.wolfActions,self.wolfDiscovery = nil,nil end
        local native = self.wolfActions
        if not native then
            -- Preserve validated handles already held by our previous release.
            -- This reads the existing owner; it never enumerates another VM.
            local previous=self.env.FERAL_RENAISSANCE_ACTIVE
            local cached=previous and previous.bridge and previous.bridge.wolfActions
            local remote=self.ReplicatedStorage:FindFirstChild("WolfActions")
            if cached and cached.script==ownScript and type(cached.tryBite)=="function" then
                local t=self:upvalues(cached.tryBite)
                local d=type(t[5])=="function" and self:upvalues(t[5]) or {}
                local named,name=pcall(debug.info,t[4],"n")
                if t[1]==self.player and d[1]==self.player and remote and d[8]==remote
                    and type(t[4])=="function" and named and name=="biteCooldown" then
                    native={script=ownScript,tryBite=cached.tryBite,doBite=t[5],biteCooldown=t[4]}
                    local f=type(cached.toggleFeed)=="function" and self:upvalues(cached.toggleFeed) or {}
                    if f[5]==self.player and f[6]==remote then native.toggleFeed=cached.toggleFeed end
                    self.wolfActions=native
                end
            end
        end
        if native and native.tryBite and native.toggleFeed then return native end
        if not self.wolfDiscovery and now < (self.nextWolfDiscovery or 0) then return native end
        if self.deferNativeDiscovery or type(getconnections) ~= "function" or type(debug) ~= "table" or type(debug.info) ~= "function" then return native end
        if type(debug.getupvalues) ~= "function" and type(getupvalues) ~= "function"
            and type(debug.getupvalue) ~= "function" and type(getupvalue) ~= "function" then return native end
        local function nameOf(fn)
            if type(fn) ~= "function" then return nil end
            local ok,source,name = pcall(debug.info,fn,"sn")
            if not ok then return nil end
            local owned=type(source)=="string" and source:find("WolfController",1,true)~=nil
            if type(getfenv) == "function" then
                local valid,env = pcall(getfenv,fn)
                if valid and type(env)=="table" and env.script~=nil then
                    if env.script~=ownScript then return nil end
                    owned=true
                end
            end
            return owned and name or nil
        end
        local pool,source=self:nativeFunctions(now)
        if not pool then return native end
        if not self.wolfDiscovery or self.wolfDiscovery.source~=source then
            self.nextWolfDiscovery = now+30
            native = native or {script=ownScript}
            self.wolfActions,self.wolfDiscovery = native,{pool=pool,index=1,source=source}
        end
        local scan,started,count = self.wolfDiscovery,self.clock(),0
        local remote = self.ReplicatedStorage:FindFirstChild("WolfActions")
        while scan.index <= #scan.pool do
            if count >= 32 or self.clock()-started > .001 then return native end
            local fn = scan.pool[scan.index];scan.index += 1;count += 1
            local name = nameOf(fn)
            if name == "tryBite" or name == "toggleFeed" or name == "cancelFeed" then
                local playerMatched,remoteMatched = false,false
                for _,value in pairs(self:upvalues(fn)) do
                    if value == self.player then playerMatched = true end
                    if remote and value == remote then remoteMatched = true end
                    if name == "tryBite" and nameOf(value) == "doBite" then
                        for _,upvalue in pairs(self:upvalues(value)) do
                            if remote and upvalue == remote then remoteMatched = true;native.doBite=value end
                        end
                    end
                    if name == "tryBite" and nameOf(value) == "biteCooldown" then native.biteCooldown=value end
                end
                if playerMatched and remoteMatched then native[name] = fn end
            end
            if native.tryBite and native.toggleFeed then break end
        end
        if source.complete or native.tryBite and native.toggleFeed then self.wolfDiscovery = nil end
        self:releaseNativeScan()
        return native
    end
    function b:nativeFeedState(now)
        local native = self:nativeWolfActions(now)
        if not native or not native.toggleFeed then return nil,nil,false end
        local values = self:upvalues(native.toggleFeed)
        if values[5] ~= self.player or values[6] ~= self.ReplicatedStorage:FindFirstChild("WolfActions") then return nil,nil,false end
        local mode = values[1]
        if mode ~= nil and mode ~= "eat" and mode ~= "drink" then return nil,nil,false end
        return mode,values[2] == true,true
    end
    function b:toggleNativeFeed(now)
        local native = self:nativeWolfActions(now)
        return native and native.toggleFeed and pcall(native.toggleFeed) or false
    end
    function b:stopNativeFeed(now)
        local native = self:nativeWolfActions(now)
        if native and native.cancelFeed then return pcall(native.cancelFeed) end
        local mode,_,known=self:nativeFeedState(now)
        -- The named cancelFeed prototype may be unretained after script startup.
        -- The original toggle's first branch performs the same native cancellation.
        return known and mode~=nil and native and native.toggleFeed and pcall(native.toggleFeed) or false
    end
    function b:tryNativeBite(now)
        local native = self:nativeWolfActions(now)
        return native and native.tryBite and pcall(native.tryBite) or false
    end
    function b:biteDelay(char)
        local c = self:config("CombatConfig")
        if c and type(c.hitDelay) == "function" then
            local ok,delay = pcall(c.hitDelay,char)
            if ok and Core.finite(delay) and delay >= .03 and delay <= 1 then return delay end
        end
        return c and Core.finite(c.HIT_DELAY) and math.clamp(c.HIT_DELAY,.03,1) or .27
    end
    function b:restLock(char)
        local profiles=self:config("AnimProfiles")
        local profile=profiles and profiles[self:attribute(char,"AnimProfile") or ""]
        local value=profile and profile.REST_UP_LOCK
        return Core.finite(value) and math.clamp(value,.05,1.5) or .7
    end
    function b:biteReadiness(s,now,policy)
        local function result(ready,reason,known)return {ready=ready,reason=reason,known=known~=false}end
        if not s.alive then return result(false,"waiting for animal") end
        if s.chat or s.gameMenu then return result(false,"menu or text input") end
        if s.captured or s.char:FindFirstChild("FeralClamp") then return result(false,"capture or carry lock") end
        if s.feeding then return result(false,"feeding") end
        if s.rest or policy.manualRest or policy:restLocked(now,self:restLock(s.char)) then return result(false,"Rest or stand-up lock") end
        if s.ability or self:attribute(s.char,"FeralKingsAt") or self:attribute(s.char,"FeralCrushAt") then
            return result(false,"native ability lock")
        end
        for _,key in ipairs({"FeralNoBiteUntil","FeralVenomRecoilUntil"}) do
            local at=self:attribute(s.char,key)
            if at~=nil and (not Core.finite(at) or not s.serverNow) then return result(false,"native timing unknown",false) end
            if at and at>s.serverNow then return result(false,"native bite lock") end
        end
        local native=self.wolfActions
        if not native or not native.tryBite or not native.doBite or not native.biteCooldown then
            -- Primary-input connections may be VM-isolated. The captured
            -- cooldown calculation and own SafeTime bite marker remain useful,
            -- but do not establish the inaccessible private Rest/input state.
            local species=self:config("Species")
            local passive=self:config("PassiveConfig")
            local at=self:attribute(s.char,"WolfBiteAt")
            if not species or type(species.biteCooldown)~="function" or not s.serverNow or not Core.finite(at)
                or at>s.serverNow+1 then return result(false,"native timing unavailable",false) end
            local ok,cd=pcall(species.biteCooldown,self:attribute(s.char,"Species") or species.DEFAULT,self:attribute(s.char,"Growth") or 1)
            local mult=1
            if passive and passive.biteCdMult~=nil then
                local valid,value=pcall(passive.biteCdMult,s.char)
                if not valid or not Core.finite(value) or value<=0 then return result(false,"native cooldown unknown",false) end
                mult=value
            end
            if not ok or not Core.finite(cd) or cd*mult<.03 or cd*mult>30 then return result(false,"native cooldown unknown",false) end
            local r=result(s.serverNow-at>=cd*mult,s.serverNow-at>=cd*mult
                and "visible client checks clear; private state unverified" or "native cooldown")
            r.timingSource="native config and own bite marker";r.privateStateKnown=false
            return r
        end
        local timing=self.biteTiming
        if not timing or timing.native~=native or now>=timing.nextAt then
            if self.deferNativeDiscovery then return result(false,"native timing deferred",false) end
            local try,doBite=self:upvalues(native.tryBite),self:upvalues(native.doBite)
            local remote=self.ReplicatedStorage:FindFirstChild("WolfActions")
            if try[1]~=self.player or try[4]~=native.biteCooldown or try[5]~=native.doBite
                or doBite[1]~=self.player or doBite[8]~=remote or not remote
                or not Core.finite(try[3]) or not Core.finite(doBite[4])
                or type(doBite[2])~="boolean" or type(doBite[3])~="boolean" then
                return result(false,"native timing layout unknown",false)
            end
            -- The captured biteCooldown prototype is a pure native calculation.
            -- No attack/cooldown state is changed or bypassed.
            local ok,cd=pcall(native.biteCooldown)
            if not ok or not Core.finite(cd) or cd<.03 or cd>30 then return result(false,"native cooldown unknown",false) end
            timing={native=native,lastBite=try[3],lastRest=doBite[4],resting=doBite[2] or doBite[3],cd=cd,nextAt=now+.05}
            self.biteTiming=timing
        end
        if timing.resting or now-timing.lastRest<self:restLock(s.char) then return result(false,"native Rest lock") end
        if now-timing.lastBite<timing.cd then return result(false,"native cooldown") end
        local r=result(true,"client checks clear; gameplay unverified")
        r.privateStateKnown=true;r.timingSource="validated own native closures"
        return r
    end
    function b:io()
        return {
            available = type(readfile) == "function" and type(writefile) == "function",
            read = function(path)
                assert(type(readfile) == "function","readfile unavailable")
                return self.HttpService:JSONDecode(readfile(path))
            end,
            write = function(path,value)
                assert(type(writefile) == "function","writefile unavailable")
                writefile(path,self.HttpService:JSONEncode(value))
                return true
            end,
        }
    end
    function b:water(char,hum,root)
        if not hum or not root then return false,false end
        local swim = self:attribute(char,"FeralSwimLocal") == true
            or hum:GetState() == Enum.HumanoidStateType.Swimming or hum.FloorMaterial == Enum.Material.Water
        local under = self:attribute(char,"FeralUnderwater") == true
            or (swim and self:attribute(char,"FeralDiving") == true)
        local params = RaycastParams.new()
        params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Include,{self.Workspace.Terrain}
        params.IgnoreWater = false
        local body = math.max(hum.HipHeight+root.Size.Y/2,.2)
        local y,top = root.Position.Y+40,nil
        for _ = 1,2 do
            local hit = self.Workspace:Raycast(Vector3.new(root.Position.X,y,root.Position.Z),
                Vector3.new(0,-(y-root.Position.Y+body*2),0),params)
            if not hit then break end
            if hit.Material == Enum.Material.Water then top = hit.Position.Y; break end
            if hit.Position.Y <= root.Position.Y then break end
            y = hit.Position.Y-.3
        end
        local depth = top and top-root.Position.Y
        if depth and depth > math.max(1.6,body*1.2) then under = true end
        local surface = swim and depth ~= nil and not under
            and depth >= -math.max(1.6,body*1.25) and depth <= math.max(1.6,body*1.2)
        return swim,under,surface == true,depth
    end
    function b:snapshot(now, waterNeeded)
        local char = self.player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local at = self:serverNow()
        local deadline = self:attribute(self.player,"FeralCombatUntil")
        local combat = nil
        if at and (deadline == nil or Core.finite(deadline)) then combat = (deadline or 0) > at end
        local s = { now = now, serverNow = at, char = char, hum = hum, root = root,
            generation = self.generation, species=self:attribute(char,"Species"),
            alive = char ~= nil and char.Parent ~= nil and hum ~= nil and root ~= nil and hum.Health > 0,
            hp = hum and hum.Health or 0, maxHP = hum and hum.MaxHealth or 0,
            chat = self.UserInputService:GetFocusedTextBox() ~= nil,
            gameMenu = self:attribute(self.player,"FeralMenuOpen") == true,
            combat = combat, rest = self:attribute(char,"WolfRest") == true,
            feeding = false, captured = false, moving = false, locomotion = "NONE",
            injury = self:attribute(char,"FeralInjury"), bleed = self:attribute(char,"FeralBleed"),
            venom = self:attribute(char,"FeralVenomAmt"), stamina = self:attribute(char,"Stamina"),
            maxStamina=self:attribute(char,"StaminaMax"),
            hunger = self:attribute(char,"Hunger"), thirst = self:attribute(char,"Thirst"),
            survival = self:attribute(self.player,"FeralSurvival") }
        if not s.alive then return s end
        local feed = self:attribute(char,"WolfFeed")
        s.feedMode = (feed == "eat" or feed == "drink") and feed or nil
        s.feeding = feed == true or s.feedMode ~= nil
        s.captured = self:attribute(char,"FeralPinned") == true
            or self:attribute(char,"FeralCarried") == true or self:attribute(char,"FeralDragged") == true
        s.pinned = self:attribute(char,"FeralPinned") == true or self:attribute(char,"FeralDragged") == true
        s.carried = self:attribute(char,"FeralCarried") == true
        s.climbing = self:isClimbing(char)
        s.climbCan = self:attribute(char,"ClimbCan") == true
        s.climber = self:attribute(char,"PassiveClimber")
        s.flying = self:attribute(char,"FeralFlyLocal") == true
        s.diveCan = self:attribute(char,"DiveCan") == true
        s.burst = self:attribute(self.player,"HudBurst") == true or self:attribute(char,"FeralFlyBurst") == true
        -- v2412 WolfController input callback accepts MouseButton1/R2.
        -- MouseButton2 is a camera control, not a continuously held bite.
        s.attackHeld = self.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        local velocity = root.AssemblyLinearVelocity
        s.moving = hum.MoveDirection.Magnitude > .13 or Vector3.new(velocity.X,0,velocity.Z).Magnitude >= 2
        local clamp = char:FindFirstChild("FeralClamp")
        s.holding = clamp ~= nil and clamp:IsA("ObjectValue") and clamp.Value ~= nil
            or self:attribute(char,"FeralCarcassCarry") == true
        s.talonLock=self:attribute(char,"FeralTalonLock")
        s.diveLock=self:attribute(char,"FeralDiveLocal")
        s.ability = self:attribute(char,"FeralCrushAt")~=nil and self:attribute(char,"FeralCrushAt")~=false
            or self:attribute(char,"FeralDeathRollLocal") == true
            or self:attribute(char,"FeralDowned") == true
            or self:attribute(char,"FeralRolling") == true
            or s.talonLock~=nil or s.diveLock~=nil
            or self:attribute(char,"FeralDiveBomb") == true
            or self:attribute(char,"FeralVenomDown") == true
            or self:attribute(char,"FeralTumbleAt") ~= nil
        if waterNeeded then
            s.swimming,s.underwater,s.surface,s.depth = self:water(char,hum,root)
        else
            s.swimming = self:attribute(char,"FeralSwimLocal") == true
            s.underwater = self:attribute(char,"FeralUnderwater") == true
        end
        s.locomotion = s.underwater and "UNDERWATER" or s.flying and "FLIGHT"
            or s.climbing and "CLIMB" or s.swimming and "SWIM" or s.burst and "BURST" or "LAND"
        return s
    end
    local function knownPack(v)
        if type(v) == "number" then return v > 0 and tostring(v) or nil end
        if type(v) == "string" and v ~= "" and v ~= "0" and v ~= "None" and v ~= "nil" then return v end
        return nil
    end
    function b:litterRecord(char)
        local record = self.litterByBody and self.litterByBody[char]
        local body = record and record.Parent and record:FindFirstChild("Body")
        if body and body:IsA("ObjectValue") and body.Value == char and self:attribute(record,"Alive") == true then return record end
        return nil
    end
    function b:refreshLitter()
        local map = {}
        local folder = self.ReplicatedStorage:FindFirstChild("FeralLitter")
        if folder then
            for index,record in ipairs(folder:GetChildren()) do
                if index > 256 then break end
                local body = record:FindFirstChild("Body")
                local char = body and body:IsA("ObjectValue") and body.Value
                if char and char:IsA("Model") and char.Parent and self:attribute(record,"Alive") == true then map[char] = record end
            end
        end
        self.litterByBody = map
        return map
    end
    function b:packFor(char,owner)
        local record = self:litterRecord(char)
        return knownPack(self:attribute(owner,"FeralPack")) or knownPack(self:attribute(char,"FeralPack"))
            or knownPack(self:attribute(record,"Pack"))
    end
    function b:affiliation(other, char)
        local own = self:packFor(self.player.Character,self.player)
        local theirs = self:packFor(char,other or (char and self.Players:GetPlayerFromCharacter(char)))
        return own and theirs and (own == theirs and "same" or "other") or "unknown"
    end
    function b:targetBlocker(char,owner)
        if not char or not char.Parent or self:attribute(char,"FeralDead") == true then return "target unavailable" end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return "target unavailable" end
        if char:FindFirstChildOfClass("ForceField") then return "protected target" end
        local safe,now = self:attribute(char,"FeralSafeUntil"),self:serverNow()
        if Core.finite(safe) and (not now or safe > now) then return "spawn protection" end
        owner = owner or self.Players:GetPlayerFromCharacter(char)
        if self:attribute(owner,"FeralTut") == true or self:attribute(owner,"FeralTutorial") == true then return "tutorial protection" end
        local tutorial = self:attribute(char,"TutorialOwner")
        if tutorial ~= nil and tutorial ~= self.player.UserId then return "another tutorial target" end
        if self:attribute(char,"FeralBurrowed") == true then return "burrowed target" end
        return nil
    end
    function b:combatEligible(char)
        return char ~= self.player.Character and not self:targetBlocker(char)
            and self:affiliation(nil,char) ~= "same"
    end
    function b:sameTree(a,c)
        if not self:isClimbing(a) or not self:isClimbing(c) then return false end
        local axisA,axisB = self:attribute(a,"FeralClimbAxis"),self:attribute(c,"FeralClimbAxis")
        return typeof(axisA) == "Vector3" and typeof(axisB) == "Vector3" and (axisA-axisB).Magnitude < 5
    end
    function b:candidates(s, range,visual)
        local all,seen = {},{}
        if not s.alive then self.tracked = all; return all end
        local litter = self:refreshLitter()
        local function add(char,other,npc)
            if not char or char == s.char or not char.Parent or seen[char] then return end
            local owner = self.Players:GetPlayerFromCharacter(char)
            if owner == self.player then return end
            local root,hum = char:FindFirstChild("HumanoidRootPart"),char:FindFirstChildOfClass("Humanoid")
            if not root or not hum or hum.Health <= 0 then return end
            local delta = root.Position-s.root.Position
            local distance = delta.Magnitude
            if distance > range then return end
            local record = litter[char]
            seen[char] = true
            table.insert(all,{ char = char, root = root, hum = hum, player = owner, npc = owner == nil,
                litter = owner == nil and record or nil,
                name = owner and owner.DisplayName or self:attribute(record,"Name") or self:attribute(char,"FeralName") or char.Name,
                distance = distance,affiliation = self:affiliation(owner,char), flat = Vector3.new(delta.X,0,delta.Z),
                sameTree = self:sameTree(s.char,char),
                protected = self:targetBlocker(char,owner) ~= nil })
        end
        for _, other in ipairs(self.Players:GetPlayers()) do
            if other ~= self.player then add(other.Character,other,false) end
        end
        local folder = self.Workspace:FindFirstChild("FeralNPCs")
        if folder then
            for i, char in ipairs(folder:GetChildren()) do
                if i > 256 then break end
                if char:IsA("Model") then add(char,nil,true) end
            end
        end
        for char in pairs(litter) do add(char,nil,true) end
        table.sort(all,function(a,c) return a.distance < c.distance end)
        local tracked,players,playerCount,npcCount = {},0,0,0
        for _,target in ipairs(all) do
            if target.player then
                playerCount += 1
                if players < 24 then table.insert(tracked,target);players += 1 end
            elseif target.litter or self:packFor(target.char) then
                npcCount += 1
            end
        end
        if visual ~= false then
            self.tracked,self.replicatedCount,self.packNPCCount = tracked,playerCount,npcCount
            self.allCandidates=all
        end
        return all
    end
    function b:carrying(s,target)
        local clamp=s.char and s.char:FindFirstChild("FeralClamp")
        local value=clamp and clamp:IsA("ObjectValue") and clamp.Value
        return value ~= nil and (value==target or value:IsDescendantOf(target)) and self:attribute(clamp,"Carry")==true
    end
    function b:carryEligible(s,target)
        if not s.alive or not target or not target.char.Parent or not target.root.Parent or target.hum.Health<=0
            or self:attribute(target.char,"FeralCarried")==true or self:attribute(target.char,"FeralDragged")==true
            or self:affiliation(target.player,target.char)=="other" then return false end
        local cfg,species,abilities=self:config("CarryConfig"),self:config("Species"),self:config("AbilityConfig")
        if not cfg or cfg.ENABLED~=true or not Core.finite(cfg.REACH) or type(cfg.canCarry)~="function" or not species or not abilities then return false end
        local diff=target.root.Position-s.root.Position
        local reach=1.5+cfg.REACH*(s.root.Size.Z+target.root.Size.Z)
        local flat=Vector3.new(diff.X,0,diff.Z)
        local look=s.root.CFrame.LookVector;look=Vector3.new(look.X,0,look.Z)
        if diff.Magnitude>reach or flat.Magnitude>.1 and look.Magnitude>.1 and look.Unit:Dot(flat.Unit)<.2 then return false end
        local ok,can=pcall(cfg.canCarry,species,abilities,s.char,target.char)
        return ok and can==true
    end
    function b:waterCub(s)
        local best
        for _,target in ipairs(self:candidates(s,35,false)) do
            if self:carryEligible(s,target) then
                local swim,_,_,depth=self:water(target.char,target.hum,target.root)
                if (swim or depth and depth>=-.25) and (not best or target.distance<best.distance) then best=target end
            end
        end
        return best
    end
    function b:carryWaterAllowed(s)
        local swim,under,_,depth=self:water(s.char,s.hum,s.root)
        if not swim and not under and (not depth or depth<-.25) then return true end
        local cfg=self:config("CarryConfig")
        return cfg and type(cfg.WATER_OK)=="table" and cfg.WATER_OK[self:attribute(s.char,"Species")]==true or false
    end
    function b:geometry(values,s,target)
        if not values or not s.alive then return nil end
        if not target.root.Parent or not target.hum.Parent or target.hum.Health <= 0 then return nil end
        local diff = target.root.Position-s.root.Position
        local flat = Vector3.new(diff.X,0,diff.Z)
        local fwd = s.root.CFrame.LookVector
        fwd = Vector3.new(fwd.X,0,fwd.Z)
        if fwd.Magnitude < .01 then return nil end
        if type(values.biteLook) == "function" then
            local ok,v = pcall(values.biteLook,s.char,fwd.Unit)
            if ok and typeof(v) == "Vector3" then fwd = Vector3.new(v.X,0,v.Z) end
        end
        if fwd.Magnitude < .01 then return nil end
        local ok,gap = pcall(values.bodyGap,target.root,flat)
        if not ok or not Core.finite(gap) then return nil end
        local function modifier(key, default)
            if type(values[key]) ~= "function" then return default end
            local good,v = pcall(values[key],s.char)
            return good and Core.finite(v) and v or default
        end
        local box = self:attribute(s.root,"FeralBoxFull")
        if not Core.finite(box) or box <= 0 then box = s.root.Size.Z end
        local reach = (box*.5+s.hum.HipHeight*values.REACH+values.SLACK)*values.HIT_SCALE*modifier("reachMult",1)
        local angle = flat.Magnitude > .01 and fwd.Unit:Dot(flat.Unit) or 1
        local cone = modifier("coneFor",values.CONE)
        local height = math.abs(target.root.Position.Y-s.root.Position.Y)
        local vertical = (s.hum.HipHeight+target.hum.HipHeight)*values.MAX_DY*modifier("dyMult",1)
        return { valid = gap < reach and angle > math.cos(math.rad(cone)) and height < vertical,
            withinBodyRange = gap < reach and height < vertical,
            gap = gap, reach = reach, angle = angle, distance = diff.Magnitude,score = gap-angle*2 }
    end
    function b:occluded(s,target)
        local params = RaycastParams.new()
        params.FilterType,params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude,{s.char}
        params.IgnoreWater = true
        local hit = self.Workspace:Raycast(s.root.Position,target.root.Position-s.root.Position,params)
        return hit ~= nil and not hit.Instance:IsDescendantOf(target.char)
    end
    function b:select(s, baseline, changed, all)
        local previousAssist=self.reachTarget
        self.treeTarget = nil
        self.reachTarget = nil
        local best,score = nil,math.huge
        local eligible={}
        for _, target in ipairs(all) do
            if target.distance <= 45 and self:combatEligible(target.char) then
                table.insert(eligible,target)
                if target.sameTree and (not self.treeTarget or target.distance < self.treeTarget.distance) then self.treeTarget = target end
            end
        end
        local assisted,assistScore = nil,math.huge
        local selectionModel = table.clone(changed)
        selectionModel.biteLook = baseline.biteLook
        for _,target in ipairs(eligible) do
                local geometry = self:geometry(selectionModel,s,target)
                if geometry and geometry.withinBodyRange then
                    local stock = self:geometry(baseline,s,target)
                    local rank = target.distance+(target.affiliation == "unknown" and .5 or 0)
                        -(stock and stock.valid and .75 or 0)
                    if previousAssist and previousAssist.char==target.char then rank-=.65 end
                    if rank < assistScore and (target.sameTree or not self:occluded(s,target)) then
                        assisted,assistScore = target,rank
                    end
                end
        end
        self.reachTarget = assisted
        for _, target in ipairs(eligible) do
                local base = self:geometry(baseline,s,target)
                local extended = self:geometry(changed,s,target)
                if base or extended then
                    local rank = (extended and extended.score or math.huge) + (extended and extended.valid and 0 or 1000)
                    if rank < score then best,score = { target = target, baseline = base, extended = extended },rank end
                end
        end
        if best then
            best.obstruction=best.target.protected or self:occluded(s,best.target)
            best.blocked=best.obstruction
        end
        return best
    end
    function b:refreshGuide(s,baseline,changed,guide)
        local target=guide.target
        if not s.alive or not target or not self:combatEligible(target.char) then
            guide.blocked,guide.invalid=true,true;return
        end
        guide.invalid=false
        guide.baseline=self:geometry(baseline,s,target)
        guide.extended=self:geometry(changed,s,target)
        -- A guide tracks the current selected body every frame. Target search
        -- and obstacle queries remain bounded background work.
        guide.blocked=guide.obstruction or not guide.extended or not guide.extended.valid
    end
    function b:friendlyCarry(s)
        if not s.carried or s.pinned then return false end
        local growth = self:attribute(s.char,"Growth")
        local species = self:attribute(s.char,"Species")
        if not Core.finite(growth) or growth > .34 or type(species) ~= "string" then return false end
        for _, other in ipairs(self.Players:GetPlayers()) do
            local adult = other.Character
            local ag = self:attribute(adult,"Growth")
            if adult ~= s.char and Core.finite(ag) and ag >= .67 and self:attribute(adult,"Species") == species then
                for _, name in ipairs({"FeralClamp","FeralClampLocal"}) do
                    local clamp = adult and adult:FindFirstChild(name)
                    if clamp and clamp:IsA("ObjectValue") then
                        local target = clamp.Value
                        if target and (target == s.char or target:IsDescendantOf(s.char)) then return true end
                    end
                end
            end
        end
        return false
    end
    function b:escapeAction(s)
        if not s.alive or self:friendlyCarry(s) then return nil,"friendly carry or no animal" end
        if s.holding and not s.captured then return nil,"carrying prey" end
        local clamp = self:attribute(s.char,"FeralClampN") or self:attribute(s.char,"FeralClampGame")
        local need = self:attribute(s.char,"FeralShakeNeed")
        local cue = s.captured or (Core.finite(clamp) and clamp > 0) or (Core.finite(need) and need > 0)
        if not cue then return nil,"watching native capture cues" end
        if s.carried then return "getoff","carried",.435 end
        local bindings = self.ContextActionService:GetAllBoundActionInfo()
        if bindings.FeralTugTap then return "shake","native tug",.12 end
        if bindings.FeralShakeTaps or bindings.FeralShakeMash then return "shake","native shake",.17 end
        return nil,"captured; no native escape binding"
    end
    function b:nearbyDanger(s)
        if not s.root then return true end
        local params = OverlapParams.new()
        params.FilterType,params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude,{s.char}
        params.MaxParts = 200
        local parts = self.Workspace:GetPartBoundsInRadius(s.root.Position,28,params)
        if #parts >= 200 then return true end
        for _, part in ipairs(parts) do
            local model = part:FindFirstAncestorOfClass("Model")
            local hum = model and model:FindFirstChildOfClass("Humanoid")
            if model ~= s.char and hum and hum.Health > 0 then return true end
        end
        return false
    end
    function b:safeStep(s, anchor)
        local config = self:config("SurvivalConfig")
        local threshold = config and config.AFK_MOVE
        if not Core.finite(threshold) or threshold < 0 or threshold+2 > 8 then return nil end
        local step = threshold+2
        local root = s.root
        local params = RaycastParams.new()
        params.FilterType,params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude,{s.char}
        params.IgnoreWater = false
        local function ground(at)
            local hit = self.Workspace:Raycast(at+Vector3.new(0,8,0),Vector3.new(0,-35,0),params)
            return hit and hit.Material ~= Enum.Material.Water and hit.Normal.Y > .86 and hit.Position or nil
        end
        local start = ground(root.Position)
        if not start then return nil end
        local forward = root.CFrame.LookVector
        forward = Vector3.new(forward.X,0,forward.Z)
        if forward.Magnitude < .01 then return nil end
        forward = forward.Unit
        local side = Vector3.new(-forward.Z,0,forward.X)
        local goals = { root.Position+side*step,root.Position-side*step,root.Position+forward*step,root.Position-forward*step }
        if anchor and (root.Position-anchor).Magnitude > threshold+.2 then goals = {anchor} end
        for _, goal in ipairs(goals) do
            local vector = goal-root.Position
            vector = Vector3.new(vector.X,0,vector.Z)
            if vector.Magnitude > threshold+.5 and vector.Magnitude <= 8 then
                local safe = true
                for distance = 0,vector.Magnitude+1.25,1 do
                    local point = ground(root.Position+vector.Unit*distance)
                    if not point or math.abs(point.Y-start.Y) > 1.1 then safe = false; break end
                end
                if safe and not self.Workspace:Raycast(root.Position+Vector3.new(0,1,0),vector,params) then
                    local ending = ground(goal)
                    if ending then return Vector3.new(goal.X,root.Position.Y+ending.Y-start.Y,goal.Z) end
                end
            end
        end
        return nil
    end
    function b:routeSafe(s,goal)
        if not s.alive or not goal or s.hum.FloorMaterial==Enum.Material.Air
            or s.hum.FloorMaterial==Enum.Material.Water then return false end
        local vector=goal-s.root.Position
        vector=Vector3.new(vector.X,0,vector.Z)
        if vector.Magnitude>8.1 then return false end
        if vector.Magnitude<.05 then return true end
        local params=RaycastParams.new()
        params.FilterType,params.FilterDescendantsInstances=Enum.RaycastFilterType.Exclude,{s.char}
        params.IgnoreWater=false
        local groundY
        for distance=0,vector.Magnitude+1.25,1 do
            local point=s.root.Position+vector.Unit*distance
            local hit=self.Workspace:Raycast(point+Vector3.new(0,8,0),Vector3.new(0,-35,0),params)
            if not hit or hit.Material==Enum.Material.Water or hit.Normal.Y<=.86 then return false end
            groundY=groundY or hit.Position.Y
            if math.abs(hit.Position.Y-groundY)>1.1 then return false end
        end
        return self.Workspace:Raycast(s.root.Position+Vector3.new(0,1,0),vector,params)==nil
    end
    function b:walk(s,goal)
        if s.char ~= self.player.Character or not s.hum or not s.root then return false end
        s.hum:MoveTo(goal or s.root.Position)
        return true
    end
    function b:pulseIdle()
        local ok = pcall(function()
            local v = game:GetService("VirtualUser")
            v:CaptureController()
            v:ClickButton2(Vector2.new(0,0))
        end)
        return ok
    end
    function b:attach(hub,scope)
        local function connect(signal,fn)
            local c = signal:Connect(function(...)
                if hub.active and not hub.closed then fn(...) end
            end)
            scope:add(function() c:Disconnect() end)
            return c
        end
        local function character(char)
            if self.characterScope then self.characterScope:close() end
            self.characterScope = Core.scope()
            self.generation += 1
            self.character = char
            hub:characterChanged(self.generation)
            if not char then return end
            for _, key in ipairs({"WolfRest","WolfBiteAt","WolfFeed","FeralPinned","FeralCarried",
                "FeralDragged","FeralTalonLock","FeralDiveLocal","FeralDeathRollLocal","FeralRolling",
                "FeralDowned","FeralVenomDown","FeralTumbleAt","FeralCrushAt","FeralCrushBiteAt","FeralClimbLocal","FeralFlyLocal","FeralUnderwater"}) do
                local c = char:GetAttributeChangedSignal(key):Connect(function()
                    if hub.active and not hub.closed and char == self.player.Character then hub:nativeAttribute(key) end
                end)
                self.characterScope:add(function() c:Disconnect() end)
            end
        end
        self.bindCharacter = character
        scope:add(function() if self.characterScope then self.characterScope:close() end end)
        connect(self.player.CharacterAdded,character)
        connect(self.player.CharacterRemoving,function() character(nil) end)
        connect(self.player.Idled,function() hub:idle() end)
        connect(self.player:GetAttributeChangedSignal("FeralRestTap"),function()
            if self.UserInputService:GetFocusedTextBox() then return end
            local now=self.clock()
            hub.policy:input("rest",now)
            hub.recovery:manual(now)
            hub.combatInput:cancel();hub.feeding:cancel("manual rest control",now);hub.rescue:cancel()
        end)
        connect(self.UserInputService.InputBegan,function(input,processed) hub:input(input,processed) end)
        connect(self.UserInputService.InputChanged,function(input)
            local kind = input.UserInputType
            if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.MouseWheel
                or kind == Enum.UserInputType.Touch then hub:physicalInput(kind == Enum.UserInputType.MouseMovement and "mouse" or "other") end
        end)
        local actionName = "FERAL_RENAISSANCE_" .. tostring(hub.token)
        -- CAS can consume event-driven sprint bindings. Native IsKeyDown
        -- polling can still see Right Shift; this limitation is recorded.
        self.ContextActionService:BindActionAtPriority(actionName,function(_,state,input)
            if not hub.active or hub.closed or self.UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
            if input.KeyCode == Enum.KeyCode.RightShift then
                if state == Enum.UserInputState.Begin then hub.ui:toggle() end
                return Enum.ContextActionResult.Sink
            end
            if state == Enum.UserInputState.Begin and input.KeyCode == Enum.KeyCode.G and hub:carryInput(input) then
                return Enum.ContextActionResult.Sink
            end
            if state == Enum.UserInputState.Begin then hub:preInput(input) end
            return Enum.ContextActionResult.Pass
        end,false,4000,Enum.KeyCode.RightShift,Enum.KeyCode.R,Enum.KeyCode.ButtonY,Enum.KeyCode.Z,Enum.KeyCode.X,
            Enum.KeyCode.E,Enum.KeyCode.F,Enum.KeyCode.G,
            Enum.KeyCode.Q,Enum.KeyCode.Space,Enum.KeyCode.ButtonR2,Enum.KeyCode.ButtonB,
            Enum.UserInputType.MouseButton1,Enum.UserInputType.MouseButton2)
        scope:add(function() self.ContextActionService:UnbindAction(actionName) end)
        connect(self.UserInputService.JumpRequest,function() hub:requestFlight() end)
        connect(self.RunService.Heartbeat,function(dt)
            local ok,err = pcall(hub.tick,hub,dt)
            if not ok then hub:fault(err) end
        end)
        local renderName = actionName .. "_RENDER"
        self.RunService:BindToRenderStep(renderName,Enum.RenderPriority.Camera.Value+3,function(dt)
            if hub.active and not hub.closed then
                local ok,err = pcall(hub.render,hub,dt)
                if not ok then hub:fault(err) end
            end
        end)
        scope:add(function() self.RunService:UnbindFromRenderStep(renderName) end)
        if self.RunService.PreAnimation then
            connect(self.RunService.PreAnimation,function() hub:maskPose() end)
        end
        scope:add(function()
            for _, item in pairs(self.remoteConnections) do item.connection:Disconnect() end
            table.clear(self.remoteConnections)
        end)
    end
    function b:bindNative(hub)
        for _, item in ipairs({{"FeralGrabV2","grab"},{"FeralHit","feedback"},{"WolfActions","actions"},
            {"FeralBiteLocal","biteLocal","BindableEvent"}}) do
            local remote = self.ReplicatedStorage:FindFirstChild(item[1])
            local old = self.remoteConnections[item[1]]
            if old and old.remote ~= remote then old.connection:Disconnect(); self.remoteConnections[item[1]] = nil; old = nil end
            if remote and remote:IsA(item[3] or "RemoteEvent") and not old then
                local kind = item[2]
                local signal = item[3] == "BindableEvent" and remote.Event or remote.OnClientEvent
                local c = signal:Connect(function(...)
                    if hub.active and not hub.closed then hub:nativeEvent(kind,...) end
                end)
                self.remoteConnections[item[1]] = { remote = remote,connection = c }
            end
        end
    end
    return b
end
return Roblox
]============]
sources["zoom"] = [============[
-- Expand the normal camera's zoom range without replacing its controller.
local Zoom = {}
local fields = {"CameraMaxZoomDistance", "CameraMinZoomDistance", "CameraMode"}
function Zoom.new(player)
    local z = {player=player,active=false,applied=false,connections={},reason="OFF"}
    local desired = {CameraMaxZoomDistance=100000,CameraMinZoomDistance=.5,CameraMode=Enum.CameraMode.Classic}
    function z:apply()
        if not self.active or self.writing then return self.applied end
        self.writing=true
        local ok=pcall(function()
            for _,key in ipairs(fields) do
                if player[key]~=desired[key] then player[key]=desired[key] end
            end
            for _,key in ipairs(fields) do assert(player[key]==desired[key],"Camera limit rejected") end
        end)
        self.writing=false;self.applied=ok
        self.reason=ok and "Mouse-wheel zoom · 0.5–100,000 studs" or "Camera limits unavailable or rejected"
        return ok
    end
    function z:close()
        self.active=false;self.applied=false
        for _,c in ipairs(self.connections) do pcall(c.Disconnect,c) end
        self.connections={}
        local before=self.before;self.before=nil
        if before then
            -- Restore only values still owned by us. Min first keeps the
            -- original min/max pair valid when returning from the wider range.
            for _,key in ipairs({"CameraMinZoomDistance","CameraMaxZoomDistance","CameraMode"}) do
                pcall(function()if player[key]==desired[key] then player[key]=before[key] end end)
            end
        end
        self.reason="OFF"
    end
    function z:set(on)
        if not on then
            if self.active then self:close() end
            return false
        end
        if not self.active then
            local before={}
            local ok=pcall(function()
                before.CameraMaxZoomDistance=player.CameraMaxZoomDistance
                before.CameraMinZoomDistance=player.CameraMinZoomDistance
                before.CameraMode=player.CameraMode
                assert(type(before.CameraMaxZoomDistance)=="number" and type(before.CameraMinZoomDistance)=="number"
                    and before.CameraMode~=nil,"Camera properties unavailable")
            end)
            if not ok then self.reason="Camera properties unavailable";return false end
            self.before=before;self.active=true
            local attached=pcall(function()
                for _,key in ipairs(fields) do
                    local c=player:GetPropertyChangedSignal(key):Connect(function()
                        if not self.active or self.writing then return end
                        local current=player[key]
                        if current~=desired[key] then
                            -- A respawn/species script can publish new defaults.
                            -- Remember those for OFF/unload instead of stale ones.
                            self.before[key]=current
                            self:apply()
                        end
                    end)
                    table.insert(self.connections,c)
                end
            end)
            if not attached then self:close();self.reason="Camera observation unavailable";return false end
        end
        return self:apply()
    end
    return z
end
return Zoom
]============]
sources["ui"] = [============[
-- One compact window and one owner for all hub outlines, tags and the bite dot.
local UI = {}
function UI.healthColour(hp,maxHP)
    if type(hp) ~= "number" or type(maxHP) ~= "number" or hp ~= hp or maxHP ~= maxHP
        or math.abs(hp) >= 1e12 or math.abs(maxHP) >= 1e12 or maxHP <= 0 then
        return Color3.fromRGB(151,173,194)
    end
    local ratio = math.clamp(hp/maxHP,0,1)
    return Color3.fromRGB(255*math.min(1,2*(1-ratio)),255*math.min(1,2*ratio),0)
end
function UI.mount(hub, bridge, scope)
    local player = bridge.player
    local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",10)
    assert(pg,"PlayerGui unavailable")
    local u = { visible = true, rows = {}, records = {}, nextText = 0, nextFit = 0,
        tab = hub.settings.tab, lastPoint = nil,pages={},pageView=nil }
    local palette = {
        bg = Color3.fromRGB(12,17,28), side = Color3.fromRGB(15,22,36),
        panel = Color3.fromRGB(22,31,48), line = Color3.fromRGB(48,65,85),
        text = Color3.fromRGB(239,246,252), sub = Color3.fromRGB(151,173,194),
        same = Color3.fromRGB(77,219,194), other = Color3.fromRGB(236,105,126),
        unknown = Color3.fromRGB(236,181,104), off = Color3.fromRGB(60,77,97),
        on = Color3.fromRGB(27,111,98),
    }
    local function make(class,properties,parent)
        local object = Instance.new(class)
        for key,value in pairs(properties or {}) do object[key] = value end
        object.Parent = parent
        return object
    end
    local function assign(object,key,value)
        if object[key]~=value then object[key]=value end
    end
    local function round(object,radius)
        make("UICorner",{CornerRadius = UDim.new(0,radius or 9)},object)
        return object
    end
    local function text(parent,body,x,y,w,h,size,colour)
        return make("TextLabel",{Text = body, BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.fromOffset(x,y), Size = UDim2.fromOffset(w,h),
            Font = Enum.Font.Gotham, TextSize = size or 12, TextColor3 = colour or palette.text,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd},parent)
    end
    local function button(parent,body,x,y,w,h)
        return round(make("TextButton",{Text = body, AutoButtonColor = true,
            BackgroundColor3 = palette.off, BorderSizePixel = 0, TextColor3 = palette.text,
            Font = Enum.Font.GothamMedium, TextSize = 11, Position = UDim2.fromOffset(x,y),
            Size = UDim2.fromOffset(w,h)},parent),7)
    end
    -- Parent ownership is registered immediately, before any child creation.
    local gui = Instance.new("ScreenGui")
    scope:add(function() gui:Destroy() end)
    gui.Name = "FeralRenaissanceV15_" .. tostring(hub.token)
    gui.ResetOnSpawn, gui.Enabled, gui.IgnoreGuiInset = false,false,true
    gui.DisplayOrder = 350
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = pg
    u.gui = gui
    local folder = Instance.new("Folder")
    scope:add(function() folder:Destroy() end)
    folder.Name,folder.Parent = gui.Name .. "_Outlines",bridge.Workspace
    local frame = round(make("Frame",{Size = UDim2.fromOffset(704,505),
        Position = UDim2.fromScale(.5,.5), AnchorPoint = Vector2.new(.5,.5),
        BackgroundColor3 = palette.bg, BorderSizePixel = 0, Active = true},gui),15)
    u.frame = frame
    local scale = make("UIScale",{},frame)
    local side = round(make("Frame",{Size = UDim2.fromOffset(165,505),
        BackgroundColor3 = palette.side, BorderSizePixel = 0},frame),15)
    text(side,"F E R A L",18,22,130,28,20)
    text(side,"RENAISSANCE  /  15.7.0",18,52,140,18,10,palette.same)
    local content = make("Frame",{BackgroundTransparency = 1,Position = UDim2.fromOffset(181,17),
        Size = UDim2.fromOffset(511,470)},frame)
    local title = text(content,u.tab,10,0,470,30,19)
    local subtitle = text(content,"Simple controls. Native gameplay remains in charge.",10,34,480,20,11,palette.sub)
    local cards = make("Frame",{BackgroundTransparency = 1,Position = UDim2.fromOffset(10,68),
        Size = UDim2.fromOffset(490,365)},content)
    text(content,"Client changes and predictions · gameplay results unverified",10,440,485,18,10,palette.sub)
    local footer = text(side,"Ready",14,452,140,39,10,palette.sub)
    footer.TextWrapped = true
    local hide = button(side,"HIDE  ·  RIGHT SHIFT",12,378,141,30)
    local unload = button(side,"UNLOAD",12,414,141,27)
    local tabs = {}
    local function card(y,height)
        return round(make("Frame",{Position = UDim2.fromOffset(0,y),Size = UDim2.fromOffset(490,height),
            BorderSizePixel = 0,BackgroundColor3 = palette.panel},cards),9)
    end
    local function info(y,heading,body,height)
        local c = card(y,height or 75)
        text(c,heading,14,8,460,20,13,palette.same)
        local t = text(c,body,14,33,459,(height or 75)-37,11,palette.sub)
        t.TextWrapped = true
        return t
    end
    local function row(id,y)
        local f = hub.registry.byId[id]
        local c = card(y,50)
        text(c,f.title,13,4,365,21,13)
        local status = text(c,f.detail,13,27,365,18,10,palette.sub)
        local toggle = button(c,"OFF",394,9,82,32)
        u.rows[id] = { toggle = toggle, status = status }
        toggle.Activated:Connect(function()
            if not hub.active then return end
            hub:set(id,not hub.registry.byId[id].requested)
            u.nextText = 0
        end)
    end
    local function draw()
        if u.pageView and u.pageView.close then pcall(u.pageView.close,u.pageView) end
        u.pageView=nil
        for _, child in ipairs(cards:GetChildren()) do child:Destroy() end
        u.rows,u.combatReadout,u.finderReadout = {},nil,nil
        title.Text = string.upper(u.tab)
        subtitle.Text="Simple controls. Native gameplay remains in charge."
        if u.pages[u.tab] then
            u.pageView=u.pages[u.tab]:mount(cards,{
                text=text,button=button,palette=palette,make=make,card=card})
            subtitle.Text="Automatic territory, survival and native movement in one hub."
        elseif u.tab=="Territory" then
            info(0,"TERRITORY FARMING","Territory controls initialise with this hub. If unavailable, reload the current Renaissance launcher.",100)
        elseif u.tab == "Combat" then
            info(0,"BITE REACH  ·  ALWAYS ON","Wider client range with rear and vertical assistance. Server acceptance unverified.",78)
            row("biteHelper",94)
            info(161,"RANGE COLOURS","Teal: stock-reference range. Amber: extended only. Grey: blocked, cooling down or readiness unknown.",80)
            u.combatReadout = info(258,"NATIVE COMBAT","Waiting for an animal.",100)
        elseif u.tab == "Vision" then
            row("esp",0); row("tags",57)
            local c = card(123,52)
            text(c,"Tracking range",14,8,270,20,13)
            text(c,"Real players only · up to 24",14,29,320,17,10,palette.sub)
            local range = button(c,tostring(hub.settings.range) .. " STUDS",350,10,124,30)
            range.Activated:Connect(function()
                if not hub.active then return end
                local old = hub.settings.range
                hub.settings.range = old == 300 and 600 or old == 600 and 900 or 300
                range.Text = tostring(hub.settings.range) .. " STUDS"
                hub:save(); hub.nextScan = 0
            end)
            local walls = button(cards,"Through-wall outlines: " .. (hub.settings.walls and "ON" or "OFF"),0,187,490,32)
            walls.Activated:Connect(function()
                if not hub.active then return end
                hub.settings.walls = not hub.settings.walls
                walls.Text = "Through-wall outlines: " .. (hub.settings.walls and "ON" or "OFF")
                hub:save()
            end)
            info(232,"HEALTH / PACK","Outlines: green → yellow → red as HP falls. Real players only; name colour shows pack.",70)
            u.finderReadout = info(313,"PLAYER FINDER","Waiting for replicated players.",50)
        else
            local order = u.tab == "Survival"
                and {"stamina","recovery","escape","robloxAFK","survivalAFK","minigame"}
                or {"climb","flight","mobility","speed","leap","zoom"}
            for i,id in ipairs(order) do row(id,(i-1)*57) end
        end
        for name,btn in pairs(tabs) do btn.BackgroundColor3 = name == u.tab and Color3.fromRGB(27,111,98) or palette.panel end
        u.nextText = 0
    end
    for i,name in ipairs({"Survival","Combat","Movement","Vision","Territory"}) do
        local btn = button(side,string.upper(name),12,113+(i-1)*44,141,35)
        tabs[name] = btn
        btn.Activated:Connect(function()
            if not hub.active then return end
            u:selectTab(name)
        end)
    end
    function u:selectTab(name)
        if not tabs[name] then return false end
        self.tab,hub.settings.tab=name,name
        draw();if hub.active then hub:save() end
        return true
    end
    function u:registerPage(name,definition)
        assert(tabs[name] and type(definition.mount)=="function","Unsupported hub page")
        self.pages[name]=definition
        if self.tab==name then draw() end
        local registration={closed=false}
        function registration:close()
            if self.closed then return end
            self.closed=true
            if u.pages[name]==definition then
                u.pages[name]=nil
                if u.tab==name and not hub.closed then draw() end
            end
        end
        return registration
    end
    function u:toggle()
        self.visible = not self.visible
        frame.Visible = self.visible
        hub.policy.menuOpen = self.visible
        self.nextText=0
        if self.visible then hub:stopWalk("menu opened") end
    end
    function u:contains(point)
        if not self.visible or not gui.Enabled then return false end
        local p,s = frame.AbsolutePosition,frame.AbsoluteSize
        return point.X >= p.X and point.X <= p.X+s.X and point.Y >= p.Y and point.Y <= p.Y+s.Y
    end
    hide.Activated:Connect(function() if hub.active then u:toggle() end end)
    unload.Activated:Connect(function() if hub.active then hub:close() end end)
    local dot = round(make("Frame",{Name = "BiteRangeMarker",BackgroundTransparency = 1,
        Size = UDim2.fromOffset(15,15),AnchorPoint = Vector2.new(.5,.5),Visible = false},gui),50)
    local dotStroke = make("UIStroke",{Thickness = 1.5,Transparency = .05,Color = palette.same},dot)
    function u:syncTracked(tracked)
        local keep = {}
        for _, target in ipairs(tracked) do
            if not target.player or bridge.Players:GetPlayerFromCharacter(target.char) ~= target.player then continue end
            local char = target.char
            keep[char] = true
            local record = self.records[char]
            if not record then
                local highlight = Instance.new("Highlight")
                highlight.Name,highlight.Adornee = "Outline",char
                highlight.FillTransparency,highlight.OutlineTransparency = 1,0
                highlight.Enabled,highlight.Parent = false,folder
                local label = text(gui,"",0,0,180,18,11)
                label.TextXAlignment, label.AnchorPoint = Enum.TextXAlignment.Center,Vector2.new(.5,1)
                record = { highlight = highlight,label = label }
                self.records[char] = record
            end
            record.target = target
            record.head=char:FindFirstChild("Head")
        end
        for char,record in pairs(self.records) do
            if not keep[char] then
                record.highlight:Destroy(); record.label:Destroy()
                self.records[char] = nil
            end
        end
    end
    function u:render(dt,now)
        local camera = bridge.Workspace.CurrentCamera
        if not camera then return end
        if now >= self.nextFit then
            self.nextFit = now+.5
            local size = camera.ViewportSize
            assign(scale,"Scale",math.clamp(math.min((size.X-25)/704,(size.Y-30)/505,1),.5,1))
        end
        local registry = hub.registry.byId
        for char,record in pairs(self.records) do
            local target = record.target
            local valid = target.player and target.player.Parent~=nil and target.player.Character==char
                and char.Parent ~= nil and target.root.Parent ~= nil and target.hum.Parent ~= nil and target.hum.Health > 0
            local colour = palette[target.affiliation] or palette.unknown
            assign(record.highlight,"FillTransparency",1)
            if registry.esp.requested then
                local hp,maxHP=target.hum.Health,target.hum.MaxHealth
                if record.hp~=hp or record.maxHP~=maxHP then
                    record.hp,record.maxHP=hp,maxHP
                    record.healthColour=UI.healthColour(hp,maxHP)
                end
                assign(record.highlight,"OutlineColor",record.healthColour)
                assign(record.highlight,"DepthMode",hub.settings.walls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded)
            end
            assign(record.highlight,"Enabled",valid and registry.esp.requested)
            local projected,onScreen
            if valid and registry.tags.requested then
                local head=record.head
                local pos=head and head.Parent and head:IsA("BasePart") and head.Position+Vector3.new(0,head.Size.Y*.65,0)
                    or target.root.Position+Vector3.new(0,target.root.Size.Y*.6+1,0)
                projected,onScreen=camera:WorldToViewportPoint(pos)
            end
            local show=valid and registry.tags.requested and onScreen==true and projected.Z>0
            assign(record.label,"Visible",show)
            if show then
                local x,y = projected.X,math.max(20,projected.Y-6)
                if not record.x or math.abs(x-record.x)>=.25 or math.abs(y-record.y)>=.25 then
                    record.x,record.y=x,y;record.label.Position=UDim2.fromOffset(x,y)
                end
                assign(record.label,"Text",target.name)
                assign(record.label,"TextColor3",colour)
            end
        end
        local guide = hub.guide
        local dotVisible=false
        if registry.biteHelper.requested and guide and not guide.invalid and guide.target.root.Parent then
            local point,onScreen = camera:WorldToViewportPoint(guide.target.root.Position)
            if onScreen and point.Z > 0 then
                local desired = Vector2.new(point.X,point.Y)
                if self.lastTarget~=guide.target.char then self.lastPoint=nil;self.lastTarget=guide.target.char end
                self.lastPoint = self.lastPoint and self.lastPoint:Lerp(desired,1-math.exp(-22*math.min(dt,.1))) or desired
                if self.dotX~=self.lastPoint.X or self.dotY~=self.lastPoint.Y then
                    self.dotX,self.dotY=self.lastPoint.X,self.lastPoint.Y
                    dot.Position=UDim2.fromOffset(self.dotX,self.dotY)
                end
                dotVisible = true
                local readiness=hub.biteReadiness
                local stale=now-(hub.guideAt or -math.huge)>.35
                local locked=not readiness or not readiness.ready
                if guide.blocked or locked or stale then assign(dotStroke,"Color",palette.sub)
                elseif guide.baseline and guide.baseline.valid then assign(dotStroke,"Color",palette.same)
                else assign(dotStroke,"Color",palette.unknown) end
            end
        else self.lastPoint,self.lastTarget = nil,nil end
        assign(dot,"Visible",dotVisible)
        if not self.visible then return end
        if now < self.nextText then return end
        self.nextText = now+.25
        if self.pageView and self.pageView.tick then self.pageView:tick(now) end
        for id,rowValue in pairs(self.rows) do
            local feature = registry[id]
            assign(rowValue.toggle,"Text",not feature.requested and "OFF"
                or feature.applied and (feature.state == "PARTIAL" and "PARTIAL"
                    or feature.state == "ARMED" and "ARMED" or "ON") or "WAIT")
            assign(rowValue.toggle,"BackgroundColor3",feature.requested and feature.applied
                and (feature.state == "PARTIAL" and palette.unknown or palette.on) or palette.off)
            assign(rowValue.status,"Text",feature.requested and feature.reason ~= "" and feature.reason or feature.detail)
        end
        assign(footer,"Text",hub.rescue.pending and hub.rescue.status
            or hub.feeding.busy and hub.feeding.status or hub.notice or "Right Shift opens menu")
        if self.combatReadout then
            assign(self.combatReadout,"Text",(hub.biteReadiness and hub.biteReadiness.reason or "Native timing unmeasured")
                .."\n"..(hub.combatStatus or "Watching native attacks") .. "\n" .. hub.rescue.status)
        end
        if self.finderReadout then
            assign(self.finderReadout,"Text",string.format("%d shown · %d in range · %.0f studs",#bridge.tracked,bridge.replicatedCount or 0,hub.settings.range))
        end
    end
    function u:activate()
        gui.Enabled = true
        hub.policy.menuOpen = self.visible
    end
    draw()
    return u
end
return UI
]============]
sources["controller"] = [============[
local Controller = {}
function Controller.new(M,bridge,options)
    local Core = M.core
    local tokenIdentity = {}
    local h = { version = "15.7.1", tokenIdentity = tokenIdentity,
        token = (tostring(tokenIdentity):gsub("[^%w]","")) .. "_" .. tostring(math.floor(bridge.clock()*1000000)),
        active = false, closed = false, ready = false, scope = Core.scope(),
        registry = Core.registry(), policy = M.policy.new(), ledger = Core.ledger(160),
        nextScan = 0, nextSlow = 0, nextBind = 0, nextSample = 0, nextEscape = 0,
        nextWalk = bridge.clock()+90, nextIdle = bridge.clock()+75,
        transactions = {}, earlyInputs = setmetatable({},{__mode = "k"}),
        notice = "Ready · Right Shift opens menu", bridge = bridge, options = options or {} }
    h.policy.lastPhysical = bridge.clock()
    h.settings,h.settingsOrigin = M.settings.load(bridge:io(),Core.specs)
    if h.options.settings then h.settings = M.settings.sanitize(h.options.settings,Core.specs) end
    for _,feature in ipairs(h.registry.order) do
        if not feature.permanent and not feature.linked then h.registry:request(feature.id,h.settings.states[feature.id]) end
    end
    h.features = M.features.new(Core,bridge,h.registry)
    h.grab = M.grab.new()
    h.grabInput = M.grab_input.new(bridge,h.token)
    h.recovery = M.recovery.new(bridge,h.policy,h.ledger)
    h.feeding = M.feeding.new(bridge,h.policy,h.ledger)
    h.combatInput = M.combat_input.new(bridge,h.policy,h.ledger)
    h.rescue = M.rescue.new(bridge,h.ledger)
    h.zoom = M.zoom.new(bridge.player)
    h.settingsAvailable = bridge:io().available ~= false
    function h:save()
        if self.closed then return false end
        for id in pairs(self.settings.states) do self.settings.states[id] = self.registry.byId[id].requested end
        local ok,why = M.settings.save(bridge:io(),self.settings,Core.specs)
        self.settingsAvailable = ok
        self.registry:ack("settings",ok,ok and "CLIENT" or "UNAVAILABLE",why)
        if not ok then self.notice = "Settings stay in memory · saving unavailable" end
        return ok
    end
    function h:stopWalk(reason)
        local walk = self.walk
        self.walk = nil
        if walk then
            pcall(bridge.walk,bridge,walk.snapshot,nil)
            self.ledger:event("afk_walk_stopped",bridge.clock(),{reason = reason})
        end
    end
    function h:clearFlight()
        self:releaseFlightRepair()
        self.flightEpisode,self.flightStatus=nil,nil
        self.features.leases:release("surface")
        self.surfaceUntil = nil
        if self.drop then
            bridge:restoreAttribute(self.drop.char,"FeralFlyDrop",true,self.drop.before)
            self.drop = nil
        end
    end
    function h:releaseFlightRepair()
        local r=self.flightRepair;self.flightRepair=nil
        if r then
            bridge:restoreAttribute(r.char,"FeralFlyDrop",true,nil)
            bridge:restoreAttribute(r.char,"FeralFlyRelaunch",r.at,nil)
        end
    end
    function h:noteFlightCancel(input,s,now)
        if not self.registry.byId.flight.requested or self.grab.active
            or bridge:attribute(s.char,"Species")~="Vulture" or s.talonLock==nil then return end
        local info=bridge.ContextActionService:GetAllBoundActionInfo().FeralTalonLetGo
        for _,key in ipairs(info and info.inputTypes or {}) do
            if key==input.KeyCode then
                local q=self.flightEpisode
                if not q or q.char~=s.char or q.lock~=s.talonLock then
                    q={char=s.char,generation=s.generation,lock=s.talonLock,at=now}
                    self.flightEpisode=q
                end
                q.cancelAt=now
                q.airborne=q.airborne or s.flying or s.hum.FloorMaterial==Enum.Material.Air
                return
            end
        end
    end
    function h:stepFlightHandoff(s,now)
        if self.flightRepair then
            local r=self.flightRepair
            if not s.alive or r.char~=s.char or s.grab or s.captured or s.ability or s.chat or s.gameMenu
                or now-r.at>1.5 then self:releaseFlightRepair()
            elseif (s.root.Position-r.position).Magnitude>1.5 and s.root.AssemblyLinearVelocity.Magnitude>2 then
                self.flightStatus="Movement observed after native restart; cause unverified"
                self.ledger:event("post_attack_flight_motion_observed",now)
                self:releaseFlightRepair()
            end
        end
        if not self.registry.byId.flight.requested or not s.alive then self.flightEpisode=nil;return end
        local config=bridge:config("FlightConfig")
        if not config or type(config.canFly)~="function" then self.flightEpisode=nil;return end
        local compatible,eligible=pcall(config.canFly,s.char)
        if not compatible or eligible~=true then
            self.flightEpisode=nil;return
        end
        local q=self.flightEpisode
        local lock,kind=s.talonLock,"talon"
        if lock==nil then lock,kind=s.diveLock,"dive" end
        if lock~=nil then
            if not q or q.char~=s.char or q.lock~=lock or q.kind~=nil and q.kind~=kind then
                q={char=s.char,generation=s.generation,lock=lock,kind=kind,at=now};self.flightEpisode=q
            end
            q.airborne=q.airborne or s.flying or s.hum.FloorMaterial==Enum.Material.Air
            -- Replay only an actual native let-go intent, once for this session.
            -- Server/native cleanup owns anchoring and capture restrictions.
            if kind=="talon" and q.cancelAt and not q.releaseRetried and now-q.cancelAt>=1 and now-q.cancelAt<3
                and not s.grab and not s.captured and not s.chat and not s.gameMenu then
                q.releaseRetried=true
                local sent=bridge:fire("FeralLunge","release")
                self.flightStatus="Native attack release retried; response unconfirmed"
                self.ledger:event("native_talon_release_retried",now,{sent=sent})
            end
            return
        end
        if not q or q.char~=s.char or q.generation~=s.generation then self.flightEpisode=nil;return end
        if not q.airborne then self.flightEpisode=nil;return end
        q.ended=q.ended or now
        if now-q.ended>4 then self.flightEpisode=nil;return end
        if s.grab or s.captured or s.ability or s.chat or s.gameMenu or s.underwater or s.swimming
            or s.climbing or s.attackHeld or s.root.Anchored or s.hum.FloorMaterial~=Enum.Material.Air
            or s.hum.MoveDirection.Magnitude<=.13 or s.root.AssemblyLinearVelocity.Magnitude>=.6 then q.stillAt=nil;return end
        local vel=s.root:FindFirstChild("FeralFlyVel")
        local rot=s.root:FindFirstChild("FeralFlyRot")
        if not s.flying or not vel or not vel:IsA("LinearVelocity") or not rot or not rot:IsA("AlignOrientation") then return end
        q.stillAt=q.stillAt or now
        if now-q.stillAt<.75 or q.restarted or self.timingCritical then return end
        if bridge:attribute(s.char,"FeralFlyDrop")~=nil or bridge:attribute(s.char,"FeralFlyRelaunch")~=nil then return end
        -- v2412 FeralFlight consumes these normal drop/relaunch intents. Never
        -- edit native movers, anchors, velocities, capture flags or positions.
        q.restarted=true
        self.flightRepair={char=s.char,at=now,position=s.root.Position}
        local a=bridge:setAttribute(s.char,"FeralFlyRelaunch",now)
        local b=a and bridge:setAttribute(s.char,"FeralFlyDrop",true)
        if not b then self:releaseFlightRepair() end
        self.flightStatus=b and "Native flight restart requested; movement unconfirmed" or "Native restart unavailable"
        self.ledger:event("post_attack_native_flight_restart",now,{sent=b==true})
    end
    function h:set(id,on)
        if self.closed or not self.active then return false end
        local feature = assert(self.registry.byId[id],"unknown feature")
        if feature.permanent or feature.linked then return false end
        self.registry:request(id,on)
        local now = bridge.clock()
        if id == "recovery" and not on then self.recovery.enabled = false; self.recovery:release("OFF",now) end
        if id == "minigame" then
            self.grab.enabled = on == true
            if not on then self.grab:reset("OFF"); self.grabInput:release();self:cancelGrabWake() end
        end
        if id == "survivalAFK" and not on then self:stopWalk("disabled") end
        if id == "flight" and not on then self:clearFlight() end
        if id == "robloxAFK" then self.idleUnavailable = nil end
        if id == "climb" and not on then self.climbQueue = nil end
        self.features.nextReconcile = 0
        local s = bridge:snapshot(now,false)
        self.features:reconcile(s,now,true) -- both true AND false are reconciled
        self:ackLocal(s)
        self:save()
        return self.registry.byId[id].applied == (on == true)
    end
    function h:characterChanged(generation)
        local now = bridge.clock()
        self.recovery:release("animal changed",now)
        self.recovery:clearPose()
        self.recovery.lastAutomaticCharacter,self.recovery.previous = nil,nil
        self.recovery.observations,self.recovery.nativeEchoObserved = {},false
        bridge.biteTiming,bridge.deferNativeDiscovery=nil,false
        self.policy.manualRest,self.policy.manualIntentUntil = false,0
        self.grab:reset("animal changed")
        self:cancelGrabWake()
        self.grabInput:release()
        self.feeding:close(now)
        self.combatInput:cancel()
        self.rescue:cancel("animal changed")
        self:stopWalk("animal changed")
        self:clearFlight()
        self.features:releaseFlag()
        self.features.nextReconcile = 0
        self.climbQueue,self.guide,self.transactions,self.lastIntent = nil,nil,{},nil
        self.ledger.previous = nil
        self.ledger.staminaObservation=nil
        self.anchor,self.anchorChar = nil,nil
        self.ledger:event("character_generation",now,{generation = generation})
        self.nextWalk = now+90
    end
    function h:physicalInput(kind)
        local now = bridge.clock()
        if kind == "mouse" and now < (self.syntheticUntil or 0) then return end
        self.policy.lastPhysical = now
        self:stopWalk("manual input")
        self.nextWalk = now+90
        self.anchor,self.anchorChar = nil,nil
    end
    function h:isRestControl(input)
        local point = input.Position
        if not point then return false end
        local pg = bridge.player:FindFirstChildOfClass("PlayerGui")
        local ok,objects = pcall(function() return pg:GetGuiObjectsAtPosition(point.X,point.Y) end)
        if not ok then return false end
        for _,object in ipairs(objects) do
            if not object:IsDescendantOf(self.ui.gui) then
                local node = object
                for _ = 1,4 do
                    if not node then break end
                    local body = node.Name
                    if node:IsA("TextButton") or node:IsA("TextLabel") then body = node.Text end
                    body=string.upper(body):match("^%s*(.-)%s*$")
                    if node.Name=="FeralRestTap" or node.Name=="WolfRest" or node.Name=="RestButton"
                        or body=="REST" or body=="REST [R]" or body=="REST (R)" or body=="STAND UP" then return true end
                    node = node.Parent
                end
            end
        end
        return false
    end
    function h:isFeedControl(input)
        local point=input.Position
        local pg=bridge.player:FindFirstChildOfClass("PlayerGui")
        if not point or not pg then return false end
        local ok,objects=pcall(pg.GetGuiObjectsAtPosition,pg,point.X,point.Y)
        if not ok then return false end
        for _,object in ipairs(objects) do
            if not object:IsDescendantOf(self.ui.gui) then
                local node=object
                for _=1,4 do
                    if not node then break end
                    local text=(node:IsA("TextLabel") or node:IsA("TextButton")) and node.Text or ""
                    text=string.upper(text):match("^%s*(.-)%s*$")
                    if text=="EAT" or text=="DRINK" or node.Name=="FeralFeedTap" then return true end
                    node=node.Parent
                end
            end
        end
        return false
    end
    function h:carryInput(input)
        if not self.active or self.closed or bridge:grabTextFocused() then return false end
        local now=bridge.clock()
        local s=bridge:snapshot(now,true);s.grab=self.grab.active
        local handled=self.rescue:input(s,now)
        if handled then
            self.earlyInputs[input]=now
            self:physicalInput("other")
            self.policy:input("action",now)
            self.recovery:release("cub rescue input",now)
            self.combatInput:cancel()
            self:stopWalk("cub rescue input")
        end
        return handled
    end
    function h:preInput(input)
        if self.closed or not self.active or bridge.UserInputService:GetFocusedTextBox() then return end
        local now,key,kind = bridge.clock(),input.KeyCode,input.UserInputType
        local previous = self.earlyInputs[input]
        if previous and now-previous < .1 then return end
        self.earlyInputs[input] = now
        local click = kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2
        local primary = kind == Enum.UserInputType.MouseButton1
        local point = bridge.UserInputService:GetMouseLocation()
        if click and self.ui:contains(point) then return end
        local s = bridge:snapshot(now,false)
        if s.gameMenu then return end
        self.features:hippoInput(s,key)
        if key == Enum.KeyCode.R or key == Enum.KeyCode.ButtonY
            or ((primary or kind == Enum.UserInputType.Touch) and self:isRestControl(input)) then
            self.policy:input("rest",now)
            self.recovery:manual(now)
            self.combatInput:cancel();self.feeding:cancel("manual rest control",now);self.rescue:cancel()
            return
        end
        if self.grab.active and (key == Enum.KeyCode.Space or key == Enum.KeyCode.ButtonA or key == Enum.KeyCode.ButtonR2) then
            self.grab:manual()
            self:cancelGrabWake()
            return
        end
        if key==Enum.KeyCode.Space or key==Enum.KeyCode.ButtonB then self:noteFlightCancel(input,s,now) end
        if key == Enum.KeyCode.E or (primary or kind == Enum.UserInputType.Touch) and self:isFeedControl(input) then
            self.feeding:input(s,now)
            self.policy:input("action",now)
            self.recovery:release("manual feeding input",now)
            self.combatInput:cancel();self.rescue:cancel()
            return
        end
        if primary or key == Enum.KeyCode.ButtonR2 then
            self.policy:input("attack",now)
            self.recovery:release("attack input",now)
            if primary or key == Enum.KeyCode.ButtonR2 then
                self.feeding:attack(s,now);self.rescue:cancel()
                local tx = { intent = now, lock = self.policy:restLocked(now), generation = s.generation }
                self.lastIntent = tx
                table.insert(self.transactions,tx)
                if #self.transactions > 32 then table.remove(self.transactions,1) end
                self.ledger:event("attack_intent",now,{restLock = tx.lock})
                self.combatInput:input(s,now)
            end
        elseif key == Enum.KeyCode.E or key == Enum.KeyCode.F or key == Enum.KeyCode.G
            or key==Enum.KeyCode.Z or key==Enum.KeyCode.X
            or key == Enum.KeyCode.Q or key == Enum.KeyCode.Space then
            self.policy:input("action",now)
            self.recovery:release("manual native action",now)
            self.combatInput:cancel()
            if key ~= Enum.KeyCode.Space then self.rescue:cancel() end
        end
    end
    function h:input(input,processed)
        local kind,key = input.UserInputType,input.KeyCode
        if kind == Enum.UserInputType.MouseButton2 and bridge.clock() < (self.syntheticUntil or 0) then return end
        self:physicalInput("other")
        if bridge.UserInputService:GetFocusedTextBox() then return end
        self:preInput(input)
        if processed then return end
        if key == Enum.KeyCode.Q and self.registry.byId.climb.requested then
            local s = bridge:snapshot(bridge.clock(),false)
            local allowed = self.policy:allowed("climb",s,s.now)
            if allowed and not s.climbing and type(s.climber) == "number" and s.climber >= 1 then
                self.climbQueue = { generation = s.generation, expires = s.now+2.25,
                    earliest = s.now+.1, attempts = 0 }
            end
        end
    end
    function h:nativeAttribute(key)
        if self.closed or not self.active then return end
        local now = bridge.clock()
        local s = bridge:snapshot(now,false)
        if key=="FeralCrushAt" then self.features:hippoAttribute(s) end
        if key == "WolfRest" then self.recovery:echo(s,now)
        elseif key == "WolfBiteAt" and Core.finite(bridge:attribute(s.char,key)) then
            bridge.biteTiming=nil
            if not s.alive then return end
            self.combatInput:cancel()
            self.policy.attackUntil = math.max(self.policy.attackUntil,now+1.1)
            self.recovery:release("native bite marker",now)
            local tx = self.lastIntent
            if not tx or tx.nativeAt or now-tx.intent > 1.3 then
                tx = { intent = now,generation = s.generation }
                table.insert(self.transactions,tx)
                if #self.transactions > 32 then table.remove(self.transactions,1) end
            end
            tx.nativeAt,tx.claimDue,tx.classified = now,now+bridge:biteDelay(s.char),false
            tx.hpBefore={}
            for _,target in ipairs(bridge.allCandidates or {}) do
                if target.root.Parent and (target.root.Position-s.root.Position).Magnitude<=45 then
                    tx.hpBefore[target.char]={hp=target.hum.Health,maxHP=target.hum.MaxHealth}
                end
            end
            self.ledger:event("native_bite_marker",now,{requestObserved = false,claimObserved = false})
        else
            -- Native actions can begin between heartbeats. Release competing
            -- automation on the actual state change, preserving manual input.
            s.grab,s.rescuing = self.grab.active,self.rescue.pending~=nil
            s.feeding = s.feeding or self.feeding.busy
            local allowed,why=self.policy:allowed("recovery",s,now,self.recovery.purpose)
            if self.recovery.owned and not allowed then self.recovery:release(why,now) end
            if s.captured or s.grab or s.ability or s.flying or s.climbing or s.feeding then
                self:stopWalk("native action began")
                if s.captured or s.ability or s.flying then self.climbQueue=nil end
            end
            if key=="FeralTalonLock" or key=="FeralDiveLocal" then self:stepFlightHandoff(s,now) end
        end
    end
    function h:nativeEvent(kind,event,data)
        if self.closed or not self.active then return end
        if kind == "feedback" then
            self.ledger:event("native_hit_feedback",bridge.clock(),{damageAcceptance = "unverified"})
            if event=="hit" and type(data)=="table" and data.a==bridge.player.Character then
                for index=#self.transactions,1,-1 do
                    local tx=self.transactions[index]
                    if tx.nativeAt and not tx.classified and bridge.clock()-tx.nativeAt<1.8 then
                        tx.feedback=data;tx.nativeTarget=data.v
                        self.ledger:event("native_outgoing_hit_reply",bridge.clock(),{safe=data.safe==true,damage=data.dmg})
                        break
                    end
                end
            end
            return
        end
        if kind=="actions" then
            if event=="FeedStop" then self.feeding:stopped(data,bridge.clock()) end
            return
        end
        if kind=="biteLocal" then
            for index=#self.transactions,1,-1 do
                local tx=self.transactions[index]
                if tx.nativeAt and not tx.classified and bridge.clock()-tx.nativeAt<1.5 then
                    tx.nativeTarget=event
                    self.ledger:event("native_client_bite_candidate",bridge.clock(),{claimObserved=false})
                    break
                end
            end
            return
        end
        local now = bridge:serverNow()
        if not now then return end
        local c = bridge:config("GrabV2Config")
        local handled = self.grab:event(event,data,now,bridge.generation,c and c.PERFECT or .32,c and c.PASSES or 2.5,
            {character=bridge.player.Character,bitePause=c and c.BITE_PAUSE or .6})
        if handled then
            self.recovery:release("native minigame",bridge.clock())
            self:stopWalk("native minigame")
            self.ledger:event("native_grab_" .. tostring(event),bridge.clock(),
                {tier = event == "res" and data.mine == true and data.tier or nil})
            if event == "begin" then
                bridge.nextGrabDiscovery = 0
                if not bridge.grabController then bridge.nativeScan=nil end
            end
            bridge.deferNativeDiscovery=self.grab.enabled and self.grab.pending~=nil
            if event=="begin" or event=="strike" then self.grabInput.nextBindingCheck=0 end
            self.grabInput:update(self.grab,bridge.clock())
            if event=="strike" then self:pumpGrab(bridge:grabSnapshot(bridge.clock()),false) end
            self:updateGrabWake()
        end
    end
    function h:cancelGrabWake()
        local wake=self.grabWake;self.grabWake=nil
        if wake then bridge:cancelDelay(wake.handle) end
    end
    function h:updateGrabWake()
        local p=self.grab.pending
        local wake=self.grabWake
        if wake and wake.pending==p and wake.at==p.at then return end
        self:cancelGrabWake()
        if not self.active or self.closed or not self.grab.enabled or not p or (p.wakes or 0)>=4 then return end
        local now=bridge:serverNow()
        if not now or p.at<=now then return end
        wake={pending=p,at=p.at};self.grabWake=wake
        wake.handle=bridge:delay(math.max(.001,p.at-now),function()
            if self.grabWake~=wake then return end
            self.grabWake=nil
            if self.active and not self.closed and self.grab.enabled and self.grab.pending==p then
                self:pumpGrab(bridge:grabSnapshot(bridge.clock()),true)
                self:updateGrabWake()
            end
        end)
        if wake.handle then p.wakes=(p.wakes or 0)+1 else self.grabWake=nil end
    end
    function h:pumpGrab(s,sync)
        if self.closed or not self.active or not self.grab.enabled or not self.grab.active then return end
        local now,clock=s.now,s.serverNow
        if not clock or not s.alive then return end
        local native=bridge.grabController
        if sync and native then
            local state,known=native.state()
            local cfg=bridge:config("GrabV2Config")
            if state or known==true then
                self.grab:syncNative(state,clock,s.generation,cfg and cfg.PERFECT or .32,cfg and cfg.PASSES or 2.5,now)
            end
        end
        local p=self.grab.pending
        if not p then return end
        if self.lastGrabClock==clock and self.lastGrabPending==p then return end
        self.lastGrabClock,self.lastGrabPending=clock,p
        s.grab=true
        self.grab:tick(clock,s.generation,self.policy:allowed("grab",s,now),function(session,strike)
            -- Native-issued IDs and the actual current server clock only.
            -- Recheck after inspection; never backdate or anticipate a press.
            local at=bridge:serverNow()
            if not at or at<p.t0 or at>=p.ends-.002
                or math.abs(M.grab.triangle(at,p.t0,p.speed,p.from)-p.target)>p.half*.98 then return false end
            local sent=bridge:fire("FeralGrabV2","press",session,strike,at)
            if sent then bridge:markGrabPress(session,strike,now) end
            return sent
        end)
    end
    function h:requestFlight()
        local now = bridge.clock()
        if not self.active or self.closed or not self.registry.byId.flight.requested or now < (self.nextFlight or 0) then return false end
        local s = bridge:snapshot(now,true)
        s.grab = self.grab.active
        local c = bridge:config("FlightConfig")
        local ok,canFly = pcall(function() return c.canFly(s.char) end)
        if not ok or canFly ~= true or s.flying or not s.surface or s.underwater
            or not self.policy:allowed("flight",s,now) then return false end
        if type(c.WATER) ~= "table" or type(c.WATER.NO_TAKEOFF) ~= "boolean" then return false end
        self.recovery:release("surface takeoff input",now)
        local applied = self.features.leases:apply("surface",{
            {target = c.WATER,key = "NO_TAKEOFF",value = false,kind = "boolean"} })
        if not applied then return false end
        if not bridge:setAttribute(s.char,"FeralFlyRequest",now) then self:clearFlight(); return false end
        self.surfaceUntil,self.nextFlight = now+1.15,now+.75
        self.ledger:event("surface_takeoff_requested",now)
        return true
    end
    function h:idle()
        local now = bridge.clock()
        if self.closed or not self.active or not self.registry.byId.robloxAFK.requested
            or bridge.UserInputService:GetFocusedTextBox() then return end
        self.syntheticUntil,self.nextIdle = now+.25,now+75
        local ok = bridge:pulseIdle()
        self.idleUnavailable = not ok
        self.registry:ack("robloxAFK",ok,ok and "ARMED" or "UNAVAILABLE",
            ok and "idle input sent; retention unverified" or "virtual input unavailable")
        self.ledger:event("idle_input_attempt",now,{callSucceeded = ok})
    end
    function h:ackLocal(s)
        local r = self.registry
        local zoom=r.byId.zoom
        local zoomApplied=self.zoom:set(self.active and zoom.requested)
        r:ack("zoom",zoomApplied,not zoom.requested and "OFF" or zoomApplied and "CLIENT" or "UNAVAILABLE",self.zoom.reason)
        for _,id in ipairs({"combat","colours","finder","menu"}) do
            r:ack(id,true,id == "combat" and "ARMED" or "CLIENT",r.byId[id].detail)
        end
        for _,id in ipairs({"esp","tags","biteHelper"}) do
            local f = r.byId[id]
            r:ack(id,f.requested,f.requested and "CLIENT" or "OFF",f.detail)
        end
        for _,id in ipairs({"robloxAFK","survivalAFK","minigame","escape","flight"}) do
            local f = r.byId[id]
            if not f.requested then r:ack(id,false,"OFF",f.detail)
            elseif id == "minigame" then
                local remote = bridge:hasRemote("FeralGrabV2")
                local state = remote and (self.grab.active and not self.grabInput.lease and "PARTIAL" or "ARMED") or "WAITING"
                r:ack(id,remote,state,
                    self.grab.active and (self.grab.status .. " · " .. self.grabInput.status) or self.grab.status)
            elseif id == "escape" then
                r:ack(id,bridge:hasRemote("FeralLunge"),"ARMED",self.escapeStatus or "watching native capture")
            elseif id == "flight" then
                local c = bridge:config("FlightConfig")
                local ok,eligible = pcall(function() return s.alive and c.canFly(s.char) end)
                r:ack(id,ok and eligible == true,ok and eligible and "ARMED" or "WAITING",
                    ok and eligible and (self.flightStatus or (s.underwater and "underwater; takeoff blocked" or "surface assistance armed"))
                        or "waiting for flight-eligible animal")
            elseif id == "survivalAFK" then
                r:ack(id,true,"ARMED",self.walk and "safe walk active; credit unverified" or self.walkStatus or "waiting for safe idle window")
            else r:ack(id,not self.idleUnavailable,self.idleUnavailable and "UNAVAILABLE" or "ARMED",
                self.idleUnavailable and "virtual input unavailable" or "best-effort idle input; retention unverified") end
        end
        if self.settingsAvailable then r:ack("settings",true,"CLIENT","saved intent reconciled; " .. self.settingsOrigin) end
        local recovery = r.byId.recovery
        if recovery.requested then
            recovery.reason = self.recovery:summary()
            recovery.observed = self.recovery.nativeEchoObserved and "owned native pose echo observed locally" or "unknown"
            r.byId.effects.reason = self.recovery:effectsSummary()
            r.byId.effects.observed = self.recovery.observations
        end
        r.byId.minigame.observed = {
            perfect = self.grab.grades.perfect,good = self.grab.grades.good,miss = self.grab.grades.miss,
            source = "matching native res replies only",
        }
        if r.byId.minigame.requested and self.grab.active then
            r.byId.minigame.reason=string.format("P %d · G %d · M %d · %d presses · native grades only",
                self.grab.grades.perfect,self.grab.grades.good,self.grab.grades.miss,self.grab.presses)
        end
        if r.byId.stamina.requested and r.byId.stamina.applied then
            local item=self.ledger.staminaObservation
            r.byId.stamina.reason=(s.locomotion or "Animal").." client profile"
                ..(item and item.seconds>=1 and string.format(" · observed %+.2f/s",item.rate) or " · watching stamina")
            r.byId.stamina.observed=item or "unmeasured"
        end
        r.byId.flight.observed = s.flying and "native local flight flag" or "unknown"
        r.byId.climb.observed = s.climbing and "native local climb flag" or "unknown"
        r.byId.survivalAFK.observed = (self.ledger.counts.survival_value_advanced or 0) > 0
            and "survival value advanced; cause unverified" or "unknown"
    end
    function h:stepCombat(s,now)
        for _,tx in ipairs(self.transactions) do
            if not tx.classified and tx.generation == s.generation then
                if not tx.nativeAt and now-tx.intent > .45 and not self.combatInput.pending then
                    tx.classified = true
                    self.combatStatus = tx.lock and "No native bite marker · recent Rest lock possible" or "No native bite marker observed"
                    self.ledger:event("no_native_bite_marker",now,{recentRest = tx.lock == true})
                elseif tx.nativeAt and not tx.sampled and now >= tx.claimDue then
                    tx.sampled = true
                    local target = self.guide and self.guide.target
                    if target then
                        local before=tx.hpBefore and tx.hpBefore[target.char]
                        tx.target,tx.hp,tx.maxHP = target,before and before.hp,before and before.maxHP
                        tx.extendedOnly = self.guide.extended and self.guide.extended.valid
                            and not (self.guide.baseline and self.guide.baseline.valid)
                    end
                    self.ledger:event("client_candidate_sample",now,{found = target ~= nil,claimObserved = false})
                elseif tx.nativeAt and tx.sampled and now >= tx.claimDue+.8 then
                    tx.classified = true
                    local target = tx.target
                    local char=tx.nativeTarget or target and target.char
                    local ok,hum=pcall(function()return char and char:FindFirstChildOfClass("Humanoid")end)
                    local before=char and tx.hpBefore and tx.hpBefore[char]
                    local drop=ok and hum and hum.Parent and before and hum.MaxHealth==before.maxHP and hum.Health<before.hp-.05
                    local damage=tx.feedback and tx.feedback.dmg
                    self.combatStatus = tx.feedback and tx.feedback.safe==true and "Game reply: target protected"
                        or Core.finite(damage) and damage>0 and (string.format("Game reply reports %.1f damage",damage)
                            ..(drop and " · HP decline correlated" or " · HP change unconfirmed"))
                        or drop and tx.feedback and "Native hit reply + target HP decline · attribution unverified"
                        or drop and "Target HP fell after native marker · attribution unverified"
                        or "Native marker observed · no matching HP decline observed"
                    self.ledger:event(drop and "target_hp_decline_correlated" or "no_correlated_hp_decline",now,
                        {extendedOnly = tx.extendedOnly == true,nativeReply=tx.feedback~=nil,damageAcceptance = "unverified"})
                    tx.hpBefore=nil
                end
            end
        end
    end
    function h:stepClimb(s,now)
        local q = self.climbQueue
        if not q then return end
        if not self.registry.byId.climb.requested or q.generation ~= s.generation or now > q.expires then self.climbQueue = nil; return end
        if s.climbing then
            self.ledger:event("native_climb_mounted",now,{afterRequest = q.attempts > 0})
            self.climbQueue = nil; return
        end
        if not self.policy:allowed("climb",s,now) then self.climbQueue = nil; return end
        if now < q.earliest or not s.climbCan then return end
        if q.attempts >= 2 then self.climbQueue = nil; return end
        self.recovery:release("buffered climb",now)
        if bridge:setAttribute(bridge.player,"FeralClimbTap",now) then
            q.attempts += 1; q.earliest = now+.7
            self.ledger:event("native_climb_tap",now,{attempt = q.attempts})
        else self.climbQueue = nil end
    end
    function h:stepAFK(s,now)
        if self.registry.byId.robloxAFK.requested and now >= self.nextIdle and now-self.policy.lastPhysical >= 65 then self:idle() end
        if not self.registry.byId.survivalAFK.requested then self:stopWalk("disabled"); return end
        if self.walk then
            s.nearbyDanger = bridge:nearbyDanger(s)
            local allowed,why = self.policy:allowed("afk",s,now)
            if not allowed or now >= self.walk.untilAt or self.walk.snapshot.char ~= s.char then self:stopWalk(why or "walk timeout"); return end
            if (s.root.Position-self.walk.goal).Magnitude < 1.3 then
                self.ledger:event("afk_displacement_observed",now)
                self:stopWalk("goal reached")
            elseif not bridge:routeSafe(s,self.walk.goal) then
                self:stopWalk("ground route changed")
            end
            return
        end
        if now < self.nextWalk then return end
        self.nextWalk = now+90
        s.nearbyDanger = bridge:nearbyDanger(s)
        local allowed,why = self.policy:allowed("afk",s,now)
        self.walkStatus = why
        if not allowed then return end
        local goal = bridge:safeStep(s,self.anchorChar == s.char and self.anchor or nil)
        if not goal then self.walkStatus = "no safe ground step"; return end
        self.recovery:release("safe idle walk",now)
        if bridge:walk(s,goal) then
            if self.anchorChar ~= s.char then self.anchor,self.anchorChar = s.root.Position,s.char end
            self.walk = { snapshot = s,goal = goal,untilAt = now+8 }
            self.ledger:event("afk_walk_requested",now)
        end
    end
    function h:stepFlight(s,now)
        if self.surfaceUntil and (now >= self.surfaceUntil or s.underwater or s.flying
            or s.captured or s.grab or s.chat or s.gameMenu or s.attackHeld) then
            self.features.leases:release("surface")
            self.surfaceUntil = nil
        end
        if self.drop then
            if not s.flying then self.ledger:event("underwater_flight_exit_observed",now) end
            if not s.flying or self.drop.char ~= s.char or now >= self.drop.untilAt then self:clearFlight() end
        elseif self.registry.byId.flight.requested and s.flying and s.underwater and not s.grab and not s.ability and not s.captured then
            local before = bridge:attribute(s.char,"FeralFlyDrop")
            if bridge:setAttribute(s.char,"FeralFlyDrop",true) then
                self.drop = {char = s.char,before = before,untilAt = now+2}
                self.ledger:event("native_underwater_flight_exit_requested",now)
            end
        end
    end
    function h:stepEscape(s,now)
        if not self.registry.byId.escape.requested or now < self.nextEscape then return end
        self.nextEscape = now+.12
        local allowed = self.policy:allowed("escape",s,now)
        if not allowed then return end
        local action,why,interval = bridge:escapeAction(s)
        self.escapeStatus = why
        if action then
            self.nextEscape = now+interval
            local sent = bridge:fire("FeralLunge",action)
            self.ledger:event("native_escape_requested",now,{action = action,sent = sent})
        end
    end
    function h:tick(dt)
        if not self.active or self.closed then return end
        local now = bridge.clock()
        if self.territory then self.territory:tick(now) end
        if Core.finite(dt) and dt>0 then
            self.frameInterval=(self.frameInterval or dt)*.85+math.min(dt,.25)*.15
        end
        local slow = now >= self.nextSlow
        local critical=self.registry.byId.minigame.requested and self.grab.active and self.grab.pending~=nil
        self.timingCritical,bridge.deferNativeDiscovery=critical,critical
        local s = bridge:snapshot(now,not critical and slow and self.registry.byId.flight.requested)
        self.snapshot = s
        self.grab.enabled = self.registry.byId.minigame.requested
        local clock = s.serverNow
        if clock then
            local cfg = self.grab.enabled and bridge:config("GrabV2Config")
            local native = self.grab.enabled and self.grabInput:controller(now)
            local nativeState,nativeKnown
            if native and (self.grab.active or now >= (self.nextGrabPoll or 0)) then
                nativeState,nativeKnown=native.state();self.nextGrabPoll=now+.25
            end
            if native and s.alive and (nativeState or nativeKnown==true) then
                self.grab:syncNative(nativeState,clock,s.generation,cfg and cfg.PERFECT or .32,
                    cfg and cfg.PASSES or 2.5,now)
            end
            critical=critical or self.grab.enabled and self.grab.active and self.grab.pending~=nil
            self.timingCritical,bridge.deferNativeDiscovery=critical,critical
            if not s.alive and self.grab.active then self.grab:reset("animal unavailable") end
            s.grab,s.afkWalking = self.grab.active,self.walk ~= nil
            self.grabInput:update(self.grab,now,native,nativeState)
            self:pumpGrab(s,false)
            self:updateGrabWake()
        else self.grab.pending = nil; s.grab,s.afkWalking = self.grab.active,self.walk ~= nil end
        if not critical and now >= self.nextBind then self.nextBind = now+1; bridge:bindNative(self) end
        local care=self.territory and self.territory.agent.enabled and self.territory.agent.goal
        self.feeding:tick(s,now,care and (care.kind=="EAT" or care.kind=="DRINK"))
        self:stepFlightHandoff(s,now)
        self.rescue:tick(s,now)
        self.activity=self.policy:activity(s,now)
        self.combatInput:tick(s,now)
        if not critical then self.features:reconcile(s,now) end
        self.recovery.enabled = self.registry.byId.recovery.requested or self.territoryRecoveryOwner~=nil
        self.recovery:tick(s,now)
        self:stepClimb(s,now)
        self:stepEscape(s,now)
        if not critical then self:stepCombat(s,now) end
        self.biteReadiness=bridge:biteReadiness(s,now,self.policy)
        if not critical and now >= self.nextScan then
            self.nextScan = now+((s.combat==true or s.attackHeld) and .12
                or math.clamp((self.frameInterval or .02)*6,.12,.3))
            local candidates = bridge:candidates(s,self.settings.range)
            if self.features.originalCombat and self.features.leases:valid("reach") then
                self.guide = bridge:select(s,self.features.originalCombat,self.features.combat,candidates)
            else self.guide = nil end
            self.guideAt=now
            self.ui:syncTracked(bridge.tracked)
        end
        if slow and not critical then
            self.nextSlow = now+.25
            self:stepFlight(s,now)
            self:stepAFK(s,now)
            self:ackLocal(s)
        end
        if now >= self.nextSample and s.alive then
            self.nextSample = now+.25
            local mode = self.policy.manualRest and "MANUAL" or self.recovery.owned and "NATIVE_SIGNAL" or "NO_SIGNAL"
            self.ledger:sample(s,mode)
            if Core.finite(s.survival) and Core.finite(self.lastSurvival) and s.survival > self.lastSurvival then
                self.ledger:event("survival_value_advanced",now,{cause = "unverified"})
            end
            self.lastSurvival = s.survival
        end
    end
    function h:maskPose()
        local now = bridge.clock()
        self.recovery:guardPose(now)
        if self.recovery.owned then
            local char = bridge.player.Character
            self.recovery:echo({char = char,rest = bridge:attribute(char,"WolfRest") == true},now)
        end
    end
    function h:render(dt)
        if self.grab.enabled and self.grab.pending then
            self:pumpGrab(bridge:grabSnapshot(bridge.clock()),true)
            self:updateGrabWake()
        end
        self:maskPose()
        if self.guide and self.snapshot and self.features.leases:valid("reach") then
            bridge:refreshGuide(self.snapshot,self.features.originalCombat,self.features.combat,self.guide)
        end
        self.ui:render(dt,bridge.clock())
        self.recovery:afterAnimationFrame(bridge.clock())
    end
    function h:fault(errorValue)
        self.notice = "Controller paused · reload or use CLEAN v14"
        self.lastError = tostring(errorValue):sub(1,180)
        self.ledger:event("runtime_fault",bridge.clock())
        self:close()
        warn("[FERAL Renaissance] " .. self.lastError)
    end
    function h:stage()
        self.ui = M.ui.mount(self,bridge,self.scope)
        bridge:attach(self,self.scope)
        bridge:bindNative(self)
        bridge.bindCharacter(bridge.player.Character)
        if self.registry.byId.minigame.requested then bridge:nativeGrabController(bridge.clock()) end
        bridge:nativeWolfActions(bridge.clock())
        self.ready = true
        return self
    end
    function h:activate()
        assert(self.ready and not self.closed,"candidate not staged")
        self.ui:activate()
        self.active = true
        self.zoom:set(self.registry.byId.zoom.requested)
        if M.amber_runtime then self.territory=M.amber_runtime.start(M,self) end
        self.registry:ack("settings",true,"CLIENT","loaded settings; full reconciliation pending")
        return self
    end
    function h:close()
        if self.closed then return end
        self.active = false
        self.closed = true
        self.cleanupErrors = {}
        for _,cleanup in ipairs({
            function() if self.territory then self.territory.close() end end,
            function() self.zoom:close() end,
            function() self:cancelGrabWake() end,
            function() self.recovery:close(bridge.clock()) end,
            function() self.grabInput:close() end,
            function() self.feeding:close(bridge.clock()) end,
            function() self.combatInput:cancel();self.rescue:cancel() end,
            function() bridge:closeNativeScan() end,
            function() self:stopWalk("shutdown") end,
            function() self:clearFlight() end,
            function() self.features:close() end,
        }) do
            local ok,why = pcall(cleanup)
            if not ok then table.insert(self.cleanupErrors,tostring(why)) end
        end
        self.scope:close()
        if bridge.env.FERAL_RENAISSANCE_ACTIVE == self then bridge.env.FERAL_RENAISSANCE_ACTIVE = nil end
        if bridge.env.FERAL_NOVA_PRIME_ACTIVE == self.marker then bridge.env.FERAL_NOVA_PRIME_ACTIVE = nil end
    end
    return h
end
return Controller
]============]
sources["amber_ledger"] = [============[
-- Bounded run accounting. Requests, world observations and attribution differ.
local Ledger={}
local function finite(n)return type(n)=="number" and n==n and math.abs(n)<1e12 end
function Ledger.new()
    local l={serial=0}
    function l:start(now)
        self.serial+=1;self.run=self.serial;self.started=now;self.at=now
        self.wall,self.active,self.paused,self.unknown=0,0,0,0
        self.phases,self.failures,self.outcomes,self.costs={},{},{},{}
        self.inflow,self.outflow,self.net=0,0,0;self.balance=nil;self.character=nil
        self.assistance=0;self.wasManual=false;self.previous=nil;self.gaits={};self.modes={}
    end
    function l:sample(now,phase,paused,manual,goal,state,nav)
        if not self.run then self:start(now) end
        local dt=math.max(0,now-(self.at or now));self.at=now;self.wall+=dt
        local known=math.min(dt,2);local gap=dt-known;self.unknown+=gap
        local p=self.previous and {phase=phase or "WAIT",paused=paused==true,goal=goal}
        if p then
            if p.paused then self.paused+=known else self.active+=known end
            self.phases[p.phase]=(self.phases[p.phase] or 0)+known
            if not p.paused then
                local mode=(not state or not state.alive) and "unavailable" or state.underwater and "depth"
                    or state.flying and "flight" or state.climbing and "climb" or state.swimming and "surface_water" or "ground"
                self.modes[mode]=(self.modes[mode] or 0)+known
                local observed=nav and nav.gaits and nav.gaits.observed
                if observed~="WALK" and observed~="TROT" and observed~="SPRINT" and observed~="BURST" then observed="UNKNOWN" end
                self.gaits[observed]=(self.gaits[observed] or 0)+known
            end
            local g=p.goal
            if g then
                g.timing=g.timing or {active=0,paused=0,unknown=0,phases={}}
                local t=g.timing;t.unknown+=gap
                if p.paused then t.paused+=known else t.active+=known end
                t.phases[p.phase]=(t.phases[p.phase] or 0)+known
            end
        else self.unknown+=known end
        if manual and not self.wasManual then self.assistance+=1 end
        self.wasManual=manual==true
        self.previous={phase=phase or "WAIT",paused=paused==true,goal=goal}
    end
    function l:currency(value,character)
        if not finite(value) then self.balance=nil;return end
        if self.character~=character then self.balance=nil;self.character=character end
        if self.balance then
            local delta=value-self.balance;self.net+=delta
            if delta>0 then self.inflow+=delta else self.outflow-=delta end
        end
        self.balance=value
    end
    function l:count(kind,reason)
        local t=kind=="failure" and self.failures or self.outcomes
        local key=tostring(reason or kind):sub(1,100)
        if not t[key] then
            local n=0;for _ in pairs(t) do n+=1 end
            if n>=48 then key="other" end
        end
        t[key]=(t[key] or 0)+1
    end
    function l:cost(name,seconds)
        local c=self.costs[name] or {calls=0,total=0,max=0,samples={}}
        self.costs[name]=c;c.calls+=1;c.total+=seconds;c.max=math.max(c.max,seconds)
        table.insert(c.samples,seconds);if #c.samples>128 then table.remove(c.samples,1) end
    end
    function l:summary()
        local costs={}
        for k,c in pairs(self.costs or {}) do
            local s=table.clone(c.samples);table.sort(s)
            costs[k]={calls=c.calls,total=c.total,max=c.max,p95=s[math.max(1,math.ceil(#s*.95))],p99=s[math.max(1,math.ceil(#s*.99))]}
        end
        return {run=self.run,wall=self.wall,active=self.active,paused=self.paused,unobserved=self.unknown,
            phases=self.phases,observedGaitSeconds=self.gaits,modeSeconds=self.modes,
            manualInterventions=self.assistance,failures=self.failures,outcomes=self.outcomes,costs=costs,
            amber={inflow=self.inflow,outflow=self.outflow,net=self.net,
                inflowPerWallHour=self.wall and self.wall>0 and self.inflow*3600/self.wall or nil,
                netPerWallHour=self.wall and self.wall>0 and self.net*3600/self.wall or nil,attribution="unattributed observed balance changes"}}
    end
    return l
end
return Ledger
]============]
sources["amber_model"] = [============[
-- Small, generation-scoped travel observations and checked passage graph.
local Model={}
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)end
local function key(p)return math.floor(p.x/48)..":"..math.floor(p.z/48)end
local function copy(p)return {x=p.x,y=p.y,z=p.z}end
function Model.new()
    local m={identity=nil,edges={},nodes={},order={},costs={},observations=0,failures=0}
    function m:reset(identity)
        if identity==self.identity then return end
        self.identity=identity;self.edges={};self.nodes={};self.order={};self.costs={}
    end
    function m:estimate(a,b,now,speed,purpose)
        local direct=distance(a,b)/math.max(6,speed or 24)
        local c=self.costs[key(a)..">"..key(b)..":"..tostring(purpose or "point")]
        if c and now-c.at<600 then
            return (c.access and c.seconds or math.max(direct,c.seconds)),c.samples>=2 and "observed" or "single observation"
        end
        return direct,"distance estimate"
    end
    function m:record(a,b,seconds,now,failed,purpose,access)
        if distance(a,b)<12 then return end
        local k=key(a)..">"..key(b)..":"..tostring(purpose or "point");local c=self.costs[k]
        local value=failed and math.max(seconds,45,distance(a,b)/10) or seconds
        if c then c.seconds=c.seconds*.4+value*.6;c.at=now;c.samples+=1;c.access=access==true
        else
            local count=0;local oldest,at=nil,math.huge
            for id,v in pairs(self.costs) do count+=1;if v.at<at then oldest,at=id,v.at end end
            if count>=192 then self.costs[oldest]=nil end
            self.costs[k]={seconds=value,at=now,samples=1,access=access==true}
        end
        if failed then self.failures+=1 else self.observations+=1 end
    end
    function m:addRoute(points,now)
        local previous
        for _,p in ipairs(points) do
            local k=key(p)
            if not self.nodes[k] then
                if #self.order>=160 then
                    local old=table.remove(self.order,1);self.nodes[old]=nil;self.edges[old]=nil
                    for _,e in pairs(self.edges) do e[old]=nil end
                end
                table.insert(self.order,k)
            end
            self.nodes[k]={point=copy(p),at=now};self.edges[k]=self.edges[k] or {}
            if previous and previous~=k and self.nodes[previous] and self.edges[previous] then
                self.edges[previous][k]={cost=distance(self.nodes[previous].point,p),at=now}
            end
            previous=k
        end
    end
    function m:path(a,b,now)
        local costs,parents,open={},{},{}
        for k,n in pairs(self.nodes) do
            local d=distance(a,n.point)
            if d<80 and now-n.at<180 then costs[k]=d;open[k]=true end
        end
        for _=1,160 do
            local current,best=nil,math.huge
            for k in pairs(open) do if costs[k]<best then current,best=k,costs[k] end end
            if not current then break end
            open[current]=nil
            local n=self.nodes[current]
            if n and distance(n.point,b)<90 then
                local result={copy(b)};local k=current;local seen={}
                while k and not seen[k] do
                    seen[k]=true;table.insert(result,1,copy(self.nodes[k].point));k=parents[k]
                end
                return result
            end
            for k,e in pairs(self.edges[current] or {}) do
                if self.nodes[k] and now-e.at<180 and (not costs[k] or best+e.cost<costs[k]) then
                    costs[k]=best+e.cost;parents[k]=current;open[k]=true
                end
            end
        end
        return nil
    end
    function m:summary()return {passages=#self.order,travelObservations=self.observations,routeFailures=self.failures}end
    return m
end
return Model
]============]
sources["amber_planner"] = [============[
-- Grizzly Amber v1: pure objective planner. Never writes territory/game state.
-- Hex geometry, pay, owner, hold and progress are replicated native observations.
local Planner = {}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e10 end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function dist(a,b)
    if not a or not b or not finite(a.x) or not finite(a.z) or not finite(b.x) or not finite(b.z) then
        return math.huge
    end
    local dx,dz=a.x-b.x,a.z-b.z
    return math.sqrt(dx*dx+dz*dz)
end
local function pathRisk(a,b,players,avoidRadius)
    for _,p in ipairs(players or {}) do
        if finite(p.x) and finite(p.z) then
            local vx,vz=b.x-a.x,b.z-a.z
            local denom=vx*vx+vz*vz
            local t=denom>.01 and clamp(((p.x-a.x)*vx+(p.z-a.z)*vz)/denom,0,1) or 0
            local qx,qz=a.x+vx*t,a.z+vz*t
            local offset=math.sqrt((qx-p.x)^2+(qz-p.z)^2)
            if offset<avoidRadius then return true,offset end
        end
    end
    return false,math.huge
end
Planner.distance=dist
Planner.pathRisk=pathRisk

-- kind is CLAIM or SCENT. Existing claims have a minimum guard against churn.
function Planner.objective(hex,state,from,options)
    options=options or {}
    if not hex or type(hex.key)~="string" or hex.neutral or state.pack==nil
        or not hex.center or not finite(hex.center.x) or not finite(hex.center.z) then return nil end
    if (options.exclude and options.exclude[hex.key])
        or (options.blockedUntil and (options.blockedUntil[hex.key] or 0)>(state.now or 0)) then return nil end
    if state.contested and state.contested[hex.key] then return nil end
    local owned=hex.owner==state.pack
    local hold=finite(hex.hold) and clamp(hex.hold,0,1) or nil
    local payKnown=finite(hex.pay)
    local pay=payKnown and clamp(hex.pay,1,20) or 1
    local kind,priority
    if owned then
        if hold==nil or hold>= (options.scentThreshold or .84) then return nil end
        kind="SCENT"
        priority=45+pay*8+(1-hold)*180
        if hold<.35 then priority+=125 end
        if finite(hex.fade) and finite(state.unixNow) then
            local seconds=hex.fade-state.unixNow
            if seconds<150 then priority+=math.max(0,150-seconds)*.32 end
        end
    else
        kind="CLAIM"
        priority=80+pay*23
        if hex.owner==nil then priority+=30 else priority-=15 end
        if hex.by==state.pack and finite(hex.prog) and hex.prog>0 then
            priority+=140+clamp(hex.prog,0,1)*100
        end
    end
    local d=dist(from,hex.center)
    if d==math.huge then return nil end
    local deny,nearest=pathRisk(from,hex.center,state.players,options.avoidRadius or 120)
    if deny and options.avoidPlayers==true then return nil end
    local recent=options.recent and options.recent[hex.key]
    local waiting=options.waitingSince and options.waitingSince[hex.key]
    if finite(waiting) then priority+=math.min(180,math.max(0,(state.now or 0)-waiting)/5) end
    if finite(recent) and (state.now or 0)-recent<120 then priority*=.65 end
    local travel,confidence=d/24,"distance estimate"
    local estimate=options.travelCost or state.travelCost
    if type(estimate)=="function" then
        local ok,t,c=pcall(estimate,from,hex.center,"HEX:"..hex.key)
        if ok and finite(t) and t>=0 then travel,confidence=t,c or "estimate" end
    end
    local service=kind=="SCENT" and (state.refillTime or 60)*(1-hold)
        or (state.claimTime or 20)*(1-(hex.by==state.pack and finite(hex.prog) and clamp(hex.prog,0,1) or 0))
    local deadline=finite(hex.deadlineSeconds) and math.max(0,hex.deadlineSeconds) or nil
    -- Fade is used only when its units plausibly match the supplied Unix clock.
    if not deadline and finite(hex.fade) and finite(state.unixNow) and math.abs(hex.fade-state.unixNow)<86400 then
        deadline=math.max(0,hex.fade-state.unixNow)
    end
    local slack=deadline and deadline-travel-service or nil
    if kind=="SCENT" and slack and slack<60 then priority+=math.max(0,60-slack)*6 end
    local routeCost=1+d/320
    local score=type(estimate)=="function" and priority/math.max(2,travel+service+2) or priority/(routeCost^.74)
    if not finite(score) then return nil end
    return {key=hex.key,kind=kind,score=score,base=priority,distance=d,
        pay=payKnown and pay or nil,hold=hold,center=hex.center,nearestPlayer=nearest,
        urgency=owned and (1-(hold or 0)) or 0,travelSeconds=travel,serviceSeconds=service,
        deadlineSeconds=deadline,slack=slack,confidence=confidence}
end

function Planner.plan(hexes,state,options)
    options=options or {}
    if type(hexes)~="table" or not state or not state.position then return {} end
    local route,from={},state.position
    local exclude={}
    for key,blocked in pairs(options.exclude or {}) do if blocked then exclude[key]=true end end
    local n=math.min(options.maxStops or 6,16)
    for step=1,n do
        local ranked={}
        local opt={}
        for k,v in pairs(options) do opt[k]=v end
        opt.exclude=exclude
        for _,hex in ipairs(hexes) do
            local item=Planner.objective(hex,state,from,opt)
            if item then table.insert(ranked,item) end
        end
        if #ranked==0 then break end
        table.sort(ranked,function(a,b) if a.score~=b.score then return a.score>b.score end return a.key<b.key end)
        -- One-stop lookahead rewards efficient clusters rather than global backtracking.
        local best=nil
        for j=1,math.min(7,#ranked) do
            local candidate=ranked[j]
            local forward=0
            if step<n then
                local lookOpt={}
                for k,v in pairs(opt) do lookOpt[k]=v end
                local skip={}
                for k,v in pairs(exclude) do skip[k]=v end
                skip[candidate.key]=true
                lookOpt.exclude=skip
                for _,hex in ipairs(hexes) do
                    local other=Planner.objective(hex,state,candidate.center,lookOpt)
                    if other and other.score>forward then forward=other.score end
                end
            end
            candidate.trajectory=candidate.score+forward*.16
            if not best or candidate.trajectory>best.trajectory
                or candidate.trajectory==best.trajectory and candidate.key<best.key then best=candidate end
        end
        table.insert(route,best)
        exclude[best.key]=true
        from=best.center
    end
    if options.currentKey and options.currentKey~="" and #route>0 and route[1].key~=options.currentKey then
        -- Preserve an active objective unless it is done, dangerous or strongly outclassed.
        local current
        for _,hex in ipairs(hexes) do
            if hex.key==options.currentKey then
                current=Planner.objective(hex,state,state.position,options);break
            end
        end
        if current and current.score>=route[1].score*.73 and
            (state.now or 0)-(options.currentStarted or 0)<(options.maxCommitSeconds or 75) then
            for i=#route,1,-1 do if route[i].key==current.key then table.remove(route,i) end end
            table.insert(route,1,current)
            while #route>n do table.remove(route) end
        end
    end
    return route
end

-- Native regionCell is a one-based row-major ID. Sweep alternating rows to
-- finish complete areas without crossing repeatedly between opposite corners.
function Planner.regionOrder(grid)
    local order={}
    for row=0,grid-1 do
        for step=0,grid-1 do
            local col=row%2==0 and step or grid-1-step
            table.insert(order,row*grid+col+1)
        end
    end
    return order
end
local function localTour(hexes,state,options)
    local remaining={}
    for _,hex in ipairs(hexes) do
        local item=Planner.objective(hex,state,state.position,options)
        if item then item.region=hex.region;item.hex=hex;table.insert(remaining,item) end
    end
    local route,from={},state.position
    local elapsed=0
    while #remaining>0 and #route<math.min(options.maxStops or 6,16) do
        local best,index,value=nil,nil,-math.huge
        for i,item in ipairs(remaining) do
            local refreshed=Planner.objective(item.hex,state,from,options)
            local t=refreshed.travelSeconds+refreshed.serviceSeconds+2
            local rank=refreshed.base/math.max(2,t)/(1+(refreshed.travelSeconds/5)^2)
            if refreshed.slack and refreshed.slack-elapsed<45 then
                rank+=1000/math.max(1,refreshed.slack-elapsed+20)
            end
            if rank>value or rank==value and item.key<(best and best.key or "~") then
                best,index,value=refreshed,i,rank
                best.region=item.region
            end
        end
        elapsed+=best.travelSeconds+best.serviceSeconds
        table.insert(route,best);table.remove(remaining,index);from=best.center
    end
    return route
end
function Planner.strategy(hexes,state,options)
    options=options or {}
    local grid=state.regionGrid
    if not finite(grid) or grid<1 or grid>8 or grid%1~=0 then
        return Planner.plan(hexes,state,options),{phase="GENERAL",cursor=options.regionCursor or 1}
    end
    local groups={};local urgent={};local anyRegion=false
    for _,hex in ipairs(hexes) do
        if hex.region and not hex.neutral then
            anyRegion=true
            groups[hex.region]=groups[hex.region] or {total=0,owned=0,hexes={}}
            local group=groups[hex.region];group.total+=1
            if hex.owner==state.pack then group.owned+=1 end
            table.insert(group.hexes,hex)
        end
        local item=Planner.objective(hex,state,state.position,options)
        if item and item.kind=="SCENT" and item.hold and (item.hold<.28 or item.slack and item.slack<45) then table.insert(urgent,hex) end
    end
    if not anyRegion then return Planner.plan(hexes,state,options),{phase="GENERAL",cursor=1} end
    local order=Planner.regionOrder(grid)
    if #urgent>0 then return localTour(urgent,state,options),{phase="URGENT_SCENT",cursor=options.regionCursor or 1} end
    local oldest,agedRegion=300,nil
    for region,group in pairs(groups) do
        for _,hex in ipairs(group.hexes) do
            local since=options.waitingSince and options.waitingSince[hex.key]
            if finite(since) and (state.now or 0)-since>oldest and Planner.objective(hex,state,state.position,options) then
                oldest,agedRegion=(state.now or 0)-since,region
            end
        end
    end
    if agedRegion then
        local index=table.find(order,agedRegion) or 1
        return localTour(groups[agedRegion].hexes,state,options),{phase="FAIRNESS_SWEEP",cursor=index,region=agedRegion,
            area="Revisiting waiting area",order=order}
    end
    local cursor=math.clamp(options.regionCursor or 1,1,#order)
    if not options.regionCursor then
        local closest=math.huge
        for index,region in ipairs(order) do
            local group=groups[region]
            if group then
                for _,hex in ipairs(group.hexes) do
                    local item=Planner.objective(hex,state,state.position,options)
                    if item and item.travelSeconds<closest then cursor,closest=index,item.travelSeconds end
                end
            end
        end
    end
    local direction=options.regionDirection or 1
    if not options.regionCursor then
        local best=math.huge
        for _,candidateDirection in ipairs({1,-1}) do
            for step=1,#order-1 do
                local index=(cursor+step*candidateDirection-1)%#order+1
                local group=groups[order[index]];local cost=math.huge
                for _,hex in ipairs(group and group.hexes or {}) do
                    local item=Planner.objective(hex,state,state.position,options)
                    if item then cost=math.min(cost,item.travelSeconds) end
                end
                if cost<math.huge then
                    if cost<best then direction,best=candidateDirection,cost end
                    break
                end
            end
        end
    end
    -- Claims first, then maintenance; blocked areas stay eligible for the next
    -- pass instead of being incorrectly counted as completed.
    for _,claimsOnly in ipairs({true,false}) do
        for step=0,#order-1 do
            local index=(cursor+step*direction-1)%#order+1
            local region=order[index];local group=groups[region]
            if group and (not claimsOnly or group.owned<group.total) then
                local pool={}
                for _,hex in ipairs(group.hexes) do
                    if not claimsOnly or hex.owner~=state.pack then table.insert(pool,hex) end
                end
                local route=localTour(pool,state,options)
                if #route>0 then
                    local row,col=math.floor((region-1)/grid),(region-1)%grid
                    local vertical=grid==3 and ({"Top","Middle","Bottom"})[row+1] or ("Row "..(row+1))
                    local horizontal=grid==3 and ({"left","centre","right"})[col+1] or ("column "..(col+1))
                    return route,{phase=claimsOnly and "AREA_SWEEP" or "AREA_MAINTENANCE",cursor=index,
                        region=region,direction=direction,area=vertical.." "..horizontal,owned=group.owned,total=group.total,
                        bonus=state.regionBonus,order=order}
                end
            end
        end
    end
    return {},{phase="MAINTAINED",cursor=cursor,direction=direction,order=order}
end

function Planner.decide(state,options)
    options=options or {}
    if not state or not finite(state.healthFraction) or state.needsKnown==false then
        return {kind="WAIT",reason="Waiting for valid native health and needs"}
    end
    local hm=finite(state.hungerMax) and state.hungerMax>0 and state.hungerMax or 100
    local tm=finite(state.thirstMax) and state.thirstMax>0 and state.thirstMax or 100
    local h=finite(state.hunger) and state.hunger/hm or nil
    local t=finite(state.thirst) and state.thirst/tm or nil
    local critical=t and t<.19 and "DRINK" or h and h<.19 and "EAT"
    if state.healthFraction<.25 then
        if critical and (state.feedCan==(critical=="DRINK" and "drink" or "eat") or state.recoveryStalled
            or critical=="DRINK" and t<.08 or critical=="EAT" and h<.08) then
            return {kind=critical,critical=true,reason="Immediate native care before critical recovery"}
        end
        return {kind="RECOVER",critical=true,reason="Critical health"}
    end
    if critical then return {kind=critical,critical=true,reason="Critical survival need"} end
    if state.healthFraction<(options.minimumHP or .46) then return {kind="RECOVER",reason="Low health"} end
    local drinkBudget=math.max(180,(state.drinkETA or 0)+45)
    local foodBudget=math.max(240,(state.foodETA or 0)+60)
    if t and t<.8 and finite(state.thirstReserve) and state.thirstReserve<drinkBudget then
        return {kind="DRINK",reason="Water reserve shorter than care margin"}
    end
    if h and h<.8 and finite(state.hungerReserve) and state.hungerReserve<foodBudget then
        return {kind="EAT",reason="Food reserve shorter than acquisition margin"}
    end
    if t and t<(options.thirstTrigger or 44)/100 then return {kind="DRINK",reason="Thirst care"} end
    if h and h<(options.hungerTrigger or 42)/100 then return {kind="EAT",reason="Hunger care"} end
    return {kind="TERRITORY",reason="Survival reserve available"}
end
function Planner.need(state,options)return Planner.decide(state,options).kind end
function Planner.capacity(hexes,state,options)
    local jobs={};local unknown=0
    for _,hex in ipairs(hexes) do
        if hex.owner==state.pack and not hex.neutral then
            local item=Planner.objective(hex,state,state.position,options)
            if item and item.deadlineSeconds then table.insert(jobs,item) else unknown+=1 end
        end
    end
    table.sort(jobs,function(a,b)return a.deadlineSeconds<b.deadlineSeconds end)
    local elapsed,misses=0,0;local from=state.position
    for _,item in ipairs(jobs) do
        local travel=item.travelSeconds
        if type(state.travelCost)=="function" then travel=state.travelCost(from,item.center,"HEX:"..item.key) end
        elapsed+=travel+item.serviceSeconds
        if elapsed>item.deadlineSeconds then misses+=1 end
        from=item.center
    end
    return {knownDeadlines=#jobs,unknown=unknown,estimatedSeconds=elapsed,predictedLate=misses,
        state=#jobs==0 and "UNKNOWN" or misses>0 and "DEADLINE_PRESSURE" or "DUE_WORK_FEASIBLE",
        scope="estimated currently due maintenance; excludes unknown/future workload"}
end
return Planner
]============]
sources["amber_gait"] = [============[
-- FERAL Amber: pure navigation/locomotion decisions, no side effects.
-- Distances in horizontal studs; angles in degrees; reserves protect stamina.
local Gait={}
local function finite(x)
    return type(x)=="number" and x==x and math.abs(x)<1e9
end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
function Gait.distance(a,b)
    if not a or not b or not finite(a.x) or not finite(a.z)
        or not finite(b.x) or not finite(b.z) then return math.huge end
    local dx,dz=a.x-b.x,a.z-b.z
    return math.sqrt(dx*dx+dz*dz)
end
function Gait.turn(previous,position,target)
    if not previous or not position or not target then return 0 end
    local ax,az=position.x-previous.x,position.z-previous.z
    local bx,bz=target.x-position.x,target.z-position.z
    local la=math.sqrt(ax*ax+az*az)
    local lb=math.sqrt(bx*bx+bz*bz)
    if la<1 or lb<1 then return 0 end
    local dot=clamp((ax*bx+az*bz)/(la*lb),-1,1)
    return math.deg(math.acos(dot))
end
-- Trot and sprint are valid across land animals; burst only when an actual
-- game input is available and enough stamina remains. Never force WalkSpeed.
function Gait.select(distance,turn,stamina,options)
    options=options or {}
    if not finite(distance) or distance<=0 then return "STOP" end
    if options.ability or options.injured then return "TROT" end
    if options.combat and not options.hunting then return "TROT" end
    if options.swimming then
        if options.swimSprint and distance>45 and (not finite(stamina) or stamina>.25) then return "SPRINT" end
        return "TROT"
    end
    if options.following and type(options.gaitSpeeds)=="table" then
        for _,mode in ipairs({"WALK","TROT","SPRINT"}) do
            local speed=options.gaitSpeeds[mode] or options.gaitSpeeds[string.lower(mode)]
            if finite(speed) and speed>=(options.preySpeed or 0)*1.08 then return mode end
        end
    end
    local reserve=finite(stamina) and stamina or nil
    local angle=finite(turn) and turn or 0
    if options.allowBurst~=false and (reserve and reserve>=.56 or not reserve and options.nativeBurstAvailable==true)
        and distance>=80 and angle<=22 and not options.crowded
        and options.burstReady~=false then return "BURST" end
    if options.hunting and (options.preySpeed or 0)>6 and distance>6
        and (not reserve or reserve>=.22) and angle<65 then return "SPRINT" end
    if distance<10 then return "WALK" end
    if distance<24 then return "TROT" end
    if distance>=48 and angle<=72 and not options.crowded
        and (not reserve or reserve>=.22) then return "SPRINT" end
    return "TROT"
end

-- Stateful requests with observed HUD acknowledgements. A successful key API
-- call is only an input request. Burst and trot are native Begin toggles.
function Gait.controller(io)
    local g={requested="STOP",observed="UNKNOWN",changedAt=-100,
        attempts={},blocked={},pending=nil,lastSuccess=nil,reason="Idle",
        burstOwned=false,trotOwned=false,requests=0,confirmations=0}
    function g:step(wanted,s,now)
        s=s or {}
        local observed=s.hudBurst==true and "BURST"
            or s.hudSprint==true and "SPRINT"
            or s.hudTrot==true and "TROT"
            or s.hudSprint==false and s.hudTrot==false and s.hudBurst==false and "WALK"
            or "UNKNOWN"
        self.observed=observed
        if self.pending then
            local p=self.pending
            local confirmed=(p.mode==observed)
                or p.mode=="BURST_OFF" and s.hudBurst==false
                or p.mode=="WALK" and s.hudTrot==false and s.hudSprint==false
            if confirmed then
                self.lastSuccess=now;self.confirmations+=1
                self.attempts[p.mode]=0;self.pending=nil
                self.reason="Native gait observed"
            elseif now-p.at>=1.25 then
                local count=self.attempts[p.mode] or 1
                if count>=2 then self.blocked[p.mode]=now+8 end
                self.pending=nil;self.reason="Gait request unconfirmed"
                if p.mode=="SPRINT" then io:hold("SHIFT",false) end
                if count==1 and type(io.retryInput)=="function" then
                    io:retryInput(p.mode=="SPRINT" and "SHIFT" or p.mode=="TROT" and "Z" or "X")
                end
            end
        end
        local emergency=wanted=="STOP" or wanted=="WALK" or s.ability or s.swimming or s.brake
        local boost=wanted=="BURST" and self.requested=="SPRINT" and observed=="SPRINT"
        if wanted~=self.requested and not emergency and not boost and now-self.changedAt<1.1 then
            wanted=self.requested
        end
        if wanted=="BURST" and (type(s.hudBurst)~="boolean" or s.hudBurstNo or (self.blocked.BURST or 0)>now) then wanted="SPRINT" end
        if (wanted=="SPRINT" or wanted=="BURST") and (self.blocked.SPRINT or 0)>now then wanted="TROT" end
        if wanted~=self.requested then self.changedAt=now;self.requested=wanted end
        if observed==wanted and not self.pending then self.reason="Native gait already active" end
        local fast=wanted=="SPRINT" or wanted=="BURST"
        io:hold("SHIFT",fast)
        local function request(mode,key)
            if self.pending and self.pending.mode~=mode and mode=="BURST_OFF" then self.pending=nil end
            if self.pending or (self.blocked[mode] or 0)>now then return end
            local sent=key=="SHIFT" and io:hold(key,true) or io:tap(key)
            if sent then
                self.attempts[mode]=(self.attempts[mode] or 0)+1
                self.requests+=1;self.pending={mode=mode,at=now}
                self.reason="Input requested; awaiting native gait"
                if mode=="BURST" then self.burstOwned=true end
                if mode=="TROT" then self.trotOwned=true end
            else self.blocked[mode]=now+8;self.reason="Gait input unavailable" end
        end
        if wanted~="BURST" and s.hudBurst==true and self.burstOwned then
            request("BURST_OFF","X")
        elseif wanted=="BURST" and s.hudBurst==false then request("BURST","X")
        elseif fast and s.hudSprint==false and s.hudBurst~=true then request("SPRINT","SHIFT")
        elseif wanted=="TROT" and s.hudTrot==false and s.hudBurst~=true then request("TROT","Z")
        elseif wanted=="WALK" and s.hudTrot==true and self.trotOwned then request("WALK","Z") end
        return self.requested
    end
    function g:stop(s,now)
        io:hold("SHIFT",false)
        -- Undo toggles only when this controller requested them and their
        -- current native state is known. Never blindly toggle an unknown mode.
        if s and s.hudBurst==true and self.burstOwned then io:tap("X") end
        if s and s.hudTrot==true and self.trotOwned then io:tap("Z") end
        self.burstOwned,self.trotOwned=false,false
        self.pending=nil;self.requested="STOP";self.changedAt=now or 0
    end
    return g
end
function Gait.arrived(destinationDistance,claimRadius)
    if not finite(destinationDistance) then return false end
    return destinationDistance<=math.max(8,(claimRadius or 17)-2)
end
-- Keep a goal unless its progress stalls. Do not change directions on each
-- intermediate waypoint when the destination is already within claim radius.
function Gait.waypointIndex(points,index,pos,reach)
    local i=math.max(1,index or 1)
    local radius=math.max(6,reach or 11)
    while i<=#points do
        local point=points[i]
        if Gait.distance(pos,point)<=radius then i+=1
        else break end
    end
    return i
end
function Gait.progress(now,previousTime,previousDistance,currentDistance,delay,minGain)
    if not finite(previousTime) or not finite(previousDistance) then
        return "RESET" end
    if now-previousTime < (delay or 4) then return "MONITOR" end
    if previousDistance-currentDistance >= (minGain or 3) then return "ADVANCING" end
    return "STALLED"
end
return Gait
]============]
sources["amber_nav"] = [============[
-- Continuous native steering, cancellable streamed routes and measured progress.
local Nav={}
local function flat(a,b)
    local x,z=a.X-b.X,a.Z-b.Z
    return math.sqrt(x*x+z*z)
end
local function p2(v) return {x=v.X,z=v.Z} end
local function rayParams(char)
    local p=RaycastParams.new()
    p.FilterType=Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances={char};p.IgnoreWater=false;p.RespectCanCollide=true
    return p
end
function Nav.new(pathService,workspace,Gait,model)
    local n={service=pathService,workspace=workspace,math=Gait,model=model,synthetic={},held={},backends={},gaitBackends={},
        recoveryCells={},trajectory={},operations={rays=0,surfaces=0,paths=0},
        destination=nil,body=nil,points={},index=1,epoch=0,keyEpoch=0,
        lastReason="IDLE",lastFailure=nil,gait="STOP",nativeInput="UNTESTED",
        preferredStrategy="WORLD",steeringStrategy="WORLD",lastMode="WORLD",
        failures=0,replans=0,routeFailures=0,stallsInRow=0,waterRoutes=0,
        strategyChanges=0,inputVerified=false,inputAttempts=0,driveCalls=0,
        travelled=0,distance=nil,speed=0,corrections=0,segmentCount=0,arrivalRadius=8,
        lastBurstAt=-100,lastTrotAt=-100,nextRouteAt=0,closed=false}
    local bindings={W=Enum.KeyCode.W,A=Enum.KeyCode.A,S=Enum.KeyCode.S,
        D=Enum.KeyCode.D,SHIFT=Enum.KeyCode.LeftShift,X=Enum.KeyCode.X,Z=Enum.KeyCode.Z}
    local codes={W=0x57,A=0x41,S=0x53,D=0x44,SHIFT=0xA0,X=0x58,Z=0x5A}
    local function send(name,on,backend)
        n.synthetic[name]=os.clock()
        if backend~="EXECUTOR" then
            local ok,v=pcall(function()return game:GetService("VirtualInputManager")end)
            if ok and v and pcall(v.SendKeyEvent,v,on,bindings[name],false,game) then return true,"VIRTUAL" end
        end
        local fn=on and keypress or keyrelease
        if type(fn)=="function" and pcall(fn,codes[name]) then return true,"EXECUTOR" end
        return false,"UNAVAILABLE"
    end
    function n:hold(name,on)
        if not bindings[name] then return false end
        if (self.held[name]==true)==on then return true end
        local ok,method=send(name,on,self.backends[name] or self.gaitBackends[name] or self.keyBackend)
        if on and ok then
            self.held[name]=true;self.backends[name]=method
            self.nativeInput=method;self.inputAttempts+=1
        elseif not on then self.held[name]=nil;self.backends[name]=nil end
        return ok
    end
    function n:tap(name)
        if self.held[name] or not self:hold(name,true) then return false end
        local epoch=self.keyEpoch
        task.delay(.09,function() if self.keyEpoch==epoch then self:hold(name,false) end end)
        return true
    end
    function n:retryInput(name)
        if type(keypress)~="function" or type(keyrelease)~="function" then return false end
        self:hold(name,false);self.gaitBackends[name]="EXECUTOR"
        return true
    end
    function n:releaseSteering()
        for _,key in ipairs({"W","A","S","D"}) do self:hold(key,false) end
    end
    function n:releaseKeys()
        self.keyEpoch+=1
        local keys={}
        for k in pairs(self.held) do table.insert(keys,k) end
        for _,k in ipairs(keys) do self:hold(k,false) end
    end
    n.gaits=Gait.controller(n)
    function n:stop(hum,root,reason)
        local active=self.desiredPoint~=nil or self.destination~=nil
        if active and reason=="at territory" and self.model and self.costPoint and self.goalOrigin and not self.costRecorded then
            self.model:record(p2(self.goalOrigin),self.costPoint,math.max(.1,(self.lastAt or 0)-(self.goalStarted or 0)),self.lastAt or 0,false,self.costPurpose,true)
            self.costRecorded=true
        end
        if active and self.model and self.goalOrigin and self.destination and not self.costRecorded
            and ((self.routeFailures or 0)>=4 or (self.stallsInRow or 0)>=3) then
            self.model:record(p2(self.goalOrigin),self.costPoint or p2(self.destination),math.max(1,(self.lastAt or 0)-(self.goalStarted or 0)),self.lastAt or 0,true,self.costPurpose)
            self.costRecorded=true
        end
        self.epoch+=1;self.pending=nil
        self.desiredPoint,self.desiredRoot,self.desiredHum=nil,nil,nil
        if active then self.gaits:stop(self.lastState,self.lastAt or 0) end
        self:releaseKeys();self.gait="STOP"
        if active and hum then pcall(hum.Move,hum,Vector3.zero,false) end
        self.destination,self.body,self.identity=nil,nil,nil
        self.points,self.index={},1;self.lastPosition=nil
        self.lastReason=reason or "IDLE"
    end
    function n:reset(destination,char,now,identity)
        self.epoch+=1;self.pending=nil
        self.destination,self.body,self.identity=destination,char,identity
        self.points,self.index={},1;self.nextRouteAt=now
        self.desiredPoint=nil;self:releaseSteering()
        self.lastProgressAt=now;self.lastPosition=nil;self.lastSampleAt=now
        self.windowAt=now;self.windowOrigin=nil;self.windowTravel=0
        self.stallsInRow,self.routeFailures,self.corrections=0,0,0
        self.inputVerified=false;self.steeringStrategy=self.preferredStrategy
        self.recoveryProgress=0;self.overlapAt=nil;self.overlapParts=nil
        self.detourUntil=nil;self.lastObstacleProbe=nil
        self.lastReason="NEW_ROUTE";self.goalStarted=now
        self.routeTravel=0;self.safetyBlockedUntil=nil;self.lastSafety=nil
        self.goalOrigin=nil;self.costRecorded=false;self.trajectory={};self.bestGoalDistance=nil
    end
    function n:surface(pos,char,allowWater)
        self.operations.surfaces+=1
        local cacheKey=string.format("%.1f:%.1f:%.1f:%s",pos.X,pos.Y,pos.Z,tostring(allowWater))
        local cache=self.surfaceCache and self.surfaceCache[cacheKey]
        if cache then return cache.point,cache.wet end
        local params=rayParams(char)
        local root=char and type(char.FindFirstChild)=="function" and char:FindFirstChild("HumanoidRootPart")
        local originY=root and root.Position.Y or pos.Y
        -- Prefer the real terrain under tall foliage. A low supporting solid
        -- surface may override it for rocks, bridges and constructed ground.
        local terrainParams=rayParams(char)
        terrainParams.FilterType=Enum.RaycastFilterType.Include
        terrainParams.FilterDescendantsInstances={self.workspace.Terrain}
        self.operations.rays+=2
        local terrain=self.workspace:Raycast(Vector3.new(pos.X,math.max(pos.Y,originY)+100,pos.Z),Vector3.new(0,-420,0),terrainParams)
        local solid=self.workspace:Raycast(Vector3.new(pos.X,originY+12,pos.Z),Vector3.new(0,-420,0),params)
        local hit=terrain or solid
        if solid and solid.Normal.Y>=.46 and solid.Position.Y<=originY+5
            and (not terrain or solid.Position.Y>terrain.Position.Y+.4) then hit=solid end
        if not hit then return nil end
        local wet=hit.Material==Enum.Material.Water
        if wet and not allowWater or not wet and hit.Normal.Y<(self.minGroundNormal or .46) then return nil end
        local position=hit.Position+Vector3.new(0,2.5,0)
        if self.surfaceCache then self.surfaceCache[cacheKey]={point=position,wet=wet} end
        return position,wet
    end
    function n:bodyClear(from,to,char)
        local direction=to-from
        if direction.Magnitude<.1 then return true end
        -- Sweeps omit shapes already touching their start volume. Check the
        -- actual animal root separately and allow movement out of an overlap.
        if self.bodyRoot and type(self.workspace.GetPartsInPart)=="function" and OverlapParams then
            local at=self.lastAt or 0
            if not self.overlapAt or at-self.overlapAt>.4 then
                self.overlapAt=at
                local params=OverlapParams.new()
                params.FilterType=Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances={char};params.RespectCanCollide=true;params.MaxParts=12
                self.operations.overlaps=(self.operations.overlaps or 0)+1
                local ok,parts=pcall(self.workspace.GetPartsInPart,self.workspace,self.bodyRoot,params)
                self.overlapParts=ok and parts or {}
            end
            for _,part in ipairs(self.overlapParts or {}) do
                if part.CanCollide~=false and part.Position then
                    local away=Vector3.new(from.X-part.Position.X,0,from.Z-part.Position.Z)
                    if away.Magnitude>.05 and direction:Dot(away)<0 then
                        self.lastObstacle={Instance=part};return false
                    end
                end
            end
        end
        if type(self.workspace.Blockcast)=="function" and CFrame and type(CFrame.lookAt)=="function" then
            local params=rayParams(char);params.IgnoreWater=true
            local size=Vector3.new((self.clearance or 2)*1.9,self.bodyHeight or 2,self.bodyLength or 4)
            self.operations.sweeps=(self.operations.sweeps or 0)+1
            local ok,hit=pcall(self.workspace.Blockcast,self.workspace,CFrame.lookAt(from,from+direction),size,direction,params)
            if ok and hit and (not hit.Instance or hit.Instance.CanCollide~=false) then
                self.lastObstacle=hit;return false
            end
        end
        return true
    end
    function n:clearSegment(from,to,char,allowWater,precise)
        self.lastSafety=nil
        local distance=flat(from,to)
        if distance<.1 then return true,false end
        local params=rayParams(char);params.IgnoreWater=true
        if not self:bodyClear(from,to,char) then return false,false end
        -- Terrain walls are obstacles too; never exempt Terrain from this ray.
        self.operations.rays+=3
        local hit=self.workspace:Raycast(from+Vector3.new(0,1.5,0),to-from,params)
        if hit and (not hit.Instance or hit.Instance.CanCollide~=false) then return false,false end
        local perpendicular=Vector3.new(-(to.Z-from.Z)/distance,0,(to.X-from.X)/distance)
        for _,side in ipairs({-1,1}) do
            local offset=perpendicular*(self.clearance or 2)*side
            local flank=self.workspace:Raycast(from+Vector3.new(0,1.5,0)+offset,to-from,params)
            if flank and (not flank.Instance or flank.Instance.CanCollide~=false) then return false,false end
        end
        local wet=false;local previous={}
        local steps=math.max(1,math.ceil(distance/(precise and 1 or 3)))
        for step=0,steps do
            local p=from+(to-from)*(step/steps)
            local center
            for _,side in ipairs({0,-1,1}) do
                local offset=perpendicular*(self.clearance or 2)*.8*side
                local ground,water=self:surface(p+offset,char,allowWater)
                if not ground then self.lastSafety="MISSING_SUPPORT";return false,wet end
                if side==0 then center=ground end
                if not previous[side] and from.Y-ground.Y>(self.supportHeight or 5)+(self.maxDrop or 3) then
                    self.lastSafety="UNSUPPORTED_DROP";return false,wet
                end
                if previous[side] then
                    local rise=ground.Y-previous[side].Y
                    if rise>(self.maxStepUp or 3) or -rise>(self.maxDrop or 3) then
                        self.lastSafety=rise>0 and "STEEP_ASCENT" or "UNSAFE_DESCENT"
                        return false,wet
                    end
                end
                if center and math.abs(ground.Y-center.Y)>math.max(self.maxDrop or 3,self.maxStepUp or 3) then
                    self.lastSafety="UNSUPPORTED_BODY_EDGE";return false,wet
                end
                previous[side]=ground;wet=wet or water
            end
        end
        return true,wet
    end
    function n:detour(root,char,state,now)
        local delta=self.destination-root.Position
        local d=flat(self.destination,root.Position)
        if d<.1 then return false end
        local base=Vector3.new(delta.X/d,0,delta.Z/d)
        local span=math.clamp((self.clearance or 2)*2.5,8,18)
        local sides=self.detourSide or 1
        for _,angle in ipairs({sides*1.1,-sides*1.1,sides*1.8,-sides*1.8,math.pi}) do
            local x=base.X*math.cos(angle)-base.Z*math.sin(angle)
            local z=base.X*math.sin(angle)+base.Z*math.cos(angle)
            local point=self:surface(root.Position+Vector3.new(x*span,0,z*span),char,state.allowWater==true)
            local cell=point and (math.floor(point.X/10)..":"..math.floor(point.Z/10))
            if point and (not self.recoveryCells[cell] or now-self.recoveryCells[cell]>20)
                and self:clearSegment(root.Position,point,char,state.allowWater==true,true) then
                self.recoveryCells[cell]=now
                local count=0;for key,at in pairs(self.recoveryCells) do count+=1;if now-at>30 then self.recoveryCells[key]=nil end end
                if count>96 then self.recoveryCells={[cell]=now} end
                self.epoch+=1;self.pending=nil
                self.points,self.index={point},1;self.routeOrigin=root.Position
                self.detourUntil=now+3;self.detourSide=-sides
                self.obstacleRecoveries=(self.obstacleRecoveries or 0)+1
                self.lastFailure="LOCAL_OBSTACLE_DETOUR"
                return true
            end
        end
        return false
    end
    function n:mesh(from,target,root,hum,char,state)
        self.operations.paths+=1
        local ok,path=pcall(function()
            local p=self.service:CreatePath({AgentRadius=self.clearance or 3,
                AgentHeight=math.clamp(hum.HipHeight+root.Size.Y+1,4,30),
                AgentCanJump=false,AgentCanClimb=false,WaypointSpacing=12})
            p:ComputeAsync(from,target);return p
        end)
        if not ok or path.Status~=Enum.PathStatus.Success then return nil end
        local points={};local previous=from
        for _,waypoint in ipairs(path:GetWaypoints()) do
            local p=waypoint.Position
            if typeof(p)=="Vector3" and flat(p,from)>2 then
                local ground=self:surface(p,char,false)
                if not ground or not self:clearSegment(previous,ground,char,false) then return nil end
                table.insert(points,ground);previous=ground
            end
            if #points>160 then return nil end
        end
        return #points>0 and points or nil
    end
    function n:compute(from,root,hum,char,state,goal,attempt)
        local distance=flat(from,goal)
        if distance<.01 then return {},"EMPTY_ROUTE" end
        local delta=goal-from;local dir=Vector3.new(delta.X/distance,0,delta.Z/distance)
        local span=math.min(distance,100)
        local allowWater=state.allowWater==true
        local direct=self:surface(from+dir*span,char,allowWater)
        if direct then
            local clear,wet=self:clearSegment(from,direct,char,allowWater)
            if clear then return {direct},(wet or state.swimming) and "SWIM_ROUTE" or "CLEAR_SURFACE" end
        end
        if not state.movingTarget and not state.swimming then
            local full=self:surface(goal,char,false)
            if full and distance<=900 then
                if self.model then
                    local cached=self.model:path(p2(from),p2(full),state.now or self.lastAt or 0)
                    if cached then
                        local result={};local previous=from;local valid=true
                        for _,p in ipairs(cached) do
                            local v=Vector3.new(p.x,p.y or full.Y,p.z)
                            if not self:clearSegment(previous,v,char,false) then valid=false;break end
                            table.insert(result,v);previous=v
                        end
                        if valid then return result,"CHECKED_PASSAGE" end
                    end
                end
                local fullPath=self:mesh(from,full,root,hum,char,state)
                if fullPath then return fullPath,"PATH_SURFACE_FULL" end
            end
        end
        local angles={0,-.45,.45,-.9,.9}
        if attempt%2==1 then angles={0,.45,-.45,.9,-.9} end
        for _,angle in ipairs(angles) do
            local length=angle==0 and span or math.min(span,55)
            local x=dir.X*math.cos(angle)-dir.Z*math.sin(angle)
            local z=dir.X*math.sin(angle)+dir.Z*math.cos(angle)
            local surface,water=self:surface(from+Vector3.new(x*length,0,z*length),char,allowWater)
            if surface then
                local clear,crossesWater=self:clearSegment(from,surface,char,allowWater)
                if clear then return {surface},(water or crossesWater or state.swimming) and "SWIM_ROUTE" or "CLEAR_SURFACE" end
                if not water and not state.swimming then
                    local points=self:mesh(from,surface,root,hum,char,state)
                    if points then return points,"PATH_SURFACE" end
                end
            end
        end
        return nil,"NO_STREAMED_SAFE_ROUTE"
    end
    function n:route(root,hum,char,now,state)
        if self.pending or (self.activeJobs or 0)>=2 or now<self.nextRouteAt then return end
        local epoch=self.epoch
        local request={at=now,epoch=epoch,origin=root.Position,goal=self.destination}
        self.pending=request;self.activeJobs=(self.activeJobs or 0)+1
        task.spawn(function()
            local started=os.clock()
            local ok,points,reason=pcall(self.compute,self,request.origin,root,hum,char,
                table.clone(state or {}),request.goal,self.replans)
            self.pathWall=(self.pathWall or 0)+math.max(0,os.clock()-started)
            self.activeJobs-=1
            if self.closed or self.epoch~=epoch or self.pending~=request then return end
            self.pending=nil
            if not ok or not points then
                self.routeFailures+=1;self.failures+=1
                self.lastFailure=ok and reason or "PATH_COMPUTATION_ERROR"
                self.lastReason=self.lastFailure;self.nextRouteAt=now+1.5
                return
            end
            -- An old path cannot pull a moving animal back toward its old start.
            if not root.Parent or self.body~=char then return end
            -- Rebase a late same-goal path at the closest checked forward join.
            local bestIndex,best=1,math.huge
            for index,p in ipairs(points) do
                local previous=points[index-1] or request.origin
                local delta=p-previous;local len=delta:Dot(delta)
                local t=len>.01 and math.clamp((root.Position-previous):Dot(delta)/len,0,1) or 0
                local projection=previous+delta*t;local d=flat(root.Position,projection)
                if d<best and self:clearSegment(root.Position,p,char,state.allowWater==true,true) then bestIndex,best=index,d end
            end
            if flat(root.Position,request.origin)>30 and best>math.max(15,self.clearance*3) then
                self.lastFailure="OBSOLETE_PATH_ORIGIN";self.nextRouteAt=self.lastAt or now;return
            end
            self.points,self.index=points,bestIndex;self.routeOrigin=request.origin
            self:advance(root,math.clamp(root.Size.X*.5+4,6,12))
            if self.model then
                local observed={{x=request.origin.X,y=request.origin.Y,z=request.origin.Z}}
                for _,p in ipairs(points) do table.insert(observed,{x=p.X,y=p.Y,z=p.Z}) end
                self.model:addRoute(observed,self.lastAt or now)
            end
            self.segmentCount+=1;self.routeFailures=0
            self.routeAt=now;self.lastReason=reason
            self.routeWater=reason=="SWIM_ROUTE"
            if self.routeWater then self.waterRoutes+=1 end
        end)
    end
    function n:direction()
        local root,hum,p=self.desiredRoot,self.desiredHum,self.desiredPoint
        if not root or not hum or not p or not root.Parent or hum.Health<=0 then return nil end
        local delta=Vector3.new(p.X-root.Position.X,0,p.Z-root.Position.Z)
        if delta.Magnitude<=self.arrivalRadius and flat(root.Position,self.destination or p)<=self.arrivalRadius then return Vector3.zero end
        if delta.Magnitude<.1 then return Vector3.zero end
        return delta.Unit*(self.inputScale or 1)
    end
    function n:drive()
        self.driveCalls+=1
        local direction=self:direction()
        if not direction then self:releaseSteering();return end
        if self.steeringStrategy=="WORLD" then
            self:releaseSteering();self.desiredHum:Move(direction,false)
            self.lastMode="WORLD";return
        end
        local camera=self.workspace.CurrentCamera
        if not camera then self:releaseSteering();self.lastFailure="NO_CAMERA";return end
        if direction.Magnitude<.01 then self:releaseSteering();return end
        -- Keys are digital: an analog following scale must not fall below
        -- every direction threshold and silently stop a moving pursuit.
        direction=direction.Unit
        local f,r=camera.CFrame.LookVector,camera.CFrame.RightVector
        f=Vector3.new(f.X,0,f.Z);r=Vector3.new(r.X,0,r.Z)
        if f.Magnitude<.1 or r.Magnitude<.1 then self:releaseSteering();return end
        local forward,side=direction:Dot(f.Unit),direction:Dot(r.Unit)
        -- Eight directions avoid the four-direction fallback's square orbit.
        local keys={W=forward>.38,S=forward<-.38,D=side>.38,A=side<-.38}
        for key,on in pairs(keys) do self:hold(key,on) end
        self.lastMode="NATIVE_KEYS"
    end
    function n:advance(root,radius)
        local advanced=false
        while self.index<=#self.points do
            local p=self.points[self.index]
            local last=self.index==#self.points
            local goalNear=last and self.destination and flat(p,self.destination)<3
            local reach=goalNear and self.arrivalRadius or radius
            local near=flat(root.Position,p)<=reach
            local prev=self.points[self.index-1] or self.routeOrigin
            local passed=false
            if prev and not goalNear then
                local dx,dz=p.X-prev.X,p.Z-prev.Z;local len=math.sqrt(dx*dx+dz*dz)
                if len>.1 then
                    local beyond=((root.Position.X-p.X)*dx+(root.Position.Z-p.Z)*dz)/len
                    local cross=math.abs((root.Position.X-p.X)*dz-(root.Position.Z-p.Z)*dx)/len
                    passed=beyond>0 and cross<radius*1.4
                end
            end
            if near or passed then self.index+=1;advanced=true else break end
        end
        return advanced
    end
    function n:tick(destination,char,hum,root,now,otherPlayers,state)
        state=state or {};self.lastState=state;self.lastAt=now;self.surfaceCache={}
        if self.closed or not destination or not char or not hum or not root or hum.Health<=0 then
            self:stop(hum,root,"NO_LIVING_ANIMAL");return "WAIT"
        end
        local identity=state.navKey or "STATIC"
        self.bodyRoot=root
        self.clearance=math.clamp(root.Size.X*.5+.65,2,12)
        self.bodyHeight=math.clamp(root.Size.Y*.8,1,10)
        self.bodyLength=math.clamp(root.Size.Z*.65,2,18)
        self.supportHeight=math.max(2,hum.HipHeight+root.Size.Y*.5)
        self.maxDrop=math.clamp(hum.HipHeight*.75,2,4)
        self.maxStepUp=math.clamp(hum.HipHeight,2,4)
        self.minGroundNormal=math.cos(math.rad(math.clamp(hum.MaxSlopeAngle or 55,20,55)))
        if not self.destination or self.body~=char or self.identity~=identity then self:reset(destination,char,now,identity) end
        local targetShift=flat(destination,self.destination)
        self.destination=destination
        self.arrivalRadius=state.moveRadius or 8
        self.inputScale=state.moveScale and math.clamp(state.moveScale,.15,1) or 1
        local total=flat(root.Position,destination);self.distance=total
        self.costPoint=state.costPoint;self.costPurpose=state.costPurpose
        self.goalOrigin=self.goalOrigin or root.Position
        self.bestGoalDistance=math.min(self.bestGoalDistance or total,total)
        if total<=self.arrivalRadius then
            if self.model and not self.costRecorded then
                self.model:record(p2(self.goalOrigin),self.costPoint or p2(destination),math.max(.1,now-self.goalStarted),now,false,self.costPurpose,self.costPurpose~=nil)
                self.costRecorded=true
            end
            self:stop(hum,root,"ARRIVED");return "REACHED"
        end

        local dt=now-(self.lastSampleAt or now)
        if self.lastPosition and dt>0 then
            local moved=flat(root.Position,self.lastPosition)
            if moved>math.max(90,(self.speed or 0)*dt*3+35) then
                self.corrections+=1;self.points={};self.epoch+=1;self.pending=nil
                self.desiredPoint=nil;self:releaseSteering()
                self.lastFailure="POSITION_CORRECTION";self.lastProgressAt=now
                if self.corrections>=3 then self:stop(hum,root,"REPEATED_CORRECTIONS");return "STUCK" end
            else
                self.travelled+=moved;self.routeTravel+=moved;self.windowTravel+=moved
                self.speed=self.speed*.6+math.min(180,moved/dt)*.4
                local wp=self.points[self.index]
                if wp and flat(self.lastPosition,wp)-flat(root.Position,wp)>math.max(.05,dt*.4) then
                    self.lastProgressAt=now;self.inputVerified=true
                    self.recoveryProgress+=moved
                    if self.recoveryProgress>15 then self.stallsInRow=0 end
                end
            end
        end
        self.lastPosition=root.Position;self.lastSampleAt=now
        self.windowOrigin=self.windowOrigin or root.Position
        local oscillating=false
        if now>=(self.nextTrajectoryAt or 0) then
            self.nextTrajectoryAt=now+1
            for _,sample in ipairs(self.trajectory) do
                if now-sample.at>8 and flat(root.Position,sample.position)<8
                    and self.routeTravel-sample.travel>70 and total>=sample.distance-5 then
                    oscillating=true;self.lastFailure="RECURRENT_ROUTE";self.lastProgressAt=now-6;break
                end
            end
            table.insert(self.trajectory,{at=now,position=root.Position,travel=self.routeTravel,distance=total})
            while #self.trajectory>40 do table.remove(self.trajectory,1) end
        end
        if now-self.windowAt>=6 then
            if self.windowTravel>35 and flat(root.Position,self.windowOrigin)<6 then
                self.lastProgressAt=math.min(self.lastProgressAt,now-6)
                self.lastFailure="OSCILLATION"
                oscillating=true
            end
            self.windowOrigin=root.Position;self.windowTravel=0;self.windowAt=now
        end
        local waypointRadius=self.detourUntil and now<self.detourUntil and 2 or math.clamp(root.Size.X*.5+4,6,12)
        local advanced=self:advance(root,waypointRadius)
        if advanced and not oscillating then self.lastProgressAt=now;self.inputVerified=true end
        if self.pending and now-self.pending.at>4 then
            self.epoch+=1;self.pending=nil;self.routeFailures+=1
            self.lastFailure="PATH_TIMEOUT"
        end
        if self.routeFailures>=4 then self:stop(hum,root,self.lastFailure);return "STUCK" end
        if now-self.lastProgressAt>.9 and now-(self.lastObstacleProbe or 0)>1
            and not (self.detourUntil and now<self.detourUntil and self.index<=#self.points) then
            self.lastObstacleProbe=now
            local probePoint=self.desiredPoint or destination
            local towards=probePoint-root.Position
            local dist=flat(probePoint,root.Position)
            if dist>1 then
                local probe=root.Position+Vector3.new(towards.X/dist,0,towards.Z/dist)*math.min(12,dist)
                if not self:bodyClear(root.Position,probe,char) then
                    self.lastCollisionAt=now
                    self:detour(root,char,state,now)
                end
            end
        end
        if now-self.lastProgressAt>(self.inputVerified and 2.5 or 1.6) then
            self.stallsInRow+=1;self.replans+=1;self.lastProgressAt=now
            self.recoveryProgress=0
            self.points={};self.epoch+=1;self.pending=nil;self.desiredPoint=nil
            self:releaseSteering();self:hold("SHIFT",false)
            self.lastFailure=(self.lastFailure=="OSCILLATION" or self.lastFailure=="RECURRENT_ROUTE") and self.lastFailure or "NO_PHYSICAL_PROGRESS"
            if self.stallsInRow==1 and self.steeringStrategy=="WORLD" and now-(self.lastCollisionAt or -100)>3 then
                self.steeringStrategy="KEY";self.strategyChanges+=1
            elseif self.stallsInRow==2 and type(keypress)=="function" then self.keyBackend="EXECUTOR" end
            if self.stallsInRow>=3 then self:stop(hum,root,"BOUNDED_STUCK");return "STUCK" end
        end
        local exhausted=self.index>#self.points
        if exhausted then
            self.points={};self.index=1;self.desiredPoint=nil
            self:releaseSteering()
        end
        -- Prepare the next segment while following the current valid segment.
        local tail=self.points[#self.points]
        local prefetch=tail and flat(root.Position,tail)<math.max(24,self.speed*.85)
            and flat(tail,destination)>15
        if (not self.detourUntil or now>=self.detourUntil or exhausted) and (exhausted or prefetch or targetShift>14 and now-(self.routeAt or 0)>1.1) then
            self:route(root,hum,char,now,state)
        end
        self:advance(root,waypointRadius)
        local waypoint=self.points[self.index]
        if not waypoint then
            self.desiredPoint=nil;self:releaseSteering();self:hold("SHIFT",false)
            self.lastReason=self.pending and "PLANNING" or self.lastFailure or "WAIT_ROUTE"
            return "WAIT"
        end
        if not state.movingTarget and not (self.detourUntil and now<self.detourUntil)
            and now>=(self.shortcutAt or 0) then
            self.shortcutAt=now+.75
            local d=destination-root.Position
            local direct=self:surface(root.Position+Vector3.new(d.X/total,0,d.Z/total)*math.min(total,100),char,state.allowWater==true)
            -- Prefer the checked straight corridor when an old obstacle path
            -- is no longer necessary. Do not cut a mountain bend blindly.
            if direct and flat(direct,waypoint)>8 and self:clearSegment(root.Position,direct,char,state.allowWater==true) then
                self.epoch+=1;self.pending=nil;self.points={direct};self.index=1
                self.routeOrigin=root.Position;self.segmentCount+=1;waypoint=direct
            end
        end
        -- Collapse straight, visible path sections into a body-checked horizon.
        -- Gaits can remain fast across tiny mesh waypoints without cutting bends.
        for j=math.min(#self.points,self.index+7),self.index+1,-1 do
            local candidate=self.points[j]
            if flat(root.Position,candidate)<=120 and self.math.turn(p2(root.Position),p2(waypoint),p2(candidate))<22
                and self:clearSegment(root.Position,candidate,char,state.allowWater==true) then
                self.index=j;waypoint=candidate;break
            end
        end
        -- Directly track a nearby moving target only over checked terrain.
        if state.movingTarget and total<28 then
            local clear=self:clearSegment(root.Position,destination,char,state.allowWater==true)
            if clear then waypoint=destination end
        end
        -- Recheck the immediate corridor after every meaningful navigation
        -- update. Terrain may stream/change after the path was computed.
        local ahead=waypoint-root.Position;local aheadFlat=flat(root.Position,waypoint)
        local reach=math.min(aheadFlat,math.max(8,self.speed*.75+self.bodyLength*.5))
        if aheadFlat>.1 then
            local probe=root.Position+Vector3.new(ahead.X/aheadFlat*reach,0,ahead.Z/aheadFlat*reach)
            local safe=self:clearSegment(root.Position,probe,char,state.allowWater==true,true)
            if not safe then
                self.desiredPoint=nil;self:releaseSteering();self:hold("SHIFT",false)
                if hum then pcall(hum.Move,hum,Vector3.zero,false) end
                self.lastFailure=self.lastSafety or "BLOCKED_CORRIDOR";self.lastReason="CHECKING_SAFE_APPROACH"
                self.points={};self.epoch+=1;self.pending=nil;self.nextRouteAt=now+.15
                return "WAIT"
            end
        end
        local look=root.CFrame and root.CFrame.LookVector
        local previous=look and {x=root.Position.X-look.X*5,z=root.Position.Z-look.Z*5} or nil
        local turn=self.math.turn(previous,p2(root.Position),p2(waypoint))
        local localRange=flat(root.Position,waypoint)
        local nextPoint=self.points[self.index+1]
        if nextPoint and self.math.turn(p2(root.Position),p2(waypoint),p2(nextPoint))>55 and localRange<35 then turn=math.max(turn,85) end
        self.lastTurn=turn;self.localRange=localRange
        local braking=turn>72 or total<18 or (nextPoint and localRange<math.max(20,self.speed*.55))
        state.brake=braking or self.detourUntil and now<self.detourUntil
        local wanted=self.math.select(state.hunting and total*2 or total,turn,state.staminaFraction,{
            allowBurst=state.allowBurst~=false and self.inputVerified and localRange>=38,
            nativeBurstAvailable=type(state.hudBurst)=="boolean",
            burstReady=not state.hudBurstNo,swimming=state.swimming,
            swimSprint=state.swimSprint,combat=state.combat,hunting=state.hunting,
            preySpeed=state.preySpeed,following=state.following,gaitSpeeds=state.gaitSpeeds,ability=state.ability})
        self.gait=self.gaits:step(wanted,state,now)
        self.desiredPoint,self.desiredRoot,self.desiredHum=waypoint,root,hum
        self.lastReason=(state.swimming and "SWIM_" or "FOLLOWING_")..self.gait
        return "MOVING"
    end
    function n:status()
        return {stage=self.lastReason,failure=self.lastFailure,method=self.lastMode,
            driverPath=self.driverPath,driverReason=self.driverReason,
            requested=self.gaits.requested,observed=self.gaits.observed,
            gaitReason=self.gaits.reason,gaitRequests=self.gaits.requests,
            gaitConfirmations=self.gaits.confirmations,input=self.nativeInput,
            staminaFraction=self.lastState and self.lastState.staminaFraction,
            inputVerified=self.inputVerified,distance=self.distance,
            travelled=math.floor(self.travelled*10)/10,speed=math.floor(self.speed*10)/10,
            routeTravel=math.floor((self.routeTravel or 0)*10)/10,routeAge=self.goalStarted and (self.lastAt-self.goalStarted),
            stalledFor=self.lastProgressAt and (self.lastAt-self.lastProgressAt),safety=self.lastSafety,
            replans=self.replans,failures=self.failures,waterRoutes=self.waterRoutes,
            corrections=self.corrections,segments=self.segmentCount,obstacleRecoveries=self.obstacleRecoveries or 0,
            operations=self.operations,pathJobWallSeconds=self.pathWall,activeJobs=self.activeJobs or 0,knowledge=self.model and self.model:summary()}
    end
    return n
end
return Nav
]============]
sources["amber_hunt"] = [============[
-- Moving NPC pursuit. Inputs and observed HP changes are separate outcomes.
local Hunt={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e8 end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
function Hunt.new(adapter)
    local h={adapter=adapter,target=nil,pending=nil,hits=0,misses=0,attacks=0,
        lastResult="No attack",nextAttack=0,blocked={},kills=0}
    function h:abandon(now,why)
        if self.target and self.target.model then
            self.blocked[self.target.model]=now+80
            if self.adapter.preyBlocked then self.adapter.preyBlocked[self.target.model]=now+80 end
        end
        self.target,self.pending=nil,nil
        self.lastBlockedReason=self.lastBlockedReason or self.lastResult
        self.blockedAt=now;self.abandonReason=why
        self.lastResult=why;self.nextSelect=now+.25
        self.adapter:stop(why)
    end
    function h:tick(s)
        local now=s.now
        if self.adapter.attackEvidence then self.inputEvidence=self.adapter:attackEvidence(s) end
        local prey=self.target
        if prey and prey.hum and prey.hum.Health<=0 then
            self.kills+=1;self.lastResult="Observed NPC HP reached zero; attribution unverified"
            self.corpse={position=prey.position,at=now,model=prey.model}
            self.target,self.pending=nil,nil
            self.adapter:stop("prey down")
            return "PREY_DOWN",self.lastResult
        end
        if prey then prey=self.adapter:checkPrey(prey,s) end
        if not prey then
            self.target,self.pending=nil,nil
            if now<(self.nextSelect or 0) then return "HUNT_SEARCH",self.lastResult end
            prey=self.adapter:prey(s)
            if prey and prey.model and (self.blocked[prey.model] or 0)>now then prey=nil end
            if not prey then self.adapter:stop("no suitable NPC prey");return "WAIT_FOOD","No suitable safe NPC prey or edible food" end
            self.target=prey;self.started=now;self.bestDistance=distance(s.position,prey.position)
            self.closingAt=now;self.sample=nil;self.noDamageAt=nil;self.missesOnTarget=0
            self.lastTargetHealth=prey.health or prey.hum and prey.hum.Health
            self.lastUsefulAt=now;self.blockedSince=nil;self.nextAttack=now
            self.repositionUntil=nil;self.previousThrottle=nil;self.fullSpeed=nil;self.routeRetries=0;self.smoothVelocity=nil
        end
        local health=prey.health or prey.hum and prey.hum.Health
        if finite(health) and finite(self.lastTargetHealth) and health<self.lastTargetHealth-.01 then
            if self.adapter.huntOutcome then self.adapter:huntOutcome(self.lastTargetHealth-health) end
            self.lastUsefulAt=now;self.noDamageAt=now;self.closingAt=now
            self.missesOnTarget=0;self.routeRetries=0
        end
        self.lastTargetHealth=health
        if self.pending then
            local p=self.pending
            if finite(health) and health<p.health-.01 then
                self.hits+=1;self.noDamageAt=now;self.missesOnTarget=0
                self.lastResult="Observed prey HP decline after input; attribution unverified"
                self.pending=nil
            elseif now-p.at>(s.attackCooldown and math.clamp(s.attackCooldown*.75+(s.progressLatency or .5)+.5,1.1,3) or 1.1) then
                self.misses+=1;self.missesOnTarget+=1
                self.lastResult="No prey HP decline observed"
                self.lastBlockedReason=self.lastResult;self.lastBlockedAt=now
                self.pending=nil;self.repositionUntil=now+.55
            end
        end
        local d=distance(s.position,prey.position)
        if d<self.bestDistance-2 then self.bestDistance=d;self.closingAt=now;self.lastUsefulAt=now;self.routeRetries=0 end
        if d>390 or now-self.lastUsefulAt>60 or self.missesOnTarget>=5
            or now-self.closingAt>12 and d>28 or self.noDamageAt and now-self.noDamageAt>16 and d<28 then
            self:abandon(now,"Prey escaping, unreachable or attacks ineffective")
            return "HUNT_REPLAN",self.lastResult
        end
        local velocity=prey.velocity or {x=0,z=0}
        if self.sample and now>self.sample.at and now-self.sample.at<2 and not prey.velocity then
            velocity={x=(prey.position.x-self.sample.position.x)/(now-self.sample.at),
                z=(prey.position.z-self.sample.position.z)/(now-self.sample.at)}
        end
        local speed=math.sqrt(velocity.x^2+velocity.z^2)
        if speed>100 then velocity={x=0,z=0};speed=0 end
        if self.smoothVelocity then
            velocity={x=self.smoothVelocity.x*.55+velocity.x*.45,z=self.smoothVelocity.z*.55+velocity.z*.45}
            speed=math.sqrt(velocity.x^2+velocity.z^2)
        end
        self.smoothVelocity=velocity
        self.sample={position={x=prey.position.x,z=prey.position.z},at=now}
        local lead=math.clamp(d/math.max(20,(s.travelSpeed or 35)+speed),.08,.85)
        local geometry=type(self.adapter.attackGeometry)=="function" and self.adapter:attackGeometry(s,prey) or nil
        local valid=geometry and geometry.valid
        self.geometry=geometry
        if not valid then
            self.lastBlockedReason=geometry and geometry.reason or "Native bite geometry unavailable"
            self.lastBlockedAt=now
            self.lastResult=self.lastBlockedReason
        end
        if not valid then self.blockedSince=nil end
        local heading=speed>1 and {x=velocity.x/speed,z=velocity.z/speed} or prey.forward
        local standoff=math.clamp((prey.attackRange or 7)*.65,2.4,8)
        local target={x=prey.position.x+velocity.x*lead,z=prey.position.z+velocity.z*lead}
        if heading then
            target.x-=heading.x*standoff;target.z-=heading.z*standoff
        end
        local following=speed>1 and d<standoff+10 and geometry and geometry.inRange
        local scale=1
        if following then
            local nav=self.adapter.nav
            local observed=nav and nav.speed
            local previous=self.previousThrottle or 1
            if observed and observed>2 then self.fullSpeed=(self.fullSpeed or observed)*.7+(observed/math.max(previous,.2))*.3 end
            if self.fullSpeed and self.fullSpeed>2 then
                scale=math.clamp((speed+(d-standoff)*1.8)/self.fullSpeed,.15,1)
            end
        end
        self.previousThrottle=scale
        -- Keep pursuing while verifying a previous bite; a coarse range check
        -- must never freeze a hunter while its prey runs out of range.
        if valid and now>=self.nextAttack and not self.pending and now>=(self.repositionUntil or 0) then
            local sent,why=self.adapter:bite(s,prey)
            if self.adapter.attackEvidence then self.inputEvidence=self.adapter:attackEvidence(s) end
            self.lastResult=why or (sent and "Attack requested; awaiting prey HP" or "Native attack not ready")
            self.nextAttack=now+(sent and (s.attackCooldown or .9) or .25)
            if sent then self.blockedSince=nil;self.noDamageAt=self.noDamageAt or now
            else self.blockedSince=self.blockedSince or now;self.lastBlockedReason=self.lastResult;self.lastBlockedAt=now end
            if sent and finite(health) then
                self.attacks+=1;self.pending={at=now,health=health}
            end
        end
        if self.blockedSince and now-self.blockedSince>12 then
            self:abandon(now,"Native attack unavailable: "..tostring(self.lastResult))
            return "HUNT_REPLAN",self.lastResult
        end
        if valid and speed<2 and not self.repositionUntil then
            self.adapter:stop("valid stationary attack position")
        else
            if geometry and geometry.inRange and geometry.facing==false and geometry.clear~=false then
                -- Walking toward a parking point behind prey can end with our
                -- animal facing away and no remaining movement. Approach the
                -- prey itself until native movement turns us toward it.
                target={x=prey.position.x,z=prey.position.z}
            elseif geometry and geometry.inRange and not valid or now<(self.repositionUntil or 0) then
                local dx,dz=prey.position.x-s.position.x,prey.position.z-s.position.z
                local len=math.max(1,math.sqrt(dx*dx+dz*dz))
                local side=(self.missesOnTarget%2==0) and 1 or -1
                if heading then
                    target={x=prey.position.x-heading.x*standoff-heading.z*side*2,
                        z=prey.position.z-heading.z*standoff+heading.x*side*2}
                else
                    target={x=prey.position.x+dx/len*2-dz/len*side*2,
                        z=prey.position.z+dz/len*2+dx/len*side*2}
                end
            end
            local result=self.adapter:move(target,s,{navKey=prey.model or "NPC_HUNT",
                movingTarget=true,hunting=true,following=following,moveScale=scale,preySpeed=speed,moveRadius=.9})
            if result=="STUCK" or result=="BLOCKED" then
                self.routeRetries=(self.routeRetries or 0)+1
                self.adapter:stop("Retrying approach to committed prey")
                if self.routeRetries>=3 then
                    self:abandon(now,"NPC pursuit route failed repeatedly")
                    return "HUNT_REPLAN",self.lastResult
                end
            end
        end
        if self.repositionUntil and now>=self.repositionUntil then self.repositionUntil=nil end
        self.distance=d;self.preySpeed=speed
        return self.pending and "HUNT_VERIFY" or valid and "HUNT_ATTACK" or "HUNT_APPROACH",self.lastResult
    end
    function h:resume(delay)
        -- Manual intervention pauses a hunt; it does not blacklist its prey.
        for _,key in ipairs({"started","closingAt","noDamageAt","lastUsefulAt","blockedSince"}) do
            if self[key] then self[key]+=delay end
        end
        self.pending=nil;self.sample=nil;self.nextAttack=0
    end
    function h:status()
        return {attacks=self.attacks,hpDeclines=self.hits,misses=self.misses,
            result=self.lastResult,distance=self.distance,preySpeed=self.preySpeed,
            active=self.target~=nil,killsObserved=self.kills,blockedSince=self.blockedSince,
            committedSince=self.started,lastUsefulAt=self.lastUsefulAt,abandonReason=self.abandonReason,
            geometry=self.geometry,lastBlockedReason=self.lastBlockedReason,lastBlockedAt=self.lastBlockedAt,inputEvidence=self.inputEvidence}
    end
    return h
end
return Hunt
]============]
sources["amber_care"] = [============[
-- Feeding handshake and recovery. Native approach, active feeding and an input
-- request have distinct lifetimes; manual cancellation never leaves a stale latch.
local Care={}
local function finite(n)return type(n)=="number" and n==n and math.abs(n)<1e10 end
local function active(s,kind)
    return s.nativeFeedMode==kind or s.feedMode==kind or s.feedMode==true
end
local function meal(g,now)
    if not g.meal then g.meal={requests=0,at=now,progressAt=now} end
    return g.meal
end
function Care.interrupt(g,now)
    if not g or g.kind~="EAT" and g.kind~="DRINK" then return end
    local m=meal(g,now)
    m.interrupted=true;m.interruptedAt=now
end
function Care.requested(g,now)
    local m=meal(g,now)
    m.requests+=1;m.at=now;m.pending=true;m.owned=true
    m.interrupted=false;m.seenActive=false;m.progressAt=now
    g.feedPending=true;g.feedAt=now
end
function Care.resetSite(g,now)
    g.meal={requests=0,at=now,progressAt=now};g.feedPending=nil
    g.feedAt=nil;g.nextAction=now+.2;g.stopFeedRequested=nil
end
function Care.step(g,s,adapter)
    local now=s.now;local m=meal(g,now)
    local kind=g.kind=="DRINK" and "drink" or "eat"
    local value=kind=="drink" and s.thirst or s.hunger
    if not finite(value) or not finite(g.baseline) then return "FAILED","Native needs unavailable" end
    g.gain=value-g.baseline
    if m.value and value>m.value+.02 then m.progressAt=now;m.requests=0 end
    m.value=value
    local running=active(s,kind)
    local other=s.nativeFeedMode and s.nativeFeedMode~=kind
        or s.feedMode and s.feedMode~=false and s.feedMode~=kind and s.feedMode~=true
    if other then return "BUSY","Another native feeding session owns movement" end
    local idleKnown=s.nativeFeedKnown==true and s.nativeFeedMode==nil and not running
    if running then m.seenActive=true;m.interrupted=false end
    if m.interrupted and not running and now-(m.interruptedAt or now)>=.35
        and (idleKnown or now-(m.interruptedAt or now)>=1.1) then
        m.pending=false;m.interrupted=false;m.cancelAt=nil;m.requests=0
        g.feedPending=nil;g.feedAt=nil;g.arrivedAt=nil;g.stopFeedRequested=nil
        g.nextAction=now
    elseif m.pending and m.seenActive and not running then
        -- The native session ended below the care target: continue the same
        -- objective immediately, instead of waiting for a 14-second timeout.
        m.pending=false;m.seenActive=false;m.cancelAt=nil;g.feedPending=nil;g.nextAction=now+.2
    elseif m.pending and not running and now-m.at>=(idleKnown and .75 or 2.2) then
        m.pending=false;g.feedPending=nil;g.nextAction=now+.2
        if m.requests>=3 then return "RELOCATE","Native feed request was not acknowledged" end
    end
    local maximum=kind=="drink" and (s.thirstMax or 100) or (s.hungerMax or 100)
    if not finite(maximum) or maximum<=0 then return "FAILED","Native need maximum unavailable" end
    local target=kind=="drink" and math.min(s.drinkTarget or maximum,maximum)-maximum*.002 or math.min(s.careTarget or maximum*.72,maximum)
    if not finite(target) or target<=0 then return "FAILED","Native care target unavailable" end
    if value>=target and g.gain>math.min(.25,maximum*.002) then
        if running then
            m.fullAt=m.fullAt or now
            if m.owned and not m.cancelAt and adapter.cancelFeed then
                if adapter:cancelFeed(s) then m.cancelAt=now end
            end
            if m.owned and now-(m.cancelAt or m.fullAt)>2 then
                return "FAILED","Thirst or hunger recovered; native feeding release unconfirmed"
            end
            return "BUSY","Needs recovered; finishing native feeding"
        end
        return "COMPLETE",(kind=="drink" and "Thirst" or "Hunger").." actually increased"
    end
    if m.cancelAt then
        if not running and (idleKnown or now-m.cancelAt>.5) then
            m.pending=false;g.feedPending=nil;return "RELOCATE","Trying a fresh feed access"
        end
        if now-m.cancelAt>2 then return "FAILED","Native feeding cancellation unconfirmed" end
        return "BUSY","Releasing a stalled native feeding session"
    end
    if running and now-m.progressAt>5.5 then
        if m.owned and adapter.cancelFeed and adapter:cancelFeed(s) then
            m.cancelAt=now;return "BUSY","Restarting feeding after no resource progress"
        end
        if now-m.progressAt>8 then return "FAILED","Native feeding has no resource progress" end
    end
    if running then return "BUSY","Native feeding active; watching needs" end
    if m.pending then return "BUSY","Native feeding approach requested" end
    return "READY","Finding native "..kind.." access"
end
return Care
]============]
sources["amber_agent"] = [============[
-- One objective and one movement owner, with suspended territory and care latches.
local Agent={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e10 end
local function flat(a,b)
    if not a or not b then return math.huge end
    return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)
end
local function feeding(s,kind)
    return s.feedMode==kind or s.feedMode==true or s.nativeFeedMode==kind
end
function Agent.new(planner,adapter,Hunt,Care,Ledger)
    local a={planner=planner,adapter=adapter,Hunt=Hunt,Care=Care,enabled=false,phase="OFF",goal=nil,
        cooldown={},careCooldown={},recent={},waitingSince={},events={},ticks=0,earned=0,claimed=0,scented=0,
        feeds=0,hunts=0,failures=0,nextTick=0,reason="Disabled",generation=0,returns={},version="0.7.0"}
    a.metrics=Ledger and Ledger.new() or nil
    function a:selectTerritory(state,force)
        local hexes=self.adapter:territories(state)
        local byKey={}
        for _,hex in ipairs(hexes) do
            byKey[hex.key]=hex
            if self.planner.objective(hex,state,state.position,{blockedUntil=self.cooldown}) then self.waitingSince[hex.key]=self.waitingSince[hex.key] or state.now
            else self.waitingSince[hex.key]=nil end
        end
        local options={blockedUntil=self.cooldown,recent=self.recent,waitingSince=self.waitingSince,
            maxStops=6,regionCursor=self.regionCursor,regionDirection=self.regionDirection}
        if not force and self.itinerary then
            while #self.itinerary>0 do
                local item=self.itinerary[1]
                local fresh=self.planner.objective(byKey[item.key],state,state.position,options)
                if fresh then self.itinerary[1]=fresh;return self.itinerary,self.strategy end
                table.remove(self.itinerary,1)
            end
        end
        local route,strategy=self.planner.strategy(hexes,state,options)
        self.itinerary=route;self.strategy=strategy;self.regionCursor=strategy.cursor;self.regionDirection=strategy.direction or self.regionDirection
        if self.planner.capacity then self.capacity=self.planner.capacity(hexes,state,options) end
        return route,strategy
    end
    function a:log(at,kind,msg)
        table.insert(self.events,{at=math.floor(at*10)/10,kind=kind,msg=msg})
        if kind=="confirmed" or kind=="deferred" or kind=="failed" then self.lastNotice=msg end
        while #self.events>35 do table.remove(self.events,1) end
    end
    function a:setEnabled(on,now)
        local ownedFeed=self.enabled and self.goal and self.goal.feedPending
        self.generation+=1;self.enabled=on==true
        if not self.enabled then
            if self.metrics and self.metrics.run then self.metrics:sample(now or self.lastState and self.lastState.now or self.metrics.at,self.phase,self.phase=="PAUSED",false,self.goal,self.lastState,self.adapter.nav) end
            if self.adapter.recover then self.adapter:recover(self.lastState,false) end
            self.goal,self.suspended=nil,nil;self.returns={};self.itinerary=nil;self.phase="OFF";self.reason="Disabled"
            self.adapter:stop("disabled")
            if self.adapter.releaseInputs then self.adapter:releaseInputs() end
            if ownedFeed and self.lastState then
                if self.adapter.cancelFeed then self.adapter:cancelFeed(self.lastState) end
            end
        else
            self.nextTick=0;self.prevAmber=nil;self.needWindow={};self.needRates={};self.depletionProfiles={}
            self.itinerary=nil;self.regionCursor=nil;self.regionDirection=nil;self.earned=0;self.claimed=0;self.scented=0
            self.feeds,self.hunts,self.failures=0,0,0
            if self.metrics then self.metrics:start(now) end
            self.reason="Assessing animal and territory"
        end
    end
    function a:suspend(goal)
        if not goal or self.suspended==goal then return end
        if self.suspended then
            table.insert(self.returns,self.suspended)
            if #self.returns>3 then table.remove(self.returns,1) end
        end
        self.suspended=goal
    end
    function a:fail(state,reason)
        self.failures+=1;self.reason=reason
        if self.metrics then self.metrics:count("failure",reason) end
        if self.adapter.recover then self.adapter:recover(state,false) end
        local g=self.goal
        if g and g.kind=="TERRITORY" then self.cooldown[g.key]=state.now+90
        elseif g then self.careCooldown[g.kind]=state.now+2 end
        if g and g.kind=="DRINK" and self.adapter.avoidWater then self.adapter:avoidWater(g.location,state.now) end
        if g and g.food and g.food.model and self.adapter.foodBlocked then self.adapter.foodBlocked[g.food.model]=state.now+80 end
        self:log(state.now,"failed",reason);self.goal=nil
        self.adapter:stop(reason);self.phase="REPLAN"
    end
    function a:takeGoal(state,kind,target)
        self.adapter:stop("new goal")
        if kind~="RECOVER" and self.adapter.recover then self.adapter:recover(state,false) end
        self.objectiveSerial=(self.objectiveSerial or 0)+1
        self.goal={id=self.objectiveSerial,generation=self.generation,wallStart=state.now,
            kind=kind,key=target and target.key,detail=target,start=state.now,
            nextAction=0,tries=0,progressAt=state.now,
            baseline=kind=="DRINK" and state.thirst or kind=="EAT" and state.hunger or nil}
        self.phase="PREPARE_"..kind;self.reason="Starting "..kind
        self:log(state.now,"goal",kind..":"..tostring(target and target.key or "-"))
    end
    function a:resume(state)
        self.adapter:stop("care confirmed")
        if self.adapter.recover then self.adapter:recover(state,false) end
        local g=self.suspended;self.suspended=table.remove(self.returns)
        if g and g.kind=="TERRITORY" then
            local current=self.adapter:territory(g.key,state)
            local detail=current and self.planner.objective(current,state,state.position,{blockedUntil=self.cooldown})
            if detail then
                if state.travelCost then
                    local route,strategy=self.planner.strategy(self.adapter:territories(state),state,{blockedUntil=self.cooldown,regionCursor=self.regionCursor,maxStops=1})
                    local alternate=route[1]
                    if alternate and alternate.key~=g.key and (strategy.phase=="URGENT_SCENT"
                        or alternate.score>detail.score*1.8 and alternate.travelSeconds<detail.travelSeconds*.55) then
                        self.itinerary=nil;self.goal=nil;self.reason="Replanning after care changed the useful route"
                        return
                    end
                end
                g.start=state.now;g.progressAt=state.now;g.interactAt=nil
                g.detail=detail;g.finishUntil=nil;g.completeAt=nil;g.inHexProgressAt=nil
                self.goal=g;self.phase="RESUME";self.reason="Resuming "..g.key
                return
            end
        end
        self.goal=nil
        if self.suspended then self:resume(state) end
    end
    function a:status()
        local s=self.lastState or {}
        local g=self.goal
        return {metrics=self.metrics and self.metrics:summary(),capacity=self.capacity,decision=self.decision,version=self.version,enabled=self.enabled,phase=self.phase,reason=self.reason,
            kind=g and g.kind or "NONE",key=g and g.key,claimed=self.claimed,scented=self.scented,
            feeds=self.feeds,hunts=self.hunts,failures=self.failures,earned=self.earned,
            species=self.species,coat=self.coat,hunger=s.hunger,thirst=s.thirst,
            suspended=self.suspended and self.suspended.key,lastSuccess=self.lastSuccess,
            targetProgress=g and {action=g.detail and g.detail.kind,progress=g.lastProg,hold=g.lastHold,alternates=g.alternates,
                needBaseline=g.baseline,needGain=g.gain},hunt=g and g.hunt and g.hunt:status() or nil,
            lastHunt=self.lastHunt,returnDepth=#self.returns+(self.suspended and 1 or 0),
            survivalReserve={hunger=s.hungerReserve,thirst=s.thirstReserve},lastCare=self.lastCare,lastRouteFailure=self.lastRouteFailure,
            input=self.adapter.lastInput,error=self.lastError,strategy=self.strategy,deferred=self.deferred or 0,
            lastSkip=self.lastSkip,lastNotice=self.lastNotice,travelled=self.adapter.nav and self.adapter.nav.travelled,
            waitSeconds=self.goal and self.goal.interactAt and s.now-self.goal.interactAt or 0}
    end
    function a:pause(state,reason)
        self.pausedAt=self.pausedAt or state.now
        self.pauseManual=state.manualInput==true or state.gameMenu==true
        if self.Care then self.Care.interrupt(self.goal,state.now) end
        self.phase="PAUSED";self.reason=reason;self.adapter:stop(reason)
    end
    function a:tick(now)
        if not self.enabled or now<self.nextTick then return end
        self.nextTick=now+.15;self.ticks+=1
        if self.metrics then
            if not self.metrics.run then self.metrics:start(now) elseif not self.metrics.at then self.metrics.at=now;self.metrics.started=now end
            self.metrics:sample(now,self.phase,self.phase=="PAUSED" or self.phase=="WAIT",self.phase=="PAUSED" and self.pauseManual,self.goal,self.lastState,self.adapter.nav)
        end
        if not self.metrics and self.goal and self.phaseAt and self.phaseGoal==self.goal then
            self.goal.durations=self.goal.durations or {}
            self.goal.durations[self.phase]=(self.goal.durations[self.phase] or 0)+math.clamp(now-self.phaseAt,0,2)
        end
        self.phaseAt=now;self.phaseGoal=self.goal
        if self.adapter.prepare then self.adapter:prepare(now,true,self.goal) end
        local state=self.adapter:snapshot(now)
        if not state or not state.alive or not state.position then
            self.phase="WAIT";self.reason="Living animal unavailable"
            self.goal,self.suspended=nil,nil;self.returns={};self.itinerary=nil
            if self.adapter.recover then self.adapter:recover(state,false) end
            self.adapter:stop("despawn");return
        end
        state.now=now;self.lastState=state;self.species,self.coat=state.species,state.coat
        local changed=self.initialized and (self.lastCharacter~=state.char or self.lastPack~=state.pack
            or self.lastBiome~=state.biome or self.lastSpecies~=state.species or self.lastProfile~=state.profileKey
            or self.lastGeneration~=state.generation)
        if changed then
            self.goal,self.suspended=nil,nil;self.returns={};self.cooldown,self.recent,self.careCooldown={},{},{}
            self.waitingSince={};self.regionCursor=nil;self.regionDirection=nil;self.itinerary=nil
            self.needWindow={};self.needRates={};self.depletionProfiles={}
            self.prevAmber=nil
            self.adapter:stop("animal / pack / map changed")
            self.lastTerritoryKey=nil;self.pausedAt=nil
            self:log(now,"reset","Changed animal, pack or map")
        end
        self.initialized=true
        self.lastCharacter,self.lastPack,self.lastBiome,self.lastSpecies,self.lastProfile=state.char,state.pack,state.biome,state.species,state.profileKey
        self.lastGeneration=state.generation
        self.needRates=self.needRates or {}
        self.needWindow=self.needWindow or {}
        for _,key in ipairs({"hunger","thirst"}) do
            local sample,value=self.needWindow[key],state[key]
            if not finite(value) then self.needWindow[key]=nil
            elseif not sample or sample.char~=state.char or value>sample.value+.02 or now-sample.at>15 then
                self.needWindow[key]={char=state.char,at=now,value=value,mode=state.swimming and "swim" or state.hudBurst and "burst" or state.hudSprint and "sprint" or "ordinary"}
            elseif now-sample.at>=4 then
                -- Include idle samples between replicated resource updates;
                -- averaging only falling ticks exaggerates consumption.
                local rate=(sample.value-value)/(now-sample.at)
                if rate>=0 and rate<((state[key.."Max"] or 100)*.05) then
                    self.needRates[key]=(self.needRates[key] or rate)*.6+rate*.4
                    self.depletionProfiles=self.depletionProfiles or {}
                    self.depletionProfiles[key]=self.depletionProfiles[key] or {}
                    local modes=self.depletionProfiles[key];local mode=sample.mode or "ordinary"
                    modes[mode]={rate=rate,at=now}
                end
                self.needWindow[key]={char=state.char,at=now,value=value,mode=state.swimming and "swim" or state.hudBurst and "burst" or state.hudSprint and "sprint" or "ordinary"}
            end
        end
        for _,key in ipairs({"hunger","thirst"}) do
            local rate=self.needRates[key]
            for _,v in pairs(self.depletionProfiles and self.depletionProfiles[key] or {}) do
                if now-v.at<90 then rate=math.max(rate or 0,v.rate*.7) end
            end
            if finite(state[key]) and rate and rate>.001 then state[key.."Reserve"]=math.max(0,state[key]-(state[key.."Max"] or 100)*.12)/rate end
        end
        if self.metrics then self.metrics:currency(state.amber,state.char) end
        if self.planner.capacity and now>=(self.nextCapacityAt or 0) then
            self.nextCapacityAt=now+10
            self.capacity=self.planner.capacity(self.adapter:territories(state),state,{blockedUntil=self.cooldown})
        end
        if finite(state.amber) then
            if finite(self.prevAmber) and state.amber>self.prevAmber then self.earned+=state.amber-self.prevAmber end
            self.prevAmber=state.amber
        end
        if state.manualInput or state.gameMenu then
            if self.goal then self.goal.manualInterventionObserved=true end
            self:pause(state,"Manual movement, typing or native menu");return
        end
        local ownRecovery=self.goal and self.goal.kind=="RECOVER" and state.automaticRest==true
        if state.ability or state.pinned or state.resting and not ownRecovery or state.flying or state.climbing or state.rescuing then
            self:pause(state,"Native ability, capture, Rest, flight or climbing");return
        end
        if (feeding(state,"eat") or feeding(state,"drink")) and (not self.goal or self.goal.kind=="TERRITORY") then
            self:pause(state,"Native feeding owns movement");return
        end
        if state.underwater then self:pause(state,"Underwater route requires manual surface recovery");return end
        if state.combat and (not self.goal or self.goal.kind~="EAT") then self:pause(state,"Combat interruption");return end
        if self.pausedAt then
            if self.goal then
                local delay=now-self.pausedAt
                self.goal.start+=delay;self.goal.progressAt+=delay
                if self.goal.interactAt then self.goal.interactAt+=delay end
                if self.goal.hunt and self.goal.hunt.resume then self.goal.hunt:resume(delay) end
            end
            self.pausedAt=nil
        end
        state.recoveryStalled=self.goal and self.goal.kind=="RECOVER" and now-(self.goal.recoverProgressAt or self.goal.start)>20
        local decision=self.planner.decide and self.planner.decide(state) or {kind=self.planner.need(state)}
        self.decision=decision
        local need=decision.kind
        if need=="WAIT" then self:pause(state,decision.reason or "Native needs unavailable");return end
        if not self.goal and self.suspended and need=="TERRITORY" then self:resume(state) end
        local goal=self.goal
        if goal and goal.kind=="TERRITORY" and state.contested and state.contested[goal.key] then
            self.cooldown[goal.key]=now+15
            self.lastSkip="Non-pack player occupies "..goal.key
            self.deferred=(self.deferred or 0)+1
            self:log(now,"deferred",self.lastSkip)
            self.goal=nil;goal=nil
        end
        if self.suspended and state.contested and state.contested[self.suspended.key] then
            self.suspended=table.remove(self.returns)
        end
        local opportunistic=(not goal or goal.kind=="TERRITORY") and state.feedCan=="drink"
            and finite(state.thirst) and state.thirst<(state.thirstMax or 100)*.82
            and now-(self.lastFullDrinkAt or -100)>90
        if opportunistic and state.healthFraction>=.45 then need="DRINK" end
        -- Finish a progressing near-complete claim before routine care. A
        -- critical need, genuine contest or native interruption still wins.
        local protected=false
        if goal and goal.kind=="TERRITORY" and need~="TERRITORY" and not decision.critical then
            local t=self.adapter:territory(goal.key,state)
            local p=t and (goal.detail.kind=="SCENT" and t.hold or t.prog)
            if type(p)=="number" and p>=.72 and p<=1 and state.healthFraction>=.45
                and (state.hunger or 100)>(state.hungerMax or 100)*.19 and (state.thirst or 100)>(state.thirstMax or 100)*.19 then
                goal.finishUntil=goal.finishUntil or now+math.clamp((goal.detail.kind=="SCENT" and (state.refillTime or 60) or (state.claimTime or 20))*(1-p)+2,2,18)
                protected=now<goal.finishUntil and now-goal.progressAt<3
            end
        end
        if protected then need="TERRITORY" end
        -- Re-evaluate urgent scent during travel, without abandoning active or
        -- nearly finished work. Preserve the region cursor and return target.
        if goal and goal.kind=="TERRITORY" and need=="TERRITORY" and not self.suspended
            and not goal.nativeStarted and now>=(self.nextUrgentCheck or 0) then
            self.nextUrgentCheck=now+1
            local current=self.adapter:territory(goal.key,state)
            local almostDone=current and current.by==state.pack and finite(current.prog) and current.prog>=.72
            local urgentGoal=goal.detail.kind=="SCENT" and current and (finite(current.hold) and current.hold<.28 or goal.detail.slack and goal.detail.slack<45)
            local completed=current and (goal.detail.kind=="CLAIM" and current.owner==state.pack
                or goal.detail.kind=="SCENT" and current.hold and current.hold>=.985)
            if not completed and not almostDone and not urgentGoal and flat(state.position,goal.detail.center)>(state.claimRadius or 15) then
                local route,strategy=self.planner.strategy(self.adapter:territories(state),state,{
                    blockedUntil=self.cooldown,regionCursor=self.regionCursor,maxStops=1})
                if strategy.phase=="URGENT_SCENT" and route[1] and route[1].key~=goal.key then
                    self:suspend(goal);self.strategy=strategy
                    self:takeGoal(state,"TERRITORY",route[1]);goal=self.goal
                    self.reason="Maintaining critical scent before resuming the area sweep"
                end
            end
        end
        -- Care is latched to its completion target. Crossing its trigger does
        -- not cancel a native feeding session or lose the suspended territory.
        if goal and goal.kind=="RECOVER" and state.healthFraction>=.72 then
            self:resume(state);goal=self.goal
        end
        local urgent=decision.critical and decision.kind or nil
        -- A latched meal cannot ignore a different need becoming lethal.
        -- Cancel only our own native feeding session and wait for its release.
        local emergency=goal and (goal.kind=="EAT" or goal.kind=="DRINK") and urgent and urgent~=goal.kind
            and (urgent=="RECOVER" or urgent=="DRINK" and state.thirst<(state.thirstMax or 100)*.10
                or urgent=="EAT" and state.hunger<(state.hungerMax or 100)*.10) and urgent
        if emergency and goal.meal and goal.meal.owned then
            goal.emergencySince=goal.emergencySince or now
            if not feeding(state,"eat") and not feeding(state,"drink")
                and (state.nativeFeedKnown==true and not state.nativeFeedMode
                    or goal.emergencyStopAt and now-goal.emergencyStopAt>.75) then
                self:takeGoal(state,emergency);goal=self.goal;urgent=emergency;need=emergency
            else
                if not goal.emergencyStopAt and self.adapter.cancelFeed and self.adapter:cancelFeed(state) then
                    goal.emergencyStopAt=now
                end
                self.adapter:stop("Critical survival handoff")
                self.phase="VERIFY_FEED_RELEASE";self.reason="Releasing owned feeding for critical "..emergency
                if now-goal.emergencySince>3 then self:fail(state,"Critical feeding release unconfirmed") end
                return
            end
        end
        local switch=not goal or goal.kind=="TERRITORY" and need~="TERRITORY"
            or urgent and goal.kind~=urgent and not goal.feedPending and not feeding(state,"eat") and not feeding(state,"drink")
        if switch and need~="TERRITORY" and need~="WAIT" then
            local kind=urgent or need
            if (self.careCooldown[kind] or 0)>now then
                self.phase="WAIT_CARE";self.reason="Retrying another survival location shortly"
                self.adapter:stop("care retry cooldown");return
            end
            if goal and goal.kind=="TERRITORY" then self:suspend(goal) end
            self:takeGoal(state,kind);goal=self.goal
        end
        if not goal then
            if state.pack==nil then
                self.phase="WAIT";self.reason="Join a pack to claim or scent territory";self.adapter:stop("no pack");return
            end
            if now<(self.nextPlanAt or 0) then
                self.phase="WATCH";self.reason="Watching native scent and survival";self.adapter:stop("maintenance watch");return
            end
            local route,strategy=self:selectTerritory(state)
            if #route==0 then
                self.nextPlanAt=now+.8
                local exposed=state.currentHex and state.contested and state.contested[state.currentHex]
                local patrol=exposed and self.adapter.patrol and self.adapter:patrol(state)
                if patrol then
                    self.phase="PATROL";self.reason="Territories maintained; checking the next area"
                    self.adapter:move(patrol,state,{navKey="PATROL:"..tostring(patrol.key),moveRadius=12})
                else
                    self.phase="WATCH";self.reason="Territories maintained or deferred; watching native scent and survival"
                    self.adapter:stop("no available target")
                end
                return
            end
            self:takeGoal(state,"TERRITORY",route[1]);goal=self.goal
            self.lastTerritoryKey=goal.key
        end
        if goal.kind=="RECOVER" then
            local available=self.adapter.recover and self.adapter:recover(state,true)
            if not goal.recoverHP or state.healthFraction>goal.recoverHP+.001 then
                goal.recoverHP=state.healthFraction;goal.recoverProgressAt=now
            end
            self.phase="RECOVER";self.reason="Watching native out-of-combat HP recovery"
            if now-(goal.recoverProgressAt or goal.start)>20 then
                self.phase="WAIT_RECOVERY"
                self.reason=state.combat and "Recovery waits for native combat eligibility"
                    or "Recovery has no observed HP gain; rechecking native eligibility"
                goal.recoverChecks=(goal.recoverChecks or 0)+1
            end
            self.adapter:stop("low health");return
        end
        if goal.kind=="TERRITORY" then
            if state.pack==nil then self:fail(state,"Pack unavailable");return end
            local native=self.adapter:territory(goal.key,state)
            if not native or native.neutral then self:fail(state,"Territory missing or neutral");return end
            local owned=native.owner==state.pack
            local pendingClaim=owned and native.by==state.pack and finite(native.prog) and native.prog>.01 and native.prog<.995
            local done=goal.detail.kind=="CLAIM" and owned and not pendingClaim
                or goal.detail.kind=="SCENT" and owned and finite(native.hold) and native.hold>=.985
            if done then
                goal.completeAt=goal.completeAt or now
                -- Require the replicated completion to survive another native
                -- sample before departure. Ownership is not fabricated locally.
                if now-goal.completeAt<.45 then
                    self.adapter:stop("verifying territory completion")
                    self.phase="VERIFY_TERRITORY";self.reason="Checking stable native territory completion";return
                end
                if goal.detail.kind=="SCENT" then self.scented+=1 else self.claimed+=1 end
                if self.metrics then self.metrics:count("outcome",goal.nativeStarted and "local territory progress completed" or "pack territory completion observed") end
                self.recent[goal.key]=now;self.lastSuccess="Observed "..goal.detail.kind.." "..goal.key
                self.waitingSince[goal.key]=nil
                self:log(now,"confirmed",self.lastSuccess);self.adapter:stop("replicated complete")
                self.goal=nil;self.phase="CONFIRMED";self.reason=self.lastSuccess
                if self.suspended then self:resume(state) end
                return
            end
            goal.completeAt=nil
            local waypoint=self.adapter:territorySpot(goal.key,state)
            if not waypoint then self:fail(state,"No streamed native territory position");return end
            local progressing=finite(native.prog) and native.by==state.pack and finite(goal.lastProg) and native.prog>goal.lastProg+.002
                or owned and finite(native.hold) and finite(goal.lastHold) and native.hold>goal.lastHold+.002
            if progressing then goal.progressAt=now;goal.nativeStarted=true end
            goal.lastProg,goal.lastHold=native.prog,native.hold
            local inHex=state.currentHex==goal.key or not state.currentHex and flat(state.position,waypoint)<=(state.claimRadius or 15)
            if progressing and inHex then goal.inHexProgressAt=now end
            -- Replication arrives less often than this coordinator ticks. Stay
            -- put between progressing samples rather than restarting travel.
            local localProgress=inHex and (owned or native.by==state.pack)
                and goal.inHexProgressAt and now-goal.inHexProgressAt<2.5
            local outsideHex=state.currentHex~=nil and state.currentHex~=goal.key
            if outsideHex or flat(state.position,waypoint)>(waypoint.moveRadius or state.claimRadius or 15) and not localProgress then
                self.phase="TRAVEL";self.reason=goal.detail.kind.." "..goal.key
                local result=self.adapter:move(waypoint,state,{navKey="HEX:"..goal.key,costPurpose="HEX:"..goal.key,costPoint=goal.detail.center,moveRadius=waypoint.moveRadius or 10})
                if result=="STUCK" or result=="BLOCKED" then
                    goal.routeRetries=(goal.routeRetries or 0)+1
                    self.lastRouteFailure={key=goal.key,at=now,reason=self.adapter.motionReason,
                        navigation=self.adapter.nav and self.adapter.nav:status()}
                    self:log(now,"route_retry","Retrying approach "..goal.key.." ("..goal.routeRetries.."): "..tostring(self.adapter.motionReason or result))
                    self.adapter:advanceSpot(goal.key);self.adapter:stop("Alternative territory approach")
                    if goal.routeRetries>=3 then self:fail(state,"Territory route failed after three approach attempts") end
                elseif now-goal.start>240 then self:fail(state,"Territory travel budget exhausted") end
                return
            end
            self.adapter:stop("at territory")
            self.phase="CLAIMING";self.reason=goal.nativeStarted and "Native territory progress observed" or "Waiting for native claim/scent progress"
            if not goal.interactAt then goal.interactAt=now;goal.progressAt=now end
            local stall=now-goal.progressAt
            local stallLimit=goal.nativeStarted and math.max(4.5,(state.progressLatency or 1)*3) or 3.2
            if stall>stallLimit and (goal.alternates or 0)<3 then
                goal.alternates=(goal.alternates or 0)+1;goal.progressAt=now;goal.interactAt=now
                self.adapter:advanceSpot(goal.key);self.phase="REPOSITION"
                self.reason="Trying another surface position in "..goal.key
            elseif stall>6 or now-goal.interactAt>75 then self:fail(state,"No confirmed territory progress") end
            return
        end
        local kind=goal.kind=="DRINK" and "drink" or "eat"
        if (feeding(state,"eat") or feeding(state,"drink")) and not (goal.meal and goal.meal.owned) then
            goal.manualInterventionObserved=true
        end
        local careStatus,careReason=self.Care.step(goal,state,self.adapter)
        if careStatus=="COMPLETE" then
            if self.adapter.careObserved then self.adapter:careObserved(goal,state) end
            self.lastCare={kind=goal.kind,seconds=now-goal.start,wallSeconds=now-(goal.wallStart or goal.start),activeSeconds=goal.timing and goal.timing.active,
                pausedSeconds=goal.timing and goal.timing.paused,unobservedSeconds=goal.timing and goal.timing.unknown,
                phases=goal.timing and goal.timing.phases or goal.durations,gain=goal.gain,
                manualInterventionObserved=goal.manualInterventionObserved==true}
            if kind=="drink" then self.lastFullDrinkAt=now end
            if self.metrics then self.metrics:count("outcome",goal.manualInterventionObserved and "assisted care completed" or "unassisted care observed") end
            self.feeds+=1;self.lastSuccess=careReason.." (+"..string.format("%.1f",goal.gain)..")"
            self:log(now,"confirmed",self.lastSuccess);self.goal=nil;self:resume(state)
            if not self.goal then self.phase="CONFIRMED";self.reason=self.lastSuccess end
            return
        elseif careStatus=="BUSY" then
            self.adapter:stop("native feeding owns approach")
            self.phase=feeding(state,kind) and (kind=="drink" and "DRINKING" or "EATING") or "FEED_APPROACH"
            self.reason=careReason;return
        elseif careStatus=="FAILED" then self:fail(state,careReason);return
        elseif careStatus=="RELOCATE" then
            if kind=="drink" and self.adapter.avoidWater then self.adapter:avoidWater(goal.location or state.feedPosition or state.position,now) end
            if goal.food and goal.food.model and self.adapter.foodBlocked then self.adapter.foodBlocked[goal.food.model]=now+30 end
            goal.location,goal.arrivedAt,goal.food,goal.foodArrived=nil,nil,nil,nil
            self.Care.resetSite(goal,now)
            goal.siteFailures=(goal.siteFailures or 0)+1
            goal.feedBlockedUntil=now+1.5
            if goal.siteFailures>=3 then self:fail(state,careReason);return end
        end
        if state.feedCan==kind and now>=(goal.feedBlockedUntil or 0) then
            self.adapter:stop("native feed offer")
            if now<goal.nextAction then return end
            local sent=self.adapter:feed(state,kind)
            goal.tries+=1;goal.nextAction=now+1
            if sent then self.Care.requested(goal,now) end
            self.phase=kind=="drink" and "DRINKING" or "EATING"
            self.reason=sent and "Feed input requested; watching native approach and need" or "Feed input unavailable"
            if not sent and goal.tries>=3 then self:fail(state,"Native feed input unavailable") end
            return
        end
        local usefulHunt=goal.hunt and goal.hunt.lastUsefulAt and now-goal.hunt.lastUsefulAt<12
        if now-goal.start>150 and not usefulHunt then self:fail(state,"Survival objective timed out without useful progress");return end
        if kind=="drink" then
            if not goal.location then goal.location=self.adapter:water(state);goal.locationAt=now end
            if not goal.location then
                local search=self.adapter.resourceSearch and self.adapter:resourceSearch(state,"WATER")
                if search then
                    self.phase="SEARCH_WATER";self.reason="Checking another area for native water access"
                    self.adapter:move(search,state,{navKey="WATER_SCOUT",moveRadius=10})
                else
                    self.phase="WAIT_WATER";self.reason="No streamed water access found";self.adapter:stop("no water")
                end
                return
            end
            if now-(goal.waterRefreshAt or 0)>1.5 and self.adapter.waterEvidence=="LANDMARK_APPROACH" then
                goal.waterRefreshAt=now
                local refined=self.adapter:water(state)
                if refined and flat(refined,goal.location)>5 then goal.location=refined;goal.arrivedAt=nil end
            end
            local d=flat(state.position,goal.location)
            if d<110 and self.adapter.waterEvidence=="LANDMARK_APPROACH" and now-(goal.refinedAt or 0)>3 then
                goal.refinedAt=now
                self.adapter.waterCache=nil
                local refined=self.adapter:water(state)
                if refined and flat(refined,goal.location)>5 then goal.location=refined;goal.arrivedAt=nil end
                d=flat(state.position,goal.location)
            end
            if d<6 and not goal.arrivedAt then goal.arrivedAt=now end
            if goal.arrivedAt and now-goal.arrivedAt>1.8 then
                if self.adapter.avoidWater then self.adapter:avoidWater(goal.location,now) end
                goal.location=nil;goal.arrivedAt=nil;goal.waterRetries=(goal.waterRetries or 0)+1
                if goal.waterRetries>=4 then self:fail(state,"No native drinking offer at sampled water access") end
                return
            end
            self.phase="TRAVEL_WATER";self.reason="Approaching observed water access"
            local result=self.adapter:move(goal.location,state,{navKey="WATER:"..tostring(goal.locationAt),moveRadius=4})
            if result=="STUCK" then
                if self.adapter.avoidWater then self.adapter:avoidWater(goal.location,now) end
                goal.location=nil;goal.arrivedAt=nil
            end
            return
        end
        local food=self.adapter.food and self.adapter:food(state,goal.food)
        if food and self.adapter.mealChoice then food=self.adapter:mealChoice(state,food,goal.hunt) end
        if food then
            if not goal.food or goal.food.model~=food.model then goal.foodArrived=nil end
            goal.food=food;self.phase="TRAVEL_FOOD";self.reason="Approaching native edible food"
            local result=self.adapter:move(food.position,state,{navKey=food.model or "FOOD",moveRadius=2})
            if result=="REACHED" then goal.foodArrived=goal.foodArrived or now end
            if result=="STUCK" or goal.foodArrived and now-goal.foodArrived>2.5 then
                if food.model and self.adapter.foodBlocked then self.adapter.foodBlocked[food.model]=now+80 end
                goal.food=nil;goal.foodArrived=nil
            end
            return
        end
        if state.healthFraction<.42 then
            local search=self.adapter.resourceSearch and self.adapter:resourceSearch(state,"FOOD")
            if search then
                self.phase="SEARCH_FOOD";self.reason="Seeking edible food without risking a hunt"
                self.adapter:move(search,state,{navKey="LOW_HP_FOOD",moveRadius=10})
            else
                self.phase="WAIT_FOOD";self.reason="Health too low to hunt; watching edible food offers"
                self.adapter:stop("low health excludes hunt")
            end
            return
        end
        if not goal.hunt and self.Hunt then goal.hunt=self.Hunt.new(self.adapter) end
        if not goal.hunt then self.phase="WAIT_FOOD";self.reason="Hunting controller unavailable";self.adapter:stop("no hunter");return end
        if goal.hunt.corpse then
            local corpse=goal.hunt.corpse
            if now-corpse.at<10 then
                self.phase="WAIT_FOOD";self.reason="Prey HP reached zero; locating native edible food"
                self.adapter:move(corpse.position,state,{navKey="CORPSE",moveRadius=2});return
            else goal.hunt.corpse=nil end
        end
        self.phase,self.reason=goal.hunt:tick(state)
        if (self.phase=="WAIT_FOOD" or self.phase=="HUNT_REPLAN" or self.phase=="HUNT_SEARCH") and self.adapter.resourceSearch then
            local search=self.adapter:resourceSearch(state,"FOOD")
            if search then
                self.adapter:move(search,state,{navKey="FOOD_SCOUT",moveRadius=10,hunting=true})
                self.phase="SEARCH_FOOD";self.reason="Searching another area for edible food or suitable NPC prey"
            end
        end
        self.lastHunt=goal.hunt:status();self.lastHunt.at=now;self.lastHunt.active=false;self.lastHunt.retained=true
        if goal.hunt.kills>(goal.observedKills or 0) then
            self.hunts+=goal.hunt.kills-(goal.observedKills or 0);goal.observedKills=goal.hunt.kills
        end
    end
    return a
end
return Agent
]============]
sources["amber_bridge"] = [============[
-- Native FERAL data boundary; shared logic does not imply every mode is supported.
-- No PivotTo, CFrame teleport, direct resource writes, or fabricated rewards.
local Bridge={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e10 end
local function point(p) return {x=p.X,z=p.Z} end
local function dist(a,b)
    local dx,dz=a.x-b.x,a.z-b.z
    return math.sqrt(dx*dx+dz*dz)
end
function Bridge.new(nav)
    local Players=game:GetService("Players")
    local Rep=game:GetService("ReplicatedStorage")
    local Workspace=game:GetService("Workspace")
    local UserInput=game:GetService("UserInputService")
    local player=assert(Players.LocalPlayer,"No local player")
    local b={player=player,Players=Players,Rep=Rep,Workspace=Workspace,
        UserInput=UserInput,nav=nav,hexes={},hexByKey={},
        cfg=nil,spots=nil,territoryInstance=nil,refreshAt=0,lastString=nil,
        lastBiome=nil,motionReason="Idle",manualUncertain=false,spotCache={},spotTry={},
        configs={},waterBlocked={},preyBlocked=setmetatable({},{__mode="k"}),foodBlocked=setmetatable({},{__mode="k"}),
        connections={},inputEpoch=0,territorySamples={},operations={surface=0,food=0,prey=0},synthetic={},generation=0,
        coverage={},coverageOrder={},nativeCosts={}}
    local world=Rep:FindFirstChild("FeralWorld")
    local function config(name)
        if b.configs[name] then return b.configs[name] end
        local module=world and world:FindFirstChild(name)
        if not module or not module:IsA("ModuleScript") then return nil end
        local ok,value=pcall(require,module)
        if ok and type(value)=="table" then b.configs[name]=value;return value end
        return nil
    end
    b.config=config
    local function measured(name,fn,...)
        local started=os.clock();local result=table.pack(pcall(fn,...))
        local elapsed=math.max(0,os.clock()-started)
        local cost=b.nativeCosts[name] or {calls=0,total=0,max=0};b.nativeCosts[name]=cost
        cost.calls+=1;cost.total+=elapsed;cost.max=math.max(cost.max,elapsed)
        return table.unpack(result,1,result.n)
    end
    function b:hub()
        local h=self.ownerHub or (type(getgenv)=="function" and getgenv() or _G).FERAL_RENAISSANCE_ACTIVE
        return type(h)=="table" and not h.closed and h.bridge and h.bridge.player==player and h or nil
    end
    function b:recover(state,on)
        local h=self:hub()
        if not h then return false end
        if on then h.territoryRecoveryOwner=self
        elseif h.territoryRecoveryOwner==self then
            h.territoryRecoveryOwner=nil
            if h.recovery and not h.registry.byId.recovery.requested then h.recovery:release("Territory recovery ended",state and state.now or os.clock()) end
        end
        return on and h.recovery~=nil
    end
    function b:resetDiscovery(identity)
        local same=self.identity~=nil
        for _,key in ipairs({"char","root","profile","pack","biome","territory","world"}) do if not self.identity or self.identity[key]~=identity[key] then same=false;break end end
        if same then return end
        self.identity=identity;self.generation+=1
        self.spotCache,self.spotTry,self.territorySamples={},{},{}
        self.waterBlocked={};self.preyBlocked=setmetatable({},{__mode="k"});self.foodBlocked=setmetatable({},{__mode="k"})
        for _,name in ipairs({"waterCache","waterScan","waterMissUntil","waterAt","searchPoint","searchVisits","searchUntil",
            "patrolTarget","patrolVisits","patrolUntil","foodIndex","preyIndex","foodBest","preyBest","lastAttackInput","attackCharacter","foodETA","drinkETA","foodObserved","drinkObserved"}) do self[name]=nil end
        self.nav.recoveryCells={};self.nav.trajectory={};self.nav.surfaceCache={}
        self:releaseInputs();self:recover(nil,false)
        if self.nav.model then self.nav.model:reset(identity) end
    end
    function b:prepare(now,enabled,goal)
        local h=self:hub()
        if not enabled or not h then return end
        if h.walk and type(h.stopWalk)=="function" then h:stopWalk("Amber movement owner") end
        h.nextWalk=now+90
        -- Coordinate with existing recovery instead of letting it start Rest
        -- during travel, feeding approach or hunt preparation.
        local recovering=goal and goal.kind=="RECOVER"
        self:recover({now=now},recovering==true)
        if recovering and h.recovery and h.recovery.owned==player.Character
            and not (h.policy and h.policy.manualRest) then
            local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            recovering=not (hum and hum.MaxHealth>0 and hum.Health/hum.MaxHealth>=.72)
        end
        if not recovering then
            if h.policy then h.policy.actionUntil=math.max(h.policy.actionUntil or 0,now+.6) end
            if h.recovery and type(h.recovery.release)=="function" then h.recovery:release("Amber objective",now) end
        end
    end
    b.cfg=config("TerritoryConfig")
    b.spots=config("MapSpots")
    b.territoryInstance=Rep:FindFirstChild("FeralTerritory")
    local function attr(object,key)
        if not object then return nil end
        local ok,value=pcall(function() return object:GetAttribute(key) end)
        if ok then return value end
        return nil
    end
    local function validAnimal()
        local c=player.Character
        local h=c and c:FindFirstChildOfClass("Humanoid")
        local r=c and c:FindFirstChild("HumanoidRootPart")
        return c,h,r
    end
    local function fullStats(c)
        local sp=attr(c,"Species")
        local coat=attr(c,"Coat") or attr(c,"CoatId") or attr(c,"Skin")
            or attr(player,"Coat")
        return sp,coat
    end
    local function packKey(value)
        if value==nil or value==false or value==0 or value=="0" or value=="" or value=="None" then return nil end
        return tostring(value)
    end
    function b:hexAt(position)
        if not self.cfg or type(self.cfg.hexAt)~="function" or not position then return nil end
        local ok,i,j=pcall(self.cfg.hexAt,position.x,position.z)
        if not ok then return nil end
        if type(self.cfg.hexKey)=="function" then
            local good,key=pcall(self.cfg.hexKey,i,j)
            if good then return key end
        end
        return "H"..tostring(i).."_"..tostring(j)
    end
    function b:otherPlayerPositions()
        local all,occupied={},{}
        local mine=packKey(attr(player,"FeralPack"))
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player then
                local c=p.Character
                local root=c and c:FindFirstChild("HumanoidRootPart")
                local theirs=packKey(attr(p,"FeralPack") or attr(c,"FeralPack"))
                local same=mine~=nil and theirs==mine
                if root and not same then
                    local pos=point(root.Position);pos.hex=self:hexAt(pos)
                    table.insert(all,pos)
                    if pos.hex then occupied[pos.hex]=(occupied[pos.hex] or 0)+1 end
                end
            end
        end
        return all,occupied
    end
    function b:refresh(now)
        local currentWorld=Rep:FindFirstChild("FeralWorld")
        if currentWorld~=world then world=currentWorld;self.configs={};self.cfg=nil;self.spots=nil;self.lastString=nil end
        local currentTerritory=Rep:FindFirstChild("FeralTerritory")
        if currentTerritory~=self.territoryInstance then self.territoryInstance=currentTerritory;self.lastString=nil end
        if not self.cfg or not self.territoryInstance then
            world=Rep:FindFirstChild("FeralWorld")
            self.cfg=config("TerritoryConfig")
            self.spots=config("MapSpots")
            self.territoryInstance=Rep:FindFirstChild("FeralTerritory")
            if not self.cfg or not self.territoryInstance then return end
        end
        self.spots=self.spots or config("MapSpots")
        local text=attr(self.territoryInstance,"Hexes")
        local biome=attr(Workspace,"FeralBiome") or "WolfValley"
        if type(text)~="string" or #text==0 or type(self.cfg.parseHexes)~="function"
            or type(self.cfg.hexCenter)~="function" then return end
        if text==self.lastString and biome==self.lastBiome then return end
        local ok,parsed=pcall(self.cfg.parseHexes,text)
        if not ok or type(parsed)~="table" then return end
        self.lastString,self.lastBiome=text,biome
        self.spotCache,self.spotTry={},{}
        local hexes,byKey={},{}
        for _,t in ipairs(parsed) do
            if type(t.key)=="string" and type(t.i)=="number" and type(t.j)=="number" then
                local good,p=pcall(self.cfg.hexCenter,t.i,t.j)
                if good and p and ((typeof(p)=="Vector2")
                    or (type(p)=="table" and finite(p.X) and finite(p.Y))) then
                    local h={key=t.key,center={x=p.X,z=p.Y}}
                    if type(self.cfg.regionCell)=="function" then
                        local valid,region=pcall(self.cfg.regionCell,p.X,p.Y)
                        if valid and finite(region) then h.region=region end
                    end
                    table.insert(hexes,h);byKey[t.key]=h
                end
            end
        end
        local landmarks=self.spots and self.spots[biome]
        if type(landmarks)=="table" and type(self.cfg.hexAt)=="function" then
            for _,spot in ipairs(landmarks) do
                if typeof(spot.pos)=="Vector2" then
                    local good,i,j=pcall(self.cfg.hexAt,spot.pos.X,spot.pos.Y)
                    if good then
                        local key=type(self.cfg.hexKey)=="function"
                            and self.cfg.hexKey(i,j) or ("H"..tostring(i).."_"..tostring(j))
                        local h=byKey[key]
                        if h and not h.spot then h.spot={x=spot.pos.X,z=spot.pos.Y} end
                    end
                end
            end
        end
        self.hexes,self.hexByKey=hexes,byKey
    end
    local function terrAttr(key,suffix)
        local t=b.territoryInstance
        return attr(t,key.."_"..suffix)
    end
    function b:territory(key)
        if not self.territoryInstance then return nil end
        local h=self.hexByKey[key]
        if not h then return nil end
        local pay=terrAttr(key,"pay") or terrAttr(key,"income") or terrAttr(key,"amber")
        local owner,by=terrAttr(key,"owner"),terrAttr(key,"by")
        local mine=attr(player,"FeralPack")
        if packKey(owner) and packKey(owner)==packKey(mine) then owner=mine end
        if packKey(by) and packKey(by)==packKey(mine) then by=mine end
        local hold,prog=terrAttr(key,"hold"),terrAttr(key,"prog")
        local now=self.observationNow or os.clock();local sample=self.territorySamples[key]
        if not sample or sample.owner~=owner then
            sample={owner=owner,hold=hold,prog=prog,at=now};self.territorySamples[key]=sample
        elseif now>sample.at+.2 and finite(hold) and finite(sample.hold) and hold~=sample.hold then
            local dt=now-sample.at;local rate=(sample.hold-hold)/dt
            if rate>0 and rate<.1 then sample.decay=sample.decay and sample.decay*.6+rate*.4 or rate end
            if hold>sample.hold and dt<8 then self.progressLatency=(self.progressLatency or dt)*.7+dt*.3 end
            sample.hold=hold;sample.at=now
        end
        return {key=key,neutral=terrAttr(key,"neutral")==true or self.cfg and self.cfg.ON==false,
            owner=owner,by=by,prog=prog,hold=hold,
            pay=finite(pay) and pay or nil,deadlineSeconds=sample.decay and finite(hold) and math.max(0,hold-.08)/sample.decay or nil,
            fade=terrAttr(key,"fade"),center=h.center,spot=h.spot,region=h.region}
    end
    function b:territories(state)
        self:refresh(state.now)
        local list={}
        for _,h in ipairs(self.hexes) do
            local t=self:territory(h.key)
            if t then table.insert(list,t) end
        end
        return list
    end
    function b:counts(state)
        local pack=state and state.pack or attr(player,"FeralPack")
        local result={total=0,eligible=0,neutral=0,owned=0,other=0,fading=0}
        for _,hex in ipairs(self:territories(state or {now=os.clock()})) do
            result.total+=1
            if hex.neutral then
                result.neutral+=1
            else
                result.eligible+=1
                if pack~=nil and hex.owner==pack then
                    result.owned+=1
                    if finite(hex.hold) and hex.hold<.84 then result.fading+=1 end
                else result.other+=1 end
            end
        end
        return result
    end
    local function groundAt(x,z,c)
        local root=c and c:FindFirstChild("HumanoidRootPart")
        if root and type(b.nav.surface)=="function" then
            return b.nav:surface(Vector3.new(x,root.Position.Y,z),c,false)
        end
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={c}
        params.IgnoreWater=false
        local hit=Workspace:Raycast(Vector3.new(x,2200,z),Vector3.new(0,-4400,0),params)
        if hit and hit.Material~=Enum.Material.Water and hit.Normal.Y>.5 then
            return hit.Position+Vector3.new(0,2.5,0)
        end
        return nil
    end
    -- Native hex geometry contains the entire territory pool; MapSpots is
    -- supplemental, not a whitelist. Sample walkable ground inside each hex,
    -- favouring genuine named claim zones where one exists.
    function b:territorySpot(key,state)
        local h=self.hexByKey[key]
        if not h then return nil end
        -- Distant hex terrain is commonly unstreamed in Roblox. Travel toward
        -- the replicated geometry first; only demand a physical claim spot
        -- after the animal is near enough for the terrain to stream in.
        local origin=state and state.position
        if origin and dist(origin,h.spot or h.center)>210 then
            return h.spot or h.center
        end
        local cached=self.spotCache[key]
        if cached and (self.spotTry[key] or 0)==cached.index and (state.now or 0)-(cached.at or 0)<8 then
            local safe=true
            for _,p in ipairs(state.players or {}) do if dist(cached.pos,p)<(state.avoidRadius or 35) then safe=false end end
            if safe then return cached.pos end
        end
        local c=player.Character
        local focus=h.spot or h.center
        local candidate={}
        local attempt=self.spotTry[key] or 0
        if origin and attempt==0 then
            if self:hexAt(origin)==key and dist(origin,focus)<(self.cfg.CLAIM_RADIUS or 120)-8 then table.insert(candidate,origin) end
            local d=dist(origin,focus)
            local margin=math.max(10,state.root and state.root.Size.X or 10)
            local radius=math.max(8,(self.cfg.CLAIM_RADIUS or 120)-margin)
            if d>radius then
                table.insert(candidate,{x=focus.x+(origin.x-focus.x)/d*radius,z=focus.z+(origin.z-focus.z)/d*radius})
            end
        end
        table.insert(candidate,focus)

        local ring={12,25,40,57,75}
        for _,radius in ipairs(ring) do
            for direction=0,11 do
                local angle=direction*math.pi/6
                table.insert(candidate,{x=focus.x+math.cos(angle)*radius,
                    z=focus.z+math.sin(angle)*radius})
            end
        end
        if h.spot then table.insert(candidate,h.center) end
        -- Broad fallback candidates are evaluated in rank order and stop once
        -- a useful distinct access exists; no whole ring scan on every visit.
        local native=self.cfg
        local previous=cached and cached.pos
        local viable={}
        local checks=0
        for index,p in ipairs(candidate) do
            local matching=true
            if attempt>0 and index<=attempt then matching=false end
            if previous and attempt>0 and dist(previous,p)<18 then matching=false end
            if matching and type(native.hexAt)=="function" then
                local ok,i,j=pcall(native.hexAt,p.x,p.z)
                if not ok then matching=false else
                    local hexKey
                    if type(native.hexKey)=="function" then
                        local good,keyResult=pcall(native.hexKey,i,j)
                        if good then hexKey=keyResult end
                    else
                        hexKey="H"..tostring(i).."_"..tostring(j)
                    end
                    matching=hexKey==key
                end
            end
            if matching and (not h.spot or dist(p,h.spot)<math.max(10,(self.cfg.CLAIM_RADIUS or 120)-12)) then
                checks+=1
                local ground=groundAt(p.x,p.z,c)
                if ground then
                    local q=point(ground);q.moveRadius=3
                    local clear=true
                    for _,other in ipairs(state and state.players or {}) do
                        if dist(q,other)<(state.avoidRadius or 110) then clear=false;break end
                    end
                    if clear then table.insert(viable,q);break end
                end
            end
            if checks>=12 then break end
        end
        self.operations.spotChecks=checks
        if #viable==0 then return nil end
        -- Walkable alternative landing slots are used only after a genuine
        -- no-progress timeout, never to teleport or change hex ownership.
        local index=1
        local position=viable[index]
        self.spotCache[key]={index=self.spotTry[key] or 0,pos=position,at=state.now or 0}
        return position
    end
    function b:advanceSpot(key)
        if not self.hexByKey[key] then return end
        self.spotTry[key]=math.min(3,(self.spotTry[key] or 0)+1)
    end
    function b:manualInput()
        if os.clock()<(self.manualUntil or 0) then return true end
        if UserInput:GetFocusedTextBox() then return true end
        if type(UserInput.IsMouseButtonPressed)=="function" and Enum.UserInputType then
            local ok,down=pcall(UserInput.IsMouseButtonPressed,UserInput,Enum.UserInputType.MouseButton1)
            if ok and down and not (self.pendingInputs and self.pendingInputs.M1) then return true end
        end
        for _,name in ipairs({"W","A","S","D","Up","Down","Left","Right","Space"}) do
            local key=Enum.KeyCode[name]
            if key then
                local ok,down=pcall(UserInput.IsKeyDown,UserInput,key)
                if ok and down and not self.nav.held[name] then return true end
            end
        end
        return false
    end
    local function safePosition(p,state,radius)
        for _,other in ipairs(state.players or {}) do
            if dist(p,other)<(radius or state.avoidRadius or 110) then return false end
        end
        return true
    end
    local function surfaceAt(x,z,state,waterAllowed)
        b.operations.surface+=1
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={state.char};params.IgnoreWater=false;params.RespectCanCollide=true
        local hit=Workspace:Raycast(Vector3.new(x,state.root.Position.Y+120,z),Vector3.new(0,-460,0),params)
        if not hit then return nil end
        local water=hit.Material==Enum.Material.Water
        if water and not waterAllowed or not water and hit.Normal.Y<.5 then return nil end
        return point(hit.Position),water
    end
    function b:avoidWater(position,now)
        if position then
            local key=string.format("%d:%d",math.floor(position.x/12),math.floor(position.z/12))
            self.waterBlocked[key]=now+90
        end
        self.waterCache=nil;self.waterAt=0;self.waterScan=nil;self.waterMissUntil=nil
    end
    function b:water(state)
        local best,score=nil,math.huge
        local coarse,coarseDistance=nil,math.huge
        local function consider(candidate)
            local key=string.format("%d:%d",math.floor(candidate.x/12),math.floor(candidate.z/12))
            if (self.waterBlocked[key] or 0)>state.now or not safePosition(candidate,state,120) then return end
            local d=dist(candidate,state.position)
            if d<score then best,score=candidate,d end
        end
        -- FeedCanPos is the real current native offer, not a guessed landmark.
        if state.feedCan=="drink" and state.feedPosition then consider(state.feedPosition) end
        local finder=config("FeedFinder")
        local needs=config("NeedsConfig")
        if finder and type(finder.waterAround)=="function" then
            local ok,p=measured("FeedFinder.waterAround",finder.waterAround,state.char,state.root,needs and needs.WATER_PROMPT_PROBES)
            if ok and typeof(p)=="Vector3" then consider(point(p)) end
        end
        if best then
            self.waterEvidence="NATIVE_OFFER";self.waterCache,self.waterAt=best,state.now;return best
        end
        if self.waterCache and state.now<(self.waterAt or 0)+3 then return self.waterCache end
        if self.waterMissUntil and state.now<self.waterMissUntil then return nil end
        -- Find actual nearby terrain water. Also sample progressively larger
        -- landmark rings: a lake's centre is not necessarily its shoreline.
        local origins={{x=state.position.x,z=state.position.z,rings={10,24,48,90,150}}}
        local biome=state.biome
        local spots=self.spots and self.spots[biome]
        for _,spot in ipairs(type(spots)=="table" and spots or {}) do
            local name=string.lower(tostring(spot.key or spot.name or ""))
            if typeof(spot.pos)=="Vector2" and (spot.drinkR or name:find("water",1,true)
                or name:find("lake",1,true) or name:find("pond",1,true) or name:find("river",1,true)
                or name:find("creek",1,true) or name:find("marsh",1,true) or name:find("fall",1,true)) then
                table.insert(origins,{x=spot.pos.X,z=spot.pos.Y,rings={0,30,80,160,spot.drinkR or 240}})
                local p={x=spot.pos.X,z=spot.pos.Y}
                local d=dist(p,state.position)
                local key=string.format("%d:%d",math.floor(p.x/12),math.floor(p.z/12))
                if d<coarseDistance and safePosition(p,state,120) and (self.waterBlocked[key] or 0)<=state.now then
                    coarse,coarseDistance=p,d
                end
            end
        end
        table.sort(origins,function(a,b)return dist(a,state.position)<dist(b,state.position)end)
        local scan=self.waterScan
        if not scan or scan.char~=state.char or scan.biome~=state.biome
            or state.now-scan.at>6 or dist(scan.position,state.position)>100 then
            scan={at=state.now,char=state.char,biome=state.biome,position={x=state.position.x,z=state.position.z},points={},index=1}
            for _,origin in ipairs(origins) do
                for _,radius in ipairs(origin.rings) do
                    for k=0,(radius==0 and 0 or 7) do
                        local a=k*math.pi/4
                        table.insert(scan.points,{x=origin.x+math.cos(a)*radius,z=origin.z+math.sin(a)*radius,
                            dx=math.cos(a),dz=math.sin(a)})
                    end
                end
            end
            self.waterScan=scan
        end
        -- Bound terrain work per coordinator tick. Resume unfinished searches
        -- instead of repeating the whole map scan after an empty result.
        local stop=math.min(#scan.points,scan.index+23)
        for index=scan.index,stop do
            local probe=scan.points[index]
            local x,z=probe.x,probe.z
            local pos,wet=surfaceAt(x,z,state,true)
            if pos and wet then
                consider(pos)
                for _,reach in ipairs({7,15}) do
                    local bank=surfaceAt(x-probe.dx*reach,z-probe.dz*reach,state,false)
                    if bank and dist(bank,pos)<=reach+1 then consider(bank) end
                end
            end
        end
        scan.index=stop+1
        if scan.index>#scan.points then
            self.waterScan=nil;self.waterMissUntil=state.now+1.2
        end
        self.waterEvidence=best and "TERRAIN_OR_NATIVE_OFFER" or coarse and "LANDMARK_APPROACH" or "NONE"
        self.waterCache,self.waterAt=best or coarse,state.now
        if self.waterCache then self.drinkETA=(state.travelCost and state.travelCost(state.position,self.waterCache) or dist(state.position,self.waterCache)/24)+12 end
        return self.waterCache
    end
    function b:profile(char,species)
        local cfg=config("Species")
        local known=cfg and cfg.List and cfg.List[species]
        if not known then return {known=false,hunts=false,swim=false,support="unknown species profile"} end
        local forage=config("Forage")
        local hunts=known.diet=="carnivore" or known.diet=="omnivore"
        if forage and type(forage.canEat)=="function" then
            local ok,value=pcall(forage.canEat,known.diet,"meat")
            if ok then hunts=value==true end
        end
        local needs=config("NeedsConfig")
        local gaits
        if game.PlaceVersion==2412 and type(cfg.scaled)=="function" then
            local growth=attr(char,"Growth") or 1
            local ok,speed=pcall(cfg.scaled,species,"speed",growth)
            local valid,gait=pcall(cfg.scaled,species,"gait",growth)
            local walk=known.walkMul or 1
            if type(known.walkMulStage)=="table" and type(cfg.stage)=="function" then
                local good,stage=pcall(cfg.stage,growth,species)
                if good then walk=known.walkMulStage[stage] or walk end
            end
            local scale=attr(char,"SpeedScale") or attr(char,"MoveScale") or 1
            if ok and valid and finite(speed) and finite(gait) and finite(walk) and finite(scale) then
                local run=needs and needs.RUN_SPEED or 1
                local burst=needs and needs.BURST
                if finite(run) and run>0 then
                    gaits={WALK=7/42*gait*walk*scale,TROT=16.8/42*gait*walk*scale,SPRINT=speed*run*scale}
                    if burst and burst.ENABLED==true and finite(burst.SPEED) and burst.SPEED>=1 and burst.SPEED<=3 then gaits.BURST=gaits.SPRINT*burst.SPEED end
                end
            end
        end
        local surfaceSwim=known.swim~=false and (finite(known.swimSprint) and known.swimSprint>0
            or finite(known.swim) and known.swim>0 or needs and finite(needs.SWIM_SPEED) and needs.SWIM_SPEED>0)
        return {known=true,diet=known.diet,gaits=gaits,swim=surfaceSwim==true,support="ground and configured surface swimming; aerial/depth/climb routing unverified",swimSprint=finite(known.swimSprint) and known.swimSprint>0,
            hunts=hunts,
            native=known}
    end
    function b:recordCoverage(profile,species,profileKey,biome,now)
        local key=tostring(game.PlaceVersion)..":"..tostring(species)..":"..tostring(biome)..":"..tostring(profile.diet)
        local item=self.coverage[key]
        if not item then
            item={gameVersion=game.PlaceVersion,species=species,biome=biome,diet=profile.diet,firstSeen=now,
                status=profile.known and "PARTIAL" or "UNKNOWN",
                ground=profile.known and "implemented; live acceptance unverified" or "unknown native profile",
                surfaceWater=profile.swim and "implemented; live acceptance unverified" or "not established",
                climb="unimplemented",flight="unimplemented",depth="unimplemented",samples=0}
            self.coverage[key]=item;table.insert(self.coverageOrder,key)
            if #self.coverageOrder>64 then self.coverage[table.remove(self.coverageOrder,1)]=nil end
        end
        item.lastSeen=now;item.samples+=1;item.profile=profileKey
        return item
    end
    function b:snapshot(now)
        local c,h,r=validAnimal()
        local species,coat=fullStats(c)
        local alive=c~=nil and c.Parent~=nil and h~=nil and r~=nil and h.Health>0
        if not alive then return {alive=false,species=species,coat=coat,now=now} end
        self:refresh(now)
        local biome=attr(Workspace,"FeralBiome") or "WolfValley"
        local body=self.bodyProfile
        if not body or body.char~=c or body.species~=species or math.abs(r.Size.X/body.x-1)>.15
            or math.abs(r.Size.Y/body.y-1)>.15 or math.abs(r.Size.Z/body.z-1)>.15 then
            self.bodySerial=(self.bodySerial or 0)+1
            body={char=c,species=species,x=math.max(.01,r.Size.X),y=math.max(.01,r.Size.Y),z=math.max(.01,r.Size.Z)}
            self.bodyProfile=body
        end
        local profileKey=tostring(species)..":body"..self.bodySerial
        self:resetDiscovery({char=c,root=r,profile=profileKey,pack=attr(player,"FeralPack"),biome=biome,territory=self.territoryInstance,world=world})
        self.observationNow=now
        if now>=(self.nextPrune or 0) then
            self.nextPrune=now+10
            for _,cache in ipairs({self.waterBlocked,self.preyBlocked,self.foodBlocked}) do
                for key,untilAt in pairs(cache) do if untilAt<=now then cache[key]=nil end end
            end
        end
        local at;pcall(function()at=Workspace:GetServerTimeNow()end)
        local untilCombat=attr(player,"FeralCombatUntil")
        local stamina,maximum=attr(c,"Stamina"),attr(c,"StaminaMax")
        local reserve=finite(stamina) and finite(maximum) and maximum>0 and math.clamp(stamina/maximum,0,1) or nil
        local burstNo=attr(player,"HudBurstNo")
        local profile=self:profile(c,species)
        self.currentCoverage=self:recordCoverage(profile,species,profileKey,biome,now)
        local hub=self:hub()
        local feed,feedStarted,feedKnown
        if hub and type(hub.bridge.nativeFeedState)=="function" then
            local ok,mode,started,known=pcall(hub.bridge.nativeFeedState,hub.bridge,now)
            if ok then feed,feedStarted,feedKnown=mode,started,known end
        end
        local needs=config("NeedsConfig") or {}
        local attackCooldown
        local speciesConfig=config("Species")
        if speciesConfig and type(speciesConfig.biteCooldown)=="function" then
            local good,value=pcall(speciesConfig.biteCooldown,species,attr(c,"Growth") or 1)
            if good and finite(value) and value>=.1 and value<=10 then attackCooldown=value end
        end
        local offer=attr(c,"FeedCanPos")
        local others,contested=self:otherPlayerPositions()
        local amber=attr(player,"Amber")
        if not finite(amber) then
            local stats=player:FindFirstChild("leaderstats")
            local v=stats and stats:FindFirstChild("Amber")
            if v and finite(v.Value) then amber=v.Value end
        end
        local pack=attr(player,"FeralPack")
        if pack==0 or pack=="" or pack=="0" or pack==false then pack=nil end
        local swimming=attr(c,"FeralSwimLocal")==true
        local ok,humState=pcall(h.GetState,h)
        if ok and Enum.HumanoidStateType and humState==Enum.HumanoidStateType.Swimming then swimming=true end
        local fly=attr(c,"FeralFlyLocal")==true
        local hunger,thirst=attr(c,"Hunger"),attr(c,"Thirst")
        local hm=needs.HUNGER_MAX==nil and 100 or needs.HUNGER_MAX
        local tm=needs.THIRST_MAX==nil and 100 or needs.THIRST_MAX
        local knownNeeds=finite(hm) and hm>0 and finite(tm) and tm>0 and finite(hunger) and hunger>=0 and hunger<=hm*1.05
            and finite(thirst) and thirst>=0 and thirst<=tm*1.05
        hm=finite(hm) and hm>0 and hm or 100;tm=finite(tm) and tm>0 and tm or 100
        local model=self.nav.model
        local travelSpeed=profile.gaits and (profile.gaits.BURST or profile.gaits.SPRINT)
            or (self.nav.speed>6 and math.clamp(self.nav.speed,6,80) or 24)
        local hudBurst=attr(player,"HudBurst")
        if type(hudBurst)~="boolean" then hudBurst=attr(c,"WolfBurst") end
        local hudTrot=attr(player,"HudTrot")
        if type(hudTrot)~="boolean" then hudTrot=attr(c,"WolfTrot") end
        return {alive=true,char=c,hum=h,root=r,position=point(r.Position),
            species=species,coat=coat,profile=profile,pack=pack,profileKey=profileKey..":"..hm..":"..tm,generation=self.generation,
            travelSpeed=travelSpeed,travelCost=model and function(a,b,purpose)return model:estimate(a,b,now,travelSpeed,purpose)end,
            foodETA=math.max(self.foodETA or 0,self.foodObserved or 0),drinkETA=math.max(self.drinkETA or 0,self.drinkObserved or 0),
            progressLatency=self.progressLatency,needsKnown=knownNeeds,hungerMax=hm,thirstMax=tm,
            biome=attr(Workspace,"FeralBiome") or "WolfValley",healthFraction=h.MaxHealth>0 and h.Health/h.MaxHealth or 0,
            hunger=hunger,thirst=thirst,feedCan=attr(c,"FeedCan"),
            feedMode=attr(c,"WolfFeed"),nativeFeedMode=feed,nativeFeedKnown=feedKnown,feedStarted=feedStarted,
            feedPosition=typeof(offer)=="Vector3" and point(offer) or nil,
            staminaFraction=reserve,hudBurst=hudBurst,hudTrot=hudTrot,hudSprint=attr(player,"HudSprint"),
            hudBurstNo=burstNo==true or finite(burstNo) and now>=burstNo and now-burstNo<1.7,
            runIntent=attr(c,"WolfRunIntent"),allowBurst=reserve==nil or reserve>=.56,
            allowWater=profile.swim==true or swimming,swimSprint=profile.swimSprint==true,
            amber=amber,now=now,serverNow=at,unixNow=os.time(),players=others,contested=contested,currentHex=self:hexAt(point(r.Position)),
            claimTime=self.cfg and finite(self.cfg.CLAIM_TIME) and self.cfg.CLAIM_TIME or 20,
            avoidRadius=35,claimRadius=self.cfg and finite(self.cfg.CLAIM_RADIUS) and math.clamp(self.cfg.CLAIM_RADIUS,8,180) or 15,careTarget=hm*.90,
            drinkTarget=tm,
            refillTime=self.cfg and self.cfg.REFILL_TIME,
            attackCooldown=attackCooldown,gaitSpeeds=profile.gaits or profile.native and profile.native.gait,
            regionGrid=self.cfg and self.cfg.REGIONS and self.cfg.REGIONS.GRID,
            regionBonus=self.cfg and self.cfg.REGIONS and self.cfg.REGIONS.PAY_MULT,
            gameMenu=attr(player,"FeralMenuOpen")==true,menuOpen=UserInput:GetFocusedTextBox()~=nil,
            manualInput=self:manualInput(),combat=finite(at) and finite(untilCombat) and untilCombat>at or false,
            pinned=attr(c,"FeralPinned")==true or attr(c,"FeralDragged")==true or attr(c,"FeralCarried")==true,
            ability=attr(c,"FeralCrushAt")~=nil and attr(c,"FeralCrushAt")~=false or attr(c,"FeralRolling")==true or attr(c,"FeralDowned")==true or attr(c,"FeralVenomDown")==true
                or attr(c,"FeralTalonLock")~=nil and attr(c,"FeralTalonLock")~=false
                or attr(c,"FeralDeathRollLocal")==true or attr(c,"FeralDiveBomb")==true
                or hub and hub.grab and hub.grab.active==true,
            rescuing=hub and hub.rescue and hub.rescue.pending~=nil,
            resting=attr(c,"WolfRest")==true,
            automaticRest=hub and hub.recovery and hub.recovery.owned==c and not (hub.policy and hub.policy.manualRest),
            flying=fly,swimming=swimming,
            climbing=attr(c,"FeralClimbLocal")==true,underwater=attr(c,"FeralUnderwater")==true}
    end
    function b:move(destination,state,options)
        if not destination then return "WAIT" end
        options=options or {}
        local s=table.clone(state)
        for key,value in pairs(options) do s[key]=value end
        local target=Vector3.new(destination.x,state.root.Position.Y,destination.z)
        local result=self.nav:tick(target,state.char,state.hum,state.root,state.now,{},s)
        self.motionReason=self.nav.lastReason
        return result
    end
    function b:stop(reason)
        self.motionReason=reason
        local _,h,r=validAnimal()
        self.nav:stop(h,r,reason)
    end
    function b:releaseInputs()
        self.inputEpoch+=1
        for name,release in pairs(self.pendingInputs or {}) do pcall(release);self.pendingInputs[name]=nil end
    end
    local function pulse(name,begin,finish)
        b.pendingInputs=b.pendingInputs or {}
        if b.pendingInputs[name] then return false end
        local ok=pcall(begin)
        if not ok then pcall(finish);return false end
        b.pendingInputs[name]=finish
        local epoch=b.inputEpoch
        task.delay(.07,function()
            if b.inputEpoch==epoch and b.pendingInputs[name]==finish then
                pcall(finish);b.pendingInputs[name]=nil
            end
        end)
        return true
    end
    function b:feed(state,kind)
        if state.feedCan~=kind or state.nativeFeedMode or state.feedMode==kind or state.feedMode==true
            or state.menuOpen or state.manualInput then return false end
        local hub=self:hub()
        if hub and type(hub.bridge.toggleNativeFeed)=="function" and state.nativeFeedKnown then
            local ok,sent=pcall(hub.bridge.toggleNativeFeed,hub.bridge,state.now)
            self.lastInput=ok and sent and "Native toggleFeed requested" or "Native toggleFeed unavailable"
            return ok and sent==true
        end
        local ok,v=pcall(function()return game:GetService("VirtualInputManager")end)
        self.synthetic.E=state.now
        if ok and v then
            local sent=pulse("E",function()v:SendKeyEvent(true,Enum.KeyCode.E,false,game)end,
                function()v:SendKeyEvent(false,Enum.KeyCode.E,false,game)end)
            if sent then self.lastInput="Virtual E input requested";return true end
        end
        if type(keypress)=="function" and type(keyrelease)=="function" then
            local sent=pulse("E",function()keypress(0x45)end,function()keyrelease(0x45)end)
            self.lastInput=sent and "Executor E input requested" or "Feeding input rejected"
            return sent
        end
        return false
    end
    function b:cancelFeed(state)
        local hub=self:hub()
        if hub and type(hub.bridge.stopNativeFeed)=="function" then
            local ok,sent=pcall(hub.bridge.stopNativeFeed,hub.bridge,state.now)
            return ok and sent==true
        end
        return false
    end
    function b:food(state,preferred)
        -- Keep a real edible food target instead of chasing a new nearest item
        -- on every tick. Revalidate consumption, diet, ownership and position.
        local item=preferred and preferred.model
        local profile=state.profile or self:profile(state.char,state.species)
        local forage=config("Forage")
        if item and item.Parent and item:IsDescendantOf(Workspace) and forage and type(forage.canEat)=="function" then
            local ok,edible=pcall(forage.canEat,profile.diet,attr(item,"Diet"))
            local left,owner=attr(item,"FoodLeft"),attr(item,"TutorialOwner")
            if ok and edible and attr(item,"Consumed")~=true and (not finite(left) or left>.01)
                and (owner==nil or owner==player.UserId) and (self.foodBlocked[item] or 0)<=state.now then
                local pos=attr(item,"FoodPos")
                if typeof(pos)~="Vector3" and item:IsA("BasePart") then pos=item.Position end
                if typeof(pos)~="Vector3" and item:IsA("Model") then
                    local good,cf=pcall(item.GetBoundingBox,item);if good then pos=cf.Position end
                end
                if typeof(pos)=="Vector3" and safePosition(point(pos),state) then
                    return {model=item,position=point(pos)}
                end
            end
        end
        local finder=config("FeedFinder")
        if finder and type(finder.food)=="function" then
            local ok,item,pos=measured("FeedFinder.food",finder.food,state.char,state.root)
            if ok and item and typeof(pos)=="Vector3" and safePosition(point(pos),state)
                and (self.foodBlocked[item] or 0)<=state.now then
                return {position=point(pos),model=item}
            end
        end
        if not profile.diet or not forage or type(forage.canEat)~="function" then return nil end
        if forage.PLANT_DIETS and forage.PLANT_DIETS[profile.diet] and type(forage.nearest)=="function" then
            local ok,entry,pos=measured("Forage.nearest",forage.nearest,state.root.Position,300)
            if ok and entry and typeof(pos)=="Vector3" and safePosition(point(pos),state) then
                local item
                if type(forage.handle)=="function" then
                    local valid,result=pcall(forage.handle,entry)
                    if valid then item=result end
                end
                if item and (self.foodBlocked[item] or 0)<=state.now then return {model=item,position=point(pos)} end
            end
        end
        local ok,collection=pcall(function()return game:GetService("CollectionService")end)
        if not ok or not collection then return nil end
        local best,score=nil,math.huge
        if not self.foodIndex or state.now>=(self.foodIndex.at or 0)+2 then
            self.foodIndex={items=collection:GetTagged("FeralFood"),cursor=1,at=state.now}
        end
        local index=self.foodIndex
        for _=1,math.min(24,#index.items) do
            if index.cursor>#index.items then index.cursor=1 end
            local item=index.items[index.cursor];index.cursor+=1;self.operations.food+=1
            local left=attr(item,"FoodLeft")
            local owner=attr(item,"TutorialOwner")
            local valid,edible=pcall(forage.canEat,profile.diet,attr(item,"Diet"))
            if item.Parent and item:IsDescendantOf(Workspace) and attr(item,"Consumed")~=true and valid and edible
                and (not finite(left) or left>.01) and (owner==nil or owner==player.UserId)
                and (self.foodBlocked[item] or 0)<=state.now then
                local pos=attr(item,"FoodPos")
                if typeof(pos)~="Vector3" then
                    if item:IsA("Model") then
                        local good,cf=pcall(item.GetBoundingBox,item)
                        if good then pos=cf.Position end
                    elseif item:IsA("BasePart") then pos=item.Position end
                end
                if typeof(pos)=="Vector3" then
                    local p=point(pos);local d=dist(p,state.position)
                    if d<400 and d<score and safePosition(p,state) then best,score={position=p,model=item},d end
                end
            end
        end
        return best
    end
    function b:resourceSearch(state,kind)
        self.searchVisits=self.searchVisits or {}
        local active=self.searchPoint
        if active and self.searchKind==kind then
            local remaining=dist(active,state.position)
            if not self.searchBest or remaining<self.searchBest-1 then
                self.searchBest=remaining;self.searchProgressAt=state.now
            end
            if state.now<(self.searchUntil or 0) and state.now-(self.searchProgressAt or state.now)<15
                and remaining>12 then return active end
        end
        if active then self.searchVisits[active.key or "last"]=state.now end
        local best,score=nil,math.huge
        local candidates={}
        for _,hex in ipairs(self.hexes) do
            local p=hex.spot or hex.center
            table.insert(candidates,{x=p.x,z=p.z,key=hex.key})
        end
        -- Explore a stable world grid as well as hex centres. A resource can
        -- lie between them; short visit cooldowns previously retraced centres.
        local cx,cz=math.floor(state.position.x/120),math.floor(state.position.z/120)
        for dx=-3,3 do for dz=-3,3 do
            if dx~=0 or dz~=0 then
                local x,z=(cx+dx)*120,(cz+dz)*120
                table.insert(candidates,{x=x,z=z,key=kind..":"..(cx+dx)..":"..(cz+dz)})
            end
        end end
        for _,p in ipairs(candidates) do
            local d=dist(p,state.position);local visited=self.searchVisits[p.key]
            local occupied=self:hexAt(p)
            if d>45 and d<650 and not (state.contested and state.contested[occupied]) then
                local rank=d+(p.key:find(":",1,true) and 250 or 0)+(visited and math.max(0,240-state.now+visited)*3 or 0)
                if rank<score then best,score=p,rank end
            end
        end
        local count=0
        for key,at in pairs(self.searchVisits) do count+=1;if state.now-at>600 then self.searchVisits[key]=nil end end
        if count>256 then self.searchVisits={} end
        self.searchPoint,self.searchUntil=best,state.now+120
        self.searchKind=kind;self.searchBest=best and dist(best,state.position);self.searchProgressAt=state.now
        return best
    end
    function b:patrol(state)
        self.patrolVisits=self.patrolVisits or {}
        local target=self.patrolTarget
        if target and dist(target,state.position)>14 and state.now<(self.patrolUntil or 0) then return target end
        if target then self.patrolVisits[target.key]=state.now end
        local best,score=nil,math.huge
        for _,h in ipairs(self.hexes) do
            local t=self:territory(h.key)
            local d=dist(state.position,h.spot or h.center)
            if t and not t.neutral and t.owner==state.pack and d>40 and not (state.contested and state.contested[h.key]) then
                local recent=self.patrolVisits[h.key]
                local rank=d+(recent and math.max(0,60-state.now+recent)*12 or 0)
                if rank<score then best,score={x=(h.spot or h.center).x,z=(h.spot or h.center).z,key=h.key},rank end
            end
        end
        self.patrolTarget,self.patrolUntil=best,state.now+12
        return best
    end
    function b:checkPrey(prey,state)
        local profile=state.profile or self:profile(state.char,state.species)
        if not prey or not prey.model or not prey.model.Parent or not profile.hunts then return nil end
        if Players:GetPlayerFromCharacter(prey.model) then return nil end
        local hub=self:hub()
        if hub and type(hub.bridge.combatEligible)=="function" then
            local ok,eligible=pcall(hub.bridge.combatEligible,hub.bridge,prey.model)
            if not ok or not eligible then return nil end
        end
        local pack=attr(prey.model,"FeralPack")
        if packKey(state.pack)~=nil and packKey(state.pack)==packKey(pack) then return nil end
        local root=prey.model:FindFirstChild("HumanoidRootPart")
        local hum=prey.model:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health<=0 or attr(prey.model,"FeralDead")==true
            or hum.MaxHealth>state.hum.MaxHealth*1.25 or (self.preyBlocked[prey.model] or 0)>state.now then return nil end
        local position=point(root.Position)
        if not safePosition(position,state,32) then return nil end
        local velocity=root.AssemblyLinearVelocity
        prey.position=position;prey.root=root;prey.hum=hum
        prey.velocity=velocity and point(velocity) or {x=0,z=0}
        local look=root.CFrame and root.CFrame.LookVector
        prey.forward=look and {x=look.X,z=look.Z} or nil
        prey.health=hum.Health
        prey.attackRange=math.clamp((state.root.Size.Z+root.Size.Z)*.35,4,12)
        return prey
    end
    function b:prey(state)
        local folder=Workspace:FindFirstChild("FeralNPCs")
        if not folder then return nil end
        local best,score=nil,math.huge
        if not self.preyIndex or self.preyIndex.folder~=folder or state.now>=self.preyIndex.at+2 then
            self.preyIndex={folder=folder,items=folder:GetChildren(),cursor=1,at=state.now}
        end
        local index=self.preyIndex
        for _=1,math.min(24,#index.items) do
            if index.cursor>#index.items then index.cursor=1 end
            local npc=index.items[index.cursor];index.cursor+=1;self.operations.prey+=1
            if npc:IsA("Model") then
                local p=self:checkPrey({model=npc},state)
                if p then
                    local d=dist(p.position,state.position)
                    local speed=math.sqrt(p.velocity.x^2+p.velocity.z^2)
                    local travel=state.travelCost and state.travelCost(state.position,p.position) or d/math.max(10,state.travelSpeed or 24)
                    local damage=self.observedDamage
                    local service=damage and p.health/math.max(1,damage)*(state.attackCooldown or 1) or p.health*.08+8
                    local closing=math.max(1,(state.travelSpeed or 24)-speed)
                    local chase=math.min(90,d/closing)
                    local rank=travel+service+chase*.5
                    p.mealETA=rank+12;self.foodETA=p.mealETA;p.costConfidence=damage and "observed HP trend; attribution unknown" or "heuristic without damage observations"
                    if speed>(state.travelSpeed or 24)*1.15 and d>60 then rank+=100 end
                    if d<330 and rank<score then best,score=p,rank end
                end
            end
        end
        return best
    end
    function b:careObserved(goal,state)
        if goal.manualInterventionObserved or goal.timing and goal.timing.unknown>1 then return end
        local seconds=goal.timing and goal.timing.active or state.now-goal.start
        if not finite(seconds) or seconds<=0 then return end
        local key=goal.kind=="DRINK" and "drinkObserved" or "foodObserved"
        self[key]=self[key] and self[key]*.6+seconds*.4 or seconds
    end
    function b:huntOutcome(amount)
        if finite(amount) and amount>0 then self.observedDamage=self.observedDamage and self.observedDamage*.7+amount*.3 or amount end
    end
    function b:mealChoice(state,food,committed)
        if not food then return nil end
        if committed and committed.target then
            if dist(food.position,state.position)<24 then return food end
            return nil
        end
        local foodETA=(state.travelCost and state.travelCost(state.position,food.position) or dist(food.position,state.position)/24)+12
        self.foodETA=foodETA
        if foodETA>24 and state.profile and state.profile.hunts then
            local prey=self:prey(state)
            if prey and prey.mealETA and prey.mealETA*1.25<foodETA then return nil end
        end
        return food
    end
    function b:attackGeometry(state,prey)
        local hub=self:hub()
        local cfg=hub and hub.features and hub.features.originalCombat or config("CombatConfig")
        if not cfg then return nil end
        local diff=prey.root.Position-state.root.Position
        local planar=Vector3.new(diff.X,0,diff.Z)
        local look=state.root.CFrame.LookVector
        look=Vector3.new(look.X,0,look.Z)
        if type(cfg.bodyGap)~="function" or not finite(cfg.REACH) or not finite(cfg.SLACK)
            or not finite(cfg.HIT_SCALE) or not finite(cfg.MAX_DY) or not finite(cfg.CONE) then return nil end
        if type(cfg.biteLook)=="function" then
            local ok,v=pcall(cfg.biteLook,state.char,look.Unit)
            if ok and typeof(v)=="Vector3" then look=Vector3.new(v.X,0,v.Z) end
        end
        local function mult(name,default)
            if type(cfg[name])~="function" then return default end
            local ok,value=pcall(cfg[name],state.char)
            return ok and finite(value) and value or default
        end
        local ok,gap=pcall(cfg.bodyGap,prey.root,planar)
        if not ok or not finite(gap) or look.Magnitude<.01 then return nil end
        local box=attr(state.root,"FeralBoxFull")
        if not finite(box) or box<=0 then box=state.root.Size.Z end
        local reach=(box*.5+state.hum.HipHeight*cfg.REACH+cfg.SLACK)*cfg.HIT_SCALE*mult("reachMult",1)
        local angle=planar.Magnitude>.01 and look.Unit:Dot(planar.Unit) or 1
        local height=(state.hum.HipHeight+prey.hum.HipHeight)*cfg.MAX_DY*mult("dyMult",1)
        local cone=mult("coneFor",cfg.CONE)
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={state.char};params.IgnoreWater=true
        params.RespectCanCollide=true
        local obstruction=Workspace:Raycast(state.root.Position,diff,params)
        local clear=not obstruction or obstruction.Instance and obstruction.Instance:IsDescendantOf(prey.model)
        local inRange=gap<reach*.92 and math.abs(diff.Y)<height*.95
        local facing=angle>math.cos(math.rad(cone))
        return {valid=inRange and facing and clear,inRange=inRange,facing=facing,
            angle=angle,gap=gap,reach=reach,clear=clear,height=math.abs(diff.Y),heightLimit=height*.95,
            reason=not inRange and "Outside native bite geometry" or not facing and "Facing away from prey"
                or not clear and "Bite corridor obstructed" or "Native attack geometry ready"}
    end
    function b:attackEvidence(state)
        if not self.lastAttackInput then return nil end
        local record=table.clone(self.lastAttackInput)
        record.age=state.now-record.at
        record.sameCharacter=self.attackCharacter==state.char
        local marker=record.sameCharacter and attr(state.char,"WolfBiteAt") or nil
        record.markerNow=finite(marker) and marker or nil
        record.markerAdvanced=record.sameCharacter and finite(marker)
            and (not finite(record.markerBefore) or marker>record.markerBefore+.000001) or false
        return record
    end
    function b:bite(state,prey)
        local p=self:checkPrey(prey,state)
        if not p then return false,"Prey unavailable" end
        local geometry=self:attackGeometry(state,p)
        if not geometry or not geometry.valid then return false,"Native range, facing or line of sight not ready" end
        self.attackCharacter=state.char;self.synthetic.M1=state.now
        self.lastAttackInput={at=state.now,markerBefore=attr(state.char,"WolfBiteAt"),sent=false,backend="NONE"}
        local hub=self:hub()
        if hub and type(hub.bridge.tryNativeBite)=="function" then
            if hub.recovery then hub.recovery:release("Amber hunt",state.now) end
            -- Readiness guidance is advisory. Cached/private timing must not
            -- suppress the original handler: that handler already owns the
            -- native cooldown, Rest and capture guards. Dispatch is still only
            -- an attempt; the hunter observes actual HP separately.
            if hub.policy then hub.policy:input("attack",state.now) end
            local priorReach,priorTree=hub.bridge.reachTarget,hub.bridge.treeTarget
            hub.bridge.reachTarget,hub.bridge.treeTarget=nil,nil
            local ok,sent=pcall(hub.bridge.tryNativeBite,hub.bridge,state.now)
            if hub.bridge.reachTarget==nil then hub.bridge.reachTarget=priorReach end
            if hub.bridge.treeTarget==nil then hub.bridge.treeTarget=priorTree end
            if ok and sent then
                self.lastAttackInput.sent=true;self.lastAttackInput.backend="NATIVE_CALLBACK"
                self.lastInput="Native tryBite requested";return true,self.lastInput
            end
        end
        local species=config("Species")
        local delay=1.35
        if species and type(species.biteCooldown)=="function" then
            local ok,value=pcall(species.biteCooldown,state.species,attr(state.char,"Growth") or 1)
            if ok and finite(value) then delay=math.clamp(value,.15,10) end
        end
        if state.now<(self.nextBite or 0) then return false,"Native bite cooldown" end
        self.nextBite=state.now+delay
        local original=UserInput:GetMouseLocation()
        local m=original
        local camera=Workspace.CurrentCamera
        local gui=player:FindFirstChildOfClass("PlayerGui")
        local function clearAt(x,y)
            if not gui or type(gui.GetGuiObjectsAtPosition)~="function" then return true end
            local checked,objects=pcall(gui.GetGuiObjectsAtPosition,gui,x,y)
            if not checked then return false end
            for _,object in ipairs(objects) do
                if object.Active or object:IsA("GuiButton") or object:IsA("TextBox") then return false end
            end
            return true
        end
        if not clearAt(m.X,m.Y) then
            local found=false
            if camera and camera.ViewportSize then
                for _,uv in ipairs({{.08,.45},{.92,.45},{.5,.5},{.5,.82}}) do
                    local x,y=camera.ViewportSize.X*uv[1],camera.ViewportSize.Y*uv[2]
                    if clearAt(x,y) then m={X=x,Y=y};found=true;break end
                end
            end
            if not found then self.lastInput="Attack input blocked by interface";return false,self.lastInput end
        end
        local ok,v=pcall(function()return game:GetService("VirtualInputManager")end)
        if ok and v then
            -- The owned WolfController callback above avoids UI hit testing.
            -- Fallback mouse input is reported as a request, never as damage.
            local sent=pulse("M1",function()v:SendMouseButtonEvent(m.X,m.Y,0,true,game,0)end,
                function()v:SendMouseButtonEvent(m.X,m.Y,0,false,game,0)end)
            if sent then
                self.lastAttackInput.sent=true;self.lastAttackInput.backend="VIRTUAL_MOUSE"
                self.lastInput="Virtual mouse attack requested";return true,self.lastInput
            end
            self.lastAttackInput.virtualError="VIRTUAL_MOUSE_REJECTED"
        end
        local moved=false
        local function positionCursor()
            if math.abs(m.X-original.X)+math.abs(m.Y-original.Y)>.5 then
                assert(type(mousemoveabs)=="function","Executor cursor positioning unavailable")
                mousemoveabs(m.X,m.Y);moved=true
            end
        end
        local function restoreCursor()
            if moved and type(mousemoveabs)=="function" then mousemoveabs(original.X,original.Y);moved=false end
        end
        local sent=false
        if type(mouse1press)=="function" and type(mouse1release)=="function" then
            sent=pulse("M1",function()positionCursor();mouse1press()end,function()
                pcall(mouse1release);restoreCursor()
            end)
        elseif type(mouse1click)=="function" then
            sent=pulse("M1",function()positionCursor();mouse1click()end,restoreCursor)
        end
        self.lastAttackInput.sent=sent;self.lastAttackInput.backend=sent and "EXECUTOR_MOUSE" or "UNAVAILABLE"
        self.lastInput=sent and "Executor mouse attack requested" or "Attack input unavailable or rejected"
        return sent,self.lastInput
    end
    if UserInput.InputBegan then
        table.insert(b.connections,UserInput.InputBegan:Connect(function(input)
            local name=tostring(input.KeyCode or ""):match("%.([^%.]+)$") or tostring(input.KeyCode or "")
            if input.UserInputType==Enum.UserInputType.MouseButton1 then name="M1" end
            local mapped=name=="LeftShift" and "SHIFT" or name
            local relevant={W=true,A=true,S=true,D=true,Space=true,X=true,Z=true,E=true,M1=true}
            if relevant[name] or mapped=="SHIFT" then
                local now=os.clock();local at=b.nav.synthetic and b.nav.synthetic[mapped] or b.synthetic[mapped]
                if not (at and now-at<.25) and not (b.pendingInputs and b.pendingInputs[mapped]) then b.manualUntil=now+.6 end
            end
        end))
    end
    function b:close()
        self:recover(nil,false);self:releaseInputs();self:stop("unloaded")
        for _,c in ipairs(self.connections) do c:Disconnect() end
        self.connections={}
    end
    return b
end
return Bridge
]============]
sources["amber_driver"] = [============[
-- Ordinary world-space input before WolfMove reads Humanoid.MoveDirection.
-- v2412 WolfController 187:1546-1666 binds WolfMove at Input.Value+1.
local Driver={}
function Driver.new(player,nav,manual)
    local d={nav=nav,closed=false,method="NATIVE_KEYS",controls=nil,original=nil,nextProbe=0}
    function d:attach()
        if self.closed or self.controls then return end
        local modules={}
        local scripts=player:FindFirstChild("PlayerScripts")
        local legacy=scripts and scripts:FindFirstChild("PlayerModule")
        if legacy then table.insert(modules,{module=legacy,path="PLAYER_SCRIPTS"}) end
        -- The supplied capture indexes StarterPlayer/PlayerModule/ControlModule.
        -- IAS PlayerModule need not expose the legacy GetControls endpoint.
        local ok,starter=pcall(function()return game:GetService("StarterPlayer")end)
        local modern=ok and starter and starter:FindFirstChild("PlayerModule")
        if modern and modern~=legacy then table.insert(modules,{module=modern,path="STARTER_PLAYER"}) end
        local controls,path=nil,nil
        for _,candidate in ipairs(modules) do
            local mod=candidate.module
            local good,value=pcall(require,mod)
            if good and type(value)=="table" then
                if type(value.GetControls)=="function" then
                    local found,result=pcall(value.GetControls,value)
                    if found and type(result)=="table" then controls=result end
                elseif type(value.moveFunction)=="function" then controls=value end
            end
            if not controls and type(mod.FindFirstChild)=="function" then
                local child=mod:FindFirstChild("ControlModule")
                if child then
                    local found,result=pcall(require,child)
                    if found and type(result)=="table" then controls=result end
                end
            end
            if controls and type(controls.moveFunction)=="function" then path=candidate.path;break end
            controls=nil
        end
        if not controls then self.reason="No supported native moveFunction; using keys";return end
        local previous=controls.moveFunction
        self.original=previous
        local wrapper=function(p,direction,relative)
            if p==player and not self.closed and nav.desiredPoint and nav.steeringStrategy=="WORLD" then
                if manual and manual() then
                    nav:stop(nav.desiredHum,nav.desiredRoot,"MANUAL_INPUT")
                else
                    local wanted=nav:direction()
                    if wanted then
                        nav.driveCalls+=1;nav.lastMode="PLAYER_MODULE"
                        return self.original(p,wanted,false)
                    end
                end
            end
            return self.original(p,direction,relative)
        end
        local attached,why=pcall(function()controls.moveFunction=wrapper end)
        if not attached then self.reason=tostring(why);return end
        self.controls,self.original,self.wrapper=controls,previous,wrapper
        self.method,self.path,self.reason="PLAYER_MODULE",path,"Native callback attached; motion unverified"
        nav.preferredStrategy="WORLD";nav.steeringStrategy="WORLD"
        nav.driverPath=path
    end
    d:attach()
    if not d.controls then nav.preferredStrategy="KEY";nav.steeringStrategy="KEY" end
    function d:tick()
        if self.closed then return end
        if self.controls and self.controls.moveFunction~=self.wrapper then
            self.method="NATIVE_KEYS";nav.preferredStrategy="KEY";nav.steeringStrategy="KEY"
            self.reason="Native callback ownership changed"
        elseif not self.controls and os.clock()>=self.nextProbe then
            self.nextProbe=os.clock()+5;self:attach()
        end
        nav.driverReason=self.reason
        if nav.steeringStrategy=="KEY" then nav:drive() end
    end
    function d:close()
        if self.closed then return end
        self.closed=true
        nav:stop(nav.desiredHum,nav.desiredRoot,"DRIVER_CLOSED")
        if self.controls and self.controls.moveFunction==self.wrapper then
            self.controls.moveFunction=self.original
        end
    end
    return d
end
return Driver
]============]
sources["amber_ui"] = [============[
-- Native Renaissance page. No companion ScreenGui, scheduler or visibility key.
local UI={}
function UI.new(engine,hub)
    local p={closed=false,engine=engine,hub=hub}
    local function amount(value)
        return type(value)=="number" and string.format("%.0f",value) or "?"
    end
    function p:mount(parent,H)
        local text,button,card=H.text,H.button,H.card
        local v={}
        local controls=card(0,48)
        local start=button(controls,"START FARMING",10,9,150,30)
        local skip=button(controls,"SKIP TARGET",169,9,150,30)
        local copy=button(controls,"COPY STATUS",328,9,150,30)
        start.Name="TerritoryStart";skip.Name="TerritorySkip";copy.Name="TerritoryCopy"
        start.Activated:Connect(function()if not p.closed then engine.setEnabled(not engine.agent.enabled)end end)
        skip.Activated:Connect(function()if not p.closed then engine.skip()end end)
        copy.Activated:Connect(function()if not p.closed then engine.copyStatus()end end)
        local stats=card(56,71)
        local totals=text(stats,"",12,8,465,22,12,H.palette.same)
        local needs=text(stats,"",12,34,465,23,12)
        local goal=card(135,103)
        local phase=text(goal,"",12,7,465,23,13,H.palette.same)
        local reason=text(goal,"",12,33,465,37,11,H.palette.sub);reason.TextWrapped=true
        local progress=text(goal,"",12,73,465,20,11)
        local movement=card(246,53)
        local gait=text(movement,"",12,5,465,22,12)
        local travel=text(movement,"",12,28,465,19,10,H.palette.sub)
        local recent=card(307,54)
        local last=text(recent,"",12,5,465,44,11,H.palette.sub);last.TextWrapped=true
        function v:tick(now)
            if now<(self.nextText or 0) then return end
            self.nextText=now+.25
            local s=engine.status();local n=s.navigation or {};local c=s.hexSummary or {}
            start.Text=s.enabled and "STOP FARMING" or "START FARMING"
            start.BackgroundColor3=s.enabled and H.palette.on or H.palette.off
            local amber=s.metrics and s.metrics.amber
            local balance=amber and string.format("Balance %+.0f · %+.0f/hr",amber.net or 0,amber.netPerWallHour or 0)
                or string.format("Observed Amber +%.0f",s.earned or 0)
            totals.Text=string.format("%d / %d owned · %d need scent · %s",c.owned or 0,c.eligible or 0,c.fading or 0,balance)
            needs.Text="Hunger "..amount(s.hunger).." · Thirst "..amount(s.thirst).." · "..tostring(s.species or "Waiting for animal")
            phase.Text=(s.enabled and "RUNNING · " or "OFF · ")..tostring(s.phase)..(s.key and " · "..s.key or "")
            reason.Text=tostring(s.reason or "Ready")
            local target=s.targetProgress or {}
            local value=target.action=="SCENT" and target.hold or target.progress
            progress.Text=type(value)=="number" and ("Native territory progress "..amount(value*100).."%")
                or s.suspended and ("Will resume "..s.suspended) or "Watching native progress and resource changes"
            if s.capacity and s.capacity.state=="DEADLINE_PRESSURE" then
                progress.Text=progress.Text.." · Maintenance pressure"
            end
            gait.Text=tostring(n.requested or "STOP").." requested · "..tostring(n.observed or "UNKNOWN").." observed"
            travel.Text="Travelled "..amount(n.travelled).." studs · Target "..amount(n.distance).." studs"
                ..(n.failure and (n.stalledFor or 0)>1 and " · "..n.failure or "")
            if s.strategy and s.strategy.area then
                progress.Text=s.strategy.area.." · "..tostring(s.strategy.owned or 0).."/"..tostring(s.strategy.total or 0).." owned"
                    ..(type(value)=="number" and (" · Native progress "..amount(value*100).."%") or "")
            end
            last.Text=s.lastNotice or s.lastSuccess or s.lastSkip or "Select START FARMING. Hiding the hub keeps farming active."
        end
        function v:close()end
        v:tick(os.clock());return v
    end
    p.registration=hub.ui:registerPage("Territory",p)
    function p:close()
        if self.closed then return end
        self.closed=true
        if self.registration then self.registration:close() end
    end
    return p
end
return UI
]============]
sources["amber_runtime"] = [============[
-- Built-in Territory engine. Renaissance owns scheduling, UI and shutdown.
local Runtime={version="0.7.0"}
function Runtime.start(M,hub)
    assert(hub and hub.ui and type(hub.ui.registerPage)=="function","Update Renaissance for its built-in Territory page")
    local env=(type(getgenv)=="function" and getgenv()) or _G
    local prior=env.FERAL_AMBER_ACTIVE
    if prior and prior.version==Runtime.version and prior.ownerHub==hub and not prior.closed then return prior end
    local function module(name)return assert(M["amber_"..name] or M[name],"Missing territory module "..name)end
    local Nav,Bridge,Agent=module("nav"),module("bridge"),module("agent")
    local model=module("model").new()
    local nav=Nav.new(game:GetService("PathfindingService"),game:GetService("Workspace"),module("gait"),model)
    local bridge=Bridge.new(nav);bridge.ownerHub=hub
    local agent=Agent.new(module("planner"),bridge,module("hunt"),module("care"),module("ledger"))
    local attached,driver=pcall(module("driver").new,bridge.player,nav,function()return bridge:manualInput()end)
    if not attached then pcall(bridge.close,bridge);nav.closed=true;error(driver,0) end
    local h={version=Runtime.version,ownerHub=hub,agent=agent,bridge=bridge,nav=nav,driver=driver,closed=false,nextCounts=0}
    function h.setEnabled(on) if not h.closed then agent:setEnabled(on==true,os.clock()) end end
    function h.status()
        local now=os.clock();local st=agent:status()
        if now>=h.nextCounts then
            h.counts=bridge:counts(agent.lastState or {now=now});h.nextCounts=now+.8
        end
        st.support={known=agent.lastState and agent.lastState.profile and agent.lastState.profile.known,
            diet=agent.lastState and agent.lastState.profile and agent.lastState.profile.diet,
            modes=agent.lastState and agent.lastState.profile and agent.lastState.profile.support}
        st.support.current=bridge.currentCoverage;st.support.encountered={}
        for _,key in ipairs(bridge.coverageOrder) do table.insert(st.support.encountered,bridge.coverage[key]) end
        st.nativeHelperCosts=bridge.nativeCosts
        st.discoveryOperations=bridge.operations;st.hexSummary=h.counts;st.navigation=nav:status();st.gameVersion=game.PlaceVersion
        st.events={}
        for i=math.max(1,#agent.events-11),#agent.events do table.insert(st.events,agent.events[i]) end
        return st
    end
    function h.copyStatus()
        local ok,payload=pcall(function()return game:GetService("HttpService"):JSONEncode(h.status())end)
        if not ok then return false end
        if type(setclipboard)=="function" then pcall(setclipboard,payload) end
        print("[FERAL TERRITORY STATUS] "..payload);return true
    end
    function h.skip()
        if not agent.enabled then return end
        local s=agent.lastState
        if not s or not agent.goal or agent.goal.kind~="TERRITORY" then return end
        agent:fail(s,"Target skipped from Territory controls");agent.nextTick=0
    end
    local mounted,panel=pcall(module("ui").new,h,hub)
    if not mounted then
        pcall(driver.close,driver);pcall(bridge.close,bridge);nav.closed=true;error(panel,0)
    end
    h.panel=panel
    function h:tick(now)
        if self.closed then return end
        if hub.closed then self.close();return end
        local started=os.clock();local wasEnabled=agent.enabled
        local ok,why=pcall(function()
            if agent.enabled then driver:tick() end
            for _=1,3 do
                agent:tick(now)
                if not agent.enabled or agent.goal or agent.phase~="CONFIRMED" and agent.phase~="REPLAN" then break end
                agent.nextTick=now
            end
        end)
        if wasEnabled and agent.metrics and agent.metrics.run then agent.metrics:cost("coordinator",math.max(0,os.clock()-started)) end
        if not ok then
            -- A failure in the normal stop path must not escape this boundary
            -- and interrupt the shared hub's remaining work for the frame.
            pcall(agent.setEnabled,agent,false)
            pcall(nav.stop,nav,nav.desiredHum,nav.desiredRoot,"TERRITORY_ERROR")
            pcall(nav.releaseKeys,nav);pcall(bridge.releaseInputs,bridge)
            agent.enabled=false;agent.goal=nil;agent.suspended=nil;agent.returns={};agent.phase="ERROR"
            agent.lastError=tostring(why):sub(1,180);agent.reason="Territory stopped after an input or data error"
        end
    end
    function h.close()
        if h.closed then return end
        h.closed=true
        pcall(agent.setEnabled,agent,false);pcall(driver.close,driver);pcall(bridge.close,bridge)
        nav.closed=true
        if h.panel then pcall(h.panel.close,h.panel) end
        if env.FERAL_AMBER_ACTIVE==h then env.FERAL_AMBER_ACTIVE=nil end
        if hub.territory==h then hub.territory=nil end
    end
    if prior and type(prior.close)=="function" then
        local ok,why=pcall(prior.close)
        if not ok then h.close();error(why,0) end
        if prior.driver and driver.original==prior.driver.wrapper then driver.original=prior.driver.original end
    end
    env.FERAL_AMBER_ACTIVE=h;hub.territory=h
    return h
end
return Runtime
]============]
local moduleOrder = {"core","settings","policy","grab","grab_input","recovery","feeding","combat_input","rescue","features","roblox","zoom","ui","controller","amber_ledger","amber_model","amber_planner","amber_gait","amber_nav","amber_hunt","amber_care","amber_agent","amber_bridge","amber_driver","amber_ui","amber_runtime"}
local M = {}
for _, name in ipairs(moduleOrder) do
    local fn, why = loadstring(sources[name], "=Renaissance/" .. name)
    if not fn then error("Renaissance compile failed: " .. name .. ": " .. tostring(why), 0) end
    local ok, value = pcall(fn)
    if not ok or type(value) ~= "table" then error("Renaissance module invalid: " .. name, 0) end
    M[name] = value
end
for _, pair in ipairs({
    {"core","scope"},{"core","leases"},{"settings","sanitize"},{"policy","new"},
    {"grab","new"},{"grab_input","new"},{"recovery","new"},{"feeding","new"},{"combat_input","new"},{"rescue","new"},{"features","new"},{"roblox","new"},
    {"zoom","new"},{"ui","mount"},{"controller","new"},
}) do
    if type(M[pair[1]][pair[2]]) ~= "function" then error("Renaissance interface mismatch",0) end
end
if options.inspect then return M end
if game.PlaceId ~= 108901361810209 then error("Open FERAL Animal Survival",0) end
local env = type(getgenv) == "function" and getgenv() or _G
local bridge = M.roblox.new(M.core,env)
local candidate
local staged, why = xpcall(function()
    candidate = M.controller.new(M,bridge,options)
    candidate:stage()
end,function(e) return tostring(e) end)
if not staged then
    if candidate then pcall(candidate.close,candidate) end
    error("Renaissance staging failed; previous hub retained: " .. tostring(why),0)
end
if options.stageOnly then return candidate end
-- All candidate attach operations are complete before retiring the previous hub.
local previous = env.FERAL_RENAISSANCE_ACTIVE or env.FERAL_NOVA_PRIME_ACTIVE
if previous and type(previous.close) == "function" then
    -- Carry only own automatic-Rest provenance across a successful hot reload.
    -- This is local metadata; staging still performs no gameplay mutations.
    local recovery = previous.recovery
    local char = recovery and (recovery.lastAutomaticCharacter or recovery.owned)
    if char == bridge.player.Character and previous.policy and not previous.policy.manualRest then
        candidate.recovery.lastAutomaticCharacter = char
    end
    local stopped, failure = pcall(previous.close,previous)
    if not stopped then
        candidate:close()
        error("Previous hub shutdown failed: " .. tostring(failure),0)
    end
end
candidate:activate()
candidate.marker = {
    version = candidate.version,
    close = function() candidate:close() end,
    setMenuVisible = function(visible)
        if candidate.ui.visible ~= (visible == true) then candidate.ui:toggle() end
    end,
}
env.FERAL_RENAISSANCE_ACTIVE = candidate
env.FERAL_NOVA_PRIME_ACTIVE = candidate.marker
print("[FERAL Renaissance 15.7.1] Ready · Right Shift · client effects and gameplay outcomes tracked separately")
return candidate
