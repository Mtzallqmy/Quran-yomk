#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -d android || ! -d ios ]]; then
  flutter create . --platforms=android,ios --project-name tarteel --org app.tarteel
fi

python3 - <<'PY'
from pathlib import Path
import re

gradle = Path('android/app/build.gradle.kts')
text = gradle.read_text()
text, count = re.subn(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 26', text)
if count != 1 and 'minSdk = 26' not in text:
    raise SystemExit('Could not enforce Android minSdk = 26')
gradle.write_text(text)

manifest = Path('android/app/src/main/AndroidManifest.xml')
manifest.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    <application
        android:label="ترتيل"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="false">
        <activity
            android:name="com.ryanheise.audioservice.AudioServiceActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        <service
            android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true"
            tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver
            android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true"
            tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
        <meta-data android:name="flutterEmbedding" android:value="2" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT" />
            <data android:mimeType="text/plain" />
        </intent>
    </queries>
</manifest>
''')
PY

grep -q 'minSdk = 26' android/app/build.gradle.kts
grep -q 'FOREGROUND_SERVICE_MEDIA_PLAYBACK' android/app/src/main/AndroidManifest.xml
grep -q 'android:usesCleartextTraffic="false"' android/app/src/main/AndroidManifest.xml
grep -q 'AudioServiceActivity' android/app/src/main/AndroidManifest.xml

# Phase 11 acceptance probes real upstream/provider streams centrally in CI.
# Listener devices never probe the provider catalog themselves.
if [[ "${CI:-}" == "true" ]]; then
  if ! command -v ffprobe >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends ffmpeg curl
  fi
  python3 tool/external_radio_ci.py
  python3 tool/phase11_api_e2e.py
fi
