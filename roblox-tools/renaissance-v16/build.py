#!/usr/bin/env python3
"""Deterministic packaging from recovered 16.3.2 modules, with rollback guards."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parent
VERSION='16.4.3-rc1'
DEST=ROOT.parent/f'feral-renaissance-v{VERSION}.lua'
PROTECTED={
    'feral-renaissance-v16.3.2.lua':'2ff67bdc354de536eb3085828414709542c9da38c1e42b50f0fdc85052ab0ec8',
    'feral-renaissance-v16.3.2-loader.lua':'461d5ed28249bbb68b24f8caac75404208d8a7904810c22d143ad8e92c9580e5',
    'feral-renaissance-v16.4.0-rc1.lua':'4a25b0a6970bf0f0bf0114a70aa186bd7d11f1f276e2e81b596f7832ddda5a15',
    'feral-renaissance-v16.4.0-rc1-loader.lua':'90c85df32266b1f1733193015ed48e8d67150be4df5f693fc2e56635949b5867',
    'feral-renaissance-v16.4.1-exp1.lua':'b5ca78b29a8cfc37bfada425561398cda72fa679e83397433c6fdb049d5fba67',
    'feral-renaissance-v16.4.1-exp1-loader.lua':'d2256f36f0340f3d18bb201613e12c9c1cab07537b35726b7eec0a33ff3871c5',
    'feral-renaissance-v16.4.2-rc1.lua':'3b06c5f8e3790f67b744b0a263fb58003481c007165183d8b0e0ae1e310f8f1e',
    'feral-renaissance-v16.4.2-rc1-loader.lua':'65dabd7cd958a961641c67d861faf193aa5eaba729c906c20e3f12497c4a1134',
}
def sha(raw): return hashlib.sha256(raw).hexdigest()
def build():
    for name,digest in PROTECTED.items():
        if sha((ROOT.parent/name).read_bytes())!=digest: raise RuntimeError('Rollback changed: '+name)
    template=(ROOT/'bootstrap.luau').read_text()
    order=json.loads('['+re.search(r'local moduleOrder = \{(.*?)\}',template).group(1)+']')
    records={};chunks=[]
    for name in order:
        data=(ROOT/'src'/(name+'.luau')).read_bytes()
        assert b']============]' not in data
        records[name]={'bytes':len(data),'sha256':sha(data)}
        chunks.append('sources["'+name+'"] = [============[\n'+data.decode()+']============]')
    fingerprint=sha(json.dumps(records,sort_keys=True,separators=(',',':')).encode())
    boot=template.replace('@VERSION@',VERSION).replace('@FINGERPRINT@',fingerprint)
    source='\n'.join([f'-- FERAL Project Renaissance {VERSION} | audited captures v2412 and v2415',
            '-- Release candidate: offline tests do not establish live server outcomes.',
            'local options = ...','if type(options) ~= "table" then options = {} end','local sources = {}',*chunks,boot.rstrip()])+'\n'
    raw=source.encode();DEST.write_bytes(raw)
    parts=[];folder=ROOT/'chunks'/VERSION;folder.mkdir(parents=True,exist_ok=True)
    offset=0
    while offset<len(raw):
        stop=min(offset+93000,len(raw))
        while stop<len(raw) and raw[stop]&0xc0==0x80: stop-=1
        block=raw[offset:stop];block.decode('utf-8')
        path=folder/f'part-{len(parts)+1:02}.lua';path.write_bytes(block)
        parts.append({'path':str(path.relative_to(ROOT.parent.parent)),'bytes':len(block),'sha256':sha(block)})
        offset=stop
    result={'version':VERSION,'channel':'release-candidate','source_baseline':2412,'audited_captures':[2412,2415],
            'bundle_bytes':len(raw),'bundle_sha256':sha(raw),'source_fingerprint':fingerprint,
            'modules':records,'chunks':parts,'rollback_protected':PROTECTED,'live_gameplay_verified':False}
    (ROOT/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    return result
if __name__=='__main__':
    r=build();print(json.dumps({k:v for k,v in r.items() if k not in ('modules','chunks')},indent=2))
