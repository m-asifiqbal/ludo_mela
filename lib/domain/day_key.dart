// Calendar-day helpers: a "day" is the player's local date, never 24 hours.
//
// Why: daily counters (reward-ad budget, gift, missions, ladder) reset at local
// midnight, and a day difference taken with `Duration.inDays` on local
// midnights is wrong across a daylight-saving change (a 23 h day reads as 0).
// Everything here works on the calendar date only, so a clock-zone change or a
// DST shift never moves a day.

/// Pure calendar-date arithmetic. Dates are `yyyy-MM-dd` strings when stored.
abstract final class DayKey {
  /// `yyyy-MM-dd` of [d]'s own calendar date (the wall-clock date it carries).
  static String of(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The local midnight of [key] (`yyyy-MM-dd`), or null when malformed.
  static DateTime? parse(String? key) {
    if (key == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
    if (m == null) return null;
    final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
    final date = DateTime(y, mo, d);
    // Reject impossible dates ("2026-02-31" would silently roll into March).
    return date.year == y && date.month == mo && date.day == d ? date : null;
  }

  /// Whole calendar days from [a] to [b] (negative when [b] is earlier),
  /// ignoring the time of day and any DST change in between.
  static int daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  /// [d]'s calendar date moved by [days], at local midnight (DST-safe).
  static DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);
}
