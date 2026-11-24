-- FERAL Project Renaissance 15.2.0 | v2412 client baseline
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
    { "recovery", "Survival", "Active Recovery + Fast Effects", "One recovery owner; native effects unverified" },
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
        if not previous or previous.char ~= s.char or previous.mode ~= mode
            or previous.combat ~= s.combat or previous.moving ~= s.moving
            or previous.maxHP ~= s.maxHP or s.now-previous.now < .1
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
            result.states[spec[1]] = value == true
        end
    end
    if raw.range == 300 or raw.range == 600 or raw.range == 900 then result.range = raw.range end
    result.walls = raw.walls == true or (raw.schema ~= 15 and src.walls == true)
    for _, tab in ipairs({ "Survival", "Combat", "Movement", "Vision" }) do
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
            if s.climbing or s.flying or s.underwater then return false, "movement transition" end
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
    local target = p.from == 0 and p.target or 1-p.target
    local best
    if now >= p.t0 and now < p.ends-.02
        and math.abs(Grab.triangle(now,p.t0,p.speed,p.from)-p.target) <= p.half*.5 then return now end
    for cycle = 0, math.min(32, math.ceil((p.ends-p.t0)*p.speed/2)+1) do
        for _, phase in ipairs({ target, 2-target }) do
            local t = p.t0+(2*cycle+phase)/p.speed
            if t >= math.max(now+.025,p.t0+.008) and t < p.ends-.02
                and (not best or t < best) then best = t end
        end
    end
    return best
