-- BOOGA BOOGA REBORN | Lightning authority experiment v1
-- Controlled single-cast versus same-frame double-cast comparison.
-- Only real game spell requests. Never alters Voodoo, boosts or inventory.
local allowed={[11729688377]=true,[11879754496]=true,[124322376658249]=true}
if not allowed[game.PlaceId] then warn("[Bolt Test] Enter Booga Booga Reborn.");return end
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local p=Players.LocalPlayer
local pg=p and p:WaitForChild("PlayerGui",10)
if not pg then return end
local old=pg:FindFirstChild("BoogaBoltAuthorityV1")
if old then
 local e=old:FindFirstChild("Shutdown")
 if e and e:IsA("BindableEvent")then pcall(function()e:Fire()end)end
 if old.Parent then old:Destroy()end
end
local function req(...)
 local node=RS
 for _,part in ipairs({...})do node=node and node:FindFirstChild(part)end
 if not node or not node:IsA("ModuleScript")then return nil end
 local ok,value=pcall(require,node)
 return ok and value or nil
end
local packets=req("Modules","util","packets")
local gameUtil=req("Modules","util","gameUtil")
local functions=req("Game","functions")
local mouse=p:GetMouse()
local function valid(n)
 return type(n)=="number" and n==n and n<math.huge and n>-math.huge
end
local function data()
 local d=gameUtil and gameUtil.Data
 return type(d)=="table" and d or nil
end
local function target()
 local obj=mouse.Target
 for _=1,10 do
  if not obj or obj==workspace then break end
  if obj:IsA("Model")then
   if Players:GetPlayerFromCharacter(obj)then return nil end
   local hp=obj:FindFirstChild("Health")
   if hp and (hp:IsA("IntValue") or hp:IsA("NumberValue"))and valid(hp.Value)then
    return obj.Name,function()return hp.Parent and hp.Value or nil end
   end
   local a=obj:GetAttribute("Health")
   if valid(a)then
    return obj.Name,function()return obj.Parent and obj:GetAttribute("Health") or nil end
   end
  end
  obj=obj.Parent
 end
 return nil
end
local function aim()
 if type(functions)=="table" and type(functions.cursorRay)=="function"then
  local ok,v=pcall(function()local _,pos=functions.cursorRay();return pos end)
  if ok and typeof(v)=="Vector3"then return v end
 end
 local ok,v=pcall(function()return mouse.Hit.Position end)
 return ok and typeof(v)=="Vector3" and v or nil
end
local function direction()
 local camera=workspace.CurrentCamera
 local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 if not camera or not hum then return Vector3.zero end
 local cf=camera.CFrame
 local horizontal=cf.LookVector*Vector3.new(1,0,1)
 local movement=hum.MoveDirection*Vector3.new(1,0,1)
 local v
 if movement.Magnitude>.1 and horizontal.Magnitude>.1 then
  v=cf:VectorToWorldSpace(CFrame.lookAlong(Vector3.zero,horizontal.Unit):VectorToObjectSpace(movement.Unit))
 elseif movement.Magnitude>.1 then v=movement.Unit
 else v=cf.LookVector end
 if v.Y<0 then v=v*Vector3.new(1,0,1)end
 return v.Magnitude>.1 and v.Unit or Vector3.zero
end
local live=true
local busy=false
local tests=0
local cooldown=0
local active=nil
local history={}
local status="Aim at a nonplayer boss. B = one cast, N = two simultaneous casts."
local con={}
local c={bg=Color3.fromRGB(14,19,32),edge=Color3.fromRGB(172,147,241),card=Color3.fromRGB(34,45,69),white=Color3.fromRGB(242,246,255),muted=Color3.fromRGB(178,191,214),green=Color3.fromRGB(85,219,178),yellow=Color3.fromRGB(255,206,130)}
local function mk(kind,props,parent)
 local o=Instance.new(kind)
 for k,v in pairs(props)do o[k]=v end
 o.Parent=parent
 return o
end
local gui=mk("ScreenGui",{Name="BoogaBoltAuthorityV1",ResetOnSpawn=false,DisplayOrder=280},pg)
local shutdown=mk("BindableEvent",{Name="Shutdown"},gui)
local box=mk("Frame",{Size=UDim2.fromOffset(441,258),Position=UDim2.fromOffset(35,120),BackgroundColor3=c.bg,BorderSizePixel=0,Active=true,Draggable=true},gui)
mk("UICorner",{CornerRadius=UDim.new(0,12)},box)
mk("UIStroke",{Color=c.edge,Thickness=1.3},box)
local function label(t,y,h,size,color,bold)
 return mk("TextLabel",{Text=t,Position=UDim2.fromOffset(15,y),Size=UDim2.fromOffset(411,h),BackgroundTransparency=1,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextColor3=color or c.white,TextSize=size or 12,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham},box)
end
local function button(t,x,y,w,h,fn)
 local b=mk("TextButton",{Text=t,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=c.card,TextColor3=c.white,TextSize=12,Font=Enum.Font.GothamBold,BorderSizePixel=0},box)
 mk("UICorner",{CornerRadius=UDim.new(0,8)},b)
 b.Activated:Connect(fn)
 return b
