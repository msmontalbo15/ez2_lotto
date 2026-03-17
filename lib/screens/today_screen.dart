// lib/screens/today_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../helpers.dart';
import '../models.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Timer? _clockTimer;
  DateTime _now = getPHTime();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = getPHTime());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final today = prov.todayResult;
    final allRows = prov.allHistoryRows;
    // Only show skeleton on first ever load (no cache at all)
    final isLoading =
        prov.isRefreshing && today == null && prov.allHistoryRows.isEmpty;

    // Find the most recent draw result:
    // Priority: live todayResult (9pm→5pm→2pm), then history newest first
    DayResult? lastResult;
    String? lastSlot;

    // Check live today first
    if (today != null && today.hasAnyResult) {
      for (final slot in ['9pm', '5pm', '2pm']) {
        final r = slot == '9pm'
            ? today.result9pm
            : slot == '5pm'
                ? today.result5pm
                : today.result2pm;
        if (r != null) {
          lastResult = today;
          lastSlot = slot;
          break;
        }
      }
    }

    // Fall back to history if today has no results yet
    if (lastResult == null) {
      // allRows is sorted newest→oldest by DateTime (fixed in app_provider)
      for (final row in allRows) {
        if (today != null && row.date == today.date)
          continue; // skip today — already checked
        for (final slot in ['9pm', '5pm', '2pm']) {
          final r = slot == '9pm'
              ? row.result9pm
              : slot == '5pm'
                  ? row.result5pm
                  : row.result2pm;
          if (r != null) {
            lastResult = row;
            lastSlot = slot;
            break;
          }
        }
        if (lastResult != null) break;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Fire and return — UI updates via stream, no blocking wait
            prov.fetchToday();
            await Future.delayed(const Duration(milliseconds: 500));
          },
          color: const Color(0xFFC0392B),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(now: _now)),
              if (prov.isOffline)
                SliverToBoxAdapter(
                    child: _OfflineBanner(onRetry: prov.fetchToday)),

              // ── Most Recent Draw ─────────────────────────
              if (lastResult != null && lastSlot != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _RecentResultCard(row: lastResult, slot: lastSlot),
                  ),
                ),

              // ── Today's Draws ────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const _SectionLabel(text: "RESULTA NGAYON"),
                    const SizedBox(height: 10),
                    _DrawCard(
                      slot: '2pm',
                      label: '2:00 NG HAPON',
                      icon: Icons.wb_sunny_outlined,
                      color: const Color(0xFFE67E22),
                      result: today?.result2pm,
                      winners: today?.winners2pm,
                      isLoading: isLoading,
                      now: _now,
                    ),
                    const SizedBox(height: 12),
                    _DrawCard(
                      slot: '5pm',
                      label: '5:00 NG HAPON',
                      icon: Icons.wb_twilight,
                      color: const Color(0xFF8E44AD),
                      result: today?.result5pm,
                      winners: today?.winners5pm,
                      isLoading: isLoading,
                      now: _now,
                    ),
                    const SizedBox(height: 12),
                    _DrawCard(
                      slot: '9pm',
                      label: '9:00 NG GABI',
                      icon: Icons.nightlight_round,
                      color: const Color(0xFF2C3E50),
                      result: today?.result9pm,
                      winners: today?.winners9pm,
                      isLoading: isLoading,
                      now: _now,
                    ),
                    const SizedBox(height: 24),
                    const _HowToPlay(),
                    const SizedBox(height: 16),
                    const _Copyright(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Draw status enum ─────────────────────────────────────────
enum _LiveStatus { live, waiting, closed }

_LiveStatus _getLiveStatus(DateTime now) {
  // Draw times: 2PM, 5PM, 9PM PHT
  // LIVE: within the draw hour (results published ~15 min after draw)
  // WAITING: 10 min before draw
  // CLOSED: all other times
  final drawHours = [14, 17, 21]; // 2pm, 5pm, 9pm
  for (final dh in drawHours) {
    final minuteOfDay = now.hour * 60 + now.minute;
    final drawMin = dh * 60;
    if (minuteOfDay >= drawMin - 10 && minuteOfDay < drawMin) {
      return _LiveStatus.waiting; // 10 min before draw
    }
    if (minuteOfDay >= drawMin && minuteOfDay < drawMin + 30) {
      return _LiveStatus.live; // draw window open (up to 30 min after)
    }
  }
  return _LiveStatus.closed;
}

String _nextDrawLabel(DateTime now) {
  final drawHours = [14, 17, 21];
  final drawNames = ['2:00 PM', '5:00 PM', '9:00 PM'];
  final nowMin = now.hour * 60 + now.minute;
  for (int i = 0; i < drawHours.length; i++) {
    if (nowMin < drawHours[i] * 60) {
      final diff = drawHours[i] * 60 - nowMin;
      final h = diff ~/ 60;
      final m = diff % 60;
      final timeLeft = h > 0 ? '${h}h ${m}m' : '${m}m';
      return '${drawNames[i]} (in $timeLeft)';
    }
  }
  // After last draw — next is 2PM tomorrow
  final diff = (24 * 60 - nowMin) + 14 * 60;
  final h = diff ~/ 60;
  final m = diff % 60;
  return '2:00 PM tomorrow (in ${h}h ${m}m)';
}

// ── Header ────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final DateTime now;
  const _Header({required this.now});

  @override
  Widget build(BuildContext context) {
    final dayName = toDayName(now).toUpperCase();
    final dateStr = toShortDate(now);
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final timeStr =
        '${h.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour < 12 ? 'AM' : 'PM'}';
    final status = _getLiveStatus(now);

    // Indicator appearance based on status
    final Color dotColor;
    final Color labelColor;
    final String label;
    switch (status) {
      case _LiveStatus.live:
        dotColor = Colors.greenAccent.shade200;
        labelColor = Colors.greenAccent.shade200;
        label = 'LIVE';
      case _LiveStatus.waiting:
        dotColor = Colors.amberAccent.shade200;
        labelColor = Colors.amberAccent.shade200;
        label = 'SOON';
      case _LiveStatus.closed:
        dotColor = Colors.white.withValues(alpha: 0.4);
        labelColor = Colors.white.withValues(alpha: 0.5);
        label = 'CLOSED';
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFC0392B),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20)),
            child: Text('EZ2 • 2D LOTTO',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
          ),
          const Spacer(),
          // Animated pulsing dot only when LIVE
          if (status == _LiveStatus.live)
            _PulsingDot(color: dotColor)
          else
            Icon(Icons.circle, size: 10, color: dotColor),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: labelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        const Text('RESULTA NGAYON',
            style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('$dayName, $dateStr',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 17,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(timeStr,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 15,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        // Next draw info when closed
        if (status == _LiveStatus.closed)
          Text('Next draw: ${_nextDrawLabel(now)}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        if (status == _LiveStatus.waiting)
          Text('Draw starting soon: ${_nextDrawLabel(now)}',
              style: TextStyle(
                  color: Colors.amberAccent.shade100.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Pulsing dot (shown only when LIVE) ───────────────────────
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Icon(Icons.circle,
          size: 10, color: widget.color.withValues(alpha: _anim.value)),
    );
  }
}

// ── Offline Banner ────────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _OfflineBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          border: Border.all(color: const Color(0xFFFFCA2C)),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, color: Color(0xFF856404), size: 26),
        const SizedBox(width: 12),
        const Expanded(
            child: Text('Walang internet. Nagpapakita ng nakaimbak na datos.',
                style: TextStyle(
                    color: Color(0xFF856404),
                    fontSize: 15,
                    fontWeight: FontWeight.w600))),
        TextButton(
            onPressed: onRetry,
            child: const Text('SUBUKAN',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF888888),
            letterSpacing: 1.2));
  }
}

