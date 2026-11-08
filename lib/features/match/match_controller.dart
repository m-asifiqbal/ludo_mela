// MatchController: the brain of the match screen — it plays the session's updates, offers the moves, runs the UI
// state (hints, cards, stickers, toasts) and never draws anything.
//
// The session runs AHEAD of the screen. Every update with events is queued and played one after the other by the
// EventPlayer (dice toss, hops, captures …); while that goes on `session.setAnimating(true)` keeps bots and the turn
// timer waiting, and only when the queue is empty and the screen is idle does it offer the player something to do
// (`canAct`): roll, tap a piece with a ring (or a destination when one piece has several), play a card, ask for a
// hint, pass. A lone legal move plays itself after 0.4 s (Settings › auto-move). Clock updates (the pie, the Rush
// clock) and stickers are shown at once. The pause menu, "Leave this match?" and the sticker picker are `MatchPause`
// (match_pause.dart), the Mayhem hand is `MatchHand` (mayhem/match_hand.dart), the verdict at the end is `Celebration`.
//
// Widgets read the public fields and listen to this ChangeNotifier; they call the action methods and nothing else.
// The dice trays' state is [table], the speech bubbles are [bubbles]; the status line, the board's spoken label and
// the destination markers are extensions in match_texts.dart and move_marking.dart.

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show TickerProvider;
import 'package:ludo_engine/ludo_engine.dart';

import '../../core/art/dice_cube.dart' show DiceCubeController;
import '../../core/feedback/feedback.dart';
import '../../core/motion/motion.dart';
import '../../core/widgets/toast.dart' show ToastController, ToastTone;
import 'board/board_model.dart';
import 'dice_table.dart';
import 'match_models.dart';
import 'match_pause.dart';
import 'mayhem/match_hand.dart';
import 'playback/celebration.dart';
import 'playback/event_player.dart';
import 'session/match_session.dart';
import 'session/match_setup.dart';
import 'sticker_bubbles.dart';

class MatchController extends ChangeNotifier with MatchPause, MatchHand {
  MatchController({required this.session, required TickerProvider vsync, required this.env, bool cube = true})
    : board = BoardModel(vsync: vsync, initial: session.state),
      state = session.state,
      clock = session.clock,
      rush = session.rushClock {
    table = DiceTable(env: env, cube: cube, onChanged: notifyListeners);
    bubbles = StickerBubbles(env: env, onChanged: notifyListeners);
    celebration = Celebration(env: env, isMine: session.canControl, toast: _toast, onChanged: notifyListeners, cancelled: () => _disposed || leaving);
    _player = EventPlayer(
      board: board,
      env: env,
      hooks: PlaybackHooks(
        toss: table.toss,
        rolled: table.read,
        turnPassed: _turnPassed,
        celebrate: (e) => celebration.play(e, _playing?.state ?? state),
        toast: _toast,
        isMine: session.canControl,
        settled: () => state,
        cancelled: () => _disposed,
      ),
    );
    board.onHop = _hopped;
    hintBudget = session.setup.practice ? -1 : 3;
    _sub = session.updates.listen(_onUpdate);
    afterIdle();
  }

  @override
  final MatchSession session;
  final MatchEnv env;
  final BoardModel board;

  /// The dice trays: the die in the air, the little dice, the last faces.
  late final DiceTable table;

  /// Stickers shown beside avatars.
  late final StickerBubbles bubbles;

  /// The verdict on the board when the match is over.
  late final Celebration celebration;

  final ToastController toasts = ToastController();

  late final EventPlayer _player;
  StreamSubscription<MatchUpdate>? _sub;
  final Queue<MatchUpdate> _queue = Queue();
  MatchUpdate? _playing;
  bool _draining = false;
  bool _disposed = false;
  Timer? _autoTimer;

  /// Hints left (-1 = unlimited, as in practice).
  int hintBudget = 3;

  /// The position as last settled on screen (the session may be ahead).
  @override
  GameState state;

  /// The turn timer of the person who must act, and the Rush clock.
  TurnClock? clock;
  RushClock? rush;

  /// Changes whenever a different clock starts (restarts the pie).
  int clockSerial = 0;

  /// Legal moves of the person on turn (empty unless they may act).
  List<MoveOption> options = const [];

  /// A piece with several moves was tapped: choose its destination.
  (Seat, int)? picked;

