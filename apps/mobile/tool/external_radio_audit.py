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

ROOT=Path(__file__).resolve().parents[3]
SEED=ROOT/'supabase/seed/06_external_stations.sql'
OUT=ROOT/'apps/mobile/release/external-radio'
OUT.mkdir(parents=True,exist_ok=True)
V3='https://www.mp3quran.net/api/v3/radios?language=ar'
LEGACY='https://www.mp3quran.net/api/radio/radio_ar.json'
REQUIRED={
'https://backup.qurango.net/radio/mix','https://backup.qurango.net/radio/salma','https://backup.qurango.net/radio/saheh-bokharee','https://backup.qurango.net/radio/saheh-muslim','https://backup.qurango.net/radio/riyad','https://backup.qurango.net/radio/alanbiya','https://backup.qurango.net/radio/sahabah','https://backup.qurango.net/radio/almukhtasar_fi_alsiyra','https://backup.qurango.net/radio/fi_zilal_alsiyra','https://backup.qurango.net/radio/tafseer','https://backup.qurango.net/radio/mukhtasartafsir','https://backup.qurango.net/radio/tabri','https://backup.qurango.net/radio/gareeb-quran','https://backup.qurango.net/radio/fatwa','https://backup.qurango.net/radio/roqiah','https://backup.qurango.net/radio/athkar_sabah','https://backup.qurango.net/radio/athkar_masa','https://backup.qurango.net/radio/albaqarah','https://backup.qurango.net/radio/Surah_Al-Mulk','https://win.holol.com/live/quran/playlist.m3u8','https://win.holol.com/live/sunnah/playlist.m3u8','https://stream.radiojar.com/0tpy1h0kxtzuv'}

def canonical(url:str)->str:
    return re.sub(r'/+$','',re.sub(r'^https?://','',url.strip().lower()))

def classify_category(name:str,url:str)->str:
    text=f'{name} {url}'.lower()
    tests=[('QURAN_TRANSLATION',r'ترجم|translation|باللغة|mokhtasr-(english|french|urdo|grgstan|husa)|farsi-(trans|tadabor)'),('TAFSEER',r'تفسير|غريب القرآن|الطبري|tafseer|tafsir|tabri|gareeb-quran'),('HADITH',r'البخاري|مسلم|رياض الصالحين|حديث|bokharee|muslim|riyad'),('SEERAH',r'السيرة|الأنبياء|alsiyra|alanbiya'),('SAHABAH',r'الصحابة|sahabah'),('ADHKAR',r'أذكار|athkar'),('RUQYAH',r'رقية|roqiah'),('FATWA',r'فتاوى|fatwa'),('QURAN_SURAH',r'سورة |albaqarah|surah_')]
    for category,pattern in tests:
        if re.search(pattern,text,re.I): return category
    return 'QURAN_GENERAL' if re.search(r'إذاعة|الإذاعة|تلاوات|تراتيل|السكينة|تكبيرات|شوال|ذي الحجة',text,re.I) else 'RECITER'

def seed_rows():
    text=SEED.read_text(encoding='utf-8')
    rx=re.compile(r"\('([^']+)','([^']+)','([^']+)','([^']+)','([^']*)','([^']*)','([^']+)','(https?://[^']+)'",re.M)
    rows=[]
    for provider,category,slug,key,name_ar,name_en,stream_type,url in rx.findall(text):
        rows.append({'provider':provider,'category':category,'slug':slug,'external_key':key,'name':name_ar or name_en,'stream_type_seed':stream_type,'url':url,'seeded':True,'aliases':[provider]})
    return rows

def fetch_json(url):
    req=urllib.request.Request(url,headers={'User-Agent':'TarteelReleaseAudit/1.0','Accept':'application/json'})
    with urllib.request.urlopen(req,timeout=20) as response:
        return json.loads(response.read().decode('utf-8'))

def dynamic_rows():
    source=V3
    try: payload=fetch_json(V3)
    except Exception:
        source=LEGACY; payload=fetch_json(LEGACY)
    radios=payload.get('radios') or payload.get('Radios') or []
    rows=[]
    for item in radios:
        key=str(item.get('id') or item.get('Id') or '').strip()
        name=str(item.get('name') or item.get('Name') or '').strip()
        url=str(item.get('url') or item.get('URL') or '').strip()
        if key and name and url.startswith(('http://','https://')):
            rows.append({'provider':'mp3quran','category':classify_category(name,url),'slug':f'mp3quran-radio-{key}','external_key':key,'name':name,'stream_type_seed':'DYNAMIC','url':url,'seeded':False,'aliases':['mp3quran'],'catalog_source':source})
    if not rows: raise RuntimeError('MP3Quran catalog returned no valid radios')
    return rows,source

