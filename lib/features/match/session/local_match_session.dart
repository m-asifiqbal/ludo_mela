// LocalMatchSession: a match on this phone: people, bots, timers, autosave, and the record at the end.
//
// It owns one LudoGame and turns "the screen is ready" into "what happens next":
//  * a person acts through roll / move / useCard / pass; every call that does not fit the position (not
//    your seat, paused, finished, an illegal move) is ignored, so a double tap is harmless;
//  * a bot acts after its think time (bot_pacing.dart, scaled by game speed); Hard / Expert think in an
//    isolate (bot_driver.dart); a refused or failing bot move falls back to AutoPlay, never a stall;
//  * the turn timer of a person (session_clocks.dart) runs only while the screen is idle and the match is
//    not paused, restarts at every decision and plays AutoPlay at zero; Rush has a 5 minute clock that keeps
//    running through animations and stops for pause (`RushTimeUp` waits for an idle screen);
//  * `setAnimating` / `setPaused` gate bots and timeouts (a closing gate cancels the bot's wait);
//  * when nobody of this phone is still in play the match ends at once by progress (`FinishByProgress`);
//  * every action is autosaved (match_autosave.dart), deleted at the end; a resumed session continues the
//    same game, tally, play time and Rush clock;
//  * at the end it builds ONE MatchRecord (match_tally.dart) for `onFinished` (the recorder pays it and
//    opens /result) once the screen is idle; `concede()` does the same for a loss.
// Pending work is keyed to the number of actions applied (stale answers are dropped); all waiting goes
// through SessionTimers, so tests use a hand-turned clock.

import 'dart:async';
import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';

import '../../../domain/match_record.dart';
import 'bot_driver.dart';
import 'bot_pacing.dart';
import 'match_autosave.dart';
import 'match_session.dart';
import 'match_setup.dart';
import 'match_tally.dart';
import 'session_clocks.dart';
import 'session_timers.dart';

class LocalMatchSession implements MatchSession {
  LocalMatchSession({
    required this.setup,
    SavedMatch? resume,
    Dice? dice,
    Random? random,
    SessionTimers? timers,
    OffThread? offThread,
    this.autosave,
    this.onFinished,
    double Function()? speed,
    bool Function()? stickersOn,
    bool Function()? botStickersOn,
  }) : _timers = timers ?? RealTimers(),
       _off = offThread ?? isolateRun,
       _speed = speed ?? (() => 1.0),
       _stickersOn = stickersOn ?? (() => true),
       _botStickersOn = botStickersOn ?? (() => true),
       _rng = random ?? Random(),
       _game = resume == null
           ? LudoGame(setup.config, dice: dice)
           : LudoGame.fromState(resume.state, dice: dice) {
    _driver = BotDriver(rng: _rng, offThread: _off);
    _clocks = SessionClocks(
      _timers,
      onTurnZero: _onTurnTimeout,
      onRushZero: _onRushZero,
      rushTotal: setup.config.mode == GameMode.rush ? setup.rushTime : null,
      rushLeft: resume?.rushLeft,
      played: resume?.played ?? Duration.zero,
    );
    final rated = setup.recordsResult && setup.config.mode != GameMode.rush;
    final saved = resume?.tally;
    _tally = saved == null
        ? MatchTally(setup.mySeat, rater: rated ? _rate : null)
        : MatchTally.fromJson(saved, rater: rated ? _rate : null);
    _tally.start(_game.state);
    _queuePump();
  }

  @override
  final MatchSetup setup;

  /// Where the running match is saved (null: nowhere).
  final MatchAutosave? autosave;

  /// Called once with the record when the match ends (and the screen is idle) or is left.
  final FutureOr<void> Function(MatchRecord record)? onFinished;

  final SessionTimers _timers;
  final OffThread _off;
  final double Function() _speed;
  final bool Function() _stickersOn;
  final bool Function() _botStickersOn;
  final Random _rng;
  final LudoGame _game;
  late final BotDriver _driver;
  final BotReactions _reactions = BotReactions();
  late final MatchTally _tally;
  late final SessionClocks _clocks;

  final StreamController<MatchUpdate> _controller = StreamController<MatchUpdate>.broadcast();
  final List<StickerMessage> _chat = [];

  bool _paused = false;
  bool _animating = false;
  bool _disposed = false;
  bool _ended = false;
  bool _pumpQueued = false;
  int _seq = 0;
  int _botToken = 0;
  bool _botActive = false;
  SessionTimer? _botTimer;
  Future<void>? _finishing;

