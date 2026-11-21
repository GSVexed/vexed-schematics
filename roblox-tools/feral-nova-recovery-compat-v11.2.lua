-- FERAL NOVA v11.2 / retired legacy Safe Rest implementation.
-- Compatibility API only. No events, Heartbeat, attributes or Rest remotes.
-- Automatic Rest has exactly one owner: feral-nova-native-recovery-v11.0.
local Recovery={}
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local function finite(n)
    return type(n)=="number" and n==n and n>=0 and n<1e9
end
function Recovery.shellState(species,rest,restAt,serverNow)
    if type(species)~="string" or not string.find(species,"SnappingTurtle",1,true) then
        return "NOT TURTLE",1
    end
    if rest~=true then return "SHELL INACTIVE",1 end
    if not finite(restAt) or not finite(serverNow) then
        return "REST OBSERVED / TIMER UNAVAILABLE",1
    end
    if serverNow-restAt<1 then return "SHELL ARMING",1 end
    return "SHELL RULE CONDITION / SERVER UNVERIFIED",.30
end
function Recovery.attach(ctx)
    local M={
        alive=true,enabled=false,legacyRetired=true,
        status="RETIRED / UNIFIED NATIVE RECOVERY OWNS REST",
        shell="UNKNOWN",multiplier=1,restOwned=nil,restActive=false,
        attempts=0,requests=0,cancels=0
    }
    function M.snapshot()
        local char=player.Character
        if not char or not char.Parent then
            M.shell="NO ANIMAL";M.multiplier=1
            return M.shell,M.multiplier
        end
        local species=char:GetAttribute("Species")
        local active=char:GetAttribute("WolfRest")==true
        local start=char:GetAttribute("WolfRestAt")
        local ok,serverNow=pcall(function()return workspace:GetServerTimeNow()end)
        M.shell,M.multiplier=Recovery.shellState(species,active,start,ok and serverNow or nil)
        return M.shell,M.multiplier
    end
    function M.beforeCarry() return false end
    function M.setEnabled(v)
        -- A stale UI or older module cannot re-enable a second Rest writer.
        M.enabled=false
        M.status="RETIRED / USE ACTIVE RECOVERY"
        return false
    end
    function M.report()
        M.snapshot()
        return table.concat({
            "FERAL NOVA v11.2 | Safe Rest compatibility only",
            "legacy_retired=true","automatic_rest_requests=0",
            "event_connections=0","heartbeat_connections=0",
            "enabled=false","status="..M.status,
            "turtle_shell_observation="..M.shell,
            "client_shell_multiplier="..tostring(M.multiplier),
            "NOTE=Actual Turtle damage reduction is game-server controlled.",
            "NOTE=Native recovery is the only hub Rest request owner."
        },"\n")
    end
    function M.close()
        M.enabled=false
        M.alive=false
    end
    return M
end
return Recovery
