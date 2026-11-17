-- BOOGA REBORN / VALUE ENGINE v1.0
-- Economy-oriented automation based on actual client modules (PlaceId 11729688377).
-- Features: auto-cast/reel, fisherman sale, smart pickup, ore pathing + mining,
-- live wallet feedback, multi-item market discount radar and optional one-click buy.
-- Does not forge item grants, edit balances, or claim any unverified income.
-- F6 stops all automation. Re-run removes prior UI/connections.
if game.PlaceId ~= 11729688377 then warn("[VALUE] Join Booga Booga Reborn first."); return end
local S=function(name) return game:GetService(name) end
local Players=S("Players")
local RS=S("ReplicatedStorage")
local WS=S("Workspace")
local CS=S("CollectionService")
local PFS=S("PathfindingService")
local UIS=S("UserInputService")
local Run=S("RunService")
local lp=Players.LocalPlayer
local pg=lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui",8))
if not pg then return end
local old=pg:FindFirstChild("BoogaValueEngineV10")
if old then
    local x=old:FindFirstChild("Shutdown")
    if x and x:IsA("BindableEvent") then pcall(function() x:Fire() end) end
    if old.Parent then old:Destroy() end
end

local M=RS:FindFirstChild("Modules")
local U=M and M:FindFirstChild("util")
local DAT=M and M:FindFirstChild("data")
local function requireAt(root,name)
    local mod=root and root:FindFirstChild(name)
    if not mod or not mod:IsA("ModuleScript") then return nil end
    local ok,value=pcall(require,mod)
    return ok and value or nil
end
local packets=requireAt(U,"packets")
local gameUtil=requireAt(U,"gameUtil")
local clock=requireAt(U,"clock")
local itemData=requireAt(DAT,"itemData")
local itemIDS=requireAt(DAT,"itemIDS")
local marketCodes=requireAt(DAT,"marketCodes")
local fishermanData=requireAt(DAT,"fishermanData")
if not packets or not gameUtil or not itemData then
    warn("[VALUE] Required Booga modules unavailable. Load fully and retry."); return
end
local rodModule
local function rod()
    if rodModule then return rodModule end
    local gameDir=RS:FindFirstChild("Game")
    local toolDir=gameDir and gameDir:FindFirstChild("tool")
    local module=toolDir and toolDir:FindFirstChild("Rod")
    if module then
        local ok,fn=pcall(require,module)
        if ok and type(fn)=="function" then rodModule=fn end
    end
    return rodModule
end

local live=true
local flags={fish=false,sell=false,loot=false,mine=false,market=false,navigate=false}
local connections={}
local counts={pickupRequests=0,fishCaught=0,fishSales=0,oreHits=0,marketQueries=0}
local stamp={loot=0,fish=0,sell=0,mine=0,market=0,ui=0}
local status={fish="Equip a rod and point at water.",sell="Find a Fisherman Trader.",loot="Pickup magnet idle.",mine="Ore miner idle.",market="Deal scanner idle."}
local fishState={lastCast=0,lastReel=0,lastCatchAt=0,pendingCatch=false}
local sellState={pending=nil,next=0,lastCoins=0}
local mineState={target=nil,bad=setmetatable({},{__mode="k"}),lastHP=nil,lastHPAt=0,started=0,routeID=0,walking=false}
local marketState={watch={},pointer=1,pending=nil,results={},selected=nil,wallet=nil,lastError="",notice="",lastQuery=0}
local initialCoins=nil
local initialFishCoins=nil
local lastInventory={}
local fishSeen=false
local buttons={}
local uptime=os.clock()
local colors={bg=Color3.fromRGB(15,22,33),panel=Color3.fromRGB(25,39,55),
    accent=Color3.fromRGB(58,215,189),text=Color3.fromRGB(236,246,252),
    muted=Color3.fromRGB(172,193,207),warn=Color3.fromRGB(248,202,117),
    red=Color3.fromRGB(202,81,101)}
local function ui(class,props,parent)
    local a=Instance.new(class)
    for k,v in pairs(props or {}) do a[k]=v end
    if parent then a.Parent=parent end
    return a
end
local function corners(a,n)
    ui("UICorner",{CornerRadius=UDim.new(0,n or 8)},a)
    return a