end
label("⚡ LIGHTNING • AUTHORITY TEST",10,29,17,c.white,true)
label("B: single     N: same-frame double     F6: close",42,22,11,c.muted)
local targetLabel=label("",71,25,12,c.green,true)
local energyLabel=label("",97,25,11,c.white)
local statusLabel=label("",128,57,11,c.yellow)
local historyLabel=label("",190,32,11,c.muted)
local function report()
 return Http:JSONEncode({version=1,place_id=game.PlaceId,results=history,
  note="Client-observed health and Voodoo; other damage/regeneration can affect readings. Requests never prove acceptance."})
end
local function save()
 local text=report()
 if type(writefile)=="function"then pcall(function()writefile("booga_bolt_authority_v1.json",text)end)end
 if type(setclipboard)=="function"then
  local ok=pcall(function()setclipboard(text)end)
  if ok then status="Results copied to clipboard."end
 end
end
local function close()
 if not live then return end
 live=false
 pcall(save)
 for _,v in ipairs(con)do pcall(function()v:Disconnect()end)end
 if gui.Parent then gui:Destroy()end
end
shutdown.Event:Connect(close)
button("COPY RESULTS",15,223,145,29,save)
button("×",407,10,27,27,close)
local function runTest(count)
 if not live or busy or tests>=4 or os.clock()<cooldown then
  status="Busy or capped. Only four controlled tests per session."
  return
 end
 local d=data()
 if not d or d.spell~="Energy Bolt"then status="Select Energy Bolt in game first.";return end
 local v=d.voodoo
 if not valid(v) or v<30 or v>=60 then
  status="Start with 30–59 Voodoo so two paid casts are not normally affordable.";return
 end
 local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then status="Spawn as a living character.";return end
 local name,readHP=target()
 local pos=aim()
 if not name or not readHP or not pos then status="Aim at a creature or boss with replicated Health.";return end
 local hp=readHP()
 if not valid(hp)then status="Target Health not readable.";return end
 local packet=packets and packets.VoodooSpell
 if not packet or type(packet.send)~="function"then status="VoodooSpell module unavailable.";return end
 busy=true;tests+=1;cooldown=os.clock()+9
 local result={type=count==1 and "SINGLE" or "DOUBLE_SAME_FRAME",target=name,before_voodoo=v,before_health=hp,requests=0,errors=0}
 active={result=result,read=readHP,minV=v,minHP=hp}
 local payload={targetPos=pos,aimDirection=direction()}
 for _=1,count do
  local ok=pcall(function()packet.send(payload)end)
  if ok then result.requests+=1 else result.errors+=1 end
 end
 status="Sent "..count.." request(s) without delays; watching actual Health and Voodoo for five seconds."
 task.delay(5.1,function()
  if not live or not active or active.result~=result then return end
  local a=active;active=nil;busy=false
  result.voodoo_loss=math.max(0,v-a.minV)
  result.target_health_loss=math.max(0,hp-a.minHP)
  history[#history+1]=result
  if count==2 and result.target_health_loss>=55 and result.voodoo_loss<45 then
   status="POTENTIAL 2-FOR-1: more than one bolt's nominal damage, under 45 Voodoo lost. Repeat before concluding."
  elseif result.target_health_loss>0 then
   status=string.format("Damage observed: %.1f. Voodoo lost: %.1f. Compare with other test.",result.target_health_loss,result.voodoo_loss)
  else
   status="No damage observed. Requests may have been rejected or missed."
  end
 end)
end
con[#con+1]=UIS.InputBegan:Connect(function(i,processed)
 if processed or UIS:GetFocusedTextBox()then return end
 if i.KeyCode==Enum.KeyCode.B then runTest(1)
 elseif i.KeyCode==Enum.KeyCode.N then runTest(2)
 elseif i.KeyCode==Enum.KeyCode.F6 then close()end
end)
local lastUI=0
con[#con+1]=Run.Heartbeat:Connect(function()
 if not live then return end
 local d=data()
 local v=d and d.voodoo
 if active then
  if valid(v)then active.minV=math.min(active.minV,v)end
  local hp=active.read()
  if valid(hp)then active.minHP=math.min(active.minHP,hp)end
 end
 local now=os.clock()
 if now-lastUI>.2 then
  lastUI=now
  local name=target()
  targetLabel.Text="TARGET: "..tostring(name or "Aim at creature / boss")
  energyLabel.Text="VOODOO: "..(valid(v) and string.format("%.1f",v) or "?").."   SPELL: "..tostring(d and d.spell or "?")
  statusLabel.Text=status
  local h=history[#history]
  historyLabel.Text=h and string.format("LAST: %s  •  Target HP -%.1f  •  Voodoo -%.1f",h.type,h.target_health_loss,h.voodoo_loss) or "This tests burst ordering, not normal rapid-fire."
 end
end)
warn("[Bolt Authority v1] Aim at a nonplayer entity. B=one cast, N=two same-frame requests. Real server damage not guaranteed.")