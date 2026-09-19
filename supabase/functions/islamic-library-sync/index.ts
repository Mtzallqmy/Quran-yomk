import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "apikey,content-type,x-request-id",
  "access-control-allow-methods": "POST,OPTIONS",
  "content-type": "application/json; charset=utf-8",
};
const JSON_HEADERS = { ...CORS, "cache-control": "no-store" };
const SUPABASE_URL = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, "");
const NS = "22d4aa19-571c-5c38-9fd2-49f0315ec38b";
const BUCKET = "islamic-content-audio";

function firstSecretKey(raw: string | undefined) {
  if (!raw) return "";
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    for (const value of Object.values(parsed)) {
      if (typeof value === "string" && value) return value;
      if (value && typeof value === "object") {
        const row = value as Record<string, unknown>;
        const candidate = row.secret ?? row.key ?? row.value;
        if (typeof candidate === "string" && candidate) return candidate;
      }
    }
  } catch {
    return "";
  }
  return "";
}

const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  firstSecretKey(Deno.env.get("SUPABASE_SECRET_KEYS"));
const publishableMap = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "{}");
const ALLOWED_KEYS = new Set(Object.values(publishableMap).map(String));
const legacyAnon = Deno.env.get("SUPABASE_ANON_KEY");
if (legacyAnon) ALLOWED_KEYS.add(legacyAnon);

type Json = Record<string, unknown>;
type ItemRow = {
  id: string;
  source_slug: string;
  source_key: string;
  title_ar: string;
  text_ar: string;
  reference: string | null;
  repeat_count: number;
  audio_asset_id: string | null;
  license_name: string;
  license_url: string;
  original_source_url: string;
  review_status: string;
  sha256: string;
  source_file_sha256: string | null;
  source_revision: string | null;
  metadata: Json;
};
type ImportItem = { item: ItemRow; categories: string[] };

const SOURCE_CONFIG: Record<
  string,
  { repo: string; license: string; licenseUrl: string }
> = {
  seen_adhkar: {
    repo: "Seen-Arabic/Morning-And-Evening-Adhkar-DB",
    license: "MIT (repository dataset)",
    licenseUrl:
      "https://github.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB/blob/main/LICENSE",
  },
  fitrahive_dua_dhikr: {
    repo: "fitrahive/dua-dhikr",
    license: "MIT (repository dataset)",
    licenseUrl: "https://github.com/fitrahive/dua-dhikr/blob/main/LICENSE",
  },
  hisn_el_muslim: {
    repo: "asellam/HisnElMuslim",
    license: "MIT (repository dataset)",
    licenseUrl: "https://github.com/asellam/HisnElMuslim/blob/main/LICENSE.md",
  },
};

const TANZIL_URL =
  "https://tanzil.net/pub/download/index.php?quranType=uthmani&outType=txt-2&agree=true&marks=true&sajdah=true&rub=true&stanween=true";
const TANZIL_LICENSE =
  "Creative Commons Attribution 3.0 + Tanzil verbatim-only terms";
const TANZIL_LICENSE_URL = "https://tanzil.net/docs/Text_License";

const AUDIO = [
  {
    file: "Beautiful adhan.ogg",
    slug: "beautiful-adhan-cc0",
    kind: "adhan",
    title: "أذان — Beautiful Adhan",
    author: "Adam-synagda",
  },
  {
    file: "Adhan.ogg",
    slug: "adhan-aishatu98-cc0",
    kind: "adhan",
    title: "أذان — تسجيل Aishatu98",
    author: "Aishatu98",
  },
  {
    file: "Muslim calling to prayer.ogg",
    slug: "muslim-call-prayer-aishatu98-cc0",
    kind: "adhan",
    title: "أذان — Muslim calling to prayer",
    author: "Aishatu98",
  },
  {
    file: "Iqamah.ogg",
    slug: "iqamah-aishatu98-cc0",
    kind: "iqamah",
    title: "إقامة — تسجيل Aishatu98",
    author: "Aishatu98",
  },
] as const;

