// Piece (coin) skins: the emblem stamped on every coin, the rim colour and the
// shape of the coin (design board "Collection" › Pieces).
//
// Why data: a coin is the same thick disc in every skin — only the emblem, the
// white rim and, for two skins, the outline change. Player colours are NOT part
// of a skin: they are fixed by seat (LmColors.seat), so a Royal Crown piece is
// still red, green, yellow or blue.
//
// Names are English literals translated where shown (`tr(skin.name)`); the ids
// are what the save file and the catalogue store.

import 'dart:ui';

import 'package:flutter/painting.dart' show BorderRadius, Radius;

import '../theme/colors.dart';
import 'emblems.dart';

/// The outline of a coin.
enum PieceShape {
  /// A round coin.
  circle,

  /// A rounded square (corner radius 30 %): Moon Gems.
  squircle,

  /// A lamp: round top, flatter bottom (Diya Lights).
  diya;

  /// Corner radii of a coin of edge [s].
  BorderRadius radius(double s) => switch (this) {
        PieceShape.circle => BorderRadius.circular(s / 2),
        PieceShape.squircle => BorderRadius.circular(s * .3),
        PieceShape.diya => BorderRadius.vertical(top: Radius.circular(s * .5), bottom: Radius.circular(s * .42)),
      };
}

class PieceSkin {
  const PieceSkin({
    required this.id,
    required this.name,
    required this.rarity,
    required this.emblem,
    this.ring = const Color(0xBFFFFFFF),
    this.shape = PieceShape.circle,
    this.emblemOpacity = .92,
  });

  /// Stable id stored in saves ("lotus", "royal_crown" …).
  final String id;

  /// English display name ("Lotus Coins").
  final String name;
  final LmRarity rarity;

  /// SVG path (24 box) of the emblem, drawn in white.
  final String emblem;

  /// The light ring just inside the coin's edge.
  final Color ring;
  final PieceShape shape;
  final double emblemOpacity;
}

/// Every piece skin of the Collection plus the earn-only event set.
abstract final class PieceSkins {
  /// The default coins: a white lotus.
  static const lotus = PieceSkin(id: 'lotus', name: 'Lotus Coins', rarity: LmRarity.standard, emblem: LmEmblems.lotus);

  static const star = PieceSkin(id: 'star', name: 'Star Coins', rarity: LmRarity.standard, emblem: LmEmblems.star);

  static const moon = PieceSkin(
    id: 'moon',
    name: 'Moon Gems',
    rarity: LmRarity.rare,
    emblem: LmEmblems.moon,
    ring: Color(0xFFBFE6FF),
    shape: PieceShape.squircle,
  );

  static const crown = PieceSkin(
    id: 'crown',
    name: 'Royal Crown',
    rarity: LmRarity.epic,
    emblem: LmEmblems.crown,
    ring: Color(0xFFFFD84A),
  );

  static const diya = PieceSkin(
    id: 'diya',
    name: 'Diya Lights',
    rarity: LmRarity.epic,
    emblem: LmEmblems.diya,
    ring: Color(0xFFFFE7A0),
    shape: PieceShape.diya,
  );

  static const peacock = PieceSkin(
    id: 'peacock',
    name: 'Peacock Fan',
    rarity: LmRarity.legendary,
    emblem: LmEmblems.peacock,
    ring: Color(0xFF7FE7E0),
  );

  /// Earn-only: the Mela event pieces (Economy board, "Elephant pucks").
  static const elephant = PieceSkin(
    id: 'elephant',
    name: 'Elephant Coins',
    rarity: LmRarity.legendary,
    emblem: LmEmblems.elephant,
    ring: Color(0xFFFFB6E1),
  );

  /// Collection order.
  static const List<PieceSkin> all = [lotus, star, moon, crown, diya, peacock, elephant];

  /// The skin stored under [id], or [lotus] for an unknown id (old saves).
  static PieceSkin byId(String? id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return lotus;
  }
}
