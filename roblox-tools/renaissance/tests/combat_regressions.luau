-- Boundary regressions for actual cancellation, ownership and schema changes.
-- The service mock supplies event ordering only; no claim of live acceptance.
return function(test,eq,load,Mock,modules,boot,close,E)
    local function fallbackWorld()
        local w=Mock.new()
        w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .6 end})
        w:enableNativeActions()
        w.env.getconnections=nil
        w.env.getgc=function()return {}end
        w.virtualBiteAvailable=true
        local h=load(w,{settings={states={holdBite=true,attackSpeed=false,recovery=false}}})
        w:advance(.15)
        w.held=E.UserInputType.MouseButton1
        local input=w:input(nil,E.UserInputType.MouseButton1)
        return w,h,input
    end

    test("combat physical release cancels an input reset before its delayed Down",function()
        local w,h,input=fallbackWorld()
        assert(h.bridge:tryHeldInputBite(h.bridge:snapshot(w.time,false),w.time))
        assert(h.bridge.syntheticM1 and not h.bridge.syntheticM1.didPress)
        w.held=nil
        h:inputEnded(input)
        w:advance(.12)
        eq(w.virtualBiteDowns or 0,0)
        eq(h.bridge.syntheticM1,nil)
        h:close()
    end)

    test("combat cancellation releases a pending pulse without a later attack",function()
        local w,h=fallbackWorld()
        assert(h.bridge:tryHeldInputBite(h.bridge:snapshot(w.time,false),w.time))
        h.combatInput:cancel()
        w.held=nil
        w:advance(.12)
        eq(w.virtualBiteDowns or 0,0)
        eq(h.bridge.syntheticM1,nil)
        h:close()
    end)

    test("combat an ability starting during the Up Down gap cancels the Down",function()
        local w,h=fallbackWorld()
        assert(h.bridge:tryHeldInputBite(h.bridge:snapshot(w.time,false),w.time))
        w.player.Character:SetAttribute("FeralCrushAt",w.time+1000)
        -- Run the timer without Heartbeat to exercise its own final-state check.
        w.time+=.03;w:runTimers()
        eq(w.virtualBiteDowns or 0,0)
        eq(h.bridge.syntheticM1,nil)
        h:close()
    end)

    test("combat an unreadable delayed input context cancels and releases its timer",function()
        local w,h=fallbackWorld()
        assert(h.bridge:tryHeldInputBite(h.bridge:snapshot(w.time,false),w.time))
        h.bridge.combatPulseBlocked=function()error("input owner replaced")end
        w.time+=.03;w:runTimers()
        eq(w.virtualBiteDowns or 0,0)
        eq(h.bridge.syntheticM1,nil)
        h:close()
    end)

    test("combat heap discovery accepts reordered own closure values without guessing private offsets",function()
        local w=Mock.new()
        w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .6 end})
        w:enableNativeActions();w.env.getconnections=nil
        for _,record in pairs(w.nativeRecords) do
            if record.name=="tryBite" or record.name=="doBite" then
                local original=record.values
                record.values=function()
                    local reordered={}
                    for key,value in pairs(original()) do reordered["captured_"..tostring(key)]=value end
                    return reordered
                end
            end
        end
        local h=load(w,{settings={states={holdBite=true,attackSpeed=false}}})
        w:advance(.15)
        w.held=E.UserInputType.MouseButton1
        local input=w:input(nil,E.UserInputType.MouseButton1)
        w:advance(1.9)
        assert(h.bridge.wolfActions and h.bridge.wolfActions.tryBite,
            "identity-valid native dispatch should not depend on numeric upvalue positions")
        eq(h.bridge.wolfActions.discovery,"validated own heap closure")
        assert((w.nativeBites or 0)>=3 and w.nativeBites<=4,
            "the original callback must still enforce the unmodified cooldown")
        local readiness=h.bridge:biteReadiness(h.bridge:snapshot(w.time,false),w.time,h.policy)
        eq(readiness.privateStateKnown,nil)
        eq(w.virtualBiteCalls,nil)
        w.held=nil;h:inputEnded(input);h:close()
    end)

    test("combat a same-named heap callback capturing another player is rejected",function()
        local w=Mock.new()
        w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .6 end})
        w:enableNativeActions();w.env.getconnections=nil
        local bite,cooldown
        for fn,record in pairs(w.nativeRecords) do
            if record.name=="doBite" then bite=fn end
            if record.name=="biteCooldown" then cooldown=fn end
        end
        local calls=0
        local function impostor()calls+=1 end
        local other=w.new("Player")
        w:registerNative(impostor,"WolfController","tryBite",function()
            return {[1]=other,[3]=-100,[4]=cooldown,[5]=bite}
        end)
        w.env.getgc=function()return {impostor}end
        local h=load(w,{settings={states={holdBite=true,attackSpeed=false}}})
        w:advance(.15);w.held=E.UserInputType.MouseButton1
        local input=w:input(nil,E.UserInputType.MouseButton1)
        w:advance(1.4)
        eq(calls,0)
        assert(not (h.bridge.wolfActions and h.bridge.wolfActions.tryBite))
        eq(w.nativeBites,1)
        w.held=nil;h:inputEnded(input);h:close()
    end)

    test("combat callback discovery resets immediately for a replacement own script",function()
        local w=Mock.new();w:enableNativeActions()
        local scripts=w.player:FindFirstChild("PlayerScripts")
        local oldScript=scripts:FindFirstChild("WolfController")
        local owners={}
        for fn in pairs(w.nativeRecords) do owners[fn]=oldScript end
        local originalEnv=w.env.getfenv or getfenv
        w.env.getfenv=function(fn)
            if owners[fn] then return {script=owners[fn]} end
            return originalEnv(fn)
        end
        local h=load(w);w:advance(.3)
        local oldBite=h.bridge.wolfActions.tryBite
        oldScript.Parent=nil
        w:enableNativeActions()
        local newScript=scripts:FindFirstChild("WolfController")
        for fn in pairs(w.nativeRecords) do if not owners[fn] then owners[fn]=newScript end end
        w:advance(.4)
        assert(h.bridge.wolfActions and h.bridge.wolfActions.tryBite~=oldBite,
            "script replacement must not wait out the old discovery backoff")
        eq(h.bridge.wolfActions.script,newScript)
        h:close()
    end)

    test("combat discovery does not consume multiple heap slices at the same timestamp",function()
        local w=Mock.new();w:enableNativeActions();w.env.getconnections=nil
        local pool={}
        for _=1,600 do table.insert(pool,function()end) end
        w.env.getgc=function()return pool end
        local h=load(w)
        h.bridge.wantHeldNativeDiscovery=true
        h.bridge:recoverWolfBiteFromHeap(w.time)
        local scan=h.bridge.wolfHeapScan
        assert(scan and scan.index<=193)
        local index=scan.index
        for _=1,8 do h.bridge:recoverWolfBiteFromHeap(w.time) end
        eq(scan.index,index)
        h.combatInput:cancel();eq(h.bridge.wolfHeapScan,nil)
        h.bridge.wantHeldNativeDiscovery=true
        h.bridge:recoverWolfBiteFromHeap(w.time+.01)
        assert(h.bridge.wolfHeapScan,"a cancelled partial scan must not impose the completed-search backoff")
        h:close()
    end)

    local function isolatedInput()
        local M=modules()
        local calls=0
        local bridge={wolfActions={tryBite=function()end}}
        function bridge:restLock()return .7 end
        function bridge:attribute()return nil end
        function bridge:biteDelay()return .27 end
        function bridge:biteReadiness()return {ready=true,known=true}end
        function bridge:tryNativeBite()calls+=1;return true end
        local policy=M.policy.new()
        local input=M.combat_input.new(bridge,policy,M.core.ledger(20))
        local s={alive=true,char={},generation=1,attackHeld=true}
        return input,s,function()return calls end
    end

    test("combat a rejected native action release prevents dispatch",function()
        local input,s,count=isolatedInput()
        input:input(s,10,"M1")
        input:tick(s,10.31,{repeatHeld=true,beforeAttempt=function()return false end})
        eq(count(),0);eq(input.awaiting,nil);eq(input.pending,nil)
        input:tick(s,10.57,{repeatHeld=true,beforeAttempt=function()return true end})
        eq(count(),1)
    end)

    test("combat a throwing action release does not dispatch or escape the scheduler",function()
        local input,s,count=isolatedInput()
        input:input(s,10,"M1")
        input:tick(s,10.31,{repeatHeld=true,beforeAttempt=function()error("release failed")end})
        eq(count(),0);eq(input.awaiting,nil)
    end)

    test("combat suspended input suppresses both polling and automatic attacks",function()
        local input,s,count=isolatedInput()
        input:input(s,10,"M1")
        input:tick(s,10.1,{repeatHeld=true,automatic=true,targetValid=true,inputSuspended=true})
        eq(count(),0);eq(input.held,nil);eq(input.pending,nil)
    end)

    test("combat held and buffered ownership retain the original input identity",function()
        local M=modules()
        local bridge={restLock=function()return .7 end,attribute=function()return nil end}
        local policy=M.policy.new();policy.lastRestRelease=10
        local input=M.combat_input.new(bridge,policy,M.core.ledger(10))
        local original={}
        input:input({alive=true,char={},generation=1},10.1,"M1",original)
        eq(input.held.input,original)
        eq(input.pending.input,original)
    end)


    test("combat hub hover pauses a held bite but preserves the originating world press",function()
        local input,s,count=isolatedInput()
        local source={}
        input:input(s,10,"M1",source)
        input:tick(s,10.1,{repeatHeld=true,uiBlocked=true})
        eq(count(),0)
        assert(input.held and input.held.input==source,"hover must not erase physical M1 ownership")
        input:tick(s,10.4,{repeatHeld=true,uiBlocked=false})
        input:tick(s,10.46,{repeatHeld=true,uiBlocked=false})
        eq(count(),1)
    end)

    test("processed stale synthetic M1 echo cannot suspend a real held mouse",function()
        local w,h,physical=fallbackWorld()
        w:advance(.75)
        local before=w.nativeBites or 0
        h.bridge.syntheticM1Until=w.time+.12
        w.uis.InputBegan:Fire({UserInputType=E.UserInputType.MouseButton1,KeyCode=E.KeyCode.Unknown},true)
        eq(h.inputSuspended,false)
        assert(h.combatInput.held and h.combatInput.held.source=="event")
        w:advance(1.8)
        eq(w.nativeBites or 0,before)
        eq(w.virtualBiteCalls,nil)
        w.held=nil;w.logicalM1Down=false
        h:inputEnded(physical)
        h:close()
    end)

    test("combat real processed M1 outside replay grace still suspends repeat",function()
        local w,h,physical=fallbackWorld()
        h.bridge.syntheticM1Until=0
        w.uis.InputBegan:Fire({UserInputType=E.UserInputType.MouseButton1,KeyCode=E.KeyCode.Unknown},true)
        eq(h.inputSuspended,true)
        eq(h.combatInput.held,nil)
        w.held=nil
        h:inputEnded(physical)
        h:close()
    end)


    test("native physical M1 hold uses the adaptive factor for real scheduler timing",function()
        local M=modules()
        local nativeCalls=0
        local bridge={wolfActions={tryBite=function()end}}
        function bridge:restLock() return .7 end
        function bridge:attribute() return nil end
        function bridge:biteDelay() return .27 end
        function bridge:biteReadiness() return {ready=true,known=true} end
        function bridge:nativeBiteCooldown() return 1 end
        function bridge:tryNativeBite() nativeCalls+=1;return true end
        function bridge:tryHeldInputBite() error("synthetic fallback must not be called") end
        local input=M.combat_input.new(bridge,M.policy.new(),M.core.ledger(20))
        local body={}
        local s={alive=true,char=body,generation=1,attackHeld=true}
        input:input(s,10,"M1",{})
        input:tick(s,10.31,{repeatHeld=true,speedEnabled=true})
        input:tick(s,10.33,{repeatHeld=true,speedEnabled=true})
        eq(nativeCalls,1)
        local fast=input.nextAttempt-10.33
        assert(math.abs(fast-.62)<.0001,"62% adaptive factor must affect actual scheduling")
        input:marker(s,10.34)
        input:tick(s,input.nextAttempt-.02,{repeatHeld=true,speedEnabled=true})
        eq(nativeCalls,1)
        local at=input.nextAttempt+.01
        input:tick(s,at,{repeatHeld=true,speedEnabled=true})
        eq(nativeCalls,2)
        input:marker(s,at)
        local offAt=input.nextAttempt+.01
        input:tick(s,offAt,{repeatHeld=true,speedEnabled=false})
        eq(nativeCalls,3)
        assert(math.abs(input.nextAttempt-offAt-1)<.0001,"Faster Bites OFF restores original request interval")
    end)

    test("known native callback repeats on real mouse hold without synthesized mouse edges",function()
        local w=Mock.new()
        w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .55 end})
        w:enableNativeActions()
        w.virtualBiteAvailable=true
        local h=load(w,{settings={states={holdBite=true,attackSpeed=true,recovery=false}}})
        w:advance(.25)
        w.held=E.UserInputType.MouseButton1
        local original=w:input(nil,E.UserInputType.MouseButton1)
        w:advance(2.15)
        assert((w.nativeBites or 0)>=3,"must repeat via original function")
        eq(w.virtualBiteCalls,nil)
        assert(h.bridge.wolfActions and type(h.bridge.wolfActions.tryBite)=="function")
        local before=w.nativeBites
        w.held=nil
        w.uis.InputEnded:Fire(original)
        w:advance(.9)
        eq(w.nativeBites,before)
        h:close()
    end)


    test("M1 quick taps and manual spam never enter repeat handoff",function()
        local w=Mock.new()
        w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .55 end})
        w:enableNativeActions();w.env.getconnections=nil;w.env.getgc=function()return {} end
        w.virtualBiteAvailable=true
        local h=load(w,{settings={states={holdBite=true,attackSpeed=true,recovery=false,autoBite=false}}})
        w:advance(.15)
        for i=1,7 do
            w.held=E.UserInputType.MouseButton1
            local click=w:input(nil,E.UserInputType.MouseButton1)
            w:advance(.1)
            eq(w.virtualBiteCalls,nil)
            assert(h.combatInput.held and not h.combatInput.held.handoff)
            w.held=nil;w.logicalM1Down=false;w.uis.InputEnded:Fire(click)
            eq(h.combatInput.held,nil)
            w:advance(.07)
        end
        w:advance(.5)
        eq(w.virtualBiteCalls,nil)
        h:close()
    end)


    test("M1 sustained hold invokes own original input handler without synthetic mouse edges",function()
        local w=Mock.new()
        w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .55 end})
        w:enableNativeActions()
        local nativeValues=w.env.debug.getupvalues
        -- Simulate an executor exposing the real InputBegan listener while
        -- hiding the private nested tryBite closure's validation upvalues.
        w.env.debug.getupvalues=function(fn)
            local rec=w.nativeRecords[fn]
            if rec and rec.name=="tryBite" then return {} end
            return nativeValues(fn)
        end
        w.virtualBiteAvailable=true
        local h=load(w,{settings={states={holdBite=true,attackSpeed=true,recovery=false,autoBite=false}}})
        w:advance(.15)
        w.held=E.UserInputType.MouseButton1
        local original=w:input(nil,E.UserInputType.MouseButton1)
        eq(w.nativeBites,1)
        w:advance(.22)
        eq(w.nativeBites,1)
        eq(w.virtualBiteCalls,nil)
        assert(h.combatInput.held and not h.combatInput.held.handoff)
        w:advance(3)
        assert(h.combatInput.held and h.combatInput.held.handoff)
        assert((w.nativeBites or 0)>=3,"original WolfController input handler must repeat")
        assert(h.bridge.wolfInputAction and h.bridge.wolfInputAction.discovery=="named own onInput")
        assert(not (h.bridge.wolfActions and h.bridge.wolfActions.tryBite),
            "native inner closure should remain inaccessible in this test")
        eq(w.virtualBiteCalls,nil)
        local before=w.nativeBites
        w.held=nil;w.logicalM1Down=false;w.uis.InputEnded:Fire(original)
        w:advance(.85)
        eq(w.nativeBites,before)
        eq(h.combatInput.held,nil)
        h:close()
    end)

    test("M1 hold prefers validated native callback and never synthesizes mouse events",function()
        local w=Mock.new()
        w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .55 end})
        w:enableNativeActions();w.virtualBiteAvailable=true
        local h=load(w,{settings={states={holdBite=true,attackSpeed=true,recovery=false}}})
        w:advance(.15)
        w.held=E.UserInputType.MouseButton1
        local original=w:input(nil,E.UserInputType.MouseButton1)
        w:advance(.19)
        eq(w.nativeBites,1)
        w:advance(2.1)
        assert((w.nativeBites or 0)>=3)
        eq(w.virtualBiteCalls,nil)
        w.held=nil;w.uis.InputEnded:Fire(original)
        h:close()
    end)

    test("Left Alt no longer has any held-repeat effect",function()
        local w=Mock.new()
        w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .5 end})
        w:enableNativeActions();w.virtualBiteAvailable=true
        local h=load(w,{settings={states={holdBite=true,attackSpeed=true,recovery=false}}})
        w:advance(.15)
        w.keys={[E.KeyCode.LeftAlt]=true}
        local press=w:input(E.KeyCode.LeftAlt)
        w:advance(1.35)
        eq(w.nativeBites or 0,0)
        eq(w.virtualBiteCalls,nil)
        eq(h.combatInput.held,nil)
        w.keys[E.KeyCode.LeftAlt]=nil;w.uis.InputEnded:Fire(press)
        h:close()
    end)


    test("native M1 input-handler handoff pauses for prey minigame and resumes without mouse replay",function()
        local w=Mock.new()
        w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .55 end})
        w:enableNativeActions();w:enableNativeGrab()
        local originalValues=w.env.debug.getupvalues
        w.env.debug.getupvalues=function(fn)
            local rec=w.nativeRecords[fn]
            if rec and rec.name=="tryBite" then return {} end
            return originalValues(fn)
        end
        w.virtualBiteAvailable=true
        local h=load(w,{settings={states={holdBite=true,minigame=true,attackSpeed=true,recovery=false,autoBite=false}}})
        w:advance(.15);w.held=E.UserInputType.MouseButton1
        local original=w:input(nil,E.UserInputType.MouseButton1)
        w:advance(1.4)
        local before=w.nativeBites or 0
        w:remote("FeralGrabV2").OnClientEvent:Fire("begin",{f=979,role="prey",n=3})
        w:advance(.9)
        eq(w.nativeBites or 0,before)
        eq(w.virtualBiteCalls,nil)
        w:remote("FeralGrabV2").OnClientEvent:Fire("end",{f=979})
        w:advance(1.6)
        assert((w.nativeBites or 0)>before,"same original hold resumes after minigame")
        eq(w.virtualBiteCalls,nil)
        w.held=nil;w.logicalM1Down=false;w.uis.InputEnded:Fire(original)
        h:close()
    end)

    test("preferred backend survives unmarked bite intervals and bounded probe returns to verified API",function()
        local w=Mock.new()
        w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .6 end})
        w:enableNativeActions();w.virtualBiteAvailable=true
        local h=load(w)
        local b=h.bridge
        b.heldInputModes=3;b.heldInputIndex=2
        b:noteHeldInputMarker()
        eq(b.heldInputVerifiedIndex,2)
        for i=1,4 do b:noteHeldInputTimeout() end
        eq(b.heldInputIndex,2)
        b:noteHeldInputTimeout()
        eq(b.heldInputIndex,3)
        b:noteHeldInputTimeout()
        eq(b.heldInputIndex,3)
        b:noteHeldInputTimeout()
        eq(b.heldInputIndex,2)
        h:close()
    end)

    test("stale M1 pulse watchdog clears permanently owned synthetic press",function()
        local w=Mock.new();w:enableNativeActions()
        local h=load(w)
        local count=0
        h.bridge.syntheticM1={startedAt=w.time-.75,release=function()count+=1 end}
        assert(h.bridge:clearStaleSyntheticBite(w.time))
        eq(count,1);eq(h.bridge.syntheticM1,nil)
        h:close()
    end)

    test("late synthetic M1 echo beyond grace never becomes a second manual press during a real hold",function()
        local w=Mock.new()
        w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .55 end})
        w:enableNativeActions()
        w.env.getconnections=nil;w.env.getgc=function()return {}end
        w.virtualBiteAvailable=true
        local h=load(w,{settings={states={holdBite=true,recovery=false,autoBite=false}}})
        w:advance(.15);w.held=E.UserInputType.MouseButton1
        local original=w:input(nil,E.UserInputType.MouseButton1)
        w:advance(1.15)
        assert(h.combatInput.held and h.combatInput.held.handoff)
        local owned=h.combatInput.held
        local intentCount=h.ledger.counts.attack_intent
        h.bridge.syntheticM1Until=0
        local echo={UserInputType=E.UserInputType.MouseButton1,KeyCode=E.KeyCode.Unknown}
        h:preInput(echo)
        h:input(echo,false)
        eq(h.combatInput.held,owned)
        eq(h.physicalM1Input,original)
        eq(h.ledger.counts.attack_intent,intentCount)
        w.held=nil;w.logicalM1Down=false
        w.uis.InputEnded:Fire(original)
        h:close()
    end)

    test("native game M1 input callback rejects ambiguous same-owned listeners",function()
        local w=Mock.new();w:enableNativeActions()
        local values=w.env.debug.getupvalues
        w.env.debug.getupvalues=function(fn)
            local rec=w.nativeRecords[fn]
            if rec and rec.name=="tryBite" then return {} end
            return values(fn)
        end
        local fake=function()end
        w:registerNative(fake,"WolfController","onInput",function()return {}end)
        w.uis.InputBegan:Connect(fake)
        local h=load(w,{settings={states={holdBite=true,attackSpeed=true,recovery=false}}})
        w:advance(.2)
        eq(h.bridge:nativeWolfInputAction(w.time),nil)
        w.held=E.UserInputType.MouseButton1
        local original=w:input(nil,E.UserInputType.MouseButton1)
        local count=w.nativeBites
        w:advance(1.4)
        eq(w.nativeBites,count)
        eq(w.virtualBiteCalls,nil)
        w.held=nil;w.uis.InputEnded:Fire(original)
        h:close()
    end)

    test("native M1 input callback ignores a foreign script listener",function()
        local w=Mock.new();w:enableNativeActions()
        local foreignCalls=0
        local fake=function()foreignCalls+=1 end
        w:registerNative(fake,"OtherController","onInput",function()return {}end)
        w.uis.InputBegan:Connect(fake)
        local h=load(w)
        local binding=h.bridge:nativeWolfInputAction(w.time)
        assert(binding and binding.discovery=="named own onInput")
        local before=foreignCalls
        assert(not h.bridge:tryNativeInputBite(w.time,nil))
        eq(foreignCalls,before)
        h:close()
    end)

    test("private original input handler retains Faster Bites cadence factor ON and OFF",function()
        local M=modules()
        local calls=0
        local bridge={wolfActions={}}
        function bridge:restLock()return .7 end
        function bridge:attribute()return nil end
        function bridge:biteDelay()return .25 end
        function bridge:nativeBiteCooldown()return 1 end
        function bridge:biteReadiness()return {ready=false,known=false,reason="native timing unavailable"}end
        function bridge:visibleBiteWindow()return true end
        function bridge:nativeWolfInputAction()return {fn=function()end}end
        function bridge:tryNativeInputBite()calls+=1;return true end
        local c=M.combat_input.new(bridge,M.policy.new(),M.core.ledger(20))
        local input={UserInputType=E.UserInputType.MouseButton1}
        local s={alive=true,char={},generation=1,attackHeld=true,mouseHeld=true}
        c:input(s,10,"M1",input)
        c:tick(s,10.31,{repeatHeld=true,speedEnabled=true})
        c:tick(s,10.33,{repeatHeld=true,speedEnabled=true})
        eq(calls,1)
        assert(math.abs(c.nextAttempt-10.95)<.001,"fast factor .62 must schedule native input")
        c:marker(s,10.34)
        local now=c.nextAttempt+.02
        c:tick(s,now,{repeatHeld=true,speedEnabled=false})
        eq(calls,2)
        assert(math.abs(c.nextAttempt-now-1)<.001,"OFF must restore native request spacing")
        c:release("M1",now+.01)
        c:tick(s,now+1.4,{repeatHeld=true})
        eq(calls,2)
    end)

    test("private native handler failure never falls back to synthetic mouse replay",function()
        local w=Mock.new();w:enableNativeActions();w.virtualBiteAvailable=true
        w.env.getconnections=nil
        w.env.getgc=function()return {}end
        local h=load(w,{settings={states={holdBite=true,attackSpeed=true,recovery=false}}})
        w:advance(.15);w.held=E.UserInputType.MouseButton1
        local original=w:input(nil,E.UserInputType.MouseButton1)
        local originalBites=w.nativeBites
        w:advance(2.3)
        eq(w.nativeBites,originalBites)
        eq(w.virtualBiteCalls,nil)
        eq(h.registry.byId.holdBite.applied,false)
        w.held=nil;w.uis.InputEnded:Fire(original)
        h:close()
    end)

    test("native held-M1 engine recovers a lost hardware InputEnded without synthetic edges",function()
        local w=Mock.new();w:enableNativeActions()
        w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .55 end})
        local h=load(w,{settings={states={holdBite=true,attackSpeed=true,recovery=false}}})
        w:advance(.2);w.held=E.UserInputType.MouseButton1
        local original=w:input(nil,E.UserInputType.MouseButton1)
        w:advance(1.5)
        assert(h.combatInput.held and h.combatInput.held.handoff)
        local before=w.nativeBites
        w.held=nil -- intentionally miss UserInputService.InputEnded
        w:advance(.42)
        eq(h.combatInput.held,nil)
        local stopped=w.nativeBites
        w:advance(.8)
        eq(w.nativeBites,stopped)
        assert(stopped>=before)
        eq(w.virtualBiteCalls,nil)
        w.uis.InputEnded:Fire(original)
        h:close()
    end)

    test("native hold finds uniquely owned WolfController onInput in heap if signal callbacks are hidden",function()
        local w=Mock.new();w:enableNativeActions();w.virtualBiteAvailable=true
        w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .55 end})
        local originalValues=w.env.debug.getupvalues
        w.env.debug.getupvalues=function(fn)
            local rec=w.nativeRecords[fn]
            if rec and rec.name=="tryBite" then return {} end
            return originalValues(fn)
        end
        -- The executor hides getconnections but exposes uniquely script-owned
        -- functions through getgc, getfenv and debug.info.
        w.env.getconnections=nil
        local originalEnv=w.env.getfenv
        w.env.getfenv=function(fn)
            local rec=w.nativeRecords[fn]
            if rec and rec.script=="WolfController" then
                return {script=w.player:FindFirstChild("PlayerScripts"):FindFirstChild("WolfController")}
            end
            return originalEnv and originalEnv(fn) or {}
        end
        local h=load(w,{settings={states={holdBite=true,attackSpeed=true,recovery=false}}})
        w:advance(.2);w.held=E.UserInputType.MouseButton1
        local first=w:input(nil,E.UserInputType.MouseButton1)
        w:advance(2.3)
        assert(h.bridge.wolfInputAction
            and h.bridge.wolfInputAction.discovery=="unique own heap onInput")
        assert((w.nativeBites or 0)>=2)
        eq(w.virtualBiteCalls,nil)
        w.held=nil;w.uis.InputEnded:Fire(first)
        h:close()
    end)
end
