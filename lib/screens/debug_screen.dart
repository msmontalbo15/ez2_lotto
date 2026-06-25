// lib/screens/debug_screen.dart
//
// SECURITY: This screen is gated to DEBUG builds only.
// It is never compiled into release APKs because the entire body is
// wrapped in a kDebugMode guard, and the widget asserts on creation.
//
// To use during development:
//   Step 1: Add import to main.dart:  import 'screens/debug_screen.dart';
//   Step 2: Change home: const _Shell()  →  home: const DebugScreen()
//   Step 3: Run app in DEBUG mode, tap "Run Diagnostics", copy output
//   Step 4: Revert main.dart change once fixed

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';
import '../helpers.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key}) : assert(kDebugMode, 'DebugScreen must NOT be used in release/profile builds.');

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  // Entire implementation is stripped in non-debug builds
  final _db = Supabase.instance.client;
  final _lines = <_Line>[];
  bool _running = false;

  void _log(String msg, {Color color = Colors.white70}) {
    setState(() => _lines.add(_Line(msg, color)));
    debugPrint(msg);
  }

  Future<void> _run() async {
    if (!kDebugMode) return; // Extra runtime guard
    setState(() {
      _lines.clear();
      _running = true;
    });

    _log('══ SUPABASE CONFIG ══', color: Colors.amber);
    _log('URL: $kSupabaseUrl');
    // Only show first 20 chars of the key — never log full credentials
    final keyPreview = kSupabaseAnonKey.length > 20
        ? '${kSupabaseAnonKey.substring(0, 20)}…[REDACTED]'
        : '[REDACTED]';
    _log('Key: $keyPreview');

    // ── 1. Fetch one row with all columns ─────────────────
    _log('\n══ SELECT * LIMIT 1 ══', color: Colors.amber);
    try {
      final rows = await _db
          .from('ez2_results')
          .select('*')
          .limit(1)
          .timeout(const Duration(seconds: 10));

      if (rows.isEmpty) {
        _log('⚠ Table is EMPTY — no rows in ez2_results', color: Colors.orange);
        _log('  → Run Sync History in the web dashboard first',
            color: Colors.orange);
      } else {
        _log('✓ Table has data. Columns:', color: Colors.greenAccent);
        rows.first.forEach((k, v) {
          _log('  $k = $v');
        });
      }
    } catch (e) {
      _log('✗ Failed: $e', color: Colors.redAccent);
    }

    // ── 2. Fetch with exact app columns ───────────────────
    _log('\n══ APP COLUMNS SELECT ══', color: Colors.amber);
    try {
      final today = toISODate(getPHTime());
      _log('Today (PHT): $today');

      final rows = await _db
          .from('ez2_results')
          .select('draw_date, draw_time, num1, num2, winner_count, created_at')
          .eq('draw_date', today)
          .order('draw_time')
          .timeout(const Duration(seconds: 10));

      _log('✓ Rows for today: ${rows.length}', color: Colors.greenAccent);
      for (final r in rows) {
        _log('  ${r['draw_date']} | ${r['draw_time']} | '
            '${r['num1']}-${r['num2']} | winners:${r['winner_count']}');
      }
    } catch (e) {
      _log('✗ App columns failed: $e', color: Colors.redAccent);
    }

    // ── 3. Check fetch_log ────────────────────────────────
    _log('\n══ FETCH LOG (last 3) ══', color: Colors.amber);
    try {
      final rows = await _db
          .from('ez2_fetch_log')
          .select('fetch_date, status, records_inserted')
          .order('fetch_date', ascending: false)
          .limit(3)
          .timeout(const Duration(seconds: 10));

      if (rows.isEmpty) {
        _log('⚠ fetch_log is empty — Edge Function has never run',
            color: Colors.orange);
      } else {
        for (final r in rows) {
          final s = r['status'];
          final c = s == 'success'
              ? Colors.greenAccent
              : s == 'failed'
                  ? Colors.redAccent
                  : Colors.orange;
          _log('  ${r['fetch_date']} | $s | recs:${r['records_inserted']}',
              color: c);
        }
      }
    } catch (e) {
      _log('✗ fetch_log error: $e', color: Colors.redAccent);
    }

    // ── 4. Realtime check ─────────────────────────────────
    _log('\n══ REALTIME ══', color: Colors.amber);
    try {
      final channel = _db.channel('debug-test');
      channel.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _log('✓ Realtime connected', color: Colors.greenAccent);
        } else if (error != null) {
          _log('✗ Realtime error: $error', color: Colors.redAccent);
        }
      });
      await Future.delayed(const Duration(seconds: 2));
      await channel.unsubscribe();
    } catch (e) {
      _log('✗ Realtime failed: $e', color: Colors.redAccent);
    }

    setState(() => _running = false);
    _log('\n══ DONE ══', color: Colors.amber);
  }

  @override
  Widget build(BuildContext context) {
    // Double guard — renders a warning screen in non-debug builds
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('DEBUG SCREEN DISABLED IN RELEASE')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'Supabase Debug [DEBUG BUILD ONLY]',
          style: TextStyle(
            color: Colors.amber,
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
        actions: [
          if (_running)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.amber,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.amber),
              onPressed: _run,
              tooltip: 'Re-run diagnostics',
            ),
        ],
      ),
      body: _lines.isEmpty && !_running
          ? Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                onPressed: _run,
                icon: const Icon(Icons.play_arrow),
                label: const Text(
                  'Run Diagnostics',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _lines.length,
              itemBuilder: (_, i) => Text(
                _lines[i].text,
                style: TextStyle(
                  color: _lines[i].color,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.7,
                ),
              ),
            ),
    );
  }
}

class _Line {
  final String text;
  final Color color;
  const _Line(this.text, this.color);
}
