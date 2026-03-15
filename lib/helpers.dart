// lib/helpers.dart

import 'package:intl/intl.dart';
import 'constants.dart';
import 'models.dart';

// ── PH Time (UTC+8) ───────────────────────────────────────────
DateTime getPHTime() => DateTime.now().toUtc().add(const Duration(hours: 8));

String toISODate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String toShortDate(DateTime d) =>
    DateFormat('MMM d, yyyy').format(d); // 'Mar 15, 2026'

String toDayName(DateTime d) => DateFormat('EEEE').format(d); // 'Saturday'

// ── Draw status ───────────────────────────────────────────────
DrawStatus getDrawStatus(int drawHour) {
  final ph = getPHTime();
  final mins = ph.hour * 60 + ph.minute;
  final dm = drawHour * 60;
  if (mins < dm - 5) return DrawStatus.upcoming;
  if (mins < dm + 20) return DrawStatus.live;
  return DrawStatus.done;
}

NextDrawInfo? getNextDrawInfo() {
  final ph = getPHTime();
  final totalMins = ph.hour * 60 + ph.minute;
  for (final d in kDrawSchedule) {
    final dm = d.drawHour * 60;
    if (totalMins < dm - 5) {
      return NextDrawInfo(
        slot: d.key,
        emoji: d.emoji,
        label: d.label,
        minsUntil: dm - totalMins,
      );
    }
  }
  return null;
}

String formatCountdown(int minsUntil) {
  if (minsUntil <= 0) return 'Ngayon na!';
  final h = minsUntil ~/ 60;
  final m = minsUntil % 60;
  return h > 0 ? '$h oras $m min' : '$m minuto';
}

// ── Month tabs ────────────────────────────────────────────────
List<MonthTab> buildMonthTabs({int count = 3}) {
  final ph = getPHTime();
  final tabs = <MonthTab>[];
  for (var i = 0; i < count; i++) {
    final d = DateTime(ph.year, ph.month - i, 1);
    final mon = d.month; // 1-indexed
    final year = d.year;
    final key = '$year-${mon.toString().padLeft(2, '0')}';
    tabs.add(MonthTab(
      label: '${kMonthsFil[mon - 1]} $year',
      monthKey: key,
      year: year,
      month: mon,
    ));
  }
  return tabs;
}

// ── Stats computation ─────────────────────────────────────────
EZ2Stats computeStats(List<DayResult> rows) {
  final comboCounts = <String, int>{};
  final numCounts = <String, int>{};
  final comboLastDate = <String, String>{};
  final comboLastSlot = <String, String>{};

  for (final row in rows) {
    for (final slot in ['2pm', '5pm', '9pm']) {
      final v = row.resultFor(slot);
      if (v == null || !RegExp(r'^\d{2}-\d{2}$').hasMatch(v)) continue;
      comboCounts[v] = (comboCounts[v] ?? 0) + 1;
      comboLastDate.putIfAbsent(v, () => row.date);
      comboLastSlot.putIfAbsent(v, () => slot);
      for (final n in v.split('-')) {
        numCounts[n] = (numCounts[n] ?? 0) + 1;
      }
    }
  }

  final sortedCombos = comboCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final topCombos = sortedCombos.take(5).toList().asMap().entries.map((e) {
    final combo = e.value.key;
    return ComboStat(
      rank: e.key + 1,
      combo: combo,
      hits: e.value.value,
      lastSeenDate: comboLastDate[combo],
      lastSeenSlot: comboLastSlot[combo],
    );
  }).toList();

  final sortedNums = numCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final hotNums = sortedNums
      .take(9)
      .map((e) => NumStat(num: e.key, count: e.value))
      .toList();
  final coldNums = sortedNums.reversed
      .take(6)
      .map((e) => NumStat(num: e.key, count: e.value))
      .toList();

  return EZ2Stats(topCombos: topCombos, hotNums: hotNums, coldNums: coldNums);
}

// ── Ticket check ──────────────────────────────────────────────
List<TicketMatch> checkTicket(
  String combo,
  List<DayResult> allRows, {
  String dateFilter = 'all',
  String drawFilter = 'all',
}) {
  final parts = combo.split('-');
  if (parts.length != 2) return [];
  final reversed = '${parts[1]}-${parts[0]}';
  final isDouble = parts[0] == parts[1];
  final matches = <TicketMatch>[];

  const slotLabels = {'2pm': '2:00 PM', '5pm': '5:00 PM', '9pm': '9:00 PM'};

  for (final row in allRows) {
    if (dateFilter != 'all' && row.date != dateFilter) continue;
    for (final slot in ['2pm', '5pm', '9pm']) {
      final label = slotLabels[slot]!;
      if (drawFilter != 'all' && drawFilter != slot) continue;
      final val = row.resultFor(slot);
      if (val == null) continue;
      if (val == combo) {
        matches.add(TicketMatch(
            date: row.date, draw: label, combo: val, isStraight: true));
      } else if (!isDouble && val == reversed) {
        matches.add(TicketMatch(
            date: row.date, draw: label, combo: val, isStraight: false));
      }
    }
  }
  return matches;
}

// ── Number formatting ─────────────────────────────────────────
String formatWinners(int count) =>
    count == 0 ? '0 nanalo' : '${NumberFormat('#,##0').format(count)} nanalo';

String slotEmoji(String slot) => slot == '2pm'
    ? '🌤️'
    : slot == '5pm'
        ? '🌇'
        : '🌙';
