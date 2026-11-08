// Colour tokens (design board A §1): surfaces, seats, board, money, status.
//
// Why constants here: screens never hard-code a colour; they read these. Player
// colours are fixed by seat and never re-themed (colour-blind patterns back
// them up). Gradients run top → bottom: hi (top), mid (55 %), lo (bottom); the
// "lip" is the solid 3D edge under a button or card.

import 'dart:ui';

import '../art/engine_geometry.dart';

/// The four colours of one seat: the flat yard / lane colour ([main]), the
/// darker inner yard square and coin rim ([dark]), the coin highlight
/// ([light]) and the coin side band ([side]).
class LmSeatColors {
  const LmSeatColors({required this.main, required this.dark, required this.light, required this.side});

  final Color main;
  final Color dark;
  final Color light;
  final Color side;
}

/// A raised tile palette: gradient top / bottom, inner rim, solid lip, and an
/// optional awning-stripe colour (lobby stall tiles).
class LmTileColors {
  const LmTileColors(this.top, this.bottom, this.rim, this.lip, [this.stripe]);

  final Color top;
  final Color bottom;
  final Color rim;
  final Color lip;
  final Color? stripe;
}

/// Collection rarity frame colours (board A §4).
class LmRarityColors {
  const LmRarityColors(this.name, this.top, this.bottom, this.rim, this.lip);

  final String name;
  final Color top;
  final Color bottom;
  final Color rim;
  final Color lip;
}

abstract final class LmColors {
  // ── Surfaces ──────────────────────────────────────────────────────────
  /// Header sky gradient and its lip.
  static const skyHi = Color(0xFF63D6FF);
  static const skyLo = Color(0xFF2AA6F0);
  static const skyLip = Color(0xFF0E78C2);

  /// Ground gradient (screen backdrop).
  static const royalHi = Color(0xFF3EA2FF);
  static const royalLo = Color(0xFF1659C4);
  static const deep = Color(0xFF0F45A6);

  /// Modal panel gradient, rim and lip (`.sec` on board A).
  static const panelHi = Color(0xFF2C7BDA);
  static const panelLo = Color(0xFF1B57B4);
  static const panelRim = Color(0xFF5FB0FF);
  static const panelLip = Color(0xFF0A2A6B);

  /// In-screen panel gradient (`.pnl` on the screen boards): rim and lip.
  static const pnlHi = Color(0xFF2064CC);
  static const pnlLo = Color(0xFF1549A6);
  static const pnlRim = Color(0xFF3F86EA);
  static const pnlLip = Color(0xFF0A2E70);

  /// Purple panel (Mayhem).
  static const pnlPurpleHi = Color(0xFF6A3FD8);
  static const pnlPurpleLo = Color(0xFF4A22A8);
  static const pnlPurpleRim = Color(0xFF9B6BFF);
  static const pnlPurpleLip = Color(0xFF241060);

  /// Raised card (board A §3): gradient, rim, lip.
  static const cardHi = Color(0xFF2D7AD6);
  static const cardLo = Color(0xFF1B5BB8);
  static const cardRim = Color(0xFF4C9AF0);
  static const cardLip = Color(0xFF0C3A86);

  /// Sunken well (values, trays) and its purple twin.
  static const well = Color(0xFF0D3680);
  static const wellPurple = Color(0xFF2A0F6E);

  /// Darker track behind currency pills and bars.
  static const pillTrack = Color(0xFF14336E);
  static const pillTrackRing = Color(0xFF0E2A5E);

  /// Bottom dock / nav.
  static const navHi = Color(0xFF2068C8);
  static const navLo = Color(0xFF123E92);
  static const dockHi = Color(0xFF123A8A);
  static const dockLo = Color(0xFF0A2464);
  static const dockRim = Color(0x738FB6FF); // rgba(143,182,255,.45)

  /// The navy ink of every outline, tray and drop line.
  static const navy = Color(0xFF0A2A6B);

  /// Night sky of the lobby.
  static const night0 = Color(0xFF0B2466);
  static const night1 = Color(0xFF143A96);
  static const night2 = Color(0xFF2462CF);
  static const night3 = Color(0xFF2E74E0);

  /// Modal scrim rgba(4,14,40,.72).
  static const scrim = Color(0xB8040E28);

  // ── Text ──────────────────────────────────────────────────────────────
  static const white = Color(0xFFFFFFFF);

  /// Dark brown ink used on gold surfaces.
  static const inkOnGold = Color(0xFF5A2E00);

  /// Warm cream label on wood planks.
  static const cream = Color(0xFFFFF3D6);
  static const plankInk = Color(0xFF4A2008);

