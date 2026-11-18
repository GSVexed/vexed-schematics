-- BOOGA LIGHTNING SUSTAIN v5.0
-- Archived game modules: Game/spells, Game/wrappedSignals, Game/inventory,
-- Game/armor, Game/stats; Modules/util/packets and gameUtil.
-- Hold V = repeated Lightning requests. Release V = stop. NO auto-aim.
-- Genuine regeneration assists use your OWN inventory only; no fake stats.
if game.PlaceId~=11729688377 then warn("[Lightning Sustain v5] Wrong game.");return end
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local me=Players.LocalPlayer
if not me then return end
local pg=me:WaitForChild("PlayerGui",10)
if not pg then return end
for _,name in ipairs({"BoogaLightningSustainV5","BoogaLightningHoldV4","BoogaLightningLabV3","BoogaLightningLabV20","BoogaLightningLabV1"}) do
 local old=pg:FindFirstChild(name)
 if old then
  local shutdown=old:FindFirstChild("Shutdown")
  if shutdown and shutdown:IsA("BindableEvent") then pcall(function()shutdown:Fire()end)end
  if old.Parent then old:Destroy()end
 end
end

local function getMod(path)
 local node=RS
 for _,part in ipairs(path) do node=node and (node:FindFirstChild(part) or node:WaitForChild(part,6)) end
 if not node or not node:IsA("ModuleScript") then return nil end
 local ok,mod=pcall(require,node)
 return ok and mod or nil
end
local packets=getMod({"Modules","util","packets"})
local gameUtil=getMod({"Modules","util","gameUtil"})
local itemData=getMod({"Modules","data","itemData"})
local gameSignals=getMod({"Game","wrappedSignals"})
local gameFunctions=getMod({"Game","functions"})
if type(gameUtil)~="table" or type(packets)~="table" then
 warn("[Lightning Sustain v5] Game packet/data modules are not ready.");return
end

local active=true
local enabled=true
local vHeld=false
local method="native"
local castRate=5
local nextCast=0
local directSent=0
local nativeSent=0
local sendErrors=0
local attempts=0
local spent=0
local gained=0
local lastVoodoo=nil
local previousSampleTime=0
local observedRegen=0
local lastStatus="Ready. Hold V to repeatedly cast your selected Energy Bolt."
local lastError=""
local buttonCooldown=0
local actionCount=0
local fileStatus="not saved"
local lastSaved=0
local lastDraw=0
local listeners={}
local filename="booga_lightning_v5_report.json"
local COLORS={bg=Color3.fromRGB(13,18,30),panel=Color3.fromRGB(28,37,54),card=Color3.fromRGB(35,47,69),white=Color3.fromRGB(238,240,255),dim=Color3.fromRGB(171,183,207),purple=Color3.fromRGB(181,150,255),green=Color3.fromRGB(107,224,184),gold=Color3.fromRGB(248,211,142),red=Color3.fromRGB(251,137,160)}
local function inst(class,props,parent)
 local obj=Instance.new(class)
 for k,v in pairs(props) do obj[k]=v end
 obj.Parent=parent
 return obj
end
local gui=inst("ScreenGui",{Name="BoogaLightningSustainV5",ResetOnSpawn=false,DisplayOrder=260},pg)
local shutdown=inst("BindableEvent",{Name="Shutdown"},gui)
local panel=inst("Frame",{Name="Main",Position=UDim2.fromOffset(28,99),Size=UDim2.fromOffset(428,402),BackgroundColor3=COLORS.bg,BorderSizePixel=0,Active=true,Draggable=true},gui)
inst("UICorner",{CornerRadius=UDim.new(0,14)},panel)
inst("UIStroke",{Color=COLORS.purple,Transparency=.18,Thickness=1.35},panel)
local function label(value,x,y,w,h,size,color,bold)
 return inst("TextLabel",{Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),TextColor3=color or COLORS.white,BackgroundTransparency=1,TextSize=size or 12,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center},panel)
end
local function button(value,x,y,w,h,cb)
 local b=inst("TextButton",{Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),TextColor3=COLORS.white,TextSize=12,Font=Enum.Font.GothamBold,BackgroundColor3=COLORS.card,BorderSizePixel=0},panel)
 inst("UICorner",{CornerRadius=UDim.new(0,9)},b)
 b.Activated:Connect(cb)
 return b
