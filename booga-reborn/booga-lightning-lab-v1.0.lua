-- Booga Lightning Lab v1.0 | Lightning already selected
-- Native VoodooSpell packet, real cursor aim, no fake energy or fake damage.
if game.PlaceId ~= 11729688377 then warn("Lightning Lab: wrong place"); return end
local P=game:GetService("Players").LocalPlayer
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local PG=P:WaitForChild("PlayerGui")
local old=PG:FindFirstChild("BoogaLightningLabV1")
if old then local s=old:FindFirstChild("Shutdown");if s then s:Fire() end;old:Destroy() end
local modules=RS:WaitForChild("Modules",8)
local util=modules and modules:FindFirstChild("util")
local packets,gameUtil,itemData
local ok=pcall(function()
 packets=require(util.packets);gameUtil=require(util.gameUtil);itemData=require(modules.data.itemData)
end)
if not ok or not packets or not packets.VoodooSpell or type(packets.VoodooSpell.send)~="function" then
 warn("Lightning Lab: native spell API unavailable");return
end
local live=true
local state={hold=false,auto=false,burst=false,aim=false,budget=true,native=false,rate=4}
local held=false
local sent=0
local errors=0
local lastSend=0
local lastBurst=0
local lastStatus="Ready. Lightning must already be equipped."
local connections={}
local gui=Instance.new("ScreenGui");gui.Name="BoogaLightningLabV1";gui.ResetOnSpawn=false;gui.DisplayOrder=190;gui.Parent=PG
local shutdown=Instance.new("BindableEvent");shutdown.Name="Shutdown";shutdown.Parent=gui
local function make(kind,props,parent)
 local x=Instance.new(kind)
 for k,v in pairs(props) do x[k]=v end
 x.Parent=parent;return x
end
local colors={bg=Color3.fromRGB(13,17,32),panel=Color3.fromRGB(26,34,54),accent=Color3.fromRGB(137,117,255),white=Color3.fromRGB(240,242,255),muted=Color3.fromRGB(164,175,198),on=Color3.fromRGB(58,159,125),off=Color3.fromRGB(62,72,92)}
local frame=make("Frame",{Name="Window",Size=UDim2.fromOffset(400,520),Position=UDim2.fromOffset(40,120),BackgroundColor3=colors.bg,BorderSizePixel=0,Active=true,Draggable=true},gui)
make("UICorner",{CornerRadius=UDim.new(0,14)},frame)
make("UIStroke",{Color=colors.accent,Thickness=1.4,Transparency=.18},frame)
local function label(t,x,y,w,h,size,color,bold)
 return make("TextLabel",{Text=t,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,TextColor3=color or colors.white,TextSize=size or 13,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true},frame)
end
label("⚡ LIGHTNING LAB",17,12,325,34,20,colors.accent,true)
label("BOOGA REBORN  •  HOLD V / AUTO / BURST",18,44,360,19,10,colors.muted)
local function stopAll()
 held=false;state.auto=false;state.hold=false;state.burst=false
end
local function close()
 stopAll();live=false
 for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
 gui:Destroy()
end
local closeBtn=make("TextButton",{Text="×",Position=UDim2.fromOffset(355,12),Size=UDim2.fromOffset(28,28),BackgroundColor3=colors.panel,TextColor3=colors.white,TextSize=20,BorderSizePixel=0},frame)
make("UICorner",{CornerRadius=UDim.new(0,7)},closeBtn)
closeBtn.Activated:Connect(close)
local function switch(key,title,desc,y)
 label(title,19,y,270,20,13,colors.white,true)
 label(desc,19,y+21,292,21,10,colors.muted)
 local b=make("TextButton",{Text="OFF",Position=UDim2.fromOffset(314,y+7),Size=UDim2.fromOffset(65,30),BackgroundColor3=colors.off,TextColor3=colors.white,TextSize=12,Font=Enum.Font.GothamBold,BorderSizePixel=0},frame)
 make("UICorner",{CornerRadius=UDim.new(0,8)},b)
 local function refresh()
 b.Text=state[key] and "ON" or "OFF";b.BackgroundColor3=state[key] and colors.on or colors.off
 end
 b.Activated:Connect(function()
  state[key]=not state[key]
  if key=="auto" and state.auto then state.hold=false end
  if key=="hold" and state.hold then state.auto=false end
  if key=="burst" and state.burst then state.auto=false;state.hold=false end
  for _,f in ipairs({}) do f() end
  refresh()
 end)
 return refresh
end
local a=switch("hold","HOLD V  •  RAPID CAST","Repeated casts only while V is held",80)
local b=switch("auto","AUTO CAST","Repeats while enabled; click to stop",136)
local c=switch("burst","BURST MODE","One bounded 3-cast burst per V press",192)
local d=switch("aim","AIM AT DAVE","Targets nearest streamed Dave (direct mode)",248)
local e=switch("budget","ENERGY GUARD","Stops sends when local Voodoo is insufficient",304)
local f=switch("native","NATIVE UI REPLAY","Uses game UI handler if supported",360)
local refreshAll=function()a();b();c();d();e();f()end
-- Reconcile mutually exclusive switches on every update.
local rateText=label("RATE  4 casts/s",20,412,200,21,12,colors.white,true)
local minus=make("TextButton",{Text="−",Position=UDim2.fromOffset(255,409),Size=UDim2.fromOffset(48,29),BackgroundColor3=colors.panel,TextColor3=colors.white,TextSize=20,BorderSizePixel=0},frame)
local plus=make("TextButton",{Text="+",Position=UDim2.fromOffset(312,409),Size=UDim2.fromOffset(48,29),BackgroundColor3=colors.panel,TextColor3=colors.white,TextSize=20,BorderSizePixel=0},frame)
for _,x in ipairs({minus,plus}) do make("UICorner",{CornerRadius=UDim.new(0,7)},x) end
minus.Activated:Connect(function()state.rate=math.max(1,state.rate-1) end)
plus.Activated:Connect(function()state.rate=math.min(12,state.rate+1) end)
local status=label("",19,447,360,65,11,colors.muted)
local function getSpell()
 local data=gameUtil.Data
 local name=data and data.spell
 local info=name and itemData[name]
 return data,name,info
