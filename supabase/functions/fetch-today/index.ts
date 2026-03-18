// supabase/functions/fetch-today/index.ts
// Scrapes pwedeh.com for EZ2 results + winners. Runs on cron during draw windows.
// Optimized based on cron_setup.sql requirements

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// =============================================================================
// Constants & Pre-compiled Regex Patterns
// =============================================================================

// Draw windows in PHT (Philippine Time): at draw time → 35 min after
// 2PM PHT = 840 min, 5PM PHT = 1020 min, 9PM PHT = 1260 min
const DRAW_SLOTS = {
  "2pm": { start: 840, end: 875 },
  "5pm": { start: 1020, end: 1055 },
  "9pm": { start: 1260, end: 1295 },
} as const;

// Scheduled fetch times: 20, 25, 30 minutes after draw (3 jobs per draw)
const SCHEDULED_FETCH_SLOTS = {
  "2pm": { start: 860, end: 870 }, // 2:20 PM – 2:30 PM
  "5pm": { start: 1040, end: 1050 }, // 5:20 PM – 5:30 PM
  "9pm": { start: 1280, end: 1290 }, // 9:20 PM – 9:30 PM
} as const;

// Pre-compiled regex patterns for better performance
const REGEX = {
  // Match row with time and combo: <tr>...<td>2:00 PM</td><td>01-02</td>...
  row: /<tr[^>]*>[\s\S]*?(\d{1,2}:\d{2}\s*(?:AM|PM))[\s\S]*?<\/td>[\s\S]*?<td[^>]*>([\d]{1,2}[\s\-–][\d]{1,2})<\/td>/gi,
  
  // Match winners: "2:00 PM ... 123 winner(s)"
  winnersA: /(\d{1,2}:\d{2}\s*(?:AM|PM))[\s\S]{0,500}?(\d[\d,]+)\s*winner/gi,
  
  // Match winners: "winner(s): 123" or "winners: 123"
  winnersB: /(\d{1,2}:\d{2}\s*(?:AM|PM))[\s\S]{0,500}?winners?\s*:?\s*(\d[\d,]+)/gi,
  
  // Match winners in table column: <td>2:00 PM</td><td>01-02</td><td>123</td>
  winnersC: /<td[^>]*>\s*(\d{1,2}:\d{2}\s*(?:AM|PM))\s*<\/td>\s*<td[^>]*>[\d\-]+<\/td>\s*<td[^>]*>\s*(\d[\d,]*)\s*<\/td>/gi,
} as const;

const MONTH_NAMES = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"];

// =============================================================================
// Helper Functions
// =============================================================================

/**
 * Normalize combo string to standard format (e.g., "1-2" → "01-02")
 */
function normalizeCombo(raw: string): string | null {
  const parts = raw.split("-");
  if (parts.length !== 2) return null;
  
  const n1 = parseInt(parts[0].trim(), 10);
  const n2 = parseInt(parts[1].trim(), 10);
  
  if (isNaN(n1) || isNaN(n2) || n1 < 1 || n1 > 31 || n2 < 1 || n2 > 31) return null;
  return `${String(n1).padStart(2, "0")}-${String(n2).padStart(2, "0")}`;
}

/**
 * Check if current time is within any draw window
 */
function isInDrawWindow(phMinOfDay: number): boolean {
  return Object.values(DRAW_SLOTS).some(
    slot => phMinOfDay >= slot.start && phMinOfDay <= slot.end
  );
}

/**
 * Check if current time is within scheduled fetch window (20, 25, 30 min after draw)
 * Returns the draw slot if within scheduled window, null otherwise
 */
function getScheduledFetchSlot(phMinOfDay: number): string | null {
  if (phMinOfDay >= SCHEDULED_FETCH_SLOTS["2pm"].start && phMinOfDay <= SCHEDULED_FETCH_SLOTS["2pm"].end) {
    return "2pm";
  }
  if (phMinOfDay >= SCHEDULED_FETCH_SLOTS["5pm"].start && phMinOfDay <= SCHEDULED_FETCH_SLOTS["5pm"].end) {
    return "5pm";
  }
  if (phMinOfDay >= SCHEDULED_FETCH_SLOTS["9pm"].start && phMinOfDay <= SCHEDULED_FETCH_SLOTS["9pm"].end) {
    return "9pm";
  }
  return null;
}

/**
 * Map time string to draw slot
 */
function getSlotFromTime(time: string): string | null {
  const t = time.trim().toUpperCase();
  if (t.startsWith("2:00")) return "2pm";
  if (t.startsWith("5:00")) return "5pm";
  if (t.startsWith("9:00")) return "9pm";
  return null;
}

/**
 * Parse winners from match result
 */
function parseWinners(match: RegExpExecArray): number | null {
  const winners = parseInt(match[2].replace(/,/g, ""), 10);
  return isNaN(winners) || winners < 0 ? null : winners;
}

/**
 * Create CORS response
 */
function corsResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Authorization, Content-Type",
    },
  });
}

