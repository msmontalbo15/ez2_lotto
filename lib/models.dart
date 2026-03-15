// lib/models.dart

// ── Single draw result ────────────────────────────────────────
class DrawResult {
  final String slot; // '2pm' | '5pm' | '9pm'
  final String? combo; // '14-04' or null
  final int? winners;

  const DrawResult({required this.slot, this.combo, this.winners});

  int? get num1 => combo != null ? int.tryParse(combo!.split('-')[0]) : null;
  int? get num2 => combo != null ? int.tryParse(combo!.split('-')[1]) : null;

  factory DrawResult.fromJson(Map<String, dynamic> json) => DrawResult(
        slot: json['draw_slot'] as String,
        combo: json['combo'] as String?,
        winners: json['winners'] as int?,
      );
}

// ── One day's results (3 slots) ───────────────────────────────
class DayResult {
  final String date; // 'Mar 15, 2026'
  final String day; // 'Saturday'
  final String? result2pm;
  final String? result5pm;
  final String? result9pm;
  final int? winners2pm;
  final int? winners5pm;
  final int? winners9pm;
  final DateTime? lastUpdated;

  const DayResult({
    required this.date,
    required this.day,
    this.result2pm,
    this.result5pm,
    this.result9pm,
    this.winners2pm,
    this.winners5pm,
    this.winners9pm,
    this.lastUpdated,
  });

  String? resultFor(String slot) => slot == '2pm'
      ? result2pm
      : slot == '5pm'
          ? result5pm
          : result9pm;

  int? winnersFor(String slot) => slot == '2pm'
      ? winners2pm
      : slot == '5pm'
          ? winners5pm
          : winners9pm;

  bool get hasAnyResult =>
      result2pm != null || result5pm != null || result9pm != null;

  /// Merge live today data on top of a DB row
  DayResult mergeWith(DayResult live) => DayResult(
        date: date,
        day: day,
        result2pm: live.result2pm ?? result2pm,
        result5pm: live.result5pm ?? result5pm,
        result9pm: live.result9pm ?? result9pm,
        winners2pm: live.winners2pm ?? winners2pm,
        winners5pm: live.winners5pm ?? winners5pm,
        winners9pm: live.winners9pm ?? winners9pm,
        lastUpdated: live.lastUpdated ?? lastUpdated,
      );

  factory DayResult.fromMonthJson(Map<String, dynamic> json) {
    final w = (json['winners'] as Map<String, dynamic>?) ?? {};
    return DayResult(
      date: json['date'] as String,
      day: json['day'] as String,
      result2pm: json['2pm'] as String?,
      result5pm: json['5pm'] as String?,
      result9pm: json['9pm'] as String?,
      winners2pm: w['2pm'] as int?,
      winners5pm: w['5pm'] as int?,
      winners9pm: w['9pm'] as int?,
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'] as String)
          : null,
    );
  }

  factory DayResult.fromDayJson(
      Map<String, dynamic> json, String date, String day) {
    final w = (json['winners'] as Map<String, dynamic>?) ?? {};
    return DayResult(
      date: date,
      day: day,
      result2pm: json['2pm'] as String?,
      result5pm: json['5pm'] as String?,
      result9pm: json['9pm'] as String?,
      winners2pm: w['2pm'] as int?,
      winners5pm: w['5pm'] as int?,
      winners9pm: w['9pm'] as int?,
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'] as String)
          : null,
    );
  }

  /// Empty skeleton for today before fetch completes
  factory DayResult.empty(String date, String day) =>
      DayResult(date: date, day: day);
}

// ── Draw status ───────────────────────────────────────────────
enum DrawStatus { upcoming, live, done }

// ── Next draw info ────────────────────────────────────────────
class NextDrawInfo {
  final String slot;
  final String emoji;
  final String label;
  final int minsUntil;
  const NextDrawInfo({
    required this.slot,
    required this.emoji,
    required this.label,
    required this.minsUntil,
  });
}

// ── Month tab ─────────────────────────────────────────────────
class MonthTab {
  final String label; // 'Marso 2026'
  final String monthKey; // '2026-03'
  final int year;
  final int month; // 1-indexed
  const MonthTab({
    required this.label,
    required this.monthKey,
    required this.year,
    required this.month,
  });
}

// ── Stats ─────────────────────────────────────────────────────
class ComboStat {
  final int rank;
  final String combo;
  final int hits;
  final String? lastSeenDate;
  final String? lastSeenSlot;
  const ComboStat({
    required this.rank,
    required this.combo,
    required this.hits,
    this.lastSeenDate,
    this.lastSeenSlot,
  });
}

class NumStat {
  final String num;
  final int count;
  const NumStat({required this.num, required this.count});
}

class EZ2Stats {
  final List<ComboStat> topCombos;
  final List<NumStat> hotNums;
  final List<NumStat> coldNums;
  const EZ2Stats({
    required this.topCombos,
    required this.hotNums,
    required this.coldNums,
  });
}

// ── Ticket check result ───────────────────────────────────────
class TicketMatch {
  final String date;
  final String draw;
  final String combo;
  final bool isStraight;
  const TicketMatch({
    required this.date,
    required this.draw,
    required this.combo,
    required this.isStraight,
  });
  int get prize => isStraight ? 4000 : 2000;
}
