// lib/models.dart

class DayResult {
  final String date;
  final String day;
  final String? result2pm;
  final String? result5pm;
  final String? result9pm;
  final int? winners2pm;
  final int? winners5pm;
  final int? winners9pm;

  const DayResult({
    required this.date,
    required this.day,
    this.result2pm,
    this.result5pm,
    this.result9pm,
    this.winners2pm,
    this.winners5pm,
    this.winners9pm,
  });

  bool get hasAnyResult =>
      result2pm != null || result5pm != null || result9pm != null;

  factory DayResult.empty(String date, String day) =>
      DayResult(date: date, day: day);

  factory DayResult.fromSupabaseRows(
      List<Map<String, dynamic>> rows, String date, String day) {
    String? r2pm, r5pm, r9pm;
    int? w2pm, w5pm, w9pm;
    for (final row in rows) {
      final slot = row['draw_slot'] as String?;
      final combo = row['combo'] as String?;
      final winners = row['winners'] as int?;
      if (slot == '2pm') {
        r2pm = combo;
        w2pm = winners;
      }
      if (slot == '5pm') {
        r5pm = combo;
        w5pm = winners;
      }
      if (slot == '9pm') {
        r9pm = combo;
        w9pm = winners;
      }
    }
    return DayResult(
        date: date,
        day: day,
        result2pm: r2pm,
        result5pm: r5pm,
        result9pm: r9pm,
        winners2pm: w2pm,
        winners5pm: w5pm,
        winners9pm: w9pm);
  }
}

// ── Draw status ───────────────────────────────────────────────
enum DrawStatus { upcoming, live, done }

// ── Stats models ──────────────────────────────────────────────

/// A single number with its frequency and last-seen combo
class NumberStat {
  final int number;
  final int count;
  final int daysSinceLast;

  /// The full combo in which this number last appeared (e.g. "06-19")
  final String? lastCombo;
  const NumberStat(
      {required this.number,
      required this.count,
      required this.daysSinceLast,
      this.lastCombo});
}

/// A full combo pair (e.g. "06-19") with hit count and last-seen date
class ComboStat {
  final String combo; // "06-19"
  final int count;
  final int daysSinceLast;
  final String lastDate; // "Jan 7, 2026"
  const ComboStat(
      {required this.combo,
      required this.count,
      required this.daysSinceLast,
      required this.lastDate});
}

/// A single-number frequency in pairs (one number known, partner varies)
class PairStat {
  final int number;
  final int count;
  final bool isFirst; // true → number-XX, false → XX-number
  const PairStat(
      {required this.number, required this.count, required this.isFirst});
}

class EZ2Stats {
  final List<NumberStat> hot;
  final List<NumberStat> cold;
  final List<ComboStat> topCombos; // top 5 full combos
  final List<PairStat> topPairs; // top 10 single-number frequencies
  const EZ2Stats(
      {required this.hot,
      required this.cold,
      required this.topCombos,
      required this.topPairs});
}

// ── Stream update ─────────────────────────────────────────────
class MonthUpdate {
  final String mk;
  final List<DayResult> rows;
  const MonthUpdate({required this.mk, required this.rows});
}

// ── Ticket ────────────────────────────────────────────────────
class TicketMatch {
  final String date;
  final String slot;
  final String combo;
  final bool isStraight;
  final int prize;

  const TicketMatch(
      {required this.date,
      required this.slot,
      required this.combo,
      required this.isStraight,
      required this.prize});

  String get draw {
    if (slot == '2pm') return '2:00 PM';
    if (slot == '5pm') return '5:00 PM';
    return '9:00 PM';
  }
}
