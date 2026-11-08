// A stand-in for a screen that has not been built yet.
//
// Why: the router registers EVERY path of the architecture from day one, so the
// whole navigation graph (tabs, drill-ins, back button, transitions) can be run
// and tested before the features land. A feature replaces its placeholder by
// editing one line in core/router/app_router.dart. Development only: nothing
// here is meant to ship, so the text is English and not translated.
//
// A placeholder may list [links] — shortcuts to other routes — so a developer
// can walk the navigation graph on a device (the splash links to the lobby, the
// lobby links to every drill-in).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';

/// A shortcut button on a placeholder: [label] opens [location].
typedef PlaceholderLink = (String label, String location);

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.title, {super.key, this.detail, this.links = const []});

  /// The screen's name, e.g. "Daily gift".
  final String title;

  /// Anything worth showing while it is a stand-in (a route parameter).
  final String? detail;

  /// Shortcuts to other routes (tab roots and the entry screens are entered
  /// with `go`, everything else is pushed).
  final List<PlaceholderLink> links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = GoRouter.maybeOf(context)?.canPop() ?? Navigator.of(context).canPop();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  detail == null ? 'Not built yet' : 'Not built yet · $detail',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                if (links.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (label, location) in links)
                        FilledButton.tonal(
                          onPressed: () => _open(context, location),
                          child: Text(label),
                        ),
                    ],
                  ),
                ],
                if (canPop) ...[
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => context.pop(), child: const Text('Back')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _open(BuildContext context, String location) {
    final root = Routes.tabIndex(location) != null || location == Routes.onboarding || location == Routes.splash;
    if (root) {
      context.go(location);
    } else {
      context.push(location);
    }
  }
}
