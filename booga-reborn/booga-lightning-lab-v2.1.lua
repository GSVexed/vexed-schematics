-- Booga Booga Reborn | LIGHTNING LAB 2.1
-- Selected Energy Bolt required. EVERY mode only casts while the V key is held.
-- Experimental outgoing requests are not proof of accepted spells or damage.
-- Maximum 24 outbound attempts per second; F6 emergency stop.
if game.PlaceId~=11729688377 then warn("[Lightning Lab] Wrong Roblox place.");return end
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local plr=Players.LocalPlayer
if not plr then return end
local pg=plr:WaitForChild("PlayerGui",10)
if not pg then return end
local prior=pg:FindFirstChild("BoogaLightningLabV21")
if prior then
 local off=prior:FindFirstChild("Shutdown")
 if off and off:IsA("BindableEvent") then pcall(function()off:Fire()end) end
 prior:Destroy()
end
-- Close v2.0 and v1.0 so only this hub can send requests.
local oldV20=pg:FindFirstChild("BoogaLightningLabV20")
if oldV20 then
 local off=oldV20:FindFirstChild("Shutdown")
 if off and off:IsA("BindableEvent") then pcall(function()off:Fire()end) end
 if oldV20.Parent then oldV20:Destroy() end
end
-- Also close earlier hub version so two casters never run together.
local earlier=pg:FindFirstChild("BoogaLightningLabV1")
if earlier then
 local off=earlier:FindFirstChild("Shutdown")
 if off and off:IsA("BindableEvent") then pcall(function()off:Fire()end) end
 earlier:Destroy()
end
local ok,packets,gameUtil,itemData=pcall(function()
 local mods=RS:WaitForChild("Modules",9)
 local util=mods:WaitForChild("util",5)
 return require(util.packets),require(util.gameUtil),require(mods.data.itemData)
end)
if not ok or type(packets)~="table" or type(packets.VoodooSpell)~="table"
 or type(packets.VoodooSpell.send)~="function"
 or type(gameUtil)~="table" or type(itemData)~="table" then
 warn("[Lightning Lab] Game's native spell modules unavailable. Join fully and retry.")
 return
end

local wrappedSignals
local function loadGameSignal()
 local g=RS:FindFirstChild("Game")
 local module=g and g:FindFirstChild("wrappedSignals")
 if not module then return nil end
 local success,result=pcall(require,module)
 return success and result or nil
end
wrappedSignals=loadGameSignal()
local gameFunctions
pcall(function()gameFunctions=require(RS.Game.functions)end)
local cfg={mode="direct",double=false,triple=false,dave=true,sweep=false,
 toward=false,guard=false,smart=false,jitter=false,rate=6}
local RATE={2,4,6,8,12}
local live=true
local armed=true
local held=false
local queue=0
local sent=0
local errors=0
local attempts=0
local nativeCalls=0
local lastAttempt=-1e6
local nextPulse=0
local nextQueued=0
local castFlip=0
local lastDraw=0
local previousV=nil
local previousVAt=0
local regen=0
local lastDaveHP=nil
local hpWindow={}
local lastMessage="Ready. Lightning already selected; hold V to cast."
local connections={}
local packetWrappers={}
local incomingStats=0
local incomingProjectiles=0
local observedServerVoodoo=nil
local lastLogAt=0
local logStatus="No local log yet"
local LOG_FILE="booga_lightning_v21_latest.json"
local COL={bg=Color3.fromRGB(12,16,29),card=Color3.fromRGB(24,32,51),
 panel=Color3.fromRGB(32,43,64),border=Color3.fromRGB(68,84,111),
 purple=Color3.fromRGB(183,144,255),mint=Color3.fromRGB(95,224,184),
 white=Color3.fromRGB(236,240,255),dim=Color3.fromRGB(169,182,208),
 gold=Color3.fromRGB(255,205,124),bad=Color3.fromRGB(253,129,148)}
local function mk(class,props,parent)
 local o=Instance.new(class)
 for k,v in pairs(props or {}) do o[k]=v end
 if parent then o.Parent=parent end
 return o
