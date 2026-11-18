-- Booga Booga Reborn: zero-cost bolt entitlement audit (read only).
-- No packet listeners, outgoing requests, local value writes or UI interactions.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local localPlayer=Players.LocalPlayer
if not localPlayer or game.PlaceId~=11729688377 then return end
local function getMod(...)
 local m=RS
 for _,name in ipairs({...}) do m=m and m:FindFirstChild(name) end
 if not m or not m:IsA("ModuleScript") then return nil end
 local ok,r=pcall(require,m)
 return ok and r or nil
end
local util=getMod("Modules","util","gameUtil")
local items=getMod("Modules","data","itemData")
local itemIds=getMod("Modules","data","itemIDS")
local data=util and util.Data
local spell=data and data.spell
local unlocked=data and data.unlockedSpells
local gui=localPlayer:FindFirstChildOfClass("PlayerGui")
local list=nil
pcall(function() list=gui.MainGui.Panels.VoodooSelect.List end)
local names={"Energy Bolt","Bullet's Ray","God's Bolt","Rainbow Ray","Equinox Bolt"}
local out={schema="booga-bolt-entitlements-v1",place=game.PlaceId,selected_spell=type(spell)=="string"and spell or nil,unlocked_kind=type(unlocked),candidates={},
 scope="No packets, listener registrations, UI changes, spell changes, item changes or gameplay input."}
for _,n in ipairs(names)do
 local def=items and items[n] or nil
 local row={name=n,definition_found=type(def)=="table",item_id=itemIds and itemIds[n]or nil,
 unlocked_raw=(type(unlocked)=="table" and unlocked[n])or nil,
 appears_in_choice_gui=false,choice_visible=false}
 if type(def)=="table"then
  row.voodoo_cost=def.voodooCost
  row.damage=def.damage
  row.blacklisted=def.blacklisted==true
  row.voodoo_spell=def.voodooSpell==true
 end
 if list then
  local a=list:FindFirstChild(n)
  if a then row.appears_in_choice_gui=true;row.choice_visible=a.Visible end
 end
 out.candidates[#out.candidates+1]=row
end
if type(writefile)=="function" then
 pcall(function()writefile("booga_bolt_entitlements_v1.json",Http:JSONEncode(out))end)
end
warn("[Booga] zero-cost bolt entitlement survey saved; no requests made.")
