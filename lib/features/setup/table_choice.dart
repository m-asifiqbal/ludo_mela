// Where a game against the computer is played, and whether the player may sit down there.
//
// A table is free practice (XP only) or one of the eight Mela Tour venues (coins at stake). The save
// has the final say (`SaveController.payEntry` refuses below the level gate, with too few coins and
// when Parent controls closed the coin tables); [refusalFor] asks the same three questions first, so a
// screen can say WHY on the spot instead of closing and failing. Pure Dart.

import '../../domain/venues.dart';

/// Free practice, or a Mela Tour [venue].
class TableChoice {
  /// Free practice: no entry, no prize, half XP.
  const TableChoice.practice() : venue = null;

  /// A coin table.
  const TableChoice.venue(Venue this.venue);

  /// The venue, or null for practice.
  final Venue? venue;

  bool get isPractice => venue == null;

  String? get venueId => venue?.id;

  @override
  bool operator ==(Object other) => other is TableChoice && other.venue?.id == venue?.id;

  @override
  int get hashCode => venue?.id.hashCode ?? 0;
}

/// Why a venue cannot be entered right now.
enum TableRefusal {
  /// It can.
  none,

  /// The player level is below its gate.
  locked,

  /// The wallet cannot pay the entry.
  tooFewCoins,

  /// Parent controls closed the coin tables.
  tablesClosed,
}

/// Whether [venue] can be entered with [coins] at [level] (Parent controls first, then the gate, then the wallet).
TableRefusal refusalFor(Venue venue, {required int level, required int coins, required bool tablesClosed}) {
  if (tablesClosed) return TableRefusal.tablesClosed;
  if (!venue.isOpenAt(level)) return TableRefusal.locked;
  if (coins < venue.entry) return TableRefusal.tooFewCoins;
  return TableRefusal.none;
}

/// The table a player sits at when they have not picked one: the highest venue open at [level] whose
/// entry [coins] can pay, else practice (always when coin tables are closed).
TableChoice defaultTable({required int level, required int coins, required bool tablesClosed}) {
  if (tablesClosed) return const TableChoice.practice();
  Venue? best;
  for (final v in Venues.openAt(level)) {
    if (v.entry <= coins) best = v;
  }
  return best == null ? const TableChoice.practice() : TableChoice.venue(best);
}
