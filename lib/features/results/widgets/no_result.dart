// What a results screen shows when nothing was recorded (a stale link, a restored route): a short
// note and one button back to the lobby.
//
// Why not redirect on the spot: the route table is walked by the router test, and a screen that
// leaves by itself cannot be "reached". A button costs the player one tap on a path they should
// never be on, and Android back does the same thing, so nobody is stuck.
//
// Both /result and /report read `matchResultProvider`; with no match in it there is nothing true to
// show, and the lobby is the one place that always makes sense.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/backdrops.dart';
import '../../../core/widgets/gloss_button.dart';
import '../../../core/widgets/outlined_text.dart';

class NoResultView extends StatelessWidget {
  const NoResultView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: LmColors.deep,
        body: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.go(Routes.lobby);
          },
          child: ScreenBackdrop(
            spec: BackdropSpec.screen,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedText(tr('No match to show yet'), size: 24, textAlign: TextAlign.center, maxLines: 2),
                      const SizedBox(height: 20),
                      GlossButton(
                        label: tr('Back to the lobby'),
                        kind: GlossKind.green,
                        size: GlossSize.l,
                        onTap: () => context.go(Routes.lobby),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