  /// The piece being held (path dots and hit chance).
  (Seat, int)? held;

  /// The piece the hint suggests.
  Move? hint;

  /// The verdict is on screen (the match is over and the board holds on for a moment).
  bool get celebrating => celebration.active;

  /// The match is over and somebody on this phone won: the confetti falls.
  bool get won => celebration.won;

  @override
  MatchSetup get setup => session.setup;
  bool get idle => !_draining && _queue.isEmpty;

  /// The person on turn may do something now.
  @override
  bool get canAct => idle && !leaving && !celebrating && pause == PauseStage.none && !state.isOver && session.canControl(state.current);

  bool get _rollPhase => state.phase == Phase.awaitRoll || state.phase == Phase.rollOff;

  // ── What the screen shows ─────────────────────────────────────────────

  DiceCubeController get dice => table.dice;
  bool get tossing => table.tossing;
  Seat? get tossSeat => table.tossSeat;
  int? get tossValue => table.tossValue;
  List<int> rollsOf(Seat seat) => table.rollsOf(seat);
  int lastRoll(Seat seat) => table.lastRoll(seat);

  /// The die settled (the tray's `onLand`): the wooden click and a light tap.
  void landed(int value) => table.landed(value);

  /// [seat]'s dice tray is on screen (its turn to roll, or a die is in the air).
  bool trayShown(Seat seat) {
    if (state.isOver) return false;
    if (table.tossing && table.tossSeat == seat) return true;
    return !table.trayHidden && !leaving && state.current == seat && _rollPhase;
  }

  /// The tray of [seat] may be tapped.
  bool canRollFrom(Seat seat) => canAct && state.current == seat && _rollPhase;

  /// The pie of [seat] (only the person who must act has one).
  TurnClock? clockOf(Seat seat) => clock != null && clock!.seat == seat ? clock : null;

  /// "Thinking…" under a bot's name.
  bool thinking(Seat seat) => !state.isOver && state.current == seat && !session.canControl(seat) && state.phase == Phase.awaitMove;

  /// Moves can be tapped on this piece (a move, or a card target).
  bool isMovable(Seat seat, int piece) {
    if (!canAct) return false;
    if (cards.targeting) return cards.targets(state).contains((seat, piece));
    return options.any((o) => o.seat == seat && o.piece == piece);
  }

  // ── Hints ─────────────────────────────────────────────────────────────

  /// The Hint button exists: not on the tabletop, in the puzzle or Wi-Fi rooms, and at coin tables only when
  /// Settings › "Hints at coin tables" is on (practice always has them).
  bool get hintsAllowed => !setup.tabletop && !setup.puzzle && !setup.isWifi && (!setup.paysEntry || env.settings().tableHints);

  /// Hints left (null = unlimited, as in practice).
  int? get hintsLeft => hintBudget < 0 ? null : hintBudget;

  bool get canHint => hintsAllowed && canAct && state.phase == Phase.awaitMove && options.isNotEmpty && hint == null && !cards.targeting && hintBudget != 0;

  void useHint() {
    if (!canHint) return;
    hint = hintFor(state);
    if (hintBudget > 0) hintBudget--;
    notifyListeners();
  }

  // ── Playing ───────────────────────────────────────────────────────────

  /// The dice tray was tapped.
  void roll() {
    if (canAct && _rollPhase) unawaited(session.roll());
  }

  /// A piece was tapped.
  void tapPiece(Seat seat, int piece) {
    if (!canAct) return;
    if (cards.targeting) {
      final use = cards.tap(state, seat, piece);
      if (use != null) {
        cards.reset();
        unawaited(session.useCard(use));
      }
      notifyListeners();
      return;
    }
    final mine = [for (final o in options) if (o.seat == seat && o.piece == piece) o];
    if (mine.isEmpty) return;
    if (distinctMoves([for (final o in mine) o.move]).length == 1) {
      _play(mine.first.move);
    } else {
      picked = picked == (seat, piece) ? null : (seat, piece);
      held = null;
      notifyListeners();
    }
  }

  /// A destination ghost was tapped (a piece with several moves was picked).
  void tapMarker(MoveMarker m) {
    if (canAct && m.tappable) _play(m.option.move);
  }

  /// Holding a piece shows its path and risk; null lets go.
  void hold(Seat? seat, int? piece) {
    final next = seat == null || piece == null ? null : (seat, piece);
    if (held == next) return;
    held = next;
    notifyListeners();
  }

