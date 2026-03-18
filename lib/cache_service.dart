// lib/cache_service.dart
// Local disk cache — stale-while-revalidate pattern
// Enhanced with extended TTL for better offline support

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

  // TTLs - Extended for aggressive caching
  // Cache-first approach: use cached data unless explicitly refreshed
  static const Duration kTodayTtl =
      Duration(minutes: 15); // Longer TTL for today
  static const Duration kTodayTtlOffline =
      Duration(hours: 24); // Extended when offline
  static const Duration kCurrentMonthTtl =
      Duration(hours: 12); // 12 hours for current month
  static const Duration kCurrentMonthTtlOffline =
      Duration(days: 7); // Extended when offline
  static const Duration kPastMonthTtl =
      Duration(days: 7); // Past months can be cached longer
  static const Duration kPastMonthTtlOffline =
      Duration(days: 30); // Extended when offline

  static Future<void> set(String key, dynamic data,
      {Map<String, String>? metadata}) async {
    await _p.setString(
        key,
        jsonEncode({
          'data': data,
          'savedAt': DateTime.now().toIso8601String(),
          'metadata': metadata ?? {},
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

  /// Get specific metadata value by key
  static String? getMetadata(String key, String metaKey) {
    final entry = get(key);
    if (entry == null) return null;
    final meta = entry['metadata'] as Map<String, dynamic>?;
    return meta?[metaKey] as String?;
  }

  /// Update metadata for existing cache entry
  static Future<void> setMetadata(
      String key, String metaKey, String value) async {
    final entry = get(key);
    if (entry == null) return;

    final metadata = (entry['metadata'] as Map<String, dynamic>? ?? {});
    metadata[metaKey] = value;

    await _p.setString(
        key,
        jsonEncode({
          ...entry,
          'metadata': metadata,
        }));
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

  /// Clear all cached data
  static Future<void> clearAll() async {
    final keys = _p.getKeys();
    for (final key in keys) {
      if (key.startsWith('ez2_')) {
        await _p.remove(key);
      }
    }
  }

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
