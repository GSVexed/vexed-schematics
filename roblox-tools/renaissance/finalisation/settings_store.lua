-- Pure settings storage; no Roblox services or gameplay dependencies.
local Store = {}
function Store.new(schema, paths, normalize, validate)
    local self = {}
    local function read(io, path)
        local ok, value = pcall(io.read, path)
        if ok and type(value) == 'table' then return value end
    end
    local function canonical(value)
        if not value or value.schema ~= schema then return false end
        local ok, valid = pcall(validate, value)
        return ok and valid == true
    end
    local function equal(a, b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= 'table' then return a == b end
        for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
        for k in pairs(b) do if a[k] == nil then return false end end
        return true
    end
    local function writeVerified(io, path, value)
        local ok, result = pcall(io.write, path, value)
        if not ok or result == false then return false, 'write failed' end
        local stored = read(io, path)
        if not canonical(stored) or not equal(value, stored) then
            return false, 'readback mismatch'
        end
        return true
    end
    function self.load(io)
        local primary = read(io, paths.primary)
        if canonical(primary) then return normalize(primary), 'loaded' end
        local backup = read(io, paths.backup)
        if canonical(backup) then return normalize(backup), 'recovered backup' end
        if paths.legacy and paths.validateLegacy then
            local old = read(io, paths.legacy)
            if old and paths.validateLegacy(old) then return normalize(old), 'migrated' end
        end
        return normalize(nil), 'defaults'
    end
    function self.save(io, value)
        local clean = normalize(value)
        if not canonical(clean) then return false, 'invalid normalized settings' end
        local old = read(io, paths.primary)
        -- Never replace a usable backup with a malformed primary.
        if canonical(old) then
            local ok, why = writeVerified(io, paths.backup, old)
            if not ok then return false, 'backup: ' .. why end
        end
        local ok, why = writeVerified(io, paths.primary, clean)
        if not ok then return false, 'primary: ' .. why end
        return true, 'saved'
    end
    return self
end
return Store
