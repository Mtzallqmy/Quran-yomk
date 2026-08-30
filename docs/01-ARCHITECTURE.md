# 01 — System Architecture

## 1. تحليل المتطلبات وحدود النظام

المنصة ثلاثة منتجات تشترك في البيانات ولا تشترك في مسار الصوت:

- **Live Radio:** بث خطي مستمر؛ كل مستمع عند اللحظة نفسها؛ لا seek.
- **On-Demand Quran:** ملفات مستقلة قابلة للـseek والـqueue والسرعة والاستئناف.
- **Administration:** إدارة المحتوى والجدولة والأوامر والصلاحيات والمراقبة.

متطلبات الجودة الحاكمة: بث 24/7، deterministic scheduling، تنفيذ command مرة واحدة فعليًا، استعادة بعد crash، عدم ربط استمرار الصوت بتوفر لوحة الإدارة، دعم محطة واحدة الآن وعدة محطات لاحقًا، وأقل جمع ممكن للبيانات الشخصية.

### خارج MVP

الميكروفون الحي، Push، downloads، حسابات المستمعين، CarPlay/Android Auto، casting، schedule calendars المتخصصة، والتحليلات المتقدمة. تُحفظ seams لها فقط من دون تنفيذها.

## 2. المعمارية النهائية

```mermaid
flowchart TB
  subgraph Clients["Clients"]
    Mobile["Flutter App"]
    Admin["Next.js Admin"]
  end
  subgraph Control["Control Plane"]
    API["REST API"]
    DB[("Supabase Postgres")]
    Store[("Object Storage")]
    Worker["Audio Worker"]
  end
  subgraph Playout["Playout Plane / Station"]
    Engine["Radio Engine"]
    Render["Continuous Playout"]
    Icecast["Icecast"]
  end
  Mobile -->|"metadata / on-demand"| API
  Admin --> API
  API --> DB
  API --> Store
  Worker --> DB
  Worker --> Store
  Engine --> DB
  Engine --> Render
  Render --> Icecast
  Mobile -->|"one live mount"| Icecast
```

### مسار التحكم

1. Admin يصادق عبر Supabase Auth.
2. REST API يتحقق من JWT ثم permission في قاعدة البيانات.
3. تعديلات المحتوى/الجدولة معاملات PostgreSQL.
4. Play Now/Next/Interrupt ينشئ صفًا في `radio.radio_commands` مع idempotency key.
5. Leader المحطة يطالب بالأمر وينفذه ويسجل event/result.

### مسار الصوت

1. الملفات المعالجة فقط تدخل Queue.
2. Engine يختار المصدر وفق الأولوية والسياسة.
3. Render adapter يحافظ على encoder/source connection واحد مستمر.
4. Icecast يوزع البث نفسه على جميع المستمعين؛ لا اتصال file-per-listener.

## 3. مسؤوليات المكونات

| المكون | مسؤولياته | لا يفعله |
|---|---|---|
| Flutter | Live/On-demand playback، cache، favorites، sleep timer | لا يجدول ولا يبث MP3 لكل مستمع |
| Next.js Admin | UI responsive وsession UX | لا يصل إلى FFmpeg أو Queue مباشرة |
| REST API | validation، versioning، RBAC، idempotency، public projections | لا يقوم playout مستمرًا |
| PostgreSQL | source of truth، constraints، leases، audit، occurrence ledger | ليس message bus صوتيًا |
| Storage | original/processed/artwork، signed access | لا يحمل حالة الجدولة |
| Audio Worker | probe/normalize/encode/metadata/checksum | لا يشغّل مادة غير `READY` |
| Scheduler داخل Engine | materialize due occurrences بوقت المحطة | لا يغيّر تعريف schedule |
| Queue Manager | deterministic candidate selection وresume frames | لا يقبل mutation من UI |
| Radio Engine | state/leader/commands/checkpoints/recovery | لا يخدم المستمعين مباشرة |
| Playout adapter | decode/switch/mix/continuous encoder/metadata | لا يقرر أولوية الأعمال |
| Icecast | fan-out، mounts، listener stats | لا يدير schedule |
| Watchdog | process/stream health/restart/escalation | لا يحل conflict scheduling |

## 4. اختيار تقنيات الخدمات

- **API:** TypeScript + Fastify مقترح؛ typed JSON schemas/OpenAPI وسرعة تشغيل جيدة. البديل Next.js Route Handlers يقلل خدمة لكنه يربط Public/Admin API بدورة نشر الواجهة.
- **Workers/Engine:** TypeScript service مناسب لتشارك الأنواع، مع child-process supervision. إن أثبت اختبار soak أن jitter/GC يؤثر في playout، يبقى render adapter منفصلًا ولا يلزم تغيير control logic.
- **Playout:** التوصية Liquidsoap كطبقة playout مصممة للراديو، مع FFmpeg للـprobe/processing. البديل custom long-lived FFmpeg encoder يتغذى PCM؛ يحتاج إثبات gapless/failover أصعب. هذا قرار اعتماد قبل التنفيذ.
- **Supabase:** Managed Postgres/Auth/Storage؛ لا تُستخدم Edge Functions للعمل الدائم.

## 5. حدود الاتساق

- DB transaction يثبت schedule/command، وليس بدء الصوت نفسه.
- التنفيذ **at-least-once claim + idempotent effect**؛ لا يمكن ضمان exactly-once بين DB وعملية صوت خارجية بلا مصالحة.
- كل أثر خارجي يسبقه/يتبعه `radio_event` وحالة command قابلة للمصالحة.
- `now_playing` projection يكتب بعد ACK من playout، لا عند نية التشغيل.

## 6. Dependencies

PostgreSQL 15+، Supabase Auth/Storage، FFmpeg/ffprobe بإصدار pinned، Icecast 2.x pinned، playout adapter pinned، Nginx، container runtime، TLS issuer، وhost persistent volume لملفات emergency/cache.

## 7. المخاطر

- الاعتماد على hosted DB من playout؛ يعالج snapshot/cache ووضع degraded.
- فجوة عند تبديل process؛ يعالج مصدر/encoder مستمر واختبارات waveform.
- نمو history/logs؛ partition/retention.
- drift بين DB وplayout؛ ACK + reconciliation.
- تكلفة egress؛ قياس قبل multi-station.

## 8. Acceptance Criteria

- كل component له owner وحدود واضحة.
- لا يوجد مسار من Admin إلى FFmpeg/Icecast control مباشرة.
- تعطل API لا يوقف Queue الحالية.
- live وon-demand مساران منفصلان موثقًا.
- إضافة محطة لا تتطلب schema جديدًا أو binary مختلفًا.
