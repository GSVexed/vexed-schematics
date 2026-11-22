-- FERAL Territory Radius Experiment v1.0 | CLIENT CONFIG ONLY
-- Changes the client-visible claim radius from 120 to 6000 game units.
-- Does NOT forge server ownership, modify replicated territory attributes,
-- send network requests, teleport, or assert server-side capture authority.
-- The small HUD observes actual replicated territory progress/ownership.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
if game.PlaceId~=108901361810209 or not player then
    warn("[FERAL Radius] Not in the expected FERAL game.")
    return
end

local env=(type(getgenv)=="function" and getgenv()) or _G
if type(env.FERAL_RADIUS_EXPERIMENT)=="table"
    and type(env.FERAL_RADIUS_EXPERIMENT.stop)=="function" then
    pcall(env.FERAL_RADIUS_EXPERIMENT.stop)
end

local world=RS:FindFirstChild("FeralWorld")
local configScript=world and world:FindFirstChild("TerritoryConfig")
local spotsScript=world and world:FindFirstChild("MapSpots")
if not (configScript and spotsScript) then
    warn("[FERAL Radius] FeralWorld/TerritoryConfig/MapSpots unavailable.")
    return
end
local ok,cfg=pcall(require,configScript)
local okSpots,spotData=pcall(require,spotsScript)
if not ok or type(cfg)~="table" or type(cfg.CLAIM_RADIUS)~="number"
    or not okSpots or type(spotData)~="table" then
    warn("[FERAL Radius] Native game config could not be read.")
    return
end

local originalRadius=cfg.CLAIM_RADIUS
local experimentalRadius=6000
cfg.CLAIM_RADIUS=experimentalRadius
local territory=RS:FindFirstChild("FeralTerritory")
local alive=true
local updateConn=nil
local gui=nil
local currentKey=nil
local lastProgress=nil
local lastOwner=nil
local progressBeyond120=false
local ownerBeyond120=false
local samplesBeyond120=0
local maxDistanceTested=0
local startedAt=os.clock()
local lastUiAt=-math.huge
local function cleanNumber(value)
    if type(value)=="number" and value==value then return value end
    return nil
end
local function nearestSpot(pos)
    local biome=workspace:GetAttribute("FeralBiome") or "WolfValley"
    local spots=spotData[biome]
    if type(spots)~="table" then spots=spotData.WolfValley end
    if type(spots)~="table" then return nil,nil end
    local best,bestDistance
    for _,spot in ipairs(spots) do
        local p=spot.pos
        if typeof(p)=="Vector2" then
            local dx=pos.X-p.X
            local dz=pos.Z-p.Y
            local distance=math.sqrt(dx*dx+dz*dz)
            if not bestDistance or distance<bestDistance then
                best=spot
                bestDistance=distance
            end
        end
    end
    return best,bestDistance
end
local ui={}
local pg=player:FindFirstChildOfClass("PlayerGui")
if pg then
    gui=Instance.new("ScreenGui")
    gui.Name="FERAL_RadiusExperimentV1"
    gui.ResetOnSpawn=false
    gui.IgnoreGuiInset=true
    gui.DisplayOrder=340
    gui.Parent=pg

    local frame=Instance.new("Frame")
    frame.Name="Panel"
    frame.Size=UDim2.fromOffset(338,198)
    frame.Position=UDim2.new(0,14,1,-216)
    frame.BackgroundColor3=Color3.fromRGB(21,25,35)
    frame.BackgroundTransparency=0.05
    frame.BorderSizePixel=0
    frame.Parent=gui
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,9)
    corner.Parent=frame
    local title=Instance.new("TextLabel")
    title.Name="Title"
    title.Position=UDim2.fromOffset(12,7)
    title.Size=UDim2.fromOffset(230,25)
    title.BackgroundTransparency=1
    title.Text="FERAL  |  RADIUS 6000 TEST"
    title.Font=Enum.Font.GothamBold
    title.TextSize=14
    title.TextColor3=Color3.fromRGB(234,239,251)
    title.TextXAlignment=Enum.TextXAlignment.Left
    title.Parent=frame
    local stopButton=Instance.new("TextButton")
    stopButton.Name="Restore"
    stopButton.Size=UDim2.fromOffset(74,26)
    stopButton.Position=UDim2.fromOffset(252,7)
    stopButton.Text="RESTORE"
    stopButton.Font=Enum.Font.GothamSemibold
    stopButton.TextSize=11
    stopButton.TextColor3=Color3.fromRGB(255,245,245)
    stopButton.BackgroundColor3=Color3.fromRGB(120,55,65)
    stopButton.AutoButtonColor=true
    stopButton.Parent=frame
    local stopCorner=Instance.new("UICorner")
    stopCorner.CornerRadius=UDim.new(0,6)
    stopCorner.Parent=stopButton
    local function line(name,y)
        local label=Instance.new("TextLabel")
        label.Name=name
        label.Position=UDim2.fromOffset(12,y)
        label.Size=UDim2.fromOffset(314,22)
        label.BackgroundTransparency=1
        label.Font=Enum.Font.Gotham
        label.TextSize=12
        label.TextColor3=Color3.fromRGB(217,226,236)
        label.TextXAlignment=Enum.TextXAlignment.Left
        label.TextTruncate=Enum.TextTruncate.AtEnd
        label.Parent=frame
        return label
    end
    ui.nearest=line("Target",39)
    ui.state=line("RemoteState",64)
    ui.distance=line("Distance",89)
    ui.result=line("Result",114)
    ui.details=line("Details",139)
    local footer=line("Footer",170)
    footer.Text="Read-only server state | no claim requests"
    footer.TextColor3=Color3.fromRGB(141,164,188)
    ui.footer=footer
    ui.stop=stopButton
