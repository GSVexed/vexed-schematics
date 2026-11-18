-- Booga Reborn: one-shot server crafting validation of Void Shroud.
-- This sends exactly ONE ordinary CraftItem request while lacking the documented
-- level and resources; never modifies client inventory or fabricates Voodoo.
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local Plrs=game:GetService("Players")
if game.PlaceId~=11729688377 then return end
local p=Plrs.LocalPlayer
if not p then return end
local function mod(...)
 local m=RS
 for _,name in ipairs({...}) do m=m and m:FindFirstChild(name)end
 if not m or not m:IsA("ModuleScript") then return nil end
 local ok,v=pcall(require,m)
 return ok and v or nil
end
local util=mod("Modules","util","gameUtil")
local ids=mod("Modules","data","itemIDS")
local defs=mod("Modules","data","itemData")
local packets=mod("Modules","util","packets")
local d=util and util.Data
local rec=defs and defs["Void Shroud"]
local want="Void Shroud"
local snap=function()
 local output={owned=0,ingredients={},level=d and d.level or nil,head=d and d.armor and d.armor.head or nil}
 local keys={Jelly=true,Magnetite=true,["Void Shard"]=true,["Void Shroud"]=true}
 local inv=d and d.inventory
 if type(inv)=="table"then
  for _,v in pairs(inv)do
   if type(v)=="table"and keys[v.name]then
    local q=tonumber(v.quantity)or 1
    if v.name==want then output.owned+=q else output.ingredients[v.name]=(output.ingredients[v.name]or 0)+q end
   end
  end
 end
 return output
end
local before=snap()
local report={schema="booga-void-shroud-craft-boundary-v1",
 place_id=game.PlaceId,before=before,after=nil,request_count=0,
 response_item_adds=0,response_item_changes=0,errors={},
 status="PRECHECK",scope="One normal CraftItem request only. No stat cache edits, no item writes, no repeated requests or auto equip."}
local function save()
 if type(writefile)=="function"then
  pcall(function()writefile("booga_void_craft_boundary_v1.json",Http:JSONEncode(report))end)
 end
end
local connections={}
local function listen(name,callback)
 local node=packets and packets[name]
 if type(node)=="table"and type(node.listen)=="function"then
  local ok,connection=pcall(function()return node.listen(callback)end)
  if ok then connections[#connections+1]=connection end
 end
end
local function done()
 report.after=snap()
 if report.after.owned>before.owned and report.request_count==1 then
  report.status="INVENTORY_GAIN_OBSERVED_CAUSALITY_UNPROVEN"
 elseif report.request_count==1 then
  report.status="CRAFT_REQUEST_DID_NOT_ADD_ITEM"
 end
 save()
 for _,connection in ipairs(connections)do
  if typeof(connection)=="RBXScriptConnection"then pcall(function()connection:Disconnect()end)
  elseif type(connection)=="function"then pcall(connection)end
 end
end
local char=p.Character
local hum=char and char:FindFirstChildOfClass("Humanoid")
if not hum or hum.Health<=0 then report.status="NOT_ALIVE";save();return end
if not (d and type(d.inventory)=="table" and type(rec)=="table" and type(rec.recipe)=="table" and type(ids)=="table" and type(ids[want])=="number") then
 report.status="MISSING_DOCUMENTED_RECIPE_OR_PROTOCOL";save();return
end
if before.owned>0 then report.status="ITEM_ALREADY_OWNED";save();return end
if before.level==nil or before.level>=rec.craftLevel then report.status="LEVEL_REQUIREMENT_NOT_UNMET";save();return end
local actualCraft
if util and type(util.canCraftItem)=="function"then
 local ok,v=pcall(util.canCraftItem,want,nil,false)
 actualCraft=ok and v==true
end
report.client_can_craft=actualCraft
if actualCraft~=false then report.status="PRECHECK_FAILED_OR_ELIGIBLE";save();return end
if not(packets and packets.CraftItem and type(packets.CraftItem.send)=="function")then
 report.status="CRAFT_INTERFACE_UNAVAILABLE";save();return
end
listen("ItemAdded",function() report.response_item_adds+=1 end)
listen("ItemChanged",function() report.response_item_changes+=1 end)
local ok,err=pcall(function()packets.CraftItem.send(ids[want])end)
if ok then report.request_count=1;report.status="REQUEST_SENT_AWAITING_RESULT"
else report.status="REQUEST_ERROR";report.errors[#report.errors+1]=tostring(err):sub(1,140)end
save()
task.delay(9,done)
