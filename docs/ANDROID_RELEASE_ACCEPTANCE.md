# Android Release Acceptance & Quality Checklist

## 1. Application Identity
- **App Name (Arabic)**: قرآن يتلى
- **App Name (English)**: Quran Yutla
- **Application ID**: `com.aistudio.quranyutla.live`
- **Minimum SDK**: 24 (Android 7.0 Nougat)
- **Target SDK**: 34 (Android 14)
- **Primary Architecture**: ARM64-v8a, armeabi-v7a, x86_64

## 2. Audio & Background Services Acceptance
- [x] Background playback continues when the screen is turned off.
- [x] Media notification displays current Surah and reciter with interactive Play, Pause, and Skip buttons.
- [x] Audio focus cleanly yields when receiving telephone calls or navigating navigation alerts.
- [x] Mini-player seamlessly transitions to full-screen player bottom sheet.

## 3. Quran Integrity & Storage
- [x] Canonical 114 Surahs dataset embedded locally with verified SHA-256 hash.
- [x] Offline audio downloads stream directly to disk without loading entire files into memory.
- [x] Fail-Closed verification prevents reading altered text files.

## 4. Privacy & Hardware Access
- [x] Zero background location tracking; prayer times calculated offline locally.
- [x] Notification permission follows Android 13+ runtime permission lifecycle.
- [x] Zero advertising SDKs, tracking pixels, or third-party telemetry analytics.
