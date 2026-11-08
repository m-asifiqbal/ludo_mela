// Dice skins (design board "Collection" › Dice): the material of the cube and
// the colour of its pips.
//
// Every skin is the same fair 1–6 cube; only paint changes. A face is a radial
// gradient focused up-left (hi → mid at 42 % → lo) with a soft rim, a darker
// inner shadow along the bottom edge and a light one along the top; pips are
// small radial-shaded domes. Classic dice print the 1 and the 4 in red (as real
// Ludo dice do). The `iso*` colours drive the little isometric cube used on
// Collection cards (top / left / right faces, pips and edge ink).
//
// Names are English literals translated where shown; ids are what saves store.

import 'dart:ui';

import '../theme/colors.dart';

/// A pip's dome: lit corner and shaded rim.
class PipPaint {
  const PipPaint(this.hi, this.lo);

  final Color hi;
  final Color lo;
}

class DiceSkin {
  const DiceSkin({
    required this.id,
    required this.name,
    required this.rarity,
    required this.faceHi,
    required this.faceMid,
    required this.faceLo,
    required this.rim,
    required this.shade,
    required this.pip,
    required this.isoTop,
    required this.isoLeft,
    required this.isoRight,
    required this.isoPip,
    required this.isoPipTop,
    required this.isoInk,
    this.stops = const [0, .42, 1],
    this.focus = const Offset(.34, .28),
    this.redPip,
    this.redFaces = const {},
    this.band,
  });

  final String id;

  /// English display name ("Ruby Jelly").
  final String name;
  final LmRarity rarity;

  /// Face gradient, lit corner → middle → shaded edge.
  final Color faceHi;
  final Color faceMid;
  final Color faceLo;
  final List<double> stops;

  /// Where the light sits on the face, as a fraction of the face.
  final Offset focus;

  /// The 1.5 pt rim and the bottom inner shadow.
  final Color rim;
  final Color shade;

  /// Pip dome, and (for classic dice) the red pips used on [redFaces].
  final PipPaint pip;
  final PipPaint? redPip;
  final Set<int> redFaces;

  /// The flat-dice bottom band (tabletop / VS intro style).
  final Color? band;

  // Isometric preview colours (Collection card art).
  final Color isoTop;
  final Color isoLeft;
  final Color isoRight;
  final Color isoPip;
  final Color isoPipTop;
  final Color isoInk;

  /// The pip paint used on the face showing [value].
  PipPaint pipFor(int value) => (redPip != null && redFaces.contains(value)) ? redPip! : pip;

  Color get bandColor => band ?? Color.lerp(faceLo, const Color(0xFF000000), .12)!;
}

/// The seven dice of the game (six in the Collection, one earn-only).
abstract final class DiceSkins {
  /// The free starter: ivory with dark pips, red 1 and 4.
  static const classic = DiceSkin(
    id: 'mela_classic',
    name: 'Mela Classic',
    rarity: LmRarity.standard,
    faceHi: Color(0xFFFFFFFF),
    faceMid: Color(0xFFFFFFFF),
    faceLo: Color(0xFFDDE4EE),
    stops: [0, .55, 1],
    focus: Offset(.5, .35),
    rim: Color(0x40CDD5E1),
    shade: Color(0x383C5078),
    pip: PipPaint(Color(0xFF5A6176), Color(0xFF121726)),
    redPip: PipPaint(Color(0xFFFF7A6E), Color(0xFFB3140C)),
    redFaces: {1, 4},
    band: Color(0xFFC5CEDC),
    isoTop: Color(0xFFFFFFFF),
    isoLeft: Color(0xFFE6ECF5),
    isoRight: Color(0xFFC9D3E3),
    isoPip: Color(0xFF1B2030),
    isoPipTop: Color(0xFFE8322B),
    isoInk: Color(0xFF5E6C88),
  );

  /// Rare: translucent red with white pips (the match tray's default look).
  static const rubyJelly = DiceSkin(
    id: 'ruby_jelly',
    name: 'Ruby Jelly',
    rarity: LmRarity.rare,
    faceHi: Color(0xFFFF9B90),
    faceMid: Color(0xFFEE3B30),
    faceLo: Color(0xFFB3160E),
    rim: Color(0x405A0000),
    shade: Color(0x595A0000),
    pip: PipPaint(Color(0xFFFFFFFF), Color(0xFFF1E4E2)),
    isoTop: Color(0xFFFF6B5E),
    isoLeft: Color(0xFFE8322B),
    isoRight: Color(0xFFB11F1A),
    isoPip: Color(0xFFFFFFFF),
    isoPipTop: Color(0xFFFFFFFF),
    isoInk: Color(0xFF7A100D),
  );

