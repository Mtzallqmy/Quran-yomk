#!/usr/bin/env python3
import csv
import json
import os
import re
import subprocess
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SEED = ROOT / 'supabase/seed/06_external_stations.sql'
OUT = ROOT / 'apps/mobile/release/external-radio'
OUT.mkdir(parents=True, exist_ok=True)
V3 = 'https://www.mp3quran.net/api/v3/radios?language=ar'
LEGACY = 'https://www.mp3quran.net/api/radio/radio_ar.json'
ISLAMIC_RADIO_API = 'https://raw.githubusercontent.com/uthumany/islamic-radio-api/main/client/public/api/stations.json'
REQUIRED = {
    'https://backup.qurango.net/radio/mix',
    'https://backup.qurango.net/radio/salma',
    'https://backup.qurango.net/radio/saheh-bokharee',
    'https://backup.qurango.net/radio/saheh-muslim',
    'https://backup.qurango.net/radio/riyad',
    'https://backup.qurango.net/radio/alanbiya',
    'https://backup.qurango.net/radio/sahabah',
    'https://backup.qurango.net/radio/almukhtasar_fi_alsiyra',
    'https://backup.qurango.net/radio/fi_zilal_alsiyra',
    'https://backup.qurango.net/radio/tafseer',
    'https://backup.qurango.net/radio/mukhtasartafsir',
    'https://backup.qurango.net/radio/tabri',
    'https://backup.qurango.net/radio/gareeb-quran',
    'https://backup.qurango.net/radio/fatwa',
    'https://backup.qurango.net/radio/roqiah',
    'https://backup.qurango.net/radio/athkar_sabah',
    'https://backup.qurango.net/radio/athkar_masa',
    'https://backup.qurango.net/radio/albaqarah',
    'https://backup.qurango.net/radio/Surah_Al-Mulk',
    'https://win.holol.com/live/quran/playlist.m3u8',
    'https://win.holol.com/live/sunnah/playlist.m3u8',
    'https://stream.radiojar.com/0tpy1h0kxtzuv',
}


def canonical(url: str) -> str:
    return re.sub(r'/+$', '', re.sub(r'^https?://', '', url.strip().lower()))


def classify_category(name: str, url: str, genres: str = '') -> str:
    text = f'{name} {url} {genres}'.lower()
    tests = [
        ('QURAN_TRANSLATION', r'ترجم|translation|باللغة|mokhtasr-(english|french|urdo|grgstan|husa)|farsi-(trans|tadabor)'),
        ('TAFSEER', r'تفسير|غريب القرآن|الطبري|tafseer|tafsir|tabri|gareeb-quran'),
        ('HADITH', r'البخاري|مسلم|رياض الصالحين|حديث|hadith|bokharee|bukhari|muslim|riyad'),
        ('SEERAH', r'السيرة|الأنبياء|seerah|sira|alsiyra|alanbiya'),
        ('SAHABAH', r'الصحابة|sahabah'),
        ('ADHKAR', r'أذكار|adhkar|athkar'),
        ('RUQYAH', r'رقية|ruqyah|roqiah'),
        ('FATWA', r'فتاوى|fatwa'),
        ('QURAN_SURAH', r'سورة |albaqarah|surah_'),
    ]
    for category, pattern in tests:
        if re.search(pattern, text, re.I):
            return category
    if re.search(r'quran recitation|reciter|recitations|قارئ|شيخ', text, re.I):
        return 'RECITER'
    return 'QURAN_GENERAL' if re.search(
        r'إذاعة|الإذاعة|quran|islamic|تلاوات|تراتيل|السكينة|تكبيرات|شوال|ذي الحجة',
        text,
        re.I,
    ) else 'OTHER'


def seed_rows():
    text = SEED.read_text(encoding='utf-8')
    rx = re.compile(
        r"\('([^']+)','([^']+)','([^']+)','([^']+)','([^']*)','([^']*)','([^']+)','(https?://[^']+)'",
        re.M,
    )
    rows = []
    for provider, category, slug, key, name_ar, name_en, stream_type, url in rx.findall(text):
        rows.append({
            'provider': provider,
            'category': category,
            'slug': slug,
            'external_key': key,
            'name': name_ar or name_en,
            'stream_type_seed': stream_type,
            'url': url,
            'seeded': True,
            'aliases': [provider],
        })
    return rows


def fetch_json(url):
    req = urllib.request.Request(
        url,
        headers={'User-Agent': 'TarteelReleaseAudit/1.1', 'Accept': 'application/json'},
    )
    with urllib.request.urlopen(req, timeout=25) as response:
        return json.loads(response.read().decode('utf-8'))