end
local screen=ui("ScreenGui",{Name="BoogaValueEngineV10",ResetOnSpawn=false,DisplayOrder=180},pg)
local shutdown=ui("BindableEvent",{Name="Shutdown"},screen)
local main=corners(ui("Frame",{Size=UDim2.fromOffset(612,474),
    Position=UDim2.fromScale(.5,.12),AnchorPoint=Vector2.new(.5,0),
    BackgroundColor3=colors.bg,BorderSizePixel=0,Active=true},screen),12)
ui("UIStroke",{Color=colors.accent,Thickness=1,Transparency=.35},main)
local heading=ui("TextLabel",{Text="BOOGA  /  VALUE ENGINE",Position=UDim2.fromOffset(15,9),
    Size=UDim2.fromOffset(480,33),TextColor3=colors.accent,Font=Enum.Font.GothamBold,
    TextSize=18,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left},main)
local sub=ui("TextLabel",{Text="Real loot • smarter fishing • ore automation • market opportunities",
    Position=UDim2.fromOffset(17,42),Size=UDim2.fromOffset(562,22),
    TextColor3=colors.muted,Font=Enum.Font.Gotham,TextSize=11,
    BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left},main)
local tabRow=ui("Frame",{Position=UDim2.fromOffset(16,79),Size=UDim2.fromOffset(580,35),
    BackgroundTransparency=1},main)
local area=ui("Frame",{Position=UDim2.fromOffset(16,120),Size=UDim2.fromOffset(580,292),
    BackgroundColor3=colors.panel,BorderSizePixel=0},main)
corners(area,9)
local pages={}
local activePage="FARM"
local function label(parent,txt,x,y,w,h,size,color,bold)
    return ui("TextLabel",{Text=txt,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h),TextColor3=color or colors.text,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=size or 12,BackgroundTransparency=1,TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left},parent)
end
local function btn(parent,txt,x,y,w,h,fn,tint)
    local b=corners(ui("TextButton",{Text=txt,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h),BackgroundColor3=tint or Color3.fromRGB(42,63,81),
        BorderSizePixel=0,Font=Enum.Font.GothamBold,TextSize=11,
        TextColor3=colors.text},parent),7)
    b.Activated:Connect(fn)
    return b
end
for _,name in ipairs({"FARM","FISH","MARKET"}) do
    pages[name]=ui("Frame",{Name=name,Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,Visible=name==activePage},area)
end
local tabButtons={}
local function showPage(name)
    activePage=name
    for key,panel in pairs(pages) do panel.Visible=key==name end
    for key,button in pairs(tabButtons) do
        button.BackgroundColor3=key==name and colors.accent or colors.panel
        button.TextColor3=key==name and colors.bg or colors.text
    end
end
for i,name in ipairs({"FARM","FISH","MARKET"}) do
    tabButtons[name]=btn(tabRow,name,(i-1)*194,0,187,34,function()showPage(name)end)
end
showPage("FARM")
local function flagButton(page,name,txt,x,y,w,h)
    local b
    b=btn(page,txt.."  [OFF]",x,y,w,h,function()
        flags[name]=not flags[name]
        b.Text=txt..(flags[name] and "  [ON]" or "  [OFF]")
        b.BackgroundColor3=flags[name] and Color3.fromRGB(20,113,95) or Color3.fromRGB(42,63,81)
        if not flags.mine then
            mineState.target=nil;mineState.routeID+=1;mineState.walking=false
        end
        if not flags.sell then sellState.pending=nil end
    end)
    buttons[name]={node=b,prefix=txt}
    return b
end
local farm=pages.FARM
label(farm,"AUTO LOOT + ORE ROUTE",13,10,360,26,14,colors.accent,true)
flagButton(farm,"loot","PICKUP MAGNET",12,45,178,33)
flagButton(farm,"mine","AUTO MINE ORES",199,45,178,33)
flagButton(farm,"navigate","WALK TO NODES",386,45,180,33)
local farmNotes=label(farm,"",13,89,552,83,12,colors.text)
local oreInfo=label(farm,"",13,180,552,83,11,colors.muted)
label(farm,"Pick an appropriate mining tool. Walk mode uses normal pathfinding, not teleportation.",
    13,262,550,23,10,colors.warn)
