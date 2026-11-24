-- Current v2412 FeralGrabV2UI protocol: begin / strike / res / bite / end.
-- Only native issued strikes permit a press; only matching "mine" res grades count.
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
        status = "OFF", rejected = 0, presses = 0, lastAt = 0, sequence = 0 }
    function g:reset(reason)
        self.active, self.pending, self.session = false, nil, nil
        self.seen, self.results = {}, {}
        self.status = reason or "waiting for native session"
        self.sequence += 1
    end
    function g:event(event, data, now, generation, perfect, passes)
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
            self.status = "native session observed"
            return true
        end
        if not self.active or tostring(self.session) ~= sessionKey or self.generation ~= generation then
            self.rejected += 1; return false
        end
        if event == "end" then self:reset("native session ended"); return true end
        if event == "bite" then
            self.pending, self.lastAt = nil, now
            self.status = "native bite pause"
            return true
        end
        if event == "res" then
            local key = tostring(data.k)
            if data.mine ~= true or not self.seen[key] or self.results[key] then
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
        if not id(data.k) or type(data.k) ~= "number" or self.seen[tostring(data.k)] then
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
        local p = { session = session, strike = data.k, generation = generation,
            t0 = data.t0, ends = data.t0+duration, speed = data.spd, from = data.from,
            target = data.zc, half = data.zw*.5*perfect }
        p.at = Grab.crossing(now, p)
        self.pending = p.at and p or nil
        self.lastAt = now
        self.status = p.at and "native strike scheduled; grade unknown" or "no safe crossing"
        return true
    end
    function g:manual()
        self.pending = nil
        self.status = "manual input has priority"
    end
    function g:tick(now, generation, allowed, send)
        if not self.enabled then self:reset("OFF"); return end
        if generation ~= self.generation or not allowed then
            self.pending = nil
            if generation ~= self.generation then self:reset("animal changed") end
            return
        end
        if self.active and now-self.lastAt > 8 then self:reset("native session timeout"); return end
        local p = self.pending
        if not p or now < p.at-.005 then return end
        if now >= p.ends-.01 then self.pending = nil; self.status = "strike expired"; return end
        local error = math.abs(Grab.triangle(now,p.t0,p.speed,p.from)-p.target)
        if error > p.half*.88 then
            if now > p.at+.08 then self.pending = nil; self.status = "missed narrow window; skipped" end
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
