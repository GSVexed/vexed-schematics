"""Offline fault injection for the two-capture supplement. Never runs game code."""
import ctypes as C
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('base_tests', ROOT / 'tests/test-feral-v3.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
LUA = base.LUA
SOURCE = ROOT / 'feral-recovery-supplement-v3.1.lua'
TARGETS = json.loads((ROOT / 'feral-recovery-targets-v3.1.json').read_text())['targets']

def quote_lua(value):
    return json.dumps(value)

def run(case, folder):
    prefix = (ROOT / 'tests/mock-feral-v3.lua').read_text().split('local text=assert(io.open(SOURCE_PATH')[0]
    harness = folder / 'harness.lua'
    harness.write_text(prefix + '\n' + (ROOT / 'tests/mock-feral-recovery-v3.1.lua').read_text())
    output = folder / (case + '.json')
    state = LUA.luaL_newstate()
    LUA.luaL_openlibs(state)
    try:
        target_lua = 'return {' + ','.join('{path=' + quote_lua(t['path']) + '}' for t in TARGETS) + '}'
        for key, value in {'TEST_CASE':case,'SOURCE_PATH':str(SOURCE),'OUTPUT_PATH':str(output),'TEST_TARGETS':target_lua}.items():
            LUA.lua_pushstring(state,value.encode())
            LUA.lua_setglobal(state,key.encode())
        status = LUA.luaL_loadfilex(state,str(harness).encode(),None)
        if status == 0:
            status = LUA.lua_pcallk(state,0,0,0,0,None)
        if status:
            raise AssertionError(LUA.lua_tolstring(state,-1,None).decode(errors='replace'))
    finally:
        LUA.lua_close(state)
    return json.loads(output.read_text())

def check_export(result):
    disk = {p:b.encode('latin1') for p,b in result['disk'].items()} if isinstance(result['disk'],dict) else {}
    for secret in ['PRIVATE_SOURCE_TOKEN','PRIVATE_COMMENT_TOKEN','PRIVATE_OTHER_NAME','PRIVATE_DISPLAY_NAME',
                   'PRIVATE_OTHER_SECRET','PRIVATE_PROFILE_ATTRIBUTE','PRIVATE_UI_CHAT_TEXT','PRIVATE_TEXTBOX_INPUT',
                   'PRIVATE_EXCEPTION_TEXT','PRIVATE_COMPILER_EXCEPTION','PRIVATE_BACKTICK_SECRET','PRIVATE_ATTRIBUTE_TOKEN',
                   'PRIVATE_PASSWORD_VALUE','PRIVATE_WEBHOOK_VALUE','PRIVATE_ENV_TOKEN']:
        assert secret.encode() not in b'\n'.join(disk.values()), secret
    assert all(p.endswith('.txt') for p in disk), 'non-text export'
    manifests = [p for p in disk if p.endswith('/UPLOAD_PART_000_METADATA/manifest.json.txt')]
    if not manifests:
        return None,{}
    prefix = manifests[0].split('/UPLOAD_PART_000_METADATA/')[0] + '/'
    manifest = json.loads(disk[manifests[0]])
    def verify(meta):
        body = disk[prefix + meta['path']]
        assert len(body) == meta['bytes'],meta['path']
        assert f'{zlib.adler32(body)&0xffffffff:08x}' == meta['adler32'],meta['path']
    payloads = []
    for meta in manifest['catalogs']:
        verify(meta)
        payloads.extend(json.loads(line) for line in disk[prefix+meta['path']].splitlines())
    for meta in payloads + manifest['controls']:
        verify(meta)
    assert len({x['path'] for x in payloads}) == len(payloads)
    assert len(payloads) == manifest['files']['payload_count']
    assert sum(x['bytes'] for x in payloads) == manifest['files']['payload_bytes']
    for p,b in disk.items():
        if '/checkpoints/manifest_' in p:
            prior = json.loads(b)
            for meta in prior['catalogs']+prior['controls']:
                verify(meta)
    records = {}
    for meta in payloads:
        if meta['path'].endswith('.ndjson.txt'):
            for record in map(json.loads,disk[prefix+meta['path']].splitlines()):
                records.setdefault(meta['path'].rsplit('/',1)[0],[]).append(record)
                if '/recovery-attempts/' in meta['path'] and record.get('status') == 'exported':
                    body = b''.join(disk[prefix+chunk['path']] for chunk in record['files'])
                    assert len(body) == record['exported_bytes']
                    assert f'{zlib.adler32(body)&0xffffffff:08x}' == record['exported_adler32']
    assert manifest['raw_sources_exported'] is False
    assert manifest['reconstructed_code_executed'] is False
    return manifest,records

def main():
    source = SOURCE.read_text()
    for bad in [':FireServer(',':InvokeServer(',':Fire(',':Invoke(',':SetAttribute(',
                'getrawmetatable(','hookmetamethod(','gethiddenproperty(','getgc(']:
        assert bad not in source,bad
    assert 'require(' not in '\n'.join(line.split('--')[0] for line in source.splitlines())
    assert source.count('local RECOVERY_PLAN =') == 1
    assert len(TARGETS) == 71
    assert sum(x['reason']=='known_syntax_failure' for x in TARGETS) == 64
    cases = sys.argv[1:] or ['manual_ready','normal','dual_capture','ingame_only','ingame_before_spawn','wrong_mode',
        'double_click','hide_show','all_invalid','retry_improves','filter_regression','compiler_missing','compiler_throws',
        'missing_target','no_decompiler','readable_source','no_readfile','environment_apis','yielding','pause','cancel',
        'recovery_timeout','recovery_uncancellable','recovery_api_error','write_failure','read_corruption','missing_files',
        'makefolder_false','chunked_recovery','oversize_recovery','object_limit','interpolated_recovery','text_only_files','pause_observation']
    with tempfile.TemporaryDirectory(prefix='feral-recovery-tests-') as tmp:
        folder = Path(tmp)
        for case in cases:
            result = run(case,folder)
            manifest,records = check_export(result)
            assert result['max_active_decompilers'] <= 1,(case,result['max_active_decompilers'])
            if case in ['manual_ready','ingame_before_spawn','wrong_mode']:
                assert result['writes'] == result['decompile_calls'] == 0
            elif case in ['missing_files','makefolder_false','read_corruption']:
                assert result['status'] == 'failed_partial'
                assert result['blocked'] is True
            else:
                assert manifest is not None,(case,result['clipboard'])
                targets = [r for k,v in records.items() if k.endswith('/target-results') for r in v]
                attempts = [r for k,v in records.items() if k.endswith('/recovery-attempts') for r in v]
                observations = [r for k,v in records.items() if k.endswith('/observations') for r in v]
                if case != 'write_failure':
                    count = 2 if case in ['dual_capture','hide_show'] else 1
                    assert len(targets) == 71*count,(case,len(targets))
                    assert len({(r['capture_id'],r['target']) for r in targets}) == len(targets)
                if case in ['dual_capture','hide_show']:
                    assert result['status'] == 'finished'
                    assert [c['mode'] for c in result['captures']] == ['menu','ingame']
                    assert len({p.split('/')[0] for p in result['disk']}) == 1
                    assert any(r.get('same_filtered_as_previous_capture_or_attempt') for r in attempts)
                    assert any(r['context']['active'] and r['context']['species'] == 'Tiger' for r in observations)
                    assert any(r['context']['menu_open'] is False for r in observations)
                if case == 'all_invalid':
                    assert result['decompile_calls'] <= 142
                    assert any(r.get('identical_retry_stopped') for r in targets)
                if case == 'filter_regression':
                    assert result['filter_regressions'] > 0
                    assert any(r.get('filter_comparison') == 'filter_regression' for r in attempts)
                if case == 'retry_improves':
                    assert any(r.get('selected_attempt') == 2 and r.get('filtered_syntax',{}).get('status') == 'pass' for r in targets)
                if case in ['compiler_missing','compiler_throws']:
                    assert not result['compiler_ready']
                if case == 'readable_source':
                    assert result['decompile_calls'] == 0
                if case == 'cancel':
                    assert result['status'] == 'stopped_partial'
                    assert any(r['status'] == 'stopped_before_target' for r in targets)
                if case == 'recovery_timeout':
                    assert result['decompile_calls'] == 3
                    assert manifest['source_abort_reason'] == 'repeated_decompiler_timeouts'
                if case == 'recovery_uncancellable':
                    assert result['decompile_calls'] == 1 and result['blocked'] is True
                if case == 'write_failure':
                    assert result['status'] == 'failed_partial'
                    assert any(p.endswith('/FAILURE.json.txt') for p in result['disk'])
                if case == 'pause_observation':
                    capture = manifest['captures'][0]
                    assert capture['trace_active_seconds'] >= 2
                    assert capture['trace_observed_seconds'] >= 5
                    assert capture['trace_finished'] is True
            print(f'PASS {case}: {result["status"]}; {result["decompile_calls"]} decompiler calls')
    print(f'{len(cases)} offline recovery cases passed. Roblox/Velocity runtime not tested here.')

if __name__ == '__main__':
    main()
