#!/usr/bin/env python3
"""Live public-product smoke test.

This intentionally verifies the deployed public API and a small byte range from
one radio stream and one on-demand recitation. It is a release gate, not a unit
test: a build must not be called functional when it only renders catalog JSON.
"""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from typing import Any

BASE = "https://qkroecnecdxghcqvvoxn.supabase.co/functions/v1/tarteel-api"
API_KEY = "sb_publishable_dLYCid35ZkeIE95xqiyHoQ_bEhWWISK"
TIMEOUT = 20


def get_json(path: str) -> dict[str, Any]:
    request = urllib.request.Request(
        f"{BASE}/{path.lstrip('/')}",
        headers={"accept": "application/json", "apikey": API_KEY, "user-agent": "Tarteel-E2E/1.0"},
    )
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        if response.status != 200:
            raise RuntimeError(f"{path}: HTTP {response.status}")
        return json.loads(response.read().decode("utf-8"))


def fetch_audio_prefix(url: str, label: str) -> int:
    if not url.startswith("https://"):
        raise RuntimeError(f"{label}: non-HTTPS playback URL")
    request = urllib.request.Request(
        url,
        headers={
            "Range": "bytes=0-4095",
            "Icy-MetaData": "1",
            "user-agent": "Tarteel-E2E/1.0",
            "accept": "*/*",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            data = response.read(4096)
            if response.status not in (200, 206):
                raise RuntimeError(f"{label}: HTTP {response.status}")
            if len(data) < 64:
                raise RuntimeError(f"{label}: only {len(data)} bytes received")
            return len(data)
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"{label}: HTTP {exc.code}") from exc


def main() -> int:
    stations_body = get_json("stations?limit=50")
    stations = stations_body.get("data") or []
    playable_stations = [
        row for row in stations
        if isinstance(row, dict)
        and isinstance(row.get("playback_url"), str)
        and row["playback_url"].startswith("https://")
    ]
    if not playable_stations:
        raise RuntimeError("No playable public station returned by the live API")

    reciters_body = get_json("reciters?limit=5")
    reciters = reciters_body.get("data") or []
    if not reciters:
        raise RuntimeError("No public reciters returned by the live API")
    first_reciter = reciters[0]
    reciter_id = first_reciter.get("id") if isinstance(first_reciter, dict) else None
    if not isinstance(reciter_id, str) or not reciter_id:
        raise RuntimeError("First reciter has no stable id")

    tracks_body = get_json(f"reciters/{reciter_id}/surahs")
    tracks = tracks_body.get("data") or []
    playable_tracks = [
        row for row in tracks
        if isinstance(row, dict)
        and isinstance(row.get("track"), dict)
        and isinstance(row["track"].get("playback_url"), str)
        and row["track"]["playback_url"].startswith("https://")
    ]
    if not playable_tracks:
        raise RuntimeError("No playable surah returned for a public reciter")

    station = playable_stations[0]
    track = playable_tracks[0]["track"]
    station_bytes = fetch_audio_prefix(station["playback_url"], "radio")
    track_bytes = fetch_audio_prefix(track["playback_url"], "recitation")

    evidence = {
        "stations": len(stations),
        "playable_stations": len(playable_stations),
        "sample_station": station.get("name_ar") or station.get("slug"),
        "reciters_returned": len(reciters),
        "sample_reciter": first_reciter.get("name_ar"),
        "tracks": len(tracks),
        "sample_surah": playable_tracks[0].get("surah", {}).get("name_ar"),
        "radio_bytes": station_bytes,
        "recitation_bytes": track_bytes,
    }
    print("TARTEEL_PUBLIC_E2E " + json.dumps(evidence, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"TARTEEL_PUBLIC_E2E_FAILED {exc}", file=sys.stderr)
        raise
