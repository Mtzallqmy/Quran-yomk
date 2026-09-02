import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";

export const DATASET_NAME = "tarteel-quran-canonical";
export const SCHEMA_VERSION = 1;
export const EXPECTED_EDITIONS = Object.freeze({
  uthmani: "quran-uthmani",
  tajweed: "quran-tajweed",
});

export function sha256(value) {
  const bytes = typeof value === "string" ? Buffer.from(value, "utf8") : value;
  return createHash("sha256").update(bytes).digest("hex");
}

export function canonicalJson(value) {
  return `${JSON.stringify(value, null, 2)}\n`;
}

export function invariant(condition, code, detail = "") {
  if (!condition) {
    const suffix = detail ? `: ${detail}` : "";
    throw new Error(`${code}${suffix}`);
  }
}

function asObject(value, code) {
  invariant(value && typeof value === "object" && !Array.isArray(value), code);
  return value;
}

function asArray(value, code) {
  invariant(Array.isArray(value), code);
  return value;
}

function positiveInteger(value, code) {
  invariant(Number.isInteger(value) && value > 0, code, String(value));
  return value;
}

function nonEmptyText(value, code) {
  invariant(typeof value === "string" && value.length > 0, code);
  return value;
}

function normalizeSajda(value) {
  if (value === true || value === false) return value;
  if (value && typeof value === "object") {
    return value.recommended === true || value.obligatory === true;
  }
  return false;
}

export async function fetchJsonBounded(url, options = {}) {
  const timeoutMs = options.timeoutMs ?? 30_000;
  const maxBytes = options.maxBytes ?? 20_000_000;
  const parsed = new URL(url);
  invariant(parsed.protocol === "https:", "QURAN_SOURCE_HTTPS_REQUIRED", url);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(parsed, {
      method: "GET",
      redirect: "error",
      signal: controller.signal,
      headers: {
        accept: "application/json",
        "user-agent": "Tarteel-Quran-Integrity/1",
      },
    });
    invariant(response.ok, "QURAN_SOURCE_HTTP_ERROR", `${response.status} ${url}`);
    const contentType = response.headers.get("content-type") ?? "";
    invariant(contentType.includes("json"), "QURAN_SOURCE_CONTENT_TYPE_INVALID", contentType);
    const advertised = Number(response.headers.get("content-length") ?? "0");
    invariant(!advertised || advertised <= maxBytes, "QURAN_SOURCE_RESPONSE_TOO_LARGE", String(advertised));

    const bytes = Buffer.from(await response.arrayBuffer());
    invariant(bytes.byteLength <= maxBytes, "QURAN_SOURCE_RESPONSE_TOO_LARGE", String(bytes.byteLength));
    let payload;
    try {
      payload = JSON.parse(bytes.toString("utf8"));
    } catch {
      throw new Error("QURAN_SOURCE_JSON_INVALID");
    }
    asObject(payload, "QURAN_SOURCE_PAYLOAD_INVALID");
    return { payload, rawSha256: sha256(bytes), bytes: bytes.byteLength };
  } finally {
    clearTimeout(timer);
  }
}

export async function readSeedAyahCounts(seedPath = "supabase/seed/03_surahs.sql") {
  const source = await readFile(seedPath, "utf8");
  const counts = new Map();
  const tuple = /\(\s*\d+\s*,\s*(\d+)\s*,\s*'[^']*'\s*,\s*'[^']*'\s*,\s*(\d+)\s*\)/g;
  for (const match of source.matchAll(tuple)) {
    const surah = Number(match[1]);
    const count = Number(match[2]);
    invariant(!counts.has(surah), "QURAN_SEED_DUPLICATE_SURAH", String(surah));
    counts.set(surah, count);
  }
  invariant(counts.size === 114, "QURAN_SEED_SURAH_COUNT_INVALID", String(counts.size));
  for (let surah = 1; surah <= 114; surah += 1) {
    invariant(counts.has(surah), "QURAN_SEED_SURAH_MISSING", String(surah));
  }
  return counts;
}

function editionIdentifier(payload, label) {
  const data = asObject(payload.data, `QURAN_${label}_DATA_INVALID`);
  const edition = asObject(data.edition, `QURAN_${label}_EDITION_INVALID`);
  return nonEmptyText(edition.identifier, `QURAN_${label}_EDITION_ID_INVALID`);
}

