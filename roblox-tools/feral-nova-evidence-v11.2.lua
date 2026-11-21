-- FERAL NOVA v11.2 / activity-isolated, read-only game-outcome evidence
-- Only reads own animal/game state; never sends any remote, alters attributes
-- or claims server-authoritative changes. Clean samples are observational.
local Evidence={}
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local STATES={"moving","stationary"}
local EFFECTS={
    {"injury","FeralInjury"},{"bleed","FeralBleed"},
    {"venom","FeralVenomAmt"},
}
local function finite(v)
    return type(v)=="number" and v==v and v>-1e9 and v<1e9
end
local function read(obj,key)
    if not obj then return nil end
    local ok,v=pcall(function()return obj:GetAttribute(key)end)
    return ok and v or nil
end
local function bucket()
    return {seconds=0,samples=0,positiveHP=0,damage=0,
        healingTicks=0,damageTicks=0,
        status={},statusSeconds={},statusTicks={}}
end
local function safeRate(num,den)
    if not finite(num) or not finite(den) or den<.35 then return nil end
    return num/den
end
local function fmt(n)
    return finite(n) and string.format("%.3f",n) or "INSUFFICIENT DATA"
end
function Evidence.attach(ctx)
    local E={
        alive=true,version="11.2",enabled=true,
        status="WAITING FOR A LIVING ANIMAL",
        moving=bucket(),stationary=bucket(),
        combatSeconds=0,unsafeSeconds=0,transitionSamples=0,
        maxHpChanged=0,characterChanges=0,invalidSamples=0,
        totalObservations=0,last=nil,lastChar=nil,lastClock=0,
        lastTick=-math.huge,interval=.25,history={},
        samplesMax=180,sessionStart=os.clock(),latest=nil,
        lastSurvival=nil,survivalIncrease=0,survivalIncreaseTicks=0,
        survivalResetCount=0,staminaDelta=0,staminaUp=0,staminaDown=0,
        needs={hunger={lost=0,gained=0},thirst={lost=0,gained=0}},
        serverOutcome="NOT CONFIRMED",lastReport="NO EVIDENCE",
        errorCount=0,lastError="",
    }
    local function observe()
        local char=player and player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if char~=E.lastChar then
            E.lastChar=char
            E.last=nil
            E.characterChanges+=1
        end
        if not char or not hum or hum.Health<=0 or not root then
            E.last=nil
            E.status="WAITING FOR LIVING ANIMAL"
            return
        end
        local now=os.clock()
        local velocity=root.AssemblyLinearVelocity
        local horizontal=typeof(velocity)=="Vector3"
            and Vector3.new(velocity.X,0,velocity.Z).Magnitude or 0
        local direction=hum.MoveDirection
        local moving=horizontal>=2 or (
            typeof(direction)=="Vector3" and direction.Magnitude>.13)
        local stateOK,state=pcall(function()return hum:GetState()end)
        local locomotion=stateOK and state and state.Name or "UNKNOWN"
        local snap=ctx.action and type(ctx.action.snapshot)=="function"
            and ctx.action.snapshot() or nil
        local combat=snap and (snap.combat==true or snap.attackHeld==true
            or snap.combatTimeUnknown==true) or false
        local unsafe=not snap or not snap.alive or
            snap.grab or snap.victim or snap.afkMoving or snap.feeding or
            locomotion=="Dead" or locomotion=="FallingDown"
        local effects={}
        for _,entry in ipairs(EFFECTS) do
            local value=read(char,entry[2])
            effects[entry[1]]=finite(value) and math.max(0,value) or nil
        end
        local new={
            now=now,char=char,health=hum.Health,max=hum.MaxHealth,
            moving=moving,combat=combat,unsafe=unsafe,
            rest=ctx.native and ctx.native.active==true or false,
            effects=effects,
            stamina=read(char,"Stamina"),
            hunger=read(char,"Hunger"),
            thirst=read(char,"Thirst"),
            survival=read(player,"FeralSurvival"),
        }
        E.latest={
            health=new.health,maxHealth=new.max,moving=moving,
            locomotion=locomotion,combat=combat,
            restSignal=new.rest,priority=snap and snap.priority or "NO STATE",
            survival=finite(new.survival) and new.survival or nil,
            injury=effects.injury,bleed=effects.bleed,venom=effects.venom,
            stamina=new.stamina,hunger=new.hunger,thirst=new.thirst,
        }
        E.totalObservations+=1
        local old=E.last
        if old then
            local dt=new.now-old.now
            if dt<.12 or dt>1.5 then
                E.invalidSamples+=1
            else
                local stable=new.max==old.max and finite(new.health)
                    and finite(old.health) and new.health>=0
                    and new.health<=new.max+.1
                if not stable then E.maxHpChanged+=1 end
                local clean=stable and not new.combat and not old.combat
                    and not new.unsafe and not old.unsafe
                    and new.moving==old.moving
                    and new.rest==old.rest
                if new.combat or old.combat then E.combatSeconds+=dt end
                if new.unsafe or old.unsafe then E.unsafeSeconds+=dt end
                if new.moving~=old.moving or new.rest~=old.rest then
                    E.transitionSamples+=1
                end
                if clean then
                    local B=new.moving and E.moving or E.stationary
                    B.seconds+=dt
                    B.samples+=1
                    local difference=new.health-old.health
                    if difference>.01 then
                        B.positiveHP+=difference
                        B.healingTicks+=1
                    elseif difference<-.01 then
                        B.damage+=-difference
                        B.damageTicks+=1
                    end
                    for _,entry in ipairs(EFFECTS) do
                        local name=entry[1]
                        local v1=new.effects[name]
                        local v0=old.effects[name]
                        if finite(v0) and v0>.01
                            and (finite(v1) or v1==nil) then
                            local after=finite(v1) and v1 or 0
                            if after<=v0 then
                                B.statusSeconds[name]=(B.statusSeconds[name] or 0)+dt
                                local clearance=v0-after
                                if clearance>.001 then
                                    B.status[name]=(B.status[name] or 0)+clearance
                                    B.statusTicks[name]=(B.statusTicks[name] or 0)+1
                                end
                            end
                        end
                    end
                end
                if finite(new.stamina) and finite(old.stamina) then
                    local diff=new.stamina-old.stamina
                    E.staminaDelta+=diff
                    if diff>0 then E.staminaUp+=diff
                    else E.staminaDown-=diff end
                end
                for _,k in ipairs({"hunger","thirst"}) do
                    local v1,v0=new[k],old[k]
                    if finite(v1) and finite(v0) then
                        local diff=v1-v0
                        if diff>=0 then E.needs[k].gained+=diff
                        else E.needs[k].lost-=diff end
                    end
                end
                if finite(new.survival) and finite(old.survival) then
                    local diff=new.survival-old.survival
                    if diff>0 and diff<=dt*5+2 then
                        E.survivalIncrease+=diff
                        E.survivalIncreaseTicks+=1
                    elseif diff<-.5 then E.survivalResetCount+=1 end
                end
            end
        end
        E.last=new
        if moving then E.status="MOVING / OBSERVING OWN HP"
        else E.status="STATIONARY / OBSERVING OWN HP" end
        if combat then E.status="COMBAT / HEALING SAMPLES EXCLUDED" end
    end
    local connection=RunService.Heartbeat:Connect(function()
        if not E.alive or not E.enabled then return end
        local now=os.clock()
        if now-E.lastTick<E.interval then return end
        E.lastTick=now
        local ok,err=pcall(observe)
        if not ok then
            E.errorCount+=1
            E.lastError=tostring(err):sub(1,160)
            E.last=nil
            E.status="EVIDENCE SAMPLE ERROR"
        end
    end)
    function E.summary()
        local movingHeal=safeRate(E.moving.positiveHP,E.moving.seconds)
        local stillHeal=safeRate(E.stationary.positiveHP,E.stationary.seconds)
        local enoughMoving=E.moving.samples>=12 and E.moving.seconds>=4
        local enoughStill=E.stationary.samples>=12 and E.stationary.seconds>=4
        local compare=enoughMoving and enoughStill and stillHeal
            and stillHeal>.01 and movingHeal and movingHeal/stillHeal or nil
        local localMinigame=ctx.grabMini
        local eagle=ctx.eagleActions
        return {
            version=E.version,
            movingHealingRate=enoughMoving and movingHeal or nil,
            stationaryHealingRate=enoughStill and stillHeal or nil,
            movingToStillRatio=compare,
            movingSeconds=E.moving.seconds,
            stationarySeconds=E.stationary.seconds,
            injuryMovingRate=safeRate(E.moving.status.injury,
                E.moving.statusSeconds.injury),
            injuryStillRate=safeRate(E.stationary.status.injury,
                E.stationary.statusSeconds.injury),
            bleedMovingRate=safeRate(E.moving.status.bleed,
                E.moving.statusSeconds.bleed),
            venomMovingRate=safeRate(E.moving.status.venom,
                E.moving.statusSeconds.venom),
            survivalIncrease=E.survivalIncrease,
            survivalSamples=E.survivalIncreaseTicks,
            staminaConsumed=E.staminaDown,
            staminaReplenished=E.staminaUp,
            hungerLost=E.needs.hunger.lost,
            thirstLost=E.needs.thirst.lost,
            minigameStrikes=localMinigame and localMinigame.strikesSeen or 0,
            minigamePresses=localMinigame and localMinigame.pressesSent or 0,
            confirmedServerPerfects=localMinigame and
                localMinigame.serverPerfectReplies or 0,
            nativeEagleClampObservations=eagle and
                eagle.actualClampObservations or 0,
            location="OWN_ANIMAL_ONLY",
            evidenceScope="OBSERVED_REPLICATED_OR_LOCAL_VALUES_NOT_CAUSAL_PROOF",
            readyForComparison=compare~=nil,
        }
    end
    function E.report()
        local S=E.summary()
        local lines={
            "FERAL NOVA v10 | Independent Gameplay Evidence",
            "status="..E.status,
            "observations="..E.totalObservations,
            "character_resets="..E.characterChanges,
            "max_HP_exclusions="..E.maxHpChanged,
            "transition_exclusions="..E.transitionSamples,
            "moving_clean_seconds="..fmt(E.moving.seconds),
            "stationary_clean_seconds="..fmt(E.stationary.seconds),
            "moving_HP_per_s="..fmt(S.movingHealingRate),
            "stationary_HP_per_s="..fmt(S.stationaryHealingRate),
            "moving_to_still_ratio="..fmt(S.movingToStillRatio),
            "injury_clearance_moving_per_s="..fmt(S.injuryMovingRate),
            "injury_clearance_still_per_s="..fmt(S.injuryStillRate),
            "bleed_clearance_moving_per_s="..fmt(S.bleedMovingRate),
            "venom_clearance_moving_per_s="..fmt(S.venomMovingRate),
            "observed_survival_gain="..fmt(S.survivalIncrease),
            "survival_credit_increments="..S.survivalSamples,
            "observed_stamina_consumed="..fmt(S.staminaConsumed),
            "observed_stamina_replenished="..fmt(S.staminaReplenished),
            "observed_hunger_lost="..fmt(S.hungerLost),
            "observed_thirst_lost="..fmt(S.thirstLost),
            "grab_native_strikes_seen="..S.minigameStrikes,
            "grab_native_presses_sent="..S.minigamePresses,
            "grab_server_perfect_replies="..S.confirmedServerPerfects,
            "eagle_native_clamp_observations="..S.nativeEagleClampObservations,
            "validation="..S.evidenceScope,
            "sample_error_count="..E.errorCount,
            "last_error="..E.lastError,
            "NOTE=Only own animal values are sampled. No remote sends, no writes.",
            "NOTE=Local Humanoid Health and replicated attributes can be updated without identifying exact cause.",
            "NOTE=Comparisons require comparable states, multiple samples, unchanged MaxHP, no combat or interruption.",
            "NOTE=Rest signal visibility, local mechanics and timing do not prove server acceptance.",
        }
        return table.concat(lines,"\n")
    end
    function E.close()
        if not E.alive then return end
        E.alive=false
        E.enabled=false
        E.last=nil
        if connection then pcall(function()connection:Disconnect()end)end
    end
    return E
end
return Evidence
