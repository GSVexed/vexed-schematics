-- Native FERAL data boundary; shared logic does not imply every mode is supported.
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
        cfg=nil,spots=nil,territoryInstance=nil,refreshAt=0,lastString=nil,
        lastBiome=nil,motionReason="Idle",manualUncertain=false,spotCache={},spotTry={},
        configs={},configInstances={},configRevision=0,manualButtons={},waterBlocked={},preyBlocked=setmetatable({},{__mode="k"}),foodBlocked=setmetatable({},{__mode="k"}),
        connections={},inputEpoch=0,territorySamples={},operations={surface=0,food=0,prey=0},synthetic={},generation=0,
        coverage={},coverageOrder={},nativeCosts={}}
    local world=Rep:FindFirstChild("FeralWorld")
    local function config(name)
        local module=world and world:FindFirstChild(name)
        local previous=b.configInstances[name]
        if b.configs[name] and previous==module then return b.configs[name] end
        if previous~=module then b.configRevision+=1 end
        b.configs[name]=nil;b.configInstances[name]=module
        if not module or not module:IsA("ModuleScript") then return nil end
        local ok,value=pcall(require,module)
        if ok and type(value)=="table" then b.configs[name]=value;return value end
        return nil
    end
    b.config=config
    local function measured(name,fn,...)
        local started=os.clock();local result=table.pack(pcall(fn,...))
        local elapsed=math.max(0,os.clock()-started)
        local cost=b.nativeCosts[name] or {calls=0,total=0,max=0};b.nativeCosts[name]=cost
        cost.calls+=1;cost.total+=elapsed;cost.max=math.max(cost.max,elapsed)
        return table.unpack(result,1,result.n)
    end
    function b:hub()
        local h=self.ownerHub or (type(getgenv)=="function" and getgenv() or _G).FERAL_RENAISSANCE_ACTIVE
        return type(h)=="table" and not h.closed and h.bridge and h.bridge.player==player and h or nil
    end
    function b:recover(state,on)
        local h=self:hub()
        if not h then return false end
        if on then h.territoryRecoveryOwner=self
        elseif h.territoryRecoveryOwner==self then
            h.territoryRecoveryOwner=nil
            if h.recovery and not h.registry.byId.recovery.requested then h.recovery:release("Territory recovery ended",state and state.now or os.clock()) end
        end
        return on and h.recovery~=nil
    end
    function b:resetDiscovery(identity)
        local same=self.identity~=nil
        for _,key in ipairs({"char","root","profile","pack","biome","territory","world","configRevision"}) do if not self.identity or self.identity[key]~=identity[key] then same=false;break end end
        if same then return end
        self.identity=identity;self.generation+=1
        local char=player.Character
        self.nav:stop(char and char:FindFirstChildOfClass("Humanoid"),char and char:FindFirstChild("HumanoidRootPart"),"GENERATION_CHANGED")
        self.spotCache,self.spotTry,self.territorySamples={},{},{}
        self.waterBlocked={};self.preyBlocked=setmetatable({},{__mode="k"});self.foodBlocked=setmetatable({},{__mode="k"})
        for _,name in ipairs({"waterCache","waterScan","waterMissUntil","waterAt","searchPoint","searchVisits","searchUntil",
            "patrolTarget","patrolVisits","patrolUntil","foodIndex","preyIndex","foodBest","preyBest","lastAttackInput","attackCharacter","foodETA","drinkETA","foodObserved","drinkObserved","observedDamage","nextBite"}) do self[name]=nil end
        self.nav.recoveryCells={};self.nav.trajectory={};self.nav.surfaceCache={}
        self:releaseInputs();self:recover(nil,false)
        if self.nav.model then self.nav.model:reset(identity) end
    end
    function b:prepare(now,enabled,goal)
        local h=self:hub()
        if not enabled or not h then return end
        if h.walk and type(h.stopWalk)=="function" then h:stopWalk("Amber movement owner") end
        h.nextWalk=now+90
        -- Coordinate with existing recovery instead of letting it start Rest
        -- during travel, feeding approach or hunt preparation.
        local recovering=goal and goal.kind=="RECOVER"
        self:recover({now=now},recovering==true)
        if recovering and h.recovery and h.recovery.owned==player.Character
            and not (h.policy and h.policy.manualRest) then
            local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            recovering=not (hum and hum.MaxHealth>0 and hum.Health/hum.MaxHealth>=.72)
        end
        if not recovering then
            if h.policy then h.policy.actionUntil=math.max(h.policy.actionUntil or 0,now+.6) end
            if h.recovery and type(h.recovery.release)=="function" then h.recovery:release("Amber objective",now) end
        end
    end
    b.cfg=config("TerritoryConfig")
    b.spots=config("MapSpots")
    b.territoryInstance=Rep:FindFirstChild("FeralTerritory")
    local function attr(object,key)
        if not object then return nil end
        local ok,value=pcall(function() return object:GetAttribute(key) end)
        if ok then return value end
        return nil
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
    local function packKey(value)
        if value==nil or value==false or value==0 or value=="0" or value=="" or value=="None" then return nil end
        return tostring(value)
    end
    function b:hexAt(position)
        if not self.cfg or type(self.cfg.hexAt)~="function" or not position then return nil end
        local ok,i,j=pcall(self.cfg.hexAt,position.x,position.z)
        if not ok then return nil end
        if type(self.cfg.hexKey)=="function" then
            local good,key=pcall(self.cfg.hexKey,i,j)
            if good then return key end
        end
        return "H"..tostring(i).."_"..tostring(j)
    end
    function b:otherPlayerPositions()
        local all,occupied={},{}
        local mine=packKey(attr(player,"FeralPack"))
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player then
                local c=p.Character
                local root=c and c:FindFirstChild("HumanoidRootPart")
                local theirs=packKey(attr(p,"FeralPack") or attr(c,"FeralPack"))
                local same=mine~=nil and theirs==mine
                if root and not same then
                    local pos=point(root.Position);pos.hex=self:hexAt(pos)
                    table.insert(all,pos)
                    if pos.hex then occupied[pos.hex]=(occupied[pos.hex] or 0)+1 end
                end
            end
        end
        return all,occupied
    end
    function b:refresh(now)
        local currentWorld=Rep:FindFirstChild("FeralWorld")
        if currentWorld~=world then world=currentWorld;self.configs={};self.configInstances={};self.configRevision+=1;self.cfg=nil;self.spots=nil;self.lastString=nil;self.hexes={};self.hexByKey={} end
        if self.configInstances.TerritoryConfig or world and world:FindFirstChild("TerritoryConfig") then
            local latest=config("TerritoryConfig")
            if latest~=self.cfg then self.cfg=latest;self.lastString=nil;self.hexes={};self.hexByKey={} end
        end
        if self.configInstances.MapSpots or world and world:FindFirstChild("MapSpots") then self.spots=config("MapSpots") end
        local currentTerritory=Rep:FindFirstChild("FeralTerritory")
        if currentTerritory~=self.territoryInstance then self.territoryInstance=currentTerritory;self.lastString=nil;self.hexes={};self.hexByKey={} end
        if not self.cfg or not self.territoryInstance then
            world=Rep:FindFirstChild("FeralWorld")
            self.cfg=config("TerritoryConfig")
            self.spots=config("MapSpots")
            self.territoryInstance=Rep:FindFirstChild("FeralTerritory")
            if not self.cfg or not self.territoryInstance then return end
        end
        self.spots=self.spots or config("MapSpots")
        local previous=self.territoryContract
        local changed=not previous
        for _,key in ipairs({"parseHexes","hexCenter","hexAt","hexKey","CLAIM_RADIUS","CLAIM_TIME","REFILL_TIME"}) do
            if not previous or previous[key]~=self.cfg[key] then changed=true;break end
        end
        if changed then
            self.territoryContract={}
            for _,key in ipairs({"parseHexes","hexCenter","hexAt","hexKey","CLAIM_RADIUS","CLAIM_TIME","REFILL_TIME"}) do self.territoryContract[key]=self.cfg[key] end
            self.lastString=nil;self.hexes={};self.hexByKey={};self.spotCache={};self.territorySamples={}
            self.configRevision+=1
        end
        local text=attr(self.territoryInstance,"Hexes")
        local biome=attr(Workspace,"FeralBiome") or "WolfValley"
        if type(text)~="string" or #text==0 or type(self.cfg.parseHexes)~="function"
            or type(self.cfg.hexCenter)~="function" then return end
        if text==self.lastString and biome==self.lastBiome then return end
        local ok,parsed=pcall(self.cfg.parseHexes,text)
        if not ok or type(parsed)~="table" then return end
        self.lastString,self.lastBiome=text,biome
        self.spotCache,self.spotTry={},{}
        local hexes,byKey={},{}
        for _,t in ipairs(parsed) do
            if type(t.key)=="string" and type(t.i)=="number" and type(t.j)=="number" then
                local good,p=pcall(self.cfg.hexCenter,t.i,t.j)
                if good and p and ((typeof(p)=="Vector2")
                    or (type(p)=="table" and finite(p.X) and finite(p.Y))) then
                    local h={key=t.key,center={x=p.X,z=p.Y}}
                    if type(self.cfg.regionCell)=="function" then
                        local valid,region=pcall(self.cfg.regionCell,p.X,p.Y)
                        if valid and finite(region) then h.region=region end
                    end
                    table.insert(hexes,h);byKey[t.key]=h
                end
            end
        end
        local landmarks=self.spots and self.spots[biome]
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
        local t=b.territoryInstance
        return attr(t,key.."_"..suffix)
    end
    function b:territory(key)
        if not self.territoryInstance then return nil end
        local h=self.hexByKey[key]
        if not h then return nil end
        local pay=terrAttr(key,"pay") or terrAttr(key,"income") or terrAttr(key,"amber")
        local owner,by=terrAttr(key,"owner"),terrAttr(key,"by")
        local mine=attr(player,"FeralPack")
        if packKey(owner) and packKey(owner)==packKey(mine) then owner=mine end
        if packKey(by) and packKey(by)==packKey(mine) then by=mine end
        local hold,prog=terrAttr(key,"hold"),terrAttr(key,"prog")
        local now=self.observationNow or os.clock();local sample=self.territorySamples[key]
        if not sample or sample.owner~=owner or not finite(sample.hold) or not finite(hold) or now-sample.at>30 then
            sample={owner=owner,hold=hold,prog=prog,at=now};self.territorySamples[key]=sample
        elseif now>sample.at+.2 and finite(hold) and finite(sample.hold) and hold~=sample.hold then
            local dt=now-sample.at;local rate=(sample.hold-hold)/dt
            if rate>0 and rate<.1 then sample.decay=sample.decay and sample.decay*.6+rate*.4 or rate end
            if hold>sample.hold and dt<8 then self.progressLatency=(self.progressLatency or dt)*.7+dt*.3 end
            sample.hold=hold;sample.at=now
        end
        return {key=key,neutral=terrAttr(key,"neutral")==true or self.cfg and self.cfg.ON==false,
            owner=owner,by=by,prog=prog,hold=hold,
            pay=finite(pay) and pay or nil,decayPerSecond=sample.decay,deadlineSeconds=sample.decay and finite(hold) and math.max(0,hold-.08)/sample.decay or nil,
            fade=terrAttr(key,"fade"),center=h.center,spot=h.spot,region=h.region}
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
    function b:counts(state)
        local pack=state and state.pack or attr(player,"FeralPack")
        local result={total=0,eligible=0,neutral=0,owned=0,other=0,fading=0}
        for _,hex in ipairs(self:territories(state or {now=os.clock()})) do
            result.total+=1
            if hex.neutral then
                result.neutral+=1
            else
                result.eligible+=1
                if pack~=nil and hex.owner==pack then
                    result.owned+=1
                    if finite(hex.hold) and hex.hold<.84 then result.fading+=1 end
                else result.other+=1 end
            end
        end
        return result
    end
    local function groundAt(x,z,c)
        local root=c and c:FindFirstChild("HumanoidRootPart")
        if root and type(b.nav.surface)=="function" then
            return b.nav:surface(Vector3.new(x,root.Position.Y,z),c,false)
        end
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
    -- Native hex geometry contains the entire territory pool; MapSpots is
    -- supplemental, not a whitelist. Sample walkable ground inside each hex,
    -- favouring genuine named claim zones where one exists.
    function b:territorySpot(key,state)
        local h=self.hexByKey[key]
        if not h then return nil end
        -- Distant hex terrain is commonly unstreamed in Roblox. Travel toward
        -- the replicated geometry first; only demand a physical claim spot
        -- after the animal is near enough for the terrain to stream in.
        local origin=state and state.position
        if origin and dist(origin,h.spot or h.center)>210 then
            return h.spot or h.center
        end
        local cached=self.spotCache[key]
        if cached and (self.spotTry[key] or 0)==cached.index and (state.now or 0)-(cached.at or 0)<8 then
            local safe=true
            for _,p in ipairs(state.players or {}) do if dist(cached.pos,p)<(state.avoidRadius or 35) then safe=false end end
            if safe then return cached.pos end
        end
        local c=player.Character
        local focus=h.spot or h.center
        local candidate={}
        local attempt=self.spotTry[key] or 0
        if origin and attempt==0 then
            if self:hexAt(origin)==key and dist(origin,focus)<(self.cfg.CLAIM_RADIUS or 120)-8 then table.insert(candidate,origin) end
            local d=dist(origin,focus)
            local margin=math.max(10,state.root and state.root.Size.X or 10)
            local radius=math.max(8,(self.cfg.CLAIM_RADIUS or 120)-margin)
            if d>radius then
                table.insert(candidate,{x=focus.x+(origin.x-focus.x)/d*radius,z=focus.z+(origin.z-focus.z)/d*radius})
            end
        end
        table.insert(candidate,focus)

        local ring={12,25,40,57,75}
        for _,radius in ipairs(ring) do
            for direction=0,11 do
                local angle=direction*math.pi/6
                table.insert(candidate,{x=focus.x+math.cos(angle)*radius,
                    z=focus.z+math.sin(angle)*radius})
            end
        end
        if h.spot then table.insert(candidate,h.center) end
        -- Broad fallback candidates are evaluated in rank order and stop once
        -- a useful distinct access exists; no whole ring scan on every visit.
        local native=self.cfg
        local previous=cached and cached.pos
        local viable={}
        local checks=0
        for index,p in ipairs(candidate) do
            local matching=true
            if attempt>0 and index<=attempt then matching=false end
            if previous and attempt>0 and dist(previous,p)<18 then matching=false end
            if matching and type(native.hexAt)=="function" then
                local ok,i,j=pcall(native.hexAt,p.x,p.z)
                if not ok then matching=false else
                    local hexKey
                    if type(native.hexKey)=="function" then
                        local good,keyResult=pcall(native.hexKey,i,j)
                        if good then hexKey=keyResult end
                    else
                        hexKey="H"..tostring(i).."_"..tostring(j)
                    end
                    matching=hexKey==key
                end
            end
            if matching and (not h.spot or dist(p,h.spot)<math.max(10,(self.cfg.CLAIM_RADIUS or 120)-12)) then
                checks+=1
                local ground=groundAt(p.x,p.z,c)
                if ground then
                    local q=point(ground);q.moveRadius=3
                    local clear=true
                    for _,other in ipairs(state and state.players or {}) do
                        if dist(q,other)<(state.avoidRadius or 110) then clear=false;break end
                    end
                    if clear then table.insert(viable,q);break end
                end
            end
            if checks>=12 then break end
        end
        self.operations.spotChecks=checks
        if #viable==0 then return nil end
        -- Walkable alternative landing slots are used only after a genuine
        -- no-progress timeout, never to teleport or change hex ownership.
        local index=1
        local position=viable[index]
        self.spotCache[key]={index=self.spotTry[key] or 0,pos=position,at=state.now or 0}
        return position
    end
    function b:advanceSpot(key)
        if not self.hexByKey[key] then return end
        self.spotTry[key]=math.min(3,(self.spotTry[key] or 0)+1)
    end
    function b:manualInput(nativeDirection)
        -- The PlayerModule supplies physical keyboard/gamepad/touch direction
        -- before the hub replaces it. Preserve it on that very input frame.
        if nativeDirection and type(nativeDirection.Magnitude)=="number" and nativeDirection.Magnitude>.15 then
            self.manualUntil=os.clock()+.6
        end
        if self.manualStick or next(self.manualButtons) then return true end
        if os.clock()<(self.manualUntil or 0) then return true end
        if UserInput:GetFocusedTextBox() then return true end
        if type(UserInput.IsMouseButtonPressed)=="function" and Enum.UserInputType then
            local ok,down=pcall(UserInput.IsMouseButtonPressed,UserInput,Enum.UserInputType.MouseButton1)
            if ok and down and not (self.pendingInputs and self.pendingInputs.M1) then return true end
        end
        for _,name in ipairs({"W","A","S","D","Up","Down","Left","Right","Space","LeftShift","X","Z","E","R","Q"}) do
            local key=Enum.KeyCode[name]
            if key then
                local ok,down=pcall(UserInput.IsKeyDown,UserInput,key)
                if ok and down and not self.nav.held[name=="LeftShift" and "SHIFT" or name] and not (self.pendingInputs and self.pendingInputs[name]) then return true end
            end
        end
        return false
    end
    local function safePosition(p,state,radius)
        for _,other in ipairs(state.players or {}) do
            if dist(p,other)<(radius or state.avoidRadius or 110) then return false end
        end
        return true
    end
    local function surfaceAt(x,z,state,waterAllowed)
        b.operations.surface+=1
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={state.char};params.IgnoreWater=false;params.RespectCanCollide=true
        local hit=Workspace:Raycast(Vector3.new(x,state.root.Position.Y+120,z),Vector3.new(0,-460,0),params)
        if not hit then return nil end
        local water=hit.Material==Enum.Material.Water
        if water and not waterAllowed or not water and hit.Normal.Y<.5 then return nil end
        return point(hit.Position),water
    end
    function b:avoidWater(position,now)
        if position then
            local key=string.format("%d:%d",math.floor(position.x/12),math.floor(position.z/12))
            self.waterBlocked[key]=now+90
        end
        self.waterCache=nil;self.waterAt=0;self.waterScan=nil;self.waterMissUntil=nil
    end
    function b:water(state)
        local best,score=nil,math.huge
        local coarse,coarseDistance=nil,math.huge
        local function consider(candidate)
            local key=string.format("%d:%d",math.floor(candidate.x/12),math.floor(candidate.z/12))
            if (self.waterBlocked[key] or 0)>state.now or not safePosition(candidate,state,120) then return end
            local d=dist(candidate,state.position)
            if d<score then best,score=candidate,d end
        end
        -- FeedCanPos is the real current native offer, not a guessed landmark.
        if state.feedCan=="drink" and state.feedPosition then consider(state.feedPosition) end
        local finder=config("FeedFinder")
        local needs=config("NeedsConfig")
        if finder and type(finder.waterAround)=="function" then
            local ok,p=measured("FeedFinder.waterAround",finder.waterAround,state.char,state.root,needs and needs.WATER_PROMPT_PROBES)
            if ok and typeof(p)=="Vector3" then consider(point(p)) end
        end
        if best then
            self.waterEvidence="NATIVE_OFFER";self.waterCache,self.waterAt=best,state.now;return best
        end
        if self.waterCache and state.now<(self.waterAt or 0)+3 then return self.waterCache end
        if self.waterMissUntil and state.now<self.waterMissUntil then return nil end
        -- Find actual nearby terrain water. Also sample progressively larger
        -- landmark rings: a lake's centre is not necessarily its shoreline.
        local origins={{x=state.position.x,z=state.position.z,rings={10,24,48,90,150}}}
        local biome=state.biome
        local spots=self.spots and self.spots[biome]
        for _,spot in ipairs(type(spots)=="table" and spots or {}) do
            local name=string.lower(tostring(spot.key or spot.name or ""))
            if typeof(spot.pos)=="Vector2" and (spot.drinkR or name:find("water",1,true)
                or name:find("lake",1,true) or name:find("pond",1,true) or name:find("river",1,true)
                or name:find("creek",1,true) or name:find("marsh",1,true) or name:find("fall",1,true)) then
                table.insert(origins,{x=spot.pos.X,z=spot.pos.Y,rings={0,30,80,160,spot.drinkR or 240}})
                local p={x=spot.pos.X,z=spot.pos.Y}
                local d=dist(p,state.position)
                local key=string.format("%d:%d",math.floor(p.x/12),math.floor(p.z/12))
                if d<coarseDistance and safePosition(p,state,120) and (self.waterBlocked[key] or 0)<=state.now then
                    coarse,coarseDistance=p,d
                end
            end
        end
        table.sort(origins,function(a,b)return dist(a,state.position)<dist(b,state.position)end)
        local scan=self.waterScan
        if not scan or scan.char~=state.char or scan.biome~=state.biome
            or state.now-scan.at>6 or dist(scan.position,state.position)>100 then
            scan={at=state.now,char=state.char,biome=state.biome,position={x=state.position.x,z=state.position.z},points={},index=1}
            for _,origin in ipairs(origins) do
                for _,radius in ipairs(origin.rings) do
                    for k=0,(radius==0 and 0 or 7) do
                        local a=k*math.pi/4
                        table.insert(scan.points,{x=origin.x+math.cos(a)*radius,z=origin.z+math.sin(a)*radius,
                            dx=math.cos(a),dz=math.sin(a)})
                    end
                end
            end
            self.waterScan=scan
        end
        -- Bound terrain work per coordinator tick. Resume unfinished searches
        -- instead of repeating the whole map scan after an empty result.
        local stop=math.min(#scan.points,scan.index+23)
        for index=scan.index,stop do
            local probe=scan.points[index]
            local x,z=probe.x,probe.z
            local pos,wet=surfaceAt(x,z,state,true)
            if pos and wet then
                consider(pos)
                for _,reach in ipairs({7,15}) do
                    local bank=surfaceAt(x-probe.dx*reach,z-probe.dz*reach,state,false)
                    if bank and dist(bank,pos)<=reach+1 then consider(bank) end
                end
            end
        end
        scan.index=stop+1
        if scan.index>#scan.points then
            self.waterScan=nil;self.waterMissUntil=state.now+1.2
        end
        self.waterEvidence=best and "TERRAIN_OR_NATIVE_OFFER" or coarse and "LANDMARK_APPROACH" or "NONE"
        self.waterCache,self.waterAt=best or coarse,state.now
        if self.waterCache then self.drinkETA=(state.travelCost and state.travelCost(state.position,self.waterCache) or dist(state.position,self.waterCache)/24)+12 end
        return self.waterCache
    end
    function b:profile(char,species)
        local cfg=config("Species")
        local known=cfg and cfg.List and cfg.List[species]
        if not known then return {known=false,hunts=false,swim=false,support="unknown species profile"} end
        local forage=config("Forage")
        local hunts=known.diet=="carnivore" or known.diet=="omnivore"
        if forage and type(forage.canEat)=="function" then
            local ok,value=pcall(forage.canEat,known.diet,"meat")
            if ok then hunts=value==true end
        end
        local needs=config("NeedsConfig")
        local gaits
        if game.PlaceVersion==2412 and type(cfg.scaled)=="function" then
            local growth=attr(char,"Growth") or 1
            local ok,speed=pcall(cfg.scaled,species,"speed",growth)
            local valid,gait=pcall(cfg.scaled,species,"gait",growth)
            local walk=known.walkMul or 1
            if type(known.walkMulStage)=="table" and type(cfg.stage)=="function" then
                local good,stage=pcall(cfg.stage,growth,species)
                if good then walk=known.walkMulStage[stage] or walk end
            end
            local scale=attr(char,"SpeedScale") or attr(char,"MoveScale") or 1
            if ok and valid and finite(speed) and finite(gait) and finite(walk) and finite(scale) then
                local run=needs and needs.RUN_SPEED or 1
                local burst=needs and needs.BURST
                if finite(run) and run>0 then
                    gaits={WALK=7/42*gait*walk*scale,TROT=16.8/42*gait*walk*scale,SPRINT=speed*run*scale}
                    if burst and burst.ENABLED==true and finite(burst.SPEED) and burst.SPEED>=1 and burst.SPEED<=3 then gaits.BURST=gaits.SPRINT*burst.SPEED end
                end
            end
        end
        local surfaceSwim=known.swim~=false and (finite(known.swimSprint) and known.swimSprint>0
            or finite(known.swim) and known.swim>0 or needs and finite(needs.SWIM_SPEED) and needs.SWIM_SPEED>0)
        return {known=true,diet=known.diet,gaits=gaits,swim=surfaceSwim==true,support="ground and configured surface swimming; aerial/depth/climb routing unverified",swimSprint=finite(known.swimSprint) and known.swimSprint>0,
            hunts=hunts,
            native=known}
    end
    function b:recordCoverage(profile,species,profileKey,biome,now)
        local key=tostring(game.PlaceVersion)..":"..tostring(species)..":"..tostring(biome)..":"..tostring(profile.diet)
        local item=self.coverage[key]
        if not item then
            item={gameVersion=game.PlaceVersion,species=species,biome=biome,diet=profile.diet,firstSeen=now,
                status=profile.known and "PARTIAL" or "UNKNOWN",
                ground=profile.known and "implemented; live acceptance unverified" or "unknown native profile",
                surfaceWater=profile.swim and "implemented; live acceptance unverified" or "not established",
                climb="unimplemented",flight="unimplemented",depth="unimplemented",samples=0}
            self.coverage[key]=item;table.insert(self.coverageOrder,key)
            if #self.coverageOrder>64 then self.coverage[table.remove(self.coverageOrder,1)]=nil end
        end
        item.lastSeen=now;item.samples+=1;item.profile=profileKey
        return item
    end
    function b:snapshot(now)
        local c,h,r=validAnimal()
        local species,coat=fullStats(c)
        local alive=c~=nil and c.Parent~=nil and h~=nil and r~=nil and h.Health>0
        if not alive then return {alive=false,species=species,coat=coat,now=now} end
        self:refresh(now)
        local biome=attr(Workspace,"FeralBiome") or "WolfValley"
        local body=self.bodyProfile
        if not body or body.char~=c or body.species~=species or math.abs(r.Size.X/body.x-1)>.15
            or math.abs(r.Size.Y/body.y-1)>.15 or math.abs(r.Size.Z/body.z-1)>.15 then
            self.bodySerial=(self.bodySerial or 0)+1
            body={char=c,species=species,x=math.max(.01,r.Size.X),y=math.max(.01,r.Size.Y),z=math.max(.01,r.Size.Z)}
            self.bodyProfile=body
        end
        local profileKey=tostring(species)..":body"..self.bodySerial
        for _,name in ipairs({"Species","NeedsConfig","Forage","FeedFinder","CombatConfig"}) do config(name) end
        self:resetDiscovery({char=c,root=r,profile=profileKey,pack=attr(player,"FeralPack"),biome=biome,territory=self.territoryInstance,world=world,configRevision=self.configRevision})
        self.observationNow=now
        if now>=(self.nextPrune or 0) then
            self.nextPrune=now+10
            for _,cache in ipairs({self.waterBlocked,self.preyBlocked,self.foodBlocked}) do
                for key,untilAt in pairs(cache) do if untilAt<=now then cache[key]=nil end end
            end
        end
        local at;pcall(function()at=Workspace:GetServerTimeNow()end)
        local untilCombat=attr(player,"FeralCombatUntil")
        local stamina,maximum=attr(c,"Stamina"),attr(c,"StaminaMax")
        local reserve=finite(stamina) and finite(maximum) and maximum>0 and math.clamp(stamina/maximum,0,1) or nil
        local burstNo=attr(player,"HudBurstNo")
        local profile=self:profile(c,species)
        self.currentCoverage=self:recordCoverage(profile,species,profileKey,biome,now)
        local hub=self:hub()
        local grabBusy=hub and hub.grab and hub.grab.active==true or false
        if hub and type(hub.hasNativeGrab)=="function" then
            local valid,active=pcall(hub.hasNativeGrab,hub,now)
            grabBusy=not valid or active==true
        end
        local feed,feedStarted,feedKnown
        if hub and type(hub.bridge.nativeFeedState)=="function" then
            local ok,mode,started,known=pcall(hub.bridge.nativeFeedState,hub.bridge,now)
            if ok then feed,feedStarted,feedKnown=mode,started,known end
        end
        local needs=config("NeedsConfig") or {}
        local attackCooldown
        local speciesConfig=config("Species")
        if speciesConfig and type(speciesConfig.biteCooldown)=="function" then
            local good,value=pcall(speciesConfig.biteCooldown,species,attr(c,"Growth") or 1)
            if good and finite(value) and value>=.1 and value<=10 then attackCooldown=value end
        end
        if hub and type(hub.bridge.serverNow)=="function" then
            local valid,value=pcall(hub.bridge.serverNow,hub.bridge)
            if valid and finite(value) then at=value end
        end
        local combatKnown=finite(at) and (untilCombat==nil or finite(untilCombat))
        local combat=combatKnown and (untilCombat or 0)>at
        local offer=attr(c,"FeedCanPos")
        local others,contested=self:otherPlayerPositions()
        local amber=attr(player,"Amber")
        if not finite(amber) then
            local stats=player:FindFirstChild("leaderstats")
            local v=stats and stats:FindFirstChild("Amber")
            if v and finite(v.Value) then amber=v.Value end
        end
        local pack=attr(player,"FeralPack")
        if pack==0 or pack=="" or pack=="0" or pack==false then pack=nil end
        local swimming=attr(c,"FeralSwimLocal")==true
        local ok,humState=pcall(h.GetState,h)
        if ok and Enum.HumanoidStateType and humState==Enum.HumanoidStateType.Swimming then swimming=true end
        local fly=attr(c,"FeralFlyLocal")==true
        local hunger,thirst=attr(c,"Hunger"),attr(c,"Thirst")
        local hm=needs.HUNGER_MAX==nil and 100 or needs.HUNGER_MAX
        local tm=needs.THIRST_MAX==nil and 100 or needs.THIRST_MAX
        local knownNeeds=finite(hm) and hm>0 and finite(tm) and tm>0 and finite(hunger) and hunger>=0 and hunger<=hm*1.05
            and finite(thirst) and thirst>=0 and thirst<=tm*1.05
        hm=finite(hm) and hm>0 and hm or 100;tm=finite(tm) and tm>0 and tm or 100
        local model=self.nav.model
        local travelSpeed=profile.gaits and (profile.gaits.BURST or profile.gaits.SPRINT)
            or (self.nav.speed>6 and math.clamp(self.nav.speed,6,80) or 24)
        local hudBurst=attr(player,"HudBurst")
        if type(hudBurst)~="boolean" then hudBurst=attr(c,"WolfBurst") end
        local hudTrot=attr(player,"HudTrot")
        if type(hudTrot)~="boolean" then hudTrot=attr(c,"WolfTrot") end
        return {alive=true,char=c,hum=h,root=r,position=point(r.Position),
            species=species,coat=coat,profile=profile,pack=pack,profileKey=profileKey..":"..hm..":"..tm,generation=self.generation,
            travelSpeed=travelSpeed,travelCost=model and function(a,b,purpose)return model:estimate(a,b,now,travelSpeed,purpose)end,
            foodETA=math.max(self.foodETA or 0,self.foodObserved or 0),drinkETA=math.max(self.drinkETA or 0,self.drinkObserved or 0),
            progressLatency=self.progressLatency,needsKnown=knownNeeds,hungerMax=hm,thirstMax=tm,
            biome=attr(Workspace,"FeralBiome") or "WolfValley",healthFraction=h.MaxHealth>0 and h.Health/h.MaxHealth or 0,
            hunger=hunger,thirst=thirst,feedCan=attr(c,"FeedCan"),
            feedMode=attr(c,"WolfFeed"),nativeFeedMode=feed,nativeFeedKnown=feedKnown,feedStarted=feedStarted,
            feedPosition=typeof(offer)=="Vector3" and point(offer) or nil,
            staminaFraction=reserve,hudBurst=hudBurst,hudTrot=hudTrot,hudSprint=attr(player,"HudSprint"),
            hudBurstNo=burstNo==true or finite(burstNo) and now>=burstNo and now-burstNo<1.7,
            runIntent=attr(c,"WolfRunIntent"),allowBurst=reserve==nil or reserve>=.56,
            allowWater=profile.swim==true or swimming,swimSprint=profile.swimSprint==true,
            amber=amber,now=now,serverNow=at,unixNow=os.time(),players=others,contested=contested,currentHex=self:hexAt(point(r.Position)),
            claimTime=self.cfg and finite(self.cfg.CLAIM_TIME) and self.cfg.CLAIM_TIME or 20,
            avoidRadius=35,claimRadius=self.cfg and finite(self.cfg.CLAIM_RADIUS) and math.clamp(self.cfg.CLAIM_RADIUS,8,180) or 15,careTarget=hm*.90,
            drinkTarget=tm,
            refillTime=self.cfg and self.cfg.REFILL_TIME,
            attackCooldown=attackCooldown,gaitSpeeds=profile.gaits or profile.native and profile.native.gait,
            regionGrid=self.cfg and self.cfg.REGIONS and self.cfg.REGIONS.GRID,
            regionBonus=self.cfg and self.cfg.REGIONS and self.cfg.REGIONS.PAY_MULT,
            gameMenu=attr(player,"FeralMenuOpen")==true,menuOpen=UserInput:GetFocusedTextBox()~=nil,
            manualInput=self:manualInput(),combat=combat,combatKnown=combatKnown,
            pinned=attr(c,"FeralPinned")==true or attr(c,"FeralDragged")==true or attr(c,"FeralCarried")==true,
            ability=attr(c,"FeralCrushAt")~=nil and attr(c,"FeralCrushAt")~=false or attr(c,"FeralRolling")==true or attr(c,"FeralDowned")==true or attr(c,"FeralVenomDown")==true
                or attr(c,"FeralTalonLock")~=nil and attr(c,"FeralTalonLock")~=false
                or attr(c,"FeralDeathRollLocal")==true or attr(c,"FeralDiveBomb")==true
                or grabBusy,
            rescuing=hub and hub.rescue and hub.rescue.pending~=nil,
            resting=attr(c,"WolfRest")==true,
            automaticRest=hub and hub.recovery and hub.recovery.owned==c and not (hub.policy and hub.policy.manualRest),
            flying=fly,swimming=swimming,
            climbing=attr(c,"FeralClimbLocal")==true,underwater=attr(c,"FeralUnderwater")==true}
    end
    local function currentAction(state)
        return not b.closed and type(state)=="table" and state.alive~=false
            and (not state.char or state.char==player.Character)
            and (not state.generation or state.generation==b.generation)
            and not state.manualInput and not state.menuOpen and not state.gameMenu
    end
    function b:move(destination,state,options)
        if not destination or not currentAction(state) then return "WAIT" end
        options=options or {}
        local s=table.clone(state)
        for key,value in pairs(options) do s[key]=value end
        local target=Vector3.new(destination.x,state.root.Position.Y,destination.z)
        local result=self.nav:tick(target,state.char,state.hum,state.root,state.now,{},s)
        self.motionReason=self.nav.lastReason
        return result
    end
    function b:stop(reason)
        self.motionReason=reason
        local _,h,r=validAnimal()
        self.nav:stop(h,r,reason)
    end
    function b:releaseInputs()
        self.inputEpoch+=1
        for name,release in pairs(self.pendingInputs or {}) do pcall(release);self.pendingInputs[name]=nil end
    end
    local function pulse(name,begin,finish)
        b.pendingInputs=b.pendingInputs or {}
        if b.pendingInputs[name] then return false end
        local ok=pcall(begin)
        if not ok then pcall(finish);return false end
        b.pendingInputs[name]=finish
        local epoch=b.inputEpoch
        task.delay(.07,function()
            if b.inputEpoch==epoch and b.pendingInputs[name]==finish then
                pcall(finish);b.pendingInputs[name]=nil
            end
        end)
        return true
    end
    function b:feed(state,kind)
        if not currentAction(state) then return false end
        if state.feedCan~=kind or state.nativeFeedMode or state.feedMode==kind or state.feedMode==true
            or state.menuOpen or state.manualInput then return false end
        local hub=self:hub()
        if hub and type(hub.bridge.toggleNativeFeed)=="function" and state.nativeFeedKnown then
            local ok,sent=pcall(hub.bridge.toggleNativeFeed,hub.bridge,state.now)
            self.lastInput=ok and sent and "Native toggleFeed requested" or "Native toggleFeed unavailable"
            return ok and sent==true
        end
        local ok,v=pcall(function()return game:GetService("VirtualInputManager")end)
        self.synthetic.E=state.now
        if ok and v then
            local sent=pulse("E",function()v:SendKeyEvent(true,Enum.KeyCode.E,false,game)end,
                function()v:SendKeyEvent(false,Enum.KeyCode.E,false,game)end)
            if sent then self.lastInput="Virtual E input requested";return true end
        end
        if type(keypress)=="function" and type(keyrelease)=="function" then
            local sent=pulse("E",function()keypress(0x45)end,function()keyrelease(0x45)end)
            self.lastInput=sent and "Executor E input requested" or "Feeding input rejected"
            return sent
        end
        return false
    end
    function b:cancelFeed(state)
        if not state or state.char and state.char~=player.Character or state.generation and state.generation~=self.generation then return false end
        local hub=self:hub()
        if hub and type(hub.bridge.stopNativeFeed)=="function" then
            local ok,sent=pcall(hub.bridge.stopNativeFeed,hub.bridge,state.now)
            return ok and sent==true
        end
        return false
    end
    function b:food(state,preferred)
        -- Keep a real edible food target instead of chasing a new nearest item
        -- on every tick. Revalidate consumption, diet, ownership and position.
        local item=preferred and preferred.model
        local profile=state.profile or self:profile(state.char,state.species)
        local forage=config("Forage")
        if item and item.Parent and item:IsDescendantOf(Workspace) and forage and type(forage.canEat)=="function" then
            local ok,edible=pcall(forage.canEat,profile.diet,attr(item,"Diet"))
            local left,owner=attr(item,"FoodLeft"),attr(item,"TutorialOwner")
            if ok and edible and attr(item,"Consumed")~=true and (not finite(left) or left>.01)
                and (owner==nil or owner==player.UserId) and (self.foodBlocked[item] or 0)<=state.now then
                local pos=attr(item,"FoodPos")
                if typeof(pos)~="Vector3" and item:IsA("BasePart") then pos=item.Position end
                if typeof(pos)~="Vector3" and item:IsA("Model") then
                    local good,cf=pcall(item.GetBoundingBox,item);if good then pos=cf.Position end
                end
                if typeof(pos)=="Vector3" and safePosition(point(pos),state) then
                    return {model=item,position=point(pos)}
                end
            end
        end
        local finder=config("FeedFinder")
        if finder and type(finder.food)=="function" then
            local ok,item,pos=measured("FeedFinder.food",finder.food,state.char,state.root)
            if ok and item and typeof(pos)=="Vector3" and safePosition(point(pos),state)
                and (self.foodBlocked[item] or 0)<=state.now then
                return {position=point(pos),model=item}
            end
        end
        if not profile.diet or not forage or type(forage.canEat)~="function" then return nil end
        if forage.PLANT_DIETS and forage.PLANT_DIETS[profile.diet] and type(forage.nearest)=="function" then
            local ok,entry,pos=measured("Forage.nearest",forage.nearest,state.root.Position,300)
            if ok and entry and typeof(pos)=="Vector3" and safePosition(point(pos),state) then
                local item
                if type(forage.handle)=="function" then
                    local valid,result=pcall(forage.handle,entry)
                    if valid then item=result end
                end
                if item and (self.foodBlocked[item] or 0)<=state.now then return {model=item,position=point(pos)} end
            end
        end
        local ok,collection=pcall(function()return game:GetService("CollectionService")end)
        if not ok or not collection then return nil end
        local best,score=nil,math.huge
        if not self.foodIndex or state.now>=(self.foodIndex.at or 0)+2 then
            self.foodIndex={items=collection:GetTagged("FeralFood"),cursor=1,at=state.now}
        end
        local index=self.foodIndex
        for _=1,math.min(24,#index.items) do
            if index.cursor>#index.items then index.cursor=1 end
            local item=index.items[index.cursor];index.cursor+=1;self.operations.food+=1
            local left=attr(item,"FoodLeft")
            local owner=attr(item,"TutorialOwner")
            local valid,edible=pcall(forage.canEat,profile.diet,attr(item,"Diet"))
            if item.Parent and item:IsDescendantOf(Workspace) and attr(item,"Consumed")~=true and valid and edible
                and (not finite(left) or left>.01) and (owner==nil or owner==player.UserId)
                and (self.foodBlocked[item] or 0)<=state.now then
                local pos=attr(item,"FoodPos")
                if typeof(pos)~="Vector3" then
                    if item:IsA("Model") then
                        local good,cf=pcall(item.GetBoundingBox,item)
                        if good then pos=cf.Position end
                    elseif item:IsA("BasePart") then pos=item.Position end
                end
                if typeof(pos)=="Vector3" then
                    local p=point(pos);local d=dist(p,state.position)
                    if d<400 and d<score and safePosition(p,state) then best,score={position=p,model=item},d end
                end
            end
        end
        return best
    end
    function b:resourceSearch(state,kind)
        self.searchVisits=self.searchVisits or {}
        local active=self.searchPoint
        if active and self.searchKind==kind then
            local remaining=dist(active,state.position)
            if not self.searchBest or remaining<self.searchBest-1 then
                self.searchBest=remaining;self.searchProgressAt=state.now
            end
            if state.now<(self.searchUntil or 0) and state.now-(self.searchProgressAt or state.now)<15
                and remaining>12 then return active end
        end
        if active then self.searchVisits[active.key or "last"]=state.now end
        local best,score=nil,math.huge
        local candidates={}
        for _,hex in ipairs(self.hexes) do
            local p=hex.spot or hex.center
            table.insert(candidates,{x=p.x,z=p.z,key=hex.key})
        end
        -- Explore a stable world grid as well as hex centres. A resource can
        -- lie between them; short visit cooldowns previously retraced centres.
        local cx,cz=math.floor(state.position.x/120),math.floor(state.position.z/120)
        for dx=-3,3 do for dz=-3,3 do
            if dx~=0 or dz~=0 then
                local x,z=(cx+dx)*120,(cz+dz)*120
                table.insert(candidates,{x=x,z=z,key=kind..":"..(cx+dx)..":"..(cz+dz)})
            end
        end end
        for _,p in ipairs(candidates) do
            local d=dist(p,state.position);local visited=self.searchVisits[p.key]
            local occupied=self:hexAt(p)
            if d>45 and d<650 and not (state.contested and state.contested[occupied]) then
                local rank=d+(p.key:find(":",1,true) and 250 or 0)+(visited and math.max(0,240-state.now+visited)*3 or 0)
                if rank<score then best,score=p,rank end
            end
        end
        local count=0
        for key,at in pairs(self.searchVisits) do count+=1;if state.now-at>600 then self.searchVisits[key]=nil end end
        if count>256 then self.searchVisits={} end
        self.searchPoint,self.searchUntil=best,state.now+120
        self.searchKind=kind;self.searchBest=best and dist(best,state.position);self.searchProgressAt=state.now
        return best
    end
    function b:patrol(state)
        self.patrolVisits=self.patrolVisits or {}
        local target=self.patrolTarget
        if target and dist(target,state.position)>14 and state.now<(self.patrolUntil or 0) then return target end
        if target then self.patrolVisits[target.key]=state.now end
        local best,score=nil,math.huge
        for _,h in ipairs(self.hexes) do
            local t=self:territory(h.key)
            local d=dist(state.position,h.spot or h.center)
            if t and not t.neutral and t.owner==state.pack and d>40 and not (state.contested and state.contested[h.key]) then
                local recent=self.patrolVisits[h.key]
                local rank=d+(recent and math.max(0,60-state.now+recent)*12 or 0)
                if rank<score then best,score={x=(h.spot or h.center).x,z=(h.spot or h.center).z,key=h.key},rank end
            end
        end
        self.patrolTarget,self.patrolUntil=best,state.now+12
        return best
    end
    function b:checkPrey(prey,state)
        local profile=state.profile or self:profile(state.char,state.species)
        if not prey or not prey.model or not prey.model.Parent or not profile.hunts then return nil end
        if Players:GetPlayerFromCharacter(prey.model) then return nil end
        local hub=self:hub()
        if hub and type(hub.bridge.combatEligible)=="function" then
            local ok,eligible=pcall(hub.bridge.combatEligible,hub.bridge,prey.model)
            if not ok or not eligible then return nil end
        end
        local pack=attr(prey.model,"FeralPack")
        if packKey(state.pack)~=nil and packKey(state.pack)==packKey(pack) then return nil end
        local root=prey.model:FindFirstChild("HumanoidRootPart")
        local hum=prey.model:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health<=0 or attr(prey.model,"FeralDead")==true
            or hum.MaxHealth>state.hum.MaxHealth*1.25 or (self.preyBlocked[prey.model] or 0)>state.now then return nil end
        local position=point(root.Position)
        if not safePosition(position,state,32) then return nil end
        local velocity=root.AssemblyLinearVelocity
        prey.position=position;prey.root=root;prey.hum=hum
        prey.velocity=velocity and point(velocity) or {x=0,z=0}
        local look=root.CFrame and root.CFrame.LookVector
        prey.forward=look and {x=look.X,z=look.Z} or nil
        prey.health=hum.Health;prey.maxHealth=hum.MaxHealth
        prey.attackRange=math.clamp((state.root.Size.Z+root.Size.Z)*.35,4,12)
        return prey
    end
    function b:prey(state)
        local folder=Workspace:FindFirstChild("FeralNPCs")
        if not folder then return nil end
        local best,score=nil,math.huge
        if not self.preyIndex or self.preyIndex.folder~=folder or state.now>=self.preyIndex.at+2 then
            self.preyIndex={folder=folder,items=folder:GetChildren(),cursor=1,at=state.now}
        end
        local index=self.preyIndex
        for _=1,math.min(24,#index.items) do
            if index.cursor>#index.items then index.cursor=1 end
            local npc=index.items[index.cursor];index.cursor+=1;self.operations.prey+=1
            if npc:IsA("Model") then
                local p=self:checkPrey({model=npc},state)
                if p then
                    local d=dist(p.position,state.position)
                    local speed=math.sqrt(p.velocity.x^2+p.velocity.z^2)
                    local travel=state.travelCost and state.travelCost(state.position,p.position) or d/math.max(10,state.travelSpeed or 24)
                    local damage=self.observedDamage
                    local service=damage and p.health/math.max(1,damage)*(state.attackCooldown or 1) or p.health*.08+8
                    local closing=math.max(1,(state.travelSpeed or 24)-speed)
                    local chase=math.min(90,d/closing)
                    local rank=travel+service+chase*.5
                    p.mealETA=rank+12;self.foodETA=p.mealETA;p.costConfidence=damage and "observed HP trend; attribution unknown" or "heuristic without damage observations"
                    if speed>(state.travelSpeed or 24)*1.15 and d>60 then rank+=100 end
                    if d<330 and rank<score then best,score=p,rank end
                end
            end
        end
        return best
    end
    function b:careObserved(goal,state)
        if goal.manualInterventionObserved or goal.timing and goal.timing.unknown>1 then return end
        local seconds=goal.timing and goal.timing.active or state.now-goal.start
        if not finite(seconds) or seconds<=0 then return end
        local key=goal.kind=="DRINK" and "drinkObserved" or "foodObserved"
        self[key]=self[key] and self[key]*.6+seconds*.4 or seconds
    end
    function b:huntOutcome(amount)
        if finite(amount) and amount>0 then self.observedDamage=self.observedDamage and self.observedDamage*.7+amount*.3 or amount end
    end
    function b:mealChoice(state,food,committed)
        if not food then return nil end
        if committed and committed.target then
            if dist(food.position,state.position)<24 then return food end
            return nil
        end
        local foodETA=(state.travelCost and state.travelCost(state.position,food.position) or dist(food.position,state.position)/24)+12
        self.foodETA=foodETA
        if foodETA>24 and state.profile and state.profile.hunts then
            local prey=self:prey(state)
            if prey and prey.mealETA and prey.mealETA*1.25<foodETA then return nil end
        end
        return food
    end
    function b:attackGeometry(state,prey)
        local hub=self:hub()
        local cfg=hub and hub.features and hub.features.originalCombat or config("CombatConfig")
        if not cfg or not state.root or not state.hum or not prey or not prey.root or not prey.hum then return nil end
        local diff=prey.root.Position-state.root.Position
        local planar=Vector3.new(diff.X,0,diff.Z)
        local function mult(name,default)
            if type(cfg[name])~="function" then return default end
            local ok,value=pcall(cfg[name],state.char)
            return ok and finite(value) and value or default
        end
        local geometry
        if hub and type(hub.bridge.geometry)=="function" then
            local ok,value=pcall(hub.bridge.geometry,hub.bridge,cfg,state,{char=prey.model,root=prey.root,hum=prey.hum})
            if not ok or not value then return nil end
            geometry=value
        else
            -- Standalone compatibility uses the same captured stock formula.
            if type(cfg.bodyGap)~="function" or not finite(cfg.REACH) or not finite(cfg.SLACK)
                or not finite(cfg.HIT_SCALE) or not finite(cfg.MAX_DY) or not finite(cfg.CONE) then return nil end
            local look=state.root.CFrame.LookVector;look=Vector3.new(look.X,0,look.Z)
            if look.Magnitude<.01 then return nil end
            if type(cfg.biteLook)=="function" then
                local ok,value=pcall(cfg.biteLook,state.char,look.Unit)
                if ok and typeof(value)=="Vector3" then look=Vector3.new(value.X,0,value.Z) end
            end
            if look.Magnitude<.01 then return nil end
            local ok,gap=pcall(cfg.bodyGap,prey.root,planar)
            if not ok or not finite(gap) then return nil end
            local box=attr(state.root,"FeralBoxFull")
            if not finite(box) or box<=0 then box=state.root.Size.Z end
            geometry={gap=gap,reach=(box*.5+state.hum.HipHeight*cfg.REACH+cfg.SLACK)*cfg.HIT_SCALE*mult("reachMult",1),
                angle=planar.Magnitude>.01 and look.Unit:Dot(planar.Unit) or 1}
        end
        local reach,gap,angle=geometry.reach,geometry.gap,geometry.angle
        local vertical=geometry.vertical or (state.hum.HipHeight+prey.hum.HipHeight)*cfg.MAX_DY*mult("dyMult",1)
        local cone=geometry.cone or mult("coneFor",cfg.CONE)
        if not finite(reach) or reach<=0 or not finite(gap) or not finite(angle) or not finite(vertical) or vertical<=0 or not finite(cone) then return nil end
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={state.char};params.IgnoreWater=true
        params.RespectCanCollide=true
        local queried,obstruction=pcall(Workspace.Raycast,Workspace,state.root.Position,diff,params)
        local clear=queried and (not obstruction or obstruction.Instance and obstruction.Instance:IsDescendantOf(prey.model)) or false
        local inRange=gap<reach*.92 and math.abs(diff.Y)<vertical*.95
        local facing=angle>math.cos(math.rad(cone))
        return {valid=inRange and facing and clear,inRange=inRange,facing=facing,
            angle=angle,gap=gap,reach=reach,clear=clear,height=math.abs(diff.Y),heightLimit=vertical*.95,
            reason=not inRange and "Outside native bite geometry" or not facing and "Facing away from prey"
                or not clear and "Bite corridor obstructed or unavailable" or "Native attack geometry ready"}
    end
    function b:attackEvidence(state)
        if not self.lastAttackInput then return nil end
        local record=table.clone(self.lastAttackInput)
        record.age=state.now-record.at
        record.sameCharacter=self.attackCharacter==state.char
        local marker=record.sameCharacter and attr(state.char,"WolfBiteAt") or nil
        record.markerNow=finite(marker) and marker or nil
        record.markerAdvanced=record.sameCharacter and finite(marker)
            and (not finite(record.markerBefore) or marker>record.markerBefore+.000001) or false
        return record
    end
    function b:bite(state,prey)
        if not currentAction(state) then return false,"Stale animal or manual input owns action" end
        local p=self:checkPrey(prey,state)
        if not p then return false,"Prey unavailable" end
        local geometry=self:attackGeometry(state,p)
        if not geometry or not geometry.valid then return false,"Native range, facing or line of sight not ready" end
        self.attackCharacter=state.char;self.synthetic.M1=state.now
        self.lastAttackInput={at=state.now,markerBefore=attr(state.char,"WolfBiteAt"),sent=false,backend="NONE"}
        local hub=self:hub()
        if hub and type(hub.bridge.tryNativeBite)=="function" then
            if hub.recovery then hub.recovery:release("Amber hunt",state.now) end
            -- Readiness guidance is advisory. Cached/private timing must not
            -- suppress the original handler: that handler already owns the
            -- native cooldown, Rest and capture guards. Dispatch is still only
            -- an attempt; the hunter observes actual HP separately.
            if hub.policy then hub.policy:input("attack",state.now) end
            local priorReach,priorTree=hub.bridge.reachTarget,hub.bridge.treeTarget
            hub.bridge.reachTarget,hub.bridge.treeTarget=nil,nil
            local ok,sent=pcall(hub.bridge.tryNativeBite,hub.bridge,state.now)
            if hub.bridge.reachTarget==nil then hub.bridge.reachTarget=priorReach end
            if hub.bridge.treeTarget==nil then hub.bridge.treeTarget=priorTree end
            if ok and sent then
                self.lastAttackInput.sent=true;self.lastAttackInput.backend="NATIVE_CALLBACK"
                self.lastInput="Native tryBite requested";return true,self.lastInput
            end
        end
        local species=config("Species")
        local delay=1.35
        if species and type(species.biteCooldown)=="function" then
            local ok,value=pcall(species.biteCooldown,state.species,attr(state.char,"Growth") or 1)
            if ok and finite(value) then delay=math.clamp(value,.15,10) end
        end
        if state.now<(self.nextBite or 0) then return false,"Native bite cooldown" end
        self.nextBite=state.now+delay
        local original=UserInput:GetMouseLocation()
        local m=original
        local camera=Workspace.CurrentCamera
        local gui=player:FindFirstChildOfClass("PlayerGui")
        local function clearAt(x,y)
            if not gui or type(gui.GetGuiObjectsAtPosition)~="function" then return true end
            local checked,objects=pcall(gui.GetGuiObjectsAtPosition,gui,x,y)
            if not checked then return false end
            for _,object in ipairs(objects) do
                if object.Active or object:IsA("GuiButton") or object:IsA("TextBox") then return false end
            end
            return true
        end
        if not clearAt(m.X,m.Y) then
            local found=false
            if camera and camera.ViewportSize then
                for _,uv in ipairs({{.08,.45},{.92,.45},{.5,.5},{.5,.82}}) do
                    local x,y=camera.ViewportSize.X*uv[1],camera.ViewportSize.Y*uv[2]
                    if clearAt(x,y) then m={X=x,Y=y};found=true;break end
                end
            end
            if not found then self.lastInput="Attack input blocked by interface";return false,self.lastInput end
        end
        local ok,v=pcall(function()return game:GetService("VirtualInputManager")end)
        if ok and v then
            -- The owned WolfController callback above avoids UI hit testing.
            -- Fallback mouse input is reported as a request, never as damage.
            local sent=pulse("M1",function()v:SendMouseButtonEvent(m.X,m.Y,0,true,game,0)end,
                function()v:SendMouseButtonEvent(m.X,m.Y,0,false,game,0)end)
            if sent then
                self.lastAttackInput.sent=true;self.lastAttackInput.backend="VIRTUAL_MOUSE"
                self.lastInput="Virtual mouse attack requested";return true,self.lastInput
            end
            self.lastAttackInput.virtualError="VIRTUAL_MOUSE_REJECTED"
        end
        local moved=false
        local function positionCursor()
            if math.abs(m.X-original.X)+math.abs(m.Y-original.Y)>.5 then
                assert(type(mousemoveabs)=="function","Executor cursor positioning unavailable")
                mousemoveabs(m.X,m.Y);moved=true
            end
        end
        local function restoreCursor()
            if moved and type(mousemoveabs)=="function" then mousemoveabs(original.X,original.Y);moved=false end
        end
        local sent=false
        if type(mouse1press)=="function" and type(mouse1release)=="function" then
            sent=pulse("M1",function()positionCursor();mouse1press()end,function()
                pcall(mouse1release);restoreCursor()
            end)
        elseif type(mouse1click)=="function" then
            sent=pulse("M1",function()positionCursor();mouse1click()end,restoreCursor)
        end
        self.lastAttackInput.sent=sent;self.lastAttackInput.backend=sent and "EXECUTOR_MOUSE" or "UNAVAILABLE"
        self.lastInput=sent and "Executor mouse attack requested" or "Attack input unavailable or rejected"
        return sent,self.lastInput
    end
    local function inputName(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then return "M1" end
        return tostring(input.KeyCode or ""):match("%.([^%.]+)$") or tostring(input.KeyCode or "")
    end
    if UserInput.InputBegan then
        table.insert(b.connections,UserInput.InputBegan:Connect(function(input)
            local name=inputName(input)
            local mapped=name=="LeftShift" and "SHIFT" or name
            local relevant={W=true,A=true,S=true,D=true,Space=true,X=true,Z=true,E=true,R=true,Q=true,M1=true}
            local gamepad=name:sub(1,6)=="Button" or name:sub(1,4)=="DPad"
            if relevant[name] or mapped=="SHIFT" or gamepad then
                local now=os.clock();local at=b.nav.synthetic and b.nav.synthetic[mapped] or b.synthetic[mapped]
                if not (at and now>=at and now-at<.25) and not (b.pendingInputs and b.pendingInputs[mapped]) then
                    b.manualUntil=now+.6
                    if gamepad then b.manualButtons[name]=true end
                    if name=="X" then nav.gaits.burstOwned=false end
                    if name=="Z" then nav.gaits.trotOwned=false end
                end
            end
        end))
    end
    if UserInput.InputEnded then
        table.insert(b.connections,UserInput.InputEnded:Connect(function(input)b.manualButtons[inputName(input)]=nil end))
    end
    if UserInput.InputChanged then
        table.insert(b.connections,UserInput.InputChanged:Connect(function(input)
            if inputName(input)=="Thumbstick1" then
                local pos=input.Position
                b.manualStick=pos and type(pos.Magnitude)=="number" and pos.Magnitude>.15 or false
                if b.manualStick then b.manualUntil=os.clock()+.6 end
            end
        end))
    end
    if UserInput.GamepadDisconnected then
        table.insert(b.connections,UserInput.GamepadDisconnected:Connect(function()
            b.manualButtons={};b.manualStick=false;b.manualUntil=os.clock()+.6
        end))
    end
    function b:close()
        if self.closed then return end
        self.closed=true;self.manualButtons={};self.manualStick=false
        self:recover(nil,false);self:releaseInputs();self:stop("unloaded")
        for _,c in ipairs(self.connections) do c:Disconnect() end
        self.connections={}
    end
    return b
end
return Bridge
