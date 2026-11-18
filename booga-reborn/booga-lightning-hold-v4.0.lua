-- Booga Booga Reborn | Lightning Hold-V v4.0
-- One control: hold physical V to repeatedly request your selected Energy Bolt.
-- Released V = zero additional requests. Native and direct routes are from archived Game/spells.
-- Server may enforce Voodoo costs / cooldowns. No local stat spoofing, no fake bolt effects.
if game.PlaceId~=11729688377 then warn("[Lightning v4] Wrong game/place."); return end
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local p=Players.LocalPlayer
if not p then return end
local pg=p:WaitForChild("PlayerGui",10)
if not pg then return end
for _,n in ipairs({"BoogaLightningHoldV4","BoogaLightningLabV3","BoogaLightningLabV20","BoogaLightningLabV1"}) do
 local existing=pg:FindFirstChild(n)
 if existing then
  local sh=existing:FindFirstChild("Shutdown")
  if sh and sh:IsA("BindableEvent") then pcall(function()sh:Fire()end)end
  if existing.Parent then existing:Destroy()end
 end
end
local function load(path)
 local node=RS
 for _,name in ipairs(path) do
  node=node and node:FindFirstChild(name)
 end
 if not node or not node:IsA("ModuleScript") then return nil,"missing module: "..table.concat(path,"/") end
 local ok,value=pcall(require,node)
 if ok then return value,nil end
 return nil,tostring(value)
end
local packets,pErr=load({"Modules","util","packets"})
local util,uErr=load({"Modules","util","gameUtil"})
local itemData,dErr=load({"Modules","data","itemData"})
local input,sErr=load({"Game","wrappedSignals"})
local functions,fErr=load({"Game","functions"})
local GUI="BoogaLightningHoldV4"
local alive=true
local armed=true
local physicalHold=false
local method=1
local interval=.20
local nextCast=0
local sent=0
local errors=0
local lowEnergy=0
local observedSpend=0
local lastEnergy=nil
local lastMessage="Ready: hold V to repeat your selected Lightning spell."
local reportStatus="Not saved yet"
local lastWrite=0
local lastDraw=0
local lastError=""
local connections={}
local colors={bg=Color3.fromRGB(14,19,32),card=Color3.fromRGB(29,39,59),purple=Color3.fromRGB(185,151,255),mint=Color3.fromRGB(92,221,180),white=Color3.fromRGB(235,241,255),muted=Color3.fromRGB(166,180,205),amber=Color3.fromRGB(255,209,138)}
local function mk(class,attributes,parent)
 local obj=Instance.new(class)
 for k,v in pairs(attributes) do obj[k]=v end
 obj.Parent=parent
 return obj
end
local g=mk("ScreenGui",{Name=GUI,ResetOnSpawn=false,DisplayOrder=250},pg)
local shutdown=mk("BindableEvent",{Name="Shutdown"},g)
local panel=mk("Frame",{Size=UDim2.fromOffset(377,303),Position=UDim2.fromOffset(32,110),BackgroundColor3=colors.bg,BorderSizePixel=0,Active=true,Draggable=true},g)
mk("UICorner",{CornerRadius=UDim.new(0,14)},panel)
mk("UIStroke",{Color=colors.purple,Transparency=.20,Thickness=1.3},panel)
local function text(value,x,y,w,h,size,color,bold)
 return mk("TextLabel",{Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,TextColor3=color or colors.white,TextSize=size or 12,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=true},panel)
end
local function button(value,x,y,w,h,fn)
 local obj=mk("TextButton",{Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),TextColor3=colors.white,BackgroundColor3=colors.card,TextSize=12,Font=Enum.Font.GothamBold,BorderSizePixel=0},panel)
 mk("UICorner",{CornerRadius=UDim.new(0,8)},obj)
 obj.Activated:Connect(fn)
 return obj
