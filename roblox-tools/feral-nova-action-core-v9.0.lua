-- FERAL NOVA CORE v9.0 / central, side-effect-free action arbiter
-- All gameplay-effecting modules retain ownership of their original game
-- interactions. This module only grants/rejects safe windows.
-- No remote traffic, movement, attribute writes, player identifiers or HTTP.
local Coordinator={}
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local function finite(n)
    return type(n)=="number" and n==n and math.abs(n)<1e12
end
local function stateName(hum)
    local ok,value=pcall(function()return hum:GetState()end)
    return ok and value and value.Name or "UNKNOWN"
end
local priority={
    GRAB_MINIGAME=100, CAPTURED=95, COMBAT=90,
    ATTACK=85, BITE_WINDOW=80, CARRY=70, CLIMB=60,
    FLIGHT=55, REAL_REST=50, AFK_WALK=35, IDLE=0
}
function Coordinator.attach(ctx)
    local A={
        alive=true,reads=0,cacheHits=0,lastRead=-math.huge,
        lastSnapshot=nil,lastPriority="STARTING",lastReason="STARTING",
        decisions=0,denied=0,denials={},allowedCounts={},
        transitions=0,lastState="",reserveCalls=0,
        lease=nil,leaseCount=0,expiredLeases=0,
    }
    local function now()return os.clock()end
    function A.reserve(owner,seconds)
        -- Higher priority actual actions can displace a lower-priority lease.
        if not A.alive or (owner~="minigame" and owner~="afk_walk") then
            return false,"UNKNOWN OWNER"
        end
        if not finite(seconds) or seconds<=0 or seconds>12 then
            return false,"UNBOUNDED LEASE"
        end
        local t=now()
        if A.lease and A.lease.expires<=t then
            A.lease=nil
            A.expiredLeases+=1
        end
        if A.lease and A.lease.owner~=owner
            and A.lease.owner=="minigame" then
            return false,"MINIGAME PRIORITY"
        end
        A.lease={owner=owner,expires=t+seconds}
        A.reserveCalls+=1
        A.leaseCount+=1
        A.lastRead=-math.huge
        return true,"GRANTED"
    end
    function A.release(owner)
        if A.lease and A.lease.owner==owner then
            A.lease=nil
            A.lastRead=-math.huge
            return true
        end
        return false
    end
    local function leaseOwner()
        if not A.lease then return nil end
        if now()>=A.lease.expires then
            A.lease=nil
            A.expiredLeases+=1
            return nil
        end
        return A.lease.owner
    end
    function A.snapshot(force)
        local t=now()
        if not force and A.lastSnapshot and t-A.lastRead<.06 then
            A.cacheHits+=1
            return A.lastSnapshot
        end
        local char=player and player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local S={
            char=char,hum=hum,root=root,alive=false,
            combat=false,combatTimeUnknown=false,
            attackHeld=false,nativeBite=false,extendedHint=false,
            victim=false,holding=false,grab=false,afkMoving=false,
            menu=false,chat=false,visibleRest=false,locomotion="UNKNOWN",
            lease=leaseOwner(),priority="IDLE",reason="NO ANIMAL",
            danger=false,blocked=true,
        }
        A.reads+=1
        if char and char.Parent and hum and hum.Health>0 and root then
            S.alive=true
            local ok,held=pcall(function()
                return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                    or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
            end)
            S.attackHeld=ok and held==true
            local guide=ctx.lab
            S.nativeBite=guide and guide.alive and guide.enabled
                and guide.nativeReady==true or false
            S.extendedHint=guide and guide.alive and guide.enabled
                and guide.ready==true or false
            local untilAt=player:GetAttribute("FeralCombatUntil")
            local animalAt=char:GetAttribute("FeralCombatUntil")
            if finite(animalAt) and
                (not finite(untilAt) or animalAt>untilAt) then
                untilAt=animalAt
            end
            if finite(untilAt) then
                local timeOK,serverNow=pcall(function()
                    return workspace:GetServerTimeNow()
                end)
                if not timeOK or not finite(serverNow) then
                    S.combatTimeUnknown=true
                else
                    S.combat=untilAt>serverNow
                end
            end
            if ctx.carry and type(ctx.carry.classify)=="function" then
                local yes,_,holding,victim=pcall(ctx.carry.classify,char)
                if yes then
                    S.holding=holding==true
                    S.victim=victim==true
                end
            end
            S.victim=S.victim or char:GetAttribute("FeralPinned")==true
                or char:GetAttribute("FeralDragged")==true
                or char:GetAttribute("FeralCarried")==true
            S.grab=ctx.grabMini and ctx.grabMini.activeSession==true or false
            S.afkMoving=ctx.afk and ctx.afk.travelActive==true or false
            S.menu=player:GetAttribute("FeralMenuOpen")==true
            local chatOK,focused=pcall(function()
                return UIS:GetFocusedTextBox()
            end)
            S.chat=chatOK and focused~=nil and focused~=false
            S.visibleRest=char:GetAttribute("WolfRest")==true
            S.locomotion=stateName(hum)
            local priorityName="IDLE"
            if S.grab or S.lease=="minigame" then
                priorityName="GRAB_MINIGAME"
            elseif S.victim then priorityName="CAPTURED"
            elseif S.combat or S.combatTimeUnknown then
                priorityName="COMBAT"
            elseif S.attackHeld then priorityName="ATTACK"
            elseif S.nativeBite then priorityName="BITE_WINDOW"
            elseif S.holding then priorityName="CARRY"
            elseif S.locomotion=="Climbing" then priorityName="CLIMB"
            elseif S.locomotion=="Swimming" or S.locomotion=="Flying"
                or S.locomotion=="Freefall" then
                priorityName="FLIGHT"
            elseif S.visibleRest then priorityName="REAL_REST"
            elseif S.afkMoving or S.lease=="afk_walk" then
                priorityName="AFK_WALK"
            end
            S.priority=priorityName
            S.priorityRank=priority[priorityName] or -1
            S.reason=priorityName
            S.danger=S.combat or S.victim or S.grab
                or S.attackHeld or S.nativeBite
            S.blocked=S.danger or S.visibleRest or S.holding
                or priorityName=="CLIMB" or priorityName=="FLIGHT"
        end
        if not S.alive then S.priority="NO ANIMAL" end
        if A.lastState~=S.priority then
            A.transitions+=1
            A.lastState=S.priority
        end
        A.lastPriority=S.priority
        A.lastReason=S.reason
        A.lastRead=t
        A.lastSnapshot=S
        return S
    end
    function A.allowed(mode,previous)
        local S=previous or A.snapshot(true)
        local reason=nil
        if not A.alive then reason="CLOSED"
        elseif not S or not S.alive then reason="NO ANIMAL"
        elseif mode=="recovery" then
            -- Do not drop recovery because an enlarged *client-only*
            -- target hint is true: only original native bite readiness
            -- has the authority to preempt actual attacks.
            if S.grab or S.lease=="minigame" then reason="GRAB MINIGAME"
            elseif S.victim then reason="CAPTURED"
            elseif S.combat then reason="COMBAT TAG"
            elseif S.combatTimeUnknown then reason="COMBAT CLOCK UNKNOWN"
            elseif S.attackHeld then reason="ATTACK HELD"
            elseif S.nativeBite then reason="NATIVE BITE RANGE"
            -- Merely holding already-captured prey is NOT a new carry
            -- action. Preserve v8.1 mobile recovery uptime outside combat;
            -- the G input still invokes Native.beforeCarry() immediately.
            elseif S.afkMoving or S.lease=="afk_walk" then
                reason="SAFE AFK WALK"
            elseif S.menu then reason="MENU" end
        elseif mode=="afk_walk" then
            if S.menu or S.chat then reason="MENU OR CHAT"
            elseif S.grab or S.lease=="minigame" then reason="GRAB MINIGAME"
            elseif S.victim or S.holding then reason="CARRY"
            elseif S.combat or S.combatTimeUnknown then reason="COMBAT"
            elseif S.attackHeld or S.nativeBite or S.extendedHint then
                reason="BITE TARGET OR INPUT"
            elseif S.visibleRest then reason="VISIBLE REST"
            elseif S.afkMoving then reason="ALREADY WALKING"
            elseif S.locomotion=="Swimming" or S.locomotion=="Climbing"
                or S.locomotion=="Freefall" or S.locomotion=="FallingDown"
                or S.locomotion=="Flying" or S.locomotion=="Dead" then
                reason="UNSAFE LOCOMOTION"
            end
        elseif mode=="grab_press" then
            if not S.grab then reason="NO NATIVE GRAB SESSION"
            elseif S.menu or S.chat then reason="MENU OR CHAT"
            end
        elseif mode=="climb" then
            if S.grab or S.lease=="minigame" then reason="GRAB PRIORITY"
            elseif S.menu or S.chat then reason="MENU OR CHAT" end
        elseif mode=="carry" then
            if S.grab or S.lease=="minigame" then reason="GRAB PRIORITY"
            elseif S.menu or S.chat then reason="MENU OR CHAT" end
        else reason="UNKNOWN POLICY"
        end
        A.decisions+=1
        if reason then
            A.denied+=1
            A.denials[mode..":"..reason]=(A.denials[mode..":"..reason] or 0)+1
            return false,reason
        end
        A.allowedCounts[mode]=(A.allowedCounts[mode] or 0)+1
        return true,"SAFE"
    end
    function A.report()
        local denials={}
        for key,n in pairs(A.denials) do
            denials[#denials+1]={key=key,count=n}
        end
        table.sort(denials,function(a,b)return a.count>b.count end)
        local lines={
            "FERAL NOVA CORE v9.0 | Unified Action Policy",
            "alive="..tostring(A.alive),
            "side_effects=NONE",
            "snapshot_reads="..A.reads,
            "snapshot_cache_hits="..A.cacheHits,
            "priority_transitions="..A.transitions,
            "current_priority="..A.lastPriority,
            "decisions="..A.decisions,
            "denied="..A.denied,
            "leases_granted="..A.reserveCalls,
            "leases_expired="..A.expiredLeases,
            "active_lease="..tostring(leaseOwner()),
            "native_bite_preempts_rest=true",
            "extended_local_hint_does_not_preempt_rest=true",
        }
        for i=1,math.min(8,#denials) do
            lines[#lines+1]="denial_"..i.."="..
                denials[i].key..":"..denials[i].count
        end
        return table.concat(lines,"\n")
    end
    function A.close()
        A.alive=false
        A.lease=nil
        A.lastSnapshot=nil
    end
    return A
end
return Coordinator