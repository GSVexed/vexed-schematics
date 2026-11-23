-- THE PHONE NOVA v2.1 — queued only on an in-session Roblox teleport.
-- Never relaunch from an ordinary manual join, and never outside THE PHONE.
local UNIVERSE=10775041696
local LOBBY=138199295184592
local MATCH=120688878033226
local KEY="THE_PHONE_NOVA_V21_HANDOFF"
local RESTORE_KEY="THE_PHONE_NOVA_V21_RESTORE"
local MAX_AGE=1200
local function resume()
    if not game:IsLoaded() then game.Loaded:Wait() end
    if game.GameId~=UNIVERSE or
       (game.PlaceId~=LOBBY and game.PlaceId~=MATCH) then return end
    local Teleport=game:GetService("TeleportService")
    local ok,payload=pcall(function()return Teleport:GetTeleportSetting(KEY)end)
    if not ok or type(payload)~="table" then return end
    if payload.schema~=1 or payload.pending~=true or
       payload.universe~=UNIVERSE or
       type(payload.sessionId)~="string" or #payload.sessionId>100 or
       type(payload.settings)~="table" or
       (payload.sourcePlace~=LOBBY and payload.sourcePlace~=MATCH) or
       type(payload.at)~="number" or
       math.abs(os.time()-payload.at)>MAX_AGE or
       (payload.sourceJob==game.JobId and payload.sourcePlace==game.PlaceId)
    then return end

    -- Clear the one-shot ticket before fetching anything. If a queue
    -- was registered twice, only the first bootstrap can consume it.
    pcall(function()Teleport:SetTeleportSetting(KEY,nil)end)
    local env=_G
    pcall(function()
        if type(getgenv)=="function" and type(getgenv())=="table" then env=getgenv() end
    end)
    if type(env[RESTORE_KEY])=="table" then return end
    env[RESTORE_KEY]=payload

    -- A teleport should not recreate an older hub after the user left manually.
    -- This invocation happens only with a valid in-session teleport ticket.
    local src=game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/the-phone-nova.lua")
    local chunk,err=loadstring(src)
    if not chunk then error("THE PHONE NOVA teleport loader: "..tostring(err))end
    chunk()
end
local ok,err=pcall(resume)
if not ok then
    warn("[THE PHONE NOVA] Auto-handoff failed: "..tostring(err))
end
