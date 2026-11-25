-- Execute the complete distributable with deterministic Roblox services.
local Mock=assert(loadstring(MOCK_SRC))()
local total,passed=0,0
local function eq(a,b)assert(a==b,tostring(a).." != "..tostring(b))end
local function test(name,fn)
    total+=1;local ok,why=pcall(fn)
    if ok then passed+=1;print("PASS "..name)else print("FAIL "..name.." "..tostring(why))end
end
local function signal()
    local s={listeners={}}
    function s:Connect(fn)
        local c={Connected=true,fn=fn}
        function c:Disconnect()self.Connected=false end
        table.insert(self.listeners,c);return c
    end
    function s:Fire(...)
        for _,c in ipairs(table.clone(self.listeners))do if c.Connected then c.fn(...)end end
    end
    return s
end
local function world(native)
    local w=Mock.new();local env=w.env;local V=Mock.V3
    env.Vector3.zero=V.new();env.UDim2.new=function(a,b,c,d)return {X={Scale=a,Offset=b},Y={Scale=c,Offset=d}}end
    local create=env.Instance.new
    env.Instance.new=function(class,parent)
        local obj=create(class)
        if class=="TextLabel" or class=="Frame" then obj.InputBegan=signal() end
        if parent then obj.Parent=parent end
        return obj
    end
    w.uis.InputEnded=signal();w.keys={};w.keyEvents={}
    function w.uis:IsKeyDown(key)return w.keys[key]==true end
    w.workspace.CurrentCamera.CFrame={LookVector=V.new(0,0,-1),RightVector=V.new(1,0,0)}
    local groundRay=w.workspace.Raycast
    function w.workspace:Raycast(origin,direction,params)
        -- A shallow lateral ray above flat ground does not hit that ground.
        if direction.X~=0 or direction.Z~=0 then return nil end
        return groundRay(self,origin,direction,params)
    end
    function w.hum:Move(dir)self.MoveDirection=dir end
    w.controls={calls=0,moveFunction=function(_,dir,relative)
        w.controls.calls+=1;w.hum:Move(dir);return relative
    end}
    w.originalMove=w.controls.moveFunction
    local scripts=w.new("PlayerScripts");scripts.Name="PlayerScripts";scripts.Parent=w.player
    local mod=w.new("ModuleScript");mod.Name="PlayerModule";mod.ModuleValue={GetControls=function()return w.controls end};mod.Parent=scripts
    local paths={}
    function paths:CreatePath()
        local p={Status=env.Enum.PathStatus.Success}
        function p:ComputeAsync(_,target)self.target=target end
        function p:GetWaypoints()return {{Position=self.target}}end
        return p
    end
    local virtual={}
    function virtual:SendKeyEvent(on,key)w.keys[key]=on;table.insert(w.keyEvents,{key=key,on=on})end
    function virtual:SendMouseButtonEvent(_,_,_,on)w.mouseDown=on end
    local get=env.game.GetService
    function env.game:GetService(name)
        if name=="PathfindingService"then return paths end
        if name=="VirtualInputManager"then return virtual end
        return get(self,name)
    end
    env.task.spawn=function(fn)fn()end;env.task.defer=function(fn)fn()end
    w:addConfig("Species",{List={Bear={diet="omnivore",swimSprint=22},Wolf={diet="carnivore",swimSprint=15}}})
    w:addConfig("TerritoryConfig",{CLAIM_RADIUS=120,
        parseHexes=function()return {{key="H0_0",i=0,j=0},{key="H1_0",i=1,j=0}}end,
        hexCenter=function(i)return env.Vector2.new(200+i*300,0)end,
        hexAt=function(x)return x<350 and 0 or 1,0 end,
        hexKey=function(i,j)return "H"..i.."_"..j end})
    local t=w.new("Folder");t.Name="FeralTerritory";t.Parent=w.rs
    t:SetAttribute("Hexes","0,0;1,0");t:SetAttribute("H0_0_owner",2);t:SetAttribute("H0_0_hold",.7)
    w:spawn("Bear");function w.hum:Move(dir)self.MoveDirection=dir end
    if native then w:enableNativeActions();w:enableNativeConnections() end
    w.owner=assert(env.loadstring(RENAISSANCE_SRC,"=RenaissanceIntegrated"))()
    assert(w.owner and w.owner.territory,"Built-in territory failed to load")
    function w:load()return assert(env.loadstring(BUNDLE_SRC,"=AmberPackage"))()end
    return w,w.owner.territory