def merge_inventory(seed,dynamic):
    merged={}
    for row in seed+dynamic:
        key=canonical(row['url'])
        if key in merged:
            existing=merged[key]
            existing['aliases']=sorted(set(existing['aliases']+row['aliases']))
            existing.setdefault('provider_records',[]).append({'provider':row['provider'],'external_key':row['external_key'],'name':row['name']})
        else:
            merged[key]={**row,'provider_records':[{'provider':row['provider'],'external_key':row['external_key'],'name':row['name']}]}
    return list(merged.values())

def curl_probe(url):
    header_file=OUT/f'.headers-{abs(hash(url))}.txt'
    fmt='%{http_code}\t%{content_type}\t%{url_effective}\t%{time_starttransfer}\t%{num_redirects}'
    cmd=['curl','-L','--connect-timeout','5','--max-time','9','--silent','--show-error','--range','0-65535','-H','Icy-MetaData: 1','-A','TarteelReleaseAudit/1.0','-D',str(header_file),'-o','/dev/null','-w',fmt,url]
    started=time.monotonic(); p=subprocess.run(cmd,text=True,capture_output=True); elapsed=round((time.monotonic()-started)*1000)
    parts=p.stdout.strip().split('\t')
    http=int(parts[0]) if parts and parts[0].isdigit() else 0
    ctype=parts[1] if len(parts)>1 else ''
    final=parts[2] if len(parts)>2 else url
    ttfb=round(float(parts[3])*1000) if len(parts)>3 and parts[3] else None
    redirects=int(parts[4]) if len(parts)>4 and parts[4].isdigit() else 0
    headers=header_file.read_text(errors='replace') if header_file.exists() else ''
    header_file.unlink(missing_ok=True)
    locations=re.findall(r'(?im)^location:\s*(\S+)',headers)
    icy=bool(re.search(r'(?im)^icy-[^:]+:',headers))
    return {'http_status':http,'content_type':ctype or None,'final_url':final,'redirect_count':redirects,'redirect_chain':locations,'http_ttfb_ms':ttfb,'http_elapsed_ms':elapsed,'icy_headers':icy,'curl_exit':p.returncode,'curl_error':p.stderr.strip()[-500:] or None}

def ffprobe(url):
    cmd=['timeout','15s','ffprobe','-v','error','-rw_timeout','8000000','-analyzeduration','3000000','-probesize','1000000','-show_entries','stream=codec_type,codec_name:format=format_name','-of','json',url]
    started=time.monotonic(); p=subprocess.run(cmd,text=True,capture_output=True); elapsed=round((time.monotonic()-started)*1000)
    data={}
    if p.stdout.strip():
        try:data=json.loads(p.stdout)
        except json.JSONDecodeError:pass
    streams=data.get('streams') or []
    codecs=[s.get('codec_name') for s in streams if s.get('codec_type')=='audio' and s.get('codec_name')]
    fmt=(data.get('format') or {}).get('format_name')
    return {'codec':codecs[0] if codecs else None,'audio_codecs':codecs,'format':fmt,'first_audio_ms':elapsed if codecs else None,'ffprobe_exit':p.returncode,'ffprobe_error':p.stderr.strip()[-700:] or None}

def detected_type(row,http,media):
    url=row['url'].lower(); ctype=(http.get('content_type') or '').lower(); fmt=(media.get('format') or '').lower(); codec=(media.get('codec') or '').lower()
    if '.m3u8' in url or 'mpegurl' in ctype or 'hls' in fmt: return 'HLS'
    if http.get('icy_headers'): return 'SHOUTCAST'
    if codec in ('aac','aac_latm'): return 'AAC_STREAM'
    if codec in ('mp3','mp2'): return 'MP3_STREAM'
    return row.get('stream_type_seed') if row.get('stream_type_seed') not in (None,'DYNAMIC','UNKNOWN_STREAM') else 'UNKNOWN_STREAM'

