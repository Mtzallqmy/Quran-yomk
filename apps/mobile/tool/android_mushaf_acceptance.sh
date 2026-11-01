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
    text = node.attrib.get("text", "")
    desc = node.attrib.get("content-desc", "")
    if expected in text or expected in desc:
        values = [int(value) for value in re.findall(r"\d+", node.attrib["bounds"])]
        if len(values) == 4:
            print((values[0] + values[2]) // 2, (values[1] + values[3]) // 2)
            break
else:
    raise SystemExit(f"node not found: {expected}")
PY
  )
  adb shell input tap $point
}

# Find a visible node by exact-or-substring match, then tap it. This avoids
# depending on how Flutter merges SegmentedButton semantics on Android 8.
tap_matching_node() {
  local expected=$1
  dump_ui
  local point
  point=$(python3 - "$evidence_dir/window.xml" "$expected" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
expected = sys.argv[2]
candidates = []
for node in root.iter("node"):
    text = node.attrib.get("text", "")
    desc = node.attrib.get("content-desc", "")
    haystack = f"{text} {desc}"
    if expected not in haystack:
        continue
    values = [int(value) for value in re.findall(r"\d+", node.attrib.get("bounds", ""))]
    if len(values) != 4:
        continue
    x1, y1, x2, y2 = values
    if x2 <= x1 or y2 <= y1:
        continue
    candidates.append(((x2-x1)*(y2-y1), (x1+x2)//2, (y1+y2)//2, text, desc))
if not candidates:
    raise SystemExit(f"node not found: {expected}")
# Prefer the smallest matching actionable semantic region; parent merged nodes
# are typically much larger than the actual segment.
candidates.sort(key=lambda item: item[0])
_, x, y, _, _ = candidates[0]
print(x, y)
PY
  )
  adb shell input tap $point
}

wait_for "المصحف"
tap_text "المصحف"
wait_for "صفحة مصحف المدينة 1"
adb exec-out screencap -p > "$evidence_dir/mushaf-hafs-svg-page-001.png"

# The reader controls auto-hide. A page tap always restores the overlay (or
# selects an ayah, which also restores it). Then select the Tajweed segment by
# its merged Android accessibility semantics rather than exact text equality.
adb shell input tap 540 960
sleep 1
tap_matching_node "تجويد"
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
