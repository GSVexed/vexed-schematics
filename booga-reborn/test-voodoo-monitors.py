#!/usr/bin/env python3
"""Run the actual monitor sources against a single-callback ByteNet mock."""
import argparse
from pathlib import Path
import subprocess
import tempfile


HARNESS = r'''
local function check(source, name, filename, stopKey, timeout)
    local now = 0
    local shared = {}
    local writes = {}
    local connections = {}
    local registrations = 0
    local requests = 0
    local nativeCalls = 0
    local data = {voodoo = 100, spell = "Energy Bolt", mojoItems = {Spellmaster = 1},
        armor = {bag = "God Bag"}, inventory = {{name = "Jelly Sandwich", quantity = 2}}}
    local util = {Data = data}
    local displayedVoodoo = data.voodoo
    local listeners = {}
    local packets = {}
    for _, packetName in ipairs({"UpdateStats", "UpdateStatsUnreliable", "SetBoost", "RemoveBoost", "UpdateArmor"}) do
        listeners[packetName] = function(payload)
            nativeCalls += 1
            if payload.voodoo ~= nil then data.voodoo = payload.voodoo; displayedVoodoo = payload.voodoo end
        end
        packets[packetName] = {
            listen = function(callback)
                registrations += 1
                listeners[packetName] = callback
                -- This matches the recovered game: no connection or unsubscribe handle.
            end,
            send = function() requests += 1 end,
        }
    end
    packets.VoodooSpell = {send = function() requests += 1 end}
    local originals = table.clone(listeners)
    local function module(value)
        return {IsA = function(_, className) return className == "ModuleScript" end, value = value}
    end
    local function folder(children)
        return {FindFirstChild = function(_, child) return children[child] end}
    end
    local storage = folder({Modules = folder({util = folder({
        gameUtil = module(util), packets = module(packets),
    })}), Game = folder({functions = module({})})})
    local heartbeat = {Connect = function(_, callback)
        local link = {connected = true, callback = callback}
        function link:Disconnect() self.connected = false end
        table.insert(connections, link)
        return link
    end}
    local services = {
        Players = {LocalPlayer = {}},
        ReplicatedStorage = storage,
        RunService = {Heartbeat = heartbeat},
        HttpService = {JSONEncode = function(_, report) return report end},
    }
    local environment = setmetatable({
        game = {PlaceId = 11729688377, GetService = function(_, service) return assert(services[service], service) end},
        os = {clock = function() return now end},
        getgenv = function() return shared end,
        _G = shared,
        require = function(value) return value.value end,
        writefile = function(path, report) writes[path] = report end,
        warn = function() end,
    }, {__index = getfenv()})
    local function launch()
        local main = assert(loadstring(source, name))
        setfenv(main, environment)
        main()
    end
    local function tick(time)
        now = time
        for _, link in ipairs(connections) do if link.connected then link.callback() end end
    end
    local function emit(packet, voodoo)
        listeners[packet]({voodoo = voodoo})
        assert(data.voodoo == voodoo and displayedVoodoo == voodoo, name .. ": native cache/UI stopped updating")
    end
    local function checkListeners()
        assert(registrations == 0, name .. ": monitor registered a packet listener")
        for packet, original in pairs(originals) do
            assert(listeners[packet] == original, name .. ": replaced " .. packet)
        end
        assert(requests == 0, name .. ": sent a gameplay request")
    end
    launch()
    assert(data.voodoo == 100 and displayedVoodoo == 100, name .. ": wrote gameplay state")
    tick(0.6)
    emit("UpdateStats", 70)
    tick(1.2)
    emit("UpdateStatsUnreliable", 40)
    tick(1.8)
    emit("UpdateStatsUnreliable", 41)
    tick(4.2)
    emit("UpdateStats", 100)
    tick(13)
    checkListeners()
    local report = assert(writes[filename], name .. ": missing report")
    assert(report.measurement.source == "client_cache")
    assert(report.measurement.packet_listeners_installed == false)
    assert(report.measurement.incoming_packets_observed == false)
    local samples = report.samples
    assert(#samples == 5 and samples[1].v == 100 and samples[2].v == 70 and samples[3].v == 40 and samples[4].v == 41)
    local counters = report.stats or report.counters
    assert((counters.voodoo_drops or counters.observed_decreases) == 2)
    if report.trial then assert(report.trial.state == "observe_only" and report.trial.request_calls == 0) end
    assert(#report.notes > 0 and string.find(report.notes[1], "rejoin"))
    assert(type(shared[stopKey]) == "function")
    -- Rerunning stops the old heartbeat without touching the native network handlers.
    launch()
    assert(not connections[1].connected and connections[2].connected)
    shared[stopKey]()
    assert(not connections[2].connected and shared[stopKey] == nil)
    emit("UpdateStatsUnreliable", 42)
    checkListeners()
    -- The automatic timeout must also disconnect only the monitor's heartbeat.
    launch()
    tick(now + timeout + 1)
    assert(not connections[3].connected and shared[stopKey] == nil)
    emit("UpdateStats", 43)
    checkListeners()
    assert(nativeCalls == 6)
    print("PASS " .. name .. ": native callbacks, cache/UI delivery, sampling, rerun, stop and timeout")
end
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", required=True, help="Official Luau interpreter executable")
    args = parser.parse_args()
    directory = Path(__file__).resolve().parent
    fixtures = [
        ("booga-voodoo-regen-native-monitor-v1.lua", "booga_voodoo_native_v1.json", "__booga_native_monitor_stop", 420),
        ("booga-voodoo-lab-v2.lua", "booga_voodoo_lab_v2.json", "__booga_lab_v2_stop", 560),
    ]
    program = HARNESS
    for name, output, stop, timeout in fixtures:
        source = (directory / name).read_text(encoding="utf-8")
        assert "]====]" not in source
        program += f'\ncheck([====[{source}]====], "{name}", "{output}", "{stop}", {timeout})\n'
    with tempfile.TemporaryDirectory(prefix="booga-monitor-test-") as temporary:
        suite = Path(temporary) / "monitors.luau"
        suite.write_text(program, encoding="utf-8")
        subprocess.run([args.luau, str(suite)], check=True)


if __name__ == "__main__":
    main()
