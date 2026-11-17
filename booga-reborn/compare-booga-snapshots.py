"""Compare complete Booga Reborn client snapshot ZIPs without extracting code.

Usage:
  python compare-booga-snapshots.py first-capture.zip second-capture.zip
  python compare-booga-snapshots.py capture1.zip capture2.zip capture3.zip

Input ZIPs must each contain one *complete export folder* with all
UPLOAD_PART_* subfolders. Split part ZIPs should be checked/combined separately
using verify-booga-client-export.py. This tool does not execute game code.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import sys
from zipfile import ZipFile, BadZipFile

UPLOAD_PART = re.compile(r"^UPLOAD_PART_\d{3}_(?:DATA|METADATA)$")
EXPECTED = "booga-reborn-client-archive/1.0"
MAX_ENTRY = 8 * 1024 * 1024


class SnapshotError(ValueError):
    pass


def safe_relative(filename):
    if "\\" in filename or filename.startswith("/"):
        raise SnapshotError("Unsafe archive path")
    parts = filename.split("/")
    if any(piece in ("", ".", "..") for piece in parts if piece):
        raise SnapshotError("Unsafe archive path")
    start = next((i for i, part in enumerate(parts) if UPLOAD_PART.fullmatch(part)), None)
    if start is None:
        return None
    return "/".join(parts[start:])


def parse_capture(filename):
    with ZipFile(filename) as zf:
        files = {}
        for info in zf.infolist():
            if info.is_dir():
                continue
            path = safe_relative(info.filename)
            if path is None:
                continue
            if path in files:
                raise SnapshotError("Duplicate internal file: " + path)
            files[path] = info
        manifest_path = "UPLOAD_PART_000_METADATA/manifest.json.txt"
        if manifest_path not in files:
            raise SnapshotError("Missing metadata manifest in " + str(filename))
        if files[manifest_path].file_size > MAX_ENTRY:
            raise SnapshotError("Manifest too large")
        manifest = json.loads(zf.read(files[manifest_path]))
        if manifest.get("schema") != EXPECTED:
            raise SnapshotError("Unexpected schema in " + str(filename))
        expected_folders = {p["folder"] for p in manifest.get("upload_parts", [])}
        existing_folders = {path.split("/")[0] for path in files}
        missing_folders = sorted(expected_folders - existing_folders)
        if missing_folders:
            raise SnapshotError("Missing export parts: " + ", ".join(missing_folders))
        script_paths = set()
        source_results = Counter()
        remote_paths = set()
        focus_paths = set()
        source_ids = set()
        source_exported = set()
        def rows(prefix):
            for path, info in files.items():
                rel = path.split("/", 1)[1] if "/" in path else ""
                if not rel.startswith(prefix) or not rel.endswith(".ndjson.txt"):
                    continue
                if info.file_size > MAX_ENTRY:
                    raise SnapshotError("Oversized individual row stream: " + path)
                text = zf.read(info).decode("utf-8", errors="replace")
                for line in text.splitlines():
                    if not line:
                        continue
                    try:
                        yield json.loads(line)
                    except (TypeError, ValueError) as exc:
                        raise SnapshotError("Invalid row JSON in " + path) from exc
        for row in rows("scripts/game_"):
            path = row.get("path")
            if isinstance(path, str):
                script_paths.add(path)
        for row in rows("source-results/game_"):
            source_results[str(row.get("status", "unknown"))] += 1
            script_id = row.get("id")
            if isinstance(script_id, int):
                source_ids.add(script_id)
                if row.get("status") == "exported":
                    source_exported.add(script_id)
        for row in rows("remotes/game_"):
            path = row.get("path")
            if isinstance(path, str):
                remote_paths.add(path)
        for row in rows("focus/game_"):
            path = row.get("path")
            if isinstance(path, str):
                focus_paths.add(path)
        systems = manifest.get("booga_system_index", {})
        return {
            "file": str(filename),
            "session_id": manifest.get("session_id"),
            "phase": manifest.get("phase"),
            "place_id": manifest.get("place_id"),
            "place_version": manifest.get("experience", {}).get("place_version"),
            "counts": manifest.get("counts", {}),
            "limits_hit": manifest.get("limits_hit", {}),
            "inventory_complete": manifest.get("inventory_traversal_exhausted"),
            "source_pass_finished": manifest.get("source_pass_finished"),
            "source_statuses": dict(source_results),
            "scripts": script_paths,
            "remotes": remote_paths,
            "focus": focus_paths,
            "systems": {k: v.get("total", 0) for k, v in systems.items()},
            "source_result_count": len(source_ids),
            "source_exported_count": len(source_exported),
        }


def preview(values, n=35):
    entries = sorted(values)
    return {"count": len(entries), "sample": entries[:n],
            "sample_truncated": len(entries) > n}


def compare(captures):
    report = {
        "schema": "booga-reborn-capture-compare/1.0",
        "integrity_note": "This is a coverage comparison, not a checksum verifier. Run verify-booga-client-export.py first.",
        "scope_note": "Only client-visible objects and script-source outcomes. No private server scripts.",
        "snapshots": [],
        "incremental_changes": [],
    }
    seen_scripts = set()
    seen_remotes = set()
    seen_focus = set()
    for capture in captures:
        report["snapshots"].append({
            "file": capture["file"],
            "session_id": capture["session_id"],
            "phase": capture["phase"],
            "place_version": capture["place_version"],
            "objects": capture["counts"].get("objects"),
            "script_count": capture["counts"].get("scripts"),
            "decompiled_or_exported": capture["counts"].get("sourceExported"),
            "source_failures": capture["counts"].get("sourceFailed"),
            "limits_hit": capture["limits_hit"],
            "inventory_complete": capture["inventory_complete"],
            "source_pass_finished": capture["source_pass_finished"],
            "systems": capture["systems"],
        })
        new_scripts = capture["scripts"] - seen_scripts
        new_remotes = capture["remotes"] - seen_remotes
        new_focus = capture["focus"] - seen_focus
        report["incremental_changes"].append({
            "capture": capture["file"],
            "new_game_script_paths": preview(new_scripts),
            "new_game_remote_paths": preview(new_remotes),
            "new_game_focus_paths": preview(new_focus),
            "source_status_counts": capture["source_statuses"],
        })
        seen_scripts.update(capture["scripts"])
        seen_remotes.update(capture["remotes"])
        seen_focus.update(capture["focus"])
    report["union"] = {
        "distinct_script_paths": len(seen_scripts),
        "distinct_remote_paths": len(seen_remotes),
        "distinct_interesting_paths": len(seen_focus),
        "number_of_captures": len(captures),
    }
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("zips", nargs="+", type=Path,
                        help="Two or more whole-export ZIPs in chronological order")
    args = parser.parse_args()
    if len(args.zips) < 2:
        parser.error("Pass at least two whole-export ZIP files")
    try:
        captures = [parse_capture(path) for path in args.zips]
        print(json.dumps(compare(captures), indent=2, ensure_ascii=False))
        return 0
    except (SnapshotError, ValueError, KeyError, OSError, BadZipFile) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2))
        return 1


if __name__ == "__main__":
    sys.exit(main())
