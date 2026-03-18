// lib/app_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'repository.dart';
import 'cache_service.dart';
import 'helpers.dart';
import 'models.dart';
import 'connectivity_service.dart';

// Parses "Mar 17, 2026" → DateTime for correct chronological sorting
DateTime _parseShortDate(String d) {
  const months = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };
  try {
    final p = d.split(' ');
    final m = months[p[0]] ?? 1;
    final day = int.parse(p[1].replaceAll(',', ''));
    final yr = int.parse(p[2]);
    return DateTime(yr, m, day);
  } catch (_) {
    return DateTime(2000);
  }
}

class AppProvider extends ChangeNotifier {
  final _repo = EZ2Repository.instance;
  final _connectivity = ConnectivityService.instance;

  // ── Today ─────────────────────────────────────────────────
  DayResult? _todayResult;
  DayResult? get todayResult => _todayResult;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  // ── History ───────────────────────────────────────────────
  final Map<String, List<DayResult>> _historyRows = {};
  Map<String, List<DayResult>> get historyRows => _historyRows;

  final Map<String, bool> _historyLoading = {};
  Map<String, bool> get historyLoading => _historyLoading;

  String _selectedMonth = monthKey(getPHTime());
  String get selectedMonth => _selectedMonth;

  List<String> get availableMonths => buildAvailableMonths(count: 3);

  // Memoised sorted rows — rebuilt only when history changes
  List<DayResult>? _cachedAllRows;
  List<DayResult> get allHistoryRows {
    if (_cachedAllRows != null) return _cachedAllRows!;
    final all = _historyRows.values.expand((r) => r).toList();
    // Use DateTime sort — dates are "Mar 17, 2026" format, string sort is unreliable
    all.sort(
        (a, b) => _parseShortDate(b.date).compareTo(_parseShortDate(a.date)));
    _cachedAllRows = all;
    return all;
  }

  List<DayResult> get allRows => allHistoryRows;

  // Memoised stats — rebuilt only when rows change
  EZ2Stats? _cachedStats;
  EZ2Stats? get stats {
    if (_cachedStats != null) return _cachedStats;
    final rows = allHistoryRows;
    if (rows.isEmpty) return null;
    _cachedStats = computeStats(rows);
    return _cachedStats;
  }

  // ── Subscriptions ─────────────────────────────────────────
  StreamSubscription<DayResult>? _todaySub;
  StreamSubscription<MonthUpdate>? _monthSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _connectivitySub;
  Timer? _smartRefreshTimer;
  Timer? _midnightTimer;

