-- ARENA NOVA Client Diagnostic v1.2.0 - heavyweight resilient native+bytecode decomp
-- Adapted from proven read-only ARENA NOVA v1.0.0 collector.
-- Only local export/UI writes; no remote invocation or module evaluation.
-- Target universe 7209131331 (Arena of Survival).
-- Read-only game snapshot. Only this tool's UI and local export files are written.
-- No gameplay remote calls, hooks, arbitrary require(), hidden-property reads,
-- authentication APIs, chat history, or server-only source extraction.
-- Source reconstruction is optional and executor-dependent. See README-v3.0.md.

local CFG = {
    rootPlaceId = 72238253016204,
    universeId = 7209131331,
    version = "1.2.0",
    nativeTimeoutSeconds = 9,
    bytecodeFallbackTimeoutSeconds = 9,
    bytecodeReadTimeoutSeconds = 2,
    maxTemporaryBytecodeBytes = 4194304,
    nativeAdaptiveFailures = 3,
    quickFingerprintTimeoutSeconds = 0.6,
    decompileWorkers = 2,
    rapidMaxObjects = 6500,
    rapidMaxDepth = 14,
    rapidAttributeLimit = 24,
    chunkBytes = 262144,
    sourceChunkBytes = 524288,
    maxBufferedBytes = 2097152,
    uploadPartBytes = 25165824,
    sourceDedupeMaxBytes = 131072,
    sourceDedupeMaxEntries = 20000,
    bytecodeCacheMaxBytes = 16777216,
    bytecodeCacheMaxSingleBytes = 131072,
    maxObjects = 600000,
    maxScripts = 150000,
    maxDepth = 512,
    maxSingleSourceBytes = 8388608,
    maxConfigurationJsonBytes = 1048576,
    maxDecodedConfigNodes = 100000,
    maxExportBytes = 2147483648,
    maxMemoryGrowthMiB = 256,
    sourceTimeoutSeconds = 9,
    checkpointSeconds = 10,
    maxConsecutiveTimeouts = 3,
}
if game.PlaceId ~= CFG.rootPlaceId and game.GameId ~= CFG.universeId then
    warn("[ARENA NOVA] Wrong experience; expecting Arena of Survival.")
    return
end
local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local Collection = game:GetService("CollectionService")
local player = Players.LocalPlayer
if not player then warn("[ARENA NOVA v3.0] LocalPlayer unavailable."); return end
local playerGui = player:FindFirstChildOfClass("PlayerGui")
if not playerGui then warn("[ARENA NOVA v3.0] Join fully, then run the loader again."); return end
for _,name in ipairs({"ArenaNovaClientDiagnosticV100","ArenaNovaClientDiagnosticV110","ArenaNovaClientDiagnosticV120"}) do
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
    bytecode = resolveApi("getscriptbytecode",getscriptbytecode),
    cancel = optional(task.cancel), defer = optional(task.defer), spawn = optional(task.spawn),
}
local D = {
    phase = "ready", started = os.clock(), startedUtc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    snapshotMode = "LOBBY",
    fastSourcePassComplete = false, rapidSceneComplete = false,
    sourceWorkers = {},
    running = false, launched = false, startClicks = 0, startupStage = "waiting_for_start",
    startupStep = "Click START SCAN to begin.", startupWarnings = {}, reportVisible = false,
    stop = false, paused = false, saveRequested = false, finished = false, closing = false,
    root = "", current = "Click the green START SCAN button.", notice = "No scan has started yet.", lastCheckpoint = 0,
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
        bytecodeReused = 0,bytecodeCacheFailures = 0,
        directSourceSaved = 0,sourceQueueCreated = 0,queuedDecompiles = 0,
        decompilerWorkersStarted = 0,workerTimeouts = 0,workerDispatchFailures = 0,
        rapidObjects = 0,rapidValues = 0,rapidAttributes = 0,rapidReadFailures = 0,
        rapidSceneRecords = 0,rapidLimitHit = 0,
        nativeDecompileSuccess=0,nativeDecompileFailure=0,
        fallbackAttempted=0,fallbackExported=0,fallbackUnavailable=0,
        decompilerPlaceholders=0,adaptiveSingleWorker=0,
        terminalSourceFailure=0,bytecodeReadErrors=0,
        identicalCodeDeepDecompAvoided=0,fastFingerprintCalls=0,
        fastFingerprintStoppedDueSlowAPI=0},
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
        "ARENA NOVA STARTUP REPORT v" .. CFG.version,
        "Snapshot mode: " .. D.snapshotMode,
        "Universe ID: " .. tostring(game.GameId),
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
        "getloadedmodules","getscripts","getscriptbytecode","setclipboard","toclipboard"}) do
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
        "Color", "Material", "MaterialVariant", "Massless", "AssemblyLinearexecutor", "AssemblyAngularexecutor",
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
    AlignPosition = {"MaxForce", "Maxexecutor", "Responsiveness", "Position", "Mode", "RigidityEnabled"},
    AlignOrientation = {"MaxTorque", "MaxAngularexecutor", "Responsiveness", "CFrame", "Mode", "RigidityEnabled"},
    Linearexecutor = {"Vectorexecutor", "MaxForce", "RelativeTo", "executorConstraintMode"},
    VectorForce = {"Force", "RelativeTo", "ApplyAtCenterOfMass"},
    SpringConstraint = {"Stiffness", "Damping", "FreeLength", "LimitsEnabled", "MinLength", "MaxLength"},
    RopeConstraint = {"Length", "Thickness", "Restitution", "WinchEnabled"},
    Bodyexecutor = {"executor", "MaxForce", "P"},
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

