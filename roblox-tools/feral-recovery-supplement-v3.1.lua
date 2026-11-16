-- FERAL Recovery Supplement v3.1 - MENU and IN-GAME capture controls.
-- Read-only game snapshot. Only this tool's UI and local export files are written.
-- No gameplay remote calls, hooks, arbitrary require(), hidden-property reads,
-- authentication APIs, chat history, or server-only source extraction.
-- Read README-recovery-v3.1.md. Syntax checking compiles but NEVER runs game code.

local CFG = {
    placeId = 108901361810209,
    version = "3.1",
    chunkBytes = 262144,
    sourceChunkBytes = 524288,
    maxBufferedBytes = 2097152,
    uploadPartBytes = 25165824,
    sourceDedupeMaxBytes = 131072,
    sourceDedupeMaxEntries = 20000,
    bytecodeCacheMaxBytes = 16777216,
    bytecodeCacheMaxSingleBytes = 131072,
    maxObjects = 300000,
    maxScripts = 150000,
    maxDepth = 512,
    maxSingleSourceBytes = 8388608,
    maxConfigurationJsonBytes = 1048576,
    maxDecodedConfigNodes = 100000,
    maxExportBytes = 536870912,
    maxMemoryGrowthMiB = 256,
    sourceTimeoutSeconds = 8,
    checkpointSeconds = 5,
    maxConsecutiveTimeouts = 3,
}
if game.PlaceId ~= CFG.placeId then
    warn("[FERAL v3.0] Wrong game. Expected PlaceId " .. CFG.placeId)
    return
end
local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local Collection = game:GetService("CollectionService")
local player = Players.LocalPlayer
if not player then warn("[FERAL v3.0] LocalPlayer unavailable."); return end
local playerGui = player:FindFirstChildOfClass("PlayerGui")
if not playerGui then warn("[FERAL v3.0] Join fully, then run the loader again."); return end
for _,name in ipairs({"FeralCompleteDiagnosticV30", "FeralCompleteDiagnosticV301", "FeralCompleteDiagnosticV302", "FeralCompleteDiagnosticV303", "FeralRecoverySupplementV31"}) do
    local previous = playerGui:FindFirstChild(name)
    if previous then
        -- These are only our diagnostic panels. Their Destroying handler requests
        -- a cooperative stop; existing export files are never removed.
        pcall(function() previous:Destroy() end)
    end
end
local function optional(fn) return type(fn) == "function" and fn or nil end
local executorEnvironment = nil
if optional(getgenv) then
    local ok,env = pcall(getgenv)
    if ok and type(env) == "table" then executorEnvironment = env end
end
local apiOrigins = {}
local function resolveApi(name,direct)
    if optional(direct) then apiOrigins[name] = "global"; return direct end
    if executorEnvironment then
        -- Inspect only named diagnostic capabilities, never enumerate environment data.
        local ok,fn = pcall(function() return executorEnvironment[name] end)
        if ok and optional(fn) then apiOrigins[name] = "executor_environment"; return fn end
    end
    apiOrigins[name] = "unavailable"
    return nil
end
local API = {
    write = resolveApi("writefile",writefile), read = resolveApi("readfile",readfile), mkdir = resolveApi("makefolder",makefolder),
    isfolder = resolveApi("isfolder",isfolder), isfile = resolveApi("isfile",isfile),
    decompile = resolveApi("decompile",decompile), clipboard = resolveApi("setclipboard",setclipboard) or resolveApi("toclipboard",toclipboard),
    loadedModules = resolveApi("getloadedmodules",getloadedmodules), scripts = resolveApi("getscripts",getscripts),
    compile = resolveApi("loadstring",loadstring),
    cancel = optional(task.cancel), defer = optional(task.defer), spawn = optional(task.spawn),
}
local D = {
    phase = "ready", started = os.clock(), startedUtc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    running = false, launched = false, startClicks = 0, startupStage = "waiting_for_start",
    startupStep = "Choose MENU CAPTURE or IN-GAME CAPTURE.", startupWarnings = {}, reportVisible = false,
    stop = false, paused = false, saveRequested = false, finished = false, closing = false,
    root = "", current = "Choose a capture for your current game state.", notice = "No scan has started yet.", lastCheckpoint = 0,
    inventoryComplete = false, sourcePassComplete = false, sourceAbortReason = nil,
    ids = {}, visited = {}, nextId = 0, scripts = {}, buckets = {{}, {}, {}, {}},
    streams = {}, catalogBuffer = {}, catalogBytes = 0, catalogs = {}, controls = {},
    bufferBytes = 0, checkpointNumber = 0, catalogNumber = 0, filesBytes = 0,
    metadataFolder = "UPLOAD_PART_000_METADATA", dataParts = {}, createdFolders = {},
    sourceCache = {},sourceCacheEntries = 0,
    bytecodeCache = {},bytecodeCacheBytes = 0,
    payloadCount = 0, verifiedCount = 0, unverifiedCount = 0, scriptRoots = {},
    classes = {}, sourceStates = {}, categories = {game = 0, platform = 0},
    c = {objects = 0, scripts = 0, eligible = 0, remotes = 0, values = 0,
        attributes = 0, propertyFailures = 0, attributeFailures = 0, childFailures = 0,
        readErrors = 0, writeErrors = 0, privacyRoots = 0, redactions = 0,
        sourceAttempted = 0, sourceExported = 0, sourceFailed = 0, sourceBytes = 0,
        sourceRedacted = 0, duplicates = 0, optionalApiFailures = 0, detachedOmitted = 0,
        configurations = 0, activeAnimationTracks = 0,sourceBodiesReused = 0,dispatchFallbacks = 0,
        bytecodeReused = 0,bytecodeCacheFailures = 0},
    limits = {}, otherIdentities = {}, privateRoots = {}, connections = {}, watchers = {},
    pendingDiscovered = 0, activeWorker = nil, sourceCursor = 0, memoryStart = 0,
}
function D.read(obj, key)
    local ok, value = pcall(function() return obj[key] end)
    return ok, value
end
function D.isa(obj, class)
    local ok, answer = pcall(function() return obj:IsA(class) end)
    return ok and answer
end
function D.memoryMiB()
    local ok, kb = pcall(gcinfo)
    return ok and type(kb) == "number" and kb / 1024 or nil
