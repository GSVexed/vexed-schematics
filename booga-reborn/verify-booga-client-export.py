"""Verify Booga Reborn client exports in ZIPs without extracting or executing content.

Usage: python verify-booga-export.py complete.zip
       python verify-booga-export.py metadata.zip data-001.zip data-002.zip
Python standard library only. Reports integrity separately from collection scope.
"""
import argparse
import json
from pathlib import PurePosixPath
import re
import sys
from zipfile import ZipFile, BadZipFile
import zlib

class VerificationError(ValueError):
    pass

def safe_path(name):
    if '\\' in name or name.startswith('/') or any(x in ('.','..') for x in name.split('/')):
        raise VerificationError('Unsafe archive or manifest path')
    parts=PurePosixPath(name).parts
    if not parts or any(':' in x for x in parts):
        raise VerificationError('Unsafe archive or manifest path')
    return parts

def verify(paths):
    archives=[]
    entries={}
    checked={}
    warnings=[]
    try:
        for path in paths:
            archive=ZipFile(path)
            archives.append(archive)
            for info in archive.infolist():
                parts=safe_path(info.filename)
                if info.is_dir():continue
                if info.file_size>64*1024*1024:
                    raise VerificationError('Individual archive member exceeds the 64 MiB verifier limit')
                # Windows may include a parent directory around an entire export.
                start=next((i for i,p in enumerate(parts) if re.fullmatch(r'UPLOAD_PART_\d{3}_(?:METADATA|DATA)',p)),None)
                if start is None:continue
                relative='/'.join(parts[start:])
                if relative in entries:
                    raise VerificationError('Duplicate export member across selected ZIPs: '+relative)
                entries[relative]=(archive,info)
        def read(path):
            safe_path(path)
            if path not in entries:raise VerificationError('Missing referenced file: '+path)
            archive,info=entries[path]
            return archive.read(info) # ZIP CRC is verified by ZipFile.read.
        def check(meta):
            path=meta['path']
            if path not in checked:
                body=read(path)
                checked[path]=(len(body),f'{zlib.adler32(body)&0xffffffff:08x}')
            observed=checked[path]
            if observed!=(meta['bytes'],meta['adler32']):
                raise VerificationError('Byte length/checksum mismatch: '+path)
        manifest=json.loads(read('UPLOAD_PART_000_METADATA/manifest.json.txt'))
        if manifest.get('schema') != 'booga-reborn-client-archive/1.0':
            raise VerificationError('Unsupported manifest schema')
        catalogs=manifest['catalogs']
        payloads=[]
        for catalog in catalogs:
            check(catalog)
            for line in read(catalog['path']).splitlines():
                meta=json.loads(line);check(meta);payloads.append(meta)
        if len(payloads)!=len({x['path'] for x in payloads}):
            raise VerificationError('Duplicate payload path in catalogs')
        for meta in manifest['controls']:check(meta)
        recorded=manifest['files']
        if len(payloads)!=recorded['payload_count'] or sum(x['bytes'] for x in payloads)!=recorded['payload_bytes']:
            raise VerificationError('Payload counts/bytes do not match manifest')
        for part in manifest['upload_parts']:
            marker=json.loads(read(part['folder']+'/UPLOAD_PART.json.txt'))
            if marker['session_id']!=manifest['session_id'] or marker['part_number']!=part['number']:
                raise VerificationError('Part/session marker mismatch: '+part['folder'])
            if marker.get('checkpoint')!=manifest.get('checkpoint') or marker.get('total_parts')!=len(manifest['upload_parts']):
                warnings.append('Advisory marker differs from selected manifest: '+part['folder'])
        source_checks=0
        bodies={}
        catalogued={x['path'] for x in payloads}
        for meta in payloads:
            if not meta['path'].endswith('.ndjson.txt'):continue
            # Inventory/property strings are data, never executed or imported.
            for line in read(meta['path']).splitlines():
                item=json.loads(line)
                if item.get('status')!='exported' or not isinstance(item.get('files'),list) or 'exported_bytes' not in item:continue
                key=tuple(x['path'] for x in item['files'])
                if not key:raise VerificationError('Exported source has no chunk references')
                if key not in bodies:
                    chunks=[]
                    for chunk in item['files']:
                        if chunk['path'] not in catalogued:raise VerificationError('Source chunk is outside payload catalog')
                        check(chunk);chunks.append(read(chunk['path']))
                    body=b''.join(chunks)
                    bodies[key]=(len(body),f'{zlib.adler32(body)&0xffffffff:08x}')
                if bodies[key]!=(item['exported_bytes'],item['exported_adler32']):
                    raise VerificationError('Whole-source length/checksum mismatch')
                source_checks+=1
        return {'integrity_ok':True,'schema':manifest['schema'],'session_id':manifest['session_id'],
                'booga_system_index':manifest.get('booga_system_index',{}),
            'manifest_phase':manifest['phase'],'parts':len(manifest['upload_parts']),
            'catalogs_checked':len(catalogs),'payload_files_checked':len(payloads),
            'payload_bytes_checked':sum(x['bytes'] for x in payloads),'source_reference_records_checked':source_checks,
            'canonical_source_bodies_checked':len(bodies),'source_pending':manifest.get('source_pending'),
            'limits_hit':manifest.get('limits_hit'),'declared_collection_gaps':manifest.get('collection_gaps'),
            'warnings':warnings,'note':'Integrity does not prove faithful decompilation or recovery of server-only, unreplicated or streamed-out game data.'}
    finally:
        for archive in archives:archive.close()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archives',nargs='+')
    args=parser.parse_args()
    try:result=verify(args.archives)
    except (VerificationError,KeyError,ValueError,OSError,RuntimeError,BadZipFile) as error:
        print(json.dumps({'integrity_ok':False,'error':str(error)},indent=2));return 1
    print(json.dumps(result,indent=2));return 0

if __name__=='__main__':sys.exit(main())