end
local function round(o,r)mk("UICorner",{CornerRadius=UDim.new(0,r or 8)},o);return o end
local function txt(parent,text,x,y,w,h,size,color,bold)
 return mk("TextLabel",{Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
  BackgroundTransparency=1,TextColor3=color or COL.white,TextSize=size or 12,
  Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
  TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
  TextWrapped=true},parent)
end
local screen=mk("ScreenGui",{Name="BoogaLightningLabV21",DisplayOrder=220,
 ResetOnSpawn=false,IgnoreGuiInset=true},pg)
local shutdown=mk("BindableEvent",{Name="Shutdown"},screen)
local panel=round(mk("Frame",{Name="Main",Active=true,Draggable=true,
 Size=UDim2.fromOffset(464,596),Position=UDim2.new(.5,-232,.5,-298),
 BackgroundColor3=COL.bg,BorderSizePixel=0},screen),16)
mk("UIStroke",{Color=COL.purple,Transparency=.30,Thickness=1.3},panel)
round(mk("Frame",{Size=UDim2.fromOffset(440,66),Position=UDim2.fromOffset(12,12),
 BorderSizePixel=0,BackgroundColor3=COL.card},panel),11)
txt(panel,"⚡  LIGHTNING LAB",24,17,338,27,21,COL.purple,true)
txt(panel,"ENERGY BOLT  /  HOLD V  /  RELEASE TO STOP",24,47,406,21,10,COL.dim)
local close=round(mk("TextButton",{Text="×",Position=UDim2.fromOffset(414,19),
 Size=UDim2.fromOffset(30,30),BackgroundColor3=COL.panel,TextColor3=COL.white,
 TextSize=22,BorderSizePixel=0},panel),8)
local spellLabel=txt(panel,"SPELL: detecting…",17,86,430,24,12,COL.white,true)
local energyLabel=txt(panel,"VOODOO: --",17,110,430,19,11,COL.dim)
local boostLabel=txt(panel,"REGEN BUFFS: --",17,131,430,30,10,COL.gold)
local scroll=mk("ScrollingFrame",{Position=UDim2.fromOffset(12,167),
 Size=UDim2.fromOffset(440,285),CanvasSize=UDim2.fromOffset(0,788),
 AutomaticCanvasSize=Enum.AutomaticSize.None,ScrollBarThickness=4,
 ScrollBarImageColor3=COL.purple,BackgroundTransparency=1,BorderSizePixel=0},panel)
