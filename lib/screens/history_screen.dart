// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../helpers.dart';
import '../models.dart';
import '../responsive.dart';

// Parses "Mar 17, 2026" → DateTime for correct chronological sorting
DateTime _parseDate(String d) {
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
    final p = d.split(' '); // ["Mar", "17,", "2026"]
    final m = months[p[0]] ?? 1;
    final day = int.parse(p[1].replaceAll(',', ''));
    final yr = int.parse(p[2]);
    return DateTime(yr, m, day);
  } catch (_) {
    return DateTime(2000); // fallback keeps bad data at bottom
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prov = context.read<AppProvider>();
      for (final mk in prov.availableMonths) {
        if (prov.historyRows[mk]?.isNotEmpty != true &&
            prov.historyLoading[mk] != true) {
          prov.fetchMonth(mk);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final prov = context.watch<AppProvider>();
    final months = prov.availableMonths;
    final mk = prov.selectedMonth;

    // Use ONLY the rows for the currently selected month
    final rows = prov.historyRows[mk];
    final isLoading =
        prov.historyLoading[mk] == true && (rows == null || rows.isEmpty);

    final todayDate = toShortDate(getPHTime());
    final ph = getPHTime();
    final isCurrent = mk == monthKey(ph);

    // Build visible rows for this specific month
    List<DayResult> visible = [];

    if (rows != null) {
      // Start with the DB rows for this month
      final rowMap = <String, DayResult>{};
      for (final r in rows) {
        rowMap[r.date] = r;
      }

      // If current month, inject live today + ensure today row exists
      if (isCurrent) {
        final liveToday = prov.todayResult;
        if (liveToday != null && liveToday.hasAnyResult) {
          rowMap[todayDate] = liveToday;
        } else if (!rowMap.containsKey(todayDate)) {
          // Add empty row for today so it always appears
          rowMap[todayDate] = DayResult(
            date: todayDate,
            day: toDayName(ph),
          );
        }
      }

      // Sort newest first — parse to DateTime for correct ordering
      // (dates are stored as "Mar 17, 2026" — string compare alone is unreliable)
      visible = rowMap.values.toList()
        ..sort((a, b) => _parseDate(b.date).compareTo(_parseDate(a.date)));

      // Filter: only show days up to today (no future dates),
      // and only show days that either have results OR are today
      visible = visible.where((r) {
        if (r.date == todayDate) return true; // always show today
        if (r.hasAnyResult) return true; // show any day with data
        return false;
      }).toList();
    }

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(children: [
          // ── Header ─────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF1A5276),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              context.horizontalPadding,
              context.headerPaddingTop,
              context.horizontalPadding,
              24,
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('HISTORY',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: context.titleFontSize,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Previous EZ2 results',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 16)),
              const SizedBox(height: 16),
              // Month tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: months.map((m) {
                    final selected = m == mk;
                    return GestureDetector(
                      onTap: () => prov.setMonth(m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: selected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _monthLabelEn(m),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? const Color(0xFF1A5276)
                                : Colors.white,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ]),
          ),

          // ── Column headers ──────────────────────────────
          Container(
            margin: EdgeInsets.fromLTRB(
                context.horizontalPadding, 14, context.horizontalPadding, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: const Color(0xFF1A5276),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              SizedBox(
                  width: context.isSmallPhone ? 52 : 72,
                  child: const Text('DATE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5))),
              Expanded(
                  child: Center(
                      child: Text('2 PM',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)))),
              Expanded(
                  child: Center(
                      child: Text('5 PM',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)))),
              Expanded(
                  child: Center(
                      child: Text('9 PM',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)))),
            ]),
          ),

          // ── Rows ────────────────────────────────────────
          Expanded(
            child: isLoading
                ? _SkeletonList()
                : visible.isEmpty
                    ? _EmptyState(onRetry: () => prov.fetchMonth(mk))
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(context.horizontalPadding,
                            8, context.horizontalPadding, 24),
                        itemCount: visible.length,
                        itemBuilder: (ctx, i) {
                          final r = visible[i];
                          final isToday = r.date == todayDate;
                          return _HistoryRow(
                              row: r, isToday: isToday, isDarkMode: isDarkMode);
                        },
                      ),
          ),

          if (prov.isOffline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFFF3CD),
              child: const Row(children: [
                Icon(Icons.wifi_off_rounded,
                    size: 14, color: Color(0xFF856404)),
                SizedBox(width: 6),
                Text('Offline — showing cached data',
                    style: TextStyle(fontSize: 12, color: Color(0xFF856404))),
              ]),
            ),
        ]),
      ),
    );
  }

  String _monthLabelEn(String mk) {
    final parts = mk.split('-');
    if (parts.length != 2) return mk;
    const months = [
      '',
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    final m = int.tryParse(parts[1]) ?? 0;
    return '${months[m]} ${parts[0]}';
  }
}

