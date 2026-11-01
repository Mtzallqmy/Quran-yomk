"""Discover official project metadata; never persist educational bodies.

Existing verified rows survive provider outages. Credentials stay in a private
connection file outside the repository. Repeating imports uses UNIQUE/UPSERT.
"""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request
from import_mushaf_library import transaction

BASE = 'https://dev.surahapp.com/api/v1'


def discover():
    request = urllib.request.Request(BASE + '/projects', headers={'Accept': 'application/json', 'User-Agent': 'Tarteel/0.9.1'})
    with urllib.request.urlopen(request, timeout=20) as response:
        raw = response.read(2 * 1024 * 1024 + 1)
    if len(raw) > 2 * 1024 * 1024:
        raise ValueError('CATALOG_TOO_LARGE')
    rows = json.loads(raw)
    if not isinstance(rows, list) or not rows:
        raise ValueError('INVALID_CATALOG')
    import re
    if any(not isinstance(r, dict) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,99}', r.get('slug', '')) or r.get('type') not in ['sura', 'page', 'aya', 'word'] for r in rows):
        raise ValueError('INVALID_PROJECT')
    return rows


def queries(projects):
    result = []
    for p in projects:
        if p.get('published') is False:
            continue
        fingerprint = hashlib.sha256(json.dumps(p, ensure_ascii=False, sort_keys=True).encode()).hexdigest()
        result.append(dict(query='''INSERT INTO surah_content.surah_projects(slug,title,scope,published,metadata_sha256,source_url)
          VALUES($1,$2,$3,true,$4,$5) ON CONFLICT(slug) DO UPDATE SET title=EXCLUDED.title,scope=EXCLUDED.scope,
          metadata_sha256=EXCLUDED.metadata_sha256,verified_at=now() RETURNING (xmax=0) AS inserted''',
          params=[p['slug'], p.get('title', p['slug']), p['type'], fingerprint, BASE + '/project/' + p['slug']]))
        result.append(dict(query='''INSERT INTO surah_content.surah_source_rights(project_slug,policy,terms_url,attribution,review_note)
          VALUES($1,$2,$3,$4,$5) ON CONFLICT(project_slug) DO NOTHING RETURNING true AS inserted''',
          params=[p['slug'], 'metadata_only' if p['slug'] == 'word-pic' else 'direct_session_only',
                  'https://dev.surahapp.com/api/docs', 'سورة — مركز تفسير للدراسات القرآنية',
                  'No verified permanent storage or redistribution grant; no educational body imported.']))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--connection-file', type=Path)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    try:
        projects = discover()
        report = dict(discovered=len(projects), body_storage=False, status='DISCOVERED')
        if args.connection_file:
            connection = json.loads(args.connection_file.read_text())['connectionString']
            rounds = []
            for _ in range(2):
                results = transaction(connection, queries(projects))
                rounds.append(sum(1 for r in results for row in r.get('rows', []) if row.get('inserted') in [True, 't', 'true']))
            report.update(inserted_by_round=rounds, status='SYNCED')
    except Exception as error:
        report = dict(status='SOURCE_UNAVAILABLE', error_type=type(error).__name__, body_storage=False, existing_rows_preserved=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