def mp3quran_rows():
    source = V3
    try:
        payload = fetch_json(V3)
    except Exception:
        source = LEGACY
        payload = fetch_json(LEGACY)
    radios = payload.get('radios') or payload.get('Radios') or []
    rows = []
    for item in radios:
        key = str(item.get('id') or item.get('Id') or '').strip()
        name = str(item.get('name') or item.get('Name') or '').strip()
        url = str(item.get('url') or item.get('URL') or '').strip()
        if key and name and url.startswith(('http://', 'https://')):
            rows.append({
                'provider': 'mp3quran',
                'category': classify_category(name, url),
                'slug': f'mp3quran-radio-{key}',
                'external_key': key,
                'name': name,
                'stream_type_seed': 'DYNAMIC',
                'url': url,
                'seeded': False,
                'aliases': ['mp3quran'],
                'catalog_source': source,
            })
    if not rows:
        raise RuntimeError('MP3Quran catalog returned no valid radios')
    return rows, source


def islamic_radio_rows():
    payload = fetch_json(ISLAMIC_RADIO_API)
    stations = payload.get('stations') or []
    if not isinstance(stations, list) or not stations:
        raise RuntimeError('Islamic Radio API catalog returned no station array')
    rows = []
    for item in stations:
        key = str(item.get('id') or '').strip()
        name = str(item.get('nameAr') or item.get('name') or '').strip()
        url = str(item.get('streamUrl') or '').strip()
        genres = ' '.join(str(value) for value in (item.get('genre') or []))
        fmt = str(item.get('streamFormat') or 'unknown').lower()
        if key and name and url.startswith(('http://', 'https://')):
            rows.append({
                'provider': 'islamic-radio-api',
                'category': classify_category(name, url, genres),
                'slug': f'islamic-radio-{key}',
                'external_key': key,
                'name': name,
                'stream_type_seed': {
                    'mp3': 'MP3_STREAM',
                    'aac': 'AAC_STREAM',
                    'hls': 'HLS',
                    'm3u8': 'HLS',
                    'icecast': 'ICECAST',
                    'shoutcast': 'SHOUTCAST',
                }.get(fmt, 'DYNAMIC'),
                'url': url,
                'seeded': False,
                'aliases': ['islamic-radio-api'],
                'catalog_source': ISLAMIC_RADIO_API,
                'provider_status': item.get('status'),
            })
    if not rows:
        raise RuntimeError('Islamic Radio API catalog contained no valid stream URLs')
    declared_total = payload.get('total')
    if isinstance(declared_total, int) and declared_total != len(stations):
        raise RuntimeError(
            f'Islamic Radio API total mismatch: declared={declared_total}, array={len(stations)}'
        )
    return rows, payload.get('version')


def merge_inventory(*sources):
    merged = {}
    source_rows = [row for source in sources for row in source]
    for row in source_rows:
        key = canonical(row['url'])
        if key in merged:
            existing = merged[key]
            existing['aliases'] = sorted(set(existing['aliases'] + row['aliases']))
            existing.setdefault('provider_records', []).append({
                'provider': row['provider'],
                'external_key': row['external_key'],
                'name': row['name'],
            })
        else:
            merged[key] = {
                **row,
                'provider_records': [{
                    'provider': row['provider'],
                    'external_key': row['external_key'],
                    'name': row['name'],
                }],
            }
    return list(merged.values()), len(source_rows) - len(merged)


def curl_probe(url):
    header_file = OUT / f'.headers-{abs(hash(url))}.txt'
    fmt = '%{http_code}\t%{content_type}\t%{url_effective}\t%{time_starttransfer}\t%{num_redirects}'
    cmd = [
        'curl', '-L', '--connect-timeout', '5', '--max-time', '9', '--silent',
        '--show-error', '--range', '0-65535', '-H', 'Icy-MetaData: 1',
        '-A', 'TarteelReleaseAudit/1.1', '-D', str(header_file), '-o', '/dev/null',
        '-w', fmt, url,
    ]
    started = time.monotonic()
    p = subprocess.run(cmd, text=True, capture_output=True)
    elapsed = round((time.monotonic() - started) * 1000)
    parts = p.stdout.strip().split('\t')
    http = int(parts[0]) if parts and parts[0].isdigit() else 0
    ctype = parts[1] if len(parts) > 1 else ''
    final = parts[2] if len(parts) > 2 else url
    ttfb = round(float(parts[3]) * 1000) if len(parts) > 3 and parts[3] else None
    redirects = int(parts[4]) if len(parts) > 4 and parts[4].isdigit() else 0
    headers = header_file.read_text(errors='replace') if header_file.exists() else ''
    header_file.unlink(missing_ok=True)
    locations = re.findall(r'(?im)^location:\s*(\S+)', headers)
    icy = bool(re.search(r'(?im)^icy-[^:]+:', headers))
    return {
        'http_status': http,
        'content_type': ctype or None,
        'final_url': final,
        'redirect_count': redirects,
        'redirect_chain': locations,
        'http_ttfb_ms': ttfb,
        'http_elapsed_ms': elapsed,
        'icy_headers': icy,
        'curl_exit': p.returncode,
        'curl_error': p.stderr.strip()[-500:] or None,
    }