def probe(row):
    try:http=curl_probe(row['url'])
    except Exception as e:http={'http_status':0,'content_type':None,'final_url':row['url'],'redirect_count':0,'redirect_chain':[],'http_ttfb_ms':None,'http_elapsed_ms':None,'icy_headers':False,'curl_exit':-1,'curl_error':str(e)}
    try:media=ffprobe(row['url'])
    except Exception as e:media={'codec':None,'audio_codecs':[],'format':None,'first_audio_ms':None,'ffprobe_exit':-1,'ffprobe_error':str(e)}
    if media.get('codec'):health='HEALTHY'
    elif http.get('http_status') in range(200,400):health='DEGRADED'
    elif 'unsupported' in (media.get('ffprobe_error') or '').lower():health='UNSUPPORTED'
    else:health='UNAVAILABLE'
    return {**row,**http,**media,'detected_stream_type':detected_type(row,http,media),'health_status':health,'checked_at':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}

def representative(results):
    def by_url(suffix): return next((r for r in results if r['url'].endswith(suffix)),None)
    picks={
      'qurango_general':by_url('/mix'),'qurango_reciter':by_url('/abdulrahman_alsudaes'),'tafseer':by_url('/tafseer'),'adhkar':by_url('/athkar_sabah'),
      'hls_quran':next((r for r in results if r['url']=='https://win.holol.com/live/quran/playlist.m3u8'),None),
      'hls_sunnah':next((r for r in results if r['url']=='https://win.holol.com/live/sunnah/playlist.m3u8'),None),
      'saudi_radio':next((r for r in results if r['url']=='https://stream.radiojar.com/0tpy1h0kxtzuv'),None),
      'mp3quran_discovered':next((r for r in results if not r['seeded'] and r['provider']=='mp3quran'),None),
    }
    return {k:v for k,v in picks.items() if v is not None}

def main():
    seed=seed_rows()
    if len(seed)!=58: raise RuntimeError(f'Expected 58 seeded external stations, found {len(seed)}')
    missing=sorted(REQUIRED-{r['url'] for r in seed})
    if missing: raise RuntimeError('Required seeded URLs missing: '+', '.join(missing))
    dynamic,source=dynamic_rows()
    inventory=merge_inventory(seed,dynamic)
    results=[]
    workers=int(os.environ.get('TARTEEL_AUDIT_WORKERS','16'))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures={pool.submit(probe,row):row for row in inventory}
        for future in as_completed(futures):
            result=future.result();results.append(result);print(f"{result['health_status']:11} {result['detected_stream_type']:12} {result['url']}",flush=True)
    results.sort(key=lambda r:(r['provider'],r['category'],r['name']))
    reps=representative(results)
    counts={status:sum(1 for r in results if r['health_status']==status) for status in ('HEALTHY','DEGRADED','UNAVAILABLE','UNSUPPORTED')}
    summary={'seeded_stations':len(seed),'mp3quran_fetched':len(dynamic),'unique_streams':len(inventory),'duplicates_prevented':len(seed)+len(dynamic)-len(inventory),'providers':sorted({p for r in results for p in r['aliases']}),'categories':sorted({r['category'] for r in results}),'health':counts,'hls_count':sum(1 for r in results if r['detected_stream_type']=='HLS'),'qurango_count':sum(1 for r in results if 'qurango' in r['aliases']),'mp3quran_catalog_source':source,'representative':{k:{'url':v['url'],'health_status':v['health_status'],'codec':v['codec'],'stream_type':v['detected_stream_type'],'first_audio_ms':v['first_audio_ms']} for k,v in reps.items()},'verified_at':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
    (OUT/'audit.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    fields=['provider','category','slug','external_key','name','url','seeded','health_status','http_status','final_url','redirect_count','content_type','http_ttfb_ms','detected_stream_type','codec','format','first_audio_ms','checked_at']
    with (OUT/'audit.csv').open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields);w.writeheader();
        for r in results:w.writerow({k:r.get(k) for k in fields})
    print(json.dumps(summary,ensure_ascii=False,indent=2))
    missing_reps=set(('qurango_general','qurango_reciter','tafseer','adhkar','hls_quran','hls_sunnah','saudi_radio','mp3quran_discovered'))-set(reps)
    if missing_reps: raise RuntimeError('Representative streams missing: '+', '.join(sorted(missing_reps)))
    failed=[k for k,v in reps.items() if v['health_status']!='HEALTHY']
    if failed: raise RuntimeError('Representative real-audio validation failed: '+', '.join(failed))

if __name__=='__main__': main()
