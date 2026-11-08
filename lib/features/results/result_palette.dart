// The art colours of the results screens that have no global token: the podium medals, the
// headline fills, the tints of the "what happened" chips, the race lines and the key-moment tiles.
//
// Why a file of its own: CLAUDE.md keeps raw colours out of feature widgets. Everything that
// exists as a token (LmColors, LmGloss) is used from there; only the one-off artwork of
// Win.dc.html and MatchReport.dc.html lives here, named, so a restyle touches one place.

import 'dart:ui';

import '../../core/theme/colors.dart';
import '../../core/theme/gloss.dart';
import '../../domain/match_record.dart' show KeyMomentKind;

/// One step of the podium: the avatar ring, the block's face (light to dark) and its lit top.
class PodiumColors {
  const PodiumColors({required this.ring, required this.face, required this.faceDark, required this.top});

  final Color ring;
  final Color face;
  final Color faceDark;
  final Color top;
}

abstract final class ResultPalette {
  // ── Podium (gold, silver, bronze) ─────────────────────────────────────
  static const gold = PodiumColors(
    ring: LmColors.frameActive,
    face: LmColors.xpText,
    faceDark: Color(0xFFE89A00),
    top: Color(0xFFFFF3B8),
  );
  static const silver = PodiumColors(
    ring: Color(0xFFC9D3E0),
    face: Color(0xFFE8EEF6),
    faceDark: Color(0xFF9AA8BC),
    top: LmColors.white,
  );
  static const bronze = PodiumColors(
    ring: Color(0xFFE39A5A),
    face: Color(0xFFF2B27A),
    faceDark: Color(0xFFB8692A),
    top: Color(0xFFFFD9B8),
  );

  /// The medal colours of podium step [rank] (1 = gold).
  static PodiumColors medal(int rank) => switch (rank) {
        1 => gold,
        2 => silver,
        _ => bronze,
      };

  /// The soft drop under a podium avatar, and the light / shade along a block's top and foot.
  static const avatarDrop = Color(0x59000000);
  static const blockLight = Color(0x73FFFFFF);
  static const blockShade = Color(0x2E000000);

  // ── Headline fills ────────────────────────────────────────────────────
  /// "YOU WON!": the gold of [HeroTitle]'s default; a finished-but-not-first headline is cool silver.
  static const placedFill = [LmColors.white, LmColors.textSoft, Color(0xFF8FB6F0)];
  static const placedOutline = Color(0xFF16408F);
  static const placedDrop = Color(0xFF06194A);

  // ── Chips under the rewards ───────────────────────────────────────────
  static const chipFact = Color(0x24FFFFFF);
  static const chipMission = Color(0x5947BA2B);
  static const chipAchievement = Color(0x59FFC61F);
  static const chipCup = Color(0x669B6BFF);

  /// The hard lip under a coloured icon tile (key moments).
  static const tileLip = LmColors.barTrackSoft;

  // ── Match report ──────────────────────────────────────────────────────
  /// The bar under the report's scroll: the ground fades into it, and it fills the home-indicator inset.
  static const reportBar = Color(0xFF0B2C74);

  // ── Race chart ────────────────────────────────────────────────────────
  /// The line of a seat in the race chart (red, green, yellow, blue by seat): the board's lit tones,
  /// brighter than the seat colours so they stand out on the dark well.
  static Color line(int seatIndex) => switch (seatIndex) {
        0 => const Color(0xFFFF6B5E),
        1 => LmGloss.green.hi,
        2 => const Color(0xFFFFD84F),
        _ => const Color(0xFF7CC6FF),
      };

  // ── Key moments ───────────────────────────────────────────────────────
  /// The icon tile of each kind of key moment (the board draws four; smart move and blunder follow its style).
  static Color moment(KeyMomentKind kind) => switch (kind) {
        KeyMomentKind.capture => const Color(0xFFD22A21),
        KeyMomentKind.captured => LmGloss.purple.lo,
        KeyMomentKind.sixes => const Color(0xFFE89A00),
        KeyMomentKind.home => LmGloss.green.lo,
        KeyMomentKind.smartMove => LmGloss.blue.lo,
        KeyMomentKind.blunder => LmColors.pinkLo,
      };
}
