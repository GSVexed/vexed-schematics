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
    { "attackSpeed", "Combat", "Faster Bites", "55% client cooldown with delayed-contact floor; server rate unverified", default = true },
    { "holdBite", "Combat", "Hold to Repeat Bites", "Hold left click or R2; native attacks repeat at readiness", default = true },
    { "autoBite", "Combat", "Auto Bite", "Selected clear target only; native readiness required" },
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
    { "hippoMove", "Hippo", "Move During Charge", "Hippo only; native sprint and Burst inputs", default = true },
    { "hippoRelease", "Hippo", "Smart Crusher Release", "Release full charge at a clear target; manual holds by default" },
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
