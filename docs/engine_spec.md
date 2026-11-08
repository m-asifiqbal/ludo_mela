# Ludo Mela engine — rules and API contract

`packages/ludo_engine` is pure Dart (no Flutter). Everything the app needs to *decide* lives here:
rules for every mode, the turn state machine, events for animation, serialization, move analysis, and —
in wave 2 — bots, hints, daily puzzles and dice-fairness stats (§5.8). The app only animates and stores.

Source of truth for rules: design board **B · Rules, modes & the Mela engine** (`design/artboards/project/GameRules.dc.html`),
plus the decisions below. Geometry is fixed in `lib/src/geometry.dart` (do not change coordinates).
Import everything from `package:ludo_engine/ludo_engine.dart`.

## 1. Board, positions, turn

* 15×15 grid, 52-square loop, 5-square home lane, home. A piece's **progress**: `-1` yard, `0…50` loop
  (0 = own start square), `51…55` lane, `56` home, and `Board.wrap` (`57`, Master only — see §2).
  `Board.cellOf(seat, progress, piece)` maps to grid cells, `Board.path(...)` to a hop path.
* Loop index of a piece: `Board.loopIndexOrNone(seat, progress)` (−1 off the loop). Red progress *p* is loop square *p*;
  green is offset 13, yellow 26, blue 39.
* Starts (loop 0/13/26/39) and stars (8/21/34/47) are **safe**: no captures there; any number of pieces of
  any colour may share them. Start squares of empty seats are safe too. Mayhem's Monsoon moves the stars
  (`currentStars(state)`); the starts never move.
* Seats in clockwise order red → green → yellow → blue. 2 players sit **opposite** (red + yellow by default,
  any opposite pair allowed); 3 players red, green, yellow (configurable seats); Teams needs all four.
* **Roll-off** decides who starts (unless `MatchConfig.firstSeat` is set): every active seat rolls once (clockwise,
  `RollOffRoll(seat)`); highest wins; ties re-roll among the tied seats only. Turn order then runs clockwise from
  the winner, skipping empty seats, finished players and conceded players.
* A **turn** is one seat's rolls: the first roll plus every bonus roll. A **round** completes each time the turn
  returns to the first seat still playing, counted clockwise from the roll-off winner (`GameState.round` = rounds
  completed; `turnNumber` = turns completed).

## 2. Classic rules (defaults) and house rules

| Rule (`Rules` field) | Default | Behaviour |
|---|---|---|
| `sixToEnter` | true | Only a 6 brings a piece out (to progress 0). Off: a 1 or a 6. |
| `bonusOnSix` | true | A 6 gives one more roll. |
| `bonusOnCapture` | true | A capture gives one more roll (Lucky hour in Mayhem: two). |
| `bonusOnHome` | true | A piece reaching home gives one more roll. |
| `threeSixesForfeit` | true | Third 6 in a row: the turn ends at once; that third 6 is not played. |
| `exactHome` | true | Needs the exact roll to land on 56. Off: overshoot still finishes. |
| `blockades` | false | Two or more pieces of one side on one non-safe loop square form a block that no piece may pass or land on — the owner's other pieces included. It breaks when one of them leaves. (Side = the seat; in Teams the team.) |
| `gentleCaptures` | false | A captured piece steps back 6 squares instead of to the yard (to the yard if that would go below 0, or if the square 6 back is a non-safe square holding another side's pieces). |
| `helpingDice` | false | A seat with no piece on the board (and one in the yard) that has rolled 5 times in a row without a way out gets a 6 next — announced (`HelpingSixEvent`, then `RolledEvent(helping: true)`). The forced 6 does **not** consume a die. Never in coin venues or Wi-Fi rooms unless the host enables it (app decides). |
| `captureBeforeLane` | false | (Master) a seat that has never captured can't enter its lane: a move that would pass progress 50 keeps going around the loop (`progress = p + roll − 52`). |
| `autoPass` | true | No legal move → the turn passes (app shows a 1 s toast). Off: the seat must send `PassTurn`. |
| `startOut` | false | Every piece starts on its start square (set by `Rules.forMode` for Quick and Rush). |
| `quickTarget` | 1 | Quick: pieces a seat must bring home to win (1–4). |

`MatchConfig` always lays the mode's requirements over the rules it is given (`Rules.forMode(mode, house: rules)`),
so Master always has blockades + capture-before-lane and Quick/Rush always start with pieces out.

**Captures.** Landing on a non-safe loop square holding rival pieces sends *all* of them back to the yard (or 6
squares back with `gentleCaptures`); a stack of 2+ pieces of one seat is captured together unless `blockades`
makes it a block (then it cannot be landed on at all). Pieces of one seat (or, in Teams, one team) never capture
each other. Lane squares, the yard and home can never be captured. Captures happen only where a piece *lands*
(never on the squares it passes). In Teams, a square holding pieces of **both partners** is a *safe block*: rivals
may land there but cannot capture them (and, if `blockades` is on, nobody may pass it).

**Master wrap.** The loop square just before a seat's own start (loop index start + 51) has no progress code of its
own; a Master piece that circles onto it is `Board.wrap` (57). From it a roll of *r* lands on progress *r − 1*.
Once the seat has captured (`hasCaptured`), every piece may turn into the lane normally.

**No legal move** for the rolled value (all pieces in the yard without an entering roll, every move overshoots
home, or blocked) → `NoMoveEvent`, then the turn passes — except that a 6 still grants its bonus roll (unless
it was the third six in a row). With `autoPass` off, or in Mayhem while a Reroll / Hop +3 card could still rescue
the roll, the state stays in `awaitMove` with no legal moves and the seat must play a card or `PassTurn`
(`LudoGame.canPass`).

**Bonus rolls** queue in `extraRolls` and are taken after the roll in progress is resolved. They stack (a 6 that
captures queues two). A six's bonus is booked when its die is resolved (the move is played, or the roll turns out
to be unplayable); capture and home bonuses the moment they happen. A seat that finishes loses its unused bonus, and a bonus it would never take (the move that finished the seat, ended a
Quick match or completed a Teams side) is neither booked nor announced; the unplayed second die of a Double goes with it.

