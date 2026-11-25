#!/usr/bin/env python3
"""Compile all-animal FERAL Amber modules and execute deterministic Luau suites."""
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
    agent=ROOT/"src/agent.luau"
    nav=ROOT/"src/nav.luau"
    bridge=ROOT/"src/bridge.luau"
    suites=[ROOT/"tests/suite.luau",ROOT/"tests/agent_suite.luau"]
    for path in (planner,agent,nav,bridge,*suites):
        subprocess.run([args.compiler,str(path)],check=True,stdout=subprocess.DEVNULL)
    sources={}
    for name,path in (("PLANNER_SRC",planner),("AGENT_SRC",agent)):
        source=path.read_text(encoding="utf-8")
        assert "]====]" not in source
        nl=chr(10)
        sources[name]="local "+name+"=[====["+nl+source+nl+"]====]"+nl
    prelude=''.join(sources.values())
    with tempfile.TemporaryDirectory(prefix="feral-amber-") as temp:
        for suite in suites:
            merged=prelude+suite.read_text(encoding="utf-8")
            path=Path(temp)/suite.name;path.write_text(merged,encoding="utf-8")
            subprocess.run([args.compiler,str(path)],check=True,stdout=subprocess.DEVNULL)
            subprocess.run([args.luau,str(path)],check=True)
if __name__=="__main__": main()
