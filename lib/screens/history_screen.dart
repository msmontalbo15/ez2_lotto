// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../app_provider.dart';
import '../constants.dart';
import '../helpers.dart';
import '../models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _monthTabs = buildMonthTabs(count: 3);
  int _activeMonth = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final key = _monthTabs[_activeMonth].monthKey;
    context.read<AppProvider>().fetchMonth(key);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final currentTab = _monthTabs[_activeMonth];
    final key = currentTab.monthKey;
    final rows = prov.historyData[key] ?? [];
    final loading = prov.historyLoading[key] ?? false;
    final error = prov.historyError[key];
    final todayShort = toShortDate(getPHTime());

    return Column(children: [
      // ── Month selector tabs ─────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: _monthTabs.asMap().entries.map((e) {
            final i = e.key;
            final tab = e.value;
            final active = _activeMonth == i;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _activeMonth = i);
                  context.read<AppProvider>().fetchMonth(tab.monthKey);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                      right: i < _monthTabs.length - 1 ? 8 : 0, bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: active
                        ? null
                        : Border.all(color: const Color(0xFFEEEEEE), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: active
                            ? AppColors.primary.withValues(alpha: 0.35)
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: active ? 12 : 4,
                      )
                    ],
                  ),
                  child: Text(
                    tab.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),

      // ── Table header ──────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            _HeaderCell('Petsa', flex: 14),
            _HeaderCell('2 PM', flex: 10),
            _HeaderCell('5 PM', flex: 10),
            _HeaderCell('9 PM', flex: 10),
          ]),
        ),
      ),
      const SizedBox(height: 6),

      // ── Table body ────────────────────────────────────
      Expanded(
        child: loading
            ? const _SkeletonList()
            : error != null
                ? _ErrorView(onRetry: () => prov.retryMonth(key))
                : rows.isEmpty
                    ? const _EmptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final row = rows[i];
                          final isToday = row.date == todayShort;
                          // Merge live data if this is today's row
                          final display =
                              isToday ? row.mergeWith(prov.liveToday) : row;
                          return _HistoryRow(
                              row: display, isToday: isToday, index: i);
                        },
                      ),
      ),
    ]);
  }
}

// ── Table header cell ─────────────────────────────────────────
class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
        ),
      );
}

// ── History row ───────────────────────────────────────────────
class _HistoryRow extends StatelessWidget {
  final DayResult row;
  final bool isToday;
  final int index;

  const _HistoryRow(
      {required this.row, required this.isToday, required this.index});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isToday
              ? const Color(0xFFFFF3E0)
              : index.isEven
                  ? Colors.white
                  : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isToday ? AppColors.amber : const Color(0xFFF0F0F0),
            width: isToday ? 3 : 1.5,
          ),
          boxShadow: isToday
              ? [
                  BoxShadow(
                      color: AppColors.amber.withValues(alpha: 0.22),
                      blurRadius: 12)
                ]
              : null,
        ),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Date column
            Expanded(
              flex: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0xFFF0F0F0))),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isToday) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFCCBC),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('NGAYON',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent)),
                        ),
                      ],
                      Text(
                        row.date.replaceAll(RegExp(r',\s*\d{4}'), ''),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark),
                      ),
                      Text(
                        row.day.length >= 3 ? row.day.substring(0, 3) : row.day,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ]),
              ),
            ),
            // Result columns
            for (final slot in ['2pm', '5pm', '9pm']) ...[
              Expanded(
                flex: 10,
                child: _ResultCell(
                  value: row.resultFor(slot),
                  winners: row.winnersFor(slot),
                  isToday: isToday,
                  isLast: slot == '9pm',
                ),
              ),
            ],
          ]),
        ),
      );
}

class _ResultCell extends StatelessWidget {
  final String? value;
  final int? winners;
  final bool isToday;
  final bool isLast;

  const _ResultCell(
      {this.value, this.winners, required this.isToday, required this.isLast});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(right: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (value != null && value!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color:
                    isToday ? const Color(0xFFFFF3E0) : const Color(0xFFF8F8F8),
                border: Border.all(
                    color: isToday ? AppColors.accent : const Color(0xFFE0E0E0),
                    width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                value!.replaceAll('-', '–'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isToday
                      ? const Color(0xFFBF360C)
                      : const Color(0xFF222222),
                ),
              ),
            ),
            if (winners != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: winners == 0
                      ? const Color(0xFFF5F5F5)
                      : const Color(0xFFE8F5E9),
                  border: Border.all(
                      color: winners == 0
                          ? const Color(0xFFEEEEEE)
                          : const Color(0xFFA5D6A7)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  winners == 0 ? '0' : '${winners!}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: winners == 0 ? Colors.grey[400] : AppColors.green,
                  ),
                ),
              ),
            ],
          ] else ...[
            Text('—',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic)),
          ],
        ]),
      );
}

// ── Skeleton loading ──────────────────────────────────────────
class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: 10,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: const Color(0xFFEEEEEE),
          highlightColor: const Color(0xFFF5F5F5),
          child: Container(
              height: 64,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14))),
        ),
      );
}

// ── Error view ────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Hindi nakuha ang kasaysayan.',
                style: TextStyle(fontSize: 16, color: AppColors.primary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              child: const Text('🔄 Subukan Ulit'),
            ),
          ]),
        ),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('📭', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('Walang datos para sa buwang ito.',
              style: TextStyle(fontSize: 16, color: AppColors.textLight)),
        ]),
      );
}
