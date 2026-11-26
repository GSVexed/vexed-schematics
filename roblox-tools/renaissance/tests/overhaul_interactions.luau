-- Integrated native-contract regressions; these do not certify live game outcomes.
test("overhaul long native stand-up locks cannot rearm recovery ahead of the buffered bite",function()
    local w=Mock.new();w:enableNativeActions();w.hum.Health=50
    w:addConfig("AnimProfiles",{Long={REST_UP_LOCK=1.5}})
    w.player.Character:SetAttribute("AnimProfile","Long")
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w:input(nil,E.UserInputType.MouseButton1);assert(h.combatInput.pending)
    w:advance(1.25);eq(w.nativeBites,nil);eq(h.recovery.owned,nil)
    w:advance(.4);eq(w.nativeBites,1);eq(h.recovery.owned,nil)
    eq(h.ledger.counts.native_bite_buffer_released,1);h:close()
end)

test("overhaul delayed native Rest state gets one eventual bite rather than repeated callback attempts",function()
    local w=Mock.new();w:enableNativeActions();w.hum.Health=50
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w:input(nil,E.UserInputType.MouseButton1)
    w.nativeRestReleasedAt=w.time+.15
    w:advance(.8);eq(w.nativeBites,nil);assert(h.combatInput.pending)
    w:advance(.2);eq(w.nativeBites,1);eq(h.combatInput.pending,nil)
    eq(w.nativeBiteAttempts,2);h:close()
end)

test("overhaul an observed bite marker cancels the buffer even when its callback was missed",function()
    local w=Mock.new();w:enableNativeActions();w.hum.Health=50
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w:input(nil,E.UserInputType.MouseButton1);assert(h.combatInput.pending)
    local original=h.nativeAttribute;h.nativeAttribute=function()end
    w.player.Character:SetAttribute("WolfBiteAt",w.time+1000)
    h.nativeAttribute=original;w:advance(.9)
    eq(w.nativeBites,nil);eq(h.combatInput.pending,nil)
    eq(h.ledger.counts.native_bite_buffer_released,nil);h:close()
end)

test("overhaul a click consumed by another UI binding cannot become a delayed bite",function()
    local w=Mock.new();w:enableNativeActions();w.hum.Health=50
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w.cas:BindActionAtPriority("ExternalModal",function()return E.ContextActionResult.Sink end,
        false,3500,E.UserInputType.MouseButton1)
    w:input(nil,E.UserInputType.MouseButton1)
    eq(h.combatInput.pending,nil);eq(h.lastIntent.consumed,true)
    w:advance(1.2);eq(w.nativeBites,nil);eq(h.ledger.counts.native_bite_buffer_released,nil)
    w.cas:UnbindAction("ExternalModal");h:close()
end)

test("overhaul failed first Rest dispatch restores pose and preserves later manual Rest",function()
    local w=Mock.new();w.hum.Health=40;w:remote("WolfActions"):Destroy()
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    eq(h.recovery.owned,nil);eq(h.recovery.lastAutomaticCharacter,nil)
    eq(w.player.Character:GetAttribute("WolfDbgRestP"),nil)
    w.player.Character:SetAttribute("WolfRest",true)
    eq(h.policy.manualRest,true);eq(w.player.Character:GetAttribute("WolfRest"),true)
    h:close()
end)

test("overhaul explicit healed zero releases condition Rest immediately while missing amounts retain grace",function()
    local w=Mock.new();local c=w.player.Character;c:SetAttribute("FeralVenomAmt",4)
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    eq(h.recovery.owned,c)
    c:SetAttribute("FeralVenomAmt",nil);w:advance(.4);eq(h.recovery.owned,c)
    c:SetAttribute("FeralVenomAmt",0);w:advance(.02);eq(h.recovery.owned,nil)
    eq(h.recovery.observations.venom,nil);h:close()
end)

test("overhaul condition grace is independent for injury bleeding and venom",function()
    local w=Mock.new();local c=w.player.Character
    c:SetAttribute("FeralInjury",2);c:SetAttribute("FeralVenomAmt",3)
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    c:SetAttribute("FeralInjury",0);c:SetAttribute("FeralVenomAmt",nil)
    w:advance(.4);eq(h.recovery.owned,c)
    c:SetAttribute("FeralVenomAmt",0);w:advance(.02);eq(h.recovery.owned,nil)
    h:close()
end)

