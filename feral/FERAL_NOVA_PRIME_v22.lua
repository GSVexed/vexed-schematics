-- FERAL NOVA PRIME v22 | CONTROLS & CLEANUP RELEASE
-- Replaces v19's ALT/C/V holds, prediction, and targeting.
-- Client-side effects only. No claims about server-authoritative cooldowns,
-- growth, carry eligibility, damage, or pickup acceptance.
-- RightShift toggles UI; End closes fully. Restores local adjustments.
local Players=game:GetService('Players')
local UIS=game:GetService('UserInputService')
local RunService=game:GetService('RunService')
local LocalPlayer=Players.LocalPlayer
if not LocalPlayer then return end
local env=(type(getgenv)=='function' and getgenv()) or _G
if env.FERAL_NOVA_PRIME_V21 and type(env.FERAL_NOVA_PRIME_V21.Destroy)=='function' then
 pcall(function() env.FERAL_NOVA_PRIME_V21:Destroy() end)
end
local app={alive=true,connections={},settings={escape=true,climb=false,hitbox=false,scale=2.0,radius=130,climbRadius=12,climbKey=Enum.KeyCode.E,growth=false,carry=false,cooldown=false,growthFactor=3,carryRatio=3,cooldownSeconds=1.5},stats={escapes=0,climbs=0},records={}}
env.FERAL_NOVA_PRIME_V21=app
if env.FERAL_NOVA_PRIME_V22 and type(env.FERAL_NOVA_PRIME_V22.Destroy)=='function' then
 pcall(function() env.FERAL_NOVA_PRIME_V22:Destroy() end)
end
env.FERAL_NOVA_PRIME_V22=app
local function on(event,fn) local c=event:Connect(fn);table.insert(app.connections,c);return c end
local function mk(class,properties,parent)
 local o=Instance.new(class)
 for k,v in pairs(properties or {}) do o[k]=v end
 o.Parent=parent;return o
end
local function attr(inst,names)
 if not inst then return nil end
 for _,key in ipairs(names) do
  local value=inst:GetAttribute(key)
  if value~=nil then return value,key end
 end
 return nil
end
local function char() return LocalPlayer.Character end
local function root(model) return model and (model:FindFirstChild('HumanoidRootPart') or model.PrimaryPart) end
local function notTyping() return UIS:GetFocusedTextBox()==nil end
local VIM=nil;pcall(function() VIM=game:GetService('VirtualInputManager') end)
local keys={Space=Enum.KeyCode.Space,E=Enum.KeyCode.E,F=Enum.KeyCode.F,R=Enum.KeyCode.R,Q=Enum.KeyCode.Q}
local vk={Space=0x20,E=0x45,F=0x46,R=0x52,Q=0x51}
local inputMode='none';local inputError=''
if type(keypress)=='function' and type(keyrelease)=='function' then inputMode='executor'
elseif VIM then inputMode='virtual' end
local function tap(key)
 if not app.alive or notTyping()==false then return false end
 local success,reason=pcall(function()
  if inputMode=='executor' then keypress(vk[key]);keyrelease(vk[key])
  elseif inputMode=='virtual' then
   VIM:SendKeyEvent(true,keys[key],false,game)
   VIM:SendKeyEvent(false,keys[key],false,game)
  else error('No supported input API') end
 end)
 if not success then inputError=tostring(reason);return false end
 return true
end
local colors={bg=Color3.fromRGB(12,18,30),pane=Color3.fromRGB(24,33,51),surface=Color3.fromRGB(36,49,72),text=Color3.fromRGB(232,241,255),cyan=Color3.fromRGB(85,216,223),muted=Color3.fromRGB(168,187,206),warn=Color3.fromRGB(255,193,103)}
local parent=LocalPlayer:FindFirstChildOfClass('PlayerGui') or LocalPlayer:WaitForChild('PlayerGui',10)
if not parent then return warn('FERAL v21: no PlayerGui') end
local gui=mk('ScreenGui',{Name='FERAL_NOVA_PRIME_V22',ResetOnSpawn=false,DisplayOrder=210},parent)
local panel=mk('Frame',{Size=UDim2.fromOffset(420,700),Position=UDim2.fromOffset(35,80),Active=true,BackgroundColor3=colors.bg,BorderSizePixel=0},gui)
local openButton=mk('TextButton',{Name='OpenHub',Size=UDim2.fromOffset(150,36),Position=UDim2.fromOffset(12,78),BackgroundColor3=colors.bg,Text='OPEN NOVA PRIME',TextColor3=colors.cyan,TextSize=12,Font=Enum.Font.GothamBold,BorderSizePixel=0,Visible=false},gui)
mk('UICorner',{CornerRadius=UDim.new(0,8)},openButton)
mk('UICorner',{CornerRadius=UDim.new(0,12)},panel)
mk('UIStroke',{Color=colors.cyan,Thickness=1,Transparency=.45},panel)
local function label(str,y,h,size,color)
 return mk('TextLabel',{Position=UDim2.fromOffset(16,y),Size=UDim2.fromOffset(386,h),BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=size or 13,TextColor3=color or colors.text,Text=str,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center},panel)
