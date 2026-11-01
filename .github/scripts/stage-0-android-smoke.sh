#!/usr/bin/env bash
set -euo pipefail
package=app.tarteel.tarteel
output="native-evidence/api-${ANDROID_API_LEVEL}"
mkdir -p "$output"
adb install -r validation/build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -W -n "$package/.MainActivity" | tee "$output/launch.txt"
sleep 25
# Cold JIT startup can outlast am's fixed wait; confirm the now-rendered activity.
adb shell am start -W -n "$package/.MainActivity" | tee "$output/launch-confirmed.txt"
app_pid="$(adb shell pidof "$package" | tr -d '\r')"
test -n "$app_pid"
adb logcat -d --pid="$app_pid" > "$output/logcat.txt"
adb shell dumpsys activity activities > "$output/activity.txt"
adb exec-out screencap -p > "$output/home.png"
adb shell dumpsys package "$package" > "$output/package.txt"
python3 - "$output" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
launch=(p/'launch-confirmed.txt').read_text()
logs=(p/'logcat.txt').read_text()
assert 'Status: ok' in launch, launch
assert 'FATAL EXCEPTION' not in logs, logs
assert 'Unhandled Exception' not in logs, logs
assert 'app.tarteel.tarteel' in (p/'activity.txt').read_text()
assert (p/'home.png').stat().st_size > 1000
print('Native install and launch smoke check passed; no live-audio or TalkBack certification implied.')
PY
