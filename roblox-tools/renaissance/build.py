#!/usr/bin/env python3
"""Deterministically package the thirteen owned modules; no downloaded code at boot."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MODULES = ("core", "settings", "policy", "grab", "grab_input", "recovery", "feeding", "combat_input", "rescue", "features", "roblox", "ui", "controller")
DEST = ROOT.parent / "feral-renaissance-v15.2.0.lua"

BOOT = '''
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
    {"ui","mount"},{"controller","new"},
}) do
    if type(M[pair[1]][pair[2]]) ~= "function" then error("Renaissance interface mismatch",0) end
end
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
    local stopped, failure = pcall(previous.close,previous)
    if not stopped then
        candidate:close()
        error("Previous hub shutdown failed: " .. tostring(failure),0)
    end
end
candidate:activate()
candidate.marker = {
    version = candidate.version,
    close = function() candidate:close() end,
    setMenuVisible = function(visible)
        if candidate.ui.visible ~= (visible == true) then candidate.ui:toggle() end
    end,
}
env.FERAL_RENAISSANCE_ACTIVE = candidate
env.FERAL_NOVA_PRIME_ACTIVE = candidate.marker
print("[FERAL Renaissance 15.2.0] Ready · Right Shift · client effects and gameplay outcomes tracked separately")
return candidate
'''


def build():
    chunks = ["-- FERAL Project Renaissance 15.2.0 | v2412 client baseline",
              "-- Gameplay acceptance is unverified unless independently observed.",
              "local options = ...",
              'if type(options) ~= "table" then options = {} end',
              "local sources = {}"]
    manifest = {}
    for name in MODULES:
        content = (ROOT / "src" / f"{name}.luau").read_text()
        if "]============]" in content:
            raise ValueError("module delimiter collision")
        chunks.append(f'sources["{name}"] = [============[\n{content}]============]')
        manifest[name] = {"sha256": hashlib.sha256(content.encode()).hexdigest(),
                          "bytes": len(content.encode())}
    chunks.append("local moduleOrder = {" + ",".join(json.dumps(n) for n in MODULES) + "}")
    chunks.append(BOOT.strip())
    data = ("\n".join(chunks) + "\n").encode()
    DEST.write_bytes(data)
    record = {"version": "15.2.0", "game_baseline": 2412, "modules": manifest,
              "bundle_sha256": hashlib.sha256(data).hexdigest(), "bundle_bytes": len(data),
              "stable_clean_v14_overwritten": False}
    (ROOT / "manifest.json").write_text(json.dumps(record, indent=2) + "\n")
    return record


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
