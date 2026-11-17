-- FERAL AURORA v3 / Operations layer
-- Works with the previously verified v2.1 own-client engine.
-- Adds an interactive radar, focus target, waypoints, local navigation and
-- session telemetry. All data originates from the current client instance.
local Ops={}
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local HttpService=game:GetService("HttpService")
local localPlayer=Players.LocalPlayer
local function finite(v)
    return type(v)=="number" and v==v and v>-math.huge and v<math.huge
end
local function num(v,precision)
    return finite(v) and string.format("%."..tostring(precision or 1).."f",v) or "—"
end
local function create(class,props,parent)
    local object=Instance.new(class)
    for k,v in pairs(props or {}) do object[k]=v end
    if parent then object.Parent=parent end
    return object
end
function Ops.relative(origin,look,target,range)
    if not origin or not target or not look or not finite(range) or range<=0 then
        return nil end
    local dx,dz=target.X-origin.X,target.Z-origin.Z
    local fx,fz=look.X,look.Z
    local mag=math.sqrt(fx*fx+fz*fz)
    if mag<.0001 then fx,fz,mag=0,-1,1 end
    fx,fz=fx/mag,fz/mag
    local right=(-fz*dx+fx*dz)
    local forward=fx*dx+fz*dz
    local dist=math.sqrt(dx*dx+dz*dz)
    return {
        x=math.clamp(right/range,-1,1),
        y=math.clamp(-forward/range,-1,1),
        distance=dist,
        bearing=math.deg(math.atan2(right,forward)),
        inRange=dist<=range
    }
