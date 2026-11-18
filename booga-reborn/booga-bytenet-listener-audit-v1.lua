-- Booga: read-only ByteNet listener ownership audit.
-- No packet listeners registered, no outgoing packets, no game-state edits.
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local Players=game:GetService("Players")
if game.PlaceId~=11729688377 then return end
local ok,packets=pcall(require,RS.Modules.util.packets)
if not ok or type(packets)~="table" then return end
local successful,data=pcall(require,RS.Modules.util.gameUtil)
local cache=successful and type(data)=="table" and data.Data or nil
local labels={}
local p=Players.LocalPlayer
if p then
 pcall(function()
  labels.voodoo=p.PlayerGui.MainGui.Panels.Stats.Bars.Voodoo.ValueLabel.Text
 end)
end
local out={schema="booga-bytenet-listener-audit-v1",place=game.PlaceId,cache_voodoo=cache and cache.voodoo or nil,ui_label=labels.voodoo,packets={},scope="Read-only listener metadata. No registration, packet send or state changes."}
for _,name in ipairs({"UpdateStatsUnreliable","UpdateStats","SetBoost","UpdateArmor"})do
 local packet=packets[name]
 local row={exists=type(packet)=="table",listen_type=type(packet and packet.listen),getListeners_type=type(packet and packet.getListeners)}
 if packet and type(packet.getListeners)=="function"then
  local pass,l=pcall(packet.getListeners)
  row.query_ok=pass
  if pass and type(l)=="table"then
   local n=0
   for _,v in pairs(l)do if type(v)=="function"then n+=1 end end
   row.function_listener_count=n
  end
 end
 out.packets[name]=row
end
if type(writefile)=="function" then pcall(function()writefile("booga_bytenet_listener_audit_v1.json",Http:JSONEncode(out))end)end
warn("[Booga ByteNet] listener metadata inspection finished")
