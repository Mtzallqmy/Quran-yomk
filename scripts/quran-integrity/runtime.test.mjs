import assert from "node:assert/strict";
import test from "node:test";

import {
  fetchVerifiedCanonicalJson,
  selectCanonicalPassage,
  sha256Hex,
} from "../../supabase/functions/tarteel-api/quran_integrity_runtime.js";

const encoder = new TextEncoder();

async function expectedFor(text) {
  const bytes = encoder.encode(text);
  return { bytes: bytes.byteLength, sha256: await sha256Hex(bytes) };
}

test("verified runtime fetch accepts only the approved byte revision", async () => {
  const body = JSON.stringify({ data: { surahs: [] } });
  const expected = await expectedFor(body);
  let seenOptions = null;
  const payload = await fetchVerifiedCanonicalJson(
    "https://example.test/quran/quran-uthmani",
    expected,
    {
      fetchImpl: async (_url, options) => {
        seenOptions = options;
        return new Response(body, {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      },
    },
  );
  assert.deepEqual(payload, { data: { surahs: [] } });
  assert.equal(seenOptions.redirect, "error");
  assert.equal(seenOptions.headers.accept, "application/json");
});

test("verified runtime fetch fails closed when upstream bytes change", async () => {
  const approved = JSON.stringify({ data: { revision: 1 } });
  const changed = JSON.stringify({ data: { revision: 2 } });
  const expected = await expectedFor(approved);
  await assert.rejects(
    fetchVerifiedCanonicalJson(
      "https://example.test/quran/quran-uthmani",
      expected,
      {
        fetchImpl: async () =>
          new Response(changed, {
            status: 200,
            headers: { "content-type": "application/json" },
          }),
      },
    ),
    (error) => error?.code === "QURAN_CANONICAL_SOURCE_REVISION_MISMATCH" && error?.status === 503,
  );
});

test("verified runtime fetch rejects non-HTTPS canonical sources", async () => {
  const body = JSON.stringify({ data: {} });
  await assert.rejects(
    fetchVerifiedCanonicalJson("http://example.test/quran", await expectedFor(body)),
    (error) => error?.code === "QURAN_CANONICAL_SOURCE_NOT_HTTPS",
  );
});

function syntheticQuran() {
  return {
    data: {
      surahs: Array.from({ length: 114 }, (_, index) => {
        const number = index + 1;
        return {
          number,
          name: `سورة ${number}`,
          englishName: `Surah ${number}`,
          ayahs: [
            {
              number,
              numberInSurah: 1,
              text: `verse-${number}`,
              juz: number === 1 ? 1 : 30,
              page: number === 1 ? 1 : 604,
              ruku: 1,
              hizbQuarter: 1,
              sajda: false,
            },
          ],
        };
      }),
    },
  };
}

test("canonical passage selection preserves exact surah identity", () => {
  const selected = selectCanonicalPassage(syntheticQuran(), "surah", 1);
  assert.equal(selected.data.number, 1);
  assert.equal(selected.data.ayahs[0].numberInSurah, 1);
  assert.equal(selected.data.ayahs[0].text, "verse-1");
});

test("canonical page/juz selection embeds surah identity without text mutation", () => {
  const selected = selectCanonicalPassage(syntheticQuran(), "page", 1);
  assert.equal(selected.data.ayahs.length, 1);
  assert.equal(selected.data.ayahs[0].text, "verse-1");
  assert.deepEqual(selected.data.ayahs[0].surah, {
    number: 1,
    name: "سورة 1",
    englishName: "Surah 1",
  });
});