test("overhaul a new animal does not inherit prior attack pauses or feeding caches",function()
    local w=Mock.new();w:enableNativeActions();w.hum.Health=40
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w:input(nil,E.UserInputType.MouseButton1);assert(h.combatInput.pending)
    h.feeding.mode,h.feeding.known,h.feeding.nextProbe="eat",true,w.time+20
    local c=w:spawn("Bear");w.hum.Health=40;w:advance(.1)
    eq(h.combatInput.pending,nil);eq(h.policy.attackUntil,0)
    eq(h.feeding.mode,nil);eq(h.feeding.busy,false);eq(h.recovery.owned,c)
    h:close()
end)

test("overhaul transient replicated feeding flags cannot replenish a spent repair budget",function()
    local w=Mock.new();w:enableNativeActions();local c=w.player.Character
    c:SetAttribute("Hunger",40);c:SetAttribute("FeedCan","eat")
    local h=load(w,{settings={states={recovery=false}}});w:advance(.1)
    w:input(E.KeyCode.E);w:advance(10)
    eq(w.nativeFeedToggles,3);eq(h.ledger.counts.native_feed_stall_repair,1)
    c:SetAttribute("WolfFeed",false);w:advance(.15)
    c:SetAttribute("WolfFeed","eat");w:advance(5)
    eq(w.nativeFeedToggles,3);eq(h.ledger.counts.native_feed_stall_repair,1)
    h:close()
end)

test("overhaul gamepad ButtonB protects the native feed approach before its binding runs",function()
    local w=Mock.new();w:enableNativeActions();w.feedApproach=true;w.hum.Health=40
    w.player.Character:SetAttribute("FeedCan","drink")
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w.cas:BindActionAtPriority("NativePadFeed",function(_,state)
        if state==E.UserInputState.Begin then
            eq(h.recovery.owned,nil);h.bridge:toggleNativeFeed(w.time)
        end
        return E.ContextActionResult.Sink
    end,false,2000,E.KeyCode.ButtonB)
    w:input(E.KeyCode.ButtonB,E.UserInputType.Gamepad1);w:advance(3)
    eq(h.feeding.busy,true);eq(h.recovery.owned,nil);eq(w.nativeFeedMode(),"drink")
    w.cas:UnbindAction("NativePadFeed");h:close()
end)

test("overhaul native pickup between frames preserves the next G drop input",function()
    local w=Mock.new();w:enableCarry();w.waterY=3;w.root.Position=Mock.V3.new(0,6,0)
    local cub=w:npc(1,Mock.V3.new(0,3,-2),true)
    local h=load(w,{settings={states={recovery=false}}});w:advance(.1)
    w:input(E.KeyCode.G);assert(h.rescue.pending)
    local clamp=w.new("ObjectValue");clamp.Name="FeralClamp";clamp.Value=cub
    clamp:SetAttribute("Carry",true);clamp.Parent=w.player.Character
    w:input(E.KeyCode.G);eq(w.nativeG,1);eq(h.rescue.pending,nil)
    h:close()
end)

test("overhaul cub rescue yields if another native carry wins first",function()
    local M=modules();local carried=false;local sent=0
    local bridge={carrying=function()return carried end,carryEligible=function()return true end,
        carryWaterAllowed=function()return true end,fire=function()sent+=1;return true end}
    local rescue=M.rescue.new(bridge,{event=function()end})
    local c={};local s={alive=true,char=c,generation=1,holding=true}
    rescue.pending={char=c,generation=1,target={char={}},untilAt=10}
    rescue:tick(s,1);eq(rescue.pending,nil);eq(sent,0)
end)

test("overhaul pending cub rescue excludes assisted climb flight and idle movement",function()
    local M=modules();local p=M.policy.new()
    local s={alive=true,rescuing=true,combat=false,hp=100,maxHP=100,hunger=100,thirst=100,injury=0,bleed=0,venom=0}
    for _,mode in ipairs({"climb","flight","afk"}) do eq(p:allowed(mode,s,100),false) end
end)

