# Quran Radio Platform — Technical Design & Foundation

**الحالة:** Draft for approval  
**النطاق:** المرحلة الأولى فقط — لا يحتوي هذا المجلد على تنفيذ تشغيلي أو Flutter UI أو migrations قابلة للتطبيق.  
**المرجع:** Master Prompt المعتمد للمشروع.

**Supabase target (read-only verification):** مشروع managed نشط في `ap-northeast-1` على PostgreSQL 17. لم تُطبّق عليه أي تغييرات في هذه المرحلة، ولم يُحسم بعد هل هو development/staging/production.

## محتويات الحزمة

| الملف | الغرض |
|---|---|
| `docs/ARCHITECTURE.md` | المتطلبات الوظيفية وغير الوظيفية، المعمارية والمسؤوليات |
| `docs/DATABASE.md` | ERD، نمذجة البيانات، القيود والفهارس وسياسة الوقت |
| `supabase/proposed-schema.sql` | DDL مرجعي للمراجعة؛ ليس Migration تنفيذية |
| `docs/RADIO_ENGINE.md` | State Machine، Queue، Commands، Never Silence |
| `docs/SCHEDULER.md` | Timezone/DST، occurrences، conflicts، restart/idempotency |
| `docs/API.md` | Public/Admin API والعقود والأخطاء والتصفح والإديمبوتنسي |
| `docs/AUDIO_PIPELINE.md` | Storage، FFmpeg، Icecast، فصل Live عن On-Demand |
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

## شرط الانتقال للمرحلة الثانية

لا تبدأ migrations قبل اعتماد نقاط القرار السابقة، ومراجعة ERD/DDL، وتوقيع Acceptance Criteria في `docs/MVP_PLAN.md`.
