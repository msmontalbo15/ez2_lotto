// lib/logger.dart
//
// Leveled logger — debug output is completely stripped in release builds.
// Use this instead of debugPrint() everywhere in the codebase.
//
// Usage:
//   Log.d('ApiService', 'fetchAll 2026-01-01 → 2026-01-31');
//   Log.w('Cache', 'stale entry evicted');
//   Log.e('Repo', 'network error: $e');

import 'package:flutter/foundation.dart';

class Log {
  Log._();

  /// Debug — stripped in release.
  static void d(String tag, String msg) {
    if (kDebugMode) debugPrint('[$tag] $msg');
  }

  /// Warning — stripped in release.
  static void w(String tag, String msg) {
    if (kDebugMode) debugPrint('[WARN][$tag] $msg');
  }

  /// Error — stripped in release.
  static void e(String tag, String msg) {
    if (kDebugMode) debugPrint('[ERROR][$tag] $msg');
  }
}
