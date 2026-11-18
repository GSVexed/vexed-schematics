-- Lightning Hold V v5: streamlined casting + honest regen monitor.
-- Uses real selected spell, does not fabricate energy/buffs.
if game.PlaceId ~= 11729688377 then warn("[Lightning v5] Wrong place");return end
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui",10)
if not pg then return end
for _,name in ipairs({"BoogaLightningV5","BoogaLightningHoldV4","BoogaLightningLabV3","BoogaLightningLabV2","BoogaLightningLabV1"}) do
 local g=pg:FindFirstChild(name)
 if g then
  local e=g:FindFirstChild("Shutdown")
  if e and e:IsA("BindableEvent") then pcall(function()e:Fire()end)end
  if g.Parent then g:Destroy()end
 end
end
local function mod(...)
 local parts={...}
 local node=RS
 for _,part in ipairs(parts) do node=node and node:FindFirstChild(part) end
 if not node or not node:IsA("ModuleScript") then return nil end
 local ok,v=pcall(require,node)
 return ok and v or nil
end
local packets=mod("Modules","util","packets")
local gameUtil=mod("Modules","util","gameUtil")
local itemData=mod("Modules","data","itemData")
local functions=mod("Game","functions")
local signals=mod("Game","wrappedSignals")
local live=true
local armed=true
local hold=false
local route=1 -- 1 direct, 2 native signal
local rates={2,4,6,8}
local rateIndex=2
local lastAt=0
local sends=0
local failures=0
local boltEvents=0
local statEvents=0
local lastEnergy=nil
local gained=0
local spent=0
local lastError="Hold V to cast; release to stop."
local reportFile="booga_lightning_v5_report.json"
local lastSave=0
local lastDraw=0
local hooks={}
local cons={}
local C={bg=Color3.fromRGB(14,19,33),card=Color3.fromRGB(29,38,57),edge=Color3.fromRGB(125,107,206),white=Color3.fromRGB(239,241,255),muted=Color3.fromRGB(171,184,208),mint=Color3.fromRGB(93,221,176),amber=Color3.fromRGB(245,194,111)}
local function make(class,props,parent)
 local obj=Instance.new(class)
 for k,v in pairs(props)do obj[k]=v end
 obj.Parent=parent;return obj
end
local gui=make("ScreenGui",{Name="BoogaLightningV5",ResetOnSpawn=false,DisplayOrder=255},pg)
local shutdown=make("BindableEvent",{Name="Shutdown"},gui)
local frame=make("Frame",{Size=UDim2.fromOffset(394,345),Position=UDim2.fromOffset(40,110),BackgroundColor3=C.bg,BorderSizePixel=0,Active=true,Draggable=true},gui)
make("UICorner",{CornerRadius=UDim.new(0,13)},frame)
make("UIStroke",{Color=C.edge,Thickness=1.4},frame)
local function label(t,x,y,w,h,size,col,bold)
 return make("TextLabel",{Text=t,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,TextColor3=col or C.white,TextSize=size or 12,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center},frame)
end
local function button(t,x,y,w,h,fn)
 local b=make("TextButton",{Text=t,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),TextColor3=C.white,TextSize=12,Font=Enum.Font.GothamBold,BackgroundColor3=C.card,BorderSizePixel=0},frame)
 make("UICorner",{CornerRadius=UDim.new(0,8)},b)
 b.Activated:Connect(fn)
 return b
