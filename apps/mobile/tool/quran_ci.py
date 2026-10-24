#!/usr/bin/env python3
"""Live Quran/Mushaf acceptance through the Tarteel public API.

This deliberately tests the deployed Tarteel Edge API rather than calling the
Quran providers from Flutter or from the test directly. It catches deployment
drift such as a Mushaf UI shipping before /quran routes are live.
"""
from __future__ import annotations

import json
import re
import time
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
API_DART = ROOT / "apps/mobile/lib/src/api.dart"
OUT = ROOT / "apps/mobile/release/quran"
OUT.mkdir(parents=True, exist_ok=True)

source = API_DART.read_text(encoding="utf-8")
base_match = re.search(r"productionBaseUrl\s*=\s*\n?\s*'([^']+)'", source)
key_match = re.search(r"defaultValue:\s*'([^']+)'", source)
if not base_match or not key_match:
    raise SystemExit("Could not resolve Flutter public API configuration")
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
            "user-agent": "TarteelQuranAcceptance/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=20) as response:
        if response.status != 200:
            raise RuntimeError(f"HTTP {response.status} for {path}")
        return json.loads(response.read().decode("utf-8"))


def strip_marks(value: str) -> str:
    return "".join(
        char
        for char in unicodedata.normalize("NFD", value)
        if unicodedata.category(char) != "Mn"
    ).replace("ٱ", "ا").replace("ـ", "")


def passage(path: str, expected_mode: str, expected_number: int) -> dict:
    payload = get(path)
    data = payload.get("data") or {}
    verses = data.get("verses") or []
    if data.get("mode") != expected_mode or data.get("number") != expected_number:
        raise RuntimeError(f"Unexpected Quran passage identity for {path}")
    if data.get("total_pages") != 604:
        raise RuntimeError(f"Mushaf page contract is not 604 for {path}")
    if not verses:
        raise RuntimeError(f"No verses returned for {path}")
    if any(not str(row.get("text_uthmani") or "").strip() for row in verses[:5]):
        raise RuntimeError(f"Empty Uthmani text returned for {path}")
    return data


def main() -> None:
    surah = passage("quran/surah/1", "surah", 1)
    verses = surah["verses"]
    if len(verses) != 7:
        raise RuntimeError(f"Al-Fatihah verse count mismatch: {len(verses)}")
    first = verses[0]
    if first.get("verse_key") != "1:1" or first.get("surah_number") != 1 or first.get("ayah_number") != 1:
        raise RuntimeError("Al-Fatihah first verse identity mismatch")
    normalized = strip_marks(str(first.get("text_uthmani") or ""))
    if "بسم الله الرحمن الرحيم" not in normalized:
        raise RuntimeError("Al-Fatihah Uthmani text sample did not match expected source text")

    juz = passage("quran/juz/1", "juz", 1)
    if int((juz["verses"][0] or {}).get("juz_number") or 0) != 1:
        raise RuntimeError("Juz 1 did not report juz_number=1")

    page = passage("quran/page/1", "page", 1)
    if any(int(row.get("page_number") or 0) != 1 for row in page["verses"]):
        raise RuntimeError("Page 1 returned verses outside page 1")

    reciter_payload = get("quran/reciters", {"surah": "1"})
    reciters = (reciter_payload.get("data") or {}).get("reciters") or []
    playable = [
        row
        for row in reciters
        if str(row.get("id") or "").startswith("mp3quran-")
        and str(row.get("playback_url") or "").startswith("https://")
        and 1 in (row.get("available_surahs") or [])
    ]
    if not playable:
        raise RuntimeError("No real HTTPS MP3Quran reciter available for Al-Fatihah")

    selected = playable[0]
    tracks_payload = get(
        f"quran/reciters/{urllib.parse.quote(str(selected['id']))}/tracks"
    )
    tracks = (tracks_payload.get("data") or {}).get("tracks") or []
    fatihah_track = next(
        (row for row in tracks if int(row.get("surah_number") or 0) == 1),
        None,
    )
    if not fatihah_track or not str(fatihah_track.get("playback_url") or "").startswith("https://"):
        raise RuntimeError("Selected reciter has no HTTPS Al-Fatihah track")

    report = {
        "status": "PASS",
        "surah_1_verses": len(verses),
        "juz_1_verses": len(juz["verses"]),
        "page_1_verses": len(page["verses"]),
        "total_pages": page.get("total_pages"),
        "quran_source": surah.get("source"),
        "tajweed_available": surah.get("tajweed_available") is True,
        "reciters_for_surah_1": len(playable),
        "selected_reciter_id": selected.get("id"),
        "selected_track_https": True,
        "verified_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    (OUT / "quran-live-smoke.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False))
    print("QURAN LIVE API -> MUSHAF CONTRACT PASS")


if __name__ == "__main__":
    main()
