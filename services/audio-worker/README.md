# Tarteel Audio Worker

خدمة Node.js/TypeScript مستقلة لمعالجة media من `UPLOADED` إلى `READY`. تستخدم PostgreSQL كـdurable queue وSupabase Storage private access، وتشغّل `ffprobe` ثم FFmpeg بقوائم arguments بدون shell.

## Development

```bash
npm ci
npm run build
npm run check:dependencies
npm test
cp .env.example .env
npm run run:once
npm start
```

لا تستخدم `.env.example` كقيمة حقيقية. متغير `TARTEEL_SUPABASE_SECRET_KEY` server-only ولا يجوز طباعته أو تمريره في command line. يبدأ الـWorker بـrecovery للleases المنتهية، ثم يطالب jobs ذريًا. إيقاف `SIGTERM` يمنع claims جديدة؛ الـlease/fencing يتعاملان مع crash القسري.

## Container

```bash
docker build -t tarteel-audio-worker:dev .
docker run --rm --env-file .env tarteel-audio-worker:dev
```

يشغّل Container العملية كمستخدم `node` غير root. يجب تثبيت image digest في CI/CD قبل production؛ `bookworm-slim` هنا foundation للتطوير وليس deployment approval.
