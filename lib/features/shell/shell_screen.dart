// TEMPORARY tab shell: the five tab roots with a plain bottom bar.
//
// The lobby wave replaces this file's bar with the round dock from the design
// kit (solid icons in circles, a gold Home, badges). What must survive:
//   * the tab order (Routes.tabs) and `shell.goBranch`;
//   * `TabsBackScope` around the tabs (Android back: tab → lobby → "Leave the
//     mela?");
//   * `FadeBranches`, so tabs keep their state and fade in;
//   * no ad banner here: banners live on match screens only (docs/ads.md).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback/feedback.dart';
import '../../core/l10n/tr.dart';
import '../../core/router/tabs_back_scope.dart';
import 'fade_branches.dart';

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key, required this.shell, required this.children});

  final StatefulNavigationShell shell;

  /// One navigator per tab, in [Routes.tabs] order.
  final List<Widget> children;

  /// Icon + label per tab. Labels are built per call so they follow a
  /// language switch.
  static List<(IconData, String)> get _tabs => [
    (Icons.home_rounded, tr('Home')),
    (Icons.people_alt_rounded, tr('Friends')),
    (Icons.inventory_2_rounded, tr('Collection')),
    (Icons.flag_rounded, tr('Road')),
    (Icons.emoji_events_rounded, tr('Events')),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = shell.currentIndex;
    return TabsBackScope(
      shell: shell,
      child: Scaffold(
        body: FadeBranches(index: index, children: children),
        bottomNavigationBar: _Bar(
          index: index,
          tabs: _tabs,
          onSelect: (i) {
            if (i != index) ref.read(feedbackProvider).selection();
            shell.goBranch(i, initialLocation: i == index);
          },
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.index, required this.tabs, required this.onSelect});

  final int index;
  final List<(IconData, String)> tabs;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final (i, (icon, label)) in tabs.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: label,
                    excludeSemantics: true,
                    onTap: () => onSelect(i),
                    child: InkResponse(
                      onTap: () => onSelect(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: i == index ? colors.primary : colors.onSurfaceVariant),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: i == index ? colors.primary : colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
