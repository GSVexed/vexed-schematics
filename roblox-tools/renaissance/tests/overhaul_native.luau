-- Native-contract regressions appended to suite.luau by run_tests.py.
test("overhaul replacement condition profiles receive current recovery and movement leases",function()
    local w,h=boot({recovery=true,mobility=true})
    local old=w.configs.StatusConfig.INJURY
    local nextProfile={HEAL=.9,REST_MULT=8,SLOW_PER_POINT=.25}
    w.configs.StatusConfig.INJURY=nextProfile;w:advance(1.4)
    close(old.SLOW_PER_POINT,.1);close(nextProfile.HEAL,.9);close(nextProfile.SLOW_PER_POINT,0)
    eq(h.registry.byId.effects.applied,true);eq(h.registry.byId.mobility.applied,true)
    h:close();close(nextProfile.HEAL,.9);close(nextProfile.SLOW_PER_POINT,.25)
end)

test("overhaul replacement climb subtree releases the detached profile",function()
    local w,h=boot({climb=true,stamina=true})
    local old=w.configs.PassiveConfig.CLIMBER
    local replacement={GRAB_REACH=.7,E_REACH=1.5,GRAB_FACING=.6,MOUNT_TIME=.4,levels={{},{}}}
    w.configs.PassiveConfig.CLIMBER=replacement;w:advance(1.4)
    close(old.GRAB_REACH,.8);eq(old.levels[1].sprintGrab,nil)
    close(replacement.GRAB_REACH,.91);eq(replacement.levels[1].sprintGrab,true)
    h:close();close(replacement.GRAB_REACH,.7);eq(replacement.levels[1].sprintGrab,nil)
end)

test("overhaul aliased climb levels keep native mounting assistance operational",function()
    local w=Mock.new();local shared={}
    w.configs.PassiveConfig.CLIMBER.levels={shared,shared}
    local h=load(w,{settings={states={climb=true}}});w:advance(.2)
    eq(h.registry.byId.climb.applied,true);eq(shared.sprintGrab,true)
    h:close();eq(shared.sprintGrab,nil)
end)

test("overhaul leap body profile replacement is leased and restored exactly",function()
    local w,h=boot({leap=true});local old=w.configs.JumpLeapConfig.BODY_LENGTHS
    local replacement={Wolf=.8,Python=0};w.configs.JumpLeapConfig.BODY_LENGTHS=replacement
    w:advance(1.4);close(old.Wolf,1);close(replacement.Wolf,.92);eq(replacement.Python,0)
    h:close();close(replacement.Wolf,.8)
end)

test("overhaul replacing and removing species climb sprint profiles retires their stamina lease",function()
    local w=Mock.new();local old={DRAIN=.8,SPEED=1.2}
    local sprint={Python=old};w.configs.PassiveConfig.CLIMBER.CLIMB_SPRINT=sprint
    local h=load(w,{settings={states={stamina=true}}});w:advance(.2);eq(old.DRAIN,0)
    local nextProfile={DRAIN=1.3,SPEED=1.4};sprint.Python=nextProfile;w:advance(1.4)
    close(old.DRAIN,.8);eq(nextProfile.DRAIN,0);close(nextProfile.SPEED,1.4)
    sprint.Python=nil;w:advance(1.4);close(nextProfile.DRAIN,1.3)
    eq(h.registry.byId.stamina.applied,true);h:close()
end)

test("overhaul replacement predicted impact settings preserve real native hit feedback",function()
    local w=Mock.new();local old={PREDICT=true};w.configs.CombatConfig.HIT2=old
    local h=load(w,{settings={states={reach=true}}});w:advance(.2);eq(old.PREDICT,false)
    local replacement={PREDICT=true};w.configs.CombatConfig.HIT2=replacement;w:advance(1.4)
    eq(old.PREDICT,true);eq(replacement.PREDICT,false)
    h:close();eq(replacement.PREDICT,true)
end)

