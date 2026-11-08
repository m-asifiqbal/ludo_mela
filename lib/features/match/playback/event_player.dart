// EventPlayer: plays what one engine update caused, in order, on the board.
//
// The session already knows the new position; this walks its events (docs/engine_spec.md · "Event order per
// action") so the player SEES it: the dice toss, a hop per square, the pop out of the yard, the POW! burst and
// the victim spinning home, HOME!, arrow zips and swaps, toasts, sounds and haptics. Timings come from
// Motion.game(d, speed) (never the dice roll); with Reduce Motion pieces jump and only the waits that carry
// meaning (toasts, the no-move pause) stay short. It talks to the screen only through [PlaybackHooks]
// (the controller owns dice, toasts and mini dice) and to the board through [BoardModel].

import 'dart:async';

import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;

import '../../../core/feedback/feedback.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/toast.dart' show ToastTone;
import '../board/board_model.dart';
import '../board/piece_anim.dart';
import '../match_models.dart';
import '../match_motion.dart';
import '../mayhem/power_cards.dart';
import '../session/match_session.dart';

/// What the player needs from the screen.
class PlaybackHooks {
  const PlaybackHooks({
    required this.toss,
    required this.rolled,
    required this.turnPassed,
    required this.celebrate,
    required this.toast,
    required this.isMine,
    required this.settled,
    required this.cancelled,
  });

  /// Tosses the die of [seat] and completes when it has landed on [value].
  final Future<void> Function(Seat seat, int value) toss;

  /// A die has been read (the mini dice next to the avatar).
  final void Function(Seat seat, int value) rolled;
  final void Function(Seat from, Seat to) turnPassed;

  /// The match is over: the verdict toast and the confetti (the Win screen owns the cheer); completes when the
  /// screen may leave.
  final Future<void> Function(GameOverEvent e) celebrate;
  final void Function(String text, ToastTone tone) toast;

  /// A person of this phone sits in the seat.
  final bool Function(Seat seat) isMine;

  /// The position as last settled on screen.
  final GameState Function() settled;

  /// The screen is gone: the rest of the update is dropped (no more sounds, toasts or bursts on a dead board).
  final bool Function() cancelled;
}

class EventPlayer {
  EventPlayer({required this.board, required this.env, required this.hooks});

  final BoardModel board;
  final MatchEnv env;
  final PlaybackHooks hooks;

  FeedbackService get _fx => env.feedback;

  Duration _g(Duration d) => env.reduced() ? Duration.zero : Motion.game(d, env.speed);
  Future<void> _wait(Duration d) => d <= Duration.zero ? Future<void>.value() : Future<void>.delayed(d);
  bool _you(Seat s) => env.look().isYou(s);
  String _name(Seat s) => env.look().nameOf(s);
  void _say(String text, [ToastTone tone = ToastTone.gold]) => hooks.toast(text, tone);

