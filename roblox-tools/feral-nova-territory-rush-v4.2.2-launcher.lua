-- FERAL NOVA + Territory Rush | Dual Panel v4.2.2
-- Main v13.5.8 and Territory v4.2.2; Right Shift controls both panels.
-- The two scripts start independently; a local status tab supports retry.
-- No gameplay-state changes are introduced by this layout coordinator.
local GAME=108901361810209
local BASE="https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/"
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local env=(type(getgenv)=="function" and getgenv()) or _G
local pg=player and player:WaitForChild("PlayerGui",15)

if not player or game.PlaceId~=GAME then
    warn("[FERAL Combined] Join FERAL Animal Survival before using this launcher.")
    return
end
if not pg then
    warn("[FERAL Combined] PlayerGui unavailable. Spawn first, then rerun.")
    return
end

local old=env.FERAL_DUAL_UI_SYNC
if type(old)=="table" and type(old.close)=="function" then
    pcall(old.close)
end
local existing=pg:FindFirstChild("FERAL_TerritoryLauncherStatus")
if existing then existing:Destroy() end
local statusGui=Instance.new("ScreenGui")
statusGui.Name="FERAL_TerritoryLauncherStatus"
statusGui.ResetOnSpawn=false
statusGui.IgnoreGuiInset=true
statusGui.DisplayOrder=900
statusGui.Parent=pg
local bar=Instance.new("Frame")
bar.Name="Status"
bar.AnchorPoint=Vector2.new(.5,0)
bar.Position=UDim2.new(.5,0,0,10)
bar.Size=UDim2.fromOffset(420,38)
bar.BorderSizePixel=0
bar.BackgroundColor3=Color3.fromRGB(21,34,41)
bar.Parent=statusGui
Instance.new("UICorner",bar).CornerRadius=UDim.new(0,7)
local stroke=Instance.new("UIStroke")
stroke.Color=Color3.fromRGB(66,112,116)
stroke.Parent=bar
local statusText=Instance.new("TextLabel")
statusText.BackgroundTransparency=1
statusText.Position=UDim2.fromOffset(10,0)
statusText.Size=UDim2.fromOffset(321,38)
statusText.Font=Enum.Font.GothamMedium
statusText.TextSize=11
statusText.TextXAlignment=Enum.TextXAlignment.Left
statusText.TextTruncate=Enum.TextTruncate.AtEnd
statusText.TextColor3=Color3.fromRGB(213,239,236)
statusText.Text="DUAL FERAL UI • STARTING..."
statusText.Parent=bar
local openButton=Instance.new("TextButton")
openButton.Name="OpenBoth"
openButton.Position=UDim2.fromOffset(334,5)
openButton.Size=UDim2.fromOffset(78,28)
openButton.BorderSizePixel=0
openButton.BackgroundColor3=Color3.fromRGB(44,107,100)
openButton.TextColor3=Color3.fromRGB(245,255,250)
openButton.Text="OPEN"
openButton.TextSize=11
openButton.Font=Enum.Font.GothamBold
openButton.Parent=bar
Instance.new("UICorner",openButton).CornerRadius=UDim.new(0,5)

local active=true
local desireVisible=true
local manager={}
local latestMain=nil
local latestTerritory=nil
local lastCamera=nil
local lastViewportX=nil
local lastViewportY=nil
local loadingMain=false
local loadingTerritory=false
local lastMainError=nil
local lastTerritoryError=nil
local watchConnection=nil

local function mainRecord()
    local main=env.FERAL_NOVA_PRIME_ACTIVE
    if type(main)=="table" and type(main.setMenuVisible)=="function"
        and typeof(main.menuShell)=="Instance" and main.menuShell.Parent then
        return main
    end
    return nil
end
local function territoryRecord()
    local territory=env.FERAL_TERRITORY_RUSH_V4
    if type(territory)=="table" and type(territory.setPanelVisible)=="function"
        and typeof(territory.panelFrame)=="Instance" and territory.panelFrame.Parent then
        return territory
    end
    return nil
end
local function refreshStatus()
    local main=mainRecord()
    local terr=territoryRecord()
    local both=main~=nil and terr~=nil
    local missing=nil
    if not main then missing="FERAL HUB" end
    if not terr then missing=if missing then missing.." + TERRITORY" else "TERRITORY" end
    if both then
        statusText.Text="DUAL PANELS • RIGHT SHIFT TO OPEN"
        openButton.Text="OPEN"
        -- Hidden panels retain this compact reopen control.
        statusGui.Enabled=not desireVisible
    elseif loadingTerritory or loadingMain then
        statusText.Text="STARTING • "..(missing or "loading")
        openButton.Text="WAIT"
        statusGui.Enabled=true
    else
        statusText.Text="RETRY • "..(missing or "waiting for game")..
            (lastTerritoryError and " (territory error)" or "")
        openButton.Text="RETRY"
        statusGui.Enabled=true
    end
end

function manager.scaleFor(viewport)
    if typeof(viewport)~="Vector2" then
        local cam=Workspace.CurrentCamera
        viewport=cam and cam.ViewportSize or Vector2.new(1366,768)
    end
    -- Shared scale: 830-wide main and 410-wide territory, 24 px gutter.
    local widthScale=(viewport.X-52)/(830+24+410)
    local heightScale=(viewport.Y-66)/828
    return math.clamp(math.min(1,widthScale,heightScale),0.29,1)
