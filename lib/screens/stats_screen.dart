// lib/screens/stats_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../helpers.dart';
import '../models.dart';
import '../responsive.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _chartDays = 30;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final prov = context.watch<AppProvider>();
    final allRows = prov.allHistoryRows;
    final stats = allRows.isEmpty ? null : computeStats(allRows);

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F0E8),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E8449),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                padding: EdgeInsets.fromLTRB(
                  context.horizontalPadding,
                  context.headerPaddingTop,
                  context.horizontalPadding,
                  28,
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STATISTICS',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: context.titleFontSize,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('Statistics from ${allRows.length} draw results',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 15)),
                    ]),
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  context.horizontalPadding, 16, context.horizontalPadding, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (stats == null)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator()))
                  else ...[
                    // ── 1. Most Drawn EZ2 Numbers ────────
                    _SectionHeader(
                      icon: Icons.bar_chart_rounded,
                      label: 'Most Drawn EZ2 Numbers',
                      sub:
                          'Top 5 most frequently drawn in the last ${allRows.length} draws',
                      color: const Color(0xFF1A5276),
                    ),
                    const SizedBox(height: 12),
                    _MostDrawnNumbersTable(combos: stats.topCombos),
                    const SizedBox(height: 22),

                    // ── 2. Most Drawn Number Pairs ────────
                    _SectionHeader(
                      icon: Icons.grid_view_rounded,
                      label: 'Most Drawn Number Pairs',
                      sub: 'How often each number appears in any draw position',
                      color: const Color(0xFF7D3C98),
                    ),
                    const SizedBox(height: 12),
                    _MostDrawnPairsTable(pairs: stats.topPairs),
                    const SizedBox(height: 22),

                    // ── 3. Winners Chart ──────────────────
                    _SectionHeader(
                      icon: Icons.show_chart_rounded,
                      label: '2D Lotto Winners Chart',
                      sub: 'Number of winners in recent draws',
                      color: const Color(0xFF0E7490),
                    ),
                    const SizedBox(height: 12),
                    _WinnersChartCard(
                      rows: allRows,
                      days: _chartDays,
                      onDaysChanged: (d) => setState(() => _chartDays = d),
                    ),
                    const SizedBox(height: 22),

                    // ── 4. Hot & Cold Numbers ─────────────
                    _SectionHeader(
                      icon: Icons.local_fire_department_rounded,
                      label: 'PCSO EZ2 Hot & Cold Numbers',
                      sub: 'Based on the last 200 EZ2 draws',
                      color: const Color(0xFFC0392B),
                    ),
                    const SizedBox(height: 12),
                    _HotColdSection(hot: stats.hot, cold: stats.cold),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  const _SectionHeader(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900, color: color))),
      ]),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.only(left: 38),
        child: Text(sub,
            style: TextStyle(
                fontSize: 13,
                color:
                    isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600)),
      ),
    ]);
  }
}

// ── Shared: colored circle ball ───────────────────────────────
class _Ball extends StatelessWidget {
  final String n;
  final Color color;
  final double size;
  const _Ball({required this.n, required this.color, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Center(
          child: Text(n,
              style: TextStyle(
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white))),
    );
  }
}