  /// Plays every event of [u].
  Future<void> play(MatchUpdate u) async {
    final ev = u.events;
    for (var i = 0; i < ev.length; i++) {
      if (hooks.cancelled()) return;
      switch (ev[i]) {
        case RollOffEvent e:
          await _rollOff(e);
        case RollOffResultEvent e:
          _rollOffResult(e);
        case RolledEvent e:
          await _rolled(e);
        case HelpingSixEvent():
          _say(tr('A helping six!'), ToastTone.green);
        case ThreeSixesEvent e:
          _say(_you(e.seat) ? tr('Three sixes — turn passes') : tr('{name} rolled three sixes', {'name': _name(e.seat)}), ToastTone.red);
          unawaited(_fx.play(Sfx.noMove));
          await _wait(_g(Motion.noMovePause));
        case NoMoveEvent e:
          await _noMove(e);
        case EnteredEvent e:
          await _entered(e);
        case MovedEvent e:
          await _moved(e);
        case CapturedEvent e:
          final group = <CapturedEvent>[e];
          while (i + 1 < ev.length && ev[i + 1] is CapturedEvent) {
            group.add(ev[++i] as CapturedEvent);
          }
          await _captured(group, again: ev.skip(i + 1).any((x) => x is BonusRollEvent && x.reason == BonusReason.capture));
        case ReachedHomeEvent e:
          await _home(e, again: ev.skip(i + 1).any((x) => x is BonusRollEvent && x.reason == BonusReason.home));
        case BonusRollEvent e:
          if (e.reason == BonusReason.six && hooks.isMine(e.seat)) {
            _say(_you(e.seat) ? tr('Six! Roll again') : tr('{name}: six! Roll again', {'name': _name(e.seat)}));
          }
        case TurnPassedEvent e:
          hooks.turnPassed(e.from, e.to);
        case PlayerFinishedEvent e:
          _say(_you(e.seat) ? tr('You finished in place {n}!', {'n': e.place}) : tr('{name} finished in place {n}', {'name': _name(e.seat), 'n': e.place}), ToastTone.green);
        case ConcededEvent e:
          _say(tr('{name} left the match', {'name': _name(e.seat)}), ToastTone.red);
        case GameOverEvent e:
          await hooks.celebrate(e);
        case CardDrawnEvent e:
          _drew(e.seat, e.card);
        case UnderdogDrawEvent e:
          unawaited(_fx.play(Sfx.card));
          _say(
            _you(e.seat)
                ? tr('Underdog draw! You get {card}', {'card': cardName(e.card)})
                : tr('Underdog draw! {name} gets {card}', {'name': _name(e.seat), 'card': cardName(e.card)}),
            ToastTone.green,
          );
          await _wait(_g(MatchMotion.beat));
        case HandFullEvent e:
          if (hooks.isMine(e.seat)) _say(tr('Hand full — no card drawn'));
        case CardPlayedEvent e:
          await _cardPlayed(e);
        case ArrowZipEvent e:
          await _zip(e);
        case ChestEvent e:
          unawaited(_fx.play(Sfx.coin));
          board.burst(BurstKind.star, e.seat, e.piece, board.progressOf(e.seat, e.piece), text: '+${e.coins}', color: LmColors.coinMid);
          if (hooks.isMine(e.seat)) _say(tr('Chest! +{n} coins if you finish', {'n': e.coins}), ToastTone.green);
          await _wait(_g(MatchMotion.chest));
        case MelaEventStarted e:
          unawaited(_fx.play(Sfx.pop));
          _say(eventTitle(e.kind), ToastTone.green);
        case StarsDriftedEvent e:
          board.setStars(e.stars);
        case ShieldBlockedEvent():
          unawaited(_fx.play(Sfx.shield));
          _say(tr('Shield held!'), ToastTone.green);
          await _wait(_g(MatchMotion.shieldHeld));
        case PieceSwappedEvent e:
          await _swapped(e);
        default:
          break;
      }
    }
  }

  // ── Dice ──────────────────────────────────────────────────────────────

  Future<void> _rollOff(RollOffEvent e) async {
    unawaited(_fx.play(Sfx.diceShake, volume: .6));
    await hooks.toss(e.seat, e.value);
    hooks.rolled(e.seat, e.value);
    _say(_you(e.seat) ? tr('You rolled {n}', {'n': e.value}) : tr('{name} rolled {n}', {'name': _name(e.seat), 'n': e.value}));
    await _wait(_g(MatchMotion.beat));
  }

  void _rollOffResult(RollOffResultEvent e) {
    final w = e.winner;
    if (w == null) {
      _say(tr('Tie! Roll again'));
    } else {
      _say(_you(w) ? tr('You go first') : tr('{name} goes first', {'name': _name(w)}), ToastTone.green);
    }
  }

  Future<void> _rolled(RolledEvent e) async {
    unawaited(_fx.play(Sfx.diceShake, volume: .6));
    await hooks.toss(e.seat, e.value);
    hooks.rolled(e.seat, e.value);
    if (e.value == 6) {
      unawaited(_fx.play(Sfx.six));
      _fx.medium();
    }
  }

  Future<void> _noMove(NoMoveEvent e) async {
    unawaited(_fx.play(Sfx.noMove));
    if (_you(e.seat)) {
      _say(e.dice.length == 1 ? tr('No move with a {n}', {'n': e.dice.first}) : tr('No move'));
    } else {
      _say(tr('{name} can’t move', {'name': _name(e.seat)}));
    }
    await _wait(_g(Motion.noMovePause));
  }

  // ── Pieces ────────────────────────────────────────────────────────────

