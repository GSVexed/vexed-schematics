"""Ownership, request bounds and verdict tests. No Roblox/server emulation claim."""
from pathlib import Path
import os
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
CASES = r'''
local passed=0
local function case(name, fn) fn(); passed+=1; print("PASS "..name) end
local function data(owned,coins)
    return {coins=coins or 2000,inventory={{name="Resource Chest",quantity=owned or 0},{name="Stone",quantity=5}}}
end
local function fixture(options)
    options=options or {}
    local a={snapshots=0,sends=0,watches=0,reserves=0,observes=0,trace={},states={}}
    local result={chest="Resource Chest",request_attempted=false,request_sent=false,world_chests_observed=0}
    local function trace(v) a.trace[#a.trace+1]=v end
    a.state=function(v) a.states[#a.states+1]=v end
    a.snapshot=function()
        a.snapshots+=1; trace("snapshot")
        if a.snapshots==1 then return options.before or data() end
        return options.missingAfter and nil or (options.after or data())
    end
    a.guard=function() return not options.cancelled and not (options.cancelAfterObserve and a.observes>0)
        and not (options.cancelAfterReserve and a.reserves>0) end
    a.watch=function() a.watches+=1; trace("watch"); return not options.noWorld end
    a.reserve=function() a.reserves+=1; trace("reserve"); return not options.limit end
    a.send=function(chest) a.sends+=1; trace("send"); assert(chest=="Resource Chest"); return not options.sendFail end
    a.observe=function() a.observes+=1; trace("observe"); return options.matches or 0 end
    return a,result
end
case("a fresh empty inventory can establish zero owned",function()
    local r=Core.snapshot({inventory={},coins=0},"Resource Chest"); assert(r.owned==0 and r.coins==0)
end)
case("duplicate inventory entries are summed without modifying them",function()
    local v=data(2); v.inventory[3]={name="Resource Chest",quantity=4}
    local r=Core.snapshot(v,"Resource Chest"); assert(r.owned==6 and v.inventory[1].quantity==2)
end)
case("invalid inventory responses cannot establish ownership",function()
    for _,v in ipairs({{}, {inventory="invalid",coins=0}, {inventory=false,coins=0}}) do
        assert(Core.snapshot(v,"Resource Chest")==nil)
    end
end)
case("invalid selected quantities cannot masquerade as zero owned",function()
    for _,q in ipairs({-1,.5,math.huge,"invalid",0/0}) do
        local v=data(); v.inventory[1].quantity=q; assert(Core.snapshot(v,"Resource Chest")==nil)
    end
    local v=data(); v.inventory[1].quantity=nil; assert(Core.snapshot(v,"Resource Chest")==nil)
end)
case("owned chests prevent both reservation and gameplay requests",function()
    local a,r=fixture({before=data(1)}); Core.trial(a,r)
    assert(r.verdict=="ALREADY_OWNED" and a.sends==0 and a.reserves==0 and a.watches==0)
end)
case("unusable initial data stops before any gameplay request",function()
    local a,r=fixture({before={inventory=false}}); Core.trial(a,r)
    assert(r.verdict=="BEFORE_UNAVAILABLE" and a.sends==0 and a.snapshots==1)
end)
case("cancellation before setup prevents the request",function()
    local a,r=fixture({cancelled=true}); Core.trial(a,r)
    assert(r.verdict=="CANCELLED" and a.sends==0 and a.watches==0)
end)
case("missing world observation support prevents the request",function()
    local a,r=fixture({noWorld=true}); Core.trial(a,r)
    assert(r.verdict=="WORLD_UNAVAILABLE" and a.sends==0 and a.reserves==0)
end)
case("session limits prevent request transmission",function()
    local a,r=fixture({limit=true}); Core.trial(a,r)
    assert(r.verdict=="SESSION_LIMIT" and a.sends==0)
end)
case("cancellation after reservation still prevents transmission",function()
    local a,r=fixture({cancelAfterReserve=true}); Core.trial(a,r)
    assert(r.verdict=="CANCELLED" and a.sends==0)
end)
case("one request and two snapshots are made in the intended order",function()
    local a,r=fixture(); Core.trial(a,r)
    assert(a.sends==1 and a.snapshots==2 and r.request_sent)
    assert(table.concat(a.trace,",")=="snapshot,watch,reserve,send,observe,snapshot")
end)
case("a transmission failure is not retried or reported as sent",function()
    local a,r=fixture({sendFail=true}); Core.trial(a,r)
    assert(r.verdict=="SEND_FAILED" and a.sends==1 and not r.request_sent and a.observes==0 and a.snapshots==1)
end)
case("no matching world chest does not produce a success result",function()
    local a,r=fixture(); Core.trial(a,r)
    assert(r.verdict=="NO_CHEST_OBSERVED" and r.world_chests_observed==0)
end)
case("a matching world chest remains explicitly unverified",function()
    local a,r=fixture({matches=1}); Core.trial(a,r)
    assert(r.verdict=="CHEST_OBSERVED_UNVERIFIED" and r.before_owned==0 and r.after_owned==0)
end)
case("coin reduction cannot be labelled a free spawn",function()
    local a,r=fixture({matches=1,after=data(0,1700)}); Core.trial(a,r)
    assert(r.verdict=="BALANCE_CHANGED")
end)
case("coin increases also mark the result as confounded",function()
    local a,r=fixture({matches=1,after=data(0,2001)}); Core.trial(a,r)
    assert(r.verdict=="BALANCE_CHANGED")
end)
case("a new owned chest makes the free-spawn inference inconclusive",function()
    local a,r=fixture({matches=1,after=data(1)}); Core.trial(a,r)
    assert(r.verdict=="BALANCE_CHANGED")
end)
case("a missing final response cannot establish a free spawn",function()
    local a,r=fixture(); a.snapshot=function() a.snapshots+=1; return a.snapshots==1 and data() or nil end
    Core.trial(a,r); assert(r.verdict=="AFTER_UNAVAILABLE" and r.after_coins==nil and a.sends==1)
end)
case("cancellation after sending prevents the final RPC and any second request",function()
    local a,r=fixture({cancelAfterObserve=true}); Core.trial(a,r)
    assert(r.verdict=="CANCELLED" and a.snapshots==1 and a.sends==1)
end)
case("excessive quantities are rejected instead of overflowing the count",function()
    local v=data(1000000001); assert(Core.snapshot(v,"Resource Chest")==nil)
end)
case("numeric strings from the native inventory are parsed without edits",function()
    local v={inventory={{name="Resource Chest",quantity="2"}},coins="123"}
    local r=Core.snapshot(v,"Resource Chest"); assert(r.owned==2 and r.coins==123 and v.coins=="123")
end)
case("unavailable coin fields do not erase a readable inventory",function()
    for _,c in ipairs({-1,math.huge,0/0,"invalid",false}) do
        local r=Core.snapshot({inventory={},coins=c},"Resource Chest")
        assert(r and r.owned==0 and r.coins==nil)
    end
end)
case("missing coins cannot become an unchanged-balance spawn result",function()
    assert(Core.verdict({owned=0},{owned=0},1)=="CHEST_OBSERVED_BALANCE_UNKNOWN")
    assert(Core.verdict({owned=0,coins=10},{owned=0},1)=="CHEST_OBSERVED_BALANCE_UNKNOWN")
end)
case("the reported nil-inventory RPC can use the initialized live game cache",function()
    local r,source,reason=Core.selectSnapshot(nil,data(),"Resource Chest")
    assert(r and r.owned==0 and source=="live_game_cache" and reason=="payload_not_table")
end)
case("a malformed remote response can fall back to readable cached inventory",function()
    local r,source=Core.selectSnapshot({inventory=false},data(),"Resource Chest")
    assert(r and source=="live_game_cache")
end)
case("a valid fresh response is preferred when it agrees with the game cache",function()
    local r,source=Core.selectSnapshot(data(),data(),"Resource Chest")
    assert(r and source=="server_reply")
end)
case("a positive current cache blocks a zero-owned stale reply",function()
    local r,source=Core.selectSnapshot(data(),data(1),"Resource Chest")
    assert(r.owned==1 and source=="live_game_cache_positive_override")
end)
case("a cached owned chest still prevents the gameplay request",function()
    local a,r=fixture(); a.snapshot=function()
        local view=Core.selectSnapshot(nil,data(1),"Resource Chest")
        return {inventory={{name="Resource Chest",quantity=view.owned}},coins=view.coins}
    end
    Core.trial(a,r); assert(r.verdict=="ALREADY_OWNED" and a.sends==0)
end)
case("two unreadable inventories remain a failure before sending",function()
    local r,source,replyReason,cacheReason=Core.selectSnapshot(nil,{inventory=false},"Resource Chest")
    assert(not r and source=="unavailable" and replyReason=="payload_not_table" and cacheReason=="inventory_not_table")
end)
case("cached zero ownership reaches exactly one request when refresh is unavailable",function()
    local a,r=fixture(); a.snapshot=function()
        a.snapshots+=1
        local view=Core.selectSnapshot(nil,data(),"Resource Chest")
        return {inventory={{name="Resource Chest",quantity=view.owned}},coins=view.coins}
    end
    Core.trial(a,r); assert(a.sends==1 and a.snapshots==2 and r.verdict=="NO_CHEST_OBSERVED")
end)
print("BOOGA_CHEST_TRIAL_CORE_CASES="..passed)
'''


def main():
    source = (ROOT / "booga-chest-trial-v1.0.lua").read_text()
    assert source.count("packets.ChestDrop.send(") == 1
    assert source.count(":InvokeServer()") == 1
    assert not re.search(r"\b(?:PurchaseChest|PurchaseFromShop)\s*[.:]", source)
    for forbidden in ("FireServer(", "getgc(", "hookfunction(", "setupvalue(", "SetAttribute(", ".Health =", ".coins =", ".inventory =", "decompile(", "getclipboard("):
        assert forbidden not in source, forbidden
    core = source.split("-- BEGIN TESTABLE CORE", 1)[1].split("-- END TESTABLE CORE", 1)[0]
    with tempfile.TemporaryDirectory(prefix="booga-chest-core-") as tmp:
        p = Path(tmp) / "checks.luau"
        p.write_text(core + CASES)
        result = subprocess.run([os.environ.get("LUAU", "luau"), str(p)], capture_output=True, text=True)
        print(result.stdout, end="")
        if result.returncode:
            print(result.stderr, end="")
            raise SystemExit(result.returncode)
    print("Core and static boundary checks passed. GUI, Velocity and live server behavior are unverified.")


if __name__ == "__main__":
    main()
