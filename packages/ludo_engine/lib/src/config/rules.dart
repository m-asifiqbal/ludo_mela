// Every switch that changes how the dice and the board behave — the classic
// rules plus all house rules from design board B / the Pass & Play setup.
//
// Why a plain value class: the app builds one from the player's House rules
// toggles (or from a venue), `Rules.forMode` lays the mode's own requirements
// on top (Master forces blockades + capture-before-lane, Quick and Rush start
// with pieces out), and the whole thing rides along in MatchConfig so a saved
// match or a Wi-Fi room plays by exactly the same rules on every phone.

import '../json.dart';
import 'game_mode.dart';

/// Points the Rush mode awards (design board B, "Rush & Teams scoring").
abstract final class RushScoring {
  /// Points for every square a piece moves (leaving the yard counts as one).
  static const perSquare = 1;

  /// Points for sending a rival piece back.
  static const perCapture = 20;

  /// Points lost when one of your pieces is sent back.
  static const whenCaptured = -10;

  /// Points for every piece that reaches home.
  static const perPieceHome = 50;
}

/// The rule switches of a match. Defaults are the classic rules.
class Rules {
  const Rules({
    this.sixToEnter = true,
    this.bonusOnSix = true,
    this.bonusOnCapture = true,
    this.bonusOnHome = true,
    this.threeSixesForfeit = true,
    this.exactHome = true,
    this.blockades = false,
    this.gentleCaptures = false,
    this.helpingDice = false,
    this.captureBeforeLane = false,
    this.autoPass = true,
    this.startOut = false,
    this.quickTarget = 1,
  }) : assert(quickTarget >= 1 && quickTarget <= 4, 'quickTarget must be 1..4');

  /// The presets of [mode] laid over [house] (the player's house rules, classic
  /// when omitted). Master forces [blockades] and [captureBeforeLane]; Quick
  /// and Rush put every piece on its start square ([startOut]); the other modes
  /// take [house] unchanged.
  factory Rules.forMode(GameMode mode, {Rules? house}) {
    final base = house ?? const Rules();
    return switch (mode) {
      GameMode.classic || GameMode.mayhem || GameMode.teams => base,
      GameMode.quick || GameMode.rush => base.copyWith(startOut: true),
      GameMode.master => base.copyWith(captureBeforeLane: true, blockades: true),
    };
  }

  /// Rolls with no 6 in a row (while stuck in the yard) before Helping dice
  /// gives a 6.
  static const helpingDiceAfter = 5;

  /// Only a 6 brings a piece out of the yard. Off: a 1 or a 6.
  final bool sixToEnter;

  /// A 6 gives one more roll.
  final bool bonusOnSix;

  /// A capture gives one more roll (two during Mayhem's Lucky hour).
  final bool bonusOnCapture;

  /// A piece reaching home gives one more roll.
  final bool bonusOnHome;

  /// The third 6 in a row ends the turn at once and is not played.
  final bool threeSixesForfeit;

  /// Home needs the exact roll. Off: overshooting still finishes.
  final bool exactHome;

  /// Two or more pieces of one side on one non-safe loop square form a block that
  /// no piece may pass or land on (the owner's other pieces included).
  final bool blockades;

  /// A captured piece steps back 6 squares instead of returning to the yard.
  final bool gentleCaptures;

  /// A seat with no piece out that has rolled [helpingDiceAfter] times without
  /// a way out gets a 6 next (announced). Never at coin tables / in Wi-Fi rooms
  /// unless the host turns it on — the app decides what to pass in.
  final bool helpingDice;

  /// (Master) a seat that has never captured can't enter its lane: a move that
  /// would pass the last loop square keeps going around the loop.
  final bool captureBeforeLane;

  /// A roll with no legal move passes the turn by itself. Off: the seat must
  /// send `PassTurn` (the app shows a button instead of the 1 s toast).
  final bool autoPass;

  /// Every piece starts on its start square instead of in the yard (Quick, Rush).
  final bool startOut;

  /// Quick: how many pieces a seat must bring home to win (1 … 4).
  final int quickTarget;

