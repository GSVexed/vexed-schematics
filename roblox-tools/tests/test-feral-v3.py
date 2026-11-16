"""Offline integration tests using system liblua5.4 via ctypes.

The diagnostic deliberately uses common Lua/Luau syntax. Lua 5.4 parsing and these
mocks do NOT validate Velocity APIs, actual Roblox UI, native-call preemption,
or Windows PowerShell execution. Run: python3 roblox-tools/tests/test-feral-v3.py
"""
import ctypes as C
import ctypes.util
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / os.environ.get('FERAL_SOURCE','feral-complete-diagnostic-v3.0.1.lua')
lib_name = ctypes.util.find_library('lua5.4')
if not lib_name:
    raise SystemExit('Install liblua5.4 to run these offline mock tests.')
LUA = C.CDLL(lib_name)
LUA.luaL_newstate.restype = C.c_void_p
LUA.luaL_openlibs.argtypes = [C.c_void_p]
LUA.lua_pushstring.argtypes = [C.c_void_p, C.c_char_p]
LUA.lua_setglobal.argtypes = [C.c_void_p, C.c_char_p]
LUA.luaL_loadfilex.argtypes = [C.c_void_p, C.c_char_p, C.c_char_p]
LUA.luaL_loadfilex.restype = C.c_int
LUA.lua_pcallk.argtypes = [C.c_void_p, C.c_int, C.c_int, C.c_int, C.c_longlong, C.c_void_p]
LUA.lua_pcallk.restype = C.c_int
LUA.lua_tolstring.argtypes = [C.c_void_p, C.c_int, C.POINTER(C.c_size_t)]
LUA.lua_tolstring.restype = C.c_char_p
LUA.lua_close.argtypes = [C.c_void_p]

def adler(data):
    return f'{zlib.adler32(data) & 0xffffffff:08x}'

def run_lua(case, output):
    state = LUA.luaL_newstate()
    LUA.luaL_openlibs(state)
    try:
        for key, value in {'TEST_CASE': case, 'SOURCE_PATH': str(SOURCE), 'OUTPUT_PATH': str(output)}.items():
            LUA.lua_pushstring(state, value.encode())
            LUA.lua_setglobal(state, key.encode())
        code = LUA.luaL_loadfilex(state, str(ROOT / 'tests/mock-feral-v3.lua').encode(), None)
        if code == 0:
            code = LUA.lua_pcallk(state, 0, 0, 0, 0, None)
        if code:
            raise AssertionError(LUA.lua_tolstring(state, -1, None).decode(errors='replace'))
    finally:
        LUA.lua_close(state)
    return json.loads(output.read_text())

