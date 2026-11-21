-- FERAL NOVA v11.3 / processed-Q protection and responsive climb buffer.
-- Adapted from the separately validated Quick Climb v1.0.
-- No injected tree geometry, no fabricated climbing server remotes.
local Climb={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
function Climb.attach(ctx)
    local env
    if type(getgenv)=="function" then
        local ok,g=pcall(getgenv)
        if ok and type(g)=="table" then env=g end
    end
    if env and type(env.FERALQuickClimbV1)=="table"
        and type(env.FERALQuickClimbV1.close)=="function" then
        pcall(env.FERALQuickClimbV1.close)
    end
    local Q={
        alive=true,enabled=true,ready=false,queued=false,
        status="WAITING FOR CLIMBABLE ANIMAL",lastError="",
        configReady=false,sprintGrabPatch=false,
        queuedPresses=0,expiredPresses=0,gameTaps=0,
        observedMounts=0,suppressedDives=0,suppressedConflicts=0,
        retries=0,retrySuppressed=0,retapsForPress=0,
        next=0,lastTap=-math.huge,pendingUntil=0,
        lastChar=nil,awaitingMount=false,awaitUntil=0,
        firstReadyAt=0,configLease=nil
    }
    local connections={}
    local function finite(v)
        return type(v)=="number" and v==v and v<1e8 and v>-1e8
    end
    local function lease(tbl,key,value,list)
        if type(tbl)~="table" then return false end
        local original=tbl[key]
        if original==nil then return false end
        if original==value then return true end
        local ok=pcall(function()tbl[key]=value end)
        if not ok or tbl[key]~=value then return false end
        list[#list+1]={tbl=tbl,key=key,original=original,wanted=value}
        return true
    end
    local function release()
        for i=#(Q.configLease or {}),1,-1 do
            local e=Q.configLease[i]
            pcall(function()
                if e.tbl[e.key]==e.wanted then e.tbl[e.key]=e.original end
            end)
        end
        Q.configLease=nil
        Q.configReady=false
        Q.sprintGrabPatch=false
    end
    local function install()
        if Q.configReady then return true end
        local world=RS:FindFirstChild("FeralWorld")
        local mod=world and world:FindFirstChild("PassiveConfig")
        if not mod or not mod:IsA("ModuleScript") then
            Q.status="PASSIVE CONFIG UNAVAILABLE"
            return false
        end
        local ok,v=pcall(require,mod)
        local c=ok and type(v)=="table" and v.CLIMBER
        if type(c)~="table" or type(c.levels)~="table"
            or not finite(c.GRAB_REACH) or not finite(c.E_REACH)
            or not finite(c.GRAB_FACING) or not finite(c.MOUNT_TIME) then
            Q.status="CLIMB CONFIG NOT COMPATIBLE"
            return false
        end
        local changes={}
        local work={
            {"GRAB_REACH",math.min(1.25,c.GRAB_REACH*1.30)},
            {"E_REACH",math.min(2.1,c.E_REACH*1.25)},
            {"GRAB_FACING",math.max(.25,c.GRAB_FACING*.58)},
            {"MOUNT_TIME",math.max(.22,c.MOUNT_TIME*.75)},
            {"HINT_RANGE",math.min(20,(c.HINT_RANGE or 14)*1.25)}
        }
        for _,entry in ipairs(work) do
            lease(c,entry[1],entry[2],changes)
        end
        local sprintGranted=false
        for _,level in ipairs({1,2}) do
            local l=c.levels[level]
            if type(l)=="table" and l.sprintGrab~=true then
                -- Source blocks basic climbers from catching a tree at
                -- sprint velocity; this is the main chase nuisance.
                if l.sprintGrab==nil then
                    -- Nil fields require special restoration.
                    local setOk=pcall(function()l.sprintGrab=true end)
                    if setOk and l.sprintGrab==true then
                        changes[#changes+1]={
                            tbl=l,key="sprintGrab",original=nil,wanted=true}
                        sprintGranted=true
                    end
                else
                    if lease(l,"sprintGrab",true,changes) then
                        sprintGranted=true
                    end
                end
            end
        end
        Q.configLease=changes
        Q.sprintGrabPatch=sprintGranted
        Q.configReady=true
        Q.status="FAST MOUNT SETTINGS READY • Q BUFFER ON"
        return true
    end
    local function validChar(char)
        if not char or not char.Parent then return false end
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health<=0 or char:GetAttribute("FeralDead")==true then
            return false
        end
        local lv=char:GetAttribute("PassiveClimber")
        return finite(lv) and lv>=1
    end
    local function unsafe(char)
        return char:GetAttribute("FeralClimbLocal")==true
            or char:GetAttribute("FeralPinned")==true
            or char:GetAttribute("FeralCarried")==true
            or char:GetAttribute("WolfRest")==true
            or char:GetAttribute("WolfFeed")==true
            or char:GetAttribute("FeralDiving")==true
            or char:FindFirstChild("FeralClamp")~=nil
            or char:FindFirstChild("FeralClampLocal")~=nil
    end
    local function climbAllowed()
        if not ctx.action or type(ctx.action.allowed)~="function" then
            return true
        end
        local ok,allowed,reason=pcall(ctx.action.allowed,"climb")
        if not ok then return false,"ACTION CORE ERROR" end
        return allowed,reason
    end
    local function onQ(now)
        if not Q.enabled or not Q.alive then return end
        if UIS:GetFocusedTextBox() then return end
        local char=player.Character
        if not validChar(char) then
            Q.status="THIS ANIMAL CANNOT CLIMB YET"
            return
        end
        if char:GetAttribute("FeralClimbLocal")==true then
            Q.queued=false
            Q.status="ALREADY CLIMBING • NATIVE Q HANDLES LET-GO"
            return
        end
        -- The same Q may be used to dive. Never invoke the climb
        -- tap listener when the local game is offering DiveCan.
        if char:GetAttribute("DiveCan")==true then
            Q.queued=false
            Q.suppressedDives+=1
            Q.status="DIVE HAS PRIORITY"
            return
        end
        if unsafe(char) then
            Q.queued=false
            Q.suppressedConflicts+=1
            Q.status="BUSY / CARRY, REST OR GRAB PRIORITY"
            return
        end
        local allowed,why=climbAllowed()
        if not allowed then
            Q.queued=false
            Q.suppressedConflicts+=1
            Q.status="ACTION PRIORITY / "..tostring(why)
            return
        end
        -- A Q pressed before the first heartbeat must survive the
        -- initial character sample; only an actual respawn clears it.
        Q.lastChar=char
        if ctx.native and ctx.native.beforeClimb then
            pcall(ctx.native.beforeClimb)
        end
        Q.pendingUntil=now+2.25
        Q.retapsForPress=0
        Q.queued=true
        Q.queuedPresses+=1
        Q.status="Q BUFFERED • RUN TOWARD TREE"
    end
    local function tick()
        if not Q.alive then return end
        local now=os.clock()
        if now<Q.next then return end
        Q.next=now+.055
        if Q.enabled and not Q.configReady then install()end
        local char=player.Character
        if char~=Q.lastChar then
            Q.lastChar=char;Q.queued=false
            Q.awaitingMount=false;Q.ready=false;Q.retapsForPress=0
        end
        if not Q.enabled then return end
        if not validChar(char) then
            Q.queued=false;Q.ready=false
            return
        end
        if char:GetAttribute("FeralClimbLocal")==true then
            if Q.awaitingMount then Q.observedMounts+=1 end
            Q.queued=false;Q.awaitingMount=false;Q.retapsForPress=0
            Q.status="CLIMBING • NATIVE Q TO LET GO"
            Q.ready=false
            return
        end
        Q.ready=char:GetAttribute("ClimbCan")==true
        if Q.awaitingMount and now>=Q.awaitUntil then
            Q.awaitingMount=false
            -- One guarded retry after a dropped native tap, only when the
            -- same own climber is still on a valid tree and not diving.
            if Q.retapsForPress<1 and Q.ready
                and not UIS:GetFocusedTextBox()
                and not unsafe(char)
                and char:GetAttribute("DiveCan")~=true
                and climbAllowed() then
                Q.retapsForPress+=1
                Q.retries+=1
                Q.queued=true
                Q.pendingUntil=now+.65
                Q.status="NATIVE CLIMB TAP RETRY QUEUED"
            else
                Q.retrySuppressed+=1
                Q.status="CLIMB TAP SENT • NO MOUNT CONFIRMED"
            end
        end
        if not Q.queued then return end
        if now>Q.pendingUntil then
            Q.queued=false
            Q.expiredPresses+=1
            Q.status="BUFFER EXPIRED • TREE NOT READY"
            return
        end
        local allowed,why=climbAllowed()
        if UIS:GetFocusedTextBox() or unsafe(char) or not allowed then
            Q.queued=false
            Q.suppressedConflicts+=1
            Q.status="ACTION PRIORITY / "..tostring(why)
            return
        end
        if char:GetAttribute("DiveCan")==true then
            Q.queued=false;Q.suppressedDives+=1
            return
        end
        if not Q.ready then return end
        if now-Q.lastTap<.35 then return end
        Q.lastTap=now
        Q.queued=false
        if ctx.native and ctx.native.beforeClimb then
            pcall(ctx.native.beforeClimb)
        end
        -- Native FERAL ClimbController listens to the player's
        -- FeralClimbTap attribute (same as the game's own touch HUD).
        -- Never send FeralClimb remote directly or teleport into trees.
        player:SetAttribute("FeralClimbTap",now)
        Q.gameTaps+=1
        Q.awaitingMount=true
        Q.awaitUntil=now+.7
        Q.status="NATIVE CLIMB TAP SENT"
    end
    function Q.setEnabled(on)
        Q.enabled=on==true
        Q.queued=false
        Q.awaitingMount=false
        Q.retapsForPress=0
        if not Q.enabled then
            release()
            Q.status="OFF / CLIMB SETTINGS RESTORED"
        else
            Q.status="READY TO BUFFER Q"
            install()
        end
    end
    function Q.report()
        return table.concat({
            "FERAL NOVA PRIME v15 | Quick Climb",
            "enabled="..tostring(Q.enabled)..
                " config_applied="..tostring(Q.configReady),
            "climb_ready_now="..tostring(Q.ready),
            "buffer_pending="..tostring(Q.queued),
            "sprint_grab_enabled_client="..tostring(Q.sprintGrabPatch),
            "Q_press_buffers="..Q.queuedPresses,
            "buffer_expired="..Q.expiredPresses,
            "native_climb_taps="..Q.gameTaps,
            "retry_taps_queued="..Q.retries,
            "retry_taps_suppressed="..Q.retrySuppressed,
            "buffer_window_seconds=2.25",
            "observed_climb_mounts="..Q.observedMounts,
            "dive_priority_holds="..Q.suppressedDives,
            "carry_and_capture_priority_holds="..Q.suppressedConflicts,
            "status="..Q.status,
            "last_error="..Q.lastError,
            "NOTE=Climb input buffers for 2.25s and may retry one missed native tap.",
            "NOTE=Game controls actual mount and server acceptance.",
            "NOTE=v9 shared minigame priority prevents buffered climb taps conflicting with grabs."
        },"\n")
    end
    
    function Q.close()
        if not Q.alive then return end
        Q.alive=false
        Q.setEnabled(false)
        for _,connection in ipairs(connections) do
            pcall(function()connection:Disconnect()end)
        end
    end
    connections[#connections+1]=UIS.InputBegan:Connect(function(input,processed)
        -- Ignore Q already handled by Roblox UI, even with no focused chat.
        if processed then return end
        if input.KeyCode==Enum.KeyCode.Q then
            local ok,err=pcall(onQ,os.clock())
            if not ok then Q.lastError=tostring(err)end
        end
    end)
    connections[#connections+1]=RunService.Heartbeat:Connect(function()
        if not ctx.state.alive then Q.close();return end
        local ok,err=pcall(tick)
        if not ok then Q.lastError=tostring(err)end
    end)
    install()
    return Q
end
return Climb
