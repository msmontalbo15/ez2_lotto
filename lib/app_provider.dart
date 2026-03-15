// lib/app_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'helpers.dart';
import 'models.dart';

class AppProvider extends ChangeNotifier {
  // ── Today ──────────────────────────────────────────────────
  late DayResult liveToday;
  bool isRefreshing = false;
  String? fetchError;
  DateTime? lastUpdate;

  // ── History: monthKey → rows ───────────────────────────────
  final Map<String, List<DayResult>> historyData = {};
  final Map<String, bool> historyLoading = {};
  final Map<String, String?> historyError = {};

  // ── Timers ────────────────────────────────────────────────
  Timer? _clockTimer;
  Timer? _refreshTimer;
  DateTime currentTime = DateTime.now();

  AppProvider() {
    final ph = getPHTime();
    liveToday = DayResult.empty(toShortDate(ph), toDayName(ph));
    _startClock();
    _startAutoRefresh();
    fetchToday(triggerCron: true);
  }

  // ── All rows (today + history) for stats & ticket ─────────
  List<DayResult> get allRows {
    final today = liveToday;
    final hist = historyData.values
        .expand((rows) => rows)
        .where((r) => r.date != today.date)
        .toList();
    return [today, ...hist];
  }

  // ── Clock ─────────────────────────────────────────────────
  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      currentTime = DateTime.now();
      notifyListeners();
    });
  }

  // ── Auto-refresh every 3 minutes ──────────────────────────
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      fetchToday(triggerCron: true);
    });
  }

  // ── Fetch today ───────────────────────────────────────────
  Future<void> fetchToday({bool triggerCron = false}) async {
    isRefreshing = true;
    fetchError = null;
    notifyListeners();

    try {
      // 1. Fast DB read first
      final dbResult = await ApiService.fetchTodayFromDB();
      if (dbResult != null) {
        liveToday = dbResult;
        notifyListeners();
      }

      // 2. Trigger background cron to pull fresh results
      if (triggerCron) {
        final newSlots = await ApiService.triggerFetchToday();
        if (newSlots.isNotEmpty) {
          // Re-read DB to get newly saved slots
          final fresh = await ApiService.fetchTodayFromDB();
          if (fresh != null) liveToday = fresh;
        }
      }

      lastUpdate = DateTime.now();
    } catch (e) {
      fetchError = 'Hindi ma-kuha ang resulta. Subukan ulit mamaya.';
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  // ── Fetch a month's history ───────────────────────────────
  Future<void> fetchMonth(String monthKey) async {
    if (historyData.containsKey(monthKey)) return; // already loaded

    historyLoading[monthKey] = true;
    historyError[monthKey] = null;
    notifyListeners();

    try {
      final rows = await ApiService.fetchMonth(monthKey);
      historyData[monthKey] = rows;
    } catch (e) {
      historyError[monthKey] = e.toString();
    } finally {
      historyLoading[monthKey] = false;
      notifyListeners();
    }
  }

  // ── Retry a failed month fetch ────────────────────────────
  void retryMonth(String monthKey) {
    historyData.remove(monthKey);
    fetchMonth(monthKey);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
