#!/usr/bin/env python3
"""Verify both integrated suites and write an evidence-bound candidate record.

The stable launcher is intentionally independent. Mocked tests never establish
live Roblox input acceptance, damage, recovery multipliers, or voice range.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from build import (ROOT, DEST, VERSION, TERRITORY_VERSION, CHANNEL, GAME_BASELINE,
                   TOOLCHAIN, MODULES, PROTECTED_HASHES, build, verify_protected_artifacts)

REPO = ROOT.parents[1]
AMBER = ROOT.parent / "feral-amber"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_paths():
    paths = [ROOT / "version.json", ROOT / "build.py", ROOT / "run_tests.py",
             ROOT / "verify_candidate.py", AMBER / "build.py", AMBER / "run_tests.py",
             AMBER / "protected.json"]
    for folder in (ROOT / "src", ROOT / "tests", AMBER / "src", AMBER / "tests"):
        paths.extend(sorted(folder.glob("*.luau")))
    return paths


def input_hashes(paths, relative_to):
    return {str(path.relative_to(relative_to)): digest(path) for path in paths}


def verify_inputs(record, relative_to, expected):
    assert record.get("validation_inputs") == expected, "Stored test inputs are stale; rerun validation"
    for name, value in expected.items():
        assert digest(relative_to / name) == value, f"Test input changed during verification: {name}"


def commit_for_inputs(requested, inputs):
    try:
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        if requested:
            raise RuntimeError("Cannot verify the requested source commit without repository history")
        return None, None
    ref = requested or head
    assert re.fullmatch(r"[0-9a-f]{40}", ref), "Source commit must be a full immutable SHA"
    matches = True
    for name, expected in inputs.items():
        result = subprocess.run(["git", "show", f"{ref}:{name}"], cwd=REPO, capture_output=True)
        if result.returncode or hashlib.sha256(result.stdout).hexdigest() != expected:
            matches = False
            if requested:
                raise RuntimeError(f"Source commit does not match validated input: {name}")
            break
    return ref if matches else None, head


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", default=os.environ.get("LUAU_BIN", "luau"))
    parser.add_argument("--compiler", default=os.environ.get("LUAU_COMPILE", "luau-compile"))
    parser.add_argument("--source-commit", help="Exact local commit containing the tested source files")
    parser.add_argument("--report-only", action="store_true",
                        help="Reuse successful reports only if their recorded input hashes still match")
    parser.add_argument("--check-tracked-bundle", action="store_true",
                        help="Require committed bundle and manifest to equal the deterministic rebuild")
    parser.add_argument("--output", type=Path, default=ROOT / "candidate.json")
    args = parser.parse_args()
    stable_paths = (ROOT / "release.json", ROOT.parent / "feral-renaissance.lua")
    stable_before = {str(path): digest(path) for path in stable_paths}
    verify_protected_artifacts()
    inputs = input_hashes(source_paths(), REPO)
    amber_paths = [AMBER / "build.py", AMBER / "run_tests.py", AMBER / "protected.json",
                   *sorted((AMBER / "src").glob("*.luau")), *sorted((AMBER / "tests").glob("*.luau"))]
    amber_inputs = input_hashes(amber_paths, AMBER)
    amber_inputs["../renaissance/tests/mock_roblox.luau"] = digest(ROOT / "tests/mock_roblox.luau")
    core_report_path, amber_report_path = ROOT / "test-results.json", AMBER / "test-results.json"
    if not args.report_only:
        subprocess.run([sys.executable, str(ROOT / "run_tests.py"), "--luau", args.luau,
                        "--compiler", args.compiler, "--output", str(core_report_path)], check=True)
        subprocess.run([sys.executable, str(AMBER / "run_tests.py"), "--luau", args.luau,
                        "--compiler", args.compiler, "--output", str(amber_report_path)], check=True)
        amber_report = json.loads(amber_report_path.read_text())
        amber_report["validation_inputs"] = amber_inputs
        amber_report_path.write_text(json.dumps(amber_report, indent=2) + "\n")
    core = json.loads(core_report_path.read_text())
    amber = json.loads(amber_report_path.read_text())
    assert inputs == input_hashes(source_paths(), REPO), "Sources changed while verification was running"
    verify_inputs(amber, AMBER, amber_inputs)
    core_inputs = core.get("validation_inputs")
    assert isinstance(core_inputs, dict) and core_inputs, "Renaissance report lacks input evidence"
    for name, expected in core_inputs.items():
        assert digest(ROOT / name) == expected, f"Renaissance validation is stale: {name}"
    required_tests = {"suite.luau", "overhaul_interactions.luau", "overhaul_native.luau", "overhaul_ui.luau",
                      "lifecycle_regressions.luau", "combat_regressions.luau", "review_regressions.luau"}
    for name in required_tests:
        assert (ROOT / "tests" / name).is_file(), f"Required regression suite missing: {name}"
    assert required_tests <= set(core.get("suite_files", [])), "Regression suites omitted from verification"
    manifest_path = ROOT / "manifest.json"
    before = DEST.read_bytes(), manifest_path.read_bytes()
    manifest = build()
    assert before == (DEST.read_bytes(), manifest_path.read_bytes()), "Package rebuild is not byte-identical"
    bundle_hash = digest(DEST)
    assert core["version"] == VERSION and core["bundle_sha256"] == bundle_hash, "Renaissance report is stale"
    assert core.get("source_fingerprint") == manifest["source_fingerprint"], "Renaissance source fingerprint is stale"
    assert core["runtime_exit_code"] == 0, "Renaissance runtime failed"
    assert core["regressions"]["failed"] == 0 and core["regressions"]["passed"] == core["regressions"]["total"]
    assert core["module_parity"] and core["rollback_hashes_unchanged"]
    assert amber["version"] == TERRITORY_VERSION, "Territory report version mismatch"
    assert amber["integrated_version"] == VERSION and amber["integrated_sha256"] == bundle_hash, "Territory report is stale"
    assert amber["total"] == amber["passed"] and amber["passed"] >= 305, "Territory regressions failed or disappeared"
    assert core.get("live_gameplay_tested") is False and amber.get("live_gameplay_tested") is False
    assert manifest["integrated_territory_version"] == TERRITORY_VERSION
    verify_protected_artifacts()
    for path in stable_paths:
        assert digest(path) == stable_before[str(path)], f"Stable release changed: {path.name}"
    # A pinned source reference must also contain the exact distributable;
    # otherwise a valid source SHA could still produce a broken loader URL.
    pinned_inputs = {**inputs, str(DEST.relative_to(REPO)): bundle_hash,
                     str(manifest_path.relative_to(REPO)): digest(manifest_path)}
    source_commit, base_commit = commit_for_inputs(args.source_commit, pinned_inputs)
    if args.check_tracked_bundle:
        for path in (DEST, manifest_path):
            committed = subprocess.check_output(["git", "show", f"HEAD:{path.relative_to(REPO)}"], cwd=REPO)
            assert committed == path.read_bytes(), f"Committed artifact differs from source: {path.name}"
    report = {
        "version": VERSION, "channel": CHANNEL, "integrated_territory_version": TERRITORY_VERSION,
        "game_baseline": GAME_BASELINE, "source_commit": source_commit, "source_base_commit": base_commit,
        "source_status": "commit verified" if source_commit else "validated workspace; source commit not yet pinned",
        "source_inputs": inputs, "bundle_file": str(DEST.relative_to(REPO)), "bundle_sha256": bundle_hash,
        "source_fingerprint": manifest["source_fingerprint"],
        "bundle_bytes": DEST.stat().st_size, "module_count": len(MODULES),
        "toolchain_commit": TOOLCHAIN,
        "renaissance_regressions": core["regressions"],
        "renaissance_compiled_files": len(core["compiled"]),
        "territory_regressions": {"total": amber["total"], "passed": amber["passed"], "failed": 0},
        "territory_compiled_files": amber["compiled"],
        "regression_suites": core["suite_files"],
        "test_report_sha256": {"renaissance": digest(core_report_path), "territory": digest(amber_report_path)},
        "deterministic_rebuild": True, "module_parity": True,
        "protected_renaissance_artifacts": len(PROTECTED_HASHES),
        "protected_territory_artifacts": amber["protected_releases"],
        "stable_promoted": False, "stable_launcher_unchanged": True,
        "validation_level": "Luau compilation, deterministic package checks, mocked integration and behavioral regressions",
        "live_gameplay_tested": False, "gameplay_acceptance": "unverified",
        "limitations": [
            "Mocks do not establish real executor capabilities or physical-input behavior in Roblox.",
            "Accepted damage, sustained recovery, Territory outcomes, and voice audibility require live runtime evidence.",
            "Stable launcher remains on its separately recorded release; use the exact candidate bundle for this version."
        ],
    }
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"candidate": VERSION, "territory": TERRITORY_VERSION,
                      "renaissance": core["regressions"], "territory_tests": report["territory_regressions"],
                      "source_commit": source_commit, "bundle_sha256": bundle_hash,
                      "live_gameplay_tested": False}, indent=2))


if __name__ == "__main__":
    main()
