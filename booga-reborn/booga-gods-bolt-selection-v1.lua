-- Booga Reborn: ONE controlled God's Bolt selection authority test.
-- User explicitly accepted risk of replacing their selected Energy Bolt.
-- Exactly one PromptSpellChoice.send(354); no additional packets or casts.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local lp=Players.LocalPlayer
if not lp or game.PlaceId~=11729688377 then return end
local function fetch(...)
 local v=RS
 for _,part in ipairs({...}) do v=v and v:FindFirstChild(part) end
 if not v or not v:IsA("ModuleScript") then return nil end
 local ok,m=pcall(require,v)
 return ok and m or nil
end
local util=fetch("Modules","util","gameUtil")
local packets=fetch("Modules","util","packets")
local ids=fetch("Modules","data","itemIDS")
local defs=fetch("Modules","data","itemData")
local name="God's Bolt"
local d=util and util.Data
local started=os.clock()
local log={schema="booga-gods-bolt-selection-v1",place=game.PlaceId,
 selected_before=d and d.spell or nil,selected_after=nil,
 request_count=0,payload_item_id=nil,status="PRECHECK",elapsed=0,
 observations={},notes={},scope="Single normal PromptSpellChoice request; no local spell mutation, no casts, no packet listeners, no item uses or rebirth."}
local function snapshot(phase)
 local v=util and util.Data
 local selected=v and v.spell or nil
 local energy=v and v.voodoo or nil
 local unlock=v and v.unlockedSpells
 local granted=type(unlock)=="table" and unlock[name] or nil
 local ob={phase=phase,t=math.floor((os.clock()-started)*10)/10,selected=selected,voodoo=energy,unlocked=granted==true}
 if #log.observations<45 then log.observations[#log.observations+1]=ob end
 log.selected_after=selected
 log.elapsed=ob.t
end
local function save()
 if type(writefile)~="function" then return end
 pcall(function()
  writefile("booga_gods_bolt_selection_v1.json",Http:JSONEncode(log))
 end)
end
snapshot("before")
save()
if not (d and packets and ids and defs and type(packets.PromptSpellChoice)=="table"
  and type(packets.PromptSpellChoice.send)=="function") then
 log.status="MISSING_MODULE_OR_PACKET";save();return
end
if d.spell~="Energy Bolt" then
 log.status="PRECHECK_SPELL_NOT_ENERGY_BOLT";save();return
end
local record=defs[name]
if type(record)~="table" or ids[name]~=354
 or record.voodooCost~=0 or record.blacklisted~=true
 or record.voodooSpell~=false then
 log.status="DEFINITION_MISMATCH_ABORT";save();return
end
-- The player accepts the risk of selection being irreversible until rebirth.
log.payload_item_id=ids[name]
log.status="SENDING_ONE_REQUEST"
save()
local ok,err=pcall(function()
 packets.PromptSpellChoice.send(ids[name])
end)
if not ok then
 log.status="LOCAL_SEND_ERROR"
 log.notes[#log.notes+1]=tostring(err):sub(1,180)
 save()
 return
end
log.request_count=1
log.status="REQUEST_SENT_CHECKING_SELECTION"
save()
for step=1,19 do
 task.wait(1)
 snapshot("after_"..tostring(step))
 if log.selected_after==name then
  log.status="CLIENT_SELECTION_CHANGED_TO_GODS_BOLT"
  save()
  break
 end
 save()
end
if log.status=="REQUEST_SENT_CHECKING_SELECTION" then
 log.status="NO_SELECTION_CHANGE_WITHIN_19_SECONDS"
 save()
end
warn("[Booga] God's Bolt selection request audited: "..log.status)