end
D.memoryStart = D.memoryMiB() or 0
function D.adler(text)
    local a, b = 1, 0
    for start = 1, #text, 4096 do
        local finish = math.min(start + 4095,#text)
        local i = start
        while i + 7 <= finish do
            local p1,p2,p3,p4,p5,p6,p7,p8 = string.byte(text,i,i + 7)
            b = b + 8*a + 8*p1 + 7*p2 + 6*p3 + 5*p4 + 4*p5 + 3*p6 + 2*p7 + p8
            a = a + p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8
            i = i + 8
        end
        for at = i,finish do
            a = a + string.byte(text, at)
            b = b + a
        end
        a, b = a % 65521, b % 65521
    end
    return string.format("%08x", b * 65536 + a)
end
function D.base64(text)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local out = {}
    for i = 1, #text, 3 do
        local a, b, c = string.byte(text, i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        out[#out + 1] = alphabet:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
            .. alphabet:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
            .. (b and alphabet:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "=")
            .. (c and alphabet:sub(n % 64 + 1, n % 64 + 1) or "=")
    end
    return table.concat(out)
end
function D.text(text)
    local ok, length = pcall(utf8.len, text)
    if ok and length then return text end
    return {encoding = "base64", bytes = #text, data = D.base64(text)}
end
function D.sensitiveKey(key)
    local k = tostring(key):lower():gsub("[^%w]", "")
    for _, word in ipairs({"password", "passwd", "secret", "cookie", "authorization", "credential",
        "accesstoken", "refreshtoken", "authtoken", "apikey", "privatekey", "sessionkey",
        "sessionid", "bearer", "csrf", "roblosecurity", "webhook"}) do
        if k:find(word, 1, true) then return true end
    end
    return k == "token" or k == "auth" or k == "email" or k == "phone"
end
function D.secretString(text)
    local low = text:lower()
    if low:find("roblosecurity", 1, true) or low:find("bearer ", 1, true)
        or low:find("begin private key", 1, true) or low:find("github_pat_", 1, true)
        or low:find("ghp_", 1, true) or low:find("discord.com/api/webhooks", 1, true)
        or low:find("sk%-[%w_%-][%w_%-][%w_%-][%w_%-][%w_%-]")
        or text:find("AKIA[A-Z0-9]+") or text:find("eyJ[%w_%-]+%.[%w_%-]+%.[%w_%-]+")
        or text:find("[%w_.+%-]+@[%w.%-]+%.[%a]+") then return true end
    for key in low:gmatch("([%w_%-]+)%s*[:=]") do
        if D.sensitiveKey(key) then return true end
    end
    -- Quoted JSON keys, credential URLs, and unknown long opaque strings.
    for key in low:gmatch('["\']([%w_%-]+)["\']%s*:') do
        if D.sensitiveKey(key) then return true end
    end
    if low:find("https?://") and (low:find("?", 1, true) or low:find("@", 1, true)) then return true end
    if #text >= 32 and text:match("^[%w+/=_%-]+$") and not text:match("^%d+$") then return true end
    return false
end
function D.redacted(reason, bytes)
    D.c.redactions = D.c.redactions + 1
    return {redacted = true, reason = reason, bytes = bytes}
end
function D.stringValue(value, key, freeText)
    if freeText and D.configString then
        local config,handled = D.configString(value,key or "")
        if handled then return config end
    end
    if D.sensitiveKey(key or "") or D.secretString(value) then
        return D.redacted("credential_or_personal_pattern", #value)
    end
    -- Arbitrary runtime prose may contain messages. Preserve identifiers, assets,
    -- numeric configuration strings and simple enum-like settings only.
    if freeText and not ((#value <= 160 and value:match("^[%w_%.%-%s,]+$"))
        or value:match("^rbxassetid://%d+$") or value:match("^rbxasset://[%w_/%-.]+$")) then
        return D.redacted("unclassified_runtime_string", #value)
    end
    return D.text(value)
end
function D.configString(text,key)
    local low = tostring(key):lower()
    if D.sensitiveKey(key) or not (low:find("config",1,true) or low:find("settings",1,true)
        or low:find("definition",1,true)) or not text:match("^%s*[%[{]") then return nil,false end
    if #text > CFG.maxConfigurationJsonBytes then
        return D.redacted("json_configuration_byte_limit",#text),true
    end
    local ok,decoded = pcall(function() return Http:JSONDecode(text) end)
    if not ok or type(decoded) ~= "table" then return nil,false end
    local nodes = 0
    local function scrub(value, field, depth)
        nodes = nodes + 1
        if depth > 32 or nodes > CFG.maxDecodedConfigNodes then
            return D.redacted("json_configuration_structure_limit")
        end
        if D.sensitiveKey(field) then return D.redacted("sensitive_configuration_field") end
        if type(value) ~= "table" then return D.value(value,field,true) end
        local result,index = {},0
        for k,v in pairs(value) do
            if nodes >= CFG.maxDecodedConfigNodes then
                local marker = D.redacted("json_configuration_structure_limit_remaining_fields")
                if type(k) == "number" then result[#result + 1] = marker
                else result["[remaining-fields-omitted]"] = marker end
                break
            end
            index = index + 1
            if type(k) == "string" and D.otherIdentities[k] then
                result["[other-player-entry-" .. index .. "]"] = D.redacted("other_player_configuration_entry")
            else
                local safeKey = type(k) == "string" and D.secretString(k) and ("[redacted-key-" .. index .. "]") or k
                result[safeKey] = scrub(v,tostring(k),depth + 1)
            end
        end
        return result
    end
    D.c.configurations = D.c.configurations + 1
    return {type = "json_configuration",decoded = scrub(decoded,key,0),original_bytes = #text,raw_string_omitted = true},true
end
function D.safeName(value)
    if value == player.Name then return "LocalPlayer" end
    if D.otherIdentities[value] or D.secretString(value) then return "[private-name]" end
    return value
end
function D.errorKind(message)
    -- Never persist arbitrary executor exception text (it can contain source or user data).
    local low = tostring(message):lower()
    if low:find("permission", 1, true) or low:find("security", 1, true) then return "permission_denied" end
    if low:find("not a valid member", 1, true) then return "property_unavailable" end
    if low:find("timeout", 1, true) then return "timeout" end
    if low:find("memory", 1, true) then return "memory_error" end
    if low:find("yield",1,true) then return "yield_not_supported_in_this_context" end
    if low:find("nil value",1,true) then return "missing_function_or_value" end
    return "api_error_details_withheld"
end
function D.startupReport()
    local lines = {
        "FERAL STARTUP REPORT v" .. CFG.version,
        "PlaceId: " .. tostring(game.PlaceId),
        "Phase: " .. D.phase .. " | launched: " .. tostring(D.launched) .. " | running: " .. tostring(D.running),
        "Start clicks: " .. D.startClicks,
        "Startup stage: " .. D.startupStage,
        "Startup step: " .. D.startupStep,
        "Failure code: " .. tostring(D.failureCode or "none"),
        "Runtime error kind: " .. tostring(D.runtimeErrorKind or "none"),
        "Diagnostic source line: " .. tostring(D.runtimeErrorLine or "unavailable"),
        "Folder: " .. (D.root ~= "" and D.root or "not created"),
        "Checkpoint created: " .. tostring(D.hasCheckpoint == true),
        "Objects: " .. D.c.objects .. " | scripts: " .. D.c.scripts .. " | write errors: " .. D.c.writeErrors,
        "Capabilities (presence only; file checks run after Start):",
    }
    for _,name in ipairs({"writefile","makefolder","readfile","isfolder","isfile","decompile",
        "getloadedmodules","getscripts","loadstring","setclipboard","toclipboard"}) do
        lines[#lines + 1] = "  " .. name .. ": " .. (apiOrigins[name] or "not_checked")
    end
    if D.lastWriteFailure then
        lines[#lines + 1] = "File failure: " .. D.lastWriteFailure.operation .. " / " .. D.lastWriteFailure.path .. " / " .. D.lastWriteFailure.reason
    end
    for _,warning in ipairs(D.startupWarnings) do lines[#lines + 1] = "UI compatibility: " .. warning end
    lines[#lines + 1] = "No gameplay values, remotes, private messages or credentials are included in this report."
    return table.concat(lines,"\n")
end
function D.safeRender(force)
    if not force and os.clock() - (D.lastRender or -1) < 0.15 then return end
    D.lastRender = os.clock()
    local ok,err = pcall(D.render)
    if not ok then
        D.renderError = D.errorKind(err)
        pcall(function()
            D.ui.status.Text = D.phase:upper()
            D.ui.current.Text = D.current
        end)
    end
end
function D.stage(stage,step)
    D.startupStage,D.startupStep,D.current = stage,step,step
    D.safeRender(true)
    task.wait()
end
function D.encode(value)
    local ok, text = pcall(function() return Http:JSONEncode(value) end)
    if not ok then error("JSON encoding failed; refusing an incomplete record", 0) end
    return text
end

-- All write paths are tool-generated relative paths; instance names never become filenames.
function D.mkdir(path)
    if API.isfolder then
        local ok, exists = pcall(API.isfolder, path)
        if ok and exists then return true end
    end
    local ok,result = pcall(API.mkdir, path)
    if ok and result ~= false then return true end
    if API.isfolder then
        local checked, exists = pcall(API.isfolder, path)
        return checked and exists
    end
    return false
end
function D.rawWrite(relative, body, knownChecksum)
    -- Every generated file is plain text data. No executable helper is exported,
    -- encoded for later execution, renamed or launched by this tool.
    if relative:sub(-4) ~= ".txt" then relative = relative .. ".txt" end
    local parent = relative:match("^(.*)/[^/]+$")
    if parent then
        local prefix = ""
        for component in parent:gmatch("[^/]+") do
            prefix = prefix == "" and component or (prefix .. "/" .. component)
            if not D.createdFolders[prefix] then
                if not D.mkdir(D.root .. "/" .. prefix) then
                    D.failureCode = "makefolder_failed"
                    error("Cannot create data folder: " .. prefix,0)
                end
                D.createdFolders[prefix] = true
            end
        end
    end
    local absolute = D.root .. "/" .. relative
    local ok, result = pcall(API.write, absolute, body)
    if not ok or result == false then
        D.c.writeErrors = D.c.writeErrors + 1
        D.lastWriteFailure = {path = relative,operation = "write",reason = D.errorKind(result)}
        error("File write failed: " .. relative, 0)
    end
    local verified = false
    if API.read then
        local readOk, stored = pcall(API.read, absolute)
        if not readOk or type(stored) ~= "string" or stored ~= body then
            D.c.writeErrors = D.c.writeErrors + 1
            D.lastWriteFailure = {path = relative,operation = "read_back",reason = "unreadable_or_byte_mismatch"}
            error("File read-back failed: " .. relative, 0)
        end
        verified = true
    end
    return {path = relative, bytes = #body, adler32 = knownChecksum or D.adler(body), read_back_verified = verified}
end
function D.metadataWrite(path,body)
    return D.rawWrite(D.metadataFolder .. "/" .. path,body)
end
function D.flushCatalog()
    if #D.catalogBuffer == 0 then return end
    D.catalogNumber = D.catalogNumber + 1
    local meta = D.metadataWrite(string.format("catalog/files_%05d.ndjson", D.catalogNumber), table.concat(D.catalogBuffer))
    D.catalogs[#D.catalogs + 1] = meta
    D.catalogBuffer, D.catalogBytes = {}, 0
end
function D.payload(path, body, knownChecksum)
    if D.filesBytes + #body > CFG.maxExportBytes then
        D.limits.export_bytes = true
        error("Export disk budget reached; completed files preserved", 0)
    end
    -- Separate upload folders can be zipped individually in Windows. The
    -- accounting includes a conservative per-file metadata/ZIP overhead charge.
    local cost = #body + 512 + 2 * #path
    local part = D.dataParts[#D.dataParts]
    if not part or (part.files > 0 and part.cost + cost > CFG.uploadPartBytes) then
        local number = #D.dataParts + 1
        part = {number = number,folder = string.format("UPLOAD_PART_%03d_DATA",number),
            files = 0,bytes = 0,cost = 0,oversize_single_file = false}
        D.dataParts[#D.dataParts + 1] = part
    end
    if cost > CFG.uploadPartBytes then part.oversize_single_file = true; D.limits.upload_part_large_record = true end
    local meta = D.rawWrite(part.folder .. "/" .. path, body,knownChecksum)
    part.files,part.bytes,part.cost = part.files + 1,part.bytes + #body,part.cost + cost
    D.filesBytes, D.payloadCount = D.filesBytes + #body, D.payloadCount + 1
    if meta.read_back_verified then D.verifiedCount = D.verifiedCount + 1
    else D.unverifiedCount = D.unverifiedCount + 1 end
    local line = D.encode(meta) .. "\n"
    D.catalogBuffer[#D.catalogBuffer + 1] = line
    D.catalogBytes = D.catalogBytes + #line
    if D.catalogBytes >= CFG.chunkBytes then D.flushCatalog() end
    return meta
end
function D.flushStream(name)
    local stream = D.streams[name]
    if not stream or #stream.lines == 0 then return end
    local number = stream.number + 1
    D.payload(name .. string.format("_%05d.ndjson", number), table.concat(stream.lines))
    D.bufferBytes = D.bufferBytes - stream.bytes
    stream.number, stream.lines, stream.bytes = number, {}, 0
end
function D.emit(name, record)
    local stream = D.streams[name]
    if not stream then stream = {number = 0, lines = {}, bytes = 0, records = 0}; D.streams[name] = stream end
    local line = D.encode(record) .. "\n"
    stream.lines[#stream.lines + 1] = line
    stream.bytes, stream.records = stream.bytes + #line, stream.records + 1
    D.bufferBytes = D.bufferBytes + #line
    if stream.bytes >= CFG.chunkBytes then D.flushStream(name) end
    if D.bufferBytes > CFG.maxBufferedBytes then
        local biggest, size = nil, 0
        for key, item in pairs(D.streams) do
            if item.bytes > size then biggest, size = key, item.bytes end
        end
        if biggest then D.flushStream(biggest) end
    end
end
function D.flushAll()
    for name in pairs(D.streams) do D.flushStream(name) end
    D.flushCatalog()
end
function D.log(stage, id, reason, extra)
    D.emit("logs/errors", {stage = stage, id = id, reason = reason, context = extra,
        elapsed_seconds = math.floor((os.clock() - D.started) * 100) / 100})
end
function D.id(obj)
    if not obj then return nil end
    if not D.ids[obj] then D.nextId = D.nextId + 1; D.ids[obj] = D.nextId end
    return D.ids[obj]
end
function D.addPrivate(root)
    if root then D.privateRoots[root] = true end
end
function D.private(obj)
    -- A hash lookup per ancestor avoids testing every player/character root for
    -- every object in a large server. Reparented references are checked as read.
    local cursor = obj
    for _ = 1,CFG.maxDepth + 4 do
        if cursor == D.gui then return "diagnostic_ui" end
        if D.privateRoots[cursor] then return "other_player" end
        local ok,parent = D.read(cursor,"Parent")
        if not ok then return "unreadable_ancestry" end
        if not parent then return nil end
        cursor = parent
    end
    return "unproven_ancestry_depth"
end
function D.value(value, key, freeText)
    local kind = typeof(value)
    if D.sensitiveKey(key or "") then return D.redacted("sensitive_field", kind == "string" and #value or nil) end
    if kind == "nil" then return {type = "nil"} end
    if kind == "string" then return D.stringValue(value, key, freeText) end
    if kind == "boolean" then return value end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return {type = "number", value = tostring(value)} end
        return value
    end
    if kind == "Instance" then
        if D.private(value) then return D.redacted("private_instance_reference") end
        return {type = kind, id = D.id(value)}
    end
    if kind == "Vector3" then return {type = kind, x = D.value(value.X), y = D.value(value.Y), z = D.value(value.Z)} end
    if kind == "Vector2" then return {type = kind, x = D.value(value.X), y = D.value(value.Y)} end
    if kind == "Color3" then return {type = kind, r = D.value(value.R), g = D.value(value.G), b = D.value(value.B)} end
    if kind == "UDim" then return {type = kind, scale = D.value(value.Scale), offset = D.value(value.Offset)} end
    if kind == "UDim2" then return {type = kind, x = D.value(value.X), y = D.value(value.Y)} end
    if kind == "CFrame" then
        local components = {value:GetComponents()}
        for i,component in ipairs(components) do components[i] = D.value(component) end
        return {type = kind, components = components}
    end
    if kind == "Rect" then return {type = kind, min = D.value(value.Min), max = D.value(value.Max)} end
    if kind == "NumberRange" then return {type = kind, min = D.value(value.Min), max = D.value(value.Max)} end
    if kind == "EnumItem" then return {type = kind, value = tostring(value)} end
    if kind == "BrickColor" then return {type = kind, number = value.Number, color = D.value(value.Color)} end
    if kind == "NumberSequence" or kind == "ColorSequence" then
        local points = {}
        for _, point in ipairs(value.Keypoints) do
            points[#points + 1] = {time = D.value(point.Time), value = D.value(point.Value),
                envelope = kind == "NumberSequence" and D.value(point.Envelope) or nil}
        end
        return {type = kind, keypoints = points}
    end
    if kind == "PhysicalProperties" then
        return {type = kind, density = value.Density, friction = value.Friction, elasticity = value.Elasticity,
            friction_weight = value.FrictionWeight, elasticity_weight = value.ElasticityWeight}
    end
    return {type = kind, representation = D.stringValue(tostring(value), key, true), representation_only = true}
end

-- Explicit property coverage. There is no supported universal runtime property
-- enumerator. Every failed allowlisted read is counted and recorded per instance.
D.properties = {
    Instance = {"Archivable"},
    BaseScript = {"Disabled", "Enabled"}, Script = {"RunContext"},
    BasePart = {"CFrame", "Size", "Anchored", "CanCollide", "CanTouch", "CanQuery", "Transparency",
        "Color", "Material", "MaterialVariant", "Massless", "AssemblyLinearVelocity", "AssemblyAngularVelocity",
        "AssemblyMass", "CustomPhysicalProperties", "CollisionGroup", "CastShadow"},
    Model = {"PrimaryPart", "WorldPivot", "ModelStreamingMode", "LevelOfDetail"},
    MeshPart = {"MeshId", "TextureID", "RenderFidelity", "CollisionFidelity"},
    SpecialMesh = {"MeshId", "TextureId", "MeshType", "Scale", "Offset", "VertexColor"},
    Decal = {"Texture", "Face", "Color3", "Transparency"},
    Texture = {"StudsPerTileU", "StudsPerTileV", "OffsetStudsU", "OffsetStudsV"},
    SurfaceAppearance = {"ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap", "AlphaMode"},
    Humanoid = {"Health", "MaxHealth", "WalkSpeed", "JumpPower", "JumpHeight", "UseJumpPower", "HipHeight",
        "MoveDirection", "FloorMaterial", "AutoRotate", "PlatformStand", "Sit", "RigType", "RootPart",
        "BreakJointsOnDeath", "RequiresNeck", "MaxSlopeAngle"},
    Animation = {"AnimationId"},
    AnimationTrack = {"Animation", "IsPlaying", "Length", "Looped", "Priority", "Speed", "TimePosition", "WeightCurrent", "WeightTarget"},
    Motor6D = {"Part0", "Part1", "C0", "C1", "Transform"},
    Attachment = {"CFrame", "WorldCFrame", "Axis", "SecondaryAxis", "Visible"},
    Constraint = {"Attachment0", "Attachment1", "Enabled", "Visible"},
    AlignPosition = {"MaxForce", "MaxVelocity", "Responsiveness", "Position", "Mode", "RigidityEnabled"},
    AlignOrientation = {"MaxTorque", "MaxAngularVelocity", "Responsiveness", "CFrame", "Mode", "RigidityEnabled"},
    LinearVelocity = {"VectorVelocity", "MaxForce", "RelativeTo", "VelocityConstraintMode"},
    VectorForce = {"Force", "RelativeTo", "ApplyAtCenterOfMass"},
    SpringConstraint = {"Stiffness", "Damping", "FreeLength", "LimitsEnabled", "MinLength", "MaxLength"},
    RopeConstraint = {"Length", "Thickness", "Restitution", "WinchEnabled"},
    BodyVelocity = {"Velocity", "MaxForce", "P"},
    BodyPosition = {"Position", "MaxForce", "P", "D"},
    BodyGyro = {"CFrame", "MaxTorque", "P", "D"},
    LayerCollector = {"Enabled", "ZIndexBehavior"},
    ScreenGui = {"DisplayOrder", "IgnoreGuiInset", "ResetOnSpawn", "ScreenInsets"},
    BillboardGui = {"Adornee", "Size", "StudsOffset", "MaxDistance", "AlwaysOnTop", "LightInfluence"},
    SurfaceGui = {"Adornee", "Face", "CanvasSize", "PixelsPerStud", "SizingMode", "AlwaysOnTop"},
    GuiObject = {"Visible", "Position", "Size", "AnchorPoint", "AbsolutePosition", "AbsoluteSize", "Rotation",
        "BackgroundColor3", "BackgroundTransparency", "LayoutOrder", "ZIndex", "Active", "AutomaticSize", "ClipsDescendants"},
    GuiButton = {"AutoButtonColor", "Modal", "Selected", "Selectable"},
    TextLabel = {"TextColor3", "TextSize", "FontFace", "TextScaled", "TextWrapped", "TextTransparency", "RichText"},
    TextButton = {"TextColor3", "TextSize", "FontFace", "TextScaled", "TextWrapped", "RichText"},
    TextBox = {"TextColor3", "TextSize", "FontFace", "MultiLine", "ClearTextOnFocus", "TextEditable"},
    ImageLabel = {"Image", "ImageColor3", "ImageTransparency", "ScaleType", "SliceCenter", "ImageRectOffset", "ImageRectSize"},
    ImageButton = {"Image", "ImageColor3", "ImageTransparency", "ScaleType", "ImageRectOffset", "ImageRectSize"},
    ScrollingFrame = {"CanvasSize", "CanvasPosition", "AbsoluteCanvasSize", "AutomaticCanvasSize", "ScrollingDirection", "ScrollBarThickness"},
    UIListLayout = {"FillDirection", "SortOrder", "Padding", "HorizontalAlignment", "VerticalAlignment"},
    UIGridLayout = {"CellSize", "CellPadding", "FillDirection", "SortOrder", "FillDirectionMaxCells"},
    UIPadding = {"PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight"},
    UICorner = {"CornerRadius"}, UIStroke = {"Color", "Thickness", "Transparency", "Enabled"},
    UIGradient = {"Color", "Transparency", "Offset", "Rotation", "Enabled"}, UIScale = {"Scale"},
    UISizeConstraint = {"MaxSize", "MinSize"}, UIAspectRatioConstraint = {"AspectRatio", "AspectType", "DominantAxis"},
    Camera = {"CFrame", "Focus", "FieldOfView", "CameraType", "CameraSubject", "ViewportSize", "HeadLocked"},
    Sound = {"SoundId", "Volume", "PlaybackSpeed", "Looped", "Playing", "TimeLength", "TimePosition", "RollOffMaxDistance", "RollOffMinDistance", "SoundGroup"},
    SoundGroup = {"Volume"},
    SoundService = {"AmbientReverb", "DistanceFactor", "DopplerScale", "RolloffScale", "RespectFilteringEnabled"},
    ParticleEmitter = {"Texture", "Enabled", "Rate", "Lifetime", "Speed", "Color", "Size", "Transparency", "LightEmission", "Acceleration", "Drag"},
    Beam = {"Texture", "Attachment0", "Attachment1", "Enabled", "Color", "Width0", "Width1", "Transparency"},
    Trail = {"Texture", "Attachment0", "Attachment1", "Enabled", "Color", "Lifetime", "Transparency"},
    Light = {"Enabled", "Color", "Brightness", "Shadows"}, PointLight = {"Range"}, SpotLight = {"Range", "Angle", "Face"},
    ProximityPrompt = {"Enabled", "MaxActivationDistance", "HoldDuration", "RequiresLineOfSight", "KeyboardKeyCode", "GamepadKeyCode", "Style"},
    ClickDetector = {"MaxActivationDistance", "CursorIcon"},
    Tool = {"Enabled", "RequiresHandle", "CanBeDropped", "Grip", "TextureId", "ManualActivationOnly"},
    Workspace = {"Gravity", "StreamingEnabled", "StreamingMinRadius", "StreamingTargetRadius", "CurrentCamera", "FallenPartsDestroyHeight", "GlobalWind"},
    Lighting = {"ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "FogStart", "FogEnd", "FogColor", "GlobalShadows", "ExposureCompensation", "GeographicLatitude"},
    Atmosphere = {"Density", "Offset", "Color", "Decay", "Glare", "Haze"},
    Sky = {"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId", "StarCount"},
    PostEffect = {"Enabled"}, ColorCorrectionEffect = {"Brightness", "Contrast", "Saturation", "TintColor"},
    BlurEffect = {"Size"}, BloomEffect = {"Intensity", "Size", "Threshold"},
    Terrain = {"WaterColor", "WaterReflectance", "WaterTransparency", "WaterWaveSize", "WaterWaveSpeed", "Decoration"},
    StarterPlayer = {"CharacterWalkSpeed", "CharacterJumpPower", "CharacterJumpHeight", "CharacterUseJumpPower", "CameraMinZoomDistance", "CameraMaxZoomDistance", "EnableMouseLockOption"},
    Player = {"CameraMode", "CameraMinZoomDistance", "CameraMaxZoomDistance", "Character"},
    LocalizationTable = {"SourceLocaleId"},
}
D.propertyCache = {}
function D.keysFor(obj, class)
    if D.propertyCache[class] then return D.propertyCache[class] end
    local keys, used = {}, {}
    for base, properties in pairs(D.properties) do
        if base == class or D.isa(obj, base) then
            for _, key in ipairs(properties) do
                if not used[key] then used[key] = true; keys[#keys + 1] = key end
            end
        end
    end
    table.sort(keys)
    D.propertyCache[class] = keys
    return keys
end
D.assetKeys = {AnimationId = true, MeshId = true, TextureID = true, TextureId = true, Texture = true,
    Image = true, SoundId = true, ColorMap = true, MetalnessMap = true, NormalMap = true, RoughnessMap = true,
    SkyboxBk = true, SkyboxDn = true, SkyboxFt = true, SkyboxLf = true, SkyboxRt = true, SkyboxUp = true,
    SunTextureId = true, MoonTextureId = true, CursorIcon = true}
function D.getProperties(obj, class, id, category, restricted)
    local props, failed = {}, {}
    if restricted then return props, failed end
    for _, key in ipairs(D.keysFor(obj, class)) do
        local ok, value = D.read(obj, key)
        if ok then
            props[key] = D.value(value, key, false)
            if D.assetKeys[key] and type(value) == "string" and #value > 0 then
                D.emit("assets/" .. category, {id = id, property = key, reference = props[key]})
            end
        else
            D.c.propertyFailures = D.c.propertyFailures + 1
            failed[#failed + 1] = {property = key, reason = D.errorKind(value)}
        end
    end
    if #failed > 0 then D.log("properties", id, "allowlisted_reads_failed", failed) end
    return props, failed
end
function D.activeAnimations(obj,id,category)
    local ok,tracks = pcall(function() return obj:GetPlayingAnimationTracks() end)
    if not ok or type(tracks) ~= "table" then
        D.c.readErrors = D.c.readErrors + 1; D.log("animations",id,"playing_tracks_unavailable"); return
    end
    for _,track in ipairs(tracks) do
        local trackId = D.id(track)
        local props,failed = D.getProperties(track,"AnimationTrack",trackId,category,false)
        local valid,animation = D.read(track,"Animation")
        local asset = nil
        if valid and animation then
            local readable,reference = D.read(animation,"AnimationId")
            if readable then asset = D.value(reference,"AnimationId",false) end
        end
        D.c.activeAnimationTracks = D.c.activeAnimationTracks + 1
        D.emit("assets/" .. category,{kind = "active_animation_track",animator_id = id,track_id = trackId,
            properties = props,failed_properties = failed,animation_reference = asset,may_be_unparented = true})
    end
end

-- SOURCE_PRIVACY_FILTER: strings with credential context/patterns are replaced;
-- all comments are omitted. Sources are labelled as privacy-filtered reconstructions.
function D.filterSource(source)
    local out, at, n, redactions, hasCode = {}, 1, #source, 0, false
    local function longEnd(position)
        if source:sub(position,position) ~= "[" then return nil end
        local last = position + 1
        while source:sub(last,last) == "=" do last = last + 1 end
        if source:sub(last,last) ~= "[" then return nil end
        local equals = source:sub(position + 1,last - 1)
        local opening = last - position + 1
        local close = "]" .. equals .. "]"
        local finish = source:find(close, position + opening, true)
        return finish and finish + #close - 1 or n, opening, finish
    end
    while at <= n do
        local char, nextTwo = source:sub(at, at), source:sub(at, at + 1)
        if nextTwo == "--" then
            local finish = longEnd(at + 2)
            if not finish then finish = (source:find("\n", at + 2, true) or n + 1) - 1 end
            local removed = source:sub(at, finish)
            local _, newlines = removed:gsub("\n", "")
            out[#out + 1] = "--[[comment omitted]]" .. string.rep("\n", newlines)
            at, redactions = finish + 1, redactions + 1
        elseif char == '"' or char == "'" then
            hasCode = true
            local finish, escaped = at + 1, false
            while finish <= n do
                local c = source:sub(finish, finish)
                if not escaped and c == char then break end
                if not escaped and c == "\\" then escaped = true else escaped = false end
                finish = finish + 1
            end
            finish = math.min(finish, n)
            local literal = source:sub(at + 1, finish - 1)
            local context = source:sub(math.max(1, at - 100), at - 1):match("([^\n]*)$") or ""
            local risky = D.secretString(literal) or D.sensitiveKey(context)
            -- Escaped string bytes cannot be reliably inspected without evaluating code.
            if literal:find("\\%d") or literal:find("\\[xu]") then risky = true end
            out[#out + 1] = risky and (char .. "[REDACTED]" .. char) or source:sub(at, finish)
            if risky then redactions = redactions + 1 end
            at = finish + 1
        elseif char == "[" then
            hasCode = true
            local finish, opening, closing = longEnd(at)
            if finish then
                local context = source:sub(math.max(1, at - 100), at - 1):match("([^\n]*)$") or ""
                local literal = source:sub(at + opening, (closing or n + 1) - 1)
                if D.secretString(literal) or D.sensitiveKey(context) then
                    out[#out + 1] = '"[REDACTED]"'; redactions = redactions + 1
                else out[#out + 1] = source:sub(at, finish) end
                at = finish + 1
            else out[#out + 1] = char; at = at + 1 end
        else
            -- Copy code in runs, avoiding one table entry per source byte.
            local finish = source:find("[%[\"'%-]", at + 1) or n + 1
            local run = source:sub(at,finish - 1)
            if run:find("%S") then hasCode = true end
            out[#out + 1] = run
            at = finish
        end
    end
    return table.concat(out), redactions, hasCode
end


function D.control(path, body)
    D.controls[path] = D.metadataWrite(path,body)
end
function D.partList()
    local list = {{number = 0,folder = D.metadataFolder,kind = "metadata"}}
    for _,part in ipairs(D.dataParts) do
        list[#list + 1] = {number = part.number,folder = part.folder,kind = "data",
            payload_files = part.files,payload_bytes = part.bytes,
            accounted_bytes = part.cost,oversize_single_file = part.oversize_single_file}
    end
    return list
end
function D.writePartIndexes()
    local parts = D.partList()
    for _,part in ipairs(parts) do
        D.rawWrite(part.folder .. "/UPLOAD_PART.json",D.encode({
            schema = "feral-upload-folder/3.1",session_id = D.session,
            part_number = part.number,total_parts = #parts,folder = part.folder,kind = part.kind,
            manifest_phase = D.phase,checkpoint = D.checkpointNumber,
            root_relative_prefix = part.folder,
            master_manifest = D.metadataFolder .. "/manifest.json.txt",
            advisory = true,
            notice = "Upload every part including metadata part 000. The selected master manifest and hashed catalogs are authoritative."}))
    end
end
function D.checkpoint()
    D.flushAll()
    D.checkpointNumber = D.checkpointNumber + 1
    local summary = D.summary()
    -- Prior manifests must never point at an overwritten mutable summary.
    D.controls.summary = D.metadataWrite(string.format("checkpoints/SUMMARY_%05d.txt",D.checkpointNumber),summary)
    D.metadataWrite("SUMMARY.txt",summary)
    D.writePartIndexes()
    local body = D.encode(D.manifest())
    -- Manifests cannot contain their own checksum. They describe all payloads and controls.
    D.metadataWrite(string.format("checkpoints/manifest_%05d.json", D.checkpointNumber),body)
    D.metadataWrite("manifest.json",body)
    D.hasCheckpoint = true
    D.lastCheckpoint, D.saveRequested = os.clock(), false
end
function D.cooperate(force)
    D.safeRender(false)
    if force or os.clock() - (D.lastYield or 0) > 0.008 then
        task.wait()
        D.lastYield = os.clock()
    end
    if D.saveRequested or os.clock() - D.lastCheckpoint >= CFG.checkpointSeconds then D.checkpoint() end
    local pauseBegin = os.clock()
    while D.paused and not D.stop do
        D.safeRender(false)
        if D.saveRequested or os.clock() - D.lastCheckpoint >= CFG.checkpointSeconds then D.checkpoint() end
        task.wait(0.15)
    end
    D.pausedSeconds = (D.pausedSeconds or 0) + (os.clock() - pauseBegin)
    local memory = D.memoryMiB()
    if memory and memory - D.memoryStart > CFG.maxMemoryGrowthMiB then
        D.limits.memory_growth = true; D.stop = true; D.sourceAbortReason = "memory_growth_limit"
    end
    return not D.stop
end

function D.refreshPrivacy()
    local ok, list = pcall(function() return Players:GetPlayers() end)
    if not ok then error("Cannot identify other player roots safely; inventory not started.",0) end
    for _, other in ipairs(list) do
        if other ~= player then
            D.addPrivate(other)
            for _, key in ipairs({"Name", "DisplayName", "UserId"}) do
                local valid, value = D.read(other,key)
                if valid and value ~= nil then D.otherIdentities[tostring(value)] = true end
            end
            local valid, char = D.read(other,"Character")
            if valid and char then D.addPrivate(char) end
        end
    end
end
function D.category(obj, inherited, name)
    if inherited == "platform" then return inherited end
    if name == "CoreGui" or name == "CorePackages" or name == "RobloxReplicatedStorage"
        or name == "RobloxReplicatedScriptStorage" or name == "PlayerModule" or name == "ChatScript" then return "platform" end
    return "game"
end
function D.focus(text)
    local low = text:lower()
    for _, word in ipairs({"stamina", "health", "regen", "bleed", "damage", "feed", "growth", "combat",
        "sprint", "burst", "latch", "hunger", "thirst", "animal", "species", "ability", "movement", "rest", "config"}) do
        if low:find(word,1,true) then return true end
    end
    return false
end
function D.scriptType(obj, class)
    if class == "LocalScript" or class == "ModuleScript" then return class, true end
    if class == "Script" then
        local ok, run = D.read(obj,"RunContext")
        if ok and tostring(run) == "Enum.RunContext.Client" then return "ClientScript",true end
        return "ServerOrUnknownScript",false
    end
    return nil,false
end
function D.sourceResult(entry, status, details)
    if entry.terminal then return end
    local result = details or {}
    result.id, result.status, result.category = entry.id,status,entry.category
    result.path = D.text(entry.path)
    D.emit("source-results/" .. entry.category,result)
    entry.terminal = true
    D.sourceStates[status] = (D.sourceStates[status] or 0) + 1
    if entry.eligible then D.sourceTerminal = (D.sourceTerminal or 0) + 1 end
end
function D.inspect(obj, frame)
    local id = D.id(obj)
    local classOk, class = D.read(obj,"ClassName")
    if not classOk or type(class) ~= "string" then
        D.c.readErrors = D.c.readErrors + 1; D.log("instance",id,"class_unavailable"); return
    end
    local nameOk, name = D.read(obj,"Name")
    name = nameOk and tostring(name) or "[unreadable-name]"
    local private = D.private(obj)
    local low = name:lower():gsub("[^%w]", "")
    if private == "diagnostic_ui" then return "omit" end
    if private or (obj ~= player and D.otherIdentities[name])
        or low == "profiles" or low == "playerdata" or low == "userdata"
        or low == "privatemessages" or low == "authdata" then
        D.c.privacyRoots = D.c.privacyRoots + 1
        D.emit("logs/exclusions", {id = id,parent_id = frame.parentId,reason = "privacy_subtree",class = class, descendants_not_enumerated = true})
        return "omit"
    end
    local scriptType, eligible = D.scriptType(obj,class)
    local category = D.category(obj,frame.category,name)
    local safeName = D.safeName(name)
    local restricted = frame.restricted or class == "TextChatMessage" or class == "TextSource"
        or class == "TextChannel" or D.sensitiveKey(name)
        or ((low == "messages" or low == "chatlog" or low == "mailbox" or low == "directmessages") and not scriptType)
    -- UI content is never read; anonymise dynamic chat-node names as well.
    local chatTree = frame.chatTree or (category == "platform" and (low == "experiencechat" or low == "bubblechat" or low == "chat"))
    if (restricted or chatTree) and not scriptType then safeName = "[private-node]" end
    local path = frame.path .. "/" .. safeName:gsub("~","~0"):gsub("/","~1")
    if obj == game then path = "game" end
    D.c.objects = D.c.objects + 1
    D.categories[category] = D.categories[category] + 1
    D.classes[class] = (D.classes[class] or 0) + 1
    local attrs, attrFailure, tags = {},nil,{}
    if not restricted and not chatTree then
        local ok, values = pcall(function() return obj:GetAttributes() end)
        if ok and type(values) == "table" then
            for key,value in pairs(values) do
                local safeKey = D.secretString(key) and "[redacted-key-" .. tostring(D.c.attributes + 1) .. "]" or key
                attrs[safeKey] = D.value(value,key,true)
                D.c.attributes = D.c.attributes + 1
                D.emit("attributes/" .. category,{id = id,key = D.text(safeKey),value = attrs[safeKey]})
            end
        else
            D.c.attributeFailures = D.c.attributeFailures + 1
            attrFailure = "attributes_unavailable"; D.log("attributes",id,attrFailure)
        end
        local tagOk, found = pcall(function() return Collection:GetTags(obj) end)
        if tagOk then for _, tag in ipairs(found) do tags[#tags + 1] = D.stringValue(tag,"tag",true) end
        else D.c.readErrors = D.c.readErrors + 1; D.log("tags",id,"tags_unavailable") end
    end
    local props, failed = D.getProperties(obj,class,id,category,restricted or chatTree)
    if not restricted and not chatTree and class == "Animator" then D.activeAnimations(obj,id,category) end
    if not restricted and not chatTree and class == "Humanoid" then
        local ok,state = pcall(function() return obj:GetState() end)
        if ok then props.ObservedState = D.value(state)
        else D.c.readErrors = D.c.readErrors + 1; D.log("humanoid_state",id,"state_unavailable") end
    end
    local value = nil
    if D.isa(obj,"ValueBase") then
        D.c.values = D.c.values + 1
        if restricted or chatTree then value = D.redacted("private_runtime_branch")
        else
            local ok, raw = D.read(obj,"Value")
            if ok then value = D.value(raw,name,true)
            else value = {unavailable = true}; D.c.readErrors = D.c.readErrors + 1; D.log("value",id,"value_unavailable") end
        end
        D.emit("values/" .. category,{id = id,path = D.text(path),value = value})
    end
    local record = {id = id,parent_id = frame.parentId,name = D.text(safeName),class = class,
        path = D.text(path),category = category,attributes = attrs,attribute_error = attrFailure,
        tags = tags,properties = props,failed_properties = failed,value = value,
        private_payload_omitted = (restricted or chatTree) and true or nil,
        observed_seconds = math.floor((os.clock() - D.started) * 100) / 100}
    D.emit("objects/" .. category,record)
    if D.isa(obj,"GuiBase2d") or D.isa(obj,"UIComponent") then
        D.emit("ui/" .. category,{id = id,path = D.text(path),class = class,properties = props,text_content_omitted = true})
    end
    if class == "RemoteEvent" or class == "RemoteFunction" or class == "UnreliableRemoteEvent"
        or class == "BindableEvent" or class == "BindableFunction" then
        D.c.remotes = D.c.remotes + 1
        D.emit("remotes/" .. category,{id = id,path = D.text(path),class = class,attributes = attrs,
            invoked = false, traffic_captured = false})
    end
    if D.focus(path) or next(attrs) ~= nil then
        D.emit("focus/" .. category,{id = id,path = D.text(path),class = class,attributes = attrs,value = value})
    end
    if scriptType then
        D.c.scripts = D.c.scripts + 1
        local root = frame.service or safeName
        D.scriptRoots[root] = (D.scriptRoots[root] or 0) + 1
        local entry = {instance = obj,id = id,path = path,category = category,eligible = eligible}
        D.scripts[#D.scripts + 1] = entry
        D.emit("scripts/" .. category,{id = id,path = D.text(path),class = class,script_type = scriptType,
            properties = props,source_eligible = eligible,root_service = root,origin_is_heuristic = true})
        if eligible then
            D.c.eligible = D.c.eligible + 1
            local bucket = category == "game" and (D.focus(path) and 1 or 2) or (D.focus(path) and 3 or 4)
            D.buckets[bucket][#D.buckets[bucket] + 1] = entry
        else D.sourceResult(entry,"not_client_source",{reason = "server_or_unknown_runcontext_not_attempted"}) end
        if #D.scripts >= CFG.maxScripts then D.limits.script_count = true; D.stop = true end
    end
    return {path = path,category = category,restricted = restricted,chatTree = chatTree,
        parentId = id,service = frame.service or (obj ~= game and safeName or nil)}
end

function D.walk(root, rootFrame)
    local stack = {{obj = root,frame = rootFrame,depth = 0}}
    D.pendingDiscovered = 1
    while #stack > 0 do
        if not D.cooperate(false) then break end
        local node = stack[#stack]
        stack[#stack] = nil
        if node.entered then
            if node.index <= #node.children then
                local child = node.children[node.index]
                node.index = node.index + 1
                stack[#stack + 1] = node
                stack[#stack + 1] = {obj = child,frame = node.childFrame,depth = node.depth + 1}
            end
        elseif not D.visited[node.obj] then
            D.visited[node.obj] = true
            if D.c.objects >= CFG.maxObjects then D.limits.object_count = true; D.stop = true; break end
            local childFrame = D.inspect(node.obj,node.frame)
            D.current = "Inventory: " .. tostring(D.c.objects) .. " visited"
            if type(childFrame) == "table" then
                if node.depth >= CFG.maxDepth then
                    D.limits.hierarchy_depth = true; D.log("children",D.id(node.obj),"depth_limit_subtree_not_enumerated")
                else
                    local ok, children = pcall(function() return node.obj:GetChildren() end)
                    if ok and type(children) == "table" then
                        if node.obj == game then
                            local priorities = {ReplicatedFirst = 1,ReplicatedStorage = 2,Players = 3,StarterPlayer = 4,
                                StarterGui = 5,Workspace = 6,CorePackages = 98,CoreGui = 99}
                            table.sort(children,function(a,b) return (priorities[a.Name] or 50) < (priorities[b.Name] or 50) end)
                        end
                        node.entered, node.children, node.index, node.childFrame = true,children,1,childFrame
                        stack[#stack + 1] = node
                    else
                        D.c.childFailures = D.c.childFailures + 1
                        D.log("children",D.id(node.obj),"children_unavailable")
                    end
                end
            end
        else D.c.duplicates = D.c.duplicates + 1 end
        -- Count discovered pending siblings, not just traversal frames. No guess at the unknown total.
        local pending = 0
        for _, frame in ipairs(stack) do
            pending = pending + (frame.entered and math.max(0,#frame.children - frame.index + 1) or 1)
        end
        D.pendingDiscovered = pending
    end
    return #stack == 0 and not D.stop
end

function D.boundedCall(fn, argument, seconds, phase)
    if not API.spawn and not API.defer then return false,"deferred_workers_unavailable" end
    local function newWorker()
        local state = {alive = true,done = false,started = false}
        local thread = coroutine.create(function()
            if not state.alive then return end
            state.started = true
            local ok,result = pcall(fn,argument)
            if state.alive then state.ok,state.result,state.done = ok,result,true end
        end)
        return state,thread
    end
    local begin = os.clock()
    local token,worker = newWorker()
    D.activeWorker = worker
    if API.spawn then
        -- task.spawn resumes immediately. Fast native calls need no mandatory
        -- frame wait, while a yielding call remains independently cancellable.
        local dispatched = pcall(API.spawn,worker)
        if not dispatched and not token.started then
            token.alive = false
            if API.cancel then pcall(API.cancel,worker) end
            API.spawn = nil
            D.c.dispatchFallbacks = D.c.dispatchFallbacks + 1
            token,worker = newWorker()
            D.activeWorker = worker
            if API.defer then API.defer(worker) else D.activeWorker = nil; return false,"deferred_workers_unavailable" end
        end
    else API.defer(worker) end
    while not token.done and not D.stop and os.clock() - begin < seconds do
        D.current = phase .. " | " .. string.format("%.1fs",os.clock() - begin) .. " / " .. seconds .. "s cooperative timeout"
        D.cooperate(true)
    end
    D.activeWorker = nil
    if token.done then token.alive = false; return token.ok,token.result end
    token.alive = false
    local cancelled = API.cancel and pcall(API.cancel,worker) or false
    if not cancelled then
        D.sourceAbortReason = "worker_could_not_be_cancelled"
        return false,"uncancellable_worker"
    end
    return false,D.stop and "cancelled" or "timeout"
end

local RECOVERY_PLAN = {["schema"]="feral-recovery-targets/3.1",["baseline_session"]="20261116_042419_33AB9E25F8D1",["baseline_version"]="3.0.3",["known_syntax_failures"]=64,["additional_semantic_review"]=7,["targets"]={
{["key"]="T0001",["path"]="game/ReplicatedStorage/FeralWorld/NeedsConfig",["previous_id"]=33,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=5251,["previous_filtered_adler32"]="a28d1d5f",["previous_parse_ok"]=false},
{["key"]="T0002",["path"]="game/ReplicatedStorage/FeralWorld/FeedFinder",["previous_id"]=34,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=12793,["previous_filtered_adler32"]="77280d53",["previous_parse_ok"]=false},
{["key"]="T0003",["path"]="game/ReplicatedStorage/FeralWorld/Species",["previous_id"]=35,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=28290,["previous_filtered_adler32"]="6853c63a",["previous_parse_ok"]=false},
{["key"]="T0004",["path"]="game/ReplicatedStorage/FeralWorld/NPCConfig",["previous_id"]=40,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=13722,["previous_filtered_adler32"]="91897c0e",["previous_parse_ok"]=false},
{["key"]="T0005",["path"]="game/ReplicatedStorage/FeralWorld/CombatConfig",["previous_id"]=41,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=16719,["previous_filtered_adler32"]="c6488be1",["previous_parse_ok"]=false},
{["key"]="T0006",["path"]="game/ReplicatedStorage/FeralWorld/WeatherConfig",["previous_id"]=44,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=4109,["previous_filtered_adler32"]="ee0ce7d9",["previous_parse_ok"]=false},
{["key"]="T0007",["path"]="game/ReplicatedStorage/FeralWorld/AmberConfig",["previous_id"]=45,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=1786,["previous_filtered_adler32"]="57fce78b",["previous_parse_ok"]=false},
{["key"]="T0008",["path"]="game/ReplicatedStorage/FeralWorld/DevConfig",["previous_id"]=46,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=943,["previous_filtered_adler32"]="f879ea96",["previous_parse_ok"]=false},
{["key"]="T0009",["path"]="game/ReplicatedStorage/FeralWorld/MapConfig",["previous_id"]=49,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=1202,["previous_filtered_adler32"]="b89a3457",["previous_parse_ok"]=false},
{["key"]="T0010",["path"]="game/ReplicatedStorage/FeralWorld/SoundConfig",["previous_id"]=50,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=3630,["previous_filtered_adler32"]="88dd5f31",["previous_parse_ok"]=false},
{["key"]="T0011",["path"]="game/ReplicatedStorage/FeralWorld/PackConfig",["previous_id"]=51,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=4121,["previous_filtered_adler32"]="16e4089d",["previous_parse_ok"]=false},
{["key"]="T0012",["path"]="game/ReplicatedStorage/FeralWorld/ShopConfig",["previous_id"]=54,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=12056,["previous_filtered_adler32"]="19ca7489",["previous_parse_ok"]=false},
{["key"]="T0013",["path"]="game/ReplicatedStorage/FeralWorld/AbilityConfig",["previous_id"]=56,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=66144,["previous_filtered_adler32"]="307f6469",["previous_parse_ok"]=false},
{["key"]="T0014",["path"]="game/ReplicatedStorage/FeralWorld/OnboardingConfig",["previous_id"]=61,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=28637,["previous_filtered_adler32"]="47b69d2d",["previous_parse_ok"]=false},
{["key"]="T0015",["path"]="game/ReplicatedStorage/FeralWorld/TutorialConfig",["previous_id"]=62,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=5886,["previous_filtered_adler32"]="4989e986",["previous_parse_ok"]=false},
{["key"]="T0016",["path"]="game/ReplicatedStorage/FeralWorld/RewardConfig",["previous_id"]=64,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=1096,["previous_filtered_adler32"]="796b04ac",["previous_parse_ok"]=false},
{["key"]="T0017",["path"]="game/ReplicatedStorage/FeralWorld/CoatConfig",["previous_id"]=65,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=13814,["previous_filtered_adler32"]="465ffd97",["previous_parse_ok"]=false},
{["key"]="T0018",["path"]="game/ReplicatedStorage/FeralWorld/TerritoryConfig",["previous_id"]=67,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=12195,["previous_filtered_adler32"]="529494d7",["previous_parse_ok"]=false},
{["key"]="T0019",["path"]="game/ReplicatedStorage/FeralWorld/FishConfig",["previous_id"]=68,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=1858,["previous_filtered_adler32"]="04f7d31c",["previous_parse_ok"]=false},
{["key"]="T0020",["path"]="game/ReplicatedStorage/FeralWorld/GrowthConfig",["previous_id"]=72,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=4966,["previous_filtered_adler32"]="bc7906f4",["previous_parse_ok"]=false},
{["key"]="T0021",["path"]="game/ReplicatedStorage/FeralWorld/HudConfig",["previous_id"]=74,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=27411,["previous_filtered_adler32"]="18485dd3",["previous_parse_ok"]=false},
{["key"]="T0022",["path"]="game/ReplicatedStorage/FeralWorld/CarcassConfig",["previous_id"]=76,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=1170,["previous_filtered_adler32"]="c5ab1871",["previous_parse_ok"]=false},
{["key"]="T0023",["path"]="game/ReplicatedStorage/FeralWorld/PassiveConfig",["previous_id"]=77,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=8210,["previous_filtered_adler32"]="97c90412",["previous_parse_ok"]=false},
{["key"]="T0024",["path"]="game/ReplicatedStorage/FeralWorld/ScentConfig",["previous_id"]=79,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=2437,["previous_filtered_adler32"]="60994bb7",["previous_parse_ok"]=false},
{["key"]="T0025",["path"]="game/ReplicatedStorage/FeralWorld/GoalConfig",["previous_id"]=81,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=2101,["previous_filtered_adler32"]="18dcf97e",["previous_parse_ok"]=false},
{["key"]="T0026",["path"]="game/ReplicatedStorage/FeralWorld/CinematicConfig",["previous_id"]=82,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=17849,["previous_filtered_adler32"]="e2d730b7",["previous_parse_ok"]=false},
{["key"]="T0027",["path"]="game/ReplicatedStorage/FeralWorld/StatusConfig",["previous_id"]=85,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=11155,["previous_filtered_adler32"]="72df2572",["previous_parse_ok"]=false},
{["key"]="T0028",["path"]="game/ReplicatedStorage/FeralWorld/VenomConfig",["previous_id"]=103,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=3520,["previous_filtered_adler32"]="2709294e",["previous_parse_ok"]=false},
{["key"]="T0029",["path"]="game/ReplicatedStorage/FeralWorld/ElderConfig",["previous_id"]=107,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=8374,["previous_filtered_adler32"]="ce889026",["previous_parse_ok"]=false},
{["key"]="T0030",["path"]="game/ReplicatedStorage/FeralWorld/FilmConfig",["previous_id"]=116,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=8108,["previous_filtered_adler32"]="7d12e294",["previous_parse_ok"]=false},
{["key"]="T0031",["path"]="game/ReplicatedStorage/FeralWorld/JumpLeapConfig",["previous_id"]=117,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=891,["previous_filtered_adler32"]="c3a7d12d",["previous_parse_ok"]=false},
{["key"]="T0032",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralCombatClient",["previous_id"]=3630,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=146044,["previous_filtered_adler32"]="e6f36f1c",["previous_parse_ok"]=false},
{["key"]="T0033",["path"]="game/ReplicatedStorage/FeralWorld/AnimProfiles",["previous_id"]=36,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=287885,["previous_filtered_adler32"]="00105eb9",["previous_parse_ok"]=false},
{["key"]="T0034",["path"]="game/ReplicatedStorage/FeralWorld/UITheme",["previous_id"]=38,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=26306,["previous_filtered_adler32"]="2d7da57f",["previous_parse_ok"]=false},
{["key"]="T0035",["path"]="game/ReplicatedStorage/FeralWorld/SoundboardList",["previous_id"]=47,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=111187,["previous_filtered_adler32"]="c84f2c1d",["previous_parse_ok"]=false},
{["key"]="T0036",["path"]="game/ReplicatedStorage/FeralWorld/MapSpots",["previous_id"]=48,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=3257,["previous_filtered_adler32"]="a1169960",["previous_parse_ok"]=false},
{["key"]="T0037",["path"]="game/ReplicatedStorage/FeralWorld/SnakeProfiles",["previous_id"]=86,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=8555,["previous_filtered_adler32"]="f53acbe4",["previous_parse_ok"]=false},
{["key"]="T0038",["path"]="game/ReplicatedStorage/FeralWorld/BirdProfiles",["previous_id"]=94,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=22439,["previous_filtered_adler32"]="4f8f11d3",["previous_parse_ok"]=false},
{["key"]="T0039",["path"]="game/ReplicatedStorage/FeralWorld/BirdRig",["previous_id"]=95,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=129732,["previous_filtered_adler32"]="be44a554",["previous_parse_ok"]=false},
{["key"]="T0040",["path"]="game/ReplicatedStorage/FeralWorld/ElderPaint",["previous_id"]=109,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=6708,["previous_filtered_adler32"]="773de7ce",["previous_parse_ok"]=false},
{["key"]="T0041",["path"]="game/ReplicatedStorage/FeralWorld/Clutter/Data_WolfValley",["previous_id"]=121,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=638,["previous_filtered_adler32"]="0f1a9af2",["previous_parse_ok"]=false},
{["key"]="T0042",["path"]="game/Players/LocalPlayer/PlayerScripts/WolfAnimClient",["previous_id"]=3621,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=737032,["previous_filtered_adler32"]="e255d0a3",["previous_parse_ok"]=false},
{["key"]="T0043",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralMenu",["previous_id"]=3625,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=658710,["previous_filtered_adler32"]="3cdc84f7",["previous_parse_ok"]=false},
{["key"]="T0044",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralHUD",["previous_id"]=3626,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=458421,["previous_filtered_adler32"]="3786775a",["previous_parse_ok"]=false},
{["key"]="T0045",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralNightVision",["previous_id"]=3638,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=15970,["previous_filtered_adler32"]="2765ceb6",["previous_parse_ok"]=false},
{["key"]="T0046",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralPacksUI",["previous_id"]=3639,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=113093,["previous_filtered_adler32"]="8e0ae362",["previous_parse_ok"]=false},
{["key"]="T0047",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralDust",["previous_id"]=3648,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=19230,["previous_filtered_adler32"]="1b2a5a47",["previous_parse_ok"]=false},
{["key"]="T0048",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralOnbClient",["previous_id"]=3653,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=111988,["previous_filtered_adler32"]="84ef6c6f",["previous_parse_ok"]=false},
{["key"]="T0049",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralRewardsUI",["previous_id"]=3658,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=96682,["previous_filtered_adler32"]="092ac502",["previous_parse_ok"]=false},
{["key"]="T0050",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralDive",["previous_id"]=3660,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=67666,["previous_filtered_adler32"]="fd9f8847",["previous_parse_ok"]=false},
{["key"]="T0051",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralClimb",["previous_id"]=3667,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=34665,["previous_filtered_adler32"]="809805b9",["previous_parse_ok"]=false},
{["key"]="T0052",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralUIKit",["previous_id"]=3677,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=42027,["previous_filtered_adler32"]="ea3d74b9",["previous_parse_ok"]=false},
{["key"]="T0053",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralTerritoryHUD",["previous_id"]=3690,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=178758,["previous_filtered_adler32"]="e9a596d9",["previous_parse_ok"]=false},
{["key"]="T0054",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralFlight",["previous_id"]=3692,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=54595,["previous_filtered_adler32"]="25b11899",["previous_parse_ok"]=false},
{["key"]="T0055",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralSaveAdminClient",["previous_id"]=3699,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=16352,["previous_filtered_adler32"]="e701e791",["previous_parse_ok"]=false},
{["key"]="T0056",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralTextFit",["previous_id"]=3700,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=8749,["previous_filtered_adler32"]="4d0fbd1a",["previous_parse_ok"]=false},
{["key"]="T0057",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralTitlePack",["previous_id"]=3709,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=37115,["previous_filtered_adler32"]="01bde82f",["previous_parse_ok"]=false},
{["key"]="T0058",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralGiveUI",["previous_id"]=3719,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=45221,["previous_filtered_adler32"]="0e5ee969",["previous_parse_ok"]=false},
{["key"]="T0059",["path"]="game/Players/LocalPlayer/PlayerScripts/FeralKingsClient",["previous_id"]=3723,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=35289,["previous_filtered_adler32"]="92b93f03",["previous_parse_ok"]=false},
{["key"]="T0060",["path"]="game/Players/LocalPlayer/PlayerScripts/RbxCharacterSounds",["previous_id"]=3725,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=16153,["previous_filtered_adler32"]="cc18959a",["previous_parse_ok"]=false},
{["key"]="T0061",["path"]="game/StarterPlayer/StarterPlayerScripts/WolfAnimClient",["previous_id"]=11837,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=737032,["previous_filtered_adler32"]="e255d0a3",["previous_parse_ok"]=false},
{["key"]="T0062",["path"]="game/StarterPlayer/StarterPlayerScripts/FeralMenu",["previous_id"]=11841,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=658710,["previous_filtered_adler32"]="3cdc84f7",["previous_parse_ok"]=false},
{["key"]="T0063",["path"]="game/StarterPlayer/StarterPlayerScripts/FeralHUD",["previous_id"]=11842,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=458421,["previous_filtered_adler32"]="3786775a",["previous_parse_ok"]=false},
{["key"]="T0064",["path"]="game/StarterPlayer/StarterPlayerScripts/FeralTerritoryHUD",["previous_id"]=11906,["reason"]="known_syntax_failure",["previous_filtered_bytes"]=178758,["previous_filtered_adler32"]="e9a596d9",["previous_parse_ok"]=false},
{["key"]="T0065",["path"]="game/ReplicatedStorage/FeralWorld/RegrowConfig",["previous_id"]=112,["reason"]="semantic_review_despite_syntax_pass",["previous_filtered_bytes"]=2150,["previous_filtered_adler32"]="4b574220",["previous_parse_ok"]=true},
{["key"]="T0066",["path"]="game/ReplicatedStorage/FeralWorld/FloodConfig",["previous_id"]=102,["reason"]="semantic_review_despite_syntax_pass",["previous_filtered_bytes"]=915,["previous_filtered_adler32"]="6abde64b",["previous_parse_ok"]=true},
{["key"]="T0067",["path"]="game/ReplicatedStorage/FeralWorld/PerfConfig",["previous_id"]=92,["reason"]="semantic_review_despite_syntax_pass",["previous_filtered_bytes"]=1248,["previous_filtered_adler32"]="9aa5455a",["previous_parse_ok"]=true},
{["key"]="T0068",["path"]="game/Players/LocalPlayer/PlayerScripts/WolfController",["previous_id"]=3620,["reason"]="semantic_review_despite_syntax_pass",["previous_filtered_bytes"]=272983,["previous_filtered_adler32"]="472b37ae",["previous_parse_ok"]=true},
{["key"]="T0069",["path"]="game/ReplicatedStorage/FeralWorld/FlightConfig",["previous_id"]=93,["reason"]="semantic_review_despite_syntax_pass",["previous_filtered_bytes"]=4090,["previous_filtered_adler32"]="b7a6f049",["previous_parse_ok"]=true},
{["key"]="T0070",["path"]="game/ReplicatedStorage/FeralWorld/SurvivalConfig",["previous_id"]=70,["reason"]="semantic_review_despite_syntax_pass",["previous_filtered_bytes"]=2783,["previous_filtered_adler32"]="c6acf6f4",["previous_parse_ok"]=true},
{["key"]="T0071",["path"]="game/ReplicatedStorage/FeralWorld/CoatMasks",["previous_id"]=111,["reason"]="semantic_review_despite_syntax_pass",["previous_filtered_bytes"]=800356,["previous_filtered_adler32"]="3f2a901f",["previous_parse_ok"]=true}
}}
-- Runtime appended by build-feral-recovery-v3.1.py. This file is not a loader.
D.captures,D.lastSources,D.recoveryCounts = {},{}, {attempts = 0,exported = 0,unexported = 0,syntax_pass = 0,syntax_reject = 0,unchecked = 0,missing = 0,filter_regressions = 0}
D.expectedSpecies,D.traceSeconds,D.traceInterval = "Tiger",30,0.1
D.phase,D.current,D.notice = "ready","Choose MENU CAPTURE first, then spawn as a Tiger and choose IN-GAME CAPTURE.","Nothing starts until you click a capture button."
D.emitBase = D.emit
function D.emit(name,record)
    if D.capture then
        record.capture_id = D.capture.key
        name = "captures/" .. D.capture.key .. "/" .. name
    end
    return D.emitBase(name,record)
end
function D.context()
    local characterOk,character = D.read(player,"Character")
    if not characterOk or typeof(character) ~= "Instance" then character = nil end
    local function attr(obj,key)
        if not obj then return nil end
        local ok,value = pcall(function() return obj:GetAttribute(key) end)
        if ok then return value end
        return nil
    end
    local humanoid = nil
    if character then
        local ok,found = pcall(function() return character:FindFirstChildOfClass("Humanoid") end)
        if ok then humanoid = found end
    end
    local health = nil
    if humanoid then local ok,value = D.read(humanoid,"Health"); if ok then health = value end end
    local species = attr(character,"Species") or attr(player,"FeralAnimal")
    local menu,despawned = attr(player,"FeralMenuOpen"),attr(player,"FeralDespawned")
    local active = character ~= nil and humanoid ~= nil and type(health) == "number" and health > 0 and menu ~= true and despawned ~= true
    return {character_present = character ~= nil,humanoid_present = humanoid ~= nil,health = D.value(health),
        menu_open = D.value(menu),despawned = D.value(despawned),species = D.value(species,"Species",false),
        expected_species = D.expectedSpecies,species_matches = species == D.expectedSpecies,active = active},character,humanoid
end
function D.syntax(source)
    if not D.compilerReady then return {status = "unavailable",reason = D.compilerReason or "not_tested"} end
    -- loadstring returns a compiled closure. It is NEVER invoked, required,
    -- spawned or passed to an execution API. Error text can echo source: omit it.
    local ok,compiled,err = pcall(API.compile,source,"=FERAL_compile_only")
    local kind = type(compiled)
    compiled = nil
    if not ok then return {status = "api_error",reason = "compiler_error_details_withheld"} end
    if kind == "function" then return {status = "pass",execution_attempted = false} end
    local text = type(err) == "string" and err or ""
    local line = tonumber(text:match(":(%d+):"))
    local row,column = text:match("%((%d+),(%d+)%)")
    return {status = "reject",line = line or tonumber(row),column = tonumber(column),
        reason = "compiler_rejected_text_details_withheld",execution_attempted = false}
end
function D.checkCompiler()
    if not API.compile then D.compilerReady,D.compilerReason = false,"loadstring_missing"; return end
    local good,fn = pcall(API.compile,"return 1","=FERAL_compiler_selfcheck")
    local bad,badFn = pcall(API.compile,"local = ","=FERAL_compiler_selfcheck")
    D.compilerReady = good and type(fn) == "function" and bad and type(badFn) ~= "function"
    fn,badFn = nil,nil
    D.compilerReason = D.compilerReady and "selfcheck_passed_without_execution" or "compiler_selfcheck_failed"
end
function D.sourceComparison(rawCheck,filteredCheck)
    if rawCheck.status == "pass" and filteredCheck.status == "reject" then return "filter_regression" end
    if rawCheck.status == "reject" and filteredCheck.status == "reject" then return "invalid_before_and_after_filter" end
    if rawCheck.status == "reject" and filteredCheck.status == "pass" then return "filter_changed_rejected_text_to_parsable" end
    if rawCheck.status == "pass" and filteredCheck.status == "pass" then return "syntax_pass_semantics_unverified" end
    return "syntax_comparison_unavailable"
end
function D.readCanonical(info)
    if not API.read or not info then return nil end
    local chunks = {}
    for _,meta in ipairs(info.files or {}) do
        local ok,body = pcall(API.read,D.root .. "/" .. meta.path)
        if not ok or type(body) ~= "string" or #body ~= meta.bytes or D.adler(body) ~= meta.adler32 then return nil end
        chunks[#chunks + 1] = body
    end
    return table.concat(chunks)
end
function D.exportAttempt(target,body,method,attempt,previousRaw,previousAttempt)
    local record = {target = target.key,path = target.path,previous_id = target.previous_id,attempt = attempt,
        method = method,original_bytes = #body,reconstructed = method == "decompile",original_source_guaranteed = false,
        execution_attempted = false}
    if #body > CFG.maxSingleSourceBytes then
        record.status,record.reason = "not_exported","source_size_limit"
        D.limits.single_source_bytes = true
        D.emit("recovery-attempts/game",record)
        return record
    end
    record.raw_syntax = D.syntax(body)
    -- Conservative gap for a new output format the privacy lexer cannot safely
    -- tokenize. Current baseline targets have no backticks. Never persist raw text.
    if body:find("`",1,true) then
        record.status,record.reason = "not_exported","interpolated_string_format_not_supported_by_privacy_filter"
        D.emit("recovery-attempts/game",record)
        return record
    end
    if previousRaw and body == previousRaw and previousAttempt then
        record.status,record.same_raw_as_previous_attempt = previousAttempt.status,true
        record.filtered_syntax,record.filter_comparison = previousAttempt.filtered_syntax,previousAttempt.filter_comparison
        record.files,record.exported_bytes,record.exported_adler32 = previousAttempt.files,previousAttempt.exported_bytes,previousAttempt.exported_adler32
        record.privacy_edits,record.storage = previousAttempt.privacy_edits,"shared_exact_raw_retry"
        record.matches_baseline_checksum_and_length = previousAttempt.matches_baseline_checksum_and_length
        record.baseline_comparison_is_exact_equality = false
        D.emit("recovery-attempts/game",record)
        return record
    end
    local filtered,edits,hasCode = D.filterSource(body)
    if not hasCode then
        record.status,record.reason = "not_exported","empty_or_comment_only"
        D.emit("recovery-attempts/game",record)
        return record
    end
    record.filtered_syntax = D.syntax(filtered)
    record.filter_comparison = D.sourceComparison(record.raw_syntax,record.filtered_syntax)
    record.exported_bytes,record.exported_adler32,record.privacy_edits = #filtered,D.adler(filtered),edits
    record.matches_baseline_checksum_and_length = #filtered == target.previous_filtered_bytes and record.exported_adler32 == target.previous_filtered_adler32
    record.baseline_comparison_is_exact_equality = false
    local previous = D.lastSources[target.key]
    local canonical = previous and D.readCanonical(previous)
    if canonical and canonical == filtered then
        record.files,record.storage,record.same_filtered_as_previous_capture_or_attempt = previous.files,"shared_exact_filtered_text",true
    else
        record.files,record.storage = {},"new_text"
        if canonical then record.same_filtered_as_previous_capture_or_attempt = false end
        if previous and not canonical then record.previous_text_comparison = "unavailable" end
        for start = 1,#filtered,CFG.sourceChunkBytes do
            local chunk = filtered:sub(start,start + CFG.sourceChunkBytes - 1)
            record.files[#record.files + 1] = D.payload("captures/" .. D.capture.key .. "/sources/game/" .. target.key
                .. string.format("_A%02d_part%03d.source.txt",attempt,#record.files + 1),chunk)
            if not D.cooperate(false) then
                record.status,record.reason = "partial_chunks","stopped_during_source_save"
                D.emit("recovery-attempts/game",record)
                return record
            end
        end
    end
    record.status = "exported"
    D.lastSources[target.key] = {files = record.files,capture = D.capture.key}
    D.c.redactions = D.c.redactions + edits
    if record.filter_comparison == "filter_regression" then D.recoveryCounts.filter_regressions = D.recoveryCounts.filter_regressions + 1 end
    D.emit("recovery-attempts/game",record)
    return record
end
function D.resolveTarget(path)
    local cursor = game
    for segment in path:gmatch("[^/]+") do
        if segment ~= "game" then
            segment = segment:gsub("~1","/"):gsub("~0","~")
            if cursor == Players and segment == "LocalPlayer" then cursor = player
            else
                local ok,found = pcall(function() return cursor:FindFirstChild(segment) end)
                if not ok or not found then return nil,"path_not_present" end
                cursor = found
            end
        end
    end
    if D.private(cursor) then return nil,"privacy_excluded" end
    local ok,class = D.read(cursor,"ClassName")
    local _,eligible = D.scriptType(cursor,ok and class or "")
    if not eligible then return nil,"not_eligible_client_source" end
    return cursor
end
function D.fetchSource(obj,target,attempt)
    local ok,body = D.read(obj,"Source")
    if ok and type(body) == "string" and #body > 0 then return true,body,"Source_property" end
    if not API.decompile then return false,"source_unavailable_no_decompiler","none" end
    local success,result = D.boundedCall(API.decompile,obj,CFG.sourceTimeoutSeconds,
        D.capture.mode .. " | " .. target.key .. " | attempt " .. attempt)
    return success,result,"decompile"
end
function D.recoverTargets()
    D.phase,D.current = "sources","Recovering 71 selected paths; Roblox platform sources remain in the prior export."
    D.capture.target_results = {}
    D.capture.source_status_counts = {}
    D.capture.targets_processed = 0
    local timeoutStreak = 0
    for index,target in ipairs(RECOVERY_PLAN.targets) do
        if not D.cooperate(false) or D.sourceAbortReason then break end
        D.sourceCursor = index
        D.current = string.format("%s sources: %d / %d | %s",D.capture.mode,index,#RECOVERY_PLAN.targets,target.key)
        local obj,missing = D.resolveTarget(target.path)
        local result = {target = target.key,path = target.path,previous_id = target.previous_id,reason_for_review = target.reason,
            attempted = false,attempts = 0,status = missing or "not_attempted"}
        if obj then
            result.instance_id,result.attempted = D.id(obj),true
            local lastRaw,lastAttempt = nil,nil
            for attempt = 1,2 do
                if D.stop or D.sourceAbortReason then break end
                local ok,body,method = D.fetchSource(obj,target,attempt)
                D.recoveryCounts.attempts = D.recoveryCounts.attempts + 1
                result.attempts = attempt
                if not ok or type(body) ~= "string" or #body == 0 then
                    local reason = body == "timeout" and "timeout" or body == "uncancellable_worker" and body
                        or body == "cancelled" and body or body == "source_unavailable_no_decompiler" and body or "source_api_error_or_empty"
                    D.emit("recovery-attempts/game",{target = target.key,path = target.path,attempt = attempt,method = method,status = "failed",reason = reason})
                    result.last_attempt_status = reason
                    if reason == "timeout" then
                        timeoutStreak = timeoutStreak + 1
                        if timeoutStreak >= CFG.maxConsecutiveTimeouts then D.sourceAbortReason = "repeated_decompiler_timeouts" end
                    else timeoutStreak = 0 end
                    if result.status ~= "exported" then result.status = reason end
                    if reason == "timeout" or reason == "uncancellable_worker" or reason == "cancelled" then break end
                else
                    timeoutStreak = 0
                    local attemptResult = D.exportAttempt(target,body,method,attempt,lastRaw,lastAttempt)
                    result.last_attempt_status = attemptResult.status
                    if attemptResult.status == "exported" then
                        result.status,result.selected_attempt,result.files = "exported",attempt,attemptResult.files
                        result.raw_syntax,result.filtered_syntax,result.filter_comparison = attemptResult.raw_syntax,attemptResult.filtered_syntax,attemptResult.filter_comparison
                        result.exported_bytes,result.exported_adler32 = attemptResult.exported_bytes,attemptResult.exported_adler32
                        result.matches_baseline_checksum_and_length = attemptResult.matches_baseline_checksum_and_length
                    elseif result.status ~= "exported" then result.status = attemptResult.reason or attemptResult.status end
                    if attemptResult.same_raw_as_previous_attempt then result.identical_retry_stopped = true; break end
                    if not attemptResult.filtered_syntax or attemptResult.filtered_syntax.status ~= "reject" then break end
                    lastRaw,lastAttempt = body,attemptResult
                end
                if not D.cooperate(true) then break end
            end
            lastRaw,lastAttempt,obj = nil,nil,nil
        else D.recoveryCounts.missing = D.recoveryCounts.missing + 1 end
        if result.status == "exported" then
            D.recoveryCounts.exported = D.recoveryCounts.exported + 1
            local status = result.filtered_syntax and result.filtered_syntax.status
            local key = status == "pass" and "syntax_pass" or status == "reject" and "syntax_reject" or "unchecked"
            D.recoveryCounts[key] = D.recoveryCounts[key] + 1
        else D.recoveryCounts.unexported = D.recoveryCounts.unexported + 1 end
        D.capture.target_results[#D.capture.target_results + 1] = result
        D.capture.source_status_counts[result.status] = (D.capture.source_status_counts[result.status] or 0) + 1
        D.capture.targets_processed = #D.capture.target_results
        D.emit("target-results/game",result)
    end
    -- Every target receives an explicit terminal record, including after Stop.
    for index = #D.capture.target_results + 1,#RECOVERY_PLAN.targets do
        local target = RECOVERY_PLAN.targets[index]
        local result = {target = target.key,path = target.path,attempted = false,attempts = 0,
            status = D.sourceAbortReason or (D.stop and "stopped_before_target" or "not_attempted")}
        D.capture.target_results[#D.capture.target_results + 1] = result
        D.capture.source_status_counts[result.status] = (D.capture.source_status_counts[result.status] or 0) + 1
        D.recoveryCounts.unexported = D.recoveryCounts.unexported + 1
        D.emit("target-results/game",result)
    end
    D.capture.source_pass_finished = not D.stop and not D.sourceAbortReason
    D.capture.targets_terminal = #D.capture.target_results
end
function D.setupPrivacy()
    D.refreshPrivacy()
    local ok,conn = pcall(function() return Players.PlayerAdded:Connect(function(other)
        if other ~= player then
            D.addPrivate(other)
            D.refreshPrivacy()
            D.watchers[#D.watchers + 1] = other.CharacterAdded:Connect(D.addPrivate)
        end
    end) end)
    if ok then D.watchers[#D.watchers + 1] = conn end
    local valid,list = pcall(function() return Players:GetPlayers() end)
    if valid then
        for _,other in ipairs(list) do if other ~= player then
            D.watchers[#D.watchers + 1] = other.CharacterAdded:Connect(D.addPrivate)
        end end
    end
end
function D.attributes(obj)
    if not obj then return {} end
    local ok,values = pcall(function() return obj:GetAttributes() end)
    if not ok then D.c.attributeFailures = D.c.attributeFailures + 1; return {unavailable = true} end
    local safe = {}
    for key,value in pairs(values) do
        local safeKey = D.secretString(key) and "[redacted-key]" or key
        safe[safeKey] = D.value(value,key,true)
    end
    return safe
end
function D.observe()
    local duration = D.capture.mode == "ingame" and D.traceSeconds or 2
    D.phase = "observing"
    local begin = os.clock()
    local pausedBefore = D.pausedSeconds or 0
    local function activeSeconds() return os.clock() - begin - ((D.pausedSeconds or 0) - pausedBefore) end
    D.capture.trace_samples,D.capture.trace_requested_seconds = 0,duration
    while activeSeconds() < duration and D.cooperate(false) do
        local context,character,humanoid = D.context()
        local props = {}
        if humanoid then
            for _,key in ipairs({"Health","MaxHealth","WalkSpeed","MoveDirection","FloorMaterial","Sit","PlatformStand"}) do
                local ok,value = D.read(humanoid,key)
                if ok then props[key] = D.value(value,key,false) end
            end
        end
        D.emit("observations/local",{seconds = os.clock() - begin,active_seconds = activeSeconds(),context = context,
            character_id = character and D.id(character) or nil,humanoid = props,
            character_attributes = D.attributes(character),player_attributes = D.attributes(player)})
        D.capture.trace_samples = D.capture.trace_samples + 1
        D.current = string.format("%s observation: %.1f / %ds | expected Tiger; active=%s",D.capture.mode,activeSeconds(),duration,tostring(context.active))
        task.wait(D.traceInterval)
    end
    D.capture.trace_observed_seconds = os.clock() - begin
    D.capture.trace_active_seconds = activeSeconds()
    D.capture.trace_finished = not D.stop and D.capture.trace_active_seconds >= duration
end
function D.captureInventory()
    D.phase = "inventory"
    D.visited,D.scripts,D.buckets = {},{},{{},{},{},{}}
    local complete = true
    -- Include ancestor context without traversing other Player roots. New
    -- instance IDs belong to this supplement, not the previous full scan.
    D.inspect(game,{path = "",category = "game"})
    D.inspect(Players,{path = "game",category = "game",service = "Players",parentId = D.id(game)})
    -- The previous complete export preserves platform roots. These additional
    -- observations cover current replicated game roots and this player's state.
    for _,name in ipairs({"ReplicatedFirst","ReplicatedStorage","Workspace","Lighting","SoundService","StarterPlayer","StarterGui","StarterPack","Teams"}) do
        if D.stop then complete = false; break end
        local root = game:FindFirstChild(name)
        if root then
            if not D.walk(root,{path = "game",category = "game",service = name,parentId = D.id(game)}) then complete = false end
        else D.emit("logs/scope",{root = name,status = "not_present"}) end
    end
    if not D.stop then
        if not D.walk(player,{path = "game/Players",category = "game",service = "Players",parentId = D.id(Players)}) then complete = false end
    else complete = false end
    local targetPaths = {}
    for _,target in ipairs(RECOVERY_PLAN.targets) do targetPaths[target.path] = true end
    for _,entry in ipairs(D.scripts) do
        if entry.eligible and not targetPaths[entry.path] then
            D.emit("source-scope/" .. entry.category,{id = entry.id,path = entry.path,status = "outside_targeted_source_pass",
                reason = "preserved_in_prior_full_export_or_requires_separate_followup_if_new"})
        end
    end
    D.capture.inventory_traversal_exhausted = complete
    D.scripts,D.buckets,D.visited = {},{{},{},{},{}},{}
end
function D.summary()
    local lines = {"FERAL Recovery Supplement v3.1 | " .. D.phase,
        "Folder: " .. (D.root ~= "" and D.root or "created when you capture"),
        "Buttons: MENU CAPTURE, then IN-GAME CAPTURE after spawning as a Tiger.",
        "Targets: 64 previous syntax failures + 7 semantic-review paths. Prior full export is retained.",
        "Session target results: " .. D.recoveryCounts.exported .. " exported | " .. D.recoveryCounts.unexported .. " unexported | " .. D.recoveryCounts.syntax_pass .. " syntax pass | "
            .. D.recoveryCounts.syntax_reject .. " syntax reject | " .. D.recoveryCounts.unchecked .. " unchecked",
        "Filter regressions: " .. D.recoveryCounts.filter_regressions .. " | missing paths: " .. D.recoveryCounts.missing,
        "Payloads: " .. D.payloadCount .. " | verified: " .. D.verifiedCount .. " | write errors: " .. D.c.writeErrors,
        "Compiler: " .. (D.compilerReason or "checked after first capture"),
        "No reconstructed code is executed. Syntax pass does not prove faithful reconstruction.",
        "ZIP this ENTIRE folder after both captures; upload that ZIP. No need to upload the old scan again."}
    for _,capture in ipairs(D.captures) do
        lines[#lines + 1] = capture.key .. ": " .. capture.status .. " | source pass " .. tostring(capture.source_pass_finished == true)
            .. " | trace " .. tostring(capture.trace_samples or 0) .. " samples"
    end
    if D.sourceAbortReason then lines[#lines + 1] = "Source stop reason: " .. D.sourceAbortReason end
    return table.concat(lines,"\n")
end
function D.manifest()
    local controls,streams,captures = {},{},{}
    for _,meta in pairs(D.controls) do controls[#controls + 1] = meta end
    for name,stream in pairs(D.streams) do streams[name] = {chunks = stream.number,records = stream.records,buffered_bytes = stream.bytes} end
    for _,capture in ipairs(D.captures) do
        local item = {}
        for key,value in pairs(capture) do if key ~= "target_results" then item[key] = value end end
        captures[#captures + 1] = item
    end
    return {schema = "feral-recovery-supplement/3.1",version = CFG.version,session_id = D.session,place_id = game.PlaceId,
        phase = D.phase,started_utc = D.startedUtc,updated_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),checkpoint = D.checkpointNumber,
        elapsed_seconds = math.floor(os.clock() - D.started),baseline_session = RECOVERY_PLAN.baseline_session,
        target_count = #RECOVERY_PLAN.targets,known_syntax_failure_targets = 64,additional_semantic_review_targets = 7,
        target_plan_file = D.controls["target-plan.json"] and D.controls["target-plan.json"].path or nil,
        captures = captures,recovery_counts = D.recoveryCounts,inventory_counts_are_cumulative_observations = true,counts = D.c,
        files = {payload_count = D.payloadCount,payload_bytes = D.filesBytes,read_back_verified = D.verifiedCount,
            unverified = D.unverifiedCount,checksum_algorithm = "adler32",checksums_are_authentication = false},
        catalogs = D.catalogs,controls = controls,streams = streams,upload_parts = D.partList(),output_format = "data_only_text",
        privacy_filter_applied = true,exact_original_sources = false,syntax_is_not_semantic_verification = true,
        raw_sources_exported = false,reconstructed_code_executed = false,gameplay_writes = false,remotes_invoked = false,
        compiler_ready = D.compilerReady == true,compiler_reason = D.compilerReason,capabilities = apiOrigins,
        last_file_failure = D.lastWriteFailure,limits_hit = D.limits,source_abort_reason = D.sourceAbortReason,
        scope = "71 source paths plus game-root inventory and local observations in each selected mode; supplements previous full export",
        collection_gaps = {"server_only_or_unreplicated_content","streamed_out_or_changed_instances","privacy_exclusions",
            "properties_outside_explicit_schema","sources_outside_target_plan","platform_sources_retained_in_prior_export",
            "runtime_function_state_and_module_returns_not_inspected","interpolated_string_sources_omitted_if_present"}}
end
function D.preflight()
    D.stage("checking_file_apis","Checking text export support...")
    if not API.write or not API.mkdir then D.failureCode = "missing_file_apis"; error("writefile/makefolder required",0) end
    local ok,guid = pcall(function() return Http:GenerateGUID(false) end)
    D.session = os.date("!%Y%m%d_%H%M%S") .. "_" .. (ok and guid:gsub("[^%w]",""):sub(1,12) or tostring(math.random(100000,999999)))
    D.root = "FERAL_Recovery_v3_1_" .. D.session
    if API.isfolder then local valid,exists = pcall(API.isfolder,D.root); if valid and exists then error("Folder collision",0) end end
    if not D.mkdir(D.root) then error("Cannot create export folder",0) end
    D.control("startup-check.txt","FERAL Recovery v3.1 text write/read probe\n")
    D.checkCompiler()
    D.control("target-plan.json",D.encode(RECOVERY_PLAN))
    local instructions = "FERAL Recovery Supplement v3.1\n\n1. Click MENU CAPTURE while in FERAL's animal menu; wait for it to finish.\n"
        .. "2. Spawn as a Tiger. Click IN-GAME CAPTURE. Stay alive for its 30-second observation, then wait for sources/inventory.\n"
        .. "3. After both captures finish, right-click this ENTIRE folder in Windows 11 > Compress to ZIP file. Upload that ZIP.\n"
        .. "If too large, ZIP and upload EVERY UPLOAD_PART_* folder, including part 000 metadata.\n\n"
        .. "This supplements baseline " .. RECOVERY_PLAN.baseline_session .. ". Keep the old full export. No automatic uploads occur.\n"
        .. "Only privacy-filtered text is exported. Raw sources are compile-checked in memory and discarded; compiled functions are never called.\n"
        .. "A decompiler can return the same invalid text twice. Syntax errors are recorded, not repaired or presented as recovered logic.\n"
        .. "STOP & SAVE keeps completed data. The window stays available between captures. Minimise/Hide uses the FERAL SHOW button.\n"
    D.control("README.txt",instructions)
    D.rawWrite("READ_FIRST.txt",instructions)
    D.control("coverage.json",D.encode({schema = "feral-recovery-coverage/3.1",configuration = CFG,properties_by_base_class = D.properties,
        source_targets = "64 prior syntax-failing file sets and 7 suspicious passing paths; resolved by path, not old IDs",
        source_retries = "At most two reads/decompilations per path per capture. Exact identical raw retries stop. Exact filtered text can share verified prior files.",
        syntax_checks = "loadstring compiler capability self-tested; compile returned closures never executed. Raw and filtered parse statuses compared.",
        compiler_limit = "Native calls can block the client; cooperative timeouts cannot guarantee preemption. One decompiler at a time.",
        observation = "LocalPlayer and own character only; no event interception. Requested sample interval 0.1 seconds; actual times recorded.",
        privacy = "No other-player subtrees, chat text/input, credentials, raw source, raw compiler error messages or raw bytecode exported.",
        scope = "Existing full export is preserved. Current game roots are inventoried; no repeat of full CorePackages/CoreGui source collection.",
        not_attempted = {"gameplay writes","remote calls","require of game modules","debug/getgc inspection","server-only sources","hidden properties"},
        snapshot_is_atomic = false,source_syntax_does_not_guarantee_semantics = true}))
    D.initialized = true
    D.checkpoint()
end
function D.runCapture(mode)
    D.capture = nil
    if not D.initialized then D.preflight() end
    local capture = {key = string.format("C%03d_%s",#D.captures + 1,mode),mode = mode,status = "running",
        started_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),context_at_start = D.context(),expected_species = D.expectedSpecies,
        target_count = #RECOVERY_PLAN.targets,targets_processed = 0}
    D.capture = capture
    D.captures[#D.captures + 1] = capture
    D.sourceCursor = 0
    D.setupPrivacy()
    D.observe()
    -- Targeted recovery is saved before the potentially much larger world inventory.
    D.recoverTargets()
    D.checkpoint()
    if not D.stop and not D.sourceAbortReason then D.captureInventory() end
    capture.context_at_end = D.context()
    capture.finished_utc = os.date("!%Y-%m-%dT%H:%M:%SZ")
    capture.status = D.stop and "stopped_partial" or D.sourceAbortReason and "source_gaps" or "finished"
    capture.limits_hit = {}
    for key,value in pairs(D.limits) do capture.limits_hit[key] = value end
    D.emit("capture-summary",{capture = capture.key,status = capture.status,context = capture.context_at_end,
        targets_processed = capture.targets_processed,inventory_traversal_exhausted = capture.inventory_traversal_exhausted,
        source_pass_finished = capture.source_pass_finished,trace_finished = capture.trace_finished})
    local menu,ingame = false,false
    for _,item in ipairs(D.captures) do
        if item.status == "finished" then
            if item.mode == "menu" then menu = true else ingame = true end
        end
    end
    D.phase = D.stop and "stopped_partial" or D.sourceAbortReason and "finished_with_source_gaps" or (menu and ingame and "finished" or "awaiting_other_capture")
    D.current = D.stop and "Stopped safely. Completed files are saved; this capture is partial."
        or D.sourceAbortReason and "Source recovery ended with gaps. Completed files are saved."
        or menu and ingame and "Both captures saved. ZIP the entire displayed folder and upload it."
        or mode == "menu" and "Menu saved. Spawn as a Tiger, then click IN-GAME CAPTURE."
        or "In-game capture saved. MENU CAPTURE is also available when you open the animal menu."
    D.notice = "Capture ended. Syntax rejection remains a reported reconstruction problem, not a repaired file."
    D.checkpoint()
    D.capture = nil
end
function D.launch(mode)
    if D.running then return end
    if D.blocked then D.notice = "A native worker could not be stopped or files failed verification. Keep completed exports and reload the panel for a fresh session."; D.safeRender(true); return end
    local context = D.context()
    if mode == "ingame" and not context.active then
        D.notice = "Spawn as a Tiger first, close the animal menu, then click IN-GAME CAPTURE. No capture started."
        D.safeRender(true); return
    end
    if mode == "menu" and context.active then
        D.notice = "Open FERAL's animal menu first, then click MENU CAPTURE. No capture started."
        D.safeRender(true); return
    end
    D.running,D.launched,D.stop,D.paused = true,true,false,false
    D.sourceAbortReason,D.failureCode,D.reportVisible = nil,nil,false
    D.startClicks = D.startClicks + 1
    D.phase,D.startupStage,D.startupStep = "starting",mode .. "_capture","Starting " .. mode .. " capture..."
    D.safeRender(true)
    local ok,err = pcall(D.runCapture,mode)
    if not ok then
        D.runtimeErrorKind,D.runtimeErrorLine = D.errorKind(err),tostring(err):match(":(%d+):")
        D.failureCode,D.phase = D.lastWriteFailure and "file_write_or_verification_failed" or "capture_failed","failed_partial"
        if D.capture then D.capture.status = "failed_partial" end
        D.current,D.notice,D.reportVisible = "Capture failed; completed checkpoints remain saved.","Click COPY STARTUP REPORT if needed.",true
        if not D.lastWriteFailure and D.initialized then pcall(D.checkpoint) end
        if D.root ~= "" then pcall(function()
            D.metadataWrite("FAILURE.json",D.encode({phase = D.phase,failure_code = D.failureCode,
                error_kind = D.runtimeErrorKind,diagnostic_line = D.runtimeErrorLine,last_file_failure = D.lastWriteFailure,
                last_intact_checkpoint = D.checkpointNumber,notice = "Use the last intact checkpoint; later files may be unreferenced."}))
        end) end
    end
    D.blocked = D.lastWriteFailure ~= nil or D.sourceAbortReason == "worker_could_not_be_cancelled" or not D.initialized
    for _,conn in ipairs(D.watchers) do pcall(function() conn:Disconnect() end) end
    D.watchers,D.scripts,D.buckets,D.visited = {},{},{{},{},{},{}},{}
    D.capture,D.running = nil,false
    D.safeRender(true)
end
function D.cleanupUI()
    for _,connection in ipairs(D.connections) do pcall(function() connection:Disconnect() end) end
    D.connections = {}
    if D.gui then pcall(function() D.gui:Destroy() end) end
end
function D.createUI()
    local colors = {bg = Color3.fromRGB(17,24,35),text = Color3.fromRGB(235,243,249),muted = Color3.fromRGB(161,184,202),
        blue = Color3.fromRGB(44,103,157),green = Color3.fromRGB(26,124,101),red = Color3.fromRGB(159,60,70)}
    local function make(class,props,parent)
        local obj = Instance.new(class)
        for key,value in pairs(props) do
            local ok = pcall(function() obj[key] = value end)
            if not ok and key ~= "TextEditable" then error("UI property unavailable: " .. key,0) end
        end
        obj.Parent = parent
        return obj
    end
    local gui = make("ScreenGui",{Name = "FeralRecoverySupplementV31",ResetOnSpawn = false,IgnoreGuiInset = true,DisplayOrder = 475},playerGui)
    D.gui = gui
    local panel = make("Frame",{Name = "Panel",Size = UDim2.fromOffset(640,505),Position = UDim2.fromScale(0.5,0.08),AnchorPoint = Vector2.new(0.5,0),
        BackgroundColor3 = colors.bg,BorderSizePixel = 0,Active = true},gui)
    make("UICorner",{CornerRadius = UDim.new(0,10)},panel)
    local camera = workspace.CurrentCamera
    if camera then make("UIScale",{Scale = math.max(0.45,math.min(1,camera.ViewportSize.X/670,camera.ViewportSize.Y/550))},panel) end
    local function label(name,text,y,h,size)
        return make("TextLabel",{Name = name,Text = text,Position = UDim2.fromOffset(14,y),Size = UDim2.fromOffset(612,h),
            BackgroundTransparency = 1,TextColor3 = colors.text,Font = Enum.Font.Gotham,TextSize = size or 12,TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,TextYAlignment = Enum.TextYAlignment.Center},panel)
    end
    local function button(name,text,x,y,w,color,parent)
        local b = make("TextButton",{Name = name,Text = text,Position = UDim2.fromOffset(x,y),Size = UDim2.fromOffset(w,34),BackgroundColor3 = color,
            BorderSizePixel = 0,Font = Enum.Font.GothamBold,TextSize = 11,TextColor3 = colors.text},parent or panel)
        make("UICorner",{CornerRadius = UDim.new(0,6)},b);return b
    end
    label("Heading","FERAL / RECOVERY SUPPLEMENT v3.1",8,28,15)
    D.ui = {panel = panel,status = label("Status","READY - CHOOSE A CAPTURE",42,24,13),
        current = label("Current",D.current,69,39),folder = label("Folder","Folder created after first capture",112,28,11),
        counts = label("Counts","64 syntax failures + 7 review paths | same folder for both captures",143,28,11)}
    D.ui.menu = button("MenuCapture","1. MENU CAPTURE",14,178,198,colors.green)
    D.ui.ingame = button("InGameCapture","2. IN-GAME CAPTURE",221,178,198,colors.blue)
    D.ui.stop = button("Stop","STOP & SAVE",428,178,198,colors.red)
    D.ui.pause = button("Pause","PAUSE",14,220,145,colors.blue)
    local save = button("Checkpoint","SAVE CHECKPOINT",168,220,145,colors.blue)
    local folder = button("CopyFolder","COPY FOLDER",322,220,145,colors.blue)
    local report = button("CopyStartup","COPY STARTUP REPORT",476,220,150,colors.green)
    local hide = button("Hide","HIDE",565,8,61,colors.blue)
    D.ui.show = button("Show","FERAL SHOW",14,12,120,colors.blue,gui)
    D.ui.show.Visible = false
    label("Help","Menu: click 1 and wait. Then spawn as a Tiger, close the animal menu and click 2. The in-game observation takes 30 seconds before source recovery and world inventory. ZIP the entire folder after both captures finish.",263,54,11)
    D.ui.preview = make("TextBox",{Name = "Summary",Text = D.summary(),Position = UDim2.fromOffset(14,326),Size = UDim2.fromOffset(612,165),
        BackgroundColor3 = Color3.fromRGB(10,16,24),TextColor3 = colors.muted,Font = Enum.Font.Code,TextSize = 11,TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,TextYAlignment = Enum.TextYAlignment.Top,ClearTextOnFocus = false,TextEditable = false,
        MultiLine = true},panel)
    local function connect(signal,fn)
        D.connections[#D.connections + 1] = signal:Connect(function(...)
            local ok,err = pcall(fn,...)
            if not ok then D.notice = "Control failed: " .. D.errorKind(err); D.safeRender(true) end
        end)
    end
    connect(D.ui.menu.Activated,function() D.launch("menu") end)
    connect(D.ui.ingame.Activated,function() D.launch("ingame") end)
    connect(D.ui.pause.Activated,function() if D.running then D.paused = not D.paused;D.safeRender(true) end end)
    connect(D.ui.stop.Activated,function() if D.running then D.stop,D.paused = true,false;D.notice = "Stopping; completed files will be kept." end end)
    connect(save.Activated,function()
        if D.running then D.saveRequested = true
        elseif D.initialized and not D.blocked then D.checkpoint();D.notice = "Checkpoint saved." end
        D.safeRender(true)
    end)
    connect(folder.Activated,function()
        if API.clipboard and D.root ~= "" then pcall(API.clipboard,D.root);D.notice = "Folder name copied." end
        D.safeRender(true)
    end)
    connect(report.Activated,function()
        D.reportVisible = true
        if API.clipboard then pcall(API.clipboard,D.startupReport()) end
        D.safeRender(true)
    end)
    connect(hide.Activated,function() panel.Visible,D.ui.show.Visible = false,true end)
    connect(D.ui.show.Activated,function() panel.Visible,D.ui.show.Visible = true,false;D.safeRender(true) end)
    connect(gui.Destroying,function() D.stop,D.paused = true,false end)
end
function D.render()
    if not D.ui then return end
    D.ui.status.Text = D.phase:upper() .. (D.running and (D.paused and " | PAUSED" or " | RUNNING") or "")
    D.ui.current.Text = D.current .. "\n" .. D.notice
    D.ui.folder.Text = D.root ~= "" and D.root or "Folder created after the first capture click"
    D.ui.counts.Text = "Capture: " .. (D.capture and D.capture.mode or "ready") .. " | sources " .. D.sourceCursor .. " / 71 | saved payloads " .. D.payloadCount
    D.ui.pause.Text = D.paused and "RESUME" or "PAUSE"
    D.ui.menu.Text = D.running and "CAPTURE RUNNING" or "1. MENU CAPTURE"
    D.ui.ingame.Text = D.running and "CAPTURE RUNNING" or "2. IN-GAME CAPTURE"
    D.ui.preview.Text = D.reportVisible and D.startupReport() or D.summary()
end
local uiOk,uiError = pcall(D.createUI)
if not uiOk then
    D.phase,D.failureCode = "ui_setup_failed","ui_setup_failed"
    D.runtimeErrorKind,D.runtimeErrorLine = D.errorKind(uiError),tostring(uiError):match(":(%d+):")
    warn(D.startupReport())
end
D.safeRender(true)
