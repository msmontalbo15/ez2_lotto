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

<<<<<<< HEAD
  /// Cache-first bulk load.
  /// Emits cached data immediately, then refreshes any stale entries.
=======
  Future<void> loadToday({bool forceNetwork = false}) async {
    final ph = getPHTime();
    final iso = toISODate(ph);
    final cacheKey = CacheService.todayKey(iso);

    // 1. ALWAYS serve cache immediately - no network on initial load
    final cached = _readTodayCache(cacheKey, ph);
    if (cached != null) {
      _todayCtrl.add(cached);

      // If not force and cache is fresh, skip network entirely
      if (!forceNetwork &&
          !CacheService.isExpired(cacheKey, CacheService.kTodayTtl) &&
          !_isInDrawWindow(ph)) {
        return;
      }

      // If force refresh OR in draw window, check for changes in background
      if (forceNetwork || _isInDrawWindow(ph)) {
        // Fire and forget - don't await, update will come via stream
        _getOrFetch('today:$iso',
            () => _fetchTodayFromNetwork(iso, ph, cacheKey, false));
        return;
      }

      // Cache is stale but not in draw window - check for changes silently
      final hasChanged = await _checkDataChanged(iso);
      if (!hasChanged) {
        debugPrint('[Repo] Today data unchanged, using cache');
        return;
      }

      // Data changed - fetch in background
      _getOrFetch(
          'today:$iso', () => _fetchTodayFromNetwork(iso, ph, cacheKey, false));
      return;
    }

    // 2. No cache - must fetch from network
    await _getOrFetch(
        'today:$iso', () => _fetchTodayFromNetwork(iso, ph, cacheKey, true));
  }

  /// Lightweight check if data has changed since last fetch
  Future<bool> _checkDataChanged(String iso) async {
    try {
      // Just get the most recent updated_at - lightweight query
      final result = await _db
          .from('ez2_results')
          .select('updated_at')
          .eq('draw_date', iso)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (result == null) return true; // No data, need to fetch

      final newUpdatedAt = result['updated_at'] as String?;
      if (newUpdatedAt == null) return true;

      // Get cached timestamp
      final cacheKey = CacheService.todayKey(iso);
      final cachedUpdatedAt = CacheService.getMetadata(cacheKey, 'updated_at');

      return cachedUpdatedAt != newUpdatedAt;
    } catch (e) {
      // On error, allow fetch
      return true;
    }
  }

  Future<void> _fetchTodayFromNetwork(
    String iso,
    DateTime ph,
    String cacheKey,
    bool isFirstLoad,
  ) async {
    try {
      debugPrint('[Repo] fetching today from network: $iso');
      final rows = await _db
          .from('ez2_results')
          .select('draw_slot, combo, winners, updated_at')
          .eq('draw_date', iso)
          .order('draw_slot')
          .timeout(const Duration(seconds: 10));

      final list = List<Map<String, dynamic>>.from(rows as List);
      final result = _buildToday(list, ph);

      debugPrint('[Repo] today fetched: ${list.length} rows');

      // Store data and get most recent updated_at for change detection
      String? latestUpdatedAt;
      for (final row in list) {
        final u = row['updated_at'] as String?;
        if (u != null &&
            (latestUpdatedAt == null || u.compareTo(latestUpdatedAt) > 0)) {
          latestUpdatedAt = u;
        }
      }

      await CacheService.set(cacheKey, list);
      if (latestUpdatedAt != null) {
        await CacheService.setMetadata(cacheKey, 'updated_at', latestUpdatedAt);
      }

      _todayCtrl.add(result);

      if (_shouldScrape(result, ph)) {
        await _scrapeInBackgroundWithData(iso, ph, cacheKey, list);
      }
    } catch (e) {
      debugPrint('[Repo] loadToday error: $e');
      if (isFirstLoad) _errorCtrl.add('offline');
      // Re-emit empty result so the loading screen dismisses
      if (isFirstLoad) {
        _todayCtrl.add(DayResult.empty(toShortDate(ph), toDayName(ph)));
      }
    }
  }

  bool _isInDrawWindow(DateTime ph) {
    // Poll from draw time → 35 min after (sites publish within 5–30 min)
    final mins = ph.hour * 60 + ph.minute;
    if (mins >= 840 && mins <= 875) return true; // 2:00PM – 2:35PM
    if (mins >= 1020 && mins <= 1055) return true; // 5:00PM – 5:35PM
    if (mins >= 1260 && mins <= 1295) return true; // 9:00PM – 9:35PM
    return false;
  }

  /// Check if we're at a scheduled fetch time (20, 25, 30 min after draw)
  /// Returns the draw slot if it's time to fetch, null otherwise
  String? _getScheduledFetchSlot(DateTime ph) {
    final mins = ph.hour * 60 + ph.minute;

    // 2PM draw window: fetch at 2:20, 2:25, 2:30 (840 + 20, 25, 30)
    if (mins >= 860 && mins <= 870) return '2pm'; // 2:20PM – 2:30PM

    // 5PM draw window: fetch at 5:20, 5:25, 5:30 (1020 + 20, 25, 30)
    if (mins >= 1040 && mins <= 1050) return '5pm'; // 5:20PM – 5:30PM

    // 9PM draw window: fetch at 9:20, 9:25, 9:30 (1260 + 20, 25, 30)
    if (mins >= 1280 && mins <= 1290) return '9pm'; // 9:20PM – 9:30PM

    return null;
  }

  bool _shouldScrape(DayResult r, DateTime ph) {
    // Scrape during draw window for combo results only
    // Winners are only fetched after the end of the day (after 9:35 PM)
    // Schedule: Fire at 20, 25, 30 minutes after each draw (3 jobs per draw)

    final scheduledSlot = _getScheduledFetchSlot(ph);

    // Only fetch during scheduled times (20, 25, 30 min after draw)
    if (scheduledSlot != null) {
      if (scheduledSlot == '2pm' && r.result2pm == null) return true;
      if (scheduledSlot == '5pm' && r.result5pm == null) return true;
      if (scheduledSlot == '9pm' && r.result9pm == null) return true;
      return false;
    }

    // Fallback: if combo is missing entirely for a past draw, still try once
    final mins = ph.hour * 60 + ph.minute;
    if (mins > 875 && r.result2pm == null) return true;
    if (mins > 1055 && r.result5pm == null) return true;
    if (mins > 1295 && r.result9pm == null) return true;

    // Winners: only fetch after end of day (after 9:35 PM = 1295 minutes)
    // This means after the 9PM draw window closes
    final isEndOfDay = mins > 1295;
    if (isEndOfDay && r.result2pm != null && r.winners2pm == null) return true;
    if (isEndOfDay && r.result5pm != null && r.winners5pm == null) return true;
    if (isEndOfDay && r.result9pm != null && r.winners9pm == null) return true;

    return false;
  }

  Future<void> _scrapeInBackgroundWithData(String iso, DateTime ph,
      String cacheKey, List<Map<String, dynamic>> existingRows) async {
    try {
      // Check if all combos already exist for today - stop fetch if they do
      final has2pm = existingRows
          .any((r) => r['draw_slot'] == '2pm' && r['combo'] != null);
      final has5pm = existingRows
          .any((r) => r['draw_slot'] == '5pm' && r['combo'] != null);
      final has9pm = existingRows
          .any((r) => r['draw_slot'] == '9pm' && r['combo'] != null);

      if (has2pm && has5pm && has9pm) {
        debugPrint(
            '[Repo] All combos already exist in database, skipping fetch');
        return; // Stop - don't call triggerFetchToday()
      }

      final newSlots = await ApiService.triggerFetchToday();
      if (newSlots.isNotEmpty) {
        // Use existing rows instead of re-fetching from network
        final list = existingRows;
        final result = _buildToday(list, ph);
        await CacheService.set(cacheKey, list);
        _todayCtrl.add(result);
      }
    } catch (e) {
      debugPrint('[Repo] scrape error: $e');
    }
  }

  DayResult? _readTodayCache(String key, DateTime ph) {
    final entry = CacheService.get(key);
    if (entry == null) return null;
    try {
      final list = (entry['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return _buildToday(list, ph);
    } catch (_) {
      return null;
    }
  }

  DayResult _buildToday(List<Map<String, dynamic>> rows, DateTime ph) {
    if (rows.isEmpty) return DayResult.empty(toShortDate(ph), toDayName(ph));
    return DayResult.fromSupabaseRows(rows, toShortDate(ph), toDayName(ph));
  }

  // ── BULK FETCH: one query for everything ──────────────────
>>>>>>> 040d0d8d8116ae221e5f6e6341a7441b44ce6370
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
