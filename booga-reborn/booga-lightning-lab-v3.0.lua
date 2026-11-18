-- BOOGA REBORN | LIGHTNING LAB v3.0
-- Fresh implementation grounded in archived Game/spells and Game/wrappedSignals.
-- ONE CONTROL: hold V for repeated attempts, release V to stop.
-- No fake voodoo balance / fake server health / auto-AFK mode.
if game.PlaceId~=11729688377 then warn("[Lightning v3] Wrong game.");return end
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local Http=game:GetService("HttpService")
local me=Players.LocalPlayer
if not me then return end
local pg=me:WaitForChild("PlayerGui",10)
if not pg then return end
for _,name in ipairs({"BoogaLightningLabV3","BoogaLightningLabV20","BoogaLightningLabV1"}) do
 local old=pg:FindFirstChild(name)
 if old then
  local sd=old:FindFirstChild("Shutdown")
  if sd and sd:IsA("BindableEvent") then pcall(function()sd:Fire()end)end
  if old.Parent then old:Destroy()end
 end
end
local mods=RS:FindFirstChild("Modules") or RS:WaitForChild("Modules",9)
local gameMods=RS:FindFirstChild("Game") or RS:WaitForChild("Game",9)
local function safeRequire(m)
 if not m or not m:IsA("ModuleScript") then return nil end
 local ok,result=pcall(require,m)
 return ok and result or nil
end
local util=mods and mods:FindFirstChild("util")
local packets=safeRequire(util and util:FindFirstChild("packets"))
local gameUtil=safeRequire(util and util:FindFirstChild("gameUtil"))
local itemData=safeRequire(mods and mods:FindFirstChild("data") and mods.data:FindFirstChild("itemData"))
local signals=safeRequire(gameMods and gameMods:FindFirstChild("wrappedSignals"))
local gameFns=safeRequire(gameMods and gameMods:FindFirstChild("functions"))
if type(packets)~="table" or type(gameUtil)~="table" or type(itemData)~="table" then
 warn("[Lightning v3] Required native game modules unavailable.");return
end
local methods={"GAME INPUT SIGNAL","DIRECT SPELL PACKET","ALTERNATE INPUT/PACKET","SPELL BUTTON HANDLER"}
local cfg={method=1,rate=4,pulse=1,aimDave=true,sweep=false,energyGuard=false,regenPace=false,log=true}
local rates={2,4,6,8,12}
local alive=true
local armed=true
local held=false
local nextAt=0
local sent=0
local inputReplays=0
local uiReplays=0
local fail=0
local energyBoltEvents=0
local energyBoltNear=0
local statsEvents=0
local energyDrop=0
local spellAttempts=0
local holdSessions=0
local lastErr="Ready. Hold V; release V to stop."
local seq=0
local lastUI=0
local lastReport=0
local logState="not attempted"
local fileName="booga_lightning_v3_report.json"
local previousEnergy=nil
local lastHP=nil
local lastDaveId=nil
local measuredDamage=0
local measuredSamples={}
local observations={}
local conns={}
local hookOriginals={}
local C={bg=Color3.fromRGB(12,16,28),panel=Color3.fromRGB(28,37,55),raised=Color3.fromRGB(38,48,71),purp=Color3.fromRGB(186,149,255),cyan=Color3.fromRGB(109,224,232),ok=Color3.fromRGB(86,204,168),white=Color3.fromRGB(234,239,255),mute=Color3.fromRGB(162,174,198),amber=Color3.fromRGB(246,205,129),red=Color3.fromRGB(249,136,155)}
local function new(class,props,parent)
 local obj=Instance.new(class)
 for k,v in pairs(props)do obj[k]=v end
 obj.Parent=parent
 return obj
end
local function round(o,r)
 new("UICorner",{CornerRadius=UDim.new(0,r or 9)},o)
 return o
end
local gui=new("ScreenGui",{Name="BoogaLightningLabV3",ResetOnSpawn=false,DisplayOrder=240,IgnoreGuiInset=true},pg)
local shutdown=new("BindableEvent",{Name="Shutdown"},gui)
local frame=round(new("Frame",{Name="Window",Size=UDim2.fromOffset(465,565),Position=UDim2.new(.5,-232,.5,-282),BackgroundColor3=C.bg,BorderSizePixel=0,Active=true,Draggable=true},gui),15)
new("UIStroke",{Color=C.purp,Thickness=1.2,Transparency=.22},frame)
local function label(text,x,y,w,h,size,color,bold,parent)
 return new("TextLabel",{Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),TextColor3=color or C.white,TextSize=size or 12,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,BackgroundTransparency=1,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center},parent or frame)
