// Per-seat tallies a match keeps for the results screen and Insights: how many
// rivals a seat sent back, how often it was sent back, and how many dice it rolled.
//
// Why part of the state (not derived from events): the autosave and the Wi-Fi
// snapshot carry the state only, and a match resumed after the app was killed
// must still report the right totals at the end.

import '../json.dart';

/// Per-seat tallies the results screen and Insights use.
class SeatStats {
  const SeatStats({this.captures = 0, this.timesCaptured = 0, this.rolls = 0});

  /// Rival pieces this seat's pieces sent back.
  final int captures;

  /// Times one of this seat's pieces was sent back.
  final int timesCaptured;

  /// Dice rolled by this seat (helping 6s and card rolls included).
  final int rolls;

  Map<String, Object?> toJson() => {'captures': captures, 'timesCaptured': timesCaptured, 'rolls': rolls};

  factory SeatStats.fromJson(Map<String, Object?> j) => SeatStats(
    captures: readIntOrNull(j['captures']) ?? 0,
    timesCaptured: readIntOrNull(j['timesCaptured']) ?? 0,
    rolls: readIntOrNull(j['rolls']) ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is SeatStats && other.captures == captures && other.timesCaptured == timesCaptured && other.rolls == rolls;

  @override
  int get hashCode => Object.hash(captures, timesCaptured, rolls);

  @override
  String toString() => 'SeatStats($captures captures, $timesCaptured lost, $rolls rolls)';
}
