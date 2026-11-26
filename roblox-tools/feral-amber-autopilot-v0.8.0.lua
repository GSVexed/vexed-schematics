-- FERAL Amber Autopilot 0.8.0 | 2026-11-26 | native profiles | gameplay outcomes observed separately
local sources = {}
sources["ledger"] = [============[
-- Bounded run accounting. Requests, world observations and attribution differ.
local Ledger={}
local function finite(n)return type(n)=="number" and n==n and math.abs(n)<1e12 end
function Ledger.new()
    local l={serial=0}
    function l:start(now)
        self.serial+=1;self.run=self.serial;self.started=now;self.at=now
        self.wall,self.active,self.paused,self.unknown=0,0,0,0
        self.phases,self.failures,self.outcomes,self.costs={},{},{},{}
        self.inflow,self.outflow,self.net=0,0,0;self.balance=nil;self.character=nil
        self.assistance=0;self.wasManual=false;self.previous=nil;self.gaits={};self.modes={}
    end
    function l:sample(now,phase,paused,manual,goal,state,nav)
        if not self.run then self:start(now) end
        local dt=math.max(0,now-(self.at or now));self.at=now;self.wall+=dt
        local known=math.min(dt,2);local gap=dt-known;self.unknown+=gap
        local p=self.previous and {phase=phase or "WAIT",paused=paused==true,goal=goal}
        if p then
            if p.paused then self.paused+=known else self.active+=known end
            self.phases[p.phase]=(self.phases[p.phase] or 0)+known
            if not p.paused then
                local mode=(not state or not state.alive) and "unavailable" or state.underwater and "depth"
                    or state.flying and "flight" or state.climbing and "climb" or state.swimming and "surface_water" or "ground"
                self.modes[mode]=(self.modes[mode] or 0)+known
                local observed=nav and nav.gaits and nav.gaits.observed
                if observed~="WALK" and observed~="TROT" and observed~="SPRINT" and observed~="BURST" then observed="UNKNOWN" end
                self.gaits[observed]=(self.gaits[observed] or 0)+known
            end
            local g=p.goal
            if g then
                g.timing=g.timing or {active=0,paused=0,unknown=0,phases={}}
                local t=g.timing;t.unknown+=gap
                if p.paused then t.paused+=known else t.active+=known end
                t.phases[p.phase]=(t.phases[p.phase] or 0)+known
            end
        else self.unknown+=known end
        if manual and not self.wasManual then self.assistance+=1 end
        self.wasManual=manual==true
        self.previous={phase=phase or "WAIT",paused=paused==true,goal=goal}
    end
    function l:currency(value,character)
        if not finite(value) then self.balance=nil;return end
        if self.character~=character then self.balance=nil;self.character=character end
        if self.balance then
            local delta=value-self.balance;self.net+=delta
            if delta>0 then self.inflow+=delta else self.outflow-=delta end
        end
        self.balance=value
    end
    function l:count(kind,reason)
        local t=kind=="failure" and self.failures or self.outcomes
        local key=tostring(reason or kind):sub(1,100)
        if not t[key] then
            local n=0;for _ in pairs(t) do n+=1 end
            if n>=48 then key="other" end
        end
        t[key]=(t[key] or 0)+1
    end
    function l:cost(name,seconds)
        local c=self.costs[name] or {calls=0,total=0,max=0,samples={}}
        self.costs[name]=c;c.calls+=1;c.total+=seconds;c.max=math.max(c.max,seconds)
        table.insert(c.samples,seconds);if #c.samples>128 then table.remove(c.samples,1) end
    end
    function l:summary()
        local costs={}
        for k,c in pairs(self.costs or {}) do
            local s=table.clone(c.samples);table.sort(s)
            costs[k]={calls=c.calls,total=c.total,max=c.max,p95=s[math.max(1,math.ceil(#s*.95))],p99=s[math.max(1,math.ceil(#s*.99))]}
        end
        return {run=self.run,wall=self.wall,active=self.active,paused=self.paused,unobserved=self.unknown,
            phases=self.phases,observedGaitSeconds=self.gaits,modeSeconds=self.modes,
            manualInterventions=self.assistance,failures=self.failures,outcomes=self.outcomes,costs=costs,
            amber={inflow=self.inflow,outflow=self.outflow,net=self.net,
                inflowPerWallHour=self.wall and self.wall>0 and self.inflow*3600/self.wall or nil,
                netPerWallHour=self.wall and self.wall>0 and self.net*3600/self.wall or nil,attribution="unattributed observed balance changes"}}
    end
    return l
end
return Ledger
]============]
sources["model"] = [============[
-- Small, generation-scoped travel observations and checked passage graph.
local Model={}
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)end
local function key(p)return math.floor(p.x/48)..":"..math.floor(p.z/48)end
local function copy(p)return {x=p.x,y=p.y,z=p.z}end
function Model.new()
    local m={identity=nil,edges={},nodes={},order={},costs={},observations=0,failures=0}
    function m:reset(identity)
        if identity==self.identity then return end
        self.identity=identity;self.edges={};self.nodes={};self.order={};self.costs={}
    end
    function m:estimate(a,b,now,speed,purpose)
        local direct=distance(a,b)/math.max(6,speed or 24)
        local c=self.costs[key(a)..">"..key(b)..":"..tostring(purpose or "point")]
        if c and now-c.at<600 then
            return (c.access and c.seconds or math.max(direct,c.seconds)),c.samples>=2 and "observed" or "single observation"
        end
        return direct,"distance estimate"
    end
    function m:record(a,b,seconds,now,failed,purpose,access)
        if distance(a,b)<12 then return end
        local k=key(a)..">"..key(b)..":"..tostring(purpose or "point");local c=self.costs[k]
        local value=failed and math.max(seconds,45,distance(a,b)/10) or seconds
        if c then c.seconds=c.seconds*.4+value*.6;c.at=now;c.samples+=1;c.access=access==true
        else
            local count=0;local oldest,at=nil,math.huge
            for id,v in pairs(self.costs) do count+=1;if v.at<at then oldest,at=id,v.at end end
            if count>=192 then self.costs[oldest]=nil end
            self.costs[k]={seconds=value,at=now,samples=1,access=access==true}
        end
        if failed then self.failures+=1 else self.observations+=1 end
    end
    function m:addRoute(points,now)
        local previous
        for _,p in ipairs(points) do
            local k=key(p)
            if not self.nodes[k] then
                if #self.order>=160 then
                    local old=table.remove(self.order,1);self.nodes[old]=nil;self.edges[old]=nil
                    for _,e in pairs(self.edges) do e[old]=nil end
                end
                table.insert(self.order,k)
            end
            self.nodes[k]={point=copy(p),at=now};self.edges[k]=self.edges[k] or {}
            if previous and previous~=k and self.nodes[previous] and self.edges[previous] then
                self.edges[previous][k]={cost=distance(self.nodes[previous].point,p),at=now}
            end
            previous=k
        end
    end
    function m:path(a,b,now)
        local costs,parents,open={},{},{}
        for k,n in pairs(self.nodes) do
            local d=distance(a,n.point)
            if d<80 and now-n.at<180 then costs[k]=d;open[k]=true end
        end
        for _=1,160 do
            local current,best=nil,math.huge
            for k in pairs(open) do if costs[k]<best then current,best=k,costs[k] end end
            if not current then break end
            open[current]=nil
            local n=self.nodes[current]
            if n and distance(n.point,b)<90 then
                local result={copy(b)};local k=current;local seen={}
                while k and not seen[k] do
                    seen[k]=true;table.insert(result,1,copy(self.nodes[k].point));k=parents[k]
                end
                return result
            end
            for k,e in pairs(self.edges[current] or {}) do
                if self.nodes[k] and now-e.at<180 and (not costs[k] or best+e.cost<costs[k]) then
                    costs[k]=best+e.cost;parents[k]=current;open[k]=true
                end
            end
        end
        return nil
    end
    function m:summary()return {passages=#self.order,travelObservations=self.observations,routeFailures=self.failures}end
    return m
end
return Model
]============]
sources["planner"] = [============[
-- Grizzly Amber v1: pure objective planner. Never writes territory/game state.
-- Hex geometry, pay, owner, hold and progress are replicated native observations.
local Planner = {}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e10 end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function dist(a,b)
    if not a or not b or not finite(a.x) or not finite(a.z) or not finite(b.x) or not finite(b.z) then
        return math.huge
    end
    local dx,dz=a.x-b.x,a.z-b.z
    return math.sqrt(dx*dx+dz*dz)
end
local function pathRisk(a,b,players,avoidRadius)
    for _,p in ipairs(players or {}) do
        if finite(p.x) and finite(p.z) then
            local vx,vz=b.x-a.x,b.z-a.z
            local denom=vx*vx+vz*vz
            local t=denom>.01 and clamp(((p.x-a.x)*vx+(p.z-a.z)*vz)/denom,0,1) or 0
            local qx,qz=a.x+vx*t,a.z+vz*t
            local offset=math.sqrt((qx-p.x)^2+(qz-p.z)^2)
            if offset<avoidRadius then return true,offset end
        end
    end
    return false,math.huge
end
Planner.distance=dist
Planner.pathRisk=pathRisk

-- kind is CLAIM or SCENT. Existing claims have a minimum guard against churn.
function Planner.objective(hex,state,from,options)
    options=options or {}
    if not hex or type(hex.key)~="string" or hex.neutral or state.pack==nil
        or not hex.center or not finite(hex.center.x) or not finite(hex.center.z) then return nil end
    if (options.exclude and options.exclude[hex.key])
        or (options.blockedUntil and (options.blockedUntil[hex.key] or 0)>(state.now or 0)) then return nil end
    if state.contested and state.contested[hex.key] then return nil end
    local owned=hex.owner==state.pack
    if options.maintenanceOnly and not owned then return nil end
    if owned and options.retainOwned and not options.retainOwned[hex.key] then return nil end
    local hold=finite(hex.hold) and clamp(hex.hold,0,1) or nil
    local payKnown=finite(hex.pay)
    local pay=payKnown and clamp(hex.pay,1,20) or 1
    local kind,priority
    if owned then
        if hold==nil or hold>= (options.scentThreshold or .84) then return nil end
        kind="SCENT"
        priority=45+pay*8+(1-hold)*180
        if hold<.35 then priority+=125 end
        if finite(hex.fade) and finite(state.unixNow) then
            local seconds=hex.fade-state.unixNow
            if seconds<150 then priority+=math.max(0,150-seconds)*.32 end
        end
    else
        kind="CLAIM"
        priority=80+pay*23
        if hex.owner==nil then priority+=30 else priority-=15 end
        if hex.by==state.pack and finite(hex.prog) and hex.prog>0 then
            priority+=140+clamp(hex.prog,0,1)*100
        end
    end
    local d=dist(from,hex.center)
    if d==math.huge then return nil end
    local deny,nearest=pathRisk(from,hex.center,state.players,options.avoidRadius or 120)
    if deny and options.avoidPlayers==true then return nil end
    local recent=options.recent and options.recent[hex.key]
    local waiting=options.waitingSince and options.waitingSince[hex.key]
    if finite(waiting) then priority+=math.min(180,math.max(0,(state.now or 0)-waiting)/5) end
    if finite(recent) and (state.now or 0)-recent<120 then priority*=.65 end
    local travel,confidence=d/24,"distance estimate"
    local estimate=options.travelCost or state.travelCost
    if type(estimate)=="function" then
        local ok,t,c=pcall(estimate,from,hex.center,"HEX:"..hex.key)
        if ok and finite(t) and t>=0 then travel,confidence=t,c or "estimate" end
    end
    local service=kind=="SCENT" and (state.refillTime or 60)*(1-hold)
        or (state.claimTime or 20)*(1-(hex.by==state.pack and finite(hex.prog) and clamp(hex.prog,0,1) or 0))
    local deadline=finite(hex.deadlineSeconds) and math.max(0,hex.deadlineSeconds) or nil
    -- Fade is used only when its units plausibly match the supplied Unix clock.
    if not deadline and finite(hex.fade) and finite(state.unixNow) and math.abs(hex.fade-state.unixNow)<86400 then
        deadline=math.max(0,hex.fade-state.unixNow)
    end
    local slack=deadline and deadline-travel-service or nil
    if kind=="SCENT" and slack and slack<60 then priority+=math.max(0,60-slack)*6 end
    local routeCost=1+d/320
    local score=type(estimate)=="function" and priority/math.max(2,travel+service+2) or priority/(routeCost^.74)
    if not finite(score) then return nil end
    return {key=hex.key,kind=kind,score=score,base=priority,distance=d,
        pay=payKnown and pay or nil,hold=hold,center=hex.center,nearestPlayer=nearest,
        urgency=owned and (1-(hold or 0)) or 0,travelSeconds=travel,serviceSeconds=service,
        deadlineSeconds=deadline,slack=slack,confidence=confidence}
end

function Planner.plan(hexes,state,options)
    options=options or {}
    if type(hexes)~="table" or not state or not state.position then return {} end
    local route,from={},state.position
    local exclude={}
    for key,blocked in pairs(options.exclude or {}) do if blocked then exclude[key]=true end end
    local n=math.min(options.maxStops or 6,16)
    for step=1,n do
        local ranked={}
        local opt={}
        for k,v in pairs(options) do opt[k]=v end
        opt.exclude=exclude
        for _,hex in ipairs(hexes) do
            local item=Planner.objective(hex,state,from,opt)
            if item then table.insert(ranked,item) end
        end
        if #ranked==0 then break end
        table.sort(ranked,function(a,b) if a.score~=b.score then return a.score>b.score end return a.key<b.key end)
        -- One-stop lookahead rewards efficient clusters rather than global backtracking.
        local best=nil
        for j=1,math.min(7,#ranked) do
            local candidate=ranked[j]
            local forward=0
            if step<n then
                local lookOpt={}
                for k,v in pairs(opt) do lookOpt[k]=v end
                local skip={}
                for k,v in pairs(exclude) do skip[k]=v end
                skip[candidate.key]=true
                lookOpt.exclude=skip
                for _,hex in ipairs(hexes) do
                    local other=Planner.objective(hex,state,candidate.center,lookOpt)
                    if other and other.score>forward then forward=other.score end
                end
            end
            candidate.trajectory=candidate.score+forward*.16
            if not best or candidate.trajectory>best.trajectory
                or candidate.trajectory==best.trajectory and candidate.key<best.key then best=candidate end
        end
        table.insert(route,best)
        exclude[best.key]=true
        from=best.center
    end
    if options.currentKey and options.currentKey~="" and #route>0 and route[1].key~=options.currentKey then
        -- Preserve an active objective unless it is done, dangerous or strongly outclassed.
        local current
        for _,hex in ipairs(hexes) do
            if hex.key==options.currentKey then
                current=Planner.objective(hex,state,state.position,options);break
            end
        end
        if current and current.score>=route[1].score*.73 and
            (state.now or 0)-(options.currentStarted or 0)<(options.maxCommitSeconds or 75) then
            for i=#route,1,-1 do if route[i].key==current.key then table.remove(route,i) end end
            table.insert(route,1,current)
            while #route>n do table.remove(route) end
        end
    end
    return route
end

-- Native regionCell is a one-based row-major ID. Sweep alternating rows to
-- finish complete areas without crossing repeatedly between opposite corners.
function Planner.regionOrder(grid)
    local order={}
    for row=0,grid-1 do
        for step=0,grid-1 do
            local col=row%2==0 and step or grid-1-step
            table.insert(order,row*grid+col+1)
        end
    end
    return order
end
local function localTour(hexes,state,options)
    local remaining={}
    for _,hex in ipairs(hexes) do
        local item=Planner.objective(hex,state,state.position,options)
        if item then item.region=hex.region;item.hex=hex;table.insert(remaining,item) end
    end
    local route,from={},state.position
    local elapsed=0
    while #remaining>0 and #route<math.min(options.maxStops or 6,16) do
        local best,index,value=nil,nil,-math.huge
        for i,item in ipairs(remaining) do
            local refreshed=Planner.objective(item.hex,state,from,options)
            local t=refreshed.travelSeconds+refreshed.serviceSeconds+2
            local rank=refreshed.base/math.max(2,t)/(1+(refreshed.travelSeconds/5)^2)
            if refreshed.slack and refreshed.slack-elapsed<45 then
                rank+=1000/math.max(1,refreshed.slack-elapsed+20)
            end
            if rank>value or rank==value and item.key<(best and best.key or "~") then
                best,index,value=refreshed,i,rank
                best.region=item.region
            end
        end
        elapsed+=best.travelSeconds+best.serviceSeconds
        table.insert(route,best);table.remove(remaining,index);from=best.center
    end
    return route
end
function Planner.strategy(hexes,state,options)
    options=options or {}
    local grid=state.regionGrid
    if not finite(grid) or grid<1 or grid>8 or grid%1~=0 then
        return Planner.plan(hexes,state,options),{phase="GENERAL",cursor=options.regionCursor or 1}
    end
    local groups={};local urgent={};local anyRegion=false
    for _,hex in ipairs(hexes) do
        if hex.region and not hex.neutral then
            anyRegion=true
            groups[hex.region]=groups[hex.region] or {total=0,owned=0,hexes={}}
            local group=groups[hex.region];group.total+=1
            if hex.owner==state.pack then group.owned+=1 end
            table.insert(group.hexes,hex)
        end
        local item=Planner.objective(hex,state,state.position,options)
        if item and item.kind=="SCENT" and item.hold and (item.hold<.28 or item.slack and item.slack<45) then table.insert(urgent,hex) end
    end
    if not anyRegion then return Planner.plan(hexes,state,options),{phase="GENERAL",cursor=1} end
    local order=Planner.regionOrder(grid)
    if #urgent>0 then return localTour(urgent,state,options),{phase="URGENT_SCENT",cursor=options.regionCursor or 1} end
    local oldest,agedRegion=300,nil
    for region,group in pairs(groups) do
        for _,hex in ipairs(group.hexes) do
            local since=options.waitingSince and options.waitingSince[hex.key]
            if finite(since) and (state.now or 0)-since>oldest and Planner.objective(hex,state,state.position,options) then
                oldest,agedRegion=(state.now or 0)-since,region
            end
        end
    end
    if agedRegion then
        local index=table.find(order,agedRegion) or 1
        return localTour(groups[agedRegion].hexes,state,options),{phase="FAIRNESS_SWEEP",cursor=index,region=agedRegion,
            area="Revisiting waiting area",order=order}
    end
    local cursor=math.clamp(options.regionCursor or 1,1,#order)
    if not options.regionCursor then
        local closest=math.huge
        for index,region in ipairs(order) do
            local group=groups[region]
            if group then
                for _,hex in ipairs(group.hexes) do
                    local item=Planner.objective(hex,state,state.position,options)
                    if item and item.travelSeconds<closest then cursor,closest=index,item.travelSeconds end
                end
            end
        end
    end
    local direction=options.regionDirection or 1
    if not options.regionCursor then
        local best=math.huge
        for _,candidateDirection in ipairs({1,-1}) do
            for step=1,#order-1 do
                local index=(cursor+step*candidateDirection-1)%#order+1
                local group=groups[order[index]];local cost=math.huge
                for _,hex in ipairs(group and group.hexes or {}) do
                    local item=Planner.objective(hex,state,state.position,options)
                    if item then cost=math.min(cost,item.travelSeconds) end
                end
                if cost<math.huge then
                    if cost<best then direction,best=candidateDirection,cost end
                    break
                end
            end
        end
    end
    -- Claims first, then maintenance; blocked areas stay eligible for the next
    -- pass instead of being incorrectly counted as completed.
    for _,claimsOnly in ipairs({true,false}) do
        for step=0,#order-1 do
            local index=(cursor+step*direction-1)%#order+1
            local region=order[index];local group=groups[region]
            if group and (not claimsOnly or group.owned<group.total) then
                local pool={}
                for _,hex in ipairs(group.hexes) do
                    if not claimsOnly or hex.owner~=state.pack then table.insert(pool,hex) end
                end
                local route=localTour(pool,state,options)
                if #route>0 then
                    local row,col=math.floor((region-1)/grid),(region-1)%grid
                    local vertical=grid==3 and ({"Top","Middle","Bottom"})[row+1] or ("Row "..(row+1))
                    local horizontal=grid==3 and ({"left","centre","right"})[col+1] or ("column "..(col+1))
                    return route,{phase=claimsOnly and "AREA_SWEEP" or "AREA_MAINTENANCE",cursor=index,
                        region=region,direction=direction,area=vertical.." "..horizontal,owned=group.owned,total=group.total,
                        bonus=state.regionBonus,order=order}
                end
            end
        end
    end
    return {},{phase="MAINTAINED",cursor=cursor,direction=direction,order=order}
end

function Planner.decide(state,options)
    options=options or {}
    if not state or not finite(state.healthFraction) or state.healthFraction<0 or state.healthFraction>1.05 or state.needsKnown==false then
        return {kind="WAIT",reason="Waiting for valid native health and needs"}
    end
    if state.hungerMax~=nil and (not finite(state.hungerMax) or state.hungerMax<=0)
        or state.thirstMax~=nil and (not finite(state.thirstMax) or state.thirstMax<=0) then
        return {kind="WAIT",reason="Native resource maxima unavailable"}
    end
    local hm=finite(state.hungerMax) and state.hungerMax>0 and state.hungerMax or 100
    local tm=finite(state.thirstMax) and state.thirstMax>0 and state.thirstMax or 100
    local h=finite(state.hunger) and state.hunger/hm or nil
    local t=finite(state.thirst) and state.thirst/tm or nil
    if not h or not t or h<0 or t<0 then return {kind="WAIT",reason="Waiting for both native needs"} end
    -- A merely thirsty animal must not repeatedly defer a starving one. Use
    -- observed depletion margins when both exist, otherwise normalized needs.
    local critical
    if h<.19 and t<.19 then
        local hr=finite(state.hungerReserve) and state.hungerReserve or h
        local tr=finite(state.thirstReserve) and state.thirstReserve or t
        if not (finite(state.hungerReserve) and finite(state.thirstReserve)) then hr,tr=h,t end
        critical=hr<tr and "EAT" or "DRINK"
    elseif t<.19 then critical="DRINK" elseif h<.19 then critical="EAT" end
    if state.healthFraction<.25 then
        if critical and (state.feedCan==(critical=="DRINK" and "drink" or "eat") or state.recoveryStalled
            or critical=="DRINK" and t<.08 or critical=="EAT" and h<.08) then
            return {kind=critical,critical=true,reason="Immediate native care before critical recovery"}
        end
        return {kind="RECOVER",critical=true,reason="Critical health"}
    end
    if critical then return {kind=critical,critical=true,reason="Critical survival need"} end
    if state.healthFraction<(options.minimumHP or .46) then return {kind="RECOVER",reason="Low health"} end
    local drinkBudget=math.max(180,(state.drinkETA or 0)+45)
    local foodBudget=math.max(240,(state.foodETA or 0)+60)
    if t and t<.8 and finite(state.thirstReserve) and state.thirstReserve<drinkBudget then
        return {kind="DRINK",reason="Water reserve shorter than care margin"}
    end
    if h and h<.8 and finite(state.hungerReserve) and state.hungerReserve<foodBudget then
        return {kind="EAT",reason="Food reserve shorter than acquisition margin"}
    end
    if t and t<(options.thirstTrigger or 44)/100 then return {kind="DRINK",reason="Thirst care"} end
    if h and h<(options.hungerTrigger or 42)/100 then return {kind="EAT",reason="Hunger care"} end
    return {kind="TERRITORY",reason="Survival reserve available"}
end
function Planner.need(state,options)return Planner.decide(state,options).kind end
-- Due-job deadlines and sustained maintenance are separate estimates. Include
-- healthy owned hexes in the latter: a full scent bar still creates future work.
-- Unknown decay is never silently replaced by an invented native lifetime.
function Planner.capacity(hexes,state,options)
    options=options or {}
    local jobs,recurring={},{}
    local unknown,owned=0,0
    local refill=finite(state.refillTime) and state.refillTime>0 and state.refillTime or 60
    local horizon=finite(options.horizon) and clamp(options.horizon,120,7200) or 900
    local floor=.35
    local function travel(from,to,purpose)
        local fallback=dist(from,to)/math.max(6,finite(state.travelSpeed) and state.travelSpeed or 24)
        if type(state.travelCost)=="function" then
            local ok,value=pcall(state.travelCost,from,to,purpose)
            if ok and finite(value) and value>=0 then return value end
        end
        return fallback
    end
    for _,hex in ipairs(hexes) do
        if state.pack~=nil and hex.owner==state.pack and not hex.neutral then
            owned+=1
            local item=Planner.objective(hex,state,state.position,options)
            if item and item.deadlineSeconds then table.insert(jobs,item) end
            local rate=hex.decayPerSecond
            if type(hex.key)=="string" and finite(rate) and rate>0 and rate<.1 and finite(hex.hold)
                and hex.center and finite(hex.center.x) and finite(hex.center.z) and #recurring<128 then
                local period=(1-floor)/rate
                local service=refill*(1-floor)
                table.insert(recurring,{key=hex.key,center=hex.center,pay=finite(hex.pay) and clamp(hex.pay,1,20) or 1,
                    period=period,service=service,load=service/period,
                    nextDue=math.max(0,(hex.hold-floor)/rate),
                    travel=travel(state.position,hex.center,"HEX:"..hex.key)})
            else unknown+=1 end
        end
    end
    table.sort(jobs,function(a,b)
        return a.deadlineSeconds==b.deadlineSeconds and a.key<b.key or a.deadlineSeconds<b.deadlineSeconds
    end)
    local elapsed,misses=0,0;local from=state.position
    for _,item in ipairs(jobs) do
        elapsed+=travel(from,item.center,"HEX:"..item.key)+item.serviceSeconds
        if elapsed>item.deadlineSeconds then misses+=1 end
        from=item.center
    end
    -- A bounded nearest-neighbour tour gives a travel allowance. It is an
    -- estimate, not a proof that every live terrain segment is traversable.
    local remaining=table.clone(recurring);from=state.position
    local tour,period,serviceLoad,events=0,math.huge,0,0
    for _,job in ipairs(recurring) do
        period=math.min(period,job.period);serviceLoad+=job.load
        events+=math.max(0,math.floor((horizon-job.nextDue)/job.period)+1)
    end
    while #remaining>0 do
        local index,best=1,math.huge
        for i,job in ipairs(remaining) do
            local cost=(from.x-job.center.x)^2+(from.z-job.center.z)^2
            if cost<best or cost==best and job.key<remaining[index].key then index,best=i,cost end
        end
        local job=table.remove(remaining,index);tour+=travel(from,job.center,"HEX:"..job.key);from=job.center
    end
    if #recurring>1 then tour+=travel(from,state.position,"MAINTENANCE_RETURN") end
    local care=finite(options.careFraction) and clamp(options.careFraction,0,.75) or 0
    local available=1-care
    local load=serviceLoad+(period<math.huge and tour/period or 0)
    local maintenanceState=#recurring==0 and "UNKNOWN" or unknown>0 and "PARTIAL"
        or load>available and "OVERLOADED" or "ESTIMATED_SUSTAINABLE"
    local retain,retained,retainedLoad={},0,0
    -- Act only on proven service overload (even zero travel cannot fit). The
    -- travel estimate alone may defer new acquisitions but does not abandon
    -- existing owned work. Higher-value cheap maintenance remains productive.
    local hardOverload=unknown==0 and serviceLoad>available
    if hardOverload then
        table.sort(recurring,function(a,b)
            local ar=a.pay/math.max(.0001,a.load+a.travel/a.period)
            local br=b.pay/math.max(.0001,b.load+b.travel/b.period)
            return ar==br and a.key<b.key or ar>br
        end)
        for _,job in ipairs(recurring) do
            local marginal=job.load+job.travel/job.period
            if retainedLoad+marginal<=available*.95 or retained==0 then
                retain[job.key]=true;retained+=1;retainedLoad+=marginal
            end
        end
    end
    return {knownDeadlines=#jobs,unknown=unknown,estimatedSeconds=elapsed,predictedLate=misses,
        state=#jobs==0 and "UNKNOWN" or misses>0 and "DEADLINE_PRESSURE" or "DUE_WORK_FEASIBLE",
        scope="due deadlines plus bounded recurring owned-map workload; estimates require live calibration",
        maintenance={state=maintenanceState,owned=owned,known=#recurring,unknown=unknown,horizonSeconds=horizon,
            visits=events,serviceUtilization=serviceLoad,travelUtilization=period<math.huge and tour/period or 0,
            estimatedUtilization=load,availableFraction=available,tourSeconds=tour,
            intervalSeconds=period<math.huge and period or nil,retained=hardOverload and retained or owned,
            retainedFeasible=hardOverload and retainedLoad<=available or not hardOverload},
        maintenanceOnly=unknown==0 and #recurring>0 and load>available,
        retainOwned=hardOverload and retain or nil,
        policy=hardOverload and (retainedLoad<=available and "Retain highest-value estimated maintenance subset; no new claims"
            or "Even best maintenance exceeds capacity; prioritize it without new claims")
            or maintenanceState=="OVERLOADED" and "Preserve owned maintenance before new claims"
            or unknown>0 and "Unknown lifetime remains eligible; no sustainability claim" or "Full observed workload estimated"}
end
return Planner
]============]
sources["gait"] = [============[
-- FERAL Amber: pure navigation/locomotion decisions, no side effects.
-- Distances in horizontal studs; angles in degrees; reserves protect stamina.
local Gait={}
local function finite(x)
    return type(x)=="number" and x==x and math.abs(x)<1e9
end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
function Gait.distance(a,b)
    if not a or not b or not finite(a.x) or not finite(a.z)
        or not finite(b.x) or not finite(b.z) then return math.huge end
    local dx,dz=a.x-b.x,a.z-b.z
    return math.sqrt(dx*dx+dz*dz)
end
function Gait.turn(previous,position,target)
    if not previous or not position or not target then return 0 end
    local ax,az=position.x-previous.x,position.z-previous.z
    local bx,bz=target.x-position.x,target.z-position.z
    local la=math.sqrt(ax*ax+az*az)
    local lb=math.sqrt(bx*bx+bz*bz)
    if la<1 or lb<1 then return 0 end
    local dot=clamp((ax*bx+az*bz)/(la*lb),-1,1)
    return math.deg(math.acos(dot))
end
-- Trot and sprint are valid across land animals; burst only when an actual
-- game input is available and enough stamina remains. Never force WalkSpeed.
function Gait.select(distance,turn,stamina,options)
    options=options or {}
    if not finite(distance) or distance<=0 then return "STOP" end
    if options.ability or options.injured then return "TROT" end
    if options.combat and not options.hunting then return "TROT" end
    if options.swimming then
        if options.swimSprint and distance>45 and (not finite(stamina) or stamina>.25) then return "SPRINT" end
        return "TROT"
    end
    if options.following and type(options.gaitSpeeds)=="table" then
        for _,mode in ipairs({"WALK","TROT","SPRINT"}) do
            local speed=options.gaitSpeeds[mode] or options.gaitSpeeds[string.lower(mode)]
            if finite(speed) and speed>=(options.preySpeed or 0)*1.08 then return mode end
        end
    end
    local reserve=finite(stamina) and stamina or nil
    local angle=finite(turn) and turn or 0
    if options.allowBurst~=false and (reserve and reserve>=.56 or not reserve and options.nativeBurstAvailable==true)
        and distance>=80 and angle<=22 and not options.crowded
        and options.burstReady~=false then return "BURST" end
    if options.hunting and (options.preySpeed or 0)>6 and distance>6
        and (not reserve or reserve>=.22) and angle<65 then return "SPRINT" end
    if distance<10 then return "WALK" end
    if distance<24 then return "TROT" end
    if distance>=48 and angle<=72 and not options.crowded
        and (not reserve or reserve>=.22) then return "SPRINT" end
    return "TROT"
end

-- Stateful requests with observed HUD acknowledgements. A successful key API
-- call is only an input request. Burst and trot are native Begin toggles.
function Gait.controller(io)
    local g={requested="STOP",observed="UNKNOWN",changedAt=-100,
        attempts={},blocked={},pending=nil,lastSuccess=nil,reason="Idle",
        burstOwned=false,trotOwned=false,requests=0,confirmations=0}
    function g:step(wanted,s,now)
        s=s or {}
        local observed=s.hudBurst==true and "BURST"
            or s.hudSprint==true and "SPRINT"
            or s.hudTrot==true and "TROT"
            or s.hudSprint==false and s.hudTrot==false and s.hudBurst==false and "WALK"
            or "UNKNOWN"
        self.observed=observed
        if self.pending then
            local p=self.pending
            local confirmed=(p.mode==observed)
                or p.mode=="BURST_OFF" and s.hudBurst==false
                or p.mode=="WALK" and s.hudTrot==false and s.hudSprint==false
            if confirmed then
                self.lastSuccess=now;self.confirmations+=1
                self.attempts[p.mode]=0;self.pending=nil
                self.reason="Native gait observed"
            elseif now-p.at>=1.25 then
                local count=self.attempts[p.mode] or 1
                if count>=2 then self.blocked[p.mode]=now+8 end
                self.pending=nil;self.reason="Gait request unconfirmed"
                if p.mode=="SPRINT" then io:hold("SHIFT",false) end
                if count==1 and type(io.retryInput)=="function" then
                    io:retryInput(p.mode=="SPRINT" and "SHIFT" or p.mode=="TROT" and "Z" or "X")
                end
            end
        end
        local emergency=wanted=="STOP" or wanted=="WALK" or s.ability or s.swimming or s.brake
        local boost=wanted=="BURST" and self.requested=="SPRINT" and observed=="SPRINT"
        if wanted~=self.requested and not emergency and not boost and now-self.changedAt<1.1 then
            wanted=self.requested
        end
        if wanted=="BURST" and (type(s.hudBurst)~="boolean" or s.hudBurstNo or (self.blocked.BURST or 0)>now) then wanted="SPRINT" end
        if (wanted=="SPRINT" or wanted=="BURST") and (self.blocked.SPRINT or 0)>now then wanted="TROT" end
        if wanted~=self.requested then self.changedAt=now;self.requested=wanted end
        if observed==wanted and not self.pending then self.reason="Native gait already active" end
        local fast=wanted=="SPRINT" or wanted=="BURST"
        io:hold("SHIFT",fast)
        local function request(mode,key)
            if self.pending and self.pending.mode~=mode and mode=="BURST_OFF" then self.pending=nil end
            if self.pending or (self.blocked[mode] or 0)>now then return end
            local sent=key=="SHIFT" and io:hold(key,true) or io:tap(key)
            if sent then
                self.attempts[mode]=(self.attempts[mode] or 0)+1
                self.requests+=1;self.pending={mode=mode,at=now}
                self.reason="Input requested; awaiting native gait"
                if mode=="BURST" then self.burstOwned=true end
                if mode=="TROT" then self.trotOwned=true end
            else self.blocked[mode]=now+8;self.reason="Gait input unavailable" end
        end
        if wanted~="BURST" and s.hudBurst==true and self.burstOwned then
            request("BURST_OFF","X")
        elseif wanted=="BURST" and s.hudBurst==false then request("BURST","X")
        elseif fast and s.hudSprint==false and s.hudBurst~=true then request("SPRINT","SHIFT")
        elseif wanted=="TROT" and s.hudTrot==false and s.hudBurst~=true then request("TROT","Z")
        elseif wanted=="WALK" and s.hudTrot==true and self.trotOwned then request("WALK","Z") end
        return self.requested
    end
    function g:stop(s,now)
        io:hold("SHIFT",false)
        -- Undo toggles only when this controller requested them and their
        -- current native state is known. Never blindly toggle an unknown mode.
        if s and s.hudBurst==true and self.burstOwned then io:tap("X") end
        if s and s.hudTrot==true and self.trotOwned then io:tap("Z") end
        self.burstOwned,self.trotOwned=false,false
        self.pending=nil;self.requested="STOP";self.changedAt=now or 0
    end
    return g
end
function Gait.arrived(destinationDistance,claimRadius)
    if not finite(destinationDistance) then return false end
    return destinationDistance<=math.max(8,(claimRadius or 17)-2)
end
-- Keep a goal unless its progress stalls. Do not change directions on each
-- intermediate waypoint when the destination is already within claim radius.
function Gait.waypointIndex(points,index,pos,reach)
    local i=math.max(1,index or 1)
    local radius=math.max(6,reach or 11)
    while i<=#points do
        local point=points[i]
        if Gait.distance(pos,point)<=radius then i+=1
        else break end
    end
    return i
end
function Gait.progress(now,previousTime,previousDistance,currentDistance,delay,minGain)
    if not finite(previousTime) or not finite(previousDistance) then
        return "RESET" end
    if now-previousTime < (delay or 4) then return "MONITOR" end
    if previousDistance-currentDistance >= (minGain or 3) then return "ADVANCING" end
    return "STALLED"
end
return Gait
]============]
sources["nav"] = [============[
-- Continuous native steering, cancellable streamed routes and measured progress.
local Nav={}
local function flat(a,b)
    local x,z=a.X-b.X,a.Z-b.Z
    return math.sqrt(x*x+z*z)
end
local function p2(v) return {x=v.X,z=v.Z} end
local function rayParams(char)
    local p=RaycastParams.new()
    p.FilterType=Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances={char};p.IgnoreWater=false;p.RespectCanCollide=true
    return p
end
function Nav.new(pathService,workspace,Gait,model)
    local n={service=pathService,workspace=workspace,math=Gait,model=model,synthetic={},held={},backends={},gaitBackends={},
        recoveryCells={},trajectory={},operations={rays=0,surfaces=0,paths=0},
        destination=nil,body=nil,points={},index=1,epoch=0,keyEpoch=0,
        lastReason="IDLE",lastFailure=nil,gait="STOP",nativeInput="UNTESTED",
        preferredStrategy="WORLD",steeringStrategy="WORLD",lastMode="WORLD",
        failures=0,replans=0,routeFailures=0,stallsInRow=0,waterRoutes=0,
        strategyChanges=0,inputVerified=false,inputAttempts=0,driveCalls=0,
        travelled=0,distance=nil,speed=0,corrections=0,segmentCount=0,arrivalRadius=8,
        lastBurstAt=-100,lastTrotAt=-100,nextRouteAt=0,closed=false}
    local bindings={W=Enum.KeyCode.W,A=Enum.KeyCode.A,S=Enum.KeyCode.S,
        D=Enum.KeyCode.D,SHIFT=Enum.KeyCode.LeftShift,X=Enum.KeyCode.X,Z=Enum.KeyCode.Z}
    local codes={W=0x57,A=0x41,S=0x53,D=0x44,SHIFT=0xA0,X=0x58,Z=0x5A}
    local function send(name,on,backend)
        n.synthetic[name]=os.clock()
        if backend~="EXECUTOR" then
            local ok,v=pcall(function()return game:GetService("VirtualInputManager")end)
            if ok and v and pcall(v.SendKeyEvent,v,on,bindings[name],false,game) then return true,"VIRTUAL" end
        end
        local fn=on and keypress or keyrelease
        if type(fn)=="function" and pcall(fn,codes[name]) then return true,"EXECUTOR" end
        return false,"UNAVAILABLE"
    end
    function n:hold(name,on)
        if not bindings[name] then return false end
        if (self.held[name]==true)==on then return true end
        local ok,method=send(name,on,self.backends[name] or self.gaitBackends[name] or self.keyBackend)
        if on and ok then
            self.held[name]=true;self.backends[name]=method
            self.nativeInput=method;self.inputAttempts+=1
        elseif not on then self.held[name]=nil;self.backends[name]=nil end
        return ok
    end
    function n:tap(name)
        if self.held[name] or not self:hold(name,true) then return false end
        local epoch=self.keyEpoch
        task.delay(.09,function() if self.keyEpoch==epoch then self:hold(name,false) end end)
        return true
    end
    function n:retryInput(name)
        if type(keypress)~="function" or type(keyrelease)~="function" then return false end
        self:hold(name,false);self.gaitBackends[name]="EXECUTOR"
        return true
    end
    function n:releaseSteering()
        for _,key in ipairs({"W","A","S","D"}) do self:hold(key,false) end
    end
    function n:releaseKeys()
        self.keyEpoch+=1
        local keys={}
        for k in pairs(self.held) do table.insert(keys,k) end
        for _,k in ipairs(keys) do self:hold(k,false) end
    end
    n.gaits=Gait.controller(n)
    function n:stop(hum,root,reason)
        local active=self.desiredPoint~=nil or self.destination~=nil
        if active and reason=="at territory" and self.model and self.costPoint and self.goalOrigin and not self.costRecorded then
            self.model:record(p2(self.goalOrigin),self.costPoint,math.max(.1,(self.lastAt or 0)-(self.goalStarted or 0)),self.lastAt or 0,false,self.costPurpose,true)
            self.costRecorded=true
        end
        if active and self.model and self.goalOrigin and self.destination and not self.costRecorded
            and ((self.routeFailures or 0)>=4 or (self.stallsInRow or 0)>=3) then
            self.model:record(p2(self.goalOrigin),self.costPoint or p2(self.destination),math.max(1,(self.lastAt or 0)-(self.goalStarted or 0)),self.lastAt or 0,true,self.costPurpose)
            self.costRecorded=true
        end
        self.epoch+=1;self.pending=nil
        self.desiredPoint,self.desiredRoot,self.desiredHum=nil,nil,nil
        local sameBody=not self.bodyRoot or self.bodyRoot==root
        if active then self.gaits:stop(sameBody and self.lastState or nil,self.lastAt or 0) end
        self:releaseKeys();self.gait="STOP"
        if active and sameBody and hum then pcall(hum.Move,hum,Vector3.zero,false) end
        self.destination,self.body,self.identity=nil,nil,nil
        self.points,self.index={},1;self.lastPosition=nil
        self.lastReason=reason or "IDLE"
    end
    function n:reset(destination,char,now,identity)
        self.epoch+=1;self.pending=nil
        self.destination,self.body,self.identity=destination,char,identity
        self.points,self.index={},1;self.nextRouteAt=now
        self.desiredPoint=nil;self:releaseSteering()
        self.lastProgressAt=now;self.lastPosition=nil;self.lastSampleAt=now
        self.windowAt=now;self.windowOrigin=nil;self.windowTravel=0
        self.stallsInRow,self.routeFailures,self.corrections=0,0,0
        self.inputVerified=false;self.steeringStrategy=self.preferredStrategy
        self.recoveryProgress=0;self.overlapAt=nil;self.overlapParts=nil
        self.detourUntil=nil;self.lastObstacleProbe=nil
        self.lastReason="NEW_ROUTE";self.goalStarted=now
        self.routeTravel=0;self.safetyBlockedUntil=nil;self.lastSafety=nil
        self.goalOrigin=nil;self.costRecorded=false;self.trajectory={};self.bestGoalDistance=nil
    end
    function n:surface(pos,char,allowWater)
        self.operations.surfaces+=1
        local cacheKey=string.format("%.1f:%.1f:%.1f:%s",pos.X,pos.Y,pos.Z,tostring(allowWater))
        local cache=self.surfaceCache and self.surfaceCache[cacheKey]
        if cache then return cache.point,cache.wet end
        local params=rayParams(char)
        local root=char and type(char.FindFirstChild)=="function" and char:FindFirstChild("HumanoidRootPart")
        local originY=root and root.Position.Y or pos.Y
        -- Prefer the real terrain under tall foliage. A low supporting solid
        -- surface may override it for rocks, bridges and constructed ground.
        local terrainParams=rayParams(char)
        terrainParams.FilterType=Enum.RaycastFilterType.Include
        terrainParams.FilterDescendantsInstances={self.workspace.Terrain}
        self.operations.rays+=2
        local terrain=self.workspace:Raycast(Vector3.new(pos.X,math.max(pos.Y,originY)+100,pos.Z),Vector3.new(0,-420,0),terrainParams)
        local solid=self.workspace:Raycast(Vector3.new(pos.X,originY+12,pos.Z),Vector3.new(0,-420,0),params)
        local hit=terrain or solid
        if solid and solid.Normal.Y>=.46 and solid.Position.Y<=originY+5
            and (not terrain or solid.Position.Y>terrain.Position.Y+.4) then hit=solid end
        if not hit then return nil end
        local wet=hit.Material==Enum.Material.Water
        if wet and not allowWater or not wet and hit.Normal.Y<(self.minGroundNormal or .46) then return nil end
        local position=hit.Position+Vector3.new(0,2.5,0)
        if self.surfaceCache then self.surfaceCache[cacheKey]={point=position,wet=wet} end
        return position,wet
    end
    function n:bodyClear(from,to,char)
        local direction=to-from
        if direction.Magnitude<.1 then return true end
        -- Sweeps omit shapes already touching their start volume. Check the
        -- actual animal root separately and allow movement out of an overlap.
        if self.bodyRoot and type(self.workspace.GetPartsInPart)=="function" and OverlapParams then
            local at=self.lastAt or 0
            if not self.overlapAt or at-self.overlapAt>.4 then
                self.overlapAt=at
                local params=OverlapParams.new()
                params.FilterType=Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances={char};params.RespectCanCollide=true;params.MaxParts=12
                self.operations.overlaps=(self.operations.overlaps or 0)+1
                local ok,parts=pcall(self.workspace.GetPartsInPart,self.workspace,self.bodyRoot,params)
                self.overlapParts=ok and parts or {}
            end
            for _,part in ipairs(self.overlapParts or {}) do
                if part.CanCollide~=false and part.Position then
                    local away=Vector3.new(from.X-part.Position.X,0,from.Z-part.Position.Z)
                    if away.Magnitude>.05 and direction:Dot(away)<0 then
                        self.lastObstacle={Instance=part};return false
                    end
                end
            end
        end
        if type(self.workspace.Blockcast)=="function" and CFrame and type(CFrame.lookAt)=="function" then
            local params=rayParams(char);params.IgnoreWater=true
            local size=Vector3.new((self.clearance or 2)*1.9,self.bodyHeight or 2,self.bodyLength or 4)
            self.operations.sweeps=(self.operations.sweeps or 0)+1
            local ok,hit=pcall(self.workspace.Blockcast,self.workspace,CFrame.lookAt(from,from+direction),size,direction,params)
            if ok and hit and (not hit.Instance or hit.Instance.CanCollide~=false) then
                self.lastObstacle=hit;return false
            end
        end
        return true
    end
    function n:clearSegment(from,to,char,allowWater,precise)
        self.lastSafety=nil
        local distance=flat(from,to)
        if distance<.1 then return true,false end
        local params=rayParams(char);params.IgnoreWater=true
        if not self:bodyClear(from,to,char) then return false,false end
        -- Terrain walls are obstacles too; never exempt Terrain from this ray.
        self.operations.rays+=3
        local hit=self.workspace:Raycast(from+Vector3.new(0,1.5,0),to-from,params)
        if hit and (not hit.Instance or hit.Instance.CanCollide~=false) then return false,false end
        local perpendicular=Vector3.new(-(to.Z-from.Z)/distance,0,(to.X-from.X)/distance)
        for _,side in ipairs({-1,1}) do
            local offset=perpendicular*(self.clearance or 2)*side
            local flank=self.workspace:Raycast(from+Vector3.new(0,1.5,0)+offset,to-from,params)
            if flank and (not flank.Instance or flank.Instance.CanCollide~=false) then return false,false end
        end
        local wet=false;local previous={}
        local steps=math.max(1,math.ceil(distance/(precise and 1 or 3)))
        for step=0,steps do
            local p=from+(to-from)*(step/steps)
            local center
            for _,side in ipairs({0,-1,1}) do
                local offset=perpendicular*(self.clearance or 2)*.8*side
                local ground,water=self:surface(p+offset,char,allowWater)
                if not ground then self.lastSafety="MISSING_SUPPORT";return false,wet end
                if side==0 then center=ground end
                if not previous[side] and from.Y-ground.Y>(self.supportHeight or 5)+(self.maxDrop or 3) then
                    self.lastSafety="UNSUPPORTED_DROP";return false,wet
                end
                if previous[side] then
                    local rise=ground.Y-previous[side].Y
                    if rise>(self.maxStepUp or 3) or -rise>(self.maxDrop or 3) then
                        self.lastSafety=rise>0 and "STEEP_ASCENT" or "UNSAFE_DESCENT"
                        return false,wet
                    end
                end
                if center and math.abs(ground.Y-center.Y)>math.max(self.maxDrop or 3,self.maxStepUp or 3) then
                    self.lastSafety="UNSUPPORTED_BODY_EDGE";return false,wet
                end
                previous[side]=ground;wet=wet or water
            end
        end
        return true,wet
    end
    function n:detour(root,char,state,now)
        local delta=self.destination-root.Position
        local d=flat(self.destination,root.Position)
        if d<.1 then return false end
        local base=Vector3.new(delta.X/d,0,delta.Z/d)
        local span=math.clamp((self.clearance or 2)*2.5,8,18)
        local sides=self.detourSide or 1
        for _,angle in ipairs({sides*1.1,-sides*1.1,sides*1.8,-sides*1.8,math.pi}) do
            local x=base.X*math.cos(angle)-base.Z*math.sin(angle)
            local z=base.X*math.sin(angle)+base.Z*math.cos(angle)
            local point=self:surface(root.Position+Vector3.new(x*span,0,z*span),char,state.allowWater==true)
            local cell=point and (math.floor(point.X/10)..":"..math.floor(point.Z/10))
            if point and (not self.recoveryCells[cell] or now-self.recoveryCells[cell]>20)
                and self:clearSegment(root.Position,point,char,state.allowWater==true,true) then
                self.recoveryCells[cell]=now
                local count=0;for key,at in pairs(self.recoveryCells) do count+=1;if now-at>30 then self.recoveryCells[key]=nil end end
                if count>96 then self.recoveryCells={[cell]=now} end
                self.epoch+=1;self.pending=nil
                self.points,self.index={point},1;self.routeOrigin=root.Position
                self.detourUntil=now+3;self.detourSide=-sides
                self.obstacleRecoveries=(self.obstacleRecoveries or 0)+1
                self.lastFailure="LOCAL_OBSTACLE_DETOUR"
                return true
            end
        end
        return false
    end
    function n:mesh(from,target,root,hum,char,state)
        self.operations.paths+=1
        local ok,path=pcall(function()
            local p=self.service:CreatePath({AgentRadius=self.clearance or 3,
                AgentHeight=math.clamp(hum.HipHeight+root.Size.Y+1,4,30),
                AgentCanJump=false,AgentCanClimb=false,WaypointSpacing=12})
            p:ComputeAsync(from,target);return p
        end)
        if not ok or path.Status~=Enum.PathStatus.Success then return nil end
        local points={};local previous=from
        for _,waypoint in ipairs(path:GetWaypoints()) do
            local p=waypoint.Position
            if typeof(p)=="Vector3" and flat(p,from)>2 then
                local ground=self:surface(p,char,false)
                if not ground or not self:clearSegment(previous,ground,char,false) then return nil end
                table.insert(points,ground);previous=ground
            end
            if #points>160 then return nil end
        end
        return #points>0 and points or nil
    end
    function n:compute(from,root,hum,char,state,goal,attempt)
        local distance=flat(from,goal)
        if distance<.01 then return {},"EMPTY_ROUTE" end
        local delta=goal-from;local dir=Vector3.new(delta.X/distance,0,delta.Z/distance)
        local span=math.min(distance,100)
        local allowWater=state.allowWater==true
        local direct=self:surface(from+dir*span,char,allowWater)
        if direct then
            local clear,wet=self:clearSegment(from,direct,char,allowWater)
            if clear then return {direct},(wet or state.swimming) and "SWIM_ROUTE" or "CLEAR_SURFACE" end
        end
        if not state.movingTarget and not state.swimming then
            local full=self:surface(goal,char,false)
            if full and distance<=900 then
                if self.model then
                    local cached=self.model:path(p2(from),p2(full),state.now or self.lastAt or 0)
                    if cached then
                        local result={};local previous=from;local valid=true
                        for _,p in ipairs(cached) do
                            local v=Vector3.new(p.x,p.y or full.Y,p.z)
                            if not self:clearSegment(previous,v,char,false) then valid=false;break end
                            table.insert(result,v);previous=v
                        end
                        if valid then return result,"CHECKED_PASSAGE" end
                    end
                end
                local fullPath=self:mesh(from,full,root,hum,char,state)
                if fullPath then return fullPath,"PATH_SURFACE_FULL" end
            end
        end
        local angles={0,-.45,.45,-.9,.9}
        if attempt%2==1 then angles={0,.45,-.45,.9,-.9} end
        for _,angle in ipairs(angles) do
            local length=angle==0 and span or math.min(span,55)
            local x=dir.X*math.cos(angle)-dir.Z*math.sin(angle)
            local z=dir.X*math.sin(angle)+dir.Z*math.cos(angle)
            local surface,water=self:surface(from+Vector3.new(x*length,0,z*length),char,allowWater)
            if surface then
                local clear,crossesWater=self:clearSegment(from,surface,char,allowWater)
                if clear then return {surface},(water or crossesWater or state.swimming) and "SWIM_ROUTE" or "CLEAR_SURFACE" end
                if not water and not state.swimming then
                    local points=self:mesh(from,surface,root,hum,char,state)
                    if points then return points,"PATH_SURFACE" end
                end
            end
        end
        return nil,"NO_STREAMED_SAFE_ROUTE"
    end
    function n:route(root,hum,char,now,state)
        if self.pending or (self.activeJobs or 0)>=2 or now<self.nextRouteAt then return end
        local epoch=self.epoch
        local request={at=now,epoch=epoch,origin=root.Position,goal=self.destination}
        self.pending=request;self.activeJobs=(self.activeJobs or 0)+1
        -- ComputeAsync may yield through an animal/goal replacement. Isolate
        -- every cache and collision side effect before the adoption lease is
        -- checked, rather than merely rejecting the eventual waypoint list.
        local worker=table.clone(self)
        worker.operations={rays=0,surfaces=0,paths=0};worker.surfaceCache={}
        worker.overlapAt=nil;worker.overlapParts=nil
        task.spawn(function()
            local started=os.clock()
            local ok,points,reason=pcall(worker.compute,worker,request.origin,root,hum,char,
                table.clone(state or {}),request.goal,self.replans)
            self.pathWall=(self.pathWall or 0)+math.max(0,os.clock()-started)
            self.activeJobs-=1
            for name,count in pairs(worker.operations) do self.operations[name]=(self.operations[name] or 0)+count end
            if self.closed or self.epoch~=epoch or self.pending~=request then return end
            self.pending=nil
            self.lastSafety=worker.lastSafety;self.lastObstacle=worker.lastObstacle
            if not ok or not points then
                self.routeFailures+=1;self.failures+=1
                self.lastFailure=ok and reason or "PATH_COMPUTATION_ERROR"
                self.lastReason=self.lastFailure;self.nextRouteAt=now+1.5
                return
            end
            -- An old path cannot pull a moving animal back toward its old start.
            if not root.Parent or self.body~=char then return end
            -- Rebase a late same-goal path at the closest checked forward join.
            local bestIndex,best=1,math.huge
            for index,p in ipairs(points) do
                local previous=points[index-1] or request.origin
                local delta=p-previous;local len=delta:Dot(delta)
                local t=len>.01 and math.clamp((root.Position-previous):Dot(delta)/len,0,1) or 0
                local projection=previous+delta*t;local d=flat(root.Position,projection)
                if d<best and self:clearSegment(root.Position,p,char,state.allowWater==true,true) then bestIndex,best=index,d end
            end
            if flat(root.Position,request.origin)>30 and best>math.max(15,self.clearance*3) then
                self.lastFailure="OBSOLETE_PATH_ORIGIN";self.nextRouteAt=self.lastAt or now;return
            end
            self.points,self.index=points,bestIndex;self.routeOrigin=request.origin
            self:advance(root,math.clamp(root.Size.X*.5+4,6,12))
            if self.model then
                local observed={{x=request.origin.X,y=request.origin.Y,z=request.origin.Z}}
                for _,p in ipairs(points) do table.insert(observed,{x=p.X,y=p.Y,z=p.Z}) end
                self.model:addRoute(observed,self.lastAt or now)
            end
            self.segmentCount+=1;self.routeFailures=0
            self.routeAt=now;self.lastReason=reason
            self.routeWater=reason=="SWIM_ROUTE"
            if self.routeWater then self.waterRoutes+=1 end
        end)
    end
    function n:direction()
        local root,hum,p=self.desiredRoot,self.desiredHum,self.desiredPoint
        if not root or not hum or not p or not root.Parent or hum.Health<=0 then return nil end
        local delta=Vector3.new(p.X-root.Position.X,0,p.Z-root.Position.Z)
        if delta.Magnitude<=self.arrivalRadius and flat(root.Position,self.destination or p)<=self.arrivalRadius then return Vector3.zero end
        if delta.Magnitude<.1 then return Vector3.zero end
        return delta.Unit*(self.inputScale or 1)
    end
    function n:drive()
        self.driveCalls+=1
        local direction=self:direction()
        if not direction then self:releaseSteering();return end
        if self.steeringStrategy=="WORLD" then
            self:releaseSteering();self.desiredHum:Move(direction,false)
            self.lastMode="WORLD";return
        end
        local camera=self.workspace.CurrentCamera
        if not camera then self:releaseSteering();self.lastFailure="NO_CAMERA";return end
        if direction.Magnitude<.01 then self:releaseSteering();return end
        -- Keys are digital: an analog following scale must not fall below
        -- every direction threshold and silently stop a moving pursuit.
        direction=direction.Unit
        local f,r=camera.CFrame.LookVector,camera.CFrame.RightVector
        f=Vector3.new(f.X,0,f.Z);r=Vector3.new(r.X,0,r.Z)
        if f.Magnitude<.1 or r.Magnitude<.1 then self:releaseSteering();return end
        local forward,side=direction:Dot(f.Unit),direction:Dot(r.Unit)
        -- Eight directions avoid the four-direction fallback's square orbit.
        local keys={W=forward>.38,S=forward<-.38,D=side>.38,A=side<-.38}
        for key,on in pairs(keys) do self:hold(key,on) end
        self.lastMode="NATIVE_KEYS"
    end
    function n:advance(root,radius)
        local advanced=false
        while self.index<=#self.points do
            local p=self.points[self.index]
            local last=self.index==#self.points
            local goalNear=last and self.destination and flat(p,self.destination)<3
            local reach=goalNear and self.arrivalRadius or radius
            local near=flat(root.Position,p)<=reach
            local prev=self.points[self.index-1] or self.routeOrigin
            local passed=false
            if prev and not goalNear then
                local dx,dz=p.X-prev.X,p.Z-prev.Z;local len=math.sqrt(dx*dx+dz*dz)
                if len>.1 then
                    local beyond=((root.Position.X-p.X)*dx+(root.Position.Z-p.Z)*dz)/len
                    local cross=math.abs((root.Position.X-p.X)*dz-(root.Position.Z-p.Z)*dx)/len
                    passed=beyond>0 and cross<radius*1.4
                end
            end
            if near or passed then self.index+=1;advanced=true else break end
        end
        return advanced
    end
    function n:tick(destination,char,hum,root,now,otherPlayers,state)
        state=state or {};self.lastState=state;self.lastAt=now;self.surfaceCache={}
        if self.closed or not destination or not char or not hum or not root or hum.Health<=0 then
            self:stop(hum,root,"NO_LIVING_ANIMAL");return "WAIT"
        end
        if state.flying or state.climbing or state.underwater then
            self:stop(hum,root,"UNSUPPORTED_NATIVE_ROUTE_MODE");return "BLOCKED"
        end
        local identity=state.navKey or "STATIC"
        local replacedRoot=self.bodyRoot and self.bodyRoot~=root
        local replacedGeneration=self.characterGeneration~=nil and self.characterGeneration~=state.generation
        self.bodyRoot=root
        self.clearance=math.clamp(root.Size.X*.5+.65,2,12)
        self.bodyHeight=math.clamp(root.Size.Y*.8,1,10)
        self.bodyLength=math.clamp(root.Size.Z*.65,2,18)
        self.supportHeight=math.max(2,hum.HipHeight+root.Size.Y*.5)
        self.maxDrop=math.clamp(hum.HipHeight*.75,2,4)
        self.maxStepUp=math.clamp(hum.HipHeight,2,4)
        self.minGroundNormal=math.cos(math.rad(math.clamp(hum.MaxSlopeAngle or 55,20,55)))
        if not self.destination or self.body~=char or self.identity~=identity or replacedRoot or replacedGeneration then
            if replacedRoot or replacedGeneration then
                self.gaits:stop(nil,now);self:releaseKeys()
            end
            self:reset(destination,char,now,identity)
        end
        self.characterGeneration=state.generation
        local targetShift=flat(destination,self.destination)
        self.destination=destination
        self.arrivalRadius=state.moveRadius or 8
        self.inputScale=state.moveScale and math.clamp(state.moveScale,.15,1) or 1
        local total=flat(root.Position,destination);self.distance=total
        self.costPoint=state.costPoint;self.costPurpose=state.costPurpose
        self.goalOrigin=self.goalOrigin or root.Position
        self.bestGoalDistance=math.min(self.bestGoalDistance or total,total)
        if total<=self.arrivalRadius then
            if self.model and not self.costRecorded then
                self.model:record(p2(self.goalOrigin),self.costPoint or p2(destination),math.max(.1,now-self.goalStarted),now,false,self.costPurpose,self.costPurpose~=nil)
                self.costRecorded=true
            end
            self:stop(hum,root,"ARRIVED");return "REACHED"
        end

        local dt=now-(self.lastSampleAt or now)
        if self.lastPosition and dt>0 then
            local moved=flat(root.Position,self.lastPosition)
            if moved>math.max(90,(self.speed or 0)*dt*3+35) then
                self.corrections+=1;self.points={};self.epoch+=1;self.pending=nil
                self.desiredPoint=nil;self:releaseSteering()
                self.lastFailure="POSITION_CORRECTION";self.lastProgressAt=now
                if self.corrections>=3 then self:stop(hum,root,"REPEATED_CORRECTIONS");return "STUCK" end
            else
                self.travelled+=moved;self.routeTravel+=moved;self.windowTravel+=moved
                self.speed=self.speed*.6+math.min(180,moved/dt)*.4
                local wp=self.points[self.index]
                if wp and flat(self.lastPosition,wp)-flat(root.Position,wp)>math.max(.05,dt*.4) then
                    self.lastProgressAt=now;self.inputVerified=true
                    self.recoveryProgress+=moved
                    if self.recoveryProgress>15 then self.stallsInRow=0 end
                end
            end
        end
        self.lastPosition=root.Position;self.lastSampleAt=now
        self.windowOrigin=self.windowOrigin or root.Position
        local oscillating=false
        if now>=(self.nextTrajectoryAt or 0) then
            self.nextTrajectoryAt=now+1
            for _,sample in ipairs(self.trajectory) do
                if now-sample.at>8 and flat(root.Position,sample.position)<8
                    and self.routeTravel-sample.travel>70 and total>=sample.distance-5 then
                    oscillating=true;self.lastFailure="RECURRENT_ROUTE";self.lastProgressAt=now-6;break
                end
            end
            table.insert(self.trajectory,{at=now,position=root.Position,travel=self.routeTravel,distance=total})
            while #self.trajectory>40 do table.remove(self.trajectory,1) end
        end
        if now-self.windowAt>=6 then
            if self.windowTravel>35 and flat(root.Position,self.windowOrigin)<6 then
                self.lastProgressAt=math.min(self.lastProgressAt,now-6)
                self.lastFailure="OSCILLATION"
                oscillating=true
            end
            self.windowOrigin=root.Position;self.windowTravel=0;self.windowAt=now
        end
        local waypointRadius=self.detourUntil and now<self.detourUntil and 2 or math.clamp(root.Size.X*.5+4,6,12)
        local advanced=self:advance(root,waypointRadius)
        if advanced and not oscillating then self.lastProgressAt=now;self.inputVerified=true end
        if self.pending and now-self.pending.at>4 then
            self.epoch+=1;self.pending=nil;self.routeFailures+=1
            self.lastFailure="PATH_TIMEOUT"
        end
        if self.routeFailures>=4 then self:stop(hum,root,self.lastFailure);return "STUCK" end
        if now-self.lastProgressAt>.9 and now-(self.lastObstacleProbe or 0)>1
            and not (self.detourUntil and now<self.detourUntil and self.index<=#self.points) then
            self.lastObstacleProbe=now
            local probePoint=self.desiredPoint or destination
            local towards=probePoint-root.Position
            local dist=flat(probePoint,root.Position)
            if dist>1 then
                local probe=root.Position+Vector3.new(towards.X/dist,0,towards.Z/dist)*math.min(12,dist)
                if not self:bodyClear(root.Position,probe,char) then
                    self.lastCollisionAt=now
                    self:detour(root,char,state,now)
                end
            end
        end
        if now-self.lastProgressAt>(self.inputVerified and 2.5 or 1.6) then
            self.stallsInRow+=1;self.replans+=1;self.lastProgressAt=now
            self.recoveryProgress=0
            self.points={};self.epoch+=1;self.pending=nil;self.desiredPoint=nil
            self:releaseSteering();self:hold("SHIFT",false)
            self.lastFailure=(self.lastFailure=="OSCILLATION" or self.lastFailure=="RECURRENT_ROUTE") and self.lastFailure or "NO_PHYSICAL_PROGRESS"
            if self.stallsInRow==1 and self.steeringStrategy=="WORLD" and now-(self.lastCollisionAt or -100)>3 then
                self.steeringStrategy="KEY";self.strategyChanges+=1
            elseif self.stallsInRow==2 and type(keypress)=="function" then self.keyBackend="EXECUTOR" end
            if self.stallsInRow>=3 then self:stop(hum,root,"BOUNDED_STUCK");return "STUCK" end
        end
        local exhausted=self.index>#self.points
        if exhausted then
            self.points={};self.index=1;self.desiredPoint=nil
            self:releaseSteering()
        end
        -- Prepare the next segment while following the current valid segment.
        local tail=self.points[#self.points]
        local prefetch=tail and flat(root.Position,tail)<math.max(24,self.speed*.85)
            and flat(tail,destination)>15
        if (not self.detourUntil or now>=self.detourUntil or exhausted) and (exhausted or prefetch or targetShift>14 and now-(self.routeAt or 0)>1.1) then
            self:route(root,hum,char,now,state)
        end
        self:advance(root,waypointRadius)
        local waypoint=self.points[self.index]
        if not waypoint then
            self.desiredPoint=nil;self:releaseSteering();self:hold("SHIFT",false)
            self.lastReason=self.pending and "PLANNING" or self.lastFailure or "WAIT_ROUTE"
            return "WAIT"
        end
        if not state.movingTarget and not (self.detourUntil and now<self.detourUntil)
            and now>=(self.shortcutAt or 0) then
            self.shortcutAt=now+.75
            local d=destination-root.Position
            local direct=self:surface(root.Position+Vector3.new(d.X/total,0,d.Z/total)*math.min(total,100),char,state.allowWater==true)
            -- Prefer the checked straight corridor when an old obstacle path
            -- is no longer necessary. Do not cut a mountain bend blindly.
            if direct and flat(direct,waypoint)>8 and self:clearSegment(root.Position,direct,char,state.allowWater==true) then
                self.epoch+=1;self.pending=nil;self.points={direct};self.index=1
                self.routeOrigin=root.Position;self.segmentCount+=1;waypoint=direct
            end
        end
        -- Collapse straight, visible path sections into a body-checked horizon.
        -- Gaits can remain fast across tiny mesh waypoints without cutting bends.
        for j=math.min(#self.points,self.index+7),self.index+1,-1 do
            local candidate=self.points[j]
            if flat(root.Position,candidate)<=120 and self.math.turn(p2(root.Position),p2(waypoint),p2(candidate))<22
                and self:clearSegment(root.Position,candidate,char,state.allowWater==true) then
                self.index=j;waypoint=candidate;break
            end
        end
        -- Directly track a nearby moving target only over checked terrain.
        if state.movingTarget and total<28 then
            local clear=self:clearSegment(root.Position,destination,char,state.allowWater==true)
            if clear then waypoint=destination end
        end
        -- Recheck the immediate corridor after every meaningful navigation
        -- update. Terrain may stream/change after the path was computed.
        local ahead=waypoint-root.Position;local aheadFlat=flat(root.Position,waypoint)
        local reach=math.min(aheadFlat,math.max(8,self.speed*.75+self.bodyLength*.5))
        if aheadFlat>.1 then
            local probe=root.Position+Vector3.new(ahead.X/aheadFlat*reach,0,ahead.Z/aheadFlat*reach)
            local safe=self:clearSegment(root.Position,probe,char,state.allowWater==true,true)
            if not safe then
                self.desiredPoint=nil;self:releaseSteering();self:hold("SHIFT",false)
                if hum then pcall(hum.Move,hum,Vector3.zero,false) end
                self.lastFailure=self.lastSafety or "BLOCKED_CORRIDOR";self.lastReason="CHECKING_SAFE_APPROACH"
                self.points={};self.epoch+=1;self.pending=nil;self.nextRouteAt=now+.15
                return "WAIT"
            end
        end
        local look=root.CFrame and root.CFrame.LookVector
        local previous=look and {x=root.Position.X-look.X*5,z=root.Position.Z-look.Z*5} or nil
        local turn=self.math.turn(previous,p2(root.Position),p2(waypoint))
        local localRange=flat(root.Position,waypoint)
        local nextPoint=self.points[self.index+1]
        if nextPoint and self.math.turn(p2(root.Position),p2(waypoint),p2(nextPoint))>55 and localRange<35 then turn=math.max(turn,85) end
        self.lastTurn=turn;self.localRange=localRange
        local braking=turn>72 or total<18 or (nextPoint and localRange<math.max(20,self.speed*.55))
        state.brake=braking or self.detourUntil and now<self.detourUntil
        local wanted=self.math.select(state.hunting and total*2 or total,turn,state.staminaFraction,{
            allowBurst=state.allowBurst~=false and self.inputVerified and localRange>=38,
            nativeBurstAvailable=type(state.hudBurst)=="boolean",
            burstReady=not state.hudBurstNo,swimming=state.swimming,
            swimSprint=state.swimSprint,combat=state.combat,hunting=state.hunting,
            preySpeed=state.preySpeed,following=state.following,gaitSpeeds=state.gaitSpeeds,ability=state.ability})
        self.gait=self.gaits:step(wanted,state,now)
        self.desiredPoint,self.desiredRoot,self.desiredHum=waypoint,root,hum
        self.lastReason=(state.swimming and "SWIM_" or "FOLLOWING_")..self.gait
        return "MOVING"
    end
    function n:status()
        return {stage=self.lastReason,failure=self.lastFailure,method=self.lastMode,
            driverPath=self.driverPath,driverReason=self.driverReason,
            requested=self.gaits.requested,observed=self.gaits.observed,
            gaitReason=self.gaits.reason,gaitRequests=self.gaits.requests,
            gaitConfirmations=self.gaits.confirmations,input=self.nativeInput,
            staminaFraction=self.lastState and self.lastState.staminaFraction,
            inputVerified=self.inputVerified,distance=self.distance,
            travelled=math.floor(self.travelled*10)/10,speed=math.floor(self.speed*10)/10,
            routeTravel=math.floor((self.routeTravel or 0)*10)/10,routeAge=self.goalStarted and (self.lastAt-self.goalStarted),
            stalledFor=self.lastProgressAt and (self.lastAt-self.lastProgressAt),safety=self.lastSafety,
            replans=self.replans,failures=self.failures,waterRoutes=self.waterRoutes,
            corrections=self.corrections,segments=self.segmentCount,obstacleRecoveries=self.obstacleRecoveries or 0,
            operations=self.operations,pathJobWallSeconds=self.pathWall,activeJobs=self.activeJobs or 0,knowledge=self.model and self.model:summary()}
    end
    return n
end
return Nav
]============]
sources["hunt"] = [============[
-- Moving NPC pursuit. Inputs and observed HP changes are separate outcomes.
local Hunt={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e8 end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
function Hunt.new(adapter)
    local h={adapter=adapter,target=nil,pending=nil,hits=0,misses=0,attacks=0,
        lastResult="No attack",nextAttack=0,blocked=setmetatable({},{__mode="k"}),kills=0}
    function h:abandon(now,why)
        if self.target and self.target.model then
            self.blocked[self.target.model]=now+80
            if self.adapter.preyBlocked then self.adapter.preyBlocked[self.target.model]=now+80 end
        end
        self.target,self.pending=nil,nil
        self.lastBlockedReason=self.lastBlockedReason or self.lastResult
        self.blockedAt=now;self.abandonReason=why
        self.lastResult=why;self.nextSelect=now+.25
        self.adapter:stop(why)
    end
    function h:tick(s)
        local now=s.now
        if self.actorSeen and (self.actor~=s.char or self.generation~=s.generation) then
            self.target,self.pending,self.sample=nil,nil,nil
            self.nextAttack=0;self.nextSelect=nil;self.lastTargetHealth=nil;self.lastTargetMax=nil
            self.blocked=setmetatable({},{__mode="k"})
            self.adapter:stop("Hunt animal generation changed")
        end
        self.actorSeen=true;self.actor=s.char;self.generation=s.generation
        for model,untilAt in pairs(self.blocked) do if now>=untilAt then self.blocked[model]=nil end end
        if self.adapter.attackEvidence then self.inputEvidence=self.adapter:attackEvidence(s) end
        local prey=self.target
        -- A recycled model/Humanoid cannot contribute a death or HP result to
        -- the old prey transaction, even if its last Health happened to be zero.
        if prey and prey.hum and prey.model and type(prey.model.FindFirstChildOfClass)=="function"
            and prey.model:FindFirstChildOfClass("Humanoid")~=prey.hum then
            self.target,self.pending=nil,nil;prey=nil
            self.lastResult="Prey identity changed; resampling native target"
        end
        if prey and prey.hum and prey.hum.Health<=0 then
            self.kills+=1;self.lastResult="Observed NPC HP reached zero; attribution unverified"
            self.corpse={position=prey.position,at=now,model=prey.model}
            self.target,self.pending=nil,nil
            self.adapter:stop("prey down")
            return "PREY_DOWN",self.lastResult
        end
        if prey then prey=self.adapter:checkPrey(prey,s) end
        if not prey then
            self.target,self.pending=nil,nil
            if now<(self.nextSelect or 0) then return "HUNT_SEARCH",self.lastResult end
            prey=self.adapter:prey(s)
            if prey and prey.model and (self.blocked[prey.model] or 0)>now then prey=nil end
            if not prey then self.adapter:stop("no suitable NPC prey");return "WAIT_FOOD","No suitable safe NPC prey or edible food" end
            self.target=prey;self.started=now;self.bestDistance=distance(s.position,prey.position)
            self.closingAt=now;self.sample=nil;self.noDamageAt=nil;self.missesOnTarget=0
            self.lastTargetHealth=prey.health or prey.hum and prey.hum.Health
            self.lastTargetMax=prey.maxHealth or prey.hum and prey.hum.MaxHealth
            self.lastTargetHum=prey.hum
            self.lastUsefulAt=now;self.blockedSince=nil;self.nextAttack=now
            self.repositionUntil=nil;self.previousThrottle=nil;self.fullSpeed=nil;self.routeRetries=0;self.smoothVelocity=nil
        end
        self.target=prey
        local health=prey.health or prey.hum and prey.hum.Health
        local maximum=prey.maxHealth or prey.hum and prey.hum.MaxHealth
        local continuous=self.lastTargetHum==prey.hum
            and not (finite(maximum) and finite(self.lastTargetMax) and math.abs(maximum-self.lastTargetMax)>.001)
        if not continuous then
            self.pending=nil;self.lastTargetHealth=health;self.missesOnTarget=0
            self.noDamageAt=now;self.lastUsefulAt=now
            self.lastResult="Prey health identity/maximum changed; outcome window reset"
        end
        self.lastTargetHum=prey.hum;self.lastTargetMax=maximum
        if continuous and finite(health) and finite(self.lastTargetHealth) and health<self.lastTargetHealth-.01 then
            if self.adapter.huntOutcome then self.adapter:huntOutcome(self.lastTargetHealth-health) end
            self.lastUsefulAt=now;self.noDamageAt=now;self.closingAt=now
            self.missesOnTarget=0;self.routeRetries=0
        end
        self.lastTargetHealth=health
        if self.pending then
            local p=self.pending
            if finite(health) and health<p.health-.01 then
                self.hits+=1;self.noDamageAt=now;self.missesOnTarget=0
                self.lastResult="Observed prey HP decline after input; attribution unverified"
                self.pending=nil
            elseif now-p.at>(s.attackCooldown and math.clamp(s.attackCooldown*.75+(s.progressLatency or .5)+.5,1.1,3) or 1.1) then
                self.misses+=1;self.missesOnTarget+=1
                self.lastResult="No prey HP decline observed"
                self.lastBlockedReason=self.lastResult;self.lastBlockedAt=now
                self.pending=nil;self.repositionUntil=now+.55
            end
        end
        local d=distance(s.position,prey.position)
        if d<self.bestDistance-2 then self.bestDistance=d;self.closingAt=now;self.lastUsefulAt=now;self.routeRetries=0 end
        if d>390 or now-self.lastUsefulAt>60 or self.missesOnTarget>=5
            or now-self.closingAt>12 and d>28 or self.noDamageAt and now-self.noDamageAt>16 and d<28 then
            self:abandon(now,"Prey escaping, unreachable or attacks ineffective")
            return "HUNT_REPLAN",self.lastResult
        end
        local velocity=prey.velocity or {x=0,z=0}
        if self.sample and now>self.sample.at and now-self.sample.at<2 and not prey.velocity then
            velocity={x=(prey.position.x-self.sample.position.x)/(now-self.sample.at),
                z=(prey.position.z-self.sample.position.z)/(now-self.sample.at)}
        end
        local speed=math.sqrt(velocity.x^2+velocity.z^2)
        if speed>100 then velocity={x=0,z=0};speed=0 end
        if self.smoothVelocity then
            velocity={x=self.smoothVelocity.x*.55+velocity.x*.45,z=self.smoothVelocity.z*.55+velocity.z*.45}
            speed=math.sqrt(velocity.x^2+velocity.z^2)
        end
        self.smoothVelocity=velocity
        self.sample={position={x=prey.position.x,z=prey.position.z},at=now}
        local lead=math.clamp(d/math.max(20,(s.travelSpeed or 35)+speed),.08,.85)
        local geometry=type(self.adapter.attackGeometry)=="function" and self.adapter:attackGeometry(s,prey) or nil
        local valid=geometry and geometry.valid
        self.geometry=geometry
        if not valid then
            self.lastBlockedReason=geometry and geometry.reason or "Native bite geometry unavailable"
            self.lastBlockedAt=now
            self.lastResult=self.lastBlockedReason
        end
        if not valid then self.blockedSince=nil end
        local heading=speed>1 and {x=velocity.x/speed,z=velocity.z/speed} or prey.forward
        local standoff=math.clamp((prey.attackRange or 7)*.65,2.4,8)
        local target={x=prey.position.x+velocity.x*lead,z=prey.position.z+velocity.z*lead}
        if heading then
            target.x-=heading.x*standoff;target.z-=heading.z*standoff
        end
        local following=speed>1 and d<standoff+10 and geometry and geometry.inRange
        local scale=1
        if following then
            local nav=self.adapter.nav
            local observed=nav and nav.speed
            local previous=self.previousThrottle or 1
            if observed and observed>2 then self.fullSpeed=(self.fullSpeed or observed)*.7+(observed/math.max(previous,.2))*.3 end
            if self.fullSpeed and self.fullSpeed>2 then
                scale=math.clamp((speed+(d-standoff)*1.8)/self.fullSpeed,.15,1)
            end
        end
        self.previousThrottle=scale
        -- Keep pursuing while verifying a previous bite; a coarse range check
        -- must never freeze a hunter while its prey runs out of range.
        if valid and now>=self.nextAttack and not self.pending and now>=(self.repositionUntil or 0) then
            local sent,why=self.adapter:bite(s,prey)
            if self.adapter.attackEvidence then self.inputEvidence=self.adapter:attackEvidence(s) end
            self.lastResult=why or (sent and "Attack requested; awaiting prey HP" or "Native attack not ready")
            self.nextAttack=now+(sent and (s.attackCooldown or .9) or .25)
            if sent then self.blockedSince=nil;self.noDamageAt=self.noDamageAt or now
            else self.blockedSince=self.blockedSince or now;self.lastBlockedReason=self.lastResult;self.lastBlockedAt=now end
            if sent and finite(health) then
                self.attacks+=1;self.pending={at=now,health=health,maxHealth=maximum,hum=prey.hum,model=prey.model}
            end
        end
        if self.blockedSince and now-self.blockedSince>12 then
            self:abandon(now,"Native attack unavailable: "..tostring(self.lastResult))
            return "HUNT_REPLAN",self.lastResult
        end
        if valid and speed<2 and not self.repositionUntil then
            self.adapter:stop("valid stationary attack position")
        else
            if geometry and geometry.inRange and geometry.facing==false and geometry.clear~=false then
                -- Walking toward a parking point behind prey can end with our
                -- animal facing away and no remaining movement. Approach the
                -- prey itself until native movement turns us toward it.
                target={x=prey.position.x,z=prey.position.z}
            elseif geometry and geometry.inRange and not valid or now<(self.repositionUntil or 0) then
                local dx,dz=prey.position.x-s.position.x,prey.position.z-s.position.z
                local len=math.max(1,math.sqrt(dx*dx+dz*dz))
                local side=(self.missesOnTarget%2==0) and 1 or -1
                if heading then
                    target={x=prey.position.x-heading.x*standoff-heading.z*side*2,
                        z=prey.position.z-heading.z*standoff+heading.x*side*2}
                else
                    target={x=prey.position.x+dx/len*2-dz/len*side*2,
                        z=prey.position.z+dz/len*2+dx/len*side*2}
                end
            end
            local result=self.adapter:move(target,s,{navKey=prey.model or "NPC_HUNT",
                movingTarget=true,hunting=true,following=following,moveScale=scale,preySpeed=speed,moveRadius=.9})
            if result=="STUCK" or result=="BLOCKED" then
                self.routeRetries=(self.routeRetries or 0)+1
                self.adapter:stop("Retrying approach to committed prey")
                if self.routeRetries>=3 then
                    self:abandon(now,"NPC pursuit route failed repeatedly")
                    return "HUNT_REPLAN",self.lastResult
                end
            end
        end
        if self.repositionUntil and now>=self.repositionUntil then self.repositionUntil=nil end
        self.distance=d;self.preySpeed=speed
        return self.pending and "HUNT_VERIFY" or valid and "HUNT_ATTACK" or "HUNT_APPROACH",self.lastResult
    end
    function h:resume(delay)
        -- Manual intervention pauses a hunt; it does not blacklist its prey.
        for _,key in ipairs({"started","closingAt","noDamageAt","lastUsefulAt","blockedSince"}) do
            if self[key] then self[key]+=delay end
        end
        self.pending=nil;self.sample=nil;self.nextAttack=0;self.lastTargetHealth=nil
    end
    function h:status()
        return {attacks=self.attacks,hpDeclines=self.hits,misses=self.misses,
            result=self.lastResult,distance=self.distance,preySpeed=self.preySpeed,
            active=self.target~=nil,killsObserved=self.kills,blockedSince=self.blockedSince,
            committedSince=self.started,lastUsefulAt=self.lastUsefulAt,abandonReason=self.abandonReason,
            geometry=self.geometry,lastBlockedReason=self.lastBlockedReason,lastBlockedAt=self.lastBlockedAt,inputEvidence=self.inputEvidence}
    end
    return h
end
return Hunt
]============]
sources["care"] = [============[
-- Feeding handshake and recovery. Native approach, active feeding and an input
-- request have distinct lifetimes; manual cancellation never leaves a stale latch.
local Care={}
local function finite(n)return type(n)=="number" and n==n and math.abs(n)<1e10 end
local function active(s,kind)
    return s.nativeFeedMode==kind or s.feedMode==kind or s.feedMode==true
end
local function meal(g,now)
    if not g.meal then g.meal={requests=0,at=now,progressAt=now} end
    return g.meal
end
function Care.interrupt(g,now)
    if not g or g.kind~="EAT" and g.kind~="DRINK" then return end
    local m=meal(g,now)
    m.interrupted=true;m.interruptedAt=now
end
function Care.requested(g,now)
    local m=meal(g,now)
    m.requests+=1;m.at=now;m.pending=true;m.owned=true
    m.interrupted=false;m.seenActive=false;m.progressAt=now
    g.feedPending=true;g.feedAt=now
end
function Care.resetSite(g,now)
    g.meal={requests=0,at=now,progressAt=now};g.feedPending=nil
    g.feedAt=nil;g.nextAction=now+.2;g.stopFeedRequested=nil
end
function Care.step(g,s,adapter)
    local now=s.now;local m=meal(g,now)
    local kind=g.kind=="DRINK" and "drink" or "eat"
    local value=kind=="drink" and s.thirst or s.hunger
    if not finite(value) or not finite(g.baseline) then return "FAILED","Native needs unavailable" end
    local maximum=kind=="drink" and (s.thirstMax or 100) or (s.hungerMax or 100)
    if not finite(maximum) or maximum<=0 then return "FAILED","Native need maximum unavailable" end
    if value<0 or value>maximum*1.05 then return "FAILED","Native need value outside its maximum" end
    if g.needMaximum and g.needMaximum~=maximum then
        -- A schema/species maximum change is not nutrition gained. Establish a
        -- new same-maximum window and keep watching the actual native session.
        g.baseline=value;m.value=value;m.progressAt=now
    end
    g.needMaximum=maximum
    g.gain=value-g.baseline
    if m.value and value>m.value+.02 then m.progressAt=now;m.requests=0 end
    m.value=value
    local running=active(s,kind)
    local other=s.nativeFeedMode and s.nativeFeedMode~=kind
        or s.feedMode and s.feedMode~=false and s.feedMode~=kind and s.feedMode~=true
    if other then return "BUSY","Another native feeding session owns movement" end
    local idleKnown=s.nativeFeedKnown==true and s.nativeFeedMode==nil and not running
    if running then m.seenActive=true;m.interrupted=false end
    if m.interrupted and not running and now-(m.interruptedAt or now)>=.35
        and (idleKnown or now-(m.interruptedAt or now)>=1.1) then
        m.pending=false;m.interrupted=false;m.cancelAt=nil;m.requests=0
        g.feedPending=nil;g.feedAt=nil;g.arrivedAt=nil;g.stopFeedRequested=nil
        g.nextAction=now
    elseif m.pending and m.seenActive and not running then
        -- The native session ended below the care target: continue the same
        -- objective immediately, instead of waiting for a 14-second timeout.
        m.pending=false;m.seenActive=false;m.cancelAt=nil;g.feedPending=nil;g.nextAction=now+.2
    elseif m.pending and not running and now-m.at>=(idleKnown and .75 or 2.2) then
        m.pending=false;g.feedPending=nil;g.nextAction=now+.2
        if m.requests>=3 then return "RELOCATE","Native feed request was not acknowledged" end
    end
    local target=kind=="drink" and math.min(s.drinkTarget or maximum,maximum)-maximum*.002 or math.min(s.careTarget or maximum*.72,maximum)
    if not finite(target) or target<=0 then return "FAILED","Native care target unavailable" end
    if value>=target and g.gain>math.min(.25,maximum*.002) then
        if running then
            m.fullAt=m.fullAt or now
            if m.owned and not m.cancelAt and adapter.cancelFeed then
                if adapter:cancelFeed(s) then m.cancelAt=now end
            end
            if m.owned and now-(m.cancelAt or m.fullAt)>2 then
                return "FAILED","Thirst or hunger recovered; native feeding release unconfirmed"
            end
            return "BUSY","Needs recovered; finishing native feeding"
        end
        return "COMPLETE",(kind=="drink" and "Thirst" or "Hunger").." actually increased"
    end
    if m.cancelAt then
        if not running and (idleKnown or now-m.cancelAt>.5) then
            m.pending=false;g.feedPending=nil;return "RELOCATE","Trying a fresh feed access"
        end
        if now-m.cancelAt>2 then return "FAILED","Native feeding cancellation unconfirmed" end
        return "BUSY","Releasing a stalled native feeding session"
    end
    if running and now-m.progressAt>5.5 then
        if m.owned and adapter.cancelFeed and adapter:cancelFeed(s) then
            m.cancelAt=now;return "BUSY","Restarting feeding after no resource progress"
        end
        if now-m.progressAt>8 then return "FAILED","Native feeding has no resource progress" end
    end
    if running then return "BUSY","Native feeding active; watching needs" end
    if m.pending then return "BUSY","Native feeding approach requested" end
    return "READY","Finding native "..kind.." access"
end
return Care
]============]
sources["agent"] = [============[
-- One objective and one movement owner, with suspended territory and care latches.
local Agent={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e10 end
local function flat(a,b)
    if not a or not b then return math.huge end
    return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)
end
local function feeding(s,kind)
    return s.feedMode==kind or s.feedMode==true or s.nativeFeedMode==kind
end
function Agent.new(planner,adapter,Hunt,Care,Ledger)
    local a={planner=planner,adapter=adapter,Hunt=Hunt,Care=Care,enabled=false,phase="OFF",goal=nil,
        cooldown={},careCooldown={},recent={},waitingSince={},events={},ticks=0,earned=0,claimed=0,scented=0,
        feeds=0,hunts=0,failures=0,nextTick=0,reason="Disabled",generation=0,returns={},version="0.8.0"}
    a.metrics=Ledger and Ledger.new() or nil
    function a:planningOptions(extra)
        local options={blockedUntil=self.cooldown,waitingSince=self.waitingSince,
            maintenanceOnly=self.capacity and self.capacity.maintenanceOnly,retainOwned=self.capacity and self.capacity.retainOwned}
        for key,value in pairs(extra or {}) do options[key]=value end
        return options
    end
    function a:updateCapacity(hexes,state)
        if not self.planner.capacity then return end
        local care,active=0,self.metrics and self.metrics.active or 0
        for phase,seconds in pairs(self.metrics and self.metrics.phases or {}) do
            if phase:find("FOOD",1,true) or phase:find("WATER",1,true) or phase:find("HUNT",1,true)
                or phase=="DRINKING" or phase=="EATING" or phase=="RECOVER" or phase=="FEED_APPROACH" then care+=seconds end
        end
        self.capacity=self.planner.capacity(hexes,state,{blockedUntil=self.cooldown,
            careFraction=active>30 and math.clamp(care/active,0,.75) or 0})
    end
    function a:selectTerritory(state,force)
        local hexes=self.adapter:territories(state)
        local byKey={}
        for _,hex in ipairs(hexes) do
            byKey[hex.key]=hex
            if self.planner.objective(hex,state,state.position,{blockedUntil=self.cooldown}) then self.waitingSince[hex.key]=self.waitingSince[hex.key] or state.now
            else self.waitingSince[hex.key]=nil end
        end
        self:updateCapacity(hexes,state)
        local options=self:planningOptions({recent=self.recent,maxStops=6,
            regionCursor=self.regionCursor,regionDirection=self.regionDirection})
        if not force and self.itinerary then
            while #self.itinerary>0 do
                local item=self.itinerary[1]
                local fresh=self.planner.objective(byKey[item.key],state,state.position,options)
                if fresh then self.itinerary[1]=fresh;return self.itinerary,self.strategy end
                table.remove(self.itinerary,1)
            end
        end
        local route,strategy=self.planner.strategy(hexes,state,options)
        self.itinerary=route;self.strategy=strategy;self.regionCursor=strategy.cursor;self.regionDirection=strategy.direction or self.regionDirection
        return route,strategy
    end
    function a:log(at,kind,msg)
        table.insert(self.events,{at=math.floor(at*10)/10,kind=kind,msg=msg})
        if kind=="confirmed" or kind=="deferred" or kind=="failed" then self.lastNotice=msg end
        while #self.events>35 do table.remove(self.events,1) end
    end
    function a:setEnabled(on,now)
        local desired=on==true
        if self.enabled==desired then return end
        now=now or self.lastState and self.lastState.now or os.clock()
        local ownedFeed=self.enabled and self.goal and self.goal.meal and self.goal.meal.owned
        self.generation+=1;self.enabled=desired
        if not self.enabled then
            if self.metrics and self.metrics.run then self.metrics:sample(now or self.lastState and self.lastState.now or self.metrics.at,self.phase,self.phase=="PAUSED",false,self.goal,self.lastState,self.adapter.nav) end
            if self.adapter.recover then self.adapter:recover(self.lastState,false) end
            self.goal,self.suspended=nil,nil;self.returns={};self.itinerary=nil;self.phase="OFF";self.reason="Disabled"
            self.adapter:stop("disabled")
            if self.adapter.releaseInputs then self.adapter:releaseInputs() end
            if ownedFeed and self.lastState then
                if self.adapter.cancelFeed then self.adapter:cancelFeed(self.lastState) end
            end
        else
            self.nextTick=0;self.prevAmber=nil;self.needWindow={};self.needRates={};self.depletionProfiles={}
            self.capacity=nil;self.nextCapacityAt=0;self.nextPlanAt=0;self.nextUrgentCheck=0;self.pausedAt=nil
            self.itinerary=nil;self.regionCursor=nil;self.regionDirection=nil;self.earned=0;self.claimed=0;self.scented=0
            self.feeds,self.hunts,self.failures=0,0,0
            if self.metrics then self.metrics:start(now) end
            self.reason="Assessing animal and territory"
        end
    end
    function a:suspend(goal)
        if not goal or self.suspended==goal then return end
        if self.suspended then
            table.insert(self.returns,self.suspended)
            if #self.returns>3 then table.remove(self.returns,1) end
        end
        self.suspended=goal
    end
    function a:fail(state,reason)
        self.failures+=1;self.reason=reason
        if self.metrics then self.metrics:count("failure",reason) end
        if self.adapter.recover then self.adapter:recover(state,false) end
        local g=self.goal
        if g and g.meal and g.meal.owned and not g.meal.cancelAt and not g.emergencyStopAt and self.adapter.cancelFeed then
            if self.adapter:cancelFeed(state) then g.meal.cancelAt=state.now end
        end
        if self.adapter.releaseInputs then self.adapter:releaseInputs() end
        if g and g.kind=="TERRITORY" then self.cooldown[g.key]=state.now+90
        elseif g then self.careCooldown[g.kind]=state.now+2 end
        if g and g.kind=="DRINK" and self.adapter.avoidWater then self.adapter:avoidWater(g.location,state.now) end
        if g and g.food and g.food.model and self.adapter.foodBlocked then self.adapter.foodBlocked[g.food.model]=state.now+80 end
        self:log(state.now,"failed",reason);self.goal=nil
        self.adapter:stop(reason);self.phase="REPLAN"
    end
    function a:takeGoal(state,kind,target)
        self.adapter:stop("new goal")
        if kind~="RECOVER" and self.adapter.recover then self.adapter:recover(state,false) end
        self.objectiveSerial=(self.objectiveSerial or 0)+1
        self.goal={id=self.objectiveSerial,generation=self.generation,wallStart=state.now,
            kind=kind,key=target and target.key,detail=target,start=state.now,
            nextAction=0,tries=0,progressAt=state.now,
            baseline=kind=="DRINK" and state.thirst or kind=="EAT" and state.hunger or nil,
            needMaximum=kind=="DRINK" and state.thirstMax or kind=="EAT" and state.hungerMax or nil}
        self.phase="PREPARE_"..kind;self.reason="Starting "..kind
        self:log(state.now,"goal",kind..":"..tostring(target and target.key or "-"))
    end
    function a:resume(state)
        self.adapter:stop("care confirmed")
        if self.adapter.recover then self.adapter:recover(state,false) end
        local g=self.suspended;self.suspended=table.remove(self.returns)
        if g and g.kind=="TERRITORY" then
            local current=self.adapter:territory(g.key,state)
            local detail=current and self.planner.objective(current,state,state.position,self:planningOptions())
            if detail then
                if state.travelCost then
                    local route,strategy=self.planner.strategy(self.adapter:territories(state),state,self:planningOptions({regionCursor=self.regionCursor,maxStops=1}))
                    local alternate=route[1]
                    if alternate and alternate.key~=g.key and (strategy.phase=="URGENT_SCENT"
                        or alternate.score>detail.score*1.8 and alternate.travelSeconds<detail.travelSeconds*.55) then
                        self.itinerary=nil;self.goal=nil;self.reason="Replanning after care changed the useful route"
                        return
                    end
                end
                g.start=state.now;g.progressAt=state.now;g.interactAt=nil
                g.detail=detail;g.finishUntil=nil;g.completeAt=nil;g.inHexProgressAt=nil
                self.goal=g;self.phase="RESUME";self.reason="Resuming "..g.key
                return
            end
        end
        self.goal=nil
        if self.suspended then self:resume(state) end
    end
    function a:status()
        local s=self.lastState or {}
        local g=self.goal
        return {metrics=self.metrics and self.metrics:summary(),capacity=self.capacity,decision=self.decision,version=self.version,enabled=self.enabled,phase=self.phase,reason=self.reason,
            kind=g and g.kind or "NONE",key=g and g.key,claimed=self.claimed,scented=self.scented,
            feeds=self.feeds,hunts=self.hunts,failures=self.failures,earned=self.earned,
            species=self.species,coat=self.coat,hunger=s.hunger,thirst=s.thirst,
            suspended=self.suspended and self.suspended.key,lastSuccess=self.lastSuccess,
            targetProgress=g and {action=g.detail and g.detail.kind,progress=g.lastProg,hold=g.lastHold,alternates=g.alternates,
                needBaseline=g.baseline,needGain=g.gain},hunt=g and g.hunt and g.hunt:status() or nil,
            lastHunt=self.lastHunt,returnDepth=#self.returns+(self.suspended and 1 or 0),
            survivalReserve={hunger=s.hungerReserve,thirst=s.thirstReserve},lastCare=self.lastCare,lastRouteFailure=self.lastRouteFailure,
            input=self.adapter.lastInput,error=self.lastError,strategy=self.strategy,deferred=self.deferred or 0,
            lastSkip=self.lastSkip,lastNotice=self.lastNotice,travelled=self.adapter.nav and self.adapter.nav.travelled,
            waitSeconds=self.goal and self.goal.interactAt and s.now-self.goal.interactAt or 0}
    end
    function a:pause(state,reason)
        self.pausedAt=self.pausedAt or state.now
        self.pauseManual=state.manualInput==true or state.gameMenu==true
        if self.Care then self.Care.interrupt(self.goal,state.now) end
        self.phase="PAUSED";self.reason=reason;self.adapter:stop(reason)
    end
    function a:tick(now)
        if not self.enabled or now<self.nextTick then return end
        self.nextTick=now+.15;self.ticks+=1
        if self.metrics then
            if not self.metrics.run then self.metrics:start(now) elseif not self.metrics.at then self.metrics.at=now;self.metrics.started=now end
            self.metrics:sample(now,self.phase,self.phase=="PAUSED" or self.phase=="WAIT",self.phase=="PAUSED" and self.pauseManual,self.goal,self.lastState,self.adapter.nav)
        end
        if not self.metrics and self.goal and self.phaseAt and self.phaseGoal==self.goal then
            self.goal.durations=self.goal.durations or {}
            self.goal.durations[self.phase]=(self.goal.durations[self.phase] or 0)+math.clamp(now-self.phaseAt,0,2)
        end
        self.phaseAt=now;self.phaseGoal=self.goal
        if self.adapter.prepare then self.adapter:prepare(now,true,self.goal) end
        local state=self.adapter:snapshot(now)
        if not state or not state.alive or not state.position then
            self.phase="WAIT";self.reason="Living animal unavailable"
            self.goal,self.suspended=nil,nil;self.returns={};self.itinerary=nil
            if self.adapter.recover then self.adapter:recover(state,false) end
            self.adapter:stop("despawn");if self.adapter.releaseInputs then self.adapter:releaseInputs() end;return
        end
        state.now=now;self.lastState=state;self.species,self.coat=state.species,state.coat
        local changed=self.initialized and (self.lastCharacter~=state.char or self.lastPack~=state.pack
            or self.lastBiome~=state.biome or self.lastSpecies~=state.species or self.lastProfile~=state.profileKey
            or self.lastGeneration~=state.generation)
        if changed then
            self.goal,self.suspended=nil,nil;self.returns={};self.cooldown,self.recent,self.careCooldown={},{},{}
            self.waitingSince={};self.regionCursor=nil;self.regionDirection=nil;self.itinerary=nil
            self.needWindow={};self.needRates={};self.depletionProfiles={}
            self.prevAmber=nil;self.capacity=nil;self.nextCapacityAt=0;self.nextPlanAt=0;self.nextUrgentCheck=0
            if self.adapter.releaseInputs then self.adapter:releaseInputs() end
            if self.adapter.recover then self.adapter:recover(state,false) end
            self.adapter:stop("animal / pack / map changed")
            self.lastTerritoryKey=nil;self.pausedAt=nil
            self:log(now,"reset","Changed animal, pack or map")
        end
        self.initialized=true
        self.lastCharacter,self.lastPack,self.lastBiome,self.lastSpecies,self.lastProfile=state.char,state.pack,state.biome,state.species,state.profileKey
        self.lastGeneration=state.generation
        self.needRates=self.needRates or {}
        self.needWindow=self.needWindow or {}
        for _,key in ipairs({"hunger","thirst"}) do
            local sample,value=self.needWindow[key],state[key]
            if not finite(value) then self.needWindow[key]=nil
            elseif not sample or sample.char~=state.char or value>sample.value+.02 or now-sample.at>15 then
                self.needWindow[key]={char=state.char,at=now,value=value,mode=state.swimming and "swim" or state.hudBurst and "burst" or state.hudSprint and "sprint" or "ordinary"}
            elseif now-sample.at>=4 then
                -- Include idle samples between replicated resource updates;
                -- averaging only falling ticks exaggerates consumption.
                local rate=(sample.value-value)/(now-sample.at)
                if rate>=0 and rate<((state[key.."Max"] or 100)*.05) then
                    self.needRates[key]=(self.needRates[key] or rate)*.6+rate*.4
                    self.depletionProfiles=self.depletionProfiles or {}
                    self.depletionProfiles[key]=self.depletionProfiles[key] or {}
                    local modes=self.depletionProfiles[key];local mode=sample.mode or "ordinary"
                    modes[mode]={rate=rate,at=now}
                end
                self.needWindow[key]={char=state.char,at=now,value=value,mode=state.swimming and "swim" or state.hudBurst and "burst" or state.hudSprint and "sprint" or "ordinary"}
            end
        end
        for _,key in ipairs({"hunger","thirst"}) do
            local rate=self.needRates[key]
            for _,v in pairs(self.depletionProfiles and self.depletionProfiles[key] or {}) do
                if now-v.at<90 then rate=math.max(rate or 0,v.rate*.7) end
            end
            if finite(state[key]) and rate and rate>.001 then state[key.."Reserve"]=math.max(0,state[key]-(state[key.."Max"] or 100)*.12)/rate end
        end
        if self.metrics then self.metrics:currency(state.amber,state.char) end
        if self.planner.capacity and now>=(self.nextCapacityAt or 0) then
            self.nextCapacityAt=now+10
            self:updateCapacity(self.adapter:territories(state),state)
        end
        if finite(state.amber) then
            if finite(self.prevAmber) and state.amber>self.prevAmber then self.earned+=state.amber-self.prevAmber end
            self.prevAmber=state.amber
        end
        if state.manualInput or state.gameMenu then
            if self.goal then self.goal.manualInterventionObserved=true end
            self:pause(state,"Manual movement, typing or native menu");return
        end
        local ownRecovery=self.goal and self.goal.kind=="RECOVER" and state.automaticRest==true
        if state.ability or state.pinned or state.resting and not ownRecovery or state.flying or state.climbing or state.rescuing then
            self:pause(state,"Native ability, capture, Rest, flight or climbing");return
        end
        if (feeding(state,"eat") or feeding(state,"drink")) and (not self.goal or self.goal.kind=="TERRITORY") then
            self:pause(state,"Native feeding owns movement");return
        end
        if state.underwater then self:pause(state,"Underwater route requires manual surface recovery");return end
        if state.combatKnown==false then self:pause(state,"Native combat timing unavailable");return end
        if state.combat and (not self.goal or self.goal.kind~="EAT") then self:pause(state,"Combat interruption");return end
        if self.pausedAt then
            if self.goal then
                local delay=now-self.pausedAt
                self.goal.start+=delay;self.goal.progressAt+=delay
                if self.goal.interactAt then self.goal.interactAt+=delay end
                if self.goal.hunt and self.goal.hunt.resume then self.goal.hunt:resume(delay) end
            end
            self.pausedAt=nil
        end
        state.recoveryStalled=self.goal and self.goal.kind=="RECOVER" and now-(self.goal.recoverProgressAt or self.goal.start)>20
        local decision=self.planner.decide and self.planner.decide(state) or {kind=self.planner.need(state)}
        self.decision=decision
        local need=decision.kind
        if need=="WAIT" then self:pause(state,decision.reason or "Native needs unavailable");return end
        if not self.goal and self.suspended and need=="TERRITORY" then self:resume(state) end
        local goal=self.goal
        if goal and goal.kind=="TERRITORY" and not goal.nativeStarted and self.capacity and self.capacity.maintenanceOnly
            and (goal.detail.kind=="CLAIM" or self.capacity.retainOwned and not self.capacity.retainOwned[goal.key]) then
            self.goal=nil;self.itinerary=nil;goal=nil
            self.adapter:stop("Maintenance workload displaced optional acquisition")
        end
        if goal and goal.kind=="TERRITORY" and state.contested and state.contested[goal.key] then
            self.cooldown[goal.key]=now+15
            self.lastSkip="Non-pack player occupies "..goal.key
            self.deferred=(self.deferred or 0)+1
            self:log(now,"deferred",self.lastSkip)
            self.goal=nil;goal=nil
        end
        if self.suspended and state.contested and state.contested[self.suspended.key] then
            self.suspended=table.remove(self.returns)
        end
        local opportunistic=(not goal or goal.kind=="TERRITORY") and state.feedCan=="drink"
            and finite(state.thirst) and state.thirst<(state.thirstMax or 100)*.82
            and now-(self.lastFullDrinkAt or -100)>90
        if opportunistic and state.healthFraction>=.45 then need="DRINK" end
        -- Finish a progressing near-complete claim before routine care. A
        -- critical need, genuine contest or native interruption still wins.
        local protected=false
        if goal and goal.kind=="TERRITORY" and need~="TERRITORY" and not decision.critical then
            local t=self.adapter:territory(goal.key,state)
            local p=t and (goal.detail.kind=="SCENT" and t.hold or t.prog)
            if type(p)=="number" and p>=.72 and p<=1 and state.healthFraction>=.45
                and (state.hunger or 100)>(state.hungerMax or 100)*.19 and (state.thirst or 100)>(state.thirstMax or 100)*.19 then
                goal.finishUntil=goal.finishUntil or now+math.clamp((goal.detail.kind=="SCENT" and (state.refillTime or 60) or (state.claimTime or 20))*(1-p)+2,2,18)
                protected=now<goal.finishUntil and now-goal.progressAt<3
            end
        end
        if protected then need="TERRITORY" end
        -- Re-evaluate urgent scent during travel, without abandoning active or
        -- nearly finished work. Preserve the region cursor and return target.
        if goal and goal.kind=="TERRITORY" and need=="TERRITORY" and not self.suspended
            and not goal.nativeStarted and now>=(self.nextUrgentCheck or 0) then
            self.nextUrgentCheck=now+1
            local current=self.adapter:territory(goal.key,state)
            local almostDone=current and current.by==state.pack and finite(current.prog) and current.prog>=.72
            local urgentGoal=goal.detail.kind=="SCENT" and current and (finite(current.hold) and current.hold<.28 or goal.detail.slack and goal.detail.slack<45)
            local completed=current and (goal.detail.kind=="CLAIM" and current.owner==state.pack
                or goal.detail.kind=="SCENT" and current.hold and current.hold>=.985)
            if not completed and not almostDone and not urgentGoal and flat(state.position,goal.detail.center)>(state.claimRadius or 15) then
                local route,strategy=self.planner.strategy(self.adapter:territories(state),state,
                    self:planningOptions({regionCursor=self.regionCursor,maxStops=1}))
                if strategy.phase=="URGENT_SCENT" and route[1] and route[1].key~=goal.key then
                    self:suspend(goal);self.strategy=strategy
                    self:takeGoal(state,"TERRITORY",route[1]);goal=self.goal
                    self.reason="Maintaining critical scent before resuming the area sweep"
                end
            end
        end
        -- Care is latched to its completion target. Crossing its trigger does
        -- not cancel a native feeding session or lose the suspended territory.
        if goal and goal.kind=="RECOVER" and state.healthFraction>=.72 then
            self:resume(state);goal=self.goal
        end
        local urgent=decision.critical and decision.kind or nil
        -- A latched meal cannot ignore a different need becoming lethal.
        -- Cancel only our own native feeding session and wait for its release.
        local emergency=goal and (goal.kind=="EAT" or goal.kind=="DRINK") and urgent and urgent~=goal.kind
            and (urgent=="RECOVER" or urgent=="DRINK" and state.thirst<(state.thirstMax or 100)*.10
                or urgent=="EAT" and state.hunger<(state.hungerMax or 100)*.10) and urgent
        if emergency and goal.meal and goal.meal.owned then
            goal.emergencySince=goal.emergencySince or now
            if not feeding(state,"eat") and not feeding(state,"drink")
                and (state.nativeFeedKnown==true and not state.nativeFeedMode
                    or goal.emergencyStopAt and now-goal.emergencyStopAt>.75) then
                self:takeGoal(state,emergency);goal=self.goal;urgent=emergency;need=emergency
            else
                if not goal.emergencyStopAt and self.adapter.cancelFeed and self.adapter:cancelFeed(state) then
                    goal.emergencyStopAt=now
                end
                self.adapter:stop("Critical survival handoff")
                self.phase="VERIFY_FEED_RELEASE";self.reason="Releasing owned feeding for critical "..emergency
                if now-goal.emergencySince>3 then self:fail(state,"Critical feeding release unconfirmed") end
                return
            end
        end
        local switch=not goal or goal.kind=="TERRITORY" and need~="TERRITORY"
            or urgent and goal.kind~=urgent and not goal.feedPending and not feeding(state,"eat") and not feeding(state,"drink")
        if switch and need~="TERRITORY" and need~="WAIT" then
            local kind=urgent or need
            if (self.careCooldown[kind] or 0)>now then
                self.phase="WAIT_CARE";self.reason="Retrying another survival location shortly"
                self.adapter:stop("care retry cooldown");return
            end
            if goal and goal.kind=="TERRITORY" then self:suspend(goal) end
            self:takeGoal(state,kind);goal=self.goal
        end
        if not goal then
            if state.pack==nil then
                self.phase="WAIT";self.reason="Join a pack to claim or scent territory";self.adapter:stop("no pack");return
            end
            if now<(self.nextPlanAt or 0) then
                self.phase="WATCH";self.reason="Watching native scent and survival";self.adapter:stop("maintenance watch");return
            end
            local route,strategy=self:selectTerritory(state)
            if #route==0 then
                self.nextPlanAt=now+.8
                local exposed=state.currentHex and state.contested and state.contested[state.currentHex]
                local patrol=exposed and self.adapter.patrol and self.adapter:patrol(state)
                if patrol then
                    self.phase="PATROL";self.reason="Territories maintained; checking the next area"
                    self.adapter:move(patrol,state,{navKey="PATROL:"..tostring(patrol.key),moveRadius=12})
                else
                    self.phase="WATCH";self.reason=self.capacity and self.capacity.maintenanceOnly and self.capacity.policy or "Territories maintained or deferred; watching native scent and survival"
                    self.adapter:stop("no available target")
                end
                return
            end
            self:takeGoal(state,"TERRITORY",route[1]);goal=self.goal
            self.lastTerritoryKey=goal.key
        end
        if goal.kind=="RECOVER" then
            local available=self.adapter.recover and self.adapter:recover(state,true)
            if not goal.recoverHP or state.healthFraction>goal.recoverHP+.001 then
                goal.recoverHP=state.healthFraction;goal.recoverProgressAt=now
            end
            self.phase="RECOVER";self.reason="Watching native out-of-combat HP recovery"
            if now-(goal.recoverProgressAt or goal.start)>20 then
                self.phase="WAIT_RECOVERY"
                self.reason=state.combat and "Recovery waits for native combat eligibility"
                    or "Recovery has no observed HP gain; rechecking native eligibility"
                goal.recoverChecks=(goal.recoverChecks or 0)+1
            end
            self.adapter:stop("low health");return
        end
        if goal.kind=="TERRITORY" then
            if state.pack==nil then self:fail(state,"Pack unavailable");return end
            local native=self.adapter:territory(goal.key,state)
            if not native or native.neutral then self:fail(state,"Territory missing or neutral");return end
            local owned=native.owner==state.pack
            local pendingClaim=owned and native.by==state.pack and finite(native.prog) and native.prog>.01 and native.prog<.995
            local done=goal.detail.kind=="CLAIM" and owned and not pendingClaim
                or goal.detail.kind=="SCENT" and owned and finite(native.hold) and native.hold>=.985
            if done then
                goal.completeAt=goal.completeAt or now
                -- Require the replicated completion to survive another native
                -- sample before departure. Ownership is not fabricated locally.
                if now-goal.completeAt<.45 then
                    self.adapter:stop("verifying territory completion")
                    self.phase="VERIFY_TERRITORY";self.reason="Checking stable native territory completion";return
                end
                if goal.detail.kind=="SCENT" then self.scented+=1 else self.claimed+=1 end
                if self.metrics then self.metrics:count("outcome",goal.nativeStarted and "local territory progress completed" or "pack territory completion observed") end
                self.recent[goal.key]=now;self.lastSuccess="Observed "..goal.detail.kind.." "..goal.key
                self.waitingSince[goal.key]=nil
                self:log(now,"confirmed",self.lastSuccess);self.adapter:stop("replicated complete")
                self.goal=nil;self.phase="CONFIRMED";self.reason=self.lastSuccess
                if self.suspended then self:resume(state) end
                return
            end
            goal.completeAt=nil
            local waypoint=self.adapter:territorySpot(goal.key,state)
            if not waypoint then self:fail(state,"No streamed native territory position");return end
            local progressing=finite(native.prog) and native.by==state.pack and finite(goal.lastProg) and native.prog>goal.lastProg+.002
                or owned and finite(native.hold) and finite(goal.lastHold) and native.hold>goal.lastHold+.002
            if progressing then goal.progressAt=now;goal.nativeStarted=true end
            goal.lastProg,goal.lastHold=native.prog,native.hold
            local inHex=state.currentHex==goal.key or not state.currentHex and flat(state.position,waypoint)<=(state.claimRadius or 15)
            if progressing and inHex then goal.inHexProgressAt=now end
            -- Replication arrives less often than this coordinator ticks. Stay
            -- put between progressing samples rather than restarting travel.
            local localProgress=inHex and (owned or native.by==state.pack)
                and goal.inHexProgressAt and now-goal.inHexProgressAt<2.5
            local outsideHex=state.currentHex~=nil and state.currentHex~=goal.key
            if outsideHex or flat(state.position,waypoint)>(waypoint.moveRadius or state.claimRadius or 15) and not localProgress then
                self.phase="TRAVEL";self.reason=goal.detail.kind.." "..goal.key
                local result=self.adapter:move(waypoint,state,{navKey="HEX:"..goal.key,costPurpose="HEX:"..goal.key,costPoint=goal.detail.center,moveRadius=waypoint.moveRadius or 10})
                if result=="STUCK" or result=="BLOCKED" then
                    goal.routeRetries=(goal.routeRetries or 0)+1
                    self.lastRouteFailure={key=goal.key,at=now,reason=self.adapter.motionReason,
                        navigation=self.adapter.nav and self.adapter.nav:status()}
                    self:log(now,"route_retry","Retrying approach "..goal.key.." ("..goal.routeRetries.."): "..tostring(self.adapter.motionReason or result))
                    self.adapter:advanceSpot(goal.key);self.adapter:stop("Alternative territory approach")
                    if goal.routeRetries>=3 then self:fail(state,"Territory route failed after three approach attempts") end
                elseif now-goal.start>240 then self:fail(state,"Territory travel budget exhausted") end
                return
            end
            self.adapter:stop("at territory")
            self.phase="CLAIMING";self.reason=goal.nativeStarted and "Native territory progress observed" or "Waiting for native claim/scent progress"
            if not goal.interactAt then goal.interactAt=now;goal.progressAt=now end
            local stall=now-goal.progressAt
            local stallLimit=goal.nativeStarted and math.max(4.5,(state.progressLatency or 1)*3) or 3.2
            if stall>stallLimit and (goal.alternates or 0)<3 then
                goal.alternates=(goal.alternates or 0)+1;goal.progressAt=now;goal.interactAt=now
                self.adapter:advanceSpot(goal.key);self.phase="REPOSITION"
                self.reason="Trying another surface position in "..goal.key
            elseif stall>6 or now-goal.interactAt>75 then self:fail(state,"No confirmed territory progress") end
            return
        end
        local kind=goal.kind=="DRINK" and "drink" or "eat"
        if (feeding(state,"eat") or feeding(state,"drink")) and not (goal.meal and goal.meal.owned) then
            goal.manualInterventionObserved=true
        end
        local careStatus,careReason=self.Care.step(goal,state,self.adapter)
        if careStatus=="COMPLETE" then
            if self.adapter.careObserved then self.adapter:careObserved(goal,state) end
            self.lastCare={kind=goal.kind,seconds=now-goal.start,wallSeconds=now-(goal.wallStart or goal.start),activeSeconds=goal.timing and goal.timing.active,
                pausedSeconds=goal.timing and goal.timing.paused,unobservedSeconds=goal.timing and goal.timing.unknown,
                phases=goal.timing and goal.timing.phases or goal.durations,gain=goal.gain,
                manualInterventionObserved=goal.manualInterventionObserved==true}
            if kind=="drink" then self.lastFullDrinkAt=now end
            if self.metrics then self.metrics:count("outcome",goal.manualInterventionObserved and "assisted care completed" or "unassisted care observed") end
            self.feeds+=1;self.lastSuccess=careReason.." (+"..string.format("%.1f",goal.gain)..")"
            self:log(now,"confirmed",self.lastSuccess);self.goal=nil;self:resume(state)
            if not self.goal then self.phase="CONFIRMED";self.reason=self.lastSuccess end
            return
        elseif careStatus=="BUSY" then
            self.adapter:stop("native feeding owns approach")
            self.phase=feeding(state,kind) and (kind=="drink" and "DRINKING" or "EATING") or "FEED_APPROACH"
            self.reason=careReason;return
        elseif careStatus=="FAILED" then self:fail(state,careReason);return
        elseif careStatus=="RELOCATE" then
            if kind=="drink" and self.adapter.avoidWater then self.adapter:avoidWater(goal.location or state.feedPosition or state.position,now) end
            if goal.food and goal.food.model and self.adapter.foodBlocked then self.adapter.foodBlocked[goal.food.model]=now+30 end
            goal.location,goal.arrivedAt,goal.food,goal.foodArrived=nil,nil,nil,nil
            self.Care.resetSite(goal,now)
            goal.siteFailures=(goal.siteFailures or 0)+1
            goal.feedBlockedUntil=now+1.5
            if goal.siteFailures>=3 then self:fail(state,careReason);return end
        end
        if state.feedCan==kind and now>=(goal.feedBlockedUntil or 0) then
            self.adapter:stop("native feed offer")
            if now<goal.nextAction then return end
            local sent=self.adapter:feed(state,kind)
            goal.tries+=1;goal.nextAction=now+1
            if sent then self.Care.requested(goal,now) end
            self.phase=kind=="drink" and "DRINKING" or "EATING"
            self.reason=sent and "Feed input requested; watching native approach and need" or "Feed input unavailable"
            if not sent and goal.tries>=3 then self:fail(state,"Native feed input unavailable") end
            return
        end
        local usefulHunt=goal.hunt and goal.hunt.lastUsefulAt and now-goal.hunt.lastUsefulAt<12
        if now-goal.start>150 and not usefulHunt then self:fail(state,"Survival objective timed out without useful progress");return end
        if kind=="drink" then
            if not goal.location then goal.location=self.adapter:water(state);goal.locationAt=now end
            if not goal.location then
                local search=self.adapter.resourceSearch and self.adapter:resourceSearch(state,"WATER")
                if search then
                    self.phase="SEARCH_WATER";self.reason="Checking another area for native water access"
                    self.adapter:move(search,state,{navKey="WATER_SCOUT",moveRadius=10})
                else
                    self.phase="WAIT_WATER";self.reason="No streamed water access found";self.adapter:stop("no water")
                end
                return
            end
            if now-(goal.waterRefreshAt or 0)>1.5 and self.adapter.waterEvidence=="LANDMARK_APPROACH" then
                goal.waterRefreshAt=now
                local refined=self.adapter:water(state)
                if refined and flat(refined,goal.location)>5 then goal.location=refined;goal.arrivedAt=nil end
            end
            local d=flat(state.position,goal.location)
            if d<110 and self.adapter.waterEvidence=="LANDMARK_APPROACH" and now-(goal.refinedAt or 0)>3 then
                goal.refinedAt=now
                self.adapter.waterCache=nil
                local refined=self.adapter:water(state)
                if refined and flat(refined,goal.location)>5 then goal.location=refined;goal.arrivedAt=nil end
                d=flat(state.position,goal.location)
            end
            if d<6 and not goal.arrivedAt then goal.arrivedAt=now end
            if goal.arrivedAt and now-goal.arrivedAt>1.8 then
                if self.adapter.avoidWater then self.adapter:avoidWater(goal.location,now) end
                goal.location=nil;goal.arrivedAt=nil;goal.waterRetries=(goal.waterRetries or 0)+1
                if goal.waterRetries>=4 then self:fail(state,"No native drinking offer at sampled water access") end
                return
            end
            self.phase="TRAVEL_WATER";self.reason="Approaching observed water access"
            local result=self.adapter:move(goal.location,state,{navKey="WATER:"..tostring(goal.locationAt),moveRadius=4})
            if result=="STUCK" or result=="BLOCKED" then
                if self.adapter.avoidWater then self.adapter:avoidWater(goal.location,now) end
                goal.location=nil;goal.arrivedAt=nil
            end
            return
        end
        local food=self.adapter.food and self.adapter:food(state,goal.food)
        if food and self.adapter.mealChoice then food=self.adapter:mealChoice(state,food,goal.hunt) end
        if food then
            if not goal.food or goal.food.model~=food.model then goal.foodArrived=nil end
            goal.food=food;self.phase="TRAVEL_FOOD";self.reason="Approaching native edible food"
            local result=self.adapter:move(food.position,state,{navKey=food.model or "FOOD",moveRadius=2})
            if result=="REACHED" then goal.foodArrived=goal.foodArrived or now end
            if result=="STUCK" or result=="BLOCKED" or goal.foodArrived and now-goal.foodArrived>2.5 then
                if food.model and self.adapter.foodBlocked then self.adapter.foodBlocked[food.model]=now+80 end
                goal.food=nil;goal.foodArrived=nil
            end
            return
        end
        if state.healthFraction<.42 then
            local search=self.adapter.resourceSearch and self.adapter:resourceSearch(state,"FOOD")
            if search then
                self.phase="SEARCH_FOOD";self.reason="Seeking edible food without risking a hunt"
                self.adapter:move(search,state,{navKey="LOW_HP_FOOD",moveRadius=10})
            else
                self.phase="WAIT_FOOD";self.reason="Health too low to hunt; watching edible food offers"
                self.adapter:stop("low health excludes hunt")
            end
            return
        end
        if not goal.hunt and self.Hunt then goal.hunt=self.Hunt.new(self.adapter) end
        if not goal.hunt then self.phase="WAIT_FOOD";self.reason="Hunting controller unavailable";self.adapter:stop("no hunter");return end
        if goal.hunt.corpse then
            local corpse=goal.hunt.corpse
            if now-corpse.at<10 then
                self.phase="WAIT_FOOD";self.reason="Prey HP reached zero; locating native edible food"
                self.adapter:move(corpse.position,state,{navKey="CORPSE",moveRadius=2});return
            else goal.hunt.corpse=nil end
        end
        self.phase,self.reason=goal.hunt:tick(state)
        if (self.phase=="WAIT_FOOD" or self.phase=="HUNT_REPLAN" or self.phase=="HUNT_SEARCH") and self.adapter.resourceSearch then
            local search=self.adapter:resourceSearch(state,"FOOD")
            if search then
                self.adapter:move(search,state,{navKey="FOOD_SCOUT",moveRadius=10,hunting=true})
                self.phase="SEARCH_FOOD";self.reason="Searching another area for edible food or suitable NPC prey"
            end
        end
        self.lastHunt=goal.hunt:status();self.lastHunt.at=now;self.lastHunt.active=false;self.lastHunt.retained=true
        if goal.hunt.kills>(goal.observedKills or 0) then
            self.hunts+=goal.hunt.kills-(goal.observedKills or 0);goal.observedKills=goal.hunt.kills
        end
    end
    return a
end
return Agent
]============]
sources["bridge"] = [============[
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
]============]
sources["driver"] = [============[
-- Ordinary world-space input before WolfMove reads Humanoid.MoveDirection.
-- v2412 WolfController 187:1546-1666 binds WolfMove at Input.Value+1.
local Driver={}
function Driver.new(player,nav,manual)
    local d={nav=nav,closed=false,method="NATIVE_KEYS",controls=nil,original=nil,nextProbe=0}
    local function currentAnimal()
        if not nav.body then return true end
        local char=player.Character
        local root=char and type(char.FindFirstChild)=="function" and char:FindFirstChild("HumanoidRootPart") or nil
        if char==nav.body and (not nav.bodyRoot or root==nav.bodyRoot) then return true end
        if nav.gaits then nav.gaits.burstOwned=false;nav.gaits.trotOwned=false end
        nav:stop(nil,nil,"CHARACTER_CHANGED")
        return false
    end
    function d:attach()
        if self.closed or self.controls and self.controls.moveFunction==self.wrapper then return end
        local modules={}
        local scripts=player:FindFirstChild("PlayerScripts")
        local legacy=scripts and scripts:FindFirstChild("PlayerModule")
        if legacy then table.insert(modules,{module=legacy,path="PLAYER_SCRIPTS"}) end
        -- The supplied capture indexes StarterPlayer/PlayerModule/ControlModule.
        -- IAS PlayerModule need not expose the legacy GetControls endpoint.
        local ok,starter=pcall(function()return game:GetService("StarterPlayer")end)
        local modern=ok and starter and starter:FindFirstChild("PlayerModule")
        if modern and modern~=legacy then table.insert(modules,{module=modern,path="STARTER_PLAYER"}) end
        local controls,path=nil,nil
        for _,candidate in ipairs(modules) do
            local mod=candidate.module
            local good,value=pcall(require,mod)
            if good and type(value)=="table" then
                if type(value.GetControls)=="function" then
                    local found,result=pcall(value.GetControls,value)
                    if found and type(result)=="table" then controls=result end
                elseif type(value.moveFunction)=="function" then controls=value end
            end
            if not controls and type(mod.FindFirstChild)=="function" then
                local child=mod:FindFirstChild("ControlModule")
                if child then
                    local found,result=pcall(require,child)
                    if found and type(result)=="table" then controls=result end
                end
            end
            if controls and type(controls.moveFunction)=="function" then path=candidate.path;break end
            controls=nil
        end
        if controls and controls==self.displacedControls then
            self.reason="External owner retained; waiting for a new control module";return
        end
        if not controls then self.reason="No supported native moveFunction; using keys";return end
        local previous=controls.moveFunction
        local binding={original=previous}
        local wrapper=function(p,direction,relative)
            if p==player and not self.closed and nav.desiredPoint and nav.steeringStrategy=="WORLD" and binding.active~=false and currentAnimal() then
                if manual and manual(direction) then
                    nav:stop(nav.desiredHum,nav.desiredRoot,"MANUAL_INPUT")
                else
                    local wanted=nav:direction()
                    if wanted then
                        nav.driveCalls+=1;nav.lastMode="PLAYER_MODULE"
                        return binding.original(p,wanted,false)
                    end
                end
            end
            return binding.original(p,direction,relative)
        end
        local attached,why=pcall(function()controls.moveFunction=wrapper end)
        if not attached then self.reason=tostring(why);return end
        self.controls,self.original,self.wrapper=controls,previous,wrapper;self.binding=binding
        self.method,self.path,self.reason="PLAYER_MODULE",path,"Native callback attached; motion unverified"
        nav.preferredStrategy="WORLD";nav.steeringStrategy="WORLD"
        nav.driverPath=path
    end
    d:attach()
    if not d.controls then nav.preferredStrategy="KEY";nav.steeringStrategy="KEY" end
    function d:tick()
        if self.closed then return end
        currentAnimal()
        if self.controls and self.controls.moveFunction~=self.wrapper then
            self.method="NATIVE_KEYS";nav.preferredStrategy="KEY";nav.steeringStrategy="KEY"
            self.reason="Native callback ownership changed";self.displacedControls=self.controls
            if self.binding then self.binding.active=false end
            if os.clock()>=self.nextProbe then self.nextProbe=os.clock()+5;self:attach() end
        elseif not self.controls and os.clock()>=self.nextProbe then
            self.nextProbe=os.clock()+5;self:attach()
        end
        nav.driverReason=self.reason
        if nav.steeringStrategy=="KEY" then nav:drive() end
    end
    function d:close()
        if self.closed then return end
        self.closed=true
        nav:stop(nav.desiredHum,nav.desiredRoot,"DRIVER_CLOSED")
        if self.controls and self.controls.moveFunction==self.wrapper then
            self.controls.moveFunction=self.original
        end
    end
    return d
end
return Driver
]============]
sources["ui"] = [============[
-- Native Renaissance page. No companion ScreenGui, scheduler or visibility key.
local UI={}
function UI.new(engine,hub)
    local p={closed=false,engine=engine,hub=hub}
    local function amount(value)
        return type(value)=="number" and string.format("%.0f",value) or "?"
    end
    function p:mount(parent,H)
        local text,button,card=H.text,H.button,H.card
        local v={}
        local controls=card(0,48)
        local start=button(controls,"START FARMING",10,9,150,30)
        local skip=button(controls,"SKIP TARGET",169,9,150,30)
        local copy=button(controls,"COPY STATUS",328,9,150,30)
        start.Name="TerritoryStart";skip.Name="TerritorySkip";copy.Name="TerritoryCopy"
        start.Activated:Connect(function()if not p.closed then engine.setEnabled(not engine.agent.enabled)end end)
        skip.Activated:Connect(function()if not p.closed then engine.skip()end end)
        copy.Activated:Connect(function()if not p.closed then engine.copyStatus()end end)
        local stats=card(56,71)
        local totals=text(stats,"",12,8,465,22,12,H.palette.same)
        local needs=text(stats,"",12,34,465,23,12)
        local goal=card(135,103)
        local phase=text(goal,"",12,7,465,23,13,H.palette.same)
        local reason=text(goal,"",12,33,465,37,11,H.palette.sub);reason.TextWrapped=true
        local progress=text(goal,"",12,73,465,20,11)
        local movement=card(246,53)
        local gait=text(movement,"",12,5,465,22,12)
        local travel=text(movement,"",12,28,465,19,10,H.palette.sub)
        local recent=card(307,54)
        local last=text(recent,"",12,5,465,44,11,H.palette.sub);last.TextWrapped=true
        function v:tick(now)
            if now<(self.nextText or 0) then return end
            self.nextText=now+.25
            local s=engine.status();local n=s.navigation or {};local c=s.hexSummary or {}
            start.Text=s.enabled and "STOP FARMING" or "START FARMING"
            start.BackgroundColor3=s.enabled and H.palette.on or H.palette.off
            local amber=s.metrics and s.metrics.amber
            local balance=amber and string.format("Balance %+.0f · %+.0f/hr",amber.net or 0,amber.netPerWallHour or 0)
                or string.format("Observed Amber +%.0f",s.earned or 0)
            totals.Text=string.format("%d / %d owned · %d need scent · %s",c.owned or 0,c.eligible or 0,c.fading or 0,balance)
            needs.Text="Hunger "..amount(s.hunger).." · Thirst "..amount(s.thirst).." · "..tostring(s.species or "Waiting for animal")
            phase.Text=(s.enabled and "RUNNING · " or "OFF · ")..tostring(s.phase)..(s.key and " · "..s.key or "")
            reason.Text=tostring(s.reason or "Ready")
            local target=s.targetProgress or {}
            local value=target.action=="SCENT" and target.hold or target.progress
            progress.Text=type(value)=="number" and ("Native territory progress "..amount(value*100).."%")
                or s.suspended and ("Will resume "..s.suspended) or "Watching native progress and resource changes"
            gait.Text=tostring(n.requested or "STOP").." requested · "..tostring(n.observed or "UNKNOWN").." observed"
            travel.Text="Travelled "..amount(n.travelled).." studs · Target "..amount(n.distance).." studs"
                ..(n.failure and (n.stalledFor or 0)>1 and " · "..n.failure or "")
            if s.strategy and s.strategy.area then
                progress.Text=s.strategy.area.." · "..tostring(s.strategy.owned or 0).."/"..tostring(s.strategy.total or 0).." owned"
                    ..(type(value)=="number" and (" · Native progress "..amount(value*100).."%") or "")
            end
            local capacity=s.capacity and s.capacity.maintenance
            if capacity and capacity.state=="OVERLOADED" then
                progress.Text=progress.Text.." · Maintenance "..tostring(capacity.retained).."/"..tostring(capacity.owned).." retained (estimate)"
            elseif s.capacity and s.capacity.state=="DEADLINE_PRESSURE" then
                progress.Text=progress.Text.." · Deadline pressure"
            end
            last.Text=s.lastNotice or s.lastSuccess or s.lastSkip or "Select START FARMING. Hiding the hub keeps farming active."
        end
        function v:close()end
        v:tick(os.clock());return v
    end
    p.registration=hub.ui:registerPage("Territory",p)
    function p:close()
        if self.closed then return end
        self.closed=true
        if self.registration then self.registration:close() end
    end
    return p
end
return UI
]============]
sources["runtime"] = [============[
-- Built-in Territory engine. Renaissance owns scheduling, UI and shutdown.
local Runtime={version="0.8.0"}
function Runtime.start(M,hub)
    assert(hub and hub.ui and type(hub.ui.registerPage)=="function","Update Renaissance for its built-in Territory page")
    local env=(type(getgenv)=="function" and getgenv()) or _G
    local prior=env.FERAL_AMBER_ACTIVE
    if prior and prior.version==Runtime.version and prior.ownerHub==hub and not prior.closed then return prior end
    local function module(name)return assert(M["amber_"..name] or M[name],"Missing territory module "..name)end
    local Nav,Bridge,Agent=module("nav"),module("bridge"),module("agent")
    local model=module("model").new()
    local nav=Nav.new(game:GetService("PathfindingService"),game:GetService("Workspace"),module("gait"),model)
    local bridge=Bridge.new(nav);bridge.ownerHub=hub
    local agent=Agent.new(module("planner"),bridge,module("hunt"),module("care"),module("ledger"))
    local attached,driver=pcall(module("driver").new,bridge.player,nav,function(direction)return bridge:manualInput(direction)end)
    if not attached then pcall(bridge.close,bridge);nav.closed=true;error(driver,0) end
    local h={version=Runtime.version,ownerHub=hub,agent=agent,bridge=bridge,nav=nav,driver=driver,closed=false,nextCounts=0}
    function h.setEnabled(on) if not h.closed then agent:setEnabled(on==true,os.clock()) end end
    function h.status()
        local now=os.clock();local st=agent:status()
        if now>=h.nextCounts then
            h.counts=bridge:counts(agent.lastState or {now=now});h.nextCounts=now+.8
        end
        st.support={known=agent.lastState and agent.lastState.profile and agent.lastState.profile.known,
            diet=agent.lastState and agent.lastState.profile and agent.lastState.profile.diet,
            modes=agent.lastState and agent.lastState.profile and agent.lastState.profile.support}
        st.support.current=bridge.currentCoverage;st.support.encountered={}
        for _,key in ipairs(bridge.coverageOrder) do table.insert(st.support.encountered,bridge.coverage[key]) end
        st.nativeHelperCosts=bridge.nativeCosts
        st.discoveryOperations=bridge.operations;st.hexSummary=h.counts;st.navigation=nav:status();st.gameVersion=game.PlaceVersion
        st.events={}
        for i=math.max(1,#agent.events-11),#agent.events do table.insert(st.events,agent.events[i]) end
        return st
    end
    function h.copyStatus()
        local ok,payload=pcall(function()return game:GetService("HttpService"):JSONEncode(h.status())end)
        if not ok then return false end
        if type(setclipboard)=="function" then pcall(setclipboard,payload) end
        print("[FERAL TERRITORY STATUS] "..payload);return true
    end
    function h.skip()
        if not agent.enabled then return end
        local s=agent.lastState
        if not s or not agent.goal or agent.goal.kind~="TERRITORY" then return end
        agent:fail(s,"Target skipped from Territory controls");agent.nextTick=0
    end
    local mounted,panel=pcall(module("ui").new,h,hub)
    if not mounted then
        pcall(driver.close,driver);pcall(bridge.close,bridge);nav.closed=true;error(panel,0)
    end
    h.panel=panel
    function h:tick(now)
        if self.closed then return end
        if hub.closed then self.close();return end
        if hub.timingCritical then
            -- The core has already pumped the legal minigame window. Avoid
            -- scans/pathfinding/gait requests until that deadline has passed.
            if agent.enabled and not self.deadlinePaused then
                self.deadlinePaused=true
                pcall(agent.pause,agent,{now=now},"Native minigame input has priority")
                pcall(nav.releaseKeys,nav);pcall(bridge.releaseInputs,bridge)
            end
            return
        end
        self.deadlinePaused=nil
        local started=os.clock();local wasEnabled=agent.enabled
        local ok,why=pcall(function()
            if agent.enabled then driver:tick() end
            for _=1,3 do
                agent:tick(now)
                if not agent.enabled or agent.goal or agent.phase~="CONFIRMED" and agent.phase~="REPLAN" then break end
                agent.nextTick=now
            end
        end)
        if wasEnabled and agent.metrics and agent.metrics.run then agent.metrics:cost("coordinator",math.max(0,os.clock()-started)) end
        if not ok then
            -- A failure in the normal stop path must not escape this boundary
            -- and interrupt the shared hub's remaining work for the frame.
            pcall(agent.setEnabled,agent,false)
            pcall(nav.stop,nav,nav.desiredHum,nav.desiredRoot,"TERRITORY_ERROR")
            pcall(nav.releaseKeys,nav);pcall(bridge.releaseInputs,bridge)
            agent.enabled=false;agent.goal=nil;agent.suspended=nil;agent.returns={};agent.phase="ERROR"
            agent.lastError=tostring(why):sub(1,180);agent.reason="Territory stopped after an input or data error"
        end
    end
    function h.close()
        if h.closed then return end
        h.closed=true
        pcall(agent.setEnabled,agent,false);pcall(driver.close,driver);pcall(bridge.close,bridge)
        nav.closed=true
        if h.panel then pcall(h.panel.close,h.panel) end
        if env.FERAL_AMBER_ACTIVE==h then env.FERAL_AMBER_ACTIVE=nil end
        if hub.territory==h then hub.territory=nil end
    end
    if prior and type(prior.close)=="function" then
        local ok,why=pcall(prior.close)
        if not ok then h.close();error(why,0) end
        if prior.driver and driver.original==prior.driver.wrapper then
            driver.original=prior.driver.original
            if driver.binding then driver.binding.original=prior.driver.original end
        end
    end
    env.FERAL_AMBER_ACTIVE=h;hub.territory=h
    return h
end
return Runtime
]============]
-- The Territory engine is part of Renaissance; this versioned entry reuses it.
if game.PlaceId~=108901361810209 then return nil end
local env=(type(getgenv)=="function" and getgenv()) or _G
local hub=env.FERAL_RENAISSANCE_ACTIVE
if not hub or hub.closed or not hub.ui or type(hub.ui.registerPage)~="function" then
    warn("[FERAL TERRITORY] Run the current combined Amber/Renaissance launcher first.")
    return nil
end
if hub.territory and hub.territory.version=="0.8.0" and not hub.territory.closed then return hub.territory end
local M={}
for name,source in pairs(sources) do
    local fn,why=loadstring(source,"=FERAL_TERRITORY_"..name)
    assert(fn,why);M[name]=fn()
end
return M.runtime.start(M,hub)
