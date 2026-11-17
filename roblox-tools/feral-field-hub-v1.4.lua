-- FERAL Field Hub v1.4 | GSVexed/vexed-schematics
-- For PlaceId 108901361810209. Original UI and client experiments.
-- Explicit native earned-reward claims / owned-coat equips; optional self look/list reads.
-- Explicit self-only gift/reward trials, empty-slot spawn attempts, Snow Leopard amber buy, and Rest packets.
-- No forced HP writes, Roblox purchases, save restores, role spoofing or other-account requests.
-- No currency spoofing, decompilation or full scan.
-- Optional client changes are OFF until clicked. They do not grant server ownership.
-- API/compiler checks and offline tests cannot establish Roblox/Velocity compatibility.

-- BEGIN TESTABLE CORE
local Core = {}
function Core.finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end
function Core.number(n, fallback)
    return Core.finite(n) and n or fallback
end
function Core.errorMeta(value)
    local message = type(value) == "string" and value or ""
    local lowered, line = string.lower(message), message:match(":(%d+):")
    local kind = "runtime_error"
    if lowered:find("permission", 1, true) or lowered:find("security", 1, true) then kind = "permission_error"
    elseif lowered:find("readonly", 1, true) or lowered:find("read-only", 1, true) then kind = "readonly_error"
    elseif lowered:find("not a valid member", 1, true) then kind = "missing_member"
    elseif lowered:find("timeout", 1, true) or lowered:find("timed out", 1, true) then kind = "timeout" end
    -- Preserve only fixed categories and a numeric source line, never raw API messages.
    return kind, line and tonumber(line) or nil
end
function Core.patch(target, changes)
    local lease = {target = target, entries = {}, expected = table.clone(changes)}
    for key, wanted in pairs(changes) do
        local readOK, old = pcall(function() return target[key] end)
        if not readOK then
            local failures = Core.restore(lease)
            return nil, "Table read failed; rollback failures: " .. failures .. "."
        end
        if old ~= wanted then
            local ok = pcall(function() target[key] = wanted end)
            if not ok then
                local failures = Core.restore(lease)
                return nil, "Table write failed; rollback failures: " .. failures .. "."
            end
            table.insert(lease.entries, {key = key, old = old, wanted = wanted})
        end
    end
    return lease
end
function Core.restore(lease)
    local failed = 0
    if not lease then return failed end
    for i = #lease.entries, 1, -1 do
        local entry = lease.entries[i]
        local ok = pcall(function()
            -- Preserve changes made by the game or another script after ours.
            if lease.target[entry.key] == entry.wanted then
                lease.target[entry.key] = entry.old
            end
        end)
        if not ok then failed = failed + 1 end
    end
    return failed
end
function Core.hpTarget(health, maximum, dt, perSecond)
    if not (Core.finite(health) and Core.finite(maximum) and Core.finite(dt)
        and Core.finite(perSecond)) then return nil end
    if health <= 0 or maximum <= 0 or health >= maximum or perSecond <= 0 then return nil end
    return math.min(maximum, health + perSecond * math.clamp(dt, 0, 0.25))
end
function Core.bearing(dx, dz, lookX, lookZ)
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance < 0.01 then return 0, "HERE", distance end
    local length = math.sqrt(lookX * lookX + lookZ * lookZ)
    if length < 0.01 then lookX, lookZ, length = 0, -1, 1 end
    lookX, lookZ = lookX / length, lookZ / length
    local forward = dx * lookX + dz * lookZ
    local right = dx * -lookZ + dz * lookX
    local angle = math.deg(math.atan2(right, forward))
    local word = "AHEAD"
    if math.abs(angle) > 150 then word = "BEHIND"
    elseif angle > 30 then word = "RIGHT"
    elseif angle < -30 then word = "LEFT" end
    return angle, word, distance
end
function Core.travelAllowed(plan, character, now, healthy, blocked)
    if not plan then return false, "Scout a landing first." end
    if plan.character ~= character then return false, "Character changed; scout again." end
    if not Core.finite(now) or not Core.finite(plan.at) or now - plan.at < 0 or now - plan.at > 12 then
        return false, "Landing expired; scout again."
    end
    if not healthy then return false, "A living, spawned animal is required." end
    if blocked then return false, "Travel unavailable during combat, carrying, a grab or a fall." end
    return true
end
function Core.supported(sample)
    return sample and sample.measured == true and sample.water == false
        and Core.finite(sample.normalY) and sample.normalY >= math.cos(math.rad(25))
        and Core.finite(sample.supportDelta) and sample.supportDelta <= 1.25
        and sample.clear == true
