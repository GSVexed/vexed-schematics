#!/usr/bin/env python3
"""Deterministically package the twelve-module integrated Territory entry."""
from pathlib import Path
import argparse
import hashlib
ROOT=Path(__file__).resolve().parent
DEST=ROOT.parent/"feral-amber-autopilot-v0.8.0.lua"
MODULES=("ledger","model","planner","gait","nav","hunt","care","agent","bridge","driver","ui","runtime")
BOOT=r'''-- The Territory engine is part of Renaissance; this versioned entry reuses it.
if game.PlaceId~=108901361810209 then return nil end
local env=(type(getgenv)=="function" and getgenv()) or _G
local hub=env.FERAL_RENAISSANCE_ACTIVE
if not hub or hub.closed or not hub.ui or type(hub.ui.registerPage)~="function" then
    warn("[FERAL TERRITORY] Run the current combined Amber/Renaissance launcher first.")
    return nil
end
if hub.territory and hub.territory.version=="0.8.0" and not hub.territory.closed then return hub.territory end
local M={}
for name,source in pairs(sources) do
    local fn,why=loadstring(source,"=FERAL_TERRITORY_"..name)
    assert(fn,why);M[name]=fn()
end
return M.runtime.start(M,hub)
'''
def create():
    chunks=['-- FERAL Amber Autopilot 0.8.0 | 2026-11-26 | native profiles | gameplay outcomes observed separately',
            'local sources = {}']
    for name in MODULES:
        source=(ROOT/"src"/f"{name}.luau").read_text(encoding="utf-8")
        assert "]============]" not in source
        chunks.append(f'sources["{name}"] = [============[\n{source}]============]')
    chunks.append(BOOT.strip())
    return "\n".join(chunks)+"\n"
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--check",action="store_true")
    args=p.parse_args()
    data=create()
    if args.check:
        assert DEST.is_file() and DEST.read_text(encoding="utf-8")==data,"Candidate source differs from compiled modules"
    else:
        DEST.write_text(data,encoding="utf-8")
    print(f"FERAL AMBER 0.8.0 sha256={hashlib.sha256(data.encode()).hexdigest()} bytes={len(data.encode())}")
if __name__=="__main__":main()
