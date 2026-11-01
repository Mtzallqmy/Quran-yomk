import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";

export const DATASET_NAME = "tarteel-quran-canonical";
export const SCHEMA_VERSION = 1;
export const EXPECTED_EDITIONS = Object.freeze({
  uthmani: "kfgqpc-hafs-v30",
  tajweed: "NONE_MATCHING_VERIFIED_TEXT",
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
  invariant(manifest.source?.provider === 'KFGQPC' && dataset.source?.provider === 'KFGQPC', 'QURAN_PUBLISHER_MISMATCH');
  invariant(manifest.source_revision?.archive_sha256 === '227e6b1564d980f2bd09c2c35ebfb0330ac268c79a7c247cd1ab665bc635f245', 'QURAN_OFFICIAL_ARCHIVE_MISMATCH');

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
      invariant(verse.text_tajweed === null, "QURAN_UNVERIFIED_TAJWEED_LAYER", verse.verse_key);
      invariant(verse.canonical_id === `hafs:${verse.verse_key}`, "QURAN_CANONICAL_ID_INVALID", verse.verse_key);
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
  invariant(manifest.source_revision.uthmani_response_sha256 === 'd7adf8aeeef5a7b6798060706a55735dffbcdb542b290a3907bd9f70c498f4d3', 'QURAN_OFFICIAL_JSON_REVISION_MISMATCH');
  invariant(contentSha === '132090d1264257ce816dfe1245014c422e3cd4c491f2397c78447efbe161ee8f', 'QURAN_APPROVED_TEXT_DIGEST_MISMATCH');
  return { verseCount: expectedVerseTotal, sha256: contentSha };
}
