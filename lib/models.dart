// lib/models.dart

// ── DayResult ─────────────────────────────────────────────────
// Represents all three draws for a single date.
// winner fields are nullable — populated only when the DB has winner_count data.
class DayResult {
  final String  date;       // "Mar 23, 2026"
  final String  day;        // "Monday"
  final String? result2pm;  // "28-30" or null if not drawn yet
  final String? result5pm;
  final String? result9pm;
  final int?    winners2pm; // null until winner_count column is populated
  final int?    winners5pm;
  final int?    winners9pm;

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

  /// Creates an empty placeholder for a date with no draws yet.
  factory DayResult.empty(String date, String day) =>
      DayResult(date: date, day: day);

  /// Creates a copy with specific fields overridden.
  DayResult copyWith({
    String?  date,
    String?  day,
    String?  result2pm,
    String?  result5pm,
    String?  result9pm,
    int?     winners2pm,
    int?     winners5pm,
    int?     winners9pm,
  }) =>
      DayResult(
        date:       date       ?? this.date,
        day:        day        ?? this.day,
        result2pm:  result2pm  ?? this.result2pm,
        result5pm:  result5pm  ?? this.result5pm,
        result9pm:  result9pm  ?? this.result9pm,
        winners2pm: winners2pm ?? this.winners2pm,
        winners5pm: winners5pm ?? this.winners5pm,
        winners9pm: winners9pm ?? this.winners9pm,
      );
}

// ── Draw status ───────────────────────────────────────────────
enum DrawStatus { upcoming, live, done }

// ── Stats models ──────────────────────────────────────────────

/// A single number (1–31) with its appearance frequency.
class NumberStat {
  final int     number;
  final int     count;
  final int     daysSinceLast;
  final String? lastCombo; // e.g. "06-19"

  const NumberStat({
    required this.number,
    required this.count,
    required this.daysSinceLast,
    this.lastCombo,
  });
}

/// A full combo pair (e.g. "06-19") with its appearance count.
class ComboStat {
  final String combo;
  final int    count;
  final int    daysSinceLast;
  final String lastDate;

  const ComboStat({
    required this.combo,
    required this.count,
    required this.daysSinceLast,
    required this.lastDate,
  });
}

/// How often a single number appears across all draws.
class PairStat {
  final int  number;
  final int  count;
  final bool isFirst;

  const PairStat({
    required this.number,
    required this.count,
    required this.isFirst,
  });
}

class EZ2Stats {
  final List<NumberStat> hot;
  final List<NumberStat> cold;
  final List<ComboStat>  topCombos;
  final List<PairStat>   topPairs;

  const EZ2Stats({
    required this.hot,
    required this.cold,
    required this.topCombos,
    required this.topPairs,
  });
}

// ── Stream events ─────────────────────────────────────────────

class MonthUpdate {
  final String          mk;
  final List<DayResult> rows;
  const MonthUpdate({required this.mk, required this.rows});
}

// ── Ticket checker ────────────────────────────────────────────

class TicketMatch {
  final String date;
  final String slot;
  final String combo;
  final bool   isStraight;
  final int    prize;

  const TicketMatch({
    required this.date,
    required this.slot,
    required this.combo,
    required this.isStraight,
    required this.prize,
  });

  String get drawLabel {
    if (slot == '2pm') return '2:00 PM';
    if (slot == '5pm') return '5:00 PM';
    return '9:00 PM';
  }
}
