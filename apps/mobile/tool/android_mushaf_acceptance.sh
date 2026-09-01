#!/usr/bin/env bash
set -euo pipefail

apk=${1:?release APK path is required}
evidence_dir=${2:?evidence directory is required}
package=app.tarteel.tarteel

mkdir -p "$evidence_dir"
adb install -r "$apk"
adb shell am force-stop "$package"
adb shell monkey -p "$package" -c android.intent.category.LAUNCHER 1

dump_ui() {
  adb shell uiautomator dump /sdcard/tarteel-window.xml >/dev/null
  adb pull /sdcard/tarteel-window.xml "$evidence_dir/window.xml" >/dev/null
}

wait_for() {
  local expected=$1
  for _ in $(seq 1 90); do
    dump_ui
    if grep -q "$expected" "$evidence_dir/window.xml"; then
      return 0
    fi
    sleep 2
  done
  echo "UI text/description was not found: $expected" >&2
  cat "$evidence_dir/window.xml" >&2
  return 1
}

tap_text() {
  local expected=$1
  dump_ui
  local point
  point=$(python3 - "$evidence_dir/window.xml" "$expected" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
expected = sys.argv[2]
for node in root.iter("node"):
    if expected in (node.attrib.get("text", ""), node.attrib.get("content-desc", "")):
        values = [int(value) for value in re.findall(r"\d+", node.attrib["bounds"])]
        print((values[0] + values[2]) // 2, (values[1] + values[3]) // 2)
        break
else:
    raise SystemExit(f"node not found: {expected}")
PY
  )
  adb shell input tap $point
}

wait_for "المصحف"
tap_text "المصحف"
wait_for "صفحة مصحف المدينة 1"
adb exec-out screencap -p > "$evidence_dir/mushaf-hafs-svg-page-001.png"

tap_text "تجويد"
wait_for "صفحة مصحف التجويد 1"
adb exec-out screencap -p > "$evidence_dir/mushaf-tajweed-webp-page-001.png"

test -s "$evidence_dir/mushaf-hafs-svg-page-001.png"
test -s "$evidence_dir/mushaf-tajweed-webp-page-001.png"
sha256sum "$evidence_dir"/mushaf-*-page-001.png \
  > "$evidence_dir/MUSHAF-SCREENSHOT-SHA256SUMS.txt"

metadata="$evidence_dir/release-metadata.json"
if [[ -f "$metadata" ]]; then
  jq '.android8EmulatorMushafPageTest = "PASS"' "$metadata" \
    > "$metadata.updated"
  mv "$metadata.updated" "$metadata"
fi

echo "ANDROID_8_EMULATOR_MUSHAF_SVG_WEBP: PASS"