end
test("Renaissance contains Territory by default with one window and scheduler",function()
    local w,h=world();eq(h.version,"0.6.1");eq(h.agent.enabled,false)
    eq(w:count("ScreenGui"),1);eq(w.run.Heartbeat:Count(),1)
    assert(w.owner.ui:selectTab("Territory"));assert(w.owner.ui.frame:FindFirstChild("TerritoryStart",true))
    w.owner:close()
end)
test("native Territory START reaches the real shared movement callback",function()
    local w,h=world();w.owner.ui:selectTab("Territory")
    w.owner.ui.frame:FindFirstChild("TerritoryStart",true).Activated:Fire();w:step(.25)
    eq(h.agent.phase,"TRAVEL");assert(h.nav.desiredPoint);eq(h.driver.method,"PLAYER_MODULE")
    for _=1,30 do w.controls.moveFunction(w.player,Mock.V3.new(),true);assert(w.hum.MoveDirection.X>0)end
    w.owner:close()
end)
test("STOP releases all owned input immediately inside the shared hub",function()
    local w,h=world();h.setEnabled(true);w:step(.25);h.setEnabled(false)
    eq(h.nav.desiredPoint,nil);eq(next(h.nav.held),nil)
    for _,down in pairs(w.keys)do eq(down,false)end
    w.owner:close()
end)
test("unloading the real hub closes Territory immediately without a later heartbeat",function()
    local w,h=world();h.setEnabled(true);w:step(.25);w.owner:close()
    eq(h.closed,true);eq(w.localEnvironment.FERAL_AMBER_ACTIVE,nil)
    eq(w.run.Heartbeat:Count(),0);eq(w:count("ScreenGui"),0);eq(next(h.nav.held),nil)
    eq(w.controls.moveFunction,w.originalMove)
end)
test("re-executing the Amber entry reuses its built-in controller",function()
    local w,first=world();first.setEnabled(true);w:step(.25)
    local second=w:load();eq(first,second);eq(w.run.Heartbeat:Count(),1)
    eq(w:count("ScreenGui"),1);eq(second.agent.enabled,true);w.owner:close()
end)
test("reloading Renaissance retires its old Territory and leaves one owner",function()
    local w,first=world();first.setEnabled(true);w:step(.25)
    local replacement=assert(w.env.loadstring(RENAISSANCE_SRC,"=ReplacementHub"))()
    eq(first.closed,true);assert(replacement.territory~=first)
    eq(w.run.Heartbeat:Count(),1);eq(w:count("ScreenGui"),1);eq(replacement.territory.agent.enabled,false)
    replacement:close()
end)
test("changing tabs and hiding the hub never turn farming off",function()
    local w,h=world();h.setEnabled(true)
    w.owner.ui:selectTab("Territory");w.owner.ui:selectTab("Vision");w.owner.ui:toggle()
    eq(h.agent.enabled,true);eq(w.owner.ui.frame.Visible,false)
    w.owner.ui:selectTab("Territory");eq(h.agent.enabled,true);w.owner:close()
end)
test("Right Shift controls the single main hub including Territory",function()
    local w,h=world();w.owner.ui:selectTab("Territory")
    local before=w.owner.ui.visible;w:input(w.env.Enum.KeyCode.RightShift)
    eq(w.owner.ui.visible,not before);eq(h.agent.enabled,false)
    w:input(w.env.Enum.KeyCode.RightShift);eq(w.owner.ui.visible,before);w.owner:close()
end)
test("Territory tab persists through the existing settings sanitizer",function()
    local w,h=world();w.owner.ui:selectTab("Territory")
    eq(w.owner.settings.tab,"Territory");assert(w.owner:save());w.owner:close()
end)
test("COPY STATUS is available on the native page without other player names",function()
    local w,h=world();local copied;w.env.setclipboard=function(value)copied=value end
    w.owner.ui:selectTab("Territory");w.owner.ui.frame:FindFirstChild("TerritoryCopy",true).Activated:Fire()
    assert(copied);local data=w.env.game:GetService("HttpService"):JSONDecode(copied)
    eq(data.version,"0.6.1");assert(data.navigation);assert(data.hexSummary);eq(data.players,nil)
    w.owner:close()
end)
test("closing the hub invalidates deferred path computations",function()
    local w,h=world();local jobs={};w.env.task.spawn=function(fn)table.insert(jobs,fn)end
    h.setEnabled(true);w:step(.25);assert(#jobs>0)
    w.owner:close();for _,fn in ipairs(jobs)do fn()end
    eq(h.nav.desiredPoint,nil);eq(h.nav.pending,nil);eq(w.run.Heartbeat:Count(),0)
end)
test("numeric native Burst denial pulse expires",function()
    local w,h=world();w.player:SetAttribute("HudBurstNo",w.time)
    eq(h.bridge:snapshot(w.time).hudBurstNo,true);eq(h.bridge:snapshot(w.time+2).hudBurstNo,false);w.owner:close()
end)
test("Bear remains Bear while Spirit Bear is coat metadata",function()
    local w,h=world();w.player.Character:SetAttribute("Coat","Spirit Bear")
    local s=h.bridge:snapshot(w.time);eq(s.species,"Bear");eq(s.coat,"Spirit Bear")
    eq(s.profile.hunts,true);eq(s.profile.diet,"omnivore");eq(s.drinkTarget,100);w.owner:close()
end)
test("packmates are absent from avoidance and territory contest maps",function()
    local w,h=world();local friend=w:enemy(1,Mock.V3.new(10,3,0))
    local s=h.bridge:snapshot(w.time);eq(#s.players,0);eq(next(s.contested),nil)
    h.setEnabled(true);w:step(.25);eq(h.agent.phase,"TRAVEL");w.owner:close()
end)
test("a non-pack occupant marks its whole native hex as contested",function()
    local w,h=world();w:enemy(2,Mock.V3.new(10,3,0))
    local s=h.bridge:snapshot(w.time);eq(s.contested.H0_0,1)
    h.setEnabled(true);w:step(.25);eq(h.agent.goal.key,"H1_0");eq(h.agent.phase,"TRAVEL")
    w.owner:close()
end)
test("native private approach prevents repeated E",function()
    local w,h=world();local calls=0
    w.owner.bridge.toggleNativeFeed=function()calls+=1;return true end
    local s={feedCan="drink",nativeFeedKnown=true,now=w.time}
    eq(h.bridge:feed(s,"drink"),true);s.nativeFeedMode="drink";eq(h.bridge:feed(s,"drink"),false)
    eq(calls,1);w.owner:close()
end)
test("one hub fault boundary keeps other Renaissance features alive",function()
    local w,h=world();h.agent.setEnabled(h.agent,true)
    h.bridge.snapshot=function()error("simulated territory data failure")end
    w:step(.25);eq(h.agent.phase,"ERROR");eq(h.agent.enabled,false);eq(w.owner.closed,false)
    eq(w:count("ScreenGui"),1);w.owner:close()
end)
test("empty water searches scan bounded chunks and retain negative results briefly",function()
    local w,h=world();h.bridge.spots=nil;h.bridge.configs.FeedFinder={}
    local calls=0;w.workspace.Raycast=function()calls+=1;return nil end
    local s=h.bridge:snapshot(w.time)
    eq(h.bridge:water(s),nil);eq(calls,24)
    s.now+=.2;eq(h.bridge:water(s),nil);eq(calls,40)
    s.now+=.2;eq(h.bridge:water(s),nil);eq(calls,40)
    s.feedCan="drink";s.feedPosition={x=8,z=0};local offered=h.bridge:water(s)
    eq(offered.x,8);eq(calls,40);w.owner:close()
end)
test("incremental water search continues to farther rings instead of restarting",function()
    local w,h=world();h.bridge.spots=nil;h.bridge.configs.FeedFinder={}
    local calls=0
    w.workspace.Raycast=function(_,origin)
        calls+=1
        if origin.X>85 and math.abs(origin.Z)<1 then
            return {Position=Mock.V3.new(origin.X,0,origin.Z),Normal={Y=1},Material=w.env.Enum.Material.Water}
        end
    end
    local s=h.bridge:snapshot(w.time)
    eq(h.bridge:water(s),nil);eq(calls,24);s.now+=.2
    local p=h.bridge:water(s);assert(p and p.x>=90);assert(calls<=72);w.owner:close()
end)
test("new native water offers take precedence over a cached distant landmark",function()
    local w,h=world();local s=h.bridge:snapshot(w.time)
    h.bridge.waterCache={x=500,z=0};h.bridge.waterAt=s.now
    s.feedCan="drink";s.feedPosition={x=4,z=0}
    eq(h.bridge:water(s).x,4);w.owner:close()
end)
test("automatic recovery releases at its farming handoff threshold",function()
    local w,h=world();local c=w.player.Character
    w.hum.Health=w.hum.MaxHealth*.8;h.ownerHub.recovery.owned=c;c:SetAttribute("WolfRest",true)
    h.bridge:prepare(w.time,true,{kind="RECOVER"})
    eq(w.owner.recovery.owned,nil);assert(w.owner.policy.actionUntil>w.time)
    eq(h.bridge:snapshot(w.time).resting,false);w.owner:close()
end)
test("manual Rest is preserved at the automatic recovery handoff threshold",function()
    local w,h=world();local c=w.player.Character
    w.hum.Health=w.hum.MaxHealth*.8;w.owner.recovery.owned=c;w.owner.policy.manualRest=true;c:SetAttribute("WolfRest",true)
    h.bridge:prepare(w.time,true,{kind="RECOVER"})
    eq(w.owner.recovery.owned,c);eq(c:GetAttribute("WolfRest"),true)
    eq(h.bridge:snapshot(w.time).automaticRest,false);w.owner:close()
end)
test("a failing Territory stop cannot escape into the shared hub tick",function()
    local w,h=world();h.setEnabled(true);w:step(.25)
    h.bridge.snapshot=function()error("data failure")end
    h.bridge.stop=function()error("stop failure")end
    w.time+=.25;local ok=pcall(w.owner.tick,w.owner,.25);eq(ok,true)
    eq(h.agent.phase,"ERROR");eq(h.agent.enabled,false);eq(h.nav.desiredPoint,nil);eq(next(h.nav.held),nil)
    eq(w.owner.closed,false);assert(w.owner.snapshot);w.owner:close()
end)
test("advisory cooldown cannot suppress a valid original native bite and simulated damage",function()
    local w,h=world(true);local target=w.new("Model");target.Parent=w.workspace
    local hp=w.new("Humanoid");hp.Health=80;hp.MaxHealth=80;hp.Parent=target
    local prey={model=target,hum=hp,health=80,position={x=4,z=0}}
    h.bridge.checkPrey=function()return prey end;h.bridge.attackGeometry=function()return {valid=true}end
    w.owner.bridge.biteReadiness=function()return {known=true,ready=false,reason="native cooldown"}end
    w.owner.snapshot=w.owner.bridge:snapshot(w.time)
    w.nativeBiteTarget=target;w.nativeDamage=10
    local s=h.bridge:snapshot(w.time);eq(h.bridge:bite(s,prey),true)
    eq(w.nativeBites,1);w:advance(.4);eq(hp.Health,70);eq(w.nativeHitResponses,1)
    w.owner:close()
end)
test("original native cooldown still guards repeated dispatched attempts",function()
    local w,h=world(true);local prey={model={},position={x=4,z=0}}
    h.bridge.checkPrey=function()return prey end;h.bridge.attackGeometry=function()return {valid=true}end
    local s=h.bridge:snapshot(w.time);h.bridge:bite(s,prey);h.bridge:bite(s,prey)
    eq(w.nativeBites,1);eq(w.nativeBiteAttempts,2);w.owner:close()
end)
test("resource scouting keeps a reachable distant target while making progress",function()
    local w,h=world();local s=h.bridge:snapshot(w.time)
    h.bridge.hexes={{key="A",center={x=300,z=0}},{key="B",center={x=0,z=320}}}
    local first=h.bridge:resourceSearch(s,"FOOD");eq(first.key,"A")
    s.now+=9;s.position={x=50,z=0};eq(h.bridge:resourceSearch(s,"FOOD"),first)
    s.now+=9;s.position={x=100,z=0};eq(h.bridge:resourceSearch(s,"FOOD"),first)
    w.owner:close()
end)
test("resource scouting leaves a genuinely stalled target within its budget",function()
    local w,h=world();local s=h.bridge:snapshot(w.time)
    h.bridge.hexes={{key="A",center={x=300,z=0}},{key="B",center={x=0,z=320}}}
    eq(h.bridge:resourceSearch(s,"FOOD").key,"A");s.now+=16
    eq(h.bridge:resourceSearch(s,"FOOD").key,"B");w.owner:close()
end)
test("core feeding cannot race Territory's owned stalled-session repair",function()
    local w,h=world();local c=w.player.Character;c:SetAttribute("WolfFeed","drink")
    c:SetAttribute("FeedCan","drink");c:SetAttribute("Thirst",50)
    w.owner.bridge.nativeFeedState=function()return "drink",true,true end
    local calls=0;w.owner.bridge.toggleNativeFeed=function()calls+=1;return true end
    local s=w.owner.bridge:snapshot(w.time);w.owner.feeding:tick(s,w.time,true)
    w.owner.feeding:tick(s,w.time+5.1,true);eq(calls,0)
    w.owner.feeding:tick(s,w.time+5.2,false);eq(calls,1)
    w.owner:close()
end)
test("real bridge preserves false native gait attributes before requesting Burst",function()
    local w,h=world();w.player:SetAttribute("HudBurst",false);w.player:SetAttribute("HudTrot",false)
    w.player:SetAttribute("HudSprint",false);w.player.Character:SetAttribute("WolfBurst",false)
    w.root.CFrame={LookVector=Mock.V3.new(1,0,0)}
    local s=h.bridge:snapshot(w.time);eq(s.hudBurst,false);eq(s.hudTrot,false);eq(s.hudSprint,false)
    h.bridge:move({x=350,z=0},s,{navKey="BURST_CHECK"})
    w.root.Position=Mock.V3.new(4,3,0);w.root.CFrame={LookVector=Mock.V3.new(1,0,0)}
    w.player:SetAttribute("HudSprint",true);w.time+=.3;s=h.bridge:snapshot(w.time)
    h.bridge:move({x=350,z=0},s,{navKey="BURST_CHECK"})
    eq(h.nav.gait,"BURST");assert(w.keys[w.env.Enum.KeyCode.X]);w.owner:close()
end)
test("real hunting geometry turns toward close stationary prey before a native attack",function()
    local w,h=world(true);local V=Mock.V3
    local prey,hp,root=w:npc(nil,V.new(6,3,0),false)
    root.Size=V.new(2,2,4);hp.HipHeight=1
    w.root.Position=V.new(8,3,2.6);w.root.CFrame={LookVector=V.new(1,0,0)}
    w.nativeBiteTarget=prey;w.nativeDamage=10
    w.player.Character:SetAttribute("Hunger",25);w.player.Character:SetAttribute("Thirst",100)
    h.setEnabled(true)
    for _=1,160 do
        w.controls.moveFunction(w.player,V.new(),true)
        local direction=w.hum.MoveDirection
        if direction.Magnitude>.01 then
            w.root.Position+=direction*8*.1;w.root.CFrame={LookVector=direction.Unit}
        end
        w:step(.1)
        if hp.Health<100 then break end
    end
    assert(hp.Health<100,"No hit: "..tostring(h.agent.phase).." / "..tostring(h.agent.lastHunt and h.agent.lastHunt.result))
    assert((w.nativeBites or 0)>0);w.owner:close()
end)
test("a rejected virtual mouse API falls back to one executor click",function()
    local w,h=world();local prey={model={},position={x=4,z=0}}
    h.bridge.checkPrey=function()return prey end;h.bridge.attackGeometry=function()return {valid=true}end
    w.owner.bridge.tryNativeBite=function()return false end
    local input=w.env.game:GetService("VirtualInputManager")
    input.SendMouseButtonEvent=function()error("Virtual mouse unavailable")end
    local clicks=0;w.env.mouse1click=function()clicks+=1 end
    local s=h.bridge:snapshot(w.time)
    eq(h.bridge:bite(s,prey),true);eq(clicks,1)
    eq(h.bridge:bite(s,prey),false);eq(clicks,1);w.owner:close()
end)
test("accepted virtual mouse input does not also emit an executor click",function()
    local w,h=world();local prey={model={},position={x=4,z=0}}
    h.bridge.checkPrey=function()return prey end;h.bridge.attackGeometry=function()return {valid=true}end
    w.owner.bridge.tryNativeBite=function()return false end
    local clicks=0;w.env.mouse1click=function()clicks+=1 end
    local s=h.bridge:snapshot(w.time);eq(h.bridge:bite(s,prey),true);eq(clicks,0)
    eq(h.bridge:attackEvidence(s).backend,"VIRTUAL_MOUSE");eq(w.mouseDown,true)
    w.owner:close();eq(w.mouseDown,false)
end)
test("executor paired mouse fallback releases and restores its cursor on unload",function()
    local w,h=world();local prey={model={},position={x=4,z=0}}
    h.bridge.checkPrey=function()return prey end;h.bridge.attackGeometry=function()return {valid=true}end
    w.owner.bridge.tryNativeBite=function()return false end
    w.env.game:GetService("VirtualInputManager").SendMouseButtonEvent=function()error("Unavailable")end
    local gui=w.player:FindFirstChildOfClass("PlayerGui");local blocker=w.new("TextButton");blocker.Active=true
    rawset(gui,"GetGuiObjectsAtPosition",function(_,x)return x>1000 and {blocker} or {}end)
    local moves={};local pressed,released=0,0
    w.env.mousemoveabs=function(x,y)table.insert(moves,{x=x,y=y})end
    w.env.mouse1press=function()pressed+=1 end;w.env.mouse1release=function()released+=1 end
    local original=w.uis:GetMouseLocation();local s=h.bridge:snapshot(w.time)
    eq(h.bridge:bite(s,prey),true);eq(pressed,1);eq(released,0)
    eq(h.bridge:attackEvidence(s).backend,"EXECUTOR_MOUSE");w.owner:close()
    eq(released,1);eq(#moves,2);eq(moves[2].x,original.X);eq(moves[2].y,original.Y)
end)
test("real attack geometry ignores noncolliding triggers while retaining solid obstruction checks",function()
    local w,h=world();local V=Mock.V3;local prey,hp,root=w:npc(nil,V.new(0,3,-3),false)
    local trigger=w.new("Part");trigger.CanCollide=false;trigger.Parent=w.workspace
    w.workspace.Raycast=function(_,_,_,params)
        if not params.RespectCanCollide or trigger.CanCollide then return {Instance=trigger}end
    end
    local s=h.bridge:snapshot(w.time);local p=h.bridge:checkPrey({model=prey},s)
    assert(p);eq(h.bridge:attackGeometry(s,p).clear,true)
    trigger.CanCollide=true;eq(h.bridge:attackGeometry(s,p).clear,false);w.owner:close()
end)
test("hunt selection excludes NPCs rejected by the native combat protection policy",function()
    local w,h=world();local prey=w:npc(nil,Mock.V3.new(0,3,-4),false)
    prey:SetAttribute("FeralSafeUntil",w.time+1100)
    local s=h.bridge:snapshot(w.time);eq(h.bridge:prey(s),nil)
    prey:SetAttribute("FeralSafeUntil",nil);eq(h.bridge:prey(s).model,prey);w.owner:close()
end)
print(string.format("AMBER_LIFECYCLE_RESULT total=%d passed=%d failed=%d",total,passed,total-passed))
assert(total==passed,"Integrated lifecycle regressions failed")
