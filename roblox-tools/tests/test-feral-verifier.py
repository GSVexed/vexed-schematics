"""Malformed-export cases for the standalone ZIP integrity verifier."""
import importlib.util
import json
from pathlib import Path
import tempfile
from zipfile import ZipFile
import zlib

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('verifier',ROOT/'verify-feral-export.py')
v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
def meta(path,body):return {'path':path,'bytes':len(body),'adler32':f'{zlib.adler32(body)&0xffffffff:08x}'}
def dataset():
    source=b'return {value=1}'
    sp='UPLOAD_PART_001_DATA/sources/test.source.txt'
    record={'status':'exported','files':[meta(sp,source)],'exported_bytes':len(source),'exported_adler32':meta(sp,source)['adler32']}
    rp='UPLOAD_PART_001_DATA/source-results/game_00001.ndjson.txt'
    records=(json.dumps(record)+'\n').encode()
    cp='UPLOAD_PART_000_METADATA/catalog/files_00001.ndjson.txt'
    catalog=b''.join((json.dumps(x)+'\n').encode() for x in [meta(sp,source),meta(rp,records)])
    m={'schema':'feral-final-supplement/3.2','session_id':'test','phase':'finished_with_source_quality_gaps','checkpoint':1,
       'catalogs':[meta(cp,catalog)],'controls':[],'files':{'payload_count':2,'payload_bytes':len(source)+len(records)},
       'upload_parts':[{'folder':'UPLOAD_PART_000_METADATA','number':0},{'folder':'UPLOAD_PART_001_DATA','number':1}]}
    files={sp:source,rp:records,cp:catalog,'UPLOAD_PART_000_METADATA/manifest.json.txt':json.dumps(m).encode()}
    for part in m['upload_parts']:
        files[part['folder']+'/UPLOAD_PART.json.txt']=json.dumps({'session_id':'test','part_number':part['number'],'checkpoint':1,'total_parts':2}).encode()
    return files
def main():
    with tempfile.TemporaryDirectory() as tmp:
        for case in ['valid','wrapped','split','changed_payload','missing_source','unsafe_path','wrong_session','bad_source_reference']:
            files=dataset()
            if case=='changed_payload':files['UPLOAD_PART_001_DATA/sources/test.source.txt']=b'CORRUPT'
            if case=='missing_source':files.pop('UPLOAD_PART_001_DATA/sources/test.source.txt')
            if case=='unsafe_path':files['../escape.txt']=b'no extraction'
            if case=='wrong_session':files['UPLOAD_PART_001_DATA/UPLOAD_PART.json.txt']=b'{"session_id":"other","part_number":1}'
            if case=='bad_source_reference':
                rp='UPLOAD_PART_001_DATA/source-results/game_00001.ndjson.txt'
                r=json.loads(files[rp]);r['exported_adler32']='00000000';files[rp]=(json.dumps(r)+'\n').encode()
                cp='UPLOAD_PART_000_METADATA/catalog/files_00001.ndjson.txt'
                files[cp]=b''.join((json.dumps(meta(p,files[p]))+'\n').encode() for p in ['UPLOAD_PART_001_DATA/sources/test.source.txt',rp])
                mp='UPLOAD_PART_000_METADATA/manifest.json.txt';m=json.loads(files[mp]);m['catalogs']=[meta(cp,files[cp])];m['files']['payload_bytes']=len(files[rp])+len(files['UPLOAD_PART_001_DATA/sources/test.source.txt']);files[mp]=json.dumps(m).encode()
            paths=[]
            for number in range(2 if case=='split' else 1):
                path=Path(tmp)/f'{case}-{number}.zip';paths.append(path)
                with ZipFile(path,'w') as z:
                    for name,body in files.items():
                        if case=='split' and name.startswith('UPLOAD_PART_000')!=(number==0):continue
                        z.writestr(('Session/' if case=='wrapped' else '')+name,body)
            try:result=v.verify(paths)
            except (v.VerificationError,KeyError,ValueError):
                assert case not in ['valid','wrapped','split'],case
            else:
                assert case in ['valid','wrapped','split'],case
                assert result['source_reference_records_checked']==1 and result['integrity_ok']
            print('PASS',case)
if __name__=='__main__':main()
