// Small enums that explain *why* something happened, carried by events and
// stored in the game state: why a bonus roll was granted, why points changed,
// why the match ended.
//
// Why enums instead of strings: the UI switches on them (a different toast and
// sound per reason) and the compiler keeps every switch exhaustive.

/// Why a seat gets another roll.
enum BonusReason {
  /// Rolled a 6.
  six,

  /// Captured a rival piece.
  capture,

  /// Brought a piece home.
  home,
}

/// Why a Rush score changed.
enum ScoreReason {
  /// +1 per square moved.
  steps,

  /// +20 for a capture.
  capture,

  /// -10 for being captured.
  captured,

  /// +50 for a piece home.
  home,
}

/// Why a match ended.
enum GameOverReason {
  /// Rush: a seat brought all four pieces home.
  allHome,

  /// Classic, Master, Mayhem: only one seat is left playing.
  lastStanding,

  /// Quick: a seat reached `Rules.quickTarget` pieces home.
  quickTarget,

  /// Teams: all eight pieces of a team are home.
  teamWon,

  /// Rush: the clock ran out.
  timeUp,

  /// `FinishByProgress`: ended early, seats placed by progress.
  byProgress,

  /// Everyone else left the match.
  conceded,

  /// Blockades left no seat with any possible move.
  stalemate,
}
