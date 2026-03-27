// lib/api_service.dart
//
// Single responsibility: talk to Supabase, return typed results.
// No caching logic here — that lives in EZ2Repository.
//
// Table: ez2_results
//   id          BIGINT
//   draw_date   DATE        "2026-03-23"
//   draw_time   TEXT        "2PM" | "5PM" | "9PM"
//   num1        SMALLINT    28
//   num2        SMALLINT    30
//   combo       TEXT        "28-30"  (generated column — we use it directly)
//   source      TEXT
//   created_at  TIMESTAMPTZ

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'helpers.dart';
import 'models.dart';

class ApiService {
  ApiService._();

  static final _db = Supabase.instance.client;

  // ── Column names ──────────────────────────────────────────
  static const _kSelect = 'draw_date, draw_time, combo, winner_count';

  // ── Public API ────────────────────────────────────────────

  /// Fetches all draws from the start of [monthCount] months ago to today.
  /// Returns a [BulkResult] containing today + each month's rows.
  static Future<BulkResult> fetchAll({int monthCount = 3}) async {
    final ph       = getPHTime();
    final today    = toISODate(ph);
    final oldest   = DateTime(ph.year, ph.month - (monthCount - 1), 1);
    final fromDate = _isoMonth(oldest.year, oldest.month);

    debugPrint('[Api] fetchAll $fromDate → $today');

    final rows = await _query(fromDate, today);

    debugPrint('[Api] fetchAll: ${rows.length} rows');
    if (rows.isNotEmpty) debugPrint('[Api] sample: ${rows.first}');

    // Split rows into per-month buckets in one pass
    final byMonth = <String, List<DrawRow>>{};
    for (final row in rows) {
      final mk = row.drawDate.substring(0, 7);
      byMonth.putIfAbsent(mk, () => []).add(row);
    }

    // Build DayResult lists per month
    final monthResults = <String, List<DayResult>>{};
    for (int i = 0; i < monthCount; i++) {
      final dt = DateTime(ph.year, ph.month - i, 1);
      final mk = monthKey(dt);
      monthResults[mk] = _buildMonth(mk, byMonth[mk] ?? []);
    }

    // Today
    final todayRows = byMonth[today.substring(0, 7)]
            ?.where((r) => r.drawDate == today)
            .toList() ??
        [];
    final todayResult = _buildDay(todayRows, ph);

    return BulkResult(today: todayResult, months: monthResults);
  }

  /// Fetches a single month — used for pull-to-refresh.
  static Future<List<DayResult>> fetchMonth(String mk) async {
    final parts   = mk.split('-');
    final year    = int.parse(parts[0]);
    final month   = int.parse(parts[1]);
    final lastDay = DateTime(year, month + 1, 0).day;
    final from    = _isoMonth(year, month);
    final to      = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

    debugPrint('[Api] fetchMonth $mk');
    final rows = await _query(from, to);
    debugPrint('[Api] fetchMonth $mk: ${rows.length} rows');
    return _buildMonth(mk, rows);
  }