// ── Recent Result Card ────────────────────────────────────────
class _RecentResultCard extends StatelessWidget {
  final DayResult row;
  final String slot;
  const _RecentResultCard({required this.row, required this.slot});

  String get _combo => slot == '9pm'
      ? row.result9pm!
      : slot == '5pm'
          ? row.result5pm!
          : row.result2pm!;
  int? get _winners => slot == '9pm'
      ? row.winners9pm
      : slot == '5pm'
          ? row.winners5pm
          : row.winners2pm;
  String get _slotLabel => slot == '2pm'
      ? '2:00 PM'
      : slot == '5pm'
          ? '5:00 PM'
          : '9:00 PM';

  @override
  Widget build(BuildContext context) {
    final parts = _combo.split('-');
    final n1 = parts.isNotEmpty ? parts[0] : '?';
    final n2 = parts.length > 1 ? parts[1] : '?';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1A252F), Color(0xFF2C3E50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF2C3E50).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20)),
            child: const Text('PINAKABAGONG RESULTA',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.date,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            Text(_slotLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ]),
          const Spacer(),
          Row(children: [
            _GlowBall(number: n1),
            const SizedBox(width: 10),
            Text('-',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 28,
                    fontWeight: FontWeight.w200)),
            const SizedBox(width: 10),
            _GlowBall(number: n2),
          ]),
        ]),
        if (_winners != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.emoji_events_rounded,
                color: Colors.amber.shade300, size: 18),
            const SizedBox(width: 6),
            Text('$_winners nanalo',
                style: TextStyle(
                    color: Colors.amber.shade200,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ]),
        ],
      ]),
    );
  }
}

class _GlowBall extends StatelessWidget {
  final String number;
  const _GlowBall({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
      ),
      child: Center(
          child: Text(number,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900))),
    );
  }
}

