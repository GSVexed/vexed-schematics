-- FERAL NOVA CORE v9.0 / native Grab V2 assistant with priority leases.
-- Uses ONLY actual own-game OnClientEvent("strike") and matching
-- FeralGrabV2:FireServer("press",sessionId,strikeId,Workspace:GetServerTimeNow()).
-- No forged strike/start events, no fake results and no timestamp spoofing.
-- Actual server "perfect" grading is NOT guaranteed by a client forecast.
local Grab={}
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local function finite(x)
    return type(x)=="number" and x==x and math.abs(x)<1e10
end
local function positive(x)
    return finite(x) and x>0
end
local function validSession(v)
    if type(v)=="number" then return finite(v) and v>0 and v%1==0 end
    if type(v)=="string" then
        return #v>=1 and #v<=90 and
            v:match("^[%w_%-]+$")~=nil and v~="-1"
    end
    return false
end
local function config()
    local folder=RS:FindFirstChild("FeralWorld")
    local m=folder and folder:FindFirstChild("GrabV2Config")
    if not m or not m:IsA("ModuleScript") then return nil end
    local ok,v=pcall(require,m)
    if ok and type(v)=="table" then return v end
    return nil
end
local function triangle(at,t0,speed,from)
    local phase=math.max(0,(at-t0)*speed)%2
    local wave=phase<=1 and phase or 2-phase
    return from==0 and wave or (1-wave)
end
-- A triangle wave reaches target on the rising and falling edges of
-- each 2/speed period. Find earliest valid crossing with time for network
-- clock/readout jitter; never claim perfect from a local prediction alone.
local function crossing(now,t0,dur,speed,from,target,halfWidth,margin)
    if not (finite(now) and finite(t0) and positive(dur)
        and positive(speed) and finite(target) and finite(halfWidth))
        or target<0 or target>1 or halfWidth<=0 then return nil end
    local current=triangle(now,t0,speed,from)
    if now>=t0 and now<=t0+dur-.018
        and math.abs(current-target)<=halfWidth*.5 then
        return now
    end
    local waveTarget=from==0 and target or 1-target
    local threshold=math.max(now+margin,t0+.008)
    local best=nil
    for cycle=0,math.min(32,math.ceil(dur*speed/2)+1) do
        for _,phase in ipairs({waveTarget,2-waveTarget}) do
            local at=t0+(2*cycle+phase)/speed
            if at>=threshold and at<=t0+dur-.018
                and (best==nil or at<best) then
                best=at
            end
        end
    end
    return best