  /// Triggers the Edge Function to scrape today's results.
  /// Returns the list of draw slots that were newly saved ("2pm", "5pm", "9pm").
  static Future<List<String>> triggerScrapeToday() async {
    try {
      final res = await _db.functions
          .invoke('fetch-ez2', method: HttpMethod.post, body: {});
      debugPrint('[Api] triggerScrape: ${jsonEncode(res.data)}');
      final results = res.data?['results'];
      if (results is! List) return [];
      return results
          .map((e) => (e['draw_time']?.toString() ?? '').toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[Api] triggerScrape error: $e');
      return [];
    }
  }

  /// Returns every year that has at least one draw result, newest first.
  /// Falls back to [current year] if the query fails.
  static Future<List<int>> fetchAvailableYears() async {
    try {
      // Get the oldest draw date to know the earliest year
      final oldest = await _db
          .from('ez2_results')
          .select('draw_date')
          .order('draw_date', ascending: true)
          .limit(1)
          .maybeSingle();

      if (oldest == null) return [getPHTime().year];

      final rawDate = oldest['draw_date'];
      final String dateStr = rawDate is DateTime
          ? rawDate.toIso8601String().substring(0, 10)
          : rawDate.toString().substring(0, 10);

      final firstYear = int.parse(dateStr.substring(0, 4));
      final currentYear = getPHTime().year;

      return List.generate(
        currentYear - firstYear + 1,
        (i) => currentYear - i,
      );
    } catch (e) {
      debugPrint('[Api] fetchAvailableYears error: $e');
      return [getPHTime().year];
    }
  }

  /// Sends a ticket image to the read-ticket Edge Function.
  static Future<Map<String, dynamic>?> readTicketImage(
      String base64Data, String mimeType) async {
    try {
      final res = await _db.functions.invoke('read-ticket',
          method: HttpMethod.post,
          body: {'image': base64Data, 'mime': mimeType});
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[Api] readTicketImage error: $e');
      return null;
    }
  }

  /// Opens a Realtime subscription on ez2_results for [isoDate].
  static RealtimeChannel subscribeToDate({
    required String isoDate,
    required void Function() onChanged,
  }) {
    return _db
        .channel('ez2:$isoDate')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ez2_results',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'draw_date',
            value: isoDate,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  // ── Private helpers ───────────────────────────────────────

  static Future<List<DrawRow>> _query(String from, String to) async {
    final raw = await _db
        .from('ez2_results')
        .select(_kSelect)
        .gte('draw_date', from)
        .lte('draw_date', to)
        .order('draw_date', ascending: false)
        .order('draw_time')
        .timeout(const Duration(seconds: 12));

    return (raw as List)
        .cast<Map<String, dynamic>>()
        .map(DrawRow.fromJson)
        .toList();
  }

  static DayResult _buildDay(List<DrawRow> rows, DateTime ph) {
    if (rows.isEmpty) return DayResult.empty(toShortDate(ph), toDayName(ph));
    final map = <String, DrawRow>{for (final r in rows) r.slot: r};
    return DayResult(
      date:       toShortDate(ph),
      day:        toDayName(ph),
      result2pm:  map['2pm']?.combo,
      result5pm:  map['5pm']?.combo,
      result9pm:  map['9pm']?.combo,
      winners2pm: map['2pm']?.winnerCount,
      winners5pm: map['5pm']?.winnerCount,
      winners9pm: map['9pm']?.winnerCount,
    );
  }

  static List<DayResult> _buildMonth(String mk, List<DrawRow> rows) {
    final parts   = mk.split('-');
    final year    = int.parse(parts[0]);
    final month   = int.parse(parts[1]);
    final lastDay = DateTime(year, month + 1, 0).day;

    // Group by date → slot
    final byDate = <String, Map<String, DrawRow>>{};
    for (final r in rows) {
      byDate.putIfAbsent(r.drawDate, () => {})[r.slot] = r;
    }

    return List.generate(lastDay, (i) {
      final d   = lastDay - i; // descending
      final iso = '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final dt  = DateTime(year, month, d);
      final map = byDate[iso];
      return DayResult(
        date:       toShortDate(dt),
        day:        toDayName(dt),
        result2pm:  map?['2pm']?.combo,
        result5pm:  map?['5pm']?.combo,
        result9pm:  map?['9pm']?.combo,
        winners2pm: map?['2pm']?.winnerCount,
        winners5pm: map?['5pm']?.winnerCount,
        winners9pm: map?['9pm']?.winnerCount,
      );
    });
  }

  static String _isoMonth(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}-01';
}

// ── Value objects ─────────────────────────────────────────────

/// A single row returned from Supabase, already parsed.
class DrawRow {
  final String drawDate; // "2026-03-23"
  final String slot;     // "2pm" | "5pm" | "9pm"
  final String combo;    // "28-30"
  final int?   winnerCount;

  const DrawRow({
    required this.drawDate,
    required this.slot,
    required this.combo,
    this.winnerCount,
  });

  factory DrawRow.fromJson(Map<String, dynamic> json) {
    // draw_date may be String or DateTime depending on supabase_flutter version
    final rawDate = json['draw_date'];
    final String dateStr;
    if (rawDate is DateTime) {
      dateStr = '${rawDate.year}-${rawDate.month.toString().padLeft(2, '0')}-${rawDate.day.toString().padLeft(2, '0')}';
    } else {
      final s = rawDate?.toString() ?? '';
      dateStr = s.length > 10 ? s.substring(0, 10) : s;
    }

    // combo is a generated column in the table ("28-30")
    // fall back to building it from num1/num2 if missing
    final combo = json['combo'] as String? ??
        _buildCombo(json['num1'], json['num2']);

    // winner_count: treat 0 as null so the trophy row stays hidden until real data arrives
    final rawWinners = json['winner_count'];
    final winnerCount = rawWinners is num ? rawWinners.toInt() : null;

    return DrawRow(
      drawDate:    dateStr,
      slot:        (json['draw_time']?.toString() ?? '').toLowerCase(),
      combo:       combo,
      winnerCount: (winnerCount != null && winnerCount > 0) ? winnerCount : null,
    );
  }

  static String _buildCombo(dynamic n1, dynamic n2) {
    final a = (n1 is num ? n1.toInt() : int.tryParse(n1?.toString() ?? '') ?? 0);
    final b = (n2 is num ? n2.toInt() : int.tryParse(n2?.toString() ?? '') ?? 0);
    return '${a.toString().padLeft(2, '0')}-${b.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'draw_date': drawDate,
        'draw_time': slot,
        'combo':     combo,
      };
}

/// Container returned by [ApiService.fetchAll].
class BulkResult {
  final DayResult today;
  final Map<String, List<DayResult>> months;
  const BulkResult({required this.today, required this.months});
}