end
local function aim()
 if state.aim then
  local resources=workspace:FindFirstChild("Resources")
  local root=P.Character and P.Character:FindFirstChild("HumanoidRootPart")
  local closest,best=nil,math.huge
  if resources and root then
   for _,m in ipairs(resources:GetChildren()) do
    if m:IsA("Model") and m.Name=="Dave" then
     local part=m.PrimaryPart or m:FindFirstChild("Stump")
     if part then
      local dist=(part.Position-root.Position).Magnitude
      if dist<best then closest,best=part,dist end
     end
    end
   end
  end
  if closest then return closest.Position end
 end
 local mouse=P:GetMouse()
 return mouse.Hit.Position
end
local function nativeCast()
 local get=getconnections
 if type(get)~="function" then return false,"getconnections not supported by Velocity" end
 local main=PG:FindFirstChild("MainGui")
 local panels=main and main:FindFirstChild("Panels")
 local stats=panels and panels:FindFirstChild("Stats")
 local images=stats and stats:FindFirstChild("ImageLabels")
 local button=images and images:FindFirstChild("SpellImage")
 if not button or not button:IsA("GuiButton") then return false,"SpellImage button not found" end
 local ok,items=pcall(get,button.Activated)
 if not ok or type(items)~="table" then return false,"Cannot inspect native spell-button handlers" end
 for _,conn in ipairs(items) do
  local valid,fire=pcall(function()return conn.Fire end)
  if valid and type(fire)=="function" then
   return pcall(function()conn:Fire()end)
  end
 end
 return false,"No callable native spell-button handler"
end
local function cast()
 local now=os.clock()
 if now-lastSend<1/state.rate then return false end
 if UIS:GetFocusedTextBox() then lastStatus="Chat open: paused";return false end
 local character=P.Character
 local hum=character and character:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then lastStatus="Character unavailable";return false end
 local data,name,info=getSpell()
 if not name or not info then lastStatus="Select Lightning in game first";return false end
 if name~="Energy Bolt" and name~="Lightning Bolt" and name~="Lightning" then lastStatus="Energy Bolt must be selected";return false end
 if state.budget and type(info.voodooCost)=="number" and (not data or type(data.voodoo)~="number" or data.voodoo<info.voodooCost) then
  lastStatus="Energy guard: insufficient Voodoo";return false
 end
 local target=aim()
 local camera=workspace.CurrentCamera
 local direction=camera and camera.CFrame.LookVector or hum.RootPart and hum.RootPart.CFrame.LookVector or Vector3.new(0,0,-1)
 if direction.Y<0 then direction=Vector3.new(direction.X,0,direction.Z) end
 if direction.Magnitude<.01 then direction=Vector3.new(0,0,-1) end
 lastSend=now
 local success,err
 if state.native then success,err=nativeCast()
 else success,err=pcall(function()packets.VoodooSpell.send({targetPos=target,aimDirection=direction.Unit})end) end
 if success then sent+=1;lastStatus=(state.native and "Native handler invoked" or "Packet sent").."; server acceptance not confirmed"
 else
  errors+=1;lastStatus="Cast method error: "..tostring(err):sub(1,65)
  if state.native then state.native=false else stopAll() end
 end
 return success
end
local function onPress(input,processed)
 if processed or input.KeyCode~=Enum.KeyCode.V then return end
 held=true
 if state.burst and os.clock()-lastBurst>1 then
  lastBurst=os.clock()
  task.spawn(function()
   for i=1,3 do if not live or not state.burst then break end;cast();task.wait(1/state.rate) end
  end)
 end
end
connections[#connections+1]=UIS.InputBegan:Connect(onPress)
connections[#connections+1]=UIS.InputEnded:Connect(function(input)if input.KeyCode==Enum.KeyCode.V then held=false end end)
local lastDraw=0
connections[#connections+1]=Run.Heartbeat:Connect(function()
 if not live then return end
 local now=os.clock()
 if (state.hold and held) or state.auto then cast() end
 if now-lastDraw>.2 then
  lastDraw=now
  refreshAll()
  rateText.Text="RATE  "..state.rate.." casts/s"
  local data,name,info=getSpell()
  local energy=data and data.voodoo
  status.Text=string.format("Selected: %s  |  Voodoo: %s  |  Sent: %d  |  Errors: %d\n%s",tostring(name or "NONE"),type(energy)=="number" and string.format("%.1f",energy) or "?",sent,errors,lastStatus)
 end
end)
connections[#connections+1]=UIS.InputBegan:Connect(function(input)
 if input.KeyCode==Enum.KeyCode.F6 then stopAll();lastStatus="F6: all casting stopped" end
end)
shutdown.Event:Connect(close)
refreshAll()
warn("[Lightning Lab] v1.1 ready. Hold V, auto, burst, or native UI replay. Real server damage not guaranteed.")
