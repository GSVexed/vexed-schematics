"""Check the refresh collector against the existing diagnostic fault-injection harness."""
import importlib.util
import json
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("feral_base_tests", ROOT / "tests/test-feral-v3.py")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
source = ROOT / "feral-client-refresh-v3.0.4.lua"
harness = (ROOT / "tests/mock-feral-v3.lua").read_text()
harness = harness.replace("    writes=writes+1", '''    writes=writes+1
    if path=="feral_client_refresh_20261118_v304.json" then disk[path]=body;return end''', 1)
harness = harness.replace('local text=assert(io.open(SOURCE_PATH,"rb")):read("*a")', '''game._props.PlaceVersion=20261118
game._props.GameId=10771881861
local text=assert(io.open(SOURCE_PATH,"rb")):read("*a")''', 1)
harness = harness.replace('assert(writes==0 and decompileCalls==0,"collection started before Start click")',
                          'assert(writes==1 and decompileCalls==0,"only the initial refresh-status file may be written before the automatic start callback")', 1)

with tempfile.TemporaryDirectory(prefix="feral-refresh-tests-") as temporary:
    directory = Path(temporary)
    (directory / "tests").mkdir()
    (directory / "tests/mock-feral-v3.lua").write_text(harness)
    base.ROOT = directory
    for case in ["normal", "scale", "no_decompiler", "read_corruption", "cancel", "bytecode_dedup"]:
        result = base.run_lua(case, directory / (case + ".json"), source=source)
        status = json.loads(result["disk"]["feral_client_refresh_20261118_v304.json"])
        export_result = dict(result, disk={path: body for path, body in result["disk"].items()
                                          if path != "feral_client_refresh_20261118_v304.json"})
        checked = base.inspect_export(export_result)
        assert status["place_version"] == 20261118 and status["universe_id"] == 10771881861
        assert status["capture_id"] == "20261118-update-v1"
        if checked is None:
            assert status["phase"] == "failed_partial"
        else:
            manifest, records = checked
            assert manifest["source_pending"] == 0
            assert manifest["place_version"] == 20261118
            assert manifest["source_optimization"]["scope"] == "eligible_game_scripts_only_platform_inventory_retained"
            outcomes = records.get("source-results", [])
            assert all(row["category"] == "game" for row in outcomes if row["status"] == "exported")
            assert all(row["status"] == "excluded_platform_update_scope" for row in outcomes if row["category"] == "platform")
            assert status["phase"] == manifest["phase"]
            if case == "scale":
                assert manifest["counts"]["scripts"] == 37991
                assert manifest["source_status_counts"]["excluded_platform_update_scope"] >= 37984
                assert result["decompile_calls"] < 20
            if case == "normal":
                assert any(row["status"] == "exported" for row in outcomes)
                assert status["source_pass_finished"]
        print("PASS refresh:", case, status["phase"])
