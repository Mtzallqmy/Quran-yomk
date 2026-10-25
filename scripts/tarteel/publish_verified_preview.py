"""Publish only an exact, externally signed preview after its actual CI gates.

GITHUB_TOKEN stays in the Actions environment; no private Android signing key is
required or uploaded. This is separate from the original2074 production gate.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

from preview_signing_envelope import reconstruct

REPO='Mtzallqmy/Quran-yomk'


def api(path):
    return json.loads(subprocess.check_output(['gh','api',f'repos/{REPO}/{path}'],text=True))


def publish(metadata_path,build_tools,output):
    metadata=json.loads(metadata_path.read_text())
    commit=metadata['candidate_commit']
    source=metadata['source_commit']
    if not all(re.fullmatch('[0-9a-f]{40}',value) for value in [commit,source]):
        raise ValueError('Invalid candidate commit')
    for key in ['candidate_run_id','artifact_id']:
        if type(metadata[key]) is not int or metadata[key]<=0:
            raise ValueError('Invalid Actions identity')
    # The only release this reviewed workflow is authorized to publish.
    if metadata['tag']!='v0.9.1-beta.2-preview.2093':
        raise ValueError('Unexpected release tag')
    run=api(f"actions/runs/{metadata['candidate_run_id']}")
    if run['head_sha']!=commit or run['conclusion']!='success' or run['event']!='pull_request' or run['name']!='Tarteel local prayer upgrade':
        raise ValueError('Candidate workflow is not the passing PR build')
    jobs=api(f"actions/runs/{metadata['candidate_run_id']}/jobs?per_page=100")['jobs']
    for name in ['quality','android-acceptance (26)','android-acceptance (36)']:
        matches=[j for j in jobs if j['name']==name]
        if len(matches)!=1 or matches[0]['conclusion']!='success':
            raise ValueError('Required acceptance failed: '+name)
    artifact=api(f"actions/artifacts/{metadata['artifact_id']}")
    expected_digest='sha256:'+metadata['artifact_sha256']
    if artifact['workflow_run']['head_sha']!=commit or artifact['expired'] or artifact['digest']!=expected_digest or artifact['name']!='tarteel-unsigned-compile-evidence-'+source:
        raise ValueError('Artifact is not the reviewed candidate')
    # PR builds compile GitHub's merge ref. Tag that actual tested source, not
    # merely the feature head that triggered it.
    source_object=api('git/commits/'+source)
    if commit not in [parent['sha'] for parent in source_object['parents']]:
        raise ValueError('Compiled source is not the reviewed PR merge')
    output.mkdir(parents=True,exist_ok=True)
    archive=output/'candidate.zip'
    with archive.open('wb') as stream:
        subprocess.run(['gh','api',f"repos/{REPO}/actions/artifacts/{metadata['artifact_id']}/zip"],stdout=stream,check=True)
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=metadata['artifact_sha256']:
        raise ValueError('Downloaded Actions artifact digest differs')
    with zipfile.ZipFile(archive) as package:
        entries=[n for n in package.namelist() if n=='UNSIGNED-tarteel-arm64-v8a.apk']
        if len(entries)!=1:raise ValueError('Unexpected APK artifact layout')
        before=package.read(entries[0])
    envelope=json.loads((metadata_path.parent/'preview-2093-envelope.json').read_text())
    apk=output/'Tarteel-0.9.1-beta.2-2093-ARM64-PREVIEW.apk'
    apk.write_bytes(reconstruct(before,envelope))
    with zipfile.ZipFile(apk) as signed_package:
        if source.encode() not in signed_package.read('lib/arm64-v8a/libapp.so'):
            raise ValueError('APK reports a different compiled Git reference')
    verification=output/'verification'
    subprocess.run(['python3',str(Path(__file__).with_name('verify_preview_apk.py')),str(apk),
        '--aapt',str(build_tools/'aapt'),'--apksigner',str(build_tools/'apksigner'),
        '--zipalign',str(build_tools/'zipalign'),'--source-commit',source,'--output',str(verification)],check=True)
    # Refuse overwrites, and never mark this preview as the latest production release.
    exists=subprocess.run(['gh','release','view',metadata['tag'],'--repo',REPO],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    if exists.returncode==0:raise ValueError('Release already exists; refusing overwrite')
    subprocess.run(['gh','release','create',metadata['tag'],str(apk),str(verification/'SHA256SUMS.txt'),str(verification/'preview-metadata.json'),
        '--repo',REPO,'--target',source,'--prerelease','--latest=false',
        '--title','ترتيل 0.9.1-beta.2 — معاينة 2093',
        '--notes-file','docs/surah-api/RELEASE_NOTES.md'],check=True)
    release=api('releases/tags/'+metadata['tag'])
    assets=[a for a in release['assets'] if a['name']==apk.name]
    if len(assets)!=1 or assets[0]['size']!=apk.stat().st_size or not release['prerelease']:
        raise ValueError('Published asset verification failed')
    (output/'release.json').write_text(json.dumps(dict(url=release['html_url'],apk=assets[0]['browser_download_url'],source_commit=source,feature_commit=commit),indent=2)+'\n')
    print(release['html_url'])


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--metadata',type=Path,required=True)
    parser.add_argument('--build-tools',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    publish(args.metadata,args.build_tools,args.output)
