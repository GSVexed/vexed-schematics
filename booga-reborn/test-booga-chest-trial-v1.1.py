"""Native-dispatch preservation and unowned-only regressions; offline checks."""
from pathlib import Path
import importlib.util
import os
import re
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("chest_previous", ROOT / "test-booga-chest-trial-v1.py")
previous = importlib.util.module_from_spec(spec)
spec.loader.exec_module(previous)

NATIVE_CASES = r'''
case("native delivery receives every argument and all return values survive",function()
    local calls=0
    local packet={fireListener=function(a,b,c) calls+=1; assert(a==12 and b==nil and c==7); return false,nil,42 end}
    local lease=assert(Core.tap(packet,function(a,b,c) assert(a==12 and b==nil and c==7) end))
    local r=table.pack(packet.fireListener(12,nil,7))
    assert(calls==1 and r.n==3 and r[1]==false and r[2]==nil and r[3]==42)
    assert(lease.forwarded==1 and lease.native_listener_return==false)
end)
case("an observer exception cannot suppress the native delivery",function()
    local calls=0;local packet={fireListener=function()calls+=1;return true end}
    local lease=assert(Core.tap(packet,function()error("PRIVATE OBSERVER ERROR")end))
    assert(packet.fireListener()==true and calls==1 and lease.observer_errors==1)
end)
case("native listener errors preserve their normal propagation",function()
    local packet={fireListener=function()error("native error")end}
    assert(Core.tap(packet,function()end));local ok=pcall(packet.fireListener)
    assert(not ok)
end)
case("cleanup restores the original native function",function()
    local old=function()return 9 end;local packet={fireListener=old}
    local lease=assert(Core.tap(packet,function()end));assert(packet.fireListener~=old)
    assert(Core.untap(lease) and packet.fireListener==old)
end)
case("cleanup preserves an external edit instead of overwriting it",function()
    local packet={fireListener=function()end};local lease=assert(Core.tap(packet,function()end))
    local replacement=function()return 13 end;packet.fireListener=replacement
    assert(Core.untap(lease) and packet.fireListener==replacement)
end)
case("a frozen packet cannot be forced writable",function()
    local old=function()end;local packet=table.freeze({fireListener=old})
    assert(Core.tap(packet,function()end)==nil and packet.fireListener==old)
end)
case("observation never replaces the single native listen callback",function()
    local packet={fireListener=function()return true end,listen=function()error("listen must not be called")end}
    local lease=assert(Core.tap(packet,function()end));assert(packet.fireListener()==true);Core.untap(lease)
end)
case("missing dispatch capability yields an unsupported result",function()
    assert(Core.tap({},function()end)==nil and Core.tap(nil,function()end)==nil)
end)
case("ownership notices are classified without retaining their text",function()
    assert(Core.notice("<b>You don't have any Resource Chests</b>")=="ownership")
    assert(Core.notice("You do not have that chest")=="ownership")
end)
case("rate-limit and affordability notices have separate classifications",function()
    assert(Core.notice("Slow down")=="rate_limit")
    assert(Core.notice("You can't afford this")=="coins")
end)
case("unrelated messages and oversized text are discarded",function()
    assert(Core.notice("PRIVATE PLAYER MESSAGE")==nil)
    assert(Core.notice(string.rep("chest",110))==nil and Core.notice({message="chest"})==nil)
end)
case("a classified ownership notice is reported without claiming a spawn",function()
    assert(Core.verdict({owned=0,coins=2},{owned=0,coins=2},0,{notices={ownership=1}})=="OWNERSHIP_NOTICE_SEEN")
end)
case("a rate-limit notice is not confused with ownership evidence",function()
    assert(Core.verdict({owned=0,coins=2},{owned=0,coins=2},0,{notices={rate_limit=1}})=="RATE_LIMIT_NOTICE_SEEN")
end)
case("a nearby falling-chest signal alone remains inconclusive",function()
    assert(Core.verdict({owned=0,coins=2},{owned=0,coins=2},0,{native_falling_nearby=1})=="FALLING_EVENT_ONLY")
end)
case("a balance change stays inconclusive even when spawn feedback arrives",function()
    assert(Core.verdict({owned=0,coins=2},{owned=0,coins=1},1,{native_falling_nearby=1})=="BALANCE_CHANGED")
end)
print("BOOGA_CHEST_NATIVE_TOTAL_CASES="..passed)
'''


def main():
    source = (ROOT / "booga-chest-trial-v1.1.lua").read_text()
    assert source.count("packets.ChestDrop.send(") == 1
    assert source.count(":InvokeServer()") == 1
    assert 'if before.owned ~= 0 then result.verdict = "ALREADY_OWNED"' in source
    assert "packet.listen(" not in source and ".FallingChest.listen(" not in source
    assert not re.search(r"\b(?:PurchaseChest|PurchaseFromShop)\s*[.:]", source)
    for forbidden in ("FireServer(", "getgc(", "hookfunction(", "setupvalue(", "SetAttribute(", ".Health =", ".coins =", ".inventory =", "decompile(", "getclipboard("):
        assert forbidden not in source, forbidden
    core = source.split("-- BEGIN TESTABLE CORE", 1)[1].split("-- END TESTABLE CORE", 1)[0]
    with tempfile.TemporaryDirectory(prefix="booga-chest-native-") as tmp:
        p = Path(tmp) / "native-checks.luau"
        p.write_text(core + previous.CASES + NATIVE_CASES)
        result = subprocess.run([os.environ.get("LUAU", "luau"), str(p)], capture_output=True, text=True)
        print(result.stdout, end="")
        if result.returncode:
            print(result.stderr, end="")
            raise SystemExit(result.returncode)
    print("45 offline checks passed. No new live chest grant or GUI result is established.")


if __name__ == "__main__":
    main()
