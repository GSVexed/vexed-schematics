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
    if options.hunting and (options.preySpeed or 0)>6 and distance>6
        and (not finite(stamina) or stamina>=.22) and (turn or 0)<65 then return "SPRINT" end
    if distance<10 then return "WALK" end
    if distance<24 then return "TROT" end
    local reserve=finite(stamina) and stamina or nil
    local angle=finite(turn) and turn or 0
    if options.allowBurst~=false and reserve and reserve>=.56
        and distance>=170 and angle<=22 and not options.crowded
        and options.burstReady~=false then return "BURST" end
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
            elseif now-p.at>=2.4 then
                local count=self.attempts[p.mode] or 1
                if count>=2 then self.blocked[p.mode]=now+18 end
                self.pending=nil;self.reason="Gait request unconfirmed"
                if p.mode=="SPRINT" then io:hold("SHIFT",false) end
                if count==1 and type(io.retryInput)=="function" then
                    io:retryInput(p.mode=="SPRINT" and "SHIFT" or p.mode=="TROT" and "Z" or "X")
                end
            end
        end
        local emergency=wanted=="STOP" or wanted=="WALK" or s.ability or s.swimming
        if wanted~=self.requested and not emergency and now-self.changedAt<2.25 then
            wanted=self.requested
        end
        if wanted=="BURST" and (type(s.hudBurst)~="boolean" or s.hudBurstNo or (self.blocked.BURST or 0)>now) then wanted="SPRINT" end
        if (wanted=="SPRINT" or wanted=="BURST") and (self.blocked.SPRINT or 0)>now then wanted="TROT" end
        if wanted~=self.requested then self.changedAt=now;self.requested=wanted end
        local fast=wanted=="SPRINT" or wanted=="BURST"
        io:hold("SHIFT",fast)
        local function request(mode,key)
            if self.pending or (self.blocked[mode] or 0)>now then return end
            local sent=key=="SHIFT" and io:hold(key,true) or io:tap(key)
            if sent then
                self.attempts[mode]=(self.attempts[mode] or 0)+1
                self.requests+=1;self.pending={mode=mode,at=now}
                self.reason="Input requested; awaiting native gait"
                if mode=="BURST" then self.burstOwned=true end
                if mode=="TROT" then self.trotOwned=true end
            else self.blocked[mode]=now+18;self.reason="Gait input unavailable" end
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
