-- FERAL v2412: one-shot Turtle/Crusher boundary check. No automatic requests.
-- F7: attempt once while resting as Turtle; F8: save/copy local evidence; F9: stop.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local HttpService=game:GetService("HttpService")
local player=assert(Players.LocalPlayer,"FERAL player unavailable")
local scope=type(getgenv)=="function" and getgenv() or _G
local previous=scope.FERAL_SHELL_CROSS_PROBE
if type(previous)=="table" and type(previous.close)=="function" then pcall(previous.close,previous) end

local probe={active=true,used=false,pending=nil,events={},connections={},characterConnections={},
    version="1.0",baseline=2412,attemptsSent=0}
scope.FERAL_SHELL_CROSS_PROBE=probe
local function finite(n)return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end
local function serverNow()
    local ok,n=pcall(function()return Workspace:GetServerTimeNow()end)
    return ok and finite(n) and n or nil
end
local function attr(object,key)
    if not object then return nil end
    local ok,v=pcall(object.GetAttribute,object,key)
    return ok and v or nil
end
local function note(kind,details)
    local event={kind=kind,t=os.clock(),serverTime=serverNow(),details=details}
    table.insert(probe.events,event)
    if #probe.events>200 then table.remove(probe.events,1) end
    print("[FERAL shell probe] "..kind)
end
local function connect(target,fn,character)
    if not target then return end
    local c=target:Connect(fn)
    table.insert(character and probe.characterConnections or probe.connections,c)
end
local function clearCharacter()
    for _,c in ipairs(probe.characterConnections)do pcall(c.Disconnect,c)end
    table.clear(probe.characterConnections)
end
function probe:snapshot()
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local localShell
    local world=ReplicatedStorage:FindFirstChild("FeralWorld")
    local config=world and world:FindFirstChild("CombatConfig")
    if char and config and config:IsA("ModuleScript") then
        local ok,c=pcall(require,config)
        if ok and type(c)=="table" and type(c.shellMult)=="function" then
            local computed,value=pcall(c.shellMult,char)
            if computed and finite(value) then localShell=value end
        end
    end
    return {species=attr(char,"Species"),rest=attr(char,"WolfRest"),restAt=attr(char,"WolfRestAt"),
        crushAt=attr(char,"FeralCrushAt"),crushBiteAt=attr(char,"FeralCrushBiteAt"),
        safeUntil=attr(char,"FeralSafeUntil"),hp=hum and hum.Health or nil,
        maxHP=hum and hum.MaxHealth or nil,localShellMultiplier=localShell,
        -- All attributes and shellMult here are CLIENT observations, not server proof.
        shellMultiplierAuthority="client only"}
end
local function attach(char)
    clearCharacter()
    probe.char=char
    if not char then note("character_removed");return end
    note("character_attached",probe:snapshot())
    for _,key in ipairs({"Species","WolfRest","WolfRestAt","FeralCrushAt","FeralCrushBiteAt","FeralSafeUntil"})do
        connect(char:GetAttributeChangedSignal(key),function()
            if probe.active and player.Character==char then note("attribute_"..key,probe:snapshot()) end
        end,true)
    end
    local function watchHealth(hum)
        if not hum or not probe.active or player.Character~=char then return end
        local last=hum.Health
        connect(hum.HealthChanged,function(hp)
            if not probe.active or player.Character~=char then return end
            note("hp_change",{before=last,after=hp,delta=hp-last,rest=attr(char,"WolfRest"),
                species=attr(char,"Species"),safeUntil=attr(char,"FeralSafeUntil")})
            last=hp
        end,true)
        note("humanoid_attached",probe:snapshot())
    end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hum then watchHealth(hum)
    else
        task.spawn(function()
            watchHealth(char:WaitForChild("Humanoid",5))
        end)
    end
end
function probe:release(reason)
    local pending=self.pending
    if not pending then return false end
    self.pending=nil
    if player.Character~=pending.char or not pending.char.Parent then
        note("release_skipped_character_changed",{reason=reason});return false
    end
    local remote=ReplicatedStorage:FindFirstChild("FeralHippo")
    local timestamp=serverNow()
    if not remote or not remote:IsA("RemoteEvent") or not timestamp then
        note("release_unavailable",{reason=reason});return false
    end
    local before=self:snapshot()
    local ok=pcall(remote.FireServer,remote,"release",timestamp)
    if ok then self.attemptsSent+=1 end
    note("crusher_release_request",{sent=ok,reason=reason,heldFor=timestamp-pending.at,
        before=before})
    return ok
