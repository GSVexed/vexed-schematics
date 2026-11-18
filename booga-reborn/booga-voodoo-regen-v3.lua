-- Booga Reborn: native Voodoo state authority audit v3.
-- NO outgoing game packets, no UI changes, no inventory uses, no automatic input.
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local lp=Players.LocalPlayer
if game.PlaceId~=11729688377 or not lp then return end
local env
pcall(function() env=getgenv() end)
if type(env)~="table" then env=_G end
for _,key in ipairs({"__booga_native_monitor_stop","__booga_lab_v2_stop","__booga_regen_v3_stop"}) do
 if type(env[key])=="function" then pcall(env[key]) end
end
local function module(...)
 local p=RS
 for _,seg in ipairs({...}) do p=p and p:FindFirstChild(seg) end
 if not p or not p:IsA("ModuleScript") then return nil end
 local ok,mod=pcall(require,p)
 return ok and mod or nil
end
local util=module("Modules","util","gameUtil")
local packets=module("Modules","util","packets")
local t0=os.clock()
local active=true
local samples={}
local events={}
local counts={reliable=0,unreliable=0,stat_reconciled=0,stat_not_reconciled=0,boosts=0,armor=0,spending=0,gains=0}
local notes={}
local lastNative=nil
local lastSample=0
local lastSave=0
local subs={}
local state={native=nil,native_received_at=nil}
local function numeric(v) return type(v)=="number" and v==v and math.abs(v)<100000 end
local function getData()
 local d=util and util.Data
 return type(d)=="table" and d or nil
end
local function emit(k,data)
 if #events>=850 then table.remove(events,1) end
 events[#events+1]={t=math.floor((os.clock()-t0)*100)/100,kind=k,value=data}
end
local function native(name,payload)
 if not active or type(payload)~="table" or not numeric(payload.voodoo) then return end
 counts[name]+=1
 local v=payload.voodoo
 if numeric(lastNative) then
  if v<lastNative-3 then counts.spending+=1
  elseif v>lastNative+.05 then counts.gains+=1 end
 end
 lastNative=v
 state.native=v
 state.native_received_at=os.clock()-t0
 local d=getData()
 local localV=d and d.voodoo
 local uiText=nil
 pcall(function()uiText=lp.PlayerGui.MainGui.Panels.Stats.Bars.Voodoo.ValueLabel.Text end)
 emit("incoming_voodoo",{native=v,cache=localV,ui=type(uiText)=="string" and uiText:sub(1,24) or nil})
 task.delay(0.15,function()
  if not active then return end
  local newData=getData()
  local cache=newData and newData.voodoo
  if numeric(cache) and math.abs(cache-v)<1 then
   counts.stat_reconciled+=1
  else
   counts.stat_not_reconciled+=1
   if counts.stat_not_reconciled<=10 then
    emit("cache_mismatch",{native=v,cache=cache})
   end
  end
 end)
end
local function listen(name,callback)
 local p=packets and packets[name]
 if not p or type(p.listen)~="function" then notes[#notes+1]="missing listener:"..name;return end
 local ok,conn=pcall(function() return p.listen(callback) end)
 if ok then subs[#subs+1]=conn else notes[#notes+1]="listen error:"..name end
end
listen("UpdateStats",function(p) native("reliable",p) end)
listen("UpdateStatsUnreliable",function(p) native("unreliable",p) end)
listen("SetBoost",function(p)
 if not active then return end
 if type(p)=="table" and type(p.name)=="string" and (p.name=="Voodoo Passive" or p.name=="Void Armor" or p.name=="Jelly Sandwich") then
  counts.boosts+=1
  emit("genuine_boost_notification",{name=p.name,duration=p.duration,percent=p.percent})
 end
end)
listen("RemoveBoost",function(p)
 if not active then return end
 local n=type(p)=="table" and p.name or p
 if n=="Voodoo Passive" or n=="Void Armor" or n=="Jelly Sandwich" then emit("genuine_boost_removed",n) end
end)
listen("UpdateArmor",function() if active then counts.armor+=1;emit("armor_changed",true) end end)
local function safeGear()
 local d=getData()
 local a=d and d.armor
 if type(a)~="table" then return {} end
 local ret={}
 for _,slot in ipairs({"head","torso","legs","bag"})do
  if type(a[slot])=="string" then ret[slot]=a[slot] end
 end
 return ret
end
local function report()
 local d=getData()
 local uiText=nil
 pcall(function()uiText=lp.PlayerGui.MainGui.Panels.Stats.Bars.Voodoo.ValueLabel.Text end)
 return {schema="booga-voodoo-regen-v3",place_id=game.PlaceId,t=os.clock()-t0,
  native_voodoo=state.native,native_last_seen_s=state.native_received_at,
  cache_voodoo=d and d.voodoo or nil,ui_voodoo_text=type(uiText)=="string" and uiText:sub(1,30) or nil,
  selected_spell=d and d.spell or nil,spellmaster=d and d.mojoItems and d.mojoItems.Spellmaster or nil,
  gear=safeGear(),samples=samples,events=events,counters=counts,notes=notes,
  scope="Read-only native Voodoo packet vs local cache and GUI; no cast requests, stat writes, item consumption or UI interaction."}
end
local function save()
 if type(writefile)~="function" then return end
 local ok=pcall(function()writefile("booga_voodoo_regen_v3.json",Http:JSONEncode(report()))end)
 if not ok and #notes<10 then notes[#notes+1]="writefile failure" end
end
local hb
local function stop()
 if not active then return end
 active=false
 save()
 if hb then hb:Disconnect()end
 for _,conn in ipairs(subs)do
  if typeof(conn)=="RBXScriptConnection" then pcall(function()conn:Disconnect()end)
  elseif type(conn)=="function" then pcall(conn) end
 end
 if env.__booga_regen_v3_stop==stop then env.__booga_regen_v3_stop=nil end
end
env.__booga_regen_v3_stop=stop
hb=Run.Heartbeat:Connect(function()
 if not active then return end
 local now=os.clock()
 if now-lastSample>=.25 then
  lastSample=now
  local d=getData()
  local v=d and d.voodoo
  local n=state.native
  if numeric(v) or numeric(n) then
   if #samples>=850 then table.remove(samples,1)end
   samples[#samples+1]={t=math.floor((now-t0)*10)/10,cache=numeric(v)and v or nil,native=numeric(n)and n or nil}
  end
 end
 if now-lastSave>=3 then lastSave=now;save()end
 if now-t0>=180 then stop()end
end)
save()
warn("[Booga Voodoo v3] read-only authority audit active; report booga_voodoo_regen_v3.json")
