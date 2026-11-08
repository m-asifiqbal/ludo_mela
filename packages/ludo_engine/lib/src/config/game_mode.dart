// The small enums a match is configured with: the mode, who controls a seat,
// and how strong a bot is.
//
// Why separate from Rules: modes decide *what the match is* (goal, scoring,
// Mayhem extras), rules decide *how the dice behave*. The app builds a
// MatchConfig from one of each plus the players.

/// The six ways to play (design board B, "Modes").
enum GameMode {
  /// All four pieces home; play on for places until one seat is left.
  classic,

  /// Pieces start out; the first seat to bring `Rules.quickTarget` pieces home wins.
  quick,

  /// Classic plus "capture once before any piece may enter your lane" and blockades.
  master,

  /// Pieces start out, a 5-minute clock (driven by the app) and points decide.
  rush,

  /// Classic plus arrows, power tiles and cards, chests, Mela events and the underdog draw.
  mayhem,

  /// Four players, opposite seats are partners; the team wins when all eight pieces are home.
  teams;

  /// Fewest seats the mode can be played with.
  int get minPlayers => this == GameMode.teams ? 4 : 2;

  /// Most seats the mode can be played with.
  int get maxPlayers => 4;

  /// True for the partner mode.
  bool get isTeams => this == GameMode.teams;

  /// True when [n] seats is a legal player count for this mode.
  bool supportsPlayers(int n) => n >= minPlayers && n <= maxPlayers;
}

/// Who controls a seat.
enum PlayerKind {
  /// A person on this device.
  human,

  /// A computer player (wave 2's BotBrain picks its moves).
  bot,

  /// A person on another phone in a Wi-Fi room.
  remote,
}

/// Bot strength (design board B, "How bots think").
enum BotLevel { easy, normal, hard, expert }
