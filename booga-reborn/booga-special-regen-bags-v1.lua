-- Booga Reborn special regen bags availability check. Read-only.
local RS=game:GetService("ReplicatedStorage")
local P=game:GetService("Players")
local H=game:GetService("HttpService")
if game.PlaceId~=11729688377 or not P.LocalPlayer then return end
local function mod(...)
 local m=RS
 for _,s in ipairs({...}) do m=m and m:FindFirstChild(s) end
 if not m or not m:IsA("ModuleScript") then return nil end
 local ok,v=pcall(require,m)
 return ok and v or nil
end
local util=mod("Modules","util","gameUtil")
local items=mod("Modules","data","itemData")
local ids=mod("Modules","data","itemIDS")
local d=util and util.Data
if type(d)~="table" or type(items)~="table" then return end
local names={"Egg Bag","Skull Bag","Present Bag","Candy Bag","Easter Bag","Void Bag","Void Shroud","Jelly Sandwich","God Bag"}
local want={}
for _,n in ipairs(names) do want[n]=true end
local owned={}
local inventory=d.inventory
if type(inventory)=="table" then
 for _,entry in pairs(inventory) do
  if type(entry)=="table" and want[entry.name] then
   local q=tonumber(entry.quantity) or 1
   if q>=0 and q<100000 then owned[entry.name]=(owned[entry.name] or 0)+q end
  end
 end
end
local result={schema="booga-special-regen-bags-v1",level=d.level,
 equipped_bag=d.armor and d.armor.bag or nil,items={},
 scope="Read-only source definitions and owned eligible item counts. Does not send packets, equip or craft."}
for _,name in ipairs(names) do
 local def=items[name]
 local row={name=name,exists=type(def)=="table",owned=owned[name]or 0,
 id=type(ids)=="table" and ids[name] or nil}
 if type(def)=="table" then
  row.level=def.craftLevel
  row.mojo=def.mojoRecipe
  row.blacklisted=def.blacklisted
  row.type=def.itemType
  row.recipe={}
  if type(def.recipe)=="table" then
   for mat,amount in pairs(def.recipe) do
    if type(mat)=="string"and type(amount)=="number" then
     local matOwned=0
     if type(inventory)=="table" then
      for _,entry in pairs(inventory) do
       if type(entry)=="table" and entry.name==mat then
        matOwned+=tonumber(entry.quantity)or 1
       end
      end
     end
     row.recipe[mat]={need=amount,owned=matOwned}
    end
   end
  end
 end
 if util and type(util.canCraftItem)=="function" then
  local ok,value=pcall(util.canCraftItem,name,nil,true)
  row.can_craft_now=ok and value==true
 end
 result.items[#result.items+1]=row
end
if type(writefile)=="function" then
 pcall(function() writefile("booga_special_regen_bags_v1.json",H:JSONEncode(result))end)
end
warn("[BOOGA] read-only special regen bag report saved")
