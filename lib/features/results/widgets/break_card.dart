// The "Quick break" card in the design kit's look: what the player sees for a moment before a
// break ad opens, so an ad never appears out of nowhere (board C).
//
// Passed to `AdService.maybeShowBreak(cardBuilder:)` by the results screens; the service shows it
// in a modal dialog, keeps it behind the ad and closes it afterwards. It centres itself because a
// dialog route does not, and sits on a transparent Material because the dialog route has none: a
// bare Text there would be drawn with Flutter's red-and-yellow "no Material" fallback style.

import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../core/widgets/panel.dart';

class BreakCard extends StatelessWidget {
  const BreakCard({super.key});

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: Center(
          child: Semantics(
            liveRegion: true,
            child: Panel(
              tone: PanelTone.modal,
              width: 300,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedText(tr('Quick break'), size: 28, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    tr('A short ad, then back to the mela.'),
                    textAlign: TextAlign.center,
                    style: LmText.bodyAt(14, color: LmColors.textPale),
                  ),
                  const SizedBox(height: 12),
                  Well(
                    radius: 8,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    child: Text(tr('Ad'), style: LmText.caption),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
