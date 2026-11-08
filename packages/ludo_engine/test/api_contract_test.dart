// The public API as docs/engine_spec.md section 5 promises it.
//
// Why a test for names: the app, the bots (wave 2), the puzzles and the Wi-Fi code
// are all written against the spec. This file touches every documented
// constructor, getter and method with the documented arguments, so renaming or
// re-typing anything in the engine fails to compile here before it breaks them.

import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

void main() {
  test('5.1 config: Rules, PlayerSpec, MatchConfig, GameMode', () {
    const rules = Rules(
      sixToEnter: true,
      bonusOnSix: true,
      bonusOnCapture: true,
      bonusOnHome: true,
      threeSixesForfeit: true,
      exactHome: true,
      blockades: false,
      gentleCaptures: false,
      helpingDice: false,
      captureBeforeLane: false,
      autoPass: true,
      startOut: false,
      quickTarget: 1,
    );
    expect(Rules.forMode(GameMode.master, house: rules).captureBeforeLane, isTrue);
    expect(rules.copyWith(blockades: true).blockades, isTrue);
    expect(Rules.fromJson(rules.toJson()), rules);
    expect(Rules.helpingDiceAfter, 5);
    expect(
      [RushScoring.perSquare, RushScoring.perCapture, RushScoring.whenCaptured, RushScoring.perPieceHome],
      [1, 20, -10, 50],
    );

    const spec = PlayerSpec(
      seat: Seat.red,
      name: 'Asha',
      kind: PlayerKind.bot,
      level: BotLevel.hard,
      personality: 'raja',
      avatar: 'fox',
      id: 'p1',
    );
    expect(spec.isBot, isTrue);
    expect(PlayerSpec.fromJson(spec.copyWith(name: 'Mitu').toJson()).name, 'Mitu');

    final config = MatchConfig(
      mode: GameMode.classic,
      rules: rules,
      players: [
        spec,
        const PlayerSpec(seat: Seat.yellow, name: 'Ravi'),
      ],
      firstSeat: Seat.yellow,
    );
    expect(config.seats, [Seat.red, Seat.yellow]);
    expect(config.hasSeat(Seat.green), isFalse);
    expect(config.playerOf(Seat.red).name, 'Asha');
    expect(config.tryPlayerOf(Seat.blue), isNull);
    expect(config.isTeams, isFalse);
    expect(config.teamOf(Seat.yellow), 0);
    expect(MatchConfig.fromJson(config.copyWith(mode: GameMode.quick).toJson()).mode, GameMode.quick);
    final generic = MatchConfig.generic(
      mode: GameMode.teams,
      count: 4,
      rules: rules,
      firstSeat: Seat.red,
      level: BotLevel.easy,
      allBots: true,
    );
    expect(generic.isTeams, isTrue);
    expect(MatchConfig.generic(seats: const [Seat.green, Seat.blue]).seats, [Seat.green, Seat.blue]);
    expect([GameMode.teams.minPlayers, GameMode.teams.maxPlayers, GameMode.teams.supportsPlayers(3)], [4, 4, false]);
    expect([Seat.red.next, Seat.red.opposite], [Seat.green, Seat.yellow]);
    expect(BotLevel.values.length, 4);
  });

  test('5.2 state: GameState, SeatStats, MayhemState, RollOffState', () {
    final config = MatchConfig.generic(mode: GameMode.mayhem, count: 3);
    final s = GameState.initial(config);
    expect(s.phase, Phase.rollOff);
    expect(s.rollOff!.contenders, config.seats);
    expect(s.rollOff!.next, Seat.red);
    expect(s.rollOff!.rolls, isEmpty);
    expect(s.rollOff!.round, 0);
    expect(s.pieces(Seat.red), [-1, -1, -1, -1]);
    expect(s.pieceAt(Seat.red, 0), -1);
    expect([s.pendingDice, s.diceUsed, s.sixesInRow, s.extraRolls, s.rollsTaken], [<int>[], 0, 0, 0, 0]);
    expect([s.placements, s.conceded, s.turnNumber, s.round], [<Seat>[], <Seat>[], 0, 0]);
    expect(
      [s.rushScore[Seat.red], s.chestCoins[Seat.red], s.dryRolls[Seat.red], s.hasCaptured[Seat.red]],
      [0, 0, 0, false],
    );
    final SeatStats st = s.stats[Seat.red]!;
    expect([st.captures, st.timesCaptured, st.rolls], [0, 0, 0]);
    final MayhemState m = s.mayhem!;
    expect([m.handOf(Seat.red), m.isShielded(Seat.red, 0), m.isFrozen(Seat.red, 0)], [<PowerCard>[], false, false]);
    expect(
      [m.luckyHour, m.monsoon, m.fog, m.festivalLights, m.starShift, m.cardPlayed, m.event],
      [false, false, false, false, 0, false, null],
    );
    expect([s.firstSeat, s.overReason, s.isOver, s.winner, s.winners], [null, null, false, null, <Seat>[]]);
    expect(s.seats, config.seats);
    expect(s.activeSeats, config.seats);
    expect(s.movingSeat, s.current);
    expect(
      [
        s.isActive(Seat.red),
        s.isFinished(Seat.red),
        s.isConceded(Seat.red),
        s.placeOf(Seat.red),
        s.piecesHome(Seat.red),
      ],
      [true, false, false, 0, 0],
    );
    expect(
      [s.totalProgress(Seat.red), s.furthestPiece(Seat.red), GameState.effectiveProgress(Board.wrap), s.isBonusRoll],
      [0, -1, -1, false],
    );
    final placed = s
        .withPieces(Seat.red, [0, 5, 56, -1])
        .copyWith(firstSeat: null, overReason: null, mayhem: null, rollOff: null);
    expect(placed.pieceAt(Seat.red, 2), Board.home);
    expect(GameState.fromJson(s.toJson()), s);
    expect(() => GameState.fromJson(const {}), throwsFormatException);
    expect(Phase.values, [Phase.rollOff, Phase.awaitRoll, Phase.awaitMove, Phase.gameOver]);
  });

  test('5.3 dice', () {
    expect(FairDice(Random(1)).roll(), inInclusiveRange(1, 6));
    expect(FairDice().roll(), inInclusiveRange(1, 6));
    expect(SeededDice(3).roll(), SeededDice(3).roll());
    final scripted = ScriptedDice([4, 2], then: SeededDice(1));
    expect(scripted.remaining, 2);
    scripted.add([5]);
    expect([scripted.roll(), scripted.roll(), scripted.roll()], [4, 2, 5]);
    final recording = RecordingDice(ScriptedDice([6]));
    recording.roll();
    expect(recording.rolls, [6]);
    expect(() => const NoDice().roll(), throwsA(anything));
    final Dice d = const NoDice();
    expect(d, isA<Dice>());
  });

  test('5.4 moves, actions, cards, events', () {
    const move = Move(seat: Seat.red, piece: 0, from: -1, to: 0, die: 6, kind: MoveKind.enter);
    expect(
      [move.isEnter, move.isHome, move.isCapture, move.isArrow, move.via, move.captures],
      [true, false, false, false, null, <CapturedPiece>[]],
    );
    expect(move.sameAs(move), isTrue);
    expect(move.looksLike(move), isTrue);
    expect(move.path, [0]);
    expect(Move.fromJson(move.toJson()).sameAs(move), isTrue);
    const captured = CapturedPiece(Seat.green, 1, 20, -1);
    expect(CapturedPiece.fromJson(captured.toJson()), captured);
    expect(const PieceRef(Seat.red, 2).piece, 2);
    expect(MoveKind.values, [MoveKind.enter, MoveKind.step, MoveKind.home, MoveKind.arrow]);

    final actions = <Action>[
      const RollOffRoll(Seat.red),
      const Roll(),
      MovePiece(move),
      const UseCard(CardUse.doubleDice()),
      const PassTurn(),
      const AutoPlay(),
      const RushTimeUp(),
      const Concede(Seat.blue),
      const FinishByProgress(),
    ];
    for (final a in actions) {
      expect(Action.fromJson(a.toJson()), a);
    }
    final GameAction alias = const Roll();
    expect(alias, isA<Action>());

    expect(PowerCard.fromRoll(4), PowerCard.swap);
    expect(MelaEventKind.values.length, 4);
    const uses = <CardUse>[
      CardUse.shield(0),
      CardUse.doubleDice(),
      CardUse.hop3(1),
      CardUse.swap(0, Seat.green, 2),
      CardUse.freeze(Seat.green, 3),
      CardUse.reroll(),
    ];
    expect([for (final u in uses) u.card], PowerCard.values);
    expect(uses[3].piece, 0);
    expect(uses[3].targetSeat, Seat.green);
    expect(uses[3].targetPiece, 2);
    expect(CardUse.fromJson(uses[4].toJson()), uses[4]);
    expect([BonusReason.values.length, ScoreReason.values.length, GameOverReason.values.length], [3, 4, 8]);

    final GameEvent e = RolledEvent(Seat.red, 6, helping: false, die: 0);
    expect(GameEvent.fromJson(e.toJson()), e);
    expect(e.toJson()['e'], isNotNull);
  });

  test('5.5 LudoGame, StepResult, IllegalActionException', () {
    final config = MatchConfig.generic(firstSeat: Seat.red);
    final game = LudoGame(config, dice: ScriptedDice([6, 3]));
    expect([game.config, game.state.phase], [config, Phase.awaitRoll]);
    expect(game.dice, isA<Dice>());
    expect(game.legalMoves(), isEmpty);
    expect(game.legalCardUses(), isEmpty);
    expect(game.canPass, isFalse);
    expect(game.autoChoice(), const Roll());
    final StepResult r = game.apply(const Roll());
    expect([r.state, r.events], [game.state, isNotEmpty]);
    final move = game.legalMoves().first;
    final MoveInsight insight = game.insight(move);
    expect(insight.has(MoveTag.enter), isTrue);
    final fork = game.fork(dice: SeededDice(1));
    expect(fork, isA<GameCore>());
    expect(
      () => game.apply(const Roll()),
      throwsA(
        isA<IllegalActionException>()
            .having((e) => e.message, 'message', isNotEmpty)
            .having((e) => e.action, 'action', const Roll()),
      ),
    );
    expect(LudoGame.fromState(game.state, dice: SeededDice(2)).state, game.state);
    expect(LudoGame(config, resumeFrom: game.state).state, game.state);
  });

  test('5.6 GameCore (simulation path)', () {
    final config = MatchConfig.generic(mode: GameMode.mayhem, count: 3, firstSeat: Seat.red);
    final core = GameCore(config, SeededDice(5));
    final copy = core.clone(dice: SeededDice(6));
    expect(GameCore.fromState(core.snapshot(), const NoDice()).snapshot(), core.snapshot());
    expect([core.phase, core.current, core.firstSeat, core.isOver], [Phase.awaitRoll, Seat.red, Seat.red, false]);
    expect(
      [core.turnNumber, core.round, core.extraRolls, core.sixesInRow, core.rollsTaken, core.diceUsed],
      [0, 0, 0, 0, 0, 0],
    );
    expect(
      [core.pendingDice, core.placements, core.conceded, core.activeSeats.length, core.movingSeat, core.overReason],
      [<int>[], <Seat>[], <Seat>[], 3, Seat.red, null],
    );
    expect(
      [
        core.progressOf(Seat.red, 0),
        core.totalProgressOf(Seat.red),
        core.piecesHomeOf(Seat.red),
        core.isFinished(Seat.red),
        core.isActive(Seat.red),
      ],
      [-1, 0, 0, false, true],
    );
    expect(
      [
        core.isSafeSquare(0),
        core.isProtected(Seat.red, 0),
        core.rushScoreOf(Seat.red),
        core.chestCoinsOf(Seat.red),
        core.dryRollsOf(Seat.red),
        core.hasCapturedBy(Seat.red),
      ],
      [true, true, 0, 0, 0, false],
    );
    expect(
      [core.starShift, core.melaEvent, core.handOf(Seat.red), core.holds(Seat.red, PowerCard.shield)],
      [0, null, <PowerCard>[], false],
    );
    expect(core.legalMoves(), isEmpty);
    expect(core.hasLegalMove(), isFalse);
    expect(core.legalCardUses(), isEmpty);
    core.rollValue(6);
    final move = core.legalMoves().first;
    expect(core.insightOf(move).has(MoveTag.enter), isTrue);
    core.play(move);
    expect(
      [
        core.threatsOnPiece(Seat.red, 0),
        core.threatsOnPiece(Seat.red, 0, maxDistance: 12),
        core.hitChanceOfPiece(Seat.red, 0),
      ],
      [0, 0, 0.0],
    );
    final events = <GameEvent>[];
    core.apply(const Roll(), events: events);
    expect(events, isNotEmpty);
    final void Function() rollFast = core.roll; // simulation fast paths exist with these shapes
    final void Function() passFast = core.pass;
    expect([rollFast, passFast], hasLength(2));
    expect(copy.snapshot().phase, Phase.awaitRoll);
  });

  test('5.7 analysis functions', () {
    final config = MatchConfig.generic(firstSeat: Seat.red);
    final s = GameState.initial(config)
        .withPieces(Seat.red, [10, -1, -1, -1])
        .withPieces(Seat.yellow, [-1, -1, -1, -1]);
    final waiting = s.copyWith(phase: Phase.awaitMove, pendingDice: const [3]);
    final moves = legalMovesOf(waiting);
    expect(moves.single.to, 13);
    final MoveInsight insight = analyzeMove(waiting, moves.single);
    expect(
      [insight.tags, insight.hitChance, insight.threatsBefore, insight.threatsAfter],
      [isA<Set<MoveTag>>(), 0.0, 0, 0],
    );
    expect(MoveTag.values.map((t) => t.name), [
      'capture',
      'home',
      'safe',
      'risky',
      'enter',
      'lane',
      'arrow',
      'chest',
      'power',
    ]);
    expect(raceProgress(s, Seat.red), closeTo(11 * 100 / 228, 1e-9));
    expect(currentStars(s), Board.stars);
    expect([isSafeLoopSquare(s, 8), isSafeLoopSquare(s, 9)], [true, false]);
    expect(legalCardUsesOf(s), isEmpty);
    expect(
      [threatsOn(s, Seat.red, 0), threatsOn(s, Seat.red, 0, maxDistance: 12), hitChanceOf(s, Seat.red, 0)],
      [0, 0, 0.0],
    );
    expect(autoChoice(s), const Roll());
  });

  test('5.5 who may send what (the Wi-Fi host check)', () {
    final s = GameState.initial(MatchConfig.generic(count: 3, firstSeat: Seat.green)).copyWith(current: Seat.green);
    const move = Move(seat: Seat.red, piece: 0, from: -1, to: 0, die: 6, kind: MoveKind.enter);
    expect(actorOf(s, const Roll()), Seat.green);
    expect(actorOf(s, const PassTurn()), Seat.green);
    expect(actorOf(s, const UseCard(CardUse.reroll())), Seat.green);
    expect(actorOf(s, const MovePiece(move)), Seat.green, reason: 'the seat on turn sends, whoever owns the piece');
    expect(actorOf(s, const RollOffRoll(Seat.blue)), Seat.blue);
    expect(actorOf(s, const Concede(Seat.red)), Seat.red);
    for (final hostOnly in const <Action>[AutoPlay(), RushTimeUp(), FinishByProgress()]) {
      expect(actorOf(s, hostOnly), isNull);
      for (final seat in Seat.values) {
        expect(mayAct(s, hostOnly, seat), isFalse);
      }
    }
    expect(mayAct(s, const Roll(), Seat.green), isTrue);
    expect(mayAct(s, const Roll(), Seat.red), isFalse);
  });

  test('5.8 bots: BotPersonality, BotLevel traits, BotBrain, scoring, hints and ratings', () {
    const BotPersonality raja = BotPersonality.raja;
    expect([raja.id, raja.run, raja.safe, raja.hunt, raja.hoard, raja.swapLove], ['raja', 1.0, 0.6, 1.8, 0.2, 0.0]);
    expect(BotPersonality.presets, [
      BotPersonality.raja,
      BotPersonality.mitu,
      BotPersonality.tara,
      BotPersonality.golu,
      BotPersonality.nani,
      BotPersonality.neutral,
    ]);
    expect(BotPersonality.byId('golu'), BotPersonality.golu);
    expect(BotPersonality.byId(null), BotPersonality.neutral);
    expect([for (final l in BotLevel.values) l.mistakeRate], [0.35, 0.15, 0.05, 0.0]);
    expect(BotLevel.expert.searches, isTrue);
    final config = MatchConfig.generic(firstSeat: Seat.red);
    expect(personalitiesOf(config), hasLength(4));

    final s = GameState.initial(config)
        .withPieces(Seat.red, [10, 20, -1, -1])
        .withPieces(Seat.yellow, [-1, -1, -1, -1])
        .copyWith(phase: Phase.awaitMove, pendingDice: const [3]);
    final legal = legalMovesOf(s);
    final brain = BotBrain(BotLevel.expert, BotPersonality.golu);
    expect([brain.level, brain.personality], [BotLevel.expert, BotPersonality.golu]);
    final Move m = brain.chooseMove(s, legal, Random(1), budget: const Duration(milliseconds: 30));
    expect(legal, contains(m));
    expect(BotBrain(BotLevel.easy).chooseMove(s, legal, Random(1)), isA<Move>(), reason: 'personality and budget are optional');
    final CardUse? card = brain.chooseCard(s, Random(1));
    expect(card, isNull, reason: 'classic has no cards');
    expect(BotBrain.defaultBudget, const Duration(milliseconds: 300));
    expect([defaultRollouts, rolloutHorizon, defaultExpertBudget], [200, 30, const Duration(milliseconds: 300)]);

    final core = GameCore.fromState(s, const NoDice());
    final double score = scoreMove(core, legal.first, BotPersonality.neutral, insight: core.insightOf(legal.first));
    expect(scoreMoves(core, legal, BotPersonality.neutral), hasLength(legal.length));
    expect(score, isA<double>());
    expect([BotScore.progress, BotScore.leaveYard, BotScore.reachHome, BotScore.enterLane], [0.5, 50, 80, 30]);
    expect([BotScore.landOnStar, BotScore.capture, BotScore.threatDelta], [18, 90, 28]);
    expect(distinctMoves(legal), isNotEmpty);
    expect(evaluatePosition(core, Seat.red), isA<double>());
    expect(winEquity(0), 0.5);
    final ExpertResult found = brain.search(s, distinctMoves(legal), 1, maxRollouts: 8);
    expect([found.values.length, found.rollouts, found.best], [2, 8, isA<int>()]);

    final Move hint = hintFor(s);
    expect(legal, contains(hint));
    final MoveRating rating = rateMove(s, m);
    expect([rating.chosen, rating.expert, rating.matchedExpert, rating.scoreGap, rating.forced, rating.smart], [m, isA<Move>(), isA<bool>(), isA<double>(), false, isA<bool>()]);
    expect(MoveRating.fromJson(rating.toJson()).scoreGap, rating.scoreGap);
  });

  test('5.8 isolate-friendly calls: JSON in, JSON out', () {
    final s = GameState.initial(MatchConfig.generic(firstSeat: Seat.red))
        .withPieces(Seat.red, [10, 20, -1, -1])
        .withPieces(Seat.yellow, [-1, -1, -1, -1])
        .copyWith(phase: Phase.awaitMove, pendingDice: const [3]);
    final legal = legalMovesOf(s);
    final Map<String, Object?> request =
        botMoveRequest(s, legal, level: BotLevel.normal, personality: 'tara', seed: 1, budget: const Duration(milliseconds: 20));
    final Map<String, Object?> response = botChooseMoveJson(request);
    expect(legal, contains(botMoveFromResponse(response, legal)));
    final Map<String, Object?> cards = botChooseCardJson(botStateRequest(s, level: BotLevel.hard, personality: 'golu', seed: 2));
    expect(botCardFromResponse(cards), isNull);
    expect(legal, contains(Move.fromJson((botHintJson(botStateRequest(s))['move'] as Map).cast<String, Object?>())));
    final rated = MoveRating.fromJson(botRateMoveJson(botRateRequest(s, legal.first, rollouts: 8)));
    expect(rated.chosen, legal.first);
  });

  test('5.8 puzzles: dailyPuzzle, Puzzle, PuzzleRun and its results', () {
    final Puzzle p = dailyPuzzle(128);
    expect([p.number, p.hero, p.rolls.length], [128, Seat.red, 3]);
    expect(p.start, isA<GameState>());
    expect(p.heroPiece, isA<int>());
    expect(p.goal, isA<PuzzleGoal>());
    expect(PuzzleGoalKind.values.map((k) => k.name), ['homeSafe', 'captureSafe', 'rescue', 'doubleCapture']);
    expect([PuzzleStatus.values.map((v) => v.name), PuzzleFailure.values.map((v) => v.name)], [
      ['playing', 'solved', 'failed'],
      ['exposed', 'missedGoal', 'stuck'],
    ]);
    final PuzzleSolution analysis = p.analysis;
    expect([analysis.solvable, analysis.wins, analysis.plays, analysis.winShare], [true, isNotEmpty, greaterThan(0), lessThan(1.0)]);
    expect(solvePuzzle(p).wins.length, analysis.wins.length);
    final List<PuzzleStep> steps = p.solution;
    final run = PuzzleRun(p);
    expect(run.movesFor(steps.first.rollIndex), isNotEmpty);
    expect(run.dangerSquares(), isA<Map<int, Seat>>());
    expect(run.hint(), steps.first);
    expect([run.canStillWin, run.status, run.failure, run.used, run.remaining, run.captures, run.steps], [true, PuzzleStatus.playing, isNull, [false, false, false], [0, 1, 2], 0, isEmpty]);
    final PuzzleStepResult r = run.apply(steps.first.rollIndex, steps.first.piece);
    expect([r.accepted, r.status, r.failure, r.move, r.insight, r.threatenedBy, r.captured, r.state, r.solved, r.failed], [true, PuzzleStatus.playing, isNull, isA<Move>(), isA<MoveInsight>(), isA<List<Seat>>(), isA<int>(), isA<GameState>(), false, false]);
    expect(run.state, r.state);
    for (final step in steps.skip(1)) {
      run.apply(step.rollIndex, step.piece);
    }
    expect([run.solved, run.failed], [true, false]);
    run.reset();
    expect([run.solved, run.steps], [false, isEmpty]);
    expect(PuzzleRun.replay(p, steps).solved, isTrue);
    expect(curatedPuzzleCount, 3);
    expect(curatedPuzzle(0, number: 7).number, 7);
    expect(const PuzzleGoal(PuzzleGoalKind.captureSafe, captures: 1).captures, 1);
  });

  test('5.8 DiceStats', () {
    final s = DiceStats.of([1, 2, 3, 4, 5, 6, 6, 9]);
    expect(s.counts, [0, 1, 1, 1, 1, 1, 2]);
    expect([s.total, s.ignored, s.expectedPerFace, s.share(6)], [7, 1, 7 / 6, 2 / 7]);
    expect([s.chiSquare, s.pValue, s.enoughData, s.looksFair], [isA<double>(), isA<double>(), false, true]);
    expect(DiceStats.of(List.filled(60, 6)).looksFair, isFalse);
  });

  test('5.8 pacing, sticker reactions and the smart-move tally', () {
    final Duration lo = BotLevel.easy.minThink;
    final Duration hi = BotLevel.easy.maxThink;
    expect([lo, hi], [const Duration(milliseconds: 900), const Duration(milliseconds: 1200)]);
    final Duration think = BotLevel.hard.thinkTime(Random(1));
    expect(think >= BotLevel.hard.minThink && think <= BotLevel.hard.maxThink, isTrue);

    final config = MatchConfig.generic(allBots: true, firstSeat: Seat.red);
    final state = GameState.initial(config);
    final reactions = BotReactions(cooldownTurns: BotReactions.defaultCooldownTurns, muted: false);
    final List<BotSticker> stickers = reactions.react(state, const [
      CapturedEvent(by: Seat.red, byPiece: 0, victim: Seat.yellow, victimPiece: 1, atLoop: 12, victimFrom: 38, victimTo: -1),
    ]);
    expect([for (final s in stickers) (s.seat, s.sticker)], [(Seat.red, StickerIds.cool), (Seat.yellow, StickerIds.angry)]);
    expect(StickerIds.all, hasLength(6));
    reactions
      ..muted = true
      ..reset();

    final s = GameState.initial(MatchConfig.generic(firstSeat: Seat.red))
        .withPieces(Seat.red, [10, 20, -1, -1])
        .withPieces(Seat.yellow, [-1, -1, -1, -1])
        .copyWith(phase: Phase.awaitMove, pendingDice: const [3]);
    final tally = SmartMoveTally()..add(rateMove(s, legalMovesOf(s).first, rollouts: 8), turn: 4);
    final RatedMove? worst = tally.costliest;
    expect([tally.moves.length, tally.decisions, tally.matched <= tally.smart, tally.smartShare, worst == null || worst.turn == 4], [1, 1, true, isA<double>(), true]);
    expect(SmartMoveTally.fromJson(tally.toJson()).decisions, 1);
  });
}
