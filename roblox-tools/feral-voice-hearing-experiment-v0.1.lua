-- FERAL Voice Hearing v0.1 | optional client-side audio trial.
-- Only touches default voice AudioEmitters belonging to remote players.
-- Does not capture, store, redirect, record or transmit microphone audio.
-- Does not alter AudioDeviceInput, AudioInteractionGroup, chat groups, input,
-- the minigame scheduler, character movement or game remotes.
local options = ...
if type(options) ~= "table" then options = {} end

local function finite(n)
    return type(n) == "number" and n == n and n >= 0 and n < 1e9
end
local function cloneCurve(source)
    if type(source) ~= "table" then return nil end
    local curve = {}
    local count = 0
    for distance, volume in pairs(source) do
        if not finite(distance) or not finite(volume) or volume > 1 then return nil end
        curve[distance] = volume
        count += 1
        if count > 400 then return nil end
    end
    return count > 0 and curve or nil
end
local function scaledCurve(source, factor)
    if not finite(factor) or factor < 1 or factor > 1.5 then return nil end
    local curve = cloneCurve(source)
    if not curve then return nil end
    local scaled = {}
    for distance, volume in pairs(curve) do
        local farther = distance == 0 and 0 or math.floor(distance * factor * 1000 + .5) / 1000
        if scaled[farther] ~= nil then return nil end
        scaled[farther] = volume
    end
    return scaled