const FITRAHIVE = [
  ["morning-dhikr", "adhkar_morning", "أذكار الصباح"],
  ["evening-dhikr", "adhkar_evening", "أذكار المساء"],
  ["dhikr-after-salah", "adhkar_prayer", "أذكار ما بعد الصلاة"],
  ["daily-dua", "dua", "دعاء يومي"],
  ["selected-dua", "dua", "دعاء مختار"],
] as const;

function reply(data: unknown, status = 200, requestId?: string) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...JSON_HEADERS,
      ...(requestId ? { "x-request-id": requestId } : {}),
    },
  });
}
function fail(status: number, code: string, requestId: string) {
  return reply({ error: { code, request_id: requestId } }, status, requestId);
}
function asMap(value: unknown): Json {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Json)
    : {};
}
function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}
function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}
function int(value: unknown, fallback = 1): number {
  const parsed = Number(value);
  return Number.isFinite(parsed)
    ? Math.max(1, Math.min(10000, Math.trunc(parsed)))
    : fallback;
}
function chunk<T>(values: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < values.length; i += size) {
    out.push(values.slice(i, i + size));
  }
  return out;
}
function hex(bytes: Uint8Array) {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}
async function sha256Bytes(bytes: Uint8Array) {
  return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)));
}
async function sha256Text(value: string) {
  return sha256Bytes(new TextEncoder().encode(value));
}
function uuidBytes(value: string) {
  return Uint8Array.from(
    value
      .replaceAll("-", "")
      .match(/../g)!
      .map((v) => parseInt(v, 16)),
  );
}
async function uuidV5(name: string) {
  const nameBytes = new TextEncoder().encode(name);
  const input = new Uint8Array(16 + nameBytes.length);
  input.set(uuidBytes(NS));
  input.set(nameBytes, 16);
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-1", input));
  hash[6] = (hash[6] & 0x0f) | 0x50;
  hash[8] = (hash[8] & 0x3f) | 0x80;
  const h = hex(hash.slice(0, 16));
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(
    16,
    20,
  )}-${h.slice(20, 32)}`;
}
function stripHtml(value: unknown) {
  return text(value)
    .replace(/<[^>]+>/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&#039;|&apos;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/\s+/g, " ")
    .trim();
}

async function rest(path: string, init: RequestInit = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: SERVICE_KEY,
      authorization: `Bearer ${SERVICE_KEY}`,
      accept: "application/json",
      "content-type": "application/json",
      ...(init.headers ?? {}),
    },
  });
  const raw = await response.text();
  if (!response.ok) {
    throw new Error(`REST_${response.status}:${raw.slice(0, 400)}`);
  }
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return raw;
  }
}

async function fetchBytes(url: string, maxBytes: number) {
  if (!url.startsWith("https://")) throw new Error("SOURCE_NOT_HTTPS");
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 25000);
  try {
    const response = await fetch(url, {
      headers: {
        accept: "*/*",
        "user-agent": "Tarteel-Islamic-Library-Sync/2",
      },
      redirect: "follow",
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`SOURCE_${response.status}`);
    const declared = Number(response.headers.get("content-length") ?? "0");
    if (declared && declared > maxBytes) throw new Error("SOURCE_TOO_LARGE");
    const bytes = new Uint8Array(await response.arrayBuffer());
    if (!bytes.length || bytes.length > maxBytes) {
      throw new Error("SOURCE_SIZE_INVALID");
    }
    return {
      bytes,
      contentType: response.headers.get("content-type") ?? "",
    };
  } finally {
    clearTimeout(timer);
  }
}
async function fetchJson(url: string, maxBytes = 5000000) {
  const { bytes } = await fetchBytes(url, maxBytes);
  return {
    payload: JSON.parse(new TextDecoder().decode(bytes)),
    fileSha: await sha256Bytes(bytes),
  };
}
async function sourceRevision(repo: string) {
  const { payload } = await fetchJson(
    `https://api.github.com/repos/${repo}/commits/main`,
    1000000,
  );
  const sha = text(asMap(payload).sha);
  if (!/^[0-9a-f]{40}$/.test(sha)) {
    throw new Error("SOURCE_REVISION_INVALID");
  }
  return sha;
}
function rawGitHub(repo: string, revision: string, path: string) {
  return `https://raw.githubusercontent.com/${repo}/${revision}/${path}`;
}
async function canonicalSha(
  source: string,
  key: string,
  categories: string[],
  title: string,
  body: string,
  reference: string,
  repeat: number,
) {
  return sha256Text(
    [
      "tarteel-islamic-content-v1",
      source,
      key,
      [...categories].sort().join(","),
      title,
      body,
      reference,
      String(repeat),
    ].join("\0"),
  );
}
async function makeItem(args: {
  source: string;
  key: string;
  title: string;
  body: string;
  categories: string[];
  reference?: string;
  repeat?: number;
  original: string;
  license: string;
  licenseUrl: string;
  fileSha?: string | null;
  revision?: string | null;
  metadata?: Json;
  audioId?: string | null;
}): Promise<ImportItem> {
  const repeat = int(args.repeat ?? 1);
  return {
    item: {
      id: await uuidV5(`content:${args.source}:${args.key}`),
      source_slug: args.source,
      source_key: args.key,
      title_ar: args.title,
      text_ar: args.body,
      reference: text(args.reference) || null,
      repeat_count: repeat,
      audio_asset_id: args.audioId ?? null,
      license_name: args.license,
      license_url: args.licenseUrl,
      original_source_url: args.original,
      review_status: "approved",
      sha256: await canonicalSha(
        args.source,
        args.key,
        args.categories,
        args.title,
        args.body,
        text(args.reference),
        repeat,
      ),
      source_file_sha256: args.fileSha ?? null,
      source_revision: args.revision ?? null,
      metadata: args.metadata ?? {},
    },
    categories: args.categories,
  };
}
async function upsertItems(rows: ImportItem[]) {
  for (const batch of chunk(rows, 100)) {
    await rest("islamic_content_items?on_conflict=source_slug,source_key", {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify(batch.map((x) => x.item)),
    });
    const links = batch.flatMap((x) =>
      x.categories.map((category_slug) => ({
        item_id: x.item.id,
        category_slug,
      }))
    );
    if (links.length) {
      await rest(
        "islamic_content_item_categories?on_conflict=item_id,category_slug",
        {
          method: "POST",
          headers: { Prefer: "resolution=ignore-duplicates,return=minimal" },
          body: JSON.stringify(links),
        },
      );
    }
  }
  return rows.length;
}
async function audit(
  source: string,
  status: "started" | "completed" | "failed",
  count = 0,
  details: Json = {},
  fileSha: string | null = null,
  errorCode: string | null = null,
) {
  await rest("islamic_content_import_runs", {
    method: "POST",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify({
      source_slug: source,
      status,
      inserted_count: count,
      updated_count: 0,
      source_file_sha256: fileSha,
      error_code: errorCode,
      details,
      completed_at: status === "started" ? null : new Date().toISOString(),
    }),
  });
}
async function cooldown(source: string) {
  const rows = asArray(
    await rest(
      `islamic_content_import_runs?select=started_at,status&source_slug=eq.${encodeURIComponent(
        source,
      )}&order=started_at.desc&limit=1`,
    ),
  );
  const at = Date.parse(text(asMap(rows[0]).started_at));
  return Number.isFinite(at) && Date.now() - at < 120000;
}