  /// Ends a roll that cannot be played (no legal move, Mayhem card window or Auto-pass off).
  bool get canPass => canAct && state.phase == Phase.awaitMove && options.isEmpty && !cards.targeting;

  void pass() {
    if (canPass) unawaited(session.pass());
  }

  void _play(Move m) {
    cancelAuto();
    picked = null;
    held = null;
    hint = null;
    options = const [];
    unawaited(session.move(m));
    notifyListeners();
  }

  // ── Stickers ──────────────────────────────────────────────────────────

  /// Whose avatar speaks when the person taps a sticker.
  Seat get stickerSeat => session.canControl(state.current) ? state.current : setup.mySeat;

  void sendSticker(String id) => session.sendSticker(stickerSeat, id);

  // ── Updates in ────────────────────────────────────────────────────────

  void _onUpdate(MatchUpdate u) {
    if (_disposed || leaving) return;
    final s = u.sticker;
    if (s != null) bubbles.show(s);
    if (!u.isAction) {
      if (clock != u.clock) clockSerial++;
      clock = u.clock;
      rush = u.rush ?? rush;
      notifyListeners();
      return;
    }
    // Acting hides the pie at once; the animations keep the session waiting. The Rush clock is taken NOW, in step with
    // the clock updates: once the update is played (seconds later) its snapshot would be stale and the pill would lag.
    if (clock != null) {
      clock = null;
      clockSerial++;
    }
    rush = u.rush ?? rush;
    _queue.add(u);
    session.setAnimating(true);
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    cancelAuto();
    hint = null;
    picked = null;
    held = null;
    options = const [];
    cards.reset();
    notifyListeners();
    try {
      while (_queue.isNotEmpty && !_disposed) {
        final u = _queue.removeFirst();
        _playing = u;
        try {
          await _player.play(u);
        } catch (e, st) {
          debugPrint('match playback failed: $e\n$st');
        }
        if (_disposed) return;
        _settle(u);
      }
    } finally {
      _draining = false;
      _playing = null;
    }
    if (_disposed) return;
    if (!leaving) session.setAnimating(false);
    afterIdle();
  }

  void _settle(MatchUpdate u) {
    state = u.state;
    board.syncFrom(u.state);
    if (u.state.config.mode == GameMode.mayhem) board.setStars(currentStars(u.state));
    table.settle(newTurn: u.state.phase == Phase.awaitRoll && u.state.rollsTaken == 0);
    notifyListeners();
  }

  @override
  void afterIdle() {
    _refreshOptions();
    _maybeAutoMove();
    notifyListeners();
  }

  void _refreshOptions() {
    if (!canAct || state.phase != Phase.awaitMove) {
      options = const [];
      return;
    }
    options = [for (final m in legalMovesOf(state)) MoveOption(m, analyzeMove(state, m))];
  }

  /// One legal move (or several that look alike) plays itself after a short pause (Settings › auto-move).
  void _maybeAutoMove() {
    cancelAuto();
    if (options.isEmpty || !env.settings().autoMove) return;
    if (distinctMoves([for (final o in options) o.move]).length != 1) return;
    if (isMayhem && hand.isNotEmpty && legalCardUsesOf(state).isNotEmpty) return; // a card might be better
    final at = state;
    final move = options.first.move;
    _autoTimer = Timer(env.reduced() ? Duration.zero : Motion.game(Motion.autoMove, env.speed), () {
      if (_disposed || !canAct || !identical(state, at)) return;
      _play(move);
    });
  }

  @override
  void cancelAuto() {
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  // ── Playback hooks ────────────────────────────────────────────────────

  void _hopped() {
    unawaited(env.feedback.play(Sfx.hop, volume: .5));
    env.feedback.selection();
  }

  void _turnPassed(Seat from, Seat to) {
    table.clearRolls();
    if (session.canControl(to) && from != to) unawaited(env.feedback.play(Sfx.turn, volume: .5));
  }

  void _toast(String text, ToastTone tone) => toasts.show(text, tone: tone, hold: Motion.game(Motion.toastHold, env.speed));

  @override
  void dispose() {
    _disposed = true;
    _autoTimer?.cancel();
    bubbles.dispose();
    unawaited(_sub?.cancel());
    board.dispose();
    toasts.dispose();
    super.dispose();
  }
}