  /// Body copy tones on blue.
  static const textSoft = Color(0xFFCFE3FF);
  static const textPale = Color(0xFFDDEEFF);
  static const textDim = Color(0xFF9DB4D8);
  static const textLabel = Color(0xFF9CC2FF);

  /// XP / reward text.
  static const xpText = Color(0xFFFFE27A);

  // ── Badges ────────────────────────────────────────────────────────────
  /// Act now.
  static const badgeRed = Color(0xFFF2463B);

  /// A count of new things / ok.
  static const badgeGreen = Color(0xFF47BA2B);

  // ── Seats (fixed by seat; board A §1 "Seats") ─────────────────────────
  static const red = LmSeatColors(
    main: Color(0xFFE8322B),
    dark: Color(0xFFB11F1A),
    light: Color(0xFFFF8A7E),
    side: Color(0xFF7A100D),
  );
  static const green = LmSeatColors(
    main: Color(0xFF76BE2E),
    dark: Color(0xFF55961C),
    light: Color(0xFFBDEB7E),
    side: Color(0xFF356A0E),
  );
  static const yellow = LmSeatColors(
    main: Color(0xFFF8C21C),
    dark: Color(0xFFD29A12),
    light: Color(0xFFFFE98A),
    side: Color(0xFF946600),
  );
  static const blue = LmSeatColors(
    main: Color(0xFF1E8BEA),
    dark: Color(0xFF1265C2),
    light: Color(0xFF86CBFF),
    side: Color(0xFF0A3C82),
  );

  /// The palette of [seat].
  static LmSeatColors seat(Seat seat) => switch (seat) {
        Seat.red => red,
        Seat.green => green,
        Seat.yellow => yellow,
        Seat.blue => blue,
      };

  // ── Board ─────────────────────────────────────────────────────────────
  static const boardFrameHi = Color(0xFFEBB984);
  static const boardFrameLo = Color(0xFFBE7F44);
  static const boardFrameLip = Color(0xFF5E3410);
  static const boardFrameLine = Color(0xFF6E3F14);
  static const boardGround = Color(0xFFD2D2D2);
  static const boardCell = Color(0xFFFFFFFF);
  static const safeCell = Color(0xFFCFCFCF);
  static const safeStar = Color(0xFFA0A0A0);
  static const boardRimGold = Color(0xFFFFD45A);

  // ── Money ─────────────────────────────────────────────────────────────
  static const coinHi = Color(0xFFFFEC8F);
  static const coinMid = Color(0xFFFFC21F);
  static const coinLo = Color(0xFFE08A00);
  static const coinLip = Color(0xFFB86E00);
  static const coinFace = Color(0xFFFFAE00);
  static const coinFaceRim = Color(0xFFFFE680);
  static const gemHi = Color(0xFFFF6CC0);
  static const gemMid = Color(0xFFF0328F);
  static const gemLo = Color(0xFFC2186D);

  // ── Wood (plank wallet, board frame) ──────────────────────────────────
  static const plankHi = Color(0xFFB8763A);
  static const plankMid = Color(0xFF8A4B1E);
  static const plankLo = Color(0xFF6B3410);
  static const plankRim = Color(0xFFD9A066);
  static const plankLip = Color(0xFF3E1A06);

  // ── Awning ────────────────────────────────────────────────────────────
  static const awningRed = Color(0xFFE8322B);
  static const awningCream = Color(0xFFFFF1D0);

  // ── Lobby tiles (Main.dc.html) ────────────────────────────────────────
  static const stallCoins = LmTileColors(Color(0xFFFF8A3D), Color(0xFFE8661E), Color(0xFFFFC08A), Color(0xFF9A3A08), Color(0xFFE8661E));
  static const stallWheel = LmTileColors(Color(0xFF2FB8C8), Color(0xFF168A98), Color(0xFF8FE6EE), Color(0xFF0B5560), Color(0xFF0F8C9A));
  static const stallGift = LmTileColors(Color(0xFFF0577A), Color(0xFFC8264E), Color(0xFFFFB0C2), Color(0xFF7E0B2C), Color(0xFFC8264E));
  static const stallMissions = LmTileColors(Color(0xFF4CBF3E), Color(0xFF2E9A1B), Color(0xFFB9F58A), Color(0xFF1D6B0F), Color(0xFF2E9A1B));

  static const modePass = LmTileColors(Color(0xFF5BB8FF), Color(0xFF1F6FD6), Color(0xFFA8DBFF), Color(0xFF0D3C86));
  static const modeWifi = LmTileColors(Color(0xFF6EDB5A), Color(0xFF2E9A1B), Color(0xFFC2F7A6), Color(0xFF1D6B0F));
  static const modeMayhem = LmTileColors(Color(0xFFC49BFF), Color(0xFF6A35D6), Color(0xFFE3CCFF), Color(0xFF3E1A8E));
  static const modePuzzle = LmTileColors(Color(0xFFFF9AC8), Color(0xFFE0407E), Color(0xFFFFD0E4), Color(0xFF8E0F4D));

