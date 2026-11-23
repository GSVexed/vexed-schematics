-- FERAL NOVA + Territory Rush launcher v4.2.1
-- Territory starts INDEPENDENTLY of the main hub. A compact OPEN/RETRY
-- banner remains visible even if territory data has not spawned yet.
-- Territory panel hotkey: F7 (toggle without interrupting AUTO or recorder).
local GAME=108901361810209
local BASE="https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/"
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local env=(type(getgenv)=="function" and getgenv()) or _G
local playerGui=player and player:WaitForChild("PlayerGui",15)
local statusGui=nil
local statusText=nil
local openButton=nil

if playerGui then
    local existing=playerGui:FindFirstChild("FERAL_TerritoryLauncherStatus")
    if existing then existing:Destroy() end
    statusGui=Instance.new("ScreenGui")
    statusGui.Name="FERAL_TerritoryLauncherStatus"
    statusGui.ResetOnSpawn=false
    statusGui.IgnoreGuiInset=true
    statusGui.DisplayOrder=800
    statusGui.Parent=playerGui
    local bar=Instance.new("Frame")
    bar.Name="Status"
    bar.Position=UDim2.fromOffset(20,44)
    bar.Size=UDim2.fromOffset(410,38)
    bar.BorderSizePixel=0
    bar.BackgroundColor3=Color3.fromRGB(21,34,41)
    bar.Parent=statusGui
    Instance.new("UICorner",bar).CornerRadius=UDim.new(0,7)
    local stroke=Instance.new("UIStroke")
    stroke.Color=Color3.fromRGB(66,112,116)
    stroke.Parent=bar
    statusText=Instance.new("TextLabel")
    statusText.Name="Message"
    statusText.BackgroundTransparency=1
    statusText.Position=UDim2.fromOffset(10,0)
    statusText.Size=UDim2.fromOffset(313,38)
    statusText.Font=Enum.Font.GothamMedium
    statusText.TextSize=11
    statusText.TextXAlignment=Enum.TextXAlignment.Left
    statusText.TextTruncate=Enum.TextTruncate.AtEnd
    statusText.TextColor3=Color3.fromRGB(213,239,236)
    statusText.Text="TERRITORY • INITIALISING..."
    statusText.Parent=bar
    openButton=Instance.new("TextButton")
    openButton.Name="OpenOrRetry"
    openButton.Position=UDim2.fromOffset(326,5)
    openButton.Size=UDim2.fromOffset(76,28)
    openButton.BorderSizePixel=0
    openButton.BackgroundColor3=Color3.fromRGB(44,107,100)
    openButton.TextColor3=Color3.fromRGB(245,255,250)
    openButton.Text="OPEN"
    openButton.TextSize=11
    openButton.Font=Enum.Font.GothamBold
    openButton.Parent=bar
    Instance.new("UICorner",openButton).CornerRadius=UDim.new(0,5)
end

local function showStatus(message,isReady)
    if statusText and statusText.Parent then
        statusText.Text=message
    end
    if openButton and openButton.Parent then
        openButton.Text=if isReady then "OPEN" else "RETRY"
    end
end

if not player then
    warn("[FERAL Territory Rush] Player not available.")
    return
end
if game.PlaceId~=GAME then
    showStatus("WRONG PLACE • join the FERAL Animal Survival match",false)
    warn("[FERAL Territory Rush] Expected FERAL Animal Survival match.")
    return
end

local function launch(name)
    local ok,err=pcall(function()
        local source=game:HttpGet(BASE..name)
        local compiled,syntaxError=loadstring(source)
        if type(compiled)~="function" then
            error("Luau compilation failed: "..tostring(syntaxError))
        end
        compiled()
    end)
    if not ok then
        warn("[FERAL Territory Rush] "..name..": "..tostring(err))
    end
    return ok,err
end

local launchingTerritory=false
local function startTerritory()
    local previous=env.FERAL_TERRITORY_RUSH_V4
    if type(previous)=="table" and type(previous.setPanelVisible)=="function" then
        previous.setPanelVisible(true)
        showStatus("TERRITORY READY • F7 hides/shows panel",true)
        return
    end
    if launchingTerritory then return end
    launchingTerritory=true
    showStatus("TERRITORY • LOADING GAME DATA...",false)
    task.spawn(function()
        local ok,err=launch("feral-territory-rush-v4.2.1.lua")
        launchingTerritory=false
        local api=env.FERAL_TERRITORY_RUSH_V4
        if type(api)=="table" and type(api.setPanelVisible)=="function" then
            api.setPanelVisible(true)
            showStatus("TERRITORY READY • press F7 to toggle",true)
        elseif ok then
            showStatus("NOT READY • spawn as animal, then RETRY",false)
        else
            showStatus("LOAD FAILED • "..tostring(err):sub(1,43),false)
        end
    end)
end

if openButton then
    openButton.Activated:Connect(startTerritory)
end

-- Territory runs first, and a slow main hub can no longer block its panel.
startTerritory()
if type(env.FERAL_NOVA_PRIME_ACTIVE)~="table" then
    task.spawn(function()
        launch("feral-nova-v13.5.7-eagle-talon-hover-fix-experimental-potassium.lua")
    end)
end
