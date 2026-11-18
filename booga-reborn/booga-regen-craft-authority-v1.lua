-- Booga Booga Reborn | Server Craft Authority Probe v1
-- A single existing CraftItem request for Void Shroud; validates actual inventory result.
-- No stat spoof, no fake item, no repeated requests, no item use or equipment changes.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local p=Players.LocalPlayer
if not p or game.PlaceId~=11729688377 then return end
local function mod(...)
 local o=RS
 for _,part in ipairs({...})do o=o and o:FindFirstChild(part)end
 if not o or not o:IsA("ModuleScript")then return nil end
 local ok,val=pcall(require,o)
 return ok and val or nil
end
local util=mod("Modules","util","gameUtil")
local packets=mod("Modules","util","packets")
local ids=mod("Modules","data","itemIDS")
local itemData=mod("Modules","data","itemData")
local name="Void Shroud"
local function amount(item)
 local d=util and util.Data
 local inv=d and d.inventory
 local v=0
 if type(inv)=="table"then
  for _,entry in pairs(inv)do
   if type(entry)=="table"and entry.name==item then
    v+=type(entry.quantity)=="number"and entry.quantity or 1
   end
  end
 end
 return v
end
local function nativeReport(data)
 if type(writefile)=="function"then
  pcall(function()writefile("booga_void_shroud_craft_authority_v1.json",Http:JSONEncode(data))end)
 end
end
local d=util and util.Data
local output={schema="booga-craft-authority-v1",place_id=game.PlaceId,
 name=name,level=d and d.level or nil,
 requirements=itemData and itemData[name] and itemData[name].recipe or nil,
 starting_inventory_count=amount(name),
 initial_armor=d and d.armor and d.armor.head or nil,
 sent=false,status="NOT_STARTED"}
if not packets or not packets.CraftItem or type(packets.CraftItem.send)~="function"or not ids or type(ids[name])~="number"then
 output.status="CRAFT_PACKET_OR_ITEM_ID_UNAVAILABLE";nativeReport(output);return
end
if output.starting_inventory_count>0 then
 output.status="SKIP_ITEM_ALREADY_OWNED";nativeReport(output);return
end
if type(d)~="table"or d.level>=100 then
 output.status="SKIP_DIFFERENT_START_CONDITION";nativeReport(output);return
end
local pre={Jelly=amount("Jelly"),Magnetite=amount("Magnetite"),["Void Shard"]=amount("Void Shard")}
output.materials=pre
local ok,err=pcall(function()packets.CraftItem.send(ids[name])end)
output.sent=ok
if not ok then
 output.status="SEND_ERROR";output.error_kind=tostring(err):sub(1,120)
 nativeReport(output);return
end
output.status="AWAITING_NATIVE_INVENTORY"
nativeReport(output)
task.delay(8,function()
 output.after_inventory_count=amount(name)
 local curr=util and util.Data
 output.after_armor=curr and curr.armor and curr.armor.head or nil
 output.after_materials={Jelly=amount("Jelly"),Magnetite=amount("Magnetite"),["Void Shard"]=amount("Void Shard")}
 if output.after_inventory_count>output.starting_inventory_count then
  output.status="SERVER_ITEM_ADDED_NEEDS_REPRODUCTION"
 else
  output.status="NO_SERVER_ITEM_GRANTED"
 end
 nativeReport(output)
end)
