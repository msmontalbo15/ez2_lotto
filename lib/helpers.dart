// lib/helpers.dart
import 'models.dart';

// ── PH Time ──────────────────────────────────────────────────

DateTime getPHTime() => DateTime.now().toUtc().add(const Duration(hours: 8));

String toISODate(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

String toShortDate(DateTime dt) {
  const m = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${m[dt.month]} ${dt.day}, ${dt.year}';
}

String toDayName(DateTime dt) {
  const d = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  return d[dt.weekday - 1];
}

String monthKey(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

List<String> buildAvailableMonths({int count = 3}) {
  final ph = getPHTime();
  return List.generate(
      count, (i) => monthKey(DateTime(ph.year, ph.month - i, 1)));
}

// ── Date parsing helper ───────────────────────────────────────
DateTime? parseShortDate(String d) {
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
    return DateTime(
        int.parse(p[2]), months[p[0]]!, int.parse(p[1].replaceAll(',', '')));
  } catch (_) {
    return null;
  }
}

// ── Stats computation ────────────────────────────────────────

EZ2Stats computeStats(List<DayResult> rows) {
  final today = getPHTime();

  // Number frequencies
  final numberCount = <int, int>{};
  final numberLastDay = <int, DateTime>{};
  final numberLastCombo = <int, String>{};

  // Full combo frequencies
  final comboCount = <String, int>{};
  final comboLastDay = <String, DateTime>{};
  final comboLastDate = <String, String>{};

  // Single-number pair frequencies (how many times each number appears in any position)
  final pairCount = <int, int>{};

  for (final row in rows) {
    final rowDate = parseShortDate(row.date);

    for (final combo in [row.result2pm, row.result5pm, row.result9pm]) {
      if (combo == null) continue;
      final parts = combo.split('-');
      if (parts.length != 2) continue;
      final n1 = int.tryParse(parts[0]);
      final n2 = int.tryParse(parts[1]);
      if (n1 == null || n2 == null) continue;

      // Individual number counts
      numberCount[n1] = (numberCount[n1] ?? 0) + 1;
      numberCount[n2] = (numberCount[n2] ?? 0) + 1;
      pairCount[n1] = (pairCount[n1] ?? 0) + 1;
      pairCount[n2] = (pairCount[n2] ?? 0) + 1;

      if (rowDate != null) {
        if (!numberLastDay.containsKey(n1) ||
            rowDate.isAfter(numberLastDay[n1]!)) {
          numberLastDay[n1] = rowDate;
          numberLastCombo[n1] = combo;
        }
        if (!numberLastDay.containsKey(n2) ||
            rowDate.isAfter(numberLastDay[n2]!)) {
          numberLastDay[n2] = rowDate;
          numberLastCombo[n2] = combo;
        }
      }

      // Full combo (order-preserved, then also reversed for dedup)
      final keyFwd = '$n1-$n2';
      final keyRev = '$n2-$n1';
      final key = keyFwd.compareTo(keyRev) <= 0 ? keyFwd : keyRev;
      comboCount[key] = (comboCount[key] ?? 0) + 1;
      if (rowDate != null) {
        if (!comboLastDay.containsKey(key) ||
            rowDate.isAfter(comboLastDay[key]!)) {
          comboLastDay[key] = rowDate;
          comboLastDate[key] = row.date;
        }
      }
    }
  }

  for (int i = 1; i <= 31; i++) numberCount.putIfAbsent(i, () => 0);

  NumberStat toStat(int n) => NumberStat(
        number: n,
        count: numberCount[n]!,
        daysSinceLast: numberLastDay.containsKey(n)
            ? today.difference(numberLastDay[n]!).inDays
            : 999,
        lastCombo: numberLastCombo[n],
      );

  final sorted = List.generate(31, (i) => i + 1)
    ..sort((a, b) => numberCount[b]!.compareTo(numberCount[a]!));

  final hot = sorted.take(7).map(toStat).toList();
  final cold = sorted.reversed.take(7).map(toStat).toList();

  // Top 5 full combos
  final topCombos = (comboCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .take(5)
      .map((e) {
    final p = e.key.split('-');
    final n1 = int.parse(p[0]);
    final n2 = int.parse(p[1]);
    final last = comboLastDay[e.key];
    return ComboStat(
      combo:
          '${n1.toString().padLeft(2, '0')}-${n2.toString().padLeft(2, '0')}',
      count: e.value,
      daysSinceLast: last != null ? today.difference(last).inDays : 999,
      lastDate: comboLastDate[e.key] ?? '',
    );
  }).toList();

  // Top 10 single-number pair frequencies
  final topPairs = (pairCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .take(10)
      .map((e) => PairStat(number: e.key, count: e.value, isFirst: false))
      .toList();

  return EZ2Stats(
      hot: hot, cold: cold, topCombos: topCombos, topPairs: topPairs);
}

// ── Ticket checker ────────────────────────────────────────────

List<TicketMatch> checkTicket(String combo, List<DayResult> allRows,
    {String dateFilter = 'all', String drawFilter = 'all'}) {
  final parts = combo.split('-');
  if (parts.length != 2) return [];
  final n1 = int.tryParse(parts[0]);
  final n2 = int.tryParse(parts[1]);
  if (n1 == null || n2 == null) return [];

  final straight =
      '${n1.toString().padLeft(2, '0')}-${n2.toString().padLeft(2, '0')}';
  final rambolito =
      '${n2.toString().padLeft(2, '0')}-${n1.toString().padLeft(2, '0')}';
  final isDiff = straight != rambolito;
  final matches = <TicketMatch>[];

  for (final row in allRows) {
    if (dateFilter != 'all' && row.date != dateFilter) continue;
    void check(String? drawn, String slot) {
      if (drawn == null) return;
      if (drawFilter != 'all' && slot != drawFilter) return;
      if (drawn == straight) {
        matches.add(TicketMatch(
            date: row.date,
            slot: slot,
            combo: drawn,
            isStraight: true,
            prize: 4000));
      } else if (isDiff && drawn == rambolito) {
        matches.add(TicketMatch(
            date: row.date,
            slot: slot,
            combo: drawn,
            isStraight: false,
            prize: 2000));
      }
    }

    check(row.result2pm, '2pm');
    check(row.result5pm, '5pm');
    check(row.result9pm, '9pm');
  }
  return matches;
}