  Rules copyWith({
    bool? sixToEnter,
    bool? bonusOnSix,
    bool? bonusOnCapture,
    bool? bonusOnHome,
    bool? threeSixesForfeit,
    bool? exactHome,
    bool? blockades,
    bool? gentleCaptures,
    bool? helpingDice,
    bool? captureBeforeLane,
    bool? autoPass,
    bool? startOut,
    int? quickTarget,
  }) => Rules(
    sixToEnter: sixToEnter ?? this.sixToEnter,
    bonusOnSix: bonusOnSix ?? this.bonusOnSix,
    bonusOnCapture: bonusOnCapture ?? this.bonusOnCapture,
    bonusOnHome: bonusOnHome ?? this.bonusOnHome,
    threeSixesForfeit: threeSixesForfeit ?? this.threeSixesForfeit,
    exactHome: exactHome ?? this.exactHome,
    blockades: blockades ?? this.blockades,
    gentleCaptures: gentleCaptures ?? this.gentleCaptures,
    helpingDice: helpingDice ?? this.helpingDice,
    captureBeforeLane: captureBeforeLane ?? this.captureBeforeLane,
    autoPass: autoPass ?? this.autoPass,
    startOut: startOut ?? this.startOut,
    quickTarget: quickTarget ?? this.quickTarget,
  );

  Map<String, Object?> toJson() => {
    'sixToEnter': sixToEnter,
    'bonusOnSix': bonusOnSix,
    'bonusOnCapture': bonusOnCapture,
    'bonusOnHome': bonusOnHome,
    'threeSixesForfeit': threeSixesForfeit,
    'exactHome': exactHome,
    'blockades': blockades,
    'gentleCaptures': gentleCaptures,
    'helpingDice': helpingDice,
    'captureBeforeLane': captureBeforeLane,
    'autoPass': autoPass,
    'startOut': startOut,
    'quickTarget': quickTarget,
  };

  /// Reads rules from JSON; any missing key keeps its classic default so a
  /// save written before a rule existed still loads.
  factory Rules.fromJson(Map<String, Object?> j) {
    const d = Rules();
    bool b(String k, bool def) => j[k] == null ? def : readBool(j[k], k);
    final target = j['quickTarget'] == null ? d.quickTarget : readInt(j['quickTarget'], 'quickTarget');
    return Rules(
      sixToEnter: b('sixToEnter', d.sixToEnter),
      bonusOnSix: b('bonusOnSix', d.bonusOnSix),
      bonusOnCapture: b('bonusOnCapture', d.bonusOnCapture),
      bonusOnHome: b('bonusOnHome', d.bonusOnHome),
      threeSixesForfeit: b('threeSixesForfeit', d.threeSixesForfeit),
      exactHome: b('exactHome', d.exactHome),
      blockades: b('blockades', d.blockades),
      gentleCaptures: b('gentleCaptures', d.gentleCaptures),
      helpingDice: b('helpingDice', d.helpingDice),
      captureBeforeLane: b('captureBeforeLane', d.captureBeforeLane),
      autoPass: b('autoPass', d.autoPass),
      startOut: b('startOut', d.startOut),
      quickTarget: target.clamp(1, 4),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Rules &&
      other.sixToEnter == sixToEnter &&
      other.bonusOnSix == bonusOnSix &&
      other.bonusOnCapture == bonusOnCapture &&
      other.bonusOnHome == bonusOnHome &&
      other.threeSixesForfeit == threeSixesForfeit &&
      other.exactHome == exactHome &&
      other.blockades == blockades &&
      other.gentleCaptures == gentleCaptures &&
      other.helpingDice == helpingDice &&
      other.captureBeforeLane == captureBeforeLane &&
      other.autoPass == autoPass &&
      other.startOut == startOut &&
      other.quickTarget == quickTarget;

  @override
  int get hashCode => Object.hash(
    sixToEnter,
    bonusOnSix,
    bonusOnCapture,
    bonusOnHome,
    threeSixesForfeit,
    exactHome,
    blockades,
    gentleCaptures,
    helpingDice,
    captureBeforeLane,
    autoPass,
    startOut,
    quickTarget,
  );

  @override
  String toString() => 'Rules(${toJson()})';
}
