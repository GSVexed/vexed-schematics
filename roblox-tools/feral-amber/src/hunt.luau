-- Moving NPC pursuit. Inputs and observed HP changes are separate outcomes.
local Hunt={}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e8 end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2) end
function Hunt.new(adapter)
    local h={adapter=adapter,target=nil,pending=nil,hits=0,misses=0,attacks=0,
        lastResult="No attack",nextAttack=0,blocked={},kills=0}
    function h:abandon(now,why)
        if self.target and self.target.model then
            self.blocked[self.target.model]=now+80
            if self.adapter.preyBlocked then self.adapter.preyBlocked[self.target.model]=now+80 end
        end
        self.target,self.pending=nil,nil
        self.lastResult=why;self.nextSelect=now+2
        self.adapter:stop(why)
    end
    function h:tick(s)
        local now=s.now
        local prey=self.target
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
            self.closingAt=now;self.sample=nil;self.noDamageAt=now;self.missesOnTarget=0
        end
        local health=prey.health or prey.hum and prey.hum.Health
        if self.pending then
            local p=self.pending
            if finite(health) and health<p.health-.01 then
                self.hits+=1;self.noDamageAt=now;self.missesOnTarget=0
                self.lastResult="Observed prey HP decline after input; attribution unverified"
                self.pending=nil
            elseif now-p.at>1.6 then
                self.misses+=1;self.missesOnTarget+=1
                self.lastResult="No prey HP decline observed"
                self.pending=nil;self.repositionUntil=now+1.1
            end
        end
        local d=distance(s.position,prey.position)
        if d<self.bestDistance-3 then self.bestDistance=d;self.closingAt=now end
        if d>390 or now-self.started>65 or self.missesOnTarget>=6
            or now-self.closingAt>12 and d>28 or now-self.noDamageAt>25 and d<28 then
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
        self.sample={position={x=prey.position.x,z=prey.position.z},at=now}
        local lead=math.clamp(d/math.max(20,(s.travelSpeed or 35)+speed),.08,.85)
        local target={x=prey.position.x+velocity.x*lead,z=prey.position.z+velocity.z*lead}
        local geometry=type(self.adapter.attackGeometry)=="function" and self.adapter:attackGeometry(s,prey) or nil
        local valid=geometry and geometry.valid
        -- Keep pursuing while verifying a previous bite; a coarse range check
        -- must never freeze a hunter while its prey runs out of range.
        if valid and now>=self.nextAttack and not self.pending and now>=(self.repositionUntil or 0) then
            local sent,why=self.adapter:bite(s,prey)
            self.lastResult=why or (sent and "Attack requested; awaiting prey HP" or "Native attack not ready")
            self.nextAttack=now+(s.attackCooldown or 1.35)
            if sent and finite(health) then
                self.attacks+=1;self.pending={at=now,health=health}
            end
        end
        if valid and speed<2 and not self.repositionUntil then
            self.adapter:stop("valid stationary attack position")
        else
            if geometry and geometry.inRange and not valid or now<(self.repositionUntil or 0) then
                local dx,dz=prey.position.x-s.position.x,prey.position.z-s.position.z
                local len=math.max(1,math.sqrt(dx*dx+dz*dz))
                local side=(self.missesOnTarget%2==0) and 1 or -1
                target={x=prey.position.x+dx/len*2-dz/len*side*2,
                    z=prey.position.z+dz/len*2+dx/len*side*2}
            end
            local result=self.adapter:move(target,s,{navKey=prey.model or "NPC_HUNT",
                movingTarget=true,hunting=true,preySpeed=speed,moveRadius=.9})
            if result=="STUCK" or result=="BLOCKED" then
                self:abandon(now,"NPC pursuit route failed")
                return "HUNT_REPLAN",self.lastResult
            end
        end
        if self.repositionUntil and now>=self.repositionUntil then self.repositionUntil=nil end
        self.distance=d;self.preySpeed=speed
        return self.pending and "HUNT_VERIFY" or valid and "HUNT_ATTACK" or "HUNT_APPROACH",self.lastResult
    end
    function h:status()
        return {attacks=self.attacks,hpDeclines=self.hits,misses=self.misses,
            result=self.lastResult,distance=self.distance,preySpeed=self.preySpeed,
            active=self.target~=nil,killsObserved=self.kills}
    end
    return h
end
return Hunt
