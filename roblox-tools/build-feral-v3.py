"""Embed the reviewed local Windows packer into the standalone v3.0 loader.

Run from any directory with Python 3. No dependencies or network required.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parent
target = root / 'feral-complete-diagnostic-v3.0.1.lua'
packer = (root / 'Pack-FERAL.ps1').read_text(encoding='utf-8')
if ']====]' in packer:
    raise SystemExit('Packer conflicts with the Lua long-string delimiter')
source = target.read_text(encoding='utf-8')
pattern = r'local PACKER = \[====\[\n.*?\n\]====\]'
source, count = re.subn(pattern, lambda _: 'local PACKER = [====[\n' + packer.rstrip('\n') + '\n]====]', source, count=1, flags=re.S)
if count != 1:
    raise SystemExit('Exactly one packer block is required')
target.write_text(source, encoding='utf-8')
print('Embedded Pack-FERAL.ps1 into the standalone Lua source.')