end
function Core.nodes(root, limit)
    local result, stack = {}, {root}
    while #stack > 0 do
        local item = table.remove(stack)
        result[#result + 1] = item
        if #result > limit then return nil end
        for _, child in ipairs(item:GetChildren()) do
            if #stack + #result >= limit then return nil end
            stack[#stack + 1] = child
        end
    end
    return result
end
function Core.stripClone(root)
    local nodes = Core.nodes(root, 3000)
    if not nodes then return false end
    for _, item in ipairs(nodes) do
        if item:IsA("LuaSourceContainer") or item:IsA("RemoteEvent")
            or item:IsA("RemoteFunction") or item:IsA("BindableEvent")
            or item:IsA("BindableFunction") or item:IsA("ProximityPrompt")
            or item:IsA("ClickDetector") or item:IsA("Sound") then
            item:Destroy()
        elseif item:IsA("BasePart") then
            item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
        end
    end
    return true
end
Core.species = {"Wolf", "Fox", "Deer", "Elk", "Bear", "Cougar", "SnowLeopard", "Eagle", "Vulture", "Falcon", "Tiger", "Otter", "Porcupine", "Bison", "Hippo", "Rhino", "Elephant", "Alligator", "Python", "Komodo", "RedPanda", "Gorilla", "KingCobra", "Phantosuchus"}
Core.coats = {"Default", "Ember", "Midnight", "Arctic", "Smoke", "Prairie", "Timber", "Giant", "River", "White", "Bengal", "Harpy", "Golden", "Bald", "Black", "Florida", "Mountain", "Spirit", "Grizzly", "Silver", "Red", "Albino", "Burmese", "Piebald", "Whitetail", "Desert", "Savanna", "Pink", "King", "Griffon", "Wild"}
function Core.knownSpecies(value)
    if type(value) ~= "string" then return "other" end
    for _, sp in ipairs(Core.species) do if sp == value then return sp end end
    return "other"
end
function Core.clientGate(group, userId, style)
    if type(group) ~= "table" or not Core.finite(userId) or userId <= 0 then return "unavailable" end
    if style == "map" then return group[userId] == true and "matched" or "not_matched" end
    if #group > 128 then return "unavailable" end
    for i = 1, #group do if group[i] == userId then return "matched" end end
    return "not_matched"
end
function Core.ownLookupSummary(value, ownId, kind)
    local result = {state = "unexpected_reply", write_permission = "unverified"}
    if type(value) ~= "table" then return result end
    if value.err then
        local message = type(value.err) == "string" and string.lower(value.err) or ""
        result.state = (message:find("permission", 1, true) or message:find("owner", 1, true)
            or message:find("admin", 1, true) or message:find("unauthor", 1, true))
            and "permission_error_reported" or "lookup_error_reported"
        return result
    end
    local id = (type(value.id) == "string" or type(value.id) == "number") and tonumber(value.id) or nil
    if not Core.finite(id) or id ~= ownId then result.state = "reply_target_not_verified"; return result end
    result.state = "own_lookup_returned"
    if kind == "gift" and type(value.save) == "table" then
        result.own_save_present = true
        if Core.finite(value.save.amber) then result.saved_amber_snapshot = value.save.amber end
    elseif kind == "saves" and type(value.list) == "table" then
        result.saved_version_count = math.min(#value.list, 1000000)
        result.undo_available = value.undoAt ~= nil
    end
    return result
end
function Core.cleanOwnership(payload)
    if type(payload) ~= "table" then return nil end
    local result = {owned_seen = type(payload.owned) == "table", coats_seen = type(payload.coats) == "table", owned = {}, coats = {}}
    if not result.owned_seen and not result.coats_seen then return nil end
    for _, sp in ipairs(Core.species) do
        if result.owned_seen and type(payload.owned[sp]) == "boolean" then result.owned[sp] = payload.owned[sp] end
        local family = result.coats_seen and payload.coats[sp]
        if type(family) == "table" then
            local clean = {}
            for _, coat in ipairs(Core.coats) do if type(family[coat]) == "boolean" then clean[coat] = family[coat] end end
            if next(clean) then result.coats[sp] = clean end
        end
    end
    -- Retain only the active own slot's protocol key, known species and known coat.
    local key = payload.active
    local numeric = (type(key) == "number" or type(key) == "string") and tonumber(key) or nil
    if Core.finite(numeric) and numeric % 1 == 0 and numeric >= 1 and numeric <= 64
        and (type(key) ~= "string" or key:match("^%d+$")) and type(payload.slots) == "table" then
        local slot = payload.slots[key]
        if type(slot) == "table" and Core.knownSpecies(slot.sp) ~= "other" then
            local coat = nil
            for _, id in ipairs(Core.coats) do if slot.coat == id then coat = id end end
            result.active = {key = key, species = slot.sp, coat = coat}
        end
    end
    return result
end
function Core.ring(capacity)
    return {capacity = capacity, items = {}, total = 0, dropped = 0}
end
function Core.push(ring, item)
    ring.total = ring.total + 1
    if #ring.items >= ring.capacity then
        ring.dropped = ring.dropped + 1
        if ring.preserve_first then return false end
        table.remove(ring.items, 1)
    end
    ring.items[#ring.items + 1] = item
    return true
end
function Core.place(x, z)
    if (type(x) ~= "number" and type(x) ~= "string") or (type(z) ~= "number" and type(z) ~= "string") then return nil end
    x, z = tonumber(x), tonumber(z)
    if not Core.finite(x) or not Core.finite(z) or math.abs(x) > 8192 or math.abs(z) > 8192 then return nil end
    return {x = x, z = z}
end
function Core.cleanPlaces(data)
    if type(data) ~= "table" or data.schema ~= "feral-places/1" or type(data.places) ~= "table" then return nil end
    if #data.places > 24 then return nil end
    local keys = 0
    for key in pairs(data.places) do
        keys = keys + 1
        if keys > 24 or type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #data.places then return nil end
    end
    if keys ~= #data.places then return nil end
    local result = {}
    for _, item in ipairs(data.places) do
        if type(item) ~= "table" then return nil end
        local point = Core.place(item.x, item.z)
        if not point then return nil end
        result[#result + 1] = point
    end
    return result
end
function Core.leaseMatches(lease)
    if not lease then return false end
    if lease.expected then
        for key, wanted in pairs(lease.expected) do
            local ok, value = pcall(function() return lease.target[key] end)
            if not ok or value ~= wanted then return false end
        end
        return true
    end
    for _, entry in ipairs(lease.entries) do
        local ok, value = pcall(function() return lease.target[entry.key] end)
        if not ok or value ~= entry.wanted then return false end
    end
    return true
end

function Core.journal(capacity)
    return {capacity = capacity, items = {}, total = 0, dropped = 0, preserve_first = true}
end
function Core.cleanRewards(payload)
    if type(payload) ~= "table" or not Core.finite(payload.pt) or payload.pt < 0
        or payload.pt > 31536000 or type(payload.pc) ~= "table" then return nil end
    local clean = {pt = payload.pt, pc = {}, dailyOn = payload.dailyOn == true}
    for i = 1, 16 do
        local v = payload.pc[i]
        if v == nil or type(v) == "boolean" then clean.pc[i] = v == true end
    end
    if type(payload.claimed) == "boolean" then clean.claimed = payload.claimed end
    if Core.finite(payload.day) and payload.day % 1 == 0 and payload.day >= 1 and payload.day <= 31 then clean.day = payload.day end
    return clean
end
function Core.rewardPlan(data, config, attempted)
    local result = {}
    if not data or type(config) ~= "table" or config.ON ~= true or type(config.PLAYTIME) ~= "table" then return result end
    for i = 1, math.min(#config.PLAYTIME, 16) do
        local tier = config.PLAYTIME[i]
        if type(tier) == "table" and Core.finite(tier.min) and tier.min >= 0 and tier.min <= 1440
            and data.pc[i] == false and data.pt >= tier.min * 60 and not attempted["play/" .. i] then
            result[#result + 1] = {kind = "play", index = i}
        end
    end
    if config.DAILY_ON == true and data.dailyOn and data.claimed == false and data.day
        and type(config.DAILY) == "table" and config.DAILY[data.day] ~= nil and not attempted["daily/" .. data.day] then
        result[#result + 1] = {kind = "daily", index = data.day}
    end
    return result
end
function Core.equipAllowed(data, age, species, coat)
    if not data or not Core.finite(age) or age < 0 or age > 10 then return false, "Refresh your own inventory in the normal animal guide first." end
    if Core.knownSpecies(species) == "other" or not data.active or data.active.species ~= species then
        return false, "Select the same species as your living animal and active save slot."
    end
    local family = data.coats[species]
    if type(family) ~= "table" or family[coat] ~= true then return false, "This coat is not listed owned in your fresh inventory. No purchase or grant submitted." end
    return true
end
function Core.speedPlan(config, multiplier)
    if type(config) ~= "table" or not Core.finite(multiplier) or multiplier < 1 or multiplier > 2
        or not Core.finite(config.RUN_SPEED) or config.RUN_SPEED <= 0 or config.RUN_SPEED > 4
        or not Core.finite(config.SWIM_SPEED) or config.SWIM_SPEED <= 0 or config.SWIM_SPEED > 4 then return nil end
    return {RUN_SPEED = config.RUN_SPEED * multiplier, SWIM_SPEED = config.SWIM_SPEED * multiplier}
end
function Core.leapPlan(config, multiplier)
    if type(config) ~= "table" or config.ON ~= true or type(config.of) ~= "function"
        or type(config.BODY_LENGTHS) ~= "table" or not Core.finite(config.DEFAULT) or config.DEFAULT < 0
        or not Core.finite(config.MAX_RUN_SHARE) or config.MAX_RUN_SHARE <= 0
        or not Core.finite(multiplier) or multiplier < 1 or multiplier > 2 then return nil end
    local changes = {}
    for _, species in ipairs(Core.species) do
        local value = config.BODY_LENGTHS[species]
        if Core.finite(value) and value >= 0 and value <= 10 then changes[species] = value * multiplier end
    end
    if not next(changes) then return nil end
    return changes, {DEFAULT = config.DEFAULT * multiplier, MAX_RUN_SHARE = config.MAX_RUN_SHARE * multiplier}
end
function Core.restAllowed(sample)
    if not sample or not Core.finite(sample.health) or sample.health <= 0 then return false, "Spawn a living animal first." end
    if sample.resting then return false, "The game already reports resting; no toggle sent." end
    if sample.combat or sample.blocked or sample.mode ~= "idle" or (sample.horizontal_speed or 0) > 0.75 then
        return false, "Rest requires an idle animal outside combat, water, flight, grabs and carrying."
    end
    if sample.focused or sample.menu then return false, "Finish typing or close the game menu first." end
    return true
end
function Core.lookupReply(packed, ownId, kind)
    local result
    if not packed[1] then result = {state = "request_failed", write_permission = "unverified"}
    elseif packed.n < 2 then result = {state = "no_values_returned", write_permission = "unverified"}
    elseif packed[2] == nil then result = {state = "nil_returned_no_access_established", write_permission = "unverified"}
    elseif type(packed[2]) == "boolean" then
        result = {state = packed[2] and "true_returned_no_access_established" or "false_returned_no_access_established", write_permission = "unverified"}
    else result = Core.ownLookupSummary(packed[2], ownId, kind) end
    result.return_count, result.return_types = packed[1] and math.max(0, packed.n - 1) or 0, {}
    if packed[1] then
        for i = 2, math.min(packed.n, 5) do
            local t = type(packed[i])
            result.return_types[#result.return_types + 1] = (t == "nil" or t == "boolean" or t == "table" or t == "number" or t == "string") and t or "other"
        end
    end
    return result
end


function Core.goalGift(kind, value)
    if kind == "amber" then
        if type(value) ~= "string" and type(value) ~= "number" then return nil end
        value = tonumber(value)
        if not Core.finite(value) or value % 1 ~= 0 or value < 1 or value > 1000000 then return nil end
        return {kind = kind, value = value}
    end
    if kind == "animal" and (value == "SnowLeopard" or value == "Phantosuchus" or value == "*") then return {kind = kind, value = value} end
    return nil
end
function Core.goalSlots(payload, count)
    if type(payload) ~= "table" or type(payload.slots) ~= "table" or not Core.finite(count)
        or count % 1 ~= 0 or count < 1 or count > 16 then return nil end
    local result = {count = count, slots = {}, empty = {}, active = nil, owned = {}}
    for i = 1, count do
        -- Native chooseTarget indexes numeric keys. Mixed string keys are ambiguous.
        if payload.slots[tostring(i)] ~= nil then return nil end
        local slot = payload.slots[i]
        if slot == nil or slot == false then result.empty[#result.empty + 1] = i
        else result.slots[i] = {occupied = true, species = type(slot) == "table" and Core.knownSpecies(slot.sp) or "other"} end
    end
    if type(payload.active) == "number" and payload.active % 1 == 0 and payload.active >= 1 and payload.active <= count then result.active = payload.active end
    for _, sp in ipairs(Core.species) do
        if type(payload.owned) == "table" and type(payload.owned[sp]) == "boolean" then result.owned[sp] = payload.owned[sp] end
    end
    return result
end
function Core.goalGiftReply(packed)
    if not packed[1] then return {state = "request_failed"} end
    local value = packed[2]
    if type(value) ~= "table" then return {state = value == nil and "nil_reply_unconfirmed" or "non_table_reply_unconfirmed"} end
    if value.err ~= nil then return {state = Core.ownLookupSummary(value, 1, "gift").state} end
    local result = {state = "table_reply_unclassified", acknowledged = false}
    for _, key in ipairs({"here", "test", "pinged"}) do
        if type(value[key]) == "boolean" then result[key], result.acknowledged = value[key], true end
    end
    if result.acknowledged then result.state = "gift_response_reported" end
    return result
end
function Core.goalRates(samples)
    local rates, moving = {}, 0
    for i = 2, #samples do
        local a, b = samples[i - 1], samples[i]
        local dt = b.t - a.t
        if dt >= .5 and dt <= 2.5 and a.health_max == b.health_max and a.health_max > 0
            and a.health < a.health_max - .01 and b.health < b.health_max - .01
            and not a.combat and not b.combat and b.health >= a.health
            and Core.number(a.hunger, 0) >= 25 and Core.number(b.hunger, 0) >= 25
            and Core.number(a.thirst, 0) >= 25 and Core.number(b.thirst, 0) >= 25 then
            local rate = (b.health - a.health) / b.health_max / dt
            if Core.finite(rate) and rate <= .1 then
                rates[#rates + 1] = rate
                if (a.horizontal_speed or 0) >= 2 and (b.horizontal_speed or 0) >= 2 then moving = moving + 1 end
            end
        end
    end
    table.sort(rates)
    local n, median = #rates, nil
    if n > 0 then median = n % 2 == 1 and rates[(n + 1) / 2] or (rates[n / 2] + rates[n / 2 + 1]) / 2 end
    return {valid_pairs = n, moving_pairs = moving, median_max_fraction_per_second = median}
end
function Core.goalRecoveryResult(phases)
    local result = {baseline = Core.goalRates(phases.baseline), signal = Core.goalRates(phases.signal), after = Core.goalRates(phases.after)}
    local b, d, a = result.baseline, result.signal, result.after
    result.state = "insufficient_comparable_intervals"
    if b.valid_pairs >= 3 and d.valid_pairs >= 3 and a.valid_pairs >= 3 then
        if b.moving_pairs < 3 or d.moving_pairs < 3 or a.moving_pairs < 3 then result.state = "movement_comparison_incomplete"
        elseif (b.median_max_fraction_per_second or 0) <= 0 or (a.median_max_fraction_per_second or 0) <= 0 then result.state = "baseline_recovery_not_established"
        elseif d.median_max_fraction_per_second >= math.max(b.median_max_fraction_per_second, a.median_max_fraction_per_second) * 1.5 then
            result.state = "higher_recovery_during_signal_observed_while_moving"
        else result.state = "no_clear_recovery_uplift_observed" end
    end
    result.limit = "Exploratory comparison, not causal proof or invulnerability. Growth, native actions, lag and other effects may confound it."
    return result
end
function Core.goalCopy(value, depth)
    depth = depth or 0
    assert(depth < 20, "Goal export nesting exceeds its schema.")
    local kind = type(value)
    if kind == "table" then
        local result = {}
        for key, item in pairs(value) do
            assert(type(key) == "string" or (type(key) == "number" and Core.finite(key)), "Unsupported goal export key.")
            result[key] = Core.goalCopy(item, depth + 1)
        end
        return result
    end
    assert(kind == "nil" or kind == "string" or kind == "boolean" or (kind == "number" and Core.finite(value)), "Unsupported goal export value.")
    return value
end

-- END TESTABLE CORE

local startupCleanup = nil
local startupPhase = "place_check"
local function run()
    if game.PlaceId ~= 108901361810209 then
        warn("[FERAL Hub] Open FERAL PlaceId 108901361810209 first.")
        return
    end
    local Players = game:GetService("Players")
    startupPhase = "services_and_player_gui"
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local player = Players.LocalPlayer
    if not player then warn("[FERAL Hub] LocalPlayer is unavailable."); return end
    local parent = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 8)
    if not parent then warn("[FERAL Hub] PlayerGui is unavailable."); return end
    local name = "FeralFieldHubV14"
    for _, oldName in ipairs({"FeralFieldHubV10", "FeralFieldHubV11", "FeralFieldHubV12", "FeralFieldHubV13", name}) do
        local previous = parent:FindFirstChild(oldName)
        if previous then
            local shutdown = previous:FindFirstChild("HubShutdown")
            if shutdown and shutdown:IsA("BindableEvent") then shutdown:Fire() end
            if previous.Parent then previous:Destroy() end
        end
    end
    local state = {
        alive = true, born = os.clock(), connections = {}, leases = {}, flags = {},
        stamina = false, healthDrops = 0, staminaDrops = 0, rewardPaidNotices = 0,
        serverReplies = {}, rewardStateSeen = false, rewardObserver = false,
        hidden = false, menus = false, light = nil, errors = 0, samples = {},
        cache = {}, cacheTargets = {}, cacheBusy = {}, cacheWaiters = {}, selectedAsset = nil, selectedSpecies = nil,
        selectedCoat = nil, clone = nil, coatLease = nil, previewEpoch = 0,
        travelEpoch = 0, scoutBusy = false, plan = nil, returnSpot = nil,
        travelWatch = nil, currentPage = "LIVE", moduleJobs = 0,
        target = {name = "Oasis / The spring", x = 1070, z = 1505},
        moduleStatus = "No game modules loaded by the hub.", staminaEpoch = 0, menuEpoch = 0,
    }
    local C = {
        bg = Color3.fromRGB(15, 23, 29), surface = Color3.fromRGB(24, 36, 44),
        line = Color3.fromRGB(47, 67, 77), text = Color3.fromRGB(236, 244, 239),
        muted = Color3.fromRGB(157, 182, 182), green = Color3.fromRGB(38, 143, 112),
        blue = Color3.fromRGB(42, 101, 145), amber = Color3.fromRGB(204, 159, 69),
        red = Color3.fromRGB(162, 67, 79),
    }
    local function new(class, props, owner)
        local item = Instance.new(class)
        for k, v in pairs(props or {}) do item[k] = v end
        if owner then item.Parent = owner end
        return item
    end
    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        state.connections[#state.connections + 1] = connection
        return connection
    end
    local function round(item, radius)
        new("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, item)
        return item
    end
    local function label(owner, content, size, height, color)
        return new("TextLabel", {
            BackgroundTransparency = 1, Text = content, RichText = false,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center, Font = Enum.Font.Gotham,
            TextColor3 = color or C.text, TextSize = size or 13,
            Size = UDim2.new(1, 0, 0, height or 30),
        }, owner)
    end
    local function button(owner, content, color, height)
        return round(new("TextButton", {
            BackgroundColor3 = color or C.blue, BorderSizePixel = 0,
            Text = content, RichText = false, TextWrapped = true,
            Font = Enum.Font.GothamBold, TextColor3 = C.text, TextSize = 12,
            Size = UDim2.new(1, 0, 0, height or 34), AutoButtonColor = true,
        }, owner))
    end
    local function list(owner, padding)
        new("UIListLayout", {Padding = UDim.new(0, padding or 8), SortOrder = Enum.SortOrder.LayoutOrder}, owner)
    end
    local function card(owner, title, body)
        local f = round(new("Frame", {
            BackgroundColor3 = C.surface, BorderSizePixel = 0,
            Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        }, owner))
        new("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}, f)
        list(f, 7)
        local head = label(f, title, 14, 25)
        head.Font = Enum.Font.GothamBold
        if body then
            local text = label(f, body, 12, 0, C.muted)
            text.AutomaticSize = Enum.AutomaticSize.Y
        end
        return f
    end
    startupPhase = "creating_panel"
    local gui = new("ScreenGui", {
        Name = name, ResetOnSpawn = false, DisplayOrder = 850, IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, parent)
    local shutdownEvent = new("BindableEvent", {Name = "HubShutdown"}, gui)
    startupCleanup = function()
        state.alive = false
        for _, connection in ipairs(state.connections) do connection:Disconnect() end
        if gui.Parent then gui:Destroy() end
    end
    local panel = round(new("Frame", {
        Name = "Panel", Size = UDim2.fromOffset(780, 594), Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.bg, BorderSizePixel = 0,
        Active = true,
    }, gui), 12)
    new("UIStroke", {Color = C.line, Thickness = 1}, panel)
    local scale = new("UIScale", {}, panel)
    local title = label(panel, "FERAL  /  FIELD HUB", 18, 28)
    title.Font = Enum.Font.GothamBold
    title.Position, title.Size, title.Active = UDim2.fromOffset(18, 13), UDim2.fromOffset(520, 28), true
    local subtitle = label(panel, "v1.4   AMBER  /  RESTRICTED SPAWNS  /  SERVER REST TRIALS", 10, 22, C.muted)
    subtitle.Position, subtitle.Size = UDim2.fromOffset(18, 40), UDim2.fromOffset(640, 22)
    local hide = button(panel, "_", C.blue)
    hide.Position, hide.Size = UDim2.fromOffset(688, 16), UDim2.fromOffset(32, 30)
    local close = button(panel, "X", C.red)
    close.Position, close.Size = UDim2.fromOffset(731, 16), UDim2.fromOffset(32, 30)
    local reopen = button(gui, "FERAL HUB", C.green)
    reopen.AnchorPoint, reopen.Position, reopen.Size = Vector2.new(1, 1), UDim2.new(1, -18, 1, -22), UDim2.fromOffset(120, 38)
    reopen.Visible = false
    local status = label(panel, "Ready. Nothing is changed until you choose a control.", 11, 30, C.muted)
    status.Position, status.Size = UDim2.fromOffset(18, 554), UDim2.fromOffset(744, 30)
    local function say(message, errorFlag)
        if not state.alive then return end
        status.Text = tostring(message)
        status.TextColor3 = errorFlag and C.amber or C.muted
    end
    local function failure(context, details)
        state.errors = state.errors + 1
        local kind, line = Core.errorMeta(details)
        state.lastError = context .. " / " .. kind .. " / line " .. tostring(line or "unavailable")
        say(state.lastError .. ". The affected action stopped.", true)
    end
    local function action(control, callback)
        connect(control.Activated, function()
            if not state.alive then return end
            local ok, details = pcall(callback)
            if not ok then failure(control.Name ~= "TextButton" and control.Name or "Action", details) end
        end)
    end
    local tabs, pages = {}, {}
    local function page(key, index)
        local tab = button(panel, key, C.surface, 33)
        tab.Size, tab.Position = UDim2.fromOffset(88, 33), UDim2.fromOffset(18 + (index - 1) * 94, 74)
        local f = new("ScrollingFrame", {
            Name = key, BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.fromOffset(18, 120), Size = UDim2.fromOffset(748, 424),
            ScrollBarThickness = 5, ScrollBarImageColor3 = C.green,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y, Visible = index == 1,
        }, panel)
        new("UIPadding", {PaddingRight = UDim.new(0, 9), PaddingBottom = UDim.new(0, 12)}, f)
        list(f, 10)
        pages[key], tabs[key] = f, tab
        action(tab, function()
            state.currentPage = key
            for name1, frame in pairs(pages) do
                frame.Visible = name1 == key
                tabs[name1].BackgroundColor3 = name1 == key and C.green or C.surface
            end
        end)
        return f
    end
    local livePage = page("LIVE", 1)
    local resourcePage = page("RESOURCES", 2)
    local travelPage = page("TRAVEL", 3)
    local animalPage = page("ANIMALS", 4)
    local coatsPage = page("COATS", 5)
    local infoPage = page("FINDINGS", 6)
    local ownerPage = page("ACCESS", 7)
    local reportPage = page("REPORT", 8)
    tabs.LIVE.BackgroundColor3 = C.green
    local function own()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        return char, hum, root
    end
    local function world()
        return ReplicatedStorage:FindFirstChild("FeralWorld")
    end
    local function optional(name1)
        if name1 == "getloadedmodules" and type(getloadedmodules) == "function" then return getloadedmodules end
        if name1 == "setclipboard" and type(setclipboard) == "function" then return setclipboard end
        if name1 == "toclipboard" and type(toclipboard) == "function" then return toclipboard end
        if name1 == "writefile" and type(writefile) == "function" then return writefile end
        if name1 == "readfile" and type(readfile) == "function" then return readfile end
        if type(getgenv) == "function" then
            local ok, env = pcall(getgenv)
            if ok and type(env) == "table" and type(env[name1]) == "function" then return env[name1] end
        end
        return nil
    end
    local function cachedModule(name1, callback, consumer)
        local fw = world()
        local target = fw and fw:FindFirstChild(name1)
        consumer = consumer or "default"
        if state.cache[name1] and state.cacheTargets[name1] == target then callback(state.cache[name1]); return end
        state.cache[name1], state.cacheTargets[name1] = nil, nil
        if state.cacheBusy[name1] then
            -- Separate feature consumers share one job; each keeps only its latest request.
            state.cacheWaiters[name1][consumer] = callback
            say("Still checking " .. name1 .. "; the panel remains usable.")
            return
        end
        local getLoaded = optional("getloadedmodules")
        if not (target and target:IsA("ModuleScript") and getLoaded) then
            say(name1 .. " needs an already-loaded module and getloadedmodules support.", true)
            callback(nil)
            return
        end
        state.cacheBusy[name1] = true
        state.cacheWaiters[name1] = {[consumer] = callback}
        state.moduleJobs = state.moduleJobs + 1
        local started = os.clock()
        say("Checking the already-loaded " .. name1 .. " cache...")
        task.delay(6, function()
            if state.alive and state.cacheBusy[name1] then
                say(name1 .. " cache check is still waiting; no duplicate job will be started.", true)
            end
        end)
        task.spawn(function()
            local ok, value = pcall(function()
                local loaded = getLoaded()
                if type(loaded) ~= "table" then return nil end
                local found, count = false, 0
                for _, module in pairs(loaded) do
                    count = count + 1
                    if module == target then found = true; break end
                    if count > 100000 or not state.alive then return nil end
                    if count % 512 == 0 then task.wait() end
                end
                if not found or not state.alive then return nil end
                -- Never require an unconfirmed/new game module. This target is already loaded.
                return require(target)
            end)
            state.cacheBusy[name1] = nil
            local waiting = state.cacheWaiters[name1]
            state.cacheWaiters[name1] = nil
            if not state.alive then return end
            local currentWorld = world()
            local unchanged = currentWorld and currentWorld:FindFirstChild(name1) == target
            if ok and type(value) == "table" and unchanged then
                state.cache[name1], state.cacheTargets[name1] = value, target
                state.moduleStatus = name1 .. " read from the loaded cache."
                for _, fn in pairs(waiting) do
                    if not state.alive then break end
                    local callOK, details = pcall(fn, value)
                    if not callOK then failure(name1 .. " consumer", details) end
                end
            else
                say("Cannot read " .. name1 .. " from the loaded cache. No new module was started.", true)
                if not ok then
                    local kind, line = Core.errorMeta(value)
                    state.lastError = name1 .. " cache / " .. kind .. " / line " .. tostring(line or "unavailable")
                end
                for _, fn in pairs(waiting) do
                    if not state.alive then break end
                    local callOK, details = pcall(fn, nil)
                    if not callOK then failure(name1 .. " unavailable handler", details) end
                end
            end
            if os.clock() - started > 6 then state.moduleStatus = name1 .. " cache response was delayed." end
        end)
    end

    startupPhase = "creating_live_and_resource_controls"
    local statsCard = card(livePage, "YOUR ANIMAL", "Reads only your current character. The panel remains available in the animal menu and after respawning.")
    local animalStats = label(statsCard, "Waiting for a spawned animal...", 14, 30)
    local hpStats = label(statsCard, "Health: —", 15, 27)
    local staminaStats = label(statsCard, "Stamina: —", 15, 27)
    local needsStats = label(statsCard, "Growth / hunger / thirst: —", 13, 30)
    local movementStats = label(statsCard, "Position / movement: —", 12, 28, C.muted)
    local rateStats = label(statsCard, "Observed changes: waiting for samples.", 11, 29, C.muted)
    local effectsCard = card(livePage, "WHY AM I SLOW OR LOSING RESOURCES?", "Observed attributes and configured effects; no buff, currency or growth is granted by this panel.")
    local effectsText = label(effectsCard, "No character loaded.", 12, 0)
    effectsText.AutomaticSize = Enum.AutomaticSize.Y
    local walletCard = card(livePage, "AMBER & OWNERSHIP", "Changing the displayed wallet does not establish spendable amber. Native reward claims can grant earned rewards when the server accepts them. Animal and coat ownership remain checked by the game.")
    local walletText = label(walletCard, "Visible amber: —", 13, 27)
    local openRewards = button(walletCard, "OPEN NORMAL REWARDS UI (OPTIONAL)")
    local observeReplies = button(walletCard, "OBSERVE NORMAL REWARD / PURCHASE REPLIES", C.surface)
    state.nativeRewardsText = label(walletCard, "No automatic claims or purchases. Open the native rewards UI and use its CLAIM buttons.", 11, 48, C.muted)
    local allowedReplies = {
        FeralRewards = {state = true, paid = true},
        FeralAmber = {gain = true},
        FeralSlots = {sync = true, bought = true, poor = true, coatBought = true, coatPoor = true},
    }
    local observedRemotes = {}
    local function observeNativeReplies()
        local count = 0
        for remoteName, allowed in pairs(allowedReplies) do
            local remote = ReplicatedStorage:FindFirstChild(remoteName)
            if remote and remote:IsA("RemoteEvent") then
                count = count + 1
                if observedRemotes[remoteName] ~= remote then
                    if observedRemotes[remoteName .. "Connection"] then
                        observedRemotes[remoteName .. "Connection"]:Disconnect()
                    end
                    observedRemotes[remoteName] = remote
                    observedRemotes[remoteName .. "Connection"] = connect(remote.OnClientEvent, function(kind, payload, detail)
                        -- Only the extension may copy explicitly allowlisted own-state fields.
                        if not state.alive or type(kind) ~= "string" or not allowed[kind] then return end
                        if state.ext then state.ext.onReply(remoteName, kind, payload, detail) end
                        state.serverReplies[#state.serverReplies + 1] = remoteName .. ":" .. kind
                        while #state.serverReplies > 12 do table.remove(state.serverReplies, 1) end
                        if remoteName == "FeralRewards" and kind == "state" then state.rewardStateSeen = true end
                        if remoteName == "FeralRewards" and kind == "paid" then state.rewardPaidNotices = state.rewardPaidNotices + 1 end
                        if kind == "poor" or kind == "coatPoor" then
                            say("The native purchase returned " .. kind .. ". Its client handler treats this as insufficient amber.", true)
                        end
                    end)
                end
            end
        end
        state.rewardObserver = count > 0
        return count
    end
    action(observeReplies, function()
        local count = observeNativeReplies()
        say("Watching " .. count .. " named native reply channels. Only known event labels are recorded; payloads are omitted.")
    end)
    action(openRewards, function()
        observeNativeReplies()
        -- The recovered FeralRewardsUI listens to this UI request attribute.
        -- Its existing implementation handles eligibility, hello and claim requests.
        local previousRequest = player:GetAttribute("FeralRewardsRequest")
        local request = os.clock()
        if request == previousRequest then request = request + 0.001 end
        player:SetAttribute("FeralRewardsRequest", request)
        say("Native reward UI requested. Use its CLAIM buttons for earned rewards; no automatic claim or payment was sent by the hub.")
    end)
    local evidenceCard = card(livePage, "SMALL STATUS REPORT", "Optional report of this hub's state and your visible resources. No full diagnostic, usernames, account IDs, chat or other players' data.")
    local copyReport = button(evidenceCard, "COPY HUB STATUS")
    local saveReport = button(evidenceCard, "SAVE HUB STATUS .TXT", C.surface)

    local staminaCard = card(resourcePage, "CLIENT STAMINA TUNING", "Targets the cached NeedsConfig used by WolfController, plus its WolfDbgNoStamina character flag. It avoids the old approach of repeatedly changing the HUD Stamina attribute. Reported working on Bear. Tiger v1.2 reports also retained >99% stamina during tuned sprint, burst and swim samples, without exhaustion. Other species/costs remain unverified.")
    local staminaToggle = button(staminaCard, "STAMINA TUNING: OFF", C.blue)
    local staminaDetail = label(staminaCard, "Off. No stamina fields or flags changed.", 12, 45, C.muted)
    local hpCard = card(resourcePage, "HEALTH — MONITOR ONLY", "The local HP trial failed in your test and is removed. Later ordinary game recovery does not prove hub healing. REST controls below request the native game action; they do not add a new healing rate or prevent damage.")
    local hpDetail = label(hpCard, "No health-writing loop or regeneration toggle in this version.", 12, 34, C.muted)
    local visualCard = card(resourcePage, "LOCAL VISIBILITY", "A small colour-correction effect for your screen. It does not reveal unreplicated objects or change the server's weather.")
    local lightToggle = button(visualCard, "BRIGHTER VIEW: OFF", C.blue)
    local stopAll = button(resourcePage, "STOP EXPERIMENTS & RESTORE LOCAL SETTINGS", C.red, 39)

    local function releaseFlag(char)
        local lease = state.flags[char]
        if not lease then return end
        local ok = pcall(function()
            if lease.changed and char:GetAttribute("WolfDbgNoStamina") == true then
                char:SetAttribute("WolfDbgNoStamina", lease.old)
            end
        end)
        if not ok then state.errors = state.errors + 1 end
        state.flags[char] = nil
    end
    local function flagCharacter(char)
        if not char or state.flags[char] then return end
        local old = char:GetAttribute("WolfDbgNoStamina")
        state.flags[char] = {old = old, changed = old ~= true}
        if old ~= true then char:SetAttribute("WolfDbgNoStamina", true) end
    end
    local function stopStamina()
        state.stamina, state.staminaEpoch = false, state.staminaEpoch + 1
        local failed = Core.restore(state.leases.stamina)
        state.leases.stamina = nil
        for char in pairs(state.flags) do releaseFlag(char) end
        staminaToggle.Text, staminaToggle.BackgroundColor3 = "STAMINA TUNING: OFF", C.blue
        staminaDetail.Text = failed == 0 and "Off. Owned settings restored; later external changes preserved."
            or "Off. Some setting restorations failed; rejoin to reset the client module cache."
        state.errors = state.errors + failed
    end
    local function startStamina()
        state.stamina, state.staminaEpoch = true, state.staminaEpoch + 1
        local epoch = state.staminaEpoch
        flagCharacter(player.Character)
        staminaToggle.Text, staminaToggle.BackgroundColor3 = "STAMINA TUNING: ON — BEAR / TIGER EVIDENCE", C.green
        staminaDetail.Text = "Character flag active. Checking the loaded controller configuration..."
        cachedModule("NeedsConfig", function(config)
            if not state.alive or not state.stamina or state.staminaEpoch ~= epoch then return end
            if not config then staminaDetail.Text = "Flag only. Cached tuning unavailable; sprint coverage is unverified."; return end
            local changes = {
                STAMINA_SPRINT_DRAIN = 0, STAMINA_JUMP_COST = 0,
                STAMINA_REGEN = 250, STAMINA_REGEN_DELAY = 0, STAMINA_LOW_NEEDS = 1,
            }
            for key in pairs(changes) do
                if not Core.finite(config[key]) then
                    staminaDetail.Text = "Flag only. Cached configuration does not match the expected numeric fields."
                    return
                end
            end
            local lease, reason = Core.patch(config, changes)
            state.leases.stamina = lease
            staminaDetail.Text = lease and "Cached client drain/regen fields tuned; character flag active. Judge actual movement, not just the bar."
                or ("Flag only. " .. reason)
        end)
    end
    action(staminaToggle, function()
        if state.stamina then stopStamina() else startStamina() end
    end)
    local function stopLight()
        if state.light then pcall(function() state.light:Destroy() end); state.light = nil end
        lightToggle.Text, lightToggle.BackgroundColor3 = "BRIGHTER VIEW: OFF", C.blue
    end
    action(lightToggle, function()
        if state.light then stopLight(); return end
        state.light = new("ColorCorrectionEffect", {
            Name = "FeralHubLocalLight", Brightness = 0.12, Contrast = -0.07, Saturation = 0.02,
        }, game:GetService("Lighting"))
        lightToggle.Text, lightToggle.BackgroundColor3 = "BRIGHTER VIEW: ON", C.green
    end)

    startupPhase = "creating_travel_controls"
    local navCard = card(travelPage, "OASIS / THE SPRING — NORMAL POI", "A normal POI at X 1070, Z 1505. No special protection or healing is established. Compass guidance works without moving your character.")
    local destinationLabel = label(navCard, "Destination: Oasis / The spring", 14, 30)
    local navText = label(navCard, "Spawn an animal to see distance and direction.", 14, 39)
    local scoutButton = button(navCard, "1  /  SCOUT A LANDING — NO MOVEMENT")
    local travelButton = button(navCard, "2  /  MOVE ONCE TO CHECKED LANDING (EXPERIMENTAL)", C.red, 40)
    local travelText = label(navCard, "No landing checked. Travel never starts automatically.", 12, 58, C.muted)
    local returnButton = button(navCard, "SCOUT RETURN TO LAST DEPARTURE", C.surface)
    local mapCard = card(travelPage, "DESTINATIONS", "Landing checks use streamed geometry, slope, water, body clearance and ground support. They cannot establish absence of enemies, hazards, future map changes or server correction.")
    local spots = {
        {name = "Oasis / The spring", x = 1070, z = 1505},
        {name = "Canyon arch", x = 818, z = 1432},
        {name = "Canyon mouth", x = 835, z = 1225},
        {name = "Golden Waterhole", x = -240, z = 220},
        {name = "Eagle Rock", x = 711, z = -105},
        {name = "Great Falls", x = 15, z = -504},
        {name = "Frost Lake", x = 30, z = -990},
        {name = "Beaver Ponds", x = -546, z = 60},
        {name = "Pine Woods", x = -1140, z = 180},
        {name = "Lunar Crest", x = -600, z = -1050},
        {name = "Goat Cliffs", x = 1215, z = -855},
        {name = "Black Ravine", x = 165, z = 1620},
        {name = "Juniper Fields", x = 932, z = -642},
        {name = "Granite Basin", x = -961, z = -632},
        {name = "Elder Giants", x = -1182, z = 583},
        {name = "Golden Plains", x = 717, z = 882},
        {name = "Elk Crossing", x = -6, z = 606},
        {name = "Alder Creek", x = -885, z = 1044},
        {name = "Rattlebone Mesa", x = 1158, z = 621},
        {name = "Red Canyon", x = 839, z = 1535},
        {name = "Tall Marsh", x = -826, z = 1996},
        {name = "Mudlands", x = 860, z = 2110},
        {name = "Dead Lagoon", x = 180, z = 2142},
    }
    local function setTarget(spot)
        state.target, state.plan, state.travelEpoch = spot, nil, state.travelEpoch + 1
        destinationLabel.Text = "Destination: " .. spot.name
        travelText.Text = "Destination changed. Scout a new landing before moving."
    end
    for _, spot in ipairs(spots) do
        local b = button(mapCard, spot.name .. "  /  " .. spot.x .. ", " .. spot.z, C.surface, 31)
        action(b, function() setTarget(spot) end)
    end
    action(returnButton, function()
        if not state.returnSpot then say("No departure saved yet.", true); return end
        setTarget({name = "Last departure", x = state.returnSpot.X, z = state.returnSpot.Z})
        say("Return destination selected. Scout it before moving.")
    end)
    local function blocked(char, root)
        local combatUntil = Core.number(player:GetAttribute("FeralCombatUntil"), 0)
        if combatUntil > workspace:GetServerTimeNow() then return true end
        for _, key in ipairs({"FeralPinned", "FeralBurrowed", "FeralVenomDown", "CarriedBy", "FeralDragged", "FeralRider", "FeralLatching"}) do
            local value = char:GetAttribute(key)
            if value ~= nil and value ~= false and value ~= 0 and value ~= "" then return true end
        end
        return root.AssemblyLinearVelocity.Magnitude > 8
    end
    local function landingAt(char, x, z)
        local boxCF, size = char:GetBoundingBox()
        if size.X > 100 or size.Y > 100 or size.Z > 160 then return nil end
        local ray = RaycastParams.new()
        ray.FilterType, ray.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {char}
        ray.IgnoreWater = false
        -- Failure to support collision-respecting queries stops the landing check.
        ray.RespectCanCollide = true
        local hit = workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -4000, 0), ray)
        if not hit then return nil end
        if hit.Material == Enum.Material.Water or hit.Normal.Y < math.cos(math.rad(25)) then return nil end
        local ancestor = hit.Instance:FindFirstAncestorOfClass("Model")
        if ancestor and ancestor:FindFirstChildOfClass("Humanoid") then return nil end
        local center = Vector3.new(x, hit.Position.Y + size.Y / 2 + 0.85, z)
        local destinationBox = CFrame.new(center) * boxCF.Rotation
        if workspace:Raycast(Vector3.new(x, hit.Position.Y + 0.4, z), Vector3.new(0, size.Y + 1, 0), ray) then
            return nil
        end
        local maximumDelta = 0
        for _, sign in ipairs({Vector2.new(-1, -1), Vector2.new(-1, 1), Vector2.new(1, -1), Vector2.new(1, 1)}) do
            local localPoint = Vector3.new(sign.X * size.X * 0.45, -size.Y / 2, sign.Y * size.Z * 0.45)
            local supportPoint = destinationBox:PointToWorldSpace(localPoint)
            local support = workspace:Raycast(supportPoint + Vector3.new(0, 3, 0), Vector3.new(0, -7, 0), ray)
            if not support or support.Material == Enum.Material.Water
                or support.Normal.Y < math.cos(math.rad(25)) then return nil end
            maximumDelta = math.max(maximumDelta, math.abs(support.Position.Y - hit.Position.Y))
        end
        local overlap = OverlapParams.new()
        overlap.FilterType, overlap.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {char}
        overlap.RespectCanCollide, overlap.MaxParts = true, 32
        local colliders = workspace:GetPartBoundsInBox(destinationBox, size + Vector3.new(1, 0.3, 1), overlap)
        local sample = {measured = true, water = false, normalY = hit.Normal.Y,
            supportDelta = maximumDelta, clear = #colliders == 0}
        if not Core.supported(sample) then return nil end
        return {pivot = destinationBox * boxCF:ToObjectSpace(char:GetPivot()), x = x, z = z,
            floorY = hit.Position.Y, size = size, position = center}
    end
    action(scoutButton, function()
        if state.scoutBusy then say("A scout is already running; wait for its result."); return end
        local char, hum, root = own()
        if not (char and hum and root and hum.Health > 0 and type(char:GetAttribute("Species")) == "string") then
            say("Spawn an animal before scouting.", true); return
        end
        state.scoutBusy, state.plan, state.travelEpoch = true, nil, state.travelEpoch + 1
        local epoch, target = state.travelEpoch, state.target
        travelText.Text = "Requesting nearby scenery (up to 5 seconds), then checking loaded geometry..."
        task.spawn(function()
            local ok, result = pcall(function()
                pcall(function() player:RequestStreamAroundAsync(Vector3.new(target.x, root.Position.Y, target.z), 5) end)
                if not state.alive or epoch ~= state.travelEpoch or player.Character ~= char then return nil end
                local offsets = {Vector2.new(0, 0)}
                for _, radius in ipairs({8, 16, 28}) do
                    for i = 0, 7 do
                        local angle = math.pi * i / 4
                        offsets[#offsets + 1] = Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius)
                    end
                end
                for i, offset in ipairs(offsets) do
                    if not state.alive or epoch ~= state.travelEpoch or player.Character ~= char then return nil end
                    local candidate = landingAt(char, target.x + offset.X, target.z + offset.Y)
                    if candidate then return candidate end
                    if i % 4 == 0 then task.wait() end
                end
                return nil
            end)
            state.scoutBusy = false
            if not state.alive or epoch ~= state.travelEpoch then return end
            if ok and result then
                result.character, result.at, result.target = char, os.clock(), target
                state.plan = result
                travelText.Text = string.format("Landing checked at %.0f, %.1f, %.0f. Valid for 12 seconds. Movement remains experimental; this is not a protected area.", result.x, result.floorY, result.z)
                say("Landing ready. Moving is a separate button and rechecks the destination.")
            else
                state.plan = nil
                travelText.Text = "No suitable landing established in loaded geometry. No movement performed. Try again when closer."
                if not ok then failure("Landing check", result) end
            end
        end)
    end)
    action(travelButton, function()
        local char, hum, root = own()
        local plan = state.plan
        local healthy = char and hum and root and hum.Health > 0 and char:GetAttribute("FeralDead") ~= true
        local permitted, reason = Core.travelAllowed(plan, char, os.clock(), healthy, healthy and blocked(char, root))
        if not permitted then say(reason, true); return end
        local current = landingAt(char, plan.x, plan.z)
        state.plan = nil
        if not current or math.abs(current.floorY - plan.floorY) > 1 then
            travelText.Text = "Destination changed or could not be revalidated. No movement performed."; return
        end
        state.returnSpot = root.Position
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
        char:PivotTo(current.pivot)
        state.travelWatch = {character = char, at = os.clock(), position = current.position, health = hum.Health}
        travelText.Text = "One local movement attempted. Monitoring position and health for 4 seconds; server acceptance and safety are unverified."
        say("Departure saved. No automatic movement retries.")
    end)

    startupPhase = "creating_animal_studio"
    local animalsCard = card(animalPage, "ANIMAL STUDIO", "Browse all locally replicated portrait assets, including available restricted-animal assets. These are script-stripped local clones; a preview is not a playable spawn or ownership unlock.")
    local assetSearch = new("TextBox", {
        Text = "", PlaceholderText = "Search portraits — tiger, snow, phanto, baby...",
        ClearTextOnFocus = false, BackgroundColor3 = C.bg, TextColor3 = C.text,
        PlaceholderColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 13,
        Size = UDim2.new(1, 0, 0, 33), BorderSizePixel = 0,
    }, animalsCard)
    round(assetSearch)
    local refreshAssets = button(animalsCard, "REFRESH PORTRAITS", C.surface, 29)
    local assetCount = label(animalsCard, "No portrait scan run yet.", 11, 25, C.muted)
    local stage = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 270)}, animalsCard)
    local assetList = new("ScrollingFrame", {
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Size = UDim2.new(0.34, -7, 1, 0),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
    }, stage)
    list(assetList, 4)
    local viewport = new("ViewportFrame", {
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Position = UDim2.new(0.34, 3, 0, 0),
        Size = UDim2.new(0.66, -3, 1, 0), Ambient = Color3.fromRGB(180, 180, 180),
        LightColor = Color3.fromRGB(255, 240, 210), LightDirection = Vector3.new(-1, -1, -1),
    }, stage)
    round(viewport)
    local previewWorld = new("WorldModel", {Name = "HubPreviewWorld"}, viewport)
    local previewCamera = new("Camera", {FieldOfView = 32}, viewport)
    viewport.CurrentCamera = previewCamera
    local previewText = label(animalsCard, "Select a portrait. No gameplay spawn request will be sent.", 12, 43, C.muted)
    local rotateButton = button(animalsCard, "ROTATE PREVIEW", C.surface, 29)
    local menuToggle = button(animalsCard, "NATIVE MENU CARD VISIBILITY: OFF", C.blue, 36)
    local menuText = label(animalsCard, "Optional cached HIDE_LOCKED flag only. Owner/tester and server checks remain unchanged; reopen the native menu to refresh it.", 11, 45, C.muted)
    local orbit, assets = 0.75, {}
    local speciesNames = {"Phantosuchus", "SnowLeopard", "KingCobra", "Porcupine", "Elephant", "Alligator", "RedPanda", "Gorilla", "Vulture", "Falcon", "Cougar", "Python", "Komodo", "Tiger", "Hippo", "Rhino", "Bison", "Otter", "Bear", "Wolf", "Fox", "Elk", "Eagle"}
    local function speciesOf(assetName)
        local lowered = string.lower(assetName)
        if lowered:match("^doe") or lowered:match("^buck") then return "Deer" end
        if lowered:match("^eaglet") then return "Eagle" end
        for _, species in ipairs(speciesNames) do
            if lowered:sub(1, #species) == string.lower(species) then return species end
        end
        return nil
    end
    local function aimPreview()
        if not state.clone then return end
        local cf, size
        if state.clone:IsA("Model") then cf, size = state.clone:GetBoundingBox()
        elseif state.clone:IsA("BasePart") then cf, size = state.clone.CFrame, state.clone.Size
        else return end
        local aspect = math.max(viewport.AbsoluteSize.X, 1) / math.max(viewport.AbsoluteSize.Y, 1)
        local extent = math.max(size.Y, size.X / math.max(aspect, 0.3), size.Z)
        local distance = extent / (2 * math.tan(math.rad(previewCamera.FieldOfView / 2))) + size.Magnitude * 0.2
        previewCamera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(math.sin(orbit), 0.22, math.cos(orbit)).Unit * distance, cf.Position)
    end
    local function clonePortrait(asset)
        if not Core.nodes(asset, 3000) then say("Portrait exceeds the 3,000-node preview budget.", true); return end
        local clone = asset:Clone()
        if not clone then say("Portrait cannot be cloned.", true); return end
        if not Core.stripClone(clone) then clone:Destroy(); say("Portrait exceeded the clone budget.", true); return end
        if state.clone then state.clone:Destroy() end
        if clone:IsA("Model") then clone:PivotTo(CFrame.new())
        elseif clone:IsA("BasePart") then clone.CFrame = CFrame.new() end
        -- Scripts and interactive objects were removed BEFORE parenting.
        clone.Parent, state.clone = previewWorld, clone
        state.selectedAsset, state.selectedSpecies = asset, speciesOf(asset.Name)
        state.selectedCoat = nil
        local restriction = state.selectedSpecies == "Phantosuchus" and "OWNER ONLY"
            or state.selectedSpecies == "SnowLeopard" and "TESTERS ONLY" or "Gameplay access not checked"
        previewText.Text = asset.Name .. "  /  " .. restriction .. "  /  LOCAL PREVIEW"
        aimPreview()
        return true
    end
    local assetConnections = {}
    local function clearAssetButtons()
        for _, connection in ipairs(assetConnections) do connection:Disconnect() end
        table.clear(assetConnections)
        for _, child in ipairs(assetList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    end
    local function renderAssets()
        clearAssetButtons()
        local needle, count = string.lower(assetSearch.Text):sub(1, 80), 0
        for _, asset in ipairs(assets) do
            if string.find(string.lower(asset.Name), needle, 1, true) then
                count = count + 1
                if count <= 256 then
                    local b = button(assetList, asset.Name, C.surface, 28)
                    assetConnections[#assetConnections + 1] = b.Activated:Connect(function()
                        if state.alive then
                            local ok, details = pcall(clonePortrait, asset)
                            if not ok then failure("Portrait preview", details) end
                        end
                    end)
                end
            end
        end
        assetCount.Text = string.format("%d replicated portrait assets / %d matches%s", #assets, count,
            count > 256 and " / first 256 displayed; refine search" or "")
    end
    local function refreshPortraits()
        assets = {}
        local fw = world()
        local folder = fw and fw:FindFirstChild("Portraits")
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                if item:IsA("Model") or item:IsA("BasePart") then assets[#assets + 1] = item end
            end
        end
        table.sort(assets, function(a, b) return a.Name < b.Name end)
        renderAssets()
        if #assets == 0 then say("No replicated portrait assets found. Try refresh after the game menu loads.", true) end
    end
    action(refreshAssets, refreshPortraits)
    connect(assetSearch:GetPropertyChangedSignal("Text"), renderAssets)
    action(rotateButton, function() orbit = orbit + math.pi / 4; aimPreview() end)
    connect(viewport:GetPropertyChangedSignal("AbsoluteSize"), function() pcall(aimPreview) end)
    local function stopMenuPatch()
        state.menus, state.menuEpoch = false, state.menuEpoch + 1
        state.errors = state.errors + Core.restore(state.leases.menu)
        state.leases.menu = nil
        menuToggle.Text, menuToggle.BackgroundColor3 = "NATIVE MENU CARD VISIBILITY: OFF", C.blue
    end
    action(menuToggle, function()
        if state.menus then stopMenuPatch(); return end
        state.menus, state.menuEpoch = true, state.menuEpoch + 1
        local epoch = state.menuEpoch
        menuToggle.Text = "CHECKING LOADED ACCESS CONFIG..."
        cachedModule("AccessConfig", function(config)
            if not state.alive or not state.menus or state.menuEpoch ~= epoch then return end
            if not config or type(config.HIDE_LOCKED) ~= "boolean" then stopMenuPatch(); return end
            local lease = Core.patch(config, {HIDE_LOCKED = false})
            if not lease then stopMenuPatch(); return end
            state.leases.menu = lease
            menuToggle.Text, menuToggle.BackgroundColor3 = "HIDDEN CARDS VISIBLE — ACCESS UNCHANGED", C.green
            menuText.Text = "Reopen the native animal menu. Phantosuchus remains owner-only; Snow Leopard remains tester-only. No unlock or spawn has been established."
        end)
    end)

    startupPhase = "creating_coat_studio"
    local coatCard = card(coatsPage, "COAT STUDIO", "Read coat definitions from the already-loaded CoatConfig. Choose an animal portrait first, then load its coats. Local appearance trials do not grant ownership, paid passes or other players' visibility.")
    local loadCoats = button(coatCard, "LOAD COATS FOR SELECTED PORTRAIT")
    local coatInfo = label(coatCard, "Select a portrait in ANIMALS first.", 12, 43, C.muted)
    local coatList = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, coatCard)
    list(coatList, 5)
    local wearButton = button(coatCard, "TRY SELECTED COAT LOCALLY ON MY MATCHING ANIMAL", C.blue, 39)
    local resetCoat = button(coatCard, "RESTORE MY LOCAL COAT", C.surface)
    local coatConnections = {}
    local function clearCoats()
        for _, connection in ipairs(coatConnections) do connection:Disconnect() end
        table.clear(coatConnections)
        for _, child in ipairs(coatList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    end
    local function resetLocalCoat()
        local lease = state.coatLease
        state.coatLease = nil
        if not lease then return end
        local ok = pcall(function()
            if lease.applied and lease.applied.Parent == lease.part then lease.applied:Destroy() end
            if lease.original and lease.original.Parent == lease.stash and lease.part.Parent
                and not lease.part:FindFirstChildOfClass("SurfaceAppearance") then
                lease.original.Parent = lease.part
            end
            Core.restore(lease.textureLease)
            if lease.stash then lease.stash:Destroy() end
        end)
        if not ok then state.errors = state.errors + 1 end
    end
    local function meshOf(root)
        local nodes = Core.nodes(root, 3000)
        if not nodes then return nil end
        local fallback = nil
        for _, part in ipairs(nodes) do
            if part:IsA("MeshPart") then
                if part:FindFirstChildOfClass("SurfaceAppearance") then return part end
                fallback = fallback or part
            end
        end
        return fallback
    end
    local function appearanceFor(sp, coat, assetName)
        local fw = world()
        local coats = fw and fw:FindFirstChild("Coats")
        local family = coats and coats:FindFirstChild(sp)
        local folder = family and family:FindFirstChild(coat.id)
        local template = folder and folder:FindFirstChild(assetName)
        if not template then
            local config = state.cache.CoatConfig
            local alias = config and config.TEMPLATE_ALIAS and config.TEMPLATE_ALIAS[assetName]
            template = alias and folder and folder:FindFirstChild(alias)
        end
        if template and template:IsA("SurfaceAppearance") then return template end
        return nil
    end
    local function paintLocal(root, sp, coat, assetName, personal)
        local mesh = meshOf(root)
        if not mesh then return false, "No suitable mesh." end
        local original = mesh:FindFirstChildOfClass("SurfaceAppearance")
        local template = appearanceFor(sp, coat, assetName)
        local texture = type(coat.textures) == "table" and coat.textures[assetName]
        if original and (template or type(coat.recolor) == "string") then
            local replacement = (template or original):Clone()
            if not replacement or not Core.stripClone(replacement) then
                if replacement then replacement:Destroy() end
                return false, "Appearance clone failed."
            end
            replacement:SetAttribute("FeralRecolor", coat.recolor)
            replacement:SetAttribute("FeralCoat", coat.id)
            local stash = new("Folder", {Name = "HubCoatBackup"}, gui)
            local lease = {part = mesh, original = original, applied = replacement, stash = stash}
            -- Install the cleanup record before changing either parent.
            if personal then
                state.coatLease = lease
            end
            local committed = pcall(function()
                original.Parent = stash
                replacement.Parent = mesh
            end)
            if not committed then
                if replacement.Parent then replacement:Destroy() end
                if original.Parent == stash then original.Parent = mesh end
                stash:Destroy()
                if personal then state.coatLease = nil end
                return false, "Appearance swap failed and restoration was attempted."
            end
            if not personal then stash:Destroy() end
            return true, coat.recolor and "Local recolor metadata applied; renderer support is unverified." or "Local surface appearance applied."
        elseif type(texture) == "string" and #texture < 200 then
            local lease = Core.patch(mesh, {TextureID = texture})
            if not lease then return false, "Texture property is not writable." end
            if personal then state.coatLease = {part = mesh, textureLease = lease} end
            return true, "Local texture applied."
        end
        return false, "No compatible replicated texture or surface for this model; no tint substituted."
    end
    action(loadCoats, function()
        local sp, asset = state.selectedSpecies, state.selectedAsset
        if not sp or not asset then say("Select an animal portrait first.", true); return end
        clearCoats()
        state.selectedCoat = nil
        cachedModule("CoatConfig", function(config)
            if not state.alive or state.selectedAsset ~= asset then return end
            local definitions = config and type(config.LIST) == "table" and config.LIST[sp]
            if type(definitions) ~= "table" then coatInfo.Text = "No coat definitions available for " .. sp .. "."; return end
            local count = 0
            for _, coat in ipairs(definitions) do
                if type(coat) == "table" and type(coat.id) == "string" and count < 100 then
                    count = count + 1
                    local b = button(coatList, tostring(coat.name or coat.id) .. "  /  " .. coat.id .. "  /  preview", C.surface, 30)
                    coatConnections[#coatConnections + 1] = b.Activated:Connect(function()
                        if not state.alive then return end
                        local ok, details = pcall(function()
                            if not clonePortrait(asset) then return end
                            state.selectedCoat = {species = sp, definition = coat, asset = asset}
                            local applied, reason = paintLocal(state.clone, sp, coat, asset.Name, false)
                            coatInfo.Text = sp .. " / " .. tostring(coat.name or coat.id) .. ": " .. reason
                            if not applied then say(reason, true) end
                        end)
                        if not ok then failure("Coat preview", details) end
                    end)
                end
            end
            coatInfo.Text = sp .. ": showing " .. count .. " of " .. #definitions
                .. " coat entries" .. (#definitions > 100 and " (100-entry UI limit)" or "")
                .. ". Select one; view it in ANIMALS. Ownership is unchanged."
        end)
    end)
    action(wearButton, function()
        local selected = state.selectedCoat
        local char, hum = own()
        if not selected or not char or not hum or hum.Health <= 0 then say("Select a coat and spawn a matching animal first.", true); return end
        if char:GetAttribute("Species") ~= selected.species then say("The selected coat belongs to a different species.", true); return end
        resetLocalCoat()
        local assetName = char:GetAttribute("Template") or char:GetAttribute("Model")
        if type(assetName) ~= "string" then
            local mesh = meshOf(char)
            assetName = mesh and mesh.Name or selected.asset.Name
        end
        local applied, reason = paintLocal(char, selected.species, selected.definition, assetName, true)
        coatInfo.Text = reason .. " Ownership and other players' views are unchanged or unverified."
        say(applied and "Local coat trial applied. RESTORE and closing the hub undo owned appearance changes." or reason, not applied)
    end)
    action(resetCoat, function() resetLocalCoat(); say("Owned local coat changes restored where still applicable.") end)

    startupPhase = "creating_findings_and_cleanup"
    local discoveries = {
        {"Stamina ownership", "CLIENT LOGIC", "WolfController maintains a private stamina accumulator and publishes attributes. Attribute-only refills can be overwritten by that same client, so snapback alone does not establish server rejection."},
        {"Health authority", "UNRESOLVED", "Client snapshots do not contain the server health writer. A visible local health increase is not proof of accepted healing."},
        {"Grab timing", "CLIENT LOGIC", "One Space-based tug handler ignores intervals below 0.1s. Another struggle uses direction prompts with a 0.15s minimum gap. Space spam is not a universal escape method."},
        {"Restricted animals", "CONFIG + MENU", "Phantosuchus is owner-only; Snow Leopard is tester-only. HIDE_LOCKED controls visibility. OFF was empty in the captured AccessConfig. Local cards do not establish spawn permission."},
        {"Oasis POI", "CONFIG LOCATION + USER OBSERVATION", "AdminConfig labels this POI Hidden oasis / The spring at X1070 Z1505. The user has already visited it normally. The label does not establish a secret, protected or healing area."},
        {"Rest and status recovery", "CONFIG + UI", "Injury, bleeding and venom have separate effects and configured 4x rest recovery. Ordinary health rest regeneration is configured separately."},
        {"Thriving", "CONFIG + UI", "A growth boost configured at +50%, with a 600-second cap. Hunting, eating, drinking and quests are named ways to build it. The server grant rules were not collected."},
        {"Regrowth", "CONFIG + UI", "A configured 2x regrowth bonus, capped at five minutes. The HUD tracks FeralRegrowLeft and FeralRegrowTotal. Eligibility and server grants were not verified."},
        {"Home turf and grazing", "CONFIG + UI", "Home turf specifies +10% damage and 5 amber per held hex per five minutes. Grazing specifies +20% damage and 10 amber per minute. Stacking is unverified."},
        {"Survival bonus", "CONFIG + UI", "Multiplier starts at x1, adds 0.1 per ten minutes until x2, then per fifteen minutes until x3. The client display accounts for an idle state; server payout was not tested."},
        {"Climbing levels", "CONFIG + CLIENT", "Climbing levels distinguish draining, cost-free and faster/regenerating movement. Cougar, Snow Leopard, Red Panda and Gorilla are in the grade-3 map; Tiger was absent from that particular map."},
        {"Vulture Death Sense", "CONFIG + CLIENT", "Configured for targets below 40% HP within 260 studs, including through-wall outlines. It is an existing Vulture mechanic, not enabled for all animals by this hub."},
        {"Baby carrying", "CONFIG", "Carrier growth >=0.67, target growth <0.34, same species and additional conditions. Same-pack status affects a spawn-safety check rather than being universally required."},
        {"Fox burrows", "CONFIG + CLIENT", "Multiple holes, digging materials, underground movement and a 15-second configured oxygen budget. Burrowing is not unlimited protection."},
        {"Diving", "CONFIG + CLIENT", "Air budget scales with growth. Separate no-drown fields do not establish unlimited underwater movement for every species."},
        {"Bird combat", "CONFIG + CLIENT", "Talon locking, spinning struggles and crashes have dedicated systems. Falcon dive-bomb text links impact speed with damage and a temporary knockout."},
        {"Cobra variants", "CONFIG + CLIENT", "Spit, throw and hiss event branches exist. KingsStrike also contains VARIANTS=false. Which variants the live server permits is unverified."},
        {"Anti-teaming", "CONFIG", "GANG is configured on with DMG=0.6 and a WEAKER BITES warning. Its notification is disabled. Actual server application was not observed."},
        {"Scavenger birds", "CONFIG + CLIENT", "Carcass state and food position drive client crow effects. Visual scavengers are separate from a proof of server food rules."},
        {"Weather and water", "CONFIG + CLIENT", "Drought lists drying ponds and a winter exclusion. Flood configuration includes areas and fish settings; reconstructed tables have fidelity limitations."},
        {"Littermates", "DISABLED CONFIG", "LitterConfig.ENABLED=false. Onboarding text refers to a version-specific littermate system. This is not proof of an upcoming release."},
        {"Disabled quest templates", "DISABLED CONFIG", "Some amber, fawn-hunt, timed-survival and daily-rest templates are disabled. Related mechanics and quick-rest quests are not all disabled."},
        {"Other hidden switches", "CONFIG", "NPC territory claiming is disabled in one branch. A Bison update banner is off. Recolor UI is hidden, although coats are enabled. These switches do not grant server features."},
        {"Coat variants", "CONFIG + ASSETS", "Black Panther, Florida Panther, Spirit Bear, Harpy Eagle and albino variants are coat entries. Local texture trials do not establish paid ownership."},
        {"Voices and cinematics", "CONFIG + CLIENT", "Calls use growth-dependent pitch. A staged growth film has newborn, teen, adult and elder scenes; some reconstructed film configuration is damaged."},
        {"Developer gifts", "CONFIG + CLIENT", "A developer-only gift interface handles amber/revives. Finding its client interface does not grant permission or prove gifts can be forged."},
    }
    discoveries[#discoveries + 1] = {"Whole client corpus", "COVERAGE", "339 logical game exports / 221 distinct text bodies indexed: 59 configs, 107 client controllers/UI, 25 shared logic/visual modules and 30 data bodies. Literal API surfaces were indexed; this does not prove every reconstructed branch correct. Server source is absent."}
    discoveries[#discoveries + 1] = {"Unlock debug hook", "STUDIO EFFECT ONLY", "FeralMenu's FeralDbgUnlock listener is inside IsStudio() and calls unlockFx(). It is not an unlock-all protocol."}
    discoveries[#discoveries + 1] = {"Shop price debug hook", "DISPLAY ONLY", "FeralDbgShopPrice alters locally displayed product pricing. It does not change Roblox charges or establish a cheap purchase."}
    discoveries[#discoveries + 1] = {"Local movement controls", "CLIENT INPUTS", "WolfController reads RUN_SPEED and SWIM_SPEED. JumpLeapConfig provides body-length distance and a run-speed cap. v1.4 exposes bounded profiles and restores its own cached changes; actual movement needs an in-game test."}
    discoveries[#discoveries + 1] = {"Native Rest action", "NOT EXTRA HEALING", "FeralRestTap toggles the same controller rest state as R. The helper waits for safe idle conditions and a game acknowledgment; it never writes Health or promises protection."}
    discoveries[#discoveries + 1] = {"Cinematic lifecycle", "SERVER COORDINATION", "Film and growth cinematics listen for FeralCine/FeralCineMode and report beats, streaming focus and completion. Forcing those fields can interfere with the lifecycle; this hub does not simulate a completed life or accepted growth."}
    discoveries[#discoveries + 1] = {"Comfort settings", "NATIVE CLIENT", "The game exposes FeralSet_shake, FeralSet_sway and FeralSet_perf. v1.4 has reversible calm-camera/performance controls using those existing client settings."}
    local findingsSearch = new("TextBox", {
        Text = "", PlaceholderText = "Search findings — stamina, growth, hidden, cobra...",
        ClearTextOnFocus = false, BackgroundColor3 = C.surface, TextColor3 = C.text,
        PlaceholderColor3 = C.muted, Font = Enum.Font.Gotham, TextSize = 13,
        Size = UDim2.new(1, -4, 0, 34), BorderSizePixel = 0,
    }, infoPage)
    round(findingsSearch)
    local findingCards = {}
    for _, entry in ipairs(discoveries) do
        local f = card(infoPage, entry[1] .. "  /  " .. entry[2], entry[3])
        findingCards[#findingCards + 1] = {frame = f, text = string.lower(table.concat(entry, " "))}
    end
    connect(findingsSearch:GetPropertyChangedSignal("Text"), function()
        local needle = string.lower(findingsSearch.Text):sub(1, 100)
        for _, entry in ipairs(findingCards) do entry.frame.Visible = string.find(entry.text, needle, 1, true) ~= nil end
    end)

    do
        local ext = {
            events = Core.journal(6000), places = {}, placeConnections = {}, healthConnections = {},
            movement = {}, lastPoll = -math.huge, mobility = false, mobilityEpoch = 0,
            healthBinding = nil, ownership = nil, ownershipAt = nil, lastWallet = nil,
            lastGain = nil, gainDropPairs = 0, fieldSaved = nil,
        }
        local ui = {}
        ext.session = tostring(os.time()) .. "_" .. tostring(math.floor(os.clock() * 1000000))
        ext.part, ext.partStarted, ext.checkpoints, ext.lastCheckpoint = 1, 0, false, os.clock()
        state.ext = ext
        ext.emit = function(kind, values)
            local t = math.max(0, os.clock() - state.born)
            if not Core.push(ext.events, {t = t, kind = kind, values = values}) and not ext.firstOmitted then ext.firstOmitted = t end
        end
        ext.stopMobility = function()
            ext.mobility, ext.mobilityEpoch = false, ext.mobilityEpoch + 1
            state.errors = state.errors + Core.restore(ext.mobilityInjury) + Core.restore(ext.mobilityNeeds)
            ext.mobilityInjury, ext.mobilityNeeds = nil, nil
            if ui.mobilityToggle then
                ui.mobilityToggle.Text, ui.mobilityToggle.BackgroundColor3 = "LOW-HP / INJURY MOVEMENT: OFF", C.blue
                ui.mobilityText.Text = "Off. Owned movement settings restored where still applicable."
            end
        end
        ext.stop = function()
            ext.stopMobility()
            ext.ownerReadEpoch = (ext.ownerReadEpoch or 0) + 1
            if ext.ownerUILeases then
                for _, lease in ipairs(ext.ownerUILeases) do state.errors = state.errors + Core.restore(lease) end
                ext.ownerUILeases = {}
            end
        end
        ext.detach = function()
            for _, connection in ipairs(ext.healthConnections) do connection:Disconnect() end
            for _, connection in ipairs(ext.placeConnections) do connection:Disconnect() end
            table.clear(ext.healthConnections)
            table.clear(ext.placeConnections)
        end
        ext.onReply = function() end
        ext.tick = function() end
        ext.summary = function()
            return "events " .. #ext.events.items .. "/" .. ext.events.total .. "; dropped " .. ext.events.dropped
        end
        ui.staminaWatch = card(resourcePage, "STAMINA RELIABILITY", "Reads the active cached fields and character flag. Repair is a separate action; external changes are not silently overwritten.")
        ui.tuningState = label(ui.staminaWatch, "Tuning status: off.", 12, 36, C.muted)
        ui.repair = button(ui.staminaWatch, "REAPPLY STAMINA TUNING", C.surface)
        action(ui.repair, function()
            stopStamina()
            startStamina()
            ext.emit("stamina_reapply", {})
        end)
        ui.mobility = card(resourcePage, "MOVEMENT EXPERIMENT — NOT HEALING", "The recovered WolfController reads HURT_SLOW and INJURY.SLOW_PER_POINT when calculating movement. This experiment sets those cached inputs to zero. It does not clear injuries, prevent damage or grant growth/damage bonuses. Actual movement effect is untested.")
        ui.mobilityToggle = button(ui.mobility, "LOW-HP / INJURY MOVEMENT: OFF")
        ui.mobilityText = label(ui.mobility, "Off. Both module inputs must validate before changing either.", 12, 46, C.muted)
        action(ui.mobilityToggle, function()
            if ext.mobility then ext.stopMobility(); return end
            ext.mobility, ext.mobilityEpoch = true, ext.mobilityEpoch + 1
            local epoch = ext.mobilityEpoch
            ui.mobilityToggle.Text = "CHECKING MOVEMENT INPUTS..."
            cachedModule("NeedsConfig", function(needs)
                if not state.alive or not ext.mobility or epoch ~= ext.mobilityEpoch then return end
                if not needs or not Core.finite(needs.HURT_SLOW) then
                    ext.stopMobility(); ui.mobilityText.Text = "NeedsConfig.HURT_SLOW unavailable; no movement tuning applied."; return
                end
                cachedModule("StatusConfig", function(statusConfig)
                    if not state.alive or not ext.mobility or epoch ~= ext.mobilityEpoch then return end
                    local injury = statusConfig and statusConfig.INJURY
                    if type(injury) ~= "table" or not Core.finite(injury.SLOW_PER_POINT) then
                        ext.stopMobility(); ui.mobilityText.Text = "Injury movement input unavailable; no movement tuning applied."; return
                    end
                    local first, reason = Core.patch(needs, {HURT_SLOW = 0})
                    if not first then ext.stopMobility(); ui.mobilityText.Text = reason; return end
                    local second, secondReason = Core.patch(injury, {SLOW_PER_POINT = 0})
                    if not second then
                        state.errors = state.errors + Core.restore(first)
                        ext.stopMobility(); ui.mobilityText.Text = secondReason; return
                    end
                    ext.mobilityNeeds, ext.mobilityInjury = first, second
                    ui.mobilityToggle.Text, ui.mobilityToggle.BackgroundColor3 = "MOVEMENT INPUTS TUNED — UNTESTED", C.green
                    ui.mobilityText.Text = "Local slowdown inputs changed. Injury/health remain real game values; observe actual movement."
                    ext.emit("mobility_inputs_applied", {})
                end)
            end, "mobility")
        end)
        ui.field = card(reportPage, "FOCUSED FIELD EVIDENCE", "Preserves up to 6000 events without evicting the beginning. Optional 60-second checkpoints; save and continue as numbered parts for longer sessions. No decompilation. Ordinary game healing is not hub-added regeneration.")
        ui.fieldState = label(ui.field, "Waiting for a character.", 12, 50, C.muted)
        ui.ownState = label(ui.field, "Own inventory sync has not been observed. Open the normal animal guide to refresh it.", 12, 58, C.muted)
        ui.openAnimals = button(ui.field, "OPEN NORMAL ANIMAL GUIDE", C.surface)
        action(ui.openAnimals, function()
            observeNativeReplies()
            local old = player:GetAttribute("FeralGuideRequest")
            local value = os.clock()
            if old == value then value = value + 0.001 end
            player:SetAttribute("FeralGuideRequest", value)
            say("Native animal guide requested. No animal selection, purchase or slot replacement was sent.")
        end)
        ext.context = function(char, hum, root)
            local result = {species = Core.knownSpecies(char and char:GetAttribute("Species")),
                generation = ext.generation or 0, stamina_tuning = state.stamina, movement_tuning = ext.mobility,
                speed_multiplier = ext.speedMultiplier or 1, leap_multiplier = ext.leapMultiplier or 1,
                cached_stamina_inputs_match = Core.leaseMatches(state.leases.stamina),
                character_stamina_flag = char ~= nil and char:GetAttribute("WolfDbgNoStamina") == true}
            local fields = {health = hum and hum.Health, health_max = hum and hum.MaxHealth,
                stamina = char and char:GetAttribute("Stamina"), stamina_max = char and char:GetAttribute("StaminaMax"),
                growth = char and char:GetAttribute("Growth"), hunger = char and char:GetAttribute("Hunger"),
                thirst = char and char:GetAttribute("Thirst"), injury = char and char:GetAttribute("FeralInjury"),
                bleed = char and char:GetAttribute("FeralBleed"), venom = char and char:GetAttribute("FeralVenomAmt")}
            for key, value in pairs(fields) do if Core.finite(value) then result[key] = value end end
            result.resting = char ~= nil and char:GetAttribute("WolfRest") == true
            result.combat = Core.number(player:GetAttribute("FeralCombatUntil"), 0) > workspace:GetServerTimeNow()
            local mode = "idle"
            if char then
                if char:GetAttribute("FeralPinned") or char:GetAttribute("CarriedBy") then mode = "grab"
                elseif char:GetAttribute("FeralFlyLocal") then mode = "flight"
                elseif char:GetAttribute("FeralClimbLocal") then mode = "climb"
                elseif char:GetAttribute("FeralSwimLocal") or char:GetAttribute("FeralUnderwater") then mode = "swim"
                elseif char:GetAttribute("FeralBurrowed") then mode = "burrow"
                elseif player:GetAttribute("HudBurst") then mode = "burst"
                elseif player:GetAttribute("HudSprint") then mode = "sprint"
                elseif hum and hum.MoveDirection and hum.MoveDirection.Magnitude > 0.1 then mode = "move" end
            end
            result.mode = mode
            if root then
                local v = root.AssemblyLinearVelocity
                result.horizontal_speed = math.sqrt(v.X * v.X + v.Z * v.Z)
                result.x, result.y, result.z = root.Position.X, root.Position.Y, root.Position.Z
            end
            return result
        end
        ext.observeHealth = function(char, hum, kind)
            if not state.alive or player.Character ~= char then return end
            local health, maximum = hum.Health, hum.MaxHealth
            if not Core.finite(health) or not Core.finite(maximum) then return end
            if ext.lastHealth == health and ext.lastMaximum == maximum then return end
            local values = ext.context(char, hum, char:FindFirstChild("HumanoidRootPart"))
            values.delta = ext.lastHealth and health - ext.lastHealth or 0
            values.maximum_delta = ext.lastMaximum and maximum - ext.lastMaximum or 0
            if values.delta > 0 then
                ext.lastGain = {at = os.clock(), amount = values.delta, generation = ext.generation}
            elseif values.delta < 0 and ext.lastGain and ext.lastGain.generation == ext.generation
                and os.clock() - ext.lastGain.at <= 1 then
                ext.gainDropPairs = ext.gainDropPairs + 1
                values.gain_followed_by_drop = true
                values.drop_context = values.combat and "combat_active" or values.maximum_delta ~= 0 and "maximum_changed" or "unidentified"
                -- A timing correlation, not attribution to the server or a particular script.
                ext.lastGain = nil
            end
            ext.lastHealth, ext.lastMaximum = health, maximum
            ext.emit(kind, values)
        end
        ext.clearHealth = function()
            for _, connection in ipairs(ext.healthConnections) do connection:Disconnect() end
            table.clear(ext.healthConnections)
        end
        ext.bindHealth = function(char, hum)
            if ext.char == char and ext.healthBinding == hum then return end
            ext.clearHealth()
            ext.char, ext.healthBinding = char, hum
            ext.lastHealth, ext.lastMaximum, ext.lastGain = nil, nil, nil
            ext.generation = (ext.generation or 0) + 1
            ext.emit("own_character_changed", {generation = ext.generation,
                species = Core.knownSpecies(char and char:GetAttribute("Species"))})
            if not char or not hum then return end
            for _, property in ipairs({"Health", "MaxHealth"}) do
                local ok, connection = pcall(function()
                    return hum:GetPropertyChangedSignal(property):Connect(function()
                        local readOK, details = pcall(ext.observeHealth, char, hum, "health_property_update")
                        if not readOK then failure("Own health observer", details) end
                    end)
                end)
                if ok then ext.healthConnections[#ext.healthConnections + 1] = connection end
            end
            ext.observeHealth(char, hum, "health_baseline")
        end
        ext.onReply = function(remoteName, kind, payload)
            if remoteName == "FeralSlots" and kind == "sync" then
                local clean = Core.cleanOwnership(payload)
                if clean then
                    ext.ownership, ext.ownershipAt, ext.ownershipCharacter = clean, os.clock(), player.Character
                    ext.emit("own_inventory_sync_filtered", {owned_table_seen = clean.owned_seen, coats_table_seen = clean.coats_seen})
                end
            elseif remoteName == "FeralRewards" and kind == "paid" then
                ext.emit("native_reward_paid_notice", {})
            elseif remoteName == "FeralSlots" and (kind == "poor" or kind == "coatPoor" or kind == "bought" or kind == "coatBought") then
                ext.emit("native_purchase_reply", {label = kind})
            end
        end
        ext.tick = function(char, hum, root, now)
            ext.bindHealth(char, hum)
            if char and hum then ext.observeHealth(char, hum, "health_poll_update") end
            if now - ext.lastPoll < 1 then return end
            ext.lastPoll = now
            local sample = ext.context(char, hum, root)
            ext.emit("own_sample", sample)
            local key = sample.species .. "/" .. sample.mode .. (state.stamina and "/stamina_on" or "/stamina_off")
                .. (ext.mobility and "/movement_on" or "/movement_off") .. "/speed_" .. tostring(ext.speedMultiplier or 1)
            local bucket = ext.movement[key] or {samples = 0, exhausted_samples = 0, minimum_fraction = nil, peak_speed = 0}
            bucket.samples = bucket.samples + 1
            if Core.finite(sample.stamina) and Core.finite(sample.stamina_max) and sample.stamina_max > 0 then
                local fraction = sample.stamina / sample.stamina_max
                bucket.minimum_fraction = math.min(bucket.minimum_fraction or fraction, fraction)
            end
            if char and char:GetAttribute("StaminaOut") == true then bucket.exhausted_samples = bucket.exhausted_samples + 1 end
            bucket.peak_speed = math.max(bucket.peak_speed, sample.horizontal_speed or 0)
            ext.movement[key] = bucket
            local tuning = "off"
            if state.stamina then
                if not state.leases.stamina then tuning = "waiting / flag only"
                elseif world() and state.cacheTargets.NeedsConfig ~= world():FindFirstChild("NeedsConfig") then tuning = "module instance changed; repair available"
                elseif not Core.leaseMatches(state.leases.stamina) then tuning = "cached fields changed; repair available"
                elseif char and char:GetAttribute("WolfDbgNoStamina") ~= true then tuning = "character flag changed; repair available"
                else tuning = "cached fields and character flag match" end
            end
            ui.tuningState.Text = "Tuning status: " .. tuning .. ". Observed modes and stamina minima are included in the field report."
            if ext.mobility and ext.mobilityNeeds and (not Core.leaseMatches(ext.mobilityNeeds)
                or not Core.leaseMatches(ext.mobilityInjury)) then
                ui.mobilityText.Text = "Movement inputs changed externally. Turn this experiment off/on to reapply; no automatic forcing."
            end
            ui.fieldState.Text = string.format("Stored %d of %d events / %d later events omitted. First events preserved. Gain/drop pairs %d; combat/growth context is recorded.",
                #ext.events.items, ext.events.total, ext.events.dropped, ext.gainDropPairs)
            if ext.ownership then
                local function owned(sp)
                    local value = ext.ownership.owned[sp]
                    return value == true and "listed owned" or value == false and "listed not owned" or "not reported"
                end
                ui.ownState.Text = string.format("Filtered own sync %.0fs old: Snow Leopard %s; Phantosuchus %s. Ownership alone does not establish owner/tester permission.",
                    now - ext.ownershipAt, owned("SnowLeopard"), owned("Phantosuchus"))
            end
            local wallet = player:GetAttribute("Amber")
            if Core.finite(wallet) and wallet ~= ext.lastWallet then
                ext.emit("visible_wallet_change", {value = wallet, delta = ext.lastWallet and wallet - ext.lastWallet or 0})
                ext.lastWallet = wallet
            end
            if state.coatLease and state.coatLease.applied and state.coatLease.applied.Parent ~= state.coatLease.part then
                coatInfo.Text = "The local surface trial was replaced or removed. Ownership is unchanged; no automatic reapplication."
            end
        end
        ui.places = card(travelPage, "CUSTOM WAYPOINTS & BOOKMARKS", "Enter X/Z or bookmark your current position. Selecting a destination never moves you. Scout and Move Once remain separate, with the existing landing checks.")
        ui.inputX = new("TextBox", {Name = "WaypointX", Text = "1070", PlaceholderText = "X coordinate",
            ClearTextOnFocus = false, BackgroundColor3 = C.bg, TextColor3 = C.text, Font = Enum.Font.Gotham,
            TextSize = 13, Size = UDim2.new(1, 0, 0, 30), BorderSizePixel = 0}, ui.places)
        ui.inputZ = new("TextBox", {Name = "WaypointZ", Text = "1505", PlaceholderText = "Z coordinate",
            ClearTextOnFocus = false, BackgroundColor3 = C.bg, TextColor3 = C.text, Font = Enum.Font.Gotham,
            TextSize = 13, Size = UDim2.new(1, 0, 0, 30), BorderSizePixel = 0}, ui.places)
        ui.customTarget = button(ui.places, "SELECT CUSTOM X/Z")
        ui.bookmark = button(ui.places, "BOOKMARK MY CURRENT POSITION", C.surface)
        ui.placeText = label(ui.places, "0 / 24 bookmarks. Coordinates must be finite and within +/-8192 studs.", 11, 34, C.muted)
        ui.placeList = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, ui.places)
        list(ui.placeList, 4)
        ui.removePlace = button(ui.places, "REMOVE LAST BOOKMARK", C.surface, 28)
        ui.savePlaces = button(ui.places, "SAVE BOOKMARKS .TXT", C.surface, 28)
        ui.loadPlaces = button(ui.places, "LOAD SAVED BOOKMARKS", C.surface, 28)
        ext.renderPlaces = function()
            for _, connection in ipairs(ext.placeConnections) do connection:Disconnect() end
            table.clear(ext.placeConnections)
            for _, child in ipairs(ui.placeList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
            for index, point in ipairs(ext.places) do
                local b = button(ui.placeList, string.format("Bookmark %02d / X %.0f Z %.0f", index, point.x, point.z), C.surface, 28)
                ext.placeConnections[#ext.placeConnections + 1] = b.Activated:Connect(function()
                    if state.alive then setTarget({name = "Bookmark " .. index, x = point.x, z = point.z}) end
                end)
            end
            ui.placeText.Text = #ext.places .. " / 24 bookmarks. No gameplay experiments are saved or enabled by loading places."
        end
        action(ui.customTarget, function()
            local point = Core.place(ui.inputX.Text, ui.inputZ.Text)
            if not point then say("Invalid coordinates. Enter finite numbers within +/-8192 studs.", true); return end
            setTarget({name = "Custom waypoint", x = point.x, z = point.z})
        end)
        action(ui.bookmark, function()
            local _, hum, root = own()
            if not hum or not root or hum.Health <= 0 then say("Spawn a living animal before bookmarking.", true); return end
            if #ext.places >= 24 then say("Bookmark limit reached (24). Remove one before adding another.", true); return end
            local point = Core.place(root.Position.X, root.Position.Z)
            if not point then say("Current position is outside the bookmark range.", true); return end
            ext.places[#ext.places + 1] = point
            ext.renderPlaces()
        end)
        action(ui.removePlace, function() table.remove(ext.places); ext.renderPlaces() end)
        ext.writeJSON = function(filename, value)
            local write = optional("writefile")
            if not write then say("writefile unavailable. The hub remains usable without saving.", true); return false end
            local ok, encoded = pcall(function() return game:GetService("HttpService"):JSONEncode(value) end)
            if not ok or type(encoded) ~= "string" then failure("JSON encoding", encoded); return false end
            if ext.fileBusy then say("Another export is still writing. Current data retained; try saving after it finishes.", true); return false end
            if ext.fieldSaved == filename then ext.fieldSaved = nil end
            ext.fileBusy = true
            local written, result = pcall(write, filename, encoded)
            if not written or result == false then ext.fileBusy = false; failure("JSON file write", result); return false end
            local reader = optional("readfile")
            if reader then
                local readOK, content = pcall(reader, filename)
                ext.fileBusy = false
                if not readOK or content ~= encoded then
                    say("Saved file could not be read back identically. Treat it as unverified; do not assume a complete export.", true)
                    return false
                end
                say("Saved " .. filename .. " / " .. #encoded .. " bytes / read-back verified.")
            else ext.fileBusy = false; say("Saved " .. filename .. " / " .. #encoded .. " bytes / read-back API unavailable.") end
            return true, reader ~= nil
        end
        action(ui.savePlaces, function()
            ext.writeJSON("FERAL_Hub_Places_v1_4.json.txt", {schema = "feral-places/1", places = ext.places})
        end)
        action(ui.loadPlaces, function()
            local read = optional("readfile")
            if not read then say("readfile unavailable.", true); return end
            local ok, raw = pcall(read, "FERAL_Hub_Places_v1_4.json.txt")
            if not ok then ok, raw = pcall(read, "FERAL_Hub_Places_v1_2.json.txt") end
            if not ok or type(raw) ~= "string" or #raw > 65536 then say("Saved places unavailable or over the 64KB limit.", true); return end
            local decoded, data = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
            local clean = decoded and Core.cleanPlaces(data)
            if not clean then say("Saved places failed validation. Current bookmarks were preserved.", true); return end
            ext.places = clean
            ext.renderPlaces()
            say("Loaded validated bookmarks. Resource and movement toggles are unchanged.")
        end)
        ui.saveField = button(ui.field, "SAVE FOCUSED FIELD REPORT .JSON.TXT")
        ui.copyFieldName = button(ui.field, "COPY LAST FIELD REPORT FILENAME", C.surface)
        ext.export = function()
            local snapshot = ext.ownership and {
                received_seconds_ago = math.max(0, os.clock() - ext.ownershipAt),
                filtered = true, values = ext.ownership,
                note = "Known species/coat booleans and the active own slot key/species/coat only. Missing entries are unknown; ownership is not restricted-spawn permission.",
            } or {observed = false}
            return {
                schema = "feral-field-report/1.4", place_id = 108901361810209,
                session_id = ext.session, part = ext.part, part_started_seconds = ext.partStarted,
                manual_save_revision = ext.manualRevision or 0, checkpoint_generation = ext.checkpointGeneration or 0,
                features = ext.featureState and ext.featureState() or {},
                goal_experiments = Core.goalCopy(ext.goal and ext.goal.data or {}),
                uptime_seconds = math.max(0, os.clock() - state.born),
                scope = "own character; visible wallet; allowlisted own inventory replies; no source collection",
                health_writer = "unidentified; this hub does not write HP", stamina_field_result = "Bear user report; Tiger v1.2 tuned sprint/burst/swim samples above 99% with no exhausted samples",
                grants = {arbitrary_amber = "unestablished", permanent_unlock = "unestablished", health_regen = "local_HP_trial_failed; no_added_regeneration_implemented", restricted_spawn = "unestablished"},
                timeline = {events = ext.events.items, stored = #ext.events.items, total_seen = ext.events.total,
                    dropped = ext.events.dropped, truncated = ext.events.dropped > 0,
                    truncation_reason = ext.events.dropped > 0 and "6000-event preserve-first budget; later events omitted" or "none",
                    first_omitted_seconds = ext.firstOmitted, older_events_evicted = false,
                    next_step = "Save this part, then SAVE PART & CONTINUE to begin the next. Upload every part for full coverage."},
                observations_by_species_mode_and_tuning = ext.movement,
                health_gain_followed_by_drop_pairs = ext.gainDropPairs,
                own_inventory = snapshot,
                current_visible_amber = Core.finite(player:GetAttribute("Amber")) and player:GetAttribute("Amber") or nil,
                known_native_reply_labels = state.serverReplies,
                native_paid_notices = state.rewardPaidNotices,
                mobility_inputs_applied = ext.mobilityNeeds ~= nil and ext.mobilityInjury ~= nil,
                own_cached_owner_gates = ext.ownerGates,
                own_server_lookup_results = ext.ownerReads,
                owner_tools_scope = "Legacy self look/list audits plus opt-in self gift trials. No restores, resets, role changes or other-account queries.",
                errors = state.errors, last_error = state.lastError,
                privacy = "No usernames, account IDs, chat, other players, raw reply payloads, credentials or arbitrary attribute enumeration.",
                inference_limit = "Timing, client attributes and paid notices do not prove a writer, a grant, server acceptance or safe travel.",
            }
        end
        action(ui.saveField, function()
            if ext.saving then say("A checkpoint is still writing; wait for it to finish.", true); return end
            local filename = ext.filename()
            if ext.writeJSON(filename, ext.export()) then ext.fieldSaved = filename end
        end)
        action(ui.copyFieldName, function()
            local copy = optional("setclipboard") or optional("toclipboard")
            if not copy or not ext.fieldSaved then say("Save a field report first; clipboard support is also required.", true); return end
            copy(ext.fieldSaved); say("Field report filename copied.")
        end)
        ui.goalCard = card(infoPage, "GOAL STATUS", "Stamina: Bear user report and Tiger sprint/burst/swim field evidence. Added HP regeneration, arbitrary amber, restricted spawns and owner privileges: not established before these trials; see the current goal results. Speed/leap inputs: implemented client experiments, pending in-game testing. Owned-coat equips and earned rewards: native requests with explicit confirmation, not entitlement grants.")
        ui.owner = card(ownerPage, "OWNER TOOLS — ACCESS AUDIT", "Gift UI: amber adjustments, all/individual animals, coats, revives and pending deliveries. Save UI: version lookup, restore and undo; restore can replace progress and kick its target. This legacy card performs own-account look/list reads and launcher visibility checks. The new goal cards separately offer explicit self-only gift trials. Your v1.2 cached gates did not match and no usable lookup was returned. No role access is established. This legacy card submits no gift, restore or undo.")
        ui.checkOwner = button(ui.owner, "CHECK MY CACHED OWNER TOOL GATES", C.surface)
        ui.ownerStatus = label(ui.owner, "Not checked. Only own gate outcomes and limited own-save metadata may be kept. Owner lists, account IDs, names, raw saves and version IDs are omitted.", 12, 75, C.muted)
        ui.giftLookup = button(ui.owner, "CHECK SERVER GIFT LOOKUP — MY ACCOUNT ONLY", C.surface, 35)
        ui.saveLookup = button(ui.owner, "CHECK SERVER SAVE-VERSION LIST — MY ACCOUNT ONLY", C.surface, 35)
        ui.lookupStatus = label(ui.owner, "Opt-in read-only requests using the recovered look/list protocol. A successful read does not establish gift or restore permission. No arbitrary target can be entered.", 11, 65, C.muted)
        ui.showOwnerLaunchers = button(ui.owner, "SHOW EXISTING GIFT / SAVE LAUNCHERS IF GATE MATCHES", C.surface, 39)
        ext.ownerGates, ext.ownerUILeases = {}, {}
        ext.ownerReads, ext.ownerReadBusy, ext.ownerReadEpoch = {}, {}, 0
        ext.lookup = function(spec)
            if ext.ownerReadBusy[spec.key] then say("That own-account lookup is still pending; no duplicate request sent.", true); return end
            local remote = ReplicatedStorage:FindFirstChild(spec.remote)
            local ownId = player.UserId
            if not remote or not remote:IsA("RemoteFunction") or not Core.finite(ownId) or ownId <= 0 then
                say("Own-account lookup unavailable: missing interface or account identity.", true); return
            end
            ext.ownerReadBusy[spec.key] = true
            local epoch = ext.ownerReadEpoch
            ui.lookupStatus.Text = "Waiting for own-account " .. spec.key .. " lookup. No gift, save or restore action is being sent."
            task.delay(8, function()
                if state.alive and ext.ownerReadBusy[spec.key] and epoch == ext.ownerReadEpoch then
                    ui.lookupStatus.Text = "Own-account lookup is still pending. No automatic retry; other hub controls remain usable."
                end
            end)
            task.spawn(function()
                local packed = table.pack(pcall(function()
                    -- Only these two constant read-only specs call this function; target is always self.
                    return remote:InvokeServer(spec.verb, tostring(ownId))
                end))
                ext.ownerReadBusy[spec.key] = nil
                if not state.alive or epoch ~= ext.ownerReadEpoch then return end
                local clean = Core.lookupReply(packed, ownId, spec.key)
                clean.received_at_seconds = math.max(0, os.clock() - state.born)
                ext.ownerReads[spec.key] = clean
                ui.lookupStatus.Text = spec.key .. ": " .. clean.state
                    .. (clean.saved_amber_snapshot ~= nil and (" / saved amber snapshot " .. clean.saved_amber_snapshot) or "")
                    .. (clean.saved_version_count ~= nil and (" / saved versions " .. clean.saved_version_count) or "")
                    .. ". Write permission remains unverified; raw reply and account identifiers are omitted."
                ext.emit("own_owner_tool_lookup", {tool = spec.key, state = clean.state})
            end)
        end
        action(ui.giftLookup, function() ext.lookup({key = "gift", remote = "FeralGive", verb = "look"}) end)
        action(ui.saveLookup, function() ext.lookup({key = "saves", remote = "FeralSaveAdmin", verb = "list"}) end)
        ext.renderOwner = function()
            ui.ownerStatus.Text = "Cached gates: gift " .. tostring(ext.ownerGates.gift or "unchecked")
                .. "; saves " .. tostring(ext.ownerGates.saves or "unchecked")
                .. "; developer " .. tostring(ext.ownerGates.developer or "unchecked")
                .. ". Native UIs present: GIVE " .. tostring(parent:FindFirstChild("FeralGive") ~= nil)
                .. ", SAVES " .. tostring(parent:FindFirstChild("FeralSaveAdmin") ~= nil)
                .. ". These are client observations; server authorization is unverified."
        end
        action(ui.checkOwner, function()
            for _, spec in ipairs({
                {module = "GiftConfig", field = "ADMINS", style = "array", key = "gift"},
                {module = "OnboardingConfig", field = "OWNERS", style = "map", key = "saves"},
                {module = "DevConfig", field = "OWNERS", style = "array", key = "developer"},
            }) do
                cachedModule(spec.module, function(config)
                    if not state.alive then return end
                    -- Read own UserId transiently for the predicate; never retain it or owner lists.
                    ext.ownerGates[spec.key] = Core.clientGate(config and config[spec.field], player.UserId, spec.style)
                    ext.renderOwner()
                end, "owner_audit")
            end
        end)
        action(ui.showOwnerLaunchers, function()
            for _, lease in ipairs(ext.ownerUILeases) do state.errors = state.errors + Core.restore(lease) end
            ext.ownerUILeases = {}
            local shown = 0
            for _, spec in ipairs({
                {gate = "gift", gui = "FeralGive", key = "GiveKey"},
                {gate = "saves", gui = "FeralSaveAdmin", key = "SavesKey"},
            }) do
                local native = parent:FindFirstChild(spec.gui)
                if ext.ownerGates[spec.gate] == "matched" and native and native:IsA("ScreenGui") then
                    local lease = Core.patch(native, {Enabled = true})
                    if lease then
                        ext.ownerUILeases[#ext.ownerUILeases + 1] = lease
                        local launcher = native:FindFirstChild(spec.key)
                        if launcher and launcher:IsA("TextButton") then
                            local buttonLease = Core.patch(launcher, {Visible = true})
                            if buttonLease then ext.ownerUILeases[#ext.ownerUILeases + 1] = buttonLease end
                        end
                        shown = shown + 1
                    end
                end
            end
            say("Existing native owner tool UIs shown: " .. shown .. ". No panel constructed, role changed, gift sent or save action submitted.")
            ext.renderOwner()
        end)

        -- Finished client controls. Each async operation is cancellable and scoped.
        staminaCard.LayoutOrder = -100
        ui.staminaWatch.LayoutOrder = -90
        ext.speedMultiplier, ext.leapMultiplier = 1, 1
        ext.speedEpoch, ext.leapEpoch, ext.claimEpoch = 0, 0, 0
        ext.settingLeases, ext.claimTotals = {}, {sent = 0, paid_notices_matched = 0, sync_confirmed = 0}
        ui.speed = card(resourcePage, "LAND / SWIM SPEED PROFILES", "Changes live cached RUN_SPEED and SWIM_SPEED inputs read by WolfController. A client experiment, not a permanent species stat. Swimming has additional species caps. Select a profile; RESET and X restore owned fields.")
        ui.speed.LayoutOrder = -80
        ui.speedText = label(ui.speed, "Original inputs. No speed profile applied.", 12, 42, C.muted)
        ext.stopSpeed = function()
            ext.speedEpoch = ext.speedEpoch + 1
            state.errors = state.errors + Core.restore(ext.speedLease)
            ext.speedLease, ext.speedMultiplier = nil, 1
            ui.speedText.Text = "Original inputs restored where still owned; later external edits preserved."
        end
        ext.applySpeed = function(multiplier)
            ext.stopSpeed()
            local epoch = ext.speedEpoch
            ui.speedText.Text = "Checking already-loaded movement inputs..."
            cachedModule("NeedsConfig", function(config)
                if not state.alive or epoch ~= ext.speedEpoch then return end
                local changes = Core.speedPlan(config, multiplier)
                if not changes then ui.speedText.Text = "Expected live inputs unavailable; no speed patch applied."; return end
                local lease, why = Core.patch(config, changes)
                ext.speedLease, ext.speedMultiplier = lease, lease and multiplier or 1
                ext.speedTarget = state.cacheTargets.NeedsConfig
                ui.speedText.Text = lease and string.format("%.2fx cached land/swim inputs applied. Observe actual movement; game/server constraints can still apply.", multiplier) or why
                ext.emit("speed_profile", {multiplier = ext.speedMultiplier, applied = lease ~= nil})
            end, "speed")
        end
        for _, multiplier in ipairs({1.25, 1.5, 2}) do
            local b = button(ui.speed, string.format("APPLY %.2fx LAND / SWIM INPUTS", multiplier), C.surface)
            action(b, function() ext.applySpeed(multiplier) end)
        end
        ui.resetSpeed = button(ui.speed, "RESET SPEED PROFILE", C.surface)
        action(ui.resetSpeed, ext.stopSpeed)

        ui.leap = card(resourcePage, "FORWARD LEAP PROFILES", "Tunes the game's body-length leap distance and forward-speed cap. This does not add double-jumps, flying or extra height. Zero-length snake entries remain zero; native flight/climb exclusions remain in the controller.")
        ui.leap.LayoutOrder = -70
        ui.leapText = label(ui.leap, "Original leap inputs.", 12, 42, C.muted)
        ext.stopLeap = function()
            ext.leapEpoch = ext.leapEpoch + 1
            state.errors = state.errors + Core.restore(ext.leapBodies) + Core.restore(ext.leapConfig)
            ext.leapBodies, ext.leapConfig, ext.leapMultiplier = nil, nil, 1
            ui.leapText.Text = "Original leap inputs restored where still owned."
        end
        ext.applyLeap = function(multiplier)
            ext.stopLeap()
            local epoch = ext.leapEpoch
            ui.leapText.Text = "Checking the already-loaded leap module..."
            cachedModule("JumpLeapConfig", function(config)
                if not state.alive or epoch ~= ext.leapEpoch then return end
                local bodies, general = Core.leapPlan(config, multiplier)
                if not bodies then ui.leapText.Text = "Expected leap inputs unavailable. No patch applied."; return end
                local first, why = Core.patch(config.BODY_LENGTHS, bodies)
                if not first then ui.leapText.Text = why; return end
                local second, why2 = Core.patch(config, general)
                if not second then state.errors = state.errors + Core.restore(first); ui.leapText.Text = why2; return end
                ext.leapBodies, ext.leapConfig, ext.leapMultiplier = first, second, multiplier
                ext.leapTarget = state.cacheTargets.JumpLeapConfig
                ui.leapText.Text = string.format("%.2fx distance and cap inputs applied. In-game effect is unverified; normal jump restrictions still apply.", multiplier)
                ext.emit("leap_profile", {multiplier = multiplier})
            end, "leap")
        end
        for _, multiplier in ipairs({1.5, 2}) do
            local b = button(ui.leap, string.format("APPLY %.2fx FORWARD LEAP INPUTS", multiplier), C.surface)
            action(b, function() ext.applyLeap(multiplier) end)
        end
        ui.resetLeap = button(ui.leap, "RESET LEAP PROFILE", C.surface)
        action(ui.resetLeap, ext.stopLeap)

        ui.recovery = card(resourcePage, "NATIVE REST HELPER — NO ADDED HP REGEN", "Requests the game's Rest action. Assist requests once per recovery episode after two idle seconds outside combat/grabs/water. It stops trying if the game does not acknowledge. It does not write HP, cure ailments, alter healing rates or make you safe from attacks.")
        ui.recovery.LayoutOrder = -60
        ui.restNow = button(ui.recovery, "REQUEST NATIVE REST NOW", C.surface)
        ui.restAssist = button(ui.recovery, "IDLE RECOVERY ASSIST: OFF")
        ui.restText = label(ui.recovery, "No added healing. Rest is controlled by the game; move or use R to leave it normally.", 12, 55, C.muted)
        ext.restSample = function(char, hum, root)
            local sample = ext.context(char, hum, root)
            sample.focused = UIS:GetFocusedTextBox() ~= nil
            sample.menu = player:GetAttribute("FeralMenuOpen") == true or player:GetAttribute("FeralTitleOpen") == true
            sample.blocked = not root or (root and math.abs(root.AssemblyLinearVelocity.Y) > 1) or false
            if char then
                for _, key in ipairs({"FeralPinned", "CarriedBy", "FeralDragged", "FeralRider", "FeralLatching", "FeralVenomDown", "WolfFeed", "FeralDiving"}) do
                    local value = char:GetAttribute(key)
                    if value ~= nil and value ~= false and value ~= 0 and value ~= "" then sample.blocked = true end
                end
            end
            return sample
        end
        ext.requestRest = function(automatic)
            local char, hum, root = own()
            local sample = ext.restSample(char, hum, root)
            local allowed, why = Core.restAllowed(sample)
            if not allowed then if not automatic then ui.restText.Text = why end; return end
            if ext.restPending or os.clock() - (ext.lastRestRequest or -math.huge) < 8 then
                if not automatic then ui.restText.Text = "A request is pending or cooling down; no repeated toggle sent." end
                return
            end
            ext.lastRestRequest, ext.restEpisode = os.clock(), true
            local old = player:GetAttribute("FeralRestTap")
            local value = os.clock()
            if old == value then value = value + .001 end
            player:SetAttribute("FeralRestTap", value)
            ext.restCharacter = char
            ext.restPending = {character = char, at = os.clock()}
            ui.restText.Text = "Rest requested; waiting for the game's own WolfRest state. No HP written."
            ext.emit("native_rest_requested", {automatic = automatic == true})
        end
        action(ui.restNow, function() ext.requestRest(false) end)
        action(ui.restAssist, function()
            ext.restAssist, ext.restEpisode, ext.restIdleAt = not ext.restAssist, nil, nil
            ui.restAssist.Text = ext.restAssist and "IDLE RECOVERY ASSIST: ON" or "IDLE RECOVERY ASSIST: OFF"
            ui.restAssist.BackgroundColor3 = ext.restAssist and C.green or C.blue
            ui.restText.Text = ext.restAssist and "Armed for one idle recovery episode. It will not keep forcing rest after you stand up." or "Assist off. Any native rest already started remains under normal game control."
        end)

        ui.comfort = card(resourcePage, "COMFORT & PERFORMANCE", "Uses the game's own local setting attributes. Calm camera sets shake to zero and running sway off. Performance mode uses native geometry/visual culling. Turning off restores values still owned by this hub.")
        ui.calm = button(ui.comfort, "CALM CAMERA: OFF", C.surface)
        ui.perf = button(ui.comfort, "NATIVE PERFORMANCE MODE: OFF", C.surface)
        ext.restoreSetting = function(name)
            local entries = ext.settingLeases[name]
            if not entries then return end
            for _, entry in ipairs(entries) do
                local ok = pcall(function()
                    if player:GetAttribute(entry.key) == entry.wanted then player:SetAttribute(entry.key, entry.old) end
                end)
                if not ok then state.errors = state.errors + 1 end
            end
            ext.settingLeases[name] = nil
        end
        ext.toggleSetting = function(name, changes, control, titleText)
            if ext.settingLeases[name] then ext.restoreSetting(name); control.Text = titleText .. ": OFF"; return end
            local entries = {}
            ext.settingLeases[name] = entries
            for key, value in pairs(changes) do
                local old = player:GetAttribute(key)
                entries[#entries + 1] = {key = key, old = old, wanted = value}
                local ok = pcall(function() player:SetAttribute(key, value) end)
                if not ok then ext.restoreSetting(name); control.Text = titleText .. ": UNAVAILABLE"; return end
            end
            control.Text = titleText .. ": ON"
        end
        action(ui.calm, function() ext.toggleSetting("calm", {FeralSet_shake = 0, FeralSet_sway = false}, ui.calm, "CALM CAMERA") end)
        action(ui.perf, function() ext.toggleSetting("perf", {FeralSet_perf = true}, ui.perf, "NATIVE PERFORMANCE MODE") end)

        ui.equip = card(coatsPage, "EQUIP A COAT YOU ACTUALLY OWN", "Select an animal portrait and coat above, then equip. Requires a fresh own-inventory reply, listed ownership, and a matching living species/active slot. Sends only the native wearCoat request; no buy, unlock or save replacement. Success requires a subsequent matching inventory sync.")
        ui.equip.LayoutOrder = -10
        ui.equipButton = button(ui.equip, "EQUIP SELECTED OWNED COAT — GAME REQUEST")
        ui.equipText = label(ui.equip, "No request sent. Your v1.2 report listed Bear Spirit and Elephant Desert; fresh current ownership is checked again.", 12, 58, C.muted)
        action(ui.equipButton, function()
            if ext.equipPending then ui.equipText.Text = "A coat request is pending; no duplicate sent."; return end
            local char, hum = own()
            local sp, selected = state.selectedSpecies, state.selectedCoat
            local coat = selected and selected.definition
            if not char or not hum or hum.Health <= 0 or char:GetAttribute("Species") ~= sp
                or type(coat) ~= "table" or selected.species ~= sp then
                ui.equipText.Text = "Choose a coat for the species you are currently playing."; return
            end
            if ext.ownershipCharacter ~= char then ui.equipText.Text = "Refresh your own inventory after this character spawned first."; return end
            local allowed, why = Core.equipAllowed(ext.ownership, ext.ownershipAt and os.clock() - ext.ownershipAt, sp, coat.id)
            if not allowed then ui.equipText.Text = why; return end
            local remote = ReplicatedStorage:FindFirstChild("FeralSlots")
            if not remote or not remote:IsA("RemoteEvent") then ui.equipText.Text = "Native coat interface unavailable."; return end
            observeNativeReplies()
            resetLocalCoat()
            ext.equipPending = {character = char, species = sp, coat = coat.id, key = ext.ownership.active.key, at = os.clock()}
            ui.equipText.Text = "Coat request sent. Waiting for a new sync; a local appearance is not confirmation."
            ext.emit("owned_coat_equip_requested", {species = sp, coat = coat.id})
            local sent, detail = pcall(function() remote:FireServer("wearCoat", ext.equipPending.key, coat.id) end)
            if not sent then ext.equipPending = nil; ui.equipText.Text = "Coat request failed; no retry sent."; failure("Owned coat request", detail) end
        end)
        ui.refreshCoat = button(ui.equip, "OPEN NORMAL GUIDE TO REFRESH OWN INVENTORY", C.surface)
        action(ui.refreshCoat, function()
            observeNativeReplies()
            local value = os.clock()
            if player:GetAttribute("FeralGuideRequest") == value then value = value + .001 end
            player:SetAttribute("FeralGuideRequest", value)
            ui.equipText.Text = "Normal guide requested. Return to your animal after its own sync, then choose a listed-owned coat."
        end)

        ui.claim = card(livePage, "EARNED AMBER CLAIMS & LEDGER", "This claims only already-eligible playtime/daily rewards using fresh server state. You already collect daily rewards, so this may have nothing new to claim. It is not an amber generator. Visible wallet changes are recorded without crediting them to this hub.")
        ui.claimButton = button(ui.claim, "CLAIM ALL SERVER-REPORTED ELIGIBLE REWARDS", C.surface, 38)
        ui.claimText = label(ui.claim, "No earned claims sent. The separate goal cards contain self-gift and duplicate-reward trials; they are not confirmed grants.", 12, 56, C.muted)
        ui.walletLedger = label(ui.claim, "Waiting for visible wallet samples.", 12, 32, C.muted)
        ext.endClaims = function(message)
            ext.claimEpoch, ext.claimBatch = ext.claimEpoch + 1, nil
            ui.claimText.Text = message
        end
        ext.helloRewards = function()
            observeNativeReplies()
            local remote = ReplicatedStorage:FindFirstChild("FeralRewards")
            if not remote or not remote:IsA("RemoteEvent") then return false end
            local ok, detail = pcall(function() remote:FireServer("hello") end)
            if not ok then failure("Reward state request", detail) end
            return ok
        end
        ext.advanceClaims = function()
            local batch = ext.claimBatch
            if not batch or not state.alive then return end
            local data = ext.rewards
            if not data or not ext.rewardsAt or os.clock() - ext.rewardsAt > 5 then
                batch.stage, batch.stageAt = "state", os.clock()
                if not ext.helloRewards() then ext.endClaims("Native reward interface unavailable.") end
                return
            end
            local plan = Core.rewardPlan(data, batch.config, batch.attempted)
            if #plan == 0 or batch.sent >= 17 then
                ext.endClaims("Finished: " .. batch.sent .. " eligible requests, " .. batch.confirmed .. " matching paid/sync notices. No other eligible reward was reported.")
                return
            end
            local item = plan[1]
            local remote = ReplicatedStorage:FindFirstChild("FeralRewards")
            if not remote or not remote:IsA("RemoteEvent") then ext.endClaims("Native reward interface disappeared; claims stopped."); return end
            batch.attempted[item.kind .. "/" .. item.index] = true
            batch.current, batch.sent, batch.stage, batch.stageAt = item, batch.sent + 1, "claim", os.clock()
            ext.claimTotals.sent = ext.claimTotals.sent + 1
            ui.claimText.Text = "Requested eligible " .. item.kind .. " reward; waiting for paid/state confirmation. No automatic retry."
            ext.emit("earned_reward_claim_requested", {kind = item.kind, index = item.index})
            local ok, detail = pcall(function() remote:FireServer("claim", item.kind, item.kind == "play" and item.index or nil) end)
            if not ok then ext.endClaims("Reward request failed; no retry sent."); failure("Earned reward request", detail) end
        end
        ext.confirmClaim = function(method)
            local batch = ext.claimBatch
            if not batch or batch.stage ~= "claim" then return end
            batch.confirmed = batch.confirmed + 1
            ext.claimTotals[method] = ext.claimTotals[method] + 1
            ext.emit("earned_reward_confirmation_notice", {method = method, kind = batch.current.kind, index = batch.current.index})
            batch.current, batch.stage, batch.stageAt = nil, "state", os.clock()
            ext.rewardsAt = nil
            if not ext.helloRewards() then ext.endClaims("Reward refresh unavailable; stopped after confirmation.") end
        end
        action(ui.claimButton, function()
            if ext.goal and ext.goal.replay then ui.claimText.Text = "Claimed-reward replay trial is pending; no earned-claim batch started."; return end
            if ext.claimStarting or ext.claimBatch then ui.claimText.Text = "A reward check is pending; no duplicate request sent."; return end
            observeNativeReplies()
            ext.claimStarting = true
            ext.claimEpoch = ext.claimEpoch + 1
            local epoch = ext.claimEpoch
            cachedModule("RewardConfig", function(config)
                if not state.alive or epoch ~= ext.claimEpoch then return end
                ext.claimStarting = false
                if type(config) ~= "table" or config.ON ~= true or type(config.PLAYTIME) ~= "table" then ui.claimText.Text = "Expected already-loaded reward config unavailable; nothing sent."; return end
                ext.claimBatch = {config = config, attempted = {}, sent = 0, confirmed = 0, stage = "state", stageAt = os.clock()}
                ext.rewardsAt = nil
                ui.claimText.Text = "Reading fresh server reward state. Claims use that eligibility, without adding elapsed time."
                if not ext.helloRewards() then ext.endClaims("Native reward interface unavailable.") end
            end, "reward_claims")
        end)

        ext.oldReply = ext.onReply
        ext.onReply = function(remoteName, kind, payload, detail)
            ext.oldReply(remoteName, kind, payload)
            if remoteName == "FeralSlots" and kind == "sync" and ext.equipPending then
                local pending, active = ext.equipPending, ext.ownership and ext.ownership.active
                if pending.character ~= player.Character then ext.equipPending = nil; ui.equipText.Text = "Character changed; coat result unresolved."
                elseif active and active.key == pending.key and active.species == pending.species and active.coat == pending.coat then
                    ui.equipText.Text = "Game sync reports " .. active.species .. " / " .. active.coat .. " equipped. Persistence after rejoining was not tested."
                    ext.emit("owned_coat_equip_sync_confirmed", {species = active.species, coat = active.coat})
                    ext.lastEquip = {species = active.species, coat = active.coat, sync_confirmed = true}
                    ext.equipPending = nil
                end
            elseif remoteName == "FeralRewards" and kind == "state" then
                local clean = Core.cleanRewards(payload)
                if clean then
                    ext.rewards, ext.rewardsAt = clean, os.clock()
                    local batch = ext.claimBatch
                    if batch and batch.stage == "state" then ext.advanceClaims()
                    elseif batch and batch.current then
                        local current = batch.current
                        if current.kind == "play" and clean.pc[current.index] == true
                            or current.kind == "daily" and clean.claimed == true and clean.day == current.index then
                            ext.confirmClaim("sync_confirmed")
                        end
                    end
                end
            elseif remoteName == "FeralRewards" and kind == "paid" then
                local batch = ext.claimBatch
                if batch and batch.current and payload == batch.current.kind and detail == batch.current.index then ext.confirmClaim("paid_notices_matched") end
            end
        end

        ext.filename = function(checkpointSlot)
            local base = string.format("FERAL_Field_Report_v1_4_%s_PART_%03d", ext.session, ext.part)
            if checkpointSlot then return base .. "_CHECKPOINT_" .. checkpointSlot .. ".json.txt" end
            ext.manualRevision = (ext.manualRevision or 0) + 1
            return base .. string.format("_SAVE_%03d.json.txt", ext.manualRevision)
        end
        ui.continueField = button(ui.field, "SAVE PART & CONTINUE IN A NEW PART", C.surface)
        ui.checkpointToggle = button(ui.field, "60s FILE CHECKPOINTS: OFF", C.surface)
        action(ui.continueField, function()
            if ext.saving then say("A checkpoint is still writing; wait for it to finish.", true); return end
            local filename = ext.filename()
            local saved, verified = ext.writeJSON(filename, ext.export())
            if not saved then return end
            ext.fieldSaved = filename
            if not verified then say("Saved without read-back verification. Current part retained in memory; no rotation.", true); return end
            ext.part, ext.partStarted, ext.manualRevision = ext.part + 1, math.max(0, os.clock() - state.born), 0
            ext.events, ext.firstOmitted = Core.journal(6000), nil
            ext.emit("report_part_started", {part = ext.part})
            say("Saved completed part. Recording the next part; upload every numbered part for this session.")
        end)
        action(ui.checkpointToggle, function()
            if not ext.checkpoints and not optional("writefile") then say("writefile is unavailable. Manual clipboard status still works.", true); return end
            ext.checkpoints = not ext.checkpoints
            ext.lastCheckpoint = -math.huge
            ui.checkpointToggle.Text = ext.checkpoints and "60s FILE CHECKPOINTS: ON" or "60s FILE CHECKPOINTS: OFF"
        end)
        ext.checkpoint = function()
            if ext.saving then return end
            ext.saving = true
            ext.checkpointGeneration = (ext.checkpointGeneration or 0) + 1
            local filename = ext.filename(ext.checkpointGeneration % 2 == 1 and "A" or "B")
            local ok, details = pcall(function() return ext.writeJSON(filename, ext.export()) end)
            ext.saving = false
            if ok and details then ext.fieldSaved = filename
            else
                ext.checkpoints = false
                ui.checkpointToggle.Text = "60s FILE CHECKPOINTS: OFF — SAVE FAILED"
                if not ok then failure("Field checkpoint", details) end
            end
        end
        ext.speedMatches = function()
            return world() ~= nil and world():FindFirstChild("NeedsConfig") == ext.speedTarget and Core.leaseMatches(ext.speedLease)
        end
        ext.leapMatches = function()
            return world() ~= nil and world():FindFirstChild("JumpLeapConfig") == ext.leapTarget and Core.leaseMatches(ext.leapBodies) and Core.leaseMatches(ext.leapConfig)
        end
        ext.featureState = function()
            return {speed_multiplier = ext.speedMultiplier, speed_inputs_match = ext.speedMatches(),
                leap_multiplier = ext.leapMultiplier, leap_inputs_match = ext.leapMatches(),
                rest_assist = ext.restAssist == true, health_writes = 0, rest_requests = "native Rest only; no added healing",
                reward_requests = ext.claimTotals, last_owned_coat_equip = ext.lastEquip,
                checkpoints_enabled = ext.checkpoints, recording_event_limit = 6000}
        end
        ext.oldTick = ext.tick
        ext.tick = function(char, hum, root, now)
            ext.oldTick(char, hum, root, now)
            if char ~= ext.restCharacter then
                ext.restCharacter, ext.restEpisode, ext.restIdleAt, ext.restPending = char, nil, nil, nil
            end
            if ext.restPending then
                if char ~= ext.restPending.character then ext.restPending = nil
                elseif char:GetAttribute("WolfRest") == true then
                    ext.restPending = nil
                    ui.restText.Text = "Game resting state observed. Any health recovery uses the game's ordinary rules. No hub HP regen is active."
                    ext.emit("native_rest_acknowledged", {})
                elseif now - ext.restPending.at >= 5 then
                    ext.restPending, ext.restAssist = nil, false
                    ui.restAssist.Text, ui.restAssist.BackgroundColor3 = "IDLE RECOVERY ASSIST: OFF", C.blue
                    ui.restText.Text = "No rest acknowledgment within 5s. Assist stopped; no repeated toggle or HP write."
                end
            end
            if ext.restAssist then
                local sample = ext.restSample(char, hum, root)
                local recovery = (sample.health and sample.health_max and sample.health < sample.health_max * .95)
                    or (sample.injury or 0) > 0 or (sample.bleed or 0) > 0 or (sample.venom or 0) > 0
                if not recovery then ext.restEpisode, ext.restIdleAt = nil, nil
                elseif Core.restAllowed(sample) and not ext.restEpisode then
                    ext.restIdleAt = ext.restIdleAt or now
                    if now - ext.restIdleAt >= 2 then ext.requestRest(true) end
                else ext.restIdleAt = nil end
            end
            if ext.equipPending and now - ext.equipPending.at >= 8 then
                ext.equipPending = nil
                ui.equipText.Text = "No matching inventory sync within 8s. Equip remains unconfirmed; no retry or purchase sent."
            end
            if ext.claimBatch and now - ext.claimBatch.stageAt >= 8 then ext.endClaims("No expected reward reply within 8s. Stopped with an unresolved result; no retry or arbitrary grant.") end
            local wallet = player:GetAttribute("Amber")
            if Core.finite(wallet) then
                ext.walletStart = ext.walletStart or wallet
                ui.walletLedger.Text = string.format("Visible amber %.0f / session change %+.0f. Changes are observed, not attributed to the hub.", wallet, wallet - ext.walletStart)
            end
            if ext.speedLease and not ext.speedMatches() then ui.speedText.Text = "Speed inputs or module instance changed externally. No automatic forcing; RESET or explicitly select a profile again." end
            if ext.leapBodies and not ext.leapMatches() then ui.leapText.Text = "Leap inputs or module instance changed externally. No automatic forcing; RESET or explicitly select a profile again." end
            if ext.checkpoints and now - ext.lastCheckpoint >= 60 and not ext.saving then
                ext.lastCheckpoint = now
                task.spawn(function() if state.alive and ext.checkpoints then ext.checkpoint() end end)
            end
        end
        ext.oldStop = ext.stop
        ext.stop = function()
            ext.oldStop()
            ext.stopSpeed(); ext.stopLeap()
            ext.restAssist, ext.restEpisode, ext.restIdleAt, ext.restPending = false, nil, nil, nil
            ui.restAssist.Text, ui.restAssist.BackgroundColor3 = "IDLE RECOVERY ASSIST: OFF", C.blue
            ext.claimStarting, ext.equipPending = false, nil
            ext.endClaims("Stopped. Requests already sent cannot be withdrawn; no more will be sent by this run.")
            ext.restoreSetting("calm"); ext.restoreSetting("perf")
            ui.calm.Text, ui.perf.Text = "CALM CAMERA: OFF", "NATIVE PERFORMANCE MODE: OFF"
        end


        -- These are explicit acceptance trials, not claims that server validation is absent.
        local g = {epoch = 0, data = {scope = "self-only explicit goal trials; no working grants presumed", trials = {}}}
        ext.goal = g
        g.record = function(kind, record)
            if not state.alive or state.updateFailed then say("Goal controls stopped after an update error. Rerun the loader before starting another trial.", true); return false end
            if #g.data.trials >= 32 then say("32 goal trials retained. Save the report and restart before adding more; no old results discarded.", true); return false end
            record.trial_kind, record.started_seconds = kind, math.max(0, os.clock() - state.born)
            g.data.trials[#g.data.trials + 1] = record
            return true
        end
        g.amberCard = card(livePage, "AMBER GOAL TRIALS", "Tests normal request protocols rather than changing the displayed wallet. Self gifts may be denied; one claimed-reward replay checks for duplicate credit. No repeated farming or automatic startup requests. All-account targets are unavailable.")
        g.amberCard.LayoutOrder = -100
        g.amount = new("TextBox", {Name = "GoalAmberAmount", Text = "1", PlaceholderText = "Positive amber amount, up to 1000000",
            ClearTextOnFocus = false, BackgroundColor3 = C.bg, TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 13,
            Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0}, g.amberCard)
        g.lookupButton = button(g.amberCard, "CHECK MY GIFT LOOKUP — NUMBER / TEXT", C.surface)
        g.giftAmberButton = button(g.amberCard, "TRY OWN AMBER GIFT — AMOUNT ABOVE", C.surface)
        g.replayButton = button(g.amberCard, "TEST ONE ALREADY-CLAIMED PLAY REWARD AGAIN", C.surface, 38)
        g.amberText = label(g.amberCard, "No goal requests sent. A reply or wallet change alone is not proof of a spendable grant.", 12, 72, C.muted)
        g.stopButton = button(g.amberCard, "STOP GOAL EXPERIMENTS", C.red)

        g.animalCard = card(animalPage, "ACTUAL RESTRICTED-ANIMAL REQUESTS", "Spawn trials require the normal menu and a fresh empty base save slot; they never select an occupied slot. They send one FeralSelect request without a purchase. The server may deny it. A successful result requires a matching live species and a new matching active-slot sync.")
        g.animalCard.LayoutOrder = -100
        g.spawnSnow = button(g.animalCard, "TRY SNOW LEOPARD NEW-SLOT SPAWN", C.surface)
        g.spawnPhanto = button(g.animalCard, "TRY PHANTOSUCHUS NEW-SLOT SPAWN", C.surface)
        g.buySnow = button(g.animalCard, "TRY SNOW LEOPARD BUY — EXPECTED 3000 AMBER", C.surface, 38)
        g.giftSnow = button(g.animalCard, "TRY OWN SNOW LEOPARD GIFT", C.surface)
        g.giftPhanto = button(g.animalCard, "TRY OWN PHANTOSUCHUS GIFT", C.surface)
        g.giftAll = button(g.animalCard, "TRY OWN ALL-ANIMAL GIFT", C.surface)
        g.animalText = label(g.animalCard, "No spawn or grant established. Return through the game's normal menu first; no automatic despawn, delete or save replacement is performed.", 12, 72, C.muted)

        g.healthCard = card(resourcePage, "SERVER REST-SIGNAL RECOVERY COMPARISON", "A different test from local HP writing: compares 8s normal, 10s with the native Rest=true packet, then 8s after Rest=false. Walk steadily throughout. Requires HP at or below 60%, adequate needs and no combat. Does not damage you or write HP. Do not press R or start native rest during the comparison.")
        g.healthCard.LayoutOrder = -120
        g.healthButton = button(g.healthCard, "RUN 26s SERVER-REST RECOVERY COMPARISON", C.surface, 38)
        g.restLoopButton = button(g.healthCard, "UNPROVEN SERVER REST LOOP: OFF", C.surface, 38)
        g.healthStop = button(g.healthCard, "STOP GOAL EXPERIMENTS", C.red)
        g.healthText = label(g.healthCard, "Not run. A higher observed rate is exploratory evidence, not proof of a permanent regen exploit.", 12, 72, C.muted)

        g.send = function(name, ...)
            local args = table.pack(...)
            if not state.alive then return false end
            if state.updateFailed and not (name == "WolfActions" and args[1] == "Rest" and args[2] == false) then
                say("Goal controls stopped after an update error. Rerun the loader.", true); return false
            end
            local remote = ReplicatedStorage:FindFirstChild(name)
            if not remote or not remote:IsA("RemoteEvent") then return false end
            local ok, detail = pcall(function() remote:FireServer(table.unpack(args, 1, args.n)) end)
            if not ok then failure("Goal native request", detail) end
            return ok
        end
        g.rest = function(enabled)
            return g.send("WolfActions", "Rest", enabled == true)
        end
        g.rpc = function(spec, callback)
            if not state.alive or state.updateFailed then say("Goal RPCs stopped after an update error. Rerun the loader.", true); return false end
            if g.rpcBusy then g.amberText.Text = "Own gift RPC still pending; no duplicate request sent."; return false end
            local remote = ReplicatedStorage:FindFirstChild("FeralGive")
            local ownId = player.UserId
            if not remote or not remote:IsA("RemoteFunction") or not Core.finite(ownId) or ownId <= 0 then g.amberText.Text = "Own gift interface unavailable."; return false end
            if spec.verb ~= "look" and spec.verb ~= "give" then return false end
            if spec.verb == "give" and not Core.goalGift(spec.kind, spec.value) then return false end
            g.rpcBusy = true
            local epoch = g.epoch
            task.delay(8, function()
                if state.alive and g.rpcBusy and epoch == g.epoch then g.amberText.Text = "Own gift RPC is still pending. It cannot be recalled; no automatic retry or further request sent." end
            end)
            task.spawn(function()
                local packed = table.pack(pcall(function()
                    if spec.verb == "look" then
                        local target = spec.text and tostring(ownId) or ownId
                        return remote:InvokeServer("look", target)
                    end
                    -- Fixed own-account target. Never accept an entered identity or arbitrary verb.
                    return remote:InvokeServer("give", ownId, spec.kind, spec.value)
                end))
                g.rpcBusy = false
                if not state.alive or epoch ~= g.epoch then return end
                callback(packed)
            end)
            return true
        end
        g.readOwn = function(textTarget, callback)
            return g.rpc({verb = "look", text = textTarget}, function(packed)
                local clean = Core.lookupReply(packed, player.UserId, "gift")
                g.data.own_lookup = clean
                g.data.own_lookup.target_format = textTarget and "text_self_id" or "numeric_self_id"
                ext.emit("goal_own_lookup", clean)
                callback(clean)
            end)
        end
        action(g.lookupButton, function()
            g.readOwn(false, function(first)
                if first.state == "own_lookup_returned" then g.amberText.Text = "Own numeric lookup verified; write permission remains unverified."
                else
                    g.readOwn(true, function(second)
                        g.amberText.Text = "Numeric lookup: " .. first.state .. "; text lookup: " .. second.state .. ". Neither outcome alone establishes gift permission."
                    end)
                end
            end)
        end)
        g.startGift = function(kind, value)
            local packet = Core.goalGift(kind, value)
            if not packet then g.amberText.Text = "Invalid gift. Use a positive integer up to 1000000 or a supported animal request."; return end
            if g.rpcBusy or g.giftWatch then g.amberText.Text = "A gift lookup/request/result watch is pending; no duplicate submitted."; return end
            local record = {kind = packet.kind, value = packet.value, state = "own_baseline_lookup_pending", own_target = true}
            if not g.record("gift", record) then return end
            g.data.gift = record
            if packet.kind == "animal" and packet.value ~= "*" then
                local known = ext.ownership and ext.ownership.owned[packet.value]
                if type(known) == "boolean" then record.ownership_listed_before = known else record.ownership_listed_before = "not_reported" end
            end
            g.amberText.Text = "Reading own baseline, then attempting one explicit self gift. Read access is not assumed to determine write access."
            local started = g.readOwn(false, function(before)
                record.saved_amber_before = before.saved_amber_snapshot
                record.visible_amber_before = Core.number(player:GetAttribute("Amber"), 0)
                record.state = "gift_request_pending"
                local sent = g.rpc({verb = "give", kind = packet.kind, value = packet.value}, function(packed)
                    record.reply = Core.goalGiftReply(packed)
                    record.state = record.reply.state
                    ext.emit("goal_self_gift_reply", {kind = record.kind, value = record.value, state = record.state})
                    g.amberText.Text = "Self gift: " .. record.state .. ". No credited balance or ownership inferred from this reply alone."
                    g.giftWatch = {record = record, at = os.clock()}
                    if record.reply.acknowledged then
                        g.readOwn(false, function(after)
                            record.saved_amber_after = after.saved_amber_snapshot
                            if kind == "amber" and Core.finite(record.saved_amber_before) and Core.finite(record.saved_amber_after)
                                and record.saved_amber_after >= record.saved_amber_before + packet.value then
                                record.state = "own_saved_balance_increase_observed_after_gift"
                                g.amberText.Text = "Own server lookup reports the expected balance increase after the gift response. Spending/persistence still needs a normal game transaction or rejoin."
                            end
                        end)
                    end
                end)
                if not sent then record.state = "gift_interface_unavailable" end
            end)
            if not started then record.state = "gift_interface_unavailable" end
        end
        action(g.giftAmberButton, function() g.startGift("amber", g.amount.Text) end)
        action(g.giftSnow, function() g.startGift("animal", "SnowLeopard") end)
        action(g.giftPhanto, function() g.startGift("animal", "Phantosuchus") end)
        action(g.giftAll, function() g.startGift("animal", "*") end)

        g.requestSlots = function(callback)
            local epoch, operation = g.epoch, g.spawn or g.buyPending
            cachedModule("SaveConfig", function(config)
                if not state.alive or epoch ~= g.epoch or (g.spawn ~= operation and g.buyPending ~= operation) then return end
                local count = config and config.SLOT_COUNT
                if not Core.finite(count) or count < 1 or count > 16 or count % 1 ~= 0 then callback(false); return end
                g.slotCount = count
                observeNativeReplies()
                callback(g.send("FeralSlots", "get"))
            end, "goal_slots")
        end
        g.startSpawn = function(species)
            if species ~= "SnowLeopard" and species ~= "Phantosuchus" then return end
            if g.spawn or g.buyPending then g.animalText.Text = "An animal request is pending; no duplicate submitted."; return end
            local char, hum = own()
            if char and (not hum or hum.Health > 0) then g.animalText.Text = "Return through the normal animal/slots menu first. A living/loading active animal is not replaced by this trial."; return end
            local record = {species = species, state = "fresh_slot_snapshot_pending", no_purchase = true}
            if not g.record("spawn", record) then return end
            local epoch = g.epoch
            g.spawn = {species = species, phase = "snapshot", at = os.clock(), originalCharacter = char}
            g.data.spawn = record
            g.animalText.Text = "Requesting a fresh own-slot snapshot. Only an empty base slot can be used."
            g.requestSlots(function(ok)
                if not state.alive or epoch ~= g.epoch or not g.spawn then return end
                if not ok then g.spawn = nil; g.data.spawn.state = "slot_interface_unavailable"; g.animalText.Text = "SaveConfig/slot interface unavailable; no spawn submitted." end
            end)
        end
        action(g.spawnSnow, function() g.startSpawn("SnowLeopard") end)
        action(g.spawnPhanto, function() g.startSpawn("Phantosuchus") end)
        action(g.buySnow, function()
            if g.buyPending or g.spawn then g.animalText.Text = "An animal request is pending."; return end
            local record = {species = "SnowLeopard", state = "client_price_check_pending"}
            if not g.record("buy", record) then return end
            g.data.buy = record
            local epoch = g.epoch
            g.buyPending = {phase = "config", at = os.clock()}
            cachedModule("ShopConfig", function(config)
                if not state.alive or epoch ~= g.epoch or not g.buyPending then return end
                local price = config and type(config.PRICES) == "table" and config.PRICES.SnowLeopard
                local amber = player:GetAttribute("Amber")
                if not Core.finite(price) or price <= 0 or price > 3000 or price % 1 ~= 0
                    or not Core.finite(amber) or amber < price then
                    g.buyPending = nil; record.state = "price_or_balance_check_failed"; g.animalText.Text = "Expected live client price (up to 3000) or sufficient amber unavailable. Nothing bought."; return
                end
                g.buyPending = {phase = "snapshot", at = os.clock(), price = price, before = amber}
                record.client_price, record.amber_before, record.state = price, amber, "fresh_ownership_snapshot_pending"
                g.requestSlots(function(ok)
                    if not state.alive or epoch ~= g.epoch or not g.buyPending then return end
                    if not ok then g.buyPending = nil; g.data.buy.state = "slot_interface_unavailable" end
                end)
            end, "goal_buy")
        end)

        action(g.replayButton, function()
            if g.replay or ext.claimBatch or ext.claimStarting then g.amberText.Text = "A reward operation is pending; no replay submitted."; return end
            if os.clock() - (g.lastReplay or -math.huge) < 60 then g.amberText.Text = "One replay trial per minute; no request submitted."; return end
            local record = {state = "config_pending", repeat_limit = 1}
            if not g.record("replay", record) then return end
            g.lastReplay = os.clock()
            g.replay = {phase = "config", at = os.clock()}
            g.data.replay = record
            local epoch = g.epoch
            cachedModule("RewardConfig", function(config)
                if not state.alive or epoch ~= g.epoch or not g.replay then return end
                if not config or config.ON ~= true or type(config.PLAYTIME) ~= "table" then
                    g.replay = nil; g.data.replay.state = "reward_config_unavailable"; return
                end
                g.replay.config, g.replay.phase, g.replay.at = config, "snapshot", os.clock()
                observeNativeReplies()
                g.amberText.Text = "Reading fresh reward state before choosing one already-claimed play tier."
                if not g.send("FeralRewards", "hello") then g.replay = nil; g.data.replay.state = "reward_interface_unavailable" end
            end, "goal_replay")
        end)

        g.finishHealth = function(reason)
            local trial = g.health
            if not trial then return end
            g.health = nil
            if trial.signalOwned and player.Character == trial.character then
                local restored = g.rest(false)
                g.data.health.restore_request_sent = restored
                trial.signalOwned = false
            end
            g.data.health.state = reason
            g.data.health.result = Core.goalRecoveryResult(g.data.health.phases)
            g.healthText.Text = "Recovery trial: " .. reason .. " / " .. g.data.health.result.state .. ". No HP writes or invulnerability."
            ext.emit("goal_recovery_finished", {state = reason, result = g.data.health.result})
        end
        action(g.healthButton, function()
            if g.health then g.healthText.Text = "Recovery comparison already running."; return end
            if g.restLoop then g.healthText.Text = "Stop the server-Rest loop before measuring a new baseline."; return end
            local char, hum, root = own()
            local context = ext.context(char, hum, root)
            if not char or not hum or not root or hum.Health <= 0 or hum.MaxHealth <= 0 or hum.Health > hum.MaxHealth * .6
                or context.combat or context.resting or (context.mode ~= "idle" and context.mode ~= "move" and context.mode ~= "sprint")
                or Core.number(context.hunger, 0) < 25 or Core.number(context.thirst, 0) < 25 then
                g.healthText.Text = "Requires a living animal at <=60% HP, hunger/thirst >=25, outside combat/water/flight/grabs and native rest. The tool never damages you."; return
            end
            local record = {state = "running", phases = {baseline = {}, signal = {}, after = {}}, writes_to_health = 0}
            if not g.record("recovery_comparison", record) then return end
            ext.restAssist, ext.restPending = false, nil
            ui.restAssist.Text, ui.restAssist.BackgroundColor3 = "IDLE RECOVERY ASSIST: OFF", C.blue
            g.data.health = record
            g.health = {character = char, phase = "baseline", phaseAt = os.clock(), started = os.clock(), lastSample = -math.huge, lastHealth = hum.Health}
            g.healthText.Text = "Baseline 8s. Walk steadily; normal health recovery is measured before sending anything."
        end)

        g.stopRestLoop = function(reason)
            local loop = g.restLoop
            if not loop then return end
            g.restLoop = nil
            if player.Character == loop.character then loop.record.restore_request_sent = g.rest(false) end
            loop.record.state = reason
            g.restLoopButton.Text, g.restLoopButton.BackgroundColor3 = "UNPROVEN SERVER REST LOOP: OFF", C.surface
        end
        action(g.restLoopButton, function()
            if g.restLoop then g.stopRestLoop("stopped"); return end
            if g.health then g.healthText.Text = "Finish or stop the comparison before starting the request loop."; return end
            local char, hum, root = own()
            local context = ext.context(char, hum, root)
            if not char or not hum or not root or hum.Health <= 0 or context.combat or context.resting
                or (context.mode ~= "idle" and context.mode ~= "move" and context.mode ~= "sprint") then
                g.healthText.Text = "Rest loop requires a living animal outside combat, water, grabs, flight and native rest."; return
            end
            local record = {state = "requesting_unproven", packets = 0, writes_to_health = 0, effectiveness = "not_established"}
            if not g.record("server_rest_loop", record) then return end
            ext.restAssist, ext.restPending = false, nil
            ui.restAssist.Text, ui.restAssist.BackgroundColor3 = "IDLE RECOVERY ASSIST: OFF", C.blue
            g.data.rest_loop, g.restLoop = record, {character = char, lastSend = os.clock(), record = record}
            record.packets = record.packets + 1
            if not g.rest(true) then g.stopRestLoop("send_failed"); return end
            g.restLoopButton.Text, g.restLoopButton.BackgroundColor3 = "UNPROVEN SERVER REST LOOP: ON", C.green
            g.healthText.Text = "Requesting server Rest=true once per 5s while mobile. Effectiveness is unconfirmed; combat/character changes stop it. No HP writes."
        end)

        g.previousReply = ext.onReply
        ext.onReply = function(remoteName, kind, payload, detail)
            g.previousReply(remoteName, kind, payload, detail)
            if remoteName == "FeralAmber" and kind == "gain" and Core.finite(payload) then
                -- Amount/time only. Reasons may contain other players' names and are discarded.
                g.data.last_gain_notice = {amount = payload, t = math.max(0, os.clock() - state.born)}
            elseif remoteName == "FeralSlots" and kind == "sync" then
                local clean = Core.goalSlots(payload, g.slotCount)
                if clean then
                    g.slots, g.slotsAt = clean, os.clock()
                    if g.spawn and g.spawn.phase == "snapshot" then
                        local trial = g.spawn
                        local char, hum = own()
                        local key = clean.empty[1]
                        if not key or (char and (not hum or hum.Health > 0)) then
                            g.spawn = nil; g.data.spawn.state = "no_empty_slot_or_active_animal"; g.animalText.Text = "No empty base slot, or a living animal is active. No spawn or overwrite submitted."
                        else
                            trial.phase, trial.key, trial.at = "result", key, os.clock()
                            g.data.spawn.state, g.data.spawn.empty_slot = "spawn_request_sent", key
                            g.animalText.Text = "Submitting one direct " .. trial.species .. " spawn into empty slot " .. key .. ". Waiting for character AND new slot sync."
                            ext.emit("goal_restricted_spawn_requested", {species = trial.species, empty_slot = key})
                            if not g.send("FeralSelect", trial.species, "Male", key, false, nil, nil) then g.spawn = nil; g.data.spawn.state = "spawn_send_failed" end
                        end
                    elseif g.spawn and g.spawn.phase == "result" then
                        local t = g.spawn
                        t.slotMatches = clean.active == t.key and clean.slots[t.key] ~= nil and clean.slots[t.key].species == t.species
                    end
                    if g.buyPending and g.buyPending.phase == "snapshot" then
                        local buy = g.buyPending
                        if clean.owned.SnowLeopard == true then
                            g.data.buy.state = "already_listed_owned_no_purchase"; g.buyPending = nil
                            g.animalText.Text = "Snow Leopard is already listed owned. No duplicate purchase submitted; spawn permission is separate."
                        else
                            buy.phase, buy.at = "result", os.clock()
                            g.data.buy.state = "native_buy_requested"
                            g.animalText.Text = "Sending normal Snow Leopard buy request. The server chooses the actual price and eligibility."
                            if not g.send("FeralSlots", "buy", "SnowLeopard") then g.buyPending = nil; g.data.buy.state = "buy_send_failed" end
                        end
                    elseif g.buyPending and g.buyPending.phase == "result" and clean.owned.SnowLeopard == true then
                        g.data.buy.state = "own_sync_lists_snow_leopard_owned_after_buy"
                        g.data.buy.amber_after = Core.number(player:GetAttribute("Amber"), 0)
                        g.animalText.Text = "New own sync lists Snow Leopard owned after the buy request. Actual spawn still requires its separate trial."
                        g.buyPending = nil
                    end
                    if g.giftWatch and g.giftWatch.record.kind == "animal" then
                        local value = g.giftWatch.record.value
                        if value ~= "*" and clean.owned[value] == true then g.giftWatch.record.ownership_listed_after = true end
                    end
                end
            elseif remoteName == "FeralSlots" and kind == "poor" and g.buyPending then
                g.data.buy.state = "native_poor_reply"; g.buyPending = nil
                g.animalText.Text = "Native poor reply received. No unlock or purchase established."
            elseif remoteName == "FeralRewards" and kind == "state" and g.replay then
                local clean, trial = Core.cleanRewards(payload), g.replay
                if clean and trial.phase == "snapshot" then
                    local index = nil
                    for i = 1, math.min(#trial.config.PLAYTIME, 16) do if clean.pc[i] == true then index = i; break end end
                    if not index then
                        g.replay = nil; g.data.replay.state = "no_claimed_play_tier_reported"
                        g.amberText.Text = "No already-claimed playtime tier was reported; no replay submitted."
                    else
                        trial.phase, trial.index, trial.at = "result", index, os.clock()
                        trial.before = Core.number(player:GetAttribute("Amber"), 0)
                        local record = g.data.replay
                        record.state, record.index, record.claimed_before, record.amber_before = "one_replay_sent", index, true, trial.before
                        g.amberText.Text = "Replaying exactly one server-reported already-claimed play tier. Waiting for matching paid, balance and fresh state observations."
                        if not g.send("FeralRewards", "claim", "play", index) then g.replay = nil; g.data.replay.state = "replay_send_failed" end
                    end
                elseif clean and trial.phase == "result" then trial.stateAfter = clean.pc[trial.index] == true end
            elseif remoteName == "FeralRewards" and kind == "paid" and g.replay and g.replay.phase == "result" then
                local index = (type(detail) == "number" or type(detail) == "string") and tonumber(detail) or nil
                if payload == "play" and index == g.replay.index then
                    g.replay.paid = true
                    g.data.replay.matching_paid_notice = true
                    g.send("FeralRewards", "hello")
                end
            end
        end
        g.previousTick = ext.tick
        ext.tick = function(char, hum, root, now)
            g.previousTick(char, hum, root, now)
            if g.restLoop then
                local loop, context = g.restLoop, ext.context(char, hum, root)
                if char ~= loop.character or not hum or not root or hum.Health <= 0 or context.combat or ext.restAssist
                    or (context.mode ~= "idle" and context.mode ~= "move" and context.mode ~= "sprint") then
                    g.stopRestLoop("combat_character_or_mode_stop")
                elseif now - loop.lastSend >= 5 then
                    loop.lastSend, loop.record.packets = now, loop.record.packets + 1
                    if not g.rest(true) then g.stopRestLoop("send_failed") end
                end
            end
            if g.spawn then
                local trial = g.spawn
                local sp = Core.knownSpecies(char and char:GetAttribute("Species"))
                if trial.phase == "result" and char ~= trial.originalCharacter and hum and root and hum.Health > 0 and sp ~= "other" then
                    g.data.spawn.observed_species = sp
                    if sp ~= trial.species then
                        g.data.spawn.state = "waiting_for_requested_species"
                        g.animalText.Text = "Current live species: " .. sp .. ". Still waiting for the requested species and new matching slot sync."
                    elseif trial.slotMatches then
                        g.data.spawn.state, g.data.spawn.observed_species = "live_species_and_new_active_slot_match", sp
                        g.animalText.Text = "Observed live " .. sp .. " AND a new matching active-slot sync. Rejoin persistence has not been tested."
                        ext.emit("goal_restricted_spawn_observed", {species = sp})
                        g.spawn = nil
                    end
                end
                if g.spawn and now - trial.at >= 12 then
                    g.data.spawn.state = "no_confirmed_spawn_in_window"; g.spawn = nil
                    g.animalText.Text = "No matching character + new slot sync within 12s. No rejection reason inferred and no retry sent."
                end
            end
            if g.buyPending and now - g.buyPending.at >= 12 then g.buyPending = nil; if g.data.buy then g.data.buy.state = "buy_result_unconfirmed" end; g.animalText.Text = "Buy result unconfirmed after 12s. No retry submitted." end
            if g.replay then
                local trial = g.replay
                local amber = Core.number(player:GetAttribute("Amber"), 0)
                if trial.phase == "result" and trial.paid and trial.stateAfter and amber > trial.before then
                    g.data.replay.state, g.data.replay.amber_after = "duplicate_award_candidate_observed", amber
                    g.data.replay.limit = "Matched notice and balance timing; other scripts/earnings can confound attribution. Persistence/spending untested."
                    g.amberText.Text = "A matching paid notice and balance increase followed the already-claimed replay. Candidate duplicate award, not yet causal/persistence proof. Save the report."
                    g.replay = nil
                elseif now - trial.at >= 8 then g.data.replay.state = "no_confirmed_duplicate_award_in_window"; g.replay = nil; g.amberText.Text = "No confirmed duplicate award within 8s. No automatic retry." end
            end
            if g.giftWatch then
                local watch, amber = g.giftWatch, player:GetAttribute("Amber")
                if watch.record.kind == "amber" and Core.finite(amber) then
                    watch.record.visible_amber_after = amber
                    watch.record.visible_increase_at_least_requested = amber >= watch.record.visible_amber_before + watch.record.value
                end
                if watch.record.kind == "animal" and watch.record.value ~= "*" and ext.ownership then
                    watch.record.ownership_listed_after = ext.ownership.owned[watch.record.value] == true
                end
                if now - watch.at >= 12 then g.giftWatch = nil end
            end
            if g.health then
                local trial, record = g.health, g.data.health
                local context = ext.context(char, hum, root)
                if char ~= trial.character or not hum or not root or hum.Health <= 0 then g.finishHealth("character_changed_or_dead"); return end
                if context.combat or hum.Health < trial.lastHealth - .001 or ext.restAssist
                    or (context.mode ~= "idle" and context.mode ~= "move" and context.mode ~= "sprint") then
                    g.finishHealth("combat_damage_or_native_assist_confounded"); return
                end
                trial.lastHealth = hum.Health
                if now - trial.lastSample >= .75 then
                    trial.lastSample = now
                    record.phases[trial.phase][#record.phases[trial.phase] + 1] = {t = now - trial.started, health = hum.Health,
                        health_max = hum.MaxHealth, horizontal_speed = context.horizontal_speed or 0,
                        resting_attribute = context.resting, combat = context.combat, hunger = context.hunger, thirst = context.thirst,
                        growth = context.growth, injury = context.injury, bleed = context.bleed, venom = context.venom}
                end
                local duration = trial.phase == "signal" and 10 or 8
                g.healthText.Text = trial.phase .. " / " .. string.format("%.1f", math.max(0, duration - (now - trial.phaseAt))) .. "s remaining. Walk steadily; HP is only observed."
                if now - trial.phaseAt >= duration then
                    if trial.phase == "baseline" then
                        trial.signalOwned = true
                        if not g.rest(true) then g.finishHealth("rest_true_send_failed"); return end
                        trial.phase, trial.phaseAt, trial.lastSample = "signal", now, -math.huge
                        record.rest_true_request_sent = true
                    elseif trial.phase == "signal" then
                        if not g.rest(false) then g.finishHealth("rest_false_send_failed"); return end
                        trial.signalOwned = false
                        trial.phase, trial.phaseAt, trial.lastSample = "after", now, -math.huge
                        record.restore_request_sent = true
                    else g.finishHealth("completed") end
                end
            end
        end
        g.stop = function()
            g.epoch = g.epoch + 1
            g.finishHealth("stopped")
            g.stopRestLoop("stopped")
            if g.spawn then g.data.spawn.state = "stopped_pending_result" end
            if g.replay then g.data.replay.state = "stopped_pending_result" end
            if g.buyPending and g.data.buy then g.data.buy.state = "stopped_pending_result" end
            if g.rpcBusy and g.data.gift then
                g.data.gift.stop_note = "RPC already pending; no further chained request. A write already submitted cannot be recalled."
                if g.data.gift.state == "own_baseline_lookup_pending" then g.data.gift.state = "stopped_before_gift_send"
                elseif g.data.gift.state == "gift_request_pending" then g.data.gift.state = "stopped_gift_result_unknown" end
            end
            g.spawn, g.replay, g.buyPending, g.giftWatch = nil, nil, nil, nil
            g.amberText.Text = "Goal operations stopped. Requests already sent cannot be recalled; no further chained request will be made."
        end
        action(g.stopButton, g.stop)
        action(g.healthStop, g.stop)
        g.previousStop = ext.stop
        ext.stop = function() g.stop(); g.previousStop() end

        ext.emit("hub_ready", {version = "1.4"})
    end

    local function stopExperiments()
        if state.ext then state.ext.stop() end
        stopStamina()
        stopLight()
        stopMenuPatch()
        resetLocalCoat()
        state.plan, state.travelEpoch = nil, state.travelEpoch + 1
    end
    action(stopAll, function() stopExperiments(); say("Experiments stopped. Owned settings restored; completed movement is not reversed.") end)
    local function shutdown(skipDestroy)
        if not state.alive then return end
        pcall(stopExperiments)
        if state.ext and state.ext.checkpoints then pcall(state.ext.checkpoint) end
        state.alive = false
        if state.ext then state.ext.detach() end
        clearAssetButtons()
        clearCoats()
        if state.cameraConnection then state.cameraConnection:Disconnect(); state.cameraConnection = nil end
        for _, connection in ipairs(state.connections) do connection:Disconnect() end
        table.clear(state.connections)
        if not skipDestroy and gui.Parent then gui:Destroy() end
    end
    startupCleanup = shutdown
    connect(shutdownEvent.Event, shutdown)
    action(close, shutdown)
    connect(gui.Destroying, function() shutdown(true) end)
    action(hide, function() panel.Visible, reopen.Visible = false, true end)
    action(reopen, function()
        panel.Position = UDim2.fromScale(0.5, 0.5)
        panel.Visible, reopen.Visible = true, false
    end)
    connect(UIS.InputBegan, function(input, processed)
        if not processed and not UIS:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.RightShift then
            panel.Visible = not panel.Visible
            reopen.Visible = not panel.Visible
            if panel.Visible then panel.Position = UDim2.fromScale(0.5, 0.5) end
        end
    end)
    local drag = nil
    connect(title.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = {start = input.Position, position = panel.Position}
        end
    end)
    connect(UIS.InputChanged, function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - drag.start
            panel.Position = UDim2.new(drag.position.X.Scale, drag.position.X.Offset + delta.X,
                drag.position.Y.Scale, drag.position.Y.Offset + delta.Y)
        end
    end)
    connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drag = nil end
    end)
    local function fit()
        local camera = workspace.CurrentCamera
        if camera then
            local view = camera.ViewportSize
            scale.Scale = math.clamp(math.min((view.X - 24) / 780, (view.Y - 70) / 594), 0.35, 1.1)
        end
    end
    local function bindCamera()
        if state.cameraConnection then state.cameraConnection:Disconnect(); state.cameraConnection = nil end
        local camera = workspace.CurrentCamera
        if camera then state.cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
        fit()
    end
    connect(workspace:GetPropertyChangedSignal("CurrentCamera"), bindCamera)
    bindCamera()
    connect(player.CharacterRemoving, function(char)
        if state.ext then state.ext.clearHealth(); state.ext.healthBinding = nil end
        releaseFlag(char)
        resetLocalCoat()
        state.plan, state.travelWatch, state.travelEpoch = nil, nil, state.travelEpoch + 1
        table.clear(state.samples)
    end)

    local function formatNumber(value)
        return Core.finite(value) and string.format("%.1f", value) or "—"
    end
    local function report()
        local char, hum = own()
        return table.concat({
            "FERAL FIELD HUB v1.4 — client status only",
            "PlaceId: 108901361810209",
            "Uptime seconds: " .. math.floor(os.clock() - state.born),
            "Species: " .. tostring(char and char:GetAttribute("Species") or "not spawned"),
            "Health: " .. formatNumber(hum and hum.Health) .. " / " .. formatNumber(hum and hum.MaxHealth),
            "Stamina: " .. formatNumber(char and char:GetAttribute("Stamina")) .. " / " .. formatNumber(char and char:GetAttribute("StaminaMax")),
            "Stamina tuning: " .. tostring(state.stamina),
            "Field result: v1.0 stamina reported working on Bear; local HP refill overwritten.",
            "Cached stamina tuning applied: " .. tostring(state.leases.stamina ~= nil),
            "Local HP writer: retired; no health writes in v1.4",
            "Health decreases observed: " .. state.healthDrops,
            "Stamina decreases observed: " .. state.staminaDrops .. " (decreases alone do not identify the writer)",
            "Native reward state seen: " .. tostring(state.rewardStateSeen),
            "Native reward paid notices: " .. state.rewardPaidNotices,
            "Recent server reply types: " .. table.concat(state.serverReplies, ", "),
            "Hidden card visibility patch: " .. tostring(state.leases.menu ~= nil),
            "Local coat trial: " .. tostring(state.coatLease ~= nil),
            "Field extension: " .. tostring(state.ext and state.ext.summary() or "not ready"),
            "Errors: " .. state.errors,
            "Last error: " .. tostring(state.lastError or "none"),
            "Module status: " .. state.moduleStatus,
            "Goal trials submit explicit requests; no working arbitrary amber, restricted spawn, owner grant or added HP regeneration is presumed.",
            "Opt-in writes include self gifts, one claimed-reward replay, empty-slot restricted spawn, Snow Leopard amber buy and Rest signals. No Roblox purchases, save restores or other-account requests.",
            "Only allowlisted own reply fields are retained. No server-only code, raw reply payloads, other players' data or credentials collected.",
        }, "\n")
    end
    action(copyReport, function()
        local copy = optional("setclipboard") or optional("toclipboard")
        if not copy then say("Clipboard API unavailable. Use SAVE HUB STATUS instead.", true); return end
        local ok, details = pcall(copy, report())
        if ok then say("Hub status copied.") else failure("Clipboard", details) end
    end)
    action(saveReport, function()
        local write = optional("writefile")
        if not write then say("writefile unavailable. The hub itself does not need file access.", true); return end
        local filename = "FERAL_Field_Hub_Status_" .. tostring(os.time()) .. ".txt"
        local ok, details = pcall(write, filename, report())
        if ok then say("Saved " .. filename .. " in the executor workspace; disk read-back is not verified.")
        else failure("Status file write", details) end
    end)
    startupPhase = "binding_live_updates"
    local lastChar, sampleAccumulator = nil, 0
    local function tick(dt)
        local char, hum, root = own()
        if char ~= lastChar then
            if lastChar then releaseFlag(lastChar) end
            table.clear(state.samples)
            lastChar = char
        end
        if state.stamina and char then flagCharacter(char) end
        sampleAccumulator = sampleAccumulator + dt
        if sampleAccumulator < 0.25 then return end
        sampleAccumulator = 0
        local now = os.clock()
        if state.ext then state.ext.tick(char, hum, root, now) end
        local stamina = char and char:GetAttribute("Stamina")
        local maximum = char and char:GetAttribute("StaminaMax")
        animalStats.Text = tostring(char and char:GetAttribute("Species") or "Animal menu / no character")
            .. "  /  " .. tostring(char and char:GetAttribute("AgeStage") or "stage unavailable")
        hpStats.Text = "HEALTH   " .. formatNumber(hum and hum.Health) .. " / " .. formatNumber(hum and hum.MaxHealth)
        staminaStats.Text = "STAMINA   " .. formatNumber(stamina) .. " / " .. formatNumber(maximum)
        local growth = char and char:GetAttribute("Growth")
        needsStats.Text = "Growth " .. (Core.finite(growth) and string.format("%.1f%%", growth * 100) or "—")
            .. "   Hunger " .. formatNumber(char and char:GetAttribute("Hunger"))
            .. "   Thirst " .. formatNumber(char and char:GetAttribute("Thirst"))
        if root then
            local p = root.Position
            movementStats.Text = string.format("Position %.0f, %.0f, %.0f   /   speed %.1f studs/s", p.X, p.Y, p.Z, root.AssemblyLinearVelocity.Magnitude)
            local camera = workspace.CurrentCamera
            local look = camera and camera.CFrame.LookVector or root.CFrame.LookVector
            local angle, direction, distance = Core.bearing(state.target.x - p.X, state.target.z - p.Z, look.X, look.Z)
            navText.Text = string.format("%.0f studs horizontally   /   %s   /   camera bearing %+.0f°", distance, direction, angle)
        else
            movementStats.Text, navText.Text = "Spawn an animal to see position.", "Spawn an animal for navigation."
        end
        walletText.Text = "Visible amber: " .. formatNumber(player:GetAttribute("Amber")) .. "  /  server spending power not modified"
        local lines = {}
        if char then
            for _, item in ipairs({{"FeralInjury", "Injury"}, {"FeralBleed", "Bleeding"}, {"FeralVenomAmt", "Venom"}}) do
                local value = char:GetAttribute(item[1])
                if Core.finite(value) and value > 0 then lines[#lines + 1] = item[2] .. ": " .. formatNumber(value) end
            end
            for _, item in ipairs({{"FeralThriveUntil", "Growth boost"}, {"FeralHobbledUntil", "Hobbled"}}) do
                local value = char:GetAttribute(item[1])
                local left = Core.finite(value) and value - workspace:GetServerTimeNow() or 0
                if left > 0 then lines[#lines + 1] = item[2] .. ": " .. math.ceil(left) .. "s remaining" end
            end
            for _, item in ipairs({{"FeralHomeTurf", "Home turf"}, {"FeralGrazing", "Grazing ground"}}) do
                local value = char:GetAttribute(item[1])
                if value and value ~= 0 and value ~= "" then lines[#lines + 1] = item[2] .. ": active attribute" end
            end
            if char:GetAttribute("WolfRest") then lines[#lines + 1] = "Resting" end
            local regrow = player:GetAttribute("FeralRegrowLeft")
            if Core.finite(regrow) and regrow > 0 then lines[#lines + 1] = "Regrowth allowance: " .. formatNumber(regrow) .. " (game units)" end
        end
        effectsText.Text = #lines > 0 and table.concat(lines, "\n") or "No supported active effect attributes observed. Other effects may exist."
        local samples = state.samples
        local hp = hum and hum.Health
        local previousSample = samples[#samples]
        if previousSample then
            if Core.finite(hp) and hp < previousSample.hp then state.healthDrops = state.healthDrops + 1 end
            if Core.finite(stamina) and stamina < previousSample.stamina then state.staminaDrops = state.staminaDrops + 1 end
        end
        samples[#samples + 1] = {at = now, hp = Core.number(hp, 0), stamina = Core.number(stamina, 0)}
        while #samples > 33 do table.remove(samples, 1) end
        local elapsed = now - samples[1].at
        if elapsed > 1 and hum and Core.finite(stamina) then
            rateStats.Text = string.format("Observed over %.1fs: HP %+.2f/s   stamina %+.2f/s. Growth, spending and damage may affect these readings.",
                elapsed, (hum.Health - samples[1].hp) / elapsed, (stamina - samples[1].stamina) / elapsed)
        end
        hpDetail.Text = "Health is observed only. Decreases observed: " .. state.healthDrops
            .. "; their cause is not identified by this count."
        if state.nativeRewardsText then
            local ready = player:GetAttribute("FeralRewardsReady")
            state.nativeRewardsText.Text = "Game reward-ready indicator: " .. tostring(ready == true)
                .. " / server state observed: " .. tostring(state.rewardStateSeen)
                .. " / paid notices received: " .. state.rewardPaidNotices
                .. ". Earned claims use server eligibility. This does not generate arbitrary amber."
        end
        local watch = state.travelWatch
        if watch and now - watch.at >= 4 then
            state.travelWatch = nil
            if char == watch.character and root and hum then
                local bodyCF = char:GetBoundingBox()
                local distance = (bodyCF.Position - watch.position).Magnitude
                travelText.Text = string.format("After 4s: %.1f studs from checked body centre; HP change %+.1f. Movement/health observations do not establish lasting safety or server approval.", distance, hum.Health - watch.health)
            else travelText.Text = "Character changed during travel observation; result unresolved." end
        end
    end
    connect(RunService.Heartbeat, function(dt)
        if not state.alive or state.updateFailed then return end
        local ok, details = pcall(tick, dt)
        if not ok then
            -- Stop mutating experiments after an unexpected update error.
            state.updateFailed = true
            stopExperiments()
            failure("Hub update", details)
        end
    end)
    refreshPortraits()
    local observerOK, observerError = pcall(observeNativeReplies)
    if not observerOK then failure("Native reply observer", observerError) end
    startupPhase = "ready"
    say("Ready. Goal trials are at the top of LIVE, ANIMALS and RESOURCES. Nothing is submitted until clicked. Right Shift hides; X stops/restores.")
end

local ok, startupError = pcall(run)
if not ok then
    if startupCleanup then pcall(startupCleanup) end
    local kind, line = Core.errorMeta(startupError)
    warn("[FERAL Hub] Startup failed / " .. startupPhase .. " / " .. kind .. " / source line " .. tostring(line or "unavailable"))
end