end
label("⚡ LIGHTNING SUSTAIN",17,8,350,33,20,COLORS.purple,true)
label("HOLD V TO CAST   •   RELEASE V TO STOP   •   NO AUTO AIM",18,40,392,23,10,COLORS.dim)
local spellLabel=label("SPELL: --",19,68,392,25,12,COLORS.white,true)
local energyLabel=label("VOODOO: --",19,95,390,28,13,COLORS.green,true)
local regenLabel=label("SERVER-SYNCED REGEN: measuring...",19,124,392,27,11,COLORS.dim)
local equipLabel=label("EQUIPPED VOID: --",19,149,394,33,11,COLORS.dim)
local mojoLabel=label("SPELLMASTER: --   |   VOID BAG: --",19,179,394,26,11,COLORS.dim)
local routeBtn=button("CAST METHOD: GAME V HANDLER",17,217,392,35,function()
 method=method=="native" and "direct" or "native"
 lastStatus="Casting method changed. Hold V to use it."
end)
local equipBtn=button("EQUIP OWNED VOID ARMOUR",17,258,191,36,function()end)
local sandwichBtn=button("USE 1 OWNED JELLY SANDWICH",216,258,193,36,function()end)
local armBtn=button("ARMED • HOLD V",17,301,392,34,function()
 enabled=not enabled
 vHeld=false
 lastStatus=enabled and "Armed. Hold V to cast." or "Stopped. Click to arm again."
end)
local statusLabel=label("",18,341,391,38,11,COLORS.gold)
local tallyLabel=label("",18,381,391,18,10,COLORS.dim)
local function data()
 return type(gameUtil.Data)=="table" and gameUtil.Data or nil
end
local function spell()
 local d=data()
 local n=d and d.spell
 local info=n and type(itemData)=="table" and itemData[n]
 return d,n,info
end
local function currentV()
 local d=data()
 return d and type(d.voodoo)=="number" and d.voodoo or nil
end
local function owned(name)
 local d=data()
 if not d or type(d.inventory)~="table" then return nil end
 for index,entry in pairs(d.inventory) do
  if type(entry)=="table" and entry.name==name then
   return index
  end
 end
 return nil
end
local voidNames={"Void Shroud","Void Chestplate","Void Greaves"}
local function armorCount()
 local d=data()
 local list={}
 if d and type(d.armor)=="table" then
  for _,item in pairs(d.armor) do
   if table.find(voidNames,item) then table.insert(list,item) end
  end
 end
 return list
end
local function haveMojo(name)
 local d=data()
 local v=d and type(d.mojoItems)=="table" and d.mojoItems[name]
 return type(v)=="number" and v>0 or v==true
end
local function canRequest()
 return active and enabled and not UIS:GetFocusedTextBox()
end
local function held()
 if not canRequest() then return false end
 local ok,down=pcall(function()return UIS:IsKeyDown(Enum.KeyCode.V)end)
 if ok then return down or vHeld end
 return vHeld
end
local function aimDirection()
 local camera=workspace.CurrentCamera
 local char=me.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not hum or not camera then return Vector3.zero end
 local horizontal=camera.CFrame.LookVector*Vector3.new(1,0,1)
 local moving=hum.MoveDirection*Vector3.new(1,0,1)
 local dir
 if moving.Magnitude>.1 and horizontal.Magnitude>.1 then
  dir=camera.CFrame:VectorToWorldSpace(CFrame.lookAlong(Vector3.zero,horizontal.Unit):VectorToObjectSpace(moving.Unit))
 elseif moving.Magnitude>.1 then dir=moving.Unit
 else dir=camera.CFrame.LookVector end
 if dir.Y<0 then dir=dir*Vector3.new(1,0,1)end
 return dir.Magnitude>.1 and dir.Unit or Vector3.zero
