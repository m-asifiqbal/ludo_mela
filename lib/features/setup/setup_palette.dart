// The art colours of the setup screens that have no global token: the Mela Tour ground, the green
// Pass & play band, the picker rows of Game options, the four seat discs and the VS player cards.
//
// Why a file of its own: CLAUDE.md keeps raw colours out of feature widgets. Everything that exists as
// a token (LmColors, LmGloss) is used from there; only the one-off artwork of VsAiSetup, Venues,
// PassPlaySetup and VsIntro lives here, named, so a restyle touches one place.

import 'dart:ui';

import 'package:ludo_engine/ludo_engine.dart' show Seat;

import '../../core/widgets/backdrops.dart';

/// The four colours of a Pass & play seat disc: lit top, body, shade and the side band under it.
class SeatDiscColors {
  const SeatDiscColors({required this.light, required this.mid, required this.dark, required this.side});

  final Color light;
  final Color mid;
  final Color dark;
  final Color side;
}

/// One VS card: the gradient (160°, light to dark) and the hard edge under it.
class VsCardColors {
  const VsCardColors({required this.light, required this.dark, required this.edge});

  final Color light;
  final Color dark;
  final Color edge;
}

abstract final class SetupPalette {
  // ── Grounds ───────────────────────────────────────────────────────────
  /// The ground of Mela Tour and Pass & play: the screen blue, centred high (the Mela Cup ground without rays).
  static final BackdropSpec ground = BackdropSpec(
    colors: BackdropSpec.screen.colors,
    stops: BackdropSpec.screen.stops,
    rx: 1.3,
    ry: .7,
    cy: .3,
  );

  // ── Pass & play ───────────────────────────────────────────────────────
  /// The green header band (top to bottom) and its lip.
  static const bandHi = Color(0xFF8DEB50);
  static const bandLo = Color(0xFF3DA828);
  static const bandLip = Color(0xFF1D7A10);

  /// The navy strip under the START button (and its fade-in).
  static const footer = Color(0xFF0B2C74);

  /// A hairline between switch rows (white at 14 %).
  static const divider = Color(0x24FFFFFF);

  /// The seat discs of the "Who's playing?" rows, by seat.
  static SeatDiscColors disc(Seat seat) => switch (seat) {
        Seat.red => const SeatDiscColors(light: Color(0xFFFF8A7A), mid: Color(0xFFEC3B30), dark: Color(0xFFA71D16), side: Color(0xFF7E120E)),
        Seat.green => const SeatDiscColors(light: Color(0xFFA3EC6A), mid: Color(0xFF43B32D), dark: Color(0xFF24781A), side: Color(0xFF195A11)),
        Seat.yellow => const SeatDiscColors(light: Color(0xFFFFEA7A), mid: Color(0xFFFFC21F), dark: Color(0xFFC88A00), side: Color(0xFF8E6100)),
        Seat.blue => const SeatDiscColors(light: Color(0xFF7CC6FF), mid: Color(0xFF2381EC), dark: Color(0xFF114FA8), side: Color(0xFF0B3878)),
      };

  // ── Game options pickers (mode tiles, player rows) ────────────────────
  static const pickHi = Color(0xFF2258AE);
  static const pickLo = Color(0xFF1A4A98);
  static const pickRim = Color(0xFF3F78D6);
  static const pickOnHi = Color(0xFF3B8CEB);
  static const pickOnLo = Color(0xFF2368C8);

  /// The tick box of a chosen row: its rim when on.
  static const checkOnRim = Color(0xFFB9F58A);

  /// The pale blue of the small print on pickers.
  static const pickSub = Color(0xFFCFE6FF);

  /// The wood frame of the little board on the player rows (lip) and the paper-grey of a seat nobody uses.
  static const boardLip = Color(0xFF6B3E16);
  static const yardOff = Color(0xFFC9CFD9);
  static const yardOffDark = Color(0xFFAEB6C3);

  // ── VS intro ──────────────────────────────────────────────────────────
  /// The ribbon with the table's name.
  static const vsRibbon = Color(0xFF8B55F0);
  static const vsRibbonEdge = Color(0xFFFFD45A);

  /// The card of the player in [seat].
  static VsCardColors vsCard(Seat seat) => switch (seat) {
        Seat.green => const VsCardColors(light: Color(0xFF8DEB50), dark: Color(0xFF2E9A1B), edge: Color(0xFF1D6B0F)),
        Seat.yellow => const VsCardColors(light: Color(0xFFFFE27A), dark: Color(0xFFE89A00), edge: Color(0xFF9A5600)),
        Seat.red => const VsCardColors(light: Color(0xFFFF9A8A), dark: Color(0xFFD22A21), edge: Color(0xFF8A1410)),
        Seat.blue => const VsCardColors(light: Color(0xFF7CC6FF), dark: Color(0xFF1C72DA), edge: Color(0xFF0D4A9E)),
      };

  /// The soft inner rim and top light of a VS card, and the dark pill under the name.
  static const vsCardRim = Color(0x59FFFFFF);
  static const vsCardLight = Color(0x40FFFFFF);
  static const vsTagFill = Color(0x47000000);

  /// The pips of a dice face that shows 1 or 4 are red.
  static const diceRedPip = Color(0xFFD7263D);
}
