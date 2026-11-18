-- BOOGA BOOGA REBORN • VOODOO SYNC v6.0
-- Genuine-effect helper for owned equipment and consumables.
-- No fake energy or buffs. Outgoing cast attempts are not server-confirmed bolts.
local places={[11729688377]=true,[11879754496]=true,[124322376658249]=true}
if not places[game.PlaceId] then warn("[Voodoo Sync] Wrong Booga place");return end
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local pl=Players.LocalPlayer
if not pl then return end
local pg=pl:WaitForChild("PlayerGui",10)
if not pg then return end
for _,name in ipairs({"BoogaVoodooSyncV6","BoogaLightningV5","BoogaLightningHoldV4","BoogaLightningLabV3","BoogaLightningLabV20","BoogaLightningLabV2","BoogaLightningLabV1"}) do
 local g=pg:FindFirstChild(name)
 if g then
  local s=g:FindFirstChild("Shutdown")
  if s and s:IsA("BindableEvent") then pcall(function()s:Fire()end)end
  if g.Parent then g:Destroy()end
 end
end
local function module(...)
 local node=RS
 for _,part in ipairs({...})do node=node and node:FindFirstChild(part)end
 if not node or not node:IsA("ModuleScript")then return nil end
 local ok,v=pcall(require,node)
 if ok then return v end
 return nil
end
local packets=module("Modules","util","packets")
local util=module("Modules","util","gameUtil")
local itemData=module("Modules","data","itemData")
local functions=module("Game","functions")
local function data()
 local d=util and util.Data
 return type(d)=="table" and d or nil
end
local function valid(v)
 return type(v)=="number" and v==v and v<math.huge and v>-math.huge
end
local function itemKey(name)
 local d=data()
 if not d or type(d.inventory)~="table"then return nil end
 for k,v in pairs(d.inventory)do
  if type(v)=="table" and v.name==name and (not valid(v.quantity) or v.quantity>0)then return k end
 end
 return nil
end
local function countItem(name)
 local d=data()
 if not d or type(d.inventory)~="table"then return 0 end
 local n=0
 for _,v in pairs(d.inventory)do
  if type(v)=="table" and v.name==name then
   n+=valid(v.quantity) and math.max(0,v.quantity) or 1
  end
 end
 return n
end
local kit={{"Void Shroud","head"},{"Void Chestplate","torso"},{"Void Greaves","legs"},{"Void Bag","bag"}}
local function wearing(name,slot)
 local d=data()
 return d and type(d.armor)=="table" and d.armor[slot]==name or false
end
local function boostVisible(name)
 local main=pg:FindFirstChild("MainGui")
 local panels=main and main:FindFirstChild("Panels")
 local toolbar=panels and panels:FindFirstChild("Toolbar")
 local container=toolbar and toolbar:FindFirstChild("Container")
 local boosts=container and container:FindFirstChild("Boosts")
 return boosts and boosts:FindFirstChild(name)~=nil or false
end
local function send(packet,payload)
 local p=packets and packets[packet]
 if not p or type(p.send)~="function"then return false,"Packet unavailable: "..packet end
 return pcall(function()p.send(payload)end)
end
local function canUse(name)
 if type(functions)=="table" and type(functions.itemLocked)=="function"then
  local ok,locked=pcall(function()return functions.itemLocked("use",name,true)end)
  if not ok then return false,"Game item-lock check failed"end
  if locked then return false,name.." is locked by the game"end
 end
 return true