  Future<MoveRating> _rate(GameState before, Move chosen) => rateInOther(_off, before, chosen);

  // ── MatchSession: read ─────────────────────────────────────────────────

  @override
  MatchConfig get config => _game.state.config;

  @override
  GameState get state => _game.state;

  @override
  Stream<MatchUpdate> get updates => _controller.stream;

  @override
  bool get paused => _paused;

  @override
  TurnClock? get clock => _clocks.turn;

  @override
  RushClock? get rushClock => _clocks.rushClock;

  @override
  bool canControl(Seat seat) => setup.config.tryPlayerOf(seat)?.kind == PlayerKind.human;

  // ── MatchSession: play ─────────────────────────────────────────────────

  bool get _mayAct => !_disposed && !_ended && !_paused && !_game.state.isOver && canControl(_game.state.current);

  @override
  Future<void> roll() async {
    if (!_mayAct) return;
    final s = _game.state;
    if (s.phase == Phase.rollOff) {
      _apply(RollOffRoll(s.current));
    } else if (s.phase == Phase.awaitRoll) {
      _apply(const Roll());
    }
  }

  @override
  Future<void> move(Move m) async {
    if (_mayAct && _game.state.phase == Phase.awaitMove) _apply(MovePiece(m));
  }

  @override
  Future<void> useCard(CardUse c) async {
    if (_mayAct) _apply(UseCard(c));
  }

  @override
  Future<void> pass() async {
    if (_mayAct && _game.canPass) _apply(const PassTurn());
  }

  @override
  void sendSticker(Seat from, String sticker) {
    if (_disposed || _ended || !_stickersOn() || !setup.config.hasSeat(from)) return;
    _publishSticker(StickerMessage(from, sticker));
  }

  // ── MatchSession: gates and leaving ────────────────────────────────────

  @override
  void setAnimating(bool busy) {
    if (_animating == busy || _disposed) return;
    _animating = busy;
    if (busy) {
      _cancelBot();
      _freezeTurn();
    } else {
      _queuePump();
    }
  }

  @override
  void setPaused(bool value) {
    if (_paused == value || _disposed || _ended) return;
    _paused = value;
    if (value) {
      _cancelBot();
      _clocks.freezeTurn();
      _clocks.syncRush(running: false);
      _clocks.stopPlayTime();
      _publishClocks();
    } else {
      _clocks.resumePlayTime();
      _queuePump();
    }
  }

  @override
  Future<void> concede() {
    if (_finishing != null || _disposed) return _finishing ?? Future<void>.value();
    _cancelBot();
    _clocks.cancelTurn();
    var abandoned = false;
    if (!_game.state.isOver) {
      abandoned = true;
      for (final seat in setup.humanSeats) {
        if (!_game.state.isOver && _game.state.isActive(seat)) _apply(Concede(seat));
      }
      if (!_game.state.isOver) _apply(const FinishByProgress());
    }
    return _finish(abandoned: abandoned);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelBot();
    _clocks.cancelAll();
    if (!_ended) _save();
    unawaited(_controller.close());
  }

  // ── The scheduler ──────────────────────────────────────────────────────

  void _queuePump() {
    if (_pumpQueued) return;
    _pumpQueued = true;
    scheduleMicrotask(_pump);
  }

  /// Looks at the position and (re)arms exactly what is due: Rush clock, stickers, the end, a Rush
  /// time-up, the turn timer of a person, or one bot step. Safe to call at any time.
  void _pump() {
    _pumpQueued = false;
    if (_disposed || _ended) return;
    final s = _game.state;
    _clocks.syncRush(running: !_paused && !s.isOver && s.phase != Phase.rollOff);
    _publishClocks();
    if (_paused || _animating) {
      _freezeTurn();
      return;
    }
    _flushChat();
    if (s.isOver) {
      unawaited(_finish(abandoned: false));
    } else if (_clocks.rushOut) {
      _apply(const RushTimeUp());
    } else if (setup.humanSeats.isNotEmpty && setup.humanSeats.every((h) => !s.isActive(h))) {
      _apply(const FinishByProgress());
    } else if (canControl(s.current)) {
      _armTurn(s.current);
    } else {
      _startBot(s.current);
    }
  }

