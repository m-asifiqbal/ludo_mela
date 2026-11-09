// Which bot character sits in each computer seat of a game against the computer.
//
// Raja, Mitu, Tara, Golu and Nani are characters with their own style (design board B,
// "Personalities"); any of them can play at any level except Nani, whom the lobby only offers at
// Expert (`BotPersonality.offeredAt`). A lineup keeps three slots (the most computers a game has) and
// the screen shows as many as the game needs. Picking a character another seat already has swaps the
// two, so a table never seats the same bot twice. Pure Dart; the lineup is not remembered between
// games (the engine's defaults are Raja, Mitu, Tara).

import 'package:ludo_engine/ludo_engine.dart';

import '../match/session/match_setup.dart' show BotCast;

class OpponentLineup {
  const OpponentLineup([this.ids = defaults]);

  /// Raja, Mitu and Tara: who sits down when nobody chose.
  static const List<String> defaults = ['raja', 'mitu', 'tara'];

  /// The personality ids of the three slots.
  final List<String> ids;

  /// The characters offered at [level], in lobby order (Nani only at Expert).
  static List<String> offered(BotLevel level) => [
        for (final c in BotCast.characters)
          if (BotPersonality.byId(c.$1).offeredAt(level)) c.$1,
      ];

  /// Whether [id] may be picked at [level].
  static bool isOffered(String id, BotLevel level) => BotPersonality.byId(id).offeredAt(level);

  /// The character in [slot] (0-based).
  String operator [](int slot) => ids[slot];

  /// [id] takes [slot]; whoever had [id] before takes the character [slot] had (a swap). A character
  /// that is not offered at [level] changes nothing.
  OpponentLineup pick(int slot, String id, BotLevel level) {
    if (!isOffered(id, level) || ids[slot] == id) return this;
    final next = [...ids];
    final other = next.indexOf(id);
    if (other >= 0) next[other] = next[slot];
    next[slot] = id;
    return OpponentLineup(next);
  }

  /// The same lineup at [level]: a character that level does not offer (Nani below Expert) is replaced
  /// by the first offered one nobody else plays.
  OpponentLineup forLevel(BotLevel level) {
    final next = [...ids];
    for (var i = 0; i < next.length; i++) {
      if (isOffered(next[i], level)) continue;
      final taken = next.toSet();
      next[i] = offered(level).firstWhere((id) => !taken.contains(id), orElse: () => defaults[i]);
    }
    return OpponentLineup(next);
  }

  /// The characters of the first [bots] seats.
  List<String> forSeats(int bots) => ids.take(bots).toList();
}