test("overhaul stock geometry retains captured species and animation cone bonuses",function()
    local w=Mock.new();local c=w.configs.CombatConfig
    c.BITE_CONE_ADD={SnappingTurtle=10,AdultTurtle=15}
    c.coneFor=function(char)
        return c.CONE+(c.BITE_CONE_ADD[char:GetAttribute("AnimProfile") or ""]
            or c.BITE_CONE_ADD[char:GetAttribute("Species") or ""] or 0)
    end
    w:spawn("SnappingTurtle");local h=load(w,{settings={states={reach=true}}});w:advance(.2)
    close(h.features.originalCombat.coneFor(w.player.Character),81)
    w.player.Character:SetAttribute("AnimProfile","AdultTurtle")
    close(h.features.originalCombat.coneFor(w.player.Character),86)
    close(c.coneFor(w.player.Character),180)
    h:close();close(c.coneFor(w.player.Character),86)
end)

test("overhaul malformed combat config during a frame cannot fault the geometry reader",function()
    local w,h=boot({biteHelper=true});w:enemy(2);w:advance(.3)
    local s=h.bridge:snapshot(w.time,false)
    local target=h.bridge:candidates(s,45,false)[1]
    local values=table.clone(h.features.originalCombat);values.REACH=nil
    eq(h.bridge:geometry(values,s,target),nil)
    values=table.clone(h.features.originalCombat);values.MAX_DY=0/0
    eq(h.bridge:geometry(values,s,target),nil)
    target.root=nil;eq(h.bridge:geometry(h.features.originalCombat,s,target),nil)
    eq(h.active,true);h:close()
end)

test("overhaul stale streamed target body cannot remain geometrically eligible",function()
    local w,h=boot({biteHelper=true});local _,char,_,root=w:enemy(2)
    local s=h.bridge:snapshot(w.time,false);local target=h.bridge:candidates(s,45,false)[1]
    local original=h.bridge:geometry(h.features.originalCombat,s,target)
    assert(original);assert(original.vertical>0);assert(original.height>=0)
    local unrelated=w:animal("Wolf");root.Parent=unrelated
    eq(h.bridge:geometry(h.features.originalCombat,s,target),nil)
    root.Parent=char
    local ownChar=s.root.Parent;s.root.Parent=unrelated
    eq(h.bridge:geometry(h.features.originalCombat,s,target),nil)
    s.root.Parent=ownChar;h:close()
end)

test("overhaul clear native eligible target outranks a closer occluded guide",function()
    local w,h=boot({biteHelper=true});local _,blocked=w:enemy(2,Mock.V3.new(0,3,-3))
    local _,clear=w:enemy(2,Mock.V3.new(0,3,-4))
    local count=0
    h.bridge.occluded=function(_,_,target)count+=1;return target.char==blocked end
    local s=h.bridge:snapshot(w.time,false);local all=h.bridge:candidates(s,45,false)
    local guide=h.bridge:select(s,h.features.originalCombat,h.features.combat,all)
    eq(guide.target.char,clear);eq(guide.blocked,false);eq(h.bridge.reachTarget.char,clear)
    eq(count,2);h:close()
end)

test("overhaul malformed spawn protection is unknown rather than a valid enemy",function()
    local w,h=boot({biteHelper=true});local _,char=w:enemy(2)
    char:SetAttribute("FeralSafeUntil","not-a-timestamp")
    eq(h.bridge:combatEligible(char),false);eq(h.bridge:targetBlocker(char),"protection timing unknown")
    char:SetAttribute("FeralSafeUntil",0);eq(h.bridge:combatEligible(char),true);h:close()
end)

test("overhaul replaced native action remote cannot receive cached bite or feed requests",function()
    local w=Mock.new();w:enableNativeActions();local h=load(w);w:advance(.3)
    local old=w:remote("WolfActions");assert(h.bridge.wolfActions.tryBite)
    old.Parent=nil;local replacement=w.new("RemoteEvent");replacement.Name="WolfActions";replacement.Parent=w.rs
    eq(h.bridge:tryNativeBite(w.time),false);eq(h.bridge:toggleNativeFeed(w.time),false)
    eq(w.nativeBiteAttempts,nil);eq(w.nativeFeedToggles,nil)
    w:advance(.3);eq(h.bridge:nativeFeedState(w.time),nil)
    eq(w.nativeBiteAttempts,nil);h:close()
end)

