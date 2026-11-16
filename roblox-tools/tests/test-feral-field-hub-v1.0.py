"""Offline Luau behaviour/fault tests. This is not a Roblox engine test."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "feral-field-hub-v1.0.lua"
DEFAULT_LUAU = ROOT.parents[1] / "check-tools" / "luau" / "luau"

CORE_CASES = r'''
local count = 0
local function case(name, fn)
    fn(); count = count + 1; print("PASS core " .. name)
end
case("error metadata does not retain raw API content", function()
    local kind, line = Core.errorMeta('source:428: permission denied secret-value-do-not-retain')
    assert(kind == "permission_error" and line == 428)
    kind, line = Core.errorMeta({private = "not retained"})
    assert(kind == "runtime_error" and line == nil)
end)
case("nonfinite health rejected", function()
    assert(Core.hpTarget(0/0, 100, 1, 4) == nil)
    assert(Core.hpTarget(10, math.huge, 1, 4) == nil)
end)
case("no revival or overheal", function()
    assert(Core.hpTarget(0, 100, .25, 4) == nil)
    assert(Core.hpTarget(-1, 100, .25, 4) == nil)
    assert(Core.hpTarget(100, 100, .25, 4) == nil)
    assert(Core.hpTarget(99.8, 100, .25, 4) == 100)
end)
case("lag cannot cause a large heal", function()
    assert(Core.hpTarget(10, 100, 500, 4) == 11)
    assert(Core.hpTarget(10, 100, -1, 4) == 10)
end)
case("patch restoration preserves later external changes", function()
    local t = {a = 2, b = 3}
    local lease = assert(Core.patch(t, {a = 7, b = 8, c = 9}))
    t.b = 11
    assert(Core.restore(lease) == 0)
    assert(t.a == 2 and t.b == 11 and t.c == nil)
end)
case("write failure rolls back prior writes", function()
    local storage, writes = {a = 1, b = 2, c = 3}, 0
    local t = setmetatable({}, {__index = storage, __newindex = function(_, key, value)
        writes = writes + 1
        if writes == 2 then error("injected write failure") end
        storage[key] = value
    end})
    assert(Core.patch(t, {a = 9, b = 9, c = 9}) == nil)
    assert(storage.a == 1 and storage.b == 2 and storage.c == 3)
end)
case("read failure rolls back prior writes", function()
    local storage, reads = {a = 1, b = 2, c = 3}, 0
    local t = setmetatable({}, {__index = function(_, key)
        reads = reads + 1
        if reads == 2 then error("injected read failure") end
        return storage[key]
    end, __newindex = storage})
    assert(Core.patch(t, {a = 9, b = 9, c = 9}) == nil)
    assert(storage.a == 1 and storage.b == 2 and storage.c == 3)
end)
case("frozen table fails without force-unfreezing", function()
    local t = table.freeze({a = 1})
    assert(Core.patch(t, {a = 2}) == nil)
    assert(t.a == 1)
end)
case("restoration failures are counted", function()
    local t = {a = 1}
    local lease = assert(Core.patch(t, {a = 2}))
    table.freeze(t)
    assert(Core.restore(lease) == 1)
end)
case("travel requires fresh matching living character", function()
    local character, other = {}, {}
    local plan = {character = character, at = 10}
    assert(Core.travelAllowed(plan, character, 11, true, false))
    assert(not Core.travelAllowed(plan, other, 11, true, false))
    assert(not Core.travelAllowed(plan, character, 23, true, false))
    assert(not Core.travelAllowed(plan, character, 9, true, false))
    assert(not Core.travelAllowed(plan, character, 11, false, false))
    assert(not Core.travelAllowed(plan, character, 11, true, true))
    assert(not Core.travelAllowed(nil, character, 11, true, false))
    plan.at = 0/0
    assert(not Core.travelAllowed(plan, character, 11, true, false))
end)
case("water steepness missing support and obstruction reject landing", function()
    local good = {measured = true, water = false, normalY = 1, supportDelta = .1, clear = true}
    assert(Core.supported(good))
    for _, field in ipairs({"measured", "water", "normalY", "supportDelta", "clear"}) do
        local t = table.clone(good); t[field] = nil
        assert(not Core.supported(t), field)
    end
    local t = table.clone(good); t.water = true; assert(not Core.supported(t))
    t = table.clone(good); t.normalY = .5; assert(not Core.supported(t))
    t = table.clone(good); t.supportDelta = 3; assert(not Core.supported(t))
    t = table.clone(good); t.clear = false; assert(not Core.supported(t))
end)
case("compass directions and degenerate view", function()
    local angle, word, distance = Core.bearing(0, -10, 0, -1)
    assert(math.abs(angle) < .001 and word == "AHEAD" and distance == 10)
    angle, word = Core.bearing(10, 0, 0, -1); assert(word == "RIGHT" and angle > 0)
    angle, word = Core.bearing(-10, 0, 0, -1); assert(word == "LEFT" and angle < 0)
    angle, word = Core.bearing(0, 10, 0, -1); assert(word == "BEHIND")
    angle, word = Core.bearing(0, 0, 0, 0); assert(word == "HERE")
end)
print("CORE_CASES=" .. count)
'''


def main():
    source = SOURCE.read_text()
    luau = Path(os.environ.get("FERAL_LUAU", str(DEFAULT_LUAU)))
    compiler = luau.with_name("luau-compile")
    subprocess.run([str(compiler), "--null", str(SOURCE)], check=True)
    for forbidden in [":FireServer(", ":InvokeServer(", ":GetPlayers(",
                      "decompile(", "getgc(", "hookfunction(", "setreadonly(",
                      'SetAttribute("Amber"', 'SetAttribute("FeralTester"']:
        assert forbidden not in source, forbidden
    core = source.split("-- BEGIN TESTABLE CORE\n", 1)[1].split("-- END TESTABLE CORE", 1)[0]
    with tempfile.TemporaryDirectory(prefix="feral-hub-tests-") as tmp:
        path = Path(tmp)
        core_file = path / "core.luau"
        core_file.write_text(core + "\n" + CORE_CASES)
        subprocess.run([str(luau), str(core_file)], check=True)
        mock = (ROOT / "tests/mock-feral-field-hub-v1.0.luau").read_text()
        prelude, scenarios = mock.split("-- HUB SCENARIOS", 1)
        runtime = path / "runtime.luau"
        runtime.write_text(prelude + "\nlocal function launchHub()\n" + source
                           + "\nend\n" + scenarios)
        subprocess.run([str(luau), str(runtime)], check=True)
    print("Source compile, static boundaries and offline scenarios passed; Roblox/Velocity untested.")


if __name__ == "__main__":
    main()
