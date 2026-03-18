// lib/repository.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'helpers.dart';
import 'models.dart';

class EZ2Repository {
  static final EZ2Repository instance = EZ2Repository._();
  EZ2Repository._();

  final _db = Supabase.instance.client;

  final _todayCtrl = StreamController<DayResult>.broadcast();
  final _monthCtrl = StreamController<MonthUpdate>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();

  Stream<DayResult> get onToday => _todayCtrl.stream;
  Stream<MonthUpdate> get onMonth => _monthCtrl.stream;
  Stream<String> get onError => _errorCtrl.stream;

  RealtimeChannel? _channel;
  bool _isSubscribed = false;

  // ── Request deduplication ────────────────────────────────────
  final _pendingRequests = <String, Future>{};

  Future<void> _getOrFetch(String key, Future<void> Function() fetcher) async {
    if (_pendingRequests.containsKey(key)) {
      await _pendingRequests[key];
      return;
    }
    final future = fetcher().whenComplete(() => _pendingRequests.remove(key));
    _pendingRequests[key] = future;
    return future;
  }

  // ── TODAY ──────────────────────────────────────────────────

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
  Future<void> loadAll({int monthCount = 3}) async {
    final ph = getPHTime();

    // Emit cache for all months immediately - no network on initial load
    for (int i = 0; i < monthCount; i++) {
      final mk = monthKey(DateTime(ph.year, ph.month - i, 1));
      final cacheKey = CacheService.monthKey(mk);
      final cached = _readMonthCache(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        _monthCtrl.add(MonthUpdate(mk: mk, rows: cached));
      }
    }
    // Emit today cache
    final todayCacheKey = CacheService.todayKey(toISODate(ph));
    final cachedToday = _readTodayCache(todayCacheKey, ph);
    if (cachedToday != null) _todayCtrl.add(cachedToday);

    // Check if we need to fetch - only if cache is empty or expired
    bool needsFetch = cachedToday == null;
    if (!needsFetch) {
      for (int i = 0; i < monthCount && !needsFetch; i++) {
        final mk = monthKey(DateTime(ph.year, ph.month - i, 1));
        final cacheKey = CacheService.monthKey(mk);
        final cached = _readMonthCache(cacheKey);
        if (cached == null || cached.isEmpty) {
          needsFetch = true;
        } else if (CacheService.isExpired(
            cacheKey, CacheService.monthTtl(mk))) {
          needsFetch = true;
        }
      }
    }

    // Skip fetch if all data is cached
    if (!needsFetch) {
      debugPrint('[Repo] All data cached, skipping network fetch');
      return;
    }

    // One single network request for everything (with deduplication)
    await _getOrFetch('loadAll:$monthCount', () async {
      try {
        final result = await ApiService.fetchAll(monthCount: monthCount);

        // Save and emit today
        final iso = toISODate(ph);
        final todayRows = result.monthResults[iso.substring(0, 7)]
                ?.where((r) => r.date == toShortDate(ph))
                .toList() ??
            [];
        await CacheService.set(todayCacheKey, _rowsToCache(todayRows));
        _todayCtrl.add(result.todayResult);

        // Save and emit each month (always emit, even if empty — clears loading state)
        for (final entry in result.monthResults.entries) {
          final cacheKey = CacheService.monthKey(entry.key);
          await CacheService.set(
              cacheKey, entry.value.map(_serializeDayResult).toList());
          _monthCtrl.add(MonthUpdate(mk: entry.key, rows: entry.value));
        }
        // Emit any months that had no data at all (ensures loading flag clears)
        final emittedKeys = result.monthResults.keys.toSet();
        for (int i = 0; i < monthCount; i++) {
          final mk = monthKey(DateTime(ph.year, ph.month - i, 1));
          if (!emittedKeys.contains(mk)) {
            _monthCtrl.add(MonthUpdate(mk: mk, rows: const []));
          }
        }
      } catch (e) {
        debugPrint('[Repo] loadAll error: $e');
        // If completely offline and no cache, signal error
        if (cachedToday == null) {
          _errorCtrl.add('offline');
          _todayCtrl.add(DayResult.empty(toShortDate(ph), toDayName(ph)));
        }
      }
    });
  }

