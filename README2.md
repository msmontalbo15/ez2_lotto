# Flowchart Explanation for fetch-today/index.ts

This document explains the flowchart of the Supabase Edge Function located at `supabase/functions/fetch-today/index.ts`.

## Overview

This Edge Function scrapes pwedeh.com for EZ2 lottery results and stores them in a Supabase database. It runs on cron during draw windows (2pm, 5pm, 9pm Philippine Time).

## Flowchart

```mermaid
flowchart TD
    A[HTTP Request] --> B{OPTIONS?}
    B -->|Yes| C[Return CORS Response]
    B -->|No| D{POST Method?}
    D -->|No| E[Return 405]
    D -->|Yes| F[Initialize Supabase]
    F --> G[Calculate PHT UTC+8]
    G --> H[Fetch Existing Results]
    H --> I{DB Error?}
    I -->|Yes| J[Return 500]
    I -->|No| K[Build Lookup Map]
    K --> L[Check What Slots Need Data]
    L --> M{All Complete & Outside Window?}
    M -->|Yes| N[Return: Already Complete]
    M -->|No| O[Build 3 URLs]
    O --> P[Parallel Fetch with Retry]
    P --> Q{Success?}
    Q -->|No| R[Empty HTML]
    Q -->|Yes| S[Use Valid Response]
    R --> T[Scraped = {}]
    S --> T
    T --> U[Parse Combos]
    U --> V[Parse Winners 3 Patterns]
    V --> W[Loop Slots]
    W --> X{Has Combo?}
    X -->|No| Y[Skip]
    X -->|Yes| Z{DB Row Exists?}
    Z -->|No| AA[Insert New]
    Z -->|Yes| BB{Winners Null?}
    BB -->|Yes| CC[Update Winners]
    BB -->|No| DD{Combo Changed?}
    DD -->|Yes| EE[Upsert Correction]
    DD -->|No| FF[Skip]
    AA --> GG[Add to Saved]
    CC --> GG
    EE --> GG
    Y --> HH
    GG --> HH{Next Slot?}
    HH -->|Yes| W
    HH -->|No| II[Log Activity]
    II --> JJ[Return JSON]
```

## Detailed Explanation

### 1. Request Handling

- **CORS Preflight** (line 104): Handles `OPTIONS` requests by returning appropriate CORS headers
- **Method Validation** (line 109): Only accepts `POST` method (intended for cron jobs)

### 2. Time Calculation

- Converts current time to **Philippine Time (UTC+8)** using `phMinOfDay` (line 126)
- Determines if current time is within draw windows:
  - **2pm**: 840-875 minutes
  - **5pm**: 1020-1055 minutes
  - **9pm**: 1260-1295 minutes

### 3. Database Operations

- Fetches existing results for today from `ez2_results` table (line 131)
- Builds a lookup map to track which slots have combo/winners data
- Determines what data is still needed using `needsCombo` and `needsWinners` (lines 148-149)

### 4. Web Scraping

Constructs URLs for three sources:
1. `pwedeh.com/2d-lotto-result-today-{date}`
2. `pwedeh.com/2d-results-today/`
3. `lottopcso.com/2d-ez2-lotto-results-today-{date}`

- Uses exponential backoff retry logic (3 attempts)
- Parallel fetching with `Promise.all` for speed

### 5. HTML Parsing

**Combos**: Uses `REGEX.row` (line 23) to find time + combo pairs

**Winners**: Tries three regex patterns:
- `winnersA` (line 26): Matches "2:00 PM ... 123 winner(s)"
- `winnersB` (line 29): Matches "winner(s): 123" or "winners: 123"
- `winnersC` (line 32): Matches table column format `<td>time</td><td>combo</td><td>winners</td>`

### 6. Database Save Logic

Four cases handled for each slot:

| Case | Condition | Action | Code Line |
|------|-----------|--------|-----------|
| **New** | Slot not in DB | Insert new record | 251 |
| **Update Winners** | Combo exists, winners is null | Update winners only | 273 |
| **Correction** | Combo changed (re-draw) | Upsert corrected data | 291 |
| **No Change** | Everything matches | Skip | 310 |

### 7. Logging

- Records fetch activity to `ez2_fetch_log` table (line 315)
- Tracks status (`success` or `no_change`), draws found, and notes

## Optimization Features

1. **Early Exit**: Skips scraping if all data exists AND outside draw window (line 152)
2. **Parallel Fetching**: Multiple URLs tried simultaneously
3. **Retry with Backoff**: Handles transient network failures
4. **Selective Updates**: Only updates what's missing

## Helper Functions

| Function | Purpose | Line |
|----------|---------|------|
| `normalizeCombo()` | Converts combo to standard format (e.g., "1-2" → "01-02") | 44 |
| `isInDrawWindow()` | Checks if current time is within any draw window | 58 |
| `getSlotFromTime()` | Maps time string to draw slot | 67 |
| `parseWinners()` | Parses winners count from regex match | 78 |
| `corsResponse()` | Creates CORS-enabled JSON response | 86 |

## Constants

- `DRAW_SLOTS`: Draw windows in PHT
- `REGEX`: Pre-compiled regex patterns for better performance
- `MONTH_NAMES`: Array of month names for URL construction