def ffprobe(url):
    cmd = [
        'timeout', '15s', 'ffprobe', '-v', 'error', '-rw_timeout', '8000000',
        '-analyzeduration', '3000000', '-probesize', '1000000',
        '-show_entries', 'stream=codec_type,codec_name:format=format_name', '-of', 'json', url,
    ]
    started = time.monotonic()
    p = subprocess.run(cmd, text=True, capture_output=True)
    elapsed = round((time.monotonic() - started) * 1000)
    data = {}
    if p.stdout.strip():
        try:
            data = json.loads(p.stdout)
        except json.JSONDecodeError:
            pass
    streams = data.get('streams') or []
    codecs = [
        s.get('codec_name')
        for s in streams
        if s.get('codec_type') == 'audio' and s.get('codec_name')
    ]
    fmt = (data.get('format') or {}).get('format_name')
    return {
        'codec': codecs[0] if codecs else None,
        'audio_codecs': codecs,
        'format': fmt,
        'first_audio_ms': elapsed if codecs else None,
        'ffprobe_exit': p.returncode,
        'ffprobe_error': p.stderr.strip()[-700:] or None,
    }


def detected_type(row, http, media):
    url = row['url'].lower()
    ctype = (http.get('content_type') or '').lower()
    fmt = (media.get('format') or '').lower()
    codec = (media.get('codec') or '').lower()
    if '.m3u8' in url or 'mpegurl' in ctype or 'hls' in fmt:
        return 'HLS'
    if http.get('icy_headers'):
        return 'SHOUTCAST'
    if codec in ('aac', 'aac_latm'):
        return 'AAC_STREAM'
    if codec in ('mp3', 'mp2'):
        return 'MP3_STREAM'
    seed = row.get('stream_type_seed')
    return seed if seed not in (None, 'DYNAMIC', 'UNKNOWN_STREAM') else 'UNKNOWN_STREAM'


def probe(row):
    try:
        http = curl_probe(row['url'])
    except Exception as exc:
        http = {
            'http_status': 0, 'content_type': None, 'final_url': row['url'],
            'redirect_count': 0, 'redirect_chain': [], 'http_ttfb_ms': None,
            'http_elapsed_ms': None, 'icy_headers': False, 'curl_exit': -1,
            'curl_error': str(exc),
        }
    try:
        media = ffprobe(row['url'])
    except Exception as exc:
        media = {
            'codec': None, 'audio_codecs': [], 'format': None, 'first_audio_ms': None,
            'ffprobe_exit': -1, 'ffprobe_error': str(exc),
        }
    if media.get('codec'):
        health = 'HEALTHY'
    elif http.get('http_status') in range(200, 400):
        health = 'DEGRADED'
    elif 'unsupported' in (media.get('ffprobe_error') or '').lower():
        health = 'UNSUPPORTED'
    else:
        health = 'UNAVAILABLE'
    return {
        **row,
        **http,
        **media,
        'detected_stream_type': detected_type(row, http, media),
        'health_status': health,
        'checked_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
    }


def _choose(results, predicate):
    candidates = [row for row in results if predicate(row)]
    return next((row for row in candidates if row['health_status'] == 'HEALTHY'), None) or (
        candidates[0] if candidates else None
    )


def representative(results):
    picks = {
        'qurango_general': _choose(
            results, lambda r: 'qurango' in r['aliases'] and r['category'] == 'QURAN_GENERAL'
        ),
        'qurango_reciter': _choose(
            results, lambda r: 'qurango' in r['aliases'] and r['category'] == 'RECITER'
        ),
        'tafseer': _choose(results, lambda r: r['category'] == 'TAFSEER'),
        'adhkar': _choose(results, lambda r: r['category'] == 'ADHKAR'),
        'hls_quran': _choose(
            results, lambda r: r['url'] == 'https://win.holol.com/live/quran/playlist.m3u8'
        ),
        'hls_sunnah': _choose(
            results, lambda r: r['url'] == 'https://win.holol.com/live/sunnah/playlist.m3u8'
        ),
        'saudi_radio': _choose(
            results, lambda r: r['url'] == 'https://stream.radiojar.com/0tpy1h0kxtzuv'
        ),
        'mp3quran_discovered': _choose(results, lambda r: 'mp3quran' in r['aliases']),
        'islamic_radio_api': _choose(results, lambda r: 'islamic-radio-api' in r['aliases']),
    }
    return {key: value for key, value in picks.items() if value is not None}


