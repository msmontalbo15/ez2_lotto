// lib/repository.dart
//
// Cache-first data layer:
//   1. Always emit cache immediately (instant UI, zero perceived latency)
//   2. Only hit Supabase when cache is stale or absent
//   3. Past months → never re-fetch (data is immutable)
//   4. Current month → re-fetch after 30 min
//   5. Today → re-fetch after 10 min (draw window) / 60 min (otherwise)
//   6. Realtime subscription handles instant push updates for today

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'helpers.dart';
import 'models.dart';

class EZ2Repository {
  EZ2Repository._();
  static final EZ2Repository instance = EZ2Repository._();

  // ── Streams ───────────────────────────────────────────────
  final _todayCtrl = StreamController<DayResult>.broadcast();
  final _monthCtrl = StreamController<MonthUpdate>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();

  Stream<DayResult> get onToday => _todayCtrl.stream;
  Stream<MonthUpdate> get onMonth => _monthCtrl.stream;
  Stream<String> get onError => _errorCtrl.stream;

  // ── State ─────────────────────────────────────────────────
  RealtimeChannel? _channel;
  bool _subscribed = false;

  /// In-flight request deduplication — prevents parallel identical fetches.
  final _inflight = <String, Future<void>>{};

  Future<void> _once(String key, Future<void> Function() fn) {
    return _inflight.putIfAbsent(
      key,
      () => fn().whenComplete(() => _inflight.remove(key)),
    );
  }

  // ── Public: load everything ───────────────────────────────

  /// Cache-first bulk load.
  /// Emits cached data immediately, then refreshes any stale entries.
  Future<void> loadAll({int monthCount = 3}) async {
    final ph = getPHTime();
    final iso = toISODate(ph);

    // 1. Emit cache for every month immediately
    bool anyCacheMissing = false;
    for (int i = 0; i < monthCount; i++) {
      final mk = monthKey(DateTime(ph.year, ph.month - i, 1));
      final cached = _cachedMonth(mk);
      if (cached != null) {
        _monthCtrl.add(MonthUpdate(mk: mk, rows: cached));
      } else {
        anyCacheMissing = true;
      }
    }

    // 2. Emit today cache immediately
    final todayCached = _cachedToday(iso, ph);
    if (todayCached != null) {
      _todayCtrl.add(todayCached);
    } else {
      anyCacheMissing = true;
    }

    // 3. Check if anything is stale
    final inWindow = _isDrawWindow(ph);
    bool anyStale = anyCacheMissing;
    if (!anyStale) {
      final todayTtl = CacheService.todayTtl(inDrawWindow: inWindow);
      if (CacheService.isStale(CacheService.todayKey(iso), todayTtl)) {
        anyStale = true;
      }
      for (int i = 0; i < monthCount && !anyStale; i++) {
        final mk = monthKey(DateTime(ph.year, ph.month - i, 1));
        if (CacheService.isStale(
            CacheService.monthKey(mk), CacheService.monthTtl(mk))) {
          anyStale = true;
        }
      }
    }

    if (!anyStale) {
      debugPrint('[Repo] loadAll: all cache fresh, skipping network');
      return;
    }

    // 4. One network request for everything
    await _once('loadAll:$monthCount', () async {
      try {
        debugPrint('[Repo] loadAll: fetching from network');
        final result = await ApiService.fetchAll(monthCount: monthCount);

        // Save and emit today
        await _saveToday(iso, result.today);
        _todayCtrl.add(result.today);

        // Save and emit each month
        final emitted = <String>{};
        for (final entry in result.months.entries) {
          await _saveMonth(entry.key, entry.value);
          _monthCtrl.add(MonthUpdate(mk: entry.key, rows: entry.value));
          emitted.add(entry.key);
        }

        // Emit empty for months not returned (clears loading state in UI)
        for (int i = 0; i < monthCount; i++) {
          final mk = monthKey(DateTime(ph.year, ph.month - i, 1));
          if (!emitted.contains(mk)) {
            _monthCtrl.add(MonthUpdate(mk: mk, rows: const []));
          }
        }
      } catch (e) {
        debugPrint('[Repo] loadAll error: $e');
        _errorCtrl.add('offline');
        // Ensure today stream emits something so loading screen dismisses
        if (todayCached == null) {
          _todayCtrl.add(DayResult.empty(toShortDate(ph), toDayName(ph)));
        }
        // Emit empty for months with no cache so loading clears
        for (int i = 0; i < monthCount; i++) {
          final mk = monthKey(DateTime(ph.year, ph.month - i, 1));
          if (_cachedMonth(mk) == null) {
            _monthCtrl.add(MonthUpdate(mk: mk, rows: const []));
          }
        }
      }
    });
  }

