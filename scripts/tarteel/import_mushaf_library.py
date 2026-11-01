"""Verify pinned source bytes, then add metadata to an isolated Neon branch.

No page image, font, Quran text, credentials or unreviewed tajweed annotation is
uploaded to Postgres. HTTP transactions use Neon's direct endpoint over TLS.
"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
TOPIC_SHA = '149f3e4532761dbd9365903fa48ab0e8d5eabcdb8971c42fed7f9ce6b4858b8c'
HAFS_PACK_SHA = '78bb6c2331f521e2769406eb0e3365e86f778b8e86e357d26114bfb1ec3ceef1'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def payload(assets_root):
    package = (ROOT / 'apps/mobile/assets/mushaf_library/topics-2026-10-24.json.gz').read_bytes()
    assert digest(package) == TOPIC_SHA
    topics = json.loads(gzip.decompress(package))['data']
    corpus_bytes = (ROOT / 'data/quran/canonical/v2/dataset.json').read_bytes()
    canonical_manifest = json.loads((ROOT / 'data/quran/canonical/v2/manifest.json').read_text())
    assert digest(corpus_bytes) == canonical_manifest['sha256']
    corpus = json.loads(corpus_bytes)
    verses = [dict(verse_key=v['verse_key'], surah=s['number'], ayah=v['ayah_number'],
                   text_sha256=digest(v['text_uthmani'].encode()), version_id='canonical-v2-kfgqpc',
                   juz=v['juz_number'], hizb_quarter=v['hizb_quarter'])
              for s in corpus['surahs'] for v in s['verses']]
    assert len(corpus['surahs']) == 114 and len(verses) == 6236
    assert all(len(s['verses']) == s['ayah_count'] for s in corpus['surahs'])
    keys = {v['verse_key'] for v in verses}
    by_id = {t['id']: t for t in topics}
    categories, sections, links = {}, [], []
    for t in topics:
        parent = t
        seen = {t['id']}
        while parent['parent_id'] is not None:
            assert parent['parent_id'] not in seen
            seen.add(parent['parent_id'])
            parent = by_id[parent['parent_id']]
        category = 'quranpedia:' + str(parent['id'])
        categories[category] = dict(id=category, source_id='quranpedia', title_ar=parent['name'])
        tid = 'quranpedia:' + str(t['id'])
        sections.append(dict(id=tid, source_id='quranpedia', version_id='topics-2026-10-24',
                             category_id=category, parent_id=None if t['parent_id'] is None else 'quranpedia:'+str(t['parent_id']),
                             source_key=str(t['id']), title_ar=t['name']))
        for key in set(t['ayahs'].split(',')) - {''}:
            assert key in keys
            links.append(dict(section_id=tid, verse_key=key))
    # Validate EVERY asset, not a single sample page.
    pack = assets_root / 'madinah-hafs-svg-pack.zip'
    assert digest(pack.read_bytes()) == HAFS_PACK_SHA
    directory = assets_root / 'hafs-pack'
    manifest_bytes = (directory / 'manifest.json').read_bytes()
    manifest = json.loads(manifest_bytes)
    for name, checksum in manifest['sha256'].items():
        path = (directory / name).resolve()
        assert path.is_relative_to(directory.resolve()) and digest(path.read_bytes()) == checksum
    pages, assets, positions = [], [], []
    artwork_keys = set()
    source_base = 'https://raw.githubusercontent.com/quranpedia/quran-svg/b91d39e1065b57bdda3e94aca8ecf3575e50e1e6/mushafs/hafs/kfqc'
    for page in range(1, 605):
        pages.append(dict(edition_id='madinah-hafs-svg-v1', page=page))
        for kind, relative, remote in [('image',f'pages/{page:03}.svg',f'svg/{page:03}.svg'),
                                      ('bounds',f'bounds/{page:03}.json',f'json/{page:03}.json')]:
            f = directory / relative
            assets.append(dict(edition_id='madinah-hafs-svg-v1', page=page, kind=kind,
                               source_url=source_base+'/'+remote, sha256=manifest['sha256'][relative], bytes=f.stat().st_size))
        grouped = {}
        for row in json.loads((directory / f'bounds/{page:03}.json').read_text()):
            key = f"{row['surahNumber']}:{row['ayahNumber']}"
            assert key in keys
            artwork_keys.add(key)
            grouped.setdefault(key, []).append(row)
        for key, bounds in grouped.items():
            positions.append(dict(edition_id='madinah-hafs-svg-v1',page=page,verse_key=key,source_bounds=bounds))
    assert artwork_keys == keys
    return dict(verses=verses, categories=list(categories.values()), sections=sections, links=links,
                pages=pages, assets=assets, positions=positions, corpus_sha=digest(corpus_bytes),
                manifest_sha=digest(manifest_bytes))


def insert(table, columns, rows):
    names = ','.join(columns)
    types = ','.join(k+' '+v for k, v in columns.items())
    return dict(query=f'INSERT INTO tarteel_mushaf.{table} ({names}) SELECT {names} FROM jsonb_to_recordset($1::jsonb) AS x({types}) ON CONFLICT DO NOTHING', params=[json.dumps(rows, ensure_ascii=False)])


def queries(data):
    q = [dict(query="SELECT pg_advisory_xact_lock(91833407)", params=[]),
         dict(query="SELECT set_config('tarteel.topic_before',((SELECT count(*) FROM tarteel_mushaf.thematic_sections)+(SELECT count(*) FROM tarteel_mushaf.thematic_ayah_ranges))::text,true)",params=[])]
    q.append(insert('mushaf_sources', dict(id='text',name='text',url='text'), [
        dict(id='canonical',name='KFGQPC official Hafs Unicode edition',url='https://github.com/Mtzallqmy/Quran-yomk/tree/feat/tarteel-local-prayer-neon-2074/data/quran/canonical/v2'),
        dict(id='quranpedia',name='الموسوعة القرآنية Quranpedia',url='https://quranpedia.net/dumps'),
        dict(id='hafs-svg',name='KFQC artwork via pinned Quranpedia SVG',url='https://github.com/quranpedia/quran-svg/tree/b91d39e1065b57bdda3e94aca8ecf3575e50e1e6')]))
    q.append(insert('mushaf_licenses',dict(id='text',source_id='text',url='text',notice='text',status='text'),[
        dict(id='quranpedia-2026-10-24',source_id='quranpedia',url='https://quranpedia.net/dumps/LICENSE.md',notice='Quranpedia.net; dataset version2026-10-24. Free app use; attribution/version required for dataset republication; keep corrections current.',status='approved'),
        dict(id='hafs-svg-original',source_id='hafs-svg',url='https://github.com/quranpedia/quran-svg/blob/b91d39e1065b57bdda3e94aca8ecf3575e50e1e6/LICENSE',notice='Pinned original SVG source terms and KFQC digital-software usage terms; no 1440 edition assertion.',status='approved')]))
    q.append(insert('mushaf_riwayat',dict(id='text',name_ar='text',ayah_count='integer'),[dict(id='hafs',name_ar='حفص عن عاصم',ayah_count=6236)]))
    q.append(insert('mushaf_versions',dict(id='text',source_id='text',version='text',sha256='text'),[
        dict(id='canonical-v2-kfgqpc',source_id='canonical',version='v2',sha256=data['corpus_sha']),
        dict(id='topics-2026-10-24',source_id='quranpedia',version='2026-10-24',sha256=TOPIC_SHA),
        dict(id='hafs-svg-v1',source_id='hafs-svg',version='b91d39e1065b57bdda3e94aca8ecf3575e50e1e6',sha256=data['manifest_sha'])]))
    q.append(insert('mushaf_editions',dict(id='text',riwayah_id='text',source_id='text',license_id='text',version_id='text',publisher='text',edition='text',text_version='text',page_layout='text',content_type='text',title_ar='text',fingerprint='text'),[
        dict(id='madinah-hafs-svg-v1',riwayah_id='hafs',source_id='hafs-svg',license_id='hafs-svg-original',version_id='hafs-svg-v1',publisher='KFQC artwork / Quranpedia SVG',edition='Pinned SVG v1; print year not independently verified',text_version='canonical-v2-kfgqpc',page_layout='604-pages-hafs-svg',content_type='page-layout',title_ar='مصحف المدينة — حفص',fingerprint=HAFS_PACK_SHA)]))
    specs = [
        ('canonical_ayahs',dict(verse_key='text',surah='integer',ayah='integer',text_sha256='text',version_id='text',juz='integer',hizb_quarter='integer'),'verses'),
        ('mushaf_pages',dict(edition_id='text',page='integer'),'pages'),
        ('mushaf_assets',dict(edition_id='text',page='integer',kind='text',source_url='text',sha256='text',bytes='bigint'),'assets'),
        ('mushaf_ayah_positions',dict(edition_id='text',page='integer',verse_key='text',source_bounds='jsonb'),'positions'),
        ('thematic_categories',dict(id='text',source_id='text',title_ar='text'),'categories'),
        ('thematic_sections',dict(id='text',source_id='text',version_id='text',category_id='text',parent_id='text',source_key='text',title_ar='text'),'sections'),
        ('thematic_ayah_ranges',dict(section_id='text',verse_key='text'),'links')]
    for table, columns, key in specs:
        q.append(insert(table, columns, data[key]))
    q.append(insert('mushaf_download_packages',dict(id='text',edition_id='text',source_url='text',bytes='bigint',sha256='text'),[
        dict(id='hafs-svg-pack-v1',edition_id='madinah-hafs-svg-v1',source_url='https://github.com/Mtzallqmy/Quran-yomk/releases/download/mushaf-assets-v1/madinah-hafs-svg-pack.zip',bytes=121620792,sha256=HAFS_PACK_SHA)]))
    q.append(dict(query="INSERT INTO tarteel_mushaf.mushaf_sync_logs(version_id,inserted,matched,report) SELECT 'topics-2026-10-24',n,25217-n,$1::jsonb FROM (SELECT (SELECT count(*) FROM tarteel_mushaf.thematic_sections)+(SELECT count(*) FROM tarteel_mushaf.thematic_ayah_ranges)-current_setting('tarteel.topic_before')::bigint AS n) counts", params=[json.dumps({k:len(data[k]) for k in ['verses','pages','assets','positions','categories','sections','links']})]))
    return q


def transaction(connection, statements):
    parsed = urllib.parse.urlsplit(connection)
    assert parsed.scheme in ('postgres','postgresql') and '-pooler' not in parsed.hostname
    request = urllib.request.Request('https://'+parsed.hostname+'/sql',
        data=json.dumps({'queries':statements}).encode(), headers={
            'Content-Type':'application/json', 'Neon-Connection-String':connection,
            'Neon-Batch-Isolation-Level':'Serializable', 'Neon-Raw-Text-Output':'true', 'Neon-Array-Mode':'false'})
    with urllib.request.urlopen(request, timeout=120) as response:
        result = json.load(response)
        return result.get("results", result) if isinstance(result, dict) else result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--assets-root', type=Path, required=True)
    parser.add_argument('--connection-file', type=Path)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    data = payload(args.assets_root)
    report = {k:len(data[k]) for k in ['verses','pages','assets','positions','categories','sections','links']}
    if args.apply:
        connection = json.loads(args.connection_file.read_text())['connectionString']
        ddl = (ROOT / 'database/neon/003_mushaf_library.sql').read_text()
        # This migration intentionally has no procedural bodies/embedded semicolons.
        ddl = '\n'.join(line for line in ddl.splitlines() if not line.lstrip().startswith('--'))
        for attempt in range(2):
            transaction(connection, [dict(query=sql,params=[]) for sql in ddl.split(';') if sql.strip()])
        for attempt in range(2):
            result = transaction(connection, queries(data))
            inserted = sum(r.get('rowCount',0) for r in result[:-1] if r.get('command')=='INSERT')
            report['sync_'+str(attempt+1)] = dict(inserted=inserted)
        assert report['sync_2']['inserted'] == 0
        report['status'] = 'APPLIED_TWICE_NO_DUPLICATES'
    else:
        report['status'] = 'VERIFIED_DRY_RUN'
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report))
