-- Booga Reborn: one-at-a-time remaining zero-cost special bolt selection tests.
-- User explicitly accepts the possibility of replacing Energy Bolt.
-- Three ordinary PromptSpellChoice requests MAX; stop immediately if selected spell changes.
local RS=game:GetService("ReplicatedStorage")
local Plrs=game:GetService("Players")
local Http=game:GetService("HttpService")
if game.PlaceId~=11729688377 or not Plrs.LocalPlayer then return end
local function mod(...)
 local p=RS
 for _,s in ipairs({...}) do p=p and p:FindFirstChild(s)end
 if not p or not p:IsA("ModuleScript") then return nil end
 local ok,value=pcall(require,p)
 return ok and value or nil
end
local util=mod("Modules","util","gameUtil")
local packets=mod("Modules","util","packets")
local ids=mod("Modules","data","itemIDS")
local defs=mod("Modules","data","itemData")
local d=util and util.Data
local candidates={
 {name="Rainbow Ray",id=89},
 {name="Equinox Bolt",id=353},
 {name="Bullet's Ray",id=144}
}
local t0=os.clock()
local r={schema="booga-zero-bolt-select-remaining-v1",place=game.PlaceId,
 status="PRECHECK",original_spell=d and d.spell or nil,final_spell=nil,
 requests=0,attempts={},scope="At most one send per special item; 8 sec of observation between requests; stop on any selection change. No spell cache edits, no casts, no listeners or inventory actions."}
local function snap()
 local data=util and util.Data
 return {t=math.floor((os.clock()-t0)*10)/10,
  spell=data and data.spell or nil,
  voodoo=data and data.voodoo or nil,
  level=data and data.level or nil}
end
local function save()
 if type(writefile)=="function"then
  pcall(function()writefile("booga_zero_bolts_remaining_v1.json",Http:JSONEncode(r))end)
 end
end
if not d or not packets or not ids or not defs
 or type(packets.PromptSpellChoice)~="table"
 or type(packets.PromptSpellChoice.send)~="function" then
 r.status="MISSING_MODULE";save();return
end
if d.spell~="Energy Bolt"then
 r.status="NO_LONGER_ENERGY_BOLT_ABORT";r.final_spell=d.spell;save();return
end
for _,candidate in ipairs(candidates)do
 local name,id=candidate.name,candidate.id
 local desc=defs[name]
 if ids[name]~=id or type(desc)~="table" or desc.blacklisted~=true
 or desc.voodooSpell~=false or desc.voodooCost~=0 then
  r.status="DEFINITION_MISMATCH_ABORT"
  r.final_spell=d.spell
  save()
  return
 end
end
r.status="TESTING";save()
for _,candidate in ipairs(candidates)do
 if d.spell~="Energy Bolt"then
  r.status="SELECTION_CHANGED_STOP"
  r.final_spell=d.spell
  save()
  break
 end
 local entry={name=candidate.name,id=candidate.id,before=snap(),after=nil,send_ok=false,send_error=nil,selected_during_window=false}
 r.attempts[#r.attempts+1]=entry
 local ok,err=pcall(function()
  packets.PromptSpellChoice.send(candidate.id)
 end)
 if not ok then
  entry.send_error=tostring(err):sub(1,150)
  r.status="SEND_ERROR_ABORT"
  entry.after=snap()
  r.final_spell=d.spell
  save()
  break
 end
 r.requests+=1
 entry.send_ok=true
 save()
 for i=1,9 do
  task.wait(1)
  entry.after=snap()
  if d.spell~="Energy Bolt"then
   entry.selected_during_window=true
   r.status="SELECTION_CHANGED_STOP"
   r.final_spell=d.spell
   save()
   break
  end
  save()
 end
 if r.status=="SELECTION_CHANGED_STOP"then break end
end
if r.status=="TESTING"then r.status="ALL_THREE_NO_SELECTION_CHANGE"end
r.final_spell=d.spell
save()
warn("[Booga bolt access] "..r.status)
