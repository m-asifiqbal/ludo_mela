// The "Quick break" card that sits behind a break ad (board C: "shown behind a
// 'Quick break' card"). A break ad never appears out of nowhere: the card says
// what is about to happen, then the ad opens over it and the card closes with it.
//
// This is the default look, built from the app theme only. The results wave can
// pass its own design-kit version to `AdService.maybeShowBreak(cardBuilder:)`.

import 'package:flutter/material.dart';

import '../l10n/tr.dart';

class QuickBreakCard extends StatelessWidget {
  const QuickBreakCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('Quick break'), textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                tr('A short ad, then back to the mela.'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 2),
                  child: Text(tr('Ad'), style: theme.textTheme.labelMedium),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
