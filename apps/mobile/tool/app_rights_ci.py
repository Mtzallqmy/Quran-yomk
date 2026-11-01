#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
API_DART = ROOT / "apps/mobile/lib/src/api.dart"
AR = ROOT / "apps/mobile/lib/l10n/app_ar.arb"
OUT = ROOT / "apps/mobile/release/app-rights"
OUT.mkdir(parents=True, exist_ok=True)

source = API_DART.read_text(encoding="utf-8")
base_match = re.search(r"productionBaseUrl\s*=\s*\n?\s*'([^']+)'", source)
key_match = re.search(r"defaultValue:\s*'([^']+)'", source)
if not base_match or not key_match:
    raise SystemExit("Could not resolve Flutter public API configuration")
base = base_match.group(1).rstrip("/")
key = key_match.group(1)

req = urllib.request.Request(
    f"{base}/content-sources",
    headers={"accept": "application/json", "apikey": key, "user-agent": "TarteelRightsAcceptance/1.0"},
)
with urllib.request.urlopen(req, timeout=15) as response:
    payload = json.loads(response.read().decode("utf-8"))
sources = payload.get("data") or []
providers = {str(item.get("provider") or "") for item in sources}
required = {"mp3quran", "qurango", "islamic-app"}
missing = sorted(required - providers)
if missing:
    raise RuntimeError("Missing required live content sources: " + ", ".join(missing))

strings = json.loads(AR.read_text(encoding="utf-8"))
expected = {
    "appRights": "حقوق التطبيق",
    "appRightsLine1": "ترتيل — Tarteel",
    "appRightsLine2": "تطوير وملكية: معتز العلقمي",
    "appRightsLine3": "تعز، اليمن",
    "appRightsLine4": "© 2026 معتز العلقمي. جميع حقوق التطبيق محفوظة.",
    "thirdPartyRights": "مصادر المحتوى وحقوق الجهات الخارجية",
}
for key_name, expected_value in expected.items():
    if strings.get(key_name) != expected_value:
        raise RuntimeError(f"App rights text mismatch for {key_name}")

report = {
    "status": "PASS",
    "required_providers": sorted(required),
    "providers_returned": sorted(providers),
    "source_count": len(sources),
    "app_rights_copy": expected,
}
(OUT / "app-rights-live.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2),
    encoding="utf-8",
)
print(f"APP RIGHTS + LIVE CONTENT SOURCES PASS ({len(sources)} sources)")
