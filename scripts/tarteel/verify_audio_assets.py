"""Validate the reviewed, locally packaged sound manifest without network access."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2] / 'apps/mobile'
manifest = json.loads((root / 'assets/audio/manifest.json').read_text())
seen = set()
for asset in manifest['assets']:
    path = Path(asset['path'])
    assert str(path).startswith('assets/audio/') and '..' not in path.parts
    assert asset['path'] not in seen
    seen.add(asset['path'])
    data = (root / path).read_bytes()
    assert hashlib.sha256(data).hexdigest() == asset['sha256'], path
    assert data[:4] in (b'OggS', b'RIFF'), path
    assert asset['author'] and asset['source'] and asset['licenseUrl'].startswith('https://creativecommons.org/')
    if asset['kind'] == 'adhan_recording':
        assert asset['durationSeconds'] > 140
        assert asset['license'] in ('CC-BY-3.0', 'CC-BY-SA-4.0')
print(f'PASS: {len(seen)} packaged sounds, checksums and source/license records')
