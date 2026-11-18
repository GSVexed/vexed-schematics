-- Booga Booga Reborn | Native Voodoo Laboratory v2.0
-- Experimental: reads only gameplay state and may send ONE ordinary Energy Bolt
-- to unoccupied air; never forges stats/boosts or sends repeated casts.
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local Local=Players.LocalPlayer
if not Local then return end
local ALLOW={[11729688377]=true,[11879754496]=true,[124322376658249]=true}
if not ALLOW[game.PlaceId] then warn("[Voodoo Lab] Not a supported Booga place");return end
local env
pcall(function()env=getgenv()end)
if type(env)~="table"then env=_G end
if type(env.__booga_native_monitor_stop)=="function"then pcall(env.__booga_native_monitor_stop)end
if type(env.__booga_lab_v2_stop)=="function"then pcall(env.__booga_lab_v2_stop)end
local function findMod(...)
 local x=RS
 for _,k in ipairs({...})do x=x and x:FindFirstChild(k)end
 if not x or not x:IsA("ModuleScript")then return nil end
 local ok,result=pcall(require,x)
 return ok and result or nil
end
local util=findMod("Modules","util","gameUtil")
local packets=findMod("Modules","util","packets")
local fun=findMod("Game","functions")
local t0=os.clock()
local running=true
local sampleAt=0
local saveAt=0
local lastVal=nil
local lastDrop=-100
local sockets={}
local samples={}
local events={}
local notes={}
local stats={incoming_reliable=0,incoming_unreliable=0,regen_gains=0,voodoo_drops=0,armor_updates=0,boosts_set=0,boosts_removed=0}
local trial={state="initialising",request_calls=0,request_errors=0,sent_at=nil,sent_initial_v=nil,low_after_send=nil}
local boosts={}
local boostAllow={["Voodoo Passive"]=true,["Void Armor"]=true,["Jelly Sandwich"]=true}
local invAllow={["Void Shroud"]=true,["Void Chestplate"]=true,["Void Greaves"]=true,["Void Bag"]=true,["Void Pouch"]=true,["Jelly Sandwich"]=true,["God Bag"]=true}
local function num(n)return type(n)=="number"and n==n and n>=-1e9 and n<1e9 end
local function data()
 local d=util and util.Data
 return type(d)=="table"and d or nil
end
local function gear()
 local d=data()
 local a=d and d.armor
 local out={}
 if type(a)=="table"then
  for _,key in ipairs({"head","torso","legs","bag"})do
   if type(a[key])=="string"then out[key]=a[key]end
  end
 end
 return out