end
local function sameCurve(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    local n, m = 0, 0
    for d, v in pairs(a) do
        n += 1
        if not finite(d) or not finite(v) or not finite(b[d])
            or math.abs(v - b[d]) > .0001 then return false end
    end
    for _ in pairs(b) do m += 1 end
    return n == m
end

-- Deterministic pure tests can inspect the math without creating Roblox services.
if options.inspect == true then
    return {cloneCurve = cloneCurve, scaledCurve = scaledCurve, sameCurve = sameCurve}
end

if game.PlaceId ~= 108901361810209 then
    error("FERAL voice trial only runs in FERAL Animal Survival", 0)
end
local Players = game:GetService("Players")
local VoiceChatService = game:GetService("VoiceChatService")
local localPlayer = Players.LocalPlayer
assert(localPlayer, "LocalPlayer unavailable")

local env = type(getgenv) == "function" and getgenv() or _G
if type(env.FERAL_VOICE_HEARING) == "table"
    and type(env.FERAL_VOICE_HEARING.close) == "function" then
    pcall(env.FERAL_VOICE_HEARING.close, env.FERAL_VOICE_HEARING)
end

local self = {
    version = "0.1.0",
    factor = 1.25,
    enabled = false,
    closed = false,
    players = {},
    characters = {},
    characterOwners = {},
    records = {},
    connections = {},
    failures = {},
    counters = {applied = 0, restored = 0, skipped = 0, foreignChanges = 0},
}

local function captureError(reason)
    self.failures[reason] = (self.failures[reason] or 0) + 1
    self.counters.skipped += 1
end
local function connect(bucket, signal, fn)
    local ok, connection = pcall(function() return signal:Connect(fn) end)
    if ok and connection then table.insert(bucket, connection) end
end
local function disconnect(bucket)
    for i = #bucket, 1, -1 do
        pcall(function() bucket[i]:Disconnect() end)
        bucket[i] = nil
    end
end
local function boundsMatch(a, b)
    return a and b and math.abs(a.Min - b.Min) <= .001
        and math.abs(a.Max - b.Max) <= .001
end

local function restore(emitter)
    local item = self.records[emitter]
    if not item then return end
    self.records[emitter] = nil
    local ok = pcall(function()
        if emitter.Parent == nil then return end
        if emitter.DistanceAttenuationMode ~= item.mode then
            self.counters.foreignChanges += 1
            return
        end
        if item.kind == "curve" then
            local actual = emitter:GetDistanceAttenuation()
            if not sameCurve(actual, item.applied) then
                self.counters.foreignChanges += 1
                return
            end
            emitter:SetDistanceAttenuation(item.original)
        else
            if not boundsMatch(emitter.DistanceAttenuationBounds, item.applied) then
                self.counters.foreignChanges += 1
                return
            end
            emitter.DistanceAttenuationBounds = item.original
        end
        self.counters.restored += 1
    end)
    if not ok then captureError("restore_rejected") end
end
local function restoreForPlayer(player)
    local targets = {}
    for emitter, item in pairs(self.records) do
        if item.player == player then table.insert(targets, emitter) end
    end
    for _, emitter in ipairs(targets) do restore(emitter) end
end
local function apply(player, emitter)
    if not self.enabled or self.closed or self.records[emitter] then return end
    if player == localPlayer or emitter.Parent ~= player.Character
        or not emitter:IsA("AudioEmitter") or emitter.Name ~= "AudioEmitter" then return end
    -- A peer's default voice emitter is only considered when their input exists.
    -- Never modify ordinary spatial sound effects or someone else's mute state.
    local input = player:FindFirstChildOfClass("AudioDeviceInput")
    if not input then return end
    local ok, mode = pcall(function() return emitter.DistanceAttenuationMode end)
    if not ok then captureError("mode_unreadable"); return end
    local isCustom = mode == Enum.DistanceAttenuationMode.Custom
    if isCustom then
        local read, old = pcall(function() return emitter:GetDistanceAttenuation() end)
        local original = read and cloneCurve(old) or nil
        if not original then captureError("no_explicit_curve"); return end
        local desired = scaledCurve(original, self.factor)
        if not desired then captureError("invalid_curve"); return end
        local wrote = pcall(function() emitter:SetDistanceAttenuation(desired) end)
        local checked, actual = pcall(function() return emitter:GetDistanceAttenuation() end)
        if not wrote or not checked or not sameCurve(actual, desired) then
            captureError("curve_write_rejected")
            if checked and sameCurve(actual, desired) then pcall(function()
                emitter:SetDistanceAttenuation(original)
            end) end
            return
        end
        self.records[emitter] = {
            player = player, kind = "curve", mode = mode,
            original = original, applied = desired
        }
    else
        local read, before = pcall(function() return emitter.DistanceAttenuationBounds end)
        if not read or not before or not finite(before.Min) or not finite(before.Max)
            or before.Max <= before.Min then
            captureError("invalid_preset_bounds")
            return
        end
        local desired = NumberRange.new(before.Min * self.factor, before.Max * self.factor)
        local wrote = pcall(function() emitter.DistanceAttenuationBounds = desired end)
        local checked, actual = pcall(function() return emitter.DistanceAttenuationBounds end)
        if not wrote or not checked or not boundsMatch(actual, desired) then
            captureError("preset_write_rejected")
            return
        end
        self.records[emitter] = {
            player = player, kind = "preset", mode = mode,
            original = before, applied = desired
        }
    end
    self.counters.applied += 1
end
local function scan(player)
    if not self.enabled or self.closed or player == localPlayer then return end
    local char = player.Character
    if not char then return end
    if not player:FindFirstChildOfClass("AudioDeviceInput") then return end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("AudioEmitter") and child.Name == "AudioEmitter" then
            apply(player, child)
        end
    end
end
local function detachCharacter(player)
    local conns = self.characters[player]
    if conns then disconnect(conns) end
    self.characters[player] = nil
    self.characterOwners[player] = nil
    restoreForPlayer(player)
end
local function watchCharacter(player, char)
    if self.characterOwners[player] == char then scan(player); return end
    detachCharacter(player)
    self.characterOwners[player] = char
    local bucket = {}
    self.characters[player] = bucket
    connect(bucket, char.ChildAdded, function(child)
        if child:IsA("AudioEmitter") then apply(player, child) end
    end)
    connect(bucket, char.ChildRemoved, function(child)
        if self.records[child] then restore(child) end
    end)
    scan(player)
end
local function watchPlayer(player)
    if player == localPlayer or self.players[player] then return end
    local bucket = {}
    self.players[player] = bucket
    connect(bucket, player.CharacterAdded, function(char)
        if not self.closed then watchCharacter(player, char) end
    end)
    connect(bucket, player.CharacterRemoving, function()
        detachCharacter(player)
    end)
    connect(bucket, player.ChildAdded, function(child)
        if child:IsA("AudioDeviceInput") then scan(player) end
    end)
    if player.Character then watchCharacter(player, player.Character) end
end

function self:setEnabled(enabled)
    if self.closed then return false end
    local requested = enabled == true
    if not requested then
        self.enabled = false
        local changed = {}
        for emitter in pairs(self.records) do table.insert(changed, emitter) end
        for _, emitter in ipairs(changed) do restore(emitter) end
        return true
    end
    self.enabled = true
    for _, player in ipairs(Players:GetPlayers()) do
        watchPlayer(player)
        if player.Character then watchCharacter(player, player.Character) end
        scan(player)
    end
    return true
end
function self:setFactor(factor)
    if not finite(factor) or factor < 1.05 or factor > 1.5 then return false end
    local wasEnabled = self.enabled
    self:setEnabled(false)
    self.factor = factor
    if wasEnabled then self:setEnabled(true) end
    return true
end
function self:status()
    local peers, inputs, emitters, changed = 0, 0, 0, 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            peers += 1
            if player:FindFirstChildOfClass("AudioDeviceInput") then inputs += 1 end
            local char = player.Character
            if char then
                for _, child in ipairs(char:GetChildren()) do
                    if child:IsA("AudioEmitter") and child.Name == "AudioEmitter" then
                        emitters += 1
                    end
                end
            end
        end
    end
    for emitter in pairs(self.records) do
        if emitter.Parent then changed += 1 end
    end
    local readable, useAudioApi = pcall(function() return VoiceChatService.UseAudioApi.Name end)
    return {
        version = self.version,
        enabled = self.enabled,
        increase = math.floor((self.factor - 1) * 100 + .5),
        voiceApi = readable and useAudioApi or "unreadable",
        remotePlayers = peers, voiceInputs = inputs, voiceEmitters = emitters,
        adjustedEmitters = changed,
        status = changed > 0 and "LOCAL_CURVE_ADJUSTED_AUDIO_UNVERIFIED"
            or emitters == 0 and "NO_VOICE_EMITTERS"
            or "NO_COMPATIBLE_CURVE",
        applied = self.counters.applied, restored = self.counters.restored,
        foreignChanges = self.counters.foreignChanges,
        failures = table.clone(self.failures),
        -- Changing local attenuation cannot force remote voice transmission.
        serverTransmissionExtended = false,
    }
end
function self:report()
    local info = self:status()
    print(("[FERAL Hearing] %s | +%d%% | Voice API %s | %d inputs | %d emitters | %d adjusted | %d restorations"):format(
        info.status, info.increase, info.voiceApi, info.voiceInputs,
        info.voiceEmitters, info.adjustedEmitters, info.restored))
    return info
end
function self:close()
    if self.closed then return end
    self:setEnabled(false)
    self.closed = true
    disconnect(self.connections)
    for player, bucket in pairs(self.players) do
        disconnect(bucket)
        self.players[player] = nil
    end
    for player in pairs(self.characters) do detachCharacter(player) end
    if env.FERAL_VOICE_HEARING == self then env.FERAL_VOICE_HEARING = nil end
end

connect(self.connections, Players.PlayerAdded, function(player)
    if not self.closed then watchPlayer(player) end
end)
connect(self.connections, Players.PlayerRemoving, function(player)
    detachCharacter(player)
    local bucket = self.players[player]
    if bucket then disconnect(bucket) end
    self.players[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end
env.FERAL_VOICE_HEARING = self
if options.autoEnable ~= false then self:setEnabled(true) end
self:report()
return self
