import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const data = {
      station: {
        id: "radio-main-general",
        titleArabic: "إذاعة التلاوات الخاشعة",
        titleEnglish: "Curated Quran Radio",
        streamUrl: "https://stream.quranyutla.app/live.mp3",
        status: "active",
        currentReciter: "الشيخ عبد الباسط عبد الصمد",
        currentSurah: "سورة مريم",
        listenersCount: 1420
      },
      schedule: [
        {
          time: "14:00",
          surah: "سورة الكهف",
          reciter: "الشيخ مشاري راشد العفاسي",
          durationMinutes: 42
        },
        {
          time: "14:45",
          surah: "سورة يس",
          reciter: "الشيخ عبد الرحمن السديس",
          durationMinutes: 28
        }
      ],
      timestamp: new Date().toISOString()
    };

    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500
    });
  }
});
