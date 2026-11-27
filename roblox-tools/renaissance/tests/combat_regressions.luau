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
        input:tick(s,10.1,{repeatHeld=true,beforeAttempt=function()return false end})
        eq(count(),0);eq(input.awaiting,nil);eq(input.pending,nil)
        input:tick(s,10.35,{repeatHeld=true,beforeAttempt=function()return true end})
        eq(count(),1)
    end)

    test("combat a throwing action release does not dispatch or escape the scheduler",function()
        local input,s,count=isolatedInput()
        input:input(s,10,"M1")
        input:tick(s,10.1,{repeatHeld=true,beforeAttempt=function()error("release failed")end})
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
        eq(count(),1)
    end)

    test("combat queued synthetic processed M1 cannot permanently suspend a physical hold",function()
        local w,h,physical=fallbackWorld()
        w:advance(.75)
        assert((w.virtualBiteCalls or 0)>0,"fallback must have replayed a native input")
        local before=w.nativeBites or 0
        -- The real input has already begun. This processed echo is delivered
        -- after a virtual-input API call has returned, but before its owned
        -- synthetic grace window expires (a real-world asynchronous ordering).
        h.bridge.syntheticM1Until=w.time+.12
        w.uis.InputBegan:Fire({UserInputType=E.UserInputType.MouseButton1,KeyCode=E.KeyCode.Unknown},true)
        eq(h.inputSuspended,false)
        assert(h.combatInput.held and h.combatInput.held.source=="event")
        w:advance(1.8)
        assert((w.nativeBites or 0)>=before+2,"held bites must continue after a delayed echo")
        w.held=nil
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
        input:tick(s,10.1,{repeatHeld=true,speedEnabled=true})
        eq(nativeCalls,1)
        local fast=input.nextAttempt-10.1
        assert(math.abs(fast-.62)<.0001,"62% adaptive factor must affect actual scheduling")
        input:marker(s,10.11)
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

    test("private bite callback never causes synthetic M1 replay while physical M1 is held",function()
        local w=Mock.new()
        w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .6 end})
        w:enableNativeActions()
        w.env.getconnections=nil
        w.env.getgc=function()return {} end
        w.virtualBiteAvailable=true
        local h=load(w,{settings={states={holdBite=true,attackSpeed=true,recovery=false}}})
        w:advance(.15)
        w.held=E.UserInputType.MouseButton1
        local original=w:input(nil,E.UserInputType.MouseButton1)
        eq(w.nativeBites,1)
        w:advance(2.1)
        eq(w.nativeBites,1)
        eq(w.virtualBiteCalls,nil)
        assert(h.combatInput.held~=nil,"real hold remains owned during native discovery")
        assert(h.registry.byId.holdBite.outcome=="unverified")
        w.held=nil
        w.uis.InputEnded:Fire(original)
        h:close()
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
end