async function importSeen() {
  const source = "seen_adhkar";
  const cfg = SOURCE_CONFIG[source];
  const revision = await sourceRevision(cfg.repo);
  const url = rawGitHub(cfg.repo, revision, "ar.json");
  await audit(source, "started", 0, { revision });
  const { payload, fileSha } = await fetchJson(url);
  const rows: ImportItem[] = [];
  let fallback = 0;
  for (const raw of asArray(payload)) {
    fallback++;
    const v = asMap(raw);
    const order = int(v.order, fallback);
    const body = text(v.content);
    if (!body) continue;
    const type = Number(v.type ?? 0);
    const categories =
      type === 1
        ? ["adhkar_morning"]
        : type === 2
          ? ["adhkar_evening"]
          : ["adhkar_morning", "adhkar_evening"];
    const label =
      type === 1
        ? "ذكر الصباح"
        : type === 2
          ? "ذكر المساء"
          : "ذكر الصباح والمساء";
    rows.push(
      await makeItem({
        source,
        key: String(order),
        title: `${label} ${order}`,
        body,
        categories,
        reference: text(v.source),
        repeat: int(v.count, 1),
        original: url,
        license: cfg.license,
        licenseUrl: cfg.licenseUrl,
        fileSha,
        revision,
        metadata: {
          fadl: text(v.fadl),
          hadith_text: text(v.hadith_text),
          upstream_audio_present: Boolean(text(v.audio)),
          audio_policy:
            "external_audio_not_mirrored_without_independent_rights_review",
        },
      }),
    );
  }
  const count = await upsertItems(rows);
  await audit(
    source,
    "completed",
    count,
    { revision, external_audio_imported: false },
    fileSha,
  );
  return { source, count, revision, fileSha };
}