local fish=pages.FISH
label(fish,"AUTO FISHING + FISHERMAN SALES",13,10,500,26,14,colors.accent,true)
flagButton(fish,"fish","AUTO CAST + REEL",12,44,270,37)
flagButton(fish,"sell","AUTO SELL NEAR TRADER",292,44,273,37)
local fishNotes=label(fish,"",13,96,553,112,12,colors.text)
local fishValue=label(fish,"",13,214,554,64,11,colors.muted)
local market=pages.MARKET
label(market,"GLOBAL MARKET  /  UNDER-RAP RADAR",13,8,540,28,14,colors.accent,true)
flagButton(market,"market","SCAN WATCHLIST",12,42,212,35)
local deals=label(market,"",13,88,550,126,12,colors.text)
local marketStatus=label(market,"",13,220,550,56,11,colors.muted)
local buyBtn
local buyConfirm=false
local buySelectedAt=0
local function formatNumber(v)
    if type(v)~="number" then return "--" end
    if math.abs(v)>=1e6 then return string.format("%.2fm",v/1e6) end
    if math.abs(v)>=1e3 then return string.format("%.1fk",v/1e3) end
    return string.format("%.0f",v)
end
local function signed(v)
    return (v>=0 and "+" or "")..formatNumber(v)
end
local function data()
    return gameUtil and gameUtil.Data or nil
end
local function playerRoot()
    local char=lp.Character
    local h=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    return char and h and h.Health>0 and root or nil,h
end
local function inventory()
    local d=data()
    return d and type(d.inventory)=="table" and d.inventory or {}
end
local function inventoryCounts()
    local tally={}
    for _,v in pairs(inventory()) do
        if type(v)=="table" and type(v.name)=="string" then
            tally[v.name]=(tally[v.name] or 0)+math.max(0,tonumber(v.quantity) or 1)
        end
    end
    return tally
end
local function snapshotBalances()
    local d=data() or {}
    return tonumber(d.coins) or 0,tonumber(d.fishermanCoins) or 0
end
local function pointOf(entity)
    if entity:IsA("Model") then
        local part=entity.PrimaryPart or entity:FindFirstChildWhichIsA("BasePart",true)
        return part and part.Position or nil
    end
    return entity:IsA("BasePart") and entity.Position or nil
end
local function near(entity,r)
    local root=playerRoot()
    local p=root and pointOf(entity)
    return p and (p-root.Position).Magnitude<=r or false
end
local function validEntity(entity)
    if not entity or not entity:IsDescendantOf(WS) then return nil end
    local id=entity:GetAttribute("EntityID")
    return typeof(id)=="number" and id or nil
end

