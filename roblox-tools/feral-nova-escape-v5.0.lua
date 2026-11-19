-- FERAL NOVA PRIME v5 - bounded, automatic, no-ALT escape watcher.
-- Watches only replicated own-victim cues, active UI escape prompts and
-- connections between own body and a different player's character.
local Escape={}
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local CAS=game:GetService("ContextActionService")
local player=Players.LocalPlayer

local keys={
    "grabbed","beingheld","heldby","pinned","latched","struggling",
    "constricted","takedownvictim","escapeactive","grappledvictim"
}
local exclusions={"cooldown","progress","available","can","chance","climb"}

local function active(value)
    if value==true then return true end
    if type(value)=="number" then return value>0 end
    if typeof(value)=="Instance" then return value.Parent~=nil end
    if type(value)=="string" then
        local s=string.lower(value)
        return s~="" and s~="false" and s~="none" and s~="nil" and s~="0"
    end
    return false
end
local function victimAttribute(obj)
    if not obj then return false end
    local ok,attributes=pcall(function()return obj:GetAttributes()end)
    if not ok or type(attributes)~="table" then return false end
    for name,value in pairs(attributes) do
        local k=string.lower(name)
        local allow=false
        for _,word in ipairs(keys) do
            if string.find(k,word,1,true) then allow=true;break end
        end
        if allow and active(value) then
            local exclude=false
            for _,word in ipairs(exclusions) do
                if string.find(k,word,1,true) then exclude=true;break end
            end
            if not exclude then return true,"character state" end
        end
    end
    return false
end
local function visible(node)
    local count=0
    while node and count<16 do
        count+=1
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") then return node.Enabled end
        node=node.Parent
    end
    return false
end
local function escapePrompt(gui,ourGui)
    local nodes=gui:GetDescendants()
    local examined=0
    for _,node in ipairs(nodes) do
        examined+=1
        if examined>650 then break end
        if (node:IsA("TextLabel") or node:IsA("TextButton"))
            and (not ourGui or not node:IsDescendantOf(ourGui))
            and visible(node) then
            local msg=string.upper(node.Text or "")
            if #msg>=6 and #msg<=125 then
                local space=string.find(msg,"SPACE",1,true)
                local required=string.find(msg,"ESCAPE",1,true)
                    or string.find(msg,"BREAK FREE",1,true)
                    or string.find(msg,"STRUGGLE",1,true)
                    or string.find(msg,"GET FREE",1,true)
                local repeats=string.find(msg,"MASH SPACE",1,true)
                    or string.find(msg,"SPAM SPACE",1,true)
                    or string.find(msg,"TAP SPACE",1,true)
                if (space and required) or repeats then
                    return true,"escape prompt"
                end
            end
        end
    end
    return false
