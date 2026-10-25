"""Verify the durable beta2 preview identity without weakening the2074 gate."""
import argparse
import hashlib
import json
import re
import subprocess
import zipfile
from pathlib import Path

PREVIEW_CERT = '5e2a2a7412c93c8a0e9e28917195534b726c9c1ae3a35232e9fd0aeb5fa718b8'

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('apk', type=Path)
    parser.add_argument('--aapt', required=True)
    parser.add_argument('--apksigner', required=True)
    parser.add_argument('--zipalign', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--source-commit', required=True)
    args = parser.parse_args()
    subprocess.run(['python3', str(Path(__file__).with_name('inspect_unsigned_apk.py')), str(args.apk), '--aapt', args.aapt, '--output', str(args.output)], check=True, stdout=subprocess.DEVNULL)
    metadata_path = args.output / 'unsigned-build-metadata.json'
    metadata = json.loads(metadata_path.read_text())
    if metadata['versionCode'] != 2094:
        raise ValueError('Unexpected actual ARM64 split code')
    signature = subprocess.check_output([args.apksigner, 'verify', '--verbose', '--print-certs', str(args.apk)], text=True)
    if re.findall(r'certificate SHA-256 digest: ([0-9a-fA-F]+)', signature) != [PREVIEW_CERT]:
        raise ValueError('Preview key differs from beta2; update would be incompatible')
    subprocess.run([args.zipalign, '-c', '-P', '16', '4', str(args.apk)], check=True)
    manifest = json.loads((Path(__file__).parents[2] / 'apps/mobile/assets/audio/manifest.json').read_text())
    # Verify the supplied recordings remain byte-identical to the source tree.
    with zipfile.ZipFile(args.apk) as archive:
        for name in ['user_makkah.mp3', 'user_madinah.mp3', 'user_egypt.mp3', 'user_abdul_basit.mp3', 'user_minshawi.mp3']:
            packaged = archive.read('assets/flutter_assets/assets/audio/' + name)
            original = (Path(__file__).parents[2] / 'apps/mobile/assets/audio' / name).read_bytes()
            if packaged != original:
                raise ValueError('Packaged user recording differs: ' + name)
    metadata.update(status='SIGNED_PREVIEW_COMPATIBLE_WITH_BETA2_NOT_2074', certificateSha256=PREVIEW_CERT,
                    sourceCommit=args.source_commit, physicalDeviceAcceptance='PENDING')
    (args.output / 'preview-metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
    (args.output / 'signature.txt').write_text(signature)
    (args.output / 'SHA256SUMS.txt').write_text(hashlib.sha256(args.apk.read_bytes()).hexdigest() + '  ' + args.apk.name + '\n')
    metadata_path.unlink()
    print(json.dumps(metadata, indent=2))