async function importFitrahive() {
  const source = "fitrahive_dua_dhikr";
  const cfg = SOURCE_CONFIG[source];
  const revision = await sourceRevision(cfg.repo);
  await audit(source, "started", 0, { revision });
  const rows: ImportItem[] = [];
  const files: Json[] = [];
  for (const [folder, category, label] of FITRAHIVE) {
    const url = rawGitHub(
      cfg.repo,
      revision,
      `data/dua-dhikr/${folder}/en.json`,
    );
    const { payload, fileSha } = await fetchJson(url);
    files.push({ folder, sha256: fileSha });
    let i = 0;
    for (const raw of asArray(payload)) {
      i++;
      const v = asMap(raw);
      const body = text(v.arabic);
      if (!body) continue;
      const notes = text(v.notes);
      const match = notes.match(/\b(\d{1,4})\b/);
      rows.push(
        await makeItem({
          source,
          key: `${folder}:${i}`,
          title: `${label} ${i}`,
          body,
          categories: [category],
          reference: text(v.source),
          repeat: match ? int(match[1], 1) : 1,
          original: url,
          license: cfg.license,
          licenseUrl: cfg.licenseUrl,
          fileSha,
          revision,
          metadata: {
            upstream_title: text(v.title),
            notes,
            fawaid: text(v.fawaid),
            translation: text(v.translation),
            transliteration: text(v.latin),
          },
        }),
      );
    }
  }
  const count = await upsertItems(rows);
  await audit(source, "completed", count, { revision, files });
  return { source, count, revision, files };
}

function hisnCategories(title: string) {
  const out: string[] = [];
  if (/الصباح|يصبح|صباح/.test(title)) out.push("adhkar_morning");
  if (/المساء|يمسي|مساء/.test(title)) out.push("adhkar_evening");
  if (/النوم|الفراش|الاستيقاظ/.test(title)) out.push("adhkar_sleep");
  if (/الصلاة|الأذان|الإقامة|الوضوء|المسجد/.test(title)) {
    out.push("adhkar_prayer");
  }
  if (!out.length) out.push("dua");
  return [...new Set(out)];
}

