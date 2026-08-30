# ترتيل (Tarteel) — Quran Radio & Audio Platform

**المعرّف التقني:** `tarteel`  
**الحالة:** Storage Foundation implemented and validated  
**النطاق المنفذ:** التصميم + Database Phase + Supabase Storage buckets/upload lifecycle. لا يتضمن Flutter/Admin/Radio Engine/FFmpeg/Icecast.  
**المرجع:** Master Prompt المعتمد للمشروع.

**Supabase target:** طُبقت Database Phase على المشروع managed المحدد للمرحلة. لا يحتوي المستودع أي credentials.

## محتويات الحزمة

| الملف | الغرض |
|---|---|
| `docs/ARCHITECTURE.md` | المتطلبات الوظيفية وغير الوظيفية، المعمارية والمسؤوليات |
| `docs/DATABASE.md` | ERD، نمذجة البيانات، القيود والفهارس وسياسة الوقت |
| `supabase/migrations/` | migrations التنفيذية المرتبة والمطبقة |
| `supabase/seed/` | seeds قابلة لإعادة التشغيل |
| `supabase/tests/database_validation.sql` | اختبارات integrity وbad-data |
| `docs/RADIO_ENGINE.md` | State Machine، Queue، Commands، Never Silence |
| `docs/SCHEDULER.md` | Timezone/DST، occurrences، conflicts، restart/idempotency |
| `docs/API.md` | Public/Admin API والعقود والأخطاء والتصفح والإديمبوتنسي |
| `docs/AUDIO_PIPELINE.md` | Storage، FFmpeg، Icecast، فصل Live عن On-Demand |
| `docs/STORAGE.md` | Buckets، object keys، Upload Intent، security، cleanup، Worker handoff |
| `docs/EXTERNAL_STATIONS.md` | Providers، adapters، sync، health، rights، Flutter catalog |
| `docs/SECURITY.md` | Auth/RBAC، الأمن، المراقبة، Watchdog والاستعادة |
| `docs/DEPLOYMENT.md` | البيئات، topology، CI/CD، Monorepo، DR |
| `docs/MVP_PLAN.md` | Tasks صغيرة، معايير القبول، Gate المرحلة الثانية |
| `docs/ENGINEERING_REVIEW.md` | Race/SPOF/timezone/gaps/duplication/security review |

## القرارات الهندسية النهائية المقترحة

1. **Control Plane منفصل عن Playout Plane.** Supabase/PostgreSQL هو مصدر الحقيقة، بينما يواصل مشغل المحطة العمل من Queue Snapshot محلية آمنة عند انقطاع قاعدة البيانات مؤقتًا.
2. **مصدر Icecast واحد مستمر لكل محطة.** المستمعون لا يشغّلون الملفات؛ يتصلون Mount ثابتًا ويسمعون اللحظة نفسها.
3. **Leader واحد لكل محطة.** lease في PostgreSQL مع fencing token، إضافة إلى قفل محلي على المضيف، يمنع تنفيذ الأمر أو البث مرتين.
4. **الوقت محفوظ UTC، والتكرار معرّف بزمن IANA للمحطة.** كل occurrence له مفتاح فريد يمنع التكرار بعد restart أو DST.
5. **الأوامر append-only نسبيًا.** لوحة الإدارة تنشئ Command ولا تعدّل Queue أو FFmpeg مباشرة. التنفيذ claim/ack/idempotent وله Audit Trail.
6. **مخططات قاعدة البيانات منفصلة.** `api` سطح قراءة عام محدود، `app` بيانات الإدارة، و`radio` حالة التشغيل. لا تُكشف جداول التشغيل الداخلية عبر Data API.
7. **المعالجة مرة واحدة.** الأصل خاص، النسخة الموحدة جاهزة للبث/الطلب عند `READY` فقط، مع checksum وإصدار processing profile.
8. **Never Silence متعدد الطبقات.** scheduled/manual → default playlist → emergency cache → short bounded silence only أثناء تبديل decoder، مع encoder/source connection مستمر.
9. **On-Demand منفصل.** روابط ملفات/CDN قابلة للـseek ولا تمر عبر Icecast أو Queue المحطة.
10. **MVP محطة واحدة لكن كل البيانات والleases والmetrics مرتبطة بـ`station_id`.**
11. **Unified station catalog مع execution boundaries.** INTERNAL فقط يدخل Scheduler/Queue/Commands؛ EXTERNAL يشغّل direct من المصدر ولا يؤثر عطله في البث المملوك.
12. **External rights deny-by-default.** جميع seed الخارجية `REVIEW_REQUIRED`, `UNKNOWN`, و`production_enabled=false` حتى مراجعة الحقوق.

## نقاط تحتاج اعتماد المالك

| القرار | التوصية | أثر التأجيل |
|---|---|---|
| محرك playout | **Liquidsoap كـrender adapter** تحت Radio Engine، وFFmpeg للمعالجة/probe؛ البديل custom persistent FFmpeg pipeline | قرار مبكر لأنه يغيّر تنفيذ Phase F–H واختبارات audio gaps |
| تخزين الإنتاج | Supabase Storage للأصل/processed في MVP، مع StoragePort يسمح S3 لاحقًا | يؤثر على signed URLs وegress/backup |
| جودة النسخة الموحدة | AAC-LC 96 kbps, 44.1 kHz, stereo افتراضيًا؛ MP3 128 kbps إن تطلبت أجهزة قديمة | يؤثر على bandwidth والتوافق |
| سياسة قطع المجدول | `FINISH_CURRENT` افتراضي، `INTERRUPT` صريح فقط | يؤثر على تجربة الاستماع ودقة المواعيد |
| زمن الاحتفاظ | commands/events سنة، play history 13 شهرًا، logs الساخنة 30 يومًا | يؤثر على التكلفة والامتثال |
| Region/Timezone أول محطة | يحددها المالك؛ timezone يجب أن يكون IANA مثل `Asia/Riyadh` | مطلوب قبل Seed المحطة واختبارات DST |
| تصنيف مشروع Supabase الحالي | اجعله `development` أو `staging`، وليس production قبل اختبارات الاستعادة والأمن | يمنع خلط بيانات/أسرار البيئات |
| سياسة نشر المصادر الخارجية | اعتماد workflow الحقوق والـattribution قبل تحويل أي source إلى production | الروابط العامة ليست ترخيصًا |

## حالة المراحل المنفذة

اكتملت Database Phase في `docs/DATABASE_PHASE_REPORT.md`، وStorage Phase في `docs/STORAGE_PHASE_REPORT.md`. لا تبدأ Audio Processing قبل اعتماد تقرير Storage.