-- Actual item pricing, not user-invented values.
local sellPrices=(fishermanData and fishermanData.sellPrices) or {}
local function sellableFish()
    local inv=inventoryCounts()
    local list={}
    local sum=0
    for name,price in pairs(sellPrices) do
        local amount=inv[name] or 0
        if amount>0 then
            list[#list+1]={name=name,amount=amount,price=price,total=price*amount}
            sum+=price*amount
        end
    end
    table.sort(list,function(a,b)return a.total>b.total end)
    return list,sum
end
local function nearbyTrader()
    local folder=WS:FindFirstChild("DialogNPCs")
    if not folder then return nil end
    for _,entity in ipairs(folder:GetDescendants()) do
        if entity:IsA("Model") and entity.Name=="Fisherman Trader" and near(entity,23) then
            return entity
        end
    end
    return nil
end
local function sellStep(now)
    if not flags.sell or not packets.SellFish or type(packets.SellFish.send)~="function" then return end
    local list,total=sellableFish()
    if #list==0 then status.sell="No unsold fish in inventory.";return end
    if not nearbyTrader() then
        status.sell="Trader not within 23 studs. Walk to the Fisherman Trader.";return
    end
    local _,fishCoins=snapshotBalances()
    if sellState.pending then
        local p=sellState.pending
        local quantity=inventoryCounts()[p.name] or 0
        if fishCoins>p.before or quantity<p.quantity then
            counts.fishSales+=1
            status.sell=string.format("SOLD %s • %s Fisherman Coins delta",p.name,
                formatNumber(fishCoins-p.before))
            sellState.pending=nil
            sellState.next=now+1.2
        elseif now-p.time>6 then
            status.sell="Seller did not confirm "..p.name..". Stopped to avoid repeat requests."
            flags.sell=false;sellState.pending=nil
        end
        return
    end
    if now<sellState.next then return end
    local selected=list[1]
    local ok=pcall(packets.SellFish.send,selected.name)
    if ok then
        sellState.pending={name=selected.name,quantity=selected.amount,before=fishCoins,time=now}
        status.sell="Awaiting server sale confirmation for "..selected.name
    else
        flags.sell=false
        status.sell="SellFish API rejected the request."
    end
    sellState.next=now+2
end

-- Loot magnet: existing server world drops only. No fake gold/material IDs.
local pickupCooldown=setmetatable({},{__mode="k"})
local function pickupStep(now)
    if not flags.loot or now-stamp.loot<.28 then return end
    stamp.loot=now
    if not packets.Pickup or type(packets.Pickup.send)~="function" then
        status.loot="Pickup client packet unavailable.";flags.loot=false;return
    end
    local root=playerRoot()
    local items=WS:FindFirstChild("Items")
    if not root or not items then return end
    local selected,best=nil,math.huge
    for _,entity in ipairs(items:GetChildren()) do
        local id=validEntity(entity)
        local p=id and pointOf(entity)
        if p and CS:HasTag(entity,"Pickup") and
            (now-(pickupCooldown[entity] or -100))>3 then
            local distance=(p-root.Position).Magnitude
            if distance<=23 and distance<best then
                selected=entity;best=distance
            end
        end
    end
    if selected then
        local id=validEntity(selected)
        pickupCooldown[selected]=now
        local ok=pcall(packets.Pickup.send,id)
        if ok then
            counts.pickupRequests+=1
            status.loot=string.format("Requesting %s (%.0f studs). Requests: %d",
                selected.Name,best,counts.pickupRequests)
        else
            status.loot="Pickup packet rejected; stopping magnet."
            flags.loot=false
        end
    else
        status.loot="No unclaimed Pickup-tagged drops in 23 studs."
    end
end

-- Auto-reel uses exact BobberState owner/state identified in the archived Rod.
local function listen(packet,fn)
    if not packet or type(packet.listen)~="function" then return end
    local ok,conn=pcall(packet.listen,fn)
    if ok then connections[#connections+1]=conn end
end
listen(packets.BobberState,function(event)
    if not live or not flags.fish or type(event)~="table" then return end
    local playerID=lp:GetAttribute("EntityID")
    if event.owner~=playerID or event.state~="hooked" then return end
    local now=os.clock()
    if now-fishState.lastReel<.8 then return end
    fishState.lastReel=now
    local serial=fishState.lastReel
    task.delay(.10,function()
        if not live or not flags.fish or fishState.lastReel~=serial then return end
        local ok=packets.RodEnd and pcall(packets.RodEnd.send)
        if ok then
            fishState.pendingCatch=true
            status.fish="Auto-reel sent on confirmed hook; awaiting fish."
        else
            status.fish="RodEnd packet not available."
            flags.fish=false
        end
    end)
end)
local function equippedInfo()
    local d=data()
    if not d or type(d.toolbar)~="table" then return nil end
    local equipped=d.equipped
    local slot=equipped and d.toolbar[equipped]
    local name=slot and slot.name
    local item=name and itemData[name]
    return name,item
end
local function fishStep(now)
    if not flags.fish or now-stamp.fish<1 then return end
    stamp.fish=now
    if not packets.RodEnd or type(packets.RodEnd.send)~="function" then
        status.fish="RodEnd unavailable.";flags.fish=false;return
    end
    local name,cfg=equippedInfo()
    if not cfg or cfg.useType~="Rod" then
        status.fish="Equip a Fishing Rod in your toolbar before enabling Auto Fish."
        return
    end
    local root=playerRoot()
    if not root then return end
    if lp:GetAttribute("Fishing")==true then
        status.fish="Waiting for a fish to hook..."
        if now-fishState.lastCast>32 and fishState.lastCast>0 then
            -- Stuck-line recovery uses the normal RodEnd action once.
            fishState.lastCast=now
            pcall(packets.RodEnd.send)
            status.fish="Reset an unusually long fishing attempt."
        end
        return
    end
    if now-fishState.lastCast<4.5 or now-fishState.lastReel<1.5 then return end
    local useRod=rod()
    if not useRod then
        status.fish="Game/tool/Rod unavailable; automatic casting unsupported."
        flags.fish=false;return
    end
    local ok,err=pcall(useRod,cfg,name)
    if ok then
        fishState.lastCast=now
        status.fish="Cast attempted. Keep the camera aimed at water."
    else
        status.fish="Rod casting failed. Re-equip rod or aim at water."
        flags.fish=false
    end
end

-- Rare-resource priority: names are from Workspace.Resources in the captured game.
local oreWeights={
    ["Magnetite Node"]=100,["Adurite Node"]=95,["Crystal Lode"]=94,
    ["Emerald Lode"]=90,["Gold Node"]=80,["Iron Node"]=65,
    ["Coal Node"]=45,["Stone Node"]=20,["Small Rock"]=10,
    ["Big Rock"]=10
}
local function pickOre(now)
    local root=playerRoot()
    local resources=WS:FindFirstChild("Resources")
    if not root or not resources then return nil end
    local best,bestScore=nil,-math.huge
    for _,model in ipairs(resources:GetChildren()) do
        local score=oreWeights[model.Name]
        local id=score and validEntity(model)
        local p=id and pointOf(model)
        local hp=model:FindFirstChild("Health")
        if p and hp and type(hp.Value)=="number" and hp.Value>0
            and now-(mineState.bad[model] or -100)>48 then
            local dist=(p-root.Position).Magnitude
            if dist<155 then
                local weight=score*3-dist
                if weight>bestScore then
                    bestScore=weight;best=model
                end
            end
        end
    end
    return best
end
local function walkTo(node,routeID)
    local root,hum=playerRoot()
    local p=node and pointOf(node)
    if not root or not hum or not p then return end
    local path=PFS:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true})
    local success=pcall(function()path:ComputeAsync(root.Position,p)end)
    if not success or path.Status~=Enum.PathStatus.Success then
        if live and flags.mine and flags.navigate and routeID==mineState.routeID then
            hum:MoveTo(p)
        end
        mineState.walking=false
        return
    end
    for _,wp in ipairs(path:GetWaypoints()) do
        if not live or not flags.mine or not flags.navigate or
            routeID~=mineState.routeID or not node.Parent then break end
        if near(node,7) then break end
        if wp.Action==Enum.PathWaypointAction.Jump then hum.Jump=true end
        hum:MoveTo(wp.Position)
        local reached=false
        local done=false
        local c=hum.MoveToFinished:Connect(function(got)reached=got;done=true end)
        local t=os.clock()
        while live and flags.mine and routeID==mineState.routeID
            and os.clock()-t<2.7 and not done and not near(node,7) do task.wait(.12) end
        c:Disconnect()
        if not reached and not near(node,7) then break end
    end
    mineState.walking=false
