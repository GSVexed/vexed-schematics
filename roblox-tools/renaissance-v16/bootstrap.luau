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
M.release = {version="@VERSION@",territoryVersion="0.8.0",channel="release-candidate",sourceFingerprint="@FINGERPRINT@"}
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
