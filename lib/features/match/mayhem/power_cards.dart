// The look and words of the six Mela Mayhem power cards (Mayhem.dc.html, board B "cards").
//
// Colours come from the kit's gloss families (Swap pink, Double gold, Hop +3 green, Freeze blue, Reroll purple)
// and the shield glow (Shield teal); the glyphs are the kit's. Words go through tr() with literals here, so the
// toasts, the hand and the pause rules share one spelling.

import 'dart:ui';

import 'package:ludo_engine/ludo_engine.dart' show MelaEventKind, PowerCard;

import '../../../core/art/glyph.dart' show Glyph;
import '../../../core/art/glyph_extras.dart' show LmIcons;
import '../../../core/l10n/tr.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/gloss.dart';

/// The colours of one card face.
class CardLook {
  const CardLook(this.gradient, this.edge);

  final LmGradient gradient;
  final Color edge;
}

CardLook _gloss(LmGloss g) => CardLook(LmGradient([g.hi, g.lo], angle: 160), g.lip);

/// Face and edge colours of [card].
CardLook cardLook(PowerCard card) => switch (card) {
  PowerCard.shield => CardLook(
    LmGradient([LmColors.shieldGlow, Color.lerp(LmColors.shieldGlow, LmColors.navy, .5)!], angle: 160),
    Color.lerp(LmColors.shieldGlow, LmColors.navy, .78)!,
  ),
  PowerCard.double => _gloss(LmGloss.gold),
  PowerCard.hop3 => _gloss(LmGloss.green),
  PowerCard.swap => _gloss(LmGloss.pink),
  PowerCard.freeze => _gloss(LmGloss.blue),
  PowerCard.reroll => _gloss(LmGloss.purple),
};

Glyph cardGlyph(PowerCard card) => switch (card) {
  PowerCard.shield => LmIcons.shield,
  PowerCard.double => LmIcons.double2,
  PowerCard.hop3 => LmIcons.hop,
  PowerCard.swap => LmIcons.swap,
  PowerCard.freeze => LmIcons.freeze,
  PowerCard.reroll => LmIcons.reroll,
};

String cardName(PowerCard card) => switch (card) {
  PowerCard.shield => tr('SHIELD'),
  PowerCard.double => tr('DOUBLE'),
  PowerCard.hop3 => tr('HOP +3'),
  PowerCard.swap => tr('SWAP'),
  PowerCard.freeze => tr('FREEZE'),
  PowerCard.reroll => tr('REROLL'),
};

/// One line on what the card does.
String cardText(PowerCard card) => switch (card) {
  PowerCard.shield => tr('Safe from capture for 2 rounds'),
  PowerCard.double => tr('Roll two dice; use one or both'),
  PowerCard.hop3 => tr('Move any of your pieces 3 squares'),
  PowerCard.swap => tr('Trade places with a rival up to 6 ahead'),
  PowerCard.freeze => tr('One rival piece skips its next move'),
  PowerCard.reroll => tr('Roll again once this turn'),
};

/// What to do after pressing USE (cards that need a target).
String cardTargetHint(PowerCard card) => switch (card) {
  PowerCard.shield => tr('Tap the piece to protect.'),
  PowerCard.hop3 => tr('Tap the piece to hop.'),
  PowerCard.swap => tr('Tap your piece, then a rival piece up to 6 squares ahead.'),
  PowerCard.freeze => tr('Tap a rival piece to freeze.'),
  PowerCard.double || PowerCard.reroll => '',
};

/// Needs a piece to be picked.
bool cardNeedsTarget(PowerCard card) => card != PowerCard.double && card != PowerCard.reroll;

/// The Mela event banner: title and one line on the effect.
String eventTitle(MelaEventKind kind) => switch (kind) {
  MelaEventKind.luckyHour => tr('LUCKY HOUR!'),
  MelaEventKind.monsoon => tr('MONSOON!'),
  MelaEventKind.fog => tr('FOG!'),
  MelaEventKind.festivalLights => tr('FESTIVAL LIGHTS!'),
};

String eventText(MelaEventKind kind) => switch (kind) {
  MelaEventKind.luckyHour => tr('Captures give 2 extra rolls'),
  MelaEventKind.monsoon => tr('Star squares drift one square forward each round'),
  MelaEventKind.fog => tr('Threat marks and RISKY tags are hidden'),
  MelaEventKind.festivalLights => tr('Double chest coins'),
};

/// Banner colours: Lucky hour pink (as in the artboard), the others from the gloss families.
LmGloss eventGloss(MelaEventKind kind) => switch (kind) {
  MelaEventKind.luckyHour => LmGloss.pink,
  MelaEventKind.monsoon => LmGloss.blue,
  MelaEventKind.fog => LmGloss.grey,
  MelaEventKind.festivalLights => LmGloss.gold,
};