  // ── Public: today ─────────────────────────────────────────

  /// Refreshes today's data.
  /// [force] bypasses the TTL check (used on manual pull-to-refresh).
  Future<void> loadToday({bool force = false}) async {
    final ph = getPHTime();
    final iso = toISODate(ph);
    final inWindow = _isDrawWindow(ph);
    final ttl = CacheService.todayTtl(inDrawWindow: inWindow);
    final cacheKey = CacheService.todayKey(iso);

    // Always emit cache first for instant display
    final cached = _cachedToday(iso, ph);
    if (cached != null) _todayCtrl.add(cached);

    // Skip network if cache is fresh and not forced
    if (!force && !CacheService.isStale(cacheKey, ttl)) {
      debugPrint('[Repo] today: cache fresh, skipping network');
      return;
    }

    await _once('today:$iso', () async {
      try {
        debugPrint('[Repo] today: fetching from network');
        final result = await ApiService.fetchAll(monthCount: 1);
        await _saveToday(iso, result.today);
        _todayCtrl.add(result.today);

        // Trigger scrape if results are still missing during draw window
        if (inWindow && _needsScrape(result.today, ph)) {
          _scrapeBackground(iso, ph);
        }
      } catch (e) {
        debugPrint('[Repo] today error: $e');
        if (cached == null) {
          _errorCtrl.add('offline');
          _todayCtrl.add(DayResult.empty(toShortDate(ph), toDayName(ph)));
        }
      }
    });
  }

  // ── Public: month ─────────────────────────────────────────

  /// Load a specific month. Serves cache instantly, refreshes if stale.
  Future<void> loadMonth(String mk) async {
    final ck = CacheService.monthKey(mk);
    final cached = _cachedMonth(mk);

    // Emit cache immediately
    if (cached != null) {
      _monthCtrl.add(MonthUpdate(mk: mk, rows: cached));
      // Past months never go stale
      if (!CacheService.isStale(ck, CacheService.monthTtl(mk))) return;
    }

    await _once('month:$mk', () async {
      try {
        debugPrint('[Repo] month $mk: fetching');
        final rows = await ApiService.fetchMonth(mk);
        await _saveMonth(mk, rows);
        _monthCtrl.add(MonthUpdate(mk: mk, rows: rows));
      } catch (e) {
        debugPrint('[Repo] month $mk error: $e');
        if (cached == null) {
          _errorCtrl.add('month_error:$mk');
          _monthCtrl.add(MonthUpdate(mk: mk, rows: const []));
        }
      }
    });
  }

  /// Force re-fetch a month, ignoring TTL.
  Future<void> forceRefreshMonth(String mk) async {
    await CacheService.delete(CacheService.monthKey(mk));
    await loadMonth(mk);
  }

  // ── Public: realtime ──────────────────────────────────────

  void subscribeRealtime() {
    if (_subscribed) return;
    _subscribed = true;
    final iso = toISODate(getPHTime());
    _channel?.unsubscribe();
    _channel = ApiService.subscribeToDate(
      isoDate: iso,
      onChanged: () async {
        debugPrint('[Repo] realtime: change detected for $iso');
        await CacheService.delete(CacheService.todayKey(iso));
        await loadToday(force: true);
      },
    );
  }

  void unsubscribeRealtime() {
    _channel?.unsubscribe();
    _channel = null;
    _subscribed = false;
  }

  /// Call at midnight to reset today's subscription to the new date.
  void resubscribeForNewDay() {
    unsubscribeRealtime();
    subscribeRealtime();
  }

  void dispose() {
    unsubscribeRealtime();
    _todayCtrl.close();
    _monthCtrl.close();
    _errorCtrl.close();
  }

  // ── Cache read helpers ────────────────────────────────────

  DayResult? _cachedToday(String iso, DateTime ph) {
    final raw = CacheService.get<List<dynamic>>(CacheService.todayKey(iso));
    if (raw == null) return null;
    try {
      return _dayResultFromCache(raw, ph);
    } catch (e) {
      debugPrint('[Repo] today cache parse error: $e');
      return null;
    }
  }