async function importHisn() {
  const source = "hisn_el_muslim";
  const cfg = SOURCE_CONFIG[source];
  const revision = await sourceRevision(cfg.repo);
  const url = rawGitHub(cfg.repo, revision, "hisn.json");
  await audit(source, "started", 0, { revision });
  const { payload, fileSha } = await fetchJson(url);
  const rows: ImportItem[] = [];
  let group = 0;
  for (const [title, rawGroup] of Object.entries(asMap(payload))) {
    group++;
    const g = asMap(rawGroup);
    let i = 0;
    for (const raw of asArray(g.Adhkar)) {
      i++;
      const v = asMap(raw);
      const body = text(v.Text);
      if (!body) continue;
      rows.push(
        await makeItem({
          source,
          key: `${group}:${i}`,
          title,
          body,
          categories: hisnCategories(title),
          reference: text(v.Reference),
          repeat: int(v.Count, 1),
          original: url,
          license: cfg.license,
          licenseUrl: cfg.licenseUrl,
          fileSha,
          revision,
          metadata: {
            group_title: title,
            upstream_audio_present: Boolean(text(g.Audio)),
            audio_policy:
              "external_audio_not_mirrored_without_independent_rights_review",
          },
        }),
      );
    }
  }
  const count = await upsertItems(rows);
  await audit(
    source,
    "completed",
    count,
    { revision, external_audio_imported: false },
    fileSha,
  );
  return { source, count, revision, fileSha };
}

async function importTanzil() {
  const source = "tanzil_uthmani_1_1";
  await audit(source, "started", 0, { url: TANZIL_URL, verbatim: true });
  const { bytes, contentType } = await fetchBytes(TANZIL_URL, 3000000);
  const fileSha = await sha256Bytes(bytes);
  const raw = new TextDecoder().decode(bytes);
  const rows: ImportItem[] = [];
  for (const lineRaw of raw.split(/\r?\n/)) {
    const line = lineRaw.replace(/^\ufeff/, "");
    if (!line || line.startsWith("#")) continue;
    const match = /^(\d+)\|(\d+)\|(.*)$/.exec(line);
    if (!match) continue;
    const surah = Number(match[1]);
    const ayah = Number(match[2]);
    const body = match[3];
    if (!(surah >= 1 && surah <= 114 && ayah >= 1 && body)) {
      throw new Error("TANZIL_ROW_INVALID");
    }
    rows.push(
      await makeItem({
        source,
        key: `${surah}:${ayah}`,
        title: `سورة ${surah} — الآية ${ayah}`,
        body,
        categories: ["quran"],
        reference: `${surah}:${ayah}`,
        repeat: 1,
        original: "https://tanzil.net/download/",
        license: TANZIL_LICENSE,
        licenseUrl: TANZIL_LICENSE_URL,
        fileSha,
        revision: "1.1",
        metadata: {
          surah,
          ayah,
          verbatim: true,
          download_url: TANZIL_URL,
          content_type: contentType,
        },
      }),
    );
  }
  if (rows.length !== 6236) {
    throw new Error(`TANZIL_VERSE_COUNT_${rows.length}`);
  }
  const count = await upsertItems(rows);
  await audit(
    source,
    "completed",
    count,
    { version: "1.1", verse_count: count, verbatim: true },
    fileSha,
  );
  return { source, count, fileSha, version: "1.1" };
}

function extmeta(ext: Json, key: string) {
  return stripHtml(asMap(ext[key]).value);
}
async function wikimediaInfo(file: string) {
  const params = new URLSearchParams({
    action: "query",
    format: "json",
    formatversion: "2",
    prop: "imageinfo",
    iiprop: "url|size|sha1|mime|extmetadata|user|timestamp",
    titles: `File:${file}`,
  });
  const { payload } = await fetchJson(
    `https://commons.wikimedia.org/w/api.php?${params}`,
    2000000,
  );
  const pages = asArray(asMap(asMap(payload).query).pages);
  const info = asMap(asArray(asMap(pages[0]).imageinfo)[0]);
  if (!text(info.url)) throw new Error("WIKIMEDIA_METADATA_MISSING");
  return info;
}