end
local function button(str,y)
 local b=mk('TextButton',{Position=UDim2.fromOffset(16,y),Size=UDim2.fromOffset(388,38),BackgroundColor3=colors.surface,TextColor3=colors.text,Font=Enum.Font.GothamBold,TextSize=12,Text=str,BorderSizePixel=0},panel)
 mk('UICorner',{CornerRadius=UDim.new(0,8)},b)
 return b
end
label('NOVA PRIME   /   v22  MECHANICS LAB',7,28,17,colors.cyan)
local close=mk('TextButton',{Position=UDim2.fromOffset(340,9),Size=UDim2.fromOffset(70,31),BackgroundColor3=colors.pane,Text='CLOSE',TextColor3=colors.text,TextSize=12,Font=Enum.Font.GothamBold,BorderSizePixel=0},panel)
mk('UICorner',{CornerRadius=UDim.new(0,6)},close)
label('Actual local config changes · reversible · server unverified',37,23,11,colors.muted)
local escapeBtn=button('AUTO ESCAPE: ON',70)
local climbBtn=button('EASIER TREE INTERACTION: OFF',115)
local hitboxBtn=button('LOCAL HITBOX EXPANSION: OFF',160)
local scaleBtn=button('HITBOX SIZE: 2.0× (local only)',205)
local keyBtn=button('CLIMB RETRY KEY (if required): E',250)
local growthBtn=button('EAGLE GROWTH CONFIG: OFF',295)
local carryBtn=button('EAGLE CARRY CONFIG: OFF',340)
local cooldownBtn=button('TALON COOLDOWN CONFIG: OFF',385)
local presetBtn=button('TUNING: BALANCED (3× GROWTH / 3× CARRY / 1.5s)',430)
local reloadBtn=button('REAPPLY LOCAL CONFIG TO LOADED MODULES',475)
local status=label('Starting…',523,94,12,colors.text)
local caveat=label('LOCAL ONLY: growth/carry/cooldown not server-verified. Infinite stamina is NOT included; previous v21 omitted it.',619,48,11,colors.warn)
local foot=label('RightShift: show/hide   |   End: close hub completely',673,18,10,colors.muted)
local function toggle(setting,b,prefix)
 app.settings[setting]=not app.settings[setting]
 b.Text=prefix..(app.settings[setting] and 'ON' or 'OFF')
