"""Fail closed when an APK cannot update the published Tarteel 2074."""
import argparse
import hashlib
import json
import re
import subprocess
import zipfile
from pathlib import Path

BASELINE_CERT = 'b93cac8e6b74a7aa33ebc0a151a778fd2bd3b8452badf0161b0ef78b862ac4b8'


def verify(apk, aapt, apksigner, output):
    badging = subprocess.check_output([aapt, 'dump', 'badging', str(apk)], text=True)
    signature = subprocess.check_output([apksigner, 'verify', '--verbose', '--print-certs', str(apk)], text=True)
    package = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging, re.M)
    if not package or package[1] != 'app.tarteel.tarteel':
        raise ValueError('Wrong application ID')
    if int(package[2]) <= 2074 or package[3] != '0.9.0-beta.2':
        raise ValueError('Version does not upgrade 2074')
    if "sdkVersion:'26'" not in badging:
        raise ValueError('Expected Android 8 minimum API 26')
    certs = re.findall(r'certificate SHA-256 digest: ([0-9a-fA-F]+)', signature)
    if certs != [BASELINE_CERT]:
        raise ValueError('Signing certificate differs from published 2074')
    with zipfile.ZipFile(apk) as archive:
        abis = sorted({p.split('/')[1] for p in archive.namelist() if p.startswith('lib/') and p.endswith('.so')})
        if abis != ['arm64-v8a']:
            raise ValueError(f'Unexpected native architectures: {abis}')
        for asset in ['assets/flutter_assets/assets/audio/adhan.ogg', 'assets/flutter_assets/assets/audio/reminder.wav',
                      'assets/flutter_assets/assets/audio/adhan_makkah.ogg',
                      'assets/flutter_assets/assets/audio/adhan_madinah.ogg',
                      'assets/flutter_assets/assets/audio/adhan_kazakhstan.ogg',
                      'assets/flutter_assets/assets/audio/adhan_sweden_fajr.ogg',
                      *['assets/flutter_assets/assets/audio/' + name for name in ['user_makkah.mp3', 'user_madinah.mp3', 'user_egypt.mp3', 'user_abdul_basit.mp3', 'user_minshawi.mp3']]]:
            if archive.getinfo(asset).file_size < 1024:
                raise ValueError('Missing offline audio: ' + asset)
    output.mkdir(parents=True, exist_ok=True)
    (output / 'badging.txt').write_text(badging)
    (output / 'signature.txt').write_text(signature)
    report = dict(applicationId=package[1], versionCode=int(package[2]), versionName=package[3], minSdk=26,
                  abis=abis, certificateSha256=certs[0], sha256=hashlib.sha256(apk.read_bytes()).hexdigest(),
                  sourceCommit=__import__('os').environ.get('GITHUB_SHA', 'local'),
                  physicalDeviceAcceptance='PENDING')
    (output / 'release-metadata.json').write_text(json.dumps(report, indent=2) + '\n')
    (output / 'SHA256SUMS.txt').write_text(f"{report['sha256']}  {apk.name}\n")
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('apk', type=Path)
    parser.add_argument('--aapt', required=True)
    parser.add_argument('--apksigner', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    verify(args.apk, args.aapt, args.apksigner, args.output)
