const QURAN_API = "https://api.alquran.cloud/v1";
const MP3QURAN_API = "https://www.mp3quran.net/api/v3";

export type QuranApiResult = {
  data: Record<string, unknown>;
  cacheControl: string;
};

type Json = Record<string, unknown>;

function asMap(value: unknown): Json {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Json
    : {};
}
function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}
function numberValue(value: unknown, fallback = 0): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}
function textValue(value: unknown): string {
  return typeof value === "string" ? value : "";
}
async function fetchJson(url: string, timeoutMs = 12000): Promise<Json> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      headers: { accept: "application/json" },
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`UPSTREAM_${response.status}`);
    const payload = await response.json();
    if (!payload || typeof payload !== "object") throw new Error("UPSTREAM_INVALID_JSON");
    return payload as Json;
  } finally {
    clearTimeout(timeout);
  }
}

function boolSajda(value: unknown): boolean {
  if (value === true) return true;
  const map = asMap(value);
  return map.recommended === true || map.obligatory === true;
}

function normalizePassage(
  mode: "surah" | "juz" | "page",
  number: number,
  uthmaniPayload: Json,
  tajweedPayload: Json | null,
): Json {
  const root = asMap(uthmaniPayload.data);
  const verses = asArray(root.ayahs);
  const tajweedRoot = tajweedPayload ? asMap(tajweedPayload.data) : {};
  const tajweedByGlobal = new Map<number, string>();
  for (const value of asArray(tajweedRoot.ayahs)) {
    const row = asMap(value);
    const global = numberValue(row.number);
    if (global > 0) tajweedByGlobal.set(global, textValue(row.text));
  }

  const normalized: Json[] = verses.map((value) => {
    const row = asMap(value);
    const surah = asMap(row.surah);
    const globalNumber = numberValue(row.number);
    const surahNumber = numberValue(surah.number);
    const ayahNumber = numberValue(row.numberInSurah);
    return {
      global_number: globalNumber,
      surah_number: surahNumber,
      ayah_number: ayahNumber,
      verse_key: `${surahNumber}:${ayahNumber}`,
      text_uthmani: textValue(row.text),
      text_tajweed: tajweedByGlobal.get(globalNumber) || null,
      juz_number: numberValue(row.juz),
      page_number: numberValue(row.page),
      ruku_number: numberValue(row.ruku),
      hizb_quarter: numberValue(row.hizbQuarter),
      sajda: boolSajda(row.sajda),
      surah_name_ar: textValue(surah.name),
      surah_name_en: textValue(surah.englishName),
    };
  });

  const sections: Json[] = [];
  for (const verse of normalized) {
    const surahNumber = numberValue(verse.surah_number);
    const ruku = numberValue(verse.ruku_number);
    const ayah = numberValue(verse.ayah_number);
    if (surahNumber <= 0 || ruku <= 0 || ayah <= 0) continue;
    const previous = sections.at(-1);
    if (
      previous &&
      numberValue(previous.surah_number) === surahNumber &&
      numberValue(previous.ruku_number) === ruku
    ) {
      previous.to_ayah = ayah;
      continue;
    }
    sections.push({
      surah_number: surahNumber,
      from_ayah: ayah,
      to_ayah: ayah,
      title_ar: `الركوع ${ruku}`,
      title_en: `Ruku ${ruku}`,
      color_key: `theme_${ruku % 6}`,
      ruku_number: ruku,
    });
  }

  return {
    mode,
    number,
    source: "ALQURAN_CLOUD",
    source_url: "https://alquran.cloud/api",
    total_pages: 604,
    tajweed_available: tajweedByGlobal.size > 0,
    verses: normalized,
    theme_sections: sections,
  };
}

async function passage(mode: "surah" | "juz" | "page", number: number): Promise<QuranApiResult> {
  const limits = { surah: 114, juz: 30, page: 604 } as const;
  if (!Number.isInteger(number) || number < 1 || number > limits[mode]) {
    throw Object.assign(new Error("QURAN_RANGE_INVALID"), { status: 422 });
  }
  const path = `${mode}/${number}`;
  const [uthmani, tajweed] = await Promise.all([
    fetchJson(`${QURAN_API}/${path}/quran-uthmani`),
    fetchJson(`${QURAN_API}/${path}/quran-tajweed`).catch(() => null),
  ]);
  return {
    data: normalizePassage(mode, number, uthmani, tajweed),
    cacheControl: "public, max-age=300, s-maxage=21600",
  };
}

function reciterStableId(reciterId: number, moshafId: number): string {
  return `mp3quran-${reciterId}-${moshafId}`;
}
function parseReciterStableId(value: string): { reciterId: number; moshafId: number } | null {
  const match = /^mp3quran-(\d+)-(\d+)$/.exec(value);
  if (!match) return null;
  return { reciterId: Number(match[1]), moshafId: Number(match[2]) };
}
function parseSurahList(value: unknown): number[] {
  return textValue(value)
    .split(",")
    .map((item) => Number(item.trim()))
    .filter((item) => Number.isInteger(item) && item >= 1 && item <= 114);
}
function surahFile(server: string, surah: number): string {
  const base = server.replace(/\/+$/, "");
  return `${base}/${String(surah).padStart(3, "0")}.mp3`;
}

