-- FERAL Complete Diagnostic v3.0
-- Read-only game snapshot. Only this tool's UI and local export files are written.
-- No gameplay remote calls, hooks, arbitrary require(), hidden-property reads,
-- authentication APIs, chat history, or server-only source extraction.
-- Source reconstruction is optional and executor-dependent. See README-v3.0.md.

local CFG = {
    placeId = 108901361810209,
    version = "3.0",
    chunkBytes = 262144,
    sourceChunkBytes = 524288,
    maxBufferedBytes = 2097152,
    maxObjects = 600000,
    maxScripts = 150000,
    maxDepth = 512,
    maxSingleSourceBytes = 8388608,
    maxConfigurationJsonBytes = 1048576,
    maxDecodedConfigNodes = 100000,
    maxExportBytes = 2147483648,
    maxMemoryGrowthMiB = 256,
    sourceTimeoutSeconds = 12,
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
if playerGui:FindFirstChild("FeralCompleteDiagnosticV30") then
    warn("[FERAL v3.0] A v3.0 panel already exists. Use its controls; close it before starting a fresh run.")
    return
end
local function optional(fn) return type(fn) == "function" and fn or nil end
local API = {
    write = optional(writefile), read = optional(readfile), mkdir = optional(makefolder),
    isfolder = optional(isfolder), isfile = optional(isfile),
    decompile = optional(decompile), clipboard = optional(setclipboard) or optional(toclipboard),
    loadedModules = optional(getloadedmodules), scripts = optional(getscripts),
    cancel = optional(task.cancel), defer = optional(task.defer),
}
local D = {
    phase = "starting", started = os.clock(), startedUtc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    stop = false, paused = false, saveRequested = false, finished = false, closing = false,
    root = "", current = "Preparing export", notice = "", lastCheckpoint = 0,
    inventoryComplete = false, sourcePassComplete = false, sourceAbortReason = nil,
    ids = {}, visited = {}, nextId = 0, scripts = {}, buckets = {{}, {}, {}, {}},
    streams = {}, catalogBuffer = {}, catalogBytes = 0, catalogs = {}, controls = {},
    bufferBytes = 0, checkpointNumber = 0, catalogNumber = 0, filesBytes = 0,
    payloadCount = 0, verifiedCount = 0, unverifiedCount = 0, scriptRoots = {},
    classes = {}, sourceStates = {}, categories = {game = 0, platform = 0},
    c = {objects = 0, scripts = 0, eligible = 0, remotes = 0, values = 0,
        attributes = 0, propertyFailures = 0, attributeFailures = 0, childFailures = 0,
        readErrors = 0, writeErrors = 0, privacyRoots = 0, redactions = 0,
        sourceAttempted = 0, sourceExported = 0, sourceFailed = 0, sourceBytes = 0,
        sourceRedacted = 0, duplicates = 0, optionalApiFailures = 0, detachedOmitted = 0,
        configurations = 0, activeAnimationTracks = 0},
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
        for i = start, math.min(start + 4095, #text) do
            a = a + string.byte(text, i)
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
    return "api_error_details_withheld"
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
    local ok = pcall(API.mkdir, path)
    if ok then return true end
    if API.isfolder then
        local checked, exists = pcall(API.isfolder, path)
        return checked and exists
    end
    return false
end
function D.rawWrite(relative, body)
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
    return {path = relative, bytes = #body, adler32 = D.adler(body), read_back_verified = verified}
end
function D.flushCatalog()
    if #D.catalogBuffer == 0 then return end
    D.catalogNumber = D.catalogNumber + 1
    local meta = D.rawWrite(string.format("catalog/files_%05d.ndjson", D.catalogNumber), table.concat(D.catalogBuffer))
    D.catalogs[#D.catalogs + 1] = meta
    D.catalogBuffer, D.catalogBytes = {}, 0
end
function D.payload(path, body)
    if D.filesBytes + #body > CFG.maxExportBytes then
        D.limits.export_bytes = true
        error("Export disk budget reached; completed files preserved", 0)
    end
    local meta = D.rawWrite(path, body)
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

-- UI implementation is kept inside a closure to keep active local counts low.
function D.createUI()
    local function make(class, props, parent)
        local obj = Instance.new(class)
        for key, value in pairs(props) do obj[key] = value end
        obj.Parent = parent
        return obj
    end
    local colors = {bg = Color3.fromRGB(17,24,35), ink = Color3.fromRGB(235,243,249),
        muted = Color3.fromRGB(161,184,202), blue = Color3.fromRGB(44,103,157),
        green = Color3.fromRGB(26,124,101), red = Color3.fromRGB(159,60,70)}
    local gui = make("ScreenGui", {Name = "FeralCompleteDiagnosticV30", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 460}, playerGui)
    D.gui = gui
    local panel = make("Frame", {Name = "Panel", Size = UDim2.fromOffset(620,440),
        Position = UDim2.fromScale(0.5,0.1), AnchorPoint = Vector2.new(0.5,0),
        BackgroundColor3 = colors.bg, BorderSizePixel = 0, Active = true}, gui)
    make("UICorner", {CornerRadius = UDim.new(0,10)}, panel)
    local camera = workspace.CurrentCamera
    if camera then make("UIScale", {Scale = math.max(0.45, math.min(1, camera.ViewportSize.X / 650, camera.ViewportSize.Y / 490))}, panel) end
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
    local title = label("Heading", "FERAL  /  COMPLETE DIAGNOSTIC  v3.0", 14,8,480,28,15)
    local mini = button("Minimize", "_", 530,8,32)
    local close = button("Close", "X", 571,8,32,colors.red)
    D.ui = {
        status = label("Status", "Checking export capabilities...",14,48,590,28,14),
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
    D.ui.pause = button("Pause", "PAUSE",14,246,137)
    local save = button("Checkpoint", "SAVE CHECKPOINT",164,246,140)
    D.ui.stop = button("Stop", "STOP & SAVE",317,246,138,colors.red)
    local copy = button("CopySummary", "COPY SUMMARY",468,246,136,colors.green)
    local copyPath = button("CopyPath", "COPY FOLDER NAME",14,289,190)
    label("Instructions", "When finished: open this folder in Velocity's workspace and double-click Pack-FERAL.cmd. Upload every ZIP plus UPLOAD_INDEX.json.",216,286,388,42,11,colors.muted)
    D.ui.preview = make("TextBox", {Name = "Summary", Text = "No gameplay actions are needed. Collection starts automatically.",
        Position = UDim2.fromOffset(14,337), Size = UDim2.fromOffset(590,89),
        BackgroundColor3 = Color3.fromRGB(29,41,55), TextColor3 = colors.ink,
        ClearTextOnFocus = false, TextEditable = false, MultiLine = true, TextWrapped = false,
        Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top},panel)
    local function connect(signal, fn) D.connections[#D.connections + 1] = signal:Connect(fn) end
    connect(D.ui.pause.Activated, function() if not D.finished then D.paused = not D.paused end end)
    connect(save.Activated, function() if not D.finished then D.saveRequested = true; D.notice = "Checkpoint requested." end end)
    connect(D.ui.stop.Activated, function()
        if not D.finished then D.stop = true; D.paused = false; D.notice = "Stopping safely; finished files will be kept." end
    end)
    local function copyText(text)
        if API.clipboard and pcall(API.clipboard,text) then D.notice = "Copied."
        else D.ui.preview.Text = text; D.notice = "Clipboard API unavailable. Select the displayed text manually." end
    end
    connect(copy.Activated, function() copyText(D.summary()) end)
    connect(copyPath.Activated, function() copyText(D.root) end)
    connect(close.Activated, function()
        if D.finished then D.cleanupUI()
        else D.stop = true; D.paused = false; D.closing = true; D.notice = "Saving before closing..." end
    end)
    local minimized = false
    connect(mini.Activated, function()
        minimized = not minimized
        panel.Size = UDim2.fromOffset(620, minimized and 44 or 440)
        for _, child in ipairs(panel:GetChildren()) do
            if child:IsA("GuiObject") and child ~= title and child ~= mini and child ~= close then child.Visible = not minimized end
        end
        mini.Text = minimized and "+" or "_"
    end)
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
    connect(gui.Destroying, function() D.stop = true; D.paused = false end)
end
function D.cleanupUI()
    for _, connection in ipairs(D.connections) do pcall(function() connection:Disconnect() end) end
    D.connections = {}
    if D.gui then pcall(function() D.gui:Destroy() end) end
end
function D.summary()
    local lines = {
        "FERAL Complete Diagnostic v3.0 | " .. D.phase,
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
        "UPLOAD: double-click Pack-FERAL.cmd in the export folder; send ALL ZIPs plus UPLOAD_INDEX.json.",
    }
    if D.sourceAbortReason then lines[#lines + 1] = "Source gap reason: " .. D.sourceAbortReason end
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
    D.ui.status.Text = (D.paused and "PAUSED / " or "") .. D.phase:upper()
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
    D.ui.preview.Text = D.summary()
    if D.phase == "inventory" then
        D.ui.current.Text = "Visited " .. D.c.objects .. " / " .. (D.c.objects + D.pendingDiscovered) .. " discovered so far (total not yet known). " .. D.current
    end
end

-- Embedded Windows packer is inserted by the repository build check.
local PACKER = [====[
# FERAL v3.0 - local export verification and independent upload ZIP parts.
# Windows PowerShell 5.1 / PowerShell 7. No network requests or game interaction.
[CmdletBinding()]
param(
    [string]$ExportFolder = $PSScriptRoot,
    [ValidateRange(8, 512)][int]$PartMiB = 48
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (-not ('FeralAdler32' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
public static class FeralAdler32 {
    public static string FileHash(string path) {
        uint a = 1, b = 0;
        byte[] buffer = new byte[65536];
        using (FileStream stream = File.OpenRead(path)) {
            int count;
            while ((count = stream.Read(buffer, 0, buffer.Length)) > 0) {
                for (int start = 0; start < count; start += 4096) {
                    int end = Math.Min(start + 4096, count);
                    for (int i = start; i < end; i++) { a += buffer[i]; b += a; }
                    a %= 65521; b %= 65521;
                }
            }
        }
        return ((b << 16) | a).ToString("x8");
    }
}
'@
}
$root = [IO.Path]::GetFullPath($ExportFolder).TrimEnd([IO.Path]::DirectorySeparatorChar)
$rootPrefix = $root + [IO.Path]::DirectorySeparatorChar
function Resolve-ExportPath([string]$relative) {
    if ([string]::IsNullOrWhiteSpace($relative) -or $relative.Contains(':') -or $relative.Contains('\') -or $relative.StartsWith('/')) {
        throw "Unsafe export path: $relative"
    }
    $absolute = [IO.Path]::GetFullPath((Join-Path $root $relative))
    if (-not $absolute.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Export path leaves its folder: $relative"
    }
    return $absolute
}
function Read-Json([string]$path) {
    return ([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json)
}
$manifestPath = Join-Path $root 'manifest.json'
$usedFallback = $false
try {
    $manifest = Read-Json $manifestPath
    if ($manifest.schema -ne 'feral-diagnostic/3.0') { throw 'Unexpected manifest schema.' }
} catch {
    # The latest immutable checkpoint survives an interrupted manifest.json write.
    $candidates = @(Get-ChildItem -LiteralPath (Join-Path $root 'checkpoints') -Filter 'manifest_*.json' -File | Sort-Object Name -Descending)
    $found = $false
    foreach ($candidate in $candidates) {
        try {
            $possible = Read-Json $candidate.FullName
            if ($possible.schema -eq 'feral-diagnostic/3.0') {
                $manifest = $possible
                $manifestPath = $candidate.FullName
                $found = $true
                break
            }
        } catch { }
    }
    if (-not $found) { throw 'No valid FERAL manifest. Let the diagnostic save a checkpoint first.' }
    $usedFallback = $true
    Write-Warning "Using checkpoint $($candidate.Name); later uncheckpointed files are not claimed as collected."
}
if ($manifest.phase -eq 'inventory' -or $manifest.phase -eq 'sources' -or $manifest.phase -eq 'starting') {
    Write-Warning 'Packing an unfinished checkpoint only. Later files are not included. Stop & save in Roblox for the latest final export.'
}
$entries = New-Object 'System.Collections.Generic.List[object]'
$seen = @{}
function Add-VerifiedFile($descriptor) {
    $relative = [string]$descriptor.path
    if ($seen.ContainsKey($relative)) { throw "Duplicate manifest path: $relative" }
    $absolute = Resolve-ExportPath $relative
    if (-not [IO.File]::Exists($absolute)) { throw "Missing file: $relative" }
    $actualBytes = (Get-Item -LiteralPath $absolute).Length
    if ($actualBytes -ne [long]$descriptor.bytes) { throw "Size mismatch: $relative" }
    if (([FeralAdler32]::FileHash($absolute)) -ne [string]$descriptor.adler32) { throw "Checksum mismatch: $relative" }
    $seen[$relative] = $true
    $entries.Add([pscustomobject]@{ path = $relative; bytes = $actualBytes; absolute = $absolute; adler32 = [string]$descriptor.adler32 })
}
Write-Host 'Checking all catalogues and data files...'
foreach ($catalog in @($manifest.catalogs)) {
    Add-VerifiedFile $catalog
    $catalogPath = Resolve-ExportPath ([string]$catalog.path)
    foreach ($line in [IO.File]::ReadLines($catalogPath, [Text.Encoding]::UTF8)) {
        if ($line.Length -gt 0) { Add-VerifiedFile ($line | ConvertFrom-Json) }
    }
}
foreach ($control in @($manifest.controls)) { Add-VerifiedFile $control }
if (($entries.Count - @($manifest.catalogs).Count - @($manifest.controls).Count) -ne [long]$manifest.files.payload_count) {
    throw 'Catalogue entry count differs from the manifest.'
}
$failurePath = Join-Path $root 'FAILURE.json'
if ([IO.File]::Exists($failurePath)) {
    Write-Warning 'The diagnostic reported a pipeline failure. This archive contains the last checkpoint and FAILURE.json; it is a partial collection.'
    Add-VerifiedFile ([pscustomobject]@{ path = 'FAILURE.json'; bytes = (Get-Item -LiteralPath $failurePath).Length; adler32 = [FeralAdler32]::FileHash($failurePath) })
}
# Use the selected immutable snapshot, even when the mutable latest manifest was damaged.
$manifestBytes = [IO.File]::ReadAllBytes($manifestPath)
$target = [long]$PartMiB * 1MB - 1MB
if ($manifestBytes.Length -ge $target) { throw 'Manifest exceeds the ZIP target. Increase -PartMiB.' }
$parts = New-Object 'System.Collections.Generic.List[object]'
$batch = New-Object 'System.Collections.Generic.List[object]'
$batchBytes = [long]$manifestBytes.Length
foreach ($entry in $entries) {
    # Data chunks are <= 512 KiB, so no normal item needs a larger archive.
    if ($entry.bytes + $manifestBytes.Length -gt $target) { throw "File exceeds the ZIP target: $($entry.path). Increase -PartMiB." }
    $entryCost = [long]$entry.bytes + 256 + [Text.Encoding]::UTF8.GetByteCount($entry.path) * 2
    if ($batch.Count -gt 0 -and $batchBytes + $entryCost -gt $target) {
        $parts.Add(@($batch.ToArray()))
        $batch = New-Object 'System.Collections.Generic.List[object]'
        $batchBytes = [long]$manifestBytes.Length
    }
    $batch.Add($entry)
    $batchBytes += $entryCost
}
if ($batch.Count -gt 0) { $parts.Add(@($batch.ToArray())) }
if ($parts.Count -eq 0) { throw 'No export files were recorded.' }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$destination = Join-Path ([IO.Directory]::GetParent($root).FullName) ((Split-Path $root -Leaf) + '_UPLOAD_' + $stamp + '_' + [Guid]::NewGuid().ToString('N').Substring(0,6))
[void][IO.Directory]::CreateDirectory($destination)
$indexParts = New-Object 'System.Collections.Generic.List[object]'
$partNumber = 0
foreach ($part in $parts) {
    $partNumber++
    $zipName = 'FERAL_v3_part{0:D3}_of{1:D3}.zip' -f $partNumber, $parts.Count
    $zipPath = Join-Path $destination $zipName
    Write-Host "Creating $zipName..."
    $zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $manifestEntry = $zip.CreateEntry('manifest.json', [IO.Compression.CompressionLevel]::Optimal)
        $stream = $manifestEntry.Open()
        try { $stream.Write($manifestBytes, 0, $manifestBytes.Length) } finally { $stream.Dispose() }
        foreach ($entry in $part) {
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $entry.absolute, $entry.path, [IO.Compression.CompressionLevel]::Optimal)
        }
        $partInfo = [ordered]@{ session_id = $manifest.session_id; part = $partNumber; total_parts = $parts.Count; manifest_phase = $manifest.phase; used_checkpoint_fallback = $usedFallback; pipeline_failure_reported = [IO.File]::Exists($failurePath); files = @($part | ForEach-Object { $_.path }) }
        $partEntry = $zip.CreateEntry('UPLOAD_PART.json')
        $writer = New-Object IO.StreamWriter($partEntry.Open(), (New-Object Text.UTF8Encoding($false)))
        try { $writer.Write(($partInfo | ConvertTo-Json -Depth 8)) } finally { $writer.Dispose() }
    } finally { $zip.Dispose() }
    # Read every archived byte back and compare it with its expected checksum.
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        if ($zip.Entries.Count -ne @($part).Count + 2) { throw "ZIP entry count mismatch: $zipName" }
        foreach ($entry in $part) {
            $archived = $zip.GetEntry($entry.path)
            if ($null -eq $archived -or $archived.Length -ne $entry.bytes) { throw "ZIP entry missing or wrong size: $($entry.path)" }
            $scratchPath = Join-Path $destination '.verify.tmp'
            $archiveInput = $archived.Open()
            $archiveOutput = [IO.File]::Create($scratchPath)
            try { $archiveInput.CopyTo($archiveOutput) } finally { $archiveOutput.Dispose(); $archiveInput.Dispose() }
            try {
                if (([FeralAdler32]::FileHash($scratchPath)) -ne $entry.adler32) { throw "ZIP checksum mismatch: $($entry.path)" }
            } finally { if ([IO.File]::Exists($scratchPath)) { [IO.File]::Delete($scratchPath) } }
        }
    } finally { $zip.Dispose() }
    $indexParts.Add([ordered]@{ file = $zipName; bytes = (Get-Item -LiteralPath $zipPath).Length; sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant(); files = @($part | ForEach-Object { $_.path }) })
}
$index = [ordered]@{ schema = 'feral-upload/3.0'; session_id = $manifest.session_id; manifest_phase = $manifest.phase; used_checkpoint_fallback = $usedFallback; pipeline_failure_reported = [IO.File]::Exists($failurePath); total_parts = $parts.Count; verification = 'All manifest data files and archived payload bytes verified'; parts = @($indexParts.ToArray()) }
[IO.File]::WriteAllText((Join-Path $destination 'UPLOAD_INDEX.json'), ($index | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
Write-Host "Verified $($entries.Count) files. Export phase: $($manifest.phase)."
Write-Host "Upload ALL $($parts.Count) ZIP file(s) and UPLOAD_INDEX.json from:"
Write-Host $destination
if ($env:OS -eq 'Windows_NT') { Start-Process explorer.exe -ArgumentList ('"' + $destination + '"') }
]====]
local PACK_CMD = "@echo off\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%~dp0Pack-FERAL.ps1\"\r\nif errorlevel 1 echo Packaging failed. Read the error above; the original export was kept.\r\npause\r\n"
local EXPORT_README = [[FERAL COMPLETE DIAGNOSTIC v3.0

1. Wait for the Roblox panel to finish, or click STOP & SAVE.
2. Open this folder inside Velocity's workspace. Its location is set by Velocity;
   this tool cannot assume a particular installation path.
3. Double-click Pack-FERAL.cmd. It runs the included local PowerShell script.
4. The script verifies the manifest, file sizes and Adler-32 checksums, creates
   independent ZIPs (48 MiB target), verifies their payloads, and opens the output.
5. Upload ALL FERAL_v3_partNNN_ofNNN.zip files AND UPLOAD_INDEX.json to ChatGPT.
   Each ZIP contains the master manifest and a numbered UPLOAD_PART.json.
   These are independent archives, not multipart .zip.001 files. Preserve names.

If Windows blocks scripts, right-click this folder, choose Compress to ZIP file
and upload that ZIP, or run the visible Pack-FERAL.ps1 from PowerShell with:
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Pack-FERAL.ps1
For smaller upload parts add: -PartMiB 16
Do not run the packer while the diagnostic is actively writing.

manifest.json is the latest master manifest. checkpoints/manifest_NNNNN.json
holds immutable prior manifests. The packer can fall back if the latest JSON is
damaged, but never claims later uncheckpointed files were collected. An active
checkpoint can be zipped manually after a Roblox crash; it is explicitly partial.

catalog/files_*.ndjson lists every payload path, byte length, Adler-32 checksum,
and whether executor read-back was available. Catalog checksums live in the
manifest. Adler-32 checks accidental corruption; it is not an authenticity hash.
The packer also records SHA-256 hashes of the final ZIPs in UPLOAD_INDEX.json.

objects/{game,platform}_*.ndjson: id, parent_id, name, class, path, attributes,
tags, allowlisted properties, and unavailable property/read information.
scripts/{game,platform}_*.ndjson: complete discovered script inventory.
source-results/{game,platform}_*.ndjson: one terminal record per known script.
Join by instance id; source inventory does not depend on decompiler success.
sources/{game,platform}/SNNNNNNN_partNNN.lua: reconstructed/readable sources.
Concatenate chunks in source-result.files order, without separators. They may
split a UTF-8 character; only the concatenated source is a complete text stream.
Sources have privacy filtering. No source is silently cut to a byte limit.
An oversize source is explicitly not exported, with its observed byte count.
attributes, values, remotes, ui, assets, and focus folders provide cross-references
for analysis. focus is supplementary; it never replaces the full inventories.
JSON configuration strings named Config/Settings/Definition are decoded and
field-sanitized, with explicit structure/byte exclusions. Active Animator tracks
are sampled read-only into assets; they can be outside the instance hierarchy.
logs/errors: all recorded failures with structured reasons. Raw exception text
is withheld because it can contain source snippets or private runtime values.
coverage.json: property schema, capabilities, limits and deliberate exclusions.
SUMMARY.txt: concise latest status, useful before source reconstruction finishes.

Game/platform classification is a location/name heuristic, not proof of author.
Platform sources are included after game sources. Counts by root in the manifest
show whether CorePackages/CoreGui account for most of the script population.

Read-only means no gameplay properties, attributes, remote calls or arbitrary
modules are executed. Only this tool's GUI and local files are created/updated.
No authentication/session APIs, chat history, UI Text contents, hidden property
APIs, getgc/debug memory extraction, or other players' data are collected.
Other Player/character roots, private-data branches, sensitive field values,
unclassified runtime strings and credential-like literals are explicitly omitted.
All source comments are removed, and suspicious/escaped literals are redacted.
These privacy changes are counted; raw unfiltered code is never saved.

This is a time-window snapshot of exposed client data, not an atomic snapshot,
the original Studio place, or a guarantee that every possible property exists.
Server-only source, unreplicated data, streamed-out objects, function closures,
module return values, remote traffic/arguments and inaccessible members are absent.
These omissions also mean a snapshot cannot by itself prove why a server changed
a particular health or stamina value; analysis must distinguish evidence from
inferences about unavailable server logic.
No HTTP uploads are performed. The launcher downloads this tool; it does not send
diagnostic data to GitHub or elsewhere. Review the files before sharing them.
]]

function D.control(path, body)
    D.controls[path] = D.rawWrite(path,body)
end
function D.manifest()
    local controls, streams = {}, {}
    for _, meta in pairs(D.controls) do controls[#controls + 1] = meta end
    table.sort(controls,function(a,b) return a.path < b.path end)
    for name,stream in pairs(D.streams) do streams[name] = {chunks = stream.number, records = stream.records, buffered_bytes = stream.bytes} end
    local allSources = D.inventoryComplete and D.c.sourceExported == D.c.eligible
    return {
        schema = "feral-diagnostic/3.0", version = CFG.version, session_id = D.session,
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
            task_cancel = API.cancel ~= nil, task_defer = API.defer ~= nil},
        coverage_file = "coverage.json", summary_file = D.controls.summary and D.controls.summary.path or nil,
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
    D.controls.summary = D.rawWrite(string.format("checkpoints/SUMMARY_%05d.txt",D.checkpointNumber),summary)
    D.rawWrite("SUMMARY.txt",summary)
    local body = D.encode(D.manifest())
    -- Manifests cannot contain their own checksum. They describe all payloads and controls.
    D.rawWrite(string.format("checkpoints/manifest_%05d.json", D.checkpointNumber),body)
    D.rawWrite("manifest.json",body)
    D.hasCheckpoint = true
    D.lastCheckpoint, D.saveRequested = os.clock(), false
end
function D.cooperate(force)
    if force or os.clock() - (D.lastYield or 0) > 0.008 then
        task.wait()
        D.lastYield = os.clock()
    end
    if D.saveRequested or os.clock() - D.lastCheckpoint >= CFG.checkpointSeconds then D.checkpoint() end
    while D.paused and not D.stop do
        if D.saveRequested or os.clock() - D.lastCheckpoint >= CFG.checkpointSeconds then D.checkpoint() end
        task.wait(0.15)
    end
    local memory = D.memoryMiB()
    if memory and memory - D.memoryStart > CFG.maxMemoryGrowthMiB then
        D.limits.memory_growth = true; D.stop = true; D.sourceAbortReason = "memory_growth_limit"
    end
    return not D.stop
end
function D.preflight()
    if not API.write or not API.mkdir then
        error("Velocity must expose working writefile and makefolder APIs for a complete export. No clipboard-only collection was started.",0)
    end
    local guidOk, guid = pcall(function() return Http:GenerateGUID(false) end)
    local suffix = guidOk and guid:gsub("[^%w]", ""):sub(1,12) or (tostring(os.time()) .. "_" .. tostring(math.random(100000,999999)))
    D.session = os.date("!%Y%m%d_%H%M%S") .. "_" .. suffix
    D.root = "FERAL_Complete_Diagnostic_v3_0_" .. D.session
    if API.isfolder then
        local ok, exists = pcall(API.isfolder,D.root)
        if ok and exists then error("Export folder collision; run again to create a fresh session.",0) end
    end
    if not D.mkdir(D.root) then error("Cannot create export folder.",0) end
    for _, name in ipairs({"catalog", "checkpoints", "objects", "scripts", "source-results", "sources",
        "sources/game", "sources/platform", "attributes", "values", "remotes", "ui", "assets", "focus", "logs"}) do
        if not D.mkdir(D.root .. "/" .. name) then error("Cannot create export subfolder: " .. name,0) end
    end
    D.control("Pack-FERAL.ps1",PACKER)
    D.control("Pack-FERAL.cmd",PACK_CMD)
    D.control("README.txt",EXPORT_README)
    local coverage = {
        schema = "feral-coverage/3.0", configuration = CFG, properties_by_base_class = D.properties,
        source_eligibility = {"LocalScript", "ModuleScript", "Script with readable RunContext.Client"},
        source_methods = {"read Source property if accessible", "optional decompile(instance)"},
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
    if not API.defer then return false,"deferred_workers_unavailable" end
    local token = {alive = true,done = false}
    local worker = API.defer(function()
        local ok,result = pcall(fn,argument)
        if token.alive then token.ok,token.result,token.done = ok,result,true end
    end)
    D.activeWorker = worker
    local begin = os.clock()
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
function D.inventory()
    D.phase = "inventory"
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
    for _, name in ipairs({"FeralAlwaysRegenTrialV22", "FeralAlwaysRegenTrialV23", "FeralClientSnapshotV24", "FeralClientSnapshotV25", "FeralClientSnapshotV26"}) do
        if playerGui:FindFirstChild(name) then
            D.log("environment",nil,"previous_tool_panel_present",{tool = name})
            D.notice = "An earlier trial/snapshot panel is present. Close it yourself for an uncontaminated new run. This scan does not stop it."
        end
    end
    D.inventoryComplete = D.walk(game,{path = "",category = "game"})
    if not D.stop then D.supplementalInventory() end
    D.current = "Inventory saved. Starting game sources, then Roblox platform sources."
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
    -- Keep room for terminal records for EVERY remaining known script.
    local metadataReserve = math.max(16777216,(#D.scripts - (D.sourceTerminal or 0)) * 768)
    if D.filesBytes + #filtered + metadataReserve > CFG.maxExportBytes then
        D.limits.export_bytes = true
        D.sourceAbortReason = "export_byte_budget"
        D.sourceResult(entry,"export_budget_not_exported",{observed_bytes = originalBytes})
        D.c.sourceFailed = D.c.sourceFailed + 1
        return
    end
    local files = {}
    local number = 0
    for at = 1,#filtered,CFG.sourceChunkBytes do
        number = number + 1
        local part = filtered:sub(at,at + CFG.sourceChunkBytes - 1)
        local path = string.format("sources/%s/S%07d_part%03d.lua",entry.category,entry.id,number)
        files[#files + 1] = D.payload(path,part)
        D.cooperate(true)
        -- Finish this bounded source write even if Stop was pressed, so no success
        -- record points to half of a script. No next source will be started.
    end
    D.sourceResult(entry,"exported",{method = method,files = files,original_bytes = originalBytes,
        exported_bytes = #filtered,exported_adler32 = D.adler(filtered),privacy_edits = redactions,
        reconstructed = method == "decompile",original_source_guaranteed = false})
    D.c.sourceExported, D.c.sourceBytes = D.c.sourceExported + 1,D.c.sourceBytes + #filtered
    if redactions > 0 then D.c.sourceRedacted = D.c.sourceRedacted + 1 end
    D.c.redactions = D.c.redactions + redactions
end
function D.collectSources()
    D.phase = "sources"
    local timeoutStreak = 0
    for _, bucket in ipairs(D.buckets) do
        for _, entry in ipairs(bucket) do
            if not D.cooperate(true) or D.sourceAbortReason then return end
            D.sourceCursor = D.sourceCursor + 1
            D.c.sourceAttempted = D.c.sourceAttempted + 1
            D.current = "Source " .. D.sourceCursor .. " / " .. D.c.eligible .. " | " .. entry.category .. " | instance " .. entry.id
            -- Source property access may be denied; no security identity changes are used.
            local ok, body = D.read(entry.instance,"Source")
            local method = "Source_property"
            if not ok or type(body) ~= "string" or body == "" then
                if API.decompile then
                    ok, body = D.boundedCall(API.decompile,entry.instance,CFG.sourceTimeoutSeconds,
                        "Decompile " .. entry.category .. " instance " .. entry.id)
                    method = "decompile"
                else ok,body = false,"source_unavailable_no_decompiler" end
            end
            if ok and type(body) == "string" and #body > 0 then
                timeoutStreak = 0
                D.exportSource(entry,body,method)
            else
                D.c.sourceFailed = D.c.sourceFailed + 1
                local reason = body == "timeout" and "timeout" or body == "cancelled" and "cancelled"
                    or body == "uncancellable_worker" and "uncancellable_worker"
                    or body == "source_unavailable_no_decompiler" and "source_unavailable_no_decompiler"
                    or (ok and "empty_or_invalid_source" or D.errorKind(body))
                D.sourceResult(entry,reason,{method = method,error_details_withheld = true})
                D.log("source",entry.id,reason)
                if reason == "timeout" then timeoutStreak = timeoutStreak + 1 else timeoutStreak = 0 end
                if timeoutStreak >= CFG.maxConsecutiveTimeouts then
                    D.sourceAbortReason = "repeated_decompiler_timeouts"; return
                end
            end
            entry.instance = nil
        end
    end
    D.sourcePassComplete = true
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
    D.inventory()
    if not D.stop and not D.sourceAbortReason then D.collectSources() end
    local reason = D.sourceAbortReason or (D.stop and "stopped_before_source" or "not_attempted")
    D.finalizePending(reason)
    if D.stop then D.phase = "stopped_partial"
    elseif D.sourceAbortReason then D.phase = "finished_with_source_gaps"
    elseif D.c.sourceFailed > 0 or D.c.childFailures > 0 or D.c.attributeFailures > 0
        or D.c.propertyFailures > 0 or D.c.readErrors > 0 or D.c.optionalApiFailures > 0 or next(D.limits) then D.phase = "finished_with_gaps"
    else D.phase = "finished" end
    D.current = "Export sealed. Pack-FERAL.cmd verifies and packages the collected dataset."
    D.checkpoint()
    D.finished = true
    D.notice = "Saved. Open the displayed folder in Velocity's workspace, then double-click Pack-FERAL.cmd. Upload all ZIPs and UPLOAD_INDEX.json."
    -- Release instance references after completion. The saved dataset remains on disk.
    D.ids,D.visited,D.scripts,D.buckets,D.privateRoots,D.otherIdentities = {},{},{},{},{},{}
end
D.createUI()
task.spawn(function()
    while D.gui and D.gui.Parent and not D.finished do D.render(); task.wait(0.25) end
    D.render()
end)
task.spawn(function()
    local ok, err = pcall(D.run)
    if not ok then
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
            pcall(function() D.rawWrite("FAILURE.json",D.encode({phase = "failed_partial",
                reason = D.errorKind(err),limits_hit = D.limits,counts_at_failure = D.c,
                last_file_failure = D.lastWriteFailure,
                last_checkpoint = D.checkpointNumber,
                notice = "Only the last intact manifest is authoritative. Later/uncheckpointed files may be absent from upload archives."})) end)
        end
        D.finished = true
        if D.lastWriteFailure then
            D.current = "File " .. D.lastWriteFailure.operation .. " failed: " .. D.lastWriteFailure.path
        end
        D.notice = not D.hasCheckpoint and "No verified checkpoint was created. Check Velocity's writefile/makefolder/readfile support. No clipboard substitute was used."
            or "Partial export only. Check manifest.json, FAILURE.json and the last checkpoint; do not treat it as a finished collection."
        warn("[FERAL v3.0] Failed/partial export. Folder: " .. D.root .. ". Review the panel and checkpoint manifest.")
    end
    if D.activeWorker and API.cancel then pcall(API.cancel,D.activeWorker) end
    D.activeWorker = nil
    for _, connection in ipairs(D.watchers) do pcall(function() connection:Disconnect() end) end
    D.watchers = {}
    D.ids,D.visited,D.scripts,D.buckets,D.privateRoots,D.otherIdentities = {},{},{},{},{},{}
    D.render()
    if D.closing then D.cleanupUI() end
end)
