"""Apply validated hashes/identities only, twice; never upload Quran strings."""
import argparse,hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts/tarteel'))
from import_mushaf_library import transaction

def run(connection):
 raw=(ROOT/'data/quran/canonical/v2/dataset.json').read_bytes();m=json.loads((ROOT/'data/quran/canonical/v2/manifest.json').read_text());assert hashlib.sha256(raw).hexdigest()==m['sha256'];d=json.loads(raw)
 rows=[dict(verse_key=v['verse_key'],hash=hashlib.sha256(v['text_uthmani'].encode()).hexdigest(),juz=v['juz_number']) for s in d['surahs'] for v in s['verses']]
 assert len(rows)==len({v['verse_key'] for v in rows})==6236
 q=[dict(query="SELECT pg_advisory_xact_lock(91833408)",params=[]),dict(query="UPDATE tarteel_mushaf.canonical_ayahs a SET text_sha256=x.hash,version_id='canonical-v2-kfgqpc',juz=x.juz FROM jsonb_to_recordset($1::jsonb) AS x(verse_key text,hash text,juz integer) WHERE a.verse_key=x.verse_key AND a.version_id IN ('canonical-v1','canonical-v2-kfgqpc') AND (a.text_sha256,a.version_id,a.juz) IS DISTINCT FROM (x.hash,'canonical-v2-kfgqpc',x.juz) RETURNING a.verse_key",params=[json.dumps(rows)]),dict(query="DO $$ BEGIN IF (SELECT count(*) FROM tarteel_mushaf.canonical_ayahs WHERE version_id='canonical-v2-kfgqpc') <> 6236 THEN RAISE EXCEPTION 'CANONICAL_CUTOVER_INCOMPLETE'; END IF; END $$",params=[]),dict(query="UPDATE tarteel_mushaf.mushaf_editions SET text_version='canonical-v2-kfgqpc' WHERE id='madinah-hafs-svg-v1' AND text_version IS DISTINCT FROM 'canonical-v2-kfgqpc'",params=[])]
 counts=[]
 for _ in range(2):counts.append(len(transaction(connection,q)[1]['rows']))
 return dict(changed_by_round=counts,canonical_ayahs=6236,source_sha256=m['sha256'],body_storage=False)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--connection-file',type=Path,required=True);p.add_argument('--report',type=Path,required=True);a=p.parse_args();r=run(json.loads(a.connection_file.read_text())['connectionString']);a.report.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
