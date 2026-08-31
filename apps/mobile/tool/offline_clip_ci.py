#!/usr/bin/env python3
"""Real offline-clip acceptance.

Path under test:
Tarteel public API -> rights policy -> permitted live stream -> bounded local
capture -> ffprobe the resulting local file. The audio bytes never pass through
Supabase and the saved-file probe does not use the network URL.
"""
from __future__ import annotations

import json
import re
import subprocess
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
API_DART = ROOT / "apps/mobile/lib/src/api.dart"
OUT = ROOT / "apps/mobile/release/offline-clips"
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
            "user-agent": "TarteelOfflineClipAcceptance/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=15) as response:
        return json.loads(response.read().decode("utf-8"))


def local_probe(path: Path) -> dict:
    process = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "stream=codec_type,codec_name:format=format_name,duration",
            "-of",
            "json",
            str(path),
        ],
        text=True,
        capture_output=True,
        timeout=15,
    )
    payload = json.loads(process.stdout or "{}") if process.stdout.strip() else {}
    codecs = [
        stream.get("codec_name")
        for stream in payload.get("streams", [])
        if stream.get("codec_type") == "audio" and stream.get("codec_name")
    ]
    return {
        "passed": bool(codecs),
        "codec": codecs[0] if codecs else None,
        "format": (payload.get("format") or {}).get("format_name"),
        "duration": (payload.get("format") or {}).get("duration"),
        "ffprobe_error": process.stderr.strip()[-400:] or None,
    }


def capture(station: dict, target: Path) -> dict:
    url = str(station.get("playback_url") or "")
    if not url.startswith("https://"):
        return {"passed": False, "reason": "insecure_url"}
    started = time.monotonic()
    command = [
        "curl",
        "-L",
        "--fail",
        "--silent",
        "--show-error",
        "--connect-timeout",
        "8",
        "--max-time",
        "10",
        "-H",
        "Icy-MetaData: 0",
        "-H",
        "Accept: audio/mpeg,audio/aac,audio/aacp,*/*;q=0.1",
        "-o",
        str(target),
        url,
    ]
    process = subprocess.run(command, text=True, capture_output=True)
    size = target.stat().st_size if target.exists() else 0
    probe = local_probe(target) if size >= 8192 else {"passed": False}
    return {
        "passed": bool(probe.get("passed")),
        "capture_seconds": round(time.monotonic() - started, 2),
        "curl_exit": process.returncode,
        "captured_bytes": size,
        "curl_error": process.stderr.strip()[-400:] or None,
        "local_file_probe": probe,
    }


def candidates(provider: str) -> list[dict]:
    payload = get(
        "stations",
        {"source": "EXTERNAL", "provider": provider, "limit": "100"},
    )
    return [
        row
        for row in (payload.get("data") or [])
        if row.get("slug") and str(row.get("playback_url") or "").startswith("https://")
    ]


def main() -> None:
    attempts: list[dict] = []
    with tempfile.TemporaryDirectory(prefix="tarteel-offline-") as directory:
        root = Path(directory)
        for provider in ("qurango", "mp3quran"):
            for station in candidates(provider)[:12]:
                slug = str(station["slug"])
                policy = (get(f"stations/{urllib.parse.quote(slug)}/offline-clip-policy").get("data") or {})
                if policy.get("allowed") is not True or policy.get("supported_stream") is not True:
                    continue
                target = root / f"clip-{len(attempts)}.bin"
                result = capture(station, target)
                evidence = {
                    "provider": provider,
                    "station_id": station.get("id"),
                    "station_slug": slug,
                    "station_name": station.get("name_ar"),
                    "catalog_stream_type": station.get("stream_type"),
                    "policy_allowed": policy.get("allowed"),
                    "policy_stream_type": policy.get("stream_type"),
                    "policy_verified_at": policy.get("verified_at"),
                    **result,
                }
                attempts.append(evidence)
                print(json.dumps(evidence, ensure_ascii=False), flush=True)
                if result.get("passed"):
                    report = {
                        "status": "PASS",
                        "selected": evidence,
                        "attempts": attempts,
                        "offline_playback_evidence": "ffprobe consumed only the local captured file",
                        "verified_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                    }
                    (OUT / "offline-clip-real-smoke.json").write_text(
                        json.dumps(report, ensure_ascii=False, indent=2),
                        encoding="utf-8",
                    )
                    print("OFFLINE CLIP REAL CAPTURE -> LOCAL FILE PASS")
                    return
        report = {
            "status": "FAIL",
            "attempts": attempts,
            "verified_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
        (OUT / "offline-clip-real-smoke.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        raise RuntimeError("No rights-permitted stream produced a valid local audio clip")


if __name__ == "__main__":
    main()
