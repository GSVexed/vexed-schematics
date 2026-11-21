-- FERAL NOVA CORE v9.0 / two independent AFK systems under central action policy.
-- Platform idle heartbeat: virtual input, best-effort, not guaranteed.
-- Survival activity: optional conservative WALK, never spoof FeralSurvival.
local AFK={}
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local function readFeralConfig(name)
    local folder=RS:FindFirstChild("FeralWorld")
    local module=folder and folder:FindFirstChild(name)
    if not module or not module:IsA("ModuleScript") then return nil end
    local ok,config=pcall(require,module)
    return ok and type(config)=="table" and config or nil
end
local function finite(v)
    return type(v)=="number" and v==v and math.abs(v)<1e9
end
local function horizontal(v)
    return Vector3.new(v.X,0,v.Z)
end
function AFK.attach(ctx)
    local now=os.clock()
    local A={
        alive=true,robloxEnabled=false,survivalEnabled=false,
        robloxStatus="OFF",survivalStatus="OFF",
        pulseAttempts=0,pulseSuccess=0,pulseErrors=0,idledEvents=0,
        survivalMoves=0,survivalArrivals=0,unsafeStops=0,moveFailures=0,
        survivalProgress=0,progressObserved=0,lastSurvival=nil,
        lastPhysicalInputAt=now,lastPulseAt=now,lastStepAt=now,
        recentPhysicalTravel=now,ignoreInputUntil=0,
        travelActive=false,travelDeadline=0,travelGoal=nil,
        travelChar=nil,travelHum=nil,anchor=nil,anchorChar=nil,
        nextTick=0,desiredTravelPeriod=70,desiredPulsePeriod=85,
        lastError="",lastBlock="NONE",userStopCount=0,
        idleTimeoutSeconds=1200,gameHopWarningSeconds=1080,
        survivalAfkSeconds=120,survivalAfkMoveStuds=4,
        safeStepStuds=6.5,serverValueIncreasesUnverified=true,
    }
    -- Feral's own replicated config is preferred to archived defaults.
    -- We NEVER edit these config objects or local Survival attributes.
    local liveSurvival=readFeralConfig("SurvivalConfig")
    if liveSurvival then
        if finite(liveSurvival.AFK_AFTER)
            and liveSurvival.AFK_AFTER>=30 and liveSurvival.AFK_AFTER<=600 then
            A.survivalAfkSeconds=liveSurvival.AFK_AFTER
        end
        if finite(liveSurvival.AFK_MOVE)
            and liveSurvival.AFK_MOVE>=1 and liveSurvival.AFK_MOVE<=20 then
            A.survivalAfkMoveStuds=liveSurvival.AFK_MOVE
        end
    end
    A.safeStepStuds=math.max(6.5,A.survivalAfkMoveStuds+2)
    A.desiredTravelPeriod=math.min(70,A.survivalAfkSeconds*.6)
    local liveAfk=readFeralConfig("AfkConfig")
    if liveAfk and finite(liveAfk.HOP_AT) and liveAfk.HOP_AT>=150 then
        A.gameHopWarningSeconds=liveAfk.HOP_AT
        A.desiredPulsePeriod=math.min(85,liveAfk.HOP_AT*.25)
    end
    local conns={}
    local virtualUser=nil
    pcall(function()virtualUser=game:GetService("VirtualUser")end)
    local virtualInput=nil
    pcall(function()virtualInput=game:GetService("VirtualInputManager")end)
    local function setBaseline()
        local t=os.clock()
        A.lastPhysicalInputAt=t
        A.lastStepAt=t
        A.anchor=nil
        A.anchorChar=nil
        A.recentPhysicalTravel=t
    end
    local function stopTravel(reason)
        if ctx.action and type(ctx.action.release)=="function" then
            ctx.action.release("afk_walk")
        end
        if not A.travelActive then return end
        local hum=A.travelHum
        local char=A.travelChar
        A.travelActive=false
        A.travelChar=nil
        A.travelHum=nil
        A.travelGoal=nil
        A.travelDeadline=0
        if hum and char and player.Character==char then
            local root=char:FindFirstChild("HumanoidRootPart")
            if root and root.Parent and hum.Parent==char then
                pcall(function()hum:MoveTo(root.Position)end)
            end
        end
        A.survivalStatus=reason or "TRAVEL STOPPED"
    end
    local function recordInput(input)
        local t=os.clock()
        if t<A.ignoreInputUntil then return end
        if input and input.UserInputType==Enum.UserInputType.MouseMovement
            or input and input.UserInputType==Enum.UserInputType.MouseWheel then
            A.lastPhysicalInputAt=t
            return
        end
        A.lastPhysicalInputAt=t
        if A.travelActive then
            A.userStopCount+=1
            stopTravel("REAL INPUT / AUTO WALK STOPPED")
            setBaseline()
        end
    end
    conns[#conns+1]=UIS.InputBegan:Connect(recordInput)
    conns[#conns+1]=UIS.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement
            or input.UserInputType==Enum.UserInputType.MouseWheel
            or input.UserInputType==Enum.UserInputType.Touch
            or (input.KeyCode==Enum.KeyCode.Thumbstick1
                or input.KeyCode==Enum.KeyCode.Thumbstick2)
                and input.Position.Magnitude>.25 then
            recordInput(input)
        end
    end)
    local function pulse(reason)
        if not A.robloxEnabled or not A.alive then return false end
        local t=os.clock()
        A.lastPulseAt=t
        A.ignoreInputUntil=t+2
        A.pulseAttempts+=1
        -- First preference: Roblox's VirtualUser. Avoid real-world OS input.
        if virtualUser then
            local ok,err=pcall(function()
                virtualUser:CaptureController()
                virtualUser:ClickButton2(Vector2.new(0,0))
            end)
            if ok then
                A.pulseSuccess+=1
                A.robloxStatus="VIRTUAL INPUT SENT / RESET UNVERIFIED"
                return true
            end
            A.lastError=tostring(err):sub(1,160)
        end
        -- Some executors expose VirtualInputManager instead. A tiny mouse
        -- movement is attempted only when no real user input is occurring.
        if virtualInput and type(virtualInput.SendMouseMoveEvent)=="function" then
            local ok,err=pcall(function()
                virtualInput:SendMouseMoveEvent(1,1,game)
                virtualInput:SendMouseMoveEvent(2,1,game)
            end)
            if ok then
                A.pulseSuccess+=1
                A.robloxStatus="VIRTUAL MOUSE MOVE / RESET UNVERIFIED"
                return true
            end
            A.lastError=tostring(err):sub(1,160)
        end
        A.pulseErrors+=1
        A.robloxStatus="INPUT API UNAVAILABLE / NOT PROTECTED"
        return false
    end
    conns[#conns+1]=player.Idled:Connect(function(seconds)
        A.idledEvents+=1
        if A.robloxEnabled then pulse("PLAYER_IDLED") end
    end)
    local function nearAnotherHumanoid(char,root)
        local params=OverlapParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={char}
        params.MaxParts=200
        local ok,parts=pcall(function()
            return workspace:GetPartBoundsInRadius(root.Position,28,params)
        end)
        if not ok or #parts>=200 then return true end
        local visited={}
        for _,part in ipairs(parts) do
            local model=part:FindFirstAncestorOfClass("Model")
            if model and model~=char and not visited[model] then
                visited[model]=true
                local other=model:FindFirstChildOfClass("Humanoid")
                if other and other.Health>0 then return true end
            end
        end
        return false
    end
    local function safeSurface(char,root,hum,target)
        local rayParams=RaycastParams.new()
        rayParams.FilterType=Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances={char}
        rayParams.IgnoreWater=false
        local groundLength=math.max(35,root.Size.Y+hum.HipHeight+25)
        local function ground(at)
            local ok,hit=pcall(function()
                return workspace:Raycast(
                    at+Vector3.new(0,8,0),
                    Vector3.new(0,-groundLength,0),rayParams)
            end)
            if not ok or not hit or hit.Material==Enum.Material.Water
                or hit.Normal.Y<.86 then return nil end
            return hit.Position
        end
        local from=ground(root.Position)
        local to=ground(target)
        if not from or not to or math.abs(from.Y-to.Y)>1.5 then return nil end
        local vector=horizontal(target-root.Position)
        if vector.Magnitude<=A.survivalAfkMoveStuds+.5
            or vector.Magnitude>8 then return nil end
        local ok,hit=pcall(function()
            return workspace:Raycast(
                root.Position+Vector3.new(0,1,0),
                vector,rayParams)
        end)
        if not ok or hit then return nil end
        local waist=ground(target+vector.Unit*1.25)
        if not waist or math.abs(waist.Y-to.Y)>1.1 then return nil end
        return Vector3.new(target.X,root.Position.Y+to.Y-from.Y,target.Z)
    end
    local function safeForTravel(snap)
        if ctx.action and type(ctx.action.allowed)=="function" then
            local ok,allowed,reason=pcall(ctx.action.allowed,"afk_walk",snap)
            if not ok then return false,"ACTION POLICY ERROR / NO WALK" end
            if not allowed then return false,"ACTION POLICY / "..tostring(reason) end
        elseif not snap or snap.blocked then
            return false,snap and snap.reason or "NO ANIMAL"
        end
        local char,hum,root=snap.char,snap.hum,snap.root
        if not char or not hum or not root then return false,"NO ANIMAL" end
        if hum.Health<hum.MaxHealth*.80 then return false,"LOW HP / AVOID MOVEMENT" end
        if horizontal(root.AssemblyLinearVelocity).Magnitude>2.5 then
            return false,"CHARACTER ALREADY MOVING"
        end
        local hunger=char:GetAttribute("Hunger")
        local thirst=char:GetAttribute("Thirst")
        if finite(hunger) and hunger<25 or finite(thirst) and thirst<25 then
            return false,"LOW HUNGER OR THIRST"
        end
        for _,key in ipairs({"FeralInjury","FeralBleed","FeralVenomAmt"}) do
            local value=char:GetAttribute(key)
            if finite(value) and value>0.1 then
                return false,"STATUS EFFECT / AVOID MOVEMENT"
            end
        end
        if UIS:GetFocusedTextBox() then return false,"CHAT OPEN" end
        if nearAnotherHumanoid(char,root) then return false,"ANIMAL NEARBY / STAY PUT" end
        return true,"SAFE"
    end
    local function beginTravel(snap)
        local char,root,hum=snap.char,snap.root,snap.hum
        if A.anchorChar~=char or not A.anchor then
            A.anchorChar=char
            A.anchor=root.Position
        end
        local current=root.Position
        local anchor=A.anchor
        local wantsReturn=horizontal(current-anchor).Magnitude>A.survivalAfkMoveStuds+.2
        local candidates={}
        if A.safeStepStuds>8 then
            A.survivalStatus="GAME THRESHOLD TOO LARGE / NO SAFE WALK"
            A.moveFailures+=1
            A.lastStepAt=os.clock()
            return false
        end
        if wantsReturn then
            candidates[1]=Vector3.new(anchor.X,current.Y,anchor.Z)
        else
            local f=horizontal(root.CFrame.LookVector)
            if f.Magnitude<.5 then f=Vector3.new(1,0,0)end
            f=f.Unit
            local side=Vector3.new(-f.Z,0,f.X)
            candidates={
                current+side*A.safeStepStuds,current-side*A.safeStepStuds,
                current+f*A.safeStepStuds,current-f*A.safeStepStuds
            }
        end
        for _,dest in ipairs(candidates) do
            local tested=safeSurface(char,root,hum,dest)
            if tested then
                if ctx.action and type(ctx.action.reserve)=="function" then
                    local reserved,reason=ctx.action.reserve("afk_walk",8)
                    if not reserved then
                        A.survivalStatus="ACTION PRIORITY / "..tostring(reason)
                        return false
                    end
                end
                if ctx.native and ctx.native.beforeAfkMove then
                    ctx.native.beforeAfkMove()
                end
                A.travelActive=true
                A.travelChar=char
                A.travelHum=hum
                A.travelGoal=tested
                A.travelDeadline=os.clock()+8
                A.lastStepAt=os.clock()
                A.survivalMoves+=1
                A.survivalStatus="WALK TO SAFE POINT / SERVER CREDIT UNVERIFIED"
                local ok,err=pcall(function()hum:MoveTo(tested)end)
                if not ok then
                    A.lastError=tostring(err):sub(1,120)
                    A.moveFailures+=1
                    stopTravel("MOVE COMMAND FAILED")
                end
                return ok
            end
        end
        A.moveFailures+=1
        A.survivalStatus="NO SAFE STEP / SURVIVAL BONUS MAY PAUSE"
        A.lastStepAt=os.clock()
        return false
    end
    function A.setRobloxEnabled(v)
        A.robloxEnabled=v==true
        A.robloxStatus=A.robloxEnabled and "ARMED / BEST-EFFORT VIRTUAL INPUT"
            or "OFF"
        A.lastPulseAt=os.clock()
        return A.robloxEnabled
    end
    function A.setSurvivalEnabled(v)
        A.survivalEnabled=v==true
        if not A.survivalEnabled then
            stopTravel("OFF")
            A.survivalStatus="OFF"
        else
            setBaseline()
            A.survivalStatus="ARMED / SAFE GROUND MOVEMENT"
        end
        return A.survivalEnabled
    end
    local lastRoot=nil
    local lastChar=nil
    local function tick()
        if not A.alive or not ctx.state.alive then return end
        local now=os.clock()
        if now<A.nextTick then return end
        A.nextTick=now+.45
        local snap=ctx.action and ctx.action.snapshot and ctx.action.snapshot()
        if A.robloxEnabled and now-A.lastPulseAt>=A.desiredPulsePeriod
            and now-A.lastPhysicalInputAt>65 then
            pulse("PERIODIC")
        end
        if not A.survivalEnabled then return end
        local char,root=snap and snap.char,snap and snap.root
        if char~=lastChar then
            lastChar=char
            lastRoot=root and root.Position or nil
            setBaseline()
        end
        if not char or not root or not snap.hum then
            stopTravel("NO ANIMAL")
            A.survivalStatus="WAITING FOR ANIMAL"
            return
        end
        local survival=player:GetAttribute("FeralSurvival")
        if finite(survival) then
            if finite(A.lastSurvival) and survival>A.lastSurvival+.01 then
                A.survivalProgress+=survival-A.lastSurvival
                A.progressObserved+=1
            end
            A.lastSurvival=survival
        end
        if lastRoot and horizontal(root.Position-lastRoot).Magnitude>=A.survivalAfkMoveStuds+.2 then
            A.recentPhysicalTravel=now
            lastRoot=root.Position
        end
        if A.travelActive then
            if snap.blocked or not A.travelGoal
                or A.travelChar~=char then
                A.unsafeStops+=1
                stopTravel("NATIVE ACTION / WALK CANCELLED")
            elseif horizontal(root.Position-A.travelGoal).Magnitude<=2.0 then
                A.travelActive=false
                A.travelChar=nil
                A.travelHum=nil
                A.travelGoal=nil
                if ctx.action and type(ctx.action.release)=="function" then
                    ctx.action.release("afk_walk")
                end
                A.survivalArrivals+=1
                A.recentPhysicalTravel=now
                A.lastStepAt=now
                A.survivalStatus="SAFE STEP REACHED / BONUS UNVERIFIED"
            elseif now>A.travelDeadline then
                A.moveFailures+=1
                stopTravel("WALK STALLED / NO BONUS CLAIM")
                A.lastStepAt=now
            end
            return
        end
        if now-A.lastPhysicalInputAt<55 then
            A.survivalStatus="USER ACTIVE / NO AUTO MOVE"
            return
        end
        if now-A.recentPhysicalTravel<math.max(20,A.desiredTravelPeriod-8)
            or now-A.lastStepAt<A.desiredTravelPeriod then
            A.survivalStatus="WAITING / SURVIVAL MOVEMENT TIMER"
            return
        end
        local safe,why=safeForTravel(snap)
        if not safe then
            A.lastBlock=why
            A.survivalStatus=why
            return
        end
        beginTravel(snap)
    end
    conns[#conns+1]=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            A.lastError=tostring(err):sub(1,160)
            A.survivalStatus="CONTROLLER ERROR / AUTO WALK STOPPED"
            A.survivalEnabled=false
            stopTravel("ERROR / WALK STOPPED")
        end
    end)
    function A.report()
        return table.concat({
            "FERAL NOVA v8.0 | Roblox Idle + Survival Activity",
            "platform_enabled="..tostring(A.robloxEnabled),
            "platform_status="..A.robloxStatus,
            "virtual_pulse_attempts="..A.pulseAttempts,
            "virtual_pulse_successful_calls="..A.pulseSuccess,
            "platform_idle_events="..A.idledEvents,
            "survival_assist_enabled="..tostring(A.survivalEnabled),
            "survival_status="..A.survivalStatus,
            "safe_steps_attempted="..A.survivalMoves,
            "safe_steps_reached="..A.survivalArrivals,
            "movement_stops="..A.unsafeStops,
            "move_failures="..A.moveFailures,
            "observed_survival_afk_after_s="..A.survivalAfkSeconds,
            "observed_survival_move_threshold_studs="..A.survivalAfkMoveStuds,
            "checked_safe_step_studs="..A.safeStepStuds,
            "observed_feral_hop_warning_s="..A.gameHopWarningSeconds,
            "observed_server_survival_seconds_gain="..string.format("%.2f",A.survivalProgress),
            "survival_progress_updates="..A.progressObserved,
            "last_block="..A.lastBlock,
            "last_error="..A.lastError,
            "NOTE=Roblox timeout protection is best effort; an API call is not evidence of long-term server retention.",
            "NOTE=FERAL's AFK detector is separate from Roblox's idle timeout.",
            "NOTE=Survival assist walks real short SAFE paths; no server reward or multiplier spoofing.",
            "NOTE=When safety conditions fail, survival bonus is allowed to pause instead of risking the animal.",
            "NOTE=v9 coordinator gives native combat and grab priority over AFK movement."
        },"\n")
    end
    function A.close()
        if not A.alive then return end
        A.alive=false
        stopTravel("CLOSED")
        A.robloxEnabled=false
        A.survivalEnabled=false
        for _,c in ipairs(conns) do
            pcall(function()c:Disconnect()end)
        end
    end
    return A
end
return AFK