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
    w.owner={closed=false,bridge={player=w.player},policy={actionUntil=0},ui={visible=true}}
    w.localEnvironment.FERAL_RENAISSANCE_ACTIVE=w.owner
    function w:load()
        return assert(env.loadstring(BUNDLE_SRC,"=AmberPackage"))()
    end
    return w,w:load()
end
test("packaged START selects a hex and continuously reaches the native input sampler",function()
    local w,h=world();h.setEnabled(true);w:step(.25)
    eq(h.agent.phase,"TRAVEL");assert(h.nav.desiredPoint);eq(h.driver.method,"PLAYER_MODULE")
    for _=1,30 do w.controls.moveFunction(w.player,Mock.V3.new(),true);assert(w.hum.MoveDirection.X>0)end
    h.close()
end)
test("packaged STOP releases Shift and pending toggles immediately",function()
    local w,h=world();h.setEnabled(true);w:step(.25);h.setEnabled(false)
    eq(h.nav.desiredPoint,nil);eq(next(h.nav.held),nil)
    for _,down in pairs(w.keys)do eq(down,false)end
    h.close()
end)
test("unloading Renaissance removes the Amber Heartbeat, inputs and panel",function()
    local w,h=world();h.setEnabled(true);w:step(.25);w.owner.closed=true;w:step(.25)
    eq(w.localEnvironment.FERAL_AMBER_ACTIVE,nil);eq(w.run.Heartbeat:Count(),0)
    eq(h.panel.gui.Parent,nil);eq(next(h.nav.held),nil);eq(w.controls.moveFunction,w.originalMove)
end)
test("re-executing the package leaves one Heartbeat and one panel",function()
    local w,first=world();first.setEnabled(true);w:step(.25)
    local second=w:load()
    eq(first.panel.gui.Parent,nil);eq(w.run.Heartbeat:Count(),1);eq(second.agent.enabled,false)
    eq(w:count("ScreenGui"),1);second.close()
end)
test("old delayed key releases cannot mutate a re-executed package",function()
    local w,first=world();first.nav:tap("X")
    local second=w:load();second.nav:hold("X",true);w:advance(.12)
    eq(second.nav.held.X,true);eq(w.keys[w.env.Enum.KeyCode.X],true);second.close()
end)
test("hiding and minimising the panel leave farming enabled",function()
    local w,h=world();h.setEnabled(true);h.setPanelVisible(false)
    eq(h.agent.enabled,true);eq(h.panel.gui.Enabled,false)
    local min=h.panel.frame:FindFirstChild("MIN");min.Activated:Fire()
    eq(h.agent.enabled,true);assert(h.panel.collapsed);h.close()
end)
test("Right Shift follows the Renaissance visibility in both directions",function()
    local w,h=world();w.owner.ui.visible=false
    w:input(w.env.Enum.KeyCode.RightShift);eq(h.panel.gui.Enabled,false)
    w.owner.ui.visible=true;w:input(w.env.Enum.KeyCode.RightShift);eq(h.panel.gui.Enabled,true)
    h.close()
end)
test("draggable header moves the panel without touching START or STOP",function()
    local w,h=world();local header
    for _,c in ipairs(h.panel.frame:GetChildren())do if c.ClassName=="TextLabel" and c.Text=="FERAL AMBER  ·  AUTOPILOT"then header=c end end
    local input={UserInputType=w.env.Enum.UserInputType.MouseButton1,Position=Mock.V3.new(100,100,0)}
    header.InputBegan:Fire(input)
    w.uis.InputChanged:Fire({UserInputType=w.env.Enum.UserInputType.MouseMovement,Position=Mock.V3.new(150,140,0)})
    eq(h.panel.frame.Position.X,50);eq(h.panel.frame.Position.Y,40);eq(h.agent.enabled,false);h.close()
end)
test("copy status contains observed gait and physical travel without other player names",function()
    local w,h=world();local captured
    w.env.setclipboard=function(payload)captured=payload end
    h.panel.frame:FindFirstChild("COPYSTATUS").Activated:Fire();assert(captured)
    local data=w.env.game:GetService("HttpService"):JSONDecode(captured)
    eq(data.version,"0.4.0");assert(data.navigation);assert(data.hexSummary)
    eq(data.players,nil);eq(data.events[1],nil);h.close()
end)
test("late path jobs cannot resurrect a closed packaged controller",function()
    local w,h=world();local jobs={};w.env.task.spawn=function(fn)table.insert(jobs,fn)end
    h.setEnabled(true);w:step(.25);assert(#jobs>0)
    h.close();for _,fn in ipairs(jobs)do fn()end
    eq(h.nav.desiredPoint,nil);eq(h.nav.pending,nil);eq(w.run.Heartbeat:Count(),0)
end)
test("native feed approach suppresses E repeats in the real bridge",function()
    local w,h=world();local calls=0
    w.owner.bridge.toggleNativeFeed=function()calls+=1;return true end
    local s={feedCan="drink",nativeFeedKnown=true,now=w.time}
    eq(h.bridge:feed(s,"drink"),true);s.nativeFeedMode="drink"
    eq(h.bridge:feed(s,"drink"),false);eq(calls,1);h.close()
end)
test("HudBurstNo numeric pulse is recognised and expires",function()
    local w,h=world();w.player:SetAttribute("HudBurstNo",w.time)
    eq(h.bridge:snapshot(w.time).hudBurstNo,true)
    eq(h.bridge:snapshot(w.time+2).hudBurstNo,false);h.close()
end)
test("real bridge distinguishes Bear species from the Spirit Bear coat",function()
    local w,h=world();w.player.Character:SetAttribute("Coat","Spirit Bear")
    local s=h.bridge:snapshot(w.time);eq(s.species,"Bear");eq(s.coat,"Spirit Bear")
    eq(s.profile.hunts,true);eq(s.profile.diet,"omnivore");h.close()
end)
test("actual Renaissance and Amber coordinate recovery and movement ownership",function()
    local w,initial=world();initial.close();w.localEnvironment.FERAL_RENAISSANCE_ACTIVE=nil
    local hub=assert(w.env.loadstring(RENAISSANCE_SRC,"=RenaissanceIntegration"))()
    assert(hub and hub.bridge and hub.policy)
    local amber=w:load();amber.setEnabled(true);w:step(.25)
    eq(amber.agent.phase,"TRAVEL");eq(hub.closed,false);eq(hub.walk,nil)
    assert(hub.policy.actionUntil>w.time)
    w.controls.moveFunction(w.player,Mock.V3.new(),true);assert(w.hum.MoveDirection.X>0)
    amber.close();hub:close()
end)
test("actual Renaissance unload closes its companion and restores the shared input callback",function()
    local w,initial=world();initial.close();w.localEnvironment.FERAL_RENAISSANCE_ACTIVE=nil
    local hub=assert(w.env.loadstring(RENAISSANCE_SRC,"=RenaissanceIntegration"))()
    local amber=w:load();amber.setEnabled(true);w:step(.25)
    hub:close();w:step(.25)
    eq(amber.panel.gui.Parent,nil);eq(w.localEnvironment.FERAL_AMBER_ACTIVE,nil)
    eq(w.controls.moveFunction,w.originalMove);eq(w.run.Heartbeat:Count(),0)
end)
print(string.format("AMBER_LIFECYCLE_RESULT total=%d passed=%d failed=%d",total,passed,total-passed))
assert(total==passed,"Package lifecycle regressions failed")