end
function probe:attempt()
    if not self.active or self.used then note("already_used");return false end
    if game.PlaceId~=108901361810209 or game.PlaceVersion~=2412 then
        note("unsupported_game_version",{placeId=game.PlaceId,placeVersion=game.PlaceVersion});return false
    end
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local t=serverNow()
    local restAt=attr(char,"WolfRestAt")
    if not char or not char.Parent or not hum or hum.Health<=0 or not t
        or attr(char,"Species")~="SnappingTurtle" or attr(char,"WolfRest")~=true
        or not finite(restAt) or t-restAt<1.25 then
        note("not_resting_turtle",self:snapshot());return false
    end
    local ready=attr(player,"FeralLungeReadyAt")
    if finite(ready) and t<ready-.05 then
        note("ability_cooldown_active",{readyAt=ready,now=t});return false
    end
    local remote=ReplicatedStorage:FindFirstChild("FeralHippo")
    if not remote or not remote:IsA("RemoteEvent") then note("remote_unavailable");return false end
    self.used=true
    local pending={char=char,at=t}
    self.pending=pending
    local before=self:snapshot()
    local ok=pcall(remote.FireServer,remote,"start",t)
    if not ok then self.pending=nil;note("crusher_start_failed");return false end
    self.attemptsSent+=1
    note("crusher_start_request",{before=before,serverAcceptance="unverified"})
    task.delay(6.1,function()
        if self.active and self.pending==pending then self:release("one-shot timed release") end
    end)
    return true
end
function probe:export()
    local report={name="FERAL shell/Crusher boundary probe",version=self.version,
        placeId=game.PlaceId,placeVersion=game.PlaceVersion,
        note="Client-side attributes/FX are not server acceptance. Compare actual HP changes and server replies.",
        oneShotUsed=self.used,requestsSent=self.attemptsSent,pending=self.pending~=nil,
        snapshot=self:snapshot(),events=self.events}
    local ok,raw=pcall(HttpService.JSONEncode,HttpService,report)
    if not ok then warn("[FERAL shell probe] JSON export failed: "..tostring(raw));return nil end
    if type(writefile)=="function" then
        local wrote=pcall(writefile,"FERAL_SHELL_CROSS_PROBE.json",raw)
        if wrote then print("[FERAL shell probe] saved FERAL_SHELL_CROSS_PROBE.json") end
    end
    if type(setclipboard)=="function" then
        if pcall(setclipboard,raw) then print("[FERAL shell probe] report copied to clipboard") end
    else print("[FERAL shell probe] "..raw) end
    return raw
end
function probe:close()
    if not self.active then return end
    if self.pending then self:release("probe stopped") end
    self.active=false
    clearCharacter()
    for _,c in ipairs(self.connections)do pcall(c.Disconnect,c)end
    table.clear(self.connections)
    if scope.FERAL_SHELL_CROSS_PROBE==self then scope.FERAL_SHELL_CROSS_PROBE=nil end
    print("[FERAL shell probe] stopped")
end
local hippo=ReplicatedStorage:FindFirstChild("FeralHippo")
if hippo and hippo:IsA("RemoteEvent") then
    connect(hippo.OnClientEvent,function(kind,...)
        local args=table.pack(...)
        note("hippo_server_reply",{kind=tostring(kind),strength=finite(args[4]) and args[4] or nil,
            hit=type(args[5])=="boolean" and args[5] or nil,
            actorIsSelf=args[1]==player.Character,snapshot=probe:snapshot()})
        if kind=="cancel" and probe.pending then
            probe.pending=nil
            note("cancel_observed_during_attempt",{serverAcceptance="not established"})
        end
    end)
end
local hit=ReplicatedStorage:FindFirstChild("FeralHit")
if hit and hit:IsA("RemoteEvent") then
    connect(hit.OnClientEvent,function(kind,data)
        if type(data)~="table" then return end
        note("hit_server_reply",{kind=tostring(kind),targetIsSelf=data.v==player.Character,
            attackerIsSelf=data.a==player.Character,damage=finite(data.dmg) and data.dmg or nil,
            safe=data.safe==true,snapshot=probe:snapshot()})
    end)
end
connect(player.CharacterAdded,function(char)if probe.active then attach(char)end end)
connect(player.CharacterRemoving,function()if probe.active then attach(nil)end end)
connect(UserInputService.InputBegan,function(input,processed)
    if not probe.active or processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.F7 then probe:attempt()
    elseif input.KeyCode==Enum.KeyCode.F8 then probe:export()
    elseif input.KeyCode==Enum.KeyCode.F9 then probe:close() end
end)
attach(player.Character)
print("[FERAL shell probe] ready · F7 one resting-Turtle test · F8 export · F9 stop")
return probe
