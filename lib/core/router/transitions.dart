// Page transitions. Every route uses one of four, so navigation feels like one
// system (board D · Motion tokens):
// * drillPage  — "screen change", 240 ms: the new page slides in 8 % from the
//                side and fades while the old one drifts the other way. Menus,
//                settings, venues, the Wi-Fi screens.
// * matchPage  — the "sit-down": the game scales 1.06 → 1 with a fade (420 ms).
//                Entering a match, its VS intro and the result.
// * fadePage   — a cross-fade with a tiny scale (340 ms): splash → lobby,
//                onboarding steps.
// * modalPage  — a pop-up route: the scrim fades in, the panel pops with a
//                spring (.6 → 1, 420 ms); the lobby stays visible behind. Closed
//                by back or a tap on the scrim.
// Reduce Motion (the phone's or Settings') turns each into a plain, quick fade.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/tr.dart';
import '../motion/motion.dart';

/// The modal scrim: rgba(4, 14, 40, .72) — design board A, "Modal anatomy".
const Color _scrim = Color(0xB8040E28);

/// A plain fade, finished in the first [share] of the transition.
Widget _quickFade(Animation<double> anim, Widget child, {double share = .5}) =>
    FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Interval(0, share)), child: child);

/// Menus and settings: slide + fade, the old page drifting away.
CustomTransitionPage<T> drillPage<T>(GoRouterState state, Widget child) => CustomTransitionPage<T>(
  key: state.pageKey,
  child: child,
  transitionDuration: Motion.screen,
  reverseTransitionDuration: Motion.screen,
  transitionsBuilder: (context, anim, secondary, child) {
    if (Motion.reduced(context)) return _quickFade(anim, child);
    final inCurve = CurvedAnimation(parent: anim, curve: Motion.standardCurve, reverseCurve: Motion.exitCurve);
    final outCurve = CurvedAnimation(parent: secondary, curve: Motion.standardCurve);
    return SlideTransition(
      position: Tween(begin: Offset.zero, end: const Offset(-.06, 0)).animate(outCurve),
      child: FadeTransition(
        opacity: Tween(begin: 1.0, end: .0).animate(CurvedAnimation(parent: secondary, curve: const Interval(0, .6))),
        child: SlideTransition(
          position: Tween(begin: const Offset(.08, 0), end: Offset.zero).animate(inCurve),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: const Interval(.15, 1)),
            child: child,
          ),
        ),
      ),
    );
  },
);

/// Entering a match (and its VS intro / result): the game "sits down".
CustomTransitionPage<T> matchPage<T>(GoRouterState state, Widget child) => CustomTransitionPage<T>(
  key: state.pageKey,
  child: child,
  transitionDuration: Motion.modal,
  reverseTransitionDuration: Motion.screen,
  transitionsBuilder: (context, anim, secondary, child) {
    if (Motion.reduced(context)) return _quickFade(anim, child);
    final t = CurvedAnimation(parent: anim, curve: Motion.standardCurve, reverseCurve: Motion.exitCurve);
    return FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: const Interval(0, .7)),
      child: ScaleTransition(scale: Tween(begin: 1.06, end: 1.0).animate(t), child: child),
    );
  },
);

/// Splash → lobby, onboarding steps: a cross-fade with a tiny scale.
CustomTransitionPage<T> fadePage<T>(GoRouterState state, Widget child) => CustomTransitionPage<T>(
  key: state.pageKey,
  child: child,
  transitionDuration: Motion.sheet,
  reverseTransitionDuration: Motion.screen,
  transitionsBuilder: (context, anim, secondary, child) {
    if (Motion.reduced(context)) return _quickFade(anim, child);
    final t = CurvedAnimation(parent: anim, curve: Motion.standardCurve);
    return FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: const Interval(.2, 1)),
      child: ScaleTransition(scale: Tween(begin: .97, end: 1.0).animate(t), child: child),
    );
  },
);

/// A pop-up as a route (the daily gift): scrim + spring pop over the page below.
CustomTransitionPage<T> modalPage<T>(GoRouterState state, Widget child) => CustomTransitionPage<T>(
  key: state.pageKey,
  child: child,
  opaque: false,
  barrierColor: _scrim,
  barrierDismissible: true,
  barrierLabel: tr('Close'),
  transitionDuration: Motion.modal,
  reverseTransitionDuration: Motion.quick,
  transitionsBuilder: (context, anim, secondary, child) {
    if (Motion.reduced(context)) return _quickFade(anim, child);
    final pop = CurvedAnimation(parent: anim, curve: Motion.popCurve, reverseCurve: Motion.exitCurve);
    return FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: const Interval(0, .5)),
      child: ScaleTransition(scale: Tween(begin: .6, end: 1.0).animate(pop), child: child),
    );
  },
);
