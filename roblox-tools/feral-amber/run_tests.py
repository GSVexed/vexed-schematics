#!/usr/bin/env python3
"""Official Luau compile + static-contract, simulation and package lifecycle gates.
No suite establishes live FERAL movement, accepted damage or Amber payouts.
"""
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path
from build import ROOT, DEST, MODULES

def literal(source):
    assert "]====================]" not in source
    return "[====================[\n"+source+"]====================]"

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--luau",required=True)
    p.add_argument("--compiler",required=True)
    p.add_argument("--output",type=Path)
    args=p.parse_args()
    subprocess.run(["python3",str(ROOT/"build.py"),"--check"],check=True)
    protections=json.loads((ROOT/"protected.json").read_text())
    for name,digest in protections.items():
        assert hashlib.sha256((ROOT.parent/name).read_bytes()).hexdigest()==digest, "Protected release changed: "+name
    sources={name:(ROOT/"src"/f"{name}.luau").read_text() for name in MODULES}
    for name,raw in sources.items():
        executable="\n".join(line for line in raw.splitlines() if not line.strip().startswith("--"))
        for pattern in (r"\bPivotTo\s*\(",r":FireServer\s*\(",r"\bAlignPosition\b",
                        r"\.(?:CFrame|Position|AssemblyLinearVelocity|AssemblyAngularVelocity|WalkSpeed|Health)\s*(?:[+*/-]?=)",
                        r"SetAttribute\s*\("):
            if name=="ui" and "Position" in pattern: continue  # GUI placement is intentional.
            assert not re.search(pattern,executable),f"Forbidden writer {pattern} in {name}"
    suites=sorted((ROOT/"tests").glob("*_suite.luau"))+[ROOT/"tests/suite.luau"]
    paths=[*(ROOT/"src"/f"{n}.luau" for n in MODULES),*suites,DEST,ROOT.parent/"feral-amber.lua"]
    for path in paths:
        subprocess.run([args.compiler,"--null",str(path)],check=True,capture_output=True,text=True)
    prelude="".join("local "+n.upper()+"_SRC="+literal(v)+"\n" for n,v in sources.items())
    prelude+="local BUNDLE_SRC="+literal(DEST.read_text())+"\n"
    prelude+="local MOCK_SRC="+literal((ROOT.parent/"renaissance/tests/mock_roblox.luau").read_text())+"\n"
    prelude+="local RENAISSANCE_SRC="+literal((ROOT.parent/"feral-renaissance-v15.6.0.lua").read_text())+"\n"
    results=[]
    errors=[]
    with tempfile.TemporaryDirectory(prefix="feral-amber-") as directory:
        for suite in suites:
            path=Path(directory)/suite.name
            path.write_text(prelude+suite.read_text())
            result=subprocess.run([args.luau,str(path)],capture_output=True,text=True)
            print(result.stdout,end="")
            if result.returncode:
                errors.append(suite.name+": "+result.stderr)
                continue
            matches=re.findall(r"AMBER_\w+_RESULT total=(\d+) passed=(\d+) failed=(\d+)",result.stdout)
            assert len(matches)==1,"Missing suite result: "+suite.name
            total,passed,failed=map(int,matches[0])
            assert total==passed and failed==0
            results.append(dict(suite=suite.name,total=total,passed=passed))
    if errors: raise RuntimeError("\n".join(errors))
    summary=dict(version="0.6.0",toolchain="97b2f4bf9cd935bed666f3e643a3b749b4d22f38",
        compiled=len(paths),total=sum(r["total"] for r in results),passed=sum(r["passed"] for r in results),
        suites=results,bundle_sha256=hashlib.sha256(DEST.read_bytes()).hexdigest(),
        protected_releases=len(protections),live_gameplay_tested=False)
    print(json.dumps(summary,sort_keys=True))
    if args.output:args.output.write_text(json.dumps(summary,indent=2)+"\n")
if __name__=="__main__":main()
