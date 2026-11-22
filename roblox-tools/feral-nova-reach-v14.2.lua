-- FERAL NOVA PRIME v14.2 / Native tree-climb biteLook and vertical-combat targeting.
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
        coneFor=t.coneFor,dyMult=t.dyMult,biteLook=t.biteLook}
end
local function vecFlat(v)
    return Vector3.new(v.X,0,v.Z)
end
local function climbing(character)
    return character and character.Parent
        and character:GetAttribute("FeralClimbLocal")==true
end
-- The native climbing controller records the tree base and trunk radius.
-- Prefer exact same-tree geometry when available; otherwise allow only
-- nearby, already-climbing characters as a low-confidence fallback.
local function treeMatch(char,other,root,otherRoot)
    if not (climbing(char) and other and other.Parent and otherRoot) then
        return false,false
    end
    local a=char:GetAttribute("FeralClimbAxis")
    local b=other:GetAttribute("FeralClimbAxis")
    local ar=char:GetAttribute("FeralClimbR")
    local br=other:GetAttribute("FeralClimbR")
    local otherClimbing=other:GetAttribute("FeralClimbLocal")==true
        or other:GetAttribute("FeralClimb")~=nil
    if not otherClimbing then return false,false end
    local d=otherRoot.Position-root.Position
    local flat=Vector3.new(d.X,0,d.Z).Magnitude
    if flat>22 or math.abs(d.Y)>27 then return false,false end
    if typeof(a)=="Vector3" and typeof(b)=="Vector3" then
        local radiusOK=type(ar)~="number" or type(br)~="number"
            or math.abs(ar-br)<4
        local exact=(a-b).Magnitude<5 and radiusOK
        return exact,exact
    end
    return flat<9 and math.abs(d.Y)<22,false
end
local function ownedCompare(patch)
    for _,e in ipairs(patch or {}) do
        if e.table[e.key]~=e.wanted then return false end
    end
    return patch and #patch>0
end
function Reach.geometry(values, ownRoot,ownHum,enemyRoot,enemyHum,character,treeBoost)
    if not values or not ownRoot or not enemyRoot
        or not ownHum or not enemyHum then return nil end
    local diff=enemyRoot.Position-ownRoot.Position
    local flat=vecFlat(diff)
    local fwd=vecFlat(ownRoot.CFrame.LookVector)
    local climbTarget=treeBoost and treeMatch(character,
        enemyRoot.Parent,ownRoot,enemyRoot)
    if fwd.Magnitude<.01 then
        if not climbTarget then return nil end
        -- Native WolfController returns nil in this case. Extended
        -- geometry can still describe the close tree target, but it is
        -- never represented as native bite confirmation.
        fwd=flat.Magnitude>.05 and flat
            or vecFlat(ownRoot.CFrame.UpVector)
        if fwd.Magnitude<.01 then return nil end
    end
    fwd=fwd.Unit
    if type(values.biteLook)=="function" then
        local ok,v=pcall(values.biteLook,character,fwd)
        if ok and typeof(v)=="Vector3" then
            v=vecFlat(v)
            if v.Magnitude>.01 then fwd=v.Unit end
        end
    end
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
        distance=flat.Magnitude,margin=reach-gap,
        treeBoosted=climbTarget==true}