  // ── Init ──────────────────────────────────────────────────
  void init() {
    _todaySub = _repo.onToday.listen((result) {
      _todayResult = result;
      _isRefreshing = false;
      _isOffline = false;
      if (result.hasAnyResult) _cachedStats = null;
      notifyListeners();
    });

    _monthSub = _repo.onMonth.listen((update) {
      _historyRows[update.mk] = update.rows;
      _historyLoading[update.mk] = false;
      _cachedAllRows = null;
      _cachedStats = null;
      notifyListeners();
    });

    _errorSub = _repo.onError.listen((err) {
      _isRefreshing = false;
      if (err == 'offline') _isOffline = true;
      notifyListeners();
    });

    // Listen for connectivity changes to auto-refresh when back online
    _connectivitySub = _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        // Connection restored - refresh data
        _isOffline = false;
        notifyListeners();
        _refreshWhenBackOnline();
      } else {
        _isOffline = true;
        notifyListeners();
      }
    });

    _repo.subscribeRealtime();
    _startSmartTimer();
    _scheduleMidnightReset();

    final isFirstRun = _isFirstRun();
    if (isFirstRun) {
      _initialFetchAll();
    } else {
      // Returning user — show cache instantly, refresh in background
      _isRefreshing = true;
      notifyListeners();
      _repo.loadAll(monthCount: 3).then((_) {
        _isRefreshing = false;
        notifyListeners();
      }).catchError((_) {
        _isRefreshing = false;
        notifyListeners();
      });
    }
  }

  bool _isFirstRun() {
    final ph = getPHTime();
    final iso = toISODate(ph);
    final mk = _selectedMonth;
    return !CacheService.has(CacheService.todayKey(iso)) &&
        !CacheService.has(CacheService.monthKey(mk));
  }

  void _initialFetchAll() {
    _isRefreshing = true;
    for (final mk in buildAvailableMonths(count: 3)) {
      _historyLoading[mk] = true;
    }
    notifyListeners();

    _repo.loadAll(monthCount: 3).then((_) {
      _isRefreshing = false;
      notifyListeners();
    }).catchError((e) {
      debugPrint('[AppProvider] Initial fetch error: $e');
      _isRefreshing = false;
      _isOffline = true;
      notifyListeners();
    });
  }

  /// Refresh data when connectivity is restored
  void _refreshWhenBackOnline() {
    // Prevent concurrent refreshes
    if (_isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();
    _repo.loadAll(monthCount: 3).then((_) {
      _isRefreshing = false;
      _isOffline = false;
      notifyListeners();
    }).catchError((_) {
      _isRefreshing = false;
      notifyListeners();
    });
  }

  void _startSmartTimer() {
    _smartRefreshTimer?.cancel();
    // Poll every 5 minutes during draw window (2PM / 5PM / 9PM PHT)
    // Sites publish combo results within 5-30 minutes after draw
    _smartRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      final ph = getPHTime();
      if (_isInDrawWindow(ph)) {
        _repo.loadToday(forceNetwork: true);
      }
    });
  }

  bool _isInDrawWindow(DateTime ph) {
    // Draw windows: exactly at draw time → 35 min after
    final mins = ph.hour * 60 + ph.minute;
    if (mins >= 840 && mins <= 875) return true; // 2:00PM – 2:35PM
    if (mins >= 1020 && mins <= 1055) return true; // 5:00PM – 5:35PM
    if (mins >= 1260 && mins <= 1295) return true; // 9:00PM – 9:35PM
    return false;
  }

  // ── Today ─────────────────────────────────────────────────
  Future<void> fetchToday() async {
    await _repo.loadToday(forceNetwork: true);
  }

  // ── History ───────────────────────────────────────────────
  Future<void> fetchMonth(String mk) async {
    // Skip if already has data and not stale
    if (_historyRows[mk]?.isNotEmpty == true &&
        !CacheService.isExpired(
            CacheService.monthKey(mk), CacheService.monthTtl(mk))) return;
    // Skip if already loading
    if (_historyLoading[mk] == true) return;
    _historyLoading[mk] = true;
    notifyListeners();
    await _repo.loadMonth(mk);
  }

  void setMonth(String mk) {
    if (_selectedMonth == mk) return;
    _selectedMonth = mk;
    notifyListeners();
    // Fetch if no data yet, or if stuck (loading flag but no data after refresh)
    final hasData = _historyRows[mk]?.isNotEmpty == true;
    final isLoading = _historyLoading[mk] == true;
    if (!hasData && !isLoading) {
      fetchMonth(mk);
    } else if (!hasData && isLoading && !_isRefreshing) {
      // Stuck loading — reset and retry
      _historyLoading[mk] = false;
      fetchMonth(mk);
    }
  }

  // ── Midnight reset ────────────────────────────────────────
  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final ph = getPHTime();
    final nextDay = DateTime(ph.year, ph.month, ph.day + 1);
    _midnightTimer = Timer(nextDay.difference(ph), () {
      _todayResult = null;
      _cachedAllRows = null;
      _cachedStats = null;
      _selectedMonth = monthKey(getPHTime());
      _repo.resubscribeForNewDay();
      _repo.loadAll(monthCount: 3).catchError((_) {});
      _scheduleMidnightReset();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _todaySub?.cancel();
    _monthSub?.cancel();
    _errorSub?.cancel();
    _connectivitySub?.cancel();
    _smartRefreshTimer?.cancel();
    _midnightTimer?.cancel();
    _repo.dispose();
    super.dispose();
  }
}
