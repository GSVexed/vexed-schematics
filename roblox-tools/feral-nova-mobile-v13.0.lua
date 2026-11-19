-- FERAL NOVA PRIME v13 / Native carry-safe mobile Rest A/B experiment.
-- No "always-on regen" claim: only a server can award the built-in Rest
-- multipliers. Tests *one* native Rest(true) window while MOVING, followed
-- by Rest(false). Stops if it enters actual Rest (which blocks bites).
-- Can sustain only after a measured moving uplift, and remains opt-in.
local Mobile={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function finite(v)
    return type(v)=="number" and v==v and v>=0 and v<1e9
end
local keyNames={"FeralInjury","FeralBleed","FeralVenomAmt"}
local function sample(char,hum)
    local sample={hp=hum.Health,max=hum.MaxHealth}
    for _,k in ipairs(keyNames) do
        local v=char:GetAttribute(k)
        sample[k]=finite(v) and v or nil
    end
    return sample
end
local function newWindow()
    return {time=0,hp=0,hpEvents=0,negative=0,
        status={FeralInjury=0,FeralBleed=0,FeralVenomAmt=0},
        statusTime={FeralInjury=0,FeralBleed=0,FeralVenomAmt=0}}
end
local function rate(sum,den)
    if den<=.01 then return nil end
    return sum/den
end
function Mobile.decide(base,signal,after)
    local hpBase=rate(base.hp,base.time)
    local hpSignal=rate(signal.hp,signal.time)
    local hpAfter=after and rate(after.hp,after.time) or nil
    local hasHp=hpBase and hpSignal
        and base.time>=2.4 and signal.time>=4
        and hpBase>.025 and hpSignal>hpBase*1.55
        and (not after or after.time<2 or not hpAfter
            or hpSignal>hpAfter*1.28)
    local effects={}
    local hasStatus=false
    for _,key in ipairs(keyNames) do
        local b=rate(base.status[key],base.statusTime[key])
        local s=rate(signal.status[key],signal.statusTime[key])
        local a=after and rate(after.status[key],after.statusTime[key]) or nil
        if b and s and base.statusTime[key]>=1.5
            and signal.statusTime[key]>=2.5
            and b>.025 and s>b*2.5
            and (not after or after.statusTime[key]<1.6 or not a
                or s>a*1.5) then
            hasStatus=true
            effects[#effects+1]=key
        end
    end
    return hasHp==true or hasStatus,hasHp==true,hasStatus,
        hpBase,hpSignal,table.concat(effects,","),hpAfter
end
function Mobile.attach(ctx)
    local M={
        alive=true,enabled=false,phase="OFF",status="OFF",
        outcome="NOT TESTED",reason="",
        starts=0,requestsOn=0,requestsOff=0,
        injuryEvents=0,attackStops=0,
        restConflicts=0,movementStops=0,deathStops=0,
        baseline=newWindow(),signal=newWindow(),
        after=newWindow(),samples=0,lastError="",
        lastInput=-math.huge,lastAttack=-math.huge,
        nextTick=0,phaseStart=0,nextSignal=0,ownSignal=false,
        lastSample=nil,lastSampleAt=0,lastCharacter=nil,
        measuredHp=false,measuredStatus=false,
        observedUplift=false,upliftStatusTypes="",
        sustainable=false,baselineStarted=false,
        carryPauses=0,carryResumes=0,carryInteractions=0,
        carryGraceUntil=0,unknownCarryStates=0
    }
    local conns={}
    local function fire(on)
        local remote=RS:FindFirstChild("WolfActions")
        if not remote or not remote:IsA("RemoteEvent") then
            M.lastError="WolfActions remote unavailable"
            return false
        end
        local ok,err=pcall(function()
            remote:FireServer("Rest",on)
        end)
        if not ok then
            M.lastError=tostring(err)
            return false
        end
        if on then M.requestsOn+=1;M.ownSignal=true
        else M.requestsOff+=1;M.ownSignal=false end
        return true
    end
    local function cancel()
        if M.ownSignal then
            M.ownSignal=false
            if player.Character==M.lastCharacter
                and M.lastCharacter and M.lastCharacter.Parent then
                fire(false)
            end
        end
    end
    local function finish(message,outcome)
        cancel()
        M.phase="OFF"
        M.enabled=false
        M.status=message
        M.outcome=outcome or M.outcome
        M.lastSample=nil
        M.lastSampleAt=0
    end
    local function clearSamples()
        M.baseline=newWindow()
        M.signal=newWindow()
        M.after=newWindow()
        M.phaseStart=os.clock()
        M.lastSample=nil
        M.lastSampleAt=0
        M.observedUplift=false
        M.measuredHp=false
        M.measuredStatus=false
        M.upliftStatusTypes=""
        M.sustainable=false
        M.baselineStarted=false
    end
    local function pauseCarry()
        if not M.enabled then
            if M.ownSignal then cancel() end
            return false
        end
        local hadSignal=M.ownSignal
        cancel()
        M.carryGraceUntil=math.max(M.carryGraceUntil,os.clock()+.85)
        if M.phase~="CARRY_PAUSED" then
            M.carryPauses+=1
            M.phase="CARRY_PAUSED"
            M.status="CARRY PRIORITY / RECOVERY PAUSED"
            M.lastSample=nil
            M.lastSampleAt=0
            M.outcome="PAUSED / NO RECOVERY CLAIM"
        end
        return hadSignal
    end
    function M.beforeCarry()
        M.carryInteractions+=1
        return pauseCarry()
    end
    local function input(action)
        M.lastInput=os.clock()
        if action then M.lastAttack=M.lastInput end
        -- Important: never keep an owned server Rest request active on
        -- attack; this has been shown to block WolfController bites.
        if action and M.ownSignal then
            M.attackStops+=1
            finish("STOPPED: ATTACK HAS PRIORITY","INTERRUPTED")
        end
    end
    conns[#conns+1]=UIS.InputBegan:Connect(function(a,processed)
        if processed or UIS:GetFocusedTextBox() then return end
        local key=a.KeyCode
        if a.UserInputType==Enum.UserInputType.MouseButton1
            or a.UserInputType==Enum.UserInputType.MouseButton2 then
            input(true)
        elseif key==Enum.KeyCode.G then
            -- G is the game's pickup/carry/drop control, not an
            -- attack. Preserve it and pause only our Rest experiment.
            M.lastInput=os.clock()
            M.beforeCarry()
        elseif key==Enum.KeyCode.W or key==Enum.KeyCode.A
            or key==Enum.KeyCode.S or key==Enum.KeyCode.D
            or key==Enum.KeyCode.Space then
            M.lastInput=os.clock()
        elseif key~=Enum.KeyCode.Unknown then
            -- Other gameplay key actions may initiate abilities. An
            -- unrecognised action must not coexist with a Rest signal.
            input(true)
        end
    end)
    function M.setEnabled(v)
        if not v then
            finish("OFF","STOPPED")
            return false
        end
        if M.enabled then return true end
        if ctx.recovery and ctx.recovery.enabled then
            ctx.recovery.setEnabled(false)
        end
        M.enabled=true
        M.starts+=1
        M.phase="BASELINE"
        M.status="MOVING BASELINE: 4 SECONDS"
        M.outcome="MEASURING"
        M.lastCharacter=player.Character
        clearSamples()
        return true
    end
    local function accumulate(window,old,current,elapsed)
        if elapsed<=0 or elapsed>1.2 then return end
        if finite(old.hp) and finite(current.hp)
            and old.max==current.max
            and old.hp<old.max-.5 and current.hp>=old.hp-.001 then
            window.time+=elapsed
            local delta=current.hp-old.hp
            if delta>.001 then
                window.hp+=delta
                window.hpEvents+=1
            end
        end
        for _,key in ipairs(keyNames) do
            local x,y=old[key],current[key]
            if finite(x) and finite(y) and x>.25 and y<=x+.001 then
                window.statusTime[key]+=elapsed
                window.status[key]+=math.max(0,x-y)
            end
        end
    end
    local function tick()
        if not M.alive or not ctx.state.alive then return end
        local now=os.clock()
        if now<M.nextTick then return end
        M.nextTick=now+.19
        if not M.enabled then return end
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if not char or not char.Parent or not hum or not root
            or hum.Health<=0 or player:GetAttribute("FeralMenuOpen")==true then
            M.deathStops+=1
            finish("STOPPED: ANIMAL UNAVAILABLE","INTERRUPTED")
            return
        end
        if char~=M.lastCharacter then
            M.deathStops+=1
            finish("STOPPED: ANIMAL CHANGED","INTERRUPTED")
            return
        end
        -- Classify carry BEFORE movement checks. Carried prey often slows
        -- the predator below the mobile-trial speed requirement; this must
        -- PAUSE the trial, not permanently disable it.
        local state,holding,victim=nil,false,false
        if ctx.carry and ctx.carry.classify then
            state,holding,victim=ctx.carry.classify(char)
        else
            victim=char:GetAttribute("FeralPinned")==true
                or char:GetAttribute("FeralCarried")==true
                or char:GetAttribute("FeralDragged")==true
            holding=char:GetAttribute("FeralCarcassCarry")==true
        end
        if victim then
            finish("STOPPED: CAPTURED BY ENEMY / ESCAPE PRIORITY","INTERRUPTED")
            return
        end
        if holding then
            pauseCarry()
            M.status="CARRYING PREY OR CARCASS; RECOVERY PAUSED"
            return
        end
        if M.phase=="CARRY_PAUSED" then
            if now<M.carryGraceUntil then
                M.status="CARRY ACTION SETTLING / TRIAL PAUSED"
                return
            end
            M.carryResumes+=1
            M.phase="BASELINE"
            M.status="CARRY FINISHED / RESUMING BASELINE"
            M.outcome="MEASURING"
            clearSamples()
            return
        end
        -- The moving requirement applies ONLY to active measurements,
        -- never while carrying or waiting for a G interaction.
        if root.AssemblyLinearVelocity.Magnitude<1.6 then
            if M.phase=="BASELINE" and not M.baselineStarted then
                M.status="START MOVING TO BEGIN"
                return
            end
            M.movementStops+=1
            finish("STOPPED: MOVEMENT INTERRUPTED","INCONCLUSIVE")
            return
        end
        if M.phase=="BASELINE" and not M.baselineStarted then
            M.baselineStarted=true
            M.phaseStart=now
            M.lastSample=nil
            M.lastSampleAt=0
        end
        if char:GetAttribute("WolfRest")==true then
            M.restConflicts+=1
            finish("STOPPED: REST BLOCKS BITES","UNSAFE")
            return
        end
        if now-M.lastAttack<2.0 then
            finish("STOPPED: RECENT ATTACK","INTERRUPTED")
            return
        end
        local nowSample=sample(char,hum)
        local hasDeficit=nowSample.hp<nowSample.max-.5
        for _,key in ipairs(keyNames) do
            if finite(nowSample[key]) and nowSample[key]>.5 then
                hasDeficit=true
            end
        end
        if not hasDeficit and M.phase=="BASELINE" then
            M.status="NEED HP DEFICIT OR BLEED / VENOM / INJURY"
            M.phaseStart=now
            M.lastSample=nil
            M.lastSampleAt=0
            return
        end
        local window=M.phase=="BASELINE" and M.baseline
            or M.phase=="SIGNAL" and M.signal or M.after
        if M.lastSample and M.lastSampleAt>0 and M.lastSamplePhase==M.phase then
            accumulate(window,M.lastSample,nowSample,now-M.lastSampleAt)
            M.samples+=1
        end
        M.lastSample=nowSample
        M.lastSampleAt=now
        M.lastSamplePhase=M.phase
        local since=now-M.phaseStart
        if M.phase=="BASELINE" then
            M.status="BASELINE: KEEP MOVING"
            if since>=4 then
                if window.time<1 and not (
                    window.statusTime.FeralInjury>=.9
                    or window.statusTime.FeralBleed>=.9
                    or window.statusTime.FeralVenomAmt>=.9) then
                    finish("NO MEASURABLE BASELINE","INCONCLUSIVE")
                    return
                end
                if not fire(true) then
                    finish("NO NATIVE REST REMOTE","UNAVAILABLE")
                    return
                end
                M.phase="SIGNAL"
                M.phaseStart=now
                M.lastSample=nil
                M.status="MOBILE REST SIGNAL SENT / WATCHING"
            end
        elseif M.phase=="SIGNAL" then
            M.status="MOBILE SIGNAL: MEASURING"
            if since>=7 then
                cancel()
                M.phase="AFTER"
                M.phaseStart=now
                M.lastSample=nil
                M.status="COMPARING AFTER SIGNAL"
            end
        elseif M.phase=="AFTER" then
            M.status="AFTER SIGNAL: KEEP MOVING"
            if since>=3.5 then
                local uplift,hp,status,b,s,keys=Mobile.decide(M.baseline,M.signal,M.after)
                M.measuredHp=hp
                M.measuredStatus=status
                M.upliftStatusTypes=keys
                M.observedUplift=uplift
                -- Even a measured rate change could be confounded; the
                -- server's actual reason is not exposed to the client.
                if uplift then
                    M.sustainable=true
                    M.enabled=true
                    M.phase="SUSTAIN"
                    M.phaseStart=now
                    M.lastSample=nil
                    M.nextSignal=now
                    M.status="UPLIFT OBSERVED; MOBILE SIGNAL TRIAL"
                    M.outcome="OBSERVED UPLIFT / UNVERIFIED CAUSE"
                else
                    finish("NO VERIFIED MOBILE UPLIFT","NOT SUPPORTED BY MEASUREMENT")
                end
            end
        elseif M.phase=="SUSTAIN" then
            if now>=M.nextSignal then
                if not fire(true) then
                    finish("SUSTAIN SIGNAL UNAVAILABLE","STOPPED")
                    return
                end
                M.nextSignal=now+5
            end
            M.status="MOBILE SIGNAL • OBSERVED UPLIFT"
        end
    end
    function M.report()
        local b,s=M.baseline,M.signal
        local base=rate(b.hp,b.time)
        local signal=rate(s.hp,s.time)
        local parts={
            "FERAL NOVA PRIME v13 | Mobile Recovery Trial",
            "enabled="..tostring(M.enabled).." phase="..M.phase,
            "status="..M.status.." outcome="..M.outcome,
            "native_rest_on="..tostring(M.requestsOn)..
                " native_rest_off="..tostring(M.requestsOff),
            "moving_normal_hp_rate="..tostring(base),
            "moving_signal_hp_rate="..tostring(signal),
            "moving_after_hp_rate="..tostring(rate(M.after.hp,M.after.time)),
            "normal_valid_hp_seconds="..string.format("%.2f",b.time),
            "signal_valid_hp_seconds="..string.format("%.2f",s.time),
            "observed_hp_uplift="..tostring(M.measuredHp),
            "observed_status_uplift="..tostring(M.measuredStatus),
            "status_uplift_types="..M.upliftStatusTypes,
            "rest_conflict_stops="..tostring(M.restConflicts),
            "carry_pause_count="..tostring(M.carryPauses),
            "carry_resume_count="..tostring(M.carryResumes),
            "carry_key_interactions="..tostring(M.carryInteractions),
            "carry_pause_before_movement_check=true",
            "attack_priority_stops="..tostring(M.attackStops),
            "movement_stops="..tostring(M.movementStops),
            "death_or_respawn_stops="..tostring(M.deathStops),
            "last_error="..M.lastError,
            "NOTE=Remote calls are not proof of server Rest. Rate changes may be confounded.",
            "NOTE=This automatically stops without observed mobile benefit."
        }
        for _,key in ipairs(keyNames) do
            parts[#parts+1]=key.."_normal_rate="..tostring(
                rate(b.status[key],b.statusTime[key]))
            parts[#parts+1]=key.."_signal_rate="..tostring(
                rate(s.status[key],s.statusTime[key]))
        end
        return table.concat(parts,"\n")
    end
    function M.close()
        finish("CLOSED","STOPPED")
        M.alive=false
        if M.connection then M.connection:Disconnect()end
        for _,cn in ipairs(conns) do pcall(function()cn:Disconnect()end)end
    end
    M.connection=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            M.lastError=tostring(err)
            finish("TRIAL ERROR","ERROR")
        end
    end)
    return M
end
return Mobile