end
function Reach.attach(ctx)
    local C={
        enabled=false,applied=false,alive=true,mode="OFF",
        status="OFF",lastError="",installCount=0,
        externalChanges=0,reverts=0,
        lease=nil,original=nil,table=nil,claimedWindows=0,
        baselineDistance=0,boostDistance=0,benefit="SERVER UNVERIFIED",
        nextTick=0,
        treeWindowReadCount=0,treeSameTrunkHits=0,
        treeAimPatches=0,treeVerticalPatches=0,
        treeLastStatus="WAITING",treeClaimServerAccepted="UNVERIFIED",
        treeCacheChar=nil,treeCacheRoot=nil,treeCacheTarget=nil,
        treeCacheAt=-math.huge,treeCacheHits=0
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
    function C.sameTree(char,enemy,ownRoot,enemyRoot)
        ownRoot=ownRoot or char and char:FindFirstChild("HumanoidRootPart")
        enemyRoot=enemyRoot or enemy and enemy:FindFirstChild("HumanoidRootPart")
        if not ownRoot or not enemyRoot then return false,false end
        return treeMatch(char,enemy,ownRoot,enemyRoot)
    end
    function C.treeTarget(char,root,limit)
        if not climbing(char) then return nil end
        root=root or char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        limit=type(limit)=="number" and math.clamp(limit,7,38) or 27
        local now=os.clock()
        if C.treeCacheChar==char and C.treeCacheRoot==root
            and now-C.treeCacheAt<.085 then
            C.treeCacheHits+=1
            local previous=C.treeCacheTarget
            if previous and previous.root and previous.root.Parent
                and (previous.root.Position-root.Position).Magnitude<=limit then
                return previous
            end
            return nil
        end
        C.treeCacheChar=char
        C.treeCacheRoot=root
        C.treeCacheAt=now
        C.treeCacheTarget=nil
        local ownPack=player:GetAttribute("FeralPack")
        local best,bestScore=nil,math.huge
        local function consider(model)
            if model==char or not model or not model.Parent
                or model:GetAttribute("FeralDead")==true then return end
            local enemyRoot=model:FindFirstChild("HumanoidRootPart")
            local enemyHum=model:FindFirstChildOfClass("Humanoid")
            if not enemyRoot or not enemyHum or enemyHum.Health<=0 then return end
            local enemyPack=model:GetAttribute("FeralPack")
            if ownPack~=nil and enemyPack~=nil and ownPack==enemyPack then return end
            local same,certain=treeMatch(char,model,root,enemyRoot)
            if not same then return end
            local diff=enemyRoot.Position-root.Position
            local distance=diff.Magnitude
            if distance>limit then return end
            local flat=Vector3.new(diff.X,0,diff.Z)
            local score=distance+math.abs(diff.Y)*.08
                +(certain and 0 or 2)
            if score<bestScore then
                bestScore=score
                best={model=model,root=enemyRoot,hum=enemyHum,
                    distance=distance,flat=flat,diff=diff,
                    certain=certain,sameTree=true}
            end
        end
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player and other.Character then consider(other.Character) end
        end
        local folder=workspace:FindFirstChild("FeralNPCs")
        if folder then
            local n=0
            for _,model in ipairs(folder:GetChildren()) do
                n+=1;if n>50 then break end
                if model:IsA("Model") then consider(model) end
            end
        end
        C.treeWindowReadCount+=1
        C.treeCacheTarget=best
        if best then
            C.treeSameTrunkHits+=1
            C.treeLastStatus=best.certain and "SAME TRUNK VERIFIED"
                or "NEARBY CLIMBER / TREE ESTIMATED"
        else
            C.treeLastStatus="NO TREE TARGET"
        end
        return best
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
        -- Do not alter normal ground/air bite aim. Only while actively
        -- climbing and near another climber do we compensate for the
        -- trunk-facing alignment and elevated target separation.
        desired.biteLook=function(char,forward)
            local nativeLook=forward
            if type(original.biteLook)=="function" then
                local ok,v=pcall(original.biteLook,char,forward)
                if ok and typeof(v)=="Vector3" and v.Magnitude>.01 then
                    nativeLook=v
                end
            end
            if not climbing(char) then return nativeLook end
            local root=char:FindFirstChild("HumanoidRootPart")
            local picked=root and C.treeTarget(char,root,27) or nil
            if picked and picked.flat.Magnitude>.05 then
                C.treeAimPatches+=1
                return picked.flat.Unit
            end
            return nativeLook
        end
        desired.dyMult=function(char)
            local base=1
            if type(original.dyMult)=="function" then
                local ok,v=pcall(original.dyMult,char)
                if ok and good(v) and v>0 then base=v end
            end
            if not climbing(char) then return base end
            local root=char:FindFirstChild("HumanoidRootPart")
            local picked=root and C.treeTarget(char,root,27) or nil
            if picked then
                C.treeVerticalPatches+=1
                return math.min(base*2.15,3.2)
            end
            return base
        end
        -- Only client claim geometry; real character/enemy parts unchanged.
        desired.bodyGap=function(part,flat)
            local gap=original.bodyGap(part,flat)
            if not good(gap) then return gap end
            return gap-.84
        end
        local lease={}
        for _,key in ipairs({"REACH","HIT_SCALE","CONE","SLACK","MAX_DY","bodyGap","biteLook","dyMult"}) do
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
        C.mode="VIRTUAL REACH + REAR ARC + ELEVATION + TREE FIGHT AIM (NO PHYSICS)"
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
        local base=Reach.geometry(native,ownRoot,ownHum,enemyRoot,enemyHum,char,false)
        local applied=C.applied and C.table or nil
        local boosted=applied and Reach.geometry(snapshot(applied),
            ownRoot,ownHum,enemyRoot,enemyHum,char,true) or base
        return base,boosted
    end
    function C.report()
        local native=C.original
        local t=C.table
        return table.concat({
            "FERAL NOVA PRIME v14.2 | Bite Reach / Tree Fight Assist / Elevation",
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
            "tree_combat_mode=CLIMB_ONLY_WHEN_TARGET_NEARBY",
            "tree_trunk_checks="..C.treeWindowReadCount,
            "tree_scan_cache_hits="..C.treeCacheHits,
            "tree_target_checks_with_nearby_climber="..C.treeSameTrunkHits,
            "tree_aim_overrides="..C.treeAimPatches,
            "tree_height_allowance_overrides="..C.treeVerticalPatches,
            "tree_last_status="..C.treeLastStatus,
            "tree_server_accepted="..C.treeClaimServerAccepted,
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