function indexTajweed(payload) {
  const data = asObject(payload.data, "QURAN_TAJWEED_DATA_INVALID");
  const surahs = asArray(data.surahs, "QURAN_TAJWEED_SURAHS_INVALID");
  const byGlobal = new Map();
  for (const rawSurah of surahs) {
    const surah = asObject(rawSurah, "QURAN_TAJWEED_SURAH_INVALID");
    const surahNumber = positiveInteger(surah.number, "QURAN_TAJWEED_SURAH_NUMBER_INVALID");
    for (const rawAyah of asArray(surah.ayahs, "QURAN_TAJWEED_AYAHS_INVALID")) {
      const ayah = asObject(rawAyah, "QURAN_TAJWEED_AYAH_INVALID");
      const globalNumber = positiveInteger(ayah.number, "QURAN_TAJWEED_GLOBAL_NUMBER_INVALID");
      invariant(!byGlobal.has(globalNumber), "QURAN_TAJWEED_DUPLICATE_GLOBAL_NUMBER", String(globalNumber));
      byGlobal.set(globalNumber, {
        surahNumber,
        ayahNumber: positiveInteger(ayah.numberInSurah, "QURAN_TAJWEED_AYAH_NUMBER_INVALID"),
        text: nonEmptyText(ayah.text, "QURAN_TAJWEED_TEXT_EMPTY"),
      });
    }
  }
  return byGlobal;
}