end
local alive=true
local armed=true
local hold=false
local rateIndex=2
local rates={2,4,6,8}
local attempts,errors=0,0
local gained,spent=0,0
local lastEnergy,dropAt=nil,os.clock()
local samples={}
local lastSample=0
local lastCast=0
local lastDraw=0
local lastSave=0
local busy=false
local lastKitAt=0
local confirmUntil=0
local status="Ready. Hold V for normal Energy Bolt requests."
local kitStatus="Only owned Void gear can be equipped. Existing armour/bag may change."
local jellyStatus="One sandwich will only be used after two clicks."
local cons={}
local col={bg=Color3.fromRGB(14,20,34),card=Color3.fromRGB(35,46,69),purple=Color3.fromRGB(156,132,245),mint=Color3.fromRGB(83,224,174),white=Color3.fromRGB(242,245,255),muted=Color3.fromRGB(164,181,206),amber=Color3.fromRGB(255,207,132)}
local function mk(class,props,parent)
 local o=Instance.new(class)
 for k,v in pairs(props)do o[k]=v end
 o.Parent=parent
 return o
end
local gui=mk("ScreenGui",{Name="BoogaVoodooSyncV6",ResetOnSpawn=false,DisplayOrder=268},pg)
local shutdown=mk("BindableEvent",{Name="Shutdown"},gui)
local panel=mk("Frame",{Size=UDim2.fromOffset(463,431),Position=UDim2.fromOffset(39,93),BackgroundColor3=col.bg,BorderSizePixel=0,Active=true,Draggable=true},gui)
mk("UICorner",{CornerRadius=UDim.new(0,13)},panel)
mk("UIStroke",{Color=col.purple,Thickness=1.3,Transparency=.2},panel)
local scale=mk("UIScale",{Scale=1},panel)
local function resize()
 local cam=workspace.CurrentCamera
 if cam then
  local v=cam.ViewportSize
  scale.Scale=math.clamp(math.min((v.X-15)/475,(v.Y-30)/455),.62,1)
 end
end
resize()
local function label(parent,t,x,y,w,h,sz,color,bold)
 return mk("TextLabel",{Text=t,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,TextColor3=color or col.white,TextSize=sz or 12,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham},parent)
end
local function btn(parent,t,x,y,w,h,fn)
 local b=mk("TextButton",{Text=t,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),TextColor3=col.white,TextSize=12,TextWrapped=true,Font=Enum.Font.GothamBold,BackgroundColor3=col.card,BorderSizePixel=0},parent)
 mk("UICorner",{CornerRadius=UDim.new(0,8)},b)
 b.Activated:Connect(fn)
 return b
end
label(panel,"⚡ VOODOO SYNC  v6",15,8,342,34,19,col.white,true)
label(panel,"Existing Mojo • Owned regen effects • Real energy changes",16,40,425,18,10,col.muted)
local castPane=mk("Frame",{Position=UDim2.fromOffset(13,106),Size=UDim2.fromOffset(437,302),BackgroundTransparency=1},panel)
local regenPane=mk("Frame",{Position=UDim2.fromOffset(13,106),Size=UDim2.fromOffset(437,302),BackgroundTransparency=1,Visible=false},panel)
local castTab,regenTab
local function setTab(t)
 castPane.Visible=t=="CAST"
 regenPane.Visible=t=="REGEN"
 castTab.BackgroundColor3=t=="CAST" and col.purple or col.card
 regenTab.BackgroundColor3=t=="REGEN" and col.purple or col.card
