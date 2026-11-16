"""Validate the data-only standalone diagnostic.

Run from any directory with Python 3. No dependencies or network required.
"""
from pathlib import Path

root = Path(__file__).resolve().parent
target = root / 'feral-complete-diagnostic-v3.0.2.lua'
source = target.read_text(encoding='utf-8')
assert 'output_format = "data_only_text"' in source
assert 'local PACKER =' not in source and 'local PACK_CMD =' not in source
assert 'version = "3.0.2"' in source
print('Validated standalone v3.0.2: data-only text output, no embedded packaging helpers.')
