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
    for _, tab in ipairs({ "Survival", "Combat", "Movement", "Vision", "Territory", "Hippo", "Test Features" }) do
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
