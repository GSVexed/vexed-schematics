-- Booga Voodoo Native Telemetry v1: observational, no client stat edits or outgoing packets.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Http=game:GetService("HttpService")
local player=Players.LocalPlayer
if not player then return end
local env
pcall(function() env=getgenv() end)
if type(env)~="table" then env=_G end
if type(env.__booga_native_monitor_stop)=="function" then pcall(env.__booga_native_monitor_stop)end
local function req(a,b,c)
 local x=RS
 for _,s in ipairs({a,b,c})do x=x and x:FindFirstChild(s)end
 if not (x and x:IsA("ModuleScript"))then return nil end
 local ok,r=pcall(require,x)
 if ok then return r end
 return nil
end
local util=req("Modules","util","gameUtil")
local packets=req("Modules","util","packets")
local start=os.clock()
local live=true
local sampleAt=0
local saveAt=0
local lastV=nil
local links={}
local notes={}
local snaps={}
local events={}
local boost={}
local count={update_stats=0,unreliable_stats=0,boost_set=0,boost_removed=0,armor_updates=0,observed_increases=0,observed_decreases=0}
local validBoost={["Voodoo Passive"]=true,["Jelly Sandwich"]=true,["Void Armor"]=true}
local function number(x)return type(x)=="number" and x==x and math.abs(x)<1e9 end
local function value()
 local d=util and util.Data
 return type(d)=="table" and d or nil
end
local function push(kind,x,meta)
 if #events>=250 then table.remove(events,1)end
 events[#events+1]={t=math.floor((os.clock()-start)*10)/10,k=kind,v=x,m=meta}
end
local function subscribe(name,callback)
 local p=packets and packets[name]
 if not p or type(p.listen)~="function"then notes[#notes+1]="Missing listener: "..name;return end
 local ok,link=pcall(function()return p.listen(callback)end)
 if not ok then notes[#notes+1]=name.." listener failed";return end
 links[#links+1]=link
end
for _,pair in ipairs({{"UpdateStats","update_stats"},{"UpdateStatsUnreliable","unreliable_stats"}})do
 local name,key=pair[1],pair[2]
 subscribe(name,function(payload)
  if not live then return end
  local v=type(payload)=="table" and payload.voodoo
  if number(v)then count[key]+=1;push(key,v)end
 end)
end
subscribe("SetBoost",function(payload)
 if not live or type(payload)~="table" or not validBoost[payload.name]then return end
 local n=payload.name
 boost[n]={duration=number(payload.duration)and payload.duration or nil,percent=number(payload.percent)and payload.percent or nil,seen_t=os.clock()-start}
 count.boost_set+=1
 push("server_boost_set",n)
end)
subscribe("RemoveBoost",function(payload)
 if not live then return end
 local n=type(payload)=="table" and payload.name or payload
 if type(n)~="string" or not validBoost[n]then return end
 boost[n]=nil
 count.boost_removed+=1
 push("server_boost_removed",n)
end)
subscribe("UpdateArmor",function(payload)
 if not live then return end
 count.armor_updates+=1
 push("server_armor_update",true)
end)
if not util then notes[#notes+1]="Game utility module not available"end
if not packets then notes[#notes+1]="Packet definitions not available"end
if type(writefile)~="function"then notes[#notes+1]="Executor writefile not supported"end
local function snapshot()
 local d=value()
 local armor={}
 if d and type(d.armor)=="table"then
  for _,k in ipairs({"head","torso","legs","bag"})do
   if type(d.armor[k])=="string"then armor[k]=d.armor[k]end
  end
 end
 local tier=d and type(d.mojoItems)=="table"and d.mojoItems.Spellmaster or nil
 return {schema="booga-voodoo-native-v1",elapsed_s=math.floor((os.clock()-start)*10)/10,
  place_id=game.PlaceId,voodoo=d and d.voodoo or nil,spell=tostring(d and d.spell or ""),
  spellmaster=tier,armor=armor,boosts_observed=boost,
  counters=count,events=events,samples=snaps,notes=notes,
  scope="Native cache and incoming listeners only. No forged boosts or Voodoo. No outgoing game packets."}
end
local function persist()
 if type(writefile)~="function"then return end
 local ok,e=pcall(function()
  writefile("booga_voodoo_native_v1.json",Http:JSONEncode(snapshot()))
 end)
 if not ok then
  if #notes<10 then notes[#notes+1]="writefile failed: "..tostring(e):sub(1,140)end
 end
end
local hb
local function stop()
 if not live then return end
 live=false
 persist()
 if hb then hb:Disconnect()end
 for _,link in ipairs(links)do
  if typeof(link)=="RBXScriptConnection"then pcall(function()link:Disconnect()end)
  elseif type(link)=="function"then pcall(link)end
 end
 if env.__booga_native_monitor_stop==stop then env.__booga_native_monitor_stop=nil end
end
env.__booga_native_monitor_stop=stop
hb=Run.Heartbeat:Connect(function()
 if not live then return end
 local t=os.clock()
 if t-sampleAt>=.5 then
  sampleAt=t
  local d=value()
  local v=d and d.voodoo
  if number(v)then
   if #snaps>=900 then table.remove(snaps,1)end
   snaps[#snaps+1]={t=math.floor((t-start)*10)/10,v=v}
   if number(lastV) and v>lastV+.01 then count.observed_increases+=1
   elseif number(lastV) and v<lastV-.01 then count.observed_decreases+=1;push("energy_spent",lastV-v)end
   lastV=v
  end
 end
 if t-saveAt>=4 then saveAt=t;persist()end
 if t-start>=420 then stop()end
end)
persist()
warn("[VOODOO NATIVE v1] read-only audit running; telemetry: booga_voodoo_native_v1.json")
