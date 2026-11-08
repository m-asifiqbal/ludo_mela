// The catalogue of board skins: the six Collection boards and the eight Mela
// Tour venue boards (Classic Wood, Lantern Night, Monsoon, Sandstone, Royal,
// Ocean Reef, Frost, Neon), plus the purple Mayhem variant.
//
// Why a separate file: [BoardSkin] (board_skin.dart) is the data model; this is
// the data. Palettes come from Collection.dc.html and Venues.dc.html.

import 'dart:ui';

import '../theme/colors.dart';
import 'board_skin.dart';
import 'emblems.dart';

/// Every board skin of the game.
abstract final class BoardSkins {
  // ── Collection ────────────────────────────────────────────────────────
  /// The free starter board (also the "Classic Wood" venue).
  static final melaWood = BoardSkin(
    id: 'mela_wood',
    name: 'Mela Wood',
    frameHi: LmColors.boardFrameHi,
    frameLo: LmColors.boardFrameLo,
    frameLip: LmColors.boardFrameLip,
    frameLine: LmColors.boardFrameLine,
    ground: LmColors.boardGround,
    cell: LmColors.boardCell,
    safeCell: LmColors.safeCell,
    safeStar: LmColors.safeStar,
    seats: [
      BoardSeatColors(LmColors.red.main, LmColors.red.dark),
      BoardSeatColors(LmColors.green.main, LmColors.green.dark),
      BoardSeatColors(LmColors.yellow.main, LmColors.yellow.dark),
      BoardSeatColors(LmColors.blue.main, LmColors.blue.dark),
    ],
  );

  static final nightBazaar = BoardSkin.palette(
    id: 'night_bazaar',
    name: 'Night Bazaar',
    rarity: LmRarity.rare,
    frameHi: const Color(0xFF3A3F7A),
    frameLo: const Color(0xFF1E2150),
    frameLip: const Color(0xFF0C0E2E),
    frameLine: const Color(0xFF0A0C28),
    ground: const Color(0xFF3C4380),
    cell: const Color(0xFF2A2F62),
    safeCell: const Color(0xFF353B78),
    safeStar: const Color(0xFF8D95E0),
    green: const Color(0xFF59E08A),
    yellow: const Color(0xFFFFD84A),
    red: const Color(0xFFFF6B6B),
    blue: const Color(0xFF5CC2FF),
    centerEmblem: LmEmblems.star,
    centerEmblemColor: const Color(0xFFFFF3C4),
  );

  static final marblePalace = BoardSkin.palette(
    id: 'marble_palace',
    name: 'Marble Palace',
    rarity: LmRarity.rare,
    frameHi: const Color(0xFFF4F1EA),
    frameLo: const Color(0xFFC9C2B2),
    frameLip: const Color(0xFF7E7666),
    frameLine: const Color(0xFF8E8676),
    ground: const Color(0xFFE3DDCF),
    cell: const Color(0xFFFBF8F2),
    safeCell: const Color(0xFFECE6D8),
    safeStar: const Color(0xFFB8AE98),
    green: const Color(0xFF3CA36A),
    yellow: const Color(0xFFE3B23C),
    red: const Color(0xFFC8443C),
    blue: const Color(0xFF3A78C8),
    centerEmblem: LmEmblems.lotus,
    centerEmblemColor: const Color(0xFFFFFFFF),
  );

  static final royalPalace = BoardSkin(
    id: 'royal_palace',
    name: 'Royal Palace',
    rarity: LmRarity.epic,
    frameHi: const Color(0xFFC24A58),
    frameLo: const Color(0xFF6E1424),
    frameLip: const Color(0xFF3A0610),
    frameLine: const Color(0xFFE8B84A),
    ground: const Color(0xFFF0DFC0),
    cell: const Color(0xFFFFF8EC),
    safeCell: const Color(0xFFF6E8CC),
    safeStar: const Color(0xFFD9BE8A),
    centerEmblem: LmEmblems.crown,
    centerEmblemColor: const Color(0xFFFFD45A),
    seats: const [
      BoardSeatColors(Color(0xFFC0272D), Color(0xFF7A1218)),
      BoardSeatColors(Color(0xFF1F8A4A), Color(0xFF0E5A2C)),
      BoardSeatColors(Color(0xFFFFB800), Color(0xFFB87A00)),
      BoardSeatColors(Color(0xFF1F5FC4), Color(0xFF0E3A86)),
    ],
  );

