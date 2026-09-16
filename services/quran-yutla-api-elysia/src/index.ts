import { Elysia } from 'elysia';
import { cors } from '@elysiajs/cors';
import { swagger } from '@elysiajs/swagger';
import * as fs from 'fs';
import * as path from 'path';

const app = new Elysia()
  .use(cors())
  .use(swagger({
    documentation: {
      info: {
        title: 'Quran Yutla BFF API (Elysia)',
        version: '1.0.0',
        description: 'High-performance aggregation layer matching Supabase Edge API contracts for Quran Yutla'
      }
    }
  }))
  // 1. Health
  .get('/health', () => ({
    status: 'healthy',
    service: 'quran-yutla-api-elysia',
    version: '1.0.0',
    edition: 'quran-uthmani-hafs-v1.0',
    timestamp: new Date().toISOString()
  }))

  // 2. Runtime Config Public Keys
  .get('/api/v1/runtime-config', () => ({
    feature_flags: {
      radio_enabled: true,
      offline_downloads: true,
      prayer_times: true,
      adhkar: true,
      learning_center: true
    },
    home_sections: ['featured_radio', 'prayer_times', 'daily_reading', 'stations_grid', 'reciters_carousel', 'offline_shelf'],
    min_supported_version: { android: '1.0.0', ios: '1.0.0' },
    maintenance: { is_active: false }
  }))

  // 3. Home Feed
  .get('/api/v1/home', () => ({
    dailyReading: {
      surahNumber: 18,
      surahNameArabic: 'سورة الكهف',
      startPage: 293,
      juzNumber: 15,
      recommendedVerses: '1-10'
    },
    featuredRadio: {
      slug: 'khashia',
      nameArabic: 'إذاعة التلاوات الخاشعة',
      currentTrack: 'سورة مريم — الشيخ عبد الباسط عبد الصمد',
      streamUrl: 'https://stream.quranyutla.app/live/khashia.mp3',
      bitrate: 128,
      listenersCount: 1420
    },
    prayerTimes: {
      city: 'الرياض',
      fajr: '04:32',
      sunrise: '05:51',
      dhuhr: '11:58',
      asr: '15:24',
      maghrib: '18:05',
      isha: '19:35'
    }
  }))

  // 4. Stations List
  .get('/api/v1/stations', () => ([
    {
      id: 'station-khashia',
      slug: 'khashia',
      titleArabic: 'إذاعة التلاوات الخاشعة',
      streamUrl: 'https://stream.quranyutla.app/live/khashia.mp3',
      fallbackStreamUrl: 'https://fallback.quranyutla.app/live/khashia.mp3',
      bitrateKbps: 128,
      isFeatured: true
    },
    {
      id: 'station-murattal',
      slug: 'murattal',
      titleArabic: 'إذاعة المصحف المرتل',
      streamUrl: 'https://stream.quranyutla.app/live/murattal.mp3',
      bitrateKbps: 128,
      isFeatured: true
    },
    {
      id: 'station-haramain',
      slug: 'haramain',
      titleArabic: 'إذاعة تلاوات الحرمين الشريفين',
      streamUrl: 'https://stream.quranyutla.app/live/haramain.mp3',
      bitrateKbps: 128,
      isFeatured: false
    }
  ]))

  // 5. Reciters List
  .get('/api/v1/reciters', () => ([
    {
      id: 'reciter-abdulbasit',
      canonicalSlug: 'abdulbasit-abdussamad',
      nameArabic: 'الشيخ عبد الباسط عبد الصمد',
      nameEnglish: 'Sheikh Abdulbasit Abdussamad',
      defaultRiwayah: 'المصحف المجود • حفص عن عاصم',
      surahsCount: 114,
      provider: 'مجمع الملك فهد / أرشيف إذاعة القرآن'
    },
    {
      id: 'reciter-minshawi',
      canonicalSlug: 'mohamed-siddiq-el-minshawi',
      nameArabic: 'الشيخ محمد صديق المنشاوي',
      nameEnglish: 'Sheikh Mohamed Siddiq El-Minshawi',
      defaultRiwayah: 'المصحف المرتل • حفص عن عاصم',
      surahsCount: 114,
      provider: 'مجمع الملك فهد / أرشيف القاهرة'
    }
  ]))

  // 6. Quran Surahs (Verified canonical fallback)
  .get('/api/v1/quran/surahs', () => {
    try {
      const p = path.resolve(process.cwd(), 'data/quran/canonical/surahs.json');
      if (fs.existsSync(p)) {
        return JSON.parse(fs.readFileSync(p, 'utf8'));
      }
    } catch {
      // Return safe standard
    }
    return [
      { number: 1, nameArabic: 'الفاتحة', ayahCount: 7, startPage: 1, endPage: 1 },
      { number: 18, nameArabic: 'الكهف', ayahCount: 110, startPage: 293, endPage: 304 }
    ];
  })
  .listen(3001);

console.log(`Quran Yutla Elysia BFF running at http://localhost:3001`);

export type App = typeof app;