end
label("⚡ LIGHTNING / HOLD V",17,9,325,32,19,C.white,true)
label("Selected Lightning • Cursor aim • No AFK",17,43,355,19,11,C.muted)
local selected=label("",17,72,360,22,12,C.white,true)
local energy=label("",17,97,360,23,12,C.muted)
local regen=label("",17,121,360,24,11,C.mint)
local status=label("",17,149,360,43,11,C.amber)
local routeBtn=button("",17,204,360,36,function()route=3-route;lastError="Route changed; hold V to use it."end)
local minus=button("−",17,250,46,31,function()rateIndex=math.max(1,rateIndex-1)end)
local speed=label("",72,251,235,28,12,C.white,true)
local plus=button("+",326,250,51,31,function()rateIndex=math.min(#rates,rateIndex+1)end)
local armBtn=button("",17,291,360,35,function()
 armed=not armed
 hold=false
 lastError=armed and "Armed. Hold V." or "Stopped."
end)
local stats=label("",17,327,360,16,10,C.muted)
local function data()
 return type(gameUtil)=="table" and type(gameUtil.Data)=="table" and gameUtil.Data or nil
end
local function spell()
 local d=data()
 local name=d and d.spell
 local info=type(itemData)=="table" and name and itemData[name] or nil
 return d,name,info
end
local function target()
 if type(functions)=="table" and type(functions.cursorRay)=="function" then
  local ok,p=pcall(function()local _,point=functions.cursorRay();return point end)
  if ok and typeof(p)=="Vector3" then return p end
 end
 local ok,p=pcall(function()return player:GetMouse().Hit.Position end)
 if ok and typeof(p)=="Vector3" then return p end
 local cam=workspace.CurrentCamera
 return cam and cam.CFrame.Position+cam.CFrame.LookVector*80 or Vector3.zero
end
local function direction()
 local cam=workspace.CurrentCamera
 if not cam then return Vector3.new(0,0,-1)end
 local v=cam.CFrame.LookVector
 if v.Y<0 then v=Vector3.new(v.X,0,v.Z)end
 return v.Magnitude>.01 and v.Unit or Vector3.new(0,0,-1)
end
local function cast()
 local d,name=spell()
 if name~="Energy Bolt" and name~="Lightning Bolt" then
  lastError="Select Lightning first (game reports "..tostring(name)..")";return
 end
 local char=player.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then lastError="Character unavailable";return end
 local ok,err
 if route==1 then
  local p=packets and packets.VoodooSpell
  if not p or type(p.send)~="function" then lastError="VoodooSpell API missing";return end
  ok,err=pcall(function()p.send({targetPos=target(),aimDirection=direction()})end)
 else
  local s=signals and signals.InputBegan
  if not s or type(s.Fire)~="function" then lastError="Native V signal missing";return end
  ok,err=pcall(function()s:Fire({KeyCode=Enum.KeyCode.V,UserInputType=Enum.UserInputType.Keyboard},false)end)
 end
 if ok then sends+=1;lastError="Request sent; server acceptance not guaranteed."
 else failures+=1;lastError="Cast error: "..tostring(err):sub(1,90) end
end
local function monitor(name,fn)
 local p=packets and packets[name]
 if type(p)~="table" or type(p.fireListener)~="function" then return end
 local original=p.fireListener
 local replacement=function(...)
  local result=table.pack(pcall(original,...))
  pcall(fn,select(1,...))
  if not result[1] then error(result[2],0)end
  return table.unpack(result,2,result.n)
 end
 p.fireListener=replacement
 hooks[#hooks+1]={p=p,original=original,replacement=replacement}
end
monitor("EnergyBolt",function()boltEvents+=1 end)
local function statPacket(payload)
 if type(payload)=="table" and type(payload.voodoo)=="number" then statEvents+=1 end
end
monitor("UpdateStats",statPacket)
monitor("UpdateStatsUnreliable",statPacket)
local function save()
 if type(writefile)~="function" then return end
 local d,name,info=spell()
 local report={
  version=5,place_id=game.PlaceId,spell=tostring(name or "none"),
  voodoo=d and d.voodoo or -1,spell_cost=info and info.voodooCost or -1,
  hold_active=hold,armed=armed,route=route==1 and "direct" or "native",
  attempts=sends,errors=failures,observed_energy_gained=gained,
  observed_energy_spent=spent,energy_bolt_events=boltEvents,
  stat_packets=statEvents,
  note="All observations are client-side. Bolt events may originate from other players. No server acceptance guaranteed."
 }
 pcall(function()writefile(reportFile,Http:JSONEncode(report))end)
end
local function stop()
 if not live then return end
 live=false;armed=false;hold=false
 pcall(save)
 for _,c in ipairs(cons)do pcall(function()c:Disconnect()end)end
 for _,h in ipairs(hooks)do pcall(function()if h.p.fireListener==h.replacement then h.p.fireListener=h.original end end)end
 if gui.Parent then gui:Destroy()end
end
shutdown.Event:Connect(stop)
button("×",347,11,29,28,stop)
cons[#cons+1]=UIS.InputBegan:Connect(function(i,processed)
 if i.KeyCode==Enum.KeyCode.F6 then armed=false;hold=false;lastError="Stopped by F6";return end
 if i.KeyCode==Enum.KeyCode.V and not processed and not UIS:GetFocusedTextBox() then hold=true;lastAt=0 end
end)
cons[#cons+1]=UIS.InputEnded:Connect(function(i)
 if i.KeyCode==Enum.KeyCode.V then hold=false;pcall(save)end
end)
cons[#cons+1]=Run.Heartbeat:Connect(function()
 if not live then return end
 local now=os.clock()
 local d,name,info=spell()
 local v=d and d.voodoo
 if type(v)=="number" then
  if type(lastEnergy)=="number" then
   if v>lastEnergy then gained+=v-lastEnergy elseif v<lastEnergy then spent+=lastEnergy-v end
  end
  lastEnergy=v
 end
 -- No low-energy client guard. The server decides whether casts count.
 local down=armed and hold and not UIS:GetFocusedTextBox()
 if down and now-lastAt>=1/rates[rateIndex] then lastAt=now;cast()end
 if now-lastDraw>.25 then
  lastDraw=now
  selected.Text="SPELL: "..tostring(name or "not loaded")
  energy.Text="VOODOO: "..(type(v)=="number" and string.format("%.1f",v) or "?").."  |  COST: "..tostring(info and info.voodooCost or "?")
  regen.Text=string.format("Observed gains: %.1f   |   Observed spending: %.1f",gained,spent)
  status.Text=(down and "V HELD • " or "READY • ")..lastError
  routeBtn.Text="CAST ROUTE: "..(route==1 and "DIRECT PACKET" or "NATIVE V HANDLER").."  •  SWITCH"
  speed.Text="RATE: "..rates[rateIndex].." attempts/s"
  armBtn.Text=armed and "ARMED • HOLD V TO CAST" or "STOPPED • CLICK TO ARM"
  armBtn.BackgroundColor3=armed and C.mint or C.card
  armBtn.TextColor3=armed and C.bg or C.white
  stats.Text=string.format("Attempts %d  |  Errors %d  |  Bolt events %d",sends,failures,boltEvents)
 end
 if now-lastSave>5 then lastSave=now;pcall(save)end
end)
warn("[Lightning v5] Ready. Hold V; release V stops. No fake regen or energy guard.")
