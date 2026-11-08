// Keeps every tab alive and fades the active one in (a "fade-through").
//
// Why: the tab roots are heavy screens (the lobby, the collection) whose state —
// scroll position, running animations — should survive a trip to another tab, so
// they stay mounted (Offstage + TickerMode off) and only the visible one fades
// and scales in a hair when the index changes. Reduce Motion shows it at once.

import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';

class FadeBranches extends StatefulWidget {
  const FadeBranches({super.key, required this.index, required this.children});

  /// The visible tab.
  final int index;

  /// One widget per tab (the shell's branch navigators).
  final List<Widget> children;

  @override
  State<FadeBranches> createState() => _FadeBranchesState();
}

class _FadeBranchesState extends State<FadeBranches> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.quick, value: 1);

  @override
  void didUpdateWidget(FadeBranches old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _c.forward(from: Motion.reduced(context) ? 1 : 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (var i = 0; i < widget.children.length; i++)
        Offstage(
          offstage: i != widget.index,
          child: TickerMode(
            enabled: i == widget.index,
            child: i == widget.index
                ? AnimatedBuilder(
                    animation: _c,
                    builder: (_, child) {
                      final t = Motion.standardCurve.transform(_c.value);
                      return Opacity(
                        opacity: Curves.easeOut.transform(_c.value),
                        child: Transform.scale(scale: .985 + .015 * t, child: child),
                      );
                    },
                    child: widget.children[i],
                  )
                : widget.children[i],
          ),
        ),
    ],
  );
}
