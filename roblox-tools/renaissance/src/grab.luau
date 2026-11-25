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