def inspect_export(result):
    disk = result['disk']
    if not isinstance(disk, dict):
        assert result['case'] in ('missing_files','manual_ready','makefolder_false')
        return None
    disk = {key: value.encode('latin1') for key, value in disk.items()}
    manifests = [p for p in disk if p.endswith('/manifest.json')]
    if not manifests:
        assert result['case'] in ('read_corruption','makefolder_false'), result['notice']
        return None
    prefix = manifests[0][:-len('manifest.json')]
    manifest = json.loads(disk[manifests[0]])
    files = []
    def verify(meta):
        path = meta['path']
        assert not path.startswith('/') and '..' not in path.split('/'), path
        body = disk[prefix + path]
        assert len(body) == meta['bytes'], path
        assert adler(body) == meta['adler32'], path
    for cat in manifest['catalogs']:
        verify(cat)
        for line in disk[prefix + cat['path']].splitlines():
            meta = json.loads(line)
            verify(meta)
            files.append(meta)
    for meta in manifest['controls']:
        verify(meta)
    assert len(files) == manifest['files']['payload_count']
    assert len({x['path'] for x in files}) == len(files), 'duplicate payload paths'
    assert sum(x['bytes'] for x in files) == manifest['files']['payload_bytes']
    # Every prior immutable manifest remains independently verifiable after later saves.
    for path, body in disk.items():
        if '/checkpoints/manifest_' not in path:
            continue
        snapshot = json.loads(body)
        for cat in snapshot['catalogs']:
            verify(cat)
        for meta in snapshot['controls']:
            verify(meta)
    records = {}
    for meta in files:
        path = meta['path']
        if path.endswith('.ndjson'):
            family = path.split('/')[0]
            records.setdefault(family, []).extend(json.loads(line) for line in disk[prefix + path].splitlines())
    if manifest['phase'] not in ('starting', 'inventory', 'sources'):
        assert len(records.get('scripts', [])) == manifest['counts']['scripts']
        assert len(records.get('source-results', [])) == manifest['counts']['scripts']
        assert manifest['source_pending'] == 0
    objects = {x['id']: x for x in records.get('objects', [])}
    assert len(objects) == len(records.get('objects', [])), 'duplicate objects'
    all_payload = b'\n'.join(disk.values())
    for secret in ['PRIVATE_OTHER_NAME', 'PRIVATE_DISPLAY_NAME', 'PRIVATE_OTHER_ATTRIBUTE',
                   'PRIVATE_OTHER_SECRET', 'PRIVATE_ATTRIBUTE_TOKEN', 'PRIVATE_PASSWORD_VALUE',
                   'PRIVATE_WEBHOOK_VALUE', 'PRIVATE_PROFILE_ATTRIBUTE', 'PRIVATE_UI_CHAT_TEXT',
                   'PRIVATE_TEXTBOX_INPUT', 'PRIVATE_MESSAGE_NODE', 'PRIVATE_MESSAGE_TEXT',
                   'PRIVATE_MESSAGE_ATTRIBUTE', 'PRIVATE_COMMENT_TOKEN', 'PRIVATE_SOURCE_TOKEN',
                   'PRIVATE_LONG_LITERAL', 'PRIVATE_INLINE_COMMENT', 'private@example.test',
                   'PRIVATE_SERVER_SOURCE', 'PRIVATE_EXCEPTION_TEXT','PRIVATE_JSON_PASSWORD',
                   'PRIVATE_JSON_OTHER_DATA','PRIVATE_ENV_TOKEN']:
        assert secret.encode() not in all_payload, 'privacy leak: ' + secret
    for record in records.get('source-results', []):
        if record['status'] != 'exported':
            continue
        chunks = record['files']
        body = b''.join(disk[prefix + chunk['path']] for chunk in chunks)
        assert len(body) == record['exported_bytes']
        assert adler(body) == record['exported_adler32']
    # Portable ZIP round trip of the contract; Windows packer itself is a separate test.
    with tempfile.TemporaryFile() as fp:
        with zipfile.ZipFile(fp, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('manifest.json', disk[manifests[0]])
            for meta in files:
                archive.writestr(meta['path'], disk[prefix + meta['path']])
        fp.seek(0)
        with zipfile.ZipFile(fp) as archive:
            assert archive.testzip() is None
            for meta in files:
                assert adler(archive.read(meta['path'])) == meta['adler32']
    return manifest, records

def main():
    source = SOURCE.read_text()
    embedded = re.search(r'local PACKER = \[====\[\n(.*?)\n\]====\]', source, re.S).group(1)
    assert embedded + '\n' == (ROOT / 'Pack-FERAL.ps1').read_text(), 'embedded packer differs'
    assert '__FERAL_PACKER_BODY__' not in source
    for forbidden in [':FireServer(', ':InvokeServer(', ':Fire(', ':Invoke(', ':SetAttribute(',
                      'getrawmetatable(', 'hookmetamethod(', 'gethiddenproperty(', 'getgc(']:
        assert forbidden not in source, forbidden
    cases = sys.argv[1:] or ['normal','yielding','no_decompiler','no_readfile','cancel','pause',
        'timeouts','uncancellable','object_limit','memory_limit','deep','chunked','oversize',
        'stop_inventory','write_failure','read_corruption','missing_files','source_budget','config_limit','scale',
        'manual_ready','environment_apis','no_background_spawn','ui_optional_property','ui_drag_unavailable','makefolder_false','click_only']
    with tempfile.TemporaryDirectory(prefix='feral-v3-tests-') as tmp:
        for case in cases:
            result = run_lua(case, Path(tmp) / (case + '.json'))
            if case == 'manual_ready':
                assert result['status'] == 'READY - CLICK START SCAN'
                assert result['writes'] == 0 and result['decompile_calls'] == 0
                assert 'waiting_for_start' in result['clipboard']
                print('PASS manual_ready: visible Start control; no collection before the click')
                continue
            if case in ('missing_files','makefolder_false','read_corruption'):
                assert 'FERAL STARTUP REPORT v3.0.1' in result['clipboard']
                expected = {'missing_files':'missing_writefile_and_makefolder','makefolder_false':'makefolder_failed','read_corruption':'file_read_back_failed'}[case]
                assert expected in result['clipboard']
            inspected = inspect_export(result)
            if inspected:
                manifest, records = inspected
                if case == 'normal':
                    assert manifest['counts']['configurations'] == 1
                    assert manifest['counts']['activeAnimationTracks'] == 1
                    configs = [r['value'] for r in records['values'] if isinstance(r.get('value'),dict) and r['value'].get('type')=='json_configuration']
                    assert configs[0]['decoded']['stamina']['regen'] == 5
                    assert configs[0]['decoded']['password']['redacted']
                    assert any(isinstance(r['name'],dict) and r['name'].get('encoding')=='base64' for r in records['objects'])
                    assert len({p.split('/')[0] for p in result['disk']}) == 1, 'Start ran twice'
                if case == 'environment_apis':
                    assert manifest['api_resolution']['writefile'] == 'executor_environment'
                if case == 'scale':
                    assert manifest['counts']['scripts'] == 37991
                    assert manifest['counts']['eligible'] == 37990
                    assert manifest['counts']['sourceExported'] > 37980
                    assert manifest['script_counts_by_root']['CorePackages'] == 37984
                if case in ('cancel','stop_inventory','object_limit','memory_limit'):
                    assert manifest['phase'] == 'stopped_partial', manifest['phase']
                if case == 'no_readfile':
                    assert manifest['files']['unverified'] == manifest['files']['payload_count']
                if case == 'timeouts':
                    assert manifest['source_abort_reason'] == 'repeated_decompiler_timeouts'
                if case == 'uncancellable':
                    assert manifest['source_abort_reason'] == 'worker_could_not_be_cancelled'
                if case == 'pause':
                    assert result['pause_triggered']
                if case == 'oversize':
                    assert manifest['source_status_counts']['oversize_not_exported'] == 1
                if case == 'deep':
                    assert manifest['limits_hit']['hierarchy_depth']
                if case == 'source_budget':
                    assert manifest['source_abort_reason'] == 'export_byte_budget'
                if case == 'config_limit':
                    assert 'json_configuration_structure_limit' in json.dumps(records['values'])
                if case == 'chunked':
                    assert any(len(r.get('files',[])) > 1 for r in records['source-results'])
                print(f"PASS {case}: {manifest['phase']}, {manifest['counts']['objects']} objects, {manifest['files']['payload_count']} payload files")
            else:
                assert result['status'] == 'FAILED_PARTIAL'
                print(f'PASS {case}: explicitly refused/failed without a complete-export claim')

if __name__ == '__main__':
    main()