end

function manager.layout()
    if not active then return false end
    local main=mainRecord()
    local terr=territoryRecord()
    if not (main and terr) then return false end
    local cam=Workspace.CurrentCamera
    local viewport=cam and cam.ViewportSize or Vector2.new(1366,768)
    local scale=manager.scaleFor(viewport)
    if type(main.refitMenu)=="function" then
        pcall(main.refitMenu)
    end
    local totalWidth=(830+24+410)*scale
    local left=(viewport.X-totalWidth)*0.5
    local mainCentre=left+830*scale*.5
    local territoryLeft=left+(830+24)*scale
    local territoryTop=(viewport.Y-656*scale)*0.5
    main.menuShell.Position=UDim2.fromOffset(mainCentre,viewport.Y*.5)
    local frame=terr.panelFrame
    frame.Position=UDim2.fromOffset(territoryLeft,territoryTop)
    if terr.panelScale and terr.panelScale.Parent then
        terr.panelScale.Scale=scale
    end
    return true
end

function manager.onMainVisibility(visible)
    if not active then return end
    desireVisible=visible==true
    local terr=territoryRecord()
    if terr then
        terr.setPanelVisible(desireVisible)
    end
    refreshStatus()
end

function manager.setBothVisible(visible)
    if not active then return false end
    desireVisible=visible==true
    local main=mainRecord()
    if main then
        -- Use the native menu setter, not .Visible directly; this keeps
        -- FERAL's private 'hidden' state and floating reopen tab consistent.
        main.setMenuVisible(desireVisible)
    end
    local terr=territoryRecord()
    if terr then terr.setPanelVisible(desireVisible) end
    if desireVisible then manager.layout() end
    refreshStatus()
    return true
end

function manager.onTerritoryHotkey()
    -- When the main hub is ready, its original RightShift listener is
    -- authoritative. It invokes onMainVisibility(), which updates territory.
    if mainRecord() then return end
    -- Territory can still be opened/hidden before FERAL's big hub loads.
    return manager.setBothVisible(not desireVisible)
end

function manager.onTerritoryReady()
    if not active then return end
    local terr=territoryRecord()
    if terr then
        latestTerritory=terr
        terr.setPanelVisible(desireVisible)
    end
    manager.layout()
    refreshStatus()
end

function manager.close()
    if not active then return end
    active=false
    if watchConnection then watchConnection:Disconnect();watchConnection=nil end
    if statusGui then statusGui:Destroy() end
    if env.FERAL_DUAL_UI_SYNC==manager then
        env.FERAL_DUAL_UI_SYNC=nil
    end
end
env.FERAL_DUAL_UI_SYNC=manager

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
        warn("[FERAL Combined] "..name..": "..tostring(err))
    end
    return ok,err
end

local function startTerritory()
    local previous=territoryRecord()
    if previous then
        manager.setBothVisible(true)
        return
    end
    if loadingTerritory then return end
    loadingTerritory=true
    refreshStatus()
    task.spawn(function()
        local ok,err=launch("feral-territory-rush-v4.2.2.lua")
        loadingTerritory=false
        lastTerritoryError=if ok then nil else tostring(err):sub(1,105)
        manager.onTerritoryReady()
        if not territoryRecord() and ok then
            lastTerritoryError="Spawn as an animal and join a pack, then retry"
        end
        refreshStatus()
    end)
end

local function startMain()
    local main=mainRecord()
    if main then
        manager.setBothVisible(true)
        return
    end
    if loadingMain then return end
    loadingMain=true
    refreshStatus()
    task.spawn(function()
        local ok,err=launch("feral-nova-v13.5.8-dual-ui-potassium.lua")
        loadingMain=false
        lastMainError=if ok then nil else tostring(err):sub(1,105)
        local current=mainRecord()
        if current then
            latestMain=current
            current.setMenuVisible(desireVisible)
            manager.layout()
        else
            if ok then lastMainError="Hub GUI was not mounted" end
        end
        refreshStatus()
    end)
end

openButton.Activated:Connect(function()
    if mainRecord() and territoryRecord() then
        manager.setBothVisible(true)
    else
        if not territoryRecord() then startTerritory() end
        if not mainRecord() then startMain() end
    end
end)

local lastTick=0
watchConnection=RunService.Heartbeat:Connect(function()
    if not active then return end
    local now=os.clock()
    if now-lastTick<0.45 then return end
    lastTick=now
    local main=mainRecord()
    local terr=territoryRecord()
    local newMain=main and main~=latestMain
    local newTerritory=terr and terr~=latestTerritory
    if newMain then
        latestMain=main
        main.setMenuVisible(desireVisible)
    end
    if newTerritory then
        latestTerritory=terr
        terr.setPanelVisible(desireVisible)
    end
    local cam=Workspace.CurrentCamera
    local viewport=cam and cam.ViewportSize
    local resized=viewport and (lastViewportX~=viewport.X or
        lastViewportY~=viewport.Y or cam~=lastCamera)
    if resized then
        lastCamera=cam
        lastViewportX,lastViewportY=viewport.X,viewport.Y
    end
    if newMain or newTerritory or resized then
        manager.layout()
    end
    refreshStatus()
end)

-- Both loaders run independently. Neither can block the other's startup.
startTerritory()
startMain()