  /// Rare: sea-blue glass.
  static const oceanGlass = DiceSkin(
    id: 'ocean_glass',
    name: 'Ocean Glass',
    rarity: LmRarity.rare,
    faceHi: Color(0xFFA6E8FF),
    faceMid: Color(0xFF3FB3F0),
    faceLo: Color(0xFF1C7FC8),
    rim: Color(0x400A3C82),
    shade: Color(0x590A3C82),
    pip: PipPaint(Color(0xFFFFFFFF), Color(0xFFDDF1FF)),
    isoTop: Color(0xFF9FE3FF),
    isoLeft: Color(0xFF3FB3F0),
    isoRight: Color(0xFF1C7FC8),
    isoPip: Color(0xFFFFFFFF),
    isoPipTop: Color(0xFFFFFFFF),
    isoInk: Color(0xFF0A3C82),
  );

  /// Epic: gold with brown pips, red 1 and 4.
  static const goldMohur = DiceSkin(
    id: 'gold_mohur',
    name: 'Gold Mohur',
    rarity: LmRarity.epic,
    faceHi: Color(0xFFFFF0A8),
    faceMid: Color(0xFFFFC61F),
    faceLo: Color(0xFFD98E00),
    rim: Color(0x407A3E0E),
    shade: Color(0x4D7A3E0E),
    pip: PipPaint(Color(0xFFA0622E), Color(0xFF6A3008)),
    redPip: PipPaint(Color(0xFFE04A3C), Color(0xFF8E1510)),
    redFaces: {1, 4},
    isoTop: Color(0xFFFFF0A8),
    isoLeft: Color(0xFFFFC61F),
    isoRight: Color(0xFFD98E00),
    isoPip: Color(0xFF7A3E0E),
    isoPipTop: Color(0xFFB11F1A),
    isoInk: Color(0xFF8A4B00),
  );

  /// Epic: deep indigo with gold pips (Mela Road reward).
  static const midnightGold = DiceSkin(
    id: 'midnight_gold',
    name: 'Midnight Gold',
    rarity: LmRarity.epic,
    faceHi: Color(0xFF3A4D8F),
    faceMid: Color(0xFF3A4D8F),
    faceLo: Color(0xFF121C46),
    stops: [0, .4, 1],
    focus: Offset(.5, .35),
    rim: Color(0x990A1030),
    shade: Color(0x66000000),
    pip: PipPaint(Color(0xFFFFF0A0), Color(0xFFE0A000)),
    band: Color(0xFF0A1030),
    isoTop: Color(0xFF4A5BA0),
    isoLeft: Color(0xFF26336E),
    isoRight: Color(0xFF151C48),
    isoPip: Color(0xFFFFD84A),
    isoPipTop: Color(0xFFFFD84A),
    isoInk: Color(0xFF0A0F2E),
  );

  /// Legendary: teal enamel with gold pips.
  static const peacockRoyal = DiceSkin(
    id: 'peacock_royal',
    name: 'Peacock Royal',
    rarity: LmRarity.legendary,
    faceHi: Color(0xFF7FE7E0),
    faceMid: Color(0xFF1AA6A0),
    faceLo: Color(0xFF0D6C8A),
    rim: Color(0x4D08404F),
    shade: Color(0x5908404F),
    pip: PipPaint(Color(0xFFFFF0A0), Color(0xFFE0A000)),
    isoTop: Color(0xFF7FE7E0),
    isoLeft: Color(0xFF1AA6A0),
    isoRight: Color(0xFF0D6C8A),
    isoPip: Color(0xFFFFD84A),
    isoPipTop: Color(0xFFFFD84A),
    isoInk: Color(0xFF08404F),
  );

  /// Earn-only (Mela events): a glowing paper lantern with deep red pips.
  static const melaLantern = DiceSkin(
    id: 'mela_lantern',
    name: 'Mela Lantern',
    rarity: LmRarity.legendary,
    faceHi: Color(0xFFFFEBB0),
    faceMid: Color(0xFFFF9A3D),
    faceLo: Color(0xFFC2511A),
    rim: Color(0x597A2E08),
    shade: Color(0x667A2E08),
    pip: PipPaint(Color(0xFF9A3414), Color(0xFF4A1006)),
    isoTop: Color(0xFFFFE0A0),
    isoLeft: Color(0xFFFF9A3D),
    isoRight: Color(0xFFC2511A),
    isoPip: Color(0xFF5A1E08),
    isoPipTop: Color(0xFF5A1E08),
    isoInk: Color(0xFF7A2E08),
  );

  /// Collection order.
  static const List<DiceSkin> all = [classic, rubyJelly, oceanGlass, goldMohur, midnightGold, peacockRoyal, melaLantern];

  /// The skin stored under [id], or [classic] for an unknown id.
  static DiceSkin byId(String? id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return classic;
  }
}
