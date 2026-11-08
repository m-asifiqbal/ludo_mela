// Board skins: the paint of the wooden board — frame, grid, squares, yards and
// the home triangles — for every board of the Collection and every Mela Tour
// venue (boards "Collection", "Venues", "TryOn", "Mayhem").
//
// A skin changes colours only; the geometry is the one fixed 15 × 15 plan. Seat
// colours are part of a skin (yards and lanes take the skin's palette, so the
// Royal board has a deeper green and the Neon board an electric one), but the
// coins on top always use the fixed seat colours (LmColors.seat).
//
// Names are English literals translated where shown; ids are what saves store.
// Venue boards "Classic Wood", "Monsoon" and "Royal" are the Collection's Mela
// Wood, Monsoon Garden and Royal Palace (aliases in [BoardSkins.byId]).

import 'dart:ui';

import 'engine_geometry.dart';

import '../theme/colors.dart';

/// One seat's colours on a board: the flat yard / lane colour and the darker
/// inner yard square (and the star on its start square).
class BoardSeatColors {
  const BoardSeatColors(this.main, this.dark);

  /// A seat palette from just the [main] colour: the dark tone is [main] shaded 24 %.
  factory BoardSeatColors.shaded(Color main, [double amount = .24]) =>
      BoardSeatColors(main, Color.lerp(main, const Color(0xFF000000), amount)!);

  final Color main;
  final Color dark;
}

class BoardSkin {
  BoardSkin({
    required this.id,
    required this.name,
    required this.frameHi,
    required this.frameLo,
    required this.frameLip,
    required this.ground,
    required this.cell,
    required this.safeCell,
    required this.safeStar,
    required List<BoardSeatColors> seats,
    this.rarity = LmRarity.standard,
    this.frameMid,
    this.frameAngle = 180,
    this.frameLine = const Color(0xFF6E3F14),
    this.frameRim,
    this.frameLipDepth = 4,
    this.cellEdge,
    this.centerEmblem,
    this.centerEmblemColor = const Color(0xFFFFD45A),
  })  : assert(seats.length == 4, 'a skin needs red, green, yellow and blue'),
        seats = List.unmodifiable(seats);

  /// Palette in the order of the Collection cards: green, yellow, red, blue.
  factory BoardSkin.palette({
    required String id,
    required String name,
    required Color frameHi,
    required Color frameLo,
    required Color frameLip,
    required Color ground,
    required Color cell,
    required Color safeCell,
    required Color safeStar,
    required Color green,
    required Color yellow,
    required Color red,
    required Color blue,
    LmRarity rarity = LmRarity.standard,
    Color frameLine = const Color(0xFF6E3F14),
    Color? frameRim,
    Color? cellEdge,
    String? centerEmblem,
    Color centerEmblemColor = const Color(0xFFFFD45A),
    double darkAmount = .24,
  }) =>
      BoardSkin(
        id: id,
        name: name,
        rarity: rarity,
        frameHi: frameHi,
        frameLo: frameLo,
        frameLip: frameLip,
        frameLine: frameLine,
        frameRim: frameRim,
        ground: ground,
        cell: cell,
        cellEdge: cellEdge,
        safeCell: safeCell,
        safeStar: safeStar,
        centerEmblem: centerEmblem,
        centerEmblemColor: centerEmblemColor,
        seats: [
          BoardSeatColors.shaded(red, darkAmount),
          BoardSeatColors.shaded(green, darkAmount),
          BoardSeatColors.shaded(yellow, darkAmount),
          BoardSeatColors.shaded(blue, darkAmount),
        ],
      );

  /// Stable id stored in saves ("mela_wood", "royal_palace" …).
  final String id;

  /// English display name ("Mela Wood").
  final String name;
  final LmRarity rarity;

  // ── Frame ─────────────────────────────────────────────────────────────
  /// Frame gradient (top → bottom at [frameAngle]; [frameMid] at 45 % if given).
  final Color frameHi;
  final Color frameLo;
  final Color? frameMid;
  final double frameAngle;

  /// The solid lip under the frame ([frameLipDepth] pt) and the 1.5 pt line
  /// between the frame and the grid.
  final Color frameLip;
  final double frameLipDepth;
  final Color frameLine;

  /// An extra rim just inside the frame edge (Mayhem's gold line).
  final Color? frameRim;

  // ── Grid ──────────────────────────────────────────────────────────────
  /// The ground that shows as 1 pt grid lines between squares.
  final Color ground;

  /// A road square, and the safe squares (stars).
  final Color cell;
  final Color safeCell;
  final Color safeStar;

  /// An optional 1 pt edge drawn inside every road square (the Neon board).
  final Color? cellEdge;

  /// Colours per seat, indexed by `Seat.index` (red, green, yellow, blue).
  final List<BoardSeatColors> seats;

  /// An emblem (24-box path) drawn over the four home triangles, e.g. a crown.
  final String? centerEmblem;
  final Color centerEmblemColor;

  /// This seat's palette on this board.
  BoardSeatColors seat(Seat s) => seats[s.index];

  /// A copy with the given fields replaced (the Mayhem board reuses a skin
  /// with a purple frame).
  BoardSkin copyWith({
    String? id,
    Color? frameHi,
    Color? frameLo,
    Color? frameMid,
    double? frameAngle,
    Color? frameLip,
    double? frameLipDepth,
    Color? frameLine,
    Color? frameRim,
  }) =>
      BoardSkin(
        id: id ?? this.id,
        name: name,
        rarity: rarity,
        frameHi: frameHi ?? this.frameHi,
        frameLo: frameLo ?? this.frameLo,
        frameMid: frameMid ?? this.frameMid,
        frameAngle: frameAngle ?? this.frameAngle,
        frameLip: frameLip ?? this.frameLip,
        frameLipDepth: frameLipDepth ?? this.frameLipDepth,
        frameLine: frameLine ?? this.frameLine,
        frameRim: frameRim ?? this.frameRim,
        ground: ground,
        cell: cell,
        safeCell: safeCell,
        safeStar: safeStar,
        cellEdge: cellEdge,
        seats: seats,
        centerEmblem: centerEmblem,
        centerEmblemColor: centerEmblemColor,
      );
}
