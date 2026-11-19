-- FERAL NOVA PRIME v8: camera-projected tag overlay.
-- Replaces distance-clipped BillboardGui labels with small ScreenGui labels.
-- Viewport projection is visual only, never changes game character state.
local Tags={}
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local function create(kind,props,parent)
    local v=Instance.new(kind)
    for k,x in pairs(props) do v[k]=x end
    v.Parent=parent
    return v
end
function Tags.attach(ctx)
    local S=ctx.state
    local pg=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",8)
    if not pg then error("PlayerGui unavailable for tags") end
    local gui=create("ScreenGui",{
        Name="FeralNovaPrimeTagsV8",
        DisplayOrder=205,ResetOnSpawn=false,
        IgnoreGuiInset=true,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    },pg)
    local T={
        alive=true,gui=gui,active=0,visible=0,close=0,
        lastError="",frameInterval=.065,lastFrame=0
    }
    local labels={}
    local function clear(plr)
        local label=labels[plr]
        labels[plr]=nil
        if label then pcall(function()label:Destroy()end)end
    end
    local function labelFor(plr)
        local label=labels[plr]
        if label and label.Parent then return label end
        label=create("TextLabel",{
            Name="FloatingAnimalName",
            AnchorPoint=Vector2.new(.5,.5),
            Size=UDim2.fromOffset(172,22),
            BackgroundTransparency=1,
            Font=Enum.Font.GothamBold,
            TextSize=12,
            TextColor3=Color3.fromRGB(231,247,252),
            TextStrokeColor3=Color3.fromRGB(3,8,15),
            TextStrokeTransparency=.12,
            TextXAlignment=Enum.TextXAlignment.Center,
            TextYAlignment=Enum.TextYAlignment.Center,
            TextTruncate=Enum.TextTruncate.AtEnd,
            Visible=false,ZIndex=8
        },gui)
        labels[plr]=label
        return label
    end
    local function worldHead(record)
        local char=record.char
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        local head=char:FindFirstChild("Head")
        local p=(head and head:IsA("BasePart")) and head.Position or root.Position
        if not record.lastTopSample or os.clock()-record.lastTopSample>1.1 then
            record.lastTopSample=os.clock()
            local ok,cf,size=pcall(function()return char:GetBoundingBox()end)
            if ok and cf and size then
                record.cachedTop=cf.Position.Y+size.Y*.5
            end
        end
        local top=record.cachedTop
        if type(top)=="number" then
            -- Keep labels above head without floating above an entire huge
            -- model when giant decorative attachments distort its bounds.
            local lift=math.clamp(top-p.Y+.52,.6,5.5)
            return p+Vector3.new(0,lift,0),root
        end
        return p+Vector3.new(0,2.35,0),root
    end
    local function paint()
        if not T.alive or not S.alive then return end
        local now=os.clock()
        if now-T.lastFrame<T.frameInterval then return end
        T.lastFrame=now
        local camera=workspace.CurrentCamera
        if not camera then
            for _,lab in pairs(labels) do lab.Visible=false end
            T.visible=0
            return
        end
        local vp=camera.ViewportSize
        if vp.X<=0 or vp.Y<=0 then return end
        local enabled=S.flags.playerFinder and S.flags.tags
        local alive={}
        local shown=0
        local closeTags=0
        local total=0
        for plr,record in pairs(S.byPlayer) do
            if plr~=player and record and record.char and record.char.Parent then
                local world,root=worldHead(record)
                if world and root and root.Parent then
                    total+=1
                    local lab=labelFor(plr)
                    alive[plr]=true
                    -- Core tracker originally creates BillboardGui plates.
                    -- Disable their render; this overlay remains visible
                    -- even at extremely short camera/target distances.
                    if record.b then record.b.Enabled=false end
                    if enabled then
                        local pos,front=camera:WorldToViewportPoint(world)
                        local rootDist=(root.Position-camera.CFrame.Position).Magnitude
                        if rootDist<=S.range then
                            local closeCamera=rootDist<9
                            local x,y
                            if pos.Z>0 then
                                x=pos.X
                                y=pos.Y
                            elseif closeCamera then
                                -- Player may literally surround the camera.
                                -- Keep a small name chip at the top, instead
                                -- of silently dropping their name.
                                x=vp.X*.5
                                y=76+closeTags*24
                            end
                            if x and y then
                                x=math.clamp(x,93,vp.X-93)
                                y=math.clamp(y,35,vp.Y-35)
                                if closeCamera then
                                    y=math.min(y,104+closeTags*24)
                                    closeTags+=1
                                end
                                lab.Position=UDim2.fromOffset(x,y)
                                lab.Text=record.name and record.name.Text or plr.DisplayName
                                lab.TextColor3=record.h and record.h.OutlineColor
                                    or Color3.fromRGB(231,247,252)
                                lab.Visible=true
                                shown+=1
                            else
                                lab.Visible=false
                            end
                        else
                            lab.Visible=false
                        end
                    else
                        lab.Visible=false
                    end
                end
            end
        end
        for plr in pairs(labels) do
            if not alive[plr] then clear(plr) end
        end
        T.active=total
        T.visible=shown
        T.close=closeTags
    end
    function T.report()
        return "FERAL v8 Screen Tags | tracked="..tostring(T.active)..
            " visible="..tostring(T.visible)..
            " close="..tostring(T.close)..
            " enabled="..tostring(S.flags.tags)..
            " error="..tostring(T.lastError)
    end
    function T.close()
        if not T.alive then return end
        T.alive=false
        if T.connection then T.connection:Disconnect()end
        for plr in pairs(labels) do clear(plr) end
        if gui then pcall(function()gui:Destroy()end)end
    end
    T.connection=RunService.RenderStepped:Connect(function()
        local ok,err=pcall(paint)
        if not ok then T.lastError=tostring(err) end
    end)
    return T
end
return Tags
