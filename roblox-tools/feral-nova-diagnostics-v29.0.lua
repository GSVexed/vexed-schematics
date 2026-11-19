-- FERAL NOVA PRIME v29 / unified recovery + outcome diagnostics
-- Privacy: never includes names, IDs, chats, coordinates, player lists or external URLs.
-- Captures own character and controller state. No background network transmission.
-- Auto-saves to the executor workspace when writefile is available.
local Diagnostics={}
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local HttpService=game:GetService("HttpService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local function finite(v)
    return type(v)=="number" and v==v and v<1e9 and v>-1e9
end
local function rounded(v)
    if not finite(v) then return nil end
    return math.floor(v*1000+.5)/1000
end
local function attribute(obj,name)
    if not obj then return nil end
    local ok,value=pcall(function()return obj:GetAttribute(name)end)
    if ok then return value end
end
local function numericAttr(obj,name)
    return rounded(attribute(obj,name))
end
local function yes(value)
    return value==true
end
local function swimmingState(hum)
    if not hum then return false end
    local ok,value=pcall(function()
        return hum:GetState()==Enum.HumanoidStateType.Swimming
    end)
    return ok and value==true
end
local function cleanText(v)
    -- Only record the game's species label, never arbitrary object names.
    if type(v)~="string" then return "unknown" end
    local allow={Bear=true,Eagle=true,Falcon=true,Vulture=true,Wolf=true,Tiger=true,
        Lion=true,Fox=true,Rabbit=true,Deer=true,Elk=true,Boar=true,Rhino=true,
        Elephant=true,Hippo=true,Crocodile=true,SnappingTurtle=true}
    return allow[v] and v or "other"
end
local function bounded(list,entry,limit)
    list[#list+1]=entry
    if #list>limit then table.remove(list,1) end
end
local function safeClock()
    local ok,n=pcall(function()return Workspace:GetServerTimeNow()end)
    return ok and finite(n) and n or nil
end
function Diagnostics.attach(ctx)
    if not player then return nil end
    local D={
        alive=true,enabled=true,autoSave=(type(writefile)=="function"),
        autoSavePeriod=25,saveFile="FERAL_NOVA_v29_session.json",
        status="Starting own-client diagnostics",saveStatus="No file yet",
        samples={},events={},maxSamples=720,maxEvents=180,
        transitions=0,samplesTotal=0,deathCount=0,respawns=0,climbTapStarts=0,
        attackInputs=0,climbInputs=0,carryInputs=0,spaceInputs=0,
        lungeStarts=0,clampStarts=0,escapeStarts=0,
        healthGained=0,healthLost=0,staminaGained=0,staminaLost=0,
        growthGained=0,statusCleared={bleed=0,venom=0,injury=0},
        growthTrials={},staminaModes={},cdTrials={},cooldownTotalJumps=0,
        noDrainMissingSeconds=0,
        modes={},lastSnapshot=nil,lastSaveAt=-math.huge,lastAutoAt=-math.huge,
        lastEvent="",session=0,lastReportBytes=0
    }
    local start=os.clock()
    local currentChar=nil
    local prev=nil
    local connectionList={}
    local lastSample=-math.huge
    local changedState={}
    local function bind(signal,fn)
        local ok,c=pcall(function()return signal:Connect(fn)end)
        if ok and c then connectionList[#connectionList+1]=c end
    end
    local function mark(kind,detail)
        if not D.alive then return end
        bounded(D.events,{t=rounded(os.clock()-start),kind=kind,info=detail},D.maxEvents)
        D.lastEvent=kind
    end
    function D.mark(kind)
        local valid={hub_reset=true,manual_save=true,copy_report=true,
            experimental_toggle=true,recovery_toggle=true}
        if valid[kind] then mark(kind) end
    end
    local function mode()
        local native=ctx.native and ctx.native.active==true or false
        local regen=ctx.regen and ctx.regen.applied==true or false
        if native and regen then return "native_plus_config" end
        if native then return "native_only" end
        if regen then return "config_only" end
        return "neither"
    end
    local function ownSnapshot()
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local clamp=char and char:FindFirstChild("FeralClamp")
        local holding=clamp and clamp:IsA("ObjectValue") and clamp.Value~=nil or false
        local nowServer=safeClock()
        -- Some game builds publish talon deadlines on the character rather than Player.
        -- Track source + raw values. Comparing to GetServerTimeNow is an estimate,
        -- never a substitute for an accepted follow-up catch.
        local playerReady=numericAttr(player,"FeralLungeReadyAt")
        local charReady=numericAttr(char,"FeralLungeReadyAt")
        local ready=playerReady or charReady
        local readySource=playerReady and "player" or charReady and "character" or "absent"
        local cdPlayer=numericAttr(player,"FeralLungeCdTotal")
        local cdChar=numericAttr(char,"FeralLungeCdTotal")
        local cdTotal=cdPlayer or cdChar
        local cooldown=nowServer and ready and rounded(math.max(0,ready-nowServer)) or nil
        local mods=ctx.mechanics
        local p=ctx.power
        local staminaMatches=nil
        if p and type(p.status)=="function" then
            local ok,ps=pcall(p.status)
            if ok and type(ps)=="table" then staminaMatches=ps.staminaMatches end
        end
        return {
            t=rounded(os.clock()-start),session=D.session,
            species=cleanText(attribute(char,"Species") or attribute(player,"Species")),
            hp=hum and rounded(hum.Health) or nil,
            hpMax=hum and rounded(hum.MaxHealth) or nil,
            stamina=numericAttr(char,"Stamina"),
            staminaMax=numericAttr(char,"StaminaMax"),
            staminaOut=yes(attribute(char,"StaminaOut")),
            growth=numericAttr(char,"Growth"),
            bleed=numericAttr(char,"FeralBleed"),
            venom=numericAttr(char,"FeralVenomAmt"),
            injury=numericAttr(char,"FeralInjury"),
            grabbed=yes(attribute(char,"FeralCarried")) or yes(attribute(char,"FeralPinned")) or yes(attribute(char,"FeralDragged")),
            pinned=yes(attribute(char,"FeralPinned")),
            dragged=yes(attribute(char,"FeralDragged")),
            holding=holding,climbCan=yes(attribute(player,"ClimbCan")),
            climbTapAt=numericAttr(player,"FeralClimbTap"),
            resting=yes(attribute(char,"WolfRest")),
            native=ctx.native and ctx.native.active==true or false,
            regen=ctx.regen and ctx.regen.applied==true or false,
            activeRecoveryEnabled=ctx.activeRecovery and ctx.activeRecovery.enabled==true or false,
            recoveryMode=ctx.activeRecovery and ctx.activeRecovery.mode or "OFF",
            recoveryPosePauses=ctx.native and ctx.native.poseSafetyPauses or 0,
            recoveryPoseBlocked=ctx.native and ctx.native.poseBlockedChar==char or false,
            statusInputsReady=ctx.regen and ctx.regen.statusApplied==true or false,
            nativeStatusRestMultReady=ctx.regen and ctx.regen.restMultipliersReady==true or false,
            regenEnabled=ctx.regen and ctx.regen.enabled==true or false,
            endurance=p and p.stamina or "unknown",
            enduranceLeaseMatches=staminaMatches,
            noDrain=yes(attribute(char,"WolfDbgNoStamina")),
            autoEscape=ctx.escape and ctx.escape.enabled==true or false,
            babyCarry=ctx.baby and ctx.baby.enabled==true or false,
            quickClimb=ctx.climb and ctx.climb.enabled==true or false,
            esp=ctx.state and ctx.state.flags and ctx.state.flags.playerFinder==true or false,
            expGrowth=mods and mods.enabled.growth or false,
            expCarry=mods and mods.enabled.carry or false,
            expCooldown=mods and mods.enabled.cooldown or false,
            flying=yes(attribute(char,"FeralFlyLocal")),
            swimming=yes(attribute(char,"FeralSwimLocal"))
                or swimmingState(hum),
            underwater=yes(attribute(char,"FeralUnderwater"))
                or (ctx.flight and ctx.flight.underwater==true) or false,
            waterSurfaceEligible=ctx.flight and ctx.flight.surfaceEligible==true or false,
            relativeWaterDepth=ctx.flight and rounded(ctx.flight.depth) or nil,
            flightRequests=ctx.flight and ctx.flight.surfaceRequests or 0,
            underwaterTakeoffBlocked=ctx.flight and ctx.flight.submergedTakeoffBlocks or 0,
            nativeFlightDropRequests=ctx.flight and ctx.flight.underwaterFlightExits or 0,
            waterFlightOverlapSamples=ctx.flight and ctx.flight.waterFlightOverlapSamples or 0,
            underwaterExitConfirmed=ctx.flight and ctx.flight.underwaterExitConfirmed or 0,
            underwaterExitUnconfirmed=ctx.flight and ctx.flight.underwaterExitUnconfirmed or 0,
            talonReadyAt=ready,talonRemaining=cooldown,talonReadySource=readySource,
            cdTotal=cdTotal,cdTotalSource=cdPlayer and "player" or cdChar and "character" or "absent",
            mode=mode()
        }
    end
    local watch={"grabbed","pinned","dragged","holding","staminaOut",
        "noDrain","native","regenEnabled","expGrowth","expCarry","expCooldown",
        "talonReadyAt","climbTapAt","endurance","quickClimb","babyCarry",
        "flying","swimming","underwater","waterSurfaceEligible",
        "recoveryMode","recoveryPosePauses","recoveryPoseBlocked",
        "statusInputsReady","activeRecoveryEnabled"}
    local function transition(s,previous)
        if not previous then return end
        for _,key in ipairs(watch) do
            local a,b=previous[key],s[key]
            if a~=b then
                D.transitions+=1
                if key=="talonReadyAt" and finite(b) and (not finite(a) or b>a+.4) then D.lungeStarts+=1 end
                if key=="holding" and b==true then D.clampStarts+=1 end
                if key=="climbTapAt" and finite(b) then D.climbTapStarts=(D.climbTapStarts or 0)+1 end
                if key=="grabbed" and b==true then D.escapeStarts+=1 end
                mark(key.."_changed",key=="talonReadyAt" and rounded(b) or tostring(b))
            end
        end
        -- Growth increments can occur several times per second and used to
        -- overwrite the entire event history; retain only 10% milestones.
        if finite(s.growth) and finite(previous.growth)
            and math.floor(s.growth*10)>math.floor(previous.growth*10) then
            mark("growth_milestone",rounded(s.growth))
        end
        if finite(s.cdTotal) and finite(previous.cdTotal)
            and math.abs(s.cdTotal-previous.cdTotal)>=.5 then
            D.cooldownTotalJumps+=1
            mark("talon_cd_total_changed",tostring(previous.cdTotal).." to "..tostring(s.cdTotal))
        end
    end
    local function addDelta(s,previous)
        if not previous then return end
        local dt=s.t-previous.t
        if not finite(dt) or dt<=0 or dt>5 then return end
        local k=s.mode
        local bucket=D.modes[k]
        if not bucket then
            bucket={seconds=0,woundedSeconds=0,
                hpUp=0,hpDown=0,staminaUp=0,staminaDown=0,growthUp=0,
                bleedClear=0,venomClear=0,injuryClear=0,
                bleedActiveSeconds=0,venomActiveSeconds=0,injuryActiveSeconds=0}
            D.modes[k]=bucket
        end
        bucket.seconds+=dt
        if finite(previous.hp) and finite(previous.hpMax)
            and previous.hpMax>0 and previous.hp<previous.hpMax-.01 then
            bucket.woundedSeconds+=dt
        end
        for _,effect in ipairs({"bleed","venom","injury"}) do
            if finite(previous[effect]) and previous[effect]>0 then
                bucket[effect.."ActiveSeconds"]+=dt
            end
        end
        if not s.noDrain and previous.noDrain and
            s.endurance~="OFF" then
            D.noDrainMissingSeconds+=dt
        end
        local function delta(key,up,down)
            if not finite(s[key]) or not finite(previous[key]) then return end
            local diff=s[key]-previous[key]
            if diff>0 then
                bucket[up]+=diff
                return diff,0
            elseif diff<0 and down then
                bucket[down]+=-diff
                return 0,-diff
            end
            return 0,0
        end
        local hpUp,hpDown=delta("hp","hpUp","hpDown")
        local sUp,sDown=delta("stamina","staminaUp","staminaDown")
        D.healthGained+=hpUp or 0
        D.healthLost+=hpDown or 0
        D.staminaGained+=sUp or 0
        D.staminaLost+=sDown or 0
        if s.flying==previous.flying and s.swimming==previous.swimming then
            local travel=s.flying and "flight" or s.swimming and "swimming" or "land_other"
            local flag=s.noDrain and previous.noDrain and "flag_on" or "flag_off"
            local mk=travel.."_"..flag
            local b=D.staminaModes[mk]
            if not b then b={seconds=0,staminaUp=0,staminaDown=0,samples=0};D.staminaModes[mk]=b end
            b.seconds+=dt
            b.samples+=1
            b.staminaUp+=sUp or 0
            b.staminaDown+=sDown or 0
        end
        if finite(s.growth) and finite(previous.growth) then
            local g=math.max(0,s.growth-previous.growth)
            D.growthGained+=g
            bucket.growthUp+=g
            if s.expGrowth==previous.expGrowth and s.species==previous.species then
                local name=s.expGrowth and "growth_trial_on" or "growth_trial_off"
                local b=D.growthTrials[name]
                if not b then b={seconds=0,delta=0,samples=0};D.growthTrials[name]=b end
                b.seconds+=dt;b.delta+=g;b.samples+=1
            end
        end
        if finite(s.cdTotal) and s.expCooldown==previous.expCooldown then
            local k=s.expCooldown and "cooldown_trial_on" or "cooldown_trial_off"
            local b=D.cdTrials[k]
            if not b then b={samples=0,nearOnePointFive=0,nearSixty=0,other=0};D.cdTrials[k]=b end
            b.samples+=1
            if s.cdTotal>=1 and s.cdTotal<=2.5 then b.nearOnePointFive+=1
            elseif s.cdTotal>=50 and s.cdTotal<=70 then b.nearSixty+=1
            else b.other+=1 end
        end
        for _,effect in ipairs({"bleed","venom","injury"}) do
            if finite(s[effect]) and finite(previous[effect]) then
                local loss=math.max(0,previous[effect]-s[effect])
                D.statusCleared[effect]+=loss
                bucket[effect.."Clear"]+=loss
            end
        end
    end
    function D.sample()
        if not D.alive or not D.enabled then return end
        local c=player.Character
        if c~=currentChar then
            currentChar=c
            D.session+=1
            D.respawns+=1
            prev=nil
            mark("character_changed",c and "character_present" or "character_absent")
        end
        local s=ownSnapshot()
        transition(s,prev)
        addDelta(s,prev)
        if prev and finite(prev.hp) and prev.hp>0 and s.hp==0 then
            D.deathCount+=1
            mark("death")
        end
        prev=s
        D.lastSnapshot=s
        D.samplesTotal+=1
        bounded(D.samples,s,D.maxSamples)
        D.status="Sampling "..tostring(D.samplesTotal).." snapshots / "..tostring(#D.events).." events"
    end
    local function totals()
        local summary={
            schema="FERAL_NOVA_DIAG_V29",scope="OWN_CHARACTER_ONLY",
            transfer="LOCAL_FILE_ONLY_NO_NETWORK_UPLOAD",
            duration=rounded(os.clock()-start),sessions=D.session,
            samples=D.samplesTotal,events=#D.events,respawns=D.respawns,
            deaths=D.deathCount,attacks=D.attackInputs,
            climbKeys=D.climbInputs,carryKeys=D.carryInputs,spaceKeys=D.spaceInputs,
            lungeDeadlines=D.lungeStarts,climbTaps=D.climbTapStarts or 0,clampStarts=D.clampStarts,
            captureStarts=D.escapeStarts,
            healthUp=rounded(D.healthGained),healthDown=rounded(D.healthLost),
            staminaUp=rounded(D.staminaGained),staminaDown=rounded(D.staminaLost),
            growthUp=rounded(D.growthGained),
            cooldownTotalJumps=D.cooldownTotalJumps,
            recovery={
                enabled=D.lastSnapshot and D.lastSnapshot.activeRecoveryEnabled or false,
                mode=D.lastSnapshot and D.lastSnapshot.recoveryMode or "OFF",
                poseSafetyPauses=D.lastSnapshot and D.lastSnapshot.recoveryPosePauses or 0,
                poseGuardActive=D.lastSnapshot and D.lastSnapshot.recoveryPoseBlocked or false,
                statusConfigApplied=D.lastSnapshot and D.lastSnapshot.statusInputsReady or false,
                nativeRestMultiplierReady=D.lastSnapshot and D.lastSnapshot.nativeStatusRestMultReady or false
            },
            staminaNoDrainMissingSeconds=rounded(D.noDrainMissingSeconds),
            recoveryComparison={},growthComparison={},staminaByMovement={},cooldownComparison={},
            water={
                surfaceTakeoffs=D.lastSnapshot and D.lastSnapshot.flightRequests or 0,
                blockedSubmergedTakeoffs=D.lastSnapshot and D.lastSnapshot.underwaterTakeoffBlocked or 0,
                nativeFlightDropRequests=D.lastSnapshot and D.lastSnapshot.nativeFlightDropRequests or 0,
                nativeFlightDropConfirmed=D.lastSnapshot and D.lastSnapshot.underwaterExitConfirmed or 0,
                nativeFlightDropNotConfirmed=D.lastSnapshot and D.lastSnapshot.underwaterExitUnconfirmed or 0,
                waterFlightOverlapSamples=D.lastSnapshot and D.lastSnapshot.waterFlightOverlapSamples or 0,
                finalUnderwater=D.lastSnapshot and D.lastSnapshot.underwater or false
            },
            cleared={
                bleed=rounded(D.statusCleared.bleed),
                venom=rounded(D.statusCleared.venom),
                injury=rounded(D.statusCleared.injury)
            },modes={},enabled=D.enabled,autoSave=D.autoSave,
            saveStatus=D.saveStatus
        }
        for k,b in pairs(D.modes) do
            local entry={}
            for name,value in pairs(b) do entry[name]=rounded(value) end
            entry.hpGainPerSecond=b.seconds>0 and rounded(b.hpUp/b.seconds) or nil
            entry.hpGainPerWoundedSecond=b.woundedSeconds>0 and rounded(b.hpUp/b.woundedSeconds) or nil
            entry.statusBleedPerSecond=b.seconds>0 and rounded(b.bleedClear/b.seconds) or nil
            entry.statusBleedPerActiveSecond=b.bleedActiveSeconds>0 and rounded(b.bleedClear/b.bleedActiveSeconds) or nil
            entry.statusVenomPerSecond=b.seconds>0 and rounded(b.venomClear/b.seconds) or nil
            entry.statusVenomPerActiveSecond=b.venomActiveSeconds>0 and rounded(b.venomClear/b.venomActiveSeconds) or nil
            summary.modes[k]=entry
        end
        for name,b in pairs(D.growthTrials) do
            summary.growthComparison[name]={
                seconds=rounded(b.seconds),samples=b.samples,delta=rounded(b.delta),
                observedPerMinute=b.seconds>0 and rounded(b.delta*60/b.seconds) or nil
            }
        end
        for name,b in pairs(D.staminaModes) do
            summary.staminaByMovement[name]={
                seconds=rounded(b.seconds),samples=b.samples,
                gained=rounded(b.staminaUp),lost=rounded(b.staminaDown)
            }
        end
        for name,b in pairs(D.cdTrials) do summary.cooldownComparison[name]=b end
        return summary
    end
    function D.payload()
        return {
            summary=totals(),
            current=D.lastSnapshot,
            recentSamples=D.samples,
            recentEvents=D.events,
            notice="Client observations are not proof of server acceptance. No identifying data is recorded."
        }
    end
    function D.report()
        local a=totals()
        local s=D.lastSnapshot or {}
        local lines={
            "=== FERAL NOVA PRIME v29 AUTOMATIC DIAGNOSTICS ===",
            "privacy=own_character_aggregates_only; upload=NONE",
            "duration_s="..tostring(a.duration).." samples="..a.samples.." events="..a.events,
            "species="..tostring(s.species).." sessions="..a.sessions,
            "HP="..tostring(s.hp).."/"..tostring(s.hpMax)..
                " stamina="..tostring(s.stamina).."/"..tostring(s.staminaMax)..
                " growth="..tostring(s.growth),
            "HP gained="..tostring(a.healthUp).." lost="..tostring(a.healthDown)..
                " stamina gained="..tostring(a.staminaUp).." lost="..tostring(a.staminaDown),
            "bleed cleared="..tostring(a.cleared.bleed)..
                " venom cleared="..tostring(a.cleared.venom)..
                " injury cleared="..tostring(a.cleared.injury),
            "attacks="..a.attacks.." climb_keys="..a.climbKeys..
                " carry_keys="..a.carryKeys.." captures="..a.captureStarts..
                " outgoing_clamps="..a.clampStarts,
            "water_surface_takeoffs="..tostring(a.water.surfaceTakeoffs)..
                " underwater_takeoff_blocks="..tostring(a.water.blockedSubmergedTakeoffs)..
                " underwater_flight_drop_requests="..tostring(a.water.nativeFlightDropRequests)..
                " water_flight_overlap_samples="..tostring(a.water.waterFlightOverlapSamples),
            "swimming="..tostring(s.swimming).." underwater="..tostring(s.underwater)..
                " surface_eligible="..tostring(s.waterSurfaceEligible)..
                " flying="..tostring(s.flying)..
                " relative_depth="..tostring(s.relativeWaterDepth),
            "lunge_deadlines="..a.lungeDeadlines..
                " talon_remaining_s="..tostring(s.talonRemaining)..
                " cd_total="..tostring(s.cdTotal)..
                " cd_source="..tostring(s.cdTotalSource)..
                " cooldown_total_jumps="..tostring(a.cooldownTotalJumps),
            "active_recovery_enabled="..tostring(s.activeRecoveryEnabled)..
                " recovery_mode="..tostring(s.recoveryMode)..
                " pose_guard_pauses="..tostring(a.recovery.poseSafetyPauses)..
                " status_inputs_applied="..tostring(a.recovery.statusConfigApplied),
            "endurance="..tostring(s.endurance).." no_drain="..tostring(s.noDrain)..
                " cached_stamina_applied="..tostring(s.enduranceLeaseMatches)..
                " native_recovery="..tostring(s.native).." regen="..tostring(s.regen),
            "experimental_growth="..tostring(s.expGrowth)..
                " carry="..tostring(s.expCarry).." cooldown="..tostring(s.expCooldown),
            "ESP="..tostring(s.esp).." quick_climb="..tostring(s.quickClimb)..
                " friendly_baby_carry="..tostring(s.babyCarry),
            "auto_save="..tostring(D.autoSave).." status="..D.saveStatus,
            "water_exit_confirmed="..tostring(a.water.nativeFlightDropConfirmed)..
                " water_exit_unconfirmed="..tostring(a.water.nativeFlightDropNotConfirmed),
            "SERVER_ACCEPTANCE=UNVERIFIED"
        }
        for _,name in ipairs({"neither","config_only","native_only","native_plus_config"}) do
            local b=a.modes[name]
            if b then
                lines[#lines+1]="MODE "..name..
                    " seconds="..tostring(b.seconds)..
                    " hp_gain_per_sec="..tostring(b.hpGainPerSecond)..
                    " hp_gain_per_wounded_sec="..tostring(b.hpGainPerWoundedSecond)..
                    " bleed_clear_per_sec="..tostring(b.statusBleedPerSecond)..
                    " venom_clear_per_sec="..tostring(b.statusVenomPerSecond)
            end
        end
        for name,b in pairs(a.growthComparison) do
            lines[#lines+1]="GROWTH "..name.." seconds="..tostring(b.seconds)..
                " progress_per_min="..tostring(b.observedPerMinute)
        end
        for name,b in pairs(a.cooldownComparison) do
            lines[#lines+1]="TALON "..name.." samples="..b.samples..
                " near_1.5s="..b.nearOnePointFive.." near_60s="..b.nearSixty
        end
        for name,b in pairs(a.staminaByMovement) do
            lines[#lines+1]="STAMINA "..name.." seconds="..tostring(b.seconds)..
                " gained="..tostring(b.gained).." lost="..tostring(b.lost)
        end
        lines[#lines+1]="RECENT EVENTS (UP TO 30)"
        for i=math.max(1,#D.events-29),#D.events do
            local e=D.events[i]
            lines[#lines+1]=tostring(e.t).."s "..tostring(e.kind)..
                (e.info~=nil and " "..tostring(e.info) or "")
        end
        return table.concat(lines,"\n")
    end
    function D.save()
        if type(writefile)~="function" then
            D.saveStatus="Executor writefile unavailable; use COPY DIAG"
            return false,D.saveStatus
        end
        local ok,encoded=pcall(function()return HttpService:JSONEncode(D.payload())end)
        if not ok then
            D.saveStatus="JSON encode failed"
            return false,D.saveStatus
        end
        local saved,err=pcall(function()writefile(D.saveFile,encoded)end)
        if saved then
            D.lastSaveAt=os.clock()
            D.lastReportBytes=#encoded
            D.saveStatus="Saved "..D.saveFile.." ("..#encoded.." bytes)"
            return true,D.saveStatus
        end
        D.saveStatus="File write failed; use COPY DIAG"
        return false,tostring(err)
    end
    function D.copy()
        local copy=(type(setclipboard)=="function" and setclipboard)
            or (type(toclipboard)=="function" and toclipboard)
        if not copy then return false,"Clipboard unsupported" end
        local ok=pcall(function()copy(D.report())end)
        if ok then return true,"Diagnostic summary copied" end
        return false,"Clipboard operation failed"
    end
    function D.setAutoSave(v)
        D.autoSave=v==true and type(writefile)=="function"
        if D.autoSave then D.save() end
        return D.autoSave
    end
    function D.shortStatus()
        local s=D.lastSnapshot or {}
        return "DIAG: "..D.samplesTotal.." samples  HP "..tostring(s.hp or "--")..
            "  ST "..tostring(s.stamina or "--")..
            "  CD "..tostring(s.talonRemaining or "--")..
            "  "..(D.autoSave and "AUTO FILE ON" or "COPY-ONLY")
    end
    bind(UIS.InputBegan,function(input,processed)
        if not D.alive or not D.enabled or processed or UIS:GetFocusedTextBox() then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            D.attackInputs+=1
        elseif input.KeyCode==Enum.KeyCode.Q then
            D.climbInputs+=1
        elseif input.KeyCode==Enum.KeyCode.G then
            D.carryInputs+=1
        elseif input.KeyCode==Enum.KeyCode.Space then
            D.spaceInputs+=1
        end
    end)
    local lastAutosave=0
    bind(RunService.Heartbeat,function()
        if not D.alive then return end
        local now=os.clock()
        if D.enabled and now-lastSample>=.5 then
            lastSample=now
            local ok,err=pcall(D.sample)
            if not ok then
                D.status="Sample error, skipped"
                if now-D.lastAutoAt>10 then
                    mark("sample_error")
                    D.lastAutoAt=now
                end
            end
        end
        if D.autoSave and now-lastAutosave>=D.autoSavePeriod then
            lastAutosave=now
            D.save()
        end
    end)
    function D.close()
        if not D.alive then return end
        if D.autoSave then pcall(D.save) end
        D.alive=false
        for _,cn in ipairs(connectionList) do pcall(function()cn:Disconnect()end) end
        for i=#connectionList,1,-1 do connectionList[i]=nil end
    end
    ctx.diag=D
    return D
end
return Diagnostics