-- UI implementation is kept inside a closure to keep active local counts low.
function D.createUI()
    local function make(class, props, parent)
        local obj = Instance.new(class)
        for key, value in pairs(props) do
            local ok = pcall(function() obj[key] = value end)
            if not ok then
                if key == "TextEditable" then
                    D.startupWarnings[#D.startupWarnings + 1] = class .. "." .. key .. " unavailable; using default"
                else error("Cannot set diagnostic UI property " .. class .. "." .. key,0) end
            end
        end
        obj.Parent = parent
        return obj
    end
    local colors = {bg = Color3.fromRGB(17,24,35), ink = Color3.fromRGB(235,243,249),
        muted = Color3.fromRGB(161,184,202), blue = Color3.fromRGB(44,103,157),
        green = Color3.fromRGB(26,124,101), red = Color3.fromRGB(159,60,70)}
    local gui = make("ScreenGui", {Name = "ArenaNovaClientDiagnosticV120", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 470}, playerGui)
    D.gui = gui
    local panel = make("Frame", {Name = "Panel", Size = UDim2.fromOffset(620,554),
        Position = UDim2.fromScale(0.5,0.1), AnchorPoint = Vector2.new(0.5,0),
        BackgroundColor3 = colors.bg, BorderSizePixel = 0, Active = true}, gui)
    make("UICorner", {CornerRadius = UDim.new(0,10)}, panel)
    local camera = workspace.CurrentCamera
    if camera then make("UIScale", {Scale = math.max(0.45, math.min(1, camera.ViewportSize.X / 650, camera.ViewportSize.Y / 605))}, panel) end
    local function label(name, text, x, y, w, h, size, color)
        return make("TextLabel", {Name = name, Text = text, Position = UDim2.fromOffset(x,y),
            Size = UDim2.fromOffset(w,h), BackgroundTransparency = 1, TextColor3 = color or colors.ink,
            Font = Enum.Font.Gotham, TextSize = size or 12, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center}, panel)
    end
    local function button(name, text, x, y, w, color)
        local b = make("TextButton", {Name = name, Text = text, Position = UDim2.fromOffset(x,y),
            Size = UDim2.fromOffset(w,32), BackgroundColor3 = color or colors.blue,
            BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = colors.ink}, panel)
        make("UICorner", {CornerRadius = UDim.new(0,6)}, b)
        return b
    end
    local title = label("Heading", "ARENA NOVA / RECOVERY ARCHIVE v1.2.0", 14,8,480,28,15)
    local mini = button("Minimize", "_", 530,8,32)
    local close = button("Close", "X", 571,8,32,colors.red)
    D.ui = {
        status = label("Status", "READY - CLICK START SCAN",14,48,590,28,14),
        count = label("Counts", "Inventory first; sources second.",14,80,590,40),
        current = label("Current", "",14,123,590,34,11,colors.muted),
        path = make("TextBox", {Name = "ExportPath", Text = "", Position = UDim2.fromOffset(14,167),
            Size = UDim2.fromOffset(590,29), ClearTextOnFocus = false, TextEditable = false,
            BackgroundColor3 = Color3.fromRGB(29,41,55), TextColor3 = colors.ink,
            Font = Enum.Font.Code, TextSize = 11},panel),
        note = label("Notice", "",14,202,590,35,11,colors.muted),
    }
    local back = make("Frame", {Name = "ProgressTrack", Position = UDim2.fromOffset(14,155),
        Size = UDim2.fromOffset(590,5), BackgroundColor3 = Color3.fromRGB(43,59,76), BorderSizePixel = 0},panel)
    D.ui.bar = make("Frame", {Name = "Progress", Size = UDim2.fromScale(0,1),
        BackgroundColor3 = Color3.fromRGB(53,189,149), BorderSizePixel = 0},back)
    D.ui.start = button("Start", "SCAN LOBBY",14,246,137,colors.green)
    D.ui.pause = button("Pause", "PAUSE",164,246,140)
    D.ui.stop = button("Stop", "STOP & SAVE",317,246,138,colors.red)
    local save = button("Checkpoint", "SAVE CHECKPOINT",468,246,136)
    D.ui.mode = button("Mode", "MODE: LOBBY",14,289,170)
    label("ModeHelp", "Switch to MATCH after entering a real round; run this loader again for the second scan.",196,289,410,32,11,colors.muted)
    local copy = button("CopySummary", "COPY SUMMARY",14,332,190)
    local report = button("CopyStartup", "COPY STARTUP REPORT",216,332,190,colors.green)
    local copyPath = button("CopyPath", "COPY FOLDER NAME",418,332,186)
    label("Instructions", "Choose LOBBY or MATCH, then SCAN. ZIP the export folder from the executor workspace and upload it here.",14,372,590,42,11,colors.muted)
    D.ui.summaryScroll = make("ScrollingFrame", {Name = "SummaryScroll",Position = UDim2.fromOffset(14,423),
        Size = UDim2.fromOffset(590,114),CanvasSize = UDim2.fromOffset(0,420),ScrollBarThickness = 6,
        ScrollingDirection = Enum.ScrollingDirection.Y,ClipsDescendants = true,BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(29,41,55)},panel)
    D.ui.preview = make("TextBox", {Name = "Summary", Text = "Click START SCAN. No gameplay actions are needed.",
        Position = UDim2.fromOffset(0,0), Size = UDim2.new(1,-10,0,420),
        BackgroundColor3 = Color3.fromRGB(29,41,55), TextColor3 = colors.ink,
        ClearTextOnFocus = false, TextEditable = false, MultiLine = true, TextWrapped = false,
        Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top},D.ui.summaryScroll)
    local function connect(signal, fn)
        D.connections[#D.connections + 1] = signal:Connect(function(...)
            local ok,err = pcall(fn,...)
            if not ok then
                D.runtimeErrorKind = D.errorKind(err)
                D.notice = "Control error: " .. D.runtimeErrorKind .. ". Click COPY STARTUP REPORT."
            end
            D.safeRender(true)
        end)
    end
    -- Bind the primary action before optional dragging or background work.
    connect(D.ui.start.Activated,function() D.launch() end)
    local clickOk,mouseClick = D.read(D.ui.start,"MouseButton1Click")
    if clickOk and mouseClick then
        connect(mouseClick,function() D.launch() end)
    end
    connect(D.ui.mode.Activated, function()
        if not D.launched and not D.running then
            D.snapshotMode = D.snapshotMode == "LOBBY" and "MATCH" or "LOBBY"
        end
    end)
    connect(D.ui.pause.Activated, function() if D.running then D.paused = not D.paused end end)
    connect(save.Activated, function() if D.running then D.saveRequested = true; D.notice = "Checkpoint requested." end end)
    connect(D.ui.stop.Activated, function()
        if D.running then D.stop = true; D.paused = false; D.notice = "Stopping safely; finished files will be kept." end
    end)
    local function copyText(text)
        local ok,result = false,nil
        if API.clipboard then ok,result = pcall(API.clipboard,text) end
        if ok and result ~= false then D.notice = "Copied."
        else D.notice = "Clipboard API unavailable. Select the displayed report and copy manually." end
    end
    connect(copy.Activated, function() D.reportVisible = false; copyText(D.summary()) end)
    connect(report.Activated, function() D.reportVisible = true; copyText(D.startupReport()) end)
    connect(copyPath.Activated, function() copyText(D.root) end)
    connect(close.Activated, function()
        if not D.running then D.cleanupUI()
        else D.stop = true; D.paused = false; D.closing = true; D.notice = "Saving before closing..." end
    end)
    local minimized = false
    connect(mini.Activated, function()
        minimized = not minimized
        panel.Size = UDim2.fromOffset(620, minimized and 44 or 554)
        for _, child in ipairs(panel:GetChildren()) do
            if child:IsA("GuiObject") and child ~= title and child ~= mini and child ~= close then child.Visible = not minimized end
        end
        mini.Text = minimized and "+" or "_"
    end)
    local dragOk = pcall(function()
    local input = game:GetService("UserInputService")
    local dragStart, panelStart, dragging = nil, nil, false
    title.Active = true
    connect(title.InputBegan, function(event)
        if event.UserInputType == Enum.UserInputType.MouseButton1 or event.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, panelStart = true, event.Position, panel.Position
        end
    end)
    connect(input.InputChanged, function(event)
        if dragging and (event.UserInputType == Enum.UserInputType.MouseMovement or event.UserInputType == Enum.UserInputType.Touch) then
            local delta = event.Position - dragStart
            panel.Position = UDim2.new(panelStart.X.Scale, panelStart.X.Offset + delta.X, panelStart.Y.Scale, panelStart.Y.Offset + delta.Y)
        end
    end)
    connect(input.InputEnded, function(event)
        if event.UserInputType == Enum.UserInputType.MouseButton1 or event.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    end)
    if not dragOk then D.startupWarnings[#D.startupWarnings + 1] = "Dragging unavailable; core scan controls remain active" end
    connect(gui.Destroying, function() D.stop = true; D.paused = false end)
end
function D.cleanupUI()
    for _, connection in ipairs(D.connections) do pcall(function() connection:Disconnect() end) end
    D.connections = {}
    if D.gui then pcall(function() D.gui:Destroy() end) end
end
function D.summary()
    local lines = {
        "ARENA NOVA Complete Diagnostic v" .. CFG.version .. " | " .. D.phase,
        "Folder: " .. D.root,
        string.format("Objects %d | scripts %d | remotes/bindables %d | values %d | attributes %d",
            D.c.objects, D.c.scripts, D.c.remotes, D.c.values, D.c.attributes),
        string.format("Objects by origin heuristic: game %d | Roblox platform %d", D.categories.game,D.categories.platform),
        string.format("Sources exported %d / eligible %d | attempted %d | failed %d | pending %d",
            D.c.sourceExported,D.c.eligible,D.c.sourceAttempted,D.c.sourceFailed, math.max(0,D.c.eligible - (D.sourceTerminal or 0))),
        string.format("Payload files %d | bytes %d | read-back verified %d | unverified %d | write errors %d",
            D.payloadCount,D.filesBytes,D.verifiedCount,D.unverifiedCount,D.c.writeErrors),
        "Inventory traversal exhausted: " .. tostring(D.inventoryComplete) .. " | source pass finished: " .. tostring(D.sourcePassComplete),
        "Sources are reconstructed/accessible source with privacy filtering; they are not guaranteed original or correct.",
        "No server-only code. No remote calls or gameplay writes. Streaming means this is a time-window snapshot.",
        "Privacy exclusions/redactions and failed reads are recorded. No claim of a complete Roblox project.",
        "UPLOAD: right-click the entire export folder in Windows and compress to ZIP; upload that ZIP.",
        "For smaller ZIPs, compress every UPLOAD_PART_* folder separately and upload ALL parts, including metadata part 000.",
        "Upload folders: " .. (#D.dataParts + 1) .. " | all generated files are plain text data.",
        "Identical source bodies reused: " .. D.c.sourceBodiesReused .. " | immediate-dispatch fallbacks: " .. D.c.dispatchFallbacks,
        "Identical bytecode reconstructions reused: " .. D.c.bytecodeReused,
        "Rapid scene records: " .. D.c.rapidSceneRecords ..
            " | directly readable sources: " .. D.c.directSourceSaved,
        "Native decompile: "..D.c.nativeDecompileSuccess.." exported | "..
            D.c.nativeDecompileFailure.." unsuccessful; fallback: "..
            D.c.fallbackExported.."/"..D.c.fallbackAttempted.." recovered",
        "Deep workers started: " .. D.c.decompilerWorkersStarted ..
            " | timed out: " .. D.c.workerTimeouts ..
            " | adaptive single-worker switches: "..D.c.adaptiveSingleWorker,
    }
    local failureReasons={}
    for status,count in pairs(D.sourceStates) do
        if status~="exported" and status~="not_client_source" then
            failureReasons[#failureReasons+1]={status=status,count=count}
        end
    end
    table.sort(failureReasons,function(a,b)return a.count>b.count end)
    if #failureReasons>0 then
        lines[#lines+1]="Actual source failure categories (not property-read warnings):"
        for i=1,math.min(7,#failureReasons) do
            local item=failureReasons[i]
            lines[#lines+1]="  "..item.status.." = "..item.count
        end
    end
    lines[#lines+1]="Property read warnings (separate from decompile failures): "..D.c.propertyFailures
    if D.sourceAbortReason then lines[#lines + 1] = "Source gap reason: " .. D.sourceAbortReason end
    if D.sourcePhaseStarted then
        local seconds = math.max(0.001,os.clock() - D.sourcePhaseStarted)
        local processed = D.sourceTerminal or 0
        local rate = processed / seconds
        lines[#lines + 1] = string.format("Source phase: %.0fs | average %.1f scripts/s",seconds,rate)
        if seconds >= 3 and rate > 0 and not D.finished then
            lines[#lines + 1] = string.format("Approx. %.0f minutes remaining at that average rate (estimate)",math.max(0,D.c.eligible - processed)/rate/60)
        end
    end
    for key in pairs(D.limits) do lines[#lines + 1] = "LIMIT HIT: " .. key end
    if D.c.propertyFailures > 0 then lines[#lines + 1] = "Unavailable allowlisted property reads: " .. D.c.propertyFailures end
    local roots = {}
    for name,count in pairs(D.scriptRoots) do roots[#roots + 1] = {name = name, count = count} end
    table.sort(roots, function(a,b) return a.count > b.count end)
    lines[#lines + 1] = "Largest script roots (inventory evidence):"
    for i = 1, math.min(8,#roots) do lines[#lines + 1] = "  " .. roots[i].name .. ": " .. roots[i].count end
    return table.concat(lines,"\n")
end
function D.render()
    if not D.ui or not D.gui.Parent then return end
    D.ui.status.Text = D.phase == "ready" and ("READY - "..D.snapshotMode.." SNAPSHOT")
        or ((D.paused and "PAUSED / " or "") .. D.phase:upper())
    D.ui.start.Text = D.running and "SCAN RUNNING" or (D.launched and "RUN ENDED" or ("SCAN "..D.snapshotMode))
    D.ui.mode.Text = "MODE: "..D.snapshotMode
    D.ui.count.Text = string.format("%d objects  |  %d scripts  |  %d remotes/bindables\nSources: %d exported / %d eligible  |  %d failures  |  %d payload files saved",
        D.c.objects,D.c.scripts,D.c.remotes,D.c.sourceExported,D.c.eligible,D.c.sourceFailed,D.payloadCount)
    D.ui.current.Text = D.current
    D.ui.path.Text = D.root ~= "" and D.root or "No export folder yet"
    D.ui.note.Text = D.notice ~= "" and D.notice or ("Checkpoint every " .. CFG.checkpointSeconds .. "s. Summary is available throughout. Files stay local until you upload them.")
    D.ui.pause.Text = D.paused and "RESUME" or "PAUSE"
    local progress = 0
    if D.phase == "inventory" then progress = D.c.objects / math.max(1,D.c.objects + D.pendingDiscovered)
    elseif D.phase == "sources" then progress = (D.sourceTerminal or 0) / math.max(1,D.c.eligible)
    elseif D.finished then progress = 1 end
    D.ui.bar.Size = UDim2.fromScale(math.min(1,progress),1)
    D.ui.preview.Text = D.reportVisible and D.startupReport() or D.summary()
    local _,lineCount = D.ui.preview.Text:gsub("\n","")
    local height = math.max(89,(lineCount + 2) * 13)
    D.ui.preview.Size = UDim2.new(1,-10,0,height)
    D.ui.summaryScroll.CanvasSize = UDim2.fromOffset(0,height)
    if D.phase == "inventory" then
        D.ui.current.Text = "Visited " .. D.c.objects .. " / " .. (D.c.objects + D.pendingDiscovered) .. " discovered so far (total not yet known). " .. D.current
    end
end

-- Exports are data-only text. Windows creates the ZIP after collection.
local EXPORT_README = [[
ARENA NOVA HEAVYWEIGHT DIAGNOSTIC v1.2.0 — DATA-ONLY EXPORT

Click START SCAN in Roblox. Wait for a finished status, or click STOP & SAVE.
All generated files are plain text. There are no executable packaging helpers.

ONE ZIP (recommended):
Open executor's workspace and find the folder shown in the panel.
Right-click the ENTIRE export folder in Windows and choose:
  Show more options > Send to > Compressed (zipped) folder
Or use Compress to > ZIP file if that menu is offered.
Upload the resulting ZIP to ChatGPT. Do not upload only a summary.

SMALLER ZIPs (if the whole ZIP is too large):
Inside the export folder, zip EACH UPLOAD_PART_* folder separately using the
same Windows menu. Upload ALL those ZIPs, including UPLOAD_PART_000_METADATA.
Each part contains UPLOAD_PART.json.txt with session, part number and total.
The data parts aim for 24 MiB of payload-plus-overhead accounting, excluding
advisory metadata. A single unusually large record may exceed that target and
is explicitly marked. Ordinary data/source chunks are 256/512 KiB.

UPLOAD_PART_000_METADATA/manifest.json.txt is the authoritative latest master.
Its catalog/files_*.ndjson.txt lists every payload's root-relative path, byte
length, Adler-32 checksum and executor read-back status. Keep folder names.
When uploading individual part ZIPs, their internal paths are relative to the
folder named by UPLOAD_PART.json.txt. Reattach that prefix when reconstructing.
The master names all required parts and hashes the catalogs and controls.
The final ZIP itself is made by Windows; upload completeness and checksums can
be checked against this text metadata after upload.

Metadata checkpoints are immutable. The mutable latest manifest, latest summary,
root READ_FIRST.txt and per-folder UPLOAD_PART.json.txt are convenience/index
copies. They do not replace the authoritative cataloged payload. A crash may
leave later files unreferenced by the last intact checkpoint. Such a snapshot
is partial. No partial collection is labelled as a complete game project.

objects/{game,platform}_*.ndjson.txt: hierarchy, IDs/parent IDs, names, paths,
classes, attributes, tags, covered properties, observation times, failed reads.
scripts/*: the full known script inventory, saved before source collection.
source-results/*: one terminal outcome per known script, joined by instance ID.
sources/{game,platform}/S*_part*.source.txt: successful privacy-filtered source.
Concatenate chunks in the source-result.files order without separators. A chunk
may split a UTF-8 character; reconstruct all bytes before decoding the source.
Every eligible script retains its own outcome. Exactly equal exported text can
reference one shared file. If optional getscriptbytecode returns supported raw
Luau data, byte-for-byte identical code can reuse a verified canonical source
reconstruction. Those records are marked shared_identical_bytecode_reconstruction.
Raw bytecode is never written. Unsupported getter/format falls back to ordinary
source reconstruction. Sharing does not remove game/platform inventory entries.
attributes, values, remotes, ui, assets, focus and logs contain cross-references,
errors and deliberate exclusions. focus never replaces the full inventories.
coverage.json.txt documents the complete property schema, caps and omissions.
Sources over the size cap are explicitly not exported; no prefix is called full.

No gameplay remotes or arbitrary game modules are invoked. No gameplay values,
security identities or server checks are changed. Only our GUI and text exports
are written. Other-player/profile data, UI/chat text, credentials, authentication
APIs and debug/getgc memory are excluded. Suspicious source literals are redacted
and comments omitted before saving. Raw exception text is not exported.
This is a changing client snapshot, not an atomic Studio project. Server-only,
unreplicated, streamed-out and inaccessible content is absent. Decompilation
is optional and reconstructed source can be inaccurate. Native blocking executor
calls cannot be forcibly preempted. Pausing resumes in-session; restarting creates
a fresh folder rather than a cross-session resume.
]]

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
            schema = "arena-nova-upload-folder/1.2.0",session_id = D.session,
            part_number = part.number,total_parts = #parts,folder = part.folder,kind = part.kind,
            manifest_phase = D.phase,checkpoint = D.checkpointNumber,
            root_relative_prefix = part.folder,
            master_manifest = D.metadataFolder .. "/manifest.json.txt",
            advisory = true,
            notice = "Upload every part including metadata part 000. The selected master manifest and hashed catalogs are authoritative."}))
    end
end
function D.manifest()
    local controls, streams = {}, {}
    for _, meta in pairs(D.controls) do controls[#controls + 1] = meta end
    table.sort(controls,function(a,b) return a.path < b.path end)
    for name,stream in pairs(D.streams) do streams[name] = {chunks = stream.number, records = stream.records, buffered_bytes = stream.bytes} end
    local allSources = D.inventoryComplete and D.c.sourceExported == D.c.eligible
    return {
        schema = "arena-nova-client-diagnostic/1.2.0", version = CFG.version, session_id = D.session,
        capture_mode = D.snapshotMode, universe_id = game.GameId, root_place_id = CFG.rootPlaceId,
        rapid_scene_complete = D.rapidSceneComplete,
        place_id = game.PlaceId, started_utc = D.startedUtc, updated_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        elapsed_seconds = math.floor(os.clock() - D.started), phase = D.phase,
        inventory_traversal_exhausted = D.inventoryComplete, source_pass_finished = D.sourcePassComplete,
        all_eligible_sources_exported = allSources, exact_original_sources = false,
        privacy_filter_applied = true, snapshot_is_atomic = false,
        counts = D.c, script_counts_by_root = D.scriptRoots, instance_counts_by_class = D.classes,
        object_categories = D.categories, source_status_counts = D.sourceStates,
        source_pending = math.max(0,D.c.eligible - (D.sourceTerminal or 0)),
        source_abort_reason = D.sourceAbortReason, limits_hit = D.limits,
        last_file_failure = D.lastWriteFailure,
        checkpoint = D.checkpointNumber, source_cursor = D.sourceCursor,
        discovered_unprocessed = D.pendingDiscovered, instance_ids_assigned = D.nextId,
        files = {payload_count = D.payloadCount, payload_bytes = D.filesBytes,
            read_back_verified = D.verifiedCount, unverified = D.unverifiedCount,
            checksum_algorithm = "adler32", checksums_are_authentication = false},
        catalogs = D.catalogs, controls = controls, streams = streams,
        capabilities = {writefile = API.write ~= nil, readfile = API.read ~= nil,
            makefolder = API.mkdir ~= nil, decompile = API.decompile ~= nil,
            getloadedmodules = API.loadedModules ~= nil, getscripts = API.scripts ~= nil,
            task_cancel = API.cancel ~= nil, task_defer = API.defer ~= nil,task_spawn = API.spawn ~= nil},
        source_optimization = {scope = "all_eligible_game_and_platform_scripts",
            concurrent_decompilers = CFG.decompileWorkers,
            direct_source_prepass_complete = D.fastSourcePassComplete,
            source_queue_created = D.c.sourceQueueCreated,
            direct_source_saved = D.c.directSourceSaved,
            decompiler_workers_started = D.c.decompilerWorkersStarted,
            worker_dispatch_failures = D.c.workerDispatchFailures,
            native_timeout_seconds=CFG.nativeTimeoutSeconds,
            fallback_timeout_seconds=CFG.bytecodeFallbackTimeoutSeconds,
            bytecode_read_timeout_seconds=CFG.bytecodeReadTimeoutSeconds,
            fallback_uses_executor_native_decompile_bytecode_string=true,
            raw_bytecode_exported=false,
            shared_text_requires_byte_equality = true,cache_entry_limit = CFG.sourceDedupeMaxEntries,
            cache_source_byte_limit = CFG.sourceDedupeMaxBytes,bytecode_api = API.bytecode ~= nil,
            bytecode_reuse_requires_exact_bytes = true,raw_bytecode_exported = false,
            bytecode_cache_byte_limit = CFG.bytecodeCacheMaxBytes},
        startup_stage = D.startupStage, startup_failure_code = D.failureCode,
        api_resolution = apiOrigins,
        coverage_file = D.controls["coverage.json"] and D.controls["coverage.json"].path or nil,
        summary_file = D.controls.summary and D.controls.summary.path or nil,
        output_format = "data_only_text",upload_parts = D.partList(),
        upload_instructions = "ZIP the entire export folder in Windows, or ZIP each UPLOAD_PART_* folder separately and upload all parts including 000 metadata.",
        collection_gaps = {"server_only_and_unreplicated_content", "streamed_out_or_changed_instances",
            "privacy_exclusions", "properties_outside_explicit_schema", "inaccessible_members",
            "runtime_function_state_and_module_returns_not_inspected"},
    }
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
    D.lastCheckpointFingerprint = table.concat({
        tostring(D.c.objects),tostring(D.c.sourceExported),
        tostring(D.c.sourceFailed),tostring(D.c.remotes),
        tostring(D.sourceTerminal or 0),tostring(D.payloadCount),
        tostring(D.c.rapidSceneRecords),D.phase
    },"/")
end
function D.hasUnsavedProgress()
    return D.lastCheckpointFingerprint ~= table.concat({
        tostring(D.c.objects),tostring(D.c.sourceExported),
        tostring(D.c.sourceFailed),tostring(D.c.remotes),
        tostring(D.sourceTerminal or 0),tostring(D.payloadCount),
        tostring(D.c.rapidSceneRecords),D.phase
    },"/")
end
function D.cooperate(force)
    D.safeRender(false)
    if force or os.clock() - (D.lastYield or 0) > 0.008 then
        task.wait()
        D.lastYield = os.clock()
    end
    if D.saveRequested or (D.hasUnsavedProgress() and os.clock() - D.lastCheckpoint >= CFG.checkpointSeconds) then D.checkpoint() end
    while D.paused and not D.stop do
        D.safeRender(false)
        if D.saveRequested or (D.hasUnsavedProgress() and os.clock() - D.lastCheckpoint >= CFG.checkpointSeconds) then D.checkpoint() end
        task.wait(0.15)
    end
    local memory = D.memoryMiB()
    if memory and memory - D.memoryStart > CFG.maxMemoryGrowthMiB then
        D.limits.memory_growth = true; D.stop = true; D.sourceAbortReason = "memory_growth_limit"
    end
    return not D.stop
end
function D.preflight()
    D.stage("checking_file_apis","Checking writefile and makefolder support...")
    if not API.write or not API.mkdir then
        D.failureCode = not API.write and (not API.mkdir and "missing_writefile_and_makefolder" or "missing_writefile") or "missing_makefolder"
        error("executor must expose working writefile and makefolder APIs for a complete export. No clipboard-only collection was started.",0)
    end
    local guidOk, guid = pcall(function() return Http:GenerateGUID(false) end)
    local suffix = guidOk and guid:gsub("[^%w]", ""):sub(1,12) or (tostring(os.time()) .. "_" .. tostring(math.random(100000,999999)))
    D.session = os.date("!%Y%m%d_%H%M%S") .. "_" .. suffix
    D.root = "ARENA_NOVA_" .. D.snapshotMode .. "_v1_2_0_" .. D.session
    D.stage("creating_export_folder","Creating the export folder...")
    if API.isfolder then
        local ok, exists = pcall(API.isfolder,D.root)
        if ok and exists then D.failureCode = "export_folder_collision"; error("Export folder collision; run again to create a fresh session.",0) end
    end
    if not D.mkdir(D.root) then D.failureCode = "makefolder_failed"; error("Cannot create export folder.",0) end
    for _, name in ipairs({D.metadataFolder,D.metadataFolder .. "/catalog",D.metadataFolder .. "/checkpoints"}) do
        D.stage("creating_export_subfolders","Creating export subfolder: " .. name)
        if not D.mkdir(D.root .. "/" .. name) then D.failureCode = "makefolder_failed"; error("Cannot create export subfolder: " .. name,0) end
        D.createdFolders[name] = true
    end
    D.stage("writing_startup_probe","Testing a small file write and read-back...")
    D.control("startup-check.txt","ARENA NOVA v1.2.0 export write/read check\n")
    D.stage("writing_text_instructions","Saving data-only ZIP instructions...")
    D.control("README.txt",EXPORT_README)
    D.control("capture-mode.json",D.encode({mode=D.snapshotMode,universe_id=game.GameId,place_id=game.PlaceId,
        recorded_utc=D.startedUtc,game_id_expected=CFG.universeId,
        collection_type="read_only_client_snapshot",comparability="independent_nonatomic_snapshot"}))
    D.rawWrite("READ_FIRST.txt",EXPORT_README)
    local coverage = {
        schema = "arena-nova-client-coverage/1.2.0", configuration = CFG, properties_by_base_class = D.properties,
        snapshot_mode = D.snapshotMode,
        file_output = "Text data only. Executable packaging helpers are neither exported nor required.",
        source_eligibility = {"LocalScript", "ModuleScript", "Script with readable RunContext.Client"},
        source_methods = {"read Source property if accessible", "optional decompile(instance)",
            "reuse a verified canonical reconstruction only for byte-for-byte identical supported client bytecode"},
        source_caches = "Only eligible client containers. Raw bytecode stays in bounded memory and is never exported. Unsupported/missing APIs fall back to ordinary reconstruction. All script records and categories remain included.",
        strings = "Credentials/personal patterns redacted; arbitrary runtime prose excluded; JSON Config/Settings/Definition values decoded and field-sanitized with explicit byte/structure limits; no silent truncation",
        ui = "Text, ContentText, TextBox input and user-visible message contents are never read",
        sensitive_branches = {"other Player and character roots", "known other-player name/id branches", "Profiles/PlayerData/UserData/PrivateMessages/AuthData"},
        source_privacy = "Comments omitted; credential-like/context-sensitive/escaped literals redacted before any disk write",
        origin = "platform: CoreGui, CorePackages, RobloxReplicatedStorage/ScriptStorage or standard PlayerModule/ChatScript ancestry; game: other roots (heuristic)",
        not_attempted = {"hidden/nonscriptable property access", "server-only source", "getgc/debug memory",
            "nil-parented/executor script state", "authentication/session APIs", "remote invocation or interception",
            "require/evaluation of game modules", "terrain voxel/mesh/audio binary downloads", "localization entry text"},
        timeout_limits = "Cooperative Luau timeouts can cancel yielding workers. A blocking native executor call can stall the engine; Luau cannot guarantee preemption.",
        cancellation = "Pause/resume is in-session. Stop finalizes partial results. Restart creates a fresh folder; there is no cross-session source resume.",
        checkpoint_limits = "Files after the last intact manifest may be unreferenced after a crash. Only checkpointed data is claimed; partial files stay on disk.",
    }
    D.control("coverage.json",D.encode(coverage))
    if not API.read then D.notice = "readfile unavailable: writes cannot be checked here. Windows packer will verify every recorded file." end
    D.stage("saving_initial_checkpoint","Saving the initial manifest...")
    D.checkpoint()
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
    for _, word in ipairs({"loot", "weapon", "chest", "crate", "supply", "inventory", "hotbar",
        "damage", "health", "stamina", "block", "parry", "crouch", "sprint",
        "arena", "map", "disaster", "hazard", "barrier", "storm", "zone",
        "perks", "ability", "combat", "attack", "projectile", "heal",
        "backpack", "drop", "pickup", "survive", "round", "config"}) do
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
            D.pendingDiscovered = math.max(0,D.pendingDiscovered - 1)
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
                        D.pendingDiscovered = D.pendingDiscovered + #children
                        node.entered, node.children, node.index, node.childFrame = true,children,1,childFrame
                        stack[#stack + 1] = node
                    else
                        D.c.childFailures = D.c.childFailures + 1
                        D.log("children",D.id(node.obj),"children_unavailable")
                    end
                end
            end
        else
            D.c.duplicates = D.c.duplicates + 1
            D.pendingDiscovered = math.max(0,D.pendingDiscovered - 1)
        end
        -- O(1) discovered-item tracking: expand children once, decrement each
        -- leaf exactly once. No repeated full-stack summation per visited object.
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
function D.supplementalInventory()
    for _, item in ipairs({{name = "getloadedmodules",fn = API.loadedModules}, {name = "getscripts",fn = API.scripts}}) do
        if item.fn and not D.stop then
            local ok, list = D.boundedCall(item.fn,nil,CFG.sourceTimeoutSeconds,"Optional " .. item.name)
            if ok and type(list) == "table" then
                for _, obj in ipairs(list) do
                    if typeof(obj) == "Instance" and not D.visited[obj] then
                        local insideOk, inside = pcall(function() return obj:IsDescendantOf(game) end)
                        if insideOk and inside and not D.private(obj) then
                            -- A new module may have appeared during the first pass. Preserve ancestry.
                            local chain, cursor, steps = {},obj,0
                            while cursor and cursor ~= game and steps < CFG.maxDepth do
                                chain[#chain + 1] = cursor; steps = steps + 1
                                local valid,parent = D.read(cursor,"Parent"); cursor = valid and parent or nil
                            end
                            local frame = {path = "game",category = "game",parentId = D.id(game)}
                            for i = #chain,1,-1 do
                                local current = chain[i]
                                if D.visited[current] then
                                    local _,name = D.read(current,"Name")
                                    name = D.safeName(tostring(name))
                                    frame.path = frame.path .. "/" .. name:gsub("~","~0"):gsub("/","~1")
                                    frame.category = D.category(current,frame.category,name)
                                    frame.parentId,frame.service = D.id(current),frame.service or name
                                else
                                    if not D.walk(current,frame) then D.inventoryComplete = false end
                                    break
                                end
                            end
                        else D.c.detachedOmitted = D.c.detachedOmitted + 1 end
                    end
                    if not D.cooperate(false) then break end
                end
            else
                D.c.optionalApiFailures = D.c.optionalApiFailures + 1
                D.log(item.name,nil,ok and "invalid_return" or D.errorKind(list))
                if list == "uncancellable_worker" then break end
            end
        end
    end
end
-- Fast, read-only, bounded scene impression captured and checkpointed BEFORE
-- heavyweight hierarchy/Source work. Not a replacement for full inventory.
-- Death, despawn or a map change cannot retroactively erase this saved pass.
function D.rapidSceneCapture()
    D.phase="rapid_scene"
    D.startupStage="rapid_scene"
    D.current="Capturing immediate "..D.snapshotMode.." state before deep archive..."
    D.refreshPrivacy()
    local workspaceRoot=game:GetService("Workspace")
    local replicated=game:GetService("ReplicatedStorage")
    local roots
    if D.snapshotMode=="MATCH" then
        roots={
            {workspaceRoot,"Workspace",2600},
            {player:FindFirstChildOfClass("Backpack"),"Backpack",650},
            {replicated,"ReplicatedStorage",1800},
            {playerGui,"PlayerGui",550},
            {game:GetService("Lighting"),"Lighting",450},
            {game:GetService("StarterPack"),"StarterPack",450}
        }
    else
        roots={
            {replicated,"ReplicatedStorage",2450},
            {workspaceRoot,"Workspace",1900},
            {playerGui,"PlayerGui",700},
            {player:FindFirstChildOfClass("Backpack"),"Backpack",350},
            {game:GetService("StarterPack"),"StarterPack",500},
            {game:GetService("Lighting"),"Lighting",450}
        }
    end
    local scanned=0
    for _,spec in ipairs(roots) do
        if D.stop or scanned>=CFG.rapidMaxObjects then break end
        local root,rootName,limit=spec[1],spec[2],spec[3]
        if root then
            local queue={{obj=root,path="game/"..rootName,depth=0}}
            local head,seen=1,0
            while head<=#queue and seen<limit and scanned<CFG.rapidMaxObjects and not D.stop do
                local item=queue[head]
                queue[head]=false
                head+=1
                local obj=item.obj
                local safe,cls=pcall(function()return obj.ClassName end)
                if safe and not D.private(obj) then
                    local _,name=pcall(function()return obj.Name end)
                    name=tostring(name or "[unknown]")
                    if not D.otherIdentities[name] then
                        seen+=1
                        scanned+=1
                        D.c.rapidObjects+=1
                        local important=D.focus(item.path) or item.depth<=2 or cls=="Tool"
                            or cls=="RemoteEvent" or cls=="RemoteFunction"
                            or cls=="UnreliableRemoteEvent" or cls=="ModuleScript"
                            or cls=="LocalScript" or cls=="StringValue"
                            or cls=="NumberValue" or cls=="IntValue"
                            or cls=="BoolValue" or cls=="ObjectValue"
                        if important then
                            local attributes={}
                            local count=0
                            local ok,got=pcall(function()return obj:GetAttributes()end)
                            if ok and type(got)=="table" then
                                for key,val in pairs(got) do
                                    if count>=CFG.rapidAttributeLimit then break end
                                    count+=1
                                    local scrub=D.sensitiveKey(key) and "[redacted-key]" or D.safeName(tostring(key))
                                    attributes[scrub]=D.value(val,key,true)
                                    D.c.rapidAttributes+=1
                                end
                            end
                            local value=nil
                            if D.isa(obj,"ValueBase") then
                                local vok,v=pcall(function()return obj.Value end)
                                if vok then value=D.value(v,name,true);D.c.rapidValues+=1 end
                            end
                            local rec={name=D.stringValue(D.safeName(name),"instance_name",false),
                                class=cls,path=D.text(item.path),root=rootName,
                                depth=item.depth,attributes=attributes,value=value,
                                observed_seconds=math.floor((os.clock()-D.started)*100)/100}
                            D.emit("rapid-scene/"..D.snapshotMode:lower(),rec)
                            D.c.rapidSceneRecords+=1
                        end
                        if item.depth<CFG.rapidMaxDepth then
                            local ok,kids=pcall(function()return obj:GetChildren()end)
                            if ok and type(kids)=="table" then
                                for _,child in ipairs(kids) do
                                    local childName=child.Name
                                    if childName and not D.otherIdentities[childName] then
                                        local safeName=D.safeName(childName)
                                        queue[#queue+1]={obj=child,
                                            path=item.path.."/"..safeName:gsub("~","~0"):gsub("/","~1"),
                                            depth=item.depth+1}
                                    end
                                end
                            else D.c.rapidReadFailures+=1 end
                        end
                    end
                end
                if scanned%100==0 then
                    D.current="Immediate "..D.snapshotMode.." scene: "..scanned.." objects"
                    if not D.cooperate(false) then break end
                end
            end
            if head<=#queue then D.c.rapidLimitHit+=1 end
            D.checkpoint() -- each root becomes independently uploadable
        end
    end
    D.rapidSceneComplete=not D.stop
    D.current="Early scene captured and saved; starting full heavyweight inventory."
    D.checkpoint()
end
function D.inventory()
    D.phase = "inventory"
    D.startupStage,D.startupStep = "inventory","File checks passed; inventory is running."
    D.refreshPrivacy()
    -- Join/respawn updates keep other-player exclusions current during the scan.
    local ok, conn = pcall(function() return Players.PlayerAdded:Connect(function(other)
        if other ~= player then
            D.addPrivate(other)
            D.otherIdentities[other.Name] = true
            D.otherIdentities[tostring(other.UserId)] = true
            D.otherIdentities[other.DisplayName] = true
            D.watchers[#D.watchers + 1] = other.CharacterAdded:Connect(function(char) D.addPrivate(char) end)
        end
    end) end)
    if ok and conn then D.watchers[#D.watchers + 1] = conn end
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then
            D.watchers[#D.watchers + 1] = other.CharacterAdded:Connect(function(char) D.addPrivate(char) end)
        end
    end
    for _, name in ipairs({"ArenaNovaClientDiagnosticV120"}) do
        if playerGui:FindFirstChild(name) then
            D.log("environment",nil,"previous_tool_panel_present",{tool = name})
            D.notice = "An earlier trial/snapshot panel is present. Close it yourself for an uncontaminated new run. This scan does not stop it."
        end
    end
    D.inventoryComplete = D.walk(game,{path = "",category = "game"})
    if not D.stop then D.supplementalInventory() end
    D.current = "Inventory saved. Capturing all immediately readable source, then deep decompilation."
    D.checkpoint()
end
function D.exportSource(entry, body, method)
    local originalBytes = #body
    if originalBytes > CFG.maxSingleSourceBytes then
        D.limits.single_source_bytes = true
        D.sourceResult(entry,"oversize_not_exported",{observed_bytes = originalBytes,limit_bytes = CFG.maxSingleSourceBytes})
        D.c.sourceFailed = D.c.sourceFailed + 1
        return
    end
    local filtered, redactions, hasCode = D.filterSource(body)
    body = nil
    if not hasCode then
        D.sourceResult(entry,"empty_or_comment_only_source",{observed_bytes = originalBytes,method = method})
        D.c.sourceFailed = D.c.sourceFailed + 1
        return
    end
    local bodyHash = D.adler(filtered)
    local cacheKey = entry.category .. ":" .. #filtered .. ":" .. bodyHash
    local canReuse = API.read and #filtered <= CFG.sourceDedupeMaxBytes
    local candidates = canReuse and D.sourceCache[cacheKey] or nil
    local files,reusedFrom = nil,nil
    if candidates then
        for _,candidate in ipairs(candidates) do
            -- A 32-bit digest is only a lookup hint. Exact byte equality is
            -- mandatory, so even a deliberate checksum collision cannot alias code.
            local ok,stored = pcall(API.read,D.root .. "/" .. candidate.files[1].path)
            if ok and stored == filtered then files,reusedFrom = candidate.files,candidate.id; break end
        end
    end
    if not files then
        -- Keep room for terminal records for EVERY remaining known script.
        local metadataReserve = math.max(16777216,(#D.scripts - (D.sourceTerminal or 0)) * 768)
        if D.filesBytes + #filtered + metadataReserve > CFG.maxExportBytes then
            D.limits.export_bytes = true
            D.sourceAbortReason = "export_byte_budget"
            D.sourceResult(entry,"export_budget_not_exported",{observed_bytes = originalBytes})
            D.c.sourceFailed = D.c.sourceFailed + 1
            return
        end
        files = {}
        local number = 0
        for at = 1,#filtered,CFG.sourceChunkBytes do
            number = number + 1
            local part = filtered:sub(at,at + CFG.sourceChunkBytes - 1)
            local path = string.format("sources/%s/S%07d_part%03d.source.txt",entry.category,entry.id,number)
            files[#files + 1] = D.payload(path,part,#filtered <= CFG.sourceChunkBytes and bodyHash or nil)
            D.cooperate(false)
            -- Finish this bounded source write even if Stop was pressed, so no success
            -- record points to half of a script. No next source will be started.
        end
        if canReuse and #files == 1 and D.sourceCacheEntries < CFG.sourceDedupeMaxEntries then
            if not candidates then candidates = {}; D.sourceCache[cacheKey] = candidates end
            if #candidates < 4 then
                candidates[#candidates + 1] = {id = entry.id,files = files}
                D.sourceCacheEntries = D.sourceCacheEntries + 1
            end
        end
    else D.c.sourceBodiesReused = D.c.sourceBodiesReused + 1 end
    D.sourceResult(entry,"exported",{method = method,files = files,original_bytes = originalBytes,
        exported_bytes = #filtered,exported_adler32 = bodyHash,privacy_edits = redactions,
        source_storage = reusedFrom and "shared_exact_text" or "new_text",reused_from_id = reusedFrom,
        reconstructed = method == "decompile",original_source_guaranteed = false})
    entry.exportInfo = {files = files,exported_bytes = #filtered,exported_adler32 = bodyHash,
        privacy_edits = redactions}
    D.c.sourceExported, D.c.sourceBytes = D.c.sourceExported + 1,D.c.sourceBytes + #filtered
    if redactions > 0 then D.c.sourceRedacted = D.c.sourceRedacted + 1 end
    D.c.redactions = D.c.redactions + redactions
end
function D.findBytecodeReuse(entry)
    if not API.bytecode or not API.read then return nil,nil end
    local ok,bytes = D.boundedCall(API.bytecode,entry.instance,CFG.sourceTimeoutSeconds,
        "Fingerprint client script instance " .. entry.id)
    if not ok or type(bytes) ~= "string" or #bytes == 0 then
        D.c.bytecodeCacheFailures = D.c.bytecodeCacheFailures + 1
        D.log("bytecode_cache",entry.id,"optional_fingerprint_api_disabled")
        API.bytecode = nil
        return nil,nil
    end
    -- Recognise the raw Luau header (versions 3..14 and experimental 100 in
    -- Luau 0.747). Unknown/compressed formats fall back to ordinary decompile.
    local version,typeVersion = string.byte(bytes,1,2)
    local supported = #bytes >= 16 and ((version >= 3 and version <= 14) or version == 100)
        and (version == 3 or (typeVersion >= 1 and typeVersion <= 3))
        and bytes:find("\0",1,true)
    if not supported then
        D.c.bytecodeCacheFailures = D.c.bytecodeCacheFailures + 1
        D.log("bytecode_cache",entry.id,"unsupported_binary_format_cache_disabled")
        API.bytecode = nil
        return nil,nil
    end
    if #bytes > CFG.bytecodeCacheMaxSingleBytes then return nil,nil end
    local key = entry.category .. ":" .. #bytes .. ":" .. D.adler(bytes)
    local candidates = D.bytecodeCache[key]
    if candidates then
        for _,candidate in ipairs(candidates) do
            if candidate.bytes == bytes then
                local verified = true
                for _,file in ipairs(candidate.info.files) do
                    local readOk,body = pcall(API.read,D.root .. "/" .. file.path)
                    if not readOk or type(body) ~= "string" or #body ~= file.bytes or D.adler(body) ~= file.adler32 then
                        verified = false; break
                    end
                end
                if verified then return nil,candidate end
            end
        end
    end
    return {key = key,bytes = bytes},nil
end
function D.cacheBytecode(entry,fingerprint)
    local info = entry.exportInfo
    if fingerprint and info and D.bytecodeCacheBytes + #fingerprint.bytes <= CFG.bytecodeCacheMaxBytes then
        local list = D.bytecodeCache[fingerprint.key]
        if not list then list = {}; D.bytecodeCache[fingerprint.key] = list end
        if #list < 4 then
            list[#list + 1] = {id = entry.id,bytes = fingerprint.bytes,info = info}
            D.bytecodeCacheBytes = D.bytecodeCacheBytes + #fingerprint.bytes
        end
    end
    entry.exportInfo = nil
end
function D.exportBytecodeReuse(entry,candidate)
    local info = candidate.info
    D.sourceResult(entry,"exported",{method = "decompile_reused_identical_bytecode",files = info.files,
        exported_bytes = info.exported_bytes,exported_adler32 = info.exported_adler32,
        privacy_edits = info.privacy_edits,privacy_edits_from_canonical = true,
        source_storage = "shared_identical_bytecode_reconstruction",reused_from_id = candidate.id,
        identical_bytecode_verified = true,canonical_reconstruction = true,
        reconstructed = true,original_source_guaranteed = false})
    D.c.bytecodeReused = D.c.bytecodeReused + 1
    D.c.sourceExported = D.c.sourceExported + 1
    D.c.sourceBytes = D.c.sourceBytes + info.exported_bytes
    if info.privacy_edits > 0 then D.c.sourceRedacted = D.c.sourceRedacted + 1 end
    D.c.redactions = D.c.redactions + info.privacy_edits
end
-- Readable-source sweep is deliberately separate from slow decompilation.
-- All code already readable through Source is sealed before source workers run.
-- This is a full-content collector: no game or platform source class is
-- silently discarded merely because it has a low Arena-specific priority.
-- Two-stage decompilation is executor-compatible and evidence-labelled.
-- Stage 1: Source property sweep over every eligible script; no decompiler.
-- Stage 2: native decompile(instance) for every remaining eligible script.
-- Stage 3: for native failures only, decompile(raw_bytecode_string), supported
-- by Potassium's documented API. Raw bytes never leave volatile memory.
-- A failed native attempt is not a terminal failure until fallback is tried
-- or the required bytecode is demonstrably unavailable.
function D.collectSources()
    D.phase="sources"
    D.sourcePhaseStarted=os.clock()
    D.startupStage,D.startupStep="sources","Native source first; then bytecode recovery."
    local queue={}
    local pendingFallback={}
    D.current="Stage 1/3: saving every immediately readable source"
    for _,bucket in ipairs(D.buckets) do
        for _,entry in ipairs(bucket) do
            if not D.cooperate(false) or D.sourceAbortReason then return end
            local ok,body=D.read(entry.instance,"Source")
            if ok and type(body)=="string" and #body>0 then
                D.c.sourceAttempted+=1
                D.sourceCursor+=1
                D.exportSource(entry,body,"Source_property")
                if entry.terminal and entry.exportInfo then D.c.directSourceSaved+=1 end
                entry.instance=nil
            else
                queue[#queue+1]=entry
            end
        end
    end
    D.fastSourcePassComplete=true
    D.c.sourceQueueCreated=#queue
    D.current="Readable sources saved; native queue: "..#queue
    D.checkpoint()

    local function attemptLog(entry,method,outcome,reason,seconds)
        D.emit("source-attempts/"..entry.category,{
            id=entry.id,path=D.text(entry.path),method=method,
            outcome=outcome,reason=reason,
            seconds=math.floor((seconds or 0)*100)/100,
            error_details_withheld=true
        })
    end
    local function failFinal(entry,reason,method,firstReason)
        if entry.terminal then return end
        D.c.sourceFailed+=1
        D.c.terminalSourceFailure+=1
        D.sourceResult(entry,reason,{
            method=method or "decompile",initial_failure=firstReason,
            attempts=(method=="bytecode_fallback") and 2 or 1,
            error_details_withheld=true
        })
        D.log("source",entry.id,reason)
        entry.instance=nil
    end
    local function classify(body,method)
        if type(body)~="string" or #body==0 then return "empty_decompiler_result" end
        local prefix=body:sub(1,1400):lower()
        if prefix:match("^%s*failed to decompile")
            or prefix:match("^%s*decompilation failed")
            or prefix:match("^%s*%-%-+%s*failed to decompile")
            or prefix:match("^%s*%-%-+%s*decompilation failed")
            or prefix:match("^%s*%-%-+%s*failed to get script bytecode")
            or prefix:match("^%s*%-%-+%s*script has no bytecode")
            or prefix:match("^%s*%-%-%[%[%s*failed to decompile") then
            D.c.decompilerPlaceholders+=1
            return "decompiler_failure_placeholder"
        end
        if prefix:match("^%s*%-%-") then
            -- A source consisting entirely of comments is not a usable
            -- reconstruction. Non-comment code after a header is valid.
            local _,_,hasCode=D.filterSource(body)
            if not hasCode then return "comment_only_decompiler_result" end
        end
        return nil
    end
    local function createWorker(entry,argument,method,timeout)
        local state={entry=entry,method=method,timeout=timeout,
            t0=os.clock(),alive=true,done=false,thread=nil,ok=false,body=nil}
        local worker=coroutine.create(function()
            if not state.alive then return end
            local ok,body=pcall(API.decompile,argument)
            if state.alive then
                state.ok,state.body,state.done=ok,body,true
            end
        end)
        state.thread=worker
        local dispatcher=API.defer or API.spawn
        local sent=dispatcher and pcall(dispatcher,worker) or false
        if not sent and dispatcher~=API.spawn and API.spawn then
            sent=pcall(API.spawn,worker)
        end
        if not sent then
            state.alive=false
            D.c.workerDispatchFailures+=1
            return nil,"worker_dispatch_failed"
        end
        D.c.decompilerWorkersStarted+=1
        return state,nil
    end
    local function preserveFailure(entry,reason,method,elapsed)
        attemptLog(entry,method,"failed",reason,elapsed)
        if method=="native" then
            D.c.nativeDecompileFailure+=1
            entry.nativeFailure=reason
            if API.bytecode then
                pendingFallback[#pendingFallback+1]=entry
            else
                D.c.fallbackUnavailable+=1
                failFinal(entry,"native_failed_bytecode_api_unavailable","native",reason)
            end
        else
            failFinal(entry,reason,"bytecode_fallback",entry.nativeFailure)
        end
    end
    local fastFingerprintsEnabled=true
    local quickFingerprint
    local function workerOutcome(state,timedOut)
        local entry,method=state.entry,state.method
        local elapsed=os.clock()-state.t0
        state.alive=false
        if timedOut then
            D.c.workerTimeouts+=1
            local cancelled=false
            if API.cancel then cancelled=pcall(API.cancel,state.thread) end
            preserveFailure(entry,cancelled and "decompiler_timeout"
                or "uncancellable_decompiler_worker",method,elapsed)
            if not cancelled then D.sourceAbortReason="uncancellable_decompiler_worker" end
            return false
        end
        local reason=nil
        if not state.done or not state.ok then
            reason=D.errorKind(state.body)
        else
            reason=classify(state.body,method)
        end
        if reason then
            preserveFailure(entry,reason,method,elapsed)
            return false
        end
        D.exportSource(entry,state.body,method=="native" and "decompile"
            or "decompile_bytecode_fallback")
        if not entry.terminal or not entry.exportInfo then
            -- Failed to export even though the decompiler returned a body:
            -- the definitive failure record is already in source-results.
            attemptLog(entry,method,"export_rejected","source_rejected_by_export",elapsed)
            entry.instance=nil
            return false
        end
        attemptLog(entry,method,"exported",nil,elapsed)
        if method=="native" then
            D.c.nativeDecompileSuccess+=1
            local fp=entry.nativeFingerprint
            if not fp and fastFingerprintsEnabled then
                local reused
                reused,fp=quickFingerprint(entry)
            end
            if fp then D.cacheBytecode(entry,fp) end
            entry.nativeFingerprint=nil
        else D.c.fallbackExported+=1 end
        if method=="bytecode" and entry.fingerprint then
            D.cacheBytecode(entry,entry.fingerprint)
        end
        entry.instance=nil
        return true
    end
    -- A verified bytecode fingerprint can reuse an earlier, already-saved
    -- reconstruction without invoking the expensive decompiler again.
    -- If the executor's getter is itself slow, disable this optimization
    -- immediately rather than adding latency to every remaining script.
    quickFingerprint=function(entry)
        if not fastFingerprintsEnabled or not API.bytecode or not API.read then
            return nil,nil
        end
        local started=os.clock()
        D.c.fastFingerprintCalls+=1
        local ok,bytes=D.boundedCall(API.bytecode,entry.instance,
            CFG.quickFingerprintTimeoutSeconds,"Fast bytecode dedup "..entry.id)
        if os.clock()-started>=CFG.quickFingerprintTimeoutSeconds or not ok then
            fastFingerprintsEnabled=false
            D.c.fastFingerprintStoppedDueSlowAPI+=1
            return nil,nil
        end
        if type(bytes)~="string" or #bytes<16
            or #bytes>CFG.bytecodeCacheMaxSingleBytes then
            return nil,nil
        end
        local key=entry.category..":"..#bytes..":"..D.adler(bytes)
        local fp={key=key,bytes=bytes}
        local candidates=D.bytecodeCache[key]
        if not candidates then return nil,fp end
        for _,candidate in ipairs(candidates) do
            if candidate.bytes==bytes then
                local verified=true
                for _,file in ipairs(candidate.info.files) do
                    local v,stored=pcall(API.read,D.root.."/"..file.path)
                    if not v or type(stored)~="string"
                        or #stored~=file.bytes or D.adler(stored)~=file.adler32 then
                        verified=false
                        break
                    end
                end
                if verified then return candidate,fp end
            end
        end
        return nil,fp
    end
    local function nativePass()
        D.current="Stage 2/3: native decompilation"
        local active={}
        D.sourceWorkers=active
        local cursor=1
        local limit=math.max(1,math.min(CFG.decompileWorkers,3))
        local consecutiveUnusual=0
        while (cursor<=#queue or #active>0) and not D.stop
            and not D.sourceAbortReason do
            while cursor<=#queue and #active<limit and not D.stop do
                local entry=queue[cursor]
                cursor+=1
                D.c.sourceAttempted+=1
                D.c.queuedDecompiles+=1
                D.sourceCursor+=1
                if not API.decompile then
                    preserveFailure(entry,"decompiler_api_unavailable","native",0)
                else
                    local reusable,fp=nil,nil
                    if D.bytecodeCacheBytes>0 then
                        reusable,fp=quickFingerprint(entry)
                    end
                    if reusable then
                        D.exportBytecodeReuse(entry,reusable)
                        D.c.identicalCodeDeepDecompAvoided+=1
                        attemptLog(entry,"native","reused_identical_bytecode",nil,0)
                        entry.instance=nil
                    else
                        entry.nativeFingerprint=fp
                        local state,err=createWorker(entry,entry.instance,
                            "native",CFG.nativeTimeoutSeconds)
                        if state then
                            active[#active+1]=state
                        else
                            preserveFailure(entry,err,"native",0)
                        end
                    end
                end
                if cursor%25==0 then D.cooperate(false) end
            end
            local now=os.clock()
            for at=#active,1,-1 do
                local state=active[at]
                if state.done or now-state.t0>=state.timeout then
                    table.remove(active,at)
                    local timedOut=not state.done
                    local success=workerOutcome(state,timedOut)
                    if success then consecutiveUnusual=0
                    elseif timedOut or not state.ok then
                        consecutiveUnusual+=1
                    else consecutiveUnusual=0 end
                end
            end
            if consecutiveUnusual>=CFG.nativeAdaptiveFailures and limit>1 then
                limit=1
                D.c.adaptiveSingleWorker+=1
                D.notice="Repeated native decompiler issues: switched to one worker for stability."
            end
            D.current="Stage 2/3: "..(cursor-1).."/"..#queue..
                " native, "..#active.." active, "..#pendingFallback.." queued for recovery"
            if not D.stop and not D.sourceAbortReason then D.cooperate(true) end
        end
        for _,state in ipairs(active) do
            state.alive=false
            if API.cancel then pcall(API.cancel,state.thread) end
        end
        D.sourceWorkers={}
    end

    -- Store bytecode only in volatile memory while attempting the fallback.
    -- Potassium documents decompile(target) accepting a bytecode string.
    -- Reconstructed source is still subject to the existing privacy filter.
    local function getFallbackBytecode(entry)
        if not API.bytecode then return nil,"bytecode_api_unavailable" end
        local ok,bytes=D.boundedCall(API.bytecode,entry.instance,
            CFG.bytecodeReadTimeoutSeconds,"Bytecode fallback for source "..entry.id)
        if not ok then
            D.c.bytecodeReadErrors+=1
            return nil,bytes=="timeout" and "bytecode_read_timeout"
                or D.errorKind(bytes)
        end
        if type(bytes)~="string" or #bytes==0 then
            D.c.bytecodeReadErrors+=1
            return nil,"bytecode_empty_or_unavailable"
        end
        if #bytes>CFG.maxTemporaryBytecodeBytes then
            return nil,"bytecode_too_large_for_safe_fallback"
        end
        return bytes,nil
    end
    local function tryVerifiedReuse(entry,bytes)
        if not API.read or #bytes>CFG.bytecodeCacheMaxSingleBytes then return nil end
        local key=entry.category..":"..#bytes..":"..D.adler(bytes)
        local candidates=D.bytecodeCache[key]
        if candidates then
            for _,candidate in ipairs(candidates) do
                if candidate.bytes==bytes then
                    local verified=true
                    for _,file in ipairs(candidate.info.files) do
                        local ok,stored=pcall(API.read,D.root.."/"..file.path)
                        if not ok or type(stored)~="string" or #stored~=file.bytes
                            or D.adler(stored)~=file.adler32 then
                            verified=false
                            break
                        end
                    end
                    if verified then return candidate end
                end
            end
        end
        return nil
    end
    -- Recovery is also pipelined, not a second serial decompilation loop.
    -- Retrieval of raw bytes is bounded, and up to two fallback workers
    -- can run at once. No bytes are ever written to files.
    local function bytecodePass()
        D.current="Stage 3/3: bytecode recovery for native failures"
        D.checkpoint()
        if not API.decompile then
            for _,entry in ipairs(pendingFallback) do
                failFinal(entry,"decompiler_api_unavailable","bytecode_fallback",entry.nativeFailure)
            end
            return
        end
        local active={}
        D.sourceWorkers=active
        local cursor=1
        local limit=math.max(1,math.min(CFG.decompileWorkers,2))
        local failureStreak=0
        while (cursor<=#pendingFallback or #active>0) and not D.stop
            and not D.sourceAbortReason do
            while cursor<=#pendingFallback and #active<limit
                and not D.stop and not D.sourceAbortReason do
                local entry=pendingFallback[cursor]
                cursor+=1
                D.c.fallbackAttempted+=1
                local bytes,errorCode=getFallbackBytecode(entry)
                if not bytes then
                    D.c.fallbackUnavailable+=1
                    attemptLog(entry,"bytecode_fallback","unavailable",errorCode,0)
                    failFinal(entry,errorCode,"bytecode_fallback",entry.nativeFailure)
                else
                    local reused=tryVerifiedReuse(entry,bytes)
                    if reused then
                        D.exportBytecodeReuse(entry,reused)
                        D.c.fallbackExported+=1
                        attemptLog(entry,"bytecode_fallback","reused_identical_bytecode",nil,0)
                        entry.instance=nil
                        failureStreak=0
                    else
                        if #bytes<=CFG.bytecodeCacheMaxSingleBytes then
                            entry.fingerprint={key=entry.category..":"..#bytes..":"..D.adler(bytes),
                                bytes=bytes}
                        end
                        local state,workerError=createWorker(entry,bytes,
                            "bytecode",CFG.bytecodeFallbackTimeoutSeconds)
                        if state then
                            active[#active+1]=state
                        else
                            preserveFailure(entry,workerError,"bytecode",0)
                            entry.fingerprint=nil
                        end
                    end
                end
                bytes=nil
                if cursor%12==0 and not D.cooperate(false) then break end
            end
            local now=os.clock()
            for n=#active,1,-1 do
                local state=active[n]
                if state.done or now-state.t0>=state.timeout then
                    table.remove(active,n)
                    local timedOut=not state.done
                    local success=workerOutcome(state,timedOut)
                    state.entry.fingerprint=nil
                    if success then failureStreak=0
                    elseif timedOut or not state.ok then failureStreak+=1
                    else failureStreak=0 end
                end
            end
            if failureStreak>=CFG.nativeAdaptiveFailures and limit>1 then
                limit=1
                D.c.adaptiveSingleWorker+=1
            end
            D.current="Stage 3/3: "..(cursor-1).."/"..#pendingFallback..
                " recovery attempts, "..#active.." workers active"
            if not D.stop and not D.sourceAbortReason then D.cooperate(true) end
        end
        for _,state in ipairs(active) do
            state.alive=false
            state.entry.fingerprint=nil
            if API.cancel then pcall(API.cancel,state.thread) end
        end
        D.sourceWorkers={}
    end

    nativePass()
    if not D.stop and not D.sourceAbortReason then bytecodePass() end
    D.sourcePassComplete=not D.stop and not D.sourceAbortReason
        and (D.sourceTerminal or 0)>=D.c.eligible
end
function D.finalizePending(reason)
    for _, entry in ipairs(D.scripts) do
        if not entry.terminal then D.sourceResult(entry,reason,{attempted = false,reason = reason}) end
        entry.instance = nil
        -- Stop is deliberately ignored while sealing the known source inventory.
        if os.clock() - (D.lastYield or 0) > 0.008 then task.wait(); D.lastYield = os.clock() end
    end
end
function D.run()
    D.preflight()
    D.rapidSceneCapture()
    if not D.stop then D.inventory() end
    if not D.stop and not D.sourceAbortReason then D.collectSources() end
    local reason = D.sourceAbortReason or (D.stop and "stopped_before_source" or "not_attempted")
    D.finalizePending(reason)
    if D.stop then D.phase = "stopped_partial"
    elseif D.sourceAbortReason then D.phase = "finished_with_source_gaps"
    elseif D.c.sourceFailed > 0 or D.c.childFailures > 0 or D.c.attributeFailures > 0
        or D.c.propertyFailures > 0 or D.c.readErrors > 0 or D.c.optionalApiFailures > 0 or next(D.limits) then D.phase = "finished_with_gaps"
    else D.phase = "finished" end
    D.current = "Export sealed. Use Windows to ZIP the entire export folder."
    D.checkpoint()
    D.finished = true
    D.notice = "Saved. Right-click the displayed folder in Windows, compress to ZIP, and upload it. For smaller ZIPs, compress and upload every UPLOAD_PART_* folder."
    -- Release instance references after completion. The saved dataset remains on disk.
    D.ids,D.visited,D.scripts,D.buckets,D.privateRoots,D.otherIdentities = {},{},{},{},{},{}
    D.sourceCache = {}
    D.bytecodeCache = {}
end
function D.launch()
    if D.running or D.launched then return end
    D.startClicks = D.startClicks + 1
    D.running,D.launched,D.phase = true,true,"starting"
    D.started,D.startedUtc = os.clock(),os.date("!%Y-%m-%dT%H:%M:%SZ")
    D.memoryStart = D.memoryMiB() or 0
    D.notice = "Starting file checks. The current step is shown above."
    D.safeRender(true)
    -- Run from the user action's yieldable callback. Collection and rendering
    -- cooperate inline; startup does not depend on a spawned background worker.
    local ok, err = pcall(D.run)
    if not ok then
        D.runtimeErrorKind = D.errorKind(err)
        D.runtimeErrorLine = tostring(err):match(":(%d+):")
        if not D.failureCode then D.failureCode = D.lastWriteFailure and ("file_" .. D.lastWriteFailure.operation .. "_failed") or D.runtimeErrorKind end
        D.phase, D.stop, D.paused = "failed_partial",true,false
        D.current = "Collection stopped by an error. Completed checkpoint files were kept."
        -- Recovery must not turn a write failure into a success claim. Best effort
        -- only; latest immutable checkpoint remains the fallback if disk writes fail.
        if D.root ~= "" and API.write and D.c.writeErrors == 0 then
            pcall(function()
                D.log("pipeline",nil,"pipeline_error_or_export_write_failed",{kind = D.errorKind(err)})
                D.finalizePending("pipeline_failed_before_source")
                D.checkpoint()
            end)
        end
        if D.root ~= "" and API.write then
            pcall(function() D.metadataWrite("FAILURE.json",D.encode({phase = "failed_partial",
                reason = D.errorKind(err),limits_hit = D.limits,counts_at_failure = D.c,
                last_file_failure = D.lastWriteFailure,
                startup_stage = D.startupStage, failure_code = D.failureCode, diagnostic_source_line = D.runtimeErrorLine,
                last_checkpoint = D.checkpointNumber,
                notice = "Only the last intact manifest is authoritative. Later/uncheckpointed files may be absent from upload archives."})) end)
        end
        D.finished = true
        if D.lastWriteFailure then
            D.current = "File " .. D.lastWriteFailure.operation .. " failed: " .. D.lastWriteFailure.path
        end
        if not D.hasCheckpoint then D.current = "START FAILED: " .. D.failureCode .. " (" .. D.startupStage .. ")" end
        D.notice = "Click COPY STARTUP REPORT and send it to ChatGPT. Completed files were kept. Failure: " .. D.failureCode
        D.reportVisible = true
        warn(D.startupReport())
    end
    -- Never leave a decompiler worker belonging to a closed scan alive.
    for _,state in ipairs(D.sourceWorkers or {}) do
        state.alive=false
        if API.cancel and state.thread then pcall(API.cancel,state.thread) end
    end
    D.sourceWorkers={}
    if D.activeWorker and API.cancel then pcall(API.cancel,D.activeWorker) end
    D.activeWorker = nil
    for _, connection in ipairs(D.watchers) do pcall(function() connection:Disconnect() end) end
    D.watchers = {}
    D.ids,D.visited,D.scripts,D.buckets,D.privateRoots,D.otherIdentities = {},{},{},{},{},{}
    D.sourceCache = {}
    D.bytecodeCache = {}
    D.running = false
    D.safeRender(true)
    if D.closing then D.cleanupUI() end
end
local uiOk,uiError = pcall(D.createUI)
if not uiOk then
    D.phase,D.failureCode,D.finished = "ui_setup_failed","ui_setup_failed",true
    D.startupStage,D.startupStep = "creating_controls","Diagnostic UI setup failed"
    D.runtimeErrorKind = D.errorKind(uiError)
    D.runtimeErrorLine = tostring(uiError):match(":(%d+):")
    D.current,D.notice,D.reportVisible = "UI setup failed","Copy the startup report from the panel or executor console.",true
    warn(D.startupReport())
end
D.safeRender(true)
