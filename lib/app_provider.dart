// lib/app_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'repository.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'helpers.dart';
import 'models.dart';
import 'connectivity_service.dart';

DateTime _parseShortDate(String d) {
  const months = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
    'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
    'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };
  try {
    final p   = d.split(' ');
    final m   = months[p[0]] ?? 1;
    final day = int.parse(p[1].replaceAll(',', ''));
    final yr  = int.parse(p[2]);
    return DateTime(yr, m, day);
  } catch (_) {
    return DateTime(2000);
  }
}

class AppProvider extends ChangeNotifier {
  final _repo         = EZ2Repository.instance;
  final _connectivity = ConnectivityService.instance;

  bool _initialized = false;

  // ── Today ─────────────────────────────────────────────────
  DayResult? _todayResult;
  DayResult? get todayResult => _todayResult;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  // ── History ───────────────────────────────────────────────
  final Map<String, List<DayResult>> _historyRows    = {};
  final Map<String, bool>            _historyLoading = {};

  Map<String, List<DayResult>> get historyRows    => _historyRows;
  Map<String, bool>            get historyLoading => _historyLoading;

  // ── Year / month navigation ───────────────────────────────
  List<int>  _availableYears = [];
  List<int>  get availableYears => _availableYears;

  int _selectedYear;
  int get selectedYear => _selectedYear;

  String _selectedMonth;
  String get selectedMonth => _selectedMonth;

  AppProvider()
    : _selectedYear  = getPHTime().year,
      _selectedMonth = monthKey(getPHTime());

  /// All months in the selected year, newest first, capped at today.
  List<String> get availableMonths => buildMonthsForYear(_selectedYear);

  /// Legacy 3-month list used by init pre-fetch.
  List<String> get _recentMonths => buildAvailableMonths(count: 3);

  // Memoised sorted rows
  List<DayResult>? _cachedAllRows;
  List<DayResult> get allHistoryRows {
    if (_cachedAllRows != null) return _cachedAllRows!;
    final all = _historyRows.values.expand((r) => r).toList()
      ..sort((a, b) => _parseShortDate(b.date).compareTo(_parseShortDate(a.date)));
    return _cachedAllRows = all;
  }

  List<DayResult> get allRows => allHistoryRows;

  // Memoised stats
  EZ2Stats? _cachedStats;
  EZ2Stats? get stats {
    if (_cachedStats != null) return _cachedStats;
    final rows = allHistoryRows;
    if (rows.isEmpty) return null;
    return _cachedStats = computeStats(rows);
  }

  // ── Subscriptions ─────────────────────────────────────────
  StreamSubscription<DayResult>?   _todaySub;
  StreamSubscription<MonthUpdate>? _monthSub;
  StreamSubscription<String>?      _errorSub;
  StreamSubscription<bool>?        _connectivitySub;

  Timer? _smartRefreshTimer;
  Timer? _connectivityDebounce;
  Timer? _midnightTimer;

  // ── Init ──────────────────────────────────────────────────

  void init() {
    if (_initialized) return;
    _initialized = true;

    _todaySub = _repo.onToday.listen((result) {
      _todayResult  = result;
      _isRefreshing = false;
      _isOffline    = false;
      if (result.hasAnyResult) _cachedStats = null;
      notifyListeners();
    });

    _monthSub = _repo.onMonth.listen((update) {
      _historyRows[update.mk]    = update.rows;
      _historyLoading[update.mk] = false;   // ← always clears loading, even on empty result
      _cachedAllRows = null;
      _cachedStats   = null;
      notifyListeners();
    });

    _errorSub = _repo.onError.listen((err) {
      _isRefreshing = false;
      if (err == 'offline') _isOffline = true;
      // ── BUG FIX: clear any stuck loading flags when we go offline ──
      for (final mk in _historyLoading.keys.toList()) {
        if (_historyLoading[mk] == true && _historyRows[mk] == null) {
          _historyLoading[mk] = false;
        }
      }
      notifyListeners();
    });

    _connectivitySub = _connectivity.onConnectivityChanged.listen((isOnline) {
      _connectivityDebounce?.cancel();
      if (isOnline) {
        _connectivityDebounce = Timer(const Duration(milliseconds: 800), () {
          if (_isOffline) {
            _isOffline = false;
            notifyListeners();
          }
          _refreshWhenBackOnline();
        });
      } else {
        if (!_isOffline) {
          _isOffline = true;
          notifyListeners();
        }
      }
    });

    _repo.subscribeRealtime();
    _startSmartTimer();
    _scheduleMidnightReset();

    // Load available years in background — no blocking
    _loadAvailableYears();

    // Initial load
    _isRefreshing = true;
    if (_isFirstRun()) {
      for (final mk in _recentMonths) {
        _historyLoading[mk] = true;
      }
    }
    notifyListeners();

    _repo.loadAll(monthCount: 3).then((_) {
      _isRefreshing = false;
      notifyListeners();
    }).catchError((e) {
      debugPrint('[AppProvider] init fetch error: $e');
      _isRefreshing = false;
      _isOffline    = true;
      // Clear stuck loading flags
      for (final mk in _recentMonths) {
        _historyLoading[mk] = false;
      }
      notifyListeners();
    });
  }