// =============================================================================
// Main Handler
// =============================================================================

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return corsResponse({ message: "OK" });
  }

  // Only allow POST method (cron calls)
  if (req.method !== "POST") {
    return corsResponse({ error: "Method not allowed" }, 405);
  }

  try {
    // Initialize Supabase client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Calculate Philippine Time (UTC+8)
    const now = new Date();
    const phMs = now.getTime() + 8 * 60 * 60 * 1000;
    const ph = new Date(phMs);
    
    const iso = `${ph.getUTCFullYear()}-${String(ph.getUTCMonth() + 1).padStart(2, "0")}-${String(ph.getUTCDate()).padStart(2, "0")}`;
    const phMinOfDay = ph.getUTCHours() * 60 + ph.getUTCMinutes();
    const inWindow = isInDrawWindow(phMinOfDay);

    // ── Fetch existing data from DB ────────────────────────────────────────
    const { data: existing, error: fetchError } = await supabase
      .from("ez2_results")
      .select("draw_slot, combo, winners")
      .eq("draw_date", iso);

    if (fetchError) {
      console.error("[fetch-today] DB fetch error:", fetchError.message);
      return corsResponse({ error: "Database error", details: fetchError.message }, 500);
    }

    // Build lookup map for existing data
    const db = new Map<string, { combo: string | null; winners: number | null }>();
    (existing ?? []).forEach((r) => {
      db.set(r.draw_slot, { combo: r.combo, winners: r.winners });
    });

    // Determine which slots need work
    const slots = ["2pm", "5pm", "9pm"] as const;
    
    // Check if we're in a scheduled fetch window (20, 25, 30 min after draw)
    const scheduledSlot = getScheduledFetchSlot(phMinOfDay);
    
    // During scheduled fetch windows: only fetch for that specific slot
    // Outside scheduled windows: fetch for all missing slots (fallback)
    let needsCombo: readonly string[];
    if (scheduledSlot) {
      // Only check the scheduled slot during 20, 25, 30 min after draw
      needsCombo = !db.get(scheduledSlot)?.combo ? [scheduledSlot] : [];
    } else {
      // Fallback: check all slots (for missed schedules or corrections)
      needsCombo = slots.filter(s => !db.get(s)?.combo);
    }
    
    // Winners: only fetch after end of day (after 9:35 PM PHT = 1295 minutes)
    const isEndOfDay = phMinOfDay > 1295;
    const needsWinners = isEndOfDay 
      ? slots.filter(s => db.get(s)?.combo && db.get(s)?.winners == null)
      : []; // Don't fetch winners during draw window
    
    const nothingToDo = needsCombo.length === 0 && needsWinners.length === 0;

    // ── STOP FETCH if all combos already exist in database ────────────────────────
    if (needsCombo.length === 0) {
      console.log(`[fetch-today] ${iso}: All combos already exist in database, skipping fetch`);
      // Still check for winners if end of day
      if (needsWinners.length === 0) {
        return corsResponse({ 
          message: "Already complete - all combos exist", 
          date: iso, 
          inWindow,
          scheduledSlot,
          needsWinners: isEndOfDay ? [] : "waiting for end of day"
        });
      }
    }

    // Skip if nothing is missing AND outside draw window (optimization)
    if (nothingToDo && !inWindow) {
      console.log(`[fetch-today] ${iso}: Already complete, outside window`);
      return corsResponse({ message: "Already complete", date: iso, inWindow: false });
    }

    // ── Scrape pwedeh.com (parallel with fallback) ────────────────────────
    const yyyy = ph.getUTCFullYear();
    const monthName = MONTH_NAMES[ph.getUTCMonth()];
    const dayNum = ph.getUTCDate();
    
    const urls = [
      `https://www.lottopcso.com/2d-ez2-lotto-results-today-${monthName}-${dayNum}-${yyyy}-2pm-5pm-9pm-draw/`,
      `https://pwedeh.com/2d-lotto-result-today-${monthName}-${dayNum}-${yyyy}/`,
      `https://pwedeh.com/2d-results-today/`,
    ];

    // Parallel fetch with retry and backoff
    const fetchWithBackoff = async (url: string, retries = 3, baseDelay = 1000): Promise<string> => {
      for (let attempt = 0; attempt < retries; attempt++) {
        try {
          const res = await fetch(url, {
            headers: { 
              "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120" 
            },
            signal: AbortSignal.timeout(9000),
          });
          if (res.ok) {
            const text = await res.text();
            if (text.length > 500) return text;
          }
        } catch (e) {
          console.log(`[fetch-today] Attempt ${attempt + 1} failed for ${url}:`, e instanceof Error ? e.message : e);
        }
        // Exponential backoff
        if (attempt < retries - 1) {
          await new Promise(r => setTimeout(r, baseDelay * Math.pow(2, attempt)));
        }
      }
      return "";
    };

    // Execute all fetches in parallel
    const results = await Promise.all(urls.map(url => fetchWithBackoff(url)));
    
    // Scrape from ALL successful responses and merge results
    // (lottopcso.com has both combos and winners, pwedeh.com has combos only)
    type SlotData = { combo: string | null; winners: number | null };
    const scraped: Record<string, SlotData> = {};

    for (const html of results) {
      if (!html || html.length < 500) continue;
      
      // Parse combos
      let match: RegExpExecArray | null;
      REGEX.row.lastIndex = 0;
      while ((match = REGEX.row.exec(html)) !== null) {
        const slot = getSlotFromTime(match[1]);
        if (!slot) continue;
        
        const combo = normalizeCombo(match[2].trim().replace(/[\s–]/g, "-"));
        if (combo) {
          if (!scraped[slot]) {
            scraped[slot] = { combo, winners: null };
          } else if (!scraped[slot].combo) {
            scraped[slot].combo = combo;
          }
        }
      }

      // Parse winners (merge - keep first non-null value)
      const winnerPatterns = [REGEX.winnersA, REGEX.winnersB, REGEX.winnersC];
      for (const pattern of winnerPatterns) {
        pattern.lastIndex = 0;
        while ((match = pattern.exec(html)) !== null) {
          const slot = getSlotFromTime(match[1]);
          if (!slot) continue;
          if (!scraped[slot]) {
            scraped[slot] = { combo: null, winners: null };
          }
          const winners = parseWinners(match);
          if (winners !== null && scraped[slot].winners == null) {
            scraped[slot].winners = winners;
          }
        }
      }
    }

    console.log(`[fetch-today] ${iso}: inWindow=${inWindow}, scheduledSlot=${scheduledSlot}, isEndOfDay=${isEndOfDay}, needsCombo=${needsCombo}, needsWinners=${needsWinners}`);
    console.log(`[fetch-today] Scraped:`, JSON.stringify(scraped));

    // ── Save to DB ───────────────────────────────────────────────────────
    const saved: string[] = [];

    for (const slot of slots) {
      const s = scraped[slot];
      const dbRow = db.get(slot);

      // Skip if nothing scraped for this slot
      if (!s?.combo) continue;

      const winnersFinal = s.winners ?? dbRow?.winners ?? null;

      // Case 1: New combo (slot not in DB yet)
      if (!dbRow?.combo) {
        const parts = s.combo.split("-");
        const { error } = await supabase.from("ez2_results").upsert({
          draw_date: iso,
          draw_slot: slot,
          combo: s.combo,
          num1: parseInt(parts[0], 10),
          num2: parseInt(parts[1], 10),
          winners: winnersFinal,
          source: "pwedeh.com",
          fetched_at: new Date().toISOString(),
        }, { onConflict: "draw_date,draw_slot" });

        if (!error) {
          saved.push(slot);
          console.log(`[fetch-today] Inserted ${slot}: ${s.combo}, winners=${winnersFinal}`);
        } else {
          console.error(`[fetch-today] Insert error ${slot}:`, error.message);
        }
        continue;
      }

      // Case 2: Combo exists, winners still null — update winners only
      if (dbRow.combo && dbRow.winners == null && s.winners != null) {
        const { error } = await supabase
          .from("ez2_results")
          .update({ winners: s.winners, fetched_at: new Date().toISOString() })
          .eq("draw_date", iso)
          .eq("draw_slot", slot);

        if (!error) {
          saved.push(`${slot}(winners:${s.winners})`);
          console.log(`[fetch-today] Updated winners ${slot}: ${s.winners}`);
        } else {
          console.error(`[fetch-today] Update error ${slot}:`, error.message);
        }
        continue;
      }

      // Case 3: Combo changed (re-draw / correction)
      if (dbRow.combo !== s.combo) {
        const parts = s.combo.split("-");
        const { error } = await supabase.from("ez2_results").upsert({
          draw_date: iso,
          draw_slot: slot,
          combo: s.combo,
          num1: parseInt(parts[0], 10),
          num2: parseInt(parts[1], 10),
          winners: winnersFinal,
          source: "pwedeh.com",
          fetched_at: new Date().toISOString(),
        }, { onConflict: "draw_date,draw_slot" });

        if (!error) {
          saved.push(`${slot}(corrected)`);
          console.log(`[fetch-today] Corrected ${slot}: ${dbRow.combo} → ${s.combo}`);
        }
        continue;
      }

      // Case 4: Nothing changed
      console.log(`[fetch-today] No change for ${slot}`);
    }

    // ── Log fetch activity ────────────────────────────────────────────────
    const logStatus = saved.length > 0 ? "success" : "no_change";
    await supabase.from("ez2_fetch_log").upsert({
      fetch_date: iso,
      status: logStatus,
      draws_found: saved.length,
      notes: saved.length > 0 ? `Saved: ${saved.join(", ")}` : `Nothing new. scraped=${JSON.stringify(Object.keys(scraped))}`,
      fetched_at: new Date().toISOString(),
    }, { onConflict: "fetch_date" });

    return corsResponse({ 
      message: "OK", 
      date: iso, 
      inWindow, 
      scheduledSlot,
      saved, 
      scraped: Object.keys(scraped),
      db: Object.fromEntries(db)
    });

  } catch (error) {
    console.error("[fetch-today] Fatal error:", error);
    return corsResponse({ 
      error: "Internal server error", 
      message: error instanceof Error ? error.message : "Unknown error" 
    }, 500);
  }
});