  static final monsoonGarden = BoardSkin.palette(
    id: 'monsoon_garden',
    name: 'Monsoon Garden',
    rarity: LmRarity.epic,
    frameHi: const Color(0xFF5FBF7A),
    frameLo: const Color(0xFF2C7A45),
    frameLip: const Color(0xFF123D22),
    frameLine: const Color(0xFF1D5A33),
    ground: const Color(0xFFCDEBD5),
    cell: const Color(0xFFF1FFF4),
    safeCell: const Color(0xFFDDF3E3),
    safeStar: const Color(0xFF8CC9A0),
    green: const Color(0xFF2F9E55),
    yellow: const Color(0xFFF0C33C),
    red: const Color(0xFFE05A47),
    blue: const Color(0xFF3C8DDE),
    centerEmblem: LmEmblems.lotus,
    centerEmblemColor: const Color(0xFFFFFFFF),
  );

  static final royalDurbar = BoardSkin.palette(
    id: 'royal_durbar',
    name: 'Royal Durbar',
    rarity: LmRarity.legendary,
    frameHi: const Color(0xFFFFE27A),
    frameLo: const Color(0xFFC98A00),
    frameLip: const Color(0xFF6B4300),
    frameLine: const Color(0xFF8A5A00),
    ground: const Color(0xFFF3E3A8),
    cell: const Color(0xFFFFFBEA),
    safeCell: const Color(0xFFF7EAB8),
    safeStar: const Color(0xFFD4B04A),
    green: const Color(0xFF1F9E6E),
    yellow: const Color(0xFFF2B200),
    red: const Color(0xFFC8232C),
    blue: const Color(0xFF2259C9),
    centerEmblem: LmEmblems.crown,
    centerEmblemColor: const Color(0xFF7A3A00),
  );

  // ── Mela Tour venues (those that are not Collection boards) ───────────
  static final lanternNight = BoardSkin.palette(
    id: 'lantern_night',
    name: 'Lantern Night',
    frameHi: const Color(0xFF8A4BC8),
    frameLo: const Color(0xFF3B1D7A),
    frameLip: const Color(0xFF1E0C44),
    frameLine: const Color(0xFFFFB347),
    ground: const Color(0xFF6A3A9A),
    cell: const Color(0xFFFFEFD8),
    safeCell: const Color(0xFFF7DDB0),
    safeStar: const Color(0xFFE0A04A),
    green: const Color(0xFF4CBB5A),
    yellow: const Color(0xFFFFC83D),
    red: const Color(0xFFF0503C),
    blue: const Color(0xFF4A8CF0),
    centerEmblem: LmEmblems.moon,
    centerEmblemColor: const Color(0xFFFFE7A8),
  );

  static final sandstone = BoardSkin.palette(
    id: 'sandstone',
    name: 'Sandstone',
    frameHi: const Color(0xFFE6AA68),
    frameLo: const Color(0xFF9A5E28),
    frameLip: const Color(0xFF5A3410),
    frameLine: const Color(0xFF7A4A1E),
    ground: const Color(0xFFE2C08E),
    cell: const Color(0xFFFFF1D6),
    safeCell: const Color(0xFFF4DDB0),
    safeStar: const Color(0xFFC99A55),
    green: const Color(0xFF6AA84F),
    yellow: const Color(0xFFF2B134),
    red: const Color(0xFFD2553A),
    blue: const Color(0xFF3E86C8),
  );

