-- FERAL NOVA PRIME v29 / pose-safe native active recovery (single coordinator)
-- Client-masked REST is an experiment, not a guaranteed server heal.
-- This controller owns only its native Rest(true/false) request and the
-- local WolfRest pose mask while not fighting, carrying, flying or climbing.
local Native={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local EFFECTS={"FeralInjury","FeralBleed","FeralVenomAmt"}
local function finite(n)
    return type(n)=="number" and n==n and n>=0 and n<1e9
end
local function blockedByActivity(char,ctx)
    if not char or not char.Parent then return "NO ANIMAL" end
    if char:GetAttribute("FeralPinned")==true
        or char:GetAttribute("FeralCarried")==true
        or char:GetAttribute("FeralDragged")==true then
        return "ESCAPE HAS PRIORITY"
    end
    if char:GetAttribute("FeralClimbLocal")==true
        or (ctx.climb and ctx.climb.queued) then
        return "CLIMB HAS PRIORITY"
    end
    if char:GetAttribute("FeralFlyLocal")==true
        or char:GetAttribute("FeralFlyDrain")==true
        or char:GetAttribute("FeralDiving")==true then
        return "FLIGHT / DIVE HAS PRIORITY"
    end
    if char:GetAttribute("WolfFeed")==true then
        return "FEED HAS PRIORITY"
    end
    if ctx.carry and ctx.carry.classify then
        local _,holding,victim=ctx.carry.classify(char)
        if holding or victim then return "CARRY HAS PRIORITY" end
    end
    local species=char:GetAttribute("Species")
    if type(species)=="string"
        and string.find(species,"SnappingTurtle",1,true) then
        return "TURTLE SHELL PROTECTED / NO MASK"
    end
    return nil
end
Native.blockedByActivity=blockedByActivity
function Native.attach(ctx)
    local N={
        enabled=false,alive=true,active=false,
        status="OFF",reason="OFF",lastError="",
        owned=nil,mask=nil,nextTick=0,pausedUntil=0,
        nextRequest=0,nextRefresh=0,
        nativeOn=0,nativeOff=0,maskWrites=0,maskEchoes=0,
        maskErrors=0,pauses=0,activations=0,
        forcedOffBeforeActions=0,combatPauses=0,
        lastHP=nil,lastStatus=nil,lastHPMax=nil,lastAt=0,
        observedHPGain=0,eligibleHPSeconds=0,HPGainTicks=0,
        effectClears={FeralInjury=0,FeralBleed=0,FeralVenomAmt=0},
        effectSeconds={FeralInjury=0,FeralBleed=0,FeralVenomAmt=0},
        lastBlock=nil,inputAt=-math.huge,
        poseRecurrences=0,poseSafetyPauses=0,poseBlockedChar=nil,
        poseSafetyFailures=0,nativeRefreshRequestsSuppressed=0
    }
    local conns={}
    local masking=false
    local function fire(on,char)
        local remote=RS:FindFirstChild("WolfActions")
        if not remote or not remote:IsA("RemoteEvent") then
            N.lastError="WolfActions missing";return false
        end
        if player.Character~=char then return false end
        local ok,err=pcall(function()remote:FireServer("Rest",on)end)
        if not ok then N.lastError=tostring(err);return false end
        if on then N.nativeOn+=1 else N.nativeOff+=1 end
        return true
    end
    local function unmask()
        local m=N.mask
        N.mask=nil
        if not m then return end
        if m.conn then pcall(function()m.conn:Disconnect()end)end
        -- Never "repair" WolfRest by writing true: that would itself
        -- activate a local Rest pose even when the server is not resting.
    end
    local function cancel(reason,preempt)
        unmask()
        local char=N.owned
        N.owned=nil;N.active=false
        if char then
            if preempt then N.forcedOffBeforeActions+=1 end
            if char.Parent and player.Character==char then
                fire(false,char)
            end
        end
        if reason then N.reason=reason;N.status=reason end
    end
    local function writeMask(m)
        if not N.enabled or not N.alive or N.mask~=m
            or player.Character~=m.char or masking then return end
        if m.char:GetAttribute("WolfRest")==true then
            local now=os.clock()
            if now-(m.echoWindowAt or 0)>2 then
                m.echoWindowAt=now
                m.trueEchoes=0
            end
            m.trueEchoes+=1
            N.poseRecurrences+=1
            -- A single WolfRest=true echo when the native action starts is
            -- expected. Repeated true echoes mean the game keeps forcing the
            -- visible resting pose: release Rest instead of fighting animation.
            if m.trueEchoes>=3 then
                N.poseSafetyPauses+=1
                N.pausedUntil=math.max(N.pausedUntil,now+10)
                N.poseSafetyFailures+=1
                if N.poseSafetyFailures>=2 then
                    N.poseBlockedChar=m.char
                end
                cancel("POSE SAFETY / REST SIGNAL RELEASED",true)
                return
            end
            masking=true
            local ok=pcall(function()
                m.char:SetAttribute("WolfRest",false)
            end)
            masking=false
            if ok then N.maskWrites+=1
            else
                N.maskErrors+=1
                N.pausedUntil=math.max(N.pausedUntil,now+10)
                cancel("POSE MASK ERROR / SIGNAL RELEASED",true)
            end
        end
    end
    local function beginMask(char)
        local m={char=char,echoWindowAt=os.clock(),trueEchoes=0}
        N.mask=m
        local ok,conn=pcall(function()
            return char:GetAttributeChangedSignal("WolfRest"):Connect(function()
                N.maskEchoes+=1
                writeMask(m)
            end)
        end)
        if not ok then
            N.mask=nil
            N.maskErrors+=1
            return false
        end
        m.conn=conn
        writeMask(m)
        return true
    end
    local function delayInput(reason,cooldown)
        N.inputAt=os.clock()
        N.pausedUntil=math.max(N.pausedUntil,N.inputAt+(cooldown or .9))
        if N.active then
            N.pauses+=1
            cancel(reason,true)
        end
    end
    function N.beforeCarry()
        local was=N.active
        delayInput("NATIVE CARRY / REST RELEASED",1.2)
        return was
    end
    function N.beforeClimb()
        local was=N.active
        delayInput("QUICK CLIMB / REST RELEASED",1.3)
        return was
    end
    function N.beforeFlight()
        local was=N.active
        delayInput("FLIGHT TAKEOFF / REST RELEASED",1.4)
        return was
    end
    function N.setEnabled(v)
        N.enabled=v==true
        if not N.enabled then
            N.poseBlockedChar=nil
            N.poseSafetyFailures=0
        end
        if not N.enabled then
            cancel("OFF / OWNED REST RELEASED")
        else
            if ctx.recovery and ctx.recovery.enabled then
                ctx.recovery.setEnabled(false)
            end
            if ctx.mobile and ctx.mobile.enabled then
                ctx.mobile.setEnabled(false)
            end
            N.status="ARMED / RECOVER WHILE NOT IN COMBAT"
            N.nextTick=0
        end
        return N.enabled
    end
    conns[#conns+1]=UIS.InputBegan:Connect(function(input,processed)
        if processed or UIS:GetFocusedTextBox() then return end
        local key=input.KeyCode
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.MouseButton2 then
            N.combatPauses+=1
            delayInput("ATTACK PRIORITY / REST RELEASED",1.2)
        elseif key==Enum.KeyCode.G then
            N.beforeCarry()
        elseif key==Enum.KeyCode.Q then
            N.beforeClimb()
        elseif key==Enum.KeyCode.Space then
            N.beforeFlight()
        end
    end)
    local function sample(char,hum,now)
        local state={hp=hum.Health,max=hum.MaxHealth,effects={}}
        for _,key in ipairs(EFFECTS) do
            state.effects[key]=char:GetAttribute(key)
        end
        local old=N.lastStatus
        if N.owned==char and old and N.lastAt>0
            and now-N.lastAt>.10 and now-N.lastAt<1.5 then
            local delta=state.hp-old.hp
            if finite(old.hp) and finite(old.max) and
                state.max==old.max and old.hp<old.max-.20 and delta>=-.01 then
                N.eligibleHPSeconds+=now-N.lastAt
                if delta>.01 then
                    N.observedHPGain+=delta
                    N.HPGainTicks+=1
                end
            end
            for _,key in ipairs(EFFECTS) do
                local a,b=old.effects[key],state.effects[key]
                if finite(a) and finite(b) and a>.2 and b<=a then
                    N.effectSeconds[key]+=now-N.lastAt
                    N.effectClears[key]+=a-b
                end
            end
        end
        N.lastStatus=state;N.lastAt=now
    end
    local function tick()
        if not N.alive or not ctx.state.alive then return end
        local now=os.clock()
        if now<N.nextTick then return end
        N.nextTick=now+.2
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not N.enabled or not char or not char.Parent or not hum
            or hum.Health<=0 or player:GetAttribute("FeralMenuOpen")==true then
            if N.active then cancel("ANIMAL UNAVAILABLE") end
            N.lastStatus=nil
            return
        end
        if N.poseBlockedChar and N.poseBlockedChar~=char then
            N.poseBlockedChar=nil
            N.poseSafetyFailures=0
        end
        if N.poseBlockedChar==char then
            N.status="POSE SAFETY / CONFIG-ONLY RECOVERY UNTIL RESPAWN"
            if N.active then cancel(N.status,true)end
            return
        end
        local blocked=blockedByActivity(char,ctx)
        N.lastBlock=blocked
        if blocked or now<N.pausedUntil then
            if N.active then cancel(blocked or "INPUT COOLDOWN",true)end
            N.status=blocked or "ATTACK / CARRY COOLDOWN"
            N.lastStatus=nil
            return
        end
        if UIS:GetFocusedTextBox() then
            if N.active then cancel("CHAT PRIORITY",true)end
            return
        end
        -- InputBegan fires only once when Mouse1 is held. Never restart
        -- Rest during a held attack merely because 1.2 s has elapsed.
        local heldOK,heldAttack=pcall(function()
            return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        end)
        if heldOK and heldAttack then
            if N.active then cancel("HELD ATTACK / NO REST",true)end
            N.status="HELD ATTACK / RECOVERY PAUSED"
            N.lastStatus=nil
            return
        end
        local hpDeficit=hum.Health<hum.MaxHealth-.35
        local statusDeficit=false
        for _,key in ipairs(EFFECTS) do
            local value=char:GetAttribute(key)
            if finite(value) and value>.2 then statusDeficit=true end
        end
        if not hpDeficit and not statusDeficit then
            if N.active then cancel("FULL HP / NO STATUS")end
            N.status="FULL HP / NO STATUS TO CLEAR"
            return
        end
        if N.owned and N.owned~=char then
            cancel("ANIMAL CHANGED")
        end
        if not N.active then
            if not fire(true,char) then
                N.status="NATIVE REST REQUEST FAILED"
                return
            end
            N.owned=char;N.active=true
            N.activations+=1
            if not beginMask(char) then
                cancel("POSE MASK UNAVAILABLE",true)
                return
            end
            N.nextRefresh=now+5.0
            N.lastStatus=nil
        end
        -- No periodic Rest(true) refresh: v15 resent this every five seconds
        -- and that could repeatedly trigger visible sitting/rest animations.
        -- Retain the single initial native request until the action is released.
        if now>=N.nextRefresh and N.owned==char then
            N.nativeRefreshRequestsSuppressed+=1
            N.nextRefresh=now+5
        end
        if N.mask then writeMask(N.mask)end
        N.status="NATIVE REST SIGNAL / LOCAL POSE MASK • SERVER UNVERIFIED"
        sample(char,hum,now)
    end
    function N.report()
        local rate=N.eligibleHPSeconds>.1
            and N.observedHPGain/N.eligibleHPSeconds or nil
        local t={
            "FERAL NOVA PRIME v15 | Rest-Signal Recovery",
            "enabled="..tostring(N.enabled)..
                " active_native_signal="..tostring(N.active),
            "status="..N.status,
            "native_rest_true_requests="..N.nativeOn,
            "native_rest_false_requests="..N.nativeOff,
            "local_WolfRest_false_mask_writes="..N.maskWrites,
            "rest_attr_echoes="..N.maskEchoes,
            "observed_health_gain_per_second_while_masked="..
                tostring(rate),
            "valid_hp_observation_seconds="..string.format("%.2f",N.eligibleHPSeconds),
            "positive_healing_samples="..N.HPGainTicks,
            "activations="..N.activations,
            "activity_pauses="..N.pauses,
            "attack_priority_pauses="..N.combatPauses,
            "pose_mask_errors="..N.maskErrors,
            "pose_rest_true_recurrences="..N.poseRecurrences,
            "pose_safety_pauses="..N.poseSafetyPauses,
            "pose_native_signals_avoided="..N.nativeRefreshRequestsSuppressed,
            "pose_guard_config_only_until_respawn="..tostring(N.poseBlockedChar==player.Character),
            "last_activity_block="..tostring(N.lastBlock),
            "last_error="..N.lastError,
            "NOTE=Native Rest is a single guarded request with no 5-second refresh.",
            "NOTE=Repeated visible-pose signals pause native Rest; config-only healing remains.",
            "NOTE=Local WolfRest masking can affect game animations and interactions.",
            "NOTE=Rest traffic or local attributes do not prove server-side healing."
        }
        for _,key in ipairs(EFFECTS) do
            local sec=N.effectSeconds[key]
            t[#t+1]=key.."_observed_decay_per_sec="..
                tostring(sec>.1 and N.effectClears[key]/sec or nil)
        end
        return table.concat(t,"\n")
    end
    function N.close()
        if not N.alive then return end
        N.alive=false
        N.setEnabled(false)
        for _,c in ipairs(conns) do
            pcall(function()c:Disconnect()end)
        end
        if N.conn then N.conn:Disconnect()end
    end
    N.conn=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            N.lastError=tostring(err)
            cancel("NATIVE RECOVERY ERROR",true)
        end
    end)
    return N
end
return Native
