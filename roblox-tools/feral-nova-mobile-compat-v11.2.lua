-- FERAL NOVA v11.2 / retired mobile A/B Rest experiment.
-- Compatibility API only; the active native controller owns moving recovery.
local Mobile={}
function Mobile.attach(ctx)
    local M={
        alive=true,enabled=false,active=false,legacyRetired=true,
        status="RETIRED / MOVING RECOVERY CONSOLIDATED",
        result="UNAVAILABLE / EXTERNAL SERVER VERIFICATION REQUIRED",
        restOwned=false,attempts=0,signals=0
    }
    function M.beforeCarry() return false end
    function M.setEnabled(v)
        M.enabled=false
        M.active=false
        return false
    end
    function M.report()
        return table.concat({
            "FERAL NOVA v11.2 | Mobile Rest experiment retired",
            "legacy_retired=true","enabled=false","active=false",
            "heartbeat_connections=0","input_connections=0",
            "native_rest_requests=0","result="..M.result,
            "NOTE=No second mobile Rest controller can interfere with user actions."
        },"\n")
    end
    function M.close()
        M.enabled=false
        M.active=false
        M.alive=false
    end
    return M
end
return Mobile
