# Seed Data Order

هذه الملفات تصميم/بيانات أولية للمرحلة الأولى، وليست migrations مطبقة:

1. `providers.sql`
2. `categories.sql`
3. seed السور الـ114 الذي سينشأ ويُتحقق منه في T06
4. `external_stations.sql`

`external_stations.sql` يحتوي 58 مصدرًا من inventory المقدم. كل external row:

- `station_source=EXTERNAL`
- `health_status=UNKNOWN`
- `rights_status=REVIEW_REQUIRED`
- `commercial_use_status=UNKNOWN`
- `production_enabled=false`

إعادة التشغيل تستخدم unique slugs/provider keys و`ON CONFLICT DO NOTHING` لحماية تعديلات Admin. Sync jobs لا تستخدم هذه الملفات كـbusiness logic؛ adapters تكتب normalized provider records وفق العقود في `docs/EXTERNAL_STATIONS.md`.
