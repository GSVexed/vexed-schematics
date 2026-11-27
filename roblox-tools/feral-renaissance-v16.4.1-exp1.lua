-- FERAL Project Renaissance 16.4.1-exp1 | audited captures v2412 and v2415
-- Release candidate: offline tests do not establish live server outcomes.
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
sources["hippo"] = [============[
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
        if type(item.target)~="table" or item.key==nil then return nil,"invalid feature field" end
        local fields=seen[item.target]
        if not fields then fields={};seen[item.target]=fields end
        local previous=fields[item.key]
        if previous then
            if previous.value~=item.value or previous.kind~=item.kind then
                return nil,"conflicting aliased feature field: "..tostring(item.key)
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
        -- 2415 reads this flag only inside IsStudio gates. Keep the independent
        -- consumption leases, and never paint an ineffective flag as unlimited.
        on=on and bridge:capability("debugStamina")
        if self.flag and (not on or not s.alive or self.flag.char ~= s.char) then self:releaseFlag() end
        if not on or self.flagConflict~=s.char then self.flagConflict=nil end
        if on and s.alive then
            if self.flagConflict==s.char then return false end
            if self.flag then
                if bridge:attribute(s.char,"WolfDbgNoStamina")==true then return true end
                -- The game/another owner replaced our value. Never repeatedly
                -- overwrite it; keep the independently valid config profile.
                self.flag,self.flagConflict=nil,s.char
                return false
            end
            local before=bridge:attribute(s.char,"WolfDbgNoStamina")
            if bridge:setAttribute(s.char,"WolfDbgNoStamina",true) then
                self.flag={char=s.char,before=before};return true
            end
            return false
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
                    -- Captured CombatConfig.coneFor (p1) adds AnimProfile,
                    -- then Species, BITE_CONE_ADD to CONE. Clamping the native
                    -- closure to stock CONE lost the legitimate species bonus
                    -- after our own shared CONE change.
                    if bridge:capability("coneBonus") and type(original.BITE_CONE_ADD)=="table" then
                        local add=original.BITE_CONE_ADD[bridge:attribute(char,"AnimProfile") or ""]
                            or original.BITE_CONE_ADD[bridge:attribute(char,"Species") or ""] or 0
                        return original.CONE+(Core.finite(add) and add or 0)
                    end
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
                return math.clamp(value,0,180)
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
                if bridge:currentTargetBody(target) and root and char==bridge.player.Character
                    and bridge:combatEligible(target.char) then
                    local diff = target.root.Position-root.Position
                    if bridge.predictionActive and char==bridge.player.Character then
                        diff=bridge:leadPoint({char=char,root=root},target)-root.Position
                    end
                    local flat = Vector3.new(diff.X,0,diff.Z)
                    local look = Vector3.new(native.X,0,native.Z)
                    if diff.Magnitude <= 45 and flat.Magnitude > .05
                        and (bridge.predictionActive or target.sameTree or look.Magnitude < .01 or look.Unit:Dot(flat.Unit) < .3) then
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
                if char==bridge.player.Character and bridge:isClimbing(char)
                    and bridge:currentTargetBody(bridge.treeTarget) and bridge.treeTarget.sameTree then
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
            -- v2412 NeedsConfig.BURST has its own finite DRAIN scalar.
            -- Keep native start eligibility, speed, animation and stamina values.
            zero(n.BURST,"DRAIN")
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
        elseif id == "attackSpeed" then
            local species=bridge:config("Species")
            if not bridge:capability("biteCadence") or type(species)~="table" or type(species.biteCooldown)~="function" then
                return nil,"compatible native bite cadence unavailable"
            end
            local original=species.biteCooldown
            local wrapper=function(name,growth,...)
                local value=original(name,growth,...)
                local char=bridge.player.Character
                if not char or not char.Parent or not bridge:capability("biteCadence")
                    or name~=(bridge:attribute(char,"Species") or species.DEFAULT)
                    or not Core.finite(value) or value<=0 or value>30 then return value end
                -- Keep delayed claims ordered; never slow an already faster
                -- native profile. The server may enforce its original cadence.
                local adaptive=bridge.combatGovernor and bridge.combatGovernor:factor() or .62
                -- Never drive contact claims faster than the game's native
                -- contact delay. Raise the interval after repeated clean
                -- no-damage contacts, lower it only on confirmed replies.
                return math.min(value,math.max(value*adaptive,bridge:biteDelay(char)+.055,.08))
            end
            return {entry(species,"biteCooldown",wrapper,"function")}
        elseif id == "recovery" then
            if not numeric(n, { "HEALTH_REGEN", "HEALTH_REST_MULT" }) then return nil, "NeedsConfig recovery schema unavailable" end
            if n.HEALTH_REST_MULT < 1 then return nil,"native HP Rest multiplier unavailable" end
            -- Preserve both native rates. A higher newly observed Rest factor
            -- is not a reason to lower ordinary healing to fit an old label.
            -- Native Rest signaling, not a client-side rate edit, is the feature.
            return { entry(n,"HEALTH_REGEN",n.HEALTH_REGEN,"number"),
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
                -- Keep every independently supplied native condition rate,
                -- including profiles whose Rest factor differs from v2412.
                table.insert(plan,entry(c,pair[2],c[pair[2]],"number"))
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
            return Features.uniquePlan(plan)
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
    -- One decision drives both the charge-speed calculation and the native
    -- HUD presentation. Never change WolfController's gait or Burst flags.
    function f:hippoTier(char,field,hippo,needs)
        if bridge.player.Character~=char or not char or not char.Parent
            or bridge:attribute(char,"Species")~="Hippo" or not bridge:capability("hippoMovement") then return nil end
        local charge=bridge:attribute(char,"FeralCrushAt")
        if charge==nil or charge==false or bridge:attribute(char,"WolfRest")==true
            or bridge:attribute(char,"FeralCrouch")==true
            or bridge:attribute(char,"FeralSrvTired")==true or bridge:attribute(char,"FeralNoSprint")==true
            or bridge:attribute(char,"FeralPinned")==true or bridge:attribute(char,"FeralCarried")==true
            or bridge:attribute(char,"FeralDragged")==true or bridge.UserInputService:GetFocusedTextBox()
            or bridge:attribute(bridge.player,"FeralMenuOpen")==true then return nil end
        local combat=bridge:config("CombatConfig")
        if combat and type(combat.hobbled)=="function" then
            local ok,hobbled=pcall(combat.hobbled,char)
            if not ok or hobbled then return nil end
        end
        local shift=false
        pcall(function()shift=bridge.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)end)
        local burst=self.hippoIntentChar==char and self.hippoBurstIntent==true
        local denial=bridge:attribute(bridge.player,"HudBurstNo")
        if denial==true or Core.finite(denial) and bridge.clock()>=denial and bridge.clock()-denial<1.7
            or bridge:attribute(char,"StaminaOut")==true then burst=false;self.hippoBurstIntent=false end
        if not shift and not burst then return nil end
        local multiplier=1
        if burst then
            local boost=needs and needs.BURST
            local key=field=="swimSpeed" and "SWIM_SPEED" or "SPEED"
            local n=boost and (boost[key] or boost.SPEED)
            if not boost or boost.ENABLED~=true or not Core.finite(n) or n<1 or n>3 then
                if not shift then return nil end
                burst=false
            else multiplier=n end
        end
        if field=="swimSpeed" then
            if not Core.finite(hippo.swimSprint) or hippo.swimSprint<=0 then return nil end
        elseif not Core.finite(needs and needs.RUN_SPEED) or needs.RUN_SPEED<=0
            or not Core.finite(hippo.speed) then return nil end
        return burst and "burst" or "sprint",multiplier
    end
    function f:paintHippoGait()
        local record=self.hippoScaled
        local char=bridge.player.Character
        local tier
        if registry.byId.hippoMove.requested and record and record.char==char
            and self.leases:valid("hippoGait") and char and char.Parent then
            local field=bridge:attribute(char,"FeralSwimLocal")==true and "swimSpeed" or "gait"
            tier=self:hippoTier(char,field,record.profile,bridge:config("NeedsConfig"))
        end
        bridge:paintHippoGait(tier)
    end
    function f:reconcileHippoGait(s)
        if not registry.byId.hippoMove.requested then self.hippoGaitConflict=nil end
        local cfg=registry.byId.hippoMove.requested and s.alive and s.species=="Hippo" and bridge:config("Species")
        local hippo=cfg and cfg.List and cfg.List.Hippo
        if self.hippoScaled and (not hippo or self.hippoScaled.cfg~=cfg or self.hippoScaled.char~=s.char
            or self.hippoScaled.profile~=hippo) then
            self.leases:release("hippoGait");self.hippoScaled=nil
        end
        if self.hippoGaitConflict and self.hippoGaitConflict.cfg==cfg and self.hippoGaitConflict.char==s.char then return end
        if not hippo or type(cfg.scaled)~="function" or not numeric(hippo,{"speed","gait"})
            or not bridge:capability("hippoMovement") then return end
        if self.hippoScaled then
            if not self.leases:valid("hippoGait") then self.leases:release("hippoGait");self.hippoScaled=nil;self.hippoGaitConflict={cfg=cfg,char=s.char} end
            return
        end
        local original=cfg.scaled
        local char=s.char
        local wrapper=function(species,field,growth,...)
            local result=original(species,field,growth,...)
            if species~="Hippo" or (field~="gait" and field~="swimSpeed") or bridge.player.Character~=char
                or not char.Parent or not bridge:capability("hippoMovement") or cfg.List.Hippo~=hippo then return result end
            local needs=bridge:config("NeedsConfig")
            local tier,multiplier=self:hippoTier(char,field,hippo,needs)
            if not tier then return result end
            if field=="swimSpeed" then
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
            self.hippoStatus=tier=="burst" and "BURST_SPEED_REQUESTED" or "SPRINT_SPEED_REQUESTED"
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
        local hippo=registry.byId.hippoMove.requested and s.alive and s.species=="Hippo" and bridge:capability("hippoMovement")
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
        if not hippo then
            self.hippoCapConflict=nil
            self.hippoStatus=not registry.byId.hippoMove.requested and "OFF"
                or s.species=="Hippo" and not bridge:capability("hippoMovement") and "INCOMPATIBLE_PROFILE" or "WAITING";return
        end
        local conflict=self.hippoCapConflict
        if conflict and conflict.char==s.char and (not profile or conflict.profile==profile) then
            self.hippoStatus="CONFLICT";return
        end
        self.hippoCapConflict=nil
        if self.leases.owners.hippoCrush then
            if self.leases:valid("hippoCrush") then
                self.hippoStatus="CLIENT";return
            end
            -- An external edit owns this value now; don't overwrite it.
            self.hippoCapConflict={profile=self.hippoProfile,char=s.char}
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
    -- Ordinary combat and the guide must remain available without a geometry lease.
    function f:combatProfileReady()
        return self.originalCombat~=nil and self.combat~=nil
            and (self.combatProfileMode=="native" or self.leases:valid("reach"))
    end
    function f:reconcile(s, now, force)
        if not force and now < self.nextReconcile then return end
        self.nextReconcile = now+1.25
        for _, id in ipairs({ "reach","stamina","recovery","effects","mobility","speed","leap","climb","attackSpeed" }) do
            local dependencies = {
                reach = {"CombatConfig"},stamina = {"NeedsConfig","FlightConfig","PassiveConfig","VenomConfig","StatusConfig"},
                attackSpeed = {"Species"},
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
                identity.burst=type(identity.NeedsConfig)=="table" and identity.NeedsConfig.BURST or false
                for _,name in ipairs({"climb","levels","sprint","venom","burst"}) do
                    if self.configIdentity[id] and self.configIdentity[id][name]~=identity[name] then changed=true end
                end
                for level=1,3 do
                    local name="climbLevel"..level
                    identity[name]=climb and type(climb.levels)=="table" and climb.levels[level] or false
                    if self.configIdentity[id] and self.configIdentity[id][name]~=identity[name] then changed=true end
                end
            end
            local function reference(key,value)
                identity[key]=value or false
                if self.configIdentity[id] and self.configIdentity[id][key]~=identity[key] then changed=true end
            end
            if id=="effects" or id=="mobility" then
                local status=identity.StatusConfig
                for _,kind in ipairs(id=="mobility" and {"INJURY"} or {"INJURY","BLEED","VENOM"}) do
                    reference("status:"..kind,type(status)=="table" and status[kind])
                end
            elseif id=="leap" then
                reference("bodyLengths",type(identity.JumpLeapConfig)=="table" and identity.JumpLeapConfig.BODY_LENGTHS)
            elseif id=="climb" then
                local passive=identity.PassiveConfig
                local climb=type(passive)=="table" and passive.CLIMBER
                reference("climb",climb)
                reference("levels",type(climb)=="table" and climb.levels)
                for level=1,2 do
                    reference("climbLevel"..level,type(climb)=="table" and type(climb.levels)=="table" and climb.levels[level])
                end
            elseif id=="reach" then
                local combat=identity.CombatConfig
                for _,key in ipairs({"HIT2","BITE_CONE_ADD"}) do reference(key,type(combat)=="table" and combat[key]) end
            end
            if id=="stamina" then
                local sprint=identity.sprint
                local count=0
                if type(sprint)=="table" then
                    for species,profile in pairs(sprint) do
                        if type(species)=="string" then
                            count+=1;reference("sprint:"..species,profile)
                        end
                    end
                end
                reference("sprintCount",count)
                -- Removed profiles must also retire their ownership.
                for key in pairs(self.configIdentity[id] or {}) do
                    if type(key)=="string" and key:sub(1,7)=="sprint:" and identity[key]==nil then changed=true end
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
            if id=="reach" then
                if record.applied then
                    self.combatProfileMode="experimental"
                else
                    -- Native compatibility is deliberately read-only: the guide
                    -- and ordinary attacks share the unmodified game profile.
                    local c=bridge:config("CombatConfig")
                    local changedProfile=self.combatProfileMode~="native" or self.originalCombat~=c
                    if numeric(c,{"REACH","HIT_SCALE","CONE","SLACK","MAX_DY"})
                        and type(c.bodyGap)=="function" then
                        self.originalCombat,self.combat=c,c
                        self.combatProfileMode="native"
                    else
                        self.originalCombat,self.combat,self.combatProfileMode=nil,nil,nil
                    end
                    if changedProfile then bridge.reachTarget,bridge.treeTarget=nil,nil end
                end
            end
        end
        self:reconcileHippo(s)
        local stamina = registry.byId.stamina
        if not self:flagCharacter(s,stamina.requested and stamina.applied) and stamina.requested then
            registry:ack("stamina",false,"PARTIAL","local config applied; character flag unavailable")
        end
        if stamina.requested and self.leases:valid("stamina") and not bridge:capability("debugStamina") then
            registry:ack("stamina",true,"PARTIAL",s.serverTired and
                "local drain controls applied; game reports server fatigue" or
                "local drain controls applied; server fatigue and ability costs remain native")
        end
    end
    function f:close()
        bridge:paintHippoGait(nil)
        self:releaseFlag()
        self.leases:close()
    end
    return f
end
return Features
]============]
sources["endurance"] = [============[
-- Experimental, own-character movement assistance. This can alter local
-- Humanoid speed; it does not change server stamina or prove peer replication.
local Endurance={}
local function horizontal(v)
    if not v then return nil end
    local x,z=v.X,v.Z
    if type(x)~="number" or type(z)~="number" then return nil end
    return math.sqrt(x*x+z*z)
end
function Endurance.new(Core,bridge)
    local e={enabled=false,status="OFF",baseline=nil,character=nil,owned=nil,
        suspendedUntil=0,externalVerified=false,observedSpeed=nil,corrections=0}
    function e:release()
        local o=self.owned;self.owned=nil
        self.appliedSince=nil;self.lowMotionSince=nil
        if o and o.hum and o.hum.Parent and o.hum.WalkSpeed==o.target then
            pcall(function()o.hum.WalkSpeed=o.before end)
        end
    end
    function e:reset()
        self:release();self.character=nil;self.baseline=nil;self.lastPosition=nil
        self.lastPositionAt=nil;self.suspendedUntil=0;self.suspendReason=nil;self.observedSpeed=nil
    end
    function e:setEnabled(on)
        self.enabled=on==true
        if not self.enabled then self:reset();self.status="OFF" end
    end
    function e:close() self:setEnabled(false) end
    function e:render(s,now,focused)
        if not self.enabled then return end
        if game.PlaceVersion~=2415 then
            self:reset();self.status="Endurance experiment needs audited build 2415";return
        end
        if not s or not s.alive or not s.char or not s.hum or not s.root then
            self:reset();self.status="Waiting for animal";return
        end
        if s.char~=self.character then
            self:reset();self.character=s.char
        end
        local hum=s.hum
        local native=hum.WalkSpeed
        if not Core.finite(native) or native<=0 or native>250 then
            self:release();self.status="Native movement speed unavailable";return
        end
        if self.owned and (self.owned.hum~=hum or native~=self.owned.target) then
            -- The native controller (or another owner) replaced our value.
            -- Never restore an older speed on top of its new value.
            self.owned=nil
        end
        local currentOwned=self.owned~=nil
        local ground=not s.swimming and not s.underwater and not s.flying and not s.climbing
            and s.hum.FloorMaterial~=Enum.Material.Air and s.hum.FloorMaterial~=Enum.Material.Water
        local clear=ground and not s.rest and not s.feeding and not s.captured and not s.ability
            and not s.noSprint and not s.holding
            and not s.grab and not s.chat and not s.gameMenu and not s.protectedInteraction
            and focused~=false and s.hum.MoveDirection.Magnitude>.55
        local inputOK,sprint=pcall(bridge.UserInputService.IsKeyDown,
            bridge.UserInputService,Enum.KeyCode.LeftShift)
        clear=clear and inputOK and sprint==true
        local tired=s.serverTired==true or bridge:attribute(s.char,"StaminaOut")==true
        if clear and not tired and not currentOwned
            and (not self.baseline or native>=self.baseline*.95)
            and s.stamina and s.maxStamina
            and Core.finite(s.stamina) and Core.finite(s.maxStamina) and s.maxStamina>0
            and s.stamina/s.maxStamina>=.35
            and bridge:attribute(bridge.player,"HudSprint")==true then
            -- Calibrate against the game's own healthy sprint on this animal.
            -- Never invent a speed from a remote argument or an old species.
            self.baseline=native
            self.status="Healthy native sprint sampled"
        end
        if not clear or not tired then
            self:release()
            native=hum.WalkSpeed
            self.lastPosition,self.lastPositionAt=nil,nil
            if not clear then self.status="Paused for native movement or input"
            elseif not self.baseline then self.status="Waiting for healthy sprint sample"
            elseif native<self.baseline*.95 then self.status="Waiting for native sprint to recover"
            else self.status="Native sprint available" end
            return
        end
        if now<self.suspendedUntil then
            self:release();self.status=self.suspendReason or "Movement assistance paused";return
        end
        if not self.baseline or not Core.finite(self.baseline) or self.baseline<=0 then
            self:release();self.status="Waiting for healthy sprint sample";return
        end
        local position=s.root.Position
        if self.lastPosition and self.lastPositionAt and Core.finite(now-self.lastPositionAt)
            and now>self.lastPositionAt and now-self.lastPositionAt<.25 then
            local dx,dz=position.X-self.lastPosition.X,position.Z-self.lastPosition.Z
            local distance=math.sqrt(dx*dx+dz*dz)
            if distance>math.max(14,self.baseline*(now-self.lastPositionAt)*4) then
                -- An abrupt own-character correction/teleport is enough to
                -- suspend the experiment; it is not proof of server rejection.
                self:release();self.suspendedUntil=now+8;self.corrections+=1
                self.suspendReason="Abrupt movement; assistance paused"
                self.status=self.suspendReason
                self.lastPosition,self.lastPositionAt=nil,nil
                return
            end
        end
        self.lastPosition,self.lastPositionAt=position,now
        self.observedSpeed=horizontal(s.root.AssemblyLinearVelocity)
        if self.appliedSince and self.observedSpeed
            and self.observedSpeed<self.baseline*.4 then
            self.lowMotionSince=self.lowMotionSince or now
            if now-self.lowMotionSince>=1.5 then
                self:release();self.suspendedUntil=now+8
                self.suspendReason="No sustained local movement; assistance paused"
                self.status=self.suspendReason
                return
            end
        else self.lowMotionSince=nil end
        if currentOwned then
            self.status="Local pace held; other-client view unverified"
            return
        end
        if native>=self.baseline*.95 then
            self.status="Native pace already sustained";return
        end
        -- No position, velocity, CFrame, animation, stamina or server writes.
        -- A native overwrite is observed afresh on the next frame.
        local target=self.baseline
        local ok=pcall(function()hum.WalkSpeed=target end)
        if not ok or hum.WalkSpeed~=target then
            self.status="Movement property unavailable";return
        end
        self.owned={hum=hum,before=native,target=target}
        self.appliedSince=self.appliedSince or now
        self.status="Local pace requested; other-client view unverified"
    end
    return e
end
return Endurance
]============]
sources["roblox"] = [============[
-- Roblox boundary. Staging creates only inactive, owner-scoped listeners.
local Roblox = {}
function Roblox.new(Core, environment)
    local b = { Core = Core, env = environment, generation = 0, modules = {},
        remoteConnections = {}, characterScope = nil, treeTarget = nil, tracked = {},
        sourceBaseline = 2412, captureVersion = 2415, placeVersion = game.PlaceVersion }
    for _, name in ipairs({ "Players","ReplicatedStorage","RunService","UserInputService",
        "ContextActionService","HttpService","Workspace" }) do b[name] = game:GetService(name) end
    b.player = assert(b.Players.LocalPlayer,"LocalPlayer unavailable")
    b.clock = os.clock
    function b:capability(name)
        return Core.compat~=nil and Core.compat.has(self,name)==true
    end
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
    function b:protectedInteraction(char)
        local wrestle=self:attribute(char,"FeralWrestle")
        if wrestle~=nil and wrestle~=false then return "native wrestling minigame" end
        -- Birth/stronghold phases can persist while their panel is closed.
        -- FeralBirthClient's open/close functions export actual modal ownership
        -- through FeralPanelHold; do not disable combat merely for owning a nest.
        local panel=self:attribute(self.player,"FeralPanelHold")
        if panel~=nil and panel~=false then return "native modal panel" end
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
    -- FeralHUD v2412 builds a Cluster with three named gait outlines. Paint
    -- those native keycaps only; HudTrot/HudSprint/HudBurst also feed other
    -- scripts and cannot be used as presentation-only flags.
    function b:paintHippoGait(tier)
        local painted=self.hippoGaitPaint
        local function restore()
            self.hippoGaitPaint=nil
            if not painted then return end
            for _,record in pairs(painted.keys) do
                if record.rim.Parent and record.rim.Color==record.paintedColor then
                    pcall(function()record.rim.Color=record.beforeColor end)
                end
                if record.cap.Parent and record.cap.BackgroundTransparency==record.paintedAlpha then
                    pcall(function()record.cap.BackgroundTransparency=record.beforeAlpha end)
                end
            end
        end
        if tier~="sprint" and tier~="burst" or not self:capability("hudGait") then
            restore();return false
        end
        local gui=self.player:FindFirstChild("PlayerGui")
        gui=gui and gui:FindFirstChild("FeralHUD")
        local cluster=painted and painted.gui==gui and painted.cluster.Parent and painted.cluster
            or gui and gui:FindFirstChild("Cluster",true)
        if not cluster then restore();return false end
        if painted and painted.cluster~=cluster then restore();painted=nil end
        if not painted then
            local keys={}
            for _,name in ipairs({"trot","sprint","burst"}) do
                local outline=cluster:FindFirstChild(name,true)
                local cap=outline and outline:IsA("Frame") and outline:FindFirstChild("Cap")
                local rim=cap and cap:IsA("Frame") and cap:FindFirstChildOfClass("UIStroke")
                if not rim then return false end
                keys[name]={outline=outline,cap=cap,rim=rim,
                    beforeColor=rim.Color,beforeAlpha=cap.BackgroundTransparency}
            end
            painted={gui=gui,cluster=cluster,keys=keys};self.hippoGaitPaint=painted
        end
        local activeColor=painted.keys.trot.beforeColor
        local quietColor=painted.keys.sprint.beforeColor
        for name,record in pairs(painted.keys) do
            if not record.outline:IsDescendantOf(cluster) or record.cap.Parent~=record.outline
                or record.rim.Parent~=record.cap then restore();return false end
            local selected=name==tier
            local desiredColor=selected and activeColor or quietColor
            local desiredAlpha=selected and painted.keys.trot.beforeAlpha or painted.keys.sprint.beforeAlpha
            if record.rim.Color~=desiredColor then record.rim.Color=desiredColor end
            if record.cap.BackgroundTransparency~=desiredAlpha then record.cap.BackgroundTransparency=desiredAlpha end
            record.paintedColor,record.paintedAlpha=desiredColor,desiredAlpha
        end
        return true
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
        if not native or type(native.state)~="function" then return false end
        local readable,state=pcall(native.state)
        if readable and type(state)=="table" and not state.ended and tostring(state.id) == tostring(session)
            and type(state.strike) == "table" and state.strike.k == strike then
            -- Annotation is optional; a native read/write failure after the
            -- actual dispatch must not make the coordinator retry that input.
            return pcall(function() state.strike.pressed = true end)
        end
        return false
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
            -- A stale/ended session must immediately return native controls,
            -- even before the next coordinator heartbeat removes this binding.
            if state == Enum.UserInputState.Begin and press() == true then
                return Enum.ContextActionResult.Sink
            end
            return Enum.ContextActionResult.Pass
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
                    local handle=inherited
                    if type(inherited.current)~="function" then
                        -- Upgrade a pre-16.0 hot-reload handle without changing
                        -- the previous controller's still-owned callback table.
                        handle=table.clone(inherited)
                        handle.current=function()
                            local currentScripts=self.player:FindFirstChild("PlayerScripts")
                            return scriptObject.Parent~=nil and currentScripts~=nil
                                and currentScripts:FindFirstChild("FeralGrabV2UI")==scriptObject
                                and self.ReplicatedStorage:FindFirstChild("FeralGrabV2")==remote
                                and remote.Parent~=nil
                        end
                        handle.state=function()
                            if not handle.current() then return nil,true end
                            return inherited.state()
                        end
                        handle.bind=function(on)
                            if not handle.current() then return false end
                            return inherited.bind(on)
                        end
                    end
                    handle.remote=remote
                    self.grabController=handle;return handle
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
                    native.current = function()
                        local currentScripts=self.player:FindFirstChild("PlayerScripts")
                        return scriptObject.Parent~=nil and currentScripts~=nil
                            and currentScripts:FindFirstChild("FeralGrabV2UI")==scriptObject
                            and self.ReplicatedStorage:FindFirstChild("FeralGrabV2")==remote
                            and remote.Parent~=nil
                    end
                    native.state = function()
                        -- A replacement service has ended this handle's ownership,
                        -- even if the old closure still exposes a readable session.
                        if not native.current() then return nil,true end
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
                        if not native.current() then return false end
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
        local wolfRemote=self.ReplicatedStorage:FindFirstChild("WolfActions")
        local grabRemote=self.ReplicatedStorage:FindFirstChild("FeralGrabV2")
        local scan=self.nativeScan
        if scan and (scan.wolf~=wolf or scan.grab~=grab or scan.wolfRemote~=wolfRemote
            or scan.grabRemote~=grabRemote or scan.complete and now>=scan.refreshAt) then scan=nil end
        if not scan then
            local signals={self.UserInputService.InputBegan,self.player:GetAttributeChangedSignal("FeralFeedTap")}
            local remote=self.ReplicatedStorage:FindFirstChild("FeralGrabV2")
            if remote and remote:IsA("RemoteEvent") then table.insert(signals,remote.OnClientEvent) end
            scan={wolf=wolf,grab=grab,wolfRemote=wolfRemote,grabRemote=grabRemote,
                functions={},seen={},queue={},cursor=1,signalIndex=1,
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
        self.hippoActions,self.hippoDiscovery=nil,nil
        self.biteTiming=nil
        self.wolfHeapScan,self.wantHeldNativeDiscovery=nil,nil
        self.wolfInputAction,self.nextWolfInputLookup=nil,nil
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
    -- Function names alone are not authority. Every cached or discovered
    -- action must belong to our current WolfController and capture our player
    -- and current remote. Locate relationships by identity; closure upvalue
    -- order is compiler detail and is only used by the versioned timing reader.
    function b:wolfFunctionName(fn,own)
        if type(fn)~="function" or type(debug)~="table" or type(debug.info)~="function" then return nil end
        local ok,source,name=pcall(debug.info,fn,"sn")
        if not ok then return nil end
        local owned=type(source)=="string" and (source=="WolfController"
            or source:match("[%.%/]WolfController$")~=nil)
        if type(getfenv)=="function" then
            local valid,env=pcall(getfenv,fn)
            if valid and type(env)=="table" and env.script~=nil then
                if env.script~=own then return nil end
                owned=true
            end
        end
        return owned and name or nil
    end
    function b:validateWolfBite(fn,own,remote)
        if self:wolfFunctionName(fn,own)~="tryBite" then return nil end
        local playerMatched,doBite,cooldown=false,nil,nil
        local count=0
        for _,value in pairs(self:upvalues(fn)) do
            count+=1;if count>64 then return nil end
            if value==self.player then playerMatched=true end
            local name=self:wolfFunctionName(value,own)
            if name=="biteCooldown" then
                if cooldown and cooldown~=value then return nil end
                cooldown=value
            elseif name=="doBite" then
                local ownPlayer,ownRemote=false,false
                local hitCount=0
                for _,hitValue in pairs(self:upvalues(value)) do
                    hitCount+=1;if hitCount>64 then return nil end
                    if hitValue==self.player then ownPlayer=true end
                    if hitValue==remote then ownRemote=true end
                end
                if ownPlayer and ownRemote then
                    if doBite and doBite~=value then return nil end
                    doBite=value
                end
            end
        end
        if not playerMatched or not doBite or not cooldown then return nil end
        return {script=own,remote=remote,placeVersion=game.PlaceVersion,
            tryBite=fn,doBite=doBite,biteCooldown=cooldown}
    end
    function b:validateWolfFeed(fn,own,remote,expectedName)
        if self:wolfFunctionName(fn,own)~=expectedName then return false end
        local playerMatched,remoteMatched=false,false
        local count=0
        for _,value in pairs(self:upvalues(fn)) do
            count+=1;if count>64 then return false end
            if value==self.player then playerMatched=true end
            if value==remote then remoteMatched=true end
        end
        return playerMatched and remoteMatched
    end
    function b:resetWolfDiscovery()
        self.wolfActions,self.wolfDiscovery,self.biteTiming=nil,nil,nil
        self.wolfInputAction,self.nextWolfInputLookup=nil,nil
        self.wolfHeapScan=nil
        -- The callback queue is shared with the minigame owner. Missing or
        -- replaced WolfController must not erase the other consumer's work;
        -- nativeFunctions checks both script and remote identities itself.
        self.nextWolfDiscovery,self.nextWolfHeapScan=0,0
    end
    -- Opt-in fallback for executors where the game's InputBegan connections
    -- are hidden but the same local WolfController closures are available in
    -- getgc(). Never search another player's script or call an unvalidated fn.
    -- Heap enumeration happens only after a physical hold requests a repeat,
    -- and is bounded over subsequent heartbeats rather than a blocking scan.
    function b:recoverWolfBiteFromHeap(now)
        if not self.wantHeldNativeDiscovery or self.deferNativeDiscovery
            or type(getgc)~="function" or type(debug)~="table"
            or type(debug.info)~="function" then return nil end
        local scripts=self.player:FindFirstChild("PlayerScripts")
        local own=scripts and scripts:FindFirstChild("WolfController")
        local remote=self.ReplicatedStorage:FindFirstChild("WolfActions")
        if not own or not own:IsA("LocalScript") or not remote
            or not remote:IsA("RemoteEvent") then return nil end
        local scan=self.wolfHeapScan
        if scan and (scan.script~=own or scan.remote~=remote) then
            self.wolfHeapScan=nil;scan=nil
        end
        if not scan then
            if now<(self.nextWolfHeapScan or 0) then return nil end
            self.nextWolfHeapScan=now+15
            local ok,items=pcall(getgc,false)
            if not ok or type(items)~="table" then
                ok,items=pcall(getgc)
            end
            if not ok or type(items)~="table" then return nil end
            -- getgc generally returns a sequential array of functions.
            -- Only ever inspect the first 32k entries to bound cost.
            scan={script=own,remote=remote,items=items,index=1,
                limit=math.min(#items,32768),inputCandidate=nil,
                inputCount=0,inputSeen={}}
            self.wolfHeapScan=scan
        end
        if scan.lastStep==now then return nil end
        scan.lastStep=now
        local checked,started=0,self.clock()
        while scan.index<=scan.limit and checked<192 and self.clock()-started<.0025 do
            local fn=scan.items[scan.index]
            scan.index+=1;checked+=1
            if type(fn)~="function" then continue end
            -- A VM may hide the private tryBite layout while exposing the
            -- original onInput function in the own script's heap. Store
            -- only uniquely owned candidates; do not call unknown closure
            -- or replay the physical mouse input.
            if self:wolfFunctionName(fn,own)=="onInput" and not scan.inputSeen[fn]
                and type(getfenv)=="function" then
                local valid,env=pcall(getfenv,fn)
                if valid and type(env)=="table" and env.script==own then
                    scan.inputSeen[fn]=true
                    scan.inputCount+=1
                    scan.inputCandidate=scan.inputCount==1 and fn or nil
                end
            end
            local native=self:validateWolfBite(fn,own,remote)
            if not native then continue end
            native.discovery="validated own heap closure"
            local previous=self.wolfActions
            if previous and previous.script==own and previous.remote==remote then
                for _,name in ipairs({"toggleFeed","cancelFeed"}) do
                    if self:validateWolfFeed(previous[name],own,remote,name) then native[name]=previous[name] end
                end
            end
            self.wolfActions=native
            self.wolfHeapScan=nil
            self.wolfDiscovery=nil
            return native
        end
        if scan.index>scan.limit then
            if scan.inputCount==1 and scan.inputCandidate then
                self.wolfInputAction={
                    fn=scan.inputCandidate,script=own,remote=remote,
                    placeVersion=game.PlaceVersion,
                    discovery="unique own heap onInput"}
            end
            scan.items,scan.inputSeen=nil,nil
            self.wolfHeapScan=nil
        end
        return nil
    end
    function b:nativeWolfActions(now)
        local scripts = self.player:FindFirstChild("PlayerScripts")
        local ownScript = scripts and scripts:FindFirstChild("WolfController")
        local currentRemote=self.ReplicatedStorage:FindFirstChild("WolfActions")
        if self.wolfScript~=ownScript or self.wolfRemote~=currentRemote or self.wolfVersion~=game.PlaceVersion then
            self:resetWolfDiscovery()
            self.wolfScript,self.wolfRemote,self.wolfVersion=ownScript,currentRemote,game.PlaceVersion
        end
        if not ownScript or not ownScript:IsA("LocalScript") or not currentRemote
            or not currentRemote:IsA("RemoteEvent") then
            self:resetWolfDiscovery();return nil
        end
        if self.wolfActions and (self.wolfActions.script~=ownScript
            or self.wolfActions.remote~=currentRemote or self.wolfActions.placeVersion~=game.PlaceVersion) then
            self:resetWolfDiscovery()
        end
        local native = self.wolfActions
        if not native then
            -- Preserve validated handles already held by our previous release.
            -- This reads the existing owner; it never enumerates another VM.
            local previous=self.env.FERAL_RENAISSANCE_ACTIVE
            local cached=previous and previous.bridge and previous.bridge.wolfActions
            local remote=self.ReplicatedStorage:FindFirstChild("WolfActions")
            if cached and cached.script==ownScript then
                native=self:validateWolfBite(cached.tryBite,ownScript,remote)
                if native then
                    for _,name in ipairs({"toggleFeed","cancelFeed"}) do
                        if self:validateWolfFeed(cached[name],ownScript,remote,name) then native[name]=cached[name] end
                    end
                    self.wolfActions=native
                end
            end
        end
        if native and native.tryBite and native.toggleFeed then return native end
        if not self.wolfDiscovery and now < (self.nextWolfDiscovery or 0) then
            return self:recoverWolfBiteFromHeap(now) or native
        end
        if self.deferNativeDiscovery then return native end
        if type(getconnections) ~= "function" or type(debug) ~= "table" or type(debug.info) ~= "function" then
            return self:recoverWolfBiteFromHeap(now) or native
        end
        if type(debug.getupvalues) ~= "function" and type(getupvalues) ~= "function"
            and type(debug.getupvalue) ~= "function" and type(getupvalue) ~= "function" then return native end
        local pool,source=self:nativeFunctions(now)
        if not pool then return self:recoverWolfBiteFromHeap(now) or native end
        if not self.wolfDiscovery or self.wolfDiscovery.source~=source then
            self.nextWolfDiscovery = now+30
            native = native or {script=ownScript,remote=currentRemote,placeVersion=game.PlaceVersion}
            self.wolfActions,self.wolfDiscovery = native,{pool=pool,index=1,source=source}
        end
        local scan,started,count = self.wolfDiscovery,self.clock(),0
        local remote = self.ReplicatedStorage:FindFirstChild("WolfActions")
        while scan.index <= #scan.pool do
            if count >= 32 or self.clock()-started > .001 then return native end
            local fn = scan.pool[scan.index];scan.index += 1;count += 1
            local name=self:wolfFunctionName(fn,ownScript)
            if name=="tryBite" then
                local bite=self:validateWolfBite(fn,ownScript,remote)
                if bite then
                    native.tryBite,native.doBite,native.biteCooldown=bite.tryBite,bite.doBite,bite.biteCooldown
                end
            elseif name=="toggleFeed" or name=="cancelFeed" then
                if self:validateWolfFeed(fn,ownScript,remote,name) then native[name]=fn end
            end
            if native.tryBite and native.toggleFeed then break end
        end
        if source.complete or native.tryBite and native.toggleFeed then self.wolfDiscovery = nil end
        self:releaseNativeScan()
        if not native.tryBite and source.complete then
            return self:recoverWolfBiteFromHeap(now) or native
        end
        return native
    end

    -- Second native attack path for a real uninterrupted mouse hold.
    -- Invoke WolfController's already-installed own InputBegan callback
    -- with the genuine original InputObject; never simulate M1 Up/Down.
    -- The captured v2412 onInput calls its original tryBite function.
    -- Prefer exact onInput name, or one uniquely script-owned anonymous
    -- callback; fail closed if ownership or identity is ambiguous.
    function b:nativeWolfInputAction(now)
        local scripts=self.player:FindFirstChild("PlayerScripts")
        local own=scripts and scripts:FindFirstChild("WolfController")
        local remote=self.ReplicatedStorage:FindFirstChild("WolfActions")
        if not own or not own:IsA("LocalScript") or not remote
            or not remote:IsA("RemoteEvent") then
            self.wolfInputAction=nil
            return nil
        end
        local cached=self.wolfInputAction
        if cached and cached.script==own and cached.remote==remote
            and cached.placeVersion==game.PlaceVersion then return cached end
        self.wolfInputAction=nil
        if self.deferNativeDiscovery or now<(self.nextWolfInputLookup or 0) then return nil end
        self.nextWolfInputLookup=now+.8
        -- An executor wrapper can obscure debug.info source/name while
        -- getfenv still identifies the actual owning WolfController script.
        -- Accept exactly one uniquely owner-matched unnamed root, never a
        -- wrapper without script identity.
        if type(getconnections)~="function" then return nil end
        local debugAvailable=type(debug)=="table" and type(debug.info)=="function"
        if not debugAvailable and type(getfenv)~="function" then return nil end
        local ok,connections=pcall(getconnections,self.UserInputService.InputBegan)
        if not ok or type(connections)~="table" then return nil end
        local named,unnamed={},{}
        local count=0
        for _,connection in ipairs(connections) do
            count+=1
            if count>128 then break end
            local valid,fn=pcall(function()return connection.Function end)
            if not valid or type(fn)~="function" then continue end
            local source,name
            if debugAvailable then
                local info
                info,source,name=pcall(debug.info,fn,"sn")
                if not info then source,name=nil,nil end
            end
            local sourceOwned=type(source)=="string" and
                (source=="WolfController" or source:match("[%.%/]WolfController$")~=nil)
            local ownerConfirmed=false
            if type(getfenv)=="function" then
                local envOK,env=pcall(getfenv,fn)
                if envOK and type(env)=="table" and env.script~=nil then
                    if env.script~=own then continue end
                    ownerConfirmed=true
                end
            end
            if not sourceOwned and not ownerConfirmed then continue end
            if name=="onInput" then
                table.insert(named,fn)
            elseif (name==nil or name=="") and ownerConfirmed then
                table.insert(unnamed,fn)
            end
        end
        local fn,origin
        if #named==1 then fn,origin=named[1],"named own onInput"
        elseif #named==0 and #unnamed==1 then fn,origin=unnamed[1],"one script-owned input listener" end
        if not fn then return nil end
        local action={fn=fn,script=own,remote=remote,
            placeVersion=game.PlaceVersion,discovery=origin}
        self.wolfInputAction=action
        return action
    end
    function b:tryNativeInputBite(now,inputObject)
        if not inputObject or inputObject.UserInputType~=Enum.UserInputType.MouseButton1 then return false end
        local native=self:nativeWolfInputAction(now)
        if not native or type(native.fn)~="function" then return false end
        self.biteTiming=nil
        return pcall(native.fn,inputObject,false)
    end
    function b:nativeFeedState(now)
        -- Named callbacks can still be used after an update; private upvalue
        -- offsets cannot be assumed to retain their meaning on another build.
        if not self:capability("feedTiming") then return nil,nil,false end
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
        self.biteTiming=nil
        return native and native.tryBite and pcall(native.tryBite) or false
    end
    -- This fallback is only for a physically held bite when the same client's
    -- private native callback cannot be reached. Roblox's own input handler
    -- continues to own every hit claim, cooldown, range and permission check.
    function b:combatInputCompatible()
        -- FERAL has had separate place versions/arenas. Validate the actual
        -- native game objects instead of hard-coding one historical PlaceId.
        local scripts=self.player:FindFirstChild("PlayerScripts")
        local wolf=scripts and scripts:FindFirstChild("WolfController")
        local remote=self.ReplicatedStorage:FindFirstChild("WolfActions")
        local species=self:config("Species")
        return wolf~=nil and wolf:IsA("LocalScript")
            and remote~=nil and remote:IsA("RemoteEvent")
            and type(species)=="table" and type(species.biteCooldown)=="function"
    end
    function b:hasHeldInputBackend()
        if type(mouse1press)=="function" and type(mouse1release)=="function" then return true end
        if type(mouse1click)=="function" then return true end
        local ok,virtual=pcall(function()return game:GetService("VirtualInputManager")end)
        return ok and virtual~=nil
    end
    function b:visibleBiteWindow(s,now)
        if not self:combatInputCompatible() or not s.alive or s.char~=self.player.Character
            or s.chat or s.gameMenu or s.grab or s.rest or s.feeding or s.ability
            or s.captured or s.holding or not Core.finite(s.serverNow) then return false end
        local species=self:config("Species")
        if not species or type(species.biteCooldown)~="function" then return false end
        local ok,cd=pcall(species.biteCooldown,self:attribute(s.char,"Species") or species.DEFAULT,
            self:attribute(s.char,"Growth") or 1)
        if not ok or not Core.finite(cd) or cd<.03 or cd>30 then return false end
        local passive=self:config("PassiveConfig")
        if passive and passive.biteCdMult~=nil then
            local valid,m=pcall(passive.biteCdMult,s.char)
            if not valid or not Core.finite(m) or m<=0 or m>20 then return false end
            cd*=m
        end
        local marker=self:attribute(s.char,"WolfBiteAt")
        if marker~=nil and (not Core.finite(marker) or marker>s.serverNow+1) then return false end
        if Core.finite(marker) and s.serverNow-marker<cd-.005 then return false end
        local input=self.combatGovernor
        if input and input.lastDispatch>0 and now-input.lastDispatch<cd-.005
            and not Core.finite(marker) then return false end
        return true
    end
    -- A pcall succeeding on VirtualInputManager does not mean FERAL received
    -- a native bite. After two unmarked pulses try a different available
    -- real-input backend automatically, without user diagnostics.
    -- The first backend that produces a real native WolfBiteAt marker is
    -- preferred over unverified alternatives. Native cooldowns can create
    -- missing markers even though a backend is still functioning.
    function b:noteHeldInputTimeout()
        self.heldInputMisses=(self.heldInputMisses or 0)+1
        if self.holdBinding=="M3" and self.heldInputLockedBackend then return end
        local count=self.heldInputModes or 1
        if count<=1 then return end
        local verified=self.heldInputVerifiedIndex
        local current=self.heldInputIndex or 1
        if verified and verified<=count then
            if current==verified then
                if self.heldInputMisses>=5 then
                    self.heldInputIndex=(verified%count)+1
                    self.heldInputProbeLeft=2
                    self.heldInputMisses=0
                end
            else
                self.heldInputProbeLeft=(self.heldInputProbeLeft or 2)-1
                if self.heldInputProbeLeft<=0 then
                    self.heldInputIndex=verified
                    self.heldInputProbeLeft=nil
                    self.heldInputMisses=0
                end
            end
        elseif self.heldInputMisses>=2 then
            self.heldInputIndex=(current%count)+1
            self.heldInputMisses=0
        end
    end
    function b:noteHeldInputMarker()
        self.heldInputMisses=0
        local index=self.heldInputIndex or 1
        if index>=1 and index<=(self.heldInputModes or 1) then
            self.heldInputVerifiedIndex=index
        end
        self.heldInputProbeLeft=nil
    end
    function b:releaseSyntheticBite()
        local pulse=self.syntheticM1
        if not pulse then return end
        self.syntheticM1=nil
        if pulse.timer and type(task)=="table" and type(task.cancel)=="function" then
            pcall(task.cancel,pulse.timer)
        end
        if not pulse.independent or pulse.didPress then
            self.syntheticReleasing=true
            pcall(pulse.release)
            self.syntheticReleasing=false
        end
        self:restoreFeedClickGuard(pulse.feedGuard)
    end
    -- If an executor fails to run the scheduled synthetic release, do not
    -- permanently block subsequent held-M1 takeover bites.
    function b:clearStaleSyntheticBite(now)
        local pulse=self.syntheticM1
        if not pulse or not Core.finite(pulse.startedAt)
            or now-pulse.startedAt<.5 then return false end
        self:releaseSyntheticBite()
        return true
    end
    -- A physical held M1 is already in the Down state. Simply sending
    -- another Down is ignored by input systems that require a new edge.
    -- Re-arm one short Up -> Down -> Up pulse, with a single owner, unless
    -- an active native grab session has priority. No Bite/BiteHit remotes.
    -- A food/water offer is not feeding. M3 may start on its prompt,
    -- but a generated primary input must never activate that GUI control.
    local feedNames={feralfeedtap=true,feedtap=true,feedbutton=true,eatbutton=true,
        drinkbutton=true,eatdrinkbutton=true,feralfeedbutton=true}
    local function feedLabel(node)
        if feedNames[string.lower(tostring(node.Name or "")):gsub("[^%w]","")] then return true end
        if not (node:IsA("TextButton") or node:IsA("TextLabel")) then return false end
        local label=string.upper(tostring(node.Text or "")):gsub("<[^>]*>",""):match("^%s*(.-)%s*$")
        for _,name in ipairs({"EAT","DRINK","EAT / DRINK"}) do
            if label==name or label==name.." [E]" or label==name.." (E)"
                or label=="[E] "..name or label=="(E) "..name then return true end
        end
        return false
    end
    function b:feedOfferControl(object)
        local node=object
        for _=1,5 do
            if not node then break end
            if feedLabel(node) then return true end
            node=node.Parent
        end
        if object:IsA("GuiButton") then
            local ok,children=pcall(object.GetDescendants,object)
            if ok then
                for _,child in ipairs(children) do if feedLabel(child) then return true end end
            end
        end
        return false
    end
    -- This lease covers one generated primary press and its release.
    -- Only recognised feed buttons are changed; do not hide HUD elements,
    -- write game attributes, consume keyboard input or alter native cooldowns.
    function b:restoreFeedClickGuard(lease)
        if not lease or lease.restored then return end
        lease.restored=true
        for i=#lease.entries,1,-1 do
            local entry=lease.entries[i]
            pcall(function()
                if entry.button.Active==false then entry.button.Active=entry.active end
                if entry.button.Interactable==false then entry.button.Interactable=entry.interactable end
            end)
        end
    end
    function b:beginFeedClickGuard(char)
        local gui=self.player:FindFirstChildOfClass("PlayerGui")
        local offer=self:feedOfferActive(char)
        local lease={entries={}}
        if not gui then
            if offer then return nil,"feeding control unresolved" end
            return lease
        end
        local ok,objects=pcall(gui.GetDescendants,gui)
        if not ok or type(objects)~="table" then return nil,"feeding control query unavailable" end
        local buttons={}
        -- Look at the entire own GUI, not just the reported click coordinates.
        -- Nested Eat/Drink labels can identify an ImageButton.
        for _,object in ipairs(objects) do
            if object:IsA("GuiButton") and self:feedOfferControl(object) then
                buttons[object]=true
            end
        end
        local found=false
        for button in pairs(buttons) do
            found=true
            local readable,active,interactable=pcall(function()return button.Active,button.Interactable end)
            if not readable or type(active)~="boolean" or type(interactable)~="boolean" then
                self:restoreFeedClickGuard(lease)
                return nil,"feeding control guard unavailable"
            end
            table.insert(lease.entries,{button=button,active=active,interactable=interactable})
            local guarded,verified=pcall(function()
                button.Interactable=false
                button.Active=false
                return button.Interactable==false and button.Active==false
            end)
            if not guarded or not verified then
                self:restoreFeedClickGuard(lease)
                return nil,"feeding control guard unavailable"
            end
        end
        -- An unrecognised active feeding control is not safe to click through.
        if offer and not found then
            self:restoreFeedClickGuard(lease)
            return nil,"feeding control unresolved"
        end
        if found then self.feedGuardPulses=(self.feedGuardPulses or 0)+1 end
        return lease
    end
    -- This check is for actual generated clicks only, never M3 acquisition.
    -- Unknown GUI state remains blocked rather than clicking blindly.
    function b:mouseGameplayPoint(point,allowOffer)
        point=point or self.UserInputService:GetMouseLocation()
        local gui=self.player:FindFirstChildOfClass("PlayerGui")
        if not point then return false,false,"mouse position unavailable" end
        if self.combatPointBlocked and self.combatPointBlocked(point) then return false,false,"hub UI" end
        if not gui then return true,false,"clear" end
        local ok,under=pcall(gui.GetGuiObjectsAtPosition,gui,point.X,point.Y)
        if not ok or type(under)~="table" then return false,false,"GUI query unavailable" end
        local offer,button=false,false
        for _,object in ipairs(under) do
            local node=object
            for _=1,4 do
                if not node then break end
                if node:IsA("TextBox") then return false,false,"text field" end
                if node:IsA("GuiButton") then
                    local readable,interactable=pcall(function()return node.Interactable end)
                    if not readable or interactable~=false then
                        if self:feedOfferControl(node) or self:feedOfferControl(object) then offer=true
                        else button=true end
                    end
                end
                node=node.Parent
            end
        end
        if button then return false,offer,"HUD button" end
        if offer then return allowOffer==true,true,"Eat/Drink offer" end
        return true,false,"clear"
    end
    function b:feedOfferActive(char)
        local offer=self:attribute(char,"FeedCan")
        return offer=="eat" or offer=="drink"
    end
    function b:clearOfferClickPoint(point)
        local clear,offer,reason=self:mouseGameplayPoint(point,false)
        if clear then return point end
        -- A feed button must be isolated by the pulse guard, not avoided by
        -- assuming the executor actually honours relocated coordinates.
        if self.holdBinding=="M3" and offer then return nil,"Eat/Drink offer" end
        -- Only relocate a coordinate-addressable click around a confirmed HUD
        -- obstruction. Do not relocate across real hub/text/menu boundaries
        -- or when the hit-test API cannot establish a clear position.
        if reason~="HUD button" and reason~="Eat/Drink offer" then return nil,reason end
        local camera=self.Workspace.CurrentCamera
        local size=camera and camera.ViewportSize
        if not size then return nil,"viewport unavailable" end
        for _,distance in ipairs({12,24,48,72,96,128}) do
            for _,offset in ipairs({{0,-distance},{0,distance},{-distance,0},{distance,0}}) do
                local x,y=point.X+offset[1],point.Y+offset[2]
                if x>=8 and y>=8 and x<size.X-8 and y<size.Y-8 then
                    local candidate=Vector2.new(x,y)
                    if self:mouseGameplayPoint(candidate,false) then return candidate end
                end
            end
        end
        return nil,"no verified clear click position"
    end
    function b:blockedHeldInput(reason)
        self.heldInputBlockReason=reason
        return false
    end
    function b:tryHeldInputBite(s,now)
        self.heldInputBlockReason=nil
        if self.syntheticM1 then return self:blockedHeldInput("previous click releasing") end
        local independent=self.holdBinding=="M3"
        local desktop=independent and s and type(self.desktopOwnsPrimary)=="function" and self.desktopOwnsPrimary(s,now)
        if independent and (not s or s.r2Held or not desktop and (s.mouseHeld or s.physicalM1Held)) then
            return self:blockedHeldInput("manual primary input")
        end
        if independent and self.combatPulseBlocked and self.combatPulseBlocked() then
            return self:blockedHeldInput("pulse ownership unavailable")
        end
        if not s or not s.alive or s.char~=self.player.Character or not self:combatInputCompatible()
            or s.chat or s.gameMenu or s.grab or s.rest or s.feeding or s.ability
            or s.captured or s.holding then return false end
        local position=self.UserInputService:GetMouseLocation()
        if not position then return self:blockedHeldInput("mouse position unavailable") end
        local clear,offer,pointReason=self:mouseGameplayPoint(position,independent)
        if not clear and (not independent or pointReason~="HUD button" and pointReason~="Eat/Drink offer") then
            return self:blockedHeldInput(pointReason)
        end
        local virtualPoint,virtualReason=position,nil
        if not clear and not offer then virtualPoint,virtualReason=self:clearOfferClickPoint(position) end
        local modes={}
        local ok,virtual=pcall(function()return game:GetService("VirtualInputManager")end)
        if ok and virtual then table.insert(modes,{
            name="VIRTUAL_MOUSE",
            down=function()virtual:SendMouseButtonEvent(virtualPoint.X,virtualPoint.Y,0,true,game,0)end,
            up=function()virtual:SendMouseButtonEvent(virtualPoint.X,virtualPoint.Y,0,false,game,0)end,
        }) end
        if type(mouse1press)=="function" and type(mouse1release)=="function" then
            table.insert(modes,{name="EXECUTOR_PAIRED",down=mouse1press,up=mouse1release})
        end
        if type(mouse1click)=="function" then
            table.insert(modes,{name="EXECUTOR_CLICK",click=mouse1click})
        end
        if #modes==0 then return false end
        self.heldInputModes=#modes
        if self.heldInputVerifiedIndex and self.heldInputVerifiedIndex>#modes then
            self.heldInputVerifiedIndex,self.heldInputProbeLeft=nil,nil
        end
        local index=self.heldInputIndex or 1
        if independent and self.heldInputLockedBackend then
            index=nil
            for i,mode in ipairs(modes) do
                if mode.name==self.heldInputLockedBackend then index=i;break end
            end
            if not index then return false end
        elseif index>#modes then index=1 end
        self.heldInputIndex=index
        local mode=modes[index]
        local down,up,backend=mode.down,mode.up,mode.name
        if backend=="VIRTUAL_MOUSE" then
            if not virtualPoint then return self:blockedHeldInput(virtualReason or "no verified clear click position") end
        elseif not clear then
            -- A physical-coordinate adapter cannot relocate an ordinary
            -- click safely. Retain the chosen route instead of clicking UI.
            return self:blockedHeldInput(pointReason)
        end
        self.heldInputBackend=backend
        if mode.click then
            -- Atomic adapters cannot establish the release boundary. The
            -- verified virtual paired route is preferred for guarded input.
            if independent and (offer or self:feedOfferActive(self.player.Character)) then
                return self:blockedHeldInput("paired click required for feeding guard")
            end
            if not self:mouseGameplayPoint(nil,false) then return false end
            self.syntheticM1Until=now+.18
            self.syntheticPressing=true
            local clicked=pcall(mode.click)
            self.syntheticPressing=false
            if not clicked then self:noteHeldInputTimeout() end
            return clicked
        end
        self.syntheticM1Until=now+.3
        local pulse={release=up,method=backend,didPress=false,startedAt=now,independent=independent}
        self.syntheticM1=pulse
        local function safeUp()
            self.syntheticReleasing=true
            local success=pcall(up)
            self.syntheticReleasing=false
            return success
        end
        local function stop()
            if self.syntheticM1==pulse then self:releaseSyntheticBite() end
        end
        -- Reset the logical button state while preserving the real human-held
        -- intent in CombatInput (synthetic InputEnded events are ignored).
        if not independent and not safeUp() then
            self.syntheticM1=nil
            self.heldInputIndex=(index%#modes)+1
            self.heldInputMisses=0
            return false
        end
        local function beginPress()
            if self.syntheticM1~=pulse then return end -- a grab began meanwhile
            if self.combatPulseBlocked then
                local known,blocked=pcall(self.combatPulseBlocked)
                if not known or blocked then self.heldInputBlockReason="pulse ownership unavailable";stop();return end
            end
            local readable,current=pcall(self.snapshot,self,self.clock(),false)
            local desktopOwned=readable and desktop and type(self.desktopOwnsPrimary)=="function"
                and self.desktopOwnsPrimary(current,self.clock())
            if desktop and not desktopOwned then
                self.heldInputBlockReason="desktop hold expired";stop();return
            end
            if not readable or not current.alive or current.char~=s.char or current.generation~=s.generation
                or current.chat or current.gameMenu or current.rest or current.feeding
                or current.ability or current.captured or current.holding
                or independent and (current.r2Held or current.grab or current.mouseHeld and not desktopOwned) then
                self.heldInputBlockReason="native action or manual input lock";stop();return
            end
            if independent then
                -- Lease the actual feeding controls just before Down, and
                -- restore immediately after Up (including errors/unload).
                local lease,why=self:beginFeedClickGuard(current.char)
                if not lease then self.heldInputBlockReason=why;stop();return end
                pulse.feedGuard=lease
                -- UI may appear between scheduling and the actual press.
                -- Revalidate the point without moving the physical mouse.
                if backend=="VIRTUAL_MOUSE" then
                    local origin=self.UserInputService:GetMouseLocation()
                    if not origin then stop();return end
                    local candidate,reason=self:clearOfferClickPoint(origin)
                    if not candidate or not self:mouseGameplayPoint(candidate,false) then
                        self.heldInputBlockReason=reason or "click point changed"
                        stop();return
                    end
                    virtualPoint=candidate
                elseif not self:mouseGameplayPoint(nil,false) then
                    self.heldInputBlockReason="cursor over an interactive control"
                    stop();return
                end
                -- If the engine still reports the primary as down, re-arm
                -- its ordinary logical input edge once, under the same
                -- feeding guard. Do not change physical device state.
                if desktopOwned and current.mouseHeld and not pulse.desktopReset then
                    pulse.desktopReset=true
                    if not safeUp() then self.heldInputBlockReason="logical release unavailable";stop();return end
                    self.desktopLogicalResets=(self.desktopLogicalResets or 0)+1
                    self:restoreFeedClickGuard(pulse.feedGuard);pulse.feedGuard=nil
                    if type(task)=="table" and type(task.delay)=="function" then
                        local scheduled,timer=pcall(task.delay,.025,beginPress)
                        if scheduled then pulse.timer=timer;return end
                    end
                    self.heldInputBlockReason="logical release scheduling unavailable";stop();return
                end
                pulse.didPress=true
            end
            self.syntheticPressing=true
            local pressed=pcall(down)
            self.syntheticPressing=false
            if not pressed then self.heldInputBlockReason="input adapter rejected press";stop();return end
            if desktop then self.desktopDispatches=(self.desktopDispatches or 0)+1 end
            pulse.didPress=true
            if self.syntheticM1~=pulse then return end -- reentrant grab begin
            if type(task)=="table" and type(task.delay)=="function" then
                local scheduled,timer=pcall(task.delay,.055,stop)
                if scheduled then pulse.timer=timer else stop() end
            else stop() end
        end
        if type(task)=="table" and type(task.delay)=="function" then
            local scheduled,timer=pcall(task.delay,.025,beginPress)
            if scheduled then pulse.timer=timer;return true end
        end
        -- Never leave a held synthetic button if delayed input isn't supported.
        beginPress()
        return pulse.didPress
    end
    -- FeralHippoClient.finish uses the native clock and release path. Validate
    -- its captured own-player/remote layout before retaining or calling it.
    function b:hippoHandleValid(native)
        if not self:capability("hippoFinish") or not native or type(native.finish)~="function" then return false end
        local scripts=self.player:FindFirstChild("PlayerScripts")
        local own=scripts and scripts:FindFirstChild("FeralHippoClient")
        local remote=self.ReplicatedStorage:FindFirstChild("FeralHippo")
        if not own or own~=native.script or not remote or remote~=native.remote then return false end
        local ok,source,name=pcall(debug.info,native.finish,"sn")
        if not ok or name~="finish" or type(source)~="string" or not source:find("FeralHippoClient",1,true) then return false end
        if type(getfenv)=="function" then
            local valid,env=pcall(getfenv,native.finish)
            if valid and type(env)=="table" and env.script~=nil and env.script~=own then return false end
        end
        local v=self:upvalues(native.finish)
        return v[2]==self.player and type(v[3])=="function" and type(v[4])=="table" and v[5]==remote
    end
    function b:nativeHippoActions(now)
        if self.hippoActions and self:hippoHandleValid(self.hippoActions) then return self.hippoActions end
        self.hippoActions=nil
        if self.deferNativeDiscovery or not self:capability("hippoFinish") or type(getconnections)~="function"
            or type(debug)~="table" or type(debug.info)~="function" then return nil end
        local scripts=self.player:FindFirstChild("PlayerScripts")
        local own=scripts and scripts:FindFirstChild("FeralHippoClient")
        local remote=self.ReplicatedStorage:FindFirstChild("FeralHippo")
        if not own or not remote or not remote:IsA("RemoteEvent") then return nil end
        local scan=self.hippoDiscovery
        if scan and (scan.script~=own or scan.remote~=remote) then scan=nil;self.hippoDiscovery=nil end
        if not scan then
            if now<(self.nextHippoDiscovery or 0) then return nil end
            local signals={}
            if self.UserInputService.InputEnded then table.insert(signals,self.UserInputService.InputEnded) end
            if self.RunService.RenderStepped then table.insert(signals,self.RunService.RenderStepped) end
            table.insert(signals,self.player:GetAttributeChangedSignal("FeralCrushTouchUp"))
            scan={script=own,remote=remote,signals=signals,signalIndex=1,queue={},cursor=1,seen={}}
            self.hippoDiscovery=scan
        end
        local started,checked=self.clock(),0
        while checked<24 and self.clock()-started<.001 do
            local item=scan.queue[scan.cursor]
            if item then
                scan.cursor+=1;checked+=1
                local fn=item.fn
                if type(fn)~="function" or scan.seen[fn] or item.depth>3 then continue end
                scan.seen[fn]=true
                local ok,source,name=pcall(debug.info,fn,"sn")
                local owned=ok and type(source)=="string" and source:find("FeralHippoClient",1,true)
                if type(getfenv)=="function" then
                    local valid,env=pcall(getfenv,fn)
                    if valid and type(env)=="table" and env.script~=nil then owned=env.script==own end
                end
                if not owned and item.depth~=0 then continue end
                if owned and name=="finish" then
                    local native={finish=fn,script=own,remote=remote}
                    if self:hippoHandleValid(native) then
                        self.hippoActions=native;self.hippoDiscovery=nil;return native
                    end
                end
                local count=0
                for _,value in pairs(self:upvalues(fn)) do
                    count+=1;if count>32 then break end
                    if type(value)=="function" and #scan.queue<192 then table.insert(scan.queue,{fn=value,depth=item.depth+1}) end
                end
            elseif scan.connections then
                local record=scan.connections[scan.connectionIndex]
                if not record or scan.connectionIndex>96 then scan.connections=nil;continue end
                scan.connectionIndex+=1;checked+=1
                local ok,fn=pcall(function()return record.Function end)
                if ok and type(fn)=="function" and #scan.queue<192 then table.insert(scan.queue,{fn=fn,depth=0}) end
            else
                local signal=scan.signals[scan.signalIndex]
                if not signal then self.hippoDiscovery=nil;self.nextHippoDiscovery=now+10;return nil end
                scan.signalIndex+=1;checked+=1
                local ok,connections=pcall(getconnections,signal)
                if ok and type(connections)=="table" then scan.connections,scan.connectionIndex=connections,1 end
            end
        end
        return nil
    end
    function b:finishNativeHippo(s,startedAt,now)
        if not s.alive or s.species~="Hippo" or s.char~=self.player.Character then return false end
        local native=self:nativeHippoActions(now)
        if not native or not self:hippoHandleValid(native) then return false end
        local state=self:upvalues(native.finish)[1]
        if type(state)~="table" or state.at~=startedAt or self:attribute(s.char,"FeralCrushAt")~=startedAt then return false end
        return pcall(native.finish) -- no supplied timestamp, multiplier or damage
    end
    -- The client's unmodified native attack cooldown provides the baseline
    -- for request pacing. Reading it does not change native damage or cooldown.
    function b:nativeBiteCooldown(s)
        if not s or not s.char or s.char~=self.player.Character then return nil end
        local native=self.wolfActions
        if native and type(native.biteCooldown)=="function"
            and self:capability("wolfTiming") then
            local ok,cd=pcall(native.biteCooldown)
            if ok and Core.finite(cd) and cd>=.03 and cd<=30 then return cd end
        end
        local species=self:config("Species")
        if not species or type(species.biteCooldown)~="function" then return nil end
        local ok,cd=pcall(species.biteCooldown,
            self:attribute(s.char,"Species") or species.DEFAULT,
            self:attribute(s.char,"Growth") or 1)
        if not ok or not Core.finite(cd) or cd<.03 or cd>30 then return nil end
        local passive=self:config("PassiveConfig")
        if passive and passive.biteCdMult~=nil then
            local valid,mult=pcall(passive.biteCdMult,s.char)
            if not valid or not Core.finite(mult) or mult<=0 or mult>20 then return nil end
            cd*=mult
        end
        return Core.finite(cd) and cd>=.03 and cd<=30 and cd or nil
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
        local scripts=self.player:FindFirstChild("PlayerScripts")
        local own=scripts and scripts:FindFirstChild("WolfController")
        if native and (native.remote~=self.ReplicatedStorage:FindFirstChild("WolfActions")
            or native.script~=own or not own or own.Parent==nil or native.placeVersion~=game.PlaceVersion) then
            self:resetWolfDiscovery();native=nil
        end
        if not self:capability("wolfTiming") or not native or not native.tryBite
            or not native.doBite or not native.biteCooldown then
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
            if not r.ready then r.nextAt=now+math.max(.015,cd*mult-(s.serverNow-at)) end
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
        if now-timing.lastBite<timing.cd then
            local r=result(false,"native cooldown");r.nextAt=timing.lastBite+timing.cd;return r
        end
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
            or self:attribute(char,"FeralDiving") == true
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
            gameMenu = self:attribute(self.player,"FeralMenuOpen") == true
                or self:attribute(self.player,"FeralTitleOpen") == true
                or self:attribute(self.player,"FeralMapOpen") == true,
            combat = combat, rest = self:attribute(char,"WolfRest") == true,
            feeding = false, captured = false, moving = false, locomotion = "NONE",
            injury = self:attribute(char,"FeralInjury"), bleed = self:attribute(char,"FeralBleed"),
            venom = self:attribute(char,"FeralVenomAmt"), stamina = self:attribute(char,"Stamina"),
            maxStamina=self:attribute(char,"StaminaMax"),
            hunger = self:attribute(char,"Hunger"), thirst = self:attribute(char,"Thirst"),
            survival = self:attribute(self.player,"FeralSurvival") }
        if not s.alive then return s end
        s.serverTired=self:attribute(char,"FeralSrvTired")==true
        s.noSprint=self:attribute(char,"FeralNoSprint")==true
        s.protectedInteraction=self:protectedInteraction(char)
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
        s.diveCan = self:attribute(self.player,"FeralDiveCan") == true
            or self:attribute(char,"DiveCan") == true
        s.diving = self:attribute(char,"FeralDiving") == true
        s.burst = self:attribute(self.player,"HudBurst") == true or self:attribute(char,"FeralFlyBurst") == true
        -- v2412 WolfController input callback accepts MouseButton1/R2.
        -- MouseButton2 is a camera control, not a continuously held bite.
        local mouseOK,mouseDown=pcall(self.UserInputService.IsMouseButtonPressed,
            self.UserInputService,Enum.UserInputType.MouseButton1)
        s.mouseHeld=mouseOK and mouseDown==true
        s.mouseHeldKnown=mouseOK and type(mouseDown)=="boolean"
        if self.holdBinding=="M3" then
            local middleOK,middleDown=pcall(self.UserInputService.IsMouseButtonPressed,
                self.UserInputService,Enum.UserInputType.MouseButton3)
            s.middleHeldKnown=middleOK and type(middleDown)=="boolean"
            s.middleHeld=middleOK and middleDown==true
        end
        s.r2Held=false
        local padsOK,pads=pcall(self.UserInputService.GetConnectedGamepads,self.UserInputService)
        if not padsOK or type(pads)~="table" then pads={Enum.UserInputType.Gamepad1} end
        for index,pad in ipairs(pads) do
            if index>8 then break end
            local padOK,padHeld=pcall(self.UserInputService.IsGamepadButtonDown,self.UserInputService,
                pad,Enum.KeyCode.ButtonR2)
            if padOK and padHeld==true then s.r2Held=true;break end
        end
        s.attackHeld=s.mouseHeld or s.r2Held
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
            or s.protectedInteraction~=nil
            or self:attribute(char,"FeralPrideTaken")~=nil and self:attribute(char,"FeralPrideTaken")~=false
        if waterNeeded then
            s.swimming,s.underwater,s.surface,s.depth = self:water(char,hum,root)
        else
            s.swimming = self:attribute(char,"FeralSwimLocal") == true
                or hum:GetState() == Enum.HumanoidStateType.Swimming or hum.FloorMaterial == Enum.Material.Water
            s.underwater = self:attribute(char,"FeralUnderwater") == true or s.diving
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
        if safe~=nil and not Core.finite(safe) then return "protection timing unknown" end
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
    function b:currentTargetBody(target)
        if not target or not target.char or target.char==self.player.Character or not target.char.Parent
            or not target.root or not target.hum
            or target.root.Parent~=target.char or target.hum.Parent~=target.char
            or target.hum.Health<=0 then return false end
        if target.player and target.player.Character~=target.char then return false end
        return target.char:FindFirstChild("HumanoidRootPart")==target.root
            and target.char:FindFirstChildOfClass("Humanoid")==target.hum
    end
    function b:clearCombatTargets()
        self.reachTarget,self.treeTarget=nil,nil
        self.allCandidates,self.tracked={},{}
        self.replicatedCount,self.packNPCCount=0,0
    end
    function b:retireCombatTarget(target)
        if self.reachTarget==target then self.reachTarget=nil end
        if self.treeTarget==target then self.treeTarget=nil end
    end
    function b:candidates(s, range,visual)
        local all,seen = {},{}
        if not s.alive then
            if visual~=false then self:clearCombatTargets() end
            return all
        end
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
        if type(values)~="table" or not s or not s.alive or not s.root or not s.hum
            or not s.root.Parent or not s.hum.Parent or not target or not target.root or not target.hum then return nil end
        if s.char and (s.root.Parent~=s.char or s.hum.Parent~=s.char) then return nil end
        if not target.root.Parent or not target.hum.Parent or target.hum.Health <= 0
            or target.char and (target.root.Parent~=target.char or target.hum.Parent~=target.char) then return nil end
        for _,key in ipairs({"REACH","HIT_SCALE","CONE","SLACK","MAX_DY"}) do
            if not Core.finite(values[key]) then return nil end
        end
        if values.REACH<=0 or values.HIT_SCALE<=0 or values.MAX_DY<=0
            or not Core.finite(s.hum.HipHeight) or not Core.finite(target.hum.HipHeight) then return nil end
        local diff = target.root.Position-s.root.Position
        if not Core.finite(diff.X) or not Core.finite(diff.Y) or not Core.finite(diff.Z) then return nil end
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
            gap = gap, reach = reach, angle = angle, cone = cone, height = height, vertical = vertical,
            distance = diff.Magnitude,score = gap-angle*2 }
    end
    function b:occluded(s,target)
        if not s or not s.root or not target or not target.root or not target.char then return true,false end
        local params = RaycastParams.new()
        params.FilterType,params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude,{s.char}
        params.IgnoreWater = true
        local ok,hit=pcall(self.Workspace.Raycast,self.Workspace,s.root.Position,target.root.Position-s.root.Position,params)
        -- Missing scene evidence must not turn into a false clear-hit cue or
        -- shut down all other features because one streamed query failed.
        if not ok then return true,false end
        return hit ~= nil and (not hit.Instance or not hit.Instance:IsDescendantOf(target.char)),true
    end
    function b:imminentBiteTarget(s,stock,all)
        -- Release automatic Rest *before* contact, when a real eligible target
        -- is either within normal bite reach or the animal is closing on it.
        -- This does not claim extra hit range or force an attack.
        if not s or not s.alive or not stock or not s.root or not s.hum then return nil end
        local movement=s.hum.MoveDirection
        local velocity=s.root.AssemblyLinearVelocity
        local horizontal=Vector3.new(velocity.X,0,velocity.Z)
        local speed=math.max(18,horizontal.Magnitude)
        local anticipate=math.clamp(self:restLock(s.char)*speed+3,6,22)
        local checked=0
        for _,target in ipairs(all or {}) do
            if target.distance>32 then break end
            if target.affiliation~="same" and not target.protected
                and self:combatEligible(target.char) and target.root and target.root.Parent then
                checked+=1
                if checked>10 then break end
                local geometric=self:geometry(stock,s,target)
                if geometric then
                    local diff=target.root.Position-s.root.Position
                    local horizontalDiff=Vector3.new(diff.X,0,diff.Z)
                    local closing=movement.Magnitude>.13 and horizontalDiff.Magnitude>.1
                        and movement.Unit:Dot(horizontalDiff.Unit)>.25
                    local allowance=closing and anticipate or 3
                    local vertical=math.abs(diff.Y)
                    local verticalLimit=geometric.vertical+2
                    if geometric.gap <= geometric.reach+allowance
                        and vertical<=verticalLimit and (target.sameTree or not self:occluded(s,target)) then
                        return target
                    end
                end
            end
        end
        return nil
    end
    function b:leadPoint(s,target)
        local point=target.root.Position
        local a,bv=target.root.AssemblyLinearVelocity,s.root.AssemblyLinearVelocity
        if typeof(a)~="Vector3" or typeof(bv)~="Vector3" then return point end
        -- A one-frame velocity replication spike can steer the bite beyond
        -- the current hitbox. Reduce the speculative lead on fast movement.
        local lead=(a-bv)*math.min(.20,self:biteDelay(s.char))
        lead=Vector3.new(lead.X,0,lead.Z)
        if not Core.finite(lead.Magnitude) then return point end
        if lead.Magnitude>2.25 then lead=lead.Unit*2.25 end
        return point+lead
    end
    function b:autoAttackTarget(s,guide,values)
        if not guide or guide.invalid or not guide.target or not s.alive then return false end
        local target=guide.target
        if not self:currentTargetBody(target) or (target.root.Position-s.root.Position).Magnitude>45
            or not self:combatEligible(target.char) then return false end
        local geometry=self:geometry(values,s,target)
        if not geometry or not geometry.valid or self:occluded(s,target) then return false end
        -- Stock-valid auto hits take priority. Extended-only contacts can
        -- still be probed, but not spammed during repeated no-reply windows.
        local base
        if self.originalAutoCombat then
            -- An out-of-range animal must not inherit a stale green guide
            -- from the preceding scan when deciding whether to auto-bite.
            base=self:geometry(self.originalAutoCombat,s,target)
        else
            base=guide.baseline
        end
        if base and base.valid then return true end
        local entry=self.extendedConfidence and self.extendedConfidence[target.char]
        return not entry or (s.now or 0)>=(entry.waitUntil or 0)
    end
    function b:select(s, baseline, changed, all)
        local previousAssist=self.reachTarget
        self.treeTarget = nil
        self.reachTarget = nil
        local best,score = nil,math.huge
        local eligible={}
        for _, target in ipairs(all) do
            if target.distance <= 45 and self:currentTargetBody(target) and self:combatEligible(target.char) then
                table.insert(eligible,target)
                if target.sameTree and (not self.treeTarget or target.distance < self.treeTarget.distance) then self.treeTarget = target end
            end
        end
        local assisted,assistScore = nil,math.huge
        local visibility,visibilityKnown={},{}
        local rays=0
        local function obstruction(target)
            if visibility[target]==nil then
                if rays>=12 then
                    visibility[target],visibilityKnown[target]=true,false
                else
                    rays+=1
                    local blocked,known=self:occluded(s,target)
                    visibility[target],visibilityKnown[target]=blocked,known~=false
                end
            end
            return visibility[target]
        end
        local selectionModel = table.clone(changed)
        selectionModel.biteLook = baseline.biteLook
        self.originalAutoCombat=baseline
        for _,target in ipairs(eligible) do
                local geometry = self:geometry(selectionModel,s,target)
                if geometry and geometry.withinBodyRange then
                    local stock = self:geometry(baseline,s,target)
                    local rank = target.distance+(target.affiliation == "unknown" and .5 or 0)
                        -(stock and stock.valid and .75 or 0)
                    if previousAssist and previousAssist.char==target.char then rank-=.65 end
                    if rank < assistScore and not obstruction(target) then
                        assisted,assistScore = target,rank
                    end
                end
        end
        self.reachTarget = assisted
        for _, target in ipairs(eligible) do
                local base = self:geometry(baseline,s,target)
                local extended = self:geometry(changed,s,target)
                if base or extended then
                    local blocked=target.protected or obstruction(target)
                    -- A clear stock-valid candidate outranks a speculative
                    -- extended-only target. Never prefer a wall over a
                    -- nearby unobstructed animal.
                    -- Stock validity comes from the unmodified biteLook.
                    -- Calculate its tier BEFORE the extended geometry score:
                    -- the latter depends on the currently assisted aim target
                    -- and otherwise creates a feedback loop favouring ghosts.
                    local stockValid=base and base.valid
                    local extendedValid=extended and extended.valid
                    local tier=stockValid and 0 or extendedValid and 100 or 2000
                    local scoreValue=stockValid and base.score
                        or extended and extended.score or 1000
                    local rank=tier+scoreValue+(blocked and 4000 or 0)
                    if rank<score then
                        best,score={
                            target=target,baseline=base,extended=extended,obstruction=blocked,
                        },rank
                    end
                end
        end
        if best then
            best.blocked=best.obstruction
            best.obstructionKnown=visibilityKnown[best.target]~=false
            -- Native biteLook must prefer the same stock-clear target the
            -- guide displays. Extended-only rear/tree aim retains the
            -- existing sticky assist until a stock-valid option appears.
            if best.baseline and best.baseline.valid and not best.blocked then
                self.reachTarget=best.target
            end
        end
        return best
    end
    function b:refreshGuide(s,baseline,changed,guide)
        local target=guide.target
        if not s.alive or s.char~=self.player.Character or not self:currentTargetBody(target)
            or not self:combatEligible(target.char) then
            self:retireCombatTarget(target)
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
        scope:add(function() self:releaseSyntheticBite() end)
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
                "FeralDowned","FeralVenomDown","FeralTumbleAt","FeralCrushAt","FeralCrushBiteAt","FeralClimbLocal","FeralFlyLocal",
                "FeralUnderwater","FeralDiving","FeralSwimLocal","FeralWrestle",
                "FeralPrideTaken","FeralSrvTired","FeralNoSprint"}) do
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
        connect(self.player:GetAttributeChangedSignal("FeralPanelHold"),function() hub:nativeAttribute("FeralPanelHold") end)
        connect(self.player:GetAttributeChangedSignal("FeralRestTap"),function()
            if self.UserInputService:GetFocusedTextBox() then return end
            local now=self.clock()
            hub.policy:input("rest",now)
            hub.recovery:manual(now)
            hub.combatInput:cancel();hub.feeding:cancel("manual rest control",now);hub.rescue:cancel()
        end)
        connect(self.UserInputService.InputBegan,function(input,processed) hub:input(input,processed) end)
        connect(self.UserInputService.InputEnded,function(input) hub:inputEnded(input) end)
        if self.UserInputService.WindowFocusReleased then
            connect(self.UserInputService.WindowFocusReleased,function() hub:focusChanged(false) end)
        end
        if self.UserInputService.WindowFocused then
            connect(self.UserInputService.WindowFocused,function() hub:focusChanged(true) end)
        end
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
        for _, item in ipairs({{"FeralGrabV2","grab"},{"FeralHit","feedback"},{"FeralHippo","hippo"},{"WolfActions","actions"},
            {"FeralBiteLocal","biteLocal","BindableEvent"}}) do
            local remote = self.ReplicatedStorage:FindFirstChild(item[1])
            local old = self.remoteConnections[item[1]]
            if old and (old.remote ~= remote or old.connection.Connected==false) then
                old.connection:Disconnect(); self.remoteConnections[item[1]] = nil; old = nil
            end
            if remote and remote:IsA(item[3] or "RemoteEvent") and not old then
                local kind,name = item[2],item[1]
                local signal = item[3] == "BindableEvent" and remote.Event or remote.OnClientEvent
                local c = signal:Connect(function(...)
                    if hub.active and not hub.closed and self.ReplicatedStorage:FindFirstChild(name)==remote then
                        hub:nativeEvent(kind,...)
                    end
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
        if not ok then
            -- A rejected second property must not leave the first expanded or
            -- retain observers on a half-applied camera lease.
            self:close()
        end
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
sources["voice"] = [============[
-- Optional hearing assistance for the default Roblox Audio API voice graph.
-- This module never touches the microphone, chat controls, voice permissions,
-- voice wires, remotes, player positions or any combat/minigame subsystem.
local Voice = {}

local function finite(x)
    return type(x)=="number" and x==x and x>=0 and x<1e8
end
function Voice.cloneCurve(curve)
    if type(curve)~="table" then return nil end
    local out,n={},0
    for distance,volume in pairs(curve) do
        if not finite(distance) or not finite(volume) or volume>1 then return nil end
        out[distance]=volume
        n+=1
        if n>400 then return nil end
    end
    return n>0 and out or nil
end
function Voice.scaleCurve(curve,scale)
    if not finite(scale) or scale<1 or scale>1.5 then return nil end
    local source=Voice.cloneCurve(curve)
    if not source then return nil end
    local out={}
    for distance,volume in pairs(source) do
        local farther=distance==0 and 0 or math.floor(distance*scale*10000+.5)/10000
        if out[farther]~=nil then return nil end
        out[farther]=volume
    end
    return out
end
function Voice.sameCurve(a,b)
    if type(a)~="table" or type(b)~="table" then return false end
    local left,right=0,0
    for distance,volume in pairs(a) do
        left+=1
        if not finite(distance) or not finite(volume)
            or not finite(b[distance]) or math.abs(volume-b[distance])>.0001 then return false end
    end
    for _ in pairs(b) do right+=1 end
    return left==right
end

function Voice.new(players,localPlayer)
    local v={players=players,localPlayer=localPlayer,closed=false,started=false,
        enabled=false,factor=1.25,records={},playerConns={},charConns={},
        characters={},connections={},skipped=0,conflicts=0}
    local function connect(bucket,signal,handler)
        if not signal then return end
        local ok,connection=pcall(function() return signal:Connect(handler) end)
        if ok and connection then table.insert(bucket,connection) end
    end
    local function disconnect(bucket)
        for i=#bucket,1,-1 do
            pcall(function() bucket[i]:Disconnect() end)
            bucket[i]=nil
        end
    end
    local function sameBounds(a,b)
        return a and b and finite(a.Min) and finite(a.Max)
            and finite(b.Min) and finite(b.Max)
            and math.abs(a.Min-b.Min)<.001 and math.abs(a.Max-b.Max)<.001
    end
    local function restore(emitter)
        local record=v.records[emitter]
        if not record then return end
        v.records[emitter]=nil
        local ok=pcall(function()
            -- Detachment is not destruction. Restore an owned curve even
            -- between parents so a later reattach cannot scale it twice.
            if emitter.DistanceAttenuationMode~=record.mode then
                v.conflicts+=1;return
            end
            if record.custom then
                if not Voice.sameCurve(emitter:GetDistanceAttenuation(),record.modified) then
                    v.conflicts+=1;return
                end
                emitter:SetDistanceAttenuation(record.original)
            else
                if not sameBounds(emitter.DistanceAttenuationBounds,record.modified) then
                    v.conflicts+=1;return
                end
                emitter.DistanceAttenuationBounds=record.original
            end
        end)
        if not ok then v.conflicts+=1 end
    end
    local function restorePlayer(remote)
        local found={}
        for emitter,record in pairs(v.records) do
            if record.player==remote then table.insert(found,emitter) end
        end
        for _,emitter in ipairs(found) do restore(emitter) end
    end
    local function apply(remote,emitter)
        if v.closed or not v.enabled or v.records[emitter] then return end
        -- Never alter an unrelated ambient sound or a user's own microphone.
        if remote==localPlayer or remote.Character~=emitter.Parent
            or not emitter:IsA("AudioEmitter") or emitter.Name~="AudioEmitter"
            or not remote:FindFirstChildOfClass("AudioDeviceInput") then return end
        local modeOK,mode=pcall(function() return emitter.DistanceAttenuationMode end)
        if not modeOK or mode==nil then v.skipped+=1;return end
        local custom=mode==Enum.DistanceAttenuationMode.Custom
        if custom then
            local ok,before=pcall(function() return emitter:GetDistanceAttenuation() end)
            local old=ok and Voice.cloneCurve(before) or nil
            -- Empty curves use Roblox's default inverse rolloff, which cannot
            -- be losslessly stretched. Do not replace it with a fabricated curve.
            local desired=old and Voice.scaleCurve(old,v.factor)
            if not desired then v.skipped+=1;return end
            local wrote=pcall(function() emitter:SetDistanceAttenuation(desired) end)
            local read,after=pcall(function() return emitter:GetDistanceAttenuation() end)
            if not wrote or not read or not Voice.sameCurve(after,desired) then
                v.skipped+=1
                if read and Voice.sameCurve(after,desired) then
                    pcall(function() emitter:SetDistanceAttenuation(old) end)
                end
                return
            end
            v.records[emitter]={player=remote,mode=mode,custom=true,original=old,modified=desired}
        else
            local ok,before=pcall(function() return emitter.DistanceAttenuationBounds end)
            if not ok or not before or not finite(before.Min) or not finite(before.Max)
                or before.Max<=before.Min then v.skipped+=1;return end
            local desired=NumberRange.new(before.Min*v.factor,before.Max*v.factor)
            local wrote=pcall(function() emitter.DistanceAttenuationBounds=desired end)
            local read,after=pcall(function() return emitter.DistanceAttenuationBounds end)
            if not wrote or not read or not sameBounds(after,desired) then
                v.skipped+=1
                -- A property setter can change the value before reporting a
                -- failure. Undo only the exact attempted value, just as the
                -- custom-curve path does, so OFF/unload cannot miss this write.
                if read and sameBounds(after,desired) then
                    pcall(function() emitter.DistanceAttenuationBounds=before end)
                end
                return
            end
            v.records[emitter]={player=remote,mode=mode,custom=false,original=before,modified=desired}
        end
    end
    local function scan(remote)
        if v.closed or not v.enabled or remote==localPlayer then return end
        local char=remote.Character
        if not char or not remote:FindFirstChildOfClass("AudioDeviceInput") then return end
        for _,child in ipairs(char:GetChildren()) do
            if child:IsA("AudioEmitter") then apply(remote,child) end
        end
    end
    local function detachCharacter(remote)
        local bucket=v.charConns[remote]
        if bucket then disconnect(bucket) end
        v.charConns[remote]=nil;v.characters[remote]=nil
        restorePlayer(remote)
    end
    local watchCharacter
    watchCharacter=function(remote,char)
        if v.characters[remote]==char then scan(remote);return end
        detachCharacter(remote)
        v.characters[remote]=char
        local bucket={}
        v.charConns[remote]=bucket
        connect(bucket,char.ChildAdded,function(child)
            if child:IsA("AudioEmitter") then apply(remote,child) end
        end)
        connect(bucket,char.ChildRemoved,function(child)
            if v.records[child] then restore(child) end
        end)
        scan(remote)
    end
    local function detachPlayer(remote)
        detachCharacter(remote)
        local bucket=v.playerConns[remote]
        if bucket then disconnect(bucket) end
        v.playerConns[remote]=nil
    end
    local function watchPlayer(remote)
        if remote==localPlayer or v.playerConns[remote] then return end
        local bucket={}
        v.playerConns[remote]=bucket
        connect(bucket,remote.CharacterAdded,function(char)
            if not v.closed then watchCharacter(remote,char) end
        end)
        connect(bucket,remote.CharacterRemoving,function()
            detachCharacter(remote)
        end)
        connect(bucket,remote.ChildAdded,function(child)
            if child:IsA("AudioDeviceInput") then scan(remote) end
        end)
        if remote.Character then watchCharacter(remote,remote.Character) end
    end

    function v:start()
        if self.started or self.closed then return end
        self.started=true
        connect(self.connections,players.PlayerAdded,function(remote)
            if not self.closed then watchPlayer(remote) end
        end)
        connect(self.connections,players.PlayerRemoving,function(remote)
            detachPlayer(remote)
        end)
        for _,remote in ipairs(players:GetPlayers()) do watchPlayer(remote) end
    end
    function v:setEnabled(on)
        if self.closed then return false end
        if not self.started then self:start() end
        self.enabled=on==true
        if self.enabled then
            for _,remote in ipairs(players:GetPlayers()) do
                watchPlayer(remote)
                if remote.Character then watchCharacter(remote,remote.Character) end
                scan(remote)
            end
        else
            local affected={}
            for emitter in pairs(self.records) do table.insert(affected,emitter) end
            for _,emitter in ipairs(affected) do restore(emitter) end
        end
        return true
    end
    function v:status()
        local adjusted=0
        for emitter in pairs(self.records) do
            if emitter.Parent then adjusted+=1 end
        end
        return {enabled=self.enabled,adjusted=adjusted,
            skipped=self.skipped,conflicts=self.conflicts}
    end
    function v:summary()
        if not self.enabled then return "Default hearing restored" end
        local status=self:status()
        if status.adjusted>0 then
            return "Local voice rolloff +25%; server hearing limit unchanged"
        end
        return "Waiting for compatible proximity voice audio; server limit unchanged"
    end
    function v:close()
        if self.closed then return end
        self:setEnabled(false)
        self.closed=true
        disconnect(self.connections)
        local peers={}
        for remote in pairs(self.playerConns) do table.insert(peers,remote) end
        for _,remote in ipairs(peers) do detachPlayer(remote) end
    end
    return v
end

return Voice
]============]
sources["test_features"] = [============[
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
        elseif type(task)=="table" and type(task.spawn)=="function" then
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
            biteCadence=self:biteCadence(),middleRepeat=hub.combatInput:middleReport(),leftHold=hub:desktopHoldReport(),
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
]============]
sources["ui"] = [============[
-- One compact window and one owner for all hub outlines, tags and the bite dot.
local UI = {}
function UI.fit(viewport,centre)
    local x,y=viewport and viewport.X,viewport and viewport.Y
    if type(x)~="number" or type(y)~="number" or x~=x or y~=y or x<80 or y<80 or x>=1e8 or y>=1e8 then return nil end
    local scale=math.min((x-24)/704,(y-24)/505,1)
    local halfX,halfY=352*scale,252.5*scale
    return scale,Vector2.new(math.clamp(centre and centre.X or x/2,halfX+12,x-halfX-12),
        math.clamp(centre and centre.Y or y/2,halfY+12,y-halfY-12))
end

function UI.markerTone(species,ready,stock)
    if not ready then return "sub" end
    if species=="KingCobra" then return stock and "same" or "unknown" end
    return "text"
end

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
            Selectable = true,
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
    local scale = make("UIScale",{Scale=1},frame)
    u.scale=scale
    local side = round(make("Frame",{Size = UDim2.fromOffset(165,505),
        BackgroundColor3 = palette.side, BorderSizePixel = 0},frame),15)
    text(side,"F E R A L",18,22,130,28,20)
    u.versionLabel=text(side,"RENAISSANCE  /  "..tostring(hub.version),18,52,140,18,10,palette.same)
    local content = make("Frame",{BackgroundTransparency = 1,Position = UDim2.fromOffset(181,17),
        Size = UDim2.fromOffset(511,470)},frame)
    local title = text(content,u.tab,10,0,470,30,19)
    local subtitle = text(content,"Simple controls. Native gameplay remains in charge.",10,34,480,20,11,palette.sub)
    local cards = make("ScrollingFrame",{BackgroundTransparency = 1,BorderSizePixel=0,
        Position = UDim2.fromOffset(10,68),Size = UDim2.fromOffset(490,365),
        CanvasSize=UDim2.fromOffset(0,365),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollBarThickness=3,ScrollBarImageColor3=palette.line,ScrollingDirection=Enum.ScrollingDirection.Y,
        ClipsDescendants=true},content)
    text(content,"Client changes and predictions · gameplay results unverified",10,440,485,18,10,palette.sub)
    local footer = text(side,"Ready",14,452,140,39,10,palette.sub)
    footer.TextWrapped = true
    local hide = button(side,"HIDE  ·  RIGHT SHIFT",12,378,141,30)
    local unload = button(side,"UNLOAD",12,414,141,27)
    local launcher = button(gui,"FERAL",16,16,82,34)
    launcher.Position=UDim2.new(0,16,1,-50)
    launcher.Visible=false
    u.launcher=launcher
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
        cards.CanvasPosition=Vector2.new(0,0)
        u.rows,u.combatReadout,u.finderReadout,u.hippoReadout,u.testsReadout,u.testsToggle = {},nil,nil,nil,nil,nil
        title.Text = string.upper(u.tab)
        subtitle.Text="Simple controls. Native gameplay remains in charge."
        if u.pages[u.tab] then
            u.pageView=u.pages[u.tab]:mount(cards,{
                text=text,button=button,palette=palette,make=make,card=card})
            subtitle.Text="Automatic territory, survival and native movement in one hub."
        elseif u.tab=="Territory" then
            info(0,"TERRITORY FARMING","Territory controls initialise with this hub. If unavailable, reload the current Renaissance launcher.",100)
        elseif u.tab == "Combat" then
            row("reach",0);row("biteHelper",57);row("attackSpeed",114);row("holdBite",171);row("autoBite",228)
            info(285,"HOLD TO BITE","Tap normally. With the installed Windows helper, hold left mouse for 0.18s to repeat. The hub pauses for native menus, offers and minigames; source and safe input backend determine availability.",85)
            u.combatReadout = info(365,"NATIVE COMBAT","Waiting for an animal.",100)
        elseif u.tab == "Hippo" then
            info(0,"CRUSHER BITE","Hold your normal ability control. Charge movement and release assistance apply only to Hippo.",65)
            row("hippoMove",74);row("hippoRelease",131)
            u.hippoReadout=info(193,"CHARGE","Waiting for Hippo.",106)
            info(309,"POWER LIMIT","Damage beyond full charge and shorter ability cooldowns remain unverified.",55)
        elseif u.tab == "Test Features" then
            subtitle.Text="Own-character observations for every animal."
            info(0,"DAMAGE & ABILITY EVIDENCE","Records HP loss, Rest, effects, Hippo replies and hub feature states. The client shell formula is not proof of protection.",60)
            u.testsReadout=info(68,"LIVE RECORDER","Waiting for your animal.",96)
            local save=button(cards,"SAVE REPORT",0,174,238,34)
            save.Activated:Connect(function()
                if hub.active then hub.tests:save();u.nextText=0 end
            end)
            local copy=button(cards,"COPY REPORT",252,174,238,34)
            copy.Activated:Connect(function()
                if hub.active then hub.tests:copy();u.nextText=0 end
            end)
            u.testsToggle=button(cards,"RECORDING: ON",0,216,490,34)
            u.testsToggle.Activated:Connect(function()
                if hub.active then hub.tests:setEnabled(not hub.tests.enabled);u.nextText=0 end
            end)
            local cross=button(cards,"ONE-SHOT TURTLE / CRUSHER REQUEST",0,258,490,34)
            cross.Activated:Connect(function()
                if hub.active then hub.tests:crossSpecies();u.nextText=0 end
            end)
            info(300,"CONTROLLED TRIAL","Only while naturally resting as Turtle in FERAL v2412. No shell or reduced damage is claimed.",64)
        elseif u.tab == "Vision" then
            row("esp",0); row("tags",57); row("voice",114)
            local c = card(171,52)
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
            local walls = button(cards,"Through-wall outlines: " .. (hub.settings.walls and "ON" or "OFF"),0,231,490,30)
            walls.Activated:Connect(function()
                if not hub.active then return end
                hub.settings.walls = not hub.settings.walls
                walls.Text = "Through-wall outlines: " .. (hub.settings.walls and "ON" or "OFF")
                hub:save()
            end)
            info(269,"HEALTH / PACK","Health-coloured outlines; pack-coloured names.",47)
            u.finderReadout = info(317,"PLAYER FINDER","Waiting for replicated players.",48)
        else
            local order = u.tab == "Survival"
                and {"stamina","recovery","escape","robloxAFK","survivalAFK","minigame"}
                or {"climb","flight","mobility","speed","enduranceMove","leap","zoom"}
            for i,id in ipairs(order) do row(id,(i-1)*57) end
        end
        for name,btn in pairs(tabs) do btn.BackgroundColor3 = name == u.tab and Color3.fromRGB(27,111,98) or palette.panel end
        u.nextText = 0
    end
    for i,name in ipairs({"Survival","Combat","Movement","Vision","Territory","Hippo","Test Features"}) do
        local btn = button(side,string.upper(name),12,106+(i-1)*39,141,32)
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
        self.drag=nil
        frame.Visible = self.visible
        launcher.Visible = not self.visible
        hub.policy.menuOpen = self.visible
        self.nextText=0
        if self.visible then hub:stopWalk("menu opened") end
    end
    function u:contains(point)
        if not gui.Enabled then return false end
        local surface=self.visible and frame or launcher
        if not surface.Visible then return false end
        local p,s = surface.AbsolutePosition,surface.AbsoluteSize
        return point.X >= p.X and point.X <= p.X+s.X and point.Y >= p.Y and point.Y <= p.Y+s.Y
    end
    function u:fit()
        local camera=bridge.Workspace.CurrentCamera
        local amount,centre=UI.fit(camera and camera.ViewportSize,self.windowCentre)
        if not amount then return end
        self.windowCentre=centre
        assign(scale,"Scale",amount)
        if self.windowX~=centre.X or self.windowY~=centre.Y then
            self.windowX,self.windowY=centre.X,centre.Y
            frame.Position=UDim2.fromOffset(centre.X,centre.Y)
        end
    end
    function u:beginDrag(point,input)
        if not hub.active or not self.visible or not self:contains(point) then return false end
        if point.Y>frame.AbsolutePosition.Y+76*scale.Scale then return false end
        self.drag={origin=point,centre=self.windowCentre or frame.AbsolutePosition+frame.AbsoluteSize*.5,input=input}
        return true
    end
    function u:moveDrag(point)
        if not self.drag or not self.visible then return end
        self.windowCentre=self.drag.centre+point-self.drag.origin
        self:fit()
    end
    local inputService=bridge.UserInputService
    local function pointOf(input)
        if input.UserInputType==Enum.UserInputType.Touch and input.Position then
            return Vector2.new(input.Position.X,input.Position.Y)
        end
        return inputService:GetMouseLocation()
    end
    local function listen(signal,callback)
        local connection=signal:Connect(callback)
        scope:add(function()connection:Disconnect()end)
    end
    listen(inputService.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            u:beginDrag(pointOf(input),input)
        end
    end)
    listen(inputService.InputChanged,function(input)
        if u.drag and (input==u.drag.input or input.UserInputType==Enum.UserInputType.MouseMovement) then
            u:moveDrag(pointOf(input))
        end
    end)
    listen(inputService.InputEnded,function(input)
        if u.drag and (input==u.drag.input or input.UserInputType==Enum.UserInputType.MouseButton1) then u.drag=nil end
    end)
    hide.Activated:Connect(function() if hub.active then u:toggle() end end)
    launcher.Activated:Connect(function() if hub.active then u:toggle() end end)
    unload.Activated:Connect(function() if hub.active then hub:close() end end)
    local dot = round(make("Frame",{Name = "BiteRangeMarker",BackgroundTransparency = 1,
        Size = UDim2.fromOffset(15,15),AnchorPoint = Vector2.new(.5,.5),Visible = false},gui),50)
    local dotStroke = make("UIStroke",{Thickness = 1.5,Transparency = .05,Color = palette.same},dot)
    u.dot,u.dotStroke=dot,dotStroke
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
        if not camera then
            for _,record in pairs(self.records) do
                assign(record.highlight,"Enabled",false);assign(record.label,"Visible",false)
            end
            assign(dot,"Visible",false)
            self.lastPoint,self.lastTarget=nil,nil
            return
        end
        if now >= self.nextFit then
            self.nextFit = now+.5
            self:fit()
        end
        local registry = hub.registry.byId
        for char,record in pairs(self.records) do
            local target = record.target
            local valid = target.player and target.player.Parent~=nil and target.player.Character==char
                and char.Parent ~= nil and target.root and target.root.Parent ~= nil
                and target.hum and target.hum.Parent ~= nil and target.hum.Health > 0
            valid=valid==true
            local colour = palette[target.affiliation] or palette.unknown
            assign(record.highlight,"FillTransparency",1)
            if valid and registry.esp.requested then
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
                local x,y = math.clamp(projected.X,90,math.max(90,camera.ViewportSize.X-90)),math.max(20,projected.Y-6)
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
                local species=hub.snapshot and hub.snapshot.species
                assign(dotStroke,"Color",palette[UI.markerTone(species,not (guide.blocked or locked or stale),
                    guide.baseline and guide.baseline.valid)])
            else self.lastPoint,self.lastTarget=nil,nil end
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
                .."\n"..(hub.combatStatus or "Watching native attacks") .. "\n" .. hub.combatInput.status)
        end
        if self.finderReadout then
            assign(self.finderReadout,"Text",string.format("%d shown · %d in range · %.0f studs",#bridge.tracked,bridge.replicatedCount or 0,hub.settings.range))
        end
        if self.hippoReadout then assign(self.hippoReadout,"Text",hub.hippo:summary()) end
        if self.testsReadout then assign(self.testsReadout,"Text",hub.tests:summary().."\n"..hub.tests.notice) end
        if self.testsToggle then assign(self.testsToggle,"Text",hub.tests.enabled and "RECORDING: ON" or "RECORDING: PAUSED") end
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
local LEFT_READY="FERAL_LEFT_HOLD_READY_V1"
local LEFT_INTENT="FERAL_LEFT_HOLD_INTENT_V1"
-- Replies have no recovered transaction identifier. Prefer a matching native
-- target and timing, and retain ambiguity instead of assigning the newest bite.
function Controller.matchFeedback(Core,transactions,data,now)
    if type(data)~="table" or data.v==nil then return nil,false end
    local best,bestRank,matches,abilityOverlap=nil,math.huge,0,false
    for _,tx in ipairs(transactions) do
        local corrected=tx.feedback and not tx.feedback.safe and tx.feedback.v==data.v
            and Core.finite(tx.feedback.dmg) and tx.feedback.dmg==0 and Core.finite(data.dmg) and data.dmg>0
        if tx.nativeAt and not tx.closed and (not tx.feedback or corrected) and now>=tx.nativeAt and now-tx.nativeAt<2.6 then
            local target=tx.focusTarget and tx.focusTarget.char or tx.target and tx.target.char
            local seenVictim=tx.hpBefore and tx.hpBefore[data.v]~=nil
            -- Real FeralHit replies may involve a different nearby victim
            -- than the client's projected target. Prefer exact matches but
            -- allow a unique weaker nearby-victim match.
            local rank=tx.nativeTarget==data.v and 0
                or tx.localTarget==data.v and 1
                or target==data.v and 2
                or seenVictim and 3 or nil
            if rank then
                if tx.abilityAmbiguous then
                    abilityOverlap=true
                elseif rank<bestRank then
                    best,bestRank,matches=tx,rank,1
                elseif rank==bestRank then
                    matches+=1
                end
            end
        end
    end
    -- Neither timing proximity nor a shared target is a transaction ID.
    -- Do not train cadence or label damage when multiple equal candidates fit.
    local ambiguous=abilityOverlap or best~=nil and matches>1
    return not ambiguous and best or nil,ambiguous
end
local function nativeState(native)
    if not native or type(native.state)~="function" then return nil,false end
    local ok,state,known=pcall(native.state)
    if ok then return state,known end
    return nil,false
end
function Controller.new(M,bridge,options)
    local Core = M.core
    local tokenIdentity = {}
    local h = { version = M.release and M.release.version or "unbundled",
        sourceFingerprint = M.release and M.release.sourceFingerprint, tokenIdentity = tokenIdentity,
        token = (tostring(tokenIdentity):gsub("[^%w]","")) .. "_" .. tostring(math.floor(bridge.clock()*1000000)),
        active = false, closed = false, ready = false, inputSuspended=false, scope = Core.scope(),
        registry = Core.registry(), policy = M.policy.new(), ledger = Core.ledger(160),
        nextScan = 0, nextSlow = 0, nextBind = 0, nextSample = 0, nextEscape = 0,
        nextWalk = bridge.clock()+90, nextIdle = bridge.clock()+75,
        transactions = {}, earlyInputs = setmetatable({},{__mode = "k"}),
        notice = "Ready · Right Shift opens menu", bridge = bridge, options = options or {} }
    h.policy.lastPhysical = bridge.clock()
    h.settings,h.settingsOrigin = M.settings.load(bridge:io(),Core.specs)
    if h.options.settings then h.settings = M.settings.sanitize(h.options.settings,Core.specs) end
    if h.options.leftHoldBridge==true then h.settings.states.holdBite=true end
    for _,feature in ipairs(h.registry.order) do
        if not feature.permanent and not feature.linked then h.registry:request(feature.id,h.settings.states[feature.id]) end
    end
    h.features = M.features.new(Core,bridge,h.registry)
    h.endurance = M.endurance.new(Core,bridge)
    h.grab = M.grab.new()
    h.grabInput = M.grab_input.new(bridge,h.token)
    h.recovery = M.recovery.new(bridge,h.policy,h.ledger)
    h.feeding = M.feeding.new(bridge,h.policy,h.ledger)
    bridge.holdBinding=h.options.holdBinding=="M1" and h.options.leftHoldBridge~=true and "M1" or "M3"
    h.leftHoldBridge=h.options.leftHoldBridge==true
    h.leftHoldIo=bridge:io()
    h.leftHoldAwaitFresh=true
    h.leftHoldEpoch=0
    h.leftHoldToken=h.token.."_0"
    bridge.desktopLeftHold=h.leftHoldBridge
    -- Default M3 to standard input: live 16.2.6 reported six native attempts and zero attributable markers.
    bridge.middleRoutePreference=h.options.middleRoutePreference=="NATIVE" and "NATIVE" or "INPUT"
    h.combatInput = M.combat_input.new(bridge,h.policy,h.ledger)
    bridge.combatGovernor = h.combatInput
    -- Weak keyed: a disappeared animal is never retained by combat trust.
    -- Only Auto Bite pauses unconfirmed extended contacts; manual reach stays.
    h.extendedConfidence=setmetatable({},{__mode="k"})
    bridge.extendedConfidence=h.extendedConfidence
    -- A pending synthetic reset can outlive the current Heartbeat. Never
    -- press during an asynchronously arriving native grab begin.
    -- Only an independently held middle button can own an ordinary-input pulse.
    -- Never compete with a physically held M1 or a native minigame.
    bridge.combatPointBlocked = function(point) return h.ui and h.ui:contains(point) or false end
    -- Desktop ownership is separate from the engine's primary-button poll.
    -- Only a fresh, accepted session can classify the same physical LMB
    -- as the held intent instead of a competing manual click.
    bridge.desktopOwnsPrimary = function(s,now)
        local held=h.combatInput.held
        return h.leftHoldBridge and h.active and not h.closed
            and h.windowFocused~=false and not h.inputSuspended
            and h.registry.byId.holdBite.requested and h.leftHoldArmed==true
            and h.leftHoldIntent==true and not h.leftHoldAwaitFresh
            and h.leftHoldLastAt~=nil and now-h.leftHoldLastAt<=.55
            and held~=nil and held.source=="desktop" and held.key=="M3"
            and held.char==s.char and held.generation==s.generation
            and s.alive and not s.chat and not s.gameMenu
    end
    bridge.combatPulseBlocked = function()
        if bridge.holdBinding~="M3" then return true end
        local held=h.combatInput.held
        local desktop=held and held.source=="desktop"
        local fresh=desktop and bridge.desktopOwnsPrimary({char=bridge.player.Character,
            generation=bridge.generation,alive=true},bridge.clock())
        return h.closed or not h.active or h.inputSuspended or h.windowFocused==false
            or not h.registry.byId.holdBite.requested
            or not held or held.key~="M3" or held.upSince~=nil
            or desktop and not fresh
            or h.physicalM1Input~=nil and not fresh or h:hasNativeGrab(bridge.clock())
            or h.grabInput.lease~=nil
            or bridge:protectedInteraction(bridge.player.Character)~=nil
            or bridge.UserInputService:GetFocusedTextBox()~=nil
            or h.ui:contains(bridge.UserInputService:GetMouseLocation())
    end
    h.rescue = M.rescue.new(bridge,h.ledger)
    h.hippo = M.hippo.new(Core,bridge,h.ledger)
    h.tests = M.test_features.new(Core,bridge,h)
    h.zoom = M.zoom.new(bridge.player)
    h.voice = M.voice.new(bridge.Players,bridge.player)
    h.settingsAvailable = bridge:io().available ~= false
    function h:hasNativeGrab(now)
        if self.grab.active then return true end
        local observed=self.nativeGrabSession
        return observed~=nil and observed.char==bridge.player.Character
            and observed.generation==bridge.generation and now-observed.at<=8
    end
    function h:focusChanged(focused)
        if self.closed then return end
        self.windowFocused=focused==true
        self.middlePollArmed=false;self.middlePollDown=nil
        -- Focus return does not resurrect a hold whose release was missed.
        -- A fresh gameplay input must establish ownership again.
        self.inputSuspended=true
        self.physicalM1Input=nil
        self.combatInput:cancel()
        self:disarmDesktopHold(bridge.clock())
        self:stopWalk("window focus changed")
        if not focused then self.endurance:reset() end
    end
    function h:observeCombatAbility(s,now)
        if not s.alive then return end
        -- FeralHit does not identify which ordinary bite or ability caused
        -- damage. Keep the real reply, but suspend ordinary-bite attribution
        -- across this bounded overlap rather than training cadence on it.
        self.abilityEvidenceUntil=now+2.6
        for _,tx in ipairs(self.transactions) do
            if tx.generation==s.generation and tx.nativeAt and not tx.closed
                and not tx.feedback and not tx.abilityAmbiguous
                and now>=tx.nativeAt and now-tx.nativeAt<2.6 then
                tx.abilityAmbiguous,tx.rateEligible,tx.dirty=true,false,true
            end
        end
    end
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
        self:releaseSurface()
        if self.drop then
            bridge:restoreAttribute(self.drop.char,"FeralFlyDrop",true,self.drop.before)
            self.drop = nil
        end
    end
    function h:releaseSurface()
        self.features.leases:release("surface")
        self.surfaceUntil = nil
        local request=self.surfaceRequest;self.surfaceRequest=nil
        if request then
            bridge:restoreAttribute(request.char,"FeralFlyRequest",request.value,request.before)
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
        if not self.registry.byId.flight.requested or self:hasNativeGrab(now)
            or s.talonLock==nil then return false end
        local config=bridge:config("FlightConfig")
        local compatible,eligible=pcall(function() return config.canFly(s.char) end)
        if not compatible or eligible~=true then return false end
        -- The captured Talon controller owns Space/ButtonB for any eligible
        -- animal using this binding. Dive has a different native cancel path.
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
                return true
            end
        end
        return false
    end
    function h:stepFlightHandoff(s,now)
        if self.flightRepair then
            local r=self.flightRepair
            if not s.alive or r.char~=s.char or r.generation~=s.generation or s.grab or s.captured or s.ability or s.chat or s.gameMenu
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
        self.flightRepair={char=s.char,generation=s.generation,at=now,position=s.root.Position}
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
        self.tests:record("feature_changed",{feature=id,requested=on==true})
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
        if id=="autoBite" and not on then self.combatInput:pause("auto bite disabled",now) end
        if id=="holdBite" and not on then
            self.middlePollArmed=false
            self.physicalM1Input=nil
            self.combatInput:cancel()
            self:disarmDesktopHold(now)
        end
        if id=="attackSpeed" then bridge.biteTiming=nil;self.combatInput.nextAttempt=0;self.combatInput:resetRate() end
        if id=="enduranceMove" then self.endurance:setEnabled(on) end
        if id=="voice" then self.voice:setEnabled(on) end
        self.features.nextReconcile = 0
        local s = bridge:snapshot(now,false)
        self.features:reconcile(s,now,true) -- both true AND false are reconciled
        if id=="reach" then
            self.guide,self.guideAt=nil,nil
            self.nextScan=0
            self.policy.combatApproachUntil=0
        end
        self:ackLocal(s)
        self:save()
        return self.registry.byId[id].applied == (on == true)
    end
    function h:characterChanged(generation)
        local now = bridge.clock()
        bridge:paintHippoGait(nil)
        self.endurance:reset()
        self.recovery:release("animal changed",now)
        self.recovery:clearPose()
        self.recovery.lastAutomaticCharacter,self.recovery.previous = nil,nil
        self.recovery.observations,self.recovery.nativeEchoObserved = {},false
        self.recovery.conditionChar,self.recovery.conditionSeenUntil,self.recovery.conditionSeen=nil,0,{}
        self.recovery.backoffUntil,self.recovery.nextObserve=0,0
        self.recovery.releaseFailedChar,self.recovery.releasingChar=nil,nil
        bridge:clearCombatTargets()
        bridge.biteTiming,bridge.deferNativeDiscovery=nil,false
        self.policy.manualRest,self.policy.manualIntentUntil = false,0
        self.nativeGrabBusy,self.nativeGrabSession,self.nativeGrabUntil=false,nil,nil
        self.abilityEvidenceUntil=nil
        self.policy.attackUntil,self.policy.actionUntil,self.policy.lastRestRelease=0,0,-math.huge
        self.policy.combatApproachUntil=0
        self.grab:reset("animal changed")
        self.nativeGrabSession=nil
        self:cancelGrabWake()
        self.grabInput:release()
        bridge:releaseSyntheticBite()
        self.feeding:close(now)
        self.combatInput:cancel()
        self:disarmDesktopHold(now)
        self.middlePollArmed=false;self.middlePollDown=nil
        self.physicalM1Input=nil;self.physicalM1MissingSince=nil
        self.combatInput:resetRate()
        self.extendedConfidence=setmetatable({},{__mode="k"})
        bridge.extendedConfidence=self.extendedConfidence
        self.hippo:reset()
        self.rescue:cancel("animal changed")
        self:stopWalk("animal changed")
        self:clearFlight()
        self.features:releaseFlag()
        self.features.nextReconcile = 0
        self.climbQueue,self.guide,self.transactions,self.lastIntent = nil,nil,{},nil
        self.snapshot=nil
        self.ledger.previous = nil
        self.ledger.staminaObservation=nil
        self.lastSurvival,self.lastGrabClock,self.lastGrabPending,self.combatStatusAt=nil,nil,nil,nil
        self.combatStatus,self.biteReadiness=nil,nil
        self.nextScan,self.nextSlow,self.nextSample,self.nextGrabPoll=0,0,0,0
        self.anchor,self.anchorChar = nil,nil
        self.ledger:event("character_generation",now,{generation = generation})
        self.tests:characterChanged(bridge.character)
        self.nextWalk = now+90
        self.nextFlight,self.nextEscape,self.rescue.nextAt=0,0,0
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
        local s=bridge:snapshot(now,true);s.grab=self:hasNativeGrab(now)
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
        -- Once this real physical M1 has been held long enough for the
        -- hub to own repeat, no *second* InputBegan can originate from that
        -- same uninterrupted hardware press. Ignore any later replay echo
        -- even when the executor delivers it after the short grace window.
        -- It still reaches FERAL's original InputBegan listener normally.
        if bridge.holdBinding=="M1" and kind==Enum.UserInputType.MouseButton1
            and self.physicalM1Input~=nil and input~=self.physicalM1Input
            and self.combatInput.held and self.combatInput.held.handoff
            and not self.ui:contains(bridge.UserInputService:GetMouseLocation()) then
            return
        end
        -- Virtual/executor mouse events may be delivered after the sending API
        -- returns. The short owned replay window is authoritative here; a
        -- synthetic Up can make IsMouseButtonPressed false before its echo.
        if kind==Enum.UserInputType.MouseButton1 and (bridge.syntheticPressing
            or bridge.syntheticM1~=nil or now<(bridge.syntheticM1Until or 0)) then return end
        local previous = self.earlyInputs[input]
        if previous and now-previous < .1 then return end
        self.earlyInputs[input] = now
        local click = kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2
        local primary = kind == Enum.UserInputType.MouseButton1
        local point = bridge.UserInputService:GetMouseLocation()
        if (click or key==Enum.KeyCode.ButtonR2) and self.ui:contains(point) then
            if primary or key==Enum.KeyCode.ButtonR2 then
                self.inputSuspended=true
                self.physicalM1Input=nil
                self.combatInput:cancel()
            end
            return
        end
        local s = bridge:snapshot(now,false)
        if s.gameMenu or self.windowFocused==false then return end
        if primary or key==Enum.KeyCode.ButtonR2 then
            self.inputSuspended=false
            if primary then self.physicalM1Input=input;self.physicalM1MissingSince=nil end
        end
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
        local flightCancel=(key==Enum.KeyCode.Space or key==Enum.KeyCode.ButtonB) and self:noteFlightCancel(input,s,now)
        if flightCancel then
            self.policy:input("action",now);self.recovery:release("manual native flight release",now)
            self.combatInput:pause("native flight release",now);return
        end
        -- WolfController binds E/ButtonB to native feeding. Preserve flight's
        -- active ButtonB cancellation, which has priority over feeding.
        if key == Enum.KeyCode.E or key==Enum.KeyCode.ButtonB and not (s.ability or s.flying)
            or (primary or kind == Enum.UserInputType.Touch) and self:isFeedControl(input) then
            self.feeding:input(s,now)
            self.policy:input("action",now)
            self.recovery:release("manual feeding input",now)
            self.combatInput:pause("manual feeding input",now);self.rescue:cancel()
            return
        end
        if primary or key == Enum.KeyCode.ButtonR2 then
            self.combatInput:manualAttack(now)
            self.policy:input("attack",now)
            local restReleased=self.recovery:release("attack input",now)
            if primary or key == Enum.KeyCode.ButtonR2 then
                self.feeding:attack(s,now);self.rescue:cancel()
                local tx = { intent = now, input=input,lock = self.policy:restLocked(now),
                    generation = s.generation,restExitFailed=not restReleased }
                self.lastIntent = tx
                table.insert(self.transactions,tx)
                if #self.transactions > 32 then table.remove(self.transactions,1) end
                self.ledger:event("attack_intent",now,{restLock = tx.lock})
                if restReleased then self.combatInput:input(s,now,primary and "M1" or "R2",input)
                else self.combatInput:pause("native Rest exit pending",now) end
            end
        elseif key == Enum.KeyCode.E or key == Enum.KeyCode.F or key == Enum.KeyCode.G
            or key==Enum.KeyCode.Z or key==Enum.KeyCode.X
            or key == Enum.KeyCode.Q or key == Enum.KeyCode.Space then
            self.policy:input("action",now)
            self.recovery:release("manual native action",now)
            -- Preserve a physically held primary attack across temporary
            -- ability/movement actions. Native readiness still gates a bite.
            self.combatInput.pending=nil
            if key ~= Enum.KeyCode.Space then self.rescue:cancel() end
        end
    end
    -- The helper is a local, scoped physical-input remap. These files carry
    -- only the current session token, sequence, readiness and held boolean.
    -- Never execute file contents or accept a signal from an older hub.
    function h:desktopReady(armed,now,force)
        if not self.leftHoldBridge or not self.leftHoldIo.available then return false end
        if not force and self.leftHoldArmed==armed and now<(self.nextLeftReady or 0) then return self.leftHoldReadyWritten==true end
        self.nextLeftReady=now+.12
        self.leftHoldArmed=armed
        local ok,written=pcall(self.leftHoldIo.write,LEFT_READY..".json",{schema=LEFT_READY,
            token=self.leftHoldToken,armed=armed==true})
        self.leftHoldReadyWritten=ok and written~=false
        return self.leftHoldReadyWritten
    end
    function h:disarmDesktopHold(now)
        if not self.leftHoldBridge then return end
        -- A hard boundary changes the input-session identity. Both legacy and
        -- current helpers must then discard the captured press until real Up/Down.
        self.leftHoldEpoch+=1
        self.leftHoldToken=self.token.."_"..tostring(self.leftHoldEpoch)
        self.leftHoldRevoked=true
        self.leftHoldAwaitFresh=true
        self.leftHoldLastAt=nil
        self.leftHoldLastSequence=nil
        self.leftHoldIntent=false
        self.leftHoldPaused,self.leftHoldResumeAt=false,nil
        self:desktopReady(false,now,true)
        local held=self.combatInput.held
        if held and held.source=="desktop" then self.combatInput:release("M3",now) end
    end
    function h:desktopHoldReport()
        local now=bridge.clock()
        return {enabled=self.leftHoldBridge==true,armed=self.leftHoldArmed==true,
            helperConnected=self.leftHoldLastAt~=nil and now-self.leftHoldLastAt<=.55,
            held=self.combatInput.held~=nil and self.combatInput.held.source=="desktop",
            intent=self.leftHoldIntent==true,waitingFresh=self.leftHoldAwaitFresh==true,
            primaryReportedDown=self.leftHoldRawPrimary==true,
            rawPrimaryDuringHold=self.leftHoldRawSamples or 0,
            epoch=self.leftHoldEpoch,helperInstance=self.leftHoldHelperInstance,
            logicalResets=bridge.desktopLogicalResets or 0,
            dispatched=bridge.desktopDispatches or 0,
            reason=self.leftHoldReason}
    end
    function h:desktopHoldTick(s,now,critical)
        if not self.leftHoldBridge then return end
        self.leftHoldRawPrimary=s.mouseHeld==true and not bridge.syntheticM1
        -- In desktop mode, the physical middle button is not the trigger.
        s.middleHeldKnown=true;s.middleHeld=false
        local hard=not self.active or self.closed or self.windowFocused==false
            or not s.alive or s.chat or s.gameMenu or s.captured or self.policy.manualRest
            or not self.registry.byId.holdBite.requested
        if hard then
            if not self.leftHoldRevoked then self:disarmDesktopHold(now) end
        else self.leftHoldRevoked=false end
        if not hard and (critical or self:hasNativeGrab(now) or self.grabInput.lease or s.protectedInteraction) then
            -- Minigames are a temporary pause, not proof that the physical
            -- desktop M1 was released. Disarm the helper's ready heartbeat
            -- and stop owned pulses, but permit a fresh *positive* same-window
            -- helper confirmation after the minigame ends.
            self:desktopReady(false,now,false)
            self.leftHoldPaused=true
            self.leftHoldIntent=false
            self.leftHoldResumeAt=nil
            local current=self.combatInput.held
            if current and current.source=="desktop" then
                self.combatInput:release("M3",now)
            end
            self.leftHoldReason="minigame priority (paused, no attack dispatch)"
            return
        end
        local eligible=not hard
        if eligible then
            local ok,allowed=pcall(bridge.mouseGameplayPoint,bridge,nil,true)
            eligible=ok and allowed==true
        end
        if not eligible and not hard then
            self.leftHoldPaused=true;self.leftHoldResumeAt=nil
        elseif eligible and self.leftHoldPaused then
            self.leftHoldPaused=false;self.leftHoldResumeAt=now+.20
        end
        local ready=self:desktopReady(eligible==true,now,false)
        if not ready then
            eligible=false
            self.leftHoldReason="local readiness file unavailable"
        end
        if now>=(self.nextLeftIntent or 0) and self.leftHoldIo.available then
            self.nextLeftIntent=now+.04
            local ok,v=pcall(self.leftHoldIo.read,LEFT_INTENT..".json")
            if ok and type(v)=="table" and v.schema==LEFT_INTENT and v.token==self.leftHoldToken
                and Core.finite(v.sequence) and v.sequence>=1 and v.sequence<=1e12
                and v.sequence%1==0 and type(v.held)=="boolean" then
                local instance=type(v.instance)=="string" and v.instance:match("^[a-f0-9]+$") and #v.instance==32 and v.instance or nil
                if instance and self.leftHoldHelperInstance and instance~=self.leftHoldHelperInstance then
                    self.leftHoldHelperInstance=instance
                    self:disarmDesktopHold(now)
                    self.leftHoldReason="helper restarted; waiting for a fresh physical press"
                    return
                end
                if instance then self.leftHoldHelperInstance=instance end
                if self.leftHoldLastSequence~=nil and v.sequence<self.leftHoldLastSequence and not v.held then
                    self:disarmDesktopHold(now)
                    self.leftHoldReason="helper sequence restarted; input session renewed"
                    return
                end
                if self.leftHoldLastSequence==nil or v.sequence>self.leftHoldLastSequence then
                    self.leftHoldLastSequence=v.sequence
                    self.leftHoldLastAt=now
                    self.leftHoldIntent=v.held
                    if not v.held then self.leftHoldAwaitFresh=false end
                end
            end
        end
        local connected=self.leftHoldLastAt~=nil and now-self.leftHoldLastAt<=.55
        local resumeFresh=not self.leftHoldResumeAt or now>=self.leftHoldResumeAt
            and self.leftHoldLastAt~=nil and self.leftHoldLastAt>=self.leftHoldResumeAt
        -- Processed input echoes can leave the hub suspended after a temporary
        -- GUI action. Only a new, positively held signal from the installed
        -- foreground-scoped helper may restore desktop attack ownership.
        -- The gameplay hit-test and minigame/offer gates above still apply.
        if eligible and connected and resumeFresh and self.leftHoldIntent and not self.leftHoldAwaitFresh
            and self.inputSuspended and self.windowFocused~=false then
            self.inputSuspended=false
            self.ledger:event("desktop_left_hold_resumed_after_gui_pause",now)
        end
        local held=self.combatInput.held
        if not eligible or not connected or not resumeFresh or not self.leftHoldIntent or self.leftHoldAwaitFresh then
            if held and held.source=="desktop" then self.combatInput:release("M3",now) end
            -- Short helper/GUI readiness gaps should pause, not permanently
            -- revoke a captured physical press. Focus and actual game menus
            -- remain strict boundaries: the helper requires another Down edge.
            if self.windowFocused==false or s.chat or s.gameMenu then
                self.leftHoldAwaitFresh=true
            end
            if ready then
                self.leftHoldReason=not eligible and "gameplay input unavailable"
                    or not connected and "waiting for desktop helper"
                    or not resumeFresh and "waiting for fresh held confirmation after pause"
                    or self.leftHoldAwaitFresh and "waiting for fresh physical press" or "ready"
            end
            return
        end
        if not held then
            if self:startMiddle(s,now,nil) and self.combatInput.held then
                self.combatInput.held.source="desktop"
                self.ledger:event("desktop_left_hold_started",now)
            end
            held=self.combatInput.held
        end
        if held and held.source=="desktop" and bridge.desktopOwnsPrimary(s,now) then
            s.middleHeld=true
            -- This is an internal ownership classification only. Preserve
            -- the raw read for diagnostics; never alter engine properties.
            if self.leftHoldRawPrimary then self.leftHoldRawSamples=(self.leftHoldRawSamples or 0)+1 end
            s.desktopPrimaryRaw=s.mouseHeld
            s.mouseHeld=false
            s.physicalM1Held=false
            self.leftHoldReason=self.leftHoldRawPrimary and "desktop owns reported primary" or "desktop hold active"
        end
    end
    function h:startMiddle(s,now,input)
        -- A real middle press does not activate a primary-click GUI control.
        -- Only actual menu/text/focus/lifecycle ownership gates the hold.
        -- Querying every native HUD button here used to discard the entire
        -- physical press before the route could even be selected.
        local reason
        if self.closed or not self.active then reason="hub inactive"
        elseif self.windowFocused==false then reason="window unfocused"
        elseif not s.alive then reason="no active animal"
        elseif s.chat or s.gameMenu or bridge.UserInputService:GetFocusedTextBox() then reason="menu or text entry"
        elseif not self.registry.byId.holdBite.requested then reason="hold feature disabled"
        elseif self.ui:contains(bridge.UserInputService:GetMouseLocation()) then reason="hub UI" end
        if reason then
            self.combatInput.middleAdmission=reason
            self.ledger:event("m3_press_rejected",now,{reason=reason})
            return false
        end
        self.combatInput.middleAdmission="physical hold accepted"
        if self.combatInput.held and self.combatInput.held.key=="M3"
            and self.combatInput.held.generation==s.generation then return true end
        self:physicalInput("other")
        self.inputSuspended=false
        self.policy:input("attack",now)
        self.feeding:attack(s,now);self.rescue:cancel()
        self:stopWalk("middle mouse attack input")
        self.recovery:release("middle mouse attack input",now)
        self.combatInput:input(s,now,"M3",input)
        return true
    end
    function h:input(input,processed)
        local kind,key = input.UserInputType,input.KeyCode
        if bridge.holdBinding=="M3" and kind==Enum.UserInputType.MouseButton3 then
            if self.leftHoldBridge then return end
            -- Camera processing alone is not a gameplay veto. UI/menu/text checks
            -- in startMiddle still reject consumed control clicks.
            self.middlePollDown=true;self.middlePollArmed=false
            local now=bridge.clock()
            self:startMiddle(bridge:snapshot(now,false),now,input)
            return
        end
        -- Once this real physical M1 has been held long enough for the
        -- hub to own repeat, no *second* InputBegan can originate from that
        -- same uninterrupted hardware press. Ignore any later replay echo
        -- even when the executor delivers it after the short grace window.
        -- It still reaches FERAL's original InputBegan listener normally.
        if bridge.holdBinding=="M1" and kind==Enum.UserInputType.MouseButton1
            and self.physicalM1Input~=nil and input~=self.physicalM1Input
            and self.combatInput.held and self.combatInput.held.handoff
            and not self.ui:contains(bridge.UserInputService:GetMouseLocation()) then
            return
        end
        -- A replayed InputBegan may arrive asynchronously, including with
        -- processed=true. Never let that echo permanently suspend the real M1.
        if kind==Enum.UserInputType.MouseButton1 and (bridge.syntheticPressing
            or bridge.syntheticM1~=nil or bridge.clock()<(bridge.syntheticM1Until or 0)) then return end
        if kind == Enum.UserInputType.MouseButton2 and bridge.clock() < (self.syntheticUntil or 0) then return end
        self:physicalInput("other")
        if processed then
            -- Once a world-originated real M1 has entered handoff, later
            -- processed mouse echoes must not cancel that real InputObject.
            -- The original processed physical click is still cancelled,
            -- and a focused UI/text field always takes priority.
            if bridge.holdBinding=="M1" and kind==Enum.UserInputType.MouseButton1
                and self.physicalM1Input~=nil and input~=self.physicalM1Input
                and self.combatInput.held and self.combatInput.held.handoff
                and not bridge.UserInputService:GetFocusedTextBox()
                and not self.ui:contains(bridge.UserInputService:GetMouseLocation()) then return end
            -- Native movement/ability bindings consume their own keyboard
            -- events too. Preserve those observations (e.g. X/Z gait intent),
            -- while consumed attack inputs never establish held ownership.
            if kind~=Enum.UserInputType.MouseButton1 and key~=Enum.KeyCode.ButtonR2
                and not bridge.UserInputService:GetFocusedTextBox() then
                self:preInput(input)
            end
            -- A later native/UI binding can consume the original event after
            -- our priority observer. Never turn its consumed click into a
            -- delayed attack through the optional Rest-exit buffer.
            local pending,held=self.combatInput.pending,self.combatInput.held
            if kind==Enum.UserInputType.MouseButton1 or key==Enum.KeyCode.ButtonR2
                or pending and pending.input==input or held and held.input==input then
                if bridge.holdBinding=="M3" and held and held.key=="M3"
                    and not bridge.UserInputService:GetFocusedTextBox()
                    and not self.ui:contains(bridge.UserInputService:GetMouseLocation()) then
                    if pending and pending.input==input then self.combatInput.pending=nil end
                    self.physicalM1Input=nil
                else
                    self.combatInput:cancel()
                    self.physicalM1Input=nil
                    self.inputSuspended=true
                end
            end
            if self.lastIntent and self.lastIntent.input==input and not self.lastIntent.nativeAt then
                self.lastIntent.consumed=true
            end
            return
        end
        if bridge.UserInputService:GetFocusedTextBox() then return end
        self:preInput(input)
        if key == Enum.KeyCode.Q and self.registry.byId.climb.requested then
            local s = bridge:snapshot(bridge.clock(),false)
            local allowed = self.policy:allowed("climb",s,s.now)
            if allowed and not s.climbing and type(s.climber) == "number" and s.climber >= 1 then
                self.climbQueue = { generation = s.generation, expires = s.now+2.25,
                    earliest = s.now+.1, attempts = 0 }
            end
        end
    end
    function h:inputEnded(input)
        if self.closed or not self.active then return end
        local kind,key=input.UserInputType,input.KeyCode
        if kind==Enum.UserInputType.MouseButton3 and bridge.holdBinding=="M3" then
            if self.leftHoldBridge then return end
            self.middlePollArmed=false
            self.combatInput:release("M3",bridge.clock())
            return
        elseif kind==Enum.UserInputType.MouseButton1 then
            -- Owned synchronous releases may reuse the engine's mouse object.
            -- Suppress those before consulting optional InputObject identity.
            if bridge.syntheticReleasing then return end
            -- A matching real InputObject can end during a synthetic Down
            -- callback. Do not discard that genuine release solely because
            -- syntheticPressing is set; generated Up has syntheticReleasing.
            if input==self.physicalM1Input then
                self.physicalM1Input=nil
                self.combatInput:release("M1",bridge.clock())
                return
            end
            if bridge.syntheticPressing then return end
            if bridge.syntheticM1~=nil
                or bridge.clock()<(bridge.syntheticM1Until or 0) then
                return
            end
            -- Fallback for late physical releases and hub sessions that
            -- started after M1 was already held: the existing poll source
            -- also clears on the next native IsMouseButtonPressed=false.
            self.physicalM1Input=nil
            self.combatInput:release("M1",bridge.clock())
        elseif key==Enum.KeyCode.ButtonR2 then
            self.combatInput:release("R2",bridge.clock())
        end
    end
    function h:nativeAttribute(key)
        if self.closed or not self.active then return end
        local now = bridge.clock()
        local s = bridge:snapshot(now,false)
        if s.ability or key=="FeralCrushBiteAt" and Core.finite(bridge:attribute(s.char,key)) then
            self:observeCombatAbility(s,now)
        end
        if key=="FeralCrushAt" then self.features:hippoAttribute(s) end
        if key=="FeralCrushAt" or key=="FeralCrushBiteAt" then self.hippo:observe(s,now) end
        if key=="FeralCrushBiteAt" and s.species=="Hippo" and Core.finite(bridge:attribute(s.char,key)) then
            self.policy:input("attack",now)
            self.recovery:release("native Crusher release",now)
            self:stopWalk("native Crusher release")
            self.ledger:event("hippo_native_bite_marker",now,{damageAcceptance="unverified"})
        end
        if key == "WolfRest" then self.recovery:echo(s,now)
        elseif key == "WolfBiteAt" and Core.finite(bridge:attribute(s.char,key)) then
            bridge.biteTiming=nil
            if not s.alive then return end
            self.combatInput:marker(s,now)
            self.tests:observeBite(s,now)
            self.policy.attackUntil = math.max(self.policy.attackUntil,now+1.1)
            self.recovery:release("native bite marker",now)
            local tx = self.lastIntent
            if not tx or tx.nativeAt or now-tx.intent > 1.3 then
                tx = { intent = now,generation = s.generation }
                table.insert(self.transactions,tx)
                if #self.transactions > 32 then table.remove(self.transactions,1) end
            end
            tx.nativeAt,tx.claimDue,tx.classified = now,now+bridge:biteDelay(s.char),false
            tx.abilityAmbiguous=s.ability==true or now<(self.abilityEvidenceUntil or 0)
            -- Only confirmed *stock*-range contacts can train attack cadence.
            -- Extended-only reach, predictive FX, and a bare bite sound are
            -- never treated as server proof.
            local guide=self.guide
            local focus=guide and guide.target
            local fresh=focus and focus.root and focus.root.Parent
                and now-(self.guideAt or -math.huge)<.28
            -- Pin the target selected at the actual native bite marker.
            -- The guide can switch to another animal before delayed contact.
            tx.focusTarget=fresh and focus or nil
            tx.focusExtendedOnly=fresh and guide.extended and guide.extended.valid
                and not (guide.baseline and guide.baseline.valid) or false
            local valid=fresh and guide and guide.baseline and guide.baseline.valid
            -- Reuse the already checked guide, avoiding extra expensive or
            -- throwable world queries within a native attribute callback.
            local clear=valid and focus and focus.root and focus.root.Parent
                and guide.blocked~=true and guide.obstruction~=true
            tx.rateTarget=clear and focus or nil
            tx.rateEligible=tx.rateTarget~=nil and self.registry.byId.attackSpeed.requested
                and (self.combatInput.held~=nil or self.registry.byId.autoBite.requested) and not tx.abilityAmbiguous
            tx.observeUntil=tx.claimDue+2.0
            tx.hpBefore={}
            for _,target in ipairs(bridge.allCandidates or {}) do
                if bridge:currentTargetBody(target) and (target.root.Position-s.root.Position).Magnitude<=45 then
                    tx.hpBefore[target.char]={hp=target.hum.Health,maxHP=target.hum.MaxHealth,hum=target.hum}
                end
            end
            self.ledger:event("native_bite_marker",now,{requestObserved = false,claimObserved = false})
        else
            -- Native actions can begin between heartbeats. Release competing
            -- automation on the actual state change, preserving manual input.
            s.grab,s.rescuing = self:hasNativeGrab(now),self.rescue.pending~=nil
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
    function h:nativeEvent(kind,event,data,...)
        if self.closed or not self.active then return end
        if kind == "hippo" then self.tests:hippoReply(event,data,...);return end
        if kind == "feedback" then
            self.tests:feedback(event,data)
            self.ledger:event("native_hit_feedback",bridge.clock(),{damageAcceptance = "unverified"})
            if event=="hit" and type(data)=="table" and data.a==bridge.player.Character then
                local now=bridge.clock()
                self.hippo:feedback(data,now)
                local tx,ambiguous=Controller.matchFeedback(Core,self.transactions,data,now)
                if tx then
                    tx.feedback=data;tx.nativeTarget=data.v;tx.dirty=true
                    tx.targetMismatch=tx.localTarget~=nil and tx.localTarget~=data.v
                    if Core.finite(data.dmg) and data.dmg>0 and data.safe~=true then
                        tx.positiveReply=true
                        local confidence=self.extendedConfidence[data.v]
                        if confidence then
                            confidence.misses=0
                            confidence.waitUntil=0
                        end
                    end
                    if tx.rateEligible and tx.rateTarget and tx.rateTarget.char==data.v
                        and data.safe~=true and Core.finite(data.dmg) and data.dmg>0
                        and not tx.fastConfirmed then
                        tx.fastConfirmed=true
                        self.combatInput:confirmed(now)
                    end
                end
                self.ledger:event("native_outgoing_hit_reply",now,{safe=data.safe==true,damage=data.dmg,
                    matched=tx~=nil,ambiguous=ambiguous==true})
                if not tx and Core.finite(data.dmg) and data.dmg>0 and data.safe~=true then
                    -- A genuine reply must not be displayed as a ghost
                    -- merely because its client bite ID was ambiguous.
                    self.lastUnmatchedGameHit=now
                    self.combatStatus="Game reports a hit · local bite association uncertain"
                end
                if not tx then
                    self.ledger:event("native_outgoing_hit_reply_unmatched",now,
                        {reason=ambiguous and "ambiguous overlapping attacks" or "no matching native bite"})
                end
            end
            return
        end
        if kind=="actions" then
            if event=="FeedStop" then self.feeding:stopped(data,bridge.clock()) end
            return
        end
        if kind=="biteLocal" then
            local at=bridge.clock()
            self.ledger:event("client_bite_fx_only",at,{claimObserved=false})
            local candidates,due={},{}
            for index=#self.transactions,1,-1 do
                local tx=self.transactions[index]
                if tx.generation==bridge.generation and tx.nativeAt and not tx.classified
                    and not tx.localTarget and at>=tx.nativeAt and at-tx.nativeAt<1.5 then
                    table.insert(candidates,tx)
                    if at>=(tx.claimDue or tx.nativeAt)-.03 then table.insert(due,tx) end
                end
            end
            -- Never attach an old delayed impact to a new bite whose claim
            -- has not occurred. Ambiguous overlaps remain local observations.
            local tx=#candidates==1 and candidates[1] or #due==1 and due[1] or nil
            if tx then
                tx.localTarget,tx.localImpactAt,tx.dirty=event,at,true
                self.ledger:event("native_client_bite_candidate",at,{claimObserved=false})
            else self.ledger:event("native_client_bite_candidate_unmatched",at,{claimObserved=false}) end
            return
        end
        -- Observe the game's action ownership even with automation OFF.
        -- This never schedules presses or leases its controls while disabled.
        if kind=="grab" and type(data)=="table" then
            local session=data.f or (event=="begin" and data.id)
            local observed=self.nativeGrabSession
            local at=bridge.clock()
            if M.grab.validId(session) then
                if event=="begin" then
                    self.nativeGrabSession={id=session,char=bridge.player.Character,generation=bridge.generation,at=at}
                    self.recovery:release("native minigame",at);self:stopWalk("native minigame")
                elseif observed and tostring(observed.id)==tostring(session)
                    and observed.generation==bridge.generation then
                    if event=="end" then self.nativeGrabSession=nil
                    elseif event=="strike" or event=="res" or event=="bite" or event=="n" then observed.at=at end
                end
            end
        end
        local now = bridge:serverNow()
        if kind=="grab" and event=="begin" then
            bridge:releaseSyntheticBite()
            self.combatInput.awaiting=nil
        end
        self.nativeGrabBusy=self:hasNativeGrab(bridge.clock())
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
        if not now then return end
        p.localEnds=p.localEnds or bridge.clock()+math.max(0,p.ends-now)
        if p.at<=now then return end
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
            local state,known=nativeState(native)
            local cfg=bridge:config("GrabV2Config")
            if state or known==true then
                self.grab:syncNative(state,clock,s.generation,cfg and cfg.PERFECT or .32,cfg and cfg.PASSES or 2.5,now)
            end
        end
        local p=self.grab.pending
        if not p then
            -- Session timeout must also run between strikes; otherwise a lost
            -- end packet with no private UI handle can block recovery forever.
            self.grab:tick(clock,s.generation,false,function()return false end)
            return
        end
        if self.lastGrabClock==clock and self.lastGrabPending==p then return end
        self.lastGrabClock,self.lastGrabPending=clock,p
        s.grab=true
        self.grab:tick(clock,s.generation,self.policy:allowed("grab",s,now),function(session,strike)
            -- Native-issued IDs and the actual current server clock only.
            -- Recheck after inspection; never backdate or anticipate a press.
            local at=bridge:serverNow()
            if not at then return false end
            if at<p.t0 or at>=p.ends-.002
                or math.abs(M.grab.triangle(at,p.t0,p.speed,p.from)-p.target)>p.half*.98 then
                return false,"clock_moved",at
            end
            local sent=bridge:fire("FeralGrabV2","press",session,strike,at)
            -- An optional native-UI annotation cannot turn an already issued
            -- press into a failed dispatch and allow a duplicate submission.
            if sent then pcall(bridge.markGrabPress,bridge,session,strike,now) end
            return sent
        end)
    end
    function h:requestFlight()
        local now = bridge.clock()
        if not self.active or self.closed or not self.registry.byId.flight.requested or now < (self.nextFlight or 0) then return false end
        local s = bridge:snapshot(now,true)
        s.grab,s.rescuing = self:hasNativeGrab(now),self.rescue.pending~=nil
        local c = bridge:config("FlightConfig")
        local ok,canFly = pcall(function() return c.canFly(s.char) end)
        if not ok or canFly ~= true or s.flying or not s.surface or s.underwater
            or not self.policy:allowed("flight",s,now) then return false end
        if type(c.WATER) ~= "table" or type(c.WATER.NO_TAKEOFF) ~= "boolean" then return false end
        self.recovery:release("surface takeoff input",now)
        local applied = self.features.leases:apply("surface",{
            {target = c.WATER,key = "NO_TAKEOFF",value = false,kind = "boolean"} })
        if not applied then return false end
        self.surfaceRequest={char=s.char,value=now,before=bridge:attribute(s.char,"FeralFlyRequest")}
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
        local endurance=r.byId.enduranceMove
        r:ack("enduranceMove",endurance.requested,endurance.requested and "PARTIAL" or "OFF",
            endurance.requested and self.endurance.status.." · server acceptance unverified" or endurance.detail,
            {localSpeed=self.endurance.observedSpeed,peerVerified=false,corrections=self.endurance.corrections})
        local zoom=r.byId.zoom
        local zoomApplied=self.zoom:set(self.active and zoom.requested)
        r:ack("zoom",zoomApplied,not zoom.requested and "OFF" or zoomApplied and "CLIENT" or "UNAVAILABLE",self.zoom.reason)
        for _,id in ipairs({"combat","colours","finder","menu"}) do
            r:ack(id,true,id == "combat" and "ARMED" or "CLIENT",r.byId[id].detail)
        end
        local hearing=r.byId.voice
        local hearingActive=self.voice.enabled and hearing.requested
        r:ack("voice",hearingActive,not hearing.requested and "OFF" or hearingActive and "ARMED" or "WAITING",
            self.voice:summary())
        for _,id in ipairs({"esp","tags","biteHelper"}) do
            local f = r.byId[id]
            r:ack(id,f.requested,f.requested and "CLIENT" or "OFF",f.detail)
        end
        local auto=r.byId.autoBite
        local native=bridge.wolfActions and bridge.wolfActions.tryBite~=nil
        local hold=r.byId.holdBite
        local m1Native=bridge.holdBinding=="M1" and not native and bridge:nativeWolfInputAction(s.now or bridge.clock()) or nil
        local middle=bridge.holdBinding=="M3"
        local locked=self.combatInput.middleRoute
        local route=locked or self.combatInput.middleCandidate
        local ordinaryReady=middle and bridge:combatInputCompatible() and bridge:hasHeldInputBackend()
        local nativeGC=native and bridge.wolfActions.discovery=="validated own heap closure"
        local sourceLabel=nativeGC and "Original native callback recovered · "
            or native and "Original native callback · "
            or m1Native and "Original WolfController M1 input callback · "
            or "Original attack handler inaccessible · "
        local routeReady=native or m1Native~=nil
        if middle then
            sourceLabel=locked and ("M3 locked: "..(locked=="NATIVE" and "native callback" or "ordinary input").." · ")
                or route and ("M3 verifying: "..route.." · ") or "M3 awaiting first verified bite · "
            routeReady=route=="NATIVE" and native or route=="INPUT" and ordinaryReady
                or route==nil and (native or ordinaryReady)
        end
        r:ack("holdBite",hold.requested and routeReady,
            not hold.requested and "OFF" or middle and locked and routeReady and "ARMED"
                or not middle and native and "ARMED" or routeReady and "PARTIAL" or "WAITING",
            hold.requested and sourceLabel..self.combatInput.status or hold.detail)
        r:ack("autoBite",auto.requested and native,not auto.requested and "OFF" or native and "ARMED" or "WAITING",
            auto.requested and self.combatInput.status or auto.detail)
        local movement=r.byId.hippoMove
        local hippo=s.alive and s.species=="Hippo"
        local moved=hippo and self.features.leases:valid("hippoGait")
        r:ack("hippoMove",movement.requested and moved,not movement.requested and "OFF" or moved and "CLIENT" or "WAITING",
            not hippo and "waiting for Hippo" or moved and "charge movement inputs applied; displacement unverified" or self.features.hippoStatus)
        local release=r.byId.hippoRelease
        local releaseReady=hippo and self.hippo.native~=nil
        r:ack("hippoRelease",release.requested and releaseReady,not release.requested and "OFF" or releaseReady and "ARMED" or "WAITING",
            self.hippo.releaseStatus)
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
        local speed=r.byId.attackSpeed
        if speed.requested and speed.applied then
            speed.reason=string.format("Adaptive %.2fx repeat request pacing · native/server limits still apply",
                1/self.combatInput:factor())
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
                ..(s.serverTired and " · server fatigue reported" or not bridge:capability("debugStamina")
                    and " · server fatigue and ability costs remain native" or "")
            r.byId.stamina.observed=item or "unmeasured"
        end
        r.byId.flight.observed = s.flying and "native local flight flag" or "unknown"
        r.byId.climb.observed = s.climbing and "native local climb flag" or "unknown"
        r.byId.survivalAFK.observed = (self.ledger.counts.survival_value_advanced or 0) > 0
            and "survival value advanced; cause unverified" or "unknown"
    end
    function h:correlatedHPDrop(tx)
        local victim=tx.nativeTarget or tx.target and tx.target.char
        local before=victim and tx.hpBefore and tx.hpBefore[victim]
        if not before then return false end
        local ok,hum=pcall(function()return victim:FindFirstChildOfClass("Humanoid")end)
        return ok and hum and hum.Parent and hum.MaxHealth==before.maxHP
            and hum.Health<before.hp-.05 or false
    end
    function h:stepCombat(s,now)
        for _,tx in ipairs(self.transactions) do
            if tx.generation == s.generation and not tx.closed then
                if not tx.nativeAt and now-tx.intent > .45 and not self.combatInput.pending then
                    if not tx.classified then
                        tx.classified = true
                        local status = tx.consumed and "Input handled by native UI or another binding"
                            or tx.restExitFailed and "Native Rest exit failed; normal input preserved"
                            or tx.lock and "No native bite marker · recent Rest lock possible" or "No native bite marker observed"
                        if not self.combatStatusAt or tx.intent>=self.combatStatusAt then
                            self.combatStatus,self.combatStatusAt=status,tx.intent
                        end
                        self.ledger:event("no_native_bite_marker",now,{recentRest = tx.lock == true,consumed=tx.consumed==true})
                    end
                elseif tx.nativeAt and now>=tx.claimDue then
                    if not tx.sampled then
                        tx.sampled = true
                        local target = tx.focusTarget
                        if tx.rateEligible and tx.rateTarget and self.features.originalCombat
                            and bridge:currentTargetBody(tx.rateTarget) then
                            local geometryOK,geo=pcall(bridge.geometry,bridge,self.features.originalCombat,s,tx.rateTarget)
                            local rayOK,blocked=pcall(bridge.occluded,bridge,s,tx.rateTarget)
                            tx.rateAtClaim=geometryOK and geo and geo.valid and rayOK and blocked==false or false
                        end
                        if target and bridge:currentTargetBody(target) then
                            local before=tx.hpBefore and tx.hpBefore[target.char]
                            tx.target,tx.hp,tx.maxHP = target,before and before.hp,before and before.maxHP
                            tx.extendedOnly = tx.focusExtendedOnly==true
                            if tx.extendedOnly then
                                local ok,geo=pcall(bridge.geometry,bridge,self.features.combat,s,target)
                                local clear,blocked=pcall(bridge.occluded,bridge,s,target)
                                tx.extendedClaimValid=ok and geo and geo.valid and clear and blocked==false or false
                            end
                        end
                        self.ledger:event("client_candidate_sample",now,{found = target ~= nil,claimObserved = false})
                    end
                    if now>=(tx.nextHPRead or 0) or tx.dirty then
                        tx.nextHPRead=now+.1
                        local char=tx.nativeTarget or tx.localTarget or tx.target and tx.target.char
                        if tx.observedChar~=char then
                            tx.observedChar,tx.hpDrop,tx.hpInvalid=char,false,false
                        end
                        local ok,hum=pcall(function()return char and char:FindFirstChildOfClass("Humanoid")end)
                        local before=char and tx.hpBefore and tx.hpBefore[char]
                        if ok and hum and hum.Parent and before then
                            if (before.hum and hum~=before.hum or hum.MaxHealth~=before.maxHP) and not tx.hpInvalid then
                                tx.hpInvalid,tx.dirty=true,true
                            end
                            if not tx.hpInvalid and Core.finite(hum.Health) and Core.finite(before.hp)
                                and hum.Health<before.hp-.05 and not tx.hpDrop then
                                tx.hpDrop,tx.dirty=true,true
                            end
                        end
                    end
                    if now>=tx.claimDue+.8 and (not tx.classified or tx.dirty) then
                        local first=not tx.classified
                        tx.classified,tx.dirty = true,false
                        local drop=tx.hpDrop and not tx.hpInvalid
                        local damage=tx.feedback and tx.feedback.dmg
                        tx.status = tx.abilityAmbiguous and "Native ability overlaps · ordinary bite impact unassigned"
                            or tx.feedback and tx.feedback.safe==true and "Game reply: target protected"
                            or Core.finite(damage) and damage>0 and (string.format("Game reply reports %.1f damage",damage)
                                ..(drop and " · HP decline correlated" or " · HP change unconfirmed"))
                            or drop and tx.feedback and "Native hit reply + target HP decline · attribution unverified"
                            or drop and "Target HP fell after native marker · attribution unverified"
                            or tx.localTarget and "Local bite impact only · server hit/HP change unconfirmed"
                            or "Native marker observed · no matching HP decline observed"
                        if tx.targetMismatch then tx.status ..= " · local/server target differed" end
                        if not self.combatStatusAt or tx.nativeAt>=self.combatStatusAt then
                            self.combatStatus,self.combatStatusAt=tx.status,tx.nativeAt
                        end
                        if first or drop and not tx.dropReported then
                            self.ledger:event(drop and "target_hp_decline_correlated" or "no_correlated_hp_decline",now,
                                {extendedOnly = tx.extendedOnly == true,nativeReply=tx.feedback~=nil,late=not first,
                                 targetMismatch=tx.targetMismatch==true,damageAcceptance = "unverified"})
                            if drop then tx.dropReported=true end
                        end
                    end
                    if now>=(tx.observeUntil or tx.claimDue+2) then
                        local drop=tx.hpDrop and not tx.hpInvalid
                        local target=tx.target
                        -- Wait for the entire evidence window before adapting
                        -- optional auto-attempts. Silence is not server rejection.
                        if not tx.abilityAmbiguous and tx.extendedOnly and tx.extendedClaimValid and target and target.char
                            and not drop and not tx.positiveReply and not tx.feedback
                            and not (self.lastUnmatchedGameHit and now-self.lastUnmatchedGameHit<1.2) then
                            local entry=self.extendedConfidence[target.char]
                            if not entry then entry={misses=0,waitUntil=0};self.extendedConfidence[target.char]=entry end
                            entry.misses+=1
                            if entry.misses>=2 then entry.waitUntil=now+math.min(4,1.5+entry.misses*.5) end
                            self.ledger:event("extended_contact_unconfirmed",now,
                                {count=entry.misses,autoWait=entry.waitUntil>now})
                        end
                        if not tx.abilityAmbiguous and tx.rateEligible and tx.rateAtClaim and not tx.fastConfirmed and not drop
                            and not (tx.feedback and tx.feedback.safe==true)
                            and (not tx.feedback or tx.rateTarget and tx.feedback.v==tx.rateTarget.char) then
                            self.combatInput:suspect(now)
                        end
                        tx.closed=true;tx.hpBefore=nil
                    end
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
            self:releaseSurface()
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
        -- Recover an executor pulse whose scheduled Up callback never ran.
        if type(bridge.clearStaleSyntheticBite)=="function"
            and bridge:clearStaleSyntheticBite(now) then
            self.ledger:event("stale_mouse_repeat_pulse_released",now)
        end
        if Core.finite(dt) and dt>0 then
            self.frameInterval=(self.frameInterval or dt)*.85+math.min(dt,.25)*.15
        end
        local slow = now >= self.nextSlow
        local critical=self.registry.byId.minigame.requested and self.grab.active and self.grab.pending~=nil
        self.timingCritical,bridge.deferNativeDiscovery=critical,critical
        local s = bridge:snapshot(now,not critical and slow and self.registry.byId.flight.requested)
        if s.ability then self:observeCombatAbility(s,now) end
        if s.chat or s.gameMenu then
            self.inputSuspended=true
            self.physicalM1Input=nil
            self.combatInput:cancel()
        end
        if bridge.holdBinding=="M3" and not self.leftHoldBridge and s.middleHeldKnown then
            if not s.middleHeld then self.middlePollArmed=true
            elseif self.middlePollArmed and not self.middlePollDown then
                self.middlePollArmed=false
                self:startMiddle(s,now,nil)
            end
            self.middlePollDown=s.middleHeld
        end
        if bridge.holdBinding=="M3" then
            -- A late synthetic echo or a missed native M1 release can leave
            -- physicalM1Input latched forever. Only clear it after independent
            -- known-up readings outside every synthetic pulse/grace interval.
            if self.physicalM1Input and s.mouseHeldKnown and not s.mouseHeld
                and not bridge.syntheticM1 and now>=(bridge.syntheticM1Until or 0) then
                self.physicalM1MissingSince=self.physicalM1MissingSince or now
                local ok,state=pcall(function()return self.physicalM1Input.UserInputState end)
                if (ok and (state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel))
                    or now-self.physicalM1MissingSince>=.45 then
                    self.physicalM1Input=nil;self.physicalM1MissingSince=nil
                    self.ledger:event("stale_manual_mouse_owner_cleared",now)
                end
            else
                self.physicalM1MissingSince=nil
            end
            s.physicalM1Held=self.physicalM1Input~=nil or (s.mouseHeld and not bridge.syntheticM1)
        end
        self:desktopHoldTick(s,now,critical)
        if self.inputSuspended then s.attackHeld,s.mouseHeld,s.r2Held,s.middleHeld=false,false,false,false
        elseif bridge.holdBinding=="M3" and self.combatInput.held and self.combatInput.held.key=="M3" then s.attackHeld=true end
        self.snapshot = s
        self.grab.enabled = self.registry.byId.minigame.requested
        local clock = s.serverNow
        if clock then
            self.grabClockLostAt=nil
            local cfg = self.grab.enabled and bridge:config("GrabV2Config")
            local native = self.grab.enabled and self.grabInput:controller(now)
            local nativeState,nativeKnown
            if native and (self.grab.active or now >= (self.nextGrabPoll or 0)) then
                local ok,state,known=pcall(native.state)
                if ok then nativeState,nativeKnown=state,known end
                self.nextGrabPoll=now+.25
            end
            if native and s.alive and (nativeState or nativeKnown==true) then
                self.grab:syncNative(nativeState,clock,s.generation,cfg and cfg.PERFECT or .32,
                    cfg and cfg.PASSES or 2.5,now)
            end
            critical=critical or self.grab.enabled and self.grab.active and self.grab.pending~=nil
            self.timingCritical,bridge.deferNativeDiscovery=critical,critical
            if not s.alive and self.grab.active then self.grab:reset("animal unavailable") end
            s.grab,s.afkWalking = self:hasNativeGrab(now),self.walk ~= nil
            self.grabInput:update(self.grab,now,native,nativeState)
            self:pumpGrab(s,false)
            s.grab=self:hasNativeGrab(now)
            if not self.grab.active and self.grabInput.lease then self.grabInput:release() end
            self:updateGrabWake()
        else
            self.grabClockLostAt=self.grabClockLostAt or now
            local p=self.grab.pending
            if not s.alive or now-self.grabClockLostAt>8 then
                self.grab:reset(not s.alive and "animal unavailable" or "server clock unavailable; session paused")
                self.grabInput:release()
            elseif p and p.localEnds and now>p.localEnds+.1 then
                self.grab.pending=nil;self.grab.status="strike expired while server clock unavailable"
            end
            self:cancelGrabWake()
            s.grab,s.afkWalking = self:hasNativeGrab(now),self.walk ~= nil
        end
        -- Both observed and newly adopted native strikes get their first legal
        -- dispatch before any Territory discovery, routing or driver work.
        if self.territory then self.territory:tick(now) end
        if not critical and now >= self.nextBind then self.nextBind = now+1; bridge:bindNative(self) end
        local care=self.territory and self.territory.agent.enabled and self.territory.agent.goal
        self.feeding:tick(s,now,care and (care.kind=="EAT" or care.kind=="DRINK"))
        self:stepFlightHandoff(s,now)
        self.rescue:tick(s,now)
        self.activity=self.policy:activity(s,now)
        bridge.predictionActive=s.attackHeld or self.combatInput.held~=nil or self.registry.byId.autoBite.requested
        -- InputBegan can remain held even when an executor/virtual M1 reset
        -- momentarily reports IsMouseButtonPressed=false. Recovery must not
        -- re-enter owned Rest in the middle of that human-held attack.
        local repeatActive=self.registry.byId.holdBite.requested
            and (self.combatInput.held~=nil or bridge.holdBinding=="M1" and s.attackHeld==true)
            and s.alive and not s.chat and not s.gameMenu and not self.inputSuspended and not self.policy.manualRest
        if repeatActive then
            self.policy.attackUntil=math.max(self.policy.attackUntil,now+1.1)
            if self.recovery.owned and not self.recovery:release("held bite priority",now) then
                self.combatInput:pause("native Rest exit pending",now)
            end
        end
        local auto=self.registry.byId.autoBite.requested and not (self.territory and self.territory.agent.enabled)
        local clear=auto and bridge:autoAttackTarget(s,self.guide,self.features.combat)
        self.nativeGrabBusy=self:hasNativeGrab(now)
        local grabActive=self.nativeGrabBusy==true
            or self.grabInput.lease~=nil
        local lease=self.grabInput.lease
        -- WolfController.tryBite does not use CAS M1 binding. Its native
        -- handler may run alongside the perfect-press scheduler only for a
        -- known hunter minigame with the original M1 minigame action safely
        -- separated. A prey/captured player and all synthetic M1 fallbacks
        -- continue to have minigame priority.
        local nativeMini=grabActive and self.grab.active and self.grab.role=="hunter"
            and lease~=nil and lease.state and not lease.state.ended
            and not bridge:nativeGrabBound()
            and (bridge.holdBinding=="M1" and s.mouseHeld==true or self.combatInput.held~=nil
                and self.combatInput.held.handoff==true)
            and not s.captured
            and bridge.wolfActions and type(bridge.wolfActions.tryBite)=="function"
        local strike=self.grab.pending
        local nearPress=strike and s.serverNow and math.abs(strike.at-s.serverNow)<.095 or false
        self.combatInput:tick(s,now,{
            repeatHeld=self.registry.byId.holdBite.requested and not self.inputSuspended,
            speedEnabled=self.registry.byId.attackSpeed.requested,
            automatic=auto and not self.inputSuspended,targetValid=clear,
            inputSuspended=self.inputSuspended==true,
            minigameBusy=grabActive,nativeMinigame=nativeMini==true,
            minigamePressNear=nearPress==true,
            uiBlocked=self.ui:contains(bridge.UserInputService:GetMouseLocation()),
            beforeAttempt=function()
                self.policy:input("attack",now)
                local released=self.recovery:release("native cadence input",now)
                self.rescue:cancel();self:stopWalk("native cadence input")
                return released
            end,
        })
        if not critical then self.features:reconcile(s,now) end
        if not critical and now >= self.nextScan then
            self.nextScan = now+((s.combat==true or s.attackHeld or self.combatInput.held~=nil) and .12
                or math.clamp((self.frameInterval or .02)*6,.12,.3))
            local candidates = bridge:candidates(s,self.settings.range)
            if self.features:combatProfileReady() then
                self.guide = bridge:select(s,self.features.originalCombat,self.features.combat,candidates)

            else
                self.guide=nil
                self.policy.combatApproachUntil=0
            end
            self.guideAt=now
            self.ui:syncTracked(bridge.tracked)
        end
        self.hippo:tick(s,now,self.registry.byId.hippoRelease.requested,self.guide,self.features.originalCombat)
        -- Recovery follows observed action ownership, never nearby-player distance.
        self.recovery.enabled = self.registry.byId.recovery.requested or self.territoryRecoveryOwner~=nil
        self.recovery:tick(s,now)
        self:stepClimb(s,now)
        self:stepEscape(s,now)
        if not critical then self:stepCombat(s,now) end
        self.biteReadiness=bridge:biteReadiness(s,now,self.policy)
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
        self.tests:tick(now,critical)
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
        if self.guide and self.snapshot and self.features:combatProfileReady() then
            bridge:refreshGuide(self.snapshot,self.features.originalCombat,self.features.combat,self.guide)
        end
        self.features:paintHippoGait()
        self.endurance:render(self.snapshot,bridge.clock(),self.windowFocused)
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
        self.endurance:setEnabled(self.registry.byId.enduranceMove.requested)
        self.zoom:set(self.registry.byId.zoom.requested)
        -- The earlier stand-alone trial must not apply a second attenuation scale.
        -- Automatically retire it before the integrated owner starts.
        local olderVoice=bridge.env.FERAL_VOICE_HEARING
        if type(olderVoice)=="table" and type(olderVoice.close)=="function" then
            pcall(olderVoice.close,olderVoice)
        end
        self.voice:setEnabled(self.registry.byId.voice.requested)
        if M.amber_runtime then self.territory=M.amber_runtime.start(M,self) end
        self.tests:start()
        self.registry:ack("settings",true,"CLIENT","loaded settings; full reconciliation pending")
        return self
    end
    function h:close()
        if self.closed then return end
        self.active = false
        self.closed = true
        self.physicalM1Input=nil
        self.nativeGrabSession=nil
        self.cleanupErrors = {}
        for _,cleanup in ipairs({
            function() if self.territory then self.territory.close() end end,
            function() self.zoom:close() end,
            function() self.voice:close() end,
            function() self.endurance:close() end,
            function() self:cancelGrabWake() end,
            function() self.recovery:close(bridge.clock()) end,
            function() self.grabInput:close() end,
            function() self.feeding:close(bridge.clock()) end,
            function() self:disarmDesktopHold(bridge.clock());self.combatInput:cancel();self.rescue:cancel() end,
            function() self.hippo:close();bridge.predictionActive=nil end,
            function() self.tests:close() end,
            function() bridge:closeNativeScan() end,
            function() self:stopWalk("shutdown") end,
            function() self:clearFlight() end,
            function() self.features:close() end,
        }) do
            local ok,why = pcall(cleanup)
            if not ok then table.insert(self.cleanupErrors,tostring(why)) end
        end
        local closed,why=pcall(self.scope.close,self.scope)
        if not closed then table.insert(self.cleanupErrors,tostring(why)) end
        for _,scopeError in ipairs(self.scope.errors or {}) do
            table.insert(self.cleanupErrors,tostring(scopeError))
        end
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
    if options.maintenanceOnly and not owned then return nil end
    if owned and options.retainOwned and not options.retainOwned[hex.key] then return nil end
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
    if not state or not finite(state.healthFraction) or state.healthFraction<0 or state.healthFraction>1.05 or state.needsKnown==false then
        return {kind="WAIT",reason="Waiting for valid native health and needs"}
    end
    if state.hungerMax~=nil and (not finite(state.hungerMax) or state.hungerMax<=0)
        or state.thirstMax~=nil and (not finite(state.thirstMax) or state.thirstMax<=0) then
        return {kind="WAIT",reason="Native resource maxima unavailable"}
    end
    local hm=finite(state.hungerMax) and state.hungerMax>0 and state.hungerMax or 100
    local tm=finite(state.thirstMax) and state.thirstMax>0 and state.thirstMax or 100
    local h=finite(state.hunger) and state.hunger/hm or nil
    local t=finite(state.thirst) and state.thirst/tm or nil
    if not h or not t or h<0 or t<0 then return {kind="WAIT",reason="Waiting for both native needs"} end
    -- A merely thirsty animal must not repeatedly defer a starving one. Use
    -- observed depletion margins when both exist, otherwise normalized needs.
    local critical
    if h<.19 and t<.19 then
        local hr=finite(state.hungerReserve) and state.hungerReserve or h
        local tr=finite(state.thirstReserve) and state.thirstReserve or t
        if not (finite(state.hungerReserve) and finite(state.thirstReserve)) then hr,tr=h,t end
        critical=hr<tr and "EAT" or "DRINK"
    elseif t<.19 then critical="DRINK" elseif h<.19 then critical="EAT" end
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
-- Due-job deadlines and sustained maintenance are separate estimates. Include
-- healthy owned hexes in the latter: a full scent bar still creates future work.
-- Unknown decay is never silently replaced by an invented native lifetime.
function Planner.capacity(hexes,state,options)
    options=options or {}
    local jobs,recurring={},{}
    local unknown,owned=0,0
    local refill=finite(state.refillTime) and state.refillTime>0 and state.refillTime or 60
    local horizon=finite(options.horizon) and clamp(options.horizon,120,7200) or 900
    local floor=.35
    local function travel(from,to,purpose)
        local fallback=dist(from,to)/math.max(6,finite(state.travelSpeed) and state.travelSpeed or 24)
        if type(state.travelCost)=="function" then
            local ok,value=pcall(state.travelCost,from,to,purpose)
            if ok and finite(value) and value>=0 then return value end
        end
        return fallback
    end
    for _,hex in ipairs(hexes) do
        if state.pack~=nil and hex.owner==state.pack and not hex.neutral then
            owned+=1
            local item=Planner.objective(hex,state,state.position,options)
            if item and item.deadlineSeconds then table.insert(jobs,item) end
            local rate=hex.decayPerSecond
            if type(hex.key)=="string" and finite(rate) and rate>0 and rate<.1 and finite(hex.hold)
                and hex.center and finite(hex.center.x) and finite(hex.center.z) and #recurring<128 then
                local period=(1-floor)/rate
                local service=refill*(1-floor)
                table.insert(recurring,{key=hex.key,center=hex.center,pay=finite(hex.pay) and clamp(hex.pay,1,20) or 1,
                    period=period,service=service,load=service/period,
                    nextDue=math.max(0,(hex.hold-floor)/rate),
                    travel=travel(state.position,hex.center,"HEX:"..hex.key)})
            else unknown+=1 end
        end
    end
    table.sort(jobs,function(a,b)
        return a.deadlineSeconds==b.deadlineSeconds and a.key<b.key or a.deadlineSeconds<b.deadlineSeconds
    end)
    local elapsed,misses=0,0;local from=state.position
    for _,item in ipairs(jobs) do
        elapsed+=travel(from,item.center,"HEX:"..item.key)+item.serviceSeconds
        if elapsed>item.deadlineSeconds then misses+=1 end
        from=item.center
    end
    -- A bounded nearest-neighbour tour gives a travel allowance. It is an
    -- estimate, not a proof that every live terrain segment is traversable.
    local remaining=table.clone(recurring);from=state.position
    local tour,period,serviceLoad,events=0,math.huge,0,0
    for _,job in ipairs(recurring) do
        period=math.min(period,job.period);serviceLoad+=job.load
        events+=math.max(0,math.floor((horizon-job.nextDue)/job.period)+1)
    end
    while #remaining>0 do
        local index,best=1,math.huge
        for i,job in ipairs(remaining) do
            local cost=(from.x-job.center.x)^2+(from.z-job.center.z)^2
            if cost<best or cost==best and job.key<remaining[index].key then index,best=i,cost end
        end
        local job=table.remove(remaining,index);tour+=travel(from,job.center,"HEX:"..job.key);from=job.center
    end
    if #recurring>1 then tour+=travel(from,state.position,"MAINTENANCE_RETURN") end
    local care=finite(options.careFraction) and clamp(options.careFraction,0,.75) or 0
    local available=1-care
    local load=serviceLoad+(period<math.huge and tour/period or 0)
    local maintenanceState=#recurring==0 and "UNKNOWN" or unknown>0 and "PARTIAL"
        or load>available and "OVERLOADED" or "ESTIMATED_SUSTAINABLE"
    local retain,retained,retainedLoad={},0,0
    -- Act only on proven service overload (even zero travel cannot fit). The
    -- travel estimate alone may defer new acquisitions but does not abandon
    -- existing owned work. Higher-value cheap maintenance remains productive.
    local hardOverload=unknown==0 and serviceLoad>available
    if hardOverload then
        table.sort(recurring,function(a,b)
            local ar=a.pay/math.max(.0001,a.load+a.travel/a.period)
            local br=b.pay/math.max(.0001,b.load+b.travel/b.period)
            return ar==br and a.key<b.key or ar>br
        end)
        for _,job in ipairs(recurring) do
            local marginal=job.load+job.travel/job.period
            if retainedLoad+marginal<=available*.95 or retained==0 then
                retain[job.key]=true;retained+=1;retainedLoad+=marginal
            end
        end
    end
    return {knownDeadlines=#jobs,unknown=unknown,estimatedSeconds=elapsed,predictedLate=misses,
        state=#jobs==0 and "UNKNOWN" or misses>0 and "DEADLINE_PRESSURE" or "DUE_WORK_FEASIBLE",
        scope="due deadlines plus bounded recurring owned-map workload; estimates require live calibration",
        maintenance={state=maintenanceState,owned=owned,known=#recurring,unknown=unknown,horizonSeconds=horizon,
            visits=events,serviceUtilization=serviceLoad,travelUtilization=period<math.huge and tour/period or 0,
            estimatedUtilization=load,availableFraction=available,tourSeconds=tour,
            intervalSeconds=period<math.huge and period or nil,retained=hardOverload and retained or owned,
            retainedFeasible=hardOverload and retainedLoad<=available or not hardOverload},
        maintenanceOnly=unknown==0 and #recurring>0 and load>available,
        retainOwned=hardOverload and retain or nil,
        policy=hardOverload and (retainedLoad<=available and "Retain highest-value estimated maintenance subset; no new claims"
            or "Even best maintenance exceeds capacity; prioritize it without new claims")
            or maintenanceState=="OVERLOADED" and "Preserve owned maintenance before new claims"
            or unknown>0 and "Unknown lifetime remains eligible; no sustainability claim" or "Full observed workload estimated"}
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
        local sameBody=not self.bodyRoot or self.bodyRoot==root
        if active then self.gaits:stop(sameBody and self.lastState or nil,self.lastAt or 0) end
        self:releaseKeys();self.gait="STOP"
        if active and sameBody and hum then pcall(hum.Move,hum,Vector3.zero,false) end
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
        -- ComputeAsync may yield through an animal/goal replacement. Isolate
        -- every cache and collision side effect before the adoption lease is
        -- checked, rather than merely rejecting the eventual waypoint list.
        local worker=table.clone(self)
        worker.operations={rays=0,surfaces=0,paths=0};worker.surfaceCache={}
        worker.overlapAt=nil;worker.overlapParts=nil
        task.spawn(function()
            local started=os.clock()
            local ok,points,reason=pcall(worker.compute,worker,request.origin,root,hum,char,
                table.clone(state or {}),request.goal,self.replans)
            self.pathWall=(self.pathWall or 0)+math.max(0,os.clock()-started)
            self.activeJobs-=1
            for name,count in pairs(worker.operations) do self.operations[name]=(self.operations[name] or 0)+count end
            if self.closed or self.epoch~=epoch or self.pending~=request then return end
            self.pending=nil
            self.lastSafety=worker.lastSafety;self.lastObstacle=worker.lastObstacle
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
        if state.flying or state.climbing or state.underwater then
            self:stop(hum,root,"UNSUPPORTED_NATIVE_ROUTE_MODE");return "BLOCKED"
        end
        local identity=state.navKey or "STATIC"
        local replacedRoot=self.bodyRoot and self.bodyRoot~=root
        local replacedGeneration=self.characterGeneration~=nil and self.characterGeneration~=state.generation
        self.bodyRoot=root
        self.clearance=math.clamp(root.Size.X*.5+.65,2,12)
        self.bodyHeight=math.clamp(root.Size.Y*.8,1,10)
        self.bodyLength=math.clamp(root.Size.Z*.65,2,18)
        self.supportHeight=math.max(2,hum.HipHeight+root.Size.Y*.5)
        self.maxDrop=math.clamp(hum.HipHeight*.75,2,4)
        self.maxStepUp=math.clamp(hum.HipHeight,2,4)
        self.minGroundNormal=math.cos(math.rad(math.clamp(hum.MaxSlopeAngle or 55,20,55)))
        if not self.destination or self.body~=char or self.identity~=identity or replacedRoot or replacedGeneration then
            if replacedRoot or replacedGeneration then
                self.gaits:stop(nil,now);self:releaseKeys()
            end
            self:reset(destination,char,now,identity)
        end
        self.characterGeneration=state.generation
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
        lastResult="No attack",nextAttack=0,blocked=setmetatable({},{__mode="k"}),kills=0}
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
        if self.actorSeen and (self.actor~=s.char or self.generation~=s.generation) then
            self.target,self.pending,self.sample=nil,nil,nil
            self.nextAttack=0;self.nextSelect=nil;self.lastTargetHealth=nil;self.lastTargetMax=nil
            self.blocked=setmetatable({},{__mode="k"})
            self.adapter:stop("Hunt animal generation changed")
        end
        self.actorSeen=true;self.actor=s.char;self.generation=s.generation
        for model,untilAt in pairs(self.blocked) do if now>=untilAt then self.blocked[model]=nil end end
        if self.adapter.attackEvidence then self.inputEvidence=self.adapter:attackEvidence(s) end
        local prey=self.target
        -- A recycled model/Humanoid cannot contribute a death or HP result to
        -- the old prey transaction, even if its last Health happened to be zero.
        if prey and prey.hum and prey.model and type(prey.model.FindFirstChildOfClass)=="function"
            and prey.model:FindFirstChildOfClass("Humanoid")~=prey.hum then
            self.target,self.pending=nil,nil;prey=nil
            self.lastResult="Prey identity changed; resampling native target"
        end
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
            self.lastTargetMax=prey.maxHealth or prey.hum and prey.hum.MaxHealth
            self.lastTargetHum=prey.hum
            self.lastUsefulAt=now;self.blockedSince=nil;self.nextAttack=now
            self.repositionUntil=nil;self.previousThrottle=nil;self.fullSpeed=nil;self.routeRetries=0;self.smoothVelocity=nil
        end
        self.target=prey
        local health=prey.health or prey.hum and prey.hum.Health
        local maximum=prey.maxHealth or prey.hum and prey.hum.MaxHealth
        local continuous=self.lastTargetHum==prey.hum
            and not (finite(maximum) and finite(self.lastTargetMax) and math.abs(maximum-self.lastTargetMax)>.001)
        if not continuous then
            self.pending=nil;self.lastTargetHealth=health;self.missesOnTarget=0
            self.noDamageAt=now;self.lastUsefulAt=now
            self.lastResult="Prey health identity/maximum changed; outcome window reset"
        end
        self.lastTargetHum=prey.hum;self.lastTargetMax=maximum
        if continuous and finite(health) and finite(self.lastTargetHealth) and health<self.lastTargetHealth-.01 then
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
                self.attacks+=1;self.pending={at=now,health=health,maxHealth=maximum,hum=prey.hum,model=prey.model}
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
        self.pending=nil;self.sample=nil;self.nextAttack=0;self.lastTargetHealth=nil
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
    local maximum=kind=="drink" and (s.thirstMax or 100) or (s.hungerMax or 100)
    if not finite(maximum) or maximum<=0 then return "FAILED","Native need maximum unavailable" end
    if value<0 or value>maximum*1.05 then return "FAILED","Native need value outside its maximum" end
    if g.needMaximum and g.needMaximum~=maximum then
        -- A schema/species maximum change is not nutrition gained. Establish a
        -- new same-maximum window and keep watching the actual native session.
        g.baseline=value;m.value=value;m.progressAt=now
    end
    g.needMaximum=maximum
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
        feeds=0,hunts=0,failures=0,nextTick=0,reason="Disabled",generation=0,returns={},version="0.8.0"}
    a.metrics=Ledger and Ledger.new() or nil
    function a:planningOptions(extra)
        local options={blockedUntil=self.cooldown,waitingSince=self.waitingSince,
            maintenanceOnly=self.capacity and self.capacity.maintenanceOnly,retainOwned=self.capacity and self.capacity.retainOwned}
        for key,value in pairs(extra or {}) do options[key]=value end
        return options
    end
    function a:updateCapacity(hexes,state)
        if not self.planner.capacity then return end
        local care,active=0,self.metrics and self.metrics.active or 0
        for phase,seconds in pairs(self.metrics and self.metrics.phases or {}) do
            if phase:find("FOOD",1,true) or phase:find("WATER",1,true) or phase:find("HUNT",1,true)
                or phase=="DRINKING" or phase=="EATING" or phase=="RECOVER" or phase=="FEED_APPROACH" then care+=seconds end
        end
        self.capacity=self.planner.capacity(hexes,state,{blockedUntil=self.cooldown,
            careFraction=active>30 and math.clamp(care/active,0,.75) or 0})
    end
    function a:selectTerritory(state,force)
        local hexes=self.adapter:territories(state)
        local byKey={}
        for _,hex in ipairs(hexes) do
            byKey[hex.key]=hex
            if self.planner.objective(hex,state,state.position,{blockedUntil=self.cooldown}) then self.waitingSince[hex.key]=self.waitingSince[hex.key] or state.now
            else self.waitingSince[hex.key]=nil end
        end
        self:updateCapacity(hexes,state)
        local options=self:planningOptions({recent=self.recent,maxStops=6,
            regionCursor=self.regionCursor,regionDirection=self.regionDirection})
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
        return route,strategy
    end
    function a:log(at,kind,msg)
        table.insert(self.events,{at=math.floor(at*10)/10,kind=kind,msg=msg})
        if kind=="confirmed" or kind=="deferred" or kind=="failed" then self.lastNotice=msg end
        while #self.events>35 do table.remove(self.events,1) end
    end
    function a:setEnabled(on,now)
        local desired=on==true
        if self.enabled==desired then return end
        now=now or self.lastState and self.lastState.now or os.clock()
        local ownedFeed=self.enabled and self.goal and self.goal.meal and self.goal.meal.owned
        self.generation+=1;self.enabled=desired
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
            self.capacity=nil;self.nextCapacityAt=0;self.nextPlanAt=0;self.nextUrgentCheck=0;self.pausedAt=nil
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
        if g and g.meal and g.meal.owned and not g.meal.cancelAt and not g.emergencyStopAt and self.adapter.cancelFeed then
            if self.adapter:cancelFeed(state) then g.meal.cancelAt=state.now end
        end
        if self.adapter.releaseInputs then self.adapter:releaseInputs() end
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
            baseline=kind=="DRINK" and state.thirst or kind=="EAT" and state.hunger or nil,
            needMaximum=kind=="DRINK" and state.thirstMax or kind=="EAT" and state.hungerMax or nil}
        self.phase="PREPARE_"..kind;self.reason="Starting "..kind
        self:log(state.now,"goal",kind..":"..tostring(target and target.key or "-"))
    end
    function a:resume(state)
        self.adapter:stop("care confirmed")
        if self.adapter.recover then self.adapter:recover(state,false) end
        local g=self.suspended;self.suspended=table.remove(self.returns)
        if g and g.kind=="TERRITORY" then
            local current=self.adapter:territory(g.key,state)
            local detail=current and self.planner.objective(current,state,state.position,self:planningOptions())
            if detail then
                if state.travelCost then
                    local route,strategy=self.planner.strategy(self.adapter:territories(state),state,self:planningOptions({regionCursor=self.regionCursor,maxStops=1}))
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
            self.adapter:stop("despawn");if self.adapter.releaseInputs then self.adapter:releaseInputs() end;return
        end
        state.now=now;self.lastState=state;self.species,self.coat=state.species,state.coat
        local changed=self.initialized and (self.lastCharacter~=state.char or self.lastPack~=state.pack
            or self.lastBiome~=state.biome or self.lastSpecies~=state.species or self.lastProfile~=state.profileKey
            or self.lastGeneration~=state.generation)
        if changed then
            self.goal,self.suspended=nil,nil;self.returns={};self.cooldown,self.recent,self.careCooldown={},{},{}
            self.waitingSince={};self.regionCursor=nil;self.regionDirection=nil;self.itinerary=nil
            self.needWindow={};self.needRates={};self.depletionProfiles={}
            self.prevAmber=nil;self.capacity=nil;self.nextCapacityAt=0;self.nextPlanAt=0;self.nextUrgentCheck=0
            if self.adapter.releaseInputs then self.adapter:releaseInputs() end
            if self.adapter.recover then self.adapter:recover(state,false) end
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
            self:updateCapacity(self.adapter:territories(state),state)
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
        if state.combatKnown==false then self:pause(state,"Native combat timing unavailable");return end
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
        if goal and goal.kind=="TERRITORY" and not goal.nativeStarted and self.capacity and self.capacity.maintenanceOnly
            and (goal.detail.kind=="CLAIM" or self.capacity.retainOwned and not self.capacity.retainOwned[goal.key]) then
            self.goal=nil;self.itinerary=nil;goal=nil
            self.adapter:stop("Maintenance workload displaced optional acquisition")
        end
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
                local route,strategy=self.planner.strategy(self.adapter:territories(state),state,
                    self:planningOptions({regionCursor=self.regionCursor,maxStops=1}))
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
                    self.phase="WATCH";self.reason=self.capacity and self.capacity.maintenanceOnly and self.capacity.policy or "Territories maintained or deferred; watching native scent and survival"
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
            if result=="STUCK" or result=="BLOCKED" then
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
            if result=="STUCK" or result=="BLOCKED" or goal.foodArrived and now-goal.foodArrived>2.5 then
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
        configs={},configInstances={},configRevision=0,manualButtons={},waterBlocked={},preyBlocked=setmetatable({},{__mode="k"}),foodBlocked=setmetatable({},{__mode="k"}),
        connections={},inputEpoch=0,territorySamples={},operations={surface=0,food=0,prey=0},synthetic={},generation=0,
        coverage={},coverageOrder={},nativeCosts={}}
    local world=Rep:FindFirstChild("FeralWorld")
    local function config(name)
        local module=world and world:FindFirstChild(name)
        local previous=b.configInstances[name]
        if b.configs[name] and previous==module then return b.configs[name] end
        if previous~=module then b.configRevision+=1 end
        b.configs[name]=nil;b.configInstances[name]=module
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
        for _,key in ipairs({"char","root","profile","pack","biome","territory","world","configRevision"}) do if not self.identity or self.identity[key]~=identity[key] then same=false;break end end
        if same then return end
        self.identity=identity;self.generation+=1
        local char=player.Character
        self.nav:stop(char and char:FindFirstChildOfClass("Humanoid"),char and char:FindFirstChild("HumanoidRootPart"),"GENERATION_CHANGED")
        self.spotCache,self.spotTry,self.territorySamples={},{},{}
        self.waterBlocked={};self.preyBlocked=setmetatable({},{__mode="k"});self.foodBlocked=setmetatable({},{__mode="k"})
        for _,name in ipairs({"waterCache","waterScan","waterMissUntil","waterAt","searchPoint","searchVisits","searchUntil",
            "patrolTarget","patrolVisits","patrolUntil","foodIndex","preyIndex","foodBest","preyBest","lastAttackInput","attackCharacter","foodETA","drinkETA","foodObserved","drinkObserved","observedDamage","nextBite"}) do self[name]=nil end
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
        if currentWorld~=world then world=currentWorld;self.configs={};self.configInstances={};self.configRevision+=1;self.cfg=nil;self.spots=nil;self.lastString=nil;self.hexes={};self.hexByKey={} end
        if self.configInstances.TerritoryConfig or world and world:FindFirstChild("TerritoryConfig") then
            local latest=config("TerritoryConfig")
            if latest~=self.cfg then self.cfg=latest;self.lastString=nil;self.hexes={};self.hexByKey={} end
        end
        if self.configInstances.MapSpots or world and world:FindFirstChild("MapSpots") then self.spots=config("MapSpots") end
        local currentTerritory=Rep:FindFirstChild("FeralTerritory")
        if currentTerritory~=self.territoryInstance then self.territoryInstance=currentTerritory;self.lastString=nil;self.hexes={};self.hexByKey={} end
        if not self.cfg or not self.territoryInstance then
            world=Rep:FindFirstChild("FeralWorld")
            self.cfg=config("TerritoryConfig")
            self.spots=config("MapSpots")
            self.territoryInstance=Rep:FindFirstChild("FeralTerritory")
            if not self.cfg or not self.territoryInstance then return end
        end
        self.spots=self.spots or config("MapSpots")
        local previous=self.territoryContract
        local changed=not previous
        for _,key in ipairs({"parseHexes","hexCenter","hexAt","hexKey","CLAIM_RADIUS","CLAIM_TIME","REFILL_TIME"}) do
            if not previous or previous[key]~=self.cfg[key] then changed=true;break end
        end
        if changed then
            self.territoryContract={}
            for _,key in ipairs({"parseHexes","hexCenter","hexAt","hexKey","CLAIM_RADIUS","CLAIM_TIME","REFILL_TIME"}) do self.territoryContract[key]=self.cfg[key] end
            self.lastString=nil;self.hexes={};self.hexByKey={};self.spotCache={};self.territorySamples={}
            self.configRevision+=1
        end
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
        if not sample or sample.owner~=owner or not finite(sample.hold) or not finite(hold) or now-sample.at>30 then
            sample={owner=owner,hold=hold,prog=prog,at=now};self.territorySamples[key]=sample
        elseif now>sample.at+.2 and finite(hold) and finite(sample.hold) and hold~=sample.hold then
            local dt=now-sample.at;local rate=(sample.hold-hold)/dt
            if rate>0 and rate<.1 then sample.decay=sample.decay and sample.decay*.6+rate*.4 or rate end
            if hold>sample.hold and dt<8 then self.progressLatency=(self.progressLatency or dt)*.7+dt*.3 end
            sample.hold=hold;sample.at=now
        end
        return {key=key,neutral=terrAttr(key,"neutral")==true or self.cfg and self.cfg.ON==false,
            owner=owner,by=by,prog=prog,hold=hold,
            pay=finite(pay) and pay or nil,decayPerSecond=sample.decay,deadlineSeconds=sample.decay and finite(hold) and math.max(0,hold-.08)/sample.decay or nil,
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
    function b:manualInput(nativeDirection)
        -- The PlayerModule supplies physical keyboard/gamepad/touch direction
        -- before the hub replaces it. Preserve it on that very input frame.
        if nativeDirection and type(nativeDirection.Magnitude)=="number" and nativeDirection.Magnitude>.15 then
            self.manualUntil=os.clock()+.6
        end
        if self.manualStick or next(self.manualButtons) then return true end
        if os.clock()<(self.manualUntil or 0) then return true end
        if UserInput:GetFocusedTextBox() then return true end
        if type(UserInput.IsMouseButtonPressed)=="function" and Enum.UserInputType then
            local ok,down=pcall(UserInput.IsMouseButtonPressed,UserInput,Enum.UserInputType.MouseButton1)
            if ok and down and not (self.pendingInputs and self.pendingInputs.M1) then return true end
        end
        for _,name in ipairs({"W","A","S","D","Up","Down","Left","Right","Space","LeftShift","X","Z","E","R","Q"}) do
            local key=Enum.KeyCode[name]
            if key then
                local ok,down=pcall(UserInput.IsKeyDown,UserInput,key)
                if ok and down and not self.nav.held[name=="LeftShift" and "SHIFT" or name] and not (self.pendingInputs and self.pendingInputs[name]) then return true end
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
        if type(cfg.scaled)=="function" and type(known.gait)=="number" and type(known.speed)=="number" then
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
        for _,name in ipairs({"Species","NeedsConfig","Forage","FeedFinder","CombatConfig"}) do config(name) end
        self:resetDiscovery({char=c,root=r,profile=profileKey,pack=attr(player,"FeralPack"),biome=biome,territory=self.territoryInstance,world=world,configRevision=self.configRevision})
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
        local grabBusy=hub and hub.grab and hub.grab.active==true or false
        if hub and type(hub.hasNativeGrab)=="function" then
            local valid,active=pcall(hub.hasNativeGrab,hub,now)
            grabBusy=not valid or active==true
        end
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
        if hub and type(hub.bridge.serverNow)=="function" then
            local valid,value=pcall(hub.bridge.serverNow,hub.bridge)
            if valid and finite(value) then at=value end
        end
        local combatKnown=finite(at) and (untilCombat==nil or finite(untilCombat))
        local combat=combatKnown and (untilCombat or 0)>at
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
            manualInput=self:manualInput(),combat=combat,combatKnown=combatKnown,
            pinned=attr(c,"FeralPinned")==true or attr(c,"FeralDragged")==true or attr(c,"FeralCarried")==true,
            ability=attr(c,"FeralCrushAt")~=nil and attr(c,"FeralCrushAt")~=false or attr(c,"FeralRolling")==true or attr(c,"FeralDowned")==true or attr(c,"FeralVenomDown")==true
                or attr(c,"FeralTalonLock")~=nil and attr(c,"FeralTalonLock")~=false
                or attr(c,"FeralDeathRollLocal")==true or attr(c,"FeralDiveBomb")==true
                or grabBusy,
            rescuing=hub and hub.rescue and hub.rescue.pending~=nil,
            resting=attr(c,"WolfRest")==true,
            automaticRest=hub and hub.recovery and hub.recovery.owned==c and not (hub.policy and hub.policy.manualRest),
            flying=fly,swimming=swimming,
            climbing=attr(c,"FeralClimbLocal")==true,underwater=attr(c,"FeralUnderwater")==true}
    end
    local function currentAction(state)
        return not b.closed and type(state)=="table" and state.alive~=false
            and (not state.char or state.char==player.Character)
            and (not state.generation or state.generation==b.generation)
            and not state.manualInput and not state.menuOpen and not state.gameMenu
    end
    function b:move(destination,state,options)
        if not destination or not currentAction(state) then return "WAIT" end
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
        if not currentAction(state) then return false end
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
        if not state or state.char and state.char~=player.Character or state.generation and state.generation~=self.generation then return false end
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
        prey.health=hum.Health;prey.maxHealth=hum.MaxHealth
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
        if not cfg or not state.root or not state.hum or not prey or not prey.root or not prey.hum then return nil end
        local diff=prey.root.Position-state.root.Position
        local planar=Vector3.new(diff.X,0,diff.Z)
        local function mult(name,default)
            if type(cfg[name])~="function" then return default end
            local ok,value=pcall(cfg[name],state.char)
            return ok and finite(value) and value or default
        end
        local geometry
        if hub and type(hub.bridge.geometry)=="function" then
            local ok,value=pcall(hub.bridge.geometry,hub.bridge,cfg,state,{char=prey.model,root=prey.root,hum=prey.hum})
            if not ok or not value then return nil end
            geometry=value
        else
            -- Standalone compatibility uses the same captured stock formula.
            if type(cfg.bodyGap)~="function" or not finite(cfg.REACH) or not finite(cfg.SLACK)
                or not finite(cfg.HIT_SCALE) or not finite(cfg.MAX_DY) or not finite(cfg.CONE) then return nil end
            local look=state.root.CFrame.LookVector;look=Vector3.new(look.X,0,look.Z)
            if look.Magnitude<.01 then return nil end
            if type(cfg.biteLook)=="function" then
                local ok,value=pcall(cfg.biteLook,state.char,look.Unit)
                if ok and typeof(value)=="Vector3" then look=Vector3.new(value.X,0,value.Z) end
            end
            if look.Magnitude<.01 then return nil end
            local ok,gap=pcall(cfg.bodyGap,prey.root,planar)
            if not ok or not finite(gap) then return nil end
            local box=attr(state.root,"FeralBoxFull")
            if not finite(box) or box<=0 then box=state.root.Size.Z end
            geometry={gap=gap,reach=(box*.5+state.hum.HipHeight*cfg.REACH+cfg.SLACK)*cfg.HIT_SCALE*mult("reachMult",1),
                angle=planar.Magnitude>.01 and look.Unit:Dot(planar.Unit) or 1}
        end
        local reach,gap,angle=geometry.reach,geometry.gap,geometry.angle
        local vertical=geometry.vertical or (state.hum.HipHeight+prey.hum.HipHeight)*cfg.MAX_DY*mult("dyMult",1)
        local cone=geometry.cone or mult("coneFor",cfg.CONE)
        if not finite(reach) or reach<=0 or not finite(gap) or not finite(angle) or not finite(vertical) or vertical<=0 or not finite(cone) then return nil end
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={state.char};params.IgnoreWater=true
        params.RespectCanCollide=true
        local queried,obstruction=pcall(Workspace.Raycast,Workspace,state.root.Position,diff,params)
        local clear=queried and (not obstruction or obstruction.Instance and obstruction.Instance:IsDescendantOf(prey.model)) or false
        local inRange=gap<reach*.92 and math.abs(diff.Y)<vertical*.95
        local facing=angle>math.cos(math.rad(cone))
        return {valid=inRange and facing and clear,inRange=inRange,facing=facing,
            angle=angle,gap=gap,reach=reach,clear=clear,height=math.abs(diff.Y),heightLimit=vertical*.95,
            reason=not inRange and "Outside native bite geometry" or not facing and "Facing away from prey"
                or not clear and "Bite corridor obstructed or unavailable" or "Native attack geometry ready"}
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
        if not currentAction(state) then return false,"Stale animal or manual input owns action" end
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
    local function inputName(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then return "M1" end
        return tostring(input.KeyCode or ""):match("%.([^%.]+)$") or tostring(input.KeyCode or "")
    end
    if UserInput.InputBegan then
        table.insert(b.connections,UserInput.InputBegan:Connect(function(input)
            local name=inputName(input)
            local mapped=name=="LeftShift" and "SHIFT" or name
            local relevant={W=true,A=true,S=true,D=true,Space=true,X=true,Z=true,E=true,R=true,Q=true,M1=true}
            local gamepad=name:sub(1,6)=="Button" or name:sub(1,4)=="DPad"
            if relevant[name] or mapped=="SHIFT" or gamepad then
                local now=os.clock();local at=b.nav.synthetic and b.nav.synthetic[mapped] or b.synthetic[mapped]
                if not (at and now>=at and now-at<.25) and not (b.pendingInputs and b.pendingInputs[mapped]) then
                    b.manualUntil=now+.6
                    if gamepad then b.manualButtons[name]=true end
                    if name=="X" then nav.gaits.burstOwned=false end
                    if name=="Z" then nav.gaits.trotOwned=false end
                end
            end
        end))
    end
    if UserInput.InputEnded then
        table.insert(b.connections,UserInput.InputEnded:Connect(function(input)b.manualButtons[inputName(input)]=nil end))
    end
    if UserInput.InputChanged then
        table.insert(b.connections,UserInput.InputChanged:Connect(function(input)
            if inputName(input)=="Thumbstick1" then
                local pos=input.Position
                b.manualStick=pos and type(pos.Magnitude)=="number" and pos.Magnitude>.15 or false
                if b.manualStick then b.manualUntil=os.clock()+.6 end
            end
        end))
    end
    if UserInput.GamepadDisconnected then
        table.insert(b.connections,UserInput.GamepadDisconnected:Connect(function()
            b.manualButtons={};b.manualStick=false;b.manualUntil=os.clock()+.6
        end))
    end
    function b:close()
        if self.closed then return end
        self.closed=true;self.manualButtons={};self.manualStick=false
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
    local function currentAnimal()
        if not nav.body then return true end
        local char=player.Character
        local root=char and type(char.FindFirstChild)=="function" and char:FindFirstChild("HumanoidRootPart") or nil
        if char==nav.body and (not nav.bodyRoot or root==nav.bodyRoot) then return true end
        if nav.gaits then nav.gaits.burstOwned=false;nav.gaits.trotOwned=false end
        nav:stop(nil,nil,"CHARACTER_CHANGED")
        return false
    end
    function d:attach()
        if self.closed or self.controls and self.controls.moveFunction==self.wrapper then return end
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
        if controls and controls==self.displacedControls then
            self.reason="External owner retained; waiting for a new control module";return
        end
        if not controls then self.reason="No supported native moveFunction; using keys";return end
        local previous=controls.moveFunction
        local binding={original=previous}
        local wrapper=function(p,direction,relative)
            if p==player and not self.closed and nav.desiredPoint and nav.steeringStrategy=="WORLD" and binding.active~=false and currentAnimal() then
                if manual and manual(direction) then
                    nav:stop(nav.desiredHum,nav.desiredRoot,"MANUAL_INPUT")
                else
                    local wanted=nav:direction()
                    if wanted then
                        nav.driveCalls+=1;nav.lastMode="PLAYER_MODULE"
                        return binding.original(p,wanted,false)
                    end
                end
            end
            return binding.original(p,direction,relative)
        end
        local attached,why=pcall(function()controls.moveFunction=wrapper end)
        if not attached then self.reason=tostring(why);return end
        self.controls,self.original,self.wrapper=controls,previous,wrapper;self.binding=binding
        self.method,self.path,self.reason="PLAYER_MODULE",path,"Native callback attached; motion unverified"
        nav.preferredStrategy="WORLD";nav.steeringStrategy="WORLD"
        nav.driverPath=path
    end
    d:attach()
    if not d.controls then nav.preferredStrategy="KEY";nav.steeringStrategy="KEY" end
    function d:tick()
        if self.closed then return end
        currentAnimal()
        if self.controls and self.controls.moveFunction~=self.wrapper then
            self.method="NATIVE_KEYS";nav.preferredStrategy="KEY";nav.steeringStrategy="KEY"
            self.reason="Native callback ownership changed";self.displacedControls=self.controls
            if self.binding then self.binding.active=false end
            if os.clock()>=self.nextProbe then self.nextProbe=os.clock()+5;self:attach() end
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
            gait.Text=tostring(n.requested or "STOP").." requested · "..tostring(n.observed or "UNKNOWN").." observed"
            travel.Text="Travelled "..amount(n.travelled).." studs · Target "..amount(n.distance).." studs"
                ..(n.failure and (n.stalledFor or 0)>1 and " · "..n.failure or "")
            if s.strategy and s.strategy.area then
                progress.Text=s.strategy.area.." · "..tostring(s.strategy.owned or 0).."/"..tostring(s.strategy.total or 0).." owned"
                    ..(type(value)=="number" and (" · Native progress "..amount(value*100).."%") or "")
            end
            local capacity=s.capacity and s.capacity.maintenance
            if capacity and capacity.state=="OVERLOADED" then
                progress.Text=progress.Text.." · Maintenance "..tostring(capacity.retained).."/"..tostring(capacity.owned).." retained (estimate)"
            elseif s.capacity and s.capacity.state=="DEADLINE_PRESSURE" then
                progress.Text=progress.Text.." · Deadline pressure"
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
local Runtime={version="0.8.0"}
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
    local attached,driver=pcall(module("driver").new,bridge.player,nav,function(direction)return bridge:manualInput(direction)end)
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
        if hub.timingCritical then
            -- The core has already pumped the legal minigame window. Avoid
            -- scans/pathfinding/gait requests until that deadline has passed.
            if agent.enabled and not self.deadlinePaused then
                self.deadlinePaused=true
                pcall(agent.pause,agent,{now=now},"Native minigame input has priority")
                pcall(nav.releaseKeys,nav);pcall(bridge.releaseInputs,bridge)
            end
            return
        end
        self.deadlinePaused=nil
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
        if prior.driver and driver.original==prior.driver.wrapper then
            driver.original=prior.driver.original
            if driver.binding then driver.binding.original=prior.driver.original end
        end
    end
    env.FERAL_AMBER_ACTIVE=h;hub.territory=h
    return h
end
return Runtime
]============]
local moduleOrder = {"core","compat","settings","policy","grab","grab_input","recovery","feeding","combat_input","rescue","hippo","features","endurance","roblox","zoom","voice","test_features","ui","controller","amber_ledger","amber_model","amber_planner","amber_gait","amber_nav","amber_hunt","amber_care","amber_agent","amber_bridge","amber_driver","amber_ui","amber_runtime"}
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
    {"endurance","new"},{"zoom","new"},{"voice","new"},{"ui","mount"},{"controller","new"},
    {"hippo","new"},{"test_features","new"},
}) do
    if type(M[pair[1]][pair[2]]) ~= "function" then error("Renaissance interface mismatch",0) end
end
M.core.compat=M.compat
M.release = {version="16.4.1-exp1",territoryVersion="0.8.0",channel="release-candidate",sourceFingerprint="057bcad3410d8c60b7d6658041f637e92feb640fe681d9eaa508b66073e01deb"}
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
local activated, failure = xpcall(function() candidate:activate() end,function(e) return tostring(e) end)
if not activated then
    pcall(candidate.close,candidate)
    error("Renaissance activation failed; candidate cleaned up: " .. tostring(failure),0)
end
candidate.marker = {
    version = candidate.version,
    close = function() candidate:close() end,
    setMenuVisible = function(visible)
        if candidate.ui.visible ~= (visible == true) then candidate.ui:toggle() end
    end,
}
env.FERAL_RENAISSANCE_ACTIVE = candidate
env.FERAL_NOVA_PRIME_ACTIVE = candidate.marker
if not M.compat.known(game.PlaceVersion) then
    print("[FERAL Renaissance "..candidate.version.."] Game build "..tostring(game.PlaceVersion)..
        " has no audited private layouts; interface capabilities remain checked at runtime.")
end
print("[FERAL Renaissance " .. candidate.version .. "] Candidate ready · Right Shift · v2415 compatibility")
return candidate