test("overhaul native functions rediscover the replacement remote without waiting thirty seconds",function()
    local w=Mock.new();w:enableNativeActions();local h=load(w);w:advance(.3)
    local old=w:remote("WolfActions");old.Parent=nil
    local replacement=w.new("RemoteEvent");replacement.Name="WolfActions";replacement.Parent=w.rs
    w:enableNativeActions();w:advance(.4)
    eq(h.bridge.wolfActions.remote,replacement)
    eq(h.bridge:tryNativeBite(w.time),true);eq(w.nativeBites,1)
    h:close()
end)

test("overhaul new game builds do not interpret captured private feed offsets as verified",function()
    local w=Mock.new();w:enableNativeActions();local h=load(w);w:advance(.3)
    eq(select(3,h.bridge:nativeFeedState(w.time)),true)
    w.env.game.PlaceVersion=2413
    eq(select(3,h.bridge:nativeFeedState(w.time)),false)
    local ready=h.bridge:biteReadiness(h.bridge:snapshot(w.time,false),w.time,h.policy)
    eq(ready.privateStateKnown,nil);eq(ready.known,false)
    eq(w.nativeBites,nil);h:close()
end)

test("overhaul held gamepad bite prevents automatic recovery between discrete input events",function()
    local w=Mock.new();w.nativeRestEcho=true;w.hum.Health=50
    local held=false
    w.uis.GetConnectedGamepads=function()return {E.UserInputType.Gamepad2}end
    w.uis.IsGamepadButtonDown=function(_,pad,key)return held and pad==E.UserInputType.Gamepad2 and key==E.KeyCode.ButtonR2 end
    local h=load(w,{settings={states={recovery=true}}});w:advance(.2);assert(h.recovery.owned)
    held=true;w:advance(2.2);eq(h.snapshot.attackHeld,true);eq(h.recovery.owned,nil)
    held=false;w:advance(2);eq(h.snapshot.attackHeld,false);assert(h.recovery.owned)
    h:close()
end)

test("overhaul missing optional gamepad polling degrades without losing mouse input",function()
    local w,h=boot();w.uis.GetConnectedGamepads=function()error("device changed")end
    w.uis.IsGamepadButtonDown=function()error("device changed")end
    w.held=E.UserInputType.MouseButton1;eq(h.bridge:snapshot(w.time,false).attackHeld,true)
    w.held=nil;eq(h.bridge:snapshot(w.time,false).attackHeld,false);eq(h.active,true);h:close()
end)

test("overhaul stamina flag honors later native edits and only rearms on explicit retry",function()
    local w,h=boot({stamina=true});local char=w.player.Character
    eq(char:GetAttribute("WolfDbgNoStamina"),true)
    char:SetAttribute("WolfDbgNoStamina",false);w:advance(3)
    eq(char:GetAttribute("WolfDbgNoStamina"),false);eq(h.registry.byId.stamina.state,"PARTIAL")
    h:set("stamina",false);h:set("stamina",true);eq(char:GetAttribute("WolfDbgNoStamina"),true)
    h:close();eq(char:GetAttribute("WolfDbgNoStamina"),false)
end)

test("overhaul dead animals release stamina debug ownership without waiting for replacement",function()
    local w,h=boot({stamina=true});local char=w.player.Character
    w.hum.Health=0;w:advance(1.4);eq(char:GetAttribute("WolfDbgNoStamina"),nil)
    h:close()
end)

test("overhaul native aquatic dive entry releases recovery before the next heartbeat",function()
    local w=Mock.new();w.nativeRestEcho=true;w.hum.Health=50
    local h=load(w,{settings={states={recovery=true}}});w:advance(.2);assert(h.recovery.owned)
    local char=w.player.Character;char:SetAttribute("FeralDiving",true)
    eq(h.recovery.owned,nil)
    local quick=h.bridge:snapshot(w.time,false);local detailed=h.bridge:snapshot(w.time,true)
    eq(quick.diving,true);eq(quick.underwater,true);eq(detailed.underwater,true)
    w:advance(1.4);eq(h.recovery.owned,nil)
    char:SetAttribute("FeralDiving",nil);w:advance(2);assert(h.recovery.owned)
    h:close()
end)

