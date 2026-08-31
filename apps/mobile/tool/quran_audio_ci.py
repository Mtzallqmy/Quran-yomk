#!/usr/bin/env python3
"""Verify the production Quran audio providers without proxying audio."""
from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "apps/mobile/release/quran-audio"
OUT.mkdir(parents=True, exist_ok=True)
HEADERS = {
    "accept": "application/json,audio/mpeg,*/*;q=0.1",
    "user-agent": "TarteelQuranAudioAcceptance/1.0",
}


def json_get(url: str) -> dict:
    request = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(request, timeout=30) as response:
        if response.status != 200:
            raise RuntimeError(f"HTTP {response.status}: {url}")
        return json.loads(response.read().decode("utf-8"))


def probe_audio(url: str) -> dict[str, object]:
    headers = dict(HEADERS)
    headers["Range"] = "bytes=0-8191"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        if response.status not in (200, 206):
            raise RuntimeError(f"HTTP {response.status}: {url}")
        sample = response.read(8192)
        content_type = (response.headers.get_content_type() or "").lower()
        if len(sample) < 4096:
            raise RuntimeError(f"Audio sample is too small ({len(sample)} bytes): {url}")
        if content_type not in ("audio/mpeg", "application/octet-stream"):
            raise RuntimeError(f"Unexpected content type {content_type!r}: {url}")
        if sample.lstrip().startswith((b"<html", b"<!doctype")):
            raise RuntimeError(f"HTML returned instead of audio: {url}")
        return {
            "url": url,
            "httpStatus": response.status,
            "contentType": content_type,
            "sampleBytes": len(sample),
        }


def main() -> None:
    editions = json_get("https://api.alquran.cloud/v1/edition/format/audio")
    edition_ids = {
        str(row.get("identifier"))
        for row in editions.get("data", [])
        if isinstance(row, dict)
    }
    if "ar.alafasy" not in edition_ids:
        raise RuntimeError("AlQuran Cloud did not expose the ar.alafasy audio edition")

    alquran_surah = probe_audio(
        "https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/1.mp3"
    )
    alquran_ayah = probe_audio(
        "https://cdn.islamic.network/quran/audio/64/ar.alafasy/1.mp3"
    )

    query = urllib.parse.urlencode({"language": "ar", "reciter": "5"})
    mp3_payload = json_get(f"https://www.mp3quran.net/api/v3/reciters?{query}")
    reciters = mp3_payload.get("reciters") or []
    selected = next(
        (
            (reciter, mushaf)
            for reciter in reciters
            for mushaf in (reciter.get("moshaf") or [])
            if str(mushaf.get("server") or "").startswith("https://")
            and "1" in str(mushaf.get("surah_list") or "").split(",")
        ),
        None,
    )
    if selected is None:
        raise RuntimeError("MP3Quran returned no HTTPS reciter with Al-Fatihah")
    reciter, mushaf = selected
    mp3_url = f"{str(mushaf['server']).rstrip('/')}/001.mp3"
    mp3quran_surah = probe_audio(mp3_url)

    report = {
        "status": "PASS",
        "checks": {
            "alquranCloudEdition": "ar.alafasy",
            "alquranCloudSurah128": alquran_surah,
            "alquranCloudAyah64": alquran_ayah,
            "mp3quranReciterId": reciter.get("id"),
            "mp3quranMoshafId": mushaf.get("id"),
            "mp3quranSurah": mp3quran_surah,
        },
        "verifiedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "scope": "Provider API/CDN reachability and audio-byte validation; not physical-device playback",
    }
    (OUT / "quran-audio-live-smoke.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False))
    print("QURAN AUDIO PROVIDERS -> LIVE SMOKE PASS")


if __name__ == "__main__":
    main()