// ── History Row ───────────────────────────────────────────────
class _HistoryRow extends StatelessWidget {
  final DayResult row;
  final bool isToday;
  final bool isDarkMode;
  const _HistoryRow(
      {required this.row, required this.isToday, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDarkMode
            ? (isToday ? const Color(0xFF2C2C2C) : const Color(0xFF1E1E1E))
            : (isToday ? const Color(0xFFFFF8E1) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? const Color(0xFFFFCA2C)
              : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
          width: isToday ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(children: [
          SizedBox(
            width: 72,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (isToday)
                Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFCA2C),
                      borderRadius: BorderRadius.circular(5)),
                  child: const Text('TODAY',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF856404))),
                ),
              Text(_dayNum(row.date),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2C3E50))),
              Text(_dayName(row.date),
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          Expanded(
              child: _DrawCell(
                  combo: row.result2pm,
                  winners: row.winners2pm,
                  color: const Color(0xFFE67E22))),
          Expanded(
              child: _DrawCell(
                  combo: row.result5pm,
                  winners: row.winners5pm,
                  color: const Color(0xFF8E44AD))),
          Expanded(
              child: _DrawCell(
                  combo: row.result9pm,
                  winners: row.winners9pm,
                  color: const Color(0xFF2C3E50))),
        ]),
      ),
    );
  }

  String _dayNum(String d) {
    final p = d.split(' ');
    if (p.length >= 2) return p[1].replaceAll(',', '');
    return d;
  }

  String _dayName(String d) {
    try {
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
        'Dec': 12
      };
      final p = d.split(' ');
      final m = months[p[0]] ?? 1;
      final dy = int.parse(p[1].replaceAll(',', ''));
      final y = int.parse(p[2]);
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[DateTime(y, m, dy).weekday - 1];
    } catch (_) {
      return '';
    }
  }
}

// ── Draw Cell ─────────────────────────────────────────────────
class _DrawCell extends StatelessWidget {
  final String? combo;
  final int? winners;
  final Color color;
  const _DrawCell(
      {required this.combo, required this.winners, required this.color});

  @override
  Widget build(BuildContext context) {
    if (combo == null) {
      return Center(
          child: Text('—',
              style: TextStyle(fontSize: 22, color: Colors.grey.shade300)));
    }
    final parts = combo!.split('-');
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Ball(n: parts.isNotEmpty ? parts[0] : '?', color: color),
        const SizedBox(width: 3),
        Text('-', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        const SizedBox(width: 3),
        _Ball(n: parts.length > 1 ? parts[1] : '?', color: color),
      ]),
      if (winners != null) ...[
        const SizedBox(height: 3),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.emoji_events_rounded,
              size: 10, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 2),
          Text('$winners',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ]),
      ],
    ]);
  }
}

class _Ball extends StatelessWidget {
  final String n;
  final Color color;
  const _Ball({required this.n, required this.color});
  @override
  Widget build(BuildContext context) {
    final size = context.lottoBallSize(baseSize: 32.0);
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [
        BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 3,
            offset: const Offset(0, 1))
      ]),
      child: Center(
          child: Text(n,
              style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w900,
                  color: Colors.white))),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 10,
      itemBuilder: (_, __) => Container(
        height: 64,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      const Text('Walang datos',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey)),
      const SizedBox(height: 14),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('SUBUKAN ULIT',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A5276),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]));
  }
}
