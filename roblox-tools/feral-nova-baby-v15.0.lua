-- FERAL NOVA PRIME v15 / Same-species baby pickup protection.
-- This protects the user's infant from Auto Escape's getoff requests.
-- It never grants a pickup or sends any carry action itself.
local Baby={}
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function number(x)
    return type(x)=="number" and x==x and x>=0 and x<10
end
local function targetOf(clamp,baby)
    if not clamp or not clamp:IsA("ObjectValue") then return false end
    local target=clamp.Value
    if not target then return false end
    if target==baby then return true end
    local ok,value=pcall(function()return target:IsDescendantOf(baby)end)
    return ok and value==true
end
function Baby.eligible(baby,adult)
    if not baby or not adult or not baby.Parent or not adult.Parent
        or baby==adult then return false end
    if baby:GetAttribute("FeralPinned")==true
        or baby:GetAttribute("FeralDragged")==true then return false end
    local bs= baby:GetAttribute("Species")
    local adultSpecies=adult:GetAttribute("Species")
    local bg=baby:GetAttribute("Growth")
    local ag=adult:GetAttribute("Growth")
    return type(bs)=="string" and bs~="" and bs==adultSpecies
        and number(bg) and bg<=.34 and number(ag) and ag>=.67
end
function Baby.carrierEvidence(baby,adult)
    if not Baby.eligible(baby,adult) then
        return false,"NOT ELIGIBLE"
    end
    local clamp=adult:FindFirstChild("FeralClamp")
    if targetOf(clamp,baby) then
        return true,"CONFIRMED OUTGOING CLAMP"
    end
    local localClamp=adult:FindFirstChild("FeralClampLocal")
    if targetOf(localClamp,baby) then
        return true,"CONFIRMED LOCAL OUTGOING CLAMP"
    end
    local b= baby:FindFirstChild("HumanoidRootPart")
    local a=adult:FindFirstChild("HumanoidRootPart")
    if b and a then
        local ok,d=pcall(function()
            return (b.Position-a.Position).Magnitude
        end)
        if ok and type(d)=="number" and d<=12 then
            return true,"SAME-SPECIES ADULT NEARBY"
        end
    end
    return false,"NO MATCHING CARRIER"
end
function Baby.attach(ctx)
    local B={
        alive=true,enabled=true,active=false,
        status="ARMED / BABY PICKUP PROTECTION",
        lastEvidence="NONE",lastCarrierSpecies="",
        friendlyFrames=0,confirmedFrames=0,
        proximityFrames=0,hostileFrames=0,
        sameSpeciesAdultCandidates=0,
        episodes=0,protectedSeconds=0,
        maxProximityTrustSeconds=12,
        firstProximityAt=0,
        lastUpdate=0,lastFriendlyAt=0,
        nextCheck=0,lastCharacter=nil
    }
    function B.setEnabled(value)
        B.enabled=value==true
        if not B.enabled then
            B.active=false;B.status="OFF / ALL CAPTURES ESCAPED NORMALLY"
        else
            B.status="ARMED / ELIGIBLE BABY ONLY"
        end
    end
    function B.shouldProtect(baby,now)
        now=now or os.clock()
        if not B.enabled or not baby or not baby.Parent then
            B.active=false
            return false,"DISABLED / NO BABY"
        end
        if baby~=B.lastCharacter then
            B.lastCharacter=baby
            B.active=false
            B.firstProximityAt=0
        end
        if baby:GetAttribute("FeralPinned")==true
            or baby:GetAttribute("FeralDragged")==true then
            B.active=false
            B.hostileFrames+=1
            B.status="PINNED/DRAGGED / ESCAPE ALWAYS WINS"
            return false,"HOSTILE CONTROL"
        end
        if baby:GetAttribute("FeralCarried")~=true then
            B.active=false
            B.firstProximityAt=0
            B.status="WAITING FOR INFANT PICKUP"
            return false,"NOT BEING CARRIED"
        end
        local growth=baby:GetAttribute("Growth")
        if not number(growth) or growth>.34 then
            B.active=false
            B.status="NOT IN BABY GROWTH RANGE"
            return false,"ADULT / UNKNOWN GROWTH"
        end
        local chosen,kind
        local count=0
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player then
                local adult=other.Character
                if Baby.eligible(baby,adult) then
                    count+=1
                    local ok,why=Baby.carrierEvidence(baby,adult)
                    if ok then
                        chosen=adult
                        kind=why
                        if why~="SAME-SPECIES ADULT NEARBY" then
                            break
                        end
                    end
                end
            end
        end
        B.sameSpeciesAdultCandidates=count
        if not chosen then
            B.active=false
            B.firstProximityAt=0
            B.status="NO VERIFIED FRIENDLY CARRIER / ESCAPE NORMAL"
            return false,"NO CARRIER"
        end
        local confirmed=kind~="SAME-SPECIES ADULT NEARBY"
        if confirmed then
            B.firstProximityAt=0
            B.confirmedFrames+=1
        else
            if B.firstProximityAt==0 then
                B.firstProximityAt=now
            end
            if now-B.firstProximityAt>B.maxProximityTrustSeconds then
                B.active=false
                B.status="NO CARRIER CLAMP CONFIRMED / ESCAPE RESUMES"
                return false,"PROXIMITY EXPIRED"
            end
            B.proximityFrames+=1
        end
        if not B.active then B.episodes+=1 end
        B.active=true
        B.lastFriendlyAt=now
        B.lastEvidence=kind
        B.lastCarrierSpecies=tostring(chosen:GetAttribute("Species") or "")
        B.friendlyFrames+=1
        B.status=confirmed
            and "FRIENDLY BABY CARRY CONFIRMED / GETOFF BLOCKED"
            or "SAME-SPECIES ADULT NEARBY / SHORT GETOFF GRACE"
        return true,kind
    end
    function B.report()
        return table.concat({
            "FERAL NOVA PRIME v15 | Friendly Baby Carry",
            "enabled="..tostring(B.enabled)..
                " friendly_carry_protected_now="..tostring(B.active),
            "status="..B.status,
            "last_carrier_evidence="..B.lastEvidence,
            "same_species_adults_eligible="..B.sameSpeciesAdultCandidates,
            "friendly_carry_episodes="..B.episodes,
            "confirmed_clamp_observations="..B.confirmedFrames,
            "proximity_fallback_observations="..B.proximityFrames,
            "proximity_grace_max_seconds="..B.maxProximityTrustSeconds,
            "hostile_pin_or_drag_overrides="..B.hostileFrames,
            "NOTE=Only Growth<=.34 with same-species adult Growth>=.67.",
            "NOTE=Pinned/dragged overrides friendly protection immediately.",
            "NOTE=Proximity alone cannot prove consent; disable protection if needed."
        },"\n")
    end
    function B.close()
        B.enabled=false;B.alive=false;B.active=false
    end
    return B
end
return Baby
