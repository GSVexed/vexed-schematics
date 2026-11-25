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
local function world()
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
    w.owner=assert(env.loadstring(RENAISSANCE_SRC,"=RenaissanceIntegrated"))()
    assert(w.owner and w.owner.territory,"Built-in territory failed to load")
    function w:load()return assert(env.loadstring(BUNDLE_SRC,"=AmberPackage"))()end
    return w,w.owner.territory
end
test("Renaissance contains Territory by default with one window and scheduler",function()
    local w,h=world();eq(h.version,"0.5.0");eq(h.agent.enabled,false)
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
    eq(data.version,"0.5.0");assert(data.navigation);assert(data.hexSummary);eq(data.players,nil)
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
print(string.format("AMBER_LIFECYCLE_RESULT total=%d passed=%d failed=%d",total,passed,total-passed))
assert(total==passed,"Integrated lifecycle regressions failed")
