import canonicalDataset from '../../../data/quran/canonical/v2/dataset.json' with { type: 'json' };

export const TARTEEL_CANONICAL_QURAN = Object.freeze({
 dataset:'tarteel-quran-canonical',version:'2',schemaVersion:1,status:'APPROVED',
 datasetSha256:'132090d1264257ce816dfe1245014c422e3cd4c491f2397c78447efbe161ee8f',
 source:Object.freeze({provider:'KFGQPC',url:'https://qurancomplex.gov.sa/quran-dev/',uthmaniEdition:'kfgqpc-hafs-v30',tajweedEdition:null})
});
// Export name retained for callers; it resolves only the new official edition.
export const CANONICAL_QURAN_V1 = TARTEEL_CANONICAL_QURAN;

const MAX_CANONICAL_RESPONSE_BYTES = 3_000_000;
let canonicalSnapshotPromise = null;

function asObject(value, code) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw integrityError(code);
  }
  return value;
}

function asArray(value, code) {
  if (!Array.isArray(value)) throw integrityError(code);
  return value;
}

function positiveInteger(value, code) {
  if (!Number.isInteger(value) || value < 1) throw integrityError(code);
  return value;
}

function integrityError(code) {
  const error = new Error(code);
  error.status = 503;
  error.code = code;
  error.integrityFailure = true;
  return error;
}

function availabilityError(code) {
  const error = new Error(code);
  error.status = 503;
  error.code = code;
  error.integrityFailure = false;
  return error;
}

export async function sha256Hex(bytes) {
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(hash), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function fetchVerifiedCanonicalJson(url, expected, options = {}) {
  if (!url.startsWith("https://")) throw integrityError("QURAN_CANONICAL_SOURCE_NOT_HTTPS");
  const fetchImpl = options.fetchImpl ?? fetch;
  const timeoutMs = options.timeoutMs ?? 15_000;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    let response;
    try {
      response = await fetchImpl(url, {
        headers: {
          accept: "application/json",
          "user-agent": "Tarteel-Quran-Runtime/1",
        },
        redirect: "error",
        signal: controller.signal,
      });
    } catch (error) {
      if (error?.integrityFailure) throw error;
      throw availabilityError("QURAN_CANONICAL_SOURCE_UNAVAILABLE");
    }
    if (!response.ok) throw availabilityError("QURAN_CANONICAL_SOURCE_UNAVAILABLE");
    const contentType = response.headers.get("content-type") ?? "";
    if (!contentType.includes("json")) throw integrityError("QURAN_CANONICAL_CONTENT_TYPE_INVALID");
    const advertised = Number(response.headers.get("content-length") ?? "0");
    if (advertised && advertised > MAX_CANONICAL_RESPONSE_BYTES) {
      throw integrityError("QURAN_CANONICAL_RESPONSE_TOO_LARGE");
    }

    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.byteLength > MAX_CANONICAL_RESPONSE_BYTES) {
      throw integrityError("QURAN_CANONICAL_RESPONSE_TOO_LARGE");
    }
    if (bytes.byteLength !== expected.bytes) {
      throw integrityError("QURAN_CANONICAL_SOURCE_REVISION_MISMATCH");
    }
    if (await sha256Hex(bytes) !== expected.sha256) {
      throw integrityError("QURAN_CANONICAL_SOURCE_REVISION_MISMATCH");
    }

    let payload;
    try {
      payload = JSON.parse(new TextDecoder().decode(bytes));
    } catch {
      throw integrityError("QURAN_CANONICAL_JSON_INVALID");
    }
    asObject(payload, "QURAN_CANONICAL_PAYLOAD_INVALID");
    return payload;
  } finally {
    clearTimeout(timer);
  }
}

export function selectCanonicalPassage(payload, mode, number) {
  if (!["surah", "juz", "page"].includes(mode)) {
    throw integrityError("QURAN_CANONICAL_MODE_INVALID");
  }
  positiveInteger(number, "QURAN_CANONICAL_NUMBER_INVALID");
  const data = asObject(payload.data, "QURAN_CANONICAL_DATA_INVALID");
  const surahs = asArray(data.surahs, "QURAN_CANONICAL_SURAHS_INVALID");
  if (surahs.length !== 114) throw integrityError("QURAN_CANONICAL_SURAH_COUNT_INVALID");

  if (mode === "surah") {
    const surah = surahs.find((value) => asObject(value, "QURAN_CANONICAL_SURAH_INVALID").number === number);
    if (!surah) throw integrityError("QURAN_CANONICAL_SURAH_MISSING");
    return { data: surah };
  }

  const ayahs = [];
  for (const rawSurah of surahs) {
    const surah = asObject(rawSurah, "QURAN_CANONICAL_SURAH_INVALID");
    const surahIdentity = {
      number: positiveInteger(surah.number, "QURAN_CANONICAL_SURAH_NUMBER_INVALID"),
      name: typeof surah.name === "string" ? surah.name : "",
      englishName: typeof surah.englishName === "string" ? surah.englishName : "",
    };
    for (const rawAyah of asArray(surah.ayahs, "QURAN_CANONICAL_AYAHS_INVALID")) {
      const ayah = asObject(rawAyah, "QURAN_CANONICAL_AYAH_INVALID");
      if (ayah[mode] === number) ayahs.push({ ...ayah, surah: surahIdentity });
    }
  }
  if (ayahs.length === 0) throw integrityError("QURAN_CANONICAL_PASSAGE_EMPTY");
  return { data: { ayahs } };
}

async function loadCanonicalQuranSnapshots() {
 const bytes=new TextEncoder().encode(JSON.stringify(canonicalDataset,null,2)+'\n');
 if(await sha256Hex(bytes)!==TARTEEL_CANONICAL_QURAN.datasetSha256)throw integrityError('QURAN_CANONICAL_SOURCE_REVISION_MISMATCH');
 if(canonicalDataset.version!=='2'||canonicalDataset.source.provider!=='KFGQPC'||canonicalDataset.surahs.length!==114)throw integrityError('QURAN_CANONICAL_EDITION_MISMATCH');
 let count=0;const identities=new Set();
 const surahs=canonicalDataset.surahs.map(s=>({number:s.number,name:s.name_ar,englishName:s.name_en,ayahs:s.verses.map(v=>{
   count++;if(v.verse_key!==`${s.number}:${v.ayah_number}`||identities.has(v.verse_key)||v.global_number!==count)throw integrityError('QURAN_CANONICAL_IDENTITY_MISMATCH');identities.add(v.verse_key);
   return {number:v.global_number,numberInSurah:v.ayah_number,text:v.text_uthmani,juz:v.juz_number,page:v.page_number,ruku:v.ruku_number,hizbQuarter:v.hizb_quarter,sajda:v.sajda};
 })}));
 if(count!==6236)throw integrityError('QURAN_CANONICAL_AYAH_COUNT');
 return {uthmani:{data:{surahs}},tajweed:null};
}

export async function canonicalQuranSnapshots() {
  if (!canonicalSnapshotPromise) {
    canonicalSnapshotPromise = loadCanonicalQuranSnapshots().catch((error) => {
      // Availability failures may recover on the next request. Integrity failures stay
      // latched for the lifetime of this isolate so a changed upstream cannot be retried
      // into service as though it were an approved Quran revision.
      if (!error?.integrityFailure) canonicalSnapshotPromise = null;
      throw error;
    });
  }
  return canonicalSnapshotPromise;
}