async function mp3quranReciters(surah?: number): Promise<Json[]> {
  if (surah != null && (!Number.isInteger(surah) || surah < 1 || surah > 114)) {
    throw Object.assign(new Error("SURAH_RANGE_INVALID"), { status: 422 });
  }
  const suffix = surah ? `&sura=${surah}` : "";
  const [arPayload, enPayload] = await Promise.all([
    fetchJson(`${MP3QURAN_API}/reciters?language=ar${suffix}`),
    fetchJson(`${MP3QURAN_API}/reciters?language=eng${suffix}`).catch(() => ({ reciters: [] })),
  ]);
  const englishById = new Map<number, Json>();
  for (const value of asArray(enPayload.reciters)) {
    const row = asMap(value);
    englishById.set(numberValue(row.id), row);
  }

  const values: Json[] = [];
  for (const value of asArray(arPayload.reciters)) {
    const reciter = asMap(value);
    const reciterId = numberValue(reciter.id);
    const english = englishById.get(reciterId) ?? {};
    const englishMoshafById = new Map<number, Json>();
    for (const m of asArray(english.moshaf)) {
      const map = asMap(m);
      englishMoshafById.set(numberValue(map.id), map);
    }
    for (const m of asArray(reciter.moshaf)) {
      const moshaf = asMap(m);
      const moshafId = numberValue(moshaf.id);
      const server = textValue(moshaf.server);
      const availableSurahs = parseSurahList(moshaf.surah_list);
      if (!reciterId || !moshafId || !server.startsWith("https://") || availableSurahs.length === 0) continue;
      const englishMoshaf = englishMoshafById.get(moshafId) ?? {};
      values.push({
        id: reciterStableId(reciterId, moshafId),
        provider: "MP3QURAN",
        provider_reciter_id: reciterId,
        moshaf_id: moshafId,
        name_ar: textValue(reciter.name),
        name_en: textValue(english.name) || textValue(reciter.name),
        rewaya_ar: textValue(moshaf.name),
        rewaya_en: textValue(englishMoshaf.name) || textValue(moshaf.name),
        image_url: null,
        available_surahs: availableSurahs,
        playback_url: surah && availableSurahs.includes(surah) ? surahFile(server, surah) : null,
      });
    }
  }
  return values;
}

async function reciterTracks(id: string, surahs: Json[]): Promise<Json[]> {
  const parsed = parseReciterStableId(id);
  if (!parsed) throw Object.assign(new Error("RECITER_ID_INVALID"), { status: 422 });
  const payload = await fetchJson(`${MP3QURAN_API}/reciters?language=ar&reciter=${parsed.reciterId}`);
  const reciter = asArray(payload.reciters).map(asMap).find((row) => numberValue(row.id) === parsed.reciterId);
  if (!reciter) throw Object.assign(new Error("RECITER_NOT_FOUND"), { status: 404 });
  const moshaf = asArray(reciter.moshaf).map(asMap).find((row) => numberValue(row.id) === parsed.moshafId);
  if (!moshaf) throw Object.assign(new Error("MOSHAF_NOT_FOUND"), { status: 404 });
  const server = textValue(moshaf.server);
  const available = new Set(parseSurahList(moshaf.surah_list));
  if (!server.startsWith("https://")) throw Object.assign(new Error("RECITER_STREAM_INSECURE"), { status: 422 });
  return surahs
    .filter((row) => available.has(numberValue(row.number)))
    .map((row) => ({
      surah_number: numberValue(row.number),
      playback_url: surahFile(server, numberValue(row.number)),
      surah: {
        id: numberValue(row.id),
        number: numberValue(row.number),
        name_ar: textValue(row.name_ar),
        name_en: textValue(row.name_en),
        ayah_count: numberValue(row.ayah_count),
      },
    }));
}

export async function handleQuranApi(
  parts: string[],
  params: URLSearchParams,
  publicSurahs: () => Promise<Json[]>,
): Promise<QuranApiResult | null> {
  if (parts[0] !== "quran") return null;
  if (["surah", "juz", "page"].includes(parts[1] ?? "") && parts[2]) {
    const mode = parts[1] as "surah" | "juz" | "page";
    return passage(mode, Number(parts[2]));
  }
  if (parts[1] === "reciters" && parts.length === 2) {
    const surah = params.get("surah") ? Number(params.get("surah")) : undefined;
    return {
      data: { reciters: await mp3quranReciters(surah) },
      cacheControl: "public, max-age=300, s-maxage=3600",
    };
  }
  if (parts[1] === "reciters" && parts[2] && parts[3] === "tracks") {
    return {
      data: { tracks: await reciterTracks(decodeURIComponent(parts[2]), await publicSurahs()) },
      cacheControl: "public, max-age=300, s-maxage=3600",
    };
  }
  throw Object.assign(new Error("QURAN_ENDPOINT_NOT_FOUND"), { status: 404 });
}
