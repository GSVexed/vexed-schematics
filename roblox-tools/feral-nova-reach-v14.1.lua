-- FERAL NOVA PRIME v14.1 / Conservative enhanced bite reach, rear arc and elevation.
-- Changes only the shared client CombatConfig bite selection math.
-- Enemy Part.Size / CanCollide / CollisionGroup are NEVER touched.
-- Native WolfController handles Bite and BiteHit on its original schedule.
local Reach={}
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local function good(n)return type(n)=="number" and n==n and math.abs(n)<1e7 end
local function cfgNow()
    local folder=RS:FindFirstChild("FeralWorld")
    local inst=folder and folder:FindFirstChild("CombatConfig")
    if not inst or not inst:IsA("ModuleScript") then return nil,"CombatConfig module absent" end
    local ok,t=pcall(require,inst)
    if not ok or type(t)~="table" then return nil,"CombatConfig require failed" end
    for _,k in ipairs({"REACH","HIT_SCALE","CONE","SLACK","MAX_DY"}) do
        if not good(t[k]) then return nil,"CombatConfig missing "..k end
    end
    if type(t.bodyGap)~="function" then
        return nil,"CombatConfig bodyGap missing"
    end
    return t,nil
end
local function snapshot(t)
    return {REACH=t.REACH,HIT_SCALE=t.HIT_SCALE,
        CONE=t.CONE,SLACK=t.SLACK,MAX_DY=t.MAX_DY,
        bodyGap=t.bodyGap,reachMult=t.reachMult,
        coneFor=t.coneFor,dyMult=t.dyMult}
end
local function vecFlat(v)
    return Vector3.new(v.X,0,v.Z)
end
local function ownedCompare(patch)
    for _,e in ipairs(patch or {}) do
        if e.table[e.key]~=e.wanted then return false end
    end
    return patch and #patch>0
end
function Reach.geometry(values, ownRoot,ownHum,enemyRoot,enemyHum,character)
    if not values or not ownRoot or not enemyRoot
        or not ownHum or not enemyHum then return nil end
    local diff=enemyRoot.Position-ownRoot.Position
    local flat=vecFlat(diff)
    local fwd=vecFlat(ownRoot.CFrame.LookVector)
    if fwd.Magnitude<.01 then return nil end
    fwd=fwd.Unit
    local angle=flat.Magnitude>.01 and fwd:Dot(flat.Unit) or 1
    local ok,gap=pcall(values.bodyGap,enemyRoot,flat)
    if not ok or not good(gap) then return nil end
    local reachMult=1
    if type(values.reachMult)=="function" then
        local b,v=pcall(values.reachMult,character)
        if b and good(v) then reachMult=v end
    end
    local cone=values.CONE
    if type(values.coneFor)=="function" then
        local b,v=pcall(values.coneFor,character)
        if b and good(v) then cone=v end
    end
    local dyMult=1
    if type(values.dyMult)=="function" then
        local b,v=pcall(values.dyMult,character)
        if b and good(v) then dyMult=v end
    end
    local box=ownRoot:GetAttribute("FeralBoxFull")
    if not good(box) or box<=0 then box=ownRoot.Size.Z end
    local reach=(box*.5+ownHum.HipHeight*values.REACH+values.SLACK)
        *values.HIT_SCALE*reachMult
    local vertical=math.abs(diff.Y)
    local maxVertical=(ownHum.HipHeight+enemyHum.HipHeight)*values.MAX_DY*dyMult
    local maxAngle=math.cos(math.rad(cone))
    local distanceOK=gap<reach
    local facingOK=angle>maxAngle
    local heightOK=vertical<maxVertical
    local valid=distanceOK and facingOK and heightOK
    return {valid=valid,gap=gap,reach=reach,angle=angle,
        angleDegrees=math.deg(math.acos(math.clamp(angle,-1,1))),
        coneDegrees=cone,vertical=vertical,maxVertical=maxVertical,
        distanceOK=distanceOK,facingOK=facingOK,heightOK=heightOK,
        distance=flat.Magnitude,margin=reach-gap}