  Future<void> _entered(EnteredEvent e) async {
    unawaited(_fx.play(Sfx.enter));
    board.burst(BurstKind.ring, e.seat, e.piece, 0, color: LmColors.white);
    await board.run(PieceAnim([PieceTrack(e.seat, e.piece, TrackKind.pop, const [-1, 0])], _g(Motion.leaveYard)));
  }

  Future<void> _moved(MovedEvent e) async {
    final path = [e.from, ...e.path];
    if (path.length < 2) return;
    await board.run(PieceAnim([PieceTrack(e.seat, e.piece, TrackKind.hop, path)], _g(Motion.hopPerSquare) * (path.length - 1)));
    final loop = Board.loopIndexOrNone(e.seat, e.to);
    if (e.kind == MoveKind.step && loop >= 0 && isSafeLoopSquare(hooks.settled(), loop)) unawaited(_fx.play(Sfx.safe, volume: .4));
  }

  Future<void> _zip(ArrowZipEvent e) async {
    unawaited(_fx.play(Sfx.arrow));
    await board.run(PieceAnim([PieceTrack(e.seat, e.piece, TrackKind.slide, [e.via, e.to])], _g(MatchMotion.zip)));
  }

  Future<void> _swapped(PieceSwappedEvent e) async {
    unawaited(_fx.play(Sfx.shield));
    await board.run(
      PieceAnim([
        PieceTrack(e.seat, e.piece, TrackKind.slide, [e.from, e.to]),
        PieceTrack(e.targetSeat, e.targetPiece, TrackKind.slide, [e.targetFrom, e.targetTo]),
      ], _g(MatchMotion.swap)),
    );
  }

  Future<void> _captured(List<CapturedEvent> group, {required bool again}) async {
    final first = group.first;
    final victimMine = hooks.isMine(first.victim);
    unawaited(_fx.play(victimMine ? Sfx.captured : Sfx.capture));
    _fx.heavy();
    board.burst(BurstKind.star, first.victim, first.victimPiece, first.victimFrom, text: tr('POW!'), color: LmColors.tagCapture);
    if (!env.reduced()) board.nudge();
    final by = first.by;
    final victim = first.victim;
    if (_you(by)) {
      _say(again ? tr('Captured {name}! Roll again', {'name': _name(victim)}) : tr('Captured {name}!', {'name': _name(victim)}), ToastTone.green);
    } else if (_you(victim)) {
      _say(tr('{name} captured you', {'name': _name(by)}), ToastTone.red);
    } else {
      _say(tr('{name} captured {victim}', {'name': _name(by), 'victim': _name(victim)}));
    }
    await board.run(
      PieceAnim([for (final c in group) PieceTrack(c.victim, c.victimPiece, TrackKind.knock, [c.victimFrom, c.victimTo])], _g(Motion.captureReturn)),
    );
  }

  Future<void> _home(ReachedHomeEvent e, {required bool again}) async {
    unawaited(_fx.play(Sfx.home));
    unawaited(_fx.success());
    board.burst(BurstKind.star, e.seat, e.piece, Board.home, text: tr('HOME!'), color: LmColors.tagHome);
    if (_you(e.seat)) {
      _say(again ? tr('Home! Roll again') : tr('Home!'), ToastTone.green);
    } else {
      _say(tr('{name} got one home', {'name': _name(e.seat)}));
    }
    await _wait(_g(Motion.reachHome));
  }

  // ── Mela Mayhem ───────────────────────────────────────────────────────

  void _drew(Seat seat, PowerCard card) {
    unawaited(_fx.play(Sfx.card));
    _say(_you(seat) ? tr('You drew {card}!', {'card': cardName(card)}) : tr('{name} drew {card}', {'name': _name(seat), 'card': cardName(card)}), ToastTone.green);
  }

  Future<void> _cardPlayed(CardPlayedEvent e) async {
    final shielding = e.use.card == PowerCard.shield || e.use.card == PowerCard.freeze || e.use.card == PowerCard.swap;
    unawaited(_fx.play(shielding ? Sfx.shield : Sfx.card));
    _fx.medium();
    _say(_you(e.seat) ? tr('You played {card}', {'card': cardName(e.use.card)}) : tr('{name} played {card}', {'name': _name(e.seat), 'card': cardName(e.use.card)}));
    await _wait(_g(MatchMotion.cardPlayed));
  }
}
