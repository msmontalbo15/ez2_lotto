// supabase/functions/fetch-today/index.ts
// Scrapes pwedeh.com for EZ2 results + winners. Runs on cron during draw windows.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (_req: Request) => {
  const supabase    = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const now         = new Date();
  const phMs        = now.getTime() + 8 * 60 * 60 * 1000;
  const ph          = new Date(phMs);
  const yyyy        = ph.getUTCFullYear();
  const mm          = String(ph.getUTCMonth() + 1).padStart(2, "0");
  const dd          = String(ph.getUTCDate()).padStart(2, "0");
  const iso         = `${yyyy}-${mm}-${dd}`;
  const phMinOfDay  = ph.getUTCHours() * 60 + ph.getUTCMinutes();

  // Draw windows: at draw time → 35 min after (sites publish within 5–30 min)
  // Start polling exactly at draw time, stop after 35 min to be safe
  const inWindow =
    (phMinOfDay >= 840  && phMinOfDay <= 875)  ||  // 2:00PM – 2:35PM
    (phMinOfDay >= 1020 && phMinOfDay <= 1055) ||  // 5:00PM – 5:35PM
    (phMinOfDay >= 1260 && phMinOfDay <= 1295);    // 9:00PM – 9:35PM

  // ── Check what's already in DB ─────────────────────────────
  const { data: existing } = await supabase
    .from("ez2_results")
    .select("draw_slot, combo, winners")
    .eq("draw_date", iso);

  const db = new Map<string, { combo: string | null; winners: number | null }>(
    (existing ?? []).map((r: any) => [r.draw_slot, { combo: r.combo, winners: r.winners }])
  );

  // Determine which slots still need work:
  // - Missing combo entirely, OR
  // - Has combo but winners is still null
  const needsCombo   = ["2pm","5pm","9pm"].filter(s => !db.get(s)?.combo);
  const needsWinners = ["2pm","5pm","9pm"].filter(s => db.get(s)?.combo && db.get(s)?.winners == null);
  const nothingToDo  = needsCombo.length === 0 && needsWinners.length === 0;

  // Skip ONLY if nothing is missing AND we're outside a draw window
  if (nothingToDo && !inWindow) {
    return Response.json({ message: "Already complete", date: iso, db: Object.fromEntries(db) });
  }

  // ── Scrape pwedeh.com ──────────────────────────────────────
  const monthNames = ["january","february","march","april","may","june","july","august","september","october","november","december"];
  const monthName  = monthNames[ph.getUTCMonth()];
  const dayNum     = ph.getUTCDate();

  let html = "";

  // 1. Specific date page (most reliable)
  const urls = [
    `https://pwedeh.com/2d-lotto-result-today-${monthName}-${dayNum}-${yyyy}/`,
    `https://pwedeh.com/2d-results-today/`,
  ];

  for (const url of urls) {
    try {
      const res = await fetch(url, {
        headers: { "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120" },
        signal: AbortSignal.timeout(9000),
      });
      if (res.ok) {
        const text = await res.text();
        if (text.length > 500) { html = text; break; }
      }
    } catch (_) {}
  }

  // 2. Fallback to lottopcso.com
  if (!html) {
    try {
      const url = `https://www.lottopcso.com/2d-ez2-lotto-results-today-${monthName}-${dayNum}-${yyyy}-2pm-5pm-9pm-draw/`;
      const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0" }, signal: AbortSignal.timeout(9000) });
      if (res.ok) html = await res.text();
    } catch (_) {}
  }

  // ── Parse combos + winners ─────────────────────────────────
  type SlotData = { combo: string | null; winners: number | null };
  const scraped: Record<string, SlotData> = {};

  if (html) {
    // ── Combo parsing ──────────────────────────────────────────
    // Pattern: draw time in one cell, number combination in next cell
    const rowPat = /<tr[^>]*>[\s\S]*?(\d{1,2}:\d{2}\s*(?:AM|PM))[\s\S]*?<\/td>[\s\S]*?<td[^>]*>([\d]{1,2}[\s\-–][\d]{1,2})<\/td>/gi;
    let m: RegExpExecArray | null;
    while ((m = rowPat.exec(html)) !== null) {
      const time  = m[1].trim().toUpperCase();
      const raw   = m[2].trim().replace(/[\s–]/, "-");
      const combo = normalizeCombo(raw);
      if (!combo) continue;
      if (time.startsWith("2:00")) scraped["2pm"] = { combo, winners: null };
      if (time.startsWith("5:00")) scraped["5pm"] = { combo, winners: null };
      if (time.startsWith("9:00")) scraped["9pm"] = { combo, winners: null };
    }

    // ── Winners parsing ────────────────────────────────────────
    // Multiple patterns to handle different page layouts

    // Pattern A: "2:00 PM ... 123 winner(s)" within 500 chars
    const winPatA = /(\d{1,2}:\d{2}\s*(?:AM|PM))[\s\S]{0,500}?(\d[\d,]+)\s*winner/gi;
    while ((m = winPatA.exec(html)) !== null) {
      const time    = m[1].trim().toUpperCase();
      const winners = parseInt(m[2].replace(/,/g, ""), 10);
      if (isNaN(winners) || winners < 0) continue;
      if (time.startsWith("2:00") && scraped["2pm"]) scraped["2pm"].winners = winners;
      if (time.startsWith("5:00") && scraped["5pm"]) scraped["5pm"].winners = winners;
      if (time.startsWith("9:00") && scraped["9pm"]) scraped["9pm"].winners = winners;
    }

    // Pattern B: "winner(s): 123" or "winners: 123"
    const winPatB = /(\d{1,2}:\d{2}\s*(?:AM|PM))[\s\S]{0,500}?winners?\s*:?\s*(\d[\d,]+)/gi;
    while ((m = winPatB.exec(html)) !== null) {
      const time    = m[1].trim().toUpperCase();
      const winners = parseInt(m[2].replace(/,/g, ""), 10);
      if (isNaN(winners) || winners < 0) continue;
      // Only fill if not already found by Pattern A
      if (time.startsWith("2:00") && scraped["2pm"] && scraped["2pm"].winners == null) scraped["2pm"].winners = winners;
      if (time.startsWith("5:00") && scraped["5pm"] && scraped["5pm"].winners == null) scraped["5pm"].winners = winners;
      if (time.startsWith("9:00") && scraped["9pm"] && scraped["9pm"].winners == null) scraped["9pm"].winners = winners;
    }

    // Pattern C: standalone "No. of Winners" table column
    // <td>2:00 PM</td><td>01-02</td><td>123</td>
    const winPatC = /<td[^>]*>\s*(\d{1,2}:\d{2}\s*(?:AM|PM))\s*<\/td>\s*<td[^>]*>[\d\-]+<\/td>\s*<td[^>]*>\s*(\d[\d,]*)\s*<\/td>/gi;
    while ((m = winPatC.exec(html)) !== null) {
      const time    = m[1].trim().toUpperCase();
      const winners = parseInt(m[2].replace(/,/g, ""), 10);
      if (isNaN(winners) || winners < 0) continue;
      if (time.startsWith("2:00") && scraped["2pm"] && scraped["2pm"].winners == null) scraped["2pm"].winners = winners;
      if (time.startsWith("5:00") && scraped["5pm"] && scraped["5pm"].winners == null) scraped["5pm"].winners = winners;
      if (time.startsWith("9:00") && scraped["9pm"] && scraped["9pm"].winners == null) scraped["9pm"].winners = winners;
    }
  }

  console.log(`[fetch-today] iso=${iso} inWindow=${inWindow} needsCombo=${needsCombo} needsWinners=${needsWinners}`);
  console.log(`[fetch-today] scraped=${JSON.stringify(scraped)}`);

  // ── Save to DB ─────────────────────────────────────────────
  const saved: string[] = [];

  for (const slot of ["2pm", "5pm", "9pm"]) {
    const s    = scraped[slot];
    const dbRow = db.get(slot);

    if (!s?.combo) continue; // nothing scraped for this slot

    const winnersFinal = s.winners ?? dbRow?.winners ?? null;

    // Case 1: New combo (slot not in DB yet)
    if (!dbRow?.combo) {
      const parts = s.combo.split("-");
      const { error } = await supabase.from("ez2_results").upsert({
        draw_date:  iso,
        draw_slot:  slot,
        combo:      s.combo,
        num1:       parseInt(parts[0], 10),
        num2:       parseInt(parts[1], 10),
        winners:    winnersFinal,
        source:     "pwedeh.com",
        fetched_at: new Date().toISOString(),
      }, { onConflict: "draw_date,draw_slot" });
      if (!error) { saved.push(slot); console.log(`[fetch-today] inserted ${slot}: ${s.combo} winners=${winnersFinal}`); }
      else console.error(`[fetch-today] insert error ${slot}:`, error.message);
      continue;
    }

    // Case 2: Combo exists, winners still null — update winners only
    if (dbRow.combo && dbRow.winners == null && s.winners != null) {
      const { error } = await supabase.from("ez2_results")
        .update({ winners: s.winners, fetched_at: new Date().toISOString() })
        .eq("draw_date", iso)
        .eq("draw_slot", slot);
      if (!error) { saved.push(`${slot}(winners:${s.winners})`); console.log(`[fetch-today] updated winners ${slot}: ${s.winners}`); }
      else console.error(`[fetch-today] update winners error ${slot}:`, error.message);
      continue;
    }

    // Case 3: Combo changed (re-draw / correction)
    if (dbRow.combo !== s.combo) {
      const parts = s.combo.split("-");
      const { error } = await supabase.from("ez2_results").upsert({
        draw_date:  iso,
        draw_slot:  slot,
        combo:      s.combo,
        num1:       parseInt(parts[0], 10),
        num2:       parseInt(parts[1], 10),
        winners:    winnersFinal,
        source:     "pwedeh.com",
        fetched_at: new Date().toISOString(),
      }, { onConflict: "draw_date,draw_slot" });
      if (!error) { saved.push(`${slot}(corrected)`); console.log(`[fetch-today] corrected ${slot}: ${dbRow.combo} → ${s.combo}`); }
      continue;
    }

    // Case 4: Nothing changed — no-op
    console.log(`[fetch-today] no change for ${slot}`);
  }

  // ── Log ────────────────────────────────────────────────────
  await supabase.from("ez2_fetch_log").upsert({
    fetch_date:  iso,
    status:      saved.length > 0 ? "success" : "no_change",
    draws_found: saved.length,
    notes:       saved.length > 0 ? `Saved: ${saved.join(", ")}` : `Nothing new. scraped=${JSON.stringify(Object.keys(scraped))}`,
    fetched_at:  new Date().toISOString(),
  }, { onConflict: "fetch_date" });

  return Response.json({ message: "OK", date: iso, inWindow, saved, scraped, db: Object.fromEntries(db) });
});

function normalizeCombo(raw: string): string | null {
  const parts = raw.split("-");
  if (parts.length !== 2) return null;
  const n1 = parseInt(parts[0].trim(), 10);
  const n2 = parseInt(parts[1].trim(), 10);
  if (isNaN(n1) || isNaN(n2) || n1 < 1 || n1 > 31 || n2 < 1 || n2 > 31) return null;
  return `${String(n1).padStart(2, "0")}-${String(n2).padStart(2, "0")}`;
}