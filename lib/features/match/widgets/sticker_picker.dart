// Stickers and quick chat: the picker above the tool row and the bubble beside an avatar.
//
// Six stickers (happy · laugh · wow · cool · angry · cry) and four phrases ("Well played!", "Oops!", "Hurry up!",
// "Good luck!") in a 250 pt panel (Match.dc.html). A phrase travels as its English text and is translated by
// whoever shows it; a sticker travels as its id. The bubble is a white card with a paper lip that lives 1.8 s.

import 'package:flutter/widgets.dart';

import '../../../core/feedback/feedback.dart' show Sfx;
import '../../../core/l10n/tr.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/gloss.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/widgets.dart';
import '../match_motion.dart';
import '../session/match_session.dart';

/// The quick-chat phrases (their English text is what is sent).
const kPhrases = ['Well played!', 'Oops!', 'Hurry up!', 'Good luck!'];

Glyph stickerGlyph(String id) => switch (id) {
  Stickers.happy => LmGlyphs.stickerHappy,
  Stickers.laugh => LmGlyphs.stickerLaugh,
  Stickers.wow => LmGlyphs.stickerWow,
  Stickers.cool => LmGlyphs.stickerCool,
  Stickers.angry => LmGlyphs.stickerAngry,
  _ => LmGlyphs.stickerCry,
};

String stickerLabel(String id) => switch (id) {
  Stickers.happy => tr('Happy sticker'),
  Stickers.laugh => tr('Laughing sticker'),
  Stickers.wow => tr('Wow sticker'),
  Stickers.cool => tr('Cool sticker'),
  Stickers.angry => tr('Angry sticker'),
  _ => tr('Crying sticker'),
};

String phraseText(String phrase) => switch (phrase) {
  'Well played!' => tr('Well played!'),
  'Oops!' => tr('Oops!'),
  'Hurry up!' => tr('Hurry up!'),
  'Good luck!' => tr('Good luck!'),
  _ => phrase,
};

class StickerPicker extends StatelessWidget {
  const StickerPicker({super.key, required this.onPick});

  /// Called with a sticker id or a phrase.
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Semantics(
    label: tr('Stickers and quick chat'),
    container: true,
    child: LmBox(
      width: 250,
      radius: 20,
      gradient: const LmGradient([LmColors.pnlHi, LmColors.pnlLo]),
      shadows: const [
        LmShadow.rim(LmColors.pnlRim, 3),
        LmShadow(LmColors.pnlLip, dy: 8),
        LmShadow(LmGloss.softShadowColor, dy: 16, blur: 30),
      ],
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final id in Stickers.all)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Pressable(
                      onTap: () => onPick(id),
                      semanticLabel: stickerLabel(id),
                      sfx: Sfx.pop,
                      child: LmBox(
                        radius: 12,
                        color: LmColors.white.withValues(alpha: .12),
                        height: 44,
                        child: Center(child: LmIcon(stickerGlyph(id), size: 24)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in kPhrases)
                SizedBox(
                  width: 107,
                  child: GlossButton(onTap: () => onPick(p), kind: GlossKind.navy, size: GlossSize.s, label: phraseText(p), expand: true, padding: const EdgeInsets.symmetric(horizontal: 6)),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// What somebody said, in a white card.
class StickerBubble extends StatelessWidget {
  const StickerBubble({super.key, required this.message});

  final StickerMessage message;

  @override
  Widget build(BuildContext context) {
    final sticker = Stickers.isSticker(message.sticker);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .6, end: 1),
      duration: MatchMotion.bubbleIn,
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(opacity: ((v - .6) / .3).clamp(0.0, 1.0), child: Transform.scale(scale: v, child: child)),
      child: Semantics(
        liveRegion: true,
        label: sticker ? stickerLabel(message.sticker) : phraseText(message.sticker),
        child: ExcludeSemantics(
          child: LmBox(
            radius: 12,
            color: LmColors.paper,
            shadows: const [LmShadow(LmColors.paperLip, dy: 4), LmShadow(LmGloss.softShadowColor, dy: 8, blur: 14)],
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              widthFactor: 1,
              child: sticker ? LmIcon(stickerGlyph(message.sticker), size: 24) : Text(phraseText(message.sticker), style: LmText.plain(14, color: LmColors.navy), maxLines: 1, softWrap: false),
            ),
          ),
        ),
      ),
    );
  }
}
