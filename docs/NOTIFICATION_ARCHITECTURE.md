# Notification Architecture & Dispatching — Quran Yutla (قرآن يتلى)

## 1. Single Device Test vs. Broadcast Campaign
- The Next.js Admin interface and Supabase `notifications` Edge Function support:
  - **Single Device Test (`targetType = 'device'`)**: Delivers only to a specific `testInstallationId` for developer verification.
  - **Broadcast Campaign (`targetType = 'all'`)**: Targets active consent installations with revocable tokens.

## 2. Route Allow-List
All notifications must point to an allow-listed destination (`/`, `/radio`, `/quran`, `/reciters`, `/library`, `/adhkar`, `/prayer-times`, `/settings`, or `/quran/surah/[1-114]`).