end
local function btn(text,x,y,w,h,parent,fn)
 local b=round(new("TextButton",{Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=C.raised,BorderSizePixel=0,TextColor3=C.white,TextSize=12,Font=Enum.Font.GothamBold},parent or frame),8)
 b.Activated:Connect(fn)
 return b
end
label("⚡ LIGHTNING LAB  /  v3.0",17,9,360,34,20,C.purp,true)
label("HOLD V → REPEAT LIGHTNING   |   RELEASE V → STOP",18,42,425,21,10,C.mute)
local spellLine=label("SPELL: ...",18,73,428,26,12,C.cyan,true)
local meter=label("VOODOO: ...",18,98,428,24,11,C.mute)
local summary=label("STATUS: ...",18,129,426,41,11,C.amber)
local scroll=new("ScrollingFrame",{Position=UDim2.fromOffset(12,183),Size=UDim2.fromOffset(441,266),CanvasSize=UDim2.fromOffset(0,655),ScrollBarThickness=4,ScrollBarImageColor3=C.purp,BackgroundTransparency=1,BorderSizePixel=0},frame)
local refreshes={}
local function toggle(title,subtitle,y,read,write)
 local slot=round(new("Frame",{Position=UDim2.fromOffset(2,y),Size=UDim2.fromOffset(421,57),BackgroundColor3=C.panel,BorderSizePixel=0},scroll),10)
 label(title,12,5,305,23,12,C.white,true,slot)
 label(subtitle,12,28,305,21,10,C.mute,false,slot)
 local b=round(new("TextButton",{Position=UDim2.fromOffset(335,12),Size=UDim2.fromOffset(72,31),BackgroundColor3=C.raised,BorderSizePixel=0,TextColor3=C.white,TextSize=11,Font=Enum.Font.GothamBold},slot),8)
 local function refresh()
  local enabled=read()
  b.Text=enabled and "ON" or "OFF"
  b.BackgroundColor3=enabled and C.ok or C.raised
  b.TextColor3=enabled and C.bg or C.white
 end
 b.Activated:Connect(function()write(not read());for _,f in ipairs(refreshes)do f()end end)
 refreshes[#refreshes+1]=refresh
 refresh()
end
toggle("NATIVE V SIGNAL","Repeats the game's real V input handler",0,function()return cfg.method==1 end,function(on)if on then cfg.method=1 end end)
toggle("DIRECT VOODOO PACKET","Sends game's typed VoodooSpell request",62,function()return cfg.method==2 end,function(on)if on then cfg.method=2 end end)
toggle("ALTERNATING CAST PATH","Alternates native signal and direct packet",124,function()return cfg.method==3 end,function(on)if on then cfg.method=3 end end)
toggle("SPELL BUTTON HANDLER","Uses spell UI callback, if executor supports it",186,function()return cfg.method==4 end,function(on)if on then cfg.method=4 end end)
toggle("AUTO AIM AT DAVE","Targets nearest loaded Dave (direct method)",248,function()return cfg.aimDave end,function(x)cfg.aimDave=x end)
toggle("LIGHTNING IMPACT SWEEP","Offsets direct target around Dave by 2 studs",310,function()return cfg.sweep end,function(x)cfg.sweep=x end)
toggle("VOODOO ENERGY GUARD","Only send while displayed Voodoo covers cost",372,function()return cfg.energyGuard end,function(x)cfg.energyGuard=x end)
toggle("REGEN-AWARE RATE","Slow down attempted casts when Voodoo is low",434,function()return cfg.regenPace end,function(x)cfg.regenPace=x end)
toggle("AUTO RESULT FILE","Write local report for your GitHub PC runner",496,function()return cfg.log end,function(x)cfg.log=x end)
toggle("DOUBLE / TRIPLE PULSE","Change the burst count using controls below",558,function()return cfg.pulse>1 end,function(x)cfg.pulse=x and 2 or 1 end)
local rateLabel=label("",73,463,160,29,13,C.purp,true)
local pulseLabel=label("",302,463,151,29,12,C.cyan,true)
btn("−",16,462,49,30,nil,function()local idx=table.find(rates,cfg.rate) or 2;cfg.rate=rates[math.max(1,idx-1)]end)
btn("+",234,462,49,30,nil,function()local idx=table.find(rates,cfg.rate) or 2;cfg.rate=rates[math.min(#rates,idx+1)]end)
btn("PULSE",374,463,73,28,nil,function()cfg.pulse=cfg.pulse%3+1;for _,f in ipairs(refreshes)do f()end end)
local tally=label("",16,500,430,23,10,C.mute)
local daveLine=label("",16,522,430,21,10,C.mute)
local logLine=label("",16,541,430,18,10,C.mute)
local function userData()
 return type(gameUtil.Data)=="table" and gameUtil.Data or nil
end
local function chosen()
 local d=userData()
 local name=d and d.spell
 local info=type(name)=="string" and itemData[name] or nil
 return d,name,info
end
local function isBolt(name,info)
 return (name=="Energy Bolt" or name=="Lightning Bolt") and type(info)=="table" and info.voodooSpell==true
end
local function dave()
 local folder=workspace:FindFirstChild("Resources")
 local char=me.Character
 local root=char and char:FindFirstChild("HumanoidRootPart")
 if not root or not folder then return nil,nil end
 local near,part,dist=nil,nil,math.huge
 for _,m in ipairs(folder:GetChildren())do
  if m:IsA("Model") and m.Name=="Dave" then
   local h=m:FindFirstChild("Health")
   local p=m.PrimaryPart or m:FindFirstChild("Stump") or m:FindFirstChildWhichIsA("BasePart")
   if p and h and h:IsA("ValueBase") and type(h.Value)=="number" and h.Value>0 then
    local n=(root.Position-p.Position).Magnitude
    if n<dist then near,part,dist=m,p,n end
   end
  end
 end
 return near,part
end
local function cursor()
 if type(gameFns)=="table" and type(gameFns.cursorRay)=="function" then
  local ok,pos=pcall(function()local _,p=gameFns.cursorRay();return p end)
  if ok and typeof(pos)=="Vector3" then return pos end
 end
 local ok,pos=pcall(function()return me:GetMouse().Hit.Position end)
 if ok and typeof(pos)=="Vector3" then return pos end
 local camera=workspace.CurrentCamera
 return camera and camera.CFrame.Position+camera.CFrame.LookVector*70 or Vector3.zero
end
local function aimPos()
 if cfg.aimDave then
  local _,part=dave()
  if part then
   local offsets={Vector3.zero,Vector3.new(2,0,0),Vector3.new(-2,0,0),Vector3.new(0,0,2),Vector3.new(0,0,-2)}
   return part.Position+(cfg.sweep and offsets[(spellAttempts%#offsets)+1] or Vector3.zero)
  end
 end
 return cursor()
end
local function aimDir()
 local char=me.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 local cam=workspace.CurrentCamera
 if not hum or not cam then return Vector3.zero end
 local forward=cam.CFrame.LookVector*Vector3.new(1,0,1)
 local move=hum.MoveDirection*Vector3.new(1,0,1)
 local v
 if move.Magnitude>.1 and forward.Magnitude>.1 then
  local localMove=CFrame.lookAlong(Vector3.zero,forward.Unit):VectorToObjectSpace(move.Unit)
  v=cam.CFrame:VectorToWorldSpace(localMove)
 elseif move.Magnitude>.1 then v=move.Unit
 else v=cam.CFrame.LookVector end
 if v.Y<0 then v=v*Vector3.new(1,0,1) end
 return v.Magnitude>.1 and v.Unit or Vector3.zero
end
local function nativeSignal()
 local ev=signals and signals.InputBegan
 if type(ev)~="table" or type(ev.Fire)~="function" then return false,"wrappedSignals.InputBegan:Fire not available" end
 return pcall(function()ev:Fire({KeyCode=Enum.KeyCode.V,UserInputType=Enum.UserInputType.Keyboard},false)end)
end
local function direct()
 local p=packets.VoodooSpell
 if type(p)~="table" or type(p.send)~="function" then return false,"VoodooSpell.send missing" end
 return pcall(function()p.send({targetPos=aimPos(),aimDirection=aimDir()})end)
end
local function buttonCast()
 local main=pg:FindFirstChild("MainGui")
 local panels=main and main:FindFirstChild("Panels")
 local stats=panels and panels:FindFirstChild("Stats")
 local images=stats and stats:FindFirstChild("ImageLabels")
 local spellImage=images and images:FindFirstChild("SpellImage")
 if not spellImage or not spellImage:IsA("GuiButton") then return false,"SpellImage UI unavailable" end
 if type(firesignal)=="function" then
  local ok,err=pcall(firesignal,spellImage.Activated)
  if ok then return true,nil end
 end
 if type(getconnections)=="function" then
  local ok,list=pcall(getconnections,spellImage.Activated)
  if ok and type(list)=="table" then
   for _,connection in ipairs(list)do
    local has,fn=pcall(function()return connection.Fire end)
    if has and type(fn)=="function" then
     local done=pcall(function()connection:Fire()end)
     if done then return true,nil end
    end
   end
  end
 end
 return false,"Executor does not support native UI handler"
end
local function observePacket(packetName,handler)
 local packet=packets[packetName]
 if type(packet)~="table" or type(packet.fireListener)~="function" then return false end
 local original=packet.fireListener
 local replacement=function(...)
  local first=select(1,...)
  local ok,err=pcall(handler,first)
  if not ok then warn("[Lightning v3] Observer: "..tostring(err)) end
  return original(...)
 end
 packet.fireListener=replacement
 hookOriginals[#hookOriginals+1]={obj=packet,original=original,ours=replacement}
 return true
end
local monitorCount=0
if observePacket("EnergyBolt",function(payload)
 energyBoltEvents+=1
 local root=me.Character and me.Character:FindFirstChild("HumanoidRootPart")
 local origin=type(payload)=="table" and payload.origin
 local pos=typeof(origin)=="CFrame" and origin.Position or typeof(origin)=="Vector3" and origin or nil
 if root and pos and (root.Position-pos).Magnitude<45 then energyBoltNear+=1 end
end) then monitorCount+=1 end
local function onStats(packet)
 if type(packet)=="table" and type(packet.voodoo)=="number" then
  statsEvents+=1
  if type(previousEnergy)=="number" and packet.voodoo<previousEnergy then
   energyDrop+=previousEnergy-packet.voodoo
  end
  previousEnergy=packet.voodoo
 end
end
if observePacket("UpdateStats",onStats) then monitorCount+=1 end
if observePacket("UpdateStatsUnreliable",onStats) then monitorCount+=1 end
local function sampleHP()
 local model=dave()
 local health=model and model:FindFirstChild("Health")
 local id=model and model:GetAttribute("EntityID")
 local hp=health and health:IsA("ValueBase") and type(health.Value)=="number" and health.Value or nil
 if hp and id and id==lastDaveId and lastHP and hp<lastHP then
  local damage=lastHP-hp
  measuredDamage+=damage
  measuredSamples[#measuredSamples+1]={at=os.clock(),dmg=damage}
 end
 lastHP=hp
 lastDaveId=id
 local now=os.clock()
 while #measuredSamples>0 and now-measuredSamples[1].at>12 do table.remove(measuredSamples,1)end
 local amount=0
 for _,s in ipairs(measuredSamples)do amount+=s.dmg end
 return hp,amount/12
end
local function saveReport()
 if not cfg.log then logState="disabled";return end
 if type(writefile)~="function" then logState="NO writefile API; runner cannot collect";return end
 local d,name,info=chosen()
 local hp,dps=sampleHP()
 local report={
  schema_version=3,created_utc=os.date("!%Y-%m-%dT%H:%M:%SZ"),place_id=game.PlaceId,
  mode=methods[cfg.method],rate_pulses_per_second=cfg.rate,pulses=cfg.pulse,
  aim_dave=cfg.aimDave,sweep=cfg.sweep,energy_guard=cfg.energyGuard,
  regen_pace=cfg.regenPace,spell=tostring(name or "none"),
  voodoo=type(d and d.voodoo)=="number" and d.voodoo or -1,
  spell_cost=type(info and info.voodooCost)=="number" and info.voodooCost or -1,
  hold_sessions=holdSessions,currently_holding=held,armed=armed,
  total_cast_attempts=spellAttempts,direct_requests=sent,
  native_input_replays=inputReplays,spell_ui_replays=uiReplays,errors=fail,
  energy_bolt_events=energyBoltEvents,nearby_energy_bolt_events=energyBoltNear,
  incoming_voodoo_stat_updates=statsEvents,voodoo_spent_observed=math.floor(energyDrop*100)/100,
  dave_hp=hp or -1,dave_total_observed_hp_loss=measuredDamage,
  dave_observed_hp_loss_per_second_12s=dps,
  passive_monitor_hooks=monitorCount,
  note="EnergyBolt events can be other players; HP loss can be other attackers. Client sends do not prove server acceptance."
 }
 local ok,err=pcall(function()writefile(fileName,Http:JSONEncode(report))end)
 logState=ok and ("saved: "..fileName) or ("writefile failed: "..tostring(err):sub(1,50))
end
local function stop(reason)
 armed=false;held=false;lastErr=reason or "Stopped."
 pcall(saveReport)
end
local function close()
 if not alive then return end
 stop("Closed.")
 alive=false
 for _,cx in ipairs(conns)do pcall(function()cx:Disconnect()end)end
 for _,entry in ipairs(hookOriginals)do
  pcall(function()
   if entry.obj.fireListener==entry.ours then entry.obj.fireListener=entry.original end
  end)
 end
 if gui.Parent then gui:Destroy()end
end
shutdown.Event:Connect(close)
btn("×",417,14,31,28,nil,close)
local arm=btn("ARMED • HOLD V",285,463,160,29,nil,function()
 armed=not armed
 held=false
 lastErr=armed and "Armed; hold V to cast." or "Disarmed; press to re-arm."
end)
conns[#conns+1]=UIS.InputBegan:Connect(function(input,processed)
 if input.KeyCode==Enum.KeyCode.F6 then stop("F6 stopped casting; click ARM to resume.");return end
 if input.KeyCode==Enum.KeyCode.V and not processed and not UIS:GetFocusedTextBox() and armed then
  held=true;nextAt=0;holdSessions+=1
 end
end)
conns[#conns+1]=UIS.InputEnded:Connect(function(input)
 if input.KeyCode==Enum.KeyCode.V then held=false;pcall(saveReport) end
end)
local function attempt()
 if not alive or not armed or not held then return end
 if UIS:GetFocusedTextBox() then held=false;return end
 local d,name,info=chosen()
 if not isBolt(name,info) then lastErr="Lightning/Energy Bolt not selected; no attempt.";return end
 local char=me.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then held=false;lastErr="Character not alive.";return end
 if cfg.energyGuard and (type(d.voodoo)~="number" or d.voodoo<info.voodooCost) then
  lastErr="Energy guard waiting for genuine Voodoo.";return
 end
 seq+=1;spellAttempts+=1
 local route=cfg.method
 if route==3 then route=seq%2==0 and 1 or 2 end
 local ok,err
 if route==1 then ok,err=nativeSignal();if ok then inputReplays+=1 end
 elseif route==2 then ok,err=direct();if ok then sent+=1 end
 else ok,err=buttonCast();if ok then uiReplays+=1 end end
 if ok then lastErr="Cast path invoked • server acceptance unverified."
 else fail+=1;lastErr="Cast method failed: "..tostring(err):sub(1,75) end
end
conns[#conns+1]=Run.Heartbeat:Connect(function()
 if not alive then return end
 local now=os.clock()
 if armed and held and not UIS:GetFocusedTextBox() and now>=nextAt then
  local d=userData()
  local rate=cfg.rate
  if cfg.regenPace and type(d and d.voodoo)=="number" then
   if d.voodoo<30 then rate=1 elseif d.voodoo<60 then rate=math.max(1,math.floor(rate/2))end
  end
  nextAt=now+1/rate
  for i=1,cfg.pulse do
   if not held or not armed then break end
   attempt()
  end
 end
 if now-lastUI>=.35 then
  lastUI=now
  local d,name,info=chosen()
  local hp,dps=sampleHP()
  spellLine.Text="SELECTED: "..tostring(name or "none").."    |    "..methods[cfg.method]
  spellLine.TextColor3=isBolt(name,info) and C.ok or C.red
  local v=d and d.voodoo
  meter.Text="VOODOO: "..(type(v)=="number" and string.format("%.1f / 100",v) or "?")..
   "    |    COST: "..tostring(info and info.voodooCost or "?")..
   "    |    BOLT EVENTS: "..energyBoltEvents
  summary.Text=(held and "V HELD • " or "READY • ")..lastErr
  tally.Text=string.format("ATTEMPTS %d  |  DIRECT %d  |  INPUT %d  |  UI %d  |  ERRORS %d",spellAttempts,sent,inputReplays,uiReplays,fail)
  daveLine.Text=string.format("DAVE HP %s  |  observed loss %.1f/s  |  nearby bolts %d",hp and string.format("%.0f",hp) or "not loaded",dps,energyBoltNear)
  logLine.Text="RUNNER REPORT: "..logState.."   |   MONITORS: "..monitorCount.."/3"
  rateLabel.Text=tostring(cfg.rate).."/s   •   "..tostring(cfg.pulse).." per pulse"
  pulseLabel.Text="PULSE "..cfg.pulse
  arm.Text=armed and (held and "CASTING • RELEASE V" or "ARMED • HOLD V") or "DISARMED • ARM"
  arm.BackgroundColor3=armed and C.ok or C.raised
 end
 if now-lastReport>4 then lastReport=now;pcall(saveReport)end
end)
pcall(saveReport)
warn("[Lightning Lab v3] Native V signal replay / direct / hybrid / UI. Hold V only. Auto report is local unless Windows runner finds report.")
