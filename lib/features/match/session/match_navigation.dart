// Where the match flow sends the player, behind one tiny seam.
//
// Why: the launcher (lobby → /vs or /match) and the recorder (→ /result) navigate from plain Dart,
// without a BuildContext, through the app's router. Tests override [matchNavigationProvider] with a
// recording fake, so the flow is checked without a widget tree.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';

class MatchNavigation {
  const MatchNavigation({required this.push, required this.go});

  /// A drill-in (lobby → VS, lobby → board): the stack grows.
  final void Function(String route) push;

  /// A root change (board → result): the stack is replaced.
  final void Function(String route) go;
}

final matchNavigationProvider = Provider<MatchNavigation>(
  (ref) => MatchNavigation(
    push: (route) => unawaited(ref.read(routerProvider).push<void>(route)),
    go: (route) => ref.read(routerProvider).go(route),
  ),
);
