#!/usr/bin/env python3
import argparse,hashlib,json,re,subprocess,tempfile
from pathlib import Path
from build import ROOT,DEST,VERSION,build
def long(s): return '[====================[\n'+s+']====================]'
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--luau',default='luau');ap.add_argument('--compiler',default='luau-compile');a=ap.parse_args()
    manifest=build();compiled=[]
    loader=ROOT.parent/f'feral-renaissance-v{VERSION}-loader.lua'
    paths=[*(ROOT/'src').glob('*.luau'),ROOT/'tests/mock_roblox.luau',DEST]
    if loader.exists(): paths.append(loader)
    for path in paths:
        r=subprocess.run([a.compiler,'--null',str(path)],capture_output=True,text=True)
        if r.returncode: raise RuntimeError(r.stdout+r.stderr)
        compiled.append(str(path.relative_to(ROOT.parent)))
    raw=DEST.read_text()
    for name,body in re.findall(r'sources\["(.*?)"\] = \[============\[\n(.*?)\]============\]',raw,re.S):
        assert body==(ROOT/'src'/(name+'.luau')).read_text(),name
    assert not re.search(r'FireServer\s*\(\s*["\']Bite(?:Hit)?["\']',raw)
    assert not re.search(r'\.Health\s*(?:[+*/-]?=)',raw)
    assert not re.search(r'(?:setAttribute|SetAttribute)\([^\n]*["\'](?:Hunger|Thirst|Stamina|StaminaMax)["\']\s*,',raw)
    legacy=ROOT.parent/'renaissance'
    definitions={'BUNDLE':raw,'MOCK_SOURCE':(ROOT/'tests/mock_roblox.luau').read_text(),
                 'LOADER':loader.read_text() if loader.exists() else '',
                 'BASELINE':(ROOT.parent/'feral-renaissance-v15.2.1.lua').read_text(),
                 'PREVIOUS':(ROOT.parent/'feral-renaissance-v15.3.0.lua').read_text(),
                 'PERF_SOURCE':(legacy/'tests/performance.luau').read_text()}
    chunks='local CHUNK_SIZES={'+','.join(str(p['bytes']) for p in manifest['chunks'])+'}\n'
    script='\n'.join('local '+k+' = '+long(v) for k,v in definitions.items())+'\n'+chunks+(ROOT/'tests/suite.luau').read_text()
    with tempfile.TemporaryDirectory(prefix='feral-v16-test-') as d:
        p=Path(d)/'tests.luau';p.write_text(script)
        r=subprocess.run([a.luau,str(p)],capture_output=True,text=True)
    (ROOT/'test-output.log').write_text(r.stdout+r.stderr)
    lines=r.stdout.splitlines();match=re.search(r'RENAISSANCE_TEST_RESULT total=(\d+) passed=(\d+) failed=(\d+)',r.stdout)
    print('\n'.join(l for l in lines if l.startswith('FAIL ') or 'TEST_RESULT' in l))
    if not match: print(r.stderr[-4000:])
    record={'version':VERSION,'compiled':compiled,'module_parity':True,'bundle_sha256':manifest['bundle_sha256'],
            'regressions':dict(zip(('total','passed','failed'),map(int,match.groups()))) if match else None,
            'runtime_exit_code':r.returncode,'live_gameplay_verified':False,'results':lines}
    (ROOT/'test-results.json').write_text(json.dumps(record,indent=2)+'\n')
    if r.returncode or not match: raise SystemExit(1)
if __name__=='__main__':main()
