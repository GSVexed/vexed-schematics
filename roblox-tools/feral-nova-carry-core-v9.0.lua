-- FERAL NOVA CORE v9.0 / hub-initiated carry respects Grab V2 action priority.
-- FeralCarryClient uses G and sets _G.FeralCarryCan / _G.FeralCarryPress.
-- Predator holding prey: own FeralClamp ObjectValue with Carry or Value.
-- Carcass holding: own FeralCarcassCarry attribute.
-- Victim: own FeralCarried/FeralPinned/FeralDragged attributes.
-- Never sends fabricated pickup/drop remotes or changes physics.
local Carry={}
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer

function Carry.classify(char)
    if not char or not char.Parent then
        return "NO ANIMAL",false,false
    end
    if char:GetAttribute("FeralCarried")==true then
        return "BEING CARRIED",false,true
    end
    if char:GetAttribute("FeralPinned")==true then
        return "PINNED BY ENEMY",false,true
    end
    if char:GetAttribute("FeralDragged")==true then
        return "BEING DRAGGED",false,true
    end
    local clamp=char:FindFirstChild("FeralClamp")
    if clamp and clamp:IsA("ObjectValue") then
        local carried=clamp:GetAttribute("Carry")==true
        local hasTarget=clamp.Value and clamp.Value.Parent~=nil
        if carried then return "HOLDING PREY",true,false end
        if hasTarget then return "GRAPPLING PREY",true,false end
    end
    if char:GetAttribute("FeralCarcassCarry")==true then
        return "HOLDING CARCASS",true,false
    end
    local localClamp=char:FindFirstChild("FeralClampLocal")
    if localClamp and localClamp:IsA("ObjectValue")
        and localClamp.Value and localClamp.Value.Parent then
        return "LOCAL GRAPPLE",true,false
    end
    return "FREE",false,false
end

