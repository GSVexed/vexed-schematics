#!/usr/bin/env python3
"""Deterministically package fourteen core and ten integrated Territory modules."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CORE_MODULES = ("core", "settings", "policy", "grab", "grab_input", "recovery", "feeding", "combat_input", "rescue", "features", "roblox", "zoom", "ui", "controller")
AMBER_MODULES=("planner","gait","nav","hunt","care","agent","bridge","driver","ui","runtime")
MODULES=(*CORE_MODULES,*("amber_"+name for name in AMBER_MODULES))
def module_path(name):
    if name.startswith("amber_"):
        return ROOT.parent/"feral-amber"/"src"/(name[6:]+".luau")
    return ROOT/"src"/(name+".luau")

VERSION = "15.6.2"
DEST = ROOT.parent / f"feral-renaissance-v{VERSION}.lua"

# Immutable known-good releases. Validate before writing a new bundle or manifest.
PROTECTED_HASHES = {
    "feral-renaissance-v15.6.1.lua": "b70d08957b44b5b48cce5a0ffb63b7dc9be288ed633efa7b7b9d949dfc7e1ef8",
    "feral-renaissance-v15.6.0.lua": "e0b8d0f6005b6c6311c9bfd873ffd490457f385844d1b5179f5ff809be3b0220",
    "feral-renaissance-v15.5.1.lua": "771e130b2a1afae4b70d5334fd40fdf1363fd690682350f6d9c012b65d637b69",
    "feral-renaissance-v15.5.0.lua": "e58a4e7dadbb1f1ceeb8f4e16f612ea33d72f26ca9519dc48b908c0b03a3f975",
    "feral-nova-v14.0-clean-reach-core.lua": "7ce435099acf823c0f92a406a8febf0260fb9fcfbdde54d9c4a084f8190ce93c",
    "feral-nova-clean.lua": "d34847e2cb11c822177071e109fc2c8bc9e13e3ce7aa7ade02fd732b192e2952",
    "feral-renaissance-v15.0.0.lua": "bc388ccfdc8bae19e7fe2dca7c24bf2fbd3f97266c205c38544735e81ea3e12f",
    "feral-renaissance-v15.1.0.lua": "7c289fd74de07c86537476e1c7fa760f3422ff8d305737bb5e19ab3e546cb093",
    "feral-renaissance-v15.2.0.lua": "435265c032d1c200157e2004021ab491dc7c317317c5792e0070c2b1fffc8ceb",
    "feral-renaissance-v15.2.1.lua": "d1aa528c9b3ec3dfa7aaf69991786cbfbaa75f75703e39408eaf11be3f8c59b9",
    "feral-renaissance-v15.3.0.lua": "af3439173cf2e848c4441b967b0a6144397467fcc6750f9611b43bb60432f6e8",
    "feral-renaissance-v15.4.0.lua": "cb0c9c840eff287bb82bcda212aa9a986f06bf44dedf920777d753c40606ed6f",
    "feral-renaissance-v15.4.1.lua": "22903a4f0ea88fbfdc5965104d511c3c73251ae706b3aa0c3db7e2f1e00ea6c5",
    "feral-renaissance-v15.4.2.lua": "022d9f06c5544eced1da971152243438b98f3b304743a95f3870d1ccc74e053a",
    "feral-renaissance-v15.4.3.lua": "e60fd51fabbd192ca6ff77ad0055b089a152a88304efb96aa59e46e6421e514e",
}


def verify_protected_artifacts(directory=None):
    """Fail closed before packaging if any known-good rollback is absent or changed."""
    folder = Path(directory) if directory is not None else ROOT.parent
    for name, expected in PROTECTED_HASHES.items():
        try:
            actual = hashlib.sha256((folder / name).read_bytes()).hexdigest()
        except OSError as exc:
            raise RuntimeError(f"Protected rollback missing or unreadable: {name}") from exc
        if actual != expected:
            raise RuntimeError(f"Protected rollback hash mismatch: {name}")


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
    {"zoom","new"},{"ui","mount"},{"controller","new"},
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
print("[FERAL Renaissance 15.6.2] Ready · Right Shift · client effects and gameplay outcomes tracked separately")
return candidate
'''


def build():
    verify_protected_artifacts()  # Do not overwrite the bundle/manifest on a damaged baseline.
    chunks = [f"-- FERAL Project Renaissance {VERSION} | v2412 client baseline",
              "-- Gameplay acceptance is unverified unless independently observed.",
              "local options = ...",
              'if type(options) ~= "table" then options = {} end',
              "local sources = {}"]
    manifest = {}
    for name in MODULES:
        content = module_path(name).read_text()
        if "]============]" in content:
            raise ValueError("module delimiter collision")
        chunks.append(f'sources["{name}"] = [============[\n{content}]============]')
        manifest[name] = {"sha256": hashlib.sha256(content.encode()).hexdigest(),
                          "bytes": len(content.encode())}
    chunks.append("local moduleOrder = {" + ",".join(json.dumps(n) for n in MODULES) + "}")
    chunks.append(BOOT.strip())
    data = ("\n".join(chunks) + "\n").encode()
    DEST.write_bytes(data)
    record = {"version": VERSION, "game_baseline": 2412, "modules": manifest,
              "bundle_sha256": hashlib.sha256(data).hexdigest(), "bundle_bytes": len(data),
              "stable_clean_v14_overwritten": False}
    (ROOT / "manifest.json").write_text(json.dumps(record, indent=2) + "\n")
    return record


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
