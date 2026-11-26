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