async function verifyStoredAudio(
  encodedPath: string,
  expectedDigest: string,
) {
  const existing = await fetch(
    `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${encodedPath}`,
    { method: "GET", cache: "no-store" },
  );
  if (!existing.ok) {
    throw new Error(`STORAGE_VERIFY_${existing.status}`);
  }
  const remote = new Uint8Array(await existing.arrayBuffer());
  if ((await sha256Bytes(remote)) !== expectedDigest) {
    throw new Error("STORAGE_IMMUTABLE_CONFLICT");
  }
}

async function uploadAudio(
  path: string,
  bytes: Uint8Array,
  digest: string,
) {
  const encodedPath = path.split("/").map(encodeURIComponent).join("/");
  const upload = await fetch(
    `${SUPABASE_URL}/storage/v1/object/${BUCKET}/${encodedPath}`,
    {
      method: "POST",
      headers: {
        apikey: SERVICE_KEY,
        authorization: `Bearer ${SERVICE_KEY}`,
        "content-type": "audio/ogg",
        "cache-control": "31536000",
        "x-upsert": "false",
      },
      body: bytes,
    },
  );
  if (upload.ok) return;

  const body = (await upload.text()).slice(0, 300);
  if (upload.status === 400 || upload.status === 409) {
    try {
      await verifyStoredAudio(encodedPath, digest);
      return;
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      throw new Error(`STORAGE_UPLOAD_${upload.status}:${body}:${detail}`);
    }
  }
  throw new Error(`STORAGE_UPLOAD_${upload.status}:${body}`);
}

async function importAudio() {
  const source = "wikimedia_commons_audio";
  await audit(source, "started", 0, {
    allowlist: AUDIO.map((value) => value.file),
    rights_policy: "per-file-cc0-only",
  });
  const imported: Json[] = [];
  for (const spec of AUDIO) {
    const info = await wikimediaInfo(spec.file);
    const ext = asMap(info.extmetadata);
    const license = extmeta(ext, "LicenseShortName");
    const usage = extmeta(ext, "UsageTerms");
    const author = extmeta(ext, "Artist") || text(info.user);
    const mime = text(info.mime).toLowerCase();
    const fileUrl = text(info.url);

    if (
      !license.toLowerCase().includes("cc0") &&
      !usage.toLowerCase().includes("cc0")
    ) {
      throw new Error(`AUDIO_LICENSE_NOT_CC0:${spec.file}`);
    }
    if (
      !["application/ogg", "audio/ogg"].includes(mime) ||
      !fileUrl.startsWith("https://")
    ) {
      throw new Error(`AUDIO_MEDIA_INVALID:${spec.file}`);
    }
    if (
      !author.toLowerCase().includes(spec.author.toLowerCase()) &&
      !text(info.user).toLowerCase().includes(spec.author.toLowerCase())
    ) {
      throw new Error(`AUDIO_AUTHOR_CHANGED:${spec.file}`);
    }

    const { bytes, contentType } = await fetchBytes(fileUrl, 10000000);
    const declared = Number(info.size ?? 0);
    if (declared && declared !== bytes.length) {
      throw new Error(`AUDIO_SIZE_MISMATCH:${spec.file}`);
    }
    const digest = await sha256Bytes(bytes);
    const path =
      `v1/${spec.kind}/${spec.slug}-${digest.slice(0, 16)}.ogg`;
    await uploadAudio(path, bytes, digest);

    const audioId = await uuidV5(`audio:${spec.slug}`);
    const page =
      `https://commons.wikimedia.org/wiki/File:${encodeURIComponent(
        spec.file.replaceAll(" ", "_"),
      )}`;
    const licenseUrl =
      extmeta(ext, "LicenseUrl") ||
      "https://creativecommons.org/publicdomain/zero/1.0/";

    await rest("islamic_audio_assets?on_conflict=slug", {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify({
        id: audioId,
        slug: spec.slug,
        kind: spec.kind,
        title_ar: spec.title,
        voice_name: author || spec.author,
        source_slug: source,
        original_source_url: page,
        storage_bucket: BUCKET,
        storage_path: path,
        mime_type: "audio/ogg",
        byte_size: bytes.length,
        duration_ms: null,
        sha256: digest,
        license_name: "CC0 1.0 Universal",
        license_url: licenseUrl,
        redistribution_allowed: true,
        review_status: "approved",
        metadata: {
          wikimedia_file: spec.file,
          wikimedia_sha1: text(info.sha1),
          wikimedia_timestamp: text(info.timestamp),
          wikimedia_uploader: text(info.user),
          author,
          rights_verified_per_file: true,
          license_short_name: license,
          usage_terms: usage,
          source_mime: mime,
          download_content_type: contentType,
          performer_identity_verified: false,
        },
      }),
    });

    await upsertItems([
      await makeItem({
        source,
        key: `audio:${spec.slug}`,
        title: spec.title,
        body: spec.kind === "iqamah" ? "الإقامة" : "الأذان",
        categories: [spec.kind === "iqamah" ? "iqamah" : "adhan"],
        original: page,
        license: "CC0 1.0 Universal",
        licenseUrl,
        fileSha: digest,
        revision: text(info.timestamp),
        metadata: {
          audio_only: true,
          rights_verified_per_file: true,
          performer_identity_verified: false,
        },
        audioId,
      }),
    ]);

    imported.push({
      slug: spec.slug,
      path,
      sha256: digest,
      bytes: bytes.length,
      license,
    });
  }
  await audit(source, "completed", imported.length, { imported });
  return { source, count: imported.length, assets: imported };
}