end
function Reach.attach(ctx)
    local C={
        enabled=false,applied=false,alive=true,mode="OFF",
        status="OFF",lastError="",installCount=0,
        externalChanges=0,reverts=0,
        lease=nil,original=nil,table=nil,claimedWindows=0,
        baselineDistance=0,boostDistance=0,benefit="SERVER UNVERIFIED",
        nextTick=0
    }
    local function restore()
        if not C.lease then return end
        for i=#C.lease,1,-1 do
            local e=C.lease[i]
            pcall(function()
                if e.table[e.key]==e.wanted then
                    e.table[e.key]=e.original
                    C.reverts+=1
                else
                    C.externalChanges+=1
                end
            end)
        end
        C.lease=nil;C.applied=false
        C.table=nil
    end
    function C.setEnabled(v)
        if v==false then
            C.enabled=false;restore()
            C.status="OFF / ORIGINAL CLAIM GEOMETRY RESTORED"
            C.mode="OFF"
            return false
        end
        C.enabled=true
        if C.applied and ownedCompare(C.lease) then
            return true
        end
        if C.applied then
            restore()
            C.enabled=false
            C.status="EXTERNAL COMBAT CONFIG CHANGED / BOOST DISABLED"
            C.lastError="Another script changed the configured claim geometry"
            return false
        end
        local t,err=cfgNow()
        if not t then
            C.status="WAITING / "..tostring(err)
            C.lastError=tostring(err)
            return false
        end
        local original=snapshot(t)
        -- Modest additional distance over v14, but a deliberate rear-side
        -- angle and elevation window. Client-only: server validation applies.
        local desired={
            REACH=math.min(original.REACH*1.27,2.82),
            HIT_SCALE=math.min(original.HIT_SCALE*1.24,2.0),
            CONE=math.min(original.CONE+48,124),
            SLACK=original.SLACK+.45,
            MAX_DY=math.min(original.MAX_DY*1.35,4.0),
        }
        -- Only client claim geometry; real character/enemy parts unchanged.
        desired.bodyGap=function(part,flat)
            local gap=original.bodyGap(part,flat)
            if not good(gap) then return gap end
            return gap-.84
        end
        local lease={}
        for _,key in ipairs({"REACH","HIT_SCALE","CONE","SLACK","MAX_DY","bodyGap"}) do
            local before=t[key]
            local wanted=desired[key]
            if before~=wanted then
                local ok=pcall(function()t[key]=wanted end)
                if not ok or t[key]~=wanted then
                    for i=#lease,1,-1 do
                        local e=lease[i]
                        if e.table[e.key]==e.wanted then
                            pcall(function()e.table[e.key]=e.original end)
                        end
                    end
                    C.status="CLAIM CONFIG WRITE FAILED / ORIGINAL RESTORED"
                    C.lastError="CombatConfig rejected "..key
                    C.enabled=false
                    return false
                end
                lease[#lease+1]={table=t,key=key,
                    original=before,wanted=wanted}
            end
        end
        C.lease=lease
        C.original=original
        C.table=t
        C.applied=true
        C.mode="VIRTUAL REACH + REAR ARC + ELEVATION (NO PHYSICS)"
        C.status="INCREASED CLIENT BITE CLAIM WINDOW"
        C.installCount+=1
        C.lastError=""
        return true
    end
    function C.compare(char,ownRoot,ownHum,enemyRoot,enemyHum)
        local native=C.original or C.table and snapshot(C.table)
        if not native then
            local t=cfgNow()
            if not t then return nil,nil end
            native=snapshot(t)
        end
        local base=Reach.geometry(native,ownRoot,ownHum,enemyRoot,enemyHum,char)
        local applied=C.applied and C.table or nil
        local boosted=applied and Reach.geometry(snapshot(applied),
            ownRoot,ownHum,enemyRoot,enemyHum,char) or base
        return base,boosted
    end
    function C.report()
        local native=C.original
        local t=C.table
        return table.concat({
            "FERAL NOVA PRIME v14.1 | Bite Reach / Rear Arc / Elevated Targets",
            "enabled="..tostring(C.enabled).." applied="..tostring(C.applied),
            "mode="..C.mode,
            "status="..C.status,
            "original_reach="..tostring(native and native.REACH),
            "client_reach="..tostring(t and t.REACH),
            "original_hit_scale="..tostring(native and native.HIT_SCALE),
            "client_hit_scale="..tostring(t and t.HIT_SCALE),
            "original_cone="..tostring(native and native.CONE),
            "client_cone="..tostring(t and t.CONE),
            "virtual_body_gap_bonus_studs="..(C.applied and "0.84" or "0"),
            "client_max_dy="..tostring(t and t.MAX_DY),
            "rear_half_arc_degrees="..tostring(t and t.CONE),
            "physical_enemy_parts_resized=0",
            "install_count="..C.installCount,
            "restored_fields="..C.reverts,
            "external_config_conflicts="..C.externalChanges,
            "server_damage_acceptance="..C.benefit,
            "last_error="..C.lastError,
            "NOTE=Claim geometry and virtual hitbox are local to the game's client.",
            "NOTE=Server may reject extended range; use the bite observations report."
        },"\n")
    end
    function C.close()
        if not C.alive then return end
        C.alive=false
        C.setEnabled(false)
        if C.connection then C.connection:Disconnect()end
    end
    C.connection=RunService.Heartbeat:Connect(function()
        if not C.alive or not ctx.state.alive then return end
        local now=os.clock()
        if now<C.nextTick then return end
        C.nextTick=now+1.25
        if C.enabled then
            -- Auto-install if loaded in the menu before FeralWorld exists.
            local ok,err=pcall(C.setEnabled,true)
            if not ok then
                C.lastError=tostring(err)
                C.status="CLAIM CONFIG ERROR"
                C.enabled=false
            end
        end
    end)
    return C
end
return Reach
