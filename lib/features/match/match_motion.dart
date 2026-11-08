// MatchMotion: the timings only the match board uses, named once (core/motion/motion.dart has the shared ones).
//
// Why a file of their own: design board D lists the app-wide moments (hop, capture, home, toast …) and those live in
// `Motion`; the board also has smaller beats (the star burst, an arrow's glide, how long a sticker stays) that come
// from Match.dc.html / Mayhem.dc.html / Tabletop.dc.html. Naming them here keeps magic numbers out of the widgets.
// Everything the player sees as a game animation still goes through `Motion.game(d, speed)`; Reduce Motion uses the
// short "reduced" waits (what carries meaning stays, the movement goes).

abstract final class MatchMotion {
  // ── On the board ──────────────────────────────────────────────────────
  /// The POW! / HOME! / "+150" star grows, turns and fades (Match.dc.html · lmBurst).
  static const burst = Duration(milliseconds: 760);

  /// The ring flash of a piece leaving the yard.
  static const ring = Duration(milliseconds: 420);

  /// With Reduce Motion a burst only fades.
  static const reducedFade = Duration(milliseconds: 140);

  /// The board's shake when a capture lands (board D · "screen nudge").
  static const nudge = Duration(milliseconds: 280);

  /// An arrow tile's zip: one glide.
  static const zip = Duration(milliseconds: 320);

  /// A Swap card: both pieces glide to each other's square.
  static const swap = Duration(milliseconds: 520);

  // ── Beats between events ──────────────────────────────────────────────
  /// A roll-off roll and an underdog draw stay on screen for this long.
  static const beat = Duration(milliseconds: 500);

  /// A chest opens.
  static const chest = Duration(milliseconds: 450);

  /// A shield held a capture off.
  static const shieldHeld = Duration(milliseconds: 400);

  /// A power card was played.
  static const cardPlayed = Duration(milliseconds: 350);

  // ── Speech and ending ─────────────────────────────────────────────────
  /// A sticker or phrase bubble beside an avatar stays this long.
  static const bubbleLife = Duration(milliseconds: 1800);

  /// A bubble pops in.
  static const bubbleIn = Duration(milliseconds: 380);

  /// After the verdict toast the celebration holds on a little longer than the title's slam.
  static const winPause = Duration(milliseconds: 300);

  // ── Tabletop ──────────────────────────────────────────────────────────
  /// The glow of the seat on turn pulses (avatar ring and dice well).
  static const glow = Duration(milliseconds: 1200);

  /// "YOUR TURN" bobs.
  static const point = Duration(milliseconds: 900);

  // ── Reduce Motion ─────────────────────────────────────────────────────
  /// A flat die has no toss: it only waits this long before it reads.
  static const reducedToss = Duration(milliseconds: 120);

  /// "Time's up!" stays long enough to be read.
  static const reducedTimeUp = Duration(milliseconds: 900);

  /// The verdict stays this long before the result opens.
  static const reducedWin = Duration(milliseconds: 400);
}
