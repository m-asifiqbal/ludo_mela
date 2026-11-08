// Bot stickers: when a bot "says" something about what just happened.
//
// Design board B: "Bots react with stickers (captured -> angry, capture -> cool) at most
// once every 3 turns, and can be muted." The rule lives in the engine, not in the match
// screen, so a local match, a Wi-Fi host and the tests all agree on it; the screen only
// draws the bubble. `BotReactions` is a tiny stateful helper: feed it the events of every
// step (`StepResult.events`) with the state after them and it answers which bot sends
// which sticker, if any. Only bots react — never a human or a remote player — and a
// bot's quiet time is counted in `GameState.turnNumber`, the engine's own clock.

import '../geometry.dart';
import '../model/events.dart';
import '../state/game_state.dart';

/// The sticker ids the match screen's picker offers (design board "Match"), as the strings
/// `MatchSession.sendSticker` carries.
abstract final class StickerIds {
  static const happy = 'happy';
  static const laugh = 'laugh';
  static const wow = 'wow';
  static const cool = 'cool';
  static const angry = 'angry';
  static const cry = 'cry';

  /// Every sticker, in picker order.
  static const all = [happy, laugh, wow, cool, angry, cry];
}

/// One sticker a bot sends: [seat] shows [sticker] (a `StickerIds` value).
class BotSticker {
  const BotSticker(this.seat, this.sticker);

  final Seat seat;
  final String sticker;

  @override
  bool operator ==(Object other) => other is BotSticker && other.seat == seat && other.sticker == sticker;

  @override
  int get hashCode => Object.hash(seat, sticker);

  @override
  String toString() => 'BotSticker(${seat.name}: $sticker)';
}

/// Decides when bots react. One instance per match; call [react] after every step.
class BotReactions {
  BotReactions({this.cooldownTurns = defaultCooldownTurns, this.muted = false});

  /// A bot sends at most one sticker per this many turns ("once every 3 turns").
  static const int defaultCooldownTurns = 3;

  final int cooldownTurns;

  /// Settings "Bot stickers" off: nobody reacts, and nothing counts against the cooldown.
  bool muted;

  final Map<Seat, int> _lastTurn = {};

  /// The stickers bots send for [events] (the events of one step), given the state [after] that step.
  ///
  /// * a bot that **captured** a piece sends `cool`;
  /// * a bot whose piece was **captured** sends `angry`;
  /// * each bot reacts at most once per call (being captured wins over capturing), and not at all
  ///   until [cooldownTurns] turns have passed since its last sticker (`after.turnNumber` is the clock).
  ///
  /// Captures by or of a seat that is not a bot (a human, a Wi-Fi guest) produce nothing for that seat.
  List<BotSticker> react(GameState after, Iterable<GameEvent> events) {
    if (muted) return const [];
    final wanted = <Seat, String>{};
    for (final e in events) {
      if (e is! CapturedEvent) continue;
      wanted.putIfAbsent(e.by, () => StickerIds.cool);
      wanted[e.victim] = StickerIds.angry;
    }
    final out = <BotSticker>[];
    for (final entry in wanted.entries) {
      final seat = entry.key;
      if (after.config.tryPlayerOf(seat)?.isBot != true) continue;
      final last = _lastTurn[seat];
      if (last != null && after.turnNumber - last < cooldownTurns) continue;
      _lastTurn[seat] = after.turnNumber;
      out.add(BotSticker(seat, entry.value));
    }
    return out;
  }

  /// Forgets every cooldown (a new match, or a restored one).
  void reset() => _lastTurn.clear();
}