end

local function stop()
    if not alive then return end
    alive=false
    if updateConn then updateConn:Disconnect() updateConn=nil end
    if cfg.CLAIM_RADIUS==experimentalRadius then
        cfg.CLAIM_RADIUS=originalRadius
    end
    if gui then gui:Destroy() gui=nil end
    if env.FERAL_RADIUS_EXPERIMENT
        and env.FERAL_RADIUS_EXPERIMENT.stop==stop then
        env.FERAL_RADIUS_EXPERIMENT=nil
    end
    print("[FERAL Radius] Radius restored to "..tostring(cfg.CLAIM_RADIUS)
        .."; observed beyond-120 progress="..tostring(progressBeyond120)
        ..", owner change="..tostring(ownerBeyond120)
        ..", samples="..samplesBeyond120)
end
if ui.stop then ui.stop.Activated:Connect(stop) end

local function record()
    if not alive then return end
    if not territory or not territory.Parent then
        territory=RS:FindFirstChild("FeralTerritory")
    end
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        if ui.nearest then
            ui.nearest.Text="Spawn an animal to begin range test"
            ui.state.Text="Server data: waiting for animal"
            ui.distance.Text="Normal radius 120  |  local radius 6000"
            ui.result.Text="Server acceptance: not tested"
            ui.details.Text="Move 200+ units from a claimable spot"
        end
        return
    end
    local spot,distance=nearestSpot(root.Position)
    if not spot or not distance then return end
    local key=spot.key
    local progress=territory and cleanNumber(territory:GetAttribute(key.."_prog")) or nil
    local owner=territory and territory:GetAttribute(key.."_owner") or nil
    local by=territory and territory:GetAttribute(key.."_by") or nil
    local state=territory and territory:GetAttribute(key.."_state") or nil
    local pack=player:GetAttribute("FeralPack")
    local isNeutral=(type(cfg.claimable)=="function" and not cfg.claimable(key))
    local far=distance>125 and distance<=experimentalRadius
    local owns=pack~=nil and owner==pack
    local ownProgress=pack~=nil and by==pack and not owns and not isNeutral
    if currentKey~=key then
        currentKey=key
        lastProgress=progress
        lastOwner=owner
    else
        if far and ownProgress and progress and lastProgress
            and progress>lastProgress+0.001 then
            progressBeyond120=true
        end
        if far and pack~=nil and owner==pack and lastOwner~=pack then
            ownerBeyond120=true
        end
        lastProgress=progress
        lastOwner=owner
    end
    if far and not isNeutral then
        samplesBeyond120+=1
        maxDistanceTested=math.max(maxDistanceTested,distance)
    end
    if ui.nearest then
        ui.nearest.Text="Nearest: "..tostring(spot.name or key)
        ui.state.Text="Replicated state: "..tostring(state or "idle")
            .."  |  progress: "..(progress and string.format("%.0f%%",progress*100) or "n/a")
        ui.distance.Text=string.format("Distance: %.0f  |  old 120  ->  local 6000",distance)
        if isNeutral then
            ui.result.Text="Neutral/nonclaimable spot — move elsewhere"
        elseif owns then
            ui.result.Text="Owned by your pack — find unclaimed spot"
        elseif not far then
            ui.result.Text="Move beyond 125 to test extra range"
        elseif not pack then
            ui.result.Text="Join a pack to test a server claim"
        elseif progressBeyond120 or ownerBeyond120 then
            ui.result.Text="Remote state changed beyond 120 (verify cause)"
        else
            ui.result.Text="Beyond 120: no own-pack progress yet"
        end
        ui.details.Text=string.format("Outside-range samples: %d  |  max: %.0f",
            samplesBeyond120,maxDistanceTested)
    end
end

updateConn=RunService.Heartbeat:Connect(function()
    local now=os.clock()
    if now-lastUiAt<0.5 then return end
    lastUiAt=now
    local okRecord,err=pcall(record)
    if not okRecord then
        warn("[FERAL Radius] Observer error: "..tostring(err))
    end
end)
env.FERAL_RADIUS_EXPERIMENT={
    stop=stop,
    radius=experimentalRadius,
    originalRadius=originalRadius,
    getResults=function()
        return {
            localRadius=cfg.CLAIM_RADIUS,
            baseRadius=originalRadius,
            active=alive,
            outsideRangeSamples=samplesBeyond120,
            maxDistance=maxDistanceTested,
            ownPackProgressChangedBeyond120=progressBeyond120,
            ownPackOwnerChangedBeyond120=ownerBeyond120
        }
    end
}
print("[FERAL Radius] Client TerritoryConfig.CLAIM_RADIUS "
    ..tostring(originalRadius).." -> "..experimentalRadius
    ..". SERVER VALIDATION NOT VERIFIED; press RESTORE in overlay to undo.")
