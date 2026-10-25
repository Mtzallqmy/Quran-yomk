#!/usr/bin/env python3
"""Validate the pinned Islamic Library Data contract and live CDN bytes."""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import urllib.request
from pathlib import Path


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "Tarteel-CI/1"})
    with urllib.request.urlopen(request, timeout=45) as response:
        if response.status != 200:
            raise SystemExit(f"HTTP {response.status}: {url}")
        return response.read()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--live", action="store_true")
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    revision = manifest["revision"]
    if len(revision) != 40 or any(ch not in "0123456789abcdef" for ch in revision):
        raise SystemExit("Islamic content revision is not an immutable commit SHA")
    assets = manifest["assets"]
    paths = {asset["path"] for asset in assets}
    required = {
        "quran/quran_segments.json",
        "quran/qcf_v2_pages.json",
        "quran/hizb_quarters.json",
        "tafseer/muyassar.json",
        "data/catalog.json",
        "names_of_allah/names_of_allah.json",
        "prophet_stories/index.json",
    }
    if not required <= paths:
        raise SystemExit(f"missing required assets: {sorted(required - paths)}")
    if not args.live:
        print("ISLAMIC_CONTENT_MANIFEST: PASS")
        return

    decoded: dict[str, object] = {}
    for asset in assets:
        data = fetch(manifest["cdn"] + asset["path"])
        if len(data) != asset["size"]:
            raise SystemExit(f"size mismatch: {asset['path']}")
        if hashlib.sha256(data).hexdigest() != asset["sha256"]:
            raise SystemExit(f"SHA-256 mismatch: {asset['path']}")
        decoded[asset["path"]] = json.loads(data)

    segments = decoded["quran/quran_segments.json"]
    qcf = decoded["quran/qcf_v2_pages.json"]
    tafseer = decoded["tafseer/muyassar.json"]
    names = decoded["names_of_allah/names_of_allah.json"]
    if segments["total_surahs"] != 114 or segments["total_segments"] != 745:
        raise SystemExit("thematic segment coverage mismatch")
    if len(qcf) != 604 or set(qcf) != {str(page) for page in range(1, 605)}:
        raise SystemExit("QCF V2 604-page coverage mismatch")
    if len(tafseer) != 6236 or len(names) != 99:
        raise SystemExit("core Quran/Names coverage mismatch")

    quran_paths = [
        f"quran/chapters/{language}/{surah}.json"
        for language in ("ar", "en")
        for surah in range(1, 115)
    ] + [f"quran/tajweed/{surah}.json" for surah in range(1, 115)]

    def live_json(path: str) -> tuple[str, object]:
        return path, json.loads(fetch(manifest["cdn"] + path))

    verse_totals = {"ar": 0, "en": 0, "tajweed": 0}
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as executor:
        for path, value in executor.map(live_json, quran_paths):
            if not value:
                raise SystemExit(f"empty live dataset: {path}")
            language = "tajweed" if "/tajweed/" in path else path.split("/")[2]
            verse_totals[language] += len(value["verses"])
    if set(verse_totals.values()) != {6236}:
        raise SystemExit(f"full-Quran coverage mismatch: {verse_totals}")

    # Counts are taken from the pinned JSON bytes, not the README summary,
    # which describes older/different exports for several collections.
    expected_hadith = {"bukhari": 7277, "muslim": 7459, "malik": 1985, "ahmed": 1374}
    for collection, count in expected_hadith.items():
        value = json.loads(fetch(manifest["cdn"] + f"hadith/{collection}.json"))
        if len(value["hadiths"]) != count:
            raise SystemExit(f"hadith count mismatch: {collection}")
    print("ISLAMIC_LIBRARY_DATA_LIVE_INTEGRITY: PASS")


if __name__ == "__main__":
    main()
