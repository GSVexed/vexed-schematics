-- BUNDLE and MOCK_SOURCE are injected verbatim by run_tests.py.
local Mock = assert(loadstring(MOCK_SOURCE))()
local tests,failures = 0,{}
local function test(name,fn)
    tests += 1
    local ok,why = pcall(fn)
    if ok then print("PASS "..name)
    else table.insert(failures,name..": "..tostring(why)); print("FAIL "..name..": "..tostring(why)) end
end
local function eq(a,b)
    assert(a==b,"expected "..tostring(b)..", got "..tostring(a))
end
local function close(a,b) assert(math.abs(a-b)<1e-8,"numbers differ") end
local function load(w,options)
    return assert(w.env.loadstring(BUNDLE))(options)
end
local function modules()
    local w=Mock.new()
    return load(w,{inspect=true}),w
end
local function boot(settings)
    local w=Mock.new()
    local h=load(w,{settings={states=settings or {}}})
    w:step(.02)
    assert(h.active,h.lastError or "not active")
    return w,h
end
local E=Mock.Enum

test("27 features retain the original set, shared combat and Hippo-only controls",function()
    local M=modules();local r=M.core.registry()
    eq(#r.order,27);eq(M.settings.sanitize({},M.core.specs).states.holdBite,true)
    r:request("reach",false);eq(r.byId.reach.requested,true)
    eq(r.byId.recovery.requested,false);r:request("recovery",true);eq(r.byId.effects.requested,true)
    for _,id in ipairs({"territory","hunger","talon","nightVision","performance","diagnostics"}) do eq(r.byId[id],nil) end
end)
test("lease transaction rolls back earlier fields on rejection",function()
    local M=modules();local l=M.core.leases();local first={value=4}
    local locked=table.freeze({value=9})
    local ok=l:apply("a",{{target=first,key="value",value=8,kind="number"},{target=locked,key="value",value=3,kind="number"}})
    eq(ok,false);eq(first.value,4);eq(l.owners.a,nil)
end)
test("lease restores nil and rejects overlapping owners",function()
    local M=modules();local l=M.core.leases();local t={}
    eq(l:apply("a",{{target=t,key="optional",value=true}}),true)
    eq(l:apply("b",{{target=t,key="optional",value=false}}),false)
    l:release("a");eq(t.optional,nil)
end)
test("lease preserves external changes on shutdown",function()
    local M=modules();local l=M.core.leases();local t={x=1}
    l:apply("a",{{target=t,key="x",value=2}});t.x=3;l:close();eq(t.x,3);eq(l.conflicts,1)
end)
test("lease acknowledges equal values and mutation-then-error unwinds",function()
    local M=modules();local l=M.core.leases();local backing={x=1}
    local t=setmetatable({},{
        __index=backing,
        __newindex=function(_,k,v)backing[k]=v;if v==3 then error("mutated then threw")end end,
    })
    eq(l:apply("a",{{target=t,key="x",value=3}}),false);eq(backing.x,1)
    eq(l:apply("b",{{target=t,key="x",value=1}}),true);eq(l:valid("b"),true);l:close()
end)
test("cleanup runs every owner despite one failure and is idempotent",function()
    local M=modules();local s=M.core.scope();local count=0
    s:add(function()count+=1 end);s:add(function()error("broken cleanup")end);s:add(function()count+=1 end)
    s:close();s:close();eq(count,2);eq(#s.errors,1)
end)
test("legacy settings migrate ON and OFF and ignore removed features",function()
    local M=modules();local p=M.settings.sanitize({states={endurance=true,recovery=false,tags=false,nightVision=true,walls=true},range=900},M.core.specs)
    eq(p.states.stamina,true);eq(p.states.recovery,false);eq(p.states.tags,false);eq(p.states.nightVision,nil);eq(p.walls,true);eq(p.range,900)
end)
test("settings reject malformed values and impossible range",function()
    local M=modules();local p=M.settings.sanitize({states={esp="yes",speed=1,leap=false},range=1/0,tab="removed"},M.core.specs)
    eq(p.states.esp,false);eq(p.states.speed,false);eq(p.range,600);eq(p.tab,"Survival")
end)
test("failed settings writes retain previous file and explicit false",function()
    local M=modules();local store={};local blocked=false
    local io={read=function(path)assert(store[path]);return store[path]end,
        write=function(path,value)if blocked then error("disk full")end;store[path]=value;return true end}
    local p=M.settings.sanitize({states={tags=true}},M.core.specs)
    eq(M.settings.save(io,p,M.core.specs),true);blocked=true;p.states.tags=false
    eq(M.settings.save(io,p,M.core.specs),false);eq(store[M.settings.path].states.tags,true)
end)
test("corrupt primary settings fall back to backup",function()
    local M=modules()
    local p,origin=M.settings.load({read=function(path)
        if path==M.settings.path then error("bad JSON")end
        return {schema=15,states={tags=false,esp=true},range=300}
    end},M.core.specs)
    eq(origin,"migrated");eq(p.states.tags,false);eq(p.states.esp,true);eq(p.range,300)
end)
test("boot reconciles every explicit false state and all features have statuses",function()
    local M=modules();local states={}
    for _,spec in ipairs(M.core.specs) do if not spec.permanent and not spec.linked then states[spec[1]]=false end end
    local w,h=boot(states)
    for _,f in ipairs(h.registry.order) do
        if not f.permanent then eq(f.requested,false);eq(f.applied,false) end
        assert(f.state~="" and f.reason~="")
    end
    eq(h.grab.enabled,false);eq(h.recovery.enabled,false);eq(w:count("Highlight"),0)
    h:close();eq(w:connections(),0)
end)
test("all opt-in client features wire together and clean exactly",function()
    local M=modules();local states={}
    for _,spec in ipairs(M.core.specs) do if not spec.permanent and not spec.linked then states[spec[1]]=true end end
    local w,h=boot(states);w:advance(1.5)
    assert(h.active,h.lastError);eq(h.registry.byId.stamina.applied,true);eq(h.registry.byId.effects.applied,true)
    eq(w.configs.NeedsConfig.HEALTH_NO_REGEN_IN_COMBAT,true)
    close(w.configs.StatusConfig.INJURY.HEAL*w.configs.StatusConfig.INJURY.REST_MULT,.45*4)
    h:close();eq(w:connections(),0);close(w.configs.CombatConfig.REACH,1.45)
    close(w.configs.NeedsConfig.STAMINA_REGEN,1.31);eq(w.player.Character:GetAttribute("WolfDbgNoStamina"),nil)
    close(w.configs.JumpLeapConfig.BODY_LENGTHS.Cobra,0)
end)
test("partial GUI attach failure preserves existing hub",function()
    local w=Mock.new();local retired=0
    w.localEnvironment.FERAL_NOVA_PRIME_ACTIVE={close=function()retired+=1 end}
    w.failure="instance:TextLabel"
    local ok=pcall(load,w,{})
    eq(ok,false);eq(retired,0);eq(w:connections(),0);eq(w:count("ScreenGui"),0)
end)
test("late render attach failure unwinds GUI listeners and CAS",function()
    local w=Mock.new();local retired=0
    w.localEnvironment.FERAL_NOVA_PRIME_ACTIVE={close=function()retired+=1 end}
    w.failure="render"
    eq(pcall(load,w,{}),false);eq(retired,0);eq(w:connections(),0);eq(w:count("ScreenGui"),0)
end)
test("stage-only live preflight has no config or remote effects",function()
    local w=Mock.new();local h=load(w,{stageOnly=true,settings={states={recovery=true,stamina=true}}})
    eq(h.ready,true);eq(h.active,false);eq(#w.calls,0);close(w.configs.CombatConfig.REACH,1.45)
    w:advance(.2);eq(#w.calls,0);h:close();eq(w:connections(),0)
end)
test("hot reload closes old controller once and leaves one GUI and scheduler",function()
    local w,h=boot({esp=true,tags=false});w:enemy(2);w:advance(.2)
    local count=w:connections();local oldGUI=h.ui.gui
    local newer=load(w,{settings={states={esp=true,tags=false}}});w:advance(.2)
    eq(h.closed,true);eq(oldGUI._destroyed,true);eq(w:count("ScreenGui"),1)
    eq(w:connections(),count);assert(newer.active,newer.lastError)
    newer:close();eq(w:connections(),0);eq(w:count("Highlight"),0)
end)
test("respawn restores old flag and applies new character once",function()
    local w,h=boot({stamina=true,recovery=true});local old=w.player.Character
    eq(old:GetAttribute("WolfDbgNoStamina"),true);local char=w:spawn("BaldEagle");w:advance(.1)
    eq(old:GetAttribute("WolfDbgNoStamina"),nil);eq(char:GetAttribute("WolfDbgNoStamina"),true)
    eq(h.grab.active,false);eq(h.climbQueue,nil);h:close();eq(w:connections(),0)
end)
test("manual Rest survives recovery disable and shutdown",function()
    local w=Mock.new();w.player.Character:SetAttribute("WolfRest",true);w.hum.Health=80
    local h=load(w,{settings={states={recovery=true}}});w:advance(.2)
    eq(h.policy.manualRest,true);eq(#w.calls,0);h:set("recovery",false);h:close()
    eq(w.player.Character:GetAttribute("WolfRest"),true);eq(#w.calls,0)
end)
test("moving recovery masks only its own echo and releases on first bite",function()
    local w=Mock.new();w.nativeRestEcho=true;w.hum.Health=75;w.hum.MoveDirection=Mock.V3.new(1,0,0)
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    eq(w.player.Character:GetAttribute("WolfRest"),false);eq(h.recovery.owned,w.player.Character)
    w:input(nil,E.UserInputType.MouseButton1)
    eq(h.recovery.owned,nil);eq(h.lastIntent.lock,true)
    local last=w.calls[#w.calls];eq(last.name,"WolfActions");eq(last.args[1],"Rest");eq(last.args[2],false)
    assert(h.policy:restLocked(w.time));w:advance(.72);eq(h.policy:restLocked(w.time),false)
    h:close()
end)
test("holding attack never re-arms recovery or fabricates bite traffic",function()
    local w=Mock.new();w.nativeRestEcho=true;w.hum.Health=60
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w.held=E.UserInputType.MouseButton1;w:input(nil,E.UserInputType.MouseButton1);w:advance(3)
    eq(h.recovery.owned,nil)
    for _,call in ipairs(w.calls) do eq(call.args[1],"Rest") end
    h:close()
end)
test("repeated successfully masked echoes keep recovery active without a false pause",function()
    local w=Mock.new();w.nativeRestEcho=true;w.hum.Health=60
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    for _=1,3 do w.player.Character:SetAttribute("WolfRest",true) end
    eq(h.recovery.owned,w.player.Character);eq(h.recovery.backoffUntil,0)
    eq(w.player.Character:GetAttribute("WolfRest"),false);h:close()
end)

test("the native procedural Rest blend is reset during automatic moving recovery",function()
    local w=Mock.new();w:enableNativePose();w.nativeRestEcho=true;w.hum.Health=60
    w.hum.MoveDirection=Mock.V3.new(1,0,0)
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    eq(w.nativePose.sit,0);eq(w.nativePose.lie,0);eq(w.nativePose.hold,0)
    eq(w.movingRestVisible,false);eq(w.player.Character:GetAttribute("WolfRest"),false)
    assert(w.player.Character:GetAttribute("WolfDbgRestP"));h:close()
    eq(w.player.Character:GetAttribute("WolfDbgRestP"),nil)
end)
test("a late automatic Rest echo stays automatic after the old timeout and disable",function()
    local w=Mock.new();w:enableNativePose();w.nativeRestEcho=true;w.hum.Health=60
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    h:set("recovery",false);w:advance(4)
    w.hum.MoveDirection=Mock.V3.new(1,0,0);w.nativePose.sit,w.nativePose.lie=1,1
    w.player.Character:SetAttribute("WolfRest",true);w:advance(.02)
    eq(h.policy.manualRest,false);eq(w.player.Character:GetAttribute("WolfRest"),false)
    eq(w.nativePose.sit,0);eq(w.nativePose.lie,0);eq(h.ledger.counts.late_owned_rest_echo,1)
    w:advance(.5);eq(w.player.Character:GetAttribute("WolfDbgRestP"),nil)
    eq(h.recovery.owned,nil);h:close()
end)
test("manual Rest keys yield the pose before the lower-priority native action runs",function()
    local w=Mock.new();w.nativeRestEcho=true;w.hum.Health=60
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w.cas:BindActionAtPriority("NativeRest",function(_,state)
        if state==E.UserInputState.Begin then
            eq(w.player.Character:GetAttribute("WolfDbgRestP"),nil)
            w.player.Character:SetAttribute("WolfRest",true)
        end
        return E.ContextActionResult.Sink
    end,false,2000,E.KeyCode.R)
    local calls=#w.calls;w:input(E.KeyCode.R);w:advance(.1)
    eq(h.policy.manualRest,true);eq(h.recovery.owned,nil);eq(#w.calls,calls)
    h:set("recovery",false);h:close();eq(w.player.Character:GetAttribute("WolfRest"),true)
end)
test("native Rest tap intent survives deferred native state without automatic rearming",function()
    local w=Mock.new();w.hum.Health=60
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w.player:SetAttribute("FeralRestTap",w.time);local calls=#w.calls
    w:advance(.3);eq(h.recovery.owned,nil);eq(#w.calls,calls)
    w.player.Character:SetAttribute("WolfRest",true);w:advance(.2)
    eq(h.policy.manualRest,true);eq(w.player.Character:GetAttribute("WolfDbgRestP"),nil);h:close()
end)
test("pose cleanup preserves an external replacement and clears the old animal",function()
    local w=Mock.new();w.hum.Health=60
    local before=Mock.V3.new(.3,.2,1);w.player.Character:SetAttribute("WolfDbgRestP",before)
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    local old=w.player.Character;h:set("recovery",false);w:advance(.5)
    eq(old:GetAttribute("WolfDbgRestP"),before)
    h:set("recovery",true);w:advance(.1)
    local external=Mock.V3.new(.2,.4,2);old:SetAttribute("WolfDbgRestP",external);w:advance(.1)
    eq(old:GetAttribute("WolfDbgRestP"),external);eq(h.recovery.owned,nil)
    w:spawn("Bear");w:advance(.1);eq(old:GetAttribute("WolfDbgRestP"),external);h:close()
end)
test("native downed poses are never suppressed by automatic recovery",function()
    local w=Mock.new();w:enableNativePose();w.hum.Health=60
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w.player.Character:SetAttribute("FeralDowned",true);w:advance(.1)
    eq(h.recovery.owned,nil);eq(w.player.Character:GetAttribute("WolfDbgRestP"),nil)
    assert(w.nativePose.sit>0);h:close()
end)
test("recovery preserves the native 2x HP and 4x condition factors without cosmetic base boosts",function()
    local w,h=boot({recovery=true})
    close(w.configs.NeedsConfig.HEALTH_REGEN,.01);eq(w.configs.NeedsConfig.HEALTH_REST_MULT,2)
    close(w.configs.StatusConfig.INJURY.HEAL,.45);eq(w.configs.StatusConfig.INJURY.REST_MULT,4)
    close(w.configs.StatusConfig.BLEED.CLOT,.2);eq(w.configs.StatusConfig.BLEED.REST_MULT,4)
    close(w.configs.StatusConfig.VENOM.FADE,.3);eq(w.configs.StatusConfig.VENOM.REST_MULT,4)
    eq(w.configs.NeedsConfig.HEALTH_NO_REGEN_IN_COMBAT,true);h:close()
end)
test("unchanged actual HP never becomes a recovery success after native requests",function()
    local w=Mock.new();w.nativeRestEcho=true;w.hum.Health=60
    local h=load(w,{settings={states={recovery=true}}});w:advance(7.5)
    eq(h.recovery.observations.hp.change,0)
    assert(h.registry.byId.recovery.reason:find("no HP rise observed",1,true))
    eq(h.registry.byId.recovery.outcome,"unverified");h:close()
end)
test("actual HP progress is distinct from a confirmed 2x multiplier",function()
    local w=Mock.new();w.hum.Health=60
    local h=load(w,{settings={states={recovery=true}}});w:advance(.5)
    w.hum.Health=61;w:advance(.4)
    assert(h.recovery.observations.hp.change>0)
    assert(h.registry.byId.recovery.reason:find("HP rising",1,true))
    assert(h.registry.byId.recovery.reason:find(string.format("%.2f/s; 2× unverified",h.recovery.observations.hp.rate),1,true))
    w.player:SetAttribute("FeralCombatUntil",w.time+1100);w:advance(.5)
    eq(h.recovery.owned,nil);eq(h.recovery.observations.hp,nil);h:close()
end)
test("condition progress is measured independently and missing amounts are not cures",function()
    local w=Mock.new();w.player.Character:SetAttribute("FeralInjury",4)
    w.player.Character:SetAttribute("FeralBleed",3);w.player.Character:SetAttribute("FeralVenomAmt",2)
    local h=load(w,{settings={states={recovery=true}}});w:advance(.6)
    w.player.Character:SetAttribute("FeralInjury",3);w.player.Character:SetAttribute("FeralVenomAmt",nil);w:advance(.4)
    eq(h.recovery.observations.injury.change,1);eq(h.recovery.observations.bleed.change,0)
    eq(h.recovery.observations.venom,nil);eq(h.registry.byId.effects.outcome,"unverified");h:close()
end)
test("hot reload carries automatic Rest provenance without inheriting manual Rest ownership",function()
    local w=Mock.new();w.hum.Health=60;w.nativeRestEcho=true
    local previous=load(w,{settings={states={recovery=true}}});w:advance(.1)
    assert(previous.recovery.owned);w.hum.Health=100
    local h=load(w,{settings={states={recovery=true}}});w:advance(3.5)
    w.player.Character:SetAttribute("WolfRest",true);w:advance(.1)
    eq(h.policy.manualRest,false);eq(w.player.Character:GetAttribute("WolfRest"),false)
    eq(previous.closed,true);h:close()
end)
test("an unavailable pose setter does not issue automatic Rest or leak a partial override",function()
    local w=Mock.new();w.hum.Health=60
    local h=load(w,{stageOnly=true,settings={states={recovery=true}}})
    local original=h.bridge.setAttribute
    h.bridge.setAttribute=function(self,char,key,value)
        local applied=original(self,char,key,value)
        return key~="WolfDbgRestP" and applied
    end
    h:activate();w:advance(.2)
    eq(h.recovery.owned,nil);eq(w.player.Character:GetAttribute("WolfDbgRestP"),nil)
    eq(#w.calls,0);h:close()
end)
test("holding the camera mouse button never suppresses out-of-combat recovery",function()
    local w=Mock.new();w.nativeRestEcho=true;w.hum.Health=60
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w.held=E.UserInputType.MouseButton2;w:input(nil,E.UserInputType.MouseButton2);w:advance(7)
    eq(h.recovery.owned,w.player.Character);eq(h.snapshot.attackHeld,false)
    eq(h.ledger.counts.attack_intent,nil)
    for _,call in ipairs(w.calls) do
        if call.args[1]=="Rest" then eq(call.args[2],true) end
    end
    w.hum.Health=100;w:advance(.1);eq(h.recovery.owned,nil)
    w.hum.Health=80;w:advance(.1);eq(h.recovery.owned,w.player.Character);h:close()
end)
test("gamepad R2 still releases recovery before the original native bite",function()
    local w=Mock.new();w:enableNativeActions();w.nativeRestEcho=true;w.hum.Health=60
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w:input(E.KeyCode.ButtonR2,E.UserInputType.Gamepad1)
    eq(h.recovery.owned,nil);eq(h.ledger.counts.attack_intent,1)
    w:advance(.9);eq(w.nativeBites,1);eq(h.ledger.counts.native_bite_buffer_released,1);h:close()
end)
test("no recovery deficit sends no priming Rest requests",function()
    local w,h=boot({recovery=true});w:advance(3)
    eq(#w.calls,0);eq(h.recovery.owned,nil);h:close()
end)
test("combat and feeding preempt owned recovery",function()
    local w=Mock.new();w.hum.Health=50;local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    assert(h.recovery.owned);w.player:SetAttribute("FeralCombatUntil",w.time+1003);w:advance(.1);eq(h.recovery.owned,nil)
    w.player:SetAttribute("FeralCombatUntil",0);w.player.Character:SetAttribute("WolfFeed","drink");w:advance(.1);eq(h.recovery.owned,nil)
    h:close()
end)
test("nearby same-pack target alone does not cancel recovery",function()
    local w=Mock.new();w:enemy(1);w.hum.Health=50
    local h=load(w,{settings={states={recovery=true,biteHelper=true}}});w:advance(.3)
    eq(h.recovery.owned,w.player.Character);eq(h.guide,nil);h:close()
end)
test("native bite marker is distinct from sent claim and damage evidence",function()
    local w,h=boot({biteHelper=true});local _,_,hum=w:enemy(2);w:advance(.2)
    w:input(nil,E.UserInputType.MouseButton1);w.player.Character:SetAttribute("WolfBiteAt",1011)
    w:advance(.3);hum.Health=90;w:advance(.9)
    eq(h.ledger.counts.native_bite_marker,1);eq(h.ledger.counts.target_hp_decline_correlated,1)
    for _,c in ipairs(w.calls) do assert(c.args[1]~="BiteHit" and c.args[1]~="Bite") end
    h:close()
end)
test("missing status is excluded from condition cure measurements",function()
    local M=modules();local l=M.core.ledger(3);local char={}
    l:sample({char=char,now=1,maxHP=100,hp=50,injury=4,combat=false,moving=true},"NO_SIGNAL")
    l:sample({char=char,now=1.5,maxHP=100,hp=51,injury=nil,combat=false,moving=true},"NO_SIGNAL")
    local bucket=l.rates["NO_SIGNAL:false:moving"]
    eq(bucket.effects.injury,nil)
    for i=1,8 do l:event("x",i) end;eq(#l.events,3);eq(l.counts.x,8)
end)
test("rate windows exclude combat and movement transitions",function()
    local M=modules();local l=M.core.ledger();local char={}
    l:sample({char=char,now=1,maxHP=100,hp=50,combat=false,moving=false},"NO_SIGNAL")
    l:sample({char=char,now=1.4,maxHP=100,hp=52,combat=true,moving=false},"NO_SIGNAL")
    eq(next(l.rates),nil)
end)
test("native Grab V2 res grades require own matching session and strike",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    assert(g:event("begin",{f=1},100,1,.32,2.5))
    assert(g:event("strike",{f=1,k=1,t0=100,spd=1,from=0,zc=.5,zw=.215,dur=2},100,1,.32,2.5))
    eq(g:event("res",{f=1,k=1,mine=false,tier="perfect"},100.5,1,.32,2.5),false)
    assert(g:event("res",{f=1,k=1,mine=true,tier="perfect"},100.5,1,.32,2.5))
    eq(g.grades.perfect,1)
    eq(g:event("res",{f=1,k=1,mine=true,tier="perfect"},100.5,1,.32,2.5),false)
    eq(g.grades.perfect,1)
end)
test("Grab duplicate strike cannot send a second press",function()
    local M=modules();local g=M.grab.new();g.enabled=true;g:event("begin",{f=1},100,1,.32,2.5)
    local packet={f=1,k=1,t0=100,spd=1,from=0,zc=.5,zw=.215,dur=2}
    g:event("strike",packet,100,1,.32,2.5);local sent=0
    g:tick(100.5,1,true,function(session,_,timestamp)eq(session,1);eq(timestamp,100.5);sent+=1;return true end)
    eq(sent,1);eq(g:event("strike",packet,100.6,1,.32,2.5),false)
    g:tick(101.5,1,true,function()sent+=1;return true end);eq(sent,1)
end)
test("Grab rejects practice, stale session, future clock and respawn",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    eq(g:event("begin",{f=-1},100,1,.32,2.5),false);eq(M.grab.validId("-2"),false);eq(M.grab.validId("0"),false)
    g:event("begin",{f=2},100,1,.32,2.5)
    eq(g:event("end",{f=1},100,1,.32,2.5),false);eq(g.active,true)
    eq(g:event("strike",{f=2,k=1,t0=104,spd=1,from=0,zc=.5,zw=.215,dur=2},100,1,.32,2.5),false)
    g:tick(100.5,2,true,function()error("stale input sent")end);eq(g.active,false)
end)
test("Grab manual takeover and unavailable clock send no input",function()
    local w,h=boot({minigame=true});local remote=w:remote("FeralGrabV2")
    local at=w.time+1000
    remote.OnClientEvent:Fire("begin",{f=9})
    remote.OnClientEvent:Fire("strike",{f=9,k=1,t0=at,spd=1,from=0,zc=.5,zw=.215,dur=2})
    assert(h.grab.pending);w:input(E.KeyCode.Space);w:advance(.8)
    for _,c in ipairs(w.calls) do assert(c.name~="FeralGrabV2") end
    h:close()
end)
test("minigame priority cancels recovery and legacy escape",function()
    local w=Mock.new();w.hum.Health=50;w.nativeShake=true
    local h=load(w,{settings={states={minigame=true,recovery=true,escape=true}}});w:advance(.1)
    w.player.Character:SetAttribute("FeralPinned",true)
    w:remote("FeralGrabV2").OnClientEvent:Fire("begin",{f=5});w:advance(.2)
    eq(h.recovery.owned,nil)
    for _,c in ipairs(w.calls) do assert(c.name~="FeralLunge") end
    h:close()
end)
test("climb buffer expires, honours Dive and never sends a climb remote",function()
    local w,h=boot({climb=true})
    w.player.Character:SetAttribute("DiveCan",true);w:input(E.KeyCode.Q);eq(h.climbQueue,nil)
    w.player.Character:SetAttribute("DiveCan",false);w:input(E.KeyCode.Q);assert(h.climbQueue)
    w:advance(2.4);eq(h.climbQueue,nil)
    for _,c in ipairs(w.calls) do assert(c.name~="FeralClimb") end
    h:close()
end)
test("climb waits for native handling and retries at most once",function()
    local w,h=boot({climb=true});w.player.Character:SetAttribute("ClimbCan",true)
    w:input(E.KeyCode.Q);eq(w.player:GetAttribute("FeralClimbTap"),nil)
    w:advance(1.8);eq(h.ledger.counts.native_climb_tap,2);h:close()
end)
test("native mount after Q avoids duplicate assisted tap",function()
    local w,h=boot({climb=true});w.player.Character:SetAttribute("ClimbCan",true)
    w:input(E.KeyCode.Q);w.player.Character:SetAttribute("FeralClimbLocal",true);w:advance(.2)
    eq(w.player:GetAttribute("FeralClimbTap"),nil);eq(h.ledger.counts.native_climb_mounted,1);h:close()
end)
test("surface takeoff is temporary and deep water never enables flight",function()
    local w=Mock.new();w:spawn("BaldEagle");w.waterY=3;w.player.Character:SetAttribute("FeralSwimLocal",true)
    local h=load(w,{settings={states={flight=true}}});w:step(.02)
    eq(h:requestFlight(),true);eq(w.configs.FlightConfig.WATER.NO_TAKEOFF,false)
    w.player.Character:SetAttribute("FeralUnderwater",true);w:advance(.3)
    eq(w.configs.FlightConfig.WATER.NO_TAKEOFF,true);eq(h:requestFlight(),false);h:close()
end)
test("flight disable and shutdown restore original water permission",function()
    local w=Mock.new();w:spawn("BaldEagle");w.waterY=3;w.player.Character:SetAttribute("FeralSwimLocal",true)
    local h=load(w,{settings={states={flight=true}}});w:step(.02);assert(h:requestFlight())
    h:set("flight",false);eq(w.configs.FlightConfig.WATER.NO_TAKEOFF,true);h:close()
end)
test("friendly baby carry is protected but pinning immediately wins",function()
    local w,h=boot({escape=true});local baby=w.player.Character;baby:SetAttribute("Growth",.2)
    local p,adult=w:enemy(1);adult:SetAttribute("Growth",.8)
    local clamp=w.new("ObjectValue");clamp.Name="FeralClamp";clamp.Value=baby;clamp.Parent=adult
    baby:SetAttribute("FeralCarried",true);w:advance(.3)
    for _,c in ipairs(w.calls) do assert(c.name~="FeralLunge") end
    baby:SetAttribute("FeralPinned",true);w:advance(.7)
    eq(h.ledger.counts.native_escape_requested,2);h:close()
end)
test("idle API failure remains unavailable instead of pcall-only ON",function()
    local w,h=boot({robloxAFK=true});w.idleBlocked=true;h:idle();w:advance(.3)
    eq(h.registry.byId.robloxAFK.applied,false);eq(h.registry.byId.robloxAFK.state,"UNAVAILABLE")
    h:close();local pulses=w.idlePulses or 0;w.player.Idled:Fire(121);eq(w.idlePulses or 0,pulses)
end)
test("survival AFK no unsolicited movement; danger and manual input stop walk",function()
    local w,h=boot({survivalAFK=true});h.ui:toggle();w:advance(20);eq(h.walk,nil)
    w:advance(72);assert(h.walk,h.walkStatus or "no walk")
    w:input(E.KeyCode.W);eq(h.walk,nil);local oldGoal=w.hum.goal
    w:advance(91);assert(h.walk,h.walkStatus or "no second walk")
    local _,_,_,root=w:enemy(2);w.parts={root};w:advance(.3);eq(h.walk,nil)
    h:close();eq(w:connections(),0)
end)
test("AFK route checks intermediate ground rather than only endpoints",function()
    local w,h=boot({survivalAFK=true});h.ui:toggle();w.hole=true;w.blocked=true;w:advance(91)
    eq(h.walk,nil);eq(h.walkStatus,"no safe ground step");h:close()
end)
test("manual mouse control is never swallowed after virtual idle pulse",function()
    local w,h=boot({robloxAFK=true,survivalAFK=true});h.ui:toggle();w:advance(91);assert(h.walk)
    h:idle();w:input(E.KeyCode.W);eq(h.walk,nil);h:close()
end)
test("hollow ESP and tags OFF persist across tracking refresh and respawn",function()
    local w,h=boot({esp=true,tags=false,biteHelper=true});local p,char=w:enemy(2);w:advance(.3)
    local rec=h.ui.records[char];assert(rec);eq(rec.highlight.FillTransparency,1);eq(rec.label.Visible,false)
    w.blocked=true;w:advance(.3);assert(h.active,h.lastError)
    h:set("tags",true);w:advance(.1);eq(rec.label.Visible,true)
    h:set("tags",false);w:spawn("Wolf");w:advance(.3)
    eq(rec.label.Visible,false);eq(rec.highlight.FillTransparency,1);h:close()
end)
test("hollow ESP follows current health while names retain pack hue without numeric metadata",function()
    local w,h=boot({esp=true,tags=true});local p,char,hum=w:enemy(2);hum.Health=20;w:advance(.3)
    local rec=h.ui.records[char];local colour=rec.highlight.OutlineColor
    eq(colour.R,1);close(colour.G,.4);eq(rec.label.TextColor3.R,236/255)
    eq(rec.health,nil);eq(rec.label.Text,"Other");eq(rec.highlight.FillTransparency,1)
    hum.Health=100;w:advance(.1);eq(rec.highlight.OutlineColor.R,0);eq(rec.highlight.OutlineColor.G,1)
    p:SetAttribute("FeralPack",1);w:advance(.3);eq(rec.label.TextColor3.G,219/255)
    p:SetAttribute("FeralPack",nil);w:advance(.3);eq(rec.label.TextColor3.R,236/255);eq(rec.label.TextColor3.G,181/255)
    hum.MaxHealth=math.huge;w:advance(.1);eq(rec.highlight.OutlineColor.R,151/255);assert(h.active)
    h:close()
end)
test("streaming and finder limit bound local records to 24",function()
    local w,h=boot({esp=true,tags=true})
    for i=1,32 do w:enemy(2,Mock.V3.new(i,3,-20)) end
    w:advance(.3);local n=0;for _ in pairs(h.ui.records)do n+=1 end;eq(n,24)
    for _,p in ipairs(w.env.game:GetService("Players"):GetPlayers()) do if p~=w.player then p.Character.Parent=nil end end
    w:advance(.3);eq(next(h.ui.records),nil);eq(w:count("Highlight"),0);h:close()
end)
test("Right Shift has one menu binding and respects focused text",function()
    local w,h=boot();local visible=h.ui.visible
    w:input(E.KeyCode.RightShift);eq(h.ui.visible,not visible)
    w.chat={};w:input(E.KeyCode.RightShift);eq(h.ui.visible,not visible);w.chat=nil
    h:close();eq(next(w.bindings),nil)
end)
test("external config conflict fails visibly and restores unrelated fields",function()
    local w,h=boot({speed=true});w.configs.NeedsConfig.RUN_SPEED=1.7;w:advance(1.4)
    eq(h.registry.byId.speed.applied,false);eq(h.registry.byId.speed.state,"UNAVAILABLE")
    close(w.configs.NeedsConfig.RUN_SPEED,1.7);close(w.configs.NeedsConfig.SWIM_SPEED,1)
    h:close()
end)
test("cleanup continues when a controller throws",function()
    local w,h=boot({stamina=true});h.recovery.close=function()error("broken owner")end
    h:close();eq(w:connections(),0);eq(w:count("ScreenGui"),0)
    close(w.configs.NeedsConfig.STAMINA_REGEN,1.31);eq(#h.cleanupErrors,1)
end)
test("ordinary Rest renewal does not accumulate recurrence failures",function()
    local w=Mock.new();w.nativeRestEcho=true;w.hum.Health=50
    local h=load(w,{settings={states={recovery=true}}});w:advance(17)
    eq(h.recovery.owned,w.player.Character);eq(h.recovery.backoffUntil,0);assert(h.ledger.counts.native_rest_renewed>=3)
    h:close()
end)
test("streamed replacement config releases stale table and patches current one",function()
    local w,h=boot({speed=true});local old=w.configs.NeedsConfig
    w.rs:FindFirstChild("FeralWorld"):FindFirstChild("NeedsConfig"):Destroy()
    local replacement=table.clone(old);replacement.RUN_SPEED=1;replacement.SWIM_SPEED=1
    w:addConfig("NeedsConfig",replacement);w:advance(1.4)
    close(old.RUN_SPEED,1);close(replacement.RUN_SPEED,1.15);eq(h.registry.byId.speed.applied,true);h:close()
    close(replacement.RUN_SPEED,1)
end)
test("runtime error closes owned loops and restores all patches",function()
    local w,h=boot({speed=true,stamina=true});h.ui.render=function()error("injected render failure")end
    w:step(.02);eq(h.closed,true);eq(w:connections(),0);close(w.configs.NeedsConfig.RUN_SPEED,1)
    eq(w:count("ScreenGui"),0)
end)
test("shutdown makes public action entry points inert",function()
    local w,h=boot({stamina=true,robloxAFK=true,minigame=true})
    h:close();local calls,pulses=#w.calls,w.idlePulses or 0
    eq(h:set("speed",true),false);h:idle();h:tick()
    h:nativeEvent("grab","begin",{f=5})
    eq(#w.calls,calls);eq(w.idlePulses or 0,pulses);eq(h.grab.active,false)
end)
test("clicking hub controls never counts as an attack intent",function()
    local w,h=boot({recovery=true})
    w.uis.GetMouseLocation=function()return Mock.V2.new(100,100)end
    w:input(nil,E.UserInputType.MouseButton1)
    eq(h.ledger.counts.attack_intent,nil);h:close()
end)
test("staging in the same clock tick never replaces active render or input owners",function()
    local w,h=boot();local count=w:connections()
    local staged=load(w,{stageOnly=true,settings={states={}}})
    assert(staged.token~=h.token);eq(h.active,true)
    staged:close();eq(w:connections(),count)
    local visible=h.ui.visible;w:input(E.KeyCode.RightShift);eq(h.ui.visible,not visible)
    h:close();eq(w:connections(),0)
end)
test("bite clicks keep native bites and automatic minigame presses independent",function()
    local w=Mock.new();w:enableNativeGrab()
    local h=load(w,{settings={states={minigame=true,recovery=true}}});w:step(.02)
    local remote=w:remote("FeralGrabV2");local at=w.time+1000
    remote.OnClientEvent:Fire("begin",{f=21,role="prey",n=3})
    remote.OnClientEvent:Fire("strike",{f=21,k=1,t0=at,spd=1,from=0,zc=.5,zw=.215})
    assert(h.grabInput.lease);eq(w.cas:GetAllBoundActionInfo().FeralGrabV2Press,nil)
    w:advance(.12);w:input(nil,E.UserInputType.MouseButton1)
    eq(w.nativeBites,1);eq(w.nativeManualPresses,nil);assert(h.grab.pending)
    w:advance(.45);eq(h.grab.presses,1);eq(w.nativeManualPresses,nil)
    eq(h.ledger.counts.native_bite_marker,1);eq(w.nativeGrabState().strike.pressed,true)
    h:close();assert(w.cas:GetAllBoundActionInfo().FeralGrabV2Press)
end)
test("three attackers and repeated attack clicks cannot cancel or duplicate a strike",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:step(.02)
    local r=w:remote("FeralGrabV2");local at=w.time+1000
    r.OnClientEvent:Fire("begin",{f=22,role="prey",n=1})
    r.OnClientEvent:Fire("strike",{f=22,k=1,t0=at,spd=1,from=0,zc=.5,zw=.215})
    for count=1,3 do
        r.OnClientEvent:Fire("n",{f=22,n=count})
        w:input(nil,E.UserInputType.MouseButton1);w:advance(.08)
    end
    eq(h.grab.hunters,3);assert(h.grab.pending);eq(w.nativeBites,3)
    w:advance(.4);eq(h.grab.presses,1);eq(w.nativeManualPresses,nil)
    r.OnClientEvent:Fire("n",{f=22,n=2});eq(h.grab.active,true);eq(h.grab.presses,1);h:close()
end)
test("native minigame input binding restores exactly on disable without restarting the fight",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:step(.02)
    local r=w:remote("FeralGrabV2");local at=w.time+1000
    r.OnClientEvent:Fire("begin",{f=23,role="prey"})
    r.OnClientEvent:Fire("strike",{f=23,k=1,t0=at,spd=1,from=0,zc=.5,zw=.215})
    eq(w.cas:GetAllBoundActionInfo().FeralGrabV2Press,nil)
    h:set("minigame",false)
    local binding=w.cas:GetAllBoundActionInfo().FeralGrabV2Press
    assert(binding);eq(binding.priorityLevel,3000);eq(#binding.inputTypes,4)
    w:input(nil,E.UserInputType.MouseButton1);eq(w.nativeManualPresses,1);eq(w.nativeBites,nil)
    h:close();assert(w.cas:GetAllBoundActionInfo().FeralGrabV2Press)
end)
test("native Space takeover sends one native press and the automated press stops",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:step(.02)
    local r=w:remote("FeralGrabV2");local at=w.time+1000
    r.OnClientEvent:Fire("begin",{f=24,role="prey"})
    r.OnClientEvent:Fire("strike",{f=24,k=1,t0=at,spd=1,from=0,zc=.5,zw=.215})
    w:advance(.2);w:input(E.KeyCode.Space);eq(w.nativeManualPresses,1);eq(h.grab.pending,nil)
    w:advance(.6);eq(h.grab.presses,0);eq(w.nativeManualPresses,1)
    h:close()
end)
test("enabling automation halfway through a native session adopts only its genuine strike",function()
    local w=Mock.new();w:enableNativeGrab()
    local r=w:remote("FeralGrabV2");local at=w.time+1000
    r.OnClientEvent:Fire("begin",{f=25,role="prey",n=3})
    r.OnClientEvent:Fire("strike",{f=25,k=1,t0=at,spd=1,from=0,zc=.5,zw=.215})
    local h=load(w,{settings={states={minigame=true}}});w:step(.02)
    eq(h.grab.session,25);eq(h.grab.hunters,3);assert(h.grab.pending);eq(h.grab.nativeResumes,1)
    w:advance(.6);eq(h.grab.presses,1);h:close()
end)
test("a stale native UI state cannot migrate to a respawned animal",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:step(.02)
    local r=w:remote("FeralGrabV2");local at=w.time+1000
    r.OnClientEvent:Fire("begin",{f=26,role="prey"})
    r.OnClientEvent:Fire("strike",{f=26,k=1,t0=at,spd=1,from=0,zc=.5,zw=.215})
    w:spawn("Wolf");w:advance(.7);eq(h.grab.active,false);eq(h.grab.presses,0);h:close()
end)
test("native bite cleanup cancels an old strike even if the observer missed its bite packet",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:step(.02)
    local r=w:remote("FeralGrabV2");local at=w.time+1000
    r.OnClientEvent:Fire("begin",{f=32,role="prey"})
    r.OnClientEvent:Fire("strike",{f=32,k=1,t0=at,spd=1,from=0,zc=.5,zw=.215})
    assert(h.grab.pending)
    local native=w.nativeGrabState();native.strike=nil;native.biteUntil=w.time+.6
    w:advance(.7);eq(h.grab.pending,nil);eq(h.grab.presses,0)
    r.OnClientEvent:Fire("strike",{f=32,k=2,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215})
    w:advance(.6);eq(h.grab.presses,1);h:close()
end)
test("closing an active minigame owner restores working native manual input",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:step(.02)
    local r=w:remote("FeralGrabV2");local at=w.time+1000
    r.OnClientEvent:Fire("begin",{f=33,role="prey"})
    r.OnClientEvent:Fire("strike",{f=33,k=1,t0=at,spd=1,from=0,zc=.5,zw=.215})
    local owner=h.grabInput.name;assert(w.bindings[owner]);h:close()
    eq(w.bindings[owner],nil);assert(w.cas:GetAllBoundActionInfo().FeralGrabV2Press)
    w:input(E.KeyCode.Space);eq(w.nativeManualPresses,1);w:advance(.6);eq(h.grab.presses,0)
end)
test("missing executor introspection is reported as partial minigame support",function()
    local w=Mock.new();w:enableNativeGrab();w.env.getconnections=nil
    local h=load(w,{settings={states={minigame=true}}});w:step(.02)
    local r=w:remote("FeralGrabV2")
    r.OnClientEvent:Fire("begin",{f=34,role="prey"});w:advance(.4)
    eq(h.grabInput.lease,nil);eq(h.registry.byId.minigame.state,"PARTIAL")
    eq(h.ui.rows.minigame.toggle.Text,"PARTIAL")
    assert(w.cas:GetAllBoundActionInfo().FeralGrabV2Press);h:close()
end)
test("bounded callback discovery resumes beyond unrelated connections without a heap scan",function()
    local w=Mock.new();w:enableNativeGrab()
    local original=w.env.getconnections;local calls=0
    w.env.getconnections=function(event)
        calls+=1;local pool={}
        if event==w.uis.InputBegan then
            for i=1,60 do pool[i]={Function=function()return i end} end
        end
        for _,connection in ipairs(original(event))do table.insert(pool,connection)end
        return pool
    end
    w.env.getgc=function()error("heap scan")end
    local h=load(w,{settings={states={minigame=true}}});w:advance(.8)
    assert(calls<=3);assert(h.bridge.grabController);eq(h.bridge.grabDiscovery,nil)
    w:remote("FeralGrabV2").OnClientEvent:Fire("begin",{f=35,role="prey"})
    assert(h.grabInput.lease);h:close()
end)
test("missing the first timing crossing reschedules the next valid crossing",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    g:event("begin",{f=27},100,1,.32,2.5)
    g:event("strike",{f=27,k=1,t0=100,spd=1,from=0,zc=.5,zw=.215},100,1,.32,2.5)
    g:tick(100.7,1,true,function()error("off-centre press")end);assert(g.pending)
    eq(g.retimed,1);close(g.pending.at,101.5-.215*.5*.32*.88)
    local sent=0;g:tick(101.5,1,true,function(_,_,now)eq(now,101.5);sent+=1;return true end)
    eq(sent,1);eq(g.grades.perfect,0)
end)
test("transient input focus retains timing without pressing into text",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    g:event("begin",{f=28},100,1,.32,2.5)
    g:event("strike",{f=28,k=1,t0=100,spd=1,from=0,zc=.5,zw=.215},100,1,.32,2.5)
    g:tick(100.2,1,false,function()error("pressed into text")end);assert(g.pending)
    local sent=0;g:tick(100.5,1,true,function()sent+=1;return true end);eq(sent,1)
end)
test("late old strikes do not replace the current multi-attacker strike",function()
    local M=modules();local g=M.grab.new();g.enabled=true;g:event("begin",{f=29},100,1,.32,2.5)
    g:event("strike",{f=29,k=3,t0=100,spd=1,from=0,zc=.5,zw=.215},100,1,.32,2.5)
    eq(g:event("strike",{f=29,k=2,t0=100,spd=1,from=0,zc=.5,zw=.215},100,1,.32,2.5),false)
    eq(g.pending.strike,3)
end)
test("own-character native grades are accepted without confusing another hunter's grade",function()
    local M=modules();local g=M.grab.new();g.enabled=true;local char={}
    g:event("begin",{f=30},100,1,.32,2.5)
    g:event("strike",{f=30,k=1,t0=100,spd=1,from=0,zc=.5,zw=.215},100,1,.32,2.5)
    eq(g:event("res",{f=30,k=1,c={},tier="miss"},100.5,1,.32,2.5,{character=char}),false)
    eq(g:event("res",{f=30,k=1,c=char,tier="good"},100.5,1,.32,2.5,{character=char}),true)
    eq(g.grades.good,1);eq(g.grades.miss,0)
end)
test("condition recovery can request native Rest during a combat tag while HP stays excluded",function()
    local w=Mock.new();w.player:SetAttribute("FeralCombatUntil",w.time+1100)
    w.player.Character:SetAttribute("FeralBleed",3);w.hum.Health=50
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    eq(h.recovery.owned,w.player.Character);eq(h.recovery.purpose,"effects")
    eq(w.configs.NeedsConfig.HEALTH_NO_REGEN_IN_COMBAT,true)
    w.held=E.UserInputType.MouseButton1;w:input(nil,E.UserInputType.MouseButton1);w:advance(.2)
    eq(h.recovery.owned,nil);h:close()
end)
test("active grabs still preempt condition Rest and preserve ordinary attack timing",function()
    local w,h=boot({recovery=true,minigame=true})
    w.player.Character:SetAttribute("FeralVenomAmt",4);w:advance(.1);assert(h.recovery.owned)
    w:remote("FeralGrabV2").OnClientEvent:Fire("begin",{f=31,role="prey",n=3})
    w:advance(.2);eq(h.recovery.owned,nil);eq(h.grab.active,true);h:close()
end)
test("client targeting covers an exactly rear target without rotating the character",function()
    local w,h=boot({biteHelper=true});local look=w.root.CFrame.LookVector
    local _,char=w:enemy(2,Mock.V3.new(0,3,7));w:advance(.2)
    assert(h.guide);eq(h.guide.target.char,char);eq(h.guide.baseline.valid,false);eq(h.guide.extended.valid,true)
    eq(w.root.CFrame.LookVector,look);eq(h.bridge.reachTarget.char,char);h:close()
end)
test("expanded client targeting reaches further and higher with exact rollback",function()
    local w,h=boot({biteHelper=true})
    local _,char=w:enemy(2,Mock.V3.new(0,10,-6));w:advance(.2)
    assert(h.guide);eq(h.guide.target.char,char);eq(h.guide.baseline.valid,false);eq(h.guide.extended.valid,true)
    close(w.configs.CombatConfig.CONE,170);h:close()
    close(w.configs.CombatConfig.CONE,71);eq(w.configs.CombatConfig.coneFor,nil)
end)
test("rear assist ignores same-pack and protected targets",function()
    local w,h=boot({biteHelper=true});local p,friend=w:enemy(1,Mock.V3.new(0,3,5))
    local p2,protected=w:enemy(2,Mock.V3.new(0,3,6))
    local shield=w.new("ForceField");shield.Parent=protected
    w:advance(.2);eq(h.bridge.reachTarget,nil);h:close()
end)

test("ESP and tags remain real-player only even for pack NPCs and copied player names",function()
    local w,h=boot({esp=true,tags=true});local npc=w:npc(1,Mock.V3.new(0,3,-2),true)
    npc:SetAttribute("FeralName","Other");local _,char=w:enemy(2)
    w:advance(.3);eq(h.ui.records[npc],nil);assert(h.ui.records[char]);eq(#h.bridge.tracked,1)
    eq(h.bridge.packNPCCount,1);h:close()
end)
test("actual player ownership wins over NPC attributes and a litter Body reference",function()
    local w,h=boot({esp=true,tags=true});local npc,_,_,record=w:npc(1,Mock.V3.new(0,3,-2),true)
    local player,char=w:enemy(2);char:SetAttribute("FeralNPC",true)
    record:FindFirstChild("Body").Value=char;npc:Destroy()
    w:advance(.3);eq(#h.bridge.tracked,1);eq(h.bridge.tracked[1].player,player)
    eq(h.ui.records[char].label.Text,"Other");h:close()
end)
test("litter membership protects friendly NPCs without changing the player-only renderer",function()
    local w,h=boot({esp=true,biteHelper=true});local npc=w:npc(1,Mock.V3.new(0,3,-2),true)
    npc:SetAttribute("FeralPack",nil);w:advance(.3)
    eq(h.bridge:affiliation(nil,npc),"same");eq(w.configs.CombatConfig.bodyGap(npc:FindFirstChild("HumanoidRootPart"),Mock.V3.new(0,0,-2)),math.huge)
    eq(h.bridge.reachTarget,nil);eq(h.ui.records[npc],nil);h:close()
end)
test("native client selection skips a protected target and keeps a valid target",function()
    local w,h=boot({biteHelper=true});local _,safe,_,safeRoot=w:enemy(2,Mock.V3.new(0,3,-2))
    safe:SetAttribute("FeralSafeUntil",w.time+1100)
    local _,valid=w:enemy(2,Mock.V3.new(0,3,-5));w:advance(.2)
    eq(w.configs.CombatConfig.bodyGap(safeRoot,Mock.V3.new(0,0,-2)),math.huge)
    eq(h.guide.target.char,valid)
    safe:SetAttribute("FeralSafeUntil",0)
    assert(w.configs.CombatConfig.bodyGap(safeRoot,Mock.V3.new(0,0,-2))<math.huge)
    h:close()
end)
test("geometry reads current positions between tracking scans",function()
    local w,h=boot({biteHelper=true});local _,char,hum,root=w:enemy(2,Mock.V3.new(0,3,-4));w:advance(.2)
    local target=h.guide.target;assert(h.guide.extended.valid)
    root.Position=Mock.V3.new(0,3,-40)
    local geometry=h.bridge:geometry(h.features.combat,h.snapshot,target)
    eq(geometry.valid,false);close(geometry.distance,40);h:close()
end)
test("one bite after owned Rest is buffered through the original native tryBite",function()
    local w=Mock.new();w:enableNativeActions();w.hum.Health=50
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1);assert(h.recovery.owned)
    w:input(nil,E.UserInputType.MouseButton1);eq(w.nativeBites,nil);assert(h.combatInput.pending)
    w:advance(.85);eq(w.nativeBites,1);eq(h.combatInput.pending,nil)
    eq(h.ledger.counts.native_bite_buffer_released,1);eq(h.recovery.owned,nil)
    local bites=0;for _,call in ipairs(w.calls)do if call.name=="WolfActions" and call.args[1]=="Bite" then bites+=1 end end
    eq(bites,1);h:close()
end)
test("the Rest-exit bite buffer respects native capture and cancels on respawn",function()
    local w=Mock.new();w:enableNativeActions();w.hum.Health=50
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w:input(nil,E.UserInputType.MouseButton1);w.player.Character:SetAttribute("FeralPinned",true)
    w:advance(.9);eq(w.nativeBites,nil);eq(h.combatInput.pending,nil)
    w.player.Character:SetAttribute("FeralPinned",false);h.policy.lastRestRelease=w.time
    w:input(nil,E.UserInputType.MouseButton1);w:spawn("Wolf");w:advance(.9)
    eq(h.combatInput.pending,nil);h:close()
end)
test("a manual feeding action cancels a queued bite",function()
    local w=Mock.new();w:enableNativeActions();w.hum.Health=50
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w:input(nil,E.UserInputType.MouseButton1);w.player.Character:SetAttribute("FeedCan","drink")
    w:input(E.KeyCode.E);w:advance(.9);eq(w.nativeBites,nil);eq(h.combatInput.pending,nil)
    eq(w.nativeFeedMode(),"drink");h:close()
end)
test("native feeding approach longer than the old action pause keeps Rest released",function()
    local w=Mock.new();w:enableNativeActions();w.feedApproach=true;w.hum.Health=50
    w.player.Character:SetAttribute("FeedCan","eat")
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1);assert(h.recovery.owned)
    w:input(E.KeyCode.E);w:advance(3)
    eq(w.player.Character:GetAttribute("WolfFeed"),nil);eq(h.feeding.busy,true);eq(h.recovery.owned,nil)
    w.finishFeedApproach();w:advance(.2);eq(h.recovery.owned,nil);eq(w.nativeFeedMode(),"eat");h:close()
end)
test("feeding intent protects native approach even without executor introspection",function()
    local w=Mock.new();w:enableNativeActions();w.env.getconnections=nil;w.feedApproach=true;w.hum.Health=50
    w.player.Character:SetAttribute("FeedCan","drink")
    local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
    w:input(E.KeyCode.E);w:advance(3);eq(h.feeding.busy,true);eq(h.recovery.owned,nil);h:close()
end)
test("a stalled manual feeding session gets one native restart without resource edits",function()
    local w=Mock.new();w:enableNativeActions();w.player.Character:SetAttribute("Thirst",40)
    w.player.Character:SetAttribute("FeedCan","drink")
    local h=load(w,{settings={states={}}});w:advance(.1);w:input(E.KeyCode.E);w:advance(11)
    eq(w.nativeFeedToggles,3);eq(h.ledger.counts.native_feed_stall_repair,1);eq(h.ledger.counts.native_feed_restart,1)
    eq(w.player.Character:GetAttribute("Thirst"),40);eq(h.ledger.counts.feeding_resource_advanced,nil);h:close()
end)
test("real resource progress prevents stalled-feeding retries",function()
    local w=Mock.new();w:enableNativeActions();w.player.Character:SetAttribute("Hunger",40)
    w.player.Character:SetAttribute("FeedCan","eat")
    local h=load(w,{settings={states={}}});w:advance(.1);w:input(E.KeyCode.E)
    for value=41,47 do w:advance(1);w.player.Character:SetAttribute("Hunger",value)end
    w:advance(.3);eq(w.nativeFeedToggles,1);assert(h.ledger.counts.feeding_resource_advanced>0)
    eq(w.player.Character:GetAttribute("Hunger"),47);h:close()
end)
test("native no-food completion never becomes automatic food seeking or another session",function()
    local w=Mock.new();w:enableNativeActions();w.player.Character:SetAttribute("Hunger",40)
    w.player.Character:SetAttribute("FeedCan","eat")
    local h=load(w,{settings={states={}}});w:advance(.1);w:input(E.KeyCode.E);w:advance(.2)
    w:remote("WolfActions").OnClientEvent:Fire("FeedStop","nofood");w:advance(9)
    eq(w.nativeFeedToggles,1);eq(w.nativeFeedMode(),nil);eq(h.feeding.restart,nil);h:close()
end)
test("movement cancels the pending feeding restart",function()
    local w=Mock.new();w:enableNativeActions();w.player.Character:SetAttribute("Thirst",40)
    w.player.Character:SetAttribute("FeedCan","drink")
    local h=load(w,{settings={states={}}});w:advance(.1);w:input(E.KeyCode.E);w:advance(4.55)
    assert(h.feeding.restart);w.hum.MoveDirection=Mock.V3.new(1,0,0);w:advance(2)
    eq(w.nativeFeedToggles,2);eq(h.feeding.restart,nil);h:close()
end)
test("a click near a feeding offer remains an attack input",function()
    local w=Mock.new();w:enableNativeActions();w.player.Character:SetAttribute("FeedCan","drink")
    local h=load(w,{settings={states={}}});w:advance(.1);w:input(nil,E.UserInputType.MouseButton1)
    eq(w.nativeBites,1);eq(w.nativeFeedToggles,nil);eq(h.ledger.counts.attack_intent,1);h:close()
end)
test("an attack ends native feeding before the game's ordinary bite callback",function()
    local w=Mock.new();w:enableNativeActions();w.player.Character:SetAttribute("FeedCan","eat")
    local h=load(w,{settings={states={}}});w:advance(.1);w:input(E.KeyCode.E);w:advance(.1)
    eq(w.nativeFeedMode(),"eat");w:input(nil,E.UserInputType.MouseButton1)
    eq(w.nativeFeedMode(),nil);eq(w.nativeBites,1);eq(h.ledger.counts.native_feed_cancel_for_attack,1);h:close()
end)
test("missing native feeding access leaves the game session intact instead of fabricating progress",function()
    local w=Mock.new();w:enableNativeActions();w.env.getconnections=nil
    w.player.Character:SetAttribute("Thirst",40);w.player.Character:SetAttribute("FeedCan","drink")
    local h=load(w,{settings={states={}}});w:advance(.1);w:input(E.KeyCode.E);w:advance(9)
    eq(w.nativeFeedToggles,1);eq(w.nativeFeedMode(),"drink");eq(w.player.Character:GetAttribute("Thirst"),40)
    eq(h.ledger.counts.native_feed_restart,nil);h:close()
end)
test("G requests a native water cub pickup from a dry position and observes its actual clamp",function()
    local w=Mock.new();w:enableCarry();w.waterY=3;w.root.Position=Mock.V3.new(0,6,0);w.acceptCarry=true
    local cub,_,cubRoot=w:npc(1,Mock.V3.new(0,3,-2),true);local position=cubRoot.Position
    local h=load(w,{settings={states={}}});w:advance(.1);w:input(E.KeyCode.G);w:advance(.15)
    eq(w.nativeG,nil);eq(h.ledger.counts.native_cub_pickup_requested,1);eq(h.ledger.counts.native_cub_carry_observed,1)
    eq(cubRoot.Position,position);eq(w.configs.CarryConfig.WATER_OK.Wolf,nil);assert(w.carryChecks>0);h:close()
end)
test("water cub rescue waits for normal water exit without spoofing position or permission",function()
    local w=Mock.new();w:enableCarry();w.waterY=3;w.acceptCarry=true
    w.player.Character:SetAttribute("FeralSwimLocal",true);w:npc(1,Mock.V3.new(0,3,-2),true)
    local position=w.root.Position;local h=load(w,{settings={states={}}});w:advance(.1);w:input(E.KeyCode.G);w:advance(.3)
    eq(w.hum.Jump,true);eq(w.root.Position,position);eq(w.player.Character:GetAttribute("FeralSwimLocal"),true)
    eq(h.ledger.counts.native_cub_pickup_requested,nil);eq(w.configs.CarryConfig.WATER_OK.Wolf,nil)
    w.root.Position=Mock.V3.new(0,6,0);w.player.Character:SetAttribute("FeralSwimLocal",false);w:advance(.2)
    eq(h.ledger.counts.native_cub_pickup_requested,1);eq(h.ledger.counts.native_cub_carry_observed,1);h:close()
end)
test("a pickup request without a game attachment stays unconfirmed and times out",function()
    local w=Mock.new();w:enableCarry();w.waterY=3;w.root.Position=Mock.V3.new(0,6,0)
    w:npc(1,Mock.V3.new(0,3,-2),true)
    local h=load(w,{settings={states={}}});w:advance(.1);w:input(E.KeyCode.G);w:advance(2)
    eq(h.ledger.counts.native_cub_pickup_requested,1);eq(h.ledger.counts.native_cub_carry_observed,nil)
    eq(h.rescue.pending,nil);assert(h.rescue.status:find("No native carry observed",1,true));h:close()
end)
test("ordinary G and native drop behavior are preserved outside a water rescue",function()
    local w=Mock.new();w:enableCarry();w:npc(1,Mock.V3.new(0,3,-2),true)
    local h=load(w,{settings={states={}}});w:advance(.1);w:input(E.KeyCode.G);eq(w.nativeG,1)
    eq(h.rescue.pending,nil);h:close();assert(w.bindings.NativeCarry)
end)
test("prediction is disabled while genuine hit replies and pre-claim HP changes remain observable",function()
    local w=Mock.new();w:enableNativeActions();w.configs.CombatConfig.HIT2={PREDICT=true}
    local _,char,hum=w:enemy(2);w.nativeBiteTarget=char;w.nativeDamage=10
    local h=load(w,{settings={states={biteHelper=true}}});w:advance(.2);w:input(nil,E.UserInputType.MouseButton1);w:advance(1.25)
    eq(w.predictedImpacts,nil);eq(w.nativeHitResponses,1);eq(hum.Health,90)
    eq(h.ledger.counts.native_outgoing_hit_reply,1);eq(h.ledger.counts.target_hp_decline_correlated,1)
    eq(h.registry.byId.combat.outcome,"unverified");h:close();eq(w.configs.CombatConfig.HIT2.PREDICT,true)
end)
test("feeding and bite coordination preserve automatic minigame timing",function()
    local w=Mock.new();w:enableNativeGrab();w:enableNativeActions()
    local h=load(w,{settings={states={minigame=true,recovery=true}}});w:advance(.1)
    local r=w:remote("FeralGrabV2");local at=w.time+1000
    r.OnClientEvent:Fire("begin",{f=41,role="prey",n=3})
    r.OnClientEvent:Fire("strike",{f=41,k=1,t0=at,spd=1,from=0,zc=.5,zw=.215})
    w:input(nil,E.UserInputType.MouseButton1);w:advance(.6)
    eq(w.nativeBites,1);eq(h.grab.presses,1);eq(w.nativeManualPresses,nil);eq(h.recovery.owned,nil);h:close()
end)

test("native lookup never requests a large heap and releases its bounded callback queue",function()
    local w=Mock.new();w:enableNativeGrab();w:enableNativeActions()
    local original=w.env.getgc;local calls=0
    w.env.getgc=function()
        calls+=1;local pool=table.create(200000,false)
        for _,fn in ipairs(original())do table.insert(pool,fn)end
        return table.freeze(pool)
    end
    local h=load(w,{settings={states={minigame=true}}});w:advance(.4)
    eq(calls,0);assert(h.bridge.grabController);assert(h.bridge.wolfActions.tryBite)
    assert(h.bridge.wolfActions.toggleFeed);eq(h.bridge.wolfActions.cancelFeed,nil)
    eq(h.bridge.nativeScan,nil);h:close();eq(h.bridge.grabDiscovery,nil);eq(h.bridge.wolfDiscovery,nil)
end)

test("native callback discovery avoids heap enumeration and invokes no input during startup",function()
    local w=Mock.new();w:enableNativeGrab();w:enableNativeActions();w:enableNativeConnections()
    local calls=0;w.env.getgc=function()calls+=1;error("heap enumeration should not be needed")end
    local h=load(w,{settings={states={minigame=true}}});w:advance(.1)
    eq(calls,0);assert(h.bridge.grabController);assert(h.bridge.wolfActions.tryBite);assert(h.bridge.wolfActions.toggleFeed)
    eq(w.nativeBites,nil);eq(w.nativeFeedToggles,nil);eq(h.grabInput.lease,nil)
    local _,_,known=h.bridge:nativeFeedState(w.time);eq(known,true);h:close()
end)
test("guarded native feed cancellation never starts an inactive feeding offer",function()
    local w=Mock.new();w:enableNativeActions();w.player.Character:SetAttribute("FeedCan","eat")
    local h=load(w,{settings={states={}}});w:advance(.1)
    eq(h.bridge.wolfActions.cancelFeed,nil);eq(h.bridge:stopNativeFeed(w.time),false);eq(w.nativeFeedToggles,nil)
    w:input(E.KeyCode.E);eq(w.nativeFeedMode(),"eat")
    eq(h.bridge:stopNativeFeed(w.time),true);eq(w.nativeFeedMode(),nil);h:close()
end)

test("recovery trend expires an old HP gain instead of reporting it forever",function()
    local w=Mock.new();w.hum.Health=60
    local h=load(w,{settings={states={recovery=true}}});w:advance(.6)
    w.hum.Health=61;w:advance(.4);assert(h.recovery:summary():find("HP rising",1,true))
    w:advance(6.6);assert(h.recovery:summary():find("no HP rise observed",1,true))
    eq(h.recovery.observations.hp.change,0);assert(h.recovery.observations.hp.seconds<=6.00001)
    assert(#h.recovery.observations.hp.samples<=32);h:close()
end)
test("HP and three condition trends remain independent in one recovery session",function()
    local w=Mock.new();w.hum.Health=60
    local c=w.player.Character;c:SetAttribute("FeralInjury",8);c:SetAttribute("FeralBleed",7);c:SetAttribute("FeralVenomAmt",6)
    local h=load(w,{settings={states={recovery=true}}});w:advance(.6)
    w.hum.Health=61;c:SetAttribute("FeralInjury",7);c:SetAttribute("FeralBleed",nil);w:advance(.4)
    assert(h.recovery:summary():find("HP rising",1,true));assert(h.recovery:effectsSummary():find("injury: easing",1,true))
    eq(h.recovery.observations.bleed,nil);eq(h.recovery.observations.venom.change,0)
    c:SetAttribute("FeralInjury",9);w:advance(.7);eq(h.recovery.observations.injury.change,0)
    w.hum.MaxHealth=101;w.hum.Health=62;w:advance(.7);eq(h.recovery.observations.hp.change,0)
    h:close()
end)
test("native bite guidance reports cooldown without invoking an attack",function()
    local w=Mock.new();w:enableNativeActions();local h=load(w,{settings={states={}}});w:advance(.2)
    eq(h.biteReadiness.ready,true);eq(w.nativeBites,nil)
    w:input(nil,E.UserInputType.MouseButton1);w:advance(.04)
    eq(h.biteReadiness.ready,false);eq(h.biteReadiness.reason,"native cooldown")
    w:advance(.55);eq(h.biteReadiness.ready,true);eq(w.nativeBites,1);h:close()
end)
test("bite guidance respects capture, timed ability and private Rest locks",function()
    local w=Mock.new();w:enableNativeActions();local h=load(w,{settings={states={}}});w:advance(.2)
    local c=w.player.Character;c:SetAttribute("FeralPinned",true);w:advance(.1);eq(h.biteReadiness.ready,false)
    c:SetAttribute("FeralPinned",nil);c:SetAttribute("FeralNoBiteUntil",w.time+1001);w:advance(.1)
    eq(h.biteReadiness.reason,"native bite lock")
    c:SetAttribute("FeralNoBiteUntil",nil);c:SetAttribute("FeralKingsAt",w.time);w:advance(.1)
    eq(h.biteReadiness.reason,"native ability lock")
    c:SetAttribute("FeralKingsAt",nil);w.nativeRestWanted=true;w:advance(.1);eq(h.biteReadiness.reason,"native Rest lock")
    w.nativeRestWanted=false;w:advance(.1);eq(h.biteReadiness.ready,true);eq(w.nativeBites,nil);h:close()
end)
test("missing native timing stays unknown instead of advertising bite readiness",function()
    local w,h=boot({biteHelper=true});eq(h.biteReadiness.ready,false);eq(h.biteReadiness.known,false);h:close()
end)
test("unchanged hollow player outlines and stationary name positions generate no repeat writes",function()
    local w=Mock.new();local _,char,hum=w:enemy(2,Mock.V3.new(0,3,-40))
    local h=load(w,{settings={states={esp=true,tags=true}}});w:advance(.4);h.ui:toggle();w:resetMetrics()
    w:advance(1)
    eq(w.metrics.writes["Highlight:OutlineColor"],nil);eq(w.metrics.writes["Highlight:FillTransparency"],nil)
    eq(w.metrics.writes["Highlight:Enabled"],nil);eq(w.metrics.writes["TextLabel:Position"],nil)
    hum.Health=20;w:advance(.1);eq(w.metrics.writes["Highlight:OutlineColor"],1)
    eq(h.ui.records[char].highlight.FillTransparency,1);h:close()
end)
test("disabled name tags perform no world projections",function()
    local w=Mock.new();for i=1,24 do w:enemy(2,Mock.V3.new(i,3,-50))end
    local h=load(w,{settings={states={esp=true,tags=false,biteHelper=false}}});w:advance(.4);w:resetMetrics()
    w:advance(1);eq(w.metrics.projections,0);h:close()
end)
test("active native strikes defer background work through frame hitches and concurrent bites",function()
    local w=Mock.new();w:enableNativeActions();w:enableNativeGrab()
    local h=load(w,{settings={states={minigame=true,recovery=true,esp=true}}});w:advance(.3)
    for _,key in ipairs({"candidates","bindNative"})do
        local original=h.bridge[key]
        h.bridge[key]=function(self,...)assert(not h.timingCritical,"background work during strike");return original(self,...)end
    end
    local r=w:remote("FeralGrabV2");r.OnClientEvent:Fire("begin",{f=62,role="prey",n=4})
    local before=w.metrics.connections
    for strike=1,8 do
        local at=w.time+1000
        r.OnClientEvent:Fire("strike",{f=62,k=strike,t0=at,spd=1,from=0,zc=.5,zw=.215})
        w:input(nil,E.UserInputType.MouseButton1)
        r.OnClientEvent:Fire("n",{f=62,n=2+strike%4})
        for _,dt in ipairs({.31,.32,.11,.13,.07,.28,.29,.1,.11})do w:step(dt)end
        assert(h.active,h.lastError);eq(h.grab.presses,strike)
    end
    eq(w.nativeBites,8);eq(w.nativeManualPresses,nil);eq(h.grab.grades.perfect,0)
    eq(w.metrics.connections,before)
    for _,call in ipairs(w.calls)do
        if call.name=="FeralGrabV2" and call.args[1]=="press" then close(call.args[4],call.at+1000) end
    end
    r.OnClientEvent:Fire("end",{f=62});w:advance(.2);eq(h.timingCritical,false);h:close()
end)
test("a strike recovered from native UI state immediately protects its timing frame",function()
    local w=Mock.new();w:enableNativeGrab();w:enableNativeActions()
    local h=load(w,{settings={states={minigame=true}}});w:advance(.3)
    w:remote("FeralGrabV2").OnClientEvent:Fire("begin",{f=63,role="prey"})
    h.grab:reset("missed observer event")
    local state=w.nativeGrabState();state.strike={f=63,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215,dur=2.5}
    h.nextGrabPoll=0;h.nextScan=0
    local calls=0;local original=h.bridge.candidates
    h.bridge.candidates=function(self,...)calls+=1;return original(self,...)end
    w:step(.02);eq(h.timingCritical,true);eq(calls,0);assert(h.grab.pending)
    w:advance(.6);eq(h.grab.presses,1);h:close()
end)
test("preserved release comparison reduces repeated visual writes and strike background scans",function()
    local P=assert(loadstring(PERF_SOURCE))()
    local old=P.run(BASELINE,Mock,false);local new=P.run(BUNDLE,Mock,false)
    assert(new.highlightWrites<old.highlightWrites*.1);assert(new.labelPositions<old.labelPositions*.1)
    assert(new.upvalues<old.upvalues);eq(new.heap,0)
    local oldStrike=P.run(BASELINE,Mock,true);local newStrike=P.run(BUNDLE,Mock,true)
    assert(oldStrike.candidateScans>=10);eq(newStrike.candidateScans,0)
    assert(newStrike.boundInfo<oldStrike.boundInfo*.35)
    print(string.format("WORK_BENCH old_highlight=%d new_highlight=%d old_label_position=%d new_label_position=%d old_idle_upvalues=%d new_idle_upvalues=%d old_strike_scans=%d new_strike_scans=%d old_binding_queries=%d new_binding_queries=%d",old.highlightWrites,new.highlightWrites,old.labelPositions,new.labelPositions,old.upvalues,new.upvalues,oldStrike.candidateScans,newStrike.candidateScans,oldStrike.boundInfo,newStrike.boundInfo))
end)
test("native talon and dive session IDs block recovery and do not trigger underwater auto-drop",function()
    local w=Mock.new();w:enableVultureFlight();w.hum.Health=60
    local c=w.player.Character;c:SetAttribute("FeralTalonLock",84);c:SetAttribute("FeralUnderwater",true)
    local h=load(w,{settings={states={flight=true,recovery=true}}});w:advance(.3)
    eq(h.snapshot.ability,true);eq(h.recovery.owned,nil);eq(c:GetAttribute("FeralFlyDrop"),nil)
    c:SetAttribute("FeralTalonLock",nil);c:SetAttribute("FeralDiveLocal",85);w:advance(.3)
    eq(h.snapshot.ability,true);eq(c:GetAttribute("FeralFlyDrop"),nil);h:close()
end)
test("a real Vulture let-go intent receives at most one native release retry",function()
    local w=Mock.new();w:enableVultureFlight();w.player.Character:SetAttribute("FeralTalonLock",84)
    local h=load(w,{settings={states={flight=true}}});w:advance(.2)
    w:input(E.KeyCode.Space);w:advance(2)
    local releases=0;for _,call in ipairs(w.calls)do if call.name=="FeralLunge" and call.args[1]=="release"then releases+=1 end end
    eq(releases,2);eq(h.ledger.counts.native_talon_release_retried,1)
    eq(w.player.Character:GetAttribute("FeralTalonLock"),84);w:advance(3)
    eq(h.ledger.counts.native_talon_release_retried,1);h:close()
end)
test("a stalled post-attack Vulture uses native restart intents without editing physics",function()
    local w=Mock.new();w:enableVultureFlight();local c=w.player.Character;c:SetAttribute("FeralTalonLock",84)
    local h=load(w,{settings={states={flight=true}}});w:advance(.2)
    c:SetAttribute("FeralTalonLock",nil);w:resetMetrics();w:advance(1)
    eq(c:GetAttribute("FeralFlyDrop"),true);assert(type(c:GetAttribute("FeralFlyRelaunch"))=="number")
    eq(w.metrics.writes["Part:Anchored"],nil);eq(w.metrics.writes["Part:Position"],nil)
    eq(w.metrics.writes["Part:AssemblyLinearVelocity"],nil);eq(w.vultureMovers.vel.Enabled,false)
    eq(h.ledger.counts.post_attack_native_flight_restart,1)
    w.acceptNativeFlightRepair=true;w:advance(.4)
    eq(w.nativeFlightRestarts,1);eq(h.ledger.counts.post_attack_flight_motion_observed,1)
    eq(c:GetAttribute("FeralFlyDrop"),nil);eq(c:GetAttribute("FeralFlyRelaunch"),nil);h:close()
end)
test("Vulture recovery never restarts an active, anchored, captured or deliberately stationary flight",function()
    local w=Mock.new();w:enableVultureFlight();local c=w.player.Character;c:SetAttribute("FeralTalonLock",84)
    local h=load(w,{settings={states={flight=true}}});w:advance(1.2);eq(c:GetAttribute("FeralFlyDrop"),nil)
    c:SetAttribute("FeralTalonLock",nil);w.root.Anchored=true;w:advance(1);eq(c:GetAttribute("FeralFlyDrop"),nil)
    w.root.Anchored=false;c:SetAttribute("FeralPinned",true);w:advance(1);eq(c:GetAttribute("FeralFlyDrop"),nil)
    c:SetAttribute("FeralPinned",nil);w.hum.MoveDirection=Mock.V3.new();w:advance(1)
    eq(c:GetAttribute("FeralFlyDrop"),nil);h:close()
end)
test("flight restart timeout and disable restore only owned intents",function()
    local w=Mock.new();w:enableVultureFlight();local c=w.player.Character;c:SetAttribute("FeralTalonLock",84)
    local h=load(w,{settings={states={flight=true}}});w:advance(.2);c:SetAttribute("FeralTalonLock",nil);w:advance(1)
    assert(h.flightRepair);c:SetAttribute("FeralFlyRelaunch",999)
    h:set("flight",false);eq(c:GetAttribute("FeralFlyDrop"),nil);eq(c:GetAttribute("FeralFlyRelaunch"),999)
    eq(h.flightRepair,nil);h:close()
end)

test("vendor-wrapped input callbacks still reveal validated own native bite functions",function()
    local w=Mock.new();w:enableNativeActions();w:enableNativeGrab()
    local original=w.env.getconnections;local wrappers={}
    w.env.getconnections=function(event)
        local connections=original(event)
        if event~=w.uis.InputBegan then return connections end
        local result={}
        for _,connection in ipairs(connections)do
            local fn=connection.Function
            if not wrappers[fn] then
                local wrapper=function()return fn end
                w:registerNative(wrapper,"VendorWrapper","wrap",function()return {fn}end)
                wrappers[fn]=wrapper
            end
            table.insert(result,{Function=wrappers[fn]})
        end
        return result
    end
    w.env.getgc=function()error("heap enumeration forbidden")end
    local h=load(w,{settings={states={minigame=true}}});w:advance(.8)
    assert(h.bridge.grabController);assert(h.bridge.wolfActions.tryBite);assert(h.bridge.wolfActions.toggleFeed)
    assert(h.bridge.wolfActions.biteCooldown);eq(w.nativeBites,nil);h:close()
end)

test("visible native cooldown remains useful when primary-input handlers are VM-isolated",function()
    local w=Mock.new();w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=function()return .6 end})
    w.configs.PassiveConfig.biteCdMult=function()return .8 end
    local h=load(w,{settings={states={}}});w:advance(.1);eq(h.biteReadiness.known,false)
    w.player.Character:SetAttribute("WolfBiteAt",w.time+1000);w:advance(.1)
    eq(h.biteReadiness.ready,false);eq(h.biteReadiness.reason,"native cooldown")
    w:advance(.5);eq(h.biteReadiness.ready,true);eq(h.biteReadiness.privateStateKnown,false)
    eq(h.biteReadiness.timingSource,"native config and own bite marker");eq(w.nativeBites,nil);h:close()
end)
test("hot reload preserves validated native bite handles without a heap search",function()
    local w=Mock.new();w:enableNativeActions();local old=load(w,{settings={states={}}});w:advance(.2)
    assert(old.bridge.wolfActions.tryBite)
    local original=w.env.getconnections
    w.env.getconnections=function(event)if event==w.uis.InputBegan then return {} end;return original(event)end
    w.env.getgc=function()error("heap search")end
    local h=load(w,{settings={states={}}});w:advance(.2)
    eq(h.bridge.wolfActions.tryBite,old.bridge.wolfActions.tryBite)
    eq(h.biteReadiness.ready,true);eq(old.closed,true);h:close()
end)

test("Z and X never transfer automatic recovery into manual Rest",function()
    local w=Mock.new();w:enableNativePose();w.nativeRestEcho=true;w.hum.Health=60
    w.hum.MoveDirection=Mock.V3.new(1,0,0)
    local h=load(w,{settings={states={recovery=true}}});w:advance(.2)
    for _,key in ipairs({E.KeyCode.Z,E.KeyCode.X})do
        w:input(key);eq(h.policy.manualRest,false);w:advance(1.7)
        eq(h.policy.manualRest,false);eq(h.recovery.owned,w.player.Character)
        eq(w.nativePose.sit,0);eq(w.nativePose.lie,0)
    end
    h:close()
end)
test("gamepad Y is handed to native manual Rest before its action callback",function()
    local w=Mock.new();w:enableNativePose();w.nativeRestEcho=true;w.hum.Health=60
    local h=load(w,{settings={states={recovery=true}}});w:advance(.2)
    w.cas:BindActionAtPriority("WolfRest",function(_,state)
        if state==E.UserInputState.Begin then
            eq(h.policy.manualRest,true);eq(w.player.Character:GetAttribute("WolfDbgRestP"),nil)
            w.player.Character:SetAttribute("WolfRest",true)
        end
        return E.ContextActionResult.Sink
    end,false,3000,E.KeyCode.ButtonY)
    w:input(E.KeyCode.ButtonY,E.UserInputType.Gamepad1);w:advance(.3)
    eq(h.policy.manualRest,true);eq(h.recovery.owned,nil);assert(w.nativePose.sit>0);h:close()
end)
test("a pose-release frame hitch cannot remove the reset before the native animator uses it",function()
    local w=Mock.new();w:enableNativePose();w.nativeRestEcho=true;w.hum.Health=60
    local h=load(w,{settings={states={recovery=true}}});w:advance(.2)
    w.nativePose.sit,w.nativePose.lie=1,1
    h:set("recovery",false)
    local original=w.renders.WolfAnim.fn;local observed=false
    w.renders.WolfAnim.fn=function(dt)
        observed=w.player.Character:GetAttribute("WolfDbgRestP")~=nil
        original(dt)
    end
    w:step(.6)
    eq(observed,true);eq(w.nativePose.sit,0);eq(w.nativePose.lie,0)
    eq(w.player.Character:GetAttribute("WolfDbgRestP"),nil);h:close()
end)
test("actual walking ends stationary manual Rest once before recovery takes over",function()
    local w=Mock.new();w:enableNativePose();w.nativeRestEcho=true;w.hum.Health=60
    w.player.Character:SetAttribute("WolfRest",true)
    local h=load(w,{settings={states={recovery=true}}});w:advance(.3);eq(h.policy.manualRest,true)
    w.hum.MoveDirection=Mock.V3.new(1,0,0);w:advance(1.2)
    eq(h.policy.manualRest,false);eq(h.ledger.counts.manual_rest_exit_by_movement,1)
    eq(h.recovery.owned,w.player.Character);eq(w.nativePose.sit,0);eq(w.nativePose.lie,0)
    local releases=0;for _,call in ipairs(w.calls)do if call.args[1]=="Rest" and call.args[2]==false then releases+=1 end end
    eq(releases,1);h:close()
end)
test("an inherited moving Rest pose cannot stay classified as stationary manual Rest",function()
    local w=Mock.new();w:enableNativePose();w.nativeRestEcho=true;w.hum.Health=60
    w.player.Character:SetAttribute("WolfRest",true);w.hum.MoveDirection=Mock.V3.new(1,0,0)
    local h=load(w,{settings={states={recovery=true}}});w:advance(.3)
    eq(h.policy.manualRest,false);eq(w.nativePose.sit,0);eq(w.nativePose.lie,0)
    eq(h.ledger.counts.manual_rest_exit_by_movement,1);h:close()
end)
test("Forest GUI text is never mistaken for a manual Rest control",function()
    local w=Mock.new();w.nativeRestEcho=true;w.hum.Health=60
    local h=load(w,{settings={states={recovery=true}}});w:advance(.2)
    local button=w.env.Instance.new("TextButton");button.Name="Forest";button.Text="Forest map";button.Parent=w.player:FindFirstChildOfClass("PlayerGui")
    w.guiHits={button};w:input(nil,E.UserInputType.MouseButton1)
    eq(h.policy.manualRest,false);eq(h.ledger.counts.attack_intent,1);h:close()
end)

test("rapid timing schedules the first safe Perfect entry in either direction",function()
    local M=modules()
    for _,speed in ipairs({.786,1,1.156,2,10}) do
        for _,from in ipairs({0,1}) do
            for _,zone in ipairs({.12,.35,.65,.88}) do
                local g=M.grab.new();g.enabled=true
                g:event("begin",{f=71},100,1,.32,2.5)
                g:event("strike",{f=71,k=1,t0=100,spd=speed,from=from,zc=zone,zw=.215},100,1,.32,2.5)
                assert(g.pending);local p=g.pending
                local centre=100+(from==0 and zone or 1-zone)/speed
                close(p.at,centre-p.half*.88/speed)
                local sent=0
                g:tick(p.at-.0001,1,true,function()error("early press")end)
                g:tick(p.at,1,true,function(_,_,at)
                    local phase=(at-100)*speed
                    local x=math.abs((phase+1)%2-1);if from==1 then x=1-x end
                    assert(math.abs(x-zone)<=.215*.5*.32)
                    sent+=1;return true
                end)
                eq(sent,1);eq(g.firstWindows,1);eq(g.grades.perfect,0)
            end
        end
    end
end)
test("a packet arriving twenty milliseconds before centre does not lose its first pass",function()
    local M,w=modules();local old=assert(w.env.loadstring(PREVIOUS))({inspect=true})
    local before=old.grab.new();before.enabled=true
    local after=M.grab.new();after.enabled=true
    for _,g in ipairs({before,after}) do
        g:event("begin",{f=72},100,1,.32,2.5)
        g:event("strike",{f=72,k=1,t0=100,spd=1,from=0,zc=.5,zw=.215},100.48,1,.32,2.5)
    end
    close(before.pending.at,101.5);close(after.pending.at,100.48)
    local sent=0;after:tick(100.48,1,true,function()sent+=1;return true end);eq(sent,1)
    print(string.format("MINIGAME_TIMING_BENCH old_late_packet_wait_ms=%.2f new_late_packet_wait_ms=0 early_window_gain_ms=%.3f",(before.pending.at-100.48)*1000,.215*.5*.32*.88*1000))
end)
test("arrival in the latter half of a Perfect interval is pressed immediately",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    g:event("begin",{f=73},100,1,.32,2.5)
    g:event("strike",{f=73,k=1,t0=100,spd=1,from=0,zc=.5,zw=.215},100.52,1,.32,2.5)
    close(g.pending.at,100.52);local sent=0
    g:tick(100.52,1,true,function()sent+=1;return true end);eq(sent,1)
end)
test("a future native strike never generates an anticipated timestamp",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    g:event("begin",{f=74},100,1,.32,2.5)
    g:event("strike",{f=74,k=1,t0=100.8,spd=1,from=0,zc=.5,zw=.215},100,1,.32,2.5)
    local sent=0
    for tick=100,101.25,.005 do g:tick(tick,1,true,function()sent+=1;return true end) end
    eq(sent,0);g:tick(101.28,1,true,function(_,_,at)close(at,101.28);sent+=1;return true end);eq(sent,1)
end)
test("window search remains valid beyond thirty-two elapsed triangle periods",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    g:event("begin",{f=75},109.8,1,.32,2.5)
    g:event("strike",{f=75,k=1,t0=100,spd=100,from=0,zc=.5,zw=.215,dur=10},109.8,1,.32,2.5)
    assert(g.pending);assert(g.pending.at<109.81)
    local at=g.pending.at;g:tick(at,1,true,function()return true end);eq(g.presses,1)
end)
test("render timing can dispatch a strike between heartbeat updates",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local remote=w:remote("FeralGrabV2");local start=w.time+1000
    remote.OnClientEvent:Fire("begin",{f=76,role="prey"})
    remote.OnClientEvent:Fire("strike",{f=76,k=1,t0=start,spd=1,from=0,zc=.5,zw=.215})
    local p=h.grab.pending;w.time+=p.at-start+.0001
    for _,record in pairs(w.renders) do record.fn(.016) end
    eq(h.grab.presses,1)
    for _,call in ipairs(w.calls)do if call.name=="FeralGrabV2" then close(call.args[4],call.at+1000) end end
    w:advance(.2);eq(h.grab.presses,1);h:close()
end)
test("a strike already inside Perfect is dispatched from its native event",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local r=w:remote("FeralGrabV2");r.OnClientEvent:Fire("begin",{f=77,role="prey"})
    r.OnClientEvent:Fire("strike",{f=77,k=1,t0=w.time+1000-.48,spd=1,from=0,zc=.5,zw=.215})
    eq(h.grab.presses,1);eq(w.nativeGrabState().strike.pressed,true);eq(h.grab.grades.perfect,0)
    w:input(E.KeyCode.Space);eq(w.nativeManualPresses,nil);eq(h.grab.presses,1);h:close()
end)
test("a matching own game result cancels its pending strike while other hunters do not",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    g:event("begin",{f=78},100,1,.32,2.5)
    g:event("strike",{f=78,k=1,t0=100,spd=1,from=0,zc=.5,zw=.215},100,1,.32,2.5)
    eq(g:event("res",{f=78,k=1,mine=false,tier="perfect"},100.2,1,.32,2.5),false);assert(g.pending)
    eq(g:event("res",{f=78,k=1,mine=true,tier="miss"},100.3,1,.32,2.5),true);eq(g.pending,nil)
    g:tick(100.5,1,true,function()error("press after final result")end);eq(g.grades.miss,1)
end)
test("reentrant game replies and session replacement retain their real provenance",function()
    local M=modules();local g=M.grab.new();g.enabled=true
    g:event("begin",{f=79},100,1,.32,2.5)
    g:event("strike",{f=79,k=1,t0=100,spd=1,from=0,zc=.5,zw=.215},100,1,.32,2.5)
    g:tick(100.48,1,true,function()
        g:event("res",{f=79,k=1,mine=true,tier="perfect"},100.48,1,.32,2.5)
        g:event("begin",{f=80},100.48,1,.32,2.5);return true
    end)
    eq(g.grades.perfect,1);eq(g.session,80);eq(next(g.submitted),nil);eq(g.status,"native session observed")
end)
test("long native sessions bound strike history and reject evicted old packets",function()
    local M=modules();local g=M.grab.new();g.enabled=true;g:event("begin",{f=81},100,1,.32,2.5)
    for k=1,300 do
        local now=100+k
        g:event("strike",{f=81,k=k,t0=now,spd=1,from=0,zc=.5,zw=.215},now,1,.32,2.5)
        g:tick(now+.48,1,true,function()return true end)
    end
    eq(#g.history,128);eq(#g.dispatches,32);eq(g.presses,300)
    eq(g:event("strike",{f=81,k=1,t0=401,spd=1,from=0,zc=.5,zw=.215},401,1,.32,2.5),false)
end)
test("replayed native zones produce valid actual-time presses across frame rates and hunter widths",function()
    local M=modules();local cases=0
    for _,fps in ipairs({30,60,144}) do
        for _,width in ipairs({.215,.215*.85,.215*.85*.85}) do
            for _,from in ipairs({0,1}) do
                for _,zone in ipairs({.15,.4,.7,.9}) do
                    local g=M.grab.new();g.enabled=true;local start=100
                    g:event("begin",{f=82,role="prey",n=3},start,1,.32,2.5)
                    g:event("strike",{f=82,k=1,t0=start+.8,spd=1.156,from=from,zc=zone,zw=width},start,1,.32,2.5)
                    local actual
                    for frame=1,math.ceil(4*fps)do
                        local at=start+frame/fps
                        g:tick(at,1,true,function(_,_,stamp)
                            close(stamp,at);actual=at;return true
                        end)
                        if actual then break end
                    end
                    assert(actual,"native interval missed")
                    local phase=(actual-start-.8)*1.156
                    local position=math.abs((phase+1)%2-1);if from==1 then position=1-position end
                    assert(math.abs(position-zone)<=width*.5*.32,"press outside native Perfect")
                    eq(g.grades.perfect,0)
                    g:event("res",{f=82,k=1,mine=true,tier="perfect"},actual,1,.32,2.5)
                    eq(g.grades.perfect,1);cases+=1
                end
            end
        end
    end
    print("MINIGAME_REPLAY_CASES "..cases.." native-contract simulations; gameplay unverified")
end)
test("native abilities preempt owned Rest immediately before the next heartbeat",function()
    for _,key in ipairs({"FeralTalonLock","FeralDiveLocal","FeralPinned","FeralClimbLocal","FeralFlyLocal","WolfFeed"}) do
        local w=Mock.new();w.nativeRestEcho=true;w.hum.Health=50
        local h=load(w,{settings={states={recovery=true}}});w:advance(.2);assert(h.recovery.owned)
        w.player.Character:SetAttribute(key,key=="WolfFeed" and "eat" or true)
        eq(h.recovery.owned,nil);h:close()
    end
end)
test("the action coordinator gives minigames, capture and actual attack the proper priority",function()
    local M=modules();local p=M.policy.new();local s={alive=true,combat=false,grab=true,captured=true,ability=true,feeding=true,attackHeld=true}
    eq(p:activity(s,10),"minigame");s.grab=false;eq(p:activity(s,10),"capture")
    s.captured=false;eq(p:activity(s,10),"attack");s.attackHeld=false;eq(p:activity(s,10),"ability")
    s.ability=false;eq(p:activity(s,10),"feeding");s.feeding=false;s.swimming=true
    eq(p:allowed("recovery",s,10,"health"),false)
end)
test("stamina covers native swim, climb and venom consumption inputs with exact restoration",function()
    local w=Mock.new();local n=w.configs.NeedsConfig;n.SWIM_DRAIN_MULT=1.15;n.WATER_DRAIN_NONSWIM=1.5
    local climb=w.configs.PassiveConfig.CLIMBER
    climb.levels={{stamina="drain",drain=1},{stamina="trot"},{stamina="walk"}}
    climb.CLIMB_SPRINT={Python={DRAIN=.8,SPEED=1.5}}
    w:addConfig("VenomConfig",{SPRINT_DRAIN=.15,OTHER_DRAIN=.06,BITE_DRAIN=.025})
    local v=w.configs.StatusConfig.VENOM;v.STAMINA_BASE=.1;v.STAMINA_PER_POINT=.02
    local h=load(w,{settings={states={stamina=true,climb=true}}});w:advance(.2)
    eq(n.SWIM_DRAIN_MULT,0);eq(n.WATER_DRAIN_NONSWIM,0);eq(climb.levels[1].stamina,"walk")
    eq(climb.levels[1].drain,0);eq(climb.CLIMB_SPRINT.Python.DRAIN,0);eq(climb.CLIMB_SPRINT.Python.SPEED,1.5)
    eq(w.configs.VenomConfig.BITE_DRAIN,0);eq(v.STAMINA_PER_POINT,0);eq(w.player.Character:GetAttribute("Stamina"),80)
    h:close();eq(n.SWIM_DRAIN_MULT,1.15);eq(n.WATER_DRAIN_NONSWIM,1.5);eq(climb.levels[1].stamina,"drain")
    eq(climb.levels[1].drain,1);eq(climb.CLIMB_SPRINT.Python.DRAIN,.8);eq(v.STAMINA_PER_POINT,.02)
end)
test("nested native climbing replacement retires the old stamina profile",function()
    local w=Mock.new();local old={{stamina="drain",drain=1}}
    w.configs.PassiveConfig.CLIMBER.levels=old
    local h=load(w,{settings={states={stamina=true}}});w:advance(.2);eq(old[1].drain,0)
    local replacement={{stamina="drain",drain=2}};w.configs.PassiveConfig.CLIMBER.levels=replacement;w:advance(1.4)
    eq(old[1].drain,1);eq(old[1].stamina,"drain");eq(replacement[1].drain,0)
    h:close();eq(replacement[1].drain,2)
end)
test("recent stamina measurements expire and exclude gait, species and capacity transitions",function()
    local M=modules();local l=M.core.ledger();local char={}
    local function sample(now,value,locomotion,species,maximum)
        l:sample({char=char,now=now,hp=50,maxHP=100,combat=false,moving=true,
            species=species or "Wolf",locomotion=locomotion or "LAND",stamina=value,maxStamina=maximum or 100},"NO_SIGNAL")
    end
    sample(1,80);sample(1.5,78);close(l.staminaObservation.rate,-4)
    sample(2,78,"CLIMB");eq(l.staminaObservation,nil)
    sample(2.5,77,"CLIMB");assert(l.staminaObservation)
    sample(3,77,"CLIMB","Eagle");eq(l.staminaObservation,nil)
    sample(3.5,77,"CLIMB","Eagle",120);eq(l.staminaObservation,nil)
    for i=1,20 do sample(3.5+i*.5,77,"CLIMB","Eagle",120)end
    close(l.staminaObservation.rate,0);assert(#l.staminaObservation.samples<=32)
end)
test("loss of the native food offer blocks a stale-session restart",function()
    local w=Mock.new();w:enableNativeActions();local c=w.player.Character;c:SetAttribute("FeedCan","drink");c:SetAttribute("Thirst",40)
    local h=load(w,{settings={states={}}});w:advance(.2);w:input(E.KeyCode.E);w:advance(1)
    c:SetAttribute("FeedCan",nil);w:advance(6)
    eq(w.nativeFeedToggles,1);eq(h.feeding.restart,nil);assert(h.feeding.status:find("offer lost",1,true));h:close()
end)
test("an ability cannot be interrupted by an automatic stalled-feeding repair",function()
    local w=Mock.new();w:enableNativeActions();local c=w.player.Character;c:SetAttribute("FeedCan","eat");c:SetAttribute("Hunger",40)
    local h=load(w,{settings={states={}}});w:advance(.2);w:input(E.KeyCode.E);w:advance(3)
    c:SetAttribute("FeralDiveLocal",84);w:advance(3)
    eq(w.nativeFeedToggles,1);eq(h.feeding.restart,nil);eq(h.feeding.busy,false);h:close()
end)
test("the selected bite guide updates current geometry between target scans",function()
    local w,h=boot({biteHelper=true});local _,char,hum,root=w:enemy(2,Mock.V3.new(0,3,-6));w:advance(.2)
    assert(h.guide);h.nextScan=w.time+10
    root.Position=Mock.V3.new(0,30,-6);w:step(.016);eq(h.guide.extended.valid,false);eq(h.guide.blocked,true)
    root.Position=Mock.V3.new(0,3,-6);w:step(.016);eq(h.guide.extended.valid,true);eq(h.guide.blocked,false)
    hum.Health=0;w:step(.016);eq(h.guide.invalid,true);h:close()
end)
test("small distance fluctuations do not flip the rear assist target",function()
    local w,h=boot();local _,a,_,ar=w:enemy(2,Mock.V3.new(0,3,6));local _,b,_,br=w:enemy(2,Mock.V3.new(0,3,6.2));w:advance(.2)
    eq(h.bridge.reachTarget.char,a);br.Position=Mock.V3.new(0,3,5.8);w:advance(.2);eq(h.bridge.reachTarget.char,a)
    br.Position=Mock.V3.new(0,3,4.8);w:advance(.2);eq(h.bridge.reachTarget.char,b);h:close()
end)
test("a native positive damage reply stays distinct from unconfirmed target HP",function()
    local w=Mock.new();w:enableNativeActions();local _,char=w:enemy(2);w.nativeBiteTarget=char;w.nativeDamage=0
    local h=load(w,{settings={states={}}});w:advance(.2);w:input(nil,E.UserInputType.MouseButton1);w:advance(.4)
    w:remote("FeralHit").OnClientEvent:Fire("hit",{a=w.player.Character,v=char,dmg=12})
    w:advance(.8);assert(h.combatStatus:find("reports 12.0 damage",1,true));assert(h.combatStatus:find("HP change unconfirmed",1,true));h:close()
end)
test("an idle walk stops when its previously safe route develops a hole",function()
    local w,h=boot({survivalAFK=true});h.ui:toggle();w:advance(91);assert(h.walk)
    w.hole=true;w:advance(.3);eq(h.walk,nil);h:close()
end)
test("low frame rate reduces idle scans while active combat retains its scan cadence",function()
    local w,h=boot();for _=1,20 do w:step(.1)end
    h.nextScan=0;w:step(.1);assert(h.nextScan-w.time>.25)
    w.player:SetAttribute("FeralCombatUntil",w.time+1100);h.nextScan=0;w:step(.1);close(h.nextScan-w.time,.12);h:close()
end)
test("validated native minigame handles survive hot reload without a new callback search",function()
    local w=Mock.new();w:enableNativeGrab();local old=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local native=old.bridge.grabController;assert(native)
    local prior=w.env.getconnections;w.env.getconnections=function()error("unnecessary rediscovery")end
    local h=load(w,{settings={states={minigame=true}}});eq(h.bridge.grabController,native)
    w.env.getconnections=prior;w:advance(.2)
    local r=w:remote("FeralGrabV2");r.OnClientEvent:Fire("begin",{f=83,role="prey"})
    r.OnClientEvent:Fire("strike",{f=83,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215})
    w:advance(.5);eq(h.grab.presses,1);eq(old.closed,true);h:close()
end)
test("flight-eligible dive cancellation has the same guarded restart as a talon handoff",function()
    local w=Mock.new();w:enableVultureFlight();local c=w.player.Character;c:SetAttribute("Species","Eagle")
    w.configs.FlightConfig.canFly=function(char)return char==c end
    local h=load(w,{settings={states={flight=true}}});w:advance(.2)
    c:SetAttribute("FeralDiveLocal",91);assert(h.flightEpisode);c:SetAttribute("FeralDiveLocal",nil)
    w:advance(.85);eq(h.ledger.counts.post_attack_native_flight_restart,1)
    for _,call in ipairs(w.calls) do assert(call.args[1]~="release","no fabricated let-go intent") end
    h:close();eq(c:GetAttribute("FeralFlyDrop"),nil)
end)
test("ordinary ground abilities never create a later flight-restart episode",function()
    local w,h=boot({flight=true});w.player.Character:SetAttribute("FeralDiveLocal",91)
    w:advance(.2);w.player.Character:SetAttribute("FeralDiveLocal",nil);w:advance(1)
    eq(h.flightEpisode,nil);eq(h.ledger.counts.post_attack_native_flight_restart,nil);h:close()
end)
test("a player body that loses real-player ownership loses its overlays immediately",function()
    local w,h=boot({esp=true,tags=true});local player,char=w:enemy(2);w:advance(.2)
    local rec=h.ui.records[char];assert(rec.highlight.Enabled);assert(rec.label.Visible)
    h.nextScan=w.time+10;player.Character=nil;w:step(.016)
    eq(rec.highlight.Enabled,false);eq(rec.label.Visible,false);h:close()
end)
test("the small bite marker starts at a new target instead of gliding across unrelated bodies",function()
    local w,h=boot({biteHelper=true});local _,a,_,ar=w:enemy(2,Mock.V3.new(0,3,-5));w:advance(.2)
    local _,b,_,br=w:enemy(2,Mock.V3.new(3,3,-3));ar.Position=Mock.V3.new(0,3,-100);w:advance(.2)
    eq(h.guide.target.char,b)
    h.ui.lastTarget=a;h.ui.lastPoint=Mock.V2.new(-100,-100);h.ui:render(.016,w.time)
    local point=w.workspace.CurrentCamera:WorldToViewportPoint(br.Position)
    close(h.ui.lastPoint.X,point.X);close(h.ui.lastPoint.Y,point.Y);h:close()
end)
test("one deadline wake dispatches at the valid opening without waiting for heartbeat or render",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local r=w:remote("FeralGrabV2");local start=w.time+1000
    r.OnClientEvent:Fire("begin",{f=84,role="prey"})
    r.OnClientEvent:Fire("strike",{f=84,k=1,t0=start,spd=1,from=0,zc=.5,zw=.215})
    local p=h.grab.pending;assert(h.grabWake);eq(p.wakes,1)
    w.time+=p.at-start+.0001;w:runTimers()
    eq(h.grab.presses,1);eq(h.grabWake,nil);eq(next(w.timers),nil)
    w:advance(.2);eq(h.grab.presses,1);h:close()
end)
test("disable, session end, respawn and close cancel all pending deadline work",function()
    for _,action in ipairs({"disable","end","respawn","close"})do
        local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
        local r=w:remote("FeralGrabV2");r.OnClientEvent:Fire("begin",{f=85,role="prey"})
        r.OnClientEvent:Fire("strike",{f=85,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215});assert(h.grabWake)
        if action=="disable"then h:set("minigame",false)
        elseif action=="end"then r.OnClientEvent:Fire("end",{f=85})
        elseif action=="respawn"then w:spawn("Wolf")else h:close()end
        eq(h.grabWake,nil);eq(next(w.timers),nil);w:advance(.6);eq(h.grab.presses,0);h:close()
    end
end)
test("a delayed deadline wake schedules a later genuine crossing with its actual timestamp",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local r=w:remote("FeralGrabV2");local start=w.time+1000
    r.OnClientEvent:Fire("begin",{f=86,role="prey"})
    r.OnClientEvent:Fire("strike",{f=86,k=1,t0=start,spd=1,from=0,zc=.5,zw=.215})
    w.time+=.7;w:runTimers();eq(h.grab.presses,0);eq(h.grab.retimed,1);assert(h.grabWake)
    local p=h.grab.pending;w.time=p.at-1000+.0001;w:runTimers();eq(h.grab.presses,1)
    for _,call in ipairs(w.calls)do if call.name=="FeralGrabV2"then close(call.args[4],call.at+1000)end end
    h:close()
end)
test("deadline wakes respect focused text and retain the next valid opportunity",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local r=w:remote("FeralGrabV2");r.OnClientEvent:Fire("begin",{f=87,role="prey"})
    r.OnClientEvent:Fire("strike",{f=87,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215})
    w.chat={};w:advance(.7);eq(h.grab.presses,0);assert(h.grab.pending)
    w.chat=nil;w:advance(.9);eq(h.grab.presses,1);h:close()
end)
test("missing task scheduling retains the frame-based minigame path",function()
    local w=Mock.new();w:enableNativeGrab();w.env.task={}
    local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local r=w:remote("FeralGrabV2");r.OnClientEvent:Fire("begin",{f=88,role="prey"})
    r.OnClientEvent:Fire("strike",{f=88,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215})
    eq(h.grabWake,nil);w:advance(.5);eq(h.grab.presses,1);h:close()
end)
test("pathologically early scheduler wakes stay bounded instead of spinning",function()
    local w=Mock.new();w:enableNativeGrab();local schedule=w.env.task.delay
    w.env.task.delay=function(_,fn)return schedule(0,fn)end
    local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local r=w:remote("FeralGrabV2");r.OnClientEvent:Fire("begin",{f=89,role="prey"})
    r.OnClientEvent:Fire("strike",{f=89,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215})
    for _=1,8 do w:runTimers()end
    eq(h.grab.pending.wakes,4);eq(h.grab.presses,0);eq(next(w.timers),nil)
    w:advance(.5);eq(h.grab.presses,1);h:close()
end)
test("a transient unreadable native closure does not abandon a genuine pending strike",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local r=w:remote("FeralGrabV2");r.OnClientEvent:Fire("begin",{f=90,role="prey"})
    r.OnClientEvent:Fire("strike",{f=90,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215})
    local record=w.nativeRecords[h.bridge.grabController.press];local values=record.values
    record.values=function()return {}end
    w:advance(.5);eq(h.grab.active,true);eq(h.grab.presses,1);assert(h.grabInput.lease)
    record.values=values;w:advance(.1);eq(w.nativeGrabState().strike.pressed,true);h:close()
end)
test("a readable native closure with no live session still cancels an obsolete strike",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local r=w:remote("FeralGrabV2");r.OnClientEvent:Fire("begin",{f=92,role="prey"})
    r.OnClientEvent:Fire("strike",{f=92,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215})
    local record=w.nativeRecords[h.bridge.grabController.press];local values=record.values
    record.values=function()return {[2]=w.configs.GrabV2Config,[3]=r}end
    w:advance(.5);eq(h.grab.active,false);eq(h.grab.presses,0);eq(h.grabWake,nil)
    record.values=values;h:close()
end)
test("disabling during a temporary native read failure restores the active manual binding",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local r=w:remote("FeralGrabV2");r.OnClientEvent:Fire("begin",{f=93,role="prey"})
    r.OnClientEvent:Fire("strike",{f=93,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215})
    local record=w.nativeRecords[h.bridge.grabController.press];record.values=function()return {}end
    h:set("minigame",false);assert(w.cas:GetAllBoundActionInfo().FeralGrabV2Press)
    w:advance(.5);eq(h.grab.presses,0);eq(next(w.timers),nil);h:close()
end)
test("replacing one native level retires its old stamina lease without changing the other levels",function()
    local w=Mock.new();local levels={{stamina="drain",drain=1},{stamina="trot"}}
    w.configs.PassiveConfig.CLIMBER.levels=levels
    local h=load(w,{settings={states={stamina=true}}});w:advance(.2);local old=levels[1]
    levels[1]={stamina="drain",drain=2};w:advance(1.4)
    eq(old.drain,1);eq(old.stamina,"drain");eq(levels[1].drain,0);eq(levels[2].stamina,"trot")
    h:close();eq(levels[1].drain,2)
end)
test("a replaced minigame remote invalidates the cached controller identity",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local old=h.bridge.grabController;assert(old);local r=w:remote("FeralGrabV2");r:Destroy()
    local replacement=w.new("RemoteEvent");replacement.Name="FeralGrabV2";replacement.Parent=w.rs
    local current=h.bridge:nativeGrabController(w.time)
    assert(current~=old);h:close()
end)

test("aliased native climb levels no longer reject the whole stamina profile",function()
    local w=Mock.new();local shared={stamina="drain",drain=1}
    w.configs.PassiveConfig.CLIMBER.levels={shared,shared,{stamina="walk"}}
    local h=load(w,{settings={states={stamina=true}}});w:advance(.2)
    eq(h.registry.byId.stamina.applied,true);eq(h.features.leases:valid("stamina"),true)
    eq(w.player.Character:GetAttribute("WolfDbgNoStamina"),true)
    eq(w.configs.NeedsConfig.STAMINA_SPRINT_DRAIN,0);eq(shared.drain,0);eq(shared.stamina,"walk")
    local seen={}
    for _,entry in ipairs(h.features.leases.owners.stamina)do
        seen[entry.target]=seen[entry.target] or {};eq(seen[entry.target][entry.key],nil);seen[entry.target][entry.key]=true
    end
    h:close();eq(shared.drain,1);eq(shared.stamina,"drain")
    close(w.configs.NeedsConfig.STAMINA_SPRINT_DRAIN,.94);eq(w.player.Character:GetAttribute("WolfDbgNoStamina"),nil)
end)
test("aliased species climb-sprint profiles share one reversible stamina field",function()
    local w=Mock.new();local shared={DRAIN=.8,SPEED=1.5}
    w.configs.PassiveConfig.CLIMBER.CLIMB_SPRINT={Python=shared,Eagle=shared}
    local h=load(w,{settings={states={stamina=true}}});w:advance(.2)
    eq(h.registry.byId.stamina.applied,true);eq(shared.DRAIN,0);eq(shared.SPEED,1.5)
    h:set("stamina",false);eq(shared.DRAIN,.8);eq(w.player.Character:GetAttribute("WolfDbgNoStamina"),nil);h:close()
end)
test("equal aliased stamina intents coalesce while genuinely conflicting values are rejected",function()
    local M=modules();local t={drain=1}
    local plan=M.features.uniquePlan({{target=t,key="drain",value=0,kind="number"},{target=t,key="drain",value=0,kind="number"}})
    eq(#plan,1);eq(t.drain,1)
    local bad,why=M.features.uniquePlan({{target=t,key="drain",value=0,kind="number"},{target=t,key="drain",value=1,kind="number"}})
    eq(bad,nil);assert(why:find("conflicting aliased",1,true));eq(t.drain,1)
end)
test("case-distinct stamina fields remain separate and kind conflicts remain errors",function()
    local M=modules();local t={drain=1,DRAIN=.8}
    local p=M.features.uniquePlan({{target=t,key="drain",value=0,kind="number"},{target=t,key="DRAIN",value=0,kind="number"}})
    eq(#p,2)
    eq(M.features.uniquePlan({{target=t,key="drain",value=0,kind="number"},{target=t,key="drain",value=0}}),nil)
end)
test("shared stamina profiles still release and rearm across a new animal",function()
    local w=Mock.new();local shared={stamina="drain",drain=1}
    w.configs.PassiveConfig.CLIMBER.levels={shared,shared,shared}
    local h=load(w,{settings={states={stamina=true}}});w:advance(.2);local old=w.player.Character
    w:spawn("Hippo");w:advance(.2);eq(old:GetAttribute("WolfDbgNoStamina"),nil)
    eq(w.player.Character:GetAttribute("WolfDbgNoStamina"),true);eq(h.registry.byId.stamina.applied,true)
    h:close();eq(shared.drain,1);eq(shared.stamina,"drain")
end)

test("Hippo Crusher Bite releases native trot speed cap without affecting other species",function()
    local w=Mock.new()
    local crusher={SPEED_CAP="trot",CHARGE_TIME=1.2,FREEZE=.2}
    w:addConfig("AbilityConfig",{CrusherBite=crusher})
    local h=load(w,{settings={states={speed=false}}});w:advance(.3)
    eq(crusher.SPEED_CAP,"trot")
    w:spawn("Hippo");w:advance(1.5)
    eq(crusher.SPEED_CAP,"burst");eq(h.features.hippoStatus,"CLIENT")
    eq(h.registry.byId.speed.requested,false)
    w:advance(1.6);eq(crusher.SPEED_CAP,"burst")
    eq(crusher.CHARGE_TIME,1.2);eq(crusher.FREEZE,.2)
    w:spawn("Wolf");w:advance(1.5);eq(crusher.SPEED_CAP,"trot")
    h:close();eq(crusher.SPEED_CAP,"trot")
end)
test("Hippo Crusher Bite releases the exact original cap on shutdown",function()
    local w=Mock.new();local crusher={SPEED_CAP="trot"}
    w:addConfig("AbilityConfig",{CrusherBite=crusher});w:spawn("Hippo")
    local h=load(w,{settings={states={speed=true}}});w:advance(.3)
    eq(crusher.SPEED_CAP,"burst");eq(h.features.leases:valid("hippoCrush"),true)
    h:close();eq(crusher.SPEED_CAP,"trot")
    eq(w.configs.NeedsConfig.RUN_SPEED,1)
end)
test("Hippo cap refuses incompatible schema and preserves external config edits",function()
    local w=Mock.new();local crusher={SPEED_CAP="unknown"}
    w:addConfig("AbilityConfig",{CrusherBite=crusher});w:spawn("Hippo")
    local h=load(w);w:advance(.2);eq(crusher.SPEED_CAP,"unknown")
    eq(h.features.hippoStatus,"WAITING")
    crusher.SPEED_CAP="trot";w:advance(1.5);eq(crusher.SPEED_CAP,"burst")
    crusher.SPEED_CAP="custom";w:advance(1.5)
    eq(crusher.SPEED_CAP,"custom")
    h:close();eq(crusher.SPEED_CAP,"custom")
end)
test("Hippo cap falls back to current shared base profile without writing unknown ability tables",function()
    local w=Mock.new();local crusher={SPEED_CAP="trot"}
    w:addConfig("AbilityConfigBase",{Hippo={CrusherBite=crusher}})
    w:spawn("Hippo");local h=load(w);w:advance(.3)
    eq(crusher.SPEED_CAP,"burst")
    h:close();eq(crusher.SPEED_CAP,"trot")
end)

test("Hippo maximum cap never invents or toggles WolfBurst movement state",function()
    local w=Mock.new();local crusher={SPEED_CAP="trot",CHARGE_TIME=6,CD_HIT=50,CD_MISS=20}
    w:addConfig("AbilityConfigBase",{Hippo={CrusherBite=crusher}})
    w:spawn("Hippo")
    local char=w.player.Character
    local before=char:GetAttribute("WolfBurst")
    local h=load(w)
    w:advance(1.5)
    eq(crusher.SPEED_CAP,"burst")
    eq(char:GetAttribute("WolfBurst"),before)
    eq(crusher.CHARGE_TIME,6);eq(crusher.CD_HIT,50);eq(crusher.CD_MISS,20)
    h:close()
    eq(crusher.SPEED_CAP,"trot")
    eq(char:GetAttribute("WolfBurst"),before)
end)

test("Renaissance 15.8.3 presents its actual version in the active controller",function()
    local w=Mock.new();local h=load(w)
    eq(h.version,"15.8.3")
    h:close()
end)

test("zoom defaults on while a saved explicit OFF survives sanitization",function()
    local M=modules()
    eq(M.settings.sanitize({},M.core.specs).states.zoom,true)
    eq(M.settings.sanitize({states={zoom=false}},M.core.specs).states.zoom,false)
    local w,h=boot();eq(w.player.CameraMaxZoomDistance,100000);eq(w.player.CameraMinZoomDistance,.5)
    eq(h.registry.byId.zoom.applied,true);h:close();eq(w.player.CameraMaxZoomDistance,128)
end)
test("zoom staging leaves the current camera untouched and OFF restores owned limits",function()
    local w=Mock.new();w.player.CameraMinZoomDistance=6;w.player.CameraMaxZoomDistance=75
    w.player.CameraMode=E.CameraMode.LockFirstPerson
    local h=load(w,{stageOnly=true})
    eq(w.player.CameraMinZoomDistance,6);eq(w.player.CameraMaxZoomDistance,75)
    h:activate();eq(w.player.CameraMode,E.CameraMode.Classic);eq(w.player.CameraMaxZoomDistance,100000)
    h:set("zoom",false);eq(w.player.CameraMinZoomDistance,6);eq(w.player.CameraMaxZoomDistance,75)
    eq(w.player.CameraMode,E.CameraMode.LockFirstPerson)
    h:close();eq(w:connections(),0)
end)
test("native zoom changes are reapplied and the new defaults return on unload",function()
    local w,h=boot()
    w.player.CameraMaxZoomDistance=40;eq(w.player.CameraMaxZoomDistance,100000)
    w.player.CameraMinZoomDistance=4;eq(w.player.CameraMinZoomDistance,.5)
    h:close();eq(w.player.CameraMaxZoomDistance,40);eq(w.player.CameraMinZoomDistance,4)
    w.player.CameraMaxZoomDistance=90;eq(w.player.CameraMaxZoomDistance,90);eq(w:connections(),0)
end)
test("zoom reload does not stack observers or capture the expanded limit as the original",function()
    local w,h=boot();local count=w:connections()
    local nextHub=load(w)
    eq(h.closed,true);eq(w:connections(),count);eq(w.player.CameraMaxZoomDistance,100000)
    nextHub:close();eq(w.player.CameraMaxZoomDistance,128);eq(w:connections(),0)
end)
test("zoom never changes camera pose, subject or scripted camera type",function()
    local w=Mock.new();local camera=w.workspace.CurrentCamera
    camera.CameraType=E.CameraType.Scriptable;local pose=camera.CFrame;local subject=camera.CameraSubject
    local h=load(w);eq(camera.CameraType,E.CameraType.Scriptable);eq(camera.CFrame,pose);eq(camera.CameraSubject,subject)
    h:close();eq(camera.CameraType,E.CameraType.Scriptable);eq(camera.CFrame,pose)
end)
test("zoom partial observer failure unwinds without leaving camera writes",function()
    local M,w=modules();local called=0
    rawset(w.player,"GetPropertyChangedSignal",function()
        called+=1;if called==2 then error("observation unavailable") end
        return {Connect=function()return {Disconnect=function()called+=10 end}end}
    end)
    local z=M.zoom.new(w.player);eq(z:set(true),false)
    eq(z.active,false);eq(w.player.CameraMaxZoomDistance,128);eq(called,12);z:close()
end)

local function hippoWorld()
    local w=Mock.new();w:spawn("Hippo");w.keys={}
    function w.uis:IsKeyDown(key)return w.keys[key]==true end
    local profile={speed=30,gait=36,walkMul=.7,swimSpeed=20,swimSprint=27}
    local native=function(species,field,growth)
        if species~="Hippo" then return 12 end
        return (profile[field] or 0)*(growth or 1)
    end
    w:addConfig("Species",{List={Hippo=profile},scaled=native})
    w.configs.NeedsConfig.BURST={ENABLED=true,SPEED=1.45,SWIM_SPEED=1.3}
    w:addConfig("AbilityConfig",{CrusherBite={SPEED_CAP="trot"}})
    local h=load(w);w:step(.1)
    local function chargeSpeed(growth)
        -- Reconstructed arithmetic from v2412 WolfMove 3092-3104;
        -- native run remains false, so its forced-trot branch consumes gait.
        return 16.8/42*w.configs.Species.scaled("Hippo","gait",growth)*profile.walkMul
    end
    return w,h,native,chargeSpeed
end
local function nativeGaitHUD(w)
    local new=w.new
    local gui=new("ScreenGui");gui.Name="FeralHUD";gui.Parent=w.player:FindFirstChild("PlayerGui")
    local cluster=new("Frame");cluster.Name="Cluster";cluster.Parent=gui
    local bright=w.env.Color3.fromRGB(255,190,120)
    local quiet=w.env.Color3.fromRGB(95,95,95)
    local keys={}
    for _,name in ipairs({"trot","sprint","burst"}) do
        local outline=new("Frame");outline.Name=name;outline.Parent=cluster
        local cap=new("Frame");cap.Name="Cap";cap.Parent=outline
        local rim=new("UIStroke");rim.Color=name=="trot" and bright or quiet;rim.Parent=cap
        cap.BackgroundTransparency=name=="trot" and .15 or .42
        keys[name]={cap=cap,rim=rim}
    end
    return gui,keys,bright,quiet
end
test("Hippo assisted sprint and Burst highlight the original HUD keycaps without changing gameplay flags",function()
    local w,h,_,speed=hippoWorld();local gui,keys,bright,quiet=nativeGaitHUD(w)
    local char=w.player.Character
    w.player:SetAttribute("HudTrot",true);w.player:SetAttribute("HudSprint",false)
    w.player:SetAttribute("HudBurst",false)
    char:SetAttribute("FeralCrushAt",w.time+1000);w.keys[E.KeyCode.LeftShift]=true
    w:step(.02);close(speed(1),30)
    eq(keys.sprint.rim.Color,bright);eq(keys.sprint.cap.BackgroundTransparency,.15)
    eq(keys.trot.rim.Color,quiet);eq(keys.trot.cap.BackgroundTransparency,.42)
    w.uis.InputBegan:Fire({KeyCode=E.KeyCode.X,UserInputType=E.UserInputType.Keyboard},true)
    w:step(.02);close(speed(1),43.5)
    eq(keys.burst.rim.Color,bright);eq(keys.sprint.rim.Color,quiet)
    eq(w.player:GetAttribute("HudTrot"),true)
    eq(w.player:GetAttribute("HudSprint"),false)
    eq(w.player:GetAttribute("HudBurst"),false)
    w.keys[E.KeyCode.LeftShift]=false;char:SetAttribute("FeralCrushAt",nil);w:step(.02)
    eq(keys.trot.rim.Color,bright);eq(keys.sprint.rim.Color,quiet)
    eq(keys.burst.cap.BackgroundTransparency,.42)
    h:close();eq(gui._destroyed,false)
end)
test("Hippo HUD reverts on Burst denial, movement OFF, character change and unload",function()
    local w,h=hippoWorld();local _,keys,bright,quiet=nativeGaitHUD(w)
    local char=w.player.Character
    char:SetAttribute("FeralCrushAt",w.time+1000)
    w.uis.InputBegan:Fire({KeyCode=E.KeyCode.X,UserInputType=E.UserInputType.Keyboard},true)
    w:step(.02);eq(keys.burst.rim.Color,bright)
    w.player:SetAttribute("HudBurstNo",true);w:step(.02)
    eq(keys.trot.rim.Color,bright);eq(keys.burst.rim.Color,quiet)
    w.player:SetAttribute("HudBurstNo",nil);w.keys[E.KeyCode.LeftShift]=true
    w:step(.02);eq(keys.sprint.rim.Color,bright)
    h:set("hippoMove",false);w:step(.02);eq(keys.trot.rim.Color,bright)
    h:set("hippoMove",true);w:step(.02);eq(keys.sprint.rim.Color,bright)
    w:spawn("Wolf");w:step(.02);eq(keys.trot.rim.Color,bright)
    h:close();eq(keys.sprint.rim.Color,quiet)
end)
test("Hippo HUD survives absent and rebuilt native UI and respects external style changes",function()
    local w,h=hippoWorld();local char=w.player.Character
    char:SetAttribute("FeralCrushAt",w.time+1000);w.keys[E.KeyCode.LeftShift]=true
    w:step(.02);assert(h.active)
    local gui,keys,bright=nativeGaitHUD(w);w:step(.02)
    eq(keys.sprint.rim.Color,bright)
    gui:Destroy();w:step(.02);assert(h.active)
    local _,rebuilt,rebuiltBright=nativeGaitHUD(w);w:step(.02)
    eq(rebuilt.sprint.rim.Color,rebuiltBright)
    local external=w.env.Color3.fromRGB(20,225,35)
    rebuilt.burst.rim.Color=external
    h:close();eq(rebuilt.burst.rim.Color,external)
end)
test("Hippo charge sprint repairs the consumed gait calculation rather than only a cap label",function()
    local w,h,original,speed=hippoWorld();local char=w.player.Character
    char:SetAttribute("FeralCrushAt",w.time+1000);w.keys[E.KeyCode.LeftShift]=true
    close(speed(.8),original("Hippo","speed",.8)*w.configs.NeedsConfig.RUN_SPEED)
    eq(char:GetAttribute("FeralCrushAt"),w.time+1000);eq(char:GetAttribute("WolfBurst"),nil)
    h:close();eq(w.configs.Species.scaled,original)
end)
test("Hippo charge Burst input chooses the native NeedsConfig burst multiplier",function()
    local w,h,original,speed=hippoWorld();local char=w.player.Character
    char:SetAttribute("FeralCrushAt",w.time+1000)
    w.uis.InputBegan:Fire({KeyCode=E.KeyCode.X,UserInputType=E.UserInputType.Keyboard},true)
    close(speed(1),original("Hippo","speed",1)*1.45)
    w.uis.InputBegan:Fire({KeyCode=E.KeyCode.X,UserInputType=E.UserInputType.Keyboard},true)
    close(speed(1),16.8/42*original("Hippo","gait",1)*.7)
    h:close()
end)
test("Hippo charge preserves ordinary walk trot other species and ability release",function()
    local w,h,original,speed=hippoWorld();local char=w.player.Character
    char:SetAttribute("FeralCrushAt",w.time+1000)
    close(speed(1),16.8/42*original("Hippo","gait",1)*.7)
    close(w.configs.Species.scaled("Wolf","gait",1),12)
    w.keys[E.KeyCode.LeftShift]=true;char:SetAttribute("FeralCrushAt",nil)
    close(w.configs.Species.scaled("Hippo","gait",1),original("Hippo","gait",1));h:close()
end)
test("Hippo water charge uses native swimSprint and native water Burst multiplier",function()
    local w,h,original=hippoWorld();w.player.Character:SetAttribute("FeralCrushAt",w.time+1000)
    w.keys[E.KeyCode.LeftShift]=true
    close(w.configs.Species.scaled("Hippo","swimSpeed",1),original("Hippo","swimSprint",1))
    w.uis.InputBegan:Fire({KeyCode=E.KeyCode.X,UserInputType=E.UserInputType.Keyboard},true)
    close(w.configs.Species.scaled("Hippo","swimSpeed",1),original("Hippo","swimSprint",1)*1.3)
    h:close()
end)
test("Hippo input respects native Burst denial and native capture restrictions",function()
    local w,h,original,speed=hippoWorld();local char=w.player.Character
    char:SetAttribute("FeralCrushAt",w.time+1000)
    w.uis.InputBegan:Fire({KeyCode=E.KeyCode.X,UserInputType=E.UserInputType.Keyboard},true)
    w.player:SetAttribute("HudBurstNo",w.time)
    close(speed(1),16.8/42*original("Hippo","gait",1)*.7)
    w.keys[E.KeyCode.LeftShift]=true;char:SetAttribute("FeralPinned",true)
    close(speed(1),16.8/42*original("Hippo","gait",1)*.7);h:close()
end)
test("Hippo calculation wrapper restores on species change and never writes movement fields",function()
    local w,h,original=hippoWorld();local char=w.player.Character
    char:SetAttribute("FeralCrushAt",w.time+1000);w.keys[E.KeyCode.LeftShift]=true
    w:resetMetrics();w.configs.Species.scaled("Hippo","gait",1)
    eq(w.metrics.writes["Humanoid:WalkSpeed"],nil);eq(w.metrics.writes["Part:AssemblyLinearVelocity"],nil)
    w:spawn("Wolf");w:step(.1);eq(w.configs.Species.scaled,original);h:close()
end)
test("Hippo charge preserves known Burst intent at the ability-start event",function()
    local w,h,original,speed=hippoWorld()
    w.uis.InputBegan:Fire({KeyCode=E.KeyCode.X,UserInputType=E.UserInputType.Keyboard},true)
    w.player.Character:SetAttribute("FeralCrushAt",w.time+1000)
    close(speed(1),original("Hippo","speed",1)*1.45);h:close()
end)
test("Hippo external scalar edits retain ownership across repeated reconciliation",function()
    local w,h=hippoWorld();local external=function()return 99 end
    w.configs.Species.scaled=external;w:step(.1);w:step(.1);w:step(.1)
    eq(w.configs.Species.scaled,external);h:close();eq(w.configs.Species.scaled,external)
end)
test("Hippo trot selection cancels Burst intent and unrelated crouch restrictions remain native",function()
    local w,h,original,speed=hippoWorld();local char=w.player.Character
    char:SetAttribute("FeralCrushAt",w.time+1000)
    w.uis.InputBegan:Fire({KeyCode=E.KeyCode.X,UserInputType=E.UserInputType.Keyboard},true)
    close(speed(1),original("Hippo","speed",1)*1.45)
    w.uis.InputBegan:Fire({KeyCode=E.KeyCode.Z,UserInputType=E.UserInputType.Keyboard},true)
    close(speed(1),16.8/42*original("Hippo","gait",1)*.7)
    w.keys[E.KeyCode.LeftShift]=true;char:SetAttribute("FeralCrouch",true)
    close(speed(1),16.8/42*original("Hippo","gait",1)*.7);h:close()
end)
test("client bite cadence follows the actual native calculation and restores exactly",function()
    local w=Mock.new();local original=function()return .6 end
    w:addConfig("Species",{DEFAULT="Wolf",biteCooldown=original});w:enableNativeActions()
    local h=load(w,{settings={states={attackSpeed=true}}});w:advance(.2)
    close(w.configs.Species.biteCooldown("Wolf",1),.33)
    close(w.configs.Species.biteCooldown("Bear",1),.6)
    eq(h.registry.byId.attackSpeed.applied,true);eq(h.registry.byId.attackSpeed.outcome,"unverified")
    h:set("attackSpeed",false);eq(w.configs.Species.biteCooldown,original)
    h:close()
end)
test("cadence adjustment never slows an already faster native profile",function()
    local w=Mock.new();w:addConfig("Species",{biteCooldown=function()return .1 end})
    local h=load(w,{settings={states={attackSpeed=true}}});w:advance(.2)
    close(w.configs.Species.biteCooldown("Wolf",1),.1);h:close()
end)
test("cadence refuses unknown game versions and preserves external ownership",function()
    local w=Mock.new();local original=function()return .6 end
    w:addConfig("Species",{biteCooldown=original});w.env.game.PlaceVersion=2413
    local h=load(w,{settings={states={attackSpeed=true}}});w:advance(.2)
    eq(w.configs.Species.biteCooldown,original);eq(h.registry.byId.attackSpeed.applied,false)
    w.env.game.PlaceVersion=2412;h.features.nextReconcile=0;w:advance(.2)
    local external=function()return .9 end;w.configs.Species.biteCooldown=external
    w:advance(1.4);eq(w.configs.Species.biteCooldown,external);eq(h.registry.byId.attackSpeed.applied,false)
    h:close();eq(w.configs.Species.biteCooldown,external)
end)
test("held bite schedules original native attempts and stops immediately on release",function()
    local w=Mock.new();w:addConfig("Species",{biteCooldown=function()return .6 end});w:enableNativeActions()
    local h=load(w,{settings={states={attackSpeed=true}}});w:advance(.3)
    w.held=E.UserInputType.MouseButton1;w:input(nil,E.UserInputType.MouseButton1);w:advance(1.4)
    assert((w.nativeBites or 0)>=5 and w.nativeBites<=6)
    local cadence=h.tests:bridgeReport().biteCadence
    eq(cadence.markers,w.nativeBites)
    assert(cadence.activeIntervals>=4 and cadence.measuredBitesPerSecond>2)
    local count=w.nativeBites;w.held=nil;w:advance(.8);eq(w.nativeBites,count)
    eq(h.registry.byId.attackSpeed.outcome,"unverified");h:close()
end)
test("hold-to-repeat stays independent of faster bite cooldown and can be disabled",function()
    local w=Mock.new();local base=function()return .6 end
    w:addConfig("Species",{biteCooldown=base});w:enableNativeActions()
    local h=load(w,{settings={states={holdBite=true,attackSpeed=false}}});w:advance(.3)
    eq(w.configs.Species.biteCooldown,base)
    w.held=E.UserInputType.MouseButton1;w:input(nil,E.UserInputType.MouseButton1);w:advance(1.4)
    assert((w.nativeBites or 0)>=3)
    h:set("holdBite",false);local count=w.nativeBites;w:advance(.9)
    eq(w.nativeBites,count);eq(w.configs.Species.biteCooldown,base)
    h:close()
end)
test("held bite waits out Hippo ability then resumes while left click remains down",function()
    local w=Mock.new();w:addConfig("Species",{biteCooldown=function()return .6 end});w:enableNativeActions()
    local h=load(w,{settings={states={holdBite=true,attackSpeed=false}}});w:advance(.3)
    w.held=E.UserInputType.MouseButton1;w:input(nil,E.UserInputType.MouseButton1);w:advance(.15)
    local char=w.player.Character;char:SetAttribute("FeralCrushAt",w.time+1000)
    local count=w.nativeBites;w:advance(.9);eq(w.nativeBites,count)
    char:SetAttribute("FeralCrushAt",nil);w:advance(.8)
    assert(w.nativeBites>count);w.held=nil;h:close()
end)
test("a bite without a native marker pauses held retries",function()
    local M=modules();local char={};local count,events=0,{}
    local bridge={biteDelay=function()return .27 end,restLock=function()return .7 end,
        biteReadiness=function()return {ready=true}end,
        tryNativeBite=function()count+=1;return true end}
    local policy={restLocked=function()return false end}
    local ledger={event=function(_,name)table.insert(events,name)end}
    local c=M.combat_input.new(bridge,policy,ledger)
    local s={alive=true,char=char,generation=1,attackHeld=true}
    c:input(s,0)
    for _,now in ipairs({0,.1,.2,.3,.36,.4,.62}) do c:tick(s,now,{repeatHeld=true}) end
    eq(count,2);eq(events[2],"native_bite_marker_timeout")
    s.attackHeld=false;c:tick(s,.61,{repeatHeld=true});eq(c.held,nil)
end)
test("Auto Bite requires current clear contact and stops for a newly friendly target",function()
    local w=Mock.new();w:enableNativeActions()
    local other,char=w:enemy(2,Mock.V3.new(0,3,-4))
    local h=load(w,{settings={states={autoBite=true,attackSpeed=false}}});w.blocked=true;w:advance(.6)
    eq(w.nativeBites,nil);w.blocked=false;w:advance(.8);assert((w.nativeBites or 0)>0)
    other:SetAttribute("FeralPack",1);char:SetAttribute("FeralPack",1)
    local count=w.nativeBites;w:advance(.8);eq(w.nativeBites,count);h:close()
end)
test("Auto Bite never invents attacks when native callbacks are inaccessible",function()
    local w=Mock.new();w:enemy(2,Mock.V3.new(0,3,-4))
    local h=load(w,{settings={states={autoBite=true}}});w:advance(1)
    for _,call in ipairs(w.calls)do assert(call.name~="WolfActions" or call.args[1]~="Bite")end
    eq(h.registry.byId.autoBite.applied,false);h:close()
end)
test("fresh attack checks reject a wall that appeared after target selection",function()
    local w,h=boot();w:enemy(2,Mock.V3.new(0,3,-4));w:advance(.3)
    assert(h.guide and h.bridge:autoAttackTarget(h.snapshot,h.guide,h.features.combat))
    w.blocked=true;eq(h.bridge:autoAttackTarget(h.snapshot,h.guide,h.features.combat),false);h:close()
end)
test("prediction uses bounded relative velocity without moving either character",function()
    local w,h=boot();local _,char,hum,root=w:enemy(2,Mock.V3.new(0,3,-4))
    root.AssemblyLinearVelocity=Mock.V3.new(100,10,0);w:advance(.2)
    local before=root.Position;local point=h.bridge:leadPoint(h.snapshot,{char=char,hum=hum,root=root})
    close((point-before).Magnitude,4);eq(root.Position,before);eq(point.Y,before.Y);h:close()
end)
test("hit replies match the victim instead of the newest unrelated attack",function()
    local M=modules();local a,b={},{}
    local first={nativeAt=10,claimDue=10.27,nativeTarget=a}
    local second={nativeAt=10.2,claimDue=10.47,nativeTarget=b}
    eq(M.controller.matchFeedback(M.core,{first,second},{v=a,dmg=8},10.5),first)
end)
test("indistinguishable hit replies remain unmatched",function()
    local M=modules();local victim={}
    local tx,ambiguous=M.controller.matchFeedback(M.core,{
        {nativeAt=10,claimDue=10.27,nativeTarget=victim},
        {nativeAt=10.04,claimDue=10.31,nativeTarget=victim}}, {v=victim,dmg=8},10.29)
    eq(tx,nil);eq(ambiguous,true)
end)
test("reply ambiguity uses the nearest two transactions regardless of iteration order",function()
    local M=modules();local victim={}
    local tx,ambiguous=M.controller.matchFeedback(M.core,{
        {nativeAt=10,claimDue=10.1,nativeTarget=victim},
        {nativeAt=10.03,claimDue=10.13,nativeTarget=victim},
        {nativeAt=10.07,claimDue=10.17,nativeTarget=victim}}, {v=victim,dmg=8},10.2)
    eq(tx,nil);eq(ambiguous,true)
end)
test("burst stamina drain follows a replaced native profile and restores both tables",function()
    local w=Mock.new();local first={DRAIN=3.9,ENABLED=true}
    w.configs.NeedsConfig.BURST=first
    local h=load(w,{settings={states={stamina=true}}});w:advance(.2);eq(first.DRAIN,0)
    local second={DRAIN=2,ENABLED=true};w.configs.NeedsConfig.BURST=second
    w:advance(1.4);eq(first.DRAIN,3.9);eq(second.DRAIN,0)
    h:close();eq(second.DRAIN,2);eq(second.ENABLED,true)
end)
test("small positive conditions retain recovery eligibility in combat",function()
    local w=Mock.new();w.player.Character:SetAttribute("FeralVenomAmt",.01)
    w.player:SetAttribute("FeralCombatUntil",w.time+1100)
    local h=load(w,{settings={states={recovery=true}}});w:advance(.3)
    eq(h.recovery.purpose,"effects");eq(h.recovery.owned,w.player.Character)
    eq(w.configs.NeedsConfig.HEALTH_NO_REGEN_IN_COMBAT,true);h:close()
end)
test("nonfinite condition values never keep a healthy animal in automatic Rest",function()
    local w=Mock.new();w.player.Character:SetAttribute("FeralVenomAmt",1/0)
    local h=load(w,{settings={states={recovery=true}}});w:advance(.3)
    eq(h.recovery.owned,nil);h:close()
end)
test("new settings retain Hippo tab, explicit OFF and manual release by default",function()
    local M=modules();local settings=M.settings.sanitize({tab="Hippo",states={attackSpeed=false,hippoMove=false}},M.core.specs)
    eq(settings.tab,"Hippo");eq(settings.states.attackSpeed,false);eq(settings.states.hippoMove,false)
    eq(settings.states.hippoRelease,false);eq(settings.states.autoBite,false)
end)
local function chargeWorld(smart)
    local w=Mock.new();w:spawn("Hippo");local profile=w:enableNativeHippo()
    local _,victim=w:enemy(2,Mock.V3.new(0,3,-4))
    local h=load(w,{settings={states={hippoRelease=smart,attackSpeed=false}}});w:advance(.3)
    return w,h,profile,victim
end
test("smart Crusher waits for full charge then uses one original timestamp-free call",function()
    local w,h,profile=chargeWorld(true);w.startHippoCharge();w:advance(5.8)
    eq(w.nativeHippoReleases,nil);w:advance(.4);eq(w.nativeHippoReleases,1)
    w:advance(.5);eq(w.nativeHippoReleases,1);eq(profile.MULT_MAX,3.5);eq(profile.CHARGE_TIME,6)
    local releases=0
    for _,call in ipairs(w.calls)do
        if call.name=="FeralHippo" and call.args[1]=="release" then releases+=1;eq(call.args.n,2) end
    end
    eq(releases,1);eq(#h.hippo.history,1);eq(h.hippo.history[1].acceptedDamage,"unverified");h:close()
end)
test("manual Crusher holds retain the original multiplier, overhold and cooldowns",function()
    local w,h,p=chargeWorld(false);w.startHippoCharge();w:advance(9)
    eq(w.nativeHippoReleases,nil);close(h.hippo.session.multiplier,3.5)
    eq(p.CHARGE_TIME,6);eq(p.OVERHOLD,8);eq(p.CD_HIT,50);eq(p.CD_MISS,20)
    w.uis.InputEnded:Fire({KeyCode=E.KeyCode.F});eq(w.nativeHippoReleases,1)
    close(h.hippo.history[1].heldFor,9);h:close()
end)
test("Crusher release keeps automatic recovery out of the native impact window",function()
    local w,h=chargeWorld(true);h:set("recovery",true);w.hum.Health=60
    w.startHippoCharge();w:advance(6.3);eq(w.nativeHippoReleases,1)
    eq(h.recovery.owned,nil);w:advance(.5);eq(h.recovery.owned,nil)
    w:advance(1);eq(h.recovery.owned,w.player.Character);h:close()
end)
test("smart release rechecks obstruction after reaching full charge",function()
    local w,h=chargeWorld(true);w.blocked=true;w.startHippoCharge();w:advance(6.2)
    eq(w.nativeHippoReleases,nil);w.blocked=false;w:advance(.3);eq(w.nativeHippoReleases,1);h:close()
end)
test("smart Crusher retains its charge in extended-only range",function()
    local w,h=chargeWorld(true)
    local target=h.guide.target.root;target.Position=Mock.V3.new(0,3,-9)
    w.startHippoCharge();w:advance(6.2);eq(w.nativeHippoReleases,nil)
    target.Position=Mock.V3.new(0,3,-4);w:advance(.3);eq(w.nativeHippoReleases,1);h:close()
end)
for _,guard in ipairs({"chat","menu","capture","feeding","holding","underwater","rest"})do
    test("smart Crusher preserves native "..guard.." restrictions",function()
        local w,h=chargeWorld(true);w.startHippoCharge()
        if guard=="chat" then w.chat={}
        elseif guard=="menu" then w.player:SetAttribute("FeralMenuOpen",true)
        elseif guard=="capture" then w.player.Character:SetAttribute("FeralPinned",true)
        elseif guard=="feeding" then w.player.Character:SetAttribute("WolfFeed","eat")
        elseif guard=="holding" then w.player.Character:SetAttribute("FeralCarcassCarry",true)
        elseif guard=="underwater" then w.player.Character:SetAttribute("FeralUnderwater",true)
        elseif guard=="rest" then w.player.Character:SetAttribute("WolfRest",true) end
        w:advance(6.2);eq(w.nativeHippoReleases,nil);h:close()
    end)
end
test("smart release refuses a stale script or substituted remote",function()
    local w,h=chargeWorld(true);assert(h.hippo.native)
    local old=w:remote("FeralHippo");old.Parent=nil
    local replacement=w.new("RemoteEvent");replacement.Name="FeralHippo";replacement.Parent=w.rs
    w.startHippoCharge();w:advance(6.2);eq(w.nativeHippoReleases,nil);h:close()
end)
test("species change stops Hippo automation and leaves another crusher profile untouched",function()
    local w,h,p=chargeWorld(true);local lockjaw={CHARGE_TIME=3,MULT_MAX=4}
    w.configs.AbilityConfig.Lockjaw=lockjaw;w.startHippoCharge();w:advance(2)
    w:spawn("SnappingTurtle");w:advance(5);eq(w.nativeHippoReleases,nil)
    eq(lockjaw.CHARGE_TIME,3);eq(lockjaw.MULT_MAX,4);eq(p.MULT_MAX,3.5);h:close()
end)
test("turning smart release off or unloading never cancels a manual charge",function()
    local w,h=chargeWorld(true);w.startHippoCharge();w:advance(2)
    h:set("hippoRelease",false);w:advance(5);eq(w.nativeHippoReleases,nil)
    local active=w.nativeHippoState();assert(active);h:close();eq(w.nativeHippoState(),active)
end)
test("Hippo charge and native release discovery need no heap enumeration",function()
    local w,h=chargeWorld(true);assert(h.hippo.native)
    eq(w.metrics.heap,0);h.ui:selectTab("Hippo");w:advance(.3)
    assert(h.ui.hippoReadout.Text:find("3.50",1,true));h:close()
end)
test("Hippo move controls restore the shared scalar without removing ordinary speed assistance",function()
    local w,h,original=hippoWorld();h:set("speed",true)
    h:set("hippoMove",false);eq(w.configs.Species.scaled,original)
    close(w.configs.NeedsConfig.RUN_SPEED,1.15)
    h:set("hippoMove",true);assert(w.configs.Species.scaled~=original)
    h:close();eq(w.configs.Species.scaled,original);close(w.configs.NeedsConfig.RUN_SPEED,1)
end)
test("R2 held assistance observes gamepad input and releases cleanly",function()
    local w=Mock.new();w:enableNativeActions()
    local h=load(w,{settings={states={attackSpeed=true}}});w:advance(.2)
    w.padHeld=E.KeyCode.ButtonR2;w:input(E.KeyCode.ButtonR2,E.UserInputType.Gamepad1);w:advance(1.1)
    assert((w.nativeBites or 0)>=3);local count=w.nativeBites
    w.padHeld=nil;w:advance(.8);eq(w.nativeBites,count);h:close()
end)
test("native minigames suppress automatic attack scheduling",function()
    local w=Mock.new();w:enableNativeActions();w:enableNativeGrab();w:enemy(2,Mock.V3.new(0,3,-4))
    local h=load(w,{settings={states={autoBite=true,minigame=true}}});w:advance(.3)
    w:remote("FeralGrabV2").OnClientEvent:Fire("begin",{f=400,role="prey",n=4})
    local count=w.nativeBites;w:advance(1);eq(w.nativeBites,count);h:close()
end)
test("automatic attacks preserve territory ownership",function()
    local w=Mock.new();w:enableNativeActions();w:enemy(2,Mock.V3.new(0,3,-4))
    local h=load(w,{settings={states={autoBite=true}}})
    h.territory.agent.enabled=true;h.territory.tick=function()end
    w:advance(.8);eq(w.nativeBites,nil);h:close()
end)
test("a changed charge profile requires manual release for the existing session",function()
    local w,h,p=chargeWorld(true);w.startHippoCharge();w:advance(2)
    w.configs.AbilityConfig.CrusherBite=table.clone(p);w:advance(5)
    eq(w.nativeHippoReleases,nil);h:close()
end)
test("unknown game versions never attempt smart release",function()
    local w,h=chargeWorld(true);w.env.game.PlaceVersion=2413;w.startHippoCharge();w:advance(6.2)
    eq(w.nativeHippoReleases,nil);eq(h.hippo.session,nil);h:close()
end)
test("a same-name release function from another script is rejected",function()
    local w,h=chargeWorld(true)
    w.nativeRecords[w.nativeHippoFinish].script="UnrelatedClient"
    w.startHippoCharge();w:advance(6.2);eq(w.nativeHippoReleases,nil);h:close()
end)
test("malformed charge timing never becomes an automatic release",function()
    local w,h,p=chargeWorld(true);p.CHARGE_TIME=0;w.startHippoCharge();w:advance(1)
    eq(w.nativeHippoReleases,nil);eq(h.hippo.profileValue,nil);h:close()
end)
test("Hippo history is bounded and native damage replies remain unattributed",function()
    local w,h,p,victim=chargeWorld(false)
    for _=1,16 do w.startHippoCharge();w:advance(.04);w.nativeHippoFinish() end
    eq(#h.hippo.history,12)
    h.hippo:feedback({a=w.player.Character,v=victim,dmg=12},w.time)
    local last=h.hippo.history[#h.hippo.history]
    eq(last.gameReportedDamage,12);eq(last.attribution,"unverified");eq(last.acceptedDamage,"unverified")
    h:close();eq(#h.hippo.history,0)
end)
test("Hippo callback discovery and tab rendering leave no hub listeners on unload",function()
    local w=Mock.new();w:spawn("Hippo");w:enableNativeHippo();local before=w:connections()
    local h=load(w,{settings={states={hippoRelease=true}}});w:advance(.3)
    h.ui:selectTab("Hippo");w:advance(.2);h.ui:selectTab("Territory");h.ui:selectTab("Hippo")
    w:advance(.2);assert(h.active);h:close();eq(w:connections(),before)
end)
test("Test Features saves own HP observations for every species without counting max-HP changes",function()
    local w,h=boot()
    h.ui:selectTab("Test Features")
    eq(w.stored[h.tests.path]~=nil,true)
    w.hum.Health=90
    w.hum.MaxHealth=120
    w.hum.Health=80
    w.player.Character:SetAttribute("WolfRest",true)
    w.hum.Health=72
    eq(h.tests.species.Wolf.hits,2)
    eq(h.tests.species.Wolf.damage,18)
    eq(h.tests.species.Wolf.restHits,1)
    local turtle=w:spawn("SnappingTurtle")
    w.hum.Health=85
    eq(h.tests.species.SnappingTurtle.hits,1)
    h.tests:save()
    local stored=w.env.game:GetService("HttpService"):JSONDecode(w.stored[h.tests.path])
    eq(stored.schema,"FERAL_RENAISSANCE_TESTS_V1")
    eq(stored.species.Wolf.damage,18)
    eq(stored.snapshot.species,"SnappingTurtle")
    eq(stored.features.zoom.requested,true)
    assert(stored.ledgerCounts.character_generation>=2)
    h:close();eq(w:connections(),0)
end)
test("Test Features one-shot Turtle request is gated and releases once",function()
    local w=Mock.new();w:spawn("SnappingTurtle")
    local remote=w.new("RemoteEvent");remote.Name="FeralHippo";remote.Parent=w.rs
    local h=load(w)
    eq(h.tests:crossSpecies(),false)
    eq(#w.calls,0)
    w.player.Character:SetAttribute("WolfRest",true)
    w.player.Character:SetAttribute("WolfRestAt",w.time+998)
    eq(h.tests:crossSpecies(),true)
    eq(h.tests:crossSpecies(),false)
    w:advance(6.2)
    local requests=0
    for _,call in ipairs(w.calls) do
        if call.name=="FeralHippo" then requests+=1 end
    end
    eq(requests,2)
    eq(h.tests.pending,nil)
    eq(h.tests.attempts,1)
    h:close();eq(w:connections(),0)
end)
print(string.format("RENAISSANCE_TEST_RESULT total=%d passed=%d failed=%d",tests,tests-#failures,#failures))
if #failures>0 then error(table.concat(failures,"\n"),0) end
