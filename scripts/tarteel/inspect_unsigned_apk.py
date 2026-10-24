"""Inspect a compile-only APK. This never certifies signing or installability."""
import argparse
import hashlib
import json
import re
import subprocess
import zipfile
from pathlib import Path

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('apk', type=Path)
    parser.add_argument('--aapt', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    badging = subprocess.check_output([args.aapt, 'dump', 'badging', str(args.apk)], text=True)
    package = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging, re.M)
    if not package or package[1] != 'app.tarteel.tarteel' or int(package[2]) <= 2074 or package[3] != '0.9.0-beta.2':
        raise ValueError('Unexpected Tarteel package or actual split APK version')
    if "sdkVersion:'26'" not in badging:
        raise ValueError('Expected Android 8 API26 minimum')
    with zipfile.ZipFile(args.apk) as archive:
        abis = sorted({p.split('/')[1] for p in archive.namelist() if p.startswith('lib/') and p.endswith('.so')})
        if abis != ['arm64-v8a']:
            raise ValueError('Expected ARM64 only')
        for asset in ['adhan.ogg', 'reminder.wav', 'adhan_makkah.ogg', 'adhan_madinah.ogg', 'adhan_kazakhstan.ogg', 'adhan_sweden_fajr.ogg', 'user_makkah.mp3', 'user_madinah.mp3', 'user_egypt.mp3', 'user_abdul_basit.mp3', 'user_minshawi.mp3']:
            if archive.getinfo('assets/flutter_assets/assets/audio/' + asset).file_size < 1024:
                raise ValueError('Missing packaged offline audio')
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output/'badging.txt').write_text(badging)
    metadata = dict(applicationId=package[1], versionCode=int(package[2]), versionName=package[3], minSdk=26,
                    abis=abis, sha256=hashlib.sha256(args.apk.read_bytes()).hexdigest(),
                    status='UNSIGNED_COMPILE_EVIDENCE_NOT_AN_INSTALLABLE_RELEASE')
    (args.output/'unsigned-build-metadata.json').write_text(json.dumps(metadata, indent=2)+'\n')
    print(json.dumps(metadata, indent=2))
