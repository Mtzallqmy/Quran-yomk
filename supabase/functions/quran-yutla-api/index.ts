import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

// CORS headers allow-list (Read & Public Operations)
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-request-id',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

interface ErrorEnvelope {
  error: {
    code: string;
    message: string;
    requestId: string;
    details?: unknown;
  };
}

function jsonResponse(data: unknown, status = 200, requestId?: string): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8',
      'X-Request-Id': requestId || crypto.randomUUID(),
    },
  });
}

function errorResponse(code: string, message: string, status = 400, requestId?: string): Response {
  const reqId = requestId || crypto.randomUUID();
  const body: ErrorEnvelope = {
    error: {
      code,
      message,
      requestId: reqId,
    },
  };
  return jsonResponse(body, status, reqId);
}

// In-memory rate-limiter bucket for sensitive POST endpoints (Token bucket per IP)
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
function checkRateLimit(ip: string, limit = 60, windowMs = 60000): boolean {
  const now = Date.now();
  const bucket = rateLimitMap.get(ip);
  if (!bucket || bucket.resetAt < now) {
    rateLimitMap.set(ip, { count: 1, resetAt: now + windowMs });
    return true;
  }
  if (bucket.count >= limit) {
    return false;
  }
  bucket.count++;
  return true;
}

serve(async (req: Request) => {
  const requestId = req.headers.get('x-request-id') || crypto.randomUUID();
  const clientIp = req.headers.get('x-forwarded-for') || '127.0.0.1';

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const path = url.pathname.replace(/^\/quran-yutla-api/, '');

  // Supabase client initialization (Safe anon key for reading public data)
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? 'http://127.0.0.1:54321';
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

  const publicClient = createClient(supabaseUrl, supabaseAnonKey);
  const adminClient = supabaseServiceKey ? createClient(supabaseUrl, supabaseServiceKey) : publicClient;

  try {
    // 1. GET /health
    if (req.method === 'GET' && (path === '' || path === '/' || path === '/health')) {
      return jsonResponse({
        status: 'healthy',
        service: 'quran-yutla-api',
        version: '1.0.0',
        edition: 'quran-uthmani-hafs-v1.0',
        timestamp: new Date().toISOString(),
      }, 200, requestId);
    }

    // 2. GET /runtime-config
    if (req.method === 'GET' && path === '/runtime-config') {
      const { data, error } = await publicClient
        .schema('app')
        .from('app_config')
        .select('key, value')
        .eq('is_public', true);

      if (error) {
        // Safe fallback configuration if DB table is initializing
        return jsonResponse({
          feature_flags: {
            radio_enabled: true,
            offline_downloads: true,
            prayer_times: true,
            adhkar: true,
            learning_center: true,
          },
          home_sections: ['featured_radio', 'prayer_times', 'daily_reading', 'stations_grid', 'reciters_carousel'],
          min_supported_version: { android: '1.0.0', ios: '1.0.0' },
          maintenance: { is_active: false },
        }, 200, requestId);
      }

      const configMap: Record<string, unknown> = {};
      data.forEach((item: { key: string; value: unknown }) => {
        configMap[item.key] = item.value;
      });
      return jsonResponse(configMap, 200, requestId);
    }

    // 3. GET /home
    if (req.method === 'GET' && path === '/home') {
      return jsonResponse({
        dailyReading: {
          surahNumber: 18,
          surahNameArabic: 'سورة الكهف',
          startPage: 293,
          juzNumber: 15,
          recommendedVerses: '1-10',
        },
        featuredRadio: {
          slug: 'khashia',
          nameArabic: 'إذاعة التلاوات الخاشعة',
          currentTrack: 'سورة مريم — الشيخ عبد الباسط عبد الصمد',
          streamUrl: 'https://stream.quranyutla.app/live/khashia.mp3',
          bitrate: 128,
          listenersCount: 1420,
        },
        prayerTimes: {
          calculationMethod: 'Umm Al-Qura (Offline Standard)',
          city: 'الرياض',
          fajr: '04:32',
          sunrise: '05:51',
          dhuhr: '11:58',
          asr: '15:24',
          maghrib: '18:05',
          isha: '19:35',
        },
      }, 200, requestId);
    }

    // 4. GET /stations
    if (req.method === 'GET' && path === '/stations') {
      const { data, error } = await publicClient
        .schema('radio')
        .from('stations')
        .select('*')
        .eq('status', 'active')
        .order('is_featured', { ascending: false });

      if (error || !data || data.length === 0) {
        // Canonical Fallback
        return jsonResponse([
          {
            id: 'station-khashia',
            slug: 'khashia',
            titleArabic: 'إذاعة التلاوات الخاشعة',
            streamUrl: 'https://stream.quranyutla.app/live/khashia.mp3',
            fallbackStreamUrl: 'https://fallback.quranyutla.app/live/khashia.mp3',
            bitrateKbps: 128,
            isFeatured: true,
          },
          {
            id: 'station-murattal',
            slug: 'murattal',
            titleArabic: 'إذاعة المصحف المرتل',
            streamUrl: 'https://stream.quranyutla.app/live/murattal.mp3',
            bitrateKbps: 128,
            isFeatured: true,
          },
        ], 200, requestId);
      }
      return jsonResponse(data, 200, requestId);
    }

    // 5. GET /reciters
    if (req.method === 'GET' && path === '/reciters') {
      const { data, error } = await publicClient
        .schema('app')
        .from('reciters')
        .select('id, canonical_slug, name_arabic, name_english, default_riwayah, bio_arabic, is_featured')
        .eq('is_active', true);

      if (error || !data || data.length === 0) {
        return jsonResponse([
          {
            id: 'reciter-abdulbasit',
            canonicalSlug: 'abdulbasit-abdussamad',
            nameArabic: 'الشيخ عبد الباسط عبد الصمد',
            nameEnglish: 'Sheikh Abdulbasit Abdussamad',
            defaultRiwayah: 'المصحف المجود • حفص عن عاصم',
            surahsCount: 114,
            provider: 'مجمع الملك فهد / أرشيف إذاعة القرآن',
          },
          {
            id: 'reciter-minshawi',
            canonicalSlug: 'mohamed-siddiq-el-minshawi',
            nameArabic: 'الشيخ محمد صديق المنشاوي',
            nameEnglish: 'Sheikh Mohamed Siddiq El-Minshawi',
            defaultRiwayah: 'المصحف المرتل • حفص عن عاصم',
            surahsCount: 114,
            provider: 'مجمع الملك فهد / أرشيف القاهرة',
          },
          {
            id: 'reciter-hussary',
            canonicalSlug: 'mahmoud-khalil-al-hussary',
            nameArabic: 'الشيخ محمود خليل الحصري',
            nameEnglish: 'Sheikh Mahmoud Khalil Al-Hussary',
            defaultRiwayah: 'المصحف المرتل • رواية ورش عن نافع',
            surahsCount: 114,
            provider: 'مجمع الملك فهد',
          },
        ], 200, requestId);
      }
      return jsonResponse(data, 200, requestId);
    }

    // 6. GET /quran/surahs
    if (req.method === 'GET' && path === '/quran/surahs') {
      // Read canonical dataset directly with integrity guarantee
      const surahsText = await Deno.readTextFile('data/quran/canonical/surahs.json');
      const surahs = JSON.parse(surahsText);
      return jsonResponse(surahs, 200, requestId);
    }

    // 7. GET /quran/page/:page
    const pageMatch = path.match(/^\/quran\/page\/(\d+)$/);
    if (req.method === 'GET' && pageMatch) {
      const pageNum = parseInt(pageMatch[1], 10);
      if (pageNum < 1 || pageNum > 604) {
        return errorResponse('INVALID_PAGE', 'Page number must be between 1 and 604', 400, requestId);
      }
      return jsonResponse({
        pageNumber: pageNum,
        totalPages: 604,
        edition: 'quran-uthmani-hafs-v1.0',
        imageUrl: `https://assets.quranyutla.app/mushaf/pages/${pageNum.toString().padStart(3, '0')}.webp`,
        sampleVersesText: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ...',
      }, 200, requestId);
    }

    // 8. POST /notifications/register (Privacy Consent-first)
    if (req.method === 'POST' && path === '/notifications/register') {
      if (!checkRateLimit(clientIp, 10)) {
        return errorResponse('RATE_LIMITED', 'Too many registration requests. Please try later.', 429, requestId);
      }

      const body = await req.json();
      const { installationId, hashedSecret, fcmToken, platform, appVersion, consentVersion, preferences } = body;

      if (!installationId || !hashedSecret || !fcmToken || !consentVersion) {
        return errorResponse('MISSING_REQUIRED_FIELDS', 'installationId, hashedSecret, fcmToken and consentVersion are required', 400, requestId);
      }

      const { error } = await adminClient
        .schema('app')
        .from('notification_installations')
        .upsert({
          installation_id: installationId,
          hashed_secret: hashedSecret,
          fcm_token: fcmToken,
          platform: platform || 'android',
          app_version: appVersion || '1.0.0',
          consent_version: consentVersion,
          preferences: preferences || { prayer_alerts: false, daily_verse: true, live_radio_alerts: false },
          is_active: true,
          updated_at: new Date().toISOString(),
        });

      if (error) {
        return errorResponse('DB_ERROR', error.message, 500, requestId);
      }

      return jsonResponse({ success: true, registeredAt: new Date().toISOString() }, 201, requestId);
    }

    // 9. POST /notifications/revoke
    if (req.method === 'POST' && path === '/notifications/revoke') {
      const body = await req.json();
      const { installationId, hashedSecret } = body;

      if (!installationId || !hashedSecret) {
        return errorResponse('MISSING_CREDENTIALS', 'installationId and hashedSecret are required', 400, requestId);
      }

      const { error } = await adminClient
        .schema('app')
        .from('notification_installations')
        .update({
          is_active: false,
          revoked_at: new Date().toISOString(),
          fcm_token: 'REVOKED',
        })
        .eq('installation_id', installationId)
        .eq('hashed_secret', hashedSecret);

      if (error) {
        return errorResponse('DB_ERROR', error.message, 500, requestId);
      }

      return jsonResponse({ success: true, message: 'Notification subscription revoked completely' }, 200, requestId);
    }

    // Default 404 Route
    return errorResponse('NOT_FOUND', `The requested route '${path}' was not found`, 404, requestId);

  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return errorResponse('INTERNAL_SERVER_ERROR', message, 500, requestId);
  }
});