end
text("⚡ LIGHTNING  /  HOLD V",15,10,312,31,18,colors.purple,true)
text("No aim lock • No AFK • Only while V is held",16,42,350,21,10,colors.muted)
local spellLabel=text("",16,73,345,26,12,colors.white,true)
local energyLabel=text("",16,99,345,22,11,colors.muted)
local statusLabel=text("",16,129,345,44,11,colors.amber)
local methodBtn=button("",15,182,344,35,function()
 method=method==1 and 2 or 1
 lastMessage="Switched casting route. Hold V to use it."
end)
local armBtn=button("ARMED • HOLD V",15,225,344,34,function()
 armed=not armed
 physicalHold=false
 lastMessage=armed and "Armed. Hold V to cast." or "Stopped. Click to arm again."
end)
local statsLabel=text("",16,265,345,27,10,colors.muted)
local function getSpell()
 local d=util and util.Data
 if type(d)~="table" then return nil,nil,nil end
 local name=d.spell
 local info=type(itemData)=="table" and name and itemData[name] or nil
 return d,name,info
end
local function spellReady()
 local d,name,info=getSpell()
 if name~="Energy Bolt" or type(info)~="table" or type(info.voodooCost)~="number" then
  return false,d,name,info
 end
 return true,d,name,info
end
local function isAlive()
 local character=p.Character
 local hum=character and character:FindFirstChildOfClass("Humanoid")
 return hum and hum.Health>0
end
local function physicalVDown()
 if not armed or UIS:GetFocusedTextBox() then return false end
 local ok,down=pcall(function()return UIS:IsKeyDown(Enum.KeyCode.V)end)
 if ok and down then return true end
 return physicalHold
end
local function direction()
 local char=p.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 local cam=workspace.CurrentCamera
 if not hum or not cam then return Vector3.zero end
 local horiz=cam.CFrame.LookVector*Vector3.new(1,0,1)
 local move=hum.MoveDirection*Vector3.new(1,0,1)
 local d
 if move.Magnitude>.1 and horiz.Magnitude>.1 then
  d=cam.CFrame:VectorToWorldSpace(CFrame.lookAlong(Vector3.zero,horiz.Unit):VectorToObjectSpace(move.Unit))
 elseif move.Magnitude>.1 then d=move.Unit
 else d=cam.CFrame.LookVector end
 if d.Y<0 then d=d*Vector3.new(1,0,1) end
 return d.Magnitude>=.1 and d.Unit or Vector3.zero
end
local function cursorPos()
 if type(functions)=="table" and type(functions.cursorRay)=="function" then
  local ok,pos=pcall(function()local _,point=functions.cursorRay();return point end)
  if ok and typeof(pos)=="Vector3" then return pos end
 end
 local camera=workspace.CurrentCamera
 if camera then
  local mouse=p:GetMouse()
  local ok,pos=pcall(function()return mouse.Hit.Position end)
  if ok and typeof(pos)=="Vector3" then return pos end
  return camera.CFrame.Position+camera.CFrame.LookVector*100
 end
 return Vector3.zero
end
local function nativeCast()
 local ev=input and input.InputBegan
 if not ev or type(ev.Fire)~="function" then
  return false,"game input signal unavailable"
 end
 return pcall(function()ev:Fire({KeyCode=Enum.KeyCode.V,UserInputType=Enum.UserInputType.Keyboard},false)end)
end
local function directCast()
 local packet=packets and packets.VoodooSpell
 if not packet or type(packet.send)~="function" then
  return false,"VoodooSpell.send unavailable: "..tostring(pErr)
 end
 return pcall(function()packet.send({targetPos=cursorPos(),aimDirection=direction()})end)
end
local function writeReport()
 if type(writefile)~="function" then reportStatus="Executor has no writefile API";return end
 local d,name,info=getSpell()
 local data={
  version=4,place_id=game.PlaceId,selected_spell=tostring(name or "none"),
  cast_route=method==1 and "native_input" or "direct_packet",
  hold_active=physicalVDown(),armed=armed,
  requests_attempted=sent,local_errors=errors,low_energy_waits=lowEnergy,
  last_voodoo=d and d.voodoo or -1,voodoo_spend_observed=observedSpend,
  last_error=lastError:sub(1,120),
  summary="Outgoing attempt counters and local Voodoo changes do not establish server acceptance."
 }
 local ok,err=pcall(function()writefile("booga_lightning_v4_report.json",Http:JSONEncode(data))end)
 reportStatus=ok and "Local results saved" or ("Could not save: "..tostring(err):sub(1,40))