end
local function cursorTarget()
 if type(gameFunctions)=="table" and type(gameFunctions.cursorRay)=="function" then
  local ok,point=pcall(function()local _,p=gameFunctions.cursorRay();return p end)
  if ok and typeof(point)=="Vector3" then return point end
 end
 local ok,pos=pcall(function()return me:GetMouse().Hit.Position end)
 if ok and typeof(pos)=="Vector3" then return pos end
 local camera=workspace.CurrentCamera
 return camera and camera.CFrame.Position+camera.CFrame.LookVector*100 or Vector3.zero
end
local function cast()
 local d,n,info=spell()
 if n~="Energy Bolt" or type(info)~="table" or not info.voodooSpell then
  lastStatus="Selected spell is not Energy Bolt. Choose Lightning in game."
  return
 end
 local char=me.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then
  lastStatus="Character is unavailable."
  return
 end
 local ok,err
 if method=="native" then
  local sig=gameSignals and gameSignals.InputBegan
  if not sig or type(sig.Fire)~="function" then
   method="direct"
   lastStatus="Native game signal unavailable, switched to direct casting."
   return
  end
  ok,err=pcall(function()
   sig:Fire({KeyCode=Enum.KeyCode.V,UserInputType=Enum.UserInputType.Keyboard},false)
  end)
  if ok then nativeSent+=1 end
 else
  local pkt=packets.VoodooSpell
  if not pkt or type(pkt.send)~="function" then
   lastStatus="Game's VoodooSpell packet is unavailable."
   return
  end
  ok,err=pcall(function()pkt.send({targetPos=cursorTarget(),aimDirection=aimDirection()})end)
  if ok then directSent+=1 end
 end
 attempts+=1
 if ok then
  lastStatus="Cast request sent via "..(method=="native" and "game input" or "direct packet").."; server acceptance not yet confirmed."
 else
  sendErrors+=1
  lastError=tostring(err):sub(1,110)
  lastStatus="Cast error: "..lastError
  if method=="native" then method="direct" end
 end
end
local function equipmentAction()
 local now=os.clock()
 if now<buttonCooldown then lastStatus="Equipment action cooling down.";return end
 if not packets.UseBagItem or type(packets.UseBagItem.send)~="function" then
  lastStatus="UseBagItem packet unavailable.";return
 end
 buttonCooldown=now+8
 local equipped=armorCount()
 local num=0
 for _,item in ipairs(voidNames) do
  if not table.find(equipped,item) then
   local slot=owned(item)
   if slot~=nil then
    local ok,err=pcall(function()packets.UseBagItem.send(slot)end)
    if ok then num+=1;actionCount+=1
    else lastError=tostring(err):sub(1,95)end
   end
  end
 end
 if num==0 then lastStatus="No owned, unequipped Void armour pieces found. No item used."
 else lastStatus="Requested equip for "..num.." owned Void piece(s); check armour state." end
end
local function sandwichAction()
 local now=os.clock()
 if now<buttonCooldown then lastStatus="Item action cooling down.";return end
 local slot=owned("Jelly Sandwich")
 if slot==nil then lastStatus="No Jelly Sandwich in current inventory; none consumed.";return end
 if not packets.UseBagItem or type(packets.UseBagItem.send)~="function" then
  lastStatus="UseBagItem packet unavailable.";return
 end
 buttonCooldown=now+3
 local ok,err=pcall(function()packets.UseBagItem.send(slot)end)
 if ok then actionCount+=1;lastStatus="Requested use of one Jelly Sandwich; server determines effect."
 else sendErrors+=1;lastError=tostring(err):sub(1,95);lastStatus="Item-use error: "..lastError end
end
-- Buttons above are initially placeholders; attach direct action callbacks here.
equipBtn.Activated:Connect(equipmentAction)
sandwichBtn.Activated:Connect(sandwichAction)
local function writeReport()
 if type(writefile)~="function" then fileStatus="No writefile API";return end
 local d,n,info=spell()
 local report={
  version=5,place_id=game.PlaceId,spell=tostring(n or "none"),cast_method=method,
  armed=enabled,holding_v=held(),attempts=attempts,native_cast_requests=nativeSent,
  direct_cast_requests=directSent,local_errors=sendErrors,
  voodoo=type(d and d.voodoo)=="number" and d.voodoo or -1,
  observed_voodoo_spend=spent,observed_voodoo_gain=gained,
  observed_positive_regen_per_second=observedRegen,
  void_armour_equipped=#armorCount(),spellmaster_owned=haveMojo("Spellmaster"),
  void_bag_owned=haveMojo("Void Bag"),owned_jelly_sandwich_available=owned("Jelly Sandwich")~=nil,
  genuine_item_actions=actionCount,last_error=lastError,
  note="Server acceptance and specific regeneration causality not proven by client-side request counters."
 }
 local ok,err=pcall(function()writefile(filename,Http:JSONEncode(report))end)
 fileStatus=ok and "Saved local report" or ("Report failed: "..tostring(err):sub(1,32))