end
function Ops.attach(ctx)
    local S=ctx.state
    local X={
        alive=true,focus=nil,focusName=nil,focusType="NONE",
        focusDescription="No target selected. Choose a player or location.",
        targetChanged=0,showWaypoint=true,waypointPart=nil,
        waypointBillboard=nil,lastUpdate=0,radar={},nearAlerts=false,
        healthAlerts=true,playerHistory={},sightingCount=0,
        unseenPlayers={},hadBaseline=false,lastNearAlert=-math.huge,
        lastHealth=nil,lastCharacter=nil,lastDangerAlert=-math.huge,
        stats={samples=0,maxHorizontalSpeed=0,lowestStaminaRatio=1,
            healthLost=0,sessions=0,secondsSpawned=0,secondsInMenu=0,
            playersSpotted=0,alertCount=0,pointsVisited=0},
        pins={},style="cyan",visualMode="normal",extraLight=nil,
        sessionNotes={},maxPins=8
    }
    ctx.ops=X
    local settingsPath="FERAL_Aurora_V3_Operations.json"
    local function log(message)
        X.sessionNotes[#X.sessionNotes+1]=string.format("%02d:%02d  %s",
            math.floor((os.clock()-S.sessionStart)/60),
            math.floor((os.clock()-S.sessionStart)%60),tostring(message))
        while #X.sessionNotes>24 do table.remove(X.sessionNotes,1) end
        ctx.notice(message)
    end
    X.log=log
    local function save()
        if type(writefile)~="function" then return end
        local pins={}
        for _,p in ipairs(X.pins) do
            pins[#pins+1]={name=p.name,x=p.x,z=p.z}
        end
        pcall(function()
            writefile(settingsPath,HttpService:JSONEncode({
                schema="aurora_v3_operations",pins=pins,showWaypoint=X.showWaypoint,
                visualMode=X.visualMode,nearAlerts=X.nearAlerts
            }))
        end)
    end
    local function load()
        if type(readfile)~="function" then return end
        local ok,result=pcall(function()
            return HttpService:JSONDecode(readfile(settingsPath))
        end)
        if not ok or type(result)~="table" then return end
        if type(result.pins)=="table" then
            for _,p in ipairs(result.pins) do
                if #X.pins>=X.maxPins then break end
                if type(p)=="table" and type(p.name)=="string"
                    and #p.name<=48 and finite(p.x) and finite(p.z)
                    and math.abs(p.x)<=200000 and math.abs(p.z)<=200000 then
                    X.pins[#X.pins+1]={name=p.name,x=p.x,z=p.z}
                end
            end
        end
        X.showWaypoint=result.showWaypoint~=false
        X.nearAlerts=result.nearAlerts==true
    end
    load()
    local function ownOrigin()
        local char=localPlayer.Character
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local camera=workspace.CurrentCamera
        if root then
            return root.Position,camera and camera.CFrame.LookVector
                or root.CFrame.LookVector,"ANIMAL"
        end
        if camera then return camera.CFrame.Position,camera.CFrame.LookVector,"MENU CAMERA" end
        return nil,nil,"NO CAMERA"
    end
    function X.getRadar()
        local origin,look,source=ownOrigin()
        X.origin=source
        local all={}
        if not origin or not look then return all end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=localPlayer and p.Character then
                local root=p.Character:FindFirstChild("HumanoidRootPart")
                local hum=p.Character:FindFirstChildOfClass("Humanoid")
                if root and hum and hum.Health>0 then
                    local relative=Ops.relative(origin,look,root.Position,S.range)
                    if relative and relative.inRange then
                        all[#all+1]={
                            ref=p,name=p.DisplayName or p.Name,
                            species=p.Character:GetAttribute("Species") or "Unknown",
                            hp=hum.Health,maxHp=hum.MaxHealth,
                            x=relative.x,y=relative.y,
                            distance=relative.distance,bearing=relative.bearing,
                            focused=X.focusType=="PLAYER" and X.focus==p
                        }
                    end
                end
            end
        end
        table.sort(all,function(a,b)return a.distance<b.distance end)
        while #all>24 do table.remove(all)end
        X.radar=all
        return all
    end
    local function clearBeacon()
        if X.waypointBillboard then
            pcall(function()X.waypointBillboard:Destroy()end)
            X.waypointBillboard=nil
        end
        if X.waypointPart then
            pcall(function()X.waypointPart:Destroy()end)
            X.waypointPart=nil
        end
    end
    local function getFocusPosition()
        if X.focusType=="PLAYER" then
            local p=X.focus
            if p and p.Parent==Players and p.Character then
                local root=p.Character:FindFirstChild("HumanoidRootPart")
                if root then return root.Position,p.DisplayName or p.Name end
            end
            return nil,X.focusName or "Player unavailable"
        elseif X.focusType=="LOCATION" then
            local origin=localPlayer.Character
            local root=origin and origin:FindFirstChild("HumanoidRootPart")
            local y=root and root.Position.Y or workspace.CurrentCamera
                and workspace.CurrentCamera.CFrame.Position.Y or 70
            return Vector3.new(X.focus.x,y,X.focus.z),X.focus.name
        end
        return nil,nil
    end
    function X.targetInfo()
        if X.focusType=="NONE" then return {
            type="NONE",name="NO TARGET SELECTED",
            summary="Select a player from RADAR or a world location to focus it.",
            distance=nil,bearing=nil,position=nil,available=false
        } end
        local pos,name=getFocusPosition()
        local origin,look=ownOrigin()
        local relative=pos and origin and look and
            Ops.relative(origin,look,pos,1000) or nil
        if not pos or not relative then
            return {type=X.focusType,name=X.focusName or "Target unavailable",
                summary="The target is no longer replicated or no camera is available.",
                available=false}
        end
        local relativeBearing=relative.bearing
        local direction=math.abs(relativeBearing)>=150 and "BEHIND"
            or relativeBearing>28 and "RIGHT"
            or relativeBearing< -28 and "LEFT" or "AHEAD"
        return {
            type=X.focusType,name=name or X.focusName,
            summary=string.format("%s • %.0f studs • heading %+.0f°",
                direction,relative.distance,relativeBearing),
            distance=relative.distance,bearing=relativeBearing,
            position=pos,available=true,
            direction=direction
        }
    end
    function X.focusPlayer(p)
        if not p or p==localPlayer or p.Parent~=Players then return end
        X.focusType="PLAYER";X.focus=p
        X.focusName=p.DisplayName or p.Name
        X.targetChanged=os.clock()
        X.focusDescription="Following replicated character position."
        log("Target selected: "..X.focusName)
    end
    function X.focusLocation(name,x,z)
        if type(name)~="string" or not finite(x) or not finite(z) then return end
        X.focus={name=name,x=x,z=z};X.focusType="LOCATION"
        X.focusName=name;X.targetChanged=os.clock()
        X.focusDescription="Static landmark compass position."
        log("Waypoint selected: "..name)
    end
    function X.focusLocationIndex(i)
        local p=ctx.locations[i]
        if p then X.focusLocation(p[1],p[2],p[3]) end
    end
    function X.focusClosest()
        local radar=X.getRadar()
        if not radar[1] then
            log("No replicated player currently within radar range.")
            return
        end
        X.focusPlayer(radar[1].ref)
    end
    function X.focusResource(i)
        local item=S.resource and S.resource.candidates[i]
        if not item then return end
        local x,z=item.x,item.z
        if item.position then x,z=item.position.X,item.position.Z end
        if finite(x) and finite(z) then
            X.focusLocation(item.name,x,z)
        end
    end
    function X.clearFocus()
        X.focus=nil;X.focusType="NONE";X.focusName=nil
        clearBeacon()
        log("Target cleared.")
    end
    function X.toggleMarker()
        X.showWaypoint=not X.showWaypoint
        if not X.showWaypoint then clearBeacon() end
        save()
        log("In-world waypoint marker: "..(X.showWaypoint and "ON" or "OFF"))
    end
    function X.addPin()
        local info=X.targetInfo()
        if not info.available or not info.position then
            log("Choose a replicated player or landmark to bookmark first.")
            return
        end
        if #X.pins>=X.maxPins then
            log("Maximum 8 pinned destinations. Remove one before adding another.")
            return
        end
        local name=tostring(info.name or "Waypoint")
        X.pins[#X.pins+1]={
            name=string.sub(name,1,48),
            x=info.position.X,z=info.position.Z
        }
        save()
        log("Saved current target as a local destination.")
    end
    function X.removePin(i)
        if not X.pins[i] then return end
        local name=X.pins[i].name
        table.remove(X.pins,i);save()
        log("Deleted pinned destination: "..name)
    end
    function X.focusPin(i)
        local p=X.pins[i]
        if p then X.focusLocation(p.name,p.x,p.z) end
    end
    local function ensureBeacon()
        if not X.showWaypoint then return end
        if X.waypointPart and X.waypointPart.Parent and
            X.waypointBillboard and X.waypointBillboard.Parent then return end
        clearBeacon()
        local part=create("Part",{
            Name="AuroraV3_ClientOnlyWaypoint",Size=Vector3.new(.2,.2,.2),
            Anchored=true,Transparency=1,CanCollide=false,
            CanTouch=false,CanQuery=false,CastShadow=false
        },workspace)
        local board=create("BillboardGui",{
            Name="AuroraWaypointTag",Adornee=part,AlwaysOnTop=true,
            Size=UDim2.fromOffset(170,50),MaxDistance=1500,
            StudsOffsetWorldSpace=Vector3.new(0,3,0)},part)
        local f=create("Frame",{
            Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(11,28,37),
            BackgroundTransparency=.1,BorderSizePixel=0},board)
        create("UICorner",{CornerRadius=UDim.new(0,11)},f)
        create("UIStroke",{Color=ctx.palette.teal,Thickness=1,Transparency=.2},f)
        local text=create("TextLabel",{
            Name="WaypointText",Text="◈ WAYPOINT",TextColor3=ctx.palette.text,
            Font=Enum.Font.GothamBold,TextSize=11,TextWrapped=true,
            BackgroundTransparency=1,Size=UDim2.new(1,-12,1,-8),
            Position=UDim2.fromOffset(6,4)},f)
        X.waypointPart,X.waypointBillboard=part,board
        X.waypointText=text
    end
    function X.setVisual(mode)
        if mode~="normal" and mode~="clarity" and mode~="warm"
            and mode~="moonlight" then return end
        if X.extraLight then X.extraLight:Destroy();X.extraLight=nil end
        X.visualMode=mode
        local settings={
            clarity={Brightness=.11,Contrast=.09,Saturation=.08,
                TintColor=Color3.fromRGB(224,248,255)},
            warm={Brightness=.04,Contrast=.05,Saturation=.1,
                TintColor=Color3.fromRGB(255,234,213)},
            moonlight={Brightness=.16,Contrast=-.03,Saturation=-.2,
                TintColor=Color3.fromRGB(211,226,255)}
        }
        if settings[mode] then
            local props=settings[mode]
            props.Name="AuroraV3_ClientVisualProfile"
            X.extraLight=create("ColorCorrectionEffect",props,Lighting)
        end
        save()
        log("Client-only colour profile: "..mode)
    end
    function X.toggleNearAlerts()
        X.nearAlerts=not X.nearAlerts
        X.hadBaseline=false
        save()
        log("Nearby player notifications: "..(X.nearAlerts and "ON" or "OFF"))
    end
    function X.toggleDangerAlerts()
        X.healthAlerts=not X.healthAlerts
        log("Health-loss notifications: "..(X.healthAlerts and "ON" or "OFF"))
    end
    function X.quick(key)
        if key=="finder" then ctx.toggle("playerFinder")
        elseif key=="rest" then ctx.toggle("recovery")
        elseif key=="camera" then ctx.toggle("calm")
        elseif key=="vision" then ctx.toggle("vision")
        elseif key=="health" then ctx.toggle("alerts")
        elseif key=="clear" then X.clearFocus()
        elseif key=="target" then X.focusClosest()
        elseif key=="water" then ctx.findResources("water")
        elseif key=="food" then ctx.findResources("food")
        elseif key=="reset" then ctx.reset()
        elseif key=="marker" then X.toggleMarker()
        elseif key=="home" then X.focusLocationIndex(1)
        end
    end
    local function sample(now,dt)
        local a=ctx.stats()
        local char=localPlayer.Character
        if char~=X.lastCharacter then
            X.lastCharacter=char
            X.lastHealth=nil
            if char then X.stats.sessions=X.stats.sessions+1 end
        end
        if a.sessionPhase=="IN GAME" then
            X.stats.secondsSpawned=X.stats.secondsSpawned+dt
        else
            X.stats.secondsInMenu=X.stats.secondsInMenu+dt
        end
        if finite(a.speed) then
            X.stats.maxHorizontalSpeed=math.max(X.stats.maxHorizontalSpeed,a.speed)
        end
        if finite(a.stamina) and finite(a.maxStamina) and a.maxStamina>0 then
            X.stats.lowestStaminaRatio=math.min(X.stats.lowestStaminaRatio,
                a.stamina/a.maxStamina)
        end
        if finite(a.hp) and X.lastHealth and a.hp<X.lastHealth then
            local delta=X.lastHealth-a.hp
            X.stats.healthLost=X.stats.healthLost+delta
            if X.healthAlerts and delta>=math.max(8,(a.maxHp or 100)*.12)
                and now-X.lastDangerAlert>=12 then
                X.lastDangerAlert=now;X.stats.alertCount=X.stats.alertCount+1
                log("Large own health drop observed: -"..num(delta,0).." HP.")
            end
        end
        X.lastHealth=a.hp
        X.stats.samples=X.stats.samples+1
        if X.focusType~="NONE" and X.showWaypoint then
            local target=X.targetInfo()
            if target.available and target.position then
                ensureBeacon()
                if X.waypointPart then
                    local position=target.position
                    X.waypointPart.CFrame=CFrame.new(position+Vector3.new(0,3,0))
                    if X.waypointText then
                        X.waypointText.Text="◈  "..string.sub(target.name,1,22)..
                            "\n"..num(target.distance,0).." STUDS"
                    end
                end
            else clearBeacon() end
        else clearBeacon() end
        if X.nearAlerts then
            local seen={}
            local nearby=X.getRadar()
            for _,item in ipairs(nearby) do
                local id=item.ref.UserId
                seen[id]=true
                if X.hadBaseline and not X.unseenPlayers[id]
                    and now-X.lastNearAlert>=12 then
                    X.lastNearAlert=now;X.stats.alertCount=X.stats.alertCount+1
                    log("Nearby replicated animal: "..item.name..
                        " ("..num(item.distance,0).." studs)")
                end
            end
            X.unseenPlayers=seen;X.hadBaseline=true
        end
    end
    X.connection=RunService.Heartbeat:Connect(function(dt)
        if not X.alive or not S.alive then return end
        local now=os.clock()
        if now-X.lastUpdate<.4 then return end
        local delta=math.clamp(now-X.lastUpdate,0,1)
        X.lastUpdate=now
        local ok,err=pcall(sample,now,delta)
        if not ok then
            X.lastError=tostring(err):sub(1,180)
        end
    end)
    local originalReset=ctx.reset
    function ctx.reset()
        originalReset()
        X.clearFocus()
        if X.extraLight then X.extraLight:Destroy();X.extraLight=nil end
        X.visualMode="normal"
        X.nearAlerts=false
        X.showWaypoint=false
        X.hadBaseline=false
        clearBeacon()
    end
    local originalClose=ctx.close
    function ctx.close()
        if X.alive then
            X.alive=false
            if X.connection then X.connection:Disconnect() end
            if X.extraLight then X.extraLight:Destroy();X.extraLight=nil end
            clearBeacon()
        end
        originalClose()
    end
    function X.summary()
        return string.format(
            "Session %.0fs animal / %.0fs menu • max speed %.1f • health lost %.1f • lowest stamina %.0f%%",
            X.stats.secondsSpawned,X.stats.secondsInMenu,
            X.stats.maxHorizontalSpeed,X.stats.healthLost,
            X.stats.lowestStaminaRatio*100)
    end
    return X
end
return Ops