const SOURCES: Record<string, string> = {
  seen: "seen_adhkar",
  fitrahive: "fitrahive_dua_dhikr",
  hisn: "hisn_el_muslim",
  tanzil: "tanzil_uthmani_1_1",
  audio: "wikimedia_commons_audio",
};
const TASKS: Record<string, () => Promise<unknown>> = {
  seen: importSeen,
  fitrahive: importFitrahive,
  hisn: importHisn,
  tanzil: importTanzil,
  audio: importAudio,
};

Deno.serve(async (req: Request) => {
  const requestId = crypto.randomUUID();
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }
  if (req.method !== "POST") {
    return fail(405, "METHOD_NOT_ALLOWED", requestId);
  }
  const apiKey = req.headers.get("apikey") ?? "";
  if (!apiKey || !ALLOWED_KEYS.has(apiKey)) {
    return fail(401, "INVALID_API_KEY", requestId);
  }
  if (!SUPABASE_URL || !SERVICE_KEY) {
    return fail(503, "SERVER_NOT_CONFIGURED", requestId);
  }

  let scope = "";
  try {
    scope = text(asMap(await req.json()).scope);
  } catch {
    return fail(400, "INVALID_JSON", requestId);
  }
  if (!TASKS[scope]) return fail(422, "INVALID_SCOPE", requestId);

  const source = SOURCES[scope];
  if (await cooldown(source)) {
    return fail(429, "SYNC_COOLDOWN", requestId);
  }

  try {
    const data = await TASKS[scope]();
    return reply({ data }, 200, requestId);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    console.error(
      JSON.stringify({
        event: "ISLAMIC_LIBRARY_SYNC_FAILED",
        request_id: requestId,
        scope,
        message: detail,
      }),
    );
    try {
      await audit(
        source,
        "failed",
        0,
        { scope, detail: detail.slice(0, 500) },
        null,
        "IMPORT_FAILED",
      );
    } catch {
      // Preserve the original import failure.
    }
    return reply(
      {
        error: {
          code: "IMPORT_FAILED",
          scope,
          request_id: requestId,
          detail,
        },
      },
      500,
      requestId,
    );
  }
});