end
local function mineStep(now)
    if not flags.mine or now-stamp.mine<.34 then return end
    stamp.mine=now
    if not packets.SwingTool or type(packets.SwingTool.send)~="function"
        or not clock or type(clock.getServerTime)~="function" then
        flags.mine=false;status.mine="Game attack/clock packet unavailable.";return
    end
    local name,cfg=equippedInfo()
    if not cfg or (cfg.useType~="Slash" and cfg.useType~="Combat") then
        status.mine="Equip a real mine-capable tool (pickaxe/club/rock).";return
    end
    local root=playerRoot()
    if not root then return end
    local target=mineState.target
    if not target or not target.Parent or not validEntity(target)
        or (target:FindFirstChild("Health") and target.Health.Value<=0) then
        mineState.target=pickOre(now)
        mineState.routeID+=1;mineState.walking=false
        mineState.started=now;mineState.lastHPAt=now
        target=mineState.target
    end
    if not target then
        status.mine="No supported ore nodes within 155 studs.";return
    end
    local p=pointOf(target)
    if not p then mineState.target=nil;return end
    local distance=(root.Position-p).Magnitude
    if distance>7.5 then
        if not flags.navigate then
            status.mine=string.format("%s %.0f studs away. Enable WALK TO NODES.",
                target.Name,distance)
            return
        end
        status.mine=string.format("PATHING → %s (%.0f studs)",target.Name,distance)
        mineState.lastHPAt=now
        if not mineState.walking then
            mineState.walking=true;mineState.routeID+=1
            local route=mineState.routeID
            task.spawn(function()walkTo(target,route)end)
        end
        if now-mineState.started>24 then
            mineState.bad[target]=now;mineState.target=nil
            mineState.routeID+=1;mineState.walking=false
        end
        return
    end
    mineState.routeID+=1;mineState.walking=false
    -- Server validates actual range/cooldown. We do not invent extra damage.
    local v=Vector3.new(p.X,root.Position.Y,p.Z)
    if (v-root.Position).Magnitude>.15 then
        root.CFrame=CFrame.lookAt(root.Position,v)
    end
    local hp=target:FindFirstChild("Health")
    if hp and type(hp.Value)=="number" then
        if mineState.lastHP and hp.Value<mineState.lastHP then
            mineState.lastHPAt=now
        end
        mineState.lastHP=hp.Value
    end
    if now-mineState.lastHPAt>12 then
        mineState.bad[target]=now;mineState.target=nil
        status.mine="No real HP loss after 12 sec; skipping target."
        return
    end
    local interval=math.max(.25,tonumber(cfg.speed) or .5)
    if now-mineState.started<.2 or now-(mineState.lastHit or 0)<interval then return end
    local id=validEntity(target)
    local char=lp.Character
    if not id or not char then return end
    mineState.lastHit=now
    local ok=pcall(packets.SwingTool.send,{
        entityIDs={id},cframe=char:GetPivot(),timestamp=clock.getServerTime(true)
    })
    if ok then
        counts.oreHits+=1
        status.mine=string.format("%s | HP %s | hits %d",
            target.Name,hp and formatNumber(hp.Value) or "?",counts.oreHits)
    else
        flags.mine=false;status.mine="SwingTool send failed."
    end
