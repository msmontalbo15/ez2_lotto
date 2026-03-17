// lib/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'helpers.dart';
import 'models.dart';

class ApiService {
  static final _db = Supabase.instance.client;

  // ── Bulk fetch: ALL data in ONE query ─────────────────────
  // Returns today + last N months split by month key.
  // One round trip instead of 4.
  static Future<BulkFetchResult> fetchAll({int monthCount = 3}) async {
    final ph = getPHTime();
    final today = toISODate(ph);

    // Date range: from start of oldest month to today
    final oldest = DateTime(ph.year, ph.month - (monthCount - 1), 1);
    final fromDate =
        '${oldest.year}-${oldest.month.toString().padLeft(2, '0')}-01';

    debugPrint('[ApiService] fetchAll from=$fromDate to=$today');

    final rows = await _db
        .from('ez2_results')
        .select('draw_date, draw_slot, combo, winners')
        .gte('draw_date', fromDate)
        .lte('draw_date', today)
        .order('draw_date', ascending: false)
        .order('draw_slot')
        .timeout(const Duration(seconds: 12));

    debugPrint('[ApiService] fetchAll returned ${(rows as List).length} rows');

    // Split rows by month key — done in Dart, zero extra network cost
    final byMonth = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final date = row['draw_date'] as String; // "2026-03-16"
      final mk = date.substring(0, 7); // "2026-03"
      byMonth.putIfAbsent(mk, () => []).add(Map<String, dynamic>.from(row));
    }

    // Build DayResult lists per month
    final monthResults = <String, List<DayResult>>{};
    for (int i = 0; i < monthCount; i++) {
      final dt = DateTime(ph.year, ph.month - i, 1);
      final mk = monthKey(dt);
      final raw = byMonth[mk] ?? [];
      monthResults[mk] = _buildMonthRows(mk, raw);
    }

    // Build today's DayResult from today's rows
    final todayRows = rows
        .where((r) => r['draw_date'] == today)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final todayResult = todayRows.isEmpty
        ? DayResult.empty(toShortDate(ph), toDayName(ph))
        : DayResult.fromSupabaseRows(todayRows, toShortDate(ph), toDayName(ph));

    return BulkFetchResult(
        todayResult: todayResult, monthResults: monthResults);
  }

  // ── Single month fetch (used for pull-to-refresh on history) ─
  static Future<List<DayResult>> fetchMonth(String mk) async {
    final parts = mk.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final lastDay = DateTime(year, month + 1, 0);
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final to =
        '$year-${month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

    final rows = await _db
        .from('ez2_results')
        .select('draw_date, draw_slot, combo, winners')
        .gte('draw_date', from)
        .lte('draw_date', to)
        .order('draw_date', ascending: false)
        .order('draw_slot')
        .timeout(const Duration(seconds: 10));

    return _buildMonthRows(mk, List<Map<String, dynamic>>.from(rows as List));
  }

  // ── Build DayResult list for a full month ─────────────────
  static List<DayResult> _buildMonthRows(
      String mk, List<Map<String, dynamic>> rows) {
    final parts = mk.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final lastDay = DateTime(year, month + 1, 0);

    // Group by draw_date
    final map = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final date = row['draw_date'] as String;
      map.putIfAbsent(date, () => {});
      final slot = row['draw_slot'] as String;
      map[date]!['${slot}_combo'] = row['combo'];
      map[date]!['${slot}_winners'] = row['winners'];
    }

    final results = <DayResult>[];
    for (int d = lastDay.day; d >= 1; d--) {
      final iso =
          '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final dt = DateTime(year, month, d);
      final data = map[iso];
      results.add(DayResult(
        date: toShortDate(dt),
        day: toDayName(dt),
        result2pm: data?['2pm_combo'] as String?,
        result5pm: data?['5pm_combo'] as String?,
        result9pm: data?['9pm_combo'] as String?,
        winners2pm: data?['2pm_winners'] as int?,
        winners5pm: data?['5pm_winners'] as int?,
        winners9pm: data?['9pm_winners'] as int?,
      ));
    }
    return results;
  }

  // ── Edge function calls ───────────────────────────────────
  static Future<List<String>> triggerFetchToday() async {
    try {
      final res = await _db.functions
          .invoke('fetch-today', method: HttpMethod.post, body: {});
      debugPrint('[ApiService] triggerFetchToday: ${jsonEncode(res.data)}');
      final data = res.data;
      if (data == null) return [];
      final newlyRaw = data['newlySaved'];
      if (newlyRaw is List) return newlyRaw.map((e) => e.toString()).toList();
      return [];
    } catch (e) {
      debugPrint('[ApiService] triggerFetchToday exception: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> readTicketImage(
      String base64Data, String mimeType) async {
    try {
      final res = await _db.functions.invoke('read-ticket',
          method: HttpMethod.post,
          body: {'image': base64Data, 'mime': mimeType});
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[ApiService] readTicketImage exception: $e');
      return null;
    }
  }

  static RealtimeChannel subscribeToday(
      {required String isoDate, required void Function() onUpdate}) {
    return _db
        .channel('ez2-today-$isoDate')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ez2_results',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'draw_date',
              value: isoDate),
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }
}

// ── Result container for bulk fetch ──────────────────────────
class BulkFetchResult {
  final DayResult todayResult;
  final Map<String, List<DayResult>> monthResults;
  const BulkFetchResult(
      {required this.todayResult, required this.monthResults});
}
