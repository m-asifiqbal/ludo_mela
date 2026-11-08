// ToolRow: the thumb row at the bottom of the match — Hint, what to do next, stickers, menu (Match.dc.html).
//
// Hint (green; dim when none is left or it is not your move) shows "Hint ×3" (unlimited in practice) and is
// absent where hints are off (coin tables unless Settings allow them, Wi-Fi rooms, the puzzle). The middle says
// what to do ("Tap the dice to roll", "Tap a piece with a ring", "Raja is playing…") or, when a roll cannot be
// played and the game waits for you, offers PASS. The gold sticker button opens the picker (hidden when Parent
// controls turn stickers off); the menu button opens the pause menu.

import 'package:flutter/widgets.dart';

import '../../../core/art/art.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/gloss_button.dart';
import '../match_controller.dart';
import '../match_texts.dart';

class ToolRow extends StatelessWidget {
  const ToolRow({super.key, required this.c});

  final MatchController c;

  /// Height of the buttons (the tool size).
  static const double height = 42;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final settings = c.env.settings();
      final left = c.hintsLeft;
      final canHint = c.canHint;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (c.hintsAllowed) ...[
              GlossButton(
                onTap: canHint ? c.useHint : null,
                kind: canHint ? GlossKind.green : GlossKind.dim,
                size: GlossSize.tool,
                icon: LmIcons.bulb,
                label: left == null ? tr('Hint') : tr('Hint ×{n}', {'n': left}),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: c.canPass
                  ? Center(child: GlossButton(onTap: c.pass, kind: GlossKind.gold, size: GlossSize.tool, label: tr('PASS')))
                  : Text(c.status, textAlign: TextAlign.center, maxLines: 2, style: LmText.bodyAt(12, color: LmColors.textPale, height: 1.3)),
            ),
            if (settings.stickersAllowed && !c.setup.puzzle) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: GlossButton(
                  onTap: c.toggleStickers,
                  kind: GlossKind.gold,
                  size: GlossSize.tool,
                  icon: LmGlyphs.stickerHappy,
                  iconSize: 24,
                  semanticLabel: tr('Stickers and quick chat'),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
            const SizedBox(width: 8),
            SizedBox(
              width: 50,
              child: GlossButton(
                onTap: c.openPause,
                kind: GlossKind.steel,
                size: GlossSize.tool,
                icon: LmIcons.menu,
                iconSize: 22,
                semanticLabel: tr('Menu'),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      );
    },
  );
}