end
local function owned()
 local d=data()
 local i=d and d.inventory
 local result={}
 if type(i)=="table"then
  for key,item in pairs(i)do
   if type(item)=="table"and invAllow[item.name]then
    local n=item.name
    local q=num(item.quantity)and item.quantity or 1
    if not result[n]then result[n]={quantity=0,indices={}}end
    result[n].quantity+=q
    if #result[n].indices<5 then
     result[n].indices[#result[n].indices+1]=key
    end
   end
  end
 end
 return result
end
local function log(kind,v)
 if #events>=350 then table.remove(events,1)end
 events[#events+1]={t=math.floor((os.clock()-t0)*10)/10,kind=kind,value=v}
end
local function listen(name,fn)
 local node=packets and packets[name]
 if not node or type(node.listen)~="function"then notes[#notes+1]="listener unavailable:"..name;return end
 local ok,connection=pcall(function()return node.listen(fn)end)
 if not ok then notes[#notes+1]="listener failed:"..name;return end
 sockets[#sockets+1]=connection
end
for _,record in ipairs({{"UpdateStats","incoming_reliable"},{"UpdateStatsUnreliable","incoming_unreliable"}})do
 local name,key=record[1],record[2]
 listen(name,function(packet)
  if not running then return end
  if type(packet)=="table"and num(packet.voodoo)then
   stats[key]+=1
   log(key,packet.voodoo)
  end
 end)
end
listen("SetBoost",function(packet)
 if not running or type(packet)~="table"or not boostAllow[packet.name]then return end
 stats.boosts_set+=1
 boosts[packet.name]={observed_at=os.clock()-t0,duration=num(packet.duration)and packet.duration or nil}
 log("server_boost_set",packet.name)
end)
listen("RemoveBoost",function(packet)
 if not running then return end
 local name=type(packet)=="table"and packet.name or packet
 if not boostAllow[name]then return end
 stats.boosts_removed+=1
 boosts[name]=nil
 log("server_boost_removed",name)
end)
listen("UpdateArmor",function()
 if not running then return end
 stats.armor_updates+=1
 log("server_armor_update",true)
end)
if not packets then notes[#notes+1]="Packets module missing"end
if not util then notes[#notes+1]="Game util module missing"end
local function report()
 local d=data()
 return {
  schema="booga-voodoo-lab-v2",place_id=game.PlaceId,
  elapsed_seconds=math.floor((os.clock()-t0)*10)/10,
  voodoo=d and d.voodoo or nil,
  spell=d and tostring(d.spell)or nil,
  spellmaster=d and type(d.mojoItems)=="table"and d.mojoItems.Spellmaster or nil,
  gear=gear(),owned_regen_items=owned(),boosts_received=boosts,stats=stats,
  trial=trial,samples=samples,events=events,notes=notes,
  source="Replicated game cache and server-origin stat/boost messages; no server source access.",
  no_cheat_claim="A successful request count is not proof of accepted damage or free regeneration."
 }
end
local function save()
 if type(writefile)~="function"then return end
 pcall(function()writefile("booga_voodoo_lab_v2.json",Http:JSONEncode(report()))end)
end
local heartbeat
local function stop()
 if not running then return end
 running=false
 save()
 if heartbeat then heartbeat:Disconnect()end
 for _,connection in ipairs(sockets)do
  if typeof(connection)=="RBXScriptConnection"then pcall(function()connection:Disconnect()end)
  elseif type(connection)=="function"then pcall(connection)end
 end
 if env.__booga_lab_v2_stop==stop then env.__booga_lab_v2_stop=nil end
end
env.__booga_lab_v2_stop=stop
local function maybeProbe()
 if trial.state~="initialising"then return end
 local now=os.clock()-t0
 if now<12 then return end
 local d=data()
 if not d or d.spell~="Energy Bolt"or not num(d.voodoo)then
  trial.state="skip: spell or native energy missing";return
 end
 if d.voodoo<90 then
  trial.state="skip: user already spending energy (observe only)";return
 end
 if lastDrop>=0 then
  trial.state="skip: recent Voodoo expenditure detected";return
 end
 local char=Local.Character
 local root=char and char:FindFirstChild("HumanoidRootPart")
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not root or not hum or hum.Health<=0 then
  trial.state="skip: character not ready";return
 end
 if not packets or not packets.VoodooSpell or type(packets.VoodooSpell.send)~="function"then
  trial.state="skip: spell request interface unavailable";return
 end
 for _,p in ipairs(Players:GetPlayers())do
  if p~=Local then
   local r=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
   if r and (r.Position-root.Position).Magnitude<170 then
    trial.state="skip: another player nearby";return
   end
  end
 end
 -- Deliberately target empty air well above the character, not at a person or mob.
 local target=root.Position+Vector3.new(0,105,0)
 local direction=(target-root.Position).Unit
 trial.sent_initial_v=d.voodoo
 trial.sent_at=now
 trial.state="one_air_cast_sent_awaiting_server"
 local ok,err=pcall(function()
  packets.VoodooSpell.send({targetPos=target,aimDirection=direction})
 end)
 if ok then trial.request_calls=1
 else
  trial.request_errors=1
  trial.state="send_error"
  notes[#notes+1]="Normal spell request failed: "..tostring(err):sub(1,100)
 end
 save()
end
heartbeat=Run.Heartbeat:Connect(function()
 if not running then return end
 local now=os.clock()
 local el=now-t0
 if now-sampleAt>=.5 then
  sampleAt=now
  local d=data()
  local v=d and d.voodoo
  if num(v)then
   if #samples>=1000 then table.remove(samples,1)end
   samples[#samples+1]={t=math.floor(el*10)/10,v=v}
   if num(lastVal)then
    if v<lastVal-.03 then
     lastDrop=el;stats.voodoo_drops+=1;log("drop",lastVal-v)
    elseif v>lastVal+.03 then
     stats.regen_gains+=1
    end
   end
   lastVal=v
   if trial.sent_at and trial.state=="one_air_cast_sent_awaiting_server"then
    trial.low_after_send=math.min(trial.low_after_send or v,v)
    if v<=trial.sent_initial_v-15 then trial.state="server_cost_seen_recovery_sampling"
    elseif el-trial.sent_at>9 then trial.state="no_cost_observed_air_cast_unverified"end
   elseif trial.state=="server_cost_seen_recovery_sampling"then
    trial.low_after_send=math.min(trial.low_after_send or v,v)
   end
  end
 end
 if trial.state=="initialising"then maybeProbe()end
 if trial.sent_at and el-trial.sent_at>=75 and trial.state=="server_cost_seen_recovery_sampling"then
  trial.state="server_cost_seen_observation_complete"
 end
 if now-saveAt>=3 then saveAt=now;save()end
 if el>560 then trial.monitor_finished=true;stop()end
end)
save()
warn("[Booga Voodoo Lab v2] Live game stat tracing started; one air-cast probe if safe. booga_voodoo_lab_v2.json")
