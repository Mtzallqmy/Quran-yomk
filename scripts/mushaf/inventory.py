"""Generate a reproducible source/dependency inventory before a Quran cutover."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
TARGETS = ['apps/mobile/pubspec.yaml','apps/mobile/lib/main.dart','apps/mobile/lib/src/api.dart',
 'apps/mobile/lib/src/islamic_content.dart','apps/mobile/lib/src/mushaf_library.dart','apps/mobile/lib/src/mushaf_pages.dart',
 'apps/mobile/lib/src/mushaf_page_reader.dart','apps/mobile/lib/src/mushaf_store.dart','apps/mobile/lib/src/quran_models.dart',
 'apps/mobile/lib/src/tajweed.dart','apps/mobile/lib/src/learning.dart','apps/mobile/lib/src/screens/mushaf.dart',
 'apps/mobile/lib/src/screens/mushaf_library.dart','apps/mobile/assets/islamic_content_manifest.json',
 'apps/mobile/assets/learning/thematic_segments.json','supabase/functions/tarteel-api/quran.ts',
 'supabase/functions/tarteel-api/quran_integrity_runtime.js','database/neon/003_mushaf_library.sql']
PREFIXES = ['apps/mobile/assets/mushaf_library/','data/quran/canonical/','services/tarteel-content/','scripts/quran-integrity/']

def category(path):
 if path.endswith('/dataset.json'):return 'محتوى نصي مرجعي مرشح للاستبدال'
 if path.endswith('mushaf_store.dart'):return 'بيانات مستخدم؛ ممنوع الحذف أو تغيير المفاتيح'
 if any(v in path for v in ['topics-','thematic_segments','mushaf_library.dart']):return 'طبقة موضوعية مستقلة بلا نص قرآني'
 if path.endswith(('mushaf_pages.dart','mushaf_page_reader.dart','hafs-page-map.json')):return 'رسم/مواضع آيات ومحرك صفحات قابل لإعادة الاستخدام'
 if any(v in path for v in ['islamic_content','surah_']):return 'محتوى تفسير/تعليم؛ افصل النص القرآني فقط'
 return 'بيانات وصفية أو شيفرة أو اختبارات لازمة'

def generate(checkpoint):
 files=subprocess.check_output(['git','ls-files'],cwd=ROOT,text=True).splitlines()
 selected=sorted(p for p in files if p in TARGETS or any(p.startswith(prefix) for prefix in PREFIXES))
 rows=[]
 for path in selected:
  raw=(ROOT/path).read_bytes()
  result=subprocess.run(['rg','-l','-F',path,'apps','scripts','services','supabase','.github'],cwd=ROOT,text=True,capture_output=True)
  refs=sorted(set(result.stdout.splitlines())-{path})
  rows.append(dict(path=path,sha256=hashlib.sha256(raw).hexdigest(),bytes=len(raw),category=category(path),references=refs))
 output=ROOT/'docs/mushaf';output.mkdir(parents=True,exist_ok=True)
 (output/'migration-inventory.json').write_text(json.dumps(dict(checkpoint=checkpoint,assets=rows),ensure_ascii=False,indent=2)+'\n')
 lines=['# جرد ترحيل المصحف — مولد آليًا','',f'نقطة الاسترجاع الثابتة: `{checkpoint}`.','',
  'الفحص مبني على الملفات المتتبعة ومراجع المسارات الفعلية. تصنيف «مرشح» لا يأذن بالحذف؛ الحذف يتطلب نجاح البديل واختبارات الاستدعاءات. الملفات غير المستخدمة لا تُفترض من الاسم وحده.','',
  '| الملف | التصنيف | البايتات | SHA-256 | المراجع المباشرة |','|---|---|---:|---|---:|']
 lines += [f"| `{r['path']}` | {r['category']} | {r['bytes']} | `{r['sha256']}` | {len(r['references'])} |" for r in rows]
 lines += ['', 'مفاتيح المستخدم المحمية: `mushaf:last-position:v1`، `mushaf:bookmarks:v1`، `mushaf:font-scale`، `mushaf:show-tajweed`، `mushaf:show-themes`، `mushaf:presentation:v1`، `mushaf:page-edition:v1`. لا تنقل أو تحذف الصوت أو قواعد SQLite أو إعدادات الصلاة.','', 'لا ملف مصنف «قديم غير مستخدم» قبل إكمال تحليل الاستدعاءات؛ التقرير التفصيلي JSON يحتوي قائمة المراجع لكل مسار.']
 (output/'MIGRATION_INVENTORY.md').write_text('\n'.join(lines)+'\n')
 print(f'Inventory: {len(rows)} files; checkpoint {checkpoint}')

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--checkpoint',required=True);generate(p.parse_args().checkpoint)