**Teams: partner rolls.** In Teams a seat whose pieces are all home keeps its turns: it rolls (stats and bonus
rolls are the roller's) and moves its **partner's** pieces (`Move.seat` is then the partner, `GameState.movingSeat`).

## 3. Modes (`GameMode`)

| Mode | Setup / goal | Notes |
|---|---|---|
| `classic` | Pieces start in the yard; first seat with all 4 home is 1st. | Play continues for places until one seat is left (`GameOverReason.lastStanding`); the app may end early when no human is still playing: `FinishByProgress`. |
| `quick` | All pieces start on their start square (progress 0); **first piece home wins** (`Rules.quickTarget` = 1, configurable 1–4). | ~5–8 min. Places: winner, then by pieces home, then total progress. |
| `master` | Classic + `captureBeforeLane` + `blockades`. | 25 min. |
| `rush` | Pieces start out; a 5-minute clock (app-driven: `RushTimeUp` action); points decide. | +1 per square moved (leaving the yard = 1), +20 per captured piece, −10 per piece lost, +50 per piece home (`RushScoring`). Ranking: points, then most pieces home, then furthest piece. All four home also ends it (`allHome`). |
| `mayhem` | Classic + arrows, power cards, chests, Mela events, underdog draw (§4). | ~12 min. |
| `teams` | 4 players; red+yellow vs green+blue. Partners share squares, never capture each other; a player whose pieces are all home rolls for (and moves) the partner's pieces. The team wins when all 8 are home. | Places: both winners first (by finishing order), then the losing team by progress. |

**Placements.** `GameState.placements` lists seats that have finished (all four pieces home) in order while the
match runs; once `isOver` it is the complete final standing (every seated seat exactly once, first place first,
conceded seats last — a later leaver ranks above an earlier one). `winner` = first place; `winners` = both seats of
the winning team in Teams. `overReason` (`GameOverReason`): `allHome`, `lastStanding`, `quickTarget`, `teamWon`,
`timeUp`, `byProgress`, `conceded`, `stalemate` (a defensive safety net for blockade deadlocks; not reachable
in normal play).

**Concede(seat)**: the seat's pieces leave the board (yard), its cards/shields vanish, and it finishes last. The match
ends when one seat is left (`conceded`). In Teams a conceding seat loses the match for its team. A seat that has already finished (all four home, not Teams) keeps its place: `Concede` for it is refused
(`IllegalActionException`) — leaving after finishing needs no action; only `state.activeSeats` can concede.

Turn timer and timeouts are app-driven; the engine offers `autoChoice(state)` / `AutoPlay` (roll, or the safest
legal move: fewest threats after the move, then a safe landing, then furthest progress; `PassTurn` when nothing can
be played; never plays cards).

## 4. Mela Mayhem

* **Arrow tiles** (loop 3/16/29/42): land exactly → zip 4 squares ahead along your route (`MoveKind.arrow`,
  `Move.via` = the tile, `ArrowZipEvent`); captures happen at the zip's end only (a rival standing on the arrow
  itself is left alone). Never applies inside lanes; passing over an arrow does nothing.
* **Power tiles** (loop 6/11/19/24/32/37/45/50): land → draw a random power card (hold at most 2; a full hand
  draws nothing and costs no die: `HandFullEvent`).
* **Chest tiles** (loop 30/4): land → 50–300 coins (one die × 50, ×2 under Festival lights) credited to the seat's
  `chestCoins`; the app pays them only if the human finishes the match.
