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
    local owned=hex.owner==state.pack
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
    if deny and options.avoidPlayers~=false then return nil end
    local recent=options.recent and options.recent[hex.key]
    local waiting=options.waitingSince and options.waitingSince[hex.key]
    if finite(waiting) then priority+=math.min(180,math.max(0,(state.now or 0)-waiting)/5) end
    if finite(recent) and (state.now or 0)-recent<120 then priority*=.65 end
    local routeCost=1+d/320
    local score=priority/(routeCost^.74)
    if not finite(score) then return nil end
    return {key=hex.key,kind=kind,score=score,base=priority,distance=d,
        pay=payKnown and pay or nil,hold=hold,center=hex.center,nearestPlayer=nearest,
        urgency=owned and (1-(hold or 0)) or 0}
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

function Planner.need(state,options)
    options=options or {}
    if not state or not finite(state.healthFraction) then return "WAIT" end
    if state.healthFraction<(options.minimumHP or .46) then return "RECOVER" end
    local h,t=state.hunger,state.thirst
    if finite(t) and t<(options.emergencyThirst or 19) then return "DRINK" end
    if finite(h) and h<(options.emergencyHunger or 19) then return "EAT" end
    if finite(t) and t<(options.thirstTrigger or 44) then return "DRINK" end
    if finite(h) and h<(options.hungerTrigger or 42) then return "EAT" end
    return "TERRITORY"
end
return Planner