  static final oceanReef = BoardSkin.palette(
    id: 'ocean_reef',
    name: 'Ocean Reef',
    frameHi: const Color(0xFF3FB8E8),
    frameLo: const Color(0xFF0A5A9A),
    frameLip: const Color(0xFF053660),
    frameLine: const Color(0xFF0A4A80),
    ground: const Color(0xFFBFE7F5),
    cell: const Color(0xFFF2FCFF),
    safeCell: const Color(0xFFD8F1FA),
    safeStar: const Color(0xFF7CC4E0),
    green: const Color(0xFF2FBF8A),
    yellow: const Color(0xFFFFC94A),
    red: const Color(0xFFFF6F61),
    blue: const Color(0xFF2F7BE0),
  );

  static final frost = BoardSkin.palette(
    id: 'frost',
    name: 'Frost',
    frameHi: const Color(0xFFF2FAFF),
    frameLo: const Color(0xFF9CC2E6),
    frameLip: const Color(0xFF5A7FA8),
    frameLine: const Color(0xFF7FA6CC),
    ground: const Color(0xFFDDEBF7),
    cell: const Color(0xFFFFFFFF),
    safeCell: const Color(0xFFE8F3FC),
    safeStar: const Color(0xFF9CC2E6),
    green: const Color(0xFF58C4A0),
    yellow: const Color(0xFFF2D15C),
    red: const Color(0xFFE8667A),
    blue: const Color(0xFF4B8EE8),
    centerEmblem: LmEmblems.star,
    centerEmblemColor: const Color(0xFFFFFFFF),
  );

  static final neon = BoardSkin.palette(
    id: 'neon',
    name: 'Neon',
    frameHi: const Color(0xFF4A1A8A),
    frameLo: const Color(0xFF12043A),
    frameLip: const Color(0xFF070120),
    frameLine: const Color(0xFFFF3FA4),
    ground: const Color(0xFF2A0A5A),
    cell: const Color(0xFF170A3E),
    cellEdge: const Color(0xFF5A2AB0),
    safeCell: const Color(0xFF241058),
    safeStar: const Color(0xFFFF8AD0),
    green: const Color(0xFF33F58A),
    yellow: const Color(0xFFFFE14A),
    red: const Color(0xFFFF4D6D),
    blue: const Color(0xFF3FC8FF),
    centerEmblem: LmEmblems.star,
    centerEmblemColor: const Color(0xFFFF8AD0),
  );

  /// The six Collection boards, in card order.
  static final List<BoardSkin> collection = [melaWood, nightBazaar, marblePalace, royalPalace, monsoonGarden, royalDurbar];

  /// The eight Mela Tour venue boards, in venue order (Classic Wood, Lantern
  /// Night, Monsoon, Sandstone, Royal, Ocean Reef, Frost, Neon).
  static final List<BoardSkin> venues = [melaWood, lanternNight, monsoonGarden, sandstone, royalPalace, oceanReef, frost, neon];

  /// Every distinct skin.
  static final List<BoardSkin> all = [...collection, lanternNight, sandstone, oceanReef, frost, neon];

  static final Map<String, BoardSkin> _byId = {
    for (final s in all) s.id: s,
    'classic_wood': melaWood,
    'monsoon': monsoonGarden,
    'royal': royalPalace,
  };

  /// The skin stored under [id] (venue aliases included), or [melaWood].
  static BoardSkin byId(String? id) => _byId[id] ?? melaWood;

  static final Map<String, BoardSkin> _mayhem = {};

  /// The Mayhem look of [skin]: a purple frame with a gold rim (Mayhem board).
  /// One instance per skin, so [BoardPainter] does not see a "new" skin on every rebuild.
  static BoardSkin mayhem(BoardSkin skin) => _mayhem.putIfAbsent(skin.id, () => _mayhemOf(skin));

  static BoardSkin _mayhemOf(BoardSkin skin) => skin.copyWith(
        id: '${skin.id}+mayhem',
        frameHi: const Color(0xFFC49BFF),
        frameMid: const Color(0xFF7A45E6),
        frameLo: const Color(0xFF3E1A8E),
        frameAngle: 145,
        frameLip: const Color(0xFF241060),
        frameLipDepth: 8,
        frameLine: const Color(0xFFFFD45A),
        frameRim: const Color(0xFFFFD45A),
      );
}
