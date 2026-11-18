-- Booga Booga Reborn | Regen Resource Scout v1
-- Read-only inventory and legitimate recipe/eligibility inspection. No gameplay packets.
local RS=game:GetService("ReplicatedStorage")
local P=game:GetService("Players")
local H=game:GetService("HttpService")
if not P.LocalPlayer then return end
local valid={[11729688377]=true,[11879754496]=true,[124322376658249]=true}
if not valid[game.PlaceId] then return end
local function requireFrom(...)
 local node=RS
 for _,part in ipairs({...})do node=node and node:FindFirstChild(part)end
 if not node or not node:IsA("ModuleScript")then return nil end
 local ok,result=pcall(require,node)
 return ok and result or nil
end
local util=requireFrom("Modules","util","gameUtil")
local itemData=requireFrom("Modules","data","itemData")
local d=util and util.Data
local names={
 "Void Greaves","Void Shroud","Void Chestplate","Void Bag",
 "Void Pouch","Candy Bag","Easter Bag","Skull Bag","Present Bag","Egg Bag",
 "Jelly Sandwich","Jelly","Void Shard","Magnetite","Magnetite Bar",
 "Obsidian","Gold","Crystal Chunk","God Bag",
}
local whitelist={}
for _,n in ipairs(names)do whitelist[n]=true end
local inventory={}
local total=0
if d and type(d.inventory)=="table"then
 for k,v in pairs(d.inventory)do
  if type(v)=="table"and type(v.name)=="string"then
   total+=1
   if whitelist[v.name]then
    if not inventory[v.name]then inventory[v.name]={quantity=0,keys={}}end
    local slot=inventory[v.name]
    local qty=type(v.quantity)=="number"and v.quantity or 1
    slot.quantity+=qty
    if #slot.keys<8 then slot.keys[#slot.keys+1]=k end
   end
  end
 end
end
local recipes={}
for _,n in ipairs(names)do
 local spec=itemData and itemData[n]
 if type(spec)=="table"and (n=="Void Shroud" or n=="Void Chestplate" or n=="Void Greaves" or n=="Void Bag" or n=="Jelly Sandwich" or n=="Candy Bag" or n=="Easter Bag" or n=="Skull Bag" or n=="Present Bag" or n=="Egg Bag")then
  local recipe={}
  if type(spec.recipe)=="table"then
   for k,v in pairs(spec.recipe)do
    if type(k)=="string" and type(v)=="number"then recipe[k]=v end
   end
  end
  local canCraft=nil
  if util and type(util.canCraftItem)=="function"then
   local ok,res=pcall(function()return util.canCraftItem(n,nil,true)end)
   if ok and type(res)=="boolean"then canCraft=res end
  end
  recipes[n]={recipe=recipe,level=spec.craftLevel,canCraft=canCraft,locus=spec.locus}
 end
end
local globalNames={}
local env
pcall(function()env=getgenv()end)
if type(env)=="table"then
 for k,_ in pairs(env)do
  if type(k)=="string"and (string.find(string.lower(k),"booga",1,true)or string.find(string.lower(k),"voodoo",1,true)or string.find(string.lower(k),"lightning",1,true))then
   if #globalNames<50 then globalNames[#globalNames+1]=k end
  end
 end
end
table.sort(globalNames)
local a=d and d.armor
local equipment={}
if type(a)=="table"then
 for _,k in ipairs({"head","torso","legs","bag"})do
  equipment[k]=a[k]
 end
end
local output={schema="booga-regen-scout-v1",place_id=game.PlaceId,
 level=d and d.level or nil,rebirths=d and d.rebirths or nil,
 spell=d and d.spell or nil,local_voodoo=d and d.voodoo or nil,
 spellmaster=d and type(d.mojoItems)=="table"and d.mojoItems.Spellmaster or nil,
 inventory_entries=total,ingredients_and_owned_items=inventory,crafting=recipes,
 equipment=equipment,debug_global_key_names=globalNames,
 limitation="Client-sourced inventory/recipes. canCraft is the UI check; actual server crafting is not attempted.",
 actions="No crafting, equipping, consuming, casting, stat edits, or personal file inspection."
}
if type(writefile)=="function"then
 pcall(function()writefile("booga_regen_resource_scout_v1.json",H:JSONEncode(output))end)
end
warn("[Booga Regen Scout] wrote read-only resources and recipe eligibility.")
