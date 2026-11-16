"""Execute the legacy PowerShell packer against a synthetic v3.0.1 export.

Current v3.0.2 exports no executable helpers and uses Windows ZIP; its native
upload folders are tested in test-feral-v3.py. This retains the earlier packer
regression checks without requiring the new diagnostic to save PowerShell files.

Usage: python3 roblox-tools/tests/test-packer-v3.py /path/to/pwsh
Runs locally without Roblox. Windows PowerShell 5.1 still needs a Windows check.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile
import zlib

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('feral_tests', HERE / 'test-feral-v3.py')
tests = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tests)
tests.SOURCE = tests.ROOT / 'feral-complete-diagnostic-v3.0.1.lua'
PWSH = sys.argv[1] if len(sys.argv) > 1 else 'pwsh'

def descriptor(path, body):
    return {'path': path, 'bytes': len(body), 'adler32': f'{zlib.adler32(body) & 0xffffffff:08x}', 'read_back_verified': True}

def pack(folder, success=True):
    result = subprocess.run([PWSH, '-NoProfile', '-File', str(folder / 'Pack-FERAL.ps1'),
                             '-ExportFolder', str(folder), '-PartMiB', '8'], capture_output=True, text=True)
    if success:
        assert result.returncode == 0, result.stdout + result.stderr
        indexes = sorted(folder.parent.glob(folder.name + '_UPLOAD_*/UPLOAD_INDEX.json'))
        assert indexes, result.stdout
        return indexes[-1], result
    assert result.returncode != 0, 'Corrupt export incorrectly packaged successfully'
    return result.stdout + result.stderr

def verify_archives(index_file):
    index = json.loads(index_file.read_text())
    paths = []
    for part in index['parts']:
        archive = index_file.parent / part['file']
        assert archive.stat().st_size == part['bytes']
        assert hashlib.sha256(archive.read_bytes()).hexdigest() == part['sha256']
        with zipfile.ZipFile(archive) as z:
            assert z.testzip() is None
            info = json.loads(z.read('UPLOAD_PART.json'))
            assert info['total_parts'] == index['total_parts']
            assert sorted(info['files']) == sorted(part['files'])
            assert sorted(z.namelist()) == sorted(part['files'] + ['manifest.json','UPLOAD_PART.json'])
            paths.extend(part['files'])
    assert len(paths) == len(set(paths))
    return index, paths

def main():
    with tempfile.TemporaryDirectory(prefix='feral-packer-tests-') as work:
        work = Path(work)
        result = tests.run_lua('chunked', work / 'fixture.json')
        disk = {k: v.encode('latin1') for k,v in result['disk'].items()}
        prefix = next(p[:-len('manifest.json')] for p in disk if p.endswith('/manifest.json'))
        folder = work / prefix.rstrip('/')
        for path, body in disk.items():
            file = work / path
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(body)
        manifest = json.loads((folder / 'manifest.json').read_bytes())
        # Many small payloads force independent volumes at the minimum 8 MiB target.
        extra = []
        for i in range(36):
            path = f'packing-fixture/chunk_{i:03}.bin'
            body = bytes((n + i) % 256 for n in range(524288))
            file = folder / path
            file.parent.mkdir(exist_ok=True)
            file.write_bytes(body)
            extra.append(descriptor(path,body))
        catalog_body = ''.join(json.dumps(x) + '\n' for x in extra).encode()
        catalog_path = 'catalog/packing_fixture.ndjson'
        (folder / catalog_path).write_bytes(catalog_body)
        manifest['catalogs'].append(descriptor(catalog_path,catalog_body))
        manifest['files']['payload_count'] += len(extra)
        manifest['files']['payload_bytes'] += sum(x['bytes'] for x in extra)
        (folder / 'manifest.json').write_text(json.dumps(manifest))
        index_path,_ = pack(folder)
        index,paths = verify_archives(index_path)
        assert index['total_parts'] >= 3
        assert set(x['path'] for x in extra).issubset(paths)
        print(f"PASS actual PowerShell ZIP split + checksums + round trip ({index['total_parts']} independent parts)")

        target = folder / extra[0]['path']
        body = target.read_bytes()
        target.write_bytes(b'X' + body[1:])
        assert 'Checksum mismatch' in pack(folder,False)
        target.write_bytes(body)
        target.unlink()
        assert 'Missing file' in pack(folder,False)
        target.write_bytes(body)
        print('PASS packer refuses altered and missing payloads')

        original_manifest = (folder / 'manifest.json').read_bytes()
        changed = json.loads(original_manifest)
        changed['controls'][0]['path'] = '../outside'
        (folder / 'manifest.json').write_text(json.dumps(changed))
        assert 'leaves its folder' in pack(folder,False)
        (folder / 'manifest.json').write_bytes(original_manifest)
        print('PASS packer rejects paths outside the export')

        (folder / 'manifest.json').write_bytes(b'broken latest manifest')
        fallback_index,_ = pack(folder)
        fallback,_ = verify_archives(fallback_index)
        assert fallback['used_checkpoint_fallback']
        (folder / 'manifest.json').write_bytes(original_manifest)
        print('PASS immutable manifest fallback after latest-manifest corruption')

        (folder / 'FAILURE.json').write_text(json.dumps({'phase':'failed_partial','reason':'simulated_write_failure'}))
        failure_index,_ = pack(folder)
        failure,paths = verify_archives(failure_index)
        assert failure['pipeline_failure_reported'] and 'FAILURE.json' in paths
        print('PASS pipeline failure report is preserved and labelled')

if __name__ == '__main__':
    main()