function Carry.attach(ctx)
    local C={
        classify=Carry.classify,
        alive=true,enabled=true,status="WAITING FOR ANIMAL",
        state="NO ANIMAL",holding=false,victim=false,
        canInteract=false,action="G",helper="UNAVAILABLE",
        method="NONE",attempts=0,helperCalls=0,keyboardTaps=0,
        blocked=0,preemptedRest=0,lastError="",lastAt=-math.huge,
        nextRefresh=0,refreshes=0,
        lastInputAt=-math.huge,lastState="NO ANIMAL",
        changes=0,holdingEpisodes=0,victimEpisodes=0
    }
    local env
    if type(getgenv)=="function" then
        local ok,result=pcall(getgenv)
        if ok and type(result)=="table" then env=result end
    end
    local kp=(type(keypress)=="function" and keypress)
        or env and type(env.keypress)=="function" and env.keypress
    local kr=(type(keyrelease)=="function" and keyrelease)
        or env and type(env.keyrelease)=="function" and env.keyrelease
    local press,release
    if type(kp)=="function" and type(kr)=="function" then
        press=function()kp(0x47)end
        release=function()kr(0x47)end
        C.method="EXECUTOR G"
    else
        local ok,vim=pcall(function()return game:GetService("VirtualInputManager")end)
        if ok and vim then
            press=function()vim:SendKeyEvent(true,Enum.KeyCode.G,false,game)end
            release=function()vim:SendKeyEvent(false,Enum.KeyCode.G,false,game)end
            C.method="VIRTUAL G"
        end
    end
    local connections={}
    local currentToken=0
    local function native()
        local fn=type(_G)=="table" and _G.FeralCarryPress or nil
        local can=type(_G)=="table" and _G.FeralCarryCan or nil
        if type(fn)=="function" then
            local ok,allowed=pcall(function()
                return type(can)~="function" or can()==true
            end)
            C.helper="GAME CARRY HELPER"
            return fn,ok and allowed
        end
        C.helper="G KEY FALLBACK"
        return nil,false
    end
    local function releaseForCarry()
        local preempt=false
        if ctx.mobile and ctx.mobile.beforeCarry then
            local ok,done=pcall(ctx.mobile.beforeCarry)
            if ok and done then preempt=true end
        end
        if ctx.native and ctx.native.beforeCarry then
            local ok,done=pcall(ctx.native.beforeCarry)
            if ok and done then preempt=true end
        end
        if ctx.recovery and ctx.recovery.beforeCarry then
            local ok,done=pcall(ctx.recovery.beforeCarry)
            if ok and done then preempt=true end
        end
        if ctx.flight and ctx.flight.beforeCarry then
            -- Native G must always undo a temporary local drag mode first.
            pcall(ctx.flight.beforeCarry)
        end
        if preempt then C.preemptedRest+=1 end
        return preempt
    end

    local function refresh()
        local char=player.Character
        local state,holding,victim=Carry.classify(char)
        if state~=C.lastState then
            C.changes+=1
            if holding then C.holdingEpisodes+=1 end
            if victim then C.victimEpisodes+=1 end
            C.lastState=state
        end
        C.state=state
        C.holding=holding
        C.victim=victim
        local fn,can=native()
        local nativeAvailable=type(fn)=="function" and (can or holding)
        C.canInteract=(nativeAvailable or type(press)=="function") and
            not victim and state~="NO ANIMAL"
        C.action=holding and "DROP / RELEASE"
            or victim and "ESCAPE FIRST"
            or can and "PICK UP / CARRY"
            or type(press)=="function" and "TRY G"
            or "USE G"
        C.status=victim and "ESCAPE PRIORITY"
            or holding and ("CARRY PRESERVED: "..state)
            or state=="NO ANIMAL" and "WAITING FOR ANIMAL"
            or can and "NATIVE CARRY READY"
            or "CARRY VIA G WHEN AVAILABLE"
    end
    function C.beforeCarry()
        return releaseForCarry()
    end
    local function mayCarry()
        if ctx.action and type(ctx.action.allowed)=="function" then
            local ok,allowed,reason=pcall(ctx.action.allowed,"carry")
            if not ok then return false,"ACTION CORE ERROR" end
            return allowed,reason
        end
        return true,"NO ACTION CORE"
    end
    function C.press()
        if not C.alive then return false end
        local safe,why=mayCarry()
        if not safe then
            C.blocked+=1
            C.lastError="Carry action priority: "..tostring(why)
            C.status="CARRY INPUT BLOCKED / "..tostring(why)
            return false
        end
        refresh()
        local now=os.clock()
        if now-C.lastAt<.39 then
            C.blocked+=1
            C.lastError="Carry action cooldown (.39 sec)"
            return false
        end
        if UIS:GetFocusedTextBox() or player:GetAttribute("FeralMenuOpen")==true
            or C.victim or not player.Character then
            C.blocked+=1
            C.lastError="Carry unavailable while chatting, in menu or captured"
            return false
        end
        C.lastAt=now
        C.lastInputAt=now  -- Suppress speculative victim shake during G transition.
        C.attempts+=1
        local preempted=releaseForCarry()
        local token=currentToken+1
        currentToken=token
        -- Give the game's own Rest=false time before native carry G.
        -- Never duplicate a native G action. Manual G is left untouched.
        local function invoke()
            if not C.alive or currentToken~=token then return end
            if UIS:GetFocusedTextBox() then return end
            local safe,why=mayCarry()
            if not safe then
                C.blocked+=1
                C.status="DEFERRED CARRY CANCELLED / "..tostring(why)
                return
            end
            local fn,can=native()
            -- A native helper may report pickup as ineligible while
            -- *already holding prey*. Let the game-owned helper handle
            -- its drop/release branch rather than forcing key injection.
            if fn and (can or C.holding) then
                local ok,err=pcall(fn)
                if ok then
                    C.helperCalls+=1
                    C.lastError=""
                    C.status="NATIVE CARRY ACTION REQUESTED"
                else
                    C.lastError=tostring(err)
                end
                return
            end
            if not press or not release then
                C.lastError="Game helper not accessible; use native G key"
                C.status="PRESS G IN GAME"
                return
            end
            local ok,err=pcall(press)
            if not ok then
                C.lastError=tostring(err)
                return
            end
            C.keyboardTaps+=1
            task.delay(.045,function()
                pcall(release)
            end)
            C.status="NATIVE G INPUT ATTEMPTED"
        end
        if preempted then task.delay(.17,invoke) else invoke() end
        return true
    end
    function C.report()
        return table.concat({
            "FERAL NOVA PRIME v15 | Native Carry",
            "state="..C.state,
            "holding_prey_or_carcass="..tostring(C.holding),
            "captured_by_enemy="..tostring(C.victim),
            "native_action="..C.action,
            "helper="..C.helper,
            "input_method="..C.method,
            "native_helper_calls="..tostring(C.helperCalls),
            "G_taps="..tostring(C.keyboardTaps),
            "native_g_fallback_available="..tostring(type(press)=="function"),
            "carry_action_confirmed_by_server=UNVERIFIED",
            "button_requests="..tostring(C.attempts),
            "carry_capability_polls="..tostring(C.refreshes),
            "rest_interference_preemptions="..tostring(C.preemptedRest),
            "carry_transitions="..tostring(C.changes),
            "holding_episodes="..tostring(C.holdingEpisodes),
            "captured_episodes="..tostring(C.victimEpisodes),
            "blocked_interactions="..tostring(C.blocked),
            "last_error="..C.lastError,
            "NOTE=Native G/carry helper is game-controlled. Requests are not proof of pickup.",
            "NOTE=v9 Grab V2 timing has priority over hub-initiated G carry.",
            "NOTE=Manual G remains native; coordinator checks only our hub button."
        },"\n")
    end
    function C.close()
        if not C.alive then return end
        C.alive=false
        currentToken+=1
        if C.connection then C.connection:Disconnect()end
        for _,cn in ipairs(connections) do
            pcall(function()cn:Disconnect()end)
        end
    end
    connections[#connections+1]=UIS.InputBegan:Connect(function(input,processed)
        if processed or UIS:GetFocusedTextBox() then return end
        if input.KeyCode==Enum.KeyCode.G then
            C.lastInputAt=os.clock()
            C.nextRefresh=0
            -- Only withdraw an OWNED experimental Rest signal; never
            -- intercept, sink, or fire additional native carry actions.
            releaseForCarry()
        end
    end)
    C.connection=RunService.Heartbeat:Connect(function()
        if not C.alive then return end
        local now=os.clock()
        if now<C.nextRefresh then return end
        C.nextRefresh=now+.13 -- Native FeralCarryCan may perform expensive work.
        local ok,err=pcall(refresh)
        if ok then C.refreshes+=1
        else C.lastError=tostring(err) end
    end)
    return C
end
return Carry
