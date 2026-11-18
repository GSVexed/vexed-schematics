-- Booga Voodoo Native Telemetry v1.1: passive client-cache sampling only.
-- The recovered ByteNet listen function replaces the native callback. Never subscribe here.
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
local start=os.clock()
local live=true
local sampleAt=0
local saveAt=0
local lastV=nil
local notes={"If an older packet-listener monitor ran in this session, rejoin first; stopping it cannot restore the replaced native callbacks."}
local snaps={}
local events={}
local count={observed_increases=0,observed_decreases=0}
local function number(x)return type(x)=="number" and x==x and math.abs(x)<1e9 end
local function value()
 local d=util and util.Data
 return type(d)=="table" and d or nil
end
local function push(kind,x,meta)
 if #events>=250 then table.remove(events,1)end
 events[#events+1]={t=math.floor((os.clock()-start)*10)/10,k=kind,v=x,m=meta}
end
if not util then notes[#notes+1]="Game utility module not available"end
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
 return {schema="booga-voodoo-native-v1",revision="1.1",elapsed_s=math.floor((os.clock()-start)*10)/10,
  place_id=game.PlaceId,voodoo=d and d.voodoo or nil,spell=tostring(d and d.spell or ""),
  spellmaster=tier,armor=armor,
  counters=count,events=events,samples=snaps,notes=notes,
  measurement={source="client_cache",packet_listeners_installed=false,incoming_packets_observed=false},
  scope="Client cache only. Native packets, actual server balance and damage are not independently verified. No outgoing game packets."}
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
warn("[VOODOO NATIVE v1.1] Passive cache sampling; rejoin first if an older listener monitor ran. booga_voodoo_native_v1.json")
