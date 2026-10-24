import assert from "node:assert/strict";
import test from "node:test";
import { readFile } from "node:fs/promises";
import {
  canonicalJson,
  readSeedAyahCounts,
  sha256,
  validateCanonicalDataset,
} from "./lib.mjs";

const dataset = JSON.parse(await readFile("data/quran/canonical/v1/dataset.json", "utf8"));
const manifest = JSON.parse(await readFile("data/quran/canonical/v1/manifest.json", "utf8"));
const seed = await readSeedAyahCounts();

function copy(value) {
  return structuredClone(value);
}

function refreshChecksum(mutatedDataset, mutatedManifest) {
  mutatedManifest.sha256 = sha256(canonicalJson(mutatedDataset));
}

function expectFailure(name, mutate, code) {
  test(name, () => {
    const d = copy(dataset);
    const m = copy(manifest);
    mutate(d, m);
    assert.throws(() => validateCanonicalDataset(d, m, seed), new RegExp(code));
  });
}

test("approved canonical v1 passes", () => {
  const result = validateCanonicalDataset(dataset, manifest, seed);
  assert.equal(result.sha256, manifest.sha256);
});

expectFailure("missing surah fails closed", (d, m) => {
  d.surahs.pop();
  refreshChecksum(d, m);
}, "QURAN_SURAH_COUNT_INVALID");

expectFailure("invalid surah number fails closed", (d, m) => {
  d.surahs[0].number = 0;
  refreshChecksum(d, m);
}, "QURAN_SURAH_ORDER_INVALID");

expectFailure("missing ayah fails closed", (d, m) => {
  d.surahs[0].verses.pop();
  refreshChecksum(d, m);
}, "QURAN_AYAH_COUNT_MISMATCH");

expectFailure("duplicate verse key fails closed", (d, m) => {
  d.surahs[0].verses[1].verse_key = d.surahs[0].verses[0].verse_key;
  refreshChecksum(d, m);
}, "QURAN_VERSE_KEY_INVALID|QURAN_DUPLICATE_VERSE_KEY");

expectFailure("invalid ayah ordering fails closed", (d, m) => {
  d.surahs[0].verses[1].ayah_number = 3;
  refreshChecksum(d, m);
}, "QURAN_AYAH_ORDER_INVALID");

expectFailure("verse identity mismatch fails closed", (d, m) => {
  d.surahs[0].verses[0].verse_key = "2:1";
  refreshChecksum(d, m);
}, "QURAN_VERSE_KEY_INVALID");

expectFailure("invalid page mapping fails closed", (d, m) => {
  d.surahs[0].verses[0].page_number = 605;
  refreshChecksum(d, m);
}, "QURAN_PAGE_INVALID");

expectFailure("unapproved checksum change fails closed", (d) => {
  d.surahs[0].verses[0].text_uthmani += " ";
}, "QURAN_CHECKSUM_MISMATCH");

expectFailure("source edition change without a new contract fails closed", (_d, m) => {
  m.source.uthmani_edition = "different-edition";
}, "QURAN_MANIFEST_UTHMANI_EDITION_INVALID");

expectFailure("approval status downgrade fails closed", (_d, m) => {
  m.status = "CAPTURED";
}, "QURAN_DATASET_NOT_APPROVED");
