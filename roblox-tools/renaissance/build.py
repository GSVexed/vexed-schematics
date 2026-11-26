#!/usr/bin/env python3
"""Deterministically package Renaissance and its integrated Territory modules."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CORE_MODULES = ("core", "settings", "policy", "grab", "grab_input", "recovery", "feeding", "combat_input", "rescue", "hippo", "features", "roblox", "zoom", "voice", "test_features", "ui", "controller")
AMBER_MODULES=("ledger","model","planner","gait","nav","hunt","care","agent","bridge","driver","ui","runtime")
MODULES=(*CORE_MODULES,*("amber_"+name for name in AMBER_MODULES))
def module_path(name):
    if name.startswith("amber_"):
        return ROOT.parent/"feral-amber"/"src"/(name[6:]+".luau")
    return ROOT/"src"/(name+".luau")

RELEASE = json.loads((ROOT / "version.json").read_text())
VERSION = RELEASE["version"]
TERRITORY_VERSION = RELEASE["territory_version"]
CHANNEL = RELEASE["channel"]
GAME_BASELINE = RELEASE["game_baseline"]
TOOLCHAIN = RELEASE["toolchain_commit"]
assert re.fullmatch(r"\d+\.\d+\.\d+", VERSION), "Invalid candidate version"
assert re.fullmatch(r"\d+\.\d+\.\d+", TERRITORY_VERSION), "Invalid Territory version"
assert CHANNEL == "candidate", "This build must not silently promote stable"
assert isinstance(GAME_BASELINE, int) and GAME_BASELINE > 0, "Invalid game baseline"
assert re.fullmatch(r"[0-9a-f]{40}", TOOLCHAIN), "Toolchain must be an immutable commit"
DEST = ROOT.parent / f"feral-renaissance-v{VERSION}.lua"

# Immutable known-good releases. Validate before writing a new bundle or manifest.
PROTECTED_HASHES = {
    "feral-renaissance-v16.1.0.lua": "5c1084a21dc59b0fe0d343c15c3d92ed0141299cf8ddd7c51c98c76e0115b92b",
    "feral-renaissance-v16.0.2.lua": "06a07fb509bbd217b059c5e282cd4bfaaf7a90595e13873b955953a8cea19f5c",
    "feral-renaissance-v15.8.7.lua": "b65b4a3750c8e521d43d4fb702fefa11db2070fe795c427dbdbd633aafcb6da3",
    "feral-renaissance-v15.8.6.lua": "28c6a2589cd5faee4a9fbf71b1560f3e60e46c18736e5a9a1f175ada1e66a9ed",
    "feral-renaissance-v15.8.5.lua": "833f7767c817ae22a775d12ec2121e7243985f95ba76e52367d4f7b112421675",
    "feral-renaissance-v15.8.4.lua": "1d25dee4390ba9d0256df1d0df8b6c867e94732380857bfe6f0be3e7cda9feae",
    "feral-renaissance-v15.8.2.lua": "d6a00b02e97f5c1e440eefb78262a2cc211b1f3eff322c67a68a1a82062bf32f",
    "feral-renaissance-v15.8.0.lua": "ba69a1efae61f2241d370aec2f9d8564cd8b3317e40c5afef114d654061ddb30",
    "feral-renaissance-v15.7.0.lua": "d54b1b1e94849a5e4c41947a2ce659e35f6ddf22591aa75b3e4288a15e5ed8bb",
    "feral-renaissance-v15.6.2.lua": "c1275bd161e5548522d7ab47e9c791eba361d5d383337535d751dfab9afafa98",
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
    {"zoom","new"},{"voice","new"},{"ui","mount"},{"controller","new"},
    {"hippo","new"},{"test_features","new"},
}) do
    if type(M[pair[1]][pair[2]]) ~= "function" then error("Renaissance interface mismatch",0) end
end
M.release = __RELEASE_METADATA__
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
print("[FERAL Renaissance " .. candidate.version .. "] Ready · Right Shift · Native Hold-to-Bite")
return candidate
'''


def build():
    verify_protected_artifacts()  # Do not overwrite the bundle/manifest on a damaged baseline.
    if DEST.name in PROTECTED_HASHES:
        raise RuntimeError("Candidate version would overwrite a protected release")
    chunks = [f"-- FERAL Project Renaissance {VERSION} | v{GAME_BASELINE} client baseline",
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
    # Identify the source independently of the distributable containing this
    # value. Embedding the bundle's own hash would be self-referential.
    fingerprint_input = {"release": RELEASE,
                         "modules": [{"name": name, "sha256": manifest[name]["sha256"]}
                                     for name in MODULES]}
    source_fingerprint = hashlib.sha256(json.dumps(
        fingerprint_input, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    chunks.append("local moduleOrder = {" + ",".join(json.dumps(n) for n in MODULES) + "}")
    metadata = "{version=" + json.dumps(VERSION) + ",territoryVersion=" + json.dumps(TERRITORY_VERSION) \
        + ",channel=" + json.dumps(CHANNEL) + ",sourceFingerprint=" + json.dumps(source_fingerprint) + "}"
    chunks.append(BOOT.replace("__RELEASE_METADATA__", metadata).strip())
    data = ("\n".join(chunks) + "\n").encode()
    DEST.write_bytes(data)
    record = {"version": VERSION, "channel": CHANNEL, "integrated_territory_version": TERRITORY_VERSION,
              "game_baseline": GAME_BASELINE, "modules": manifest,
              "source_fingerprint": source_fingerprint,
              "bundle_sha256": hashlib.sha256(data).hexdigest(), "bundle_bytes": len(data),
              "stable_clean_v14_overwritten": False}
    (ROOT / "manifest.json").write_text(json.dumps(record, indent=2) + "\n")
    return record


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
