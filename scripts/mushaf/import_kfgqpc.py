"""Import one complete, pinned official Hafs edition without text normalization.

The comparison report is diagnostic only: no similarity-based text selection,
no word merging and no generated Quran text. Old navigation metadata is retained
separately; it cannot replace a single character of the official text.
"""
import argparse
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT=Path(__file__).resolve().parents[2]
ARCHIVE_SHA='227e6b1564d980f2bd09c2c35ebfb0330ac268c79a7c247cd1ab665bc635f245'
JSON_SHA='d7adf8aeeef5a7b6798060706a55735dffbcdb542b290a3907bd9f70c498f4d3'
SOURCE='https://download.qurancomplex.gov.sa/resources_dev/kfgqpc_hafs_v30.zip'

def sha(b):return hashlib.sha256(b).hexdigest()
def write(path,value):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')

def build(archive):
 assert sha(archive.read_bytes())==ARCHIVE_SHA,'Official published archive fingerprint mismatch'
 with zipfile.ZipFile(archive) as z:
  raw=z.read('kfgqpc_hafs_v30-data/kfgqpc_hafs_v30.json');assert sha(raw)==JSON_SHA
  rows=json.loads(raw.decode('utf-8-sig'))
  font=z.read('kfgqpc_hafs_v30-font/kfgqpc_hafs_v30.ttf')
 old_path=ROOT/'data/quran/canonical/v1/dataset.json';old_bytes=__import__('subprocess').check_output(['git','show','69d67ca0c267682f6342beacee6b8ace7fb682c3:data/quran/canonical/v1/dataset.json'],cwd=ROOT);old=json.loads(old_bytes)
 expected={s['number']:s['ayah_count'] for s in old['surahs']}
 by_old={v['verse_key']:v for s in old['surahs'] for v in s['verses']}
 assert len(rows)==6236 and len(expected)==114
 surahs=[];diff=[];observed=Counter();pages=set();juz=set();seen=set();n=0
 for number in range(1,115):
  selected=[r for r in rows if r['sura_no']==number];assert len(selected)==expected[number]
  verses=[]
  for ayah,r in enumerate(selected,1):
   n+=1;k=f'{number}:{ayah}';legacy=by_old[k]
   assert r['id']==n and r['aya_no']==ayah and k not in seen;seen.add(k)
   assert isinstance(r['aya_text_unicode'],str) and r['aya_text_unicode'] and '\ufffd' not in r['aya_text_unicode']
   text=r['aya_text_unicode'];pages.add(r['page']);juz.add(r['jozz'])
   # Keep source string including its original ayah-end marker and digits.
   verses.append(dict(global_number=n,ayah_number=ayah,verse_key=k,canonical_id=f'hafs:{k}',text_uthmani=text,text_tajweed=None,juz_number=r['jozz'],page_number=r['page'],ruku_number=legacy['ruku_number'],hizb_quarter=legacy['hizb_quarter'],sajda=legacy['sajda'],line_start=r['line_start'],line_end=r['line_end']))
   diagnostic=re.sub(r'\s*\u06dd[٠-٩0-9]+\s*$','',text)
   if legacy['text_uthmani']!=text:
    diff.append(dict(verse_key=k,old_sha256=sha(legacy['text_uthmani'].encode()),official_sha256=sha(text.encode()),equal_after_removing_end_marker_for_diagnostics_only=legacy['text_uthmani']==diagnostic))
    observed.update(set(text)-set(legacy['text_uthmani']))
  surahs.append(dict(number=number,name_ar=selected[0]['sura_name_ar'],name_en=selected[0]['sura_name_en'],ayah_count=len(selected),verses=verses))
 assert pages==set(range(1,605)) and juz==set(range(1,31)) and len(seen)==6236
 source=dict(provider='KFGQPC',url=SOURCE,terms='https://qurancomplex.gov.sa/quran-dev/',uthmani_edition='kfgqpc-hafs-v30',tajweed_edition='NONE_MATCHING_VERIFIED_TEXT')
 dataset=dict(schema_version=1,dataset='tarteel-quran-canonical',version='2',source=source,surahs=surahs)
 data=(json.dumps(dataset,ensure_ascii=False,indent=2)+'\n').encode()
 dest=ROOT/'data/quran/canonical/v2';dest.mkdir(parents=True,exist_ok=True);(dest/'dataset.json').write_bytes(data)
 manifest=dict(schema_version=1,dataset=dataset['dataset'],version='2',status='APPROVED',approval_policy='VERBATIM_SNAPSHOT_NO_TEXT_MUTATION',approval_basis='Whole official edition selected by verified publisher identity and published archive SHA256, never by text similarity; no independent scholarly-review claim.',source=source,source_revision=dict(archive_sha256=ARCHIVE_SHA,uthmani_response_sha256=JSON_SHA,uthmani_response_bytes=len(raw)),sha256=sha(data),surahs=114,verses=6236,pages=604,rights=dict(storage_policy='OFFICIAL_DEVELOPER_USE_WITH_ATTRIBUTION',permission_url=source['terms'],no_text_mutation=True,no_ai_correction=True,notice='مجمع الملك فهد لطباعة المصحف الشريف — جميع الحقوق محفوظة؛ الحزمة الرسمية المقدمة لتطوير التطبيقات والبرمجيات.'),navigation_metadata=dict(hizb_ruku_sajda='Preserved identity/navigation metadata from retired canonical-v1; no old Quran text retained.'),font_sha256=sha(font),font_source=SOURCE)
 write(dest/'manifest.json',manifest)
 bundled=gzip.compress(data,mtime=0);assets=ROOT/'apps/mobile/assets/canonical';assets.mkdir(parents=True,exist_ok=True);(assets/'hafs-v2.json.gz').write_bytes(bundled)
 fonts=ROOT/'apps/mobile/assets/fonts';(fonts/'kfgqpc_hafs_v30.ttf').write_bytes(font)
 report=dict(old_path=str(old_path.relative_to(ROOT)),old_sha256=sha(old_bytes),official_archive_sha256=ARCHIVE_SHA,official_json_sha256=JSON_SHA,canonical_dataset_sha256=sha(data),bundle_sha256=sha(bundled),bundle_bytes=len(bundled),font_bytes=len(font),surahs=114,ayahs=6236,raw_strings_changed=len(diff),diagnostic_marker_only_changes=sum(d['equal_after_removing_end_marker_for_diagnostics_only'] for d in diff),selection_policy='Whole official source; no hybrid text, normalization, similarity selection or AI correction.',differences=diff,source_only_codepoints={f'U+{ord(c):04X}':count for c,count in observed.most_common()})
 write(ROOT/'docs/mushaf/CANONICAL_COMPARISON.json',report)
 write(ROOT/'docs/mushaf/canonical-build.json',{k:v for k,v in report.items() if k not in ['differences','source_only_codepoints']})
 print(json.dumps({k:v for k,v in report.items() if k not in ['differences','source_only_codepoints']}))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--archive',type=Path,required=True);build(p.parse_args().archive)