local rows={}
local function addToggle(y,name,desc,read,write)
 local slot=round(mk("Frame",{Position=UDim2.fromOffset(2,y),
  Size=UDim2.fromOffset(424,55),BorderSizePixel=0,BackgroundColor3=COL.card},scroll),10)
 txt(slot,name,12,3,310,24,12,COL.white,true)
 txt(slot,desc,12,27,315,19,10,COL.dim)
 local b=round(mk("TextButton",{Position=UDim2.fromOffset(345,12),
  Size=UDim2.fromOffset(66,31),BorderSizePixel=0,TextSize=11,
  Font=Enum.Font.GothamBold,TextColor3=COL.white},slot),8)
 local function update()
  local on=read()
  b.Text=on and "ON" or "OFF"
  b.BackgroundColor3=on and COL.mint or COL.panel
  b.TextColor3=on and COL.bg or COL.dim
 end
 b.Activated:Connect(function()write(not read());update()end)
 rows[#rows+1]=update
 update()
end
addToggle(0,"DIRECT SPELL PACKETS","Native typed VoodooSpell.send payloads",
 function()return cfg.mode=="direct" end,
 function(on)if on then cfg.mode="direct" else cfg.mode="native" end end)
addToggle(61,"REPLAY GAME UI HANDLER","Invokes actual spell-button callback when available",
 function()return cfg.mode=="native" end,
 function(on)if on then cfg.mode="native" else cfg.mode="direct" end end)
addToggle(122,"ALTERNATE BOTH METHODS","Alternates direct + game UI callback",
 function()return cfg.mode=="hybrid" end,
 function(on)if on then cfg.mode="hybrid" else cfg.mode="direct" end end)
addToggle(183,"DOUBLE PULSE","2 successive cast attempts per trigger",
 function()return cfg.double end,
 function(on)cfg.double=on;if on then cfg.triple=false end end)
addToggle(244,"TRIPLE PULSE","3 successive cast attempts per trigger",
 function()return cfg.triple end,
 function(on)cfg.triple=on;if on then cfg.double=false end end)
addToggle(305,"AIM LOCK: DAVE","Targets nearest loaded Dave stump",
 function()return cfg.dave end,
 function(on)cfg.dave=on end)
addToggle(366,"AOE OFFSET SWEEP","Alternate strike positions near Dave",
 function()return cfg.sweep end,
 function(on)cfg.sweep=on end)
addToggle(427,"AIM DIRECTION: TARGET","Point trajectory toward aim point instead of camera",
 function()return cfg.toward end,
 function(on)cfg.toward=on end)
addToggle(488,"VOODOO ENERGY GUARD","Wait if local Voodoo is below the spell cost",
 function()return cfg.guard end,
 function(on)cfg.guard=on end)
addToggle(549,"REGEN SMART PACE","Reduce requests while Voodoo is low; speed up when full",
 function()return cfg.smart end,
 function(on)cfg.smart=on end)
addToggle(610,"TIMING VARIATION","Jitter intervals slightly; no guaranteed bypass",
 function()return cfg.jitter end,
 function(on)cfg.jitter=on end)
addToggle(671,"SUSTAINED BURST REQUEUE","Queue extra attempts while V remains held",
 function()return cfg.double or cfg.triple end,
 function(on)if not on then cfg.double=false;cfg.triple=false else cfg.double=true end end)

local minus=round(mk("TextButton",{Position=UDim2.fromOffset(17,461),
 Size=UDim2.fromOffset(49,32),Text="−",TextSize=20,TextColor3=COL.white,
 BackgroundColor3=COL.panel,BorderSizePixel=0},panel),9)
local rateLabel=txt(panel,"6 pulses/s",72,464,133,27,13,COL.purple,true)
local plus=round(mk("TextButton",{Position=UDim2.fromOffset(212,461),
 Size=UDim2.fromOffset(49,32),Text="+",TextSize=20,TextColor3=COL.white,
 BackgroundColor3=COL.panel,BorderSizePixel=0},panel),9)
local arm=round(mk("TextButton",{Position=UDim2.fromOffset(273,461),
 Size=UDim2.fromOffset(178,32),Text="READY • HOLD V",
 Font=Enum.Font.GothamBold,TextSize=12,TextColor3=COL.bg,
 BackgroundColor3=COL.mint,BorderSizePixel=0},panel),9)
local status=txt(panel,"STATUS: ready",18,502,428,26,11,COL.gold)
local stats=txt(panel,"Requests: 0   •   Dave: --   •   F6 OFF",18,529,428,23,10,COL.dim)
local telemetryLabel=txt(panel,"DIAGNOSTICS: checking file support...",18,554,428,26,10,COL.dim)
local function refresh()
 for _,fn in ipairs(rows) do fn() end
 rateLabel.Text=tostring(cfg.rate).." pulses/s"
 arm.Text=armed and (held and "V HELD • CASTING" or "READY • HOLD V") or "OFF • CLICK TO ARM"
 arm.BackgroundColor3=armed and COL.mint or COL.panel
 arm.TextColor3=armed and COL.bg or COL.white
end
minus.Activated:Connect(function()
 local idx=table.find(RATE,cfg.rate) or 3
 cfg.rate=RATE[math.max(1,idx-1)]
 refresh()
end)
plus.Activated:Connect(function()
 local idx=table.find(RATE,cfg.rate) or 3
 cfg.rate=RATE[math.min(#RATE,idx+1)]
 refresh()
end)
arm.Activated:Connect(function()
 armed=not armed
 if not armed then held=false;queue=0 end
 lastMessage=armed and "Armed. Hold V to cast." or "Disarmed: no casts will be sent."
 refresh()
end)
local function getData()
 local d=gameUtil.Data
 return type(d)=="table" and d or nil
end
local function spellInfo()
 local d=getData()
 local name=d and d.spell
 local info=type(name)=="string" and itemData[name] or nil
 return d,name,info
end
local function boltSelected(name,info)
 return type(info)=="table" and info.voodooSpell==true and name=="Energy Bolt"
end
local function dave()
 local resources=workspace:FindFirstChild("Resources")
 local char=plr.Character
 local root=char and char:FindFirstChild("HumanoidRootPart")
 if not resources or not root then return nil,nil,nil end
 local chosen,part,best=nil,nil,math.huge
 for _,m in ipairs(resources:GetChildren()) do
  if m:IsA("Model") and m.Name=="Dave" then
   local h=m:FindFirstChild("Health")
   local p=m.PrimaryPart or m:FindFirstChild("Stump") or m:FindFirstChildWhichIsA("BasePart")
   if p and h and h:IsA("ValueBase") and type(h.Value)=="number" and h.Value>0 then
    local dist=(root.Position-p.Position).Magnitude
    if dist<best then chosen=m;part=p;best=dist end
   end
  end
 end
 return chosen,part,best
end
local function cursor()
 if gameFunctions and type(gameFunctions.cursorRay)=="function" then
  local good,result=pcall(function()local ray,p=gameFunctions.cursorRay();return p end)
  if good and typeof(result)=="Vector3" then return result end
 end
 local ok,result=pcall(function()return plr:GetMouse().Hit.Position end)
 if ok and typeof(result)=="Vector3" then return result end
 local camera=workspace.CurrentCamera
 return camera and camera.CFrame.Position+camera.CFrame.LookVector*120 or Vector3.zero
end
local function targetPos()
 if cfg.dave then
  local _,part,dist=dave()
  if part and dist and dist<700 then
   local base=part.Position
   if cfg.sweep then
    local ix=attempts%5
    local off=({Vector3.zero,Vector3.new(2,0,0),Vector3.new(-2,0,0),
     Vector3.new(0,0,2),Vector3.new(0,0,-2)})[ix+1]
    return base+off
   end
   return base
  end
 end
 return cursor()
end
local function direction(pos)
 local char=plr.Character
 local root=char and char:FindFirstChild("HumanoidRootPart")
 local cam=workspace.CurrentCamera
 if cfg.toward and root then
  local diff=pos-root.Position
  if diff.Magnitude>.1 then return diff.Unit end
 end
 if cam then
  local look=cam.CFrame.LookVector
  if look.Y<0 then look=Vector3.new(look.X,0,look.Z) end
  if look.Magnitude>.1 then return look.Unit end
 end
 return root and root.CFrame.LookVector or Vector3.new(0,0,-1)
end
local function nativeCast()
 -- Replay the exact internal signal used by Game/spells on a real V press.
 -- This invokes the game's own V callback; no executor-specific firesignal needed.
 local signal=wrappedSignals and wrappedSignals.InputBegan
 if not signal or type(signal.Fire)~="function" then
  return false,"Game wrapped V-key signal unavailable"
 end
 local ok,err=pcall(function()
  signal:Fire({KeyCode=Enum.KeyCode.V,UserInputType=Enum.UserInputType.Keyboard},false)
 end)
 if ok then return true end
 return false,tostring(err)
end
local function stop(reason)
 armed=false
 held=false
 queue=0
 lastMessage=reason or "Stopped."
 refresh()
end
local function castOne()
 if not live or not armed or not held then return end
 if UIS:GetFocusedTextBox() then queue=0;return end
 local char=plr.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then stop("Character unavailable; stopped.");return end
 local d,name,info=spellInfo()
 if not boltSelected(name,info) then stop("Energy Bolt is not selected; stopped.");return end
 local energy=d and d.voodoo
 if cfg.guard and type(info.voodooCost)=="number"
    and (type(energy)~="number" or energy<info.voodooCost) then
  lastMessage="Waiting for Voodoo regeneration; energy guard is ON."
  return
 end
 local action=cfg.mode
 if action=="hybrid" then
  castFlip+=1
  action=(castFlip%2==0) and "native" or "direct"
 end
 attempts+=1
 local ok,err
 if action=="native" then
  ok,err=nativeCast()
  if ok then nativeCalls+=1 end
 else
  local pos=targetPos()
  ok,err=pcall(function()
   packets.VoodooSpell.send({targetPos=pos,aimDirection=direction(pos)})
  end)
  if ok then sent+=1 end
 end
 if ok then
  errors=0
  lastMessage=(action=="native" and "Native handler invoked" or "Typed packet sent")..
   " • server acceptance is not confirmed."
 else
  errors+=1
  lastMessage="Method unavailable: "..tostring(err):sub(1,75)
  if cfg.mode=="hybrid" and action=="native" then
   cfg.mode="direct"
   lastMessage="Native replay unavailable; switched to direct casting."
  elseif errors>=3 then stop("Stopped after 3 cast errors: "..tostring(err):sub(1,60)) end
 end
end
local function regenBoosts()
 local main=pg:FindFirstChild("MainGui")
 local panels=main and main:FindFirstChild("Panels")
 local toolbar=panels and panels:FindFirstChild("Toolbar")
 local container=toolbar and toolbar:FindFirstChild("Container")
 local boosts=container and container:FindFirstChild("Boosts")
 local found={}
 if boosts then
  for _,name in ipairs({"Voodoo Passive","Void Armor","Jelly Sandwich"}) do
   local x=boosts:FindFirstChild(name)
   if x and x.Visible then found[#found+1]=name end
  end
 end
 return #found>0 and table.concat(found," / ") or "none visible"
end
-- Safe passive receivers: preserve the game's original ByteNet callback.
-- These are observations, not evidence that our own casts created the effects.
local function monitorPacket(name,callback)
 local packet=packets[name]
 if type(packet)~="table" or type(packet.fireListener)~="function" then return end
 local original=packet.fireListener
 local wrapper=function(...)
  local result=original(...)
  pcall(callback,...)
  return result
 end
 packet.fireListener=wrapper
 packetWrappers[#packetWrappers+1]={packet=packet,original=original,wrapper=wrapper}
end
for _,name in ipairs({"UpdateStats","UpdateStatsUnreliable"}) do
 monitorPacket(name,function(value)
  if type(value)=="table" and type(value.voodoo)=="number" then
   incomingStats+=1;observedServerVoodoo=value.voodoo
  end
 end)
end
monitorPacket("ServerCreateProjectile",function()incomingProjectiles+=1 end)
local function saveSnapshot()
 if type(writefile)~="function" then
  logStatus="No writefile in this executor";return
 end
 local d,name,info=spellInfo()
 local model=select(1,dave())
 local health=model and model:FindFirstChild("Health")
 local hp=health and health:IsA("ValueBase") and type(health.Value)=="number" and health.Value or nil
 local observedDps=nil
 if hp and #hpWindow>0 then
  observedDps=math.max(0,hpWindow[1].hp-hp)/math.max(.1,os.clock()-hpWindow[1].at)
 end
 local payload={
  version="2.1",saved_utc=os.date("!%Y-%m-%dT%H:%M:%SZ"),
  selected_spell=tostring(name or "none"),
  method=cfg.mode,pulses_per_second=cfg.rate,
  double=cfg.double,triple=cfg.triple,aim_dave=cfg.dave,aoe_sweep=cfg.sweep,
  energy_guard=cfg.guard,smart_regen_pacing=cfg.smart,
  held=held,armed=armed,voodoo=d and d.voodoo or nil,
  incoming_server_voodoo=observedServerVoodoo,
  energy_updates_observed=incomingStats,
  other_projectile_events_observed=incomingProjectiles,
  direct_send_calls=sent,native_event_calls=nativeCalls,attempts=attempts,
  consecutive_errors=errors,nearby_dave_hp=hp,nearby_dave_hp_loss_per_sec=observedDps,
  note="Outgoing attempts and nearby damage cannot alone verify that lightning was accepted."
 }
 local ok,err=pcall(function()writefile(LOG_FILE,Http:JSONEncode(payload))end)
 logStatus=ok and ("Saved "..LOG_FILE) or ("Log failed: "..tostring(err):sub(1,65))
end
local function destroy()
 if not live then return end
 live=false;armed=false;held=false;queue=0
 for _,conn in ipairs(connections) do pcall(function()conn:Disconnect()end)end
 for _,entry in ipairs(packetWrappers) do
  pcall(function()
   if entry.packet.fireListener==entry.wrapper then entry.packet.fireListener=entry.original end
  end)
 end
 if screen.Parent then screen:Destroy()end
end
shutdown.Event:Connect(destroy)
close.Activated:Connect(destroy)
connections[#connections+1]=UIS.InputBegan:Connect(function(input,processed)
 if input.KeyCode==Enum.KeyCode.F6 then
  stop("F6 emergency stop. Click OFF to arm again.")
 elseif input.KeyCode==Enum.KeyCode.V and not processed and not UIS:GetFocusedTextBox() then
  held=true
  nextPulse=0
 end
end)
connections[#connections+1]=UIS.InputEnded:Connect(function(input)
 if input.KeyCode==Enum.KeyCode.V then
  held=false;queue=0
  lastMessage="V released • casting stopped."
 end
end)
connections[#connections+1]=Run.Heartbeat:Connect(function()
 if not live then return end
 local now=os.clock()
 if UIS:GetFocusedTextBox() then held=false;queue=0 end
 if armed and held then
  local d=getData()
  local energy=d and d.voodoo
  local rate=cfg.rate
  if cfg.smart and type(energy)=="number" then
   if energy<30 then rate=math.max(1,math.floor(cfg.rate*.25))
   elseif energy<60 then rate=math.max(1,math.floor(cfg.rate*.5)) end
  end
  if now>=nextPulse then
   local variance=cfg.jitter and (math.random()*.24-.12) or 0
   nextPulse=now+(1/rate)*(1+variance)
   local amount=cfg.triple and 3 or cfg.double and 2 or 1
   queue=math.min(queue+amount,6)
  end
  if queue>0 and now>=nextQueued and now-lastAttempt>=1/24 then
   queue-=1
   nextQueued=now+.03
   lastAttempt=now
   castOne()
  end
 else
  queue=0
  nextPulse=now
 end
 if now-lastLogAt>=5 then lastLogAt=now;pcall(saveSnapshot) end
  if now-lastDraw<.3 then return end
 lastDraw=now
 refresh()
 local d,name,info=spellInfo()
 spellLabel.Text="SELECTED SPELL: "..tostring(name or "None")
 spellLabel.TextColor3=boltSelected(name,info) and COL.mint or COL.bad
 local v=d and d.voodoo
 if type(v)=="number" then
  if previousV~=nil and now-previousVAt>.25 then
   local delta=v-previousV
   if delta>0 then regen=regen*.7+(delta/(now-previousVAt))*.3 end
  end
  previousV=v;previousVAt=now
 end
 energyLabel.Text="VOODOO: "..(type(v)=="number" and string.format("%.1f / 100",v) or "?")..
  "  •  Cost: "..tostring(info and info.voodooCost or "?")..
  "  •  Regen observed: "..string.format("%.1f/s",regen)
 boostLabel.Text="BUFFS: "..regenBoosts().."   •  Spellmaster via Mojo"
 local model=select(1,dave())
 local hp=model and model:FindFirstChild("Health")
 local value=hp and hp:IsA("ValueBase") and type(hp.Value)=="number" and hp.Value or nil
 if value then
  hpWindow[#hpWindow+1]={at=now,hp=value}
  while #hpWindow>0 and now-hpWindow[1].at>8 do table.remove(hpWindow,1)end
  lastDaveHP=value
 end
 local observed=0
 if value and #hpWindow>0 then
  observed=math.max(0,hpWindow[1].hp-value)/math.max(.1,now-hpWindow[1].at)
 end
 status.Text="STATUS: "..lastMessage
 stats.Text=string.format("Packets %d  •  UI %d  •  Dave %s  •  HP loss %.1f/s",
  sent,nativeCalls,value and string.format("%.0f",value) or "--",observed)
 telemetryLabel.Text="RUNNER LOG: "..logStatus.."  •  Incoming stats: "..incomingStats.." / Projectiles*: "..incomingProjectiles
end)
refresh()
warn("[Lightning Lab v2.1] Published. Hold V casts; release stops. Scroll toggles. F6 emergency stop. Client attempts do not prove server acceptance.")
