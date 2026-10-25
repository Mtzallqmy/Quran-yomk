"""Live scoped preference acceptance. Never prints credentials or user payloads."""
import argparse,json,urllib.request,urllib.error
from pathlib import Path

def main(base,report_path):
 if not base.startswith('https://'):raise ValueError('HTTPS_REQUIRED')
 tokens=[]
 def call(path,method='GET',token=None,body=None):
  req=urllib.request.Request(base.rstrip('/')+path,data=json.dumps(body).encode() if body is not None else None,method=method,headers={'content-type':'application/json',**({'authorization':'Bearer '+token} if token else {})})
  try:
   with urllib.request.urlopen(req,timeout=25) as r:return r.status,json.load(r)
  except urllib.error.HTTPError as e:return e.code,json.load(e)
 payload=dict(schema=1,calculation_method='muslimWorldLeague',asr_method='shafi',offsets={'fajr':2},reminder_modes={'fajr':'adhan'},before_minutes={'fajr':5},after_minutes={},volumes={'fajr':0.7},audio_assets={'fajr':'assets/audio/user_makkah.mp3'})
 try:
  assert call('/health')[0]==200
  assert call('/v1/prayer-preferences')[0]==401
  assert call('/v1/prayer-preferences',token='x'*43)[0]==401
  for _ in range(2):
   status,data=call('/v1/devices','POST',body={'consent':'favorites-backup-v1'});assert status==201;tokens.append(data['token'])
  a,b=tokens;body={'consent':'prayer-preferences-v1','revision':0,'payload':payload}
  assert call('/v1/prayer-preferences','PUT',a,{'revision':0,'payload':payload})[0]==422
  assert call('/v1/prayer-preferences','PUT',a,body)[0]==200
  assert call('/v1/prayer-preferences',token=a)[1]['data']['payload']==payload
  assert call('/v1/prayer-preferences',token=b)[1]['data'] is None
  assert call('/v1/prayer-preferences','PUT',a,body)[0]==409
  assert call('/v1/prayer-preferences','PUT',b,{**body,'payload':{**payload,'latitude':13}})[0]==422
  assert call('/v1/prayer-preferences','PUT',b,{**body,'payload':{**payload,'audio_assets':{'fajr':'/data/private/audio.mp3'}}})[0]==422
  assert call('/v1/prayer-preferences','PUT',a,{**body,'revision':1})[0]==200
  report=dict(status='PASS',api_base=base,authenticated_read_write=True,isolation=True,stale_revision_conflict=True,separate_consent=True,location_rejected=True,private_audio_paths_rejected=True,cloud_required_for_alarms=False)
 finally:
  for token in tokens:
   assert call('/v1/device','DELETE',token)[0]==200
   assert call('/v1/prayer-preferences',token=token)[0]==401
 if report_path:
  report_path.parent.mkdir(parents=True,exist_ok=True);report_path.write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report))
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--base',required=True);parser.add_argument('--report',type=Path);a=parser.parse_args();main(a.base,a.report)