end
local function validConnection(char)
    local root=char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local otherCharacters={}
    for _,other in ipairs(Players:GetPlayers()) do
        if other~=player and other.Character then
            local oRoot=other.Character:FindFirstChild("HumanoidRootPart")
            if oRoot and (root.Position-oRoot.Position).Magnitude<26 then
                otherCharacters[#otherCharacters+1]=other.Character
            end
        end
    end
    if #otherCharacters==0 then return false end
    local function linked(item)
        if not (item:IsA("WeldConstraint") or item:IsA("Weld")
            or item:IsA("Motor6D")) then return false end
        local a,b=item.Part0,item.Part1
        if not a or not b then return false end
        for _,other in ipairs(otherCharacters) do
            if a:IsDescendantOf(char) and b:IsDescendantOf(other)
                or b:IsDescendantOf(char) and a:IsDescendantOf(other) then
                return true
            end
        end
        return false
    end
    local function scan(model)
        local i=0
        for _,inst in ipairs(model:GetDescendants()) do
            i+=1
            if i>450 then break end
            if linked(inst) then return true end
        end
        return false
    end
    if scan(char) then return true,"player latch joint" end
    for i=1,math.min(#otherCharacters,5) do
        if scan(otherCharacters[i]) then return true,"player latch joint" end
    end
    return false
end


-- Confirmed in a FERAL client capture from 18 Nov 2026:
-- Character.FeralCarried -> "getoff"; own clamp/shake progress -> "shake".
-- These are the same native FeralLunge RemoteEvent verbs used by the UI.
-- We do NOT call them without the local animal's own active escape state.
local function nativeEscapeMode(char)
    if char:GetAttribute("FeralCarried")==true then
        return "getoff","carried escape"
    end
    local clamp=char:GetAttribute("FeralClampGame")
    if type(clamp)~="number" then
        clamp=char:GetAttribute("FeralClampN")
    end
    if type(clamp)=="number" and clamp>0 and clamp<1000 then
        return "shake","shake off attacker"
    end
    -- Native actions are bound only while the corresponding FERAL
    -- escape interaction is active, even if an attribute hasn't replicated.
    local ok,bindings=pcall(function()
        return CAS:GetAllBoundActionInfo()
    end)
    if ok and type(bindings)=="table" then
        if bindings.FeralCarryEscape then
            return "getoff","active carry escape bind"
        end
        if bindings.FeralShakeMash then
            return "shake","active shake escape bind"
        end
        -- FeralTugTap can also belong to a HUNTER. Require local prey
        -- progress, never auto squeeze or shake just because a grab is held.
        local need=char:GetAttribute("FeralShakeNeed")
        if bindings.FeralTugTap and type(need)=="number" and need>0 then
            return "shake","active tug escape bind"
        end
    end
    return nil,nil
end

function Escape.attach(ctx)
    local e={
        alive=true,enabled=true,status="WATCHING",source="",
        pulses=0,lastInputError="",input="UNAVAILABLE",
        lastScan=0,holdUntil=0,nextPulse=0,down=false,token=0,
        successes=0,nativeCount=0,nextNative=0,
        nextNativeCheck=0,nativeMode=nil,nativeReason=nil,
        lastCharacter=nil
    }
    local env
    if type(getgenv)=="function" then
        local ok,result=pcall(getgenv)
        if ok and type(result)=="table" then env=result end
    end
    local kp=(type(keypress)=="function" and keypress)
        or (env and type(env.keypress)=="function" and env.keypress)
    local kr=(type(keyrelease)=="function" and keyrelease)
        or (env and type(env.keyrelease)=="function" and env.keyrelease)
    local press,release
    if kp and kr then
        press=function()kp(0x20)end
        release=function()kr(0x20)end
        e.input="EXECUTOR"
    else
        local ok,vim=pcall(function()return game:GetService("VirtualInputManager")end)
        if ok and vim then
            press=function()vim:SendKeyEvent(true,Enum.KeyCode.Space,false,game)end
            release=function()vim:SendKeyEvent(false,Enum.KeyCode.Space,false,game)end
            e.input="VIRTUAL INPUT"
        end
    end
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local function stopPress()
        if e.down then
            e.down=false
            e.token+=1
            if release then pcall(release) end
        end
    end
    function e.setEnabled(on)
        e.enabled=(on==true)
        if not e.enabled then
            e.holdUntil=0;e.status="OFF";stopPress()
        else
            e.status=press and "WATCHING" or "NO KEY INJECTION"
        end
    end
    function e.close()
        e.alive=false
        e.setEnabled(false)
        if e.connection then e.connection:Disconnect()end
    end
    local function tick()
        if not e.alive or not e.enabled or not ctx.state.alive then return end
        local now=os.clock()
        if UIS:GetFocusedTextBox() then
            e.holdUntil=0;e.status="CHAT PAUSED";stopPress();return
        end
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health<=0
            or player:GetAttribute("FeralMenuOpen")==true then
            e.holdUntil=0;e.nativeMode=nil
            e.status="WAITING FOR ANIMAL";stopPress();return
        end
        if char~=e.lastCharacter then
            e.lastCharacter=char;e.nativeMode=nil
            e.nextNativeCheck=0;e.holdUntil=0
        end
        -- Prefer the game's actual escape action over executor-simulated
        -- Space whenever the recovered game-specific victim state is present.
        -- This also works when Velocity cannot inject keyboard events.
        if now>=e.nextNativeCheck then
            e.nextNativeCheck=now+.15
            e.nativeMode,e.nativeReason=nativeEscapeMode(char)
        end
        local nativeAction,nativeReason=e.nativeMode,e.nativeReason
        if nativeAction then
            e.holdUntil=now+.34
            e.source=nativeReason
            stopPress()
            if now>=e.nextNative then
                local remote=RS:FindFirstChild("FeralLunge")
                if remote and remote:IsA("RemoteEvent") then
                    -- Match native client pacing: carry getoff >=0.4 seconds;
                    -- shake calls >= the 0.15s game-side minimum interval.
                    e.nextNative=now+(nativeAction=="getoff" and .43 or .23)
                    local ok,err=pcall(function()
                        remote:FireServer(nativeAction)
                    end)
                    if ok then
                        e.nativeCount+=1
                        e.status="SENDING ESCAPE"
                        return
                    else
                        e.lastInputError=tostring(err)
                        e.status="NATIVE INPUT ERROR"
                    end
                end
            else
                e.status="SENDING ESCAPE"
                return
            end
        end
        if now-e.lastScan>=.25 then
            e.lastScan=now
            local yes,reason=victimAttribute(char)
            if not yes then yes,reason=victimAttribute(hum)end
            if not yes then yes,reason=victimAttribute(player)end
            if not yes then
                local ok,a,b=pcall(validConnection,char)
                if ok then yes,reason=a,b end
            end
            if not yes and pg then
                local ok,a,b=pcall(escapePrompt,pg,ctx.ui)
                if ok then yes,reason=a,b end
            end
            if yes then
                e.holdUntil=now+.32
                e.source=reason or "grab cue"
            end
        end
        if now>e.holdUntil then
            e.status=press and "WATCHING" or "NO KEY INJECTION"
            stopPress()
            return
        end
        if not press then e.status="NO KEY INJECTION";return end
        if now<e.nextPulse or e.down then return end
        e.nextPulse=now+.125
        local ok,err=pcall(press)
        if not ok then
            e.lastInputError=tostring(err)
            e.setEnabled(false)
            e.status="KEY INPUT BLOCKED"
            return
        end
        e.down=true
        e.pulses+=1
        e.status="ESCAPING"
        e.token+=1
        local token=e.token
        task.delay(.05,function()
            if e.alive and e.token==token then stopPress() end
        end)
    end
    e.connection=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            e.lastInputError=tostring(err)
            e.setEnabled(false)
            e.status="ESCAPE ERROR"
        end
    end)
    return e
end
return Escape
