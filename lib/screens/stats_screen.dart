// lib/screens/stats_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../constants.dart';
import '../helpers.dart';
import '../models.dart';
import '../widgets/common.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _ctrlA = TextEditingController();
  final _ctrlB = TextEditingController();
  String _draw = 'all';
  List<_SearchMatch>? _results;
  bool _searched = false;

  @override
  void dispose() {
    _ctrlA.dispose();
    _ctrlB.dispose();
    super.dispose();
  }

  void _search(List<DayResult> allRows) {
    final a = (_ctrlA.text.trim().padLeft(2, '0'));
    final b = (_ctrlB.text.trim().padLeft(2, '0'));
    final n1 = int.tryParse(a) ?? 0;
    final n2 = int.tryParse(b) ?? 0;
    if (n1 < 1 || n1 > 31 || n2 < 1 || n2 > 31) return;

    final combo = '${a.padLeft(2, "0")}-${b.padLeft(2, "0")}';
    final reversed = '${b.padLeft(2, "0")}-${a.padLeft(2, "0")}';
    final isDouble = a == b;
    final found = <_SearchMatch>[];

    for (final row in allRows) {
      for (final slot in ['2pm', '5pm', '9pm']) {
        if (_draw != 'all' && _draw != slot) continue;
        final val = row.resultFor(slot);
        if (val == null) continue;
        if (val == combo) {
          found.add(_SearchMatch(
              date: row.date, slot: slot, result: val, isStraight: true));
        } else if (!isDouble && val == reversed) {
          found.add(_SearchMatch(
              date: row.date, slot: slot, result: val, isStraight: false));
        }
      }
    }
    setState(() {
      _results = found;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final stats = computeStats(prov.allRows);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Top Combos ─────────────────────────────────────
        AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeading('🔢 Pinaka-madalas na Kombinasyon'),
            const SizedBox(height: 4),
            Text('Top 5 · lahat ng draws sa DB',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            const SizedBox(height: 16),
            ...stats.topCombos.map((r) {
              final parts = r.combo.split('-');
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: r.rank.isEven ? const Color(0xFFFAFAFA) : Colors.white,
                  border:
                      Border.all(color: const Color(0xFFF0F0F0), width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  SizedBox(
                    width: 34,
                    child: Text('${r.rank}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary)),
                  ),
                  const SizedBox(width: 8),
                  SmallBall(num: parts[0]),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('–',
                          style: TextStyle(color: Color(0xFFCCCCCC)))),
                  SmallBall(num: parts[1]),
                  const SizedBox(width: 12),
                  Text('${r.hits}x',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.green)),
                  const Spacer(),
                  if (r.lastSeenDate != null)
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(r.lastSeenDate!,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMid)),
                          Text(slotEmoji(r.lastSeenSlot ?? ''),
                              style: const TextStyle(fontSize: 12)),
                        ]),
                ]),
              );
            }),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Hot / Cold ─────────────────────────────────────
        AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: const [
              SectionHeading('🔥 Hot Numbers'),
              Text(' / ',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textMid)),
              Text('❄️ Cold',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.blue)),
            ]),
            const SizedBox(height: 16),
            const Text('🔥 Pinaka-madalas',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFC62828))),
            const SizedBox(height: 10),
            Wrap(
                spacing: 14,
                runSpacing: 14,
                children: stats.hotNums
                    .map((n) => _NumBall(n: n, hot: true))
                    .toList()),
            const SizedBox(height: 20),
            const Text('❄️ Pinaka-bihira',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blue)),
            const SizedBox(height: 10),
            Wrap(
                spacing: 14,
                runSpacing: 14,
                children: stats.coldNums
                    .map((n) => _NumBall(n: n, hot: false))
                    .toList()),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Combo Search ───────────────────────────────────
        AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeading('🔎 Hanapin ang Kombinasyon'),
            const SizedBox(height: 16),
            Row(children: [
              _NumInput(label: 'NUMERO A', ctrl: _ctrlA),
              const SizedBox(width: 12),
              _NumInput(label: 'NUMERO B', ctrl: _ctrlB),
            ]),
            const SizedBox(height: 14),
            // Draw filter
            Row(children: [
              for (final (v, l) in [
                ('all', 'Lahat'),
                ('2pm', '2 PM'),
                ('5pm', '5 PM'),
                ('9pm', '9 PM')
              ]) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _draw = v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _draw == v
                            ? AppColors.primary
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(l,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _draw == v
                                  ? Colors.white
                                  : const Color(0xFF555555))),
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 14),
            PrimaryButton(
              label: '🔍 Hanapin',
              onPressed: () => _search(prov.allRows),
            ),
            if (_searched && _results != null) ...[
              const SizedBox(height: 16),
              if (_results!.isEmpty)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Walang nahanap na tugma.',
                            style: TextStyle(
                                fontSize: 16, color: AppColors.textLight))))
              else ...[
                Text('✅ ${_results!.length} na tugma:',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.green)),
                const SizedBox(height: 8),
                ..._results!.map((r) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FBE7),
                        border: Border.all(
                            color: const Color(0xFFC5E1A5), width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${r.date} — ${slotEmoji(r.slot)}',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.green)),
                                  Text('Resulta: ${r.result}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textMid)),
                                ]),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: r.isStraight
                                    ? AppColors.green
                                    : Colors.orange,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                  r.isStraight ? 'Straight' : 'Rambolito',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ]),
                    )),
              ],
            ],
          ]),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Hot/Cold ball ─────────────────────────────────────────────
class _NumBall extends StatelessWidget {
  final NumStat n;
  final bool hot;
  const _NumBall({required this.n, required this.hot});

  @override
  Widget build(BuildContext context) {
    final isVeryHot = hot && n.count >= 15;
    return Column(children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.28, -0.36),
            colors: hot
                ? (isVeryHot
                    ? [
                        const Color(0xFFFFF8E1),
                        const Color(0xFFFF5722),
                        AppColors.primary
                      ]
                    : [
                        const Color(0xFFFFFDE7),
                        AppColors.amber,
                        AppColors.accent
                      ])
                : [
                    const Color(0xFFE3F2FD),
                    const Color(0xFF42A5F5),
                    AppColors.blue
                  ],
            stops: const [0.0, 0.52, 1.0],
          ),
          border: Border.all(
              color: hot
                  ? (isVeryHot ? AppColors.primary : AppColors.ballOrangeBorder)
                  : const Color(0xFF01579B),
              width: 2.5),
        ),
        alignment: Alignment.center,
        child: Text(n.num,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: (!hot || isVeryHot)
                    ? Colors.white
                    : const Color(0xFF3E1000))),
      ),
      const SizedBox(height: 4),
      Text('${n.count}x',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: hot
                  ? (isVeryHot ? AppColors.primary : AppColors.accent)
                  : AppColors.blue)),
    ]);
  }
}

// ── Number input ──────────────────────────────────────────────
class _NumInput extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  const _NumInput({required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMid)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3E1000)),
            decoration: InputDecoration(
              hintText: '01–31',
              filled: true,
              fillColor: const Color(0xFFFFFDE7),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.amber, width: 3),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 3),
              ),
            ),
          ),
        ]),
      );
}

class _SearchMatch {
  final String date, slot, result;
  final bool isStraight;
  const _SearchMatch(
      {required this.date,
      required this.slot,
      required this.result,
      required this.isStraight});
}