test("overhaul cheap snapshots recognize native swimming without an expensive depth query",function()
    local w,h=boot({recovery=true});local rays=0
    w.workspace.Raycast=function()rays+=1;return nil end
    w.hum.NativeState=E.HumanoidStateType.Swimming
    local s=h.bridge:snapshot(w.time,false)
    eq(s.swimming,true);eq(s.underwater,false);eq(s.locomotion,"SWIM");eq(rays,0)
    eq(h.policy:allowed("recovery",s,w.time,"hp"),true)
    w.hum.NativeState=E.HumanoidStateType.Running;w.hum.FloorMaterial=E.Material.Water
    eq(h.bridge:snapshot(w.time,false).swimming,true);eq(rays,0);h:close()
end)

test("overhaul native player dive eligibility has priority over buffered climb input",function()
    local w,h=boot({climb=true});local char=w.player.Character
    char:SetAttribute("PassiveClimber",1);char:SetAttribute("ClimbCan",true)
    w.player:SetAttribute("FeralDiveCan",true)
    eq(h.bridge:snapshot(w.time,false).diveCan,true)
    w:input(E.KeyCode.Q);eq(h.climbQueue,nil)
    w.player:SetAttribute("FeralDiveCan",false);w:input(E.KeyCode.Q);assert(h.climbQueue)
    h:close()
end)

test("overhaul optional native strike annotation cannot convert a dispatch to a failure",function()
    local w,h=boot()
    h.bridge.nativeGrabController=function()return {state=function()error("native session changed")end}end
    eq(h.bridge:markGrabPress("session",1,w.time),false)
    local strike={k=1};local state={id="session",strike=strike}
    h.bridge.nativeGrabController=function()return {state=function()return state end}end
    eq(h.bridge:markGrabPress("other",1,w.time),false);eq(strike.pressed,nil)
    eq(h.bridge:markGrabPress("session",1,w.time),true);eq(strike.pressed,true)
    eq(h.active,true);h:close()
end)

test("overhaul unsupported combat schema removes stale guide config ownership",function()
    local w,h=boot({biteHelper=true});w:enemy(2);w:advance(.3);assert(h.features.combat)
    w.configs.CombatConfig.REACH="changed";w:advance(1.4)
    eq(h.registry.byId.reach.applied,false);eq(h.features.combat,nil)
    eq(h.features.originalCombat,nil);eq(h.bridge.reachTarget,nil);h:close()
end)

test("overhaul recovery preserves higher native factors without reducing ordinary regen or decay",function()
    local w=Mock.new();w.configs.NeedsConfig.HEALTH_REST_MULT=3
    w.configs.StatusConfig.INJURY.REST_MULT=6;w.configs.StatusConfig.BLEED.REST_MULT=8
    local h=load(w,{settings={states={recovery=true}}});w:advance(.2)
    close(w.configs.NeedsConfig.HEALTH_REGEN,.01);eq(w.configs.NeedsConfig.HEALTH_REST_MULT,3)
    close(w.configs.StatusConfig.INJURY.HEAL,.45);eq(w.configs.StatusConfig.INJURY.REST_MULT,6)
    close(w.configs.StatusConfig.BLEED.CLOT,.2);eq(w.configs.StatusConfig.BLEED.REST_MULT,8)
    eq(w.configs.NeedsConfig.HEALTH_NO_REGEN_IN_COMBAT,true);h:close()
end)

test("overhaul dense blocked combat scenes retain a bounded visibility budget",function()
    local w,h=boot({biteHelper=true})
    for i=1,40 do w:enemy(2,Mock.V3.new(i*.02,3,-3-i*.02)) end
    local rays=0;h.bridge.occluded=function()rays+=1;return true end
    local s=h.bridge:snapshot(w.time,false)
    local guide=h.bridge:select(s,h.features.originalCombat,h.features.combat,h.bridge:candidates(s,45,false))
    eq(rays,12);eq(guide.blocked,true);eq(h.bridge.reachTarget,nil);h:close()
end)

test("overhaul transient scene query failure blocks the cue without crashing other features",function()
    local w,h=boot({biteHelper=true});w:enemy(2)
    local s=h.bridge:snapshot(w.time,false);local target=h.bridge:candidates(s,45,false)[1]
    w.workspace.Raycast=function()error("stream replaced during raycast")end
    local blocked,known=h.bridge:occluded(s,target)
    eq(blocked,true);eq(known,false);eq(h.active,true);h:close()
end)

