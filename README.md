# EZ2 Lotto

**EZ2 Lotto** is a Flutter application that provides real-time result tracking, historical archives, statistical insights, and ticket checking for the Philippine EZ2 (2D Lotto) game.

**Version:** `1.0.2`

---

## 🚀 Key Features

- **Live draw results (2PM / 5PM / 9PM)** with real-time updates via Supabase Realtime.
- **Historical results** browsable by year and month, including per-draw winners.
- **Statistics & insights** — hot/cold numbers, most drawn pairs, winner charts, and draw analysis.
- **Ticket checker** with:
  - Camera / gallery OCR support via Supabase Edge Function (`read-ticket`)
  - Manual input mode with date and draw-slot filters
  - Prize calculation (Straight / Rambolito)
- **Offline support** — local cache via `SharedPreferences` for fast startup and intermittent network handling.
- **Dark mode & language toggle** (English / Filipino) persisted across sessions.
- **In-app update checker** — checks `app_versions` table in Supabase for the latest APK version.
- **Security guard** — blocks launch on rooted/jailbroken devices or with Developer Options enabled.

---

## 🧭 App Screens

| Tab | Label | What it shows |
| --- | ----- | ------------- |
| **Results** | `TodayScreen` | Today's live results, latest draw, and draw status (LIVE / SOON / CLOSED). |
| **History** | `HistoryScreen` | Year/month-based historical results view (2PM / 5PM / 9PM). |
| **Statistics** | `StatsScreen` | Hot/cold numbers, most frequent combos, winner chart, and draw statistics. |
| **Ticket** | `TicketScreen` | Scan or manually enter your ticket numbers to check for a win. |
| **Settings** | `SettingsScreen` | Dark mode, language, update checker, app sharing, and admin tools. |

---

## 🧩 Architecture Overview

- **Flutter (Dart)** UI with Material 3 styling (light & dark themes).
- **State management** via `Provider`:
  - `AppProvider` — manages today's results, history, offline status, and year/month navigation.
  - `AppLocale` — manages dark mode and language (English/Filipino) preferences.
- **Backend & Realtime** via **Supabase** (`supabase_flutter`):
  - `ez2_results` table holds draw history.
  - `app_versions` table holds APK version info and download URLs.
  - Realtime subscriptions keep the Results view updated live.
  - Edge functions power ticket OCR and trigger result scraping.
- **Caching layer** (`CacheService`) stores results locally in `SharedPreferences` for fast startup and offline use.
- **Connectivity monitoring** (`ConnectivityService`) detects network state and shows an offline banner.
- **Security** (`flutter_jailbreak_detection`) blocks the app on rooted/jailbroken devices in release mode.

---

## 🛠️ Setup & Run

### Requirements

- Flutter SDK (>= 3.0, Dart SDK `>=3.0.0 <4.0.0`)
- A device/emulator (Android / iOS / Web)

### Run locally

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://votvvysgaiaycmbgeayh.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your_anon_key>
```

> ✅ The app has DEV-only fallback values in `lib/constants.dart`. **Remove them before distributing a production build.**

### Release build

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

---

## 🔧 Configuration

### Supabase

Credentials are injected at build time via `--dart-define`. See `lib/constants.dart`:

| Constant | `--dart-define` key |
| -------- | ------------------- |
| `kSupabaseUrl` | `SUPABASE_URL` |
| `kSupabaseAnonKey` | `SUPABASE_ANON_KEY` |

If you want to use your own Supabase instance, update those values and ensure your database has the following:

**`ez2_results` table**

| Column | Type | Example |
| ------ | ---- | ------- |
| `draw_date` | date | `2026-06-25` |
| `draw_slot` | text | `2pm`, `5pm`, `9pm` |
| `combo` | text | `06-19` |
| `winners` | integer | `12` |

**`app_versions` table** *(optional — powers in-app update checks)*

| Column | Type |
| ------ | ---- |
| `version` | text |
| `download_url` | text |
| `created_at` | timestamptz |

### Supabase Edge Functions

The app calls two edge functions:

| Function | Purpose |
| -------- | ------- |
| `fetch-today` | Scrapes `pwedeh.com` / `lottopcso.com` and upserts EZ2 results for a given date. |
| `read-ticket` | OCR — extracts ticket numbers from an uploaded image. |

If you fork this project, ensure those functions exist in your Supabase project or adjust the calls in `lib/api_service.dart`.

---

## 🧠 Data & Business Logic

- **Draw windows** (Philippine Time, UTC+8):
  - 2:00 PM – 2:35 PM
  - 5:00 PM – 5:35 PM
  - 9:00 PM – 9:35 PM
- The app auto-refreshes more frequently during draw windows.
- History is grouped by year and month; caching reduces network load and speeds up navigation.
- The offline banner is shown whenever `ConnectivityService` detects no internet.
- The `fetch-today` edge function uses exponential-backoff retries and parallel URL fetching for resilience.

---

## 🔒 Security

- **Jailbreak / root detection** — the app checks for jailbroken/rooted devices and enabled Developer Options at startup (release mode only). If detected, a `SecurityWarningScreen` is shown and the app is blocked.
- **Credential injection** — Supabase credentials are passed via `--dart-define` at build time, never hardcoded in production builds.
- **APK service** — uses the Supabase Flutter SDK exclusively (no raw HTTP calls with the anon key exposed in headers).

---

## 📦 Key Dependencies

| Package | Purpose |
| ------- | ------- |
| `supabase_flutter` | Backend, realtime, and edge functions |
| `provider` | State management |
| `shared_preferences` | Local caching and settings persistence |
| `image_picker` | Camera / gallery access for ticket OCR |
| `connectivity_plus` | Network state monitoring |
| `shimmer` | Loading skeleton animations |
| `intl` | Date formatting |
| `flutter_jailbreak_detection` | Root/jailbreak device guard |
| `flutter_launcher_icons` | Custom app icon generation |
| `flutter_native_splash` | Native splash screen generation |

---

## ✅ Credits

**EZ2 Lotto** was created by **Mark Spencer D. Montalbo**.

© 2026 Mark Spencer D. Montalbo. All rights reserved.

---

## 📄 License

This repository does not include a license file by default. Add a `LICENSE` file if you want to clarify usage terms.
