-- Optional hearing assistance for the default Roblox Audio API voice graph.
-- This module never touches the microphone, chat controls, voice permissions,
-- voice wires, remotes, player positions or any combat/minigame subsystem.
local Voice = {}

local function finite(x)
    return type(x)=="number" and x==x and x>=0 and x<1e8
end
function Voice.cloneCurve(curve)
    if type(curve)~="table" then return nil end
    local out,n={},0
    for distance,volume in pairs(curve) do
        if not finite(distance) or not finite(volume) or volume>1 then return nil end
        out[distance]=volume
        n+=1
        if n>400 then return nil end
    end
    return n>0 and out or nil
end
function Voice.scaleCurve(curve,scale)
    if not finite(scale) or scale<1 or scale>1.5 then return nil end
    local source=Voice.cloneCurve(curve)
    if not source then return nil end
    local out={}
    for distance,volume in pairs(source) do
        local farther=distance==0 and 0 or math.floor(distance*scale*10000+.5)/10000
        if out[farther]~=nil then return nil end
        out[farther]=volume
    end
    return out
end
function Voice.sameCurve(a,b)
    if type(a)~="table" or type(b)~="table" then return false end
    local left,right=0,0
    for distance,volume in pairs(a) do
        left+=1
        if not finite(distance) or not finite(volume)
            or not finite(b[distance]) or math.abs(volume-b[distance])>.0001 then return false end
    end
    for _ in pairs(b) do right+=1 end
    return left==right
end

