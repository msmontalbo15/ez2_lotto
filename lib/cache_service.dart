// lib/cache_service.dart
// Local disk cache — stale-while-revalidate pattern

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    assert(_prefs != null, 'CacheService.init() not called');
    return _prefs!;
  }

  // TTLs
  static const Duration kTodayTtl = Duration(minutes: 3);
  static const Duration kCurrentMonthTtl = Duration(hours: 24);
  static const Duration kPastMonthTtl = Duration(days: 7);

  static Future<void> set(String key, dynamic data) async {
    await _p.setString(
        key,
        jsonEncode({
          'data': data,
          'savedAt': DateTime.now().toIso8601String(),
        }));
  }

  static Map<String, dynamic>? get(String key) {
    final raw = _p.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static bool isExpired(String key, Duration ttl) {
    final entry = get(key);
    if (entry == null) return true;
    final saved = DateTime.tryParse(entry['savedAt'] as String? ?? '');
    if (saved == null) return true;
    return DateTime.now().difference(saved) > ttl;
  }

  static Future<void> delete(String key) async => _p.remove(key);
  static bool has(String key) => _p.containsKey(key);

  // ── Key builders ──────────────────────────────────────────
  static String todayKey(String isoDate) => 'ez2_today:$isoDate';
  static String monthKey(String mk) => 'ez2_month:$mk';

  static Duration monthTtl(String mk) {
    final now = DateTime.now();
    final parts = mk.split('-');
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return (now.year == y && now.month == m) ? kCurrentMonthTtl : kPastMonthTtl;
  }
}