end
function Grab.new()
    local g = { enabled = false, active = false, pending = nil, session = nil,
        seen = {}, results = {}, grades = { perfect = 0, good = 0, miss = 0 },
        status = "OFF", rejected = 0, presses = 0, lastAt = 0, sequence = 0,
        highestStrike = 0, hunters = 1, pauseUntil = 0, retimed = 0, nativeResumes = 0 }
    function g:reset(reason)
        self.active, self.pending, self.session = false, nil, nil
        self.seen, self.results = {}, {}
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
        self.highestStrike = math.max(self.highestStrike,data.k)
        local p = { session = session, strike = data.k, generation = generation,
            t0 = data.t0, ends = data.t0+duration, speed = data.spd, from = data.from,
            target = data.zc, half = data.zw*.5*perfect }
        p.at = Grab.crossing(math.max(now,self.pauseUntil), p)
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
        if not p or now < p.at-.005 then return end
        if now >= p.ends-.01 then self.pending = nil; self.status = "strike expired"; return end
        local error = math.abs(Grab.triangle(now,p.t0,p.speed,p.from)-p.target)
        if error > p.half*.88 then
            if now > p.at+p.half/p.speed then
                local nextAt = Grab.crossing(now,p)
                if nextAt then
                    p.at = nextAt
                    self.retimed += 1
                    self.status = "next native crossing scheduled"
                else self.pending = nil; self.status = "no valid crossing left" end
            end
            return
        end
        self.pending = nil -- clear before calling out, including re-entrant replies
        local ok, sent = pcall(send, p.session, p.strike, now)
        if ok and sent == true then
            self.presses += 1
            self.status = "press sent; game grade unknown"
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
        local current = lease.controller.state()
        if current == lease.state and current.ended ~= true and not bridge:nativeGrabBound()
            and (not lease.controller.script or lease.controller.script.Parent ~= nil)
            and bridge.player.Character == lease.character then
            pcall(lease.controller.bind,true)
        end
        self.status = "native inputs restored"
    end
    function i:controller(now)
        return bridge:nativeGrabController(now)
    end
    function i:update(grab,now)
        if not grab.enabled or not grab.active then
            if self.lease then self:release() end
            return false
        end
        local native = self:controller(now)
        local state = native and native.state()
        if not state or state.ended or tostring(state.id) ~= tostring(grab.session) then
            if self.lease then self:release() end
            self.status = "native input isolation unavailable"
            return false
        end
        if self.lease and (self.lease.controller ~= native or self.lease.state ~= state) then self:release() end
        if bridge:nativeGrabBound() then
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
        local mode,started,known = bridge:nativeFeedState(now)
        local invalid = not s.alive or s.chat or s.gameMenu or s.captured or s.grab or s.holding
            or s.attackHeld or now < policy.attackUntil
        if invalid then
            if self.intent or self.session or self.restart then self:cancel("feeding yielded to native action",now) end
            return
        end
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
        if now<self.nextAt or not s.alive or s.chat or s.gameMenu or s.holding or s.captured or s.feeding or s.grab then return false end
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
                if target and target.char and target.char.Parent and target.root.Parent and root then
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
            return plan
        elseif id == "recovery" then
            if not numeric(n, { "HEALTH_REGEN", "HEALTH_REST_MULT" }) then return nil, "NeedsConfig recovery schema unavailable" end
            -- At most 2x total local HP reference. Never edit combat exclusion.
            return { entry(n,"HEALTH_REGEN",n.HEALTH_REGEN*2,"number"),
                entry(n,"HEALTH_REST_MULT",1,"number") }
        elseif id == "effects" then
            local status = bridge:config("StatusConfig")
            local plan = {}
            for _, pair in ipairs({ {"INJURY","HEAL"}, {"BLEED","CLOT"}, {"VENOM","FADE"} }) do
                local c = status and status[pair[1]]
                if not numeric(c,{pair[2],"REST_MULT"}) or c[pair[2]] <= 0 then
                    return nil, "StatusConfig " .. pair[1] .. " schema unavailable"
                end
                -- Avoid v14's possible 4x base multiplied by 4x Rest = 16x.
                table.insert(plan,entry(c,pair[2],c[pair[2]]*4,"number"))
                table.insert(plan,entry(c,"REST_MULT",1,"number"))
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
    function f:reconcile(s, now, force)
        if not force and now < self.nextReconcile then return end
        self.nextReconcile = now+1.25
        for _, id in ipairs({ "reach","stamina","recovery","effects","mobility","speed","leap","climb" }) do
            local dependencies = {
                reach = {"CombatConfig"},stamina = {"NeedsConfig","FlightConfig"},
                recovery = {"NeedsConfig"},effects = {"StatusConfig"},
                mobility = {"NeedsConfig","StatusConfig"},speed = {"NeedsConfig"},
                leap = {"JumpLeapConfig"},climb = {"PassiveConfig"},
            }
            local identity,changed = {},false
            for _,name in ipairs(dependencies[id]) do
                identity[name] = bridge:config(name) or false
                if self.configIdentity[id] and self.configIdentity[id][name] ~= identity[name] then changed = true end
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
        if self.grabController and self.grabController.script == scriptObject and scriptObject.Parent then
            return self.grabController
        end
        self.grabController = nil
        if not scriptObject then self.grabDiscovery = nil; return nil end
        if self.grabDiscovery and self.grabDiscovery.script ~= scriptObject then self.grabDiscovery = nil end
        if not self.grabDiscovery and now < (self.nextGrabDiscovery or 0) then return nil end
        if (type(getgc) ~= "function" and type(getconnections) ~= "function") or type(debug) ~= "table" or type(debug.info) ~= "function" then return nil end
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
        local pool,source=self:nativeFunctions(now)
        if not pool then return nil end
        if not self.grabDiscovery or self.grabDiscovery.source~=source then
            self.nextGrabDiscovery = now+30
            self.grabDiscovery = {script=scriptObject,pool=pool,index=1,source=source}
        end
        -- Resume after the previous slice; a large GC pool must not repeatedly
        -- scan only its prefix and never reach the native UI closure.
        local discovery,started,checked = self.grabDiscovery,self.clock(),0
        while discovery.index <= #discovery.pool do
            if checked >= 384 or self.clock()-started > .012 then return nil end
            local fn = discovery.pool[discovery.index]
            discovery.index += 1; checked += 1
            if type(fn) == "function" and nativeName(fn) == "serverPress" then
                local remote = self.ReplicatedStorage:FindFirstChild("FeralGrabV2")
                local matched = false
                for _,value in pairs(upvalues(fn)) do
                    if remote ~= nil and value == remote then matched = true end
                end
                if matched then
                    local native = { press = fn,script = scriptObject }
                    native.state = function()
                        for _,value in pairs(upvalues(fn)) do
                            if type(value) == "table" and value.id ~= nil
                                and (value.role == "prey" or value.role == "hunter") then
                                if native.lastState ~= value then native.lastState,native.ownerCharacter = value,self.player.Character end
                                if native.ownerCharacter ~= self.player.Character then return nil end
                                return value
                            end
                        end
                        return nil
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
    function b:connectedNativeFunctions()
        if type(getconnections)~="function" or type(debug.info)~="function" then return {} end
        local scripts=self.player:FindFirstChild("PlayerScripts")
        local wolf=scripts and scripts:FindFirstChild("WolfController")
        local grab=scripts and scripts:FindFirstChild("FeralGrabV2UI")
        local seen,functions={},{}
        local started=self.clock()
        local function visit(fn,depth)
            if type(fn)~="function" or seen[fn] or depth>4 or #functions>=256 or self.clock()-started>.025 then return end
            seen[fn]=true
            local ok,source=pcall(debug.info,fn,"s")
            local owned=ok and type(source)=="string" and (source:find("WolfController",1,true) or source:find("FeralGrabV2UI",1,true))
            if type(getfenv)=="function" then
                local valid,env=pcall(getfenv,fn)
                if valid and type(env)=="table" and env.script~=nil then
                    owned=env.script==wolf or env.script==grab
                end
            end
            if not owned then return end
            table.insert(functions,fn)
            for _,value in pairs(self:upvalues(fn)) do if type(value)=="function" then visit(value,depth+1) end end
        end
        local signals={self.UserInputService.InputBegan,self.player:GetAttributeChangedSignal("FeralFeedTap")}
        local remote=self.ReplicatedStorage:FindFirstChild("FeralGrabV2")
        if remote and remote:IsA("RemoteEvent") then table.insert(signals,remote.OnClientEvent) end
        for _,signal in ipairs(signals) do
            local ok,connections=pcall(getconnections,signal)
            if ok and type(connections)=="table" then
                for index,connection in ipairs(connections) do
                    if index>96 then break end
                    local valid,fn=pcall(function()return connection.Function end)
                    if valid then visit(fn,0) end
                end
            end
        end
        return functions
    end
    function b:nativeFunctions(now)
        local scan=self.nativeScan
        if scan and scan.complete and now>=(scan.refreshAt or math.huge) then scan=nil end
        if not scan then
            if now<(self.nextNativeScan or 0) then return nil end
            self.nextNativeScan=now+30
            local functions=self:connectedNativeFunctions()
            scan={index=1,total=0,functions=functions,complete=false,refreshAt=now+30,heapAt=now+(#functions>0 and .08 or 0)}
            self.nativeScan=scan
        end
        if not scan.complete then
            if not scan.raw then
                if now<scan.heapAt then return scan.functions,scan end
                local ok,raw=false,nil
                if type(getgc)=="function" then ok,raw=pcall(getgc,false) end
                if not ok or type(raw)~="table" then scan.complete=true;return scan.functions,scan end
                scan.raw,scan.total=raw,#raw
            end
            local started,count=self.clock(),0
            while scan.index<=scan.total and count<32768 do
                local index=scan.index
                local value=scan.raw[index]
                scan.index+=1;count+=1
                if type(value)=="function" then table.insert(scan.functions,value) end
                if count%256==0 and self.clock()-started>.003 then break end
            end
            if scan.index>scan.total then scan.raw=nil;scan.complete=true end
        end
        return scan.functions,scan
    end
    function b:releaseNativeScan()
        local native=self.wolfActions
        if native and native.tryBite and native.toggleFeed
            and not self.wolfDiscovery and not self.grabDiscovery then self.nativeScan=nil;self.nextNativeScan=0 end
    end
    function b:closeNativeScan()
        self.nativeScan,self.wolfDiscovery,self.grabDiscovery=nil,nil,nil
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
        if native and native.tryBite and native.toggleFeed then return native end
        if not self.wolfDiscovery and now < (self.nextWolfDiscovery or 0) then return native end
        if (type(getgc) ~= "function" and type(getconnections) ~= "function") or type(debug) ~= "table" or type(debug.info) ~= "function" then return native end
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
            if count >= 384 or self.clock()-started > .008 then return native end
            local fn = scan.pool[scan.index];scan.index += 1;count += 1
            local name = nameOf(fn)
            if name == "tryBite" or name == "toggleFeed" or name == "cancelFeed" then
                local playerMatched,remoteMatched = false,false
                for _,value in pairs(self:upvalues(fn)) do
                    if value == self.player then playerMatched = true end
                    if remote and value == remote then remoteMatched = true end
                    if name == "tryBite" and nameOf(value) == "doBite" then
                        for _,upvalue in pairs(self:upvalues(value)) do
                            if remote and upvalue == remote then remoteMatched = true end
                        end
                    end
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
            generation = self.generation, alive = char ~= nil and char.Parent ~= nil and hum ~= nil and root ~= nil and hum.Health > 0,
            hp = hum and hum.Health or 0, maxHP = hum and hum.MaxHealth or 0,
            chat = self.UserInputService:GetFocusedTextBox() ~= nil,
            gameMenu = self:attribute(self.player,"FeralMenuOpen") == true,
            combat = combat, rest = self:attribute(char,"WolfRest") == true,
            feeding = false, captured = false, moving = false, locomotion = "NONE",
            injury = self:attribute(char,"FeralInjury"), bleed = self:attribute(char,"FeralBleed"),
            venom = self:attribute(char,"FeralVenomAmt"), stamina = self:attribute(char,"Stamina"),
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
        s.attackHeld = self.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            or self.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        local velocity = root.AssemblyLinearVelocity
        s.moving = hum.MoveDirection.Magnitude > .13 or Vector3.new(velocity.X,0,velocity.Z).Magnitude >= 2
        local clamp = char:FindFirstChild("FeralClamp")
        s.holding = clamp ~= nil and clamp:IsA("ObjectValue") and clamp.Value ~= nil
            or self:attribute(char,"FeralCarcassCarry") == true
        s.ability = self:attribute(char,"FeralDeathRollLocal") == true
            or self:attribute(char,"FeralRolling") == true
            or self:attribute(char,"FeralTalonLock") == true
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
        self.treeTarget = nil
        self.reachTarget = nil
        local best,score = nil,math.huge
        for _, target in ipairs(all) do
            if self:combatEligible(target.char) and target.distance <= 45 then
                if target.sameTree and (not self.treeTarget or target.distance < self.treeTarget.distance) then self.treeTarget = target end
            end
        end
        local assisted,assistScore = nil,math.huge
        local selectionModel = table.clone(changed)
        selectionModel.biteLook = baseline.biteLook
        for _,target in ipairs(all) do
            if self:combatEligible(target.char) and target.distance <= 45 then
                local geometry = self:geometry(selectionModel,s,target)
                if geometry and geometry.withinBodyRange then
                    local stock = self:geometry(baseline,s,target)
                    local rank = target.distance+(target.affiliation == "unknown" and .5 or 0)
                        -(stock and stock.valid and .75 or 0)
                    if rank < assistScore and (target.sameTree or not self:occluded(s,target)) then
                        assisted,assistScore = target,rank
                    end
                end
            end
        end
        self.reachTarget = assisted
        for _, target in ipairs(all) do
            if self:combatEligible(target.char) and target.distance <= 45 then
                local base = self:geometry(baseline,s,target)
                local extended = self:geometry(changed,s,target)
                if base or extended then
                    local rank = (extended and extended.score or math.huge) + (extended and extended.valid and 0 or 1000)
                    if rank < score then best,score = { target = target, baseline = base, extended = extended },rank end
                end
            end
        end
        if best then best.blocked = best.target.protected or self:occluded(s,best.target) end
        return best
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
            for _, key in ipairs({"WolfRest","WolfBiteAt"}) do
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
        end,false,4000,Enum.KeyCode.RightShift,Enum.KeyCode.E,Enum.KeyCode.F,Enum.KeyCode.G,
            Enum.KeyCode.Q,Enum.KeyCode.Space,Enum.UserInputType.MouseButton1,Enum.UserInputType.MouseButton2)
        scope:add(function() self.ContextActionService:UnbindAction(actionName) end)
        connect(self.UserInputService.JumpRequest,function() hub:requestFlight() end)
        connect(self.RunService.Heartbeat,function(dt)
            local ok,err = pcall(hub.tick,hub,dt)
            if not ok then hub:fault(err) end
        end)
        local renderName = actionName .. "_RENDER"
        self.RunService:BindToRenderStep(renderName,90,function(dt)
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
        tab = hub.settings.tab, lastPoint = nil }
    local palette = {
        bg = Color3.fromRGB(12,17,28), side = Color3.fromRGB(15,22,36),
        panel = Color3.fromRGB(22,31,48), line = Color3.fromRGB(48,65,85),
        text = Color3.fromRGB(239,246,252), sub = Color3.fromRGB(151,173,194),
        same = Color3.fromRGB(77,219,194), other = Color3.fromRGB(236,105,126),
        unknown = Color3.fromRGB(236,181,104), off = Color3.fromRGB(60,77,97),
    }
    local function make(class,properties,parent)
        local object = Instance.new(class)
        for key,value in pairs(properties or {}) do object[key] = value end
        object.Parent = parent
        return object
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
    text(side,"RENAISSANCE  /  15.2",18,52,140,18,10,palette.same)
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
        for _, child in ipairs(cards:GetChildren()) do child:Destroy() end
        u.rows,u.combatReadout,u.finderReadout = {},nil,nil
        title.Text = string.upper(u.tab)
        if u.tab == "Combat" then
            info(0,"BITE REACH  ·  ALWAYS ON","Wider client range with rear and vertical assistance. Server acceptance unverified.",78)
            row("biteHelper",94)
            info(161,"RANGE COLOURS","Teal: stock-reference range. Amber: extended only. Grey: blocked or leaving Rest.",80)
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
                or {"climb","flight","mobility","speed","leap"}
            for i,id in ipairs(order) do row(id,(i-1)*57) end
        end
        for name,btn in pairs(tabs) do btn.BackgroundColor3 = name == u.tab and Color3.fromRGB(27,111,98) or palette.panel end
        u.nextText = 0
    end
    for i,name in ipairs({"Survival","Combat","Movement","Vision"}) do
        local btn = button(side,string.upper(name),12,113+(i-1)*49,141,37)
        tabs[name] = btn
        btn.Activated:Connect(function()
            if not hub.active then return end
            u.tab,hub.settings.tab = name,name
            draw(); hub:save()
        end)
    end
    function u:toggle()
        self.visible = not self.visible
        frame.Visible = self.visible
        hub.policy.menuOpen = self.visible
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
            scale.Scale = math.clamp(math.min((size.X-25)/704,(size.Y-30)/505,1),.5,1)
        end
        local registry = hub.registry.byId
        for char,record in pairs(self.records) do
            local target = record.target
            local valid = char.Parent ~= nil and target.root.Parent ~= nil and target.hum.Parent ~= nil and target.hum.Health > 0
            local colour = palette[target.affiliation] or palette.unknown
            record.highlight.FillTransparency = 1
            record.highlight.OutlineColor = UI.healthColour(target.hum.Health,target.hum.MaxHealth)
            record.highlight.DepthMode = hub.settings.walls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            record.highlight.Enabled = valid and registry.esp.requested
            local head = char:FindFirstChild("Head")
            local pos = head and head:IsA("BasePart") and head.Position+Vector3.new(0,head.Size.Y*.65,0)
                or target.root.Position+Vector3.new(0,target.root.Size.Y*.6+1,0)
            local projected,onScreen = camera:WorldToViewportPoint(pos)
            local show = valid and registry.tags.requested and onScreen and projected.Z > 0
            record.label.Visible = show
            if show then
                local x,y = projected.X,math.max(20,projected.Y-6)
                record.label.Position = UDim2.fromOffset(x,y)
                record.label.Text = target.name
                record.label.TextColor3 = colour
            end
        end
        local guide = hub.guide
        dot.Visible = false
        if registry.biteHelper.requested and guide and guide.target.root.Parent then
            local point,onScreen = camera:WorldToViewportPoint(guide.target.root.Position)
            if onScreen and point.Z > 0 then
                local desired = Vector2.new(point.X,point.Y)
                self.lastPoint = self.lastPoint and self.lastPoint:Lerp(desired,1-math.exp(-22*math.min(dt,.1))) or desired
                dot.Position = UDim2.fromOffset(self.lastPoint.X,self.lastPoint.Y)
                dot.Visible = true
                local locked = hub.policy:restLocked(now)
                if guide.blocked or locked then dotStroke.Color = palette.sub
                elseif guide.baseline and guide.baseline.valid then dotStroke.Color = palette.same
                else dotStroke.Color = palette.unknown end
            end
        else self.lastPoint = nil end
        if now < self.nextText then return end
        self.nextText = now+.25
        for id,rowValue in pairs(self.rows) do
            local feature = registry[id]
            rowValue.toggle.Text = not feature.requested and "OFF"
                or feature.applied and (feature.state == "PARTIAL" and "PARTIAL"
                    or feature.state == "ARMED" and "ARMED" or "ON") or "WAIT"
            rowValue.toggle.BackgroundColor3 = feature.requested and feature.applied
                and (feature.state == "PARTIAL" and palette.unknown or Color3.fromRGB(27,111,98)) or palette.off
            rowValue.status.Text = feature.requested and feature.reason ~= "" and feature.reason or feature.detail
        end
        footer.Text = hub.rescue.pending and hub.rescue.status
            or hub.feeding.busy and hub.feeding.status or hub.notice or "Right Shift opens menu"
        if self.combatReadout then
            self.combatReadout.Text = (hub.combatStatus or "Watching native attacks") .. "\n" .. hub.rescue.status
        end
        if self.finderReadout then
            self.finderReadout.Text = string.format("%d shown · %d in range · %.0f studs",#bridge.tracked,bridge.replicatedCount or 0,hub.settings.range)
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
    local h = { version = "15.2.0", tokenIdentity = tokenIdentity,
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
        self.features.leases:release("surface")
        self.surfaceUntil = nil
        if self.drop then
            bridge:restoreAttribute(self.drop.char,"FeralFlyDrop",true,self.drop.before)
            self.drop = nil
        end
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
            if not on then self.grab:reset("OFF"); self.grabInput:release() end
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
        self.policy.manualRest,self.policy.manualIntentUntil = false,0
        self.grab:reset("animal changed")
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
                    if node:IsA("TextButton") or node:IsA("TextLabel") then body ..= " " .. node.Text end
                    if string.find(string.lower(body),"rest",1,true) then return true end
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
        local point = bridge.UserInputService:GetMouseLocation()
        if click and self.ui:contains(point) then return end
        local s = bridge:snapshot(now,false)
        if s.gameMenu then return end
        if key == Enum.KeyCode.R or key == Enum.KeyCode.Z or key == Enum.KeyCode.X
            or (click and self:isRestControl(input)) then
            self.policy:input("rest",now)
            if self.recovery.owned then self.recovery:manual(now) end
            self.combatInput:cancel();self.feeding:cancel("manual rest control",now);self.rescue:cancel()
            return
        end
        if self.grab.active and (key == Enum.KeyCode.Space or key == Enum.KeyCode.ButtonA or key == Enum.KeyCode.ButtonR2) then
            self.grab:manual()
            return
        end
        if key == Enum.KeyCode.E or (click or kind == Enum.UserInputType.Touch) and self:isFeedControl(input) then
            self.feeding:input(s,now)
            self.policy:input("action",now)
            self.recovery:release("manual feeding input",now)
            self.combatInput:cancel();self.rescue:cancel()
            return
        end
        if click then
            self.policy:input("attack",now)
            self.recovery:release("attack input",now)
            if kind == Enum.UserInputType.MouseButton1 then
                self.feeding:attack(s,now);self.rescue:cancel()
                local tx = { intent = now, lock = self.policy:restLocked(now), generation = s.generation }
                self.lastIntent = tx
                table.insert(self.transactions,tx)
                if #self.transactions > 32 then table.remove(self.transactions,1) end
                self.ledger:event("attack_intent",now,{restLock = tx.lock})
                self.combatInput:input(s,now)
            end
        elseif key == Enum.KeyCode.E or key == Enum.KeyCode.F or key == Enum.KeyCode.G
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
        if key == "WolfRest" then self.recovery:echo(s,now)
        elseif key == "WolfBiteAt" and Core.finite(bridge:attribute(s.char,key)) then
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
            if event == "begin" then bridge.nextGrabDiscovery = 0 end
            self.grabInput:update(self.grab,bridge.clock())
        end
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
                    ok and eligible and (s.underwater and "underwater; takeoff blocked" or "surface assistance armed")
                        or "waiting for flight-eligible animal")
            elseif id == "survivalAFK" then
                r:ack(id,true,"ARMED",self.walk and "safe walk active; credit unverified" or self.walkStatus or "waiting for safe idle window")
            else r:ack(id,not self.idleUnavailable,self.idleUnavailable and "UNAVAILABLE" or "ARMED",
                self.idleUnavailable and "virtual input unavailable" or "best-effort idle input; retention unverified") end
        end
        if self.settingsAvailable then r:ack("settings",true,"CLIENT","saved intent reconciled; " .. self.settingsOrigin) end
        local recovery = r.byId.recovery
        if recovery.requested then
            recovery.reason = self.recovery.state .. " · gameplay unverified"
            recovery.observed = self.recovery.nativeEchoObserved and "owned native pose echo observed locally" or "unknown"
        end
        r.byId.minigame.observed = {
            perfect = self.grab.grades.perfect,good = self.grab.grades.good,miss = self.grab.grades.miss,
            source = "matching native res replies only",
        }
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
                    self.combatStatus = tx.feedback and tx.feedback.safe==true and "Game reply: target protected"
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
        elseif self.registry.byId.flight.requested and s.flying and s.underwater and not s.grab then
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
    function h:tick()
        if not self.active or self.closed then return end
        local now = bridge.clock()
        local slow = now >= self.nextSlow
        local s = bridge:snapshot(now,slow and self.registry.byId.flight.requested)
        self.snapshot = s
        self.grab.enabled = self.registry.byId.minigame.requested
        local clock = s.serverNow
        if clock then
            local cfg = self.grab.enabled and bridge:config("GrabV2Config")
            local native = self.grab.enabled and self.grabInput:controller(now)
            if native and s.alive then
                self.grab:syncNative(native.state(),clock,s.generation,cfg and cfg.PERFECT or .32,
                    cfg and cfg.PASSES or 2.5,now)
            end
            if not s.alive and self.grab.active then self.grab:reset("animal unavailable") end
            s.grab,s.afkWalking = self.grab.active,self.walk ~= nil
            self.grabInput:update(self.grab,now)
            self.grab:tick(clock,s.generation,s.alive and self.policy:allowed("grab",s,now),
                function(session,strike,at)
                    local sent = bridge:fire("FeralGrabV2","press",session,strike,at)
                    if sent then bridge:markGrabPress(session,strike,now) end
                    return sent
                end)
        else self.grab.pending = nil; s.grab,s.afkWalking = self.grab.active,self.walk ~= nil end
        if now >= self.nextBind then self.nextBind = now+1; bridge:bindNative(self) end
        self.feeding:tick(s,now)
        self.rescue:tick(s,now)
        self.combatInput:tick(s,now)
        self.features:reconcile(s,now)
        self.recovery.enabled = self.registry.byId.recovery.requested
        self.recovery:tick(s,now)
        self:stepClimb(s,now)
        self:stepEscape(s,now)
        self:stepCombat(s,now)
        if now >= self.nextScan then
            self.nextScan = now+.12
            local candidates = bridge:candidates(s,self.settings.range)
            if self.features.originalCombat and self.features.leases:valid("reach") then
                self.guide = bridge:select(s,self.features.originalCombat,self.features.combat,candidates)
            else self.guide = nil end
            self.ui:syncTracked(bridge.tracked)
        end
        if slow then
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
        if self.recovery.owned then
            local char = bridge.player.Character
            self.recovery:echo({char = char,rest = bridge:attribute(char,"WolfRest") == true},bridge.clock())
        end
    end
    function h:render(dt)
        self:maskPose()
        self.ui:render(dt,bridge.clock())
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
        self.registry:ack("settings",true,"CLIENT","loaded settings; full reconciliation pending")
        return self
    end
    function h:close()
        if self.closed then return end
        self.active = false
        self.closed = true
        self.cleanupErrors = {}
        for _,cleanup in ipairs({
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
local moduleOrder = {"core","settings","policy","grab","grab_input","recovery","feeding","combat_input","rescue","features","roblox","ui","controller"}
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
    {"ui","mount"},{"controller","new"},
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
print("[FERAL Renaissance 15.2.0] Ready · Right Shift · client effects and gameplay outcomes tracked separately")
return candidate
