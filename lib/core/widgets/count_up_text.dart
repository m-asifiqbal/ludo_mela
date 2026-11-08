// CountUpText: a number that counts up to its value — coins, XP, scores — one
// 40 ms step at a time, then pops (scale 1 → 1.15 → 1) when it lands.
//
// Long counts are capped at one second (the step grows instead of the time), and
// [onStep] fires for every step so the caller can tick the coin sound. Reduce
// Motion shows the final number at once. When [value] changes, the count
// continues from what is on screen.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import 'outlined_text.dart';

/// 12450 → "12,450" (plain Latin digits; pass `format` for other languages).
String lmGroupDigits(int n) {
  final s = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

class CountUpText extends StatefulWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.from = 0,
    this.format = lmGroupDigits,
    this.size = 24,
    this.kind = OutlineKind.navy,
    this.color,
    this.prefix = '',
    this.maxDuration = const Duration(seconds: 1),
    this.pop = true,
    this.onStep,
    this.onDone,
    this.semanticsLabel,
  });

  /// The number to count up to.
  final int value;

  /// Where the first count starts.
  final int from;

  /// Turns the shown number into text (thousands separators, local digits).
  final String Function(int) format;
  final double size;
  final OutlineKind kind;
  final Color? color;

  /// Text before the number ("+").
  final String prefix;
  final Duration maxDuration;

  /// Pop on arrival.
  final bool pop;

  /// Called with the number shown after each step.
  final ValueChanged<int>? onStep;
  final VoidCallback? onDone;
  final String? semanticsLabel;

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText> with TickerProviderStateMixin {
  late final AnimationController _count = AnimationController(vsync: this)..addListener(_tick);
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  int _from = 0;
  int _steps = 1;
  int _shown = 0;
  int _lastStep = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _from = widget.from;
    _shown = widget.from;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _run();
    }
  }

  @override
  void didUpdateWidget(CountUpText old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = _shown;
      _run();
    }
  }

  void _run() {
    final delta = (widget.value - _from).abs();
    if (delta == 0 || Motion.reduced(context)) {
      _count.stop();
      _shown = widget.value;
      return;
    }
    final maxSteps = math.max(1, widget.maxDuration.inMilliseconds ~/ Motion.countStep.inMilliseconds);
    _steps = math.min(delta, maxSteps);
    _lastStep = 0;
    _count.duration = Motion.countStep * _steps;
    _count.forward(from: 0);
  }

  void _tick() {
    final step = (_count.value * _steps).floor().clamp(0, _steps);
    if (step == _lastStep && !_count.isCompleted) return;
    _lastStep = step;
    final next = _count.isCompleted ? widget.value : (_from + ((widget.value - _from) * step / _steps)).round();
    if (next != _shown) {
      setState(() => _shown = next);
      widget.onStep?.call(next);
    }
    if (_count.isCompleted) {
      if (widget.pop && !Motion.reduced(context)) _pop.forward(from: 0);
      widget.onDone?.call();
    }
  }

  @override
  void dispose() {
    _count.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = '${widget.prefix}${widget.format(_shown)}';
    return Semantics(
      label: widget.semanticsLabel ?? '${widget.prefix}${widget.format(widget.value)}',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _pop,
          builder: (context, child) => Transform.scale(
            scale: 1 + .15 * math.sin(math.pi * Motion.popCurve.transform(_pop.value).clamp(0.0, 1.0)),
            child: child,
          ),
          child: OutlinedText(text, size: widget.size, kind: widget.kind, color: widget.color, tabular: true, fit: false),
        ),
      ),
    );
  }
}
