export const CANONICAL_QURAN_V1 = Object.freeze({
  dataset: "tarteel-quran-canonical",
  version: "1",
  schemaVersion: 1,
  status: "APPROVED",
  datasetSha256: "cc9db6390358e1a98091f868b0e09c9b8ede3bee559e38fd67c4a839646f2946",
  source: Object.freeze({
    provider: "ALQURAN_CLOUD",
    api: "https://api.alquran.cloud/v1",
    uthmaniEdition: "quran-uthmani",
    tajweedEdition: "quran-tajweed",
    uthmaniResponseSha256: "0df03e1d6da4fc8138208fec1688f2b416f0dd4ebbd514179f3e5e0fbaf4195f",
    tajweedResponseSha256: "a80dca6b11351b1d79bea1523c3ff8af3289c6df5e3e48a2e1e11074c80ccb31",
    uthmaniResponseBytes: 2109200,
    tajweedResponseBytes: 2488551,
  }),
});

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
  const source = CANONICAL_QURAN_V1.source;
  const [uthmani, tajweed] = await Promise.all([
    fetchVerifiedCanonicalJson(`${source.api}/quran/${source.uthmaniEdition}`, {
      sha256: source.uthmaniResponseSha256,
      bytes: source.uthmaniResponseBytes,
    }),
    fetchVerifiedCanonicalJson(`${source.api}/quran/${source.tajweedEdition}`, {
      sha256: source.tajweedResponseSha256,
      bytes: source.tajweedResponseBytes,
    }),
  ]);
  return { uthmani, tajweed };
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