def main():
    seed = seed_rows()
    if len(seed) != 58:
        raise RuntimeError(f'Expected 58 seeded external stations, found {len(seed)}')
    missing = sorted(REQUIRED - {row['url'] for row in seed})
    if missing:
        raise RuntimeError('Required seeded URLs missing: ' + ', '.join(missing))

    mp3quran, mp3quran_source = mp3quran_rows()
    islamic, islamic_version = islamic_radio_rows()
    inventory, duplicate_count = merge_inventory(seed, mp3quran, islamic)

    results = []
    workers = int(os.environ.get('TARTEEL_AUDIT_WORKERS', '16'))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(probe, row): row for row in inventory}
        for future in as_completed(futures):
            result = future.result()
            results.append(result)
            print(
                f"{result['health_status']:11} {result['detected_stream_type']:12} {result['url']}",
                flush=True,
            )

    results.sort(key=lambda row: (row['provider'], row['category'], row['name']))
    reps = representative(results)
    counts = {
        status: sum(1 for row in results if row['health_status'] == status)
        for status in ('HEALTHY', 'DEGRADED', 'UNAVAILABLE', 'UNSUPPORTED')
    }
    summary = {
        'seeded_stations': len(seed),
        'mp3quran_fetched': len(mp3quran),
        'islamic_radio_api_fetched': len(islamic),
        'islamic_radio_api_version': islamic_version,
        'unique_streams': len(inventory),
        'duplicates_prevented': duplicate_count,
        'providers': sorted({provider for row in results for provider in row['aliases']}),
        'categories': sorted({row['category'] for row in results}),
        'health': counts,
        'hls_count': sum(1 for row in results if row['detected_stream_type'] == 'HLS'),
        'qurango_count': sum(1 for row in results if 'qurango' in row['aliases']),
        'islamic_radio_api_unique_streams': sum(
            1 for row in results if 'islamic-radio-api' in row['aliases']
        ),
        'islamic_radio_api_healthy': sum(
            1
            for row in results
            if 'islamic-radio-api' in row['aliases'] and row['health_status'] == 'HEALTHY'
        ),
        'mp3quran_catalog_source': mp3quran_source,
        'islamic_radio_api_catalog_source': ISLAMIC_RADIO_API,
        'representative': {
            key: {
                'url': value['url'],
                'health_status': value['health_status'],
                'codec': value['codec'],
                'stream_type': value['detected_stream_type'],
                'first_audio_ms': value['first_audio_ms'],
                'aliases': value['aliases'],
            }
            for key, value in reps.items()
        },
        'verified_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
    }
    (OUT / 'audit.json').write_text(
        json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8'
    )
    (OUT / 'summary.json').write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8'
    )
    fields = [
        'provider', 'category', 'slug', 'external_key', 'name', 'url', 'seeded',
        'health_status', 'http_status', 'final_url', 'redirect_count', 'content_type',
        'http_ttfb_ms', 'detected_stream_type', 'codec', 'format', 'first_audio_ms',
        'checked_at',
    ]
    with (OUT / 'audit.csv').open('w', encoding='utf-8', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in results:
            writer.writerow({key: row.get(key) for key in fields})

    print(json.dumps(summary, ensure_ascii=False, indent=2))
    required_reps = {
        'qurango_general', 'qurango_reciter', 'tafseer', 'adhkar', 'hls_quran',
        'hls_sunnah', 'saudi_radio', 'mp3quran_discovered', 'islamic_radio_api',
    }
    missing_reps = required_reps - set(reps)
    if missing_reps:
        raise RuntimeError('Representative streams missing: ' + ', '.join(sorted(missing_reps)))
    failed = [key for key, value in reps.items() if value['health_status'] != 'HEALTHY']
    if failed:
        raise RuntimeError('Representative real-audio validation failed: ' + ', '.join(failed))
    if summary['islamic_radio_api_healthy'] < 1:
        raise RuntimeError('Islamic Radio API has no stream with detected real audio')


if __name__ == '__main__':
    main()
