import { readFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import {
  canonicalJson,
  invariant,
  readSeedAyahCounts,
  sha256,
  validateCanonicalDataset,
} from "./lib.mjs";

function arg(name, fallback = null) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : fallback;
}

const version = arg("--version", "1");
const datasetPath = arg("--dataset", `data/quran/canonical/v${version}/dataset.json`);
const manifestPath = arg("--manifest", `data/quran/canonical/v${version}/manifest.json`);
const baseRef = arg("--base-ref", process.env.QURAN_INTEGRITY_BASE_REF ?? "");

const [datasetText, manifestText, seedAyahCounts] = await Promise.all([
  readFile(datasetPath, "utf8"),
  readFile(manifestPath, "utf8"),
  readSeedAyahCounts(),
]);
let dataset;
let manifest;
try {
  dataset = JSON.parse(datasetText);
  manifest = JSON.parse(manifestText);
} catch {
  throw new Error("QURAN_CANONICAL_JSON_INVALID");
}

invariant(datasetText === canonicalJson(dataset), "QURAN_DATASET_NOT_CANONICAL_JSON");
invariant(manifestText === canonicalJson(manifest), "QURAN_MANIFEST_NOT_CANONICAL_JSON");
const result = validateCanonicalDataset(dataset, manifest, seedAyahCounts);
invariant(sha256(datasetText) === manifest.sha256, "QURAN_DATASET_FILE_HASH_MISMATCH");

if (baseRef) {
  const paths = [datasetPath, manifestPath];
  for (const path of paths) {
    let baseText = null;
    try {
      baseText = execFileSync("git", ["show", `${baseRef}:${path}`], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
    } catch {
      // A path absent from the base is a new canonical version and is allowed.
    }
    if (baseText !== null && baseText !== (path === datasetPath ? datasetText : manifestText)) {
      throw new Error(`QURAN_APPROVED_VERSION_IMMUTABLE: ${path} exists in ${baseRef}; create a new version directory instead of changing an approved version`);
    }
  }
}

console.log(JSON.stringify({
  event: "quran_canonical_validation_passed",
  version: String(manifest.version),
  sha256: result.sha256,
  verses: result.verseCount,
  status: manifest.status,
}));