// ── 1. Most Drawn Numbers Table ───────────────────────────────
class _MostDrawnNumbersTable extends StatelessWidget {
  final List<ComboStat> combos;
  const _MostDrawnNumbersTable({required this.combos});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final rowColor = isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade50;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDarkMode ? const Color(0xFF3E3E3E) : Colors.grey.shade200),
      ),
      child: Column(children: [
        _TableHeader(
          color: const Color(0xFF1A5276),
          children: const ['#', 'Numbers', 'Hits', 'Last Seen'],
          widths: const [36, 0, 48, 0],
        ),
        ...combos.asMap().entries.map((e) {
          final i = e.key;
          final c = e.value;
          final parts = c.combo.split('-');
          final n1 = parts.isNotEmpty ? parts[0] : '?';
          final n2 = parts.length > 1 ? parts[1] : '?';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: i.isEven ? rowColor : cardColor,
              border: Border(
                  top: BorderSide(
                      color: isDarkMode
                          ? const Color(0xFF3E3E3E)
                          : Colors.grey.shade100)),
            ),
            child: Row(children: [
              SizedBox(
                  width: 36,
                  child: Text('#${i + 1}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade500))),
              Row(children: [
                _Ball(n: n1, color: const Color(0xFF1A5276)),
                const SizedBox(width: 4),
                _Ball(n: n2, color: const Color(0xFF1A5276)),
              ]),
              const Spacer(),
              SizedBox(
                  width: 48,
                  child: Text('x${c.count}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A5276)))),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.lastDate,
                          style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey)),
                      Text('(${c.daysSinceLast} days ago)',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDarkMode
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400)),
                    ]),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── 2. Most Drawn Pairs Table ─────────────────────────────────
class _MostDrawnPairsTable extends StatelessWidget {
  final List<PairStat> pairs;
  const _MostDrawnPairsTable({required this.pairs});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final rowColor = isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade50;

    return Container(
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  isDarkMode ? const Color(0xFF3E3E3E) : Colors.grey.shade200)),
      child: Column(children: [
        _TableHeader(
          color: const Color(0xFF7D3C98),
          children: const ['#', 'Pairs', 'Draws'],
          widths: const [36, 0, 0],
        ),
        ...pairs.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final numStr = p.number.toString().padLeft(2, '0');
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: i.isEven ? rowColor : cardColor,
              border: Border(
                  top: BorderSide(
                      color: isDarkMode
                          ? const Color(0xFF3E3E3E)
                          : Colors.grey.shade100)),
            ),
            child: Row(children: [
              SizedBox(
                  width: 36,
                  child: Text('#${i + 1}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade500))),
              Row(children: [
                _Ball(n: numStr, color: const Color(0xFF1E8449), size: 38),
                const SizedBox(width: 8),
                Text('-',
                    style: TextStyle(
                        fontSize: 18,
                        color: isDarkMode
                            ? Colors.grey.shade600
                            : Colors.grey.shade400)),
                const SizedBox(width: 8),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isDarkMode
                              ? Colors.grey.shade600
                              : Colors.grey.shade300,
                          width: 2)),
                  child: Center(
                      child: Text('?',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDarkMode
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade400))),
                ),
              ]),
              const Spacer(),
              Text('${p.count}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF7D3C98))),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Shared table header ───────────────────────────────────────
class _TableHeader extends StatelessWidget {
  final Color color;
  final List<String> children;
  final List<int> widths; // 0 = Expanded
  const _TableHeader(
      {required this.color, required this.children, required this.widths});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Row(
        children: children.asMap().entries.map((e) {
          final i = e.key;
          final w = i < widths.length ? widths[i] : 0;
          final text = Text(e.value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color));
          return w > 0
              ? SizedBox(width: w.toDouble(), child: text)
              : (i == children.length - 1 ? text : Expanded(child: text));
        }).toList(),
      ),
    );
  }
}

// ── 3. Winners Chart Card ─────────────────────────────────────
class _WinnersChartCard extends StatelessWidget {
  final List<DayResult> rows;
  final int days;
  final void Function(int) onDaysChanged;
  const _WinnersChartCard(
      {required this.rows, required this.days, required this.onDaysChanged});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    // Collect winner data points: one per draw slot
    final points = <_WinPoint>[];
    final recent =
        rows.where((r) => r.hasAnyResult).take(days).toList().reversed.toList();
    for (final row in recent) {
      if (row.winners2pm != null)
        points.add(
            _WinPoint(date: row.date, slot: '2pm', count: row.winners2pm!));
      if (row.winners5pm != null)
        points.add(
            _WinPoint(date: row.date, slot: '5pm', count: row.winners5pm!));
      if (row.winners9pm != null)
        points.add(
            _WinPoint(date: row.date, slot: '9pm', count: row.winners9pm!));
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDarkMode ? const Color(0xFF3E3E3E) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title + toggle
        Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('2D Lotto Winners Chart',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0E7490))),
              const SizedBox(height: 2),
              Text('Number of winners in recent games',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade500)),
            ]),
          ),
          const SizedBox(width: 12),
          _TogglePill(
            options: const ['Last 7 Days', 'Last 30 Days'],
            selected: days == 7 ? 0 : 1,
            onChanged: (i) => onDaysChanged(i == 0 ? 7 : 30),
          ),
        ]),
        const SizedBox(height: 20),
        // Chart
        points.isEmpty
            ? SizedBox(
                height: 180,
                child: Center(
                    child: Text('No winner data yet',
                        style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey.shade500
                                : Colors.grey.shade400,
                            fontSize: 15))),
              )
            : SizedBox(
                height: 200,
                child: _LineChart(points: points),
              ),
      ]),
    );
  }
}

class _WinPoint {
  final String date, slot;
  final int count;
  const _WinPoint(
      {required this.date, required this.slot, required this.count});
}

// ── Toggle pill ───────────────────────────────────────────────
class _TogglePill extends StatelessWidget {
  final List<String> options;
  final int selected;
  final void Function(int) onChanged;
  const _TogglePill(
      {required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF0E7490)),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
          mainAxisSize: MainAxisSize.min,
          children: options.asMap().entries.map((e) {
            final sel = e.key == selected;
            return GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF0E7490) : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(e.value,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : const Color(0xFF0E7490))),
              ),
            );
          }).toList()),
    );
  }
}

// ── Line chart painter ────────────────────────────────────────
class _LineChart extends StatelessWidget {
  final List<_WinPoint> points;
  const _LineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _LineChartPainter(points: points),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_WinPoint> points;
  _LineChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const leftPad = 52.0;
    const rightPad = 12.0;
    const topPad = 12.0;
    const botPad = 36.0;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - botPad;

