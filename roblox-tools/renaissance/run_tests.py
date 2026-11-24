#!/usr/bin/env python3
"""Compile every module/bundle and run service-boundary regression scenarios."""
import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import tempfile

from build import ROOT, DEST, MODULES, build


def long_string(text):
    marker = "===================="
    assert f"]{marker}]" not in text
    return f"[{marker}[\n{text}]{marker}]"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--luau", default=os.environ.get("LUAU_BIN", "luau"))
    ap.add_argument("--compiler", default=os.environ.get("LUAU_COMPILE", "luau-compile"))
    ap.add_argument("--output", type=pathlib.Path, default=ROOT / "test-results.json")
    args = ap.parse_args()
    manifest = build()
    compiled = []
    compile_paths = [*(ROOT/"src"/f"{name}.luau" for name in MODULES),
                     ROOT/"tests/mock_roblox.luau", ROOT/"tests/suite.luau", DEST]
    launcher = ROOT.parent/"feral-renaissance.lua"
    if launcher.exists():
        compile_paths.append(launcher)
        release = json.loads((ROOT/"release.json").read_text())
        pin = f'{release["source_commit"]}/roblox-tools/feral-renaissance-v{release["version"]}.lua'
        assert re.fullmatch(r"[0-9a-f]{40}", release["source_commit"]), "launcher commit pin"
        assert pin in launcher.read_text(), "launcher differs from released source pin"
        released = ROOT.parent/f'feral-renaissance-v{release["version"]}.lua'
        assert hashlib.sha256(released.read_bytes()).hexdigest() == release["bundle_sha256"], "released bundle hash"
    for p in compile_paths:
        result = subprocess.run([args.compiler, "--null", str(p)], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        compiled.append(p.name)
    # Ensure the stable rollback has not been edited.
    stable_hashes = {
        "feral-nova-v14.0-clean-reach-core.lua": "7ce435099acf823c0f92a406a8febf0260fb9fcfbdde54d9c4a084f8190ce93c",
        "feral-nova-clean.lua": "d34847e2cb11c822177071e109fc2c8bc9e13e3ce7aa7ade02fd732b192e2952",
        "feral-renaissance-v15.0.0.lua": "bc388ccfdc8bae19e7fe2dca7c24bf2fbd3f97266c205c38544735e81ea3e12f",
        "feral-renaissance-v15.1.0.lua": "7c289fd74de07c86537476e1c7fa760f3422ff8d305737bb5e19ab3e546cb093",
    }
    stable_hashes["feral-renaissance-v15.2.0.lua"] = "435265c032d1c200157e2004021ab491dc7c317317c5792e0070c2b1fffc8ceb"
    for name, digest in stable_hashes.items():
        assert hashlib.sha256((ROOT.parent/name).read_bytes()).hexdigest() == digest, f"rollback changed: {name}"
    source = DEST.read_text()
    for name in MODULES:
        body = re.search(r'sources\["' + name + r'"\] = \[============\[\n(.*?)\]============\]', source, re.S).group(1)
        assert body == (ROOT/"src"/f"{name}.luau").read_text(), f"bundle parity: {name}"
    assert not re.search(r'FireServer\s*\(\s*["\']Bite(?:Hit)?["\']', source)
    script = "local BUNDLE = " + long_string(source) + "\nlocal MOCK_SOURCE = " + long_string(
        (ROOT/"tests/mock_roblox.luau").read_text()) + "\n" + (ROOT/"tests/suite.luau").read_text()
    with tempfile.TemporaryDirectory(prefix="renaissance-test-") as directory:
        path = pathlib.Path(directory)/"regression.luau"
        path.write_text(script)
        result = subprocess.run([args.luau, str(path)], text=True, capture_output=True)
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    match = re.search(r"RENAISSANCE_TEST_RESULT total=(\d+) passed=(\d+) failed=(\d+)", result.stdout)
    summary = {"version": "15.2.1", "bundle_sha256": manifest["bundle_sha256"],
               "compiled": compiled, "module_parity": True, "rollback_hashes_unchanged": True,
               "regressions": dict(zip(("total","passed","failed"), map(int,match.groups()))) if match else None,
               "runtime_exit_code": result.returncode, "gameplay_success_claimed": False,
               "results": result.stdout.splitlines()}
    args.output.write_text(json.dumps(summary, indent=2) + "\n")
    if result.returncode or not match:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
