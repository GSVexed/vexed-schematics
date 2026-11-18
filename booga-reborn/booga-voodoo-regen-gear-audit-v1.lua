-- Booga Reborn: read-only genuine Voodoo gear/crafting eligibility audit.
-- Does not send any game packets, interact with inventory, or consume materials.
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
if game.PlaceId~=11729688377 then return end
local function mod(...)
 local node=RS
 for _,s in ipairs({...}) do node=node and node:FindFirstChild(s)end
 if not node or not node:IsA("ModuleScript") then return nil end
 local ok,value=pcall(require,node)
 return ok and value or nil
end
local util=mod("Modules","util","gameUtil")
local itemData=mod("Modules","data","itemData")
local data=util and util.Data
if type(data)~="table" then return end
local wanted={"Void Bag","Void Shroud","Void Chestplate","Void Greaves","Candy Bag","Easter Bag","Jelly Sandwich"}
local inventoryCounts={}
local whitelist={["Void Bag"]=true,["Void Shroud"]=true,["Void Chestplate"]=true,["Void Greaves"]=true,["Candy Bag"]=true,["Easter Bag"]=true,["Jelly Sandwich"]=true,["Void Shard"]=true,["Magnetite"]=true,["Jelly"]=true,["God Bag"]=true,["Crystal Chunk"]=true,["Gold"]=true,["Bread"]=true,["Meat"]=true}
local inv=data.inventory
local inventoryEntryCount=0
if type(inv)=="table"then
 for _,entry in pairs(inv) do
  if type(entry)=="table" and type(entry.name)=="string" then
   inventoryEntryCount+=1
   local n=entry.name
   if whitelist[n] then
    local quantity=tonumber(entry.quantity) or 1
    if quantity>=0 and quantity<1e8 then inventoryCounts[n]=(inventoryCounts[n]or 0)+quantity end
   end
  end
 end
end
local rows={}
for _,name in ipairs(wanted)do
 local def=itemData and itemData[name]
 local row={name=name,exists=type(def)=="table",owned=inventoryCounts[name]or 0}
 if type(def)=="table" then
  row.craft_level=def.craftLevel
  row.mojo_required=def.mojoRecipe==true
  row.item_type=def.itemType
  row.locus=def.locus
  row.ingredients={}
  if type(def.recipe)=="table" then
   for k,v in pairs(def.recipe) do
    if type(k)=="string" and type(v)=="number" then row.ingredients[k]={need=v,owned=inventoryCounts[k]or 0} end
   end
  end
 end
 if util and type(util.canCraftItem)=="function"then
  local ok,result=pcall(util.canCraftItem,name,nil,true)
  row.client_can_craft=ok and (result==true) or false
  if not ok then row.craft_query_error="client utility error" end
 end
 rows[#rows+1]=row
end
local armor={}
if type(data.armor)=="table"then
 for _,slot in ipairs({"head","torso","legs","bag"}) do
  if type(data.armor[slot])=="string" then armor[slot]=data.armor[slot]end
 end
end
local result={
 schema="booga-voodoo-regen-gear-v1",place_id=game.PlaceId,level=data.level,
 inventory_entry_count=inventoryEntryCount,whitelisted_inventory=inventoryCounts,
 spellmaster=type(data.mojoItems)=="table" and data.mojoItems.Spellmaster or nil,
 equipped=armor,recipes=rows,
 scope="Only allowlisted inventory counts, recipes and craft eligibility; no outgoing game packets or purchases."}
local saved=false
if type(writefile)=="function"then
 saved=pcall(function()writefile("booga_voodoo_gear_v1.json",Http:JSONEncode(result))end)
end
warn("[Booga Gear Audit] "..(saved and "Saved booga_voodoo_gear_v1.json" or "Report not saved"))
