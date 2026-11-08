// The press every tappable thing in Ludo Mela shares: it sinks 3 pt onto its
// lip in 120 ms and springs back with a small overshoot, with a selection haptic
// and a quiet tap sound (feedbackProvider, which respects Settings).
//
// Why one widget: touch feedback is most of what makes a game feel polished,
// so buttons, tiles, chips and dock tabs all get it from here. The pressed
// amount is exposed to a [builder] (0 = rest, 1 = fully sunk, briefly < 0 on
// the spring-back) so a button can shrink its lip while it sinks. Reduce Motion
// keeps the sink (it is state, not movement) but makes it instant.
//
// Accessibility: the visible shape can be smaller than 44 × 44 pt (badges,
// close buttons), so [MinTapTarget] widens the hit area without changing layout.
// Every icon-only button must pass a [semanticLabel].

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feedback/feedback.dart';
import '../motion/motion.dart';

/// Builds the visual for a press amount: 0 = rest, 1 = fully pressed.
typedef PressBuilder = Widget Function(BuildContext context, double press);

class Pressable extends ConsumerStatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    this.child,
    this.builder,
    this.semanticLabel,
    this.selected,
    this.sink = 3,
    this.pressedScale = .98,
    this.sfx = Sfx.tap,
    this.volume = .5,
    this.haptic = true,
    this.minTarget = 44,
    this.onLongPress,
    this.enabledOpacity = 1,
  }) : assert(child != null || builder != null, 'Pressable needs a child or a builder');

  /// Called on a completed tap; null disables the control.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The content; sunk and scaled as a whole. Ignored when [builder] is given.
  final Widget? child;

  /// Builds the content from the press amount (the content then handles sinking
  /// itself, e.g. a button shrinking its lip). No automatic transform is applied.
  final PressBuilder? builder;

  /// Screen-reader label (required for icon-only buttons).
  final String? semanticLabel;
  final bool? selected;

  /// How far the content sinks in pt (with [child]).
  final double sink;
  final double pressedScale;

  /// Sound and strength of the confirmation; [Sfx.pop] for badges and modals.
  final Sfx? sfx;
  final double volume;
  final bool haptic;

  /// Minimum tappable size (pt). Hit area only; layout is unchanged.
  final double minTarget;

  /// Opacity of the whole control when disabled (1 = leave it to the content).
  final double enabledOpacity;

  @override
  ConsumerState<Pressable> createState() => _PressableState();
}

class _PressableState extends ConsumerState<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, lowerBound: -.4, upperBound: 1, value: 0);

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  /// Cached in [build]: gesture callbacks (incl. a cancel while the element is
  /// being torn down) must not look up inherited widgets from a dead context.
  bool _reduced = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down() {
    if (!_enabled) return;
    if (_reduced) {
      _c.value = 1;
      return;
    }
    _c.animateTo(1, duration: Motion.tap, curve: Curves.easeOut);
  }

  void _up() {
    if (!mounted) return;
    if (_reduced) {
      _c.value = 0;
      return;
    }
    // A very quick tap must still be seen: finish the sink, then spring back.
    if (_c.value < .8) {
      _c.animateTo(1, duration: Motion.tap * (1 - _c.value), curve: Curves.easeOut).whenComplete(_spring);
    } else {
      _spring();
    }
  }

  void _spring() {
    if (!mounted) return;
    _c.animateTo(0, duration: Motion.quick, curve: Motion.popCurve);
  }

  void _tap() {
    final cb = widget.onTap;
    if (cb == null) return;
    final fb = ref.read(feedbackProvider);
    if (widget.haptic) fb.selection();
    if (widget.sfx != null) fb.play(widget.sfx!, volume: widget.volume);
    cb();
  }

  @override
  Widget build(BuildContext context) {
    _reduced = Motion.reduced(context);
    final enabled = widget.onTap != null;

    Widget body = AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final p = _c.value;
        if (widget.builder != null) return widget.builder!(context, p);
        return Transform.translate(
          offset: Offset(0, widget.sink * p),
          child: Transform.scale(scale: 1 - (1 - widget.pressedScale) * p, child: widget.child),
        );
      },
    );

    if (!enabled && widget.enabledOpacity < 1) {
      body = Opacity(opacity: widget.enabledOpacity, child: body);
    }

    // MinTapTarget is the OUTERMOST box: every ancestor render box rejects
    // positions outside its own size before it asks its child, so the widened
    // hit area only works when nothing narrower sits above it.
    return MinTapTarget(
      minSize: widget.minTarget,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: widget.selected,
        label: widget.semanticLabel,
        onTap: enabled ? _tap : null,
        onLongPress: widget.onLongPress,
        excludeSemantics: widget.semanticLabel != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: (_) => _down(),
          onTapUp: (_) => _up(),
          onTapCancel: _up,
          onTap: enabled ? _tap : null,
          onLongPress: widget.onLongPress,
          child: body,
        ),
      ),
    );
  }
}

/// Widens the hit-test area of [child] to at least [minSize] × [minSize]
/// without changing its layout size (a 36 pt button stays 36 pt tall but a
/// thumb 4 pt above or below it still hits).
class MinTapTarget extends SingleChildRenderObjectWidget {
  const MinTapTarget({super.key, this.minSize = 44, super.child});

  final double minSize;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMinTapTarget(minSize);

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    (renderObject as _RenderMinTapTarget).minSize = minSize;
  }
}

class _RenderMinTapTarget extends RenderProxyBox {
  _RenderMinTapTarget(this.minSize);

  double minSize;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (super.hitTest(result, position: position)) return true;
    final dx = math.max(0.0, (minSize - size.width) / 2);
    final dy = math.max(0.0, (minSize - size.height) / 2);
    if (dx == 0 && dy == 0) return false;
    final inSlop = position.dx >= -dx && position.dx < size.width + dx && position.dy >= -dy && position.dy < size.height + dy;
    if (!inSlop) return false;
    final clamped = Offset(
      position.dx.clamp(0.0, math.max(0.0, size.width - .01)),
      position.dy.clamp(0.0, math.max(0.0, size.height - .01)),
    );
    return super.hitTest(result, position: clamped);
  }
}
