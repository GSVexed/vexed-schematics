-- FERAL NOVA PRIME v13 / victim-only escape, preserves all own carry intents.
-- Captured FeralLungeUI: TUG_MIN_GAP=.10, SHAKE_MIN_GAP=.15,
-- SHAKE_MASH=false (directional FeralShakeTaps), getoff gap=.40.
-- Only sends native actions while its OWN character reports a grab
-- or the native grab control is actually bound. Server acceptance unknown.
local Escape={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local CAS=game:GetService("ContextActionService")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer

local function num(v)
    return type(v)=="number" and v==v and v>=0 and v<1e8
end
local function on(obj,key)
    return obj and obj:GetAttribute(key)==true
end
local function positive(obj,key)
    local a=obj and obj:GetAttribute(key)
    return num(a) and a>0
end

function Escape.choose(carry,pinned,clamp,need,bindings)
    bindings=bindings or {}
    if carry then return "getoff","CARRIED",.405 end
    -- The captured game has SHAKE_MASH=false. In that mode
    -- FeralShakeTaps is the actual A/D escape binding.
    local shakeBinding=bindings.FeralShakeTaps or bindings.FeralShakeMash
    local tugBinding=bindings.FeralTugTap
    if (clamp or need or pinned) and tugBinding then
        return "shake","TUG PREY",.105
    end
    if (clamp or need or pinned) and shakeBinding then
        return "shake","DIRECTIONAL SHAKE",.153
    end
    if pinned and (clamp or need) then
        return "shake","PINNED CLAMP STATE",.155
    end
    if clamp and need then
        return "shake","CLAMP PROGRESS",.155
    end
    -- The pinned cue alone is not proof that a shake request is allowed;
    -- don't send arbitrary game traffic without a native escape binding.
    return nil,"UNCLASSIFIED PIN",nil
end

function Escape.attach(ctx)
    local E={
        alive=true,enabled=true,status="WATCHING",
        trigger="",mode="NONE",input="NO INJECTION",
        nativeCount=0,pulses=0,detections=0,
        attempts={getoff=0,shake=0},
        progress=0,releaseEvents=0,
        cases=0,activeSince=0,longest=0,
        lastShakeHave=nil,lastClamp=nil,
        noProgressWarnings=0,lastError="",
        holdingPauses=0,carryIntentPauses=0,lastCarryState="FREE",
        lastCharacter=nil,bindings={},
        nextBindings=0,nextScan=0,nextAction=0,
        nextKey=0,down=false,token=0,active=false,
        fallbackUntil=0,fallbackReason="",
        lastAction="",nextReport=0,
        pendingFeedback=false
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
    if type(kp)=="function" and type(kr)=="function" then
        press=function()kp(0x20)end
        release=function()kr(0x20)end
        E.input="EXECUTOR"
    else
        local ok,vim=pcall(function()return game:GetService("VirtualInputManager")end)
        if ok and vim then
            press=function()vim:SendKeyEvent(true,Enum.KeyCode.Space,false,game)end
            release=function()vim:SendKeyEvent(false,Enum.KeyCode.Space,false,game)end
            E.input="VIRTUAL INPUT"
        end
    end
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local charConnections={}
    local forceRead=false
    local function drop()
        if E.down then
            E.down=false;E.token+=1
            if release then pcall(release)end
        end
    end
    local function resetEpisode()
        if E.active then
            E.longest=math.max(E.longest,os.clock()-E.activeSince)
        end
        E.active=false
        E.mode="NONE"
        E.pendingFeedback=false
        E.lastShakeHave=nil
        E.lastClamp=nil
        drop()
    end
    local function connectChar(char)
        for _,c in ipairs(charConnections) do pcall(function()c:Disconnect()end)end
        table.clear(charConnections)
        resetEpisode()
        E.lastCharacter=char
        E.nextAction=0
        E.nextBindings=0
        forceRead=true
        if char then
            for _,key in ipairs({"FeralCarried","FeralPinned","FeralClampN",
                "FeralClampGame","FeralShakeHave","FeralShakeNeed",
                "FeralDowned"}) do
                local ok,c=pcall(function()
                    return char:GetAttributeChangedSignal(key):Connect(function()
                        forceRead=true
                        E.nextBindings=0
                    end)
                end)
                if ok then charConnections[#charConnections+1]=c end
            end
        end
    end
    connectChar(player.Character)
    E.charConnection=player.CharacterAdded:Connect(connectChar)

    local function updateBindings(now)
        if now<E.nextBindings and not forceRead then return end
        E.nextBindings=now+.12
        forceRead=false
        local ok,value=pcall(function()return CAS:GetAllBoundActionInfo()end)
        if ok and type(value)=="table" then
            E.bindings={
                FeralCarryEscape=value.FeralCarryEscape~=nil,
                FeralShakeTaps=value.FeralShakeTaps~=nil,
                FeralShakeMash=value.FeralShakeMash~=nil,
                FeralTugTap=value.FeralTugTap~=nil
            }
        end
    end

    local function fallback(char,now)
        if now<E.nextScan then return end
        E.nextScan=now+.40
        if on(char,"FeralPinned") then
            E.fallbackUntil=now+.46
            E.fallbackReason="PINNED"
            return
        end
        if not pg then return end
        local checked=0
        for _,node in ipairs(pg:GetDescendants()) do
            checked+=1
            if checked>420 then break end
            if node:IsA("TextLabel") and node.Visible
                and (not ctx.ui or not node:IsDescendantOf(ctx.ui)) then
                local s=string.upper(node.Text or "")
                if (string.find(s,"ESCAPE",1,true)
                    or string.find(s,"SHAKE",1,true))
                    and string.find(s,"SPACE",1,true) then
                    E.fallbackUntil=now+.45
                    E.fallbackReason="ESCAPE PROMPT"
                    return
                end
            end
        end
    end

    local function pulse(now)
        if not press then E.status="KEYBOARD UNAVAILABLE";return end
        if E.down or now<E.nextKey then return end
        E.nextKey=now+.16
        local ok,err=pcall(press)
        if not ok then E.lastError=tostring(err);E.status="SPACE BLOCKED";return end
        E.down=true;E.pulses+=1
        E.status="SPACE FALLBACK (UNVERIFIED)"
        E.token+=1
        local token=E.token
        task.delay(.045,function()
            if E.alive and E.token==token then drop()end
        end)
    end

    local function observeProgress(char)
        local have=char:GetAttribute("FeralShakeHave")
        if num(have) then
            if E.lastShakeHave and have>E.lastShakeHave+.01 then
                E.progress+=1
                E.pendingFeedback=false
            end
            E.lastShakeHave=have
        end
        local clamp=char:GetAttribute("FeralClampN")
        if not num(clamp) then clamp=char:GetAttribute("FeralClampGame")end
        if num(clamp) then
            if E.lastClamp and clamp<E.lastClamp-.01 then
                E.progress+=1
                E.pendingFeedback=false
            end
            E.lastClamp=clamp
        end
    end

    local function tick()
        if not E.alive or not ctx.state.alive or not E.enabled then return end
        local now=os.clock()
        if UIS:GetFocusedTextBox() then
            drop()
            E.status="PAUSED FOR CHAT"
            return
        end
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if char~=E.lastCharacter then connectChar(char)end
        if not char or not char.Parent or not hum or hum.Health<=0
            or on(player,"FeralMenuOpen") then
            resetEpisode()
            E.status="WAITING FOR ANIMAL"
            return
        end
        local carryState,holding,victim="UNKNOWN",false,false
        if ctx.carry and ctx.carry.classify then
            carryState,holding,victim=ctx.carry.classify(char)
        else
            -- Safe fallback when the native carry tracker is missing.
            local obj=char:FindFirstChild("FeralClamp")
            holding=obj and obj:IsA("ObjectValue")
                and (obj:GetAttribute("Carry")==true
                    or obj.Value and obj.Value.Parent~=nil)
                or char:GetAttribute("FeralCarcassCarry")==true
            victim=on(char,"FeralCarried") or on(char,"FeralPinned")
                or on(char,"FeralDragged")
        end
        E.lastCarryState=carryState
        -- Owner's outgoing FeralClamp can exist during a real grab.
        -- This is NOT evidence the owner is a victim; never spam
        -- "shake/getoff" while they carry prey or a carcass.
        if holding and not victim then
            if E.active then resetEpisode() end
            if E.status~="CARRYING / ESCAPE NOT NEEDED" then
                E.holdingPauses+=1
            end
            E.status="CARRYING / ESCAPE NOT NEEDED"
            return
        end
        -- Native G input has an unavoidable replication transition.
        -- Never mistake one's outgoing pickup/drop animation for an
        -- incoming enemy grab merely because the clamp attributes lag.
        if not victim and ctx.carry then
            local lastG=math.max(ctx.carry.lastInputAt or -math.huge,
                ctx.carry.lastAt or -math.huge)
            if now-lastG<.58 then
                if E.active then resetEpisode() end
                E.status="CARRY ACTION / ESCAPE SUSPENDED"
                E.carryIntentPauses+=1
                return
            end
        end
        updateBindings(now)
        local carried=on(char,"FeralCarried")
        local pinned=on(char,"FeralPinned")
        local clamp=positive(char,"FeralClampN") or positive(char,"FeralClampGame")
        local need=positive(char,"FeralShakeNeed")
        local hasCue=carried or pinned or clamp or need
        local mode,reason,interval=Escape.choose(carried,pinned,clamp,need,E.bindings)
        if not hasCue then
            if E.active then
                E.releaseEvents+=1
                resetEpisode()
            end
            E.status="WATCHING"
            return
        end
        if not E.active then
            E.active=true
            E.activeSince=now
            E.cases+=1
            E.detections+=1
            E.nextAction=0
            E.lastShakeHave=nil
            E.lastClamp=nil
        end
        E.trigger=reason or "grab cue"
        observeProgress(char)
        local spent=now-E.activeSince
        E.longest=math.max(E.longest,spent)
        if mode then
            E.mode=mode
            E.status="ESCAPING / "..reason
            drop()
            if now<E.nextAction then return end
            E.nextAction=now+interval
            local remote=RS:FindFirstChild("FeralLunge")
            if not remote or not remote:IsA("RemoteEvent") then
                E.status="ESCAPE REMOTE MISSING"
                E.lastError="FeralLunge RemoteEvent unavailable"
                return
            end
            local ok,err=pcall(function()remote:FireServer(mode)end)
            if ok then
                E.nativeCount+=1
                E.attempts[mode]+=1
                E.lastAction=mode
                if spent>2.5 and E.progress==0 and E.noProgressWarnings<1 then
                    E.noProgressWarnings+=1
                    E.status="NO OBSERVED ESCAPE PROGRESS"
                end
            else
                E.lastError=tostring(err)
                E.status="NATIVE INPUT ERROR"
            end
        else
            E.mode="FALLBACK"
            fallback(char,now)
            if now<E.fallbackUntil then
                pulse(now)
            else
                E.status="GRABBED / NO CONFIRMED ACTION"
            end
        end
    end

    function E.setEnabled(v)
        E.enabled=v==true
        if E.enabled then
            E.status="WATCHING"
            E.nextBindings=0
            E.nextAction=0
        else
            resetEpisode()
            E.status="OFF"
        end
    end
    function E.report()
        return table.concat({
            "FERAL NOVA PRIME v13 | Escape",
            "status="..E.status.." enabled="..tostring(E.enabled),
            "last_cue="..E.trigger,
            "last_action="..E.lastAction.." mode="..E.mode,
            "getoff_requests="..tostring(E.attempts.getoff),
            "shake_requests="..tostring(E.attempts.shake),
            "space_fallback_pulses="..tostring(E.pulses),
            "grab_episodes="..tostring(E.cases),
            "observed_releases="..tostring(E.releaseEvents),
            "shake_progress_changes="..tostring(E.progress),
            "longest_grab_seconds="..string.format("%.2f",E.longest),
            "binding_taps="..tostring(E.bindings.FeralShakeTaps),
            "binding_tug="..tostring(E.bindings.FeralTugTap),
            "binding_mash="..tostring(E.bindings.FeralShakeMash),
            "carrying_pauses="..tostring(E.holdingPauses),
            "carry_action_grace_frames="..tostring(E.carryIntentPauses),
            "carry_or_capture_state="..E.lastCarryState,
            "input="..E.input,
            "last_error="..E.lastError,
            "NOTE=Native requests and observed release do not prove which action caused release."
        },"\n")
    end
    function E.close()
        E.alive=false
        E.setEnabled(false)
        if E.connection then E.connection:Disconnect()end
        if E.charConnection then E.charConnection:Disconnect()end
        for _,c in ipairs(charConnections) do pcall(function()c:Disconnect()end)end
        table.clear(charConnections)
    end
    E.connection=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            E.lastError=tostring(err)
            E.status="ESCAPE ERROR"
            drop()
        end
    end)
    return E
end
return Escape