    final maxVal = points.map((p) => p.count).reduce(math.max).toDouble();
    const minVal = 0.0;
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    double x(int i) =>
        leftPad + (i / (points.length - 1).clamp(1, 9999)) * chartW;
    double y(int v) => topPad + chartH - ((v - minVal) / range) * chartH;

    // ── Fill area ───────────────────────────────────────
    final fillPath = Path();
    fillPath.moveTo(x(0), y(points[0].count));
    for (int i = 1; i < points.length; i++) {
      final prev = Offset(x(i - 1), y(points[i - 1].count));
      final curr = Offset(x(i), y(points[i].count));
      final cp1 = Offset((prev.dx + curr.dx) / 2, prev.dy);
      final cp2 = Offset((prev.dx + curr.dx) / 2, curr.dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
    }
    fillPath.lineTo(x(points.length - 1), size.height - botPad);
    fillPath.lineTo(x(0), size.height - botPad);
    fillPath.close();

    canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFF0E7490).withValues(alpha: 0.25),
              const Color(0xFF0E7490).withValues(alpha: 0.02)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, topPad, size.width, chartH))
          ..style = PaintingStyle.fill);

    // ── Line ─────────────────────────────────────────────
    final linePath = Path();
    linePath.moveTo(x(0), y(points[0].count));
    for (int i = 1; i < points.length; i++) {
      final prev = Offset(x(i - 1), y(points[i - 1].count));
      final curr = Offset(x(i), y(points[i].count));
      final cp1 = Offset((prev.dx + curr.dx) / 2, prev.dy);
      final cp2 = Offset((prev.dx + curr.dx) / 2, curr.dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(
        linePath,
        Paint()
          ..color = const Color(0xFF0E7490)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    // ── Y-axis grid lines + labels ────────────────────────
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    const steps = 4;
    for (int i = 0; i <= steps; i++) {
      final val = (maxVal * i / steps).round();
      final yy = y(val);
      canvas.drawLine(
          Offset(leftPad, yy), Offset(size.width - rightPad, yy), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
            text: _fmt(val),
            style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, yy - tp.height / 2));
    }

    // ── X-axis date labels (show every Nth) ──────────────
    final labelEvery = (points.length / 6).ceil().clamp(1, 999);
    for (int i = 0; i < points.length; i += labelEvery) {
      final dateShort = _shortLabel(points[i].date);
      final tp = TextPainter(
        text: TextSpan(
            text: dateShort,
            style: const TextStyle(fontSize: 9, color: Color(0xFF888888))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x(i) - tp.width / 2, size.height - botPad + 6));
    }

    // ── Dots at each data point ───────────────────────────
    final dotPaint = Paint()
      ..color = const Color(0xFF0E7490)
      ..style = PaintingStyle.fill;
    final dotBg = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    if (points.length <= 30) {
      for (int i = 0; i < points.length; i++) {
        canvas.drawCircle(Offset(x(i), y(points[i].count)), 4, dotBg);
        canvas.drawCircle(Offset(x(i), y(points[i].count)), 3, dotPaint);
      }
    }
  }

  String _fmt(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return '$v';
  }

  String _shortLabel(String date) {
    // "Mar 16, 2026" → "Mar 16"
    final p = date.split(' ');
    if (p.length >= 2) return '${p[0]} ${p[1].replaceAll(',', '')}';
    return date;
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => old.points != points;
}

// ── 4. Hot & Cold Numbers ─────────────────────────────────────
class _HotColdSection extends StatelessWidget {
  final List<NumberStat> hot, cold;
  const _HotColdSection({required this.hot, required this.cold});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  isDarkMode ? const Color(0xFF3E3E3E) : Colors.grey.shade200)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Text('Hot Numbers',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFC0392B))),
        ]),
        const SizedBox(height: 4),
        Text('Most drawn in the last 200 EZ2 draws',
            style: TextStyle(
                fontSize: 13,
                color:
                    isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: hot
                  .map((s) =>
                      _HotColdBall(stat: s, color: const Color(0xFFC0392B)))
                  .toList()),
        ),
        const SizedBox(height: 20),
        Row(children: [
          const Text('❄️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Text('Cold Numbers',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2471A3))),
        ]),
        const SizedBox(height: 4),
        Text('Least drawn in the last 200 EZ2 draws',
            style: TextStyle(
                fontSize: 13,
                color:
                    isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: cold
                  .map((s) =>
                      _HotColdBall(stat: s, color: const Color(0xFF2471A3)))
                  .toList()),
        ),
      ]),
    );
  }
}

class _HotColdBall extends StatelessWidget {
  final NumberStat stat;
  final Color color;
  const _HotColdBall({required this.stat, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      child: Column(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Center(
              child: Text(stat.number.toString().padLeft(2, '0'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900))),
        ),
        const SizedBox(height: 4),
        Text('${stat.count}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}
