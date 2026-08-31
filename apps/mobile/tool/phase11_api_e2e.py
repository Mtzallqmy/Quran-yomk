#!/usr/bin/env python3
"""Phase 11 real-path acceptance: Tarteel API -> normalized station -> real audio.

This intentionally does not talk to PostgreSQL directly and does not use a
service-role credential. It exercises the same public Edge API contract shipped
in Flutter, then probes only a bounded representative set of returned external
URLs. Continuous audio is never proxied through Supabase.

Virtual Radio is failover-aware: a failed current source is acceptable only when
the resolver returns a different fallback source and that fallback yields real
audio. The primary failure remains recorded in the evidence file.
"""
from __future__ import annotations

import json
import re
import subprocess
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
API_DART = ROOT / "apps/mobile/lib/src/api.dart"
OUT = ROOT / "apps/mobile/release/phase11"
OUT.mkdir(parents=True, exist_ok=True)

source = API_DART.read_text(encoding="utf-8")
base_match = re.search(r"productionBaseUrl\s*=\s*\n?\s*'([^']+)'", source)
key_match = re.search(r"defaultValue:\s*'([^']+)'", source)
if not base_match or not key_match:
    raise SystemExit("Could not resolve the Flutter public API configuration")
BASE = base_match.group(1).rstrip("/")
API_KEY = key_match.group(1)


def get(path: str, query: dict[str, str] | None = None) -> dict:
    url = f"{BASE}/{path.lstrip('/')}"
    if query:
        url += "?" + urllib.parse.urlencode(query)
    req = urllib.request.Request(
        url,
        headers={"accept": "application/json", "apikey": API_KEY, "user-agent": "TarteelPhase11Acceptance/1.0"},
    )
    with urllib.request.urlopen(req, timeout=15) as response:
        data = json.loads(response.read().decode("utf-8"))
        if response.status < 200 or response.status >= 300:
            raise RuntimeError(f"GET {path} failed with {response.status}: {data}")
        return data


def ffprobe(url: str) -> dict:
    if not url.startswith("https://"):
        return {"result": "STREAM_INSECURE", "url": url, "audio_codec": None, "first_audio_ms": None}
    started = time.monotonic()
    command = [
        "timeout", "18s", "ffprobe", "-v", "error", "-rw_timeout", "9000000",
        "-analyzeduration", "3500000", "-probesize", "1200000",
        "-show_entries", "stream=codec_type,codec_name:format=format_name", "-of", "json", url,
    ]
    process = subprocess.run(command, text=True, capture_output=True)
    elapsed = round((time.monotonic() - started) * 1000)
    payload = {}
    if process.stdout.strip():
        try:
            payload = json.loads(process.stdout)
        except json.JSONDecodeError:
            payload = {}
    codecs = [
        stream.get("codec_name")
        for stream in payload.get("streams", [])
        if stream.get("codec_type") == "audio" and stream.get("codec_name")
    ]
    return {
        "result": "PASS" if codecs else "FAIL",
        "url": url,
        "audio_codec": codecs[0] if codecs else None,
        "format": (payload.get("format") or {}).get("format_name"),
        "first_audio_ms": elapsed if codecs else None,
        "exit": process.returncode,
        "error": process.stderr.strip()[-500:] or None,
    }


def station_query(**query: str) -> dict:
    payload = get("stations", {**query, "source": "EXTERNAL", "limit": "200"})
    rows = payload.get("data") or []
    if not rows:
        raise RuntimeError(f"No station returned for query {query}")
    https_rows = [row for row in rows if str(row.get("playback_url") or "").startswith("https://")]
    preferred = [row for row in https_rows if row.get("health_status") == "HEALTHY"] or https_rows
    if not preferred:
        raise RuntimeError(f"No secure playable station returned for query {query}")
    return preferred[0]


def probe_station(label: str, station: dict) -> dict:
    result = ffprobe(str(station.get("playback_url") or ""))
    evidence = {
        "label": label,
        "station_id": station.get("id"),
        "station_slug": station.get("slug"),
        "station_name": station.get("name_ar"),
        "provider": station.get("provider"),
        "stream_type": station.get("stream_type"),
        "catalog_health": station.get("health_status"),
        **result,
    }
    print(json.dumps(evidence, ensure_ascii=False), flush=True)
    return evidence


