# EZ2 Lotto

**EZ2 Lotto** is a Flutter application that provides real-time result tracking, historical archives, statistical insights, and ticket checking for the Philippine EZ2 (2D Lotto) game.

**Version:** `1.0.1`

## 🚀 Key Features

- **Live draw results (2PM / 5PM / 9PM)** with real-time updates via Supabase Realtime.
- **Historical results** for the current and previous months, including per-draw winners.
- **Statistics & insights** (hot/cold numbers, most drawn pairs, winner charts).
- **Ticket checker** with:
  - camera/gallery OCR support via Supabase Edge Function
  - manual input mode with date/draw filters
  - prize calculation (Straight / Rambolito)
- **Offline support** via local cache for fast startup and intermittent network.

## 🧭 App Screens

| Tab | What it shows |
| --- | --- |
| **Resulta** | Today's live results, latest draw, and draw status (LIVE / SOON / CLOSED). |
| **Kasaysayan** | Month-based historical results view (2PM/5PM/9PM). |
| **Istatistika** | Hot/cold numbers, most frequent combos, winner chart, and draw statistics. |
| **Tiket** | Scan ticket or type your numbers to see if you won. |

---

## 🧩 Architecture Overview

- **Flutter (Dart)** UI with Material 3 styling.
- **State management** via `Provider` (`AppProvider`).
- **Backend & Realtime** via **Supabase** (`supabase_flutter`):
  - `ez2_results` table holds draw history.
  - Realtime subscriptions keep Today view updated.
  - Edge functions power ticket OCR and trigger result fetching.
- **Caching layer** (`CacheService`) stores results locally for fast startup and offline use.

---

## 🛠️ Setup & Run

### Requirements

- Flutter SDK (>= 3.0)
- Dart SDK
- A device/emulator (Android/iOS/web)

### Run locally

```bash
flutter pub get
flutter run
```

> ✅ The app is preconfigured to use the public Supabase project (see `lib/constants.dart`).

---

## 🔧 Configuration

### Supabase

The app connects to Supabase using the constants found in `lib/constants.dart`:

- `kSupabaseUrl`
- `kSupabaseAnonKey`

If you want to point to your own Supabase instance, update these values and ensure your database has an `ez2_results` table with the following columns:

- `draw_date` (date)
- `draw_slot` (text, e.g., `2pm`, `5pm`, `9pm`)
- `combo` (text, e.g., `06-19`)
- `winners` (integer)

### Supabase Edge Functions

The app calls two edge functions:

- `fetch-today` (triggers a scrape / update for today’s results)
- `read-ticket` (OCR extraction of ticket numbers from an image)

If you fork this project, ensure those functions exist in your Supabase project or adjust the API calls in `lib/api_service.dart`.

---

## 🧠 Data & Business Logic Notes

- **Draw windows** are considered:
  - 2:00 PM – 2:35 PM
  - 5:00 PM – 5:35 PM
  - 9:00 PM – 9:35 PM
- The app auto-refreshes more frequently during draw windows.
- History is grouped by month; caching reduces load and speeds up navigation.

---

## ✅ Credit

**EZ2 Lotto** was created by **Mark Spencer D. Montalbo**.

©2026 Mark Spencer D. Montalbo. All rights reserved.

---

## 📄 License

This repository does not include a license file by default. Add a `LICENSE` file if you want to clarify usage terms.
