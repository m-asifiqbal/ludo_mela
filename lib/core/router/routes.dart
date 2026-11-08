// Every path of the app, as constants (architecture.md · "Routes").
//
// Why one file: screens navigate with `context.push(Routes.settings)` /
// `context.go(Routes.lobby)`, never with a string literal, so a path can be
// renamed or re-parented in one place and the router test can prove that every
// path in the architecture has a screen registered.
//
//   /                splash                       tabs (the round dock):
//   /onboarding      first-run name + animal        /lobby  /friends  /collection  /road  /events
//   drill-ins (full screens above the tabs):
//     /gift /wheel /venues /pass-play /vs /match /result /report /puzzle
//     /try-on/:item /terms /insights /profile /settings
//     /lan/host /lan/join /lan/scan /lan/lobby
// Pop-ups over the lobby (free rewards, missions, game options, pot opening,
// level-up) are dialogs (`showMelaDialog`), not routes.
//
// Data for a route travels in `GoRouterState.extra` (a MatchConfig for /match,
// a RewardSummary for /result …) — except the item id of /try-on/:item.

import '../../domain/save_data.dart';

abstract final class Routes {
  // ── Entry ──────────────────────────────────────────────────────────────
  static const splash = '/';
  static const onboarding = '/onboarding';

  // ── Tabs (order = the dock, left to right) ─────────────────────────────
  static const lobby = '/lobby';

  /// "Friends": the Wi-Fi party hub.
  static const friends = '/friends';
  static const collection = '/collection';

  /// Mela Road (level rewards).
  static const road = '/road';

  /// Mela Cup and events.
  static const events = '/events';

  /// The tab roots in dock order; the index is the shell branch index.
  static const List<String> tabs = [lobby, friends, collection, road, events];

  // ── Drill-ins ──────────────────────────────────────────────────────────
  static const gift = '/gift';
  static const wheel = '/wheel';
  static const venues = '/venues';
  static const passPlay = '/pass-play';

  /// "VS — who goes first" (between setup and the match).
  static const vs = '/vs';

  /// The board: classic, quick, master, rush, mayhem, teams, tabletop.
  static const match = '/match';
  static const result = '/result';

  /// Match insights.
  static const report = '/report';
  static const puzzle = '/puzzle';

  /// The route pattern; build a location with [tryOn].
  static const tryOnPattern = '/try-on/:item';
  static const terms = '/terms';
  static const insights = '/insights';
  static const profile = '/profile';
  static const settings = '/settings';
  static const lanHost = '/lan/host';
  static const lanJoin = '/lan/join';
  static const lanScan = '/lan/scan';
  static const lanLobby = '/lan/lobby';

  /// The location that tries on catalogue item [itemId].
  static String tryOn(String itemId) => '/try-on/${Uri.encodeComponent(itemId)}';

  /// Every route pattern the app registers (the router test walks this list).
  static const List<String> all = [
    splash,
    onboarding,
    ...tabs,
    gift,
    wheel,
    venues,
    passPlay,
    vs,
    match,
    result,
    report,
    puzzle,
    tryOnPattern,
    terms,
    insights,
    profile,
    settings,
    lanHost,
    lanJoin,
    lanScan,
    lanLobby,
  ];

  /// The tab index of [location] (a tab root), or null for anything else.
  static int? tabIndex(String location) {
    final i = tabs.indexOf(Uri.parse(location).path);
    return i < 0 ? null : i;
  }

  /// Where the splash leads: the first-run flow until it is done, then the lobby.
  static String entryFor(DeviceState device) => device.onboarded ? lobby : onboarding;
}