  List<Map<String, dynamic>> _rowsToCache(List<DayResult> rows) =>
      rows.map(_serializeDayResult).toList();

  // ── MONTH ──────────────────────────────────────────────────

  Future<void> loadMonth(String mk) async {
    final cacheKey = CacheService.monthKey(mk);

    // Serve cache instantly
    final cached = _readMonthCache(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      _monthCtrl.add(MonthUpdate(mk: mk, rows: cached));
      if (!CacheService.isExpired(cacheKey, CacheService.monthTtl(mk))) return;
    }

    // Network refresh (with deduplication)
    await _getOrFetch('month:$mk', () async {
      try {
        debugPrint('[Repo] fetching month: $mk');
        final rows = await ApiService.fetchMonth(mk);
        debugPrint('[Repo] month $mk fetched: ${rows.length} rows');
        await CacheService.set(
            cacheKey, rows.map(_serializeDayResult).toList());
        _monthCtrl.add(MonthUpdate(mk: mk, rows: rows));
      } catch (e) {
        debugPrint('[Repo] loadMonth error ($mk): $e');
        if (cached == null || cached.isEmpty) {
          _errorCtrl.add('month_error:$mk');
          // Emit empty so loading state clears
          _monthCtrl.add(MonthUpdate(mk: mk, rows: const []));
        }
      }
    });
  }

  /// Force-fetch a month from network, ignoring cache freshness
  Future<void> forceLoadMonth(String mk) async {
    final cacheKey = CacheService.monthKey(mk);

    // Always serve cache first for instant display
    final cached = _readMonthCache(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      _monthCtrl.add(MonthUpdate(mk: mk, rows: cached));
    }

    // Always hit network regardless of cache freshness
    try {
      debugPrint('[Repo] force-fetching month: $mk');
      final rows = await ApiService.fetchMonth(mk);
      debugPrint('[Repo] force month $mk: ${rows.length} rows');
      await CacheService.set(cacheKey, rows.map(_serializeDayResult).toList());
      _monthCtrl.add(MonthUpdate(mk: mk, rows: rows));
    } catch (e) {
      debugPrint('[Repo] forceLoadMonth error ($mk): $e');
      if (cached == null || cached.isEmpty) {
        _errorCtrl.add('month_error:$mk');
        _monthCtrl.add(MonthUpdate(mk: mk, rows: const []));
      }
    }
  }

  Future<void> reloadMonth(String mk) async {
    await CacheService.delete(CacheService.monthKey(mk));
    await loadMonth(mk);
  }

  List<DayResult>? _readMonthCache(String key) {
    final entry = CacheService.get(key);
    if (entry == null) return null;
    try {
      return (entry['data'] as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return DayResult(
          date: m['date'] as String,
          day: m['day'] as String,
          result2pm: m['result2pm'] as String?,
          result5pm: m['result5pm'] as String?,
          result9pm: m['result9pm'] as String?,
          winners2pm: m['winners2pm'] as int?,
          winners5pm: m['winners5pm'] as int?,
          winners9pm: m['winners9pm'] as int?,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _serializeDayResult(DayResult r) => {
        'date': r.date,
        'day': r.day,
        'result2pm': r.result2pm,
        'result5pm': r.result5pm,
        'result9pm': r.result9pm,
        'winners2pm': r.winners2pm,
        'winners5pm': r.winners5pm,
        'winners9pm': r.winners9pm,
      };

  // ── REALTIME ───────────────────────────────────────────────

  void subscribeRealtime() {
    // Prevent duplicate subscriptions
    if (_isSubscribed) return;
    _isSubscribed = true;

    final iso = toISODate(getPHTime());
    _channel?.unsubscribe();
    _channel = _db
        .channel('ez2:$iso')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ez2_results',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'draw_date',
            value: iso,
          ),
          callback: (_) async {
            await CacheService.delete(CacheService.todayKey(iso));
            await loadToday();
          },
        )
        .subscribe();
  }

  void unsubscribeRealtime() {
    _channel?.unsubscribe();
    _channel = null;
    _isSubscribed = false;
  }

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
}
