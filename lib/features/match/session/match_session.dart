// MatchSession: the one thing the match screen talks to (architecture.md · "Match session").
//
// Why an interface: the same screen plays a local game (LocalMatchSession: bots + people on this
// phone) and, later, a Wi-Fi room (LanHostSession / LanGuestSession). The screen never touches
// LudoGame; it renders what the session publishes and sends what the player does.
//
// PUBLIC API IN SHORT
//   Read     session.setup  (MatchSetup: venue, practice / cup / puzzle / tabletop flags, mySeat)
//            session.config (engine MatchConfig: mode, rules, seats with kind / level / personality)
//            session.state  (GameState now: ahead of the screen while it animates; render from updates)
//            session.clock  (TurnClock? of the human who must act) · session.rushClock · session.paused
//            canControl(seat): a human of THIS phone sits there (pass & play: several).
//   Listen   session.updates is a broadcast Stream<MatchUpdate>, one per applied action:
//              MatchUpdate { state, events (play them in order), action, clock, rush, sticker }.
//            Extra updates carry NO events: a new `clock` / `rush` (started, frozen, resumed; clock null
//            = hide the pie) or a `sticker` (quick chat). Compare `update.events.isEmpty`.
//   Play     roll()  rolls the die (in the roll-off phase: the seat's roll-off die); move(Move) plays one of
//            legalMovesOf(state); useCard(CardUse) plays a power card (legalCardUsesOf(state)); pass() ends
//            an unplayable roll when legalMovesOf(state) is empty (Mayhem card window). Only the
//            seat on turn may act, and only when canControl(state.current); other calls are ignored.
//            Hints, move tags and path previews come from the engine (hintFor, analyzeMove) on `state`.
//   Gates    setAnimating(true) while the screen plays events: bots, the 15 s timer and a Rush time-up wait;
//            setAnimating(false) when the events are done. setPaused(true) (pause menu) freezes the timers,
//            Rush clock and bots; pause it too when the app goes to the background. A session starts running:
//            the first bot move comes after its think time (no start call needed).
//   Leave    concede() leaves the match: every local human concedes, the match ends at once and counts as a
//            loss (entry not returned). Completes after the loss is recorded; the SCREEN then navigates
//            (lobby). A match that finishes normally records itself and opens /result after the screen is
//            idle (setAnimating(false), not paused) — hold setAnimating(true) for a win celebration.
//   Chat     sendSticker(seat, id) publishes a sticker (ids in [Stickers]) or a quick-chat phrase (free
//            text, translated by the screen). Bots may react on their own (the engine's BotReactions:
//            captured → angry, capture → cool; at most once every 3 turns per bot) when Settings › bot
//            stickers is on.
//   End      dispose() (the provider calls it). A running match stays in the autosave.

import 'package:flutter/foundation.dart';
import 'package:ludo_engine/ludo_engine.dart';

import 'match_setup.dart';

/// Sticker ids the picker offers (design board "Match": happy · laugh · wow · cool · angry · cry). They are the
/// engine's own ([StickerIds]), so the picker, the bots' reactions and a Wi-Fi room speak the same ids.
abstract final class Stickers {
  static const happy = StickerIds.happy;
  static const laugh = StickerIds.laugh;
  static const wow = StickerIds.wow;
  static const cool = StickerIds.cool;
  static const angry = StickerIds.angry;
  static const cry = StickerIds.cry;

  /// In picker order.
  static const all = StickerIds.all;

  /// True when [text] is a sticker id (anything else is a quick-chat phrase).
  static bool isSticker(String text) => all.contains(text);
}

/// A sticker or quick-chat phrase shown beside [from]'s avatar for a moment.
@immutable
class StickerMessage {
  const StickerMessage(this.from, this.sticker);

  final Seat from;

  /// A [Stickers] id, or a quick-chat phrase.
  final String sticker;

  @override
  bool operator ==(Object other) => other is StickerMessage && other.from == from && other.sticker == sticker;

  @override
  int get hashCode => Object.hash(from, sticker);
}

/// The turn timer of the human who must act (the pie inside the avatar). Published when it starts,
/// freezes (pause / animation) or resumes; the screen animates the pie itself from [remaining].
@immutable
class TurnClock {
  const TurnClock({required this.seat, required this.total, required this.remaining, required this.running});

  final Seat seat;

  /// The whole allowance (15 s; 20 s in pass & play when it is switched on).
  final Duration total;

  /// What was left when this clock was published.
  final Duration remaining;

  /// False while frozen: the pie stays where it is.
  final bool running;

  /// The last seconds, when the avatar frame pulses.
  static const urgentWindow = Duration(seconds: 3);

  /// 1 = full, 0 = out of time.
  double get fraction => total <= Duration.zero ? 0 : (remaining.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);

  bool get urgent => remaining <= urgentWindow;

  @override
  bool operator ==(Object other) =>
      other is TurnClock &&
      other.seat == seat &&
      other.total == total &&
      other.remaining == remaining &&
      other.running == running;

  @override
  int get hashCode => Object.hash(seat, total, remaining, running);
}

/// The Rush match clock (5 minutes; the session fires `RushTimeUp` at zero). Published when it
/// starts, freezes (pause) or resumes.
@immutable
class RushClock {
  const RushClock({required this.total, required this.remaining, required this.running});

  final Duration total;
  final Duration remaining;
  final bool running;

  @override
  bool operator ==(Object other) =>
      other is RushClock && other.total == total && other.remaining == remaining && other.running == running;

  @override
  int get hashCode => Object.hash(total, remaining, running);
}

/// One thing that happened in the match, for the screen to play.
@immutable
class MatchUpdate {
  const MatchUpdate({required this.state, this.events = const [], this.action, this.clock, this.rush, this.sticker});

  /// The position after [events].
  final GameState state;

  /// What the action caused, in the order to animate it (empty for a clock or sticker update).
  final List<GameEvent> events;

  /// The engine action that produced [events]; null for clock / sticker updates.
  final Action? action;

  /// The turn timer now; null = none running (hide the pie).
  final TurnClock? clock;

  /// The Rush clock now (Rush only).
  final RushClock? rush;

  /// A sticker to show (a sticker-only update).
  final StickerMessage? sticker;

  /// True for a plain game update (an action was applied).
  bool get isAction => action != null;
}

/// What the match screen plays against.
abstract class MatchSession {
  /// The game as it was launched: seats, venue, flags.
  MatchSetup get setup;

  /// The engine configuration (mode, rules, seats).
  MatchConfig get config;

  /// The position now.
  GameState get state;

  /// One [MatchUpdate] per applied action, plus clock and sticker updates.
  Stream<MatchUpdate> get updates;

  /// The running or frozen turn timer, or null.
  TurnClock? get clock;

  /// The Rush clock, or null outside Rush.
  RushClock? get rushClock;

  /// True while the pause menu holds the match.
  bool get paused;

  /// A local human sits in [seat].
  bool canControl(Seat seat);

  Future<void> roll();
  Future<void> move(Move m);
  Future<void> useCard(CardUse c);

  /// Ends a roll that cannot be played (`legalMovesOf(state)` is empty while awaiting a move: Mayhem keeps
  /// the roll open for a rescuing card, or the Auto-pass rule is off). Ignored otherwise.
  Future<void> pass();

  void sendSticker(Seat from, String sticker);

  /// Bots and timeouts wait while [busy] (the screen is animating events).
  void setAnimating(bool busy);

  /// The pause menu freezes timers and bots.
  void setPaused(bool paused);

  /// Leave the match (counts as a loss).
  Future<void> concede();

  void dispose();
}