  List<DayResult>? _cachedMonth(String mk) {
    final raw = CacheService.get<List<dynamic>>(CacheService.monthKey(mk));
    if (raw == null) return null;
    try {
      return raw
          .map((e) => _dayResultFromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Repo] month cache parse error: $e');
      return null;
    }
  }

  DayResult _dayResultFromCache(List<dynamic> rows, DateTime ph) {
    if (rows.isEmpty) return DayResult.empty(toShortDate(ph), toDayName(ph));
    final combos   = <String, String>{};
    final winners  = <String, int?>{};
    for (final r in rows) {
      final m    = r as Map<String, dynamic>;
      final slot = m['draw_time']?.toString().toLowerCase() ?? '';
      final combo = m['combo']?.toString() ?? '';
      if (slot.isNotEmpty && combo.isNotEmpty) {
        combos[slot]  = combo;
        final w = m['winner_count'];
        winners[slot] = w is num ? w.toInt() : null;
      }
    }
    return DayResult(
      date:       toShortDate(ph),
      day:        toDayName(ph),
      result2pm:  combos['2pm'],
      result5pm:  combos['5pm'],
      result9pm:  combos['9pm'],
      winners2pm: winners['2pm'],
      winners5pm: winners['5pm'],
      winners9pm: winners['9pm'],
    );
  }

  DayResult _dayResultFromMap(Map<String, dynamic> m) {
    int? parseWinners(dynamic v) => v is num ? v.toInt() : null;
    return DayResult(
      date:       m['date']       as String,
      day:        m['day']        as String,
      result2pm:  m['result2pm']  as String?,
      result5pm:  m['result5pm']  as String?,
      result9pm:  m['result9pm']  as String?,
      winners2pm: parseWinners(m['winners2pm']),
      winners5pm: parseWinners(m['winners5pm']),
      winners9pm: parseWinners(m['winners9pm']),
    );
  }

  // ── Cache write helpers ───────────────────────────────────

  Future<void> _saveToday(String iso, DayResult result) async {
    final rows = <Map<String, dynamic>>[
      if (result.result2pm != null)
        {'draw_time': '2pm', 'combo': result.result2pm!, 'winner_count': result.winners2pm},
      if (result.result5pm != null)
        {'draw_time': '5pm', 'combo': result.result5pm!, 'winner_count': result.winners5pm},
      if (result.result9pm != null)
        {'draw_time': '9pm', 'combo': result.result9pm!, 'winner_count': result.winners9pm},
    ];
    await CacheService.set(CacheService.todayKey(iso), rows);
  }

  Future<void> _saveMonth(String mk, List<DayResult> rows) async {
    final serialised = rows
        .map((r) => {
              'date':       r.date,
              'day':        r.day,
              'result2pm':  r.result2pm,
              'result5pm':  r.result5pm,
              'result9pm':  r.result9pm,
              'winners2pm': r.winners2pm,
              'winners5pm': r.winners5pm,
              'winners9pm': r.winners9pm,
            })
        .toList();
    await CacheService.set(CacheService.monthKey(mk), serialised);
  }

  // ── Draw window helpers ───────────────────────────────────

  bool _isDrawWindow(DateTime ph) {
    final m = ph.hour * 60 + ph.minute;
    return (m >= 840 && m <= 875) // 2:00–2:35 PM
        ||
        (m >= 1020 && m <= 1055) // 5:00–5:35 PM
        ||
        (m >= 1260 && m <= 1295); // 9:00–9:35 PM
  }

  bool _needsScrape(DayResult r, DateTime ph) {
    final m = ph.hour * 60 + ph.minute;
    if (m >= 840 && r.result2pm == null) return true;
    if (m >= 1020 && r.result5pm == null) return true;
    if (m >= 1260 && r.result9pm == null) return true;
    return false;
  }

  void _scrapeBackground(String iso, DateTime ph) {
    ApiService.triggerScrapeToday().then((slots) async {
      if (slots.isNotEmpty) {
        debugPrint('[Repo] scrape returned: $slots');
        await CacheService.delete(CacheService.todayKey(iso));
        await loadToday(force: true);
      }
    }).catchError((Object e, StackTrace st) async {
      debugPrint('[Repo] scrape error: $e');
    }, test: (e) => true);
  }
}
