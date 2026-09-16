#!/usr/bin/env python3
"""Import reviewed Islamic text/audio into the shared Tarteel Supabase library.

Security and rights policy:
- Server credentials are read from environment only.
- Source hosts and file paths are allowlisted in this program.
- Repository-level licenses never authorize third-party audio URLs embedded in data.
- The Seen-Arabic and HisnElMuslim `audio`/`Audio` fields are never downloaded.
- Wikimedia audio is mirrored only after per-file metadata reports CC0 and the file is OGG.
- Tanzil Quran text is stored verbatim and must contain exactly 6,236 verse rows.
- Every stored item/object receives SHA-256 provenance.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

PROJECT_URL = os.environ.get("SUPABASE_PROJECT_URL", "").rstrip("/")
SERVER_KEY = os.environ.get("SUPABASE_SERVER_KEY", "")
BUCKET = "islamic-content-audio"
NAMESPACE = uuid.UUID("22d4aa19-571c-5c38-9fd2-49f0315ec38b")
USER_AGENT = "Tarteel-Islamic-Library-Importer/1.0 (+https://github.com/Mtzallqmy/Quran-yomk)"
CC0_URL = "https://creativecommons.org/publicdomain/zero/1.0/"
REPORT: dict[str, Any] = {"started_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "sources": {}}

SOURCES = {
    "seen_adhkar": {
        "repo": "Seen-Arabic/Morning-And-Evening-Adhkar-DB",
        "license": "MIT (repository dataset)",
        "license_url": "https://github.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB/blob/main/LICENSE",
    },
    "fitrahive_dua_dhikr": {
        "repo": "fitrahive/dua-dhikr",
        "license": "MIT (repository dataset)",
        "license_url": "https://github.com/fitrahive/dua-dhikr/blob/main/LICENSE",
    },
    "hisn_el_muslim": {
        "repo": "asellam/HisnElMuslim",
        "license": "MIT (repository dataset)",
        "license_url": "https://github.com/asellam/HisnElMuslim/blob/main/LICENSE.md",
    },
}

TANZIL_URL = (
    "https://tanzil.net/pub/download/index.php?"
    "quranType=uthmani&outType=txt-2&agree=true&marks=true&"
    "sajdah=true&rub=true&stanween=true"
)
TANZIL_LICENSE = "Creative Commons Attribution 3.0 + Tanzil verbatim-only terms"
TANZIL_LICENSE_URL = "https://tanzil.net/docs/Text_License"

@dataclass(frozen=True)
class WikimediaAudio:
    file_name: str
    slug: str
    kind: str
    title_ar: str
    expected_author: str

WIKIMEDIA_AUDIO = (
    WikimediaAudio("Beautiful adhan.ogg", "beautiful-adhan-cc0", "adhan", "أذان — Beautiful Adhan", "Adam-synagda"),
    WikimediaAudio("Adhan.ogg", "adhan-aishatu98-cc0", "adhan", "أذان — تسجيل Aishatu98", "Aishatu98"),
    WikimediaAudio("Muslim calling to prayer.ogg", "muslim-call-prayer-aishatu98-cc0", "adhan", "أذان — Muslim calling to prayer", "Aishatu98"),
    WikimediaAudio("Iqamah.ogg", "iqamah-aishatu98-cc0", "iqamah", "إقامة — تسجيل Aishatu98", "Aishatu98"),
)


def require_runtime() -> None:
    if not PROJECT_URL.startswith("https://"):
        raise SystemExit("SUPABASE_PROJECT_URL must be an https URL")
    if not SERVER_KEY:
        raise SystemExit("SUPABASE_SERVER_KEY is required and must be supplied via a secret")


def _request(url: str, *, method: str = "GET", data: bytes | None = None,
             headers: dict[str, str] | None = None, timeout: int = 90):
    merged = {"User-Agent": USER_AGENT, **(headers or {})}
    req = urllib.request.Request(url, method=method, data=data, headers=merged)
    return urllib.request.urlopen(req, timeout=timeout)


def fetch_bytes(url: str, *, max_bytes: int) -> tuple[bytes, str]:
    if not url.startswith("https://"):
        raise RuntimeError(f"non-HTTPS source rejected: {url}")
    with _request(url, headers={"Accept": "*/*"}) as response:
        advertised = int(response.headers.get("content-length", "0") or 0)
        if advertised and advertised > max_bytes:
            raise RuntimeError(f"source too large: {url} ({advertised})")
        payload = response.read(max_bytes + 1)
        if not payload or len(payload) > max_bytes:
            raise RuntimeError(f"invalid source size: {url} ({len(payload)})")
        return payload, response.headers.get("content-type", "")


def fetch_json(url: str, *, max_bytes: int = 5_000_000) -> tuple[Any, str]:
    payload, _ = fetch_bytes(url, max_bytes=max_bytes)
    return json.loads(payload.decode("utf-8-sig")), sha256(payload)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_item_sha(source: str, key: str, categories: Iterable[str], title: str,
                       text_ar: str, reference: str, repeat_count: int) -> str:
    parts = [
        "tarteel-islamic-content-v1", source, key,
        ",".join(sorted(categories)), title, text_ar, reference, str(repeat_count),
    ]
    return sha256("\0".join(parts).encode("utf-8"))


def deterministic_uuid(name: str) -> str:
    return str(uuid.uuid5(NAMESPACE, name))


def strip_html(value: Any) -> str:
    if not isinstance(value, str):
        return ""
    text = re.sub(r"<[^>]+>", " ", value)
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


def clamp_repeat(value: Any, fallback: int = 1) -> int:
    try:
        number = int(value)
    except (TypeError, ValueError):
        number = fallback
    return max(1, min(10_000, number))


def postgrest(path: str, *, method: str = "GET", body: Any | None = None,
              prefer: str | None = None) -> Any:
    url = f"{PROJECT_URL}/rest/v1/{path.lstrip('/')}"
    headers = {
        "Authorization": f"Bearer {SERVER_KEY}",
        "apikey": SERVER_KEY,
        "Accept": "application/json",
    }
    data = None
    if body is not None:
        data = json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if prefer:
        headers["Prefer"] = prefer
    try:
        with _request(url, method=method, data=data, headers=headers, timeout=120) as response:
            raw = response.read()
            if not raw:
                return None
            return json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")[:1200]
        raise RuntimeError(f"PostgREST {error.code} {path}: {detail}") from error


def chunked(values: list[Any], size: int) -> Iterable[list[Any]]:
    for start in range(0, len(values), size):
        yield values[start:start + size]


def audit(source_slug: str, status: str, *, count: int = 0,
          source_file_sha256: str | None = None, details: dict[str, Any] | None = None,
          error_code: str | None = None) -> None:
    row = {
        "source_slug": source_slug,
        "status": status,
        "inserted_count": count,
        "updated_count": 0,
        "source_file_sha256": source_file_sha256,
        "error_code": error_code,
        "details": details or {},
        "completed_at": None if status == "started" else time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    postgrest("islamic_content_import_runs", method="POST", body=row, prefer="return=minimal")


def source_revision(repo: str) -> str:
    url = f"https://api.github.com/repos/{repo}/commits/main"
    data, _ = fetch_json(url, max_bytes=1_000_000)
    value = str(data.get("sha", ""))
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise RuntimeError(f"unable to pin source revision for {repo}")
    return value


def raw_github(repo: str, revision: str, path: str) -> str:
    return f"https://raw.githubusercontent.com/{repo}/{revision}/{path}"


def make_item(*, source: str, key: str, title: str, text_ar: str,
              categories: list[str], reference: str = "", repeat_count: int = 1,
              original_source_url: str, license_name: str, license_url: str,
              source_file_sha256: str | None = None, source_revision_value: str | None = None,
              metadata: dict[str, Any] | None = None, audio_asset_id: str | None = None) -> tuple[dict[str, Any], list[str]]:
    repeat_count = clamp_repeat(repeat_count)
    item_id = deterministic_uuid(f"content:{source}:{key}")
    item_sha = canonical_item_sha(source, key, categories, title, text_ar, reference, repeat_count)
    return ({
        "id": item_id,
        "source_slug": source,
        "source_key": key,
        "title_ar": title.strip(),
        "text_ar": text_ar.strip(),
        "reference": reference.strip() or None,
        "repeat_count": repeat_count,
        "audio_asset_id": audio_asset_id,
        "license_name": license_name,
        "license_url": license_url,
        "original_source_url": original_source_url,
        "review_status": "approved",
        "sha256": item_sha,
        "source_file_sha256": source_file_sha256,
        "source_revision": source_revision_value,
        "metadata": metadata or {},
    }, categories)


def upsert_items(rows: list[tuple[dict[str, Any], list[str]]]) -> int:
    for batch in chunked(rows, 100):
        items = [item for item, _ in batch]
        postgrest(
            "islamic_content_items?on_conflict=source_slug,source_key",
            method="POST", body=items,
            prefer="resolution=merge-duplicates,return=minimal",
        )
        links = [
            {"item_id": item["id"], "category_slug": category}
            for item, categories in batch for category in categories
        ]
        if links:
            postgrest(
                "islamic_content_item_categories?on_conflict=item_id,category_slug",
                method="POST", body=links,
                prefer="resolution=ignore-duplicates,return=minimal",
            )
    return len(rows)


def import_seen() -> dict[str, Any]:
    source = "seen_adhkar"
    cfg = SOURCES[source]
    revision = source_revision(cfg["repo"])
    url = raw_github(cfg["repo"], revision, "ar.json")
    audit(source, "started", details={"url": url, "revision": revision})
    payload, file_sha = fetch_json(url)
    rows: list[tuple[dict[str, Any], list[str]]] = []
    for fallback_order, value in enumerate(payload, 1):
        order = clamp_repeat(value.get("order"), fallback_order)
        body = str(value.get("content") or "").strip()
        if not body:
            continue
        type_code = int(value.get("type") or 0)
        categories = ["adhkar_morning"] if type_code == 1 else ["adhkar_evening"] if type_code == 2 else ["adhkar_morning", "adhkar_evening"]
        label = "ذكر الصباح" if type_code == 1 else "ذكر المساء" if type_code == 2 else "ذكر الصباح والمساء"
        rows.append(make_item(
            source=source, key=str(order), title=f"{label} {order}", text_ar=body,
            categories=categories, reference=str(value.get("source") or ""),
            repeat_count=clamp_repeat(value.get("count"), 1),
            original_source_url=url, license_name=cfg["license"], license_url=cfg["license_url"],
            source_file_sha256=file_sha, source_revision_value=revision,
            metadata={
                "fadl": str(value.get("fadl") or ""),
                "hadith_text": str(value.get("hadith_text") or ""),
                "audio_policy": "external_audio_url_not_mirrored_without_independent_rights_review",
                "upstream_audio_present": bool(str(value.get("audio") or "").strip()),
            },
        ))
    count = upsert_items(rows)
    audit(source, "completed", count=count, source_file_sha256=file_sha, details={"revision": revision, "external_audio_imported": False})
    return {"count": count, "revision": revision, "sha256": file_sha}


FITRAHIVE_FILES = (
    ("morning-dhikr", "adhkar_morning", "أذكار الصباح"),
    ("evening-dhikr", "adhkar_evening", "أذكار المساء"),
    ("dhikr-after-salah", "adhkar_prayer", "أذكار ما بعد الصلاة"),
    ("daily-dua", "dua", "دعاء يومي"),
    ("selected-dua", "dua", "دعاء مختار"),
)


def parse_repeat_notes(notes: str) -> int:
    match = re.search(r"\b(\d{1,4})\b", notes)
    return clamp_repeat(match.group(1), 1) if match else 1


def import_fitrahive() -> dict[str, Any]:
    source = "fitrahive_dua_dhikr"
    cfg = SOURCES[source]
    revision = source_revision(cfg["repo"])
    audit(source, "started", details={"revision": revision})
    rows: list[tuple[dict[str, Any], list[str]]] = []
    files: list[dict[str, Any]] = []
    for folder, category, label in FITRAHIVE_FILES:
        url = raw_github(cfg["repo"], revision, f"data/dua-dhikr/{folder}/en.json")
        payload, file_sha = fetch_json(url)
        files.append({"path": folder, "sha256": file_sha})
        for index, value in enumerate(payload, 1):
            arabic = str(value.get("arabic") or "").strip()
            if not arabic:
                continue
            notes = str(value.get("notes") or "")
            rows.append(make_item(
                source=source, key=f"{folder}:{index}", title=f"{label} {index}", text_ar=arabic,
                categories=[category], reference=str(value.get("source") or ""),
                repeat_count=parse_repeat_notes(notes), original_source_url=url,
                license_name=cfg["license"], license_url=cfg["license_url"],
                source_file_sha256=file_sha, source_revision_value=revision,
                metadata={
                    "upstream_title": str(value.get("title") or ""),
                    "notes": notes,
                    "fawaid": str(value.get("fawaid") or ""),
                    "translation": str(value.get("translation") or ""),
                    "transliteration": str(value.get("latin") or ""),
                },
            ))
    count = upsert_items(rows)
    audit(source, "completed", count=count, details={"revision": revision, "files": files})
    return {"count": count, "revision": revision, "files": files}


def hisn_categories(title: str) -> list[str]:
    categories: list[str] = []
    if re.search(r"الصباح|يصبح|صباح", title): categories.append("adhkar_morning")
    if re.search(r"المساء|يمسي|مساء", title): categories.append("adhkar_evening")
    if re.search(r"النوم|الفراش|الاستيقاظ", title): categories.append("adhkar_sleep")
    if re.search(r"الصلاة|الأذان|الإقامة|الوضوء|المسجد", title): categories.append("adhkar_prayer")
    if not categories: categories.append("dua")
    return list(dict.fromkeys(categories))


def import_hisn() -> dict[str, Any]:
    source = "hisn_el_muslim"
    cfg = SOURCES[source]
    revision = source_revision(cfg["repo"])
    url = raw_github(cfg["repo"], revision, "hisn.json")
    audit(source, "started", details={"url": url, "revision": revision})
    payload, file_sha = fetch_json(url)
    rows: list[tuple[dict[str, Any], list[str]]] = []
    for group_index, (title, group) in enumerate(payload.items(), 1):
        entries = group.get("Adhkar") if isinstance(group, dict) else []
        if not isinstance(entries, list):
            continue
        for index, value in enumerate(entries, 1):
            body = str(value.get("Text") or "").strip()
            if not body:
                continue
            rows.append(make_item(
                source=source, key=f"{group_index}:{index}", title=title, text_ar=body,
                categories=hisn_categories(title), reference=str(value.get("Reference") or ""),
                repeat_count=clamp_repeat(value.get("Count"), 1), original_source_url=url,
                license_name=cfg["license"], license_url=cfg["license_url"],
                source_file_sha256=file_sha, source_revision_value=revision,
                metadata={
                    "group_title": title,
                    "audio_policy": "section_audio_not_mirrored_without_independent_rights_review",
                    "upstream_audio_present": bool(str(group.get("Audio") or "").strip()),
                },
            ))
    count = upsert_items(rows)
    audit(source, "completed", count=count, source_file_sha256=file_sha, details={"revision": revision, "external_audio_imported": False})
    return {"count": count, "revision": revision, "sha256": file_sha}


def import_tanzil() -> dict[str, Any]:
    source = "tanzil_uthmani_1_1"
    audit(source, "started", details={"url": TANZIL_URL, "policy": "verbatim_only"})
    payload, content_type = fetch_bytes(TANZIL_URL, max_bytes=3_000_000)
    file_sha = sha256(payload)
    raw = payload.decode("utf-8-sig")
    rows: list[tuple[dict[str, Any], list[str]]] = []
    for line in raw.splitlines():
        line = line.strip("\ufeff\r\n")
        if not line or line.startswith("#"):
            continue
        match = re.match(r"^(\d+)\|(\d+)\|(.*)$", line)
        if not match:
            continue
        surah, ayah, verse = int(match.group(1)), int(match.group(2)), match.group(3)
        if not (1 <= surah <= 114 and ayah >= 1 and verse):
            raise RuntimeError(f"invalid Tanzil row: {line[:80]}")
        rows.append(make_item(
            source=source, key=f"{surah}:{ayah}", title=f"سورة {surah} — الآية {ayah}", text_ar=verse,
            categories=["quran"], reference=f"{surah}:{ayah}", repeat_count=1,
            original_source_url="https://tanzil.net/download/", license_name=TANZIL_LICENSE,
            license_url=TANZIL_LICENSE_URL, source_file_sha256=file_sha, source_revision_value="1.1",
            metadata={"surah": surah, "ayah": ayah, "verbatim": True, "download_url": TANZIL_URL, "content_type": content_type},
        ))
    if len(rows) != 6236:
        raise RuntimeError(f"Tanzil verse count must be 6236, got {len(rows)}")
    count = upsert_items(rows)
    audit(source, "completed", count=count, source_file_sha256=file_sha, details={"version": "1.1", "verse_count": count, "verbatim": True})
    return {"count": count, "sha256": file_sha, "version": "1.1"}


def wikimedia_metadata(file_name: str) -> dict[str, Any]:
    params = urllib.parse.urlencode({
        "action": "query", "format": "json", "formatversion": "2",
        "prop": "imageinfo", "iiprop": "url|size|sha1|mime|extmetadata|user|timestamp",
        "titles": f"File:{file_name}",
    })
    data, _ = fetch_json(f"https://commons.wikimedia.org/w/api.php?{params}", max_bytes=2_000_000)
    pages = data.get("query", {}).get("pages", [])
    if len(pages) != 1 or "imageinfo" not in pages[0] or not pages[0]["imageinfo"]:
        raise RuntimeError(f"Wikimedia metadata unavailable for {file_name}")
    return pages[0]["imageinfo"][0]


def public_storage_url(path: str) -> str:
    quoted = "/".join(urllib.parse.quote(part) for part in path.split("/"))
    return f"{PROJECT_URL}/storage/v1/object/public/{BUCKET}/{quoted}"


def storage_upload(path: str, payload: bytes, *, expected_sha: str) -> None:
    existing: bytes | None = None
    try:
        existing, _ = fetch_bytes(public_storage_url(path), max_bytes=12_000_000)
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
    except RuntimeError:
        existing = None
    if existing is not None:
        if sha256(existing) != expected_sha:
            raise RuntimeError(f"immutable Storage conflict: {path}")
        return
    url = f"{PROJECT_URL}/storage/v1/object/{BUCKET}/" + "/".join(urllib.parse.quote(part) for part in path.split("/"))
    headers = {
        "Authorization": f"Bearer {SERVER_KEY}", "apikey": SERVER_KEY,
        "Content-Type": "audio/ogg", "cache-control": "31536000", "x-upsert": "false",
    }
    try:
        with _request(url, method="POST", data=payload, headers=headers, timeout=180) as response:
            if response.status not in (200, 201):
                raise RuntimeError(f"unexpected Storage status {response.status}")
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")[:800]
        raise RuntimeError(f"Storage upload failed {error.code}: {detail}") from error


def extmeta_value(ext: dict[str, Any], key: str) -> str:
    raw = ext.get(key, {})
    return strip_html(raw.get("value")) if isinstance(raw, dict) else ""


def import_audio() -> dict[str, Any]:
    source = "wikimedia_commons_audio"
    audit(source, "started", details={"allowlist": [x.file_name for x in WIKIMEDIA_AUDIO]})
    imported: list[dict[str, Any]] = []
    for spec in WIKIMEDIA_AUDIO:
        info = wikimedia_metadata(spec.file_name)
        ext = info.get("extmetadata") or {}
        license_short = extmeta_value(ext, "LicenseShortName")
        usage_terms = extmeta_value(ext, "UsageTerms")
        author = extmeta_value(ext, "Artist") or str(info.get("user") or "")
        source_url = f"https://commons.wikimedia.org/wiki/File:{urllib.parse.quote(spec.file_name.replace(' ', '_'))}"
        original_url = str(info.get("url") or "")
        mime = str(info.get("mime") or "").lower()
        if "cc0" not in license_short.lower() and "cc0" not in usage_terms.lower():
            raise RuntimeError(f"{spec.file_name}: per-file license is not CC0 ({license_short!r})")
        if mime not in {"application/ogg", "audio/ogg"} or not original_url.startswith("https://"):
            raise RuntimeError(f"{spec.file_name}: unexpected media type/url ({mime})")
        if spec.expected_author.lower() not in author.lower() and spec.expected_author.lower() not in str(info.get("user") or "").lower():
            raise RuntimeError(f"{spec.file_name}: author/uploader changed; manual review required")
        payload, content_type = fetch_bytes(original_url, max_bytes=10_000_000)
        digest = sha256(payload)
        declared_size = int(info.get("size") or 0)
        if declared_size and declared_size != len(payload):
            raise RuntimeError(f"{spec.file_name}: Wikimedia size mismatch")
        path = f"v1/{spec.kind}/{spec.slug}-{digest[:16]}.ogg"
        storage_upload(path, payload, expected_sha=digest)
        audio_id = deterministic_uuid(f"audio:{spec.slug}")
        license_url = extmeta_value(ext, "LicenseUrl") or CC0_URL
        metadata = {
            "wikimedia_file": spec.file_name,
            "wikimedia_sha1": str(info.get("sha1") or ""),
            "wikimedia_timestamp": str(info.get("timestamp") or ""),
            "wikimedia_uploader": str(info.get("user") or ""),
            "author": author,
            "rights_verified_per_file": True,
            "license_short_name": license_short,
            "usage_terms": usage_terms,
            "source_mime": mime,
            "download_content_type": content_type,
            "performer_identity_verified": False,
        }
        postgrest(
            "islamic_audio_assets?on_conflict=slug", method="POST",
            body={
                "id": audio_id, "slug": spec.slug, "kind": spec.kind,
                "title_ar": spec.title_ar, "voice_name": author or spec.expected_author,
                "source_slug": source, "original_source_url": source_url,
                "storage_bucket": BUCKET, "storage_path": path, "mime_type": "audio/ogg",
                "byte_size": len(payload), "duration_ms": None, "sha256": digest,
                "license_name": "CC0 1.0 Universal", "license_url": license_url,
                "redistribution_allowed": True, "review_status": "approved", "metadata": metadata,
            },
            prefer="resolution=merge-duplicates,return=minimal",
        )
        category = "iqamah" if spec.kind == "iqamah" else "adhan"
        item = make_item(
            source=source, key=f"audio:{spec.slug}", title=spec.title_ar,
            text_ar="الإقامة" if spec.kind == "iqamah" else "الأذان", categories=[category],
            original_source_url=source_url, license_name="CC0 1.0 Universal", license_url=license_url,
            source_file_sha256=digest, source_revision_value=str(info.get("timestamp") or ""),
            metadata={"audio_only": True, "rights_verified_per_file": True}, audio_asset_id=audio_id,
        )
        upsert_items([item])
        imported.append({"slug": spec.slug, "path": path, "sha256": digest, "bytes": len(payload), "license": license_short})
    audit(source, "completed", count=len(imported), details={"imported": imported})
    return {"count": len(imported), "assets": imported}


def verify_database() -> dict[str, Any]:
    result: dict[str, Any] = {}
    for source in ["seen_adhkar", "fitrahive_dua_dhikr", "hisn_el_muslim", "tanzil_uthmani_1_1", "wikimedia_commons_audio"]:
        rows = postgrest(f"islamic_content_items?select=id&source_slug=eq.{urllib.parse.quote(source)}&review_status=eq.approved")
        result[source] = len(rows or [])
    audio = postgrest("islamic_audio_assets?select=slug,sha256,storage_path,license_name&review_status=eq.approved&redistribution_allowed=eq.true") or []
    if len(audio) < 4:
        raise RuntimeError(f"expected at least four approved redistributed audio assets, found {len(audio)}")
    result["approved_audio"] = len(audio)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scope", choices=["all", "seen", "fitrahive", "hisn", "tanzil", "audio", "verify"], default="all")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    require_runtime()
    tasks = {
        "seen": import_seen,
        "fitrahive": import_fitrahive,
        "hisn": import_hisn,
        "tanzil": import_tanzil,
        "audio": import_audio,
    }
    try:
        if args.scope == "all":
            for name in ("seen", "fitrahive", "hisn", "tanzil", "audio"):
                REPORT["sources"][name] = tasks[name]()
            REPORT["verification"] = verify_database()
        elif args.scope == "verify":
            REPORT["verification"] = verify_database()
        else:
            REPORT["sources"][args.scope] = tasks[args.scope]()
        REPORT["status"] = "PASS"
    except Exception as exc:
        REPORT["status"] = "FAIL"
        REPORT["error"] = f"{type(exc).__name__}: {exc}"
        raise
    finally:
        REPORT["finished_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(REPORT, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps(REPORT, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
