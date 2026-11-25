-- Native FERAL data boundary; all species supported by shared territory/need logic.
-- No PivotTo, CFrame teleport, direct resource writes, or fabricated rewards.
local Bridge={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e10 end
local function point(p) return {x=p.X,z=p.Z} end
local function dist(a,b)
    local dx,dz=a.x-b.x,a.z-b.z
    return math.sqrt(dx*dx+dz*dz)
end
function Bridge.new(nav)
    local Players=game:GetService("Players")
    local Rep=game:GetService("ReplicatedStorage")
    local Workspace=game:GetService("Workspace")
    local UserInput=game:GetService("UserInputService")
    local player=assert(Players.LocalPlayer,"No local player")
    local b={player=player,Players=Players,Rep=Rep,Workspace=Workspace,
        UserInput=UserInput,nav=nav,hexes={},hexByKey={},
        cfg=nil,spots=nil,territory=nil,refreshAt=0,lastString=nil,
        lastBiome=nil,motionReason="Idle",manualUncertain=false}
    local world=Rep:FindFirstChild("FeralWorld")
    local function config(name)
        local module=world and world:FindFirstChild(name)
        if not module or not module:IsA("ModuleScript") then return nil end
        local ok,value=pcall(require,module)
        return ok and type(value)=="table" and value or nil
    end
    b.cfg=config("TerritoryConfig")
    b.spots=config("MapSpots")
    b.territory=Rep:FindFirstChild("FeralTerritory")
    local function attr(object,key)
        if not object then return nil end
        local ok,value=pcall(function() return object:GetAttribute(key) end)
        return ok and value or nil
    end
    local function validAnimal()
        local c=player.Character
        local h=c and c:FindFirstChildOfClass("Humanoid")
        local r=c and c:FindFirstChild("HumanoidRootPart")
        return c,h,r
    end
    local function fullStats(c)
        local sp=attr(c,"Species")
        local coat=attr(c,"Coat") or attr(c,"CoatId") or attr(c,"Skin")
            or attr(player,"Coat")
        return sp,coat
    end
    function b:otherPlayerPositions()
        local all={}
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player then
                local c=p.Character
                local root=c and c:FindFirstChild("HumanoidRootPart")
                if root then table.insert(all,point(root.Position)) end
            end
        end
        return all
    end
    function b:refresh(now)
        if not self.cfg or not self.territory then
            world=Rep:FindFirstChild("FeralWorld")
            self.cfg=config("TerritoryConfig")
            self.spots=config("MapSpots")
            self.territory=Rep:FindFirstChild("FeralTerritory")
            if not self.cfg or not self.territory then return end
        end
        local text=attr(self.territory,"Hexes")
        local biome=attr(Workspace,"FeralBiome") or "WolfValley"
        if type(text)~="string" or #text==0 or type(self.cfg.parseHexes)~="function"
            or type(self.cfg.hexCenter)~="function" then return end
        if text==self.lastString and biome==self.lastBiome then return end
        self.lastString,self.lastBiome=text,biome
        local ok,parsed=pcall(self.cfg.parseHexes,text)
        if not ok or type(parsed)~="table" then return end
        local hexes,byKey={},{}
        for _,t in ipairs(parsed) do
            if type(t.key)=="string" and type(t.i)=="number" and type(t.j)=="number" then
                local good,p=pcall(self.cfg.hexCenter,t.i,t.j)
                if good and typeof(p)=="Vector2" then
                    local h={key=t.key,center={x=p.X,z=p.Y}}
                    table.insert(hexes,h);byKey[t.key]=h
                end
            end
        end
        local landmarks=self.spots and (self.spots[biome] or self.spots.WolfValley)
        if type(landmarks)=="table" and type(self.cfg.hexAt)=="function" then
            for _,spot in ipairs(landmarks) do
                if typeof(spot.pos)=="Vector2" then
                    local good,i,j=pcall(self.cfg.hexAt,spot.pos.X,spot.pos.Y)
                    if good then
                        local key=type(self.cfg.hexKey)=="function"
                            and self.cfg.hexKey(i,j) or ("H"..tostring(i).."_"..tostring(j))
                        local h=byKey[key]
                        if h and not h.spot then h.spot={x=spot.pos.X,z=spot.pos.Y} end
                    end
                end
            end
        end
        self.hexes,self.hexByKey=hexes,byKey
    end
    local function terrAttr(key,suffix)
        local t=b.territory
        return attr(t,key.."_"..suffix)
    end
    function b:territory(key)
        if not self.territory then return nil end
        local h=self.hexByKey[key]
        if not h then return nil end
        return {key=key,neutral=terrAttr(key,"neutral")==true,
            owner=terrAttr(key,"owner"),by=terrAttr(key,"by"),
            prog=terrAttr(key,"prog"),hold=terrAttr(key,"hold"),
            pay=terrAttr(key,"pay") or terrAttr(key,"income") or terrAttr(key,"amber"),
            fade=terrAttr(key,"fade"),center=h.center,spot=h.spot}
    end
    function b:territories(state)
        self:refresh(state.now)
        local list={}
        for _,h in ipairs(self.hexes) do
            local t=self:territory(h.key)
            if t then table.insert(list,t) end
        end
        return list
    end
    local function groundAt(x,z,c)
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={c}
        params.IgnoreWater=false
        local hit=Workspace:Raycast(Vector3.new(x,2200,z),Vector3.new(0,-4400,0),params)
        if hit and hit.Material~=Enum.Material.Water and hit.Normal.Y>.5 then
            return hit.Position+Vector3.new(0,2.5,0)
        end
        return nil
    end
    function b:territorySpot(key)
        local h=self.hexByKey[key]
        if not h then return nil end
        local c=player.Character
        local p=h.spot or h.center
        local ground=groundAt(p.x,p.z,c)
        if ground then return point(ground) end
        local center=h.center
        if p~=center then
            ground=groundAt(center.x,center.z,c)
            if ground then return point(ground) end
        end
        return nil
    end
    function b:water(state)
        local char=player.Character
        local biome=attr(Workspace,"FeralBiome") or "WolfValley"
        local landmarks=self.spots and (self.spots[biome] or self.spots.WolfValley)
        if type(landmarks)~="table" then return nil end
        local best,bestScore=nil,math.huge
        for _,spot in ipairs(landmarks) do
            local name=string.lower(tostring(spot.name or spot.key or ""))
            if typeof(spot.pos)=="Vector2" and
                (name:find("water",1,true) or name:find("lake",1,true)
                or name:find("pond",1,true) or name:find("river",1,true)
                or name:find("falls",1,true) or name:find("spring",1,true)) then
                for k=0,11 do
                    local angle=k*math.pi/6
                    local x=spot.pos.X+math.cos(angle)*22
                    local z=spot.pos.Y+math.sin(angle)*22
                    local land=groundAt(x,z,char)
                    if land then
                        local candidate=point(land)
                        local d=dist(candidate,state.position)
                        local blocked=false
                        for _,p in ipairs(state.players or {}) do
                            if dist(p,candidate)<120 then blocked=true;break end
                        end
                        if not blocked and d<bestScore then best,bestScore=candidate,d end
                    end
                end
            end
        end
        return best
    end
    function b:snapshot(now)
        local c,h,r=validAnimal()
        local species,coat=fullStats(c)
        local alive=c~=nil and c.Parent~=nil and h~=nil and r~=nil and h.Health>0
        if not alive then return {alive=false,species=species,coat=coat} end
        self:refresh(now)
        local nowServer
        pcall(function() nowServer=Workspace:GetServerTimeNow() end)
        local untilCombat=attr(player,"FeralCombatUntil")
        local typing=UserInput:GetFocusedTextBox()~=nil
        local movingKeys={Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,
            Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.Left,Enum.KeyCode.Right}
        local manual=typing
        for _,key in ipairs(movingKeys) do
            local ok,down=pcall(UserInput.IsKeyDown,UserInput,key)
            if ok and down then manual=true;break end
        end
        local combat=finite(nowServer) and finite(untilCombat) and untilCombat>nowServer or false
        local power=attr(c,"FeralRolling")==true or attr(c,"FeralDowned")==true
            or attr(c,"FeralVenomDown")==true or attr(c,"FeralTalonLock")~=nil
            or attr(c,"FeralTumbleAt")~=nil or attr(c,"FeralDeathRollLocal")==true
        local amber=attr(player,"Amber")
        if not finite(amber) then
            local stats=player:FindFirstChild("leaderstats")
            local v=stats and stats:FindFirstChild("Amber")
            if v and typeof(v.Value)=="number" then amber=v.Value end
        end
        local hub=(type(getgenv)=="function" and getgenv() or _G).FERAL_RENAISSANCE_ACTIVE
        local menu=attr(player,"FeralMenuOpen")==true
            or hub and hub.policy and hub.policy.menuOpen==true
        return {alive=true,char=c,hum=h,root=r,position=point(r.Position),
            species=species,coat=coat,pack=attr(player,"FeralPack"),
            healthFraction=h.MaxHealth>0 and h.Health/h.MaxHealth or 0,
            hunger=attr(c,"Hunger"),thirst=attr(c,"Thirst"),feedCan=attr(c,"FeedCan"),
            feedMode=attr(c,"WolfFeed"),
            amber=amber,now=now,unixNow=os.time(),players=self:otherPlayerPositions(),
            avoidRadius=110,claimRadius=17,careTarget=65,menuOpen=menu or typing,
            manualInput=manual,combat=combat,pinned=attr(c,"FeralPinned")==true
                or attr(c,"FeralDragged")==true or attr(c,"FeralCarried")==true,
            ability=power,resting=attr(c,"WolfRest")==true,
            flying=attr(c,"FeralFlyLocal")==true,
            swimming=attr(c,"FeralSwimLocal")==true,
            underwater=attr(c,"FeralUnderwater")==true}
    end
    function b:move(destination,state)
        if not destination then return "WAIT" end
        -- Pathfinding and Humanoid:MoveTo are the only movement writers.
        local target=Vector3.new(destination.x,state.root.Position.Y,destination.z)
        local players={}
        for _,p in ipairs(state.players or {}) do
            table.insert(players,Vector3.new(p.x,state.root.Position.Y,p.z))
        end
        local result=self.nav:tick(target,state.char,state.hum,state.root,state.now,players)
        self.motionReason=self.nav.lastReason
        return result
    end
    function b:stop(reason)
        self.motionReason=reason
        local c,h,r=validAnimal()
        self.nav:stop(h,r,reason)
    end
    function b:feed(state,kind)
        if state.feedCan~=kind then return false end
        if state.menuOpen or state.manualInput then return false end
        local ok,virtual=pcall(function() return game:GetService("VirtualInputManager") end)
        if ok and virtual then
            local sent=pcall(function()
                virtual:SendKeyEvent(true,Enum.KeyCode.E,false,game)
                task.wait(.07)
                virtual:SendKeyEvent(false,Enum.KeyCode.E,false,game)
            end)
            if sent then return true end
        end
        if type(keypress)=="function" and type(keyrelease)=="function" then
            return pcall(function() keypress(0x45);task.wait(.07);keyrelease(0x45) end)
        end
        return false
    end
    local function alliedNPC(model)
        local mine=attr(player,"FeralPack")
        local pack=attr(model,"FeralPack")
        return mine~=nil and pack~=nil and mine==pack
    end
    local hunters={Bear=true,Wolf=true,Tiger=true,Lion=true,Jaguar=true,Cobra=true,
        KingCobra=true,Crocodile=true,SaltwaterCrocodile=true,Alligator=true,
        BaldEagle=true,Eagle=true,Vulture=true,Leopard=true,Hyena=true,
        Fox=true,Python=true,Otter=true}
    function b:checkPrey(prey,state)
        if not prey or not prey.model or not prey.model.Parent
            or not hunters[state.species] then return nil end
        if Players:GetPlayerFromCharacter(prey.model) then return nil end
        local root=prey.model:FindFirstChild("HumanoidRootPart")
        local hum=prey.model:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health<=0 or attr(prey.model,"FeralDead")==true
            or alliedNPC(prey.model) then return nil end
        if hum.MaxHealth>state.hum.MaxHealth*1.2 then return nil end
        local position=point(root.Position)
        for _,p in ipairs(state.players or {}) do
            if dist(position,p)<100 then return nil end
        end
        prey.position=position;prey.root=root;prey.hum=hum
        return prey
    end
    function b:prey(state)
        if not hunters[state.species] then return nil end
        local folder=Workspace:FindFirstChild("FeralNPCs")
        if not folder then return nil end
        local best,bestDist=nil,math.huge
        for i,npc in ipairs(folder:GetChildren()) do
            if i>96 then break end
            if npc:IsA("Model") then
                local p=self:checkPrey({model=npc},state)
                if p then
                    local d=dist(p.position,state.position)
                    if d<270 and d<bestDist then best,bestDist=p,d end
                end
            end
        end
        return best
    end
    function b:bite(state,prey)
        local p=self:checkPrey(prey,state)
        if not p then return false end
        local direction=p.root.Position-state.root.Position
        local planar=Vector3.new(direction.X,0,direction.Z)
        if planar.Magnitude<.1 or planar.Magnitude>22 then return false end
        local forward=state.root.CFrame.LookVector
        local flat=Vector3.new(forward.X,0,forward.Z)
        if flat.Magnitude<.1 or flat.Unit:Dot(planar.Unit)<.35 then
            -- Natural rotation occurs during a MoveTo approach, never PivotTo.
            self:move(p.position,state)
            return false
        end
        local ok,virtual=pcall(function() return game:GetService("VirtualInputManager") end)
        if ok and virtual then
            local m=UserInput:GetMouseLocation()
            local sent=pcall(function()
                virtual:SendMouseButtonEvent(m.X,m.Y,0,true,game,0)
                task.wait(.04)
                virtual:SendMouseButtonEvent(m.X,m.Y,0,false,game,0)
            end)
            if sent then return true end
        end
        if type(mouse1click)=="function" then return pcall(mouse1click) end
        return false
    end
    return b
end
return Bridge