end
on(escapeBtn.MouseButton1Click,function()toggle('escape',escapeBtn,'AUTO ESCAPE: ')end)
on(climbBtn.MouseButton1Click,function()toggle('climb',climbBtn,'EASIER TREE INTERACTION: ')end)
on(hitboxBtn.MouseButton1Click,function()toggle('hitbox',hitboxBtn,'LOCAL HITBOX EXPANSION: ')end)
on(scaleBtn.MouseButton1Click,function()
 local sizes={1.5,2,2.5,3,4};local ix=1
 for i,n in ipairs(sizes) do if math.abs(app.settings.scale-n)<.01 then ix=i end end
 app.settings.scale=sizes[ix%#sizes+1]
 scaleBtn.Text='HITBOX SIZE: '..app.settings.scale..'× (local only)'
end)
on(keyBtn.MouseButton1Click,function()
 local cycle={Enum.KeyCode.E,Enum.KeyCode.F,Enum.KeyCode.R,Enum.KeyCode.Q}
 local ix=1;for i,k in ipairs(cycle) do if app.settings.climbKey==k then ix=i end end
 app.settings.climbKey=cycle[ix%#cycle+1]
 keyBtn.Text='CLIMB RETRY KEY (if required): '..app.settings.climbKey.Name
end)

-- v21 mechanics: modify the actual locally cached configuration objects exposed by
-- ReplicatedStorage/FeralWorld. This does NOT modify ServerScriptService or the
-- authoritative state of the public game. Every changed key is snapshotted.
local originals=setmetatable({}, {__mode='k'})
local modules={}; local moduleErrors={}
local function captureAndSet(tbl,key,value)
 if type(tbl)~='table' or rawget(tbl,key)==nil then return false end
 local previous=originals[tbl]
 if not previous then previous={}; originals[tbl]=previous end
 if previous[key]==nil then previous[key]={value=rawget(tbl,key)} end
 local ok=pcall(function() tbl[key]=value end)
 return ok
end
local function restoreConfig()
 for tbl,keys in pairs(originals) do
  for key,entry in pairs(keys) do pcall(function()tbl[key]=entry.value end) end
 end
 originals=setmetatable({}, {__mode='k'})
end
local function getModules()
 local world=game:GetService('ReplicatedStorage'):FindFirstChild('FeralWorld')
 if not world then return false,'FeralWorld missing' end
 for _,name in ipairs({'GrowthConfig','Species','AbilityConfig','FlightConfig'}) do
  if not modules[name] then
   local node=world:FindFirstChild(name)
   if node and node:IsA('ModuleScript') then
    local ok,value=pcall(require,node)
    if ok and type(value)=='table' then modules[name]=value
    else moduleErrors[name]=ok and 'non-table module' or tostring(value) end
   else moduleErrors[name]='not found' end
  end
 end
 return true
end
local function eagleKey(value)
 -- This export calls the eagle species "Eagle"; leave unrelated species alone.
 return value and (value.Eagle or value.BaldEagle)
end
local changed=0
local function change(tbl,key,value)
 if captureAndSet(tbl,key,value) then changed=changed+1 end
end
local function applyConfig()
 restoreConfig()
 changed=0
 getModules()
 local g,s,a,f=modules.GrowthConfig,modules.Species,modules.AbilityConfig,modules.FlightConfig
 if app.settings.growth then
  -- Preserve stage thresholds; shorten only the eagle's local time scale.
  if type(g)=='table' then
   if type(g.ELDER_RATE)=='number' then change(g,'ELDER_RATE',g.ELDER_RATE*app.settings.growthFactor) end
   if type(g.CUB_BOOST)=='number' then change(g,'CUB_BOOST',math.max(g.CUB_BOOST,app.settings.growthFactor)) end
  end
  if type(s)=='table' then
   if type(s.ADULT_MINUTES)=='table' and type(s.ADULT_MINUTES.Eagle)=='number' then
    change(s.ADULT_MINUTES,'Eagle',math.max(0.5,s.ADULT_MINUTES.Eagle/app.settings.growthFactor))
   elseif type(s.List)=='table' and type(s.List.Eagle)=='table' and type(s.List.Eagle.growthMinutes)=='number' then
    change(s.List.Eagle,'growthMinutes',math.max(0.5,s.List.Eagle.growthMinutes/app.settings.growthFactor))
   end
  end
 end
 if app.settings.carry and type(a)=='table' and type(a.Talon)=='table' then
  change(a.Talon,'CARRY_RATIO',app.settings.carryRatio)
  change(a.Talon,'NO_ELDER_LIFT',false)
 end
 if app.settings.cooldown then
  if type(a)=='table' and type(a.Talon)=='table' then
   for _,key in ipairs({'FLAT_COOLDOWN','COOLDOWN','MISS_COOLDOWN'}) do
    if type(rawget(a.Talon,key))=='number' then change(a.Talon,key,app.settings.cooldownSeconds) end
   end
  end
  if type(f)=='table' and type(f.STOOP)=='table' then
   for _,key in ipairs({'CD_PICK','CD_CANCEL','CD_EMPTY'}) do
    if type(rawget(f.STOOP,key))=='number' then change(f.STOOP,key,app.settings.cooldownSeconds) end
   end
  end
 end
end
local function updateControls()
 growthBtn.Text='EAGLE GROWTH CONFIG: '..(app.settings.growth and 'ON' or 'OFF')
 carryBtn.Text='EAGLE CARRY CONFIG: '..(app.settings.carry and 'ON' or 'OFF')
 cooldownBtn.Text='TALON COOLDOWN CONFIG: '..(app.settings.cooldown and 'ON' or 'OFF')
end
on(growthBtn.MouseButton1Click,function()app.settings.growth=not app.settings.growth;applyConfig();updateControls()end)
on(carryBtn.MouseButton1Click,function()app.settings.carry=not app.settings.carry;applyConfig();updateControls()end)
on(cooldownBtn.MouseButton1Click,function()app.settings.cooldown=not app.settings.cooldown;applyConfig();updateControls()end)
local presetIndex=1
local presets={
 {title='BALANCED',growth=3,carry=3,cd=1.5},
 {title='MODERATE',growth=2,carry=2,cd=5},
 {title='MAX LOCAL',growth=6,carry=5,cd=0.25}
}
on(presetBtn.MouseButton1Click,function()
 presetIndex=presetIndex%#presets+1
 local p=presets[presetIndex]
 app.settings.growthFactor=p.growth
 app.settings.carryRatio=p.carry
 app.settings.cooldownSeconds=p.cd
 presetBtn.Text='TUNING: '..p.title..' ('..p.growth..'× / '..p.carry..'× / '..p.cd..'s)'
 applyConfig()
end)
on(reloadBtn.MouseButton1Click,function()applyConfig()end)
applyConfig()
updateControls()

local drag=false;local dragStart,frameStart,dragInput
on(panel.InputBegan,function(i)
 if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
  if i.Position.Y < panel.AbsolutePosition.Y+65 then
   drag=true;dragInput=i;dragStart=i.Position;frameStart=panel.Position
  end
 end
end)
on(UIS.InputChanged,function(i)
 if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i==dragInput) then
  local d=i.Position-dragStart
  panel.Position=UDim2.new(frameStart.X.Scale,frameStart.X.Offset+d.X,frameStart.Y.Scale,frameStart.Y.Offset+d.Y)
 end
end)
on(UIS.InputEnded,function(i) if i==dragInput then drag=false end end)
on(UIS.InputBegan,function(i,processed)
 if UIS:GetFocusedTextBox() then return end
  if i.KeyCode==Enum.KeyCode.RightShift then
    panel.Visible=not panel.Visible
    openButton.Visible=not panel.Visible
  elseif i.KeyCode==Enum.KeyCode.End then
    app:Destroy()
  end
end)
-- Store original instance properties; never mutate humanoid root ownership/network state.
local modified={}
local function restorePart(part)
 local orig=modified[part]
 if orig then
  if part and part.Parent then pcall(function()part.Size=orig.Size;part.Transparency=orig.Transparency;part.CanCollide=orig.CanCollide end) end
  modified[part]=nil
 end
end
local function restoreAll()
 for part in pairs(modified) do restorePart(part) end
end
local function updateHitboxes()
 if not app.settings.hitbox then restoreAll();return end
 local mine=root(char())
 if not mine then restoreAll();return end
 local active={}
 for _,other in ipairs(Players:GetPlayers()) do
  if other~=LocalPlayer then
   local model=other.Character
   local humanoid=model and model:FindFirstChildOfClass('Humanoid')
   local part=root(model)
   if part and part:IsA('BasePart') and humanoid and humanoid.Health>0 and (part.Position-mine.Position).Magnitude<=app.settings.radius then
    active[part]=true
    if not modified[part] then modified[part]={Size=part.Size,Transparency=part.Transparency,CanCollide=part.CanCollide} end
    local base=modified[part]
    pcall(function()
     part.Size=base.Size*app.settings.scale
     part.Transparency=1
     part.CanCollide=false
    end)
   end
  end
 end
 for part in pairs(modified) do if not active[part] then restorePart(part) end end
end
-- Observing grab signals is necessary: no space injection when not grabbed.
local grabNames={'IsCarried','BeingCarried','Grabbed','Held','Carried','IsGrabbed','IsHeld','PickedUp'}
local lastEscape=0;local grabDetected=false;local lastClimb=0;local bufferUntil=0;local lastProbe=0;local detectedPrompt=nil
local function isGrabbed()
 local c=char();if not c then return false end
 local v=attr(c,grabNames)
 if v==true then return true end
 local selfValue=attr(LocalPlayer,grabNames)
 if selfValue==true then return true end
 -- False or absent are not enough evidence to initiate escape.
 return false
end
local function nearbyClimbPrompt()
 local r=root(char());if not r then return nil end
 local best=nil;local nearest=app.settings.climbRadius
 for _,v in ipairs(workspace:GetDescendants()) do
  if v:IsA('ProximityPrompt') and v.Enabled then
   local action=(v.ActionText..' '..v.ObjectText..' '..v.Name):lower()
   if action:find('climb',1,true) or action:find('tree',1,true) or action:find('trunk',1,true) or action:find('vine',1,true) then
    local p=v.Parent
    local location=p and (p:IsA('Attachment') and p.WorldPosition or (p:IsA('BasePart') and p.Position or (p:IsA('Model') and p:GetPivot().Position)))
    if location then
     local distance=(location-r.Position).Magnitude
     if distance<=nearest and distance<=v.MaxActivationDistance+1 then best=v;nearest=distance end
    end
   end
  end
 end
 return best
end
local function attemptPrompt(prompt)
 if not prompt then return false end
 local ok=pcall(function()
  if type(fireproximityprompt)=='function' then fireproximityprompt(prompt)
  else
   prompt:InputHoldBegin()
   task.delay(math.max(.05,prompt.HoldDuration+.04),function()
    if app.alive and prompt.Parent then pcall(function() prompt:InputHoldEnd() end) end
   end)
  end
 end)
 if ok then app.stats.climbs=app.stats.climbs+1 end
 return ok
end
-- One ordinary climb-key press schedules a brief retry window, not a hold requirement.
on(UIS.InputBegan,function(input,processed)
 if processed or not notTyping() or not app.settings.climb then return end
 if input.KeyCode==app.settings.climbKey then bufferUntil=os.clock()+.55 end
end)
function app:Destroy()
 if not self.alive then return end
 self.alive=false
 restoreAll()
 restoreConfig()
 for _,c in ipairs(self.connections) do pcall(function()c:Disconnect()end) end
 if gui then gui:Destroy() end
 if env.FERAL_NOVA_PRIME_V21==self then env.FERAL_NOVA_PRIME_V21=nil end
  if env.FERAL_NOVA_PRIME_V22==self then env.FERAL_NOVA_PRIME_V22=nil end
end
on(close.MouseButton1Click,function() app:Destroy() end)
on(openButton.MouseButton1Click,function() panel.Visible=true;openButton.Visible=false end)
local lastTick=0;local lastUI=0
on(RunService.Heartbeat,function()
 if not app.alive then return end
 local now=os.clock()
 if now-lastTick>=.20 then
  lastTick=now
  updateHitboxes()
  if app.settings.climb and now-lastProbe>=.65 then lastProbe=now;detectedPrompt=nearbyClimbPrompt() end
 end
 grabDetected=isGrabbed()
 if app.settings.escape and grabDetected and notTyping() and now-lastEscape>=.09 then
  lastEscape=now;if tap('Space') then app.stats.escapes=app.stats.escapes+1 end
 end
 if app.settings.climb and notTyping() and now-lastClimb>=.45 then
  local r=root(char())
  local moving=r and Vector3.new(r.AssemblyLinearVelocity.X,0,r.AssemblyLinearVelocity.Z).Magnitude>2
  if detectedPrompt and (moving or now<bufferUntil) and not grabDetected then
   if attemptPrompt(detectedPrompt) then lastClimb=now end
  elseif now<bufferUntil then
   local k=app.settings.climbKey.Name
   if keys[k] and tap(k) then lastClimb=now end
  end
 end
 if now-lastUI>=.35 then
  lastUI=now
  local count=0;for _ in pairs(modified) do count=count+1 end
  local mode=inputMode=='none' and 'not available' or inputMode
  status.Text='Config fields modified: '..changed..'  |  Growth: '..(app.settings.growth and 'ON' or 'OFF')..'  Carry: '..(app.settings.carry and 'ON' or 'OFF')..'  CD: '..(app.settings.cooldown and 'ON' or 'OFF')..'\nGrab: '..(grabDetected and 'DETECTED' or 'not detected')..'  Escape inputs: '..app.stats.escapes..'  |  Climb tries: '..app.stats.climbs..'\nLocal hitboxes: '..count..'  |  Input API: '..mode..(inputError~='' and '\nInput error: '..inputError:sub(1,45) or '')
 end
end)
print('[FERAL NOVA PRIME v22] RightShift toggles; End closes. Infinite stamina not included. Local config tuning is not server verified.')