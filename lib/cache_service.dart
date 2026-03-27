// lib/cache_service.dart
//
// Cache strategy:
//   • Past months  — never expire (data never changes)
//   • Current month — expire after 30 min, re-fetch in background
//   • Today        — expire after 10 min during draw windows, 60 min otherwise
//   • All reads    — serve cache instantly, refresh in background if stale
//
// Storage: SharedPreferences (key-value, JSON encoded)
// Format:  { "v": 1, "savedAt": "ISO8601", "data": <payload> }

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Bump this when the cache payload structure changes — forces a full invalidation
const int _kCacheVersion = 2;

class CacheService {
  CacheService._();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _evictOldVersions();
  }

  static SharedPreferences get _p {
    assert(_prefs != null, 'CacheService.init() not called');
    return _prefs!;
  }

  // ── TTLs ──────────────────────────────────────────────────

  /// Today: 10 min during draw windows (2PM/5PM/9PM ± 35 min), 60 min otherwise
  static Duration todayTtl({bool inDrawWindow = false}) =>
      inDrawWindow ? const Duration(minutes: 10) : const Duration(hours: 1);

  /// Current month: 30 min (data can change if today's draws happen)
  static const Duration kCurrentMonthTtl = Duration(minutes: 30);

  /// Past months: never expire — historical data never changes
  static const Duration kPastMonthTtl = Duration(days: 365);

  static Duration monthTtl(String mk) {
    final now    = getPHTNow();
    final parts  = mk.split('-');
    final y      = int.tryParse(parts[0]) ?? 0;
    final m      = int.tryParse(parts[1]) ?? 0;
    final isPast = y < now.year || (y == now.year && m < now.month);
    return isPast ? kPastMonthTtl : kCurrentMonthTtl;
  }

  // ── Write ─────────────────────────────────────────────────

  static Future<void> set(String key, dynamic data) async {
    try {
      await _p.setString(key, jsonEncode({
        'v':       _kCacheVersion,
        'savedAt': DateTime.now().toIso8601String(),
        'data':    data,
      }));
    } catch (e) {
      debugPrint('[Cache] set error ($key): $e');
    }
  }

  // ── Read ──────────────────────────────────────────────────

  /// Returns the cached data payload, or null if missing/invalid/wrong version.
  static T? get<T>(String key) {
    try {
      final raw = _p.getString(key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if ((json['v'] as int? ?? 0) != _kCacheVersion) return null;
      return json['data'] as T?;
    } catch (_) {
      return null;
    }
  }

  /// Returns when the entry was saved, or null if not cached.
  static DateTime? savedAt(String key) {
    try {
      final raw = _p.getString(key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return DateTime.tryParse(json['savedAt'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  /// True if the entry is older than [ttl] or does not exist.
  static bool isStale(String key, Duration ttl) {
    final saved = savedAt(key);
    if (saved == null) return true;
    return DateTime.now().difference(saved) > ttl;
  }

  static bool has(String key) {
    if (!_p.containsKey(key)) return false;
    return get(key) != null; // also validates version
  }

  // ── Delete ────────────────────────────────────────────────

  static Future<void> delete(String key) => _p.remove(key);

  static Future<void> clearAll() async {
    final keys = _p.getKeys().where((k) => k.startsWith('ez2_')).toList();
    for (final k in keys) await _p.remove(k);
    debugPrint('[Cache] cleared ${keys.length} entries');
  }

  // ── Key builders ──────────────────────────────────────────

  static String todayKey(String isoDate)  => 'ez2_today:$isoDate';
  static String monthKey(String monthKey) => 'ez2_month:$monthKey';

  // ── Internal ──────────────────────────────────────────────

  /// Remove any entries saved with an older cache version.
  static void _evictOldVersions() {
    final stale = <String>[];
    for (final key in _p.getKeys()) {
      if (!key.startsWith('ez2_')) continue;
      try {
        final raw  = _p.getString(key);
        if (raw == null) continue;
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if ((json['v'] as int? ?? 0) != _kCacheVersion) stale.add(key);
      } catch (_) {
        stale.add(key);
      }
    }
    for (final k in stale) _p.remove(k);
    if (stale.isNotEmpty) {
      debugPrint('[Cache] evicted ${stale.length} old-version entries');
    }
  }

  /// PHT DateTime used only for TTL calculations (avoids importing helpers).
  static DateTime getPHTNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 8));
}