test("overhaul retired minigame IDs cannot resurrect an ended or replaced session",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    g:event("begin",{f=1001},100,1,.32,2.5)
    g:event("begin",{f=1002},100.1,1,.32,2.5)
    eq(g:event("begin",{f=1001},100.2,1,.32,2.5),false);eq(g.session,1002)
    g:event("end",{f=1002},100.3,1,.32,2.5)
    eq(g:event("begin",{f=1002},100.4,1,.32,2.5),false);eq(g.active,false)
    eq(g:event("begin",{f=1002},100.5,2,.32,2.5),true);eq(g.generation,2)
end)

test("overhaul minigame retirement memory remains bounded through long play",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    for session=1,100 do
        g:event("begin",{f=session},100+session,1,.32,2.5)
        g:event("end",{f=session},100+session+.1,1,.32,2.5)
    end
    eq(#g.retirementOrder,32)
    local count=0;for _ in pairs(g.retired)do count+=1 end;eq(count,32)
    eq(g:event("begin",{f=100},201,1,.32,2.5),false)
end)

test("overhaul a final clock slip retains the issued strike for a later legal window",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    g:event("begin",{f=1010},100,1,.32,2.5)
    g:event("strike",{f=1010,k=1,t0=100,spd=1,from=0,zc=.5,zw=.215},100,1,.32,2.5)
    g:tick(100.5,1,true,function()return false,"clock_moved",100.7 end)
    eq(g.presses,0);assert(g.pending);assert(g.pending.at>101)
    local at=g.pending.at
    g:tick(at,1,true,function(session,strike,actual)
        eq(session,1010);eq(strike,1);close(actual,at)
        assert(math.abs(M.grab.triangle(actual,100,1,0)-.5)<=.215*.5*.32)
        return true
    end)
    eq(g.presses,1);eq(g.pending,nil);eq(g.grades.perfect,0)
end)

test("overhaul ambiguous dispatch failures and reentrant session changes never replay a strike",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    g:event("begin",{f=1011},100,1,.32,2.5)
    g:event("strike",{f=1011,k=1,t0=100,spd=1,from=0,zc=.5,zw=.215},100,1,.32,2.5)
    g:tick(100.5,1,true,function()error("dispatch status unknown")end)
    eq(g.pending,nil);eq(g.presses,0)
    g:event("strike",{f=1011,k=2,t0=101,spd=1,from=0,zc=.5,zw=.215},101,1,.32,2.5)
    g:tick(101.5,1,true,function()
        g:event("begin",{f=1012},101.6,1,.32,2.5)
        return false,"clock_moved",101.7
    end)
    eq(g.session,1012);eq(g.pending,nil);eq(g.status,"native session observed")
end)

test("overhaul an ended manual minigame lease passes gamepad combat to native input",function()
    local w=Mock.new();w:enableNativeGrab();w:enableNativeActions()
    local h=load(w,{settings={states={minigame=true,recovery=false}}});w:advance(.2)
    w:remote("FeralGrabV2").OnClientEvent:Fire("begin",{f=1013,role="prey"})
    assert(h.grabInput.lease);w.nativeGrabState().ended=true
    w:input(E.KeyCode.ButtonR2,E.UserInputType.Gamepad1)
    eq(w.nativeBites,1);eq(w.nativeManualPresses,nil);h:close()
end)

test("overhaul native strike dispatch precedes Territory work in the same heartbeat",function()
    local w=Mock.new();w:enableNativeGrab()
    local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local r=w:remote("FeralGrabV2");r.OnClientEvent:Fire("begin",{f=1014})
    r.OnClientEvent:Fire("strike",{f=1014,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215})
    local old=h.territory;local observed=false
    h.territory={tick=function()eq(h.grab.presses,1);observed=true end,agent={enabled=false},close=function()end}
    w.time=h.grab.pending.at-1000+.001
    h:tick(.02);eq(observed,true);h.territory=old;h:close()
end)

test("overhaul same-target overlapping replies remain ambiguous without a unique attack ID",function()
    local w=Mock.new();w:enableNativeActions();local _,target=w:enemy(2)
    local h=load(w,{settings={states={recovery=false}}});w:advance(.2)
    for bite=1,2 do
        w:input(nil,E.UserInputType.MouseButton1)
        w:remote("FeralBiteLocal").Event:Fire(target)
        if bite==1 then w:advance(.55) end
    end
    w:remote("FeralHit").OnClientEvent:Fire("hit",{a=w.player.Character,v=target,dmg=8})
    eq(h.transactions[1].feedback,nil);eq(h.transactions[2].feedback,nil)
    eq(h.ledger.counts.native_outgoing_hit_reply_unmatched,1);h:close()
end)

test("overhaul a delayed local impact cannot be assigned to a newer bite before its claim",function()
    local w=Mock.new();w:enableNativeActions();local _,a=w:enemy(2);local _,b=w:enemy(2)
    local h=load(w,{settings={states={recovery=false}}});w:advance(.2)
    w:input(nil,E.UserInputType.MouseButton1);w:advance(.55)
    w:input(nil,E.UserInputType.MouseButton1)
    w:remote("FeralBiteLocal").Event:Fire(a)
    eq(h.transactions[1].localTarget,a);eq(h.transactions[2].localTarget,nil)
    w:advance(.3);w:remote("FeralBiteLocal").Event:Fire(b)
    eq(h.transactions[2].localTarget,b);h:close()
end)

test("overhaul late native damage and replicated HP update the bounded original transaction",function()
    local w=Mock.new();w:enableNativeActions();local _,target,hum=w:enemy(2)
    local h=load(w,{settings={states={recovery=false}}});w:advance(.2)
    w:input(nil,E.UserInputType.MouseButton1);w:remote("FeralBiteLocal").Event:Fire(target)
    w:advance(1.4);eq(h.transactions[1].classified,true)
    w:remote("FeralHit").OnClientEvent:Fire("hit",{a=w.player.Character,v=target,dmg=9})
    hum.Health=91;w:advance(.15)
    assert(h.combatStatus:find("reports 9.0 damage",1,true))
    assert(h.combatStatus:find("HP decline correlated",1,true))
    eq(h.ledger.counts.target_hp_decline_correlated,1)
    w:advance(1);eq(h.transactions[1].hpBefore,nil);eq(h.transactions[1].closed,true)
    h:close()
end)

test("overhaul transient HP loss remains observed but growth invalidates the comparison",function()
    local w=Mock.new();w:enableNativeActions();local _,target,hum=w:enemy(2)
    local h=load(w,{settings={states={recovery=false}}});w:advance(.2)
    w:input(nil,E.UserInputType.MouseButton1);w:remote("FeralBiteLocal").Event:Fire(target)
    w:advance(.3);hum.Health=90;w:advance(.15);hum.Health=100;w:advance(.7)
    eq(h.transactions[1].hpDrop,true);assert(h.combatStatus:find("HP fell",1,true))
    hum.MaxHealth=120;w:advance(.15)
    eq(h.transactions[1].hpInvalid,true)
    assert(not h.combatStatus:find("HP fell",1,true));h:close()
end)

test("overhaul surface-flight requests restore owned attributes and preserve later replacements",function()
    local w=Mock.new();w:spawn("BaldEagle");w.waterY=3;local c=w.player.Character
    c:SetAttribute("FeralSwimLocal",true);c:SetAttribute("FeralFlyRequest",-5)
    local h=load(w,{settings={states={flight=true}}});w:advance(.1)
    assert(h:requestFlight());h:set("flight",false)
    eq(c:GetAttribute("FeralFlyRequest"),-5)
    h:set("flight",true);w:advance(.8);assert(h:requestFlight())
    c:SetAttribute("FeralFlyRequest",999);h:close();eq(c:GetAttribute("FeralFlyRequest"),999)
end)

test("overhaul the native talon release binding also works for an eligible Eagle",function()
    local w=Mock.new();w:enableVultureFlight();local c=w.player.Character
    c:SetAttribute("Species","BaldEagle");c:SetAttribute("FeralTalonLock",901)
    local h=load(w,{settings={states={flight=true}}});w:advance(.2)
    w:input(E.KeyCode.ButtonB,E.UserInputType.Gamepad1);w:advance(1.2)
    eq(h.ledger.counts.native_talon_release_retried,1);eq(h.feeding.busy,false)
    local releases=0;for _,call in ipairs(w.calls)do
        if call.name=="FeralLunge" and call.args[1]=="release" then releases+=1 end
    end
    eq(releases,2);h:close()
end)

test("overhaul throwing optional minigame introspection cannot shut down the hub",function()
    local w=Mock.new();w:enableNativeGrab()
    local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local r=w:remote("FeralGrabV2");r.OnClientEvent:Fire("begin",{f=1020})
    r.OnClientEvent:Fire("strike",{f=1020,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215})
    h.bridge.grabController.state=function()error("executor inspection failed")end
    w:advance(.6);eq(h.active,true);eq(h.closed,false);eq(h.grab.presses,1)
    h:close();assert(w.cas:GetAllBoundActionInfo().FeralGrabV2Press)
end)

test("overhaul newly recovered native UI strikes are pumped before Territory work",function()
    local w=Mock.new();w:enableNativeGrab()
    local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    w:remote("FeralGrabV2").OnClientEvent:Fire("begin",{f=1021})
    h.grab:reset("missed observer event")
    local state=w.nativeGrabState()
    state.strike={k=1,t0=w.time+1000-.49,spd=1,from=0,zc=.5,zw=.215,dur=2.5}
    h.nextGrabPoll=0
    local old=h.territory;local observed=false
    h.territory={tick=function()
        eq(h.grab.presses,1);eq(h.timingCritical,true);observed=true
    end,agent={enabled=false},close=function()end}
    h:tick(.02);eq(observed,true);h.territory=old;h:close()
end)

test("overhaul a temporary unavailable server clock preserves a real strike without sending guessed times",function()
    local w=Mock.new();w:enableNativeGrab()
    local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local r=w:remote("FeralGrabV2");r.OnClientEvent:Fire("begin",{f=1022})
    r.OnClientEvent:Fire("strike",{f=1022,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215})
    local original=w.workspace.GetServerTimeNow
    w.workspace.GetServerTimeNow=function()error("clock unavailable")end
    w:advance(.7);eq(h.grab.presses,0);assert(h.grab.pending);eq(h.active,true)
    w.workspace.GetServerTimeNow=original;w:advance(1)
    eq(h.grab.presses,1);eq(h.grab.grades.perfect,0)
    for _,call in ipairs(w.calls)do
        if call.name=="FeralGrabV2" and call.args[1]=="press" then close(call.args[4],call.at+1000) end
    end
    h:close()
end)

test("overhaul a lost minigame end packet cannot reserve recovery forever between strikes",function()
    local w=Mock.new();w.hum.Health=60
    local h=load(w,{settings={states={minigame=true,recovery=true}}});w:advance(.2)
    w:remote("FeralGrabV2").OnClientEvent:Fire("begin",{f=1023})
    w:advance(.2);eq(h.grab.active,true);eq(h.recovery.owned,nil)
    w:advance(8.1);eq(h.grab.active,false);eq(h.recovery.owned,w.player.Character)
    h:close()
end)

test("overhaul an extended missing clock releases the minigame lease without inventing a result",function()
    local w=Mock.new();w:enableNativeGrab()
    local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    w:remote("FeralGrabV2").OnClientEvent:Fire("begin",{f=1024})
    assert(h.grabInput.lease)
    w.workspace.GetServerTimeNow=function()error("clock unavailable")end
    w:advance(8.3);eq(h.grab.active,false);eq(h.grabInput.lease,nil)
    assert(w.cas:GetAllBoundActionInfo().FeralGrabV2Press);eq(h.grab.presses,0);eq(h.grab.grades.perfect,0)
    h:close()
end)

test("overhaul AFK treats invalid HP needs and status amounts as unknown",function()
    local M=modules();local p=M.policy.new()
    local s={alive=true,combat=false,hp=100,maxHP=100,hunger=100,thirst=100,injury=0,bleed=0,venom=0}
    eq(p:allowed("afk",s,100),true)
    for _,key in ipairs({"hp","maxHP","hunger","thirst","injury","bleed","venom"}) do
        local before=s[key]
        for _,bad in ipairs({0/0,math.huge,-math.huge}) do
            s[key]=bad;eq(p:allowed("afk",s,100),false)
        end
        s[key]=nil;eq(p:allowed("afk",s,100),false);s[key]=before
    end
    s.maxHP=0;eq(p:allowed("afk",s,100),false)
end)

test("overhaul native practice takeover cancels a previous real fight without issuing its old strike",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    g:event("begin",{f=1030},100,1,.32,2.5)
    g:event("strike",{f=1030,k=1,t0=100,spd=1,from=0,zc=.5,zw=.215},100,1,.32,2.5)
    g:syncNative({id="practice",practice=true},100.2,1,.32,2.5,10.2)
    eq(g.active,false);eq(g.pending,nil)
    g:tick(100.5,1,true,function()error("old fight press")end)
    eq(g.presses,0);eq(g.grades.perfect,0)
end)

test("overhaul malformed native bite pause cannot crash or indefinitely pause minigames",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    g:event("begin",{f=1031},100,1,.32,2.5)
    g:event("bite",{f=1031},100,1,.32,2.5,{bitePause="changed schema"})
    close(g.pauseUntil,100.6)
    g:event("bite",{f=1031},101,1,.32,2.5,{bitePause=math.huge})
    close(g.pauseUntil,101.6)
end)

test("overhaul negative condition amounts are unknown rather than a measured cure",function()
    local w=Mock.new();local c=w.player.Character;c:SetAttribute("FeralBleed",3)
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    c:SetAttribute("FeralBleed",-1);w:advance(.3);eq(h.recovery.owned,c);eq(h.recovery.observations.bleed,nil)
    c:SetAttribute("FeralBleed",0);w:advance(.02);eq(h.recovery.owned,nil)
    h:close()
end)

test("overhaul shutdown reports scoped cleanup failures while completing other releases",function()
    local w,h=boot({recovery=true,stamina=true})
    h.scope:add(function()error("injected scoped disconnect failure")end)
    h:close();eq(h.closed,true);eq(w:connections(),0)
    eq(w.localEnvironment.FERAL_RENAISSANCE_ACTIVE,nil)
    eq(#h.cleanupErrors,1)
    assert(h.cleanupErrors[1]:find("injected scoped disconnect failure",1,true))
    h:close();eq(#h.cleanupErrors,1)
end)

test("overhaul native minigame ownership still preempts Rest when its automation is explicitly OFF",function()
    local w=Mock.new();w:enableNativeGrab();w.player.Character:SetAttribute("FeralVenomAmt",4)
    local h=load(w,{settings={states={recovery=true,minigame=false}}});w:advance(.2)
    assert(h.recovery.owned)
    local r=w:remote("FeralGrabV2");r.OnClientEvent:Fire("begin",{f=1040})
    eq(h.recovery.owned,nil);eq(h.grab.enabled,false);eq(h.grabInput.lease,nil)
    r.OnClientEvent:Fire("strike",{f=1040,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215})
    w:advance(.6);eq(h.recovery.owned,nil);eq(h.grab.presses,0)
    assert(w.cas:GetAllBoundActionInfo().FeralGrabV2Press)
    r.OnClientEvent:Fire("end",{f=1040});w:advance(.1)
    eq(h.recovery.owned,w.player.Character);eq(h.registry.byId.minigame.requested,false)
    h:close()
end)

test("overhaul passive native minigame observation expires and cannot cross character generations",function()
    local w=Mock.new();w.player.Character:SetAttribute("FeralVenomAmt",4)
    local h=load(w,{settings={states={recovery=true,minigame=false}}});w:advance(.1)
    w:remote("FeralGrabV2").OnClientEvent:Fire("begin",{f=1041})
    w:advance(8.2);eq(h:hasNativeGrab(w.time),false);eq(h.recovery.owned,w.player.Character)
    w:remote("FeralGrabV2").OnClientEvent:Fire("begin",{f=1042})
    w:spawn("Bear");eq(h.nativeGrabSession,nil);eq(h:hasNativeGrab(w.time),false)
    h:close()
end)
