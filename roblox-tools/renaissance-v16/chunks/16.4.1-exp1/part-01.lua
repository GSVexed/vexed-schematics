-- FERAL Project Renaissance 16.4.1-exp1 | audited captures v2412 and v2415
-- Experimental movement: offline tests do not establish live server outcomes.
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
        if self.closed then
            local ok,err=pcall(fn)
            if not ok then table.insert(self.errors,tostring(err)) end
        else table.insert(self.tasks, fn) end
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
        local seen, prepared = {}, {}
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
            if type(e.value) == "number" and not Core.finite(e.value) then
                return false, "invalid numeric patch: " .. tostring(e.key)
            end
            table.insert(prepared, {target=e.target,key=e.key,value=e.value,before=value})
        end
        self.owners[owner] = {}
        for _, e in ipairs(prepared) do
            -- A getter can fail or another setter can change a later field
            -- after preflight. Unwind the earlier writes without replacing
            -- that intervening external value or leaking an owner slot.
            local readable, current = pcall(function() return e.target[e.key] end)
            if not readable or current ~= e.before then
                self:release(owner)
                return false, "field changed during patch: " .. tostring(e.key)
            end
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
    { "stamina", "Survival", "Local Stamina Conservation", "Reversible local drain/regen profile; server fatigue and ability costs remain native" },
    { "recovery", "Survival", "Active Recovery + Fast Effects", "On by default; native effects unverified", default = true },
    { "effects", "Survival", "Fast Negative-Effect Recovery", "Injury, bleed and venom measured separately", linked = "recovery" },
    { "robloxAFK", "Survival", "Roblox Anti-AFK", "Best-effort platform idle input" },
    { "survivalAFK", "Survival", "Survival Bonus AFK", "Bounded safe walks; survival credit observed separately" },
    { "minigame", "Survival", "Automatic Minigames", "Native sessions; grades come from game replies" },
    { "escape", "Survival", "Auto Escape", "Native struggle actions; friendly baby carry preserved" },
    { "reach", "Combat", "Bite Reach", "Existing expanded reach; OFF restores normal game geometry", default = true },
    { "biteHelper", "Combat", "Bite Range Helper", "Small smooth marker; native versus extended range" },
    { "attackSpeed", "Combat", "Adaptive Faster Bites", "Native repeat request pacing starts at 62% of the original cooldown, adapts to damage feedback, and respects game limits", default = true },
    { "holdBite", "Combat", "Hold to Repeat Bites", "Hold left mouse with the installed desktop helper (or middle mouse in legacy mode). Recognised feed controls are guarded during each generated click.", default = true },
    { "autoBite", "Combat", "Auto Bite", "Prefers clear stock hits; paces repeated unconfirmed extended contacts" },
    { "combat", "Combat", "Combat Core", "Native attempts and feedback; no extra hit claims", permanent = true },
    { "climb", "Movement", "Climb Assist", "Native Q buffer and one guarded retry" },
    { "flight", "Movement", "Flight Assistance", "Surface takeoff assistance; no underwater flight" },
    { "mobility", "Movement", "Movement Assistance", "Reversible local injury slowdown inputs" },
    { "speed", "Movement", "Speed Assistance", "1.15x local land and swimming inputs" },
    { "enduranceMove", "Movement", "Endurance Movement (experimental)", "Attempts native-sampled sprint pace on land while tired; other-player visibility unverified", default = true },
    { "leap", "Movement", "Jump / Leap Assistance", "1.15x local leap inputs; native exclusions retained" },
    { "zoom", "Movement", "Zoom Unlock", "Normal mouse-wheel zoom, from close-up to a distant view", default = true },
    { "esp", "Vision", "Outline ESP", "Hollow outlines for replicated characters" },
    { "colours", "Vision", "Faction / Health Colours", "Health-coloured hollow outlines; pack-coloured names", permanent = true },
    { "tags", "Vision", "Name Tags", "Small labels with independent visibility" },
    { "voice", "Vision", "Extended Proximity Hearing", "25% farther local voice rolloff when supported", default = true },
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
        if type(s) ~= "table" or not Core.finite(s.now) then
            self.previous,self.staminaObservation=nil,nil
            return
        end
        -- Keep observations independent of the mutable snapshot shared by the
        -- action owners. Reusing a snapshot must not rewrite our baseline.
        s=table.clone(s)
        mode=type(mode)=="string" and mode or "UNKNOWN"
        s.mode=mode
        local previous = self.previous
        self.previous = s
        if previous and (previous.char~=s.char or previous.species~=s.species) then
            self.rates={}
        end
        if previous and previous.char==s.char and previous.species==s.species
            and previous.mode==mode
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
            or s.now-previous.now > 1.5 then return end
        local dt = s.now-previous.now
        local key = mode .. ":" .. tostring(s.combat) .. ":" .. (s.moving and "moving" or "still")
        local bucket = self.rates[key] or { seconds = 0, hp = 0, effects = {}, stamina = {} }
        self.rates[key] = bucket
        bucket.seconds += dt
        if Core.finite(s.hp) and Core.finite(previous.hp) and Core.finite(previous.maxHP)
            and previous.maxHP>0 and previous.hp>=0 and s.hp<=s.maxHP and previous.hp < previous.maxHP-.2 then
            if s.hp >= previous.hp then
                bucket.hp += s.hp-previous.hp
                bucket.hpSeconds=(bucket.hpSeconds or 0)+dt
                bucket.hpNormalized=(bucket.hpNormalized or 0)+(s.hp-previous.hp)/s.maxHP
            else bucket.damage = (bucket.damage or 0)+1 end
        end
        for _, name in ipairs({ "injury", "bleed", "venom" }) do
            local a, b = previous[name], s[name]
            if Core.finite(a) and Core.finite(b) and a > 0 and b >= 0 and b <= a then
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
sources["compat"] = [============[
-- Interface capabilities are separate from compiler-specific closure layouts.
-- 2415 evidence: Hippo/HUD/Needs programs identical to 2412; Wolf tryBite,
-- biteCooldown and toggleFeed instructions unchanged. See compatibility.json.
local Compat = {}
local layouts = {
    [2412]={wolfTiming=true,feedTiming=true,hippoFinish=true,hippoMovement=true,debugStamina=true},
    [2415]={wolfTiming=true,feedTiming=true,hippoFinish=true,hippoMovement=true,debugStamina=false},
}
function Compat.layout(version,name)
    return layouts[version]~=nil and layouts[version][name]==true
end
function Compat.known(version) return layouts[version]~=nil end
function Compat.has(b,name)
    local finite=b.Core.finite
    if name=="wolfTiming" or name=="feedTiming" or name=="hippoFinish" then
        return Compat.layout(game.PlaceVersion,name)
    elseif name=="debugStamina" then
        if Compat.layout(game.PlaceVersion,name) then return true end
        if game.PlaceVersion~=2415 or type(b.RunService.IsStudio)~="function" then return false end
        local ok,studio=pcall(b.RunService.IsStudio,b.RunService)
        return ok and studio==true
    elseif name=="biteCadence" then
        local s=b:config("Species")
        return type(s)=="table" and type(s.biteCooldown)=="function" and type(s.DEFAULT)=="string"
    elseif name=="coneBonus" then
        local c=b:config("CombatConfig")
        return type(c)=="table" and finite(c.CONE) and type(c.BITE_CONE_ADD)=="table"
            and type(c.coneFor)=="function"
    elseif name=="hippoMovement" then
        -- The movement owner independently checks scaled/List fields and the
        -- exact reversible SPEED_CAP before each lease. Only its arithmetic
        -- layout is versioned here; charging diagnostics need extra fields.
        return Compat.layout(game.PlaceVersion,"hippoMovement")
    elseif name=="hippoProfile" then
        local c=b:config("AbilityConfig") or b:config("AbilityConfigBase")
        local p=c and c.CrusherBite
        if type(p)~="table" then return false end
        for _,key in ipairs({"CHARGE_TIME","MULT_START","MULT_MAX","CURVE","OVERHOLD"}) do
            if not finite(p[key]) then return false end
        end
        if p.CHARGE_TIME<=0 or p.CHARGE_TIME>30 or p.MULT_START<0 or p.MULT_MAX<p.MULT_START
            or p.CURVE<=0 or p.CURVE>8 or p.OVERHOLD<0 or p.OVERHOLD>60 then return false end
        return true
    elseif name=="hudGait" then
        -- Each actual Frame/Cap/UIStroke relationship is validated by the painter.
        return Compat.known(game.PlaceVersion)
    end
    return false
end
return Compat
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
    result.walls = raw.walls == true or (raw.walls == nil and raw.schema ~= 15 and src.walls == true)
    for _, tab in ipairs({ "Survival", "Combat", "Movement", "Vision", "Territory", "Hippo", "Test Features" }) do
        if raw.tab == tab then result.tab = tab end
    end
    return result
end

-- Decodable JSON is not necessarily a settings file. An empty or unrelated
-- object must not hide a valid backup containing the user's explicit OFFs.
function Settings.recognized(raw, specs)
    if type(raw)~="table" or type(raw.states)~="table" then return false end
    for _,spec in ipairs(specs) do
        if not spec.permanent and not spec.linked and type(raw.states[spec[1]])=="boolean" then return true end
    end
    if type(raw.states.endurance)=="boolean" then return true end
    return raw.schema==Settings.schema and next(raw.states)==nil
        and (raw.range==300 or raw.range==600 or raw.range==900)
        and type(raw.walls)=="boolean" and type(raw.tab)=="string"
end

function Settings.load(io, specs)
    for _, path in ipairs({ Settings.path, Settings.backup, Settings.legacy }) do
        local ok, raw = pcall(io.read, path)
        if ok and Settings.recognized(raw, specs) then
            return Settings.sanitize(raw, specs), path == Settings.path and "loaded" or "migrated"
        end
    end
    return Settings.sanitize(nil, specs), "defaults"
end

function Settings.save(io, value, specs)
    local clean = Settings.sanitize(value, specs)
    -- Backup protects the last readable settings if the executor stops mid-write.
    local readOK, old = pcall(io.read, Settings.path)
    if readOK and Settings.recognized(old, specs) then
        local backup=Settings.sanitize(old, specs)
        local ok, why = pcall(io.write, Settings.backup, backup)
        if not ok or why == false then return false, "backup write unavailable" end
        local readable, stored=pcall(io.read,Settings.backup)
        if not readable or not Settings.recognized(stored,specs) then return false,"backup verification failed" end
        for key,state in pairs(backup.states) do
            if stored.states[key]~=state then return false,"backup verification mismatch" end
        end
        if stored.range~=backup.range or stored.walls~=backup.walls or stored.tab~=backup.tab then
            return false,"backup verification mismatch"
        end
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
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e12 end
function Policy.new()
    local p = { attackUntil = 0, actionUntil = 0, lastRestRelease = -math.huge,
        manualIntentUntil = 0, manualRest = false, lastPhysical = 0, menuOpen = false,
        combatApproachUntil = 0 }
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
            -- Nearby animals alone do not cancel recovery. Actual input and
            -- native combat/ability ownership decide; this preserves mixpacking.
            if now < self.actionUntil or s.afkWalking then return false, "action has priority" end
            -- The original live-tested Rest signal worked while the own
            -- animal was moving; surface swimming is ordinary locomotion, not
            -- an attack. Protect aerial, climb and submerged transitions.
            if s.climbing or s.flying or s.underwater then return false, "movement transition" end
            -- Combat time can be unknown when the server clock is unavailable.
            -- That must not silently disable the separate condition request.
            -- HP is still excluded while combat is true or unknown.
            if purpose == "effects" then
                return true,s.combat == true and "condition Rest while in combat; no combat HP claim"
                    or s.combat == nil and "condition Rest; combat state unknown, HP excluded"
                    or "condition Rest, no combat"
            end
            if s.combat ~= false then return false, s.combat and "combat" or "combat state unknown" end
            return true, "recovery window"
        end
        if self.manualRest or s.rest then return false, "manual Rest" end
        if s.feeding or s.ability then return false, "native action" end
        if s.rescuing then return false,"cub rescue input" end
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
            if not finite(s.hp) or not finite(s.maxHP) or s.maxHP<=0 or s.hp<0 then return false,"health unavailable" end
            if s.hp < s.maxHP*.8 then return false, "health deficit" end
            for _, key in ipairs({ "injury", "bleed", "venom" }) do
                if not finite(s[key]) or s[key]<0 or s[key] > .1 then return false, "status or unknown status" end
            end
            if not finite(s.hunger) or not finite(s.thirst)
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
        submitted = {}, history = {}, firstWindows = 0, dispatches = {}, retired = {}, retirementOrder = {} }
    function g:retire()
        if not self.session then return end
        local key=tostring(self.session)
        if self.retired[key]==self.generation then return end
        self.retired[key]=self.generation
        table.insert(self.retirementOrder,{key=key,generation=self.generation})
        if #self.retirementOrder>32 then
            local old=table.remove(self.retirementOrder,1)
            if self.retired[old.key]==old.generation then self.retired[old.key]=nil end
        end
    end
    function g:reset(reason)
        self.active, self.pending, self.session = false, nil, nil
        self.seen, self.results, self.submitted, self.history = {}, {}, {}, {}
        self.highestStrike,self.pauseUntil = 0,0
        self.role,self.hunters=nil,1 -- never retain a prior session role or hunter count
        self.status = reason or "waiting for native session"
        self.sequence += 1
    end
    function g:event(event, data, now, generation, perfect, passes, context)
        if not self.enabled or not finite(now) or type(event) ~= "string" or type(data) ~= "table" then return false end
        local session = data.f or (event == "begin" and data.id)
        if not id(session) then self.rejected += 1; return false end
        local sessionKey = tostring(session)
        if event == "begin" then
            if self.retired[sessionKey]==generation then self.rejected+=1;return false end
            if tostring(self.session) ~= sessionKey or self.generation ~= generation then
                self:retire()
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
        if event == "end" then self:retire();self:reset("native session ended"); return true end
        if event == "n" then
            if finite(data.n) and data.n >= 0 and data.n <= 128 then self.hunters = data.n end
            self.lastAt = now -- joining/leaving hunters does not cancel the strike
            return true
        end
        if event == "bite" then
            self.pending, self.lastAt = nil, now
            local pause=context and context.bitePause
            self.pauseUntil = now+(finite(pause) and pause>=0 and math.min(pause,3) or .6)
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
            if self.active then
                -- This is the current native UI state, not an unrelated event.
                -- Practice or an ended replacement retires the previous fight.
                if state.ended or state.practice then self:retire() end
                self:reset(state.practice and "practice session excluded" or "native session ended")
            end
            return
        end
        if not self.active or self.generation ~= generation or tostring(self.session) ~= tostring(state.id) then
            if not self:event("begin",{f=state.id,role=state.role,n=state.n},now,generation,perfect,passes) then return end
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
        if not finite(now) then return end
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
        local ok, sent,why,actual = pcall(send, p.session, p.strike, now)
        if ok and sent == true then
            self.presses += 1
            if self.sequence==sequence then self.submitted[tostring(p.strike)] = true end
            if not p.later then self.firstWindows += 1 end
            table.insert(self.dispatches,{delay=now-p.received,afterOpening=now-p.at,
                later=p.later==true,error=error,perfectHalf=p.half})
            if #self.dispatches>32 then table.remove(self.dispatches,1) end
            if self.sequence==sequence and not self.results[tostring(p.strike)] then self.status = "press sent; game grade unknown" end
        elseif ok and sent==false and why=="clock_moved" and finite(actual)
            and self.sequence==sequence and self.active and self.pending==nil
            and not self.results[tostring(p.strike)] and (p.dispatchChecks or 0)<3 then
            -- The final actual-time check can cross the window while the
            -- callback is being inspected. No press was issued on this path,
            -- so retain the real strike for its next legal interval.
            p.dispatchChecks=(p.dispatchChecks or 0)+1
            local at,closes=Grab.crossing(math.max(actual,now+.001),p)
            if at then
                p.at,p.closes,p.later=at,closes,true
                self.pending=p;self.retimed+=1;self.status="actual clock moved; next legal crossing"
            else self.status="no valid crossing left" end
        elseif self.sequence==sequence and self.pending==nil then self.status = "native press unavailable" end
        self.lastAt = math.max(self.lastAt,now)
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
local function read(native)
    if not native or type(native.state)~="function" then return nil,false end
    local ok,state,known=pcall(native.state)
    if ok then return state,known end
    return nil,false
end
function GrabInput.new(bridge,token)
    local i = { lease = nil, status = "waiting for native session", name = "FERAL_GRAB_INPUT_" .. token }
    function i:release()
        local lease = self.lease
        self.lease = nil
        pcall(bridge.unbindGrabManual,bridge,self.name)
        if not lease then return end
        local current,known = read(lease.controller)
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
        state = state or read(native)
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
                if not grab.enabled or not grab.active or self.lease ~= lease or bridge:grabTextFocused() then return false end
                local current = read(native)
                if current ~= state or current.ended or tostring(current.id) ~= tostring(grab.session) then return false end
                grab:manual()
                return pcall(native.press)
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
                    self.conditionSeen[key]=value>0 and now+.9 or nil
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
]============]
sources["feeding"] = [============[
-- Protect the user's native feeding session; never changes hunger/thirst values.
local Feeding = {}
function Feeding.new(bridge,policy,ledger)
    local f = { intent=nil,session=nil,restart=nil,status="",busy=false }
    function f:cancel(reason,now)
        local active=self.intent or self.session or self.restart or self.busy
        self.intent,self.session,self.restart,self.carryRetry,self.busy = nil,nil,nil,nil,false
        self.mode,self.started,self.known,self.nextProbe=nil,nil,false,0
        self.status = reason or ""
        if active then policy.actionUntil = math.max(policy.actionUntil,now+.45) end
    end
    function f:input(s,now)
        self.nextProbe=0
        if s.feeding or self.intent or self.restart then self:cancel("manual feeding toggle",now);return end
        local kind = bridge:attribute(s.char,"FeedCan")
        if kind == "eat" or kind == "drink" then
            self.intent = {char=s.char,generation=s.generation,kind=kind,untilAt=now+6}
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
        if self.intent and (self.intent.char ~= s.char or self.intent.generation~=s.generation or now > self.intent.untilAt
            or known and mode == nil and not self.restart and now > self.intent.untilAt-5.65) then self.intent=nil end
        if self.session and (self.session.char ~= s.char or self.session.generation~=s.generation
            or s.feedMode ~= self.session.kind and (not known or mode~=self.session.kind)) and not self.restart then self.session=nil end
        if self.carryRetry and (self.carryRetry.char~=s.char or self.carryRetry.generation~=s.generation
            or now>self.carryRetry.untilAt) then self.carryRetry=nil end
        local active = s.feedMode
        local pending = known and mode ~= nil or self.intent ~= nil or self.restart ~= nil
        self.busy = s.feeding or pending
        s.feeding = self.busy
        if self.restart then
            local r = self.restart
            if r.char ~= s.char or r.generation~=s.generation or s.moving or now > r.untilAt then self:cancel("feeding restart cancelled",now);return end
            if now >= r.at and known and mode == nil and bridge:attribute(s.char,"FeedCan") == r.kind then
                self.restart=nil
                -- Original toggleFeed owns approach, selection, eligibility and Feed.
                local sent = bridge:toggleNativeFeed(now)
                self.intent = sent and {char=s.char,generation=s.generation,kind=r.kind,untilAt=now+6} or nil
                self.carryRetry = sent and {char=s.char,generation=s.generation,kind=r.kind,untilAt=now+6} or nil
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
        if type(value) ~= "number" or value ~= value or math.abs(value)>=1e12 then self.status="Feeding; resource unavailable";return end
        local session = self.session
        if not session or session.kind ~= active or session.char ~= s.char then
            session = {char=s.char,generation=s.generation,kind=active,last=value,progressAt=now,
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
        if type(maximum) ~= "number" or maximum~=maximum or maximum<=0 or maximum>=1e12 then maximum=100 end
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
        self.restart={char=s.char,generation=s.generation,kind=active,at=now+.18,untilAt=now+1.3}
        -- Re-read the current native mode at cancellation. A stale toggle
        -- would otherwise start feeding after the native session already ended.
        local stopped = bridge:stopNativeFeed(now)
        ledger:event("native_feed_stall_repair",now,{called=stopped==true})
        if not stopped then self.restart=nil;self.status="Feeding stalled; native restart unavailable" end
    end
    function f:close(now) self:cancel("",now) end
    return f
end
return Feeding
]============]
sources["combat_input"] = [============[
-- Original WolfController.tryBite is the preferred dispatch. Never inject BiteHit,
-- synthesize hit replies, or infer accepted damage from a local bite sound.
-- A guarded physical-input fallback is used only for *held* human input when
-- the private callback is unavailable; never for passive/automatic attacks.
local CombatInput = {}
function CombatInput.new(bridge,policy,ledger)
    local middleMode=bridge.holdBinding=="M3"
    local c = {
        pending=nil, held=nil, awaiting=nil, nextAttempt=0, markerCount=0,
        status="native input", fallbackMisses=0, unavailableUntil=0,
        speedFactor=.62, goodStreak=0, suspectStreak=0,
        lastRateChange=-math.huge, lastMarker=nil, lastDispatch=0,
        nativeMisses=0,middleCandidate=middleMode and bridge.middleRoutePreference~="NATIVE" and "INPUT" or nil,middleRoute=nil,
        middleRouteMarkers=0,middleNativeAttempts=0,middleInputAttempts=0,
    }
    local function stopDiscovery()
        bridge.wantHeldNativeDiscovery=false
        -- A cancelled, unfinished lookup has not established unavailability.
        -- A fresh press may restart it; completed negative searches retain
        -- the bridge's normal retry backoff.
        if bridge.wolfHeapScan then bridge.nextWolfHeapScan=0 end
        bridge.wolfHeapScan=nil
    end
    function c:factor()
        return self.speedFactor
    end
    function c:resetRate()
        self.speedFactor,self.goodStreak,self.suspectStreak=.62,0,0
        self.lastRateChange=-math.huge
    end
    -- Feedback changes only the requested local timing, never server outcomes.
    -- A confirmed, uniquely matched positive damage response is the only
    -- evidence that permits accelerating below the initial 62% cadence.
    function c:confirmed(now)
        self.suspectStreak=0
        self.goodStreak+=1
        if self.goodStreak>=3 and now-self.lastRateChange>=1.8 then
            self.speedFactor=math.max(.55,math.floor((self.speedFactor-.025)*1000+.5)/1000)
            self.lastRateChange=now
            self.goodStreak=0
            ledger:event("cadence_confidence_increased",now,{factor=self.speedFactor})
        end
    end
    -- Three *clean* stock-range contact windows without verified damage
    -- may indicate server cadence rejection, so slow down rather than spam.
    function c:suspect(now)
        self.goodStreak=0
        self.suspectStreak+=1
        if self.suspectStreak>=3 and now-self.lastRateChange>=1 then
            self.speedFactor=math.min(1,math.floor((self.speedFactor+.08)*1000+.5)/1000)
            self.lastRateChange=now
            self.suspectStreak=0
            ledger:event("cadence_backoff",now,{factor=self.speedFactor})
        end
    end
    function c:cancel()
        self.pending,self.held,self.awaiting=nil,nil,nil
        stopDiscovery()
        if type(bridge.releaseSyntheticBite)=="function" then bridge:releaseSyntheticBite() end
        self.nextAttempt=0
    end
    -- Temporary native action transitions must not discard an accepted M3
    -- press. Hard cancellation is reserved for release, focus, UI, OFF,
    -- manual Rest, or loss of the current animal.
    function c:pause(reason,now)
        if not middleMode or not self.held or self.held.key~="M3" then
            self:cancel()
            return
        end
        self.pending,self.awaiting=nil,nil
        stopDiscovery()
        if type(bridge.releaseSyntheticBite)=="function" then bridge:releaseSyntheticBite() end
        self.nextAttempt=math.max(self.nextAttempt,now+.20)
        self.status=reason.." · middle hold retained"
    end
    -- Standard input is the production M3 route. Explicit native compatibility
    -- mode may probe only until its first attributable marker.
    function c:noteNativeMiss(now)
        if not middleMode or not self.held or self.held.key~="M3" then return end
        self.nativeMisses=math.min(3,self.nativeMisses+1)
        if self.nativeMisses>=3 then
            if not self.middleRoute and self.middleCandidate=="NATIVE"
                and type(bridge.hasHeldInputBackend)=="function" and bridge:hasHeldInputBackend() then
                self.middleCandidate="INPUT"
                stopDiscovery()
                ledger:event("m3_initial_route_probe_changed",now,{route="INPUT"})
            else
                -- A verified route may pause but never hands off to another method.
                self.nextAttempt=math.max(self.nextAttempt,now+.4)
            end
        end
    end
    function c:manualAttack(now)
        if middleMode and self.awaiting and self.awaiting.middle then
            self.awaiting=nil
            self.nextAttempt=math.max(self.nextAttempt,now+.12)
        end
    end
    function c:confirmMiddleRoute(waiting,s,now)
        if not middleMode or not waiting or not waiting.middle or not self.held
            or self.held.key~="M3" or self.held.char~=s.char
            or self.held.generation~=s.generation or waiting.char~=s.char
            or waiting.generation~=s.generation then return end
        local route=waiting.backend
        if route~="NATIVE" and route~="INPUT" then return end
        if route=="NATIVE" and (s.mouseHeld or s.r2Held) then return end
        if route=="INPUT" and not bridge.heldInputBackend then return end
        if self.middleRoute and self.middleRoute~=route then return end
        if not self.middleRoute then
            self.middleRoute,self.middleCandidate=route,route
            self.middleVerifiedAt=now
            if route=="INPUT" then bridge.heldInputLockedBackend=bridge.heldInputBackend end
            ledger:event("m3_route_verified_and_locked",now,{route=route,adapter=bridge.heldInputLockedBackend})
        end
        self.middleRouteMarkers+=1
    end
    function c:middleReport()
        return {binding=bridge.desktopLeftHold and "LMB_DESKTOP" or middleMode and "M3" or "M1",route=self.middleRoute,
            candidate=self.middleCandidate,verifiedAt=self.middleVerifiedAt,
            attributableMarkers=self.middleRouteMarkers,nativeAttempts=self.middleNativeAttempts,
            inputAttempts=self.middleInputAttempts,adapter=bridge.heldInputLockedBackend,
            held=self.held~=nil,status=self.status,admission=self.middleAdmission,
            inputBlockReason=bridge.heldInputBlockReason,feedGuardPulses=bridge.feedGuardPulses or 0,
            serverDamageVerified=false}
    end
    function c:release(kind,now)
        if self.held and (kind==nil or self.held.key==kind or self.held.key=="poll") then
            -- A single tap made during an owned Rest-exit window must still
            -- deliver its one buffered native bite after M1/R2 is released.
            -- Only the continuous repeat intent stops on InputEnded.
            self.held,self.awaiting=nil,nil
            stopDiscovery()
            if type(bridge.releaseSyntheticBite)=="function" then bridge:releaseSyntheticBite() end
            self.nextAttempt=now or 0
            self.status=self.pending and "one Rest-exit bite queued" or "released"
        end
    end
    function c:marker(s,now)
        local waiting=self.awaiting
        self:confirmMiddleRoute(waiting,s,now)
        if waiting and waiting.backend=="NATIVE" and (not middleMode or self.middleRoute=="NATIVE") then self.nativeMisses=0 end
        if waiting and waiting.backend=="INPUT"
            and (not middleMode or self.middleRoute=="INPUT")
            and type(bridge.noteHeldInputMarker)=="function" then
            bridge:noteHeldInputMarker()
        end
        self.pending,self.awaiting=nil,nil
        self.lastMarker=now
        self.markerCount+=1
        self.fallbackMisses=0
        self.unavailableUntil=0
        self.status="native bite marker observed; impact unverified"
    end
    function c:input(s,now,kind,inputObject)
        if not s.alive then return end
        if middleMode then
            if kind=="M3" then
                if self.held and self.held.key=="M3" and self.held.char==s.char
                    and self.held.generation==s.generation then return end
                self.held={char=s.char,generation=s.generation,key="M3",
                    source="event",input=inputObject,startedAt=now,handoff=true}
                self.fallbackMisses,self.unavailableUntil=0,0
                self.nextAttempt=math.max(self.nextAttempt,now+.025)
                self.status="middle mouse held"
                ledger:event("physical_m3_hold_started",now)
                return
            end
        else
            -- The first genuine M1 click belongs entirely to the game. Only
            -- after one uninterrupted hold crosses the tap/hold threshold does
            -- the hub take over repeating. New taps always start a fresh timer.
            self.held={char=s.char,generation=s.generation,key=kind or "mouse",
                source="event",input=inputObject,startedAt=now,handoff=kind=="R2"}
            self.nextAttempt=math.max(self.nextAttempt,now+.025)
        end
        if not policy:restLocked(now,bridge:restLock(s.char)) then return end
        local at=math.max(now+.025,policy.lastRestRelease+bridge:restLock(s.char)+.035)
        self.pending={char=s.char,generation=s.generation,at=at,untilAt=math.max(now+1.6,at+.35),
            marker=bridge:attribute(s.char,"WolfBiteAt"),input=inputObject}
        policy.attackUntil=math.max(policy.attackUntil,at+.3)
        ledger:event("bite_waiting_for_rest_exit",now)
    end
    function c:tick(s,now,options)
        options=options or {}
        if options.inputSuspended then
            self:cancel()
            self.status="input suspended; waiting for a fresh press"
            return
        end
        if middleMode then
            -- Fresh world InputBegan owns M3. Polling only revokes stale ownership.
            if self.held then
                if s.middleHeldKnown and s.middleHeld then
                    self.held.seenDown=true;self.held.upSince=nil
                elseif s.middleHeldKnown and self.held.seenDown then
                    self.held.upSince=self.held.upSince or now
                end
                if not options.repeatHeld or self.held.char~=s.char
                    or self.held.generation~=s.generation
                    or self.held.upSince and now-self.held.upSince>.35 then
                    self:release("M3",now)
                elseif self.held.upSince then
                    -- Stop dispatch immediately on an uncertain physical release,
                    -- but keep the press through a short polling dropout.
                    if type(bridge.releaseSyntheticBite)=="function" then bridge:releaseSyntheticBite() end
                    self.awaiting=nil
                    self.status="middle button temporarily unconfirmed"
                    return
                end
            end
        else
            local physical=s.attackHeld==true
            if not options.repeatHeld then
                if self.held then self:release(nil,now) end
            elseif physical and not bridge.syntheticM1
                and now>=(bridge.syntheticM1Until or 0)
                and (not self.held or self.held.char~=s.char or self.held.generation~=s.generation) then
                -- Hub enabled after M1 was already pressed: wait a fresh hold
                -- threshold before dispatching repeats.
                self.held={char=s.char,generation=s.generation,key="poll",source="poll",
                    startedAt=now,handoff=false}
                self.nextAttempt=math.max(self.nextAttempt,now+.025)
            elseif self.held and (self.held.char~=s.char or self.held.generation~=s.generation
                or self.held.source=="poll" and not physical) then
                self:release(nil,now)
            end
            -- The real InputBegan object, not a potentially unreliable native
            -- mouse-down poll, owns this hold until its actual InputEnded.
            -- Focus loss, UI, ability/Rest and hub unload still revoke it.
            if self.held and not self.held.handoff and
                (self.held.key=="M1" or self.held.key=="poll") then
                local age=now-(self.held.startedAt or now)
                if age>=.28 then
                    self.held.handoff=true
                    self.nextAttempt=math.max(self.nextAttempt,now+.015)
                    ledger:event("physical_m1_hold_handoff",now,{age=age})
                end
            end
        end
        local inGrab=s.grab==true or options.minigameBusy==true
        local nativeGrabLane=inGrab and options.nativeMinigame==true
            and self.held~=nil and (self.held.key=="M3" or self.held.key=="M1" or self.held.key=="poll")
            and (not middleMode or (self.middleRoute or self.middleCandidate)~="INPUT")
            and options.minigamePressNear~=true
            and bridge.wolfActions and type(bridge.wolfActions.tryBite)=="function"
        if not s.alive or s.chat or s.gameMenu or s.protectedInteraction or inGrab and not nativeGrabLane
            or policy.manualRest or options.uiBlocked then
            self.pending,self.awaiting=nil,nil
            stopDiscovery()
            if type(bridge.releaseSyntheticBite)=="function" then bridge:releaseSyntheticBite() end
            -- Preserve the event-held state across a *known* minigame, so
            -- continuing to hold resumes after its native end. OFF and
            -- InputEnded always clear it; menus/text clear it immediately.
            -- Hovering over an existing hub window pauses attacks, but does
            -- not revoke an M1 that began in the world. An actual UI press
            -- cancels ownership in Controller.preInput, and InputEnded clears
            -- it even while hovering. This prevents one hover from ending a
            -- continuous real hold until the user clicks again.
            if not s.alive or s.chat or s.gameMenu then self.held=nil end
            self.nextAttempt=now+.12
            self.status=(options.minigameBusy or s.grab) and "minigame has priority" or "native action has priority"
            return
        end
        if middleMode and bridge.syntheticM1 then return end
        local p=self.pending
        if p and (p.char~=s.char or p.generation~=s.generation or now>p.untilAt
            or bridge:attribute(s.char,"WolfBiteAt")~=p.marker) then
            self.pending=nil;p=nil
        end
        local held=options.repeatHeld and self.held~=nil and self.held.handoff==true
            and (not middleMode or inGrab or not (s.mouseHeld or s.r2Held))
        -- Holding M1 explicitly takes priority over Auto Bite target
        -- selection. Ordinary clicks before the handoff remain game-owned.
        local automatic=not inGrab and options.automatic and options.targetValid==true
            and self.held==nil and (not middleMode or not (s.mouseHeld or s.r2Held))
        if inGrab and not nativeGrabLane then automatic=false end
        if not p and not held and not automatic then
            -- A quick manual tap is never repeated by this controller.
            -- No callback/simulated mouse edge is dispatched until handoff.
            self.awaiting=nil
            self.status=self.held and (middleMode and "manual attack has priority" or "manual M1 tap; waiting for sustained hold") or "idle"
            return
        end
        if s.feeding or s.captured or s.holding or s.ability or s.rest then
            self.pending=nil
            if middleMode then self.awaiting=nil end
            if type(bridge.releaseSyntheticBite)=="function" then bridge:releaseSyntheticBite() end
            self.status="native action lock; hold retained"
            return
        end
        local waiting=self.awaiting
        if waiting and (waiting.char~=s.char or waiting.generation~=s.generation) then
            self.awaiting=nil;waiting=nil
        end
        if waiting then
            if middleMode and waiting.backend=="INPUT" and bridge.heldInputBlockReason then
                self.awaiting=nil
                self.nextAttempt=math.max(self.nextAttempt,now+.12)
                self.status="M3 held; "..bridge.heldInputBlockReason
                return
            end
            if now-waiting.at<math.max(.18,bridge:biteDelay(s.char)+.10) then return end
            self.awaiting=nil
            self.nextAttempt=math.max(self.nextAttempt,now+.18)
            if waiting.backend=="INPUT" and type(bridge.noteHeldInputTimeout)=="function" then
                bridge:noteHeldInputTimeout()
            end
            if waiting.backend=="NATIVE" and not inGrab then self:noteNativeMiss(now) end
            self.fallbackMisses+=(waiting.backend=="NATIVE_INPUT" or waiting.backend=="INPUT") and 1 or 0
            if self.fallbackMisses>=3 then
                self.unavailableUntil=now+2.5
                self.fallbackMisses=0
            end
            self.status="no native marker; checking original game cooldown"
            ledger:event("native_bite_marker_timeout",now,{backend=waiting.backend})
            return
        end
        if now<self.nextAttempt or p and now<p.at or now<self.unavailableUntil then return end
        local middleHeld=middleMode and held and self.held.key=="M3"
        if held and (not middleHeld or (self.middleRoute or self.middleCandidate)~="INPUT")
            and not (bridge.wolfActions and type(bridge.wolfActions.tryBite)=="function")
            and type(bridge.nativeWolfActions)=="function" then
            -- The input-event connection path may be unavailable in the
            -- executor's VM even when the original WolfController closure is
            -- discoverable via getgc. Request validation only while held.
            bridge.wantHeldNativeDiscovery=true
            bridge:nativeWolfActions(now)
        end
        local route
        if middleHeld then
            route=self.middleRoute or self.middleCandidate
            if not route then
                if bridge.wolfActions and type(bridge.wolfActions.tryBite)=="function" then
                    route="NATIVE"
                elseif not inGrab and type(bridge.hasHeldInputBackend)=="function"
                    and bridge:hasHeldInputBackend() then
                    route="INPUT"
                end
                if route then
                    self.middleCandidate=route
                    ledger:event("m3_initial_route_selected",now,{route=route})
                end
            end
            if not route then
                self.status="middle held; waiting for a supported attack route"
                self.nextAttempt=now+.15
                return
            end
        end
        local readiness=bridge:biteReadiness(s,now,policy)
        local allowed=readiness.ready
        -- If a game's original callback is private, visible cooldown + own
        -- BiteAt marker still offer a bounded path for held user input.
        -- This path never enables Auto Bite or ignores a known Rest/minigame lock.
        local privateUnknown=not readiness.known
            and (readiness.reason=="native timing unavailable"
                or readiness.reason=="native timing layout unknown")
        if not allowed and privateUnknown and held and not automatic then
            -- The native tryBite owns its cooldown. Its private timing
            -- upvalue offsets cannot be inferred after an update. The
            -- original onInput fallback remains gated by the visible stock
            -- bite cooldown and a genuine original M1 InputObject.
            local original=bridge.wolfActions and bridge.wolfActions.tryBite
            if type(original)=="function" and route~="INPUT" and (not inGrab or nativeGrabLane) then
                allowed=true
            elseif not inGrab and self.held and ((self.held.key=="M1" and self.held.input)
                or middleMode and self.held.key=="M3") then
                allowed=type(bridge.visibleBiteWindow)=="function"
                    and bridge:visibleBiteWindow(s,now) or false
            end
        end
        if not allowed then
            self.status=readiness.reason
            self.nextAttempt=readiness.nextAt and math.max(now+.015,readiness.nextAt) or now+.08
            return
        end
        if options.beforeAttempt then
            local ok,released=pcall(options.beforeAttempt,s,now)
            if not ok or released==false then
                self.pending,self.awaiting=nil,nil
                self.nextAttempt=now+.2
                self.status="native action release not confirmed"
                ledger:event("native_bite_preparation_failed",now,{callbackSucceeded=ok})
                return
            end
        end
        -- A chosen M3 route remains exclusive. Native/manual compatibility
        -- and the separate Auto Bite feature keep their original dispatch.
        local native=bridge.wolfActions and bridge.wolfActions.tryBite
        if middleHeld and route=="INPUT" then native=nil end
        local nativeInput=not native and held and not automatic and not inGrab
            and self.held and self.held.key=="M1" and self.held.source=="event"
            and self.held.input and type(bridge.nativeWolfInputAction)=="function"
            and bridge:nativeWolfInputAction(now) or nil
        local ordinary=middleHeld and route=="INPUT" and not inGrab
            and not automatic and self.held.key=="M3"
            and not (s.mouseHeld or s.r2Held or s.physicalM1Held)
            and type(bridge.tryHeldInputBite)=="function"
            and type(bridge.visibleBiteWindow)=="function" and bridge:visibleBiteWindow(s,now)
        if type(native)~="function" and not nativeInput and not ordinary then
            self.nextAttempt=now+.12
            self.status=middleHeld and (route=="INPUT" and "ordinary route waiting for native cooldown or manual input"
                or "native route waiting for original callback")
                or "waiting for native attack handler"
            return
        end
        -- The only dispatch sources are validated original game functions.
        -- Preserve Rest-exit intent until an actual native dispatcher exists.
        self.pending=nil
        self.lastDispatch=now
        local markers=self.markerCount
        -- Keep the existing working Adaptive Faster Bites factor unchanged.
        -- It controls native-request timing, not game/server cooldown.
        local cooldown=type(bridge.nativeBiteCooldown)=="function"
            and bridge:nativeBiteCooldown(s) or nil
        if type(cooldown)=="number" and cooldown==cooldown
            and cooldown>=.03 and cooldown<=30 then
            -- Species.biteCooldown already carries the adaptive lease. Scaling
            -- it again produces 0.62^2 pacing and extra rejected attempts.
            self.nextAttempt=now+math.max(.04,cooldown)
        else
            self.nextAttempt=now+.065
        end
        local called,backend
        if type(native)=="function" then backend="NATIVE"
        elseif nativeInput then backend="NATIVE_INPUT"
        else backend="INPUT" end
        local attempt={char=s.char,generation=s.generation,at=now,backend=backend,middle=middleHeld==true}
        if middleHeld then
            if backend=="NATIVE" then self.middleNativeAttempts+=1
            else self.middleInputAttempts+=1 end
            -- Record before invocation: the original game can emit its marker
            -- synchronously, before the callback returns.
            self.awaiting=attempt
        end
        if backend=="NATIVE" then
            called=bridge:tryNativeBite(now)
        elseif backend=="NATIVE_INPUT" then
            called=bridge:tryNativeInputBite(now,self.held.input)
        else
            called=bridge:tryHeldInputBite(s,now)
        end
        local marked=self.markerCount>markers
        if backend=="NATIVE" and marked then self.nativeMisses=0 end
        if backend=="NATIVE" and not called and not inGrab then self:noteNativeMiss(now) end
        if called and not marked then
            self.awaiting=attempt
        elseif self.awaiting==attempt then
            self.awaiting=nil
        end
        if not called then
            self.lastDispatch=0
            self.nextAttempt=math.max(self.nextAttempt,now+.3)
        end
        self.status=marked and "native marker; awaiting server-confirmed impact"
            or called and (backend=="INPUT" and "M3 ordinary-input route; awaiting native marker"
                or backend=="NATIVE_INPUT" and "own original input handler called; awaiting native marker"
                or "original native bite callback called; awaiting marker")
            or (backend=="INPUT" and bridge.heldInputBlockReason and ("M3 held; "..bridge.heldInputBlockReason))
            or "validated native attack handler unavailable"
        ledger:event(p and "native_bite_buffer_released" or "native_cadence_attempt",now,{
            called=called==true,marker=marked,backend=backend,automatic=automatic==true,
            minigameNative=nativeGrabLane==true,
            damageAcceptance="unverified"})
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
        if self.pending then
            local carrying=s.holding or bridge:carrying(s,self.pending.target.char)
            self:cancel("Cub rescue cancelled")
            -- A native pickup may complete between heartbeats. The next G
            -- must reach the game's drop binding rather than being swallowed.
            return not carrying
        end
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
            or s.captured or s.grab or s.feeding or s.attackHeld or s.ability or s.holding or now>p.untilAt then
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
            self.status="Native water lock; jump or move to the ba