end
Grab.crossing=crossing
function Grab.attach(ctx)
    local G={
        enabled=false,alive=true,activeSession=false,
        status="OFF",session=nil,pending=nil,serial=0,
        strikesSeen=0,pressesAttempted=0,pressesSent=0,pressErrors=0,
        perfectWindowAtPress=0,missedWindow=0,
        skippedMissingId=0,invalidStrikePackets=0,manualOverrides=0,
        remoteBinds=0,lateBinds=0,lastBind=0,lastStatus="",
        serverPerfectReplies=0,serverGoodReplies=0,
        serverMissReplies=0,serverUnknownReplies=0,
        lastSessionAt=0,blockedRestWindows=0,lastError="",
        minLeadSeconds=.042,lastReadDelay=0,rawWindowSeconds=0,
    }
    local conns={}
    local remote=nil
    local remoteConn=nil
    local watchedRemote=nil
    local function revoke(reason)
        G.pending=nil
        G.activeSession=false
        G.session=nil
        if ctx.action and type(ctx.action.release)=="function" then
            ctx.action.release("minigame")
        end
        if reason then G.status=reason end
    end
    local function reserve(t)
        if ctx.action and type(ctx.action.reserve)=="function" then
            return ctx.action.reserve("minigame",math.clamp(t,1,8))
        end
        return true,"COORDINATOR NOT ATTACHED"
    end
    local function notifyResult(data)
        local tier=type(data)=="table" and (data.tier or data.grade or data.result) or data
        if type(tier)~="string" then return end
        tier=tier:lower()
        if tier=="perfect" then G.serverPerfectReplies+=1
        elseif tier=="good" then G.serverGoodReplies+=1
        elseif tier=="miss" then G.serverMissReplies+=1
        else G.serverUnknownReplies+=1 end
    end
    local function onEvent(event,data)
        if not G.alive or not G.enabled or type(event)~="string" then return end
        if event=="end" or event=="done" or event=="free"
            or event=="quit" or event=="cancel" then
            revoke("MINIGAME ENDED / WAITING")
            return
        end
        if event=="result" or event=="grade" or event=="scored" then
            notifyResult(data)
            return
        end
        if event=="bite" then
            G.pending=nil
            G.status="BITE PAUSE / WAITING NEXT STRIKE"
            return
        end
        if event=="start" or event=="begin" then
            local id=type(data)=="table" and (data.f or data.id) or nil
            if validSession(id) then
                local permitted,why=reserve(8)
                if not permitted then
                    G.status="PRIORITY CONFLICT / "..tostring(why)
                    return
                end
                G.session=id
                G.activeSession=true
                G.lastSessionAt=os.clock()
                G.status="SESSION FOUND / WATCHING STRIKES"
                if ctx.native and ctx.native.beforeMinigame then
                    ctx.native.beforeMinigame()
                    G.blockedRestWindows+=1
                end
            end
            return
        end
        if event~="strike" then return end
        G.strikesSeen+=1
        if type(data)~="table" then
            G.invalidStrikePackets+=1
            G.status="INVALID STRIKE / NO INPUT SENT"
            return
        end
        local id=validSession(data.f) and data.f or G.session
        local strike=data.k
        local t0=data.t0
        local spd=data.spd
        local from=data.from
        local zc=data.zc
        local zw=data.zw
        local cfg=config()
        local cfgPerfect=cfg and cfg.PERFECT or .32
        local passes=cfg and cfg.PASSES or 2.5
        local duration=data.dur
        if not positive(duration) then duration=positive(spd) and passes/spd or 0 end
        if not validSession(id) or not finite(strike) or strike<1
            or strike%1~=0 then
            G.skippedMissingId+=1
            G.status="NO VERIFIED SESSION/STRIKE ID / SKIPPING"
            return
        end
        if not(finite(t0) and positive(spd) and (from==0 or from==1)
            and finite(zc) and zc>=0 and zc<=1 and positive(zw)
            and zw<1 and positive(duration) and duration<=10
            and positive(cfgPerfect) and cfgPerfect<=1) then
            G.invalidStrikePackets+=1
            G.status="UNEXPECTED STRIKE SCHEMA / SKIPPING"
            return
        end
        local ok,serverNow=pcall(function()return Workspace:GetServerTimeNow()end)
        if not ok or not finite(serverNow) or t0+duration<serverNow+.02
            or t0-serverNow>3 then
            G.invalidStrikePackets+=1
            G.status="STRIKE EXPIRED OR CLOCK UNSAFE"
            return
        end
        local permitted,why=reserve(math.min(8,duration+1))
        if not permitted then
            G.pending=nil
            G.status="PRIORITY CONFLICT / "..tostring(why)
            return
        end
        G.session=id
        G.activeSession=true
        G.lastSessionAt=os.clock()
        if ctx.native and ctx.native.beforeMinigame then
            ctx.native.beforeMinigame()
            G.blockedRestWindows+=1
        end
        local halfPerfect=(zw/2)*cfgPerfect
        local targetTime=crossing(serverNow,t0,duration,spd,from,zc,halfPerfect,G.minLeadSeconds)
        if not targetTime then
            G.missedWindow+=1
            G.status="NO SAFE PERFECT WINDOW LEFT / NOT GUESSING"
            G.pending=nil
            return
        end
        G.serial+=1
        G.pending={
            serial=G.serial,session=id,strike=strike,
            t0=t0,duration=duration,speed=spd,
            from=from,target=zc,halfPerfect=halfPerfect,
            targetTime=targetTime,arrivedAt=os.clock(),
        }
        G.rawWindowSeconds=2*halfPerfect/spd
        G.status="PERFECT CROSSING SCHEDULED / SERVER UNVERIFIED"
    end
    local function bindRemote()
        local nextRemote=RS:FindFirstChild("FeralGrabV2")
        if not nextRemote or not nextRemote:IsA("RemoteEvent") then
            G.status="WAITING FOR NATIVE FERALGRABV2 REMOTE"
            return
        end
        if remote==nextRemote and remoteConn then return end
        if remoteConn then pcall(function()remoteConn:Disconnect()end)end
        remote=nextRemote
        local ok,cn=pcall(function()
            return nextRemote.OnClientEvent:Connect(onEvent)
        end)
        if not ok then
            remote=nil
            G.lastError=tostring(cn):sub(1,140)
            return
        end
        remoteConn=cn
        G.remoteBinds+=1
        G.status="MONITORING NATIVE GRAB V2 EVENTS"
    end
    function G.setEnabled(v)
        G.enabled=v==true
        if G.enabled then
            G.status="WAITING FOR GRAB V2 STRIKE / AUTO PERFECT ARMED"
            bindRemote()
        else
            revoke("OFF / NO MINIGAME INPUTS")
        end
        return G.enabled
    end
    conns[#conns+1]=UIS.InputBegan:Connect(function(input,processed)
        if not G.enabled or not G.pending or processed then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1
            or input.UserInputType==Enum.UserInputType.Touch
            or input.KeyCode==Enum.KeyCode.Space then
            G.manualOverrides+=1
            G.pending=nil
            G.status="MANUAL INPUT HAS PRIORITY"
        end
    end)
    local lastCheck=0
    local function tick()
        if not G.enabled or not G.alive or not ctx.state.alive then return end
        local nowClock=os.clock()
        if nowClock-lastCheck>2 then
            lastCheck=nowClock
            if not remote or not remote.Parent then
                if G.remoteBinds>0 then G.lateBinds+=1 end
                bindRemote()
            end
        end
        if G.activeSession and not G.pending
            and nowClock-G.lastSessionAt>8 then
            revoke("SESSION TIMEOUT / NO STRIKE")
        end
        local p=G.pending
        if not p then return end
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health<=0
            or player:GetAttribute("FeralMenuOpen")==true
            or UIS:GetFocusedTextBox() then
            G.pending=nil
            G.status="NO ANIMAL / MENU / CHAT / NO INPUT"
            return
        end
        if ctx.action and type(ctx.action.allowed)=="function" then
            local okAllow,mayPress,reason=pcall(
                ctx.action.allowed,"grab_press")
            if not okAllow or not mayPress then
                G.pending=nil
                G.status="COORDINATOR BLOCKED PRESS / "..tostring(reason)
                return
            end
        end
        local ok,now=pcall(function()return Workspace:GetServerTimeNow()end)
        if not ok or not finite(now) then
            G.pending=nil
            G.status="SERVER CLOCK UNAVAILABLE"
            return
        end
        if now<p.targetTime-.007 then return end
        if now>p.t0+p.duration-.01 then
            G.pending=nil
            G.missedWindow+=1
            G.status="STRIKE EXPIRED / NOT SENDING MISS"
            return
        end
        local pos=triangle(now,p.t0,p.speed,p.from)
        if math.abs(pos-p.target)>p.halfPerfect*.88 then
            -- If a very narrow window was missed, do not lie about the
            -- expected grade or send a stale/future timestamp.
            if now>p.targetTime+.08 then
                G.pending=nil
                G.missedWindow+=1
                G.status="MISSED CENTER / SKIPPED UNSAFE PRESS"
            end
            return
        end
        G.pending=nil
        G.pressesAttempted+=1
        if not remote or not remote.Parent then
            G.pressErrors+=1
            G.status="NATIVE REMOTE LOST / PRESS NOT SENT"
            return
        end
        local sent,err=pcall(function()
            remote:FireServer("press",p.session,p.strike,now)
        end)
        if sent then
            G.pressesSent+=1
            G.perfectWindowAtPress+=1
            G.lastReadDelay=now-p.targetTime
            G.lastSessionAt=nowClock
            G.status="PRESS SENT IN LOCAL PERFECT WINDOW / SERVER RESULT UNKNOWN"
        else
            G.pressErrors+=1
            G.lastError=tostring(err):sub(1,140)
            G.status="NATIVE PRESS ERROR"
        end
    end
    conns[#conns+1]=RunService.Heartbeat:Connect(function()
        local ok,err=pcall(tick)
        if not ok then
            G.lastError=tostring(err):sub(1,140)
            G.status="MINIGAME CONTROLLER ERROR"
            G.pending=nil
        end
    end)
    function G.report()
        return table.concat({
            "FERAL NOVA v8.1 | Grab V2 Auto Perfect",
            "enabled="..tostring(G.enabled),
            "active_native_session="..tostring(G.activeSession),
            "status="..G.status,
            "native_remote_binds="..G.remoteBinds,
            "native_strikes_observed="..G.strikesSeen,
            "perfect_center_press_attempts="..G.pressesAttempted,
            "native_press_calls_success="..G.pressesSent,
            "local_perfect_window_samples="..G.perfectWindowAtPress,
            "late_or_unavailable_windows="..G.missedWindow,
            "manual_press_overrides="..G.manualOverrides,
            "invalid_strike_packets="..G.invalidStrikePackets,
            "unverified_session_ids="..G.skippedMissingId,
            "server_perfect_replies="..G.serverPerfectReplies,
            "server_good_replies="..G.serverGoodReplies,
            "server_miss_replies="..G.serverMissReplies,
            "rest_releases_for_grab="..G.blockedRestWindows,
            "v9_minigame_action_priority=true",
            "last_read_timing_error_seconds="..string.format("%.4f",G.lastReadDelay),
            "last_window_width_seconds="..string.format("%.4f",G.rawWindowSeconds),
            "last_error="..G.lastError,
            "NOTE=Only native server-issued strike packets allow a press.",
            "NOTE=The submitted timestamp is the actual Workspace:GetServerTimeNow().",
            "NOTE=A local Perfect prediction is not a confirmed server Perfect grade.",
            "NOTE=The server may reject presses because of state, latency or validation.",
            "NOTE=Practice mode uses local-only events and is not sent to the server."
        },"\n")
    end
    function G.close()
        if not G.alive then return end
        G.alive=false
        revoke("CLOSED")
        if remoteConn then pcall(function()remoteConn:Disconnect()end)end
        for _,cn in ipairs(conns) do
            pcall(function()cn:Disconnect()end)
        end
    end
    return G
end
return Grab