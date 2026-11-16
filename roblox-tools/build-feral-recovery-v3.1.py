"""Build the self-contained recovery supplement from the tested v3.0.3 core.

No diagnostic export or reconstructed game source is embedded in the launcher.
Only target paths, prior filtered checksums and prior syntax classifications are.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
base = (ROOT / 'feral-complete-diagnostic-v3.0.3.lua').read_text()
targets = json.loads((ROOT / 'feral-recovery-targets-v3.1.json').read_text())
assert targets['known_syntax_failures'] == 64
assert len(targets['targets']) == 71
assert len({x['path'] for x in targets['targets']}) == 71

# Preserve the existing bounded traversal, privacy, serialization and verified
# text-export code. UI, orchestration and source handling below are independent.
foundation = base[:base.index('-- UI implementation is kept inside a closure')]
foundation = foundation.replace('version = "3.0.3"', 'version = "3.1"')
foundation = foundation.replace('"FeralCompleteDiagnosticV303"}', '"FeralCompleteDiagnosticV303", "FeralRecoverySupplementV31"}')
foundation = foundation.replace('maxObjects = 600000', 'maxObjects = 300000')
foundation = foundation.replace('maxExportBytes = 2147483648', 'maxExportBytes = 536870912')
foundation = foundation.replace('sourceTimeoutSeconds = 12', 'sourceTimeoutSeconds = 8')
foundation = foundation.replace('Click START SCAN to begin.', 'Choose MENU CAPTURE or IN-GAME CAPTURE.')
foundation = foundation.replace('Click the green START SCAN button.', 'Choose a capture for your current game state.')
foundation = foundation.replace('bytecode = resolveApi("getscriptbytecode",getscriptbytecode),',
    'compile = resolveApi("loadstring",loadstring),')
foundation = foundation.replace('"getloadedmodules","getscripts","getscriptbytecode","setclipboard","toclipboard"',
    '"getloadedmodules","getscripts","loadstring","setclipboard","toclipboard"')
foundation = foundation.replace('-- FERAL Complete Diagnostic v3.0.3 - manual start and observable startup.',
    '-- FERAL Recovery Supplement v3.1 - MENU and IN-GAME capture controls.')
foundation = foundation.replace('-- Source reconstruction is optional and executor-dependent. See README-v3.0.md.',
    '-- Read README-recovery-v3.1.md. Syntax checking compiles but NEVER runs game code.')
helpers = base[base.index('function D.control('):base.index('function D.preflight(')]
helpers = helpers.replace('feral-upload-folder/3.0.3', 'feral-upload-folder/3.1')
# This manifest definition is replaced by the supplement's scoped manifest.
helpers = helpers[:helpers.index('function D.manifest(')] + helpers[helpers.index('function D.checkpoint('):]
helpers = helpers.replace('    while D.paused and not D.stop do',
    '    local pauseBegin = os.clock()\n    while D.paused and not D.stop do')
helpers = helpers.replace('    local memory = D.memoryMiB()',
    '    D.pausedSeconds = (D.pausedSeconds or 0) + (os.clock() - pauseBegin)\n    local memory = D.memoryMiB()')
inventory = base[base.index('function D.refreshPrivacy('):base.index('function D.supplementalInventory(')]

def lua(value):
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=True)
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        return '{\n' + ',\n'.join(lua(v) for v in value) + '\n}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    raise TypeError(type(value))

runtime = (ROOT / 'feral-recovery-runtime-v3.1.lua').read_text()
output = foundation + '\n' + helpers + '\n' + inventory + '\nlocal RECOVERY_PLAN = ' + lua(targets) + '\n' + runtime
target = ROOT / 'feral-recovery-supplement-v3.1.lua'
target.write_text(output)
print(f'Built {target.name}: {len(output.encode()):,} bytes; {len(targets["targets"])} targets')