  /// The big orange VS-computer PLAY tile (135°, three stops).
  static const playTop = Color(0xFFFFD24A);
  static const playMid = Color(0xFFFFA51F);
  static const playBottom = Color(0xFFF07800);
  static const playRim = Color(0xFFFFE89A);
  static const playLip = Color(0xFF9A4A00);

  // ── Rarity (Collection) ───────────────────────────────────────────────
  static const standard = LmRarityColors('Standard', Color(0xFF56AEF7), Color(0xFF2470CF), Color(0xFFA6D8FF), Color(0xFF0D4A9E));
  static const rare = LmRarityColors('Rare', Color(0xFFFFB64D), Color(0xFFEE7A0E), Color(0xFFFFDDA6), Color(0xFF9A4A00));
  static const epic = LmRarityColors('Epic', Color(0xFFFF7C6C), Color(0xFFD6302A), Color(0xFFFFC4BA), Color(0xFF7E120B));
  static const legendary = LmRarityColors('Legendary', Color(0xFFC99BFF), Color(0xFF7B37D6), Color(0xFFE6D0FF), Color(0xFF3E1A8E));

  /// Progress / stat fills.
  static const barGreenHi = Color(0xFFA3F06A);
  static const barGreenLo = Color(0xFF47BA2B);
  static const barGoldHi = Color(0xFFFFF3B0);
  static const barGoldLo = Color(0xFFFFC61F);
  static const barTrack = Color(0x59000000); // rgba(0,0,0,.35)
  static const barTrackSoft = Color(0x4D000000); // rgba(0,0,0,.3)

  /// Turn timer pie: green → gold (55 %) → red (85 %).
  static const pieGreen = Color(0xFF47BA2B);
  static const pieGold = Color(0xFFFFC61F);
  static const pieRed = Color(0xFFF2463B);

  /// Avatar frames: your turn / waiting.
  static const frameActive = Color(0xFFFFC61F);
  static const frameWaiting = Color(0xFF2B78D6);

  /// The pink "2 players" swatch of board A §1 (the Party button itself uses
  /// [LmGloss.pink]): hi → lo and its lip.
  static const pinkHi = Color(0xFFFF5E8E);
  static const pinkLo = Color(0xFFC4143F);
  static const pinkLip = Color(0xFF7E0B2C);

  /// Mela bunting / bulb colours (splash lights, venue cards, awning bulbs).
  static const List<Color> bunting = [
    Color(0xFFFFE27A),
    Color(0xFFFF6CC0),
    Color(0xFF7DF0E4),
    Color(0xFF8DEB50),
    Color(0xFFFFB02E),
  ];

  /// Confetti paper colours (the Win board).
  static const List<Color> confetti = [
    Color(0xFFFFC61F),
    Color(0xFFFF3FA4),
    Color(0xFF47BA2B),
    Color(0xFF2F95F2),
    Color(0xFFFFFFFF),
    Color(0xFFF2463B),
  ];

  /// Pale ink on the paper-white chips (mini dice, speech bubbles) and their lip.
  static const paper = Color(0xFFFFFFFF);
  static const paperLip = Color(0xFF9FB4D6);
  static const paperInk = Color(0xFF1B2030);

  /// The move-preview colours: capture / home / safe / risky tags.
  static const tagCapture = Color(0xFFF2463B);
  static const tagHome = Color(0xFF47BA2B);
  static const tagSafe = Color(0xFF2F95F2);
  static const tagRisky = Color(0xFFF59E00);

  /// Hint glow around the piece the helper suggests.
  static const hintGlow = Color(0xFF7DF0E4);

  /// Shield / freeze power-card colours (Mela Mayhem).
  static const shieldGlow = Color(0xFF7DF0E4);
  static const freezeInk = Color(0xFF1A62C4);

  /// The jali (lattice) pattern ink over every screen background.
  static const jali = Color(0x12FFFFFF); // white at .07
}

/// The four collection rarities (board A §4): frame colours come from
/// [LmColors.standard] … [LmColors.legendary].
enum LmRarity {
  standard,
  rare,
  epic,
  legendary;

  /// The frame colours of this rarity.
  LmRarityColors get colors => switch (this) {
        LmRarity.standard => LmColors.standard,
        LmRarity.rare => LmColors.rare,
        LmRarity.epic => LmColors.epic,
        LmRarity.legendary => LmColors.legendary,
      };

  /// English label ("Legendary"); translate with `tr(rarity.label)` where shown.
  String get label => colors.name;
}
