// The route table: every path of the architecture and the transition it uses
// (transitions.dart). Paths come from routes.dart.
//
// TEMPORARY: until a feature lands, its route shows a PlaceholderScreen. To wire
// a feature in, replace the placeholder in ITS route with the real screen (one
// line + an import) — routes are grouped by feature area, one route per line
// block, so several builders can edit this file without touching the same lines.
// The tab shell (features/shell) is replaced the same way by the lobby wave's
// round dock.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dev/placeholder_screen.dart';
import '../../features/shell/shell_screen.dart';
import '../l10n/tr.dart';
import 'routes.dart';
import 'transitions.dart';

/// The app's router (one per app; tests build their own with [buildRouter]).
final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});

/// Builds the router, starting at [initial]. [observers] and [initialExtra] are
/// for tests.
GoRouter buildRouter({
  String initial = Routes.splash,
  Object? initialExtra,
  List<NavigatorObserver> observers = const [],
}) => GoRouter(
  initialLocation: initial,
  initialExtra: initialExtra,
  observers: observers,
  routes: [
    // ── Entry · features/splash, features/onboarding ─────────────────────
    GoRoute(
      path: Routes.splash,
      pageBuilder: (c, s) => fadePage(
        s,
        const PlaceholderScreen('Splash', links: [('Lobby', Routes.lobby), ('Onboarding', Routes.onboarding)]),
      ),
    ),
    GoRoute(path: Routes.onboarding, pageBuilder: (c, s) => fadePage(s, const PlaceholderScreen('Onboarding'))),

    // ── The five tabs (round dock) · features/lobby, lan, collection, road, cup ──
    StatefulShellRoute(
      builder: (context, state, shell) => shell,
      navigatorContainerBuilder: (context, shell, children) => ShellScreen(shell: shell, children: children),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.lobby, builder: (c, s) => const PlaceholderScreen('Lobby', links: _drillInLinks))],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.friends, builder: (c, s) => const PlaceholderScreen('Wi-Fi party'))],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.collection, builder: (c, s) => const PlaceholderScreen('Collection'))],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.road, builder: (c, s) => const PlaceholderScreen('Mela Road'))],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: Routes.events, builder: (c, s) => const PlaceholderScreen('Mela Cup and events'))],
        ),
      ],
    ),

    // ── Rewards · features/rewards ───────────────────────────────────────
    GoRoute(path: Routes.gift, pageBuilder: (c, s) => modalPage(s, const PlaceholderScreen('Daily gift'))),
    GoRoute(path: Routes.wheel, pageBuilder: (c, s) => drillPage(s, const PlaceholderScreen('Lucky wheel'))),

    // ── Setup · features/setup ───────────────────────────────────────────
    GoRoute(path: Routes.venues, pageBuilder: (c, s) => drillPage(s, const PlaceholderScreen('Mela Tour'))),
    GoRoute(path: Routes.passPlay, pageBuilder: (c, s) => drillPage(s, const PlaceholderScreen('Pass and play'))),
    GoRoute(path: Routes.vs, pageBuilder: (c, s) => matchPage(s, const PlaceholderScreen('VS'))),

    // ── Match and results · features/match, features/results ─────────────
    GoRoute(path: Routes.match, pageBuilder: (c, s) => matchPage(s, const PlaceholderScreen('Match'))),
    GoRoute(path: Routes.result, pageBuilder: (c, s) => matchPage(s, const PlaceholderScreen('Result'))),
    GoRoute(path: Routes.report, pageBuilder: (c, s) => drillPage(s, const PlaceholderScreen('Match insights'))),

    // ── Daily puzzle · features/puzzle ───────────────────────────────────
    GoRoute(path: Routes.puzzle, pageBuilder: (c, s) => drillPage(s, const PlaceholderScreen('Daily puzzle'))),

    // ── Collection · features/collection, features/terms ─────────────────
    GoRoute(
      path: Routes.tryOnPattern,
      pageBuilder: (c, s) => drillPage(s, PlaceholderScreen('Try on', detail: s.pathParameters['item'])),
    ),
    GoRoute(path: Routes.terms, pageBuilder: (c, s) => drillPage(s, const PlaceholderScreen('Gems and coins rules'))),

    // ── Profile, insights, settings · features/profile, insights, settings ──
    GoRoute(path: Routes.insights, pageBuilder: (c, s) => drillPage(s, const PlaceholderScreen('Insights'))),
    GoRoute(path: Routes.profile, pageBuilder: (c, s) => drillPage(s, const PlaceholderScreen('Profile'))),
    GoRoute(path: Routes.settings, pageBuilder: (c, s) => drillPage(s, const PlaceholderScreen('Settings'))),

    // ── Wi-Fi rooms · features/lan ───────────────────────────────────────
    GoRoute(path: Routes.lanHost, pageBuilder: (c, s) => drillPage(s, const PlaceholderScreen('Wi-Fi room (host)'))),
    GoRoute(path: Routes.lanJoin, pageBuilder: (c, s) => drillPage(s, const PlaceholderScreen('Join a room'))),
    GoRoute(path: Routes.lanScan, pageBuilder: (c, s) => drillPage(s, const PlaceholderScreen('Scan a QR code'))),
    GoRoute(path: Routes.lanLobby, pageBuilder: (c, s) => drillPage(s, const PlaceholderScreen('Wi-Fi room'))),
  ],
  errorBuilder: (context, state) => const _NotFound(),
);

/// The lobby stand-in's shortcuts: every full-screen route, so the navigation graph can be walked on a device.
const List<PlaceholderLink> _drillInLinks = [
  ('Settings', Routes.settings),
  ('Profile', Routes.profile),
  ('Insights', Routes.insights),
  ('Daily gift', Routes.gift),
  ('Lucky wheel', Routes.wheel),
  ('Mela Tour', Routes.venues),
  ('Pass and play', Routes.passPlay),
  ('VS', Routes.vs),
  ('Match', Routes.match),
  ('Result', Routes.result),
  ('Report', Routes.report),
  ('Puzzle', Routes.puzzle),
  ('Terms', Routes.terms),
  ('Wi-Fi host', Routes.lanHost),
  ('Wi-Fi join', Routes.lanJoin),
  ('Wi-Fi scan', Routes.lanScan),
  ('Wi-Fi room', Routes.lanLobby),
];

/// Shown for a location the table does not know (a stale link, a typo).
class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('This page is not here'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => context.go(Routes.lobby), child: Text(tr('Back to the lobby'))),
          ],
        ),
      ),
    ),
  );
}