def main() -> None:
    first = get("stations", {"source": "EXTERNAL", "page": "1", "limit": "200"})
    catalog = list(first.get("data") or [])
    page = first.get("next_page")
    seen_pages = {1}
    while isinstance(page, int) and page not in seen_pages and len(seen_pages) < 20:
        seen_pages.add(page)
        current = get("stations", {"source": "EXTERNAL", "page": str(page), "limit": "200"})
        catalog.extend(current.get("data") or [])
        page = current.get("next_page")
    unique = {row.get("id"): row for row in catalog if row.get("id")}
    if len(unique) < 10:
        raise RuntimeError(f"Normalized external catalog unexpectedly small: {len(unique)}")

    representatives = {
        "quran_general": station_query(category="QURAN_GENERAL"),
        "reciter": station_query(category="RECITER"),
        "tafseer": station_query(category="TAFSEER"),
        "adhkar": station_query(category="ADHKAR"),
        "live_hls": station_query(category="LIVE_TV_AUDIO"),
        "radiojar": station_query(provider="radiojar"),
        "islamic_radio_api": station_query(provider="islamic-radio-api"),
        "islamic_app": station_query(provider="islamic-app"),
    }
    results = [probe_station(label, station) for label, station in representatives.items()]

    virtual = get("virtual-radio/tarteel").get("data") or {}
    virtual_station = virtual.get("station") or {}
    if virtual.get("available") is not True or not virtual_station.get("id"):
        raise RuntimeError("Virtual Tarteel Radio did not resolve a current source")
    current = probe_station("virtual_tarteel_current", virtual_station)
    fallback_payload = get(
        "virtual-radio/tarteel",
        {"failed_station_ids": str(virtual_station["id"])},
    ).get("data") or {}
    fallback_station = fallback_payload.get("station") or {}
    if fallback_payload.get("available") is not True or not fallback_station.get("id"):
        raise RuntimeError("Virtual Tarteel Radio fallback did not resolve")
    if fallback_station.get("id") == virtual_station.get("id"):
        raise RuntimeError("Virtual Tarteel Radio fallback reused the failed station")
    if (fallback_payload.get("channel") or {}).get("id") != (virtual.get("channel") or {}).get("id"):
        raise RuntimeError("Virtual Tarteel Radio fallback changed the logical channel identity")
    fallback = probe_station("virtual_tarteel_fallback", fallback_station)

    failed = [item["label"] for item in results if item["result"] != "PASS"]
    failover_accepted = current["result"] != "PASS" and fallback["result"] == "PASS"
    virtual_path_passed = current["result"] == "PASS" or failover_accepted
    if not virtual_path_passed:
        failed.extend(
            item["label"] for item in (current, fallback) if item["result"] != "PASS"
        )
    if failover_accepted:
        print(
            json.dumps(
                {
                    "event": "VIRTUAL_FAILOVER_ACCEPTED",
                    "failed_station_id": current.get("station_id"),
                    "fallback_station_id": fallback.get("station_id"),
                    "logical_channel": (virtual.get("channel") or {}).get("name_ar"),
                    "fallback_audio_ms": fallback.get("first_audio_ms"),
                },
                ensure_ascii=False,
            ),
            flush=True,
        )

    evidence = {
        "api_base": BASE,
        "external_catalog_unique": len(unique),
        "pages": len(seen_pages),
        "virtual_channel": (virtual.get("channel") or {}).get("name_ar"),
        "virtual_program": (virtual.get("program") or {}).get("title_ar"),
        "current_station_id": virtual_station.get("id"),
        "fallback_station_id": fallback_station.get("id"),
        "virtual_primary_result": current["result"],
        "virtual_fallback_result": fallback["result"],
        "virtual_failover_accepted": failover_accepted,
        "results": results + [current, fallback],
        "failed": failed,
        "verified_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    (OUT / "api-real-stream-e2e.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
    if failed:
        raise RuntimeError("Real API/audio acceptance failed: " + ", ".join(failed))
    print(f"PHASE11 API->REAL STREAM PASS ({len(unique)} external stations discovered)")


if __name__ == "__main__":
    main()
