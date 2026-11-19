-- FERAL AURORA FORCE v14 - land vs bird stamina paths and real rate observations
-- Concrete own-client power profiles based on recovered controller fields.
-- All experimental features OFF by default. Server authority is NOT bypassed.
local Power={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function number(v)
    return type(v)=="number" and v==v and v>-math.huge and v<math.huge
end
local function loaded(name)
    local world=RS:FindFirstChild("FeralWorld")
    local mod=world and world:FindFirstChild(name)
    if not mod or not mod:IsA("ModuleScript") then
        return nil,"Module "..name.." not available"
    end
    local ok,result=pcall(require,mod)
    if not ok or type(result)~="table" then
        return nil,"Client module "..name.." not readable"
    end
    return result,nil
end
local function revert(lease)
    local reverted=0;local failed=0
    if not lease then return 0,0 end
    for i=#lease.entries,1,-1 do
        local entry=lease.entries[i]
        local ok=pcall(function()
            if lease.target[entry.key]==entry.wanted then
                lease.target[entry.key]=entry.previous
                reverted=reverted+1
            end
        end)
        if not ok then failed=failed+1 end
    end
    return reverted,failed
end
local function apply(tableValue,changes)
    if type(tableValue)~="table" then return nil,"No usable client config" end
    local lease={target=tableValue,entries={}}
    for key,wanted in pairs(changes) do
        if not number(wanted) then return nil,"Invalid number for "..key end
        local ok,previous=pcall(function()return tableValue[key]end)
        if not ok or not number(previous) then
            revert(lease);return nil,"Missing numeric field "..key
        end
        if previous~=wanted then
            local success=pcall(function()
                tableValue[key]=wanted
                assert(tableValue[key]==wanted)
            end)
            if not success then
                revert(lease);return nil,"Client config rejected "..key
            end
            lease.entries[#lease.entries+1]={
                key=key,previous=previous,wanted=wanted
            }
        end
    end
    return lease
end
function Power.attach(ctx)
    local S=ctx.state
    local P={
        alive=true,stamina="OFF",speed=1,leap=1,
        staminaLease=nil,speedLease=nil,
        leapConfig=nil,leapSpecies=nil,
        noDrain=false,turbo=false,
        lastAction="No power changes enabled.",lastError=nil,
        charFlags={},lastFlagChar=nil,heartbeat=nil,
        turboSupported=false,turboSignal="Executor keypress/keyrelease unavailable.",
        turboHeld=false,turboLast=0,
        lastRecheck=0,createdAt=os.clock(),
        lastChar=nil,appliedProfiles=0,restored=0,
        lastStaminaRate=nil,rateSamples=0,
        fallbackInfo="No status data sampled yet.",
        animalMode="WAITING",species="--",
        flightTickSeconds=0,landTickSeconds=0,
        flightStaminaGains=0,landStaminaGains=0,
        flightStaminaLoss=0,landStaminaLoss=0,
        burstSeconds=0,burstDamageEvents=0,
        suddenHpEvents=0,outEvents=0,
        observationSeconds=0,modeChanges=0,
        lastObs=nil,nextObs=0,
        lastObservedBurst=false,priorHp=nil,
        flightBaseDrain=nil,flightEasyDrain=nil,
        latestStamina=0,latestMax=0,
        birdEvidence="NO LIVE BIRD TRACE YET"
    }
    ctx.power=P
    local environment=nil
    if type(getgenv)=="function" then
        local ok,result=pcall(getgenv)
        if ok and type(result)=="table" then environment=result end
    end
    local press=type(keypress)=="function" and keypress
        or environment and type(environment.keypress)=="function"
        and environment.keypress or nil
    local release=type(keyrelease)=="function" and keyrelease
        or environment and type(environment.keyrelease)=="function"
        and environment.keyrelease or nil
    if press and release then
        P.turboSupported=true
        P.turboSignal="Executor key events available; native game handling still unverified."
    else
        -- Some executor environments permit VirtualInputManager instead.
        -- Its protected SendKeyEvent method may still be rejected at runtime.
        local ok,vim=pcall(function()
            return game:GetService("VirtualInputManager")
        end)
        if ok and vim then
            press=function()
                vim:SendKeyEvent(true,Enum.KeyCode.Space,false,game)
            end
            release=function()
                vim:SendKeyEvent(false,Enum.KeyCode.Space,false,game)
            end
            P.turboSupported=true
            P.turboSignal="VirtualInputManager fallback armed; input permissions unverified."
        end
    end
    local function log(info)
        P.lastAction=tostring(info)
        ctx.notice(info)
    end
    local function ownCharacter()
        local char=player.Character
        if not char or not char.Parent then return nil end
        return char
    end
    local function revertFlag(char)
        local old=P.charFlags[char]
        P.charFlags[char]=nil
        if not old or not char then return end
        pcall(function()
            if old.changed and char:GetAttribute("WolfDbgNoStamina")==true then
                char:SetAttribute("WolfDbgNoStamina",old.value)
            end
        end)
    end
    local function flagCharacter(char)
        if not char or not char.Parent or P.charFlags[char] then return end
        local value=char:GetAttribute("WolfDbgNoStamina")
        local ok=pcall(function()
            if value~=true then char:SetAttribute("WolfDbgNoStamina",true)end
        end)
        if ok then
            P.charFlags[char]={value=value,changed=value~=true}
        else
            P.lastError="Own-character debug stamina flag could not be set."
        end
    end
    local function maintainFlag()
        local on=P.noDrain or P.stamina=="APEX"
        local char=ownCharacter()
        for c in pairs(P.charFlags) do
            if not on or c~=char then revertFlag(c)end
        end
        if on and char then flagCharacter(char)end
        P.lastFlagChar=char
    end
    function P.disableStamina(silent)
        revert(P.staminaLease);P.staminaLease=nil
        P.stamina="OFF";maintainFlag()
        if not silent then log("Stamina profile OFF • cached settings restored where still owned.")end
    end
    local function staminaPlan(mode,c)
        if not number(c.STAMINA_REGEN) or c.STAMINA_REGEN<=0
            or not number(c.STAMINA_REST_MULT)
            or not number(c.STAMINA_REGEN_DELAY)
            or not number(c.STAMINA_LOW_NEEDS) then
            return nil,"Client stamina config is missing expected values."
        end
        if mode=="RECOVER" then
            return {
                STAMINA_REGEN=c.STAMINA_REGEN*3,
                STAMINA_REST_MULT=1,
                STAMINA_REGEN_DELAY=0,
                STAMINA_LOW_NEEDS=1,
                STAMINA_SPRINT_DRAIN=0,
                STAMINA_JUMP_COST=0
            }
        elseif mode=="APEX" then
            if not number(c.STAMINA_SPRINT_DRAIN)
                or not number(c.STAMINA_JUMP_COST) then
                return nil,"Apex sprint/jump controller fields not found."
            end
            return {
                STAMINA_SPRINT_DRAIN=0,STAMINA_JUMP_COST=0,
                STAMINA_REGEN=250,STAMINA_REGEN_DELAY=0,
                STAMINA_LOW_NEEDS=1
            }
        end
        return nil,"Unknown power profile"
    end
    function P.setStamina(mode)
        if mode~="RECOVER" and mode~="APEX" and mode~="OFF" then return end
        if mode==P.stamina then return end
        P.disableStamina(true)
        if mode=="OFF" then log("Stamina config restored.");return end
        -- The standalone low-needs switch patches the SAME cached field.
        -- Release its lease first so both controls can be switched off cleanly.
        if S.flags.lowNeedsAssist then
            ctx.toggle("lowNeedsAssist",false)
        end
        local config,err=loaded("NeedsConfig")
        if not config then
            P.lastError=err;log("Unavailable: "..err);return
        end
        local plan,reason=staminaPlan(mode,config)
        if not plan then
            P.lastError=reason;log("Unavailable: "..reason);return
        end
        local lease,why=apply(config,plan)
        if not lease then
            P.lastError=why;log("Not applied: "..why);return
        end
        P.staminaLease=lease;P.stamina=mode;P.appliedProfiles+=1
        maintainFlag()
        if mode=="RECOVER" then
            log("ENDURANCE: 3x client regen + sprint/jump cost zeroed + debug flag; flight and land acceptance unverified.")
        else
            log("APEX CLIENT MODE applied: high-risk local stamina tuning. Prior prolonged Burst deaths remain unexplained.")
        end
    end
    function P.toggleNoDrain()
        P.noDrain=not P.noDrain
        maintainFlag()
        local state=P.noDrain and
            "Standalone client no-stamina-cost flag ON (not a server guarantee)." or
            P.stamina=="APEX" and
            "Standalone flag OFF; Apex profile still owns WolfDbgNoStamina." or
            "Standalone client no-drain flag OFF; original attribute restored."
        log(state)
    end
    function P.setSpeed(multiplier)
        if multiplier~=1 and multiplier~=1.15
            and multiplier~=1.30 and multiplier~=1.50 then return end
        if multiplier==P.speed then return end
        revert(P.speedLease);P.speedLease=nil;P.speed=1
        if multiplier==1 then log("Speed profile restored.");return end
        local c,why=loaded("NeedsConfig")
        if not c then log("Speed unavailable: "..why);return end
        if not number(c.RUN_SPEED) or not number(c.SWIM_SPEED)
            or c.RUN_SPEED<=0 or c.RUN_SPEED>4
            or c.SWIM_SPEED<=0 or c.SWIM_SPEED>4 then
            log("Speed profile unavailable: expected cached inputs not present.")
            return
        end
        local lease,err=apply(c,{
            RUN_SPEED=c.RUN_SPEED*multiplier,SWIM_SPEED=c.SWIM_SPEED*multiplier
        })
        if not lease then log("Speed not applied: "..err);return end
        P.speedLease=lease;P.speed=multiplier;P.appliedProfiles+=1
        log(string.format("%.2f× land/swim inputs applied locally; server checks remain independent.",multiplier))
    end
    function P.setLeap(multiplier)
        if multiplier~=1 and multiplier~=1.15 and multiplier~=1.35 then return end
        if multiplier==P.leap then return end
        revert(P.leapSpecies);revert(P.leapConfig)
        P.leapSpecies=nil;P.leapConfig=nil;P.leap=1
        if multiplier==1 then log("Leap profile restored.");return end
        local c,why=loaded("JumpLeapConfig")
        if not c or c.ON~=true or type(c.BODY_LENGTHS)~="table"
            or not number(c.DEFAULT) or not number(c.MAX_RUN_SHARE) then
            log("Leap unavailable: original cached module not usable.");return
        end
        local species={}
        for name,value in pairs(c.BODY_LENGTHS) do
            if type(name)=="string" and number(value) and value>=0 and value<=10 then
                species[name]=value*multiplier
            end
        end
        if not next(species) then log("Leap source has no usable species entries.");return end
        local one,firstErr=apply(c,{
            DEFAULT=c.DEFAULT*multiplier,
            MAX_RUN_SHARE=c.MAX_RUN_SHARE*multiplier
        })
        if not one then log("Leap unavailable: "..firstErr);return end
        local two,secondErr=apply(c.BODY_LENGTHS,species)
        if not two then
            revert(one);log("Leap species table unavailable: "..secondErr);return
        end
        P.leapConfig=one;P.leapSpecies=two;P.leap=multiplier
        P.appliedProfiles+=1
        log(string.format("%.2f× leap inputs locally applied (not flight or a server grant).",multiplier))
    end
    local function releaseSpace()
        if P.turboHeld and release then pcall(release,0x20)end
        P.turboHeld=false
    end
    function P.toggleTurbo()
        if not P.turboSupported then
            log("Rapid Escape unavailable: this executor does not expose keypress/keyrelease.")
            return
        end
        P.turbo=not P.turbo
        if not P.turbo then releaseSpace()end
        log(P.turbo and "Rapid Escape ARMED: hold ALT to pulse Space, chat input excluded."
            or "Rapid Escape OFF: key events stopped.")
    end
    local function turboTick(now)
        if not P.turbo or not P.turboSupported then return end
        if UIS:GetFocusedTextBox() then
            releaseSpace();return
        end
        if not (UIS:IsKeyDown(Enum.KeyCode.LeftAlt)
            or UIS:IsKeyDown(Enum.KeyCode.RightAlt)) then
            releaseSpace();return
        end
        if now-P.turboLast<.17 then return end
        P.turboLast=now
        if not P.turboHeld then
            local ok=pcall(press,0x20)
            if ok then
                P.turboHeld=true
                task.delay(.06,function()
                    if not P.alive then releaseSpace();return end
                    releaseSpace()
                end)
            else
                P.turbo=false;P.lastError="Executor keypress failed"
                log("Rapid Escape stopped: key input was rejected by executor.")
            end
        end
    end
    function P.reset()
        P.disableStamina(true)
        P.noDrain=false;maintainFlag()
        P.setSpeed(1);P.setLeap(1)
        P.turbo=false;releaseSpace()
        P.lastAction="All power profiles OFF; original client inputs restored where still owned."
        ctx.notice(P.lastAction)
    end
    function P.status()
        local a=ctx.stats()
        local valid=function(lease)
            if not lease then return false end
            local ok,match=pcall(function()
                for _,entry in ipairs(lease.entries) do
                    if lease.target[entry.key]~=entry.wanted then return false end
                end
                return true
            end)
            return ok and match
        end
        local char=ownCharacter()
        local flag=char and char:GetAttribute("WolfDbgNoStamina")==true or false
        local danger=P.stamina=="APEX" and "AGGRESSIVE / HIGH RISK" or
            P.stamina=="RECOVER" and "RECOVERY / EXPERIMENTAL" or "STOCK"
        return {
            stamina=P.stamina,
            staminaMatches=valid(P.staminaLease),
            speed=P.speed,speedMatches=valid(P.speedLease),
            leap=P.leap,leapMatches=valid(P.leapConfig) and valid(P.leapSpecies),
            noDrain=P.noDrain,turbo=P.turbo,turboSupported=P.turboSupported,
            flag=flag,mode=danger,phase=a.sessionPhase,
            hp=a.hp,staminaValue=a.stamina,maxStamina=a.maxStamina,
            healthMax=a.maxHp,hunger=a.hunger,thirst=a.thirst,
            last=P.lastAction,error=P.lastError,
            appliedProfiles=P.appliedProfiles
        }
    end
    local function watchStamina(now)
        if now<P.nextObs then return end
        P.nextObs=now+.28
        local char=ownCharacter()
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health<=0 then
            P.lastObs=nil
            P.animalMode="WAITING"
            return
        end
        local species=tostring(char:GetAttribute("Species") or "UNKNOWN")
        local flight=char:GetAttribute("FeralFlyLocal")==true
            or char:GetAttribute("FeralFlyDrain")==true
        local mode=flight and "FLIGHT" or "LAND / SWIM / OTHER"
        local stamina=char:GetAttribute("Stamina")
        local maximum=char:GetAttribute("StaminaMax")
        local burst=char:GetAttribute("FeralFlyBurst")==true
            or player:GetAttribute("HudBurst")==true
        local nowHp=hum.Health
        local out=char:GetAttribute("StaminaOut")==true
        if mode~=P.animalMode then P.modeChanges+=1 end
        P.animalMode=mode
        P.species=species
        if number(stamina) then P.latestStamina=stamina end
        if number(maximum) then P.latestMax=maximum end
        local last=P.lastObs
        if last and last.char==char and last.mode==mode then
            local dt=now-last.time
            if dt>.05 and dt<1.3 then
                local isFlight=mode=="FLIGHT"
                if isFlight then P.flightTickSeconds+=dt
                else P.landTickSeconds+=dt end
                if number(stamina) and number(last.stamina) then
                    local d=stamina-last.stamina
                    if d>.02 then
                        if isFlight then P.flightStaminaGains+=d
                        else P.landStaminaGains+=d end
                    elseif d<-.02 then
                        if isFlight then P.flightStaminaLoss-=d
                        else P.landStaminaLoss-=d end
                    end
                end
                if burst then P.burstSeconds+=dt end
                if number(nowHp) and number(last.hp) then
                    local loss=last.hp-nowHp
                    if loss>math.max(10,(hum.MaxHealth or 100)*.10) then
                        P.suddenHpEvents+=1
                        if burst then P.burstDamageEvents+=1 end
                    end
                end
                if out and not last.out then P.outEvents+=1 end
                P.observationSeconds+=dt
            end
        end
        P.lastObs={char=char,mode=mode,time=now,
            stamina=stamina,hp=nowHp,out=out}
        if flight and P.flightTickSeconds>=3 then
            P.birdEvidence="FLIGHT CONTROLLER ACTIVE; OBSERVE SERVER EFFECTS"
        end
    end
    function P.enduranceReport()
        return table.concat({
            "FERAL NOVA PRIME v14 | Land and Flight Endurance",
            "species="..P.species.." movement_path="..P.animalMode,
            "endurance_mode="..P.stamina,
            "client_debug_no_drain="..tostring(
                ownCharacter() and ownCharacter():GetAttribute("WolfDbgNoStamina")==true),
            "flight_trace_seconds="..string.format("%.2f",P.flightTickSeconds),
            "land_trace_seconds="..string.format("%.2f",P.landTickSeconds),
            "flight_stamina_gained="..string.format("%.2f",P.flightStaminaGains),
            "flight_stamina_lost="..string.format("%.2f",P.flightStaminaLoss),
            "land_stamina_gained="..string.format("%.2f",P.landStaminaGains),
            "land_stamina_lost="..string.format("%.2f",P.landStaminaLoss),
            "burst_seconds="..string.format("%.2f",P.burstSeconds),
            "burst_hp_loss_events="..P.burstDamageEvents,
            "large_hp_loss_events="..P.suddenHpEvents,
            "stamina_out_transitions="..P.outEvents,
            "current_stamina="..string.format("%.1f",P.latestStamina),
            "current_stamina_max="..string.format("%.1f",P.latestMax),
            "mode_changes="..P.modeChanges,
            "bird_evidence="..P.birdEvidence,
            "NOTE=Flight and land share stamina resources, but different drain paths.",
            "NOTE=Observed bird survival does not prove bypass of server validation."
        },"\n")
    end
    P.connection=RunService.Heartbeat:Connect(function()
        if not P.alive or not S.alive then return end
        local now=os.clock()
        turboTick(now)
        watchStamina(now)
        if now-P.lastRecheck>=.75 then
            P.lastRecheck=now
            local char=ownCharacter()
            if char~=P.lastChar then
                P.lastChar=char
                maintainFlag()
            end
        end
    end)
    local priorReset=ctx.reset
    function ctx.reset()
        P.reset()
        priorReset()
    end
    local priorClose=ctx.close
    function ctx.close()
        if P.alive then
            P.reset()
            P.alive=false
            if P.connection then P.connection:Disconnect()end
            releaseSpace()
        end
        priorClose()
    end
    return P
end
return Power