* Tile effects fire for the final landing square of a move, a zip, or a Hop +3 — not for Swap.
* **Power cards** — at most one card per turn (bonus rolls included), before the roll (`awaitRoll`) or after it
  (`awaitMove`):
  * `shield` (one of your pieces on the loop can't be captured or swapped until `turnNumber + 2 × seats still
    playing` — two full rotations of the table; `ShieldBlockedEvent` when a landing is refused, `ShieldExpiredEvent`
    when it ends). It does not stop Freeze.
  * `double` (before the roll only): rolls two dice immediately (`RolledEvent` die 0 and 1); you may use either die
    first, each on any piece, the same piece twice included. A die with no legal move is forfeited. Each six books a
    bonus roll when its die is resolved; the dice count one by one toward three sixes in a row (a third six ends the
    turn at once, the other die included).
  * `hop3` (move one of your pieces on the loop/lane 3 squares; exact-home rule applies; blockades apply; an ordinary
    landing: may capture, zip, draw, open a chest, reach home — `MovedEvent(byCard: true, die: 0)`). Before the roll
    the roll is still to be made; after it the pending die stays and is re-checked.
  * `swap` (trade places with a rival piece 1–6 loop squares **ahead** of yours; both on the loop, neither in a lane,
    the target not shielded and not on its start; both must stay on their own route afterwards — your progress +k must
    be ≤ 50 and the target's progress −k ≥ 0; both pieces must be alone on non-safe squares). A trade, not a landing:
    no captures, no tile effects. `PieceSwappedEvent`.
  * `freeze` (one rival piece on the loop or lane can't move until its owner's next turn is over: the engine
    removes the freeze when that seat's turn ends, `FreezeEndedEvent`; a frozen piece that is captured thaws).
  * `reroll` (after the roll only): the roll in hand is discarded (a discarded 6 never happened: no bonus, the
    sixes counter steps back) and the die is rolled again at once.
* **Mela events**: every 5 rounds (when `round % 5 == 0`) an event starts for 2 rounds (`MelaEventStarted.endsRound
  = round + 2`): `luckyHour` (captures give 2 extra rolls), `monsoon` (the stars drift one square forward when it
  starts and once more each round — `starShift` 1, then 2 — and return when it ends; `currentStars(state)` is the
  source of truth for safety; `StarsDriftedEvent`), `fog` (flag only: the app hides threat marks and RISKY tags),
  `festivalLights` (double chest coins; flag for the app's glow). The kind is one die 1–4 (5 and 6 are rolled
  again), so it is deterministic from the dice.
* **Underdog draw**: whenever the seat in last place (least total progress; ties → the later seat in turn order)
  rolls a 6 (and the turn survives the three-sixes rule) it draws a card, visible to all (`UnderdogDrawEvent`;
  `HandFullEvent(underdog: true)` with a full hand).

## 5. API (names are the contract the app is written against)

Everything below is exported by `package:ludo_engine/ludo_engine.dart`.

### 5.1 Config

```dart
enum Seat { red, green, yellow, blue }          // .next, .opposite   (geometry.dart)
enum GameMode { classic, quick, master, rush, mayhem, teams }   // minPlayers, maxPlayers, isTeams, supportsPlayers(n)
enum PlayerKind { human, bot, remote }
enum BotLevel { easy, normal, hard, expert }
class Rules {                                     // const; every switch in §2
  const Rules({sixToEnter, bonusOnSix, bonusOnCapture, bonusOnHome, threeSixesForfeit, exactHome, blockades,
               gentleCaptures, helpingDice, captureBeforeLane, autoPass, startOut, quickTarget});
  factory Rules.forMode(GameMode m, {Rules? house});   // mode presets merged over house rules
  Rules copyWith({...}); Map<String,Object?> toJson(); factory Rules.fromJson(Map<String,Object?>);
  static const helpingDiceAfter = 5;
}
abstract final class RushScoring { perSquare = 1; perCapture = 20; whenCaptured = -10; perPieceHome = 50; }
class PlayerSpec { Seat seat; String name; PlayerKind kind; BotLevel? level; String? personality; String? avatar;
                   String? id; bool get isBot; copyWith; toJson/fromJson }
class MatchConfig {
  MatchConfig({required GameMode mode, Rules? rules, required List<PlayerSpec> players, Seat? firstSeat});
  factory MatchConfig.generic({mode, count = 2, rules, firstSeat, seats, level, allBots});   // tests / tools
  GameMode mode; Rules rules; List<PlayerSpec> players /* clockwise */; Seat? firstSeat;
  List<Seat> get seats; bool hasSeat(Seat); PlayerSpec playerOf(Seat); PlayerSpec? tryPlayerOf(Seat);
  bool get isTeams; int teamOf(Seat);   // 0 = red + yellow, 1 = green + blue
  MatchConfig copyWith({...}); toJson/fromJson;     // throws ArgumentError for impossible seatings
}
```

### 5.2 State (immutable)

```dart
enum Phase { rollOff, awaitRoll, awaitMove, gameOver }
class GameState {
  factory GameState.initial(MatchConfig c);  factory GameState.fromJson(Map<String,Object?>);  // FormatException
  MatchConfig config; Phase phase;
  Seat current;                      // seat on turn (roll-off: next to roll)
  Seat? firstSeat;                   // roll-off winner / configured first seat
  List<int> pieces(Seat s);  int pieceAt(Seat s, int piece);      // 4 progress values per seat
  List<int> pendingDice;             // dice rolled and not used yet (1, or 2 with Double)
  int diceUsed;                      // dice of the current roll already played (Double)
  int sixesInRow; int extraRolls;    // bonus rolls queued for the current seat
  int rollsTaken;                    // rolls this turn; > 0 while awaiting a roll = it is a bonus roll (isBonusRoll)
  List<Seat> placements; List<Seat> conceded;
  int turnNumber; int round;
  Map<Seat,int> rushScore, chestCoins, dryRolls;  Map<Seat,bool> hasCaptured;  Map<Seat,SeatStats> stats;
  MayhemState? mayhem;               // hands, shields, frozen, event, starShift, cardPlayed (+ handOf, isShielded,
                                     //   isFrozen, luckyHour/monsoon/fog/festivalLights)
  RollOffState? rollOff;             // contenders, rolls, round, next
  GameOverReason? overReason;
  bool get isOver; Seat? get winner; List<Seat> get winners; List<Seat> get seats; List<Seat> get activeSeats;
  Seat get movingSeat;               // whose pieces the current roll moves (Teams: partner of a finished seat)
  bool isActive(Seat); bool isFinished(Seat); bool isConceded(Seat); int placeOf(Seat); int piecesHome(Seat);
  int totalProgress(Seat); int furthestPiece(Seat); static int effectiveProgress(int progress);
  GameState copyWith({...});  GameState withPieces(Seat, List<int>);   // hand-built positions (puzzles, tests)
  Map<String,Object?> toJson();
}
class SeatStats { int captures, timesCaptured, rolls; }
```
`copyWith`'s per-seat maps (`rushScore`, `chestCoins`, `hasCaptured`, `dryRolls`, `stats`, `pieces`) replace only
the seats they name; pass `null` explicitly to clear `firstSeat`, `mayhem`, `rollOff`, `overReason`.

### 5.3 Dice

```dart
abstract class Dice { int roll(); }                        // 1..6
class FairDice implements Dice { FairDice([Random? r]); }   // Random.secure() by default
class SeededDice implements Dice { SeededDice(int seed); }  // SplitMix64: identical rolls on every device / Dart version
                                                          // (daily puzzles, replays); pinned by a test vector
class ScriptedDice implements Dice { ScriptedDice(Iterable<int> rolls, {Dice? then}); int get remaining; void add(..); }
class RecordingDice implements Dice { RecordingDice(Dice inner); List<int> rolls; }
class NoDice implements Dice { const NoDice(); }           // throws if rolled (read-only analysis)
```
**Dice consumption order** (what a `ScriptedDice` script has to list): roll-off roll = 1 die · normal roll = 1 die
(none for a Helping-dice six) · Double = 2 dice (die 0, die 1) · Reroll = 1 die · power-tile draw / underdog draw =
1 die (1 shield, 2 double, 3 hop3, 4 swap, 5 freeze, 6 reroll; none when the hand is full) · chest = 1 die (×50) ·
Mela event = 1 die 1–4, re-rolled while it shows 5 or 6 (1 luckyHour, 2 monsoon, 3 fog, 4 festivalLights).

### 5.4 Moves, actions, events

```dart
class PieceRef { Seat seat; int piece; }
enum MoveKind { enter, step, home, arrow }
class CapturedPiece { Seat seat; int piece; int from; int to; }       // to = -1 (yard) or 6 back (gentle)
class Move { Seat seat; int piece; int from; int to; int die; MoveKind kind; int? via;     // via = arrow tile
             List<CapturedPiece> captures; bool get isEnter/isHome/isCapture/isArrow;
             List<int> get path;       // progress values hopped through (== MovedEvent.path), for path dots before the move
             bool sameAs(Move);        // seat, piece, die, from, to — how MovePiece is matched (extras are ignored)
             bool looksLike(Move);     // identical on the board (two yard pieces): the UI may auto-play it
             toJson/fromJson }

sealed class Action { toJson(); factory Action.fromJson(...) }     // alias: typedef GameAction = Action;
  RollOffRoll(Seat seat) · Roll() · MovePiece(Move move) · UseCard(CardUse use) · PassTurn() · AutoPlay()
  · RushTimeUp() · Concede(Seat seat) · FinishByProgress()
enum PowerCard { shield, double, hop3, swap, freeze, reroll }       // PowerCard.fromRoll(1..6)
enum MelaEventKind { luckyHour, monsoon, fog, festivalLights }
class CardUse { CardUse.shield(piece) · .doubleDice() · .hop3(piece) · .swap(piece, targetSeat, targetPiece)
                · .freeze(targetSeat, targetPiece) · .reroll(); PowerCard card; int? piece; Seat? targetSeat; int? targetPiece; }
enum BonusReason { six, capture, home }  enum ScoreReason { steps, capture, captured, home }
enum GameOverReason { allHome, lastStanding, quickTarget, teamWon, timeUp, byProgress, conceded, stalemate }

sealed class GameEvent { Map<String,Object?> toJson() /* tag under "e" */; factory GameEvent.fromJson(...); ==/hashCode by content }
  RollOffEvent(seat, value, round) · RollOffResultEvent({winner, tied, round}) · RolledEvent(seat, value, {helping, die})
  · HelpingSixEvent(seat) · ThreeSixesEvent(seat) · NoMoveEvent(seat, dice) · EnteredEvent(seat, piece, die)
  · MovedEvent(seat, piece, from, to, path, die, kind, byCard) · CapturedEvent(by, byPiece, victim, victimPiece, atLoop,
    victimFrom, victimTo) · ReachedHomeEvent(seat, piece) · BonusRollEvent(seat, reason, {count}) · TurnPassedEvent(from, to)
  · PlayerFinishedEvent(seat, place) · GameOverEvent(placements, reason) · ScoreEvent(seat, delta, reason) · ConcededEvent(seat)
  Mayhem: CardDrawnEvent(seat, card, tile) · UnderdogDrawEvent(seat, card) · HandFullEvent(seat, {underdog})
  · CardPlayedEvent(seat, use) · ArrowZipEvent(seat, piece, via, to) · ChestEvent(seat, piece, coins)
  · MelaEventStarted(kind, endsRound) · MelaEventEnded(kind) · StarsDriftedEvent(shift, stars) · ShieldBlockedEvent(by,
    victim, victimPiece, atLoop) · ShieldExpiredEvent(seat, piece) · FreezeEndedEvent(seat, piece)
  · PieceSwappedEvent(seat, piece, from, to, targetSeat, targetPiece, targetFrom, targetTo)
```
**Event order per action** (what the match screen plays back):

* `Roll`: `[HelpingSixEvent] RolledEvent`, then either `ThreeSixesEvent` + turn change (the third six is not played, so
  there is no underdog draw), or `[UnderdogDrawEvent | HandFullEvent]` followed by `NoMoveEvent` (+ `BonusRollEvent(six)`,
  then a turn change when auto-passing) or nothing (the seat now moves).
* `MovePiece`: `EnteredEvent` **or** `MovedEvent` (path = progress values hopped through; for an arrow it ends on the
  tile) · `[ScoreEvent steps]` · `[ArrowZipEvent]` · `[ShieldBlockedEvent]*` · `[CapturedEvent [ScoreEvent ×2] [FreezeEndedEvent]]*` ·
  `[BonusRollEvent capture]` · `[ReachedHomeEvent [ScoreEvent] [BonusRollEvent home]]` · `[ChestEvent | CardDrawnEvent | HandFullEvent]` ·
  `[BonusRollEvent six]` · `[PlayerFinishedEvent]` · `[GameOverEvent]` — or, for the second die of a Double,
  `NoMoveEvent`; then the turn change.
* Turn change: `[FreezeEndedEvent]*` · `TurnPassedEvent(from, to)` · on a new round `[MelaEventEnded] [StarsDriftedEvent]
  [MelaEventStarted] [StarsDriftedEvent]` · `[ShieldExpiredEvent]*`. A bonus roll is *not* a turn change.
* `UseCard`: `CardPlayedEvent` then the card's own events (`RolledEvent`s, `MovedEvent`…, `PieceSwappedEvent`).
* `Concede`: `ConcededEvent` (+ turn change or `GameOverEvent`). `RushTimeUp` / `FinishByProgress`: `GameOverEvent`.

### 5.5 LudoGame

```dart
class LudoGame {
  LudoGame(MatchConfig config, {Dice? dice, GameState? resumeFrom});   // dice default FairDice()
  LudoGame.fromState(GameState state, {Dice? dice});
  GameState get state;  MatchConfig get config;  Dice get dice;
  List<Move> legalMoves();               // in awaitMove (the moving seat's pieces; empty when stuck)
  List<CardUse> legalCardUses();         // Mayhem: before / after the roll, one per turn
  bool get canPass;                      // a roll with no legal move is waiting for PassTurn / a card
  MoveInsight insight(Move m);           // = analyzeMove(state, m)
  Action autoChoice();                   // what AutoPlay would do now
  StepResult apply(Action a);            // throws IllegalActionException (and changes nothing) on misuse
  GameCore fork({Dice? dice});           // independent mutable copy for look-ahead
}
class StepResult { GameState state; List<GameEvent> events; }
class IllegalActionException implements Exception { String message; Action? action; }
```
`MovePiece` is matched against the engine's own legal list with `Move.sameAs`; the extras (`captures`, `via`, `kind`) a
Wi-Fi guest sends are ignored — the host replays the move itself. The host must check *who* may send: `Roll`, `PassTurn`
and `UseCard` belong to `state.current`; `MovePiece` too (the move's `seat` may be the partner in Teams);
`RollOffRoll(seat)` to the seat it names; `Concede(seat)` to that seat. `actorOf(state, action)` returns that seat (`null` for the host-only `AutoPlay`, `RushTimeUp` and
`FinishByProgress`) and `mayAct(state, action, seat)` is the one-line host check — legality itself is still `apply`'s call.

### 5.6 Simulation core (for bots, rollouts, puzzles)

`GameCore` is the mutable engine under `LudoGame`: all rules once, on flat typed arrays, with **no events and no
snapshots unless asked** — `GameCore.apply(action, {events})` collects events only when a list is passed, and the fast
path methods build none at all. Measured on a laptop: ~1.2–1.6 million simulated turns per second (a 30-turn
rollout from a mid-game position takes ~20 µs), so an Expert decision (≈ 4 moves × 200 rollouts × 30 turns) costs ~15–30 ms.

```dart
GameCore(MatchConfig c, Dice dice);  GameCore.fromState(GameState s, Dice dice);  GameCore clone({Dice? dice});
GameState snapshot();                                     // only at action boundaries — it allocates
// read-only views (the state only changes through apply / roll / play / pass):
Phase get phase; Seat get current; Seat? get firstSeat; bool get isOver; int get turnNumber, round, extraRolls, sixesInRow, rollsTaken, diceUsed;
List<int> get pendingDice; List<Seat> get placements, conceded, activeSeats; Seat get movingSeat; GameOverReason? get overReason;
int progressOf(Seat s, int piece); int totalProgressOf(Seat); int piecesHomeOf(Seat); bool isFinished(Seat); bool isActive(Seat); bool isSafeSquare(int loopIndex); bool isProtected(Seat s, int piece);
int rushScoreOf(Seat), chestCoinsOf(Seat), dryRollsOf(Seat); bool hasCapturedBy(Seat); int get starShift; MelaEventKind? get melaEvent;
List<PowerCard> handOf(Seat); bool holds(Seat, PowerCard);
List<Move> legalMoves(); bool hasLegalMove(); List<CardUse> legalCardUses();
void apply(Action a, {List<GameEvent>? events});         // full rules, optional events
void roll(); void rollValue(int v); void play(Move m); void pass();   // fast paths: no events; play() trusts a move from legalMoves()
MoveInsight insightOf(Move m); int threatsOnPiece(Seat s, int piece, {int maxDistance = 6}); double hitChanceOfPiece(Seat s, int piece);
```
`rollValue(v)` rolls a chosen value (expectimax over a rival's six outcomes, hints, puzzles). Give a clone its own
dice with `clone(dice: SeededDice(i))` so rollouts never share randomness; never roll the real match's dice.

### 5.7 Analysis (move previews, hints, smart moves)

```dart
enum MoveTag { capture, home, safe, risky, enter, lane, arrow, chest, power }
class MoveInsight { Set<MoveTag> tags; double hitChance; int threatsBefore, threatsAfter; bool has(MoveTag t); }
MoveInsight analyzeMove(GameState s, Move m);       // tags, hit chance after the move, threats before / after
double raceProgress(GameState s, Seat seat);        // 0–100: share of the 4 × 57 squares travelled
List<int> currentStars(GameState s);                // Monsoon-aware star squares (starts are always safe too)
bool isSafeLoopSquare(GameState s, int loopIndex);
List<Move> legalMovesOf(GameState s);  List<CardUse> legalCardUsesOf(GameState s);
int threatsOn(GameState s, Seat seat, int piece, {int maxDistance = 6});   // rival pieces that could hit it with one roll
double hitChanceOf(GameState s, Seat seat, int piece);                     // if it stays where it is
Action autoChoice(GameState s);
Seat? actorOf(GameState s, Action a);                     // who may send it (Wi-Fi host check); null = host only
bool mayAct(GameState s, Action a, Seat seat);
```
Tags: `capture` sends a rival back · `home` reaches 56 · `enter` leaves the yard · `lane` turns off the loop into the lane ·
`arrow` zips · `chest` / `power` lands on that Mayhem tile · `safe` = the piece cannot be captured where it lands (star or
start, lane, home, Shield, blockade, Teams pair) · `risky` = not safe and `threatsAfter > 0` (the app hides it under Fog).
`hitChance` = probability the moved piece is captured before its owner moves again: every rival seat gets one turn
(a Teams seat that has finished rolls for its partner, so its partner's pieces get two); in it a rival piece at
distance *d* along its own route hits with a roll of *d* (1/6), or with 6 then *d−6* (1/36), up to two leading sixes
(the third is forfeited) — a leading 6 can be spent on another piece when the rival has one (a yard piece to enter,
another piece to move), otherwise the hitting piece must use it. Rivals are assumed to take a capture; blockades,
frozen pieces and routes (no hitting a square behind a piece or beyond its lane entry) are respected; rival bonus
rolls from captures / reaching home are ignored. Exact cases are unit-tested (1/6, 43/216, 86/216, 1/36, 7/216, 11/36).

### 5.8 Bots, hints, puzzles, dice stats

Built on the API above; every name here is exported and touched by `api_contract_test.dart`.

```dart
// Characters and strength (bots/personality.dart)
class BotPersonality { const BotPersonality(id, {run, safe, hunt, hoard = 0.4, swapLove = 0, onlyAt});
  String id; double run, safe, hunt, hoard /* 0–1: keeps cards */, swapLove /* extra score for Swap */;
  BotLevel? onlyAt;  bool offeredAt(BotLevel level);   // Nani: Expert only; the lobby asks before seating a character
  static const raja, mitu, tara, golu, nani, neutral;  static const presets = [raja, mitu, tara, golu, nani, neutral];
  static BotPersonality byId(String? id);              // neutral for null / unknown (a human, an old save)
}
extension BotLevelTraits on BotLevel {
  double mistakeRate;                                  // 0.35 / 0.15 / 0.05 / 0  (easy … expert)
  bool searches;                                       // hard, expert
  Duration minThink, maxThink;  Duration thinkTime(Random rng);   // the on-screen pause (table below)
}
List<BotPersonality> personalitiesOf(MatchConfig c);   // indexed by Seat.index; neutral for humans / empty seats

// One bot's decisions (bots/bot_brain.dart)
class BotBrain { BotBrain(BotLevel level, [BotPersonality personality = BotPersonality.neutral]);
  static const Duration defaultBudget;                 // = defaultExpertBudget, 300 ms
  Move chooseMove(GameState s, List<Move> legal, Random rng, {Duration budget});   // an element of `legal`; slips included
  Move bestMove(GameState s, List<Move> legal, Random rng, {Duration budget});     // the same without slips
  CardUse? chooseCard(GameState s, Random rng);        // Mayhem, seat on turn, before or after its roll; null = keep the cards
  ExpertResult search(GameState s, List<Move> options, int seed, {Duration budget, int maxRollouts = 200});
  List<BotPersonality> personalitiesFor(GameState s);  // how each seat is modelled (the bot's own seat = its personality)
}
class ExpertResult { List<double> values /* mean equity 0–1 per option */; int rollouts; int get best; }
const defaultRollouts = 200, rolloutHorizon = 30;  const Duration defaultExpertBudget = 300 ms;

// The shared formula and the position value (bots/move_score.dart, bots/evaluation.dart)
abstract final class BotScore { progress = 0.5; leaveYard = 50; reachHome = 80; enterLane = 30; landOnStar = 18; capture = 90; threatDelta = 28; }
double scoreMove(GameCore core, Move m, BotPersonality p, {MoveInsight? insight, bool deep = false});
List<double> scoreMoves(GameCore core, List<Move> moves, BotPersonality p, {bool deep = false});
List<Move> distinctMoves(List<Move> moves);            // one of each group of moves that look identical (Move.looksLike)
double evaluatePosition(GameCore c, Seat me);          // squares; > 0 = me (or my team) ahead; ±1000 when the match is over
double winEquity(double value);                        // logistic, 0–1 (30 squares ahead ≈ 73 %)

// Reactions (bots/reactions.dart): stickers, captured → angry, capture → cool
abstract final class StickerIds { happy, laugh, wow, cool, angry, cry; static const all; }
class BotSticker { Seat seat; String sticker; }
class BotReactions { BotReactions({cooldownTurns = 3, muted = false});  bool muted;
  List<BotSticker> react(GameState after, Iterable<GameEvent> events);   // call after every step; only bots speak
  void reset();
}

// The player's helpers (bots/hints.dart, bots/smart_moves.dart)
Move hintFor(GameState s);                             // Hard evaluation, no slips; StateError when there is no move
MoveRating rateMove(GameState s, Move chosen, {int rollouts = 64});   // vs the Expert search; ArgumentError if illegal
class MoveRating { Move chosen, expert; bool matchedExpert, forced; double scoreGap /* equity lost, 0–1 */;
  bool get smart /* matched, or lost < smartGap */;  static const smartGap = 0.01;  toJson / fromJson }
class SmartMoveTally { SmartMoveTally([Iterable<RatedMove>]);  add(MoveRating r, {required int turn});
  List<RatedMove> moves; int decisions /* forced moves left out */, matched, smart; double? smartShare; RatedMove? costliest;  toJson / fromJson }
class RatedMove { int turn; MoveRating rating;  toJson / fromJson }

// Isolate-friendly calls (bots/bot_json.dart): one JSON map in, one out, for Isolate.run
Map<String, Object?> botMoveRequest(GameState, List<Move> legal, {required BotLevel level, String? personality, required int seed, Duration budget});
Map<String, Object?> botChooseMoveJson(Map<String, Object?> request);   Move botMoveFromResponse(Map<String, Object?> response, List<Move> legal);
Map<String, Object?> botStateRequest(GameState, {BotLevel level, String? personality, int seed});
Map<String, Object?> botChooseCardJson(request);   CardUse? botCardFromResponse(response);
Map<String, Object?> botHintJson(request);                              // {'move': …} or {'move': null}
Map<String, Object?> botRateRequest(GameState, Move played, {int rollouts});   Map<String, Object?> botRateMoveJson(request);   // MoveRating.toJson()

// Daily puzzle (puzzles/)
Puzzle dailyPuzzle(int dayNumber);                     // any integer; deterministic, always solvable; Puzzle.number = dayNumber
Puzzle curatedPuzzle(int index, {int number = 0});  const curatedPuzzleCount = 3;   // hand-checked fallbacks
class Puzzle { int number; GameState start /* hero to roll */; Seat hero /* red */; int heroPiece; List<int> rolls /* 3, each used once */;
  PuzzleGoal goal; PuzzleSolution analysis /* exhaustive, lazy */; List<PuzzleStep> get solution; }
enum PuzzleGoalKind { homeSafe, captureSafe, rescue, doubleCapture }    class PuzzleGoal { kind; int captures; }
class PuzzleStep { int rollIndex; int piece; }    class PuzzleSolution { List<List<PuzzleStep>> wins; int plays; bool solvable; double winShare; }
PuzzleSolution solvePuzzle(Puzzle p);
enum PuzzleStatus { playing, solved, failed }     enum PuzzleFailure { exposed, missedGoal, stuck }
class PuzzleRun { PuzzleRun(Puzzle);  factory PuzzleRun.replay(Puzzle, Iterable<PuzzleStep>);
  GameState state; PuzzleStatus status; PuzzleFailure? failure; bool solved, failed, canStillWin; List<PuzzleStep> steps;
  List<bool> used; List<int> remaining; int captures;
  List<Move> movesFor(int rollIndex);                  // destinations of a die before a piece is picked
  PuzzleStepResult apply(int rollIndex, int piece);    // never throws: an impossible step is just not accepted
  PuzzleStep? hint();   Map<int, Seat> dangerSquares();   // SHOW DANGER: loop index → a rival seat that could hit it
  void reset();                                        // START OVER
}
class PuzzleStepResult { bool accepted; PuzzleStatus status; PuzzleFailure? failure; Move? move; MoveInsight? insight;
  List<Seat> threatenedBy; int captured; GameState state; bool solved, failed; }

// Dice fairness (stats/dice_stats.dart)
class DiceStats { factory DiceStats.of(Iterable<int> rolls);      // values outside 1–6 are ignored (→ ignored)
  List<int> counts /* [1..6], index 0 unused */; int total, ignored; double expectedPerFace, chiSquare, pValue;  double share(int face);
  bool enoughData /* ≥ minimumRolls = 30 */, looksFair /* p ≥ alpha = 0.001, or too few rolls */; }
```

**Bot formula** (design board B): `score = 0.5·run·to + 50 (leave yard) + 80 (reach home) + 30 (enter lane) + 18·safe (land on a
star) + 90·hunt (capture) + 28·safe·(threat before − threat after)`; threat = rival pieces 1–6 squares behind that could land
there next roll. The deep score (Hard, Expert) also counts 7–12 via 6-then-k at 1/36 each, as `6 × hitChance` from the analysis.

| Level | Decides by | Slips | Think pause (`thinkTime`) |
|---|---|---|---|
| Easy | softmax over the scores (temperature 22) | 35 % a plain random move | 0.9–1.2 s |
| Normal | the best score | 15 % (another move, never the best) | 0.6–0.9 s |
| Hard | expectimax over the next round of rival rolls (every roll 1–6 at 1/6, rivals answer with their own personality, the bot's first bonus roll searched too) + 0.3 × formula + 0.5 × the personality's difference | 5 % | 0.5–0.8 s |
| Expert | 200 Monte-Carlo rollouts per move (30-turn horizon, the same dice in rollout *r* for every candidate, rivals modelled by personality), stopped at the 300 ms budget (at least 8 rollouts); the personality adds at most 0.05 equity | 0 % | 0.4 s show + up to 0.3 s search |

Personalities (run / safe / hunt): Raja 1.0/0.6/1.8 (Hunter), Mitu 0.8/1.8/0.7 (Turtle), Tara 1.7/0.7/1.0 (Racer), Golu 1.0/0.9/1.2
(hoards cards: `hoard` 0.9, `swapLove` 18), Nani 1.1/1.3/1.2 (Expert-only in the lobby). Power cards (Mayhem): every legal use gets a
gain in squares and the best is played when it clears `5 + 14·hoard` (×0.4 with a full hand); Reroll only for an unplayable or poor and
risky roll (never a playable 6), Double when pieces are on the board, Shield counts double. Bots never see future dice: a decision gets a
`GameState` (no dice inside) and its own `Random`; every look-ahead rolls `SeededDice` streams or a chosen value, never the match's dice.
Expert decides inside its 300 ms budget (about 125 ms on a laptop) and is meant for an isolate
(`Isolate.run(() => botChooseMoveJson(request))`); Hard is milliseconds typically and honours the same budget; `hintFor` is Hard
without slips (a few milliseconds, never past the 300 ms deadline).

**Stickers**: a bot that captured sends `cool`, a bot that was captured sends `angry`; each bot at most once per 3 turns
(`GameState.turnNumber`), nobody when muted (Settings → bot stickers); humans and Wi-Fi guests never "speak" through `BotReactions`.

**Smart moves**: `rateMove` seeds its search from a fingerprint of the position, so a position and move always get the same rating
on every device. The app rates each human decision as it is played (or afterwards, in an isolate) and collects the ratings in a
`SmartMoveTally` for the report ("26 of 30 moves matched the Expert", "turn 14 cost you most" = `costliest`); forced moves
(one distinct option) are left out of every count.

**Daily puzzle**: the day picks a goal from a fixed cycle (home-safe twice, capture-safe, rescue, double capture); positions are proposed
from a SplitMix64 stream seeded by (day, goal, attempt) and kept only when the exhaustive search (`solvePuzzle`, the real engine rules)
finds a win, there are at least 4 different plays, no more than a third of them win, and (home-safe) playing the rolls left to right as
shown fails. Rivals never move; "can be hit" means a rival piece 1–6 squares behind on a non-safe loop square. Days 0 … 1095 are tested
and days 0, 1 and 2 are pinned, so changing the generator re-rolls every phone.

## 6. Quality bar

* Deterministic with `SeededDice` / `ScriptedDice`; `FairDice` uses `Random.secure()`; no rubber-banding.
* `cd packages/ludo_engine && dart test` — ~450 tests (`api_contract_test.dart` touches every name in section 5, so this
  document cannot drift from the code unnoticed): every rule above (classic, each house rule, each mode, each
  card and Mela event, tiles, roll-off), JSON round trips of configs, states, actions, moves and all 29 event types,
  exact hit-chance values, a differential test of legal moves and captures against a slow reference on 30,000 random
  positions, an independent naive re-implementation of the Classic / Quick / Rush / Teams flow played side by side with
  the engine on the same dice (`flow_reference_test.dart`), resume equivalence (a match restored from its JSON state
  continues exactly like the uninterrupted one, `resume_test.dart`), simulation speed, and long random self-play in every mode and random house-rule
  combination (invariants after every action: piece counts and ranges, no rival seats sharing a non-safe square,
  announced moves land where announced, snapshots / clones / JSON equal, every game terminates, determinism).
  Wave 2 adds: the formula term by term and the position value (`bot_brain_test`, `evaluation_test`), card play (`bot_cards_test`), a bot ladder
  in self-play (`bot_strength_test`: Normal beats Easy, Hard beats Normal, Expert beats the rest, characters play differently but none is crippled),
  Expert / Hard inside their budget (`bot_perf_test`), hints, ratings and the isolate calls (`hints_test`), pacing, stickers and the smart-move
  tally (`bot_extras_test`), every day of three years of puzzles solved and replayed (`puzzle_test`) and chi-square values against textbook tables
  (`dice_stats_test`). Timing tests are generous (the suite runs files side by side) and compare against the budgets, never a bare wall-clock number.
* 0 analyzer issues (`dart analyze`), files < ~400 lines, a header comment per file (what + why).