export function buildCanonicalDataset({ version, uthmaniPayload, tajweedPayload, seedAyahCounts }) {
  invariant(/^\d+$/.test(String(version)), "QURAN_DATASET_VERSION_INVALID", String(version));
  invariant(editionIdentifier(uthmaniPayload, "UTHMANI") === EXPECTED_EDITIONS.uthmani,
    "QURAN_UTHMANI_EDITION_MISMATCH", editionIdentifier(uthmaniPayload, "UTHMANI"));
  invariant(editionIdentifier(tajweedPayload, "TAJWEED") === EXPECTED_EDITIONS.tajweed,
    "QURAN_TAJWEED_EDITION_MISMATCH", editionIdentifier(tajweedPayload, "TAJWEED"));

  const uthmaniData = asObject(uthmaniPayload.data, "QURAN_UTHMANI_DATA_INVALID");
  const uthmaniSurahs = asArray(uthmaniData.surahs, "QURAN_UTHMANI_SURAHS_INVALID");
  invariant(uthmaniSurahs.length === 114, "QURAN_SURAH_COUNT_INVALID", String(uthmaniSurahs.length));
  const tajweedByGlobal = indexTajweed(tajweedPayload);
  const seenVerseKeys = new Set();
  const seenGlobals = new Set();
  const seenPages = new Set();
  const seenJuz = new Set();
  let previousGlobal = 0;
  let previousPage = 0;
  let previousJuz = 0;

  const surahs = uthmaniSurahs.map((rawSurah, index) => {
    const surah = asObject(rawSurah, "QURAN_UTHMANI_SURAH_INVALID");
    const surahNumber = positiveInteger(surah.number, "QURAN_SURAH_NUMBER_INVALID");
    invariant(surahNumber === index + 1, "QURAN_SURAH_ORDER_INVALID", String(surahNumber));
    const ayahs = asArray(surah.ayahs, "QURAN_UTHMANI_AYAHS_INVALID");
    const expectedCount = seedAyahCounts.get(surahNumber);
    invariant(Number.isInteger(expectedCount), "QURAN_SEED_SURAH_MISSING", String(surahNumber));
    invariant(ayahs.length === expectedCount, "QURAN_AYAH_COUNT_MISMATCH", `${surahNumber}:${ayahs.length}!=${expectedCount}`);

    const verses = ayahs.map((rawAyah, ayahIndex) => {
      const ayah = asObject(rawAyah, "QURAN_UTHMANI_AYAH_INVALID");
      const globalNumber = positiveInteger(ayah.number, "QURAN_GLOBAL_NUMBER_INVALID");
      const ayahNumber = positiveInteger(ayah.numberInSurah, "QURAN_AYAH_NUMBER_INVALID");
      invariant(ayahNumber === ayahIndex + 1, "QURAN_AYAH_ORDER_INVALID", `${surahNumber}:${ayahNumber}`);
      invariant(globalNumber === previousGlobal + 1, "QURAN_GLOBAL_ORDER_INVALID", String(globalNumber));
      previousGlobal = globalNumber;
      invariant(!seenGlobals.has(globalNumber), "QURAN_DUPLICATE_GLOBAL_NUMBER", String(globalNumber));
      seenGlobals.add(globalNumber);

      const verseKey = `${surahNumber}:${ayahNumber}`;
      invariant(!seenVerseKeys.has(verseKey), "QURAN_DUPLICATE_VERSE_KEY", verseKey);
      seenVerseKeys.add(verseKey);

      const tajweed = tajweedByGlobal.get(globalNumber);
      invariant(Boolean(tajweed), "QURAN_TAJWEED_VERSE_MISSING", verseKey);
      invariant(tajweed.surahNumber === surahNumber && tajweed.ayahNumber === ayahNumber,
        "QURAN_TAJWEED_IDENTITY_MISMATCH", verseKey);

      const page = positiveInteger(ayah.page, "QURAN_PAGE_INVALID");
      const juz = positiveInteger(ayah.juz, "QURAN_JUZ_INVALID");
      invariant(page >= previousPage, "QURAN_PAGE_ORDER_INVALID", verseKey);
      invariant(juz >= previousJuz, "QURAN_JUZ_ORDER_INVALID", verseKey);
      previousPage = page;
      previousJuz = juz;
      seenPages.add(page);
      seenJuz.add(juz);

      return {
        global_number: globalNumber,
        ayah_number: ayahNumber,
        verse_key: verseKey,
        text_uthmani: nonEmptyText(ayah.text, "QURAN_UTHMANI_TEXT_EMPTY"),
        text_tajweed: tajweed.text,
        juz_number: juz,
        page_number: page,
        ruku_number: positiveInteger(ayah.ruku, "QURAN_RUKU_INVALID"),
        hizb_quarter: positiveInteger(ayah.hizbQuarter, "QURAN_HIZB_QUARTER_INVALID"),
        sajda: normalizeSajda(ayah.sajda),
      };
    });

    return {
      number: surahNumber,
      name_ar: nonEmptyText(surah.name, "QURAN_SURAH_AR_NAME_EMPTY"),
      name_en: nonEmptyText(surah.englishName, "QURAN_SURAH_EN_NAME_EMPTY"),
      ayah_count: expectedCount,
      verses,
    };
  });

  invariant(tajweedByGlobal.size === seenGlobals.size, "QURAN_TAJWEED_CARDINALITY_MISMATCH",
    `${tajweedByGlobal.size}!=${seenGlobals.size}`);
  invariant(seenPages.size === 604, "QURAN_PAGE_SET_INVALID", String(seenPages.size));
  for (let page = 1; page <= 604; page += 1) invariant(seenPages.has(page), "QURAN_PAGE_MISSING", String(page));
  invariant(seenJuz.size === 30, "QURAN_JUZ_SET_INVALID", String(seenJuz.size));
  for (let juz = 1; juz <= 30; juz += 1) invariant(seenJuz.has(juz), "QURAN_JUZ_MISSING", String(juz));

  const expectedVerseTotal = [...seedAyahCounts.values()].reduce((sum, count) => sum + count, 0);
  invariant(seenVerseKeys.size === expectedVerseTotal, "QURAN_VERSE_TOTAL_MISMATCH",
    `${seenVerseKeys.size}!=${expectedVerseTotal}`);

  return {
    schema_version: SCHEMA_VERSION,
    dataset: DATASET_NAME,
    version: String(version),
    source: {
      provider: "ALQURAN_CLOUD",
      api: "https://api.alquran.cloud/v1",
      uthmani_edition: EXPECTED_EDITIONS.uthmani,
      tajweed_edition: EXPECTED_EDITIONS.tajweed,
    },
    surahs,
  };
}

