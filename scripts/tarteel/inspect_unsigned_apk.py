"""Inspect a compile-only APK. This never certifies signing or installability."""
import argparse
import hashlib
import gzip
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
    if not package or package[1] != 'app.tarteel.tarteel' or int(package[2]) <= 2092 or package[3] != '0.9.2-beta.2':
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
        canonical_name='assets/flutter_assets/assets/canonical/hafs-v2.json.gz'
        if archive.namelist().count(canonical_name)!=1: raise ValueError('Expected exactly one canonical Quran bundle')
        canonical=archive.read(canonical_name)
        if hashlib.sha256(canonical).hexdigest()!='d5b4d84c28b67c69e4bf22a7ee67964caee0dd85207a435650f5c89b0021414e': raise ValueError('Canonical bundle differs')
        raw=gzip.decompress(canonical)
        if hashlib.sha256(raw).hexdigest()!='132090d1264257ce816dfe1245014c422e3cd4c491f2397c78447efbe161ee8f': raise ValueError('Official canonical text differs')
        corpus=json.loads(raw)
        if len(corpus['surahs'])!=114 or sum(len(s['verses']) for s in corpus['surahs'])!=6236: raise ValueError('Incomplete Quran corpus')
        legacy=json.loads(archive.read('assets/flutter_assets/assets/islamic_content_manifest.json'))
        if 'quran_ar' in legacy['patterns'] or 'tajweed' in legacy['patterns'] or any(a['path']=='tafseer/muyassar.json' for a in legacy['assets']): raise ValueError('Retired Quran downloads could return')
        forbidden=[n for n in archive.namelist() if '/canonical/v1/' in n or '/quran/chapters/ar/' in n or '/quran/tajweed/' in n]
        if forbidden: raise ValueError('Duplicate retired Quran assets in APK')
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output/'badging.txt').write_text(badging)
    metadata = dict(applicationId=package[1], versionCode=int(package[2]), versionName=package[3], minSdk=26,
                    abis=abis, sha256=hashlib.sha256(args.apk.read_bytes()).hexdigest(),
                    status='UNSIGNED_COMPILE_EVIDENCE_NOT_AN_INSTALLABLE_RELEASE')
    (args.output/'unsigned-build-metadata.json').write_text(json.dumps(metadata, indent=2)+'\n')
    print(json.dumps(metadata, indent=2))