end
castTab=btn(panel,"⚡ LIGHTNING",16,73,210,29,function()setTab("CAST")end)
regenTab=btn(panel,"✦ GENUINE REGEN",234,73,213,29,function()setTab("REGEN")end)
local spell=label(castPane,"",4,1,429,28,13,col.white,true)
local energy=label(castPane,"",4,32,429,26,12,col.mint,true)
local less=btn(castPane,"−",4,84,47,35,function()rateIndex=math.max(1,rateIndex-1)end)
local speed=label(castPane,"",64,84,295,35,12,col.white,true)
local more=btn(castPane,"+",380,84,48,35,function()rateIndex=math.min(#rates,rateIndex+1)end)
local arm=btn(castPane,"",4,130,424,43,function()
 armed=not armed;hold=false
 status=armed and "Armed. Hold V to cast." or "Stopped. Press again to arm."
end)
local castStatus=label(castPane,"",4,178,429,56,12,col.amber)
local stats=label(castPane,"",4,237,429,26,11,col.muted)
label(castPane,"No low-energy wait in the script. Server-accepted strikes still require whatever Voodoo and cooldowns the game enforces.",4,261,427,40,11,col.muted)
local mojo=label(regenPane,"",4,0,430,27,13,col.mint,true)
local worn=label(regenPane,"",4,28,430,48,11,col.white)
local owned=label(regenPane,"",4,77,430,42,11,col.muted)
local equipBtn=btn(regenPane,"EQUIP OWNED VOID REGEN GEAR",4,124,428,38,function()end)
local equipStatus=label(regenPane,"",4,166,429,39,11,col.amber)
local jellyBtn=btn(regenPane,"USE OWNED JELLY SANDWICH • CONFIRM TWICE",4,215,428,37,function()end)
local jellyText=label(regenPane,"",4,253,429,49,11,col.muted)
label(panel,"RIGHT SHIFT: HIDE/SHOW    •    F6: STOP    •    NO AUTOMATIC PURCHASES",18,412,430,15,10,col.muted)
local reopen
reopen=btn(gui,"⚡ SHOW HUB",10,10,133,33,function()panel.Visible=true;reopen.Visible=false end)
reopen.Visible=false
local function equipOwned()
 if busy then kitStatus="Already checking gear.";return end
 if os.clock()-lastKitAt<3 then kitStatus="Check existing result before trying again.";return end
 local d=data()
 if not d or type(d.inventory)~="table"then kitStatus="Inventory not loaded.";return end
 lastKitAt=os.clock();busy=true;kitStatus="Sending native owned-item use requests..."
 task.spawn(function()
  local confirmed,missing,unconfirmed,locked=0,0,0,0
  for _,gear in ipairs(kit)do
   if not alive then break end
   local name,slot=gear[1],gear[2]
   if wearing(name,slot)then confirmed+=1
   else
    local key=itemKey(name)
    if key==nil then missing+=1
    else
     local okLock,reason=canUse(name)
     if not okLock then locked+=1;kitStatus=reason
     else
      local ok,err=send("UseBagItem",key)
      if not ok then unconfirmed+=1;kitStatus=tostring(err):sub(1,80)
      else
       task.wait(1.4)
       if wearing(name,slot)then confirmed+=1 else unconfirmed+=1 end
      end
     end
    end
   end
   task.wait(.15)
  end
  if alive then
   busy=false
   kitStatus=string.format("Equipped %d/4 • Not owned %d • Unconfirmed %d • Locked %d",confirmed,missing,unconfirmed,locked)
  end
 end)
end
equipBtn.Activated:Connect(equipOwned)
local function useSandwich()
 local d=data()
 if not d or type(d.inventory)~="table"then jellyStatus="Inventory not loaded.";return end
 local key=itemKey("Jelly Sandwich")
 if key==nil then jellyStatus="No Jelly Sandwich in inventory.";return end
 if boostVisible("Jelly Sandwich")then
  jellyStatus="Native sandwich boost already visible. Using more may only refresh it."
  confirmUntil=0;return
 end
 if os.clock()>confirmUntil then
  confirmUntil=os.clock()+5
  jellyStatus="Click again within 5 seconds to consume ONE owned sandwich."
  return
 end
 confirmUntil=0
 local can,reason=canUse("Jelly Sandwich")
 if not can then jellyStatus=reason;return end
 local before=countItem("Jelly Sandwich")
 local ok,err=send("UseBagItem",key)
 if not ok then jellyStatus="Item use failed: "..tostring(err):sub(1,65);return end
 jellyStatus="Use sent. Checking native inventory/buff..."
 task.delay(1.8,function()
  if not alive then return end
  if boostVisible("Jelly Sandwich")then jellyStatus="Sandwich boost visible in the native UI."
  elseif countItem("Jelly Sandwich")<before then jellyStatus="Inventory decreased; buff not independently verified."
  else jellyStatus="Use request sent; no confirmed change." end
 end)
end
jellyBtn.Activated:Connect(useSandwich)
local function direction()
 local char=pl.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 local cam=workspace.CurrentCamera
 if not hum or not cam then return Vector3.zero end
 local h=cam.CFrame.LookVector*Vector3.new(1,0,1)
 local m=hum.MoveDirection*Vector3.new(1,0,1)
 local v
 if m.Magnitude>.1 and h.Magnitude>.1 then
  local relative=CFrame.lookAlong(Vector3.zero,h.Unit):VectorToObjectSpace(m.Unit)
  v=cam.CFrame:VectorToWorldSpace(relative)
 elseif m.Magnitude>.1 then v=m.Unit else v=cam.CFrame.LookVector end
 if v.Y<0 then v=v*Vector3.new(1,0,1)end
 return v.Magnitude>=.1 and v.Unit or Vector3.zero
end
local function target()
 if type(functions)=="table" and type(functions.cursorRay)=="function"then
  local ok,v=pcall(function()local _,p=functions.cursorRay();return p end)
  if ok and typeof(v)=="Vector3"then return v end
 end
 local ok,v=pcall(function()return pl:GetMouse().Hit.Position end)
 if ok and typeof(v)=="Vector3"then return v end
 local c=workspace.CurrentCamera
 return c and (c.CFrame.Position+c.CFrame.LookVector*100) or Vector3.zero
end
local function cast()
 local d=data()
 if not d or d.spell~="Energy Bolt"then
  status="Select Energy Bolt first. Current: "..tostring(d and d.spell or "none");return
 end
 local ch=pl.Character
 local hum=ch and ch:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then status="Spawn a living character first.";return end
 local ok,err=send("VoodooSpell",{targetPos=target(),aimDirection=direction()})
 if ok then attempts+=1;status="Request sent; real damaging strike NOT confirmed."
 else errors+=1;status="Cast API error: "..tostring(err):sub(1,92)end
end
local function sample(now,v)
 if not valid(v)then return end
 if valid(lastEnergy)then
  if v>lastEnergy then gained+=v-lastEnergy
  elseif v<lastEnergy then spent+=lastEnergy-v;dropAt=now end
 end
 lastEnergy=v
 if now-lastSample<.5 then return end
 lastSample=now
 samples[#samples+1]={t=now,v=v}
 while #samples>1 and samples[1].t<now-12 do table.remove(samples,1)end
end
local function regenRate(now,v)
 if #samples<2 or not valid(v)then return "Regen: collecting real stat updates..." end
 local f=samples[1];local elapsed=now-f.t
 if elapsed<5 then return "Regen: measuring (idle sample)..." end
 if dropAt>=f.t or v>=99.8 or f.v>=99.8 then
  return "Regen: needs an idle period below full Voodoo"
 end
 local rate=(v-f.v)/elapsed
 if rate<0 then return "Regen: unstable sample" end
 return string.format("Measured idle regen ~%.2f/s (theoretical %.1f bolts/min)",rate,rate*2)
end
local function writeReport()
 if type(writefile)~="function"then return end
 local d=data();local equipped={}
 for _,g in ipairs(kit)do equipped[g[2]]=wearing(g[1],g[2])end
 local report={version=6,place_id=game.PlaceId,selected_spell=d and d.spell or "none",voodoo=d and d.voodoo or -1,
  spellmaster_owned=d and type(d.mojoItems)=="table" and not not d.mojoItems.Spellmaster or false,
  equipped_void=equipped,jelly_owned=countItem("Jelly Sandwich"),jelly_boost_visible=boostVisible("Jelly Sandwich"),
  attempts=attempts,errors=errors,observed_voodoo_gain=gained,observed_voodoo_spend=spent,
  kit_status=kitStatus,jelly_status=jellyStatus,
  note="Client-side view of server-synchronised data; outgoing attempts are not confirmed server damage."}
 pcall(function()writefile("booga_voodoo_sync_v6_report.json",Http:JSONEncode(report))end)
end
local function stop()
 if not alive then return end
 alive=false;armed=false;hold=false
 pcall(writeReport)
 for _,c in ipairs(cons)do pcall(function()c:Disconnect()end)end
 if gui.Parent then gui:Destroy()end
end
shutdown.Event:Connect(stop)
btn(panel,"×",425,11,28,28,stop)
cons[#cons+1]=UIS.InputBegan:Connect(function(i,processed)
 if i.KeyCode==Enum.KeyCode.F6 then armed=false;hold=false;status="Stopped by F6";return end
 if i.KeyCode==Enum.KeyCode.RightShift then panel.Visible=not panel.Visible;reopen.Visible=not panel.Visible;return end
 if i.KeyCode==Enum.KeyCode.V and not processed and not UIS:GetFocusedTextBox()then hold=true;lastCast=0 end
end)
cons[#cons+1]=UIS.InputEnded:Connect(function(i)
 if i.KeyCode==Enum.KeyCode.V then hold=false;pcall(writeReport)end
end)
cons[#cons+1]=Run.Heartbeat:Connect(function()
 if not alive then return end
 local now=os.clock();local d=data();local v=d and d.voodoo
 sample(now,v)
 local down=armed and hold and not UIS:GetFocusedTextBox()
 -- No script-side wait for Voodoo. Server remains authoritative.
 if down and now-lastCast>=1/rates[rateIndex]then lastCast=now;cast()end
 if now-lastDraw>.25 then
  lastDraw=now
  local selected=d and d.spell or "not loaded"
  local cost=type(itemData)=="table" and itemData["Energy Bolt"] and itemData["Energy Bolt"].voodooCost or 30
  spell.Text="SPELL: "..tostring(selected)
  spell.TextColor3=selected=="Energy Bolt" and col.mint or col.amber
  energy.Text="VOODOO: "..(valid(v) and string.format("%.1f",v) or "?").." / 100   •   COST: "..tostring(cost)
  speed.Text="CAST ATTEMPTS: "..rates[rateIndex].."/second"
  arm.Text=armed and (down and "HOLDING V • RELEASE TO STOP" or "ARMED • HOLD V TO CAST") or "STOPPED • CLICK TO ARM"
  arm.BackgroundColor3=armed and col.mint or col.card
  arm.TextColor3=armed and col.bg or col.white
  castStatus.Text=status
  stats.Text=string.format("Attempts %d   •   Errors %d   •   Voodoo gains observed %.1f",attempts,errors,gained)
  local mojoOwned=d and type(d.mojoItems)=="table" and d.mojoItems.Spellmaster
  mojo.Text=mojoOwned and "SPELLMASTER MOJO: OWNED / PASSIVE" or "SPELLMASTER MOJO: "..(d and "NOT DETECTED" or "WAITING FOR DATA")
  local we,own={},{}
  for _,g in ipairs(kit)do
   if wearing(g[1],g[2])then we[#we+1]=g[1]end
   if itemKey(g[1])~=nil then own[#own+1]=g[1]end
  end
  worn.Text="EQUIPPED "..#we.."/4: "..(#we>0 and table.concat(we,", ") or "No Void pieces detected")
  owned.Text="IN INVENTORY "..#own..": "..(#own>0 and table.concat(own,", ") or "No owned Void gear found")
  equipBtn.Text=busy and "EQUIPPING OWNED ITEMS..." or "EQUIP OWNED VOID REGEN GEAR"
  equipStatus.Text=kitStatus
  jellyBtn.Text="USE JELLY SANDWICH  •  OWNED "..countItem("Jelly Sandwich")
  jellyText.Text=jellyStatus.."\n"..regenRate(now,v)
 end
 if now-lastSave>=5 then lastSave=now;pcall(writeReport)end
end)
if not packets then status="Packets module not loaded: casting/equipping unavailable."end
if not util then status="Player data not loaded: join and spawn in Booga."end
warn("[Voodoo Sync v6] Owned-effect optimisation + hold V. No fabricated Voodoo.")
