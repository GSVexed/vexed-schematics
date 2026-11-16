"""Fault-injection tests for the final one-source supplement; no game execution."""
import importlib.util
import json
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('recovery_tests',ROOT/'tests/test-feral-recovery-v3.1.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
LUA = base.LUA
SOURCE = ROOT/'feral-final-gap-v3.2.lua'
TARGET = 'game/Workspace/LocalPlayer/Animate'

def run(case,folder):
    fixture = (ROOT/'tests/mock-feral-v3.lua').read_text().split('local text=assert(io.open(SOURCE_PATH')[0]
    if case == 'clean_capture':
        # Successful nullable reads for the optional allowlist in this fixture.
        # Source reads still hit the explicit permission-denied branch above it.
        fixture = fixture.replace('error(key .. " is not a valid member")','return nil')
    mock = (ROOT/'tests/mock-feral-recovery-v3.1.lua').read_text()
    mock = mock.replace('if cursor == services.Players and segments[i] == "LocalPlayer" then cursor = localPlayer',
        'if cursor == workspace and segments[i] == "LocalPlayer" then cursor = localCharacter\n'
        '        elseif cursor == services.Players and segments[i] == "LocalPlayer" then cursor = localPlayer')
    mock = mock.replace('if index == 1 or case == "all_invalid" then', 'if case == "all_invalid" then')
    mock = mock.replace('index == 2','index == 1')
    mock = mock.replace('decompileCalls == 3','decompileCalls == 1')
    mock = mock.replace('decompileCalls == 2','decompileCalls == 1')
    mock = mock.replace('local text = assert(io.open(SOURCE_PATH,"rb")):read("*a")',
        'newNode("Script","Health",localCharacter,{RunContext=Enum.RunContext.Legacy,mockSource="PRIVATE_SERVER_SOURCE"})\n'
        'if case == "rename_character" then localCharacter._props.Name = "DifferentRigName" end\n'
        'local text = assert(io.open(SOURCE_PATH,"rb")):read("*a")')
    mock = mock.replace('if case == "ingame_only" then spawnTiger();click("InGameCapture");return end',
        'if case ~= "normal" and case ~= "dual_capture" and case ~= "hide_show" and case ~= "ingame_before_spawn" then spawnTiger();click("InGameCapture");return end')
    mock = mock.replace('if case == "object_limit" then text = text:gsub("maxObjects = 300000"',
        'if case == "object_limit" then text = text:gsub("maxObjects = 50000"')
    harness = folder/'harness.lua'
    harness.write_text(fixture+'\n'+mock)
    output = folder/(case+'.json')
    state = LUA.luaL_newstate()
    LUA.luaL_openlibs(state)
    try:
        for key,value in {'TEST_CASE':case,'SOURCE_PATH':str(SOURCE),'OUTPUT_PATH':str(output),
                          'TEST_TARGETS':'return {{path='+json.dumps(TARGET)+'}}'}.items():
            LUA.lua_pushstring(state,value.encode());LUA.lua_setglobal(state,key.encode())
        code=LUA.luaL_loadfilex(state,str(harness).encode(),None)
        if code==0:code=LUA.lua_pcallk(state,0,0,0,0,None)
        if code:raise AssertionError(LUA.lua_tolstring(state,-1,None).decode(errors='replace'))
    finally:LUA.lua_close(state)
    return json.loads(output.read_text())

def main():
    source=SOURCE.read_text()
    for bad in [':FireServer(',':InvokeServer(',':Fire(',':Invoke(',':SetAttribute(','getgc(','gethiddenproperty(']:
        assert bad not in source,bad
    assert 'require(' not in '\n'.join(x.split('--')[0] for x in source.splitlines())
    cases=['manual_ready','normal','ingame_only','dual_capture','hide_show','ingame_before_spawn','wrong_mode',
        'rename_character','all_invalid','filter_regression','compiler_missing','compiler_throws','no_decompiler',
        'readable_source','missing_target','no_readfile','environment_apis','yielding','pause','cancel',
        'recovery_timeout','recovery_uncancellable','recovery_api_error','write_failure','read_corruption',
        'missing_files','makefolder_false','chunked_recovery','oversize_recovery','interpolated_recovery','text_only_files','clean_capture']
    with tempfile.TemporaryDirectory(prefix='feral-final-tests-') as tmp:
        folder=Path(tmp)
        for case in cases:
            result=run(case,folder)
            manifest,records=base.check_export(result)
            assert result['max_active_decompilers']<=1
            if case in ['manual_ready','ingame_before_spawn','wrong_mode']:
                assert result['writes']==result['decompile_calls']==0,(case,result)
            elif case in ['missing_files','makefolder_false','read_corruption']:
                assert result['status']=='failed_partial'
            else:
                assert manifest and manifest['schema']=='feral-final-supplement/3.2'
                assert manifest['target_count']==1
                assert manifest['known_syntax_failure_targets']==0
                assert manifest['unresolved_baseline_syntax_failures']==64
                assert manifest['all_original_game_sources_recovered'] is False
                targets=[r for k,v in records.items() if k.endswith('/target-results') for r in v]
                if case=='normal':
                    assert result['decompile_calls']==0 and not targets
                    assert result['status']=='menu_snapshot_saved' or result['status']=='finished_with_inventory_gaps'
                else:
                    assert all(r['path']==TARGET for r in targets)
                    assert len(targets)==1,(case,len(targets))
                    assert result['decompile_calls']<=2
                if case in ['ingame_only','rename_character','dual_capture','hide_show','readable_source','yielding','pause','text_only_files']:
                    assert targets[0]['status']=='exported',(case,targets)
                    assert manifest['live_source_collected'] is True
                if case=='rename_character':
                    objects=[r for k,v in records.items() if k.endswith('/objects') for r in v]
                    assert any(r['path']=='game/Workspace/LocalPlayer/Animate' for r in objects)
                if case=='all_invalid':
                    assert targets[0]['filtered_syntax']['status']=='reject'
                    assert targets[0]['identical_retry_stopped'] is True
                    assert result['status']=='finished_with_source_quality_gaps'
                if case=='cancel':assert result['status']=='stopped_partial'
                if case=='recovery_uncancellable':assert result['blocked'] is True
                if case=='no_readfile':assert manifest['files']['unverified']>0
                if case=='write_failure':assert result['status']=='failed_partial'
                if case=='clean_capture':
                    assert result['status']=='live_supplement_saved'
                    assert manifest['source_counts']['exported']==1
                    assert manifest['inventory_counts']['propertyFailures']==0
            print('PASS',case,result['status'],result['decompile_calls'],'decompiler calls')
    print(f'{len(cases)} final-supplement offline cases passed; Roblox/Velocity not tested here.')

if __name__=='__main__':main()
