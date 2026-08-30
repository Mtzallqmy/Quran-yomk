# Tarteel Mobile

Flutter listener MVP for ترتيل / Tarteel.

## Architecture

Flutter consumes the Phase 7 Backend API only. It never contains Supabase service-role credentials, Icecast administration credentials, Radio Engine controls, or privileged database access.

The API base URL is supplied at build/run time:

```bash
flutter run --dart-define=TARTEEL_API_BASE_URL=https://your-development-api.example/api/v1
flutter build apk --release --dart-define=TARTEEL_API_BASE_URL=https://your-approved-api.example/api/v1
```

If the define is omitted, the app uses the reserved non-routable `https://api.tarteel.invalid/api/v1` and displays safe connectivity errors instead of falling back to direct database access.

Android platform files are generated from the pinned/current stable Flutter toolchain by `tool/bootstrap_platforms.sh`; the script enforces `minSdk = 26`, release Internet access, audio foreground-service declarations, and iOS background-audio mode. The Android application id remains provisional until owner approval for store identity.
