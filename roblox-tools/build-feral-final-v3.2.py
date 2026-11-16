"""Build the small final live-source supplement from the tested 3.1 collector.

The full 3.0.3 export and verified 3.1 captures remain the project baseline.
This does not repeat their source or world passes.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
source = (ROOT / 'feral-recovery-supplement-v3.1.lua').read_text()
core = source[:source.index('local RECOVERY_PLAN =')]
core = core.replace('version = "3.1"', 'version = "3.2"')
core = core.replace('"FeralRecoverySupplementV31"}', '"FeralRecoverySupplementV31", "FeralFinalGapV32"}')
core = core.replace('maxObjects = 300000', 'maxObjects = 50000')
core = core.replace('feral-upload-folder/3.1', 'feral-upload-folder/3.2')
core = core.replace('-- FERAL Recovery Supplement v3.1 - MENU and IN-GAME capture controls.',
    '-- FERAL Final Live Supplement v3.2 - collects the last known live client source.')
core = core.replace('README-recovery-v3.1.md', 'README-final-v3.2.md')
core = core.replace('Choose MENU CAPTURE or IN-GAME CAPTURE.', 'Choose MENU SNAPSHOT or CAPTURE LIVE SOURCE.')
core = core.replace('    if obj == game then path = "game" end',
    '    if obj == game then path = "game" end\n    if frame.forcePath then path = frame.forcePath end')
plan = {
    'schema':'feral-final-targets/3.2',
    'baseline_session':'20261116_042419_33AB9E25F8D1',
    'verified_recovery_session':'20261116_052501_0B08C69B24CD',
    'unresolved_baseline_syntax_failures':64,
    'targets':[{
        'key':'L0001','path':'game/Workspace/LocalPlayer/Animate','previous_id':11945,
        'reason':'live_character_source_not_collected_in_v3_1',
        'previous_filtered_bytes':265,'previous_filtered_adler32':'d00a5361',
        'baseline_comparison_kind':'starter_template_only_not_same_instance',
    }],
}

def lua(value):
    if isinstance(value,str): return json.dumps(value)
    if isinstance(value,int): return str(value)
    if isinstance(value,list): return '{'+','.join(lua(x) for x in value)+'}'
    if isinstance(value,dict): return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'
    raise TypeError(type(value))

runtime = (ROOT / 'feral-recovery-runtime-v3.1.lua').read_text()
runtime = runtime[:runtime.index('local uiOk,uiError = pcall(D.createUI)')]
# Reuse verified syntax comparison, source export, worker and control functions.
# Final overrides below replace the 71-path orchestration and world inventory.
runtime = runtime.replace('FeralRecoverySupplementV31', 'FeralFinalGapV32')
runtime = runtime.replace('RECOVERY SUPPLEMENT v3.1', 'FINAL LIVE SUPPLEMENT v3.2')
runtime = runtime.replace('v3.1', 'v3.2').replace('/3.1', '/3.2')
runtime = runtime.replace('"FERAL_Recovery_v3_1_"', '"FERAL_Final_v3_2_"')
runtime = runtime.replace('D.expectedSpecies,D.traceSeconds,D.traceInterval = "Tiger",30,0.1',
    'D.expectedSpecies,D.traceSeconds,D.traceInterval = "Tiger",5,0.1')
runtime = runtime.replace('if cursor == Players and segment == "LocalPlayer" then cursor = player',
    'if cursor == workspace and segment == "LocalPlayer" then\n'
    '                local ok,character = D.read(player,"Character")\n'
    '                if not ok or typeof(character) ~= "Instance" then return nil,"local_character_not_present" end\n'
    '                cursor = character\n'
    '            elseif cursor == Players and segment == "LocalPlayer" then cursor = player')
runtime = runtime.replace('previous_id = target.previous_id,',
    'previous_id = target.previous_id,baseline_comparison_kind = target.baseline_comparison_kind,')
runtime = runtime.replace('Recovering 71 selected paths; Roblox platform sources remain in the prior export.',
    'Collecting the live Animate source; previous game/platform sources are retained.')
# Text used by the inherited UI; the 71-path plan itself is not embedded.
runtime = runtime.replace('Choose MENU CAPTURE first, then spawn as a Tiger and choose IN-GAME CAPTURE.',
    'Spawn as a Tiger and click CAPTURE LIVE SOURCE. Menu snapshot is optional.')
runtime = runtime.replace('64 syntax failures + 7 review paths | same folder for both captures',
    'One remaining live client source | earlier exports retained')
runtime = runtime.replace('1. MENU CAPTURE', 'MENU SNAPSHOT')
runtime = runtime.replace('2. IN-GAME CAPTURE', 'CAPTURE LIVE SOURCE')
runtime = runtime.replace('click IN-GAME CAPTURE', 'click CAPTURE LIVE SOURCE')
runtime = runtime.replace('MENU CAPTURE', 'MENU SNAPSHOT').replace('IN-GAME CAPTURE', 'CAPTURE LIVE SOURCE')
runtime = runtime.replace('Menu: click 1 and wait. Then spawn as a Tiger, close the animal menu and click 2. The in-game observation takes 30 seconds before source recovery and world inventory. ZIP the entire folder after both captures finish.',
    'Already scanned? Spawn as a Tiger and click CAPTURE LIVE SOURCE. It records 5 seconds and collects live Animate plus your own hierarchy. ZIP this small supplement when it finishes. Menu snapshot is optional.')
runtime = runtime.replace('" / 71 | saved payloads "', '" / " .. #RECOVERY_PLAN.targets .. " | saved payloads "')
final = (ROOT / 'feral-final-runtime-v3.2.lua').read_text()
output = core + '\nlocal RECOVERY_PLAN = ' + lua(plan) + '\n' + runtime + '\n' + final
path = ROOT / 'feral-final-gap-v3.2.lua'
path.write_text(output)
print(f'Built {path.name}: {len(output.encode()):,} bytes; one live source target.')
