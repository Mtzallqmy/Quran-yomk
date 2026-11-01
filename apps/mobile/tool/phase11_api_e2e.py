#!/usr/bin/env python3
"""Real-path radio regression: Tarteel API -> normalized station -> real audio.

This is intentionally provider-failure-aware. It never relabels a failed stream
as healthy. Representative categories try a bounded set of secure catalog
candidates, and Virtual Tarteel Radio repeatedly reports failed station IDs to
the server resolver until one audible source is found or the bounded failover
budget is exhausted.
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
        headers={
            "accept": "application/json",
            "apikey": API_KEY,
            "user-agent": "TarteelPhase11Acceptance/1.1",
        },
    )
    with urllib.request.urlopen(req, timeout=15) as response:
        data = json.loads(response.read().decode("utf-8"))
        if response.status < 200 or response.status >= 300:
            raise RuntimeError(f"GET {path} failed with {response.status}: {data}")
        return data


def ffprobe(url: str) -> dict:
    if not url.startswith("https://"):
        return {
            "result": "STREAM_INSECURE",
            "url": url,
            "audio_codec": None,
            "first_audio_ms": None,
        }
    started = time.monotonic()
    command = [
        "timeout",
        "18s",
        "ffprobe",
        "-v",
        "error",
        "-rw_timeout",
        "9000000",
        "-analyzeduration",
        "3500000",
        "-probesize",
        "1200000",
        "-show_entries",
        "stream=codec_type,codec_name:format=format_name",
        "-of",
        "json",
        url,
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


def station_candidates(**query: str) -> list[dict]:
    payload = get("stations", {**query, "source": "EXTERNAL", "limit": "200"})
    rows = payload.get("data") or []
    https_rows = [
        row
        for row in rows
        if str(row.get("playback_url") or "").startswith("https://")
    ]
    healthy = [row for row in https_rows if row.get("health_status") == "HEALTHY"]
    other = [row for row in https_rows if row not in healthy]
    return healthy + other


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


def probe_any(label: str, *, optional: bool = False, max_attempts: int = 6, **query: str) -> tuple[dict | None, list[dict]]:
    attempts: list[dict] = []
    candidates = station_candidates(**query)
    if not candidates:
        if optional:
            print(f"TARTEEL_WARNING no secure candidates for optional {label}", flush=True)
            return None, attempts
        raise RuntimeError(f"No secure station returned for {label}: {query}")
    seen_urls: set[str] = set()
    for station in candidates:
        url = str(station.get("playback_url") or "")
        if not url or url in seen_urls:
            continue
        seen_urls.add(url)
        item = probe_station(f"{label}_attempt_{len(attempts)+1}", station)
        attempts.append(item)
        if item["result"] == "PASS":
            item["label"] = label
            return item, attempts
        if len(attempts) >= max_attempts:
            break
    if optional:
        print(
            f"TARTEEL_WARNING all bounded candidates unavailable for optional {label}; "
            "individual failed probes remain recorded",
            flush=True,
        )
        return None, attempts
    return None, attempts


def probe_virtual_with_failover(max_attempts: int = 8) -> tuple[dict, list[dict], list[str]]:
    attempts: list[dict] = []
    failed_ids: list[str] = []
    logical_channel_id = None
    initial: dict | None = None
    for attempt in range(max_attempts):
        query = {}
        if failed_ids:
            query["failed_station_ids"] = ",".join(failed_ids[-8:])
        payload = get("virtual-radio/tarteel", query).get("data") or {}
        station = payload.get("station") or {}
        if payload.get("available") is not True or not station.get("id"):
            break
        channel_id = (payload.get("channel") or {}).get("id")
        if logical_channel_id is None:
            logical_channel_id = channel_id
            initial = payload
        elif channel_id != logical_channel_id:
            raise RuntimeError("Virtual Tarteel Radio changed logical channel during failover")
        station_id = str(station["id"])
        if station_id in failed_ids:
            raise RuntimeError("Virtual resolver returned an already excluded station")
        item = probe_station(f"virtual_tarteel_attempt_{attempt+1}", station)
        item["program"] = (payload.get("program") or {}).get("title_ar")
        attempts.append(item)
        if item["result"] == "PASS":
            return payload, attempts, failed_ids
        failed_ids.append(station_id)
    raise RuntimeError(
        "Virtual Tarteel Radio exhausted bounded failover without audible audio; "
        f"failed_station_ids={failed_ids}"
    )


def main() -> None:
    first = get("stations", {"source": "EXTERNAL", "page": "1", "limit": "200"})
    catalog = list(first.get("data") or [])
    page = first.get("next_page")
    seen_pages = {1}
    while isinstance(page, int) and page not in seen_pages and len(seen_pages) < 20:
        seen_pages.add(page)
        current = get(
            "stations",
            {"source": "EXTERNAL", "page": str(page), "limit": "200"},
        )
        catalog.extend(current.get("data") or [])
        page = current.get("next_page")
    unique = {row.get("id"): row for row in catalog if row.get("id")}
    if len(unique) < 10:
        raise RuntimeError(f"Normalized external catalog unexpectedly small: {len(unique)}")

    results: list[dict] = []
    all_attempts: list[dict] = []
    required_queries = [
        ("quran_general", {"category": "QURAN_GENERAL"}),
        ("reciter", {"category": "RECITER"}),
        ("tafseer", {"category": "TAFSEER"}),
        ("live_hls", {"category": "LIVE_TV_AUDIO"}),
        ("radiojar", {"provider": "radiojar"}),
        ("islamic_radio_api", {"provider": "islamic-radio-api"}),
        ("islamic_app", {"provider": "islamic-app"}),
    ]
    for label, query in required_queries:
        passed, attempts = probe_any(label, **query)
        all_attempts.extend(attempts)
        if passed is None:
            raise RuntimeError(f"No audible candidate for required {label}")
        results.append(passed)

    # Adhkar is a third-party category with very small inventory and can be
    # temporarily entirely unavailable. Probe multiple real rows and keep its
    # failure as a recorded warning rather than fabricating a healthy result.
    adhkar, adhkar_attempts = probe_any(
        "adhkar",
        category="ADHKAR",
        optional=True,
        max_attempts=6,
    )
    all_attempts.extend(adhkar_attempts)
    if adhkar is not None:
        results.append(adhkar)

    virtual, virtual_attempts, failed_virtual_ids = probe_virtual_with_failover()
    all_attempts.extend(virtual_attempts)
    virtual_pass = virtual_attempts[-1]
    virtual_pass["label"] = "virtual_tarteel"
    results.append(virtual_pass)

    evidence = {
        "api_base": BASE,
        "external_catalog_unique": len(unique),
        "pages": len(seen_pages),
        "virtual_channel": (virtual.get("channel") or {}).get("name_ar"),
        "virtual_program": (virtual.get("program") or {}).get("title_ar"),
        "virtual_selected_station_id": (virtual.get("station") or {}).get("id"),
        "virtual_failed_station_ids_before_success": failed_virtual_ids,
        "virtual_failover_count": len(failed_virtual_ids),
        "adhkar_status": "PASS" if adhkar is not None else "TEMPORARILY_UNAVAILABLE_WARNING",
        "results": results,
        "all_attempts": all_attempts,
        "failed": [],
        "verified_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    (OUT / "api-real-stream-e2e.json").write_text(
        json.dumps(evidence, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(
        f"RADIO API->REAL STREAM PASS ({len(unique)} external stations; "
        f"virtual failovers={len(failed_virtual_ids)})"
    )


if __name__ == "__main__":
    main()
