// Android's back button at the tab roots (architecture.md · "Routes"):
//   * on any other tab  → go to the lobby tab (and tick, like a tab tap);
//   * on the lobby      → ask "Leave the mela?"; only a yes closes the app.
// Pages pushed above the tabs (settings, a match, a pop-up) keep their own back
// behaviour: Flutter asks the topmost route first, so this only sees the back
// press when the tab shell itself is on top. iOS has no back button, so nothing
// is intercepted there.
//
// Why its own widget: the temporary shell (features/shell) uses it today and the
// round-dock shell of the lobby wave wraps its tabs in the same scope, so the
// rule lives in one place — with the question and the exit injectable for tests.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../feedback/feedback.dart';
import '../l10n/tr.dart';
import 'routes.dart';

/// Asks "Leave the mela?"; true = leave. A plain dialog: the shell owner can
/// pass the kit's ribbon dialog instead (`TabsBackScope.confirmLeave`).
Future<bool> confirmLeaveMela(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('Leave the mela?')),
      content: Text(tr('Your coins and progress are saved on this phone.')),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(tr('Stay'))),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(tr('Leave'))),
      ],
    ),
  );
  return leave ?? false;
}

/// Wraps the tab shell and owns its back behaviour.
class TabsBackScope extends ConsumerStatefulWidget {
  const TabsBackScope({
    super.key,
    required this.shell,
    required this.child,
    this.confirmLeave = confirmLeaveMela,
    this.leave = SystemNavigator.pop,
  });

  final StatefulNavigationShell shell;
  final Widget child;

  /// The "Leave the mela?" question (true = leave).
  final Future<bool> Function(BuildContext context) confirmLeave;

  /// Closes the app (replaced in tests).
  final Future<void> Function() leave;

  @override
  ConsumerState<TabsBackScope> createState() => _TabsBackScopeState();
}

class _TabsBackScopeState extends ConsumerState<TabsBackScope> {
  /// The question is on screen: a second back press is ignored.
  bool _asking = false;

  Future<void> _onBack() async {
    final home = Routes.tabs.indexOf(Routes.lobby);
    if (widget.shell.currentIndex != home) {
      ref.read(feedbackProvider).selection();
      widget.shell.goBranch(home);
      return;
    }
    if (_asking) return;
    _asking = true;
    final leave = await widget.confirmLeave(context);
    _asking = false;
    if (leave) await widget.leave();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _onBack();
    },
    child: widget.child,
  );
}