end

-- Price scanner asks for listings through the game's real public market API.
local watchNames={
    "Pie","Gold","Magnetite","Adurite","Diamond","Emerald",
    "Raw Gold","Iron","Crystal","Void Shard","Essence",
    "Raw Magnetite","Raw Adurite","God Axe","Gold Fish"
}
if itemIDS and marketCodes then
    for _,name in ipairs(watchNames) do
        local id=itemIDS[name]
        if type(id)=="number" then
            marketState.watch[#marketState.watch+1]={name=name,id=id}
        end
    end
end
local function processMarketItem(v)
    if type(v)~="table" then return end
    local p=marketState.pending
    if not p or v.itemId~=p.id then return end
    marketState.pending=nil
    local history=v.rapHistoryTenths
    local recent=type(history)=="table" and tonumber(history[#history] or 0) or 0
    local cheapest=nil
    for _,entry in ipairs(v.listings or {}) do
        if type(entry)=="table" and type(entry.priceTenths)=="number"
            and entry.priceTenths>0 and entry.quantity and entry.quantity>0 then
            if not cheapest or entry.priceTenths<cheapest.priceTenths then cheapest=entry end
        end
    end
    if cheapest and recent>0 then
        local discount=1-cheapest.priceTenths/recent
        marketState.results[p.name]={
            name=p.name,rap=recent/10,price=cheapest.priceTenths/10,
            discount=discount,listingId=cheapest.listingId,
            quantity=cheapest.quantity,
            priceTenths=cheapest.priceTenths,time=os.clock()
        }
    end
end
listen(packets.MarketPayload,function(result)
    if not live or type(result)~="table" then return end
    if result.item then processMarketItem(result.item) end
    if type(result.wallets)=="table" then
        for _,w in ipairs(result.wallets) do
            if w.assetType==0 and w.itemId==0 then
                marketState.wallet=tonumber(w.spendable)
            end
        end
    end
    if result.notice then
        marketState.notice="Market returned a transaction notice; check in-game wallet."
    end
end)
local function marketStep(now)
    if not flags.market or now-stamp.market<1 then return end
    stamp.market=now
    if not packets.MarketRequest or type(packets.MarketRequest.send)~="function"
        or #marketState.watch==0 or not marketCodes then
        flags.market=false;status.market="Market interface unavailable.";return
    end
    if marketState.pending then
        if now-marketState.pending.time>7 then
            status.market="Market query timed out for "..marketState.pending.name
            marketState.pending=nil
        else return end
    end
    if now-marketState.lastQuery<2.6 then return end
    local item=marketState.watch[marketState.pointer]
    marketState.pointer=marketState.pointer%#marketState.watch+1
    local request={itemView={
        itemId=item.id,listingType=marketCodes.listingType.code.item,
        order=marketCodes.itemOrder.code.priceAscending,skip=0
    }}
    local ok=pcall(packets.MarketRequest.send,request)
    if ok then
        marketState.pending={id=item.id,name=item.name,time=now}
        marketState.lastQuery=now
        counts.marketQueries+=1
        status.market="Scanning "..item.name.." • "..counts.marketQueries.." queries"
    else
        flags.market=false
        status.market="Market request not accepted."
    end
end
local function rankedDeals()
    local list={}
    for _,v in pairs(marketState.results) do
        if os.clock()-v.time<180 then list[#list+1]=v end
    end
    table.sort(list,function(a,b) return a.discount>b.discount end)
    return list
end
buyBtn=btn(market,"BUY TOP DEAL  /  CONFIRM",336,42,231,35,function()
    local list=rankedDeals()
    local best=list[1]
    if not best or best.discount<.35 then
        status.market="No currently scanned deal at least 35% below RAP."
        buyConfirm=false;return
    end
    local now=os.clock()
    if not buyConfirm or now-buySelectedAt>5 then
        buyConfirm=true;buySelectedAt=now
        status.market=string.format("Confirm within 5 sec: buy 1 %s for %s market coins",
            best.name,formatNumber(best.price))
        return
    end
    buyConfirm=false
    if marketState.wallet==nil or marketState.wallet<best.price then
        status.market="Market wallet balance not verified or insufficient. Deposit market coins in-game."
        return
    end
    if now-best.time>60 then
        status.market="Deal too old; wait for a fresh market scan.";return
    end
    local ok=pcall(packets.MarketRequest.send,{
        buy={listingId=best.listingId,quantity=1,expectedPriceTenths=best.priceTenths}
    })
    if ok then
        status.market="Buy request sent for 1 "..best.name..". Check Market settlement notice."
        marketState.wallet=nil
        marketState.results[best.name]=nil
    else
        status.market="Buy request failed. No purchase confirmed."
    end
end,Color3.fromRGB(84,79,44))

-- Simple interactive dragging and emergency stop.
local drag,dragPos,panelPos=nil,nil,nil
main.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        local y=input.Position.Y-main.AbsolutePosition.Y
        if y<42 then
            drag=input;dragPos=input.Position;panelPos=main.Position
        end
    end
end)
UIS.InputChanged:Connect(function(input)
    if drag and input.UserInputType==Enum.UserInputType.MouseMovement then
        local delta=input.Position-dragPos
        main.Position=UDim2.new(panelPos.X.Scale,panelPos.X.Offset+delta.X,
            panelPos.Y.Scale,panelPos.Y.Offset+delta.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input==drag then drag=nil end
end)
local function stopAll()
    for k in pairs(flags) do flags[k]=false end
    mineState.target=nil;mineState.routeID+=1;mineState.walking=false
    sellState.pending=nil
    status.mine="All automation stopped."
    status.fish="Stopped."
    status.loot="Stopped."
    status.sell="Stopped."
    status.market="Stopped."
    buyConfirm=false
end
btn(main,"STOP ALL  [F6]",444,12,150,30,stopAll,Color3.fromRGB(126,48,63))
connections[#connections+1]=UIS.InputBegan:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.F6 then stopAll() end
end)
local lastCoins=0
local lastFish=0
local footer=label(main,"",17,422,575,43,12,colors.accent,true)
local function paint()
    local coins,fishcoins=snapshotBalances()
    if not initialCoins then initialCoins=coins end
    if not initialFishCoins then initialFishCoins=fishcoins end
    local list,total=sellableFish()
    local newest=inventoryCounts()
    if fishSeen then
        for name in pairs(sellPrices) do
            if (newest[name] or 0)>(lastInventory[name] or 0) then
                counts.fishCaught+=(newest[name] or 0)-(lastInventory[name] or 0)
            end
        end
    end
    lastInventory=newest
    fishSeen=true
    for key,value in pairs(buttons) do
        local b=value.node
        b.Text=value.prefix..(flags[key] and "  [ON]" or "  [OFF]")
        b.BackgroundColor3=flags[key] and Color3.fromRGB(20,113,95)
            or Color3.fromRGB(42,63,81)
    end
    footer.Text=string.format("Coins %s (%s)  |  Fisherman Coins %s (%s)  |  Uptime %.0fm",
        formatNumber(coins),signed(coins-initialCoins),
        formatNumber(fishcoins),signed(fishcoins-initialFishCoins),
        (os.clock()-uptime)/60)
    local target=mineState.target
    farmNotes.Text="PICKUP: "..status.loot.."\n\nORE: "..status.mine
    local root=playerRoot()
    local resources=WS:FindFirstChild("Resources")
    local loaded=resources and #resources:GetChildren() or 0
    oreInfo.Text=string.format("Visible resource models: %d   •   Ground pickups requested: %d\n"..
        "Ore attacks attempted: %d   •   Navigation: %s\n"..
        "Node: %s",loaded,counts.pickupRequests,counts.oreHits,
        flags.navigate and "enabled" or "off",target and target.Name or "none")
    local name=select(1,equippedInfo()) or "none"
    fishNotes.Text="ROD: "..status.fish.."\n\nSALE: "..status.sell..
        "\n\nEquipped: "..name.."  •  New fish observed: "..counts.fishCaught..
        "  •  Sales confirmed: "..counts.fishSales
    local pieces={}
    for i=1,math.min(4,#list) do
        pieces[#pieces+1]=list[i].name.." ×"..formatNumber(list[i].amount)
    end
    fishValue.Text="Potential Fisherman sale: "..formatNumber(total)..
        " coins\nOwned fish: "..(#pieces>0 and table.concat(pieces,", ") or "none")
    local rows={}
    local ranked=rankedDeals()
    for i=1,math.min(6,#ranked) do
        local v=ranked[i]
        rows[#rows+1]=string.format("%d. %s   %s vs RAP %s   [%+.0f%% below]",
            i,v.name,formatNumber(v.price),formatNumber(v.rap),v.discount*100)
    end
    deals.Text=#rows>0 and table.concat(rows,"\n") or
        "Enable SCAN WATCHLIST to search actual market listings.\n"..
        "Deal percentage compares current asking price to recent RAP.\n"..
        "No automatic buying; purchase needs two button presses."
    marketStatus.Text=status.market..
        "\nMarket wallet spendable: "..formatNumber(marketState.wallet)..
        ". Below-RAP is NOT guaranteed resale profit."
    if buyConfirm and os.clock()-buySelectedAt>5 then buyConfirm=false end
end
local function cleanup()
    if not live then return end
    live=false;stopAll()
    for _,connection in ipairs(connections) do
        if typeof(connection)=="RBXScriptConnection" then pcall(function()connection:Disconnect()end)
        elseif type(connection)=="function" then pcall(connection)
        elseif type(connection)=="table" and type(connection.Disconnect)=="function" then
            pcall(function()connection:Disconnect()end)
        end
    end
    screen:Destroy()
end
shutdown.Event:Connect(cleanup)
local closed=btn(main,"X",410,12,29,30,cleanup)
local nextTick=0
connections[#connections+1]=Run.Heartbeat:Connect(function()
    if not live then return end
    local now=os.clock()
    if now<nextTick then return end
    nextTick=now+.16
    local ok,err=pcall(function()
        if not UIS:GetFocusedTextBox() then
            pickupStep(now)
            mineStep(now)
            fishStep(now)
            sellStep(now)
            marketStep(now)
        end
        if now-stamp.ui>.5 then
            stamp.ui=now
            paint()
        end
    end)
    if not ok then
        stopAll()
        status.mine="Stopped on local error; check Velocity console."
        warn("[VALUE] Guarded runtime error: "..tostring(err))
    end
end)
paint()
warn("[VALUE] Economy engine ready. Separate Coins and Fisherman Coins. Every reward remains server-owned.")