test("overhaul legacy inherited minigame handles gain service identity guards",function()
    local w=Mock.new();w:enableNativeGrab();local old=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local source=old.bridge.grabController;assert(source)
    local binds=0;local session={id="legacy",role="prey"}
    local legacy={script=source.script,remote=source.remote,press=source.press,
        state=function()return session,true end,bind=function()binds+=1;return true end}
    old.bridge.grabController=legacy
    local h=load(w,{settings={states={minigame=true}}});local adopted=h.bridge.grabController
    assert(adopted~=legacy);eq(adopted:current(),true);eq(adopted.state(),session)
    eq(legacy.current,nil)
    local before=binds
    source.remote.Parent=nil
    local replacement=w.new("RemoteEvent");replacement.Name="FeralGrabV2";replacement.Parent=w.rs
    eq(adopted.state(),nil);eq(adopted.bind(true),false);eq(binds,before)
    h:close()
end)

test("overhaul approach protection retains native species vertical reach",function()
    local w,h=boot();w:enemy(2,Mock.V3.new(0,8,-3))
    -- The generic ground-probe mock intersects every non-horizontal ray;
    -- this case supplies a clear corridor and isolates species geometry.
    h.bridge.occluded=function()return false,true end
    local s=h.bridge:snapshot(w.time,false);local all=h.bridge:candidates(s,45,false)
    local stock=table.clone(h.features.originalCombat);stock.MAX_DY=.5;stock.dyMult=function()return 4 end
    local target=h.bridge:imminentBiteTarget(s,stock,all)
    assert(target);eq(target.char,all[1].char);h:close()
end)

test("overhaul Hippo cap respects an external native trot edit across repeated reconciliation",function()
    local w=Mock.new();local profile={SPEED_CAP="trot"}
    w:addConfig("AbilityConfig",{CrusherBite=profile});w:spawn("Hippo")
    local h=load(w);w:advance(.2);eq(profile.SPEED_CAP,"burst")
    profile.SPEED_CAP="trot";w:advance(3);eq(profile.SPEED_CAP,"trot")
    eq(h.features.hippoStatus,"CONFLICT");h:close();eq(profile.SPEED_CAP,"trot")
end)

test("overhaul unverified game builds never apply the captured Hippo cap adapter",function()
    local w=Mock.new();local profile={SPEED_CAP="trot"}
    w:addConfig("AbilityConfig",{CrusherBite=profile});w:spawn("Hippo");w.env.game.PlaceVersion=2413
    local h=load(w);w:advance(.2);eq(profile.SPEED_CAP,"trot")
    eq(h.features.hippoStatus,"UNVERIFIED_VERSION");h:close()
end)

test("overhaul replacing a grab service never reinstalls its obsolete input callback",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local old=w:remote("FeralGrabV2")
    old.OnClientEvent:Fire("begin",{f=990,role="prey"})
    old.OnClientEvent:Fire("strike",{f=990,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215})
    assert(h.grabInput.lease);eq(w.bindings.FeralGrabV2Press,nil)
    old.Parent=nil;local replacement=w.new("RemoteEvent");replacement.Name="FeralGrabV2";replacement.Parent=w.rs
    h:set("minigame",false)
    eq(w.bindings.FeralGrabV2Press,nil);eq(h.grabInput.lease,nil)
    w:input(E.KeyCode.Space);eq(w.nativeManualPresses,nil);h:close()
end)

test("overhaul replacing a grab LocalScript invalidates the old readable state",function()
    local w=Mock.new();w:enableNativeGrab();local h=load(w,{settings={states={minigame=true}}});w:advance(.2)
    local remote=w:remote("FeralGrabV2");remote.OnClientEvent:Fire("begin",{f=991,role="prey"})
    remote.OnClientEvent:Fire("strike",{f=991,k=1,t0=w.time+1000,spd=1,from=0,zc=.5,zw=.215})
    local native=h.grabInput.lease.controller
    local old=native.script;old.Parent=nil
    local replacement=w.new("LocalScript");replacement.Name="FeralGrabV2UI";replacement.Parent=w.player:FindFirstChild("PlayerScripts")
    local state,known=native.state();eq(state,nil);eq(known,true)
    h:set("minigame",false);eq(w.bindings.FeralGrabV2Press,nil);h:close()
end)