  /// Applies [a]; false when the engine refuses it (nothing changed).
  bool _apply(Action a) {
    if (_ended || _disposed) return false;
    final StepResult r;
    try {
      r = _game.apply(a);
    } on IllegalActionException {
      return false;
    }
    _seq++;
    _clocks.cancelTurn();
    _cancelBot();
    final update = MatchUpdate(state: r.state, events: r.events, action: a, rush: _clocks.rushClock);
    _clocks.sentWithAction(update.rush);
    _tally.observe(update);
    _reactions.muted = !(_stickersOn() && _botStickersOn());
    for (final b in _reactions.react(r.state, r.events)) {
      _chat.add(StickerMessage(b.seat, b.sticker));
    }
    _save();
    _publish(update);
    _queuePump();
    return true;
  }

  void _publish(MatchUpdate u) {
    if (!_controller.isClosed) _controller.add(u);
  }

  void _publishClocks() {
    final u = _clocks.changed(_game.state);
    if (u != null) _publish(u);
  }

  void _publishSticker(StickerMessage m) =>
      _publish(MatchUpdate(state: _game.state, sticker: m, clock: _clocks.turn, rush: _clocks.rushClock));

  void _flushChat() {
    final out = List<StickerMessage>.of(_chat);
    _chat.clear();
    out.forEach(_publishSticker);
  }

  // ── People: the turn timer; Rush ───────────────────────────────────────

  void _armTurn(Seat seat) {
    final limit = setup.turnTime;
    if (limit == null) return;
    _clocks.armTurn(seat, limit, _seq);
    _publishClocks();
  }

  void _freezeTurn() {
    if (_clocks.freezeTurn()) _publishClocks();
  }

  void _onTurnTimeout() {
    if (!_clocks.turnIsFor(_seq) || _paused || _animating || _ended || _disposed) return;
    final s = _game.state;
    _apply(s.phase == Phase.rollOff ? RollOffRoll(s.current) : const AutoPlay());
  }

  void _onRushZero() {
    _publishClocks();
    _queuePump();
  }

  // ── Bots ───────────────────────────────────────────────────────────────

  void _cancelBot() {
    _botActive = false;
    _botToken++;
    _botTimer?.cancel();
    _botTimer = null;
  }

  void _startBot(Seat seat) {
    if (_botActive) return;
    _botActive = true;
    unawaited(_botStep(seat, ++_botToken, _seq));
  }

  Future<void> _sleep(Duration d) {
    if (d <= Duration.zero) return Future<void>.value();
    final done = Completer<void>();
    _botTimer = _timers.after(d, done.complete);
    return done.future;
  }

  Future<void> _botStep(Seat seat, int token, int seq) async {
    bool live() => !_disposed && !_ended && !_paused && !_animating && token == _botToken && seq == _seq;
    final s = _game.state;
    final spec = setup.config.playerOf(seat);
    final level = spec.level ?? BotLevel.normal;
    // A failed decision (isolate error, bad answer) becomes null: the bot then plays AutoPlay.
    final deciding = _driver.decide(s, spec).then<Action?>((a) => a, onError: (Object _) => null);
    await _sleep(BotPacing.pause(s.phase, level, _rng, _speed()));
    if (!live()) return;
    final action = await deciding;
    if (!live()) return;
    if (action != null) {
      await _sleep(BotPacing.show(level, action, _rng, _speed()));
      if (!live()) return;
    }
    _botActive = false;
    if (action == null || !_apply(action)) _apply(const AutoPlay());
  }

  // ── Ending, autosave ───────────────────────────────────────────────────

  Future<void> _finish({required bool abandoned}) => _finishing ??= _doFinish(abandoned);

  Future<void> _doFinish(bool abandoned) async {
    _ended = true;
    _cancelBot();
    _clocks.cancelAll();
    final records = setup.recordsResult;
    if (records) await _tally.settle();
    final record = records
        ? _tally.build(setup: setup, state: _game.state, abandoned: abandoned, duration: _clocks.played)
        : null;
    await autosave?.clear();
    if (record != null) await onFinished?.call(record);
  }

  void _save() {
    final store = autosave;
    if (store == null || !setup.recordsResult || _ended) return;
    store.save(
      SavedMatch(
        setup: setup,
        state: _game.state,
        tally: _tally.toJson(),
        played: _clocks.played,
        rushLeft: _clocks.rush?.remaining,
      ),
    );
  }
}
