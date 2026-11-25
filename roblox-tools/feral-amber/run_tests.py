#!/usr/bin/env python3
"""Compile Grizzly Amber modules with official Luau and run deterministic planner tests."""
import argparse
import subprocess
import tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--luau",required=True)
    p.add_argument("--compiler",required=True)
    args=p.parse_args()
    planner=ROOT/"src/planner.luau"
    suite=ROOT/"tests/suite.luau"
    for path in (planner,suite):
        subprocess.run([args.compiler,str(path)],check=True,stdout=subprocess.DEVNULL)
    source=planner.read_text(encoding="utf-8")
    assert "]====]" not in source
    merged='local PLANNER_SRC=[====[\n'+source+'\n]====]\n'+suite.read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="grizzly-amber-") as temp:
        path=Path(temp)/"test.luau";path.write_text(merged,encoding="utf-8")
        subprocess.run([args.compiler,str(path)],check=True,stdout=subprocess.DEVNULL)
        subprocess.run([args.luau,str(path)],check=True)
if __name__=="__main__": main()
