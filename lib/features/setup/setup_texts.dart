// The words of the setup screens that more than one of them says: the small print under a mode, the
// level and character names, the seat colours, the coin amounts and the one-line reasons a table cannot
// be entered.
//
// Why here: Game options, Mela Tour, Pass & play and the VS screen all name the same modes, levels and
// bots, and must say them the same way in every language. Every phrase is one plain `tr()` literal in a
// switch or a function (never in a const), so the translation catalogue finds it once.

import 'package:ludo_engine/ludo_engine.dart';

import '../../core/l10n/tr.dart';
import '../../core/widgets/count_up_text.dart' show lmGroupDigits;
import '../../domain/venues.dart';
import 'table_choice.dart';

/// The small print under a mode tile ("4 pieces home").
String modeSub(GameMode mode) => switch (mode) {
      GameMode.classic => tr('4 pieces home'),
      GameMode.quick => tr('1 piece · 5 min'),
      GameMode.master => tr('blockades'),
      GameMode.rush => tr('5 min · points'),
      GameMode.mayhem => tr('power-ups'),
      GameMode.teams => tr('2 vs 2'),
    };

/// The name of a computer level.
String levelName(BotLevel level) => switch (level) {
      BotLevel.easy => tr('Easy'),
      BotLevel.normal => tr('Normal'),
      BotLevel.hard => tr('Hard'),
      BotLevel.expert => tr('Expert'),
    };

/// The title of a bot character ("Hunter"); empty for an unknown id.
String botTitle(String? id) => switch (id) {
      'raja' => tr('Hunter'),
      'mitu' => tr('Turtle'),
      'tara' => tr('Racer'),
      'golu' => tr('Hoarder'),
      'nani' => tr('Sage'),
      _ => '',
    };

/// One line on how a bot character plays (design board B, "Personalities").
String botHabit(String? id) => switch (id) {
      'raja' => tr('Chases captures, leaves pieces exposed'),
      'mitu' => tr('Waits on stars, rarely risks a piece'),
      'tara' => tr('Races one piece home early'),
      'golu' => tr('Hoards power cards, loves Swap'),
      'nani' => tr('Balanced and patient · Expert only'),
      _ => '',
    };

/// The colour of a seat in capitals ("RED").
String seatColourName(Seat seat) => switch (seat) {
      Seat.red => tr('RED'),
      Seat.green => tr('GREEN'),
      Seat.yellow => tr('YELLOW'),
      Seat.blue => tr('BLUE'),
    };

/// "250 coins" with thousands separators (the plural follows the number).
String coinsLabel(int n) => tr('{n, plural, one {{amount} coin} other {{amount} coins}}', {'n': n, 'amount': lmGroupDigits(n)});

/// "3 players".
String playersLabel(int n) => tr('{n, plural, one {# player} other {# players}}', {'n': n});

/// Why [venue] cannot be entered ([TableRefusal.none] has no text).
String refusalText(TableRefusal why, Venue venue) => switch (why) {
      TableRefusal.none => '',
      TableRefusal.locked => tr('Reach level {n} to play here', {'n': venue.minLevel}),
      TableRefusal.tooFewCoins => tr('Not enough coins for this table'),
      TableRefusal.tablesClosed => tr('Coin tables are off in Parent controls'),
    };
