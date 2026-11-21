-- FERAL NOVA v8.0 Foundation / shared observational action policy
-- Central state reader; no remote calls, state mutation or movement.
local Coordinator={}
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local function isFinite(v)
    return type(v)=="number" and v==v and math.abs(v)<1e12
end
function Coordinator.attach(ctx)
    local A={alive=true,reads=0,combatReads=0,blockedReads=0,lastReason="STARTING"}
    function A.snapshot()
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local result={
            char=char,hum=hum,root=root,healthy=false,
            blocked=false,reason="NO ANIMAL",
            attackHeld=false,aimedBite=false,combat=false,
            victim=false,holding=false,locomotion="UNKNOWN",
        }
        A.reads+=1
        if not char or not char.Parent or not hum or hum.Health<=0 or not root then
            A.blockedReads+=1
            return result
        end
        result.healthy=hum.Health>0
        local heldOK,held=pcall(function()
            return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        end)
        result.attackHeld=heldOK and held==true
        local lab=ctx.lab
        result.aimedBite=lab and lab.alive and lab.enabled
            and (lab.nativeReady==true or lab.ready==true) or false
        local nowOK,now=pcall(function()return workspace:GetServerTimeNow()end)
        local untilAt=player:GetAttribute("FeralCombatUntil")
        local ownAt=char:GetAttribute("FeralCombatUntil")
        if isFinite(ownAt) and (not isFinite(untilAt) or ownAt>untilAt) then
            untilAt=ownAt
        end
        result.combat=nowOK and isFinite(now) and isFinite(untilAt)
            and untilAt>now or false
        if result.combat then A.combatReads+=1 end
        if ctx.carry and type(ctx.carry.classify)=="function" then
            local ok,_,holding,victim=pcall(ctx.carry.classify,char)
            if ok then
                result.holding=holding==true
                result.victim=victim==true
            end
        end
        result.victim=result.victim or char:GetAttribute("FeralPinned")==true
            or char:GetAttribute("FeralDragged")==true
            or char:GetAttribute("FeralCarried")==true
        local stateOK,state=pcall(function()return hum:GetState()end)
        result.locomotion=stateOK and state.Name or "UNKNOWN"
        if player:GetAttribute("FeralMenuOpen")==true then
            result.reason="IN MENU"
        elseif result.combat then
            result.reason="COMBAT TAG"
        elseif result.attackHeld or result.aimedBite then
            result.reason="BITE PRIORITY"
        elseif result.victim or result.holding then
            result.reason="CARRY OR ESCAPE"
        elseif char:GetAttribute("WolfRest")==true then
            result.reason="VISIBLE REST"
        elseif hum.Sit or hum.PlatformStand then
            result.reason="SEATED OR STUNNED"
        elseif result.locomotion=="Swimming" or result.locomotion=="Climbing"
            or result.locomotion=="Freefall" or result.locomotion=="FallingDown"
            or result.locomotion=="Flying" or result.locomotion=="Dead" then
            result.reason="UNSAFE LOCOMOTION"
        else
            result.reason="SAFE INPUT WINDOW"
        end
        result.blocked=result.reason~="SAFE INPUT WINDOW"
        A.lastReason=result.reason
        if result.blocked then A.blockedReads+=1 end
        return result
    end
    function A.report()
        return table.concat({
            "FERAL NOVA v8.0 | Shared Action Policy",
            "alive="..tostring(A.alive),
            "read_only=true",
            "checks="..A.reads,
            "combat_checks="..A.combatReads,
            "unsafe_checks="..A.blockedReads,
            "last_policy="..A.lastReason
        },"\n")
    end
    function A.close()
        A.alive=false
    end
    return A
end
return Coordinator