function Voice.new(players,localPlayer)
    local v={players=players,localPlayer=localPlayer,closed=false,started=false,
        enabled=false,factor=1.25,records={},playerConns={},charConns={},
        characters={},connections={},skipped=0,conflicts=0}
    local function connect(bucket,signal,handler)
        if not signal then return end
        local ok,connection=pcall(function() return signal:Connect(handler) end)
        if ok and connection then table.insert(bucket,connection) end
    end
    local function disconnect(bucket)
        for i=#bucket,1,-1 do
            pcall(function() bucket[i]:Disconnect() end)
            bucket[i]=nil
        end
    end
    local function sameBounds(a,b)
        return a and b and finite(a.Min) and finite(a.Max)
            and finite(b.Min) and finite(b.Max)
            and math.abs(a.Min-b.Min)<.001 and math.abs(a.Max-b.Max)<.001
    end
    local function restore(emitter)
        local record=v.records[emitter]
        if not record then return end
        v.records[emitter]=nil
        local ok=pcall(function()
            if emitter.Parent==nil then return end
            if emitter.DistanceAttenuationMode~=record.mode then
                v.conflicts+=1;return
            end
            if record.custom then
                if not Voice.sameCurve(emitter:GetDistanceAttenuation(),record.modified) then
                    v.conflicts+=1;return
                end
                emitter:SetDistanceAttenuation(record.original)
            else
                if not sameBounds(emitter.DistanceAttenuationBounds,record.modified) then
                    v.conflicts+=1;return
                end
                emitter.DistanceAttenuationBounds=record.original
            end
        end)
        if not ok then v.conflicts+=1 end
    end
    local function restorePlayer(remote)
        local found={}
        for emitter,record in pairs(v.records) do
            if record.player==remote then table.insert(found,emitter) end
        end
        for _,emitter in ipairs(found) do restore(emitter) end
    end
    local function apply(remote,emitter)
        if v.closed or not v.enabled or v.records[emitter] then return end
        -- Never alter an unrelated ambient sound or a user's own microphone.
        if remote==localPlayer or remote.Character~=emitter.Parent
            or not emitter:IsA("AudioEmitter") or emitter.Name~="AudioEmitter"
            or not remote:FindFirstChildOfClass("AudioDeviceInput") then return end
        local modeOK,mode=pcall(function() return emitter.DistanceAttenuationMode end)
        if not modeOK or mode==nil then v.skipped+=1;return end
        local custom=mode==Enum.DistanceAttenuationMode.Custom
        if custom then
            local ok,before=pcall(function() return emitter:GetDistanceAttenuation() end)
            local old=ok and Voice.cloneCurve(before) or nil
            -- Empty curves use Roblox's default inverse rolloff, which cannot
            -- be losslessly stretched. Do not replace it with a fabricated curve.
            local desired=old and Voice.scaleCurve(old,v.factor)
            if not desired then v.skipped+=1;return end
            local wrote=pcall(function() emitter:SetDistanceAttenuation(desired) end)
            local read,after=pcall(function() return emitter:GetDistanceAttenuation() end)
            if not wrote or not read or not Voice.sameCurve(after,desired) then
                v.skipped+=1
                if read and Voice.sameCurve(after,desired) then
                    pcall(function() emitter:SetDistanceAttenuation(old) end)
                end
                return
            end
            v.records[emitter]={player=remote,mode=mode,custom=true,original=old,modified=desired}
        else
            local ok,before=pcall(function() return emitter.DistanceAttenuationBounds end)
            if not ok or not before or not finite(before.Min) or not finite(before.Max)
                or before.Max<=before.Min then v.skipped+=1;return end
            local desired=NumberRange.new(before.Min*v.factor,before.Max*v.factor)
            local wrote=pcall(function() emitter.DistanceAttenuationBounds=desired end)
            local read,after=pcall(function() return emitter.DistanceAttenuationBounds end)
            if not wrote or not read or not sameBounds(after,desired) then
                v.skipped+=1;return
            end
            v.records[emitter]={player=remote,mode=mode,custom=false,original=before,modified=desired}
        end
    end
    local function scan(remote)
        if v.closed or not v.enabled or remote==localPlayer then return end
        local char=remote.Character
        if not char or not remote:FindFirstChildOfClass("AudioDeviceInput") then return end
        for _,child in ipairs(char:GetChildren()) do
            if child:IsA("AudioEmitter") then apply(remote,child) end
        end
    end
    local function detachCharacter(remote)
        local bucket=v.charConns[remote]
        if bucket then disconnect(bucket) end
        v.charConns[remote]=nil;v.characters[remote]=nil
        restorePlayer(remote)
    end
    local watchCharacter
    watchCharacter=function(remote,char)
        if v.characters[remote]==char then scan(remote);return end
        detachCharacter(remote)
        v.characters[remote]=char
        local bucket={}
        v.charConns[remote]=bucket
        connect(bucket,char.ChildAdded,function(child)
            if child:IsA("AudioEmitter") then apply(remote,child) end
        end)
        connect(bucket,char.ChildRemoved,function(child)
            if v.records[child] then restore(child) end
        end)
        scan(remote)
    end
    local function detachPlayer(remote)
        detachCharacter(remote)
        local bucket=v.playerConns[remote]
        if bucket then disconnect(bucket) end
        v.playerConns[remote]=nil
    end
    local function watchPlayer(remote)
        if remote==localPlayer or v.playerConns[remote] then return end
        local bucket={}
        v.playerConns[remote]=bucket
        connect(bucket,remote.CharacterAdded,function(char)
            if not v.closed then watchCharacter(remote,char) end
        end)
        connect(bucket,remote.CharacterRemoving,function()
            detachCharacter(remote)
        end)
        connect(bucket,remote.ChildAdded,function(child)
            if child:IsA("AudioDeviceInput") then scan(remote) end
        end)
        if remote.Character then watchCharacter(remote,remote.Character) end
    end

    function v:start()
        if self.started or self.closed then return end
        self.started=true
        connect(self.connections,players.PlayerAdded,function(remote)
            if not self.closed then watchPlayer(remote) end
        end)
        connect(self.connections,players.PlayerRemoving,function(remote)
            detachPlayer(remote)
        end)
        for _,remote in ipairs(players:GetPlayers()) do watchPlayer(remote) end
    end
    function v:setEnabled(on)
        if self.closed then return false end
        if not self.started then self:start() end
        self.enabled=on==true
        if self.enabled then
            for _,remote in ipairs(players:GetPlayers()) do
                watchPlayer(remote)
                if remote.Character then watchCharacter(remote,remote.Character) end
                scan(remote)
            end
        else
            local affected={}
            for emitter in pairs(self.records) do table.insert(affected,emitter) end
            for _,emitter in ipairs(affected) do restore(emitter) end
        end
        return true
    end
    function v:status()
        local adjusted=0
        for emitter in pairs(self.records) do
            if emitter.Parent then adjusted+=1 end
        end
        return {enabled=self.enabled,adjusted=adjusted,
            skipped=self.skipped,conflicts=self.conflicts}
    end
    function v:summary()
        if not self.enabled then return "Default hearing restored" end
        local status=self:status()
        if status.adjusted>0 then
            return "Local voice rolloff +25%; server hearing limit unchanged"
        end
        return "Waiting for compatible proximity voice audio; server limit unchanged"
    end
    function v:close()
        if self.closed then return end
        self:setEnabled(false)
        self.closed=true
        disconnect(self.connections)
        local peers={}
        for remote in pairs(self.playerConns) do table.insert(peers,remote) end
        for _,remote in ipairs(peers) do detachPlayer(remote) end
    end
    return v
end

return Voice
