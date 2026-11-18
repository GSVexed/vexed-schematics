-- Booga Booga Reborn | Native Voodoo Laboratory v2.1
-- Passive client-cache observation. No packet subscriptions or outgoing requests.
-- The recovered ByteNet listen function replaces the native callback. Never subscribe here.
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
local t0=os.clock()
local running=true
local sampleAt=0
local saveAt=0
local lastVal=nil
local samples={}
local events={}
local notes={"If an older packet-listener monitor ran in this session, rejoin first; stopping it cannot restore the replaced native callbacks."}
local stats={regen_gains=0,voodoo_drops=0}
local trial={state="observe_only",request_calls=0,request_errors=0}
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
if not util then notes[#notes+1]="Game util module missing"end
local function report()
 local d=data()
 return {
  schema="booga-voodoo-lab-v2",revision="2.1",place_id=game.PlaceId,
  elapsed_seconds=math.floor((os.clock()-t0)*10)/10,
  voodoo=d and d.voodoo or nil,
  spell=d and tostring(d.spell)or nil,
  spellmaster=d and type(d.mojoItems)=="table"and d.mojoItems.Spellmaster or nil,
  gear=gear(),owned_regen_items=owned(),stats=stats,
  trial=trial,samples=samples,events=events,notes=notes,
  measurement={source="client_cache",packet_listeners_installed=false,incoming_packets_observed=false},
  source="Client cache only; native packets, actual server balance and damage are not independently verified.",
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
 if env.__booga_lab_v2_stop==stop then env.__booga_lab_v2_stop=nil end
end
env.__booga_lab_v2_stop=stop
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
     stats.voodoo_drops+=1;log("drop",lastVal-v)
    elseif v>lastVal+.03 then
     stats.regen_gains+=1
    end
   end
   lastVal=v
  end
 end
 if now-saveAt>=3 then saveAt=now;save()end
 if el>560 then trial.monitor_finished=true;stop()end
end)
save()
warn("[Booga Voodoo Lab v2.1] Passive cache sampling; rejoin first if an older listener monitor ran. booga_voodoo_lab_v2.json")
