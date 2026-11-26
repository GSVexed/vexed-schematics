-- Full-candidate settings, ownership, observation and presentation regressions.
test("overhaul late cleanup failures remain visible after a scope has closed",function()
    local M=modules();local scope=M.core.scope();scope:close()
    scope:add(function()error("late failed detach")end)
    eq(#scope.tasks,0);eq(#scope.errors,1);scope:close();eq(#scope.errors,1)
end)
test("overhaul lease getter failure after preflight restores all earlier writes",function()
    local M=modules();local leases=M.core.leases();local first={value=1};local reads=0
    local later=setmetatable({}, {__index=function()
        reads+=1;if reads>1 then error("streamed schema disappeared") end;return 4
    end})
    local ok=leases:apply("example",{{target=first,key="value",value=2}, {target=later,key="value",value=5}})
    eq(ok,false);eq(first.value,1);eq(leases.owners.example,nil)
    eq(leases:apply("replacement",{{target=first,key="value",value=3}}),true)
    leases:close();eq(first.value,1)
end)
test("overhaul lease preserves a later field changed by an earlier setter",function()
    local M=modules();local leases=M.core.leases();local later={value=4};local backing=1
    local first=setmetatable({}, {__index=function()return backing end,
        __newindex=function(_,_,v)backing=v;if v==2 then later.value=99 end end})
    eq(leases:apply("example",{{target=first,key="value",value=2},{target=later,key="value",value=5}}),false)
    eq(backing,1);eq(later.value,99);eq(leases.owners.example,nil)
end)
test("overhaul config leases reject nonfinite patch values before any mutation",function()
    local M=modules();local leases=M.core.leases();local t={value=3}
    eq(leases:apply("bad",{{target=t,key="value",value=0/0}}),false)
    eq(t.value,3);eq(next(leases.owners),nil)
end)
test("overhaul observations keep an immutable baseline when caller reuses a snapshot",function()
    local M=modules();local l=M.core.ledger();local s={char={},now=1,hp=50,maxHP=100,combat=false,moving=false}
    l:sample(s,"NO_SIGNAL");eq(s.mode,nil)
    s.now=1.5;s.hp=52;l:sample(s,"NO_SIGNAL")
    local b=l.rates["NO_SIGNAL:false:still"]
    eq(b.hp,2);close(b.hpSeconds,.5);close(b.hpNormalized,.02)
end)
test("overhaul observations tolerate unknown health capacity and invalid clocks",function()
    local M=modules();local l=M.core.ledger();local char={}
    l:sample({char=char,now=1,hp=50},"NO_SIGNAL")
    l:sample({char=char,now=1.5,hp=52},"NO_SIGNAL")
    eq(l.rates["NO_SIGNAL:nil:still"].hp,0)
    l:sample({char=char,now=0/0},"NO_SIGNAL");eq(l.previous,nil)
end)
test("overhaul observations exclude negative conditions and incompatible recovery modes",function()
    local M=modules();local l=M.core.ledger();local char={}
    local function sample(now,mode,stamina,venom)
        l:sample({char=char,now=now,hp=50,maxHP=100,combat=false,moving=false,
            species="Wolf",stamina=stamina,maxStamina=100,locomotion="LAND",venom=venom},mode)
    end
    sample(1,"NO_SIGNAL",80,5);sample(1.5,"NO_SIGNAL",79,-1)
    eq(l.rates["NO_SIGNAL:false:still"].effects.venom,nil)
    sample(2,"REQUESTED",81,4);eq(l.staminaObservation,nil)
end)
test("overhaul settings reject unrelated primary JSON and retain backup explicit OFFs",function()
    local M=modules();local S=M.settings
    local saved,origin=S.load({read=function(path)
        if path==S.path then return {unrelated=true} end
        return {schema=15,states={recovery=false,zoom=false,esp=true},range=900,walls=false}
    end},M.core.specs)
    eq(origin,"migrated");eq(saved.states.recovery,false);eq(saved.states.zoom,false);eq(saved.states.esp,true)
end)
test("overhaul legacy walls migration honors an explicit top-level false",function()
    local M=modules();local p=M.settings.sanitize({states={walls=true,recovery=false},walls=false},M.core.specs)
    eq(p.walls,false);eq(p.states.recovery,false)
end)
test("overhaul saving does not replace a valid backup with an unrecognized primary",function()
    local M=modules();local S=M.settings
    local backup={schema=15,states={recovery=false,zoom=false}}
    local files={[S.path]={unrelated=true},[S.backup]=backup}
    local io={read=function(path)return files[path]end,write=function(path,v)files[path]=v;return true end}
    eq(S.save(io,{states={recovery=false}},M.core.specs),true)
    eq(files[S.backup],backup);eq(files[S.path].states.recovery,false)
end)
test("overhaul failed backup acknowledgement stops before replacing primary settings",function()
    local M=modules();local S=M.settings;local old={schema=15,states={recovery=false,esp=true}}
    local files={[S.path]=old};local primaryWrites=0
    local io={read=function(path)return files[path]end,write=function(path,v)
        if path==S.path then primaryWrites+=1;files[path]=v end;return true
    end}
    eq(S.save(io,{states={recovery=true}},M.core.specs),false)
    eq(primaryWrites,0);eq(files[S.path],old)
end)
test("overhaul zoom rejection unwinds a partially applied camera lease",function()
    local M,w=modules();local values={CameraMaxZoomDistance=128,CameraMinZoomDistance=2,CameraMode=E.CameraMode.LockFirstPerson}
    local player=setmetatable({}, {__index=function(_,key)
        if key=="GetPropertyChangedSignal" then return function(_,name)return w.player:GetPropertyChangedSignal(name)end end
        return values[key]
    end,__newindex=function(_,key,value)
        if key=="CameraMode" and value==E.CameraMode.Classic then error("camera controller rejected mode") end
        values[key]=value
    end})
    local z=M.zoom.new(player);eq(z:set(true),false);eq(z.active,false);eq(#z.connections,0)
    eq(values.CameraMaxZoomDistance,128);eq(values.CameraMinZoomDistance,2);eq(values.CameraMode,E.CameraMode.LockFirstPerson)
end)
test("overhaul every visible feature control responds and saved OFF survives repeated page changes",function()
    local w,h=boot()
    local controls={Survival={"stamina","recovery","escape","robloxAFK","survivalAFK","minigame"},
        Movement={"climb","flight","mobility","speed","leap","zoom"},Combat={"biteHelper"},Vision={"esp","tags"}}
    for tab,ids in pairs(controls) do
        h.ui:selectTab(tab)
        for _,id in ipairs(ids) do
            local before=h.registry.byId[id].requested
            h.ui.rows[id].toggle.Activated:Fire();eq(h.registry.byId[id].requested,not before)
            if h.registry.byId[id].requested then h.ui.rows[id].toggle.Activated:Fire() end
            eq(h.settings.states[id],false)
        end
    end
    for i=1,15 do h.ui:selectTab(i%2==0 and "Survival" or "Movement") end
    local replacement=load(w);eq(h.closed,true)
    for _,ids in pairs(controls) do for _,id in ipairs(ids) do eq(replacement.registry.byId[id].requested,false) end end
    replacement:close();eq(w:connections(),0)
end)
test("overhaul window fits small viewports and clamps drag to the visible screen",function()
    local M=modules();local amount,centre=M.ui.fit(Mock.V2.new(320,240),Mock.V2.new(-999,999))
    assert(704*amount<=296 and 505*amount<=216)
    assert(centre.X-352*amount>=11.999 and centre.Y+252.5*amount<=228.001)
    eq(M.ui.fit(Mock.V2.new(0,0)),nil)
    local w,h=boot();assert(h.ui:beginDrag(Mock.V2.new(10,10),{}))
    h.ui:moveDrag(Mock.V2.new(-10000,-10000));assert(h.ui.windowCentre.X>=364)
    h.ui:toggle();eq(h.ui.drag,nil);h:close();eq(w:connections(),0)
end)
test("overhaul marker range colours are exclusive to King Cobra",function()
    local M=modules()
    eq(M.ui.markerTone("KingCobra",true,true),"same")
    eq(M.ui.markerTone("KingCobra",true,false),"unknown")
    for _,species in ipairs({"Wolf","Vulture","Eagle","Python","Hippo"}) do
        eq(M.ui.markerTone(species,true,true),"text");eq(M.ui.markerTone(species,true,false),"text")
        eq(M.ui.markerTone(species,false,true),"sub")
    end
end)
test("overhaul missing camera hides overlays instead of leaving stale screen markers",function()
    local w,h=boot({esp=true,tags=true,biteHelper=true});local _,char=w:enemy(2);w:advance(.2)
    local record=h.ui.records[char];assert(record.highlight.Enabled)
    local camera=w.workspace.CurrentCamera;w.workspace.CurrentCamera=nil;h.ui:render(.016,w.time)
    eq(record.highlight.Enabled,false);eq(record.label.Visible,false);eq(h.ui.dot.Visible,false)
    eq(h.ui.lastPoint,nil);w.workspace.CurrentCamera=camera;h:close()
end)
test("overhaul names retain independent through-wall visibility and fit screen edges",function()
    local w,h=boot({tags=true});local _,char=w:enemy(2);w:advance(.2)
    local record=h.ui.records[char];eq(record.label.Visible,true)
    w.blocked=true;w:advance(.3);eq(record.label.Visible,true)
    local camera=w.workspace.CurrentCamera;local project=camera.WorldToViewportPoint
    camera.WorldToViewportPoint=function()return Mock.V3.new(4,4,10),true end
    h.ui:render(.016,w.time);eq(record.x,90);eq(record.y,20)
    camera.WorldToViewportPoint=project;h:close()
end)
test("overhaul rendering never performs target raycasts in a crowded scene",function()
    local w,h=boot({tags=true});for i=1,24 do w:enemy(2,Mock.V3.new(i,3,-60)) end
    w:advance(.2);local count=0;local original=h.bridge.occluded
    h.bridge.occluded=function(...)count+=1;return original(...)end
    for _=1,30 do h.ui:render(1/144,w.time)end;eq(count,0)
    h:close()
end)
test("overhaul hidden menu can reopen without a keyboard and its button excludes combat clicks",function()
    local w,h=boot();h.ui:toggle();eq(h.ui.visible,false);eq(h.ui.launcher.Visible,true)
    h.ui.launcher.AbsolutePosition=Mock.V2.new(16,816);h.ui.launcher.AbsoluteSize=Mock.V2.new(82,34)
    eq(h.ui:contains(Mock.V2.new(32,830)),true);eq(h.ui:contains(Mock.V2.new(200,830)),false)
    eq(h.ui:beginDrag(Mock.V2.new(32,830),{}),false)
    h.ui.launcher.Activated:Fire();eq(h.ui.visible,true);eq(h.ui.launcher.Visible,false)
    eq(h.policy.menuOpen,true);h:close()
end)
test("overhaul activation failure unwinds camera GUI and input after successful staging",function()
    local w=Mock.new();local original=w.env.game.GetService
    rawset(w.env.game,"GetService",function(self,name)
        if name=="PathfindingService" then error("injected native service failure during activation") end
        return original(self,name)
    end)
    local ok,why=pcall(load,w)
    eq(ok,false);assert(tostring(why):find("activation failed",1,true))
    eq(w.player.CameraMaxZoomDistance,128);eq(w.player.CameraMinZoomDistance,.5)
    eq(w:connections(),0);eq(next(w.bindings),nil);eq(next(w.renders),nil)
    eq(w.localEnvironment.FERAL_RENAISSANCE_ACTIVE,nil)
    for _,object in ipairs(w.objects) do
        if object.ClassName=="ScreenGui" and object.Name:find("FeralRenaissance",1,true) then eq(object.Parent,nil) end
    end
end)

-- Compare operation counts against the actual integrated predecessor, not only
-- the much older reference release. These are deterministic counts, not FPS.
test("overhaul preserves the integrated predecessor render budget and minigame scan isolation",function()
    local P=assert(loadstring(PERF_SOURCE))()
    local a=P.run(INTEGRATED_BASELINE,Mock,false);local b=P.run(BUNDLE,Mock,false)
    assert(b.highlightWrites<=a.highlightWrites+24,"additional per-frame outline writes")
    assert(b.labelPositions<=a.labelPositions+24,"additional per-frame label writes")
    eq(b.heap,0)
    local ac=P.run(INTEGRATED_BASELINE,Mock,true);local bc=P.run(BUNDLE,Mock,true)
    eq(bc.candidateScans,0);eq(bc.heap,0)
    print(string.format("INTEGRATED_WORK_BENCH baseline_highlight=%d candidate_highlight=%d baseline_label=%d candidate_label=%d baseline_projections=%d candidate_projections=%d baseline_strike_scans=%d candidate_strike_scans=%d",a.highlightWrites,b.highlightWrites,a.labelPositions,b.labelPositions,a.projections,b.projections,ac.candidateScans,bc.candidateScans))
end)
