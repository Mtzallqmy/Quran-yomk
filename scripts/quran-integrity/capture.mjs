import { mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import {
  DATASET_NAME,
  EXPECTED_EDITIONS,
  SCHEMA_VERSION,
  buildCanonicalDataset,
  canonicalJson,
  fetchJsonBounded,
  readSeedAyahCounts,
  sha256,
  validateCanonicalDataset,
} from "./lib.mjs";

function arg(name, fallback = null) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : fallback;
}

const version = arg("--version");
if (!version) throw new Error("QURAN_DATASET_VERSION_REQUIRED");
const outputPath = arg("--output", `data/quran/canonical/v${version}/dataset.json`);
const manifestPath = arg("--manifest", `data/quran/canonical/v${version}/manifest.json`);
const base = "https://api.alquran.cloud/v1/quran";

const [uthmani, tajweed, seedAyahCounts] = await Promise.all([
  fetchJsonBounded(`${base}/${EXPECTED_EDITIONS.uthmani}`),
  fetchJsonBounded(`${base}/${EXPECTED_EDITIONS.tajweed}`),
  readSeedAyahCounts(),
]);

const dataset = buildCanonicalDataset({
  version,
  uthmaniPayload: uthmani.payload,
  tajweedPayload: tajweed.payload,
  seedAyahCounts,
});
const datasetText = canonicalJson(dataset);
const generatedAt = new Date().toISOString();
const verseCount = [...seedAyahCounts.values()].reduce((sum, count) => sum + count, 0);
const manifest = {
  schema_version: SCHEMA_VERSION,
  dataset: DATASET_NAME,
  version: String(version),
  status: "APPROVED",
  approval_policy: "VERBATIM_SNAPSHOT_NO_TEXT_MUTATION",
  approval_basis: "Exact snapshot of the Quran editions already used by the production API, accepted only after deterministic identity/order/page/juz/checksum validation. This does not claim independent scholarly certification.",
  source: {
    provider: "ALQURAN_CLOUD",
    api: "https://api.alquran.cloud/v1",
    uthmani_edition: EXPECTED_EDITIONS.uthmani,
    tajweed_edition: EXPECTED_EDITIONS.tajweed,
    terms: "https://alquran.cloud/terms-and-conditions",
    upstream_attribution: ["AlQuran Cloud / Islamic Network", "Tanzil Project and other edition curators as identified by AlQuran Cloud"],
  },
  source_revision: {
    strategy: "RAW_API_RESPONSE_SHA256",
    uthmani_response_sha256: uthmani.rawSha256,
    tajweed_response_sha256: tajweed.rawSha256,
    uthmani_response_bytes: uthmani.bytes,
    tajweed_response_bytes: tajweed.bytes,
  },
  generated_at: generatedAt,
  verified_at: generatedAt,
  sha256: sha256(datasetText),
  surahs: 114,
  verses: verseCount,
  pages: 604,
  rights: {
    storage_policy: "VERBATIM_ONLY_WITH_ATTRIBUTION",
    no_text_mutation: true,
    no_ai_correction: true,
  },
};

validateCanonicalDataset(dataset, manifest, seedAyahCounts);
await mkdir(dirname(outputPath), { recursive: true });
await mkdir(dirname(manifestPath), { recursive: true });
await writeFile(outputPath, datasetText, "utf8");
await writeFile(manifestPath, canonicalJson(manifest), "utf8");
console.log(JSON.stringify({
  event: "quran_canonical_capture_complete",
  version: String(version),
  sha256: manifest.sha256,
  surahs: manifest.surahs,
  verses: manifest.verses,
  pages: manifest.pages,
}));
