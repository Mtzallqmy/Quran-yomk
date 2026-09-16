# Deployment & Infrastructure Guide — Quran Yutla (قرآن يتلى)

## 1. Local Development Quickstart

### Prerequisites
- Node.js 20+ & npm
- JDK 17 & Android SDK (for Android app)
- Docker & Docker Compose (for Supabase & Icecast/Liquidsoap)

### Verify Canonical Quran Dataset
```bash
./scripts/validate-checksums.sh
```

### Run Supabase Database & Migrations Locally
```bash
supabase start
supabase db reset
```

### Run Admin Web Dashboard
```bash
cd apps/admin
npm install
npm run dev
# Dashboard accessible at http://localhost:3000
```

### Run Audio Processing Worker
```bash
cd services/audio-worker
npm install
npm run start
```

### Run Managed Radio Engine
```bash
cd services/radio-engine
npm install
npm run start
```

---

## 2. Production Deployment Topology
- **Database & Auth**: Supabase Managed Cloud or Self-Hosted PostgreSQL 15+ with pg_crypto.
- **Edge API**: Supabase Edge Functions (`quran-yutla-api` and `notifications`).
- **Web Admin**: Next.js deployed on Vercel or containerized on Cloud Run.
- **Radio Engine & Audio Worker**: Dedicated compute nodes running Liquidsoap 2.2 and Icecast 2 with persistent volumes for audio cache.
- **Android Client**: Signed release APK distributed via Google Play Store and official APK mirrors.