export function validateCanonicalDataset(dataset, manifest, seedAyahCounts) {
  asObject(dataset, "QURAN_DATASET_INVALID");
  asObject(manifest, "QURAN_MANIFEST_INVALID");
  invariant(dataset.dataset === DATASET_NAME && manifest.dataset === DATASET_NAME, "QURAN_DATASET_NAME_MISMATCH");
  invariant(dataset.schema_version === SCHEMA_VERSION && manifest.schema_version === SCHEMA_VERSION,
    "QURAN_SCHEMA_VERSION_MISMATCH");
  invariant(String(dataset.version) === String(manifest.version), "QURAN_VERSION_MISMATCH");
  invariant(manifest.status === "APPROVED", "QURAN_DATASET_NOT_APPROVED", String(manifest.status));
  invariant(manifest.approval_policy === "VERBATIM_SNAPSHOT_NO_TEXT_MUTATION", "QURAN_APPROVAL_POLICY_INVALID");
  invariant(manifest.source?.uthmani_edition === EXPECTED_EDITIONS.uthmani, "QURAN_MANIFEST_UTHMANI_EDITION_INVALID");
  invariant(manifest.source?.tajweed_edition === EXPECTED_EDITIONS.tajweed, "QURAN_MANIFEST_TAJWEED_EDITION_INVALID");
  invariant(/^[a-f0-9]{64}$/.test(manifest.source_revision?.uthmani_response_sha256 ?? ""),
    "QURAN_SOURCE_REVISION_UTHMANI_INVALID");
  invariant(/^[a-f0-9]{64}$/.test(manifest.source_revision?.tajweed_response_sha256 ?? ""),
    "QURAN_SOURCE_REVISION_TAJWEED_INVALID");

  const surahs = asArray(dataset.surahs, "QURAN_DATASET_SURAHS_INVALID");
  invariant(surahs.length === 114, "QURAN_SURAH_COUNT_INVALID", String(surahs.length));
  const verseKeys = new Set();
  const globals = new Set();
  const pages = new Set();
  let previousGlobal = 0;
  let previousPage = 0;
  for (let i = 0; i < surahs.length; i += 1) {
    const surah = asObject(surahs[i], "QURAN_DATASET_SURAH_INVALID");
    invariant(surah.number === i + 1, "QURAN_SURAH_ORDER_INVALID", String(surah.number));
    const expectedCount = seedAyahCounts.get(surah.number);
    invariant(surah.ayah_count === expectedCount, "QURAN_AYAH_COUNT_METADATA_MISMATCH", String(surah.number));
    const verses = asArray(surah.verses, "QURAN_DATASET_VERSES_INVALID");
    invariant(verses.length === expectedCount, "QURAN_AYAH_COUNT_MISMATCH", String(surah.number));
    for (let j = 0; j < verses.length; j += 1) {
      const verse = asObject(verses[j], "QURAN_DATASET_VERSE_INVALID");
      invariant(verse.ayah_number === j + 1, "QURAN_AYAH_ORDER_INVALID", `${surah.number}:${verse.ayah_number}`);
      invariant(verse.verse_key === `${surah.number}:${j + 1}`, "QURAN_VERSE_KEY_INVALID", String(verse.verse_key));
      invariant(!verseKeys.has(verse.verse_key), "QURAN_DUPLICATE_VERSE_KEY", verse.verse_key);
      verseKeys.add(verse.verse_key);
      invariant(verse.global_number === previousGlobal + 1, "QURAN_GLOBAL_ORDER_INVALID", String(verse.global_number));
      previousGlobal = verse.global_number;
      invariant(!globals.has(verse.global_number), "QURAN_DUPLICATE_GLOBAL_NUMBER", String(verse.global_number));
      globals.add(verse.global_number);
      invariant(typeof verse.text_uthmani === "string" && verse.text_uthmani.length > 0, "QURAN_UTHMANI_TEXT_EMPTY", verse.verse_key);
      invariant(typeof verse.text_tajweed === "string" && verse.text_tajweed.length > 0, "QURAN_TAJWEED_TEXT_EMPTY", verse.verse_key);
      invariant(Number.isInteger(verse.page_number) && verse.page_number >= 1 && verse.page_number <= 604,
        "QURAN_PAGE_INVALID", verse.verse_key);
      invariant(verse.page_number >= previousPage, "QURAN_PAGE_ORDER_INVALID", verse.verse_key);
      previousPage = verse.page_number;
      pages.add(verse.page_number);
      invariant(Number.isInteger(verse.juz_number) && verse.juz_number >= 1 && verse.juz_number <= 30,
        "QURAN_JUZ_INVALID", verse.verse_key);
    }
  }
  invariant(pages.size === 604, "QURAN_PAGE_SET_INVALID", String(pages.size));
  const expectedVerseTotal = [...seedAyahCounts.values()].reduce((sum, count) => sum + count, 0);
  invariant(verseKeys.size === expectedVerseTotal, "QURAN_VERSE_TOTAL_MISMATCH", `${verseKeys.size}!=${expectedVerseTotal}`);
  invariant(manifest.surahs === 114, "QURAN_MANIFEST_SURAH_COUNT_INVALID");
  invariant(manifest.verses === expectedVerseTotal, "QURAN_MANIFEST_VERSE_COUNT_INVALID");
  invariant(manifest.pages === 604, "QURAN_MANIFEST_PAGE_COUNT_INVALID");

  const contentSha = sha256(canonicalJson(dataset));
  invariant(manifest.sha256 === contentSha, "QURAN_CHECKSUM_MISMATCH", `${manifest.sha256}!=${contentSha}`);
  return { verseCount: expectedVerseTotal, sha256: contentSha };
}