end
local function shutdownHub()
 if not alive then return end
 alive=false
 armed=false
 physicalHold=false
 pcall(writeReport)
 for _,c in ipairs(connections)do pcall(function()c:Disconnect()end)end
 if g.Parent then g:Destroy()end
end
shutdown.Event:Connect(shutdownHub)
button("×",331,10,28,29,shutdownHub)
connections[#connections+1]=UIS.InputBegan:Connect(function(i,processed)
 if i.KeyCode==Enum.KeyCode.F6 then
  armed=false;physicalHold=false;lastMessage="F6 stopped casting. Re-arm via the button."
 elseif i.KeyCode==Enum.KeyCode.V and not processed and not UIS:GetFocusedTextBox() then
  physicalHold=true;nextCast=0
 end
end)
connections[#connections+1]=UIS.InputEnded:Connect(function(i)
 if i.KeyCode==Enum.KeyCode.V then
  physicalHold=false
  pcall(writeReport)
 end
end)
connections[#connections+1]=Run.Heartbeat:Connect(function()
 if not alive then return end
 local now=os.clock()
 local d,name,info=getSpell()
 local v=d and d.voodoo
 if type(v)=="number" and type(lastEnergy)=="number" and v<lastEnergy then
  observedSpend+=lastEnergy-v
 end
 if type(v)=="number" then lastEnergy=v end
 if physicalVDown() and now>=nextCast then
  nextCast=now+interval
  local valid,d2,n,info2=spellReady()
  if not valid then
   lastMessage="Select Energy Bolt first (game reports: "..tostring(n)..")."
  elseif not isAlive() then
   lastMessage="Character must be alive."
  elseif type(d2.voodoo)=="number" and d2.voodoo<info2.voodooCost then
   lowEnergy+=1
   lastMessage="Waiting for real Voodoo regeneration ("..math.floor(d2.voodoo).."/"..info2.voodooCost..")."
  else
   local ok,err
   if method==1 then ok,err=nativeCast() else ok,err=directCast() end
   if ok then
    sent+=1
    lastMessage="Cast attempted through "..(method==1 and "native V handler" or "spell packet").."."
   else
    errors+=1
    lastError=tostring(err)
    lastMessage="Route error: "..lastError:sub(1,93)
    if method==1 then method=2;lastMessage="Native route failed. Switched to direct packets." end
   end
  end
 end
 if now-lastDraw>.20 then
  lastDraw=now
  spellLabel.Text="SELECTED: "..tostring(name or "not loaded")
  spellLabel.TextColor3=name=="Energy Bolt" and colors.mint or colors.amber
  energyLabel.Text="VOODOO: "..(type(v)=="number" and string.format("%.1f / 100",v) or "?").."   |   COST: "..tostring(info and info.voodooCost or "?")
  statusLabel.Text=(physicalVDown() and "HOLDING V • " or "READY • ")..lastMessage
  methodBtn.Text="CAST ROUTE: "..(method==1 and "GAME V HANDLER" or "DIRECT PACKET").."  •  CHANGE"
  armBtn.Text=armed and (physicalVDown() and "CASTING • RELEASE V TO STOP" or "ARMED • HOLD V") or "STOPPED • CLICK TO ARM"
  armBtn.BackgroundColor3=armed and colors.mint or colors.card
  armBtn.TextColor3=armed and colors.bg or colors.white
  statsLabel.Text=string.format("Attempts %d  •  Errors %d  •  Voodoo spent %.0f  •  %s",sent,errors,observedSpend,reportStatus)
 end
 if now-lastWrite>=5 then lastWrite=now;pcall(writeReport)end
end)
if not packets then lastMessage="Packet module unavailable: "..tostring(pErr) end
if not util then lastMessage="Player data unavailable: "..tostring(uErr) end
if not itemData then lastMessage="Item data unavailable: "..tostring(dErr) end
pcall(writeReport)
warn("[Lightning v4] Hold V to cast; release stops. Routes are native V handler / typed packet. Server controls real bolt approval.")