// ── Draw Card ─────────────────────────────────────────────────
class _DrawCard extends StatelessWidget {
  final String slot, label;
  final IconData icon;
  final Color color;
  final String? result;
  final int? winners;
  final bool isLoading;
  final DateTime now;
  const _DrawCard(
      {required this.slot,
      required this.label,
      required this.icon,
      required this.color,
      required this.result,
      required this.winners,
      required this.isLoading,
      required this.now});

  bool get _hasPassed {
    final h = now.hour;
    if (slot == '2pm') return h >= 14;
    if (slot == '5pm') return h >= 17;
    return h >= 21;
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = result != null;
    final waiting = _hasPassed && !hasResult;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 3))
        ],
        border: Border.all(
            color:
                hasResult ? color.withValues(alpha: 0.3) : Colors.grey.shade200,
            width: 1.5),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color:
                hasResult ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: hasResult
                        ? color.withValues(alpha: 0.15)
                        : Colors.grey.shade200,
                    shape: BoxShape.circle),
                child: Icon(icon,
                    color: hasResult ? color : Colors.grey, size: 22)),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: hasResult ? color : Colors.grey.shade600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: hasResult
                    ? Colors.green.shade50
                    : waiting
                        ? Colors.orange.shade50
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: hasResult
                        ? Colors.green.shade300
                        : waiting
                            ? Colors.orange.shade300
                            : Colors.grey.shade300),
              ),
              child: Text(
                  hasResult
                      ? 'NALABAS'
                      : waiting
                          ? 'HINIHINTAY'
                          : 'DARATING',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: hasResult
                          ? Colors.green.shade700
                          : waiting
                              ? Colors.orange.shade700
                              : Colors.grey.shade600)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: isLoading
              ? _LoadingSkeleton()
              : hasResult
                  ? _ResultDisplay(
                      combo: result!, winners: winners, color: color)
                  : _NoResult(waiting: waiting),
        ),
      ]),
    );
  }
}

class _ResultDisplay extends StatelessWidget {
  final String combo;
  final int? winners;
  final Color color;
  const _ResultDisplay(
      {required this.combo, required this.winners, required this.color});

  @override
  Widget build(BuildContext context) {
    final parts = combo.split('-');
    final n1 = parts.isNotEmpty ? parts[0] : '?';
    final n2 = parts.length > 1 ? parts[1] : '?';
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _BigBall(number: n1, color: color),
        const SizedBox(width: 16),
        Text('-',
            style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w300,
                color: Colors.grey.shade400)),
        const SizedBox(width: 16),
        _BigBall(number: n2, color: color),
      ]),
      if (winners != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.emoji_events_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Text('$winners NANALO',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      ],
    ]);
  }
}

class _BigBall extends StatelessWidget {
  final String number;
  final Color color;
  const _BigBall({required this.number, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.9), color],
            center: const Alignment(-0.3, -0.3)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Center(
          child: Text(number,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900))),
    );
  }
}

class _NoResult extends StatelessWidget {
  final bool waiting;
  const _NoResult({required this.waiting});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(waiting ? Icons.hourglass_top_rounded : Icons.schedule_rounded,
          size: 48, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(waiting ? 'Hinihintay ang resulta...' : 'Hindi pa oras ng draw',
          style: TextStyle(
              fontSize: 17,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: Colors.grey.shade200)),
      const SizedBox(width: 16),
      Container(width: 20, height: 4, color: Colors.grey.shade200),
      const SizedBox(width: 16),
      Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: Colors.grey.shade200)),
    ]);
  }
}

class _HowToPlay extends StatelessWidget {
  const _HowToPlay();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200)),
      child:
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFC0392B), size: 24),
          SizedBox(width: 10),
          Text('PAANO MANALO',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFC0392B))),
        ]),
        SizedBox(height: 14),
        _InfoRow(
            icon: Icons.monetization_on_outlined,
            text: 'Halaga ng tiket: ₱10 bawat kombinasyon'),
        _InfoRow(
            icon: Icons.emoji_events_outlined,
            text: 'Premyo: ₱4,000 (Tuwid) • ₱2,000 (Rambolito)'),
        _InfoRow(
            icon: Icons.numbers_rounded,
            text: 'Pumili ng 2 numero mula 1 hanggang 31'),
        _InfoRow(
            icon: Icons.access_time_rounded,
            text: 'Draw: 2PM, 5PM, at 9PM araw-araw'),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
            child:
                Text(text, style: const TextStyle(fontSize: 16, height: 1.4))),
      ]),
    );
  }
}

// ── Copyright ─────────────────────────────────────────────────
class _Copyright extends StatelessWidget {
  const _Copyright();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(children: [
        Text(
          '© ${DateTime.now().year} Mark Spencer D. Montalbo',
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          'EZ2 Lotto Results App • All rights reserved',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}