end
local function close()
 if not active then return end
 active=false;enabled=false;vHeld=false
 pcall(writeReport)
 for _,c in ipairs(listeners)do pcall(function()c:Disconnect()end)end
 if gui.Parent then gui:Destroy()end
end
shutdown.Event:Connect(close)
button("×",382,12,30,30,close)
listeners[#listeners+1]=UIS.InputBegan:Connect(function(input,processed)
 if input.KeyCode==Enum.KeyCode.F6 then
  enabled=false;vHeld=false;lastStatus="F6 stopped the hub. Click ARM to resume."
 elseif input.KeyCode==Enum.KeyCode.V and not processed and not UIS:GetFocusedTextBox() then
  vHeld=true;nextCast=0
 end
end)
listeners[#listeners+1]=UIS.InputEnded:Connect(function(input)
 if input.KeyCode==Enum.KeyCode.V then vHeld=false;pcall(writeReport)end
end)
listeners[#listeners+1]=Run.Heartbeat:Connect(function()
 if not active then return end
 local now=os.clock()
 local energy=currentV()
 if type(energy)=="number" and previousSampleTime>0 and now-previousSampleTime>=.35 then
  local diff=lastVoodoo and energy-lastVoodoo or 0
  local dt=now-previousSampleTime
  if diff>0 then gained+=diff;observedRegen=observedRegen*.8+(diff/dt)*.2 end
  if diff<0 then spent-=diff end
  lastVoodoo=energy;previousSampleTime=now
 elseif previousSampleTime==0 then
  previousSampleTime=now;lastVoodoo=energy
 end
 if held() and now>=nextCast then
  nextCast=now+1/castRate
  cast()
 end
 if now-lastDraw>=.25 then
  lastDraw=now
  local d,n,info=spell()
  spellLabel.Text="SELECTED SPELL: "..tostring(n or "not loaded")
  spellLabel.TextColor3=n=="Energy Bolt" and COLORS.green or COLORS.gold
  energyLabel.Text="VOODOO: "..(energy and string.format("%.1f / 100",energy) or "?")..
    "    •    BOLT COST: "..tostring(info and info.voodooCost or "?")
  regenLabel.Text=string.format("Observed positive Voodoo gain: ~%.2f/s   |   no script energy gate",observedRegen)
  local equipped=armorCount()
  equipLabel.Text="VOID ARMOUR: "..tostring(#equipped).."/3 equipped  •  "..(#equipped>0 and table.concat(equipped,", ") or "none")
  mojoLabel.Text="SPELLMASTER: "..(haveMojo("Spellmaster") and "OWNED" or "NO")..
    "   |   VOID BAG: "..(haveMojo("Void Bag") and "OWNED" or "NO")
  routeBtn.Text="CAST METHOD: "..(method=="native" and "GAME V HANDLER" or "DIRECT SPELL PACKET").."   •   SWITCH"
  armBtn.Text=enabled and (held() and "CASTING • RELEASE V TO STOP" or "ARMED • HOLD V") or "STOPPED • CLICK TO ARM"
  armBtn.BackgroundColor3=enabled and COLORS.green or COLORS.card
  armBtn.TextColor3=enabled and COLORS.bg or COLORS.white
  statusLabel.Text=lastStatus
  tallyLabel.Text="Attempts: "..attempts.." | Errors: "..sendErrors.." | Regen actions: "..actionCount.." | "..fileStatus
 end
 if now-lastSaved>5 then lastSaved=now;pcall(writeReport)end
end)
pcall(writeReport)
warn("[Lightning Sustain v5] Hold V only. Optional owned Void gear/Jelly uses. Server enforces spell energy and cooldowns.")
