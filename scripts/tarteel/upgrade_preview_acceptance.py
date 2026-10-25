"""Actual signed2092 -> signed2094 install-r and data-retention acceptance."""
import argparse,hashlib,json,re,subprocess,time,xml.etree.ElementTree as ET,zipfile,tempfile,shutil
from pathlib import Path
PACKAGE='app.tarteel.tarteel'
BASE_SHA='46c0ddd6cf99122192473ef8b409a70b1862ef764f6ef2b4ae885420ded2e10b'
CERT='5e2a2a7412c93c8a0e9e28917195534b726c9c1ae3a35232e9fd0aeb5fa718b8'
def command(*args):return subprocess.check_output(list(args),text=True,stderr=subprocess.STDOUT,timeout=120)
def adb(*args):return command('adb',*args)
def main(a):
 a.output.mkdir(parents=True,exist_ok=True)
 private=Path(tempfile.mkdtemp(prefix='tarteel-upgrade-private-'))
 assert hashlib.sha256(a.baseline.read_bytes()).hexdigest()==BASE_SHA
 for apk in [a.baseline,a.candidate]:assert re.findall(r'certificate SHA-256 digest: ([0-9a-fA-F]+)',command(str(a.apksigner),'verify','--print-certs',str(apk)))==[CERT]
 abis=adb('shell','getprop','ro.product.cpu.abilist').strip();assert 'arm64-v8a' in abis, 'System image cannot execute actual ARM64 APK; refusing ABI override'
 adb('root');adb('wait-for-device')
 assert 'Success' in adb('install',str(a.baseline))
 if int(adb('shell','getprop','ro.build.version.sdk').strip())>=33:adb('shell','pm','grant',PACKAGE,'android.permission.POST_NOTIFICATIONS')
 adb('shell','am','start','-W','-n',PACKAGE+'/.MainActivity');time.sleep(15)
 assert 'versionCode=2092' in adb('shell','dumpsys','package',PACKAGE)
 adb('shell','am','force-stop',PACKAGE)
 device='/data/data/'+PACKAGE+'/shared_prefs/FlutterSharedPreferences.xml';local=private/'baseline-prefs.xml';adb('pull',device,str(local))
 tree=ET.parse(local);root=tree.getroot()
 fixtures={'flutter.mushaf:last-position:v1':json.dumps(dict(mode='page',number=121,verse_key='5:77',surah_number=5,ayah_number=77,page_number=121)), 'flutter.mushaf:bookmarks:v1':json.dumps([dict(verse_key='5:77',surah_number=5,ayah_number=77,page_number=121,created_at='2026-10-25T00:00:00Z')])}
 for key,value in fixtures.items():
  for child in list(root):
   if child.get('name')==key:root.remove(child)
  ET.SubElement(root,'string',{'name':key}).text=value
 tree.write(local,encoding='utf-8',xml_declaration=True)
 uid=adb('shell','stat','-c','%u','/data/data/'+PACKAGE).strip();assert uid.isdigit()
 adb('push',str(local),'/data/local/tmp/tarteel-upgrade-prefs.xml');adb('shell','cp','/data/local/tmp/tarteel-upgrade-prefs.xml',device);adb('shell','chown',uid+':'+uid,device);adb('shell','chmod','660',device)
 with zipfile.ZipFile(a.baseline) as z:audio=z.read('assets/flutter_assets/assets/audio/user_makkah.mp3')
 probe=a.output/'reference-recording.mp3';probe.write_bytes(audio);target='/data/data/'+PACKAGE+'/files/upgrade-reference.mp3'
 adb('shell','mkdir','-p','/data/data/'+PACKAGE+'/files');adb('push',str(probe),'/data/local/tmp/tarteel-upgrade-recording.mp3');adb('shell','cp','/data/local/tmp/tarteel-upgrade-recording.mp3',target);adb('shell','chown',uid+':'+uid,target)
 result=adb('install','-r',str(a.candidate));assert 'Success' in result
 (a.output/'install-r.txt').write_text(result)
 adb('logcat','-c');launch=adb('shell','am','start','-W','-n',PACKAGE+'/.MainActivity');time.sleep(25)
 pid=adb('shell','pidof',PACKAGE).strip().split()[0];assert pid
 logs=adb('logcat','-d','--pid='+pid);assert not re.search(r'FATAL EXCEPTION|Unhandled Exception|Fatal signal',logs)
 package=adb('shell','dumpsys','package',PACKAGE);assert 'versionCode=2094' in package
 after=private/'upgraded-prefs.xml';adb('pull',device,str(after));values={c.get('name'):c.text for c in ET.parse(after).getroot()}
 for key,value in fixtures.items():
  expected=json.loads(value)
  if key.endswith('last-position:v1'):expected.update(number=120,page_number=120)
  else:expected[0]['page_number']=120
  assert json.loads(values[key])==expected,'Lost2092 reading/bookmark identity: '+key
 backup=json.loads(values['flutter.mushaf:pre-canonical-v2-backup:v1']);assert backup['position']==fixtures['flutter.mushaf:last-position:v1'] and backup['bookmarks']==fixtures['flutter.mushaf:bookmarks:v1']
 retained=a.output/'retained-recording.mp3';adb('pull',target,str(retained));assert retained.read_bytes()==audio
 adb('shell','uiautomator','dump','/sdcard/tarteel-upgrade-ui.xml');adb('pull','/sdcard/tarteel-upgrade-ui.xml',str(a.output/'ui.xml'))
 assert PACKAGE in (a.output/'ui.xml').read_text()
 (a.output/'launch.txt').write_text(launch);(a.output/'logcat.txt').write_text(logs);(a.output/'package.txt').write_text(package)
 report=dict(status='PASS',baseline_version_code=2092,version_code=2094,baseline_sha256=BASE_SHA,apk_sha256=hashlib.sha256(a.candidate.read_bytes()).hexdigest(),certificate_sha256=CERT,emulator_abis=abis,reading_position_retained=True,bookmarks_retained=True,legacy_page=121,official_page=120,verse_identity='5:77',rollback_snapshot_verified=True,recording_sha256=hashlib.sha256(audio).hexdigest(),recording_retained=True)
 (a.output/'acceptance.json').write_text(json.dumps(report,indent=2)+'\n');shutil.rmtree(private);print(json.dumps(report))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path,required=True);p.add_argument('--candidate',type=Path,required=True);p.add_argument('--apksigner',type=Path,required=True);p.add_argument('--output',type=Path,required=True);main(p.parse_args())