  Future<void> _loadAvailableYears() async {
    try {
      final years = await ApiService.fetchAvailableYears();
      if (years.isNotEmpty) {
        _availableYears = years;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AppProvider] fetchAvailableYears error: $e');
      // Fallback: just current year
      _availableYears = [getPHTime().year];
      notifyListeners();
    }
  }

  // ── Year / month selection ─────────────────────────────────

  void setYear(int year) {
    if (_selectedYear == year) return;
    _selectedYear  = year;
    // Select the most recent month in that year
    _selectedMonth = buildMonthsForYear(year).first;
    notifyListeners();
    _ensureMonthLoaded(_selectedMonth);
  }

  void setMonth(String mk) {
    if (_selectedMonth == mk) return;
    _selectedMonth = mk;
    notifyListeners();
    _ensureMonthLoaded(mk);
  }

  /// Ensures [mk] is either loaded or actively loading.
  /// Resets a stuck loading flag before retrying.
  void _ensureMonthLoaded(String mk) {
    final hasData   = _historyRows[mk]?.isNotEmpty == true;
    final isLoading = _historyLoading[mk] == true;

    if (hasData && !CacheService.isStale(CacheService.monthKey(mk), CacheService.monthTtl(mk))) {
      return; // fresh data — nothing to do
    }

    if (isLoading) {
      // If it's been stuck loading with no result, reset and retry
      if (_historyRows[mk] == null) {
        _historyLoading[mk] = false;
        fetchMonth(mk);
      }
      return;
    }

    fetchMonth(mk);
  }

  // ── Today ─────────────────────────────────────────────────

  Future<void> fetchToday() => _repo.loadToday(force: true);

  // ── History ───────────────────────────────────────────────

  Future<void> fetchMonth(String mk) async {
    if (_historyRows[mk]?.isNotEmpty == true &&
        !CacheService.isStale(CacheService.monthKey(mk), CacheService.monthTtl(mk))) return;
    if (_historyLoading[mk] == true) return;
    _historyLoading[mk] = true;
    notifyListeners();
    await _repo.loadMonth(mk);
  }

  // ── Internals ─────────────────────────────────────────────

  bool _isFirstRun() {
    final ph  = getPHTime();
    final iso = toISODate(ph);
    return !CacheService.has(CacheService.todayKey(iso)) &&
        !CacheService.has(CacheService.monthKey(_selectedMonth));
  }

  void _refreshWhenBackOnline() {
    if (_isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();
    _repo.loadAll(monthCount: 3).then((_) {
      _isRefreshing = false;
      _isOffline    = false;
      notifyListeners();
    }).catchError((_) {
      _isRefreshing = false;
      notifyListeners();
    });
  }

  void _startSmartTimer() {
    _smartRefreshTimer?.cancel();
<<<<<<< HEAD
    final inWindow = _isInDrawWindow(getPHTime());
    _smartRefreshTimer = Timer(
      inWindow ? const Duration(seconds: 5) : const Duration(seconds: 60),
      () {
        if (_isInDrawWindow(getPHTime())) {
          _repo.loadToday(force: true);
        }
        _startSmartTimer();
      },
    );
=======
    // Poll every 5 minutes during draw window (2PM / 5PM / 9PM PHT)
    // Sites publish combo results within 5-30 minutes after draw
    _smartRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      final ph = getPHTime();
      if (_isInDrawWindow(ph)) {
        _repo.loadToday(forceNetwork: true);
      }
    });
>>>>>>> 040d0d8d8116ae221e5f6e6341a7441b44ce6370
  }

  bool _isInDrawWindow(DateTime ph) {
    final mins = ph.hour * 60 + ph.minute;
    return (mins >= 840  && mins <= 875)
        || (mins >= 1020 && mins <= 1055)
        || (mins >= 1260 && mins <= 1295);
  }

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final ph      = getPHTime();
    final nextDay = DateTime(ph.year, ph.month, ph.day + 1);
    _midnightTimer = Timer(nextDay.difference(ph), () {
      _todayResult   = null;
      _cachedAllRows = null;
      _cachedStats   = null;
      _selectedYear  = getPHTime().year;
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
    _connectivityDebounce?.cancel();
    _smartRefreshTimer?.cancel();
    _midnightTimer?.cancel();
    _repo.dispose();
    super.dispose();
  }
}
